extends Node3D
## Outlaws vs Dinosaurs 法外狂徒大戰恐龍（簡稱 OvD）— 區網原型。兩個模式：連線模式（大家都是牛仔，第一人稱）和沙盒模式。
## Esc 選單裡的「遊戲局控制」讓主機加移動標靶、牛仔 bot。恐龍的程式都還在，玩法定了再接回來。

const PORT := 24680
## 測試站：雲端主機上一直開著的專用伺服器（`-- --server`，見 README 的「測試站」）。
## 還沒架好就空著，大廳的「連到測試站」按鈕會關掉
const TEST_SERVER := ""
const NEXT_ROUND_DELAY := 10.0   # 專用伺服器一局結束後隔幾秒開下一局
const ARENA := 168.0        # 場地邊長（320 → 192 → 168：越縮交火越密集）
const SPAWN_CLEARANCE := 7.0  # 出生點離建築至少這麼遠
const FENCE_H := 1.0          # 柵欄高度，要在牛仔的翻越範圍（0.4~1.5）內
const BUILDING_MAX_H := 22.0  # 最高的東西（筒倉＋圓頂約 20、穀倉屋脊約 16）不能超過這個
# 沙盒的靶場：從 (0, 84) 往 -Z 打到 100 公尺，這一條不蓋東西。撤離區在東西兩端，不會壓到
const SANDBOX_RANGE := Rect2(-20, -30, 40, 112)   # 靶在路兩側 4 公尺、恐龍靶 12 公尺；再窄旁邊的坡會超過 40 度
const SANDBOX_START := Vector3(0, 0.1, 76)   # y 是離地高度，用 _on_ground() 換成實際位置
const SANDBOX_TARGETS := [10, 25, 50, 100]   # 牛仔靶的距離（公尺）：左輪、散彈、步槍各自的有效距離
const GRASS := Color(0.49, 0.34, 0.21)   # 乾草原：黃昏裡偏紅的枯黃
const DIRT := Color(0.52, 0.39, 0.27)    # 沙土路，比草地亮
const PATH := Color(0.74, 0.6, 0.45)     # 荒地小路（Trails）：踩實的乾土，比草地亮一截（夕陽下要一眼看出路線）
const WHEAT := Color(0.45, 0.33, 0.18)
# 場景物件的模型（blender/props.py）。這幾個基準尺寸跟那邊共用，改一邊要改另一邊
const PROPS := preload("res://models/props.glb")
const BARN_BASE := Vector3(14, 8, 20)   # 穀倉模型的寬、牆高、長
const BARN_PITCH := 0.55
const SILO_BASE_H := 15.0
const FENCE_SEG := 2.5
const TREE_BASE_TRUNK := 5.0   # 松樹的基準樹幹高
# 闊葉樹（blender/tree.py → trees.glb）：三種大小各自建模，尺寸就是實際公尺。
# 每種 [樹幹胸口半徑, 碰撞圓柱高（到分叉點再往上一點）]，改了 tree.py 的樹幹這裡要跟著改
const TREES := preload("res://models/trees.glb")
const TREE_KINDS := {&"TreeOakS": [0.17, 1.4], &"TreeOakM": [0.41, 1.8], &"TreeOak": [0.55, 2.4],
	# 五種新樹（blender/grove.py → groves.glb）和柱狀仙人掌（blender/flora.py → floras.glb），一樣是實際公尺
	&"TreeMaple": [0.41, 3.4], &"TreePine2": [0.45, 6.0], &"TreeJoshua": [0.4, 1.9], &"TreeDead": [0.62, 3.4],
	&"TreeWillow": [0.42, 3.0], &"Saguaro": [0.46, 5.0], &"SaguaroS": [0.28, 2.6]}
const GROVES := preload("res://models/groves.glb")
const FLORAS := preload("res://models/floras.glb")
# 石頭（blender/rock.py → rocks.glb）：Rock01..16，尺寸是實際公尺、原點在底部中央。
# 01~04 大石（最大那顆 6 公尺寬，縮小一點當掩體）、05~11 單顆、12~16 石頭堆
const ROCKS := preload("res://models/rocks.glb")
const ROCK_COVER := [&"Rock01", &"Rock02", &"Rock03", &"Rock04", &"Rock05", &"Rock07", &"Rock12", &"Rock16"]
const ROCK_SCATTER := [&"Rock06", &"Rock08", &"Rock09", &"Rock10", &"Rock11", &"Rock13", &"Rock14", &"Rock15"]
# 門和梯子的位置（blender/props.py 的同名常數，改一邊要改另一邊）
const BARN_T := 0.25
const BARN_DOOR_W := 5.0
const BARN_DOOR_H := 4.8
const BARN_BACK_X := 4.0
const BARN_BACK_W := 1.6   # 後門開口，跟 blender/props.py 一樣
const BARN_BACK_H := 2.8
const BARN_LOFT := 4.0
const BARN_LADDER_X := -2.5
const HOUSE_T := 0.2
# 農舍三種（blender/house.py → houses.glb）：主屋牆都是 10 × 8，門在正面中央，整棟架高 HOUSE_FLOOR。
# 牆、屋頂、煙囪、前廊、台階斜坡的碰撞都在 House<N>Col 裡。每種 [煙囪頂（冒煙的地方）]，跟 house.py 的 CHIMNEY 一樣
const HOUSES := preload("res://models/houses.glb")
# 場景小物件（blender/kit.py → kits.glb）：木桶、木箱、方草捆、車輪、柵欄、圍欄門、繫柱架、風車、倉庫、吊燈
const KIT := preload("res://models/kits.glb")
# 城鎮店面（blender/town.py → towns.glb）：酒館、雜貨店、警長辦公室、水塔，各帶碰撞 <名字>Col。正面朝 +Z
const TOWNS := preload("res://models/towns.glb")
const WINDMILL_HUB := Vector3(0.0, 8.9, 0.9)   # 風車葉輪掛在哪（kit.py 的 WINDMILL_HUB 換成 Godot 座標）
const HAY_BLOCK := Vector3(1.1, 0.48, 0.55)    # 方草捆大小（kit.py 的 HAY_SIZE）
const HOUSE_FLOOR := 0.45
const HOUSE_KINDS := {&"House1": Vector3(5.6, 10.11, -2.0), &"House2": Vector3(-5.6, 7.09, -1.8),
	&"House3": Vector3(3.4, 10.66, -1.6)}
# 圍牆不給爬（見 dino.gd 的 _on_climbable_wall），所以恐龍能到的最高點就是
# 「站上最高的屋頂再跳一下」。圍牆要比那個高，才翻不出去。
const WALL_H := 40.0
const WALL_T := 4.0
const EXIT_RADIUS := 14.0     # 撤離區半徑
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
## lives：每個牛仔能重生幾次（-1 不限）；用完就出局、不再回場。dino：有沒有恐龍 boss。
## egg：有沒有蛋和撤離。timer：有沒有四分鐘時限。
## 牛仔之間本來就打得到（PvP），恐龍決鬥的「隊友火力」不用另外開
const RULES := {
	&"egg": {name = "搶蛋", lives = -1, dino = true, egg = true, timer = true,
		desc = "先把蛋帶進撤離區的人贏，一局四分鐘。場上有一隻恐龍，死了五秒後重生（不限次數）。"},
	&"deathmatch": {name = "死鬥", lives = 3, dino = false, egg = false, timer = false,
		desc = "沒有恐龍、沒有蛋。每個人可以重生 3 次，用完就出局，最後剩下的一個人獲勝。"},
	&"dino_duel": {name = "恐龍決鬥", lives = 5, dino = true, egg = false, timer = false,
		desc = "所有牛仔合力打一隻恐龍，打死牠大家一起贏。每人可以重生 5 次，全部出局就是恐龍贏。小心，打到隊友一樣會扣血。"},
}
const DUEL_BOSS_HP := 3000   # 恐龍決鬥的恐龍血量（搶蛋模式打不死、900 血會倒地）
var rules := &"egg"
var _lives := {}   # 牛仔的連線編號 -> 還能重生幾次。只有用得到次數的模式有；主機算，廣播給大家（_sync_lives）
var _out := {}     # 出局的牛仔：連線編號 -> 是不是 bot（新的一局要生回來）
var _exit_pads: Array[Node3D] = []   # 撤離區的地面標示：沒有蛋的模式藏起來

var _props := {}   # 物件名 -> Mesh，從 props.glb 拿出來共用
var _terrain: Terrain
var _level: Array[Dictionary] = []   # 擺設清單：場地上每樣東西一筆（見 _build_level）
## 手調過的場景檔（在 Godot 編輯器裡改，見 docs/場景編輯.md）。烘焙工具設成空的：不讀場景檔，自動擺一份初稿
## 目前的地圖：&"" 是牧場（連線、沙盒），&"range" 是靶場。靜態的：換地圖要重載整個場景，重載後還記得
static var mode := &""
const RANGE_LEVEL := "res://levels/range.tscn"
var level_path := RANGE_LEVEL if mode == &"range" else "res://levels/ranch.tscn"
var _houses_built := 0   # 第幾棟農舍：三種輪流蓋（不用亂數，後面擺的東西位置才不會跟著變）
var _doors: Array[Door] = []   # 晚加入的人連進來時，把開著的門補送給他
var _wheat_fields: Array[Rect2] = []   # 地形上色要知道哪裡是麥田
var _roads: Array[Rect2] = []          # 城鎮主街這類另外鋪的土路（地形上色）；彎彎曲曲的荒地小路在 Trails（trails.gd）
var _blocked: Array[Rect2] = []  # 建築物在 XZ 平面佔的範圍
var _drift: Node3D   # 落葉飛蟲，跟著鏡頭走（Fx.drift）
var _bushes: Array[Vector3] = []  # 灌木叢的根部位置（bot 判斷人是不是躲在裡面）
var _exits: Array[Vector3] = []  # 四個撤離區的中心
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
	_add_report_button()
	_flatten_models()
	_use_cjk_font()
	_ips = _local_ips()
	_load_saved_ips()
	_load_settings()
	saved_ips.get_popup().index_pressed.connect(func(i: int) -> void:
		ip_edit.text = saved_ips.get_popup().get_item_text(i))
	for k: StringName in RULES:
		mode_pick.add_item(RULES[k].name)
	_on_mode_picked(0)
	_use_sky()
	_use_outline()
	_load_props()
	_skin_egg()
	_load_level()
	_build_arena()
	if mode != &"range":
		_build_exits()
	multiplayer.peer_connected.connect(_spawn)
	multiplayer.peer_disconnected.connect(_despawn)
	multiplayer.connected_to_server.connect(func() -> void: status.text = "已連線。WASD 移動，滑鼠瞄準，左鍵開槍，右鍵舉槍")
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
	print("[滑鼠診斷] %s　鎖定=%s　視窗焦點=%s　選單=%s　還要等=%dms　滑鼠下的介面=%s" % [
		Fighter.diag, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, get_window().has_focus(), menu.visible,
		maxi(Fighter._look_from - Time.get_ticks_msec(), 0), hov.get_path() if hov else "無"])
	Fighter.diag.clear()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F8:
		report_bug()   # 大廳、遊戲中都能按
		return
	if lobby.visible:
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
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
	var me := players.get_node_or_null(NodePath(str(multiplayer.get_unique_id())))
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
	_over = false
	_offline = false
	_sandbox = false
	_solo_dino = false
	_lives.clear()
	_out.clear()
	rules = RULES.keys()[mode_pick.selected]   # 加入別人的房間時被主機改過，回大廳換回自己選的
	_apply_rules()
	egg.visible = true
	for n in get_tree().get_nodes_in_group(&"sandbox_prop"):
		n.free()
	_time_left = 0.0
	_respawn_queue.clear()
	egg.carrier = 0
	menu.hide()
	result.hide()
	center_info.text = ""
	if _boss_bar:
		_boss_bar.hide()
		_boss_label.hide()
	_had_me = false
	crosshair.hide()
	stamina_bar.hide()
	lobby.show()
	hud.text = ""
	status.text = msg
	_show_cursor()
	# 靶場是另一張地圖：回大廳就重載回牧場（測試自己組的場景不是 current_scene，不重載）
	if mode == &"range":
		mode = &""
		if get_tree().current_scene == self:
			get_tree().reload_current_scene.call_deferred()

# --- 連線 ---

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
	Engine.max_fps = 120   # 沒畫面也會一直空轉：不鎖的話吃滿一顆處理器，跟物理一樣每秒 120 次就夠
	_enter_game("專用伺服器")
	_apply_rules()
	if RULES[rules].dino:
		spawn_boss()
	print("測試站開好了，連接埠 %d（UDP）" % PORT)

