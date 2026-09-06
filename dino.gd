extends "res://fighter.gd"
## 恐龍：跑很快、血很多，沒有遠程。
## 左鍵咬前方，Space 跳躍（吃體力），Shift 衝刺（吃體力）。

const SPEED := 16.0
const SPRINT_MULT := 1.9
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 32.0  # 每秒消耗，全滿約衝 3 秒
const STAMINA_REGEN := 16.0  # 每秒回復，回滿約 6 秒
const MOUSE_SENS := 0.009  # 恐龍要靈活，轉頭比坦克快很多
const BITE_REACH := 6.5
const BITE_DAMAGE := 35   # 剛好四口咬死一台 140 血的坦克
const BITE_COOLDOWN := 1.1
# 跳躍：拉開距離、跨過障礙、撲向坦克
const JUMP_SPEED := 18.0  # 大約跳得起 6.5 公尺
const JUMP_COST := 30.0
const HEAD_HEIGHT := 1.6  # 視線從這個高度射出

var stamina := STAMINA_MAX
var _bite_cd := 0.0

func _ready() -> void:
	super()
	$Camera3D.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	rotate_y(-mouse_look(e).x * MOUSE_SENS)

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
	if Input.is_key_pressed(KEY_SPACE):
		try_jump()
	move_and_slide()

	_bite_cd -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _bite_cd <= 0.0:
		_bite_cd = BITE_COOLDOWN
		_hit_nearby(BITE_REACH, BITE_DAMAGE, 0.3)  # 只咬前方
		_play_fx.rpc(false)

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
		ring.inner_radius = 2.2
		ring.outer_radius = 3.0
		Fx.burst(get_tree().get_first_node_in_group(&"arena"), ring,
			Color(0.7, 0.65, 0.55, 0.7), global_position + Vector3(0, -2.4, 0),
			Vector3(0.4, 1.0, 0.4), Vector3.ONE * 1.6, 0.35)
	else:
		# 張嘴咬下去 + 咬擊點爆一團
		$Trex.bite()
		Fx.burst(self, SphereMesh.new(), Color(1, 0.35, 0.35, 0.8),
			Vector3(0, 1.1, -4.6), Vector3.ONE * 0.6, Vector3.ONE * 3.0, 0.2)
