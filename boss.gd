extends "res://dino.gd"
## 恐龍 boss（電腦操控，主機上跑）：在地圖上自己找人、追人、咬人，跟蛋無關（設計見 docs/規劃/2026-10-01-恐龍行為.md）。
## 打不死——血打光會倒地暈 KNOCK_TIME 秒，起來血是滿的，而且先退開一段（導演的高峰）。
##
## 行為樹（bt.gd），每幀從上往下找第一條走得通的：
##   1. 倒地中        → 等
##   2. 出招中        → 把這招做完（預備動作 → 出手 → 收招）
##   3. 導演叫牠退開  → 往離大家遠的地方跑
##   4. 剛確定看到人  → 停下來吼一聲（發現），之後才出招、追（太近的不吼，直接動手）
##   5. 可以出招      → 咬／蓄力甩尾
##   6. 看得到人      → 追最近的
##   7. 瞄到人還不確定 → 停下來盯著、慢慢轉過去（不確定感，ARC Raiders 的做法）
##   8. 剛看丟了人    → 往最後看到的地方追
##   9. 聽到聲音      → 走到那一帶，再在附近繞著找（放鬆的時候只理近的）
##  10. 導演給了方向  → 走過去、在附近繞著找
##  11. 都沒有        → 隨便逛
##
## 感官：視力差——近（SIGHT）、只看前方、要沒被擋住；蹲著要更近才看得到，蹲在灌木裡看不到。
## 看到不等於確定：要盯著一下（越遠越久）才確定是人，這段時間躲回去，牠只會去你剛才在的地方找。
## 聽力好——整張地圖的槍聲都聽得到，附近有人跑步也聽得到（走路和蹲著走聽不到）。
## 但聲音只聽得出大概在哪：越遠偏越多（NOISE_FUZZ）。
##
## 心情 mood（逛／找／追）同步給大家，各台照它擺頭的高低、出聲（trex.gd、_process）：玩家看得出牠現在在幹嘛。
## 導演（director.gd）知道大家在哪，但只給恐龍大概方向，不給準確位置。
##
## 兩招都有預備動作和聲音，看得懂、聽得到才公平；收招有破綻（DOOM 的做法，知識庫敵人設計筆記）。
## 一次只出一招。動作狀態 act 同步給大家，各台自己播骨架動作和叫聲（trex.gd、_process）。
##
## 移動：照導航網格的路徑走（main.gd 的 bake_nav，開場在主機上烘），繞得過建築；烘好之前退回直線追。
## 走跟牛仔一樣、跑比牛仔快。跑步吃體力，見底只能走、回到 RECOVER_AT 才能再跑——牛仔拉開距離的機會就在這。

# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var WALK: float = Balance.num("dino_walk")   # 牛仔走 4.0
static var RUN: float = Balance.num("dino_run")   # 牛仔衝刺 6.8
static var RUN_DRAIN: float = Balance.num("dino_run_drain")   # 每秒；滿體力約跑 10 秒
static var REGEN: float = Balance.num("dino_regen")   # 沒在跑的時候每秒回
static var RECOVER_AT: float = Balance.num("dino_recover_at")   # 跑到見底之後，回到這麼多才能再跑
const SIGHT := 18.0          # 看得到多遠
const SIGHT_CROUCH := 9.0    # 蹲著的人要更近才看得到
const SIGHT_CONE := 0.5      # cos 60°：正前方左右各 60 度
const FEEL := 5.0            # 這麼近不管方向都會發現
const HEAR_GUN := 150.0      # 槍聲：場地 168 公尺，幾乎整張圖都聽得到
const HEAR_RUN := 20.0       # 有人在附近跑步
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var RUN_SPEED_HEARD: float = Balance.num("dino_run_heard")   # 水平速度超過這個算在跑（牛仔走 4、衝刺 6.8）
const MEMORY := 10.0         # 看丟之後，往最後看到的位置追這麼久
const NOISE_FORGET := 12.0   # 聽到的聲音記多久
const NOISE_FUZZ := 0.12     # 聲音的位置偏差：距離的這麼多倍……
const NOISE_FUZZ_MAX := 15.0 # ……最多偏這麼遠
const NOISE_SEARCH := 5.0    # 走到聲音那一帶之後，在附近繞著找這麼久
const SPOT_NEAR := 0.25      # 瞄到人到確定要多久：FEEL 那麼近要這麼久……
const SPOT_FAR := 1.0        # ……SIGHT 那麼遠要這麼久
const SPOT_FORGET := 0.5     # 沒瞄到時，確定的進度每秒退這麼多
const SPOT_LEAD := 0.3       # 進度超過這麼多才看丟，才去你剛才在的地方找
const LOOK_PAUSE := 1.2      # 繞著找的時候，每走到一點停下來張望這麼久
const SNIFF_EVERY := Vector2(2.5, 4.5)   # 找人時多久嗅一次（秒）
const SEARCH_TIME := 8.0     # 走到導演給的點之後，在附近繞著找這麼久
const SEARCH_RADIUS := 10.0
const KNOCK_TIME := 6.0
const PARTY_KNOCK_TIME := 15.0   # 派對模式倒地比較久：牛仔打倒恐龍就有這段時間偷蛋、撤離
const GET_UP_GUARD := 3.0        # 派對模式：起身後這麼久打不動（身體閃爍）
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var TURN: float = Balance.num("dino_turn")   # 轉身速度（弧度／秒）：大隻轉得慢，繞著牠跑有用
const ARRIVE := 2.5
const RETREAT_DIST := 50.0   # 退開時往離最近的人這麼遠的地方跑

