extends RefCounted
const BASE := preload("res://levels/farm_interiors/install.gd")
const PARTS := preload("res://levels/farm_house1_r002/north.glb")
const PANEL := preload("res://levels/farm_house1_r002/wall.gd")
const GLAZING := preload("res://levels/farm_house1_r002/pane.gd")

static func piece(parent: Node3D, mesh: Mesh, paint: Material, id: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.material_override = paint
	parent.add_child(node)
	return node

static func install(farm: Node3D) -> void:
	BASE.install(farm)
	var site := farm.get_node_or_null("House1Interior")
	if not site or site.has_node("WallN"):
		return
	var model := PARTS.instantiate()
	var meshes := {}
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		meshes[String(node.name)] = node.mesh
	model.free()
	var shell: StaticBody3D = site.get_node("House")
	var paint: Material = shell.get_node("Envelope").material_override
	var clear_glass: Material = shell.get_node("NorthGlass").material_override
	var visual_floor := piece(shell,meshes.Floor,paint,"Floor")
	visual_floor.set_meta("component","floor")
	shell.get_node("Kitchen").mesh = meshes.Kitchen
	shell.get_node("KitchenCollision").shape = meshes.Kitchen.create_trimesh_shape()
	shell.get_node("Envelope").free()
	shell.get_node("NorthGlass").free()
	shell.get_node("NorthWallAndWindow").free()
	var solids := {"WallS":["SouthWestPier","SouthEastPier","DoorHead"],"WallN":[],
			"WallW":["WestWall"],"WallE":["EastWall"],"Roof":["Roof"]}
	for id: String in solids:
		var panel := PANEL.new()
		panel.name = id
		panel.set_meta("component","roof" if id=="Roof" else "wall")
		panel.set_meta("material","wood_dark" if id=="Roof" else "adobe")
		panel.set_meta("structure_material",&"wood" if id=="Roof" else &"brick")
		panel.set_meta("storey",1)
		panel.collision_layer = shell.collision_layer
		panel.collision_mask = shell.collision_mask
		site.add_child(panel)
		piece(panel,meshes[id],paint,"Boards" if id=="Roof" else "MasonryAndTrim")
		for shape_name in solids[id]:
			shell.get_node(shape_name).reparent(panel)
	var north: StaticBody3D = site.get_node("WallN")
	for side in [-1,1]:
		BASE.box(north,"PierLeft" if side<0 else "PierRight",Vector3(side*3.85,2.25,-4.375),Vector3(6.3,4.5,.25))
	BASE.box(north,"Sill",Vector3(0,.43,-4.375),Vector3(1.40,.86,.25))
	BASE.box(north,"Head",Vector3(0,3.52,-4.375),Vector3(1.40,1.96,.25))
	var sash := GLAZING.new()
	sash.name = "NorthGlass"
	sash.position = Vector3(-.70,.86,-4.375)
	sash.collision_layer = north.collision_layer
	sash.collision_mask = north.collision_mask
	BASE.box(sash,"Pane",Vector3(.70,.84,0),Vector3(1.40,1.68,.036))
	var plate := BoxMesh.new()
	plate.size = Vector3(1.40,1.68,.036)
	var glass := piece(sash,plate,clear_glass,"Glass")
	glass.position = Vector3(.70,.84,0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece(sash,meshes.SashBars,paint,"Dividers").position = -sash.position
	north.add_child(sash)
	north.glass = sash
	site.get_node("WallS").leaf = site.get_node("SouthDoor")
