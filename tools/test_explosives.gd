extends SceneTree
## 炸藥和炸彈長矛的檢查（規劃 docs/規劃/2026-10-04-炸藥與炸彈長矛.md）：
## 範圍傷害照距離遞減、隔牆炸不到、自己也會被炸；丟出去會落地停住、引信燒完才爆；按太久在手上爆；補給箱補滿。
## 物理引擎（Jolt）新加的東西要等下一個物理幀才查得到，所以跟 test_battle.gd（同一幀跑完）分開，每步之間等幾幀。
##   godot --headless --path . --script tools/test_explosives.gd

var _fails := 0
var _frames := 0
var m: Node
var me: Node3D
var vm: Viewmodel
var _at := Vector3.ZERO   # 一開始挑的空地（自己被炸過可能會被移走，之後都用這個點）


func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_run()   # 第一幀才開始：_initialize 的時候場景樹還沒在跑，節點拿不到 multiplayer
	if _frames > 60 * 60:
		printerr("FAIL: 跑太久（中間有錯卡住了？）")
		quit(1)
	return false


func _frames_pass(n := 3) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(20261004)   # 出生點是隨機的：固定下來，每次都在同一塊地（坡地上炸藥會一直滾）
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	me = m._add_player(m.COWBOY, 1)
	vm = me.viewmodel
	var at: Vector3 = m._spawn_point()
	_at = at
	me.global_position = at
	var near: Node3D = m._add_player(m.COWBOY, 5)
	var far: Node3D = m._add_player(m.COWBOY, 6)
	near.global_position = at + Vector3(12, 0, 0)
	far.global_position = at + Vector3(12, 0, 5.0)
	await _frames_pass()
	await _blast_falloff(near, far)
	await _wall_blocks(near)
	await _thrown_lands()
	await _arc_matches()
	await _cook_counts()
	await _cooked_in_hand()
	await _lance(near)
	await _lance_range()
	_crate()
	_resupply()
	print("炸藥、長矛檢查：" + ("通過" if _fails == 0 else "有 %d 項沒過" % _fails))
	quit(0 if _fails == 0 else 1)


## 中心 150，往外線性遞減到半徑 6 公尺；12 公尺外的自己不扣
func _blast_falloff(near: Node3D, far: Node3D) -> void:
	var r: float = Viewmodel.BLASTS[Viewmodel.KIND_DYNAMITE][0]
	var full: int = Viewmodel.BLASTS[Viewmodel.KIND_DYNAMITE][1]
	var center := func(n: Node3D) -> Vector3: return n.global_position + Vector3.UP * 0.9
	var blast: Vector3 = center.call(near) + Vector3(-2.0, 0, 0)
	var d_far: float = blast.distance_to(center.call(far))
	var want_near := int(round(full * (1.0 - 2.0 / r)))
	var want_far := int(round(full * (1.0 - d_far / r))) if d_far < r else 0
	vm._explode(blast, Viewmodel.KIND_DYNAMITE)
	_ck(near.max_hp - near.hp == want_near, "炸藥 2 公尺外扣 %d（扣了 %d）" % [want_near, near.max_hp - near.hp])
	_ck(far.max_hp - far.hp == want_far, "炸藥 %.1f 公尺外扣 %d（扣了 %d）" % [d_far, want_far, far.max_hp - far.hp])
	_ck(me.hp == me.max_hp, "炸藥 12 公尺外不扣（自己扣了 %d）" % (me.max_hp - me.hp))
	near.hp = near.max_hp
	far.hp = far.max_hp
	await _frames_pass(1)


func _wall_blocks(near: Node3D) -> void:
	m._solid_box(near.global_position + Vector3(-1.0, 1.5, 0), Vector3(0.3, 3.0, 3.0))
	await _frames_pass()
	vm._explode(near.global_position + Vector3(-2.0, 0.9, 0), Viewmodel.KIND_DYNAMITE)
	_ck(near.hp == near.max_hp, "隔著牆炸不到（扣了 %d）" % (near.max_hp - near.hp))


