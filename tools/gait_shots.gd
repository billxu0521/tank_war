extends SceneTree
## 拍尼諾拉走、跑、轉彎的連續畫面（改走路動作前後對照用）。真的進遊戲（單機）、照駕駛的方式送輸入。
##   OUT=/某個資料夾 VIEW=side godot --fixed-fps 60 --path . --resolution 960x540 --script tools/gait_shots.gd
##   VIEW：side 正側面（鏡頭跟著身體平移）、top 後上方俯視（看脊椎和尾巴的 S 形）、pilot 駕駛的越肩鏡頭
## 場上的房子、樹、石頭（ToyBuild）會先全部拿掉，只剩地形。
## 每段 SEC 秒（走 → 跑 → 邊跑邊轉），每 2 幀存一張 OUT/<VIEW>_<段>_<幀>.png（每秒 30 張）；最後印「SHOTS OK」。
## 接成對照圖、GIF 用 ffmpeg（例：ffmpeg -framerate 30 -i side_0_%03d.png walk.gif）

const PHASES := ["walk", "run", "turn"]
var SEC := 4.0
var _view := OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
var _out := OS.get_environment("OUT")
var _m: Node
var _f := 0
var _boss: Node3D
var _phase := -1
var _t := 0.0
var _n := 0
var _yaw := 0.0
var _cam: Camera3D
var _tap: Node
var _done := false


func _initialize() -> void:
	if OS.get_environment("SEC") != "":
		SEC = OS.get_environment("SEC").to_float()
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	_tap = Node.new()
	_tap.process_priority = 1000
	_tap.process_physics_priority = 1000
	var s := GDScript.new()
	s.source_code = "extends Node\nvar probe\nfunc _process(d: float) -> void:\n\tprobe.frame(d)\nfunc _physics_process(d: float) -> void:\n\tprobe.tick(d)\n"
	s.reload()
	_tap.set_script(s)
	_tap.set("probe", self)
	root.add_child(_tap)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_m._offline = true
		_m._enter_game("shots")
	if _boss != null and _phase == 2:
		_boss._cam_yaw = _yaw + 1.3 * sin(_t * 1.6)
	return _done


func tick(d: float) -> void:
	if _f < 3 or _done:
		return
	if _boss == null:
		_boss = _m._boss() if _m._boss() else _m.spawn_boss()
		_boss.pilot = 1
		for n: Node in _m.find_children("*", "StaticBody3D", true, false):   # 房子、樹、石頭全部拿掉：擋路也擋鏡頭
			if n is ToyBuild:
				n.queue_free()
		_next()
	_boss.stamina = _boss.STAMINA_MAX
	_boss.exhausted = false
	_boss.set_physics_process(false)
	_boss._sync_mask()
	_boss.pilot_input(Vector2(0, -1), _boss._cam_yaw, 0.0, _boss.PIN_RUN if _phase != 0 else 0)
	_boss.think(d)


func _next() -> void:
	_phase += 1
	_t = 0.0
	_n = 0
	if _phase >= PHASES.size():
		print("SHOTS OK")
		_done = true
		return
	_boss.global_position = _m.boss_on_ground(Vector3(0, 0, 10))
	_boss.velocity = Vector3.ZERO
	_boss.rotation.y = PI * 0.5
	_boss.reset_physics_interpolation()
	_yaw = _boss.rotation.y
	_boss._cam_yaw = _yaw
	_boss._pin_yaw = _yaw


func frame(d: float) -> void:
	if _done or _boss == null:
		return
	if _view != "pilot":
		if _cam == null:
			_cam = Camera3D.new()
			_cam.fov = 26.0 if _view == "side" else 40.0
			var ui := _m.get_node_or_null(^"UI") as CanvasLayer
			if ui:
				ui.visible = false
			_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(_cam)
		_cam.current = true
		var at: Vector3 = _boss.get_global_transform_interpolated().origin
		var fwd := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
		if _view == "side":
			_cam.look_at_from_position(at + fwd.cross(Vector3.UP) * 30.0 + Vector3.UP * -2.0, at + Vector3.UP * -2.0)
		else:
			_cam.look_at_from_position(at - fwd * 20.0 + Vector3.UP * 34.0, at - fwd * 2.5)
	_t += d
	if _t < 1.5:   # 起步那段不拍
		return
	if _t >= 1.5 + SEC:
		_next()
		return
	_n += 1
	if _n % 2 == 0 and _out != "":
		root.get_texture().get_image().save_png("%s/%s_%d_%03d.png" % [_out, _view, _phase, _n / 2])
