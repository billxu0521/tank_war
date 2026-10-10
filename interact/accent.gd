class_name Accent
## 可互動物件（門、梯子、補給箱）的固定強調色：整個疊一層強調色 #C65A35 的加亮，看著時更亮。
## 美術風格指南 §11：這個顏色只給能按 F 的東西用，場景其他地方不要用（2026-10-10 FPS 角度評估 #7）。
## 跟蛋的加亮（main.gd 的 _skin_egg）同一個做法

const COLOR := Color(0.776, 0.353, 0.208)
static var IDLE := _overlay(0.25)
static var FOCUS := _overlay(0.55)


static func _overlay(k: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(COLOR.r * k, COLOR.g * k, COLOR.b * k)   # 不能 COLOR * k：透明度也會被乘掉
	return m


## 底下所有網格都疊上平常的加亮
static func mark(n: Node) -> void:
	_apply(n, IDLE)


## 看著／移開視線（cowboy.gd 的 update_focus）
static func focus(n: Node, on: bool) -> void:
	if is_instance_valid(n):
		_apply(n, FOCUS if on else IDLE)


static func _apply(n: Node, m: Material) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
