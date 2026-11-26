extends RefCounted
## 舊版場內農務物和 Buildings 分件都在母圖安裝完成後登記。
const LUMBER := ["農舍北側柴垛","北站後場木料","南場農車備柴","南田筐料板垛","北集乳車路木料"]
const PROPS := {"bale":"soft","clutters_LogPile":"wood","kits_Crate":"wood","props_Wagon":"wood","rocks_Rock02":"stone","rocks_Rock04":"stone"}

static func populate(r, farm: Node3D) -> void:
	var dependency_list := {}
	var env := farm.get_node_or_null("FarmLocalEnvironment")
	for body: StaticBody3D in farm.find_children("*","StaticBody3D",true,false):
		if not body.has_meta("structure_material") or not body.has_meta("component"):
			continue
		var family := String(body.get_meta("structure_material"))
		var role := String(body.get_meta("component"))
		if role in ["frame","support","main_beam","bridge_deck","bridge_frame","bridge_pier"]:
			family = "frame" if role in ["frame","support","main_beam"] else ("bridge_frame" if role=="bridge_pier" else role)
		if family == "adobe":
			family = "brick"
		if not r.DURABILITY.has(family):
			continue
		var key := str(farm.get_path_to(body))
		var shapes := _own_shapes(body)
		r.register(key,family,[body],shapes,body)
		for relative: String in body.get_meta("depends_on",PackedStringArray()):
			var anchor := body.get_parent().get_node_or_null(NodePath(relative))
			if anchor:
				if not dependency_list.has(key): dependency_list[key] = []
				dependency_list[key].append(str(farm.get_path_to(anchor)))
	for child: String in dependency_list:
		for anchor: String in dependency_list[child]:
			if r.entries.has(anchor):
				r.depend(child,anchor)
	for pane: Node in farm.get_tree().get_nodes_in_group(&"farm_fixed_glazing"):
		if farm.is_ancestor_of(pane) and not r.entries.has(str(farm.get_path_to(pane))):
			r.register(str(farm.get_path_to(pane)),"glass",[pane],_own_shapes(pane),pane)
	# 房屋門扇和玻璃要能單獨拆，所在牆已毀時亦須一起退場。
	for key: String in r.entries.keys():
		var wall: Node = r.entries[key].native
		if not wall or not wall.has_method("set_present") or not "leaf" in wall:
			continue
		for attached in [wall.leaf,wall.glass]:
			if not attached:
				continue
			var id := str(farm.get_path_to(attached))
			if not r.entries.has(id):
				r.register(id,"wood",[attached],_all_shapes(attached))
			r.depend(id,key)

	var bales := {}
	for vis: MeshInstance3D in farm.find_children("*","MeshInstance3D",true,false):
		if not vis.mesh or not vis.is_visible_in_tree() or vis.layers == 0:
			continue
		var mesh_name := String(vis.mesh.resource_name)
		if not PROPS.has(mesh_name):
			continue
		if env and mesh_name.begins_with("rocks_"):
			continue
		var root: Node3D = vis.get_parent() if vis.get_parent() is StaticBody3D else vis
		var shapes := _all_shapes(root)
		if shapes.is_empty() or r.by_shape.has(shapes[0]):
			continue
		var key := _at(mesh_name,root.global_position)
		r.register(key,PROPS[mesh_name],[root],shapes)
		if mesh_name == "bale":
			bales[key] = root.global_position
	for upper: String in bales:
		for lower: String in bales:
			var diff: Vector3 = bales[upper]-bales[lower]
			if diff.y>0.9 and diff.y<1.4 and Vector2(diff.x,diff.z).length()<0.90:
				r.depend(upper,lower)
	var stacks := farm.get_node_or_null("LoadingStation/WorkingCrates")
	if stacks:
		r.working_crates.register(r, stacks)
	for label: String in LUMBER+["StoredGateBoards"]:
		var root := farm.get_node_or_null(NodePath(label))
		if root:
			r.register(label,"wood",[root],_all_shapes(root))
	var farm_stock := {"YardStack":"wood","ApproachStock":"wood","TeamStock":"wood","NorthStock":"wood","FarmCrates":"wood","StoredFeed":"soft"}
	for spec: Dictionary in preload("res://levels/farm_style_buildings/placement.json").data:
		var label := str(spec.model)
		if not farm_stock.has(label): continue
		var skin := farm.get_node_or_null("FarmStyleBuildings/"+label) as MeshInstance3D
		var solid := farm.get_node_or_null(NodePath(spec.targets[0]))
		if skin and skin.is_visible_in_tree() and solid:
			r.register("stock/"+label,farm_stock[label],[skin],_all_shapes(solid))
	_fittings(r,farm)
	_batches(r,farm)
	if env:
		r.finish_environment(env)

