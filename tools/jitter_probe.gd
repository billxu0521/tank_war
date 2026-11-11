extends SceneTree
## 量「駕駛尼諾拉撞房子時鏡頭抖不抖」：每一張畫面記鏡頭在哪、被拉近多少、抖動偏移、身體動了多少、這一幀跑幾步物理。
## 劇本（每段 SEC 秒）：空地邊跑邊轉 → 全速撞穿一排房子 → 撞進房子後在廢墟裡繞圈 → 用走的頂著大樓的牆（走路拆不動）→ 用跑的撞安全屋（拆不動，偏一點會滑開）。
##   單機（自己當主機）      godot --headless --path . --script tools/jitter_probe.gd
##   開視窗（照螢幕的幀率）  godot --path . --resolution 1280x720 --script tools/jitter_probe.gd
##   連線（駕駛是客戶端）    tools/jitter_probe.sh
##   每一幀的原始數字        CSV=/某個資料夾 godot --headless ...（每段一個 .csv）
## 每段印一行「抖動 …」；最後一行「JITTER OK」才算跑完（Godot 解析錯誤也回 0）。
## 「急轉」＝這一幀的速度跟上一幀差超過 JOLT 公尺／秒（60 幀下一幀差 5 公分）；「來回」＝連兩幀速度方向相反（真的在抖）。
## 分開看：鏡頭在世界裡、鏡頭相對身體（扣掉身體的移動，只剩拉近）、身體自己、抖動偏移（add_shake）、鏡頭水平角、骨架停頓（hitstop）。

const JOLT := 3.0
const PHASES := ["空地跑", "全速撞穿一排房子", "撞進房子後在廢墟裡繞圈", "走路頂牆", "跑步撞拆不動的安全屋"]
## 每段的起點和面向（-PI/2 朝 +x）。照灰盒地圖的房子位置寫死：北邊一排七棟（z -72～-60）、第二排（z -42～-32）、西邊的大樓（x -68～-54）、東北角的安全屋（x 64～68、z -66～-62，拆不動）。
## 都不走正中間（大樓的門尼諾拉過得去，會直接穿過）。地圖改了這裡要跟著改
const STARTS := [
	[Vector3(0, 0, 10), PI * 0.5],
	[Vector3(-58, 0, -67), -PI * 0.5],
	[Vector3(-56, 0, -38), -PI * 0.5],
	[Vector3(-44.5, 0, -25), PI * 0.5],
	[Vector3(65, 0, -44), 0.0],
]
var SEC := 10.0
var FPS := 60 if DisplayServer.get_name() == "headless" else 0   # 開視窗就照螢幕（垂直同步）
var _role := OS.get_environment("ROLE")   # ""＝單機、server、client
var _csv := OS.get_environment("CSV")
var _m: Node
var _f := 0
var _boss: Node3D
var _phase := -1
var _t := 0.0
var _steps := 0
var _rows: Array = []
var _tap: Node
var _yaw := 0.0
var _last_us := 0
var _client_id := 0
var _seen_phase := -1


func _initialize() -> void:
	if OS.get_environment("SEC") != "":
		SEC = OS.get_environment("SEC").to_float()
	if OS.get_environment("FPS") != "":
		FPS = OS.get_environment("FPS").to_int()
	if _role != "server":
		OS.low_processor_usage_mode_sleep_usec = 1
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	# 排在所有節點後面跑：這一幀鏡頭已經擺好才量
	_tap = Node.new()
	_tap.process_priority = 1000
	_tap.process_physics_priority = 1000
	_tap.set_script(_tap_script())
	_tap.set("probe", self)
	root.add_child(_tap)


