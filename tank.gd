extends "res://fighter.gd"
## 坦克：車身慢慢轉，砲塔用滑鼠獨立瞄準（左右轉塔、上下抬砲），左鍵開砲。

const SPEED := 9.0
const TURN := 1.8
const RELOAD := 1.0
const MOUSE_SENS := 0.004
# 仿坦克世界：砲管上下有角度限制，車體擋住的部分打不到
const PITCH_MIN := -0.14  # 俯角 8 度
const PITCH_MAX := 0.35   # 仰角 20 度
const CAM_BASE := -0.4363  # 相機基礎俯角 25 度
const AIM_RANGE := 55.0    # 準心以這個距離做彈道歸零
const SHELL := preload("res://shell.tscn")

var turret_yaw := 0.0
var gun_pitch := 0.0
var _cooldown := 0.0

@onready var turret: Node3D = $Turret
@onready var gun: Node3D = $Turret/Gun
@onready var muzzle: Marker3D = $Turret/Gun/Muzzle
@onready var cam: Camera3D = $Turret/Camera3D

func _ready() -> void:
	super()
	cam.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	aim(mouse_look(e))

## 滑鼠移動量 -> 砲塔左右轉 + 砲管上下抬（上下有角度上限）
func aim(rel: Vector2) -> void:
	turret_yaw -= rel.x * MOUSE_SENS
	gun_pitch = clampf(gun_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return  # 別人的坦克交給 MultiplayerSynchronizer 更新

	turret.rotation.y = turret_yaw
	gun.rotation.x = gun_pitch
	cam.rotation.x = CAM_BASE + gun_pitch * 0.5  # 相機跟一半，抬砲時視野才不會鑽到地上

	rotate_y((float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D))) * TURN * delta)
	var fwd := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var move := -global_transform.basis.z * fwd * SPEED
	velocity.x = move.x
	velocity.z = move.z
	_apply_gravity(delta)
	move_and_slide()

	_cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cooldown <= 0.0:
		_cooldown = RELOAD
		_fire.rpc(muzzle.global_position, -muzzle.global_transform.basis.z)

@rpc("any_peer", "call_local", "reliable")
func _fire(pos: Vector3, dir: Vector3) -> void:
	Fx.burst(muzzle, SphereMesh.new(), Color(1, 0.85, 0.3, 0.9),
		Vector3.ZERO, Vector3.ONE * 0.3, Vector3.ONE * 1.2, 0.12)
	var s := SHELL.instantiate()
	s.vel = dir * s.SPEED
	get_tree().get_first_node_in_group(&"arena").add_child(s)
	s.global_position = pos


## 砲彈在 AIM_RANGE 距離會落在哪裡。準心畫在這個點上，玩家才知道會打到哪。
func aim_point() -> Vector3:
	var t := AIM_RANGE / Shell.SPEED
	return muzzle.global_position \
		- muzzle.global_transform.basis.z * AIM_RANGE \
		+ Vector3.DOWN * (0.5 * Shell.GRAVITY * t * t)
