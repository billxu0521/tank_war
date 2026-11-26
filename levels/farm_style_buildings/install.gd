extends RefCounted
## 灌渠農莊 A v2.9d。原地圖完成建置後套用，只替換外觀。
const PARTS := preload("res://levels/farm_style_buildings/farm_parts.glb")
const PLACEMENT := preload("res://levels/farm_style_buildings/placement.json")
const PAINT := preload("res://levels/farm_style_buildings/vertex_paint.gdshader")
const FINISH := &"FarmStyleBuildings"
const ROOTS := [
	"MilkStation", "LoadingStation", "RegistrationRoom", "PayOffice", "NortheastWorkyard",
	"WestToolHouse", "NortheastFarmhouse", "EastGageHouse", "FarmCanalWorks",
	"NorthwestWagonShed", "SoutheastUnloadingShed", "StoredGateBoards",
	"農舍北側柴垛", "北站後場木料", "南場農車備柴", "南田筐料板垛", "北集乳車路木料"
]
const PROP_NAMES := ["props_Wagon","kits_HayBlock","props_HayBale","clutters_LogPile",
	"kits_FenceRail","kits_FencePost","kits_Crate","hitches_FenceRail"]
const INK := {
	"oak":"b58756", "end":"d6ad7c", "honey":"caa06d", "timber":"785138", "red":"bd6846",
	"oxblood":"a34f39", "cream":"e9cf9d", "pine":"48685a", "teal":"578477", "clay":"bd956b",
	"adobe":"a1724d", "slate":"536467", "zinc":"748380", "stone":"998b76", "shale":"7e7464",
	"iron":"414744", "shade":"463f36", "straw":"c1a06a"
}
const MATERIALS := {
	"oak":"oak", "wood":"oak", "wood2":"honey", "p_wood":"honey", "p_wood_d":"timber",
	"p_band":"iron", "p_canvas":"cream", "h_iron":"iron", "h_post":"pine", "h_wood0":"oak",
	"h_wood1":"timber", "h_wood2":"honey", "h_trim":"end", "h_dark":"shade",
	"h_log0":"oak", "h_log1":"timber", "h_log2":"honey", "c_log_end":"end", "p_roof":"slate", "p_red":"oxblood", "p_red_d":"red", "p_trim":"cream",
	"pine":"oak", "old":"timber", "heart":"timber", "heartwood":"timber", "weathered boards":"oak",
	"sill":"timber", "cut":"end", "cut edge":"end", "sawn":"honey", "endgrain":"end",
	"seams":"shade", "iron":"iron", "rust":"oxblood", "stone":"stone", "stone2":"shale",
	"stone3":"stone", "fieldstone":"stone", "grout":"shale", "roof":"pine", "tin":"slate",
	"galvanized sheet":"slate", "sheet":"slate", "fold":"teal", "tin basin":"zinc",
	"milk can metal":"zinc", "rolled hoop":"iron", "lime":"cream", "plaster":"clay",
	"earth":"clay", "pot":"adobe", "brick":"adobe", "lightbrick":"clay", "shutter":"pine",
	"shutter_light":"teal", "paint":"teal", "board":"pine", "edge":"zinc", "worn":"end",
	"base":"adobe", "reveal":"shade", "inner":"shade", "mortar":"shale", "paper":"cream",
	"chalk":"cream", "k_hay_core":"timber", "k_hay0":"straw", "k_hay1":"honey", "k_hay2":"straw",
	"k_twine":"timber", "detail_vertex_grain_canvas":"straw", "detail_vertex_seam":"timber",
	"detail_vertex_family_ink":"oxblood","detail_vertex_pledge_paint":"red","detail_vertex_iron":"iron"
}

static func install(farm: Node3D) -> void:
	if farm.has_meta(&"farm_style_buildings_scheduled") or farm.has_node(NodePath(FINISH)):
		return
	if not farm.is_node_ready():
		farm.set_meta(&"farm_style_buildings_scheduled", true)
		farm.ready.connect(_install_ready.bind(farm), CONNECT_ONE_SHOT)
		return
	_install_ready(farm)

