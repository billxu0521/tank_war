extends Node3D
## 西部牛仔打恐龍 — 區網原型。兩個模式：連線模式（大家都是牛仔，第一人稱）和沙盒模式。
## Esc 選單裡的「遊戲局控制」讓主機加移動標靶、牛仔 bot。恐龍的程式都還在，玩法定了再接回來。

const PORT := 24680
## 測試站：雲端主機上一直開著的專用伺服器（`-- --server`，見 README 的「測試站」）。
## 還沒架好就空著，大廳的「連到測試站」按鈕會關掉
const TEST_SERVER := ""
const NEXT_ROUND_DELAY := 10.0   # 專用伺服器一局結束後隔幾秒開下一局
const ARENA := 192.0        # 場地邊長（原本 320，縮 40%：交火更密集）
const SPAWN_CLEARANCE := 7.0  # 出生點離建築至少這麼遠
const FARM_GRID := 4          # 鄉村：4x4 塊地，每塊隨機是農莊／果園／麥田／牧場
const FARM_CELL := 44.0
const FENCE_H := 1.0          # 柵欄高度，要在牛仔的翻越範圍（0.4~1.5）內
const BUILDING_MAX_H := 22.0  # 最高的東西（筒倉＋圓頂約 20、穀倉屋脊約 16）不能超過這個
# 沙盒的靶場：從 (0, 84) 往 -Z 打到 100 公尺，這一條不蓋東西。撤離區在東西兩端，不會壓到
const SANDBOX_RANGE := Rect2(-20, -25, 40, 115)   # 靶在路兩側 4 公尺、恐龍靶 12 公尺；再窄旁邊的坡會超過 40 度
const SANDBOX_START := Vector3(0, 0.1, 84)   # y 是離地高度，用 _on_ground() 換成實際位置
const SANDBOX_TARGETS := [10, 25, 50, 100]   # 牛仔靶的距離（公尺）：左輪、散彈、步槍各自的有效距離
const GRASS := Color(0.49, 0.34, 0.21)   # 乾草原：黃昏裡偏紅的枯黃
const DIRT := Color(0.52, 0.39, 0.27)    # 沙土路，比草地亮
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
const TREE_KINDS := {&"TreeOakS": [0.17, 1.4], &"TreeOakM": [0.41, 1.8], &"TreeOak": [0.55, 2.4]}
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

var _props := {}   # 物件名 -> Mesh，從 props.glb 拿出來共用
var _terrain: Terrain
var _houses_built := 0   # 第幾棟農舍：三種輪流蓋（不用亂數，後面擺的東西位置才不會跟著變）
var _doors: Array[Door] = []   # 晚加入的人連進來時，把開著的門補送給他
var _wheat_fields: Array[Rect2] = []   # 地形上色要知道哪裡是麥田
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

func _ready() -> void:
	_flatten_models()
	_use_cjk_font()
	_ips = _local_ips()
	_load_saved_ips()
	_load_settings()
	saved_ips.get_popup().index_pressed.connect(func(i: int) -> void:
		ip_edit.text = saved_ips.get_popup().get_item_text(i))
	_use_sky()
	_use_outline()
	_load_props()
	_skin_egg()
	_build_arena()
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
##   TankWar.exe -- --host
##   TankWar.exe -- --join 192.168.1.5
##   TankWar.exe -- --sandbox
##   TankWar.exe -- --viewer
##   godot --headless -- --server    專用伺服器（測試站）：自己不下場，一局結束自動開下一局
func _autostart() -> void:
	var args := OS.get_cmdline_user_args()
	var test_btn: Button = $UI/Root/Lobby/TestServerBtn
	test_btn.disabled = TEST_SERVER == ""
	if test_btn.disabled:
		test_btn.text = "連到測試站（還沒架好）"
	if args.has("--server"):
		_start_dedicated()
	elif args.has("--host"):
		_on_host_pressed()
	elif args.has("--sandbox"):
		_on_sandbox_pressed()
	elif args.has("--viewer"):
		_on_viewer_pressed()
	else:
		var i := args.find("--join")
		if i >= 0 and i + 1 < args.size():
			ip_edit.text = args[i + 1]
			_on_join_pressed()

