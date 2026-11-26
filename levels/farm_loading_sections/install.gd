extends RefCounted
## 保留原果場逐塊木板與錯縫。視覺與碰撞由同一組八角點生成。
const STOCK = preload("res://levels/farm_loading_sections/stock.json")
const BATCH = preload("res://levels/farm_yard_sections/batch.gd")
const UNIT = preload("res://levels/farm_buildings_v31/unit.gd")
const FACES = [[3,2,1,0],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]

static func prism(body:StaticBody3D, surface:SurfaceTool, row:Array, palette:Dictionary) -> void:
	var points:=PackedVector3Array()
	for layer in [row[5],row[6]]:
		var h:Array=layer if layer is Array else [layer,layer]
		points.append_array(PackedVector3Array([Vector3(row[1],h[0],row[3]),Vector3(row[1],h[0],row[4]),Vector3(row[2],h[1],row[4]),Vector3(row[2],h[1],row[3])]))
	var rgb:Array=palette[row[7]]
	var center:Vector3=(points[0]+points[6]+points[2]+points[4])*.25
	for face:Array in FACES:
		var normal:Vector3=(points[face[1]]-points[face[0]]).cross(points[face[2]]-points[face[0]]).normalized()
		for i:int in [0,2,1,0,3,2]:
			surface.set_normal(normal)
			surface.set_color(Color(rgb[0],rgb[1],rgb[2],1))
			surface.add_vertex(points[face[i]])
	var shape:=CollisionShape3D.new()
	shape.name=str(row[0]).replace(".","_")
	shape.position=center
	if not row[5] is Array and not row[6] is Array:
		var box:=BoxShape3D.new()
		box.size=Vector3(row[2]-row[1],row[6]-row[5],row[4]-row[3])
		shape.shape=box
	else:
		for i in points.size():points[i]-=center
		var hull:=ConvexPolygonShape3D.new()
		hull.points=points
		shape.shape=hull
	body.add_child(shape)

# 臺面錯縫長短不一，板尾所在的小樑依原圖實際交疊位置決定。
static func plank_seats(key: String, row: Array, spec: Dictionary, parts: Dictionary) -> Array:
	if not key.begins_with("Deck"):
		return spec.seats
	var bay := key.get_slice("_", 0).trim_prefix("Deck")
	var contacts := []
	for i in 5:
		var joist := "Joist%s_%d" % [bay, i]
		var timber: Array = parts[joist].boards[0]
		if minf(row[4], timber[4]) > maxf(row[3], timber[3]):
			contacts.append(joist)
	assert(contacts.size() >= 2, str(row[0]))
	return [[contacts.front()], [contacts.back()]]

static func build_unit(kit: Node3D, id: String, boards: Array, spec: Dictionary, seats: Array, palette: Dictionary, material: Material) -> StaticBody3D:
	var body := UNIT.new()
	body.name = id
	body.set_meta("structure_material", spec.material)
	body.set_meta("component", spec.role)
	body.set_meta("support_seats", seats)
	body.set_meta("ground_anchor", seats.is_empty())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: Array in boards:
		prism(body, surface, row, palette)
	surface.index()
	var art := MeshInstance3D.new()
	art.name = "StockAssembly"
	art.mesh = surface.commit()
	art.material_override = material
	if spec.role == "floor":
		body.collision_layer |= 1 << 16
		var row: Array = boards[0]
		# 同色、同剖面的板共用繪製；坡腳受地面截切，有不同剖面。
		var profile := str(row[7])
		if row[5] is Array:
			var base_height: float = row[5][0]
			for height: float in [row[5][1], row[6][0], row[6][1]]:
				profile += "_%d" % roundi((height - base_height) * 100000)
		art.name = profile
	body.add_child(art)
	kit.add_child(body)
	return body

static func install(farm: Node3D) -> void:
	var station := farm.get_node("LoadingStation")
	if station.has_node("BoardSections"):
		return
	var kit := Node3D.new()
	kit.name = "BoardSections"
	var original: MeshInstance3D = station.get_node("Timbers").find_children("*", "MeshInstance3D", true, false)[0]
	var material := original.get_active_material(0)
	if not material:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
	var src: Dictionary = STOCK.data
	var planks := []
	for key: String in src.parts:
		var spec: Dictionary = src.parts[key]
		if spec.role == "floor":
			for index in spec.boards.size():
				var board: Array = spec.boards[index]
				var id := key if index == 0 else "%s_P%02d" % [key, index]
				planks.append(build_unit(kit, id, [board], spec, plank_seats(key, board, spec, src.parts), src.palette, material))
		else:
			build_unit(kit, key, spec.boards, spec, spec.seats, src.palette, material)
	station.get_node("Timbers").hide()
	for collider: CollisionShape3D in station.get_node("Platform").get_children():
		collider.disabled = true
	station.add_child(kit)
	BATCH.collect(kit, planks, true)
