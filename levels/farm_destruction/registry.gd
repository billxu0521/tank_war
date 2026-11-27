extends Node3D
## A v3.1 試玩用。伺服器判定傷害，每個可拆單位有跨主機一致的識別碼。
const Catalog := preload("res://levels/farm_destruction/catalog.gd")
const SupportGraph := preload("res://levels/farm_buildings_r004/supports.gd")
const Fragments := preload("res://levels/farm_destruction/fragments.gd")
const SENSOR := 1 << 25
const DURABILITY := {"glass":1,"soft":1,"wood":2,"brick":2,"earth":2,"stone":4,"metal":4,"frame":6,"bridge_deck":3,"bridge_frame":6}
var entries := {}
var health := {}
var by_shape := {}
var supports := {}
var support_graph := SupportGraph.new()
var fragments := Fragments.new()
var working_crates := preload("res://levels/farm_destruction/working_crates.gd").new()
var contact_keys := {}
var arena: Node3D
var doors: Array[Door] = []
var nav_pending := false
var nav_dirty := {}   # 碰撞有變的節點（主機）：main.gd 的 _parse_arena 拿去只重解析那一群
var waiting_state := {}

static func install(farm: Node3D) -> Node:
	if farm.has_node("FarmDestruction"):
		return farm.get_node("FarmDestruction")
	var registry := new()
	registry.name = "FarmDestruction"
	registry.arena = farm
	farm.add_child(registry)
	registry.add_to_group(&"farm_destruction")
	Catalog.populate(registry, farm)
	registry._index_supports()
	preload("res://levels/farm_yard_loads/install.gd").install(registry)
	registry.fragments.prepare(registry)
	return registry

func finish_environment(env: Node) -> void:
	while is_instance_valid(env) and not env.get_meta("ready_for_review",false):
		await get_tree().physics_frame
	if not is_instance_valid(env): return
	Catalog.register_stones(self,arena)
	if not waiting_state.is_empty():
		var pending := waiting_state.duplicate()
		waiting_state.clear()
		apply_patch_local(pending)

func register(key: String, family: String, nodes: Array, colliders: Array, native: Node = null) -> Dictionary:
	if entries.has(key):
		push_error("農莊破壞識別重複 " + key)
		return {}
	var part := {"key":key,"family":family,"limit":DURABILITY[family],"nodes":[],"shapes":[],"instances":[],"native":native}
	for n: Node3D in nodes:
		part.nodes.append([n, n.visible])
	for shape: CollisionShape3D in colliders:
		if shape.shape == null:
			continue
		part.shapes.append([shape,shape.disabled])
		by_shape[shape] = key
	entries[key] = part
	for node: Node in nodes:
		if node is Door and node not in doors: doors.append(node)
	return part

func key_at(obj: CollisionObject3D, shape_index: int, at := Vector3.INF) -> String:
	if working_crates.stacks.has(obj):
		return working_crates.slot_key(obj, at) if at.is_finite() else ""
	if not obj or shape_index < 0 or obj.get_shape_owners().is_empty():
		return ""
	var owner_id := obj.shape_find_owner(shape_index)
	var shape := obj.shape_owner_get_owner(owner_id)
	return by_shape.get(shape,"")

func bullet_material(obj: CollisionObject3D, shape: int) -> StringName:
	if working_crates.stacks.has(obj):
		return &"wood"
	var key := key_at(obj, shape)
	if key.is_empty() or entries[key].family == "glass":
		return &""
	return Fragments.material(entries[key])