## 舊裝配的碰撞集中在同一座 StaticBody3D，下列對照保留逐件的可見面與碰撞。
static func _fittings(r,farm: Node3D) -> void:
	for spec in [
		["LoadingStation",["Timbers"],"Platform",["Deck","West","East"],"wood"],
		["PayOffice",["Fittings/ClerkDesk","Fittings/PayRoll"],"Structure",["Desk*","WritingLip"],"wood"],
		["PayOffice",["Fittings/ClerkSeat"],"Structure",["Stool"],"wood"],
		["PayOffice",["Fittings/Records"],"Structure",["Records"],"wood"],
		["PayOffice",["Fittings/PorchBench"],"Structure",["PorchBench*"],"wood"],
		["PayOffice",["Fittings/WaitingBench"],"Structure",["WaitingBench*"],"wood"],
		["PayOffice",["Fittings/PaymentCounter"],"Structure",["Counter","WindowPost*","Lattice"],"wood"],
		["PayOffice",["Fittings/BackOfficeScreen"],"Structure",["OfficeScreen"],"wood"],
		["PayOffice",["Fittings/TicketPigeonholes"],"Structure",["TicketCabinet"],"wood"],
		["RegistrationRoom",["ReceiptDesk","DeskWork"],"Collision",["ReceiptDeskPart*","WritingLip"],"wood"],
		["RegistrationRoom",["GoodsScale"],"Collision",["GoodsScalePart*"],"metal"],
		["RegistrationRoom",["TareCrate"],"Collision",["TareCrate"],"wood"],
		["RegistrationRoom",["FilledLot","Fruit"],"Collision",["FilledLot"],"wood"],
		["RegistrationRoom",["Archive"],"Collision",["RecordCase"],"wood"],
		["RegistrationRoom",["Seat"],"Collision",["Stool*"],"wood"],
		["RegistrationRoom",["Intake"],"Collision",["Intake*"],"wood"],
		["RegistrationRoom",["DeliveryJamb"],"Collision",["Jamb*"],"wood"],
		["House1Interior/House",["Floor"],".",["PackedFloor"],"earth"],
		["House1Interior/House",["Kitchen"],".",["KitchenCollision"],"wood"],
		["House1Interior/House",["Sleeping"],".",["SleepingCollision"],"wood"],
		["FarmCanalWorks/UnloadingRack",["WharfDeck"],"Surface",["Collision"],"frame"]
	]:
		var root := farm.get_node_or_null(NodePath(spec[0]))
		if not root: continue
		var body := root.get_node_or_null(NodePath(spec[2]))
		if not body: continue
		var shapes := []
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or r.by_shape.has(child): continue
			for pattern: String in spec[3]:
				if str(child.name).match(pattern):
					shapes.append(child)
					break
		var nodes := []
		for path: String in spec[1]:
			var node := root.get_node_or_null(NodePath(path))
			if node: nodes.append(node)
		if not nodes.is_empty() and not shapes.is_empty():
			if spec[1][0]=="Fittings/PaymentCounter" and r.entries.has("FarmBuildings31/PayOffice/PaymentDesk"):
				var unit: Dictionary = r.entries["FarmBuildings31/PayOffice/PaymentDesk"]
				for sh: CollisionShape3D in shapes:
					unit.native.shapes.append(sh)
					unit.shapes.append([sh,sh.disabled])
					r.by_shape[sh]=unit.key
				continue
			var key := str(farm.get_path_to(nodes[0]))
			if spec[1][0]=="DeliveryJamb":
				# 五塊木板已有原生逐板受擊。石檻與固定邊框才隸屬牆腳承座。
				var jamb:Node3D=nodes[0]
				var frame_art:=jamb.get_children().filter(func(n):return n is MeshInstance3D)
				var frame:Dictionary=r.register(key,spec[4],frame_art,shapes)
				frame.infill=jamb.get_node("Boards")
			else:
				r.register(key,spec[4],nodes,shapes)
	# 這兩個原模型在實例化時自己建 ToyBuild。加入現役追蹤才能補送晚加入與換局。
	for path in ["PayOffice/RollBoard/RollTimber","RegistrationRoom/DeliveryJamb/Boards"]:
		var timber:=farm.get_node(path) as ToyBuild
		if timber not in farm._toys: farm._toys.append(timber)
	for path: String in ["MilkStation/MilkReceiving/Bench","MilkStation/MilkReceiving/Landing"]:
		var rack := farm.get_node_or_null(NodePath(path))
		if not rack: continue
		r.register(path,"wood",[rack],_own_shapes(rack))
		for can in rack.get_children():
			if can is StaticBody3D:
				var key := str(farm.get_path_to(can))
				r.register(key,"metal",[can],_own_shapes(can))
				r.depend(key,path)
	for spec in [
		["NortheastWorkyard/HarvestWagon","wood"],
		["FarmCanalWorks/EastGate/GateMasonry","stone"],["FarmCanalWorks/EastGate/GateFrame","metal"],
		["FarmCanalWorks/EastGate/GateLeaf","wood"],["FarmCanalWorks/NorthWall","brick"],
		["FarmCanalWorks/WestWall","brick"],["FarmCanalWorks/ShortWall","brick"],
		["FarmCanalWorks/UnloadingRack/ChockedWagon","wood"],["FarmCanalWorks/UnloadingRack/Chocks","wood"],
		["FarmCanalWorks/UnloadingRack/Stock","wood"],["FarmCanalWorks/UnloadingRack/Trestles","wood"],
		["FarmCanalWorks/UnloadingRack/WharfPiles","frame"],
	]:
		var node := farm.get_node_or_null(NodePath(spec[0]))
		if not node: continue
		var shapes := []
		for sh: CollisionShape3D in _all_shapes(node):
			if not sh.disabled and not r.by_shape.has(sh): shapes.append(sh)
		if shapes.is_empty(): continue
		r.register(spec[0],spec[1],[node],shapes)
	for pair in [
		["FarmCanalWorks/EastGate/GateLeaf","FarmCanalWorks/EastGate/GateFrame"],
		["FarmCanalWorks/UnloadingRack/WharfDeck","FarmCanalWorks/UnloadingRack/WharfPiles"],
		["FarmCanalWorks/UnloadingRack/Stock","FarmCanalWorks/UnloadingRack/Trestles"]
	]:
		if r.entries.has(pair[0]) and r.entries.has(pair[1]): r.depend(pair[0],pair[1])


	# 秤房收貨筐底貼收貨臺面，交貨框下的石檻碰撞則隸屬西南牆。
	for pair: Array in [
		["RegistrationRoom/TareCrate","RegistrationRoom/Intake"],
		["RegistrationRoom/FilledLot","RegistrationRoom/Intake"],
		["RegistrationRoom/DeliveryJamb","FarmBuildings31/RegistrationRoom/SouthWestWall"]
	]:
		if r.entries.has(pair[0]) and r.entries.has(pair[1]):
			r.depend(pair[0],pair[1])
	# 發薪房角柱承在南、北向牆腳上，短側牆只碰到柱邊一公分。
	for pair: Array in [["Corner0_0","NWall"],["Corner16_0","NWall"],["Corner0_13","SWWall"],["Corner16_13","SEWall"]]:
		var corner := farm.get_node_or_null("FarmBuildings31/PayOffice/"+str(pair[0]))
		if corner and r.entries.has("FarmBuildings31/PayOffice/"+str(pair[1])):
			corner.set_meta("ground_anchor",false)
			corner.set_meta("support_seats",[[pair[1]]])

