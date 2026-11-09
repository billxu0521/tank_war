## 用法：godot --headless --path . --script tools/debris_walk.gd（NOFLY=1 專用伺服器模式、HOUSES=幾棟、DIRS=每棟幾個方向、DBG=1/2 印卡住和跑太慢的碰撞）
extends "res://tests/base.gd"
## 實地測：駕駛尼諾拉跑步撞穿一棟真的灰盒房子，再在碎塊堆裡來回走/跑，量順不順
## 參數（環境變數）：NOFLY=1 專用伺服器模式（碎塊直接落地）；HOUSES=幾棟；DIRS=每棟幾個方向

var m: Node
var b: Node3D
var houses: Array = []
var hi := 0
var di := 0
var DIRS := int(OS.get_environment("DIRS")) if OS.get_environment("DIRS") != "" else 3
var NH := int(OS.get_environment("HOUSES")) if OS.get_environment("HOUSES") != "" else 3
var center := Vector3.ZERO
var start := Vector3.ZERO
var far := Vector3.ZERO
# 每一趟：[名稱, 跑不跑, 從, 到, 秒數上限]
var legs: Array = []
var li := 0
var t := 0.0
var started := false
# 每趟量測
var stuck_t := 0.0
var slow_run := 0.0
var max_dy := 0.0
var bumps := 0
var kicks := 0
var smashed := 0
var last_y := 0.0
var last_vy := 0.0
var standing0 := 0
var max_ms := 0.0
var rows: Array = []

func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	ToyBuild.no_flight = OS.get_environment("NOFLY") == "1"
	var Main: GDScript = load("res://main.gd")
	Main.level_file = ""
	m = _isolated_match()
	_park(m)
	for tb: ToyBuild in m.map._toys:
		if tb.can_break and tb != m.map._party_house and tb.brick_count() > 200:
			houses.append(tb)
	houses = houses.slice(0, NH)
	b = m.spawn_boss()
	b.set_physics_process(false)
	b._sync_mask()
	b.pilot = 1
	print("房子 %d 棟、方向 %d 個、專用伺服器模式=%s" % [houses.size(), DIRS, ToyBuild.no_flight])
	_setup_run()
	return false

func _standing() -> int:
	var n := 0
	for tb: ToyBuild in m.map._toys:
		for i in tb.brick_count():
			if tb.is_standing(i):
				n += 1
	return n

func _setup_run() -> void:
	if hi >= houses.size():
		_report()
		return
	var h: ToyBuild = houses[hi]
	center = Vector3.ZERO
	for i in h.brick_count():
		center += h.center_of(i)
	center /= h.brick_count()
	var a := TAU * float(di) / float(DIRS) + 0.3 * hi
	var dir := Vector3(cos(a), 0, sin(a))
	start = center - dir * 22.0
	far = center + dir * 16.0
	b.global_position = m.boss_on_ground(start)
	b.velocity = Vector3.ZERO
	b.stamina = b.STAMINA_MAX
	b.exhausted = false
	legs = [
		["跑撞房子", true, start, far, 8.0],
		["走回碎塊", false, far, start, 12.0],
		["跑穿碎塊", true, start, far, 8.0],
		["走過碎塊", false, far, start, 12.0],
		["跑回碎塊", true, start, far, 8.0],
	]
	li = 0
	_begin_leg()

func _begin_leg() -> void:
	t = 0.0
	stuck_t = 0.0; slow_run = 0.0; max_dy = 0.0; bumps = 0; kicks = 0; max_ms = 0.0
	last_y = b.global_position.y
	last_vy = 0.0
	standing0 = _standing()
	b.stamina = b.STAMINA_MAX   # 體力不是這次要測的
	b.exhausted = false

func _physics_process(delta: float) -> bool:
	if b == null or hi >= houses.size() or legs.is_empty():
		return false
	var L: Array = legs[li]
	var to: Vector3 = L[3]
	var d := to - b.global_position
	d.y = 0
	var dir := d.normalized()
	b.rotation.y = atan2(-dir.x, -dir.z)
	b.stamina = b.STAMINA_MAX
	var now := Time.get_ticks_msec()
	var t0 := Time.get_ticks_usec()
	b._move(dir, L[1], delta)
	max_ms = maxf(max_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	t += delta
	# 踢了幾次：這一幀被記上踢的時間的碎塊
	for tb: ToyBuild in m.map._toys:
		for k in tb._kick_t:
			if int(tb._kick_t[k]) >= now:
				kicks += 1
	var hv := Vector2(b.velocity.x, b.velocity.z).length()
	if hv < 1.0:
		stuck_t += delta
		if OS.get_environment("DBG") == "1" and int(t / delta) % 30 == 0:
			var cs := []
			for k in b.get_slide_collision_count():
				var col: KinematicCollision3D = b.get_slide_collision(k)
				var c: Object = col.get_collider()
				cs.append("%s%s n=%s" % [c.get_class(), " piece" if (c as Node).is_in_group(&"toy_piece") else (" toy" if c is ToyBuild else " " + str((c as Node).name)), col.get_normal().snapped(Vector3.ONE * 0.01)])
			print("卡 " + str(hi) + str(di) + " %s t=%.1f pos=%s floor=%s wall=%s vel=%s %s" % [legs[li][0], t, b.global_position.snapped(Vector3.ONE*0.1), b.is_on_floor(), b.is_on_wall(), b.velocity.snapped(Vector3.ONE*0.1), cs])
	if L[1] and hv < b.RUN * 0.5:
		slow_run += delta
		if OS.get_environment("DBG") == "2" and int(t / delta) % 20 == 0:
			var cs := []
			for k in b.get_slide_collision_count():
				var col: KinematicCollision3D = b.get_slide_collision(k)
				var c: Object = col.get_collider()
				cs.append("%s n=%s" % [("piece" if (c as Node).is_in_group(&"toy_piece") else ("toy" if c is ToyBuild else str((c as Node).name))), col.get_normal().snapped(Vector3.ONE * 0.01)])
			print("慢 %d%d %s t=%.1f hv=%.1f stag=%.2f fresh=%.2f %s" % [hi, di, L[0], t, hv, b._stagger, b._charge_fresh, cs])
	var y := b.global_position.y
	var vy := (y - last_y) / delta
	max_dy = maxf(max_dy, absf(y - last_y))
	if absf(vy - last_vy) > 6.0 and t > 0.1:   # 垂直速度一幀變超過 6 公尺／秒＝顛一下
		bumps += 1
	last_y = y
	last_vy = vy
	if d.length() < 2.0 or t >= L[4]:
		var left := d.length()
		var total: float = (L[3] - L[2]).length()
		smashed = standing0 - _standing()
		rows.append([hi, di, L[0], left < 2.0, t, left, stuck_t, slow_run, bumps, max_dy, kicks, smashed, max_ms, total])
		li += 1
		if li >= legs.size():
			di += 1
			if di >= DIRS:
				di = 0
				hi += 1
			_setup_run()
		else:
			_begin_leg()
	return false

func _report() -> void:
	print("房 方向 趟　　　 到了 秒數 剩(m) 卡(秒) 跑太慢(秒) 顛 最大一幀上下(m) 踢 拆 最慢一步(ms)")
	for r in rows:
		print("%d  %d  %s  %s  %4.1f  %4.1f  %4.1f  %4.1f  %2d  %.2f  %3d  %3d  %5.1f" % [r[0], r[1], r[2], "是" if r[3] else "否", r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12]])
	legs = []
	_free_map(m)
	quit(0)
