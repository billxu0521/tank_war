class_name Trex
extends Node3D
## 暴龍的灰盒骨架模型：一副 Skeleton3D，每根骨頭掛一個方塊。
##
## ponytail: 方塊是剛體掛在骨頭上（BoneAttachment3D），不做蒙皮權重。
## 粗模型看得出關節在動就夠了，要平滑變形再換成真正的 skinned mesh。
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

const TAIL_STIFF := 26.0   # 越大跟得越緊，延遲越短
const TAIL_DAMP := 4.5     # 越小晃越久（過衝越明顯）
const SPINE_STIFF := 55.0
const SPINE_DAMP := 8.0

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

	for e in _rig():
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = e[0]
		att.add_child(_box(e[3], e[4], e[5]))

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
	var stride := clampf(speed / 16.0, 0.0, 1.5)  # 站著不動就只剩呼吸
	_phase += delta * (2.0 + speed * 0.55)
	_bite = maxf(_bite - delta * 3.5, 0.0)
	var chomp := sin(_bite * PI)  # 0 -> 1 -> 0

	# 身體這一幀轉了多快，是尾巴甩動的源頭
	var yaw := global_rotation.y
	var yaw_rate := wrapf(yaw - _yaw_prev, -PI, PI) / maxf(delta, 0.0001)
	_yaw_prev = yaw

	# 腳：左右差半個週期，小腿跟著晚一點
	for side in [["_l", 0.0], ["_r", PI]]:
		var s: String = side[0]
		var o: float = side[1]
		_pose("thigh" + s, Vector3.RIGHT, sin(_phase + o) * 0.55 * stride)
		_pose("shin" + s, Vector3.RIGHT, (sin(_phase + o - 1.1) * 0.35 - 0.35) * stride)
		_pose("foot" + s, Vector3.RIGHT, (sin(_phase + o - 2.0) * 0.3 + 0.3) * stride)

	# 身體隨步伐上下起伏
	skel.position.y = absf(sin(_phase)) * 0.12 * stride

	# 尾巴：轉身往外甩 + 走路跟著擺，然後一節傳一節
	var tail_yaw_drive := clampf(-yaw_rate * 0.20, -0.65, 0.65) + sin(_phase) * 0.09 * stride
	var tail_pitch_drive := clampf(-moved.y * 0.035, -0.30, 0.30) + 0.06
	_propagate(_tail_yaw, _tail_yaw_v, tail_yaw_drive, TAIL_STIFF, TAIL_DAMP, delta)
	_propagate(_tail_pitch, _tail_pitch_v, tail_pitch_drive, TAIL_STIFF, TAIL_DAMP, delta)
	for i in 4:
		_pose_py("tail%d" % (i + 1), _tail_pitch[i], _tail_yaw[i])

	# 脊椎到頭：同一套邏輯，但幅度小、追得緊，轉身時上半身會晚一點跟上
	_propagate(_spine_yaw, _spine_yaw_v, clampf(-yaw_rate * 0.09, -0.28, 0.28),
		SPINE_STIFF, SPINE_DAMP, delta)
	_pose_py("spine1", 0.06 + sin(_phase * 0.4) * 0.02, _spine_yaw[0])
	_pose_py("spine2", 0.0, _spine_yaw[1])
	_pose_py("neck", -0.20 + sin(_phase) * 0.05 * stride + chomp * 0.35 + look_pitch * 0.45,
		_spine_yaw[2])
	_pose_py("head", 0.18 - chomp * 0.25 + look_pitch * 0.35, _spine_yaw[3])
	_pose("jaw", Vector3.RIGHT, -0.12 - chomp * 0.65)

	# 小手貼著身體晃一下
	_pose("arm_l", Vector3.RIGHT, -0.7 + sin(_phase) * 0.15 * stride)
	_pose("arm_r", Vector3.RIGHT, -0.7 - sin(_phase) * 0.15 * stride)

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
	skel.set_bone_pose_rotation(_idx[bone], Quaternion.from_euler(Vector3(pitch, yaw, 0.0)))

func _pose(bone: String, axis: Vector3, angle: float) -> void:
	skel.set_bone_pose_rotation(_idx[bone], Quaternion(axis, angle))
