class_name Room
extends VBoxContainer
## 房間（docs/企劃/2026-11-20-選單流程.md）：開房、加入之後先進這裡等人，房主選模式和局數、按開始。
## 它是大廳（main 的 Lobby）的一頁（LOBBY_PAGES 的 room）：在房間時 main.lobby.visible 還是 true，主機不跑對局、畫面不畫局內資訊。
## 狀態只在主機改：大家按的東西都走 ask 送到主機，主機檢查是不是房主才改；有變就整包送給所有人（_recv），畫面照那包畫。
## 名字固定（Room），RPC 每台找得到。

const HOST_ONLY := [&"mode", &"rounds", &"dino", &"start", &"again", &"back"]   # 只有房主能按的
const PLAY_ONLY := [&"again", &"back"]   # 打的時候才能按的（其他的只在房間裡）

var main: Node
var active := false     # 在房間流程裡（開房、加入，到離開房間為止）
var playing := false    # 正在打（不是在房間等）
var order: Array = []   # 照連進來順序的真人編號（專用伺服器的主機自己不算）
var host_id := 0        # 房主的連線編號；0 = 還沒有（專用伺服器沒人）
var mode := &"normal"   # 現在選的模式（主機：main.rules）
var rounds := 4         # 一般模式幾局（主機：main.normal_rounds）
var want: Array = []    # 想當恐龍的人（主機：main.dino_pool()）
var prepared: Array = []   # 按了「準備」的人（只是一盞燈給房主看，不擋開始）；回房間時清掉
var dino_pick := 0      # 一般模式誰當恐龍：0 = 抽想當的人、-1 = 電腦、正的 = 房主指定的那個人（party.dino_rule）
var connecting := false # 客戶端：按了加入、還沒收到主機的第一包

var _mode_btns := {}    # 模式 -> 按鈕（一般、派對）
var _other: OptionButton   # 其他模式（舊的四個）
var _rounds_row: HBoxContainer
var _round_btns := {}   # 局數 -> 按鈕
var _dino_row: HBoxContainer
var _dino_opt: OptionButton   # 誰當恐龍：抽、電腦、指定：玩家 N（項目的 metadata 是 dino_pick 的值）
var _ready_btn: Button
var _desc: Label
var _list: VBoxContainer
var _bots: Label
var _want: CheckBox
var _addr: Label
var _start: Button
var _title: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	custom_minimum_size.x = 640
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 22)
	add_child(_title)
	var row := _row("模式")
	var group := ButtonGroup.new()
	for k: StringName in main.RULES:
		if main.RULES[k].legacy:
			continue
		_mode_btns[k] = _toggle(row, main.RULES[k].name, group, ask.bind(&"mode", k))
	if not main.RULES.has(&"team"):   # 團隊模式還沒做：先佔一格（T1 在規則表加一筆就換成真的）
		var t := Button.new()
		t.text = "團隊（製作中）"
		t.disabled = true
		row.add_child(t)
	_other = OptionButton.new()
	_other.add_item("其他模式 ▾")
	for k: StringName in main.RULES:
		if main.RULES[k].legacy:
			_other.add_item(main.RULES[k].name + "（舊）")
			_other.set_item_metadata(_other.item_count - 1, k)
	_other.item_selected.connect(func(i: int) -> void:
		if i > 0:
			ask(&"mode", _other.get_item_metadata(i)))
	row.add_child(_other)
	_rounds_row = _row("局數")
	var rg := ButtonGroup.new()
	for n: int in [4, 1]:
		_round_btns[n] = _toggle(_rounds_row, "%d 局" % n, rg, ask.bind(&"rounds", n))
	_dino_row = _row("恐龍")
	_dino_opt = OptionButton.new()
	_dino_opt.custom_minimum_size.x = 220
	_dino_opt.item_selected.connect(func(i: int) -> void: ask(&"dino", _dino_opt.get_item_metadata(i)))
	_dino_row.add_child(_dino_opt)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(600, 48)
	_desc.modulate = Color(1, 0.88, 0.65)
	add_child(_desc)
	add_child(HSeparator.new())
	_list = VBoxContainer.new()
	add_child(_list)
	_bots = Label.new()
	_bots.modulate = Color(1, 1, 1, 0.6)
	add_child(_bots)
	add_child(HSeparator.new())
	_want = CheckBox.new()
	_want.text = "我想當恐龍"
	_want.toggled.connect(_on_want)
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override(&"separation", 24)
	add_child(mine)
	mine.add_child(_want)
	_ready_btn = _button(mine, "準備", ask.bind(&"ready"))
	_ready_btn.custom_minimum_size.x = 120
	_addr = Label.new()
	add_child(_addr)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 12)
	add_child(bottom)
	_start = _button(bottom, "開始", ask.bind(&"start"))
	_start.custom_minimum_size.x = 160
	_button(bottom, "設定", main.open_settings.bind(0))
	_button(bottom, "離開房間", main._on_leave_pressed)
	refresh()


