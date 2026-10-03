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
const MODEL_LIFT := 0.0    # 腳底在模型原點（腿加長後，docs/尼諾拉.md）；走路時腳由 IK 踩在實際地面上
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
var _snap_bite := false
var _spin := 0.0     # 甩尾時整隻轉一圈：剩下還要轉的角度
# 塵土特效（每台自己播，fx.gd）：上一幀兩隻腳的步伐相位、跺地相位，算「這一幀腳落地了沒」
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
	skel = parts.find_children("*", "Skeleton3D", true, false)[0]
	for i in skel.get_bone_count():
		_idx[skel.get_bone_name(i)] = i
		_rest.append(skel.get_bone_global_rest(i).basis.orthonormalized())
	for i in TAIL_N:
		for a in [_tail_yaw, _tail_yaw_v, _tail_pitch, _tail_pitch_v]:
			a.append(0.0)
	_last_pos = global_position
	for side in ["_l", "_r"]:   # 腿的長度和靜止角度（側面平面裡：從正下方往前量的角度）
		var hip := _rest_pos("thigh" + side)
		var knee := _rest_pos("shin" + side)
		var ankle := _rest_pos("foot" + side)
		var ball := _rest_pos("toe2_1" + side)
		_leg.append({hip = hip, l1 = _yz(knee - hip).length(), l2 = _yz(ankle - knee).length(), lm = _yz(ball - ankle).length(),
			a1r = _ang(knee - hip), a2r = _ang(ankle - knee), a3r = _ang(ball - ankle), neutral = ball})

# --- 走路：腳踩在地上（兩段 IK）---
## 每隻腳的掌心（中趾根）在「支撐期」釘在世界座標不動，身體從上面走過去；「擺動期」抬起來，畫一道弧跨到下一個落點。
## 大腿、小腿的角度由腳的位置反推（膝蓋朝前），腳背的角度照步伐階段給：支撐末段腳跟先抬、擺動時往後收、落地前伸直。
## 步伐相位跟著實際走過的距離跑（走多遠跨幾步），腳不會在地上滑；原地轉身也算走路，會踏步。
## 參考 NIBA 給的走路動畫（docs/尼諾拉.md）：身體幾乎水平、兩腳著地時微微下沉、抬腳時腳趾往下捲、腳掌收得很高。
## 驗證：tools/trex_walk_check.gd（腳滑、踩地、抬腳高度、步伐週期、左右交替、膝蓋方向）
## ponytail: 腿只在側面平面裡解（繞 X 轉），腳的左右位置跟著身體走；原地轉身時支撐腳會往旁邊滑一點。要更準再加大腿的偏擺
const REACH_FWD := 1.5      # 落地時腳掌在中立位置前方多遠（模型單位，遊戲裡 ×1.5）
const REACH_BACK := 0.9     # 離地時在中立位置後方多遠。前後不對稱：踝關節在腳掌後上方，腳往後伸太遠腿就搆不到（自我檢查量到超出腿長 1 單位）
const DUTY_WALK := 0.62     # 走路：一隻腳六成時間踩地，有兩腳同時著地的時候
const DUTY_RUN := 0.40      # 跑步：四成，有騰空
const SWING_LIFT := 0.42    # 擺動期腳掌抬多高（模型單位）
const MIN_CYCLE := 0.9      # 一個循環最快幾秒：撲擊這種爆衝時腳跟不上就讓它滑，不要抖成一團
const HURRY_CYCLE := 0.45  # 腳被拖太遠時的步伐，最快一個循環幾秒
const SETTLE_CYCLE := 1.6   # 停下來時，跨到一半的腳用這個速度放下來
const STAND_RISE := 0.1     # 身體比模型靜止姿勢再抬高多少（模型單位）：靜止姿勢的膝蓋彎快 90 度，參考動畫是腿比較直地走
var _leg := []              # 每隻腳：{hip, l1, l2, lm, a1r, a2r, a3r, neutral}（骨架座標、模型單位）
var _gait := 0.0            # 步伐相位 0~1（左腳）；右腳差半個
var _plant := [Vector3.ZERO, Vector3.ZERO]   # 腳掌現在的世界座標（支撐期釘住不動）
var _swing := [false, false]
var _lift_from := [Vector3.ZERO, Vector3.ZERO]
var _land := [Vector3.ZERO, Vector3.ZERO]
var _landed := [false, false]   # 這一幀剛落地（塵土）
var _curl := [0.0, 0.0]
var _roll := [0.0, 0.0]     # 整條腿繞髖往外（+x）擺的角度
var _leg_out := []          # 上一幀的腿角度（限速用）
var _vel_smooth := Vector3.ZERO
var _body_h := 0.0          # 身體跟著腳的高度下沉多少（模型單位）
var _body_h_v := 0.0
var _body_h_fresh := true
var _ext := [0.0, 0.0]
var _air_land := 0.0
var _spinning := false
var _spin_local := [Vector3.ZERO, Vector3.ZERO]      # 每條腿伸直的程度（髖到踝 ÷ 腿長），上一幀的
var _foot_tilt := 0.0       # 兩腳高低差帶來的側傾
var _prev_ph := [0.0, 0.5]
var _travel_s := 0.0
var _a3_s := [0.0, 0.0]
var _walk_ready_a3 := false
var _swing_duty := [0.6, 0.6]
const MAX_DROP := 1.0       # 一步最多往下踩多深（模型單位，遊戲裡 1.5 公尺）
const LATERAL_MAX := 0.45  # 腳離中立位置左右最多幾（模型單位）
const LAND_SPEED := 10.0    # 擺動中的腳，落點每秒最多移動幾公尺（再加上身體速度）
const LEG_MAX_SPEED := 18.0  # 抬起來的腿關節每秒最多轉幾弧度（約 800 度）
var _walk_ready := false

