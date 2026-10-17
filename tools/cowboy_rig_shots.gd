extends SceneTree
## 別人眼中的牛仔（CowboyRig）各種動作：開沙盒，旁邊放一個電腦牛仔（遠端身分），一個狀態擺一陣子再從斜前方拍。
##   OUT=docs/image/cowboy_rig/遊戲裡 godot --path . --resolution 1280x720 --script tools/cowboy_rig_shots.gd

const HOLD := 1.2   # 每個狀態擺多久再拍（動畫要時間換過去）
## [名字, 水平速度, 垂直速度, 翻越, 爬梯, 近戰, 抬頭, 蹲, 中彈]
const STATES := [
	["站著", 0.0, 0.0, false, false, false, 0.0, false, false],
	["走", 5.0, 0.0, false, false, false, 0.0, false, false],
	["跑", 8.5, 0.0, false, false, false, 0.0, false, false],
	["跳", 0.0, 2.5, false, false, false, 0.0, false, false],
	["爬梯", 0.0, 0.0, false, true, false, 0.0, false, false],
	["翻越", 0.0, 0.0, true, false, false, 0.0, false, false],
	["近戰", 0.0, 0.0, false, false, true, 0.0, false, false],
	["中彈", 0.0, 0.0, false, false, false, 0.0, false, true],
	["抬頭", 0.0, 0.0, false, false, false, 0.6, false, false],
	["低頭", 0.0, 0.0, false, false, false, -0.5, false, false],
	["蹲", 0.0, 0.0, false, false, false, 0.0, true, false],
]

var _f := 0
var _main: Node
var _c: Cowboy
var _cam: Camera3D
var _i := 0
var _t := 0.0
var _home := Vector3.ZERO


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 60:
		_main.menu.visible = false
		var me: Node3D = _main.players.get_node(^"1")
		_c = load("res://cowboy/cowboy.tscn").instantiate()
		_c.name = "-77"   # 負數＝電腦：遠端身分，別人眼中的樣子
		_main.players.add_child(_c)
		_c.set_physics_process(false)   # 不跑電腦的腦袋，位置這裡自己推
		_home = me.global_position + Vector3(0, 0, -6)
		var q := PhysicsRayQueryParameters3D.create(_home + Vector3.UP * 20.0, _home + Vector3.DOWN * 20.0)
		var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			_home = hit.position   # 地面有起伏：放到這裡的地面上，不然腳陷進地裡
		_c.global_position = _home
		for g in _main.find_children("*", "MultiMeshInstance3D", true, false):
			(g as Node3D).visible = false   # 草、麥子會擋住腳
		_cam = Camera3D.new()
		root.add_child(_cam)
		_cam.current = true
		return false
	if _c == null:
		return false
	var s: Array = STATES[_i]
	if _t == 0.0:
		_c.vaulting = s[3]
		_c._ladder = _c if s[4] else null   # 只看有沒有，不會真的爬
		_c.head.rotation.x = s[6]
		_c.sync_crouching = s[7]
		if s[8]:
			_c._on_hurt(30, _c.global_position + Vector3(0, 1, -5))
	if s[5]:
		_c.viewmodel._melee_cooldown = 0.5   # 近戰中
	_t += delta
	_c._apply_crouch(s[7], delta)
	# 原地跑步機：照速度往前推，推遠了拉回來（瞬移超過 20 m/s 不算速度）
	_c.global_position += Vector3(0, s[2], -s[1]) * delta
	if _c.global_position.distance_to(_home) > 3.0:
		_c.global_position = _home
	var p := _c.global_position
	_cam.current = true   # 自己的牛仔每幀會搶回相機
	(_main.players.get_node(^"1") as Node).get_node(^"HUD").visible = false
	_cam.look_at_from_position(p + Vector3(1.8, 1.5, -2.4), p + Vector3(0, 0.95, 0))
	if _t >= HOLD:
		RenderingServer.force_draw()
		if OS.get_environment("DEBUG") != "":
			var mi := _c._rig.skeleton.get_child(0) as MeshInstance3D
			print("cam ", _cam.global_position, " current ", root.get_viewport().get_camera_3d() == _cam, " cowboy ", _c.global_position, " rig ", _c._rig.global_transform.basis.get_scale(), " mesh aabb ", mi.global_transform * mi.get_aabb(), " visible ", mi.is_visible_in_tree())
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%02d_%s.png" % [_i, s[0]])
		_i += 1
		_t = 0.0
		_c.global_position = _home
		_c.viewmodel._melee_cooldown = 0.0
	return _i >= STATES.size()