## 大廳選模式：記下來、說明換成那個模式的
func _on_mode_picked(i: int) -> void:
	rules = RULES.keys()[i]
	mode_pick.select(i)
	$UI/Root/Lobby/ModeDesc.text = RULES[rules].desc

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

## 這局有沒有重生次數（沙盒、靶場不算）
func _uses_lives() -> bool:
	return not _sandbox and mode != &"range" and int(RULES[rules].lives) >= 0

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
	if rules == &"deathmatch" and _lives.size() >= 2 and left.size() <= 1:
		_end_round()
		if left.is_empty():
			_finish.rpc("最後兩個人同歸於盡，沒有贏家")
		else:
			_finish_winner.rpc(left[0])
	elif rules == &"dino_duel" and not _lives.is_empty() and left.is_empty():
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
	for prop in [_fence(SANDBOX_START + Vector3(-10, -0.1, -4), 6.0, -PI * 0.5),
			_hay_bale(SANDBOX_START + Vector3(9, -0.1, -6), 0.0),
			_hay_bale(SANDBOX_START + Vector3(9, -0.1, -9), 0.0)]:
		prop.add_to_group(&"sandbox_prop")

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
	for w in me.viewmodel._weapons:
		w.reserve = -1
	me.viewmodel._refresh_ammo()
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

## 練槍的共用部分：自己（編號 1，子彈無限）、每個距離一個牛仔靶、一隻恐龍靶
func _start_practice(start: Vector3, dists: Array, xs: Array, dino_at: Vector3, msg: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_sandbox = true
	egg.visible = false
	_enter_game(msg)
	var me := _add_player(COWBOY, 1)   # 編號 1 才操控得動
	me.global_position = _on_ground(start)
	for w in me.viewmodel._weapons:
		w.reserve = -1
	me.viewmodel._refresh_ammo()
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

## 準星指到多遠：從鏡頭中心往前掃 400 公尺，撞到什麼就量到那裡
func _aim_distance(me: Node3D) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null or me == null:
		return "—"
	var from := cam.global_position
	var mine: Array[RID] = [me.get_rid()]   # 自己身上的碰撞（頭、身體的判定區）和看不見的圍牆都不算
	for n in me.find_children("*", "CollisionObject3D", true, false) + get_tree().get_nodes_in_group(&"arena_wall"):
		mine.append(n.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 400.0, 1, mine)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return "—" if hit.is_empty() else "%.1f m" % from.distance_to(hit["position"])

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
var _had_me := false    # 這局我已經生出來過；之後角色不見了就是死了，開始重生倒數
var _dead_ms := -1
var saved_ips_path := "user://saved_ips.cfg"   # 測試會換成別的檔，不動到真的清單

var settings_path := "user://settings.cfg"      # 玩家自己的設定（瞄準按住／切換）

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)   # 第一次開沒有檔案，用預設值
	Viewmodel.aim_toggle = cfg.get_value("controls", "aim_toggle", false)
	$UI/Root/Menu/Box/AimToggleBtn.set_pressed_no_signal(Viewmodel.aim_toggle)
	var caps: OptionButton = $UI/Root/Menu/Box/FpsCapBtn
	caps.clear()
	var hz := _refresh_hz()
	for label: String in [FPS_CAPS[0], FPS_CAPS[1] % hz, FPS_CAPS[2] % (hz / 2)]:
		caps.add_item(label)
	vsync = cfg.get_value("display", "vsync", true)
	fps_cap = cfg.get_value("display", "fps_cap", 0)
	$UI/Root/Menu/Box/VsyncBtn.set_pressed_no_signal(vsync)
	caps.select(fps_cap)
	_apply_display()

func _save_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(section, key, value)
	cfg.save(settings_path)

## 選單的「瞄準：按一下切換」：關掉是按住右鍵才舉槍
func _on_aim_toggle_toggled(on: bool) -> void:
	Viewmodel.aim_toggle = on
	_save_setting("controls", "aim_toggle", on)

## 畫面設定：垂直同步、幀率上限。上限只給跟螢幕刷新率對得上的數字（刷新率、一半）：
## 隨便填一個（例如 60Hz 螢幕鎖 50）每幀間隔會長短不一，平均幀數對了看起來還是卡
const FPS_CAPS := ["幀率上限：不限", "幀率上限：跟螢幕一樣（%d）", "幀率上限：螢幕的一半（%d）"]
var vsync := true
var fps_cap := 0

func _refresh_hz() -> int:
	var hz := roundi(DisplayServer.screen_get_refresh_rate())
	return hz if hz > 0 else 60   # 查不到（無頭模式、某些系統）當 60

func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var hz := _refresh_hz()
	Engine.max_fps = [0, hz, hz / 2][fps_cap]

func _on_vsync_toggled(on: bool) -> void:
	vsync = on
	_apply_display()
	_save_setting("display", "vsync", on)

func _on_fps_cap_selected(i: int) -> void:
	fps_cap = i
	_apply_display()
	_save_setting("display", "fps_cap", i)

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
	if rules == &"dino_duel" and not _sandbox:
		b.max_hp = DUEL_BOSS_HP   # 決鬥要打得死，血多一點（大家一起打）
		b.hp = DUEL_BOSS_HP
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
func bake_nav() -> void:
	if is_instance_valid(_nav_region) or not multiplayer.is_server():
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
		_broadcast_lives()
		for d in _doors:   # 門的開關不走同步器，晚來的人要補送一次
			if d.is_open:
				d._set_open.rpc_id(id, true)

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
	if _over:
		return
	var as_dino := who.is_in_group(&"dino")
	var id := who.name.to_int()
	_died_at[id] = [Time.get_ticks_msec(), who.global_position]   # 同歸於盡用（request_damage）
	if not as_dino:
		_cowboys -= 1
	if who.is_in_group(&"boss") and rules == &"dino_duel" and not _sandbox:
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
			for w in p.viewmodel._weapons:
				w.reserve = -1


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
	if _sandbox:
		# 沒有時間限制，但重生是用剩餘秒數排的，時間還是要走（不會歸零結束）
		_time_left -= delta
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
		_finish.rpc("時間到，沒有人把蛋帶走")

## 開下一局（開房的人按「重開一局」、或專用伺服器自動）：時間和蛋歸位、重生次數補滿，
## 每個牛仔重生（刪掉重生，客戶端的位置才會跟著換），出局的人也回來；boss 回到離大家最遠的地方
func _new_round() -> void:
	_over = false
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
	_had_me = false
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
			_over = true
			_next_round = NEXT_ROUND_DELAY
			_finish_egg.rpc(egg.carrier)
			return
	else:
		egg.extract = 0.0

func _process(delta: float) -> void:
	_track_frame_time(delta)
	_diag_print(delta)
	if BugReport.instance.take_new_error():
		status.text = "遊戲記到一個錯誤，按 F8 存成回報檔（會複製到剪貼簿）"
	var cam := get_viewport().get_camera_3d()
	if _drift and cam:
		_drift.global_position = cam.global_position
	_update_net_info()
	if _compass:
		_compass.visible = not lobby.visible
	# 連線還沒建立好就問 id 會噴錯
	if lobby.visible or multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var me := players.get_node_or_null(NodePath(str(multiplayer.get_unique_id())))
	var dino := get_tree().get_first_node_in_group(&"dino")
	# 保險：遊戲中、沒開選單和勝負畫面，游標卻沒鎖住（系統自己放掉的，0.8.1 回饋「舉槍後跑出游標」），就鎖回去。
	# 視窗沒焦點時鎖不住，等切回來再鎖
	if not menu.visible and not result.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and get_window().has_focus():
		Fighter.lock_mouse()
	_update_center_info(me)
	_update_spectator(me)
	_update_crosshair(me)
	_update_boss_bar(me)
	_update_compass()
	stamina_bar.visible = me != null and me == dino
	if stamina_bar.visible:
		stamina_bar.value = me.stamina
		stamina_bar.modulate = Color(1, 0.35, 0.3) if me.exhausted else Color.WHITE
	var egg_state := "無人持有"
	if egg.carrier == multiplayer.get_unique_id():
		egg_state = "在你身上！帶去撤離區"
	elif egg.carrier != 0:
		egg_state = "被牛仔 %d 拿走了" % egg.carrier
	var mine := str(me.hp) if me != null else "陣亡"
	if mode == &"range":
		hud.text = "靶場    準星距離：%s    上一發：%s" % [_aim_distance(me), _last_hit]
		return
	if _solo_dino:
		hud.text = "單人打恐龍    我的血量：%s    接關 %d 次\n%s" % [mine, _continues, _boss_debug()]
		return
	if _sandbox:
		hud.text = "沙盒    我的血量：%s    恐龍靶血量：%s" % [mine, dino.hp if dino else "重生中"]
		return
	var my_id := multiplayer.get_unique_id()
	if _uses_lives():
		var left := "出局" if _out.has(my_id) else "剩 %d 次" % int(_lives.get(my_id, 0))
		hud.text = "%s    我的血量：%s    重生：%s    場上還有 %d 名牛仔" % [RULES[rules].name, mine, left, _remaining().size()]
		return
	hud.text = "⏱ %d:%02d    我的血量：%s    %s存活牛仔：%d    蛋：%s" % [
		maxi(_clock, 0) / 60, maxi(_clock, 0) % 60,
		mine,
		("恐龍血量：%d    " % dino.hp) if dino else "",
		players.get_child_count() - (1 if dino else 0),
		egg_state]

## 出局之後觀戰：鏡頭跟在一個還在場上的牛仔後上方（左鍵換人）
var _spectator: Camera3D
var _watch := 0
func _update_spectator(me: Node) -> void:
	var out := me == null and _out.has(multiplayer.get_unique_id())
	if not out:
		if _spectator and _spectator.current:
			_spectator.current = false
		return
	var alive := players.get_children().filter(func(p: Node) -> bool: return not p.is_in_group(&"dino"))
	if alive.is_empty():
		return
	if _spectator == null:
		_spectator = Camera3D.new()
		add_child(_spectator)
	if Input.is_action_just_pressed(&"fire"):
		_watch += 1
	var p: Node3D = alive[_watch % alive.size()]
	var back := p.global_basis.z
	back.y = 0.0
	_spectator.look_at_from_position(p.global_position + back.normalized() * 6.0 + Vector3.UP * 4.0, p.global_position + Vector3.UP * 1.5)
	_spectator.current = true

## 單人打恐龍的除錯資訊：導演在哪個階段、威脅值、恐龍在做什麼
const BOSS_ACTS := ["", "咬（預備）", "咬！", "蓄力甩尾（打頭打斷）", "甩尾！", "撲擊（預備）", "撲擊！", "收招", "被打斷", "發現你了（吼）"]
func _boss_debug() -> String:
	var b := get_tree().get_first_node_in_group(&"boss")
	if b == null:
		return "恐龍：不在場上"
	var d: Director = b.director
	var phase: String = ["醞釀", "退開", "放鬆"][d.phase]
	var doing: String = "倒地" if b.down_left > 0.0 else BOSS_ACTS[b.act]
	if doing == "":
		doing = "追人" if b._sees_now else ("盯著（還不確定）" if b._glimpse else ("找最後看到的地方" if b._seen_left > 0.0 else ("查聲音" if b._noise_left > 0.0
			else ("照導演的方向找" if b._hint != Vector3.INF else "閒逛"))))
	var extra := "　剩 %d 秒" % ceili(d.phase_left) if d.phase != Director.Phase.BUILD else "　威脅 %d / %d" % [roundi(d.menace), roundi(Director.MENACE_MAX)]
	return "恐龍：%s%s　｜　%s　｜　距離 %d m" % [phase, extra, doing, _dist_to_boss(b)]

func _dist_to_boss(b: Node3D) -> int:
	var me := players.get_node_or_null(^"1") as Node3D
	return roundi(me.global_position.distance_to(b.global_position)) if me else -1

