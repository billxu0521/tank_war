extends SceneTree
## 真的連線的檢查：本機開一台專用伺服器、兩個客戶端連上去（tools/net_check.sh 會一起開好）。
## 客戶端 A：請主機扣 B 的血（Main.request_damage）、開一槍；客戶端 B：看自己的血有沒有同步到、有沒有收到 A 的槍聲。
## 每個客戶端最後印一行「NET OK」或「NET FAIL: …」。
##   ROLE=a godot --headless --path . --script tools/net_check.gd

var _f := 0
var _m: Node
var _role := OS.get_environment("ROLE")
var _a: Node   # 客戶端 A 的牛仔（兩邊都找得到：名字是連線編號）
var _b: Node


func _initialize() -> void:
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:   # 等 Main 的 _ready 跑完（ip_edit 那些節點才拿得到）
		_m.ip_edit.text = "127.0.0.1"
		_m._on_join_pressed()
	if _f > 60 * 25:
		var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
		print("NET FAIL: 逾時（%s）連線狀態 %s、我是 %d、場上 %s、A=%s B=%s%s" % [_role,
			mp.get_connection_status() if mp else -1, _m.multiplayer.get_unique_id(),
			_m.players.get_children().map(func(p: Node) -> String: return p.name), _a, _b,
			"、B 血 %d、A 開槍 %d" % [_b.hp, _a.viewmodel.remote_shots] if _a and _b else ""])
		return true
	if _a == null or _b == null:
		_find()
		return false
	var want := OS.get_environment("MODE")   # 伺服器用 --mode 開的話，客戶端要收到同一個模式和重生次數
	if want != "" and (String(_m.rules) != want or _m._lives.size() < 2):
		return false
	if _role == "a":
		if _f % 60 == 0 and _b.hp == _b.max_hp:
			_a.deal_damage(_b, 30)   # 一發合理的傷害：主機要扣
			_a.viewmodel.try_fire()  # 一槍：B 要聽得到
		if _b.hp == _b.max_hp - 30:
			print("NET OK（A 看到 B 被扣到 %d，模式 %s，重生次數 %s）" % [_b.hp, _m.rules, _m._lives])
			return true
	else:
		if _b.hp == _b.max_hp - 30 and _a.viewmodel.remote_shots > 0:
			print("NET OK（B 自己的血 %d，收到 A 的槍 %d 發）" % [_b.hp, _a.viewmodel.remote_shots])
			return true
	return false


## 場上兩個牛仔：自己的跟另一個（伺服器不下場、恐龍和 bot 不算）
func _find() -> void:
	if _m.multiplayer.multiplayer_peer == null or _m.multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var mine: Node = _m.players.get_node_or_null(NodePath(str(_m.multiplayer.get_unique_id())))
	var other: Node = null
	for p in _m.players.get_children():
		if p != mine and not p.is_in_group(&"dino") and not Fighter.is_bot_id(p.name.to_int()):
			other = p
	if mine == null or other == null:
		return
	if _role == "a":
		_a = mine
		_b = other
	else:
		_a = other
		_b = mine
