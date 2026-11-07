class_name Greybox
extends RefCounted
## 灰盒（素模）：灰色方塊拼的房子和掩體，先專心調玩法（docs/規劃/2026-10-19-灰盒地圖.md）。
## 遊戲（arena_map.gd 的 _build_level）和編輯器預覽（LevelPreview）共用：回傳一個 StaticBody3D，
## 裡面是合併好的一個網格＋每一塊各自的碰撞。原點在地面中央，正面朝 +Z。

const T := 0.3                 # 牆厚
const BURY := 1.0              # 牆和地板往地下多埋這麼深：蓋在斜坡上時，低的那邊才不會露縫
const DOOR := Vector2(1.4, 2.3)   # 一般門（寬、高）：恐龍擠不進來（尼諾拉放大後半徑 BODY_RADIUS 3.56，放大前 2.4）
static var BIG_DOOR: Vector2 = Vector2(6.0, 8.5) * (Balance.num("dino_height") / 8.1)   # 大門：恐龍走得進來（照尼諾拉身高放大，放大前高 8.5；boss.gd 的 GROW）
const WINDOW := Vector3(1.2, 1.0, 2.1)   # 寬、窗台高、窗頂高。窗台 1 公尺在翻越範圍（0.4～1.5）內
const RAMP_W := 1.4            # 上樓的斜坡：貼著左牆，從前面往後爬
const RAMP_DEG := 30.0
const SLAB := 0.2              # 樓板厚
const FLOOR := 0.05            # 一樓地板比地面高一點：整平過的地面剛好跟地板一樣高時，地面的三角形會從地板穿出來一塊塊閃

static var _mat: ShaderMaterial
static var _ground_mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://greybox.gdshader")
	return _mat


## 地面（玩具地墊）：柔和的淡綠、大格子（2 公尺一格）、線淡一點。場外（arena_map.gd）也用這個顏色
const GROUND_COLOR := Color(0.6, 0.82, 0.55)
static var _bush_mat: StandardMaterial3D

static func ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = preload("res://greybox.gdshader")
		_ground_mat.set_shader_parameter(&"base", GROUND_COLOR)
		_ground_mat.set_shader_parameter(&"floor_color", GROUND_COLOR)
		_ground_mat.set_shader_parameter(&"line", 0.06)
		_ground_mat.set_shader_parameter(&"cell", 2.0)
	return _ground_mat


## 灌木（玩具風）：圓圓的綠色塑膠感，形狀不動（arena_map.gd 的 _build_level 換上）
static func bush_material() -> StandardMaterial3D:
	if _bush_mat == null:
		_bush_mat = StandardMaterial3D.new()
		_bush_mat.albedo_color = Color(0.3, 0.72, 0.32)
		_bush_mat.roughness = 0.3
	return _bush_mat


## 方塊房子（派對模式，規則草案 4.1 試驗屋）：一格 1.5 公尺的方塊，4×4 格＝6 公尺見方、一層樓。
## 回傳 [[中心（相對房子中心、地面高 0）, 等級], ...]，共 53 塊：地基（外圈，最底下一層，等級 3）12 塊、
## 地板（裡面，2）4 塊、柱子（四角，2）8 塊、牆（外圈其他，1）13 塊、屋頂（16 塊，1）。
## 門口：正面（+Z）靠左那一格，牆的兩層都不放，人走得進去。窗：左側（-X）牆中間那格，窗台（第 0 層）留著、窗頂以上不放。
## ponytail: 懸空的方塊不會掉下來（拆掉下面的柱子，上面的牆還站著），以後做連通檢查再說
const CUBE := 1.5
const DOOR_CELL := Vector2i(1, 3)     # 格子座標（i 沿 X、j 沿 Z，0..3）
const WINDOW_CELL := Vector2i(0, 1)
static func cube_house() -> Array:
	var cells := []
	for layer in [-1, 0, 1, 2]:   # -1：地基和地板，整層在地面以下（頂面跟地面齊平）；0、1：牆；2：屋頂
		for j in 4:
			for i in 4:
				var ring := i == 0 or i == 3 or j == 0 or j == 3
				var corner := (i == 0 or i == 3) and (j == 0 or j == 3)
				var cell := Vector2i(i, j)
				var level := 0
				if layer == -1:
					level = 3 if ring else 2
				elif layer == 2:
					level = 1
				elif ring and cell != DOOR_CELL and not (layer == 1 and cell == WINDOW_CELL):
					level = 2 if corner else 1
				if level > 0:
					cells.append([Vector3(-3.0 + (i + 0.5) * CUBE, (layer + 0.5) * CUBE, -3.0 + (j + 0.5) * CUBE), level])
	return cells


## 斜坡要多深才放得下（樓高 h）：前後各留 1 公尺走道
static func ramp_depth(h: float) -> float:
	return h / tan(deg_to_rad(RAMP_DEG)) + 2.0 * T + 2.0


## 實心方塊：半身牆、木箱、平台。size.y 是露出地面的高度
static func block(size: Vector3) -> StaticBody3D:
	return _body(block_pieces(size))


