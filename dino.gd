extends "res://fighter.gd"
## 恐龍：跑很快、血很多，沒有遠程。
## 左鍵咬前方，Space 尾巴橫掃四周（吃體力），Shift 衝刺（吃體力）。

const SPEED := 16.0
const SPRINT_MULT := 1.9
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 32.0  # 每秒消耗，全滿約衝 3 秒
const STAMINA_REGEN := 16.0  # 每秒回復，回滿約 6 秒
const MOUSE_SENS := 0.004
const BITE_REACH := 6.5
const BITE_DAMAGE := 35
const BITE_COOLDOWN := 0.9
# 尾巴橫掃：360 度、範圍大、傷害低，但要吃體力
const SWEEP_REACH := 10.0
const SWEEP_DAMAGE := 22
const SWEEP_COOLDOWN := 2.0
const SWEEP_COST := 40.0

var stamina := STAMINA_MAX
var _bite_cd := 0.0
var _sweep_cd := 0.0

func _ready() -> void:
	super()
	$Camera3D.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	if is_multiplayer_authority() and e is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * MOUSE_SENS)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var input := Vector3(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		0.0,
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and stamina > 0.0 and input != Vector3.ZERO
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)

	var speed := SPEED * (SPRINT_MULT if sprinting else 1.0)
	var move := (global_transform.basis * input).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	_apply_gravity(delta)
	move_and_slide()

	_bite_cd -= delta
	_sweep_cd -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _bite_cd <= 0.0:
		_bite_cd = BITE_COOLDOWN
		_hit_nearby(BITE_REACH, BITE_DAMAGE, 0.3)  # 只咬前方
		_play_fx.rpc(false)
	if Input.is_key_pressed(KEY_SPACE) and _sweep_cd <= 0.0 and stamina >= SWEEP_COST:
		_sweep_cd = SWEEP_COOLDOWN
		stamina -= SWEEP_COST
		_hit_nearby(SWEEP_REACH, SWEEP_DAMAGE, -1.0)  # 四面八方都掃到
		_play_fx.rpc(true)

# ponytail: 恐龍一定是主機（編號 1），所以直接算傷害，不用 RPC 繞一圈。
# 之後若要讓客戶端也能當恐龍，改成 rpc_id(1) 送請求。
## 打範圍內的坦克。min_dot 是方向限制：0.3 = 只打前方錐形，-1 = 不管方向
func _hit_nearby(reach: float, damage: int, min_dot: float) -> void:
	for p in get_parent().get_children():
		if p == self or not p.has_method("take_damage"):
			continue
		var to: Vector3 = p.global_position - global_position
		if to.length() < reach and (-global_transform.basis.z).dot(to.normalized()) > min_dot:
			p.take_damage(damage)


## 攻擊的示意動畫。要 rpc 才會在每個人畫面上都播。
@rpc("any_peer", "call_local", "reliable")
func _play_fx(sweep: bool) -> void:
	if sweep:
		var ring := TorusMesh.new()
		ring.inner_radius = SWEEP_REACH * 0.82
		ring.outer_radius = SWEEP_REACH
		Fx.burst(self, ring, Color(1, 0.55, 0.1, 0.85),
			Vector3(0, -2.4, 0), Vector3(0.15, 1.0, 0.15), Vector3.ONE, 0.3)
	else:
		# 頭往前撞一下 + 咬擊點爆一團
		var head: Node3D = $Head
		var t := create_tween()
		t.tween_property(head, "position:z", -4.4, 0.07)
		t.tween_property(head, "position:z", -2.8, 0.13)
		Fx.burst(self, SphereMesh.new(), Color(1, 0.35, 0.35, 0.8),
			Vector3(0, 1.5, -6.4), Vector3.ONE * 0.6, Vector3.ONE * 3.2, 0.2)