## 方位條下面的倒數：重生、撤離、撿蛋。重生倒數用自己這台的時間算（主機的重生佇列客戶端看不到）
func _update_center_info(me: Node) -> void:
	var now := Time.get_ticks_msec()
	if me != null:
		_had_me = true
		_dead_ms = -1
	elif _had_me and _dead_ms < 0:
		_dead_ms = now
	var t := ""
	if result.visible:
		t = ""
	elif me == null and _out.has(multiplayer.get_unique_id()):
		t = "你出局了，觀戰中"
	elif me == null and _dead_ms >= 0:
		t = "%d 秒後重生" % maxi(1, ceili(RESPAWN_DELAY - (now - _dead_ms) / 1000.0))
	elif egg.extract > 0.0:
		var who := "你" if egg.carrier == multiplayer.get_unique_id() else "牛仔 %d" % egg.carrier
		t = "%s撤離中：還剩 %.1f 秒" % [who, maxf(EXTRACT_SECONDS - egg.extract, 0.0)]
	elif egg.pickup > 0.0:
		t = "有人在撿蛋：還剩 %.1f 秒" % maxf(PICKUP_SECONDS - egg.pickup, 0.0)
	center_info.text = t

## 最近一秒最慢的一幀。平均 FPS 看不出卡頓：60 FPS 裡夾幾幀 50 毫秒，數字照樣是 60
var _slow := 0.0
var _slow_shown := 0.0
var _slow_since := 0

func _track_frame_time(delta: float) -> void:
	_slow = maxf(_slow, delta * 1000.0)
	var now := Time.get_ticks_msec()
	if now - _slow_since >= 1000:
		_slow_shown = _slow
		_slow = 0.0
		_slow_since = now

## 右上角：本機 IP（開房的人報給朋友用）、連線延遲、每秒畫面數、最慢一幀
func _update_net_info() -> void:
	var parts: Array[String] = ["本機 IP：" + _ips]
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not lobby.visible and peer and not multiplayer.is_server() \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := peer.get_peer(1)
		if p:
			parts.append("延遲 %d ms" % p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			# 掉包率：ENet 的統計是乘了 PACKET_LOSS_SCALE（65536）的比例
			parts.append("掉包 %.1f%%" % (100.0 * p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / ENetPacketPeer.PACKET_LOSS_SCALE))
	if not lobby.visible:
		parts.append("%d FPS（最慢一幀 %.0f ms）" % [Engine.get_frames_per_second(), _slow_shown])
	net_info.text = "　".join(parts)

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

## 準心畫在「火球會落到哪」，不是螢幕正中央——抬頭時看得出彈道往上跑。
## 牛仔的準心在自己的 HUD 裡（子彈是直線，畫正中央就對），沒有 aim_point，這裡就不顯示。
func _update_crosshair(me: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	if me == null or cam == null or not me.has_method("aim_point"):
		crosshair.hide()
		return
	# 打中人準心閃紅。遠距離看不出血條掉，這是唯一的命中確認
	crosshair.modulate = Color(1, 0.3, 0.25) if me.hit_until > Time.get_ticks_msec() else Color.WHITE
	var p: Vector3 = me.aim_point()
	crosshair.visible = not cam.is_position_behind(p)
	crosshair.position = cam.unproject_position(p) - crosshair.size * 0.5

# --- 場地 ---

func _build_arena() -> void:
	# 擺設清單：有手調過的場景檔就照它，沒有就自動擺一份初稿（見 docs/場景編輯.md）
	Trails.enabled = mode != &"range"   # 自動擺設、地面上色、草都會查小路，最先設
	if _level.is_empty():
		_generate_level()
	# 地形要在擺任何東西之前定案：整平區（農莊、倉庫、牧場的房子……）在清單裡
	_terrain = make_terrain(_level.filter(func(r: Dictionary) -> bool: return r.kind == &"flat") \
		.map(func(r: Dictionary) -> Array: return [Vector2(r.pos.x, r.pos.z), r.r]))
	var ground := _terrain.build(_ground_color)
	ground.add_to_group(&"ground")   # 子彈打到噴土（Bullet.surface_of）
	$Arena.add_child(ground)

	# 四周圍牆，東西才不會掉出場外。內側牆面剛好貼齊地板邊緣，不留縫。
	# 牆看不見：外面是一路延伸到地平線的遠景（far_land.gd），邊上一圈柵欄讓人看得出邊界
	var e := (ARENA + WALL_T) * 0.5
	var long := ARENA + WALL_T * 2.0
	for w: Array in [[Vector3(0, WALL_H * 0.5, e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(0, WALL_H * 0.5, -e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)],
			[Vector3(-e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)]]:
		_solid_box(w[0], w[1]).add_to_group(&"arena_wall")
	$Arena.add_child(FarLand.build(_terrain, _ground_color, [_props[&"TreeOakM"], _props[&"TreeOakS"], _props[&"Bush"],
		_props[&"TreePine2"], _props[&"Saguaro"]],
		_props[&"FenceRail"], FENCE_SEG))

	_build_level()

	# 草地：畫面用的，伺服器沒畫面就不長（測試會直接呼叫 _grass_field 檢查）
	if DisplayServer.get_name() != "headless":
		_grass_field()
		_flora_field()
		_drift = Fx.drift($Arena)

# --- 擺設清單（場景編輯工具，見 docs/plans/2026-09-30-場景編輯工具.md） ---
# 場地上每樣東西是一筆：{kind, pos（x, 離地高度, z）, yaw, ……}。先有清單（自動擺，或從場景檔讀），再照清單蓋。
# 出生點避開建築（_blocked）、灌木藏人（_bushes）、麥田上色（_wheat_fields）這些「記下來的範圍」在加進清單時就算好（_reserve），
# 所以自動擺的時候，後面的東西看得到前面擺了什麼

## 讀場景檔：每個 LevelItem 變成擺設清單的一筆。沒有場景檔就留空，_build_arena 會自動擺一份
func _load_level() -> void:
	if level_path == "" or not ResourceLoader.exists(level_path):
		return
	var scene: Node = load(level_path).instantiate()
	add_child(scene)   # 要在場景樹裡才讀得到整體位置（群組節點可以整組搬）
	for n in scene.find_children("*", "", true, false):
		if n is LevelItem:
			_put(n.to_record())
	scene.free()

## 地形：固定種子的丘陵，靶場、撤離區固定整平，再加上清單裡的整平區（flats：[[中心, 半徑], ...]）。
## 遊戲和編輯器（LevelRoot）用同一支，編輯器裡看到的地面才跟遊戲一樣
static func make_terrain(flats: Array) -> Terrain:
	var t := Terrain.new(ARENA, 20260927)
	# 沙盒靶場和撤離區不再整平：以前的十字路一整條是平的，現在跟周圍一樣有起伏。只有清單裡的整平區（建築底下、城鎮街道）是平的
	for f: Array in flats:
		t.flatten_circle(f[0], f[1])
	t.settle()   # 靠太近的平地把高度拉近，中間才不會擠出陡坡
	return t

## 每種東西在地面上佔的長方形半寬（沿自己的 X、Z）。出生點避開（_reserve，再加各自的間隔）和擺設檢查（LevelCheck）共用
const FOOTPRINT := {&"house": Vector2(6.0, 6.5), &"silo": Vector2(3.0, 3.0), &"hay_shed": Vector2(4.0, 3.5),
	&"windmill": Vector2(1.5, 1.5), &"tree": Vector2(0.5, 0.5), &"hay_bale": Vector2(0.75, 0.75),
	&"hitch": Vector2(1.7, 0.15), &"gate": Vector2(0.15, 0.15), &"water_tower": Vector2(2.3, 2.3)}
## 店面佔地（半寬）：房子本身＋門口人行道和台階。前後一樣長（背後多留一點空地，比較好算）
const SHOP_HALF := {&"Saloon": Vector2(5.3, 9.5), &"Store": Vector2(4.8, 9.0), &"Sheriff": Vector2(4.3, 8.4)}
## 出生點要再離多遠（穀倉的在清單那一筆自己帶，大穀倉和小棚子不一樣）
const CLEARANCE := {&"house": SPAWN_CLEARANCE, &"silo": 3.0, &"hay_shed": 2.0, &"windmill": 2.0, &"tree": 1.5,
	&"hay_bale": 1.0, &"rock": 1.5, &"fence": 0.6, &"shop": SPAWN_CLEARANCE, &"water_tower": 2.0}

## 這一筆在地面上佔的半寬；沒有碰撞的（灌木、碎石、只有外觀的東西）回傳 ZERO
static func footprint_half(rec: Dictionary) -> Vector2:
	match rec.kind:
		&"barn":
			return Vector2(rec.size.x, rec.size.z) * 0.5
		&"shop":
			return SHOP_HALF.get(rec.variant, Vector2(5, 9))
		&"fence":
			return Vector2(maxf(rec.length * 0.5 - 0.25, 0.0), 0.15)   # 兩端各縮一根柱子：轉角接頭、門柱貼著端點不算佔到
		&"kit":
			var k: Vector3 = KIT_SIZE.get(rec.name, Vector3.ZERO)
			return Vector2(k.x, k.z) * 0.5
		&"rock":
			if not rec.solid:
				return Vector2.ZERO
			var r: Vector3 = meshes()[rec.mesh].get_aabb().size * rec.s
			return Vector2(r.x, r.z) * 0.5
	return FOOTPRINT.get(rec.kind, Vector2.ZERO)

## 加一筆到擺設清單
func _put(rec: Dictionary) -> void:
	_level.append(rec)
	_reserve(rec)

## 這一筆會佔掉哪些範圍（出生點要避開、灌木藏人、麥田上色）
func _reserve(rec: Dictionary) -> void:
	var p: Vector3 = rec.pos
	match rec.kind:
		&"wheat":
			_wheat_fields.append(Rect2(p.x - rec.size * 0.5, p.z - rec.size * 0.5, rec.size, rec.size))
			return
		&"road":
			var r := Rect2(p.x - rec.size.x * 0.5, p.z - rec.size.z * 0.5, rec.size.x, rec.size.z)
			_roads.append(r)
			_block(Vector3(r.get_center().x, 0, r.get_center().y), r.size, 0.0)   # 街上不長樹、不放石頭
			return
		&"bush":
			_bushes.append(Vector3(p.x, 0, p.z))
			return
		&"kit":
			return   # 小物件不擋出生點
		&"hay_bale":
			if not rec.get("block", false):
				return   # 麥田裡的圓捆不擋（空地補的那些才擋）
	# 佔地（照朝向轉過之後的外框）＋間隔。柵欄也佔地：後面擺的樹、石頭、草捆才不會卡在柵欄裡
	var half := footprint_half(rec)
	if half == Vector2.ZERO or not (rec.kind == &"barn" or CLEARANCE.has(rec.kind)):
		return   # 門柱、繫柱架這種細的不擋出生點
	var yaw: float = rec.get("yaw", 0.0)
	var ext := Vector2(absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y, absf(sin(yaw)) * half.x + absf(cos(yaw)) * half.y)
	_block(p, ext * 2.0, rec.clearance if rec.kind == &"barn" else CLEARANCE[rec.kind])

## 照擺設清單把東西蓋出來。順序跟清單一樣（門的名字 Door0、Door1… 照蓋的順序，每台機器要一樣）
func _build_level() -> void:
	var bushes: Array[Transform3D] = []
	for rec: Dictionary in _level:
		var p: Vector3 = rec.pos
		match rec.kind:
			&"wheat": _wheat(rec)
			&"barn": _barn(p, rec.size)
			&"house": _house(p, rec.variant)
			&"silo": _silo(p, rec.h)
			&"fence": _fence(p, rec.length, rec.yaw)
			&"gate": _gate(p, rec.out, rec.left)
			&"windmill": _windmill(p)
			&"hay_shed": _hay_shed(p)
			&"hay_bale": _hay_bale(p, rec.yaw)
			&"kit": _kit(rec.name, p, rec.yaw)
			&"wheel": _lean_wheel(p, rec.yaw)
			&"hitch": _hitch(p)
			&"shop": _shop(p, rec.variant, rec.yaw)
			&"water_tower": _water_tower(p, rec.yaw)
			&"tree": _tree(rec)
			&"rock": _rock(rec.mesh, p, rec.s, rec.yaw, rec.solid)
			&"prop": _prop(rec.name, _on_ground(p)).rotation.y = rec.yaw
			&"bush":
				# 埋一點，斜坡下坡那側才不會懸空。灌木幾百叢，用 MultiMesh 一次畫完
				bushes.append(Transform3D(Basis(Vector3.UP, rec.yaw).scaled(rec.size), _on_ground(p) + Vector3.DOWN * 0.15))
	_scatter(&"Bush", bushes, true)

## 自動擺一份初稿：固定種子的亂數，每台機器擺出來一樣。手調過的場景檔存在時不會跑這個
func _generate_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	if mode == &"range":
		_generate_range(rng)
		return
	# 場地分四區：西北農社區、東北城鎮、西南麥田、東南森林，之間用彎曲的荒地小路（trails.gd）連起來。
	# 沙盒靶場在南北那條路的南段、撤離點在東西兩端，位置不動。農社區先蓋：_blocked[0] 要是一棟擋得住視線的穀倉（測試靠它）
	_zone_farm(rng)
	_zone_town(rng)
	_zone_wheat(rng)
	_zone_forest(rng)

	# 沿著場邊種一圈樹
	var edge := ARENA * 0.5 - 6.0
	for i in 40:
		var t := float(i) / 40.0 * 4.0
		var side := int(t)
		var u := (t - side) * ARENA - ARENA * 0.5
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u),
			Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		if _free(p, 2) and _is_clear(Vector2(p.x, p.z)) and _inside(p, 2.5) and not ZONE_TOWN.has_point(Vector2(p.x, p.z)) \
				and Trails.edge(p.x, p.z) > 2.0:   # 四個角會跑出場外；主路從東西兩邊出場
			_gen_tree(p, rng, 0.4)

	# 空地補東西：塊跟塊之間本來是一大片空草地，補上樹和乾草捲，走到哪都有東西可以躲。
	# 樹照植被密度（Terrain.vegetation）長：濕地一叢一叢成林、旱地零星；乾草捲不挑地方
	var inner := ARENA * 0.5
	for i in 260:   # 次數照「掩體總量跟改之前差不多」調的
		var p := Vector3(rng.randf_range(-inner + 12, inner - 12), 0, rng.randf_range(-inner + 12, inner - 12))
		if Trails.edge(p.x, p.z) < 3.0 or not _free(p, 6) or not _is_clear(Vector2(p.x, p.z)) \
				or _in_wheat(p) or ZONE_TOWN.has_point(Vector2(p.x, p.z)):
			continue
		var roll := rng.randf()
		if roll < Terrain.vegetation(p.x, p.z) * 0.8:
			_gen_tree(p, rng, 0.3)
		elif roll > 0.8:
			var bale := {kind = &"hay_bale", pos = p, yaw = rng.randf() * PI, block = true}
			if not _overlaps_placed(bale):   # 柵欄不在 _blocked 裡（太細），用擺設檢查的佔地來比
				_put(bale)

	# 灌木叢：兩三叢一群，蹲進去就看不到人。只擋視線不擋子彈，也沒碰撞（跟 Hunt 一樣）。
	# 用自己的亂數，灌木多一叢少一叢不會影響其他東西的位置
	var br := RandomNumberGenerator.new()
	br.seed = 13
	for i in 300:   # 城鎮和麥田不長，其他地方要補多一點
		var c := Vector3(br.randf_range(-inner + 8, inner - 8), 0, br.randf_range(-inner + 8, inner - 8))
		if br.randf() > Terrain.vegetation(c.x, c.z) * 1.6:   # 濕地多、旱地少（不是沒有：旱地也要有地方躲）
			continue
		for k in br.randi_range(2, 4):
			var p := c + Vector3(br.randf_range(-2.5, 2.5), 0, br.randf_range(-2.5, 2.5))
			if Trails.edge(p.x, p.z) < 2.0 or not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)) \
					or _in_wheat(p) or ZONE_TOWN.has_point(Vector2(p.x, p.z)):
				continue
			var s := br.randf_range(0.75, 1.3)
			var yaw := br.randf() * TAU
			_put({kind = &"bush", pos = p, yaw = yaw, size = Vector3(s, s * br.randf_range(0.85, 1.15), s)})
	_gen_rocks(inner)

	# 撤離點旁邊停一台篷車：遠遠就認得出「從這裡走」；旁邊是卸下來的貨
	for ex: Vector2 in exit_spots():
		_put({kind = &"prop", name = &"Wagon", pos = Vector3(ex.x, 0, ex.y + EXIT_RADIUS + 3.0), yaw = 0.4})
		_gen_clutter(Vector3(ex.x + 3.5, 0, ex.y + EXIT_RADIUS + 1.2), 0.4)

