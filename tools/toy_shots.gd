extends SceneTree
## 玩具積木拍照（docs/規劃/2026-11-08-玩具積木場景.md）：灰盒地圖，拍一棟積木房子（1）完整、（2）拆掉朝鏡頭那面牆的下半之後 0.5 秒、
## （3）4 秒後碎塊停下來；再拍整個鎮的遠景。同時印出：積木塊數、拆一下花的主線程時間、碎塊數。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/toy_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _house: ToyBuild
var _shot := 0
var _wait := 0
var _out := ""

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
	if _f < 60:
		return false
	if _f == 60:
		var houses: Array = _main.map._toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t != _main.map._party_house)
		houses.sort_custom(func(a: ToyBuild, b: ToyBuild) -> bool: return a.brick_count() < b.brick_count())
		_house = houses[houses.size() / 2]   # 不大不小的一棟
		_main.menu.visible = false
		_cam = Camera3D.new()
		_cam.fov = 50
		root.add_child(_cam)
		_cam.current = true
		var total := 0
		var toys: Array = _main.map._toys
		for t: ToyBuild in toys:
			total += t.brick_count()
		print("積木總塊數 %d（%d 棟；碰撞形狀一塊一個）" % [total, toys.size()])
		print("這一棟 %d 塊" % _house.brick_count())
		return false
	if _shot == 0:
		_aim()
		_wait += 1
		if _wait >= 4:
			_save("house_full")
			_shot = 1
			_wait = 0
			_smash_wall()
		return false
	if _shot == 1:
		_aim()
		_wait += 1
		if _wait >= 30:   # 0.5 秒
			_save("wall_gone_0_5s")
			_shot = 2
			_wait = 0
		return false
	if _shot == 2:
		_aim()
		_wait += 1
		if _wait >= 260:   # 4 秒後碎塊停下來
			_save("settled_4s")
			_report()
			_shot = 3
			_wait = 0
			_town_view()
		return false
	if _shot == 3:
		_wait += 1
		if _wait >= 10:
			_save("town_far")
			return true
	return false

## 鏡頭看房子（從朝 +Z 那側，房子本地座標）
func _aim() -> void:
	var b := _house.global_transform
	_cam.current = true
	_cam.look_at_from_position(b * Vector3(7, 13, 22), b * Vector3(0, 1.5, 0))

## 拆朝鏡頭那面牆（本地 +Z 那側）的下半：等級 1、2 挨一下（2 的要兩下，這裡只一下）。從房子中間往外推
func _smash_wall() -> void:
	var t0 := Time.get_ticks_usec()
	var inv := _house.global_transform.affine_inverse()
	_house.smash(func(p: Vector3) -> bool:
		var l := inv * p
		return l.z > 0.0 and absf(l.x) < 3.5 and l.y < 1.7, 2, _house.global_position + Vector3(0, 1.5, 0))
	print("拆一面牆（含連通檢查、碎塊）主線程花 %.1f 毫秒" % ((Time.get_ticks_usec() - t0) / 1000.0))

func _town_view() -> void:
	var c := _house.global_position
	_cam.current = true
	_cam.look_at_from_position(c + Vector3(-45, 38, 55), c + Vector3(0, 2, 0))

func _report() -> void:
	var pieces := 0
	for n in _house.get_parent().get_children():
		if n.is_in_group(&"toy_piece"):
			pieces += 1
	var down := 0
	for i in _house.brick_count():
		if not _house.is_standing(i):
			down += 1
	print("拆完：不站著的 %d 塊，場上碎塊 %d 個（還在場上、沒被刪）" % [down, pieces])

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("存圖 ", path)
