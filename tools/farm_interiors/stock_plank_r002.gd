extends "res://tools/farm_interiors/bake_stock_rooms.gd"
## 離線低面數替身。從原木板抽出八角橫截面，依原長封住兩端，
## 保留實體板的寬厚與四條通長倒角。只在本次工具程序替換快取。
const PLANK := "res://levels/farm_stock_assemblies/stock/plank.res"
var candidate:ArrayMesh

func _initialize() -> void:
	make_candidate.call_deferred()

static func add_face(st:SurfaceTool, vertices:Array[Vector3], outward:Vector3) -> void:
	var normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	if normal.dot(outward)<0:normal=-normal
	for i in range(1,vertices.size()-1):
		var triangle:Array[Vector3]=[vertices[0],vertices[i],vertices[i+1]]
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).dot(normal)>0:
			triangle.reverse()
		for point in triangle:
			st.set_normal(normal)
			st.add_vertex(point)

func make_candidate() -> void:
	var original:ArrayMesh=load(PLANK)
	var arr:=original.surface_get_arrays(0)
	var points:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	var xmax:=original.get_aabb().end.x
	var xmin:=original.get_aabb().position.x
	var bevel_end:=-INF
	for point in points:
		if point.x<xmax-.0001:bevel_end=maxf(point.x,bevel_end)
	var cross_section:Array[Vector2]=[]
	for point in points:
		if absf(point.x-bevel_end)<.00001:
			var yz:=Vector2(point.y,point.z)
			if yz not in cross_section:cross_section.append(yz)
	if cross_section.size()!=8:
		printerr("原板截面已變更");quit(2);return
	cross_section.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.angle()<b.angle())
	var left:Array[Vector3]=[]
	var right:Array[Vector3]=[]
	for yz in cross_section:
		left.append(Vector3(xmin,yz.x,yz.y))
		right.append(Vector3(xmax,yz.x,yz.y))
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_face(st,left,Vector3.LEFT)
	add_face(st,right,Vector3.RIGHT)
	for i in cross_section.size():
		var j:=(i+1)%cross_section.size()
		var center:=(left[i]+left[j]+right[i]+right[j])*.25
		add_face(st,[left[i],left[j],right[j],right[i]],Vector3(0,center.y,center.z))
	st.index()
	candidate=st.commit()
	if not original.get_aabb().is_equal_approx(candidate.get_aabb()) or candidate.get_faces().size()!=28*3:
		printerr("替身未保留原板包絡或面數不符");quit(2);return
	candidate.take_over_path(PLANK)
	print("原板每端簡化區占板長 ",(xmax-bevel_end)/(xmax-xmin))
	bake()
