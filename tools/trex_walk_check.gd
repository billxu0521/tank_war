extends SceneTree
## 恐龍走路的自我檢查（trex.gd 的 _walk）：平地上走 6 秒 → 停 2 秒 → 跑 3 秒 → 原地轉身 2 秒，每一幀量腳。
## 有畫面時另外從正側面拍走路的影格，跟參考動畫（docs/尼諾拉.md）並排存成 OUT 那張圖。
##   godot --headless --path . --script tools/trex_walk_check.gd                     只量數字（失敗回傳 1）
##   OUT=/tmp/walk.png godot --path . --resolution 1280x720 --script tools/trex_walk_check.gd   加拍影格
## 檢查項目和門檻寫在 _report()；docs/尼諾拉.md 有說明

const WALK := 4.0    # boss.gd 的 WALK
const RUN := 11.0    # boss.gd 的 RUN
const FLOOR_Y := 0.0
var _t := 0.0
var _rig: Node3D
var _trex: Trex
var _cam: Camera3D
var _frames: Array[Image] = []
var _shoot_next := 0.0
var _fail := 0
# 量測
var _ik_err := 0.0          # 腳掌實際位置跟目標差多少（公尺），走和跑的時候
var _turn_err := 0.0        # 原地轉身時差多少（已知限制，只列出來）
var _slip := 0.0            # 支撐期腳掌水平滑多少
var _contact := 0.0         # 支撐期腳掌高度偏差
var _sink := 0.0            # 最深穿地多少
var _lift := 0.0            # 擺動期最高抬多高
var _land_t := [[], []]     # 走路時每隻腳的落地時間
var _knee_back := 0         # 膝蓋往後彎的幀數
var _hip_h := 0.0
var _stance_from := [Vector3.ZERO, Vector3.ZERO]
var _was_swing := [false, false]
var _settled := true
var _nan := false
var _run_lift := 0.0
var _jump := 0.0             # 腳的目標一幀最多跳多遠（扣掉身體本來就走的距離）
var _prev_target := [null, null]
var _prev_rig := Vector3.ZERO
var _joint := 0.0            # 腿關節一幀最多轉幾度
var _prev_q := {}
var _jump_at := ""
var _ik_at := ""
var _swing_lag := 0.0
var _swing_jump := 0.0
var _sink_at := ""
var _joint_at := ""


func _initialize() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = FLOOR_Y - 0.5
	floor_body.add_child(cs)
	root.add_child(floor_body)
	_rig = Node3D.new()   # 跟 boss.tscn 一樣：身體在 4.05，恐龍模型放大 1.5 往下放 4.05（腳底在地上）
	_rig.position = Vector3(0, FLOOR_Y + 4.05, 0)
	root.add_child(_rig)
	_trex = (load("res://trex.gd") as GDScript).new()
	_trex.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.5), Vector3(0, -4.05, 0))
	_rig.add_child(_trex)
	if DisplayServer.get_name() != "headless":
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.85, 0.85, 0.83)
		env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0)
		root.add_child(sun)
		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(400, 400)
		ground.mesh = pm
		root.add_child(ground)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = 9.0
		root.add_child(_cam)
		_cam.current = true


func _process(delta: float) -> bool:
	_t += delta
	# 劇本：走 → 停 → 跑 → 原地轉身
	var walking := _t > 0.5 and _t < 6.5
	var running := _t > 8.5 and _t < 11.5
	# 先量再移動：恐龍這一幀是照移動前的位置擺腳的（遊戲裡身體在物理步先動、動畫後擺，沒有這個時間差）
	if _t > 0.3:
		_measure(walking, running)
	_prev_rig = _rig.position
	if walking:
		_rig.position.z -= WALK * delta
	elif running:
		_rig.position.z -= RUN * delta
	elif _t > 12.0 and _t < 14.0:
		_rig.rotation.y += 3.0 * delta   # boss.gd 的 TURN
	if _cam:
		_cam.position = Vector3(-30, 3.4, _rig.position.z - 1.2)
		_cam.rotation = Vector3(0, -PI / 2, 0)
		if walking and _t > 3.0 and _t >= _shoot_next and _frames.size() < 24:
			_shoot_next = _t + 0.1
			_frames.append(root.get_viewport().get_texture().get_image())
	if _t > 14.5:
		_report()
		return true
	return false


