extends SceneTree
## 以一公尺格、四向鄰接查可達性。相鄰格加查中點，不能對角穿牆。
const MAP := preload("res://tools/map_study/farm_trial/farm.tscn")
const FIXTURE := preload("res://tools/map_study/canal_farm/east_levee_cases.json")
var farm
var reached := {}
var failed := []
var grid := {}
var height := {}
var space: PhysicsDirectSpaceState3D

func _initialize() -> void:
	run.call_deferred()

func xz(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

func clear_line(a: Vector3,b: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func visit_component() -> void:
	for x in range(-83,84):
		for z in range(-83,84):
			var cell := Vector2i(x,z)
			if farm._is_clear(Vector2(cell)):
				grid[cell]=true
				height[cell]=farm.floor_hit(x,z).position.y
	var start := Vector2i(xz(farm.spawn_points[0]))
	var queue: Array[Vector2i]=[start]
	reached[start]=true
	var i := 0
	while i < queue.size():
		var a := queue[i]
		i+=1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var b: Vector2i=a+step
			if reached.has(b) or not grid.has(b) or absf(height[a]-height[b])>0.65:
				continue
			if not farm._is_clear((Vector2(a)+Vector2(b))/2):
				continue
			reached[b]=true
			queue.append(b)

## 新構件內的窄走道可能通得過角色，但兩個相鄰整公尺格不落在同一條線上。
## 僅針對粗格未連通的格點加密，必須實際連回已知區域。
func connects_at_step(start: Vector2i, subdivisions: int) -> bool:
	var origin := start * subdivisions
	var search_radius := 12 * subdivisions
	var queue: Array[Vector2i] = [origin]
	var seen := {origin:true}
	var i := 0
	while i < queue.size():
		var p := queue[i]
		i += 1
		if p.x%subdivisions == 0 and p.y%subdivisions == 0 and reached.has(Vector2i(p.x/subdivisions,p.y/subdivisions)):
			return true
		var a := Vector2(p)/subdivisions
		var ha: float = farm.floor_hit(a.x,a.y).position.y
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = p+d
			if seen.has(next) or next.distance_squared_to(origin)>search_radius*search_radius:
				continue
			var b := Vector2(next)/subdivisions
			if not farm._is_clear(b) or not farm._is_clear((a+b)*0.5):
				continue
			if absf(farm.floor_hit(b.x,b.y).position.y-ha)>0.25:
				continue
			seen[next]=true
			queue.append(next)
	return false

func reachable(p: Vector3) -> bool:
	var near := Vector2i(xz(p).round())
	for dx in range(-1,2):
		for dz in range(-1,2):
			var at := near+Vector2i(dx,dz)
			if reached.has(at) and xz(p).distance_to(Vector2(at))<=1.5:
				var eye := Vector3(at.x,height[at]+0.8,at.y)
				if clear_line(eye, p+Vector3.UP*0.8):
					return true
	return false

func wall_viewpoint() -> Dictionary:
	var start:=Vector2i(38,-25)
	var pick:=Vector3(42.5,1,-14)
	var queue:Array[Vector2i]=[start]
	var distance:={start:0}
	var i:=0
	while i<queue.size():
		var cell:=queue[i]
		i+=1
		var eye:=Vector3(cell.x,height[cell]+1.55,cell.y)
		if clear_line(eye,pick):
			return {"x":cell.x,"z":cell.y,"walk_m":distance[cell]}
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var to:Vector2i=cell+delta
			if reached.has(to) and not distance.has(to) and farm._is_clear((Vector2(cell)+Vector2(to))/2):
				distance[to]=distance[cell]+1
				queue.append(to)
	return {}

func dino_doorways() -> Array:
	var boss_body:=preload("res://boss.tscn").instantiate()
	var source:CollisionShape3D=boss_body.find_children("*","CollisionShape3D",true,false)[0]
	var shape:=source.shape as CapsuleShape3D
	var result:=[]
	# 兩間房各在南門前場設一個假想離場人物，不移動或拆除房屋。
	for f in [[Vector2(29,29),Vector2(28,34)],[Vector2(-41,-27),Vector2(-36,-21)]]:
		var found:=false
		var nearest:=INF
		var best:=Vector2.ZERO
		var person:Vector2=f[1]
		for x in range(int(person.x)-9,int(person.x)+10):
			for z in range(int(person.y)-9,int(person.y)+10):
				var center:=Vector2(x,z)
				if not reached.has(Vector2i(x,z)) or center.distance_to(person)>9: continue
				var q:=PhysicsShapeQueryParameters3D.new()
				q.shape=shape
				q.transform.origin=Vector3(x,height[Vector2i(x,z)]+shape.height/2+0.06,z)
				if not space.intersect_shape(q,1).is_empty(): continue
				var dist:=center.distance_to(person)
				if dist<shape.radius or dist>=nearest: continue
				if clear_line(Vector3(x,height[Vector2i(x,z)]+2.0,z),Vector3(person.x,1,person.y)):
					found=true
					best=center
					nearest=dist
		result.append({"safe":str(f[0]),"exit_person":str(person),"ground_position":str(best),"distance_m":snappedf(nearest,0.01) if found else -1.0})
		if not found: failed.append(str(f[0])+" 門外沒有符合身形的可見位置")
	boss_body.free()
	return result

func orchard_clearance() -> Dictionary:
	var paths:Dictionary=preload("res://tools/map_study/farm_trial/orchard_paths.json").data.duplicate()
	paths["返場"]=[[-56,52],[-53.5,56.3],[-45,56.3],[-38.1,52.2],[-35,47],[-32.5,45.5],[-31.8,43]]
	var blocked:={}
	for key in paths:
		var hits:=0
		var path:Array=paths[key]
		for j in range(1,path.size()):
			var a:=Vector2(path[j-1][0],path[j-1][1])
			var b:=Vector2(path[j][0],path[j][1])
			var n:=ceili(a.distance_to(b)/0.20)
			for k in n+1:
				if not farm._is_clear(a.lerp(b,float(k)/n)): hits+=1
		blocked[key]=hits
		if hits: failed.append(key+" 線")
	return blocked

func run() -> void:
	farm=MAP.instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	space=farm.get_world_3d().direct_space_state
	visit_component()
	for group in ["InitialSpawns","SafeCandidates","ExitCandidates"]:
		for mark in farm.get_node("Anchors/"+group).get_children():
			if not reachable(mark.position): failed.append(str(mark.get_path()))
	for zone in farm.get_node("Anchors/ReturnZones").get_children():
		for mark in zone.get_children():
			if not reachable(mark.position): failed.append(str(mark.get_path()))
	var missing := []
	var narrow := []
	var fine := []
	for cell: Vector2i in grid:
		if reached.has(cell): continue
		if connects_at_step(cell,4):
			narrow.append([cell.x,cell.y])
		elif connects_at_step(cell,20):
			fine.append([cell.x,cell.y])
		else:
			missing.append([cell.x,cell.y])
	var eyes := [Vector3(50,1.55,-14),Vector3(38,1.55,-25)]
	var windows := []
	for s in FIXTURE.data.cases:
		var len_m := 0.0
		var seen: Array=[null,null]
		var old: Array=s.route_xz[0]
		for pt in s.route_xz:
			var a:=Vector2(old[0],old[1])
			var b:=Vector2(pt[0],pt[1])
			var n:=maxi(1,ceili(a.distance_to(b)/0.2))
			for k in range(n+1):
				var q:=a.lerp(b,float(k)/n)
				var floor_info: Dictionary=farm.floor_hit(q.x,q.y)
				if floor_info.is_empty() or not farm._is_clear(q):
					if not failed.has(s.id): failed.append(s.id)
					continue
				for j in eyes.size():
					if seen[j]==null and clear_line(eyes[j],floor_info.position+Vector3.UP):
						seen[j]=snappedf(len_m+a.distance_to(q),0.01)
			len_m+=a.distance_to(b)
			old=pt
		windows.append([s.id,snappedf(len_m,0.01),seen])
	var accessible := {}
	for p in [[-47,6],[4,13],[51,-7],[-56,52],[-31.5,43],[-39,42]]:
		accessible[str(p)]=reachable(farm._on_ground(Vector3(p[0],0,p[1])))
		if not accessible[str(p)]: failed.append(p)
	var corner:=wall_viewpoint()
	if corner.is_empty(): failed.append("北牆換位")
	var dino:=dino_doorways()
	var intact:=orchard_clearance()
	var tree:ToyBuild=farm._toys[1]
	var strike:=tree.center_of(0)
	var near:=func(p:Vector3)->bool:return p.distance_to(strike)<0.12
	tree.smash(near,2,strike-Vector3.RIGHT)
	tree.smash(near,2,strike-Vector3.RIGHT)
	for i in 8*Engine.physics_ticks_per_second: await physics_frame
	if tree.is_standing(0): failed.append("果樹斷幹")
	var broken:=orchard_clearance()
	for stack in farm.get_node("LoadingStation/WorkingCrates").get_children(): stack.apply_mask(0)
	await physics_frame
	await physics_frame
	var open:=clear_line(Vector3(-27,1.55,39),Vector3(-36,.75,35))
	if not open: failed.append("拆筐後箱仍被遮住")
	if not missing.is_empty(): failed.append("有孤立可站格")
	print("CHOICES ",JSON.stringify({"north_wall_first_view":corner,"dinosaur_doorways":dino,"intact_blocked":intact,"broken_blocked":broken,"loading_side_sees_safe_after_crates_removed":open}))
	print("ROUTES ",JSON.stringify({"standable":grid.size(),"reached":reached.size()+narrow.size()+fine.size(),"quarter_step_connections":narrow,"five_cm_connections":fine,"unreachable_examples":missing.slice(0,15),"anchors_or_routes_failed":failed,"crossings_and_work_points":accessible,"east_first_sight_m_from_pickup":windows}))
	for sound in root.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	farm.queue_free()
	await process_frame
	var finish:=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<finish:
		OS.delay_msec(8)
		await process_frame
	quit(0 if failed.is_empty() else 1)
