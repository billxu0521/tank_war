class_name CowboyRig
extends Node3D
## 別人眼中的牛仔（有骨架的版本）：models/cowboy_anim.glb，Tripo 綁骨架＋預設動作（blender/cowboy_anim.py）。
## 全身播 Tripo 的動作（站、走、跑、跳、爬、近戰、中彈），手臂再蓋上端槍姿勢（hold），
## 脊椎、脖子、手臂跟著抬頭低頭轉。近戰、爬梯、翻越時放開手臂，讓動作自己的手臂出來（槍先藏起來）。
## 動畫手動推進（advance）：讓 AnimationPlayer 自己跑的話，它會在這裡之後才更新，把蓋上去的手臂洗掉。
## 蹲沒有動作，照舊由 cowboy.gd 把整個身體壓扁。
## 站在地上時腳貼地（IK）：每段動作先整個抬到鞋底貼平地，每隻腳再在腳跟、腳尖往下打射線找真的地面，
## 踩地的腳吸到地面、抬起的腳照動作高度；低的那隻腳要踩得到就把臀部放低，腿再彎過去。

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
## 動作原地播時本來的步速（公尺/秒，腳踩地往後滑的速度，量出來的）。播放倍率＝實際速度÷這個，腳才不會在地上滑
const WALK_PACE := 1.2
const RUN_PACE := 4.0
## 比這個快就播 run：遊戲的「走」是每秒 5 公尺，其實是小跑，慢走的動作加速到那裡太急
## 已經在跑要掉到 RUN_FROM - 0.3 才換回走：斜著貼牆走速度會卡在這附近，不留緩衝會一直切
const RUN_FROM := 3.5
## 腳的 IK：往上往下各找多遠的地面、臀部最多放低多少（公尺）
const FOOT_REACH := 0.5
const HIP_DROP := 0.4
## 動作裡（平地）鞋底離地這麼近（公尺）算踩在地上，吸到真的地面；離到 PLANT_OFF 以上算抬腳，照動作的高度擺在真的地面上方，中間漸變。
## 看動作不看真的地面：斜坡下坡那隻腳離坡面本來就遠，看真的地面會被當成抬腳。Tripo 的動作踩地的腳有時浮空幾公分、腳尖有時穿地，光靠整段抬一個高度兩邊顧不到
const PLANT_ON := 0.05
const PLANT_OFF := 0.10
## 腳尖尖端在腳趾骨前面多遠（公尺）：腳尖那條射線打在這裡
const TOE_TIP := 0.11
## 以下開場量一次，所有骨架牛仔共用
## Tripo 的動作腳會踩到地面以下（站 6、走 17、跑 28 公分）：每段動作整個身體抬到最低那格鞋底剛好貼地
static var _lift := {}  # 動作名 -> 身體要抬多高（公尺）
## 左右腳的鞋底點：靜止姿勢離地 3 公分內的網格點（同位置只留一個，最多 40 個），存成 [[骨頭, 骨頭座標裡的點, 權重], ...]
## 每格照骨頭自己算蒙皮後的位置，看鞋底真正最低在哪（腳踝骨頭離鞋底的距離會隨腳掌彎曲變）
static var _soles := []

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
var _hips := -1
var _legs := []         # 左右各 [大腿, 小腿, 腳] 的骨頭編號
var _foot_h := [0.0, 0.0]   # 每隻腳要上下挪多少（地面高低＋吸地）
var _toes := []         # 左右腳趾骨
var _ik_w := 0.0        # 腳貼地蓋多少（跳、爬、翻越時收掉）
var _ray_skip: Array[RID] = []   # 射線不打自己的碰撞體
var _lift_now := 0.0    # 現在抬多高（換動作時慢慢過去，不要一下跳）
var _drop := 0.0        # 臀部現在放低多少（抹平：一腳踏出台階邊時身體不要一格掉下去）


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
	_hips = skeleton.find_bone("mixamorig_Hips")
	for side in ["Left", "Right"]:
		_legs.append([skeleton.find_bone("mixamorig_%sUpLeg" % side), skeleton.find_bone("mixamorig_%sLeg" % side),
			skeleton.find_bone("mixamorig_%sFoot" % side)])
	var body := get_parent()
	while body and not body is CollisionObject3D:
		body = body.get_parent()
	if body:
		_ray_skip = [(body as CollisionObject3D).get_rid()]
	for side in ["Left", "Right"]:
		_toes.append(skeleton.find_bone("mixamorig_%sToeBase" % side))
	if _soles.is_empty():
		_find_soles()
	if _lift.is_empty():
		_measure_lift()
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
func update(delta: float, speed: float, vy: float, act: int, pitch: float) -> void:
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
		elif speed > RUN_FROM - (0.3 if anim.assigned_animation == &"run" else 0.0):
			want = &"run"
			rate = speed / RUN_PACE
		elif speed > 0.3:
			want = &"walk"
			rate = maxf(speed / WALK_PACE, 0.6)
		if anim.assigned_animation != want:   # 比 assigned 不比 current：跳躍播完停住時 current 是空的，比 current 會一直重播
			anim.play(want, BLEND)
		anim.speed_scale = rate
	else:
		anim.speed_scale = 1.0
	anim.advance(delta)
	_lift_now = lerpf(_lift_now, _lift.get(anim.assigned_animation, 0.0), 1.0 - exp(-10.0 * delta))
	_ik_w = move_toward(_ik_w, 1.0 if not _air and (act == ACT_NONE or act == ACT_MELEE) else 0.0, delta * 4.0)
	_move_hips(_lift_now * _ik_w)   # 跳、爬梯、翻越不抬：那些動作的腳本來就不在地上
	_feet(delta)

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