static func register_stones(r, farm: Node3D) -> void:
	for body: StaticBody3D in farm.get_children().filter(func(n): return n is StaticBody3D and n.has_meta("farm_field_stone")):
		if preload("res://levels/farm_yard_loads/install.gd").field_stone(body): continue
		r.register(_at("stone/"+str(body.get_meta("farm_field_stone")),body.global_position),"stone",[body],_own_shapes(body))

static func _own_shapes(root: Node) -> Array:
	var shapes := []
	for node in root.get_children():
		if node is CollisionShape3D:
			shapes.append(node)
	return shapes

static func _all_shapes(root: Node) -> Array:
	return root.find_children("*","CollisionShape3D",true,false)

static func _at(kind: String, p: Vector3) -> String:
	return "%s/%d,%d,%d" % [kind,roundi(p.x*100),roundi(p.y*100),roundi(p.z*100)]

static func _batches(r,farm: Node3D) -> void:
	var hay_regions := {}
	for body in farm.get_tree().get_nodes_in_group(&"soft"):
		if not farm.is_ancestor_of(body):
			continue
		for shape: CollisionShape3D in _own_shapes(body):
			if shape.shape is BoxShape3D:
				hay_regions[shape] = []
	var sensor := Area3D.new()
	sensor.name = "VegetationAndFence"
	sensor.collision_layer = r.SENSOR
	sensor.collision_mask = 0
	sensor.monitoring = false
	r.add_child(sensor)
	for batch: MultiMeshInstance3D in farm.find_children("*","MultiMeshInstance3D",true,false):
		if not batch.has_meta("farm_source_transforms"):
			continue
		var transforms: Array = batch.get_meta("farm_source_transforms")
		var kind := String(batch.multimesh.mesh.resource_name)
		if kind not in ["block","kits_HayBlock","kits_FenceRail","kits_FencePost"]:
			continue

		var mesh_box := batch.multimesh.mesh.get_aabb()
		for i in transforms.size():
			var xf: Transform3D = transforms[i]
			var world := batch.global_transform*xf
			if kind in ["block","kits_HayBlock"]:
				for shape: CollisionShape3D in hay_regions:
					var local := shape.to_local(world*mesh_box.get_center())
					var half: Vector3 = shape.shape.size*.5+Vector3.ONE*.04
					if absf(local.x)<=half.x and absf(local.y)<=half.y and absf(local.z)<=half.z:
						hay_regions[shape].append([batch,i,xf])
						break
				continue
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = mesh_box.size
			collision.shape = box
			sensor.add_child(collision)
			collision.global_transform = world*Transform3D(Basis(),mesh_box.get_center())
			var key := _at(kind,world.origin)
			var part: Dictionary = r.register(key,"wood",[],[collision])
			if part.is_empty():
				continue
			part.instances.append([batch,i,xf])
	for shape: CollisionShape3D in hay_regions:
		if not hay_regions[shape].is_empty():
			var part: Dictionary = r.register(_at("hay",shape.global_position),"soft",[],[shape])
			part.instances = hay_regions[shape]
