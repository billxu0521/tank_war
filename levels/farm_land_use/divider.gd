extends RefCounted
## 採用 VB／MB 的 C 案灌溉田埂。u 沿埂，v 橫切埂頂與兩側落坡。
static func build(farm:Node3D)->ArrayMesh:
	var axis:=Vector2.RIGHT.rotated(deg_to_rad(20.))
	var side:=axis.orthogonal()
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous:Array[Vector3]=[]
	for i in 13:
		var t:float=i/12.
		var long:float=lerpf(-6.7,6.7,t)
		var outline:float=pow(maxf(0.,sin(t*PI)),.67)
		var centerline:float
		var height:float
		var section:Array
		# 草埂向田尾收尖，脊線稍彎，讓田路側有較長的緩坡。
		centerline=.91*sin(t*PI*1.6)*outline
		height=1.64*pow(outline,1.15)*(.88+.12*sin(t*PI*1.35))
		section=[[-1.,0.],[-.76,.10],[-.48,.39],[-.20,.79],[.05,1.],[.29,.80],[.61,.35],[.84,.10],[1.,0.]]
		var row:Array[Vector3]=[]
		for sample:Array in section:
			var v:=float(sample[0])
			var width:float=(4.02 if v<0 else 2.93)
			var pt:Vector2=Vector2(23,-77)+axis*long+side*(centerline+v*(.22+width*outline))
			row.append(Vector3(pt.x,lerpf(-.019,height,sample[1]),pt.y))
		if not previous.is_empty():
			for j in row.size()-1:
				farm.top_triangle(st,previous[j],row[j],row[j+1])
				farm.top_triangle(st,previous[j],row[j+1],previous[j+1])
		previous=row
	st.generate_normals()
	st.index()
	return st.commit()
