extends SceneTree
## 檢視模式「操控恐龍」的自我檢查：照玩家按鍵的方式（送鍵盤事件）開恐龍走斜坡、台階、石堆、跑步，再把每一招按一遍，
## 每一幀量腳（踩著的腳滑不滑、穿不穿地、懸不懸空，對照真的地面）和腿的關節有沒有抽。
##   godot --headless --path . --script tools/trex_drive_check.gd
##   OUT=/tmp/drive godot --path . --resolution 1280x720 --script tools/trex_drive_check.gd   加拍畫面

var _v: ModelViewer
var _t := 0.0
var _step := -1
var _fail := 0
var _shots := 0
var _next_shot := 0.0
# 劇本：一步一步做完才換下一步（不靠秒數：這種模式下每幀時間不固定，按住幾秒會轉過頭）
#   ["tap", 鍵]、["face", 角度]（按住 A/D 轉到這個朝向）、["go", 軸, 目標, 跑?]（按住 W 走到 x 或 z 過了目標）、["wait", 秒]
const PLAN := [
	["tap", "C", "切到操控"], ["tap", "K", ""],
	["face", -PI / 2, "轉向東"], ["go", "x", 22.0, false, "往東走到斜坡腳下"],
	["face", 0.0, "轉向北"], ["go", "z", -14.0, false, "走上 20 度斜坡"], ["wait", 1.5, "坡上站著"],
	["face", PI, "坡上轉身向南"], ["go", "z", 4.0, true, "往南跑下坡"],
	["face", PI / 2, "轉向西"], ["go", "x", 2.0, false, "往西走回中間"],
	["face", 0.0, "轉向北"], ["go", "z", -33.0, false, "走上三階台階"], ["wait", 1.0, "台階上站著"],
	["face", PI, "轉向南"], ["go", "z", 42.0, false, "往南走過石堆"], ["wait", 1.0, "停"],   # 走過石堆到空地上再出招（甩尾時腿是凍住的，旁邊有石頭會穿過去）
	["tap", "Z", "咬"], ["wait", 2.0, ""], ["tap", "X", "長吼＋甩尾"], ["wait", 3.0, ""],
	["tap", "V", "撲擊"], ["wait", 2.6, ""], ["tap", "B", "被打斷"], ["wait", 2.8, ""],
	["tap", "G", "發現人"], ["wait", 1.0, ""], ["tap", "H", "中彈"], ["wait", 1.0, ""], ["tap", "J", "頭被打"], ["wait", 1.0, ""],
	["tap", "M", "換心情"], ["tap", "BRACKETLEFT", "慢動作"], ["wait", 0.3, ""], ["tap", "BRACKETRIGHT", "恢復"], ["wait", 0.5, ""],
]
var _wait := 0.0
var _go_sign := 1.0
var _started := false
var _held: Array[Key] = []
var _slip := 0.0
var _slip_at := ""
var _sink := 0.0
var _sink_at := ""
var _float := 0.0
var _float_at := ""
var _joint := 0.0
var _joint_at := ""
var _from := [null, null]
var _prev_q := {}
var _phase := ""
var _max_x := -INF
var _max_h := 0.0
var _min_z := INF
var _max_z := -INF
var _acts_seen := {}


func _initialize() -> void:
	_v = (load("res://viewer.gd") as GDScript).new()
	root.add_child(_v)


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> bool:
	_t += delta
	if _t > 0.3 and _advance(delta):
		_report()
		return true
	if _t > 1.0:
		_measure(delta)
	var out := OS.get_environment("OUT")
	if out != "" and _t >= _next_shot and _t > 1.2:
		_next_shot = _t + 1.5
		root.get_viewport().get_texture().get_image().save_png(out + "/d_%02d.png" % _shots)
		_shots += 1
	return _t > 240.0   # 保險：卡住就停


## 做目前這一步；整個劇本做完回傳 true
func _advance(delta: float) -> bool:
	if _step >= PLAN.size():
		return true
	if _step < 0 or not _started:
		_step = maxi(_step, 0)
		_started = true
		_phase = PLAN[_step][PLAN[_step].size() - 1] if PLAN[_step][PLAN[_step].size() - 1] != "" else _phase
		_wait = 0.0
	var st: Array = PLAN[_step]
	var t: Trex = _v._trex
	var done := false
	match st[0]:
		"tap":
			var k: Key = OS.find_keycode_from_string(st[1])
			_key(k, true)
			_key(k, false)
			done = true
		"wait":
			_wait += delta
			done = _wait >= st[1]
		"face":
			var diff := wrapf(float(st[1]) - t.rotation.y, -PI, PI)
			_hold([KEY_A] if diff > 0.0 else [KEY_D])
			done = absf(diff) < 0.06
		"go":
			var pos: float = t.global_position.x if st[1] == "x" else t.global_position.z
			_hold([KEY_W, KEY_SHIFT] if st[3] else [KEY_W])
			var target: float = st[2]
			if _wait == 0.0:   # 第一幀記下要往哪個方向過目標
				_go_sign = signf(target - pos)
			_wait += delta
			done = (pos - target) * _go_sign >= 0.0 or _wait > 30.0
	if done:
		_hold([])
		_step += 1
		_started = false
	return false


