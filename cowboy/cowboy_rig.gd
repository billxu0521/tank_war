class_name CowboyRig
extends Node3D
## 別人眼中的牛仔（有骨架的版本）：models/cowboy_anim.glb，Tripo 綁骨架＋預設動作（blender/cowboy_anim.py）。
## 全身播 Tripo 的動作（站、走、跑、跳、爬、近戰、中彈），手臂再蓋上端槍姿勢（hold），
## 脊椎、脖子、手臂跟著抬頭低頭轉。近戰、爬梯、翻越時放開手臂，讓動作自己的手臂出來（槍先藏起來）。
## 動畫手動推進（advance）：讓 AnimationPlayer 自己跑的話，它會在這裡之後才更新，把蓋上去的手臂洗掉。
## 蹲沒有動作，照舊由 cowboy.gd 把整個身體壓扁。

const SCENE := preload("res://models/cowboy_anim.glb")
enum { ACT_NONE, ACT_VAULT, ACT_LADDER, ACT_MELEE }
const ARM_BONES := [&"Shoulder", &"Arm", &"ForeArm", &"Hand"]
## 抬頭低頭分給哪幾根骨頭（合計 1＝槍口跟視線一起轉）。手臂是 Spine2 的子骨頭，會疊上脊椎轉的量
const BEND := {&"mixamorig_Spine1": 0.2, &"mixamorig_Spine2": 0.2, &"mixamorig_Neck": 0.3,
	&"mixamorig_LeftArm": 0.6, &"mixamorig_RightArm": 0.6}
## 骨架空間的「角色右手方向」：模型轉了 180 度，角色的 +X 在骨架裡是 -X
const RIGHT := Vector3(-1, 0, 0)
## 近戰只播 slash 中間揮下去那段（整段 6.6 秒，前後是站著）
const SLASH := Vector2(2.0, 4.6)
const SLASH_SPEED := 3.5
const BLEND := 0.2
## 垂直速度超過這個算跳起來、掉下去；回到 AIR_OUT 以下才算落地（中間不換，跳到最高點速度是 0 也不會閃回站姿）
const AIR_IN := 2.0
const AIR_OUT := 0.5

var skeleton: Skeleton3D
var anim: AnimationPlayer
## 槍要不要拿出來：手臂放開（近戰、爬梯、翻越）時兩隻手在做別的事，槍會亂指
var holding := true
var _hold := {}         # 骨頭編號 -> 端槍時的旋轉（相對父骨頭）
var _hold_world := {}   # 上臂的骨頭編號 -> 端槍時在骨架空間的朝向：跑步身體前傾時手臂不跟著，槍口不會朝地
var _bend := {}         # 骨頭編號 -> 抬頭分到的比例
var _hands := {}        # "Left"/"Right" -> 手的骨頭編號
var _hold_w := 1.0      # 端槍姿勢蓋多少（0＝全照動作）
var _one_shot := &""    # 正在播的一次性動作（中彈、近戰），播完回到走跑
var _last_act := ACT_NONE
var _air := false
var _speed := 0.0


func _ready() -> void:
	var m := SCENE.instantiate()
	add_child(m)
	skeleton = m.find_children("*", "Skeleton3D", true, false)[0]
	anim = m.get_node(^"AnimationPlayer")
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for n in [&"idle", &"walk", &"run", &"ladder"]:
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR   # glb 匯入的動畫預設不循環
	anim.play(&"hold")
	anim.advance(0.0)
	for side in ["Left", "Right"]:
		_hands[side] = skeleton.find_bone("mixamorig_%sHand" % side)
		for b in ARM_BONES:
			var i := skeleton.find_bone("mixamorig_%s%s" % [side, b])
			_hold[i] = skeleton.get_bone_pose_rotation(i)
			if b == &"Arm":
				_hold_world[i] = skeleton.get_bone_global_pose(i).basis.get_rotation_quaternion()
	for bone: StringName in BEND:
		_bend[skeleton.find_bone(bone)] = BEND[bone] * (-1.0 if bone.ends_with("Arm") else 1.0)   # 負號＝手臂，乘端槍權重
	anim.play(&"idle")


