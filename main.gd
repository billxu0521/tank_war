extends Node3D
## 坦克大戰恐龍 — 區網原型。開房的人當恐龍，加入的人當坦克。

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
	_enter_game("離線測試模式：你是坦克，恐龍靶會自己跑")
	_add_player(TANK, 1).global_position = Vector3(-20, 1.0, 15)  # 編號 1 才操控得動
	var target := _add_player(DINO, 2)
	target.set(&"dummy", true)
	target.global_position = Vector3(-20, 5.0, -20)

## 離線 debug：自己當恐龍，配三台會繞圈跑的坦克靶
func _on_offline_dino_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enter_game("離線測試模式：你是恐龍，三台坦克靶會自己跑（不會還擊）")
	_add_player(DINO, 1).global_position = _spawn_point()  # 編號 1 才操控得動
	for i in 3:
		var t := _add_player(TANK, 2 + i)
		t.set(&"dummy", true)
		t.global_position = _spawn_point()

func _enter_game(msg: String) -> void:
	if multiplayer.is_server():
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

func _on_died(who: Node) -> void:
	if _over:
		return
	if who.is_in_group(&"dino"):
		_over = true
		_finish.rpc("坦克獲勝！")
	else:
		_tanks -= 1
		if _tanks <= 0:
			_over = true
			_finish.rpc("恐龍獲勝！")

@rpc("authority", "call_local", "reliable")
func _finish(msg: String) -> void:
	status.text = msg + "  （按 Esc 放開滑鼠）"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta: float) -> void:
	if lobby.visible or _over or not multiplayer.is_server():
		return
	_egg_step()

## 蛋的規則：坦克靠近就撿走，持有者死掉就留在原地，帶進撤離區就贏。
func _egg_step() -> void:
	if egg.carrier == 0:
		for p in players.get_children():
			if p.is_in_group(&"dino"):
				continue
			if egg.global_position.distance_to(p.global_position) < PICKUP_RANGE:
				egg.carrier = p.name.to_int()
				return
		return

	var holder := players.get_node_or_null(NodePath(str(egg.carrier)))
	if holder == null:
		egg.carrier = 0   # 持有者陣亡，蛋就掉在他最後的位置
		return
	egg.global_position = holder.global_position + Vector3.UP * EGG_HOLD_HEIGHT
	for e: Vector3 in _exits:
		if Vector2(egg.global_position.x - e.x, egg.global_position.z - e.z).length() < EXIT_RADIUS:
			_over = true
			_finish.rpc("坦克帶著蛋撤離，坦克獲勝！")
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
	hud.text = "我的血量：%s    恐龍血量：%s    存活坦克：%d    蛋：%s" % [
		me.hp if me else "陣亡",
		dino.hp if dino else 0,
		players.get_child_count() - (1 if dino else 0),
		egg_state]

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
