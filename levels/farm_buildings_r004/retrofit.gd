extends RefCounted
const KIT := "res://levels/farm_buildings_r004/"
const PROXY := preload("res://levels/farm_buildings_v31/existing.gd")

static func replace_body(old:StaticBody3D, revised:StaticBody3D) -> void:
	# 換掉原形的子圖像與碰撞，讓舊部位保有名稱、行為與母圖登記。
	if old is PROXY:
		for visual:Node3D in old.visuals:visual.hide()
		for shape:CollisionShape3D in old.shapes:shape.disabled=true
		old.visuals.clear();old.shapes.clear()
	for child in old.get_children():
		if child is CollisionShape3D:child.free()
		elif child is GeometryInstance3D:child.hide()
	for child in revised.get_children():
		if child is CollisionShape3D or child is MeshInstance3D:
			if child is MeshInstance3D:child.name="RevisedStock"
			child.reparent(old,true)
			if old is PROXY:old.capture(child)
	old.set_meta("stock_source",revised.get_meta("stock_source"))
	revised.free()

static func install(farm:Node3D,holder:Node3D) -> void:
	var kit=load(KIT+"install.gd")
	var changes:Dictionary=load(KIT+"existing.json").data
	for id:String in changes:
		var site:=farm.get_node("FarmBuildings31/"+id) as Node3D
		var extra:Node3D
		if ResourceLoader.exists(KIT+"Extra"+id+".json"):
			extra=kit.make_site(farm,holder,"Extra"+id,holder.global_transform.affine_inverse()*site.global_transform)
		for path:String in changes[id]:
			var n:=farm.get_node_or_null(path) as StaticBody3D
			if not n:push_error("原棟部位缺失 "+path);continue
			var row:Dictionary=changes[id][path]
			var seats:Array=[]
			for group:Array in row.seats:
				var choices:Array=[]
				for p:String in group:
					var target:=farm.get_node_or_null(NodePath(p))
					if not target:push_error("支點未載入 "+p);continue
					choices.append(str(n.get_parent().get_path_to(target)))
				seats.append(choices)
			n.set_meta("support_seats",seats)
			n.set_meta("ground_anchor",row.get("ground",false))
			if row.has("window_role"):n.set_meta("window_role",row.window_role)
			if row.has("trim_jamb"):
				var solids:Array=[]
				for child in n.get_children():
					if child is CollisionShape3D:solids.append(child)
					if child is MeshInstance3D:child.hide()
				if solids.size()>=5:solids[4].free()
			if row.has("ramp"):
				var first:CollisionShape3D
				for child in n.get_children():
					if child is CollisionShape3D:first=child;break
				if first:
					var r:Array=row.ramp
					var dir:Vector3=n.global_basis.inverse()*site.global_basis*Vector3(r[0],0,r[1])
					var low:float=n.to_local(site.to_global(Vector3(0,r[2],0))).y
					var high:float=n.to_local(site.to_global(Vector3(0,r[3],0))).y
					kit.ramp(n,first,dir.normalized(),low,high)
		if extra:
			var added:Dictionary=load(KIT+str(extra.name)+".json").data
			for key:String in added:
				if added[key].has("retire"):
					var retired:=farm.get_node(NodePath(added[key].retire)) as StaticBody3D
					retired.hide()
					retired.get_parent().remove_child(retired)
					retired.free()
				if added[key].has("replace"):
					replace_body(farm.get_node(added[key].replace),extra.get_node(NodePath(key)))
