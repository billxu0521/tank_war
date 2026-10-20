class_name ModelMaterials
extends RefCounted
## 模型材質：平面化、折面、像素風、顆粒。全部靜態，不碰場景（原本在 main.gd 的場地區段，搬出來給 ArenaMap 和工具用）


## 樹的材質不要高光：朝太陽的面疊一層白色反光，會把葉子受光面的黃沖成灰，折面的明暗差就被吃掉。
## Blender 那邊設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 全部模型都不要高光：朝太陽的面疊一層反光會把顏色沖灰、反射粉色的天空（牆和門廊泛粉紫）。
## Blender 設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 網格被資源快取住，改一次之後各處 instantiate 出來的都是改好的那份（glb 要留著，快取才不會被丟掉）
const LEAVES_SHADER := preload("res://leaves.gdshader")
const FLAT_MODELS := ["res://models/props.glb", "res://models/trees.glb", "res://models/rocks.glb", "res://models/houses.glb", "res://models/kits.glb", "res://models/towns.glb",
	"res://models/groves.glb", "res://models/floras.glb", "res://models/clutters.glb",
	"res://models/cowboy.glb", "res://models/trex_hd.glb", "res://models/ninola.glb", "res://models/revolver.glb",
	"res://models/shotgun.glb", "res://models/rifle.glb", "res://models/lance.glb",
	"res://models/cowboy_tripo.glb", "res://models/ninola_tripo.glb", "res://models/revolver_tripo.glb", "res://models/shotgun_tripo.glb", "res://models/lance_tripo.glb"]   # Tripo 生成版（blender/cowboy_tripo.py、weapons_tripo.py）
static var _flat_keep: Array[PackedScene] = []
static func _flatten_models() -> void:
	if not _flat_keep.is_empty():
		return
	for path: String in FLAT_MODELS:
		var scene: PackedScene = load(path)
		_flat_keep.append(scene)
		var inst := scene.instantiate()
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if m:
					m.metallic_specular = 0.0
					m.metallic = 0.0
					if m.resource_name in ["p_wheat", "p_grass"]:   # 字串比對（StringName 放在陣列裡比不到）
						m.roughness = 0.5   # 描線跳過的記號（見 grass.gdshader）
					if m.resource_name.contains("leafcard"):   # 樹的葉片卡（blender/tree.py、grove.py）：換成會隨風擺的葉子材質
						var leaf := ShaderMaterial.new()          # （透明底挖空、不接收影子，見 leaves.gdshader）
						leaf.shader = LEAVES_SHADER
						leaf.set_shader_parameter(&"leaf_tex", m.albedo_texture)
						if m.resource_name.contains("yucca") or m.resource_name.contains("pine") or m.resource_name.contains("willow"):
							leaf.set_shader_parameter(&"leaf_px", 0.0)   # 細長尖葉切格後尖端剩碎方塊，放射狀形狀也沒了（收尾審查）
						if m.resource_name.begins_with("p_bush"):   # 灌木叢（props.py）：只有 1.6 公尺高，樹冠中心照樹的 3.5 公尺算的話整叢的法線朝下、一片暗
							leaf.set_shader_parameter(&"crown_height", 0.8)
							leaf.set_shader_parameter(&"tint", 0.85)   # 朝陽面的黃綠比樹亮半階，往橄欖綠壓
						mi.mesh.surface_set_material(i, leaf)   # 網格是共用的：場上每棵、遠景的樹都跟著換
						continue
					var px := _pixel_kind(m) if m.albedo_texture == null else &""
					if m.albedo_texture == null and px == &"":   # 材質可能好幾個網格共用，只疊一次
						_add_grain(m)
					var f := _to_facet(m)
					if f:
						if px != &"":
							_add_pixel(f, px)
						mi.mesh.surface_set_material(i, f)
		inst.free()