## 丟出去：落下來、停住、引信燒完才爆，爆一次（出生點旁邊常有柵欄、草捆，停在上面也算停住）
func _thrown_lands() -> void:
	var hits := []
	var dyn := Dynamite.new()
	dyn.vel = Vector3(3, 2, 0)
	dyn.fuse = 2.0
	dyn.on_explode = func(p: Vector3) -> void: hits.append(p)
	m.get_node(^"Arena").add_child(dyn)
	var start: Vector3 = m._on_ground(Vector3(_at.x - 6, 1.5, _at.z))   # 那一點的地面上 1.5 公尺（坡地：照自己的高度算會埋在土裡）
	dyn.global_position = start
	await create_timer(1.6).timeout
	_ck(hits.is_empty(), "引信還沒燒完不能爆")
	_ck(is_instance_valid(dyn) and dyn.vel == Vector3.ZERO, "丟出去 1.6 秒內要停下來（速度 %s）" % (dyn.vel if is_instance_valid(dyn) else "已經沒了"))
	_ck(is_instance_valid(dyn) and dyn.global_position.y < start.y - 0.5, "炸藥要落下來")
	await create_timer(0.7).timeout
	_ck(hits.size() == 1, "引信燒完爆一次（爆了 %d 次）" % hits.size())


## 拿著點燃的炸藥時畫的拋物線：預測的落點要跟真的丟出去第一次碰到東西的地方一樣
func _arc_matches() -> void:
	vm.dynamite = Viewmodel.DYNAMITE_MAX
	me.global_position = _at
	await _frames_pass()
	Input.action_press("throw")
	vm._light_dynamite()
	vm._update_cook(0.1)
	var predicted := vm.arc_land
	_ck(vm._arc != null and vm._arc.visible and predicted != Vector3.INF, "拿著點燃的炸藥要畫拋物線和落點")
	Input.action_release("throw")
	vm._update_cook(0.0)
	_ck(not vm._arc.visible, "丟出去之後拋物線要收掉")
	var thrown: Dynamite = null
	for c in m.get_node(^"Arena").get_children():
		if c is Dynamite and not c.is_queued_for_deletion():
			thrown = c
	if thrown == null or predicted == Vector3.INF:
		_ck(false, "沒丟出去或沒有落點")
		return
	thrown.on_explode = Callable()
	var first := Vector3.INF
	for i in 300:   # 等它第一次碰到東西（速度往上彈或停下）
		var vy := thrown.vel.y
		await physics_frame
		if not is_instance_valid(thrown) or thrown.vel.y > vy or thrown.vel == Vector3.ZERO:
			first = thrown.global_position if is_instance_valid(thrown) else Vector3.INF
			break
	_ck(first != Vector3.INF and first.distance_to(predicted) < 0.6, "落點預測 %s、實際 %s" % [predicted, first])
	if is_instance_valid(thrown):
		thrown.queue_free()
	await _frames_pass(1)


## 按著 1.5 秒才放開：丟出去的引信只剩 2.5 秒（按著的時間要扣掉）
func _cook_counts() -> void:
	vm.dynamite = Viewmodel.DYNAMITE_MAX
	Input.action_press("throw")
	vm._light_dynamite()
	vm._update_cook(1.5)
	Input.action_release("throw")
	vm._update_cook(0.0)
	var thrown: Dynamite = null
	for c in m.get_node(^"Arena").get_children():
		if c is Dynamite and not c.is_queued_for_deletion():
			thrown = c
	_ck(thrown != null and absf(thrown.fuse - (Viewmodel.FUSE - 1.5)) < 0.05, "按著 1.5 秒再丟，引信剩 %.1f 秒（實際 %s）" % [Viewmodel.FUSE - 1.5, thrown.fuse if thrown else "沒丟出去"])
	if thrown:
		thrown.on_explode = Callable()   # 這根不用真的炸
		thrown.queue_free()
	await _frames_pass(1)


## 拿太久在手上爆，自己會被炸，也用掉一根
func _cooked_in_hand() -> void:
	vm.dynamite = Viewmodel.DYNAMITE_MAX
	vm._light_dynamite()
	vm._cook = Viewmodel.FUSE - 0.01
	vm._update_cook(0.02)
	_ck(me.hp < me.max_hp, "炸藥拿太久會在手上爆，自己也被炸")
	_ck(vm.dynamite == Viewmodel.DYNAMITE_MAX - 1 and vm._cook < 0.0, "在手上爆掉也用掉一根")
	await _frames_pass(1)


