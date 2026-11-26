extends RefCounted
## 完整原料依地方分件；保留原受力鍵，另在登記後把附著物轉到真正腳下的板帶。
const KIT=preload("res://levels/farm_roof_sections/install.gd")
const STOCK=preload("res://levels/farm_large_sections/stock.json")
const PROXY=preload("res://levels/farm_buildings_v31/existing.gd")
const FLOOR=1<<16

static func remove_previous(old:StaticBody3D):
	if old is PROXY:
		for n:Node3D in old.visuals:n.hide()
		for sh:CollisionShape3D in old.shapes:sh.disabled=true
		old.visuals.clear();old.shapes.clear()
	for n in old.get_children():
		if n is GeometryInstance3D:n.hide()
		elif n is CollisionShape3D:n.free()

static func actual_name(base:String,label:String,primary:String)->String:
	return base if label==primary else base+"_"+label

static func merged(boxes:Array)->Array:
	# 只合併同平面、另外兩軸全長重合的連續木板；門窗和樓梯口保留。
	for axis:int in [0,2,1,0]:
		var groups:={}
		var b:=(axis+1)%3
		var c:=(axis+2)%3
		for box:AABB in boxes:
			var signature:=[snappedf(box.position[b],.001),snappedf(box.position[c],.001),snappedf(box.size[b],.001),snappedf(box.size[c],.001)]
			var key:=str(signature)
			if not groups.has(key):groups[key]=[]
			groups[key].append(box)
		boxes=[]
		for group:Array in groups.values():
			group.sort_custom(func(l:AABB,r:AABB):return l.position[axis]<r.position[axis])
			var a:AABB=group[0]
			for i in range(1,group.size()):
				var n:AABB=group[i]
				if n.position[axis]<=a.end[axis]+.018:a=a.merge(n)
				else:boxes.append(a);a=n
			boxes.append(a)
	return boxes

static func install(farm:Node3D, stock_data:Dictionary={}, marker:String="large_stock_groups"):
	if farm.has_meta(marker):return
	var all:Dictionary=STOCK.data if stock_data.is_empty() else stock_data
	var sites:={};var prototypes:={};var patches:={}
	for path:String in all:
		var old:=farm.get_node(path) as StaticBody3D
		var site:=old.get_parent() as Node3D
		var base:=str(old.name);var original:=old.transform
		var old_layer:=old.collision_layer
		var row:Dictionary=all[path]
		remove_previous(old)
		patches[path]=[]
		if not sites.has(site):sites[site]={"owners":[],"frames":[],"batches":{}}
		var bank:Dictionary=sites[site]
		for group:Dictionary in row.groups:
			var primary:bool=group.id==row.primary
			var body:StaticBody3D=old if primary else KIT.UNIT.new()
			if not primary:
				body.name=actual_name(base,group.id,row.primary)
				site.add_child(body);body.transform=original
			body.collision_layer=old_layer
			if row.role=="floor" and group.role!="floor":body.collision_layer&=~FLOOR
			if group.role=="floor":body.collision_layer|=FLOOR
			body.collision_mask=old.collision_mask
			body.set_meta("structure_material","wood");body.set_meta("component",group.role)
			body.set_meta("storey",old.get_meta("storey",1));body.set_meta("bay",base)
			body.set_meta("stock_source","res://"+str(row.source));body.set_meta("split_from",path)
			body.set_meta("ground_anchor",group.seats.is_empty())
			body.set_meta("stable_id",str(farm.get_path_to(body)))
			var seats:=[]
			for alternatives:Array in group.seats:
				var names:=[]
				for anchor:String in alternatives:
					var relative:String
					if anchor.begins_with("$"):relative=actual_name(base,anchor.substr(1),row.primary)
					else:relative=str(site.get_path_to(farm.get_node(anchor)))
					names.append(relative)
				seats.append(names)
			body.set_meta("support_seats",seats);body.set_meta("depends_on",PackedStringArray())
			var view:=MeshInstance3D.new();view.name="SectionStock"
			body.add_child(view)
			var idx:int=bank.owners.size()
			bank.owners.append(view);bank.frames.append(original)
			var boxes:={}
			for member:Array in group.rows:
				var stock:String=member[1];var finish:String=member[2];var key:=stock+"_"+finish
				if not prototypes.has(key):
					var mesh:Mesh=load(KIT.STOCK_ROOT+"stock/"+stock+".res").duplicate()
					var paint:Material=load(KIT.STOCK_ROOT+"finishes/"+finish+".tres")
					for s in mesh.get_surface_count():mesh.surface_set_material(s,paint)
					prototypes[key]=mesh
				if not bank.batches.has(key):bank.batches[key]={"owners":PackedInt32Array(),"poses":PackedVector3Array()}
				var t:=KIT.pose(member[3]);var bucket:Dictionary=bank.batches[key]
				bucket.owners.append(idx);bucket.poses.append_array(PackedVector3Array([t.basis.x,t.basis.y,t.basis.z,t.origin]))
				var basis:=t.basis.orthonormalized()
				var aligned:=true
				for unit:Vector3 in [basis.x,basis.y,basis.z]:
					var n:=unit.abs()
					if maxf(n.x,maxf(n.y,n.z))<.999999:aligned=false
				if aligned:
					var tag:String=str(member[0]).get_slice("_",0)
					if not boxes.has(tag):boxes[tag]=[]
					boxes[tag].append(t*prototypes[key].get_aabb())
				else:KIT.collider(body,member[0],t,prototypes[key].get_aabb(),stock=="folded_sheet")
			for tag:String in boxes:
				for box:AABB in merged(boxes[tag]):
					var c:=CollisionShape3D.new()
					var solid:=BoxShape3D.new();solid.size=box.size
					c.shape=solid;c.position=box.get_center()
					if tag in ["Sheet","FoldedSheet"]:c.set_meta("debris_skip",true)
					body.add_child(c)
			if body is PROXY:
				body.capture(view)
				for sh in body.get_children():
					if sh is CollisionShape3D:body.capture(sh)
			if group.id.begins_with("Panel"):patches[path].append(body)
	for site:Node3D in sites:
		var bank:Dictionary=sites[site];var views:Array[Node3D]=[];var frames:Array[Transform3D]=[]
		views.assign(bank.owners);frames.assign(bank.frames)
		var holder:=Node3D.new();holder.name="SectionBatches";site.add_child(holder)
		for key:String in bank.batches:
			var node:=MultiMeshInstance3D.new();node.name=key;holder.add_child(node)
			for field:String in ["owners","poses"]:node.set_meta(field,bank.batches[key][field])
			node.set_meta("prototype",prototypes[key]);KIT.GROUPS.Batch.new().start(node,frames,views)
	farm.set_meta(marker,patches)