## 換成共用材質（facet.gdshader：打光分段，一面一面看得出來）。參數照抄；半透明、不受光、看板、
## 自己有用頂點色以外的特殊設定的（目前沒有）留原本的標準材質。同一個材質換一次，各處共用
const FACET_SHADER := preload("res://facet.gdshader")
## 材質分色（Shader 美術改善規格第 14 節）：材質名字含有這些字 → 哪一類。第一個對到的算數；人物、恐龍不分（原色）
const FACET_TYPES := [
	[["blued", "bore", "gunmetal", "steel", "iron", "c_metal", "lead", "p_band", "brass", "hull"], &"metal"],
	[["shing", "roof"], &"roof"],
	[["stone", "rock", "mortar", "chink"], &"stone"],
	[["leaf", "flora", "bush", "grass", "pine", "wheat", "scrub", "cactus"], &"plant"],
	[["wood", "plank", "log", "trim", "post", "bark", "h_lap", "p_red", "p_silo", "shut", "k_floor", "k_lid", "t_board", "h_inner"], &"wood"],
]
## 類別 → [暗部色調, 受光色調, 明度]：木頭暗部紫棕、受光金棕；石頭冷灰／暖灰；植物冷綠／黃綠；金屬冷灰／暖灰白
const FACET_TINTS := {
	&"wood": [Vector3(0.96, 0.90, 1.06), Vector3(1.06, 0.98, 0.84), 1.0],
	&"stone": [Vector3(0.92, 0.96, 1.06), Vector3(1.04, 1.0, 0.94), 1.0],
	&"roof": [Vector3(0.92, 0.96, 1.06), Vector3(1.04, 1.0, 0.94), 0.85],   # 屋頂比牆暗一段
	&"plant": [Vector3(0.90, 1.0, 0.98), Vector3(1.04, 1.06, 0.86), 1.0],
	&"metal": [Vector3(0.92, 0.96, 1.06), Vector3(1.04, 1.02, 0.98), 1.0],
}
static var _facet_of := {}
static func _to_facet(m: BaseMaterial3D) -> ShaderMaterial:
	if _facet_of.has(m):
		return _facet_of[m]
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
			or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return null
	var f := ShaderMaterial.new()
	f.shader = FACET_SHADER
	f.resource_name = m.resource_name   # 其他地方照名字認材質（_add_grain、葉片卡）
	f.set_shader_parameter(&"albedo", m.albedo_color)
	if m.albedo_texture:
		f.set_shader_parameter(&"albedo_tex", m.albedo_texture)
		f.set_shader_parameter(&"use_tex", true)
		f.set_shader_parameter(&"use_triplanar", m.uv1_triplanar)
	f.set_shader_parameter(&"use_vcol", m.vertex_color_use_as_albedo)
	f.set_shader_parameter(&"uv_scale", m.uv1_scale)
	f.set_shader_parameter(&"uv_offset", m.uv1_offset)
	f.set_shader_parameter(&"roughness", m.roughness)
	if m.emission_enabled:
		f.set_shader_parameter(&"emission", m.emission)
		f.set_shader_parameter(&"emission_energy", m.emission_energy_multiplier)
	var name := String(m.resource_name)
	for rule: Array in FACET_TYPES:
		if (rule[0] as Array).any(func(k: String) -> bool: return name.contains(k)):
			var t: Array = FACET_TINTS[rule[1]]
			f.set_shader_parameter(&"shade_tint", t[0])
			f.set_shader_parameter(&"lit_tint", t[1])
			f.set_shader_parameter(&"value", t[2])
			break
	_facet_of[m] = f
	return f

## 像素材質（tools/make_pixel_tex.py，16×16 一張鋪 1 公尺 = 16 格／公尺）：材質名字含有前面那個字 → 哪一張。
## 第一個對到的算數；對到的就不疊下面的程式雜訊。只做場景，人物、恐龍、手上的槍不加
const PIXEL_RULES := [
	# 樹冠、灌木的芯：近看會從葉片卡之間露出一顆平滑的多面體（橡樹審查），貼葉叢圖
	["leaf_core", &"foliage"], ["maple_core", &"foliage"], ["tree_pine_leaf", &"foliage"], ["tree_leaf_willow", &"foliage"],
	["yucca_dead", &"foliage"], ["p_bush", &"foliage"],
	["leaf", &""], ["pine", &""], ["bush", &""], ["lit", &""], ["lamp", &""], ["glass", &""],
	["bark", &"bark"],
	["mortar", &"plaster"], ["chink", &"plaster"],
	["rock_", &""],   # 天然大石頭：砌石牆的圖貼上去像馬賽克（第二輪審查），維持原本的程式雜訊
	["stone", &"stone"],
	["shing", &"roof"], ["roof", &"roof"],
	["hay", &"hay"],
	["flora_grass", &"blades"], ["p_grass", &"blades"],   # 草叢（樹葉、灌木葉子不加）
	["iron", &"metal"], ["p_band", &"metal"],
	# 房子外牆板（h_wood、搭接板 h_lap、收邊條 trim）：模型自己做了板條，橫板、直板兩種房子共用同一個材質，
	# 貼有板縫的木板圖會跟模型的板條交叉成格子布（第二輪審查）。改貼沒有方向的舊木頭斑駁（weathered），不畫板縫
	["h_wood", &"weathered"], ["h_lap", &"weathered"], ["trim", &"weathered"],
	["post", &"wood_v"],   # 直立的柱子：直紋（橫紋像纏膠帶）
	["p_red", &"wood_v"], ["p_silo", &"wood_v"],   # 直條板
	["wood", &"wood_h"], ["plank", &"wood_h"], ["log", &"wood_h"],
	["shut", &"wood_h"], ["p_white", &"wood_h"], ["h_inner", &"wood_h"], ["k_floor", &"wood_h"],
	["t_board", &"wood_h"],
]
static var _pixel_tex := {}

static func _pixel_kind(m: BaseMaterial3D) -> StringName:
	var name := String(m.resource_name)
	if name in ["wood", "wood2", "wood_red"]:
		return &""   # 槍的木頭
	for rule: Array in PIXEL_RULES:
		if name.contains(rule[0]):
			var kind: StringName = rule[1]
			return kind if kind != &"" and ResourceLoader.exists("res://assets/textures/pixel/%s.png" % kind) else &""
	return &""

