extends SceneTree
## 檢視模式「4 生存物資」的截圖：正面一張、拉近每排各一張，看遊戲燈光下的樣子。
##   OUT=/tmp/sv godot --path . --resolution 1280x720 --script tools/survival_viewer_shot.gd
const SHOTS := [[0.7, 0.35, 3.2, Vector3(0, 0.25, 0.5), "0_all"], [0.5, 0.4, 1.6, Vector3(0, 0.25, 0), "1_back"],
	[0.5, 0.45, 1.5, Vector3(0, 0.1, 1.0), "2_front"]]
var _f := 0
var v: ModelViewer


func _initialize() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		root.get_node(^"Main")._on_viewer_pressed()
	if _f == 10:
		v = root.find_children("*", "ModelViewer", true, false)[0]
		v._select("survival")
		v._moving = false
	var i := (_f - 30) / 20
	if _f >= 30 and (_f - 30) % 20 == 0 and i < SHOTS.size():
		var s: Array = SHOTS[i]
		v._yaw = s[0]; v._pitch = s[1]; v._dist = s[2]; v._focus = s[3]
	if _f >= 30 and (_f - 30) % 20 == 19 and i < SHOTS.size():
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % SHOTS[i][4])
	return _f > 30 + SHOTS.size() * 20
