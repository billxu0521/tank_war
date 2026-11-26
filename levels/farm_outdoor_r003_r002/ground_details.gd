extends RefCounted

const FIELD_LAYOUT := preload("res://levels/farm_environment/fields.gd")
const PLAN := preload("res://levels/farm_environment/plan.json")

## 原磁磚內含土屑、短莖及葉片，依各棟牆腳與樓板處理。
static func clear_room_edges(farm: Node3D) -> void:
	var tasks := {
		"Tile_11_13": "House6", "Tile_13_13": "House7",
		"Tile_13_14": "House7", "Tile_12_12": "GateStore"
	}
	for tile: String in tasks:
		var view := farm.get_node("FarmStyleEnvironment/田路與岸腳/" + tile) as MeshInstance3D
		var room: Node3D = farm.get_node("FarmBuildings31/" + str(tasks[tile]))
		var to_room := room.global_transform.affine_inverse() * view.global_transform
		var half := Vector2(room.width,room.depth) * .5 + Vector2(.18,.18)
		filter_tile(view,to_room,Rect2(-half,2.0*half),.035,false)
	# 新轉運樓的板縫低於中央板面；只移除完整落在樓內的田面碎屑，留住跨界與戶外部分。
	var sites := preload("res://levels/farm_sites/sites.gd")
	var site := farm.global_transform * sites.placement(sites.GRAIN)
	var grain_tile := farm.get_node(^"FarmStyleEnvironment/田路與岸腳/Tile_12_10") as MeshInstance3D
	filter_tile(grain_tile,site.affine_inverse()*grain_tile.global_transform,Rect2(Vector2.ZERO,sites.GRAIN.size),0.0,true)

static func filter_tile(view: MeshInstance3D, to_room: Transform3D, footprint: Rect2, min_height: float, inside_only: bool) -> void:
	var original := view.mesh as ArrayMesh
	var clean := ArrayMesh.new()
	for s in original.get_surface_count():
		var a := original.surface_get_arrays(s)
		var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(points.size()))
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			var pa := to_room * points[indices[i]]
			var pb := to_room * points[indices[i+1]]
			var pc := to_room * points[indices[i+2]]
			var low := pa.min(pb).min(pc)
			var high := pa.max(pb).max(pc)
			var bounds := Rect2(Vector2(low.x,low.z),Vector2(high.x-low.x,high.z-low.z))
			var remove := footprint.encloses(bounds) if inside_only else footprint.intersects(bounds,true)
			if high.y > min_height and remove:
				continue
			kept.append(indices[i])
			kept.append(indices[i+1])
			kept.append(indices[i+2])
		if kept.is_empty(): continue
		a[Mesh.ARRAY_INDEX] = kept
		clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		var dest := clean.get_surface_count()-1
		clean.surface_set_material(dest, original.surface_get_material(s))
		clean.surface_set_name(dest, original.surface_get_name(s))
	clean.resource_name = original.resource_name
	view.mesh = clean

## 西岸修理棚 p01 的低草。沿用近西灘田的原種子、變換、材質與散佈順序。
static func clear_repair_shed(farm: Node3D) -> void:
	var field := farm.get_node(^"CropFields/Field4/grass") as MultiMeshInstance3D
	var original := field.multimesh
	var poses: Array = FIELD_LAYOUT.layout(PLAN.data.fields[3],PLAN.data,7244).grass
	if poses.size()!=original.instance_count:
		push_error("近西灘草田與 r003 基準數量不合，保留原草。")
		return
	var site := Transform3D(Basis(Vector3.UP,deg_to_rad(175)),Vector3(-65.371455,0,-24.492287))
	var inside := AABB(Vector3(-.10,-.30,-.10),Vector3(12.2,3.55,8.2))
	var kept: Array[Transform3D] = []
	for xf: Transform3D in poses:
		var box := (site.affine_inverse()*field.global_transform*xf)*original.mesh.get_aabb()
		if not inside.intersects(box): kept.append(xf)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = original.use_colors
	mm.mesh = original.mesh
	mm.instance_count = kept.size()
	mm.custom_aabb = original.custom_aabb
	for i in kept.size():
		mm.set_instance_transform(i,kept[i])
		if mm.use_colors: mm.set_instance_color(i,Color.WHITE)
	field.multimesh = mm
	field.set_meta(&"outdoor_retained_poses",kept)
