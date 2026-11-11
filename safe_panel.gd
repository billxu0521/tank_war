class_name SafePanel
extends Control
## 保險箱的密碼面板（規劃 docs/企劃/2026-11-12-保險箱與號碼牌.md 第 5～7 項）。照 buy_menu.gd 的做法：游標放開、可以點。
## 看著保險箱按 F 打開（safe.gd 的 interact）。上排十位數（白底黑字）、下排個位數（黑底白字），各選一個按「試開」。
## 選了十位數 X，個位數裡「X 配它試過」的變灰；反過來也一樣。灰的還是點得到（只是提示）。
## 按移動鍵或 Esc 關；死了、走開、箱子開了、不在遊戲階段也關。被打到不關。只讀 main.safe 的公開狀態，不改規則。

var main: Node
var tens := -1
var ones := -1
var _rows: Array = [[], []]   # [十位數 10 顆, 個位數 10 顆]
var _try_btn: Button
var _status: Label
var _sent := -1               # 自己最後送出的組合（顯示「不對」用）
var _last := []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.09, 0.92)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	box.add_theme_stylebox_override(&"panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)   # 蓋住畫面中央：提案要的「看不到四周」
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	box.add_child(v)
	v.add_child(_label(28, "保險箱"))
	for row in 2:
		v.add_child(_label(18, "十位數" if row == 0 else "個位數"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 6)
		v.add_child(h)
		for d in 10:
			var b := Button.new()
			b.text = str(d)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(52, 52)
			b.add_theme_font_size_override(&"font_size", 26)
			b.pressed.connect(_pick.bind(row, d))
			h.add_child(b)
			_rows[row].append(b)
	_try_btn = Button.new()
	_try_btn.text = "試開"
	_try_btn.focus_mode = Control.FOCUS_NONE
	_try_btn.custom_minimum_size = Vector2(0, 48)
	_try_btn.add_theme_font_size_override(&"font_size", 24)
	_try_btn.pressed.connect(_submit)
	v.add_child(_try_btn)
	_status = _label(20, "")
	v.add_child(_status)
	v.add_child(_label(16, "移動鍵／Esc 關閉"))
	hide()


func _label(size: int, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override(&"font_size", size)
	return l


func open_panel() -> void:
	tens = int(main.party.my_digits[0]) if main.party else -1   # 看過的那一位先幫他選好
	ones = int(main.party.my_digits[1]) if main.party else -1
	_sent = -1
	_last = []
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _can_stay() or Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") != Vector2.ZERO:
		hide()
		Fighter.lock_mouse()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:   # main 有時會把游標鎖回去
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if visible and k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		hide()
		Fighter.lock_mouse()
		get_viewport().set_input_as_handled()


## 遊戲階段、自己是活著的牛仔、站在箱子旁邊、箱子還關著
func _can_stay() -> bool:
	if main == null or main.party == null or main.party.phase != &"play" or not main.safe.locked():
		return false
	var me := main._me() as Cowboy
	return me != null and me.hp > 0 and not me.is_queued_for_deletion() \
		and Vector2(me.global_position.x - main.safe.global_position.x, me.global_position.z - main.safe.global_position.z).length() < Safe.RANGE


func _pick(row: int, d: int) -> void:
	if row == 0:
		tens = d
	else:
		ones = d
	_refresh()


func _submit() -> void:
	if tens < 0 or ones < 0 or main.safe.busy != 0:
		return
	_sent = tens * 10 + ones
	main.safe.request_try(_sent)


## 這顆是不是灰的：選了另一排的數字，而且這個組合試過了
func is_gray(row: int, d: int) -> bool:
	var other := ones if row == 0 else tens
	if other < 0:
		return false
	var n := d * 10 + other if row == 0 else other * 10 + d
	return main.safe.tried[n] == 1


func _refresh() -> void:
	var s: Safe = main.safe
	var sig := [tens, ones, s.tried, s.busy, _sent]
	if sig == _last:   # 每幀叫：沒變就不重做按鈕樣式
		return
	_last = sig
	for row in 2:
		for d in 10:
			var b: Button = _rows[row][d]
			var picked := (tens if row == 0 else ones) == d
			var bg := Color.WHITE if row == 0 else Color.BLACK
			var fg := Color.BLACK if row == 0 else Color.WHITE
			if is_gray(row, d):
				bg = Color(0.45, 0.45, 0.45)
				fg = Color(0.7, 0.7, 0.7)
			_style(b, bg, fg, picked)
	var me: int = multiplayer.get_unique_id()
	_try_btn.disabled = tens < 0 or ones < 0 or s.busy != 0
	if s.busy == me:
		_status.text = "試開中…"
	elif s.busy != 0:
		_status.text = "有人在試，等一下"
	elif _sent >= 0 and s.tried[_sent] == 1:
		_status.text = "%02d 不對" % _sent
	else:
		_status.text = ""


func _style(b: Button, bg: Color, fg: Color, picked: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	if picked:   # 選中的框起來（強調色，同 Accent）
		sb.set_border_width_all(4)
		sb.border_color = Accent.COLOR
	for st: StringName in [&"normal", &"hover", &"pressed"]:
		b.add_theme_stylebox_override(st, sb)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		b.add_theme_color_override(c, fg)
