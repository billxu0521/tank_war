class_name Minimap
extends Control
## 等重生時的俯視圖（0.8.16 第 6 節）：場地外框、房子的佔地（map._blocked）、重生點（綠的有編號、紅的選不了）、
## 自己死在哪、自己知道的撤離點。不畫任何玩家、不畫尼諾拉：這是畫出來的圖，不是把鏡頭拉到天上（會看光全場）。
## party_hud.gd 等重生時顯示、填 red／picked／dead_at，點綠點發 chosen。北（-Z）在上

signal chosen(index: int)

const SIZE := 460.0
const DOT := 26.0          # 重生點圖示寬
const GREEN := Color(0.35, 0.85, 0.45)
const RED := Color(0.9, 0.3, 0.25)

var main: Node
var red := 0               # 紅的重生點（第 i 位）
var picked := -1
var dead_at := Vector3.INF # 自己死在哪


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -SIZE * 0.5
	offset_right = SIZE * 0.5
	offset_top = -SIZE * 0.5 + 40.0   # 往下一點，上面留給方位條和提示
	offset_bottom = SIZE * 0.5 + 40.0
	mouse_filter = Control.MOUSE_FILTER_STOP


## 世界座標（XZ）換成圖上的座標：場地 arena 公尺見方，正中央在圖的中心，北（-Z）在上
static func to_map(p: Vector3, arena: float, size: float) -> Vector2:
	return Vector2((p.x / arena + 0.5) * size, (p.z / arena + 0.5) * size)


func _points() -> Array:
	return (main.spawn_points as Array).slice(0, 9)   # 數字鍵只有 1～9


func _draw() -> void:
	var arena: float = main.ARENA
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.2, 0.14, 0.88))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.85, 0.7), false, 2.0)
	var k := SIZE / arena
	if main.map.has_method(&"draw_farm_roads"):
		main.map.draw_farm_roads(self)
	for r: Rect2 in main.map._blocked:   # 房子的佔地（XZ）
		draw_rect(Rect2(to_map(Vector3(r.position.x, 0, r.position.y), arena, SIZE), r.size * k), Color(0.55, 0.5, 0.45, 0.9))
	if main.party == null or main.party.knows_exits():
		for e: Vector3 in main._exits:
			Icons.draw(self, &"exit", to_map(e, arena, SIZE), 20.0, Compass.EXIT_COLOR)
	if dead_at != Vector3.INF:   # 自己死的地方：一個叉
		var d := to_map(dead_at, arena, SIZE)
		for s in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(d - s * 8.0, d + s * 8.0, Icons.OUTLINE, 5.0)
			draw_line(d - s * 8.0, d + s * 8.0, Color(1, 0.9, 0.8), 2.5)
	var pts := _points()
	for i in pts.size():
		var at := to_map(pts[i], arena, SIZE)
		if i == picked:
			draw_arc(at, DOT * 0.5 + 6.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
		Icons.draw(self, &"spawn", at, DOT, RED if (red >> i) & 1 else GREEN, str(i + 1))


## 點到哪個重生點（-1 = 沒點到）
func point_at(local: Vector2) -> int:
	var pts := _points()
	for i in pts.size():
		if to_map(pts[i], main.ARENA, SIZE).distance_to(local) <= DOT * 0.5 + 6.0:
			return i
	return -1


func _gui_input(e: InputEvent) -> void:
	var b := e as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		var i := point_at(b.position)
		if i >= 0:
			chosen.emit(i)
		accept_event()
