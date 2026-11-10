extends SceneTree
## 量「順不順」（docs/規劃/2026-11-10-遊戲順暢.md）：照固定劇本拆房子，量兩幀之間真的隔多久（Time.get_ticks_usec，不看 Performance 的幀時間）。
## 劇本：先空轉 IDLE 秒 → 每 GAP 秒拆一棟（最大的 HOUSES 棟，在牆腳用甩尾的半徑拆，碎塊留著不還原）→ 最後再空轉 IDLE 秒（滿場碎塊）。
##   單機（客戶端的路：碎塊會飛）    godot --headless --path . --script tools/smooth_probe.gd
##   單機、伺服器的路（碎塊直接落地）  NOFLIGHT=1 godot --headless --path . --script tools/smooth_probe.gd
##   開視窗（多印繪製指令、三角形）    godot --path . --disable-vsync --resolution 1920x1080 --script tools/smooth_probe.gd
##   尼諾拉真的跑去撞（碎塊多、會踢）  SCEN=plow godot --headless --path . --script tools/smooth_probe.gd
##   逐項計時（找誰最慢）            PROFILE=1 godot --headless --path . --script tools/smooth_probe.gd
##   真的連線（伺服器＋客戶端）       tools/smooth_probe.sh
## 每段印一行「順暢 …」；最後一行「SMOOTH OK」才算跑完（Godot 解析錯誤也回 0）。

const FRAME_MS := 16.7   # 超過算掉幀（每秒 60 張的一幀）

var _role := OS.get_environment("ROLE")   # ""＝單機、server、client
var NH := _env("HOUSES", 4.0) as int
var GAP := _env("GAP", 8.0)
var IDLE := _env("IDLE", 5.0)
var R := _env("RADIUS", 12.0)   # balance.csv 的 sweep_radius
var _m: Node
var _f := 0
var _houses: Array = []
var _hi := -1
var _phase := ""
var _t := 0.0            # 這一段過了幾秒
var _gaps := PackedFloat32Array()
var _worst: Array = []   # [毫秒, 這一段的第幾秒]
var _draws := PackedFloat32Array()
var _tris := PackedFloat32Array()
var _last_us := 0
var _bytes0 := 0
var _fixes := 0          # 主機拉回玩家幾次
var _fix_seen := {}
var _started := false
var PLOW := OS.get_environment("SCEN") == "plow"   # SCEN=plow：不直接叫 smash，改成開尼諾拉全速撞穿房子
var _boss: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _f_steps := 0        # 這一幀跑了幾步物理
var _f_pp_us := 0        # 這一幀第一步物理開始的時刻
var _f_boss := 0.0       # 這一幀尼諾拉移動花的毫秒
var _move_ms := 0.0      # 尼諾拉移動一步（含撞、踢）最久幾毫秒
var _windowed := DisplayServer.get_name() != "headless"


func _env(k: String, d: float) -> float:
	return OS.get_environment(k).to_float() if OS.get_environment(k) != "" else d


