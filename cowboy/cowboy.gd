extends "res://fighter.gd"
class_name Cowboy
## 牛仔：第一人稱，操作照 Hunt: Showdown。從 FNE_project 的 player.gd 搬來，
## 血量、死亡、連線權限改吃 fighter.gd，跟恐龍同一套。
## 移動／蹲／翻越／體力是原本的。FNE 的互動系統（門、燈）這裡沒有；Q/E 探頭也拿掉了——
## Hunt 刻意不做探頭（見 docs/企劃/Hunt操作機制分析.md），怕變成躲在看不到的角落對槍。

@export_group("Movement")
# 以下三個從 balance.csv 讀（見 balance.gd），改數字去改表，所以不再 @export
var walk_speed: float = Balance.num("cowboy_walk")
var sprint_speed: float = Balance.num("cowboy_sprint")
var crouch_speed: float = Balance.num("cowboy_crouch")
## 起跳速度。設計原則（2026-10-09 使用者）：原地平地跳的高度不能超過柵欄高度（arena_map.gd 的 FENCE_H），
## 過柵欄一定要翻越。4.0 → 腳離地約 0.82 公尺（v²/2g，重力 9.8），跳得過碎塊、仍低於柵欄；
## 以前 3.1 是 0.49 公尺（碎塊擋死），4.5 是 1.03 公尺，直接跳過 1 公尺的柵欄
@export var jump_velocity := 4.0
## 走路自動跨上的障礙高度上限（見 _try_step）。矮的碎塊不用跳，走過去就上去
const STEP_H := 0.35
## 自動跨上的小跳起跳速度，要 ≤ jump_velocity（net_max_up 才算得過主機的往上上限）
const STEP_SPEED := 3.0
## 加速度，單位是 m/s²（不是每 frame 的插值比例），所以幀率高低不影響手感。
@export var ground_accel := 25.0
@export var air_accel := 6.0

@export_group("Stamina")
## 一條體力：跑、跳、翻越、閉氣、槍托都吃這條（左下黃條）。
## 體力不夠只影響移動速度（見底後不能跑，回到 sprint_min_stamina 才能再跑）；跳、翻越、近戰照樣做得到。
@export var max_stamina := 100.0
## 全力跑約 18 秒見底。Hunt 基礎約 34 秒，但這張圖只有 320 公尺，跑得太久就沒有「跑步很吵」以外的代價
@export var sprint_drain := 5.5
@export var stamina_recover := 15.0
## 停止出力後要等這麼久才開始回。沒有這段延遲，「衝一下放開再衝」等於無限衝刺。
## Hunt 約 3 秒，這裡取短一點，交火節奏比較快
@export var recover_delay := 2.0
## 體力見底後要回到這個值才准再衝。少了門檻會在零點附近抖動衝刺，一步一頓。
@export var sprint_min_stamina := 25.0
@export var jump_stamina := 15.0

@export_group("Look")
@export var mouse_sensitivity := 0.0025
## 右蘇桿的轉速，rad/s。手把是持續輸入，跟滑鼠的位移量不同單位。
@export var joypad_sensitivity := 3.0
@export var pitch_limit_deg := 89.0

@export_group("Vault")
## 翻得上去的高度範圍。低於下限的東西直接走上去就好，高於上限爬不動。
@export var vault_min_height := 0.4
@export var vault_max_height := 2.2
## 翻高：比這個高（到 vault_max_height）的是「撐上去」——比較慢、比較累（碎塊堆常常 1.5～2 公尺高，翻不上去就整個擋死）
@export var mantle_height := 1.5
@export var mantle_time := 0.9
@export var mantle_stamina := 30.0
## 障礙要在多近才翻得到。
@export var vault_reach := 1.0
@export var vault_time := 0.55
@export var vault_stamina := 20.0
## 翻上去之後往前站多遠（從障礙前緣算）。要大於「障礙厚度 + 膠囊半徑」，
## 不然翻過薄牆時人會落在牆邊，膠囊卡進牆裡導致整個翻越被判定為不可行。
@export var vault_landing_offset := 0.9
## 翻越、互動的射線打哪些層。
@export_flags_3d_physics var world_mask := 1

@export_group("Fall")
## 摔落：這個高度以下沒事，到 fall_lethal_height 摔死，中間照比例扣。
## Hunt 大約 15 公尺以上落在硬地必死；落在乾草捲（soft 群組）減半
@export var fall_safe_height := 4.0
@export var fall_lethal_height := 15.0

@export_group("Interact")
## 看著門、梯子多近按 F 有反應
@export var interact_range := 2.5
@export var climb_speed := 2.5

@export_group("Crouch")
@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var crouch_lerp := 12.0

@export_group("Footsteps")
@export var step_walk_interval := 0.5
@export var step_sprint_interval := 0.3
@export var step_crouch_interval := 0.8

@export_group("Bot")
## 移動標靶：在 patrol_a / patrol_b 之間來回走，不開槍、不搶蛋
@export var walker := false
var patrol_a := Vector3.ZERO
var patrol_b := Vector3.ZERO
var _to_b := true
## bot 進這個距離才開槍。手槍腰射散布 4 度，再遠打人形靶就是浪費子彈。
@export var bot_fire_range := 40.0

## 自己低頭看到的靴子、屍體：Tripo 生成、blender/cowboy_tripo.py 轉成四塊（2026-10-11）。COWBOY_OLD=1 啟動切回程式建的舊版（cowboy.glb）
## 別人眼中的牛仔是有骨架會動的那個（CowboyRig，2026-10-16）；COWBOY_OLD=1 也一起切回硬塊
const MODEL_NEW := preload("res://models/cowboy_tripo.glb")
const MODEL_OLD := preload("res://models/cowboy.glb")

@onready var head: Node3D = $Head
@onready var viewmodel: Viewmodel = $Head/Camera3D/Viewmodel
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = _collision.shape
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _stamina_fill: ColorRect = $HUD/StaminaBar/Fill
@onready var _crosshair: Control = $HUD/Crosshair
@onready var _hp_fill: ColorRect = $HUD/HealthBar/Fill
@onready var _prompt: Label = $HUD/PromptLabel
@onready var _body: MeshInstance3D = $Body
@onready var _face: MeshInstance3D = $Head/Face
@onready var _leg_l: MeshInstance3D = $Body/LegL
@onready var _leg_r: MeshInstance3D = $Body/LegR
@onready var _arms: MeshInstance3D = $Body/Arms
@onready var _step_sound: AudioStreamPlayer = get_node_or_null("StepSound")
@onready var _jump_sound: AudioStreamPlayer = get_node_or_null("JumpSound")
@onready var _land_sound: AudioStreamPlayer = get_node_or_null("LandSound")
var _step_sound3: AudioStreamPlayer3D   # 別人的腳步聲（_remote_footsteps），用到才建

## 這個節點是不是「我自己」。false 代表它是別人的角色（或 bot），
## 輸入、HUD、相機都關掉。單機時恆為 true。
var is_local := true
## 唯一同步出去的操作狀態。遠端拿它重跑 `_apply_crouch`，膠囊、碰撞、
## 頭高三者一次到位，不用再各同步一份。
var sync_crouching := false
## 正在做什麼別人看不出來的事（CowboyRig.ACT_*：翻越、爬梯、近戰），同步出去，別人畫面上才播得出對的動作
var sync_act := 0
## 手上拿哪把槍（Viewmodel 的 weapon_scenes 第幾個）。同步出去，別人看得到你換槍
var gun := 0:
	set(v):
		if v != gun:
			gun = v
			if is_node_ready():
				_show_gun()
## 別人眼中手上那把槍：照 blender/cowboy_tripo.py 印出的手的位置（Arms 座標）擺，握把在右手、槍身朝左手
const HAND_R := Vector3(0.116, -0.296, -0.352)
const HAND_L := Vector3(0.057, -0.223, -0.521)
var _held: Node3D
## 有骨架的身體（別人的牛仔才有）；null＝用硬塊（自己、COWBOY_OLD）
var _rig: CowboyRig

