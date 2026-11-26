extends Node3D
## 農舍 4、5 的局部尺寸樣本，單位 m。每個盒形的可見面與碰撞使用同一尺寸。
const WOOD := Color("#976d4f")
const BRICK := Color("#b89572")
const TIMBER := Color("#644c3c")
const BOARDS := Color("#c59c6b")
const BED := Color("#758c86")
const GLASS := Color(.64,.81,.85,.28)
const DECK := 2.88
var wash: bool
var depth: float
var materials := {}

func part(id: String, p: Vector3, size: Vector3, color: Color, role: StringName, core: StringName) -> StaticBody3D:
	var body := preload("res://levels/farm_house1_r002/wall.gd").new()
	body.name = id
	body.position = p
	body.set_meta("component",role)
	body.set_meta("structure_material",core)
	body.set_meta("storey",2 if p.y>=DECK else 1)
	if id.length()>2 and id.left(1) in ["N","S","E","W"] and id.substr(1,1) in ["1","2"]:
		body.set_meta("wall_id",id.left(2))
		body.set_meta("storey",int(id.substr(1,1)))
	add_child(body,true)
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if color.a < 1.: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materials[color] = mat
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = materials[color]
	body.add_child(view)
	var box := BoxShape3D.new()
	box.size = size
	var collider := CollisionShape3D.new()
	collider.shape = box
	body.add_child(collider)
	return body

func deck(id: String, x0: float, x1: float, z0: float, z1: float) -> void:
	part(id,Vector3((x0+x1)*.5,DECK-.10,(z0+z1)*.5),Vector3(x1-x0,.20,z1-z0),BOARDS,&"floor",&"wood")

func wall_span(side: String, id: String, a: float, b: float, low: float, high: float, core: StringName, c: Color, role := &"wall") -> void:
	if b-a<.001 or high-low<.001: return
	var long_wall := side in ["N","S"]
	var normal := -1. if side in ["N","W"] else 1.
	var u := (a+b)*.5
	var h := (high+low)*.5
	var p := Vector3(u,h,normal*(depth/2-.09)) if long_wall else Vector3(normal*5.91,h,u)
	var size := Vector3(b-a,high-low,.18) if long_wall else Vector3(.18,high-low,b-a)
	part(id,p,size,c,role,core)

func facade(side: String, storey: int, openings: Array) -> void:
	var half := 6. if side in ["N","S"] else depth*.5
	var floor_y := 0. if storey==1 else DECK
	var top := DECK if storey==1 else 5.55
	var core := &"brick" if wash and storey==1 else &"wood"
	var tone := BRICK if core==&"brick" else WOOD
	var start := -half
	var prefix := side+str(storey)
	var i := 0
	for spec: Array in openings:
		var a := float(spec[0])-float(spec[1])/2.
		var b := a+float(spec[1])
		var low := floor_y+float(spec[2])
		var high := floor_y+float(spec[3])
		wall_span(side,prefix+"Pier"+str(i),start,a,floor_y,top,core,tone)
		wall_span(side,prefix+"Sill"+str(i),a,b,floor_y,low,core,tone)
		wall_span(side,prefix+"Head"+str(i),a,b,high,top,core,tone)
		if spec[4]!="door":
			var fixed: bool = spec[4]=="board"
			wall_span(side,prefix+"Pane"+str(i),a,b,low,high,&"wood" if fixed else &"glass",TIMBER if fixed else GLASS,&"window")
			wall_span(side,prefix+"Rail"+str(i),a,b,low+.26,low+.32,&"wood",BOARDS,&"rail")
		start = b
		i += 1
	wall_span(side,prefix+"End",start,half,floor_y,top,core,tone)

func set_wall_present(wall_id: String, present: bool) -> void:
	for panel in get_children():
		if panel.get_meta("wall_id","") == wall_id:
			panel.set_present(present)

func timber_between(id: String, a: Vector3, b: Vector3, width: float, height: float, role: StringName) -> void:
	var delta := b-a
	var along := delta.normalized()
	var side := along.cross(Vector3.UP).normalized()
	var timber := part(id,(a+b)*.5,Vector3(width,height,delta.length()),TIMBER,role,&"wood")
	timber.basis = Basis(side,side.cross(along),-along)

