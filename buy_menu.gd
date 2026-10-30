class_name BuyMenu
extends Control
## 派對模式的選裝選單（規格：docs/規劃/2026-10-31-選裝.md）。
## 只在準備階段開：準備一開始自動打開，中途按 B 或 Esc 關、B 再開；準備結束就關。恐龍和死掉的人打不開。
## 選了就存進 Viewmodel.pick，活著就馬上換到那把。只讀 main.party 的階段和倒數，不改規則。
## main.gd 在 _ready 建一個掛到 $UI/Root 底下，要加在 party_hud 後面（數字鍵先給它，party_hud 的選重生點才不會搶到）。

## 主武器的 id，順序跟 cowboy/cowboy.tscn 的 weapon_scenes 一樣（0 是左輪，不在選單裡）
const WEAPON_IDS := ["revolver", "shotgun", "rifle", "lance"]
## 數字鍵 -> 選的編號（0 = 不帶，只用左輪）
const DIGITS := {KEY_0: -1, KEY_1: 1, KEY_2: 2, KEY_3: 3}
const OUTLINE := Color(0.12, 0.07, 0.05, 0.85)

var main: Node
var _title: Label
var _btns := {}        # 編號 -> Button
var _auto := false     # 這個準備階段已經自動打開過了（B 關掉之後不會再自動開）


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.04, 0.8)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	box.add_theme_stylebox_override(&"panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)   # 畫面中間偏左，不擋準心
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_left = 60.0
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	box.add_child(v)
	_title = _label(28, "")
	v.add_child(_title)
	v.add_child(_label(20, "主武器（1 鍵）"))
	for idx: int in [1, 2, 3, -1]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(480, 40)
		b.add_theme_font_size_override(&"font_size", 22)
		b.pressed.connect(_choose.bind(idx))
		v.add_child(b)
		_btns[idx] = b
	v.add_child(_label(20, "副武器（2 鍵）　左輪"))
	v.add_child(_label(20, "裝備　補血包 ×%d（3 鍵）　炸藥（4 鍵）" % Balance.whole("medkit_count")))
	v.add_child(_label(18, "B／Esc 關閉"))
	hide()


func _label(size: int, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override(&"font_size", size)
	return l


func _process(_delta: float) -> void:
	if not _can_open():
		hide()
		if not _in_prep():   # 準備結束了，下一個準備階段再自動開
			_auto = false
		return
	if not _auto:
		_auto = true
		_open()
	if not visible:
		return
	# main 會在某些時候把游標鎖回去（回合開始的廣播等），選單開著就要留游標給人點
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if visible:
		if k.is_action_pressed(&"ammo_next") or k.keycode == KEY_ESCAPE:
			hide()
		elif DIGITS.has(k.physical_keycode):
			_choose(DIGITS[k.physical_keycode])
		else:
			return
		get_viewport().set_input_as_handled()   # 數字鍵不傳給換槍、party_hud 的選重生點
	elif k.is_action_pressed(&"ammo_next") and _can_open():
		_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## 選一把：存起來，活著就馬上換到那把（準備階段牛仔被定住，換了不影響公平）
func _choose(idx: int) -> void:
	Viewmodel.pick = idx
	var me := _my_cowboy()
	if me:
		me.viewmodel.switch_weapon(maxi(idx, 0))
	_refresh()


## 倒數、按鈕文字（名字和價格照 weapons.csv；價格現在全 0，寫「免費」）、已選的標記
func _refresh() -> void:
	var p: Node = _party()
	_title.text = "選裝（剩 %d 秒）" % ceili(maxf(p.time_left, 0.0))
	for idx: int in _btns:
		var b: Button = _btns[idx]
		var nm := "不帶（只用左輪）"
		var price := ""
		if idx >= 0:
			var t: Dictionary = Weapon.table().get(WEAPON_IDS[idx], {})
			nm = t.get("display_name", WEAPON_IDS[idx])
			var cost: int = t.get("price", "0").to_int()
			price = "免費" if cost == 0 else "%d 元" % cost   # ponytail: 不收錢，先只寫免費；接購買時照價格顯示
		var mark := "　◀ 已選" if Viewmodel.pick == idx else ""
		b.text = "[%d] %s　%s%s" % [maxi(idx, 0), nm, price, mark]


func _party() -> Node:
	return main.get(&"party") if main else null


func _in_prep() -> bool:
	var p: Node = _party()
	return p != null and p.phase == &"prep"


## 準備階段，而且自己是活著的牛仔。恐龍（操作尼諾拉）、死掉的人、沒有牛仔（專用伺服器）都開不了
func _can_open() -> bool:
	var p: Node = _party()
	return _in_prep() and p.dino_id != multiplayer.get_unique_id() and _my_cowboy() != null


func _my_cowboy() -> Cowboy:
	if main == null:
		return null
	var me := main._me() as Cowboy
	return me if me and me.hp > 0 and not me.is_queued_for_deletion() else null