func _measure(walking: bool, running: bool) -> void:
	var sw := 1.5
	var foot_h: float = _trex._leg[0].neutral.y * sw
	_hip_h = maxf(_hip_h, _trex.bone_pos("thigh_l").y - FLOOR_Y)
	for i in 2:
		var s := "_l" if i == 0 else "_r"
		var ball := _trex.bone_pos("toe2_1" + s)
		if not ball.is_finite():
			_nan = true
			continue
		var target: Vector3 = _trex._plant[i]
		if _prev_target[i] != null:   # 目標一幀不能跳太遠：腳的目標跳，腿就跟著抽
			var jj := target.distance_to(_prev_target[i])
			if _trex._swing[i] or _trex._landed[i]:   # 抬起來的腳本來就在動（約身體速度的兩倍）
				_swing_jump = maxf(_swing_jump, jj - (_rig.position - _prev_rig).length())
			elif _t > 12.0:   # 原地快轉時踩著的腳會往旁邊滑（已知限制），另外記
				_turn_err = maxf(_turn_err, jj)
			elif jj > _jump:
				_jump = jj
				_jump_at = "t=%.2f 腳%d" % [_t, i]
		_prev_target[i] = target
		if walking or running:
			if _trex._swing[i]:   # 抬起來的腳：腿有轉速上限，急起急停時會慢半拍
				_swing_lag = maxf(_swing_lag, ball.distance_to(target))
			else:
				if ball.distance_to(target) > _ik_err:
					_ik_at = "t=%.2f 腳%d" % [_t, i]
				_ik_err = maxf(_ik_err, ball.distance_to(target))
		elif _t > 12.0:   # 原地轉身：腿只在側面平面裡解，腳的左右跟著身體走（trex.gd 的 ponytail），另外記
			_turn_err = maxf(_turn_err, ball.distance_to(target))
		if (FLOOR_Y + foot_h) - ball.y > _sink:
			_sink_at = "t=%.2f 腳%d %s" % [_t, i, "擺動" if _trex._swing[i] else "支撐"]
		_sink = maxf(_sink, (FLOOR_Y + foot_h) - ball.y)
		var swing: bool = _trex._swing[i]
		if walking:
			if swing:
				_lift = maxf(_lift, ball.y - (FLOOR_Y + foot_h))
			else:
				if _was_swing[i]:
					_stance_from[i] = ball
					_land_t[i].append(_t)
				elif _land_t[i].size() > 0:   # 落地之後的支撐期：不能滑
					var d := ball - (_stance_from[i] as Vector3)
					_slip = maxf(_slip, Vector2(d.x, d.z).length())
				_contact = maxf(_contact, absf(ball.y - (FLOOR_Y + foot_h)))
		if running and swing:
			_run_lift = maxf(_run_lift, ball.y - (FLOOR_Y + foot_h))
		_was_swing[i] = swing
		# 膝蓋朝前：在恐龍自己的座標裡，膝蓋要在「髖到踝」連線的前方（-Z）
		var inv := _trex.skel.global_transform.affine_inverse()
		var hip := inv * _trex.bone_pos("thigh" + s)
		var knee := inv * _trex.bone_pos("shin" + s)
		var ankle := inv * _trex.bone_pos("foot" + s)
		var t := clampf((knee.y - hip.y) / minf(ankle.y - hip.y, -0.001), 0.0, 1.0)
		if knee.z > lerpf(hip.z, ankle.z, t) + 0.02:
			_knee_back += 1
	for b in ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]:
		var q := _trex.skel.get_bone_pose_rotation(_trex._idx[b])
		if _prev_q.has(b):
			var jd := rad_to_deg(q.angle_to(_prev_q[b]))
			if jd > _joint:
				_joint = jd
				_joint_at = "t=%.2f %s" % [_t, b]
		_prev_q[b] = q
	if _t > 7.5 and _t < 8.4 and (_trex._swing[0] or _trex._swing[1]):
		_settled = false


