extends "res://tools/map_study/farm_trial/levee_soil.gd"
## 東堤的堤頂保留通行，西來渠水經堤下涵洞到木閘。
const BANK := preload("res://levels/canal_banks/profile.gd")
const SOIL := preload("res://levels/gate_water/channel_soil.gdshader")
const EDGES := preload("res://tools/map_study/farm_trial/farm_edges.gd")

func _ready() -> void:
	super()
	var field := get_node(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	var clay := ShaderMaterial.new()
	clay.shader = SOIL
	clay.set_shader_parameter(&"water_level",BANK.WATER_Y)
	for s in field.mesh.get_surface_count():
		if field.mesh.surface_get_name(s) in ["渠岸","渠道底面示色","西灘涉水面"]:
			field.set_surface_override_material(s,clay)
	for label in ["西灘西端淤坡","西灘東端淤坡","東堤上游護腳土坡","卸料端北側回岸坡"]:
		(get_node(NodePath(label)) as MeshInstance3D).material_override = clay
	var bank := get_node(^"WestBank")
	var mud := bank.find_child("BankMud",true,false) as MeshInstance3D
	mud.hide()
	var outside := get_node(^"BeyondFarm")
	outside.get_node(^"WestWaterExtension").free()
	EDGES.extend_water(outside,bank.find_child("Water",true,false))

