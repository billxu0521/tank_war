class_name FireballFx
## 火球的樣子：嘴裡蓄火、吐出去那一下、飛行中的火球和尾巴、命中的爆開。純表演，各台自己播，跟判定無關。
## 外觀跟炸藥同一套（Explosive.blob_mesh）：低面數、硬邊、不透明的色塊，不用模糊的光球。
## 全部不透明（除了衝擊環、焦痕、閃光各一片），顆數見各段；內建顯示卡也畫得動。
## 沒畫面的專用伺服器不跑（on = false）：呼叫的人先看 on。

static var on := DisplayServer.get_name() != "headless"

const CORE := Color(1.0, 0.92, 0.5)      # 最亮的芯
const FIRE := Color(1.0, 0.52, 0.1)      # 橘
const DEEP := Color(0.86, 0.2, 0.06)     # 外圈深紅
const SMOKE := Color(0.26, 0.22, 0.2)
const LIGHT := Color(1.0, 0.6, 0.25)
const FUSE := preload("res://assets/audio/weapons/fuse.wav")     # 嘶嘶聲，壓低音高當火燒的聲音（同 oil_fire.gd）
const LAUNCH := preload("res://assets/audio/weapons/launch.wav")
const BOOM := preload("res://assets/audio/weapons/boom.wav")
const SHAKE_RANGE := 30.0   # 公尺：離這麼遠鏡頭就不震

static var _mats := {}
static var _scorch_mesh: Mesh


## 不吃光的純色。bright 大於 1 會被畫面的光暈吃到（微微發亮）；hull = 只畫背面，套在外面變成一圈邊
static func _mat(c: Color, bright := 1.0, hull := false, ramp := false) -> StandardMaterial3D:
	var key := [c, bright, hull, ramp]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(c.r * bright, c.g * bright, c.b * bright)
		m.vertex_color_use_as_albedo = ramp   # 粒子的 color_ramp
		m.vertex_color_is_srgb = ramp
		if hull:
			m.cull_mode = BaseMaterial3D.CULL_FRONT
		_mats[key] = m
	return _mats[key]


