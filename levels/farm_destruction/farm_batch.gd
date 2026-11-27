extends Node3D
## 農莊效能 P2＋P3（docs/技術筆記/農莊效能改善.md）：影子合併、畫面照材質合併。
## 每一格（CELL 公尺見方）把靜態零件合成：一個「只投影子、自己不畫」的網格（P2），和一個照材質分段、自己不投影子的畫面網格（P3）。
## 原零件改成不投影子、layers 0（不畫），節點、碰撞、顯示狀態都照舊，遊戲照舊藏它、顯示它。
## 零件被藏起來（拆掉、玻璃破、整棟退場）的當下，把它在合併網格裡那幾段頂點縮成一點（畫面、影子跟著不見）；
## 再出現（換局還原、晚加入的人收到狀態）就把原本的頂點寫回去。同一幀生效，不閃、不少一格。
## 每台客戶端各自算，不同步；沒有畫面（專用伺服器、測試）不做。FARM_SHADOW_BATCH=0 全關；FARM_DRAW_BATCH=0 只合影子（量改前）。
## 不合的：會動的（門、門扇、積木、物理體）、鏤空或半透明、會改頂點或挖洞的著色器、看板、有骨架或形變、有設遠處不畫、MultiMesh、比一格還大的（地面）。
## 只合影子、不合畫面的：著色器用到物件自己的座標（物件空間頂點、物件位置、每個零件的參數）、頂點有自訂欄位、本來就只投影子的。

const CELL := 48.0
const GROUND_LAYER := 1 << 19   # 地面貼花那層（levels/ranch_surface/surface.gd 的 DECAL_LAYER）
const ARRAYS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
var _src := {}      # MeshInstance3D -> [[合併的 ArrayMesh, 第幾段, 第幾個位元組起, 原本的頂點（位元組）], …]（影子一筆、畫面每種材質一筆）
var _shown := {}    # MeshInstance3D -> 合併網格裡現在是不是寫著它的頂點
var _drawn := {}    # P3：畫面也合了的零件（自己 layers 設 0：不畫，節點、碰撞、顯示狀態都照舊）
static var _mat_seen := {}   # 材質 -> 參數一樣就同一個鍵


static func install(farm: Node3D, force := false) -> Node:
	if not force and DisplayServer.get_name() == "headless":
		return null
	var batch := new()
	batch.name = "FarmBatches"
	farm.add_child(batch)
	batch.build(farm, OS.get_environment("FARM_DRAW_BATCH") != "0")
	return batch


## 影子和畫面共用同一次讀出的網格資料（讀資料是載入最慢的一段）。
## 影子：[格 x, 格 z, layers, 剔除] 一塊。畫面：[格 x, 格 z, layers] 一個網格，裡面同材質、同頂點格式的一段。
func build(farm: Node3D, draw := true) -> void:
	var t0 := Time.get_ticks_usec()
	var shadow := {}   # 鍵 -> 段
	var meshes := {}   # [格 x, 格 z, layers] -> {[材質鍵, 格式] -> 段}
	var inv := global_transform.affine_inverse()
	for n: MeshInstance3D in farm.find_children("*", "MeshInstance3D", true, false):
		var cull := _cull(n, farm)
		if cull < 0:
			continue
		var casts := n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drawn := draw and n.layers != 0 and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and _draw_ok(n)
		if not casts and not drawn:
			continue
		var xf := inv * n.global_transform
		var at := xf * n.get_aabb().get_center()
		var cell := [floori(at.x / CELL), floori(at.z / CELL), n.layers]
		var flip := xf.basis.determinant() < 0.0   # 鏡像的零件：繞的方向反過來，背面剔除才不會剔錯面
		var nb := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		for s in n.mesh.get_surface_count():
			var arr := n.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or idx.is_empty():
				idx = PackedInt32Array(range(arr[Mesh.ARRAY_VERTEX].size()))
			if flip:
				idx = idx.duplicate()
				for i in range(0, idx.size(), 3):
					var a: int = idx[i]
					idx[i] = idx[i + 2]
					idx[i + 2] = a
			arr[Mesh.ARRAY_INDEX] = idx
			arr[Mesh.ARRAY_VERTEX] = xf * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			if casts:
				var sk := cell.slice(0, 2) + [n.layers, cull]
				if not shadow.has(sk):
					shadow[sk] = _part()
				_add(shadow[sk], n, arr, [Mesh.ARRAY_VERTEX])
			if not drawn:
				continue
			var has := ARRAYS.filter(func(a): return arr[a] != null)
			if arr[Mesh.ARRAY_NORMAL] != null:
				arr[Mesh.ARRAY_NORMAL] = nb * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)
				if not xf.basis.is_conformal():   # 不等比縮放：法線要重新變成單位長
					var nv: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					for i in nv.size():
						nv[i] = nv[i].normalized()
					arr[Mesh.ARRAY_NORMAL] = nv
			if arr[Mesh.ARRAY_TANGENT] != null:
				var t: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
				var w := -1.0 if flip else 1.0
				for i in range(0, t.size(), 4):
					var v := (xf.basis * Vector3(t[i], t[i + 1], t[i + 2])).normalized()
					t[i] = v.x
					t[i + 1] = v.y
					t[i + 2] = v.z
					t[i + 3] *= w
				arr[Mesh.ARRAY_TANGENT] = t
			var m := n.get_active_material(s)
			if not meshes.has(cell):
				meshes[cell] = {}
			var mk := [_mat_key(m), has]
			if not meshes[cell].has(mk):
				meshes[cell][mk] = _part()
				meshes[cell][mk][3] = m
			_add(meshes[cell][mk], n, arr, has)
		if casts:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if drawn:
			_drawn[n] = true
			n.layers = 0   # 不畫（還在場上、碰撞和顯示狀態不變），改由合併網格畫
	for sk: Array in shadow:
		var mi := _emit(shadow[sk], "Shadow_%d_%d_%d_%d" % sk, sk[2], [sk[3]])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for cell: Array in meshes:
		var mi := _emit_all(meshes[cell].values(), "Cell_%d_%d_%d" % cell, cell[2])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 影子由上面那塊畫
	for n: MeshInstance3D in _src:
		_shown[n] = true
		n.visibility_changed.connect(_sync.bind(n))
		n.tree_exiting.connect(_show.bind(n, false))
	for n: MeshInstance3D in _src:
		_sync(n)
	_mat_seen.clear()   # 不留著材質（換地圖時才放得掉）
	var surfaces := 0
	for cell in meshes:
		surfaces += meshes[cell].size()
	print("合併：%d 個零件，影子 %d 塊、畫面 %d 段（%d 個網格），%.0f 毫秒" % [_src.size(), shadow.size(), surfaces, meshes.size(), (Time.get_ticks_usec() - t0) / 1000.0])