# --- 兩招（時間都是秒、距離是公尺）---
enum { ACT_NONE, ACT_BITE_WIND, ACT_BITE, ACT_CHARGE_WIND, ACT_SWEEP, ACT_POUNCE_WIND, ACT_POUNCE, ACT_RECOVER, ACT_STUN, ACT_SPOT }  # ACT_POUNCE_WIND／ACT_POUNCE 已不用（撲擊拿掉，規則草案 10-28），留著是因為 trex.gd 用編號對動作
enum { MOOD_ROAM, MOOD_SEARCH, MOOD_HUNT, MOOD_RETREAT }
const SPOT_TIME := 0.7       # 發現人：停下來吼一聲這麼久，玩家還有這段時間跑
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var ATTACK_GAP: float = Balance.num("attack_gap")   # 收招之後至少隔這麼久才出下一招
static var PILOT_ATTACK_GAP: float = Balance.num("pilot_attack_gap")   # 玩家操作：收招後很快能出下一招（電腦版留空檔給牛仔喘氣）
# 咬：近距離正前方。站定、頭往後仰、低吼，再咬下去
const BITE_TRIGGER := 7.5    # 嘴巴到人這麼近開始預備
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var BITE_WIND: float = Balance.num("bite_wind")
static var PILOT_BITE_WIND: float = Balance.num("pilot_bite_wind")   # 玩家操作：出招要跟手，預備比電腦短一半
static var BITE_RECOVER: float = Balance.num("bite_recover")
static var PILOT_BITE_RECOVER: float = Balance.num("pilot_bite_recover")   # 玩家操作：咬完很快收回來
const BITE_AT := 6.0         # 判定點在身體中心前方這麼遠（嘴巴的位置）
const BODY_RADIUS := 2.4     # 身體碰撞膠囊的半徑（boss.tscn）
# 輕攻擊（左鍵咬）：胸前扇形，從身體中心算。以下從 balance.csv 讀
static var LIGHT_DAMAGE: int = Balance.whole("light_damage")
static var LIGHT_REACH: float = Balance.num("light_reach")
static var LIGHT_COS: float = cos(deg_to_rad(Balance.num("light_angle") * 0.5))   # 扇形半角的餘弦，判定用
# 踩踏：移動中貼著牛仔走過去就踩，站著不動不踩。以下從 balance.csv 讀
static var STOMP_DAMAGE: int = Balance.whole("stomp_damage")
static var STOMP_REACH: float = Balance.num("stomp_reach")
static var STOMP_INTERVAL: float = Balance.num("stomp_interval")
static var STOMP_MIN_SPEED: float = Balance.num("stomp_min_speed")
const STOMP_HEIGHT := 1.5    # 牛仔腳底在恐龍腳底上下這麼多以內才踩得到
# 蓄力甩尾：身邊有人在側面或背後、或身邊不只一個人。站著仰頭長吼，這段時間打中頭就打斷
const SWEEP_TRIGGER := 9.0
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var CHARGE_WIND: float = Balance.num("charge_wind")
static var PILOT_CHARGE_WIND: float = Balance.num("pilot_charge_wind")   # 玩家操作：搖動太久不好玩。打中頭打斷的機會也跟著變短
static var SWEEP_RADIUS: float = Balance.num("sweep_radius")
static var SWEEP_DAMAGE: int = Balance.whole("sweep_damage")
static var SWEEP_RECOVER: float = Balance.num("sweep_recover")
static var SWEEP_CD: float = Balance.num("sweep_cd")
static var SWEEP_CD_PARTY: float = Balance.num("sweep_cd_party")   # 派對模式：甩尾拆得掉地形（destructible.gd），冷卻拉長，不然掩體一下就拆光
static var STUN_TIME: float = Balance.num("stun_time")   # 蓄力被打斷暈多久
const STRIKE_SHOW := 0.15    # 出手那一下的動作狀態留這麼久（同步每秒 40 次，太短會漏）

const SOUNDS := {
	ACT_BITE_WIND: preload("res://assets/audio/dino/growl.wav"),
	ACT_CHARGE_WIND: preload("res://assets/audio/dino/roar.wav"),
	ACT_STUN: preload("res://assets/audio/dino/yelp.wav"),
	ACT_SPOT: preload("res://assets/audio/dino/bellow.wav"),
}
const YELP := preload("res://assets/audio/dino/yelp.wav")
const SNIFF := preload("res://assets/audio/dino/sniff.wav")

## 這幾個同步出去（boss.tscn 的同步器），大家的 HUD、畫面和聲音都看得到
@export var down_left := 0.0
@export var running := false
@export var act := ACT_NONE
@export var mood := MOOD_ROAM
@export var guard_left := 0.0   # 派對模式起身後的無敵還剩幾秒
@export var sweep_left := 0.0   # 甩尾冷卻還剩幾秒：同步出去，玩家操作恐龍時畫面上看得到
## 派對模式用（docs/企劃/派對玩法.md）：倒地中、起身後無敵中。各台都看得到（照同步的值算）
var downed: bool:
	get: return down_left > 0.0
var invulnerable: bool:
	get: return guard_left > 0.0
