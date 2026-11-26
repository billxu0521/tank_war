extends RefCounted
## 依原件位置拆開屋面，完整木料、折邊鐵片保持原位置。每個場所共用原材的繪製。
const STOCK=preload("res://levels/farm_roof_sections/stock.json")
const UNIT=preload("res://levels/farm_buildings_v31/unit.gd")
const GROUPS=preload("res://levels/farm_stock_groups/install.gd")
const STOCK_ROOT="res://levels/farm_stock_assemblies/"
static func pose(a:Array)->Transform3D:
	return Transform3D(Vector3(a[0],a[3],a[6]),Vector3(a[1],a[4],a[7]),Vector3(a[2],a[5],a[8]),Vector3(a[9],a[10],a[11]))

static func collider(body:StaticBody3D,name_:String,t:Transform3D,bounds:AABB,skip:bool):
	var c:=CollisionShape3D.new()
	c.name=name_
	var box:=BoxShape3D.new()
	box.size=t.basis.get_scale().abs()*bounds.size
	c.shape=box
	c.transform=Transform3D(t.basis.orthonormalized(),t*bounds.get_center())
	if skip:c.set_meta("debris_skip",true)
	body.add_child(c)

static func install(farm:Node3D, only_site:String="") -> void:
	var data:Dictionary=STOCK.data
	var sites:Dictionary={}
	var prototype:Dictionary={}
	for path:String in data:
		if only_site!="" and path.get_slice("/",1)!=only_site:continue
		var old:=farm.get_node_or_null(path) as StaticBody3D
		if not old:continue
		var site:=old.get_parent() as Node3D
		if not sites.has(site):sites[site]={"batches":{},"views":[],"frames":[]}
		var bank:Dictionary=sites[site]
		var bay:=str(old.name).trim_suffix("Cover")
		for group:String in data[path]:
			var is_rail:=group.ends_with("Rails")
			var side:="North" if group.begins_with("North") else "South"
			var body:=UNIT.new()
			body.name=bay+group
			body.transform=old.transform
			body.collision_layer=old.collision_layer
			body.collision_mask=old.collision_mask
			body.set_meta("storey",old.get_meta("storey",1))
			body.set_meta("bay",bay)
			body.set_meta("component","frame" if is_rail else "roof")
			body.set_meta("structure_material","wood")
			body.set_meta("stock_source",old.get_meta("stock_source",""))
			var seat:=bay+side+"Rails"
			if is_rail:seat=bay+side+"Seat" if site.has_node(bay+side+"Seat") else bay+"Tie"
			body.set_meta("support_seats",[[seat]])
			body.add_to_group("farm_building_parts")
			site.add_child(body)
			body.set_meta("stable_id",str(farm.get_path_to(body)))
			var view:=MeshInstance3D.new()
			view.name="StockAssembly"
			body.add_child(view)
			var owner_index:int=bank.views.size()
			bank.views.append(view)
			bank.frames.append(old.transform)
			for row:Array in data[path][group]:
				var stock:String=row[1]
				var finish:String=row[2]
				var key:=stock+"_"+finish
				if not prototype.has(key):
					var m:Mesh=load(STOCK_ROOT+"stock/"+stock+".res").duplicate()
					var mat:Material=load(STOCK_ROOT+"finishes/"+finish+".tres")
					for idx in m.get_surface_count():m.surface_set_material(idx,mat)
					prototype[key]=m
				if not bank.batches.has(key):bank.batches[key]={"owners":PackedInt32Array(),"poses":PackedVector3Array()}
				var batch:Dictionary=bank.batches[key]
				var t:=pose(row[3])
				batch.owners.append(owner_index)
				batch.poses.append_array(PackedVector3Array([t.basis.x,t.basis.y,t.basis.z,t.origin]))
				collider(body,row[0],t,prototype[key].get_aabb(),stock=="folded_sheet")
		old.hide()
		site.remove_child(old)
		old.free()
	for site:Node3D in sites:
		var bank:Dictionary=sites[site]
		var holder:=Node3D.new()
		holder.name="RoofStockBatches"
		site.add_child(holder)
		var frames:Array[Transform3D]=[]
		frames.assign(bank.frames)
		var views:Array[Node3D]=[]
		views.assign(bank.views)
		for key:String in bank.batches:
			var item:=MultiMeshInstance3D.new()
			item.name=key
			holder.add_child(item)
			for field:String in ["owners","poses"]:item.set_meta(field,bank.batches[key][field])
			item.set_meta("prototype",prototype[key])
			var batch:=GROUPS.Batch.new()
			batch.start(item,frames,views)
