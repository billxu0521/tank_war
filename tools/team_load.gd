extends SceneTree
## 團隊模式 T0：量 10 個人的負擔（docs/企劃/2026-11-19-團隊模式.md 第 11 節）。不改玩法，只量。
## 一次開完整組用 tools/team_load.sh（伺服器＋N 個假客戶端，或只跑電腦版）。各角色：
##   ROLE=server  godot --headless --path . --script tools/team_load.gd -- --server --mode party
##       專用伺服器（物理 60 次、鎖 60 幀）。等 CLIENTS 個客戶端都連上，排成「電腦尼諾拉＋全部真人當牛仔」重開回合，
##       量 DURATION 秒：主機每幀忙多久、ENet 送收多少。
##   ROLE=client  godot --headless --path . --script tools/team_load.gd
##       假客戶端：連 127.0.0.1，自己繞圈跑、每 0.5 秒開一槍（打空就換彈），量自己每秒收多少。
##   ROLE=bots    godot --headless --path . --script tools/team_load.gd
##       電腦版：不連線，BOTS 個電腦牛仔＋電腦尼諾拉（照 bot_sim 的開法，但不快轉），量主機每幀忙多久。
## 環境變數：CLIENTS（預設 9）、BOTS（預設 9）、DURATION（預設 180）、ID（客戶端編號，分開 player_key）。
## SYNC=30：自己負責送的同步器（客戶端：自己的牛仔；主機：尼諾拉、蛋）和主機合包（main.gd 的 net_pack_hz）改成每秒 SYNC 次。只在這個工具裡改，遊戲不動。
##   SYNC_ROLE=client：只降玩家自己的牛仔（主機的尼諾拉、蛋照舊）；SYNC_ROLE=server 反過來。分得出兩邊各省多少。
## PROF=1：主機多印物理步裡幾個大塊各花多少（Fighter.prof：尼諾拉 think、電腦牛仔 _bot_step、小恐龍、party.step）。
## 「每幀忙多久」＝從這一幀第一個物理步（沒有物理步就從 _process）開始，到最後一個節點的 _process 結束：
## 含腳本的物理、物理引擎、收網路包、_process；不含畫面（沒畫面）和鎖 60 幀的空等。
## 每個角色最後印「TEAM_LOAD OK」（Godot 解析錯誤也回 0，要看這行）。

var _role := OS.get_environment("ROLE")
var _n := int(OS.get_environment("CLIENTS")) if OS.get_environment("CLIENTS") != "" else 9
var _bots := int(OS.get_environment("BOTS")) if OS.get_environment("BOTS") != "" else 9
var _secs := float(OS.get_environment("DURATION")) if OS.get_environment("DURATION") != "" else 180.0
var _m: Node
var _f := 0
var _arranged := false
var _t0 := 0           # 量的那段開始（微秒），0 = 還沒開始
var _start := -1       # 這一幀開始（微秒）
var _ticks := 0        # 這一幀幾個物理步
var _us: PackedInt32Array = []   # 每幀忙多久（微秒）
var _multi := 0        # 一幀跑了不只一個物理步（追進度）的幀數
var _ang := 0.0
var _shot := 0.0
var _tp := 0          # 這一幀腳本的 _process（物理步之後、收網路包之前）
var _tf := 0          # 這一幀的 process_frame 訊號（收完網路包、節點的 _process 之前）
var _sum := [0, 0, 0] # 三段加總（微秒）：物理、網路、_process
var _reported := false   # 客戶端：量完了，繼續跑到主機關掉（先走的話主機那邊少一個人，回合會結束）


## 排在所有節點的 _process 最後：一幀的結束
class EndMark extends Node:
	var on_end: Callable
	func _process(_d: float) -> void:
		on_end.call()


func _initialize() -> void:
	seed(1)
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	var e := EndMark.new()
	e.process_priority = 1 << 30
	e.on_end = _frame_end
	root.add_child(e)
	process_frame.connect(func() -> void: _tf = Time.get_ticks_usec())


func _physics_process(_d: float) -> bool:
	if _start < 0:
		_start = Time.get_ticks_usec()
	_ticks += 1
	return false


func _frame_end() -> void:
	if _t0 > 0 and _start >= 0:
		var e := Time.get_ticks_usec()
		_us.append(e - _start)
		_sum[0] += _tp - _start
		_sum[1] += _tf - _tp
		_sum[2] += e - _tf
		if _ticks > 1:
			_multi += 1
	_start = -1
	_ticks = 0


func _process(d: float) -> bool:
	if _start < 0:
		_start = Time.get_ticks_usec()
	_tp = Time.get_ticks_usec()
	_f += 1
	var sr := OS.get_environment("SYNC_ROLE")
	if OS.get_environment("SYNC") != "" and _f % 30 == 0 and (sr == "" or sr == _role):
		_slow_sync(float(OS.get_environment("SYNC")))
	match _role:
		"server":
			return _server()
		"client":
			return _client(d)
		"bots":
			return _bots_step()
	print("TEAM_LOAD FAIL: ROLE 要是 server、client 或 bots")
	return true


