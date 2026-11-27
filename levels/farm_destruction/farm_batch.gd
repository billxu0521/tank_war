extends Node3D
## 農莊效能 P2（docs/技術筆記/農莊效能改善.md）：影子合併。
## 每一格（CELL 公尺見方）把投影子的靜態零件合成一個「只投影子、自己不畫」的網格，原零件改成不投影子。
## 零件被藏起來（拆掉、玻璃破、整棟退場）的當下，把它在合併網格裡那一段頂點縮成一點（影子跟著不見）；
## 再出現（換局還原、晚加入的人收到狀態）就把原本的頂點寫回去。同一幀生效，不閃、不少一格。
## 零件本身一個都沒動：節點、碰撞、顯示照舊，只是影子改由合併網格畫。
## 每台客戶端各自算，不同步；沒有畫面（專用伺服器、測試）不做。
## 不合的：會動的（門、門扇、積木、物理體）、鏤空或半透明、會改頂點或挖洞的著色器、看板、有骨架或形變、有設遠處不畫、MultiMesh、比一格還大的（地面）。
## 給 P3：_src[零件] = [合併節點, 位元組起點, 原本頂點]；_show() 是唯一改合併網格的地方，畫面合併可照同樣的方式藏零件。

const CELL := 48.0
var _src := {}      # MeshInstance3D -> [合併的 MeshInstance3D, 第幾個位元組起, 原本的頂點（位元組）]
var _shown := {}    # MeshInstance3D -> 合併網格裡現在是不是寫著它的頂點


static func install(farm: Node3D, force := false) -> Node:
	if not force and DisplayServer.get_name() == "headless":
		return null
	var batch := new()
	batch.name = "ShadowBatches"
	farm.add_child(batch)
	batch.build(farm)
	return batch


func build(farm: Node3D) -> void:
	var t0 := Time.get_ticks_usec()
	var cells := {}   # [格 x, 格 z, layers, cull] -> [PackedVector3Array, PackedInt32Array, [[零件, 起點, 數量]]]
	var inv := global_transform.affine_inverse()
	for n: MeshInstance3D in farm.find_children("*", "MeshInstance3D", true, false):
		var cull := _cull(n, farm)
		if cull < 0:
			continue
		var xf := inv * n.global_transform
		var at := xf * n.get_aabb().get_center()
		var key := [floori(at.x / CELL), floori(at.z / CELL), n.layers, cull]
		if not cells.has(key):
			cells[key] = [PackedVector3Array(), PackedInt32Array(), []]
		var c: Array = cells[key]
		var start: int = c[0].size()
		for s in n.mesh.get_surface_count():
			var arr := n.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = xf * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			var base: int = c[0].size()
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or idx.is_empty():
				idx = PackedInt32Array(range(v.size()))
			var flip := xf.basis.determinant() < 0.0   # 鏡像的零件：繞的方向反過來，背面剔除才不會剔錯面
			var out: PackedInt32Array = c[1]
			var o := out.size()
			out.resize(o + idx.size())
			for i in idx.size():
				out[o + i] = idx[i + 2 - 2 * (i % 3) if flip else i] + base
			c[1] = out
			c[0].append_array(v)
		c[2].append([n, start, c[0].size() - start])
	for key: Array in cells:
		var c: Array = cells[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = c[0]
		arrays[Mesh.ARRAY_INDEX] = c[1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		var mat := StandardMaterial3D.new()
		mat.cull_mode = key[3]
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Cell_%d_%d" % [key[0], key[1]]
		mi.mesh = mesh
		var stride := RenderingServer.mesh_surface_get_format_vertex_stride(mesh.surface_get_format(0), c[0].size())
		mi.layers = key[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(mi)
		for e: Array in c[2]:
			var n: MeshInstance3D = e[0]
			_src[n] = [mi, e[1] * stride, c[0].slice(e[1], e[1] + e[2]).to_byte_array()]
			_shown[n] = true
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.visibility_changed.connect(_sync.bind(n))
			n.tree_exiting.connect(_show.bind(n, false))
	for n: MeshInstance3D in _src:
		_sync(n)
	print("影子合併：%d 個零件合成 %d 塊，%.0f 毫秒" % [_src.size(), cells.size(), (Time.get_ticks_usec() - t0) / 1000.0])


## 合併前就藏著的零件（拆過的、破玻璃）不合，照舊自己投影子；合了的才在這裡追。
func _cull(n: MeshInstance3D, farm: Node) -> int:
	if n.mesh == null or not n.is_visible_in_tree() or n.mesh is not ArrayMesh and n.mesh is not PrimitiveMesh:
		return -1
	if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or n.transparency > 0.0 or n.visibility_range_end > 0.0 or n.skin != null:
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
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or bm.grow or bm.use_point_size or bm.fixed_size:
				return -1
			mc = bm.cull_mode
		if cull == BaseMaterial3D.CULL_DISABLED:
			continue
		if cull >= 0 and cull != mc:
			return -1   # 一個零件裡正反面剔除不一樣：不合
		cull = mc
	return cull


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
	var e: Array = _src[n]
	var data: PackedByteArray = e[2]
	if not on:
		data = PackedByteArray()
		data.resize((e[2] as PackedByteArray).size())
	(e[0].mesh as ArrayMesh).surface_update_vertex_region(0, e[1], data)


## 測試用：零件的影子現在有沒有在合併網格裡
func casting(n: MeshInstance3D) -> bool:
	return _shown.get(n, false)

