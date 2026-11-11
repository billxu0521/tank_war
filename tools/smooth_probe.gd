extends SceneTree
## 量「順不順」（docs/規劃/2026-11-10-遊戲順暢.md）：照固定劇本拆房子，量兩幀之間真的隔多久（Time.get_ticks_usec，不看 Performance 的幀時間）。
## 劇本：先空轉 IDLE 秒 → 每 GAP 秒拆一棟（最大的 HOUSES 棟，在牆腳用甩尾的半徑拆，碎塊留著不還原）→ 最後再空轉 IDLE 秒（滿場碎塊）。
##   單機（客戶端的路：碎塊會飛）    godot --headless --path . --script tools/smooth_probe.gd
##   單機、伺服器的路（碎塊直接落地）  NOFLIGHT=1 godot --headless --path . --script tools/smooth_probe.gd
##   開視窗（多印繪製指令、三角形）    godot --path . --disable-vsync --resolution 1920x1080 --script tools/smooth_probe.gd
##   尼諾拉真的跑去撞（碎塊多、會踢）  SCEN=plow godot --headless --path . --script tools/smooth_probe.gd
##   逐項計時（找誰最慢）            PROFILE=1 godot --headless --path . --script tools/smooth_probe.gd
##   真的連線（伺服器＋客戶端）       tools/smooth_probe.sh
##   照玩家的玩法（恐龍沙盒、自己開尼諾拉，要開視窗）  VSYNC=1 SCEN=pilot godot --path . --screen 1 --resolution 1920x1080 --script tools/smooth_probe.gd
##     走大廳「恐龍沙盒」同一個函式、同一個鏡頭，按鍵用 Input 假裝按：全速撞穿 → 甩尾 → 轉身火球 → 跑回來咬。房子之後再撞幾個小的（樹、柵欄、掩體）。
##     --screen 選螢幕（1＝外接的 50 Hz）。掉幀的門檻照那個螢幕：兩幀隔超過 1.5 格＝少畫一張。慢的幀拆成：物理腳本、物理引擎、上一幀的 _process、剩下的（畫面＋等螢幕）
##     最後多一段「一次甩尾掃好幾棟」（MULTI=0 不要）。VSYNC=1／0 開關垂直同步（不給就照玩家的設定檔 user://settings.cfg）、FPS=n 鎖幀率、HOUSES／SMALL 大的小的各幾個。
##     垂直同步關掉又不鎖幀率時，macOS 大約每秒有一幀卡兩格（空專案也量到過），不是遊戲的；前後比要開垂直同步。說明見 docs/技術筆記/拆東西順暢.md
## 每段印一行「順暢 …」；最後一行「SMOOTH OK」才算跑完（Godot 解析錯誤也回 0）。

var FRAME_MS := 16.7   # 超過算掉幀（每秒 60 張的一幀；SCEN=pilot 照螢幕的更新率，1.5 格）

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
var _multi: ToyBuild      # SCEN=pilot 最後一段：周圍積木最多的那一個
var _multi_i := -1        # 那一段是 _houses 的第幾個
var _multi_hit := 0       # 甩之前場上挨過打的積木有幾棟
var PILOT := OS.get_environment("SCEN") == "pilot"   # SCEN=pilot：照玩家的玩法，見檔頭
var _f_script := 0.0     # 這一幀物理腳本（所有節點的 _physics_process）共幾毫秒
var _f_engine := 0.0     # 這一幀物理引擎（Jolt 一步＋導航同步＋延後呼叫）共幾毫秒
var _f_proc := 0.0       # 上一幀所有節點的 _process 共幾毫秒
var _proc_us := 0        # 這一幀 _process 開始的時刻
var _tick_us := 0        # 這一步物理開始的時刻
var _tail_us := 0        # 這一步物理腳本跑完的時刻（_Tail 節點記的；0＝這一步的引擎時間已經算過）
var _tick_script := 0.0  # 這一段裡，一步物理的腳本最久幾毫秒
var _tick_engine := 0.0  # 這一段裡，一步物理的引擎最久幾毫秒
var _tick_now := 0.0     # 這一步物理的腳本幾毫秒（等引擎那段量到再加起來）
var _tick_all := PackedFloat32Array()   # 這一段每一步物理共幾毫秒（腳本＋引擎）


## 排在所有節點後面跑的 _physics_process：記「物理腳本跑完」的時刻
class _Tail extends Node:
	var probe: Object
	func _physics_process(_d: float) -> void:
		probe._tail_us = Time.get_ticks_usec()
		var ms: float = (probe._tail_us - probe._tick_us) / 1000.0
		probe._f_script += ms
		probe._tick_now = ms
		probe._tick_script = maxf(probe._tick_script, ms)
	func _process(_d: float) -> void:   # 所有節點的 _process 跑完：這一幀的 _process 腳本共幾毫秒（下一幀取樣時用）
		probe._f_proc = (Time.get_ticks_usec() - probe._proc_us) / 1000.0


