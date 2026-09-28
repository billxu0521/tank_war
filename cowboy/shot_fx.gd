extends Node3D
class_name ShotFX
## 開槍的視覺回饋：槍口火光、曳光、命中火花。全部用內建節點，沒有任何素材。
## 這個節點自己的位置就是槍口——曳光從相機原點出去會看起來像從眼睛射出來。

@export_group("Muzzle")
@export var flash_time := 0.05
@export var smoke_lifetime := 1.2
@export var smoke_size := 0.2

@export_group("Holes")
## 打在牆上的彈孔。可破壞物（會動、會消失）不留孔。
@export var hole_material: StandardMaterial3D
@export var hole_size := 0.07
@export var hole_lifetime := 10.0
@export var max_holes := 100
@export var impact_stream: AudioStream

@export_group("Tracer")
@export var tracer_width := 0.02
@export var tracer_material: StandardMaterial3D

@export_group("Impact")
@export var spark_count := 12
@export var spark_lifetime := 0.35
@export var spark_speed := 4.0
@export var spark_size := 0.03

@onready var _light: OmniLight3D = $Light
@onready var _flash: MeshInstance3D = get_node_or_null("Flash")

var _flash_left := 0.0
## 曳光和火花要留在世界上，掛在自己底下會跟著相機轉。
## 掛在 arena 不掛 owner.get_parent()：牛仔的上一層是 Players，那裡的每個子節點
## 都會被當成玩家（bot 選目標、恐龍咬人、存活人數都是掃 Players 的子節點）。
var _world: Node
var _holes: Array[MeshInstance3D] = []


func _ready() -> void:
	_world = get_tree().get_first_node_in_group(&"arena")
	if _world == null:
		_world = get_tree().current_scene
	_light.visible = false
	if _flash:
		_flash.visible = false


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_light.visible = false
		if _flash:
			_flash.visible = false


## 槍口火光。子彈本身（曳光、飛行）在 Bullet。
func flash() -> void:
	_light.visible = true
	if _flash:
		_flash.visible = true
		# 每發轉一個隨機角度，連射看起來才不像同一張貼圖閃爍
		_flash.rotation.z = randf() * TAU
	_flash_left = flash_time
	_spawn_smoke(global_position, -global_basis.z)


## 黑火藥的白煙：一團往前噴、慢慢變大、飄起來、散掉。Pax 開一槍眼前就是一團煙
func _spawn_smoke(at: Vector3, forward: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.mesh = _smoke_mesh()
	smoke.amount = 16
	smoke.lifetime = smoke_lifetime
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.direction = forward
	smoke.spread = 30.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 3.5
	smoke.damping_min = 3.0
	smoke.damping_max = 5.0
	smoke.gravity = Vector3(0.0, 0.25, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = fade
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(smoke)
	smoke.global_position = at
	smoke.emitting = true
	_free_after(smoke, smoke_lifetime + 0.1)


var _smoke: SphereMesh
func _smoke_mesh() -> SphereMesh:
	if _smoke == null:
		_smoke = SphereMesh.new()
		_smoke.radius = smoke_size
		_smoke.height = smoke_size * 2.0
		_smoke.radial_segments = 8
		_smoke.rings = 4
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true     # color_ramp 的透明度要靠這個才吃得到
		mat.albedo_color = Color(0.7, 0.69, 0.66)
		mat.roughness = 1.0
		_smoke.material = mat
	return _smoke


## 子彈打到東西：火花；solid = 打到不會動的世界，留彈孔；sound = 要不要出著彈聲。
func impact(at: Vector3, normal: Vector3, solid: bool, sound := true) -> void:
	_spawn_sparks(at, normal)
	if solid:
		_spawn_hole(at, normal)
	if sound:
		impact_sound(at)


## 彈孔貼片：貼著命中面、存活一段時間、總數有上限（最舊的先回收）。
func _spawn_hole(at: Vector3, normal: Vector3) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * hole_size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = hole_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(m)
	# 沿法線抬 1mm，不然跟牆面共面會閃爍（z-fighting）
	m.global_position = at + normal * 0.001
	if normal != Vector3.ZERO:
		m.look_at(at + normal, Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP)
	_holes.append(m)
	# 到期的孔被 _free_after 收掉後參考還留在陣列裡，先濾掉失效的，
	# 不然 pop 出來的可能是已釋放實例（賦值給型別變數會報錯）
	_holes = _holes.filter(is_instance_valid)
	while _holes.size() > max_holes:
		_holes.pop_front().queue_free()
	_free_after(m, hole_lifetime)


## 命中點的著彈聲，一次扣扳機播一聲（不是每顆彈丸一聲）。
func impact_sound(at: Vector3) -> void:
	if not impact_stream:
		return
	var snd := AudioStreamPlayer3D.new()
	snd.stream = impact_stream
	snd.max_distance = 60.0
	_world.add_child(snd)
	snd.global_position = at
	snd.play()
	snd.finished.connect(snd.queue_free)


func _spawn_sparks(at: Vector3, normal: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * spark_size
	mesh.material = tracer_material

	var sparks := CPUParticles3D.new()
	# 粒子是世界座標的，一進場景就會噴。先關掉，擺好位置再開，
	# 不然整把火花會生在父節點原點而不是命中點。
	sparks.emitting = false
	sparks.mesh = mesh
	sparks.amount = spark_count
	sparks.lifetime = spark_lifetime
	sparks.one_shot = true
	# 全部同一瞬間噴出來，不要拖成一條連續的煙。
	# CPUParticles3D 叫 explosiveness，GPUParticles3D 才是 explosiveness_ratio
	sparks.explosiveness = 1.0
	# direction 是節點的本地座標，這裡不轉節點所以本地就等於世界
	sparks.direction = normal
	sparks.spread = 45.0
	sparks.initial_velocity_min = spark_speed * 0.4
	sparks.initial_velocity_max = spark_speed
	_world.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	_free_after(sparks, spark_lifetime)


## 用訊號不用 await：節點被別人先砍掉（重開一局清場）時，連線會自己斷，不會噴錯。
func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(node.queue_free)