## rec 的佔地跟已經擺好的東西重不重疊（跟擺設檢查 LevelCheck 同一套算法）
func _overlaps_placed(rec: Dictionary) -> bool:
	var fp := LevelCheck.footprint(rec)
	return not fp.is_empty() and _level.any(func(o: Dictionary) -> bool:
		var f := LevelCheck.footprint(o)
		return not f.is_empty() and LevelCheck.overlap(fp, f))

## 離場邊至少 margin 公尺（場邊有看不見的牆）
func _inside(p: Vector3, margin: float) -> bool:
	return absf(p.x) < ARENA * 0.5 - margin and absf(p.z) < ARENA * 0.5 - margin

## 一棵樹：亂數決定種類（松樹、闊葉樹大中小）、大小、朝向
func _gen_tree(p: Vector3, rng: RandomNumberGenerator, pine_chance := 0.0) -> void:
	var h := rng.randf_range(4.0, 6.0)
	var rec := {kind = &"tree", pos = p}
	if rng.randf() < pine_chance:
		rec.mesh = &"TreePine"
		rec.s = h / TREE_BASE_TRUNK
	else:
		# 闊葉樹：同一個亂數 h 決定大中小（小 25%、中 40%、大 35%）和 ±10% 的縮放
		var t := (h - 4.0) / 2.0
		rec.mesh = &"TreeOakS" if t < 0.25 else (&"TreeOakM" if t < 0.65 else &"TreeOak")
		rec.s = 0.9 + 0.2 * fmod(t * 7.0, 1.0)
	rec.yaw = rng.randf() * TAU   # 每棵轉個角度，一整排才不會長得一模一樣
	_put(rec)

## 穀倉＋門口外面的東西：一邊一堆雜物、另一邊牆上靠一個車輪（放在滑門拉開的範圍外），側牆邊疊草捆
func _gen_barn(p: Vector3, size: Vector3, clearance := SPAWN_CLEARANCE) -> void:
	_put({kind = &"barn", pos = p, size = size, clearance = clearance})
	var s := size / BARN_BASE
	_gen_clutter(p + Vector3(-(BARN_DOOR_W * s.x + 1.9), 0, size.z * 0.5 + 1.3), 0.0)
	_put({kind = &"wheel", pos = p + Vector3(BARN_DOOR_W * s.x + 0.9, 0, size.z * 0.5), yaw = 0.0})
	_gen_hay_stack(p + Vector3(-(size.x * 0.5 + 0.8), 0, size.z * 0.15), PI * 0.5)

## 農舍（三種輪流：不用亂數，後面擺的東西位置才不會跟著變）＋門前的繫柱架、左側牆邊一排木桶木箱
func _gen_house(p: Vector3, variant: StringName = &"") -> void:
	if variant == &"":
		variant = HOUSE_KINDS.keys()[_houses_built % HOUSE_KINDS.size()]
		_houses_built += 1
	_put({kind = &"house", pos = p, variant = variant})
	_put({kind = &"hitch", pos = p + Vector3(-4.5, 0, 10.5)})   # 台階旁邊，不擋路
	_gen_clutter(p + Vector3(-6.9, 0, 1.4), PI * 0.5)

## 一小堆雜物（木桶、木箱、方草捆）排成一列：蹲得進去的矮掩體，擋子彈。
## 用自己的亂數（照位置算）：多擺少擺不影響其他東西的位置
func _gen_clutter(p: Vector3, yaw: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(p.x * 131.0 + p.z * 17.0)
	var along := Basis(Vector3.UP, yaw)
	var kinds: Array[StringName] = [&"Barrel", &"Crate", &"HayBlock"]
	var n := r.randi_range(2, 4)
	for i in n:
		var k := kinds[r.randi() % kinds.size()]
		var off := along * Vector3((i - (n - 1) * 0.5) * 1.25, 0, r.randf_range(-0.3, 0.3))
		_put({kind = &"kit", name = k, pos = p + off, yaw = yaw + r.randf_range(-0.3, 0.3)})

## 疊起來的方草捆：底下兩捆、上面一捆（pos.y 是離地高度）
func _gen_hay_stack(p: Vector3, yaw: float) -> void:
	var along := Basis(Vector3.UP, yaw)
	for off: Vector3 in [Vector3(-0.56, 0, 0), Vector3(0.56, 0, 0), Vector3(0, HAY_BLOCK.y, 0)]:
		_put({kind = &"kit", name = &"HayBlock", pos = p + along * Vector3(off.x, 0, 0) + Vector3(0, off.y, 0), yaw = yaw})

## 描線：一片蓋滿畫面的方塊，用 outline.gdshader 從深度和法線畫出輪廓和稜線。
## 放在場地底下，任何相機（玩家、檢視模式、截圖）都會畫到；剔除邊界拉很大，不會因為方塊不在視野裡被跳過
func _use_outline() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://outline.gdshader")
	mat.render_priority = Material.RENDER_PRIORITY_MIN   # 比火光、煙先畫：它們蓋在線上，不會被框一圈黑邊
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = &"Outline"   # tools/style_shots.gd 用名字找它調油畫感
	mi.mesh = quad
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Arena.add_child(mi)

## 上方的方位條：看著的方向、蛋在哪、兩個撤離區在哪（都附距離）。
## 蛋在自己身上就不標蛋；沙盒沒有蛋也不標
var _compass: Compass
func _update_compass() -> void:
	var cam := get_viewport().get_camera_3d()
	if _compass == null:
		_compass = Compass.new()
		$UI/Root.add_child(_compass)
	if cam == null:
		return
	_compass.set_view(cam)
	var at := cam.global_position
	var marks := []
	if egg.visible and egg.carrier != multiplayer.get_unique_id():
		marks.append({"deg": Compass.bearing(at, egg.global_position), "dist": at.distance_to(egg.global_position),
			"color": Compass.EGG_COLOR, "label": "蛋"})
	for e: Vector3 in (_exits if RULES[rules].egg and not _solo_dino else []):
		marks.append({"deg": Compass.bearing(at, e), "dist": at.distance_to(e),
			"color": Compass.EXIT_COLOR, "label": "撤離"})
	var boss := get_tree().get_first_node_in_group(&"boss") as Node3D
	if _solo_dino and boss:   # 測恐龍行為：標出恐龍在哪
		marks.append({"deg": Compass.bearing(at, boss.global_position), "dist": at.distance_to(boss.global_position),
			"color": Color(1, 0.35, 0.3), "label": "恐龍"})
	_compass.marks = marks
	_compass.queue_redraw()

## boss 的體力條（畫面上方中間，每個人都看得到）：看牠還跑不跑得動，決定現在要逃還是要躲。
## 跑不動（力竭）變紅、倒地變灰
var _boss_bar: ProgressBar
var _boss_label: Label
func _update_boss_bar(me: Node) -> void:
	var b := get_tree().get_first_node_in_group(&"boss")
	# 當牛仔時不顯示（0.8.1 回饋）。沙盒是測恐龍行為的地方，留著
	var duel := rules == &"dino_duel" and not _sandbox and mode != &"range"
	if not _sandbox and not duel and not (me != null and me.is_in_group(&"dino")):
		b = null
	if _boss_bar == null:
		_boss_bar = ProgressBar.new()
		_boss_bar.show_percentage = false
		_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_bar.offset_left = -160
		_boss_bar.offset_right = 160
		_boss_bar.offset_top = 140   # 在方位條（compass.gd）和倒數（CenterInfo）下面
		_boss_bar.offset_bottom = 154
		_boss_bar.add_theme_stylebox_override(&"background", stamina_bar.get_theme_stylebox(&"background"))
		_boss_bar.add_theme_stylebox_override(&"fill", stamina_bar.get_theme_stylebox(&"fill"))
		_boss_label = Label.new()
		_boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_label.offset_left = -160
		_boss_label.offset_right = 160
		_boss_label.offset_top = 116
		_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		$UI/Root.add_child(_boss_label)
		$UI/Root.add_child(_boss_bar)
	_boss_bar.visible = b != null
	_boss_label.visible = b != null
	if b == null:
		return
	if duel:   # 恐龍決鬥：大家要看的是牠還剩多少血
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp
		_boss_bar.modulate = Color(1, 0.45, 0.35)
		_boss_label.text = "恐龍　%d / %d" % [b.hp, b.max_hp]
		return
	_boss_bar.max_value = 100
	_boss_bar.value = b.stamina
	var state := "奔跑中" if b.running else "走路"
	if b.down_left > 0.0:
		state = "倒地 %d 秒" % ceili(b.down_left)
		_boss_bar.modulate = Color(0.6, 0.6, 0.6)
	elif b.exhausted:
		state = "跑不動了！"
		_boss_bar.modulate = Color(1, 0.35, 0.3)
	else:
		_boss_bar.modulate = Color.WHITE
	_boss_label.text = "恐龍 boss　體力（%s）" % state

## 天空換成 sky.gdshader（有雲、有太陽盤）。霧只蓋一點點天空，不然雲全被霧洗掉
func _use_sky() -> void:
	var env: Environment = $Arena/WorldEnvironment.environment
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://sky.gdshader")
	env.sky.sky_material = mat
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64   # 環境光只要大概的顏色
	env.fog_sky_affect = 0.0   # 霧的灰紫色會混進地平線的橘

## 石頭：空地上零星的大石當掩體（有碰撞、擋子彈），山崖腳下堆一圈碎石和石頭堆（把牆腳藏起來）。
## 用自己的亂數，多一顆少一顆不會影響其他東西的位置
func _gen_rocks(inner: float) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = 21
	for i in 120:   # 空地：大石和石頭堆，當掩體。旱地多（植被密度低的地方），樹林裡少
		var p := Vector3(rr.randf_range(-inner + 12, inner - 12), 0, rr.randf_range(-inner + 12, inner - 12))
		if rr.randf() < Terrain.vegetation(p.x, p.z) * 0.8:
			continue
		var kind: StringName = ROCK_COVER[rr.randi() % ROCK_COVER.size()]
		var s := rr.randf_range(0.45, 0.7) if kind in [&"Rock01", &"Rock02", &"Rock03", &"Rock04"] else rr.randf_range(0.8, 1.2)
		var yaw := rr.randf() * TAU
		var half: float = _props.get(kind).get_aabb().size.x * s * 0.5
		if Trails.edge(p.x, p.z) < 3.0 or not _free(p, 5) or not _is_clear(Vector2(p.x, p.z), half) or _in_wheat(p) \
				or ZONE_TOWN.has_point(Vector2(p.x, p.z)) \
				or _near_bush(p, half + 2.0):
			continue
		_put({kind = &"rock", mesh = kind, pos = p, s = s, yaw = yaw, solid = true})
	var edge := inner - 4.0
	for i in 70:   # 山崖腳下：碎石、小石頭堆，只是外觀
		var t := rr.randf() * 4.0
		var side := int(t)
		var u := (t - side) * inner * 2.0 - inner
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u), Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rr.randf_range(-2.5, 2.5), 0, rr.randf_range(-2.5, 2.5))
		var kind: StringName = ROCK_SCATTER[rr.randi() % ROCK_SCATTER.size()]
		var s := rr.randf_range(0.9, 1.6)
		var yaw := rr.randf() * TAU
		if Trails.edge(p.x, p.z) < 1.0 or not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)) or not _inside(p, 2.0):
			continue
		_put({kind = &"rock", mesh = kind, pos = p, s = s, yaw = yaw, solid = false})

