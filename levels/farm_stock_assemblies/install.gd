extends RefCounted
const KIT := "res://levels/farm_stock_assemblies/"
const SITES:=preload("res://levels/farm_stock_assemblies/rooms.json")
const PROXY:=preload("res://levels/farm_buildings_v31/existing.gd")
const PART:=preload("res://levels/farm_buildings_v31/unit.gd")

static func hide_art(n:Node) -> void:
	for child in n.get_children():
		if child.is_in_group("farm_building_parts"): continue
		if child is MeshInstance3D: child.hide()
		else: hide_art(child)

static func install(farm:Node3D) -> void:
	if farm.has_meta("farm_stock_count"): return
	var count:=0
	for site:String in SITES.data:
		if SITES.data[site]["新組裝分件"]==0: continue
		var source=load(KIT+"baked/"+site+".scn") as PackedScene
		if not source:push_error("缺少建材組裝 "+site);return
		var temp:=source.instantiate()
		for view:MeshInstance3D in temp.get_children():
			var body:=farm.get_node_or_null(view.get_meta("target"))
			if not body:push_error("建材失去對位 "+str(view.get_meta("target")));continue
			if body is PROXY:
				for old:Node3D in body.visuals:old.hide()
				body.visuals.clear()
				body.visuals.append(view)
			elif body is MeshInstance3D:
				# 保留原現役節點與碰撞，讓原材料直接換成按建材合批的網格。
				body.mesh=view.mesh
				body.material_override=null
				body.set_meta("stock_source",KIT+"rooms/"+site+".tscn")
				body.set_meta("stock_count",view.get_meta("members"))
				count+=1
				continue
			else:hide_art(body)
			view.owner=null
			temp.remove_child(view)
			view.name="StockAssembly"
			body.add_child(view)
			body.set_meta("stock_source",KIT+"rooms/"+site+".tscn")
			body.set_meta("stock_count",view.get_meta("members"))
			count+=1
		temp.free()
	farm.set_meta("farm_stock_count",count)

