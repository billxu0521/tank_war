extends SceneTree
## 方塊房子拍照（規則草案 4.1 試驗屋）：開單人派對，拍兩張——房子完整、尼諾拉從房子西南角甩一下之後缺一角。
## 同時印出：房子幾塊、等級各幾塊、甩一下拆掉幾塊、導航網格解析（主線程）花多久（有房子 vs 沒房子）。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/cube_house_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _house: Node3D
var _boss: Node3D
var _shot := 0
var _settle := 0
var _out := ""

func _initialize() -> void:
	_out = OS.get_environment("OUT")
	if _out == "":
		_out = "user://cube_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_solo_party_pressed()
	if _f < 60:
		return false
	if _f == 60:
		_house = _main.map._party_house
		if _house == null:
			push_error("沒有方塊房子（不是灰盒地圖？）")
			return true
		_boss = _main._boss()   # 單人派對已經生了尼諾拉
		_report_counts()
		_time_nav("有房子")
		_main.map.set_party_house(false)
		_time_nav("沒有房子")
		_main.map.set_party_house(true)
		_cam = Camera3D.new()
		_cam.fov = 50
		root.add_child(_cam)
		_cam.current = true
		_main.menu.visible = false
		_place_boss_sweep()
		return false
	# 甩一下之前先拍完整的
	if _shot == 0:
		_aim(Vector3(7, 13, 22), Vector3(0, 1.5, 0))
		_settle += 1
		if _settle >= 4:
			_save("house_full")
			_shot = 1
			_settle = 0
			_sweep()
		return false
	if _shot == 1:
		_aim(Vector3(7, 13, 22), Vector3(0, 1.5, 0))
		_settle += 1
		if _settle >= 180:   # 倒塌動畫 1.5 秒，等它落完再拍
			_save("house_after_sweep")
			_report_after()
			_shot = 2
		return false
	return true

## 鏡頭看房子：本地座標（房子中心為原點）
func _aim(from_local: Vector3, at_local: Vector3) -> void:
	var b := _house.global_transform
	_cam.current = true   # 玩家的鏡頭會搶回來，每次都設
	_cam.look_at_from_position(b * from_local, b * at_local)

## 尼諾拉站在房子西南外面（-X、-Z 那側，離 9 公尺，甩尾半徑 12 公尺夠不到遠角）、身體朝房子中心，用真正的甩尾判定拆一下
func _place_boss_sweep() -> void:
	var c := _house.global_position
	_boss.global_position = Vector3(c.x - 9.0, c.y + 4.1, c.z - 9.0)
	_boss.rotation.y = PI * 0.25   # 身體朝 (+X, +Z)，後方（+Z 那一側）是房子

func _sweep() -> void:
	var t0 := Time.get_ticks_usec()
	_boss._strike_sweep()
	print("甩一下（含拆塊、重烘導航）主線程花 %.1f 毫秒" % ((Time.get_ticks_usec() - t0) / 1000.0))

func _report_counts() -> void:
	var by := {1: 0, 2: 0, 3: 0}
	var n := 0
	for w in _house.get_children():
		if w is Destructible:
			n += 1
			by[w.level] += 1
	print("方塊房子 %d 塊：等級 1 有 %d、2 有 %d、3 有 %d" % [n, by[1], by[2], by[3]])

func _report_after() -> void:
	var down := 0
	var hit := 0
	for w in _house.get_children():
		if w is Destructible:
			if w.hits > 0:
				hit += 1
			if w.collision_layer == 0:
				down += 1
	print("甩一下之後：挨到 %d 塊、倒下 %d 塊（剩下的照等級站著）" % [hit, down])

## 導航網格的解析（烘焙前在主線程做的那一段）花多久：有房子跟沒房子各量一次
func _time_nav(label: String) -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 2.4
	nm.agent_height = 8.0
	nm.agent_max_climb = 0.9
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	var src := NavigationMeshSourceGeometryData3D.new()
	var t0 := Time.get_ticks_usec()
	NavigationServer3D.parse_source_geometry_data(nm, src, _main.get_node(^"Arena"))
	print("導航網格解析（%s）：%.1f 毫秒" % [label, (Time.get_ticks_usec() - t0) / 1000.0])

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("存圖 ", path)
