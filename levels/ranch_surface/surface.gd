extends RefCounted
## 現有168m ranch地面方案。僅改材質與無碰撞裝飾；時段仍由Period管理。
const ROOT = "res://levels/ranch_surface/"
const DECAL_LAYER = 1 << 19
static func install(main: Node, ground: StaticBody3D) -> bool:
	if main.level_path != "res://levels/ranch.tscn" or main.ARENA != 168.0:
		return false
	if OS.get_cmdline_user_args().has("--original-ground") or OS.get_cmdline_user_args().has("--server"):
		return false
	var mesh: MeshInstance3D = ground.get_child(0)
	mesh.material_override = load(ROOT + "ground.res")
	mesh.layers |= DECAL_LAYER
	# 維持同一mesh.material物件，讓Period與PixelStyle持續更新實際描線。
	var outline: ShaderMaterial = main.get_node(^"Arena/Outline").mesh.material
	var data: ShaderMaterial = load(ROOT + "outline_data.res")
	outline.shader = load(ROOT + "outline.gdshader")
	for key: StringName in [&"ground_height", &"sample_mask", &"grid_n"]:
		outline.set_shader_parameter(key, data.get_shader_parameter(key))
	for name: String in ["decor.scn", "wear.scn"]:
		var node: Node3D = load(ROOT + name).instantiate()
		node.visible = true
		main.get_node(^"Arena").add_child(node)
	return true
