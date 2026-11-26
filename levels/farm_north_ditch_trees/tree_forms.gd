extends RefCounted
## 和現役樹的著色器共用五個部位。枝與葉跟著各自的 ToyBuild 分段落下。

static func make(leafy: bool) -> Mesh:
	var bark := Color("7b624b") if leafy else Color("765749")
	var leaf := Color("788f49") if leafy else Color("51694e")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	branch(surface, 0, Vector3(0,-.51,0), Vector3(0,.52,0), .45,.36,bark)
	branch(surface, 1, Vector3(0,-.52,0), Vector3(0,.51,0), .42,.23,bark)
	if leafy:
		branch(surface, 1, Vector3(0,-.18,0), Vector3(-1.85,.57,.32), .32,.13,bark)
		branch(surface, 1, Vector3(0,.02,0), Vector3(1.63,.49,-.37), .30,.11,bark)
		branch(surface, 1, Vector3(0,-.02,0), Vector3(-.24,.49,1.18), .32,.12,bark)
	else:
		branch(surface, 0, Vector3(0,-.21,0), Vector3(-.89,.35,.18), .32,.17,bark)
		branch(surface, 1, Vector3(0,-.39,0), Vector3(.96,.26,.37), .32,.11,bark)
		branch(surface, 1, Vector3(0,-.20,0), Vector3(-1.16,.36,-.39), .35,.15,bark)
	for slot in range(2,5):
		var bias := float(slot-2)
		var tally := [
			[Vector3(-.19,-.05,.10), Vector3(.64,.82,.78)],
			[Vector3(.18,.045,-.10), Vector3(.58,.91,.70)],
			[Vector3(.02,.11,.16), Vector3(.56,.68,.74)],
		]
		for i in tally.size():
			var offset: Vector3 = tally[i][0]
			var scale: Vector3 = tally[i][1]
			if not leafy:
				offset.y -= .07 * i
				scale.y *= .93 + .08 * bias
			lump(surface,slot,offset,scale,leaf.lightened(.055*i+.03*bias),slot*3+i)
	surface.generate_normals()
	return surface.commit()

static func branch(st: SurfaceTool, slot: int, start: Vector3, end: Vector3, lower: float, upper: float, bark: Color) -> void:
	var axis := (end-start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	var forward := axis.cross(right)
	for i in 7:
		var a := cos(TAU*i/7.)*right+sin(TAU*i/7.)*forward
		var b := cos(TAU*(i+1)/7.)*right+sin(TAU*(i+1)/7.)*forward
		var lo := start+a*lower
		var lo_b := start+b*lower
		var hi := end+a*upper
		var hi_b := end+b*upper
		var tone := bark.darkened(float(i%3)*.075)
		tri(st, slot, lo, hi_b, lo_b, tone)
		tri(st, slot, lo, hi, hi_b, tone)
		tri(st, slot, end, hi_b, hi, bark.lightened(.10))
		tri(st, slot, start, lo, lo_b, bark)

static func lump(st: SurfaceTool, slot: int, center: Vector3, scale: Vector3, color: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 367+seed*319
	var rings := []
	for layer in 3:
		var row := []
		for i in 7:
			var a := TAU*i/7. + .18*seed + .11*layer
			var bulge := [0.38,0.54,0.38]
			var r: float = bulge[layer]*rng.randf_range(.88,1.09)
			var y: float = [-.48,-.11,.28][layer]+rng.randf_range(-.065,.065)
			row.append(center+Vector3(cos(a)*r,y,sin(a)*r)*scale)
		rings.append(row)
	var lower := center+Vector3(-.04,-.5,.01)*scale
	var upper := center+Vector3(.07,.5,-.05)*scale
	for i in 7:
		var j := (i+1)%7
		tri(st,slot,lower,rings[0][i],rings[0][j],color.darkened(.22))
		for k in 2:
			var tint := color.darkened((2-k)*.07+.03*(i%2))
			tri(st,slot,rings[k][i],rings[k+1][i],rings[k+1][j],tint)
			tri(st,slot,rings[k][i],rings[k+1][j],rings[k][j],tint)
		tri(st,slot,upper,rings[2][j],rings[2][i],color.lightened(.10))

static func tri(st: SurfaceTool, slot: int, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point in [a,b,c]:
		st.set_smooth_group(-1)
		st.set_uv(Vector2(slot,0))
		st.set_color(color.srgb_to_linear())
		st.add_vertex(point)
