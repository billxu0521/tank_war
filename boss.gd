extends "res://dino.gd"
## 恐龍 boss（電腦操控，主機上跑）：守著蛋、牽制偷蛋的人。打不死——血打光會倒地暈 KNOCK_TIME 秒，
## 起來血是滿的，繼續追。只會咬，不吐火球。
##
## 行為樹（bt.gd），每幀從上往下找第一條走得通的：
##   1. 倒地中        → 等
##   2. 嘴邊有人      → 咬
##   3. 有人拿著蛋    → 追持蛋者（自己的蛋，一定知道在哪）
##   4. 看得到人      → 追最近的
##   5. 剛看丟了人    → 往最後看到的地方追
##   6. 聽到聲音      → 過去查看（槍聲、附近有人跑步）
##   7. 都沒有        → 回蛋旁邊巡邏（用走的）
##
## 感官：視力差——近（SIGHT）、只看前方、要沒被擋住；蹲著要更近才看得到，蹲在灌木裡看不到。
## 聽力好——整張地圖的槍聲都聽得到，附近有人跑步也聽得到（走路和蹲著走聽不到）。
## 移動：走比牛仔慢、跑比牛仔快。跑步吃自己的體力（跟恐龍玩家那套分開），
## 見底就只能走、要回到 RECOVER_AT 才能再跑——牛仔拉開距離的機會就在這。
##
## ponytail: 直線追、卡牆就偏一點滑開，沒有導航網格。會卡在建築後面繞不出來的話再加 NavigationRegion3D。

const WALK := 4.0            # 牛仔走 5.0
const RUN := 11.0            # 牛仔跑 8.5
const RUN_DRAIN := 14.0      # 每秒；滿體力約跑 7 秒
const REGEN := 12.0          # 沒在跑的時候每秒回
const RECOVER_AT := 45.0     # 跑到見底之後，回到這麼多才能再跑
const SIGHT := 18.0          # 看得到多遠
const SIGHT_CROUCH := 9.0    # 蹲著的人要更近才看得到
const SIGHT_CONE := 0.5      # cos 60°：正前方左右各 60 度
const FEEL := 5.0            # 這麼近不管方向都會發現
const HEAR_GUN := 150.0      # 槍聲：場地 192 公尺，幾乎整張圖都聽得到
const HEAR_RUN := 20.0       # 有人在附近跑步
const RUN_SPEED_HEARD := 6.5 # 水平速度超過這個算在跑（牛仔走 5、跑 8.5）
const MEMORY := 6.0          # 看丟之後，往最後看到的位置追這麼久
const NOISE_FORGET := 12.0   # 聽到的聲音記多久
const GUARD_RADIUS := 12.0   # 在蛋附近這個半徑內巡邏
const KNOCK_TIME := 6.0
const TURN := 3.0            # 轉身速度（弧度／秒）：大隻轉得慢，繞著牠跑有用
const BOSS_BITE_CD := 1.4
const ARRIVE := 2.5

## 這幾個同步出去（boss.tscn 的同步器），大家的 HUD 和畫面都看得到
@export var down_left := 0.0
@export var running := false

var _tree: BT.Task
var _target: Node3D = null
var _last_seen := Vector3.INF
var _seen_left := 0.0
var _noise := Vector3.INF
var _noise_left := 0.0
var _last_pos := {}           # 牛仔 → 上一幀的位置（算誰在跑）
var _guard_to := Vector3.INF


func _ready() -> void:
	super()
	_tree = BT.Sel.new([
		BT.Seq.new([BT.Cond.new(func() -> bool: return down_left > 0.0), BT.Act.new(_act_down)]),
		BT.Seq.new([BT.Cond.new(_can_bite), BT.Act.new(_act_bite)]),
		BT.Seq.new([BT.Cond.new(_egg_carried), BT.Act.new(_act_chase)]),
		BT.Seq.new([BT.Cond.new(_sees_someone), BT.Act.new(_act_chase)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _seen_left > 0.0), BT.Act.new(_act_last_seen)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _noise_left > 0.0), BT.Act.new(_act_investigate)]),
		BT.Act.new(_act_guard),
	])


## 倒地時整隻往側邊躺（每台都跑，down_left 是同步來的）
func _process(delta: float) -> void:
	super(delta)
	$Trex.rotation.z = lerpf($Trex.rotation.z, 1.35 if down_left > 0.0 else 0.0, minf(delta * 4.0, 1.0))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	think(delta)


## 一幀的決策＋移動。測試直接呼叫這個
func think(delta: float) -> void:
	_bite_cd -= delta
	_seen_left = maxf(_seen_left - delta, 0.0)
	_noise_left = maxf(_noise_left - delta, 0.0)
	_listen_steps(delta)
	_tree.tick(delta)


# --- 感官 ---

## 聽到槍聲（viewmodel 開槍時在主機上呼叫，見 Viewmodel._alert_boss）
func hear(at: Vector3) -> void:
	if global_position.distance_to(at) <= HEAR_GUN:
		_noise = at
		_noise_left = NOISE_FORGET