## 被打一下：播一次中彈（手臂照舊端槍，看得到身體縮一下）。跑動中不播：腿會停住整個人往前滑
func hit() -> void:
	if _one_shot == &"slash" or _speed > 0.5:
		return
	_one_shot = &"hit_to_body_01"
	anim.play(_one_shot, 0.1)


## 每幀：speed 水平速度、vy 垂直速度（公尺/秒，呼叫的人先抹平），act 是 ACT_*，pitch 抬頭角度（弧度，正＝往上看）
func update(delta: float, speed: float, vy: float, act: int, pitch: float, walk_speed: float, sprint_speed: float) -> void:
	_speed = speed
	if act == ACT_MELEE and _last_act != ACT_MELEE:   # 按下去那一刻揮一次；重擊冷卻比這段長，不會揮兩次
		_one_shot = &"slash"
		anim.play_section(_one_shot, SLASH.x, SLASH.y, 0.1, SLASH_SPEED)
	_last_act = act
	if _one_shot != &"" and (not anim.is_playing() or anim.assigned_animation != _one_shot):
		_one_shot = &""
	_air = absf(vy) > (AIR_OUT if _air else AIR_IN)
	if _one_shot == &"":
		var want := &"idle"
		var rate := 1.0
		if act == ACT_LADDER or act == ACT_VAULT:
			want = &"ladder"
			rate = 3.0 if act == ACT_VAULT else 1.5
		elif _air:
			want = &"jump"   # 不循環：掉很久就停在最後一格
			rate = 1.5
		elif speed > (walk_speed + sprint_speed) * 0.5:
			want = &"run"
			rate = clampf(speed / sprint_speed, 0.6, 1.5)
		elif speed > 0.3:
			want = &"walk"
			rate = clampf(speed / walk_speed, 0.6, 1.6)
		if anim.assigned_animation != want:   # 比 assigned 不比 current：跳躍播完停住時 current 是空的，比 current 會一直重播
			anim.play(want, BLEND)
		anim.speed_scale = rate
	else:
		anim.speed_scale = 1.0
	anim.advance(delta)

	var free_arms := _one_shot == &"slash" or act == ACT_LADDER or act == ACT_VAULT
	_hold_w = move_toward(_hold_w, 0.0 if free_arms else 1.0, delta * 6.0)
	holding = _hold_w > 0.5
	for b: int in _hold:
		var q: Quaternion = _hold[b]
		if _hold_world.has(b):   # 上臂照骨架空間擺：扣掉父骨頭（脊椎）現在的朝向
			q = skeleton.get_bone_global_pose(skeleton.get_bone_parent(b)).basis.get_rotation_quaternion().inverse() * _hold_world[b]
		skeleton.set_bone_pose_rotation(b, skeleton.get_bone_pose_rotation(b).slerp(q, _hold_w))
	for b: int in _bend:
		var w: float = _bend[b]
		_turn(b, pitch * (-w * _hold_w if w < 0.0 else w))


## 把骨頭繞「角色的右手方向」轉 angle：換到父骨頭的座標再乘上去
func _turn(b: int, angle: float) -> void:
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(b)).basis.orthonormalized()
	var axis := (parent.inverse() * RIGHT).normalized()
	skeleton.set_bone_pose_rotation(b, Quaternion(axis, angle) * skeleton.get_bone_pose_rotation(b))


## 手握的位置（這個節點的座標）：手腕再往手指方向一點
func hand(side: String) -> Vector3:
	var b: int = _hands[side]
	var wrist := skeleton.get_bone_global_pose(b).origin
	var elbow := skeleton.get_bone_global_pose(skeleton.get_bone_parent(b)).origin
	return to_local(skeleton.global_transform * (wrist + (wrist - elbow).normalized() * 0.04))


## 槍擺哪：握把在右手、槍身朝左手
func gun_transform() -> Transform3D:
	var r := hand("Right")
	return Transform3D(Basis.looking_at(hand("Left") - r), r)