## 一段：[各陣列, 頂點數, [[零件, 起點, 數量]], 材質]
func _part() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return [a, 0, [], null]


func _add(c: Array, n: MeshInstance3D, arr: Array, keep: Array) -> void:
	var base: int = c[1]
	var out: Array = c[0]
	for a: int in keep:
		if out[a] == null:
			out[a] = arr[a].duplicate()
		else:
			out[a].append_array(arr[a])
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var o: int = out[Mesh.ARRAY_INDEX].size()
	out[Mesh.ARRAY_INDEX].append_array(idx)
	var oi: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	for i in idx.size():
		oi[o + i] += base
	out[Mesh.ARRAY_INDEX] = oi
	var count: int = arr[Mesh.ARRAY_VERTEX].size()
	c[1] = base + count
	var e: Array = c[2]
	if not e.is_empty() and e[-1][0] == n:
		e[-1][2] += count   # 同一個零件的下一段材質一樣：接在一起
	else:
		e.append([n, base, count])


func _emit(c: Array, label: String, layers: int, cull: Array) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = cull[0]
	c[3] = mat
	return _emit_all([c], label, layers)


## 一個網格、每段一種材質。每個零件在每段的頂點位元組記進 _src，拆掉時改那一小段
func _emit_all(parts: Array, label: String, layers: int) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.layers = layers
	for c: Array in parts:
		var s := mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c[0], [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		mesh.surface_set_material(s, c[3])
		# 頂點在顯示卡上的樣子（位置＋法線＋切線那一條）讀回來，切成每個零件一段；沒有顯示卡（測試）讀不到就只記長度
		var stride := RenderingServer.mesh_surface_get_format_vertex_stride(mesh.surface_get_format(s), c[1])
		var bytes: PackedByteArray = RenderingServer.mesh_get_surface(mesh.get_rid(), s).get("vertex_data", PackedByteArray())
		if bytes.size() != stride * c[1]:
			bytes.resize(stride * c[1])
		for e: Array in c[2]:
			if not _src.has(e[0]):
				_src[e[0]] = []
			_src[e[0]].append([mesh, s, e[1] * stride, bytes.slice(e[1] * stride, (e[1] + e[2]) * stride)])
	mi.mesh = mesh
	add_child(mi)
	return mi


## 參數一模一樣的材質當成同一個（農莊有不少是同一份設定各自存一份）
static func _mat_key(m: Material) -> Variant:
	if m == null:
		return null
	if not _mat_seen.has(m):
		var parts := [m.get_class()]
		for p in m.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name not in ["resource_name", "resource_path", "resource_local_to_scene", "script"]:
				parts.append([p.name, m.get(p.name)])
		_mat_seen[m] = str(parts)
	return _mat_seen[m]


## 合併前就藏著的零件（拆過的、破玻璃）不合，照舊自己投影子；合了的才在這裡追。
func _cull(n: MeshInstance3D, farm: Node) -> int:
	if n.mesh == null or not n.is_visible_in_tree() or n.mesh is not ArrayMesh and n.mesh is not PrimitiveMesh:
		return -1
	if n.material_overlay != null or n.transparency > 0.0 or n.visibility_range_end > 0.0 or n.skin != null:
		return -1
	if n.mesh is ArrayMesh and (n.mesh as ArrayMesh).get_blend_shape_count() > 0:
		return -1
	if n.get_aabb().size.length() > CELL:
		return -1
	var p: Node = n
	while p != farm:
		if p is Door or p is ToyBuild or p is Skeleton3D or p.has_method(&"interact") or (p is PhysicsBody3D and p is not StaticBody3D):
			return -1
		p = p.get_parent()
	var cull := BaseMaterial3D.CULL_DISABLED if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED else -1
	for s in n.mesh.get_surface_count():
		if n.mesh is ArrayMesh and n.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return -1
		var m := n.get_active_material(s)
		var bm := m as BaseMaterial3D
		var mc := BaseMaterial3D.CULL_BACK
		if m is ShaderMaterial:
			mc = _shader_cull(m.shader)
			if mc < 0:
				return -1
		elif m != null and bm == null:
			return -1
		if bm:
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or bm.grow or bm.use_point_size or bm.fixed_size \
					or bm.uv1_triplanar and not bm.uv1_world_triplanar or bm.uv2_triplanar and not bm.uv2_world_triplanar or bm.next_pass != null:
				return -1
			mc = bm.cull_mode
		if cull == BaseMaterial3D.CULL_DISABLED:
			continue
		if cull >= 0 and cull != mc:
			return -1   # 一個零件裡正反面剔除不一樣：不合
		cull = mc
	return cull


## 畫面也合不合：合了之後「零件自己的座標」不見了，著色器有用到的（物件空間的頂點、法線、物件位置、每個零件的參數）就不合，只合影子。
## 地面（有地面貼花那層的：田路、車轍、岸腳）也不合：它們和大地面疊在同一個高度，誰蓋誰是看畫的順序，合了順序會變（實測 270° 那張整片田路不見）。
## 頂點格式有自訂欄位、骨架的也不合（這裡只搬位置、法線、切線、顏色、兩組 UV）。
func _draw_ok(n: MeshInstance3D) -> bool:
	if n.layers & GROUND_LAYER:
		return false
	for s in n.mesh.get_surface_count():
		if n.mesh is ArrayMesh and n.mesh.surface_get_format(s) & (Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3 | Mesh.ARRAY_FORMAT_BONES):
			return false
		var m := n.get_active_material(s)
		if m is ShaderMaterial and not _shader_world(m.shader):
			return false
	return true


static var _world_seen := {}
static func _shader_world(shader: Shader) -> bool:
	if not _world_seen.has(shader):
		# 只用世界座標（MODEL_MATRIX * vec4(VERTEX, 1.0)）的可以：合併網格的世界座標一樣
		var code := RegEx.create_from_string("MODEL_MATRIX\\s*\\*\\s*vec4\\s*\\(\\s*VERTEX\\s*,\\s*1(\\.0*)?\\s*\\)").sub(shader.code, "", true)
		var vtx := RegEx.create_from_string("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{[^}]*\\}").search(code)
		var local := RegEx.create_from_string("\\b(VERTEX|NORMAL|TANGENT|BINORMAL)\\b")
		_world_seen[shader] = not RegEx.create_from_string("MODEL_|NODE_POSITION|INSTANCE_").search(code) and not (vtx and local.search(vtx.get_string()))
	return _world_seen[shader]


## 自訂著色器：只讀頂點、不挖洞的（農莊的牆、地面著色器都是這種）才合，回傳它的剔除方式；會改頂點、透明、挖洞的回 -1
static var _shader_seen := {}
static func _shader_cull(shader: Shader) -> int:
	if shader == null:
		return -1
	if not _shader_seen.has(shader):
		var code := shader.code
		var moves := RegEx.create_from_string("\\bVERTEX(\\.\\w+)?\\s*[-+*/]?=[^=]|\\bPOSITION\\b|\\bALPHA|\\bdiscard\\b|skip_vertex_transform|\\bshader_type\\s+(?!spatial)")
		var mode := RegEx.create_from_string("render_mode[^;]*").search(code)
		var modes := mode.get_string() if mode else ""
		var cull := BaseMaterial3D.CULL_DISABLED if "cull_disabled" in modes else (BaseMaterial3D.CULL_FRONT if "cull_front" in modes else BaseMaterial3D.CULL_BACK)
		_shader_seen[shader] = -1 if moves.search(code) or "#include" in code else cull
	return _shader_seen[shader]


func _sync(n: MeshInstance3D) -> void:
	_show(n, n.is_inside_tree() and n.is_visible_in_tree())


## 把零件在合併網格裡那段寫成原本的頂點（on）或全部縮成一點（off）
func _show(n: MeshInstance3D, on: bool) -> void:
	if _shown.get(n, on) == on:
		return
	_shown[n] = on
	for e: Array in _src[n]:
		var data: PackedByteArray = e[3]
		if not on:
			data = PackedByteArray()
			data.resize((e[3] as PackedByteArray).size())
		(e[0] as ArrayMesh).surface_update_vertex_region(e[1], e[2], data)


## 測試用：零件的影子／畫面現在有沒有在合併網格裡
func casting(n: MeshInstance3D) -> bool:
	return _shown.get(n, false)


func drawing(n: MeshInstance3D) -> bool:
	return _drawn.has(n) and _shown.get(n, false)