func _ck(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fail += 1


func _report() -> void:
	var cyc := []
	for i in 2:
		var ts: Array = _land_t[i]
		for k in range(1, ts.size()):
			cyc.append(ts[k] - ts[k - 1])
	var cycle := 0.0
	for c in cyc:
		cycle += c
	cycle /= maxf(cyc.size(), 1)
	# 左右交替：右腳落地應該在左腳兩次落地的中間
	var alt := 1.0
	var l: Array = _land_t[0]
	var r: Array = _land_t[1]
	if l.size() >= 2 and r.size() >= 1:
		for rt in r:
			for k in range(1, l.size()):
				if rt > l[k - 1] and rt < l[k]:
					alt = (rt - l[k - 1]) / (l[k] - l[k - 1])
	print("步伐週期 %.2f 秒（走 %d 步）、右腳落在左腳週期的 %.0f%%" % [cycle, cyc.size() + 2, alt * 100.0])
	_ck(not _nan, "骨頭位置沒有無效值")
	_ck(_ik_err < 0.06, "IK 準：踩著的腳離目標最多 %.3f 公尺（< 0.06）%s" % [_ik_err, _ik_at])
	print("（已知限制）原地轉身時腳掌離目標最多 %.2f 公尺：腳的左右位置跟著身體走" % _turn_err)
	_ck(_jump < 0.02, "踩著的腳不動：目標一幀最多移 %.3f 公尺（< 0.02）%s" % [_jump, _jump_at])
	_ck(_swing_jump < 0.3, "抬起的腳不瞬移：扣掉身體移動，一幀最多 %.3f 公尺（< 0.3）" % _swing_jump)
	_ck(_swing_lag < 0.25, "抬起的腳跟得上：最多落後目標 %.3f 公尺（< 0.25）" % _swing_lag)
	_ck(_joint < 12.0, "腿不抽：關節一幀最多轉 %.1f 度（< 12；60 幀時約每秒 720 度）%s" % [_joint, _joint_at])
	_ck(_slip < 0.05, "腳不滑：支撐期腳掌水平最多移動 %.3f 公尺（< 0.05）" % _slip)
	_ck(_contact < 0.08, "踩實地面：支撐期腳掌高度偏差最多 %.3f 公尺（< 0.08）" % _contact)
	_ck(_sink < 0.10, "不穿地：最深 %.3f 公尺（< 0.10）%s" % [_sink, _sink_at])
	_ck(_lift > 0.35, "抬腳夠高：走路時最高 %.2f 公尺（> 0.35）" % _lift)
	_ck(_run_lift > 0.35, "跑步時也抬腳：最高 %.2f 公尺（> 0.35）" % _run_lift)
	_ck(cycle > 1.3 and cycle < 2.2, "走路週期 %.2f 秒（1.3～2.2；參考動畫慢走 2.4 秒，遊戲走得比較快）" % cycle)
	_ck(alt > 0.4 and alt < 0.6, "左右交替：右腳在左腳週期的 %.0f%%（40～60%%）" % (alt * 100.0))
	_ck(_knee_back == 0, "膝蓋朝前：往後彎 %d 幀（0）" % _knee_back)
	_ck(_hip_h > 3.4 and _hip_h < 4.1, "髖關節高 %.2f 公尺（3.4～4.1，設定圖肩高 3.5～4.5）" % _hip_h)
	_ck(_settled, "停下來 1 秒後兩腳都踩在地上")
	if _frames.size() > 0:
		_save_strip()
	print("走路檢查：%d 項沒過" % _fail)
	quit(1 if _fail > 0 else 0)


## 拍的影格拼成 6 欄（跟參考動畫的 10fps 側面影格同一個排法），存到 OUT
func _save_strip() -> void:
	var w := 400
	var h := int(400.0 * _frames[0].get_height() / _frames[0].get_width())
	var cols := 6
	var rows := int(ceil(_frames.size() / float(cols)))
	var out := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for k in _frames.size():
		var f: Image = _frames[k]
		f.convert(Image.FORMAT_RGBA8)
		f.resize(w, h)
		out.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	out.save_png(OS.get_environment("OUT"))
	print("影格 -> ", OS.get_environment("OUT"))
