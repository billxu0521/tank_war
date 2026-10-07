class_name ModelViewer
extends Node3D
## 模型檢視模式：把牛仔（連三把槍）和暴龍單獨擺出來繞著看。
## C 切到「操控恐龍」：WASD 自己開、一鍵出招、換心情、慢動作、顯示腳踩的點，旁邊有斜坡和台階看腳怎麼踩（docs/企劃/尼諾拉.md）。
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

## 生存物資（blender/survival.py）：實際大小排兩排，近看用
const SURVIVAL_GLB := preload("res://models/survivals.glb")
const SURVIVAL_ROWS := [["Campfire", "Lantern", "Backpack", "SnowRock", "Antler"],
	["Rifle", "Axe", "StewCan", "Mug", "Matchbox"]]

const KEYS := {
	KEY_1: "cowboy", KEY_2: "trex", KEY_3: "both", KEY_4: "survival", KEY_5: "library",
}

## 素材庫（5）：models/ 底下每個 .glb 都自動列進來，素材成員丟檔案進去就能看，不用改這支程式。
## ← → 換檔、L 切「整包看 / 一件一件排開」（一個 glb 裝很多樣東西時用，例如 rocks.glb）
const LIBRARY_DIR := "res://models/"
var _lib_files: PackedStringArray
var _lib_i := 0
var _lib_spread := false
var _lib: Node3D           # 現在擺出來的那個 glb

var _trex: Trex
var _cowboy: Node3D
var _survival: Node3D
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
var _drive := false        # C：自己操控恐龍
var _speed := 0.0          # 操控時現在的速度（加速、減速有個過程，boss 也是）
var _acts := []            # 排隊中的出招：[act, 秒數, 往前的速度]
var _act_left := 0.0
var _act_push := 0.0
var _mood := -1
var _slow := 3             # Engine.time_scale 的檔位，見 SLOW
const SLOW := [0.1, 0.25, 0.5, 1.0]
var _markers := false      # K：顯示腳踩的點
var _marks: Array[MeshInstance3D] = []
# 出招的順序和時間照 boss.gd（ACT_*、*_WIND、*_RECOVER）
const MOVES := {
	KEY_Z: [[1, 0.7, 0.0], [2, 0.15, 0.0], [7, 0.8, 0.0]],                  # 咬：預備 → 咬 → 收招
	KEY_X: [[3, 1.6, 0.0], [4, 0.4, 0.0], [7, 0.6, 0.0]],                   # 蓄力長吼 → 甩尾 → 收招
	KEY_V: [[5, 0.5, 0.0], [6, 0.6, 24.0], [7, 1.2, 0.0]],                  # 撲擊：蹲 → 撲出去 → 收招
	KEY_B: [[8, 2.5, 0.0]],                                                 # 被打斷（暈）
	KEY_G: [[9, 0.7, 0.0]],                                                 # 發現人
}
const MOVE_NAMES := {1: "咬預備", 2: "咬", 3: "蓄力長吼", 4: "甩尾", 5: "撲擊預備", 6: "撲出去", 7: "收招", 8: "被打斷", 9: "發現人"}
const MOOD_NAMES := {-1: "不套心情", 0: "逛", 1: "找", 2: "追"}

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
	_trex.scale = Vector3.ONE * 1.5   # 跟遊戲裡一樣大（boss.tscn）
	add_child(_trex)

	_cowboy = _build_cowboy()
	add_child(_cowboy)

	_survival = _build_survival()
	add_child(_survival)

	# list_directory 匯出後也拿得到原檔名（DirAccess 只會看到 .import）
	for f in ResourceLoader.list_directory(LIBRARY_DIR):
		if f.get_extension() == "glb":
			_lib_files.append(f)

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
	pm.size = Vector2(120, 120)
	pm.material = mat
	plane.mesh = pm
	n.add_child(plane)
	# 碰撞：恐龍的腳是往下打射線找地面踩（trex.gd 的 _ground），沒有碰撞就只會踩在固定高度
	_solid(n, Vector3(0, -0.5, 0), Vector3(120, 1, 120), Basis(), mat)
	# 操控模式看腳怎麼踩：東邊一道 20 度的坡（往北上去）、北邊三階台階、南邊一片小石堆
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.32, 0.28, 0.24)
	_solid(n, Vector3(24, 2.0, -6), Vector3(14, 1, 24), Basis(Vector3.RIGHT, deg_to_rad(20.0)), rock)
	_solid(n, Vector3(24, 3.27, -22.3), Vector3(14, 6.54, 10), Basis(), rock)   # 坡頂的平台（不然坡頂是 6 公尺的斷崖）
	for k in 3:   # 一階 0.3 公尺（約恐龍膝蓋的五分之一）
		_solid(n, Vector3(0, 0.15 + k * 0.15, -22 - k * 4.0), Vector3(16, 0.3 + k * 0.3, 4), Basis(), rock)
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	for k in 14:
		var sz := rr.randf_range(0.6, 1.6)
		_solid(n, Vector3(rr.randf_range(-8, 8), sz * 0.25, rr.randf_range(18, 30)), Vector3(sz, sz * 0.5, sz),
			Basis(Vector3.UP, rr.randf() * TAU), rock)

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

