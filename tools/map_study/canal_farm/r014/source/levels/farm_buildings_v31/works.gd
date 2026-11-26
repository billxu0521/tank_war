extends RefCounted
const R:=preload("res://levels/farm_buildings_v31/room.gd")
const TOWER:=preload("res://levels/farm_buildings_v31/tower.gd")
const EXIST:=preload("res://levels/farm_buildings_v31/existing.gd")

static func retire(n:Node) -> void:
	if not n: return
	if n is Node3D: n.visible=false
	if n is CollisionShape3D: n.disabled=true
	for c in n.get_children(): retire(c)

static func proxy(site:Node3D,key:String,role:String,mat:String,objects:Array,bay:String) -> void:
	var piece:=EXIST.new()
	site.identify(piece,key,role,mat,bay)
	site.add_child(piece)
	for n:Node in objects:
		if n: piece.capture(n)
	for shape:CollisionShape3D in piece.shapes:
		# 舊固定圖像沿用舊路徑；物理命中直接取得新的分件。
		var original:=shape.get_parent() as CollisionObject3D
		piece.collision_layer=original.collision_layer
		piece.collision_mask=original.collision_mask
		shape.reparent(piece,true)

static func split_sleeping(site:Node3D,old:Node3D) -> void:
	# 原 BLD 組裝圖的土坯隔間中心 X=2.22；床及衣箱完全在 X>4。
	var room:=old.get_node("House")
	var view:=room.get_node("Sleeping") as MeshInstance3D
	var original:=view.mesh
	var groups:=[ArrayMesh.new(),ArrayMesh.new()]
	for surf in original.get_surface_count():
		var data:=original.surface_get_arrays(surf)
		var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=data[Mesh.ARRAY_NORMAL]
		var colors:PackedColorArray=data[Mesh.ARRAY_COLOR]
		var triangles:PackedInt32Array=data[Mesh.ARRAY_INDEX]
		if triangles.is_empty():
			for i in vertices.size(): triangles.append(i)
		var outputs:=[SurfaceTool.new(),SurfaceTool.new()]
		var counts:=[0,0]
		for builder in outputs: builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for start in range(0,triangles.size(),3):
			var index:=int(vertices[triangles[start]].x<3.)
			for j in 3:
				var ix:=triangles[start+j]
				if not normals.is_empty(): outputs[index].set_normal(normals[ix])
				if not colors.is_empty(): outputs[index].set_color(colors[ix])
				outputs[index].add_vertex(vertices[ix])
			counts[index]+=3
		for i in 2:
			if counts[i]>0: outputs[i].commit(groups[i])
	var partition=site.unit("BedroomPartition","wall","brick","BedAlcove")
	var wall:=MeshInstance3D.new()
	wall.mesh=groups[1]
	wall.material_override=view.material_override
	partition.add_child(wall)
	var collision:=CollisionShape3D.new()
	collision.shape=wall.mesh.create_trimesh_shape()
	partition.add_child(collision)
	view.mesh=groups[0]
	room.get_node("SleepingCollision").shape=view.mesh.create_trimesh_shape()

static func house_one(farm:Node3D,site:Node3D) -> void:
	var old:=farm.get_node("House1Interior")
	split_sleeping(site,old)
	for id:String in ["WallN","WallE","WallS","WallW","Roof"]:
		var n:=old.get_node(id)
		site.identify(n,id,"roof" if id=="Roof" else "wall","wood" if id=="Roof" else "brick",id)
	var door:=old.get_node("SouthDoor")
	site.identify(door,"SouthDoor","door","wood","WallS",["WallS"])
	var north:=old.get_node("WallN/NorthGlass")
	site.identify(north,"NorthGlass","window","glass","WallN",["../WallN"])
	# 補齊室內一面的封固痕跡，拆牆會隨原牆隱藏。
	for side in ["WallE","WallW","WallS"]:
		var wall:=old.get_node(side)
		var u:=R.UNIT.new()
		u.name="InnerBoardStops"
		wall.add_child(u)
		if side=="WallS": u.position=Vector3(2.4,1.62,4.235)
		else:
			u.position=Vector3(6.72 if side=="WallE" else -6.72,1.62,0)
			u.rotation.y=PI*.5
		u.cuboid(Vector3.ZERO,Vector3(1.14,.92,.038),R.DARK,false)
		for y:float in [-.32,.32]: u.cuboid(Vector3(0,y,0),Vector3(1.23,.09,.08),R.OAK,false)
		u.finish()