func _initialize() -> void:
	if OS.get_environment("HITCH_MS") == "":
		load("res://main.gd").HITCH_MS = 30   # 遊戲自己的「主機停頓」記錄門檻（平常 50）調低，一起印出來對照
	if _role != "server":
		# 沒畫面的 Godot 每幀固定睡 6.9 毫秒（low_processor_usage_mode_sleep_usec），兩幀的間隔＝睡覺＋真正做事的時間，會多算 6.9。
		# 關掉才量得到「這一幀做了多久」；伺服器照真的開法（60 幀＋睡覺），不動
		OS.low_processor_usage_mode_sleep_usec = 1
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		if _role == "":
			_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			_m._offline = true
			ToyBuild.no_flight = OS.get_environment("NOFLIGHT") != ""
			_m._enter_game("probe")
			_m.bake_nav()
			if _windowed:
				var cam := Camera3D.new()
				root.add_child(cam)
				cam.current = true
				cam.set_meta(&"probe", true)
		elif _role == "client":
			Engine.max_fps = 120   # 不睡覺會一秒跑幾千幀，同一毫秒裡好幾幀，「畫面不動」會數錯；鎖在一般螢幕的幀率
			var join := OS.get_environment("JOIN")   # LAG=1 時指到 tools/lag_proxy.py
			_m.ip_edit.text = join if join != "" else "127.0.0.1"
			_m.player_key = "smooth-probe" + OS.get_environment("IDX")   # 多個客戶端在同一台，代號要不一樣
			_m._on_join_pressed()
	if _f < 3:
		return false
	if _role == "client":
		return _client(d)
	if not _started:
		if _role == "server" and _peer_players() < maxi(int(_env("CLIENTS", 1.0)), 1):
			return _f > 60 * 60   # 一分鐘沒人連就放棄
		_started = true
		for tb: ToyBuild in _m.map._toys:
			if tb.can_break and tb.visible and tb.brick_count() > 200:
				_houses.append(tb)
		_houses.sort_custom(func(a: ToyBuild, b: ToyBuild) -> bool: return a.brick_count() > b.brick_count())
		_houses = _houses.slice(0, NH)
		if OS.get_environment("PROFILE") != "":
			_profile()
			return true
		_begin("空轉")
		return false
	_sample(d)
	if _role == "server":
		for p: Node in _m.players.get_children():
			var c: Variant = p.get(&"_net_corrected")
			if c != null and c != _fix_seen.get(p.name, c):
				_fixes += 1
			_fix_seen[p.name] = c
	if _t < (IDLE if _hi < 0 or _hi >= _houses.size() else GAP):
		return false
	_report()
	_hi += 1
	if _hi > _houses.size():
		print("SMOOTH OK")
		return true
	if _hi == _houses.size():
		_begin("滿場碎塊空轉")
		return false
	var h: ToyBuild = _houses[_hi]
	var bb: AABB = h.global_transform * h._all
	var at := Vector3(bb.position.x, h.global_position.y, bb.position.z)   # 牆角的地面
	if _windowed and _role == "":
		var cam := root.get_children().filter(func(n: Node) -> bool: return n.has_meta(&"probe"))[0] as Camera3D
		cam.look_at_from_position(bb.get_center() + Vector3(-25, 12, -25), bb.get_center())
	if PLOW:   # 尼諾拉全速跑過去撞穿，後半段再跑回來（踢碎塊）；照 tools/debris_walk.gd 的開法
		if _boss == null:
			_boss = _m._boss() if _m._boss() else _m.spawn_boss()
			_boss.set_physics_process(false)
			_boss._sync_mask()
			_boss.pilot = 1
		var dir := Vector3(cos(0.3 * _hi), 0, sin(0.3 * _hi))
		_from = bb.get_center() - dir * 22.0
		_to = bb.get_center() + dir * 16.0
		_boss.global_position = _m.boss_on_ground(_from)
		_boss.velocity = Vector3.ZERO
		_begin("尼諾拉撞穿第 %d 棟（%d 塊）再跑回來" % [_hi + 1, h.brick_count()])
		return false
	_begin("拆第 %d 棟（%d 塊）" % [_hi + 1, h.brick_count()])
	var t0 := Time.get_ticks_usec()
	h.smash(func(p: Vector3) -> bool: return p.distance_to(at) < R, 2, at)
	print("  smash 呼叫本身 %.1f 毫秒，鬆脫後碎塊 %d 個、排隊落地 %d 塊" % [(Time.get_ticks_usec() - t0) / 1000.0, h._pieces.size(), h._land_q.size()])
	return false


func _physics_process(delta: float) -> bool:
	if _f_steps == 0:
		_f_pp_us = Time.get_ticks_usec()
	_f_steps += 1
	if _boss == null or _hi < 0 or _hi >= _houses.size():
		return false
	var d := (_to if _t < GAP * 0.5 else _from) - _boss.global_position
	d.y = 0.0
	if d.length() < 2.0:
		return false
	_boss.rotation.y = atan2(-d.x, -d.z)
	_boss.stamina = _boss.STAMINA_MAX
	_boss.exhausted = false
	var t0 := Time.get_ticks_usec()
	_boss._move(d.normalized(), true, delta)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_move_ms = maxf(_move_ms, ms)
	_f_boss += ms
	return false


func _begin(name: String) -> void:
	_move_ms = 0.0
	_phase = name
	_t = 0.0
	_gaps.clear(); _worst.clear(); _draws.clear(); _tris.clear()
	_last_us = Time.get_ticks_usec()
	_bytes0 = _net_bytes()


