extends Node3D
## 西部牛仔打恐龍 — 區網原型。兩個模式：連線模式（大家都是牛仔，第一人稱）和沙盒模式。
## Esc 選單裡的「遊戲局控制」讓主機加移動標靶、牛仔 bot。恐龍的程式都還在，玩法定了再接回來。

const PORT := 24680
const ARENA := 320.0        # 場地邊長
const SPAWN_CLEARANCE := 7.0  # 出生點離建築至少這麼遠
const FARM_GRID := 5          # 鄉村：5x5 塊地，每塊隨機是農莊／果園／麥田／牧場
const FARM_CELL := 60.0
const FENCE_H := 1.0          # 柵欄高度，要在牛仔的翻越範圍（0.4~1.5）內
const BUILDING_MAX_H := 22.0  # 最高的東西（筒倉＋圓頂約 20、穀倉屋脊約 16）不能超過這個
# 沙盒的靶場：從 (0, 110) 往 -Z 打，這一條不蓋東西。起點要在撤離區（z=138）外面
const SANDBOX_RANGE := Rect2(-25, -5, 50, 125)
const SANDBOX_START := Vector3(0, 0.1, 110)   # y 是離地高度，用 _on_ground() 換成實際位置
const SANDBOX_TARGETS := [10, 25, 50, 100]   # 牛仔靶的距離（公尺）：左輪、散彈、步槍各自的有效距離
const GRASS := Color(0.40, 0.44, 0.24)
const DIRT := Color(0.45, 0.36, 0.24)
const WHEAT := Color(0.78, 0.66, 0.34)
# 場景物件的模型（blender/props.py）。這幾個基準尺寸跟那邊共用，改一邊要改另一邊
const PROPS := preload("res://models/props.glb")
const BARN_BASE := Vector3(14, 8, 20)   # 穀倉模型的寬、牆高、長
const BARN_PITCH := 0.55
const SILO_BASE_H := 15.0
const FENCE_SEG := 2.5
const TREE_BASE_TRUNK := 5.0
# 門和梯子的位置（blender/props.py 的同名常數，改一邊要改另一邊）
const BARN_T := 0.25
const BARN_DOOR_W := 5.0
const BARN_DOOR_H := 4.8
const BARN_BACK_X := 4.0
const BARN_LOFT := 4.0
const BARN_LADDER_X := -2.5
const HOUSE_T := 0.2
const CLIFF_W := 40.0
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

@onready var lobby: VBoxContainer = $UI/Root/Lobby
@onready var ip_edit: LineEdit = $UI/Root/Lobby/IP
@onready var status: Label = $UI/Root/Status
@onready var hud: Label = $UI/Root/Hud
@onready var stamina_bar: ProgressBar = $UI/Root/Stamina
@onready var crosshair: Label = $UI/Root/Crosshair
@onready var menu: Control = $UI/Root/Menu
@onready var players: Node3D = $Players
@onready var egg: Egg = $Egg

var _props := {}   # 物件名 -> Mesh，從 props.glb 拿出來共用
var _terrain: Terrain
var _doors: Array[Door] = []   # 晚加入的人連進來時，把開著的門補送給他
var _wheat_fields: Array[Rect2] = []   # 地形上色要知道哪裡是麥田
var _blocked: Array[Rect2] = []  # 建築物在 XZ 平面佔的範圍
var _exits: Array[Vector3] = []  # 四個撤離區的中心
var _cowboys := 0
var _offline := false
var _time_left := 0.0
var _clock := 0                     # 主機廣播的剩餘秒數
var _respawn_queue: Array[Dictionary] = []
var _claimer := 0   # 正在撿蛋的牛仔編號
var _over := false
## 沙盒：沒有時間限制、沒有蛋，靶打死會在原地重生，子彈無限
var _sandbox := false

func _ready() -> void:
	_use_cjk_font()
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
func _autostart() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--host"):
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
	elif e is InputEventMouseButton and e.pressed and not menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # 點畫面重新鎖回滑鼠

# --- 暫停選單 ---