func _host() -> ENetConnection:
	var mp := _m.multiplayer.multiplayer_peer
	return (mp as ENetMultiplayerPeer).host if mp is ENetMultiplayerPeer else null


## SYNC 開關：自己是權威的同步器都改成每秒 hz 次（新生的牛仔是新節點，所以每 30 幀掃一次）
func _slow_sync(hz: float) -> void:
	for n: Node in root.find_children("*", "MultiplayerSynchronizer", true, false):
		if n.is_multiplayer_authority():
			n.replication_interval = 1.0 / hz
	if _m.multiplayer.multiplayer_peer and _m.multiplayer.is_server():
		_m.net_pack_hz = hz   # 主機合包（S2）的頻率


## 回合不要結束：命補滿、時間不倒數到底（量的是 3 分鐘一直在打的負擔）
func _keep_playing(p: Party) -> void:
	p.time_left = maxf(p.time_left, 30.0)
	_m.egg.extract = 0.0   # 電腦會帶蛋撤離：撤離的進度一直歸零，回合才不會結束（拿著蛋的那個會站在撤離區）
	for id in p.lives:
		p.lives[id] = Party.LIVES


## 開始量：清掉 ENet 的累計（pop 會歸零）
func _begin() -> void:
	print("TEAM_LOAD 開始量（同步 %s）" % ("每秒 %s 次" % OS.get_environment("SYNC") if OS.get_environment("SYNC") != "" else "照遊戲"))
	var h := _host()
	if h:
		for s in [ENetConnection.HOST_TOTAL_SENT_DATA, ENetConnection.HOST_TOTAL_SENT_PACKETS,
				ENetConnection.HOST_TOTAL_RECEIVED_DATA, ENetConnection.HOST_TOTAL_RECEIVED_PACKETS]:
			h.pop_statistic(s)
	Fighter.prof.clear()
	_t0 = Time.get_ticks_usec()


func _elapsed() -> float:
	return (Time.get_ticks_usec() - _t0) / 1e6


## 一行流量：位元組＋每包 28 位元組的 UDP／IP 標頭（ENet 的統計不含）
func _traffic(label: String, data: int, packets: int, t: float) -> String:
	var kbps := (data + 28.0 * packets) * 8.0 / 1000.0 / t
	return "%s %.0f kbps（%.1f KB／秒，%.0f 包／秒，平均一包 %.0f 位元組）" % [label, kbps, kbps / 8.0, packets / t, float(data) / maxi(packets, 1)]


func _report(extra: String) -> void:
	var t := _elapsed()
	var s := Array(_us)
	s.sort()
	var tot := 0
	for v: int in s:
		tot += v
	var pct := func(q: float) -> float: return s[mini(int(s.size() * q), s.size() - 1)] / 1000.0 if s.size() > 0 else 0.0
	print("TEAM_LOAD %s（%.0f 秒，%d 幀，追進度的幀 %d）" % [extra, t, s.size(), _multi])
	print("  主機每幀忙 平均 %.2f 毫秒、中間值 %.2f、最慢 1%% %.2f、最慢 0.1%% %.2f、最慢 %.2f" % [
		tot / 1000.0 / maxi(s.size(), 1), pct.call(0.5), pct.call(0.99), pct.call(0.999), pct.call(1.0)])
	var n := maxi(s.size(), 1) * 1000.0
	print("  主機三段 物理 %.2f、網路 %.2f、_process %.2f 毫秒（平均）" % [_sum[0] / n, _sum[1] / n, _sum[2] / n])
	if Fighter.prof_on:
		var parts := []
		var rest: float = _sum[0]
		for k: StringName in Fighter.prof:
			parts.append("%s %.3f" % [k, Fighter.prof[k] / n])
			rest -= Fighter.prof[k]
		parts.append("其他（物理引擎、子彈、其餘腳本） %.3f" % (rest / n))
		print("  主機物理步拆帳（平均每幀毫秒）：" + "、".join(parts))
	var h := _host()
	if h:
		var sd := h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		var sp := h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
		var rd := h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		var rp := h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
		print("  " + _traffic("送出", sd, sp, t))
		print("  " + _traffic("收到", rd, rp, t))


