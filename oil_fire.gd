class_name OilFire
extends Node3D
## 燈油潑灑燃燒：油燈被打破，燈油潑到地上燒起來。
## 一灘不規則的油（幾瓣往不同方向潑開）在 SPREAD 秒內從中心往外擴散，火苗一簇簇跟著長出來；
## 燒 BURN 秒後火苗變小、熄滅，地上留一片燒焦的痕跡。站在火裡會一直扣血（只有主機算）。
## 範圍內的其他油燈也會被點燃（連鎖）。
## 外觀跟炸藥同一套：低面數、平面著色、硬邊（Explosive._blob），不用粒子貼圖。
## 各端各自播：形狀用位置當亂數種子，每台電腦燒出來一樣

const SPREAD := 2.5        # 秒：油潑開、火燒滿
const BURN := 12.0         # 秒：燒多久
const FADE := 2.0          # 秒：熄滅
const RADIUS := 2.2        # 公尺：最大半徑（最長那瓣）
const DPS := 20.0          # 站在火裡每秒扣多少（牛仔 150 血：站 7 秒多會死）
const TICK := 0.5          # 秒：多久扣一次
const FLAMES := 40         # 火苗幾簇
const SCORCH_KEEP := 30.0  # 秒：燒焦的痕跡留多久

var shooter: Node = null   # 誰打破的（燒死人算他的）

var _t := 0.0
var _tick := 0.0
var _lobes: Array[Vector2] = []   # 每一瓣：[方向角, 長度比例]
var _flames: Array[Node3D] = []
var _flame_at: Array[float] = []  # 每簇火苗離中心多遠（比例 0..1）：火燒到那裡才冒出來
var _light: OmniLight3D
var _scorch: MeshInstance3D
var _glow: MeshInstance3D
var _sound: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

static var _flame_mesh: Mesh
const FIRE := [Color(1.0, 0.45, 0.08), Color(1.0, 0.68, 0.18), Color(1.0, 0.85, 0.4)]


## 在 world 底下 at（地面上）點一灘火
static func spill(world: Node3D, at: Vector3, by: Node) -> OilFire:
	var f := OilFire.new()
	f.shooter = by
	world.add_child(f)
	f.global_position = at
	return f


func _ready() -> void:
	add_to_group(&"oil_fire")
	_rng.seed = hash(Vector3i(global_position.round()))   # 每台電腦同一個形狀
	# 油潑開的形狀：5 瓣，往不同方向、長短不一（潑出去像一灘，不是正圓）
	for i in 5:
		_lobes.append(Vector2(TAU * i / 5.0 + _rng.randf_range(-0.4, 0.4), _rng.randf_range(0.55, 1.0)))
	_make_scorch()
	_glow = _scorch.duplicate() as MeshInstance3D   # 燒著的油面：同一個形狀，fire_ground.gdshader 畫會流動的三階火
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://fire_ground.gdshader")
	_glow.material_override = gm
	_glow.position = Vector3.UP * 0.12   # 高一點：地上的草會蓋住
	add_child(_glow)
	for i in FLAMES:
		_add_flame(i)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.omni_range = RADIUS * 3.0
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 0.8
	add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = preload("res://assets/audio/weapons/fuse.wav")   # 引信的嘶嘶聲，降低音高當火燒的劈啪聲
	_sound.pitch_scale = 0.55
	_sound.unit_size = 6.0
	add_child(_sound)
	_sound.play()
	_sound.finished.connect(_loop_sound)


func _loop_sound() -> void:
	if _t < SPREAD + BURN:
		_sound.play()


## 這個方向上油潑到多遠（比例 0..1）：照最近的兩瓣內插，邊緣才會是波浪的
func _reach(angle: float) -> float:
	var best := 0.0
	for l in _lobes:
		var d := absf(wrapf(angle - l.x, -PI, PI))
		best = maxf(best, l.y * clampf(1.0 - d / 1.1, 0.0, 1.0))
	return maxf(best, 0.5)   # 每個方向至少潑 1.1 公尺：旁邊 1 公尺內的東西一定燒得到


func _make_scorch() -> void:
	# 地上燒焦的一片：照油潑開的形狀做一個扁平的多邊形，深褐色、半透明
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		st.set_color(Color(0, 0, 0))   # 頂點顏色 r：中心 0、邊緣 1（燃燒油面的著色器拿來算離中心多遠）
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 0, 0))
		st.add_vertex(Vector3(cos(a1), 0, sin(a1)) * _reach(a1) * RADIUS)
		st.add_vertex(Vector3(cos(a0), 0, sin(a0)) * _reach(a0) * RADIUS)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.06, 0.04, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scorch = MeshInstance3D.new()
	_scorch.mesh = st.commit()
	_scorch.material_override = m
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.position = Vector3.UP * 0.03
	_scorch.scale = Vector3(0.05, 1, 0.05)
	add_child(_scorch)


