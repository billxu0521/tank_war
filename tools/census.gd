extends SceneTree
## 清點場上每種模型：開沙盒，照網格加總「數量 × 三角形」，排序印前 25 名，標出有沒有投影子（影）、遠處不畫的距離（遠N）。
## 找誰最佔三角形用（docs/技術筆記/效能.md）。要有畫面才會長草：godot --path . --script tools/census.gd
var _f := 0
var _main: Node
func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t
func _process(_d: float) -> bool:
	_f += 1
	if _f == 5: _main._on_sandbox_pressed()
	if _f < 30: return false
	var tri_cache := {}
	var by := {}
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var count := 1
		if n is MeshInstance3D: mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			count = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if mesh == null or not n.is_visible_in_tree(): continue
		if not tri_cache.has(mesh): tri_cache[mesh] = _tris(mesh)
		var key := "%s%s|%s|%s" % ["MM:" if n is MultiMeshInstance3D else "", mesh.resource_name if mesh.resource_name != "" else String(n.get_parent().name) + "/" + n.name, "影" if n.cast_shadow != 0 else "-", ("遠%d" % n.visibility_range_end) if n.visibility_range_end > 0 else ""]
		var e: Array = by.get(key, [0, 0, tri_cache[mesh], mesh.get_surface_count()])
		e[0] += count; e[1] += count * tri_cache[mesh]
		by[key] = e
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a][1] > by[b][1])
	var total := 0
	for k in keys: total += by[k][1]
	print("TOTAL 三角形 %.0f 萬" % (total / 10000.0))
	for k in keys.slice(0, 25):
		print("ROW %-44s 數量 %5d  每個 %6d 面 %d 段材質  合計 %.1f 萬" % [k, by[k][0], by[k][2], by[k][3], by[k][1] / 10000.0])
	return true
