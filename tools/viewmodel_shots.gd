extends SceneTree
## 第一人稱武器的姿勢截圖：開沙盒，拿出第 SLOT 把（1 起算），拍「拿著、舉槍瞄、換彈的幾個時刻、開槍」，存到 OUT。
## SET="hip_rotation=Vector3(1,0,0);grip_hand=Transform3D(...)"：拍之前臨時改這把槍的參數（Godot 的寫法，分號隔開），調姿勢不用一直改場景檔
##   SLOT=4 OUT=/tmp/pose godot --path . --resolution 1280x720 --script tools/viewmodel_shots.gd

var _f := 0
var _t := -1.0
var m: Node
var vm: Viewmodel
var _n := 0
const MARKS := [[0.0, "hip"], [0.8, "ads"], [1.6, "reload_25"], [2.0, "reload_50"], [2.7, "reload_75"], [3.4, "fire"]]


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f == 60:
		vm = m.players.get_node(^"1").viewmodel
		vm.switch_weapon(int(OS.get_environment("SLOT")) - 1 if OS.get_environment("SLOT") != "" else 0)
		for kv in OS.get_environment("SET").split(";", false):
			var k := kv.get_slice("=", 0).strip_edges()
			vm.weapon.set(k, str_to_var(kv.substr(kv.find("=") + 1)))
			if k == "grip_hand" or k == "support_hand":
				var hand := vm.weapon.find_child("HandGrip" if k == "grip_hand" else "HandSupport", true, false) as Node3D
				if hand:
					hand.transform = vm.weapon.get(k)
		var model := vm.weapon.get_node_or_null(vm.weapon.model_path) as Node3D
		if model:   # 改了腰射角度要重算靜止姿勢
			vm.weapon._rest_rot = model.rotation
	if _f > 60:
		m.menu.visible = false
	if _f == 140:
		_t = 0.0
	if _t < 0.0:
		return false
	_t += d
	var w := vm.weapon
	vm.ads = 1.0 if _t >= 0.5 and _t < 1.1 else (0.0 if _t >= 1.1 else vm.ads)
	if _t >= 1.15 and not vm._reloading and w.mag == w.capacity and _n == 2:
		w.mag = 0
		w.reserve = maxi(w.reserve, 1)
		vm.try_reload()
	if _t >= 3.2 and _n == 5:
		vm._fire_cooldown = 0.0
		if w.mag == 0:
			w.mag = 1
		vm.try_fire()
	if _n < MARKS.size() and _t >= MARKS[_n][0] + (0.05 if MARKS[_n][1] == "fire" else 0.0):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%d_%s.png" % [_n, MARKS[_n][1]])
		var me := m.players.get_node(^"1") as Node3D
		print("%s 抬頭 %.1f 度 手上那支 %s" % [MARKS[_n][1], rad_to_deg(me.head.rotation.x), w._hand_round.visible if w._hand_round else "-"])
		_n += 1
	return _n >= MARKS.size()
