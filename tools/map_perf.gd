extends SceneTree
## 量一張地圖的負擔（docs/技術筆記/農莊效能改善.md）：載入時間、場上有多少東西、站在幾個位置各要畫多少、物理一步多久、炸一輪之後多久。
##   godot --path . --resolution 1920x1080 --script tools/map_perf.gd                農莊（主地圖），有畫面：多印每個角度的繪製指令
##   godot --path . --resolution 1920x1080 --script tools/map_perf.gd -- --greybox   舊灰盒對照
##   godot --headless --path . --script tools/map_perf.gd                            沒畫面：只有清點、載入、物理
## BLAST=1：量完再在場上 5×5 個點各炸一次（照 ToyBuild.blast 的範圍、力道 2，半徑 8 公尺），印最慢的一步和炸完的物理。
## SHOTS=資料夾：每個角度量完存一張截圖。FARM_SHADOW_BATCH=0：不合併影子（量改前）。
## 開的是離線、只有自己一個牛仔的場（不呼叫沙盒：沙盒的柵欄、乾草捲是舊牧場地圖的函式）。
## 最後印「MAP_PERF OK」（Godot 解析錯誤也回 0，要看這行）。

const SETTLE := 20        # 換角度後先等幾幀
const SAMPLE := 60        # 每個角度量幾幀
const IDLE_SECS := 3.0    # 物理量幾秒
const BLAST_SECS := 8.0

var _m: Node
var _f := 0
var _t_boot := 0
var _cam: Camera3D
var _views: Array = []    # [名字, 位置, 看哪裡]
var _i := -1
var _vf := 0
var _rec := {}
var _last_us := 0
var _stage := &"boot"
var _t := 0.0
var _ps := -1             # 這一幀第一個物理步開始（微秒）
var _ticks := 0
var _steps: PackedFloat32Array = []   # 每個物理步多久（毫秒；腳本的物理＋物理引擎）
var _headless := DisplayServer.get_name() == "headless"
var _box := AABB()
var _sum := {}        # 各角度加總、最大（最後印平均和最重）
var _max := {}


func _initialize() -> void:
	_t_boot = Time.get_ticks_usec()
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _physics_process(_d: float) -> bool:
	if _ps < 0:
		_ps = Time.get_ticks_usec()
	_ticks += 1
	return false


func _process(d: float) -> bool:
	if _ps >= 0:
		if _stage in [&"idle", &"blast", &"after"]:
			_steps.append((Time.get_ticks_usec() - _ps) / 1000.0 / _ticks)
		_ps = -1
		_ticks = 0
	_f += 1
	if _f == 3:
		print("載入：開始到第 3 幀 %.0f 毫秒（檔案系統快取是熱的）" % ((Time.get_ticks_usec() - _t_boot) / 1000.0))
		_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_m._offline = true
		_m._enter_game("map_perf")
		var me: Node3D = _m._add_player(_m.COWBOY, 1)
		me.global_position = _m._on_ground(Vector3(0, 0.5, 0)) + Vector3.UP
	if _f < 90:   # 農莊有些東西晚幾幀才裝好（registry.finish_environment）
		return false
	if _f == 90:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_m.menu.visible = false
		_census()
		_stage = &"idle"
		return false
	_t += d
	match _stage:
		&"idle":
			if _t >= IDLE_SECS:
				_phys_report("沒人動")
				_stage = &"done" if _headless else &"views"
				if not _headless:
					_plan()
		&"views":
			_view_step()
		&"done":
			if OS.get_environment("BLAST") == "":
				print("MAP_PERF OK")
				return true
			var t0 := Time.get_ticks_usec()
			for ix in 5:
				for iz in 5:
					var at := Vector3(_box.position.x + _box.size.x * (0.2 + 0.15 * ix), 0, _box.position.z + _box.size.z * (0.2 + 0.15 * iz))
					_blast(_m._on_ground(at) + Vector3.UP, 8.0)
			print("炸 25 個點：呼叫本身 %.1f 毫秒" % ((Time.get_ticks_usec() - t0) / 1000.0))
			_stage = &"blast"
			_t = 0.0
		&"blast":
			if _t >= BLAST_SECS:
				_phys_report("炸完 %d 秒內" % BLAST_SECS)
				_bodies("炸完")
				_stage = &"after"
				_t = 0.0
		&"after":   # 碎塊都停下來之後還剩多少
			if _t >= IDLE_SECS:
				_phys_report("炸完都停了")
				print("MAP_PERF OK")
				return true
	return false


