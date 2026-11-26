extends ArenaMap
## 地圖獨立入口。專案的四席規則可直接讀本圖的候選點、地形與通行查詢。
const ROW := preload("res://levels/canal_orchard/fruit_row.tscn")
const FIELD_PLAN := preload("res://tools/map_study/farm_trial/fields.json")
const ACTOR_SPAWNS := preload("res://tools/map_study/farm_trial/actor_spawns.gd")
const FLOOR_LAYER := 1 << 16
const EXIT_GROUND_LAYER := preload("res://levels/ranch_surface/surface.gd").DECAL_LAYER
const SUPPLIES := [Vector3(-11,0,-43), Vector3(6,0,52)]
var floor_body: StaticBody3D
var standing := CapsuleShape3D.new()

func _ready() -> void:
	for old: String in ["FarmShell/裝車臺", "FarmShell/西坡", "FarmShell/東坡", "LocalGeometry/YardProp2_1", "FarmShell/南草料垛", "FarmShell/北集乳站"]:
		get_node(old).free()
	solidify_placeholders()
	floor_body = $"FarmShell/場地剖切與渠床".find_children("*", "StaticBody3D", true, false)[0]
	floor_body.collision_layer |= FLOOR_LAYER | ACTOR_SPAWNS.TERRAIN_LAYER
	floor_body.add_to_group(&"ground")
	var bridge: StaticBody3D = $"FarmShell/中橋通過面".find_children("*", "StaticBody3D", true, false)[0]
	bridge.collision_layer |= FLOOR_LAYER
	$LoadingStation/Platform.collision_layer |= FLOOR_LAYER
	_load_props()
	# 本圖的固定農務設施設在標高 0 的作業面。動態抽點於物理世界就緒後取實際渠床高度。
	plant_fruit()
	build_milk_station()
	build_hay_yard()
	for p: Vector3 in SUPPLIES:
		var box := _kit(&"Crate", p, 0.15)
		box.add_to_group(&"farm_supply")
	for mark in $Anchors/SafeCandidates.get_children():
		safe_spots.append(mark.position)
	for mark in $Anchors/InitialSpawns.get_children():
		if mark.kind == "spawn":
			spawn_points.append(mark.position)
		else:
			dino_spawn = mark.position
	for mark in $Anchors/ExitCandidates.get_children():
		var pad := _add_exit_at(mark.position)
		pad.cull_mask = EXIT_GROUND_LAYER
	$"FarmShell/場地剖切與渠床".layers |= EXIT_GROUND_LAYER
	show_exits(0)
	build_boundary()

func solidify_placeholders() -> void:
	# 只有封閉的背景量體可轉成實心。兩間箱房的獨立屋頂、可走的渡點和地形保留原碰撞。
	const SOLIDS := ["西灘閘具房","橋西水車機座","橋東閘板棚","南橋頭車材垛","東堤量水房",
		"東卸料車架","果場空箱垛","秤棚外飼料垛","西北農車棚","東工班料垛","南農具棚",
		"西北木料垛","東北防風土垣","東南卸車棚","西南田埂石垛"]
	for item in $FarmShell.get_children():
		if item is MeshInstance3D and (item.name.begins_with("農舍 ") or item.name.begins_with("護牆 ") or String(item.name) in SOLIDS):
			var shapes := item.find_children("*","CollisionShape3D",true,false)
			assert(shapes.size()==1)
			shapes[0].shape = item.mesh.create_convex_shape()

func plant_fruit() -> void:
	for offset: Vector3 in [Vector3.ZERO, Vector3(4.9384,0,-0.7822)]:
		var row := ROW.instantiate()
		add_child(row)
		row.position = offset
		for marker: LevelItem in row.get_children():
			_tree(marker.to_record())
		row.free()

func build_milk_station() -> void:
	var shed := StaticBody3D.new()
	shed.name = "MilkStation"
	add_child(shed)
	shed.position = Vector3(-6,0,-47)
	shed.rotation.y = deg_to_rad(12)
	# 收貨棚沿用現有屋頂與木柱；四面留通，不把內建草料垛一併帶到集乳站。
	var roof: Mesh = _props[&"BarnRoof"]
	var limits := roof.get_aabb()
	var fit := Vector3(5.2,0.85,6.2) / limits.size
	var offset := Vector3(0,2.4,0) - (limits.position + Vector3(limits.size.x/2,0,limits.size.z/2)) * fit
	_prop(&"BarnRoof", offset, fit, shed)
	var cover := CollisionShape3D.new()
	var ceiling := ConvexPolygonShape3D.new()
	var faces := roof.get_faces()
	for i in faces.size():
		faces[i] = faces[i] * fit + offset
	ceiling.points = faces
	cover.shape = ceiling
	shed.add_child(cover)
	var timber: Mesh = _props[&"FencePost"]
	var timber_fit := Vector3(0.19,2.45,0.19)/timber.get_aabb().size
	for x in [-2.25,2.25]:
		for z in [-2.7,2.7]:
			var foot := Vector3(x,0,z)
			_prop(&"FencePost",foot - timber.get_aabb().get_center()*timber_fit + Vector3.UP*1.225,timber_fit,shed)
			var post := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.19,2.45,0.19)
			post.shape = shape
			post.position = foot+Vector3.UP*1.225
			shed.add_child(post)
	var wagon := _prop(&"Wagon", Vector3(-11.8,0,-47.2))
	wagon.rotation.y = deg_to_rad(78)
	wagon.create_trimesh_collision()
	place_milk_furniture(shed)
	var signboard := Label3D.new()
	signboard.text = "MILK RECEIVING"
	signboard.position = Vector3(0,2.25,3.03)
	signboard.pixel_size = 0.006
	signboard.font_size = 48
	signboard.outline_size = 6
	shed.add_child(signboard)

