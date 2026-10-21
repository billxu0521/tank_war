extends Node3D
## Outlaws vs Dinosaurs 法外狂徒大戰恐龍（簡稱 OvD）— 區網原型。兩個模式：連線模式（大家都是牛仔，第一人稱）和沙盒模式。
## Esc 選單裡的「遊戲局控制」讓主機加移動標靶、牛仔 bot。恐龍的程式都還在，玩法定了再接回來。

const PORT := 24680
## 測試站：雲端主機上一直開著的專用伺服器（`-- --server`，見 README 的「測試站」）。
## 還沒架好就空著，大廳的「連到測試站」按鈕會關掉
const TEST_SERVER := ""
const NEXT_ROUND_DELAY := 10.0   # 專用伺服器一局結束後隔幾秒開下一局
# 沙盒的靶場：從 (0, 84) 往 -Z 打到 100 公尺，這一條不蓋東西。撤離區在東西兩端，不會壓到
const SANDBOX_RANGE := Rect2(-20, -30, 40, 112)   # 靶在路兩側 4 公尺、恐龍靶 12 公尺；再窄旁邊的坡會超過 40 度
const SANDBOX_START := Vector3(0, 0.1, 76)   # y 是離地高度，用 _on_ground() 換成實際位置
const SANDBOX_TARGETS := [10, 25, 50, 100]   # 牛仔靶的距離（公尺）：左輪、散彈、步槍各自的有效距離
const PICKUP_RANGE := 3.0     # 牛仔靠這麼近就撿得到蛋
const PICKUP_SECONDS := 2.0   # 撿蛋要連續待滿這麼久，不是碰到就拿
const EXTRACT_SECONDS := 5.0  # 要在撤離區內連續待滿這麼久
const EGG_HOLD_HEIGHT := 2.4  # 蛋舉在牛仔頭上多高（腳底算起），低了會擋住自己的鏡頭
const MATCH_SECONDS := 240.0  # 一局四分鐘
const RESPAWN_DELAY := 5.0    # 死亡的代價是節奏，不是失去參賽資格
const COWBOY := preload("res://cowboy/cowboy.tscn")
const DINO := preload("res://dino.tscn")
const BOSS := preload("res://boss.tscn")
const BOSS_ID := -999   # 負數＝電腦（主機操控）；固定編號，場上最多一隻

@onready var lobby: VBoxContainer = $UI/Root/Lobby
@onready var ip_edit: LineEdit = $UI/Root/Lobby/IPRow/IP
@onready var saved_ips: MenuButton = $UI/Root/Lobby/IPRow/SavedIpBtn
@onready var center_info: Label = $UI/Root/CenterInfo   # 方位條下面：重生倒數、撤離倒數
@onready var net_info: Label = $UI/Root/NetInfo         # 右上角：本機 IP、延遲、每秒畫面數
@onready var result: Control = $UI/Root/Result          # 勝負畫面
@onready var status: Label = $UI/Root/Status
@onready var hud: Label = $UI/Root/Hud
@onready var stamina_bar: ProgressBar = $UI/Root/Stamina
@onready var crosshair: Label = $UI/Root/Crosshair
@onready var menu: Control = $UI/Root/Menu
@onready var players: Node3D = $Players
@onready var egg: Egg = $Egg
@onready var mode_pick: OptionButton = $UI/Root/Lobby/ModeRow/ModePick

## 連線對戰的模式：開房的人在大廳選，加入的人照主機的（連進來時主機會送 _set_rules）。
## 模式表在 match_rules.gd（欄位說明也在那裡）
const RULES := MatchRules.RULES
var rules := &"egg"
var _lives := {}   # 牛仔的連線編號 -> 還能重生幾次。只有用得到次數的模式有；主機算，廣播給大家（_sync_lives）
var _out := {}     # 出局的牛仔：連線編號 -> 是不是 bot（新的一局要生回來）
var party: Party   # 派對模式的回合、計分（party.gd）；不是派對模式是 null
var _party_hud: PartyHud   # 派對模式的畫面（方位條要問它是不是在選重生點）
var _match_hud: MatchHud   # 局內的畫面資訊（match_hud.gd）：方位條、倒數、準心、boss 條、左上角那行字
@onready var map: ArenaMap = $Arena   # 場地：地形、擺設、門、撤離區都在 arena_map.gd
const ARENA := ArenaMap.ARENA
const EXIT_RADIUS := ArenaMap.EXIT_RADIUS
## 場地狀態的只讀轉接：外面只讀，要改去 map 那邊改
var _terrain: Terrain:
	get: return map._terrain
var _props: Dictionary:
	get: return map._props
var _exit_pads: Array[Node3D]:
	get: return map._exit_pads
var _exits: Array[Vector3]:
	get: return map._exits
var spawn_points: Array[Vector3]:
	get: return map.spawn_points
var dino_spawn: Vector3:
	get: return map.dino_spawn
var _doors: Array[Door]:
	get: return map._doors
var _wrecks: Array[Destructible]:
	get: return map._wrecks
var _drift: Node3D:
	get: return map._drift
## 場地的一行轉接（給牛仔、派對、bot 用，名字不變）
func _on_ground(v: Vector3) -> Vector3: return map._on_ground(v)
func _spawn_point(span := ARENA * 0.45) -> Vector3: return map._spawn_point(span)
func _is_clear(p: Vector2, radius := 0.0) -> bool: return map._is_clear(p, radius)
func hidden_in_bush(who: Node3D) -> bool: return map.hidden_in_bush(who)

## 手調過的場景檔（在 Godot 編輯器裡改，見 docs/素材流水線/場景編輯.md）。烘焙工具設成空的：不讀場景檔，自動擺一份初稿
## 目前的地圖：&"" 是主地圖（連線、沙盒），&"range" 是靶場。靜態的：換地圖要重載整個場景，重載後還記得
static var mode := &""
const RANGE_LEVEL := "res://levels/range.tscn"
## 主地圖是灰盒（素模，greybox.gd）：先專心調玩法。舊的牧場留著，測試和 level_file 指定時才用
const GREYBOX_LEVEL := "res://levels/greybox.tscn"
const RANCH_LEVEL := "res://levels/ranch.tscn"
static var level_file := ""   # 指定主地圖（測試切回牧場用）；空的就是灰盒
var level_path := RANGE_LEVEL if mode == &"range" else (level_file if level_file != "" else GREYBOX_LEVEL)
## 灰盒地圖：地面換格線、不長草不撒碎物、固定正午、不開像素風（pixel_style.gd）
var greybox: bool:
	get: return level_path == GREYBOX_LEVEL

## 沙盒靶道要空著的範圍（擺設檢查 LevelCheck 用）：靶場地圖沒有（null）；灰盒只留靶子那一條（中央要放東西）
const GREYBOX_LANE := Rect2(-7, -30, 14, 112)
static func lane_of(path: String) -> Variant:
	if path == RANGE_LEVEL:
		return null
	return GREYBOX_LANE if path == GREYBOX_LEVEL else SANDBOX_RANGE
var _cowboys := 0
var _offline := false
var _dedicated := false   # 專用伺服器（測試站）：主機自己不是玩家
var _next_round := 0.0
var _time_left := 0.0
var _clock := 0                     # 主機廣播的剩餘秒數
var _respawn_queue: Array[Dictionary] = []
var _claimer := 0   # 正在撿蛋的牛仔編號
var _over := false
## 沙盒：沒有時間限制、沒有蛋，靶打死會在原地重生，子彈無限
var _sandbox := false
var _solo_dino := false   # 單人打恐龍（測恐龍行為用）：沙盒的場地，只有自己和恐龍 boss，接關無限
var _continues := 0       # 單人打恐龍：接關了幾次

