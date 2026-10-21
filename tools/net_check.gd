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
var _dir := 1.0      # 客戶端 A 現在往哪跑（±X）
var _turn := 0.0     # 還剩幾秒換方向
var _hit_at := -100000   # A 上次送扣血的時刻（毫秒）
var _ok_at := 0          # 成功的時刻（毫秒）；之後再等 5 秒才離開，不然先走的會讓另一邊拿到 Freed
var _reconnect := OS.get_environment("RECONNECT") != ""   # 斷線重連檢查：B 被扣一條命後斷線再連回，看命數有沒有回來
var _b_old := 0      # B：斷線前的編號
var _rejoin_at := 0  # B：斷線的時刻（毫秒），隔 1 秒再連


func _initialize() -> void:
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _process(_d: float) -> bool:
	_f += 1
	if _ok_at > 0:   # 已經成功：等另一邊也收完才離開（重連檢查時 A 要撐到 B 連回來）
		return Time.get_ticks_msec() - _ok_at >= (20000 if _reconnect and _role == "a" else 5000)
	if _f == 2:   # 等 Main 的 _ready 跑完（ip_edit 那些節點才拿得到）
		var join := OS.get_environment("JOIN")   # LAG=1 時指到轉送程式，例如 127.0.0.1:24681
		_m.ip_edit.text = join if join != "" else "127.0.0.1"
		_m.player_key = "net-" + _role   # 兩個客戶端在同一台、讀同一個 settings.cfg，不蓋掉會被當成同一個人
		_m._on_join_pressed()
	if _f > 60 * ((40 if OS.get_environment("JOIN") != "" else 25) + (20 if _reconnect else 0)):
		var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
		print("NET FAIL: 逾時（%s）連線狀態 %s、我是 %d、場上 %s、A=%s B=%s%s" % [_role,
			mp.get_connection_status() if mp else -1, _m.multiplayer.get_unique_id(),
			_m.players.get_children().map(func(p: Node) -> String: return p.name), _a, _b,
			"、B 血 %d、A 開槍 %d" % [_b.hp, _a.viewmodel.remote_shots] if is_instance_valid(_a) and is_instance_valid(_b) else ""])
		return true
	if _reconnect and _role == "b" and _rejoin_at > 0:   # B 斷線中：1 秒後再連回來（大廳還看得到才按，只按一次）
		if not _m.lobby.visible:   # 按了加入、大廳藏起來了：不用再等，照常找角色
			_rejoin_at = 0
		elif Time.get_ticks_msec() - _rejoin_at >= 1000:
			_m._on_join_pressed()
		if _rejoin_at > 0:
			return false
	if not is_instance_valid(_a) or not is_instance_valid(_b):   # 角色死了重生就是新節點，要重找
		_find()
		return false
	var want := OS.get_environment("MODE")   # 伺服器用 --mode 開的話，客戶端要收到同一個模式和重生次數
	if want != "" and (String(_m.rules) != want or _m._lives.size() < 2):
		return false
	if _reconnect:
		# A 一直打 B（每 0.5 秒 30 點）直到 B 少一條命（3 -> 2）；B 扣掉一條命後斷線，連回來命數要是 2
		var bid := _b.name.to_int()
		if _role == "a":
			if int(_m._lives.get(bid, 3)) >= 3 and _b.hp > 0 and Time.get_ticks_msec() - _hit_at >= 500:
				_hit_at = Time.get_ticks_msec()
				_a.deal_damage(_b, 30)
			if int(_m._lives.get(bid, 3)) == 2:
				print("NET OK（A 扣掉 B 一條命）")
				_ok_at = Time.get_ticks_msec()
		else:
			var me := _m.multiplayer.get_unique_id()
			if _b_old == 0 and int(_m._lives.get(me, 3)) == 2:   # 被扣一條命了：斷線
				_b_old = me
				_rejoin_at = Time.get_ticks_msec()
				_m._to_lobby("")
				_a = null
				_b = null
			elif _b_old != 0 and me != _b_old and _m._lives.has(me):
				_rejoin_at = 0
				if int(_m._lives[me]) == 2:
					print("NET OK（B 重連：編號 %d -> %d，命數拿回 2）" % [_b_old, me])
				else:
					print("NET FAIL: B 重連後命數是 %d，應該是 2" % int(_m._lives[me]))
				_ok_at = Time.get_ticks_msec()
		return false
	if _role == "a":
		# 正常移動的玩家不能被主機拉回：沿 X 來回跑，速度 0.95 倍衝刺，每 3 秒換方向
		_turn -= _d
		if _turn <= 0.0:
			_dir = -_dir
			_turn = 3.0
		_a.global_position.x += _dir * _a.sprint_speed * 0.95 * _d
		var now := Time.get_ticks_msec()
		if _b.hp == _b.max_hp and now - _hit_at >= 2000:   # 隔 2 秒重送：第一發可能被主機拒絕（網路慢）
			_hit_at = now
			_a.deal_damage(_b, 30)   # 一發合理的傷害：主機要扣
			_a.viewmodel.try_fire()  # 一槍：B 要聽得到
		if _b.hp < _b.max_hp:
			print("NET OK（A 看到 B 被扣到 %d，模式 %s，重生次數 %s）" % [_b.hp, _m.rules, _m._lives])
			_ok_at = now
	else:
		if _b.hp < _b.max_hp and _a.viewmodel.remote_shots > 0:
			print("NET OK（B 自己的血 %d，收到 A 的槍 %d 發）" % [_b.hp, _a.viewmodel.remote_shots])
			_ok_at = Time.get_ticks_msec()
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
