class_name Terrain
extends RefCounted
## 起伏的地形：柏林雜訊的丘陵，加上幾塊整平的地（農莊、撤離區、沙盒靶場）。
##
## 所有東西擺在地上都問 height(x, z)——建築、樹、柵欄、出生點、蛋。
## 畫面（ArrayMesh）和碰撞（HeightMapShape3D）用同一份高度格點，兩邊一定對得上。
##
## ponytail: 雜訊用固定 seed，每台機器算出來的地形一樣（場地不走網路同步）。
## 兩塊平地靠得近、高度又差很多，中間一定是陡坡（實測 48 度），怎麼平均都救不了——
## 所以蓋之前先 settle()：太近的兩塊把高度往中間拉。
## 要做河道、懸崖再加新的區塊種類。

const AMP := 9.0          # 丘陵起伏大約正負這麼多公尺。圍牆 40 要高過「9 + 最高屋頂 22 + 恐龍跳 6.5」
const FREQ := 0.010       # 越小丘陵越寬。0.010 ≈ 一座丘陵一百公尺寬；最陡的坡要在 40 度內（測試會量）
const EDGE_FADE := 30.0   # 離圍牆這麼近開始降回 0，山崖底部才接得上
## 整平區邊緣接回丘陵的過渡寬度。smoothstep 最陡處的斜率是 1.5 × 高低差 / 寬度，
## 實測平地和旁邊丘陵最多差 10 公尺以上（靶場 -4.6、旁邊丘陵 5.9），要 30 公尺才壓得在 40 度內
const PAD_FALL := 30.0

var size := 320.0
var cell := 2.0
var _noise := FastNoiseLite.new()
## 整平區：{"rect": Rect2, "h": 目標高度, "fall": 邊緣過渡寬度}。圓形的用外接方形 + 圓距離
var _pads: Array[Dictionary] = []


func _init(arena_size: float, seed_value: int) -> void:
	size = arena_size
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = FREQ
	_noise.fractal_octaves = 3


## 還沒整平的原始地形
func raw(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * AMP * 1.6   # 雜訊實際大多落在 ±0.6，放大一點才看得出起伏
	var to_edge := size * 0.5 - maxf(absf(x), absf(z))
	return clampf(h, -AMP, AMP) * smoothstep(0.0, EDGE_FADE, to_edge)


## 這一點的地面高度（整平區已經算進去）
func height(x: float, z: float) -> float:
	var h := raw(x, z)
	# 平均時權重取 4 次方：站在某塊平地正中央（權重 1）就幾乎只聽它的，
	# 旁邊那塊的過渡帶（權重 0.5 → 0.06）插不太進來；兩塊之間照樣平順接起來。
	# 兩塊平地本身的高度已經在 settle() 裡拉近過，中間不會擠出陡坡
	var wmax := 0.0
	var wsum := 0.0
	var hsum := 0.0
	for p: Dictionary in _pads:
		var w := _pad_weight(p, x, z)
		var k := pow(w, 4.0)
		wmax = maxf(wmax, w)
		wsum += k
		hsum += k * float(p["h"])
	if wsum <= 0.0:
		return h
	return lerpf(h, hsum / wsum, wmax)


## 圓形整平區（農莊、撤離區）：半徑內全平，往外 PAD_FALL 公尺慢慢接回丘陵。
## 目標高度取中心的原始高度，所以農莊蓋在哪就是哪的高度，不會全部壓到 0
func flatten_circle(center: Vector2, radius: float) -> void:
	_pads.append({"c": center, "r": radius, "fall": PAD_FALL, "h": raw(center.x, center.y)})


## 方形整平區（沙盒靶場：靶的距離要準，地要平）
func flatten_rect(rect: Rect2) -> void:
	var c := rect.get_center()
	_pads.append({"rect": rect, "fall": PAD_FALL, "h": raw(c.x, c.y)})


## 所有整平區加完之後、蓋地形之前呼叫：兩塊平地的高度差不能超過它們之間距離的 SETTLE_RATIO 倍，
## 超過就把兩邊往中間拉。重疊的兩塊會被拉成一樣高。重複幾輪直到大家都滿足
const SETTLE_RATIO := 0.35   # ≈ 20 度；過渡是 smoothstep，最陡處再乘 1.5 還在 30 度內
func settle() -> void:
	for it in 30:
		var moved := false
		for i in _pads.size():
			for j in range(i + 1, _pads.size()):
				var a: Dictionary = _pads[i]
				var b: Dictionary = _pads[j]
				var limit := maxf(_gap(a, b), 0.0) * SETTLE_RATIO
				var dh: float = b["h"] - a["h"]
				if absf(dh) > limit + 0.01:
					var fix := (absf(dh) - limit) * 0.5 * signf(dh)
					a["h"] += fix
					b["h"] -= fix
					moved = true
		if not moved:
			return


## 兩塊平地的「平的部分」之間隔多遠（重疊就是負的）
func _gap(a: Dictionary, b: Dictionary) -> float:
	if a.has("rect") and b.has("rect"):
		return 0.0   # ponytail: 目前只有一塊方的（靶場），兩塊方的出現再補
	if a.has("rect") or b.has("rect"):
		var r: Rect2 = (a if a.has("rect") else b)["rect"]
		var c: Dictionary = b if a.has("rect") else a
		var p: Vector2 = c["c"]
		var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
		return Vector2(dx, dz).length() - float(c["r"])
	return (a["c"] as Vector2).distance_to(b["c"]) - float(a["r"]) - float(b["r"])


func _pad_weight(p: Dictionary, x: float, z: float) -> float:
	var d := 0.0
	if p.has("rect"):
		var r: Rect2 = p["rect"]
		var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		d = Vector2(dx, dz).length()
	else:
		d = maxf(Vector2(x, z).distance_to(p["c"]) - p["r"], 0.0)
	return 1.0 - smoothstep(0.0, p["fall"], d)


## 坡度（0 平地 .. 1 垂直），顏色用：陡的地方露土
func slope(x: float, z: float) -> float:
	var dx := height(x + 1.0, z) - height(x - 1.0, z)
	var dz := height(x, z + 1.0) - height(x, z - 1.0)
	var n := Vector3(-dx, 2.0, -dz).normalized()
	return 1.0 - n.y


## 蓋出地面：畫面是頂點上色的 ArrayMesh，碰撞是同一份格點的 HeightMapShape3D。
## color_at(x, z, h) -> Color 由呼叫的人決定（路、麥田、草地）
func build(color_at: Callable) -> StaticBody3D:
	var n := int(size / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = height(-size * 0.5 + ix * cell, -size * 0.5 + iz * cell)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n:
		for ix in n:
			var x := -size * 0.5 + ix * cell
			var z := -size * 0.5 + iz * cell
			var h := heights[iz * n + ix]
			st.set_color(color_at.call(x, z, h))
			st.add_vertex(Vector3(x, h, z))
	for iz in n - 1:
		for ix in n - 1:
			var i := iz * n + ix
			# 逆時針（從上往下看）才是朝上的面
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true   # 不設的話顏色被當成線性，整片地會被洗成淡土黃
	mat.roughness = 0.95
	st.set_material(mat)

	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	body.add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	# 高度圖一格是 1 單位，放大成 cell 公尺。中心在原點，跟畫面的格點一模一樣
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	return body