func _ready() -> void:
	BugReport.install()
	# 視窗開最大（填滿螢幕）。只在還是預設大小時才放大：截圖工具用 --resolution 指定了別的大小，照它的，不然裁切位置會跑掉
	# （--resolution 是引擎吃掉的參數，OS.get_cmdline_args 看不到，只能看視窗大小）
	# 要延到 _ready 跑完：macOS 放大視窗會當場先跑一幀 _process，那時場地、問題回報都還沒建好，一路報錯、編輯器停住
	var base := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	if DisplayServer.get_name() != "headless" and get_window().size == base:
		get_window().set_deferred(&"mode", Window.MODE_MAXIMIZED)
	_add_report_button()
	_party_hud = PartyHud.new()   # 派對模式的畫面（party_hud.gd），party 是 null 時自己藏起來
	_party_hud.main = self
	$UI/Root.add_child(_party_hud)
	ModelMaterials._flatten_models()
	_use_cjk_font()
	_add_settings()
	_ips = _local_ips()
	_load_saved_ips()
	_load_settings()
	saved_ips.get_popup().index_pressed.connect(func(i: int) -> void:
		ip_edit.text = saved_ips.get_popup().get_item_text(i))
	for k: StringName in RULES:
		mode_pick.add_item(RULES[k].name)
	_on_mode_picked(0)
	map._use_sky()
	map._use_outline()
	Period.snapshot(self)   # 要在像素風疊上去之前：記下的是夕陽原本的天空、霧
	add_child(preload("res://pixel_style.gd").new())   # 像素風＋夕陽調色，F9 開關（pixel_style.gd）
	map._load_props()
	map._skin_egg()
	map._load_level()
	map._build_arena()
	OilLantern.replace_baked($Arena, _props.get(&"Lantern"), _props)   # 模型上的提燈換成打得破的油燈（lantern.gd）
	map._dark_windows()
	if mode != &"range":
		map._build_exits()
	_load_period()
	_add_dino_volunteer()
	_build_home()
	Period.apply(self, period)
	_match_hud = MatchHud.new(self)
	multiplayer.auth_callback = _on_auth   # 版本檢查（連線認證）；SceneMultiplayer 本身不換，_to_lobby 重設 peer 也不會清掉
	multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	multiplayer.peer_connected.connect(_spawn)
	multiplayer.peer_disconnected.connect(_despawn)
	multiplayer.connected_to_server.connect(func() -> void:
		status.text = "已連線。WASD 移動，滑鼠瞄準，左鍵開槍，右鍵舉槍"
		_volunteer.rpc_id(1, want_dino))
	multiplayer.connection_failed.connect(
		func() -> void: _to_lobby.call_deferred("連線失敗，檢查 IP 和防火牆"))
	multiplayer.server_disconnected.connect(
		func() -> void: _to_lobby.call_deferred("主機斷線了"))
	_autostart.call_deferred()

## 啟動參數，方便在同一台機器開兩個視窗對打：
##   OvD.exe -- --host
##   OvD.exe -- --join 192.168.1.5
##   OvD.exe -- --sandbox
##   OvD.exe -- --range
##   OvD.exe -- --viewer
##   OvD.exe -- --solo-dino    單人打恐龍（測恐龍行為）
##   OvD.exe -- --host --mode deathmatch    指定模式（egg、deathmatch、dino_duel）
##   OvD.exe -- --host --period midnight    指定時段（sunset、noon、midnight），不填用大廳上次選的
##   godot --headless -- --server    專用伺服器（測試站）：自己不下場，一局結束自動開下一局
func _autostart() -> void:
	var args := OS.get_cmdline_user_args()
	var mi := args.find("--mode")   # --mode deathmatch / dino_duel / egg（開房和專用伺服器用）
	if mi >= 0 and mi + 1 < args.size() and RULES.has(StringName(args[mi + 1])):
		_on_mode_picked(RULES.keys().find(StringName(args[mi + 1])))
	var test_btn: Button = $UI/Root/Lobby/TestServerBtn
	test_btn.disabled = TEST_SERVER == ""
	if test_btn.disabled:
		test_btn.text = "連到測試站（還沒架好）"
	if mode == &"range" or args.has("--range"):
		_start_range()
	elif args.has("--server"):
		_start_dedicated()
	elif args.has("--host"):
		_on_host_pressed()
	elif args.has("--sandbox"):
		_on_sandbox_pressed()
	elif args.has("--solo-dino"):
		_on_solo_dino_pressed()
	elif args.has("--viewer"):
		_on_viewer_pressed()
	else:
		var i := args.find("--join")
		if i >= 0 and i + 1 < args.size():
			ip_edit.text = args[i + 1]
			_on_join_pressed()

## 診斷（暫時，滑鼠視角卡住的 bug 修好就拿掉）：_input 在介面之前收到，跟角色收到的次數比，看事件是不是被介面吃掉
var _diag_t := 0.0
func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		Fighter._diag("遊戲收到")

func _diag_print(delta: float) -> void:
	_diag_t += delta
	if _diag_t < 0.5 or Fighter.diag.is_empty():
		return
	_diag_t = 0.0
	var hov := get_viewport().gui_get_hovered_control()
	print("[滑鼠診斷] %s　鎖定=%s　視窗焦點=%s　選單=%s　滑鼠下的介面=%s" % [
		Fighter.diag, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, get_window().has_focus(), menu.visible,
		hov.get_path() if hov else "無"])
	Fighter.diag.clear()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F8:
		report_bug()   # 大廳、遊戲中都能按
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F3:
		debug_hud = not debug_hud
		return
	var esc: bool = e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE
	if esc and settings.visible:   # 設定開著：Esc 只關它，停在原本的畫面
		settings.hide()
		return
	if lobby.visible:
		if esc and lobby_page != &"home":
			lobby_go(&"home")
		return
	if esc:
		_set_menu(not menu.visible)
	elif e is InputEventMouseButton and e.pressed and not menu.visible and not result.visible:
		Fighter.lock_mouse()  # 點畫面重新鎖回滑鼠

# --- 問題回報（bug_report.gd）---

## Esc 選單裡的「回報問題」，放在「離開遊戲」上面
func _add_report_button() -> void:
	var b := Button.new()
	b.name = "ReportBtn"
	b.text = "回報問題（F8）"
	b.pressed.connect(report_bug)
	var box := $UI/Root/Menu/Box
	box.add_child(b)
	box.move_child(b, $UI/Root/Menu/Box/QuitBtn.get_index())

## 設定視窗（settings.gd）：主選單和 Esc 選單共用。Esc 選單放「設定」和「操作說明」（直接開按鍵頁）
var settings: Settings

func _add_settings() -> void:
	settings = Settings.new(self)
	$UI/Root.add_child(settings)
	# 視窗不會跟著選單藏：一局結束、回大廳時會擋住畫面。在主選單開的不算（那時選單本來就沒開）
	menu.visibility_changed.connect(func() -> void: if not menu.visible: settings.hide())
	var box := $UI/Root/Menu/Box
	for pair: Array in [["ControlsBtn", "操作說明", 3], ["SettingsBtn", "設定", 0]]:
		var btn := Button.new()
		btn.name = pair[0]
		btn.text = pair[1]
		btn.pressed.connect(open_settings.bind(pair[2]))
		box.add_child(btn)
		box.move_child(btn, $UI/Root/Menu/Box/ResumeBtn.get_index() + 1)

func open_settings(tab: int) -> void:
	settings.tabs.current_tab = tab
	settings.popup_centered()

## 存回報檔、複製到剪貼簿，告訴玩家貼到哪裡。回傳存檔路徑（測試用）
func report_bug() -> String:
	var path := BugReport.instance.save(_game_state())
	status.text = ("回報存好了，也複製到剪貼簿：貼到 Discord 這一版的討論串就好\n" + path) if path != "" \
		else "回報存檔失敗（已複製到剪貼簿，直接貼到 Discord）"
	return path

## 報告裡的「遊戲」那一行：在哪、玩什麼、當誰、連線狀況
func _game_state() -> String:
	if lobby.visible:
		return "在大廳"
	var me := _me()
	var role := "觀戰" if me == null else ("恐龍" if me.is_in_group(&"dino") else "牛仔")
	var where := "單人打恐龍" if _solo_dino else ("沙盒" if _sandbox else ("靶場" if mode == &"range" else String(RULES.get(rules, {}).get("name", rules))))
	var net := "離線" if _offline else ("專用伺服器" if _dedicated else ("主機" if multiplayer.is_server() else "連線中（編號 %d）" % multiplayer.get_unique_id()))
	return "%s　當%s　%s　場上 %d 個角色" % [where, role, net, players.get_child_count()]

# --- 暫停選單 ---

func _set_menu(open: bool) -> void:
	menu.visible = open
	# 遊戲局控制只有主機（和沙盒）能用：bot 都在主機上跑
	$UI/Root/Menu/Box/Controller.visible = multiplayer.is_server()
	if open:
		_fill_weapon_info()
		_show_cursor()
	else:
		Fighter.lock_mouse()

