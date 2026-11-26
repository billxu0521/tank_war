extends RefCounted
## 在 A v3.0 的全圖外觀安裝完畢後呼叫。只接手農舍 1。
const HOUSE := preload("res://levels/farm_interiors/house1.glb")
const HINGE := preload("res://levels/farm_interiors/house_door.gd")

static func box(parent: StaticBody3D, id: String, p: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.name = id
	node.shape = shape
	node.position = p
	parent.add_child(node)

static func install(farm: Node3D) -> void:
	if farm.has_node("House1Interior"):
		return
	var old := farm.get_node_or_null("FarmShell/農舍 1") as MeshInstance3D
	var visual := farm.get_node_or_null("FarmStyleBuildings/House1") as MeshInstance3D
	if not old or not visual or not farm is ArenaMap:
		push_error("農舍 1 缺少 A v3.0 的原建築或外觀")
		return
	var shapes := old.find_children("*", "CollisionShape3D", true, false)
	var packed := HOUSE.instantiate()
	var models := {}
	for item: MeshInstance3D in packed.find_children("*", "MeshInstance3D", true, false):
		models[String(item.name)] = item.mesh
	packed.free()
	if shapes.size() != 1 or not models.has_all(["Envelope", "Kitchen", "Sleeping", "DoorLeaf"]):
		push_error("農舍 1 固體或匯入構件與來源不符")
		return
	var site := Node3D.new()
	site.name = "House1Interior"
	site.transform = farm.global_transform.affine_inverse() * visual.global_transform
	farm.add_child(site)
	var original_body := shapes[0].get_parent() as CollisionObject3D
	var shell := StaticBody3D.new()
	shell.name = "House"
	shell.collision_layer = original_body.collision_layer
	shell.collision_mask = original_body.collision_mask
	site.add_child(shell)
	var paint := visual.get_active_material(0)
	for key in ["Envelope", "Kitchen", "Sleeping"]:
		var part := MeshInstance3D.new()
		part.name = key
		part.mesh = models[key]
		part.material_override = paint
		shell.add_child(part)
		if key != "Envelope":
			var hull := CollisionShape3D.new()
			hull.name = key + "Collision"
			hull.shape = part.mesh.create_trimesh_shape()
			shell.add_child(hull)
	box(shell,"WestWall",Vector3(-6.875,2.25,0),Vector3(.25,4.5,9))
	box(shell,"EastWall",Vector3(6.875,2.25,0),Vector3(.25,4.5,9))
	box(shell,"NorthWallAndWindow",Vector3(0,2.25,-4.375),Vector3(14,4.5,.25))
	box(shell,"SouthWestPier",Vector3(-5.39,2.25,4.375),Vector3(3.22,4.5,.25))
	box(shell,"SouthEastPier",Vector3(2.31,2.25,4.375),Vector3(9.38,4.5,.25))
	box(shell,"DoorHead",Vector3(-3.08,3.375,4.375),Vector3(1.4,2.25,.25))
	box(shell,"Roof",Vector3(0,4.3975,0),Vector3(14,.205,9))
	box(shell,"PackedFloor",Vector3(0,.018,0),Vector3(13.96,.036,8.96))
	# 北窗為固定透光玻璃，牛仔可看院子。碰撞與窗框合併。
	var glass := MeshInstance3D.new()
	glass.name = "NorthGlass"
	var pane := BoxMesh.new()
	pane.size = Vector3(1.18,1.15,.022)
	glass.mesh = pane
	glass.position = Vector3(0,1.555,-4.37)
	var glazing := StandardMaterial3D.new()
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.albedo_color = Color(.54,.71,.74,.19)
	glazing.roughness = .35
	glass.material_override = glazing
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(glass)
	var door: Door = HINGE.new()
	door.name = "SouthDoor"
	door.position = Vector3(-3.76,0,4.43)
	door.collision_layer = original_body.collision_layer
	door.collision_mask = original_body.collision_mask
	var leaf := MeshInstance3D.new()
	leaf.mesh = models.DoorLeaf
	leaf.material_override = paint
	door.add_child(leaf)
	box(door,"Solid",Vector3(.68,1.125,0),Vector3(1.36,2.19,.10))
	site.add_child(door)
	(farm as ArenaMap)._doors.append(door)
	shapes[0].disabled = true
	visual.visible = false
