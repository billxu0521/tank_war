class_name Trails
extends RefCounted
## 荒地小路：人和馬車踩出來的土路，彎彎曲曲連起撤離點、農莊、城鎮主街、森林小屋、麥田倉庫。
## 取代以前把場地切成四塊的十字路（太像棋盤，不像荒野）。
##
## 每條路：幾個路經點 → Catmull-Rom 曲線串起來（平順轉彎）→ 沿路每公尺往兩側推一點，推多少由 Simplex 雜訊 fBm 決定
## （大彎裡有小扭動，不是圓規畫的弧）→ 路寬也跟著雜訊變寬變窄。
## 算好之後蓋成一張 1 公尺一格的「離路邊多遠」表，地面上色、草、樹、石頭都查這張表（全場幾十萬次，要快）。
##
## 靜態、固定 seed：場地自動擺設（main.gd _generate_level）在地形蓋好之前就要用，每台機器算出來一樣。
## ponytail: 路經點手寫的，不是自動尋路。要「路自己繞開山丘」再換成在地形上找坡度最小的路線（A*）

const CELL := 1.0
const ARENA := 168.0   # 要跟 main.gd 的 ARENA 一樣（不引用 main.gd：它也引用這支，互相載入會出錯）
## [半寬（公尺）, 路經點]。座標是場地的 x、z；第一條是東西向的主路，從場邊一路穿過兩個撤離點
const ROUTES := [
	[2.0, [Vector2(-84, 1), Vector2(-62, 0), Vector2(-40, 3), Vector2(-20, -2), Vector2(0, 2), Vector2(22, -3), Vector2(42, 2), Vector2(62, 0), Vector2(84, -1)]],
	[1.5, [Vector2(-40, 3), Vector2(-46, -10), Vector2(-50, -26)]],                  # 農莊（牧場柵欄在 x -44～-24，從西邊繞）
	[1.5, [Vector2(22, -3), Vector2(24, -16), Vector2(18, -28), Vector2(10, -40)]],   # 城鎮主街西口
	[1.5, [Vector2(42, 2), Vector2(46, 18), Vector2(51, 37)]],                       # 森林小屋
	[1.4, [Vector2(-40, 3), Vector2(-34, 15), Vector2(-30, 22)]],                    # 麥田倉庫
]
const WANDER := 2.5   # 路往兩側最多推幾公尺
const FAR := 12.0     # 表裡只記這麼近的，再遠一律當很遠

## 只有牧場有這些路；靶場是另一張地圖，蓋之前關掉（main.gd _build_arena、編輯器 level_root.gd）。
## ponytail: 全域開關，一次只會有一張地圖
static var enabled := true
static var _edge := PackedFloat32Array()   # 每格「離路邊多遠」（在路上是負的）
static var _n := 0
static var _half := 0.0
static var _noise: FastNoiseLite


## 離最近的路邊幾公尺：路上是負的，越往路中間越負
static func edge(x: float, z: float) -> float:
	if not enabled:
		return FAR
	_build()
	var fx := (x + _half) / CELL
	var fz := (z + _half) / CELL
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	if ix < 0 or iz < 0 or ix >= _n - 1 or iz >= _n - 1:
		return FAR
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(_edge[iz * _n + ix], _edge[iz * _n + ix + 1], tx)
	var b := lerpf(_edge[(iz + 1) * _n + ix], _edge[(iz + 1) * _n + ix + 1], tx)
	return lerpf(a, b, tz)


## 路的濃度 0～1（地面上色用）：路中間 1，路邊半公尺內淡出去；邊緣再用雜訊咬得參差，不是一刀切齊
static func weight(x: float, z: float) -> float:
	var e := edge(x, z)
	if e > 2.0:
		return 0.0
	return 1.0 - smoothstep(-0.5, 0.5, e + _noise.get_noise_2d(x * 7.0, z * 7.0) * 0.6)


static func _build() -> void:
	if _n > 0:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 1871
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.03   # 沿路約 30 公尺彎一次
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_half = ARENA * 0.5
	_n = int(ARENA / CELL) + 1
	_edge.resize(_n * _n)
	_edge.fill(FAR)
	var r := int(ceil((FAR + WANDER) / CELL))
	for k in ROUTES.size():
		var half_w: float = ROUTES[k][0]
		var pts: Array = ROUTES[k][1]
		var walked := 0.0
		for p: Array in _samples(pts):
			var at: Vector2 = p[0]
			var side: Vector2 = p[1]
			walked += CELL
			# 往側邊推：每條路用雜訊的不同一段（k * 1000），兩條路不會同時往同一邊彎。
			# 路經點上不推（離路經點 10 公尺內慢慢收回來）：岔路口就在路經點上，主路和岔路才接得起來
			var fade := minf(1.0, p[2] / 10.0)
			at += side * _noise.get_noise_2d(walked, k * 1000.0) * WANDER * 2.0 * fade
			var w := half_w * (1.0 + _noise.get_noise_2d(walked * 2.0, k * 1000.0 + 500.0) * 0.5)
			var cx := int(round((at.x + _half) / CELL))
			var cz := int(round((at.y + _half) / CELL))
			for iz in range(maxi(cz - r, 0), mini(cz + r + 1, _n)):
				for ix in range(maxi(cx - r, 0), mini(cx + r + 1, _n)):
					var d := Vector2(ix * CELL - _half, iz * CELL - _half).distance_to(at) - w
					if d < _edge[iz * _n + ix]:
						_edge[iz * _n + ix] = d


## 沿著路經點的 Catmull-Rom 曲線每公尺取一點：[位置, 往左的方向（長度 1）, 離最近的路經點多遠]
static func _samples(pts: Array) -> Array:
	var out := []
	var dense: Array[Vector2] = []
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var steps := int(ceil(p1.distance_to(p2) / CELL))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	dense.append(pts[-1])
	for i in dense.size():
		var dir := (dense[mini(i + 1, dense.size() - 1)] - dense[maxi(i - 1, 0)]).normalized()
		var near := INF
		for q: Vector2 in pts:
			near = minf(near, dense[i].distance_to(q))
		out.append([dense[i], Vector2(-dir.y, dir.x), near])
	return out
