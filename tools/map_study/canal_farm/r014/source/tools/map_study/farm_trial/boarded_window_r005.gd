extends "res://tools/map_study/farm_trial/building_walk_r004.gd"
## 正式火球擊碎實圖封板；同一批碎件落定後，從兩面空手／帶蛋檢查實際角色通路。
var detail := {}
var registry: Node
var dragon: Node3D

func ticks(n:int) -> void:
	for i in n: await physics_frame

func overlaps(query: PhysicsShapeQueryParameters3D) -> Array:
	var hits := []
	for hit in site.get_world_3d().direct_space_state.intersect_shape(query,40):
		var obj: Node=hit.collider
		var desc:= obj.get_class()+":"+str(game.map.get_path_to(obj))
		if not hits.has(desc): hits.append(desc)
	return hits

func traverse_window(center: Vector3,normal: Vector3,side: float,egg: bool) -> Dictionary:
	actor.global_position=site.to_global(center+normal*side*.89)+Vector3.UP*.06
	actor.velocity=Vector3.ZERO
	actor.rotation.y=atan2((site.global_basis*normal).x*side,(site.global_basis*normal).z*side)
	actor.reset_physics_interpolation()
	game.egg.carrier=1 if egg else 0
	game.egg.exits=0
	await ticks(35)
	var begin:=site.to_local(actor.global_position)
	var took_off:=false
	var overlap_during: Array=[]
	var follows:=true
	var shape:=CapsuleShape3D.new()
	shape.radius=actor._capsule.radius-actor.safe_margin
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=actor.collision_mask
	query.exclude=[actor.get_rid()]
	var in_opening: Dictionary={}
	shape.height=actor.crouch_height-actor.safe_margin*2.
	for dist:float in [-.55,-.25,0.0,.25,.55]:
		var p:=site.to_global(center+normal*dist+Vector3.UP*1.53)
		query.transform=Transform3D(Basis.IDENTITY,p)
		in_opening[str(dist)]=overlaps(query)
	Input.action_press("move_forward")
	for i in 115:
		if i==2: Input.action_press("jump")
		if i==5: Input.action_release("jump")
		if i==16: Input.action_release("move_forward")
		await physics_frame
		if actor.vaulting:
			took_off=true
			shape.height=actor._capsule.height-2.*actor.safe_margin
			query.transform=actor._collision.global_transform
			for name_ in overlaps(query):
				if not overlap_during.has(name_): overlap_during.append(name_)
		if egg:
			game._egg_step(1./Engine.physics_ticks_per_second)
			follows=follows and game.egg.carrier==1 and game.egg.global_position.distance_to(actor.global_position+Vector3.UP*game.EGG_HOLD_HEIGHT)<.02
	var end:=site.to_local(actor.global_position)
	return {"通過":(end-center).dot(normal)*side<-.35 and actor.is_on_floor(),"起跳翻越":took_off,
		"起點":point(begin),"落腳":point(end),"沿窗面五點的縮身碰撞":in_opening,"翻越時身體重疊":overlap_during,"持蛋跟隨":follows if egg else null}


func window(wall: String) -> void:
	var key:="FarmBuildings004/ExtraHouse1/"+wall+"SecuredShutter"
	var native: Node3D=game.map.get_node(key)
	var part: Dictionary=registry.entries[key]
	var actual: CollisionShape3D=native.get_node("Solid")
	var pane:=site.to_local(actual.global_position)
	var center:=Vector3(pane.x,0,pane.z)
	var normal:=Vector3.BACK if wall=="WallS" else (Vector3.RIGHT if wall=="WallE" else Vector3.LEFT)
	var origin:=site.to_global(pane+normal*1.8)
	var toward:Vector3=-(site.global_basis*normal)
	var times:=0
	while native.is_visible_in_tree() and times < int(part.limit)+2:
		dragon._spit_fire(toward,origin)
		times+=1
		await ticks(12)
	if native.is_visible_in_tree(): failures.append(wall+" 火球未打掉封板")
	await ticks(330)
	for egg:bool in [false,true]:
		for side:float in [-1.,1.]:
			var label:=wall+("持蛋" if egg else "空手")+("內出" if side<0 else "外入")
			var result:=await traverse_window(center,normal,side,egg)
			result["局部窗心"]=point(pane)
			result["命中火球數"]=times
			detail[label]=result
			if not result["通過"] or not result["翻越時身體重疊"].is_empty() or (egg and not result["持蛋跟隨"]):
				failures.append(label)
	registry.restore_all()
	await ticks(5)
	if not native.is_visible_in_tree(): failures.append(wall+" 重建未回復窗板")
	for egg:bool in [false,true]:
		for side:float in [-1.,1.]:
			var label:=wall+"重建"+("持蛋" if egg else "空手")+("內出" if side<0 else "外入")
			var result:=await traverse_window(center,normal,side,egg)
			result["局部窗心"]=point(pane)
			detail[label]=result
			if result["起跳翻越"] or result["通過"] or (egg and not result["持蛋跟隨"]): failures.append(label)


func run() -> void:
	seed(241125)
	game=load("res://farm_match.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await ticks(2)
	game._on_vs_bots_pressed()
	game.rules=&"normal"
	game.normal_rounds=1
	game.room.dino_pick=-1
	game.start_match()
	game.set_physics_process(false)
	game.party.step(0.)
	game.party.step(game.party.PREP_SECONDS+.1)
	actor=game.players.get_node("1")
	for candidate in get_nodes_in_group(&"dino"):
		if candidate.has_method("_spit_fire"):
			dragon=candidate
			break
	if not dragon:
		dragon=load("res://boss.tscn").instantiate()
		dragon.position=Vector3(100,25,100)
		game.map.add_child(dragon)
	dragon.set_physics_process(false)
	dragon.set_process(false)
	for n in game.players.get_children():
		if n!=actor:
			n.set_physics_process(false)
			n.set_process(false)
	site=game.map.get_node("FarmBuildings31/House1")
	registry=game.map.get_node("FarmDestruction")
	for wall:String in ["WallE","WallS","WallW"]:
		await window(wall)
	if detail.size()!=24: failures.append("三窗、兩向、兩種持有狀態未全部執行")
	var out:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	out.store_string(JSON.stringify({"物理頻率":Engine.physics_ticks_per_second,"落件後等待幀":330,"實測":detail,"問題":failures},"  "))
	out.close()
	print("封板正式破壞實走 ",failures)
	quit(int(not failures.is_empty()))