signal knocked_down   # 各台：倒地那一刻
signal got_up         # 各台：起身那一刻
## 對抗模式：玩家操作尼諾拉（docs/規劃/2026-10-18-對抗模式.md）。0 = 電腦。有駕駛時行為樹不跑，照駕駛送來的輸入動，
## 出招、預備動作、叫聲、體力、倒地、同步都跟電腦版一樣。駕駛斷線 main.gd 會清回 0，電腦接手
@export var pilot := 0
enum { PIN_BITE = 1, PIN_SWEEP = 4, PIN_RUN = 8 }
const PILOT_STALE := 0.5     # 主機這麼久沒收到駕駛的輸入就當放開（網路斷斷續續時不要一直往前衝）
var _pin_move := Vector2.ZERO   # 主機：駕駛最新的輸入（相對鏡頭，x 右、y 後）
var _pin_yaw := 0.0
var _pin_buttons := 0
var _pin_age := 0.0
var _cam_yaw := 0.0             # 駕駛那台：鏡頭的水平角（身體慢慢轉過來）
var _cam_pitch := 0.0
var _piloting := false          # 駕駛那台：現在是不是由我操作（變成駕駛、不再是駕駛的那一刻才換鏡頭）
var _quake := 0.0               # 駕駛那台：甩尾打到可拆的東西，鏡頭抖的幅度（弧度），每幀衰減（add_shake）

var director := Director.new()
var _tree: BT.Task
var _target: Node3D = null
var _last_seen := Vector3.INF
var _seen_left := 0.0
var _noise := Vector3.INF
var _noise_left := 0.0
var _hint := Vector3.INF
var _search_left := 0.0
var _hint_reached := false
var _wander_to := Vector3.INF
var _retreat_to := Vector3.INF
var _last_pos := {}           # 牛仔 → 上一幀的位置（算誰在跑）
var _act_left := 0.0          # 這個動作狀態還剩多久
var _attack_gap := 0.0
var _hit_once := []           # 這一招已經打過的人（一招內不重複扣）
var _sees_now: Node3D = null
var _path := PackedVector3Array()
var _path_goal := Vector3.INF
var _path_age := 0.0
var _rng := RandomNumberGenerator.new()
var _stuck_at := Vector3.INF  # 卡住偵測：一秒前的位置
var _stuck_t := 0.0
var _unstick_left := 0.0      # 脫困中：往後退、往旁邊繞
var _unstick_dir := Vector3.ZERO
var _shown_act := ACT_NONE    # 各台：上一次播過動作和叫聲的狀態
var _was_down := false        # 各台：上一幀是不是倒地（倒地那一下揚土）
var _sniff_in := 0.0          # 各台：再過多久嗅一次
var _glimpse: Node3D = null   # 瞄到、但還沒確定的人
var _glimpse_at := Vector3.INF
var _suspect := 0.0           # 確定的進度 0~1
var _spot_pending := false    # 剛確定看到人，這一幀要吼
var _look_left := 0.0         # 繞著找時停下來張望還剩多久
var _stomp_clock := 0.0        # 踩踏的計時（只在主機用）
var _stomp_at := {}           # 牛仔 → 上一次被踩的時刻；ponytail: 牛仔離線留下的項目不清，一局幾個人不會長大


func _ready() -> void:
	super()
	var voice := AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.unit_size = 12.0       # 大隻，遠遠就聽得到
	voice.max_distance = 120.0
	voice.volume_db = 4.0
	voice.position = Vector3(0, 2.0, -4.0)   # 頭的位置
	add_child(voice)
	_tree = BT.Sel.new([
		BT.Seq.new([BT.Cond.new(func() -> bool: return down_left > 0.0), BT.Act.new(_act_down)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return act != ACT_NONE), BT.Act.new(_act_attack)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return director.phase == Director.Phase.RETREAT), BT.Act.new(_act_retreat)]),
		BT.Seq.new([BT.Cond.new(_start_spot), BT.Act.new(_act_attack)]),
		BT.Seq.new([BT.Cond.new(_start_attack), BT.Act.new(_act_attack)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _sees_now != null), BT.Act.new(_act_chase)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _glimpse != null), BT.Act.new(_act_glimpse)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _seen_left > 0.0), BT.Act.new(_act_last_seen)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _noise_left > 0.0), BT.Act.new(_act_investigate)]),
		BT.Seq.new([BT.Cond.new(func() -> bool: return _hint != Vector3.INF), BT.Act.new(_act_hint)]),
		BT.Act.new(_act_wander),
	])


## 每台都跑：倒地往側邊躺；動作狀態一變，骨架換動作、出叫聲
func _process(delta: float) -> void:
	super(delta)
	# 駕駛那台：第三人稱鏡頭照自己的視角，不等身體轉過來。只在變成／不再是駕駛那一刻換鏡頭：
	# 新一局客戶端的牛仔常比 pilot=0 先同步到，每幀搶的話鏡頭會卡在恐龍身上
	var mine := _is_my_pilot()
	var cam: Camera3D = $CamPivot/Camera3D
	if mine != _piloting:
		_piloting = mine
		cam.current = mine
		_cam_yaw = rotation.y
	if mine:
		$CamPivot.rotation = Vector3(CAM_BASE + _cam_pitch + randf_range(-1.0, 1.0) * _stagger * 0.08 * Settings.v.get(&"shake", 1.0), _cam_yaw - rotation.y, 0.0)
		_quake = lerpf(_quake, 0.0, 1.0 - exp(-10.0 * delta))
		$CamPivot.rotation += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _quake
	$Trex.rotation.z = lerpf($Trex.rotation.z, 1.35 if down_left > 0.0 else 0.0, minf(delta * 4.0, 1.0))
	if down_left > 0.0 and not _was_down:   # 倒地：整隻摔下去揚起一大圈土
		var w: Node = get_tree().get_first_node_in_group(&"arena")
		if w:
			Fx.dust_ring(w, global_position + Vector3.DOWN * 3.5, 4.0, 40, 9.0, 1.2)
	if downed != _was_down:
		(knocked_down if downed else got_up).emit()
	_was_down = downed
	$Trex.visible = guard_left <= 0.0 or fmod(guard_left, 0.2) < 0.12   # 無敵中閃爍
	$Trex.act = act
	if act != _shown_act:
		_shown_act = act
		if SOUNDS.has(act):
			var voice: AudioStreamPlayer3D = $Voice
			voice.stream = SOUNDS[act]
			voice.play()
		if act == ACT_BITE:
			$Trex.bite()
	$Trex.mood = mood
	# 找人的時候不時嗅一下（嘴巴沒在叫的時候才嗅，不蓋掉出招的預告）
	_sniff_in -= delta
	if mood == MOOD_SEARCH and act == ACT_NONE and _sniff_in <= 0.0:
		_sniff_in = randf_range(SNIFF_EVERY.x, SNIFF_EVERY.y)
		_say(SNIFF)