## 附近有人跑步：主機只拿得到同步來的位置，用位置差算速度
func _listen_steps(delta: float) -> void:
	for p in _cowboys():
		var now: Vector3 = p.global_position
		var before: Vector3 = _last_pos.get(p, now)
		_last_pos[p] = now
		var speed := Vector2(now.x - before.x, now.z - before.z).length() / maxf(delta, 1e-4)
		if speed > RUN_SPEED_HEARD and global_position.distance_to(now) < HEAR_RUN:
			_noise = now
			_noise_left = NOISE_FORGET

func can_see(p: Node3D) -> bool:
	var to := p.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if flat < FEEL:
		return true
	var g := _game()
	if g and g.hidden_in_bush(p):
		return false
	if flat > (SIGHT_CROUCH if p.get(&"sync_crouching") == true else SIGHT):
		return false
	var fwd := -global_basis.z
	if Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to.x, to.z) / flat) < SIGHT_CONE:
		return false
	return not _blocked_by_wall(p)

func _cowboys() -> Array:
	return get_parent().get_children().filter(
		func(p: Node) -> bool: return p != self and not p.is_in_group(&"dino") and p.get(&"hp") > 0)

func _game() -> Node:
	return get_tree().get_first_node_in_group(&"match")


# --- 行為樹的條件 ---

func _can_bite() -> bool:
	if _bite_cd > 0.0:
		return false
	var fwd := -global_basis.z
	for p: Node3D in _cowboys():
		var to := p.global_position - global_position
		if to.length() < BITE_REACH * 0.9 and fwd.dot(to.normalized()) > 0.3 and not _blocked_by_wall(p):
			return true
	return false

func _egg_carried() -> bool:
	var g := _game()
	if g == null or g.egg.carrier == 0:
		return false
	_target = g.players.get_node_or_null(NodePath(str(g.egg.carrier)))
	return _target != null

func _sees_someone() -> bool:
	var best: Node3D = null
	for p: Node3D in _cowboys():
		if can_see(p) and (best == null or global_position.distance_to(p.global_position)
				< global_position.distance_to(best.global_position)):
			best = p
	if best == null:
		return false
	_target = best
	_last_seen = best.global_position
	_seen_left = MEMORY
	return true


# --- 行為樹的動作 ---

func _act_down(delta: float) -> int:
	down_left = maxf(down_left - delta, 0.0)
	_move(Vector3.ZERO, false, delta)
	return BT.RUNNING

func _act_bite(delta: float) -> int:
	_bite_cd = BOSS_BITE_CD
	_move(Vector3.ZERO, false, delta)
	_hit_nearby(BITE_REACH, BITE_DAMAGE, 0.3)
	_play_fx.rpc(false)
	return BT.SUCCESS

func _act_chase(delta: float) -> int:
	if not is_instance_valid(_target):
		return BT.FAILURE
	_go(_target.global_position, true, delta)
	return BT.RUNNING

func _act_last_seen(delta: float) -> int:
	if _go(_last_seen, true, delta):
		_seen_left = 0.0
	return BT.RUNNING

func _act_investigate(delta: float) -> int:
	if _go(_noise, true, delta):
		_noise_left = 0.0
	return BT.RUNNING

## 蛋旁邊隨便挑一點走過去，到了再挑下一點
func _act_guard(delta: float) -> int:
	var g := _game()
	var home: Vector3 = g.egg.global_position if g else global_position
	if _guard_to == Vector3.INF or home.distance_to(_guard_to) > GUARD_RADIUS * 1.5:
		_guard_to = home
	if _go(_guard_to, false, delta):
		var a := randf() * TAU
		_guard_to = home + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, GUARD_RADIUS)
	return BT.RUNNING


# --- 移動 ---

## 轉向 to 走過去（轉得慢，偏太多就先放慢腳步轉身）。到了回傳 true
func _go(to: Vector3, want_run: bool, delta: float) -> bool:
	var d := to - global_position
	d.y = 0.0
	if d.length() < ARRIVE:
		_move(Vector3.ZERO, false, delta)
		return true
	var want := atan2(-d.x, -d.z)
	if is_on_wall():
		want += 0.9   # 卡牆就偏一點滑開
	rotation.y = rotate_toward(rotation.y, want, TURN * delta)
	var off := absf(wrapf(want - rotation.y, -PI, PI))
	_move(-global_basis.z * clampf(cos(off), 0.15, 1.0), want_run, delta)
	return false

## 走或跑。跑吃體力，見底就只能走，回到 RECOVER_AT 才能再跑
func _move(dir: Vector3, want_run: bool, delta: float) -> void:
	_stagger = maxf(_stagger - delta, 0.0)
	running = want_run and not exhausted and dir != Vector3.ZERO
	if running:
		stamina = maxf(stamina - RUN_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= RECOVER_AT:
			exhausted = false
	var speed := (RUN if running else WALK) * (STAGGER_MULT if _stagger > 0.0 else 1.0)
	_accelerate(dir * speed, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()


# --- 受傷 ---

## 打不死：血打光就倒地 KNOCK_TIME 秒、血補滿。倒地時打不動（不然一直被壓在地上起不來）
func take_damage(amount: int, source: Node = null) -> void:
	if down_left > 0.0 or hp <= 0:
		return
	if hp - amount > 0:
		super(amount, source)
		return
	_knock.rpc()

@rpc("any_peer", "call_local", "reliable")
func _knock() -> void:
	down_left = KNOCK_TIME
	hp = max_hp
	_target = null
	_seen_left = 0.0
