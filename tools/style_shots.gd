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
