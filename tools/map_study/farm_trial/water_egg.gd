extends "res://tools/map_study/farm_trial/canal_sections.gd"
## 檢查持蛋者在渠內或橋的上下層消失時，正式掉蛋、拾取與圈內計時落在哪裡。
var game
var person
var body_mesh:AABB
var water_y:float
var records:={}

class RoundProbe extends Party:
	var finish_id:=0

	func extracted(id:int) -> void:
		finish_id=id

func expect(ok:bool,message:String) -> void:
	if not ok: issues.append(message)

func position_values(p:Vector3) -> Array:
	return [snappedf(p.x,.01),snappedf(p.y,.01),snappedf(p.z,.01)]

func make_person(at:Vector3,id:int,duck:bool,required:bool=true) -> bool:
	person=COWBOY.instantiate()
	person.process_mode=Node.PROCESS_MODE_DISABLED
	person.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	person.name=str(id)
	person.position=at+Vector3.UP*.025
	game.players.add_child(person)
	var dt:=1.0/Engine.physics_ticks_per_second
	if duck: person._apply_crouch(true,1.)
	for tick in 45:
		await physics_frame
		person.velocity+=person.get_gravity()*dt
		person._move_flat(Vector3.ZERO,dt)
	var stable:bool=person.is_on_floor() and person.position.distance_to(at)<.35
	if required: expect(stable,"角色未在指定地面站穩 "+str(at))
	return stable

func walk_to_x(finish:float,speed:float) -> bool:
	var dt:=1.0/Engine.physics_ticks_per_second
	for tick in ceili((absf(person.position.x-finish)/speed+3.)/dt):
		await physics_frame
		var dx:float=finish-person.position.x
		if absf(dx)<.07:
			return person.is_on_floor()
		person.velocity+=person.get_gravity()*dt
		person._move_flat(Vector3(signf(dx)*speed,0,0),dt)
	return false

func surface_or_bed(p:Vector2,low:bool) -> Vector3:
	return Vector3(p.x,bed(p.x,p.y) if low else farm.floor_hit(p.x,p.y).position.y,p.y)

func try_pick(at:Vector3,crouch:bool) -> Dictionary:
	await make_person(at,3,crouch)
	game._claimer=0
	game.egg.carrier=0
	game.egg.pickup=0
	var q:=PhysicsRayQueryParameters3D.create(person.position+Vector3.UP*(.85 if crouch else 1.55),game.egg.position)
	q.exclude=[person.get_rid()]
	var hit:Dictionary=space.intersect_ray(q)
	var seconds:float=game.pickup_seconds()
	for i in ceili(seconds*Engine.physics_ticks_per_second)+1:
		game._claim_step(1./Engine.physics_ticks_per_second)
		if game.egg.carrier==3: break
	var result:={"feet":position_values(person.position),"picked":game.egg.carrier==3,"solid_between":str(farm.get_path_to(hit.collider)) if hit else ""}
	person.free()
	return result

func test_place(label:String,feet:Vector2,under:bool,walk_under:bool,second_pick:Dictionary={},approach_x:float=-6.) -> void:
	var initial:=Vector2(approach_x,feet.y) if walk_under else feet
	await make_person(surface_or_bed(initial,under),2,walk_under)
	var walked:bool=await walk_to_x(feet.x,person.crouch_speed) if walk_under else true
	expect(walked and (not walk_under or person.position.y<-.8),"未能到達 "+label)
	var holder:Vector3=person.position
	var west:int=farm.get_node("Anchors/ExitCandidates/West").get_index()
	var north:int=farm.get_node("Anchors/ExitCandidates/North").get_index()
	var south:int=farm.get_node("Anchors/ExitCandidates/South").get_index()
	game.egg.carrier=2
	game.egg.exits=(1<<west)|(1<<south)
	game._egg_step(.25)
	var west_active:float=game.egg.extract
	var dt:=1.0/Engine.physics_ticks_per_second
	game.party.finish_id=0
	game.egg.extract=0.0
	for i in ceili(game.extract_seconds()/dt)+2:
		game._egg_step(dt)
		if game.party.finish_id: break
	var west_finished:bool=game.party.finish_id==2
	game.egg.exits=(1<<north)|(1<<south)
	game._egg_step(.25)
	var west_inactive:float=game.egg.extract
	person.hp=0
	game.party._drop_orphan_egg()
	expect(game.egg.carrier==0 and is_zero_approx(game.egg.extract),"掉落未重置 "+label)
	var drop:Vector3=game.egg.position
	var r:={"feet":position_values(holder),"drop":position_values(drop),"supported_walk":walked,"render_top_y":snappedf(drop.y+body_mesh.end.y,.01),
		"west_water_at_xz":water_at(drop.x,drop.z),"west_active_timer":west_active,"west_inactive_timer":west_inactive,"west_finish_called":west_finished}
	person.free()
	r.same_side=await try_pick(holder,walk_under)
	if second_pick:
		var pick_at:=surface_or_bed(second_pick.xz,second_pick.low)
		r.other_side=await try_pick(pick_at,second_pick.low)
	expect(r.same_side.picked,"同地角色未撿回 "+label)
	records[label]=r