func _set_menu(open: bool) -> void:
	menu.visible = open
	# 遊戲局控制只有主機（和沙盒）能用：bot 都在主機上跑
	$UI/Root/Menu/Box/Controller.visible = multiplayer.is_server()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

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
	crosshair.hide()
	stamina_bar.hide()
	lobby.show()
	hud.text = ""
	status.text = msg
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- 連線 ---

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT) != OK:
		status.text = "開房失敗，連接埠 %d 可能被占用" % PORT
		return
	multiplayer.multiplayer_peer = peer
	_enter_game("連線模式：大家都是牛仔。等人加入…  本機 IP：" + _local_ips())
	_spawn(1)

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
		if Fighter.is_bot_id(p.name.to_int()):
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

@rpc("authority", "call_local", "reliable")
func _finish(msg: String) -> void:
	status.text = msg + "  （按 Esc 放開滑鼠）"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
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
		_finish.rpc("時間到，沒有人把蛋帶走")

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
			_finish_egg.rpc(egg.carrier)
			return
	else:
		egg.extract = 0.0

func _process(_delta: float) -> void:
	# 連線還沒建立好就問 id 會噴錯
	if lobby.visible or multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var me := players.get_node_or_null(NodePath(str(multiplayer.get_unique_id())))
	var dino := get_tree().get_first_node_in_group(&"dino")
	_update_crosshair(me)
	stamina_bar.visible = me != null and me == dino
	if stamina_bar.visible:
		stamina_bar.value = me.stamina
		stamina_bar.modulate = Color(1, 0.35, 0.3) if me.exhausted else Color.WHITE
	var egg_state := "無人持有"
	if egg.carrier == multiplayer.get_unique_id():
		egg_state = "在你身上！帶去藍色撤離區"
	elif egg.carrier != 0:
		egg_state = "被牛仔 %d 拿走了" % egg.carrier
	if egg.pickup > 0.0:
		egg_state += "　撿取中 %.1f/%.0f 秒" % [egg.pickup, PICKUP_SECONDS]
	if egg.extract > 0.0:
		egg_state += "　撤離中 %.1f/%.0f 秒" % [egg.extract, EXTRACT_SECONDS]
	var mine := "陣亡"
	if me != null:
		mine = str(me.hp)
	elif _respawn_seconds_for(multiplayer.get_unique_id()) > 0:
		mine = "重生中 %d 秒" % _respawn_seconds_for(multiplayer.get_unique_id())
	if _sandbox:
		hud.text = "沙盒    我的血量：%s    恐龍靶血量：%s" % [mine, dino.hp if dino else "重生中"]
		return
	hud.text = "⏱ %d:%02d    我的血量：%s    %s存活牛仔：%d    蛋：%s" % [
		maxi(_clock, 0) / 60, maxi(_clock, 0) % 60,
		mine,
		("恐龍血量：%d    " % dino.hp) if dino else "",
		players.get_child_count() - (1 if dino else 0),
		egg_state]

func _dist_to_exit(p: Vector3) -> float:
	var best := 9999.0
	for e: Vector3 in _exits:
		best = minf(best, Vector2(p.x - e.x, p.z - e.z).length())
	return best

