class_name Settings
extends AcceptDialog
## 設定視窗（docs/規劃/2026-10-18-玩家設定.md 第一版）：主選單和 Esc 選單開的是同一個。
## 調了馬上生效、馬上存（main 的 settings.cfg）。數值放在 static 的 v，角色直接讀，不用找這個視窗

## 鍵 -> [設定檔的節, 預設值]。預設值就是加設定以前的手感
const DEFAULTS := {
	&"mouse_sens": ["controls", 1.0],   # 乘在滑鼠位移上（fighter.gd 的 mouse_look）
	&"ads_sens": ["controls", 1.0],     # 舉槍時再乘的倍率，1＝跟腰射一樣（使用者選的：維持原手感）
	&"pad_sens": ["controls", 1.0],     # 手把右搖桿轉速倍率
	&"invert_y": ["controls", false],
	&"fov": ["display", 70.0],          # 腰射的垂直視角（Camera3D.fov），畫面上顯示 16:9 的水平角
	&"shake": ["display", 1.0],         # 鏡頭晃動：只乘純畫面的（被打歪、翻越點頭、開槍撞一下），後座力和舉槍晃不動
	&"volume": ["audio", 1.0],
}
static var v := {}

static func load_from(cfg: ConfigFile) -> void:
	for k: StringName in DEFAULTS:
		v[k] = cfg.get_value(DEFAULTS[k][0], k, DEFAULTS[k][1])
	apply_volume()

## 滑鼠位移乘上靈敏度和上下反轉。不乘在 rotate_view 裡：那裡還有後座力和舉槍晃動，靈敏度高的人不該被踢得比較兇
static func look(rel: Vector2) -> Vector2:
	return rel * float(v.get(&"mouse_sens", 1.0)) * Vector2(1.0, -1.0 if v.get(&"invert_y", false) else 1.0)

static func apply_volume() -> void:
	var vol: float = v.get(&"volume", 1.0)
	AudioServer.set_bus_mute(0, vol <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))

## 16:9 的水平角和垂直角互換（多數玩家講的「FOV 100」是水平的）
static func h_fov(vdeg: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vdeg) / 2.0) * 16.0 / 9.0))

static func v_fov(hdeg: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(hdeg) / 2.0) * 9.0 / 16.0))

var main: Node
var tabs := TabContainer.new()
var _widgets := {}   # 鍵 -> 控制項，refresh() 拿來對回現在的值

func _init(m: Node) -> void:
	main = m
	name = &"Settings"
	title = "設定"
	ok_button_text = "關閉"
	theme = m.get_node(^"UI/Root").theme   # 視窗不吃 UI 的字型，要自己帶
	tabs.custom_minimum_size = Vector2(760, 440)
	add_child(tabs)
	var hz: int = m._refresh_hz()
	_page("操作", [
		_slider(&"mouse_sens", "滑鼠靈敏度", 0.1, 3.0, 0.01),
		_slider(&"ads_sens", "舉槍時靈敏度倍率", 0.2, 2.0, 0.01),
		_slider(&"pad_sens", "手把靈敏度", 0.3, 3.0, 0.01),
		_check(&"invert_y", "上下反轉"),
		_check(&"aim_toggle", "瞄準：按一下切換（關＝按住右鍵）", func(on: bool) -> void: m._on_aim_toggle_toggled(on)),
	], func() -> void:
		_reset([&"mouse_sens", &"ads_sens", &"pad_sens", &"invert_y"])
		m._on_aim_toggle_toggled(false))
	_page("畫面", [
		_slider(&"fov", "視野（水平角）", 90.0, 110.0, 1.0),
		_slider(&"shake", "鏡頭晃動（%）", 0.0, 100.0, 1.0),
		_check(&"vsync", "垂直同步（關掉畫面可能撕裂，延遲稍低）", func(on: bool) -> void: m._on_vsync_toggled(on)),
		_option(&"fps_cap", "幀率上限", [m.FPS_CAPS[0], m.FPS_CAPS[1] % hz, m.FPS_CAPS[2] % (hz / 2)],
			func(i: int) -> void: m._on_fps_cap_selected(i)),
		_check(&"pixel_style", "像素風（F9）", func(on: bool) -> void: m.get_node(^"PixelStyle").set_on(on)),
		_option(&"period", "時段", Period.NAMES.values(), func(i: int) -> void: m._on_period_picked(i)),
	], func() -> void:
		_reset([&"fov", &"shake"])
		m._on_vsync_toggled(true)
		m._on_fps_cap_selected(0)
		m.get_node(^"PixelStyle").set_on(true)
		m._on_period_picked(Period.NAMES.keys().find(&"sunset")))
	_page("聲音", [_slider(&"volume", "主音量（%）", 0.0, 100.0, 1.0)], func() -> void: _reset([&"volume"]))
	var keys := RichTextLabel.new()
	keys.name = &"按鍵"
	keys.bbcode_enabled = true
	keys.text = m.controls_table()
	tabs.add_child(keys)
	about_to_popup.connect(refresh)