static func service(farm:Node3D,site:Node3D,id:String) -> void:
	var old:=farm.get_node(id)
	if id in ["NorthwestWagonShed","SoutheastUnloadingShed"]:
		for n in old.get_children():
			if n is MeshInstance3D:
				var role:String={"Frame":"frame","Roof":"roof","Backwall":"wall","ReceivingDeck":"floor"}.get(str(n.name),"furniture")
				proxy(site,str(n.name),role,"wood",[n],str(n.name))
	elif id=="MilkStation":
		farm.get_node("FarmStyleBuildings/MilkFrame").hide()
		for n in old.get_children():
			if n is CollisionShape3D or n is MeshInstance3D: retire(n)
		site.width=5.2
		site.depth=6.2
		for x in [-2.25,2.25]:
			for z in [-2.7,2.7]:
				site.box("Post"+("W" if x<0 else "E")+("N" if z<0 else "S"),Vector3(x,1.22,z),Vector3(.19,2.45,.19),R.DARK,"support","wood","MilkFrame")
		site.roof(2.45)
	elif id=="PayOffice": pay(site,old)
	else: weigh(site,old,farm)

static func pay(site:Node3D,old:Node3D) -> void:
	site.width=16.
	site.depth=14.
	site.portal("W",[1.12,5.32,0.,2.62,"pairslide"],0,"WestPayroll","WestDoor")
	# 將舊整跨牆板的顯示、基座、木芯歸同一可拆單元。
	var walls:=old.get_node("Walls")
	var physical:=old.get_node("Structure")
	proxy(site,"OfficeScreen","wall","wood",[old.get_node("Fittings/BackOfficeScreen"),physical.get_node("OfficeScreen")],"Staff")
	proxy(site,"PaymentDesk","furniture","wood",[old.get_node("Fittings/PaymentCounter"),physical.get_node("Counter")],"Staff")
	for prefix:String in ["N","E","WN","WS","SW","SE"]:
		var objects:Array=[]
		for view in walls.get_children():
			var label:=str(view.name)
			if label.begins_with(prefix) and label.substr(prefix.length(),1).is_valid_int(): objects.append(view)
		for suffix in ["Base","Wood"]: objects.append(physical.get_node_or_null(prefix+suffix))
		proxy(site,prefix+"Wall","wall","wood",objects,prefix)
	for n in walls.get_children():
		var label:=str(n.name)
		var p:=physical.get_node_or_null(label)
		if p and p is CollisionShape3D: proxy(site,label,"frame","wood",[n,p],label)
	# 南面三跨屋架，兩旁及北跨保留；拆中跨後自南口進入可見天空。
	retire(old.get_node("Roof"))
	for ix in 3:
		var x0:float=[-8.,-4.55,4.55][ix]
		var x1:float=[-4.55,4.55,8.][ix]
		for iz in 2:
			var z0:float=-7.05 if iz==0 else -2.64
			var z1:float=-2.64 if iz==0 else 7.09
			var bay:="SouthEntry" if ix==1 and iz==1 else "Roof"+str(ix)+str(iz)
			var tie=site.unit(bay+"Frame","frame","wood",bay)
			var x:float=(x0+x1)*.5
			var z:float=(z0+z1)*.5
			tie.cuboid(Vector3(x,4.91,z),Vector3(x1-x0,.24,.20),R.DARK)
			for i in 3:
				var sx:float=x0+(i+.5)*(x1-x0)/3
				tie.cuboid(Vector3(sx,5.57,z),Vector3(.17,.29,z1-z0),R.OAK)
				tie.cuboid(Vector3(sx,5.21,z),Vector3(.14,.59,.14),R.END)
			tie.finish()
			var cover=site.unit(bay+"Roof","roof","wood",bay,[str(tie.name)])
			cover.cuboid(Vector3(x,5.91,z),Vector3(x1-x0,.22,z1-z0),R.OAK)
			cover.cuboid(Vector3(x,6.045,z),Vector3(x1-x0,.055,z1-z0),R.GREEN,false)
			for i in ceili((x1-x0)/.5):
				cover.cuboid(Vector3(x0+.13+i*.5,5.795,z),Vector3(.025,.025,z1-z0),R.DARK,false)
			cover.finish()

