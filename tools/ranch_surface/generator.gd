extends RefCounted
const DECAL_LAYER=1<<19
const ROCK=Vector2(28.15763,10.015007)
var base:=preload("res://tools/ranch_surface/base.gd").new()
var gen:=preload("res://tools/ranch_surface/decor.gd").new()
var m:Node
var mat:ShaderMaterial
var active_outline:Material
var original_outline:Material
var outline_node:MeshInstance3D
var contact:Image
var contact_target:StaticBody3D
var decor:Node3D
var wear:Node3D
var shadow:Node3D
var costs:Dictionary={}
var points:Array[Dictionary]=[]
var initial_grid:PackedFloat32Array
var initial_mesh:Mesh
var initial_shape:Shape3D
var context:Image
var local:Image
var baked:Image
var wear_images:Array[Image]=[]
var config:="full"
func install(main:Node)->void:
	m=main
	var start:=Time.get_ticks_usec()
	base.install(m)
	costs.base_ms=(Time.get_ticks_usec()-start)/1000.0
	initial_grid=m._terrain._grid_h.duplicate();initial_mesh=base.ground_mesh.mesh
	initial_shape=base.ground_mesh.get_parent().get_child(1).shape
	gen.m=m;gen.ground=base.ground_mesh;gen.terrain=m._terrain
	gen.noise.seed=gen.SEED;gen.noise.frequency=0.23
	for rec:Dictionary in m._level:
		var p:=Vector2(rec.pos.x,rec.pos.z)
		if rec.kind==&"tree" and gen.PATCH.grow(8).has_point(p):gen.trees.append(p)
	for node:Node in m.get_node(^"Arena").find_children("*","MultiMeshInstance3D",true,false):
		if str(node.name).begins_with("Groundcover") or str(node.name).begins_with("Grass"):
			for i in node.multimesh.instance_count:
				var pt:Vector3=(node.global_transform*node.multimesh.get_instance_transform(i)).origin
				if gen.PATCH.has_point(Vector2(pt.x,pt.z)):gen.cover.append(Vector2(pt.x,pt.z))
	start=Time.get_ticks_usec();gen._load_meshes()
	points=gen.generate("guided",120)
	for rec:Dictionary in gen.generate("weathered",90):
		if not points.any(func(q:Dictionary)->bool:return q.point.distance_to(rec.point)<gen.SPACING):points.append(rec)
	decor=gen.batch(points,"V10Combined")
	costs.decor_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	context=Image.create(336,336,false,Image.FORMAT_RGBA8);local=Image.create(336,336,false,Image.FORMAT_RGBA8)
	for z in 336:
		for x in 336:
			var p:Vector2=(Vector2(x+0.5,z+0.5)/336.0-Vector2.ONE*0.5)*m.ARENA
			var forest:=base.rect_weight(gen.PATCH,p,2.0)
			var life:=gen.life(p);var canopy:=gen.canopy(p)
			context.set_pixel(x,z,Color(forest,life,canopy,canopy*(1.0-life)))
			var rock:=zone(p,ROCK,Vector2(6,5));var wet:=zone(p,Vector2(-53,-44),Vector2(3.4,3.7))
			local.set_pixel(x,z,Color(forest,rock,maxf(forest,maxf(rock,wet)),1))
	costs.context_ms=(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec();_contact();costs.contact_ms=(Time.get_ticks_usec()-start)/1000.0
	mat=base.candidate.duplicate();mat.shader=load("res://levels/ranch_surface/ground.gdshader")
	mat.set_shader_parameter(&"context_mask",ImageTexture.create_from_image(context));mat.set_shader_parameter(&"local_mask",ImageTexture.create_from_image(local));mat.set_shader_parameter(&"contact_mask",ImageTexture.create_from_image(contact))
	wear=Node3D.new();wear.name="V10Wear";m.get_node(^"Arena").add_child(wear)
	start=Time.get_ticks_usec()
	for i in 3:
		var img:=wear_image(i);wear_images.append(img)
		var pt:Vector2=[Vector2(52,55.8),Vector2(51.7,58),Vector2(53.1,60)][i]
		var decal:=_decal(pt,Vector2(1.0+i*0.15,1.6-i*0.12),ImageTexture.create_from_image(img),wear)
		decal.rotation.y=[0.13,-0.28,0.40][i];decal.albedo_mix=0.5
	baked=Image.create(512,512,false,Image.FORMAT_RGBA8)
	for z in 512:
		for x in 512:
			var p:=Vector2(49,54)+Vector2(x+0.5,z+0.5)/512.0*Vector2(7,8)
			var c:=Color(0,0,0,1)
			for i in 3:
				var pt:Vector2=[Vector2(52,55.8),Vector2(51.7,58),Vector2(53.1,60)][i]
				var yaw:float=[0.13,-0.28,0.40][i]
				# Inverse Y rotation: local x=cos*x-sin*z, local z=sin*x+cos*z.
				var q:Vector2=(p-pt).rotated(yaw)/Vector2(1.0+i*0.15,1.6-i*0.12)+Vector2.ONE*0.5
				if q.x>=0 and q.x<=1 and q.y>=0 and q.y<=1:c[i]=wear_images[i].get_pixel(clampi(int(q.x*128),0,127),clampi(int(q.y*128),0,127)).a
			baked.set_pixel(x,z,c)
	baked.generate_mipmaps();mat.set_shader_parameter(&"wear_mask",ImageTexture.create_from_image(baked))
	costs.wear_bake_ms=(Time.get_ticks_usec()-start)/1000.0
	shadow=Node3D.new();shadow.name="V10Contact";m.get_node(^"Arena").add_child(shadow)
	var ci:=Image.create(96,96,false,Image.FORMAT_RGBA8)
	for z in 96:
		for x in 96:ci.set_pixel(x,z,Color(0.29,0.23,0.17,contact.get_pixel(x,z).r*0.42))
	var sd:=_decal(ROCK,Vector2(6,6),ImageTexture.create_from_image(ci),shadow);sd.albedo_mix=1.0
	for n:Node in m.get_node(^"Arena").find_children("*","MeshInstance3D",true,false):
		var source:Material=n.get_active_material(0)
		if source is ShaderMaterial and source.shader.resource_path.ends_with("outline.gdshader"):
			outline_node=n;original_outline=source
	if outline_node!=null:
		var outmat:ShaderMaterial=original_outline.duplicate();outmat.shader=load("res://levels/ranch_surface/outline.gdshader")
		var h:=Image.create(m._terrain._n,m._terrain._n,false,Image.FORMAT_RF)
		for z in m._terrain._n:
			for x in m._terrain._n:h.set_pixel(x,z,Color(initial_grid[z*m._terrain._n+x],0,0,1))
		outmat.set_shader_parameter(&"ground_height",ImageTexture.create_from_image(h));outmat.set_shader_parameter(&"sample_mask",ImageTexture.create_from_image(local));outmat.set_shader_parameter(&"grid_n",m._terrain._n)
		active_outline=outmat;outline_node.material_override=outmat
	costs.total_ms=(Time.get_ticks_usec()-start)/1000.0+costs.base_ms+costs.decor_ms+costs.context_ms+costs.contact_ms
	select("full")
func zone(p:Vector2,c:Vector2,size:Vector2)->float:
	return 1.0-smoothstep(0.6,1.0,((p-c)/size).length())
func _height(p:Vector2)->float:return gen.height(p)
func _contact()->void:
	contact=Image.create(96,96,false,Image.FORMAT_RF)
	var best:=1000.0
	for body:Node3D in m.get_tree().get_nodes_in_group(&"stone"):
		var dist:=Vector2(body.global_position.x,body.global_position.z).distance_to(ROCK)
		if body is StaticBody3D and dist<best:best=dist;contact_target=body
	if contact_target==null or best>0.1:
		push_error("No existing solid rock at v9 contact location");return
	var space:PhysicsDirectSpaceState3D=m.get_world_3d().direct_space_state
	var ground:CollisionObject3D=base.ground_mesh.get_parent()
	for z in 96:
		for x in 96:
			var p:=ROCK+(Vector2(x+0.5,z+0.5)/96.0-Vector2.ONE*0.5)*6.0
			var origin:=Vector3(p.x,_height(p)+0.035,p.y)
			var hits:=0.0
			# 12 finite low upward rays: local collider proxy, not full physical AO integral.
			for i in 12:
				var a:=TAU*float(i)/12.0
				var ray:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3(cos(a)*0.65,0.20,sin(a)*0.65))
				ray.exclude=[ground.get_rid()]
				var hit:Dictionary=space.intersect_ray(ray)
				if not hit.is_empty() and hit.collider==contact_target:hits+=1.0
			contact.set_pixel(x,z,Color(hits/12.0,0,0,1))
	# Two small low-pass passes remove directional spoke marks without a wide black ring.
	for pass_index in 2:
		var copy:=contact.duplicate()
		for z in range(1,95):
			for x in range(1,95):
				var value:=0.0
				for dz in range(-1,2):
					for dx in range(-1,2):value+=copy.get_pixel(x+dx,z+dz).r
				contact.set_pixel(x,z,Color(value/9.0,0,0,1))