func _solid(parent: Node, pos: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.transform = Transform3D(basis, pos)
	parent.add_child(body)

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

## 一樣一樣排開：每排從左到右，間隔 0.3 公尺；第二排在前面（+Z）
func _build_survival() -> Node3D:
	var root := Node3D.new()
	var src := SURVIVAL_GLB.instantiate()
	for r in SURVIVAL_ROWS.size():
		var x := 0.0
		var row: Array[MeshInstance3D] = []
		for part: String in SURVIVAL_ROWS[r]:
			var mi := _mesh_of(src, part, Vector3.ZERO)
			var w := mi.get_aabb().size.x if mi.mesh else 0.3
			mi.position = Vector3(x + w * 0.5, 0, r * 1.0)
			x += w + 0.3
			row.append(mi)
			root.add_child(mi)
		for mi in row:   # 整排置中
			mi.position.x -= (x - 0.3) * 0.5
	src.free()
	root.visible = false
	return root

## 8 字路徑。單純繞圓只會一直往同一邊傾，看不出換邊
const TREX_WALK := 4.0   # boss.gd 的 WALK
const TREX_RUN := 11.0   # boss.gd 的 RUN
const TREX_TURN := 3.0   # boss.gd 的 TURN

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
	_trex.visible = which in ["trex", "both"]
	_cowboy.visible = which in ["cowboy", "both"]
	_survival.visible = which == "survival"
	if which == "library":
		_show_lib()
	elif _lib:
		_lib.queue_free()
		_lib = null
	match which:
		"library": pass   # _show_lib 已經依大小對好鏡頭
		"survival": _focus = Vector3(0, 0.25, 0.5); _dist = 3.5
		"cowboy": _focus = Vector3(0.2, 1.1, 0); _dist = 4.5
		"trex": _focus = Vector3(0, 3.0, 0); _dist = 22.0
		_:      _focus = Vector3(0, 3.0, 0); _dist = 26.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				Engine.time_scale = 1.0
				closed.emit()
			KEY_SPACE:
				_moving = not _moving
			KEY_C:   # 操控恐龍
				_drive = not _drive
				_speed = 0.0
				if _drive:
					_select("trex")
					_moving = false
					_trex.global_position = Vector3.ZERO   # 從中間、面朝北開始（斜坡在東、台階在北、石堆在南）
					_trex.rotation.y = 0.0
			KEY_M:
				_mood = (_mood + 2) % 4 - 1   # -1 → 0 → 1 → 2 → -1
				_trex.mood = _mood
			KEY_BRACKETLEFT:
				_slow = maxi(_slow - 1, 0)
				Engine.time_scale = SLOW[_slow]
			KEY_BRACKETRIGHT:
				_slow = mini(_slow + 1, SLOW.size() - 1)
				Engine.time_scale = SLOW[_slow]
			KEY_K:
				_markers = not _markers
			KEY_H:   # 中彈：從隨機一邊推一下
				var a := randf() * TAU
				_trex.flinch(Vector3(cos(a), 0, sin(a)), 1.0, false)
			KEY_J:   # 頭被打中
				_trex.flinch(Vector3.RIGHT, 1.0, true)
			KEY_F:
				_trex.bite()
			KEY_LEFT, KEY_RIGHT:
				if _subject == "library" and not _lib_files.is_empty():
					_lib_i = posmod(_lib_i + (1 if e.keycode == KEY_RIGHT else -1), _lib_files.size())
					_show_lib()
			KEY_L:
				if _subject == "library":
					_lib_spread = not _lib_spread
					_show_lib()
			KEY_TAB:
				_wire = not _wire
				get_viewport().debug_draw = (Viewport.DEBUG_DRAW_WIREFRAME if _wire
					else Viewport.DEBUG_DRAW_DISABLED)
			_:
				if MOVES.has(e.keycode) and _acts.is_empty() and _act_left <= 0.0:
					_acts = (MOVES[e.keycode] as Array).duplicate(true)
				elif KEYS.has(e.keycode):
					_select(KEYS[e.keycode])
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.6)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 45.0)
	elif e is InputEventMouseMotion and _dragging:
		_yaw -= e.relative.x * 0.008
		_pitch = clampf(_pitch + e.relative.y * 0.006, 0.02, 1.35)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	_run_acts(delta)
	_update_markers()
	if _drive:
		_drive_trex(delta)
	elif _moving:
		_t += delta
		# 繞圈跑。暴龍的步態和尾巴慣性是從實際位移算的，所以一定要真的移動
		var both := _subject == "both"
		# 恐龍照遊戲裡的樣子走：boss 的走路速度（4 m/s）、8 字夠寬（彎的半徑比腿長大，遊戲裡也轉不了更急）。
		# 以前半徑 2.6 公尺、還故意斜著走 26 度，比身體還小的圈，腳一定會在地上被拖（使用者看到「奇怪的動態」）
		var r := 9.0
		var a := _t * TREX_WALK / (2.5 * r)
		var tc := Vector3.ZERO
		var kc := Vector3(0, 0, 13) if both else Vector3.ZERO   # 牛仔站在 8 字外面
		# 恐龍走 8 字：左右彎都吃得到，才看得出側傾會換邊。朝向加一點點偏差，有一點側移
		var p0 := _lemniscate(a, r)
		var p1 := _lemniscate(a + 0.02, r)
		_trex.global_position = tc + p0
		var head := (p1 - p0)
		_trex.rotation.y = atan2(-head.x, -head.z) + sin(a * 2.0) * 0.12
		if _subject in ["trex", "both"]:   # 鏡頭跟著恐龍
			_focus = _focus.lerp(_trex.global_position + Vector3(0, 3.0, 0), 1.0 - exp(-3.0 * delta))
		# 牛仔原地慢慢轉身、上下看，繞一圈看得到前後
		_cowboy.global_position = kc
		_cowboy.rotation.y = _t * 0.5
		_head.rotation.x = sin(_t * 1.1) * 0.35
		if _lib:
			_lib.rotation.y = _t * 0.5
	else:
		# 停下來時擺回原位，方便正面看細節
		var both := _subject == "both"
		_trex.global_position = Vector3(-5.0 if both else 0.0, 0, 0)   # 恐龍是遊戲裡的大小，離牛仔遠一點
		_trex.rotation.y = PI
		_cowboy.global_position = Vector3(3.6 if both else 0.0, 0, 0)
		_cowboy.rotation.y = 0.0
		_head.rotation.x = 0.0
		if _lib:
			_lib.rotation.y = 0.0

	_cam.position = _focus + Vector3(
		_dist * cos(_pitch) * sin(_yaw),
		_dist * sin(_pitch),
		_dist * cos(_pitch) * cos(_yaw))
	_cam.look_at(_focus, Vector3.UP)

	if _drive:
		_label.text = ("操控恐龍　速度 %.1f m/s　%s　心情：%s　時間 ×%s\n" % [_speed, MOVE_NAMES.get(_trex.act, "—"), MOOD_NAMES[_mood], SLOW[_slow]]
			+ "W 走　Shift+W 跑　A/D 轉身　S 停\n"
			+ "Z 咬　X 長吼＋甩尾　V 撲擊　B 被打斷　G 發現人　H 中彈　J 頭被打\n"
			+ "M 換心情　[ ] 慢動作　K 腳踩的點（綠＝踩著、橘＝抬起、紅＝要落的地方）　Tab 線框\n"
			+ "東邊斜坡、北邊台階、南邊石堆　C 回到自動　左鍵拖曳轉視角　滾輪縮放　Esc 回大廳")
	elif _subject == "library":
		_label.text = "素材庫　%s　（%d / %d）\n← → 換檔　L %s　空白鍵 %s　Tab %s\n1～4 回其他模式　左鍵拖曳轉視角　滾輪縮放　Esc 回大廳" % [
			_lib_files[_lib_i].get_file() if not _lib_files.is_empty() else "models/ 裡沒有 .glb",
			_lib_i + 1, _lib_files.size(),
			"整包看" if _lib_spread else "一件一件排開",
			"停下" if _moving else "轉起來",
			"關線框" if _wire else "開線框",
		]
	else:
		_label.text = "模型檢視　[%s]\n1 牛仔和槍　2 恐龍　3 兩個　4 生存物資　5 素材庫\n空白鍵 %s　F 咬一口　Tab %s　C 操控恐龍\n左鍵拖曳轉視角　滾輪縮放　Esc 回大廳" % [
			{"cowboy": "牛仔和槍", "trex": "恐龍", "both": "兩個", "survival": "生存物資"}[_subject],
			"停下" if _moving else "動起來",
			"關線框" if _wire else "開線框",
		]


