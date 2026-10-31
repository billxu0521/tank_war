class_name Fireball
extends Node3D
## 恐龍的火球。跟砲彈一樣用射線掃過每幀位移，但飛得慢、弧度大，
## 打得到遠處但躲得掉——恐龍的定位是近戰，火球是逼位不是主力輸出。
## 尼諾拉的火球（boss.gd）用另外的設定：直線、有半徑、飛得遠、會燒人；舊恐龍用的是下面的預設值，行為不變。
##

const SPEED := 45.0
const DAMAGE := 50  # 三顆打死一個牛仔
const GRAVITY := 12.0

var vel := Vector3.ZERO
var shooter: Node = null
var speed := SPEED         # 初速（呼叫的人照這個設 vel）
var gravity := GRAVITY    # 重力加速度，0 = 直線飛
var radius := 0.0          # 0 = 只用射線；大於 0 = 每幀另外用球形查詢找會受傷的人，中心偏這麼遠也算
var max_range := 0.0       # 0 = 不限（照原本 5 秒消失）；大於 0 = 飛超過這麼遠就消失
var damage := DAMAGE
var burn := false          # 打中人就點著（燃燒見 fighter.gd）
var wreck := false         # 打中可拆的方塊扣一下（派對模式的尼諾拉火球；destructible.gd 自己擋等級 3）
var _flown := 0.0          # 飛了多遠

func _ready() -> void:
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	vel.y -= gravity * delta
	var from := global_position
	var to := from + vel * delta
	_flown += (to - from).length()
	if max_range > 0.0 and _flown > max_range:
		queue_free()
		return
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty() and radius > 0.0:
		hit = _near(to)
	if hit.is_empty():
		global_position = to
		return
	Fx.burst(get_tree().get_first_node_in_group(&"arena"), SphereMesh.new(),
		Color(1, 0.45, 0.1, 0.9), hit.position, Vector3.ONE * 0.8, Vector3.ONE * 5.0, 0.3)
	if hit.collider.has_method("take_damage"):
		if is_instance_valid(shooter):
			shooter.on_hit()
		if multiplayer.is_server():
			hit.collider.take_damage(damage, shooter if is_instance_valid(shooter) else null)
			if burn and hit.collider.has_method("ignite"):
				hit.collider.ignite(shooter)
	elif wreck and multiplayer.is_server() and hit.collider.has_method(&"tail_hit"):
		hit.collider.tail_hit(from)
	queue_free()

## 射線沒打到的時候，看半徑之內有沒有會受傷的人（擦過去也算）。發射者不算
func _near(at: Vector3) -> Dictionary:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), at)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(q):
		if r.collider.has_method("take_damage"):
			return {"position": at, "collider": r.collider}
	return {}
