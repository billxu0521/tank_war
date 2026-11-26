extends StaticBody3D
## 一件可拆實物。頂點色、可碰撞的盒及穩定名稱同屬此節點。
const FACES := [[4,5,7,6],[1,0,2,3],[5,1,3,7],[0,4,6,2],[6,7,3,2],[0,1,5,4]]
const NORMALS := [Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN]
static var paint: StandardMaterial3D
var surface: SurfaceTool
var visible_mesh: MeshInstance3D
var present := true

func cuboid(p:Vector3, size:Vector3, tint:Color, solid:=true, angle:=Vector3.ZERO) -> void:
	if not surface:
		surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var basis_=Basis.from_euler(angle)
	var corners:=PackedVector3Array()
	for z in [-.5,.5]:
		for y in [-.5,.5]:
			for x in [-.5,.5]:
				corners.append(p+basis_*(Vector3(x,y,z)*size))
	for face in 6:
		for n in [0,2,1,0,3,2]:
			surface.set_normal(basis_*NORMALS[face])
			surface.set_color(tint.srgb_to_linear())
			surface.add_vertex(corners[FACES[face][n]])
	if solid:
		var shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=size
		shape.shape=box
		shape.transform=Transform3D(basis_,p)
		add_child(shape)

func gable(center:Vector3, thickness:float, span:float, rise:float, tint:Color) -> void:
	if not surface:
		surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices:=PackedVector3Array()
	for edge:float in [-.5,.5]:
		for yz:Vector2 in [Vector2(0,-span*.5),Vector2(0,span*.5),Vector2(rise,0)]:
			vertices.append(center+Vector3(edge*thickness,yz.x,yz.y))
	for indices:Array in [[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]]:
		var a:=vertices[indices[0]]
		var b:=vertices[indices[1]]
		var c:=vertices[indices[2]]
		var normal:Vector3=(b-a).cross(c-a).normalized()
		var outward:Vector3=(a+b+c)/3.-(center+Vector3.UP*rise/3.)
		if normal.dot(outward)<0:
			normal=-normal
			var swap:=b
			b=c
			c=swap
		for pt in [a,c,b]:
			surface.set_normal(normal)
			surface.set_color(tint.srgb_to_linear())
			surface.add_vertex(pt)
	var collision:=CollisionShape3D.new()
	var convex:=ConvexPolygonShape3D.new()
	convex.points=vertices
	collision.shape=convex
	add_child(collision)

func finish() -> void:
	if not surface: return
	if not paint:
		paint=StandardMaterial3D.new()
		paint.vertex_color_use_as_albedo=true
		paint.roughness=.87
		paint.metallic_specular=.23
	visible_mesh=MeshInstance3D.new()
	visible_mesh.name="Assembly"
	visible_mesh.mesh=surface.commit()
	visible_mesh.material_override=paint
	add_child(visible_mesh)
	surface=null

func set_present(value:bool) -> void:
	present=value
	visible=value
	for shape in get_children():
		if shape is CollisionShape3D: shape.set_deferred("disabled",not value)