func bridge_approaches() -> Dictionary:
	var paths:=[]
	var best:={}
	for z in [11.5,12.,12.5,13.,13.5,14.,14.5]:
		for start in [-6.,14.]:
			var stable:=await make_person(surface_or_bed(Vector2(start,z),true),3,true,false)
			if not stable:
				paths.append({"start_x":start,"start_z":z,"stable_start":false,"center":false})
				person.free()
				continue
			var reached_center:=await walk_to_x(4.,person.crouch_speed)
			var p:Vector3=person.position
			var cover:Dictionary=farm.floor_hit(p.x,p.z)
			var sheltered:bool=person.is_on_floor() and p.y < -1.0 and cover.get("collider")==farm.get_node("FarmCanalWorks/CenterBridge/Span/Surface")
			paths.append({"start_x":start,"start_z":z,"end":position_values(p),"stable_start":true,"center":reached_center,"under_deck":sheltered})
			if reached_center and sheltered and best.is_empty() and absf(p.z-z)<.12:
				best={"start":start,"z":z,"x":4.}
			person.free()
	return {"approaches":paths,"best":best}

## 比較三個圈心覆蓋的深渠。只有滿足蛋頂低於水片的樣點才算；不改動正式點位。
func west_options() -> Dictionary:
	var out:={}
	var deep:={}
	# 共享的半公尺樣格。完全淹沒才計，取樣範圍涵蓋下方全部候選圓。
	for i in range(-164,-82):
		for j in range(-56,80):
			var p:=Vector2(i,j)*.5
			if bed(p.x,p.y)+.5+body_mesh.end.y<water_y and water_at(p.x,p.y):
				deep[Vector2i(i,j)]=true
	var original:=Vector2(-62,0)
	var best:=original
	var best_count:=999999
	var eligible:=0
	for x in range(-6,7):
		for z in range(-6,7):
			var shift:=Vector2(x,z)
			var center:=original+shift
			if shift.length()>6 or center.distance_to(Vector2(-62,-4))>=farm.EXIT_RADIUS or center.distance_to(Vector2(-62,12))>=farm.EXIT_RADIUS:
				continue
			eligible+=1
			var count:=0
			for cell:Vector2i in deep:
				if center.distance_squared_to(Vector2(cell)*.5)<farm.EXIT_RADIUS*farm.EXIT_RADIUS: count+=1
			if count<best_count or (count==best_count and shift.length()<best.distance_to(original)):
				best=center
				best_count=count
	for option in [["原位",original],["北移",Vector2(-62,-14)],["南移",Vector2(-62,25)],["兩岸保留微調",best]]:
		var center:Vector2=option[1]
		var submerged:=0
		var within:=0
		for i in range(-27,28):
			for j in range(-27,28):
				var offset:=Vector2(i,j)*.5
				if offset.length()>=farm.EXIT_RADIUS: continue
				var p:=center+offset
				within+=1
				if deep.has(Vector2i((p*2).round())):
					submerged+=1
		var known:={}
		for mark in [["果場側南岸",Vector2(-62,12)],["北岸巡渠路",Vector2(-62,-4)],["深渠樣點",Vector2(-72,6.4)]]:
			known[mark[0]]=center.distance_to(mark[1])<farm.EXIT_RADIUS
		var to_boxes:=[]
		for box:Vector3 in farm.safe_spots:
			to_boxes.append(snappedf(maxf(0,center.distance_to(Vector2(box.x,box.z))-farm.EXIT_RADIUS),.1))
		out[option[0]]={"center":[center.x,center.y],"grid_samples":within,"submerged_samples":submerged,"submerged_area_approx_m2":submerged*.25,"in_ring":known,"direct_box_to_ring_m":to_boxes}
	out["兩岸保留微調"].eligible_centers=eligible
	return out

