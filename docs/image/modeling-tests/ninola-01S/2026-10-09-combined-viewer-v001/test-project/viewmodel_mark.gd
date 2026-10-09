extends RefCounted
class_name Viewmodel
const TARGET_MARK := 0.87
static func mark_meshes(root: Node, mark: float) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == preload("res://facet.gdshader"):   # 共用材質（main.gd 的 _to_facet）
				mat = mat.duplicate()
				mat.set_shader_parameter(&"roughness", mark)
				mi.set_surface_override_material(i, mat)
			elif mat is BaseMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:   # 火光這類半透明的不寫粗糙度，不用改
				mat = mat.duplicate()
				mat.roughness = mark
				mi.set_surface_override_material(i, mat)