func wear_image(index:int)->Image:
	var img:=Image.create(128,128,false,Image.FORMAT_RGBA8)
	var n:=FastNoiseLite.new();n.seed=91010+index;n.frequency=0.055
	for z in 128:
		for x in 128:
			var q:Vector2=(Vector2(x+0.5,z+0.5)/128.0-Vector2.ONE*0.5)*2.0
			var edge:=q.length()+n.get_noise_2d(x,z)*0.20
			var alpha:float=(1.0-smoothstep(0.45,0.98,edge))*(0.58+0.20*n.get_noise_2d(x*2,z*2))
			img.set_pixel(x,z,Color(0.49,0.37,0.25,alpha))
	img.generate_mipmaps();return img
func _decal(p:Vector2,size:Vector2,texture:Texture2D,parent:Node3D)->Decal:
	var decal:=Decal.new();decal.name="V9Decal_%d"%parent.get_child_count()
	decal.size=Vector3(size.x,1.2,size.y);decal.position=Vector3(p.x,_height(p),p.y)
	decal.texture_albedo=texture;decal.cull_mask=DECAL_LAYER;decal.normal_fade=0.5
	decal.distance_fade_enabled=true;decal.distance_fade_begin=24.0;decal.distance_fade_length=6.0
	parent.add_child(decal);return decal

