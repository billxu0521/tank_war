extends SceneTree
## 燈油火的截圖：開沙盒，鏡頭對著乾草捲旁邊那兩盞油燈，打破一盞，拍「打破前、0.3 秒、1 秒、2.5 秒（燒滿、連鎖）、8 秒、熄滅後」。
##   OUT=/tmp/fire godot --path . --resolution 1280x720 --script tools/fire_shots.gd
const MARKS := [[0.0, "0_before"], [0.3, "1_break"], [1.0, "2_spread"], [2.5, "3_full"], [8.0, "4_burning"], [17.5, "5_out"]]

var _f := 0
var _t := -1.0
var _n := 0
var m: Node
var lamp: Node3D
var me: Node3D
var face: Vector3


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f > 60:
		m.menu.visible = false
	if _f == 90:
		me = m.players.get_node(^"1") as Node3D
		var lamps := root.get_tree().get_nodes_in_group(&"oil_lantern")
		lamp = lamps[0]
		for l: Node3D in lamps:   # 挑乾草捲旁邊那盞（離出生點右前方）
			if l.global_position.x > lamp.global_position.x:
				lamp = l
		var eye := lamp.global_position + Vector3(-4.5, 1.6, 2.5)   # 從左側看：右邊是乾草捲，從前面看會被擋住
		me.global_position = eye - Vector3.UP * 1.6
		me.look_at(Vector3(lamp.global_position.x, me.global_position.y, lamp.global_position.z))
		me.rotation.x = 0.0
		me.rotation.z = 0.0
		me.head.rotation.x = -0.25
		face = me.rotation
		me.set_physics_process(false)
		me.viewmodel.visible = false   # 拍火：槍會擋到
		_t = 0.0
	if _t < 0.0:
		return false
	me.rotation = face   # 每格鎖住：視窗抓到滑鼠會把鏡頭轉走
	me.head.rotation.x = -0.25
	_t += d
	if _n == 1 and _t >= 0.0 and not lamp.broken:
		lamp.on_shot(lamp.global_position, null, Vector3(0.3, 0, -1).normalized())
	if _n < MARKS.size() and _t >= MARKS[_n][0] + (0.05 if _n == 0 else 0.0):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % MARKS[_n][1])
		_n += 1
		if _n == 1:
			_t = 0.0
	return _n >= MARKS.size()
