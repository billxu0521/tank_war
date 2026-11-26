extends RefCounted
## 各組以原主石為錨點。次石朝工作田、渠岸或清石帶收尾，避開農路。
# 每筆依序為單石資源、世界水平偏移、公尺模型倍率、偏航角。
const LAYOUTS := {
	"北圍田清石":[[2,0.,0.,.85,18.],[6,2.10,.28,.62,-8.],[11,2.55,-.45,.60,37.]],
	"西渠上游清石":[[3,-.24,0.,.94,47.],[6,1.55,-1.06,.74,55.]],
	"東南田界清石":[[2,0.,0.,.83,82.],[9,1.28,-1.46,.72,15.],[5,2.17,-1.78,.44,-29.]],
	"西北至內院農路肩":[[1,-.17,.15,.70,13.],[6,2.02,-.53,.58,19.]],
	"北院西側路肩":[[2,0.,0.,.86,-55.],[7,.79,1.90,.58,66.],[11,1.57,2.18,.63,5.]],
	"秤房東側田界":[[3,-.03,.09,.96,59.],[8,.22,-2.01,.70,12.]],
	"西麥場拾石帶":[[2,0.,0.,.86,2.],[9,1.94,.19,.70,-14.],[11,2.68,-.18,.64,35.],[10,3.21,-.30,.49,59.]]}

static func install(farm:Node3D) -> Array:
	var originals:Array[MeshInstance3D]=[]
	for n:MeshInstance3D in farm.find_children("*","MeshInstance3D",true,false):
		if n.mesh in [farm._props.Rock02,farm._props.Rock04] and n.get_parent() is StaticBody3D and n.get_parent().get_parent()==farm:
			originals.append(n)
	var proof:=[]
	for field:Array in farm.MARGINS.data:
		if not LAYOUTS.has(field[0]): continue
		var origin:=Vector2(field[1],field[2])
		var old:Array[MeshInstance3D]=[]
		for v in originals:
			var p:Vector3=v.get_parent().position
			if Vector2(p.x,p.z).distance_to(origin)<2.60: old.append(v)
		if old.size()!=2:
			push_error("清石定位不符："+str(field[0]))
			continue
		var cluster:Array=LAYOUTS[field[0]]
		for i in cluster.size():
			var item:Array=cluster[i]
			var mesh:Mesh=farm._props[StringName("Rock%02d"%int(item[0]))]
			var locations:Dictionary=farm.get_meta(&"field_stone_locations",{})
			var at:Vector2=locations.get("%s/%d"%[field[0],i],origin+Vector2(item[1],item[2]))
			var p:=Vector3(at.x,0,at.y)
			var rot:=deg_to_rad(float(item[4]))
			var factor:float=item[3]
			# 底部外圈也要入土。取低位頂點相對各自實際地面的間隙，讓四分之三獲得支承。
			var gaps:=base_gaps(farm,mesh,p,rot,factor)
			if gaps.is_empty(): continue
			p.y=-gaps[floori(.75*(gaps.size()-1))]-.065
			var body:StaticBody3D
			if i<2:
				var view:=old[i]
				body=view.get_parent()
				view.mesh=mesh
				view.scale=Vector3.ONE*factor
				var cs:=body.find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D
				var faces:=mesh.get_faces()
				for j in faces.size(): faces[j]*=factor
				var shape:=ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				shape.backface_collision=true
				cs.shape=shape
			else:
				body=farm._solid_mesh(p,mesh,Vector3.ONE*factor)
				farm._prop(StringName("Rock%02d"%int(item[0])),Vector3.ZERO,Vector3.ONE*factor,body)
			body.position=p
			body.rotation.y=rot
			body.collision_layer=old[0].get_parent().collision_layer
			body.set_meta(&"farm_field_stone",str(field[0]))
			proof.append([field[0],i,int(item[0]),p.x,p.y,p.z,gaps.front()+p.y,gaps.back()+p.y])
	return proof

static func base_gaps(farm:Node3D,mesh:Mesh,p:Vector3,yaw:float,factor:float) -> Array[float]:
	var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds:=mesh.get_aabb()
	var basis:=Basis(Vector3.UP,yaw)
	var sampled:={}
	var gaps:Array[float]=[]
	for v in vertices:
		if v.y>bounds.position.y+bounds.size.y*.075 or sampled.has(v): continue
		sampled[v]=true
		var world:=p+basis*(v*factor)
		var hit:Dictionary=farm.floor_hit(world.x,world.z)
		if not hit.is_empty(): gaps.append(world.y-hit.position.y)
	gaps.sort()
	return gaps