var stamina: float
## 大於 0 的時候體力不回復
var _recover_wait := 0.0
## 體力見底過，還沒回到門檻，暫時不准衝刺
var _sprint_locked := false
var _sprinting := false
var _stand_head_y: float
var _stamina_bar_width: float
## 翻越中：位置交給 Tween，一般移動和重力都先停掉
var vaulting := false
## 翻越進度 0..1（鏡頭點頭、槍放低、撐障礙的那隻手都看這個）
var vault_t := 0.0
## 這一 frame 累積的滑鼠視角增量（弧度），給 Viewmodel 的武器搖擺用，讀走就清零
var _look_delta := Vector2.ZERO
var _step_timer := 0.0
var _was_on_floor := true
const WALKER_SPEED := 3.0   # 移動標靶走多快（比人慢一點，練提前量）
## 走路擺腿：步伐相位、目前的擺幅、上一幀的位置
var _stride := 0.0
var _swing := 0.0
var _last_pos := Vector3.ZERO
var _speed := 0.0   # 上一幀量到的水平、垂直速度（公尺/秒），骨架動畫挑動作用
var _vy := 0.0
const STRIDE_RATE := 3.0          # 每走一公尺相位走多少，越大步子越碎
## 自己的腿往前挪多少：腿在鏡頭正下方的話，低頭只看得到兩個褲管的頂端；
## 往前一點才看得到褲管和靴子的正面
const LOCAL_LEG_FORWARD := 0.25
## C 切換的蹲下（Ctrl 是按住蹲）。Hunt 兩種都有，切換的比較不累手
var crouch_toggled := false
## 看著的門或梯子（有 interact() 的東西），沒有就是 null
var focus: Node = null
## 正在爬的梯子，沒在爬就是 null
var _ladder: Node = null
## 這次騰空的最高點。-INF＝還沒落地過（剛出生從半空掉下來不算摔）
var _fall_top := -INF
var _bot_alert := 0.0      # bot 剛被打：還剩幾秒不試密碼、專心還手
const BOT_ALERT := 1.5     # ponytail: 挨打後還手多久，憑感覺；要調再拉出來
## bot 繞牆：頂著牆走不動時沿牆面走一段
var _detour := Vector3.ZERO
var _detour_left := 0.0
var _detour_sign := 0.0


func _ready() -> void:
	super()
	# 電腦在主機上 authority 也是主機，但它不是「我」：不能搶相機、不能讀鍵盤
	is_local = is_multiplayer_authority() and not is_bot_id(name.to_int())
	# 客戶端的牛仔位置由自己同步出去，主機選的出生點傳不過來，不處理的話每個人都生在地圖正中間
	# （剛好在蛋和恐龍 boss 旁邊）。地圖每台一樣，自己挑一個出生點就好
	if is_local and not multiplayer.is_server():
		var g := get_tree().get_first_node_in_group(&"match")
		if g:
			position = g._spawn_point()
	stamina = max_stamina
	_stand_head_y = head.position.y
	_stamina_bar_width = _stamina_fill.size.x
	_refresh_stamina_bar()

	_skin()
	died.connect(_drop_corpse)
	_voice = AudioStreamPlayer3D.new()
	_voice.position = Vector3(0, 1.6, 0)   # 嘴巴的高度
	_voice.max_distance = 45.0
	add_child(_voice)
	if is_local:
		# 第一人稱看不到自己的軀幹和臉，但影子要在（地上看得到自己的影子，像 Hunt 那樣）。
		# 腿照樣畫：低頭看得到自己的靴子
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_arms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for leg in [_leg_l, _leg_r]:
			leg.position.z -= LOCAL_LEG_FORWARD
	_show_gun()
	if not is_local:
		_become_remote()
		Viewmodel.mark_target(self)   # 別人（和靶）是目標；自己的靴子不用
		return
	# 場景裡會有好幾台相機（每個玩家一台），不能靠 Godot 自動挑第一台——
	# 那台可能是別人的。自己的一定要明講。
	_camera.current = true
	# 相機不走物理插值（見 _process）：轉視角是滑鼠事件，補間會讓轉頭慢半拍。槍和手跟著相機
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hurt_hud = HurtHud.new(_camera)
	$HUD.add_child(_hurt_hud)
	$HUD.move_child(_hurt_hud, 0)   # 墊在血條、彈藥這些下面
	_spread_marks = Control.new()
	_spread_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spread_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spread_marks.draw.connect(_draw_spread_marks)
	$HUD.add_child(_spread_marks)
	# 血條掉血殘影：掉的那段先變淺色，等一下才縮回去，看得出這一下掉了多少
	_hp_lost = ColorRect.new()
	_hp_lost.color = Color(1.0, 0.85, 0.6, 0.9)
	_hp_lost.size = _hp_fill.size
	_hp_fill.get_parent().add_child(_hp_lost)
	_hp_fill.get_parent().move_child(_hp_lost, 0)


# --- 被打的回饋（只有自己的牛仔）---
var _hurt_hud: HurtHud
var _hp_lost: ColorRect
var _hp_lag := -1.0          # 殘影現在畫到的血量
var _hp_lag_wait := 0.0      # 掉血後殘影先停這麼久才開始縮
var _kick := Vector2.ZERO    # 鏡頭被打歪多少（弧度：x 上下、y 左右），每幀彈回來
var fire_punch := Vector3.ZERO   # 開槍畫面撞一下（弧度：上、左右、側歪），viewmodel 每幀填
var aim_rot := Vector3.ZERO      # 鏡頭該歪多少（沒乘鏡頭晃動設定），子彈方向照這個算
var _quake := 0.0                # 甩尾打到可拆的東西：鏡頭隨機抖的幅度（弧度），每幀衰減（add_shake）

## 叫聲（assets/audio/cowboy，~/project/moss-sfx 生的）：被打會叫、死掉會慘叫。每台都播，別人聽得到
const HURT_VOICES := [preload("res://assets/audio/cowboy/hurt_1.wav"), preload("res://assets/audio/cowboy/hurt_2.wav"),
	preload("res://assets/audio/cowboy/hurt_3.wav"), preload("res://assets/audio/cowboy/hurt_4.wav")]
const DEATH_VOICES := [preload("res://assets/audio/cowboy/death_1.wav"), preload("res://assets/audio/cowboy/death_2.wav"),
	preload("res://assets/audio/cowboy/death_3.wav")]
var _voice: AudioStreamPlayer3D

## 被打了：叫一聲；自己的話畫面四周閃紅、準心外圍標出打你的方向、鏡頭抖一下（傷越重抖越大）
func _on_hurt(amount: int, from: Vector3) -> void:
	_bot_alert = BOT_ALERT
	_bot_hit = true
	_bot_hit_ago = 0.0
	if brain and from.is_finite():   # 被恐龍打到：馬上知道牠在哪
		for c: Node in get_parent().get_children():
			if c.is_in_group(&"dino") and (c as Node3D).global_position.distance_to(from) < 20.0:
				brain.remember((c as Node3D).global_position, 1.0)
	if _rig:
		_rig.hit()
	if hp - amount <= 0:
		_death_cry()
	elif not _voice.playing:   # 散彈一次十幾顆彈丸各扣一次血：還在叫就不重來
		_voice.stream = HURT_VOICES.pick_random()
		_voice.play()
	if not is_local or _hurt_hud == null:
		return
	var frac := float(amount) / max_hp
	_hurt_hud.hurt(frac, from)
	_kick += Vector2(randf_range(0.03, 0.06), randf_range(-0.05, 0.05)) * (0.5 + frac * 3.0)
	_hp_lag_wait = 0.4

func _update_hurt(delta: float) -> void:
	if _hurt_hud == null:
		return
	_hurt_hud.low = clampf((HurtHud.LOW_HP - float(hp) / max_hp) / HurtHud.LOW_HP, 0.0, 1.0)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	if _hp_lag < hp:
		_hp_lag = hp
	_hp_lag_wait -= delta
	if _hp_lag_wait <= 0.0:
		_hp_lag = move_toward(_hp_lag, hp, max_hp * 0.8 * delta)
	_hp_lost.size = Vector2((_hp_fill.get_parent() as Control).size.x * clampf(_hp_lag / max_hp, 0.0, 1.0), _hp_fill.size.y)


