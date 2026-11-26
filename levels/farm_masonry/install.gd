extends RefCounted
## 把原模型的砌石、壓枕、鐵座與工具各自交給地圖破壞系統。
const PARTS := preload("res://levels/farm_masonry/parts.glb")

static func site(skin: MeshInstance3D, solid: Node3D, id: String) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = id
	for old: CollisionShape3D in solid.find_children("*", "CollisionShape3D", true, false):
		old.disabled = true
	solid.add_child(assembly)
	assembly.global_transform = skin.global_transform
	skin.hide()
	return assembly

static func install(farm: Node3D) -> void:
	var heap_skin: MeshInstance3D = farm.get_node("FarmStyleBuildings/StoneHeap")
	var wheel_skin: MeshInstance3D = farm.get_node("FarmStyleBuildings/WheelSeat")
	var wheel: Node3D = farm.get_node("FarmCanalWorks/WheelSeat")
	if wheel.has_node("BearingAssembly"):
		return
	var heap := site(heap_skin, farm.get_node("FarmShell/西南田埂石垛"), "Masonry")
	var bed := site(wheel_skin, wheel, "BearingAssembly")
	var joint: MeshInstance3D = farm.get_node("bridge_details/水尺與水車機座工具")
	var gauge := ArrayMesh.new()
	var tool_materials := {}
	for i in joint.mesh.get_surface_count():
		var material := joint.get_active_material(i)
		if material.resource_name in ["作業物 · rope", "作業物 · cut"]:
			tool_materials[material.resource_name] = material
		else:
			gauge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, joint.mesh.surface_get_arrays(i))
			gauge.surface_set_material(gauge.get_surface_count() - 1, material)
	joint.mesh = gauge

	var source: Node3D = PARTS.instantiate()
	for visual: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var id := str(visual.name)
		var parent := heap if id.begins_with("Heap") else bed
		var pose := visual.transform
		var pigment := heap_skin.get_active_material(0)
		if id.begins_with("Tool"):
			pose = bed.global_transform.affine_inverse() * joint.global_transform * pose
			pigment = tool_materials["作業物 · rope" if id == "ToolRope" else "作業物 · cut"]
		var body := StaticBody3D.new()
		body.name = id
		body.transform = pose
		body.set_meta("component", "masonry_part")
		body.set_meta("structure_material", "brick")
		body.set_meta("original_debris_mesh", true)
		parent.add_child(body)
		visual.reparent(body, false)
		visual.name = "StockAssembly"
		visual.transform = Transform3D.IDENTITY
		visual.mesh.surface_set_material(0, pigment)
		var solid := CollisionShape3D.new()
		solid.shape = visual.mesh.create_convex_shape()
		body.add_child(solid)
	source.free()
	for assembly in [heap, bed]:
		link_courses(assembly)

## 錯縫砌石可由下方任一實際重疊的砌塊承托。基底直接落在田埂／渠岸。
static func link_courses(assembly: Node3D) -> void:
	var bounds := {}
	for body: StaticBody3D in assembly.get_children():
		bounds[body] = body.transform * body.get_node("StockAssembly").mesh.get_aabb()
	for body: StaticBody3D in assembly.get_children():
		var box: AABB = bounds[body]
		var supports := []
		for lower: StaticBody3D in assembly.get_children():
			var base: AABB = bounds[lower]
			if lower == body or absf(base.end.y - box.position.y) > 0.05:
				continue
			if minf(base.end.x, box.end.x) - maxf(base.position.x, box.position.x) > 0.025 and minf(base.end.z, box.end.z) - maxf(base.position.z, box.position.z) > 0.025:
				supports.append(str(lower.name))
		body.set_meta("support_seats", [] if supports.is_empty() else [supports])
		body.set_meta("ground_anchor", supports.is_empty())
