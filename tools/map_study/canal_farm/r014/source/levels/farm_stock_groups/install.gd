extends RefCounted
## 依場所共繪固定建材。各自的牆、柱、橋板仍掌握碰撞、血量與可見狀態。
const KIT := "res://levels/farm_stock_assemblies/"
const OUT := "res://levels/farm_stock_groups/"
const ORIG := preload("res://levels/farm_stock_assemblies/install.gd")
const PROXY := preload("res://levels/farm_buildings_v31/existing.gd")

class Batch:
	extends RefCounted
	var output: MultiMesh
	var origins := PackedVector3Array()
	var slot_by_id := PackedInt32Array()
	var id_by_slot := PackedInt32Array()
	var by_owner := {}
	var active := 0

	func read_pose(id: int) -> Transform3D:
		var i := id * 4
		return Transform3D(origins[i], origins[i + 1], origins[i + 2], origins[i + 3])

	func start(node: MultiMeshInstance3D, frames: Array[Transform3D], views: Array[Node3D]) -> void:
		var owners: PackedInt32Array = node.get_meta("owners")
		var authored: PackedVector3Array = node.get_meta("poses")
		var prototype: Mesh = node.get_meta("prototype")
		var count := owners.size()
		output = MultiMesh.new()
		output.transform_format = MultiMesh.TRANSFORM_3D
		output.mesh = prototype
		output.instance_count = count
		origins.resize(count * 4)
		slot_by_id.resize(count)
		id_by_slot.resize(count)
		var bounds := AABB()
		for id in count:
			var i := id * 4
			var relative := Transform3D(authored[i], authored[i + 1], authored[i + 2], authored[i + 3])
			var frame := frames[owners[id]] * relative
			origins[i] = frame.basis.x
			origins[i + 1] = frame.basis.y
			origins[i + 2] = frame.basis.z
			origins[i + 3] = frame.origin
			var box := frame * prototype.get_aabb()
			bounds = box if id == 0 else bounds.merge(box)
			slot_by_id[id] = id
			id_by_slot[id] = id
			output.set_instance_transform(id, frame)
			if not by_owner.has(owners[id]):
				by_owner[owners[id]] = PackedInt32Array()
			by_owner[owners[id]].append(id)
		active = count
		output.custom_aabb = bounds
		output.visible_instance_count = active
		node.multimesh = output
		for field: StringName in [&"owners", &"poses", &"prototype"]:
			node.remove_meta(field)
		for owner_id: int in by_owner:
			var view := views[owner_id]
			view.visibility_changed.connect(sync.bind(owner_id, view))
			var groups: Array = view.get_meta("stock_groups", [])
			groups.append([self, owner_id])
			view.set_meta("stock_groups", groups)
			sync(owner_id, view)

	func sync(owner_id: int, view: Node3D) -> void:
		var visible_now := view.is_visible_in_tree()
		for id: int in by_owner[owner_id]:
			var slot := slot_by_id[id]
			if visible_now == (slot >= 0):
				continue
			if visible_now:
				id_by_slot[active] = id
				slot_by_id[id] = active
				output.set_instance_transform(active, read_pose(id))
				active += 1
			else:
				active -= 1
				var moved := id_by_slot[active]
				if slot != active:
					output.set_instance_transform(slot, read_pose(moved))
					id_by_slot[slot] = moved
					slot_by_id[moved] = slot
				slot_by_id[id] = -1
		output.visible_instance_count = active

	func visible_members(owner_id: int) -> int:
		var count := 0
		for id: int in by_owner[owner_id]:
			if slot_by_id[id] >= 0:
				count += 1
		return count

static func install(farm: Node3D) -> void:
	if farm.has_meta("farm_stock_count"):
		return
	var holder := Node3D.new()
	holder.name = "StockBatches"
	farm.add_child(holder)
	var count := 0
	var manifest: Dictionary = load(KIT + "rooms.json").data
	for site_name: String in manifest:
		if manifest[site_name]["新組裝分件"] == 0:
			continue
		var site: Node3D
		if site_name == "CenterBridge":
			site = farm.get_node("FarmBuildings31/CenterBridge/PendingStock")
			site.get_parent().remove_child(site)
			site.name = site_name
			site.show()
		else:
			var packed: PackedScene = load(OUT + "sites/" + site_name + ".scn")
			site = packed.instantiate()
		holder.add_child(site)
		var views_root := site.get_node("Views")
		for view: MeshInstance3D in views_root.get_children():
			var target := farm.get_node_or_null(view.get_meta("target")) as Node3D
			if not target:
				push_error("建材遺失掛載點 " + str(view.get_meta("target")))
				continue
			target.set_meta("stock_source", KIT + "rooms/" + site_name + ".tscn")
			target.set_meta("stock_count", view.get_meta("members"))
			count += 1
			if target is MeshInstance3D:
				target.mesh = view.mesh
				target.material_override = null
				continue
			if target is PROXY:
				for old: Node3D in target.visuals:
					old.hide()
				target.visuals.clear()
				target.visuals.append(view)
			else:
				ORIG.hide_art(target)
			views_root.remove_child(view)
			view.name = "StockAssembly"
			target.add_child(view)
		views_root.free()
		var paths: PackedStringArray = site.get_meta("targets")
		var frames: Array[Transform3D] = []
		var views: Array[Node3D] = []
		var inverse := site.global_transform.affine_inverse()
		for path: String in paths:
			var target := farm.get_node(path) as Node3D
			views.append(target.get_node("StockAssembly"))
			frames.append(inverse * target.global_transform)
		for node: MultiMeshInstance3D in site.get_node("Batches").get_children():
			var state := Batch.new()
			state.start(node, frames, views)
		site.remove_meta("targets")
	farm.set_meta("farm_stock_count", count)
