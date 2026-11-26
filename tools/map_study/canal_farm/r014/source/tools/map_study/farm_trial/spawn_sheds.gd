extends "res://tools/map_study/farm_trial/north_yard.gd"

func _ready() -> void:
	super()
	preload("res://models/farm_spawn_sheds/install.gd").install(self)
