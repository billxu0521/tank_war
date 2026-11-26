extends SceneTree
## 實走東南棚斜向作業空隙與第三返場落點之間的往返。
const FARM := preload("res://tools/map_study/farm_trial/farm.tscn")
const COWBOY := preload("res://cowboy/cowboy.tscn")
const LINE := [Vector2(63,70),Vector2(63.1,68.55),Vector2(64,66)]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var farm := FARM.instantiate()
	root.add_child(farm)
	var cowboy = COWBOY.instantiate()
	cowboy.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	cowboy.process_mode = Node.PROCESS_MODE_DISABLED
	farm.add_child(cowboy)
	await physics_frame
	await physics_frame
	cowboy.global_position = farm.floor_hit(LINE[0].x,LINE[0].y).position+Vector3.UP*.02
	var dt := 1./Engine.physics_ticks_per_second
	var results := []
	var issues := []
	for target: Vector2 in [LINE[1],LINE[2],LINE[1],LINE[0]]:
		var error_m := INF
		for tick in 480:
			await physics_frame
			var here: Vector3 = cowboy.global_position
			var gap := Vector3(target.x-here.x,0,target.y-here.z)
			cowboy.velocity += cowboy.get_gravity()*dt
			cowboy._move_flat(gap.normalized()*minf(2.,gap.length()*6.),dt)
			error_m = gap.length()
			if cowboy.is_on_floor() and error_m < .04: break
		results.append(snappedf(error_m,.001))
		if error_m >= .04: issues.append(target)
	print("SHED_PASSAGE ",JSON.stringify({"miss_m":results,"failed_points":issues}))
	farm.free()
	quit(0 if issues.is_empty() else 1)
