extends StaticBody3D
## 玻璃與內窗格共用一次破壞；外框和窗臺屬於房屋。
@onready var collider := get_child(0) as CollisionShape3D
var broken := false

func on_shot(_point: Vector3, _source: Node, _direction: Vector3) -> void:
	if broken:
		return
	broken = true
	hide()
	collision_layer = 0
	collision_mask = 0
	collider.set_deferred("disabled", true)

## 牛仔翻越會略過途中的碰撞。僅在路線穿過這一面完整玻璃時阻擋起跳。
func blocks_crossing(start: Vector3, finish: Vector3, radius: float) -> bool:
	if broken: return false
	var a := to_local(start)
	var b := to_local(finish)
	if is_equal_approx(a.z, b.z) or a.z * b.z > 0: return false
	var crossing := a.lerp(b, a.z / (a.z - b.z))
	var size := (collider.shape as BoxShape3D).size
	return crossing.x >= -radius and crossing.x <= size.x + radius and crossing.y >= 0 and crossing.y <= size.y
