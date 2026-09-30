extends SceneTree
## 風格檢查用的截圖：開沙盒，從幾個固定角度各拍一張（第一人稱、農莊、三種農舍、掩體石頭、往場外看遠景、恐龍近看、高處俯瞰），
## 存到 OUT 資料夾，給 tools/style_iter.sh 拼成一張給人和審查子代理看。
##   OUT=docs/image/style_iter/v1 godot --path . --resolution 1280x720 --script tools/style_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _views: Array = []
var _i := 0

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 40:
		_plan()
	if _f > 40 and (_f - 40) % 30 == 0:
		_main.menu.visible = false
		if _i > 0:
			root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%d_%s.png" % [_i, _views[_i - 1][0]])
		if _i >= _views.size():
			return true
		_main.menu.visible = false   # 視窗失去焦點時選單會跳出來，擋住畫面
		var v: Array = _views[_i]
		if v[1] != null:
			_cam.current = true
			_cam.look_at_from_position(v[1], v[2])
		_i += 1
	return false

## 找場上的東西，排好每個角度 [名字, 相機位置, 看哪裡]；null 是用玩家自己的第一人稱
func _plan() -> void:
	_cam = Camera3D.new()
	_cam.fov = 60
	root.add_child(_cam)
	var barn := _find(&"Barn")
	var rock := _find(&"Rock01")
	var dino := root.get_tree().get_first_node_in_group(&"dino") as Node3D
	var up := Vector3.UP
	_views.append(["first_person", null, null])
	if barn:
		var b := barn.global_position
		_views.append(["farm", _ground(b + Vector3(38, 0, 32)) + up * 12, b + up * 3])
	# 四個區域各一張：城鎮主街（從街口往西看）、麥田、森林小屋
	_views.append(["town", _ground(Vector3(82, 0, -46)) + up * 2.5, _ground(Vector3(20, 0, -46)) + up * 3])
	_views.append(["wheat", _ground(Vector3(-22, 0, 78)) + up * 3, _ground(Vector3(-55, 0, 36)) + up * 2])
	_views.append(["forest", _ground(Vector3(61, 0, 63)) + up * 3, _ground(Vector3(52, 0, 48)) + up * 3])
	for kind: StringName in [&"Windmill", &"HayShed"]:     # 場景小物件（kits.glb）：風車、麥田角落的倉庫
		var n := _find(kind)
		if n:
			var q := n.global_position
			_views.append([String(kind).to_lower(), _ground(q + Vector3(-9, 0, 13)) + up * 3.5, q + up * 2.5])
	if rock:
		var r := rock.global_position
		_views.append(["rock", _ground(r + Vector3(9, 0, 8)) + up * 3, r + up])
	# 遠景：站在場邊往外看（北邊中間，路一直延伸到地平線）
	var half: float = _main.ARENA * 0.5
	_views.append(["far", _ground(Vector3(10, 0, -half + 12)) + up * 2.5, _ground(Vector3(-40, 0, -half - 300)) + up * 30])
	if dino:
		var d := dino.global_position
		_views.append(["dino", _ground(d + Vector3(-8, 0, 9)) + up * 3.5, d + up * 2.5])
	_views.append(["overview", Vector3(0, 230, 1), Vector3(0, 0, 0)])   # 正上方：看四個區域

func _ground(p: Vector3) -> Vector3:
	return _main._on_ground(Vector3(p.x, 0, p.z))

func _all(mesh_name: StringName) -> Array[Node]:
	var mesh: Mesh = _main._props.get(mesh_name)
	return _main.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh == mesh)

func _find(mesh_name: StringName) -> Node3D:
	var mesh: Mesh = _main._props.get(mesh_name)
	for n in _main.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh == mesh:
			return n
	return null