static func block_pieces(size: Vector3) -> Array:
	var p := []
	_box(p, Vector3(0, (size.y - BURY) * 0.5, 0), size + Vector3(0, BURY, 0), 2, 0)
	return p


## 房子：size = 寬 × 每層高 × 深，floors 層。一樓前後各一扇門（big：前門換成恐龍進得去的大門），
## 窗戶在兩側和樓上；兩層以上貼著左牆有斜坡上樓。平屋頂，上不去
static func house(size: Vector3, floors: int, big := false) -> StaticBody3D:
	return _body(house_pieces(size, floors, big))


## house() 的每一塊 [Transform3D, 尺寸, 等級, 材質（0 牆、1 屋頂、2 柱子樓板斜坡）]，玩具積木用（bricks()）。
## 四個角各一根柱子（等級 2）：牆在兩端各縮一根柱子的寬度，角落由柱子補上
static func house_pieces(size: Vector3, floors: int, big := false) -> Array:
	var p := []
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	floors = maxi(floors, 1)
	_box(p, Vector3(0, (FLOOR - BURY) * 0.5, 0), Vector3(size.x, BURY + FLOOR, size.z), 2, 2)   # 地板（實心埋進地下）
	_box(p, Vector3(0, h * floors + T * 0.5, 0), Vector3(size.x, T, size.z), 1, 1)   # 屋頂
	var run := h / tan(deg_to_rad(RAMP_DEG))
	var z0 := hz - T - 1.0                 # 斜坡起點（低的那端）
	var hole := -hx + T + RAMP_W + 0.2     # 樓板開洞的右緣
	for f in floors:
		var y0 := f * h - (BURY if f == 0 else 0.0)
		var y1 := (f + 1) * h
		var win := [WINDOW.x, f * h + WINDOW.y, f * h + WINDOW.z]
		var front := []
		var back := []
		var left := [[0.0] + win]
		var right := [[0.0] + win]
		if f == 0:
			var door := Vector2(minf(BIG_DOOR.x, size.x - 2.0), minf(BIG_DOOR.y, h - 0.5)) if big else DOOR
			front = [[0.0, door.x, -BURY, door.y]]
			back = [[0.0, DOOR.x, -BURY, DOOR.y]]
			if floors > 1:
				left = []   # 斜坡貼著左牆經過窗戶，一樓左邊不開窗
		else:
			front = [[-hx * 0.5] + win, [hx * 0.5] + win]
			back = front
			_box(p, Vector3((hole + hx - T) * 0.5, f * h - SLAB * 0.5, 0), Vector3(hx - T - hole, SLAB, size.z - 2 * T), 2, 2)
			var zb := z0 - run
			_box(p, Vector3((-hx + T + hole) * 0.5, f * h - SLAB * 0.5, (zb - hz + T) * 0.5), Vector3(hole + hx - T, SLAB, zb + hz - T), 2, 2)
			_box(p, Vector3((-hx + T + hole) * 0.5, f * h - SLAB * 0.5, (z0 + hz - T) * 0.5), Vector3(hole + hx - T, SLAB, hz - T - z0), 2, 2)
		if f < floors - 1:   # 往上一層的斜坡
			var ramp := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(RAMP_DEG)),
				Vector3(-hx + T + RAMP_W * 0.5, f * h + h * 0.5 - SLAB * 0.5, z0 - run * 0.5))
			p.append([ramp, Vector3(RAMP_W, SLAB, Vector2(run, h).length()), 2, 2])
		# 前後的牆兩端各縮 T（角落給柱子），左右的牆本來就縮了
		_wall(p, true, hz - T * 0.5, size.x - 2 * T, y0, y1, front)
		_wall(p, true, -hz + T * 0.5, size.x - 2 * T, y0, y1, back)
		_wall(p, false, -hx + T * 0.5, size.z - 2 * T, y0, y1, left)
		_wall(p, false, hx - T * 0.5, size.z - 2 * T, y0, y1, right)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p, Vector3(sx * (hx - T * 0.5), (y0 + y1) * 0.5, sz * (hz - T * 0.5)), Vector3(T, y1 - y0, T), 2, 2)
	return p


## 一面牆：沿 X（along_x）或 Z 方向，長 length，挖掉 holes 的洞。holes 每個是 [中心, 寬, 底, 頂]，由小到大排
static func _wall(p: Array, along_x: bool, at: float, length: float, y0: float, y1: float, holes: Array) -> void:
	var u := -length * 0.5
	for hole: Array in holes:
		var a: float = hole[0] - hole[1] * 0.5
		var b: float = hole[0] + hole[1] * 0.5
		_seg(p, along_x, at, u, a, y0, y1)
		_seg(p, along_x, at, a, b, y0, hole[2])   # 窗台
		_seg(p, along_x, at, a, b, hole[3], y1)   # 門楣、窗頂
		u = b
	_seg(p, along_x, at, u, length * 0.5, y0, y1)


