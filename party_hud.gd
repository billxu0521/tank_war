class_name PartyHud
extends Control
## 派對模式的畫面資訊（規格：docs/企劃/派對玩法.md）。
## 只讀 main.party（Party 節點）的值和 changed 訊號，不改規則；main.party 是 null 時整個藏起來。
## - 左上：第幾回合、階段倒數、誰是恐龍、自己剩幾條命；下面一個直的計分欄（準備、遊戲階段）
## - 中間：準備階段的提示；死掉等重生時的俯視圖（minimap.gd），點綠點或按 1～9 選重生點
## - Tab 按住：分數板；回合結算、四回合結束：中間的大框
## main.gd 在 _ready 建一個掛到 $UI/Root 底下（那邊的主題有中文字型）。

const RESULT_SHOW := 6.0   # 回合結算框留幾秒
const PHASES := {&"prep": "準備", &"play": "遊戲", &"result": "結算", &"final": "結束"}
const OUTLINE := Color(0.12, 0.07, 0.05, 0.85)   # 跟 CenterInfo、方位條的字一樣的深色描邊
const GOLD := Color(1.0, 0.85, 0.4)
const CARRY := Color(1.0, 0.9, 0.2)   # 拿著蛋的人：計分欄的「+10」
## 計分欄每個參賽者固定一個顏色（照加入的順序）。ponytail: 之後美術給頭像，只換色塊那一格
const SWATCH := [Color(0.9, 0.3, 0.25), Color(0.3, 0.6, 0.95), Color(0.35, 0.8, 0.4), Color(0.85, 0.5, 0.9),
	Color(0.95, 0.6, 0.2), Color(0.3, 0.85, 0.85), Color(0.9, 0.9, 0.9), Color(0.6, 0.45, 0.3)]

var main: Node
var picked := -1   # 這次死掉選了第幾個重生點（-1 = 還沒選）
var _party: Node   # 目前接著 changed 的那個
var _phase: StringName = &""
var _result_left := 0.0