## 鏡頭震一下（amount 是弧度，已乘過鏡頭晃動設定）。destructible 打到東西時呼叫
func add_shake(amount: float) -> void:
	_quake = minf(_quake + amount, 0.15)

## 走路時兩條腿繞髖關節前後擺，擺幅跟速度走。速度用位置差算：
## 遠端的人沒有 velocity（位置是同步器塞的），自己和 bot 用這個也一樣準
func _swing_legs(delta: float) -> void:
	var moved := global_position - _last_pos
	_last_pos = global_position
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001)
	# 抹平再給骨架挑動作：主機收別人的位置一秒 40 次、畫面 60 幀以上，有些幀量到 0，不抹會在站和走之間一直切
	var k := 1.0 - exp(-10.0 * delta)
	# 瞬移用「這幀動多遠」判斷，不用速度：別人的位置一秒只來 40 次，高幀數時一幀跳 0.2 公尺算出來會超過 20 m/s
	var warp := moved.length() > 1.0
	_speed = lerpf(_speed, 0.0 if warp else speed, k)
	_vy = lerpf(_vy, moved.y / maxf(delta, 0.0001) if absf(moved.y) < 1.0 else 0.0, k)   # 一幀動一公尺以上是瞬移
	if warp or vaulting or _ladder:
		speed = 0.0   # 瞬移（重生、爬到頂）和翻越、爬梯子時不擺
	_stride += speed * delta * STRIDE_RATE
	var amp := clampf(speed / walk_speed, 0.0, 1.4) * 0.45
	_swing = move_toward(_swing, amp, delta * 3.0)   # 停下來時慢慢收，不要一下彈回直的
	_leg_l.rotation.x = sin(_stride) * _swing
	_leg_r.rotation.x = -sin(_stride) * _swing


## 把牛仔模型換到身體和頭上。
## 頭掛在 Head 底下，跟著上下看的角度轉，別人看得出你在看哪裡。
func _skin() -> void:
	var g := _match()
	if not is_local and OS.get_environment("COWBOY_OLD") == "" and not (g and g.get(&"_dedicated")):   # 專用伺服器沒人看
		_rig = CowboyRig.new()
		_rig.name = &"Rig"
		_body.add_child(_rig)
		return
	var src := (MODEL_OLD if OS.get_environment("COWBOY_OLD") != "" else MODEL_NEW).instantiate()
	# 自己看自己的腿只畫靴子（整條腿從正上方看只看得到褲管頂端）
	var leg := "Shin" if is_local else "Leg"
	for pair in [["CowboyBody", _body], ["CowboyHead", _face], ["Cowboy%sL" % leg, _leg_l], ["Cowboy%sR" % leg, _leg_r], ["CowboyArms", _arms]]:
		var from := src.get_node_or_null(NodePath(pair[0])) as MeshInstance3D
		if from:
			(pair[1] as MeshInstance3D).mesh = from.mesh
	src.free()


## 手上的槍：拿那把槍場景裡的模型（Model）來擺，不跑槍的程式。自己看得到第一人稱的槍，這把只投影子
func _show_gun() -> void:
	if _held:
		_held.queue_free()
		_held = null
	if (_arms.mesh == null and _rig == null) or gun < 0 or gun >= viewmodel.weapon_scenes.size():
		return   # 舊牛仔沒有端槍的手臂
	var w := viewmodel.weapon_scenes[gun].instantiate()
	w.use_tripo()
	var model := w.get_node(^"Model") as Node3D
	w.remove_child(model)
	w.free()
	model.transform = Transform3D.IDENTITY
	# 握把大概在模型後三分之一：槍身中心往前挪，讓右手落在握把上
	var box := AABB()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY   # 還沒進場景樹，沒有 global_transform：自己沿父節點乘上去
		var n: Node = mi
		while n != model:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		box = (t * mi.get_aabb()) if box.size == Vector3.ZERO else box.merge(t * mi.get_aabb())
		if is_local:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_held = Node3D.new()
	_held.name = &"Held"
	_held.add_child(model)
	model.position = -Vector3(box.get_center().x, box.get_center().y, box.end.z - box.size.z * 0.3)
	if _rig:
		_rig.add_child(_held)   # 位置每幀照手的骨頭擺（_process）
	else:
		_arms.add_child(_held)
		_held.transform = Transform3D(Basis.looking_at(HAND_L - HAND_R), HAND_R)


## 別人的角色：把所有「這是我的畫面」的東西關掉。少關一項的症狀都很難查
## ——相機沒關會搶畫面、HUD 沒關會疊兩個準心。
## _physics_process 不關：bot 在主機上是「遠端」身分，但要靠它跑。
## viewmodel 自己會看 is_local 決定讀不讀輸入。
func _become_remote() -> void:
	_camera.current = false
	$HUD.visible = false
	viewmodel.visible = false
	set_process_unhandled_input(false)


func _process(delta: float) -> void:
	_swing_legs(delta)
	_arms.rotation.x = head.rotation.x   # 端槍的手臂跟著上下看
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		sync_act = CowboyRig.ACT_VAULT if vaulting else (CowboyRig.ACT_LADDER if _ladder else
			(CowboyRig.ACT_MELEE if viewmodel._melee_cooldown > 0.0 else CowboyRig.ACT_NONE))
	if _rig:
		_rig.update(delta, _speed, _vy, sync_act, head.rotation.x)
		if _held:
			_held.visible = _rig.holding
			if _rig.holding:
				_held.transform = _rig.gun_transform()
	if not is_local:
		# 遠端角色拿同步過來的蹲下狀態重跑一次姿勢
		_apply_crouch(sync_crouching, delta)
		_remote_footsteps(delta)
		return
	# 翻越：鏡頭往下點頭、往側邊歪一下，看得出自己撐過去了
	var v := sin(PI * vault_t)
	_update_hurt(delta)
	# 被打歪、開槍撞一下也會讓子彈偏（viewmodel 的 _spread_direction 用 aim_rot）：
	# 「鏡頭晃動」設定只縮畫面，子彈照原本的歪法，調到 0 不會比別人準
	aim_rot = Vector3(-0.22 * v + _kick.x, _kick.y, 0.12 * v + _kick.y * 0.5) + fire_punch
	_quake = lerpf(_quake, 0.0, 1.0 - exp(-10.0 * delta))
	_camera.rotation = aim_rot * Settings.v.get(&"shake", 1.0) + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _quake
	# 相機位置用補間後的（移動不抖），朝向用現在的（轉頭零延遲）：
	# 相機掛在頭底下，差多少就往回挪多少。瞬移後補間會重設，這個差就是 0
	var lag := head.get_global_transform_interpolated().origin - head.global_position
	_camera.position = head.global_basis.inverse() * lag
	# 沒有準心（跟 Hunt 一樣靠槍身瞄）。打中人時畫面中間閃一下紅 +：
	# 遠距離看不出血條掉，這是唯一的命中確認
	_crosshair.visible = hit_until > Time.get_ticks_msec()
	if _spread_marks:
		_spread_marks.queue_redraw()
	_hp_fill.size.x = (_hp_fill.get_parent() as Control).size.x * clampf(float(hp) / max_hp, 0.0, 1.0)


## 腰射的散布範圍：畫面中間左右兩條短線「-   -」，間距＝子彈可能飛出去的最大角度。
## 不是十字準心，只告訴你「子彈會落在這兩條線之間」。舉槍瞄準、槍放低時不畫（靠槍身瞄）
var _spread_marks: Control

