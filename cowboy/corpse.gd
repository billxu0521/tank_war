class_name Corpse
extends Node3D
## 牛仔死掉後的屍體：身體（連手）、頭、兩條腿四塊用關節連起來，往被打的方向推一下，自己癱下去（分段布娃娃）。
## 牛仔模型沒有骨架（是分開的硬零件），所以不用 Godot 的骨架布娃娃，直接把零件變成物理剛體。
##
## 每台電腦在 died 時各自生一具，不走網路：只是畫面，每台倒的樣子差一點沒關係。
## 不擋人、不擋子彈（collision_layer 0），只會撞到地面、建築。LIFETIME 秒後消失。
## 自己死的那具（mine）帶一台鏡頭：從眼睛往後上方拉開看自己倒下；重生時新牛仔的相機會搶回去。
## ponytail: 零件之間不互撞（都在 layer 0），腿可能穿進身體一點。看得出來再給零件各自的層

const LIFETIME := 10.0
const PUSH := 2.5        # 往被打的方向推多快（公尺/秒）。4 的時候 3 秒滑了快 5 公尺
const TIP := 4.5         # 往那個方向倒的轉速（弧度/秒）
const CAM_BACK := 5.0    # 死亡鏡頭離屍體多遠
const CAM_UP := 1.8      # 3 的時候幾乎從正上方往下看，看不到周圍
## 每塊的質量（公斤）
const PARTS := {torso = 40.0, head = 5.0, leg_l = 10.0, leg_r = 10.0}

## 跟地面的摩擦：不加的話方塊碰撞箱在地上一直滑（推 4 公尺/秒，3 秒滑快 5 公尺）
static var _ROUGH := _rough()
static func _rough() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = 1.0
	m.rough = true
	return m

var parts := {}          # 名字 -> RigidBody3D（測試用）
var _cam: Camera3D
var _dir := Vector3.ZERO
var _left := LIFETIME


## 照牛仔現在的姿勢生一具屍體。from 是打過來的位置（INF＝不知道，例如摔死，往後倒）
static func spawn(c: Node3D, from: Vector3, mine: bool) -> Corpse:
	var k := Corpse.new()
	var at := c.global_position
	var dir := at - from if from != Vector3.INF else c.global_basis.z   # 朝後（+Z）倒
	dir.y = 0.0
	k._dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	var g := c.get_tree().get_first_node_in_group(&"match")
	(g if g else c.get_tree().root).add_child(k)
	k._build(c)
	if mine:
		k._cam = Camera3D.new()
		k.add_child(k._cam)
		k._cam.global_transform = (c.get_node(^"Head/Camera3D") as Node3D).global_transform
		k._cam.current = true
	return k


func _build(c: Node3D) -> void:
	var src: Node = (Cowboy.MODEL_OLD if OS.get_environment("COWBOY_OLD") != "" else Cowboy.MODEL_NEW).instantiate()
	var body := c.get_node(^"Body") as Node3D
	var head := c.get_node(^"Head") as Node3D
	# 自己的牛仔腿往前挪過（低頭看得到靴子，cowboy.gd 的 LOCAL_LEG_FORWARD），屍體要擺回原位
	var leg_fix := body.global_basis * Vector3(0, 0, Cowboy.LOCAL_LEG_FORWARD) if c.get(&"is_local") else Vector3.ZERO
	var leg_l := (c.get_node(^"Body/LegL") as Node3D).global_transform.translated(leg_fix)
	var leg_r := (c.get_node(^"Body/LegR") as Node3D).global_transform.translated(leg_fix)
	var arms := (c.get_node(^"Body/Arms") as Node3D).global_transform
	parts.torso = _part(body.global_transform, [[src, "CowboyBody", Transform3D.IDENTITY], [src, "CowboyArms", body.global_transform.affine_inverse() * arms]], PARTS.torso)
	parts.head = _part(head.global_transform, [[src, "CowboyHead", Transform3D.IDENTITY]], PARTS.head)
	parts.leg_l = _part(leg_l, [[src, "CowboyLegL", Transform3D.IDENTITY]], PARTS.leg_l)
	parts.leg_r = _part(leg_r, [[src, "CowboyLegR", Transform3D.IDENTITY]], PARTS.leg_r)
	src.free()
	# 關節：脖子、兩個髖。ConeTwist 的扭轉軸是關節的 X 軸，轉成沿著肢體（頭往上、腿往下）
	_joint(parts.torso, parts.head, head.global_position, Basis(Vector3.BACK, PI / 2), 0.6, 0.3)
	_joint(parts.torso, parts.leg_l, leg_l.origin, Basis(Vector3.BACK, -PI / 2), 1.1, 0.3)
	_joint(parts.torso, parts.leg_r, leg_r.origin, Basis(Vector3.BACK, -PI / 2), 1.1, 0.3)
	# 往被打的方向推、往那邊倒：繞 UP × dir 轉，頭會往 dir 那邊倒
	for p: RigidBody3D in parts.values():
		p.linear_velocity = _dir * PUSH + Vector3.UP
	(parts.torso as RigidBody3D).angular_velocity = Vector3.UP.cross(_dir) * TIP


## 一塊剛體：meshes 是 [模型, 節點名, 相對這塊的位置]；碰撞箱、重心照網格的外框
func _part(at: Transform3D, meshes: Array, mass: float) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = mass
	# 躺下去就停靠摩擦（粗糙＝跟地面取大的那個），不靠空氣阻力：阻力大到不滑的話，倒下去像慢動作（量過 1.5 要 1.2 秒才倒平）
	rb.physics_material_override = _ROUGH
	rb.angular_damp = 1.0
	add_child(rb)
	rb.global_transform = at
	var box := AABB()
	for m: Array in meshes:
		var from := (m[0] as Node).get_node_or_null(NodePath(m[1])) as MeshInstance3D
		if from == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = from.mesh
		mi.transform = m[2]
		rb.add_child(mi)
		var b: AABB = mi.transform * from.mesh.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = box.size.max(Vector3.ONE * 0.05)
	shape.position = box.get_center()
	rb.add_child(shape)
	rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM   # 不然重心在零件原點（身體是腳底）
	rb.center_of_mass = box.get_center()
	return rb


func _joint(a: RigidBody3D, b: RigidBody3D, at: Vector3, axis: Basis, swing: float, twist: float) -> void:
	var j := ConeTwistJoint3D.new()
	add_child(j)
	j.global_transform = Transform3D(axis, at)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, swing)
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, twist)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if _cam and _cam.current:   # 死亡鏡頭：慢慢拉到屍體後上方，看得到打你的那邊
		var target := (parts.torso as Node3D).global_transform * (parts.torso as RigidBody3D).center_of_mass
		var want := target + _dir * CAM_BACK + Vector3.UP * CAM_UP
		_cam.global_position = _cam.global_position.lerp(want, 1.0 - exp(-2.5 * delta))
		_cam.look_at(target)