## Esc 選單右邊的武器介紹：手上幾把槍並排比。數字從參數算出來（weapon.gd 的 info_rows），不另外填。
## 當恐龍、或還沒進遊戲就不顯示
func _fill_weapon_info() -> void:
	var grid: GridContainer = menu.get_node_or_null(^"WeaponInfo")
	if grid == null:
		grid = GridContainer.new()
		grid.name = "WeaponInfo"
		grid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
		grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		grid.add_theme_constant_override(&"h_separation", 24)
		grid.add_theme_constant_override(&"v_separation", 6)
		menu.add_child(grid)
	for c in grid.get_children():
		c.free()
	var me := players.get_node_or_null(str(multiplayer.get_unique_id()))
	var vm: Node = me.get(&"viewmodel") if me else null
	grid.visible = vm != null
	if vm == null:
		return
	var guns: Array = vm._weapons
	grid.columns = guns.size() + 1
	var cells: Array = [["武器"]]
	for w: Weapon in guns:
		cells[0].append(w.display_name)
	var rows: Array = guns[0].info_rows()
	for r in rows.size():
		var line: Array = [rows[r][0]]
		for w: Weapon in guns:
			line.append(w.info_rows()[r][1])
		cells.append(line)
	for line: Array in cells:
		for i in line.size():
			var l := Label.new()
			l.text = line[i]
			l.add_theme_font_size_override(&"font_size", 15)
			if i == 0 or line == cells[0]:
				l.modulate = Color(1.0, 0.85, 0.55)
			grid.add_child(l)

## 放開滑鼠並把游標搬到畫面中間。macOS（尤其在編輯器內嵌的遊戲視窗）從鎖定切回來時，
## 游標常常解鎖了卻沒畫出來；搬一下會強迫系統重畫，也剛好落在選單按鈕旁邊
func _show_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)

func _on_resume_pressed() -> void:
	_set_menu(false)

func _on_leave_pressed() -> void:
	_to_lobby("")

func _on_quit_pressed() -> void:
	get_tree().quit()

## 斷線 + 清乾淨，回到可以重新開房／加入的狀態
func _to_lobby(msg: String) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	for p in players.get_children():
		p.free()  # 用 free 不用 queue_free，不然馬上重開會撞到同名節點
	_cowboys = 0
	_volunteers.clear()
	_pilot_picked = false
	_over = false
	_offline = false
	_sandbox = false
	_solo_dino = false
	_lives.clear()
	_out.clear()
	rules = RULES.keys()[mode_pick.selected]   # 加入別人的房間時被主機改過，回大廳換回自己選的
	if Period.current != period:   # 時段也是
		Period.apply(self, period)
	_apply_rules()
	if party:   # 大廳選的是派對：開局時才建（不然畫面會疊在大廳上）
		party.free()
		party = null
	egg.visible = true
	for n in get_tree().get_nodes_in_group(&"sandbox_prop"):
		n.free()
	_time_left = 0.0
	_respawn_queue.clear()
	egg.carrier = 0
	menu.hide()
	result.hide()
	_match_hud.reset()
	lobby.show()
	status.text = msg
	_show_cursor()
	# 靶場是另一張地圖：回大廳就重載回牧場（測試自己組的場景不是 current_scene，不重載）。
	# 甩尾拆過東西也重載：下一局（或加入別人的房間）場地要是完整的
	var wrecked := _wrecks.any(func(w: Destructible) -> bool: return w.hits > 0)
	if mode == &"range" or wrecked:
		mode = &""
		if get_tree().current_scene == self:
			get_tree().reload_current_scene.call_deferred()

# --- 連線 ---

## 版本檢查（Godot 內建的連線認證）：認證完成前不 spawn、不送 RPC，所以舊版本不會打架。
## 客戶端連上主機時先送自己的版本；主機比對，同版回 "ok" 放行，不同版回一句錯誤訊息，再斷線
func _on_peer_authenticating(id: int) -> void:
	if not multiplayer.is_server():
		multiplayer.send_auth(id, str(ProjectSettings.get_setting("application/config/version")).to_utf8_buffer())

func _on_auth(id: int, data: PackedByteArray) -> void:
	var text := data.get_string_from_utf8()
	if not multiplayer.is_server():   # 客戶端：收到的是主機的回覆
		if text == "ok":
			multiplayer.complete_auth(id)
		else:
			_to_lobby.call_deferred(text)
		return
	var mine := str(ProjectSettings.get_setting("application/config/version"))
	if text == mine:
		multiplayer.send_auth(id, "ok".to_utf8_buffer())
		multiplayer.complete_auth(id)
		return
	multiplayer.send_auth(id, ("版本不同：主機是 %s，你是 %s，請更新到一樣的版本" % [mine, text]).to_utf8_buffer())
	if _dedicated:
		print("擋下版本不同的客戶端（編號 %d）：他是 %s，主機是 %s" % [id, text, mine])
	# 等 0.2 秒讓訊息送出再斷；這段內客戶端自己斷了也沒關係
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if id in multiplayer.get_authenticating_peers():   # 客戶端已經自己斷了就不用踢（踢不存在的連線會報錯）
			multiplayer.multiplayer_peer.disconnect_peer(id))

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT) != OK:
		status.text = "開房失敗，連接埠 %d 可能被占用" % PORT
		return
	multiplayer.multiplayer_peer = peer
	_enter_game("%s模式：等人加入…  本機 IP：%s" % [RULES[rules].name, _local_ips()])
	_apply_rules()
	_spawn(1)
	if RULES[rules].dino:
		spawn_boss()

## 專用伺服器：開房但自己不下場（沒有編號 1 的牛仔），恐龍 boss 照生。
## 一局結束 NEXT_ROUND_DELAY 秒後自動開下一局，不用有人去按
func _start_dedicated() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT) != OK:
		printerr("開不了伺服器，連接埠 %d 可能被占用" % PORT)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	_dedicated = true
	# 物理 120Hz 只是為了畫面順（README「為什麼物理跑 120Hz」），伺服器沒畫面：60 次就夠，處理器省一半。
	# 測試站（1 顆處理器）跑 120 次算不完，遊戲時間會變慢（2026-10-18 測試站回報）
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60   # 沒畫面也會一直空轉：不鎖的話吃滿一顆處理器，跟物理一樣次數就夠
	_enter_game("專用伺服器")
	_apply_rules()
	if RULES[rules].dino:
		spawn_boss()
	print("測試站開好了，連接埠 %d（UDP）" % PORT)

## 主選單分兩層：首頁四顆按鈕，「連線對戰」「單人練習」各一頁，按「返回」或 Esc 回首頁。
## 第二層的按鈕還是 Lobby 底下原本那些（場景裡接好的訊號不動），換頁只是藏起來。
## Lobby 底下加新東西要登記在這裡，沒登記的換頁時會被藏掉
const LOBBY_PAGES := {
	&"home": ["Title", "HomeOnline", "HomePractice", "HomeSettings", "HomeQuit"],
	&"online": ["Title", "OnlineLabel", "ModeRow", "DinoVolunteer", "ModeDesc", "HostBtn", "JoinBtn", "IPRow", "TestServerBtn", "BackBtn"],
	&"practice": ["Title", "PracticeLabel", "SandboxBtn", "SoloDinoBtn", "SoloPartyBtn", "RangeBtn", "ViewerBtn", "BackBtn"],
}
var lobby_page := &"home"

func _build_home() -> void:
	for b: Array in [["HomeOnline", "連線對戰", lobby_go.bind(&"online")], ["HomePractice", "單人練習", lobby_go.bind(&"practice")],
			["HomeSettings", "設定", open_settings.bind(0)], ["HomeQuit", "離開遊戲", _on_quit_pressed],
			["BackBtn", "← 返回", lobby_go.bind(&"home")]]:
		var btn := Button.new()
		btn.name = b[0]
		btn.text = b[1]
		btn.custom_minimum_size.y = 48
		btn.pressed.connect(b[2])
		lobby.add_child(btn)
	lobby_go(&"home")

func lobby_go(page: StringName) -> void:
	lobby_page = page
	for c: Node in lobby.get_children():
		c.visible = String(c.name) in LOBBY_PAGES[page]

## 大廳選模式：記下來、說明換成那個模式的
func _on_mode_picked(i: int) -> void:
	rules = RULES.keys()[i]
	mode_pick.select(i)
	$UI/Root/Lobby/ModeDesc.text = RULES[rules].desc

## 時段（period.gd）：大廳選，存在設定檔。開房、沙盒、靶場都用這個；加入別人的房間時照主機的（_set_period）
var period := &"sunset"