## 側面平面裡的角度：從正下方往前（-Z）量。骨頭的俯仰（繞 X 轉）正的就是往前
static func _ang(v: Vector3) -> float:
	return atan2(-v.z, -v.y)

static func _dir(a: float) -> Vector3:
	return Vector3(0.0, -cos(a), -sin(a))

static func _yz(v: Vector3) -> Vector3:
	return Vector3(0.0, v.y, v.z)

func _rest_pos(bone: String) -> Vector3:
	return skel.get_bone_global_rest(_idx[bone]).origin

## 腳掌中立位置（靜止時的位置）往前 fwd（模型單位）的世界座標，高度貼到地面
func _foot_world(i: int, fwd: float) -> Vector3:
	return _ground(skel.global_transform * (_leg[i].neutral + Vector3(0, 0, -fwd)))

## 往下打射線找地面；打不到（沒有物理世界的預覽場景）就用骨架靜止時的腳掌高度
func _ground(p: Vector3) -> Vector3:
	var rest_y: float = (skel.global_transform * _leg[0].neutral).y
	var w := get_world_3d()
	if w == null:
		return Vector3(p.x, rest_y, p.z)
	# 從恐龍自己的高度往上 6 公尺開始打，不是從估計的腳點：估計的點偏低時（陡坡、身體高度還在追），
	# 起點會在坡面底下，打穿到下面的地板（操控檢查在 20 度坡上量到腳點低了 1.9 公尺）
	var top := maxf(p.y, global_position.y) + 6.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.z), Vector3(p.x, minf(p.y, global_position.y) - 8.0, p.z))
	var body := get_parent() as CollisionObject3D
	if body:
		q.exclude = [body.get_rid()]
	var hit := w.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Vector3(p.x, rest_y, p.z)
	var foot_h: float = _leg[0].neutral.y * skel.global_basis.get_scale().y   # 腳掌骨頭離腳底的高度
	return Vector3(p.x, hit.position.y + foot_h, p.z)

