extends "res://tools/map_study/farm_trial/bank_returns.gd"

func place_milk_furniture(shed: Node3D) -> void:
	super(shed)
	shed.get_node("MilkReceiving").add_child(preload("res://levels/milk_yard/yard_surface.tscn").instantiate())
