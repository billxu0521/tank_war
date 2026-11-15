class_name Compass
extends Control
## 畫面上方的方位條：0～360 度（0 = 北 = 場地的 -Z，順時針，90 = 東 = +X），
## 看著的方向在正中間，左右各看得到 COVER/2 度。
## 上面標蛋和撤離區的方向＋距離；在視野外的就貼在兩端，箭頭指往那邊轉。
##
## match_hud.gd 每幀呼叫 set_view() 並填 marks（蛋、撤離區），這裡只負責畫。

const COVER := 180.0          # 方位條總共涵蓋幾度
const WIDTH := 640.0
const HEIGHT := 30.0
const EGG_COLOR := Color(1.0, 0.95, 0.8)
const EXIT_COLOR := Color(1.0, 0.72, 0.2)
const ROW_GAP := 18.0         # 第二行字（信封、保險箱）往下多少
const PAD := 8.0              # 同一行兩個字之間至少留多少

var heading := 0.0
## [{"deg": 方位, "dist": 公尺, "color": Color, "label": String, "row": 0 或 1（沒給就是 0）}]
var marks: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 8
	offset_bottom = 8 + HEIGHT + 40 + ROW_GAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 方位：從 from 看 to 在哪個角度（0 = -Z，順時針）
static func bearing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)


func set_view(cam: Camera3D) -> void:
	var f := -cam.global_basis.z
	heading = fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


## 某個方位在條上的 x；超出視野回傳兩端外面一點（負的或大於 WIDTH）
func _x_of(deg: float) -> float:
	var off := wrapf(deg - heading, -180.0, 180.0)
	return WIDTH * 0.5 + off / COVER * WIDTH


## 文字加深色描邊：背景是亮橘色的天空，淡色字直接畫會糊掉
func _text(font: Font, pos: Vector2, t: String, size: int, c: Color) -> void:
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.12, 0.07, 0.05, 0.85))
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color(0.1, 0.06, 0.04, 0.45))
	# 刻度：每 15 度一小格，每 45 度寫數字
	var start := floorf((heading - COVER * 0.5) / 15.0) * 15.0
	var d := start
	while d <= heading + COVER * 0.5:
		var x := _x_of(d)
		if x >= 0.0 and x <= WIDTH:
			var deg := int(fposmod(d, 360.0))
			var big := deg % 45 == 0
			draw_line(Vector2(x, HEIGHT - (12.0 if big else 6.0)), Vector2(x, HEIGHT), Color(1, 1, 1, 0.8), 1.5)
			if big:
				var t := str(deg)
				var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				_text(font, Vector2(x - w * 0.5, 15), t, 16, Color(1, 1, 1, 0.9))
		d += 15.0
	# 目前方向：中間一根指針＋下面的度數
	var h := str(int(round(heading)) % 360)
	var hw := font.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_line(Vector2(WIDTH * 0.5, 0), Vector2(WIDTH * 0.5, HEIGHT), Color.WHITE, 2.0)
	_text(font, Vector2(WIDTH * 0.5 - hw * 0.5, HEIGHT + 18), h, 18, Color.WHITE)
	# 目標：蛋、撤離區。視野外的貼在兩端、畫成箭頭
	var rows := [[], []]   # 每行的字：[想放的左緣, 寬, 字, 顏色]
	for m: Dictionary in marks:
		var x := _x_of(m["deg"])
		var c: Color = m["color"]
		var inside := x >= 0.0 and x <= WIDTH
		x = clampf(x, 8.0, WIDTH - 8.0)
		if inside:
			var tri := PackedVector2Array([Vector2(x, HEIGHT - 2), Vector2(x - 7, HEIGHT - 14), Vector2(x + 7, HEIGHT - 14)])
			draw_colored_polygon(tri, c)
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.12, 0.07, 0.05), 1.5)
		else:
			var s := -1.0 if x < WIDTH * 0.5 else 1.0
			var tri := PackedVector2Array([Vector2(x + s * 7, HEIGHT * 0.5),
				Vector2(x - s * 5, HEIGHT * 0.5 - 8), Vector2(x - s * 5, HEIGHT * 0.5 + 8)])
			draw_colored_polygon(tri, c)
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.12, 0.07, 0.05), 1.5)
		var t: String = "%s %dm" % [m["label"], int(m["dist"])] if m.has("dist") else m["label"]   # 沒給距離只寫名字（一排重生點）
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		rows[int(m.get("row", 0))].append([x - w * 0.5, w, t, c])
	for r in rows.size():
		var xs := spread(rows[r].map(func(a: Array) -> float: return a[0]), rows[r].map(func(a: Array) -> float: return a[1]))
		for i in xs.size():
			_text(font, Vector2(xs[i], HEIGHT + 36 + r * ROW_GAP), rows[r][i][2], 16, rows[r][i][3])


## 同一行的字擺開：want = 每個字想放的左緣，w = 寬。回傳實際的左緣（順序照輸入）：
## 照左右順序排，後面的往右推開、中間留 PAD，全部不超出方位條（太多擠不下才會疊）
static func spread(want: Array, w: Array) -> Array:
	var order := range(want.size())
	order.sort_custom(func(a: int, b: int) -> bool: return want[a] < want[b])
	var xs := want.duplicate()
	var edge := 0.0
	for i: int in order:   # 左到右：不疊上一個
		xs[i] = maxf(clampf(want[i], 0.0, WIDTH - w[i]), edge)
		edge = xs[i] + w[i] + PAD
	edge = WIDTH
	for k in range(order.size() - 1, -1, -1):   # 右到左：推出右邊界的往回拉
		var i: int = order[k]
		xs[i] = maxf(minf(xs[i], edge - w[i]), 0.0)
		edge = xs[i] - PAD
	return xs