func projectile(obj: CollisionObject3D, shape: int, at := Vector3.INF, reach := 0.0) -> void:
	if not multiplayer.is_server():
		return
	var key := key_at(obj, shape, at)
	if key.is_empty():
		return
	var near := fragments.fireball_parts(entries[key], entries, at, reach)
	var force := Balance.whole("hit_fireball_force")
	var keys := []
	var ignite := false
	for affected: String in near:
		var part: Dictionary = entries[affected]
		if health.get(affected, part.limit) <= 0:
			continue
		var mat := Fragments.material(part)
		if HitRules.breaks(force, mat):
			keys.append(affected)
		if part.family != "glass" and HitRules.burns(mat):
			ignite = true
	if ignite and at.is_finite() and Balance.whole("fire_burns_toys") != 0 and not fragments.homes.is_empty():
		var home: ToyBuild = fragments.homes[entries[key].get("debris_site", fragments.homes.keys()[0])]
		home.fire_at(at, Balance.num("fire_ball_radius"), Balance.num("fire_ball_seconds"))
	impact(keys, 1, at)

func blast(at: Vector3, radius: float, force: int) -> void:
	if not multiplayer.is_server() or radius <= 0.0:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = at
	query.collision_mask = 0xffffffff
	query.collide_with_areas = true
	var keys := {}
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,by_shape.size()+128):
		if working_crates.stacks.has(hit.collider):
			if HitRules.breaks(force, &"wood"):
				working_crates.sphere_hits(hit.collider, at, radius, keys)
			continue
		var key := key_at(hit.collider,hit.shape)
		if entries.has(key) and HitRules.breaks(force,Fragments.material(entries[key])):
			keys[key] = true
	impact(keys.keys(),1,at)

func strike(boss: CharacterBody3D, bite: bool) -> void:
	if not multiplayer.is_server():
		return
	var foot: Vector3 = boss.global_position - Vector3.UP * boss.HALF_H
	var direction: Vector3 = -boss.global_basis.z if bite else boss._back_dir()
	direction.y = 0.0
	direction = direction.normalized()
	var spread: float = acos(boss.LIGHT_COS if bite else boss.SWEEP_COS)
	var reach: float = boss.BODY_RADIUS + boss.LIGHT_REACH if bite else boss.SWEEP_RADIUS
	if not bite:
		foot += direction * boss.SWEEP_ROOT_BACK
	var keys := {}
	for sample in 11:
		var heading := direction.rotated(Vector3.UP,lerpf(-spread,spread,sample/10.0))
		for height: float in [0.42,1.42,2.90,4.50]:
			var origin := foot + Vector3.UP * height
			var destination := origin + heading * reach
			_trace(origin,destination,boss,keys,bite)
		# 稍向下咬或掃，讓站在橋上的恐龍能擊中橋板。
		_trace(foot + Vector3.UP*1.65, foot + heading*reach + Vector3.DOWN*.72, boss,keys,bite)
	var force := Balance.whole("hit_sweep_force")
	var breakable := keys.keys().filter(func(key): return HitRules.breaks(force, Fragments.material(entries[key])))
	impact(breakable, 2 if bite else 3, foot, direction, ToyBuild.FALL_SPEED, keys if bite else {})

func _trace(origin: Vector3, target: Vector3, boss: CharacterBody3D, keys: Dictionary, bite := false) -> void:
	var ray := PhysicsRayQueryParameters3D.create(origin,target,1 | SENSOR,[boss.get_rid()])
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var key := key_at(hit.collider,hit.shape,hit.position)
		if not key.is_empty():
			# 咬到堆垛時保留外箱的實際受擊面；同箱多次命中時先取側面。
			if not bite or not key.begins_with("yardload/FarmCrates/"):
				keys[key] = true
			elif not keys.has(key) or absf(hit.normal.y) < absf(keys[key].y):
				keys[key] = hit.normal

