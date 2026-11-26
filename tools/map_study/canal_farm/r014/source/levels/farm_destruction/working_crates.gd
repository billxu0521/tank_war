extends RefCounted
## 命中時按原筐目前的層位取樣。關卡沿用果筐原有的一疊一碰撞、槽位與連線同步。
var stacks := {}

func register(registry: Node3D, group: Node3D) -> void:
	for stack in group.get_children():
		var keys: Array[String] = []
		var contact := str(registry.arena.get_path_to(stack))
		for slot in stack.bins.size():
			var key := str(registry.arena.get_path_to(stack.bins[slot]))
			var part: Dictionary = registry.register(key, "wood", [], [])
			part.crate_stack = stack
			part.crate_slot = slot
			part.charge_contact = contact
			keys.append(key)
		stacks[stack] = keys

func slot_key(stack: StaticBody3D, at: Vector3) -> String:
	var slot: int = stack.slot_at(at)
	return stacks[stack][slot] if slot >= 0 else ""

func sphere_hits(stack: StaticBody3D, at: Vector3, radius: float, keys: Dictionary) -> void:
	var solid: CollisionShape3D = stack.get_node("Solid")
	var half: Vector3 = (solid.shape as BoxShape3D).size * .5
	half.y = stack.TIER_HEIGHT * .5
	var local := stack.to_local(at)
	for slot in stack.bins.size():
		if (stack.intact_mask & (1 << slot)) == 0:
			continue
		var center := Vector3(solid.position.x, stack.bins[slot].position.y + half.y, solid.position.z)
		var closest := stack.to_global(local.clamp(center-half, center+half))
		if closest.distance_squared_to(at) <= radius * radius:
			keys[stacks[stack][slot]] = true

func changed() -> bool:
	for stack in stacks:
		if stack.intact_mask != (1 << stack.bins.size()) - 1:
			return true
	return false

func restore() -> bool:
	var changed_any := false
	for stack in stacks:
		var full: int = (1 << stack.bins.size()) - 1
		if stack.intact_mask != full:
			stack.apply_mask(full)
			changed_any = true
	return changed_any
