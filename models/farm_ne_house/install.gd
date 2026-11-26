extends RefCounted
const SCENE := preload("res://models/farm_ne_house/NortheastFarmhouse.tscn")
const OLD := ^"FarmShell/農舍 4"

static func install(farm:Node3D) -> void:
	var old:=farm.get_node_or_null(OLD)
	var existing:=farm.get_node_or_null("NortheastFarmhouse")
	if old==null and existing and existing.scene_file_path==SCENE.resource_path: return
	if not old is MeshInstance3D or existing:
		push_error("農舍 4 的建圖入口已變動")
		return
	var bodies:=old.find_children("*","StaticBody3D",true,false)
	if bodies.size()!=1:
		push_error("農舍 4 的原碰撞已變動")
		return
	var house:StaticBody3D=SCENE.instantiate()
	house.position=Vector3(49,0,-39)
	house.rotation.y=deg_to_rad(-12.)
	house.collision_layer=bodies[0].collision_layer
	house.collision_mask=bodies[0].collision_mask
	old.free()
	farm.add_child(house)
