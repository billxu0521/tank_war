extends "res://tools/map_study/farm_trial/integrated.gd"
## 深床沿原西灘、東堤接回可走面。東卸料臺下游另有一處偏向北岸的泥坡。
func _ready() -> void:
	super()
	$"FarmShell/東堤量水房".free()
	place(preload("res://models/farm_gage_house/EastGageHouse.tscn"),Vector3(58,0,5),-12)
	var soil:MeshInstance3D=$"FarmShell/場地剖切與渠床"
	var material:Material
	for i in soil.mesh.get_surface_count():
		var m:=soil.get_active_material(i)
		if m and m.resource_name=="土層": material=m
	if not material:
		var clay:=StandardMaterial3D.new()
		clay.albedo_color=Color("#88765a")
		clay.roughness=1
		material=clay
	add_slope("西灘西端淤坡",Vector2(-62.5,6),Vector2(-53,6),-1.82,-1.732,2.15,material)
	add_slope("西灘東端淤坡",Vector2(-31,10.6),Vector2(-41,7.7),-1.82,-1.732,2.15,material)
	add_slope("東堤上游護腳土坡",Vector2(34,1.8),Vector2(45,-1.6),-1.82,.012,2.45,material)
	add_slope("卸料端北側回岸坡",Vector2(78,-11),Vector2(70.8,-17.1),-1.82,.012,2.5,material,.80)

func triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
	if (b-a).cross(c-a).y>0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)

func add_slope(label:String,start:Vector2,finish:Vector2,bottom:float,top:float,half_width:float,material:Material,crest:float=1.0) -> void:
	var direction:=(finish-start).normalized()
	var across:=Vector2(-direction.y,direction.x)
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var previous:=PackedVector3Array()
	for i in range(13):
		var t:=float(i)/12
		var center:=start.lerp(finish,t)
		var height:=lerpf(bottom,top,minf(t/crest,1.0))
		var row:=PackedVector3Array()
		for side in [-1.5,-1.0,1.0,1.5]:
			var at:Vector2=center+across*side*half_width
			var y:=bottom-.06 if absf(side)>1 else height
			row.append(Vector3(at.x,y,at.y))
		if i>0:
			for j in 3:
				triangle(st,previous[j],row[j],previous[j+1])
				triangle(st,previous[j+1],row[j],row[j+1])
		previous=row
	st.generate_normals()
	var ramp:=MeshInstance3D.new()
	ramp.name=label
	ramp.mesh=st.commit()
	add_child(ramp)
	var body:=StaticBody3D.new()
	body.collision_layer=1|FLOOR_LAYER|Fighter.SOLID_LAYER
	ramp.add_child(body)
	body.add_to_group(&"ground")
	body.add_to_group(&"canal_soil")
	var collider:=CollisionShape3D.new()
	collider.shape=ramp.mesh.create_trimesh_shape()
	body.add_child(collider)
