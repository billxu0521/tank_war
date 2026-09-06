class_name Fx
extends RefCounted
## 一次性視覺效果：生一個網格，放大 + 淡出，然後自己刪掉。
## 純表演，不影響傷害判定，所以不需要同步——各端各自播。

static func burst(parent: Node3D, mesh: PrimitiveMesh, color: Color,
		pos: Vector3, from: Vector3, to: Vector3, secs: float) -> void:
	if parent == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	mi.position = pos
	mi.scale = from

	var t := mi.create_tween().set_parallel()
	t.tween_property(mi, "scale", to, secs)
	t.tween_property(mat, "albedo_color:a", 0.0, secs)
	t.chain().tween_callback(mi.queue_free)
