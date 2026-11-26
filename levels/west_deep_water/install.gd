extends MeshInstance3D
## 只將西側一段既有三角面換為濁水材質。卸下時恢復原網格。
const LOCAL_SHADER := preload("res://levels/west_deep_water/suspended_water.gdshader")
const PIECE := &"WestDeepTransmission"
var source_mesh: Mesh

static func install(water: MeshInstance3D) -> bool:
	if water.has_node(NodePath(PIECE)):
		return true
	var source := water.mesh
	if not source is ArrayMesh or source.get_surface_count()!=1 or not water.material_override is ShaderMaterial:
		return false
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var west := PackedInt32Array()
	var rest := PackedInt32Array()
	for i in range(0,indices.size(),3):
		var x := (vertices[indices[i]].x+vertices[indices[i+1]].x+vertices[indices[i+2]].x)/3.0
		var group := west if x >= -82.0 and x < -64.0 else rest
		group.append(indices[i])
		group.append(indices[i+1])
		group.append(indices[i+2])
	if west.is_empty() or rest.is_empty():
		return false
	var part := new()
	part.name = PIECE
	part.source_mesh = source
	part.mesh = _part(arrays,west)
	part.cast_shadow = water.cast_shadow
	var local_mat := ShaderMaterial.new()
	local_mat.shader = LOCAL_SHADER
	# 先畫正式蛋的加亮層，再由水遮住；遠處不會只剩一顆發亮的蛋。
	local_mat.render_priority = 1
	part.material_override = local_mat
	water.mesh = _part(arrays,rest)
	water.add_child(part)
	return true

static func _part(arrays: Array,indices: PackedInt32Array) -> ArrayMesh:
	var subset := arrays.duplicate()
	subset[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,subset)
	return result

static func uninstall(water: MeshInstance3D) -> void:
	var part = water.get_node_or_null(NodePath(PIECE))
	if part:
		water.mesh = part.source_mesh
		part.free()
