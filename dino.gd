extends "res://fighter.gd"
## 恐龍：跑很快、血很多，沒有遠程。
## 左鍵咬前方，Space 跳躍，Shift 衝刺，貼著建築按 W 往上爬（場地圍牆不給爬）。
## 滑鼠左右轉身、上下看（頭會跟著抬，相機繞著身體轉）。
## 衝刺、跳躍、攀爬都吃體力；體力見底會力竭，要回到 EXHAUSTED_UNTIL 才能再出力。

const SPEED := 16.0
const SPRINT_MULT := 1.9
const ACCEL := 22.0        # 這麼大一隻不該瞬間到全速
const BRAKE := 32.0
const STAMINA_MAX := 100.0
const SPRINT_DRAIN := 32.0     # 每秒；全滿約衝 3 秒
const CLIMB_DRAIN := 25.0      # 每秒；全滿約爬 4 秒 = 24 公尺，剛好爬得完最高的建築
const REGEN_STILL := 16.0      # 站著不動每秒回
const REGEN_MOVING := 7.0      # 邊走邊回慢很多
const EXHAUSTED_UNTIL := 30.0  # 力竭後要回到這個值才能再衝刺／攀爬
const CLIMB_SPEED := 6.0
const MOUSE_SENS := 0.009  # 恐龍要靈活，轉頭比坦克快很多
const BITE_REACH := 9.0   # 體型放大 1.5 倍，嘴巴搆得更遠
const BITE_DAMAGE := 35   # 剛好四口咬死一台 140 血的坦克
const BITE_COOLDOWN := 1.1
# 跳躍：拉開距離、跨過障礙、撲向坦克
const JUMP_SPEED := 18.0  # 大約跳得起 6.5 公尺
const JUMP_COST := 30.0
const HEAD_HEIGHT := 2.4  # 視線從這個高度射出
const CAM_BASE := -0.40   # 相機支點的基礎俯角
const PITCH_MIN := -0.75  # 往下看到底（約 43 度）
const PITCH_MAX := 0.45   # 往上看到底（約 26 度）

var look_pitch := 0.0   # 上下視角，有同步出去，遠端才看得到頭抬起來
var stamina := STAMINA_MAX
var exhausted := false
var _bite_cd := 0.0

func _ready() -> void:
	super()
	$CamPivot/Camera3D.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	var look := mouse_look(e)
	rotate_y(-look.x * MOUSE_SENS)
	look_pitch = clampf(look_pitch - look.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)

## 相機和抬頭都要在遠端也看得到，所以放 _process（_physics_process 只有本人在跑）
func _process(_delta: float) -> void:
	$CamPivot.rotation.x = CAM_BASE + look_pitch
	$Trex.look_pitch = look_pitch