func _server() -> bool:
	var p: Party = _m.party
	if p == null or _m.multiplayer.multiplayer_peer == null:
		return false
	if not _arranged:
		if _m.multiplayer.get_peers().size() < _n:
			if _f > 60 * 120:
				print("TEAM_LOAD FAIL: 2 分鐘只連上 %d／%d 個" % [_m.multiplayer.get_peers().size(), _n])
				return true
			return false
		# 排名單：電腦尼諾拉（-1）＋全部真人當牛仔，重開這回合
		var ids: Array = _m.multiplayer.get_peers().duplicate()
		ids.sort()
		p._roster = [-1] + ids
		p.names.clear()
		p.scores.clear()
		for id: int in p._roster:
			p.names[id] = "假 %d" % id
			p.scores[id] = 0
		p.round_index = 0
		p._start_round()
		_arranged = true
		return false
	return _measure(p, "伺服器（1＋%d 個假客戶端）" % _n)


## 共用：準備階段跳過、進到打的階段開始量 DURATION 秒
func _measure(p: Party, label: String) -> bool:
	if p.phase == &"prep":
		p.time_left = minf(p.time_left, 0.1)
		return false
	if p.phase != &"play":
		print("TEAM_LOAD FAIL: 回合跑到 %s（%s），量了 %.0f 秒" % [p.phase, p.last_result, _elapsed() if _t0 > 0 else 0.0])
		return true
	_keep_playing(p)
	if _t0 == 0:
		_begin()
		return false
	if _elapsed() >= _secs:
		var cows: int = _m.players.get_children().filter(func(c: Node) -> bool: return not c.is_in_group(&"dino")).size()
		_report("%s：場上牛仔 %d 個" % [label, cows])
		print("TEAM_LOAD OK")
		return true
	return false


func _client(d: float) -> bool:
	if _f == 2:
		_m.ip_edit.text = "127.0.0.1"
		_m.player_key = "load-" + OS.get_environment("ID")   # 同一台、讀同一個設定檔，不分開會被當成同一個人
		_m._on_join_pressed()
		return false
	if Time.get_ticks_msec() > 600000:
		print("TEAM_LOAD FAIL: 客戶端 10 分鐘還沒量完")
		return true
	var mp := _m.multiplayer.multiplayer_peer
	if _reported and (mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED):
		return true
	var p: Party = _m.party
	var me: Node = _m.players.get_node_or_null(NodePath(str(_m.multiplayer.get_unique_id())))
	if p == null or p.phase != &"play" or me == null or not me.has_method(&"deal_damage"):
		if _t0 > 0 and not _reported and (mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED):
			print("TEAM_LOAD FAIL: 斷線了")
			return true
		return false
	if _t0 == 0:
		_begin()
	# 繞半徑 6 公尺的圈：用衝刺的 0.9 倍速度，主機不會拉回
	var r := 6.0
	var v: float = me.sprint_speed * 0.9
	_ang += v / r * d
	me.global_position += Vector3(-sin(_ang), 0.0, cos(_ang)) * v * d
	me.rotation.y = -_ang
	_shot -= d
	if _shot <= 0.0:
		_shot = 0.5
		if me.viewmodel.weapon.mag == 0:
			me.viewmodel.try_reload()
		else:
			me.viewmodel.try_fire()
	if _elapsed() >= _secs - 5.0 and not _reported:   # 比主機早 5 秒收：主機先關的話這邊會變斷線
		_reported = true
		var h := _host()
		var t := _elapsed()
		var others: Array = _m.players.get_children().filter(func(c: Node) -> bool: return c != me and c is Fighter and c.get_multiplayer_authority() != 1)
		var fresh := others.filter(func(c: Fighter) -> bool: return not c._snaps.is_empty() and Time.get_ticks_msec() - c._snaps[-1][1] < 500.0)
		print("TEAM_LOAD 客戶端 %s：別的玩家 %d 個、半秒內有收到位置的 %d 個" % [OS.get_environment("ID"), others.size(), fresh.size()])
		print("TEAM_LOAD 客戶端 %s：%s；%s" % [OS.get_environment("ID"), _traffic("收到",
			h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA), h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS), t),
			_traffic("送出", h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA), h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS), t)])
		print("TEAM_LOAD OK")
	return false


func _bots_step() -> bool:
	if _f == 2:   # 照 bot_sim：沒有真人的專用伺服器，但不快轉、鎖 60 幀
		Engine.physics_ticks_per_second = 60
		Engine.max_fps = 60
		_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_m._offline = true
		_m._dedicated = true
		ToyBuild.no_flight = true
		_m._on_mode_picked(_m.RULES.keys().find(&"party"))
		_m._enter_game("team_load")
		_m._apply_rules()
		_m.spawn_boss()
		return false
	var p: Party = _m.party
	if p == null or p.phase == &"":
		return false
	if not _arranged:
		p._roster = []
		p.names.clear()
		p.scores.clear()
		for i in _bots + 1:   # -1 是尼諾拉
			p._roster.append(-1 - i)
			p.names[-1 - i] = "電腦 %d" % (i + 1)
			p.scores[-1 - i] = 0
		p.round_index = 0
		p._start_round()
		_arranged = true
		return false
	return _measure(p, "電腦版（%d 個電腦牛仔＋電腦尼諾拉）" % _bots)
