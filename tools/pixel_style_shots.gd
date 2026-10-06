extends SceneTree
## 像素風的對照截圖：開沙盒，站在農舍右後方面向夕陽、手上拿槍，拍一張。
##   STYLE=1 OUT=/tmp/on.png godot --path . --resolution 1280x720 --script tools/pixel_style_shots.gd
## STYLE=0 拍關掉的；AIM_SUN=0 正對太陽（數字是鏡頭再往上抬幾弧度）；PIXEL="pixel=4,levels=8,saturation=1.3" 改 pixel_style.gd 的參數（不存檔）
## 拍完存參考圖並排：magick docs/image/survival_style.png -resize x720 on.png +append out.png

var _f := 0
var m: Node
var me: Node3D
var face: Vector3
var sun_pitch := -10.0


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f > 30:
		m.menu.visible = false
	if _f == 40:
		var ps: Node = m.get_node(^"PixelStyle")
		ps.on = OS.get_environment("STYLE") != "0"
		for kv in OS.get_environment("PIXEL").split(",", false):
			ps.set(kv.get_slice("=", 0), kv.get_slice("=", 1).to_float())
		ps.apply()
		me = m.players.get_node(^"1") as Node3D
		var sun: Node3D = m.get_node(^"Arena/Sun")
		var f := sun.global_basis.z
		f = Vector3(f.x, 0, f.z).normalized()   # 往太陽的水平方向
		var left := Vector3.UP.cross(f)
		var barn := _find(&"Barn")
		var at: Vector3 = barn.global_position - left * 22.0 - f * 30.0 if barn else me.global_position
		at = m._on_ground(Vector3(at.x, 0, at.z))
		me.global_position = at
		me.look_at(at + f)
		face = Vector3(0, me.rotation.y + OS.get_environment("YAW").to_float() - 0.3, 0)   # 往左一點，農舍進畫面；YAW=0.3 正對太陽
		if OS.get_environment("AIM_SUN") != "":   # 正對太陽：看光暈（浮高 8 公尺，越過農舍；物理關掉不會掉）
			var d := sun.global_basis.z
			at += Vector3.UP * 8.0
			me.global_position = at
			me.look_at(at + Vector3(d.x, 0, d.z))
			face = me.rotation
			sun_pitch = asin(d.y) + OS.get_environment("AIM_SUN").to_float()
		me.set_physics_process(false)
	if _f < 40:
		return false
	me.rotation = face   # 每格鎖住：視窗抓到滑鼠會把鏡頭轉走
	me.head.rotation.x = sun_pitch if sun_pitch > -9.0 else (0.18 if OS.get_environment("PITCH") == "" else OS.get_environment("PITCH").to_float())
	if _f == 100:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		return true
	return false


func _find(mesh_name: StringName) -> Node3D:
	var mesh: Mesh = m._props.get(mesh_name)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh == mesh:
			return n
	return null
