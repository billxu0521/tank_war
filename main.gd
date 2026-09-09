extends Node3D
## 坦克大戰恐龍 — 區網原型。開房的人當恐龍，加入的人當坦克。

## 主機在關鍵時刻發出的事件，sim.gd 用它做時間軸。之後要做擊殺播報也接得上。
signal logged(text: String)

const PORT := 24680
const ARENA := 320.0        # 場地邊長
const SPAWN_CLEARANCE := 7.0  # 出生點離建築至少這麼遠
const GRID := 10              # 建築排成 GRID x GRID
const CELL := 30.0            # 格子間距，越小越密
const BUILDING_MAX_H := 28.0
# 圍牆不給爬（見 dino.gd 的 _on_climbable_wall），所以恐龍能到的最高點就是
# 「站上最高的屋頂再跳一下」。圍牆要比那個高，才翻不出去。
const WALL_H := 40.0
const WALL_T := 4.0
const EXIT_RADIUS := 14.0     # 撤離區半徑
const PICKUP_RANGE := 6.0     # 坦克靠這麼近就撿得到蛋
const EGG_HOLD_HEIGHT := 2.2  # 蛋掛在坦克上方多高
const MATCH_SECONDS := 240.0  # 一局四分鐘
const RESPAWN_DELAY := 5.0    # 死亡的代價是節奏，不是失去參賽資格
const TANK := preload("res://tank.tscn")
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

var _blocked: Array[Rect2] = []  # 建築物在 XZ 平面佔的範圍
var _exits: Array[Vector3] = []  # 四個撤離區的中心
var _tanks := 0
var _offline := false
var _time_left := 0.0
var _clock := 0                     # 主機廣播的剩餘秒數
var _respawn_queue: Array[Dictionary] = []
var _over := false

func _ready() -> void:
	_use_cjk_font()
	_build_arena()
	_build_exits()
	multiplayer.peer_connected.connect(_spawn)
	multiplayer.peer_disconnected.connect(_despawn)
	multiplayer.connected_to_server.connect(func() -> void: status.text = "已連線，你是坦克。WASD 移動，滑鼠瞄準砲塔，左鍵開砲")
	multiplayer.connection_failed.connect(
		func() -> void: _to_lobby.call_deferred("連線失敗，檢查 IP 和防火牆"))
	multiplayer.server_disconnected.connect(
		func() -> void: _to_lobby.call_deferred("主機斷線了"))
	_autostart.call_deferred()

## 啟動參數，方便在同一台機器開兩個視窗對打：
##   TankWar.exe -- --host
##   TankWar.exe -- --join 192.168.1.5
##   TankWar.exe -- --offline
func _autostart() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--host"):
		_on_host_pressed()
	elif args.has("--offline"):
		_on_offline_pressed()
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
	_tanks = 0
	_over = false
	_offline = false
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
	_enter_game("你是恐龍。等坦克加入…  本機 IP：" + _local_ips())
	_spawn(1)

func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip_edit.text, PORT) != OK:
		status.text = "連線失敗，IP 格式不對？"
		return
	multiplayer.multiplayer_peer = peer
	_enter_game("連線中…")

## 離線 debug：不連線，自己開一台坦克，配一隻會繞圈跑的恐龍當靶
func _on_offline_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_enter_game("離線測試模式：你是坦克，恐龍靶會自己跑")
	_add_player(TANK, 1).global_position = Vector3(-20, 1.0, 15)  # 編號 1 才操控得動
	var target := _add_player(DINO, 2)
	target.set(&"bot", true)
	target.global_position = Vector3(-20, 5.0, -20)

## 離線 debug：自己當恐龍，配三台會繞圈跑的坦克靶
func _on_offline_dino_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_offline = true
	_enter_game("離線測試模式：你是恐龍，三台坦克靶會自己跑（不會還擊）")
	_add_player(DINO, 1).global_position = _spawn_point()  # 編號 1 才操控得動
	for i in 3:
		var t := _add_player(TANK, 2 + i)
		t.set(&"bot", true)
		t.global_position = _spawn_point()

func _enter_game(msg: String) -> void:
	if multiplayer.is_server():
		_time_left = MATCH_SECONDS
		_clock = int(MATCH_SECONDS)
		_respawn_queue.clear()
		egg.carrier = 0
		egg.global_position = _spawn_point(ARENA * 0.22)  # 放中央附近，不要一開始就在出口旁邊
		egg.global_position.y = 1.2
	lobby.hide()
	menu.hide()
	status.text = msg
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- 生怪 / 勝負 ---

func _spawn(id: int) -> void:
	if not multiplayer.is_server():
		return  # 只有主機生，MultiplayerSpawner 會同步給大家
	_add_player(DINO if id == 1 else TANK, id)

