extends "res://tools/map_study/farm_trial/first_play.gd"

const PLOTS := preload("res://tools/map_study/farm_trial/placements.json")
const WORKYARD := preload("res://models/farm_ne_yard/NortheastWorkyard_r001.tscn")
const FIELD_MARGIN := preload("res://levels/east_field_margin/install.gd")

func _ready() -> void:
	super()
	add_child(WORKYARD.instantiate())
	FIELD_MARGIN.install(self)
	place_gate_lumber()
	make_yard_tracks()
	place_fodder_pickup()
	var shrubs: Array[Transform3D] = []
	for plot: Dictionary in PLOTS.data.values():
		for bank: Array in plot.get("banks", []):
			field_bank(bank)
		for crop: Array in plot.get("hay", []):
			stack_bales(Vector3(crop[0], 0, crop[1]), crop[2], int(crop[3]))
		for plant: Array in plot.get("trees", []):
			_tree({ "pos": Vector3(plant[0],0,plant[1]), "mesh": StringName(plant[2]), "s": plant[3], "yaw": plant[4] })
		for hedge: Array in plot.get("hedges", []):
			var p := Vector3(hedge[0], 0, hedge[1])
			shrubs.append(Transform3D(Basis(Vector3.UP, p.x*0.26).scaled(Vector3.ONE*float(hedge[2])), p + Vector3.DOWN*0.15))
			_reserve({ "kind": &"bush", "pos": p })
	if not shrubs.is_empty():
		var strip := _scatter(&"Bush", shrubs, true)
		strip.material_override = Greybox.bush_material()

func place_gate_lumber() -> void:
	# 從卸料車卸下的備用閘板，在渠務院短牆內側架空存放。
	var stockyard := Node3D.new()
	stockyard.name = &"StoredGateBoards"
	stockyard.position = Vector3(38.5, 0, -11.7)
	stockyard.rotation.y = deg_to_rad(102.0)
	add_child(stockyard)
	var unloading := get_node(^"FarmCanalWorks/UnloadingRack")
	for part_name: String in ["Trestles", "Stock"]:
		var part := unloading.get_node(part_name).duplicate() as Node3D
		part.position -= Vector3(1.52, 0, -0.35)
		stockyard.add_child(part)

func make_yard_tracks() -> void:
	# 車輪從原農路彎入院口，停在農舍南側。只在硬院土上留淺痕，兩端收細。
	var trail := Curve3D.new()
	trail.add_point(Vector3(48, 0.022, -25), Vector3.ZERO, Vector3(2.2, 0, -0.3))
	trail.add_point(Vector3(55, 0.022, -30.6), Vector3(-2.4, 0, -0.2), Vector3(2.0, 0, 0.25))
	trail.add_point(Vector3(62.5, 0.022, -29.5), Vector3(-1.8, 0, -0.36))
	var soil := SurfaceTool.new()
	soil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := trail.get_baked_length()
	for wheel: float in [-0.80, 0.80]:
		var last: Array[Vector3] = []
		for i in 33:
			var distance_m := length * i / 32.0
			var p := trail.sample_baked(distance_m)
			var direction := trail.sample_baked(minf(length, distance_m+0.1)) - trail.sample_baked(maxf(0, distance_m-0.1))
			var lateral := direction.normalized().cross(Vector3.UP)
			var half_width := (0.06 + 0.018 * sin(distance_m * 1.37 + wheel)) * smoothstep(0.0, 1.4, minf(distance_m,length-distance_m))
			var row: Array[Vector3] = [p+lateral*(wheel-half_width),p+lateral*(wheel+half_width)]
			if not last.is_empty():
				for v in [last[0],row[0],row[1],last[0],row[1],last[1]]:
					soil.add_vertex(v)
			last = row
	soil.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ab916c")
	material.roughness = 1.0
	soil.set_material(material)
	var tracks := MeshInstance3D.new()
	tracks.name = &"HarvestWagonTracks"
	tracks.mesh = soil.commit()
	tracks.layers |= EXIT_GROUND_LAYER
	tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracks)

func place_fodder_pickup() -> void:
	# 南田搬運道邊留一車份，靠車道的一端少一層，保留裝載缺口。
	var center := Vector3(26.05, 0, 50.18)
	var rotation_y := deg_to_rad(-12.0)
	var rotation_basis := Basis(Vector3.UP, rotation_y)
	var bales: Array[Transform3D] = []
	for column in 3:
		var tiers := 3 if column == 2 else 4
		var local_x := (column - 1) * 1.12
		for row in 2:
			for tier in tiers:
				var offset := Vector3(local_x, tier * HAY_BLOCK.y, (row - 0.5) * 0.60)
				bales.append(Transform3D(rotation_basis, center + rotation_basis * offset))
		var size := Vector3(HAY_BLOCK.x, tiers * HAY_BLOCK.y, 0.60 + HAY_BLOCK.z)
		var block := _solid_box(center + rotation_basis * Vector3(local_x, size.y / 2, 0), size)
		block.rotation.y = rotation_y
		block.add_to_group(&"soft")
	_scatter(&"HayBlock", bales, true)

func stack_bales(center: Vector3, yaw: float, count: int) -> void:
	if count == 1:
		_hay_bale(center, yaw)
		return
	var side := Vector3.BACK.rotated(Vector3.UP, yaw)
	for shift: float in [-0.7, 0.7]:
		_hay_bale(center+side*shift, yaw)
	# 上捆靠兩個下捆承托；方位沿用收割時的裝車方向。
	if count == 3:
		_hay_bale(center+Vector3.UP*sqrt(3.0)*HAY_BALE_R, yaw)

func field_bank(spec: Array) -> void:
	# 橫斷面約四公尺寬，兩端與兩肩收回可行走田面。
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = spec[2]
	var height: float = spec[4]
	var previous := PackedVector3Array()
	var colors := [Color("#9d8969"), Color("#aa976d"), Color("#aa9b71"), Color("#938260")]
	for i in 9:
		var t := i / 8.0
		var scale_h := smoothstep(0.0, 0.23, t) * smoothstep(0.0, 0.23, 1.0-t)
		var crown := height*scale_h*(0.91+0.09*sin(4.7*t))
		var spine := 0.19*sin(7.0*t)
		var row := PackedVector3Array()
		for pair in [[-2.0,-0.08],[-0.43,crown*0.9],[0.24,crown],[0.77,crown*0.79],[1.95,-0.08]]:
			row.append(Vector3((t-0.5)*length, pair[1], spine+float(pair[0])))
		if i:
			for k in 4:
				for v in [previous[k],row[k],row[k+1], previous[k],row[k+1],previous[k+1]]:
					mesh.set_color(colors[k])
					mesh.add_vertex(v)
		previous=row
	mesh.generate_normals()
	var surface:=MeshInstance3D.new()
	surface.mesh=mesh.commit()
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=1.0
	surface.material_override=mat
	var bank:=StaticBody3D.new()
	bank.add_to_group(&"ground")
	bank.collision_layer=1 | FLOOR_LAYER | Fighter.SOLID_LAYER
	bank.position=Vector3(spec[0],0,spec[1])
	bank.rotation.y=-deg_to_rad(spec[3])
	bank.add_child(surface)
	var shape:=CollisionShape3D.new()
	shape.shape=surface.mesh.create_trimesh_shape()
	bank.add_child(shape)
	add_child(bank)