## 腳貼地：每隻腳在腳跟、腳尖各往下打一條射線找地面（打到的點和坡面方向各是一個平面，沿腳掌在兩個平面間漸變），
## 量鞋底離真的地面最近多少（gap）和動作裡離平地多高（lift）：踩地的整隻挪到 gap＝0，抬腳的挪到 gap＝lift。
## 臀部放低到要往下最多的那隻腳踩得到，兩條腿再各自彎到位。
## ponytail: 每個人每幀四條射線、腳掌不跟著坡度轉（斜坡上腳跟或腳尖會離地幾公分）；人多變慢就只做離鏡頭近的
func _feet(delta: float) -> void:
	if _ik_w == 0.0 or not is_inside_tree():
		return
	var xf := skeleton.global_transform
	var up := global_transform.basis.y.normalized()
	var base := global_position   # 角色腳底
	var feet := []
	for i in 2:
		var heel: Vector3 = xf * skeleton.get_bone_global_pose(_legs[i][2]).origin
		var toe: Vector3 = xf * skeleton.get_bone_global_pose(_toes[i]).origin
		var axis := toe - heel
		axis -= up * up.dot(axis)
		var tip := toe + axis.normalized() * TOE_TIP
		axis = tip - heel
		axis -= up * up.dot(axis)
		var gh := _ground(heel, up, base)
		var gt := _ground(tip, up, base)
		var gap := INF
		var lift := INF
		for p in _sole_points(i):
			var w := xf * p
			var t := clampf((w - heel).dot(axis) / axis.length_squared(), 0.0, 1.0) if axis.length_squared() > 1e-6 else 0.0
			var y := up.dot(w - base)
			gap = minf(gap, y - lerpf(_plane(gh, w, up, base), _plane(gt, w, up, base), t))
			lift = minf(lift, y)
		feet.append(heel)
		# 不抹平：踩地那一下腳往下很快，抹平會慢半拍、腳尖先穿地（地面高低是連續的，不抹也不會跳）
		var planted := clampf((PLANT_OFF - lift) / (PLANT_OFF - PLANT_ON), 0.0, 1.0)
		_foot_h[i] = maxf(lift, 0.0) * (1.0 - planted) - gap if gap < INF else 0.0   # 沒有鞋底點（換了模型）就不挪
	var h := [_foot_h[0] * _ik_w, _foot_h[1] * _ik_w]
	_drop = lerpf(_drop, clampf(minf(h[0], h[1]), -HIP_DROP, 0.0), 1.0 - exp(-15.0 * delta))
	_move_hips(_drop)
	var fwd := (xf.basis.inverse() * -global_transform.basis.z).normalized()
	for i in 2:
		_leg_ik(_legs[i], xf.affine_inverse() * (feet[i] + up * h[i]), fwd)


## p 底下的地面：[打到的點, 坡面方向]；沒打到算角色腳底那層平地
func _ground(p: Vector3, up: Vector3, base: Vector3) -> Array:
	var flat := p - up * up.dot(p - base)
	var q := PhysicsRayQueryParameters3D.create(flat + up * FOOT_REACH, flat - up * FOOT_REACH, 1, _ray_skip.duplicate())
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	for t in 3:   # 打到別的玩家、恐龍（大家都在第 1 層）：跳過它再打，腳不要踩到別人身上
		if not hit or not hit.collider is CharacterBody3D:
			break
		q.exclude += [hit.rid]
		hit = space.intersect_ray(q)
	if not hit or hit.collider is CharacterBody3D:
		return [flat, up]
	return [hit.position, hit.normal]


## 地面平面 g（_ground 的結果）在 w 正下方比角色腳底高多少
func _plane(g: Array, w: Vector3, up: Vector3, base: Vector3) -> float:
	var n: Vector3 = g[1]
	var d: Vector3 = w - g[0]
	d -= up * up.dot(d)
	return up.dot(g[0] - base) - n.dot(d) / maxf(n.dot(up), 0.3)


