extends SceneTree
## 兩棟各用相同車口起訖，正式角色橫穿、室外繞行、走樓梯換出口，並從原路返回。
## 每條路徑只在起始處定位一次；過門、登樓、折返、量時都由實際物理幀及前進鍵完成。
const LEVEL := 3.06
const SITES := preload("res://levels/farm_sites/sites.gd")
var game
var actor: Cowboy
var site: Node3D
var stats := {}
var sites_used := {}
var failures: Array[String] = []
var moving_ticks := 0
var distance := 0.0
var carry_ok := true
var carried := false
var highest := 0.0
var contacts: Array[String] = []
var waypoints := []
var first_sight := {}
var destination: Vector3

func _initialize() -> void:
	run.call_deferred()

func ground(x: float,z: float) -> Vector3: return Vector3(x,0,z)
func middle(x: float,z: float) -> Vector3: return Vector3(x,LEVEL,z)
func at_turn(x: float,z: float) -> Vector3: return Vector3(x,1.44,z)
func point(p: Vector3) -> Array: return [snappedf(p.x,.01),snappedf(p.y,.01),snappedf(p.z,.01)]

func exterior_feet(x: float,z: float) -> Vector3:
	var flat := site.to_global(ground(x,z))
	var ray := PhysicsRayQueryParameters3D.create(flat+Vector3.UP*1.7,flat+Vector3.DOWN*2.0,1,[actor.get_rid()])
	var hit := site.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty(), "戶外路線缺少地面")
	return site.to_local(hit.position)

func paths(grain: bool) -> Dictionary:
	var start := ground(-2,2)
	var end := ground(14,2)
	var direct := [start,end]
	# 兩棟低翼外各有一株原樹，從樹幹外緣通過，仍回到相同的另一端車口。
	var outside := [start,exterior_feet(-2,-3.85),exterior_feet(14,-3.85),end]
	if grain:
		var a := [ground(5.04,9),middle(10.99,9)]
		var c_down := [middle(4.38,6.48),at_turn(.84,6.48),at_turn(.84,5.02),ground(4.48,5.02)]
		var to_a := [start,ground(4.9,2),ground(4.9,8.03)]
		var upper := to_a+a+[middle(10.99,7.42),middle(4.38,7.42)]+c_down+[ground(4.72,2),end]
		# B 到三樓機頭後必須折返，再沿 A 回到起點。
		var top := to_a+a+[middle(10.99,10.55),Vector3(5.05,2*LEVEL,10.55),Vector3(5.05,2*LEVEL,8.25)]
		return {"一樓穿越":direct,"室外繞行":outside,"A上C下":upper,"B梯往返頭輪層":top}
	var upper := [start,ground(3.35,2),ground(3.35,5.62),ground(.88,5.62),ground(.88,6.65),
		middle(7.06,6.65),middle(7.57,6.86),at_turn(11.00,6.86),at_turn(11.00,5.02),ground(7.40,5.02),
		ground(7.35,2),end]
	return {"一樓穿越":direct,"室外繞行":outside,"D上E下":upper}


func progress_tick() -> void:
	var before := actor.global_position
	await physics_frame
	var after := actor.global_position
	moving_ticks += 1
	distance += before.distance_to(after)
	highest = maxf(highest,site.to_local(after).y)
	if carried:
		game._egg_step(1.0/Engine.physics_ticks_per_second)
		carry_ok = carry_ok and game.egg.carrier==1 and game.egg.global_position.distance_to(after+Vector3.UP*game.EGG_HOLD_HEIGHT)<.02
	if first_sight.is_empty() and moving_ticks % 3 == 0:
		var ray := PhysicsRayQueryParameters3D.create(after+Vector3.UP*1.55,destination+Vector3.UP*1.55,1,[actor.get_rid()])
		if actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			first_sight={"出發後秒":snappedf(float(moving_ticks)/Engine.physics_ticks_per_second,.01),"所在局部座標":point(site.to_local(after))}


