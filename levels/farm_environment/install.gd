extends RefCounted
## 母圖固定建圖時呼叫一次。田與水岸亦可分開掛上。
const FIELDS := preload("res://levels/farm_environment/fields.gd")
const PLAN := preload("res://levels/farm_environment/plan.json")
const SHORE := preload("res://levels/farm_environment/west_bank.glb")
const WATER_SHADER := preload("res://levels/farm_environment/canal_water.gdshader")

static func install_fields(farm: ArenaMap, plan: Dictionary = PLAN.data) -> Node3D:
	var existing := farm.get_node_or_null(^"CropFields") as Node3D
	if existing:
		return existing
	var all := Node3D.new()
	all.name = "CropFields"
	farm.add_child(all)
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://grass.gdshader")
	var mesh_for := {"wheat": ArenaMap.wheat_card(),"stubble": FIELDS.cut_stalks(),
		"grass": farm._grass_mesh(), "bush": ArenaMap.meshes()[&"Bush"]}
	var registered: Array[Vector3] = []
	for i in plan.fields.size():
		var spec: Dictionary = plan.fields[i]
		if spec.use == "orchard":
			continue
		var rows := FIELDS.layout(spec,plan,7241+i)
		var field := Node3D.new()
		field.name = "Field%d" % (i+1)
		all.add_child(field)
		for kind: String in rows:
			var mat: Material
			if kind == "grass":
				mat = grass
			elif kind == "bush":
				mat = Greybox.bush_material()
			FIELDS.draw(field,kind,rows[kind],mesh_for[kind],mat)
		for xf: Transform3D in rows.bush:
			var world := farm.to_global(xf.origin)
			var pos := Vector3(world.x,0,world.z)
			if not farm._bushes.has(pos):
				farm._reserve({kind=&"bush",pos=pos})
				registered.append(pos)
	all.tree_exiting.connect(func() -> void:
		for p: Vector3 in registered:
			farm._bushes.erase(p)
	,CONNECT_ONE_SHOT)
	return all

static func install_shore(farm: ArenaMap, shoal_marks := true) -> Node3D:
	var bank := farm.get_node_or_null(^"WestBank") as Node3D
	if not bank:
		bank = SHORE.instantiate()
		bank.name = "WestBank"
		farm.add_child(bank)
		var water := bank.find_child("Water",true,false) as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		water.material_override = mat
		var edge_grass := []
		for g: Array in preload("res://levels/farm_environment/shore_grass.json").data:
			edge_grass.append(Transform3D(Basis(Vector3.UP,g[4]).scaled(Vector3.ONE*float(g[3])),Vector3(g[0],g[1],g[2])))
		var grass := ShaderMaterial.new()
		grass.shader = preload("res://grass.gdshader")
		FIELDS.draw(bank,"grass",edge_grass,farm._grass_mesh(),grass)
		for piece: MeshInstance3D in bank.find_children("*","MeshInstance3D",true,false):
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := bank.find_child("Water",true,false) as MeshInstance3D
	(surface.material_override as ShaderMaterial).set_shader_parameter(&"shoal_marks",shoal_marks)
	return bank

static func install(farm: ArenaMap) -> void:
	install_fields(farm)
	install_shore(farm)

