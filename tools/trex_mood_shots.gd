extends SceneTree
## 恐龍四種狀態（逛、找、追、退開）好不好認：每種照遊戲的速度走一段，從側面、牛仔眼睛的高度拍 20、40 公尺各一張，
## 再從正前方 30 公尺拍一張（玩家最常看到牠衝過來的樣子），存到 OUT/<狀態>_<20|40|front>.png，再由 tools/trex_mood_sheet.py 拼成對照圖（含全黑剪影）。
## 沒有地面（背景單色才好做剪影），腳由 trex.gd 退回靜止高度。
##   OUT=/tmp/mood godot --path . --resolution 1280x720 --script tools/trex_mood_shots.gd
##   BEFORE=1 ……   拍改之前的樣子：那時退開的心情是「逛」

const BG := Color(0.13, 0.15, 0.18)
## [名字, 心情, 速度]：速度照 boss.gd 的 WALK 4、RUN 11
const STATES := [["roam", 0, 4.0], ["search", 1, 4.0], ["hunt", 2, 11.0], ["retreat", 3, 11.0]]
## [檔名後綴, 相機在恐龍的哪裡（世界座標，恐龍往 -Z 走）]
const SHOTS := [["20", Vector3(-20, 1.7, 0)], ["40", Vector3(-40, 1.7, 0)], ["front", Vector3(0, 1.7, -30)]]
const HOLD := 8
const SETTLE := 3.0   # 每種狀態走多久才拍（心情、跑步姿勢是慢慢換過去的）

var _trex: Trex
var _cam: Camera3D
var _i := 0
var _t := 0.0
var _shot := -1   # -1 還沒拍；之後每張照片佔 HOLD 幀


func _initialize() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, -0.6, 0)
	sun.light_energy = 1.7
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 50
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.53, 0.62)
	env.ambient_light_energy = 0.45
	_cam.environment = env
	root.add_child(_cam)
	_cam.current = true
	_trex = Trex.new()
	_trex.scale = Vector3.ONE * 1.5   # 跟遊戲裡一樣大（boss.tscn）
	root.add_child(_trex)
	_start()


func _start() -> void:
	var s: Array = STATES[_i]
	var mood: int = s[1]
	if mood == 3 and OS.get_environment("BEFORE") != "":
		mood = 0
	_trex.mood = mood
	_t = 0.0
	_shot = -1


func _process(delta: float) -> bool:
	_t += delta
	var s: Array = STATES[_i]
	_trex.global_position += Vector3.FORWARD * float(s[2]) * delta   # 拍照時也照走：一停下來身體會往前晃
	# 每張佔 HOLD 幀，每幀都強制畫，最後一幀才拍：視窗被擋住時 macOS 不重畫，拿到的畫面會晚好幾幀，
	# 只強制畫一次還是會拿到上一個相機位置的（量過：正面那張拍成側面）
	var k := maxi(_shot, 0)
	var cam: Vector3 = SHOTS[mini(k / HOLD, SHOTS.size() - 1)][1]
	var at := _trex.global_position + Vector3(0, 3.0, 0)
	_cam.look_at_from_position(_trex.global_position + cam, at)
	if _t < SETTLE:
		return false
	if _shot >= 0:
		RenderingServer.force_draw()
	if _shot >= 0 and _shot % HOLD == HOLD - 1:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("OUT") + "/%s_%s.png" % [s[0], SHOTS[_shot / HOLD][0]])
	_shot += 1
	if _shot < SHOTS.size() * HOLD:
		return false
	_i += 1
	if _i >= STATES.size():
		return true
	_start()
	return false