## 出聲，但不蓋掉正在叫的（出招的預告比較重要）
func _say(s: AudioStream) -> void:
	var voice: AudioStreamPlayer3D = $Voice
	if voice.playing:
		return
	voice.stream = s
	voice.play()


func _physics_process(delta: float) -> void:
	if _is_my_pilot():
		_pilot_local()
	if not is_multiplayer_authority():
		return
	think(delta)


## 一幀的決策＋移動。測試直接呼叫這個
func think(delta: float) -> void:
	_seen_left = maxf(_seen_left - delta, 0.0)
	_noise_left = maxf(_noise_left - delta, 0.0)
	_attack_gap = maxf(_attack_gap - delta, 0.0)
	sweep_left = maxf(sweep_left - delta, 0.0)
	guard_left = maxf(guard_left - delta, 0.0)
	_stomp(delta)
	if pilot != 0:
		_pilot_step(delta)
		return
	_listen_steps(delta)
	_look(delta)
	var hint := director.step(delta, _sees_now, _seen_left > 0.0 or _noise_left > 0.0 or _glimpse != null, _cowboys(), _rng)
	if hint != Vector3.INF:
		_hint = hint
		_search_left = SEARCH_TIME
		_hint_reached = false
	_tree.tick(delta)
	mood = _mood()

## 踩踏（主機每幀，電腦和駕駛都一樣）：水平速度夠快時，貼著走過去的牛仔扣血。倒地、出招中照樣算（只看速度）
func _stomp(delta: float) -> void:
	_stomp_clock += delta
	if Vector2(velocity.x, velocity.z).length() <= STOMP_MIN_SPEED:
		return
	for p: Node3D in _cowboys():
		var to := p.global_position - global_position
		to.y = 0.0
		if to.length() >= BODY_RADIUS + STOMP_REACH or absf(p.global_position.y - (global_position.y - 4.0)) >= STOMP_HEIGHT:
			continue
		if _stomp_clock - _stomp_at.get(p, -INF) < STOMP_INTERVAL:
			continue
		_stomp_at[p] = _stomp_clock
		p.take_damage(STOMP_DAMAGE, self)

# --- 對抗模式：玩家駕駛 ---

## 主機收駕駛的輸入（只收駕駛本人送的；主機自己當駕駛時直接呼叫）
@rpc("any_peer", "call_remote", "unreliable_ordered")
func pilot_input(move: Vector2, yaw: float, pitch: float, buttons: int) -> void:
	var from := multiplayer.get_remote_sender_id()
	if from == 0:
		from = multiplayer.get_unique_id()
	if not multiplayer.is_server() or from != pilot or not (is_finite(yaw) and is_finite(pitch) and move.is_finite()):
		return
	_pin_move = move.limit_length(1.0)
	_pin_yaw = yaw
	_pin_buttons = buttons
	_pin_age = 0.0
	look_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)

## 駕駛這一幀：倒地、出招中照電腦版跑完；平常照輸入走、慢慢轉向鏡頭的方向、按鍵出招
func _pilot_step(delta: float) -> void:
	_pin_age += delta
	if _pin_age > PILOT_STALE:
		_pin_move = Vector2.ZERO
		_pin_buttons = 0
	mood = MOOD_HUNT if act != ACT_NONE or running else MOOD_ROAM
	if down_left > 0.0:
		_act_down(delta)
		return
	if act != ACT_NONE:
		if act in [ACT_BITE_WIND, ACT_SPOT]:   # 預備時還能對準（跟電腦版一樣：咬、發現人都半速）
			rotation.y = rotate_toward(rotation.y, _pin_yaw, TURN * 0.5 * delta)
		_act_attack(delta)
		return
	if _attack_gap <= 0.0:
		_target = null   # 沒有目標：咬照面對的方向
		if _pin_buttons & PIN_BITE:
			_begin(ACT_BITE_WIND, PILOT_BITE_WIND)
			return
		if _pin_buttons & PIN_SWEEP and sweep_left <= 0.0:
			sweep_left = _sweep_cd_time()
			_begin(ACT_CHARGE_WIND, PILOT_CHARGE_WIND)
			return
	rotation.y = rotate_toward(rotation.y, _pin_yaw, TURN * delta)   # 轉身限速：繞著牠跑有用
	var dir := Basis(Vector3.UP, _pin_yaw) * Vector3(_pin_move.x, 0.0, _pin_move.y)
	_move(dir, _pin_buttons & PIN_RUN != 0, delta)