## 按住這些鍵，其他放開
func _hold(keys: Array) -> void:
	for k in _held.duplicate():
		if not keys.has(k):
			_key(k, false)
			_held.erase(k)
	for k in keys:
		if not _held.has(k):
			_key(k, true)
			_held.append(k)


func _ground_y(p: Vector3) -> float:
	var hit := _v.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0))
	return hit.position.y if hit else 0.0


func _measure(_d: float) -> void:
	var t: Trex = _v._trex
	if not t._walk_ready:
		return
	_acts_seen[t.act] = true
	_max_x = maxf(_max_x, t.global_position.x)
	_min_z = minf(_min_z, t.global_position.z)
	_max_z = maxf(_max_z, t.global_position.z)
	_max_h = maxf(_max_h, t.global_position.y)
	var foot_h: float = t._leg[0].neutral.y * 1.5
	var spin: bool = t.act == 4 or t._spin > 0.0   # 甩尾整隻轉一圈，腳一定在原地轉
	for i in 2:
		var ball := t.bone_pos("toe2_1" + ("_l" if i == 0 else "_r"))
		var gap := ball.y - (_ground_y(ball) + foot_h)
		# 跺地、咬下去踏步、撲出去（騰空）和落地那一下是故意抬腳
		var lifted: bool = t._swing[i] or (t.act == 3 and gap > 0.05) or (t._snap_bite and t._snap > 0.0) or t.act == 6 or t._air_land > 0.0
		if -gap > _sink:
			_sink = -gap
			_sink_at = "t=%.1f %s 腳%d" % [_t, _phase, i]
		if not lifted and not spin and gap > _float:   # 甩尾時腿凍住，可能有一隻正在跺地抬著
			_float = gap
			_float_at = "t=%.1f %s 腳%d" % [_t, _phase, i]
		if lifted or spin:
			_from[i] = null
		else:
			if _from[i] == null:
				_from[i] = ball
			var dd: Vector3 = ball - _from[i]
			if Vector2(dd.x, dd.z).length() > _slip:
				_slip = Vector2(dd.x, dd.z).length()
				_slip_at = "t=%.1f %s 腳%d" % [_t, _phase, i]
	for b in ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]:
		var q := t.skel.get_bone_pose_rotation(t._idx[b])
		if _prev_q.has(b):
			var a := rad_to_deg(q.angle_to(_prev_q[b]))
			if a > _joint:
				_joint = a
				_joint_at = "t=%.1f %s %s" % [_t, _phase, b]
		_prev_q[b] = q


func _ck(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fail += 1


func _report() -> void:
	_ck(_v._drive, "按 C 進入操控")
	_ck(_max_x > 18.0, "往東走到斜坡（最遠 x=%.1f）" % _max_x)
	_ck(_min_z < -20.0, "往北走到台階（最北 z=%.1f）" % _min_z)
	_ck(_max_z > 20.0, "往南走到石堆（最南 z=%.1f）" % _max_z)
	_ck(_max_h > 1.0, "真的爬高了（最高 %.1f 公尺）" % _max_h)
	var all_acts := true
	for a in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		all_acts = all_acts and _acts_seen.has(a)
	_ck(all_acts, "每一招都放出來了（看到的動作：%s）" % str(_acts_seen.keys()))
	_ck(_slip < 0.10, "踩著的腳不滑：最多 %.3f 公尺（< 0.10）%s" % [_slip, _slip_at])
	_ck(_sink < 0.15, "不穿地：最深 %.3f 公尺（< 0.15）%s" % [_sink, _sink_at])
	_ck(_float < 0.15, "踩著的腳不懸空：最多 %.3f 公尺（< 0.15）%s" % [_float, _float_at])
	_ck(_joint < 12.0, "腿不抽：一幀最多轉 %.1f 度（< 12）%s" % [_joint, _joint_at])
	_ck(Engine.time_scale == 1.0, "慢動作切回來")
	print("操控檢查：%d 項沒過" % _fail)
	quit(1 if _fail > 0 else 0)