## 時段：設定視窗「畫面」頁選，存在設定檔。專用伺服器用啟動參數 --period noon / midnight
func _load_period() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	period = StringName(cfg.get_value("display", "period", "sunset"))
	if greybox:
		period = &"noon"   # 灰盒固定白天，不分心（要換還是能在設定裡換，重開回正午）
	var args := OS.get_cmdline_user_args()
	var pi := args.find("--period")
	if pi >= 0 and pi + 1 < args.size():
		period = StringName(args[pi + 1])
	if not Period.PRESETS.has(period):
		period = &"sunset"

func _on_period_picked(i: int) -> void:
	period = Period.NAMES.keys()[i]
	_save_setting("display", "period", String(period))
	if lobby.visible:   # 遊戲中只存下來，回大廳才換：時段是整間房間一起的，自己先換會跟別人不一樣（暗處看得比較清楚）
		Period.apply(self, period)

## 大廳「我想當恐龍」：對抗模式每局從勾的人裡抽一個操作尼諾拉（docs/規劃/2026-10-18-對抗模式.md）
var want_dino := false
var _volunteers := {}   # 主機：想當恐龍的人（編號 -> true）
var _pilot_picked := false   # 這局已經抽過了（make_pilot 設、_new_round 和回大廳清）

func _add_dino_volunteer() -> void:
	var c := CheckBox.new()
	c.name = &"DinoVolunteer"
	c.text = "我想當恐龍（對抗模式）"
	c.toggled.connect(func(on: bool) -> void: want_dino = on)
	var lobby_box := $UI/Root/Lobby
	lobby_box.add_child(c)
	lobby_box.move_child(c, $UI/Root/Lobby/ModeRow.get_index() + 1)

## 連上之後告訴主機自己想不想當恐龍
@rpc("any_peer", "call_remote", "reliable")
func _volunteer(on: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if on:
		_volunteers[id] = true
	else:
		_volunteers.erase(id)

func _boss() -> Node:
	return players.get_node_or_null(NodePath(str(BOSS_ID)))

## 對抗模式：尼諾拉沒人操作、又有人想當，就從想當的人裡抽一個（主機每幀問一次，很便宜）
func _pick_pilot() -> void:
	var b := _boss()
	# 一局只抽一次：駕駛中途斷線就讓電腦接手到這局結束，不然會把別人正在玩的牛仔（和身上的蛋）收掉。
	# 沙盒、單人打恐龍、靶場的 rules 還是大廳選的那個，不能誤抽
	if not RULES[rules].pilot or b == null or b.pilot != 0 or _pilot_picked or _practice():
		return
	var pool: Array = _volunteers.keys().filter(func(id: int) -> bool: return multiplayer.get_peers().has(id))
	if want_dino and not _dedicated:   # 開房的人自己勾的（他不用送 _volunteer）
		pool.append(1)
	if not pool.is_empty():
		make_pilot(pool.pick_random())

## 讓 id 操作尼諾拉：他的牛仔收掉、不排重生
func make_pilot(id: int) -> void:
	var b := _boss()
	if b == null:
		return
	b.pilot = id
	_pilot_picked = true
	var p := players.get_node_or_null(NodePath(str(id)))
	if p:
		players.remove_child(p)
		p.queue_free()
		_cowboys -= 1
	_respawn_queue = _respawn_queue.filter(func(r: Dictionary) -> bool: return int(r["id"]) != id)
	var msg := "你是尼諾拉！左鍵 咬　右鍵 撲擊　Space 蓄力甩尾　Shift 跑"
	if id == multiplayer.get_unique_id():
		_announce(msg)
	else:
		_announce.rpc_id(id, msg)

## 自己的角色：牛仔，或是自己正在操作的尼諾拉
func _me() -> Node:
	var me := players.get_node_or_null(NodePath(str(multiplayer.get_unique_id())))
	if me == null:
		var b := _boss()
		if b and b.pilot != 0 and b.pilot == multiplayer.get_unique_id():
			return b
	return me

## 主機告訴連進來的人這局是什麼時段
@rpc("authority", "call_remote", "reliable")
func _set_period(p: StringName) -> void:
	Period.apply(self, p)

## 主機告訴連進來的人這局是什麼模式
@rpc("authority", "call_remote", "reliable")
func _set_rules(r: StringName) -> void:
	if RULES.has(r):
		rules = r
		_apply_rules()

## 照模式藏起用不到的東西（每台都跑）
func _apply_rules() -> void:
	var has_egg: bool = RULES[rules].egg
	egg.visible = has_egg
	for pad in _exit_pads:
		pad.visible = has_egg
	if party:   # 換模式、回大廳都重來一份
		party.free()
		party = null
	if RULES[rules].party:
		party = Party.new()
		party.name = &"Party"
		add_child(party)

## 派對模式的準備、結算階段：牛仔不能動、不能開槍，誰都不扣血（cowboy.gd、viewmodel.gd、fighter.gd 問這個）
func party_frozen() -> bool:
	return party != null and party.phase in [&"prep", &"result", &"final"]

## 練習場（沙盒、靶場）：沒有蛋、沒有計時、不算勝負，大廳選的模式也不作數
func _practice() -> bool:
	return _sandbox or mode == &"range"

## 這局有沒有重生次數（沙盒、靶場不算）
func _uses_lives() -> bool:
	return not _practice() and int(RULES[rules].lives) >= 0

@rpc("authority", "call_local", "reliable")
func _sync_lives(lives: Dictionary, out: Array) -> void:
	_lives = lives
	_out.clear()
	for id in out:
		_out[id] = true

func _broadcast_lives() -> void:
	if multiplayer.is_server() and _uses_lives():
		_sync_lives.rpc(_lives, _out.keys())

## 還在場上（活著或等重生）的參賽者
func _remaining() -> Array:
	return _lives.keys().filter(func(id: int) -> bool: return not _out.has(id))

## 死鬥：剩一個人就贏；恐龍決鬥：全部出局就恐龍贏。至少要有兩個參賽者才判（一個人開房等人時不會直接贏）
func _check_lives_end() -> void:
	if _over or not _uses_lives():
		return
	var left := _remaining()
	if RULES[rules].end == &"last_standing" and _lives.size() >= 2 and left.size() <= 1:
		_end_round()
		if left.is_empty():
			_finish.rpc("最後兩個人同歸於盡，沒有贏家")
		else:
			_finish_winner.rpc(left[0])
	elif RULES[rules].end == &"all_out_dino_wins" and not _lives.is_empty() and left.is_empty():
		_end_round()
		_finish.rpc("牛仔全部出局，恐龍獲勝")

func _end_round() -> void:
	_over = true
	_next_round = NEXT_ROUND_DELAY

## 死鬥的贏家：每台顯示的字不一樣
@rpc("authority", "call_local", "reliable")
func _finish_winner(winner: int) -> void:
	_finish("你是最後的倖存者，獲勝！" if winner == multiplayer.get_unique_id()
		else "牛仔 %d 是最後的倖存者，你輸了" % winner)

func _on_test_server_pressed() -> void:
	ip_edit.text = TEST_SERVER
	_on_join_pressed()

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip_edit.text, PORT) != OK:
		status.text = "連線失敗，IP 格式不對？"
		return
	multiplayer.multiplayer_peer = peer
	_enter_game("連線中…")

## 沙盒：一個人在牧場的靶道練槍。前方 10／25／50／100 公尺各站一個牛仔靶，
## 旁邊一隻不會動的恐龍。靶不是 bot、也不是本機操控，所以站著不動、不會還擊。
func _on_sandbox_pressed() -> void:
	var xs := SANDBOX_TARGETS.map(func(d: int) -> float: return -4.0 if SANDBOX_TARGETS.find(d) % 2 == 0 else 4.0)
	_start_practice(SANDBOX_START, SANDBOX_TARGETS, xs, Vector3(12, 4.0, -45),
		"沙盒模式：沒有時間限制、子彈無限。靶打死會在原地重生。Esc 回大廳")
	# 翻越練習：一段柵欄、兩個乾草捲，就在出生點旁邊
	for prop in [map._fence(SANDBOX_START + Vector3(-10, -0.1, -4), 6.0, -PI * 0.5),
			map._hay_bale(SANDBOX_START + Vector3(9, -0.1, -6), 0.0),
			map._hay_bale(SANDBOX_START + Vector3(9, -0.1, -9), 0.0)]:
		prop.add_to_group(&"sandbox_prop")
	# 油燈練習：乾草捲旁邊地上兩盞、柵欄邊一盞，射它會潑油燒起來（燒到旁邊的燈會連鎖）
	for off: Vector3 in [Vector3(7, 0, -7.5), Vector3(7.4, 0, -8.2), Vector3(-9, 0, -2.5)]:
		OilLantern.place($Arena, _props.get(&"Lantern"), _on_ground(SANDBOX_START + off), false).add_to_group(&"sandbox_prop")

