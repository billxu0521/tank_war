class_name Trex
extends Node3D
## 暴龍：Blender 建的蒙皮模型（models/trex_hd.glb，blender/trex_hd.py 產生）——一整張皮包在 47 根骨頭上。
##
## 動畫是程式算的，不用 AnimationPlayer——走路快慢直接跟著實際位移，
## 而且不管是自己那隻還是別人同步過來的都會動。
##
## 尾巴和脊椎用「旋轉延遲傳遞」：每一節用彈簧去追**前一節上一幀**的角度。
## 追不上就是延遲，追過頭就是過衝，慣性和彈性都是這樣長出來的。
## 參考 https://www.youtube.com/watch?v=7yXqfESL5qo
##
## 骨頭的靜止朝向是 Blender 給的（每根沿自己的方向），下面的動作程式都當成「靜止時沒有轉角、軸是世界的 x 右 y 上 z 後」來寫，
## 所以 _set_rot 會先換算：在父骨的靜止朝向裡套上旋轉。改骨架不用動任何一行動作程式。

const MODEL := preload("res://models/trex_hd.glb")
const MODEL_LIFT := 0.25   # 舊模型腳底離原點約 0.25，新模型腳底在 0；墊回去，boss / dino 場景的位置和碰撞不用改
const TAIL_N := 8          # 尾巴節數（舊骨架 4 節）。每節角度乘 TAIL_PER，整條彎的總量跟以前一樣
const TAIL_PER := 0.5

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
# 中彈：往子彈推的方向晃一下（衝量踢進側傾和位移延遲的彈簧，彈簧自己會穩回來）
const FLINCH_LEAN := 3.0
const FLINCH_DRIFT := 2.0

var skel: Skeleton3D
var _idx := {}          # 骨頭名字 -> index
var _phase := 0.0
var look_pitch := 0.0   # 由 dino.gd 餵進來，讓頭跟著視角抬
var _bite := 0.0        # 1 -> 0，咬擊動作的進度
## boss 的動作狀態（boss.gd 的 ACT_*，同步來的）：預備動作的姿勢從這裡來。0 = 沒在出招
var act := 0
# 幾個姿勢的份量（0~1），每幀往 act 要的值追，動作才不會一格一格跳
var _rear := 0.0     # 咬的預備：頭往後仰、嘴微張
var _roar := 0.0     # 蓄力：仰頭張大嘴吼、頭甩
var _crouch := 0.0   # 撲擊的預備：身體壓低、往前傾
var _lunge := 0.0    # 撲出去：身體前衝、嘴張開
var _stun := 0.0     # 被打斷：頭垂下來晃
var _sweep := 0.0    # 甩尾：尾巴甩直、兩腳張開
var _recover := 0.0  # 收招：甩頭、喘
var _spot := 0.0     # 發現人：挺起來、頭抬高張嘴吼（不跺腳、不揮手，跟蓄力分得開）
## boss 的心情（boss.gd 的 MOOD_*：0 逛、1 找、2 追，同步來的）。每個心情頭的高低、動法不一樣，玩家看得出牠在幹嘛。
## -1 = 不是 boss（玩家操控的恐龍），不套心情的姿勢
var mood := -1
var _roam := 0.0     # 逛：頭放低、不時低頭聞地
var _search := 0.0   # 找：頭抬高、左右張望
var _hunt := 0.0     # 追：頭往前伸低、嘴微張、尾巴打直
var _toss := 0.0     # 頭被打中：甩一下頭，1 → 0
var _toss_side := 1.0
var _act_t := 0.0    # 這個動作開始多久了（每台自己算，不同步）
var _last_act := 0
var _snap := 0.0     # 出手那一下的衝量（咬下去、撲出去）：1 → 0
var _spin := 0.0     # 甩尾時整隻轉一圈：剩下還要轉的角度
# 塵土特效（每台自己播，fx.gd）：上一幀兩隻腳的步伐相位、跺地相位，算「這一幀腳落地了沒」
var _step_prev := [0.0, 0.0]
var _stomp_prev := [0.0, 0.0]
var _fx_tick := 0.0   # 連續噴的特效（長吼的鼻息、撲擊的塵土尾巴）多久噴一次
var _last_pos := Vector3.ZERO
var _yaw_prev := 0.0
# 骨鏈的角度和角速度。用 Array 不用 PackedFloat32Array，才傳得進函式改得到
var _tail_yaw := []
var _tail_yaw_v := []
var _tail_pitch := []
var _tail_pitch_v := []
var _rest := []         # 每根骨頭的全域靜止朝向（Basis）
var _spine_yaw := [0.0, 0.0, 0.0, 0.0]   # spine1, spine2, neck, head
var _spine_yaw_v := [0.0, 0.0, 0.0, 0.0]
var _lean := Vector2.ZERO     # x 側傾（正 = 往左倒）, y 俯仰（正 = 抬頭）
var _lean_v := Vector2.ZERO
var _drift := Vector2.ZERO    # 身體相對腳的位移延遲（本地座標的左右、前後）
var _drift_v := Vector2.ZERO
var _local_v := Vector3.ZERO  # 上一幀的本地速度，用來算加速度
var _breath := 0.0