## 照 ToyBuild.blast 拆，但力道 2（甩尾、火球那一級：木頭、磚都拆；炸藥的力道 1 拆不了多少）
func _blast(at: Vector3, radius: float) -> void:
	for w: Node in get_nodes_in_group(&"destructible"):
		if w is ToyBuild:
			(w as ToyBuild).smash(func(p: Vector3) -> bool: return p.distance_to(at) < radius, 2, at, AABB(at - Vector3.ONE * radius, Vector3.ONE * radius * 2.0), ToyBuild.FALL_SPEED, 9)
	for reg: Node in get_nodes_in_group(&"farm_destruction"):
		for k in 3:   # 耐久最多 2～3 下
			reg.blast(at, radius, 2)


func _phys_report(label: String) -> void:
	var a := Array(_steps)
	a.sort()
	if a.is_empty():
		return
	print("物理一步（%s，每秒 %d 步）：平均 %.3f 毫秒、最慢 1%% %.3f、最慢 %.3f；活動中的物體 %d、碰撞對 %d" % [label, Engine.physics_ticks_per_second,
		a.reduce(func(x, y): return x + y, 0.0) / a.size(), a[int(a.size() * 0.99)], a[-1],
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)])
	_steps.clear()


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var n: int = mesh.surface_get_array_index_len(s)
			t += (n if n > 0 else mesh.surface_get_array_len(s)) / 3
		else:
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _bodies(label: String) -> void:
	var kinds := {}
	var shapes := {}
	var off := 0
	for n in root.find_children("*", "CollisionObject3D", true, false):
		kinds[n.get_class()] = kinds.get(n.get_class(), 0) + 1
	for n: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		if n.disabled:
			off += 1
		elif n.shape != null:
			shapes[n.shape.get_class()] = shapes.get(n.shape.get_class(), 0) + 1
	print("碰撞（%s）：物體 %s；啟用的形狀 %s；停用的形狀 %d" % [label, kinds, shapes, off])


## 場上有多少東西（不管看不看得到）
func _census() -> void:
	var meshes := {}       # 網格 -> 三角形
	var mats := {}
	var by := {}           # 第一層（Arena 底下的子節點名）-> [節點數, 段數, 三角形]
	var inst := 0
	var surf := 0
	var tri := 0
	var shadow := 0
	var ranged := 0
	var mm_nodes := 0
	var mm_inst := 0
	for n: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var count := 1
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			count = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if mesh == null or not n.is_visible_in_tree():
			continue
		if n is MultiMeshInstance3D:
			mm_nodes += 1
			mm_inst += count
		if not meshes.has(mesh):
			meshes[mesh] = _tris(mesh)
		_box = n.global_transform * n.get_aabb() if inst == 0 else _box.merge(n.global_transform * n.get_aabb())
		inst += 1
		surf += mesh.get_surface_count()
		tri += meshes[mesh] * count
		shadow += int(n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		ranged += int(n.visibility_range_end > 0.0)
		for s in mesh.get_surface_count():
			var mat: Material = n.material_override
			if mat == null:
				mat = (n as MeshInstance3D).get_active_material(s) if n is MeshInstance3D else mesh.surface_get_material(s)
			mats[mat] = true
		var top: Node = n
		while top.get_parent() != null and top.get_parent() != _m.map and top.get_parent() != root:
			top = top.get_parent()
		var e: Array = by.get(top.name, [0, 0, 0])
		e[0] += 1; e[1] += mesh.get_surface_count(); e[2] += meshes[mesh] * count
		by[top.name] = e
	# 玩法的範圍比畫面的邊界框小（遠景、天空）：拿碰撞形狀的範圍當場地
	var play := AABB()
	var first := true
	for n: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		if n.shape is BoxShape3D or n.shape is ConvexPolygonShape3D:
			play = AABB(n.global_position, Vector3.ZERO) if first else play.expand(n.global_position)
			first = false
	if not first:
		_box = play
	print("清點：節點 %d；會畫的節點 %d（藏起來的不算；其中 MultiMesh %d 個、共 %d 份）；材質段 %d；不同的網格 %d；不同的材質 %d；三角形 %.1f 萬；投影子的 %d；有設遠處不畫的 %d；燈 %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		inst, mm_nodes, mm_inst, surf, meshes.size(), mats.size(), tri / 10000.0, shadow, ranged, root.find_children("*", "Light3D", true, false).size()])
	_bodies("開場")
	var reg := get_first_node_in_group(&"farm_destruction")
	if reg != null:
		print("可破壞：農莊登記 %d 個單位（%d 個碰撞形狀）" % [reg.entries.size(), reg.by_shape.size()])
	var toys := root.find_children("*", "ToyBuild", true, false)
	var bricks := 0
	for t: ToyBuild in toys:
		bricks += t._xf.size()
	print("可破壞：積木 %d 棟、%d 塊" % [toys.size(), bricks])
	print("記憶體：一般 %.0f MB、顯示卡 %.0f MB（貼圖 %.0f MB）；場地範圍 %s" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, _box])
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a][1] > by[b][1])
	for k in keys.slice(0, 15):
		print("  群 %-34s 節點 %5d  材質段 %5d  三角形 %.1f 萬" % [k, by[k][0], by[k][1], by[k][2] / 10000.0])