## 駕駛那台：滑鼠轉鏡頭（身體由主機慢慢轉過來）
func _unhandled_input(e: InputEvent) -> void:
	if not _is_my_pilot() or not (e is InputEventMouseMotion) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or after_hitch():
		return
	var rel := Settings.look((e as InputEventMouseMotion).screen_relative)
	_cam_yaw -= rel.x * MOUSE_SENS * 0.5   # 玩家恐龍原本的靈敏度是給會瞬間轉身的身體用的；這隻轉得慢，鏡頭也放慢一點
	_cam_pitch = clampf(_cam_pitch - rel.y * MOUSE_SENS * 0.5, PITCH_MIN, PITCH_MAX)

## 甩尾打到可拆的東西（destructible.gd 呼叫）：鏡頭抖一下。只有操控的那台抖得到（鏡頭只在那台）
func add_shake(amount: float) -> void:
	_quake = minf(_quake + amount, 0.2)

## 打擊停頓：只有操控牠的那台停，骨架凍住（trex.gd 的 hitstop）；別人看到的照常動
func add_hitstop(sec: float) -> void:
	if _is_my_pilot():
		$Trex.hitstop = maxf($Trex.hitstop, sec)

func _is_my_pilot() -> bool:
	return pilot != 0 and multiplayer.multiplayer_peer != null and pilot == multiplayer.get_unique_id()

## 駕駛那台每個物理幀：把按鍵送給主機（鏡頭在 _process）
func _pilot_local() -> void:
	var free := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED   # 開選單、結算畫面時不送按鍵
	var mv := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if free else Vector2.ZERO
	var b := 0
	if free:
		b |= PIN_BITE if Input.is_action_pressed(&"fire") else 0
		b |= PIN_SWEEP if Input.is_action_pressed(&"aim") else 0
		b |= PIN_RUN if Input.is_action_pressed(&"sprint") else 0
	if multiplayer.is_server():
		pilot_input(mv, _cam_yaw, _cam_pitch, b)
	else:
		pilot_input.rpc_id(1, mv, _cam_yaw, _cam_pitch, b)

## 看：瞄到人要盯一下才確定（越遠越久）。已經在追的人（剛看丟沒多久）一瞄到就確定。
## 確定之前人躲回去了，就去他剛才在的地方找（當成聽到聲音）
func _look(delta: float) -> void:
	var seen := _nearest_seen()
	_sees_now = null
	if seen:
		var d := _flat_dist(seen.global_position)
		if _seen_left > 0.0 or d < FEEL:
			_suspect = 1.0
		else:
			var need := lerpf(SPOT_NEAR, SPOT_FAR, clampf((d - FEEL) / (SIGHT - FEEL), 0.0, 1.0))
			_suspect = minf(_suspect + delta / need, 1.0)
		_glimpse_at = seen.global_position
	elif _glimpse != null and _suspect >= SPOT_LEAD and _suspect < 1.0 and director.phase != Director.Phase.RETREAT:
		_noise = _glimpse_at
		_noise_left = NOISE_FORGET
		_suspect = 0.0
	else:
		_suspect = maxf(_suspect - SPOT_FORGET * delta, 0.0)
	_glimpse = seen if seen and _suspect < 1.0 else null
	if seen and _suspect >= 1.0:
		# 剛確定（不是本來就在追）：這一幀吼一聲。太近（直接動手）、在出招、倒地、退開就不吼
		if _seen_left <= 0.0 and _flat_dist(seen.global_position) >= FEEL and act == ACT_NONE and down_left <= 0.0 \
				and director.phase != Director.Phase.RETREAT:
			_spot_pending = true
		_sees_now = seen
		_target = seen
		_last_seen = seen.global_position
		_seen_left = MEMORY
		_hint = Vector3.INF

func _mood() -> int:
	if director.phase == Director.Phase.RETREAT and act == ACT_NONE and down_left <= 0.0:
		return MOOD_RETREAT   # 跑起來要看得出是走掉不是衝過來（trex.gd 頭抬高、尾巴垂）
	if act != ACT_NONE or _sees_now or _seen_left > 0.0:
		return MOOD_HUNT
	if _glimpse or _noise_left > 0.0 or (_hint != Vector3.INF and _hint_reached):
		return MOOD_SEARCH
	return MOOD_ROAM


# --- 感官 ---

## 聽到槍聲（viewmodel 開槍時在主機上呼叫，見 Viewmodel._alert_boss）
func hear(at: Vector3) -> void:
	var reach := Director.RELAX_HEAR if director.phase == Director.Phase.RELAX else HEAR_GUN
	if director.phase != Director.Phase.RETREAT and global_position.distance_to(at) <= reach:
		_heard(at)

## 聽到 at 那裡有聲音：只記得大概位置，越遠偏越多。偏到房子裡就拉回導航網格上（不然走不到）
func _heard(at: Vector3) -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf() * minf(_flat_dist(at) * NOISE_FUZZ, NOISE_FUZZ_MAX)
	_noise = at + Vector3(cos(a), 0, sin(a)) * r
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		_noise = NavigationServer3D.map_get_closest_point(map, _noise)
	_noise_left = NOISE_FORGET

## 附近有人跑步：主機只拿得到同步來的位置，用位置差算速度
func _listen_steps(delta: float) -> void:
	for p in _cowboys():
		var now: Vector3 = p.global_position
		var before: Vector3 = _last_pos.get(p, now)
		_last_pos[p] = now
		var speed := Vector2(now.x - before.x, now.z - before.z).length() / maxf(delta, 1e-4)
		if speed > RUN_SPEED_HEARD and global_position.distance_to(now) < HEAR_RUN \
				and director.phase != Director.Phase.RETREAT:
			_heard(now)

