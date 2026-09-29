extends Node3D
class_name ShotFX
## 開槍的視覺回饋：槍口火光、曳光、著彈碎屑（碎屑和煙在 Fx 特效庫）。全部用內建節點，沒有任何素材。
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
	Fx.gun_smoke(_world, global_position, -global_basis.z, smoke_lifetime, smoke_size)


## 子彈打到東西：照材質噴碎屑（Fx.SURFACES）；打到不會動的世界（不是血肉）留彈孔；
## sound = 要不要出著彈聲。
func impact(at: Vector3, normal: Vector3, surface: StringName, sound := true) -> void:
	Fx.hit(_world, at, normal, surface)
	if surface != &"blood":
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


## 用訊號不用 await：節點被別人先砍掉（重開一局清場）時，連線會自己斷，不會噴錯。
func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(node.queue_free)