static func _tongue_mesh() -> Mesh:
	## 一條火舌：低面數的水滴形（5 邊、3 層），下面圓胖、往上收成尖，平面著色
	if _flame_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := [[0.0, 0.0], [0.12, 0.42], [0.35, 0.5], [0.65, 0.3], [1.0, 0.0]]   # [高度, 半徑]
		var n := 5
		for k in rings.size() - 1:
			var a: Array = rings[k]
			var b: Array = rings[k + 1]
			for i in n:
				var t0 := TAU * i / n + k * 0.4   # 每層轉一點：側面不是一條條直棱
				var t1 := TAU * (i + 1) / n + k * 0.4
				var u0 := TAU * i / n + (k + 1) * 0.4
				var u1 := TAU * (i + 1) / n + (k + 1) * 0.4
				var p00 := Vector3(cos(t0) * a[1], a[0], sin(t0) * a[1])
				var p01 := Vector3(cos(t1) * a[1], a[0], sin(t1) * a[1])
				var p10 := Vector3(cos(u0) * b[1], b[0], sin(u0) * b[1])
				var p11 := Vector3(cos(u1) * b[1], b[0], sin(u1) * b[1])
				st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
				st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
		st.generate_normals()
		_flame_mesh = st.commit()
	return _flame_mesh


func _add_flame(i: int) -> void:
	## 一簇火：外層橘、裡面一條小一點的黃，一直重生——從地上冒出、往上竄、拉長、縮掉，再換個位置冒（火在跳的樣子）
	var holder := Node3D.new()
	for layer in 2:
		var m := StandardMaterial3D.new()
		m.albedo_color = FIRE[0] if layer == 0 else FIRE[2]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi := MeshInstance3D.new()
		mi.mesh = _tongue_mesh()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if layer == 1:
			mi.scale = Vector3(0.55, 0.7, 0.55)
			mi.position = Vector3(0, 0.02, 0)
		holder.add_child(mi)
	holder.scale = Vector3.ZERO
	add_child(holder)
	_flames.append(holder)
	_flame_at.append(0.0)
	holder.set_meta(&"age", _rng.randf())   # 一開始錯開，不會一起跳
	_respawn(holder, i)


func _respawn(f: Node3D, i: int) -> void:
	## 換個位置重生：撒在油潑開的範圍裡（均勻撒在面積上），越靠中心越大越高
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf())
	var reach := _reach(a) * r
	f.position = Vector3(cos(a), 0, sin(a)) * reach * RADIUS
	f.rotation.y = _rng.randf() * TAU
	f.set_meta(&"r", reach)
	f.set_meta(&"life", _rng.randf_range(0.45, 0.9))
	f.set_meta(&"size", _rng.randf_range(0.18, 0.4) * (1.35 - 0.7 * r))
	f.set_meta(&"tall", _rng.randf_range(2.0, 3.6))
	f.set_meta(&"lean", Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)) + Vector3(Fx.WIND.x, 0, Fx.WIND.z) * 1.5)
	_flame_at[i] = reach


func _process(delta: float) -> void:
	_t += delta
	var spread := clampf(_t / SPREAD, 0.0, 1.0)
	spread = 1.0 - pow(1.0 - spread, 2.0)            # 一開始潑得快、後面慢下來
	var dying := clampf((_t - SPREAD - BURN) / FADE, 0.0, 1.0)
	var life := 1.0 - dying
	for i in _flames.size():
		var f := _flames[i]
		var age: float = f.get_meta(&"age") + delta / float(f.get_meta(&"life"))
		if age >= 1.0:
			age = 0.0
			_respawn(f, i)
		f.set_meta(&"age", age)
		# 火燒到這裡了沒（油往外潑的進度）；燒到了才冒，熄滅時一起變小
		var on := clampf((spread - _flame_at[i]) / 0.15, 0.0, 1.0) * life
		var s: float = f.get_meta(&"size") * on * sin(PI * age)            # 冒出來長大、再縮掉
		var tall: float = f.get_meta(&"tall") * (0.7 + 0.6 * age)          # 往上竄的時候越拉越長
		f.scale = Vector3(s, s * tall, s)
		f.position.y = s * tall * 0.25 * age                                # 整條往上飄一點
		var lean: Vector3 = f.get_meta(&"lean")
		f.rotation.x = lean.z * (0.5 + age)
		f.rotation.z = -lean.x * (0.5 + age)
	var sm := _scorch.material_override as StandardMaterial3D
	var sk := maxf(spread, 0.05)
	_scorch.scale = Vector3(sk, 1, sk)
	sm.albedo_color.a = 0.75 * minf(_t / 0.5, 1.0) * (1.0 - clampf((_t - SPREAD - BURN - FADE) / SCORCH_KEEP, 0.0, 1.0))
	_glow.scale = _scorch.scale
	(_glow.material_override as ShaderMaterial).set_shader_parameter(&"burn", life * minf(_t / 0.3, 1.0))
	_glow.visible = life > 0.0
	if life > 0.0 and fmod(_t, 0.06) < delta:
		_ember(spread)
	_light.light_energy = (1.6 + 0.5 * sin(_t * 13.0) + 0.3 * sin(_t * 31.0)) * spread * life
	if life > 0.0 and fmod(_t, 0.2) < delta:
		_smoke(spread)
	if life > 0.0:
		_ignite_nearby(spread * RADIUS)
		_tick += delta
		if _tick >= TICK:
			_tick = 0.0
			_burn(spread * RADIUS)
	if _t > SPREAD + BURN + FADE:
		_sound.stop()
		_light.visible = false
	if _t > SPREAD + BURN + FADE + SCORCH_KEEP:
		queue_free()


