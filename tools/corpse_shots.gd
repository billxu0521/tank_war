extends SceneTree
## 牛仔死掉倒下的連續畫面：開沙盒，從北邊把自己的牛仔打死，從側面拍倒下的過程，最後一張是死亡鏡頭看到的。
##   OUT=/tmp/corpse godot --path . --resolution 1280x720 --script tools/corpse_shots.gd

const AT := [0.0, 0.25, 0.5, 0.8, 1.2, 2.0, 3.0]   # 死後幾秒拍側面
const DEATH_CAM := 3.5                               # 這時拍死亡鏡頭

var _f := 0
var _main: Node
var _cam: Camera3D
var _corpse: Corpse
var _t := 0.0
var _i := 0
var _side := Vector3.ZERO


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 60:
		_main.menu.visible = false
		var me: Node3D = _main.players.get_node_or_null(^"1")
		if me == null or not me is Cowboy:
			push_error("找不到自己的牛仔")
			return true
		me.take_damage(9999, null)
		me.last_from = me.global_position + Vector3(0, 1, -5)   # take_damage 是 RPC，打過來的方向在這之後才用到：補一個北邊
		_corpse = _main.get_children().filter(func(n: Node) -> bool: return n is Corpse).back()
		_side = me.global_position + Vector3(-5, 1.6, 1.5)
		_cam = Camera3D.new()
		root.add_child(_cam)
		return false
	if _corpse == null:
		return _f > 400
	_t += delta
	var torso: Node3D = _corpse.parts.torso
	if _i < AT.size():
		_cam.current = true
		_cam.look_at_from_position(_side, torso.global_position + Vector3(0, 0.6, 0))
		if _t >= AT[_i]:
			RenderingServer.force_draw()   # 視窗被擋住時 macOS 不重畫（同 trex_skin_check.gd）
			_save("%d_t%.2f" % [_i, AT[_i]])
			_i += 1
		return false
	_corpse._cam.current = true
	if _t >= DEATH_CAM:
		RenderingServer.force_draw()
		_save("death_cam")
		return true
	return false


func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % n)