## 炸彈長矛（4 號）：射出去的魚叉打中人＝直接 40 再加爆炸；射掉之後管裡看不到魚叉；R 裝回來
func _lance(target: Node3D) -> void:
	vm.switch_weapon(3)
	var w: Weapon = vm.weapon
	_ck(w.display_name == "炸彈長矛" and w.harpoon != null, "4 號是炸彈長矛（現在 %s）" % w.display_name)
	await create_timer(0.6).timeout   # 拿出來的動作
	target.hp = target.max_hp
	_ck(w.harpoon.visible, "裝著魚叉時發射管裡看得到")
	var from: Vector3 = target.global_position + Vector3(0.5, 6.0, 0)   # 從正上方往下射：橫著射的話中間可能剛好有柵欄、木箱（擺設是隨機的）
	var dir := (target.global_position + Vector3.UP * 1.0 - from).normalized()
	w.mag -= 1
	vm._launch(3, from, PackedVector3Array([dir]), false)
	await create_timer(0.8).timeout
	var lost: int = target.max_hp - target.hp
	_ck(lost > int(w.damage), "魚叉打中人：直接 %d 再加爆炸（扣了 %d）" % [int(w.damage), lost])
	_ck(not w.harpoon.visible, "射掉之後管裡沒有魚叉")
	var reserve := w.reserve
	vm._reloading = false
	vm.try_reload()
	await create_timer(w.reload_time + 0.6).timeout
	_ck(w.mag == 1 and w.reserve == reserve - 1, "R 裝一支魚叉（彈匣 %d、備用 %d）" % [w.mag, w.reserve])
	w.reserve = 0
	vm.dynamite = Viewmodel.DYNAMITE_MAX
	_ck(vm.resupply() and w.reserve == w.starting_reserve, "補給箱也補魚叉")
	vm.switch_weapon(0)
	await create_timer(0.6).timeout


## 魚叉最遠 25 公尺：沒打到東西就在射程盡頭空炸
func _lance_range() -> void:
	var w: Weapon = vm._weapons[3]
	_ck(is_equal_approx(w.max_range, 25.0), "炸彈長矛射程 25 公尺（現在 %s）" % w.max_range)
	var at := []
	var b := Bullet.new()
	b.origin = _at + Vector3(0, 40, 0)   # 往天上射：一定打不到東西
	b.vel = Vector3.UP * w.muzzle_velocity
	b.weapon = w
	b.on_impact = func(p: Vector3) -> void: at.append(p)
	m.get_node(^"Arena").add_child(b)
	await create_timer(1.5).timeout
	_ck(at.size() == 1 and absf(at[0].distance_to(b.origin if is_instance_valid(b) else _at + Vector3(0, 40, 0)) - 25.0) < 2.0,
		"魚叉飛 25 公尺空炸一次（%s）" % [at])


## 場上的木箱都是補給箱：F 補滿，同一個箱子要等冷卻
func _crate() -> void:
	var crates := m.get_node(^"Arena").find_children("*", "SupplyCrate", true, false)
	_ck(crates.size() >= 5, "場上要有補給箱（木箱，現在 %d 個）" % crates.size())
	if crates.is_empty():
		return
	var c: SupplyCrate = crates[0]
	_ck(c.prompt.contains("補給"), "看著補給箱要提示補給（現在「%s」）" % c.prompt)
	vm.dynamite = 0
	c.interact(me)
	_ck(vm.dynamite == Viewmodel.DYNAMITE_MAX, "按 F 補滿炸藥（現在 %d）" % vm.dynamite)
	vm.dynamite = 0
	c.interact(me)
	_ck(vm.dynamite == 0, "同一個箱子剛補過不能再補")
	_ck(c.prompt.contains("秒"), "冷卻中要提示還要幾秒（現在「%s」）" % c.prompt)


func _resupply() -> void:
	_ck(vm.resupply() and vm.dynamite == Viewmodel.DYNAMITE_MAX, "補給箱把炸藥補滿")
	_ck(not vm.resupply(), "滿的時候補不到東西")
	vm.set_infinite()
	_ck(vm.dynamite < 0, "沙盒炸藥無限")
