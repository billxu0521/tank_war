class_name Compass
extends Control
## 畫面上方的方位條：0～360 度（0 = 北 = 場地的 -Z，順時針，90 = 東 = +X），
## 看著的方向在正中間，左右各看得到 COVER/2 度。
## 標記畫成一排小圖示（icons.gd），只有最靠近正前方的那個寫距離；在視野外的就貼在兩端，箭頭指往那邊轉。
## 撤離、星星、蛋不在這裡，是畫面上的標記（markers.gd）。
##
## match_hud.gd 每幀呼叫 set_view() 並填 marks（compass_marks），這裡只負責畫。

const COVER := 180.0          # 方位條總共涵蓋幾度
const WIDTH := 640.0
const HEIGHT := 30.0
const EGG_COLOR := Color(1.0, 0.95, 0.8)
const EXIT_COLOR := Color(1.0, 0.72, 0.2)
const ICON := 20.0            # 圖示寬（icons.gd）
const PAD := 10.0             # 兩個圖示之間至少留多少（信封右下角的「十」「個」會凸出一點）
const FRONT := 10.0           # 正前方左右幾度內的標記寫距離（只寫最近正前方的一個）

var heading := 0.0
## [{"deg": 方位, "dist": 公尺（沒給就不寫距離）, "color": Color, "label": String, "icon": StringName（沒給就寫 label）, "text": 圖示上的字（重生點編號）}]
var marks: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 8
	offset_bottom = 8 + HEIGHT + 70
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
	# 標記：條上一個小三角指方位（視野外的貼在兩端、畫成箭頭），下面一排圖示（擺開不疊）。
	# 距離只寫最靠近正前方的那一個（左右 FRONT 度內），其他只有圖示
	var items := []   # [想放的左緣, 寬, 標記, x]
	var front := -1
	var best := FRONT
	for i in marks.size():
		var m: Dictionary = marks[i]
		var x := _x_of(m["deg"])
		var c: Color = m["color"]
		var inside := x >= 0.0 and x <= WIDTH
		x = clampf(x, 8.0, WIDTH - 8.0)
		if inside:
			var tri := PackedVector2Array([Vector2(x, HEIGHT - 2), Vector2(x - 6, HEIGHT - 12), Vector2(x + 6, HEIGHT - 12)])
			draw_colored_polygon(tri, c)
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.12, 0.07, 0.05), 1.5)
		else:
			var sd := -1.0 if x < WIDTH * 0.5 else 1.0
			var tri := PackedVector2Array([Vector2(x + sd * 7, HEIGHT * 0.5),
				Vector2(x - sd * 5, HEIGHT * 0.5 - 8), Vector2(x - sd * 5, HEIGHT * 0.5 + 8)])
			draw_colored_polygon(tri, c)
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.12, 0.07, 0.05), 1.5)
		var off := absf(wrapf(float(m["deg"]) - heading, -180.0, 180.0))
		if m.has("dist") and off <= best:
			best = off
			front = i
		var w := ICON if m.has("icon") else font.get_string_size(m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		items.append([x - w * 0.5, w, m])
	var xs := spread(items.map(func(a: Array) -> float: return a[0]), items.map(func(a: Array) -> float: return a[1]))
	var y := HEIGHT + 26.0 + ICON * 0.5   # 圖示中線：在中間的度數下面
	for i in xs.size():
		var m: Dictionary = items[i][2]
		var cx: float = xs[i] + items[i][1] * 0.5
		if m.has("icon"):
			Icons.draw(self, m["icon"], Vector2(cx, y), ICON, m["color"], m.get("text", ""))
		else:
			_text(font, Vector2(xs[i], y + 6), m["label"], 16, m["color"])
		if i == front:
			var t := "%dm" % int(m["dist"])
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_text(font, Vector2(clampf(cx - tw * 0.5, 0.0, WIDTH - tw), y + ICON * 0.5 + 18), t, 15, Color.WHITE)


## 同一排的圖示擺開：want = 每個想放的左緣，w = 寬。回傳實際的左緣（順序照輸入）：
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
