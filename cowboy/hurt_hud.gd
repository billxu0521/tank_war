class_name HurtHud
extends Control
## 自己被打的畫面回饋（只有自己的牛仔有，cowboy.gd 的 _on_hurt 叫 hurt()）：
## - 畫面四周閃紅：傷越重越紅，約 0.6 秒退掉
## - 受傷方向：準心外圍一段紅色弧線指向打你的人，轉身時跟著轉（記的是世界座標），1.5 秒淡掉
## - 血量低於 LOW_HP 時，四周一直有暗紅色慢慢脈動
## 畫在 Control 的 _draw 裡，不吃滑鼠

const FLASH_TIME := 0.6
const ARROW_TIME := 1.5
const LOW_HP := 0.3
const RING := 140.0        # 弧線離畫面中心多遠（像素）
const ARC := 0.55          # 弧線張開的角度（弧度，約 30 度）
const RED := Color(0.85, 0.08, 0.05)

var low := 0.0             # 0~1：血少到什麼程度（cowboy.gd 每幀給）
var _flash := 0.0          # 0~1：這一下多紅
var _arrows := []          # [世界座標, 剩下的時間]
var _camera: Camera3D
var _t := 0.0
var _vignette: TextureRect


func _init(camera: Camera3D) -> void:
	_camera = camera
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 四周暗、中間透明的漸層，用顏色調紅色的深淺
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(0.55, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(RED, 0.0)
	add_child(_vignette)


## 被打一下。frac：這一下扣了滿血的幾成；from：打你的人在哪（摔落是 INF，不畫方向）
func hurt(frac: float, from: Vector3) -> void:
	_flash = clampf(_flash + 0.35 + frac * 1.5, 0.0, 1.0)
	if from != Vector3.INF:
		_arrows.append([from, ARROW_TIME])


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	for a: Array in _arrows:
		a[1] -= delta
	_arrows = _arrows.filter(func(a: Array) -> bool: return a[1] > 0.0)
	var pulse := low * (0.35 + 0.15 * sin(_t * 5.0))   # 血少：慢慢脈動，像心跳
	_vignette.modulate.a = clampf(maxf(_flash * 0.85, pulse), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _camera == null or _arrows.is_empty():
		return
	var c := size * 0.5
	var fwd := -_camera.global_basis.z
	var yaw := atan2(fwd.x, -fwd.z)   # 鏡頭朝哪（北為 0、順時針）
	for a: Array in _arrows:
		var to: Vector3 = a[0] - _camera.global_position
		var ang := atan2(to.x, -to.z) - yaw   # 相對鏡頭的方向：0 是正前方、往右為正
		var alpha := clampf(a[1] / ARROW_TIME, 0.0, 1.0)
		# 畫面上的角度：正前方在上（-90 度）
		var screen := ang - PI * 0.5
		draw_arc(c, RING, screen - ARC * 0.5, screen + ARC * 0.5, 16, Color(RED, alpha * 0.9), 14.0, true)
		var tip := c + Vector2(cos(screen), sin(screen)) * (RING + 24.0)
		var side := Vector2(cos(screen + PI * 0.5), sin(screen + PI * 0.5)) * 13.0
		var base := c + Vector2(cos(screen), sin(screen)) * (RING + 4.0)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(RED, alpha))
