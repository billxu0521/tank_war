class_name Fx
extends RefCounted
## 特效庫：一行叫得出來的一次性效果和場景氣氛。
## 純表演，不影響傷害判定，所以不需要同步——各端各自播。
## ponytail: 全部用 CPUParticles3D 程式建，沒有貼圖素材。要更細緻再換 GPUParticles3D + 貼圖

## 子彈打到的東西是什麼 → [顏色, 碎屑大小, 顆數, 速度, 多一團煙塵嗎]
const SURFACES := {
	&"dirt": [Color(0.42, 0.33, 0.22), 0.05, 14, 4.0, true],
	&"wood": [Color(0.62, 0.47, 0.3), 0.04, 10, 5.0, false],
	&"stone": [Color(0.6, 0.6, 0.58), 0.035, 10, 6.0, true],
	&"blood": [Color(0.55, 0.03, 0.03), 0.04, 16, 3.0, false],
}


static func burst(parent: Node3D, mesh: PrimitiveMesh, color: Color,
		pos: Vector3, from: Vector3, to: Vector3, secs: float) -> void:
	if parent == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	mi.position = pos
	mi.scale = from

	var t := mi.create_tween().set_parallel()
	t.tween_property(mi, "scale", to, secs)
	t.tween_property(mat, "albedo_color:a", 0.0, secs)
	t.chain().tween_callback(mi.queue_free)


## 著彈：沿著命中面噴碎屑（土、木屑、石屑、血），土和石頭多一小團煙塵
static func hit(world: Node, at: Vector3, normal: Vector3, surface: StringName) -> void:
	var s: Array = SURFACES.get(surface, SURFACES[&"wood"])
	var chips := _emitter(_box(s[1], s[0]), s[2], 0.6)
	chips.direction = normal
	chips.spread = 35.0
	chips.initial_velocity_min = s[3] * 0.4
	chips.initial_velocity_max = s[3]
	chips.gravity = Vector3(0, -12, 0)
	chips.scale_amount_min = 0.5
	_once(world, chips, at)
	if s[4]:
		puff(world, at + normal * 0.1, normal, Color(s[0].lightened(0.3), 0.6), 0.8, 0.25)


## 一團煙：往 forward 噴、變大、飄起來、散掉。槍口黑火藥煙、著彈煙塵都是這個
static func puff(world: Node, at: Vector3, forward: Vector3, color: Color,
		lifetime: float, size: float, amount := 8) -> void:
	var p := _emitter(_ball(size, color), amount, lifetime)
	p.explosiveness = 0.9
	p.direction = forward
	p.spread = 30.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.5
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = grow
	p.color_ramp = _fade(color)
	_once(world, p, at)


## 黑火藥的白煙（原本在 ShotFX 裡）
static func gun_smoke(world: Node, at: Vector3, forward: Vector3, lifetime := 1.2, size := 0.2) -> void:
	puff(world, at, forward, Color(0.7, 0.69, 0.66, 0.5), lifetime, size, 16)


## 煙囪一直冒的煙。回傳節點，要停掉就 queue_free
static func chimney(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var c := Color(0.55, 0.55, 0.55, 0.5)
	var p := _emitter(_ball(0.35, c), 24, 6.0)
	p.one_shot = false
	p.explosiveness = 0.0   # 一顆一顆接著冒，不是一陣一陣
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0.25, 0.1, 0)   # 一點點風，煙往同一邊斜
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 3.0))
	p.scale_amount_curve = grow
	p.color_ramp = _fade(c)
	parent.add_child(p)
	p.position = pos
	p.emitting = true
	return p


## 跟著玩家飄的氣氛：落葉 + 飛蟲。只在身邊一圈生，整張地圖一起生太貴。
## 粒子是世界座標，節點每幀搬到鏡頭位置，已經飄出來的不會跟著跑
static func drift(parent: Node) -> Node3D:
	var root := Node3D.new()
	var leaf := _box(0.08, Color(0.75, 0.62, 0.3), Vector3(1, 0.1, 0.6))
	# 從底下看是背光面，會變黑點。不吃光，逆光也看得出是葉子
	leaf.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var leaves := _emitter(leaf, 30, 8.0)
	leaves.one_shot = false
	leaves.explosiveness = 0.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(18, 2, 18)
	leaves.position.y = 8.0
	leaves.gravity = Vector3(0.6, -0.5, 0.2)   # 慢慢往下飄，順著風
	leaves.spread = 180.0
	leaves.initial_velocity_max = 0.5
	leaves.angular_velocity_min = -180.0
	leaves.angular_velocity_max = 180.0
	leaves.particle_flag_rotate_y = true
	root.add_child(leaves)
	var bugs := _emitter(_box(0.025, Color(0.1, 0.1, 0.08)), 20, 4.0)
	bugs.one_shot = false
	bugs.explosiveness = 0.0
	bugs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bugs.emission_box_extents = Vector3(10, 1, 10)
	bugs.position.y = 0.8
	bugs.gravity = Vector3.ZERO
	bugs.spread = 180.0
	bugs.initial_velocity_min = 0.3
	bugs.initial_velocity_max = 0.8
	bugs.tangential_accel_min = -2.0   # 繞圈亂飛，不是直線
	bugs.tangential_accel_max = 2.0
	root.add_child(bugs)
	parent.add_child(root)
	leaves.emitting = true
	bugs.emitting = true
	return root


# ---- 內部 ----

static func _emitter(mesh: Mesh, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# 粒子是世界座標的，一進場景就會噴。先關掉，擺好位置再開，
	# 不然整把會生在父節點原點而不是目標點
	p.emitting = false
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	# 全部同一瞬間噴出來。CPUParticles3D 叫 explosiveness，GPUParticles3D 才是 explosiveness_ratio
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## 噴一次、播完自己刪。用計時器訊號不用 await：節點被別人先砍掉（重開一局清場）時連線自己斷
static func _once(world: Node, p: CPUParticles3D, at: Vector3) -> void:
	if world == null:
		p.free()
		return
	p.emitting = false
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	world.get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)


static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true     # color_ramp 的透明度要靠這個才吃得到
	mat.albedo_color = Color(color, 1.0)
	mat.roughness = 1.0
	return mat


static func _box(size: float, color: Color, shape := Vector3.ONE) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = shape * size
	m.material = _mat(color)
	return m


static func _ball(size: float, color: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 8
	m.rings = 4
	m.material = _mat(color)
	return m


## 從原本的透明度淡到全透明
static func _fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, color.a))
	g.set_color(1, Color(1, 1, 1, 0))
	return g
