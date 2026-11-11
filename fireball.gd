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
var wreck := false         # 打中可拆的積木扣一下（尼諾拉的火球；toy_build.gd 自己擋等級 3）
var _flown := 0.0          # 飛了多遠
# 外觀（FireballFx，純表演，沒畫面的伺服器不建）
var look_size := 1.4            # 火球看起來的直徑（公尺）
var look_from := Vector3.INF    # 外觀從這裡（嘴裡蓄火的位置）出發，BLEND 秒內滑到真正的位置；判定不受影響
const BLEND := 0.12
var _look: Node3D
var _age := 0.0
var _off := Vector3.ZERO

func _ready() -> void:
	get_tree().create_timer(5.0).timeout.connect(_end.bind(false))
	set_process(FireballFx.on)
	if FireballFx.on:
		_look = FireballFx.flight(self, look_size)

## 每幀（只有有畫面的那台）：外觀從嘴裡滑到真正的位置、芯自己轉
func _process(delta: float) -> void:
	if _age == 0.0 and look_from != Vector3.INF:
		_off = look_from - global_position
	_age += delta
	_look.position = _off * (1.0 - smoothstep(0.0, BLEND, _age))
	_look.get_node(^"Ball").rotate(Vector3(0.3, 1.0, 0.2).normalized(), delta * 9.0)

## 火球沒了。hit = 打到東西（爆開在 FireballFx.impact），不是的話是飛到底自己熄掉
func _end(hit: bool) -> void:
	if _look and not is_queued_for_deletion():
		FireballFx.release(_look, get_parent())
		if not hit:
			FireballFx.fizzle(get_parent(), _look.global_position, look_size)
	queue_free()

func _physics_process(delta: float) -> void:
	vel.y -= gravity * delta
	var from := global_position
	var to := from + vel * delta
	_flown += (to - from).length()
	if max_range > 0.0 and _flown > max_range:
		_end(false)
		return
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty() and radius > 0.0:
		hit = _near(to)
	if hit.is_empty():
		global_position = to
		return
	if FireballFx.on:
		var world := get_tree().get_first_node_in_group(&"arena") as Node3D
		var normal: Vector3 = hit.get(&"normal", -vel.normalized())   # 擦到人（_near）沒有法線：朝來的方向爆
		if world:
			FireballFx.impact(world, hit.position, normal, look_size, normal.y > 0.6 and (hit.collider as Node).is_in_group(&"ground"))
	if hit.collider.has_method("take_damage"):
		if is_instance_valid(shooter):
			shooter.on_hit()
		if multiplayer.is_server():
			hit.collider.take_damage(damage, shooter if is_instance_valid(shooter) else null)
			if burn and hit.collider.has_method("ignite"):
				hit.collider.ignite(shooter)
	elif wreck and multiplayer.is_server() and hit.collider.has_method(&"smash"):   # 積木（toy_build.gd）：半徑（球半徑的 2 倍）內的塊
		var at: Vector3 = hit.position
		var reach := radius * 2.0
		hit.collider.fireball_fire(at, reach)   # 打到可燃的塊留一灘火（物理規則第二版）。認方法不認型別：寫 ToyBuild 會循環載入（toy_build → … → fireball.tscn）
		hit.collider.smash(func(p: Vector3) -> bool: return p.distance_to(at) < reach, Balance.whole("hit_fireball_force"), from, AABB(at - Vector3.ONE * reach, Vector3.ONE * reach * 2.0))
	_end(true)

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
