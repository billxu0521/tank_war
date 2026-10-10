class_name Ambience
extends Node3D
## 環境感（2026-10-10，docs/image/style_check/評估_2026-10-10_FPS角度.md 的 #2 補充）：
##   一、每區自己的光：森林冷綠偏暗、城鎮暖橘、麥田金黃。照鏡頭在哪一區調太陽和環境光，跨區時照位置慢慢混，不會一下跳色
##   二、風滾草：鏡頭上風處生、順風滾過去，滾遠了或撞到東西就換個地方重生
## 都只是畫面，不走網路，各台自己算。main.gd 在有畫面時才建（伺服器不建）。

const FEATHER := 10.0   # 公尺：進區多深才完全換成那區的光
## 區域 -> [太陽顏色, 太陽亮度倍數, 環境光顏色, 環境光亮度倍數]。顏色是照夕陽調的；換時段（period.gd）時
## 換算成「跟夕陽原本的顏色差幾倍」乘到那個時段上，不然進森林會一下跳回夕陽的顏色
const REF_SUN := Color(1.0, 0.78, 0.52)      # main.tscn 的太陽
const REF_AMB := Color(0.55, 0.52, 0.68)     # main.tscn 的環境光
const LOOKS := {
	&"forest": [Color(0.92, 0.8, 0.6), 0.75, Color(0.42, 0.56, 0.5), 0.9],
	&"town": [Color(1.0, 0.64, 0.36), 1.05, Color(0.74, 0.5, 0.4), 1.05],
	&"wheat": [Color(1.0, 0.82, 0.46), 1.12, Color(0.62, 0.56, 0.5), 1.0],
}
const WEEDS := 3
const WEED_SPEED := Vector2(3.0, 5.0)

var _main: Node
var _sun: DirectionalLight3D
var _env: Environment
var _base: Array   # main.tscn 原本的值，區外用這個
var _zones: Dictionary
var _weeds: Array[MeshInstance3D] = []
var _speed: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _wind := Vector3(Fx.WIND.x, 0, Fx.WIND.z).normalized()


func setup(main: Node) -> void:
	name = &"Ambience"   # period.gd 用名字找
	_main = main
	_sun = main.get_node(^"Arena/Sun")
	_env = (main.get_node(^"Arena/WorldEnvironment") as WorldEnvironment).environment
	rebase()
	_zones = {&"forest": main.ZONE_FOREST, &"town": main.ZONE_TOWN, &"wheat": main.ZONE_WHEAT}
	var mesh := _weed_mesh()
	for i in WEEDS:
		var w := MeshInstance3D.new()
		w.mesh = mesh
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.set_instance_shader_parameter(&"spin", 0.0)
		add_child(w)
		w.visible = false
		_weeds.append(w)
		_speed.append(0.0)


## 時段換了（period.gd）：重抓太陽和環境光的基準
func rebase() -> void:
	_base = [_sun.light_color, _sun.light_energy, _env.ambient_light_color, _env.ambient_light_energy]


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _main == null:
		return
	_light(cam.global_position)
	for i in _weeds.size():
		_roll(i, cam.global_position, delta)


## 照鏡頭位置，把各區的光照「進區多深」加權混起來
func _light(at: Vector3) -> void:
	var look := _base.duplicate()
	for k: StringName in _zones:
		var r: Rect2 = _zones[k]
		var inside := minf(minf(at.x - r.position.x, r.end.x - at.x), minf(at.z - r.position.y, r.end.y - at.z))
		var w := smoothstep(0.0, FEATHER, inside)
		if w <= 0.0:
			continue
		var l: Array = LOOKS[k]
		look[0] = (look[0] as Color).lerp(_base[0] * l[0] / REF_SUN, w)
		look[1] = lerpf(look[1], _base[1] * l[1], w)
		look[2] = (look[2] as Color).lerp(_base[2] * l[2] / REF_AMB, w)
		look[3] = lerpf(look[3], _base[3] * l[3], w)
	_sun.light_color = look[0]
	_sun.light_energy = look[1]
	_env.ambient_light_color = look[2]
	_env.ambient_light_energy = look[3]


func _roll(i: int, cam: Vector3, delta: float) -> void:
	var w := _weeds[i]
	if not w.visible or w.global_position.distance_to(cam) > 40.0 or _blocked(w.global_position):
		_respawn(i, cam)
		return
	var p := w.global_position + _wind * _speed[i] * delta
	var t := Time.get_ticks_msec() * 0.001 + i * 1.7
	var r := 0.55
	p.y = _main._terrain.height(p.x, p.z) + r + absf(sin(t * 2.6)) * 0.35   # 一蹦一蹦地滾
	w.global_position = p
	# 在畫面上轉圈：風往畫面右邊吹就順時針轉
	var cam_right := get_viewport().get_camera_3d().global_basis.x
	var turn := -signf(_wind.dot(cam_right)) * _speed[i] / r * delta
	w.set_instance_shader_parameter(&"spin", float(w.get_instance_shader_parameter(&"spin")) + turn)


## 上風處 15～25 公尺、左右亂偏，地上要是空地：森林和麥田不生（樹林裡滾不動、麥田裡看不到）
func _respawn(i: int, cam: Vector3) -> void:
	var w := _weeds[i]
	w.visible = false
	var side := _wind.cross(Vector3.UP)
	var p := cam - _wind * _rng.randf_range(15.0, 25.0) + side * _rng.randf_range(-15.0, 15.0)
	for k: StringName in [&"forest", &"wheat"]:
		if (_zones[k] as Rect2).has_point(Vector2(p.x, p.z)):
			return
	p.y = _main._terrain.height(p.x, p.z) + 0.55
	if _blocked(p):
		return
	w.global_position = p
	_speed[i] = _rng.randf_range(WEED_SPEED.x, WEED_SPEED.y)
	w.visible = true


## 順風方向前面一公尺有沒有東西擋（牆、柵欄、石頭）；起點往上抬一點，不會打到地面
func _blocked(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.UP * 0.3 + _wind * 1.0)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 一張面向鏡頭的方形，貼亂枝團的圖（tools/make_tumbleweed.py）
static func _weed_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.2
	var m := ShaderMaterial.new()
	m.shader = preload("res://tumbleweed.gdshader")
	m.set_shader_parameter(&"tex", preload("res://assets/textures/tumbleweed.png"))
	q.material = m
	q.custom_aabb = AABB(-Vector3.ONE * 0.7, Vector3.ONE * 1.4)   # 頂點在 shader 裡轉向鏡頭，扁的方形會被誤判看不到
	return q
