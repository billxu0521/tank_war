extends SceneTree
## 量「尼諾拉自己的動作抖不抖」（鏡頭的抖是 tools/jitter_probe.gd）：每一張畫面記畫出來的腳、頭、髖在哪，骨頭轉了多少，模型自己算出來的速度。
## 劇本（每段 SEC 秒）：空地走 → 空地繞大圈跑（半徑約 16 公尺，直直跑會撞到東西）→ 邊跑邊轉 → 撞進房子後在廢墟裡繞圈（腳下有碎塊）。
##   單機（自己當主機）      godot --headless --path . --script tools/gait_probe.gd          （FPS=120／50 換幀率；物理固定每秒 120 步）
##   開視窗（照螢幕的幀率）  godot --path . --resolution 1280x720 --script tools/gait_probe.gd
##   連線（看的人是客戶端）  PROBE=tools/gait_probe.gd tools/jitter_probe.sh
##   最後量 trex.gd 一幀花多久：BENCH=1（只有單機）
## 每段印「抖動 …」幾行；最後一行「JITTER OK」才算跑完（Godot 解析錯誤也回 0）。
## 「來回」＝連兩幀往相反方向動，而且兩幀都超過門檻（真的在抖；走路本來的擺動一秒只會來回幾次）。
## 位置都是「畫面上的」：身體用物理插值補過的位置，不是物理步的位置。