func charge(boss: CharacterBody3D, motion: Vector3) -> void:
	var touching := {}
	var frontal_impact := false
	if boss.running and motion.length() >= boss.TOY_CHARGE_SPEED:
		for i in boss.get_slide_collision_count():
			var collision := boss.get_slide_collision(i)
			if -motion.dot(collision.get_normal()) >= boss.TOY_CHARGE_SPEED*.65:
				var key := key_at(collision.get_collider(),collision.get_collider_shape_index(),collision.get_position())
				if not key.is_empty():
					touching[key] = true
					frontal_impact = true
		# 可穿過的圍欄以感應範圍偵測衝刺。
		var foot: Vector3 = boss.global_position - Vector3.UP * boss.HALF_H
		# 膠囊的第一個接觸常在屋簷；同一撞擊可碰到下方緊鄰的外牆。
		if frontal_impact:
			for height: float in [.80,2.30,3.80]:
				var origin := foot + Vector3.UP*height
				_trace(origin,origin+motion.normalized()*(boss.BODY_RADIUS+.62),boss,touching)
		var shape := BoxShape3D.new()
		shape.size = Vector3(boss.BODY_RADIUS*1.55,2.0,boss.BODY_RADIUS)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.looking_at(motion.normalized()),foot + Vector3.UP + motion.normalized()*boss.BODY_RADIUS*.7)
		query.collision_mask = SENSOR
		query.collide_with_bodies = false
		query.collide_with_areas = true
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,32):
			var key := key_at(hit.collider,hit.shape)
			if not key.is_empty():
				touching[key] = true
	var fresh := []
	if not contact_keys.has(boss):
		boss.tree_exiting.connect(func(): contact_keys.erase(boss),CONNECT_ONE_SHOT)
	var latched: Dictionary = contact_keys.get(boss,{})
	var contacts_now := {}
	for key: String in touching:
		var contact: String = entries[key].get("charge_contact", key)
		if not latched.has(contact) and HitRules.breaks(boss.TOY_CHARGE_LEVEL, Fragments.material(entries[key])):
			fresh.append(key)
		contacts_now[contact] = boss.global_position
	latched.merge(contacts_now, true)
	# 必須離開接觸位置後再衝；持續朝牆推不會反覆扣血。
	for key: String in latched.keys():
		if not contacts_now.has(key) and boss.global_position.distance_to(latched[key]) > boss.BODY_RADIUS*.85:
			latched.erase(key)
	contact_keys[boss] = latched
	impact(fresh,2,boss.global_position,motion.normalized(),maxf(ToyBuild.FALL_SPEED,motion.length()))

func impact(keys: Array, amount: int, at := Vector3.INF, dir := Vector3.ZERO, power := ToyBuild.FALL_SPEED, bite_faces := {}) -> void:
	if not multiplayer.is_server():
		return
	var patch := {}
	for key: String in keys:
		if entries.has(key) and entries[key].has("crate_slot"):
			var part: Dictionary = entries[key]
			part.crate_stack.remove_slot(part.crate_slot)
			continue
		if entries.has(key) and health.get(key,entries[key].limit)>0:
			patch[key] = maxi(0,health.get(key,entries[key].limit)-amount)
	if patch.is_empty():
		return
	patch = support_graph.cascades(self,patch)
	var fallen := {}
	for key: String in patch:
		if patch[key] == 0 and health.get(key,entries[key].limit) > 0:
			fallen[key] = true
	if not at.is_finite():
		var part: Dictionary = entries[patch.keys()[0]]
		if not part.shapes.is_empty():
			at = part.shapes[0][0].global_position
		elif not part.nodes.is_empty():
			at = part.nodes[0][0].global_position
		else:
			at = global_position
	var poses := fragments.moving_poses(fallen,entries)
	_update(patch,poses,at,fallen.is_empty())
	if multiplayer.has_multiplayer_peer():
		_update.rpc(patch,poses,at,fallen.is_empty())
	fragments.release(fallen,entries,at,dir,power,bite_faces)

@rpc("authority","call_remote","reliable")
func _update(patch: Dictionary, poses: Dictionary, at: Vector3, hurt_only: bool) -> void:
	fragments.set_poses(poses)
	apply_patch_local(patch)
	if hurt_only:
		ToyBuild.hit_fx(self,at,false)

func apply_patch_local(patch: Dictionary) -> void:
	var changes := false
	for key: String in patch:
		if not entries.has(key):
			if key.begins_with("stone/"): waiting_state[key] = patch[key]
			continue
		var p: Dictionary = entries[key]
		var before: int = health.get(key,p.limit)
		var after: int = patch[key]
		if after == p.limit:
			health.erase(key)
		else:
			health[key] = after
		if (before == 0) != (after == 0):
			_set_present(p,after>0)
			changes = true
	if changes and multiplayer.is_server() and not nav_pending:
		nav_pending = true
		_rebake_after_physics()

