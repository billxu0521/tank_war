extends SceneTree
## 甩尾動畫拍照（草案 2.6，trex.gd 的 act 4）：開沙盒，把沙盒恐龍的 Trex.act 直接排成
## 蓄力中段 → 甩尾 0% / 33% / 66% / 100% → 收招中段，每個角度各拍一遍，共 12 張。
## 角度：正上方往下看（top）、斜後方（back）。存到 OUT，終端機印出尾根（tail1 骨）在身體中心後方幾公尺。
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/trex_sweep_shots.gd

const ACT_CHARGE_WIND := 3
const ACT_SWEEP := 4
const ACT_RECOVER := 7
## [名字, 這張要的 act, 進這個 act 多久（秒，trex 的 _act_t）]
const SHOTS := [
	["charge", ACT_CHARGE_WIND, 0.8],
	["sweep00", ACT_SWEEP, 0.0],
	["sweep33", ACT_SWEEP, 0.4 / 3.0],
	["sweep66", ACT_SWEEP, 0.4 * 2.0 / 3.0],
	["sweep100", ACT_SWEEP, 0.4],
	["recover", ACT_RECOVER, 0.3],
]
## [角度名, 相機位置（恐龍本地座標，後方是 +Z）, 看哪裡（本地）]
const ANGLES := [
	["top", Vector3(0, 26, 3), Vector3(0, 2, 0)],
	["back", Vector3(5, 9, 20), Vector3(0, 3, -2)],
]

var _f := 0
var _main: Node
var _cam: Camera3D
var _boss: Node3D
var _trex: Trex
var _ai := 0
var _si := 0
var _stage := 0
var _settle := 0

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f < 40:
		return false
	if _f == 40:
		_boss = root.get_tree().get_first_node_in_group(&"dino") as Node3D
		if _boss == null:
			push_error("找不到恐龍")
			return true
		_trex = _boss.get_node("Trex") as Trex
		_boss.global_position = _clear_spot()   # 沙盒恐龍可能卡在樹林裡，相機會被樹擋住，搬到空地
		_cam = Camera3D.new()
		_cam.fov = 50
		root.add_child(_cam)
		_cam.current = true
		_report_tail()
	_main.menu.visible = false
	var ang: Array = ANGLES[_ai]
	var b := _boss.global_transform
	_cam.look_at_from_position(b * ang[1], b * ang[2])
	var sh: Array = SHOTS[_si]
	match _stage:
		0:
			_trex.act = sh[1]   # 沙盒的恐龍（dino.gd）不會自己設 act，這裡直接排
			_stage = 1
		1:
			if _trex._last_act == sh[1] and _trex._act_t >= sh[2]:   # _last_act 換過才會把 _act_t 歸零
				_stage = 2
				_settle = 0
		2:
			_settle += 1
			if _settle >= 3:   # 相機移過去後等幾幀再拍，不然拍到上一幀的畫面
				_save(ang[0], sh[0])
				_stage = 0
				_si += 1
				if _si >= SHOTS.size():
					_si = 0
					_ai += 1
					if _ai >= ANGLES.size():
						return true
	return false

func _save(angle: String, shot: String) -> void:
	var path := OS.get_environment("OUT") + "/%s_%s.png" % [angle, shot]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("存 ", path)

## 找一塊平、四周 14 公尺內沒有樹幹和樹冠的地方（射線打地面、打周圍），回傳恐龍節點該站的位置
func _clear_spot() -> Vector3:
	var space := _boss.get_world_3d().direct_space_state
	var ex := [_boss.get_rid()]
	for ring in range(0, 90, 6):
		for k in range(maxi(1, ring / 3)):
			var a := TAU * float(k) / float(maxi(1, ring / 3))
			var x := sin(a) * ring
			var z := cos(a) * ring
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -100, z), 1, ex))
			if hit.is_empty() or hit.normal.y < 0.99:
				continue
			var g: float = hit.position.y
			var ok := true
			for dx in [-3.0, 3.0]:
				for dz in [-3.0, 3.0]:
					var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + dx, 100, z + dz), Vector3(x + dx, -100, z + dz), 1, ex))
					if h2.is_empty() or absf(h2.position.y - g) > 0.2:
						ok = false
			for dir in 12:
				var d := Vector3(sin(TAU * dir / 12.0), 0, cos(TAU * dir / 12.0))
				for hgt in [1.5, 4.0]:
					var o := Vector3(x, g + hgt, z)
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 14.0, 1, ex)):
						ok = false
			if ok:
				print("搬到空地 (%.1f, %.1f, %.1f)" % [x, g, z])
				return Vector3(x, g + 4.1, z)
	push_error("附近找不到空地，照原位置拍")
	return _boss.global_position

## 量尾根：tail1 骨在身體中心（恐龍節點的位置）後方幾公尺（水平）。草案 2.6 的 sweep_root_back 用這個數字
func _report_tail() -> void:
	var back := _boss.global_basis.z
	back.y = 0.0
	back = back.normalized()
	for bone in ["root", "spine1", "spine2", "tail1", "tail2", "tail3", "tail5"]:
		var d := _trex.bone_pos(bone) - _boss.global_position
		print("骨 %s：身體中心後方 %.2f 公尺（水平），高 %.2f 公尺" % [bone, d.dot(back), d.y])
	print("balance.csv sweep_root_back = %.2f" % Balance.num("sweep_root_back"))
