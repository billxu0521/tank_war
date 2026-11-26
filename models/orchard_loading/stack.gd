extends StaticBody3D
## 以固定槽位保存每個原筐的身分。移走下層後，上面的筐落在下一個承托面。
signal contents_changed(mask: int)
const TIER_HEIGHT := 0.475
var intact_mask := 0
var bins: Array[Node3D] = []

func _ready() -> void:
	for child in get_children():
		if child.name.begins_with("Bin"):
			bins.append(child)
	apply_mask((1 << bins.size()) - 1)

func apply_mask(mask: int) -> void:
	var filtered := mask & ((1 << bins.size()) - 1)
	if filtered == intact_mask:
		return
	intact_mask = filtered
	var level := 0
	for i in bins.size():
		var remains := (filtered & (1 << i)) != 0
		bins[i].visible = remains
		if remains:
			bins[i].position.y = level * TIER_HEIGHT
			level += 1
	var col: CollisionShape3D = $Solid
	if level > 0:
		var shape: BoxShape3D = col.shape
		shape.size.y = level * TIER_HEIGHT
		col.position.y = shape.size.y * 0.5
	col.set_deferred("disabled", level == 0)
	contents_changed.emit(intact_mask)

func remove_slot(slot: int) -> void:
	if slot >= 0 and slot < bins.size():
		apply_mask(intact_mask & ~(1 << slot))

func slot_at(point: Vector3) -> int:
	var level := maxi(0, floori((to_local(point).y - 0.0001) / TIER_HEIGHT))
	var live: Array[int] = []
	for i in bins.size():
		if intact_mask & (1 << i):
			live.append(i)
	return live[mini(level, live.size() - 1)] if not live.is_empty() else -1

func on_shot(point: Vector3, _who: Variant, _direction: Vector3) -> void:
	if is_multiplayer_authority():
		remove_slot(slot_at(point))
