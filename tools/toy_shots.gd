extends SceneTree
## 玩具積木拍照（docs/規劃/2026-11-08-玩具積木場景.md、-二.md）：灰盒地圖。拍：
##   trees（一排積木樹，近看）、stones_fence（石頭和柵欄，近看）、ground（地面，近看）、town（鎮的遠景）、
##   charge_0_before / charge_1_hit / charge_2_after（尼諾拉跑步撞進一棟房子：撞之前、房子第一塊掉下來、0.8 秒後）。
## 鏡頭換了要等幾幀才拍（畫面要跟上），所以每張都是「換鏡頭、等 4 幀、存圖」。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/toy_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _boss: Node3D
var _house: ToyBuild
var _hc := Vector3.ZERO
var _shots: Array = []   # [名字, 鏡頭位置, 看向的點]
var _i := 0
var _wait := 0
var _out := ""
var _stage := 0          # 0 = 靜態的拍照；1 = 跑步撞房子
var _run_on := false     # 鏡頭對好之後才讓尼諾拉跑（物理在 _physics_process 推）
var _run_t := 0.0
var _hit := false
var _after_t := -1.0
var _before_done := false

func _initialize() -> void:
	_out = OS.get_environment("OUT")
	if _out == "":
		_out = "user://toy_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_main._offline = true
		_main._enter_game("玩具積木拍照")
		return false
	if _f == 60:
		_setup()
		return false
	if _f < 60:
		return false
	_wait += 1
	if _stage == 0:
		if _i >= _shots.size():
			_stage = 1
			_wait = 0
			return false
		var s: Array = _shots[_i]
		if _wait == 1:
			_aim(s[1], s[2])
		elif _wait >= 5:
			_save(s[0])
			_i += 1
			_wait = 0
		return false
	# 撞房子：鏡頭對好、等 5 幀，拍撞之前，然後讓尼諾拉跑
	if _wait == 1:
		_aim(_hc + Vector3(-14, 7, 20), _hc + Vector3(-4, 4, 0))
	if _wait == 5 and not _before_done:
		_save("charge_0_before")
		_before_done = true
		_run_on = true
	if _run_on and not _hit and _standing() < _house.brick_count():
		_hit = true
		_save("charge_1_hit")
		print("撞到了：尼諾拉 x=%.1f，房子站著 %d 塊" % [_boss.global_position.x, _standing()])
		_after_t = 0.0
	if _after_t >= 0.8:
		_save("charge_2_after")
		print("之後：房子站著 %d 塊（共 %d 塊）；場上碎塊 %d 個" % [_standing(), _house.brick_count(), _pieces()])
		return true
	if _run_t > 5.0:
		print("跑了 5 秒還沒撞到房子")
		return true
	return false

func _physics_process(delta: float) -> bool:
	if not _run_on or _boss == null:
		return false
	_run_t += delta
	if _after_t >= 0.0:
		_after_t += delta
	_boss._move(Vector3.RIGHT, true, delta)   # 沿 +X 跑，房子在前面
	return false

func _setup() -> void:
	_main.menu.visible = false
	_cam = Camera3D.new()
	_cam.fov = 50
	root.add_child(_cam)
	_cam.current = true
	var toys: Array = _main.map._toys
	var total := 0
	for t: ToyBuild in toys:
		total += t.brick_count()
	print("積木總塊數 %d（%d 棟；碰撞形狀一塊一個）" % [total, toys.size()])
	var trees: Array = toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"tree"))
	var stones: Array = toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"stone"))
	var fences: Array = toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"fence"))
	print("樹 %d 棵、石頭 %d 顆、柵欄 %d 段" % [trees.size(), stones.size(), fences.size()])
	var houses: Array = toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t.brick_count() > 300 and not t.is_in_group(&"tree") and not t.is_in_group(&"fence") and t != _main.map._party_house)
	_house = houses[0]
	_hc = _house.global_position
	# 一排樹：挑一棵，取離它最近的三棵，從它們的前面（+Z 側）拍
	var row := _nearest(trees, _hc, 3)
	var rc: Vector3 = (row[0].global_position + row[1].global_position + row[2].global_position) / 3.0
	_shots.append(["trees", rc + Vector3(0, 2.2, 8.0), rc + Vector3(0, 2.6, 0)])
	var st: ToyBuild = stones[0]
	var fe: ToyBuild = fences[0]
	var sc := (st.global_position + fe.global_position) * 0.5
	_shots.append(["stones_fence", sc + Vector3(0, 2.5, 7.0), sc + Vector3(0, 0.8, 0)])
	_shots.append(["ground", row[0].global_position + Vector3(0, 1.4, 4.0), row[0].global_position + Vector3(0, 0, 0)])
	_shots.append(["town", _hc + Vector3(-26, 13, 34), _hc + Vector3(0, 3, 0)])
	_boss = _main.spawn_boss()
	_boss.set_physics_process(false)
	_boss.global_position = _main.boss_on_ground(_hc + Vector3(-16, 0, 0))
	_boss.rotation.y = -PI * 0.5
	_boss.velocity = Vector3.ZERO
	print("房子 %d 塊，尼諾拉在它前面 16 公尺" % _house.brick_count())

func _standing() -> int:
	var n := 0
	for i in _house.brick_count():
		if _house.is_standing(i):
			n += 1
	return n

func _pieces() -> int:
	var n := 0
	for c in _house.get_parent().get_children():
		if c.is_in_group(&"toy_piece") and c.get_meta(&"toy_home", null) == _house:
			n += 1
	return n

func _aim(from: Vector3, at: Vector3) -> void:
	_cam.current = true
	_cam.look_at_from_position(from, at)

func _nearest(list: Array, p: Vector3, n: int) -> Array:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: ToyBuild, b: ToyBuild) -> bool: return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return sorted.slice(0, n)

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("存圖 ", path)
