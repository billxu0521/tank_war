extends SceneTree
## 駕駛尼諾拉的畫面拍照：站著（idle）、瞄一棟房子（house）、往地上瞄（ground）、身體還沒轉過去就吐（side）、
## 背後貼著房子（wall，看鏡頭有沒有被牆推近）；會吐火球的另外拍一張飛行中（_flight）。
## 另外印出「畫面正中央那條線打到哪」和「火球最後到哪」差幾公尺（準心準不準）。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/pilot_cam_shots.gd

var _f := 0
var _main: Node
var _boss: Node3D
var _out := ""
var _step := 0
var _wait := 0
var _ball: Node3D
var _got_ball := false   # 放掉的節點跟 null 比是 true，另外記
var _ball_at := Vector3.ZERO
var _ball_from := Vector3.ZERO
var _center := Vector3.ZERO
var _flight_saved := false
## [名字, 鏡頭水平角相對身體（弧度）, 鏡頭俯仰, 要不要吐火球]
const SHOTS := [
	["idle", 0.0, 0.0, false],
	["house", 0.0, 0.0, true],
	["ground", 0.0, -0.25, true],
	["side", 0.5, 0.0, true],
	["wall", 0.0, 0.0, false],
]

func _initialize() -> void:
	_out = OS.get_environment("OUT")
	if _out == "":
		_out = "user://pilot_cam_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_main._offline = true
		_main._enter_game("駕駛鏡頭拍照")
		return false
	if _f < 60:
		return false
	if _f == 60:
		_setup()
		return false
	_main.menu.visible = false
	if _step >= SHOTS.size():
		return true
	var s: Array = SHOTS[_step]
	_wait += 1
	if _wait == 1:
		_place(s[0] in ["idle", "wall"], 5.0 if s[0] == "wall" else 22.0)
		_boss._cam_yaw = _boss.rotation.y + s[1]
		_boss._cam_pitch = s[2]
		_got_ball = false
		_flight_saved = false
		return false
	_boss._cam_yaw = _boss.rotation.y + s[1] if _wait < 30 else _boss._cam_yaw   # 身體還沒轉過去的那一刻就吐（side）
	if _wait == 30:
		_center = _center_hit()
		_save(s[0])
		if not s[3]:
			_next()
			return false
		_boss.fireball_left = 0.0
		_boss._attack_gap = 0.0
		_boss._begin(_boss.ACT_SPIT_WIND, _boss.FIREBALL_WIND)
		return false
	if _wait > 30:
		if not _got_ball:
			for c in _main.get_node(^"Arena").get_children():
				if c is Fireball:
					_ball = c
					_got_ball = true
					_ball_from = c.global_position
					_center = _center_hit()   # 吐出去那一刻畫面正中央指的地方
		elif is_instance_valid(_ball) and not _ball.is_queued_for_deletion():
			_ball_at = _ball.global_position
			if not _flight_saved and _ball_at.distance_to(_ball_from) > 14.0:
				_flight_saved = true
				_save(s[0] + "_flight")
		else:
			var dir := (_ball_at - _ball_from).normalized()
			var miss := (_center - _ball_from).cross(dir).length()   # 畫面正中央指的點離火球那條線多遠
			print("%s：畫面正中央指到 %s；火球從 %s 飛到 %s；正中央那點離火球的線 %.1f 公尺" % [s[0], _v(_center), _v(_ball_from), _v(_ball_at), miss])
			_next()
		if _wait > 900:
			print(s[0], "：等不到火球")
			_next()
	return false

func _next() -> void:
	_step += 1
	_wait = 0

func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]

var _hc := Vector3.ZERO
var _wall_x := 0.0
var _zc := 0.0

func _setup() -> void:
	var toys: Array = _main.map._toys
	var houses: Array = toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t.brick_count() > 300 and not t.is_in_group(&"tree") and not t.is_in_group(&"fence") and t != _main.map._party_house)
	var house: ToyBuild = houses[0]
	_hc = house.global_position
	var bb: AABB = house._bb[0]
	for i in house.brick_count():
		bb = bb.merge(house._bb[i])
	_wall_x = _hc.x + bb.position.x
	_zc = _hc.z + bb.get_center().z
	_boss = _main.spawn_boss()
	_boss.pilot = 1

## 尼諾拉放在房子 -X 那面牆外 gap 公尺，面向房子；away = 背對房子（看空地）
func _place(away: bool, gap: float) -> void:
	_boss.global_position = _main.boss_on_ground(Vector3(_wall_x - _boss.BODY_RADIUS - gap, 0, _zc))
	_boss.rotation.y = PI * 0.5 if away else -PI * 0.5
	_boss.velocity = Vector3.ZERO

## 畫面正中央那條線打到的點（不算尼諾拉自己和牠身後的東西；沒打到就取 80 公尺外）
func _center_hit() -> Vector3:
	var cam := root.get_camera_3d()
	var fwd := -cam.global_basis.z
	var from := cam.global_position + fwd * maxf((_boss.global_position - cam.global_position).dot(fwd), 0.0)   # 從尼諾拉旁邊開始，身後的東西不算
	var to := from + fwd * 80.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [_boss.get_rid()]
	var hit := _boss.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else to

func _save(name: String) -> void:
	var path := "%s/%s.png" % [_out, name]
	root.get_texture().get_image().save_png(path)
	print("存圖 ", path)