## 算這一幀兩隻腳的 [大腿, 小腿, 腳背] 俯仰角（放在 Vector3 的 x、y、z）
func _walk(delta: float, moved: Vector3, speed: float, yaw_rate: float, teleported := false, offs := []) -> Array:
	# 第一幀，或身體一下子跳很遠（重生、檢視模式換位置）：兩腳直接擺在身體底下
	if not _walk_ready or teleported:
		_swing = [false, false]
		_vel_smooth = Vector3.ZERO
		_air_land = 0.0   # 落地、轉完的收腳也一起清掉
		for i in 2:
			_plant[i] = _foot_world(i, 0.0)
		_walk_ready = true
	var sw := skel.global_basis.get_scale().x   # 模型單位 → 公尺
	var to_skel := skel.global_transform.affine_inverse()
	_air_land = maxf(_air_land - delta, 0.0) if act != 6 else _air_land
	var run_k := clampf((speed - 4.0) / 7.0, 0.0, 1.0)
	var duty := lerpf(DUTY_WALK, DUTY_RUN, run_k)
	var k := clampf(speed / 2.5, 0.35, 1.0)        # 慢下來就跨小步（前後一起縮，腳才不會落在前面、拖到後面搆不到）
	var cycle_dist := (REACH_FWD + REACH_BACK) * k * sw / duty   # 走一個循環前進多少公尺
	var travel := speed + absf(yaw_rate) * 2.0       # 原地轉身也要踏步（2 公尺 ≈ 腳到轉軸的距離）
	var rate := travel / cycle_dist
	if _swing[0] or _swing[1]:
		rate = maxf(rate, 1.0 / SETTLE_CYCLE)        # 跨到一半的腳要放下來
	# 原地轉身時步伐可以快一點：boss 0.5 秒就轉 90 度，一般的上限下來不及跨一步，踩著的腳只好在地上滑（操控檢查量到 1.5 公尺）
	var turning := clampf((absf(yaw_rate) * 2.0 - speed) / 4.0, 0.0, 1.0)
	rate = minf(rate, 1.0 / lerpf(MIN_CYCLE, HURRY_CYCLE, turning))
	# 急轉彎、側移、被推開、跑步起步：踩著的腳被拉得太遠，步伐加快，讓它早點抬起來跨。
	# 不能直接跳相位或把腳搬回來：會一幀跳過去（檢視模式的 8 字繞圈量過，腿一幀轉 20 度）
	for i in 2:
		# 前後拉太遠，或往左右偏太多（原地快轉時腳會被掃到身體另一邊；正常走路左右幾乎不偏）：早點跨
		var off: Vector3 = to_skel * (_plant[i] as Vector3) - _leg[i].neutral
		# 踩著的腿快伸直了（上坡起步時後腳又低又後面）：也要早點抬。腿伸直時膝蓋角度對腳的位置非常敏感，
		# 拖到伸直才抬，第一幀膝蓋會甩很大一下、腳往反方向掃進坡裡（斜坡檢查量過，伸直度到 1.02）
		if not _swing[i] and (Vector2(off.x, off.z).length() > (REACH_FWD + REACH_BACK) * 0.75 or absf(off.x) > 0.35):
			# 原地轉身時可以比一般上限快（腳會被掃到身體另一邊）；走路、側移時不行（遊戲自我檢查的兩腳反相、側傾量過）
			rate = minf(maxf(rate * 2.5, 1.0 / SETTLE_CYCLE), 1.0 / lerpf(MIN_CYCLE, HURRY_CYCLE, turning))
		# 腿快伸直（跑步起步時腳被拖得比腿還長，自我檢查量過）：只有這個可以比一般上限快。
		# 其他理由也放寬的話，遊戲裡跑步、側移時步伐會亂（遊戲自我檢查的兩腳反相、側傾量過）
		if not _swing[i] and _ext[i] > 0.95:
			rate = minf(maxf(rate * 2.5, 1.0 / SETTLE_CYCLE), 1.0 / HURRY_CYCLE)
	_gait = fposmod(_gait + rate * delta, 1.0)
	_phase = _gait * TAU                             # 尾巴、手、脖子跟著步伐擺
	var cycle_t := 1.0 / maxf(rate, 0.05)
	var reach := REACH_FWD * k * clampf(speed / 1.0, 0.0, 1.0)   # 停下來時腳收回身體底下
	# 預測落點用的速度要平滑：速度一下子變（起跑、急停），落點會一幀跳兩公尺，腿就跟著抽一下（自我檢查量過）
	_vel_smooth = _vel_smooth.lerp(Vector3(moved.x, 0.0, moved.z), 1.0 - exp(-6.0 * delta))
	var flat := _vel_smooth
	_travel_s = lerpf(_travel_s, travel, 1.0 - exp(-6.0 * delta))
	var travel_s := _travel_s
	# 站著（兩腳都踩地）時，把相位對回腳的實際位置：拖在比較後面的那隻腳，照它離中立位置多遠算它走到支撐期的哪裡。
	# 平常走路兩者本來就一致，幾乎不動；從站著起步時兩腳都在身體底下（支撐期中間），另一隻腳就會馬上往前跨，
	# 不會讓支撐腳被拖完一整段支撐期、拖到後面搆不到（自我檢查量到的起步問題）
	if not _swing[0] and not _swing[1] and travel < 0.3:   # 只在站著的時候：走路中的雙腳著地期這樣撥，後腳永遠抬不起來
		var back := -1
		var back_z := -INF
		for i in 2:
			var z: float = (to_skel * (_plant[i] as Vector3)).z - _leg[i].neutral.z
			if z > back_z:
				back_z = z
				back = i
		# 後腳的相位至少 0.5：兩腳差半個週期，後腳在 0.5 以下的話前腳會被排到擺動期（明明踩著卻一直抬起放下，操控檢查量到一幀轉 92 度）
		var ph_back := clampf(duty * (REACH_FWD * k + back_z) / ((REACH_FWD + REACH_BACK) * k), 0.5, duty * 0.98)
		_gait = fposmod(ph_back - 0.5 * back, 1.0)
	# 撲出去：整隻在空中，兩腳收到身體下面，不踩地（以前腳釘在原地、身體一秒飛 24 公尺，腿被拉直、拖著滑）。
	# 落地後 0.25 秒兩腳從收著的地方放到地上
	var air := act == 6
	if air:
		_air_land = 0.25
	# 甩尾：0.4 秒整隻轉一圈，腳跟著身體一起轉（踩著地原地轉），不然腳釘在原地、腿扭成麻花（操控檢查量到一幀轉 28 度）
	var spin := _spin > 0.0
	if spin and not _spinning:
		for i in 2:
			_spin_local[i] = to_skel * (_plant[i] as Vector3)
			_swing[i] = false
	if _spinning and not spin:   # 轉完：腳從轉完的地方（可能還抬著，長吼時在跺地）慢慢放到地上，跟撲擊落地一樣
		for i in 2:
			_plant[i] = bone_pos("toe2_1" + ("_l" if i == 0 else "_r"))
		_air_land = 0.3
	_spinning = spin
	if spin and _leg_out.size() == 2:
		# 腿整副凍住跟著身體轉（0.4 秒一整圈只是表演，腳一步也來不及跨；用 IK 釘在地上會扭成麻花、穿地）
		return _leg_out
	var out := []
	for i in 2:
		var ph := fposmod(_gait + 0.5 * i, 1.0)
		# 擺動中的腳照「抬起來那時候」的支撐比例走完這一步，相位繞回 0 才落地。
		# 不然走跑切換時比例一變（跑 0.40、走 0.62），半空中的腳會被當成已經落地，一幀掉到幾公尺外（自我檢查量到 9 公尺）
		var wrapped: bool = ph < _prev_ph[i] - 0.5
		_prev_ph[i] = ph
		var stance: bool
		if _swing[i]:
			stance = wrapped or (ph - _swing_duty[i]) / (1.0 - _swing_duty[i]) >= 1.0
		else:
			stance = ph < duty or wrapped
		_landed[i] = false
		var L: Dictionary = _leg[i]
		var a3: float = L.a3r
		var heel := 0.8 * minf(travel_s / 2.0, 1.0)   # 支撐末段腳跟抬多少（用平滑過的速度：急停時腳背才不會一幀轉 35 度）
		if air:
			_swing[i] = false
			var tuck: Vector3 = skel.global_transform * ((_leg[i].neutral as Vector3) + Vector3(0.0, 0.8, 0.5))
			_plant[i] = (_plant[i] as Vector3).lerp(tuck, 1.0 - exp(-14.0 * delta))
			a3 -= 0.7
			_curl[i] = 0.9
		elif not stance:
			if not _swing[i]:
				# 從抬起來那一刻的相位算起：起步時相位被撥過，可能一抬腳就已經在擺動中段，腳會一幀跳過去
				_swing_duty[i] = ph
			var s := clampf((ph - _swing_duty[i]) / (1.0 - _swing_duty[i]), 0.0, 1.0)   # 擺動進度 0~1
			# 落點：落地那一刻腳在中立位置前方 reach，身體到時候會往前走一段
			var t_rem := (1.0 - s) * (1.0 - duty) * cycle_t
			# 側移（斜著走、橫著走）：左右照「站到一半」的時候算，腳落在身體會經過的地方，
			# 踩著的那段身體從腳的一邊移到另一邊，不會一直被拉著（檢視模式量到累積滑一公尺）
			var side_v := skel.global_basis.x.normalized()
			var lat := side_v * flat.dot(side_v)
			# 先往前推、再找地面高度：反過來的話坡上會差 推的距離 × 坡度（20 度坡推 1 公尺差 36 公分，斜坡檢查量過）
			var land := _ground(skel.global_transform * _leg[i].neutral + Vector3(0, 0, 0)
				- skel.global_basis.z.normalized() * reach * sw + flat * t_rem + lat * (0.5 * duty * cycle_t))
			# 落點不能比現在的腳低超過一條腿：前面是懸崖、坑邊，射線會打到底下很遠的地面（操控檢查量到落點低了 6 公尺）。
			# 那就踩在原本的高度（像停在邊上），不要一腳踏空
			land.y = maxf(land.y, (_plant[i] as Vector3).y - MAX_DROP * sw)
			if not _swing[i]:
				_swing[i] = true
				_lift_from[i] = _plant[i]
				_land[i] = land
			else:
				# 落點有速度上限：急停、起跑時步伐一下子變慢變快，預測的落點會一幀跳好幾公尺（自我檢查量到 9 公尺），腿就抽一下
				_land[i] = (_land[i] as Vector3).move_toward(land, (LAND_SPEED + speed) * delta)
			# 等速往前：身體也是等速往前，腳相對身體就是從後面平順地移到前面，任何時候都搆得到。
			# 先慢後快（smoothstep）跑步時抬腳那段被拖在後面；先快後慢會跑到身體前面太遠（自我檢查都量過）
			var e := s
			var foot: Vector3 = (_lift_from[i] as Vector3).lerp(_land[i], e)
			# 高度另外走：往上踩（台階、上坡）先抬高再往前。等速直線的話，往上那步會削到台階邊（操控檢查量過）
			var up: float = (_land[i] as Vector3).y - (_lift_from[i] as Vector3).y
			var ey := smoothstep(0.0, 0.55, s) if up > 0.0 else e   # 往下踩照直線：先停高再放的話最後掉太快，腿跟不上
			# 不能低於起點到落點的直線：均勻的坡上那條線就貼著坡面，只用上面的曲線會在坡上往下沉（斜坡檢查量過）
			foot.y = maxf(foot.y, lerpf((_lift_from[i] as Vector3).y, (_land[i] as Vector3).y, ey))
			# 中間有東西擋（石頭、台階邊）：看起點和落點中間的地面，比兩端連線高就抬更高越過去
			# 看路徑上三個點（只看中點會漏掉靠近落點的台階邊）
			var clear := 0.0
			for f: float in [0.25, 0.5, 0.75]:
				var pt := (_lift_from[i] as Vector3).lerp(_land[i], f)
				clear = maxf(clear, _ground(pt).y - pt.y)
			foot.y += clear * sin(PI * s)
			foot.y += SWING_LIFT * sw * sin(PI * smoothstep(0.0, 1.0, s)) * clampf(travel_s / 2.0, 0.6, 1.0)   # 離地那一刻速度從 0 開始（以前一抬就往上衝，坡上腿伸很直時跟不上、腳會掃進坡裡）；慢的時候也要抬夠高，限速的腿慢半拍時才不會掃到地
			_plant[i] = foot
			# 擺動時腳背往後收，落地前伸回來。從支撐末段腳跟抬起的角度接著走（以前從 0 開始，抬腳那一幀膝蓋跳 0.7 弧度）
			a3 -= heel * (1.0 - smoothstep(0.0, 0.6, s)) + 0.75 * sin(PI * minf(s * 1.3, 1.0))
			_curl[i] = 0.9 * sin(PI * s)
		else:
			if _swing[i]:
				_swing[i] = false
				_landed[i] = true
				_plant[i] = _ground(_land[i])   # 落地那一刻再貼一次地：落點的高度可能是舊的（坡上停下來時量到低了 2 公尺）
			# 支撐末段腳跟抬起來，腳背轉到接近垂直：踝跑到腳趾正上方，腳往後伸時腿才搆得到
			a3 -= heel * smoothstep(duty * 0.55, duty, ph)
			_curl[i] = 0.0
			if _air_land > 0.0:   # 撲擊落地：收著的腳放回地上
				_plant[i] = (_plant[i] as Vector3).move_toward(_foot_world(i, 0.3), 9.0 * sw * delta)
			# 原地快轉時，踩著的腳會被身體掃到另一邊、腿擺不到：左右超過範圍就讓它往旁邊滑一點（連續的，不會跳）
			var lp: Vector3 = to_skel * (_plant[i] as Vector3)
			var nx: float = L.neutral.x
			if absf(lp.x - nx) > LATERAL_MAX:
				lp.x = clampf(lp.x, nx - LATERAL_MAX, nx + LATERAL_MAX)
				_plant[i] = _ground(skel.global_transform * lp)   # 滑到旁邊要重新貼地：坡上左右高低不一樣
		# 腳背角度只是姿態（腳跟抬、腳背收），平滑地追：走跑切換、急停、起步時它的公式會換，直接用會一幀轉二三十度
		_a3_s[i] = move_toward(_a3_s[i], a3, 7.0 * delta) if _walk_ready_a3 else a3
		a3 = _a3_s[i]
		# 兩段 IK：腳掌目標 → 踝 → 膝（膝蓋朝前）
		var ball: Vector3 = to_skel * (_plant[i] as Vector3)
		if offs.size() == 2:   # 出招的腳部動作（跺地抬腳、踏步、張開）：只動這一幀的目標
			ball += offs[i]
		# 左右：腳不在靜止時的那條線上（側移、轉彎時腳釘在地上、身體走開），整條腿繞髖往外或往內擺（_roll），
		# 再把腳轉回腿的平面裡解前後。以前只解前後，腳會被身體拖著橫滑
		var rh: Vector3 = L.hip
		var r0 := atan2(float(L.neutral.x) - rh.x, rh.y - float(L.neutral.y))
		var v := ball - rh
		_roll[i] = clampf(atan2(v.x, -v.y) - r0, -0.6, 0.6)
		ball = rh + Basis(Vector3.BACK, -_roll[i]) * v
		var hip: Vector3 = _yz(L.hip)
		var ankle := _yz(ball) - _dir(a3) * float(L.lm)
		var d := ankle - hip
		var l1: float = L.l1
		var l2: float = L.l2
		_ext[i] = d.length() / (l1 + l2)
		var dl := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)   # 搆不到就把腿伸直
		var ad := _ang(d)
		var a1 := ad + acos(clampf((l1 * l1 + dl * dl - l2 * l2) / (2.0 * l1 * dl), -1.0, 1.0))
		var knee := hip + _dir(a1) * l1
		var a2 := _ang(hip + _dir(ad) * dl - knee)
		var p1: float = a1 - L.a1r
		var p2: float = a2 - L.a2r - p1
		var p3: float = a3 - L.a3r - p1 - p2
		# 關節轉速上限：急轉彎時腳被拖到後面很遠，一抬腳膝蓋要在幾幀內摺 50 度，看起來像抽一下（檢視模式量過）。
		# 限速會讓腳在那一瞬間沒完全踩在目標上，走路檢查的「IK 準」守著平常走路不受影響
		var want := Vector3(p1, p2, p3)
		if _leg_out.size() == 2 and not teleported and not stance:   # 只限抬起來的腳：踩著的腳要釘在地上
			var prev: Vector3 = _leg_out[i]
			var lim := LEG_MAX_SPEED * delta
			want = prev + (want - prev).clamp(Vector3.ONE * -lim, Vector3.ONE * lim)
		out.append(want)
	_leg_out = out
	_walk_ready_a3 = true
	return out

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
	# 載入、切視窗卡一下，一幀可能超過 0.16 秒：脊椎彈簧（硬度 55）在那麼大的時間步會發散亂甩（知識庫二階動態筆記算過）
	delta = minf(delta, 0.05)
	var moved := (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	var teleported := moved.length() * delta > 1.0   # 重生、檢視模式換位置：最快的撲擊 24 m/s 一幀才 0.4 公尺
	if teleported:
		moved = Vector3.ZERO   # 不然那一幀算成時速上百，步伐、側傾、位移延遲全被踢飛
	# 往上爬時腳也要動一下。只算往上的部分，不然下墜會變成空中亂踢
	var speed := Vector2(moved.x, moved.z).length() + maxf(moved.y, 0.0) * 0.5
	var stride := clampf(speed / 11.0, 0.0, 1.5)  # 除數大約等於恐龍的基礎速度
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
			_snap_bite = act == 2   # 咬下去那一下的動作跟著 _snap 收完，不跟著 act 切掉（咬只有 0.15 秒，收招時腳還在空中）
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
	var roll_target := clampf(yaw_rate * 0.16 - lv.x * 0.022 - _foot_tilt * 0.5, -LEAN_MAX, LEAN_MAX)   # 左腳踩低就往左倒
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
	# 身體高度和左右傾斜跟著兩腳實際踩的高度（知識庫 Withersworn 第 8、9 步）：
	# 一腳踩低（下坡、一腳在坑裡）身體就往下沉、往那邊斜，腿才搆得到；不然低的那隻腳懸空（斜坡檢查量過，懸空 2.5 公尺）
	if _walk_ready:
		var to_me := global_transform.affine_inverse()   # 用恐龍節點自己的座標，不用骨架的（骨架會被這裡移動，會繞圈）
		var hs := []
		for i in 2:
			# 抬起來的腳用它要落的地方：下坡時腳還在空中，身體就先往下沉，落地那一刻腿才搆得到
			var at: Vector3 = _land[i] if _swing[i] else _plant[i]
			hs.append((to_me * at).y - (skel.transform * (_leg[i].neutral as Vector3)).y + skel.position.y)
		var sink: float = minf(hs[0], hs[1]) if not _spinning else _body_h   # 甩尾轉圈時身體高度不動（腿凍住）
		sink = clampf(sink, -1.2, 0.3)
		# 剛出生、剛被搬到別的地方：直接到位，不要慢慢沉（不然第一步腿是直的，膝蓋會亂甩）。
		# 瞬移那一幀腳還沒重擺（_walk 在下面才擺），下一幀才用新的腳算
		if teleported:
			_body_h_fresh = true
		elif _body_h_fresh:
			_body_h = sink
			_body_h_v = 0.0
			_body_h_fresh = false
		_body_h_v += (sink - _body_h) * 40.0 * delta
		_body_h_v *= exp(-9.0 * delta)
		_body_h += _body_h_v * delta
		_foot_tilt = lerpf(_foot_tilt, clampf(atan2(hs[0] - hs[1], 1.64), -0.35, 0.35), 1.0 - exp(-6.0 * delta))
	# 身體隨步伐上下起伏，再疊上位移延遲和呼吸。要在腳的 IK 之前設：IK 照這一幀的骨架位置算，之後再動髖就對不上了
	skel.position = Vector3(_drift.x,
		_body_h + STAND_RISE - 0.05 * cos(_phase * 2.0) * minf(stride * 2.0, 1.0) + sin(_breath * 0.5) * 0.025 * idle - _crouch * 0.38 - _rear * 0.15,   # 甩尾不壓低身體：轉的時候腿是凍住的，身體一沉腳就穿地
		_drift.y - _lunge * 0.3 - sin(PI * _snap) * 0.4 * float(_snap_bite))   # 咬下去往前一衝：前後都平順（以前一幀衝 0.4，腿抽 32 度）
	skel.rotation.y = _spin   # 甩尾：整隻轉一圈

	# 腳：踩在地上走（_walk 算 IK）。出招的腿部動作不再疊在關節角度上（那樣腳會離開踩著的地方，往後滑或穿地，
	# 知識庫 IK 筆記指出的）：蹲、後坐、前衝靠上面移動身體，膝蓋由 IK 自己彎；跺地、咬下去踏一步、兩腳張開、站不穩，
	# 改成移動腳的目標（只影響這一幀的姿勢，腳踩的地方不變）
	var offs := []
	for i in 2:
		var o: float = [0.0, PI][i]
		var sg: float = [1.0, -1.0][i]
		var lift := maxf(sin(_breath * 4.4 + o), 0.0) * stomp   # 跺地：輪流抬起來再踩下去（用不會歸零的時間：出招一換 _act_t 歸零，抬著的腳會一幀掉下去）
		# 咬下去：左腳抬起來往前頓一下再放回原地（拱形，起點終點都在地上）。
		# 以前是往前踏再往回滑、兩腳張開、站不穩左右晃，都是踩著的腳在地上被拖（自我檢查量過）
		var step := sin(PI * _snap) * float(_snap_bite and sg > 0.0)
		offs.append(Vector3(0.0, lift * 0.55 + step * 0.45, -step * 0.5))
	var legs := _walk(delta, moved, speed, yaw_rate, teleported, offs)
	for i in 2:
		var s: String = ["_l", "_r"][i]
		var p: Vector3 = legs[i]   # 大腿、小腿、腳背的俯仰（IK 算的）
		# 先繞身體前後軸擺開（_roll，腳的左右），再在腿的平面裡前後擺
		_set_rot("thigh" + s, Basis(Vector3.BACK, _roll[i]) * Basis(Vector3.RIGHT, p.x))
		_pose("shin" + s, Vector3.RIGHT, p.y)
		_pose("foot" + s, Vector3.RIGHT, p.z)
		for t in 3:   # 腳趾：抬腳時往下捲、落地前張開（參考動畫）
			_pose("toe%d_1%s" % [t + 1, s], Vector3.RIGHT, -_curl[i])
			_pose("toe%d_2%s" % [t + 1, s], Vector3.RIGHT, -_curl[i] * 0.6)


	# 尾巴：轉身往外甩 + 走路跟著擺，然後一節傳一節
	# 出招時：長吼甩尾巴、甩尾時尾巴甩直往外、撲擊時打直、被打斷垂下來
	var tail_yaw_drive := clampf(-yaw_rate * 0.20, -0.65, 0.65) + sin(_phase) * 0.09 * stride \
		+ sin(_act_t * 9.0) * 0.55 * _roar + 0.9 * _sweep
	var tail_pitch_drive := clampf(-moved.y * 0.035, -0.30, 0.30) + 0.09 \
		- _rear * 0.20 - _roar * 0.35 - _snap * 0.30 + _crouch * 0.10 + _stun * 0.40 \
		- _hunt * 0.08 - _spot * 0.25   # 尾巴俯仰正的是往下（看截圖確認過）；0.09：參考動畫尾巴是平的、尾尖微垂
	_propagate(_tail_yaw, _tail_yaw_v, tail_yaw_drive, TAIL_STIFF, TAIL_DAMP, delta)
	_propagate(_tail_pitch, _tail_pitch_v, tail_pitch_drive, TAIL_STIFF, TAIL_DAMP, delta)
	for i in TAIL_N:
		_pose_pyr("tail%d" % (i + 1), _tail_pitch[i] * TAIL_PER, _tail_yaw[i] * TAIL_PER, _lean.x * 0.12 * TAIL_PER)

	# 脊椎到頭：同一套邏輯，但幅度小、追得緊，轉身時上半身會晚一點跟上
	_propagate(_spine_yaw, _spine_yaw_v, clampf(-yaw_rate * 0.09, -0.28, 0.28),
		SPINE_STIFF, SPINE_DAMP, delta)
	# 側傾分散在幾節脊椎上（不放在 root，不然腿會跟著翻起來），
	# 頭再反向轉回去——掠食者跑起來頭是穩的，這一下最像活的。
	# -0.12：身體壓平（設定圖「保持水平重心」、參考動畫背是平的）；模型靜止姿勢胸口偏高
	_pose_pyr("spine1", -0.12 + sin(_phase * 0.4) * 0.02 + _lean.y * 0.50 - _crouch * 0.30 - _lunge * 0.20 + _roar * 0.15
		+ _rear * 0.12 - _snap * 0.35 * float(_snap_bite) + _spot * 0.15,
		_spine_yaw[0], _lean.x * 0.45)
	_pose_pyr("spine2", _lean.y * 0.30, _spine_yaw[1], _lean.x * 0.35)
	_pose_pyr("neck", -0.20 + sin(_phase) * 0.05 * stride + chomp * 0.35 + look_pitch * 0.45
		+ sin(_breath) * 0.030 * idle + _rear * 0.45 + _roar * 0.55 - _crouch * 0.15 - _stun * 0.45
		- _snap * 0.45 * float(_snap_bite) + _spot * 0.55 + _search * 0.25 - _hunt * 0.12 - roam * 0.08 - sniff * 0.35
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
	var arm_k := -0.7 + _lunge * 1.0 + _snap * 0.6 * float(_snap_bite) - _crouch * 0.4 + _stun * 0.5 + _rear * 0.3
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
		# 腳步：_walk 記下這一幀落地的腳
		if _landed[i] and stride > 0.25:
			var run := stride > 0.7
			Fx.dust(w, bone_pos(foot), back + Vector3.UP * 0.6, 1.4 if run else 0.6, 12 if run else 4, 4.0 if run else 1.5, 2.2 if run else 1.4)
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
