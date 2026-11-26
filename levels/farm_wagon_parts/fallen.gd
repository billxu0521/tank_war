extends RefCounted
## 保留原車件的網格、材質及落定碰撞；跨機沿用 ToyBuild 的構件編號及姿勢。
static func append(bricks: Array, stock: Array, unit: Node3D, origin: Transform3D, mat: StringName) -> void:
	var art: MeshInstance3D = unit.get_node("StockAssembly")
	var bounds: AABB = art.transform * art.mesh.get_aabb()
	var center := Transform3D(Basis.IDENTITY, bounds.get_center())
	bricks.append([origin.affine_inverse() * unit.global_transform * center, bounds.size, HitRules.level(mat), Color.WHITE, false, mat])
	var solid: CollisionShape3D = unit.find_children("*", "CollisionShape3D", false, false)[0]
	stock.append({"art": art.mesh, "pose": center.affine_inverse() * art.transform, "solid": solid.shape,
		"solid_pose": center.affine_inverse() * solid.transform, "name": str(unit.name)})

static func dress(body: Node) -> void:
	if not body.has_meta(&"toy_home"): return
	var home: ToyBuild = body.get_meta(&"toy_home")
	if not home.has_meta(&"farm_wagon_stock"): return
	var stock: Array = home.get_meta(&"farm_wagon_stock")
	var info: Dictionary = home._info[body.get_meta(&"toy_key")]
	for old in body.get_children():
		if old is MultiMeshInstance3D:
			old.hide()
		elif old is CollisionShape3D:
			old.disabled = true
	for j in info.m.size():
		var item: Dictionary = stock[info.m[j]]
		var local: Transform3D = info.rel[j]
		var view := MeshInstance3D.new()
		view.name = item.name
		view.mesh = item.art
		view.transform = local * item.pose
		body.add_child(view)
		if body is StaticBody3D or item.solid is ConvexPolygonShape3D:
			add_solid(body, item.solid, local * item.solid_pose)
		else:
			# 車輪、拱弓和篷布的靜態原件是三角面；飛行中的剛體需用凸體。
			if not item.has("flight_hulls"):
				item.flight_hulls = flight_hulls(item)
			for hull in item.flight_hulls:
				add_solid(body, hull, local)

static func add_solid(body: Node, shape: Shape3D, pose: Transform3D) -> void:
	var solid := CollisionShape3D.new()
	solid.shape = shape
	solid.transform = pose
	body.add_child(solid)

static func flight_hulls(item: Dictionary) -> Array:
	var faces: PackedVector3Array = item.pose * item.art.get_faces()
	var bins := {}
	var wheel: bool = item.name.begins_with("Wheel")
	var bounds: AABB = item.pose * item.art.get_aabb()
	for i in range(0, faces.size(), 3):
		var p := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		var cell: int
		if wheel:
			cell = posmod(floori((atan2(p.y, p.x) + PI) * 8.0 / TAU), 8)
		else:
			cell = clampi(floori((p.z - bounds.position.z) * 6.0 / maxf(0.001, bounds.size.z)), 0, 5)
		var points: Array = bins.get_or_add(cell, [])
		points.append(faces[i])
		points.append(faces[i + 1])
		points.append(faces[i + 2])
	var shapes := []
	for points: Array in bins.values():
		var cloud := PackedVector3Array(points)
		# 給單面篷布極薄的厚度，以產生有效體積。
		var count := cloud.size()
		for i in count:
			cloud.append(cloud[i] + Vector3.UP * 0.008)
		var hull := ConvexPolygonShape3D.new()
		hull.points = cloud
		shapes.append(hull)
	return shapes
