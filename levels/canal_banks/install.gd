extends RefCounted
## 在 v2.6 場地的 _ready() 結尾呼叫 install(self)。同一場地可重複呼叫或卸下。
const PROFILE := preload("res://levels/canal_banks/profile.gd")
const TERRAIN := preload("res://levels/gate_water/terrain.res")
const MUD := preload("res://levels/canal_banks/mud.res")
const WATER := preload("res://levels/gate_water/water.res")
const WEST := preload("res://levels/west_deep_water/install.gd")
const GRASS := preload("res://levels/farm_environment/shore_grass.json")
const KEY := &"canal_banks_v1_original"

static func section_at(x: float) -> Dictionary:
	return PROFILE.section_at(x)

static func with_materials(baked: ArrayMesh, original: MeshInstance3D) -> ArrayMesh:
	var result := baked.duplicate() as ArrayMesh
	for i in result.get_surface_count():
		result.surface_set_material(i,original.get_active_material(i))
	return result

static func install(farm: Node3D) -> bool:
	if farm.has_meta(KEY):
		return true
	var field := farm.get_node_or_null(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	var bank := farm.get_node_or_null(^"WestBank")
	if not field or not bank:
		return false
	var water := bank.find_child("Water",true,false) as MeshInstance3D
	var mud := bank.find_child("BankMud",true,false) as MeshInstance3D
	var grass := bank.get_node_or_null(^"grass") as MultiMeshInstance3D
	var floor_body := farm.get("floor_body") as StaticBody3D
	if not water or not mud or not grass or not floor_body or not field.is_ancestor_of(floor_body):
		return false
	var shapes := floor_body.find_children("*","CollisionShape3D",true,false)
	if shapes.size()!=1 or TERRAIN.get_surface_count()!=field.mesh.get_surface_count() or grass.multimesh.instance_count!=GRASS.data.size():
		return false
	for i in TERRAIN.get_surface_count():
		var material := field.get_active_material(i)
		if not material or material.resource_name!=TERRAIN.surface_get_name(i):
			return false
	var next_terrain := with_materials(TERRAIN,field)
	var next_shape := next_terrain.create_trimesh_shape()
	if not next_shape:
		return false
	var split_west := water.has_node(NodePath(WEST.PIECE))
	if split_west:
		WEST.uninstall(water)
	var old := {"terrain":field.mesh,"shape":shapes[0].shape,"water":water.mesh,
		"mud":mud.mesh,"grass":grass.multimesh,"split":split_west}
	water.mesh=with_materials(WATER,water)
	if split_west and not WEST.install(water):
		water.mesh=old.water
		WEST.install(water)
		return false
	field.mesh=next_terrain
	shapes[0].shape=next_shape
	mud.mesh=with_materials(MUD,mud)
	# 無視窗模式可能讀不到 MultiMesh 原變換；依母圖同一份種植點重設。
	var plants := MultiMesh.new()
	plants.transform_format=MultiMesh.TRANSFORM_3D
	plants.mesh=grass.multimesh.mesh
	plants.use_colors=true
	plants.instance_count=GRASS.data.size()
	var bounds:=AABB()
	var transforms: Array[Transform3D]=[]
	for i in GRASS.data.size():
		var g: Array=GRASS.data[i]
		var z:=PROFILE.map_z(g[0],g[2],section_at(g[0]))
		var xf:=Transform3D(Basis(Vector3.UP,g[4]).scaled(Vector3.ONE*float(g[3])),Vector3(g[0],g[1],z))
		plants.set_instance_transform(i,xf)
		plants.set_instance_color(i,Color("77804c").lerp(Color("a19b63"),fmod(i*.618,1.0)))
		transforms.append(xf)
		var box: AABB=xf*plants.mesh.get_aabb()
		bounds=box if i==0 else bounds.merge(box)
	plants.custom_aabb=bounds.grow(1)
	if grass.multimesh.has_meta(&"capture_xf"):
		plants.set_meta(&"capture_xf",transforms)
	grass.multimesh=plants
	farm.set_meta(KEY,old)
	return true

static func uninstall(farm: Node3D) -> void:
	if not farm.has_meta(KEY):
		return
	var old: Dictionary=farm.get_meta(KEY)
	var bank:=farm.get_node(^"WestBank")
	var water:=bank.find_child("Water",true,false) as MeshInstance3D
	WEST.uninstall(water)
	water.mesh=old.water
	if old.split:
		WEST.install(water)
	farm.get_node(^"FarmShell/場地剖切與渠床").mesh=old.terrain
	farm.get("floor_body").find_children("*","CollisionShape3D",true,false)[0].shape=old.shape
	bank.find_child("BankMud",true,false).mesh=old.mud
	bank.get_node(^"grass").multimesh=old.grass
	farm.remove_meta(KEY)