## 上一步物理腳本跑完到現在＝引擎那一段
func _close_tick() -> void:
	if _tail_us == 0:
		return
	var ms := (Time.get_ticks_usec() - _tail_us) / 1000.0
	_tail_us = 0
	_f_engine += ms
	_tick_engine = maxf(_tick_engine, ms)
	_tick_all.append(_tick_now + ms)


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
	_close_tick()
	_f += 1
	if _f == 2:
		var tail := _Tail.new()
		tail.probe = self
		tail.process_physics_priority = 1000000
		tail.process_priority = 1000000
		root.add_child(tail)
		if PILOT:
			# 垂直同步、幀率上限照玩家自己的設定檔（user://settings.cfg，main.gd 開場就套了）；VSYNC=1／0 蓋掉、FPS=n 鎖幀率
			if OS.get_environment("VSYNC") != "":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if OS.get_environment("VSYNC") == "1" else DisplayServer.VSYNC_DISABLED)
			if OS.get_environment("FPS") != "":
				Engine.max_fps = int(OS.get_environment("FPS"))
			FRAME_MS = 1500.0 / DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
			print("螢幕 %d，%.0f Hz，垂直同步%s，幀率上限 %d，兩幀隔超過 %.1f 毫秒算掉幀" % [DisplayServer.window_get_current_screen(), 1500.0 / FRAME_MS,
				"開" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "關", Engine.max_fps, FRAME_MS])
			_m._on_dino_sandbox_pressed()   # 大廳「恐龍沙盒」按鈕的同一個函式
		elif _role == "":
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
		if PILOT:   # 再加幾個小的（樹、柵欄、掩體：塊數不一樣的各挑一個），看是不是只有房子會卡
			var seen := {}
			for tb: ToyBuild in _m.map._toys:
				if tb.can_break and tb.visible and tb.brick_count() <= 200 and not seen.has(tb.brick_count()) and seen.size() < int(_env("SMALL", 4.0)):
					seen[tb.brick_count()] = true
					_houses.append(tb)
			_boss = _m._boss()
			_multi = _cluster()   # 最後加一段「一次甩尾掃好幾棟」（到時候再挑一次還沒拆過的）
			if _multi and OS.get_environment("MULTI") != "0":
				_houses.append(_multi)
				_multi_i = _houses.size() - 1
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
	if _windowed and _role == "" and not PILOT:
		var cam := root.get_children().filter(func(n: Node) -> bool: return n.has_meta(&"probe"))[0] as Camera3D
		cam.look_at_from_position(bb.get_center() + Vector3(-25, 12, -25), bb.get_center())
	if PILOT:
		var dir := Vector3(cos(0.3 * _hi), 0, sin(0.3 * _hi))
		_from = bb.get_center() - dir * 22.0
		_to = bb.get_center()
		_boss.global_position = _m.boss_on_ground(_from)
		_boss.velocity = Vector3.ZERO
		_boss.rotation.y = atan2(-dir.x, -dir.z)
		_boss._cam_yaw = _boss.rotation.y
		_boss.reset_physics_interpolation()
		if _hi == _multi_i:   # 站在那一堆旁邊、背對它（甩尾只掃後方半圈）
			_multi = _cluster()
			bb = _multi.global_transform * _multi._all
			_boss.global_position = _m.boss_on_ground(bb.get_center() + dir * 5.0)
			_boss.sweep_left = 0.0   # 上一段剛甩過，冷卻還沒好
			_multi_hit = _m.map._toys.filter(func(t: ToyBuild) -> bool: return t.has_damage()).size()
			_begin("駕駛：一次甩尾掃好幾棟")
			return false
		_begin("駕駛：撞穿、甩尾、火球、咬 第 %d 個（%d 塊）" % [_hi + 1, h.brick_count()])
		return false
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
	_close_tick()
	_tick_us = Time.get_ticks_usec()
	if _f_steps == 0:
		_f_pp_us = Time.get_ticks_usec()
	_f_steps += 1
	if PILOT:
		_drive()
		return false
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


## 周圍 10 公尺內「可拆、還沒拆過」的積木最多的那一個
func _cluster() -> ToyBuild:
	var ok: Array = _m.map._toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t.visible and not t.has_damage())
	var best: ToyBuild
	var most := 0
	for a: ToyBuild in ok:
		var ca: Vector3 = a.global_transform * a._all.get_center()
		var n := ok.filter(func(t: ToyBuild) -> bool: return (t.global_transform * t._all.get_center()).distance_to(ca) < 10.0).size()
		if n > most:
			most = n
			best = a
	return best


