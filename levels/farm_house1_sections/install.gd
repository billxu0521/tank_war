extends RefCounted
## 西北農宅的牆墩依原抹土分跨，窗楣、門楣均有兩端實座。
const PARTS := preload("res://levels/farm_house1_sections/sections.scn")
const WALLS := ["WallN","WallS","WallE","WallW"]

static func bearing(wall: Node3D, coordinate: float, axis: int, height: float) -> StaticBody3D:
	for unit: Node3D in wall.get_children():
		var solid := unit.get_node_or_null("Masonry") as CollisionShape3D
		if not solid: continue
		var box: AABB = solid.transform * solid.shape.get_debug_mesh().get_aabb()
		if coordinate >= box.position[axis]-.001 and coordinate <= box.end[axis]+.001 and height >= box.position.y-.001 and height <= box.end.y+.001:
			return unit
	push_error("西北農宅牆段承座缺失 %s %.3f %.3f" % [wall.name,coordinate,height])
	return null

static func seat(node: Node3D, bearings: Array) -> void:
	var seats := []
	for part: Node in bearings:
		seats.append([str(node.get_parent().get_path_to(part))])
	node.set_meta("support_seats",seats)
	node.set_meta("depends_on",PackedStringArray())
	node.set_meta("ground_anchor",seats.is_empty())

static func flanks(wall: Node3D, head: StaticBody3D, axis: int) -> Array:
	var shape := head.get_node("Masonry") as CollisionShape3D
	var box: AABB = shape.transform * shape.shape.get_debug_mesh().get_aabb()
	return [bearing(wall,box.position[axis]-.02,axis,1.6),bearing(wall,box.end[axis]+.02,axis,1.6)]

# 完整時沿用原牆的一次繪製；該面出現缺口後才繪製剩下的局部土坯。
static func draw_wall(original: MeshInstance3D, units: Array) -> void:
	var intact := units.all(func(unit):return unit.visible)
	original.visible=intact
	for unit: StaticBody3D in units: unit.get_node("StockAssembly").visible=not intact

static func mount_wall(site: Node3D, source: Node3D, id: String) -> void:
	var wall := site.get_node(id) as StaticBody3D
	wall.remove_meta("structure_material")
	wall.remove_from_group("farm_building_parts")
	# 原節點保留門窗路徑，舊牆退出碰撞與渲染。
	for child in wall.get_children():
		if child is GeometryInstance3D: child.hide()
		if child is CollisionShape3D: child.disabled=true
		if child.name == "InnerBoardStops": child.hide()
	var axis := 0 if id in ["WallN","WallS"] else 2
	var units := source.get_node(id).get_children()
	var original := wall.get_node("StockAssembly" if id=="WallN" else "RevisedStock") as MeshInstance3D
	for body: StaticBody3D in units:
		body.reparent(wall,false)
		body.collision_layer=wall.collision_layer
		body.collision_mask=wall.collision_mask
		body.set_meta("component","wall")
		body.set_meta("structure_material","brick")
		body.set_meta("storey",1)
		body.set_meta("bay",id)
		body.add_to_group("farm_building_parts")
		body.set_meta("stable_id",str(site.get_parent().get_path_to(body)))
		seat(body,[])
		body.visibility_changed.connect(draw_wall.bind(original,units))
	draw_wall(original, units)
	for label: String in ["WindowHead","DoorHead"]:
		var head := wall.get_node_or_null(label) as StaticBody3D
		if head: seat(head,flanks(wall,head,axis))
	if id == "WallN":
		seat(wall.get_node("NorthGlass"),[wall.get_node("WindowSill"),wall.get_node("WindowHead")])
	else:
		var boarded:=site.get_parent().get_node("FarmBuildings004/ExtraHouse1/"+id+"SecuredShutter")
		seat(boarded,flanks(wall,wall.get_node("WindowHead"),axis))

static func install(farm: Node3D) -> void:
	var site := farm.get_node("House1Interior") as Node3D
	if site.has_node("WallN/Pier00"): return
	var source := PARTS.instantiate()
	for id: String in WALLS: mount_wall(site,source,id)
	source.free()
	var north := site.get_node("WallN")
	var south := site.get_node("WallS")
	var door := site.get_node("SouthDoor") as Door
	# 門扇安在南門左側的鉸鏈墩。
	seat(door,[flanks(south,south.get_node("DoorHead"),0)[0]])
	for beam: StaticBody3D in site.find_children("Roof_Joist*","StaticBody3D",false,false):
		var shape: CollisionShape3D = beam.find_children("*","CollisionShape3D",false,false)[0]
		var end_x: float = site.to_local(shape.global_position).x
		seat(beam,[bearing(north,end_x,0,4.3),bearing(south,end_x,0,4.3)])
	# 貼地的原夯土飾面和足下碰撞保留為地面，地面家具各自接地。
	var house:=site.get_node("House")
	house.get_node("PackedFloor").name="CompactedEarth"
	for furniture: StaticBody3D in house.get_node("Furnishings").get_children():
		if furniture.name==&"PegRail":
			var model: MeshInstance3D=furniture.find_children("*","MeshInstance3D",true,false)[0]
			var center: Vector3=site.to_local(model.to_global(model.get_aabb().get_center()))
			seat(furniture,[bearing(site.get_node("WallE"),center.z,2,center.y)])
		else: seat(furniture,[])
