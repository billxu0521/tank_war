extends Node3D
## 坦克大戰恐龍 — 區網原型。開房的人當恐龍，加入的人當坦克。

const PORT := 24680
const TANK := preload("res://tank.tscn")
const DINO := preload("res://dino.tscn")

@onready var lobby: VBoxContainer = $UI/Root/Lobby
@onready var ip_edit: LineEdit = $UI/Root/Lobby/IP
@onready var status: Label = $UI/Root/Status
@onready var hud: Label = $UI/Root/Hud
@onready var stamina_bar: ProgressBar = $UI/Root/Stamina
@onready var crosshair: Label = $UI/Root/Crosshair
@onready var players: Node3D = $Players

var _tanks := 0
var _over := false

func _ready() -> void:
	_use_cjk_font()
	_build_arena()
	multiplayer.peer_connected.connect(_spawn)
	multiplayer.peer_disconnected.connect(_despawn)
	multiplayer.connected_to_server.connect(func() -> void: status.text = "已連線，你是坦克。WASD 移動，滑鼠瞄準砲塔，左鍵開砲")
	multiplayer.connection_failed.connect(func() -> void: status.text = "連線失敗，檢查 IP 和防火牆")
	multiplayer.server_disconnected.connect(func() -> void: status.text = "主機斷線了")
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
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed and not lobby.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

## 離線 debug：不連線，自己開一台坦克，配一隻不會動的恐龍當靶
func _on_offline_pressed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enter_game("離線測試模式：你是坦克，恐龍是不會動的靶子")
	_add_player(TANK, 1).global_position = Vector3(-20, 1.0, 15)  # 編號 1 才操控得動
	_add_player(DINO, 2).global_position = Vector3(-20, 2.7, -8)  # 沒權限不會掉，直接放地上

func _enter_game(msg: String) -> void:
	lobby.hide()
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
	p.global_position = Vector3(randf_range(-50.0, 50.0), 5.0, randf_range(-50.0, 50.0))
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
	hud.text = "我的血量：%s    恐龍血量：%s    存活坦克：%d" % [
		me.hp if me else "陣亡",
		dino.hp if dino else 0,
		players.get_child_count() - (1 if dino else 0)]

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
	_add_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color(0.30, 0.40, 0.25))
	for p: Vector3 in [Vector3(24, 1.5, 16), Vector3(-28, 1.5, -12), Vector3(10, 1.5, -36),
			Vector3(-16, 1.5, 32), Vector3(40, 1.5, -40), Vector3(-44, 1.5, 40),
			Vector3(0, 1.5, 44), Vector3(44, 1.5, 30), Vector3(-38, 1.5, -34),
			Vector3(2, 1.5, -6)]:
		_add_box(p, Vector3(8, 3, 8), Color(0.45, 0.40, 0.35))

func _add_box(pos: Vector3, size: Vector3, col: Color) -> void:
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