func _rebake_after_physics() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	nav_pending = false
	var game := get_tree().current_scene
	if game and game.has_method("bake_nav"):
		game.bake_nav(true)

func _set_present(p: Dictionary, value: bool) -> void:
	if multiplayer.is_server():
		if p.native:
			nav_dirty[p.native] = true
		for shape: Array in p.shapes:
			nav_dirty[shape[0].get_parent()] = true
	if p.native and p.native.has_method("set_present"):
		p.native.set_present(value)
	elif p.native and p.native.has_method("set_broken"):
		p.native.set_broken(not value)
	else:
		for node: Array in p.nodes:
			node[0].visible = value and node[1]
		for shape: Array in p.shapes:
			shape[0].set_deferred("disabled",not value or shape[1])
	for item: Array in p.instances:
		var xf: Transform3D = item[2]
		if not value:
			xf.basis = Basis.from_scale(Vector3.ZERO)
		item[0].multimesh.set_instance_transform(item[1],xf)

func send_state_to(peer: int) -> void:
	if multiplayer.is_server() and not health.is_empty():
		_snapshot.rpc_id(peer,health)
		fragments.send_state_to(peer)

@rpc("authority","call_remote","reliable")
func _snapshot(saved: Dictionary) -> void:
	fragments.restore()
	waiting_state.clear()
	var patch := saved.duplicate()
	for key: String in health:
		if not patch.has(key):
			patch[key] = entries[key].limit
	apply_patch_local(patch)

func has_changed() -> bool:
	if not health.is_empty() or working_crates.changed() or doors.any(func(door: Door) -> bool: return door.is_open):
		return true
	for pane: Node in get_tree().get_nodes_in_group(&"farm_fixed_glazing"):
		if arena.is_ancestor_of(pane) and pane.broken:
			return true
	return false

func restore_all() -> bool:
	contact_keys.clear()
	var closed := working_crates.restore()
	for door: Door in doors:
		if door.is_open:
			door._set_open.rpc(false)
			closed = true
	if health.is_empty():
		return closed
	_snapshot({})
	if multiplayer.has_multiplayer_peer():
		_snapshot.rpc({})
	return true

func depend(child: String, parent_key: String) -> void:
	if not supports.has(child):
		supports[child] = []
	if parent_key not in supports[child]:
		supports[child].append(parent_key)

func _index_supports() -> void:
	support_graph.index(self)
	for message: String in support_graph.errors:
		push_error("農莊承座未登記 " + message)
	# 建築師的逐端承座優先；橋板、草料堆等舊件的多個原支點可互為替代。
	var legacy := supports.duplicate(true)
	supports.clear()
	for child: String in legacy:
		var part: Node = entries[child].native
		if not part or not part.has_meta("support_seats"):
			require_seats(child,[legacy[child]])
	for child: String in support_graph.seats:
		for seat: Array in support_graph.seats[child]:
			for parent_key: String in seat:
				depend(child,parent_key)

func require_seats(child: String, seats: Array) -> void:
	for seat: Array in support_graph.seats.get(child,[]):
		for key: String in seat:
			if support_graph.uses.has(key):
				support_graph.uses[key].erase(child)
	support_graph.seats.erase(child)
	supports.erase(child)
	if seats.is_empty():
		return
	support_graph.seats[child] = []
	for seat in seats:
		var valid := []
		for key: String in seat:
			if not entries.has(key):
				push_error("未登記的承座 " + child + " / " + key)
				continue
			valid.append(key)
			depend(child,key)
			if not support_graph.uses.has(key):
				support_graph.uses[key] = []
			if child not in support_graph.uses[key]:
				support_graph.uses[key].append(child)
		support_graph.seats[child].append(valid)
