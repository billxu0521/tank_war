extends "res://fighter.gd"
## 坦克：車身慢慢轉，砲塔用滑鼠獨立瞄準（左右轉塔、上下抬砲），左鍵開砲。

const SPEED := 9.0
const REVERSE := 0.55      # 倒車只有前進的六成
const ACCEL := 7.0         # 每秒加速，約 1.3 秒到全速
const BRAKE := 13.0        # 煞車比加速快，放開按鍵不會滑很遠
const TURN := 1.8
const TURN_ACCEL := 5.0    # 車身轉向也要拉起來，不是瞬間到最大轉速
const ELEVATE := 1.1       # 砲管每秒最多抬這麼多
const RELOAD := 1.5
const MOUSE_SENS := 0.004
# 仿坦克世界：砲管上下有角度限制，車體擋住的部分打不到
const PITCH_MIN := -0.14  # 俯角 8 度
const PITCH_MAX := 0.35   # 仰角 20 度
const CAM_BASE := -0.4363  # 相機基礎俯角 25 度
const AIM_RANGE := 70.0    # 準心以這個距離做彈道歸零（場地大了，歸零拉遠）
const BARREL_Z := -1.5     # 砲管原本的位置，後座從這裡往後推
const BOT_RANGE := 95.0    # bot 進這個距離就開火
const SHELL := preload("res://shell.tscn")

var aim_pitch := 0.0
var turret_yaw := 0.0   # 砲塔左右，直接跟著滑鼠
var gun_pitch := 0.0
var _turn_rate := 0.0
var _recoil := 0.0
var _cooldown := 0.0


@onready var turret: Node3D = $Turret
@onready var gun: Node3D = $Turret/Gun
@onready var muzzle: Marker3D = $Turret/Gun/Muzzle
@onready var cam: Camera3D = $Turret/Camera3D
@onready var barrel: Node3D = $Turret/Gun/Barrel

func _ready() -> void:
	super()
	cam.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	aim(mouse_look(e))

