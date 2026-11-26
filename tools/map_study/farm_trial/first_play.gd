extends "res://tools/map_study/farm_trial/farmhouse_water.gd"

const SURVEY := preload("res://levels/farm_environment/plan.json")
# 對應農莊量體的渠心斷面；兩端裁到 168 m 場界，橋與堤另疊在渠上。
const CHANNEL := [[-84,8.8125],[-69,6],[-47,6],[-26,12],[4,13],[22,8],[51,-7],[73,-11],[84,-11]]
var return_centres: Array[Vector3] = []

func _ready() -> void:
	super()
	for zone in $Anchors/ReturnZones.get_children():
		var middle := Vector3.ZERO
		for pad in zone.get_children():
			middle += pad.global_position
		return_centres.append(middle / zone.get_child_count())

func farm_return_zones() -> Array[Vector3]:
	return return_centres

# 場景已在子節點就緒時建完。對局入口保留正式天空與時段，沿用同一套碰撞層。
func _load_level() -> void:
	pass

func _build_exits() -> void:
	pass

func _build_arena() -> void:
	for body: PhysicsBody3D in find_children("*", "PhysicsBody3D", true, false):
		if body.collision_layer & 1 and not body.is_in_group(&"tree"):
			body.collision_layer |= Fighter.SOLID_LAYER

func arrival_yaw(at: Vector3) -> float:
	var next := Vector3.ZERO
	if at.distance_to($Anchors/InitialSpawns/NW.global_position) < 1.0:
		next = Vector3(-55, 0, -73)
	elif at.distance_to($Anchors/ReturnZones/NE/Pad3.global_position) < 1.0 or at.distance_to($Anchors/ReturnZones/SE/Pad1.global_position) < 1.0:
		next = at + Vector3.FORWARD
	return atan2(at.x - next.x, at.z - next.z)

# 公開農路直接取自地表的路線。畫面只標三個慣用過岸處，玩家、箱、信與有效圈交給原規則。
func draw_farm_roads(view: Minimap) -> void:
	var channel := PackedVector2Array()
	for point in CHANNEL:
		channel.append(Minimap.to_map(Vector3(point[0], 0, point[1]), ARENA, view.SIZE))
	view.draw_polyline(channel, Color(0.27,0.44,0.50), 8.0*view.SIZE/ARENA, true)
	for line in SURVEY.data.paths:
		if float(line[0]) < 2.0:
			continue
		var points := PackedVector2Array()
		for xz in line[1]:
			points.append(Minimap.to_map(Vector3(xz[0], 0, xz[1]), ARENA, view.SIZE))
		view.draw_polyline(points, Color(0.53, 0.49, 0.36), 2.0, true)
	for crossing in [[-47,-2.5,14.5,"西灘"],[4,1,25,"中橋"],[51,-19,4,"東堤"]]:
		var a := Minimap.to_map(Vector3(crossing[0],0,crossing[1]), ARENA, view.SIZE)
		var b := Minimap.to_map(Vector3(crossing[0],0,crossing[2]), ARENA, view.SIZE)
		view.draw_line(a, b, Color(0.60,0.80,0.83), 4.0, true)
		view.draw_string(view.get_theme_default_font(), b + Vector2(4,9), crossing[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
