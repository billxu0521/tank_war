extends "res://levels/farm_buildings_v31/workshop.gd"

func fit(id:String,x:float,z:float,y:float,size:Vector3,kind:String) -> void:
	var u:=unit(id,"furniture","brick" if kind=="hearth" else "wood","Interior"+str(level))
	u.position=Vector3(x,y,z)
	var a:=size.x
	var b:=size.z
	var h:=size.y
	match kind:
		"table","rack","bed","screen","bench":
			var shelf:=.2 if kind=="bed" else h-.09
			u.cuboid(Vector3(0,shelf+.045,0),Vector3(a,.09,b),OAK)
			for i:float in [-1.,1.]:
				for j:float in [-1.,1.]:
					u.cuboid(Vector3(i*(a*.5-.07),shelf*.5,j*(b*.5-.07)),Vector3(.1,shelf,.1),DARK)
			if kind=="bed":
				u.cuboid(Vector3(0,.40,0),Vector3(a-.06,.25,b-.04),LINEN)
				u.cuboid(Vector3(0,.55,-b*.31),Vector3(a*.76,.095,b*.2),Color("#d7c6a3"),false)
			if kind=="rack":
				for fraction:float in [.32,.63]:
					u.cuboid(Vector3(0,h*fraction,0),Vector3(a,.085,b),OAK)
				for i in 3:
					u.cuboid(Vector3((i-1)*a*.25,h*.74,0),Vector3(a*.17,h*.18,b*.63),END,false)
			if kind=="screen":
				for i in 7:
					u.cuboid(Vector3((i-3)*a/8,h+.07,0),Vector3(.04,.1,b*.92),IRON,false)
		"hearth":
			u.cuboid(Vector3(0,h*.45,0),Vector3(a,h*.9,b),ADOBE)
			u.cuboid(Vector3(0,h*.55,b*.51),Vector3(a*.56,h*.47,.05),SHADE,false)
			u.cuboid(Vector3(-a*.24,h+.65,-b*.22),Vector3(.37,1.4,.38),CLAY)
		"hopper":
			u.cuboid(Vector3(0,h*.73,0),Vector3(a,h*.52,b),OAK)
			u.cuboid(Vector3(0,h*.31,0),Vector3(a*.52,h*.32,b*.66),DARK)
			for sign_:float in [-1.,1.]:
				u.cuboid(Vector3(sign_*a*.4,h*.26,0),Vector3(.16,h*.52,b*.80),DARK)
		"chest":
			u.cuboid(Vector3(0,h*.5,0),size,OAK)
			u.cuboid(Vector3(0,h-.07,0),Vector3(a+.025,.11,b+.025),DARK,false)
			u.cuboid(Vector3(0,h*.64,b*.5),Vector3(.1,.15,.05),IRON,false)
	u.finish()

func roof(h:float) -> void:
	# 木梁由柱列承托，板底與屋面同一跨拆卸。低坡薄鐵皮保留折邊與檐口。
	for sign_:float in [-1.,1.]:
		var gable_end:=unit("GableWest" if sign_<0 else "GableEast","wall","wood","GableW" if sign_<0 else "GableE")
		var x:=sign_*(width/2.-.05)
		gable_end.cuboid(Vector3(x,h+.045,0),Vector3(.16,.105,depth),DARK)
		gable_end.gable(Vector3(x,h+.09,0),.14,depth,minf(.7,depth*.066),OAK)
		gable_end.finish()
	var count:=maxi(2,ceili(width/4.))
	for i in count:
		var a:=width/count
		var x:float=-width*.5+(i+.5)*a
		var bay:="RoofBay"+str(i)
		var beam:=unit(bay+"Tie","frame","wood",bay)
		beam.cuboid(Vector3(x,h-.11,0),Vector3(.19,.23,depth+.12),DARK)
		beam.finish()
		var cover:=unit(bay+"Cover","roof","wood",bay,[str(beam.name)])
		for side:float in [-1.,1.]:
			var rise:=minf(.7,depth*.066)
			var reach:=depth*.5+.16
			var angle:=side*atan2(rise,reach)
			var slope:=sqrt(reach*reach+rise*rise)
			var center:=Vector3(x,h+.12+rise*.5,side*reach*.5)
			var tilt:=Vector3(angle,0,0)
			cover.cuboid(center,Vector3(a,.14,slope),OAK,true,tilt)
			cover.cuboid(center+Vector3.UP*.087,Vector3(a,.044,slope+.08),GREEN,false,tilt)
			for n in maxi(1,ceili(a/.46)):
				var off:float=-a*.5+(n+.5)*a/ceilf(a/.46)
				cover.cuboid(center+Vector3(off,-.069,0),Vector3(.025,.024,slope),DARK,false,tilt)
		cover.finish()