## 灌木先撒，石頭後放：石頭不能壓在灌木上（灌木會被圈進石頭的保留區）
func _near_bush(p: Vector3, r: float) -> bool:
	for b: Vector3 in _bushes:
		if Vector2(p.x, p.z).distance_to(Vector2(b.x, b.z)) < r:
			return true
	return false

## 一顆石頭：往下埋一點（斜坡上才不會懸空）。solid 的用模型的凸包當碰撞，擋人也擋子彈
func _rock(kind: StringName, p: Vector3, s: float, yaw: float, solid: bool) -> void:
	var at := _on_ground(p) + Vector3.DOWN * 0.15 * s
	var mesh: Mesh = _props.get(kind)
	if solid:
		var hull := mesh.create_convex_shape() as ConvexPolygonShape3D
		var pts := PackedVector3Array()
		for v in hull.points:
			pts.append(v * s)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var body := _body(at, shape)
		body.add_to_group(&"stone")   # 子彈打到噴石屑
		body.rotation.y = yaw
		_prop(kind, Vector3.ZERO, Vector3.ONE * s, body)
	else:
		var mi := _prop(kind, at, Vector3.ONE * s)
		mi.rotation.y = yaw

## 蹲在灌木叢裡（離某叢中心 1.2 公尺內）：灌木 1.5 公尺高，站著頭會露出來，蹲下才藏得住
func hidden_in_bush(who: Node3D) -> bool:
	if who.get(&"sync_crouching") != true:
		return false
	var at := Vector2(who.global_position.x, who.global_position.z)
	for b: Vector3 in _bushes:
		if at.distance_to(Vector2(b.x, b.z)) < 1.2:
			return true
	return false

func _in_wheat(p: Vector3) -> bool:
	for f: Rect2 in _wheat_fields:
		if f.grow(2.0).has_point(Vector2(p.x, p.z)):
			return true
	return false

## 荒野的矮植物（blender/flora.py）：草叢、灌木、小仙人掌。只有外觀、沒碰撞也不藏人（都不到一公尺半），
## 伺服器不長。城鎮區是荒漠長得最多、也只有那裡有球形仙人掌和仙人掌片；其他地方零星幾叢。路上、建築旁、麥田、靶場、撤離區不長。
## 用自己的亂數，每台機器長得一樣。名字: [城鎮區幾叢, 其他地方幾叢]
## 城鎮區以外照植被密度（Terrain.vegetation）挑地方：高草長在濕地（樹林旁），矮灌木、仙人掌長在旱地
const FLORA_WET := [&"GrassTall", &"GrassDense", &"GrassSmall"]
const FLORA_MIX := {&"GrassTall": [70, 110], &"GrassDense": [60, 90], &"GrassSmall": [90, 150], &"ScrubBush": [60, 40],
	&"DesertBush": [15, 30], &"BarrelCactus": [18, 0], &"PricklyPear": [14, 0]}
func _flora_field() -> void:
	var fr := RandomNumberGenerator.new()
	fr.seed = 29
	var half := ARENA * 0.5 - 3.0
	for name: StringName in FLORA_MIX:
		var pts: Array[Transform3D] = []
		for zone in 2:
			var want: int = FLORA_MIX[name][zone]
			var placed := 0
			for i in want * 8:   # 試到種滿為止，擋到的位置跳過
				if placed == want:
					break
				var p := Vector2(fr.randf_range(ZONE_TOWN.position.x, ZONE_TOWN.end.x), fr.randf_range(ZONE_TOWN.position.y, ZONE_TOWN.end.y)) \
					if zone == 0 else Vector2(fr.randf_range(-half, half), fr.randf_range(-half, half))
				var yaw := fr.randf() * TAU
				var s := fr.randf_range(0.8, 1.2)
				var v := Terrain.vegetation(p.x, p.y)
				if zone == 1 and fr.randf() > (v if name in FLORA_WET else 1.0 - v):
					continue
				if Trails.edge(p.x, p.y) < 1.0 or (zone == 1 and ZONE_TOWN.has_point(p)) or not _is_clear(p, 0.5) \
						or _in_wheat(Vector3(p.x, 0, p.y)) or not _free(Vector3(p.x, 0, p.y), 1.0) \
						or _roads.any(func(r: Rect2) -> bool: return r.has_point(p)):
					continue
				pts.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), _on_ground(Vector3(p.x, 0, p.y)) + Vector3.DOWN * 0.05))
				placed += 1
		_scatter(name, pts, name in [&"BarrelCactus", &"PricklyPear", &"DesertBush"])

const GRASS_CHUNK := 16.0
const GRASS_PER_M2 := 6.0   # 效能旋鈕：電腦跑不動就調低（3 看得出一叢一叢的空隙）
const GRASS_SHADER := preload("res://grass.gdshader")

## 草地：16 公尺一塊的 MultiMesh，每塊自己剔除、45 公尺外不畫。
## 顏色取地形頂點的顏色（麥田裡自動變黃），根部暗、尖端亮，風一波一波吹過去，腳邊的草會被撥開。
## 路上、建築周圍不長。用自己的亂數，每台機器長得一樣。
## spots 給一個陣列就把每叢的位置也放進去（測試用：沒畫面的伺服器讀不回 MultiMesh 裡的位置）
func _grass_field(spots: Variant = null) -> void:
	var mesh := _grass_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	var gr := RandomNumberGenerator.new()
	gr.seed = 7
	var per := int(GRASS_CHUNK * GRASS_CHUNK * GRASS_PER_M2)
	var cells := int(ARENA / GRASS_CHUNK)
	var half := GRASS_CHUNK * 0.5
	for cx in cells:
		for cz in cells:
			var o := Vector3((cx + 0.5) * GRASS_CHUNK - ARENA * 0.5, 0, (cz + 0.5) * GRASS_CHUNK - ARENA * 0.5)
			# 先挑出碰到這塊的建築：每叢都掃全場的建築會慢到讀圖卡好幾秒
			var area := Rect2(o.x - half, o.z - half, GRASS_CHUNK, GRASS_CHUNK)
			var near: Array[Rect2] = []
			for r: Rect2 in _blocked + _roads:   # 鋪的路（城鎮主街、靶場的靶道）上也不長
				if r.intersects(area):
					near.append(r)
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			for i in per:
				var x := o.x + gr.randf_range(-half, half)
				var z := o.z + gr.randf_range(-half, half)
				var a := gr.randf() * TAU
				var s := gr.randf_range(0.7, 1.3)
				if Trails.edge(x, z) < 0.3:   # 路邊一點點草探進路面，比切齊的邊自然
					continue
				# 植被密度：濕地長滿，旱地剩三成——一片一片的草地和裸土，不是整片均勻的地毯
				if gr.randf() > lerpf(0.3, 1.0, Terrain.vegetation(x, z)):
					continue
				var inside := false
				for r in near:
					if r.has_point(Vector2(x, z)):
						inside = true
						break
				if inside:
					continue
				xf.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * s),
					Vector3(x - o.x, _terrain.fast_height(x, z) - 0.03, z - o.z)))   # 相對塊中心
				cols.append(_terrain.fast_color(x, z))
				if spots != null:
					spots.append(Vector2(x, z))
			if xf.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true            # 一定要在 instance_count 之前設
			mm.mesh = mesh
			mm.instance_count = xf.size()
			# ponytail: 一叢一叢設，全場約 30 萬次。讀圖太慢再改成一次填 mm.buffer
			#（但沒畫面的伺服器不會存 buffer，測試會讀不到位置）
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
				mm.set_instance_color(i, cols[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Grass"
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.position = Vector3(o.x, 0, o.z)   # 節點放在塊中心，可見距離才算得對
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 45.0
			mmi.extra_cull_margin = 1.0   # 風吹會把葉子推出 AABB
			mmi.add_to_group(&"grass")
			$Arena.add_child(mmi)

## 一叢七片葉子，每片兩段（根部四邊形＋尖端三角形）。UV.y＝離地高度比例，shader 靠它做漸層和擺動
func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for k in 7:
		var a := r.randf() * TAU
		var h := r.randf_range(0.3, 0.55)
		var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.05, 0.2)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.035
		var at := Vector3(r.randf_range(-0.12, 0.12), 0, r.randf_range(-0.12, 0.12))
		var mid := at + lean * 0.4 + Vector3(0, h * 0.5, 0)
		var tip := at + lean + Vector3(0, h, 0)
		for p: Vector3 in [at - side, at + side, mid + side * 0.7, at - side, mid + side * 0.7, mid - side * 0.7,
				mid - side * 0.7, mid + side * 0.7, tip]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0, p.y / h))
			st.add_vertex(p)
	return st.commit()

## 地面顏色直接畫在地形頂點上：泥土路跟著地形起伏、麥田是黃的、
## 坡頂偏乾黃、山谷偏深綠、陡坡露土、農莊的院子踩出一片泥地
func _ground_color(x: float, z: float, h: float) -> Color:
	return ground_color(_terrain, _wheat_fields, _roads, x, z, h)

## 地面顏色：路、麥田、草地（越高越黃、越陡越露土）。編輯器畫地形（LevelRoot）也用這支
static func ground_color(t: Terrain, wheat: Array[Rect2], roads: Array[Rect2], x: float, z: float, h: float) -> Color:
	if roads.any(func(r: Rect2) -> bool: return r.has_point(Vector2(x, z))):
		return DIRT   # 透明度 1：地面 shader 換成小路的紋理（terrain.gdshader）
	for f: Rect2 in wheat:
		if f.has_point(Vector2(x, z)):
			return Color(WHEAT, 0.0)   # 透明度 0：不是路
	var c := GRASS.lerp(Color(0.86, 0.71, 0.43), clampf((h + Terrain.AMP) / (Terrain.AMP * 2.0), 0.0, 1.0) * 0.55)
	# 旱地（植被密度低）偏乾土色，跟上面長的草、仙人掌、石頭對得上
	c = c.lerp(DIRT, (1.0 - Terrain.vegetation(x, z)) * 0.35)
	c = c.lerp(DIRT, clampf(t.slope(x, z) * 5.0, 0.0, 0.7))
	# 荒地小路：顏色往乾土拉，透明度 = 路的濃度（terrain.gdshader 照它換紋理）
	var w := Trails.weight(x, z)
	c = c.lerp(PATH, w)
	c.a = w
	return c