static func weigh(site:Node3D,old:Node3D,farm:Node3D) -> void:
	site.width=12.
	site.depth=7.
	site.portal("W",[-1.30,2.87,0.,2.57,"slide",1],0,"WestLedger","WestDoor")
	var base:=old.get_node("Collision")
	var bays:=old.get_node_or_null("WallBays")
	for prefix:String in ["North","East","WestNorth","WestSouth","SouthEast","SouthWest"]:
		var objs:Array=[]
		if bays:
			for n in bays.get_children():
				if str(n.name).begins_with(prefix): objs.append(n)
		for n in base.get_children():
			if str(n.name).begins_with(prefix): objs.append(n)
		if not objs.is_empty(): proxy(site,prefix+"Wall","wall","wood",objs,prefix)
	retire(farm.get_node("FarmShell/種子秤棚屋頂"))
	farm.get_node("FarmStyleBuildings/WeighRoof").hide()
	for r:Array in [[-8.,6.50,-4.,3.50],[6.50,10.,-2.35,3.50]]:
		var x0:float=r[0]
		var x1:float=r[1]
		var z0:float=r[2]
		var z1:float=r[3]
		var bay:="OfficeCanopy" if x0<0 else "CartCanopy"
		var center:=Vector3((x0+x1)*.5,3.91,(z0+z1)*.5)
		var roof=site.unit(bay,"roof","wood",bay)
		roof.cuboid(center,Vector3(x1-x0,.21,z1-z0),R.OAK)
		roof.cuboid(center+Vector3.UP*.12,Vector3(x1-x0,.035,z1-z0),R.GREEN,false)
		for i in ceili((x1-x0)/.4):
			roof.cuboid(center+Vector3(-.5*(x1-x0)+.13+i*.4,-.107,0),Vector3(.023,.02,z1-z0),R.DARK,false)
		roof.finish()
	var annex:=TOWER.new()
	annex.name="SeedCleaningLoft"
	annex.position=Vector3(9.50,0,-5.85)
	annex.farm=farm
	site.add_child(annex)
	annex.build_tower()

static func bridge(farm:Node3D,group:Node3D) -> void:
	var old:=farm.get_node("FarmCanalWorks/CenterBridge")
	var site:=R.new()
	site.name="CenterBridge"
	group.add_child(site)
	site.global_transform=old.global_transform
	farm.get_node("FarmStyleBuildings/CenterBridge").hide()
	retire(old.get_node("Span"))
	# 原砌石座及護岸仍按兩岸原形著地；柱排獨立於板區。
	for key in ["Abutments","BankFacing","Bent"]:
		var mesh:=old.get_node("Supports/"+key)
		mesh.layers=1
		proxy(site,key,"bridge_frame" if key=="Bent" else "support","wood" if key=="Bent" else "stone",[mesh],key)
	for i in 7:
		var x:float=[-5.77,-4.,-2.,0.,2.,4.,5.77][i]
		for j in 2:
			var bay:="Stringer"+str(i)+("North" if j==0 else "South")
			site.box(bay,Vector3(x,-.243,-4.50 if j==0 else 4.50),Vector3(.25,.214,9.),R.DARK,"bridge_frame","wood",bay,["Bent"])
	# 以原 360 支鋪木的位置分板區；合批、碰撞及欄柱承座共用這份幾何。
	var stock: Node3D = preload("res://levels/farm_stock_groups/sites/CenterBridge.scn").instantiate()
	stock.name = "PendingStock"
	stock.hide()
	site.add_child(stock)
	_bridge_units(site,stock,old.get_node("Span/Surface").collision_layer)

