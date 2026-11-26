extends Node3D
## 在 v2.9d farm 的 _ready 最後呼叫。所有新增節點都是繪圖節點。
const EXIT_GROUND_LAYER := preload("res://levels/ranch_surface/surface.gd").DECAL_LAYER
const LAND := preload("res://levels/farm_style_environment/fields.scn")
const SOIL := preload("res://levels/farm_style_environment/soil.res")
const EARTH := preload("res://levels/farm_style_environment/earth.gdshader")
const WATER := preload("res://levels/farm_style_environment/water.gdshader")
const TREE := preload("res://levels/farm_style_environment/tree.gdshader")
const GATE := preload("res://levels/canal_banks/profile.gd")
const OPEN := preload("res://levels/gate_water/open_water.json")
var forms:Dictionary
var soil:Array[ShaderMaterial]=[]
var tree_paint:=ShaderMaterial.new()
var styled_trees:=0

static func install(farm:Node3D) -> void:
	if farm.has_node(^"FarmStyleEnvironment"): return
	if not farm.has_node(^"WestBank/Water") or not farm.has_node(^"BeyondFarm/OutlyingLand"):
		push_error("02＋06 地景需在 v2.9d 場地建好後接入")
		return
	var skin:=new()
	skin.name=&"FarmStyleEnvironment"
	farm.add_child(skin)
	skin.bind(farm)