## 把「離地多高」換成實際位置：v.y 當作離地面的高度
func _on_ground(v: Vector3) -> Vector3:
	return Vector3(v.x, _terrain.height(v.x, v.z) + v.y, v.z)

## 這塊地能不能蓋東西：沙盒的靶場、撤離區要空著。
func _free(pos: Vector3, radius: float) -> bool:
	for r: Rect2 in _reserved():
		if r.grow(radius).has_point(Vector2(pos.x, pos.z)):
			return false
	return true

func _reserved() -> Array[Rect2]:
	var out: Array[Rect2] = [SANDBOX_RANGE]
	for e: Vector2 in exit_spots():
		out.append(Rect2(e.x - EXIT_RADIUS - 4, e.y - EXIT_RADIUS - 4, EXIT_RADIUS * 2 + 8, EXIT_RADIUS * 2 + 8))
	return out

## 兩個撤離區的中心：東西兩端（南北向那條路留給沙盒靶場）
static func exit_spots() -> Array[Vector2]:
	var d := ARENA * 0.5 - 22.0
	return [Vector2(d, 0), Vector2(-d, 0)]

## 農莊：穀倉＋農舍＋筒倉，外面一圈柵欄。穀倉是恐龍爬上去看全場的制高點
func _farmstead(c: Vector3, rng: RandomNumberGenerator) -> void:
	var barn := c + Vector3(-8, 0, -4)
	if _free(barn, 14):
		_gen_barn(barn, Vector3(rng.randf_range(12, 16), rng.randf_range(7, 9), rng.randf_range(18, 24)))
	var house := c + Vector3(12, 0, 8)
	if _free(house, 8):
		_gen_house(house)
	var silo := c + Vector3(4, 0, -16)
	if _free(silo, 4):
		_put({kind = &"silo", pos = silo, h = rng.randf_range(13, 18)})
	# 柵欄圍一圈，留兩個缺口當出入口
	var r := 24.0
	for side in 4:
		for k in 8:
			if k == 3 or k == 4:
				if side % 2 == 0:
					continue   # 南北兩邊中間留門
			var u := -r + (k + 0.5) * (r * 2.0 / 8.0)
			var p: Vector3 = [Vector3(u, 0, -r), Vector3(r, 0, u), Vector3(u, 0, r), Vector3(-r, 0, u)][side]
			if _free(c + p, 2):
				_put({kind = &"fence", pos = c + p, length = r * 2.0 / 8.0, yaw = -PI * 0.5 if side % 2 == 1 else 0.0})
	# 南北兩個缺口各一對圍欄門，敞開往外。缺口太靠場地邊緣（門開出去會撞到場邊柵欄）就不裝
	for zz: float in [-r, r]:
		if _free(c + Vector3(0, 0, zz), 7) and absf(c.z + zz) < ARENA * 0.5 - 6.0:
			# 門柱往缺口內縮一點，不跟柵欄端點的木樁疊在一起
			_put({kind = &"gate", pos = c + Vector3(-r / 4.0 + 0.2, 0, zz), out = signf(zz), left = true})
			_put({kind = &"gate", pos = c + Vector3(r / 4.0 - 0.2, 0, zz), out = signf(zz), left = false})
	var mill := c + Vector3(15, 0, -12)
	if _free(mill, 3) and _is_clear(Vector2(mill.x, mill.z)):
		_put({kind = &"windmill", pos = mill})

## 靶場的地圖：整片壓平，中間一條靶道，每 10 公尺一條橫的土線；兩側柵欄，射擊線後面擺個棚子和雜物，
## 盡頭一排樹當背景。靶（牛仔、恐龍）是開局才生的，不在清單裡（見 _start_range）
func _generate_range(rng: RandomNumberGenerator) -> void:
	_put({kind = &"flat", pos = Vector3.ZERO, r = 150.0})
	var z0 := RANGE_START.z
	_put({kind = &"road", pos = Vector3(0, 0, z0), size = Vector3(44, 0, 6)})   # 射擊線
	# 中間的靶道和 75 公尺那條橫路（以前是牧場十字路順便畫的，牧場改成彎曲小路後自己鋪）
	_put({kind = &"road", pos = Vector3.ZERO, size = Vector3(8, 0, ARENA)})
	_put({kind = &"road", pos = Vector3.ZERO, size = Vector3(ARENA, 0, 8)})
	for d in range(10, 160, 10):
		if d != 75:   # 75 公尺那條是上面的橫路
			_put({kind = &"road", pos = Vector3(0, 0, z0 - d), size = Vector3(36, 0, 2)})
	for side: float in [-1.0, 1.0]:
		for k in 15:
			_put({kind = &"fence", pos = Vector3(side * 20.0, 0, z0 - 3.0 - k * 10.0), length = 10.0, yaw = -PI * 0.5})
	var shed := Vector3(-34, 0, z0 - 4)
	_gen_barn(shed, Vector3(8, 4, 6), 3.0)
	_gen_clutter(Vector3(10, 0, z0 + 3.5), 0.0)
	_gen_clutter(Vector3(-10, 0, z0 + 3.5), 0.0)
	_put({kind = &"prop", name = &"Wagon", pos = Vector3(30, 0, z0 - 2), yaw = 0.3})
	for x in range(-44, 45, 7):
		_gen_tree(Vector3(x + rng.randf_range(-2, 2), 0, -79 + rng.randf_range(-1.5, 1.5)), rng, 0.3)
	for i in 24:   # 靶道兩側外面零星的樹
		var p := Vector3((30 + rng.randf_range(0, 45)) * (1 if i % 2 else -1), 0, rng.randf_range(-70, 55))
		if _free(p, 2) and _is_clear(Vector2(p.x, p.z), 2.0):
			_gen_tree(p, rng, 0.3)

## 四個區域（x、z 範圍）。中間留 16 公尺寬的十字空帶（以前是十字路，現在是主路和空地）；西南那塊的東邊讓給沙盒靶場
const ZONE_FARM := Rect2(-84, -84, 76, 76)
const ZONE_TOWN := Rect2(8, -84, 76, 76)
const ZONE_WHEAT := Rect2(-84, 8, 62, 76)
const ZONE_FOREST := Rect2(22, 8, 62, 76)

## 農社區（西北）：一座大農莊（穀倉、農舍、筒倉、風車、一圈柵欄），往路口那邊兩戶人家，路口旁一小塊牧場
func _zone_farm(rng: RandomNumberGenerator) -> void:
	var a := Vector3(-56, 0, -56)
	_put({kind = &"flat", pos = a, r = 30.0})
	_farmstead(a, rng)
	for z: float in [-70.0, -48.0]:
		var h := Vector3(-22, 0, z)
		_put({kind = &"flat", pos = h, r = 10.0})
		_gen_house(h)
	# 牧場：柵欄隔成欄位（翻越練習），旁邊一間小棚子
	var shed := Vector3(-12, 0, -40)   # 再往南會壓到沙盒靶場（z > -30）
	_put({kind = &"flat", pos = shed, r = 10.0})
	_gen_barn(shed, Vector3(8, 4, 6), 3.0)
	for k in 3:
		for seg in 2:
			var p := Vector3(-39 + seg * 10.0, 0, -26 + k * 8.0)
			if _free(p, 2) and rng.randf() > 0.2 and _is_clear(Vector2(p.x, p.z)):
				_put({kind = &"fence", pos = p, length = 10.0, yaw = 0.0})

## 城鎮（東北）：一條東西向的主街，兩排店面面對面（北排朝南、南排朝北），店門口有繫柱架，
## 街上停一台篷車，後面一座水塔當制高點
func _zone_town(rng: RandomNumberGenerator) -> void:
	var sz := -46.0   # 主街中線
	_put({kind = &"road", pos = Vector3(46, 0, sz), size = Vector3(76, 0, 8)})
	for x: float in [16.0, 36.0, 56.0, 76.0]:
		_put({kind = &"flat", pos = Vector3(x, 0, sz), r = 22.0})
	var north := [[&"Saloon", 18.0], [&"Store", 32.0], [&"Sheriff", 45.0], [&"house", 58.0], [&"Store", 72.0]]
	var south := [[&"Store", 26.0], [&"Sheriff", 38.0], [&"Saloon", 51.0], [&"Store", 65.0]]   # 西邊讓給沙盒靶場
	for row: Array in [[north, sz - 14.0, 0.0, -1.0], [south, sz + 14.0, PI, 1.0]]:
		for b: Array in row[0]:
			var p := Vector3(b[1], 0, row[1])
			if b[0] == &"house":
				_gen_house(p)
				continue
			_put({kind = &"shop", pos = p, variant = b[0], yaw = row[2]})
			# 門口的繫柱架：台階旁邊，在街上
			_put({kind = &"hitch", pos = Vector3(b[1] + 3.6, 0, sz + row[3] * 3.0)})
		for i in row[0].size() - 1:   # 兩棟之間的巷子口堆一點雜物（農舍自己會堆，旁邊不再堆）
			if &"house" in [row[0][i][0], row[0][i + 1][0]]:
				continue
			var x: float = (row[0][i][1] + row[0][i + 1][1]) * 0.5
			_gen_clutter(Vector3(x, 0, row[1] - row[3] * 4.0), PI * 0.5)
	_put({kind = &"prop", name = &"Wagon", pos = Vector3(54, 0, sz + 1.5), yaw = 0.1 + rng.randf() * 0.2})
	_put({kind = &"water_tower", pos = Vector3(78, 0, -78), yaw = 0.0})

## 麥田（西南）：一大片麥子，裡面散著圓捆當掩體，東北角一間倉庫，西邊一座風車
func _zone_wheat(rng: RandomNumberGenerator) -> void:
	var c := Vector3(-52, 0, 50)
	_put({kind = &"wheat", pos = c, size = 58.0})
	# 田裡的車輪痕：一橫一直兩條窄土路，不長麥子
	_put({kind = &"road", pos = Vector3(-52, 0, 44), size = Vector3(58, 0, 2.5)})
	_put({kind = &"road", pos = Vector3(-45, 0, 50), size = Vector3(2.5, 0, 58)})
	var shed := Vector3(-30, 0, 28)
	_put({kind = &"flat", pos = shed, r = 7.0})
	_put({kind = &"hay_shed", pos = shed})
	_gen_hay_stack(shed + Vector3(-4.2, 0, 1.5), PI * 0.5)
	_gen_clutter(shed + Vector3(4.5, 0, 4.2), 0.0)
	for i in 12:
		var p := c + Vector3(rng.randf_range(-27, 27), 0, rng.randf_range(-27, 27))
		var yaw := rng.randf() * PI
		if _free(p, 2) and not _shed_rect(shed).has_point(Vector2(p.x, p.z)) and _is_clear(Vector2(p.x, p.z)):
			_put({kind = &"hay_bale", pos = p, yaw = yaw})
	_put({kind = &"windmill", pos = Vector3(-78, 0, 12)})   # 麥田外面，西北角

## 森林（東南）：一整片林子（闊葉樹為主、三成松樹），中間一塊空地有間圓木小屋和柴堆
func _zone_forest(rng: RandomNumberGenerator) -> void:
	var cabin := Vector3(52, 0, 48)
	_put({kind = &"flat", pos = cabin, r = 11.0})
	_gen_house(cabin, &"House2")
	_gen_clutter(cabin + Vector3(7.5, 0, -3.0), PI * 0.5)
	var z := ZONE_FOREST.position.y + 4.0
	while z < ZONE_FOREST.end.y - 2.0:
		var x := ZONE_FOREST.position.x + 3.0
		while x < ZONE_FOREST.end.x - 2.0:
			var p := Vector3(x + rng.randf_range(-2.5, 2.5), 0, z + rng.randf_range(-2.5, 2.5))
			# 植被密度低的地方是林間空地（不是一整片格子排的樹）；最稀也還有四成多，看起來還是森林
			if rng.randf() < lerpf(0.45, 1.0, Terrain.vegetation(p.x, p.z)) and _free(p, 2) and _is_clear(Vector2(p.x, p.z)) and _inside(p, 3.0):
				_gen_tree(p, rng, 0.35)
			x += 6.5
		z += 6.5

