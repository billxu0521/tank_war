extends Node3D
## 固定的活體植被提供蹲藏，角色可以直接穿過。
var farm:Node3D
var center:Vector3

func register(host:Node3D,at:Vector2) -> void:
	farm=host
	center=Vector3(at.x,0,at.y)
	position=center

func grow(reed:bool) -> void:
	position=farm.floor_hit(center.x,center.z).position
	if reed:
		var full:=MeshInstance3D.new()
		full.mesh=reed_mesh()
		add_child(full)
	else:
		hide_old_hedge()
		var geom:Mesh=farm.get_node(^"FarmStyleEnvironment").forms.bush
		for spec in [[-.76,.13,.82],[.03,-.06,1.39],[.79,.17,.93]]:
			var leaf:=MeshInstance3D.new()
			leaf.mesh=geom
			var box:=geom.get_aabb()
			leaf.scale=Vector3(.74,spec[2]/box.size.y,.90)
			leaf.position=Vector3(spec[0],-box.position.y*leaf.scale.y-.035,spec[1])
			add_child(leaf)
	if not farm._bushes.has(center):
		farm._bushes.append(center)

func hide_old_hedge() -> void:
	var mesh:Mesh=farm.get_node(^"FarmStyleEnvironment").forms.bush
	var count:=0
	var slot:=-1
	for plot:Dictionary in farm.PLOTS.data.values():
		for item:Array in plot.get("hedges",[]):
			if Vector2(item[0],item[1]).distance_to(Vector2(center.x,center.z))<.10: slot=count
			count+=1
	if slot<0: return
	# connections.gd 以田塊記錄順序建立這一批。無繪圖模式也能精確移除原株。
	for node in farm.get_children():
		if node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh==mesh and node.multimesh.instance_count==count:
			node.multimesh.set_instance_transform(slot,Transform3D(Basis.from_scale(Vector3.ZERO),center))
			set_meta(&"replaced_hedge_slot",slot)
			return
	push_error("找不到原果園矮籬圖層")

func reed_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new()
	rng.seed=109061
	for i in 81:
		var angle:=rng.randf_range(-PI,PI)
		var radius:=sqrt(rng.randf())
		var base:=Vector3(1.48*cos(angle)*radius,0,1.10*sin(angle)*radius)
		base.y=farm.floor_hit(position.x+base.x,position.z+base.z).position.y-position.y-.04
		var h:=rng.randf_range(1.19,1.59)*(1.-.27*radius)
		var side:=Vector3(cos(angle),0,sin(angle))
		var cross:=side.rotated(Vector3.UP,PI*.5)
		var w:=rng.randf_range(.040,.085)
		if base.z>.05: h+=.21
		var knee:=base+Vector3.UP*h*.63+side*.075
		var top:=base+Vector3.UP*h+side*.26
		var col:=Color("#888047").lerp(Color("#707d45"),rng.randf()).srgb_to_linear()
		var a:=base-cross*w*.26
		var b:=base+cross*w*.26
		var c:=knee+cross*w
		var d:=knee-cross*w
		for v in [a,b,c,a,c,d,d,c,top]:
			st.set_color(col)
			st.add_vertex(v)
		# 水側地面較低。由相同莖基往斜上左右各抽一葉，靠近身體處互相錯開。
		for sign_side:float in [-1.,1.]:
			var blade:=cross*sign_side
			var tangent:=side*w*(1.20 if base.z>0 else .85)
			var join:=base+Vector3.UP*h*.27
			var elbow:=base+Vector3.UP*h*.60+blade*.24
			var tip:=base+Vector3.UP*h*.80+blade*.43
			for v in [join,elbow-tangent,elbow+tangent,elbow-tangent,tip,elbow+tangent]:
				st.set_color(col*.93)
				st.add_vertex(v)
		if i%7==0:
			var tip_axis:=Vector3.UP*.19+side*.045
			for orientation in [side,cross]:
				var width:Vector3=orientation*.032
				for v in [top,top+tip_axis*.46-width,top+tip_axis,top,top+tip_axis,top+tip_axis*.46+width]:
					st.set_color(Color("#796a46").srgb_to_linear())
					st.add_vertex(v)
	st.generate_normals()
	var m:=StandardMaterial3D.new()
	m.vertex_color_use_as_albedo=true
	m.roughness=.97
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	st.set_material(m)
	return st.commit()
