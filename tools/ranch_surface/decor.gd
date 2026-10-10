extends RefCounted
## v8第一輪：全程隔離；不更動正式地形、碰撞或藏身資料。

const PATCH=Rect2(44,54,30,22)
const CAP=120
const SPACING=0.24
const SEED=810101
var ground:MeshInstance3D
var terrain:Terrain
var m:Node
var mat:ShaderMaterial
var mask:Image
var trees:Array[Vector2]=[]
var cover:Array[Vector2]=[]
var meshes:Dictionary={}
var groups:Dictionary={}
var records:Dictionary={}
var costs:Dictionary={}
var mode:=1
var variant:=2
var noise:=FastNoiseLite.new()
var shape_identity:Resource
var grid_identity:PackedFloat32Array

func life(p:Vector2)->float:
	var a:=Vector2(52,53);var b:=Vector2(52,61);var c:=Vector2(58,66)
	var value:=0.0
	for seg:Array in [[a,b],[b,c]]:
		var d:Vector2=seg[1]-seg[0]
		var t:=clampf((p-seg[0]).dot(d)/d.length_squared(),0.0,1.0)
		var center:Vector2=seg[0]+d*t
		var width:=0.64+0.15*sin(center.y*0.43)+0.09*noise.get_noise_2d(center.x,center.y)
		var dist:=p.distance_to(center)
		value=maxf(value,1.0-smoothstep(width,width+1.35,dist+noise.get_noise_2d(p.x*1.3,p.y*1.3)*0.20))
	return maxf(value,Trails.weight(p.x,p.y))

func canopy(p:Vector2)->float:
	var value:=0.0
	for tree:Vector2 in trees:
		var w:float=(1.0-smoothstep(1.0,5.6,p.distance_to(tree)))
		value=maxf(value,w)
	return clampf(value*(0.76+noise.get_noise_2d(p.x,p.y)*0.3),0.0,1.0)

func valid(p:Vector2)->bool:
	if not PATCH.grow(-0.4).has_point(p) or life(p)>0.80 or Trails.edge(p.x,p.y)<0.85:return false
	# Existing _blocked includes broad grass/spawn reserves, not just physical walls.
	# This explicit outside-house yard strip admits tiny decorative leaves/chips;
	# core travel suppression and actual ground-only ray still protect functionality.
	var yard:=Rect2(49,54.5,6,8.5).has_point(p)
	if not yard and m._blocked.any(func(r:Rect2)->bool:return r.grow(0.40).has_point(p)):return false
	for rec:Dictionary in m._level:
		if rec.kind in [&"flat",&"wheat",&"road"]:continue
		if p.distance_to(Vector2(rec.pos.x,rec.pos.z))<0.70:return false
	if cover.any(func(q:Vector2)->bool:return q.distance_to(p)<0.22):return false
	return true

func _load_meshes()->void:
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var result:=document.append_from_file("res://levels/ranch_surface/ground_fragments.glb",state)
	assert(result==OK,"v8 isolated GLB cannot read")
	var source:Node3D=document.generate_scene(state)
	for n:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var mesh:Mesh=n.mesh.duplicate()
		for j in mesh.get_surface_count():
			var old:StandardMaterial3D=mesh.surface_get_material(j)
			var material:ShaderMaterial=m._to_facet(old).duplicate()
			material.set_shader_parameter(&"use_vcol",true)
			material.set_shader_parameter(&"roughness",0.95)
			var color:Color=old.albedo_color.srgb_to_linear()*0.45
			color.a=1.0
			material.set_shader_parameter(&"albedo",color.linear_to_srgb())
			mesh.surface_set_material(j,material)
		meshes[str(n.name)]=mesh
	source.free()

