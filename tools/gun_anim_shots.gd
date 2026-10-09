extends SceneTree
## 槍的連續動作截圖：腰射開槍→扳擊錘（0.4～1.5 秒）、舉槍開槍（2.5～3.6 秒）、換彈（4.2 秒起），檔名帶時間。
## 跟參考影片 docs/movie/pax.mov 對照用（扳擊錘約 7 秒、舉槍 15 秒、換彈 20～25 秒）。
##   OUT=/tmp/rev godot --path . --resolution 1280x720 --script tools/gun_anim_shots.gd
## SLOT=2 散彈、SLOT=3 步槍（預設 1 左輪）。NOPIXEL=1 關掉像素濾鏡看細節；RSTEP=0.07 換彈改成每 0.07 秒一張（只拍一發多）
var _f := 0
var _t := -1.0
var m: Node
var vm: Viewmodel
var _next := 0.0
var _n := 0
var fired := [false, false]
var reloaded := false
func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
func _shot(dt: float) -> bool:
	return (_t >= 0.4 and _t < 1.5) or (_t >= 2.5 and _t < 3.6) or (_t >= 4.2 and _t < (5.6 if OS.get_environment("RSTEP") != "" else 10.0))
func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f == 60:
		if OS.get_environment("NOPIXEL") != "":
			var ps := m.get_node(^"PixelStyle")
			ps.on = false
			ps.apply()
		vm = m.players.get_node(^"1").viewmodel
		vm.switch_weapon(int(OS.get_environment("SLOT")) - 1 if OS.get_environment("SLOT") != "" else 0)
	if _f > 60:
		m.menu.visible = false
		var me := m.players.get_node(^"1") as Node3D
		me.rotation.y = 0.0
		me.head.rotation.x = 0.0
	if _f == 140:
		_t = 0.0
	if _t < 0.0:
		return false
	_t += d
	var w := vm.weapon
	vm.ads = 1.0 if _t >= 2.0 and _t < 3.8 else 0.0
	if _t >= 0.5 and not fired[0]:
		fired[0] = true; vm._fire_cooldown = 0.0; vm.try_fire()
	if _t >= 2.6 and not fired[1]:
		fired[1] = true; vm._fire_cooldown = 0.0; vm.try_fire()
	if _t >= 4.2 and not reloaded:
		reloaded = true; w.mag = maxi(w.capacity - 3, 0); w.reserve = 30; vm.try_reload()
	var step := 0.1 if _t < 4.0 else float(OS.get_environment("RSTEP")) if OS.get_environment("RSTEP") != "" else 0.25
	if _shot(0) and _t >= _next:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%03d_t%.2f.png" % [_n, _t])
		if OS.get_environment("SKEL") != "":
			_save_bones(OS.get_environment("OUT") + "/%03d_t%.2f.json" % [_n, _t])
		_n += 1
		_next = _t + step
	return _t > 10.0


## SKEL=1：每張截圖另存一份 json，看得到的手骨架每根骨頭投影到畫面上的位置（給 tools/hand_skeleton.py 那邊畫對照圖）。
## 前臂 LowerArm 只有起點（手腕），往自己的 +Y 伸 25 公分當手肘
func _save_bones(path: String) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var vp := cam.get_viewport().get_visible_rect().size   # 3D 可能畫在另一個大小的子畫面（像素濾鏡），存比例 0～1
	var out := []
	for sk: Skeleton3D in vm.weapon.find_children("*", "Skeleton3D", true, false):
		if not sk.is_visible_in_tree():
			continue
		var bones := {}
		for i in sk.get_bone_count():
			var g := sk.global_transform * sk.get_bone_global_pose(i)
			var p := cam.unproject_position(g.origin)
			bones[sk.get_bone_name(i)] = [p.x / vp.x, p.y / vp.y, cam.is_position_behind(g.origin)]
			if sk.get_bone_name(i) == "LowerArm":
				var e := cam.unproject_position(g.origin + g.basis.y.normalized() * 0.25)
				bones["Elbow"] = [e.x / vp.x, e.y / vp.y, cam.is_position_behind(g.origin + g.basis.y.normalized() * 0.25)]
		out.append({"rig": String(sk.get_parent().name) + "/" + String(sk.name), "bones": bones})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
