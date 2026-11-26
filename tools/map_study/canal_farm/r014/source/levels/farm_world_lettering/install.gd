extends RefCounted
## 灌渠農莊 A v3.1；建築分件已建好後呼叫。套件只改外觀與掛牌的顯隱。
const PAY = preload("B_Pay_Office.res")
const SCALE = preload("A_Scale_Left.res")
const MILK = preload("A_Milk_Receiving.res")
const CANAL = preload("A_East_Canal.res")
const FORMS = {"Field":preload("Field_Time_Roll.res"),"Ditch":preload("Ditch_Time_Roll.res"),"Orchard":preload("Orchard_Time_Roll.res")}
const PARTS := "FarmBuildings31/"
const REQUIRED := [PARTS+"PayOffice/SEWall", "PayOffice/Walls/SignBoard", "PayOffice/Walls/PaintedSign",
	PARTS+"RegistrationRoom/EastWall", "RegistrationRoom/EastReceivingSign/Paint",
	PARTS+"MilkStation/PostWS", PARTS+"MilkStation/PostES", PARTS+"EastGageHouse/S1B1End","MilkStation","PayOffice/RollBoard/Notices"]

static func ink(source:Image) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_texture=ImageTexture.create_from_image(source)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode=BaseMaterial3D.CULL_BACK
	m.roughness=.95
	m.metallic_specular=.17
	return m

static func timber(parent:Node3D, label:String, center:Vector3, size:Vector3)->MeshInstance3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color("#71563C")
	m.roughness=.96
	var mesh:=BoxMesh.new()
	mesh.size=size
	mesh.material=m
	var board:=MeshInstance3D.new()
	board.name=label
	board.mesh=mesh
	parent.add_child(board)
	board.position=center
	return board

static func face(board:Node3D, size:Vector2, z:float, source:Image)->void:
	var plane:=QuadMesh.new()
	plane.size=size
	var letters:=MeshInstance3D.new()
	letters.name="Ink"
	letters.mesh=plane
	letters.material_override=ink(source)
	board.add_child(letters)
	letters.position.z=z

static func bind_existing(proxy:Node3D, view:MeshInstance3D)->void:
	# 牆代理保留舊牆的節點與路徑，只替它登記牌面的顯隱。
	proxy.capture(view)
	view.visible=proxy.present

static func install(farm:Node3D)->bool:
	if farm.has_meta(&"farm_world_lettering_v31"): return true
	for path in REQUIRED:
		if not farm.has_node(NodePath(path)):
			push_error("農莊字牌缺少掛位 "+path)
			return false
	var paper:=farm.get_node("PayOffice/RollBoard/Notices")
	for crew in FORMS:
		for side in ["W","E"]:
			if not paper.has_node(NodePath(crew+side)):
				push_error("農莊工單缺少掛位 "+crew+side)
				return false
	var legacy:Label3D
	for candidate:Label3D in farm.get_node("MilkStation").find_children("*","Label3D",false,false):
		if candidate.text=="MILK RECEIVING": legacy=candidate
	if not legacy:
		push_error("集乳棚原字樣與套件不符，請核對掛位。")
		return false
	var milk:Node3D=farm.get_node(PARTS+"MilkStation")
	var west:Node3D=milk.get_node("PostWS")
	var east:Node3D=milk.get_node("PostES")
	var yard:=farm.get_node(PARTS+"EastGageHouse") as Node3D
	var host:=yard.get_node("S1B1End") as Node3D
	var pay:=farm.get_node("PayOffice/Walls/PaintedSign") as MeshInstance3D
	var scale:=farm.get_node("RegistrationRoom/EastReceivingSign/Paint") as MeshInstance3D
	pay.material_override=ink(PAY)
	scale.material_override=ink(SCALE)
	var pay_wall:=farm.get_node(PARTS+"PayOffice/SEWall")
	bind_existing(pay_wall,pay)
	bind_existing(pay_wall,farm.get_node("PayOffice/Walls/SignBoard"))
	# 木背與字面原是父子；只交付木背給代理，兩者一起顯隱。
	bind_existing(farm.get_node(PARTS+"RegistrationRoom/EastWall"),scale.get_parent())
	for crew in FORMS:
		var material:=ink(FORMS[crew])
		for side in ["W","E"]:
			paper.get_node(NodePath(crew+side)).material_override=material
	# 橫料釘在南側兩柱的外面，字在南面；任一承點拆去，橫料與牌一起退場。
	var rail:=timber(milk,"SignRail",Vector3(0,2.22,2.835),Vector3(4.67,.18,.09))
	var board:=timber(rail,"MilkSign",Vector3(0,0,.079),Vector3(3.09,.536,.08))
	face(board,Vector2(3,.487),.0415,MILK)
	var sync:=func(): rail.visible=west.visible and east.visible
	west.visibility_changed.connect(sync)
	east.visibility_changed.connect(sync)
	sync.call()
	legacy.hide()
	# 沿用舊牌兩行原文，改釘在新門洞右方完整牆板上。
	var nameplate:=timber(host,"CanalSign",Vector3.ZERO,Vector3(2.05,.54,.062))
	nameplate.global_transform=yard.global_transform*Transform3D(Basis(),Vector3(.92,2.37,3.123))
	face(nameplate,Vector2(2,.515),.0325,CANAL)
	farm.set_meta(&"farm_world_lettering_v31",true)
	return true