## 操控恐龍：W 走（boss 的走路速度）、Shift 跑、A/D 照 boss 的轉速轉身。出招時站定（撲出去會往前衝）。
## 高度貼著地面（往下打射線）：走上斜坡、台階，看腳和身體怎麼跟
func _drive_trex(delta: float) -> void:
	var want := 0.0
	if _act_left <= 0.0 and _acts.is_empty():
		if Input.is_key_pressed(KEY_W):
			want = TREX_RUN if Input.is_key_pressed(KEY_SHIFT) else TREX_WALK
		var turn := float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D))
		_trex.rotation.y += turn * TREX_TURN * delta
	_speed = move_toward(_speed, want, 14.0 * delta)   # 起步、煞車約 0.3～0.8 秒
	var v := _speed + _act_push
	var p := _trex.global_position - _trex.global_basis.z.normalized() * v * delta
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 10.0))
	if hit:   # 高度平順地跟（像角色控制器上台階）：一幀跳一整階，腳和身體都會被扯一下
		p.y = move_toward(_trex.global_position.y, hit.position.y, 6.0 * delta)
	_trex.global_position = p
	_focus = _focus.lerp(_trex.global_position + Vector3(0, 3.0, 0), 1.0 - exp(-3.0 * delta))

## 排隊的出招一個一個放（自動模式也可以按，站著做）
func _run_acts(delta: float) -> void:
	if _act_left > 0.0:
		_act_left -= delta
		if _act_left > 0.0:
			return
	_act_push = 0.0
	if _acts.is_empty():
		_trex.act = 0
		return
	var a: Array = _acts.pop_front()
	_trex.act = a[0]
	_act_left = a[1]
	_act_push = a[2]