## 單人打恐龍：測恐龍行為用。場地跟沙盒一樣，只有自己和一隻恐龍 boss（導演、三招、找路都照連線模式），
## 子彈無限、接關無限：死了五秒後在地圖上隨機一個地方回來。恐龍生在離你最遠的地方，要靠導演給的方向找過來。
## 畫面上方顯示恐龍的導演階段、威脅值、正在出的招
func _on_solo_dino_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_sandbox = true
	_solo_dino = true
	_continues = 0
	egg.visible = false
	_enter_game("單人打恐龍：接關無限、子彈無限，測恐龍行為用。Esc 回大廳")
	var me := _add_player(COWBOY, 1)
	me.global_position = _on_ground(SANDBOX_START)
	me.viewmodel.set_infinite()
	spawn_boss()

## 單人派對：不開房（離線），派對模式自己會用電腦補到 4 人，一個人就能測完整四回合
func _on_solo_party_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_on_mode_picked(RULES.keys().find(&"party"))
	_enter_game("單人派對：你和 3 個電腦輪流當恐龍。Esc 回大廳")
	_apply_rules()
	_spawn(1)
	spawn_boss()

## 靶場：另一張平地地圖（levels/range.tscn），專門測手感。打中跳傷害數字，畫面上有準星距離。
## 大廳按鈕只是切地圖、重載場景，重載完 _autostart 看到 mode 就會進來這裡
func _on_range_pressed() -> void:
	mode = &"range"
	get_tree().reload_current_scene.call_deferred()

const RANGE_START := Vector3(0, 0.1, 75)   # 射擊線。往 -Z 打，75 公尺剛好是橫的那條土路
const RANGE_TARGETS := [10, 25, 50, 75, 100, 150]
const RANGE_X := [-12.0, -7.5, -2.5, 2.5, 7.5, 12.0]   # 近的靶放外側，才不會擋到遠的

func _start_range() -> void:
	_start_practice(RANGE_START, RANGE_TARGETS, RANGE_X, Vector3(16, 4.0, -40),
		"靶場：打中會跳傷害和距離，準星下面是準星指到的距離。Esc 回大廳")
	for d in range(10, 160, 10):   # 左邊每 10 公尺一塊距離牌，跟地上的土線對齊
		_sign(_on_ground(RANGE_START + Vector3(-18, 1.2, -d)), "%d m" % d)
	_pierce_walls()

## 穿牆測試：跑道右邊三個牛仔靶，每個前面 3 公尺一面牆（單層木板、雙層木板、金屬板），站在射擊線上牆剛好擋在靶前面。B 換子彈試穿不穿得過
const PIERCE_WALLS := [["單層木板", &"plank", 0.05, Color(0.66, 0.5, 0.32)],
	["雙層木板", &"double_plank", 0.12, Color(0.45, 0.32, 0.2)], ["金屬板", &"metal", 0.03, Color(0.55, 0.57, 0.6)]]

func _pierce_walls() -> void:
	for i in PIERCE_WALLS.size():
		var w: Array = PIERCE_WALLS[i]
		var off := Vector3(12 + i * 3, 0, -20)   # 靶的位置（相對射擊線）。右邊柵欄在 x 20，恐龍靶在 40 公尺外
		var t := _add_player(COWBOY, 9 + i)
		t.global_position = _on_ground(RANGE_START + off)
		t.rotation.y = PI
		var at := _on_ground(RANGE_START + off * (1.0 - 3.0 / off.length()))   # 射擊線往靶看，靶前 3 公尺
		var body := StaticBody3D.new()
		body.add_to_group(w[1])
		body.add_to_group(&"sandbox_prop")
		var size := Vector3(2.0, 2.4, w[2])
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = size
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		(mi.mesh as BoxMesh).size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = w[3]
		mi.material_override = mat
		body.add_child(mi)
		$Arena.add_child(body)
		body.global_position = at + Vector3(0, size.y / 2, 0)
		body.look_at(Vector3(RANGE_START.x, body.global_position.y, RANGE_START.z))   # 牆面朝射擊線
		_sign(at + Vector3(0, 3.0, 0), w[0])

## 練槍的共用部分：自己（編號 1，子彈無限）、每個距離一個牛仔靶、一隻恐龍靶
func _start_practice(start: Vector3, dists: Array, xs: Array, dino_at: Vector3, msg: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_sandbox = true
	egg.visible = false
	_enter_game(msg)
	var me := _add_player(COWBOY, 1)   # 編號 1 才操控得動
	me.global_position = _on_ground(start)
	me.viewmodel.set_infinite()
	for i in dists.size():
		var t := _add_player(COWBOY, 3 + i)
		t.global_position = _on_ground(start + Vector3(xs[i], 0, -dists[i]))
		t.rotation.y = PI   # 面對玩家，打頭才對得到臉
		_sign(t.global_position + Vector3(0, 2.6, 0), "%d m" % dists[i])
	var dino := _add_player(DINO, 2)
	dino.global_position = _on_ground(start + dino_at)
	dino.rotation.y = 0.4
	_sign(dino.global_position + Vector3(0, 6.5, 0), "恐龍 %d m" % roundi(-dino_at.z))

## 靶場：打中的地方跳出傷害（爆頭紅字）和這發飛了幾公尺，往上飄、一秒多淡掉。Bullet 打中人時叫
func hit_popup(pos: Vector3, dmg: int, dist: float, head: bool) -> void:
	if mode != &"range":
		return
	_last_hit = "%s%d（%.1f m）" % ["爆頭 " if head else "", dmg, dist]
	var l := Label3D.new()
	l.text = "%s%d\n%.1f m" % ["爆頭 " if head else "", dmg, dist]
	l.font = $UI/Root.theme.default_font
	l.font_size = 48
	l.outline_size = 12
	l.fixed_size = true   # 在螢幕上一樣大：150 公尺外也看得清楚
	l.pixel_size = 0.0009
	l.modulate = Color(1, 0.25, 0.2) if head else Color(1, 0.95, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	$Arena.add_child(l)
	l.global_position = pos + Vector3(0, 0.3, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, ^"global_position:y", l.global_position.y + 0.8 + dist * 0.012, 1.4)   # 遠的飄高一點，看起來一樣快
	tw.tween_property(l, ^"modulate:a", 0.0, 1.4).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

var _last_hit := "—"

# --- 遊戲局控制（Esc 選單，只有主機） ---

func _on_add_walker_pressed() -> void:
	add_walker()

func _on_add_bot_pressed() -> void:
	add_bot()

func _on_clear_bots_pressed() -> void:
	clear_bots()

## 選單的「恐龍攻擊」開關：關掉時恐龍咬、踩、火球都打不痛（fighter.take_damage 擋），測恐龍行為用
var dino_attacks := true
var _ips := ""          # 本機 IP，開遊戲時查一次就好
var saved_ips_path := "user://saved_ips.cfg"   # 測試會換成別的檔，不動到真的清單

var settings_path := "user://settings.cfg"      # 玩家自己的設定（settings.gd 的設定視窗）

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)   # 第一次開沒有檔案，用預設值
	Viewmodel.aim_toggle = cfg.get_value("controls", "aim_toggle", false)
	settings.vsync = cfg.get_value("display", "vsync", true)
	settings.fps_cap = cfg.get_value("display", "fps_cap", 0)
	settings._apply_display()
	Settings.load_from(cfg)

func _save_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(section, key, value)
	cfg.save(settings_path)

func _on_dino_attack_toggled(on: bool) -> void:
	dino_attacks = on

func _on_add_boss_pressed() -> void:
	spawn_boss()

## 恐龍 boss（boss.gd）：跟蛋無關，生在離所有牛仔最遠的地方，自己在地圖上找人。場上已經有就不再生。
## 沙盒改生在玩家前方 40 公尺，方便測試。生的時候順便在主機上烘導航網格（bake_nav），boss 照路徑繞過建築
func spawn_boss() -> Node3D:
	if not multiplayer.is_server() or players.has_node(NodePath(str(BOSS_ID))):
		return null
	var at := _far_from_cowboys()
	var b := _add_player(BOSS, BOSS_ID)
	var me := players.get_node_or_null(^"1") as Node3D
	if _sandbox and me and not _solo_dino:   # 沙盒：生在前方 40 公尺方便看；單人打恐龍：離你最遠，要自己找過來
		at = me.global_position - me.global_basis.z * 40.0
	b.global_position = _on_ground(Vector3(at.x, 4.2, at.z))
	var boss_hp: int = RULES[rules].boss_hp
	if boss_hp > 0 and not _sandbox:
		b.max_hp = boss_hp   # 決鬥要打得死，血多一點（大家一起打）
		b.hp = boss_hp
	bake_nav()
	return b

## 場內一圈候選點裡，離最近的牛仔最遠的那個
func _far_from_cowboys() -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var p := Vector3(cos(a), 0, sin(a)) * ARENA * 0.35
		var d := INF
		for c in players.get_children():
			if not c.is_in_group(&"dino"):
				d = minf(d, Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length())
		if d > best_d and _is_clear(Vector2(p.x, p.z), 3.0):
			best = p
			best_d = d
	return best

## 恐龍的導航網格：從場地上所有靜態碰撞（地形、房子、柵欄、樹幹、石頭）烘出來，只在主機上需要。
## 讀場景要在主執行緒，烘本身丟背景（幾百毫秒），烘好之前 boss 退回直線追。一個場地只烘一次。
## 恐龍很大（半徑 2.4），進不了房子、擠不過柵欄的缺口——網格自己就會繞開這些地方
var _nav_region: NavigationRegion3D
## rebake：地形被甩尾拆掉（destructible.gd）時重烘，烘好之前照舊的網格走。
## ponytail: 整張圖重烘（背景幾百毫秒，甩尾冷卻 20 秒才一次）；連續拆好幾樣時，晚開始的烘可能先烘完被舊的蓋掉，真的發生再排隊
func bake_nav(rebake := false) -> void:
	if not multiplayer.is_server() or is_instance_valid(_nav_region) != rebake:
		return
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 2.4
	nm.agent_height = 8.0
	nm.agent_max_climb = 0.9
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, $Arena)
	if not rebake:
		_nav_region = NavigationRegion3D.new()
		_nav_region.name = "DinoNav"
		$Arena.add_child(_nav_region)
	var region: WeakRef = weakref(_nav_region)   # 烘完之前回大廳、場地被刪掉的話，不要抓著已經不在的節點
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func() -> void:
		var r: Object = region.get_ref()
		if r:
			r.set_deferred(&"navigation_mesh", nm))   # 烘完的通知可能不在主執行緒

