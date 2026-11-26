extends RefCounted
## 在四席農莊生成灰盒及其碰撞後呼叫一次。模型內的碰撞取自可見構件。
const SITES := [
	["西北農車棚","NorthwestWagonShed",Vector3(-64,0,-71),-18.,preload("res://models/farm_spawn_sheds/NorthwestWagonShed_r002.glb")],
	["東南卸車棚","SoutheastUnloadingShed",Vector3(62,0,65),-20.,preload("res://models/farm_spawn_sheds/SoutheastUnloadingShed_r003.glb")]
]

static func install(farm:Node3D) -> void:
	var changes:Array=[]
	for site in SITES:
		var old:=farm.get_node_or_null("FarmShell/"+site[0])
		var existing:=farm.get_node_or_null(site[1])
		if old==null and existing!=null and existing.scene_file_path==site[4].resource_path:
			continue
		if not (old is MeshInstance3D) or farm.has_node(site[1]):
			push_error("車棚現況不符，請核對節點 "+site[0])
			return
		var bodies:=old.find_children("*","StaticBody3D",true,false)
		if bodies.size()!=1:
			push_error("車棚原碰撞數量已變動 "+site[0])
			return
		changes.append([site,old,bodies[0].collision_layer,bodies[0].collision_mask])
	for change in changes:
		var site:Array=change[0]
		var old:Node=change[1]
		var unit:Node3D=site[4].instantiate()
		unit.name=site[1]
		unit.position=site[2]
		unit.rotation.y=deg_to_rad(site[3])
		for body in unit.find_children("*","StaticBody3D",true,false):
			body.collision_layer=change[2]
			body.collision_mask=change[3]
		old.free()
		farm.add_child(unit)