static func footprint(owner:Node3D, shapes:Array, only_feet:bool)->AABB:
	var bounds:=AABB();var boxes:Array[AABB]=[]
	var inv:=owner.global_transform.affine_inverse()
	for pair:Array in shapes:
		var shape:CollisionShape3D=pair[0]
		if pair[1] or not shape.shape:continue
		var b:AABB=inv*shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
		boxes.append(b)
	var low:=INF
	for b in boxes:low=minf(low,b.position.y)
	var first:=true
	for b in boxes:
		if only_feet and b.position.y>low+.14:continue
		bounds=b if first else bounds.merge(b)
		first=false
	return bounds

static func near_panels(p:Vector3,panels:Dictionary)->Array:
	var score:=INF
	var distances:={}
	for key:String in panels:
		var box:AABB=panels[key]
		var dx:=maxf(maxf(box.position.x-p.x,p.x-box.end.x),0.)
		var dz:=maxf(maxf(box.position.z-p.z,p.z-box.end.z),0.)
		var dist:=sqrt(dx*dx+dz*dz)
		distances[key]=dist;score=minf(score,dist)
	var found:=[]
	for key:String in distances:
		if distances[key]<=score+.025:found.append(key)
	return found

# 二樓牆腳可直接落在一樓牆頂，兩戶的樓梯平臺也有自己的落地支座。
static func lower_bearings(base:Node3D,reg:Node,source:String)->Dictionary:
	var bearings:={}
	if not source.ends_with("/HomeDeck"):return bearings
	var site:=source.get_slice("/",1)
	var prefix:="FarmBuildings31/"+site+"/"
	var local:=base.global_transform.affine_inverse()
	for key:String in reg.entries:
		if not key.begins_with(prefix):continue
		var label:=key.trim_prefix(prefix)
		var lower_wall:=label.length()>2 and label[0] in ["N","S","E","W"] and label[1]=="1" and label[2]=="B"
		if not lower_wall and label!="Timberwork/LandingExit":continue
		var shapes:=[]
		for pair:Array in reg.entries[key].shapes:
			var shape:CollisionShape3D=pair[0]
			if pair[1] or not shape.shape:continue
			shapes.append(local*shape.global_transform*shape.shape.get_debug_mesh().get_aabb())
		if not shapes.is_empty():bearings[key]=shapes
	return bearings

static func at_foot(point:Vector3,shapes:Array)->bool:
	for b:AABB in shapes:
		if absf(b.end.y-point.y)>.04:continue
		if point.x>=b.position.x-.025 and point.x<=b.end.x+.025 and point.z>=b.position.z-.025 and point.z<=b.end.z+.025:return true
	return false

static func bind(reg:Node):
	var farm:Node3D=reg.arena
	var plan:Dictionary=farm.get_meta("large_stock_groups")
	for source:String in plan:
		var external:Array=reg.support_graph.uses.get(source,[]).duplicate()
		if external.is_empty():continue
		var base:Node3D=farm.get_node(source)
		var bearings:=lower_bearings(base,reg,source)
		var panels:={}
		for panel:Node3D in plan[source]:
			var id:=str(farm.get_path_to(panel))
			panels[id]=footprint(base,reg.entries[id].shapes,false)
		for dependent:String in external:
			var rec:Dictionary=reg.entries[dependent]
			if rec.native and rec.native.get_meta("split_from","")==source:continue
			var box:=footprint(base,rec.shapes,true)
			if box.size.length_squared()<.000001:continue
			var mid:=box.get_center();mid.y=box.position.y
			var axis:=0 if box.size.x>box.size.z else 2
			var samples:=[mid]
			if box.size[axis]>.65:
				var a:=mid;var b:=mid
				a[axis]-=box.size[axis]*.38;b[axis]+=box.size[axis]*.38;samples=[a,b]
			var revised:=[]
			for group:Array in reg.support_graph.seats.get(dependent,[]):
				if source not in group:revised.append(group.duplicate());continue
				for point:Vector3 in samples:
					var next:=group.duplicate();next.erase(source)
					var direct:=[]
					for id:String in bearings:
						if id!=dependent and at_foot(point,bearings[id]):direct.append(id)
					for id:String in near_panels(point,panels):
						if direct.is_empty() or at_foot(point,[panels[id]]):direct.append(id)
					for id:String in direct:
						if id not in next:next.append(id)
					if next not in revised:revised.append(next)
			reg.require_seats(dependent,revised)
