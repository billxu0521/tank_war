extends RefCounted
const PARTS=preload("res://levels/farm_house1_furniture/parts.scn")
static func install(farm:Node3D):
	var house:=farm.get_node("House1Interior/House") as StaticBody3D
	if house.has_node("Furnishings"):return
	var fresh:=PARTS.instantiate()
	house.add_child(fresh)
	for body:StaticBody3D in fresh.get_children():
		body.collision_layer=house.collision_layer;body.collision_mask=house.collision_mask
		body.add_to_group("farm_building_parts")
		body.set_meta("stable_id",str(farm.get_path_to(body)))
	for room:String in ["Kitchen","Sleeping"]:
		house.get_node(room).hide()
		house.get_node(room+"Collision").disabled=true
