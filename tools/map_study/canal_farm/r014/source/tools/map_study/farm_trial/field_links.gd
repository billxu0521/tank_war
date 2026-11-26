extends "res://tools/map_study/farm_trial/full_a.gd"

const MARGINS := preload("res://tools/map_study/farm_trial/field_links.json")

func _ready() -> void:
	super()
	for entry: Array in MARGINS.data:
		var center := Vector3(entry[1], 0, entry[2])
		var yaw := deg_to_rad(float(entry[4]))
		var axis := Vector3.RIGHT.rotated(Vector3.UP, yaw)
		match entry[3]:
			"grain":
				stack_bales(center, yaw, 3)
				stack_bales(center + axis * 2.65, yaw + 0.09, 1)
			"wood":
				make_lumber(center, yaw, entry[0])
			"stone":
				field_stone(&"Rock02", center, yaw, .88)
				field_stone(&"Rock04", center + axis * 2.55, yaw + .65, .49)
			"logs":
				var size := Vector3(1.4,1.18,1.1)
				var body := _solid_mesh(_on_ground(center),_props[&"LogPile"],size)
				body.rotation.y=yaw
				body.collision_layer |= Fighter.SOLID_LAYER
				_prop(&"LogPile",Vector3.ZERO,size,body)
			"halfgrain":
				stack_bales(center,yaw,2)
				stack_bales(center+axis*2.05,yaw+.12,1)
			"lowbank":
				var p := Vector2(center.x,center.z)
				var d := Vector2(axis.x,axis.z)*2.55
				make_shoulder(p-d,p+d,1.14)
				get_child(-1).name=entry[0]
			"trees":
				_tree({"pos":center, "mesh":&"TreeOakM", "s":1.0, "yaw":yaw})
				_tree({"pos":center+axis*3.55, "mesh":&"TreeOakS", "s":.88, "yaw":yaw+.4})
			"ridge":
				var p := Vector2(center.x, center.z)
				var d := Vector2(axis.x, axis.z) * 2.8
				make_shoulder(p-d, p+d, 1.83)
				get_child(-1).name = entry[0]
	tint_field()
	for spur: Array in [
		[Vector2(65,-59),Vector2(66,-55),Vector2(69,-50),Vector2(71,-46)],
		[Vector2(71,-22),Vector2(73,-23),Vector2(75,-25)],
		[Vector2(57,12),Vector2(54.5,14),Vector2(53.5,17),Vector2(53,19.5)],
		[Vector2(59,27),Vector2(58,28),Vector2(57,31)],
		[Vector2(-27,49),Vector2(-26,53),Vector2(-24,57),Vector2(-24,58.5)]
	]:
		wagon_spur(spur)

func wagon_spur(points: Array) -> void:
	# 土色雙轍接回原農路，接近裝載處收窄。兩轍只傳達行進方向。
	for wheel: float in [-.77,.77]:
		var line := []
		for i in points.size():
			var direction: Vector2=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
			line.append(points[i]+direction.normalized().orthogonal()*wheel)
		make_track(line,.13)
		var track := get_child(-1) as MeshInstance3D
		track.material_override=soil_material(Color("#897353"))

func field_stone(kind: StringName, center: Vector3, yaw: float, factor: float) -> void:
	var size := Vector3.ONE * factor
	var body := _solid_mesh(_on_ground(center) + Vector3.DOWN*.13, _props[kind], size)
	body.rotation.y = yaw
	body.collision_layer |= Fighter.SOLID_LAYER
	_prop(kind, Vector3.ZERO, size, body)

# 場邊待用板材。從低垛端可以看向下一段，高垛端可遮住站立牛仔。
func make_lumber(center: Vector3, yaw: float, label: String) -> void:
	var rack := Node3D.new()
	rack.name = label
	add_child(rack)
	rack.position = _on_ground(center)
	rack.rotation.y = yaw
	var wood := soil_material(Color("#96704c"))
	var ends := soil_material(Color("#72553b"))
	for spec in [[-.6,4.0,8],[2.1,1.34,4]]:
		var height := .2 + int(spec[2])*.23
		var body := _solid_box(Vector3.ZERO, Vector3(spec[1],height,1.55))
		body.reparent(rack, false)
		body.position = Vector3(spec[0], height*.5, 0)
		body.collision_layer |= Fighter.SOLID_LAYER
		for tier in int(spec[2]):
			var board := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(spec[1], .21, 1.51)
			mesh.material = wood if tier%3 else ends
			board.mesh = mesh
			board.position = Vector3(spec[0]+.045*sin(tier), .305+tier*.23, 0)
			rack.add_child(board)
		for offset in [-.32,.32]:
			var foot := MeshInstance3D.new()
			var block := BoxMesh.new()
			block.size = Vector3(.22,.2,1.55)
			block.material = ends
			foot.mesh = block
			foot.position = Vector3(spec[0]+spec[1]*offset,.10,0)
			rack.add_child(foot)

func tint_field() -> void:
	var ground := get_node("FarmShell/場地剖切與渠床") as MeshInstance3D
	for i in ground.mesh.get_surface_count():
		var mat := ground.get_active_material(i) as StandardMaterial3D
		if mat and mat.resource_name == "田間地表與農路":
			var soil := mat.duplicate() as StandardMaterial3D
			soil.albedo_color = Color("#ac9876")
			ground.set_surface_override_material(i,soil)
