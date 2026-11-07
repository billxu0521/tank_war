extends SceneTree
## 玩具積木拍照（docs/規劃/2026-11-08-玩具積木場景.md、-二.md）：灰盒地圖。拍：
##   trees（一排積木樹，近看）、stones_fence（石頭和柵欄，近看）、ground（地面，近看）、town（整個鎮的遠景）、
##   charge_0_before / charge_1_hit / charge_2_after（尼諾拉跑步撞進一棟房子：撞之前、撞的那一下、之後碎塊散開）。
## 同時印出：積木總塊數、樹、石頭、柵欄的數量。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/toy_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _boss: Node3D
var _shots: Array = []   # [名字, 鏡頭位置, 看向的點]
var _i := 0
var _wait := 0
var _out := ""
var _stage := 0          # 0 = 靜態的拍照；1 = 跑步撞房子（物理在 _physics_process 推）
var _run_t := 0.0        # 跑了幾秒（物理時間）
var _hit_at := -1.0      # 撞到之後幾秒（拍 charge_2 用）
var _house: ToyBuild
var _hc := Vector3.ZERO

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
	if _stage == 1:
		return _charge_shots()
	_wait += 1
	if _wait < 8:   # 等畫面和物理穩下來
		return false
	_wait = 0
	if _i < _shots.size():
		var s: Array = _shots[_i]
		_aim(s[1], s[2])
		_save(s[0])
		_i += 1
		if _i == _shots.size():
			_stage = 1
			_aim(_boss_cam_from(), _hc + Vector3(0, 3, 0))
			_save("charge_0_before")
			_wait = 0
			_run_t = 0.0
	return false

## 跑步撞房子：撞之前拍過了（charge_0_before）。跑 0.9 秒拍撞的那一下，之後再 1.8 秒拍碎塊散開
func _charge_shots() -> bool:
	if _run_t < 0.9:
		return false
	if _hit_at < 0.0:
		_save("charge_1_hit")
		print("撞的時候 尼諾拉在 x=%.1f；房子還站著 %d 塊" % [_boss.global_position.x, _standing()])
		_hit_at = 0.0
	if _hit_at < 1.8:
		return false
	_save("charge_2_after")
	print("之後：房子站著 %d 塊（%d 塊）；場上碎塊 %d 個" % [_standing(), _house.brick_count(), _pieces()])
	return true

func _physics_process(delta: float) -> bool:
	if _stage != 1 or _boss == null:
		return false
	if _run_t < 0.9:
		_run_t += delta
		_boss._move(Vector3.RIGHT, true, delta)   # 沿 +X 跑，房子在前面
	else:
		_hit_at += delta
		_boss._move(Vector3.ZERO, false, delta)   # 撞之後停住，看碎塊怎麼散
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
	var base: ToyBuild = trees[trees.size() / 2]
	var row := _nearest(trees, base.global_position, 3)
	var rc: Vector3 = (row[0].global_position + row[1].global_position + row[2].global_position) / 3.0
	_shots.append(["trees", rc + Vector3(0, 3.5, 13.0), rc + Vector3(0, 3.0, 0)])
	var st: ToyBuild = stones[0] if not stones.is_empty() else base
	var fe: ToyBuild = fences[0] if not fences.is_empty() else base
	var sc := (st.global_position + fe.global_position) * 0.5
	_shots.append(["stones_fence", sc + Vector3(0, 3.0, 9.0), sc + Vector3(0, 0.8, 0)])
	_shots.append(["ground", base.global_position + Vector3(0, 1.8, 5.0), base.global_position + Vector3(0, 0, 0)])
	_shots.append(["town", Vector3(-45, 38, 55), Vector3(0, 2, 0)])
	var houses: Array = toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t.brick_count() > 300 and not t.is_in_group(&"tree") and not t.is_in_group(&"fence") and t != _main.map._party_house)
	_house = houses[0] if not houses.is_empty() else base
	_hc = _house.global_position
	_boss = _main.spawn_boss()
	_boss.set_physics_process(false)
	_boss.global_position = _main.boss_on_ground(_hc + Vector3(-16, 0, 0))
	_boss.rotation.y = -PI * 0.5
	_boss.velocity = Vector3.ZERO
	print("房子 %d 塊，尼諾拉在它前面 16 公尺" % _house.brick_count())

func _boss_cam_from() -> Vector3:
	return _hc + Vector3(-14, 7, 20)

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
