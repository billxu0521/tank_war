extends "res://fighter.gd"
class_name Cowboy
## 牛仔：第一人稱，操作照 Hunt: Showdown。從 FNE_project 的 player.gd 搬來，
## 血量、死亡、連線權限改吃 fighter.gd，跟恐龍同一套。
## 移動／蹲／翻越／體力是原本的。FNE 的互動系統（門、燈）這裡沒有；Q/E 探頭也拿掉了——
## Hunt 刻意不做探頭（見 docs/Hunt操作機制分析.md），怕變成躲在看不到的角落對槍。

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var crouch_speed := 2.5
@export var jump_velocity := 4.5
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
@export var vault_max_height := 1.5
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

const MODEL := preload("res://models/cowboy.glb")

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
@onready var _step_sound: AudioStreamPlayer = get_node_or_null("StepSound")
@onready var _jump_sound: AudioStreamPlayer = get_node_or_null("JumpSound")
@onready var _land_sound: AudioStreamPlayer = get_node_or_null("LandSound")

## 這個節點是不是「我自己」。false 代表它是別人的角色（或 bot），
## 輸入、HUD、相機都關掉。單機時恆為 true。
var is_local := true
## 唯一同步出去的操作狀態。遠端拿它重跑 `_apply_crouch`，膠囊、碰撞、
## 頭高三者一次到位，不用再各同步一份。
var sync_crouching := false

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
	if is_local:
		# 第一人稱看不到自己的軀幹和臉，但影子要在（地上看得到自己的影子，像 Hunt 那樣）。
		# 腿照樣畫：低頭看得到自己的靴子
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for leg in [_leg_l, _leg_r]:
			leg.position.z -= LOCAL_LEG_FORWARD
	if not is_local:
		_become_remote()
		return
	# 場景裡會有好幾台相機（每個玩家一台），不能靠 Godot 自動挑第一台——
	# 那台可能是別人的。自己的一定要明講。
	_camera.current = true
	# 相機不走物理插值（見 _process）：轉視角是滑鼠事件，補間會讓轉頭慢半拍。槍和手跟著相機
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## 走路時兩條腿繞髖關節前後擺，擺幅跟速度走。速度用位置差算：
## 遠端的人沒有 velocity（位置是同步器塞的），自己和 bot 用這個也一樣準
func _swing_legs(delta: float) -> void:
	var moved := global_position - _last_pos
	_last_pos = global_position
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001)
	if speed > 20.0 or vaulting or _ladder:
		speed = 0.0   # 瞬移（重生、爬到頂）和翻越、爬梯子時不擺
	_stride += speed * delta * STRIDE_RATE
	var amp := clampf(speed / walk_speed, 0.0, 1.4) * 0.45
	_swing = move_toward(_swing, amp, delta * 3.0)   # 停下來時慢慢收，不要一下彈回直的
	_leg_l.rotation.x = sin(_stride) * _swing
	_leg_r.rotation.x = -sin(_stride) * _swing