func stair(id: String, start: Vector2, direction: Vector2, count: int, initial: float, width: float) -> void:
	var side := Vector2(-direction.y,direction.x)
	for sign_: float in [-1.,1.]:
		var foot := start+side*sign_*(width*.5-.08)
		var head := foot+direction*count*.30
		var a := Vector3(foot.x,initial-.08,foot.y)
		var b := Vector3(head.x,initial+count*.18-.08,head.y)
		timber_between(id+("LeftStringer" if sign_<0 else "RightStringer"),a,b,.11,.21,&"stringer")
		if sign_ == (-1. if wash else 1.):
			var shift := Vector3(side.x,0,side.y)*sign_*.12
			var inset := Vector3(direction.x,.60,direction.y)*.22
			a += shift+inset
			b += shift-inset
			var lift := Vector3.UP*.96
			timber_between(id+"Handrail",a+lift,b+lift,.07,.08,&"rail")
			for n in [0.,.5,1.]:
				var post := a.lerp(b,float(n))
				part(id+"RailPost"+str(int(n*2)),post+lift*.5,Vector3(.07,.96,.07),TIMBER,&"rail",&"wood")
	for i in count:
		var c := start + direction * (.30*(i+.5))
		var h := initial + (i+1)*.18
		var size := Vector3(.30,.18,width) if absf(direction.x)>.5 else Vector3(width,.18,.30)
		part(id+str(i+1),Vector3(c.x,h-.09,c.y),size,BOARDS,&"tread",&"wood")

func furnishing(id: String, x: float, z: float, base: float, size: Vector3, color: Color) -> void:
	var role := &"partition" if id=="LandingScreen" else &"furniture"
	var material := &"brick" if id=="Cookstove" else &"wood"
	part(id,Vector3(x,base+size.y*.5,z),size,color,role,material)

func rail(id: String,x: float,z: float,span: Vector2,base: float) -> void:
	var size := Vector3(maxf(.08,absf(span.x)),.12,maxf(.08,absf(span.y)))
	for i in 3:
		var t := (float(i)-1)*.5
		var p := Vector3(x+span.x*t,base+.49,z+span.y*t)
		part(id+"Post"+str(i),p,Vector3(.085,.98,.085),TIMBER,&"rail",&"wood")
	part(id+"Top",Vector3(x,base+.99,z),size,TIMBER,&"rail",&"wood")

## 只由已判定的分區失效或測試呼叫，與普通接觸、開窗各自獨立。
func set_frame_bay_present(id: String, value: bool) -> void:
	for member in get_children():
		if member.get_meta("bay","")==id:
			member.set_present(value)

