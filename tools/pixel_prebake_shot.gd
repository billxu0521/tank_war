extends SceneTree
## 像素風「模型先處理」的試驗：生存物資的顏色和貼圖先過 pixel_style.gd 的 grade()（色調＋換成調色盤最近色），
## 貼圖縮小、最近點取樣；畫面只留低解析度放大，不再整個畫面查色。跟現在的做法並排比。
## 在沙盒裡拍（檢視器有自己的畫面和光，像素風套不上去）：生存物資排在牛仔面前的地上。
##   MODE=screen  現在的做法（畫面查色表）
##   MODE=prebake 模型先處理＋畫面只做像素化
##   MODE=off     像素風關掉
##   MODE=prebake OUT=/tmp/pb.png godot --path . --resolution 1280x720 --script tools/pixel_prebake_shot.gd
const SURVIVALS := preload("res://models/survivals.glb")
const ITEMS := ["Campfire", "Lantern", "Backpack", "Rifle", "Axe", "StewCan", "Mug", "Matchbox", "Antler"]
const TEX_DOWN := 4   # 貼圖縮幾倍：一格貼圖在近看時大約跟畫面的一格像素一樣大
var _f := 0
var m: Node
var me: Node3D
var face: Vector3
var ps: Node


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(_d: float) -> bool:
	_f += 1
	var mode := OS.get_environment("MODE")
	if _f == 5:
		m._on_sandbox_pressed()
	if _f > 30:
		m.menu.visible = false
	if _f == 40:
		ps = m.get_node(^"PixelStyle")
		ps.on = mode != "off"
		ps.apply()
		me = m.players.get_node(^"1") as Node3D
		me.set_physics_process(false)
		face = me.rotation
		var fwd := -me.global_basis.z
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		var right := fwd.cross(Vector3.UP)
		var src := SURVIVALS.instantiate()
		for i in ITEMS.size():
			var from := src.get_node(NodePath(ITEMS[i])) as MeshInstance3D
			var mi := MeshInstance3D.new()
			mi.mesh = from.mesh
			var p: Vector3 = me.global_position + fwd * 2.6 + right * (i - (ITEMS.size() - 1) * 0.5) * 0.42
			m.add_child(mi)
			mi.global_position = m._on_ground(Vector3(p.x, 0, p.z))
			mi.look_at(mi.global_position - fwd)
			if mode == "prebake":
				_prebake(mi)
		src.free()
		if mode == "prebake":
			ps._env.adjustment_enabled = false   # 顏色已經在模型上處理過，畫面不再查色
	if _f < 40:
		return false
	me.rotation = face   # 每格鎖住：視窗抓到滑鼠會把鏡頭轉走
	me.head.rotation.x = -0.42
	if _f == 100:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		return true
	return false


func _prebake(mi: MeshInstance3D) -> void:
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
		if mat == null:
			continue
		mat = mat.duplicate()
		mat.albedo_color = ps.grade(mat.albedo_color)
		if mat.albedo_texture:
			var img: Image = mat.albedo_texture.get_image()
			img.decompress()
			img.resize(img.get_width() / TEX_DOWN, img.get_height() / TEX_DOWN, Image.INTERPOLATE_BILINEAR)
			for y in img.get_height():
				for x in img.get_width():
					img.set_pixel(x, y, ps.grade(img.get_pixel(x, y)))
			mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mi.set_surface_override_material(s, mat)