## 移動標靶：在主機玩家前方 25 公尺，左右各 6 公尺來回走，不開槍
func add_walker() -> Node3D:
	if not multiplayer.is_server():
		return null
	var fwd := Vector3.FORWARD
	var at := _spawn_point()
	var me := players.get_node_or_null(^"1") as Node3D
	if me:
		fwd = -me.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		at = me.global_position
	# 只取水平位置：_on_ground 的 y 是「離地高度」，把已經貼地的高度帶進去會算兩次
	var center := (at + fwd * 25.0) * Vector3(1, 0, 1)
	var side := fwd.cross(Vector3.UP) * Vector3(1, 0, 1)
	var w := _add_player(COWBOY, _next_bot_id())
	_make_walker(w, _on_ground(center - side * 6.0), _on_ground(center + side * 6.0))
	w.global_position = _on_ground(center)
	return w

func _make_walker(w: Node3D, a: Vector3, b: Vector3) -> void:
	_lives.erase(w.name.to_int())   # 移動標靶是練習用的，不算參賽者
	w.set(&"bot", true)
	w.set(&"walker", true)
	w.set(&"patrol_a", a)
	w.set(&"patrol_b", b)

## 牛仔 bot：會搶蛋、會開槍。沙盒裡直接來找你打（出現在前方 40 公尺）
func add_bot() -> Node3D:
	if not multiplayer.is_server():
		return null
	var b := _add_player(COWBOY, _next_bot_id())
	b.set(&"bot", true)
	var me := players.get_node_or_null(^"1") as Node3D
	if _sandbox and me:
		var fwd := -me.global_basis.z
		b.global_position = _on_ground(Vector3(me.global_position.x + fwd.x * 40.0, 0.5, me.global_position.z + fwd.z * 40.0))
	return b

## 清掉所有電腦（移動標靶和 bot），排隊等重生的也一起取消
func clear_bots() -> void:
	if not multiplayer.is_server():
		return
	for p in players.get_children():
		if Fighter.is_bot_id(p.name.to_int()) and not p.is_in_group(&"boss"):   # boss 不算 bot，清不掉
			if not p.is_in_group(&"dino"):
				_cowboys -= 1
			p.free()
	_respawn_queue = _respawn_queue.filter(func(r: Dictionary) -> bool: return not Fighter.is_bot_id(int(r["id"])))

## 電腦的編號：從 -1 往下找一個沒人用的（負數，見 Fighter.is_bot_id）
func _next_bot_id() -> int:
	var id := -1
	while players.has_node(NodePath(str(id))) or _respawn_queue.any(func(r: Dictionary) -> bool: return int(r["id"]) == id):
		id -= 1
	return id

## 靶上的距離牌。只在沙盒用，跟著場地一起清。
func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = $UI/Root.theme.default_font   # 預設字型沒有中文
	l.add_to_group(&"sandbox_prop")
	$Arena.add_child(l)
	l.global_position = pos