func _add_player(scene: PackedScene, id: int) -> Node3D:
	var p: Node3D = scene.instantiate()
	p.name = str(id)
	players.add_child(p, true)
	p.global_position = _spawn_point()
	p.died.connect(_on_died.bind(p))
	if not p.is_in_group(&"dino"):
		_tanks += 1
	return p

func _despawn(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := players.get_node_or_null(NodePath(str(id)))
	if p:
		p.queue_free()
		if id != 1:
			_tanks -= 1

## 無限重生，不設命數。死亡的代價是節奏——等重生，而且蛋會掉在原地被別人撿走。
## 勝負只有兩種：有人帶蛋撤離（那個人贏），或時間到（恐龍贏）。
## 「打死恐龍」不算贏，不然三台坦克會理性地先聯手弄死恐龍，跟互相競爭矛盾。
func _on_died(killer: Node, who: Node) -> void:
	if _over:
		return
	var as_dino := who.is_in_group(&"dino")
	_log("%s 被 %s 打死%s" % [_who(who), _who(killer),
		"（身上有蛋）" if egg.carrier == who.name.to_int() else ""])
	if not as_dino:
		_tanks -= 1
	_respawn_queue.append({
		"id": who.name.to_int(),
		"dino": as_dino,
		"bot": bool(who.get(&"bot")),
		"at": Time.get_ticks_msec() + int(RESPAWN_DELAY * 1000.0),
	})

## 用佇列不用 await：回大廳時整個 Main 會被 free，await 醒來會踩到已釋放的物件。
func _respawn_step() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_respawn_queue.size() - 1, -1, -1):
		var r: Dictionary = _respawn_queue[i]
		if now < int(r["at"]):
			continue
		_respawn_queue.remove_at(i)
		var id: int = r["id"]
		if id != 1 and not _offline and not multiplayer.get_peers().has(id):
			continue  # 人已經離線就別生了
		var p := _add_player(DINO if r["dino"] else TANK, id)
		p.set(&"bot", r["bot"])


## 撤離是個人獲勝，所以每台機器顯示的字不一樣
@rpc("authority", "call_local", "reliable")
func _finish_egg(winner: int) -> void:
	_finish("你帶著蛋撤離，獲勝！" if winner == multiplayer.get_unique_id()
		else "坦克 %d 帶著蛋撤離，你輸了" % winner)

@rpc("authority", "call_local", "reliable")
func _finish(msg: String) -> void:
	status.text = msg + "  （按 Esc 放開滑鼠）"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if lobby.visible or _over or not multiplayer.is_server():
		return
	_egg_step()
	_respawn_step()

	_time_left -= delta
	if int(_time_left) != _clock:
		_clock = int(_time_left)
		_set_clock.rpc(_clock)
	if _time_left <= 0.0:
		_over = true
		_log("時間到，沒有人把蛋帶走")
		_finish.rpc("時間到，沒有人把蛋帶走——恐龍獲勝！")

@rpc("authority", "call_local", "reliable")
func _set_clock(secs: int) -> void:
	_clock = secs

## 蛋的規則：坦克靠近就撿走，持有者死掉就留在原地，帶進撤離區就贏。
func _egg_step() -> void:
	if egg.carrier == 0:
		for p in players.get_children():
			if p.is_in_group(&"dino"):
				continue
			if egg.global_position.distance_to(p.global_position) < PICKUP_RANGE:
				egg.carrier = p.name.to_int()
				_log("%s 撿到蛋" % _who(p))
				return
		return

	var holder := players.get_node_or_null(NodePath(str(egg.carrier)))
	if holder == null:
		_log("蛋掉在 (%.0f, %.0f)，離最近的出口還有 %.0f 公尺" % [
			egg.global_position.x, egg.global_position.z, _dist_to_exit(egg.global_position)])
		egg.carrier = 0   # 持有者陣亡，蛋就掉在他最後的位置
		return
	egg.global_position = holder.global_position + Vector3.UP * EGG_HOLD_HEIGHT
	for e: Vector3 in _exits:
		if Vector2(egg.global_position.x - e.x, egg.global_position.z - e.z).length() < EXIT_RADIUS:
			_over = true
			_log("坦克%d 帶著蛋撤離成功" % egg.carrier)
			_finish_egg.rpc(egg.carrier)
			return

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
		egg_state = "在你身上！開去藍色撤離區"
	elif egg.carrier != 0:
		egg_state = "被坦克 %d 拿走了" % egg.carrier
	var mine := "陣亡"
	if me != null:
		mine = str(me.hp)
	elif _respawn_seconds_for(multiplayer.get_unique_id()) > 0:
		mine = "重生中 %d 秒" % _respawn_seconds_for(multiplayer.get_unique_id())
	hud.text = "⏱ %d:%02d    我的血量：%s    恐龍血量：%s    存活坦克：%d    蛋：%s" % [
		maxi(_clock, 0) / 60, maxi(_clock, 0) % 60,
		mine,
		dino.hp if dino else 0,
		players.get_child_count() - (1 if dino else 0),
		egg_state]