## 排角度：場地中心往外 30%、八個方向，站在地上往中心看；再加一個從角落高處看全場
func _plan() -> void:
	var old := root.get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	if old != null:
		_cam.fov = old.fov
		_cam.far = old.far
		_cam.near = old.near
	root.add_child(_cam)
	_cam.current = true
	var c := _box.get_center() * Vector3(1, 0, 1)
	c = _m._on_ground(c)
	var r := minf(_box.size.x, _box.size.z) * 0.3
	for k in 8:
		var dir := Vector3(cos(k * TAU / 8), 0, sin(k * TAU / 8))
		var at: Vector3 = _m._on_ground(Vector3(c.x, 0, c.z) + dir * r) + Vector3.UP * 1.7
		_views.append(["往中心 %d°" % (k * 45), at, Vector3(c.x, at.y, c.z)])
		_views.append(["往外 %d°" % (k * 45), _m._on_ground(Vector3(c.x, 0, c.z) + dir * r * 0.3) + Vector3.UP * 1.7, at])
	_views.append(["高處看全場", c + Vector3(r * 1.6, 40, r * 1.6), c])
	print("角度            幀ms   畫面draw  畫面三角形(萬)  影子draw  影子三角形(萬)  畫面物件")


func _view_step() -> void:
	_m.menu.visible = false
	var vp := root.get_viewport_rid()
	if _i < 0 or _vf >= SETTLE + SAMPLE:
		if _i >= 0:
			var avg := func(k: String) -> float: return (_rec[k] as Array).reduce(func(x, y): return x + y, 0.0) / SAMPLE
			print("VIEW %-12s %5.2f  %6.0f  %8.1f  %8.0f  %8.1f  %6.0f" % [_views[_i][0], avg.call("dt"), avg.call("vd"), avg.call("vt") / 10000.0, avg.call("sd"), avg.call("st") / 10000.0, avg.call("vo")])
			if OS.get_environment("SHOTS") != "":   # 存每個角度的截圖（改前改後疊圖用）
				DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOTS"))
				root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS").path_join("%02d.png" % _i))
			for k in _rec:
				_sum[k] = _sum.get(k, 0.0) + avg.call(k)
				_max[k] = maxf(_max.get(k, 0.0), avg.call(k))
		_i += 1
		_vf = 0
		_rec = {"dt": [], "vd": [], "vt": [], "sd": [], "st": [], "vo": []}
		if _i >= _views.size():
			var n := float(_views.size())
			print("VIEW 平均       %5.2f  %6.0f  %8.1f  %8.0f  %8.1f  %6.0f" % [_sum.dt / n, _sum.vd / n, _sum.vt / n / 10000.0, _sum.sd / n, _sum.st / n / 10000.0, _sum.vo / n])
			print("VIEW 最重       %5.2f  %6.0f  %8.1f  %8.0f  %8.1f  %6.0f" % [_max.dt, _max.vd, _max.vt / 10000.0, _max.sd, _max.st / 10000.0, _max.vo])
			_stage = &"done"
			return
		_cam.current = true
		_cam.look_at_from_position(_views[_i][1], _views[_i][2])
		return
	_vf += 1
	var now := Time.get_ticks_usec()
	if _vf > SETTLE:
		var V := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
		var S := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
		_rec.dt.append((now - _last_us) / 1000.0)
		_rec.vd.append(RenderingServer.viewport_get_render_info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		_rec.vt.append(RenderingServer.viewport_get_render_info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		_rec.sd.append(RenderingServer.viewport_get_render_info(vp, S, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		_rec.st.append(RenderingServer.viewport_get_render_info(vp, S, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		_rec.vo.append(RenderingServer.viewport_get_render_info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	_last_us = now

