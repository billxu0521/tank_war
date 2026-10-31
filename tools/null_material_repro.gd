extends SceneTree
## 重現「Parameter "material" is null」（引擎錯誤，材質是無效的 RID）：單人派對，尼諾拉依序做一遍會用到的招，
## 每一步之後印標記、等幾秒讓畫面真的畫出來（這個錯是渲染端報的，不畫就不會出）。
## 看錯誤出現在哪個標記之後：
##   godot --path . --resolution 1280x720 --script tools/null_material_repro.gd > LOG 2>&1
##   grep -n '== 步驟' LOG ; grep -n 'Parameter "material" is null' LOG

const SETTLE := 150   # 每步之後等幾幀（約 2.5 秒）：倒樹、倒房子的動畫要跑完

var _f := 0
var _main: Node
var _boss   # 恐龍（boss.gd，動態呼叫）
var _cow
var _step := 0
var _wait := -1
var _house
var _me   # 本機玩家（編號 1）：設定完成時記下來，後面的步驟可能已經把它打倒

## 依序的步驟：[標記名, 要做的事（Callable）]。每步做完等 SETTLE 幀，印標記
var _steps: Array = []

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	_steps = [
		["輕攻擊打牛仔", _step_bite],
		["甩尾打樹（拆倒）", _step_sweep_tree],
		["甩尾打方塊屋", _step_sweep_house],
		["吐火球打牛仔（燒）", _step_fire_cowboy],
		["火球打方塊", _step_fire_house],
		["踩踏", _step_stomp],
		["牛仔用補血包", _step_medkit],
		["牛仔丟炸藥", _step_dynamite],
		["牛仔被火燒（每秒扣血、閃紅）", _step_burn],
		["打倒牛仔（死掉、留屍體）", _step_kill],
		["恐龍挨打（閃紅、倒地）", _step_boss_hurt],
		["火球連打、煙和碎屑", _step_fx_pile],
		["刪掉電腦角色（free）", _step_clear_bots],
		["同一幀生出牛仔又清掉（新角色還沒畫過）", _step_spawn_drop],
		["本機牛仔被換掉（remove_child + queue_free，同 party.gd 清場）", _step_drop_me],
		["讓電腦 AI 自己打一陣", _step_free_play],
	]

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_solo_party_pressed()
		return false
	if _f < 60:
		return false
	if _f == 60:
		_boss = _main._boss()
		_house = _main.map._party_house
		_cow = _first_cowboy()
		print("== 設定完成：恐龍 %s、牛仔 %s、方塊房子 %s ==" % [_boss, _cow, _house != null])
		if _boss == null or _cow == null:
			push_error("找不到恐龍或牛仔")
			return true
		for p in _main.players.get_children():
			print("   角色 %s 群組 %s viewmodel=%s" % [p.name, p.get_groups(), p.get(&"viewmodel") != null])
		_me = _main.players.get_node_or_null(^"1")
		print("   本機玩家 %s viewmodel=%s" % [_me, _me != null and _me.get(&"viewmodel") != null])
		_main.menu.visible = false
		_wait = SETTLE
		return false
	_main.menu.visible = false
	if _wait > 0:
		_wait -= 1
		if _wait == 0 and _step > 0:
			print("== 步驟結束：%s ==" % _steps[_step - 1][0])
		return false
	if _soak_frames > 0:
		_soak_frames -= 1
		if _soak_frames == 0:
			print("== AI 自己玩結束 ==")
		return false
	if _step >= _steps.size():
		print("== 全部做完 ==")
		return true
	var s: Array = _steps[_step]
	print("== 步驟：%s ==" % s[0])
	s[1].call()
	_step += 1
	_wait = SETTLE
	return false

func _first_cowboy() -> Node3D:
	for p in _main.players.get_children():
		if p != _boss and p is Node3D and p.is_in_group(&"cowboy"):
			return p
	for p in _main.players.get_children():
		if p != _boss and p is Node3D:
			return p
	return null

## 把牛仔放到恐龍正前方 d 公尺（水平），面朝恐龍
func _cowboy_in_front(d: float) -> void:
	var fwd: Vector3 = -_boss.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_cow.global_position = _ground_at(_boss.global_position + fwd * d)
	if d > 0.1:
		_cow.look_at(Vector3(_boss.global_position.x, _cow.global_position.y, _boss.global_position.z))

## 水平位置 → 站在地面上的位置（射線打地面，跳過恐龍自己）
func _ground_at(at: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = _boss.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 100, at.z), Vector3(at.x, -100, at.z), 1, [_boss.get_rid()]))
	return Vector3(at.x, hit.position.y if not hit.is_empty() else at.y, at.z)

func _step_bite() -> void:
	_cowboy_in_front(3.0)
	_boss._begin(_boss.ACT_BITE, 0.6)
	for i in 30:   # 出手的判定（每幀判，同 _act_attack）
		_boss._hit_cone()
		_boss._hit_once.clear()
	print("   牛仔血量 %s" % str(_cow.get("hp")))