## 腳踩的點：綠＝踩著、橘＝抬起來、紅＝這一步要落的地方
func _update_markers() -> void:
	if _marks.is_empty():
		for k in 4:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.5
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.no_depth_test = true   # 被腳擋住也看得到
			sm.material = mat
			mi.mesh = sm
			add_child(mi)
			_marks.append(mi)
	for k in 4:
		_marks[k].visible = _markers and _trex.visible and _trex._walk_ready
	if not _marks[0].visible:
		return
	for i in 2:
		_marks[i].global_position = _trex._plant[i]
		(_marks[i].mesh.material as StandardMaterial3D).albedo_color = Color(1, 0.55, 0.1) if _trex._swing[i] else Color(0.2, 1, 0.3)
		_marks[2 + i].visible = _trex._swing[i]
		_marks[2 + i].global_position = _trex._land[i]
		(_marks[2 + i].mesh.material as StandardMaterial3D).albedo_color = Color(1, 0.15, 0.15)


## 把現在選的 glb 擺到地板正中間（底部貼地），鏡頭依大小拉遠拉近。
## 排開時把最上層的每個子節點當一樣東西，排成方陣、間隔是最寬那樣的兩成
func _show_lib() -> void:
	if _lib:
		_lib.queue_free()
		_lib = null
	if _lib_files.is_empty():
		return
	var scene := load(LIBRARY_DIR + _lib_files[_lib_i]) as PackedScene
	if scene == null:
		return
	_lib = Node3D.new()
	add_child(_lib)
	var inst := scene.instantiate()
	_lib.add_child(inst)
	if _lib_spread and inst.get_child_count() > 1:
		var parts := inst.get_children().filter(func(c: Node) -> bool: return c is Node3D)
		var boxes := parts.map(func(c: Node3D) -> AABB: return _bounds(c))
		var cell := 0.0
		for b: AABB in boxes:
			cell = maxf(cell, maxf(b.size.x, b.size.z))
		cell *= 1.2
		var cols := ceili(sqrt(parts.size()))
		for k in parts.size():
			var b: AABB = boxes[k]
			var c := b.get_center()
			(parts[k] as Node3D).position += Vector3(k % cols * cell - c.x, -b.position.y, k / cols * cell - c.z)
	var box := _bounds(_lib)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	_focus = Vector3(0, box.size.y * 0.5, 0)
	_dist = clampf(box.get_longest_axis_size() * 1.8, 0.6, 45.0)

## 底下所有網格合起來的外框（世界座標；_lib 擺在原點所以等於相對座標）
func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
