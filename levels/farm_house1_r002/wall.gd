extends StaticBody3D
## 接手方先判斷是否命中、是否達到允許的破壞條件，再切換對應構件。
var present := true
var leaf: Door
var glass: StaticBody3D

func set_present(value: bool) -> void:
	present = value
	visible = value
	for shape in get_children():
		if shape is CollisionShape3D:
			shape.set_deferred("disabled",not value)
	if leaf:
		leaf.visible = value
		leaf.get_node("Solid").set_deferred("disabled",not value)
	if glass:
		glass.wall_present = value
		glass.update_pane()
