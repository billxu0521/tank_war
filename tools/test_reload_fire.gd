extends SceneTree
## 換彈中、剛換完就按開槍：子彈一定要等槍回正（換彈姿勢收完）才射出去。
## 每把逐發／整組的槍各測兩種：換到一半按開槍、換完那一刻按開槍。射出那一幀量換彈姿勢（0 = 回正）。
##   godot --headless --fixed-fps 60 --path . --script tools/test_reload_fire.gd
const SLOTS := [1, 2]   # 散彈、步槍（Viewmodel 的槍序：0 左輪、1 散彈、2 步槍）
var m: Node
var vm: Viewmodel
var _f := 0
var _case := 0          # 第幾個測試：slot × 2（換到一半／換完）
var _t := 0.0
var _pressed := false
var _shot_pose := -1.0
var _mag0 := 0
var _fail := 0


func _initialize() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f < 60:
		return false
	if vm == null:
		vm = m.players.get_node(^"1").viewmodel
		_start()
		return false
	_t += d
	var w := vm.weapon
	var mid := _case % 2 == 0
	# 換到一半：裝填 0.3 秒後按；換完：一換完（_reloading 變 false）那一幀就按
	if not _pressed and ((mid and _t > 0.3) or (not mid and not vm._reloading and _t > 0.1)):
		_pressed = true
		_mag0 = w.mag
		vm.try_fire()
	if _pressed and _shot_pose < 0.0 and w.mag < _mag0:
		_shot_pose = w._reload_pose
	if _pressed and (_shot_pose >= 0.0 or _t > 6.0):
		var name := "%s %s" % [w.name, "換到一半開槍" if mid else "剛換完開槍"]
		if w.reload_type == Weapon.Reload.WHOLE and mid:
			print("SKIP  %s：整組裝填中不能開槍" % name)
		elif _shot_pose < 0.0:
			print("FAIL  %s：沒有射出去" % name)
			_fail += 1
		elif _shot_pose > 0.01:
			print("FAIL  %s：射出時換彈姿勢還有 %.2f（要回正 0）" % [name, _shot_pose])
			_fail += 1
		else:
			print("PASS  %s：回正才射（換彈開始後 %.2f 秒射出）" % [name, _t])
		_case += 1
		if _case >= SLOTS.size() * 2:
			print("換彈開槍檢查：%s" % ("通過" if _fail == 0 else "%d 項沒過" % _fail))
			quit(1 if _fail else 0)
			return true
		_start()
	return false


func _start() -> void:
	vm.cancel_reload()
	vm.switch_weapon(SLOTS[_case / 2])
	vm._fire_cooldown = 0.0
	vm._fire_queued = false
	var w := vm.weapon
	w.mag = maxi(w.capacity - 3, 0)   # 留幾發：換到一半開槍時才有子彈（散彈只裝 1 發，從空的開始）
	w.reserve = 30
	vm.try_reload()
	_t = 0.0
	_pressed = false
	_shot_pose = -1.0
