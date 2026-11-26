extends "res://levels/farm_house1_r002/fixed_window.gd"
## 玻璃沿用 BLD-01 的玻璃、內格一起脫落。同步及支撐牆隨建築局部管理。
var wall_present := true
var intact_layer: int
var intact_mask: int

func _ready() -> void:
	intact_layer = collision_layer
	intact_mask = collision_mask
	add_to_group(&"farm_fixed_glazing")

func on_shot(_point: Vector3, _source: Node, _direction: Vector3) -> void:
	if wall_present and not broken and multiplayer.is_server():
		set_broken.rpc(true)

@rpc("authority","call_local","reliable")
func set_broken(value: bool) -> void:
	broken = value
	update_pane()

func update_pane() -> void:
	var active := wall_present and not broken
	visible = active
	collision_layer = intact_layer if active else 0
	collision_mask = intact_mask if active else 0
	collider.set_deferred("disabled",not active)
