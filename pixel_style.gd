extends Node
## 像素風（參考圖 docs/image/survival_style.png）：F9 開關，存在設定檔。
## 像素化：3D 畫面用 Godot 內建的「低解析度算圖＋最近點放大」（Viewport.scaling_3d_*），
##   介面是 2D、不吃這個縮放，所以字還是清楚的；第一人稱的槍和手也在 3D 裡，一起變像素。算的像素少，反而比較省。
## 調色：Environment 的 color correction 吃一張 3D 查色表（LUT），在這裡用程式算：
##   去藍紫、對比、暗部往暖褐推、亮部往橘紅推，最後換成參考圖調色盤裡最近的顏色（全畫面只剩 37 色）。
##   天空另外換一組顏色（SKY），描線的槍身稜線關掉（gun_ridge）。
## 改參數後呼叫 apply() 重算。tools/pixel_style_shots.gd 用環境變數 PIXEL="pixel=4,gamma=0.9" 改來比對。

@export var pixel := 4.0          # 一個像素方塊是幾個螢幕像素（照 720p 算，畫面大方塊跟著大，看起來一樣粗）
@export var levels := 8.0         # palette_mix = 0 時才用：每個顏色通道分幾階；0 = 不分
@export var contrast := 1.3      # 以 0.45 為中心拉開
@export var saturation := 1.0
@export var shadow_tint := Color(0.16, 0.08, 0.09)   # 暗部往這個暖褐混
@export var shadow_amount := 0.35
@export var light_tint := Color(1.0, 0.72, 0.5)     # 中亮部乘上這個（往橘紅偏）
@export var light_amount := 0.12   # 0.3 會把所有亮面都推成同一種橘，紫和黃都留不住
@export var gamma := 1.15        # <1 提亮暗部、>1 壓暗。1.15：影子壓深（使用者 2026-10-06：強化黑影處）；1.3 更像參考圖的剪影，但手上的槍變成一團黑
@export var warm := Color(1.02, 0.98, 0.96)   # 先整體乘上這個：抽掉藍紫（場景的環境光偏藍紫，乘完才是暖褐）
@export var gun_brightness := 1.15  # 手上的槍和手：顏色 × gun_brightness + gun_lift（Viewmodel）。抵消上面 gamma 把影子壓暗；
@export var gun_lift := 0.10        # 槍的鐵件接近全黑，只乘倍數還是黑的，要加底亮才看得出零件
@export var gun_ridge := 0.0      # 開著時描線（outline.gdshader）槍和手零件交界線的濃度；關掉回 1
## 泛光：3D 畫面縮成 1/pixel 解析度算，泛光的模糊半徑在畫面上跟著放大 pixel 倍，太陽的光暈蓋掉半邊天（2026-10-06 使用者：光暈太強）。
## 開著時只留最小的兩層模糊、強度乘上 glow_scale
@export var glow_scale := 0.4
const GLOW_LEVELS := [1.0, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0]   # glow_levels/1..7
@export var palette_mix := 1.0   # 最後往參考圖的調色盤（PALETTE）最近的顏色靠多少：1 = 只剩這 32 色，0 = 只用上面的分階
## 參考圖量出來的 32 色（magick -colors 32），再加最後一排槍和手套的冷灰（參考圖裡槍是灰藍、手套是灰，量色會被大片的天空和地面吃掉）
const PALETTE := [
	"140C0C", "1B1317", "261919", "311C15", "2C221C", "382318", "181724", "291D22",
	"321F21", "372426", "332630", "4C2B1A", "69351A", "472924", "522D31", "6D3431",
	"533743", "6C3C43", "573C6B", "6F4944", "8D3833", "A83B2D", "994C1E", "904632",
	"AF4935", "A4433B", "CF4E33", "E9582F", "F96C34", "F89332", "FABB50", "C9C3A3",
	"262A36", "3A3F50", "565C6C", "77787E", "A09C96",
	"FFE39A", "FFF6DC",
	"372533", "5A3843", "5E4354", "7A5A6E", "FDB346", "FDF891",   # 天頂和遠山的紫、地平線和窗光的黃：沒有這幾色，全畫面會被推成同一種橘褐   # 太陽：參考圖的太陽是亮黃白，調色盤最亮只有灰米 C9C3A3 的話太陽會變成一顆灰盤
]
## 開著的時候天空（sky.gdshader）換成這組：雲更多更暗、天頂深紫褐、中段橘紅。關掉還原
## 2026-10-06 使用者：顏色太單一、天空要有漸層、雲要有層次。照參考圖量的顏色分三段：天頂暗紫 → 中段磚紅 → 地平線亮黃；
## 雲：暗紫的雲心、紅的邊、亮橘的受光面
const SKY := {
	"top_color": Color("2a1b28"), "mid_color": Color("9c3a30"), "horizon_color": Color("f7a540"),
	"cloud_shade": Color("4a2633"), "cloud_edge": Color("8a3533"), "cloud_lit": Color("c8583a"),
	"cloud_cover": 0.6, "halo": 0.45, "rays": 0.45,
}
## 遠景的空氣：霧調成偏紫、濃一點，越遠越紫，跟近景的暖褐分開（參考圖的遠山是 #5E4354）
const FOG := {"fog_light_color": Color("6a4a64"), "fog_density": 0.006, "fog_sun_scatter": 0.15}

