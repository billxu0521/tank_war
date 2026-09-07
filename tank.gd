extends "res://fighter.gd"
## 坦克：車身慢慢轉，砲塔用滑鼠獨立瞄準（左右轉塔、上下抬砲），左鍵開砲。

const SPEED := 9.0
const REVERSE := 0.55      # 倒車只有前進的六成
const ACCEL := 7.0         # 每秒加速，約 1.3 秒到全速
const BRAKE := 13.0        # 煞車比加速快，放開按鍵不會滑很遠
const TURN := 1.8
const TURN_ACCEL := 5.0    # 車身轉向也要拉起來，不是瞬間到最大轉速
const ELEVATE := 1.1       # 砲管每秒最多抬這麼多
const RELOAD := 1.5
const MOUSE_SENS := 0.004
# 仿坦克世界：砲管上下有角度限制，車體擋住的部分打不到
const PITCH_MIN := -0.14  # 俯角 8 度
const PITCH_MAX := 0.35   # 仰角 20 度
const CAM_BASE := -0.4363  # 相機基礎俯角 25 度
const AIM_RANGE := 70.0    # 準心以這個距離做彈道歸零（場地大了，歸零拉遠）
const BARREL_Z := -1.5     # 砲管原本的位置，後座從這裡往後推
const SHELL := preload("res://shell.tscn")

var aim_pitch := 0.0
var turret_yaw := 0.0   # 砲塔左右，直接跟著滑鼠
var gun_pitch := 0.0
var _turn_rate := 0.0
var _recoil := 0.0
var _cooldown := 0.0
var _patrol_t := 0.0

@onready var turret: Node3D = $Turret
@onready var gun: Node3D = $Turret/Gun
@onready var muzzle: Marker3D = $Turret/Gun/Muzzle
@onready var cam: Camera3D = $Turret/Camera3D
@onready var barrel: Node3D = $Turret/Gun/Barrel

func _ready() -> void:
	super()
	cam.current = is_multiplayer_authority()

func _unhandled_input(e: InputEvent) -> void:
	aim(mouse_look(e))

## 砲塔左右直接跟著滑鼠；砲管上下有角度上限，抬升速度也有上限
func aim(rel: Vector2) -> void:
	turret_yaw -= rel.x * MOUSE_SENS
	aim_pitch = clampf(aim_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if dummy:
		_patrol(delta)
		return
	if not is_multiplayer_authority():
		return  # 別人的坦克交給 MultiplayerSynchronizer 更新

	gun_pitch = move_toward(gun_pitch, aim_pitch, ELEVATE * delta)  # 砲管抬升有速度上限
	turret.rotation.y = turret_yaw
	gun.rotation.x = gun_pitch

	_recoil = maxf(_recoil - delta * 4.5, 0.0)
	cam.rotation.x = CAM_BASE + gun_pitch * 0.5 + _recoil * 0.05  # 相機跟一半 + 開砲抬頭
	barrel.position.z = BARREL_Z + _recoil * 0.6                  # 砲管後座

	var turn := float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D))
	_turn_rate = move_toward(_turn_rate, turn * TURN, TURN_ACCEL * delta)
	rotate_y(_turn_rate * delta)

	var fwd := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var want := -global_transform.basis.z * fwd * SPEED * (REVERSE if fwd < 0.0 else 1.0)
	_accelerate(want, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()

	_cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cooldown <= 0.0:
		_cooldown = RELOAD
		_fire.rpc(muzzle.global_position, -muzzle.global_transform.basis.z)

## 離線練習用的移動靶：一邊繞圈一邊亂轉砲塔。撞到建築會自己滑開，
## 路線就不會太規律。編號單雙決定左轉還右轉，幾台才不會疊在一起。
func _patrol(delta: float) -> void:
	_patrol_t += delta
	rotate_y(TURN * 0.5 * delta * (1.0 if name.to_int() % 2 == 0 else -1.0))
	_accelerate(-global_transform.basis.z * SPEED * 0.75, ACCEL, BRAKE, delta)
	_apply_gravity(delta)
	move_and_slide()
	turret_yaw = sin(_patrol_t * 0.7) * 2.0
	turret.rotation.y = turret_yaw

@rpc("any_peer", "call_local", "reliable")
func _fire(pos: Vector3, dir: Vector3) -> void:
	_recoil = 1.0
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
