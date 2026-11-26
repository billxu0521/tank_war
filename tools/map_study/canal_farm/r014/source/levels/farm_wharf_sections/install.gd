extends RefCounted
## 從原模型抽出的實際木料、砌體，沿用整圖的受擊、失承與復原。
const STOCK := preload("sections.glb")
const UNIT := preload("res://levels/farm_buildings_v31/unit.gd")
const BATCH := preload("res://levels/farm_yard_sections/batch.gd")
const BOARD_COUNT := 30
const BOARD_PITCH := 7.0 / BOARD_COUNT

static func deck_index(z: float) -> int:
	return clampi(floori((z + 3.5) / BOARD_PITCH), 0, BOARD_COUNT - 1)

static func deck_path(index: int) -> String:
	return "WharfSections/Deck%02d" % index

static func two_of_three(a: String, b: String, c: String) -> Array:
	# 三道實際支承中，至少兩道不同支承存活。
	return [[a, b], [b, c], [a, c]]

static func seats_for(id: String) -> Array:
	if id.begins_with("Deck"):
		return two_of_three("Stringer0", "Stringer1", "Stringer2")
	if id.begins_with("Stringer"):
		return two_of_three("Cap0", "Cap1", "Cap2")
	if id.begins_with("Cap"):
		var prefix := "Pile" + id.trim_prefix("Cap")
		return [[prefix + "West"], [prefix + "East"]]
	if id == "BraceNorth":
		return [["Pile0West"], ["Pile0East"]]
	return []

static func assign_seats(body: StaticBody3D, family: String, role: String, seats: Array) -> void:
	body.set_meta("structure_material", family)
	body.set_meta("component", role)
	body.set_meta("support_seats", seats)
	body.set_meta("ground_anchor", seats.is_empty())

static func container_at(site: Node3D, id: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = id
	site.add_child(holder)
	return holder

static func replace_surface(source: MeshInstance3D) -> void:
	source.hide()
	for old: CollisionShape3D in source.find_children("*", "CollisionShape3D", true, false):
		old.disabled = true

static func wrap_existing(site: Node3D, id: String, family: String, seats: Array) -> void:
	var stock := site.get_node(id) as MeshInstance3D
	var shapes := stock.find_children("*", "CollisionShape3D", true, false)
	var unit := UNIT.new()
	stock.name = id + "Art"
	unit.name = id
	assign_seats(unit, family, "fitting", seats)
	unit.collision_layer = shapes[0].get_parent().collision_layer
	unit.collision_mask = shapes[0].get_parent().collision_mask
	site.add_child(unit)
	for shape: CollisionShape3D in shapes:
		shape.reparent(unit, true)
	stock.reparent(unit, true)

static func bind_chocks(rack: Node3D) -> void:
	for body: StaticBody3D in rack.find_children("WheelStop*", "StaticBody3D", false, false):
		var collision: CollisionShape3D = body.find_children("*", "CollisionShape3D", false, false)[0]
		var hull := collision.shape as ConvexPolygonShape3D
		var local := (rack.global_transform.affine_inverse() * collision.global_transform) * hull.points
		var floor_y := INF
		for p in local:
			floor_y = minf(p.y, floor_y)
		var near_z := INF
		var far_z := -INF
		for p in local:
			if absf(p.y - floor_y) < .002:
				near_z = minf(near_z, p.z)
				far_z = maxf(far_z, p.z)
		# 楔底中央半段確實壓住的板可獨立承重；忽略側緣相擦。
		var quarter := (far_z - near_z) * .25
		var options := []
		for i in range(deck_index(near_z + quarter), deck_index(far_z - quarter) + 1):
			options.append(deck_path(i))
		assign_seats(body, "wood", "furniture", [options])

static func material_map(original: MeshInstance3D) -> Dictionary:
	var result := {}
	for i in original.mesh.get_surface_count():
		var raw := original.mesh.surface_get_material(i)
		result[raw.resource_name] = original.get_active_material(i)
	return result

static func batch_deck(kit: Node3D, deck_layers: int) -> void:
	BATCH.collect(kit, kit.find_children("Deck*", "StaticBody3D", false, false), true)
	for group: MultiMeshInstance3D in kit.get_node("StockBatches").get_children():
		group.layers = deck_layers

static func install(farm: Node3D) -> void:
	var rack := farm.get_node("FarmCanalWorks/UnloadingRack") as Node3D
	if rack.has_node("WharfSections"):
		return
	var gate := farm.get_node("FarmCanalWorks/EastGate") as Node3D
	var kit := container_at(rack, "WharfSections")
	var wings := container_at(gate, "MasonrySections")
	var old_deck := rack.get_node("WharfDeck") as MeshInstance3D
	var old_surface := rack.get_node("Surface") as StaticBody3D
	var old_piles := rack.get_node("WharfPiles") as MeshInstance3D
	var old_wall := gate.get_node("GateMasonry") as MeshInstance3D
	var sources := [old_deck, old_piles, old_wall]
	var paints := [material_map(old_deck), material_map(old_piles), material_map(old_wall)]
	var solids := [old_surface, old_piles.get_child(0), old_wall.get_child(0)]
	var original_board: BoxShape3D = old_surface.get_node("Collision").shape
	var stock: Node3D = STOCK.instantiate()
	for art: MeshInstance3D in stock.find_children("*", "MeshInstance3D", true, false):
		var id := String(art.name)
		var is_board := id.begins_with("Deck")
		var is_wing := id.begins_with("Wing")
		var group := 0 if is_board else (2 if is_wing else 1)
		var source: MeshInstance3D = sources[group]
		var solid: StaticBody3D = solids[group]
		var unit := UNIT.new()
		unit.name = id
		unit.position = art.get_aabb().get_center()
		unit.collision_layer = solid.collision_layer
		unit.collision_mask = solid.collision_mask
		assign_seats(unit, "stone" if is_wing else "frame", "floor" if is_board else "member", seats_for(id))
		(wings if is_wing else kit).add_child(unit)
		art.reparent(unit, false)
		art.name = "StockAssembly"
		art.position = -unit.position
		art.layers = source.layers
		for i in art.mesh.get_surface_count():
			var raw := art.mesh.surface_get_material(i)
			art.set_surface_override_material(i, paints[group][raw.resource_name])
		var collision := CollisionShape3D.new()
		if is_board:
			var box := BoxShape3D.new()
			box.size = Vector3(original_board.size.x, original_board.size.y, BOARD_PITCH)
			collision.shape = box
		else:
			collision.shape = art.mesh.create_trimesh_shape()
			collision.position = -unit.position
		unit.add_child(collision)
	stock.free()
	old_surface.get_node("Collision").disabled = true
	for old: MeshInstance3D in sources:
		replace_surface(old)
	wrap_existing(gate, "GateFrame", "wood", [["MasonrySections/WingNorth"], ["MasonrySections/WingSouth"]])
	# 前後輪最低點實座於局部 Z -1.82 和 +0.78，兩道車軸分別要有承托。
	wrap_existing(rack, "ChockedWagon", "wood", [[deck_path(deck_index(-1.82))], [deck_path(deck_index(.78))]])
	bind_chocks(rack)
	if farm.is_node_ready():
		batch_deck(kit, old_deck.layers)
	else:
		farm.ready.connect(batch_deck.bind(kit, old_deck.layers), CONNECT_ONE_SHOT)