const LUT_SIZE := 33

var on := true
var _env: Environment
var _cc_before: Texture   # 關掉時還原原本的設定
var _adj_before: bool
var _sky_before := {}
var _glow_before := {}
var _fog_before := {}


func _ready() -> void:
	name = &"PixelStyle"   # tools/pixel_style_shots.gd 用名字找
	_env = get_viewport().find_child("WorldEnvironment", true, false).environment
	_cc_before = _env.adjustment_color_correction
	_adj_before = _env.adjustment_enabled
	for k: String in SKY:
		_sky_before[k] = _env.sky.sky_material.get_shader_parameter(k)
	_glow_before["intensity"] = _env.glow_intensity
	for k: String in FOG:
		_fog_before[k] = _env.get(k)
	for i in GLOW_LEVELS.size():
		_glow_before[i] = _env.get_glow_level(i)
	var cfg := ConfigFile.new()
	cfg.load(get_parent().settings_path)
	on = cfg.get_value("display", "pixel_style", true)
	get_viewport().size_changed.connect(_rescale)   # 拉視窗只改縮放，不重算查色表（GDScript 算一次要一點時間）
	apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F9:
		on = not on
		get_parent()._save_setting("display", "pixel_style", on)
		apply()


func apply() -> void:
	var vp := get_viewport()
	for k: String in SKY:
		_env.sky.sky_material.set_shader_parameter(k, SKY[k] if on else _sky_before[k])
	_env.glow_intensity = _glow_before["intensity"] * (glow_scale if on else 1.0)
	for k: String in FOG:
		_env.set(k, FOG[k] if on else _fog_before[k])
	Viewmodel.brightness = gun_brightness if on else 1.0
	Viewmodel.lift = gun_lift if on else 0.0
	get_tree().call_group(&"viewmodel", &"apply_brightness")
	for i in GLOW_LEVELS.size():
		_env.set_glow_level(i, GLOW_LEVELS[i] if on else _glow_before[i])
	var outline: Node = get_parent().get_node_or_null(^"Arena/Outline")
	if outline:
		outline.mesh.material.set_shader_parameter(&"gun_ridge", gun_ridge if on else 1.0)
	if on:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
		_rescale()
		_env.adjustment_enabled = true
		_env.adjustment_color_correction = _make_lut()
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		_env.adjustment_enabled = _adj_before
		_env.adjustment_color_correction = _cc_before


func _rescale() -> void:
	var vp := get_viewport()
	if on:
		vp.scaling_3d_scale = clampf(1.0 / (pixel * vp.get_visible_rect().size.y / 720.0), 0.05, 1.0)


## 一個 sRGB 顏色（0~1）調成參考圖的色調。LUT 每一格都過一次
func grade(c: Color) -> Color:
	c *= warm
	var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	c = Color(l, l, l).lerp(c, saturation)                       # 飽和
	c = Color(0.45, 0.45, 0.45).lerp(c, contrast)               # 對比
	l = clampf(c.r * 0.299 + c.g * 0.587 + c.b * 0.114, 0.0, 1.0)
	c = c.lerp(shadow_tint, shadow_amount * (1.0 - l) * (1.0 - l))   # 暗部往暖褐
	c = c.lerp(c * light_tint * 1.2, light_amount * l)           # 亮部往橘紅
	c = Color(pow(clampf(c.r, 0, 1), gamma), pow(clampf(c.g, 0, 1), gamma), pow(clampf(c.b, 0, 1), gamma))
	if palette_mix > 0.0:
		c = c.lerp(_nearest(c), palette_mix)
	elif levels > 0.0:
		c = Color(roundf(c.r * levels) / levels, roundf(c.g * levels) / levels, roundf(c.b * levels) / levels)
	return c


var _pal: Array[Color] = []
func _nearest(c: Color) -> Color:
	if _pal.is_empty():
		for h: String in PALETTE:
			_pal.append(Color(h))
	var best := c
	var bd := INF
	for p in _pal:   # 照人眼的權重算距離（綠最敏感）
		var dd := 3.0 * (p.r - c.r) ** 2 + 4.0 * (p.g - c.g) ** 2 + 2.0 * (p.b - c.b) ** 2
		if dd < bd:
			bd = dd
			best = p
	return best


func _make_lut() -> ImageTexture3D:
	var t0 := Time.get_ticks_msec()
	var imgs: Array[Image] = []
	var n := LUT_SIZE - 1
	for b in LUT_SIZE:
		var img := Image.create_empty(LUT_SIZE, LUT_SIZE, false, Image.FORMAT_RGB8)
		for g in LUT_SIZE:
			for r in LUT_SIZE:
				img.set_pixel(r, g, grade(Color(float(r) / n, float(g) / n, float(b) / n)))
		imgs.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, LUT_SIZE, LUT_SIZE, LUT_SIZE, false, imgs)
	print_verbose("像素風查色表 %d ms" % (Time.get_ticks_msec() - t0))
	return tex
