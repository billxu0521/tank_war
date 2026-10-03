class_name FarLand
extends RefCounted
## 遠景：場地外面一圈延伸出去的地面（路也一直延伸到地平線）、零星的樹、遠處的平頂山和石柱。
## 全部沒有碰撞——場邊有看不見的牆擋著，邊上一圈柵欄讓人看得出邊界在哪。
##
## 地面跟場地的地形共用邊上那排格點（高度、顏色都用同一個函式算），接縫不會裂開。
## ponytail: 固定 seed，每台機器蓋出來的遠景一樣（場地不走網路同步）。

const REACH := 1500.0      # 地面鋪到多遠（相機最遠看 4000）
const FINE := 120.0        # 場邊這個範圍內用 2 公尺的格子（跟地形一樣），外面越遠格子越大
const OUTER: Array[float] = [150.0, 200.0, 270.0, 360.0, 480.0, 640.0, 850.0, 1100.0, 1500.0]
# 平頂山的顏色（sRGB）：紅褐的岩石，越遠越往 HAZE（天邊的灰紫）靠——參考圖遠山那種一層層變淡的剪影。
# 平頂山不吃霧（霧會把它洗成一片淡粉，看起來像方塊房子），遠近的淡化直接算在顏色裡
const CLIFF := Color(0.36, 0.23, 0.22)
const TALUS := Color(0.40, 0.26, 0.23)
const TOP := Color(0.42, 0.28, 0.24)
const TO_SUN := Vector3(0.88, 0.208, -0.43)   # main.tscn 的 Sun 往太陽的方向（改了太陽要跟著改）
const WARM := Color(0.66, 0.36, 0.26)   # 受光面偏過去的暖橘
const HAZE := Color(0.42, 0.29, 0.29)   # 跟霧的顏色（main.tscn fog_light_color）幾乎一樣：地面和山在天邊收成同一個顏色


## 蓋出整個遠景，回傳一個節點掛到場地上。trees 是 [Mesh...]（撒在場外的樹），fence 是一段柵欄的 Mesh
static func build(t: Terrain, color_at: Callable, trees: Array, fence: Mesh, fence_seg: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FarLand"
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930
	var noise := FastNoiseLite.new()
	noise.seed = 20260930
	noise.frequency = 0.004
	var half := t.size * 0.5
	root.add_child(_ground(t, color_at, noise, half))
	root.add_child(_mesas(t, noise, half, rng))
	for i in trees.size():
		root.add_child(_scatter(trees[i], _tree_spots(t, noise, half, rng, 40), false))
	root.add_child(_scatter(fence, _fence_spots(t, half - 1.5, fence_seg), true))
	return root


## 場外的高度：貼著場邊的高度，往外 40 公尺內慢慢接成緩緩起伏、越遠越高一點的丘陵
static func far_height(t: Terrain, noise: FastNoiseLite, half: float, x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z)) - half
	if d <= 0.0:
		return t.height(x, z)
	var edge := t.height(clampf(x, -half, half), clampf(z, -half, half))
	var hills := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 18.0 * clampf(d / 150.0, 0.0, 1.0) \
		+ 25.0 * smoothstep(200.0, REACH, d)
	return lerpf(edge, hills, smoothstep(0.0, 40.0, d))


