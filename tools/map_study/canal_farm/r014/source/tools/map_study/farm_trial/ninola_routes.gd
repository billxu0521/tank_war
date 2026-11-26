extends SceneTree
## 從四席初生點實走到箱旁或箱房門外，再原路回來。空間查詢只負責找候選路線。
const FARM := preload("res://tools/map_study/farm_trial/farm.tscn")
const BOSS := preload("res://boss.tscn")
const COWBOY := preload("res://cowboy/cowboy.tscn")
const TARGETS := [Vector2(42.5,-14), Vector2(28,34), Vector2(-35,34), Vector2(-36,-21)]
const NAMES := ["東堤", "秤房", "果場", "發薪房"]
var farm
var boss
var shape_query := PhysicsShapeQueryParameters3D.new()
var space: PhysicsDirectSpaceState3D
var issues: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func xz(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

func pair(p: Vector2) -> Array:
	return [snappedf(p.x,.01),snappedf(p.y,.01)]

func fit(p: Vector2) -> bool:
	var floor_sample: Dictionary = farm.floor_hit(p.x,p.y)
	if floor_sample.is_empty(): return false
	shape_query.transform.origin = floor_sample.position + Vector3.UP*(boss.HALF_H+.12)
	return space.intersect_shape(shape_query,1).is_empty()

func clear_segment(a: Vector2,b: Vector2) -> bool:
	var n := maxi(1,ceili(a.distance_to(b)/.35))
	for i in range(n+1):
		if not fit(a.lerp(b,float(i)/n)): return false
	return true

func route(target: Vector2, cowboy: CharacterBody3D) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-40,-40,81,81)
	grid.cell_size = Vector2(2,2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var ends: Array[Vector2i] = []
	for x in range(-40,41):
		for z in range(-40,41):
			var cell := Vector2i(x,z)
			var p := Vector2(cell)*2
			var passable := fit(p)
			grid.set_point_solid(cell,not passable)
			var distance := p.distance_to(target)
			if not passable or distance < boss.BODY_RADIUS+.45 or distance > boss.BODY_RADIUS+boss.LIGHT_REACH-.2:
				continue
			var ground: Vector3 = farm.floor_hit(p.x,p.y).position
			var ray := PhysicsRayQueryParameters3D.create(ground+Vector3.UP*(boss.HALF_H+boss.HEAD_HEIGHT*boss.GROW),cowboy.global_position+Vector3.UP)
			ray.exclude=[boss.get_rid(),cowboy.get_rid()]
			if space.intersect_ray(ray).is_empty(): ends.append(cell)
	var start := Vector2i((xz(farm.dino_spawn)/2).round())
	if grid.is_point_solid(start): return PackedVector2Array()
	var best := PackedVector2Array()
	var best_length := INF
	for end in ends:
		var path := grid.get_point_path(start,end)
		if path.is_empty(): continue
		var length := 0.0
		for i in range(1,path.size()): length+=path[i].distance_to(path[i-1])
		if length < best_length:
			best=path
			best_length=length
	var smooth := PackedVector2Array()
	if best.is_empty(): return smooth
	smooth.append(best[0])
	var i := 0
	while i < best.size()-1:
		var next := best.size()-1
		while next>i and not clear_segment(best[i],best[next]): next-=1
		if next==i: return PackedVector2Array()
		smooth.append(best[next])
		i=next
	return smooth

func walk(points: PackedVector2Array) -> Dictionary:
	var dt:=1.0/Engine.physics_ticks_per_second
	var ticks:=0
	var distance:=0.0
	var ground_ticks:=0
	var trace := [pair(xz(boss.position))]
	for i in range(1,points.size()):
		var arrived:=false
		var budget:=ceili((xz(boss.position).distance_to(points[i])/boss.WALK*1.5+3.0)/dt)
		for k in budget:
			await physics_frame
			var before:=xz(boss.position)
			var left:=points[i]-before
			if left.length()<.16:
				arrived=true
				break
			var dir:=left.normalized()
			boss._move(Vector3(dir.x,0,dir.y),false,dt)
			distance+=before.distance_to(xz(boss.position))
			ticks+=1
			if boss.is_on_floor(): ground_ticks+=1
			if ticks%120==0: trace.append(pair(xz(boss.position)))
		if not arrived:
			return {"arrived":false,"stopped_xz":pair(xz(boss.position)),"next_xz":pair(points[i]),"trace":trace}
	trace.append(pair(xz(boss.position)))
	return {"arrived":true,"walk_m":snappedf(distance,.01),"simulation_s":snappedf(ticks*dt,.01),"ground_ticks":ground_ticks,"ticks":ticks,"trace":trace}

func run() -> void:
	farm=FARM.instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	space=farm.get_world_3d().direct_space_state
	var game=preload("res://main.gd").new()
	game.map=farm
	boss=BOSS.instantiate()
	boss.name="Boss"
	boss.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	boss.process_mode=Node.PROCESS_MODE_DISABLED
	boss.position=game.boss_on_ground(farm.dino_spawn)
	farm.add_child(boss)
	game.free()
	var origin: Vector3=boss.position
	var capsule: CapsuleShape3D=boss.get_node("CollisionShape3D").shape
	shape_query.shape=capsule
	shape_query.collision_mask=boss.collision_mask
	shape_query.exclude=[boss.get_rid()]
	shape_query.transform=boss.get_node("CollisionShape3D").global_transform
	var origin_clear:=space.intersect_shape(shape_query,1).is_empty()
	if not origin_clear: issues.append("中央初生位置無法容納尼諾拉")
	var result:={"radius_m":capsule.radius,"height_m":capsule.height,"mask":boss.collision_mask,"walk_speed":boss.WALK,"spawn_y":origin.y,"spawn_clear":origin_clear,"runs":[]}
	var safe:=Safe.new()
	farm.add_child(safe)
	safe.set_physics_process(false)
	for j in TARGETS.size():
		boss.position=origin
		boss.velocity=Vector3.ZERO
		safe.reset(true,2)
		safe.place(farm._on_ground(farm.safe_spots[j]+Vector3.UP*Safe.HALF))
		safe.freeze=true
		await physics_frame
		await physics_frame
		var target:Vector2=TARGETS[j]
		var clear_person:bool=farm._is_clear(target)
		var cowboy:=COWBOY.instantiate() as CharacterBody3D
		cowboy.name="1001"
		cowboy.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		cowboy.process_mode=Node.PROCESS_MODE_DISABLED
		cowboy.position=farm.floor_hit(target.x,target.y).position+Vector3.UP*.02
		farm.add_child(cowboy)
		await physics_frame
		var points:=route(target,cowboy)
		var row:={"box":j,"place":NAMES[j],"person_xz":pair(target),"person_clear":clear_person,"waypoints":[]}
		for p in points: row.waypoints.append(pair(p))
		if not points.is_empty():
			row.outbound=await walk(points)
			boss.look_at(Vector3(target.x,boss.position.y,target.y))
			row.driver_can_bite=boss.can_bite(cowboy)
			row.person_distance_m=snappedf(xz(boss.position).distance_to(target),.01)
			if row.outbound.arrived:
				points.reverse()
				row.inbound=await walk(points)
		if not clear_person or not row.get("driver_can_bite",false) or not row.get("inbound",{}).get("arrived",false):
			issues.append(NAMES[j])
		result.runs.append(row)
		cowboy.free()
		await physics_frame
	result.issues=issues
	print("NINOLA ",JSON.stringify(result))
	farm.free()
	quit(0 if issues.is_empty() else 1)
