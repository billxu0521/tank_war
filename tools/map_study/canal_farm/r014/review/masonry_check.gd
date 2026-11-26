extends SceneTree
var game
var farm:Node3D
var reg
var site:Node3D
var report:={}
var failures:Array=[]
var prefix:=""
func _initialize(): run.call_deferred()
func wait_frames(n:int):
	for i in n:await physics_frame
func verify(label:String,ok:bool):
	if not ok:failures.append(label)
func alive(key:String)->bool:
	var e:Dictionary=reg.entries[prefix+key]
	return reg.health.get(prefix+key,e.limit)>0 and e.native.is_visible_in_tree() and e.shapes.any(func(s):return not s[0].disabled)
func ray(a:Vector3,b:Vector3,mask:int=1)->Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(site.to_global(a),site.to_global(b),mask)
	return site.get_world_3d().direct_space_state.intersect_ray(q)
func aim(a:Vector3,b:Vector3)->String:
	var hit:=ray(a,b)
	if hit.is_empty():return ""
	return reg.key_at(hit.collider,hit.shape)
func shoot(key:String,a:Vector3,b:Vector3,count:int):
	for i in count:
		var hit:=ray(a,b)
		if hit.is_empty() or reg.key_at(hit.collider,hit.shape)!=prefix+key:
			failures.append(key+" 命中位置")
			return
		reg.projectile(hit.collider,hit.shape,hit.position)
func park():
	for p in game.players.get_children():
		p.set_physics_process(false)
		p.set_process(false)
		p.global_position=Vector3(85,10,76)
func new_round():
	var id:int=game.players.get_node("1").get_instance_id()
	await game._new_round()
	park()
	await wait_frames(7)
	verify("新角色已生成",id!=game.players.get_node("1").get_instance_id())
func loss(label:String,key:String,a:Vector3,b:Vector3,fall:Array,stay:Array):
	var limit:int=reg.entries[prefix+key].limit
	verify(label+" 耐久",limit==6 if reg.entries[prefix+key].family=="frame" else limit==2)
	shoot(key,a,b,limit-1)
	verify(label+" 未到耐久",alive(key))
	shoot(key,a,b,1)
	await wait_frames(5)
	var post:={}
	for name:String in fall+stay:
		post[name]=alive(name)
		verify(label+"/"+name,post[name]==(name in stay))
	var home:ToyBuild=reg.fragments.homes[reg.entries[prefix+key].debris_site]
	verify(label+" 碎落",home.has_damage() and not home.loose_ids().is_empty())
	var rendered := []
	for id in home.loose_ids():
		var piece = home._pieces[id]
		for view in piece.find_children("*","MeshInstance3D",false,false):
			var original = site.get_node_or_null(NodePath(str(view.name)+"/StockAssembly"))
			if original and view.mesh == original.mesh and view.get_active_material(0) == original.get_active_material(0) and view.is_visible_in_tree():
				rendered.append(str(view.name))
	for expected in fall:
		verify(label+" 散落原件 "+expected,expected in rendered)
	var after:=aim(a,b)
	verify(label+" 命中點已清",after!=prefix+key)
	report[label]={"target":prefix+key,"hits":limit,"rendered":rendered,"after":post,"ray_after":after,"loose":home.loose_ids().size()}
	await new_round()
	for name:String in fall+stay:verify(label+" 復原 "+name,alive(name))
	verify(label+" 接觸復原",aim(a,b)==prefix+key)
	verify(label+" 清理碎塊",not home.has_damage())
func run():
	var args:=OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate()
	root.add_child(game);current_scene=game
	await wait_frames(3)
	game._on_vs_bots_pressed();game.rules=&"normal";game.normal_rounds=150;game.room.dino_pick=-1
	game.start_match();game.set_physics_process(false);game.party.step(0.);game.party.step(game.party.PREP_SECONDS+.1)
	farm=game.map;reg=farm.get_node("FarmDestruction")
	park()
	await wait_frames(12)
	await loading()
	report.errors=failures
	report.graph_errors=reg.support_graph.errors
	var f:=FileAccess.open(args[0],FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("農務構件 ",failures)
	var cleanup := Time.get_ticks_msec() + 1800
	while Time.get_ticks_msec() < cleanup:
		OS.delay_msec(5)
		await process_frame
	quit(int(not failures.is_empty() or not reg.support_graph.errors.is_empty()))

func loading():
	var sites := ["FarmShell/西南田埂石垛/Masonry","FarmCanalWorks/WheelSeat/BearingAssembly"]
	var control = reg.entries["FarmCanalWorks/NorthWall"] if reg.entries.has("FarmCanalWorks/NorthWall") else {}
	if control.is_empty():
		for part in reg.entries.values():
			if part.family == "brick" and part.native != null and not part.native.has_meta("original_debris_mesh"):
				control = part
				break
	for index in 2:
		site=farm.get_node(sites[index])
		prefix=sites[index]+"/"
		verify("構件數",site.get_child_count()==[51,61][index])
		for body in site.get_children():
			var key=prefix+str(body.name)
			if not reg.entries.has(key):
				failures.append(key+" 未登記");continue
			var part=reg.entries[key]
			verify(key+" 磚材與碎件",part.limit==control.limit and reg.fragments.material(part)==&"brick" and part.debris_end==part.debris_start+1)
			var grounded = body.name in ["Heap01","Heap02","Heap03","Heap04","Heap05","Heap06","Heap07","Heap08"] or (str(body.name).begins_with("Seat") and str(body.name).trim_prefix("Seat").to_int()<6)
			verify(key+" 承座",reg.support_graph.anchors.has(key)==grounded)
		if index==0:
			await loss("田埂頂層端石","Heap43",Vector3(-3.75,2.10,2.0),Vector3(-3.75,2.10,-1.9),["Heap43"],["Heap44","Heap35","Heap01"])
			await loss("田埂底石","Heap01",Vector3(-3.75,.19,2.0),Vector3(-3.75,.19,-1.9),["Heap01","Heap09"],["Heap10","Heap02","Heap51"])
		else:
			await loss("西側軸墩壓枕","Seat41",Vector3(-1.96,2.53,1.4),Vector3(-1.96,2.53,.8),["Seat41","Seat50","Seat51","Seat52","Seat53"],["Seat39","Seat49","Seat54"])
			await loss("底台邊石","Seat25",Vector3(-2.75,1.14,2.3),Vector3(-2.75,1.14,-2.1),["Seat25"],["Seat26","Seat24","Seat32"])
		var boss=game._boss()
		boss.global_position=site.to_global(Vector3(-2.65,boss.HALF_H,4.8))
		boss.global_basis=site.global_basis.orthonormalized()
		reg.strike(boss,true)
		await wait_frames(4)
		var missing=site.get_children().filter(func(n):return not alive(str(n.name))).size()
		report["咬擊"+str(index)]=missing
		verify("尼諾拉咬擊局部掉件",missing>0 and missing<site.get_child_count())
		await new_round()