static func _ball(parent: Node3D, c: Color, size: float, bright := 1.0, hull := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Explosive.blob_mesh()
	mi.material_override = _mat(c, bright, hull)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * size
	parent.add_child(mi)
	return mi


## 三層的火球（芯、橘邊、紅邊），外圈直徑 size 公尺。回傳根節點
static func _fire_ball(parent: Node3D, size: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.scale = Vector3.ONE * size
	_ball(root, CORE, 0.62, 1.5).name = &"Core"
	_ball(root, FIRE, 0.84, 1.0, true)
	_ball(root, DEEP, 1.0, 1.0, true)
	return root


## 一把不透明的小色塊粒子：從大縮到沒有（不淡出，不疊半透明）
static func _bits(mesh: Mesh, amount: int, life: float, colors: Array, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.mesh = mesh
	p.material_override = _mat(Color.WHITE, 1.0, false, true)
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.15, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(colors.size()).map(func(i: int) -> float: return float(i) / maxf(colors.size() - 1, 1.0)))
	g.colors = PackedColorArray(colors)
	p.color_ramp = g
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	return p


static func _spark_mesh() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


static func _light(parent: Node3D, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = LIGHT
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	parent.add_child(l)
	return l


static func _sound(parent: Node3D, stream: AudioStream, pitch: float, unit: float, db := 0.0) -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.pitch_scale = pitch
	s.unit_size = unit
	s.volume_db = db
	parent.add_child(s)
	s.play()
	return s


## 播完自己收掉的一次性節點
static func _later(n: Node, secs: float) -> void:
	n.get_tree().create_timer(secs).timeout.connect(n.queue_free)


## 先畫一遍：每種材質、網格、粒子、燈各生一個很小的在 at，一秒後收掉。
## 第一次用到的材質要現編著色器，量到第一顆火球起招那一幀會卡（見 tools/fireball_probe.gd）；尼諾拉一進場就先做掉
static func warm(world: Node3D, at: Vector3) -> void:
	if world == null:
		return
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = at
	root.scale = Vector3.ONE * 0.01
	_fire_ball(root, 1.0)
	for mesh: Mesh in [Explosive.blob_mesh(), _spark_mesh()]:
		var p := _bits(mesh, 2, 0.5, [CORE, FIRE], 1.0)
		root.add_child(p)
		p.emitting = true
	_light(root, 0.1, 1.0)
	_ring(world, at, Vector3.UP, 0.01, 0.02, 0.5, FIRE)
	_scorch(world, at, Vector3.UP, 0.01)
	Explosive._blob(world, at, FIRE, true, 0.005, 0.01, Vector3.ZERO, 0.5, 0.1)
	Explosive._blob(world, at, SMOKE, false, 0.005, 0.01, Vector3.ZERO, 0.5, 0.1)
	Fx.burst(world, SphereMesh.new(), Color(1, 1, 1, 0.5), at, Vector3.ONE * 0.01, Vector3.ONE * 0.02, 0.5)
	_later(root, 1.0)


# ---- 蓄火（前搖）----

## 嘴裡的火：掛在骨架的 bone 上（跟著頭動），secs 秒內從一點長到快要吐出去的大小，火星往裡吸。
## 回傳節點：吐出去或被打斷時 queue_free。粒子 16 顆
static func charge(skel: Skeleton3D, bone: String, offset: Vector3, size: float, secs: float) -> Node3D:
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	var root := Node3D.new()
	at.add_child(root)
	root.position = offset
	root.scale = Vector3.ONE / maxf(at.global_basis.get_scale().x, 0.001)
	var ball := _fire_ball(root, size * 0.05)
	var sparks := _bits(_spark_mesh(), 16, 0.35, [FIRE, CORE], 0.09 * size)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	sparks.emission_sphere_radius = 0.9 * size
	sparks.gravity = Vector3.ZERO
	sparks.radial_accel_min = -2.0 * 0.9 * size / (0.35 * 0.35)   # 生在球面上，剛好在壽命結束時吸到中心
	sparks.radial_accel_max = sparks.radial_accel_min
	sparks.local_coords = true
	root.add_child(sparks)
	sparks.emitting = true
	var l := _light(root, 0.0, 9.0 * size)
	var t := root.create_tween().set_parallel()
	t.tween_property(ball, "scale", Vector3.ONE * size * 0.6, secs).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)   # 嘴巴裝不下整顆：長到六成，越後面脹越快
	t.tween_property(l, "light_energy", 2.5, secs)
	var wob := ball.create_tween().set_loops()   # 一脹一縮地抖，越來越急的感覺靠上面的長大
	wob.tween_property(ball.get_node(^"Core"), "scale", Vector3.ONE * 0.72, 0.06)
	wob.tween_property(ball.get_node(^"Core"), "scale", Vector3.ONE * 0.56, 0.06)
	_sound(root, FUSE, 0.8, 8.0)
	return at


# ---- 吐出去那一下 ----

## 嘴前一圈往外擴的火環、往前噴的幾團火、閃光、聲音；附近的人鏡頭震一下。色塊 5 團
static func launch(world: Node3D, at: Vector3, dir: Vector3, size: float) -> void:
	_ring(world, at, dir, size * 0.5, size * 2.0, 0.22, FIRE)
	for k in 5:
		var side := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5
		Explosive._blob(world, at, [FIRE, CORE][k % 2], true, size * 0.15, size * randf_range(0.2, 0.32),
			(dir * randf_range(1.5, 3.0) + side) * size, 0.16, 0.1)
	var l := _light(world, 4.0, 12.0 * size)
	l.global_position = at
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.25)
	t.tween_callback(l.queue_free)
	var s := _sound(world, LAUNCH, 0.55, 14.0, 3.0)
	s.global_position = at
	s.finished.connect(s.queue_free)
	Fx.shake(world, at, 0.05, SHAKE_RANGE)


## 面向 dir 的一圈環，從 r0 擴到 r1 公尺同時淡掉（同 Explosive._ground_ring 的做法）
static func _ring(world: Node3D, at: Vector3, dir: Vector3, r0: float, r1: float, secs: float, c: Color) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 1.0
	ring.rings = 14
	ring.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = at
	mi.quaternion = Quaternion(Vector3.UP, dir.normalized()) if dir.normalized().dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	mi.scale = Vector3(r0, 0.3, r0)
	var t := mi.create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3(r1, 0.3, r1), secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(m, "albedo_color:a", 0.0, secs).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(mi.queue_free)


# ---- 飛行 ----

## 飛行中的火球，掛在 ball 底下、叫 Look。size = 外圈直徑（公尺）。尾巴的粒子是世界座標：火舌 22、煙 8、火星 12 顆
static func flight(ball: Node3D, size: float) -> Node3D:
	var look := Node3D.new()
	look.name = &"Look"
	look.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # 自己每幀擺（fireball.gd 的 _process）；父節點照常補幀
	ball.add_child(look)
	_fire_ball(look, size).name = &"Ball"
	var flame := _bits(Explosive.blob_mesh(), 22, 0.38, [CORE.lerp(FIRE, 0.5), FIRE, DEEP], 0.8 * size)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.18
	flame.spread = 180.0
	flame.initial_velocity_min = 0.5
	flame.initial_velocity_max = 2.0
	flame.gravity = Vector3(0, 2.5, 0)
	var smoke := _bits(Explosive.blob_mesh(), 8, 0.9, [SMOKE, SMOKE.lightened(0.25)], 0.5 * size)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.3
	smoke.spread = 180.0
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0, 3.0, 0) + Fx.WIND * 4.0
	var sparks := _bits(_spark_mesh(), 12, 0.5, [CORE, FIRE], 0.13 * size)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.gravity = Vector3(0, -9.0, 0)
	for p: CPUParticles3D in [flame, smoke, sparks]:
		look.add_child(p)
		p.emitting = true
	_light(look, 2.0, 7.0).name = &"Light"
	var s := _sound(look, FUSE, 0.5, 12.0, 2.0)
	s.finished.connect(s.play)   # 飛行中一直燒
	return look