static func _axis(half: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for v in OUTER:
		a.append(-v)
	var x := -FINE
	while x <= FINE + 0.01:
		a.append(x)
		x += 2.0
	for v in OUTER:
		a.append(v)
	a.sort()
	return a


static func _ground(t: Terrain, color_at: Callable, noise: FastNoiseLite, half: float) -> MeshInstance3D:
	var ax := _axis(half)
	var n := ax.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n:
		for ix in n:
			var x := ax[ix]
			var z := ax[iz]
			var h := far_height(t, noise, half, x, z)
			st.set_color(color_at.call(x, z, clampf(h, -Terrain.AMP, Terrain.AMP)))
			st.add_vertex(Vector3(x, h, z))
	for iz in n - 1:
		for ix in n - 1:
			# 場地裡面那塊是地形自己畫的，跳過
			if ax[ix] >= -half - 0.01 and ax[ix + 1] <= half + 0.01 and ax[iz] >= -half - 0.01 and ax[iz + 1] <= half + 0.01:
				continue
			var i := iz * n + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 平頂山：幾圈多邊形往上疊——山腳的碎石坡、直直的崖壁、平頂；大的上面再疊一小塊。
## 也有細高的石柱。平面著色、roughness 0.75（描線只畫天際線的記號，見 outline.gdshader）
static func _mesas(t: Terrain, noise: FastNoiseLite, half: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 46:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(480.0, 1350.0)
		var c := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		c.y = far_height(t, noise, half, c.x, c.z) - 4.0
		var k := dist / 1000.0          # 遠的大一點，才不會越遠越小到看不見
		_fade = lerpf(0.45, 0.8, inverse_lerp(480.0, 1350.0, dist))
		if rng.randf() < 0.2:           # 石柱
			_mesa(st, c, rng.randf_range(14, 30) * k, rng.randf_range(90, 170) * k, rng, 5)
		else:
			var r := rng.randf_range(80, 240) * k   # 寬、矮：平頂山是桌子，不是柱子
			var h := rng.randf_range(40, 100) * k
			_mesa(st, c, r, h, rng, rng.randi_range(5, 7))
			if rng.randf() < 0.5:       # 上面再疊一塊小的，輪廓才有一階一階
				var o := Vector3(rng.randf_range(-0.3, 0.3) * r, h - 2.0, rng.randf_range(-0.3, 0.3) * r)
				_mesa(st, c + o, r * rng.randf_range(0.3, 0.5), h * rng.randf_range(0.35, 0.7), rng, 7, false)
	_ridge(st, rng)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.75
	mat.metallic_specular = 0.0
	mat.disable_fog = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _fade := 0.0   # 現在蓋的這座往 HAZE 靠多少


## 一座：每圈 [高度比例, 半徑比例, 顏色]。talus=false 就沒有山腳碎石坡（疊在上面的那塊）
static func _mesa(st: SurfaceTool, c: Vector3, r: float, h: float, rng: RandomNumberGenerator, sides: int, talus := true) -> void:
	var rings := [[0.0, 1.45, TALUS], [0.32, 1.0, TALUS], [0.36, 0.95, CLIFF], [1.0, 0.88, CLIFF]] if talus \
		else [[0.0, 1.0, CLIFF], [1.0, 0.9, CLIFF]]
	var jit: Array[float] = []
	var a0 := rng.randf() * TAU
	for s in sides:
		jit.append(rng.randf_range(0.7, 1.3))
	var pts: Array = []   # 每圈的點
	for ring: Array in rings:
		var row: Array[Vector3] = []
		for s in sides:
			var a := a0 + s * TAU / sides
			var rr: float = r * ring[1] * jit[s]
			row.append(c + Vector3(cos(a) * rr, h * ring[0], sin(a) * rr))
		pts.append(row)
	for j in rings.size() - 1:
		var col: Color = rings[j + 1][2]
		for s in sides:
			var s2 := (s + 1) % sides
			var a: Vector3 = pts[j][s]
			var b: Vector3 = pts[j][s2]
			var cc: Vector3 = pts[j + 1][s2]
			var d: Vector3 = pts[j + 1][s]
			_tri(st, col, a, b, cc)   # Godot 的正面是順時針（跟 terrain.gd 的格子同一個方向）
			_tri(st, col, a, cc, d)
	var top: Array = pts[rings.size() - 1]
	var mid := c + Vector3(0, h, 0)
	for s in sides:
		_tri(st, TOP, mid, top[s], top[(s + 1) % sides])


## 最遠的一圈山脊：繞一整圈、一段一段平頂（高度一階一階跳），最淡。地平線才不會在平頂山之間空出來
static func _ridge(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	_fade = 0.85
	var n := 90
	var dist := 1480.0
	var h := 60.0
	var prev_top := Vector3.ZERO
	var prev_bot := Vector3.ZERO
	for i in n + 1:
		if i % 3 == 0:
			h = rng.randf_range(35.0, 110.0)
		var a := i * TAU / n
		var r := dist + rng.randf_range(-60.0, 60.0)
		var bot := Vector3(cos(a) * r, 20.0, sin(a) * r)
		var top := Vector3(cos(a) * (r + 30.0), 20.0 + h, sin(a) * (r + 30.0))
		if i > 0:
			_tri(st, CLIFF, prev_bot, top, bot)          # 朝內（朝場地），跟平頂山的面方向相反
			_tri(st, CLIFF, prev_bot, prev_top, top)
		prev_top = top
		prev_bot = bot


static func _tri(st: SurfaceTool, col: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	# 每個三角形自己的三個點：沒有共用頂點，generate_normals 出來就是平面著色
	# 平頂山不吃燈光（unshaded）：明暗自己算，朝太陽的面亮、背面最多暗兩成——遠山靠變淡表現距離，不靠明暗
	var n := (b - a).cross(c - a).normalized() * -1.0
	var lit := clampf(n.dot(TO_SUN) * 1.5, 0.0, 1.0)
	col = (col * lerpf(0.88, 1.05, lit)).lerp(WARM, lit * 0.25)   # 受光面亮一點、往橘偏；背光面留在灰紫
	col = col.lerp(HAZE, _fade)
	col.a = 1.0
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


## 場外零星的樹：離場邊 10~350 公尺，近的密一點
static func _tree_spots(t: Terrain, noise: FastNoiseLite, half: float, rng: RandomNumberGenerator, count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	while out.size() < count:
		var x := rng.randf_range(-half - 350.0, half + 350.0)
		var z := rng.randf_range(-half - 350.0, half + 350.0)
		var d := maxf(absf(x), absf(z)) - half
		if d < 10.0 or rng.randf() > 1.0 - d / 450.0:
			continue
		var s := rng.randf_range(0.8, 1.3)
		out.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s),
			Vector3(x, far_height(t, noise, half, x, z) - 0.2, z)))
	return out


## 場邊一圈柵欄（只有外觀）：一段一段沿著四邊排
static func _fence_spots(t: Terrain, at: float, seg: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var n := int(at * 2.0 / seg)
	var step := at * 2.0 / n
	for side in 4:
		var yaw: float = [0.0, PI * 0.5, PI, -PI * 0.5][side]
		for k in n:
			var u := -at + (k + 0.5) * step
			var p: Vector2 = [Vector2(u, at), Vector2(at, -u), Vector2(-u, -at), Vector2(-at, u)][side]
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(step / seg, 1, 1))
			out.append(Transform3D(b, Vector3(p.x, t.fast_height(p.x, p.y), p.y)))
	return out


static func _scatter(mesh: Mesh, pts: Array[Transform3D], shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
