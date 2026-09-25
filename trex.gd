class_name Trex
extends Node3D
## 暴龍：一副 Skeleton3D，每根骨頭掛一塊 Blender 建好的部件（模型缺件就退回灰盒）。
##
## ponytail: 部件是剛體掛在骨頭上（BoneAttachment3D），不做蒙皮權重。
## 關節處會有接縫，但看得出關節在動就夠了，要平滑變形再換成真正的 skinned mesh。
##
## 動畫是程式算的，不用 AnimationPlayer——走路快慢直接跟著實際位移，
## 而且不管是自己那隻還是別人同步過來的都會動。
##
## 尾巴和脊椎用「旋轉延遲傳遞」：每一節用彈簧去追**前一節上一幀**的角度。
## 追不上就是延遲，追過頭就是過衝，慣性和彈性都是這樣長出來的。
## 參考 https://www.youtube.com/watch?v=7yXqfESL5qo

const BODY := Color(0.34, 0.58, 0.27)
const BELLY := Color(0.56, 0.69, 0.40)
const DARK := Color(0.21, 0.36, 0.18)

const MODEL := preload("res://models/trex.glb")  # Blender 建的部件，名字對應骨頭

const TAIL_STIFF := 26.0   # 越大跟得越緊，延遲越短
const TAIL_DAMP := 4.5     # 越小晃越久（過衝越明顯）
const SPINE_STIFF := 55.0
const SPINE_DAMP := 8.0

# 側傾和位移延遲：身體是有重量的，方向一變不會馬上跟上
const LEAN_STIFF := 16.0
const LEAN_DAMP := 5.5
const LEAN_MAX := 0.40     # 最多傾 23 度
const DRIFT_STIFF := 22.0
const DRIFT_DAMP := 6.0

var skel: Skeleton3D
var _idx := {}          # 骨頭名字 -> index
var _phase := 0.0
var look_pitch := 0.0   # 由 dino.gd 餵進來，讓頭跟著視角抬
var _bite := 0.0        # 1 -> 0，咬擊動作的進度
var _last_pos := Vector3.ZERO
var _yaw_prev := 0.0
# 骨鏈的角度和角速度。用 Array 不用 PackedFloat32Array，才傳得進函式改得到
var _tail_yaw := [0.0, 0.0, 0.0, 0.0]
var _tail_yaw_v := [0.0, 0.0, 0.0, 0.0]
var _tail_pitch := [0.0, 0.0, 0.0, 0.0]
var _tail_pitch_v := [0.0, 0.0, 0.0, 0.0]
var _spine_yaw := [0.0, 0.0, 0.0, 0.0]   # spine1, spine2, neck, head
var _spine_yaw_v := [0.0, 0.0, 0.0, 0.0]
var _lean := Vector2.ZERO     # x 側傾（正 = 往左倒）, y 俯仰（正 = 抬頭）
var _lean_v := Vector2.ZERO
var _drift := Vector2.ZERO    # 身體相對腳的位移延遲（本地座標的左右、前後）
var _drift_v := Vector2.ZERO
var _local_v := Vector3.ZERO  # 上一幀的本地速度，用來算加速度
var _breath := 0.0

## [骨頭, 父骨, 相對父骨的位置, 方塊尺寸, 方塊相對骨頭的中心, 顏色]
func _rig() -> Array:
	return [
		["root",    "",       Vector3(0, 2.3, 0),      Vector3(1.4, 1.3, 1.4), Vector3(0, 0, 0),        BODY],

		["spine1",  "root",   Vector3(0, 0.05, -0.65), Vector3(1.4, 1.3, 1.2), Vector3(0, 0.02, -0.3),  BODY],
		["spine2",  "spine1", Vector3(0, 0.10, -0.70), Vector3(1.2, 1.1, 1.1), Vector3(0, 0.05, -0.3),  BODY],
		["neck",    "spine2", Vector3(0, 0.30, -0.55), Vector3(0.8, 0.8, 0.9), Vector3(0, 0.05, -0.35), BODY],
		["head",    "neck",   Vector3(0, 0.15, -0.60), Vector3(0.8, 0.7, 1.4), Vector3(0, 0.10, -0.55), BODY],
		["jaw",     "head",   Vector3(0, -0.20, -0.25),Vector3(0.7, 0.28, 1.1),Vector3(0, -0.05, -0.5), BELLY],

		["arm_l",   "spine2", Vector3(0.42, -0.35, -0.30), Vector3(0.22, 0.22, 0.65), Vector3(0, -0.12, -0.25), DARK],
		["arm_r",   "spine2", Vector3(-0.42, -0.35, -0.30),Vector3(0.22, 0.22, 0.65), Vector3(0, -0.12, -0.25), DARK],

		["tail1",   "root",   Vector3(0, 0.05, 0.65),  Vector3(1.0, 1.0, 1.1), Vector3(0, 0, 0.35),     BODY],
		["tail2",   "tail1",  Vector3(0, -0.05, 0.75), Vector3(0.8, 0.8, 1.1), Vector3(0, 0, 0.35),     BODY],
		["tail3",   "tail2",  Vector3(0, -0.05, 0.75), Vector3(0.55, 0.55, 1.0),Vector3(0, 0, 0.35),    BODY],
		["tail4",   "tail3",  Vector3(0, -0.05, 0.70), Vector3(0.32, 0.32, 1.0),Vector3(0, 0, 0.35),    DARK],

		["thigh_l", "root",   Vector3(0.52, -0.20, 0.10),  Vector3(0.7, 1.2, 0.95), Vector3(0, -0.45, 0),    BODY],
		["shin_l",  "thigh_l",Vector3(0, -0.85, 0.08), Vector3(0.42, 1.1, 0.5), Vector3(0, -0.45, 0),    BODY],
		["foot_l",  "shin_l", Vector3(0, -0.80, -0.10),Vector3(0.5, 0.24, 1.1),Vector3(0, -0.06, -0.3),  DARK],

		["thigh_r", "root",   Vector3(-0.52, -0.20, 0.10), Vector3(0.7, 1.2, 0.95), Vector3(0, -0.45, 0),    BODY],
		["shin_r",  "thigh_r",Vector3(0, -0.85, 0.08), Vector3(0.42, 1.1, 0.5), Vector3(0, -0.45, 0),    BODY],
		["foot_r",  "shin_r", Vector3(0, -0.80, -0.10),Vector3(0.5, 0.24, 1.1),Vector3(0, -0.06, -0.3),  DARK],
	]