## 還要幾秒才重生（只有主機知道，客戶端看到的是 0）
func _respawn_seconds_for(id: int) -> int:
	for r: Dictionary in _respawn_queue:
		if int(r["id"]) == id:
			return maxi(0, ceili(_time_left - float(r["at"])))
	return 0

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
	var d := ARENA * 0.5 - 22.0
	for ez in [d, -d]:
		_terrain.flatten_circle(Vector2(0, ez), EXIT_RADIUS + 5.0)
	var half := (FARM_GRID - 1) * 0.5
	var cells: Array[Array] = []
	for gx in FARM_GRID:
		for gz in FARM_GRID:
			var c := Vector3((gx - half) * FARM_CELL, 0, (gz - half) * FARM_CELL)
			c += Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			var kind := rng.randi() % 4
			if cells.is_empty():
				kind = 0   # 第一格一定是農莊：_blocked[0] 要是一棟擋得住視線的穀倉（測試靠它）
			cells.append([c, kind])
			match kind:
				0: _terrain.flatten_circle(Vector2(c.x, c.z), 30.0)       # 農莊整塊平地
				2:
					if _free(c, 20):
						_wheat_fields.append(Rect2(c.x - 20, c.z - 20, 40, 40))
				3: _terrain.flatten_circle(Vector2(c.x, c.z + 22), 12.0)  # 牧場的小棚
	_terrain.settle()   # 靠太近的平地把高度拉近，中間才不會擠出陡坡
	$Arena.add_child(_terrain.build(_ground_color))

	# 四周圍牆，東西才不會掉出場外。內側牆面剛好貼齊地板邊緣，不留縫。
	# 碰撞是平的牆（看不見），外觀是一段段山崖（blender/props.py 的 Cliff），
	# 岩塊都長在牆面外側，不會凸進場地變成看得到摸不到的東西
	var e := (ARENA + WALL_T) * 0.5
	var long := ARENA + WALL_T * 2.0
	for w: Array in [[Vector3(0, WALL_H * 0.5, e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(0, WALL_H * 0.5, -e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)],
			[Vector3(-e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)]]:
		_solid_box(w[0], w[1]).add_to_group(&"arena_wall")
	var inner := ARENA * 0.5
	var segs := 9
	var seg := long / segs
	# [這一面的起點, 沿著牆往哪走, 模型要轉多少才讓岩塊長在牆外]
	for side: Array in [[Vector3(-long * 0.5, 0, -inner), Vector3.RIGHT, 0.0],
			[Vector3(-long * 0.5, 0, inner), Vector3.RIGHT, PI],
			[Vector3(inner, 0, -long * 0.5), Vector3.BACK, -PI * 0.5],
			[Vector3(-inner, 0, -long * 0.5), Vector3.BACK, PI * 0.5]]:
		for i in segs:
			var mi := _prop(&"Cliff", side[0] + side[1] * seg * (i + 0.5), Vector3(seg / CLIFF_W, 1, 1))
			mi.rotation.y = side[2]

	# 第二輪：把東西擺上去。每個擺東西的函式自己問地形高度
	for cell in cells:
		var c: Vector3 = cell[0]
		match cell[1]:
			0: _farmstead(c, rng)
			1: _orchard(c, rng)
			2: _hayfield(c, rng)
			3: _pasture(c, rng)

	# 沿著圍牆種一圈樹，把牆藏在林子後面
	var edge := ARENA * 0.5 - 6.0
	for i in 64:
		var t := float(i) / 64.0 * 4.0
		var side := int(t)
		var u := (t - side) * ARENA - ARENA * 0.5
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u),
			Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		_tree(p, rng, 0.4)

	# 草叢撒滿整片地，路上和建築周圍不長。一樣用自己的亂數
	var gr := RandomNumberGenerator.new()
	gr.seed = 7
	var grass: Array[Transform3D] = []
	while grass.size() < 3000:
		var at := Vector3(gr.randf_range(-inner, inner), 0, gr.randf_range(-inner, inner))
		if absf(at.x) < 5.0 or absf(at.z) < 5.0:
			continue
		if not _is_clear(Vector2(at.x, at.z)):
			continue   # 建築周圍不長（院子踩禿了），更不能長進屋裡
		at.y = _terrain.height(at.x, at.z)
		grass.append(Transform3D(Basis(Vector3.UP, gr.randf() * TAU).scaled(Vector3.ONE * gr.randf_range(0.7, 1.5)), at))
	_scatter(&"GrassClump", grass)

## 地面顏色直接畫在地形頂點上：泥土路跟著地形起伏、麥田是黃的、
## 坡頂偏乾黃、山谷偏深綠、陡坡露土、農莊的院子踩出一片泥地
func _ground_color(x: float, z: float, h: float) -> Color:
	if absf(x) < 4.0 or absf(z) < 4.0:
		return DIRT
	for f: Rect2 in _wheat_fields:
		if f.has_point(Vector2(x, z)):
			return WHEAT
	var c := GRASS.lerp(Color(0.55, 0.52, 0.30), clampf((h + Terrain.AMP) / (Terrain.AMP * 2.0), 0.0, 1.0) * 0.55)
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
	var d := ARENA * 0.5 - 22.0
	return [SANDBOX_RANGE,
		Rect2(-EXIT_RADIUS - 4, d - EXIT_RADIUS - 4, EXIT_RADIUS * 2 + 8, EXIT_RADIUS * 2 + 8),
		Rect2(-EXIT_RADIUS - 4, -d - EXIT_RADIUS - 4, EXIT_RADIUS * 2 + 8, EXIT_RADIUS * 2 + 8)]

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
			var p := c + Vector3((i - 2) * 8.0, 0, (j - 2) * 8.0)
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