func build(is_wash: bool) -> void:
	wash = is_wash
	depth = 9. if wash else 8.
	part("GroundFloor",Vector3(0,-.08,0),Vector3(12,.16,depth),TIMBER,&"floor",&"earth")
	part("Roof",Vector3(0,5.65,0),Vector3(12,.20,depth),WOOD,&"roof",&"wood")
	if wash:
		facade("S",1,[[-3.9,1.17,1.11,2.14,"pane"],[-1.18,1.28,0,2.25,"door"]])
		facade("N",1,[[-3.47,1.52,1.08,2.24,"board"],[.69,1.27,1.14,2.24,"pane"]])
		facade("E",1,[[-.66,.89,1.31,2.20,"board"]])
		facade("W",1,[[.25,.86,1.30,2.20,"board"]])
		facade("S",2,[[-2.5,1.2,1.10,2.08,"pane"]])
		facade("W",2,[[-1.2,.9,1.25,2.04,"pane"]])
		facade("N",2,[])
		facade("E",2,[])
		deck("HomeDeck",-6,1.15,-4.5,4.5)
		deck("NorthDeck",1.15,6,-4.5,-1.17)
		deck("LandingExit",1.15,6,2.70,4.5)
		deck("EastEdge",4.65,6,-1.17,2.70)
		stair("LowerFlight",Vector2(2.02,2.7),Vector2.UP,8,0,1.48)
		part("MidLanding",Vector3(2.90,1.35,-.43),Vector3(3.50,.18,1.46),BOARDS,&"floor",&"wood")
		stair("UpperFlight",Vector2(3.78,.3),Vector2.DOWN,8,1.44,1.48)
		for x: float in [1.27,4.52]:
			part("LandingSupport"+str(int(x)),Vector3(x,.63,-.98),Vector3(.15,1.26,.15),TIMBER,&"support",&"wood")
		rail("InnerGuard",1.13,.76,Vector2(0,3.86),DECK)
		rail("NorthernGuard",2.90,-1.18,Vector2(3.5,0),DECK)
		rail("OuterGuard",4.67,.76,Vector2(0,3.86),DECK)
		rail("EntryGuard",2.04,2.70,Vector2(1.75,0),DECK)
		furnishing("Cookstove",-4.9,-3.4,0,Vector3(1.6,.98,.92),BRICK)
		furnishing("BowlTable",-4.10,3.10,0,Vector3(1.9,.85,.72),BOARDS)
		for x: float in [-5.65,.75]:
			for z: float in [-4.04,1.32]:
				var post := part("RoomPost",Vector3(x,1.23,z),Vector3(.20,2.46,.20),TIMBER,&"frame",&"wood")
				post.set_meta("member","post")
			var beam := part("RoomBeam",Vector3(x,2.56,-1.37),Vector3(.21,.24,5.60),TIMBER,&"frame",&"wood")
			beam.set_meta("member","beam")
		furnishing("FamilyBed",-4.60,-2.45,DECK,Vector3(1.55,.65,2.04),BED)
		furnishing("LinenChest",-4.9,1.92,DECK,Vector3(1.25,.72,.64),TIMBER)
		furnishing("LandingScreen",-.10,.64,DECK,Vector3(.16,1.85,1.35),WOOD)
	else:
		facade("E",1,[[-1.92,1.12,1.0,2.12,"board"],[1.76,1.40,0,2.25,"door"]])
		facade("N",1,[[0.,1.22,.98,2.13,"pane"]])
		facade("S",1,[[0.,1.22,.98,2.13,"pane"]])
		facade("W",1,[[0.,1.18,.98,2.13,"board"]])
		facade("W",2,[[0.,1.10,1.1,2.1,"pane"]])
		facade("N",2,[[-2.8,.95,1.24,2.10,"pane"]])
		facade("S",2,[])
		facade("E",2,[])
		deck("WestLoft",-6,-2,-4,1.85)
		deck("SortingLoft",-2,2,-4,1.85)
		deck("EastLoft",2,6,-4,1.85)
		for x: float in [-5.75,-2.13,2.13,5.75]:
			for z: float in [-3.74,1.52]:
				var support := part("BentPost",Vector3(x,1.24,z),Vector3(.22,2.48,.22),TIMBER,&"frame",&"wood")
				support.set_meta("member","post")
			var tie := part("BentTie",Vector3(x,2.57,-1.11),Vector3(.22,.22,5.48),TIMBER,&"frame",&"wood")
			tie.set_meta("member","beam")
		for z: float in [-3.55,-1.05,1.49]:
			for x: float in [-4.,0.,4.]:
				var girder := part("LoftBeam",Vector3(x,2.56,z),Vector3(4,.24,.16),TIMBER,&"frame",&"wood")
				girder.set_meta("member","beam")
				girder.set_meta("bay","center" if x==0 else "outer")
		get_node("SortingLoft").set_meta("bay","center")
		deck("UpperLanding",-6,-2.50,1.85,4)
		deck("EastDeck",2.30,6,1.85,4)
		stair("LongFlight",Vector2(2.3,2.67),Vector2.LEFT,16,0,1.58)
		rail("LongGuard",-.10,1.84,Vector2(4.80,0),DECK)
		rail("BaseGuard",2.32,2.92,Vector2(0,2.12),DECK)
		furnishing("SortingTable",-1.9,-2.85,0,Vector3(2.1,.85,.86),BOARDS)
		furnishing("EmptyCrates",4.65,-2.75,0,Vector3(1.55,.96,1.0),WOOD)
		furnishing("WestBunk",-4.7,-2.45,DECK,Vector3(1.15,.6,2.05),BED)
		furnishing("EastBunk",3.65,-2.45,DECK,Vector3(1.15,.6,2.05),BED)
		furnishing("Locker",-1.60,-.55,DECK,Vector3(.55,1.67,1.4),TIMBER)
		get_node("Locker").set_meta("bay","center")
		for node in get_children():
			if String(node.name).begins_with("LongGuard"):
				node.set_meta("bay","center")