var top: Label        # 左上
var scorebar: VBoxContainer   # 左上、top 下面的計分欄：每人一列
var _carrier := 0     # 計分欄上次畫的時候誰拿著蛋（換人才重畫）
var _star := 0        # 計分欄上次畫的時候誰拿著星星
var _shown := 0       # refresh 上次畫的內容的雜湊值：一樣就不重建（_sync 每秒都發 changed）
var hint: Label       # 中間的提示（準備階段、選重生點）
var board: PanelContainer   # Tab 分數板
var board_rows: GridContainer
var popup: PanelContainer   # 回合結算／最終排名
var popup_title: Label
var popup_champ: Label
var popup_rows: GridContainer
var minimap: Minimap  # 等重生時的俯視圖（minimap.gd）
var _was_waiting := false
var _last_pos := Vector3.INF   # 自己最後活著的位置（圖上畫死在哪）


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := VBoxContainer.new()
	left.position = Vector2(16, 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	top = _label(22)
	left.add_child(top)
	scorebar = VBoxContainer.new()
	scorebar.add_theme_constant_override(&"separation", 2)
	left.add_child(scorebar)
	minimap = Minimap.new()
	minimap.hide()
	minimap.chosen.connect(_choose)
	add_child(minimap)
	hint = _label(26)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -400
	hint.offset_right = 400
	hint.offset_top = 188   # 方位條、CenterInfo、恐龍體力條都在這上面
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	board = _panel()
	board_rows = _grid(board)
	popup = _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	popup.add_child(box)
	popup_title = _label(40)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(popup_title)
	popup_champ = _label(56)
	popup_champ.add_theme_color_override(&"font_color", GOLD)
	popup_champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(popup_champ)
	popup_rows = _grid(box)
	popup_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hide()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", OUTLINE)
	l.add_theme_constant_override(&"outline_size", 6)
	return l


## 畫面正中間、深色半透明底的框（跟方位條的底色同一系）
func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.04, 0.75)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override(&"panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.hide()
	add_child(p)
	return p


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override(&"h_separation", 36)
	g.add_theme_constant_override(&"v_separation", 6)
	parent.add_child(g)
	return g


func _process(delta: float) -> void:
	var p: Node = main.get(&"party") if main else null
	visible = p != null and not main.lobby.visible
	if p != _party:
		if _party and is_instance_valid(_party):
			_party.changed.disconnect(refresh)
		_party = p
		_phase = &""
		_shown = 0
		if p:
			p.changed.connect(refresh)
			refresh()
	if p == null:
		return
	_result_left -= delta
	board.visible = Input.is_physical_key_pressed(KEY_TAB) and p.phase != &"final" and p.rounds > 1   # 1 局（一般模式）不看分數
	popup.visible = p.phase == &"final" or (p.phase == &"result" and _result_left > 0.0)
	scorebar.visible = p.phase in [&"prep", &"play"] and (p.rounds > 1 or p.team != null)   # 結算、最終排名中間有大框；團隊模式是三隊的人頭
	update_live()


## 每幀換的：倒數、提示、重生點方位（鏡頭會動）
func update_live() -> void:
	var p := _party
	var me := my_id()
	var t := ceili(maxf(p.time_left, 0.0))
	# final 時 round_index 已經加到 rounds：停在最後一回合
	var lines := ["第 %d／%d 回合　　%s %d:%02d" % [mini(p.round_index + 1, p.rounds), p.rounds, PHASES.get(p.phase, ""), t / 60, t % 60],
		"恐龍：%s" % name_of(p.dino_id)]
	if p.team and p.team.team_of(me) >= 0:
		lines.append("你是%s" % Team.NAMES[p.team.team_of(me)])
	if me != p.dino_id and p.lives.has(me) and p.phase in [&"prep", &"play"]:
		lines.append("你剩 %d 條命" % int(p.lives[me]) if int(p.lives[me]) > 0 else "你出局了，觀戰中")
	top.text = "\n".join(lines)
	if main.egg.carrier != _carrier or p.star_holder != _star:
		_fill_scorebar()
	hint.text = ""
	if p.phase == &"prep":
		if main.safe.on:   # 保險箱模式：箱子開場就抽好位置
			hint.text = "保險箱在方位條上，先去你想守的地方" if me == p.dino_id else "看恐龍往哪走"
		elif me != p.dino_id:
			hint.text = "看恐龍把蛋藏去哪"
		else:
			hint.text = "蛋放好了，等牛仔進場" if p.egg_placed else "按 F 把蛋放在腳下"
	var waiting := waiting_respawn()
	if waiting and not _was_waiting:
		picked = -1   # 每次死都重選
	_was_waiting = waiting
	var me_node: Node3D = main._me()
	if me_node:
		_last_pos = me_node.global_position
	minimap.visible = waiting and not spawn_points().is_empty()
	if minimap.visible:
		minimap.main = main
		minimap.red = p.spawn_red
		minimap.picked = picked
		minimap.dead_at = _last_pos
		minimap.queue_redraw()
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:   # 要點圖：游標放出來（重生時 main 會鎖回去）
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hint.text = "點地圖上的綠點、或按 1～%d 選重生點（紅的附近有人，選不了）" % spawn_points().size()


func my_id() -> int:
	return main.multiplayer.get_unique_id()


func name_of(id: int) -> String:
	var n: String = _party.names.get(id, "玩家 %d" % id)
	return n + "（你）" if id == my_id() else n


## 自己是牛仔、死了、還有命：等重生，可以選點
func waiting_respawn() -> bool:
	var me := my_id()
	return _party.phase == &"play" and me != _party.dino_id and int(_party.lives.get(me, 0)) > 0 \
		and main._me() == null


func spawn_points() -> Array:
	var pts: Array = main.spawn_points
	return pts.slice(0, 9)   # 數字鍵只有 1～9


func _unhandled_input(e: InputEvent) -> void:
	if _party == null or not (e is InputEventKey and e.pressed and not e.echo):
		return
	var i: int = e.physical_keycode - KEY_1
	if i < 0 or i >= spawn_points().size() or not waiting_respawn():
		return
	_choose(i)
	get_viewport().set_input_as_handled()


## 選第 i 個重生點（按數字鍵或點圖）。紅的選不了
func _choose(i: int) -> void:
	if _party == null or not waiting_respawn() or (_party.spawn_red >> i) & 1:
		return
	picked = i
	_party.request_respawn_at(i)


## changed 來了：分數板、結算框重排。內容跟上次一樣就不動（約 70 個節點，每秒重建一次在 2 核主機頓 40 毫秒）
func refresh() -> void:
	var p := _party
	var key := hash([p.phase, p.scores, p.round_scores, p.names, p.dino_id, p.last_result, main.egg.carrier, p.star_holder, my_id(),
		p.lives, p.team.of if p.team else null])
	if key == _shown:
		return
	_shown = key
	if p.phase != _phase:
		_phase = p.phase
		if _phase == &"result":
			_result_left = RESULT_SHOW
		if _phase != &"play":
			picked = -1
	var ranked: Array = p.ranking()
	_fill(board_rows, ranked)
	_fill_scorebar()
	popup_rows.visible = p.rounds > 1
	if p.phase == &"final" and p.rounds > 1:
		popup_title.text = "最終排名"
		popup_champ.text = "冠軍　%s　%d 分" % [name_of(ranked[0]), int(p.scores.get(ranked[0], 0))] if ranked else ""
		popup_champ.show()
		_fill(popup_rows, ranked.slice(1), 2)
	else:
		popup_title.text = p.last_result
		popup_champ.hide()
		var by_round := ranked.duplicate()
		by_round.sort_custom(func(a: int, b: int) -> bool: return int(p.round_scores.get(a, 0)) > int(p.round_scores.get(b, 0)))
		_fill(popup_rows, by_round)


## 表格：名次、名字、本回合、總分。first = 第一列的名次
func _fill(g: GridContainer, ids: Array, first := 1) -> void:
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()
	for t in ["名次", "名字", "本回合", "總分"]:
		var h := _label(18)
		h.text = t
		h.modulate = Color(1, 1, 1, 0.6)
		g.add_child(h)
	for i in ids.size():
		var id: int = ids[i]
		for t in [str(first + i), name_of(id), "+%d" % int(_party.round_scores.get(id, 0)), str(int(_party.scores.get(id, 0)))]:
			var l := _label(22)
			l.text = t
			if id == my_id():
				l.add_theme_color_override(&"font_color", GOLD)
			g.add_child(l)


## 左上的計分欄：名次、色塊、名字、總分。拿著蛋的那列多一個「+10」（撤離＋活著，照 balance.csv）、底色變亮；
## 當恐龍的寫「恐龍」；自己那列金色。拿著星星的那列名字後面一顆 ★，他也拿著蛋就寫成 × 倍數（+20）
func _fill_scorebar() -> void:
	_carrier = main.egg.carrier
	_star = _party.star_holder
	for c in scorebar.get_children():
		scorebar.remove_child(c)
		c.queue_free()
	if _party.team:
		_fill_teams()
		return
	var order: Array = _party.scores.keys()
	var ranked: Array = _party.ranking()
	for i in ranked.size():
		var id: int = ranked[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.9, 0.5, 0.35) if id == _carrier else Color(0.1, 0.06, 0.04, 0.45)
		sb.set_content_margin_all(3)
		row.add_theme_stylebox_override(&"panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 8)
		row.add_child(h)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.color = SWATCH[order.find(id) % SWATCH.size()]
		var pad := Control.new()   # 沒拿蛋的列也留「+10」那格的寬，分數才對得齊
		pad.custom_minimum_size.x = 44
		var cells := [str(i + 1), sw, name_of(id) + ("　恐龍" if id == _party.dino_id else "") + ("　★" if id == _star else ""), str(int(_party.scores.get(id, 0))),
			"+%d" % ((Party.SCORE_EXTRACT + Party.SCORE_SURVIVE) * (Party.STAR_MULT if id == _star else 1)) if id == _carrier else pad]
		for c: Variant in cells:
			if c is Control:
				h.add_child(c)
				continue
			var l := _label(20)
			l.text = c
			if id == my_id():
				l.add_theme_color_override(&"font_color", GOLD)
			if h.get_child_count() == 2:   # 名字：撐滿，把分數推到右邊成一欄
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			elif h.get_child_count() == 3:   # 分數：固定寬、靠右
				l.custom_minimum_size.x = 36
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			elif String(c).begins_with("+"):   # 大一級、粗描邊，跟自己那列的金色分得開
				l.custom_minimum_size.x = 44
				l.add_theme_font_size_override(&"font_size", 24)
				l.add_theme_constant_override(&"outline_size", 10)
				l.add_theme_color_override(&"font_color", CARRY)
			h.add_child(l)
		scorebar.add_child(row)


## 團隊模式的左上：每隊一列，隊色的隊名加每個人一個圓點（● 還在場上、○ 出局）。自己那隊後面寫（你）。
## ponytail: 用字畫圓點；T2 加倒地（半滿）時再換成畫的
func _fill_teams() -> void:
	var t: Team = _party.team
	for i in Team.COUNT:
		var ids: Array = t.of.keys().filter(func(id: int) -> bool: return t.of[id] == i)
		var l := _label(20)
		l.text = "%s　%s%s" % [Team.NAMES[i], " ".join(ids.map(func(id: int) -> String: return "●" if int(_party.lives.get(id, 1)) > 0 else "○")),
			"　（你）" if t.team_of(my_id()) == i else ""]
		l.add_theme_color_override(&"font_color", Team.COLORS[i])
		scorebar.add_child(l)
