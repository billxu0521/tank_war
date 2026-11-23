extends SceneTree
const BUILDING = preload("res://tools/cd_gbb_buildings/envelope_r005/building.gd")
var failures: Array = []
var rows: Array = []
func _initialize() -> void:
	call_deferred("run")
func tick(count: int = 2) -> void:
	for i in count: await physics_frame
func run() -> void:
	for number in [1,7,2,15]:
		var house := BUILDING.new()
		root.add_child(house)
		house.build(number, true)
		var actor := CharacterBody3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = .4
		shape.height = 1.8
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = .9
		actor.add_child(collider)
		root.add_child(actor)
		await tick()
		for leaf in house.leaves:
			if not leaf.bidirectional: continue
			var closed: Transform3D = house.global_transform * leaf.base_transform
			var middle: Vector3 = closed * Vector3(leaf.shape_offset.x,0,0)
			var normal: Vector3 = closed.basis.z
			for side in [-1,1]:
				leaf.set_fraction(0)
				actor.global_position = middle + normal * side * .9
				await tick()
				var eye: Vector3 = actor.global_position + Vector3.UP * 1.6
				var ray := PhysicsRayQueryParameters3D.create(eye,middle+Vector3.UP*1.6)
				ray.exclude = [actor.get_rid()]
				var hit := house.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider != leaf:
					failures.append([number,str(leaf.name),side,"cannot_focus_from_side",str(hit.get("collider","empty"))])
				leaf.interact(actor)
				var selected: float = leaf.target
				for frame in 50:
					if is_equal_approx(leaf.fraction,leaf.target): break
					await tick(1)
				var opened: Vector3 = (house.global_transform * leaf.pose(leaf.fraction)) * Vector3(leaf.shape_offset.x,0,0)
				var away: bool = (opened-middle).dot(actor.global_position-middle) < 0
				if absf(leaf.fraction)<.99 or not away:
					failures.append([number,str(leaf.name),side,"opening_failed",leaf.fraction,selected,leaf.prompt,away])
				var crossed := true
				# 0.9m窄門依開扇後剩餘淨空中心穿越，不要求走在關門葉片的中心線。
				var passage_bias: Vector3 = closed.basis.x * (.035 if leaf.shape.size.x < .9 else 0.0)
				for sample in 41:
					var point: Vector3 = middle + passage_bias + normal * lerpf(side*.9,-side*.9,float(sample)/40)
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = shape
					query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*.905)
					query.exclude = [actor.get_rid()]
					query.margin = .001
					if not house.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
						crossed = false
						failures.append([number,str(leaf.name),side,"crossing_blocked",sample])
						break
				# 關門時離開原有開扇掃掠區；站在掃掠區應保持受阻。
				actor.global_position = middle-normal*side*1.65
				await tick()
				leaf.interact(actor)
				for frame in 50:
					if is_equal_approx(leaf.fraction,leaf.target): break
					await tick(1)
				if absf(leaf.fraction)>.001:failures.append([number,str(leaf.name),side,"cannot_close_from_other_side",leaf.prompt])
				rows.append({"building":number,"door":str(leaf.name),"side":side,"away":away,"crossed":crossed,"selected":selected})
		actor.queue_free()
		house.queue_free()
		await tick()
	if rows.size() != 18: failures.append(["expected_18_door_sides",rows.size()])
	var report := {"rows":rows,"failures":failures,"scope":"實體玩家膠囊在兩側呼叫互動、物理幀開合及穿門取樣；非真人鍵鼠／多人測試"}
	print("TWO_SIDED_DOORS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
