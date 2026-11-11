extends SceneTree
## 尼諾拉火球：量順不順、拍照。尼諾拉站定，照固定劇本連吐 SHOTS_N 顆（每顆隔 GAP 秒，朝斜下方打地面）。
##   量（開視窗才有畫面的成本）  godot --path . --disable-vsync --resolution 1600x900 --script tools/fireball_probe.gd
##   量（沒畫面：只看程式的成本） godot --headless --path . --script tools/fireball_probe.gd
##   拍照                       OUT=資料夾 godot --path . --resolution 1600x900 --script tools/fireball_probe.gd
##   真的連線                    ROLE=server godot --headless --path . --script tools/fireball_probe.gd -- --server
##                              ROLE=client godot --path . --disable-vsync --script tools/fireball_probe.gd
## 每顆印一行「火球 …」：兩幀之間真的隔多久（Time.get_ticks_usec）、多了幾個節點和物件、畫面上的位置跟「速度×時間」差多少、
## 火球生出來的位置離嘴巴多遠。最後一行「FIREBALL OK」才算跑完（Godot 解析錯誤也回 0）。

const CAMS := ["side", "hunter", "pilot", "impact", "hunter_far"]   # 拍照：每顆換一個鏡頭
const AT_WIND := [0.3, 0.6, 0.78, 0.86, 1.0, 1.3]   # 起招後幾秒拍
const AT_HIT := [0.02, 0.12, 0.3, 0.8, 2.0]          # 命中後幾秒拍

var _role := OS.get_environment("ROLE")
var _out := OS.get_environment("OUT")
var NSHOT := CAMS.size() if _out != "" else _env("SHOTS_N", 5.0) as int
var GAP := _env("GAP", 5.0)
var _windowed := DisplayServer.get_name() != "headless"
var _m: Node
var _f := 0
var _boss: Node3D
var _cam: Camera3D
var _shot := -1
var _t := 0.0             # 這一顆起招後幾秒
var _last_us := 0
var _ball: Node3D
var _seen := false        # 這一顆的火球出現過了
var _hit_t := -1.0        # 這一顆在起招後幾秒命中（消失）
var _hit_at := Vector3.ZERO
var _muzzle := Vector3.ZERO
var _prev := Vector3.INF
var _snaps := {}          # 這一顆拍過哪幾張
var _s := {}              # 這一顆的統計
var _base_nodes := 0.0
var _base_objs := 0.0
var _started := false
var _wait := 0.0
var _yaw := 0.0


func _env(k: String, d: float) -> float:
	return OS.get_environment(k).to_float() if OS.get_environment(k) != "" else d


func _initialize() -> void:
	if _role != "server":
		OS.low_processor_usage_mode_sleep_usec = 1   # 同 smooth_probe.gd：沒畫面的 Godot 每幀固定睡 6.9 毫秒，關掉才量得到真的做了多久
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		if _role == "client":
			Engine.max_fps = 120
			_m.ip_edit.text = OS.get_environment("JOIN") if OS.get_environment("JOIN") != "" else "127.0.0.1"   # LAG=1 時指到 tools/lag_proxy.py
			_m.player_key = "fireball-probe"
			_m._on_join_pressed()
		elif _role == "":
			_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			_m._offline = true
			_m._enter_game("probe")
	if _f < 3:
		return false
	if not _started:
		if _role == "client":
			var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
			if not (mp != null and not mp is OfflineMultiplayerPeer and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED \
					and _m.players.has_node(NodePath(str(_m.multiplayer.get_unique_id())))):
				return _f > 60 * 120
		elif _role == "server" and _m.multiplayer.get_peers().is_empty():
			return _f > 60 * 60
		_wait += d
		if _wait < 4.0:   # 進場的卡頓（載地圖、編著色器）先過去
			return false
		_started = true
		_boss = _m._boss() if _m._boss() else _m.spawn_boss()
		if _role != "client":
			_boss.pilot = 1
			_place()
		if _windowed:
			_m.get_node(^"UI").visible = _out == ""
			_cam = Camera3D.new()
			_cam.fov = 75.0
			root.add_child(_cam)
		_last_us = Time.get_ticks_usec()
		return false
	if _role == "client":
		return _client(d)
	if _shot < 0 and _wait < 6.0:   # 尼諾拉剛生出來那幾幀的卡頓不要算進第一顆
		_wait += d
		return false
	if _shot < 0 or _t >= GAP:
		if _shot >= 0:
			_report()
		_shot += 1
		if _shot >= NSHOT:
			print("FIREBALL OK")
			return true
		_fire()
	# 駕駛那台每個物理幀把鏡頭的角度送給主機（_pilot_local），滑鼠一動就偏：每幀釘住
	_boss._cam_yaw = _yaw
	_boss._cam_pitch = _env("PITCH", -0.22)
	_sample(d)
	return false