func _tap_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar probe\nfunc _process(d: float) -> void:\n\tprobe.frame(d)\nfunc _physics_process(d: float) -> void:\n\tprobe.tick(d)\n"
	s.reload()
	return s


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		if _role != "server" and FPS > 0:
			Engine.max_fps = FPS   # 沒畫面時不鎖會一秒跑幾千幀；main.gd 的設定會改這個，所以進場後才設
		if _role == "":
			_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			_m._offline = true
			_m._enter_game("probe")
		elif _role == "client":
			var join := OS.get_environment("JOIN")   # LAG=1 時指到 tools/lag_proxy.py
			_m.ip_edit.text = join if join != "" else "127.0.0.1"
			_m.player_key = "jitter-probe"
			_m._on_join_pressed()
	# 鏡頭的角度每一張畫面改一次（真的滑鼠也是每幀進來），排在尼諾拉的 _process 前面
	if _role != "server" and _boss != null and is_instance_valid(_boss) and _phase >= 0 and _phase < PHASES.size():
		if _phase == 0:
			_boss._cam_yaw = _yaw + 2.4 * sin(_t * 1.5)   # 空地：邊跑邊左右甩鏡頭（最快每秒 3.6 弧度，比身體轉得快，身體有時跟得上、有時在後面追）
		elif _phase == 2 and _t > 1.5:
			_boss._cam_yaw += 0.6 * _d   # 撞進去之後一直往左轉：鏡頭的手臂掃過還站著的牆和滿地碎塊
	return _done or Time.get_ticks_msec() > 180000


var _done := false


## 每個物理步（排在尼諾拉後面）：主機照劇本擺位置；駕駛那台送輸入
func tick(_d: float) -> void:
	_steps += 1
	if _f < 3:
		return
	if _role != "client" and _boss == null:
		if _role == "server":
			for id: int in _m.multiplayer.get_peers():
				if _m.players.has_node(NodePath(str(id))):
					_client_id = id
			if _client_id == 0:
				return
		_boss = _m._boss() if _m._boss() else _m.spawn_boss()
		_boss.pilot = _client_id if _role == "server" else 1
		_next()
	if _role == "client":
		if not _online():
			return
		_boss = _m.get_tree().get_first_node_in_group(&"boss")
		if _boss == null or _boss.pilot != _m.multiplayer.get_unique_id():
			return
		# 主機換段時把牠搬走（一步跳超過 4 公尺）：客戶端跟著換段（沒看到就照自己的時間換）
		if _phase < 0 or (_t > 1.0 and _boss.global_position.distance_to(_tick_pos) > 4.0) or _t > SEC + 1.0:
			_report()
			_phase += 1
			_t = 0.0
			if _phase < PHASES.size():
				_yaw = STARTS[_phase][1]
				_boss._cam_yaw = _yaw
		_tick_pos = _boss.global_position
	if _boss == null or _phase < 0 or _phase >= PHASES.size():
		return
	_boss.stamina = _boss.STAMINA_MAX
	_boss.exhausted = false
	if _role == "server":
		return
	# 沒畫面時滑鼠抓不住，尼諾拉自己讀鍵盤（_pilot_local）只會送「沒按」：關掉牠的物理步，這裡照 boss.gd _physics_process 做一樣的事、輸入換成劇本的
	_boss.set_physics_process(false)
	_boss._sync_mask()
	var b: int = _boss.PIN_RUN if _phase != 3 else 0
	_boss._cam_pitch = 0.3 if _phase == 2 else 0.0   # 繞圈那段往上看：鏡頭降到離地很近，手臂會掃到地上的碎塊
	if _role == "client":
		_boss.pilot_input.rpc_id(1, Vector2(0, -1), _boss._cam_yaw, _boss._cam_pitch, b)
	else:
		_boss.pilot_input(Vector2(0, -1), _boss._cam_yaw, _boss._cam_pitch, b)
		_boss.think(_d)
var _tick_pos := Vector3.ZERO


func _online() -> bool:
	var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
	return mp != null and not mp is OfflineMultiplayerPeer and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## 主機：下一段，把尼諾拉擺到起點