const PHASES := ["空地走", "空地繞大圈跑", "邊跑邊轉", "廢墟裡繞圈"]
const STARTS := [[Vector3(0, 0, 10), PI * 0.5], [Vector3(0, 0, 10), PI * 0.5], [Vector3(0, 0, 10), PI * 0.5], [Vector3(-56, 0, -38), -PI * 0.5]]
const BONES := ["spine1", "neck", "head", "tail1", "tail4", "tail8", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const FLIP_DEG := 0.15     # 骨頭一幀轉超過這麼多度、下一幀又反過來轉超過這麼多：算來回
const FLIP_M := 0.004      # 位置同上（公尺）
var SEC := 8.0
var FPS := 60 if DisplayServer.get_name() == "headless" else 0
var _role := OS.get_environment("ROLE")
var _m: Node
var _f := 0
var _boss: Node3D
var _phase := -1
var _t := 0.0
var _steps := 0
var _rows: Array = []
var _tap: Node
var _yaw := 0.0
var _client_id := 0
var _done := false
var _tick_pos := Vector3.ZERO
var _prev := {}
var _range := {}


func _initialize() -> void:
	if OS.get_environment("SEC") != "":
		SEC = OS.get_environment("SEC").to_float()
	if OS.get_environment("FPS") != "":
		FPS = OS.get_environment("FPS").to_int()
	if _role != "server":
		OS.low_processor_usage_mode_sleep_usec = 1
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	_tap = Node.new()
	_tap.process_priority = 1000
	_tap.process_physics_priority = 1000
	var s := GDScript.new()
	s.source_code = "extends Node\nvar probe\nfunc _process(d: float) -> void:\n\tprobe.frame(d)\nfunc _physics_process(d: float) -> void:\n\tprobe.tick(d)\n"
	s.reload()
	_tap.set_script(s)
	_tap.set("probe", self)
	root.add_child(_tap)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		if _role != "server" and FPS > 0:
			Engine.max_fps = FPS
		if _role == "":
			_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			_m._offline = true
			_m._enter_game("probe")
		elif _role == "client":
			var join := OS.get_environment("JOIN")
			_m.ip_edit.text = join if join != "" else "127.0.0.1"
			_m.player_key = "gait-probe"
			_m._on_join_pressed()
	if _role != "server" and _boss != null and is_instance_valid(_boss) and _phase >= 1 and _phase < PHASES.size():
		if _phase == 1:
			_boss._cam_yaw += 0.7 * _d
		elif _phase == 2:
			_boss._cam_yaw = _yaw + 2.4 * sin(_t * 1.5)   # 同 jitter_probe：左右甩，淨前進幾乎是 0，不會跑出空地
		elif _t > 1.5:
			_boss._cam_yaw += 0.6 * _d
	return _done or Time.get_ticks_msec() > 180000


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
		var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
		if mp == null or mp is OfflineMultiplayerPeer or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			if _phase >= 0 and not _done:
				_report()
				print("JITTER OK")
				_done = true
			return
		_boss = _m.get_tree().get_first_node_in_group(&"boss")
		if _boss == null or _boss.pilot != _m.multiplayer.get_unique_id():
			return
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
	_boss.set_physics_process(false)
	_boss._sync_mask()
	var b: int = _boss.PIN_RUN if _phase != 0 else 0
	if _role == "client":
		_boss.pilot_input.rpc_id(1, Vector2(0, -1), _boss._cam_yaw, 0.0, b)
	else:
		_boss.pilot_input(Vector2(0, -1), _boss._cam_yaw, 0.0, b)
		_boss.think(_d)


func _next() -> void:
	_report()
	_phase += 1
	_t = 0.0
	if _phase >= PHASES.size():
		if OS.get_environment("BENCH") != "" and _role == "":
			_bench()
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


## 畫面上的骨架在世界裡的位置：恐龍模型自己每幀擺（top_level）就是它現在的位置，不然是「補過的身體」接上骨架相對身體的位置
func _skel_xf(trex: Node3D) -> Transform3D:
	var sk: Skeleton3D = trex.skel
	if trex.top_level:
		return sk.global_transform
	return _body_xf() * (_boss.global_transform.affine_inverse() * sk.global_transform)


## 畫面上的身體：物理插值補過的；別人同步來的（自己每幀補、關掉物理插值）就是現在的位置
func _body_xf() -> Transform3D:
	return _boss.get_global_transform_interpolated() if _boss.is_physics_interpolated_and_enabled() else _boss.global_transform


func frame(d: float) -> void:
	var steps := _steps
	_steps = 0
	if _done or _boss == null or not is_instance_valid(_boss) or not _boss.is_inside_tree() or _phase < 0 or _phase >= PHASES.size():
		return
	_t += d
	if _role != "client" and _t >= SEC:
		_next()
		_prev = {}
		return
	if _role == "server" or _t < 1.0 or (_role == "client" and _t > SEC - 0.5):
		_prev = {}
		return
	var trex: Node3D = _boss.get_node(^"Trex")
	var sk: Skeleton3D = trex.skel
	var xf := _skel_xf(trex)
	var body := _body_xf().origin
	var cur := {d = d, steps = steps, body = body, seen = trex.global_position, hip_y = sk.position.y, lean = trex._lean, drift = trex._drift,
		head = xf * sk.get_bone_global_pose(sk.find_bone("head")).origin,
		tail = xf * sk.get_bone_global_pose(sk.find_bone("tail8")).origin,
		foot = [], swing = (trex._swing as Array).duplicate(), plant_y = [trex._plant[0].y, trex._plant[1].y], rot = {}}
	for s: String in ["toe2_1_l", "toe2_1_r"]:
		cur.foot.append(xf * sk.get_bone_global_pose(sk.find_bone(s)).origin)
	for b: String in BONES:
		cur.rot[b] = trex.pose_rot(b)
	# 動作有多大：頭、尾尖、髖（骨架原點）在「畫面上的身體」座標裡跑過的範圍（x 左右、y 上下）
	var inv := _body_xf().affine_inverse()
	for pair: Array in [["head", cur.head], ["tail", cur.tail], ["hip", xf.origin]]:
		var q: Vector3 = inv * (pair[1] as Vector3)
		if not _range.has(pair[0]):
			_range[pair[0]] = [q, q]
		_range[pair[0]] = [(_range[pair[0]][0] as Vector3).min(q), (_range[pair[0]][1] as Vector3).max(q)]
	if not _prev.is_empty():
		var p: Dictionary = _prev
		var row := {steps = steps, d = d}
		row.true_v = (body - p.body).length() / d                 # 畫面上的身體這一幀的速度
		row.seen_v = ((cur.seen as Vector3) - (p.seen as Vector3)).length() / d   # 模型自己看到的（trex.gd 用 global_position 差算）
		row.used_v = (trex._local_v as Vector3).length()   # 模型實際拿去算動作的（平滑過的話）
		row.slide = [0.0, 0.0]; row.dfoot = [Vector3.ZERO, Vector3.ZERO]; row.pop = [0.0, 0.0]
		for i in 2:
			if not cur.swing[i] and not p.swing[i]:
				var df: Vector3 = cur.foot[i] - p.foot[i]
				row.dfoot[i] = df
				row.slide[i] = Vector2(df.x, df.z).length()
				row.pop[i] = absf(cur.plant_y[i] - p.plant_y[i])
				if OS.get_environment("EVENTS") != "" and (row.slide[i] > 0.05 or row.pop[i] > 0.02):   # 大的滑、跳：印出當時的狀況
					print("    事件 %s t=%.2f 腳%d 滑 %.3f 高度跳 %.3f 伸直 %.2f 相位 %.2f 速度 %.1f 動作 %d" % [PHASES[_phase], _t, i, row.slide[i], row.pop[i], trex._ext[i], fposmod(trex._gait + 0.5 * i, 1.0), row.true_v, trex.act])
		row.dhead = (cur.head as Vector3) - (p.head as Vector3) - (body - (p.body as Vector3))   # 扣掉身體本來的移動
		row.dtail = (cur.tail as Vector3) - (p.tail as Vector3) - (body - (p.body as Vector3))
		row.dhip = cur.hip_y - p.hip_y
		row.dlean = (cur.lean as Vector2) - (p.lean as Vector2)
		row.ddrift = (cur.drift as Vector2) - (p.drift as Vector2)
		row.drot = {}
		for b: String in BONES:
			var dq: Quaternion = (p.rot[b] as Quaternion).inverse() * (cur.rot[b] as Quaternion)   # 這一幀轉了多少（轉軸 × 角度；不用歐拉角，過 180 度會跳）
			if dq.w < 0.0:
				dq = -dq
			row.drot[b] = dq.get_axis() * dq.get_angle() if dq.get_angle() > 0.00001 else Vector3.ZERO
		_rows.append(row)
	_prev = cur


static func _flip(a: float, b: float, th: float) -> bool:
	return a * b < 0.0 and absf(a) > th and absf(b) > th


func _report() -> void:
	if _rows.size() < 10 or _phase >= PHASES.size():
		_rows.clear()
		return
	var n := _rows.size()
	var secs := 0.0
	var st := {}
	var v_err := PackedFloat32Array(); var v_jump := PackedFloat32Array(); var u_jump := PackedFloat32Array()
	var slide_max := 0.0; var slide_sum := 0.0; var slide_n := 0; var slide_flip := 0; var pop_max := 0.0; var pops := 0
	var flips := {head = 0, tail = 0, hip = 0, lean = 0, drift = 0}
	var bone_flip := {}; var bone_max := {}
	for b: String in BONES:
		bone_flip[b] = 0; bone_max[b] = 0.0
	var pr: Dictionary = _rows[0]
	for r: Dictionary in _rows:
		secs += r.d
		st[r.steps] = st.get(r.steps, 0) + 1
		v_err.append(absf(r.seen_v - r.true_v))
		v_jump.append(absf(r.seen_v - pr.seen_v))
		u_jump.append(absf(r.used_v - pr.used_v))
		for i in 2:
			slide_max = maxf(slide_max, r.slide[i])
			if r.slide[i] > 0.0:
				slide_sum += r.slide[i]; slide_n += 1
			var a: Vector3 = r.dfoot[i]; var b: Vector3 = pr.dfoot[i]
			slide_flip += 1 if a.dot(b) < 0.0 and a.length() > FLIP_M and b.length() > FLIP_M else 0
			pop_max = maxf(pop_max, r.pop[i])
			pops += 1 if r.pop[i] > 0.02 else 0
		for ax in 3:
			flips.head += 1 if _flip(r.dhead[ax], pr.dhead[ax], FLIP_M) else 0
			flips.tail += 1 if _flip(r.dtail[ax], pr.dtail[ax], FLIP_M) else 0
		flips.hip += 1 if _flip(r.dhip, pr.dhip, 0.002) else 0
		for ax in 2:
			flips.lean += 1 if _flip(r.dlean[ax], pr.dlean[ax], deg_to_rad(0.05)) else 0
			flips.drift += 1 if _flip(r.ddrift[ax], pr.ddrift[ax], 0.001) else 0
		for bn: String in BONES:
			var da: Vector3 = r.drot[bn]; var db: Vector3 = pr.drot[bn]
			bone_flip[bn] += 1 if da.dot(db) < 0.0 and da.length() > deg_to_rad(FLIP_DEG) and db.length() > deg_to_rad(FLIP_DEG) else 0
			bone_max[bn] = maxf(bone_max[bn], rad_to_deg(da.length()))
		pr = r
	v_err.sort(); v_jump.sort(); u_jump.sort()
	var bf := ""
	var bf_total := 0
	for bn: String in BONES:
		bf_total += bone_flip[bn]
		bf += " %s %d/%.1f°" % [bn, bone_flip[bn], bone_max[bn]]
	print("抖動 [%s] %s：%d 幀（每秒 %.0f 幀）、每幀物理步數 %s" % [_role if _role != "" else "單機", PHASES[_phase], n, n / secs, st])
	print("    模型看到的速度 vs 畫面上身體的速度：差 中位 %.2f、95%% %.2f 公尺／秒｜看到的速度一幀變多少：中位 %.2f、95%% %.2f｜拿去算動作的速度一幀變：中位 %.2f、95%% %.2f" % [
		v_err[n / 2], v_err[n * 19 / 20], v_jump[n / 2], v_jump[n * 19 / 20], u_jump[n / 2], u_jump[n * 19 / 20]])
	print("    踩著的腳（畫面上）：一幀最多滑 %.3f 公尺、平均 %.4f、來回 %d 幀（每秒 %.1f）；高度一幀跳 >2 公分 %d 次、最多 %.3f" % [
		slide_max, slide_sum / maxf(slide_n, 1), slide_flip, slide_flip / secs, pops, pop_max])
	print("    來回（每秒）：頭 %.1f、尾尖 %.1f、髖高 %.1f、側傾俯仰 %.1f、位移延遲 %.1f、骨頭合計 %.1f" % [
		flips.head / secs, flips.tail / secs, flips.hip / secs, flips.lean / secs, flips.drift / secs, bf_total / secs])
	print("    骨頭 來回幀數/一幀最多轉：%s" % bf)
	var rg := ""
	for k: String in _range:
		var span: Vector3 = (_range[k][1] as Vector3) - (_range[k][0] as Vector3)
		rg += " %s 左右 %.2f 上下 %.2f" % [{head = "頭", tail = "尾尖", hip = "髖"}[k], span.x, span.y]
	print("    動作幅度（相對身體，公尺）：%s" % rg)
	_rows.clear()
	_range.clear()


## trex.gd 一幀花多久：邊走邊叫 _process 2000 次（每次往前 4 公尺／秒 × 1/60 秒）
func _bench() -> void:
	var trex: Node3D = _boss.get_node(^"Trex")
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		_boss.global_position += -_boss.global_basis.z * (4.0 / 60.0)
		trex._process(1.0 / 60.0)
	print("    trex.gd 每幀 %.3f 毫秒（2000 次平均，走路）" % ((Time.get_ticks_usec() - t0) / 2000.0 / 1000.0))
