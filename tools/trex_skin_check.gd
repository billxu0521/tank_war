extends SceneTree
## 尼諾拉的皮跟著骨頭動得好不好（trex_walk_check 只量骨頭，這支量皮）：
## 走 → 跑 → 原地轉身 → 每一招 → 抬頭低頭，每一幀用骨頭姿勢自己算一遍蒙皮（跟顯示卡算的一樣），量
##   拉長：每條邊現在長度 ÷ 靜止長度，最大是多少、在哪根骨頭管的地方
##   壓扁：同上取最小
##   穿地：皮最低的點比地面低多少
## 結果按骨頭列出最差的幾根。godot --headless --fixed-fps 60 --path . --script tools/trex_skin_check.gd
## （一定要 --fixed-fps：自己算蒙皮很慢，不固定的話一幀的時間會很長，恐龍會被當成瞬移）
## 門檻寫在 _report()；超過回傳 1

const WALK := 4.0
const RUN := 11.0
const ACTS := [[1, "咬預備"], [2, "咬"], [7, "收招"], [3, "蓄力長吼"], [5, "撲擊預備"], [6, "撲出去"], [8, "被打斷"], [9, "發現人"], [4, "甩尾"]]
var _t := 0.0
var _rig: Node3D
var _trex: Trex
var _mi: MeshInstance3D
var _pos: PackedVector3Array
var _bones: PackedInt32Array   # 每個頂點 _nw 根骨頭（skin bind 編號）
var _wts: PackedFloat32Array
var _nw := 4
var _edges: PackedInt32Array   # 兩兩一組
var _rest_len: PackedFloat32Array
var _owner: PackedInt32Array   # 每條邊歸哪根骨頭管（兩端權重最大的那根）
var _bind_bone: PackedInt32Array
var _stretch := {}             # 骨頭名 -> [最大比例, 時間, 段落]
var _squash := {}
var _sink := 0.0
var _sink_at := ""
var _sink_by := {}   # 每段動作最深穿地 [公尺, 骨頭]
var _stage := ""
var _cam: Camera3D
var _shots := []


func _initialize() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	root.add_child(floor_body)
	_rig = Node3D.new()   # 跟 boss.tscn 一樣
	_rig.position = Vector3(0, 4.05, 0)
	root.add_child(_rig)
	_trex = (load("res://trex.gd") as GDScript).new()
	_trex.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.5), Vector3(0, -4.05, 0))
	_rig.add_child(_trex)
	if DisplayServer.get_name() != "headless":   # SHOTS=11.6,21.5 OUT=資料夾：在這些時間拍側面
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.85, 0.85, 0.83)
		env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.7, -0.8, 0)
		root.add_child(sun)
		var ground := MeshInstance3D.new()
		ground.mesh = PlaneMesh.new()
		ground.mesh.size = Vector2(400, 400)
		root.add_child(ground)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = 12.0
		root.add_child(_cam)
		_cam.current = true
		for x in OS.get_environment("SHOTS").split(",", false):
			_shots.append(float(x))