func _unhandled_input(e: InputEvent) -> void:
	if lobby.visible:
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_set_menu(not menu.visible)
	elif e is InputEventMouseButton and e.pressed and not menu.visible and not result.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # 點畫面重新鎖回滑鼠

# --- 暫停選單 ---

func _set_menu(open: bool) -> void:
	menu.visible = open
	# 遊戲局控制只有主機（和沙盒）能用：bot 都在主機上跑
	$UI/Root/Menu/Box/Controller.visible = multiplayer.is_server()
	if open:
		_fill_weapon_info()
		_show_cursor()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

# --- 連線 ---

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT) != OK:
		status.text = "開房失敗，連接埠 %d 可能被占用" % PORT
		return
	multiplayer.multiplayer_peer = peer
	_enter_game("連線模式：大家都是牛仔。等人加入…  本機 IP：" + _local_ips())
	_spawn(1)
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
	_enter_game("專用伺服器")
	spawn_boss()
	print("測試站開好了，連接埠 %d（UDP）" % PORT)

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

## 沙盒：一個人在靶場練槍。前方 10／25／50／100 公尺各站一個牛仔靶，
## 旁邊一隻不會動的恐龍。靶不是 bot、也不是本機操控，所以站著不動、不會還擊。
func _on_sandbox_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_sandbox = true
	egg.visible = false
	_enter_game("沙盒模式：沒有時間限制、子彈無限。靶打死會在原地重生。Esc 回大廳")
	var me := _add_player(COWBOY, 1)   # 編號 1 才操控得動
	me.global_position = _on_ground(SANDBOX_START)
	for w in me.viewmodel._weapons:
		w.reserve = -1
	me.viewmodel._refresh_ammo()
	var id := 3
	for dist in SANDBOX_TARGETS:
		var t := _add_player(COWBOY, id)
		t.global_position = _on_ground(SANDBOX_START + Vector3(-4 if id % 2 else 4, 0, -dist))
		t.rotation.y = PI   # 面對玩家，打頭才對得到臉
		_sign(t.global_position + Vector3(0, 2.6, 0), "%d m" % dist)
		id += 1
	var dino := _add_player(DINO, 2)
	dino.global_position = _on_ground(SANDBOX_START + Vector3(12, 4.0, -45))
	dino.rotation.y = 0.4
	_sign(dino.global_position + Vector3(0, 6.5, 0), "恐龍 45 m")
	# 翻越練習：一段柵欄、兩個乾草捲，就在出生點旁邊
	for prop in [_fence(SANDBOX_START + Vector3(-10, -0.1, -4), 6.0, true),
			_hay_bale(SANDBOX_START + Vector3(9, -0.1, -6), 0.0),
			_hay_bale(SANDBOX_START + Vector3(9, -0.1, -9), 0.0)]:
		prop.add_to_group(&"sandbox_prop")

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

## 選單的「瞄準：按一下切換」：關掉是按住右鍵才舉槍
func _on_aim_toggle_toggled(on: bool) -> void:
	Viewmodel.aim_toggle = on
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("controls", "aim_toggle", on)
	cfg.save(settings_path)

func _on_dino_attack_toggled(on: bool) -> void:
	dino_attacks = on

func _on_add_boss_pressed() -> void:
	spawn_boss()