## 一頁：一列一個設定，最下面「恢復預設」
func _page(title_text: String, rows: Array, reset: Callable) -> void:
	var box := VBoxContainer.new()
	box.name = title_text
	box.add_theme_constant_override(&"separation", 10)
	for r: Control in rows:
		box.add_child(r)
	var b := Button.new()
	b.text = "恢復預設"
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func() -> void:
		reset.call()
		refresh())
	box.add_child(b)
	tabs.add_child(box)

func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 260
	row.add_child(l)
	return row

## 拉桿＋數字框（可以直接打數字），兩個共用同一個值（Range.share）。% 的設定畫面上 0–100，存 0–1
func _slider(key: StringName, label_text: String, lo: float, hi: float, step: float) -> Control:
	var row := _row(label_text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := SpinBox.new()
	n.custom_minimum_size.x = 110
	s.share(n)
	row.add_child(s)
	row.add_child(n)
	s.value_changed.connect(func(x: float) -> void: set_value(key, x))
	_widgets[key] = s
	return row

func _check(key: StringName, label_text: String, on_toggle: Callable = Callable()) -> Control:
	var c := CheckButton.new()
	c.text = label_text
	c.toggled.connect(on_toggle if on_toggle.is_valid() else func(on: bool) -> void: set_value(key, on))
	_widgets[key] = c
	return c

func _option(key: StringName, label_text: String, items: Array, on_pick: Callable) -> Control:
	var row := _row(label_text)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t: String in items:
		o.add_item(t)
	o.item_selected.connect(on_pick)
	row.add_child(o)
	_widgets[key] = o
	return row

## 畫面上的數字換回存檔的值，套用、存檔。
## ponytail: 拖拉桿時每一格都寫一次檔；檔案很小沒感覺，真的卡再改成放開才存
func set_value(key: StringName, x: Variant) -> void:
	match key:
		&"fov": x = v_fov(x)
		&"shake", &"volume": x = x / 100.0
	v[key] = x
	main._save_setting(DEFAULTS[key][0], key, x)
	if key == &"volume":
		apply_volume()
	elif key == &"fov":
		main.get_tree().call_group(&"viewmodel", &"set", &"hip_fov", x)

func _reset(keys: Array) -> void:
	for k: StringName in keys:
		v[k] = DEFAULTS[k][1]
		main._save_setting(DEFAULTS[k][0], k, v[k])
	apply_volume()
	main.get_tree().call_group(&"viewmodel", &"set", &"hip_fov", v[&"fov"])

## 控制項對回現在的值（不觸發訊號）。打開視窗、恢復預設時叫
func refresh() -> void:
	for k: StringName in [&"mouse_sens", &"ads_sens", &"pad_sens"]:
		_put(k, v[k])
	_put(&"fov", roundf(h_fov(v[&"fov"])))
	_put(&"shake", v[&"shake"] * 100.0)
	_put(&"volume", v[&"volume"] * 100.0)
	_widgets[&"invert_y"].set_pressed_no_signal(v[&"invert_y"])
	_widgets[&"aim_toggle"].set_pressed_no_signal(Viewmodel.aim_toggle)
	_widgets[&"vsync"].set_pressed_no_signal(main.vsync)
	_widgets[&"fps_cap"].select(main.fps_cap)
	_widgets[&"pixel_style"].set_pressed_no_signal(main.get_node(^"PixelStyle").on)
	_widgets[&"period"].select(Period.NAMES.keys().find(main.period))

## 拉桿設值但不存檔：擋住拉桿的訊號（不然又寫回設定）。不用 set_value_no_signal：那個不會更新共用值的數字框
func _put(key: StringName, x: float) -> void:
	var s: Range = _widgets[key]
	s.set_block_signals(true)
	s.value = x
	s.set_block_signals(false)