## 麥田裡的麥子：一叢一叢，大約 80 公分高，蹲在裡面會被擋掉一部分。沒有碰撞，子彈照樣穿過去。
## 麥田的黃色畫在地形上（_ground_color）。倉庫蓋在哪，那塊就不長麥子。
## 用自己的亂數（照麥田位置算）：麥子只是外觀，不該影響其他東西的位置
func _wheat(rec: Dictionary) -> void:
	var c: Vector3 = rec.pos
	var sheds: Array[Rect2] = _roads.duplicate()   # 路上和倉庫那塊不長麥子
	for other: Dictionary in _level:
		if other.kind == &"hay_shed":
			sheds.append(_shed_rect(other.pos))
	var wr := RandomNumberGenerator.new()
	wr.seed = int(c.x * 7919.0 + c.z)
	var pts: Array[Transform3D] = []
	var n := int(rec.size / 1.1)   # 一公尺多一叢
	var start: float = -rec.size * 0.5 + 0.5
	for gx in n:
		for gz in n:
			var at := _on_ground(c + Vector3(start + gx * 1.1 + wr.randf_range(-0.4, 0.4), 0,
				start + gz * 1.1 + wr.randf_range(-0.4, 0.4)))
			if sheds.any(func(r: Rect2) -> bool: return r.has_point(Vector2(at.x, at.z))):
				continue
			pts.append(Transform3D(Basis(Vector3.UP, wr.randf() * TAU).scaled(Vector3.ONE * wr.randf_range(0.8, 1.2)), at))
	_scatter_mesh(wheat_card(), pts)

## 麥子：一張只會水平轉向鏡頭的平面（billboard），貼上麥穗的透明圖（tools/make_wheat_card.py 畫的）。
## 幾千叢立體模型換成每叢兩個三角形，遠看一樣是一片麥浪
static var _wheat_mesh: QuadMesh
static func wheat_card() -> QuadMesh:
	if _wheat_mesh == null:
		var mat := ShaderMaterial.new()   # 只繞垂直軸轉的看板、近處變少、穗尖壓暗（見 wheat.gdshader）
		mat.shader = preload("res://wheat.gdshader")
		mat.set_shader_parameter(&"card_tex", preload("res://assets/textures/wheat_card.png"))
		_wheat_mesh = QuadMesh.new()
		_wheat_mesh.size = Vector2(0.55, 1.1)   # 圖是 1:2，最高的穗大約 90 公分
		_wheat_mesh.center_offset = Vector3(0, 0.55, 0)
		_wheat_mesh.material = mat
	return _wheat_mesh

## 倉庫連門口那塊地（不長麥子、不放圓捆）
func _shed_rect(p: Vector3) -> Rect2:
	return Rect2(p.x - 5.5, p.z - 5.0, 12.0, 11.0)

## 穀倉：空心的，進得去。牆（含門洞、窗洞）、閣樓、柱子、隔間的碰撞是 Blender 的 BarnCol，
## 屋頂碰撞是兩片斜板（看不見）。整棟照實際大小縮放，屋頂的寬和高用同一個倍率縮，斜度才跟碰撞一樣。
## 小棚子也用這個，只是小一號（閣樓 2 公尺、門 2.9 × 2.4，一樣進得去、爬得上去）。
func _barn(p: Vector3, size: Vector3) -> void:
	p = _on_ground(p)
	var s := size / BARN_BASE
	_solid_mesh(p, _props.get(&"BarnCol"), s)
	_roof(p, size, BARN_PITCH)
	_prop(&"Barn", p, s)
	_prop(&"BarnRoof", p + Vector3(0, size.y, 0), Vector3(s.x, s.x, s.z))
	# 正面兩扇滑門：關著剛好蓋住門洞，開的時候各往外滑半個門寬
	var front := size.z * 0.5 + 0.12
	for side in [-1.0, 1.0]:
		var d := _door(&"BarnDoorSlide", p + Vector3(side * BARN_DOOR_W * 0.25 * s.x, 0, front),
			Vector3(BARN_DOOR_W * 0.5, BARN_DOOR_H, 0.16), Vector3.ZERO, Vector3(s.x, s.y, 1))
		d.slide = Vector3(side * BARN_DOOR_W * 0.5 * s.x, 0, 0)
	# 後門：門軸在開口左緣，往裡推開
	var back := _door(&"BarnBackDoor", p + Vector3((BARN_BACK_X - BARN_BACK_W * 0.5) * s.x, 0, -(BARN_BASE.z * 0.5 - BARN_T * 0.5) * s.z),
		Vector3(BARN_BACK_W, BARN_BACK_H, 0.08), Vector3(BARN_BACK_W * 0.5, 0, 0), Vector3(s.x, s.y, 1))
	back.swing = -PI * 0.5
	# 閣樓的梯子：靠在閣樓邊緣（z=0），人站在梯子前面（+Z 那側）面向 -Z 爬
	var loft := BARN_LOFT * s.y
	var lx := BARN_LADDER_X * s.x
	_ladder(p + Vector3(lx, 0, 0.15 * s.z), loft + 1.0, p + Vector3(lx, 0, 0.15 * s.z + 0.5), loft,
		p + Vector3(lx, loft + 0.1, -1.0 * s.z), 0.0)
	_lamp(p + Vector3(0, loft - 1.0, 3.0 * s.z), 7.0 * s.x)

## 農舍：空心的，進得去。kind 是三種外觀之一（前廊農舍、圓木小屋、直板高屋），碰撞跟著外觀走
func _house(p: Vector3, kind: StringName) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(StringName(kind + "Col")), Vector3.ONE)
	Fx.chimney($Arena, p + HOUSE_KINDS[kind])
	_prop(kind, p)
	# 前門：門軸在門洞左緣，往屋裡推開
	var d := _door(&"HouseDoor", p + Vector3(-0.55, HOUSE_FLOOR, 4.0 - HOUSE_T * 0.5),
		Vector3(1.1, 2.2, 0.08), Vector3(0.55, 0, 0), Vector3.ONE)
	d.swing = PI * 0.5
	_lamp(p + Vector3(-1.5, 2.6 + HOUSE_FLOOR, 1.8), 5.0)

## --- 場景小物件（kits.glb） ---
## 下面這些函式都自己貼地：p 給不含高度的位置（p.y 是離地高度，通常 0）。
## 已經 _on_ground 過的座標要先把 y 歸零，不然地面多高就浮多高

## 小物件的碰撞方塊大小（底部貼地）。表裡沒有的只有外觀
const KIT_SIZE := {&"Barrel": Vector3(0.7, 0.93, 0.7), &"Crate": Vector3(0.8, 0.8, 0.8), &"HayBlock": HAY_BLOCK,
	&"GatePost": Vector3(0.24, 1.6, 0.24)}

## 擺一個小物件。方草捆跟圓捆一樣算軟：掉在上面摔落傷害減半
func _kit(name: StringName, p: Vector3, yaw: float) -> Node3D:
	p = _on_ground(p)
	var size: Vector3 = KIT_SIZE.get(name, Vector3.ZERO)
	if size == Vector3.ZERO:
		var mi := _prop(name, p)
		mi.rotation.y = yaw
		return mi
	var body := _solid_box(p + Vector3(0, size.y * 0.5, 0), size)
	body.rotation.y = yaw
	if name == &"HayBlock":
		body.add_to_group(&"soft")
	_prop(name, Vector3(0, -size.y * 0.5, 0), Vector3.ONE, body)
	return body

## 靠在牆上的車輪（只有外觀）。p 是牆腳，牆面朝 yaw 方向（0 = 朝 +Z），輪子頂端往牆那邊倒一點
func _lean_wheel(p: Vector3, yaw: float) -> void:
	_prop(&"Wheel", Vector3.ZERO).transform = Transform3D(Basis(Vector3.UP, yaw), _on_ground(p)) * WHEEL_POSE

## 靠牆車輪相對牆腳的擺法：輪軸轉到跟牆垂直、頂端往牆倒一點、輪心離地 0.6（編輯器預覽也用）
const WHEEL_POSE := Transform3D(Basis(Vector3.RIGHT, -0.18) * Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.6, 0.24))

## 馬匹繫柱架：兩根柱子有碰撞，中間的繫馬橫桿 1 公尺高，翻得過去
func _hitch(p: Vector3) -> void:
	p = _on_ground(p)
	_prop(&"HitchRail", p)
	for sx: float in [-1.6, 1.6]:
		_solid_box(p + Vector3(sx, 1.25, 0), Vector3(0.2, 2.5, 0.2))
	_solid_box(p + Vector3(0, 1.0, 0), Vector3(3.2, 0.1, 0.1))

## 圍欄門：門柱有碰撞，門板敞開往外（只有外觀，不擋路）。left = 缺口左邊（-X 那側）；out = 往外是 -Z（-1）還是 +Z（+1）
func _gate(p: Vector3, out: float, left: bool) -> void:
	_kit(&"GatePost", p, 0.0)
	_prop(&"FenceGate", Vector3.ZERO).transform = Transform3D(Basis(), _on_ground(p)) * gate_leaf(out, left)

## 圍欄門的門板相對門柱的擺法：門板本來往 +X 長，轉過去朝外敞開（編輯器預覽也用）
static func gate_leaf(out: float, left: bool) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(100.0 if left else 80.0) * -out), Vector3(0.12 if left else -0.12, 0, 0))

## 風車塔：四根塔腳底部有碰撞；葉輪一直慢慢轉
func _windmill(p: Vector3) -> void:
	p = _on_ground(p)
	_prop(&"Windmill", p)
	for sx: float in [-1.2, 1.2]:
		for sz: float in [-1.2, 1.2]:
			_solid_box(p + Vector3(sx, 1.5, sz), Vector3(0.3, 3.0, 0.3))
	var rotor := _prop(&"WindmillRotor", p + WINDMILL_HUB)
	rotor.create_tween().set_loops().tween_property(rotor, ^"rotation:z", TAU, 7.0).as_relative()

const SHED_LANTERN := Vector3(2.0, 2.95, 3.25)   # 倉庫門口的吊燈（編輯器預覽也用）

## 倉庫／圍棚：門朝 +Z 敞開，裡面疊著方草捆。牆、屋頂、草捆的碰撞是 HayShedCol
## 城鎮店面（酒館、雜貨店、警長辦公室）：空心的，門窗是開口（沒有門板）。碰撞是 Blender 的 <名字>Col，
## 跟著朝向轉（yaw 0 正面朝 +Z，PI 朝 -Z）。裡面一盞暖光
func _shop(p: Vector3, variant: StringName, yaw: float) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(StringName(variant + "Col")), Vector3.ONE).rotation.y = yaw
	_prop(variant, p).rotation.y = yaw
	_lamp(p + Vector3(0, 3.0, 0), 7.0)

## 水塔：四根腳和水桶有碰撞（恐龍爬得上去，當城鎮的制高點）
func _water_tower(p: Vector3, yaw: float) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(&"WaterTowerCol"), Vector3.ONE).rotation.y = yaw
	_prop(&"WaterTower", p).rotation.y = yaw

func _hay_shed(p: Vector3) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(&"HayShedCol"), Vector3.ONE)
	_prop(&"HayShed", p)
	_prop(&"Lantern", p + SHED_LANTERN)

func _silo(p: Vector3, h: float) -> void:
	p = _on_ground(p)
	_solid_cyl(p + Vector3(0, h * 0.5, 0), 3.0, h)
	_solid_cyl(p + Vector3(0, h + 0.8, 0), 1.6, 1.6)   # 圓頂中間站得住的地方（爬梯子上來就站這）
	# 外側的爬梯（模型本來就有）：F 爬到頂，全場最高的狙擊點，摔下來也必死
	_ladder(p + Vector3(3.25, 0, 0), h, p + Vector3(3.25 + 0.5, 0, 0), h,
		p + Vector3(0, h + 1.7, 0), PI * 0.5)
	_prop(&"SiloBody", p, Vector3(1, h / SILO_BASE_H, 1))
	_prop(&"SiloDome", p + Vector3(0, h, 0))