## 把 Blender 建的牛仔（blender/cowboy.py）換到身體和頭上。
## 頭掛在 Head 底下，跟著上下看的角度轉，別人看得出你在看哪裡。
func _skin() -> void:
	var src := MODEL.instantiate()
	# 自己看自己的腿只畫靴子（整條腿從正上方看只看得到褲管頂端）
	var leg := "Shin" if is_local else "Leg"
	for pair in [["CowboyBody", _body], ["CowboyHead", _face], ["Cowboy%sL" % leg, _leg_l], ["Cowboy%sR" % leg, _leg_r]]:
		var from := src.get_node_or_null(NodePath(pair[0])) as MeshInstance3D
		if from:
			(pair[1] as MeshInstance3D).mesh = from.mesh
	src.free()


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
	if not is_local:
		# 遠端角色拿同步過來的蹲下狀態重跑一次姿勢
		# ponytail: 腳步聲和落地聲沒有同步，聽不到別人走路。要做就把 AudioStreamPlayer
		# 換成 AudioStreamPlayer3D 再加一條 RPC。
		_apply_crouch(sync_crouching, delta)
		return
	# 翻越：鏡頭往下點頭、往側邊歪一下，看得出自己撐過去了
	var v := sin(PI * vault_t)
	_camera.rotation = Vector3(-0.22 * v, 0.0, 0.12 * v)
	# 相機位置用補間後的（移動不抖），朝向用現在的（轉頭零延遲）：
	# 相機掛在頭底下，差多少就往回挪多少。瞬移後補間會重設，這個差就是 0
	var lag := head.get_global_transform_interpolated().origin - head.global_position
	_camera.position = head.global_basis.inverse() * lag
	# 沒有準心（跟 Hunt 一樣靠槍身瞄）。打中人時畫面中間閃一下紅 +：
	# 遠距離看不出血條掉，這是唯一的命中確認
	_crosshair.visible = hit_until > Time.get_ticks_msec()
	_hp_fill.size.x = (_hp_fill.get_parent() as Control).size.x * clampf(float(hp) / max_hp, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# mouse_look 擋掉 macOS 鎖滑鼠後那串殘留位移（見 fighter.gd）
	var rel := mouse_look(event) * mouse_sensitivity
	if rel != Vector2.ZERO:
		rotate_view(rel)
		_look_delta += rel


func _physics_process(delta: float) -> void:
	if bot:
		_bot_step(delta)
		return
	if not is_local:
		return  # 位置、朝向全部由 MultiplayerSynchronizer 決定

	# 滑鼠是事件驅動的，手把要自己每 frame 讀
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		rotate_view(look * joypad_sensitivity * delta)

	# 翻越期間位置由 Tween 接管，只留視角給玩家轉
	if vaulting:
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
	elif Input.is_action_just_pressed("jump"):
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
	_track_fall()


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

## 電腦操控的牛仔。優先序跟以前的坦克 bot 一樣，行為固定才好拿來量平衡：
##   1. 拿著蛋 -> 去最近的撤離區
##   2. 蛋沒人拿 -> 去撿
##   3. 別人拿著 -> 追那個人（打死他蛋就掉下來）
## 走路方向和槍口方向分開：身體朝著威脅開槍，腳往目標走（Hunt 的側移射擊）。
## ponytail: 不翻越、不蹲，沒有尋路。卡牆就沿牆繞一段，場地都是大方塊，夠用；
## 場地變複雜（巷弄、室內）再換 NavigationAgent3D，FNE 那邊已經有烘 navmesh 的做法。
func _bot_step(delta: float) -> void:
	var g := get_tree().get_first_node_in_group(&"match")
	if not is_on_floor():
		velocity += get_gravity() * delta
	if walker:
		_walk_patrol(delta)
		return

	var want := Vector3.ZERO
	if not _bot_should_hold(g):
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
	_bot_shoot(_bot_threat(g))


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


## 撿蛋和撤離都要在原地待滿時間，跑掉就歸零
func _bot_should_hold(g: Node) -> bool:
	if g == null:
		return false
	if g.egg.carrier == name.to_int():
		return g._dist_to_exit(global_position) < g.EXIT_RADIUS * 0.5
	if g.egg.carrier == 0:
		return global_position.distance_to(g.egg.global_position) < g.PICKUP_RANGE * 0.5
	return false


func _bot_goal(g: Node) -> Vector3:
	if g == null:
		return global_position
	if g._sandbox:
		# 沙盒沒有蛋：直接去找玩家打，當陪練
		var me := _bot_threat(g)
		return me.global_position if me else global_position
	var my_id := name.to_int()
	if g.egg.carrier == my_id:
		var best: Vector3 = g._exits[0]
		for e: Vector3 in g._exits:
			if global_position.distance_to(e) < global_position.distance_to(best):
				best = e
		return best
	if g.egg.carrier == 0:
		return g.egg.global_position
	var holder: Node3D = g.players.get_node_or_null(NodePath(str(g.egg.carrier)))
	return holder.global_position if holder != null else g.egg.global_position


## 瞄誰：有人拿著蛋就瞄他，否則瞄最近的敵人（恐龍或別的牛仔）
func _bot_threat(g: Node) -> Node3D:
	if g == null:
		return null
	if g._sandbox:
		var me: Node3D = g.players.get_node_or_null(^"1")   # 沙盒裡只打玩家，不去打站樁的靶
		return null if me and _bush_hides(g, me) else me
	var my_id := name.to_int()
	if g.egg.carrier != 0 and g.egg.carrier != my_id:
		var holder: Node3D = g.players.get_node_or_null(NodePath(str(g.egg.carrier)))
		if holder != null:
			return holder
	var best: Node3D = null
	for p in g.players.get_children():
		if p == self or _bush_hides(g, p):
			continue
		if best == null or global_position.distance_to(p.global_position) \
				< global_position.distance_to(best.global_position):
			best = p
	return best


## 蹲在灌木叢裡的人 bot 看不到，除非走到 6 公尺內
func _bush_hides(g: Node, p: Node3D) -> bool:
	return global_position.distance_to(p.global_position) > 6.0 and g.hidden_in_bush(p)


## 轉身、抬頭對準，然後照一般玩家的流程扣扳機（散布、後座力、裝填都一樣）。
func _bot_shoot(threat: Node3D) -> void:
	if threat == null:
		return
	# 牛仔的原點在腳底，恐龍的原點在身體中心
	var aim := threat.global_position + (Vector3.ZERO if threat.is_in_group(&"dino") else Vector3.UP * 1.2)
	var to := aim - _camera.global_position
	var flat := Vector2(to.x, to.z).length()
	rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, flat)
	# 換彈中不扣扳機：try_fire 會中止逐發裝填，每幀都按的話永遠換不完
	if flat < bot_fire_range and not viewmodel._reloading:
		viewmodel.try_fire()


