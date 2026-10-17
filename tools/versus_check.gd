extends SceneTree
## 對抗模式真的連線檢查（tools/versus_check.sh 開好專用伺服器＋兩個客戶端）：
## A 勾「我想當恐龍」→ 要被抽成尼諾拉、自己的牛仔收掉；A 送輸入（往前跑、咬）；
## B 要看到尼諾拉是 A 在開、有往前移動、出了咬的預備。每個客戶端最後印「VS OK」或「VS FAIL: …」
var _f := 0
var _m: Node
var _role := OS.get_environment("ROLE")
var _p0 := Vector3.INF
var _saw_move := false   # B：看到過尼諾拉移動
var _saw_bite := false   # B：看到過咬的預備
var _done_at := 0        # A：成功後再留一下，讓 B 看得到

func _initialize() -> void:
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_m.want_dino = _role == "a"
		_m.ip_edit.text = "127.0.0.1"
		_m._on_join_pressed()
	if _f > 60 * 25:
		var b: Node = _m._boss()
		print("VS FAIL: 逾時（%s）pilot=%s 我=%d act=%s" % [_role, b.pilot if b else "沒有恐龍", _m.multiplayer.get_unique_id(), b.act if b else -1])
		return true
	var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	var b: Node = _m._boss()
	if b == null:
		return false
	if _p0 == Vector3.INF:   # 從恐龍一出現就開始量（B 晚連上時，A 可能已經在跑了）
		_p0 = b.global_position
	if b.pilot == 0:
		return false
	var me := _m.multiplayer.get_unique_id()
	if _done_at > 0:   # A 成功後再留兩秒讓 B 看到
		return _f > _done_at + 120
	# A 等 B 連上（場上有別的牛仔）才開始動，B 才看得到整段
	if _role == "a" and not _m.players.get_children().any(func(p: Node) -> bool: return not p.is_in_group(&"dino") and not Fighter.is_bot_id(p.name.to_int())):
		return false
	var moved: float = Vector2(b.global_position.x - _p0.x, b.global_position.z - _p0.z).length()
	if _role == "a":
		if b.pilot != me:
			print("VS FAIL: 想當恐龍的 A 沒被抽到（pilot=%d）" % b.pilot)
			return true
		var bite: bool = moved > 3.0
		b.pilot_input.rpc_id(1, Vector2(0, -1) if not bite else Vector2.ZERO, b.rotation.y, 0.0, b.PIN_BITE if bite else b.PIN_RUN)
		if bite and b.act == b.ACT_BITE_WIND:
			_done_at = _f
			print("VS OK（A 是尼諾拉、沒有自己的牛仔=%s、跑了 %.1f 公尺、咬的預備同步回來）" % [not _m.players.has_node(NodePath(str(me))), moved])
	else:
		if b.pilot == me:
			print("VS FAIL: 沒勾的 B 被抽成恐龍")
			return true
		_saw_move = _saw_move or moved > 3.0
		_saw_bite = _saw_bite or b.act == b.ACT_BITE_WIND
		if _saw_move and _saw_bite:
			print("VS OK（B 看到尼諾拉由 %d 操作、移動 %.1f 公尺、出咬的預備）" % [b.pilot, moved])
			return true
	return false
