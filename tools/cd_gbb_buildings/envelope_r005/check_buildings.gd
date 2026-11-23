extends SceneTree
const BUILDING = preload("res://tools/cd_gbb_buildings/envelope_r005/building.gd")
var failures: Array = []
var rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for number in [1, 7, 15, 2]:
		var house := BUILDING.new()
		root.add_child(house)
		house.build(number, true)
		await physics_frame
		await physics_frame
		var roof_local := Vector3(8, 5, -8) if number == 1 else Vector3(10, 5, -2.5)
		var roof_ray := PhysicsRayQueryParameters3D.create(house.to_global(roof_local), house.to_global(roof_local - Vector3(0, 3, 0)))
		if house.get_world_3d().direct_space_state.intersect_ray(roof_ray).is_empty():
			failures.append([number, "roof_ray"])
		var triangles := 0
		var mesh_count := 0
		var colored_surfaces := 0
		var normal_surfaces := 0
		for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
				var material := mi.mesh.surface_get_material(surface) as BaseMaterial3D
				if material and material.resource_name.begins_with("detail_vertex_"):
					colored_surfaces += 1
					if material.normal_enabled and material.normal_texture:
						normal_surfaces += 1
						var image := material.normal_texture.get_image()
						var pixel := image.get_pixel(0, 0)
						if pixel.b < 0.9 or pixel.r < 0.4 or pixel.r > 0.6:
							failures.append([number, "invalid_normal_pixel", pixel])
					if not material.vertex_color_use_as_albedo:
						failures.append([number, "vertex_color_disabled", mi.name])
		if colored_surfaces == 0:
			failures.append([number, "missing_detail_materials"])
		if number == 1 and normal_surfaces == 0:
			failures.append([number, "missing_plaster_normal"])
		var folder: String = str(house.spec.model_path).get_base_dir().get_file()
		var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/cd_gbb/%s/bld_%02d_metrics.json" % [folder, number]))
		if triangles != int(metrics.triangles):
			failures.append([number, "triangle_readback", triangles, metrics.triangles])
		var expected: Dictionary = metrics.get("runtime_groups", metrics.units)
		var unit_triangles: Dictionary = {}
		for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			var unit := str(mi.name).split("__")[0]
			if unit == "a3_lid": unit = "a3_chest"
			if unit not in expected: unit = "shell"
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				unit_triangles[unit] = unit_triangles.get(unit, 0) + (ix.size() / 3 if not ix.is_empty() else vs.size() / 3)
		for unit in expected:
			if unit_triangles.get(unit, 0) != int(expected[unit].triangles):
				failures.append([number, "runtime_group_readback", unit, unit_triangles.get(unit, 0)])
		for unit in metrics.units:
			if int(metrics.units[unit].triangles) > int(metrics.units[unit].limit):
				failures.append([number, "complete_unit_budget", unit])
		# 包絡中心必須讀回同版地圖坐標，避免把旋轉當作網格對齊。
		var place: Dictionary = house.spec.placement
		var center := house.to_global(Vector3(place.w / 2.0, 0, -place.d / 2.0))
		if center.distance_to(Vector3(place.center_m[0], place.floor_h, -place.center_m[1])) > 0.001:
			failures.append([number, "placement_center"])
		var tested := 0
		for leaf in house.leaves:
			var mid: Vector3 = house.global_transform * leaf.base_transform * leaf.shape_offset
			var normal: Vector3 = house.global_basis * leaf.base_transform.basis.z
			var ray := PhysicsRayQueryParameters3D.create(mid - normal * 0.1, mid + normal * 0.1)
			var closed := house.get_world_3d().direct_space_state.intersect_ray(ray)
			if closed.is_empty() or closed.collider != leaf:
				failures.append([number, "closed_leaf_ray", leaf.name])
			for i in range(31):
				if not leaf.clear_at(float(i) / 30.0):
					failures.append([number, "leaf_sweep", leaf.name, i])
					break
			leaf.set_fraction(1.0)
			await physics_frame
			await physics_frame
			var opened := house.get_world_3d().direct_space_state.intersect_ray(ray)
			if not opened.is_empty():
				failures.append([number, "open_leaf_ray", leaf.name])
			tested += 1
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		var route_samples := 0
		var routes: Array = house.spec.routes.duplicate(true)
		if number == 1:
			for approach: Dictionary in house.spec.approaches:
				routes.append({"name": approach.id, "points": approach.path})
		for route: Dictionary in routes:
			for k in range(route.points.size() - 1):
				var a := Vector2(route.points[k][0], route.points[k][1])
				var b := Vector2(route.points[k + 1][0], route.points[k + 1][1])
				var count := maxi(2, ceili(a.distance_to(b) / 0.1))
				for i in range(count + 1):
					var point := a.lerp(b, float(i) / count)
					var q := PhysicsShapeQueryParameters3D.new()
					q.shape = capsule
					q.transform = house.global_transform * Transform3D(Basis.IDENTITY, Vector3(point.x, 0.94, -point.y))
					q.margin = 0.001
					var hits := house.get_world_3d().direct_space_state.intersect_shape(q, 1)
					if not hits.is_empty():
						failures.append([number, "route", route.name, point.x, point.y, str(hits[0].collider)])
						break
					route_samples += 1
		# 證明檢查確實能抓錯：門中心放阻擋物必須被掃掠檢查辨識。
		var detector_ok := true
		if number == 1:
			var leaf: Node3D = house.leaves[0]
			var block := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.35, 1.6, 0.35)
			cs.shape = box
			block.add_child(cs)
			house.add_child(block)
			block.transform = leaf.pose(0.5) * Transform3D(Basis.IDENTITY, leaf.shape_offset)
			await physics_frame
			await physics_frame
			detector_ok = not leaf.clear_at(0.5)
			if not detector_ok:
				failures.append([number, "blocker_detection"])
			block.queue_free()
		var operation_count: int = await operations(house, number)
		rows.append({"operations_tested": operation_count, "building": number, "triangles_readback": triangles, "mesh_count": mesh_count, "colored_surfaces": colored_surfaces, "normal_surfaces": normal_surfaces,
			"leaves_sweep_tested": tested, "route_samples": route_samples, "blocker_detector": detector_ok})
		house.queue_free()
		await process_frame
	var report := {"rows": rows, "failures": failures, "scope": "GLB讀回、候選膠囊取樣與葉扇檢查；非真輸入實玩或多人驗收"}
	print("CD_GBB_CHECK ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func operations(house: Node3D, number: int) -> int:
	var count := 0
	for op: Dictionary in house.spec.get("operations", []):
		var own: CollisionShape3D
		var base: Dictionary = {}
		if op.has("collision_index"):
			own = house.get_node("StructureCollision").get_child(int(op.collision_index)) as CollisionShape3D
			base = house.spec.collisions[int(op.collision_index)]
			own.set_deferred("disabled", true)
			await physics_frame
			await physics_frame
		var box := BoxShape3D.new()
		var poses: Array = []
		if op.kind == "carry":
			box.size = BUILDING.size_xyz(op.size)
			for point: Array in op.points: poses.append([point[0], point[1], 0.0])
		elif op.kind == "prop_slide":
			box.size = BUILDING.size_xyz(base.size)
			poses = [[base.position[0], base.position[1], rad_to_deg(base.rotation[2])],
				[base.position[0]+op.direction[0]*op.distance, base.position[1]+op.direction[1]*op.distance, rad_to_deg(base.rotation[2])]]
		else:
			box.size = BUILDING.size_xyz(base.size)
			poses = op.poses
		var blocked := false
		for k in range(poses.size()-1):
			var a: Array = poses[k]
			var b: Array = poses[k+1]
			var steps := maxi(31, ceili(Vector2(float(a[0]),float(a[1])).distance_to(Vector2(float(b[0]),float(b[1])))/0.05))
			for i in range(steps+1):
				var f := float(i)/steps
				var height: float = float(op.height) if op.kind == "carry" else float(base.position[2])+0.005
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = box
				q.transform = house.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(lerpf(float(a[2]),float(b[2]),f))), Vector3(lerpf(float(a[0]),float(b[0]),f),height,-lerpf(float(a[1]),float(b[1]),f)))
				q.margin = 0.001
				var hits := house.get_world_3d().direct_space_state.intersect_shape(q,1)
				if not hits.is_empty():
					failures.append([number,"operation",op.name,k,i,str(hits[0].collider)])
					blocked = true
					break
			if blocked:break
		if own:
			own.set_deferred("disabled",false)
			await physics_frame
			await physics_frame
		count += 1
	return count
