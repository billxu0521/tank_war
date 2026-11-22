class_name SafePanel
extends Control
## 保險箱的密碼面板（規劃 docs/企劃/2026-11-12-保險箱與號碼牌.md 第 5～7 項）。照 buy_menu.gd 的做法：游標放開、可以點。
## 看著保險箱按 F 打開（safe.gd 的 interact）。上排十位數（白底黑字）、下排個位數（黑底白字），各選一個按「試開」。
## 選了十位數 X，個位數裡「X 配它試過」的變灰；反過來也一樣。灰的還是點得到（只是提示）。
## 按移動鍵或 Esc 關；死了、走開、箱子開了、不在遊戲階段也關。被打到不關。只讀 main.safe 的公開狀態，不改規則。

## 團隊模式三位數：上面多一排百位數（暗紅底白字），兩位數時藏起來。pick 照位數排（三位數 [百, 十, 個]、兩位數 [十, 個]），
## is_gray 的 row 也是 pick 的索引
var main: Node
var pick: Array = [-1, -1]
var tens: int:
	get: return pick[-2]
	set(v): pick[-2] = v
var ones: int:
	get: return pick[-1]
	set(v): pick[-1] = v
var _rows: Array = [[], [], []]   # [百位數, 十位數, 個位數] 各 10 顆
var _row_box: Array = []          # 每排的標題和按鈕列（兩位數時藏百位那排）
const ROW_NAMES := ["百位數", "十位數", "個位數"]
const ROW_BG := [Color(0.5, 0.16, 0.14), Color.WHITE, Color.BLACK]
const ROW_FG := [Color.WHITE, Color.BLACK, Color.WHITE]
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
	for row in 3:
		var title := _label(18, ROW_NAMES[row])
		v.add_child(title)
		var h := HBoxContainer.new()
		_row_box.append([title, h])
		h.add_theme_constant_override(&"separation", 6)
		v.add_child(h)
		for d in 10:
			var b := Button.new()
			b.text = str(d)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(52, 52)
			b.add_theme_font_size_override(&"font_size", 26)
			b.pressed.connect(_pick.bind(row - 1, d))   # 兩位數時 row 1 是 pick[0]；三位數 _pick 自己再加回來
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
	var n: int = main.safe.digits
	pick = []
	for j in n:   # 看過的那一位先幫他選好
		pick.append(int(main.party.my_digits[j]) if main.party and j < main.party.my_digits.size() else -1)
	for row in 3:
		for c: Control in _row_box[row]:
			c.visible = row >= 3 - n
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


## j：兩位數時的索引（按鈕綁的是 row - 1），三位數再往後挪一格
func _pick(j: int, d: int) -> void:
	pick[j + pick.size() - 2] = d
	_refresh()


func _submit() -> void:
	if pick.has(-1) or main.safe.busy != 0:
		return
	_sent = pick.reduce(func(a: int, d: int) -> int: return a * 10 + d, 0)
	main.safe.request_try(_sent)


## 這顆是不是灰的：不在候選裡（吞掉的信封、團隊模式的隊伍情報；還是可以按），或其他排都選了、而且這個組合試過了
func is_gray(row: int, d: int) -> bool:
	if main.party and not main.party.in_hint(row, d):
		return true
	var p := pick.duplicate()
	p[row] = d
	if p.has(-1):
		return false
	return main.safe.tried[p.reduce(func(a: int, x: int) -> int: return a * 10 + x, 0)] == 1


func _refresh() -> void:
	var s: Safe = main.safe
	var sig := [pick.duplicate(), s.tried, s.busy, _sent, main.party.my_hint if main.party else []]
	if sig == _last:   # 每幀叫：沒變就不重做按鈕樣式
		return
	_last = sig
	var skip := 3 - pick.size()
	for j in pick.size():
		for d in 10:
			var b: Button = _rows[j + skip][d]
			var picked: bool = pick[j] == d
			var bg: Color = ROW_BG[j + skip]
			var fg: Color = ROW_FG[j + skip]
			if is_gray(j, d):
				bg = Color(0.45, 0.45, 0.45)
				fg = Color(0.7, 0.7, 0.7)
			_style(b, bg, fg, picked)
	var me: int = multiplayer.get_unique_id()
	_try_btn.disabled = pick.has(-1) or s.busy != 0
	if s.busy == me:
		_status.text = "試開中…"
	elif s.busy != 0:
		_status.text = "有人在試，等一下"
	elif _sent >= 0 and s.tried[_sent] == 1:
		_status.text = "%s 不對" % str(_sent).pad_zeros(pick.size())
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
