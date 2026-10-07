extends SceneTree
## 槍枝 L0 驗收：企劃《槍枝參數規格》第 09 節「交給 Wayne 的第一輪驗收」逐條寫成檢查。
## 換彈用真的計時器，要等時間，所以跟 test_battle.gd（同步跑）分開；遊戲時間加速 5 倍跑。
## 拉栓沒做完不能開、參數表、武器介紹在 test_battle.gd 的 _case_hunt_weapons。
##   godot --headless --path . --script tools/test_weapon_l0.gd

var _fails := 0
var m: Node
var me: Node
var vm: Node


func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)


var _frames := 0

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_run()   # 第一幀才開始：_initialize 的時候場景樹還沒在跑，節點拿不到 multiplayer
	if _frames > 60 * 60:
		printerr("FAIL: 驗收跑太久（中間有錯卡住了？）")
		quit(1)
	return false


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	Engine.time_scale = 5.0
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	me = m._add_player(m.COWBOY, 1)
	me.global_position = m._on_ground(Vector3(-20, 1.0, 15))
	vm = me.viewmodel
	await _wait(0.5)
	await _fire_interval()
	await _spread_vs_recoil()
	await _reload_counts()
	await _fire_during_reload()
	_rapid_clicks_no_fan()
	_ballistics()
	Engine.time_scale = 1.0
	print("槍枝 L0 驗收：" + ("通過" if _fails == 0 else "有 %d 項沒過" % _fails))
	quit(0 if _fails == 0 else 1)


## 左輪：連按不能突破射擊間隔
func _fire_interval() -> void:
	var rev: Weapon = vm._weapons[0]
	rev.mag = rev.capacity
	vm._fire_cooldown = 0.0
	vm.try_fire()
	for i in 5:
		vm.try_fire()
	_ck(rev.mag == rev.capacity - 1, "左輪連按：同一瞬間只能出一發")
	await _wait(rev.shot_gap() * 0.5)
	vm.try_fire()
	_ck(rev.mag == rev.capacity - 1, "左輪：擊發間隔還沒到不能開")
	await _wait(rev.shot_gap() * 0.6)
	vm.try_fire()
	_ck(rev.mag == rev.capacity - 2, "左輪：間隔到了就能開")
	rev.mag = rev.capacity


## 散布設為 0 仍看得到後座力；後座力設為 0 仍有散布
func _spread_vs_recoil() -> void:
	var rev: Weapon = vm._weapons[0]
	var keep := [rev.spread_hip, rev.spread_ads, vm.spread_per_shot, rev.recoil_pitch, rev.recoil_pitch_random, rev.recoil_yaw]
	var cam: Camera3D = vm._camera
	rev.spread_hip = 0.0
	rev.spread_ads = 0.0
	vm.spread_per_shot = 0.0
	vm.spread = 0.0
	await _wait(0.6)                       # 前面開的槍回正完
	var pitch: float = me.head.rotation.x
	vm._fire_cooldown = 0.0
	vm.try_fire()
	_ck(absf(me.head.rotation.x - pitch) > 0.001, "散布 0 還是要有後座力（準心往上抬）")
	_ck(vm._spread_direction(cam).is_equal_approx(-cam.global_transform.basis.z), "散布 0：子彈正正打在準心")

	rev.recoil_pitch = 0.0
	rev.recoil_pitch_random = 0.0
	rev.recoil_yaw = 0.0
	rev.spread_hip = 4.0
	await _wait(0.6)
	pitch = me.head.rotation.x
	var yaw: float = me.rotation.y
	vm._fire_cooldown = 0.0
	vm.try_fire()
	_ck(is_equal_approx(me.head.rotation.x, pitch) and is_equal_approx(me.rotation.y, yaw), "後座力 0：準心不動")
	vm.spread = 4.0
	var off := 0
	for i in 20:
		if not vm._spread_direction(cam).is_equal_approx(-cam.global_transform.basis.z):
			off += 1
	_ck(off > 15, "後座力 0 還是要有散布（20 發有 %d 發偏）" % off)
	rev.spread_hip = keep[0]
	rev.spread_ads = keep[1]
	vm.spread_per_shot = keep[2]
	rev.recoil_pitch = keep[3]
	rev.recoil_pitch_random = keep[4]
	rev.recoil_yaw = keep[5]
	rev.mag = rev.capacity