## 牧場：柵欄隔成欄位＋一間小棚。翻越練習場
func _pasture(c: Vector3, rng: RandomNumberGenerator) -> void:
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
	var back := _door(&"BarnBackDoor", p + Vector3((BARN_BACK_X - 0.6) * s.x, 0, -(BARN_BASE.z * 0.5 - BARN_T * 0.5) * s.z),
		Vector3(1.2, 2.2, 0.08), Vector3(0.6, 0, 0), Vector3(s.x, s.y, 1))
	back.swing = -PI * 0.5
	# 閣樓的梯子：靠在閣樓邊緣（z=0），人站在梯子前面（+Z 那側）面向 -Z 爬
	var loft := BARN_LOFT * s.y
	var lx := BARN_LADDER_X * s.x
	_ladder(p + Vector3(lx, 0, 0.15 * s.z), loft + 1.0, p + Vector3(lx, 0, 0.15 * s.z + 0.5), loft,
		p + Vector3(lx, loft + 0.1, -1.0 * s.z), 0.0)
	_lamp(p + Vector3(0, loft - 1.0, 3.0 * s.z), 7.0 * s.x)
	_block(p, Vector2(size.x, size.z), clearance)

func _house(p: Vector3) -> void:
	var size := Vector3(10, 5, 8)   # 跟 blender/props.py 的 HOUSE 一樣
	p = _on_ground(p)
	_solid_mesh(p, _props.get(&"HouseCol"), Vector3.ONE)   # 空心：牆、隔間、窗洞、大件家具
	_roof(p, size, 0.5)
	_solid_box(p + Vector3(3, size.y + 2.5, 0), Vector3(0.9, 3.0, 0.9))   # 煙囪
	_prop(&"House", p)
	# 前門：門軸在門洞左緣，往屋裡推開
	var d := _door(&"HouseDoor", p + Vector3(-0.55, 0, size.z * 0.5 - HOUSE_T * 0.5),
		Vector3(1.1, 2.2, 0.08), Vector3(0.55, 0, 0), Vector3.ONE)
	d.swing = PI * 0.5
	_lamp(p + Vector3(-1.5, 2.6, 1.8), 5.0)
	_block(p, Vector2(size.x, size.z), SPAWN_CLEARANCE)

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
	_solid_cyl(p + Vector3(0, h * 0.5, 0), 0.35, h)
	var mi := _prop(&"TreePine" if rng.randf() < pine_chance else &"TreeOak", p, Vector3.ONE * (h / TREE_BASE_TRUNK))
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
	light.light_energy = 1.4
	light.omni_range = reach
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
func _scatter(name: StringName, pts: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _props.get(name)
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
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

## 從 props.glb 把每個物件的網格拿出來，場上幾百個物件共用同一份
func _load_props() -> void:
	var src := PROPS.instantiate()
	for c in src.get_children():
		if c is MeshInstance3D:
			_props[StringName(c.name)] = c.mesh
	src.free()

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
	var d := ARENA * 0.5 - 22.0
	for c: Vector3 in [_on_ground(Vector3(0, 0, d)), _on_ground(Vector3(0, 0, -d))]:
		_exits.append(c)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(EXIT_RADIUS * 2.0, 0.3, EXIT_RADIUS * 2.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.75, 0.95, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = c + Vector3(0, 0.15, 0)
		$Arena.add_child(mi)
		# 撤離點旁邊停一台篷車：遠遠就認得出「從這裡走」
		_prop(&"Wagon", _on_ground(c * Vector3(1, 0, 1) + Vector3(EXIT_RADIUS + 3.0, 0, 0))).rotation.y = 0.4

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
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "自己查 ifconfig"