func _ready() -> void:
	skel = Skeleton3D.new()
	add_child(skel)
	for e in _rig():
		skel.add_bone(e[0])
		var i := skel.find_bone(e[0])
		_idx[e[0]] = i
		if e[1] != "":
			skel.set_bone_parent(i, _idx[e[1]])
		skel.set_bone_rest(i, Transform3D(Basis(), e[2]))
	skel.reset_bone_poses()

	var parts := MODEL.instantiate()
	for e in _rig():
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = e[0]
		var src := parts.get_node_or_null(NodePath(e[0])) as MeshInstance3D
		if src:
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			mi.transform = src.transform
			att.add_child(mi)
		else:
			att.add_child(_box(e[3], e[4], e[5]))   # 模型缺這塊就退回灰盒
	parts.free()

	_last_pos = global_position

func _box(size: Vector3, offset: Vector3, col: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	return mi

## 咬一口，讓嘴巴張開再合上
func bite() -> void:
	_bite = 1.0

func _process(delta: float) -> void:
	var moved := (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	# 往上爬時腳也要動一下。只算往上的部分，不然下墜會變成空中亂踢
	var speed := Vector2(moved.x, moved.z).length() + maxf(moved.y, 0.0) * 0.5
	var stride := clampf(speed / 11.0, 0.0, 1.5)  # 除數大約等於恐龍的基礎速度
	_phase += delta * (2.0 + speed * 0.55)
	_bite = maxf(_bite - delta * 3.5, 0.0)
	var chomp := sin(_bite * PI)  # 0 -> 1 -> 0

	# 身體這一幀轉了多快，是尾巴甩動的源頭
	var yaw := global_rotation.y
	var yaw_rate := wrapf(yaw - _yaw_prev, -PI, PI) / maxf(delta, 0.0001)
	_yaw_prev = yaw

	# 本地座標的速度：x 是左右、z 是前後（Godot 的前方是 -Z）。
	# 側移和轉彎都會讓身體往內倒，加減速則是前後俯仰。
	var lv := global_basis.inverse() * moved
	var dv := lv - _local_v     # 這一幀速度變了多少
	_local_v = lv

	# 側傾是持續狀態（一直在轉彎就一直傾著），用彈簧追一個目標角度
	var roll_target := clampf(yaw_rate * 0.16 - lv.x * 0.022, -LEAN_MAX, LEAN_MAX)
	_lean_v.x += (roll_target - _lean.x) * LEAN_STIFF * delta
	# 俯仰不是狀態是事件：只有「速度變了」才會點頭。所以拿速度差當衝量踢一下，
	# 再讓彈簧把它收回中間。用 dv 不用加速度，才跟幀率無關。
	_lean_v.y += dv.z * 0.030 - _lean.y * LEAN_STIFF * delta
	_lean_v *= exp(-LEAN_DAMP * delta)
	_lean += _lean_v * delta
	_lean.x = clampf(_lean.x, -LEAN_MAX, LEAN_MAX)
	_lean.y = clampf(_lean.y, -0.25, 0.25)

	# 位移延遲：身體有重量，方向一變就被留在後面，再被拖回來。同樣是衝量
	_drift_v -= Vector2(dv.x, dv.z) * 0.10
	_drift_v -= _drift * DRIFT_STIFF * delta
	_drift_v *= exp(-DRIFT_DAMP * delta)
	_drift = (_drift + _drift_v * delta).limit_length(0.30)

	# 站著不動時的呼吸和重心晃動。沒有這個，停下來就變雕像
	_breath += delta * 1.6
	var idle := 1.0 - clampf(stride, 0.0, 1.0)

	# 腳：左右差半個週期，小腿跟著晚一點
	for side in [["_l", 0.0], ["_r", PI]]:
		var s: String = side[0]
		var o: float = side[1]
		_pose("thigh" + s, Vector3.RIGHT, sin(_phase + o) * 0.55 * stride)
		_pose("shin" + s, Vector3.RIGHT, (sin(_phase + o - 1.1) * 0.35 - 0.35) * stride)
		_pose("foot" + s, Vector3.RIGHT, (sin(_phase + o - 2.0) * 0.3 + 0.3) * stride)

	# 身體隨步伐上下起伏，再疊上位移延遲和呼吸
	skel.position = Vector3(_drift.x,
		absf(sin(_phase)) * 0.12 * stride + sin(_breath * 0.5) * 0.025 * idle,
		_drift.y)

	# 尾巴：轉身往外甩 + 走路跟著擺，然後一節傳一節
	var tail_yaw_drive := clampf(-yaw_rate * 0.20, -0.65, 0.65) + sin(_phase) * 0.09 * stride
	var tail_pitch_drive := clampf(-moved.y * 0.035, -0.30, 0.30) + 0.06
	_propagate(_tail_yaw, _tail_yaw_v, tail_yaw_drive, TAIL_STIFF, TAIL_DAMP, delta)
	_propagate(_tail_pitch, _tail_pitch_v, tail_pitch_drive, TAIL_STIFF, TAIL_DAMP, delta)
	for i in 4:
		_pose_pyr("tail%d" % (i + 1), _tail_pitch[i], _tail_yaw[i], _lean.x * 0.12)

	# 脊椎到頭：同一套邏輯，但幅度小、追得緊，轉身時上半身會晚一點跟上
	_propagate(_spine_yaw, _spine_yaw_v, clampf(-yaw_rate * 0.09, -0.28, 0.28),
		SPINE_STIFF, SPINE_DAMP, delta)
	# 側傾分散在幾節脊椎上（不放在 root，不然腿會跟著翻起來），
	# 頭再反向轉回去——掠食者跑起來頭是穩的，這一下最像活的。
	_pose_pyr("spine1", 0.06 + sin(_phase * 0.4) * 0.02 + _lean.y * 0.50,
		_spine_yaw[0], _lean.x * 0.45)
	_pose_pyr("spine2", _lean.y * 0.30, _spine_yaw[1], _lean.x * 0.35)
	_pose_pyr("neck", -0.20 + sin(_phase) * 0.05 * stride + chomp * 0.35 + look_pitch * 0.45
		+ sin(_breath) * 0.030 * idle, _spine_yaw[2], _lean.x * 0.25)
	_pose_pyr("head", 0.18 - chomp * 0.25 + look_pitch * 0.35 - _lean.y * 0.55,
		_spine_yaw[3] + sin(_breath * 0.31) * 0.10 * idle, -_lean.x * 0.75)
	_pose("jaw", Vector3.RIGHT, -0.12 - chomp * 0.65)

	# 小手貼著身體晃一下
	_pose("arm_l", Vector3.RIGHT, -0.7 + sin(_phase) * 0.15 * stride + sin(_breath) * 0.04 * idle)
	_pose("arm_r", Vector3.RIGHT, -0.7 - sin(_phase) * 0.15 * stride + sin(_breath) * 0.04 * idle)

## 旋轉延遲傳遞：第 0 節追 driver，之後每一節追前一節「上一幀」的角度。
## 彈簧的過衝就是彈性，追不上的落差就是延遲。
func _propagate(ang: Array, vel: Array, driver: float,
		stiff: float, damp: float, delta: float) -> void:
	var prev := ang.duplicate()
	for i in ang.size():
		var target: float = driver if i == 0 else prev[i - 1]
		vel[i] += (target - ang[i]) * stiff * delta
		vel[i] *= exp(-damp * delta)   # 這樣寫才跟幀率無關
		ang[i] += vel[i] * delta

func _pose_py(bone: String, pitch: float, yaw: float) -> void:
	_pose_pyr(bone, pitch, yaw, 0.0)

func _pose_pyr(bone: String, pitch: float, yaw: float, roll: float) -> void:
	skel.set_bone_pose_rotation(_idx[bone], Quaternion.from_euler(Vector3(pitch, yaw, roll)))

func _pose(bone: String, axis: Vector3, angle: float) -> void:
	skel.set_bone_pose_rotation(_idx[bone], Quaternion(axis, angle))
