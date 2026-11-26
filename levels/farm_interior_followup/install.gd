extends RefCounted
## 建材組裝與 r004 修訂後、破壞登記前接入。保留各件原生穩定識別與承座。
const KIT := "res://levels/farm_interior_followup/"
const BASE := preload("res://levels/farm_buildings_r004/install.gd")

static func move_stock(body:Node3D, delta:Vector3, batches:Dictionary) -> void:
	var art:=body.get_node_or_null("StockAssembly")
	if art:
		for group:Array in art.get_meta("stock_groups",[]):
			var batch=group[0]
			for id:int in batch.by_owner[group[1]]:
				var node:MultiMeshInstance3D=batches[batch.output]
				batch.origins[id*4+3]+=node.global_basis.inverse()*delta
				batch.output.custom_aabb=batch.output.custom_aabb.merge(batch.read_pose(id)*batch.output.mesh.get_aabb())
				var slot:int=batch.slot_by_id[id]
				if slot>=0:batch.output.set_instance_transform(slot,batch.read_pose(id))
	body.global_position+=delta

static func install(farm:Node3D) -> void:
	if farm.has_meta("farm_interior_followup"):return
	var specs:Dictionary=load(KIT+"sites.json").data
	for site_name:String in specs:
		var site:=farm.get_node("FarmBuildings31/"+site_name) as Node3D
		var art:=load(KIT+"baked/"+site_name+".scn").instantiate() as Node3D
		var entry:Dictionary=specs[site_name]
		for key:String in entry.parts:
			var row:Dictionary=entry.parts[key]
			var body:=farm.get_node(NodePath(row.replace)) as StaticBody3D
			for child in body.get_children():
				if child is CollisionShape3D:child.free()
				elif child is MeshInstance3D:
					child.hide()
					if child.name==&"StockAssembly":child.name="PriorStock"
			var view:=art.get_node(NodePath(key)) as MeshInstance3D
			view.owner=null
			art.remove_child(view)
			view.name="StockAssembly"
			body.add_child(view)
			view.global_transform=site.global_transform
			for i in row.shapes.size():
				var shape:=BASE.collision(body,row.shapes[i],"Solid" if i==0 else "Solid"+str(i))
				shape.global_transform=site.global_transform*BASE.xf(row.shapes[i][0])
			if row.has("plaster_shell"):
				var offset:=BASE.v(row.plaster_shell.position)
				for panel:Array in row.plaster_shell.panels:
					var pts:=PackedVector3Array()
					for vert:Array in panel:pts.append(BASE.v(vert))
					var hull:=ConvexPolygonShape3D.new();hull.points=pts
					var shape:=CollisionShape3D.new();shape.shape=hull;body.add_child(shape)
					shape.global_transform=site.global_transform*Transform3D(Basis(),offset)
					shape.set_meta("debris_skip",true)
			body.set_meta("stock_source",KIT+"author/"+site_name+".tscn")
			body.set_meta("stock_count",view.get_meta("members"))
			if row.has("recipe"):
				body.set_meta("source_asset",row.recipe)
				body.set_meta("structure_material","brick")
		art.free()
		if entry.has("relocate_east"):
			var delta:Vector3=site.global_basis*Vector3(0,0,entry.relocate_east)
			var batches:={}
			for node:MultiMeshInstance3D in farm.get_node("StockBatches/"+site_name+"/Batches").get_children():
				batches[node.multimesh]=node
			for suffix:String in ["Jamb","Apron","LeafL"]:
				var part:=site.get_node("E1Opening0"+suffix) as Node3D
				move_stock(part,delta,batches)
				if suffix=="LeafL":part._closed=part.transform
		if site_name=="YardHouse":
			# 滑窗行程留一段實體把手在窗洞。出納可由兩面拉回。
			var sash=site.get_node("N1Opening1LeafL")
			sash.travel=signf(sash.travel)*sash.width*.62
	install_loft_feet(farm)
	farm.set_meta("farm_interior_followup",true)

## 清選樓的一樓木地板直接鋪在地坪上。每柱有自己的攤壓木座，樓板與柱皆可單拆。
static func install_loft_feet(farm:Node3D) -> void:
	var loft:=farm.get_node("FarmBuildings31/RegistrationRoom/SeedCleaningLoft")
	for side:String in ["North","South"]:
		var post:=loft.get_node("Work2"+side+"Post") as StaticBody3D
		var sole:=preload("res://levels/farm_interior_followup/LoftPostSole.tscn").instantiate() as StaticBody3D
		sole.name="Work2"+side+"PostSole"
		# 上緣接柱底 0.110，下緣落在此跨樓板頂 0.017，座木跨過柱兩側。
		sole.position=Vector3(1.5,.0635,-3.17 if side=="North" else 3.17)
		sole.add_to_group("farm_building_parts")
		loft.add_child(sole)
		sole.set_meta("stable_id",str(farm.get_path_to(sole)))
		post.set_meta("ground_anchor",false)
		post.set_meta("depends_on",PackedStringArray([str(sole.name)]))
		post.set_meta("support_seats",[[str(sole.name)]])