func _log(text: String) -> void:
	logged.emit("%6.1fs  %s" % [MATCH_SECONDS - maxf(_time_left, 0.0), text])

func _who(n: Node) -> String:
	if n == null:
		return "不明"
	return "恐龍" if n.is_in_group(&"dino") else "坦克%s" % n.name

func _dist_to_exit(p: Vector3) -> float:
	var best := 9999.0
	for e: Vector3 in _exits:
		best = minf(best, Vector2(p.x - e.x, p.z - e.z).length())
	return best

## 還要幾秒才重生（只有主機知道，客戶端看到的是 0）
func _respawn_seconds_for(id: int) -> int:
	for r: Dictionary in _respawn_queue:
		if int(r["id"]) == id:
			return maxi(0, int((int(r["at"]) - Time.get_ticks_msec()) / 1000) + 1)
	return 0

## 準心畫在「砲彈會落到哪」，不是螢幕正中央——抬砲時看得出彈道往上跑。
## 恐龍是近戰，沒有 aim_point，就不顯示。
func _update_crosshair(me: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	if me == null or cam == null or not me.has_method("aim_point"):
		crosshair.hide()
		return
	var p: Vector3 = me.aim_point()
	crosshair.visible = not cam.is_position_behind(p)
	crosshair.position = cam.unproject_position(p) - crosshair.size * 0.5

# --- 場地 ---

func _build_arena() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(ARENA, 1, ARENA), Color(0.30, 0.40, 0.25))

	# 四周圍牆，東西才不會掉出場外。內側牆面剛好貼齊地板邊緣，不留縫。
	var e := (ARENA + WALL_T) * 0.5
	var long := ARENA + WALL_T * 2.0
	var col := Color(0.32, 0.31, 0.29)
	for w: Array in [[Vector3(0, WALL_H * 0.5, e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(0, WALL_H * 0.5, -e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)],
			[Vector3(-e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)]]:
		_add_box(w[0], w[1], col).add_to_group(&"arena_wall")

	# ponytail: 固定 seed 的亂數，每台機器蓋出來的建築才會完全一樣（場地沒有走網路同步）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	for gx in GRID:
		for gz in GRID:
			if rng.randf() < 0.12:
				continue  # 留一點空地，不然完全沒有開闊處
			# 高度差距拉開：矮的當掩體、高的要爬才上得去
			var size := Vector3(rng.randf_range(8, 20), rng.randf_range(6, BUILDING_MAX_H),
				rng.randf_range(8, 20))
			var half := (GRID - 1) * 0.5
			var pos := Vector3((gx - half) * CELL + rng.randf_range(-6, 6), size.y * 0.5,
				(gz - half) * CELL + rng.randf_range(-6, 6))
			_add_box(pos, size, Color(0.45, 0.40, 0.35))
			# 出生點要避開，不然會卡在牆裡
			_blocked.append(Rect2(pos.x - size.x * 0.5 - SPAWN_CLEARANCE,
				pos.z - size.z * 0.5 - SPAWN_CLEARANCE,
				size.x + SPAWN_CLEARANCE * 2, size.z + SPAWN_CLEARANCE * 2))

## 四個撤離區，四邊各一個。只有一個出口的話恐龍蹲在那裡就好，
## 等於把「守著不動」的問題從蛋搬到出口。
func _build_exits() -> void:
	var d := ARENA * 0.5 - 22.0
	for c: Vector3 in [Vector3(0, 0, d), Vector3(0, 0, -d), Vector3(d, 0, 0), Vector3(-d, 0, 0)]:
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

## 找一個不在建築物裡面的出生點
func _spawn_point(span := ARENA * 0.45) -> Vector3:
	for i in 80:
		var p := Vector2(randf_range(-span, span), randf_range(-span, span))
		if _is_clear(p):
			return Vector3(p.x, 5.0, p.y)
	# 建築只蓋在中間，外圍一定是空的
	var edge := ARENA * 0.46
	var corner := Vector2(edge, edge).rotated(randf() * TAU)
	return Vector3(corner.x, 5.0, corner.y)

func _is_clear(p: Vector2) -> bool:
	for r: Rect2 in _blocked:
		if r.has_point(p):
			return false
	return true

func _add_box(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(mi)
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
