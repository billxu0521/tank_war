extends RefCounted
## 中橋原模型的岸座、護坡和柱排。沿用既有耐久、材質與現役碎落處理。
const STOCK := preload("sections.scn")

static func retire(body: StaticBody3D) -> void:
	# 合批的視覺代理和已搬到原鍵的碰撞，都要退出地圖。
	for view: Node3D in body.visuals:
		view.hide()
	for shape: CollisionShape3D in body.shapes:
		shape.disabled = true
	body.hide()
	body.remove_from_group(&"farm_building_parts")
	body.remove_meta("structure_material")
	body.remove_meta("component")
	body.name = String(body.name) + "Retired"

static func seats(body: StaticBody3D, groups: Array) -> void:
	body.set_meta("support_seats", groups)
	body.set_meta("ground_anchor", groups.is_empty())

static func stone_top(art: MeshInstance3D) -> Vector2:
	# 上層台石按真接縫分段，忽略後方灰漿和下層錯縫石。
	var bounds := Vector2(INF, -INF)
	var top := art.get_aabb().end.y
	for i in art.mesh.get_surface_count():
		if art.mesh.surface_get_material(i).resource_name == "grout":
			continue
		var points: PackedVector3Array = art.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		for v in points:
			if v.y >= top - .025:
				bounds.x = minf(bounds.x, v.x)
				bounds.y = maxf(bounds.y, v.x)
	return bounds

static func install(farm: Node3D) -> void:
	var bridge := farm.get_node("FarmBuildings31/CenterBridge") as Node3D
	if bridge.has_node("Pile0"):
		return
	var originals := farm.get_node("FarmCanalWorks/CenterBridge/Supports")
	var sources := {}
	for id: String in ["Abutments", "BankFacing", "Bent"]:
		var old := bridge.get_node(id) as StaticBody3D
		var mesh := originals.get_node(id) as MeshInstance3D
		var materials := {}
		for i in mesh.mesh.get_surface_count():
			materials[mesh.mesh.surface_get_material(i).resource_name] = mesh.get_active_material(i)
		sources[id] = [materials, mesh.layers, old.collision_layer, old.collision_mask]
		retire(old)
	var stock: Node3D = STOCK.instantiate()
	var tops := {}
	for art: MeshInstance3D in stock.find_children("*", "MeshInstance3D", true, false):
		var id := String(art.name)
		var source_id := "Bent"
		if id.begins_with("Sill"):
			source_id = "Abutments"
			tops[id] = stone_top(art)
		elif id.begins_with("Facing"):
			source_id = "BankFacing"
		var source: Array = sources[source_id]
		var timber := source_id == "Bent"
		var body: StaticBody3D = bridge.unit(id, "bridge_frame" if timber else "support", "wood" if timber else "stone", id)
		body.position = art.get_aabb().get_center()
		body.collision_layer = source[2]
		body.collision_mask = source[3]
		art.owner = null
		art.reparent(body, false)
		art.name = "StockAssembly"
		art.position = -body.position
		art.layers = source[1]
		for i in art.mesh.get_surface_count():
			art.set_surface_override_material(i, source[0][art.mesh.surface_get_material(i).resource_name])
		var collision := CollisionShape3D.new()
		collision.shape = art.mesh.create_trimesh_shape()
		collision.position = -body.position
		body.add_child(collision)
		if id == "Bent":
			# 中央樁搭配任一側，或左右各有樁；同一端殘留兩根不托全跨。
			seats(body, [["Pile0", "Pile1", "Pile2"], ["Pile2", "Pile3", "Pile4"], ["Pile0", "Pile1", "Pile3", "Pile4"]])
		elif id.begins_with("Brace"):
			var index := id.trim_prefix("Brace").to_int()
			seats(body, [["Pile%d" % index], ["Pile%d" % (index + 1)]])
		else:
			seats(body, [])
	stock.free()
	for girder: StaticBody3D in bridge.find_children("Stringer*", "StaticBody3D", false, false):
		var side := "North" if String(girder.name).ends_with("North") else "South"
		var shape := girder.get_child(0) as CollisionShape3D
		var box := shape.shape as BoxShape3D
		var x := bridge.to_local(shape.global_position).x
		var local_sills := []
		for id: String in tops:
			if id.begins_with("Sill" + side):
				var edges: Vector2 = tops[id]
				if minf(x + box.size.x / 2., edges.y) > maxf(x - box.size.x / 2., edges.x):
					local_sills.append(id)
		assert(not local_sills.is_empty(), str(girder.name))
		seats(girder, [["Bent"], local_sills])