func _setup() -> void:
	for n in _trex.find_children("*", "MeshInstance3D", true, false):
		if n.skin and (_mi == null or n.mesh.get_faces().size() > _mi.mesh.get_faces().size()):
			_mi = n
	var arr: Array = _mi.mesh.surface_get_arrays(0)
	# 多個材質＝多個面組；全部合起來，頂點編號往後接
	var idx := PackedInt32Array()
	_nw = 8 if _mi.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
	for s in _mi.mesh.get_surface_count():
		var a: Array = _mi.mesh.surface_get_arrays(s)
		var base := _pos.size()
		_pos.append_array(a[Mesh.ARRAY_VERTEX])
		_bones.append_array(a[Mesh.ARRAY_BONES])
		_wts.append_array(a[Mesh.ARRAY_WEIGHTS])
		for i in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
	# 同一個位置的頂點（切 UV、切法線分開的）焊回同一個，邊才連得起來
	var weld := {}
	var remap := PackedInt32Array()
	remap.resize(_pos.size())
	for i in _pos.size():
		var key := Vector3i((_pos[i] * 10000.0).round())
		if not weld.has(key):
			weld[key] = i
		remap[i] = weld[key]
	var seen := {}
	for f in idx.size() / 3:
		for e in 3:
			var a := remap[idx[f * 3 + e]]
			var b := remap[idx[f * 3 + (e + 1) % 3]]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if seen.has(key) or a == b:
				continue
			seen[key] = true
			_edges.append(key.x)
			_edges.append(key.y)
			_rest_len.append(_pos[a].distance_to(_pos[b]))
	var skin := _mi.skin
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		_bind_bone.append(_trex.skel.find_bone(bn) if bn != "" else skin.get_bind_bone(i))
	for e in _rest_len.size():
		_owner.append(_bind_bone[_top(_edges[e * 2])])
	# 自我檢查：骨頭全回靜止姿勢時，自己算的蒙皮要等於模型原本的位置（算錯就什麼都不準）
	_trex.skel.reset_bone_poses()
	var sp := _skinned()
	var err := 0.0
	for v in _pos.size():
		err = maxf(err, sp[v].distance_to(_mi.global_transform * _pos[v]))
	print("蒙皮：%d 頂點、%d 條邊、每點 %d 根骨頭；靜止姿勢自算誤差 %.4f 公尺" % [_pos.size(), _rest_len.size(), _nw, err])


## 這條邊在靜止模型上的哪裡（模型座標：x 左右、y 高、z 前後，前方是 -z）
func _where(e: int) -> Vector3:
	return ((_pos[_edges[e * 2]] + _pos[_edges[e * 2 + 1]]) * 0.5).snapped(Vector3.ONE * 0.01)

func _top(v: int) -> int:
	var best := 0
	for k in _nw:
		if _wts[v * _nw + k] > _wts[v * _nw + best]:
			best = k
	return _bones[v * _nw + best]


func _skinned() -> PackedVector3Array:
	var mats := []
	var skin := _mi.skin
	var sk := _trex.skel
	for i in skin.get_bind_count():
		mats.append(sk.global_transform * sk.get_bone_global_pose(_bind_bone[i]) * skin.get_bind_pose(i))
	var out := PackedVector3Array()
	out.resize(_pos.size())
	for v in _pos.size():
		var p := Vector3.ZERO
		for k in _nw:
			var w := _wts[v * _nw + k]
			if w > 0.0:
				p += (mats[_bones[v * _nw + k]] as Transform3D) * _pos[v] * w
		out[v] = p
	return out


func _measure() -> void:
	var p := _skinned()
	var low := 1e9
	var lv := 0
	for v in p.size():
		if p[v].y < low:
			low = p[v].y
			lv = v
	var bn := _trex.skel.get_bone_name(_bind_bone[_top(lv)])
	if -low > (_sink_by.get(_stage, [0.0])[0] as float):
		_sink_by[_stage] = [-low, bn, _t]
	if -low > _sink:
		_sink = -low
		_sink_at = "%s t=%.2f %s" % [_stage, _t, _trex.skel.get_bone_name(_bind_bone[_top(lv)])]
	var sc := 1.5   # 遊戲裡放大 1.5 倍，比例要除掉
	for e in _rest_len.size():
		var r0 := _rest_len[e]
		if r0 < 0.02:   # 太短的邊（2 公分以下）比例會亂跳
			continue
		var r := p[_edges[e * 2]].distance_to(p[_edges[e * 2 + 1]]) / sc / r0
		var b := _stage + " " + _trex.skel.get_bone_name(_owner[e])
		if r > (_stretch.get(b, [0.0])[0] as float):
			_stretch[b] = [r, _t, _stage, _where(e)]
		if r < (_squash.get(b, [9.0])[0] as float):
			_squash[b] = [r, _t, _stage, _where(e)]


