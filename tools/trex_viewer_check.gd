extends SceneTree
## 檢視模式（viewer.gd）裡的恐龍：跑 20 秒，量踩著的腳滑多少、腿和身體的關節一幀最多轉幾度。
##   godot --headless --path . --script tools/trex_viewer_check.gd
var _v: ModelViewer
var _f := 0
var _prev := {}
var _worst := {}
var _ik := 0.0
var _ik_at := ""
var _slip := 0.0
var _stance_from := [null, null]
var _prev_ball := [null, null]
var _slide_t := 0.0
var _slide_max := 0.0
const BONES := ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "spine1", "neck", "head", "tail1", "tail4"]
func _initialize() -> void:
	_v = (load("res://viewer.gd") as GDScript).new()
	root.add_child(_v)
func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		_v._show("trex") if _v.has_method("_show") else null
	var t: Trex = _v._trex
	if _f > 30 and t.skel:
		for b in BONES:
			var q := t.skel.get_bone_pose_rotation(t._idx[b])
			if _prev.has(b):
				var ang := rad_to_deg((q as Quaternion).angle_to(_prev[b]))   # 這一幀轉幾度
				if ang > _worst.get(b, [0.0])[0]:
					_worst[b] = [ang, _v._t]
			_prev[b] = q
		for i in 2:
			var s := "_l" if i == 0 else "_r"
			var ball := t.bone_pos("toe2_1" + s)
			var e := ball.distance_to(t._plant[i])
			if e > _ik:
				_ik = e
				_ik_at = "t=%.2f 腳%d swing=%s" % [_v._t, i, t._swing[i]]
			if not t._swing[i]:
				if _stance_from[i] == null:
					_stance_from[i] = ball
				var dd: Vector3 = ball - _stance_from[i]
				var rs: float = (ball - _prev_ball[i]).length() / d if _prev_ball[i] != null else 0.0
				if rs > 0.5:
					_slide_t += d
					_slide_max = maxf(_slide_max, rs)
				_slip = maxf(_slip, Vector2(dd.x, dd.z).length())
			else:
				_stance_from[i] = null
			_prev_ball[i] = ball
	if _f > 30 + 60 * 20:
		print("踩著的腳在滑（> 0.5 m/s）的時間 %.2f 秒（共 20 秒）、最快 %.2f m/s；恐龍轉速 / 速度見 viewer.gd" % [_slide_t, _slide_max])
		print("IK 最大誤差 %.3f（%s）  支撐期滑動 %.3f" % [_ik, _ik_at, _slip])
		for b in BONES:
			print("%-8s 一幀最多轉 %.1f 度 在 t=%.2f" % [b, _worst[b][0], _worst[b][1]])
		return true
	return false