# --- 開槍打中：走主機 ---

## viewmodel 打中東西時呼叫。扣血只有主機能做（fighter.take_damage），
## 客戶端要請主機代打：請求送到 Main（Main.request_damage）不送到自己這個節點——
## 同時開槍時自己可能已經在主機上被打死刪掉了，送到自己會找不到節點，同歸於盡就不成立
func deal_damage(target: Node, amount: int) -> void:
	on_hit()
	if multiplayer.is_server():
		target.take_damage(amount, self)
	else:
		_match().request_damage.rpc_id(1, name.to_int(), target.get_path(), amount, _camera.global_position)


func _match() -> Node:
	return get_tree().get_first_node_in_group(&"match")


# --- 互動：門、梯子 ---

## 從畫面中央往前打一條短射線，看著的東西有 interact() 就是可以互動的（門、梯子）。
## 認方法不認型別，跟子彈認 take_damage 同一個做法
func update_focus() -> void:
	var from := _camera.global_position
	var hit := _ray(from, from - _camera.global_transform.basis.z * interact_range)
	var c: Object = hit.get("collider")
	focus = c if c and c.has_method(&"interact") else null
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


# --- 以下是 FNE 原本的移動系統 ---

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
	var knee := global_position + Vector3.UP * vault_min_height
	var wall := _ray(knee, knee + forward * vault_reach)
	if wall.is_empty():
		return false

	# 從障礙上方往下打，找出頂面在哪。往裡探三個深度取最高的：
	# 柵欄和牆只有 20 公分厚，只探一個 25 公分會越過它、打到另一邊的地上，當成「太矮不用翻」
	var top := {}
	for depth: float in [0.05, 0.15, 0.3]:
		var probe := Vector3(wall["position"].x, 0.0, wall["position"].z) + forward * depth
		probe.y = global_position.y + vault_max_height + 0.3
		var hit := _ray(probe, probe + Vector3.DOWN * (vault_max_height + 0.6))
		if not hit.is_empty() and (top.is_empty() or hit["position"].y > top["position"].y):
			top = hit
	if top.is_empty():
		return false

	var height: float = top["position"].y - global_position.y
	if height < vault_min_height or height > vault_max_height:
		return false

	# 往前跨出去之後腳踩在哪：寬平台會踩在自己的頂面，薄牆／窗戶則是踩到另一側地面。
	# 不重新找一次會落在頂面高度的半空中，翻完立刻往下掉
	var ahead: Vector3 = top["position"] + forward * vault_landing_offset
	var ground := _ray(
		ahead + Vector3.UP * 0.2, ahead + Vector3.DOWN * (vault_max_height + 1.2)
	)
	var landing: Vector3 = ground["position"] if ground else ahead
	if not _fits_at(landing):
		return false

	spend_stamina(vault_stamina)
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
		global_position = start.bezier_interpolate(c1, c2, landing, t), 0.0, 1.0, vault_time)
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