## 第 i 隻腳的鞋底點現在在哪（骨架空間）：照綁定的骨頭和權重自己算蒙皮
func _sole_points(i: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var g := {}
	for v: Array in _soles[i]:
		var p := Vector3.ZERO
		for k in range(0, v.size(), 3):
			if not g.has(v[k]):
				g[v[k]] = skeleton.get_bone_global_pose(v[k])
			p += v[k + 2] * ((g[v[k]] as Transform3D) * (v[k + 1] as Vector3))
		out.append(p)
	return out


## 挑鞋底點：靜止姿勢下離地 3 公分內的網格點，離哪隻腳踝近就歸哪隻
func _find_soles() -> void:
	var mi := skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skeleton.reset_bone_poses()
	var to_rig := global_transform.affine_inverse() * skeleton.global_transform
	var ankles := [skeleton.get_bone_global_pose(_legs[0][2]).origin, skeleton.get_bone_global_pose(_legs[1][2]).origin]
	var found := [{}, {}]   # 位置（取到公分）-> 點，同位置只留一個
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var n := weights.size() / verts.size()
		for j in verts.size():
			var v := []
			var p := Vector3.ZERO
			for k in n:
				var w := weights[j * n + k]
				if w <= 0.0:
					continue
				var bi := bones[j * n + k]
				var b := mi.skin.get_bind_bone(bi)
				if b < 0:
					b = skeleton.find_bone(mi.skin.get_bind_name(bi))
				var local := mi.skin.get_bind_pose(bi) * verts[j]
				v.append_array([b, local, w])
				p += w * (skeleton.get_bone_global_pose(b) * local)
			if (to_rig * p).y > 0.03:
				continue
			var side := 0 if p.distance_to(ankles[0]) < p.distance_to(ankles[1]) else 1
			found[side][Vector3i((p * 100.0).round())] = v
	for side in 2:
		var all: Array = found[side].values()
		var keep := []
		for j in range(0, all.size(), maxi(1, ceili(all.size() / 40.0))):
			keep.append(all[j])
		_soles.append(keep)


## 臀部（連整個身體）沿角色的上方移 dy 公尺。Hips 上面還有一根轉過的 Root：要換到 Root 的座標
func _move_hips(dy: float) -> void:
	var root_b := skeleton.get_bone_global_pose(skeleton.get_bone_parent(_hips)).basis
	var up := global_transform.basis.y.normalized()
	skeleton.set_bone_pose_position(_hips, skeleton.get_bone_pose_position(_hips)
		+ root_b.inverse() * (skeleton.global_transform.basis.inverse() * (up * dy)))


## 每段動作從頭播到尾，量鞋底最低到哪（離角色腳底），算出要抬多少
func _measure_lift() -> void:
	var to_rig := global_transform.affine_inverse() * skeleton.global_transform
	for n in anim.get_animation_list():
		var a := anim.get_animation(n)
		anim.play(n)
		var lo := INF
		var t := 0.0
		while t <= a.length:
			anim.seek(t, true)
			for i in 2:
				for p in _sole_points(i):
					lo = minf(lo, (to_rig * p).y)
			t += 1.0 / 15.0
		_lift[n] = -lo


## 兩節的腿彎到 t（骨架空間）：膝蓋留在原本彎的那一面，腳掌朝向不變
func _leg_ik(bones: Array, t: Vector3, fwd: Vector3) -> void:
	var a := skeleton.get_bone_global_pose(bones[0])
	var b := skeleton.get_bone_global_pose(bones[1])
	var c := skeleton.get_bone_global_pose(bones[2])
	var la := a.origin.distance_to(b.origin)
	var lb := b.origin.distance_to(c.origin)
	var dir := (t - a.origin).normalized()
	var d := clampf(a.origin.distance_to(t), absf(la - lb) + 0.001, la + lb - 0.001)
	var bend := b.origin - a.origin
	var pole := bend - dir * bend.dot(dir)
	if pole.length_squared() < 1e-6:   # 腿打直：膝蓋往前彎
		pole = fwd - dir * fwd.dot(dir)
	pole = pole.normalized()
	var cos_a := (la * la + d * d - lb * lb) / (2.0 * la * d)
	var knee := a.origin + dir * (la * cos_a) + pole * (la * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))
	var q1 := Quaternion(bend.normalized(), (knee - a.origin).normalized())
	var c1 := a.origin + q1 * (c.origin - a.origin)
	var q2 := Quaternion((c1 - knee).normalized(), (a.origin + dir * d - knee).normalized())
	var na := q1 * a.basis.get_rotation_quaternion()
	var nb := q2 * q1 * b.basis.get_rotation_quaternion()
	var pa := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bones[0])).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bones[0], pa.inverse() * na)
	skeleton.set_bone_pose_rotation(bones[1], na.inverse() * nb)
	skeleton.set_bone_pose_rotation(bones[2], nb.inverse() * c.basis.get_rotation_quaternion())


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