func _step_sweep_tree() -> void:
	var tree: Node3D = null
	var best := 1e9
	for w in root.get_tree().get_nodes_in_group(&"destructible"):
		if w is Destructible and (w as Destructible).level < 3 and (w as Node3D).global_position.distance_to(_boss.global_position) < best:
			best = (w as Node3D).global_position.distance_to(_boss.global_position)
			tree = w
	if tree == null:
		print("   找不到樹")
		return
	# 恐龍身體朝 -Z，尾巴在 +Z：樹放在恐龍後方 6 公尺
	_boss.global_position = _ground_at(tree.global_position + Vector3(0, 0, -6.0)) + Vector3.UP * 4.1
	_boss.rotation.y = 0.0
	var d: Destructible = tree
	for i in 4:
		_boss._strike_sweep()
	print("   樹 hits=%d / %d" % [d.hits, d.hits_needed])

func _step_sweep_house() -> void:
	if _house == null:
		print("   沒有方塊房子")
		return
	var c: Vector3 = _house.global_position
	_boss.global_position = Vector3(c.x - 9.0, c.y + 4.1, c.z - 9.0)
	_boss.rotation.y = PI * 0.25
	_boss._strike_sweep()

func _step_fire_cowboy() -> void:
	_cowboy_in_front(10.0)
	var dir: Vector3 = (_cow.global_position + Vector3.UP * 1.2 - _boss.global_position - Vector3.UP * 4.0).normalized()
	_boss._spit_fire(dir, _boss.global_position + Vector3.UP * 4.0)

func _step_fire_house() -> void:
	if _house == null:
		return
	var c: Vector3 = _house.global_position
	_boss.global_position = Vector3(c.x - 14.0, c.y + 4.1, c.z)
	_boss.rotation.y = -PI * 0.5   # 面朝 +X（房子在 +X 那側）
	var dir: Vector3 = (c + Vector3.UP * 3.0 - _boss.global_position).normalized()
	_boss._spit_fire(dir, _boss.global_position + Vector3.UP * 4.0)

func _step_stomp() -> void:
	_cowboy_in_front(0.0)
	_cow.global_position = _ground_at(_boss.global_position)
	_boss.velocity = _boss.global_basis.z * 12.0   # 水平速度夠快才踩得到
	for i in 20:
		_boss._stomp(0.05)
		_boss.velocity = Vector3(_boss.velocity.x, 0, _boss.velocity.z)

func _step_medkit() -> void:
	if _cow.has_method("take_damage"):
		_cow.take_damage(40, _boss)
	if _cow.has_method("request_heal"):
		_cow.request_heal()

## 刪角色：電腦牛仔（remote，mark_target 複製過材質）整個 free 掉
func _step_clear_bots() -> void:
	print("   刪前角色數 %d" % _main.players.get_child_count())
	var ov := 0
	var all := 0
	for p in _main.players.get_children():
		for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			for i in mi.get_surface_override_material_count():
				all += 1
				if mi.get_surface_override_material(i) != null:
					ov += 1
	print("   覆寫材質 %d / 網格面 %d（刪前）" % [ov, all])
	_main.clear_bots()
	print("   刪後角色數 %d" % _main.players.get_child_count())

## 本機玩家的牛仔（有第一人稱的 viewmodel，武器的網格被標成目標）被清掉：派對每回合、選尼諾拉時都是這樣收的
## 同一幀生一個牛仔（有第一人稱 viewmodel，武器網格被標成目標）、又 remove_child + queue_free：
## 派對清場、選尼諾拉（party.gd、main.gd make_pilot）都是這樣收角色，新生的角色常常還沒被畫過一次
func _step_spawn_drop() -> void:
	var c: Node3D = _main._add_player(_main.COWBOY, 77)
	_main.players.remove_child(c)
	c.queue_free()

func _step_drop_me() -> void:
	var me = _me
	print("   本機角色 %s viewmodel=%s" % [me, me != null and me.get(&"viewmodel") != null])
	if me == null:
		return
	_main.players.remove_child(me)
	me.queue_free()

func _step_burn() -> void:
	_cowboy_in_front(8.0)
	_cow.ignite(_boss)
	for i in 6:
		_cow.burn_step(1.0)

func _step_kill() -> void:
	_cowboy_in_front(4.0)
	_cow.take_damage(9999, _boss)

func _step_boss_hurt() -> void:
	_boss.take_damage(30, _cow)
	_boss.take_damage(9999, _cow)

func _step_fx_pile() -> void:
	var at: Vector3 = _boss.global_position + Vector3.UP * 2.0
	for i in 12:
		Fx.hit(_main, at + Vector3(randf() - 0.5, randf(), randf() - 0.5), Vector3.UP, &"stone")
		Fx.puff(_main, at, Vector3.UP, Color(0.6, 0.6, 0.6, 0.6), 2.0, 1.0)
		Fx.gun_smoke(_main, at, Vector3.FORWARD)
	_boss.add_shake(0.05)

## 讓 AI 自己玩（恐龍追牛仔、牛仔開槍），時間用 SOAK 環境變數（秒，預設 90）
func _step_free_play() -> void:
	_soak_frames = int(OS.get_environment("SOAK") if OS.get_environment("SOAK") != "" else "90") * 60

var _soak_frames := 0

func _step_dynamite() -> void:
	var at: Vector3 = _cow.global_position + Vector3.UP * 0.5
	var arena: Node3D = _main.get_node(^"Arena")
	Explosive.play(arena, at, 4.0)
	Explosive.damage(arena, at, 4.0, 60, _cow)
	Destructible.blast(arena, at, 4.0)
