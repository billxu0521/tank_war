extends SceneTree
## 丟炸藥的第一人稱截圖：開沙盒，按住 G 點燃、放開丟出去，拍「拿起來、拿著、甩出去、收回、落地爆炸」，存到 OUT。
## 調手的姿勢（Viewmodel 的 STICK_* 常數）時用
##   OUT=/tmp/dyn godot --path . --resolution 1280x720 --script tools/dynamite_shots.gd

var _f := 0
var _t := -1.0
var m: Node
var vm: Viewmodel
var _n := 0
const MARKS := [[0.08, "raise"], [0.5, "hold"], [0.86, "throw_a"], [0.92, "throw_b"], [1.05, "after"], [4.05, "boom"], [4.3, "boom_0.3s"], [5.0, "boom_1s"]]


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f > 60:
		m.menu.visible = false
	if _f == 100:
		vm = m.players.get_node(^"1").viewmodel
		(m.players.get_node(^"1") as Node3D).head.rotation.x = -0.12
		Input.action_press("throw")
		vm._light_dynamite()
		_t = 0.0
	if _t < 0.0:
		return false
	_t += d
	if _t > 0.8:
		Input.action_release("throw")
	if _n < MARKS.size() and _t >= MARKS[_n][0]:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%d_%s.png" % [_n, MARKS[_n][1]])
		_n += 1
	return _n >= MARKS.size()