## 柵欄：碰撞是一整片 1 公尺高的板子——剛好在翻越範圍內。外觀是一段段 2.5 公尺的
## 木樁＋橫木排過去（長度不整除就每段稍微拉長），最後補一根收尾的木樁
func _fence(p: Vector3, length: float, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	# 兩端各自貼地，整段沿著坡度斜過去。p.y 是離地高度（沙盒的練習柵欄用）。yaw 0 沿 X，-90 度沿 +Z
	var dir := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var a := _on_ground(p - dir * length * 0.5)
	var b := _on_ground(p + dir * length * 0.5)
	var x := (b - a).normalized()
	var z := x.cross(Vector3.UP).normalized()
	body.transform = Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, FENCE_H, 0.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = FENCE_H * 0.5
	body.add_child(cs)
	var n := maxi(ceili(length / FENCE_SEG), 1)
	var seg := length / n
	for i in n:
		_prop(&"FenceRail", Vector3(-length * 0.5 + (i + 0.5) * seg, 0, 0), Vector3(seg / FENCE_SEG, 1, 1), body)
	_prop(&"FencePost", Vector3(length * 0.5, 0, 0), Vector3.ONE, body)
	$Arena.add_child(body)
	return body

const HAY_BALE_R := 0.7   # 圓捆半徑（躺著放，軸心離地這麼高；編輯器預覽也用）
func _hay_bale(p: Vector3, yaw: float) -> StaticBody3D:
	# 圓捆躺著放：直徑 1.4 公尺，翻得過去也蹲得進後面。模型的軸是直的，跟著碰撞圓柱一起放倒
	var body := _solid_cyl(_on_ground(p) + Vector3(0, HAY_BALE_R, 0), HAY_BALE_R, 1.3)
	body.rotation = Vector3(0, yaw, PI * 0.5)
	body.add_to_group(&"soft")   # 從屋頂跳下來落在乾草上，摔落傷害減半
	_prop(&"HayBale", Vector3.ZERO, Vector3.ONE, body)
	return body

## 樹：只有樹幹有碰撞，擋子彈；樹冠擋視線不擋子彈，躲在樹下只是比較難被看到。
## pine_chance：林子邊緣混一點松樹，果園只種闊葉樹
func _tree(rec: Dictionary) -> void:
	var p := _on_ground(rec.pos) + Vector3.DOWN * 0.3   # 往下埋一點：斜坡上樹根的下坡那側才不會懸空
	var s: float = rec.s
	if rec.mesh == &"TreePine":
		var h := s * TREE_BASE_TRUNK
		_solid_cyl(p + Vector3(0, h * 0.5, 0), 0.35, h)
	else:
		var trunk: Array = TREE_KINDS[rec.mesh]
		_solid_cyl(p + Vector3(0, trunk[1] * s * 0.5, 0), trunk[0] * s, trunk[1] * s)
	_prop(rec.mesh, p, Vector3.ONE * s).rotation.y = rec.yaw

## 人字屋頂的碰撞：兩片斜板。斜度在 45 度以內，恐龍爬上來站得住。
## 外觀在 Blender 的模型裡（blender/props.py 的 gable_roof() 照這個擺法建的）
func _roof(p: Vector3, size: Vector3, pitch: float) -> void:
	var run := size.x * 0.5
	var rise := run * tan(pitch)
	var w := run / cos(pitch) + 0.5   # 多出來的是屋簷
	for sx in [-1.0, 1.0]:
		var b := _solid_box(p + Vector3(sx * run * 0.5, size.y + rise * 0.5, 0), Vector3(w, 0.3, size.z + 1.0))
		b.rotation.z = -sx * pitch

## 會動的門：碰撞是一塊板（看不見），外觀是 Blender 的門。
## pivot 是門軸／底部中央的位置；box 是門板大小（沒縮放前），center 是門板中心相對門軸的位置。
## 名字依序取 Door0、Door1…：每台機器蓋場景的順序一樣，RPC 才找得到同一扇門
func _door(mesh: StringName, pivot: Vector3, box: Vector3, center: Vector3, scale: Vector3) -> Door:
	var d := Door.new()
	d.name = "Door%d" % _doors.size()
	d.position = pivot
	var shape := BoxShape3D.new()
	shape.size = box * scale
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = (center + Vector3(0, box.y * 0.5, 0)) * scale
	d.add_child(cs)
	_prop(mesh, Vector3.ZERO, scale, d)
	$Arena.add_child(d)
	_doors.append(d)
	return d

## 梯子：thin 的碰撞板讓射線打得到（F 才有反應）。
## at 梯子底部中央；height 梯子多高；foot 人抓住時站的位置；top_y 腳到這個高度就算爬上去；
## exit 爬上去之後站的位置；yaw 爬的時候面向哪
func _ladder(at: Vector3, height: float, foot: Vector3, top_y: float, exit: Vector3, yaw: float) -> void:
	var l := Ladder.new()
	l.position = at + Vector3(0, height * 0.5, 0)
	l.rotation.y = yaw
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, height, 0.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	l.add_child(cs)
	l.foot = foot
	l.top_y = top_y
	l.exit = exit
	l.yaw = yaw
	$Arena.add_child(l)

## 室內的暖光：提燈的光。範圍收在屋子裡，不開影子（十幾盞都開影子太貴）
func _lamp(at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 0.6
	light.omni_range = reach
	light.omni_attenuation = 2.0   # 很快衰減：沒開影子，光會穿牆照到屋外地面
	light.shadow_enabled = false
	light.position = at
	$Arena.add_child(light)

## 空心建築的碰撞：直接拿 Blender 的碰撞模型（BarnCol / HouseCol）當形狀，照實際大小縮放。
## 縮放烘進頂點，不縮碰撞節點——物理引擎對非等比縮放的網格形狀支援不一
func _solid_mesh(pos: Vector3, mesh: Mesh, scale: Vector3) -> StaticBody3D:
	var faces := mesh.get_faces()
	for i in faces.size():
		faces[i] *= scale
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true   # 牆只有幾公分厚，兩面都要擋
	return _body(pos, shape)

## 一次撒幾千個一樣的東西（麥子、草叢）：MultiMesh 一次畫完，一叢一個節點會卡。
## 不投影子：幾千叢的影子很貴，而且貼著地面本來就看不太出來
func _scatter(name: StringName, pts: Array[Transform3D], shadows := false) -> void:
	_scatter_mesh(_props.get(name), pts, shadows)

func _scatter_mesh(mesh: Mesh, pts: Array[Transform3D], shadows := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Arena.add_child(mmi)

## 擺一個 Blender 建的場景物件（models/props.glb）。parent 預設是場地
func _prop(name: StringName, pos: Vector3, scale := Vector3.ONE, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _props.get(name)
	mi.position = pos
	mi.scale = scale
	(parent if parent else $Arena).add_child(mi)
	return mi

## 蛋換成 Blender 的模型（下胖上尖、有斑點），再疊一層加亮：場上最重要的東西要遠遠就看得到
func _skin_egg() -> void:
	var mi: MeshInstance3D = $Egg/MeshInstance3D
	mi.mesh = _props.get(&"Egg")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.28, 0.24, 0.14)
	mi.material_overlay = glow

## 從 props.glb、trees.glb 把每個物件的網格拿出來，場上幾百個物件共用同一份
func _load_props() -> void:
	_props = meshes()

## 全部模型（props、樹、石頭、農舍、小物件）名字 -> Mesh。遊戲、編輯器預覽（LevelPreview）、擺設檢查（LevelCheck）共用這一份
static var _mesh_table := {}
static func meshes() -> Dictionary:
	if _mesh_table.is_empty():
		for glb: PackedScene in [PROPS, TREES, ROCKS, HOUSES, KIT, TOWNS, GROVES, FLORAS]:
			var src := glb.instantiate()
			for c in src.get_children():
				if c is MeshInstance3D:
					_mesh_table[StringName(c.name)] = c.mesh
			src.free()
	return _mesh_table

## 樹的材質不要高光：朝太陽的面疊一層白色反光，會把葉子受光面的黃沖成灰，折面的明暗差就被吃掉。
## Blender 那邊設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 全部模型都不要高光：朝太陽的面疊一層反光會把顏色沖灰、反射粉色的天空（牆和門廊泛粉紫）。
## Blender 設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 網格被資源快取住，改一次之後各處 instantiate 出來的都是改好的那份（glb 要留著，快取才不會被丟掉）
const LEAVES_SHADER := preload("res://leaves.gdshader")
const FLAT_MODELS := ["res://models/props.glb", "res://models/trees.glb", "res://models/rocks.glb", "res://models/houses.glb", "res://models/kits.glb", "res://models/towns.glb",
	"res://models/groves.glb", "res://models/floras.glb",
	"res://models/cowboy.glb", "res://models/trex.glb", "res://models/revolver.glb",
	"res://models/shotgun.glb", "res://models/rifle.glb"]
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
						mi.mesh.surface_set_material(i, leaf)   # 網格是共用的：場上每棵、遠景的樹都跟著換
						continue
					if m.albedo_texture == null:   # 材質可能好幾個網格共用，只疊一次
						_add_grain(m)
		inst.free()

## 紋理：純色平面看起來像塑膠，在材質上疊一層淡淡的程式雜訊——木紋（橫向細條）、石斑、乾草絲、恐龍鱗片。
## 物件自己的座標三面投影（triplanar），不用 UV，會動的東西紋理也黏著走。
## 只動明暗十幾趴：折面之間的明暗差（兩三成）還在，不會像照片貼圖把折面洗掉（見 docs/程式建模迭代.md）。
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

## 出生點避開這塊地
func _block(p: Vector3, size: Vector2, clearance: float) -> void:
	_blocked.append(Rect2(p.x - size.x * 0.5 - clearance, p.z - size.y * 0.5 - clearance,
		size.x + clearance * 2, size.y + clearance * 2))

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

## 兩個撤離區，對邊各一個。只有一個出口的話恐龍蹲在那裡就好；
## 兩個保留了選擇，但競爭比四個集中，撤離區更容易變成三方交會的爭奪點。
func _build_exits() -> void:
	for e: Vector2 in exit_spots():
		var c := _on_ground(Vector3(e.x, 0, e.y))
		_exits.append(c)
		# 地面標示用貼花（Decal）從上往下投在地上：撤離區沒整平（高低差可到 10 公尺），平板會一半埋進坡裡、一半浮在空中。
		# 圓形：裡面淡淡一層暖金，邊上一圈比較亮，站在圈外也看得出邊界
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.88, 0.95, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var d := Decal.new()
		d.texture_albedo = tex
		d.modulate = Color(0.95, 0.78, 0.4)   # 暖金：看得出來，又不像貼上去的藍色佔位片
		d.size = Vector3(EXIT_RADIUS * 2.0, Terrain.AMP * 3.0, EXIT_RADIUS * 2.0)   # 上下各投 15 公尺，坡再陡也蓋得到
		d.position = c
		$Arena.add_child(d)
		_exit_pads.append(d)
		_exit_pipe(c)   # 旁邊的篷車和貨在擺設清單裡（_generate_level）

## 撤離點中間的綠色水管：遠遠就看得到撤離點在哪（0.8.1 回饋 U14）。
## ponytail: 佔位用的，之後換正式的撤離標的物模型。有碰撞，不然會變成看得到摸不到的東西
func _exit_pipe(c: Vector3) -> void:
	const R := 1.2
	const H := 6.0   # 比柵欄、乾草高很多，隔著小丘也看得到管口
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.62, 0.22)
	mat.roughness = 0.6
	for part: Array in [[R, H, H * 0.5], [R + 0.25, 0.8, H - 0.4]]:   # [半徑, 高, 中心高]：管身＋頂上一圈管口
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = part[1]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = c + Vector3(0, part[2], 0)
		mi.add_to_group(&"exit_pipe")
		$Arena.add_child(mi)
	_solid_cyl(c + Vector3(0, H * 0.5, 0), R + 0.25, H)

## 找一個不在建築物裡面的出生點
func _spawn_point(span := ARENA * 0.45) -> Vector3:
	for i in 80:
		var p := Vector2(randf_range(-span, span), randf_range(-span, span))
		if _is_clear(p):
			return _on_ground(Vector3(p.x, 5.0, p.y))
	# 建築只蓋在中間，外圍一定是空的
	var edge := ARENA * 0.46
	var corner := Vector2(edge, edge).rotated(randf() * TAU)
	return _on_ground(Vector3(corner.x, 5.0, corner.y))

func _is_clear(p: Vector2, radius := 0.0) -> bool:   # radius：東西本身的半寬
	for r: Rect2 in _blocked:
		if r.grow(radius).has_point(p):
			return false
	return true

## 只有碰撞、沒有外觀：外觀由 Blender 的模型負責
func _solid_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _body(pos, shape)

func _solid_cyl(pos: Vector3, r: float, h: float) -> StaticBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	return _body(pos, shape)

func _body(pos: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	$Arena.add_child(body)
	return body

# --- 雜項 ---

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
