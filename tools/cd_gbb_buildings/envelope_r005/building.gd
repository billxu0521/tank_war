extends Node3D
const LEAF = preload("res://tools/cd_gbb_buildings/leaf.gd")
var spec: Dictionary
var leaves: Array[Node3D] = []
var model: Node3D

static func xyz(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])

static func size_xyz(a: Array) -> Vector3:
	return Vector3(a[0], a[2], a[1])

func build(number: int, map_pose := true) -> void:
	name = "BLD_%02d" % number
	var path := "res://models/cd_gbb/envelope_r005/bld_%02d_assembly.json" % number
	spec = JSON.parse_string(FileAccess.get_file_as_string(path))
	if map_pose:
		var place: Dictionary = spec.placement
		position = Vector3(place.center_m[0], place.floor_h, -place.center_m[1])
		rotation.y = deg_to_rad(90.0 - float(place.orientation.u_azimuth_deg))
		# 模型局部原點為包絡角，場內根節點為包絡旋轉中心。
		position -= basis * Vector3(place.w / 2.0, 0, -place.d / 2.0)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(spec.model_path, state)
	assert(error == OK, "無法讀回建築GLB")
	model = doc.generate_scene(state)
	model.name = "Model"
	add_child(model)
	# 直接 GLB 讀回時明確啟用作者頂點色，避免不同匯入路徑遺失木材色差。
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if material and material.resource_name.begins_with("detail_vertex_"):
				var colors = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				assert(colors != null and not colors.is_empty(), "細節材質缺少頂點色")
				material.vertex_color_use_as_albedo = true
	var body := StaticBody3D.new()
	body.name = "StructureCollision"
	add_child(body)
	for c: Dictionary in spec.collisions:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size_xyz(c.size)
		cs.shape = box
		cs.position = xyz(c.position)
		cs.rotation = Vector3(c.rotation[0], c.rotation[2], -c.rotation[1])
		cs.name = "shape_%03d" % body.get_child_count()
		body.add_child(cs)
	for p: Dictionary in spec.portals:
		var leaf := LEAF.new()
		leaf.name = p.name
		leaf.swing = p.swing
		leaf.bidirectional = p.kind == "door"
		leaf.base_transform = Transform3D(Basis(Vector3.UP, p.yaw), xyz(p.hinge))
		# 雙向門採距門邊50mm的偏置轉軸，避免厚門反向掃入深門框。
		# 葉片與碰撞反向平移等量，關閉外形及開口尺寸保持原位。
		var pivot_setback: float = .05 if leaf.bidirectional else 0.0
		leaf.base_transform.origin += leaf.base_transform.basis.x * pivot_setback
		leaf.transform = leaf.base_transform
		leaf.shape = BoxShape3D.new()
		leaf.shape.size = Vector3(p.width, p.height, p.depth)
		leaf.shape_offset = Vector3(p.width / 2.0 - pivot_setback, p.height / 2.0, 0)
		var cs := CollisionShape3D.new()
		cs.shape = leaf.shape
		cs.position = leaf.shape_offset
		leaf.add_child(cs)
		add_child(leaf)
		var visual := model.find_child(p.name, true, false) as Node3D
		assert(visual != null, "活動部件在GLB中遺失")
		visual.reparent(leaf, false)
		visual.transform = Transform3D(Basis.IDENTITY,Vector3(-pivot_setback,0,0))
		leaves.append(leaf)