func _next() -> void:
	_report()
	_phase += 1
	_t = 0.0
	if _phase >= PHASES.size():
		print("JITTER OK")
		_done = true
		return
	var st: Array = STARTS[_phase]
	_boss.global_position = _m.boss_on_ground(st[0])
	_boss.velocity = Vector3.ZERO
	_boss.rotation.y = st[1]
	_boss.reset_physics_interpolation()
	_yaw = _boss.rotation.y
	_boss._cam_yaw = _yaw
	_boss._pin_yaw = _yaw


## 每一張畫面（排在所有節點後面）
var _pc := Vector3.INF
var _pv := Vector3.ZERO
var _pr := Vector3.INF
var _prv := Vector3.ZERO
var _pb := Vector3.INF
var _pbv := Vector3.ZERO
var _pt := 1.0
var _snap_t := -1.0
var _snap_v := PackedFloat32Array()
var _snap_dt := PackedFloat32Array()
var _po := Vector2.ZERO
var _psv := Vector2.ZERO
func frame(d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	var steps := _steps
	_steps = 0
	if _done:
		return
	if _role == "client" and _phase >= 0 and not _online():   # 伺服器關了：收工
		_report()
		print("JITTER OK")
		_done = true
		return
	if _boss == null or not is_instance_valid(_boss) or not _boss.is_inside_tree() or _phase < 0 or _phase >= PHASES.size():
		return
	_t += d
	if _role != "client" and _t >= SEC:
		_next()
		_pc = Vector3.INF
		return
	if _role == "server" or _t < 0.5 or (_role == "client" and _t > SEC - 0.5):   # 剛擺好的前半秒不算（起步、鏡頭歸位）；客戶端最後半秒也不算（主機可能已經把牠搬去下一段）
		_pc = Vector3.INF
		return
	var cam: Camera3D = _boss.get_node(^"CamPivot/Camera3D")
	# 畫面上的身體（物理插值補過的）接上支點、鏡頭現在的相對位置＝這一幀畫出來的鏡頭。
	# 不直接問鏡頭的 get_global_transform_interpolated：那是這一幀開頭算好的，拿到的是上一幀在 _process 擺的相對位置
	var bx := _boss.get_global_transform_interpolated()
	var piv: Node3D = _boss.get_node(^"CamPivot")
	var cx: Transform3D = cam.global_transform if piv.top_level else bx * piv.transform * cam.transform   # 支點不跟身體（top_level）的話，擺在哪就畫在哪
	# 抖動（h_offset、v_offset，沿鏡頭自己的右、上平移）另外算，這裡的鏡頭位置不含抖動
	var c := cx.origin
	var off := Vector2(cam.h_offset, cam.v_offset)
	var rel := Basis(Vector3.UP, _boss._cam_yaw).inverse() * (c - bx.origin)   # 相對身體（轉到鏡頭的方向：x 右、z 後）
	var fwd := -cx.basis.z
	var yaw_err := wrapf(atan2(-fwd.x, -fwd.z) - _boss._cam_yaw, -PI, PI)   # 畫面上鏡頭的水平角跟玩家要的差多少（應該是 0）
	var starved := false
	if _role == "client" and not (_boss._snaps as Array).is_empty():   # 同 fighter.gd net_step：這一幀要畫的時刻超過最新一包＝照速度往前猜
		var o := INF
		for sn: Array in _boss._snaps:
			o = minf(o, sn[1] - sn[0])
		starved = float(Time.get_ticks_msec()) - o - _boss.NET_DELAY >= _boss._snaps[-1][0]
	if _role == "client" and (_boss._snaps as Array).size() >= 2 and _boss._snaps[-1][0] != _snap_t:   # 新的一包：跟上一包算速度（位置差÷送出時間差）
		var s1: Array = _boss._snaps[-1]
		var s0: Array = _boss._snaps[-2]
		_snap_t = s1[0]
		_snap_v.append(((s1[2] as Vector3) - (s0[2] as Vector3)).length() / maxf((s1[0] - s0[0]) / 1000.0, 0.0001))
		_snap_dt.append(s1[0] - s0[0])
	var row := {t = _t, ms = ms, steps = steps, cam = c, rel = rel, body = bx.origin, yaw = bx.basis.get_euler().y,
		pull = _boss._cam_t.y, side = _boss._cam_t.x, shake = off.length(), quake = _boss._quake, hit = _what_blocks(),
		stop = _boss.get_node(^"Trex").hitstop > 0.0, yaw_err = yaw_err, starved = starved,
		jw = 0.0, jr = 0.0, jb = 0.0, js = 0.0, rw = false, rr = false, rb = false, rs = false, dpull = 0.0}
	if _pc != Vector3.INF and d > 0.0:
		var v := (c - _pc) / d
		var rv := (rel - _pr) / d
		var bv := (bx.origin - _pb) / d
		var sv := (off - _po) / d
		row.jw = (v - _pv).length()
		row.jr = (rv - _prv).length()
		row.jb = (bv - _pbv).length()
		row.js = (sv - _psv).length()
		row.rw = v.dot(_pv) < 0.0 and v.length() > 0.3 and _pv.length() > 0.3
		row.rr = rv.dot(_prv) < 0.0 and rv.length() > 0.3 and _prv.length() > 0.3
		row.rb = bv.dot(_pbv) < 0.0 and bv.length() > 0.3 and _pbv.length() > 0.3
		row.rs = sv.dot(_psv) < 0.0 and sv.length() > 0.3 and _psv.length() > 0.3
		row.dpull = (_boss._cam_t.y - _pt) * _boss.CAM_DIST
		_pv = v; _prv = rv; _pbv = bv; _psv = sv
		_rows.append(row)
	_po = off
	_pc = c; _pr = rel; _pb = bx.origin; _pt = _boss._cam_t.y


## 鏡頭往後那條線現在被什麼擋住（照 boss.gd _cam_clear 的第二條線再打一次）：""、積木（還站著的房子）、飛的碎塊、落地的碎塊、其他
func _what_blocks() -> String:
	var piv: Node3D = _boss.get_node(^"CamPivot")
	var gb := piv.global_basis
	var from: Vector3 = piv.global_position + gb.x * _boss.CAM_SIDE * _boss._cam_t.x
	var hit := _boss.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from + gb.z * _boss.CAM_DIST, Fighter.SOLID_LAYER, [_boss.get_rid()]))
	if hit.is_empty():
		return ""
	var c: Object = hit.collider
	if c is ToyBuild:
		return "積木"
	if c is Node and (c as Node).is_in_group(&"toy_piece"):
		return "飛的碎塊" if c is RigidBody3D else "落地的碎塊"
	return "其他"