## 恐龍 boss（boss.gd）：生在蛋旁邊守著。場上已經有就不再生。
## 沙盒裡蛋藏起來了，改生在玩家前方 40 公尺，方便測試
func spawn_boss() -> Node3D:
	if not multiplayer.is_server() or players.has_node(NodePath(str(BOSS_ID))):
		return null
	var b := _add_player(BOSS, BOSS_ID)
	var at := egg.global_position + Vector3(10, 0, 0)
	var me := players.get_node_or_null(^"1") as Node3D
	if _sandbox and me:
		at = me.global_position - me.global_basis.z * 40.0
	b.global_position = _on_ground(Vector3(at.x, 4.2, at.z))
	return b

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
	v.closed.connect(func() -> void:
		v.queue_free()
		visible = true
		$UI.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	get_tree().root.add_child(v)
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
	lobby.hide()
	menu.hide()
	status.text = msg
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- 生怪 / 勝負 ---

func _spawn(id: int) -> void:
	if not multiplayer.is_server():
		return  # 只有主機生，MultiplayerSpawner 會同步給大家
	_add_player(COWBOY, id)
	if id != 1:
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
	return p

func _despawn(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := players.get_node_or_null(NodePath(str(id)))
	if p:
		p.queue_free()
		if id != 1:
			_cowboys -= 1

## 無限重生，不設命數。死亡的代價是節奏——等重生，而且蛋會掉在原地被別人撿走。
## 勝負只有兩種：有人帶蛋撤離（那個人贏），或時間到（恐龍贏）。
## 「打死恐龍」不算贏，不然三個牛仔會理性地先聯手弄死恐龍，跟互相競爭矛盾。
func _on_died(killer: Node, who: Node) -> void:
	if _over:
		return
	var as_dino := who.is_in_group(&"dino")
	if not as_dino:
		_cowboys -= 1
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
		if r["pos"] != Vector3.INF:
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
	if _dedicated and _over:
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
	_egg_step(delta)

	_time_left -= delta
	if int(_time_left) != _clock:
		_clock = int(_time_left)
		_set_clock.rpc(_clock)
	if _time_left <= 0.0:
		_over = true
		_next_round = NEXT_ROUND_DELAY
		_finish.rpc("時間到，沒有人把蛋帶走")

## 專用伺服器開下一局：時間和蛋歸位，每個牛仔重生（刪掉重生，客戶端的位置才會跟著換），boss 回蛋旁邊
func _new_round() -> void:
	_over = false
	_enter_game("專用伺服器" if _dedicated else "新的一局")
	egg.extract = 0.0
	_cowboys = 0
	for p in players.get_children():
		if p.is_in_group(&"boss"):
			p.global_position = _on_ground(egg.global_position + Vector3(10, 4.2 - egg.global_position.y, 0))
			p.hp = p.max_hp
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
	_announce.rpc("新的一局開始！")

@rpc("authority", "call_local", "reliable")
func _announce(msg: String) -> void:
	status.text = msg
	result.hide()
	_had_me = false
	if not lobby.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

func _process(_delta: float) -> void:
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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_center_info(me)
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
	if _sandbox:
		hud.text = "沙盒    我的血量：%s    恐龍靶血量：%s" % [mine, dino.hp if dino else "重生中"]
		return
	hud.text = "⏱ %d:%02d    我的血量：%s    %s存活牛仔：%d    蛋：%s" % [
		maxi(_clock, 0) / 60, maxi(_clock, 0) % 60,
		mine,
		("恐龍血量：%d    " % dino.hp) if dino else "",
		players.get_child_count() - (1 if dino else 0),
		egg_state]

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
	elif me == null and _dead_ms >= 0:
		t = "%d 秒後重生" % maxi(1, ceili(RESPAWN_DELAY - (now - _dead_ms) / 1000.0))
	elif egg.extract > 0.0:
		var who := "你" if egg.carrier == multiplayer.get_unique_id() else "牛仔 %d" % egg.carrier
		t = "%s撤離中：還剩 %.1f 秒" % [who, maxf(EXTRACT_SECONDS - egg.extract, 0.0)]
	elif egg.pickup > 0.0:
		t = "有人在撿蛋：還剩 %.1f 秒" % maxf(PICKUP_SECONDS - egg.pickup, 0.0)
	center_info.text = t

## 右上角：本機 IP（開房的人報給朋友用）、連線延遲、每秒畫面數
func _update_net_info() -> void:
	var parts: Array[String] = ["本機 IP：" + _ips]
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not lobby.visible and peer and not multiplayer.is_server() \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := peer.get_peer(1)
		if p:
			parts.append("延遲 %d ms" % p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	if not lobby.visible:
		parts.append("%d FPS" % Engine.get_frames_per_second())
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
	# ponytail: 固定 seed 的亂數，每台機器蓋出來的場景才會完全一樣（場地沒有走網路同步）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	_terrain = Terrain.new(ARENA, 20260927)

	# 第一輪：先決定每一格是什麼，要平地的先整平（建築、撤離區、靶場）。
	# 地形要在擺任何東西之前定案，所以擺東西留到第二輪
	_terrain.flatten_rect(SANDBOX_RANGE)
	for e: Vector2 in _exit_spots():
		_terrain.flatten_circle(e, EXIT_RADIUS + 5.0)
	var half := (FARM_GRID - 1) * 0.5
	var cells: Array[Array] = []
	for gx in FARM_GRID:
		for gz in FARM_GRID:
			var c := Vector3((gx - half) * FARM_CELL, 0, (gz - half) * FARM_CELL)
			c += Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))   # 塊變小了，晃太多會撞到隔壁
			var kind := rng.randi() % 4
			if cells.is_empty():
				kind = 0   # 第一格一定是農莊：_blocked[0] 要是一棟擋得住視線的穀倉（測試靠它）
			cells.append([c, kind])
			match kind:
				0: _terrain.flatten_circle(Vector2(c.x, c.z), 30.0)       # 農莊整塊平地
				2:
					if _free(c, 20):
						_wheat_fields.append(Rect2(c.x - 20, c.z - 20, 40, 40))
				3:
					_terrain.flatten_circle(Vector2(c.x, c.z + 22), 12.0)  # 牧場的小棚
					_terrain.flatten_circle(Vector2(c.x, c.z - 20), 12.0)  # 牧場的農舍（台階前面也要平）
	_terrain.settle()   # 靠太近的平地把高度拉近，中間才不會擠出陡坡
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
	var inner := ARENA * 0.5
	$Arena.add_child(FarLand.build(_terrain, _ground_color, [_props[&"TreeOakM"], _props[&"TreeOakS"], _props[&"Bush"]],
		_props[&"FenceRail"], FENCE_SEG))

	# 第二輪：把東西擺上去。每個擺東西的函式自己問地形高度
	for cell in cells:
		var c: Vector3 = cell[0]
		match cell[1]:
			0: _farmstead(c, rng)
			1: _orchard(c, rng)
			2: _hayfield(c, rng)
			3: _pasture(c, rng)

	# 沿著場邊種一圈樹
	var edge := ARENA * 0.5 - 6.0
	for i in 40:
		var t := float(i) / 40.0 * 4.0
		var side := int(t)
		var u := (t - side) * ARENA - ARENA * 0.5
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u),
			Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		if _free(p, 2) and _is_clear(Vector2(p.x, p.z)):   # 地圖小了，邊緣就是農莊和靶場
			_tree(p, rng, 0.4)

	# 空地補東西：塊跟塊之間本來是一大片空草地，補上零星的樹和乾草捲，走到哪都有東西可以躲
	for i in 110:
		var p := Vector3(rng.randf_range(-inner + 12, inner - 12), 0, rng.randf_range(-inner + 12, inner - 12))
		if absf(p.x) < 7.0 or absf(p.z) < 7.0 or not _free(p, 6) or not _is_clear(Vector2(p.x, p.z)) \
				or _in_wheat(p):
			continue
		if rng.randf() < 0.6:
			_tree(p, rng, 0.3)
		else:
			_hay_bale(p, rng.randf() * PI)
			_block(p, Vector2(1.5, 1.5), 1.0)

	# 灌木叢：兩三叢一群，蹲進去就看不到人。只擋視線不擋子彈，也沒碰撞（跟 Hunt 一樣）。
	# 用自己的亂數，灌木多一叢少一叢不會影響其他東西的位置
	var br := RandomNumberGenerator.new()
	br.seed = 13
	var bushes: Array[Transform3D] = []
	for i in 80:
		var c := Vector3(br.randf_range(-inner + 8, inner - 8), 0, br.randf_range(-inner + 8, inner - 8))
		for k in br.randi_range(2, 4):
			var p := c + Vector3(br.randf_range(-2.5, 2.5), 0, br.randf_range(-2.5, 2.5))
			if absf(p.x) < 6.0 or absf(p.z) < 6.0 or not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)) \
					or _in_wheat(p):
				continue
			var s := br.randf_range(0.75, 1.3)
			var at := _on_ground(p) + Vector3.DOWN * 0.15   # 埋一點，斜坡下坡那側才不會懸空
			bushes.append(Transform3D(Basis(Vector3.UP, br.randf() * TAU).scaled(Vector3(s, s * br.randf_range(0.85, 1.15), s)), at))
			_bushes.append(at)
	_scatter(&"Bush", bushes, true)
	_rocks(inner)

	# 草地：畫面用的，伺服器沒畫面就不長（測試會直接呼叫 _grass_field 檢查）
	if DisplayServer.get_name() != "headless":
		_grass_field()
		_drift = Fx.drift($Arena)

