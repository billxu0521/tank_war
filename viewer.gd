class_name ModelViewer
extends Node3D
## 模型檢視模式：把牛仔（連三把槍）和暴龍單獨擺出來繞著看。
##
## 存在的理由是「改完模型要有地方看」。Blender 裡看不到 Godot 的材質、
## 也看不到程式動畫，所以這裡要能讓暴龍真的走起來——它的步態是從實際位移
## 算出來的，站著不動就看不出對不對。
##
## ponytail: 整個場景用程式建，不開 .tscn。就一個檔案，刪掉也不影響遊戲。

const COWBOY_GLB := preload("res://models/cowboy.glb")
## 三把槍擺在牛仔旁邊腰的高度，真實比例，看得出跟人比起來多大
const GUNS := [preload("res://models/revolver.glb"), preload("res://models/shotgun.glb"),
	preload("res://models/rifle.glb")]

const KEYS := {
	KEY_1: "cowboy", KEY_2: "trex", KEY_3: "both",
}

var _trex: Trex
var _cowboy: Node3D
var _head: Node3D
var _cam: Camera3D
var _label: Label
var _ui: CanvasLayer

var _subject := "both"
var _moving := true
var _wire := false
var _t := 0.0
var _yaw := 0.7
var _pitch := 0.32
var _dist := 13.0
var _focus := Vector3(0, 1.8, 0)
var _dragging := false

## 離開時呼叫，讓叫我的人把自己收回去
signal closed

func _ready() -> void:
	RenderingServer.set_debug_generate_wireframes(true)   # 不先開，線框模式會是空的

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, -0.6, 0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)

	add_child(_ground())

	_trex = Trex.new()
	add_child(_trex)

	_cowboy = _build_cowboy()
	add_child(_cowboy)

	_cam = Camera3D.new()
	_cam.fov = 50
	# 環境掛在相機上而不是 WorldEnvironment：主場景那顆還在樹上，會搶過去
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.53, 0.62)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_cam.environment = env
	add_child(_cam)
	_cam.current = true

	_ui = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_ui.add_child(_label)
	add_child(_ui)

	_select(_subject)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## 主場景把大廳的中文字型傳進來，不然 Label 會變成豆腐字
func use_theme(th: Theme) -> void:
	if is_instance_valid(_label):
		_label.theme = th

## 地板：一片深色方格，才看得出模型多大、有沒有浮在空中
func _ground() -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.14, 0.16)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.material = mat
	plane.mesh = pm
	n.add_child(plane)

	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.24, 0.26, 0.30)
	for i in range(-10, 11):          # 一公尺一格，當比例尺用
		for axis in 2:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 0.01, 20.0) if axis == 0 else Vector3(20.0, 0.01, 0.03)
			bm.material = line
			bar.mesh = bm
			bar.position = Vector3(i, 0.01, 0) if axis == 0 else Vector3(0, 0.01, i)
			n.add_child(bar)
	return n

## 用 cowboy.tscn 一樣的節點位置把牛仔組起來（那邊是 CharacterBody3D，搬進來會拖一堆遊戲邏輯）。
## 頭掛在 1.6 公尺的樞紐上，會慢慢上下看——遊戲裡別人就是這樣看出你在看哪。
func _build_cowboy() -> Node3D:
	var root := Node3D.new()
	var src := COWBOY_GLB.instantiate()
	root.add_child(_mesh_of(src, "CowboyBody", Vector3.ZERO))
	_head = Node3D.new()
	_head.position.y = 1.6
	_head.add_child(_mesh_of(src, "CowboyHead", Vector3.ZERO))
	root.add_child(_head)
	src.free()
	for i in GUNS.size():
		var gun: Node3D = GUNS[i].instantiate()   # 整個 glb 放進來，會動的零件在自己的轉軸上
		gun.position = Vector3(0.55, 0.9 + i * 0.22, 0.2)
		gun.rotation.y = -PI * 0.5                # 槍口朝右（遠離牛仔），從正面看得到側面
		for loose in [^"RevolverRound", ^"ShotgunShell", ^"RifleRound"]:   # 換彈用的子彈，原點在扳機，不藏會卡在護弓裡
			if gun.has_node(loose):
				gun.get_node(loose).visible = false
		root.add_child(gun)
	return root