func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 48
	r.add_child(l)
	add_child(r)
	return r


func _toggle(parent: Node, text: String, group: ButtonGroup, fn: Callable) -> Button:
	var b := _button(parent, text, fn)
	b.toggle_mode = true
	b.button_group = group
	return b


func _button(parent: Node, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


# --- 主機 ---

## 開房：自己（開房的人）是房主；專用伺服器（dedicated）沒有自己，第一個連進來的人當房主
func open(dedicated: bool) -> void:
	active = true
	playing = false
	connecting = false
	order = [] if dedicated else [1]
	host_id = 0 if dedicated else 1
	push()


## 有人連進來：排在名單最後；還沒有房主就是他
func join(id: int) -> void:
	if order.has(id):
		return
	order.append(id)
	if host_id == 0:
		host_id = id
	push()


## 有人走了：名單拿掉；房主走了交給下一個最早進來的（只有專用伺服器會這樣：開房的人走了房間就關了）
func leave(id: int) -> void:
	if not order.has(id):
		return
	order.erase(id)
	prepared.erase(id)
	if dino_pick == id:   # 指定的人走了：改回抽
		dino_pick = 0
	if host_id == id:
		host_id = order[0] if not order.is_empty() else 0
	push()


## 主機：整包送給大家，自己的畫面也照著更新
func push() -> void:
	if main.multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	var s := state()
	_apply(s)
	_recv.rpc(s)


func state() -> Dictionary:
	return {playing = playing, order = order, host_id = host_id, mode = main.rules, rounds = main.normal_rounds, want = main.dino_pool(),
		prepared = prepared, dino_pick = dino_pick}


## 大家按的東西：客戶端送到主機；主機自己按直接處理
@rpc("any_peer", "call_remote", "reliable")
func ask(what: StringName, v: Variant = null) -> void:
	if not multiplayer.is_server():
		ask.rpc_id(1, what, v)
		return
	var from := multiplayer.get_remote_sender_id()
	handle(from if from != 0 else multiplayer.get_unique_id(), what, v)


## 主機：from 按了 what。只有房主能改設定、按開始、再來一場、回房間；設定、開始只在房間裡，再來一場、回房間只在打的時候
func handle(from: int, what: StringName, v: Variant = null) -> void:
	if not active or (what in PLAY_ONLY) != playing or (what in HOST_ONLY and from != host_id):
		return
	match what:
		&"mode":
			var m := StringName(str(v))
			if main.RULES.has(m):
				main._on_mode_picked(main.RULES.keys().find(m))
		&"rounds":
			if v is int and v in [1, 4]:
				main.normal_rounds = v
		&"dino":
			if v is int and (v <= 0 or order.has(v)):
				dino_pick = maxi(v, -1)
		&"ready":   # 準備：再按一次取消
			if prepared.has(from):
				prepared.erase(from)
			else:
				prepared.append(from)
		&"start":
			main.start_match()
			return
		&"again":
			main.play_again()
			return
		&"back":
			main.back_to_room()
			return
	push()


# --- 每台 ---

@rpc("authority", "call_remote", "reliable")
func _recv(s: Dictionary) -> void:
	_apply(s)
	if playing and main.lobby.visible:   # 開打了（或連進來時已經在打）：進場
		main._enter_game("已連線。WASD 移動，滑鼠瞄準，左鍵開槍，右鍵舉槍")
	elif not playing and not main.lobby.visible:   # 打完回房間
		main._show_room()


func _apply(s: Dictionary) -> void:
	for k: String in s:
		set(k, s[k])
	connecting = false
	refresh()


## 客戶端按了加入：先停在房間頁，等主機送第一包
func wait_join() -> void:
	active = true
	playing = false
	connecting = true
	order = []
	host_id = 0
	refresh()


## 離開房間（回大廳）
func close() -> void:
	active = false
	playing = false
	connecting = false
	order = []
	host_id = 0


func is_host() -> bool:
	return active and main.multiplayer.multiplayer_peer != null and host_id == multiplayer.get_unique_id()


## 名單上的稱呼：照進來的順序（派對、一般模式的名字也照這個順序，party._humans）
func name_of(id: int) -> String:
	var i := order.find(id)
	return "玩家 %d" % (i + 1) if i >= 0 else "玩家"


func _on_want(on: bool) -> void:
	main.want_dino = on
	if main.multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		push()
	else:
		main._volunteer.rpc_id(1, on)


func refresh() -> void:
	if _title == null:
		return
	var me := multiplayer.get_unique_id() if main.multiplayer.multiplayer_peer != null else 0
	var host := is_host()
	_title.text = "連線中…" if connecting else ("跟電腦打" if main._offline else "房間")
	for k: StringName in _mode_btns:   # 選中的前面加 ●：不是房主時按鈕是灰的，看不出哪個按下去
		_mode_btns[k].set_pressed_no_signal(k == mode)
		_mode_btns[k].text = ("● " if k == mode else "") + main.RULES[k].name
		_mode_btns[k].disabled = not host
	var oi := 0
	for i in range(1, _other.item_count):
		if _other.get_item_metadata(i) == mode:
			oi = i
	_other.select(oi)
	_other.disabled = not host
	_rounds_row.visible = mode == &"normal"
	for n: int in _round_btns:
		_round_btns[n].set_pressed_no_signal(n == rounds)
		_round_btns[n].text = ("● " if n == rounds else "") + "%d 局" % n
		_round_btns[n].disabled = not host
	_desc.text = main.RULES[mode].desc if main.RULES.has(mode) else ""
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for id: int in order:
		var l := Label.new()
		l.text = "%s %s%s%s%s　　%s" % ["★" if id == host_id else "　", name_of(id), "（房主）" if id == host_id else "",
			"（你）" if id == me else "", "　　想當恐龍" if want.has(id) else "", "準備好了" if prepared.has(id) else "還沒"]
		_list.add_child(l)
	_dino_row.visible = mode == &"normal"
	_dino_opt.clear()
	for pair: Array in [[0, "抽想當的人"], [-1, "電腦"]] + order.map(func(id: int) -> Array: return [id, "指定：" + name_of(id)]):
		_dino_opt.add_item(pair[1])
		_dino_opt.set_item_metadata(_dino_opt.item_count - 1, pair[0])
		if pair[0] == dino_pick:
			_dino_opt.select(_dino_opt.item_count - 1)
	_dino_opt.disabled = not host
	_ready_btn.text = "準備好了 ✓" if prepared.has(me) else "準備"
	_ready_btn.disabled = connecting
	if order.is_empty():
		var l := Label.new()
		l.text = "等主機回覆…" if connecting else "還沒有人"
		_list.add_child(l)
	_bots.text = {&"normal": "不到 3 個獵人用電腦補，沒人當恐龍就電腦當", &"party": "不到 4 個人用電腦補"}.get(mode, "")
	_want.set_pressed_no_signal(main.want_dino)
	_want.disabled = connecting
	var self_host: bool = host and multiplayer.is_server() and not main._offline
	_addr.visible = self_host
	_addr.text = "本機位址 %s（給朋友填）" % main._ips
	_start.visible = host
