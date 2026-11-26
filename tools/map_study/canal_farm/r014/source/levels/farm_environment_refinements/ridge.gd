extends RefCounted
## A v3.0 北地分水埂。剖面沿埂由田頭向田內收低，橫向保留通行緩坡。
const STATIONS := [
	[-6.8,0.00,.30,.25,0.],[-5.7,.29,1.7,1.15,-.10],[-4.3,.86,2.65,2.17,-.17],
	[-2.8,1.54,3.35,3.10,-.18],[-1.1,1.80,3.80,3.60,-.13],[.9,1.83,3.78,3.52,.05],
	[2.6,1.69,3.63,3.33,.16],[3.8,1.04,3.31,2.72,.21],[5.4,.38,2.31,1.55,.13],[6.78,0.,.66,.31,0.]]
const CROSS := [[-1.,0.],[-.68,.25],[-.23,.81],[.04,1.],[.32,.76],[.68,.32],[1.,0.]]
static func make(farm:Node3D) -> ArrayMesh:
	var axis := Vector2(cos(deg_to_rad(20.)),sin(deg_to_rad(20.)))
	var side := axis.orthogonal()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev:Array[Vector3]=[]
	for s:Array in STATIONS:
		var row:Array[Vector3]=[]
		for c:Array in CROSS:
			var width:float=s[2] if c[0]<0 else s[3]
			var p:Vector2 = Vector2(23,-77)+axis*float(s[0])+side*(c[0]*width+s[4])
			row.append(Vector3(p.x,lerpf(-.016,s[1],c[1]),p.y))
		if not prev.is_empty():
			for j in row.size()-1:
				farm.top_triangle(st,prev[j],row[j],row[j+1])
				farm.top_triangle(st,prev[j],row[j+1],prev[j+1])
		prev=row
	st.generate_normals()
	st.index()
	return st.commit()
