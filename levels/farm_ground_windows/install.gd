extends RefCounted
## 接在室內修訂後、全圖破壞登記前；所有門窗、牆段與家具沿用舊身分。
const KIT := "res://levels/farm_ground_windows/"
const BASE := preload("res://levels/farm_buildings_r004/install.gd")
const PREVIOUS := preload("res://levels/farm_interior_followup/install.gd")

static func install(farm: Node3D) -> void:
	if farm.has_meta("farm_ground_windows"): return
	for task: Array in [["House2","MilkWashBench",Vector3(1.08,0,0)],["House7","BootBench",Vector3(0,0,2.0)]]:
		var room := farm.get_node("FarmBuildings31/"+task[0]) as Node3D
		var batches := {}
		for node: MultiMeshInstance3D in farm.get_node("StockBatches/"+task[0]+"/Batches").get_children():
			batches[node.multimesh]=node
		PREVIOUS.move_stock(room.get_node(task[1]),room.global_basis*task[2],batches)
	var spec: Dictionary=load(KIT+"parts.json").data
	var art: Node3D=load(KIT+"baked/WorkWindows.scn").instantiate()
	for key: String in spec:
		var row: Dictionary=spec[key]
		var room := farm.get_node("FarmBuildings31/"+row.site) as Node3D
		var body := farm.get_node(NodePath(row.target)) as StaticBody3D
		# 先退下原圖像，既有合批會跟著原圖像的可見狀態移除該件。
		for old: GeometryInstance3D in body.find_children("*","GeometryInstance3D",true,false):
			old.hide()
			if old.name==&"StockAssembly": old.name="PriorStock"
		for old in body.get_children():
			if old is CollisionShape3D: old.free()
		var frame: Transform3D=room.global_transform
		if row.has("hinge"):
			var leaf=body as Door
			leaf.global_transform=frame*BASE.xf(row.hinge)
			leaf._closed=leaf.transform
			leaf.width=row.width
			leaf.height=row.height
			leaf.travel=row.travel
			leaf.set_meta("window_role","guarded_vent" if row.guard else "operable")
			frame=leaf.global_transform
		var view := art.get_node(NodePath(key)) as MeshInstance3D
		view.owner=null
		art.remove_child(view)
		view.name="StockAssembly"
		body.add_child(view)
		view.global_transform=frame
		for i in row.shapes.size():
			var shape:=BASE.collision(body,row.shapes[i],"Solid" if i==0 else "Solid"+str(i))
			shape.global_transform=frame*BASE.xf(row.shapes[i][0])
		body.set_meta("stock_source",KIT+"author/WorkWindows.tscn")
		body.set_meta("stock_count",view.get_meta("members"))
	art.free()
	farm.set_meta("farm_ground_windows",true)
