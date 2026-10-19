class_name Greybox
extends RefCounted
## 灰盒（素模）：灰色方塊拼的房子和掩體，先專心調玩法（docs/規劃/2026-10-19-灰盒地圖.md）。
## 遊戲（main.gd 的 _build_level）和編輯器預覽（LevelPreview）共用：回傳一個 StaticBody3D，
## 裡面是合併好的一個網格＋每一塊各自的碰撞。原點在地面中央，正面朝 +Z。

const T := 0.3                 # 牆厚
const BURY := 1.0              # 牆和地板往地下多埋這麼深：蓋在斜坡上時，低的那邊才不會露縫
const DOOR := Vector2(1.4, 2.3)   # 一般門（寬、高）：恐龍（半徑 2.4）擠不進來
const BIG_DOOR := Vector2(6.0, 8.5)   # 大門：恐龍（高 8）走得進來
const WINDOW := Vector3(1.2, 1.0, 2.1)   # 寬、窗台高、窗頂高。窗台 1 公尺在翻越範圍（0.4～1.5）內
const RAMP_W := 1.4            # 上樓的斜坡：貼著左牆，從前面往後爬
const RAMP_DEG := 30.0
const SLAB := 0.2              # 樓板厚

static var _mat: ShaderMaterial
static var _ground_mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://greybox.gdshader")
	return _mat


## 地面：比牆暗一點、格線淡一點，牆和地分得開
static func ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		_ground_mat = ShaderMaterial.new()
		_ground_mat.shader = preload("res://greybox.gdshader")
		_ground_mat.set_shader_parameter(&"base", Color(0.42, 0.44, 0.4))
		_ground_mat.set_shader_parameter(&"floor_color", Color(0.42, 0.44, 0.4))
		_ground_mat.set_shader_parameter(&"line", 0.12)
	return _ground_mat


## 斜坡要多深才放得下（樓高 h）：前後各留 1 公尺走道
static func ramp_depth(h: float) -> float:
	return h / tan(deg_to_rad(RAMP_DEG)) + 2.0 * T + 2.0


## 實心方塊：半身牆、木箱、平台。size.y 是露出地面的高度
static func block(size: Vector3) -> StaticBody3D:
	var p := []
	_box(p, Vector3(0, (size.y - BURY) * 0.5, 0), size + Vector3(0, BURY, 0))
	return _body(p)


## 房子：size = 寬 × 每層高 × 深，floors 層。一樓前後各一扇門（big：前門換成恐龍進得去的大門），
## 窗戶在兩側和樓上；兩層以上貼著左牆有斜坡上樓。平屋頂，上不去
static func house(size: Vector3, floors: int, big := false) -> StaticBody3D:
	var p := []
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	floors = maxi(floors, 1)
	_box(p, Vector3(0, -BURY * 0.5, 0), Vector3(size.x, BURY, size.z))   # 地板（實心埋進地下）
	_box(p, Vector3(0, h * floors + T * 0.5, 0), Vector3(size.x, T, size.z))   # 屋頂
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
			_box(p, Vector3((hole + hx - T) * 0.5, f * h - SLAB * 0.5, 0), Vector3(hx - T - hole, SLAB, size.z - 2 * T))
			var zb := z0 - run
			_box(p, Vector3((-hx + T + hole) * 0.5, f * h - SLAB * 0.5, (zb - hz + T) * 0.5), Vector3(hole + hx - T, SLAB, zb + hz - T))
			_box(p, Vector3((-hx + T + hole) * 0.5, f * h - SLAB * 0.5, (z0 + hz - T) * 0.5), Vector3(hole + hx - T, SLAB, hz - T - z0))
		if f < floors - 1:   # 往上一層的斜坡
			var ramp := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(RAMP_DEG)),
				Vector3(-hx + T + RAMP_W * 0.5, f * h + h * 0.5 - SLAB * 0.5, z0 - run * 0.5))
			p.append([ramp, Vector3(RAMP_W, SLAB, Vector2(run, h).length())])
		_wall(p, true, hz - T * 0.5, size.x, y0, y1, front)
		_wall(p, true, -hz + T * 0.5, size.x, y0, y1, back)
		_wall(p, false, -hx + T * 0.5, size.z - 2 * T, y0, y1, left)
		_wall(p, false, hx - T * 0.5, size.z - 2 * T, y0, y1, right)
	return _body(p)


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


static func _box(p: Array, center: Vector3, size: Vector3) -> void:
	p.append([Transform3D(Basis(), center), size])


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
