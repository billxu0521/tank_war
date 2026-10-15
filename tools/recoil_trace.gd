extends SceneTree
## 後座力曲線記錄：沙盒裡每把槍各開一槍（腰射、隨機歸零），每幀記準心抬了幾度、槍模型上揚幾度，存成 JSON。
## 畫圖用 tools/recoil_plot.py。
##   OUT=/tmp/recoil.json godot --headless --path . --fixed-fps 120 --script tools/recoil_trace.gd

const FRAMES := 72   # 0.6 秒

var _f := 0
var _main: Node
var _vm: Node
var _i := 0
var _t := -1
var _pitch0 := 0.0
var _out := {}
var _rows: Array = []


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		_main._on_sandbox_pressed()
	if _f < 30:
		return false
	if _vm == null:
		_vm = _main.players.get_node(^"1").viewmodel
	var w: Weapon = _vm._weapons[_i]
	if _t < 0:
		if _vm._index != _i:
			_vm.switch_weapon(_i)
		if _vm._fire_cooldown > 0.0 or _vm._anim_lock > 0.0 or w.mag == 0:
			return false
		w.recoil_pitch_random = 0.0
		w.recoil_yaw = 0.0
		_pitch0 = _vm._player.head.rotation.x
		_rows = []
		_vm.try_fire()
		_t = 0
	var model_x: float = w._model.rotation.x - w._rest_rot.x if w._model else 0.0
	_rows.append([_t / 120.0, rad_to_deg(_vm._player.head.rotation.x - _pitch0), rad_to_deg(model_x)])
	_t += 1
	if _t > FRAMES:
		_out[w.display_name] = {"pitch": w.recoil_pitch, "rows": _rows}
		_t = -1
		_i += 1
		if _i >= _vm._weapons.size():
			var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
			f.store_string(JSON.stringify(_out))
			return true
	return false