func generate(kind:String,limit:int=CAP)->Array[Dictionary]:
	var rng:=RandomNumberGenerator.new();rng.seed=SEED+(17 if kind=="uniform" else 0)
	var style:=RandomNumberGenerator.new();style.seed=SEED+102
	var output:Array[Dictionary]=[]
	var cells:Dictionary={}
	var anchors:Array[Vector2]=[]
	# Only point proposals; acceptance uses common safety constraints and actual physics ground.
	for t in 450:
		var p:=PATCH.position+Vector2(rng.randf(),rng.randf())*PATCH.size
		if valid(p) and rng.randf()<0.12+canopy(p)*0.8:anchors.append(p)
		if anchors.size()==7:break
	for trial in 10000:
		var p:Vector2
		if kind=="swept":
			var centers:=[Vector2(50.35,57.2),Vector2(53.55,60.7),Vector2(54.2,64.4)]
			var k:=rng.randi_range(0,2)
			p=centers[k]+Vector2(rng.randfn(0,0.44),rng.randfn(0,0.37))
		elif kind in ["maintained","weathered"]:
			p=Vector2(49+rng.randf()*9,54+rng.randf()*12)
			if kind=="maintained" and rng.randf()>canopy(p)*0.5+0.07:continue
			if kind=="weathered" and rng.randf()>canopy(p)*0.7+life(p)*0.20:continue
		elif kind=="guided" and not anchors.is_empty() and rng.randf()<0.84:
			var k:=rng.randi_range(0,anchors.size()-1)
			var spread:=0.45+float(k%4)*0.34
			p=anchors[k]+Vector2(rng.randfn(0,spread),rng.randfn(0,spread*0.66))
		else:p=PATCH.position+Vector2(rng.randf(),rng.randf())*PATCH.size
		if not valid(p):continue
		if kind=="guided" and rng.randf()>0.08+canopy(p)*0.66:continue
		if kind=="swept" and life(p)>0.72:continue
		if kind=="maintained" and life(p)>0.48:continue
		var cell:=Vector2i(floor(p.x/SPACING),floor(p.y/SPACING))
		var near:=false
		for dz in range(-1,2):
			for dx in range(-1,2):
				for other:Vector2 in cells.get(cell+Vector2i(dx,dz),[]):
					if p.distance_to(other)<SPACING:near=true
		if near:continue
		var h:=height(p)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,h+0.5,p.y),Vector3(p.x,h-0.5,p.y))
		var hit:Dictionary=m.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider!=ground.get_parent():continue
		var family:=style.randi_range(0,2)
		if p.distance_to(Vector2(52,53))<6 and style.randf()<0.28:family=3
		if kind in ["swept","maintained","weathered"]:family=0
		var mesh_name:String=["Leaf","Stone","Twig","Chip"][family]+str(style.randi_range(0,2))
		var scale:=style.randf_range(0.80,1.12)
		var angle:=style.randf_range(0,TAU)
		var up:Vector3=hit.normal
		var transform:=Transform3D((Basis(Quaternion(Vector3.UP,up))*Basis(Vector3.UP,angle)).scaled(Vector3.ONE*scale),hit.position+up*0.002)
		var tint_value:=style.randf_range(0.93,1.06)
		output.append({point=p,transform=transform,mesh=mesh_name,scale=scale,angle=angle,tint=Color(tint_value,tint_value,tint_value,1),normal=up})
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(p)
		if output.size()>=limit:break
	return output

func batch(points:Array[Dictionary],label:String)->Node3D:
	var group:=Node3D.new();group.name="V8_"+label;m.get_node(^"Arena").add_child(group)
	var buckets:Dictionary={}
	for rec:Dictionary in points:
		var chunk:=Vector2i(floor(rec.point.x/8.0),floor(rec.point.y/8.0))
		var key:String=str(chunk)+"_"+str(rec.mesh)
		if not buckets.has(key):buckets[key]=[]
		buckets[key].append(rec)
	for key:String in buckets:
		var rows:Array=buckets[key]
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
		mm.mesh=meshes[rows[0].mesh];mm.instance_count=rows.size()
		var aabb:=AABB()
		for i in rows.size():
			var row:Dictionary=rows[i]
			# Palette/mesh edits don't change position or yaw; tint/scale copied for controlled comparison.
			var xf:Transform3D=row.transform
			xf.basis=(Basis(Quaternion(Vector3.UP,row.normal))*Basis(Vector3.UP,float(row.angle))).scaled(Vector3.ONE*float(row.scale))
			mm.set_instance_transform(i,xf);mm.set_instance_color(i,row.tint)
			var box:AABB=xf*mm.mesh.get_aabb()
			aabb=box if i==0 else aabb.merge(box)
		mm.custom_aabb=aabb.grow(0.003)
		var node:=MultiMeshInstance3D.new();node.name=key;node.multimesh=mm
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=35.0;node.visibility_range_end_margin=5.0
		node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		group.add_child(node)
	group.visible=false
	return group


func height(p:Vector2)->float:
	return surface_height(terrain,p)
func surface_height(t: Terrain,p:Vector2) -> float:
	var f:Vector2=(p+Vector2.ONE*t.size*0.5)/t.cell
	var x:=clampi(int(floor(f.x)),0,t._n-2)
	var z:=clampi(int(floor(f.y)),0,t._n-2)
	var q:=f-Vector2(x,z)
	var i:=z*t._n+x
	if q.x+q.y<=1.0:
		return t._grid_h[i]*(1.0-q.x-q.y)+t._grid_h[i+1]*q.x+t._grid_h[i+t._n]*q.y
	return t._grid_h[i+1]*(1.0-q.y)+t._grid_h[i+t._n]*(1.0-q.x)+t._grid_h[i+t._n+1]*(q.x+q.y-1.0)
