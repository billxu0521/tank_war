extends SceneTree
## 土床、橋面、水片與遊戲角色各自量測。水片僅代表本版看得到的水面。
const FARM := preload("res://tools/map_study/farm_trial/farm.tscn")
const FIELDS := preload("res://levels/farm_environment/plan.json")
const COWBOY := preload("res://cowboy/cowboy.tscn")
const NINOLA := preload("res://boss.tscn")
const CROSSINGS := {"西灘":[-47,-2.5,14.5],"中橋":[4,1,25],"東閘":[51,-19,4]}
var farm
var space: PhysicsDirectSpaceState3D
var terrain_query: PhysicsRayQueryParameters3D
var water_faces: PackedVector3Array
var issues: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func bed(x: float,z: float,original_only: bool=false) -> float:
	terrain_query.from=Vector3(x,9,z)
	terrain_query.to=Vector3(x,-6,z)
	terrain_query.exclude=[]
	var exclude: Array[RID]=[]
	for i in 8:
		var hit:=space.intersect_ray(terrain_query)
		if hit.is_empty(): break
		if hit.collider==farm.floor_body or (not original_only and hit.collider.is_in_group(&"canal_soil")): return hit.position.y
		exclude.append(hit.rid)
		terrain_query.exclude=exclude
	issues.append("缺少渠床或田面 %s" % Vector2(x,z))
	return NAN

func water_at(x: float,z: float) -> bool:
	var q:=Vector2(x,z)
	for i in range(0,water_faces.size(),3):
		var a:=water_faces[i]
		var b:=water_faces[i+1]
		var c:=water_faces[i+2]
		var av:=Vector2(a.x,a.z)
		var bv:=Vector2(b.x,b.z)
		var cv:=Vector2(c.x,c.z)
		var area:=(bv-av).cross(cv-av)
		if absf(area)<.000001: continue
		var u:=(q-av).cross(cv-av)/area
		var v:=(bv-av).cross(q-av)/area
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001: return true
	return false

func sample_profile(x: int,original_only: bool=false) -> Dictionary:
	var low:=INF
	var first:=NAN
	var last:=NAN
	for j in range(-70,71):
		var z:=j*.5
		var height:=bed(x,z,original_only)
		low=minf(low,height)
		if height<-.19:
			if is_nan(first): first=z
			last=z
	if is_nan(first):
		return {"x":x,"lowest_y":snappedf(low,.001),"depressed":false}
	var mid:=(first+last)*.5
	return {"x":x,"north_z":first,"south_z":last,"middle_z":mid,"lowest_y":snappedf(low,.001),"depressed":true,"water_mesh_at_middle":water_at(x,mid)}

func field_levels() -> Array:
	var result:=[]
	for f in FIELDS.data.fields:
		var lo:=INF
		var hi:=-INF
		for u in [-.42,0,.42]:
			for v in [-.42,0,.42]:
				var d:=Vector2(u*f.size[0],v*f.size[1]).rotated(deg_to_rad(f.angle))
				var y:=bed(f.center[0]+d.x,f.center[1]+d.y)
				lo=minf(lo,y)
				hi=maxf(hi,y)
		result.append({"center":f.center,"use":f.use,"min_y":snappedf(lo,.001),"max_y":snappedf(hi,.001)})
	return result

func cross(row: Array,reverse: bool,as_dino: bool) -> Dictionary:
	var actor= NINOLA.instantiate() if as_dino else COWBOY.instantiate()
	var x:float=row[0]
	var start:float=row[2] if reverse else row[1]
	var end:float=row[1] if reverse else row[2]
	var hit:Dictionary=farm.floor_hit(x,start)
	var ahead:=signf(end-start)
	actor.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	actor.process_mode=Node.PROCESS_MODE_DISABLED
	actor.name="Boss" if as_dino else "1001"
	farm.add_child(actor)
	var foot:float=actor.get_node("CollisionShape3D").shape.height*.5-actor.get_node("CollisionShape3D").position.y
	actor.position=hit.position+Vector3.UP*(foot+.03)
	await physics_frame
	var shape:=PhysicsShapeQueryParameters3D.new()
	shape.shape=actor.get_node("CollisionShape3D").shape
	shape.transform=actor.get_node("CollisionShape3D").global_transform
	shape.collision_mask=actor.collision_mask
	shape.exclude=[actor.get_rid()]
	var fit:bool=space.intersect_shape(shape,1).is_empty()
	var dt:=1.0/Engine.physics_ticks_per_second
	var lowest:float=actor.position.y-foot
	var arrived:=false
	var ticks:=0
	var drift:=0.0
	if fit:
		for i in ceili((absf(end-start)/4+5)*Engine.physics_ticks_per_second):
			await physics_frame
			if as_dino: actor._move(Vector3(0,0,ahead),false,dt)
			else:
				actor.velocity+=actor.get_gravity()*dt
				actor._move_flat(Vector3(0,0,ahead)*actor.walk_speed,dt)
			lowest=minf(lowest,actor.position.y-foot)
			drift=maxf(drift,absf(actor.position.x-x))
			ticks+=1
			if ahead*(actor.position.z-end)>=-.035:
				arrived=actor.is_on_floor() and absf(actor.position.y-foot-farm.floor_hit(actor.position.x,actor.position.z).position.y)<.16
				break
	var out:={"spawn_clear":fit,"arrived":arrived,"near_transect":arrived and drift<1.0,"seconds":snappedf(ticks*dt,.01),"min_foot":snappedf(lowest,.01),"drift_x":snappedf(drift,.01),"end_x":snappedf(actor.position.x,.01),"end_z":snappedf(actor.position.z,.01)}
	actor.free()
	await physics_frame
	return out

