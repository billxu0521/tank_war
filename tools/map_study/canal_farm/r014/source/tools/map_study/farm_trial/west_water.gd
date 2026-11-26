extends "res://tools/map_study/farm_trial/spawn_sheds.gd"
## 西深渠 B 候選沿用 v2.3 的地形、兩座車棚及出生設定。
func _ready() -> void:
	super()
	var water := get_node("WestBank").find_child("Water", true, false) as MeshInstance3D
	if not water or not preload("res://levels/west_deep_water/install.gd").install(water):
		push_error("西深渠 B 水面缺少原網格或材質，請檢查 WestBank/Water。")
