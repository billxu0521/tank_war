extends SceneTree
## 只放置一次牛仔；其後以正式控制器的輸入做連續往返。
const MAP := preload("res://tools/map_study/farm_trial/farm.tscn")
const COWBOY := preload("res://cowboy/cowboy.tscn")
const POCKET := Vector3(-63,0,-70)
var farm
var player
var site:Node3D
var out_path:String
var failure:=false

func _initialize() -> void:
	run.call_deferred()

func pos(p:Vector3) -> Array:
	return [snappedf(p.x,.001),snappedf(p.y,.001),snappedf(p.z,.001)]

func local_point(x:float,z:float) -> Vector3:
	return site.to_global(Vector3(x,0,z))

func release_keys() -> void:
	for key in ["move_forward","crouch","jump"]:
		Input.action_release(key)

func settle(ticks:int) -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")
	for j in ticks: await physics_frame

func leg(goal:Vector3, jump_z:float=INF, crouch:=false) -> Dictionary:
	var peak:float=player.position.y
	var vaulted:=false
	var jumped:=false
	var was_airborne:=false
	var start:Vector3=player.position
	var direction:=signf(site.to_local(goal).z-site.to_local(start).z)
	var takeoff:Array=[]
	if crouch: Input.action_press("crouch")
	else: Input.action_release("crouch")
	var on_target:=false
	var hz:=Engine.physics_ticks_per_second
	for tick in ceili((3.+goal.distance_to(start)/player.crouch_speed)*hz):
		var delta:Vector3=goal-player.position
		delta.y=0
		var speed:=Vector2(player.velocity.x,player.velocity.z).length()
		if delta.length()<.07 and speed<.9 and not player.vaulting and player.is_on_floor():
			on_target=true
			break
		if delta.length()>.07:
			player.rotation.y=atan2(-delta.x,-delta.z)
		if delta.length()>.045 and (speed<.50 or speed*speed < 1.20*player.ground_accel*delta.length()):
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		var z:=site.to_local(player.position).z
		if not jumped and is_finite(jump_z) and direction*(z-jump_z)>=0 and player.is_on_floor():
			Input.action_press("move_forward")
			Input.action_press("jump")
			jumped=true
			takeoff=pos(player.position)
		else:
			Input.action_release("jump")
		await physics_frame
		peak=maxf(peak,player.position.y)
		vaulted=vaulted or player.vaulting
		was_airborne=was_airborne or not player.is_on_floor()
	await settle(28)
	var dist:=Vector2(player.position.x-goal.x,player.position.z-goal.z).length()
	return {"reached":on_target and dist<.19 and player.is_on_floor() and absf(player.position.y)<.06,
		"start":pos(start),"aim":pos(goal),"stop":pos(player.position),"jump_pressed":jumped,
		"takeoff":takeoff,"vault":vaulted,"airborne":was_airborne,"peak_m":snappedf(peak,.001),
		"grounded":player.is_on_floor(),"speed_end":snappedf(player.velocity.length(),.01)}

func trial(mode:String, lane:float, trigger:float) -> Dictionary:
	release_keys()
	player=COWBOY.instantiate()
	player.name="1"
	# 無視窗驗移動時不播放音效，避免加速重跑離場後音訊播放物件仍佔用裝置。
	for sound in ["StepSound","JumpSound","LandSound"]:
		player.get_node(sound).stream=null
	var outside:=local_point(lane,-3.15)
	var spawn:Vector3=farm.get_node("Anchors/InitialSpawns/NW").global_position
	player.position=farm.floor_hit(spawn.x,spawn.z).position+Vector3.UP*.02
	farm.add_child(player)
	await settle(25)
	assert(player.is_local and player.is_on_floor())
	var corner:=local_point(-3.70,-3.15)
	var leave_spawn:=await leg(corner)
	var stage:=await leg(outside)
	var crossing:=mode=="jump"
	var crouch:=mode=="crouch"
	var inner:=local_point(lane,.83)
	var enter:=await leg(inner,-trigger if crossing else INF,crouch)
	var journey:={"mode":mode,"lane_local_x":lane,"jump_distance":trigger,"from_spawn":leave_spawn,"stage":stage,"enter":enter}
	if enter.reached:
		journey.pocket=await leg(POCKET)
		if journey.pocket.reached:
			journey.align_exit=await leg(inner)
			if journey.align_exit.reached:
				journey.exit=await leg(outside,trigger if crossing else INF,crouch)
	release_keys()
	player.free()
	await physics_frame
	journey.complete=leave_spawn.reached and stage.reached and journey.get("exit",{}).get("reached",false)
	return journey

func run() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--out="): out_path=s.trim_prefix("--out=")
	if out_path.is_empty():
		quit(2)
		return
	farm=MAP.instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	site=farm.get_node("NorthwestWagonShed")
	var all:=[]
	for mode in ["walk","crouch"]:
		all.append(await trial(mode,1.50,.75))
	for sample in [[1.50,.75],[1.35,.65],[1.70,.85]]:
		all.append(await trial("jump",sample[0],sample[1]))
	var passes:=0
	for record in all:
		if not record.from_spawn.reached or not record.stage.reached: failure=true
		if record.mode=="jump":
			if record.complete and record.enter.jump_pressed and record.exit.jump_pressed and record.enter.airborne and record.exit.airborne and not record.enter.vault and not record.exit.vault:
				passes+=1
		elif record.enter.reached: failure=true
	var ok:=passes==3 and not failure
	var f:=FileAccess.open(out_path,FileAccess.WRITE)
	f.store_line(JSON.stringify({"site":site.scene_file_path,"location":pos(POCKET),"runs":all,"passed_jump_round_trips":passes,
		"physics_hz":Engine.physics_ticks_per_second,"round_trip":ok},"  "))
	f.close()
	print("POCKET_WALK ",ok," ",all.size())
	farm.queue_free()
	for i in 6: await process_frame
	quit(0 if ok else 1)