## 從深段渠底起步，沿床面找鄰近的緩坡上岸。只計地面走通的實際行程。
func escape_from_bed(from_x: int,to_x: int,north: bool,as_dino: bool) -> Dictionary:
	var points:=PackedVector2Array()
	var step:=2*signi(to_x-from_x)
	for x in range(from_x,to_x+step,step):
		var profile:=sample_profile(x,true)
		if not profile.depressed: break
		points.append(Vector2(x,profile.middle_z))
	var last:=points[-1]
	var end_profile:=sample_profile(roundi(last.x),true)
	var desired_bank:float=(end_profile.north_z-5) if north else (end_profile.south_z+5)
	# 東堤兩端削平；先循渠的縱向登上堤，再轉向平坦岸頂。
	if absf(last.x-to_x)>1:
		points.append(Vector2(to_x,last.y))
	points.append(Vector2(to_x,desired_bank))
	if from_x==78:
		points=PackedVector2Array([Vector2(78,-11),Vector2(71,-16.6),Vector2(70.5,-19)])
	var actor= NINOLA.instantiate() if as_dino else COWBOY.instantiate()
	actor.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	actor.process_mode=Node.PROCESS_MODE_DISABLED
	actor.name="Boss" if as_dino else "1001"
	farm.add_child(actor)
	var shape:CollisionShape3D=actor.get_node("CollisionShape3D")
	var foot:float=shape.shape.height*.5-shape.position.y
	actor.position=Vector3(points[0].x,bed(points[0].x,points[0].y)+foot+1.0,points[0].y)
	await physics_frame
	var fit:=PhysicsShapeQueryParameters3D.new()
	fit.shape=shape.shape
	fit.transform=shape.global_transform
	fit.collision_mask=actor.collision_mask
	fit.exclude=[actor.get_rid()]
	var clear_start:=space.intersect_shape(fit,1).is_empty()
	var dt:=1.0/Engine.physics_ticks_per_second
	for tick in Engine.physics_ticks_per_second:
		await physics_frame
		if as_dino: actor._move(Vector3.ZERO,false,dt)
		else:
			actor.velocity+=actor.get_gravity()*dt
			actor._move_flat(Vector3.ZERO,dt)
	var settled:bool=actor.is_on_floor() and actor.position.y-foot < -.8
	var completed:=0
	var ticks:=0
	for i in range(1,points.size()):
		var arrived:=false
		for t in ceili((points[i-1].distance_to(points[i])/4+2.5)/dt):
			await physics_frame
			var delta:=points[i]-Vector2(actor.position.x,actor.position.z)
			if delta.length()<.2:
				arrived=true
				completed=i
				break
			var dir:=Vector3(delta.x,0,delta.y).normalized()
			if as_dino: actor._move(dir,false,dt)
			else:
				actor.velocity+=actor.get_gravity()*dt
				actor._move_flat(dir*actor.walk_speed,dt)
			ticks+=1
		if not arrived: break
	var final_y:=snappedf(actor.position.y-foot,.01)
	var out:={"start_clear":clear_start,"settled_in_channel":settled,"start_xz":[points[0].x,points[0].y],"goal_xz":[points[-1].x,points[-1].y],"last_xz":[snappedf(actor.position.x,.01),snappedf(actor.position.z,.01)],"last_foot_y":final_y,"walked_s":snappedf(ticks*dt,.01),"arrived_on_bank":clear_start and settled and completed==points.size()-1 and absf(final_y)<.1}
	actor.free()
	await physics_frame
	return out

