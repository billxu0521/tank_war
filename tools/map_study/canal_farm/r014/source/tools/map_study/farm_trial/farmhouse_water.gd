extends "res://tools/map_study/farm_trial/west_water.gd"

func _ready() -> void:
	super()
	preload("res://models/farm_ne_house/install.gd").install(self)