func can_see(p: Node3D) -> bool:
	var to := p.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if flat < FEEL:
		return true
	var g := _game()
	if g and g.hidden_in_bush(p):
		return false
	if flat > (SIGHT_CROUCH if p.get(&"sync_crouching") == true else SIGHT):
		return false
	var fwd := -global_basis.z
	if Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to.x, to.z) / flat) < SIGHT_CONE:
		return false
	return not _blocked_by_wall(p)

func _nearest_seen() -> Node3D:
	var best: Node3D = null
	for p: Node3D in _cowboys():
		if can_see(p) and (best == null or _flat_dist(p.global_position) < _flat_dist(best.global_position)):
			best = p
	return best

func _cowboys() -> Array:
	var out := get_parent().get_children().filter(
		func(p: Node) -> bool: return p != self and not p.is_in_group(&"dino") and p.get(&"hp") > 0)
	# 恐龍走路不被牛仔擋住（只對恐龍這邊：牛仔還是走不進恐龍身體裡）。
	# 不然站著不動的人可以把恐龍卡死在原地（長時間模擬真的發生過）
	for p: PhysicsBody3D in out:
		add_collision_exception_with(p)
	return out

func _game() -> Node:
	return get_tree().get_first_node_in_group(&"match")

func _party() -> bool:
	var g := _game()
	return g != null and g.rules == &"party" and not g._sandbox   # 大廳選了派對再按沙盒：照沙盒

func _flat_dist(at: Vector3) -> float:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length()

## 那個點在不在正前方（cos 夾角大於 min_dot）
func _in_front(at: Vector3, min_dot: float) -> bool:
	var to := at - global_position
	to.y = 0.0
	var fwd := -global_basis.z
	fwd.y = 0.0
	return to.length() < 0.01 or fwd.normalized().dot(to.normalized()) > min_dot

## 嘴巴的位置：身體中心前方 BITE_AT 公尺
func mouth() -> Vector3:
	var fwd := -global_basis.z
	fwd.y = 0.0
	return global_position + fwd.normalized() * BITE_AT


# --- 出招 ---

## 看能不能出招，可以就開始預備（回傳 true，下一個節點 _act_attack 接著做）
func _start_attack() -> bool:
	if _attack_gap > 0.0 or director.phase == Director.Phase.RETREAT:
		return false
	var near := _cowboys().filter(func(p: Node3D) -> bool:
		return _flat_dist(p.global_position) < SWEEP_TRIGGER and not _blocked_by_wall(p))
	# 咬：嘴巴前面有人
	for p: Node3D in near:
		if _in_front(p.global_position, 0.5) and _flat_dist(p.global_position) < BITE_TRIGGER + 1.5 \
				and p.global_position.distance_to(mouth()) < BITE_TRIGGER:
			_target = p
			_begin(ACT_BITE_WIND, BITE_WIND)
			return true
	# 蓄力甩尾：身邊有人在側面或背後，或身邊不只一個人
	if sweep_left <= 0.0 and (near.size() >= 2 or near.any(func(p: Node3D) -> bool: return not _in_front(p.global_position, 0.5))):
		sweep_left = _sweep_cd_time()
		_begin(ACT_CHARGE_WIND, CHARGE_WIND)
		return true
	return false

func _begin(a: int, t: float) -> void:
	act = a
	_act_left = t
	_hit_once.clear()
	_spot_pending = false
	if a in [ACT_BITE_WIND, ACT_CHARGE_WIND]:
		director.attacked()

## 剛確定看到人：停下來吼一聲（_act_attack 的 ACT_SPOT）
func _start_spot() -> bool:
	if not _spot_pending:
		return false
	_begin(ACT_SPOT, SPOT_TIME)
	return true

## 一招的進行：預備 → 出手 → 收招。每個階段時間到就換下一個
func _act_attack(delta: float) -> int:
	_act_left -= delta
	match act:
		ACT_BITE_WIND:
			_turn_to(_target, TURN * 0.5, delta)   # 預備時慢慢對準，側移還是躲得掉
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				_next(ACT_BITE, STRIKE_SHOW)
		ACT_BITE:
			_hit_cone()   # 整段出手時間每幀判，_hit_once 保證每人每招只中一次
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				_next(ACT_RECOVER, PILOT_BITE_RECOVER if pilot != 0 else BITE_RECOVER)
		ACT_CHARGE_WIND:
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				_strike_sweep()
				_next(ACT_SWEEP, STRIKE_SHOW * 2.0)
		ACT_SWEEP:
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				_next(ACT_RECOVER, SWEEP_RECOVER)
		ACT_SPOT:
			_turn_to(_target, TURN, delta)
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				act = ACT_NONE
				return BT.SUCCESS
		ACT_RECOVER, ACT_STUN:
			_move(Vector3.ZERO, false, delta)
			if _act_left <= 0.0:
				act = ACT_NONE
				_attack_gap = PILOT_ATTACK_GAP if pilot != 0 else ATTACK_GAP
				return BT.SUCCESS
	return BT.RUNNING

func _next(a: int, t: float) -> void:
	act = a
	_act_left = t

