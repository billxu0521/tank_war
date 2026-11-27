class_name Markers
extends Control
## 畫面上的標記（0.8.16 第 7 節）：撤離點、星星、蛋這種常駐的東西，把位置投到畫面上，在那裡畫圖示、下面寫距離。
## 不被牆擋；在畫面外（含身後）就貼在畫面邊緣、加一個小箭頭指方向；離準心太近變半透明，不擋瞄準。
## match_hud.gd 每幀填 marks（world_marks()）、叫 set_view，這裡只負責畫。

const SIZE := 22.0        # 圖示寬（像素）
const EDGE := 36.0        # 貼邊時離畫面邊緣多遠
const NEAR_AIM := 70.0    # 離畫面中央這麼近就變淡
const NEAR_ALPHA := 0.3
const GAP := 44.0         # 兩個標記疊在一起時往上推多少

## [{"pos": Vector3, "icon": StringName, "color": Color, "label": String, "sub": 圖示下面的字（沒有就寫距離）}]
var marks: Array = []
var _cam: Camera3D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(cam: Camera3D) -> void:
	_cam = cam


## 投得到畫面上嗎：要在近平面前面。剛好在鏡頭上、鏡頭那個平面上（含自己算是 -0.0000001、引擎算是 0 的）
## 給 unproject_position 會除以 0 報 p.d == 0（跳「遊戲記到一個錯誤」），呼叫 unproject_position 前都先問這個
## 要用 get_camera_transform()（unproject_position 用的那個）：開了物理插值時它是插值後的位置，跟 global_transform 差一點，
## 用 global_transform 判斷「在前面」，引擎那邊可能剛好在鏡頭平面上。
static func in_front(cam: Camera3D, p: Vector3) -> bool:
	if not cam.is_inside_tree():
		return false
	var t := cam.get_camera_transform()
	return -t.basis.z.normalized().dot(p - t.origin) >= cam.near


## 標記在畫面上的位置：[位置, 在不在畫面裡, 指向（貼邊時箭頭的方向）]
func place(p: Vector3) -> Array:
	var sz := size
	var mid := sz * 0.5
	var local: Vector3 = _cam.get_camera_transform().affine_inverse() * p
	var at: Vector2
	var front := in_front(_cam, p)
	if front:
		at = _cam.unproject_position(p)
		if Rect2(Vector2(EDGE, EDGE), sz - Vector2(EDGE, EDGE) * 2.0).has_point(at):
			return [at, true, Vector2.ZERO]
	var dir := (at - mid) if front else Vector2(local.x, -local.y)   # 身後：照左右上下的方向貼邊
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var half := mid - Vector2(EDGE, EDGE)
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	return [mid + dir * k, false, dir]


func _draw() -> void:
	if _cam == null:
		return
	var font := get_theme_default_font()
	var mid := size * 0.5
	var placed: Array = []   # [畫面位置, 標記, 在不在畫面裡, 指向]
	for m: Dictionary in marks:
		var r := place(m["pos"])
		placed.append([r[0], m, r[1], r[2]])
	placed.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y > b[0].y)
	for i in placed.size():   # 疊在一起的往上推開（只有幾個，兩兩比就好）
		for j in i:
			var a: Vector2 = placed[i][0]
			var b: Vector2 = placed[j][0]
			if absf(a.x - b.x) < SIZE + 8.0 and absf(a.y - b.y) < GAP:
				placed[i][0] = Vector2(a.x, b.y - GAP)
	for e: Array in placed:
		var at: Vector2 = e[0]
		var m: Dictionary = e[1]
		var c: Color = m["color"]
		var alpha := NEAR_ALPHA if at.distance_to(mid) < NEAR_AIM else 1.0
		var col := Color(c, alpha)
		if not e[2]:   # 貼邊：圖示外側畫一個小箭頭
			var d: Vector2 = e[3]
			var tip := at + d * (SIZE * 0.5 + 12.0)
			var side := Vector2(-d.y, d.x) * 6.0
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 9.0 + side, tip - d * 9.0 - side]), col)
		Icons.draw(self, m["icon"], at, SIZE, col)
		var t: String = m.get("sub", "%dm" % int(_cam.global_position.distance_to(m["pos"])))   # sub：隊友的名字
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var tp := at + Vector2(-w * 0.5, SIZE * 0.5 + 15.0)
		draw_string_outline(font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(Icons.OUTLINE, 0.85 * alpha))
		draw_string(font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, alpha))
