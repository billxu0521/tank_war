extends SceneTree

const SCENE = preload("res://tools/cd_gbb_buildings/envelope_r005/review.tscn")
var failures: Array[String] = []
var stage: Node3D
var player: CharacterBody3D
var broken_crossings := 0
var dorm_sides := 0

func _initialize() -> void:
	call_deferred("run")

func tick(count: int = 2) -> void:
	for i in count: await physics_frame

func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func ray(start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, 1, [player.get_rid()])
	return stage.get_world_3d().direct_space_state.intersect_ray(query)

func stand(center: Vector3, side: Vector3) -> void:
	var near := center + side * .94
	var ground := ray(near, near - Vector3.UP * 2.5)
	assert(not ground.is_empty())
	player.global_position = ground.position + Vector3.UP * .005
	player.look_at(player.global_position - side)
	stage.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await tick()

func farm(house: Node3D) -> void:
	expect(house.fixed_windows.size() == 4, "農宅應有四扇固定窗")
	for pane in house.fixed_windows:
		var collider: CollisionShape3D = pane.get_child(0)
		var mid: Vector3 = collider.global_position
		var normal: Vector3 = pane.global_basis.z
		var prefix := str(pane.name) + " "
		expect(not pane.has_method("interact"), prefix + "不提供開合")
		for side in [normal, -normal]:
			await stand(mid, side)
			expect(stage.focus() == pane, prefix + "完整時可瞄準")
			expect(not stage.try_window_vault(), prefix + "完整時須擋住翻越")
		var shot := Bullet.new()
		shot.origin = mid - normal * .7
		shot.vel = normal * 90
		shot.weapon = player.viewmodel.weapon
		shot.shooter = player
		stage.add_child(shot)
		shot.advance(1.0/60)
		expect(pane.broken, prefix + "專案子彈命中並破壞")
		pane.on_shot(mid, player, normal)
		await tick()
		expect(pane.broken and not pane.visible and collider.disabled, prefix + "破壞後移除內格")
		expect(ray(mid-normal*.65, mid+normal*.65).is_empty(), prefix + "窗洞淨空")
		var sill := ray(mid + Vector3.UP * .1, mid - Vector3.UP * .75)
		expect(not sill.is_empty() and absf(sill.position.y - house.global_position.y - 1.1)<.025, prefix + "保留窗臺")
		# 在原窗框及厚牆中掃過與角色同寬、收身高 90 cm 的膠囊。
		var tucked := CapsuleShape3D.new()
		tucked.radius = .4
		tucked.height = .9
		for side in [normal, -normal]:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = tucked
			q.transform.origin = mid + side * .7
			q.motion = -side * 1.4
			q.exclude = [player.get_rid()]
			var travel := stage.get_world_3d().direct_space_state.cast_motion(q)
			expect(travel[0] >= .999, prefix + "收身通過整段窗洞")
			await stand(mid, side)
			var started: bool = stage.try_window_vault()
			expect(started, prefix + "破後可起跳 " + str(side))
			await tick(90)
			var destination := player.global_position
			var crossed: bool = (destination-mid).dot(side) < -.35 and not player.vaulting
			var floor_hit := ray(destination + Vector3.UP * .15, destination - Vector3.UP * .25)
			var grounded := not floor_hit.is_empty() and absf(floor_hit.position.y - destination.y) < .025
			expect(crossed and grounded and destination.y <= house.global_position.y+.03,
					prefix + "在另一側地面落腳 " + str(house.to_local(destination)))
			if started and crossed and grounded: broken_crossings += 1

func dorm(house: Node3D) -> void:
	for leaf in house.leaves:
		if leaf.get_meta("kind") != "window": continue
		var mid: Vector3 = house.global_transform * leaf.base_transform * leaf.shape_offset
		var normal: Vector3 = house.global_basis * leaf.base_transform.basis.z
		for side in [normal, -normal]:
			await stand(mid, side)
			expect(stage.focus() == leaf, str(leaf.name) + " 雙側能瞄準")
			var obstruction := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(.12, .25, .12)
			shape.shape = box
			obstruction.add_child(shape)
			stage.add_child(obstruction)
			var angle_sign := signf(side.dot(normal) * float(leaf.swing))
			obstruction.global_position = house.global_transform * leaf.pose(.5 * angle_sign) * leaf.shape_offset
			await tick()
			leaf.interact(player)
			expect(leaf.blocked and is_zero_approx(leaf.target), str(leaf.name) + " 開窗遇阻時停住")
			obstruction.queue_free()
			await tick()
			leaf.interact(player)
			await tick(60)
			var center: Vector3 = leaf.to_global(leaf.shape_offset)
			expect(absf(leaf.fraction)>.99 and (center-mid).dot(side)<-.15, str(leaf.name) + " 朝另一側完整開啟")
			player.global_position = mid - side*1.55 - Vector3.UP*1.3
			await tick()
			stage.camera.look_at(center)
			expect(stage.focus() == leaf, str(leaf.name) + " 對側可瞄準關窗")
			leaf.interact(player)
			await tick(60)
			expect(absf(leaf.fraction)<.001, str(leaf.name) + " 對側關窗")
			dorm_sides += 1
	expect(dorm_sides == 6, "宿舍三窗兩側")

func run() -> void:
	stage = SCENE.instantiate()
	root.add_child(stage)
	stage.set_physics_process(false)
	player = stage.player
	player._jump_sound = null
	player._land_sound = null
	await tick()
	await farm(stage.houses[0])
	await dorm(stage.houses[3])
	stage.queue_free()
	await process_frame
	await process_frame
	print("WINDOWS ", JSON.stringify({"farm_crossings":broken_crossings, "dorm_sides":dorm_sides, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