## 火球沒了：尾巴留在原地燒完（不跟著一起突然消失），其他的收掉
static func release(look: Node3D, world: Node3D) -> void:
	for p: Node in look.get_children():
		if p is CPUParticles3D:
			p.reparent(world)
			(p as CPUParticles3D).emitting = false
			_later(p, (p as CPUParticles3D).lifetime)


# ---- 命中 ----

## 爆開：白光一閃 → 火團往外脹 → 幾團黑煙往上（很快縮掉，不擋住視線）＋ 四濺的火星、貼著命中面的衝擊環、閃光、聲音、鏡頭震；
## 打在地上留一片焦痕。色塊：火 7、煙 4；火星 18 顆
static func impact(world: Node3D, at: Vector3, normal: Vector3, size: float, scorch: bool) -> void:
	var r := size * 0.5
	var out := at + normal * r * 0.3
	Fx.burst(world, SphereMesh.new(), Color(1.0, 0.96, 0.82, 1.0), out, Vector3.ONE * r * 0.8, Vector3.ONE * r * 2.4, 0.07)
	for k in 7:
		var off := (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) + normal * 0.8).normalized()
		Explosive._blob(world, out + off * r * 0.4, [FIRE, CORE, DEEP][k % 3], true, r * 0.35, r * randf_range(0.6, 1.0),
			off * r * 1.8, 0.24, 0.14)
	for k in 4:
		var off := Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)) * r * 0.7
		var rr := r * randf_range(0.3, 0.45)
		Explosive._blob(world, out + off, [SMOKE, SMOKE.lightened(0.15)][k % 2], false, rr * 0.5, rr * 1.4,
			Vector3(randf_range(-0.5, 0.5), randf_range(3.5, 5.0), randf_range(-0.5, 0.5)), 0.9, 0.5)   # 要往上竄成一根煙柱，不然像地上一堆黑石頭
	var sparks := _bits(_spark_mesh(), 18, 0.8, [CORE, FIRE, DEEP], 0.16 * size)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = normal
	sparks.spread = 70.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 13.0
	sparks.gravity = Vector3(0, -18.0, 0)
	world.add_child(sparks)
	sparks.global_position = out
	sparks.emitting = true
	_later(sparks, 0.9)
	_ring(world, at + normal * 0.15, normal, r * 0.6, size * 1.8, 0.35, FIRE)
	var l := _light(world, 5.0, 10.0 * size)
	l.global_position = out + normal
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.35)
	t.tween_callback(l.queue_free)
	var s := _sound(world, BOOM, 1.5, 12.0)   # 炸藥的爆炸聲拉高音高：比較短、比較小顆
	s.global_position = at
	s.finished.connect(s.queue_free)
	Fx.shake(world, at, 0.08, SHAKE_RANGE)
	if scorch:
		_scorch(world, at, normal, size)


## 飛到底自己熄掉：一小團火縮掉、冒一點煙
static func fizzle(world: Node3D, at: Vector3, size: float) -> void:
	for k in 3:
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * size * 0.2
		Explosive._blob(world, at + off, [FIRE, SMOKE, DEEP][k], k != 1, size * 0.25, size * 0.4, off + Vector3.UP * (1.5 if k == 1 else 0.3), 0.3, 0.3)


## 地上的焦痕：一片不規則的深色，留 SCORCH_KEEP 秒，最後 3 秒淡掉
const SCORCH_KEEP := 14.0
static func _scorch(world: Node3D, at: Vector3, normal: Vector3, size: float) -> void:
	if _scorch_mesh == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 11
		var rim := PackedVector3Array()
		for i in n:
			var a := TAU * i / n
			rim.append(Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.0))
		for i in n:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(rim[(i + 1) % n])
			st.add_vertex(rim[i])
		_scorch_mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.16, 0.12, 0.1, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _scorch_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = at + normal * 0.08
	mi.quaternion = Quaternion(Vector3.UP, normal) * Quaternion(Vector3.UP, randf() * TAU)
	mi.scale = Vector3.ONE * size * 0.9
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", 0.5, 0.1)
	t.tween_interval(SCORCH_KEEP - 3.1)
	t.tween_property(m, "albedo_color:a", 0.0, 3.0)
	t.tween_callback(mi.queue_free)