static func _install_ready(farm: Node3D) -> void:
	if farm.has_node(NodePath(FINISH)):
		return
	var models := {}
	var packed := PARTS.instantiate()
	for node: MeshInstance3D in packed.find_children("*", "MeshInstance3D", true, false):
		models[String(node.name)] = node.mesh
	packed.free()
	var added := Node3D.new()
	added.name = FINISH
	farm.add_child(added)
	# glTF 原檔有線性色票，4.7.2 匯入的材質卻未啟用頂點色。直接綁在每個遊戲實例。
	var pigment := StandardMaterial3D.new()
	pigment.resource_name = "Farm02_06_VertexPigment"
	pigment.vertex_color_use_as_albedo = true
	pigment.vertex_color_is_srgb = false
	pigment.roughness = .87
	pigment.metallic_specular = .23
	var painted := {}
	var count := 0
	for job: Dictionary in PLACEMENT.data:
		var key := String(job.model)
		var source := farm.get_node_or_null(NodePath(job.targets[0])) as Node3D
		if not source or not models.has(key):
			push_warning("農莊建築缺少對應部件 " + key)
			continue
		var visual := MeshInstance3D.new()
		visual.name = key
		visual.mesh = models[key]
		visual.material_override = pigment
		added.add_child(visual)
		if job.get("local_wall",false):
			visual.transform = farm.global_transform.affine_inverse() * source.global_transform
			visual.position.y -= (source as MeshInstance3D).get_aabb().size.y * 0.5
		else:
			visual.position = Vector3(job.x,0,job.z)
			visual.rotation.y = deg_to_rad(job.yaw)
		# 只停畫原網格，物理、節點可見性及子件行為繼續由原地圖管理。
		if source is MeshInstance3D:
			source.layers = 0
		for child: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if job.has("original_meshes") and (not child.mesh or child.mesh.resource_name not in job.original_meshes):
				continue
			child.layers = 0
	for target: String in ROOTS:
		var unit := farm.get_node_or_null(NodePath(target))
		if not unit:
			continue
		for view: MeshInstance3D in unit.find_children("*","MeshInstance3D",true,false):
			if view.layers == 0 or not view.mesh:
				continue
			if view.mesh.resource_name == "wall_bay_mesh":
				view.mesh = models["WallBayWeigh" if target == "RegistrationRoom" else "WallBayPay"]
				view.material_override = pigment
				count += 1
				continue
			count += _paint_view(view, painted, target)
	# 農車、草捆等散放件的節點名稱由引擎配發，用模型身分辨認。
	for view: MeshInstance3D in farm.find_children("*","MeshInstance3D",true,false):
		if view.mesh and view.mesh.resource_name in PROP_NAMES and view.layers != 0:
			count += _paint_view(view, painted, "")
	for scatter: MultiMeshInstance3D in farm.find_children("*","MultiMeshInstance3D",true,false):
		var mm := scatter.multimesh
		if not mm or not mm.mesh or not mm.mesh.resource_name in PROP_NAMES:
			continue
		# 散布保留全部實例位置、色彩與數量，僅給原農務網格一個私有材質副本。
		var resource_key := "mesh:" + mm.mesh.resource_name
		if not painted.has(resource_key):
			var copy := mm.mesh.duplicate() as Mesh
			for i in copy.get_surface_count():
				var mat := _replacement(copy.surface_get_material(i), painted, "", copy.resource_name)
				if mat: copy.surface_set_material(i,mat)
			painted[resource_key] = copy
		mm.mesh = painted[resource_key]
		count += 1
	added.set_meta(&"styled_placements", added.get_child_count())
	added.set_meta(&"painted_originals", count)

static func _paint_view(view: MeshInstance3D, cache: Dictionary, site: String) -> int:
	# 文字、圖卡及作業地表沿用原材質；動態木板的 MultiMesh 另由 ToyBuild 控制。
	if view.mesh is PlaneMesh or view.mesh is QuadMesh:
		return 0
	if view.material_override != null:
		return 0
	var changed := false
	for i in view.mesh.get_surface_count():
		var before := view.get_active_material(i)
		var mat := _replacement(before,cache,site,view.mesh.resource_name)
		if mat and mat != before:
			view.set_surface_override_material(i,mat)
			changed = true
	return int(changed)

static func _replacement(before: Material, cache: Dictionary, site: String, mesh_name: String) -> Material:
	if not before is BaseMaterial3D:
		return null
	var base := before as BaseMaterial3D
	if base.albedo_texture or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var label := base.resource_name.to_lower().get_slice(".",0)
	var swatch := String(MATERIALS.get(label,""))
	if mesh_name in ["props_Wagon","HarvestWagon_r001_Wagon_002","NorthwestWagonShed_r002_Wagon_002","UnloadingRack_Wagon_002"] and label == "p_wood_d":
		swatch = "oxblood"
	if label.begins_with("p_hay") or label.begins_with("hay"):
		swatch = "timber" if label.ends_with("_d") else "straw"
	if label in ["k_board","k_wood","k_crate"]: swatch = "oak"
	if label.begins_with("k_wood") or label.begins_with("p_log"): swatch = "timber" if label.ends_with("d") else "oak"
	if swatch.is_empty() and label in ["orchard_kit_wood","detail_vertex_wood","kittimberandstone"]:
		var flavour := "painted:" + ("roof" if "RoofDeck" in mesh_name else "wood")
		if not cache.has(flavour):
			var shader := ShaderMaterial.new()
			shader.shader = PAINT
			shader.set_shader_parameter(&"shadow_paint",Color(INK.shade))
			shader.set_shader_parameter(&"timber_paint",Color(INK.pine if flavour.ends_with("roof") else INK.oak))
			shader.set_shader_parameter(&"cut_paint",Color(INK.teal if flavour.ends_with("roof") else INK.end))
			cache[flavour] = shader
		return cache[flavour]
	if swatch.is_empty() and label == "" and site in ["農舍北側柴垛","北站後場木料","南場農車備柴","南田筐料板垛","北集乳車路木料"]:
		swatch = "timber" if base.albedo_color.r < 0.50 else "oak"
	if swatch.is_empty():
		return null
	if not cache.has(swatch):
		var paint := StandardMaterial3D.new()
		paint.resource_name = "Farm02_06_" + swatch
		paint.albedo_color = Color(INK[swatch])
		paint.roughness = .87
		paint.metallic_specular = .23
		cache[swatch] = paint
	return cache[swatch]