func _report() -> void:
	if _rows.size() < 3 or _phase >= PHASES.size():
		_rows.clear()
		return
	_rows.pop_front()   # 第一筆的「上一幀速度」是 0，不算
	var n := _rows.size()
	var c := {jw = 0, jr = 0, jb = 0, rw = 0, rr = 0, rb = 0, rs = 0, snaps = 0, shaky = 0, slow = 0, stop = 0, stops = 0, starved = 0, yaw = 0}
	var mx := {jw = 0.0, jr = 0.0, jb = 0.0, js = 0.0, pin = 0.0, out = 0.0, shake = 0.0, yaw = 0.0}
	var st := {}; var hits := {}
	var was_stop := false
	var pe := 0.0; var pde := 0.0
	for r: Dictionary in _rows:
		for k: String in ["jw", "jr", "jb"]:
			c[k] += 1 if r[k] > JOLT else 0
			mx[k] = maxf(mx[k], r[k])
		for k: String in ["rw", "rr", "rb", "rs"]:
			c[k] += 1 if r[k] else 0
		mx.js = maxf(mx.js, r.js)
		c.snaps += 1 if r.dpull < -0.05 else 0
		mx.pin = maxf(mx.pin, -r.dpull)
		mx.out = maxf(mx.out, r.dpull)
		c.shaky += 1 if r.shake > 0.005 else 0
		mx.shake = maxf(mx.shake, r.shake)
		c.stop += 1 if r.stop else 0
		c.stops += 1 if r.stop and not was_stop else 0
		was_stop = r.stop
		c.starved += 1 if r.starved else 0
		mx.yaw = maxf(mx.yaw, absf(r.yaw_err))
		var de: float = r.yaw_err - pe
		c.yaw += 1 if de * pde < 0.0 and absf(de) > 0.0005 and absf(pde) > 0.0005 else 0   # 0.0005 弧度約 0.03 度（1080p 約半個像素）
		pe = r.yaw_err; pde = de
		st[r.steps] = st.get(r.steps, 0) + 1
		if r.hit != "":
			hits[r.hit] = hits.get(r.hit, 0) + 1
		c.slow += 1 if r.ms > 25.0 else 0
	print("抖動 [%s] %s：%d 幀" % [_role if _role != "" else "單機", PHASES[_phase], n])
	print("    鏡頭（世界，不含抖動偏移）：急轉 %d 幀、來回 %d 幀、最大一幀變速 %.1f 公尺／秒" % [c.jw, c.rw, mx.jw])
	print("    鏡頭相對身體（只剩拉近）：急轉 %d、來回 %d、最大 %.1f；突然拉近（一幀 >5 公分）%d 次、一幀最多拉近 %.2f 公尺、放回最多 %.2f；擋住鏡頭的 %s" % [c.jr, c.rr, mx.jr, c.snaps, mx.pin, mx.out, hits])
	print("    身體：急轉 %d、來回 %d、最大 %.1f%s" % [c.jb, c.rb, mx.jb, "；往前猜的幀 %d" % c.starved if _role == "client" else ""])
	print("    抖動偏移：超過 5 公釐 %d 幀（%d%%）、最大 %.3f 公尺、方向來回 %d 幀、最大一幀變速 %.1f" % [c.shaky, c.shaky * 100 / n, mx.shake, c.rs, mx.js])
	print("    鏡頭水平角偏掉：最大 %.2f 度、來回 %d 幀｜骨架停頓 %d 次共 %d 幀｜每幀物理步數 %s｜超過 25 毫秒的幀 %d" % [rad_to_deg(mx.yaw), c.yaw, c.stops, c.stop, st, c.slow])
	if _snap_v.size() > 10:
		var sv := _snap_v.duplicate(); sv.sort()
		var sd := _snap_dt.duplicate(); sd.sort()
		var med := sv[sv.size() / 2]
		var off := 0
		for v in sv:
			off += 1 if absf(v - med) > 0.2 * maxf(med, 1.0) else 0
		print("    主機的位置包 %d 包：兩包之間算出來的速度 中位 %.1f、5%% %.1f、95%% %.1f 公尺／秒，偏離中位兩成以上 %d 包；間隔 中位 %.0f、最短 %.0f、最長 %.0f 毫秒" % [
			sv.size(), med, sv[sv.size() / 20], sv[sv.size() * 19 / 20], off, sd[sd.size() / 2], sd[0], sd[-1]])
	_snap_v.clear(); _snap_dt.clear()
	if _csv != "":
		var f := FileAccess.open("%s/%s_%d.csv" % [_csv, _role if _role != "" else "solo", _phase], FileAccess.WRITE)
		f.store_line("t,ms,steps,cam_x,cam_y,cam_z,rel_x,rel_y,rel_z,body_x,body_y,body_z,yaw,pull,side,shake,quake,jolt_world,jolt_rel,jolt_body,hit,hitstop,yaw_err,starved")
		for r: Dictionary in _rows:
			f.store_line("%.3f,%.1f,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.4f,%.3f,%.3f,%.4f,%.4f,%.2f,%.2f,%.2f,%s,%d,%.5f,%d" % [
				r.t, r.ms, r.steps, r.cam.x, r.cam.y, r.cam.z, r.rel.x, r.rel.y, r.rel.z, r.body.x, r.body.y, r.body.z, r.yaw, r.pull, r.side, r.shake, r.quake, r.jw, r.jr, r.jb, r.hit, int(r.stop), r.yaw_err, int(r.starved)])
	_rows.clear()