func run() -> void:
	farm=FARM.instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	space=farm.get_world_3d().direct_space_state
	terrain_query=PhysicsRayQueryParameters3D.create(Vector3.ZERO,Vector3.DOWN,farm.FLOOR_LAYER)
	var surface:=farm.get_node("WestBank").find_child("Water",true,false) as MeshInstance3D
	water_faces=surface.global_transform*surface.mesh.get_faces()
	var low:=INF
	var high:=-INF
	for v in water_faces:
		low=minf(low,v.y)
		high=maxf(high,v.y)
	if water_faces.is_empty() or high-low>.01: issues.append("水片缺失或水位不平")
	var result:={"water_y":[snappedf(low,.001),snappedf(high,.001)],"profiles":[],"fields":field_levels(),"field_inlet_options":[],"crossings":{}}
	for x in range(-82,83,2):
		result.profiles.append(sample_profile(x))
	# 比較田四西側兩條試算線。下切量以 0.5% 示意底坡計，並非既有溝體。
	for x in [-77,-72]:
		var section:=sample_profile(x)
		var source_z:float=section.north_z+.5
		var end:=-16.0
		var initial_bed:=low-.08
		var max_cut:=0.0
		var min_circle:=INF
		var inside_length:=0.0
		var length:=source_z-end
		var steps:=ceili(length/.25)
		for i in range(steps+1):
			var t:=float(i)/steps
			var z:=lerpf(source_z,end,t)
			var y:=initial_bed-length*t*.005
			max_cut=maxf(max_cut,bed(x,z)-y)
			var dist:=Vector2(x,z).distance_to(Vector2(farm._exits[1].x,farm._exits[1].z))
			min_circle=minf(min_circle,dist)
			if i<steps and dist < farm.EXIT_RADIUS: inside_length+=length/steps
		result.field_inlet_options.append({"x":x,"source_z":source_z,"source_has_water":water_at(x,source_z),"end_z":end,"length":snappedf(length,.01),"end_invert":snappedf(initial_bed-length*.005,.001),"max_cut":snappedf(max_cut,.001),"nearest_west_exit_center":snappedf(min_circle,.01),"inside_west_ring_m_approx":snappedf(inside_length,.01)})
	var stations:=CROSSINGS.duplicate(true)
	for x in [-72,-42,-24,26,78]:
		var profile:=sample_profile(x)
		var label:="西灘東緣" if x==-42 else "普通渠段 X%d"%x
		stations[label]=[x,profile.north_z-4,profile.south_z+4]
	for tag in stations:
		var row:Array=stations[tag]
		var passes:={}
		for species in ["牛仔","尼諾拉"]:
			for reverse in [false,true]:
				var direction: String="北向" if reverse else "南向"
				var check: Dictionary=await cross(row,reverse,species=="尼諾拉")
				passes[species+direction]=check
				if CROSSINGS.has(tag) and not check.near_transect: issues.append(tag+species+direction)
		result.crossings[tag]={"section":row,"passes":passes}
	result.escape_routes={}
	result.bed_sections={}
	var lines:={"西灘西端":[Vector2(-63,6),Vector2(-52,6)],
		"西灘東端":[Vector2(-30,10.9),Vector2(-42,7.4)],
		"東堤西端":[Vector2(33,2.3),Vector2(46,-4.4)],
		"卸料端北岸":[Vector2(78.5,-10.6),Vector2(70,-17.8)]}
	for label in lines:
		var a:Vector2=lines[label][0]
		var b:Vector2=lines[label][1]
		var samples:=[]
		for i in range(61):
			var p:=a.lerp(b,float(i)/60)
			samples.append([snappedf(a.distance_to(p),.01),snappedf(bed(p.x,p.y),.001)])
		result.bed_sections[label]={"from_xz":[a.x,a.y],"to_xz":[b.x,b.y],"distance_height":samples}
	for entry in [[-72,-46,false],[-24,-46,true],[26,50,true],[78,56,true]]:
		var escape:={}
		for species in ["牛仔","尼諾拉"]:
			escape[species]=await escape_from_bed(entry[0],entry[1],entry[2],species=="尼諾拉")
			if not get_nodes_in_group(&"canal_soil").is_empty() and not escape[species].arrived_on_bank:
				issues.append("回岸 X%d %s"%[entry[0],species])
		result.escape_routes[str(entry[0])]=escape
	result.issues=issues
	print("SECTIONS ",JSON.stringify(result))
	farm.free()
	quit(0 if issues.is_empty() else 1)