func place_milk_furniture(_shed: Node3D) -> void:
	for p: Vector3 in [Vector3(-8.6,0,-43.5),Vector3(-7.6,0,-43.3)]:
		_kit(&"Barrel", p, 0.2)

func build_hay_yard() -> void:
	var center := Vector3(-5,0,57)
	var angle := deg_to_rad(-17)
	var pieces: Array[Transform3D] = []
	for column in 5:
		for row in 5:
			var tiers := 3 if column == 4 else (4 if row == 4 else 5)
			for tier in tiers:
				var offset := Vector3((column-2)*1.12,tier*HAY_BLOCK.y,(row-2)*0.60)
				pieces.append(Transform3D(Basis(Vector3.UP,angle), center + offset.rotated(Vector3.UP,angle)))
	_scatter(&"HayBlock", pieces, true)
	for region: Array in [[-0.56,-0.30,4,4,5],[-0.56,1.2,4,1,4],[2.24,0.0,1,5,3]]:
		var size := Vector3(region[2]*1.12-0.02,region[4]*HAY_BLOCK.y,region[3]*0.60-0.05)
		var p := center + Vector3(region[0],size.y/2,region[1]).rotated(Vector3.UP,angle)
		var body := _solid_box(p,size)
		body.rotation.y = angle
		body.add_to_group(&"soft")
	_hay_bale(Vector3(-1.4,0,59), angle)

func build_boundary() -> void:
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for i in 4:
		var turn := Basis(Vector3.UP,i*PI/2)
		var wall := _solid_box(turn*Vector3(0,18,-86), Vector3(172,44,4) if i%2==0 else Vector3(4,44,172))
		wall.add_to_group(&"arena_wall")
		for j in 68:
			var pos := turn*Vector3(-83.75+j*FENCE_SEG,0,-83.9)
			var h := floor_hit(pos.x,pos.z)
			if i == 3:
				# 東乾渠下切處只在岸頂立柱，逐跨檢查兩根柱子之間的坡面。
				if h.is_empty() or h.position.y < -0.10:
					continue
				pos.y = h.position.y
				posts.append(Transform3D(turn,pos))
				if j == 67:
					continue
				var supported := true
				for sample in [0.25,0.5,0.75,1.0]:
					var surface := floor_hit(pos.x,pos.z + FENCE_SEG*float(sample))
					if surface.is_empty() or surface.position.y < -0.10:
						supported = false
						break
				if supported:
					rails.append(Transform3D(turn,pos + turn*Vector3(FENCE_SEG/2.0,0,0)))
				continue
			if not h.is_empty() and h.position.y < -0.8:
				continue
			posts.append(Transform3D(turn,pos))
			rails.append(Transform3D(turn,pos+turn*Vector3(1.25,0,0)))
	_scatter(&"FencePost",posts,true)
	_scatter(&"FenceRail",rails,true)

func floor_hit(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x,8,z), Vector3(x,-5,z), FLOOR_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _on_ground(point: Vector3) -> Vector3:
	var hit := floor_hit(point.x,point.z)
	return point + Vector3.UP * (float(hit.position.y) if not hit.is_empty() else 0.0)

func _is_clear(at: Vector2, extra := 0.0) -> bool:
	if not super._is_clear(at, extra):
		return false
	var hit := floor_hit(at.x,at.y)
	if hit.is_empty() or hit.position.y < -0.50 or not _inside(hit.position, 0.5 + extra):
		return false
	standing.radius = 0.4 + extra
	standing.height = maxf(1.8,standing.radius*2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform.origin = hit.position + Vector3.UP*(standing.height/2+0.045)
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func farm_spawn_candidate(at: Vector3, big: bool, actor: CollisionObject3D = null) -> Vector3:
	return ACTOR_SPAWNS.candidate(self, at, big, actor)

func farm_nearest_spawn(at: Vector3, big: bool, actor: CollisionObject3D = null) -> Vector3:
	var floor_point: Vector3 = ACTOR_SPAWNS.nearest(self, at, big, actor)
	return floor_point + Vector3.UP * (ACTOR_SPAWNS.BOSS.LIFT if big else ACTOR_SPAWNS.COWBOY_LIFT)
