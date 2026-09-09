class_name Fireball
extends Node3D
## 恐龍的火球。跟砲彈一樣用射線掃過每幀位移，但飛得慢、弧度大，
## 打得到遠處但躲得掉——恐龍的定位是近戰，火球是逼位不是主力輸出。
##
## ponytail: 沒有跟 shell.gd 共用一份程式碼。坦克的準心歸零算式吃 Shell 的常數，
## 抽成可設定的參數反而更繞。兩邊各二十幾行，之後手感真的分岔了也好改。

const SPEED := 45.0
const DAMAGE := 45
const GRAVITY := 12.0

var vel := Vector3.ZERO
var shooter: Node = null

func _ready() -> void:
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		global_position = to
		return
	Fx.burst(get_tree().get_first_node_in_group(&"arena"), SphereMesh.new(),
		Color(1, 0.45, 0.1, 0.9), hit.position, Vector3.ONE * 0.8, Vector3.ONE * 5.0, 0.3)
	if multiplayer.is_server() and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(DAMAGE, shooter if is_instance_valid(shooter) else null)
	queue_free()
