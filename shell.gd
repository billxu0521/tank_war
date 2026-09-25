class_name Shell
extends Node3D
## 砲彈。ponytail: 彈道是固定的拋物線，每台機器各自生一顆就會長得一樣，不用網路同步位置。
## 只有主機那顆會真的造成傷害。
##
## 用射線掃過這一幀的位移，不是靠碰撞區域——砲彈一幀跑 1.7 公尺，
## 用區域偵測會直接穿過坦克。

const SPEED := 150.0  # 70 公尺只要 0.47 秒。原本 100 太慢，恐龍在飛行時間內就跑掉了
const DAMAGE := 40
const GRAVITY := 9.8  # 有掉落，遠距離要抬砲口

var vel := Vector3.ZERO
var shooter: Node = null

func _ready() -> void:
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	_impact(hit.position, hit.collider)

func _impact(pos: Vector3, body: Node) -> void:
	var on_flesh := body.has_method("take_damage")
	# 打到人爆得比打到地板大，而且偏紅——不用看血條就知道有沒有中
	Fx.burst(get_tree().get_first_node_in_group(&"arena"), SphereMesh.new(),
		Color(1, 0.35, 0.2, 0.9) if on_flesh else Color(1, 0.6, 0.2, 0.85), pos,
		Vector3.ONE * 0.5, Vector3.ONE * (4.5 if on_flesh else 2.4), 0.25)
	if on_flesh:
		if is_instance_valid(shooter):
			shooter.on_hit()   # 每台機器自己的那顆都會叫，開砲的人本機就看得到命中
		if multiplayer.is_server():
			body.take_damage(DAMAGE, shooter if is_instance_valid(shooter) else null)
	queue_free()
