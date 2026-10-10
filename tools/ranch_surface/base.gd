extends RefCounted
## 隔離候選：只換 ground MeshInstance 材質，所有玩法資料與碰撞保持原件。
const RESOLUTION := 672 # 0.25m/texel；線性遮罩不產生新的幾何。
var landscape_mask: Image
var condition_mask: Image
var farm_zone: Rect2
var forest_zone: Rect2
var farm_entries: Array[Array] = []
var farm_pads: Array[Rect2] = []
var tree_count := 0
var rock_count := 0
var arena_size := 168.0


var baseline: Material
var candidate: ShaderMaterial
var ground_mesh: MeshInstance3D
var mask: Image
var detail_mask: Image
var wagon_traces: Array[Array] = []
var town_road := Rect2()
var town_zone := Rect2()
var shed_aprons: Array[Rect2] = []
var fields: Array[Rect2] = []
var roads: Array[Rect2] = []
var entries: Array[Array] = []
var wear_spots: Array[Vector2] = []
var noise := FastNoiseLite.new()

func install(m: Node) -> void:
	town_zone = m.ZONE_TOWN
	for rec: Dictionary in m._level:
		var p := Vector2(rec.pos.x, rec.pos.z)
		if rec.kind == &"hay_shed":
			shed_aprons.append(m._shed_rect(rec.pos))
		elif rec.kind == &"wheat":
			fields.append(Rect2(p - Vector2.ONE * rec.size * 0.5, Vector2.ONE * rec.size))
		elif rec.kind == &"road":
			var r := Rect2(p - Vector2(rec.size.x, rec.size.z) * 0.5, Vector2(rec.size.x, rec.size.z))
			roads.append(r)
			if rec.size.z > 3.0 and rec.size.x > rec.size.z * 4.0:
				town_road = r
	for rec: Dictionary in m._level:
		var p := Vector2(rec.pos.x, rec.pos.z)
		if not town_road.grow(19.0).has_point(p):
			continue
		if rec.kind == &"shop" or rec.kind == &"house":
			var yaw: float = rec.get("yaw", 0.0)
			var front := Vector2(sin(yaw), cos(yaw))
			var depth: float = m.SHOP_HALF.get(rec.get("variant", &""), Vector2(6, 6.5)).y
			var a := p + front * (depth - 0.5)
			var b := Vector2(a.x, town_road.get_center().y)
			entries.append([a, b, 1.15 + fmod(absf(p.x), 3.0) * 0.15])
		elif rec.kind == &"hitch" or (rec.kind == &"prop" and rec.get("name") == &"Wagon"):
			wear_spots.append(p)
			if rec.kind == &"prop":
				var yaw: float = rec.get("yaw", 0.0)
				var fwd := Vector2(sin(yaw), cos(yaw))
				var side := Vector2(cos(yaw), -sin(yaw))
				# props.py 四輪中心 local X=±0.92m；只留下接近停放位置的短輪跡。
				for sign_value in [-1.0, 1.0]:
					wagon_traces.append([p + side * sign_value * 0.92 - fwd * 1.0, p + side * sign_value * 0.92 - fwd * 4.0])
	noise.seed = 10102026
	noise.frequency = 0.65
	mask = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	detail_mask = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	var area: float = m.ARENA
	for iz in RESOLUTION:
		for ix in RESOLUTION:
			var p := Vector2((ix + 0.5) / RESOLUTION, (iz + 0.5) / RESOLUTION) * area - Vector2.ONE * area * 0.5
			mask.set_pixel(ix, iz, weights(p))
			detail_mask.set_pixel(ix, iz, detail_weights(p))
	var ground: Node = m.get_tree().get_first_node_in_group(&"ground")
	ground_mesh = ground.get_child(0) as MeshInstance3D
	baseline = ground_mesh.mesh.surface_get_material(0)
	candidate = baseline.duplicate() as ShaderMaterial
	candidate.shader = load("res://tools/ranch_surface/base.gdshader")
	candidate.set_shader_parameter(&"study_mask", ImageTexture.create_from_image(mask))
	candidate.set_shader_parameter(&"study_size", area)
	candidate.set_shader_parameter(&"detail_mask", ImageTexture.create_from_image(detail_mask))
	if not fields.is_empty():
		candidate.set_shader_parameter(&"row_origin", fields[0].position.x + 0.5)
	farm_zone = m.ZONE_FARM
	forest_zone = m.ZONE_FOREST
	arena_size = m.ARENA
	landscape_mask = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	condition_mask = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	for rec: Dictionary in m._level:
		var p := Vector2(rec.pos.x, rec.pos.z)
		if rec.kind == &"tree":
			tree_count += 1
			stamp(p, 4.5 + fmod(absf(p.x + p.y), 2.5), 1, 0.75)
		elif rec.kind == &"rock":
			rock_count += 1
			stamp(p, 2.0, 3, 0.65)
		elif rec.kind in [&"house", &"barn", &"silo", &"windmill"] and farm_zone.has_point(p):
			var half := Vector2(5.5, 6.5)
			if rec.kind == &"barn":
				half = Vector2(rec.size.x, rec.size.z) * 0.5
			elif rec.kind == &"silo" or rec.kind == &"windmill":
				half = Vector2(3.0, 3.0)
			farm_pads.append(Rect2(p - half - Vector2.ONE * 3.0, (half + Vector2.ONE * 3.0) * 2.0))
			# 現存農舍／穀倉正面朝+Z；短通行帶只延伸至門前。
			if rec.kind in [&"house", &"barn"]:
				farm_entries.append([p + Vector2(0, half.y - 0.5), p + Vector2(0, half.y + 7.0), 1.5])
	for iz in RESOLUTION:
		for ix in RESOLUTION:
			var p := (Vector2(ix + 0.5, iz + 0.5) / RESOLUTION - Vector2.ONE * 0.5) * arena_size
			var n := noise.get_noise_2d(p.x * 0.18, p.y * 0.18)
			var land := landscape_mask.get_pixel(ix, iz)
			var farm := 0.0
			for pad: Rect2 in farm_pads:
				farm = maxf(farm, rect_weight(pad, p, 2.2))
			land.r = farm * (0.76 + n * 0.18)
			land.g = maxf(land.g * (0.68 + n * 0.4), rect_weight(forest_zone, p, 9.0) * (0.35 + n * 0.18))
			var travel: float = Trails.weight(p.x, p.y)
			for r: Rect2 in roads:
				travel = maxf(travel, rect_weight(r, p, 0.65))
			var wear := 0.0
			for e: Array in farm_entries:
				wear = maxf(wear, segment_weight(p, e[0], e[1], e[2]))
			land.b = travel
			land.a *= 0.65 + n * 0.30
			landscape_mask.set_pixel(ix, iz, land)
			# 局部凹度只作潮濕色彩候選，不宣稱水文模擬，沒有水面／反光。
			var h: float = m._terrain.fast_height(p.x, p.y)
			var surrounding: float = (m._terrain.fast_height(p.x+3, p.y) + m._terrain.fast_height(p.x-3, p.y) + m._terrain.fast_height(p.x, p.y+3) + m._terrain.fast_height(p.x, p.y-3)) * 0.25
			var damp := land.g * smoothstep(0.04, 0.40, surrounding - h)
			var shoulder := (1.0 - smoothstep(0.25, 1.7, absf(Trails.edge(p.x, p.y) - 0.5))) * (0.55 + n * 0.4)
			condition_mask.set_pixel(ix, iz, Color(0.0, damp, wear, shoulder))
	candidate.shader = load("res://tools/ranch_surface/base.gdshader")
	candidate.set_shader_parameter(&"landscape_mask", ImageTexture.create_from_image(landscape_mask))
	candidate.set_shader_parameter(&"condition_mask", ImageTexture.create_from_image(condition_mask))
	for axis: StringName in [&"semantic_strength", &"detail_strength", &"boundary_strength"]:
		candidate.set_shader_parameter(axis, 0.3)
	set_enabled(true)


