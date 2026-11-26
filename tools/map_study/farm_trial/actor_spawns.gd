extends RefCounted
## 出生只認農莊實際地表。台面、樓面保留給遊戲中的行走與互動。
const TERRAIN_LAYER := 1 << 17
const COWBOY_LIFT := 0.08
const BOSS := preload("res://boss.gd")

static func terrain(map: ArenaMap, at: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x,24,at.z),Vector3(at.x,-8,at.z),TERRAIN_LAYER)
	return map.get_world_3d().direct_space_state.intersect_ray(ray)

static func floor_at(map: ArenaMap, at: Vector3, radius: float) -> Vector3:
	if not map._inside(at,radius + 0.5):
		return Vector3.INF
	var center := terrain(map,at)
	if center.is_empty() or center.position.y < -0.50:
		return Vector3.INF
	var top: float = center.position.y
	var low := top
	for i in 8:
		# 整軸取樣時消除三角函數殘差，避免射線僅偏出地表三角形接縫幾奈米。
		var direction := Vector3.RIGHT.rotated(Vector3.UP,TAU * i / 8.0).snappedf(0.00001).normalized()
		var hit := terrain(map,at + direction * radius)
		if hit.is_empty():
			return Vector3.INF
		top = maxf(top,hit.position.y)
		low = minf(low,hit.position.y)
	if top - low > 0.45 or low < -0.50:
		return Vector3.INF
	return Vector3(at.x,top,at.z)

static func candidate(map: ArenaMap, at: Vector3, big: bool, actor: CollisionObject3D = null) -> Vector3:
	var radius: float = BOSS.BODY_RADIUS if big else 0.4
	var height: float = 2.0 * BOSS.HALF_H if big else 1.8
	var ground := floor_at(map,at,radius)
	if not ground.is_finite():
		return Vector3.INF
	# 圓柱包住完整角色膠囊，也為腳邊及頭側預留轉身空間。
	var shape := CylinderShape3D.new()
	shape.height = height
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | Fighter.SOLID_LAYER
	if is_instance_valid(actor):
		query.exclude = [actor.get_rid()]
	var lift: float = BOSS.LIFT - BOSS.HALF_H if big else COWBOY_LIFT
	query.transform.origin = ground + Vector3.UP * (height * 0.5 + lift)
	var space := map.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty():
		return Vector3.INF
	# 至少能沿其中一個方向走出一個身位，並能在走出的地點落腳。
	for i in 8:
		var move := Vector3.RIGHT.rotated(Vector3.UP,TAU*i/8.0) * maxf(1.2,radius*2.0)
		var end := floor_at(map,at+move,radius)
		if not end.is_finite() or absf(end.y-ground.y) > 0.45:
			continue
		var middle := floor_at(map,at+move*0.5,radius)
		if not middle.is_finite() or absf(middle.y - (end.y+ground.y)*0.5) > 0.35:
			continue
		move.y = end.y-ground.y
		query.motion = move
		if space.cast_motion(query)[0] >= 0.999:
			return ground
	return Vector3.INF

static func nearest(map: ArenaMap, wanted: Vector3, big: bool, actor: CollisionObject3D = null) -> Vector3:
	var point := candidate(map,wanted,big,actor)
	if point.is_finite():
		return point
	var stride: float = BOSS.BODY_RADIUS if big else 1.25
	# 先留在原出生區，逐圈改試鄰近位置。
	for ring in range(1,7):
		var count := ring * 8
		for i in count:
			var offset := Vector3.RIGHT.rotated(Vector3.UP,TAU*i/count)*ring*stride
			point = candidate(map,wanted+offset,big,actor)
			if point.is_finite():
				return point
	# 原區整片封住時，繼續檢查場內其他落點。
	var edge := floori(map.ARENA * 0.5) - 8
	for z in range(-edge,edge+1,8):
		for x in range(-edge,edge+1,8):
			point = candidate(map,Vector3(x,0,z),big,actor)
			if point.is_finite():
				return point
	push_error("農莊找不到角色可站立及走出的出生位置。")
	return Vector3.INF