func _ready() -> void:
	var parts := MODEL.instantiate() as Node3D
	add_child(parts)
	parts.position.y = MODEL_LIFT
	Viewmodel.mark_meshes(parts, Viewmodel.TARGET_MARK)
	_recolor(parts)
	skel = parts.find_children("*", "Skeleton3D", true, false)[0]
	for i in skel.get_bone_count():
		_idx[skel.get_bone_name(i)] = i
		_rest.append(skel.get_bone_global_rest(i).basis.orthonormalized())
	for i in TAIL_N:
		for a in [_tail_yaw, _tail_yaw_v, _tail_pitch, _tail_pitch_v]:
			a.append(0.0)
	_last_pos = global_position

## 主色從橄欖綠改成偏冷的灰綠：橄欖綠跟樹、枯草同色相，背後有樹就融進去（美術風格評估第 3 項，FPS 可讀性）。
## 改在遊戲裡不改模型檔：材質在 mark_meshes 已經複製過一份，只動這隻恐龍
const RECOLOR := {"d_olive": Color("666a4c"), "d_moss": Color("555a45")}   # 純冷灰綠背光面像石像，往暖橄欖 #73704A 偏一點（第 80 版審查）
func _recolor(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m and RECOLOR.has(m.resource_name):
				m.albedo_color = RECOLOR[m.resource_name]

## 咬一口，讓嘴巴張開再合上
func bite() -> void:
	_bite = 1.0

## 中彈晃一下。push：本地座標裡被推的方向（水平、長度 1）；strength 0~1。head：頭被打中，甩頭
func flinch(push: Vector3, strength: float, head: bool) -> void:
	if head:
		_toss = 1.0
		_toss_side = 1.0 if randf() < 0.5 else -1.0
		return
	_lean_v += Vector2(-push.x, push.z) * FLINCH_LEAN * strength   # 往右推就往右倒、從前面打就往後仰
	_drift_v += Vector2(push.x, push.z) * FLINCH_DRIFT * strength

func _process(delta: float) -> void:
	var moved := (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	# 往上爬時腳也要動一下。只算往上的部分，不然下墜會變成空中亂踢
	var speed := Vector2(moved.x, moved.z).length() + maxf(moved.y, 0.0) * 0.5
	var stride := clampf(speed / 11.0, 0.0, 1.5)  # 除數大約等於恐龍的基礎速度
	_phase += delta * (2.0 + speed * 0.55)
	_bite = maxf(_bite - delta * 3.5, 0.0)
	var chomp := sin(_bite * PI)  # 0 -> 1 -> 0
	# 預備動作的姿勢（boss.gd 的 ACT_*：1 咬預備、3 蓄力、5 撲擊預備、6 撲出去、8 被打斷、9 發現人）。
	# 這副骨架俯仰是正的往上抬（跟 chomp 那幾行相反），看截圖確認過
	if act != _last_act:
		_act_fx(_last_act, act)
		_last_act = act
		_act_t = 0.0
		if act == 2 or act == 6:
			_snap = 1.0
		if act == 4:
			_spin = TAU   # 甩尾：整隻轉一圈，尾巴掃一整圈
	_act_t += delta
	_fx_step(delta, speed)   # 用最上面算好的速度：_last_pos 在那裡已經更新成這一幀了
	_snap = maxf(_snap - delta * 3.0, 0.0)
	_spin = maxf(_spin - delta * TAU / 0.4, 0.0)   # 0.4 秒轉完
	var k := 1.0 - exp(-10.0 * delta)
	_sweep += (float(act == 4 or _spin > 0.0) - _sweep) * k
	_recover += (float(act == 7) - _recover) * k
	_rear += (float(act == 1) - _rear) * k
	_roar += (float(act == 3) - _roar) * k
	_crouch += (float(act == 5) - _crouch) * k
	_lunge += (float(act == 6) - _lunge) * k
	_stun += (float(act == 8) - _stun) * k
	_spot += (float(act == 9) - _spot) * k
	var km := 1.0 - exp(-4.0 * delta)   # 心情換得慢一點，不是一格一格跳
	_search += (float(mood == 1) - _search) * km
	_hunt += (float(mood == 2) - _hunt) * km
	_roam += (float(mood == 0) - _roam) * km
	var roam := _roam
	var sniff := pow(maxf(sin(_breath * 0.35), 0.0), 4.0) * roam   # 逛的時候不時低頭聞地
	var scan := sin(_breath * 1.1) * 0.45 * _search                # 找的時候左右張望
	_toss = maxf(_toss - delta * 4.0, 0.0)
	var toss := sin(_toss * PI)
	var shake := sin(_breath * 23.0) * 0.08 * _roar + sin(_breath * 7.0) * 0.18 * _stun

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

	# 出招的腿部動作（疊在走路上）。thigh 正的是大腿往前抬、shin 負的是膝蓋彎、foot 正的是腳尖往下（看截圖確認過）
	#   咬預備：重心往後坐（兩膝微彎）；咬下去：左腳往前踏一步
	#   蓄力長吼：兩腳輪流跺地；甩尾：兩腳張開站穩
	#   撲擊預備：深蹲；撲出去：大腿往後蹬直
	#   被打斷：兩腳晃、站不穩
	var stomp := _roar * 0.5
	var wobble := sin(_act_t * 6.0) * 0.22 * _stun
	# 腳：左右差半個週期，小腿跟著晚一點
	for side in [["_l", 0.0, 1.0], ["_r", PI, -1.0]]:
		var s: String = side[0]
		var o: float = side[1]
		var sg: float = side[2]
		var lift := maxf(sin(_act_t * 7.0 + o), 0.0) * stomp   # 跺地：輪流抬起來再踩下去
		var step := _snap * 0.55 * float(act == 2 and sg > 0.0)  # 咬下去那一步
		_pose_pyr("thigh" + s, sin(_phase + o) * 0.55 * stride + _rear * 0.25 + _crouch * 0.70 - _lunge * 0.65
				+ lift * 0.9 + step + wobble * sg,
			0.0, sg * (_sweep * 0.25 + _crouch * 0.10))
		_pose("shin" + s, Vector3.RIGHT, (sin(_phase + o - 1.1) * 0.35 - 0.35) * stride - _rear * 0.35 - _crouch * 1.05
			+ _lunge * 0.25 - lift * 1.2 - step * 0.6)
		_pose("foot" + s, Vector3.RIGHT, (sin(_phase + o - 2.0) * 0.3 + 0.3) * stride + _rear * 0.10 + _crouch * 0.35
			+ _lunge * 0.45 + lift * 0.3)

	# 身體隨步伐上下起伏，再疊上位移延遲和呼吸
	skel.position = Vector3(_drift.x,
		absf(sin(_phase)) * 0.12 * stride + sin(_breath * 0.5) * 0.025 * idle - _crouch * 0.55 - _rear * 0.15 - _sweep * 0.15,
		_drift.y - _lunge * 0.3 - _snap * 0.4 * float(act == 2))
	skel.rotation.y = _spin   # 甩尾：整隻轉一圈

	# 尾巴：轉身往外甩 + 走路跟著擺，然後一節傳一節
	# 出招時：長吼甩尾巴、甩尾時尾巴甩直往外、撲擊時打直、被打斷垂下來
	var tail_yaw_drive := clampf(-yaw_rate * 0.20, -0.65, 0.65) + sin(_phase) * 0.09 * stride \
		+ sin(_act_t * 9.0) * 0.55 * _roar + 0.9 * _sweep
	var tail_pitch_drive := clampf(-moved.y * 0.035, -0.30, 0.30) + 0.06 \
		- _rear * 0.20 - _roar * 0.35 - _snap * 0.30 + _crouch * 0.10 + _stun * 0.40 \
		- _hunt * 0.08 - _spot * 0.25   # 尾巴俯仰正的是往下（看截圖確認過）
	_propagate(_tail_yaw, _tail_yaw_v, tail_yaw_drive, TAIL_STIFF, TAIL_DAMP, delta)
	_propagate(_tail_pitch, _tail_pitch_v, tail_pitch_drive, TAIL_STIFF, TAIL_DAMP, delta)
	for i in TAIL_N:
		_pose_pyr("tail%d" % (i + 1), _tail_pitch[i] * TAIL_PER, _tail_yaw[i] * TAIL_PER, _lean.x * 0.12 * TAIL_PER)

	# 脊椎到頭：同一套邏輯，但幅度小、追得緊，轉身時上半身會晚一點跟上
	_propagate(_spine_yaw, _spine_yaw_v, clampf(-yaw_rate * 0.09, -0.28, 0.28),
		SPINE_STIFF, SPINE_DAMP, delta)
	# 側傾分散在幾節脊椎上（不放在 root，不然腿會跟著翻起來），
	# 頭再反向轉回去——掠食者跑起來頭是穩的，這一下最像活的。
	_pose_pyr("spine1", 0.06 + sin(_phase * 0.4) * 0.02 + _lean.y * 0.50 - _crouch * 0.30 - _lunge * 0.20 + _roar * 0.15
		+ _rear * 0.12 - _snap * 0.35 * float(act == 2) + _spot * 0.15,
		_spine_yaw[0], _lean.x * 0.45)
	_pose_pyr("spine2", _lean.y * 0.30, _spine_yaw[1], _lean.x * 0.35)
	_pose_pyr("neck", -0.20 + sin(_phase) * 0.05 * stride + chomp * 0.35 + look_pitch * 0.45
		+ sin(_breath) * 0.030 * idle + _rear * 0.45 + _roar * 0.55 - _crouch * 0.15 - _stun * 0.45
		- _snap * 0.45 * float(act == 2) + _spot * 0.55 + _search * 0.25 - _hunt * 0.12 - roam * 0.08 - sniff * 0.35
		+ toss * 0.25,
		_spine_yaw[2] + shake + sin(_act_t * 11.0) * 0.25 * _recover + scan * 0.5 + toss * 0.3 * _toss_side, _lean.x * 0.25)
	_pose_pyr("head", 0.18 - chomp * 0.25 + look_pitch * 0.35 - _lean.y * 0.55 + _rear * 0.25 + _roar * 0.40 - _stun * 0.25
		+ _spot * 0.30 - _hunt * 0.08 - sniff * 0.25 + toss * 0.2,
		_spine_yaw[3] + sin(_breath * 0.31) * 0.10 * idle + shake + scan + toss * 0.4 * _toss_side,
		-_lean.x * 0.75 + shake * 0.5)
	_pose("jaw", Vector3.RIGHT, -0.12 - chomp * 0.65 - _rear * 0.30 - _roar * 0.75 - _lunge * 0.60 - _stun * 0.25
		- _spot * 0.80 - _hunt * 0.12)

	# 小手貼著身體晃一下；長吼時亂揮、撲出去時往前抓、撲擊預備時收起來、被打斷時垂下
	var flail := sin(_act_t * 14.0) * 0.5 * _roar
	var arm_k := -0.7 + _lunge * 1.0 + _snap * 0.6 * float(act == 2) - _crouch * 0.4 + _stun * 0.5 + _rear * 0.3
	_pose("arm_l", Vector3.RIGHT, arm_k + sin(_phase) * 0.15 * stride + sin(_breath) * 0.04 * idle + flail)
	_pose("arm_r", Vector3.RIGHT, arm_k - sin(_phase) * 0.15 * stride + sin(_breath) * 0.04 * idle - flail)

# --- 塵土特效（純表演，每台自己播，見 fx.gd）---

func _world() -> Node:
	return get_tree().get_first_node_in_group(&"arena") if is_inside_tree() else null

## 骨頭在世界裡的位置
func bone_pos(bone: String) -> Vector3:
	return skel.to_global(skel.get_bone_global_pose(_idx[bone]).origin)

## 每幀：跑步每一步揚起一團土（走路小、跑步大）；長吼時跺地起土、鼻孔噴氣；撲擊預備刨土、撲出去拖一道土
func _fx_step(delta: float, speed: float) -> void:
	var w := _world()
	if w == null:
		return
	var back := global_basis.z
	back.y = 0.0
	back = back.normalized()
	var stride := clampf(speed / 11.0, 0.0, 1.5)
	for i in 2:
		var o := 0.0 if i == 0 else PI
		var foot := "foot_l" if i == 0 else "foot_r"
		# 腳步：步伐相位從正變負的那一幀算腳踩下去
		var now := sin(_phase + o)
		if _step_prev[i] > 0.0 and now <= 0.0 and stride > 0.25:
			var run := stride > 0.7
			Fx.dust(w, bone_pos(foot), back + Vector3.UP * 0.6, 1.4 if run else 0.6, 12 if run else 4, 4.0 if run else 1.5, 2.2 if run else 1.4)
		_step_prev[i] = now
		# 長吼的跺地：抬起來的腳踩回去那一下
		var stomp := sin(_act_t * 7.0 + o) * float(act == 3)
		if _stomp_prev[i] > 0.0 and stomp <= 0.0:
			Fx.dust_ring(w, bone_pos(foot), 1.2, 10, 5.0, 0.6)
		_stomp_prev[i] = stomp
	_fx_tick -= delta
	if _fx_tick > 0.0:
		return
	match act:
		3:   # 長吼：鼻孔噴氣
			_fx_tick = 0.22
			var fwd := -global_basis.z
			Fx.puff(w, bone_pos("head") + fwd * 1.2, (fwd + Vector3.UP).normalized(), Color(0.85, 0.82, 0.78, 0.45), 0.9, 0.35, 4)
		5:   # 撲擊預備：後腳刨土
			_fx_tick = 0.12
			Fx.dust(w, bone_pos("foot_l" if randf() < 0.5 else "foot_r"), back + Vector3.UP * 0.4, 0.5, 3, 4.0, 1.0)
		6:   # 撲出去：腳下拖一道土
			_fx_tick = 0.06
			Fx.dust(w, (bone_pos("foot_l") + bone_pos("foot_r")) * 0.5, back + Vector3.UP * 0.5, 0.8, 4, 3.0, 1.4)

## 動作切換那一下的特效
func _act_fx(from: int, to: int) -> void:
	var w := _world()
	if w == null:
		return
	var feet := (bone_pos("foot_l") + bone_pos("foot_r")) * 0.5
	var fwd := -global_basis.z
	fwd.y = 0.0
	match to:
		2:   # 咬下去：踏出去那隻腳起土，嘴前地上一團
			Fx.dust(w, bone_pos("foot_l"), Vector3.UP + fwd * 0.3, 0.7, 5, 2.5)
			Fx.dust(w, Vector3(bone_pos("jaw").x, feet.y, bone_pos("jaw").z), Vector3.UP, 0.6, 5, 2.0, 1.2)
		4:   # 甩尾：整圈掃開一大圈土
			Fx.dust_ring(w, feet, 3.0, 36, 10.0, 1.1)
		6:   # 撲出去：起跳的地方炸一團
			Fx.dust(w, feet, Vector3.UP - fwd * 0.6, 1.1, 10, 4.5)
		8:   # 被打斷：踉蹌揚起一點土
			Fx.dust(w, feet, Vector3.UP, 0.7, 6, 2.0)
		9:   # 發現人：鼻孔噴一大口氣
			Fx.puff(w, bone_pos("head") + fwd * 1.2, (fwd + Vector3.UP * 0.5).normalized(), Color(0.85, 0.82, 0.78, 0.5), 1.2, 0.5, 6)
	if from == 6 and to == 7:   # 撲擊落地：一圈土
		Fx.dust_ring(w, feet, 2.0, 24, 8.0, 1.0)

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
	_set_rot(bone, Basis.from_euler(Vector3(pitch, yaw, roll)))

func _pose(bone: String, axis: Vector3, angle: float) -> void:
	_set_rot(bone, Basis(axis, angle))

## 讀回動作程式寫進去的旋轉（_set_rot 的反算），測試和除錯用：自己靜止 · 本地 · 自己靜止⁻¹ 換回父骨世界朝向裡的 q
func pose_rot(bone: String) -> Quaternion:
	var i: int = _idx[bone]
	var p := skel.get_bone_parent(i)
	var ap: Basis = _rest[p] if p >= 0 else Basis()
	return (ap * Basis(skel.get_bone_pose_rotation(i)) * _rest[i].inverse()).get_rotation_quaternion()

## q 是「父骨的世界朝向」裡的旋轉（舊骨架的寫法）。換成這根骨頭的本地旋轉：父靜止⁻¹ · q · 自己靜止
func _set_rot(bone: String, q: Basis) -> void:
	var i: int = _idx[bone]
	var p := skel.get_bone_parent(i)
	var ap: Basis = _rest[p] if p >= 0 else Basis()
	skel.set_bone_pose_rotation(i, (ap.inverse() * q * _rest[i]).get_rotation_quaternion())
