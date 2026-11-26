extends Node3D
const UNIT:=preload("res://levels/farm_buildings_v31/unit.gd")
const LEAF:=preload("res://levels/farm_buildings_v31/leaf.gd")
const PANE:=preload("res://levels/farm_buildings_v31/pane.gd")
const OAK:=Color("#b58756")
const END:=Color("#d6ad7c")
const DARK:=Color("#785138")
const SHADE:=Color("#514439")
const CLAY:=Color("#bd956b")
const ADOBE:=Color("#a1724d")
const LIME:=Color("#d4ad83")
const GREEN:=Color("#48685a")
const IRON:=Color("#414744")
const LINEN:=Color("#819784")
var farm:Node3D
var width:float
var depth:float
var core:String
var purpose:String
var deck:=2.88
var level:=1

func identify(n:Node,id:String,role:String,mat:String,bay:String,parents:Array=[]) -> void:
	n.name=id
	n.set_meta("component",role)
	n.set_meta("structure_material",mat)
	n.set_meta("bay",bay)
	n.set_meta("storey",level)
	n.set_meta("depends_on",PackedStringArray(parents))
	n.add_to_group(&"farm_building_parts")

func unit(id:String,role:String,mat:String,bay:String,parents:Array=[]) -> StaticBody3D:
	var u:=UNIT.new()
	identify(u,id,role,mat,bay,parents)
	add_child(u)
	return u

func box(id:String,p:Vector3,size:Vector3,c:Color,role:String,mat:String,bay:String,dep:Array=[]) -> StaticBody3D:
	var u:=unit(id,role,mat,bay,dep)
	u.cuboid(p,size,c)
	u.finish()
	return u

func basis_side(side:String) -> Basis:
	return Basis(Vector3.UP,PI*.5 if side in ["E","W"] else 0.)

func at(side:String,u:float,h:float,offset:=0.) -> Vector3:
	match side:
		"N": return Vector3(u,h,-depth*.5+offset)
		"S": return Vector3(u,h,depth*.5+offset)
		"E": return Vector3(width*.5+offset,h,-u)
		_: return Vector3(-width*.5+offset,h,-u)

func length_of(side:String) -> float:
	return width if side in ["N","S"] else depth

func wall_piece(side:String,a:float,b:float,lo:float,hi:float,mat:String,id:String,bay:String) -> void:
	if b-a<.015 or hi-lo<.015: return
	var u:=unit(id,"wall",mat,bay)
	u.transform=Transform3D(basis_side(side),at(side,(a+b)*.5,(hi+lo)*.5))
	var thick:=.33 if mat=="brick" else .15
	var span:=b-a
	var tall:=hi-lo
	u.cuboid(Vector3.ZERO,Vector3(span,tall,thick),CLAY if mat=="brick" else DARK)
	if mat=="brick":
		# 灰泥下的局部砌層只集中在牆腳、端面及窗洞收邊。
		for sign_ in [-1.,1.]:
			var count:=mini(4,maxi(1,floori(span/.54)))
			for j in count:
				var x:float=-span*.5+.25+j*.51
				var bw:=minf(.46,span*.92)
				x=clampf(x,-span*.5+bw*.5,span*.5-bw*.5)
				u.cuboid(Vector3(x,-tall*.5+minf(.16,tall*.48),sign_*(thick*.5+.011)),Vector3(bw,minf(.18,tall*.5),.025),ADOBE.lerp(CLAY,(j%3)*.19),false)
		u.cuboid(Vector3(0,tall*.5-minf(.06,tall*.2),0),Vector3(span,minf(.12,tall*.4),thick+.015),LIME,false)
	else:
		var boards:=maxi(1,ceili(span/.33))
		for i in boards:
			u.cuboid(Vector3(-span*.5+(i+.5)*span/boards,0,0),Vector3(maxf(.012,span/boards-.012),tall,.17),OAK.lerp(DARK,((i+id.length())%4)*.065),false)
		for h:float in [-.34,.34]:
			u.cuboid(Vector3(0,tall*h,side_sign(side)*-.095),Vector3(span,minf(.105,tall*.18),.055),DARK,false)
	u.finish()

func side_sign(side:String) -> float:
	return -1. if side in ["W","N"] else 1.

func frame_post(side:String,u:float,lo:float,hi:float,bay:String) -> void:
	var stud:=unit(bay+"Post","frame","wood",bay)
	stud.transform=Transform3D(basis_side(side),at(side,u,(lo+hi)*.5))
	stud.cuboid(Vector3.ZERO,Vector3(.16,hi-lo,.23),DARK)
	stud.cuboid(Vector3(0,(hi-lo)*.5-.16,0),Vector3(.065,.065,.25),END,false)
	stud.finish()

