extends SceneTree
## 方位條最擠的情況拍照（0.8.16 第 7 節的驗收）：派對模式、自己當獵人，正前方 ±25 度內擺
## 2 信封＋保險箱＋金色小恐龍＋2 撤離點＋星星，拍一張全畫面。改前改後各跑一次對照。
##   OUT=/path/to/folder NAME=after godot --path . --resolution 1600x900 --script tools/compass_shots.gd

var _f := 0
var _main: Node
var _out := ""
var _name := ""
## [東西, 方位（度，0 = 正前方 = 北）, 距離（公尺）]
const SPOTS := {"env0": [-22.0, 60.0], "env1": [-15.0, 95.0], "safe": [-9.0, 40.0], "gold": [-2.0, 28.0],
	"exit0": [6.0, 120.0], "exit1": [13.0, 70.0], "star": [20.0, 50.0]}
var _at := Vector3.ZERO


func _initialize() -> void:
	_out = OS.get_environment("OUT")
	_name = OS.get_environment("NAME")
	if _out == "":
		_out = "user://compass_shots"
	if _name == "":
		_name = "compass"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_f += 1
	var p: Party = _main.party
	if _f == 5:
		_main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_main._offline = true
		_main._enter_game("方位條拍照")
		_main._on_mode_picked(_main.RULES.keys().find(&"party"))
		_main._apply_rules()
	elif _f == 30:   # 第一回合主機當恐龍：跳到第二回合當獵人
		p._end_round(true, "拍照")
		p.time_left = 0.0
	elif _f == 40:
		p.time_left = 0.0   # 準備階段跳過
	elif _f == 50:
		_setup(p)
	elif _f > 50 and _f < 120:
		_hold(p)
	elif _f == 120:
		var path := "%s/%s.png" % [_out, _name]
		root.get_texture().get_image().save_png(path)
		print("存圖 ", path)
		return true
	return false


## 前方 deg 度、d 公尺的地面
func _spot(key: String) -> Vector3:
	var s: Array = SPOTS[key]
	var a := deg_to_rad(s[0])
	return _main._on_ground(_at + Vector3(sin(a), 0, -cos(a)) * s[1])


func _setup(p: Party) -> void:
	_main.menu.visible = false
	_at = _main._on_ground(Vector3(0, 0, 70))
	for c: Node in _main.players.get_children():
		if c.name != "1":
			c.process_mode = Node.PROCESS_MODE_DISABLED   # 電腦獵人、尼諾拉不動
			c.global_position = Vector3(0, -50, 0) if not c.is_in_group(&"boss") else Vector3(0, 0, -80)
	_main.raptors.add_gold()
	p.star_on = true
	p.set(&"touched_egg", true)   # 摸過蛋才知道撤離點（A7 之前沒有這個變數，set 不會做事）


## 每幀擺回去（物理、規則會把東西挪走）
func _hold(p: Party) -> void:
	var me: Node3D = _main.players.get_node_or_null(^"1")
	if me:
		me.global_position = _at + Vector3.UP * 0.1
		me.rotation.y = 0.0
		me.head.rotation.x = 0.0
	p.env_pos = [_spot("env0"), _spot("env1")]
	_main.safe.global_position = _spot("safe") + Vector3.UP * Safe.HALF
	_main.safe.freeze = true
	var g: Node3D = _main.raptors.gold_body()
	if g:
		g.global_position = _spot("gold")
	var k := 0
	for i in _main.map._exits.size():   # 開著的兩個撤離區搬到前面（地上的光圈不跟著搬，方位條、標記照搬過的算）
		if (_main.egg.exits >> i) & 1 and k < 2:
			_main.map._exits[i] = _spot("exit%d" % k)
			k += 1
	p.star_pos = _spot("star")
	p.time_left = 120.0
	if &"_seen" in _main._match_hud:   # 每 5 秒跟上的標記：擺好之前記到的舊位置清掉
		_main._match_hud._seen.clear()
