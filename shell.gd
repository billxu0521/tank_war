class_name Shell
extends Area3D
## 砲彈。ponytail: 彈道是固定的拋物線，每台機器各自生一顆就會長得一樣，不用網路同步位置。
## 只有主機那顆會真的造成傷害。

const SPEED := 60.0
const DAMAGE := 40
const GRAVITY := 9.8  # 有掉落，遠距離要抬砲口

var vel := Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	vel.y -= GRAVITY * delta
	global_position += vel * delta

func _on_body_entered(body: Node3D) -> void:
	Fx.burst(get_tree().get_first_node_in_group(&"arena"), SphereMesh.new(),
		Color(1, 0.6, 0.2, 0.85), global_position,
		Vector3.ONE * 0.5, Vector3.ONE * 2.4, 0.25)
	if multiplayer.is_server() and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	queue_free()
