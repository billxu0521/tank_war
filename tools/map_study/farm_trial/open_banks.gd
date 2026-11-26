extends "res://tools/map_study/farm_trial/connections.gd"
## 保留三處農務渡點，接入普通渠段可就近回岸的地形與同形碰撞。
func _ready() -> void:
	super()
	if not preload("res://levels/canal_banks/install.gd").install(self):
		push_error("農莊新渠岸未接上，請核對場地、水面與地表植被版本。")
