@tool
extends StaticBody3D
## 南側耕地翻出的殘埂。中心保留一段完整土脊，兩端隨車路回到田面。
## 沿田界的距離、脊線側移、半寬、離地高度，單位為公尺。
const SECTIONS := [
	Vector4(-3.05, -.08, .29, .015),
	Vector4(-2.35, -.07, .67, .15),
	Vector4(-1.30, .03, .86, .30),
	Vector4(.12, .08, .94, .37),
	Vector4(1.26, .02, .83, .32),
	Vector4(2.16, -.09, .73, .17),
	Vector4(3.0, -.12, .32, .015),
]

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var previous := PackedVector3Array()
	for s: Vector4 in SECTIONS:
		var current := PackedVector3Array([
			Vector3(s.x, -.025, s.y-s.z),
			Vector3(s.x, s.w*.91, s.y-s.z*.17),
			Vector3(s.x, s.w, s.y+s.z*.13),
			Vector3(s.x, -.025, s.y+s.z),
		])
		if not previous.is_empty():
			for i in 3:
				for p: Vector3 in [previous[i],current[i],current[i+1],previous[i],current[i+1],previous[i+1]]:
					surface.set_color(Color.WHITE if p.y>.02 else Color(.86,.87,.84))
					surface.add_vertex(p)
		previous = current
	surface.generate_normals()
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("#ad9877")
	earth.vertex_color_use_as_albedo = true
	earth.roughness = .95
	surface.set_material(earth)
	var mesh := surface.commit()
	$Soil.mesh = mesh
	$Ground.shape = mesh.create_trimesh_shape()