func ground_floor(material:String) -> void:
	var count:=maxi(1,ceili(width/4.))
	for i in count:
		var w:=width/count
		var x:float=(i+.5)*w-width*.5
		var slab:=unit("GroundBay"+str(i),"floor","earth" if material=="brick" else "wood","Ground"+str(i))
		slab.cuboid(Vector3(x,-.043,0),Vector3(w-.006,.12,depth-.08),ADOBE if material=="brick" else DARK)
		if material=="wood":
			var n:=ceili(depth/.35)
			for j in n:
				slab.cuboid(Vector3(x,.016,(j+.5)*depth/n-depth*.5),Vector3(w-.01,.015,depth/n-.015),OAK.lerp(DARK,(j%4)*.08),false)
		slab.finish()

func single(w:float,d:float,h:float,material:String,faces:Dictionary,fits:Array) -> void:
	width=w
	depth=d
	core=material
	ground_floor(material)
	for side in ["N","S","E","W"]:
		face(side,faces.get(side,[]),0,h,material)
	roof(h)
	for f:Array in fits: fit(f[0],f[1],f[2],0,Vector3(f[3],f[4],f[5]),f[6])

func study_upper(wash:bool,worker:bool) -> void:
	var old:=preload("res://levels/farm_stair_studies/layout.gd").new()
	old.name="Timberwork"
	add_child(old)
	old.build(wash)
	for n:StaticBody3D in old.get_children():
		var id:=str(n.name)
		var role:=str(n.get_meta("component"))
		if n.has_meta("wall_id") or id in ["Roof","GroundFloor"] or role=="furniture":
			n.free()
			continue
		if not wash and n.position.x>5.70 and n.position.z>1.4 and id.begins_with("BentPost"):
			n.position.z=.72
		if worker and id in ["HomeDeck","NorthDeck","LandingExit","EastEdge"]:
			var delta:=.5
			n.position.x+=-.25 if id=="HomeDeck" else .25
			for child in n.get_children():
				if child is MeshInstance3D: child.mesh.size.x+=delta
				if child is CollisionShape3D: child.shape.size.x+=delta
		var mat:=str(n.get_meta("structure_material"))
		var category:=role
		if role in ["stringer","rail"]: category="frame"
		if role=="tread": category="floor"
		var bay:=str(n.get_meta("bay","Landing" if role in ["tread","stringer","rail"] else "Home"))
		var dependence:Array=[]
		if bay=="center" and role!="frame":
			for peer in old.get_children():
				if peer.get_meta("component","")=="frame" and peer.get_meta("bay","")=="center":
					dependence.append(str(peer.name))
		identify(n,id,category,mat,bay,dependence)
		n.set_meta("storey",2 if n.position.y>2.64 else 1)
	# 一面填牆不是樓板支點。每塊樓板尋找本跨已實作的梁，先失去全部支點才會垮。
	for plate:StaticBody3D in old.get_children():
		if plate.get_meta("component","")!="floor" or plate.get_meta("depends_on").size()>0: continue
		if not str(plate.name) in ["HomeDeck","NorthDeck","LandingExit","EastEdge","WestLoft","EastLoft","EastDeck","UpperLanding","MidLanding"]: continue
		var nearest:=INF
		var anchors:=PackedStringArray()
		for member:StaticBody3D in old.get_children():
			if member.get_meta("member","")!="beam" and not str(member.name).begins_with("LandingSupport"): continue
			var dist:=Vector2(plate.position.x,plate.position.z).distance_to(Vector2(member.position.x,member.position.z))
			if dist<nearest-.05:
				nearest=dist
				anchors=PackedStringArray([str(member.name)])
			elif absf(nearest-dist)<.05: anchors.append(str(member.name))
		plate.set_meta("depends_on",anchors)
	for beam:StaticBody3D in old.get_children():
		if beam.get_meta("member","")!="beam": continue
		var anchors:=PackedStringArray()
		var order:Array=[]
		for post:StaticBody3D in old.get_children():
			if post.get_meta("member","")=="post": order.append([beam.position.distance_squared_to(post.position),str(post.name)])
		order.sort()
		for i in mini(2,order.size()): anchors.append(order[i][1])
		beam.set_meta("depends_on",anchors)
	# 保留樣本的真正踏級與留洞樓板，牆、門窗按本圖的位置和使用方式建造。
	width=13. if worker else 12.
	depth=9. if wash else 8.
	ground_floor("brick" if wash else "wood")
	var sides:Dictionary
	if worker:
		sides={"W":[[-1.98,1.4,0,2.25,"swing"],[1.45,1.2,1.,2.14,"shutter"]],"N":[[0,1.44,.86,2.54,"pane"]],"S":[[-3.2,1.0,1.12,2.17,"light"]],"E":[[2.,1.,1.12,2.15,"board"]]}
	elif wash:
		sides={"S":[[-3.9,1.17,1.11,2.14,"light"],[-1.18,1.28,0,2.25,"swing"]],"N":[[-3.47,1.52,1.08,2.24,"board"],[.69,1.27,1.14,2.24,"shutter"]],"E":[[.66,.89,1.31,2.20,"high"]],"W":[[-.25,.86,1.3,2.20,"high"]]}
	else:
		sides={"E":[[-1.76,1.40,0,2.25,"swing"],[1.92,1.12,1,2.12,"shutter"]],"N":[[0,1.44,.86,2.54,"pane"]],"S":[[0,1.22,.98,2.13,"light"]],"W":[[0,1.18,.98,2.13,"board"]]}
	for side in ["N","S","E","W"]:
		face(side,sides.get(side,[]),0,deck,"brick" if wash else "wood")
	level=2
	if worker: sides={"E":[[.65,1.2,1.15,2.14,"high"]],"N":[[-3.,1.,1.16,2.12,"light"]]}
	elif wash: sides={"S":[[-2.5,1.2,1.10,2.08,"high"]],"W":[[1.2,.9,1.25,2.04,"light"]]}
	else: sides={"W":[[0,1.1,1.1,2.1,"high"]],"N":[[-2.8,.95,1.24,2.10,"light"]]}
	for side in ["N","S","E","W"]: face(side,sides.get(side,[]),deck,5.58,"wood")
	roof(5.58)
	fit("FamilyBed" if wash and not worker else "WestBunk",-4.65,-2.62,deck,Vector3(1.3,.6,2.02),"bed")
	if not wash or worker: fit("SecondBunk",4.15,-2.70,deck,Vector3(1.03,.60,1.94),"bed")
	fit("LinenChest",-4.9 if wash else -.74,1.15 if wash else -3.55,deck,Vector3(1.13,.62,.62),"chest")
	level=1
	if wash:
		fit("Hearth",-4.86,-3.77,0,Vector3(1.35,.92,.85),"hearth")
		fit("PrepBench",-3.7,3.72,0,Vector3(1.72,.83,.64),"table")
		if not worker: fit("YardWashTable",-3.77,4.91,0,Vector3(1.68,.83,.67),"table")
		else: fit("BootBench",-5.87,-1.94,0,Vector3(.45,.46,1.25),"bench")
	else:
		fit("SortingTable",-2.18,-3.26,0,Vector3(2.1,.83,.76),"table")
		fit("PackingChests",4.88,-3.15,0,Vector3(1.55,.91,.90),"chest")

