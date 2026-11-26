extends RefCounted
## 清選樓的穿板孔與果農閣樓使用既有板材合批，依真正板帶、排木及兩端支承登記。
const SECTIONS := preload("res://levels/farm_large_sections/install.gd")
const STOCK := preload("res://levels/farm_loft_sections/stock.json")
const MARK := "farm_loft_sections"

static func install(farm:Node3D) -> void:
	if farm.has_meta(MARK):return
	SECTIONS.install(farm,STOCK.data,MARK)
	# 遊戲出生／落蛋原由此具名實體查詢工作板面；它仍是完整孔西側的一段原板。
	var primary:=farm.get_node("FarmBuildings31/RegistrationRoom/SeedCleaningLoft/Work3Floor")
	for child in primary.get_children():
		if child is CollisionShape3D:
			child.name="Solid"
			break

static func boxes(base:Node3D, pairs:Array)->Array[AABB]:
	var found:Array[AABB]=[]
	var inv:=base.global_transform.affine_inverse()
	for pair:Array in pairs:
		var sh:CollisionShape3D=pair[0]
		if not pair[1] and sh.shape:
			found.append(inv*sh.global_transform*sh.shape.get_debug_mesh().get_aabb())
	return found

static func supports_at(point:Vector3,panels:Dictionary,walls:Dictionary)->Array:
	var near:={}
	for key:String in panels:
		var best:=INF
		for box:AABB in panels[key]:
			var dx:=maxf(maxf(box.position.x-point.x,point.x-box.end.x),0.0)
			var dz:=maxf(maxf(box.position.z-point.z,point.z-box.end.z),0.0)
			best=minf(best,dx*dx+dz*dz)
		near[key]=best
	var shortest:float=near.values().min()
	var ids:=[]
	for key:String in near:
		if near[key]<=shortest+.0005:ids.append(key)
	for key:String in walls:
		if SECTIONS.at_foot(point,walls[key]):ids.append(key)
	return ids

static func wall_tops(reg:Node,base:Node3D,top:float)->Dictionary:
	var found:={}
	var prefix:=str(reg.arena.get_path_to(base)).get_base_dir()
	# 果農屋的外牆在 Timberwork 的母節點，清選樓牆位於本樓層自己的節點。
	if str(base.get_parent().name)=="Timberwork":prefix=prefix.get_base_dir()
	for key:String in reg.entries:
		if key.get_base_dir()!=prefix:continue
		var n:Node=reg.entries[key].native
		if not n or n.get_meta("component","")!="wall":continue
		var near_top:=boxes(base,reg.entries[key].shapes).filter(func(b:AABB):return absf(b.end.y-top)<.04 and b.position.y<top-.35)
		if not near_top.is_empty():found[key]=near_top
	return found

static func contacts(base:Node3D,pairs:Array,top:float)->Array[Vector3]:
	var pos:Array[Vector3]=[]
	var candidate_boxes:=boxes(base,pairs)
	var standing:=candidate_boxes.filter(func(b:AABB):return absf(b.position.y-top)<.065)
	if standing.is_empty():
		# 樓梯斜樑由斜盒的下端接工作面。從變換後的原頂點取腳跟，不能用整道斜梯的中央。
		var points:Array[Vector3]=[]
		var lowest:=INF
		var inv:=base.global_transform.affine_inverse()
		for pair:Array in pairs:
			var sh:CollisionShape3D=pair[0]
			if pair[1] or not sh.shape:continue
			var xf:=inv*sh.global_transform
			var bounds:=sh.shape.get_debug_mesh().get_aabb()
			for corner in 8:
				var v:=xf*bounds.get_endpoint(corner)
				lowest=minf(lowest,v.y);points.append(v)
		for v in points:
			if v.y<lowest+.06:pos.append(Vector3(v.x,top,v.z))
	else:
		for b:AABB in standing:
			var mid:=b.get_center();mid.y=top
			var axis:=0 if b.size.x>=b.size.z else 2
			if b.size[axis]>.65:
				var a:=mid;var z:=mid
				a[axis]-=.42*b.size[axis];z[axis]+=.42*b.size[axis]
				pos.append(a);pos.append(z)
			else:pos.append(mid)
	return pos

static func foot_seats(base:Node3D,pairs:Array,top:float,panels:Dictionary,walls:Dictionary)->Array:
	var pos:=contacts(base,pairs,top)
	if pos.is_empty():return []
	var span:=AABB(pos[0],Vector3.ZERO)
	for v in pos:span=span.expand(v)
	var groups:=[]
	for axis:int in [0,2]:
		if span.size[axis]<=.45:continue
		var sides:Array=[[],[]]
		for v in pos:
			var side:=int(v[axis]>span.get_center()[axis])
			for key:String in supports_at(v,panels,walls):
				if key not in sides[side]:sides[side].append(key)
		for side:Array in sides:
			if not side.is_empty() and side not in groups:groups.append(side)
	if groups.is_empty():groups.append(supports_at(span.get_center(),panels,walls))
	return groups

static func bind(reg:Node)->void:
	if reg.has_meta(MARK):return
	reg.set_meta(MARK,true)
	var parts:Dictionary=reg.arena.get_meta(MARK)
	for source:String in parts:
		var base:Node3D=reg.arena.get_node(source)
		var panels:={}
		for n:Node3D in parts[source]:
			var path:=str(reg.arena.get_path_to(n))
			panels[path]=boxes(base,reg.entries[path].shapes)
		var top:float=panels[source][0].end.y
		var walls:=wall_tops(reg,base,top)
		for child:String in reg.support_graph.uses.get(source,[]).duplicate():
			var part:Dictionary=reg.entries[child]
			if part.native and part.native.get_meta("split_from","")==source:continue
			var name:=child.get_file()
			if name in ["Work2Guard","Work3Guard","LongGuardTop","BaseGuardTop"]:
				var stem:=name.trim_suffix("Top") if name.ends_with("Top") else name.trim_suffix("Guard")+"Rail"
				var ids:=[1,47] if name.begins_with("Work") else [0,2]
				var rails:=[]
				for i in ids:rails.append([child.get_base_dir()+"/"+stem+"Post"+str(i)])
				reg.require_seats(child,rails)
				continue
			var attached:=foot_seats(base,part.shapes,top,panels,walls)
			if attached.is_empty():continue
			var resolved:=[]
			for choices:Array in reg.support_graph.seats[child]:
				if source not in choices:resolved.append(choices.duplicate());continue
				for bearings:Array in attached:
					var options:=choices.duplicate()
					options.erase(source)
					for key:String in bearings:
						if key!=child and key not in options:options.append(key)
					if not options.is_empty() and options not in resolved:resolved.append(options)
			reg.require_seats(child,resolved)