static func _bridge_units(site:Node3D,stock:Node3D,deck_layer:int) -> void:
	var paths: PackedStringArray = stock.get_meta("targets").duplicate()
	var owner_by_path := {}
	var views := {}
	for index in paths.size():
		owner_by_path[paths[index]] = index
	for view in stock.get_node("Views").get_children():
		views[str(view.get_meta("target"))] = view
	var members := {}
	var boxes := {}
	var boards := {}
	var planks := {}
	for batch: MultiMeshInstance3D in stock.get_node("Batches").get_children():
		var owners: PackedInt32Array = batch.get_meta("owners").duplicate()
		var poses: PackedVector3Array = batch.get_meta("poses").duplicate()
		var mesh: Mesh = batch.get_meta("prototype")
		var original_count := owners.size()
		for i in original_count:
			var path: String = paths[owners[i]]
			var bay := path.get_file()
			if not bay.begins_with("Lane") and not bay.contains("Rail"):
				continue
			var k := i*4
			var pose := Transform3D(poses[k],poses[k+1],poses[k+2],poses[k+3])
			var box := pose*mesh.get_aabb()
			var center := box.get_center()
			var id := bay
			if bay.begins_with("Lane"):
				var lane := bay.substr(4,1).to_int()
				var span_index := bay.right(1).to_int()
				var edges := [-9.0,-4.5,-.32,4.5,9.0]
				var half := int(center.x > -4.0+lane*4.0)
				var row := clampi(floori(4.0*inverse_lerp(edges[span_index],edges[span_index+1],center.z)),0,3)
				if half != 0 or row != 0:
					id += "Half%dRow%d" % [half,row]
				boards[id] = lane*2+half
				var strips:Array = planks.get_or_add(id,[])
				strips.append(box)
			elif box.size.y > box.size.z:
				id = bay.replace("Rail","Post")
				if id.ends_with("3"):
					var last_id := id.trim_suffix("3")+"4"
					var last_path := path.get_base_dir()+"/"+last_id
					pose.origin.z += 3.9 # 最後一支欄木止於原設計的 z = 8 m。
					for axis in [pose.basis.x,pose.basis.y,pose.basis.z,pose.origin]: poses.append(axis)
					owners.append(_bridge_view(stock,paths,owner_by_path,views,last_path))
					boxes[last_id] = pose*mesh.get_aabb()
					members[last_path] = 1
			var new_path := path.get_base_dir()+"/"+id
			owners[i] = _bridge_view(stock,paths,owner_by_path,views,new_path)
			members[new_path] = members.get(new_path,0)+1
			boxes[id] = (boxes[id] as AABB).merge(box) if boxes.has(id) else box
		batch.set_meta("owners",owners)
		if poses.size() != original_count*4: batch.set_meta("poses",poses)
	stock.set_meta("targets",paths)
	for path:String in members: views[path].set_meta("members",members[path])
	for id:String in boxes:
		var box:AABB = boxes[id]
		var is_board := boards.has(id)
		var unit = site.unit(id,"bridge_deck" if is_board else "bridge_frame","wood",id)
		var center := box.get_center()
		var seats := []
		if is_board:
			# 每欄板段橫跨相鄰縱梁。跨中央接頭時，同一端可以落在南或北半梁。
			var col:int = boards[id]
			for line in [col,col+1]:
				var alternatives := []
				if box.position.z < 0: alternatives.append("Stringer%dNorth" % line)
				if box.end.z > 0: alternatives.append("Stringer%dSouth" % line)
				seats.append(alternatives)
			unit.collision_layer = deck_layer
			# 破口與整個板區相符；碎落只保留其中一塊短木的實體，毛屑交給現役粉塵。
			var chip:AABB = planks[id][planks[id].size() >> 1]
			var chip_size := chip.size*Vector3(.5,1,1)
			unit.set_meta("bridge_chip",AABB(chip.get_center()-chip_size*.5,chip_size))
		elif id.contains("Post"):
			# 只取實際位於柱腳下的外緣板，內側剝落不會牽走欄柱。
			var bearing := []
			for plate:String in boards:
				if boards[plate] != (0 if center.x<0 else 5): continue
				var board:AABB = boxes[plate]
				# 柱腳若落在兩區接縫，任一有實質木面重疊的外板都可承托。
				if minf(box.end.z,board.end.z)-maxf(box.position.z,board.position.z) >= box.size.z*.25:
					bearing.append(plate)
			if bearing.is_empty(): push_error("中橋欄柱腳下沒有橋板 "+id)
			seats = [bearing]
		else:
			var end := id.right(1).to_int()
			var post := id.left(-1).replace("Rail","Post")
			seats = [[post+str(end)],[post+str(end+1)]]
		unit.set_meta("support_seats",seats)
		unit.cuboid(center,box.size,R.OAK if is_board else R.DARK)
		unit.finish()

