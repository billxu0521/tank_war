extends "res://tools/map_study/farm_trial/open_banks.gd"
## A 案的雙岸田肩及北院；沿用 v2.7 兩岸、目標及普通四席規則。
const RIDGES := [[Vector2(-38,-19), Vector2(-26,-14), 1.8], [Vector2(6,38), Vector2(19,35), 1.85]]
const WORK_LANE := [Vector2(3.3,-47.7),Vector2(7.8,-44),Vector2(10.1,-43.8),Vector2(13.3,-43.9),Vector2(14.4,-46.1),Vector2(15.1,-49.7),Vector2(18.5,-49.5),Vector2(21,-48),Vector2(22,-45)]
const TRACK_SITES := preload("res://levels/farm_sites/sites.gd")

func _ready() -> void:
	super()
	var original := get_node("FarmShell/農舍 3") as MeshInstance3D
	var base_mat := original.get_active_material(0)
	original.free()
	var outline: Array = SURVEY.data.polygons[2]
	var start := Vector2(outline[0][0],outline[0][1])
	var across := Vector2(outline[1][0],outline[1][1]) - start
	var along := Vector2(outline[3][0],outline[3][1]) - start
	for spec in [[.71,1.,0.,1.,3.2,"北院東屋"],[0.,.34,0.,.32,3.2,"北院側庫"],[.08,.68,.74,1.,2.05,"北院貨垛"]]:
		var centre: Vector2 = start + across * ((spec[0]+spec[1])*.5) + along * ((spec[2]+spec[3])*.5)
		var size := Vector3(across.length()*(spec[1]-spec[0]),spec[4],along.length()*(spec[3]-spec[2]))
		var body := _solid_box(Vector3(centre.x,size.y*.5,centre.y),size)
		body.name = spec[5]
		body.rotation.y = -across.angle()
		var view := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		box.material = base_mat
		view.mesh = box
		if spec[5] == "北院貨垛": view.material_override = soil_material(Color("#997751"))
		body.add_child(view)
	for ridge in RIDGES:
		make_shoulder(ridge[0],ridge[1],ridge[2])
	for track in SURVEY.data.paths.slice(-2):
		var points: Array = []
		for xz in track[1]:
			points.append(Vector2(xz[0],xz[1]))
		make_track(points,.8)
	var grain_floor := PackedVector2Array()
	var size: Vector2 = TRACK_SITES.GRAIN.size
	var placement := TRACK_SITES.placement(TRACK_SITES.GRAIN)
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var world := placement * Vector3(corner.x, 0, corner.y)
		grain_floor.append(Vector2(world.x, world.z))
	make_track(WORK_LANE,.52,grain_floor)
	# 院牆的短末節移回內院；同一節的外觀與碰撞一起移。
	var long_wall := get_node("LocalGeometry/Wall2_2") as StaticBody3D
	var shorten := 5.5
	var direction := long_wall.basis.x.normalized()
	long_wall.position -= direction * shorten * .5
	var surface := long_wall.get_node("Mesh") as MeshInstance3D
	var mesh := surface.mesh.duplicate() as BoxMesh
	mesh.size.x -= shorten
	surface.mesh = mesh
	var collider := long_wall.find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
	var block := collider.shape.duplicate() as BoxShape3D
	block.size.x -= shorten
	collider.shape = block
	get_node("LocalGeometry/Wall2_3").position -= direction*shorten

func soil_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.
	return mat

func vertex_at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x,y,p.y)

func top_triangle(surface: SurfaceTool, a: Vector3,b: Vector3,c: Vector3) -> void:
	surface.add_vertex(a)
	if (b-a).cross(c-a).y < 0.:
		surface.add_vertex(b)
		surface.add_vertex(c)
	else:
		surface.add_vertex(c)
		surface.add_vertex(b)

func make_shoulder(a: Vector2,b: Vector2, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var forward := (b-a).normalized()
	var side := forward.orthogonal()
	for dir: float in [-1.,1.]:
		var left := vertex_at(a+side*4.*dir,-.015)
		var right := vertex_at(b+side*4.*dir,-.015)
		top_triangle(surface,vertex_at(a,height),right,left)
		top_triangle(surface,vertex_at(a,height),vertex_at(b,height),right)
	for end in [[a,-forward],[b,forward]]:
		var centre: Vector2 = end[0]
		var outward: Vector2 = end[1]
		for i in 16:
			var v := centre+outward.rotated(-PI*.5+PI*i/16.)*4.
			var w := centre+outward.rotated(-PI*.5+PI*(i+1)/16.)*4.
			top_triangle(surface,vertex_at(centre,height),vertex_at(v,-.015),vertex_at(w,-.015))
	surface.generate_normals()
	var view := MeshInstance3D.new()
	view.mesh = surface.commit()
	view.material_override = soil_material(Color("#9b8c62"))
	var bank := StaticBody3D.new()
	bank.name = "西岸田肩" if a.x<0 else "南田田肩"
	bank.add_to_group(&"ground")
	bank.collision_layer = 1 | FLOOR_LAYER | Fighter.SOLID_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = view.mesh.create_trimesh_shape()
	bank.add_child(view)
	bank.add_child(shape)
	add_child(bank)

func track_vertex(p: Vector2) -> Vector3:
	var y := 0.
	for ridge in RIDGES:
		var foot := Geometry2D.get_closest_point_to_segment(p,ridge[0],ridge[1])
		y = maxf(y, ridge[2]*(1.-p.distance_to(foot)/4.))
	return vertex_at(p,y+.025)

func add_track_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, footprint: PackedVector2Array) -> void:
	if footprint.is_empty():
		top_triangle(st,a,b,c)
		return
	var triangle := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
	if Geometry2D.intersect_polygons(triangle,footprint).is_empty():
		top_triangle(st,a,b,c)
		return
	for outside in Geometry2D.clip_polygons(triangle,footprint):
		var indices := Geometry2D.triangulate_polygon(outside)
		for i in range(0,indices.size(),3):
			top_triangle(st,track_vertex(outside[indices[i]]),track_vertex(outside[indices[i+1]]),track_vertex(outside[indices[i+2]]))

func make_track(points: Array, half_width: float, footprint := PackedVector2Array()) -> void:
	var path := Curve2D.new()
	for p in points: path.add_point(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last: Array[Vector3] = []
	var n := ceili(path.get_baked_length()/.4)
	for i in range(n+1):
		var t := path.get_baked_length()*i/n
		var p := path.sample_baked(t)
		var dir := path.sample_baked(minf(t+.15,path.get_baked_length()))-path.sample_baked(maxf(0.,t-.15))
		var side := dir.normalized().orthogonal()*half_width
		var row: Array[Vector3] = [track_vertex(p+side),track_vertex(p-side)]
		if i:
			add_track_triangle(st,last[0],last[1],row[1],footprint)
			add_track_triangle(st,last[0],row[1],row[0],footprint)
		last = row
	st.generate_normals()
	var view := MeshInstance3D.new()
	view.mesh = st.commit()
	view.layers |= EXIT_GROUND_LAYER
	view.material_override = soil_material(Color("#b8a186"))
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)