func _sample(d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_t += d
	_gaps.append(ms)
	if ms > FRAME_MS:
		# 這一幀拆開看：跑了幾步物理、物理開始前等了多久（上一幀的 _process、畫面、鎖幀率的睡覺）、尼諾拉那一步、其他物理（節點的 _physics_process＋引擎）
		var before := ((_f_pp_us if _f_steps > 0 else now) - (now - int(ms * 1000.0))) / 1000.0
		_worst.append([ms, _t, _f_steps, before, _f_boss, ms - before - _f_boss])
	_f_steps = 0
	_f_boss = 0.0
	if _windowed:
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_tris.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _report() -> void:
	var g := _gaps.duplicate()
	g.sort()
	if g.is_empty():
		return
	var over := 0.0   # 超過 16.7 毫秒的部分加起來（卡住的總時間）
	for ms in g:
		over += maxf(ms - FRAME_MS, 0.0)
	_worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var s := "順暢 [%s%s] %s：%d 幀，中位 %.2f、p95 %.2f、p99 %.2f、最久 %.1f 毫秒；掉幀（>16.7）%d 次共卡 %.0f 毫秒、>33 的 %d 次、>50 的 %d 次；碎塊 %d" % [
		_role if _role != "" else "單機", "／落地" if ToyBuild.no_flight else "", _phase, g.size(), g[g.size() / 2], g[int(g.size() * 0.95)], g[int(g.size() * 0.99)], g[-1],
		_worst.size(), over, g.size() - g.bsearch(33.0), g.size() - g.bsearch(50.0), _m.get_tree().get_nodes_in_group(&"toy_piece").size()]
	if not _worst.is_empty():
		s += "；最慢的幾幀（毫秒@第幾秒）" + str(_worst.slice(0, 4).map(func(w: Array) -> String: return "%.0f@%.1f（物理 %d 步、物理前 %.1f、尼諾拉 %.1f、其他物理 %.1f）" % w))
	if PLOW and _boss:
		s += "；尼諾拉一步最久 %.1f 毫秒" % _move_ms
	if _windowed:
		var dr := _draws.duplicate(); dr.sort()
		var tr := _tris.duplicate(); tr.sort()
		s += "；繪製指令中位 %d、三角形 %d 萬" % [dr[dr.size() / 2], tr[tr.size() / 2] / 10000.0]
	if _role == "server":
		s += "；網路送出共 %.1f KB／秒（%d 個客戶端）、拉回玩家 %d 次" % [(_net_bytes() - _bytes0) / 1024.0 / maxf(_t, 0.01), _m.multiplayer.get_peers().size(), _fixes]
	print(s)


## ENet 累計送出的位元組（伺服器才看）
func _net_bytes() -> int:
	var p := _m.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if p == null or p.host == null:
		return 0
	_bytes_total += int(p.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
	return _bytes_total
var _bytes_total := 0


## 已經連上、生出來的客戶端玩家有幾個
func _peer_players() -> int:
	var n := 0
	for p: Node in _m.players.get_children():
		if p.name.to_int() in _m.multiplayer.get_peers():
			n += 1
	return n


## 客戶端：連上、生出來之後一直來回跑（同 net_check.gd 的 A），量到伺服器關掉為止，整段印一行
var _dir := 1.0
var _turn := 0.0
func _client(d: float) -> bool:
	var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
	var on := mp != null and not mp is OfflineMultiplayerPeer and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if not _started:
		if on and _m.players.has_node(NodePath(str(_m.multiplayer.get_unique_id()))):
			_started = true
			_begin("整段（伺服器拆房子的時候在場上來回跑）")
		return _f > 60 * 120
	if not on or _m.lobby.visible:   # 伺服器關了：收工
		_report()
		_sent_gaps.sort()
		if not _sent_gaps.is_empty():
			print("順暢 [client] 尼諾拉的位置包：收到 %d 包，間隔中位 %.0f、p99 %.0f、最久 %.0f 毫秒；畫面上尼諾拉停住（等不到新的包）%d 幀、最久連續 %.0f 毫秒；畫面真的不動（畫面該走的那一段在走、畫面位置沒變）%d 幀、最久連續 %.0f 毫秒" % [
				_sent_gaps.size(), _sent_gaps[_sent_gaps.size() / 2], _sent_gaps[int(_sent_gaps.size() * 0.99)], _sent_gaps[-1], _starved, _starve_max, _vis_frozen, _vis_max])
		print("SMOOTH OK")
		return true
	_sample(d)
	_watch_boss()
	var me: Node3D = _m.players.get_node_or_null(NodePath(str(_m.multiplayer.get_unique_id())))
	if me and me.get(&"sprint_speed") != null:
		_turn -= d
		if _turn <= 0.0:
			_dir = -_dir
			_turn = 3.0
		me.global_position.x += _dir * me.sprint_speed * 0.95 * d
	return false


## 客戶端看尼諾拉順不順：照 fighter.gd net_step 的算法，這一幀要畫的時刻已經超過手上最新的一包＝畫面上牠停住不動
var _sent_gaps := PackedFloat32Array()   # 主機送出位置包的間隔（毫秒）
var _last_sent := -1.0
var _starved := 0
var _starve_run := 0.0
var _starve_max := 0.0
var _vis_frozen := 0          # 畫面真的不動：畫面這一刻該用的那一段速度 > 0.5 公尺／秒，可是這一幀畫面上的位置跟上一幀一樣
var _vis_run := 0.0
var _vis_max := 0.0
var _prev_pos := Vector3.INF
func _watch_boss() -> void:
	var b := _m.get_tree().get_first_node_in_group(&"boss")
	if b == null or (b._snaps as Array).is_empty():
		return
	var snaps: Array = b._snaps
	var last: Array = snaps[-1]
	if _last_sent >= 0.0 and last[0] != _last_sent:
		_sent_gaps.append(last[0] - _last_sent)
	_last_sent = last[0]
	var off := INF
	for sn: Array in snaps:
		off = minf(off, sn[1] - sn[0])
	if float(Time.get_ticks_msec()) - off - b.NET_DELAY >= last[0]:
		_starved += 1
		_starve_run += _gaps[-1]
		_starve_max = maxf(_starve_max, _starve_run)
	else:
		_starve_run = 0.0
	# 這一幀畫面要的時刻（同 fighter.gd net_step）落在哪一段，那一段的速度才算數（不然剛開始走的時候，畫面還慢 60 毫秒，會誤算成停住）
	var t: float = float(Time.get_ticks_msec()) - off - float(b.NET_DELAY)
	var vel := 0.0
	if snaps.size() >= 2:
		var seg := snaps.size() - 1
		for i in range(snaps.size() - 1, 0, -1):
			if (snaps[i - 1] as Array)[0] <= t:
				seg = i
				break
		var a: Array = snaps[seg - 1]
		var bn: Array = snaps[seg]
		vel = ((bn[2] as Vector3) - (a[2] as Vector3)).length() / maxf((bn[0] - a[0]) / 1000.0, 0.001)
	if vel > 0.5 and b.global_position.distance_to(_prev_pos) < 0.001:
		_vis_frozen += 1
		_vis_run += _gaps[-1]
		_vis_max = maxf(_vis_max, _vis_run)
	else:
		_vis_run = 0.0
	_prev_pos = b.global_position


## 逐項計時：直接叫 toy_build.gd、main.gd 裡的步驟，各自量幾毫秒（找卡頓是誰造成的）
func _profile() -> void:
	var h: ToyBuild = _houses[0]
	var n := h.brick_count()
	var bb: AABB = h.global_transform * h._all
	var at := Vector3(bb.position.x, h.global_position.y, bb.position.z)
	_m.nav_budget_ms = 0.0   # 重烘導航一次做完才量得到整段
	print("計時：最大的一棟 %d 塊，場上積木 %d 棟共 %d 塊" % [n, _m.map._toys.size(), _m.map._toys.reduce(func(a: int, t: ToyBuild) -> int: return a + t.brick_count(), 0)])
	_time("建鄰居表 _ensure_grid（每棟第一次拆才建）", func() -> void: h._ensure_grid())
	_time("連通檢查 _unsupported", func() -> void: h._unsupported(h._loose))
	_time("拆（甩尾半徑）smash：算＋生碎塊", func() -> void: h.smash(func(p: Vector3) -> bool: return p.distance_to(at) < R, 2, at))
	print("    → 碎塊 %d 個、排隊落地 %d 塊" % [h._pieces.size(), h._land_q.size()])
	_time("落完排隊的碎塊 _flush（遊戲裡分幀做）", func() -> void: h._flush())
	var ids := PackedInt32Array()
	var xfs := []
	for k: int in h._pieces:
		if h._pieces[k] is RigidBody3D:
			ids.append(k)
			xfs.append(h._pieces[k].global_transform)
	_time("碎塊停下 _settle（%d 個飛的換成靜態，一幀做完）" % ids.size(), func() -> void: h._settle(ids, xfs))
	_time("晚加入補送 state", func() -> void: h.state())
	_time("重烘導航 _bake_nav 主線程解析（拆過 1 棟）", func() -> void: _m._bake_nav())
	_time("還原 restore（新的一場，1 棟）", func() -> void: h.restore())
	_time("整棟一次拆光 smash（最壞：全部塊都中）", func() -> void: h.smash(func(_p: Vector3) -> bool: return true, 2, at))
	print("    → 碎塊 %d 個、排隊落地 %d 塊" % [h._pieces.size(), h._land_q.size()])
	_time("    其中 _flush", func() -> void: h._flush())
	h.restore()
	# 一次鬆脫 150 塊、每塊一個碎塊（尼諾拉撞穿牆最常走的路）：拆開來量每一步
	var top := PackedInt32Array()
	for i in range(n - 1, -1, -1):
		if top.size() < ToyBuild.MAX_PIECES and h._lv[i] < 3 and h._sidx[i] >= 0:
			top.append(i)
	top.sort()
	_time("鬆脫 150 塊 _break（客戶端的路：150 個會飛的碎塊）", func() -> void: h._break(top, PackedInt32Array(), at, ToyBuild.FALL_SPEED, Vector3.ZERO))
	_time("    150 個碎塊停下 _settle（刪掉飛的、各生一個靜態的）", func() -> void: h._settle(top, top_xf(h, top)))
	h.restore()
	_time("    其中：藏 150 塊 _hide_bricks", func() -> void: h._hide_bricks(top))
	_time("    其中：生 150 個碎塊節點 _spawn＋_make", func() -> void:
		for i in top: h._spawn(PackedInt32Array([i]), h._xf[i], h.global_transform * h._xf[i], true))
	h.restore()
	ToyBuild.no_flight = true
	_time("鬆脫 150 塊 _break（伺服器的路：直接落地）", func() -> void: h._break(top, PackedInt32Array(), at, ToyBuild.FALL_SPEED, Vector3.ZERO))
	var none: Array[RID] = []
	_time("    其中：150 次往下掃找落點 _land", func() -> void:
		for i in top: h._land(h.global_transform * h._xf[i], h._info[i].box, none))
	_time("    踢 30 個落地的碎塊 _kick（刪掉、掃落點、再生）", func() -> void:
		for i in top.slice(0, 30): h._kick(i, Vector3(5, 0, 0)))
	ToyBuild.no_flight = false
	h.restore()
	var k := 0
	for t: ToyBuild in _m.map._toys:   # 全場都拆過的最壞情況
		if t.can_break and t.visible and t != h:
			var c: Vector3 = t.global_transform * t._all.get_center()
			t.smash(func(p: Vector3) -> bool: return p.distance_to(c) < R, 2, c)
			t._flush()
			k += 1
	_time("重烘導航 _bake_nav 主線程解析（全場 %d 棟都拆過、碎塊 %d）" % [k + 1, _m.get_tree().get_nodes_in_group(&"toy_piece").size()], func() -> void: _m._bake_nav())
	_time("新的一場：拆過的全部還原 restore（同一幀）", func() -> void:
		for t: ToyBuild in _m.map._toys:
			if t.has_damage(): t.restore())
	print("SMOOTH OK")


func top_xf(h: ToyBuild, ids: PackedInt32Array) -> Array:
	var out := []
	for i in ids:
		out.append((h._pieces[i] as Node3D).global_transform)
	return out


func _time(what: String, fn: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	fn.call()
	print("  %7.1f 毫秒  %s" % [(Time.get_ticks_usec() - t0) / 1000.0, what])