## 尼諾拉放平地、轉到「火球會在 25–45 公尺外打到地面」的方向
func _place() -> void:
	_boss.global_position = _m.boss_on_ground(Vector3(_env("X", 0.0), 0, _env("Z", 60.0)))
	_boss.velocity = Vector3.ZERO
	_boss.look_pitch = _env("PITCH", -0.22)
	var space := _boss.get_world_3d().direct_space_state
	for i in 24:
		_boss.rotation.y = TAU * i / 24.0
		_boss.force_update_transform()
		var q := PhysicsRayQueryParameters3D.create(_boss._spit_muzzle(), _boss._spit_muzzle() + _boss._spit_dir() * 60.0)
		q.exclude = [_boss.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit.collider as Node).is_in_group(&"ground") and hit.position.distance_to(_boss._spit_muzzle()) > 25.0:
			_hit_at = hit.position
			_yaw = _boss.rotation.y
			return
	push_error("找不到打得到地面的方向")


func _fire() -> void:
	_reset()
	_boss.fireball_left = 0.0
	_boss._attack_gap = 0.0
	_boss._begin(_boss.ACT_SPIT_WIND, _boss.FIREBALL_WIND)


func _reset() -> void:
	_t = 0.0
	_seen = false
	_hit_t = -1.0
	_ball = null
	_prev = Vector3.INF
	_snaps = {}
	_s = {gap = 0.0, all = PackedFloat32Array(), n = 0, gap_wind = 0.0, apart = 0.0, t_launch = 0.0, over = 0, gap_launch = 0.0, gap_hit = 0.0, nodes = 0.0, objs = 0.0, draws = 0.0, tris = 0.0, jit_max = 0.0, jit_sq = 0.0, jit_n = 0,
		jit_at = 0, first = -1.0, mouth = -1.0, launch_f = -1, hit_f = -1}
	_base_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_base_objs = Performance.get_monitor(Performance.OBJECT_COUNT)
	_last_us = Time.get_ticks_usec()


func _find_ball() -> Node3D:
	for c: Node in _m.get_node(^"Arena").get_children():
		if c is Fireball and not c.is_queued_for_deletion():
			return c
	return null


## 畫面上火球（本體，補幀之後）在哪
func _look_pos(b: Node3D) -> Vector3:
	return b.get_global_transform_interpolated().origin