static func _seg(p: Array, along_x: bool, at: float, u0: float, u1: float, y0: float, y1: float) -> void:
	if u1 - u0 < 0.01 or y1 - y0 < 0.01:
		return
	var c := Vector3((u0 + u1) * 0.5, (y0 + y1) * 0.5, at) if along_x else Vector3(at, (y0 + y1) * 0.5, (u0 + u1) * 0.5)
	_box(p, c, Vector3(u1 - u0, y1 - y0, T) if along_x else Vector3(T, y1 - y0, u1 - u0))


static func _box(p: Array, center: Vector3, size: Vector3, lv := 1, tone := 0) -> void:
	p.append([Transform3D(Basis(), center), size, lv, tone])


## 每一塊 [Transform3D, 尺寸]：網格合併成一個（一棟一次繪製），碰撞一塊一個
static func _body(pieces: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pc: Array in pieces:
		var box := BoxMesh.new()
		box.size = pc[1]
		st.append_from(box, 0, pc[0])
		var shape := BoxShape3D.new()
		shape.size = pc[1]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = pc[0]
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material()
	body.add_child(mi)
	return body


## ---- 玩具積木（docs/規劃/2026-11-08-玩具積木場景.md）----
## 積木最大：水平 1.5、高 0.75 公尺；厚度（0.2、0.3）本來就小於這個，不會被切
const BRICK_W := 1.5
const BRICK_H := 0.75
## 鮮豔的玩具色，每棟挑一個當牆（屋頂用隔兩個的顏色）。地基（頂面在地面以下）一律灰
const TOY_COLORS := [Color(0.85, 0.18, 0.16), Color(0.18, 0.38, 0.85), Color(0.95, 0.78, 0.18),
	Color(0.2, 0.66, 0.3), Color(0.93, 0.93, 0.9)]


## 把 pieces（house_pieces／block_pieces 的結果）切成積木：每塊 [Transform3D（相對原點，沒有旋轉）, 尺寸, 等級, 顏色]。
## at 是這棟的位置（挑色用）；force > 0 時所有塊都改成這個等級（安全屋全部 3）。斜坡（有轉角度）整片一塊。
## 等級：頂面在地面以下（<= 0.05）的是 3；其他照 pieces 的等級（牆、屋頂 1，樓板、柱子、斜坡 2）。純計算、沒有亂數：每台切出來一樣
static func bricks(pieces: Array, at := Vector3.ZERO, force := 0) -> Array:
	var out := []
	for pc: Array in pieces:
		var xf: Transform3D = pc[0]
		var size: Vector3 = pc[1]
		var base: bool = xf.origin.y + size.y * 0.5 <= FLOOR + 0.001
		var lv: int = 3 if base else int(pc[2])
		if force > 0:
			lv = force
		var tone: int = pc[3]
		if not xf.basis.is_equal_approx(Basis()):   # 斜坡：不切
			out.append([xf, size, lv, paint(tone, base, at, xf.origin)])
			continue
		var n := Vector3i(_cuts(size.x, BRICK_W), _cuts(size.y, BRICK_H), _cuts(size.z, BRICK_W))
		var each := size / Vector3(n)
		for ix in n.x:
			for iy in n.y:
				for iz in n.z:
					var c := xf.origin + (Vector3(ix + 0.5, iy + 0.5, iz + 0.5) * each - size * 0.5)
					out.append([Transform3D(Basis(), c), each, lv, paint(tone, base, at, c)])
	return out


## 切成幾塊：平均切，每塊不超過 limit（厚度比 limit 小的自然是 1 塊）
static func _cuts(d: float, limit: float) -> int:
	return maxi(ceili(d / limit - 0.001), 1)


## 積木的顏色。tone：0 牆、1 屋頂（隔兩個顏色）、2 柱子樓板斜坡（同色深一點）；base 是地基（灰）。
## 每塊亮度 ±5%，用位置算，看得出一塊一塊
static func paint(tone: int, base: bool, key: Vector3, at: Vector3) -> Color:
	var c := Color(0.5, 0.5, 0.5)
	if not base:
		var k := int(absf(key.x) * 3.0 + absf(key.z) * 7.0) % TOY_COLORS.size()
		match tone:
			1:
				c = TOY_COLORS[(k + 2) % TOY_COLORS.size()]
			2:
				c = (TOY_COLORS[k] as Color).darkened(0.3)
			_:
				c = TOY_COLORS[k]
	var j := _jitter(at) * 0.05
	return Color(c.r * (1.0 + j), c.g * (1.0 + j), c.b * (1.0 + j))


## -1 到 1 之間、由位置決定的數（不用亂數）
static func _jitter(p: Vector3) -> float:
	var s := sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453
	return (s - floorf(s)) * 2.0 - 1.0


## 方塊房子（派對，cube_house() 的格子）的積木：等級照格子，顏色照等級（地基灰、柱子樓板深色、屋頂另一色）
static func cube_bricks(at: Vector3) -> Array:
	var out := []
	for c: Array in cube_house():
		var lv: int = c[1]
		var center: Vector3 = c[0]
		var tone := 2 if lv == 2 else (1 if center.y > 3.0 else 0)
		out.append([Transform3D(Basis(), center), Vector3.ONE * CUBE, lv, paint(tone, lv == 3, at, center)])
	return out