## 模型檢視：把整個遊戲畫面收起來，換成一個只有模型的場景。
## 不清多人連線狀態，因為根本沒建立。
func _on_viewer_pressed() -> void:
	var v := ModelViewer.new()
	v.use_theme($UI/Root.theme)
	# 自己一個 3D 世界：遊戲場景只是藏起來，地形、建築的碰撞還在同一個世界裡，
	# 恐龍的腳往下找地面會踩到看不見的地形（使用者看到「透明物件，走過去像踩高」）
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.handle_input_locally = true
	box.add_child(sv)
	sv.add_child(v)
	v.closed.connect(func() -> void:
		box.queue_free()
		visible = true
		$UI.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	get_tree().root.add_child(box)
	visible = false
	$UI.visible = false

func _enter_game(msg: String) -> void:
	if multiplayer.is_server():
		_time_left = MATCH_SECONDS
		_clock = int(MATCH_SECONDS)
		_respawn_queue.clear()
		_claimer = 0
		egg.pickup = 0.0
		egg.carrier = 0
		var at := _spawn_point(ARENA * 0.22)  # 放中央附近，不要一開始就在出口旁邊
		egg.global_position = _on_ground(Vector3(at.x, 0.5, at.z))
		egg.reset_physics_interpolation()   # 瞬移：不要從上一局的位置滑過來
	lobby.hide()
	menu.hide()
	status.text = msg
	Fighter.lock_mouse()

# --- 生怪 / 勝負 ---

func _spawn(id: int) -> void:
	if not multiplayer.is_server():
		return  # 只有主機生，MultiplayerSpawner 會同步給大家
	_add_player(COWBOY, id)
	if id != 1:
		_set_rules.rpc_id(id, rules)
		_set_period.rpc_id(id, Period.current)
		_broadcast_lives()
		for d in _doors:   # 門的開關不走同步器，晚來的人要補送一次
			if d.is_open:
				d._set_open.rpc_id(id, true)
		for w in _wrecks:
			if w.hits > 0:
				w._set_hits.rpc_id(id, w.hits, Vector3.ZERO, true)

func _add_player(scene: PackedScene, id: int) -> Node3D:
	var p: Node3D = scene.instantiate()
	p.name = str(id)
	players.add_child(p, true)
	p.global_position = _spawn_point()
	p.died.connect(_on_died.bind(p))
	if not p.is_in_group(&"dino"):
		_cowboys += 1
		if multiplayer.is_server() and _uses_lives() and not _lives.has(id):
			_lives[id] = int(RULES[rules].lives)
			_broadcast_lives.call_deferred()
	return p

func _despawn(id: int) -> void:
	if not multiplayer.is_server():
		return
	_volunteers.erase(id)
	var b := _boss()
	if b and b.pilot == id:   # 操作尼諾拉的人走了：電腦接手
		b.pilot = 0
	var p := players.get_node_or_null(NodePath(str(id)))
	if p:
		p.queue_free()
		if id != 1:
			_cowboys -= 1
	if _lives.has(id):   # 離線的人不算參賽者了：死鬥可能因此剩一個人
		_lives.erase(id)
		_out.erase(id)
		_broadcast_lives()
		_check_lives_end()

## 客戶端打中東西，請主機扣血（Cowboy.deal_damage、摔落的 _hurt_self）。主機檢查合不合理才扣：
## - 只收開槍者本人送的（別人不能假冒）
## - 開槍者還活著，或剛死不到 DEATH_GRACE_MS：兩人同時開槍可以同歸於盡（跟 Hunt 一樣），
##   不會因為誰的封包先到主機就只算一邊
## - 一發的傷害不超過 MAX_HIT（打頭秒殺另外算，傷害剛好等於目標的滿血）；扣自己（摔落）不限
## - 開槍位置離主機看到的開槍者不遠、離目標在射程內
## ponytail: 不重算射線、不限射速。有人真的作弊再加主機重算命中（docs 知識庫「延遲補償」那篇）
const DEATH_GRACE_MS := 300
const MAX_HIT := 60          # 單發最大傷害：步槍 60、重擊槍托 60（cowboy/weapons/*.tscn、viewmodel.gd），改了這裡要跟著改
const MAX_SHOT_RANGE := 270.0   # 步槍射程 250 再加一點
var _died_at := {}            # 牛仔的連線編號 -> [死的時刻（毫秒）, 位置]

@rpc("any_peer", "call_remote", "reliable")
func request_damage(shooter_id: int, target_path: NodePath, amount: int, from: Vector3, head := false) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != shooter_id:
		return
	apply_damage_request(shooter_id, get_node_or_null(target_path), amount, from, head)

## request_damage 檢查完來源之後的部分（測試直接呼叫這個）。扣了回傳 true
func apply_damage_request(shooter_id: int, target: Node, amount: int, from: Vector3, head := false) -> bool:
	if target == null or not target.has_method(&"take_damage"):
		return false
	var shooter := players.get_node_or_null(NodePath(str(shooter_id)))
	var at: Vector3
	if shooter:
		at = shooter.global_position
	elif _died_at.has(shooter_id) and Time.get_ticks_msec() - int(_died_at[shooter_id][0]) <= DEATH_GRACE_MS:
		at = _died_at[shooter_id][1]
	else:
		return false
	var self_hit := target == shooter
	if not self_hit and amount > MAX_HIT and amount != int(target.get(&"max_hp")):
		return false
	if from.distance_to(at) > 5.0 or (not self_hit and from.distance_to((target as Node3D).global_position) > MAX_SHOT_RANGE):
		return false
	if head and target.has_method(&"head_hit"):
		target.head_hit()
	target.take_damage(amount, shooter)
	return true

## 無限重生，不設命數。死亡的代價是節奏——等重生，而且蛋會掉在原地被別人撿走。
## 勝負只有兩種：有人帶蛋撤離（那個人贏），或時間到（恐龍贏）。
## 「打死恐龍」不算贏，不然三個牛仔會理性地先聯手弄死恐龍，跟互相競爭矛盾。
func _on_died(killer: Node, who: Node) -> void:
	var as_dino := who.is_in_group(&"dino")
	if _over:   # 結束畫面時才死：不算勝負、不扣次數，但要排進重生單，下一局才生得回來（不然卡在觀戰）
		_queue_respawn(who, as_dino)
		return
	var id := who.name.to_int()
	_died_at[id] = [Time.get_ticks_msec(), who.global_position]   # 同歸於盡用（request_damage）
	if not as_dino:
		_cowboys -= 1
	if party and not _sandbox:
		party.on_died(killer, who)
		return
	if who.is_in_group(&"boss") and RULES[rules].boss_kill_wins and not _sandbox:
		_end_round()
		_finish.rpc("恐龍倒下了，所有牛仔獲勝！")
		return
	if not as_dino and _uses_lives() and _lives.has(id):
		if int(_lives[id]) <= 0:
			_out[id] = bool(who.get(&"bot"))   # 用完了：出局，不排重生
			_broadcast_lives()
			_announce_out.rpc(id)
			_check_lives_end()
			return
		_lives[id] = int(_lives[id]) - 1
		_broadcast_lives()
	_queue_respawn(who, as_dino)

func _queue_respawn(who: Node, as_dino: bool) -> void:
	_respawn_queue.append({
		"id": who.name.to_int(),
		"dino": as_dino,
		"bot": bool(who.get(&"bot")),
		"walker": who.get(&"walker") == true,   # 恐龍沒有這個屬性，拿到 null
		"patrol": [who.get(&"patrol_a"), who.get(&"patrol_b")],
		# 沙盒的靶要生回原地，不然打死一次靶就散到地圖各處
		"pos": who.global_position if _sandbox else Vector3.INF,
		"yaw": who.rotation.y,
		# 用比賽剩餘秒數計時，不用真實時間：遊戲時間跟真實時間不同步時（加速、卡頓）
		# 重生才不會跟著跑掉
		"at": _time_left - RESPAWN_DELAY,
	})

@rpc("authority", "call_local", "reliable")
func _announce_out(id: int) -> void:
	status.text = "你出局了，觀戰中" if id == multiplayer.get_unique_id() else "牛仔 %d 出局了" % id

## 用佇列不用 await：回大廳時整個 Main 會被 free，await 醒來會踩到已釋放的物件。
func _respawn_step() -> void:
	for i in range(_respawn_queue.size() - 1, -1, -1):
		var r: Dictionary = _respawn_queue[i]
		if _time_left > float(r["at"]):
			continue
		_respawn_queue.remove_at(i)
		var id: int = r["id"]
		if id != 1 and not Fighter.is_bot_id(id) and not _offline and not multiplayer.get_peers().has(id):
			continue  # 人已經離線就別生了（電腦不是連線，不用問）
		var p := _add_player(DINO if r["dino"] else COWBOY, id)
		p.set(&"bot", r["bot"])
		if r["walker"]:
			_make_walker(p, r["patrol"][0], r["patrol"][1])
		if _solo_dino and id == 1:
			_continues += 1
			p.global_position = _spawn_point()   # 接關：地圖上隨機一個地方
		elif r["pos"] != Vector3.INF:
			p.global_position = r["pos"] if id != 1 else _on_ground(SANDBOX_START)
			p.rotation.y = r["yaw"]
		if _sandbox and id == 1:
			p.viewmodel.set_infinite()


## 撤離是個人獲勝，所以每台機器顯示的字不一樣
@rpc("authority", "call_local", "reliable")
func _finish_egg(winner: int) -> void:
	_finish("你帶著蛋撤離，獲勝！" if winner == multiplayer.get_unique_id()
		else "牛仔 %d 帶著蛋撤離，你輸了" % winner)

## 勝負畫面：畫面中間大字＋按鈕。重開一局只有開房的人能按；測試站（專用伺服器）自己會開下一局
@rpc("authority", "call_local", "reliable")
func _finish(msg: String) -> void:
	status.text = msg
	$UI/Root/Result/Box/Text.text = msg
	var host := multiplayer.is_server()
	$UI/Root/Result/Box/RestartBtn.visible = host
	$UI/Root/Result/Box/Sub.text = "" if host else ("%d 秒後自動開下一局" % NEXT_ROUND_DELAY if _joined_dedicated() else "等開房的人重開一局")
	menu.hide()
	result.show()
	_show_cursor()

## 客戶端分不出主機是不是測試站，看連的 IP 是不是測試站的
func _joined_dedicated() -> bool:
	return TEST_SERVER != "" and ip_edit.text == TEST_SERVER

func _on_restart_pressed() -> void:
	if multiplayer.is_server():
		_new_round()

func _physics_process(delta: float) -> void:
	if _over and _dedicated:
		_next_round -= delta
		if _next_round <= 0.0:
			_new_round()
		return
	if lobby.visible or _over or not multiplayer.is_server():
		return
	_respawn_step()
	_pick_pilot()
	if _sandbox:
		# 沒有時間限制，但重生是用剩餘秒數排的，時間還是要走（不會歸零結束）
		_time_left -= delta
		return
	if party:   # 派對模式的計時、蛋、重生、勝負都在 party.gd
		party.step(delta)
		return
	_time_left -= delta   # 沒有時限的模式也要走：重生是用剩餘秒數排的
	if not RULES[rules].timer:
		return
	_egg_step(delta)
	if int(_time_left) != _clock:
		_clock = int(_time_left)
		_set_clock.rpc(_clock)
	if _time_left <= 0.0:
		_over = true
		_next_round = NEXT_ROUND_DELAY
		_finish.rpc(RULES[rules].timeout_msg)

## 開下一局（開房的人按「重開一局」、或專用伺服器自動）：時間和蛋歸位、重生次數補滿，
## 每個牛仔重生（刪掉重生，客戶端的位置才會跟著換），出局的人也回來；boss 回到離大家最遠的地方
func _new_round() -> void:
	_over = false
	var pending := _respawn_queue.duplicate()   # 一局結束時剛死、還在等重生的人（_enter_game 會清掉這張單）
	_enter_game("專用伺服器" if _dedicated else "新的一局")
	egg.extract = 0.0
	_cowboys = 0
	var comeback := _out.duplicate()   # 出局的人：還連著（或是 bot）就生回來
	_lives.clear()
	_out.clear()
	_respawn_queue.clear()
	var boss: Node3D = null
	for p in players.get_children():
		if p.is_in_group(&"boss"):
			boss = p
			continue
		var id := p.name.to_int()
		var scene: PackedScene = DINO if p.is_in_group(&"dino") else COWBOY
		var bot: bool = p.get(&"bot") == true
		var patrol := [p.get(&"patrol_a"), p.get(&"patrol_b")] if p.get(&"walker") == true else []
		players.remove_child(p)
		p.queue_free()
		var q := _add_player(scene, id)
		q.set(&"bot", bot)   # 開房的人按重開一局時場上可能有 bot 和移動標靶，要照原樣生回來
		if patrol:
			_make_walker(q, patrol[0], patrol[1])
	for id: int in comeback:
		if Fighter.is_bot_id(id) or id == 1 and not _dedicated or multiplayer.get_peers().has(id):
			_add_player(COWBOY, id).set(&"bot", comeback[id])
	# 等重生的人（含結束畫面時才死的）也要生回來：以前漏掉，那些人卡在觀戰，要回大廳重進（0.8.10 測試站回報）
	for r: Dictionary in pending:
		var id: int = r["id"]
		if not players.has_node(NodePath(str(id))) and (Fighter.is_bot_id(id) or id == 1 and not _dedicated or multiplayer.get_peers().has(id)):
			var q := _add_player(DINO if r["dino"] else COWBOY, id)
			q.set(&"bot", r["bot"])
			if r["walker"]:
				_make_walker(q, r["patrol"][0], r["patrol"][1])
	# 對抗模式：上一局操作尼諾拉的人變回牛仔，下一幀重抽（_pick_pilot）
	_pilot_picked = false
	if boss and boss.pilot != 0:
		var old: int = boss.pilot
		boss.pilot = 0
		if (old == 1 and not _dedicated) or multiplayer.get_peers().has(old):
			_add_player(COWBOY, old)
	if RULES[rules].dino:
		if boss == null:
			spawn_boss()
		else:
			boss.global_position = _on_ground(_far_from_cowboys() + Vector3(0, 4.2, 0))
			boss.reset_physics_interpolation()
			boss.hp = boss.max_hp
	_broadcast_lives()
	_announce.rpc("新的一局開始！")

@rpc("authority", "call_local", "reliable")
func _announce(msg: String) -> void:
	status.text = msg
	result.hide()
	_match_hud.on_announce()
	if not lobby.visible:
		Fighter.lock_mouse()

@rpc("authority", "call_local", "reliable")
func _set_clock(secs: int) -> void:
	_clock = secs

## 蛋的規則：牛仔靠近就撿走，持有者死掉就留在原地，帶進撤離區就贏。
func _egg_step(delta: float) -> void:
	if egg.carrier == 0:
		egg.extract = 0.0
		_claim_step(delta)
		return

	var holder := players.get_node_or_null(NodePath(str(egg.carrier)))
	if holder == null:
		egg.carrier = 0   # 持有者陣亡，蛋就掉在他最後的位置
		egg.extract = 0.0
		return
	egg.global_position = holder.global_position + Vector3.UP * EGG_HOLD_HEIGHT

	# 要在圈內連續待滿才算數。離開就歸零；敵人站在圈裡不會中斷。
	if _dist_to_exit(egg.global_position) < EXIT_RADIUS:
		egg.extract += delta
		if egg.extract >= EXTRACT_SECONDS:
			if party:   # 派對模式：回合結束、計分，不跳勝負畫面
				party.extracted(egg.carrier)
				return
			_over = true
			_next_round = NEXT_ROUND_DELAY
			_finish_egg.rpc(egg.carrier)
			return
	else:
		egg.extract = 0.0

func _process(delta: float) -> void:
	Fighter._frame_ms = Time.get_ticks_msec()   # 給 Fighter.after_hitch 判斷卡頓
	_match_hud.track_frame_time(delta)
	_diag_print(delta)
	if BugReport.instance.take_new_error():
		status.text = "遊戲記到一個錯誤，按 F8 存成回報檔（會複製到剪貼簿）"
	var cam := get_viewport().get_camera_3d()
	if _drift and cam:
		_drift.global_position = cam.global_position
	_match_hud.update_always()
	# 連線還沒建立好就問 id 會噴錯
	if lobby.visible or multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var me := _me()
	# 保險：遊戲中、沒開選單和勝負畫面，游標卻沒鎖住（系統自己放掉的，0.8.1 回饋「舉槍後跑出游標」），就鎖回去。
	# 視窗沒焦點時鎖不住，等切回來再鎖
	if not menu.visible and not result.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and get_window().has_focus():
		Fighter.lock_mouse()
	_match_hud.update_match(me)
	_match_hud.update_text(me)

## 出局了（只能觀戰）：派對模式看 Party 的命數（每回合補滿），其他模式看 _out
func _is_out(id: int) -> bool:
	return int(party.lives.get(id, 1)) <= 0 if party else _out.has(id)

var debug_hud := false   # F3 開關右上角的開發資訊（match_hud.gd 的 update_always）

## 大廳存過的 IP：「＋」把目前的存起來，「⋯」選一個填回去
func _load_saved_ips() -> void:
	var cfg := ConfigFile.new()
	cfg.load(saved_ips_path)   # 第一次開沒有檔案，當作空的
	var popup := saved_ips.get_popup()
	popup.clear()
	for a: String in cfg.get_value("ips", "list", []):
		popup.add_item(a)
	saved_ips.disabled = popup.item_count == 0

func _on_save_ip_pressed() -> void:
	var a := ip_edit.text.strip_edges()
	var cfg := ConfigFile.new()
	cfg.load(saved_ips_path)
	var list: Array = cfg.get_value("ips", "list", [])
	if a == "" or list.has(a):
		return
	list.append(a)
	cfg.set_value("ips", "list", list)
	cfg.save(saved_ips_path)
	_load_saved_ips()
	status.text = "存好了：" + a

func _dist_to_exit(p: Vector3) -> float:
	var best := 9999.0
	for e: Vector3 in _exits:
		best = minf(best, Vector2(p.x - e.x, p.z - e.z).length())
	return best

# --- 場地 ---


## 撿蛋不是碰到就拿，要在旁邊連續待滿 PICKUP_SECONDS。
## 換人或走開就歸零——跟撤離同一個道理，讓拿蛋變成要承諾的動作。
func _claim_step(delta: float) -> void:
	var near: Node3D = null
	for p in players.get_children():
		if p.is_in_group(&"dino"):
			continue
		var d := egg.global_position.distance_to(p.global_position)
		if d < PICKUP_RANGE and (near == null
				or d < egg.global_position.distance_to(near.global_position)):
			near = p
	if near == null:
		_claimer = 0
		egg.pickup = 0.0
		return
	var id := near.name.to_int()
	if id != _claimer:
		_claimer = id
		egg.pickup = 0.0
	egg.pickup += delta
	if egg.pickup >= PICKUP_SECONDS:
		egg.carrier = id
		egg.pickup = 0.0
		_claimer = 0

# Godot 內建字型沒有中文，用系統字型頂著
func _use_cjk_font() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["PingFang TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Heiti TC", "Sans-Serif"])
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 18
	$UI/Root.theme = th

func _local_ips() -> String:
	var out: Array[String] = []
	for a: String in IP.get_local_addresses():
		# 結尾 .0 是網段不是能連的位址（虛擬網卡常有），列出來只會讓人填錯
		if (a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172.")) and not a.ends_with(".0"):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "自己查 ifconfig"