var _next := 0.0
func _process(delta: float) -> bool:
	if _trex == null or _trex.skel == null:   # trex.gd 編譯失敗
		quit(1)
		return true
	if _mi == null:
		_setup()
	_t += delta
	var acts_from := 15.0
	var acts_to := acts_from + ACTS.size() * 0.9
	if _t < 6.5:
		_stage = "走"
		_rig.position.z -= WALK * delta
	elif _t < 8.5:
		_stage = "停"
	elif _t < 11.5:
		_stage = "跑"
		_rig.position.z -= RUN * delta
	elif _t < 14.0:
		_stage = "原地轉身"
		_rig.rotation.y += 3.0 * delta
	elif _t > acts_from and _t < acts_to:
		var k := int((_t - acts_from) / 0.9)
		_trex.act = ACTS[k][0]
		_stage = ACTS[k][1]
	elif _t > acts_to and _t < acts_to + 4.0:
		_trex.act = 0
		_stage = "抬頭低頭"
		_trex.look_pitch = sin((_t - acts_to) * 1.6) * 1.0
	elif _t >= acts_to + 4.0:
		_report()
		return true
	if _cam:
		# CAM_YAW：繞恐龍轉幾度看（0 = 左側面）；CAM_SIZE：畫面多寬（公尺）；CAM_Y：看哪個高度；CAM_BONE：對準哪根骨頭
		var yaw := _rig.rotation.y + deg_to_rad(float(OS.get_environment("CAM_YAW")))
		_cam.size = float(OS.get_environment("CAM_SIZE")) if OS.get_environment("CAM_SIZE") else 12.0
		_cam.rotation = Vector3(deg_to_rad(float(OS.get_environment("CAM_PITCH"))), yaw - PI / 2, 0)
		var at := Vector3(_rig.position.x, float(OS.get_environment("CAM_Y")) if OS.get_environment("CAM_Y") else 3.45, _rig.position.z)
		if OS.get_environment("CAM_BONE"):   # CAM_BONE=head：鏡頭對準這根骨頭（拍頭、腳的特寫）
			at = _trex.bone_pos(OS.get_environment("CAM_BONE"))
		_cam.position = at + _cam.basis.z * 30.0
		if not _shots.is_empty() and _t >= _shots[0]:
			RenderingServer.force_draw()   # 視窗被別的視窗擋住時 macOS 不重畫，不強制畫的話會拿到舊的畫面
			root.get_viewport().get_texture().get_image().save_png("%s/t%.2f.png" % [OS.get_environment("OUT"), _shots.pop_front()])
	if _t > 0.6 and _t >= _next:   # 一秒量 20 次，夠抓到最差的姿勢
		_next = _t + 0.05
		_measure()
	return false


func _report() -> void:
	var fail := 0
	print("穿地：皮最低比地面低 %.3f 公尺（%s）" % [_sink, _sink_at])
	for k in _sink_by:
		if _sink_by[k][0] > 0.15:
			print("  %s：%.2f 公尺（%s t=%.2f）" % [k, _sink_by[k][0], _sink_by[k][1], _sink_by[k][2]])
			fail += 1
	# 每段動作列最差的幾根骨頭（TOP=數字，預設 2）
	var top := int(OS.get_environment("TOP")) if OS.get_environment("TOP") else 2
	var by := {}
	for k: String in _stretch:
		var st := k.split(" ")[0]
		if not by.has(st):
			by[st] = []
		by[st].append([maxf(_stretch[k][0], 1.0 / _squash[k][0]), k])
	for st in by:
		by[st].sort_custom(func(x, y): return x[0] > y[0])
		by[st] = by[st].slice(0, top)
	print("動作 骨頭        拉最長   壓最扁（倍）")
	for st in by:
		for r in by[st]:
			var k: String = r[1]
			print("%-18s  %.2f %s t=%.2f  %.2f %s t=%.2f" % [k, _stretch[k][0], _stretch[k][3], _stretch[k][1], _squash[k][0], _squash[k][3], _squash[k][1]])
			if _stretch[k][0] > 2.0 or _squash[k][0] < 0.4:
				fail += 1
	print("蒙皮檢查：%s" % ("通過" if fail == 0 else "%d 項沒過（拉長 > 2 倍、壓扁 < 0.4 倍、穿地 > 0.15 公尺）" % fail))
	quit(1 if fail else 0)