## 輕攻擊的判定：胸前扇形，中心算到身體半徑＋light_reach 為止，夾角在 light_angle 以內。
## 高度、擋牆跟 _hit_around 一樣
func _hit_cone() -> void:
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for p: Node3D in _cowboys():
		if p in _hit_once:
			continue
		var to := p.global_position - global_position
		to.y = 0.0
		if to.length() >= BODY_RADIUS + LIGHT_REACH or fwd.dot(to.normalized()) < LIGHT_COS:
			continue
		if absf(p.global_position.y - (global_position.y - 4.0)) < 4.0 and not _blocked_by_wall(p):
			_hit_once.append(p)
			p.take_damage(LIGHT_DAMAGE, self)

func _strike_sweep() -> void:
	_hit_around(global_position, SWEEP_RADIUS, SWEEP_DAMAGE)   # 掃起的一圈土是各台自己播（trex.gd 的 _act_fx）
	if _party():
		_wreck_around(global_position, SWEEP_RADIUS)

func _sweep_cd_time() -> float:
	return SWEEP_CD_PARTY if _party() else SWEEP_CD

## 派對模式：甩尾掃到的地形（群組 destructible：樹、灰盒房子；安全屋不在裡面）各挨一下，倒不倒它自己算
func _wreck_around(at: Vector3, radius: float) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), at)
	q.exclude = [get_rid()]
	var done := {}
	# ponytail: 一棟房子幾十塊碰撞各算一筆，上限給大一點；房子擠成一團漏掉幾個再加
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 256):
		var c: Object = r.collider
		if c is Node and (c as Node).is_in_group(&"destructible") and not done.has(c):
			done[c] = true
			c.tail_hit(at)

## 判定點附近的牛仔扣血（一招每人最多一次、中間隔著東西打不到）
func _hit_around(at: Vector3, radius: float, damage: int) -> void:
	for p: Node3D in _cowboys():
		if p in _hit_once:
			continue
		var d := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d < radius and absf(p.global_position.y - (global_position.y - 4.0)) < 4.0 and not _blocked_by_wall(p):
			_hit_once.append(p)
			p.take_damage(damage, self)

## 打中頭（Main.request_damage 帶 head 旗標進來）：蓄力中被打中頭就打斷、暈 STUN_TIME 秒
func head_hit() -> void:
	if act == ACT_CHARGE_WIND:
		_next(ACT_STUN, STUN_TIME)
	_head_flinch.rpc()

## 頭被打中：各台甩一下頭、短短哀一聲（主機在 take_damage 之前送，同一條可靠通道，順序不會亂）
@rpc("authority", "call_local", "reliable")
func _head_flinch() -> void:
	$Trex.flinch(Vector3.ZERO, 0.0, true)
	_say(YELP)

## 中彈（fighter._sync_hp，每台都跑）：身體往子彈推的方向晃一下再穩住。只是表演
func _on_hurt(amount: int, from: Vector3) -> void:
	var push := Vector3.ZERO
	if from != Vector3.INF:
		push = global_basis.inverse() * (global_position - from)
		push.y = 0.0
		push = push.normalized()
	$Trex.flinch(push, clampf(amount / 40.0, 0.3, 1.0), false)

## 頭的位置（牛仔的子彈判斷有沒有打中頭用，見 Bullet._impact）
func head_position() -> Vector3:
	var t: Trex = $Trex
	if t.skel == null:
		return mouth()
	return t.skel.to_global(t.skel.get_bone_global_pose(t.skel.find_bone("head")).origin)


# --- 行為樹的其他動作 ---

func _act_down(delta: float) -> int:
	down_left = maxf(down_left - delta, 0.0)
	if down_left <= 0.0 and _party():
		guard_left = GET_UP_GUARD
	_move(Vector3.ZERO, false, delta)
	return BT.RUNNING

## 瞄到人但還不確定：停下來盯著、慢慢轉過去
func _act_glimpse(delta: float) -> int:
	if not is_instance_valid(_glimpse):
		return BT.FAILURE
	_turn_to(_glimpse, TURN * 0.6, delta)
	_move(Vector3.ZERO, false, delta)
	return BT.RUNNING

func _act_chase(delta: float) -> int:
	if not is_instance_valid(_target):
		return BT.FAILURE
	_nav_go(_target.global_position, true, delta)
	return BT.RUNNING

func _act_last_seen(delta: float) -> int:
	if _nav_go(_last_seen, true, delta):
		_seen_left = 0.0
	return BT.RUNNING

## 走到聲音那一帶，再在附近繞著找一陣子（跟導演的方向同一套：_act_hint）
func _act_investigate(delta: float) -> int:
	if _nav_go(_noise, true, delta):
		_noise_left = 0.0
		_hint = _noise
		_hint_reached = true
		_search_left = NOISE_SEARCH
		_wander_to = Vector3.INF
	return BT.RUNNING

## 走到導演給的點，再在附近繞著找一陣子（隨便挑點、會折返）
func _act_hint(delta: float) -> int:
	if not _hint_reached:
		_hint_reached = _nav_go(_hint, false, delta)
		return BT.RUNNING
	_search_left -= delta
	if _search_left <= 0.0:
		_hint = Vector3.INF
		_look_left = 0.0
		return BT.SUCCESS
	if _look_left > 0.0:   # 停下來張望（頭左右掃是 trex.gd 照 mood 做的）
		_look_left -= delta
		_move(Vector3.ZERO, false, delta)
		return BT.RUNNING
	if _wander_to != Vector3.INF and _flat_dist(_wander_to) < ARRIVE:
		_look_left = LOOK_PAUSE
		_wander_to = Vector3.INF
		return BT.RUNNING
	if _wander_to == Vector3.INF or _hint.distance_to(_wander_to) > SEARCH_RADIUS:
		var a := _rng.randf() * TAU
		_wander_to = _hint + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, SEARCH_RADIUS)
	_nav_go(_wander_to, false, delta)
	return BT.RUNNING

