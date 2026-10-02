extends SceneTree
## 恐龍進遊戲後的截圖：開沙盒，找到場上的恐龍，從側面、正面、斜前近看、稍遠（帶地面）各拍一張，存到 OUT。
## 相機每一格都重新對準恐龍（牠會走動），看得到程式動畫在蒙皮上的樣子。
##   OUT=docs/image/trex_hd_game godot --path . --resolution 1280x720 --script tools/trex_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _dino: Node3D
var _i := 0
## [名字, 相對恐龍的相機位置（恐龍本地座標，前方 -Z）, 看哪裡（本地）]
const VIEWS := [
	["side", Vector3(-16, 4, 0), Vector3(0, 3, 0)],
	["front", Vector3(0, 4, -16), Vector3(0, 3.5, 0)],
	["three_q", Vector3(-7, 5, -8), Vector3(0, 4, -2)],
	["far", Vector3(-22, 3, -20), Vector3(0, 3, 0)],
]

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 40:
		_dino = root.get_tree().get_first_node_in_group(&"dino") as Node3D
		if _dino == null:
			push_error("找不到恐龍")
			return true
		_cam = Camera3D.new()
		_cam.fov = 50
		root.add_child(_cam)
		_cam.current = true
	if _f > 40:
		_main.menu.visible = false
		var v: Array = VIEWS[_i]
		var b := _dino.global_transform
		_cam.look_at_from_position(b * v[1], b * v[2])
		if (_f - 40) % 45 == 0:
			root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%d_%s.png" % [_i, v[0]])
			_i += 1
			if _i >= VIEWS.size():
				return true
	return false