func _draw_spread_marks() -> void:
	var vm := viewmodel
	if vm.ads > 0.5 or vm.weapon.lower > 0.5 or is_sprinting():
		return
	var deg: float = vm.spread + vm.weapon.pellet_spread + (vm.weapon.fan_spread if vm._wants_fan() else 0.0)
	var size := _spread_marks.size
	# 角度換成像素：鏡頭的 fov 是垂直視角，tan 比例對到半個畫面高
	var gap := tan(deg_to_rad(deg)) / tan(deg_to_rad(_camera.fov * 0.5)) * size.y * 0.5
	gap = maxf(gap, 4.0)
	var mid := size * 0.5
	for side in [-1.0, 1.0]:
		var a := mid + Vector2(side * gap, 0)
		var b := mid + Vector2(side * (gap + 10.0), 0)
		_spread_marks.draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0, 0, 0, 0.5), 2.0)   # 陰影，亮的地方也看得到
		_spread_marks.draw_line(a, b, Color(1, 1, 1, 0.85), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	# mouse_look 擋掉卡頓時累積湧進來的位移（見 fighter.gd 的 after_hitch）
	var rel := mouse_look(event) * mouse_sensitivity * _ads_sens()
	if rel != Vector2.ZERO:
		rotate_view(rel)
		_look_delta += rel


## 舉槍時靈敏度再乘的倍率（設定視窗），跟著舉槍進度慢慢變，不會一下跳
func _ads_sens() -> float:
	return lerpf(1.0, Settings.v.get(&"ads_sens", 1.0), viewmodel.ads) if viewmodel else 1.0


func _physics_process(delta: float) -> void:
	if bot:
		_bot_step(delta)
		return
	if not is_local:
		return  # 位置、朝向全部由 MultiplayerSynchronizer 決定

	# 滑鼠是事件驅動的，手把要自己每 frame 讀
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		look.y *= -1.0 if Settings.v.get(&"invert_y", false) else 1.0
		rotate_view(look * joypad_sensitivity * Settings.v.get(&"pad_sens", 1.0) * _ads_sens() * delta)

	# 翻越期間位置由 Tween 接管，只留視角給玩家轉
	if vaulting:
		return
	if frozen():
		_hold_still(delta)
		return

	# 爬梯子：W 上、S 下，Space 或 F 放手。這一幀不處理其他移動和互動
	if _ladder:
		climb_step(delta, Input.get_axis("move_back", "move_forward"),
			Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"))
		return

	update_focus()
	if focus and Input.is_action_just_pressed("interact"):
		focus.interact(self)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	# 舉槍時 Shift 是閉氣（viewmodel 在處理），不是跑步
	var wants_sprint := Input.is_action_pressed("sprint") and not Input.is_action_pressed("aim") \
		and input != Vector2.ZERO
	if Input.is_action_just_pressed("crouch_toggle"):
		crouch_toggled = not crouch_toggled
	if wants_sprint:
		crouch_toggled = false   # 跑起來就站起來，跟 Hunt 一樣
	var crouching := (Input.is_action_pressed("crouch") or crouch_toggled) and not wants_sprint
	crouching = crouching or _blocked_above()
	sync_crouching = crouching
	_apply_crouch(crouching, delta)
	_sprinting = update_stamina(wants_sprint, delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	if (is_on_floor() or _wedged()) and Input.is_action_just_pressed("jump"):
		# 前進頂著東西按跳＝翻越，其餘情況才是普通跳。get_vector 的 y 是 -1 代表往前
		if try_vault(input.y < 0.0):
			return
		velocity.y = jump_velocity
		spend_stamina(jump_stamina)
		if _jump_sound:
			_jump_sound.play()

	var speed := crouch_speed
	if not crouching:
		speed = sprint_speed if _sprinting else walk_speed
	# 舉槍就走不快。ads 是 0..1 的過渡值，速度跟著一起變
	speed = lerpf(speed, minf(speed, walk_speed * viewmodel.ads_speed_scale), viewmodel.ads)

	_move_flat(dir * speed, delta)

	if is_on_floor() and not _was_on_floor and _land_sound:
		_land_sound.play()
	_was_on_floor = is_on_floor()

	_update_footsteps(input != Vector2.ZERO, crouching, delta)


## move_toward 是固定加速度，lerp 是每 frame 收斂一個比例——後者幀率一變手感就跑掉
func _move_flat(want: Vector3, delta: float) -> void:
	var accel := ground_accel if is_on_floor() else air_accel
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, accel * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	_wedge_t = _wedge_t + delta if not is_on_floor() and get_slide_collision_count() > 0 and absf(global_position.y - _wedge_y) < 0.005 else 0.0
	_wedge_y = global_position.y
	_try_step(want)
	_track_fall()


## 走路撞到矮的（STEP_H 以下）就給一個小跳跨上去：不瞬移（主機要看移動速度上限），只把往上的速度給到 STEP_SPEED，水平速度不動。
## 頭上要有空、往前 0.3 公尺也走得過才算，不然就是牆。蹲在矮處、翻越、爬梯子不做
func _try_step(want: Vector3) -> void:
	var flat := Vector3(want.x, 0.0, want.z)
	if not is_on_floor() or flat.length() < 0.5 or not is_on_wall() or vaulting or _ladder or _blocked_above():
		return
	var raised := global_transform
	raised.origin += Vector3.UP * STEP_H
	if test_move(global_transform, Vector3.UP * STEP_H) or test_move(raised, flat.normalized() * 0.3):
		return
	velocity.y = maxf(velocity.y, STEP_SPEED)


## 記騰空最高點，落地時算摔了多高。本人和 bot 共用這條，所以放在移動之後。
func _track_fall() -> void:
	if not is_on_floor():
		if _fall_top > -INF:
			_fall_top = maxf(_fall_top, global_position.y)
		return
	_land()


## 站在地上的每一幀都會跑：剛落地就結算這次摔了多高，然後把最高點重設成腳下。
func _land() -> void:
	if _fall_top > -INF:
		var dmg := fall_damage(_fall_top - global_position.y)
		if dmg > 0 and _landed_on_soft():
			dmg /= 2
		if dmg > 0:
			_hurt_self(dmg)
	_fall_top = global_position.y


## 摔了 h 公尺要扣多少血
func fall_damage(h: float) -> int:
	var t := inverse_lerp(fall_safe_height, fall_lethal_height, h)
	return ceili(max_hp * clampf(t, 0.0, 1.0))


func _landed_on_soft() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7 and (c.get_collider() as Node).is_in_group(&"soft"):
			return true
	return false


## 自己弄傷自己（摔落）。扣血只有主機能做，客戶端要請主機代扣
func _hurt_self(amount: int) -> void:
	if multiplayer.is_server():
		take_damage(amount, null)
	else:
		_match().request_damage.rpc_id(1, name.to_int(), get_path(), amount, _camera.global_position)


# --- bot ---

## 電腦操控的牛仔：去哪由 brain（bot_brain.gd，打分數選動作）決定，這裡只管身體：走路、看牌、試密碼、開槍。
## 走路方向和槍口方向分開：身體朝著威脅開槍，腳往目標走（Hunt 的側移射擊）。
## 沙盒照舊直接去找玩家打（陪練）。
## ponytail: 不翻越、不蹲，沒有尋路。卡牆就沿牆繞一段；卡牆的秒數 tools/bot_sim.gd 量得到
var brain: BotBrain
var _bot_hit := false        # 上次想之後被打過（馬上重想、不管 LOCK）
var _bot_now := false        # 動作做完了（看完牌）：馬上重想
var _bot_wait := INF         # 看牌、試密碼的手腳：還要等幾秒（INF＝還沒走到）
var _bot_wait_for := ""      # 在等哪個動作
var _bot_label: Label3D      # F3 開著時頭上那行字（只有主機有）
var _bot_sense_dt := 0.0     # 上次看、聽之後過了幾秒
var _bot_hit_ago := INF      # 上次被打幾秒前
var _bot_heal := 0.0         # 躲好了在用急救包：用了幾秒
var _bot_spot := -1.0        # 看到恐龍、還沒反應過來：還剩幾秒（-1＝沒看到）
var _bot_dino_down := false  # 看到恐龍倒地
var _bot_target: Node3D      # 看得到、要打的（每次想的時候選）
var _bot_shot_wait := 0.0    # 每發之間多等的
var _bot_turned := 0.0       # 剛大轉身：瞄準多偏一點（剩幾秒）
var _aim_err := Vector2.ZERO # 瞄準偏多少（弧度：左右、上下），慢慢滑向 _aim_goal
var _aim_goal := Vector2.ZERO
var _aim_t := 0.0
var _look_yaw := 0.0         # 沒有要打的時候看哪（走的方向）
var _glance_t := 4.0         # 下一次往旁邊瞄還有幾秒
var _glance_left := 0.0
var _glance_off := 0.0
var bot_action: String:      # 正在做的動作（round_stats.gd、除錯用）
	get: return brain.action if brain else ""

func _bot_step(delta: float) -> void:
	if frozen():
		_hold_still(delta)
		return
	var g := get_tree().get_first_node_in_group(&"match")
	if not is_on_floor():
		velocity += get_gravity() * delta
	if walker:
		_walk_patrol(delta)
		return

	_bot_alert -= delta
	_bot_hit_ago += delta
	if g != null and not g._sandbox and multiplayer.is_server():
		_bot_think(g, delta)
		if _bot_alert <= 0.0:   # 看牌、試密碼只有主機算；挨打就先停
			_bot_safe_act(g, delta)
	var hold := _bot_should_hold(g)
	var want := Vector3.ZERO
	if not hold:
		var to := _bot_goal(g) - global_position
		to.y = 0.0
		if to.length() > 1.0:
			var dir := to.normalized()
			_detour_left -= delta
			if _detour_left > 0.0:
				dir = _detour
			elif is_on_wall() and Vector2(velocity.x, velocity.z).length() < 1.0:
				# 頂著牆走不動（正面撞牆或卡牆角）：沿牆面繞一段再回頭找路。
				# 編號單雙決定先往哪邊，幾個人才不會擠同一邊；再卡住就換邊
				if _detour_sign == 0.0:
					_detour_sign = 1.0 if name.to_int() % 2 == 0 else -1.0
				_detour_sign = -_detour_sign
				_detour = get_wall_normal().cross(Vector3.UP).normalized() * _detour_sign
				_detour_left = 1.5
				dir = _detour
			_sprinting = update_stamina(true, delta)
			want = dir * (sprint_speed if _sprinting else walk_speed)
	_move_flat(want, delta)
	_bot_hands(delta, want)
	_bot_hide(g, hold, delta)
	# 開槍是反射：腳照動作走，看得到就打。站在牌前、箱子旁邊（看牌、試密碼）時跟真人一樣不開槍（真人開著密碼盤拿不到槍），挨打才還手
	var threat := _bot_threat(g)
	if threat and not (hold and bot_action in ["看牌0", "看牌1", "試密碼"] and _bot_alert <= 0.0):
		_bot_shoot(threat, delta)
	else:
		_bot_look(delta, want)


## 到時間（或被打）就重想一次動作；換了動作照 BOT_LOG 印一行。頭上的字跟著換
func _bot_think(g: Node, delta: float) -> void:
	if brain == null:
		brain = BotBrain.new(name.to_int())
	_bot_sense_dt += delta
	if not brain.tick(delta, _bot_hit or _bot_now or brain.action == ""):
		_bot_show(g)
		return
	_bot_sense(g, _bot_sense_dt)
	_bot_sense_dt = 0.0
	var ctx := _bot_ctx(g)
	ctx.hit = _bot_hit
	_bot_hit = false
	_bot_now = false
	var was := brain.action
	if brain.think(ctx) and BotBrain.LOG:
		print("BOT %.1f %s：%s → %s（%s）" % [Engine.get_physics_frames() / float(Engine.physics_ticks_per_second),
			_bot_name(g), BotBrain.NAMES.get(was, was), BotBrain.NAMES.get(brain.action, brain.action), brain.describe()])
	_bot_show(g)


func _bot_name(g: Node) -> String:
	return g.party.names.get(name.to_int(), String(name)) if g.party else "電腦 %s" % name


## F3 開著時頭上一行字：誰、在做什麼、前三名分數。分數只有主機有，所以只有主機那台看得到
func _bot_show(g: Node) -> void:
	if g.get(&"_dedicated"):
		return
	if g.debug_hud and _bot_label == null:
		_bot_label = Label3D.new()
		_bot_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bot_label.no_depth_test = true
		_bot_label.fixed_size = true
		_bot_label.pixel_size = 0.0015
		_bot_label.font_size = 20
		_bot_label.outline_size = 6
		_bot_label.position = Vector3.UP * 2.3
		add_child(_bot_label)
	if _bot_label:
		_bot_label.visible = g.debug_hud
		_bot_label.text = "%s｜%s" % [_bot_name(g), brain.describe()]


## 給 brain 的狀況（欄位見 BotBrain.think）
func _bot_ctx(g: Node) -> Dictionary:
	var id := name.to_int()
	var p: Node = g.party
	var safe_on: bool = g.safe.locked()
	var dino: Variant = null   # 記得的恐龍位置；看到牠倒地、不在場＝null（不怕）
	var carrier := 0 if g.egg.carrier == 0 else (1 if g.egg.carrier == id else 2)
	var holder: Node3D = g.players.get_node_or_null(NodePath(str(g.egg.carrier))) if carrier == 2 else null
	var mates: Array = []
	for c: Node in g.players.get_children():
		if c.is_in_group(&"dino"):
			dino = null if _bot_dino_down else brain.dino_mem
		elif c != self and c is Cowboy:
			mates.append({"pos": c.global_position, "vel": c.velocity, "act": (c as Cowboy).bot_action if c.bot else "",
				"carry": g.egg.carrier == c.name.to_int()})
	return {"me": global_position, "hp": float(hp) / max_hp, "last_life": p != null and int(p.lives.get(id, 2)) <= 1,
		"time_left": p.time_left if p else 999.0, "locked": safe_on, "safe": g.safe.global_position,
		"cards": p.env_pos if p else [], "known": p._known.get(id, [-1, -1]) if p else [-1, -1],
		"carrier": carrier, "holder": holder.global_position if holder else g.egg.global_position, "egg": g.egg.global_position,
		"exits": g._exits, "ffa": p != null, "dino": dino, "conf": brain.conf, "mates": mates,
		"sees": brain.seen_ago < BotBrain.THINK + 0.1 and not _bot_dino_down, "hit_ago": _bot_hit_ago, "bushes": g.map._bushes}


## 移動標靶：來回走，走到端點就回頭，身體朝著走的方向（打側面比打正面難）
func _walk_patrol(delta: float) -> void:
	var target := patrol_b if _to_b else patrol_a
	var to := target - global_position
	to.y = 0.0
	# 走到端點、或撞到柵欄牆壁走不動（生在建築旁邊時），就回頭
	var stuck := is_on_wall() and Vector2(velocity.x, velocity.z).length() < 0.5
	if to.length() < 0.5 or stuck:
		_to_b = not _to_b
		to = Vector3.ZERO
	if to != Vector3.ZERO:
		rotation.y = atan2(-to.x, -to.z)
	_move_flat(to.normalized() * WALKER_SPEED, delta)


## 照動作看要不要站著：看牌、試密碼、撿蛋、撤離都要在原地待滿時間（跑掉就歸零），躲到了也站著
func _bot_should_hold(g: Node) -> bool:
	if g == null or g._sandbox or brain == null:
		return false
	match brain.action:
		"看牌0", "看牌1":
			return _flat_to(brain.last_ctx.cards[int(brain.action[-1])]) < Envelope.RANGE * 0.8
		"試密碼":
			return _flat_to(g.safe.global_position) < Safe.RANGE * 0.6
		"撿蛋":
			return global_position.distance_to(g.egg.global_position) < g.pickup_range() * 0.9   # 0.9：恐龍站在蛋上時，牛仔貼著身體還走得到這裡
		"撤離":
			return g._dist_to_exit(global_position) < g.EXIT_RADIUS * 0.5
		"躲", "守箱":
			return _flat_to(brain.goal(brain.last_ctx)) < 2.0
	return false


## 躲好了：在草叢裡就蹲下（藏得住，見 hidden_in_bush）；血少就用急救包（站著不動 medkit_seconds 秒，跟真人一樣）
func _bot_hide(g: Node, hold: bool, delta: float) -> void:
	var hiding := hold and bot_action == "躲"
	var crouch: bool = hiding and g.map._bushes.any(func(b: Vector3) -> bool: return _flat_to(b) < 1.2)
	sync_crouching = crouch   # 膠囊、頭高由 _process 照這個縮（bot 在主機上是「遠端」身分）
	if hiding and float(hp) / max_hp < BotBrain.HEAL_BELOW and medkits > 0:
		_bot_heal += delta
		if _bot_heal >= Fighter.medkit_seconds:
			_bot_heal = 0.0
			request_heal()
	else:
		_bot_heal = 0.0


func _bot_goal(g: Node) -> Vector3:
	if g == null:
		return global_position
	if g._sandbox:
		# 沙盒沒有蛋：直接去找玩家打，當陪練
		var me := _bot_threat(g)
		return me.global_position if me else global_position
	if brain == null or brain.action == "":   # 還沒想過（剛生出來、測試直接問）：先想一次
		brain = brain if brain else BotBrain.new(name.to_int())
		brain.think(_bot_ctx(g))
	return brain.goal(brain.last_ctx)


func _flat_to(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## 主機：看牌、試密碼的手。看牌要站在牌前 READ 秒才看到；試密碼到箱子旁先等 ARRIVE 秒，之後每次試完再等 GAP 秒，
## 沒人在試才從「跟看過的數字對得上、還沒試過」的組合隨機挑一個
func _bot_safe_act(g: Node, delta: float) -> void:
	var act := bot_action
	if act != _bot_wait_for or not _bot_should_hold(g):
		_bot_wait_for = act
		_bot_wait = INF
		return
	if not g.safe.locked() or g.party == null or not act in ["看牌0", "看牌1", "試密碼"]:
		return
	if _bot_wait == INF:
		_bot_wait = randf_range(BotBrain.ARRIVE_MIN, BotBrain.ARRIVE_MAX) if act == "試密碼" else randf_range(BotBrain.READ_MIN, BotBrain.READ_MAX)
	_bot_wait -= delta
	if _bot_wait > 0.0:
		return
	var id := name.to_int()
	var p: Node = g.party
	if act != "試密碼":
		if p.read(id, int(act[-1])):
			_bot_now = true
		return
	if g.safe.busy != 0:
		return
	var k: Array = p._known.get(id, [-1, -1])
	var left: Array = []
	for n in 100:
		if g.safe.tried[n] == 0 and (k[0] < 0 or n / 10 == k[0]) and (k[1] < 0 or n % 10 == k[1]):
			left.append(n)
	if not left.is_empty() and g.safe.try_code(id, left.pick_random()):
		_bot_wait = Safe.TRY_SECONDS + randf_range(BotBrain.GAP_MIN, BotBrain.GAP_MAX)


## 瞄誰：沙盒照舊找玩家；其他時候是上次看、聽時選的（_bot_sense，只有看得到的）
func _bot_threat(g: Node) -> Node3D:
	if g == null:
		return null
	if g._sandbox:
		# 沙盒裡只打玩家，不去打站樁的靶；恐龍沙盒的玩家是尼諾拉（boss）
		var me: Node3D = g._boss() if g._dino_sandbox else g.players.get_node_or_null(^"1")
		return null if me and _bush_hides(g, me) else me
	return _bot_target if is_instance_valid(_bot_target) and _bot_target.is_inside_tree() else null


## 主機、每次想之前：看、聽恐龍（記進 brain），選要打的（看得到的人裡：別人拿著蛋就打他，不然最近的）。
## 看到恐龍要過 REACT 秒（越遠越久）才算數；貼身馬上知道。別的牛仔先不算反應時間
func _bot_sense(g: Node, dt: float) -> void:
	_bot_target = null
	_bot_dino_down = false
	var best := INF
	for c: Node in g.players.get_children():
		if c == self or not c is Node3D or c.get(&"hp") == null or c.hp <= 0:
			continue
		var n := c as Node3D
		var d := _flat_to(n.global_position)
		var see := false
		if c.is_in_group(&"dino"):
			if _bot_sees(g, n, BotBrain.SIGHT_DINO):
				if _bot_spot < 0.0:
					_bot_spot = 0.0 if d < BotBrain.FEEL else float(brain.persona.get("react", BotBrain.REACT)) + BotBrain.REACT_PER_M * d
				_bot_spot -= dt
				if _bot_spot <= 0.0:
					see = true
					brain.remember(n.global_position, 1.0)
					var down = c.get(&"down_left")
					_bot_dino_down = down != null and down > 0.0
			else:
				_bot_spot = -1.0
				var act = c.get(&"act")
				var loud: bool = act != null and act != 0   # 吼叫、出招
				var run := Vector2((c as CharacterBody3D).velocity.x, (c as CharacterBody3D).velocity.z).length() > 5.0 if c is CharacterBody3D else false
				if (loud and d < BotBrain.HEAR_LOUD) or (run and d < BotBrain.HEAR_RUN):
					var r := randf() * minf(d * BotBrain.HEAR_FUZZ, BotBrain.HEAR_FUZZ_MAX)
					brain.remember(n.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * r, BotBrain.HEARD_CONF)
		elif c is Cowboy:
			see = _bot_sees(g, n, BotBrain.SIGHT_COWBOY)
		if not see:
			continue
		if g.egg.carrier == c.name.to_int():
			d = -1.0   # 別人拿著蛋：先打他
		if d < best:
			best = d
			_bot_target = n


## 看得到嗎（抄 boss.can_see，數字換成人的）：貼身一定知道；草叢裡看不到；太遠、不在視野錐、中間有牆都看不到
func _bot_sees(g: Node, p: Node3D, sight: float) -> bool:
	var to := p.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if flat < BotBrain.FEEL:
		return true
	if g.hidden_in_bush(p) or flat > sight:
		return false
	var fwd := -global_basis.z
	if Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to.x, to.z) / flat) < BotBrain.SIGHT_COS:
		return false
	var at: Vector3 = p.head_position() if p.has_method(&"head_position") else p.global_position + Vector3.UP * 1.5
	var hit := _ray(_camera.global_position, at)
	return hit.is_empty() or hit.collider == p or p.is_ancestor_of(hit.collider)


## 手的節奏：開槍間隔、剛轉身、瞄準偏差（每 AIM_SLIDE 秒換個方向、慢慢滑過去，不是每幀亂跳）
func _bot_hands(delta: float, want: Vector3) -> void:
	_bot_shot_wait -= delta
	_bot_turned -= delta
	_aim_t -= delta
	var deg := (BotBrain.AIM_BASE + (BotBrain.AIM_MOVING if want.length() > 0.5 else 0.0) + (BotBrain.AIM_TURNED if _bot_turned > 0.0 else 0.0)) \
		* (float(brain.persona.get("aim", 1.0)) if brain else 1.0)
	if _aim_t <= 0.0:
		_aim_t = BotBrain.AIM_SLIDE
		_aim_goal = Vector2.from_angle(randf() * TAU) * deg_to_rad(deg)
	_aim_err = _aim_err.move_toward(_aim_goal, deg_to_rad(deg) * 2.0 / BotBrain.AIM_SLIDE * delta)


## 沒有要打的：看走的方向，每 3～5 秒往旁邊或後面瞄一眼（不然背後來的恐龍永遠不知道）
func _bot_look(delta: float, want: Vector3) -> void:
	_glance_t -= delta
	_glance_left -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(BotBrain.GLANCE_MIN, BotBrain.GLANCE_MAX)
		_glance_left = BotBrain.GLANCE_TIME
		_glance_off = randf_range(0.4 * PI, PI) * (1.0 if randf() < 0.5 else -1.0)
	if Vector2(want.x, want.z).length() > 0.5:
		_look_yaw = atan2(-want.x, -want.z)
	_bot_turn(_look_yaw + (_glance_off if _glance_left > 0.0 else 0.0), 0.0, delta)


## 轉身有速度上限（TURN），回傳還差幾度（弧度）
func _bot_turn(yaw: float, pitch: float, delta: float) -> float:
	var dy := angle_difference(rotation.y, yaw)
	var step := BotBrain.TURN * delta
	if absf(dy) > step:
		_bot_turned = 0.5
	rotation.y += clampf(dy, -step, step)
	head.rotation.x = move_toward(head.rotation.x, pitch, step)
	return absf(angle_difference(rotation.y, yaw))


## 蹲在灌木叢裡的人 bot 看不到，除非走到 6 公尺內
func _bush_hides(g: Node, p: Node3D) -> bool:
	return global_position.distance_to(p.global_position) > 6.0 and g.hidden_in_bush(p)


## 轉身、抬頭對準（有轉速上限、會偏），轉過來了才照一般玩家的流程扣扳機（散布、後座力、裝填都一樣），每發之間多等一下
func _bot_shoot(threat: Node3D, delta := 1.0 / 60.0) -> void:
	if threat == null:
		return
	# 牛仔的原點在腳底，恐龍的原點在身體中心
	var aim := threat.global_position + (Vector3.ZERO if threat.is_in_group(&"dino") else Vector3.UP * 1.2)
	var to := aim - _camera.global_position
	var flat := Vector2(to.x, to.z).length()
	var off := _bot_turn(atan2(-to.x, -to.z) + _aim_err.x, atan2(to.y, flat) + _aim_err.y, delta)
	_look_yaw = rotation.y
	# 換彈中不扣扳機：try_fire 會中止逐發裝填，每幀都按的話永遠換不完
	if off > deg_to_rad(8.0) or flat >= bot_fire_range or viewmodel._reloading or _bot_shot_wait > 0.0:
		return
	if viewmodel.weapon.mag == 0:
		viewmodel.try_reload()   # 打空不會自動換彈（硬派規則），bot 要自己按
		return
	var before: int = viewmodel.weapon.mag
	viewmodel.try_fire()
	if viewmodel.weapon.mag < before:
		_bot_shot_wait = randf_range(BotBrain.SHOT_GAP_MIN, BotBrain.SHOT_GAP_MAX)


# --- 開槍打中：走主機 ---

## viewmodel 打中東西時呼叫。扣血只有主機能做（fighter.take_damage），
## 客戶端要請主機代打：請求送到 Main（Main.request_damage）不送到自己這個節點——
## 同時開槍時自己可能已經在主機上被打死刪掉了，送到自己會找不到節點，同歸於盡就不成立
## head：打中恐龍的頭（可以打斷蓄力，見 boss.gd 的 head_hit）
func deal_damage(target: Node, amount: int, head := false) -> void:
	on_hit()
	if multiplayer.is_server():
		if head and target.has_method(&"head_hit"):
			target.head_hit()
		target.take_damage(amount, self)
	else:
		_match().request_damage.rpc_id(1, name.to_int(), target.get_path(), amount, _camera.global_position, head)


## 派對模式的準備、結算階段：不能動、不能開槍（只能轉視角），見 Main.party_frozen
func frozen() -> bool:
	var g := _match()
	return g != null and g.party_frozen()


## 站著不動，但還是會落地
func _hold_still(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_move_flat(Vector3.ZERO, delta)


func _match() -> Node:
	return get_tree().get_first_node_in_group(&"match")


## 死前的慘叫：角色馬上會被刪掉，聲音另外放在場上，播完自己刪
func _death_cry() -> void:
	var g := _match()
	if g == null or g.get(&"_dedicated"):
		return
	var snd := AudioStreamPlayer3D.new()
	snd.stream = DEATH_VOICES.pick_random()
	snd.max_distance = _voice.max_distance
	g.add_child(snd)
	snd.global_position = _voice.global_position
	snd.play()
	snd.finished.connect(snd.queue_free)

## 死掉時每台各自留一具會癱倒的屍體（corpse.gd）。專用伺服器沒人看，不做
func _drop_corpse(_killer: Node) -> void:
	var g := _match()
	if g and g.get(&"_dedicated"):
		return
	Corpse.spawn(self, last_from, is_local)


# --- 互動：門、梯子 ---

## 從畫面中央往前打一條短射線，看著的東西有 interact() 就是可以互動的（門、梯子）。
## 認方法不認型別，跟子彈認 take_damage 同一個做法
func update_focus() -> void:
	var from := _camera.global_position
	var hit := _ray(from, from - _camera.global_transform.basis.z * interact_range)
	var c: Object = hit.get("collider")
	var was := focus
	focus = c if c and c.has_method(&"interact") else null
	if focus != was:
		Accent.focus(was, false)
		Accent.focus(focus, true)
	_prompt.text = "[F] %s" % focus.prompt if focus else ""


func is_climbing() -> bool:
	return _ladder != null


## 抓住梯子：貼到梯子前面、面向它，高度維持在梯子範圍內（從半空跳上來也抓得住）
func start_climb(ladder: Node) -> void:
	if _ladder:
		return
	_ladder = ladder
	velocity = Vector3.ZERO
	global_position = Vector3(ladder.foot.x, clampf(global_position.y, ladder.foot.y, ladder.top_y), ladder.foot.z)
	rotation.y = ladder.yaw
	_prompt.text = "[W/S] 上下爬　[Space] 放手"


## 爬一幀。直接改位置不走 move_and_slide：梯子頂端要穿過閣樓邊緣，碰撞會卡住。
## up 是 -1..1；let_go 放手（之後照一般規則掉下來，摔多高照算）
func climb_step(delta: float, up: float, let_go: bool) -> void:
	if let_go:
		_ladder = null
		return
	global_position.y += up * climb_speed * delta
	if global_position.y >= _ladder.top_y:
		global_position = _ladder.exit   # 到頂，站上閣樓／筒倉頂
		_fall_top = global_position.y
		_ladder = null
	elif up < 0.0 and global_position.y <= _ladder.foot.y:
		global_position.y = _ladder.foot.y   # 爬到底，腳踩地
		_ladder = null
	if not _ladder:
		_prompt.text = ""


## 主機檢查移動用：水平最快就是衝刺（翻越、爬梯子的水平位移都比它小）
func net_max_speed() -> float:
	return sprint_speed

## 往上最快：跳、爬梯子、翻越（頂面再多 0.5 公尺當餘裕，曲線會略高）
func net_max_up() -> float:
	# 翻越（到 mantle_height、vault_time 秒）和翻高（到 vault_max_height、mantle_time 秒）取快的那個
	return maxf(maxf(jump_velocity, climb_speed), maxf((mantle_height + 0.5) / vault_time, (vault_max_height + 0.5) / mantle_time))


# --- 以下是 FNE 原本的移動系統 ---

## 別人（遠端玩家、bot）的腳步聲：用量到的速度在自己這台踩，不用另外同步。
## 有位置，聽得出從哪個方向靠近；蹲著走比較小聲。
## ponytail: 別人的跳躍、落地聲沒做，要做再照 _vy 的變化補
func _remote_footsteps(delta: float) -> void:
	if _speed < 1.0 or sync_act == CowboyRig.ACT_VAULT or sync_act == CowboyRig.ACT_LADDER:
		_step_timer = 0.0
		return
	var interval := step_walk_interval
	if sync_crouching:
		interval = step_crouch_interval
	elif _speed > (walk_speed + sprint_speed) * 0.5:
		interval = step_sprint_interval
	_step_timer += delta
	if _step_timer < interval or not _step_sound:
		return
	_step_timer = 0.0
	# 要踩的那一下才看腳下有沒有地（不看垂直速度：上 30 度斜坡也要有聲音，跳在空中不能有）
	if _ray(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.3).is_empty():
		return
	var g := _match()
	if g and g.get(&"_dedicated"):   # 專用伺服器沒人聽
		return
	if not _step_sound3:
		_step_sound3 = AudioStreamPlayer3D.new()
		_step_sound3.stream = _step_sound.stream
		_step_sound3.unit_size = 3.0      # 二、三十公尺內聽得到
		_step_sound3.max_distance = 35.0
		add_child(_step_sound3)
	_step_sound3.volume_db = _step_sound.volume_db - (8.0 if sync_crouching else 0.0)
	_step_sound3.play()


func _update_footsteps(moving: bool, crouching: bool, delta: float) -> void:
	if not is_on_floor() or not moving:
		_step_timer = 0.0
		return
	var interval := step_walk_interval
	if _sprinting:
		interval = step_sprint_interval
	elif crouching:
		interval = step_crouch_interval
	_step_timer += delta
	if _step_timer >= interval:
		_step_timer = 0.0
		if _step_sound:
			_step_sound.play()


## 更新體力，回傳這個 frame 到底有沒有在衝刺。
func update_stamina(wants_sprint: bool, delta: float) -> bool:
	var sprinting := wants_sprint and not _sprint_locked and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		_recover_wait = recover_delay
		if stamina == 0.0:
			_sprint_locked = true
	else:
		_recover_wait = maxf(_recover_wait - delta, 0.0)
		if _recover_wait == 0.0:
			stamina = minf(stamina + stamina_recover * delta, max_stamina)
		if _sprint_locked and stamina >= sprint_min_stamina:
			_sprint_locked = false
	_refresh_stamina_bar()
	return sprinting


## 面前有沒有翻得過去的東西？有就翻，回傳 true。
## 條件：往前推、面前 vault_reach 內有東西、那個東西高度剛好（柵欄、窗台、乾草捲、矮牆）。
## 不用先撞上去——以前要 is_on_wall()，走到柵欄前按 Space 常常沒反應，看起來像沒有翻越。
##
## pressing_forward 用傳的不用自己讀 Input：headless 測試沒辦法模擬按鍵。
##
## ponytail: 翻越途中位置交給 Tween、不做碰撞。要做「翻到一半被打斷」再改成自己算位移。
func try_vault(pressing_forward: bool) -> bool:
	if vaulting:
		return false
	if not pressing_forward:
		return false

	var forward := -global_transform.basis.z
	# 從膝蓋高度往前找牆面。太低的東西直接走上去就好，不用翻
	# 碎塊堆常常底下是空的（斜靠著、疊歪）：膝蓋打不到就再往上打兩次
	var wall := {}
	for up: float in [vault_min_height, 0.8, 1.2]:
		var knee := global_position + Vector3.UP * up
		wall = _ray(knee, knee + forward * vault_reach)
		if not wall.is_empty():
			break
	if wall.is_empty():
		return false

	# 從障礙上方往下打，找出頂面在哪。往裡探三個深度取最高的：
	# 柵欄和牆只有 20 公分厚，只探一個 25 公分會越過它、打到另一邊的地上，當成「太矮不用翻」
	# 先從翻越的高度（mantle_height 上方）往下打，找不到合的再從翻高的高度打：
	# 窗戶上面還有牆，一開始就從高處打會打到窗戶上方的牆，翻不進窗
	var top := {}
	var height := 0.0
	for reach: float in [mantle_height, vault_max_height]:
		top = {}
		for depth: float in [0.05, 0.15, 0.3]:
			var probe := Vector3(wall["position"].x, 0.0, wall["position"].z) + forward * depth
			probe.y = global_position.y + reach + 0.3
			var hit := _ray(probe, probe + Vector3.DOWN * (reach + 0.6))
			if not hit.is_empty() and (top.is_empty() or hit["position"].y > top["position"].y):
				top = hit
		if not top.is_empty():
			height = top["position"].y - global_position.y
			if height >= vault_min_height and height <= reach:
				break
		top = {}
	if top.is_empty():
		return false

	# 往前跨出去之後腳踩在哪：寬平台會踩在自己的頂面，薄牆／窗戶則是踩到另一側地面。
	# 不重新找一次會落在頂面高度的半空中，翻完立刻往下掉
	# 碎塊堆凹凸不平：照預設距離站不下，就試站在頂上（近一點）、或跨遠一點
	# ponytail: 最多 30 次查詢，只在按跳的那一下。先照原本從頂面上方 0.2 往下打（窗戶：0.6 會打到窗框上緣）；
	# 都站不下再從 0.6 打（碎塊堆往前是往上疊的，0.2 的起點在碎塊裡）
	var landing := Vector3.INF
	var side := forward.cross(Vector3.UP)
	for lift: float in [0.2, 0.6]:
		for off: float in [vault_landing_offset, 0.35, 0.6, 1.4, 1.9]:
			for lat: float in [0.0, 0.4, -0.4]:
				var ahead: Vector3 = top["position"] + forward * off + side * lat
				var ground := _ray(ahead + Vector3.UP * lift, ahead + Vector3.DOWN * (vault_max_height + 1.2))
				var spot: Vector3 = (ground["position"] if ground else ahead) + Vector3.UP * 0.1   # 抬一點：凹凸的碎塊頂面差幾公分就判定卡住
				if spot.y - global_position.y <= vault_max_height + 0.3 and _fits_at(spot):
					landing = spot
					break
			if landing != Vector3.INF:
				break
		if landing != Vector3.INF:
			break
	if landing == Vector3.INF:
		return false

	var high := height > mantle_height
	spend_stamina(mantle_stamina if high else vault_stamina)
	vaulting = true
	velocity = Vector3.ZERO
	if _jump_sound:
		_jump_sound.play()
	# 一條「先往上撐、越過頂面、往前落下」的曲線。直線拉過去會像穿模而不是翻越
	var start := global_position
	var over := Vector3(top["position"].x, top["position"].y + 0.25, top["position"].z)
	var c1 := Vector3(start.x, over.y + 0.15, start.z)
	var c2 := over + forward * 0.3
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float) -> void:
		vault_t = t
		global_position = start.bezier_interpolate(c1, c2, landing, t), 0.0, 1.0, mantle_time if high else vault_time)
	tween.finished.connect(func():
		vaulting = false
		vault_t = 0.0
		_fall_top = global_position.y
		if _land_sound:
			_land_sound.play())
	return true


## 膠囊放到這裡會不會卡到東西。
func _fits_at(foot: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis(), foot + Vector3.UP * (_capsule.height * 0.5 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, world_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


## 給 Viewmodel 用：衝刺中就強制放下槍。
func is_sprinting() -> bool:
	return _sprinting


## 給武器搖擺用：拿走這一 frame 的視角增量。單一消費者，讀完就清。
func consume_look_delta() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d


## 一次性消耗（跳躍等），一樣會壓住恢復。
func spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_recover_wait = recover_delay
	if stamina == 0.0:
		_sprint_locked = true
	_refresh_stamina_bar()


## 見底鎖住時變紅，讓玩家知道現在按衝刺沒用
func _refresh_stamina_bar() -> void:
	_stamina_fill.size.x = _stamina_bar_width * (stamina / max_stamina)
	_stamina_fill.color = (
		Color(0.85, 0.25, 0.2) if _sprint_locked else Color(0.92, 0.75, 0.18)
	)


## 滑鼠、手把、後座力共用的轉視角：amount 是這一步要轉的弧度（x = 左右，y = 上下）。
func rotate_view(amount: Vector2) -> void:
	var limit := deg_to_rad(pitch_limit_deg)
	rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, -limit, limit)


## 用現在這個（矮的）膠囊往上掃過要長高的距離，被擋住就代表站不起來。
## 卡在碎塊中間：沒踩到平地（腳下是斜的邊角）但被夾住不動，也要能跳、能翻，不然整個卡死
## 要「高度不變超過 0.2 秒」才算：跳到最高點那一下不算，不然貼著牆在空中一直跳就能爬上去
func _wedged() -> bool:
	return _wedge_t > 0.2

var _wedge_t := 0.0
var _wedge_y := 0.0


func _blocked_above() -> bool:
	var grow := stand_height - _capsule.height
	return grow > 0.01 and test_move(global_transform, Vector3.UP * grow)


func _apply_crouch(crouching: bool, delta: float) -> void:
	var target := crouch_height if crouching else stand_height
	var h := lerpf(_capsule.height, target, minf(crouch_lerp * delta, 1.0))
	_capsule.height = h
	_collision.position.y = h * 0.5
	head.position.y = _stand_head_y - (stand_height - h)
	# 身體跟著往下壓，別人才看得出你蹲下了。原點在腳底，所以只要縮 Y
	_body.scale.y = h / stand_height