func _sample(d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_t += d
	_s.gap = maxf(_s.gap, ms)
	_s.all.append(ms)
	_s.n += 1
	if _s.n <= 5:
		_s.gap_wind = maxf(_s.gap_wind, ms)
	_s.over += int(ms > 16.7)
	_s.nodes = maxf(_s.nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - _base_nodes)
	_s.objs = maxf(_s.objs, Performance.get_monitor(Performance.OBJECT_COUNT) - _base_objs)
	if _windowed:
		_s.draws = maxf(_s.draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_s.tris = maxf(_s.tris, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if _s.launch_f >= 0 and _f - _s.launch_f <= 4:
		_s.gap_launch = maxf(_s.gap_launch, ms)
	if _s.hit_f >= 0 and _f - _s.hit_f <= 4:
		_s.gap_hit = maxf(_s.gap_hit, ms)
	var b := _ball if is_instance_valid(_ball) and not _ball.is_queued_for_deletion() else _find_ball()
	if b != null:
		var p := _look_pos(b)
		if not _seen:
			_seen = true
			_ball = b
			_s.launch_f = _f
			_s.t_launch = _t
			_s.gap_launch = ms
			_muzzle = b.global_position - (b.vel as Vector3).normalized() * b._flown
			_s.first = p.distance_to(_muzzle) - b._flown   # 第一張畫面：畫出來的位置跟「照理該在的位置」差多少
			_s.mouth = _muzzle.distance_to(_boss.get_node(^"Trex").bone_pos("jaw"))
			if _role != "":   # 伺服器和客戶端各印自己看到火球的時刻（同一台電腦的時鐘），相減＝客戶端晚多久
				print("FBT %s 第 %d 顆 %d %.2f" % [_role, _shot + 1, int(Time.get_unix_time_from_system() * 1000.0), b._flown])
		elif _prev != Vector3.INF:
			var err := absf(p.distance_to(_prev) - (b.vel as Vector3).length() * d)
			if err > _s.jit_max:
				_s.jit_at = _s.jit_n
			_s.jit_max = maxf(_s.jit_max, err)
			_s.jit_sq += err * err
			_s.jit_n += 1
		_prev = p
		var look := b.get_node_or_null(^"Look") as Node3D   # 外觀滑到本體之後要一直貼著本體
		if look and _t - _s.t_launch > 0.2:
			_s.apart = maxf(_s.apart, look.get_global_transform_interpolated().origin.distance_to(p))
	elif _seen and _hit_t < 0.0:
		_hit_t = _t
		_s.hit_f = _f
		_s.gap_hit = ms
	if _out != "" and _windowed:
		_shoot()


func _report() -> void:
	(_s.all as PackedFloat32Array).sort()
	print("火球 [%s] 第 %d 顆：兩幀中位 %.1f、最久 %.1f 毫秒（起招那幾幀 %.1f、發射那幾幀 %.1f、命中那幾幀 %.1f）、掉幀（>16.7）%d 次；多出節點最多 %d、物件 %d；繪製指令最多 %d、三角形 %.1f 萬；畫面位置跟速度×時間差最多 %.1f、均方根 %.2f 公分（%d 幀，最差在第 %d 幀）；第一張畫面偏 %.2f 公尺、外觀離本體最多 %.1f 公分；生出來的位置離下巴 %.1f 公尺；%.2f 秒後命中" % [
		_role if _role != "" else "單機", _shot + 1, _s.all[_s.all.size() / 2], _s.gap, _s.gap_wind, _s.gap_launch, _s.gap_hit, _s.over, _s.nodes, _s.objs, _s.draws, _s.tris / 10000.0,
		_s.jit_max * 100.0, sqrt(_s.jit_sq / maxf(_s.jit_n, 1.0)) * 100.0, _s.jit_n, _s.jit_at, _s.first, _s.apart * 100.0, _s.mouth, _hit_t])


## 拍照：每顆一個鏡頭，起招後、命中後各拍幾張
func _shoot() -> void:
	var name: String = CAMS[_shot % CAMS.size()]
	var fwd: Vector3 = _boss._spit_dir()
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var right := flat.cross(Vector3.UP)
	var mouth: Vector3 = _boss._spit_muzzle()
	var eye := Vector3.UP * 1.7
	_cam.current = name != "pilot"
	match name:
		"side": _cam.look_at_from_position(mouth + right * 11.0 + flat * 2.0 - Vector3.UP * 1.0, mouth + flat * 1.0)
		"hunter": _cam.look_at_from_position(_m._on_ground(_boss.global_position + flat * 30.0 + right * 7.0) + eye, mouth - Vector3.UP * 2.0)
		"hunter_far": _cam.look_at_from_position(_m._on_ground(_boss.global_position + flat * 60.0 + right * 14.0) + eye, mouth - Vector3.UP * 3.0)
		"impact": _cam.look_at_from_position(_m._on_ground(_hit_at - flat * 13.0 + right * 5.0) + eye * 2.5, _hit_at + Vector3.UP)
	for at: float in AT_WIND:
		if _t >= at and not _snaps.has(at):
			_snaps[at] = true
			_save("%s_w%.2f" % [name, at])
	if _hit_t >= 0.0:
		for at: float in AT_HIT:
			if _t - _hit_t >= at and not _snaps.has(-at):
				_snaps[-at] = true
				_save("%s_i%.2f" % [name, at])


func _save(n: String) -> void:
	RenderingServer.force_draw()   # 視窗被擋住時 macOS 不重畫（同 corpse_shots.gd）
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, n])


## 客戶端：伺服器起招一次就量一顆，伺服器關了收工
var _was_wind := false
func _client(d: float) -> bool:
	var mp: MultiplayerPeer = _m.multiplayer.multiplayer_peer
	_boss = _m._boss()
	if mp == null or mp is OfflineMultiplayerPeer or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or _m.lobby.visible or _boss == null:
		if _shot >= 0:
			_report()
		print("FIREBALL OK")
		return true
	var wind: bool = _boss.act == _boss.ACT_SPIT_WIND
	if wind and not _was_wind:
		if _shot >= 0:
			_report()
		_shot += 1
		_reset()
	_was_wind = wind
	if _shot >= 0:
		_sample(d)
	return false