## 槍打空、已裝滿、備彈不足、中途停止、切換武器：子彈不會多也不會少
func _reload_counts() -> void:
	var rev: Weapon = vm._weapons[0]
	var shotgun: Weapon = vm._weapons[1]
	rev.mag = rev.capacity
	rev.reserve = 10
	vm.try_reload()
	_ck(not vm._reloading, "裝滿了不開始裝填")

	rev.mag = 0
	rev.reserve = 2
	vm.try_reload()
	await _wait(rev.reload_start + 2 * rev.reload_insert + rev.reload_end + 0.3)
	_ck(rev.mag == 2 and rev.reserve == 0 and not vm._reloading, "備彈只剩 2：裝 2 發就停（現在 %d＋%d）" % [rev.mag, rev.reserve])

	rev.mag = 0
	rev.reserve = 0
	vm.try_reload()
	_ck(not vm._reloading, "沒有備彈不開始裝填")

	# 中途停止（只停不開的做法）：已經放進去的留著，還沒放好的那顆不算
	vm.reload_fire_shoots = false
	rev.mag = 1
	rev.reserve = 10
	vm.try_reload()
	await _wait(rev.reload_start + rev.reload_insert * 1.5)
	vm.try_fire()
	_ck(rev.mag + rev.reserve == 11 and rev.mag == 2 and not vm._reloading,
		"中途停止：放好 1 顆、總數不變（現在 %d＋%d）" % [rev.mag, rev.reserve])
	vm.reload_fire_shoots = true

	# 裝填中換槍：這輪作廢，換回來也不會繼續偷裝
	rev.mag = 1
	rev.reserve = 10
	vm.try_reload()
	await _wait(rev.reload_start + rev.reload_insert * 1.5)
	vm.switch_weapon(2)
	await _wait(rev.reload_insert * 2.0)
	vm.switch_weapon(0)
	_ck(rev.mag == 2 and rev.reserve == 9, "裝填中換槍：只算已經放好的（現在 %d＋%d）" % [rev.mag, rev.reserve])

	# 整組裝填（散彈）：備彈 3 裝 1 發；備彈 0 不裝
	vm.switch_weapon(1)
	await _wait(0.4)
	shotgun.mag = 0
	shotgun.reserve = 3
	vm.try_reload()
	await _wait(shotgun.reload_time + 0.3)
	_ck(shotgun.mag == 1 and shotgun.reserve == 2, "散彈整組裝填：裝 1 發、備彈扣 1（現在 %d＋%d）" % [shotgun.mag, shotgun.reserve])
	shotgun.mag = 0
	shotgun.reserve = 0
	vm.try_reload()
	_ck(not vm._reloading, "散彈沒有備彈不裝填")
	vm.switch_weapon(0)


## 逐發裝填中按開火：槍先回正（左輪要關裝填門），回好了才射這一發，不在裝填姿勢半路開槍
func _fire_during_reload() -> void:
	var rev: Weapon = vm._weapons[0]
	rev.mag = 2
	rev.reserve = 10
	vm._fire_cooldown = 0.0
	vm.try_reload()
	await _wait(rev.reload_start + rev.reload_insert * 1.5)
	vm.try_fire()
	_ck(rev.mag == 3 and not vm._reloading, "裝填中按開火：先停下裝填、這一瞬間不開槍（現在 %d 發）" % rev.mag)
	await _wait(rev.ready_after_reload() * 0.5)
	_ck(rev.mag == 3, "槍還沒回正不能開")
	await _wait(rev.ready_after_reload() * 0.5 + 0.1)
	_ck(rev.mag == 2, "槍回正之後自動射出那一發（現在 %d 發）" % rev.mag)
	rev.mag = rev.capacity


## 快速連點不能變成搧擊錘連發：搧擊錘要持續按住夠久
func _rapid_clicks_no_fan() -> void:
	vm.ads = 0.0
	vm._fire_hold = 0.05          # 一下點擊只按住幾十毫秒
	_ck(not vm._wants_fan(), "快速連點（每下很短）不能算搧擊錘")
	vm._fire_hold = vm.fan_hold + 0.01
	_ck(not vm._wants_fan(), "搧擊錘關著（還沒技能）：按住不連射")
	vm.fan_enabled = true
	_ck(vm._wants_fan(), "搧擊錘打開後，持續按住夠久才是搧擊錘")
	vm.fan_enabled = false
	vm._fire_hold = 0.0


## 調低初速應該更晚命中、傷害不變；傷害衰減四段；超過最大判定距離不再命中
func _ballistics() -> void:
	var rifle: Weapon = vm._weapons[2]
	var steps := []
	for v: float in [rifle.muzzle_velocity, rifle.muzzle_velocity * 0.5]:
		var b := Bullet.new()
		b.origin = Vector3(0, 800, 0)
		b.vel = Vector3(0, 0, -v)
		b.weapon = rifle
		m.get_node(^"Arena").add_child(b)
		var n := 0
		while b._traveled < 100.0 and n < 10000:
			b.advance(1.0 / 120.0)
			n += 1
		steps.append(n)
		b.free()
	_ck(steps[1] > steps[0] * 1.8, "初速減半，飛 100 公尺要花快兩倍時間（%d vs %d 步）" % steps)
	var dmg: float = rifle.damage_at(80.0)
	var old_v := rifle.muzzle_velocity
	rifle.muzzle_velocity *= 0.5
	_ck(is_equal_approx(rifle.damage_at(80.0), dmg), "改初速不會改傷害")
	rifle.muzzle_velocity = old_v

	for w: Weapon in vm._weapons:
		var mid := (w.falloff_start + w.falloff_end) * 0.5
		_ck(is_equal_approx(w.damage_at(w.falloff_start), w.damage)
			and is_equal_approx(w.damage_at(mid), (w.damage + w.minimum_damage) * 0.5)
			and is_equal_approx(w.damage_at(w.falloff_end), w.minimum_damage)
			and is_equal_approx(w.damage_at(w.falloff_end + 10.0), w.minimum_damage),
			"%s：衰減起點全額、一半、終點最低、再遠也是最低" % w.display_name)

	var far := Bullet.new()
	far.origin = Vector3(0, 800, 0)
	far.vel = Vector3(0, 0, -rifle.muzzle_velocity)
	far.weapon = rifle
	m.get_node(^"Arena").add_child(far)
	var k := 0
	while not far.is_queued_for_deletion() and k < 10000:
		far.advance(1.0 / 120.0)
		k += 1
	_ck(far.is_queued_for_deletion() and far._traveled <= rifle.max_range + rifle.muzzle_velocity / 120.0 + 1.0,
		"超過最大判定距離，子彈要消失（飛了 %.0f 公尺）" % far._traveled)
	if is_instance_valid(far):
		far.free()