func set_enabled(on: bool) -> void:
	ground_mesh.material_override = candidate if on else baseline

func rect_weight(r: Rect2, p: Vector2, fade: float) -> float:
	if not r.has_point(p):
		return 0.0
	var d := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
	return smoothstep(0.0, fade, d)

func segment_weight(p: Vector2, a: Vector2, b: Vector2, width: float) -> float:
	var ab := b - a
	var q := a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var irregular := noise.get_noise_2d(p.x, p.y) * 0.24
	return 1.0 - smoothstep(width * 0.55, width + 0.6, p.distance_to(q) + irregular)

func weights(p: Vector2) -> Color:
	var town := rect_weight(town_road.grow(12.0).intersection(town_zone), p, 2.0)
	var wear := 0.0
	if town > 0.0:
		wear = rect_weight(town_road, p, 1.5) * 0.80
		for e: Array in entries:
			wear = maxf(wear, segment_weight(p, e[0], e[1], e[2]))
		for s: Vector2 in wear_spots:
			wear = maxf(wear, (1.0 - smoothstep(1.0, 3.2, p.distance_to(s))) * 0.85)
	var field := 0.0
	var path := 0.0
	for f: Rect2 in fields:
		field = maxf(field, rect_weight(f, p, 1.8))
		if f.has_point(p):
			var edge := minf(minf(p.x - f.position.x, f.end.x - p.x), minf(p.y - f.position.y, f.end.y - p.y))
			path = maxf(path, (1.0 - smoothstep(0.5, 2.8, edge)) * 0.42)
			for r: Rect2 in roads:
				if not r.intersects(f):
					continue
				var a := r.get_center()
				var b := a
				var width := minf(r.size.x, r.size.y) * 0.5
				if r.size.x > r.size.y:
					a.x = r.position.x
					b.x = r.end.x
				else:
					a.y = r.position.y
					b.y = r.end.y
				path = maxf(path, segment_weight(p, a, b, width * 0.74))
	for apron: Rect2 in shed_aprons:
		path = maxf(path, rect_weight(apron, p, 1.0) * 0.92)
	return Color(town, wear, field, path)

