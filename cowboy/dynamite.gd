class_name Dynamite
extends Node3D
## 丟出去的炸藥：一根紅色的棒子，引信冒火花、嘶嘶響。會彈、會滾，引信燒完就爆。
## 每台各自模擬一份（Viewmodel._throw）；只有丟的人那台的 on_explode 有東西，爆炸位置以它為準。
## ponytail: 自己用射線算彈跳，不用物理引擎的剛體——各台的結果比較接近，也不會被場景裡的東西推來推去

const GRAVITY := 14.0
const LENGTH := 0.30       # 紙筒長度（審查第 12 條：以前 0.24 像一截香腸）
const WICK := 0.09         # 引信長度
const BOUNCE := 0.35       # 彈起來剩幾成速度
const FRICTION := 0.6      # 碰地時水平速度剩幾成
const FUSE_SOUND := preload("res://assets/audio/weapons/fuse.wav")

var vel := Vector3.ZERO
var fuse := 4.0            # 還剩幾秒爆
var ignore: Array[RID] = []   # 剛丟出去時不撞到丟的人自己
var on_explode := Callable()  # 丟的人那台：爆的時候呼叫（位置）
var _spin := Vector3.ZERO


func _ready() -> void:
	add_child(stick_mesh())
	var spark := spark()
	spark.position = Vector3(0, LENGTH * 0.5 + WICK, 0)
	add_child(spark)
	var hiss := AudioStreamPlayer3D.new()
	hiss.stream = FUSE_SOUND
	hiss.unit_size = 4.0
	add_child(hiss)
	hiss.play()
	hiss.finished.connect(hiss.play)   # 循環
	_spin = Vector3(randf_range(-8, 8), randf_range(-3, 3), randf_range(-8, 8))


## 引信的火花（丟出去的、第一人稱手上的共用）
static func spark() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.14
	var ball := SphereMesh.new()
	ball.radius = 0.0025
	ball.height = 0.005
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.35)
	ball.material = m
	p.mesh = ball
	p.direction = Vector3.UP
	p.spread = 20.0            # 只從引信尖端噴一小撮（審查第 12 條：以前散在半個畫面像螢火蟲）
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -2.0, 0)
	p.local_coords = false
	return p


## 炸藥的樣子：紙筒（暗紅褐、中間一圈淡色的紙標）、頂端一截引信。第一人稱拿在手上也用這個
## （參考 docs/image/explosives/炸藥_參考.png：Hunt 的是舊舊的紅褐色紙筒，不是鮮紅）
static func stick_mesh() -> MeshInstance3D:
	var body := CylinderMesh.new()
	body.top_radius = 0.019
	body.bottom_radius = 0.019
	body.height = LENGTH
	body.radial_segments = 8
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.42, 0.13, 0.07)
	red.roughness = 0.9
	body.material = red
	var mi := MeshInstance3D.new()
	mi.mesh = body
	var band := MeshInstance3D.new()   # 紙標
	var b := CylinderMesh.new()
	b.top_radius = 0.0195
	b.bottom_radius = 0.0195
	b.height = 0.06
	b.radial_segments = 8
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.55, 0.42, 0.26)
	paper.roughness = 0.95
	b.material = paper
	band.mesh = b
	mi.add_child(band)
	var wick := MeshInstance3D.new()
	var w := CylinderMesh.new()
	w.top_radius = 0.003
	w.bottom_radius = 0.003
	w.height = WICK
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.13, 0.1)
	w.material = dark
	wick.mesh = w
	wick.position = Vector3(0, (LENGTH + WICK) * 0.5, 0)
	var glow := MeshInstance3D.new()   # 引信尖端燒著的那一點
	var g := SphereMesh.new()
	g.radius = 0.006
	g.height = 0.012
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.55, 0.15)
	g.material = hot
	glow.mesh = g
	glow.position = Vector3(0, WICK * 0.5, 0)
	wick.add_child(glow)
	mi.add_child(wick)
	return mi


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		if on_explode.is_valid():
			on_explode.call(global_position)
		queue_free()
		return
	if vel == Vector3.ZERO:
		return
	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = ignore
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		rotation += _spin * delta
		return
	var n: Vector3 = hit.normal
	global_position = hit.position + n * 0.03
	vel = vel.bounce(n) * BOUNCE
	if n.y > 0.6:
		vel.x *= FRICTION
		vel.z *= FRICTION
		_spin *= 0.5
		if vel.length() < 0.8:   # 停下來躺在地上
			vel = Vector3.ZERO
			rotation = Vector3(PI * 0.5, rotation.y, 0)
