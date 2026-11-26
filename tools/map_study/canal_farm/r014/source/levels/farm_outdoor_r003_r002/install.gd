extends RefCounted
## 插在農莊建物分件建立後、建材合批與破壞登錄前。草叢由母圖逐處選用。
const SOUTH_FIELD := &"south_field"
const EAST_FIELD := &"east_field"
const SHRUBS := {SOUTH_FIELD: Vector2(28,54), EAST_FIELD: Vector2(45.5,18)}

static func install(farm: Node3D, selected: Array = [], repair_shed := false) -> bool:
	if farm.has_meta(&"r003_outdoor_installed"):
		return true
	var gate := farm.get_node_or_null(^"FarmBuildings31/GateStore") as Node3D
	var stock := farm.get_node_or_null(^"FarmStyleBuildings/ApproachStock") as MeshInstance3D
	var solid := farm.get_node_or_null(^"FarmShell/南橋頭車材垛") as Node3D
	var tree: ToyBuild
	for plant: Node3D in farm.get_tree().get_nodes_in_group(&"tree"):
		if farm.is_ancestor_of(plant) and Vector2(plant.position.x, plant.position.z).distance_to(Vector2(17,71)) < .03:
			tree = plant as ToyBuild
			break
	if not gate or not stock or not solid or not tree or farm.has_node(^"StockBatches") or farm.has_node(^"FarmDestruction"):
		push_error("請在 r003 建物分件完成後、合批及破壞登錄前套用戶外修訂。")
		return false
	for id in selected:
		if not SHRUBS.has(id):
			push_error("未知的農莊草叢點位 " + str(id))
			return false
	var frame := Transform3D(Basis(Vector3.UP,deg_to_rad(4.0)),Vector3(17.95,0,20.60)) * gate.global_transform.affine_inverse()
	for node: Node3D in [gate, farm.get_node(^"FarmStyleBuildings/GateStore"), farm.get_node(^"FarmShell/橋東閘板棚")]:
		node.global_transform = frame * node.global_transform
	# 外觀與原凸體共用同一次剛體變換。保持木料沿伙房東牆長向堆放。
	var old := stock.global_transform
	var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(81)), Vector3(2.8,old.origin.y,34))
	solid.global_transform = pose * old.affine_inverse() * solid.global_transform
	stock.global_transform = pose
	tree.position = Vector3(18.5,tree.position.y,74.3)
	farm.set_meta(&"field_stone_locations", {"秤房東側田界/0": Vector2(40.35,14.3)})
	preload("ground_details.gd").clear_room_edges(farm)
	if repair_shed: preload("ground_details.gd").clear_repair_shed(farm)
	var transforms: Array[Transform3D] = []
	for id in SHRUBS:
		if id not in selected:
			continue
		var xz: Vector2 = SHRUBS[id]
		var point := Vector3(xz.x,0,xz.y)
		farm._reserve({"kind": &"bush", "pos": point})
		transforms.append(Transform3D(Basis(Vector3.UP,point.x*.26),point + Vector3.DOWN*.15))
	if not transforms.is_empty():
		var batch: MultiMeshInstance3D = farm._scatter(&"Bush", transforms, true)
		batch.name = &"FarmRouteBushes"
		batch.material_override = Greybox.bush_material()
	farm.set_meta(&"r003_outdoor_installed", true)
	return true
