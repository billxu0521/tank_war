extends RefCounted
## 最終合成入口，於 FarmStyleEnvironment 建好後安裝。可與先安裝的局部環境包共用。
const LOCAL:=preload("res://levels/farm_environment_refinements/install.gd")
const EARTH:=preload("earth.gdshader")
const RIDGE:=preload("divider.gd")
const A_IMAGE:=preload("a.res")
const PLAN:=preload("usage.res")
const ZONES:=preload("zones.res")
static func install(farm:Node3D) -> void:
	if farm.has_meta(&"farm_land_use_ac"): return
	if not farm.has_node(^"FarmStyleEnvironment") or not farm.has_node(^"北地分水埂"):
		push_error("農路 A、田塊 C 需在農莊 A v3.0 基礎地景完成後安裝")
		return
	LOCAL.install(farm)
	var skin:=farm.get_node(^"FarmStyleEnvironment")
	var a:=ImageTexture.create_from_image(A_IMAGE)
	var use_map:=ImageTexture.create_from_image(PLAN)
	var zones:=ImageTexture.create_from_image(ZONES)
	var ground:=ShaderMaterial.new()
	ground.shader=EARTH
	ground.set_shader_parameter(&"soil_map",skin.soil[0].get_shader_parameter(&"soil_map"))
	ground.set_shader_parameter(&"a_map",a)
	ground.set_shader_parameter(&"usage_map",use_map)
	ground.set_shader_parameter(&"zones",zones)
	var upper_bank:=ground.duplicate() as ShaderMaterial
	upper_bank.set_shader_parameter(&"role",2)
	upper_bank.set_shader_parameter(&"water_level",skin.soil[2].get_shader_parameter(&"water_level"))
	var field:=farm.get_node(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	for i in field.mesh.get_surface_count():
		if field.mesh.surface_get_name(i)=="田間地表與農路":
			field.set_surface_override_material(i,ground)
		elif field.get_active_material(i)==skin.soil[2]:
			field.set_surface_override_material(i,upper_bank)
	for label in [^"西灘西端淤坡",^"西灘東端淤坡"]:
		var slope:=farm.get_node(label) as MeshInstance3D
		if slope.material_override==skin.soil[2]: slope.material_override=upper_bank
	var cover:=ground.duplicate() as ShaderMaterial
	cover.set_shader_parameter(&"role",4)
	for tile:MeshInstance3D in skin.find_children("Tile_*","MeshInstance3D",true,false):
		tile.material_override=cover
	var wheel_mats:={}
	for child in farm.get_children():
		if not child is MeshInstance3D or not child.material_override is StandardMaterial3D: continue
		var tone:Color=child.material_override.albedo_color
		var tag:=tone.to_html(false)
		if tag not in ["b8a186","897353"]: continue
		if not wheel_mats.has(tag):
			var wheel:=ground.duplicate() as ShaderMaterial
			wheel.set_shader_parameter(&"role",5)
			wheel.set_shader_parameter(&"old_track",tone)
			wheel_mats[tag]=wheel
		child.material_override=wheel_mats[tag]
	var bank:=farm.get_node(^"北地分水埂")
	var vb:=RIDGE.build(farm)
	var bank_view:=bank.find_children("*","MeshInstance3D",false,false)[0] as MeshInstance3D
	var ridge_soil:=ground.duplicate() as ShaderMaterial
	ridge_soil.set_shader_parameter(&"role",1)
	bank_view.mesh=vb
	bank_view.material_override=ridge_soil
	(bank.find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D).shape=vb.create_trimesh_shape()
	farm.set_meta(&"farm_land_use_ac",true)
