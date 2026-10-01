class_name Fx
extends RefCounted
## 特效庫：一行叫得出來的一次性效果和場景氣氛。
## 純表演，不影響傷害判定，所以不需要同步——各端各自播。
## 全部用 CPUParticles3D 程式建。煙是一張柔邊的煙團貼圖（tools/make_smoke_card.py），碎屑是小方塊

const WIND := Vector3(0.3, 0.1, 0.08)   # 全場同一個風向：煙囪、槍口煙都往這邊飄

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
	var p := _emitter(_card(size, color), amount, lifetime)   # 全部同時噴（見 gun_smoke：分批噴會閃黑）
	_spin(p)
	p.direction = forward
	p.spread = 30.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.5
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _grow(0.3, 1.0)
	p.color_ramp = _fade(color)
	_once(world, p, at)


## 黑火藥的白煙，照 Hunt 分兩段。amount 是這把槍的煙量（Weapon.smoke，左輪 = 1）：
##   一、往前噴的一股：很快、半秒內停住
##   二、停在槍口前面的一團：慢慢變大、順著風飄走，留好幾秒——遠處的人看得出「那邊有人開槍」
static func gun_smoke(world: Node, at: Vector3, forward: Vector3, amount := 1.0) -> void:
	var c := Color(0.8, 0.79, 0.76, 0.75)
	var jet := _emitter(_card(0.17 * amount, c), 12, 0.6)
	jet.direction = forward
	jet.spread = 6.0
	jet.initial_velocity_min = 5.0
	jet.initial_velocity_max = 10.0 * amount
	jet.damping_min = 18.0
	jet.damping_max = 24.0
	jet.gravity = Vector3.ZERO
	jet.scale_amount_curve = _grow(0.4, 1.6)
	jet.color_ramp = _fade(c)
	_spin(jet)
	_once(world, jet, at)

	var cloud := _emitter(_card(0.4 * amount, c), 20, (2.5 + amount) * 1.5 - 1.0)   # 左輪約 4 秒、散彈槍約 5 秒散掉
	# 不能設成小於 1（分批噴）：還沒輪到噴的煙片會被畫成黑色，開槍瞬間槍口前一團黑閃
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 0.25 * amount
	cloud.direction = forward
	cloud.spread = 50.0
	cloud.initial_velocity_min = 0.3
	cloud.initial_velocity_max = 1.0 * amount
	cloud.damping_min = 0.5
	cloud.damping_max = 1.0
	cloud.gravity = WIND
	cloud.scale_amount_min = 0.7
	cloud.scale_amount_curve = _grow(0.5, 2.4)
	# 一出來很快變濃，之後慢慢淡掉。點要一次整組給：新的 Gradient 自帶黑白兩點，
	# 用 add_point 插進去順序會亂，前幾格取到黑色，煙團一出來整團是黑的
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.05, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	cloud.color_ramp = g
	_spin(cloud)
	_once(world, cloud, at + forward * (0.5 + 0.3 * amount))


## 塵土：大東西（恐龍）踩地、出招揚起的一團土。dir 是往哪邊噴（腳步是往後上方），size 是一片多大
const DUST := Color(0.63, 0.5, 0.36, 0.55)   # 跟沙土路（main.gd 的 DIRT）同色系、亮一點
static func dust(world: Node, at: Vector3, dir: Vector3, size := 0.7, amount := 6, speed := 2.5, life := 1.6) -> void:
	var p := _emitter(_card(size, DUST), amount, life)
	_spin(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.6
	p.direction = dir
	p.spread = 40.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.gravity = WIND + Vector3(0, 0.15, 0)   # 慢慢飄起來、順著風散掉
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _grow(0.4, 1.8)
	p.color_ramp = _fade(DUST)
	_once(world, p, at)


## 一圈往外推開的塵土（甩尾掃地、重摔、跺地的震波）
static func dust_ring(world: Node, at: Vector3, radius: float, amount := 24, speed := 7.0, size := 0.9) -> void:
	var p := _emitter(_card(size, DUST), amount, 1.8)
	_spin(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.6
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.radial_accel_min = speed     # 從圈的中心往外推
	p.radial_accel_max = speed * 1.5
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.gravity = WIND
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _grow(0.5, 2.0)
	p.color_ramp = _fade(DUST)
	_once(world, p, at)


## 煙囪一直冒的煙。回傳節點，要停掉就 queue_free
static func chimney(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var c := Color(0.55, 0.55, 0.55, 0.5)
	var p := _emitter(_card(0.35, c), 24, 6.0)
	_spin(p)
	p.one_shot = false
	p.explosiveness = 0.0   # 一顆一顆接著冒，不是一陣一陣
	p.preprocess = p.lifetime   # 一出現就是冒了一陣子的樣子：還沒冒出來的煙片會畫成黑色
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.2
	p.gravity = WIND   # 一點點風，煙往同一邊斜
	p.scale_amount_curve = _grow(0.5, 3.0)
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


## 一片煙：永遠面向鏡頭的方形，貼柔邊的煙團圖。size 是看起來的半徑（圖的邊緣是透明的，方形要大一點）。
## 碰到地面、牆會淡掉（proximity fade），不會切出一條硬邊
static var _smoke_tex: Texture2D

static func _card(size: float, color: Color) -> QuadMesh:
	if _smoke_tex == null:
		_smoke_tex = load("res://assets/textures/smoke_card.png")
	var mat := _mat(color)
	mat.albedo_texture = _smoke_tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true   # 槍和手的影子落在煙上，槍口那股會整團變黑
	# 煙片永遠朝著鏡頭，逆光時朝鏡頭那面是背光面，整團發黑。讓光透過來（跟樹葉一樣），逆光的煙反而是亮的
	mat.backlight_enabled = true
	mat.backlight = Color(0.8, 0.8, 0.8)
	var m := QuadMesh.new()
	m.size = Vector2.ONE * size * 2.6
	m.material = mat
	return m


## 每片轉個隨機角度、慢慢自轉，同一張圖疊起來才不像複製貼上
static func _spin(p: CPUParticles3D) -> void:
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0


## 大小從 a 倍長到 b 倍
static func _grow(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(b, 1.0)
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c


## 從原本的透明度淡到全透明
static func _fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, color.a))
	g.set_color(1, Color(1, 1, 1, 0))
	return g