func walk(p: Vector3) -> bool:
	var target := site.to_global(p)
	var from := actor.global_position
	for i in ceili((from.distance_to(target)/actor.walk_speed+1.8)*Engine.physics_ticks_per_second):
		var delta := target - actor.global_position
		delta.y=0.0
		if delta.length()<.12 and actor.is_on_floor() and absf(actor.global_position.y-target.y)<.32:
			waypoints.append(point(site.to_local(actor.global_position)))
			return true
		if delta.length()>.035:
			actor.rotation.y=atan2(-delta.x,-delta.z)
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		await progress_tick()
	contacts.clear()
	for i in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(i)
		if collision.get_collider() is Node:
			contacts.append(str(site.get_path_to(collision.get_collider())))
	print("卡點 ",site.name," ",point(site.to_local(actor.global_position))," 目標 ",point(p)," 接觸 ",contacts)
	return false


func traverse(label: String, route: Array) -> bool:
	moving_ticks=0
	distance=0.0
	highest=site.to_local(actor.global_position).y
	carry_ok=true
	first_sight={}
	contacts=[]
	waypoints=[]
	destination=site.to_global(route.back())
	var ok:=true
	for i in range(1,route.size()):
		if not await walk(route[i]):
			ok=false
			break
	Input.action_release("move_forward")
	stats[label]={"通過":ok and carry_ok,"起點":point(route.front()),"預定終點":point(route.back()),
		"實際終點":point(site.to_local(actor.global_position)),"行走秒":snappedf(float(moving_ticks)/Engine.physics_ticks_per_second,.01),
		"實走公尺":snappedf(distance,.01),"最高高度":snappedf(highest,.01),"逐點腳底":waypoints,
		"接觸構件":contacts,"持蛋跟隨":carry_ok if carried else null,"首次與終點眼高無阻擋":first_sight}
	if not ok or not carry_ok: failures.append(label)
	return ok and carry_ok


func trial(label: String, route: Array) -> void:
	actor.global_position=site.to_global(route.front())+Vector3.UP*.16
	actor.velocity=Vector3.ZERO
	actor.reset_physics_interpolation()
	game.egg.carrier=1 if carried else 0
	game.egg.exits=0
	for i in 30: await physics_frame
	if await traverse(label+" 去",route):
		var reversed:=route.duplicate()
		reversed.reverse()
		await traverse(label+" 回",reversed)
	else: failures.append(label+" 回（去程中止）")


func run() -> void:
	seed(240031)
	game=load("res://farm_match.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await physics_frame
	await physics_frame
	game._on_vs_bots_pressed()
	game.rules=&"normal"
	game.normal_rounds=1
	game.room.dino_pick=-1
	game.start_match()
	game.set_physics_process(false)
	game.party.step(0.)
	game.party.step(game.party.PREP_SECONDS+.1)
	actor=game.players.get_node("1")
	for canvas in game.find_children("*","CanvasLayer",true,false):
		canvas.visible=false
	for n in game.players.get_children():
		if n!=actor:
			n.set_physics_process(false)
			n.set_process(false)
	var args := OS.get_cmdline_user_args()
	for id in ["GrainTransfer","WheelShop"]:
		site=game.map.get_node_or_null("FarmBuildings004/"+id)
		if not site:
			failures.append(id+" 缺建築")
			continue
		if args.size()>1 and args[1]!=id: continue
		var placement: Dictionary = SITES.GRAIN if id=="GrainTransfer" else SITES.REPAIR
		var target_transform := SITES.placement(placement)
		if not site.global_transform.is_equal_approx(target_transform): failures.append(id+" 地圖場址有異")
		var size: Vector2 = placement.size
		sites_used[id]=point(site.to_global(ground(size.x/2.,size.y/2.)))
		var options:=paths(id=="GrainTransfer")
		for has_egg in [false,true]:
			carried=has_egg
			for label:String in options:
				await trial(id+" "+label+(" 持蛋" if carried else " 空手"),options[label])
	var out:=FileAccess.open(args[0],FileAccess.WRITE)
	out.store_string(JSON.stringify({"建築中心世界座標":sites_used,"測例":stats,"問題":failures,"時間基準":Engine.physics_ticks_per_second},"  "))
	out.close()
	print("兩棟實走 ",stats.size()," ",failures)
	quit(int(not failures.is_empty()))
