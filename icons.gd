class_name Icons
extends RefCounted
## 方位條、畫面上的標記、重生地圖共用的小圖示（0.8.16 第 7 節）。全部用程式畫的簡單形狀，
## ponytail: 美術給圖之後只換這個檔（draw 照樣吃 kind，畫貼圖就好）。
## kind：&"envelope_tens"、&"envelope_ones"、&"safe"、&"gold"、&"raptor"、&"dino"（爪印）、&"exit"、&"star"、&"egg"、&"spawn"。
## size 是圖示的寬（像素），c 是主色；每個圖示都有深色描邊，亮的天空上也看得到

const OUTLINE := Color(0.12, 0.07, 0.05, 0.9)

## 在 ci 上以 at 為中心畫一個圖示。text：spawn 的編號（其他忽略）
static func draw(ci: CanvasItem, kind: StringName, at: Vector2, size: float, c: Color, text := "") -> void:
	var h := size * 0.5
	var o := Color(OUTLINE, OUTLINE.a * c.a)   # 變淡時描邊一起淡
	match kind:
		&"envelope_tens", &"envelope_ones":   # 長方形加一個 V，右下角小「十」「個」
			var r := Rect2(at - Vector2(h, h * 0.68), Vector2(size, size * 0.68))
			ci.draw_rect(r.grow(1.5), o)
			ci.draw_rect(r, c)
			ci.draw_polyline(PackedVector2Array([r.position, at + Vector2(0, h * 0.05), r.position + Vector2(size, 0)]), o, 1.5)
			_label(ci, at + Vector2(h * 0.55, h * 0.9), "十" if kind == &"envelope_tens" else "個", maxi(int(size * 0.55), 9), c)
		&"safe":   # 方塊加圓鈕
			var r := Rect2(at - Vector2(h, h), Vector2(size, size))
			ci.draw_rect(r.grow(1.5), o)
			ci.draw_rect(r, c)
			ci.draw_circle(at, h * 0.42, o)
			ci.draw_circle(at, h * 0.28, c.darkened(0.35))
		&"gold", &"raptor", &"dino":   # 爪印：一個掌墊加三個趾頭
			ci.draw_circle(at + Vector2(0, h * 0.3), h * 0.5, o)
			ci.draw_circle(at + Vector2(0, h * 0.3), h * 0.38, c)
			for k in 3:
				var p := at + Vector2((k - 1) * h * 0.62, -h * (0.45 if k == 1 else 0.25))
				ci.draw_circle(p, h * 0.27, o)
				ci.draw_circle(p, h * 0.17, c)
		&"exit":   # 門：門框加一個門把
			var r := Rect2(at - Vector2(h * 0.62, h), Vector2(size * 0.62, size))
			ci.draw_rect(r.grow(1.5), o)
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(r.position + Vector2(h * 0.18, h * 0.18), r.size - Vector2(h * 0.36, h * 0.18)), c.darkened(0.45))
			ci.draw_circle(at + Vector2(h * 0.25, h * 0.1), maxf(h * 0.1, 1.5), c)
		&"star":   # 五角星
			var pts := PackedVector2Array()
			for k in 10:
				var a := TAU * k / 10.0
				pts.append(at + Vector2(sin(a), -cos(a)) * (h if k % 2 == 0 else h * 0.45))
			ci.draw_colored_polygon(pts, c)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), o, 1.5)
		&"egg":   # 橢圓
			var pts := PackedVector2Array()
			for k in 20:
				var a := TAU * k / 20.0
				pts.append(at + Vector2(sin(a) * h * 0.72, -cos(a) * h * (1.0 if cos(a) > 0.0 else 0.85)))
			ci.draw_colored_polygon(pts, c)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), o, 1.5)
		&"spawn":   # 圓加編號
			ci.draw_circle(at, h, o)
			ci.draw_circle(at, h - 1.5, c)
			if text != "":
				_label(ci, at, text, maxi(int(size * 0.7), 9), Color(1, 1, 1, c.a))
		_:   # 不認得的：一個圓點
			ci.draw_circle(at, h * 0.5, o)
			ci.draw_circle(at, h * 0.5 - 1.5, c)


## 小字（左右置中在 at，at 大約是字的中線）
static func _label(ci: CanvasItem, at: Vector2, t: String, fs: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := at + Vector2(-sz.x * 0.5, fs * 0.35)
	ci.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(OUTLINE, OUTLINE.a * c.a))
	ci.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
