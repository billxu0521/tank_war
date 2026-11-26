extends RefCounted
## 場界外的農務延續只有可見網格。實際場界、四圈和當局提示仍由母圖提供。
const PLAN := preload("res://tools/map_study/farm_trial/design_cases.json")

static func install(farm: Node3D) -> void:
	var outside := Node3D.new()
	outside.name = &"BeyondFarm"
	farm.add_child(outside)
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var earth := Color("#e9e6cd")
	for sign_z in [-1,1]:
		quad(ground,Vector3(-126,0,84*sign_z),Vector3(126,0,84*sign_z),
			Vector3(126,0,126*sign_z),Vector3(-126,0,126*sign_z),earth)
	for side in [-1,1]:
		# 延長與灰盒相同的兩岸、渠床與平田斷面，西端水位沿用本版 H 的比較值。
		var zs := [-84.,4.74,6.37,11.25,12.88,84.] if side<0 else [-84.,-15.,-13.4,-8.6,-7.,84.]
		var ys := [0.,0.,-1.8,-1.8,0.,0.]
		var drift := 3.6 if side<0 else -4.0
		for i in range(5):
			var offset_a := drift if i>0 else 0.0
			var offset_b := drift if i<4 else 0.0
			quad(ground,Vector3(side*84.,ys[i],zs[i]),Vector3(side*84.,ys[i+1],zs[i+1]),
				Vector3(side*126.,ys[i+1],zs[i+1]+offset_b),Vector3(side*126.,ys[i],zs[i]+offset_a),
				earth if i in [0,4] else Color("#978164"))
	extend_water(outside,farm.get_node("WestBank").find_child("Water",true,false))
	# 北邊是橫向通過的收乳車道；玩家從圈看過去時，道路沿著外側柵欄轉走。
	ribbon(ground,[Vector2(-65,-92),Vector2(-32,-89),Vector2(5,-90),Vector2(36,-96),Vector2(70,-103)],2.2,Color("#aa9069"))
	var wagon: MeshInstance3D = farm._prop(&"Wagon",Vector3(-4,0,-91),Vector3.ONE,outside)
	wagon.rotation.y=deg_to_rad(79)
	# 南側收割帶與留下的草料堆、東側卸下的備用木料分別延續兩個作業場所。
	for i in 9:
		ribbon(ground,[Vector2(-23+i*3,88),Vector2(-17+i*3,102),Vector2(-15+i*3,113)],0.48,Color("#bd9c61"))
	for tier in 3:
		for i in range(6-tier):
			farm._prop(&"HayBlock",Vector3(-9+i*1.08+tier*.51,tier*farm.HAY_BLOCK.y,91),Vector3.ONE,outside)
	for z in [0.,1.4]:
		for i in 5:
			var rail:MeshInstance3D=farm._prop(&"FenceRail",Vector3(90,0.23*i,z),Vector3(2.2,1,1),outside)
			rail.rotation.y=deg_to_rad(16)
	# 西渠外延旁留一條巡渠道，農路到北岸後沿水走；南岸仍可進圈。
	ribbon(ground,[Vector2(-125,4),Vector2(-107,1),Vector2(-85,1.2)],1.1,Color("#a79371"))
	var surface := MeshInstance3D.new()
	surface.name = &"OutlyingLand"
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	ground.set_material(mat)
	surface.mesh=ground.commit()
	outside.add_child(surface)
	weigh_yard_tracks(farm)

static func wagon_curve() -> Curve2D:
	var line:=PackedVector2Array()
	for p in PLAN.data.wagon:
		line.append(Vector2(p[0],p[1]))
	var curve:=Curve2D.new()
	for i in line.size():
		var axis:Vector2=(line[mini(i+1,line.size()-1)]-line[maxi(0,i-1)])*.16
		curve.add_point(line[i],-axis if i>0 else Vector2.ZERO,axis if i<line.size()-1 else Vector2.ZERO)
	return curve

static func weigh_yard_tracks(farm:Node3D) -> void:
	var curve:=wagon_curve()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 規則點外的收貨彎道只留幾段輪痕；中心線同篷車淨空檢查。
	for stretch in [[78.,91.,-.92],[79.,88.,.92],[93.,98.,.92]]:
		var last_a:=Vector3.ZERO
		var last_b:=Vector3.ZERO
		for i in 31:
			var t:=i/30.0
			var s:=lerpf(stretch[0],stretch[1],t)
			var axis:Vector2=(curve.sample_baked(s+.1)-curve.sample_baked(s-.1)).normalized()
			var side:=axis.orthogonal()
			var p:Vector2=curve.sample_baked(s)+side*float(stretch[2])
			var width:=.012+.11*sin(t*PI)
			var a:=Vector3(p.x+side.x*width,.018,p.y+side.y*width)
			var b:=Vector3(p.x-side.x*width,.018,p.y-side.y*width)
			if i: quad(st,last_a,last_b,b,a,Color("#ae987e"))
			last_a=a
			last_b=b
	var mesh:=MeshInstance3D.new()
	mesh.name=&"WeighYardTracks"
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	st.set_material(mat)
	mesh.mesh=st.commit()
	farm.add_child(mesh)

static func ribbon(st: SurfaceTool, line: Array, half_width: float, color: Color) -> void:
	var last_left := Vector3.ZERO
	var last_right := Vector3.ZERO
	for i in line.size():
		var tangent:Vector2 = (line[mini(i+1,line.size()-1)]-line[maxi(0,i-1)]).normalized()
		var normal := tangent.orthogonal()*half_width
		var left := Vector3(line[i].x+normal.x,.015,line[i].y+normal.y)
		var right := Vector3(line[i].x-normal.x,.015,line[i].y-normal.y)
		if i>0:
			quad(st,last_left,last_right,right,left,color)
		last_left=left
		last_right=right

static func quad(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	var vertices := [a,b,c,a,c,d] if normal.y<0 else [a,c,b,a,d,c]
	for p:Vector3 in vertices:
		st.set_normal(-normal if normal.y<0 else normal)
		st.set_color(color.srgb_to_linear())
		st.add_vertex(p)

static func extend_water(outside:Node3D, water:MeshInstance3D) -> void:
	# 用水面本身的斷面與頂點色接出場界，避免界內外憑兩套色表產生一道接縫。
	var arrays:=water.mesh.surface_get_arrays(0)
	var pts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var edge:Dictionary={}
	for i in pts.size():
		if absf(pts[i].x+84)<.01:
			edge[roundi(pts[i].z*1000)]=i
	var keys:=edge.keys()
	keys.sort()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extend:=Vector3(-42,0,3.6)
	for j in range(1,keys.size()):
		var a:int=edge[keys[j-1]]
		var b:int=edge[keys[j]]
		for pair in [[a,false],[b,false],[b,true],[a,false],[b,true],[a,true]]:
			var i:int=pair[0]
			st.set_color(colors[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i]+(extend if pair[1] else Vector3.ZERO))
	var surface:=MeshInstance3D.new()
	surface.name=&"WestWaterExtension"
	surface.mesh=st.commit()
	surface.material_override=water.material_override
	outside.add_child(surface)