## 砲塔左右直接跟著滑鼠；砲管上下有角度上限，抬升速度也有上限
func aim(rel: Vector2) -> void:
	turret_yaw -= rel.x * MOUSE_SENS
	aim_pitch = clampf(aim_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if bot:
		_bot_step(delta)
		return
	if not is_multiplayer_authority():
		return  # 別人的坦克交給 MultiplayerSynchronizer 更新

	gun_pitch = move_toward(gun_pitch, aim_pitch, ELEVATE * delta)  # 砲管抬升有速度上限
	turret.rotation.y = turret_yaw
	gun.rotation.x = gun_pitch

	_recoil = maxf(_recoil - delta * 4.5, 0.0)
	cam.rotation.x = CAM_BASE + gun_pitch * 0.5 + _recoil * 0.05  # 相機跟一半 + 開砲抬頭
	barrel.position.z = BARREL_Z + _recoil * 0.6                  # 砲管後座

	var turn := float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D))
	_turn_rate = move_toward(_turn_rate, turn * TURN, TURN_ACCEL * delta)
	rotate_y(_turn_rate * delta)

	var fwd := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var want := -global_transform.basis.z * fwd * SPEED * (REVERSE if fwd < 0.0 else 1.0)
	_accelerate(want, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()

	_cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cooldown <= 0.0:
		_cooldown = RELOAD
		_fire.rpc(muzzle.global_position, -muzzle.global_transform.basis.z)

## 電腦操控的坦克。優先序由上而下，沒有行為樹——分支就這幾條，
## 框架會比行為本身還長。而且要拿來量平衡，行為固定可預測才好歸因。
##   1. 拿著蛋 -> 開去最近的撤離區
##   2. 蛋沒人拿 -> 開去撿
##   3. 別人拿著 -> 去追那個人（打死他蛋就掉下來）
## 砲塔獨立運作：永遠瞄最近的威脅，進射程就開火。
func _bot_step(delta: float) -> void:
	var g := get_tree().get_first_node_in_group(&"match")
	_bot_drive(delta, _bot_goal(g))
	_bot_shoot(delta, _bot_threat(g))

func _bot_goal(g: Node) -> Vector3:
	if g == null:
		return global_position
	var my_id := name.to_int()
	if g.egg.carrier == my_id:
		var best: Vector3 = g._exits[0]
		for e: Vector3 in g._exits:
			if global_position.distance_to(e) < global_position.distance_to(best):
				best = e
		return best
	if g.egg.carrier == 0:
		return g.egg.global_position
	var holder: Node3D = g.players.get_node_or_null(NodePath(str(g.egg.carrier)))
	return holder.global_position if holder != null else g.egg.global_position

## 瞄誰：有人拿著蛋就瞄他，否則瞄最近的敵人（恐龍或別台坦克）
func _bot_threat(g: Node) -> Node3D:
	if g == null:
		return null
	var my_id := name.to_int()
	if g.egg.carrier != 0 and g.egg.carrier != my_id:
		var holder: Node3D = g.players.get_node_or_null(NodePath(str(g.egg.carrier)))
		if holder != null:
			return holder
	var best: Node3D = null
	for p in g.players.get_children():
		if p == self:
			continue
		if best == null or global_position.distance_to(p.global_position) \
				< global_position.distance_to(best.global_position):
			best = p
	return best

func _bot_drive(delta: float, goal: Vector3) -> void:
	var to := goal - global_position
	var diff := wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI)
	# 卡牆就偏一個角度滑開，編號單雙決定往哪偏，幾台才不會擠在同一個角落
	if is_on_wall():
		diff += 0.9 if name.to_int() % 2 == 0 else -0.9
	_turn_rate = move_toward(_turn_rate, clampf(diff * 3.0, -TURN, TURN), TURN_ACCEL * delta)
	rotate_y(_turn_rate * delta)
	var throttle := 1.0 if absf(diff) < 1.2 else 0.35   # 角度差太大就先轉再衝
	_accelerate(-global_transform.basis.z * SPEED * throttle, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()

func _bot_shoot(delta: float, threat: Node3D) -> void:
	_cooldown -= delta
	if threat == null:
		return
	var rel := threat.global_position - muzzle.global_position
	var flat := Vector2(rel.x, rel.z).length()
	turret_yaw = wrapf(atan2(-rel.x, -rel.z) - rotation.y, -PI, PI)
	var t := flat / Shell.SPEED
	gun_pitch = clampf(atan2(rel.y + 0.5 * Shell.GRAVITY * t * t, flat), PITCH_MIN, PITCH_MAX)
	turret.rotation.y = turret_yaw
	gun.rotation.x = gun_pitch
	if _cooldown <= 0.0 and flat < BOT_RANGE:
		_cooldown = RELOAD
		_fire.rpc(muzzle.global_position, -muzzle.global_transform.basis.z)

@rpc("any_peer", "call_local", "reliable")
func _fire(pos: Vector3, dir: Vector3) -> void:
	_recoil = 1.0
	Fx.burst(muzzle, SphereMesh.new(), Color(1, 0.85, 0.3, 0.9),
		Vector3.ZERO, Vector3.ONE * 0.3, Vector3.ONE * 1.2, 0.12)
	var s := SHELL.instantiate()
	s.vel = dir * s.SPEED
	s.shooter = self
	get_tree().get_first_node_in_group(&"arena").add_child(s)
	s.global_position = pos


## 砲彈在 AIM_RANGE 距離會落在哪裡。準心畫在這個點上，玩家才知道會打到哪。
func aim_point() -> Vector3:
	var t := AIM_RANGE / Shell.SPEED
	return muzzle.global_position \
		- muzzle.global_transform.basis.z * AIM_RANGE \
		+ Vector3.DOWN * (0.5 * Shell.GRAVITY * t * t)