## R 鬆散路肩／入口周邊、G 短輪跡、B 田邊鬆土、A 田塊路口磨耗。
func detail_weights(p: Vector2) -> Color:
	var shoulder := 0.0
	var track := 0.0
	var loose := 0.0
	var entrance := 0.0
	var n := noise.get_noise_2d(p.x, p.y)
	var town := rect_weight(town_road.grow(12.0).intersection(town_zone), p, 2.0)
	if town > 0.0:
		# 路兩側細碎土石，寬度／連續度不同，避免道路劃線外觀。
		var dz := absf(p.y - town_road.get_center().y)
		shoulder = (1.0 - smoothstep(0.45, 1.35, absf(dz - town_road.size.y * 0.43 + n * 0.4))) * (0.45 + 0.4 * (n + 0.5))
		for e: Array in entries:
			var outer := segment_weight(p, e[0], e[1], e[2] + 1.0)
			var inner := segment_weight(p, e[0], e[1], e[2])
			shoulder = maxf(shoulder, maxf(outer - inner, 0.0) * 0.8)
		for trace: Array in wagon_traces:
			track = maxf(track, segment_weight(p, trace[0], trace[1], 0.12) * (0.75 + n * 0.5))
		shoulder *= town
		track *= town
	for f: Rect2 in fields:
		if not f.has_point(p):
			continue
		var field := rect_weight(f, p, 1.8)
		var edge := minf(minf(p.x - f.position.x, f.end.x - p.x), minf(p.y - f.position.y, f.end.y - p.y))
		loose = maxf(loose, (1.0 - smoothstep(1.0, 3.5, edge)) * field * 0.6)
		for r: Rect2 in roads:
			if not r.intersects(f):
				continue
			var horizontal := r.size.x > r.size.y
			var a := r.get_center()
			var b := a
			if horizontal:
				a.x = r.position.x
				b.x = r.end.x
			else:
				a.y = r.position.y
				b.y = r.end.y
			var width := minf(r.size.x, r.size.y) * 0.5
			var side_distance := absf((p.y - a.y) if horizontal else (p.x - a.x))
			loose = maxf(loose, (1.0 - smoothstep(0.20, 0.8, absf(side_distance - width + n * 0.2))) * field * 0.65)
			for end: Vector2 in [a, b]:
				entrance = maxf(entrance, (1.0 - smoothstep(1.3, 4.8, p.distance_to(end))) * field)
	return Color(clampf(shoulder, 0, 1), clampf(track, 0, 1), clampf(loose, 0, 1), clampf(entrance, 0, 1))
func stamp(center: Vector2, radius: float, channel: int, strength: float) -> void:
	var low := ((center - Vector2.ONE * radius) / arena_size + Vector2.ONE * 0.5) * RESOLUTION
	var high := ((center + Vector2.ONE * radius) / arena_size + Vector2.ONE * 0.5) * RESOLUTION
	for z in range(maxi(0, int(low.y)), mini(RESOLUTION, int(high.y) + 1)):
		for x in range(maxi(0, int(low.x)), mini(RESOLUTION, int(high.x) + 1)):
			var p := (Vector2(x + 0.5, z + 0.5) / RESOLUTION - Vector2.ONE * 0.5) * arena_size
			var w := (1.0 - smoothstep(radius * 0.20, radius, center.distance_to(p))) * strength
			var c := landscape_mask.get_pixel(x, z)
			c[channel] = clampf(c[channel] + w * (1.0 - c[channel]), 0.0, 1.0)
			landscape_mask.set_pixel(x, z, c)