## 描線：一片蓋滿畫面的方塊，用 outline.gdshader 從深度和法線畫出輪廓和稜線。
## 放在場地底下，任何相機（玩家、檢視模式、截圖）都會畫到；剔除邊界拉很大，不會因為方塊不在視野裡被跳過
func _use_outline() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://outline.gdshader")
	quad.material = mat
	var mi := MeshInstance3D.new()
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
	for e: Vector3 in _exits:
		marks.append({"deg": Compass.bearing(at, e), "dist": at.distance_to(e),
			"color": Compass.EXIT_COLOR, "label": "撤離"})
	_compass.marks = marks
	_compass.queue_redraw()

## boss 的體力條（畫面上方中間，每個人都看得到）：看牠還跑不跑得動，決定現在要逃還是要躲。
## 跑不動（力竭）變紅、倒地變灰
var _boss_bar: ProgressBar
var _boss_label: Label
func _update_boss_bar(me: Node) -> void:
	var b := get_tree().get_first_node_in_group(&"boss")
	# 當牛仔時不顯示（0.8.1 回饋）。沙盒是測恐龍行為的地方，留著
	if not _sandbox and not (me != null and me.is_in_group(&"dino")):
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
func _rocks(inner: float) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = 21
	for i in 60:   # 空地：大石和石頭堆，當掩體
		var p := Vector3(rr.randf_range(-inner + 12, inner - 12), 0, rr.randf_range(-inner + 12, inner - 12))
		var kind: StringName = ROCK_COVER[rr.randi() % ROCK_COVER.size()]
		var s := rr.randf_range(0.45, 0.7) if kind in [&"Rock01", &"Rock02", &"Rock03", &"Rock04"] else rr.randf_range(0.8, 1.2)
		var yaw := rr.randf() * TAU
		if absf(p.x) < 7.0 or absf(p.z) < 7.0 or not _free(p, 5) or not _is_clear(Vector2(p.x, p.z)) or _in_wheat(p) \
				or _near_bush(p, _props.get(kind).get_aabb().size.x * s * 0.5 + 2.0):
			continue
		_rock(kind, p, s, yaw, true)
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
		if not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)):
			continue
		_rock(kind, p, s, yaw, false)

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
	var size := mesh.get_aabb().size * s
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
		_block(p, Vector2(size.x, size.z), 1.5)
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
			for r: Rect2 in _blocked:
				if r.intersects(area):
					near.append(r)
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			for i in per:
				var x := o.x + gr.randf_range(-half, half)
				var z := o.z + gr.randf_range(-half, half)
				var a := gr.randf() * TAU
				var s := gr.randf_range(0.7, 1.3)
				if absf(x) < 5.0 or absf(z) < 5.0:
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
	if absf(x) < 4.0 or absf(z) < 4.0:
		return DIRT
	for f: Rect2 in _wheat_fields:
		if f.has_point(Vector2(x, z)):
			return WHEAT
	var c := GRASS.lerp(Color(0.86, 0.71, 0.43), clampf((h + Terrain.AMP) / (Terrain.AMP * 2.0), 0.0, 1.0) * 0.55)
	return c.lerp(DIRT, clampf(_terrain.slope(x, z) * 5.0, 0.0, 0.7))

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
	for e: Vector2 in _exit_spots():
		out.append(Rect2(e.x - EXIT_RADIUS - 4, e.y - EXIT_RADIUS - 4, EXIT_RADIUS * 2 + 8, EXIT_RADIUS * 2 + 8))
	return out