func _physics_process(delta: float) -> void:
	if dummy:
		# 離線練習用的移動靶：繞圈跑，讓坦克練習算提前量
		rotate_y(0.55 * delta)
		move_step(delta, Vector3(0, 0, -1), false, false, false)
		return
	if not is_multiplayer_authority():
		return
	var input := Vector3(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		0.0,
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	move_step(delta, input, Input.is_key_pressed(KEY_SHIFT),
		Input.is_key_pressed(KEY_W), Input.is_key_pressed(KEY_SPACE))

	_bite_cd -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _bite_cd <= 0.0:
		_bite_cd = BITE_COOLDOWN
		_hit_nearby(BITE_REACH, BITE_DAMAGE, 0.3)  # 只咬前方
		_play_fx.rpc(false)

## 一幀的移動。輸入是傳進來的，鍵盤只在 _physics_process 讀一次，
## 這樣測試才驅動得了（Input 的按鍵狀態沒辦法從程式偽造）。
func move_step(delta: float, input: Vector3, want_sprint: bool,
		want_climb: bool, want_jump: bool) -> void:
	var moving := input != Vector3.ZERO
	# 貼著牆按 W 就往上爬。力竭就爬不動，會直接滑下來。
	var climbing := want_climb and _on_climbable_wall() and can_exert()
	var sprinting := want_sprint and moving and can_exert() and not climbing

	var spend := 0.0
	if climbing:
		spend = CLIMB_DRAIN
	elif sprinting:
		spend = SPRINT_DRAIN
	_update_stamina(delta, spend, moving)

	var speed := SPEED * (SPRINT_MULT if sprinting else 1.0)
	_accelerate((global_transform.basis * input).normalized() * speed, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	if climbing:
		# 往上爬的同時保留往前的推力，爬過屋簷才會自己翻上去
		velocity.y = CLIMB_SPEED
	if want_jump:
		try_jump()
	move_and_slide()

## 貼到的是不是「爬得上去」的牆。場地四周的圍牆不算——不然從高樓跳過去
## 再往上爬就翻出場外了。
func _on_climbable_wall() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) < 0.5 and not c.get_collider().is_in_group(&"arena_wall"):
			return true   # 接近垂直的面，而且不是場地圍牆
	return false

## 力竭中不能衝刺也不能爬。
## 沒有這個門檻的話，體力會在 0 附近抽動：回一點就衝、衝掉又停。
func can_exert() -> bool:
	return not exhausted

## spend > 0 表示這一幀在出力（衝刺或攀爬），否則回復。站著回得比走著快。
func _update_stamina(delta: float, spend: float, moving: bool) -> void:
	if spend > 0.0:
		stamina = maxf(stamina - spend * delta, 0.0)
	else:
		stamina = minf(stamina + (REGEN_MOVING if moving else REGEN_STILL) * delta, STAMINA_MAX)
	if stamina <= 0.0:
		exhausted = true
	elif stamina >= EXHAUSTED_UNTIL:
		exhausted = false

## 跳躍。踩在地上而且體力夠才跳得起來。
func try_jump() -> bool:
	if not is_on_floor() or stamina < JUMP_COST:
		return false
	stamina -= JUMP_COST
	velocity.y = JUMP_SPEED
	_play_fx.rpc(true)
	return true

# ponytail: 恐龍一定是主機（編號 1），所以直接算傷害，不用 RPC 繞一圈。
# 之後若要讓客戶端也能當恐龍，改成 rpc_id(1) 送請求。
## 打範圍內的坦克。min_dot 是方向限制：0.3 = 只打前方錐形，-1 = 不管方向。
## 中間隔著建築物就打不到——這是坦克躲掩蔽的依據。
func _hit_nearby(reach: float, damage: int, min_dot: float) -> void:
	for p in get_parent().get_children():
		if p == self or not p.has_method("take_damage"):
			continue
		var to: Vector3 = p.global_position - global_position
		if to.length() >= reach or (-global_transform.basis.z).dot(to.normalized()) <= min_dot:
			continue
		if _blocked_by_wall(p):
			continue
		p.take_damage(damage)

## 從恐龍頭部往目標拉一條線，被東西擋住就算打不到
func _blocked_by_wall(target: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * HEAD_HEIGHT, target.global_position)
	q.exclude = [get_rid(), target.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 示意動畫。要 rpc 才會在每個人畫面上都播。
@rpc("any_peer", "call_local", "reliable")
func _play_fx(jump: bool) -> void:
	if jump:
		# 起跳踢起一圈灰
		var ring := TorusMesh.new()
		ring.inner_radius = 3.3
		ring.outer_radius = 4.5
		Fx.burst(get_tree().get_first_node_in_group(&"arena"), ring,
			Color(0.7, 0.65, 0.55, 0.7), global_position + Vector3(0, -4.0, 0),
			Vector3(0.4, 1.0, 0.4), Vector3.ONE * 1.6, 0.35)
	else:
		# 張嘴咬下去 + 咬擊點爆一團
		$Trex.bite()
		Fx.burst(self, SphereMesh.new(), Color(1, 0.35, 0.35, 0.8),
			Vector3(0, 1.6, -7.0), Vector3.ONE * 0.9, Vector3.ONE * 4.5, 0.2)