## SCEN=pilot 的按鍵（每步物理設一次，boss.gd 的 _pilot_local 照常讀 Input）：
## 0～3.5 秒 往前全速跑（撞穿）→ 3.5～4 右鍵甩尾（尾巴朝剛撞穿的那棟）→ 5.5 轉身、Q 火球 → 6.5 之後跑回來、7.5 咬
func _drive() -> void:
	var on := _boss != null and _hi >= 0 and _hi < _houses.size()
	var multi := _hi == _multi_i   # 這一段只甩尾（第 1 秒按）
	var run := on and not multi and (_t < 3.5 or _t > 6.5)
	var keys := {&"move_forward": run, &"sprint": run, &"aim": on and (_t > 1.0 and _t < 1.5 if multi else _t > 3.5 and _t < 4.0),
		&"dino_fireball": on and not multi and _t > 5.5 and _t < 5.8, &"fire": on and not multi and _t > 7.5 and _t < 7.7}
	for k: StringName in keys:
		if keys[k]:
			Input.action_press(k)
		else:
			Input.action_release(k)
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 沒抓滑鼠 _pilot_local 不送按鍵
		_boss.stamina = _boss.STAMINA_MAX
		_boss.exhausted = false
		if _t > 5.5 and not multi:   # 轉身看回那一棟
			var d := _to - _boss.global_position
			_boss._cam_yaw = atan2(-d.x, -d.z)


func _begin(name: String) -> void:
	_tick_script = 0.0
	_tick_engine = 0.0
	_tick_all.clear()
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
		_worst.append([ms, _t, _f_steps, _f_script, _f_engine, _f_proc, ms - _f_script - _f_engine - _f_proc] if PILOT else [ms, _t, _f_steps, before, _f_boss, ms - before - _f_boss])
	_f_steps = 0
	_f_boss = 0.0
	_f_script = 0.0
	_f_engine = 0.0
	if _windowed:
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_tris.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_proc_us = Time.get_ticks_usec()


func _report() -> void:
	var g := _gaps.duplicate()
	g.sort()
	if g.is_empty():
		return
	var over := 0.0   # 超過 16.7 毫秒的部分加起來（卡住的總時間）
	for ms in g:
		over += maxf(ms - FRAME_MS, 0.0)
	_worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var s := "順暢 [%s%s] %s：%d 幀，中位 %.2f、p95 %.2f、p99 %.2f、最久 %.1f 毫秒；掉幀（>%.1f）%d 次共卡 %.0f 毫秒、>33 的 %d 次、>50 的 %d 次；碎塊 %d" % [
		_role if _role != "" else "單機", "／落地" if ToyBuild.no_flight else "", _phase, g.size(), g[g.size() / 2], g[int(g.size() * 0.95)], g[int(g.size() * 0.99)], g[-1],
		FRAME_MS, _worst.size(), over, g.size() - g.bsearch(33.0), g.size() - g.bsearch(50.0), _m.get_tree().get_nodes_in_group(&"toy_piece").size()]
	if PILOT:
		var ta := _tick_all.duplicate()
		ta.sort()
		s += "；物理一步（腳本＋引擎）最久 %.1f 毫秒、超過 4 毫秒的 %d 步、超過 8.3 的 %d 步（共 %d 步）；一步最久：腳本 %.1f、引擎 %.1f 毫秒" % [
			ta[-1] if not ta.is_empty() else 0.0, ta.size() - ta.bsearch(4.0), ta.size() - ta.bsearch(8.3), ta.size(), _tick_script, _tick_engine]
		if _hi == _multi_i:
			s += "；這一下新拆到 %d 棟" % (_m.map._toys.filter(func(t: ToyBuild) -> bool: return t.has_damage()).size() - _multi_hit)
		if not _worst.is_empty():
			s += "；最慢的幾幀（毫秒@第幾秒）" + str(_worst.slice(0, 5).map(func(w: Array) -> String: return "%.0f@%.1f（物理 %d 步、物理腳本 %.1f、物理引擎 %.1f、上一幀的 _process %.1f、畫面和等螢幕 %.1f）" % w))
	elif not _worst.is_empty():
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
	_time("鬆脫 150 塊 _break＋_flush（客戶端的路：150 個會飛的碎塊；遊戲裡一步只生 SPAWN_PER_TICK 個）", func() -> void:
		h._break(top, PackedInt32Array(), at, ToyBuild.FALL_SPEED, Vector3.ZERO)
		h._flush())
	_time("    150 個碎塊停下 _settle（刪掉飛的、各生一個靜態的）", func() -> void: h._settle(top, top_xf(h, top)))
	h.restore()
	_time("    其中：藏 150 塊 _hide_bricks", func() -> void: h._hide_bricks(top))
	_time("    其中：生 150 個碎塊節點 _spawn＋_make", func() -> void:
		for i in top: h._spawn(PackedInt32Array([i]), h._xf[i], h.global_transform * h._xf[i], true)
		h._flush())
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
