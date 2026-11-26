extends RefCounted
## 田表角度為 X/Z 平面角。此入口亦接受其他平坦田面的中心、尺寸、角度及禁植區。

static func point(pair: Array) -> Vector2:
	return Vector2(pair[0], pair[1])

static func near_zones(spec: Dictionary, plan: Dictionary) -> Array:
	var zones := []
	var center := point(spec.center)
	var reach := point(spec.size).length() * 0.5 + 2.0
	for family: String in ["paths", "polygons", "circles"]:
		for item: Array in plan.get(family, []):
			var points := PackedVector2Array()
			var clearance := 0.0
			if family == "circles":
				points.append(point(item[1]))
				clearance = item[0]
			else:
				var line: Array = item if family == "polygons" else item[1]
				for p: Array in line:
					points.append(point(p))
				if family == "paths":
					clearance = item[0]
			var box := Rect2(points[0], Vector2.ZERO)
			for p in points:
				box = box.expand(p)
			if box.grow(reach + clearance).has_point(center):
				zones.append([family, clearance, points])
	return zones

static func clear_of_zones(p: Vector2, radius: float, zones: Array) -> bool:
	for zone: Array in zones:
		var points: PackedVector2Array = zone[2]
		var limit := radius + float(zone[1])
		if points.size() == 1:
			if p.distance_squared_to(points[0]) < limit * limit:
				return false
			continue
		var closed: bool = zone[0] == "polygons"
		if closed and Geometry2D.is_point_in_polygon(p, points):
			return false
		var n := points.size() if closed else points.size() - 1
		for j in n:
			var a := points[j]
			var b := points[(j + 1) % points.size()]
			var nearest := a if a.is_equal_approx(b) else Geometry2D.get_closest_point_to_segment(p, a, b)
			if p.distance_squared_to(nearest) < limit * limit:
				return false
	return true

static func layout(spec: Dictionary, plan: Dictionary, field_seed: int) -> Dictionary:
	var result := {"wheat": [], "stubble": [], "grass": [], "bush": []}
	if spec.use == "orchard":
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var half := point(spec.size) * 0.5
	var angle := deg_to_rad(float(spec.angle))
	var center := point(spec.center)
	var zones := near_zones(spec, plan)
	var height := float(spec.get("height", 0.0))
	# 這些半徑包含麥卡轉向／穗尖隨風擺動與草葉彎折，避免只有根部退讓。
	var radii := {"wheat": 1.65, "stubble": 1.05, "grass": 0.92, "bush": 2.0}
	var place := func(kind: String, uv: Vector2, scale_factor: float) -> void:
		var p := center + uv.rotated(angle)
		var radius := float(radii[kind]) * maxf(1.0, scale_factor)
		if absf(uv.x) + radius > half.x or absf(uv.y) + radius > half.y or not clear_of_zones(p, radius, zones):
			return
		result[kind].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE * scale_factor),
			Vector3(p.x, height, p.y)))
	for bush: Array in spec.get("bushes_local", []):
		place.call("bush",point(bush),1.0)
	for xf: Transform3D in result.bush:
		zones.append(["circles",1.2,PackedVector2Array([Vector2(xf.origin.x,xf.origin.z)])])
	if spec.use in ["wheat","stubble"]:
		var spacing := Vector2(0.84,0.8) if spec.use == "wheat" else Vector2(1.04,0.96)
		# 行向與母圖田紋一致。行尾留迴轉空間，收割田偶爾有一小段缺茬。
		for i in ceili(half.x * 2 / spacing.x):
			var u := -half.x + (i+0.5)*spacing.x
			var row_end := rng.randf_range(0.15,0.9)
			for j in ceili(half.y * 2 / spacing.y):
				var v := -half.y + (j+0.5)*spacing.y
				if absf(v) > half.y-1.1-row_end or (spec.use == "stubble" and sin(v*0.47+i*0.39)>0.64 and rng.randf()<0.5):
					continue
				place.call(spec.use, Vector2(u+rng.randf_range(-0.12,0.12), v+rng.randf_range(-0.20,0.20)),rng.randf_range(0.9,1.08))
	# 少踩的幾段田緣成簇長草；田心、道路及規則點仍保持乾淨。
	for side in [-1,1]:
		for j in ceili(half.y/2.5):
			var v := rng.randf_range(-half.y,half.y)
			var length := rng.randf_range(0.7,2.0)
			var inset := rng.randf_range(1.25,2.6) if spec.use == "low_margin" else rng.randf_range(1.0,1.5)
			for blade in (24 if spec.use == "low_margin" else 9):
				var uv := Vector2(side*(half.x-inset)+rng.randf_range(-0.65,0.65),v+rng.randfn(0,length))
				place.call("grass", uv, rng.randf_range(0.5,0.83))
	return result

## 沿用三張原麥卡、貼圖、朝向和風；只取卡片底部莖段，上緣為實際切口。
static func cut_stalks() -> Mesh:
	var src := ArenaMap.wheat_card()
	var data := src.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
	for i in vertices.size():
		var ratio := 0.10
		vertices[i].y *= ratio
		uv[i].y = 1.0 - (1.0-uv[i].y)*ratio
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	mesh.surface_set_material(0,src.surface_get_material(0))
	return mesh

static func draw(parent: Node3D, kind: String, transforms: Array, mesh: Mesh, material: Material = null) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = kind == "grass"
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	var bounds := AABB()
	for i in transforms.size():
		var xf: Transform3D = transforms[i]
		if kind == "bush":
			xf.origin.y -= 0.15
		mm.set_instance_transform(i,xf)
		var box: AABB = xf * mesh.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
		if mm.use_colors:
			mm.set_instance_color(i,Color("77804c").lerp(Color("a19b63"),fmod(i*0.618,1.0)))
	mm.custom_aabb = bounds.grow(1.0)
	var group := MultiMeshInstance3D.new()
	group.name = kind
	if kind == "bush":
		var shrubs := []
		for xf: Transform3D in transforms:
			xf.origin.y -= .15
			shrubs.append(xf)
		group.set_meta("farm_source_transforms",shrubs)
	group.multimesh = mm
	group.material_override = material
	if kind in ["grass","stubble"]:
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "grass":
		group.visibility_range_end = 52
	parent.add_child(group)

