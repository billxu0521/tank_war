extends AnimatableBody3D
## 單人候選的門／窗扇；移動中重新檢查阻擋，尚未實作多人同步。
var prompt := "開啟"
var fraction := 0.0
var target := 0.0
var base_transform := Transform3D.IDENTITY
var swing := 0.0
var shape: BoxShape3D
var shape_offset := Vector3.ZERO
var blocked := false
var bidirectional := false

func pose(t: float) -> Transform3D:
	return Transform3D(base_transform.basis * Basis(Vector3.UP, swing * t), base_transform.origin)

func clear_at(t: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = get_parent().global_transform * pose(t) * Transform3D(Basis.IDENTITY, shape_offset)
	q.exclude = [get_rid()]
	q.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func set_fraction(t: float) -> void:
	fraction = t
	target = t
	transform = pose(t)
	prompt = "關閉" if absf(t) > 0.5 else "開啟"

func interact(who: Node) -> void:
	if not is_equal_approx(fraction, target):
		return
	var next := 0.0 if absf(fraction) > 0.001 else 1.0
	if next != 0.0 and bidirectional and who is Node3D:
		var closed_global: Transform3D = get_parent().global_transform * base_transform
		var operator_local: Vector3 = closed_global.affine_inverse() * who.global_position
		# 局部+Z側的操作者，門中心須往-Z移；反側則反向。
		next = signf(operator_local.z * swing)
		if is_zero_approx(next):
			prompt = "請站到門的一側再開啟"
			return
	for i in range(1, 31):
		if not clear_at(lerpf(fraction, next, float(i) / 30.0)):
			blocked = true
			prompt = "受阻，移開後再試"
			return
	blocked = false
	target = next

func _physics_process(delta: float) -> void:
	if is_equal_approx(target, fraction):
		return
	var next := move_toward(fraction, target, delta * 2.5)
	if clear_at(next):
		fraction = next
		transform = pose(fraction)
		prompt = "關閉" if absf(target) > 0.5 else "開啟"
	else:
		target = fraction
		blocked = true
		prompt = "受阻，移開後再試"
