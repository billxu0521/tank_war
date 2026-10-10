class_name Period
## 時段：夕陽（原本的樣子）、白天正午、夜晚午夜（月光）。大廳選，連線時照開房的人（main.gd 的 _set_period）。
## 規劃：docs/規劃/2026-10-10-時段-正午與午夜.md
##
## 做法：夕陽不寫數值——開場先把場景原本的值（main.tscn、sky.gdshader、outline.gdshader 的預設）存一份（snapshot），
## 每次換時段都先還原成那份，再蓋上這個時段要改的鍵。所以夕陽 = 空的預設，畫面跟以前一模一樣。
## 像素風（pixel_style.gd）在這之後再疊：夕陽用它自己的天空、霧；其他時段用這裡的 pixel 那組（調色盤、調色）。
##
## ponytail: 開局選一次，不做一局內時間流動（每幀插值、查色表重算、平衡沒有固定狀態）。要做再在兩組之間插值

const NAMES := {&"sunset": "夕陽", &"noon": "正午", &"midnight": "午夜（月光）"}

## 每組：sun（太陽節點）、env（Environment）、sky／outline／wheat（shader 參數）、
## far（遠山乘的顏色）、lamp（燈的亮度倍數）、muzzle（槍口火光倍數）、barn（穀倉光柱強度，0 = 關）、
## fireflies（飛蟲改螢火蟲）、leaves（飄落葉）、pixel（像素風的調色盤和調色）
const PRESETS := {
	&"sunset": {},
	&"noon": {
		"to_sun": Vector3(0.35, 0.93, -0.12),   # 仰角約 68 度：不要正頂，房子才有一面亮一面暗
		"sun": {"light_color": Color(1.0, 0.97, 0.9), "light_energy": 1.6, "shadow_opacity": 0.95,
			"directional_shadow_max_distance": 50.0},
		"env": {"ambient_light_color": Color(0.55, 0.65, 0.85), "ambient_light_energy": 0.9,
			"ambient_light_sky_contribution": 0.6, "fog_light_color": Color(0.78, 0.82, 0.85), "fog_density": 0.0015,
			"fog_sun_scatter": 0.05, "glow_intensity": 0.3, "glow_hdr_threshold": 1.4, "tonemap_exposure": 0.95,
			"background_energy_multiplier": 1.0},
		"sky": {"top_color": Color(0.22, 0.42, 0.78), "mid_color": Color(0.45, 0.62, 0.86), "horizon_color": Color(0.86, 0.9, 0.92),
			"ground_color": Color(0.7, 0.62, 0.5), "cloud_lit": Color(1.0, 1.0, 0.98), "cloud_shade": Color(0.72, 0.76, 0.82),
			"cloud_edge": Color(0.85, 0.87, 0.9), "cloud_cover": 0.3, "halo": 0.35, "rays": 0.0},
		"outline": {"dist_haze": Color(0.75, 0.8, 0.88), "dist_sat": 0.6, "dist_contrast": 0.55,
			"shadow_tint": Color(0.3, 0.36, 0.5), "shadow_tint_amount": 0.3, "near_dark": 0.85,
			"sun_haze": 0.1, "sun_haze_color": Color(0.95, 0.95, 0.9), "shafts": 0.0,
			"rim_color": Color(1.0, 1.0, 0.95), "rim_strength": 0.35, "target_line_alpha": 0.8, "heat": 1.0},
		"far": Color(1.1, 1.15, 1.3),   # 遠山烘的是夕陽的灰紫：乘一點藍，再讓它吃霧（far_fog）融進泛白的地平線
		"lamp": 0.3, "muzzle": 1.0, "barn": 0.0,
		"pixel": {
			"warm": Color(1.0, 1.0, 1.0), "shadow_tint": Color(0.08, 0.1, 0.16), "light_tint": Color(1.0, 0.98, 0.92),
			"light_amount": 0.05, "gamma": 1.05,
			"palette": [
				"1E3A6E", "2F5A9A", "4A7BBE", "7FA6D6", "B9D0E8", "E4ECF2", "FFFFFF", "F4F1E6",
				"E8D3A8", "D2B47C", "B8955C", "9C7848", "7A5A36", "5A4128", "3E2C1C", "261A12", "140E0A",
				"3E5A2A", "5B7A35", "7E9A48", "A8B866", "8E3A2A", "B4553A", "D9845A",
				"2E3036", "4A4D55", "6E717A", "9A9CA2", "C8C9CC", "6B4A30", "8C6A48", "E2C15A", "C9A040", "F2DD8A",
			],
		},
	},
	&"midnight": {
		"to_sun": Vector3(0.6, 0.75, -0.3),   # 月亮仰角約 50 度：太低會變成整片逆光剪影
		"sun": {"light_color": Color(0.62, 0.72, 0.95), "light_energy": 0.4, "shadow_opacity": 0.6,
			"directional_shadow_max_distance": 40.0},
		"env": {"ambient_light_color": Color(0.18, 0.22, 0.34), "ambient_light_energy": 0.6,
			"ambient_light_sky_contribution": 0.4, "fog_light_color": Color(0.12, 0.15, 0.24), "fog_density": 0.003,
			"fog_sun_scatter": 0.1, "glow_intensity": 0.6, "glow_hdr_threshold": 0.9, "tonemap_exposure": 1.0,
			"background_energy_multiplier": 0.6},
		"sky": {"top_color": Color(0.03, 0.04, 0.09), "mid_color": Color(0.08, 0.1, 0.2), "horizon_color": Color(0.16, 0.18, 0.28),
			"ground_color": Color(0.06, 0.07, 0.1), "cloud_lit": Color(0.5, 0.55, 0.7), "cloud_shade": Color(0.08, 0.09, 0.14),
			"cloud_edge": Color(0.2, 0.22, 0.3), "cloud_cover": 0.35, "halo": 0.6, "rays": 0.0,
			"stars": 1.0, "disk_size": 0.9972, "disk_bright": 2.5},
		"outline": {"line_color": Color(0.06, 0.07, 0.12), "dist_haze": Color(0.12, 0.15, 0.24), "dist_contrast": 0.7,
			"shadow_tint": Color(0.1, 0.12, 0.22), "shadow_tint_amount": 0.45, "tint_keep_warm": 1.0, "shadow_sat": 0.5, "near_dark": 0.7,
			"sun_haze": 0.25, "sun_haze_color": Color(0.5, 0.58, 0.8), "sun_haze_bright": 0.5,
			"shafts": 0.3, "shaft_color": Color(0.55, 0.62, 0.85),
			"rim_color": Color(0.75, 0.85, 1.0), "rim_strength": 1.2, "gun_lift": 0.9, "target_line_alpha": 0.8},
		"wheat": {"backlight": Color(0.3, 0.35, 0.48)},
		"far": Color(0.35, 0.4, 0.62),
		"lamp": 2.3, "muzzle": 3.0, "barn": 0.5, "fireflies": true, "leaves": false,
		"pixel": {
			"warm": Color(0.98, 1.0, 1.04), "shadow_tint": Color(0.03, 0.04, 0.09), "light_tint": Color(0.85, 0.9, 1.0),
			"light_amount": 0.05, "gamma": 1.0, "contrast": 1.15,
			"gun_lift": 0.02,   # 手和槍的底亮：夕陽的 0.1 在夜裡讓手像自己發光
			"palette": [
				"05070E", "0A0E1C", "111829", "1A2338", "243049", "30405E", "40527A", "586C96", "7A8DB4", "A6B6D4", "D6E0F0",
				"1C2622", "2A3830", "3A4C40", "52665A", "8C96A0", "B8C0C8", "2A2420", "3E352E", "574C42",
				"3A2414", "6A3A1A", "A4561E", "E08A30", "F8C060", "FFE8A8", "FFF8E0", "B8F070",
				"4A3424", "5E4430", "7A5838", "9A6E40", "C08848",   # 燈光灑在地上的暗暖色。也不放紫色：月光的藍＋燈的橘混出來會被吸成粉紫
			],
		},
	},
}

