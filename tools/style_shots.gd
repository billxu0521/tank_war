extends SceneTree
## 風格檢查用的截圖：開沙盒，從幾個固定角度各拍一張（第一人稱、農莊、三種農舍、掩體石頭、往場外看遠景、恐龍近看、高處俯瞰），
## 存到 OUT 資料夾，給 tools/style_iter.sh 拼成一張給人和審查子代理看。
##   OUT=docs/image/style_iter/v1 godot --path . --resolution 1280x720 --script tools/style_shots.gd
## 量效能：PERF=秒數，每個角度停這麼久（前 0.5 秒不算），關垂直同步、不限幀率，印出每個角度的幀時間、GPU、CPU、畫幾次（draw call）。不存圖
##   PERF=3 godot --path . --resolution 1920x1080 --script tools/style_shots.gd

var _f := 0
var _main: Node
var _cam: Camera3D
var _views: Array = []
var _i := 0
var _perf := OS.get_environment("PERF").to_float()
var _t := 0.0
var _rec := {}   # 這個角度量到的每一幀
var _last_us := 0

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _perf > 0.0:
		return _perf_step(_d)
	if _f == 5:
		if OS.get_environment("PERIOD") != "":   # PERIOD=noon / midnight：拍那個時段（period.gd）
			Period.apply(_main, StringName(OS.get_environment("PERIOD")))
		_main._on_sandbox_pressed()
	if _f == 40:
		_plan()
		# SHADER="paint_radius=5,ramp_steps=0"：拍之前改描線／風格 shader（outline.gdshader）的參數，比對用
		var mat: ShaderMaterial = (_main.get_node(^"Arena/Outline") as MeshInstance3D).mesh.material
		for kv in OS.get_environment("SHADER").split(",", false):
			mat.set_shader_parameter(kv.get_slice("=", 0), kv.get_slice("=", 1).to_float())
		# FACET="ramp_steps=0"：共用材質（facet.gdshader）的參數，每個換過的材質都改
		for f: ShaderMaterial in _main.get_script()._facet_of.values():
			for kv in OS.get_environment("FACET").split(",", false):
				f.set_shader_parameter(kv.get_slice("=", 0), kv.get_slice("=", 1).to_float())
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
	_views.append(["forest_edge", _ground(Vector3(12, 0, 12)) + up * 3, _ground(Vector3(45, 0, 40)) + up * 4])
	# 城鎮店面後面的荒漠植被（tools/plant_flora.gd 種的仙人掌、約書亞樹，main.gd _flora_field 撒的草叢）
	_views.append(["desert_n", _ground(Vector3(66, 0, -80)) + up * 2.5, _ground(Vector3(20, 0, -76)) + up * 2])
	_views.append(["desert_s", _ground(Vector3(14, 0, -12)) + up * 2.5, _ground(Vector3(60, 0, -16)) + up * 2])
	# 葉片卡的樹近看（blender/grove.py）：場上的都被別的樹擋住，在空的靶場臨時種一棵楓樹、一棵闊葉樹並排拍
	var spot := _ground(Vector3(-12, 0, 60))
	for k: Array in [[&"TreeMaple", Vector3(-4, 0, 0)], [&"TreeOak", Vector3(5, 0, 0)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _main._props[k[0]]
		_main.get_node(^"Arena").add_child(mi)
		mi.global_position = _ground(spot + k[1])
	_views.append(["maple", spot + Vector3(0, 2.5, 20), spot + up * 4.5])
	# 灌木叢近看：空的靶場臨時擺兩叢（葉片卡版，props.py 的 Bush）
	var bspot := _ground(Vector3(-30, 0, 40))
	for off: Vector3 in [Vector3(-1.6, 0, 0), Vector3(1.8, 0, 0.8)]:
		var bmi := MeshInstance3D.new()
		bmi.mesh = _main._props[&"Bush"]
		_main.get_node(^"Arena").add_child(bmi)
		bmi.global_position = _ground(bspot + off)
	_views.append(["bush", bspot + Vector3(0, 1.6, 6.5), bspot + up * 0.8])
	# 場上撒的灌木（MultiMesh 那批）：挑離農莊最近的一叢，從 6 公尺外、背光和順光各拍一張
	if not _main._bushes.is_empty():
		var fb: Vector3 = _main._bushes[0]
		for b: Vector3 in _main._bushes:
			if b.length() < fb.length():
				fb = b
		fb = _ground(fb)
		_views.append(["field_bush_a", fb + Vector3(6, 1.6, 0), fb + up * 0.6])
		_views.append(["field_bush_b", fb + Vector3(-6, 1.6, 0), fb + up * 0.6])
	# 環境小物件（main.gd _clutter_field）：每種挑第一個，從 6 公尺外眼睛高度看
	var seen := {}
	for c: Array in _main.clutter_spots:
		if seen.has(c[0]):
			continue
		seen[c[0]] = true
		var at: Vector3 = c[1]
		var yaw: float = c[2]   # 從物件的正面斜 35 度看（正面 = 自己的 +Z）
		var dir := Vector3(sin(yaw + 0.6), 0, cos(yaw + 0.6))
		var eye := _ground(at + dir * 5.0) + up * 1.6
		_views.append(["clutter_" + String(c[0]), eye, at + up * 0.6])
		if c[0] == &"DinoSkull":   # 頭骨另外從側面（自己的 +X 方向，模型沿 X 長）近拍
			var side := Vector3(cos(yaw), 0, -sin(yaw))
			_views.append(["clutter_DinoSkull_side", _ground(at - side.cross(Vector3.UP) * 4.5) + up * 1.2, at + up * 0.6])
	# 地面材質（main.gd _ground_mix）：每種找一塊權重最高的地，從 6 公尺外、2.5 公尺高往下看
	var best := [[-1.0, Vector2()], [-1.0, Vector2()], [-1.0, Vector2()], [-1.0, Vector2()]]
	var cover := [0, 0, 0, 0]
	for gx in range(-80, 81, 3):
		for gz in range(-80, 81, 3):
			var w: Color = _main._ground_mix(gx, gz, _main._terrain.height(gx, gz))
			var arr := [w.r, w.g, w.b, w.a]
			for k in 4:
				if arr[k] > 0.5:
					cover[k] += 1
				if arr[k] > best[k][0]:
					best[k] = [arr[k], Vector2(gx, gz)]
	var names := ["gravel", "clay", "mud", "outcrop"]
	for k in 4:
		print("ground ", names[k], " 覆蓋 ", snappedf(cover[k] * 9.0 / (161.0 * 161.0) * 100.0, 0.1), "% 最高 ", snappedf(best[k][0], 0.01), " 在 ", best[k][1])
		var g: Vector2 = best[k][1]
		var at := _ground(Vector3(g.x, 0, g.y))
		_views.append(["ground_" + names[k], at + Vector3(2.5, 3.5, 2.5), at])   # 往下約 45 度
	# 地被（main.gd _groundcover_field）：每種挑最靠近場中央的一塊，蹲高 1 公尺、3 公尺外往下看
	var gcs := {}
	for mmi: MultiMeshInstance3D in _main.get_node(^"Arena").find_children("*", "MultiMeshInstance3D", true, false):
		var mesh: Mesh = mmi.multimesh.mesh
		if mmi.material_override == null or (mmi.material_override as ShaderMaterial).shader != _main.GROUNDCOVER_SHADER or mmi.multimesh.instance_count < 20:
			continue
		var k := mesh.get_instance_id()
		var p: Vector3 = mmi.position + mmi.multimesh.get_instance_transform(0).origin
		if not gcs.has(k) or p.length() < (gcs[k] as Vector3).length():
			gcs[k] = p
	var gi := 0
	for k in gcs:
		var p: Vector3 = gcs[k]
		_views.append(["groundcover_%d" % gi, p + Vector3(2.5, 1.0, 2.5), p])
		gi += 1
	# 站在麥田邊、眼睛高度（1.6）往麥田裡看：麥子要比人高
	var wf := _ground(Vector3(-56, 0, 44))   # 田中間那條車輪痕上，往田裡看
	_views.append(["wheat_eye", wf + Vector3(0, 1.6, 0), wf + Vector3(-2, 1.6, 10)])
	_views.append(["wheat_inside", _ground(Vector3(-60, 0, 54)) + Vector3(0, 1.6, 0), _ground(Vector3(-70, 0, 56)) + Vector3(0, 1.6, 0)])
	# 草葉近看（蹲著、鏡頭貼近草地往前看）：grass.gdshader 的像素草葉
	_views.append(["grass_low", _ground(Vector3(-30, 0, 10)) + up * 0.6, _ground(Vector3(-40, 0, 10)) + up * 0.3])
	_views.append(["oak_close", spot + Vector3(3, 3.5, 9), spot + Vector3(5, 6.5, 0)])   # 近看葉子
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


## 效能模式：跟拍照同樣的角度，每個停 _perf 秒
func _perf_step(d: float) -> bool:
	if _f == 2:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f < 40:
		return false
	if _f == 40:
		# SUN="directional_shadow_max_distance=60,directional_shadow_mode=1"：改太陽（影子）的設定比較
		var sun := _main.get_node(^"Arena/Sun")
		for kv in OS.get_environment("SUN").split(",", false):
			sun.set(kv.get_slice("=", 0), str_to_var(kv.get_slice("=", 1)))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # 遊戲開局時會套用玩家的畫面設定（main.gd），再關一次
		Engine.max_fps = 0
		_plan()
		print("角度              平均ms  最慢1%%ms  最慢ms   GPU ms  CPU畫面ms  腳本ms  物理ms  draw  三角形(萬)")
		_i = -1
	_main.menu.visible = false
	_t += d
	if _i < 0 or _t >= _perf:
		if _i >= 0:
			_perf_report(_views[_i][0])
		_i += 1
		_t = 0.0
		_rec = {"dt": [], "gpu": [], "cpu": [], "proc": [], "phys": [], "draw": [], "tri": []}
		if _i >= _views.size():
			return true
		var v: Array = _views[_i]
		if v[1] != null:   # 第一個是第一人稱（null），還沒換相機
			_cam.current = true
			_cam.look_at_from_position(v[1], v[2])
		return false
	var now := Time.get_ticks_usec()
	var real_ms := (now - _last_us) / 1000.0   # 真的時鐘量兩幀之間（引擎給的 delta 有上下限，不準）
	_last_us = now
	if _t > 0.5:
		var vp := root.get_viewport_rid()
		_rec.dt.append(real_ms)
		_rec.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_rec.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		_rec.proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_rec.phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_rec.draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_rec.tri.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return false

func _perf_report(name: String) -> void:
	var dt: Array = _rec.dt.duplicate()
	if dt.is_empty():
		return
	dt.sort()
	var avg := func(a: Array) -> float: return a.reduce(func(x, y): return x + y, 0.0) / maxf(a.size(), 1)
	var p99: float = dt[int(dt.size() * 0.99)]
	var vp := root.get_viewport_rid()
	var info := func(t: int, k: int) -> int: return RenderingServer.viewport_get_render_info(vp, t, k)
	print("%-16s 畫面 draw %d 三角形 %.0f 萬｜影子 draw %d 三角形 %.0f 萬" % [name,
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 10000.0,
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 10000.0])
	print("%-16s %7.2f %9.2f %7.2f %8.2f %9.2f %7.2f %7.2f %5d %8.1f" % [name, avg.call(dt), p99, dt[-1],
		avg.call(_rec.gpu), avg.call(_rec.cpu), avg.call(_rec.proc), avg.call(_rec.phys), int(avg.call(_rec.draw)), avg.call(_rec.tri) / 10000.0])