static func _add_pixel(f: ShaderMaterial, kind: StringName) -> void:
	if not _pixel_tex.has(kind):
		var img := (load("res://assets/textures/pixel/%s.png" % kind) as Texture2D).get_image()
		img.decompress()
		var sum := 0.0
		for y in img.get_height():
			for x in img.get_width():
				sum += pow(img.get_pixel(x, y).r, 2.2)   # png 是 sRGB，平均要用線性的
		img.generate_mipmaps()   # 遠處用小一級的圖（最近點），不然整片閃
		_pixel_tex[kind] = [ImageTexture.create_from_image(img), sum / (img.get_width() * img.get_height())]
	f.set_shader_parameter(&"pixel_tex", _pixel_tex[kind][0])
	f.set_shader_parameter(&"pixel_mean", _pixel_tex[kind][1])
	if kind == &"foliage":
		f.set_shader_parameter(&"pixel_scale", 0.5)   # 芯的大面上一公尺 16 格看起來像棋盤，放大一倍
	if f.shader == FACET_SHADER:
		f.set_shader_parameter(&"use_pixel", true)

## 紋理：純色平面看起來像塑膠，在材質上疊一層淡淡的程式雜訊——木紋（橫向細條）、石斑、乾草絲、恐龍鱗片。
## 物件自己的座標三面投影（triplanar），不用 UV，會動的東西紋理也黏著走。
## 只動明暗十幾趴：折面之間的明暗差（兩三成）還在，不會像照片貼圖把折面洗掉（見 docs/素材流水線/程式建模迭代.md）。
## 規則：材質名字含有前面那個字 -> [紋理種類, 三個軸的縮放（越大越密）]。第一個對到的算數；葉子、布、金屬不加
const GRAIN_RULES := [
	["leaf", null], ["pine", null], ["bush", null], ["lit", null], ["lamp", null], ["glass", null],
	["wood", [&"wood", Vector3(0.35, 3.0, 0.35)]], ["plank", [&"wood", Vector3(0.35, 3.0, 0.35)]],
	["log", [&"wood", Vector3(0.35, 3.0, 0.35)]], ["trim", [&"wood", Vector3(0.35, 3.0, 0.35)]],
	["post", [&"wood", Vector3(0.35, 3.0, 0.35)]], ["shut", [&"wood", Vector3(0.35, 3.0, 0.35)]],
	["p_red", [&"wood", Vector3(3.0, 0.35, 3.0)]], ["p_silo", [&"wood", Vector3(3.0, 0.35, 3.0)]],   # 直條板：直紋
	["p_white", [&"wood", Vector3(0.35, 3.0, 0.35)]], ["h_inner", [&"wood", Vector3(0.35, 3.0, 0.35)]],
	["bark", [&"wood", Vector3(3.0, 0.5, 3.0)]],
	["shing", [&"stone", Vector3(1.2, 1.2, 1.2)]], ["roof", [&"stone", Vector3(1.2, 1.2, 1.2)]],
	["stone", [&"stone", Vector3(0.4, 0.4, 0.4)]], ["brick", [&"stone", Vector3(0.4, 0.4, 0.4)]],
	["chink", [&"stone", Vector3(1.5, 1.5, 1.5)]],
	["hay", [&"hay", Vector3(1.5, 1.5, 1.5)]],
	["t_body", [&"scale", Vector3(2.5, 2.5, 2.5)]], ["t_belly", [&"scale", Vector3(2.5, 2.5, 2.5)]],
	["t_dark", [&"scale", Vector3(2.5, 2.5, 2.5)]],
]
static var _grain_tex := {}
static func _add_grain(m: BaseMaterial3D) -> void:
	var name := String(m.resource_name)
	if name in ["wood", "wood2", "wood_red"]:
		return   # 槍的木頭：拿在手上很近、尺寸很小，這套縮放不合
	for rule: Array in GRAIN_RULES:
		if not name.contains(rule[0]):
			continue
		if rule[1] == null:
			return
		var kind: StringName = rule[1][0]
		if not _grain_tex.has(kind):
			_grain_tex[kind] = _make_grain(kind)
		m.albedo_texture = _grain_tex[kind][0]
		m.albedo_color = m.albedo_color / _grain_tex[kind][1]   # 補回平均變暗的量，整體顏色跟以前一樣
		m.uv1_triplanar = true
		m.uv1_scale = rule[1][1]
		return

## 產生一張可以無縫重複的雜訊圖，回傳 [圖, 平均亮度（線性）]
static func _make_grain(kind: StringName) -> Array:
	var n := FastNoiseLite.new()
	n.seed = 7
	var lo := 0.80   # 最暗的地方（sRGB）；白色 = 原色
	match kind:
		&"wood":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.03
			n.fractal_octaves = 3
		&"stone":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.035
			n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			n.fractal_octaves = 2
			lo = 0.78
		&"hay":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.12
			lo = 0.74
		&"scale":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.08
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			lo = 0.82
	var g := Gradient.new()
	g.set_color(0, Color(lo, lo, lo))
	g.set_color(1, Color.WHITE)
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	t.generate_mipmaps = true
	var mean := (pow(lo, 2.2) + 1.0) * 0.5
	return [t, mean]