static var current := &"sunset"
static var _snap := {}   # 場景原本（夕陽）的值：{"sun": {...}, "env": {...}, ...}


static func preset() -> Dictionary:
	return PRESETS[current]


## 開場、像素風加進來之前叫一次：記下夕陽的原值。只記有時段會改的鍵
static func snapshot(main: Node) -> void:
	var t := _targets(main)
	for p: Dictionary in PRESETS.values():
		for group: String in t:
			for k: String in p.get(group, {}):
				if not _snap.has(group):
					_snap[group] = {}
				_snap[group][k] = _read(t[group], k)
	_snap["sun_basis"] = (main.get_node(^"Arena/Sun") as Node3D).global_basis


## 換到 name：先還原夕陽，再蓋上這個時段。像素風、燈、遠山、粒子也一起處理
static func apply(main: Node, name: StringName) -> void:
	current = name if PRESETS.has(name) else &"sunset"
	var p := preset()
	var t := _targets(main)
	for group: String in t:
		for k: String in _snap.get(group, {}):
			_write(t[group], k, p.get(group, {}).get(k, _snap[group][k]))
	var sun: DirectionalLight3D = main.get_node(^"Arena/Sun")
	# 光往 -Z 照：-Z 指向離開太陽的方向。夕陽直接還原原本的轉向（連繞光線的旋轉都一樣，影子貼圖才不會變）
	sun.global_basis = Basis.looking_at(-p["to_sun"].normalized()) if p.has("to_sun") else _snap["sun_basis"]
	t["outline"].set_shader_parameter(&"to_sun", sun.global_basis.z)
	var tree := main.get_tree()
	_scale_energy(tree.get_nodes_in_group(&"period_lamp"), p.get("lamp", 1.0))
	ShotFX.light_scale = p.get("muzzle", 1.0)
	for n: Node in tree.get_nodes_in_group(&"far_mesa"):
		var m: StandardMaterial3D = (n as MeshInstance3D).material_override
		m.albedo_color = p.get("far", Color.WHITE)
		m.disable_fog = not p.has("far")   # 夕陽的遠山不吃霧（顏色已經烘好）；其他時段靠霧換成那個時段的天色
	var barn: float = p.get("barn", 1.0)
	for n: Node in tree.get_nodes_in_group(&"barn_light"):
		n.visible = barn > 0.0
		if n is MeshInstance3D:
			n.mesh.material.set_shader_parameter(&"strength", 0.12 * barn)
			n.mesh.material.set_shader_parameter(&"color", Color(0.6, 0.7, 0.95) if current == &"midnight" else Color(1.0, 0.72, 0.4))
	if main._drift:
		main._drift.get_node(^"Leaves").visible = p.get("leaves", true)
		Fx.firefly(main._drift.get_node(^"Bugs"), p.get("fireflies", false))
	var amb := main.get_node_or_null(^"Arena/Ambience")
	if amb:
		amb.rebase()
	var px := main.get_node_or_null(^"PixelStyle")
	if px:
		px.apply()


## 各組的目標物件
static func _targets(main: Node) -> Dictionary:
	var env: Environment = (main.get_node(^"Arena/WorldEnvironment") as WorldEnvironment).environment
	return {"sun": main.get_node(^"Arena/Sun"), "env": env, "sky": env.sky.sky_material,
		"outline": (main.get_node(^"Arena/Outline") as MeshInstance3D).mesh.material,
		"wheat": main.wheat_card().surface_get_material(0)}


## shader 參數沒設過時 get_shader_parameter 拿到 null，要去 shader 裡讀預設值
static func _read(o: Object, k: String) -> Variant:
	if o is ShaderMaterial:
		var v: Variant = o.get_shader_parameter(k)
		return v if v != null else RenderingServer.shader_get_parameter_default(o.shader.get_rid(), k)
	return o.get(k)


static func _write(o: Object, k: String, v: Variant) -> void:
	if o is ShaderMaterial:
		o.set_shader_parameter(k, v)
	else:
		o.set(k, v)


static func _scale_energy(lights: Array, k: float) -> void:
	for l: Light3D in lights:
		if not l.has_meta(&"base_energy"):
			l.set_meta(&"base_energy", l.light_energy)
		l.light_energy = l.get_meta(&"base_energy") * k