func _smoke(spread: float) -> void:
	# 黑煙：火上面一團團往上飄（跟炸藥的煙同一個樣子）
	var a := _rng.randf() * TAU
	var r := _rng.randf() * spread * RADIUS * 0.7
	var at := global_position + Vector3(cos(a) * r, 1.0, sin(a) * r)
	# 煙：半透明的灰褐低面數煙團，往上飄、變大、變淡（實心的會像一顆顆砲彈）
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.33, 0.29, 0.26, 0.55) if _rng.randf() < 0.5 else Color(0.42, 0.37, 0.33, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = _smoke_mesh()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = at
	mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
	mi.scale = Vector3.ONE * 0.2
	var up := Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(1.6, 2.4), _rng.randf_range(-0.2, 0.2)) + Fx.WIND * 3.0
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "global_position", at + up, 1.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * _rng.randf_range(0.7, 1.0), 1.8)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static var _smoke_m: Mesh
static func _smoke_mesh() -> Mesh:
	if _smoke_m == null:
		var sphere := SphereMesh.new()
		sphere.radial_segments = 6
		sphere.rings = 3
		var st := SurfaceTool.new()
		st.create_from(sphere, 0)
		st.deindex()
		st.generate_normals()
		_smoke_m = st.commit()
	return _smoke_m


func _ember(spread: float) -> void:
	# 火星：小小的亮黃碎塊，從火裡往上飄、左右飄、變小消失
	var a := _rng.randf() * TAU
	var r := _rng.randf() * spread * RADIUS * 0.8
	var at := global_position + Vector3(cos(a) * r, _rng.randf_range(0.2, 0.6), sin(a) * r)
	var m := StandardMaterial3D.new()
	m.albedo_color = FIRE[2] if _rng.randf() < 0.6 else FIRE[1]
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * 0.035
	mi.mesh = b
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = at
	mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
	var up := Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(1.2, 2.6), _rng.randf_range(-0.4, 0.4)) + Fx.WIND * 2.0
	var life := _rng.randf_range(0.6, 1.2)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "global_position", at + up, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.1, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## 在火的範圍裡嗎：水平距離照這個方向油潑到的地方算、高度 2 公尺內
func covers(p: Vector3, r: float, margin := 0.0) -> bool:
	var d := p - global_position
	if d.y < -0.5 or d.y > 2.0:
		return false
	var flat := Vector2(d.x, d.z)
	return flat.length() <= _reach(atan2(d.z, d.x)) * r + margin


func _burn(r: float) -> void:
	if not multiplayer.is_server():
		return   # 扣血只有主機算（跟子彈、炸藥一樣）
	var game := get_tree().get_first_node_in_group(&"match")
	if game == null:
		return
	for target: Node in game.players.get_children():
		if target.has_method(&"take_damage") and covers((target as Node3D).global_position, r):
			target.take_damage(int(round(DPS * TICK)), shooter if is_instance_valid(shooter) else null)


func _ignite_nearby(r: float) -> void:
	# 連鎖：火燒到的其他油燈也會破、潑出來（掛在高處的要火焰碰得到才算：2 公尺內）
	for l: Node in get_tree().get_nodes_in_group(&"oil_lantern"):
		if l.has_method(&"on_shot") and not l.broken and covers((l as Node3D).global_position, r, 0.15):   # 燈本身有 0.15 公尺寬
			l.on_shot((l as Node3D).global_position, shooter)
