extends Party

var last_pad := {}

func _start_round() -> void:
	last_pad.clear()
	super()

func _pad_gap(at: Vector3) -> float:
	var gap := INF
	for c: Node3D in _cowboys():
		gap = minf(gap, _flat(c.global_position, 0).distance_to(_flat(at, 0)))
	var boss: Node3D = main._boss()
	if boss:
		gap = minf(gap, _flat(boss.global_position, 0).distance_to(_flat(at, 0)) - BOSS_GD.BODY_RADIUS)
	return gap

func _pads(zone: int) -> Array:
	return main.map.get_node("Anchors/ReturnZones").get_child(zone).get_children()

func _open_ground(p: Vector3) -> bool:
	return main.map.farm_spawn_candidate(p, false).is_finite()

func _enemy_gaps() -> Array:
	var gaps := []
	for zone in main.map.farm_return_zones().size():
		var best := -INF
		for pad: Marker3D in _pads(zone):
			if _open_ground(pad.global_position):
				best = maxf(best, _pad_gap(pad.global_position))
		gaps.append(best)
	return gaps

func _return_pad(id: int, zone: int) -> Vector3:
	var open: Array[Vector3] = []
	var safest := Vector3.ZERO
	var maximum := -INF
	for pad: Marker3D in _pads(zone):
		var p := pad.global_position
		if not _open_ground(p):
			continue
		var gap := _pad_gap(p)
		if gap > maximum:
			maximum = gap
			safest = p
		if gap >= SPAWN_BLOCK:
			open.append(p)
	# 四區落點全被動態物件占住的罕見情況，改用一般規則的淨空地點。
	if maximum == -INF:
		return main._spawn_point()
	if open.size() > 1 and last_pad.has(id):
		open.erase(last_pad[id])
	var at: Vector3 = safest if open.is_empty() else open.pick_random()
	last_pad[id] = at
	return at

func _spawn_cowboy(id: int, bot: bool, index: int, at := Vector3.INF) -> void:
	if phase == &"play" and not at.is_finite() and index >= 0:
		at = _return_pad(id, index)
	super(id, bot, index, at)
	var actor: Node3D = main.players.get_node(NodePath(str(id)))
	actor.rotation.y = main.map.arrival_yaw(actor.global_position)
	actor.reset_physics_interpolation()