static func _bridge_view(stock:Node3D,paths:PackedStringArray,indices:Dictionary,views:Dictionary,path:String) -> int:
	if not indices.has(path):
		indices[path] = paths.size()
		paths.append(path)
		var view := MeshInstance3D.new()
		view.set_meta("target",NodePath(path))
		stock.get_node("Views").add_child(view)
		views[path] = view
	return indices[path]

static func boundaries(farm:Node3D,group:Node3D) -> void:
	var site:=R.new()
	site.name="Boundaries"
	group.add_child(site)
	# 原母圖已縮短或移位的牆，以實載外框為準；採地表專層逐節探地。
	var styles:=farm.get_node("FarmStyleBuildings")
	for row:Dictionary in preload("res://levels/farm_style_buildings/placement.json").data:
		var id:String=row.model
		if not id in ["Guard1","Guard2","YardWall1","YardWall2","YardWall3","WindWall"]: continue
		var art:=styles.get_node(id) as MeshInstance3D
		var source:=farm.get_node(row.targets[0])
		var shape_owner:Node=source.get_parent() if row.get("local_wall",false) else source
		var bounds:=art.get_aabb()
		var length:float=bounds.size.x
		var h:float=bounds.end.y
		var thick:=clampf(bounds.size.z,.32,1.0)
		if row.get("local_wall",false):
			var b:AABB=source.get_aabb()
			length=b.size.x
			h=b.size.y
			thick=b.size.z
		var anchor:Transform3D=art.global_transform
		retire(shape_owner)
		art.hide()
		var count:=maxi(3,roundi(length/1.05))
		var dx:=length/count
		for i in count:
			var offset:float=(i+.5)*dx-length*.5
			var pos:Vector3=anchor*Vector3(offset,0,0)
			var ground:Array=preload("res://levels/farm_buildings_v31/footings.json").data[id]
			var low:float=ground[i]
			var worn:=float(posmod(id.hash()+i*17,11))*.018
			if i==0 or i==count-1: worn+=float(posmod(id.hash()+i,5))*.095
			var t:float=(i+.5)/count
			match id:
				"Guard1": worn=.07+.14*t
				"Guard2": worn+=.15*maxf(0.,1.-t*4.)
				"WindWall": worn=.09+.23*absf(t-.54)
				"YardWall1": worn+=.53*maxf(0.,1.-absf(t-.77)*4.)
				"YardWall2": worn+=.37*maxf(0.,1.-t*2.6)
				"YardWall3": worn+=.39*t
			var top:=anchor.origin.y+h-worn
			var u:=site.unit(id+"Block"+str(i),"wall","stone" if id=="Guard1" else "brick",id+str(i))
			u.global_transform=Transform3D(anchor.basis.orthonormalized(),Vector3(pos.x,low-.14,pos.z))
			var wall_h:=maxf(.25,top-low+.14)
			u.cuboid(Vector3(0,wall_h*.5,0),Vector3(dx,wall_h,thick),R.ADOBE if id!="Guard1" else R.SHADE)
			u.cuboid(Vector3(0,wall_h-.06,0),Vector3(dx,.12,thick+.025),R.CLAY)
			for n in 2:
				u.cuboid(Vector3((n-.5)*dx*.42,wall_h*.36+(i%3)*.048,0),Vector3(dx*.37,.12,thick+.026),R.CLAY.lerp(R.ADOBE,.46),false)
			u.finish()