func bind(farm:Node3D) -> void:
	var art:=LAND.instantiate() as Node3D
	forms=art.get_meta(&"forms")
	add_child(art)
	tree_paint.shader=TREE
	var map:=ImageTexture.create_from_image(SOIL)
	for role in 4:
		var mat:=ShaderMaterial.new()
		mat.shader=EARTH
		mat.set_shader_parameter(&"role",role)
		mat.set_shader_parameter(&"soil_map",map)
		mat.set_shader_parameter(&"water_level",GATE.WATER_Y)
		soil.append(mat)
	var field:=farm.get_node(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	for i in field.mesh.get_surface_count():
		match field.mesh.surface_get_name(i):
			"田間地表與農路": field.set_surface_override_material(i,soil[0])
			"渠岸","渠道底面示色","西灘涉水面","土層": field.set_surface_override_material(i,soil[2])
	# 田面上另疊著道路、田路與岸坡。保留模型原圖層，讓撤離圈在這些戶外表面連續。
	for tile in art.find_children("Tile_*", "MeshInstance3D", false, false):
		tile.layers |= EXIT_GROUND_LAYER
	for path: NodePath in [^"MilkStation/MilkReceiving/MilkYardWear", ^"FarmCanalWorks/UnloadingRack/WharfDeck"]:
		var deck := farm.get_node_or_null(path) as MeshInstance3D
		if deck: deck.layers |= EXIT_GROUND_LAYER
	for label in ["西灘西端淤坡","西灘東端淤坡","東堤上游護腳土坡","卸料端北側回岸坡"]:
		var ramp:=farm.get_node(NodePath(label)) as MeshInstance3D
		ramp.material_override=soil[2]
		ramp.layers |= EXIT_GROUND_LAYER
	var outlying:=farm.get_node(^"BeyondFarm/OutlyingLand") as MeshInstance3D
	outlying.material_override=soil[3]
	outlying.layers |= EXIT_GROUND_LAYER
	var east:=farm.get_node_or_null(^"EastFieldMargin/Bank/Soil") as MeshInstance3D
	if east:
		east.material_override=soil[1]
		east.layers |= EXIT_GROUND_LAYER
	var water:=ShaderMaterial.new()
	water.shader=WATER
	var table:=Image.create_empty(512,1,false,Image.FORMAT_RGF)
	for i in 512:
		var limits:Array=OPEN.data[mini(i,OPEN.data.size()-1)]
		table.set_pixel(i,0,Color(limits[0],limits[1],0))
	water.set_shader_parameter(&"shore_limits",ImageTexture.create_from_image(table))
	farm.get_node(^"WestBank/Water").material_override=water
	farm.get_node(^"BeyondFarm/WestWaterExtension").material_override=water
	art.get_node(^"TailWater").material_override=water
	for item in farm.find_children("*","GeometryInstance3D",true,false):
		if not is_ancestor_of(item): style_geometry(item)
	for tree in farm.get_tree().get_nodes_in_group(&"tree"):
		if farm.is_ancestor_of(tree) and tree is ToyBuild: style_tree(tree)
	for piece in farm.get_tree().get_nodes_in_group(&"toy_piece"):
		if farm.is_ancestor_of(piece): style_piece(piece)
	farm.get_tree().node_added.connect(_added)

func _added(node:Node) -> void:
	if not get_parent().is_ancestor_of(node): return
	if node is ToyBuild and node.is_in_group(&"tree"): style_tree(node)
	elif node.has_meta(&"toy_home"): style_piece(node)
	elif node is MeshInstance3D or node is MultiMeshInstance3D: style_geometry(node)

func style_geometry(node:GeometryInstance3D) -> void:
	if node is MeshInstance3D:
		var mesh:=node.mesh as Mesh
		if not mesh: return
		var replacement:=prop_form(mesh.resource_name)
		if replacement!="":
			node.mesh=forms[replacement]
			node.material_override=null
		elif node.get_parent().is_in_group(&"ground") and node.get_parent()!=get_parent().get("floor_body") and mesh is ArrayMesh and mesh.resource_name=="" and node.get_parent() is StaticBody3D:
			node.material_override=soil[1]
	elif node is MultiMeshInstance3D:
		var mm:=node.multimesh as MultiMesh
		if not mm or not mm.mesh: return
		var replacement:=prop_form(mm.mesh.resource_name)
		if replacement=="" and node.name in [&"wheat",&"grass",&"stubble"]: replacement=str(node.name)
		if replacement!="":
			mm.mesh=forms[replacement]
			node.material_override=null
			if mm.use_colors:
				for i in mm.instance_count: mm.set_instance_color(i,Color.WHITE)

func prop_form(label:String) -> String:
	match label:
		"props_Bush": return "bush"
		"props_HayBale": return "bale"
		"kits_HayBlock": return "block"
	return ""

func style_tree(toy:ToyBuild) -> void:
	if toy.has_meta(&"farm_style_tree") or toy.brick_count()==0: return
	var view:=toy.get_child(0) as MultiMeshInstance3D
	if not view: return
	var trunk_count:=0
	for i in toy.brick_count():
		if toy._mt[i]==&"tree": trunk_count+=1
	if toy.brick_count()-trunk_count!=3: return
	toy.set_meta(&"farm_style_tree",trunk_count)
	var all:=PackedInt32Array(range(toy.brick_count()))
	toy._mm=tree_mesh(toy,all,toy._xf,true)
	view.multimesh=toy._mm
	view.material_override=tree_paint
	styled_trees+=1

func style_piece(piece:Node) -> void:
	var toy:=piece.get_meta(&"toy_home") as ToyBuild
	if not is_instance_valid(toy) or not toy.has_meta(&"farm_style_tree"): return
	var key:int=piece.get_meta(&"toy_key")
	if not toy._info.has(key): return
	var info:Dictionary=toy._info[key]
	var view:=piece.find_children("*","MultiMeshInstance3D",false,false)
	if view.is_empty(): return
	var mm:=info.get("mm") as MultiMesh
	if not mm or mm.mesh!=toy.get_meta(&"farm_tree_form", forms.tree):
		mm=tree_mesh(toy,info.m,info.rel,false)
		info.mm=mm
	view[0].multimesh=mm
	view[0].material_override=tree_paint

func tree_mesh(toy:ToyBuild,members:PackedInt32Array,relative:Array,standing:bool) -> MultiMesh:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true
	mm.mesh=toy.get_meta(&"farm_tree_form", forms.tree)
	mm.instance_count=members.size()
	var whole:=AABB()
	var trunks:int=toy.get_meta(&"farm_style_tree")
	var variation:=fposmod(toy.position.dot(Vector3(.273,.19,.647)),1.0)
	for k in members.size():
		var i:=members[k]
		var index:=2+i-trunks if i>=trunks else int(i==trunks-1)
		var rel:Transform3D=relative[k]
		var xf:=Transform3D(rel.basis.scaled(toy._size[i]),rel.origin)
		var bounds:=xf * mm.mesh.get_aabb()
		whole=bounds if k==0 else whole.merge(bounds)
		if standing and not toy.is_standing(i): xf=Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO)
		mm.set_instance_transform(k,xf)
		mm.set_instance_custom_data(k,Color(index/8.0,variation,0,1))
	mm.custom_aabb=whole.grow(.03)
	return mm