func carry_to_west(line:Array,center:Vector2) -> Dictionary:
	var west:int=farm.get_node("Anchors/ExitCandidates/West").get_index()
	var saved:Vector3=farm._exits[west]
	farm._exits[west]=Vector3(center.x,0,center.y)
	await make_person(surface_or_bed(Vector2(line[0][0],line[0][1]),false),2,false)
	game.egg.exits=(1<<west)|(1<<farm.get_node("Anchors/ExitCandidates/South").get_index())
	game.egg.carrier=2
	game.egg.extract=0.
	game.party.finish_id=0
	var dt:=1./Engine.physics_ticks_per_second
	var elapsed:=0.
	var distance:=0.
	var lowest:float=person.position.y
	var arrival:={}
	var reached_count:=0
	for i in range(1,line.size()):
		var goal:=Vector2(line[i][0],line[i][1])
		var start:=Vector2(person.position.x,person.position.z)
		var reached:=false
		for tick in ceili((start.distance_to(goal)/person.walk_speed+3.)/dt):
			await physics_frame
			var before:Vector3=person.position
			var delta:=goal-Vector2(before.x,before.z)
			if delta.length()<.085:
				reached=true
				break
			person.velocity+=person.get_gravity()*dt
			person._move_flat(Vector3(delta.x,0,delta.y).normalized()*person.walk_speed,dt)
			game._egg_step(dt)
			elapsed+=dt
			distance+=Vector2(person.position.x-before.x,person.position.z-before.z).length()
			lowest=minf(lowest,person.position.y)
			if game.egg.extract>0 and arrival.is_empty():
				arrival={"at":position_values(person.position),"elapsed_s":snappedf(elapsed,.01),"walked_m":snappedf(distance,.01)}
		if not reached: break
		reached_count+=1
	# 停在同一條已驗乾路上，確認站穩後也能結束撤離計時。
	for tick in ceili((game.extract_seconds()+.2)/dt):
		await physics_frame
		person.velocity+=person.get_gravity()*dt
		person._move_flat(Vector3.ZERO,dt)
		game._egg_step(dt)
		if game.party.finish_id: break
	var r:={"entry":arrival,"finished":game.party.finish_id==2,"waypoints_reached":reached_count,"waypoints_requested":line.size()-1,"lowest_foot_y":snappedf(lowest,.01),"end":position_values(person.position)}
	expect(not arrival.is_empty() and r.finished and lowest>-.06 and reached_count==line.size()-1,"乾路持蛋進西圈 "+str(center))
	person.free()
	farm._exits[west]=saved
	return r

func run() -> void:
	farm=FARM.instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	space=farm.get_world_3d().direct_space_state
	terrain_query=PhysicsRayQueryParameters3D.create(Vector3.ZERO,Vector3.DOWN,farm.FLOOR_LAYER)
	var water:=farm.get_node("WestBank").find_child("Water",true,false) as MeshInstance3D
	water_faces=water.global_transform*water.mesh.get_faces()
	water_y=water_faces[0].y
	body_mesh=farm._props[&"Egg"].get_aabb()
	game=preload("res://main.gd").new()
	game.map=farm
	game.players=Node3D.new()
	farm.add_child(game.players)
	game.egg=Egg.new()
	farm.add_child(game.egg)
	game.egg.set_physics_process(false)
	game.safe=Safe.new()
	farm.add_child(game.safe)
	game.safe.set_physics_process(false)
	game.safe.reset(true,2)
	game.safe.open=true
	game.party=RoundProbe.new()
	game.party.main=game
	await test_place("西灘",Vector2(-47,6),false,false)
	await test_place("西圈深渠",Vector2(-72,6.4),true,false,{"xz":Vector2(-72,2.1),"low":false})
	await test_place("西圈南岸",Vector2(-62,12),false,false)
	await test_place("東堤",Vector2(51,-7),false,false)
	var bridge:=await bridge_approaches()
	if not bridge.best.is_empty():
		var spot:=Vector2(bridge.best.x,bridge.best.z)
		await test_place("橋上",spot,false,false,{"xz":spot,"low":true})
		await test_place("橋下",spot,true,true,{"xz":spot,"low":false},bridge.best.start)
	else:
		await test_place("橋上",Vector2(4,13),false,false)
	var alternatives:=west_options()
	var dry:={}
	for label in ["原位","兩岸保留微調"]:
		var q:Array=alternatives[label].center
		var center:=Vector2(q[0],q[1])
		dry[label]={"果場南岸":await carry_to_west(preload("res://tools/map_study/farm_trial/orchard_paths.json").data["西"],center),
			"北岸巡渠路":await carry_to_west([[-76,-13],[-74,-8],[-70,-4],[-62,-4]],center)}
	print("WATER_EGG ",JSON.stringify({"bounds":position_values(body_mesh.size),"water_y":water_y,"pickup_range":game.pickup_range(),"pickup_s":game.pickup_seconds(),"extract_s":game.extract_seconds(),"bridge":bridge,"sites":records,"west_options":alternatives,"dry_approaches":dry,"issues":issues}))
	game.party.free()
	game.party=null
	game.free()
	farm.free()
	quit(0 if issues.is_empty() else 1)
