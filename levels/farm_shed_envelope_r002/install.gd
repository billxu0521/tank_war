extends RefCounted
## 在 r004 及既有農棚家具安裝完成後、正式破壞登記前，換入可獨立受擊的兩棚外殼。
const ENVELOPE:=preload("res://levels/farm_shed_envelope_r002/envelope.scn")

static func retire(body:StaticBody3D)->void:
	body.set_present(false)
	body.get_parent().remove_child(body)
	body.free()

static func install(farm:Node3D)->void:
	if farm.has_meta("shed_envelope_installed"):return
	var source:=ENVELOPE.instantiate()
	for group:Node3D in source.get_children():
		var id:=str(group.name)
		var site:Node3D=farm.get_node("FarmBuildings31/"+id)
		var extra:Node3D=farm.get_node("FarmBuildings004/Extra"+id)
		var layer:int=site.get_node("Roof").collision_layer
		var mask:int=site.get_node("Roof").collision_mask
		for label:String in ["Roof","Backwall","Frame"]:retire(site.get_node(label))
		if id.begins_with("South"):retire(extra.get_node("EastSideWall"))
		for body:StaticBody3D in group.get_children():
			group.remove_child(body);site.add_child(body)
			body.collision_layer=layer;body.collision_mask=mask
			body.set_meta("stable_id",str(farm.get_path_to(body)))
	source.free()
	farm.set_meta("shed_envelope_installed","r002")
