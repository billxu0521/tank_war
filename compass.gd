class_name Compass
extends Control
## 畫面上方的方位條：0～360 度（0 = 北 = 場地的 -Z，順時針，90 = 東 = +X），
## 看著的方向在正中間，左右各看得到 COVER/2 度。
## 上面標蛋和撤離區的方向＋距離；在視野外的就貼在兩端，箭頭指往那邊轉。
##
## main.gd 每幀呼叫 set_view() 並填 marks（蛋、撤離區），這裡只負責畫。

const COVER := 180.0          # 方位條總共涵蓋幾度
const WIDTH := 640.0
const HEIGHT := 30.0
const EGG_COLOR := Color(1.0, 0.95, 0.8)
const EXIT_COLOR := Color(1.0, 0.72, 0.2)

var heading := 0.0
## [{"deg": 方位, "dist": 公尺, "color": Color, "label": String}]
var marks: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 8
	offset_bottom = 8 + HEIGHT + 34
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
				var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				_text(font, Vector2(x - w * 0.5, 13), t, 13, Color(1, 1, 1, 0.9))
		d += 15.0
	# 目前方向：中間一根指針＋下面的度數
	var h := str(int(round(heading)) % 360)
	var hw := font.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_line(Vector2(WIDTH * 0.5, 0), Vector2(WIDTH * 0.5, HEIGHT), Color.WHITE, 2.0)
	_text(font, Vector2(WIDTH * 0.5 - hw * 0.5, HEIGHT + 16), h, 15, Color.WHITE)
	# 目標：蛋、撤離區。視野外的貼在兩端、畫成箭頭
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
		var t := "%s %dm" % [m["label"], int(m["dist"])]
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var tx := clampf(x - w * 0.5, 0.0, WIDTH - w)
		_text(font, Vector2(tx, HEIGHT + 32), t, 14, c)
