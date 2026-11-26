extends RefCounted
## 正式擺設的平面占地，同時供小地圖與規則物件選址使用。
const EXISTING := preload("res://levels/farm_buildings_v31/sites.json")
const SITES := preload("res://levels/farm_sites/sites.gd")

static func _mesh_area(room: Node3D, mesh: MeshInstance3D) -> Rect2:
	var box := (room.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

static func _room_area(room) -> Rect2:
	var size := Vector2(room.width, room.depth)
	return Rect2(-size * .5, size)

static func _register(farm: ArenaMap, room: Node3D, area: Rect2, label: String) -> void:
	var center := area.get_center()
	var pos := room.to_global(Vector3(center.x, 0, center.y))
	var x_axis := room.global_basis.x
	# 農莊建物此時已經蓋好。沿用 _put 登錄資料與小地圖，不再次生成模型或碰撞。
	farm._put({"kind": &"barn", "pos": pos, "yaw": -Vector2(x_axis.x,x_axis.z).angle(),
		"size": Vector3(area.size.x, 0, area.size.y), "clearance": 0.0, "farm_site": label})

static func install(farm: ArenaMap) -> void:
	if farm.has_meta(&"farm_building_footprints"): return
	for spec: Array in EXISTING.data:
		var label: String = spec[0]
		var room := farm.get_node("FarmBuildings31/" + label) as Node3D
		match label:
			"House1":
				_register(farm,room,_mesh_area(room,farm.get_node("House1Interior/House/Floor")),label)
			"NorthwestWagonShed","SoutheastUnloadingShed":
				_register(farm,room,_mesh_area(room,farm.get_node(label + "/Frame")),label)
			"RegistrationRoom":
				# 秤房前棚兩跨與清選樓交界各自登錄，保留外側轉車缺口。
				for bay in ["OfficeCanopy","CartCanopy"]:
					var roof: StaticBody3D = room.get_node(bay)
					var collider := roof.find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
					var size: Vector3 = (collider.shape as BoxShape3D).size
					var box := (room.global_transform.affine_inverse()*collider.global_transform) * AABB(-size*.5,size)
					_register(farm,room,Rect2(box.position.x,box.position.z,box.size.x,box.size.z),label)
				var loft := room.get_node("SeedCleaningLoft")
				_register(farm,loft,_room_area(loft),label)
			_:
				_register(farm,room,_room_area(room),label)
	for pair: Array in [["GrainTransfer",SITES.GRAIN],["WheelShop",SITES.REPAIR]]:
		var site := farm.get_node("FarmBuildings004/" + str(pair[0])) as Node3D
		_register(farm,site,Rect2(Vector2.ZERO,pair[1].size),pair[0])
	farm.set_meta(&"farm_building_footprints", true)