## 隨便逛：在自己附近挑一點走過去
func _act_wander(delta: float) -> int:
	if _wander_to == Vector3.INF or _nav_go(_wander_to, false, delta):
		var a := _rng.randf() * TAU
		_wander_to = _clamp_arena(global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(10.0, 25.0))
	return BT.RUNNING

## 退開：往離最近的人遠的那一邊跑
func _act_retreat(delta: float) -> int:
	if _retreat_to == Vector3.INF or _flat_dist(_retreat_to) < ARRIVE * 2.0:
		var away := Vector3.ZERO
		for p: Node3D in _cowboys():
			var d := global_position - p.global_position
			d.y = 0.0
			away += d.normalized() / maxf(d.length(), 1.0)
		if away == Vector3.ZERO:
			away = -global_basis.z
		_retreat_to = _clamp_arena(global_position + away.normalized() * RETREAT_DIST)
	_nav_go(_retreat_to, true, delta)
	if director.phase != Director.Phase.RETREAT:
		_retreat_to = Vector3.INF
	return BT.RUNNING

func _clamp_arena(at: Vector3) -> Vector3:
	var g := _game()
	var half: float = g.ARENA * 0.5 - 10.0 if g else 70.0
	return Vector3(clampf(at.x, -half, half), at.y, clampf(at.z, -half, half))


# --- 移動 ---

## 照導航網格的路徑走到 to（每隔一下、或目標動了就重算路徑）。網格還沒烘好就直線走。到了回傳 true
func _nav_go(to: Vector3, want_run: bool, delta: float) -> bool:
	if _flat_dist(to) < ARRIVE:
		_move(Vector3.ZERO, false, delta)
		return true
	_path_age += delta
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0 and (_path_age > 1.0 or _path_goal.distance_to(to) > 3.0 or _path.is_empty()):
		_path = NavigationServer3D.map_get_path(map, global_position, to, true)
		_path_goal = to
		_path_age = 0.0
	while _path.size() > 1 and _flat_dist(_path[0]) < 2.0:
		_path.remove_at(0)
	_go(_path[0] if _path.size() > 1 else to, want_run, delta)
	return false

## 轉向 to 走過去（轉得慢，偏太多就先放慢腳步轉身）。
## 卡住一秒沒前進（撞到網格沒算到的東西、或站在網格外面）就脫困：往後斜退 UNSTICK_TIME 秒再重算路徑
const UNSTICK_TIME := 0.8
func _go(to: Vector3, want_run: bool, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		_move(_unstick_dir, false, delta)
		return
	_stuck_t += delta
	if _stuck_t >= 1.0:
		if _stuck_at != Vector3.INF and _flat_dist(_stuck_at) < 0.5:
			_unstick_left = UNSTICK_TIME
			_unstick_dir = (global_basis.z + global_basis.x * (1.0 if _rng.randf() < 0.5 else -1.0)).normalized()
			_path.clear()
		_stuck_at = global_position
		_stuck_t = 0.0
	var d := to - global_position
	d.y = 0.0
	var want := atan2(-d.x, -d.z)
	if is_on_wall():
		want += 0.9   # 還是卡住（沒網格、或被別的東西擋）就偏一點滑開
	rotation.y = rotate_toward(rotation.y, want, TURN * delta)
	var off := absf(wrapf(want - rotation.y, -PI, PI))
	_move(-global_basis.z * clampf(cos(off), 0.15, 1.0), want_run, delta)

## p 可能已經被刪掉（預備出招時目標剛好死掉）：參數不寫型別，先檢查再用
func _turn_to(p: Variant, speed: float, delta: float) -> void:
	if not is_instance_valid(p):
		return
	var d: Vector3 = (p as Node3D).global_position - global_position
	rotation.y = rotate_toward(rotation.y, atan2(-d.x, -d.z), speed * delta)

## 走或跑。跑吃體力，見底就只能走，回到 RECOVER_AT 才能再跑
func _move(dir: Vector3, want_run: bool, delta: float) -> void:
	_stagger = maxf(_stagger - delta, 0.0)
	running = want_run and not exhausted and dir != Vector3.ZERO
	if running:
		stamina = maxf(stamina - RUN_DRAIN * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + REGEN * delta, STAMINA_MAX)
		if exhausted and stamina >= RECOVER_AT:
			exhausted = false
	var speed := (RUN if running else WALK) * (STAGGER_MULT if _stagger > 0.0 else 1.0)
	_accelerate(dir * speed, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()


# --- 受傷 ---

## 打不死：血打光就倒地 KNOCK_TIME 秒、血補滿，起來先退開（導演的高峰）。倒地時打不動。
## 恐龍決鬥模式例外：打得死（死了大家贏，見 Main._on_died）。派對模式起身後還有 GET_UP_GUARD 秒打不動
func take_damage(amount: int, source: Node = null) -> void:
	if down_left > 0.0 or guard_left > 0.0 or hp <= 0:
		return
	var g := _game()
	if hp - amount > 0 or (g and g.rules == &"dino_duel" and not g._sandbox):
		super(amount, source)
		return
	_knock.rpc()

@rpc("any_peer", "call_local", "reliable")
func _knock() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	down_left = PARTY_KNOCK_TIME if _party() else KNOCK_TIME
	hp = max_hp
	act = ACT_NONE
	_target = null
	_seen_left = 0.0
	_suspect = 0.0
	_spot_pending = false
	director.peak()