func portal(side:String,spec:Array,base:float,prefix:String,bay:String) -> void:
	var u:float=spec[0]
	var w:float=spec[1]
	var lo:float=spec[2]
	var h:float=spec[3]-lo
	var mode:String=spec[4]
	var is_door:=mode in ["swing","slide","pairslide","pairhinge"]
	var jamb:=unit(prefix+"Jamb","frame","wood",bay)
	jamb.transform=Transform3D(basis_side(side),at(side,u,base+lo))
	for x:float in [-w*.5,w*.5]:
		jamb.cuboid(Vector3(x,h*.5,0),Vector3(.075,h,.25),DARK)
	jamb.cuboid(Vector3(0,h,0),Vector3(w+.16,.09,.26),END)
	if not is_door:
		jamb.cuboid(Vector3(0,0,0),Vector3(w+.16,.07,.29),END)
	if mode in ["light","high","service"]:
		jamb.cuboid(Vector3(0,h*.36,-side_sign(side)*.20),Vector3(w,.085,.07),DARK)
	jamb.finish()
	var dep:=[str(jamb.name)]
	if mode in ["pane","light"]:
		var pane:=PANE.new()
		identify(pane,prefix+"Pane","window","glass",bay,dep)
		pane.transform=Transform3D(basis_side(side),at(side,u-w*.5,base+lo))
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(w,h,.034)
		collider.shape=shape
		collider.position=Vector3(w*.5,h*.5,0)
		pane.add_child(collider)
		var glass:=MeshInstance3D.new()
		glass.mesh=BoxMesh.new()
		glass.mesh.size=shape.size
		var glaze:=StandardMaterial3D.new()
		glaze.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		glaze.albedo_color=Color(.57,.75,.78,.30)
		glass.material_override=glaze
		glass.position=collider.position
		pane.add_child(glass)
		var bars:=UNIT.new()
		bars.cuboid(Vector3(w*.5,h*.5,0),Vector3(.045,h,.052),DARK,false)
		bars.cuboid(Vector3(w*.5,h*.55,0),Vector3(w,.035,.052),DARK,false)
		bars.finish()
		pane.add_child(bars)
		add_child(pane)
		return
	if mode=="board":
		var board:=unit(prefix+"Fixed","window","wood",bay,dep)
		board.transform=jamb.transform
		board.cuboid(Vector3(0,h*.5,0),Vector3(w,h,.085),GREEN)
		for y:float in [.15,h-.15]:
			board.cuboid(Vector3(0,y,0),Vector3(w,.10,.13),DARK,false)
			for x:float in [-w*.35,w*.35]:
				board.cuboid(Vector3(x,y,0),Vector3(.029,.029,.134),IRON,false)
		board.finish()
		return
	if mode=="high":
		# 固定護木留在低窗扇下沿，開向室內時也不會穿過護木。
		var apron:=unit(prefix+"Apron","window","wood",bay,dep)
		apron.transform=jamb.transform
		apron.cuboid(Vector3(0,h*.21,0),Vector3(w,.42*h,.09),DARK)
		apron.finish()
		lo+=h*.43
		h*=.57
	var pair:=mode in ["pairhinge","pairslide"]
	for i in (2 if pair else 1):
		var leaf:=LEAF.new()
		var hand:float=-1. if i==1 else 1.
		var leaf_width:float=w*.5 if pair else w
		identify(leaf,prefix+("LeafR" if i==1 else "LeafL"),"door" if is_door else "window","wood",bay,dep)
		leaf.hand=hand
		leaf.width=leaf_width
		leaf.height=h
		leaf.shutter=not is_door
		leaf.prompt="開門" if is_door else "開窗"
		var sliding:=mode in ["slide","pairslide","service"]
		var direction:float=float(spec[5]) if spec.size()>5 else 1.
		leaf.travel=(-hand if pair else direction)*(leaf_width+.07) if sliding else 0.
		leaf.transform=Transform3D(basis_side(side),at(side,u-hand*(w*.5-.043),base+lo+.035,side_sign(side)*(.21 if sliding else 0.)))
		var shape:=CollisionShape3D.new()
		shape.name="Solid"
		shape.shape=BoxShape3D.new()
		shape.shape.size=Vector3(leaf_width-.095,h-.07,.075)
		shape.position=Vector3(hand*(leaf_width-.095)*.5,(h-.07)*.5,0)
		leaf.add_child(shape)
		var art:=UNIT.new()
		var n:=maxi(3,ceili(leaf_width/.27))
		for j in n:
			art.cuboid(Vector3(hand*(j+.5)*(leaf_width-.095)/n,(h-.07)*.5,0),Vector3((leaf_width-.095)/n-.007,h-.07,.075),GREEN.lerp(OAK,(j%3)*.10),false)
		for y:float in [.2,h-.21]:
			art.cuboid(Vector3(hand*leaf_width*.45,y,0),Vector3(leaf_width*.84,.085,.10),DARK,false)
		art.cuboid(Vector3(hand*(leaf_width-.17),h*.53,0),Vector3(.06,.13,.18),IRON,false)
		art.finish()
		leaf.add_child(art)
		add_child(leaf)
		farm._doors.append(leaf)

## 每道開口自有窗臺及過梁；兩道開口間仍分跨，拆填牆不會連帶拆主架。
func face(side:String,specs:Array,base:float,top:float,mat:String) -> void:
	var half:=length_of(side)*.5
	specs.sort_custom(func(a,b): return a[0]<b[0])
	var last:float=-half
	var prefix:=side+str(level)
	var i:=0
	for s:Array in specs:
		var a:float=s[0]-s[1]*.5
		var b:float=s[0]+s[1]*.5
		var bay:=prefix+"B"+str(i)
		wall_piece(side,last,a,base,top,mat,bay+"Pier",bay)
		wall_piece(side,a,b,base,base+s[2],mat,bay+"Sill",bay)
		wall_piece(side,a,b,base+s[3],top,mat,bay+"Head",bay)
		portal(side,s,base,prefix+"Opening"+str(i),bay)
		last=b
		i+=1
	var bay:=prefix+"B"+str(i)
	wall_piece(side,last,half,base,top,mat,bay+"End",bay)
	if side in ["N","S"]:
		for sign_:float in [-1.,1.]:
			frame_post(side,sign_*(half-.12),base,top,prefix+("Left" if sign_<0 else "Right"))