## 8 字路徑。單純繞圓只會一直往同一邊傾，看不出換邊
func _lemniscate(a: float, r: float) -> Vector3:
	return Vector3(sin(a) * r * 1.5, 0, sin(a) * cos(a) * r * 2.0)

func _mesh_of(src: Node, part: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var from := src.get_node_or_null(NodePath(part)) as MeshInstance3D
	if from:
		mi.mesh = from.mesh
	mi.position = pos
	return mi

func _select(which: String) -> void:
	_subject = which
	_trex.visible = which != "cowboy"
	_cowboy.visible = which != "trex"
	match which:
		"cowboy": _focus = Vector3(0.2, 1.1, 0); _dist = 4.5
		"trex": _focus = Vector3(0, 2.0, 0); _dist = 12.0
		_:      _focus = Vector3(0, 1.7, 0); _dist = 15.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				closed.emit()
			KEY_SPACE:
				_moving = not _moving
			KEY_F:
				_trex.bite()
			KEY_TAB:
				_wire = not _wire
				get_viewport().debug_draw = (Viewport.DEBUG_DRAW_WIREFRAME if _wire
					else Viewport.DEBUG_DRAW_DISABLED)
			_:
				if KEYS.has(e.keycode):
					_select(KEYS[e.keycode])
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 2.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 45.0)
	elif e is InputEventMouseMotion and _dragging:
		_yaw -= e.relative.x * 0.008
		_pitch = clampf(_pitch + e.relative.y * 0.006, 0.02, 1.35)

func _process(delta: float) -> void:
	if _moving:
		_t += delta
		# 繞圈跑。暴龍的步態和尾巴慣性是從實際位移算的，所以一定要真的移動
		var both := _subject == "both"
		var r := 2.6 if both else 4.0
		var a := _t * 0.55
		var tc := Vector3(-3.6, 0, 0) if both else Vector3.ZERO   # 兩個一起看就各站一邊
		var kc := Vector3(3.6, 0, 0) if both else Vector3.ZERO
		# 恐龍走 8 字：左右彎都吃得到，才看得出側傾會換邊。
		# 朝向再加一點偏差，讓它有側移（不是只有轉彎）
		var p0 := _lemniscate(a, r)
		var p1 := _lemniscate(a + 0.02, r)
		_trex.global_position = tc + p0
		var head := (p1 - p0)
		_trex.rotation.y = atan2(-head.x, -head.z) + sin(a * 2.0) * 0.45
		# 牛仔原地慢慢轉身、上下看，繞一圈看得到前後
		_cowboy.global_position = kc
		_cowboy.rotation.y = _t * 0.5
		_head.rotation.x = sin(_t * 1.1) * 0.35
	else:
		# 停下來時擺回原位，方便正面看細節
		var both := _subject == "both"
		_trex.global_position = Vector3(-3.6 if both else 0.0, 0, 0)
		_trex.rotation.y = PI
		_cowboy.global_position = Vector3(3.6 if both else 0.0, 0, 0)
		_cowboy.rotation.y = 0.0
		_head.rotation.x = 0.0

	_cam.position = _focus + Vector3(
		_dist * cos(_pitch) * sin(_yaw),
		_dist * sin(_pitch),
		_dist * cos(_pitch) * cos(_yaw))
	_cam.look_at(_focus, Vector3.UP)

	_label.text = "模型檢視　[%s]\n1 牛仔和槍　2 恐龍　3 兩個\n空白鍵 %s　F 咬一口　Tab %s\n左鍵拖曳轉視角　滾輪縮放　Esc 回大廳" % [
		{"cowboy": "牛仔和槍", "trex": "恐龍", "both": "兩個"}[_subject],
		"停下" if _moving else "動起來",
		"關線框" if _wire else "開線框",
	]
