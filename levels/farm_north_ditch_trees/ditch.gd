extends RefCounted

const START := Vector2(-35.518, -72.828)
const END := Vector2(-36.144, -68.877)
const HALF_WIDTH := .325
const GROUND := &"田間地表與農路"
const STATIONS := [0., .28, .62, 1.22, 1.90, 2.63, 3.36, 3.72, 4.0]
const DEPTHS := [0., .04, .105, .145, .155, .12, .085, .032, 0.]
const BANK_LEFT := [-.2, -.25, -.18, -.14, -.23, -.17, -.13, -.18, -.16]
const BANK_RIGHT := [.18, .15, .22, .17, .14, .21, .24, .16, .17]
const RIPPLE := [.02, -.02, .04, .01, -.02, -.05, .00, .03, .01]
const FIELDS := preload("res://levels/farm_environment/fields.gd")
const PLAN := preload("res://levels/farm_environment/plan.json")

static func install(farm: Node3D) -> bool:
	var view := farm.get_node_or_null(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	if not view or not view.mesh or not is_instance_valid(farm.floor_body): return false
	var shape := farm.floor_body.get_child(0) as CollisionShape3D
	if not shape or not shape.shape is ConcavePolygonShape3D: return false
	var original: Mesh = view.mesh
	var updated := ArrayMesh.new()
	var overrides: Array[Material] = []
	var trimmed := false
	for i in original.get_surface_count():
		var arrays := original.surface_get_arrays(i)
		if original.surface_get_name(i) == GROUND:
			trimmed = open_ground(arrays)
			if not trimmed:
				return false
		updated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		updated.surface_set_name(i, original.surface_get_name(i))
		updated.surface_set_material(i, original.surface_get_material(i))
		overrides.append(view.get_surface_override_material(i))
	if not trimmed: return false
	var soil: ShaderMaterial
	for i in original.get_surface_count():
		if original.surface_get_name(i) == GROUND:
			soil = view.get_active_material(i).duplicate() as ShaderMaterial
	if not soil: return false
	soil.set_shader_parameter(&"role", 6)
	add_channel(updated, soil)
	var floor_shape := updated.create_trimesh_shape()
	if not floor_shape: return false
	floor_shape.backface_collision = shape.shape.backface_collision
	view.mesh = updated
	for i in overrides.size():
		view.set_surface_override_material(i, overrides[i])
	shape.shape = floor_shape
	open_wheat_rows(farm)
	return true

static func open_wheat_rows(farm: Node3D) -> void:
	var wheat := farm.get_node_or_null(^"CropFields/Field2/wheat") as MultiMeshInstance3D
	if not wheat or not wheat.multimesh: return
	# 依原田塊種子取得座標，圖形端與無視窗模式走相同資料。
	var placements: Array = FIELDS.layout(PLAN.data.fields[1],PLAN.data,7242).wheat
	if placements.size() != wheat.multimesh.instance_count: return
	var kept := []
	for xf: Transform3D in placements:
		var p := Vector2(xf.origin.x, xf.origin.z)
		var nearest := Geometry2D.get_closest_point_to_segment(p, START, END)
		if p.distance_to(nearest) > .54: kept.append(xf)
	var updated := MultiMesh.new()
	updated.transform_format = MultiMesh.TRANSFORM_3D
	updated.mesh = wheat.multimesh.mesh
	updated.instance_count = kept.size()
	updated.custom_aabb = wheat.multimesh.custom_aabb
	for i in kept.size(): updated.set_instance_transform(i, kept[i])
	wheat.multimesh = updated
	wheat.set_meta(&"ditch_removed_wheat", placements.size() - kept.size())

# 分割碰到溝界的三角形，保留四個外側區段。內側由同一套側坡與溝底取代。
static func open_ground(arrays: Array) -> bool:
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var elements: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var axes := [(END - START).normalized(), (END - START).normalized().orthogonal()]
	var length := START.distance_to(END)
	var kept := PackedInt32Array()
	var modified := false
	for i in range(0, elements.size(), 3):
		var ids := Vector3i(elements[i], elements[i + 1], elements[i + 2])
		var base: Array[Vector2] = []
		for ix in [ids.x, ids.y, ids.z]:
			var dxz := Vector2(positions[ix].x, positions[ix].z) - START
			base.append(Vector2(dxz.dot(axes[0]), dxz.dot(axes[1])))
		if minf(base[0].x, minf(base[1].x, base[2].x)) >= length or maxf(base[0].x, maxf(base[1].x, base[2].x)) <= 0.0 or minf(base[0].y, minf(base[1].y, base[2].y)) >= HALF_WIDTH or maxf(base[0].y, maxf(base[1].y, base[2].y)) <= -HALF_WIDTH:
			kept.append_array([ids.x, ids.y, ids.z])
			continue
		# North Field 2 is a flat pad. Avoid replacing anything if a later map moved its grade.
		if maxf(absf(positions[ids.x].y), maxf(absf(positions[ids.y].y), absf(positions[ids.z].y))) > .005:
			return false
		var pending: Array[Vector2] = base.duplicate()
		var pieces: Array = []
		for plane: Vector3 in [Vector3(1,0,length), Vector3(-1,0,0), Vector3(0,1,HALF_WIDTH), Vector3(0,-1,HALF_WIDTH)]:
			pieces.append(clip(pending, plane, -1.0))
			pending = clip(pending, plane, 1.0)
			if pending.size() < 3: break
		if pending.size() < 3:
			kept.append_array([ids.x, ids.y, ids.z])
			continue
		modified = true
		for polygon: Array[Vector2] in pieces:
			if polygon.size() < 3: continue
			var first: int = arrays[Mesh.ARRAY_VERTEX].size()
			for point: Vector2 in polygon:
				append_vertex(arrays, ids, barycentric(point, base))
			for corner in range(1, polygon.size() - 1):
				var area := (polygon[corner] - polygon[0]).cross(polygon[corner + 1] - polygon[0])
				if absf(area) > .0000001:
					kept.append_array([first, first + corner, first + corner + 1])
	arrays[Mesh.ARRAY_INDEX] = kept
	return modified

static func clip(polygon: Array[Vector2], plane: Vector3, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if polygon.is_empty(): return out
	var normal := Vector2(plane.x, plane.y)
	var a := polygon[-1]
	var d_a := side * (normal.dot(a) - plane.z)
	for b: Vector2 in polygon:
		var d_b := side * (normal.dot(b) - plane.z)
		if (d_a > 0.0) != (d_b > 0.0):
			out.append(a.lerp(b, d_a / (d_a - d_b)))
		if d_b <= 0.0: out.append(b)
		a = b
		d_a = d_b
	return out

static func barycentric(p: Vector2, tri: Array[Vector2]) -> Vector3:
	var u := tri[1] - tri[0]
	var v := tri[2] - tri[0]
	var w := p - tri[0]
	var wb := w.cross(v) / u.cross(v)
	var wc := u.cross(w) / u.cross(v)
	return Vector3(1.0 - wb - wc, wb, wc)

static func append_vertex(arrays: Array, ids: Vector3i, weight: Vector3) -> void:
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		var data = arrays[channel]
		var value = data[ids.x] * weight.x + data[ids.y] * weight.y + data[ids.z] * weight.z
		if channel == Mesh.ARRAY_NORMAL: value = value.normalized()
		data.append(value)
		arrays[channel] = data
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for k in 4:
		tangents.append(tangents[ids.x * 4 + k] * weight.x + tangents[ids.y * 4 + k] * weight.y + tangents[ids.z * 4 + k] * weight.z)
	arrays[Mesh.ARRAY_TANGENT] = tangents

static func add_channel(mesh: ArrayMesh, soil: ShaderMaterial) -> void:
	var dir := (END - START).normalized()
	var lateral := dir.orthogonal()
	var rows: Array = []
	for i in STATIONS.size():
		var along: float = START.distance_to(END) * STATIONS[i] / 4.0
		var depth: float = DEPTHS[i]
		var row: Array[Vector3] = []
		# 幾毫米薄唇埋進原地面，避開物理引擎在兩片共邊的取樣縫。
		if i == 0: along -= .005
		if i == STATIONS.size() - 1: along += .005
		var across := [-HALF_WIDTH - .006, BANK_LEFT[i], RIPPLE[i] - .055, RIPPLE[i] + .060, BANK_RIGHT[i], HALF_WIDTH + .006]
		var levels := [-.001, -depth * .44 - .001, -depth - .001, -depth * .95 - .001, -depth * .39 - .001, -.001]
		for j in across.size():
			var point: Vector2 = START + dir * along + lateral * across[j]
			row.append(Vector3(point.x, levels[j], point.y))
		rows.append(row)
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, rows.size()):
		for j in range(1, rows[i].size()):
			for v: Vector2i in [Vector2i(i-1,j-1), Vector2i(i,j), Vector2i(i,j-1), Vector2i(i-1,j-1), Vector2i(i-1,j), Vector2i(i,j)]:
				face.add_vertex(rows[v.x][v.y])
	face.generate_normals()
	face.set_material(soil)
	face.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "北田乾支溝")