## 兩個撤離區的中心：東西兩端（南北向那條路留給沙盒靶場）
func _exit_spots() -> Array[Vector2]:
	var d := ARENA * 0.5 - 22.0
	return [Vector2(d, 0), Vector2(-d, 0)]

## 農莊：穀倉＋農舍＋筒倉，外面一圈柵欄。穀倉是恐龍爬上去看全場的制高點
func _farmstead(c: Vector3, rng: RandomNumberGenerator) -> void:
	var barn := c + Vector3(-8, 0, -4)
	if _free(barn, 14):
		_barn(barn, Vector3(rng.randf_range(12, 16), rng.randf_range(7, 9), rng.randf_range(18, 24)))
	var house := c + Vector3(12, 0, 8)
	if _free(house, 8):
		_house(house)
	var silo := c + Vector3(4, 0, -16)
	if _free(silo, 4):
		_silo(silo, rng.randf_range(13, 18))
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
				_fence(c + p, r * 2.0 / 8.0, side % 2 == 1)

## 果園：整齊的樹，樹幹擋子彈、樹冠擋視線不擋子彈
func _orchard(c: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 5:
		for j in 5:
			var p := c + Vector3((i - 2) * 6.5, 0, (j - 2) * 6.5)
			if _free(p, 2) and rng.randf() > 0.15:
				_tree(p, rng)

## 麥田：黃色一片，散落乾草捲。開闊地，交火距離最遠的地方
func _hayfield(c: Vector3, rng: RandomNumberGenerator) -> void:
	if _free(c, 20):
		# 麥田的黃色畫在地形上（_ground_color）。一叢一叢的麥子，大約 80 公分高：蹲在裡面會被擋掉一部分。沒有碰撞，子彈照樣穿過去。
		# 用自己的亂數：麥子只是外觀，不該影響主亂數，不然後面的農莊位置會全部跟著變
		var wr := RandomNumberGenerator.new()
		wr.seed = int(c.x * 7919.0 + c.z)
		var pts: Array[Transform3D] = []
		for gx in 36:
			for gz in 36:
				var at := _on_ground(c + Vector3(-19.5 + gx * 1.1 + wr.randf_range(-0.4, 0.4), 0,
					-19.5 + gz * 1.1 + wr.randf_range(-0.4, 0.4)))
				pts.append(Transform3D(Basis(Vector3.UP, wr.randf() * TAU).scaled(Vector3.ONE * wr.randf_range(0.8, 1.2)), at))
		_scatter(&"WheatTuft", pts)
	for i in 7:
		var p := c + Vector3(rng.randf_range(-18, 18), 0, rng.randf_range(-18, 18))
		if _free(p, 2):
			_hay_bale(p, rng.randf() * PI)

## 牧場：柵欄隔成欄位＋一間小棚＋一棟農舍。翻越練習場
func _pasture(c: Vector3, rng: RandomNumberGenerator) -> void:
	var home := c + Vector3(0, 0, -20)       # 牧場主人的房子，先蓋：柵欄碰到它就不擺（不用亂數，後面擺的東西位置不變）
	if _free(home, 8):
		_house(home)
	for k in 5:
		var z := c.z + (k - 2) * 9.0
		for seg in 4:
			var p := Vector3(c.x - 15 + seg * 10.0, 0, z)
			if _free(p, 2) and rng.randf() > 0.2:
				_fence(p, 10.0, false)
	var shed := c + Vector3(rng.randf_range(-10, 10), 0, 22)
	if _free(shed, 6):
		_barn(shed, Vector3(8, 4, 6), 3.0)   # 小棚子＝縮小的穀倉

## 穀倉：空心的，進得去。牆（含門洞、窗洞）、閣樓、柱子、隔間的碰撞是 Blender 的 BarnCol，
## 屋頂碰撞是兩片斜板（看不見）。整棟照實際大小縮放，屋頂的寬和高用同一個倍率縮，斜度才跟碰撞一樣。
## 小棚子也用這個，只是小一號（閣樓 2 公尺、門 2.9 × 2.4，一樣進得去、爬得上去）。
func _barn(p: Vector3, size: Vector3, clearance := SPAWN_CLEARANCE) -> void:
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
	_block(p, Vector2(size.x, size.z), clearance)

## 農舍：空心的，進得去。三種外觀輪流（前廊農舍、圓木小屋、直板高屋），碰撞跟著外觀走
func _house(p: Vector3) -> void:
	var kind: StringName = HOUSE_KINDS.keys()[_houses_built % HOUSE_KINDS.size()]
	_houses_built += 1
	p = _on_ground(p)
	_solid_mesh(p, _props.get(StringName(kind + "Col")), Vector3.ONE)
	Fx.chimney($Arena, p + HOUSE_KINDS[kind])
	_prop(kind, p)
	# 前門：門軸在門洞左緣，往屋裡推開
	var d := _door(&"HouseDoor", p + Vector3(-0.55, HOUSE_FLOOR, 4.0 - HOUSE_T * 0.5),
		Vector3(1.1, 2.2, 0.08), Vector3(0.55, 0, 0), Vector3.ONE)
	d.swing = PI * 0.5
	_lamp(p + Vector3(-1.5, 2.6 + HOUSE_FLOOR, 1.8), 5.0)
	_block(p, Vector2(12, 13), SPAWN_CLEARANCE)   # 含前廊、煙囪、後面的小倉

func _silo(p: Vector3, h: float) -> void:
	p = _on_ground(p)
	_solid_cyl(p + Vector3(0, h * 0.5, 0), 3.0, h)
	_solid_cyl(p + Vector3(0, h + 0.8, 0), 1.6, 1.6)   # 圓頂中間站得住的地方（爬梯子上來就站這）
	# 外側的爬梯（模型本來就有）：F 爬到頂，全場最高的狙擊點，摔下來也必死
	_ladder(p + Vector3(3.25, 0, 0), h, p + Vector3(3.25 + 0.5, 0, 0), h,
		p + Vector3(0, h + 1.7, 0), PI * 0.5)
	_prop(&"SiloBody", p, Vector3(1, h / SILO_BASE_H, 1))
	_prop(&"SiloDome", p + Vector3(0, h, 0))
	_block(p, Vector2(6, 6), 3.0)

## 柵欄：碰撞是一整片 1 公尺高的板子——剛好在翻越範圍內。外觀是一段段 2.5 公尺的
## 木樁＋橫木排過去（長度不整除就每段稍微拉長），最後補一根收尾的木樁
func _fence(p: Vector3, length: float, along_z: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	# 兩端各自貼地，整段沿著坡度斜過去。p.y 是離地高度（沙盒的練習柵欄用）
	var dir := Vector3.BACK if along_z else Vector3.RIGHT
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

func _hay_bale(p: Vector3, yaw: float) -> StaticBody3D:
	# 圓捆躺著放：直徑 1.4 公尺，翻得過去也蹲得進後面。模型的軸是直的，跟著碰撞圓柱一起放倒
	var body := _solid_cyl(_on_ground(p) + Vector3(0, 0.7, 0), 0.7, 1.3)
	body.rotation = Vector3(0, yaw, PI * 0.5)
	body.add_to_group(&"soft")   # 從屋頂跳下來落在乾草上，摔落傷害減半
	_prop(&"HayBale", Vector3.ZERO, Vector3.ONE, body)
	return body

## 樹：只有樹幹有碰撞，擋子彈；樹冠擋視線不擋子彈，躲在樹下只是比較難被看到。
## pine_chance：林子邊緣混一點松樹，果園只種闊葉樹
func _tree(p: Vector3, rng: RandomNumberGenerator, pine_chance := 0.0) -> void:
	var h := rng.randf_range(4.0, 6.0)
	p = _on_ground(p) + Vector3.DOWN * 0.3   # 往下埋一點：斜坡上樹根的下坡那側才不會懸空
	var mi: MeshInstance3D
	if rng.randf() < pine_chance:
		_solid_cyl(p + Vector3(0, h * 0.5, 0), 0.35, h)
		mi = _prop(&"TreePine", p, Vector3.ONE * (h / TREE_BASE_TRUNK))
	else:
		# 闊葉樹：同一個亂數 h 決定大中小（小 25%、中 40%、大 35%）和 ±10% 的縮放，
		# 亂數用量跟以前一樣，後面擺的東西位置不會跟著變
		var t := (h - 4.0) / 2.0
		var kind: StringName = &"TreeOakS" if t < 0.25 else (&"TreeOakM" if t < 0.65 else &"TreeOak")
		var s := 0.9 + 0.2 * fmod(t * 7.0, 1.0)
		var trunk: Array = TREE_KINDS[kind]
		_solid_cyl(p + Vector3(0, trunk[1] * s * 0.5, 0), trunk[0] * s, trunk[1] * s)
		mi = _prop(kind, p, Vector3.ONE * s)
	mi.rotation.y = rng.randf() * TAU   # 每棵轉個角度，一整排才不會長得一模一樣
	_block(p, Vector2(1, 1), 1.5)

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
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _props.get(name)
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
	for glb: PackedScene in [PROPS, TREES, ROCKS, HOUSES]:
		var src := glb.instantiate()
		for c in src.get_children():
			if c is MeshInstance3D:
				_props[StringName(c.name)] = c.mesh
		src.free()

## 樹的材質不要高光：朝太陽的面疊一層白色反光，會把葉子受光面的黃沖成灰，折面的明暗差就被吃掉。
## Blender 那邊設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 全部模型都不要高光：朝太陽的面疊一層反光會把顏色沖灰、反射粉色的天空（牆和門廊泛粉紫）。
## Blender 設了 Specular 0，但 glTF 匯進來 Godot 還是預設 0.5，要在這裡補。
## 網格被資源快取住，改一次之後各處 instantiate 出來的都是改好的那份（glb 要留著，快取才不會被丟掉）
const FLAT_MODELS := ["res://models/props.glb", "res://models/trees.glb", "res://models/rocks.glb", "res://models/houses.glb",
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
	for e: Vector2 in _exit_spots():
		var c := _on_ground(Vector3(e.x, 0, e.y))
		_exits.append(c)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(EXIT_RADIUS * 2.0, 0.3, EXIT_RADIUS * 2.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.78, 0.4, 0.25)   # 半透明暖金：看得出來，又不像貼上去的藍色佔位片
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = c + Vector3(0, 0.15, 0)
		$Arena.add_child(mi)
		_exit_pipe(c)
		# 撤離點旁邊停一台篷車：遠遠就認得出「從這裡走」
		_prop(&"Wagon", _on_ground(c * Vector3(1, 0, 1) + Vector3(0, 0, EXIT_RADIUS + 3.0))).rotation.y = 0.4

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

func _is_clear(p: Vector2) -> bool:
	for r: Rect2 in _blocked:
		if r.has_point(p):
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