func select(value:String)->void:
	config=value
	if outline_node!=null:outline_node.material_override=original_outline if value in ["original","v5"] else active_outline
	base.ground_mesh.layers=1|DECAL_LAYER
	base.ground_mesh.material_override=mat
	mat.set_shader_parameter(&"integration_strength",0.65 if value=="restrained" else 1.0)
	mat.set_shader_parameter(&"height_enabled",true);mat.set_shader_parameter(&"optical_enabled",value!="no_optics")
	mat.set_shader_parameter(&"contact_mode",0 if value in ["no_contact","contact_decal"] else 1)
	mat.set_shader_parameter(&"wear_mode",2 if value=="baked" else 0)
	decor.visible=value!="no_decor";wear.visible=value!="baked";shadow.visible=value=="contact_decal"
	for n:MultiMeshInstance3D in decor.get_children():
		n.multimesh.visible_instance_count=int(n.multimesh.instance_count*0.65) if value=="restrained" else -1
	for n:Decal in wear.get_children():n.albedo_mix=0.325 if value=="restrained" else 0.5
	if value in ["original","v5"]:
		base.ground_mesh.material_override=base.baseline if value=="original" else base.candidate
		decor.visible=false;wear.visible=false;shadow.visible=false
func evidence(path:String)->void:
	context.save_png(path+"/context.png");local.save_png(path+"/local.png");baked.save_png(path+"/wear-baked.png")
	var c:=contact.duplicate();c.convert(Image.FORMAT_RGBA8);c.save_png(path+"/contact.png")
	var count:=0
	for n:MultiMeshInstance3D in decor.get_children():count+=n.multimesh.instance_count
	var f:=FileAccess.open(path+"/setup.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({costs=costs,decor_instances=count,decor_batches=decor.get_child_count(),wear_decals=3,contact_decals=1,base_rgba_bytes=4*672*672*4,wear_original_rgba_bytes=3*128*128*4,wear_baked_rgba_bytes=512*512*4,contact_proxy="12 rays per pixel; collider proxy, not physical AO",geometry_unchanged=initial_grid==m._terrain._grid_h and initial_mesh==base.ground_mesh.mesh and initial_shape==base.ground_mesh.get_parent().get_child(1).shape},"\t"))

func export_assets()->void:
	select("full")
	var full:ShaderMaterial=mat.duplicate()
	full.set_shader_parameter(&"wear_mask",null)
	assert(ResourceSaver.save(full,"res://levels/ranch_surface/ground.res",ResourceSaver.FLAG_COMPRESS)==OK)
	assert(ResourceSaver.save(active_outline,"res://levels/ranch_surface/outline_data.res",ResourceSaver.FLAG_COMPRESS)==OK)
	for pair:Array in [[decor,"decor.scn"],[wear,"wear.scn"]]:
		var group:Node3D=pair[0]
		for child:Node in group.find_children("*","",true,false):child.owner=group
		var scene:=PackedScene.new();assert(scene.pack(group)==OK)
		assert(ResourceSaver.save(scene,"res://levels/ranch_surface/"+pair[1],ResourceSaver.FLAG_COMPRESS)==OK)
