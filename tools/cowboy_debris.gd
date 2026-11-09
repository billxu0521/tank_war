extends "res://tests/base.gd"
## 實地測：拆掉幾棟真的灰盒房子，獵人從各個方向穿過碎塊堆（擋住就照玩家的習慣：先翻越、翻不了就跳），量走不走得過去
## 用法：godot --headless --path . --script tools/cowboy_debris.gd（HOUSES=幾棟、DIRS=每棟幾個方向、NOFLY=1 專用伺服器模式）

var m: Node
var c: Node3D
var houses: Array = []
var DIRS := int(OS.get_environment("DIRS")) if OS.get_environment("DIRS") != "" else 6
var NH := int(OS.get_environment("HOUSES")) if OS.get_environment("HOUSES") != "" else 3
var hi := 0
var di := 0
var t := 0.0
var wait := 0.0
var started := false
var center := Vector3.ZERO
var to := Vector3.ZERO
var stuck := 0.0
var block_t := 0.0
var jumps := 0
var vaults := 0
var rows: Array = []
var detour := 0.0
var detour_side := 1.0
var detours := 0
var stuck_run := 0.0

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
	for h: ToyBuild in houses:   # 全部拆掉（等級 3 的地基留著），碎塊往外飛
		var cc := _center(h)
		h.smash(func(_p: Vector3) -> bool: return true, 2, cc + Vector3.DOWN * 2.0)
		h.smash(func(_p: Vector3) -> bool: return true, 2, cc + Vector3.DOWN * 2.0)
	c = m._add_player(m.COWBOY, 2)
	c.set_physics_process(false)
	wait = ToyBuild.SETTLE_TIME + 1.0
	print("獵人 跳 %.2f 公尺；%d 棟 × %d 方向；專用伺服器模式=%s" % [c.jump_velocity * c.jump_velocity / (2.0 * 9.8), houses.size(), DIRS, ToyBuild.no_flight])
	return false

func _center(h: ToyBuild) -> Vector3:
	var s := Vector3.ZERO
	for i in h.brick_count():
		s += h.center_of(i)
	return s / h.brick_count()

func _setup() -> void:
	var h: ToyBuild = houses[hi]
	center = _center(h)
	var a := TAU * float(di) / float(DIRS) + 0.4 * hi
	var dir := Vector3(cos(a), 0, sin(a))
	var start := center - dir * 14.0
	to = center + dir * 14.0
	c.global_position = m._on_ground(start) + Vector3.UP * 1.0
	c.velocity = Vector3.ZERO
	c.stamina = c.max_stamina if "max_stamina" in c else 100.0
	t = 0.0; stuck = 0.0; block_t = 0.0; jumps = 0; vaults = 0; detours = 0; detour = 0.0; stuck_run = 0.0

func _physics_process(delta: float) -> bool:
	if c == null:
		return false
	if wait > 0.0:
		wait -= delta
		if wait <= 0.0:
			_setup()
		return false
	if hi >= houses.size():
		return false
	t += delta
	if c.vaulting:
		return false
	var d := to - c.global_position
	d.y = 0.0
	var dir := d.normalized()
	if detour > 0.0:   # 繞路中：往旁邊斜 70 度走
		detour -= delta
		dir = dir.rotated(Vector3.UP, 1.2 * detour_side)
	elif stuck_run > 1.5:   # 卡超過 1.5 秒（跳、翻都不行）：像玩家一樣往旁邊繞
		stuck_run = 0.0
		detour = 1.2
		detour_side = -detour_side
		detours += 1
	c.rotation.y = atan2(-dir.x, -dir.z)
	if not c.is_on_floor():
		c.velocity += c.get_gravity() * delta
	c._move_flat(dir * c.walk_speed, delta)
	var hv := Vector2(c.velocity.x, c.velocity.z).length()
	stuck_run = stuck_run + delta if hv < 0.5 else 0.0
	if hv < 0.5:
		stuck += delta
		if OS.get_environment("DBG") == "1" and int(t / delta) % 60 == 0:
			var sp := c.get_world_3d().direct_space_state
			var ahead := c.global_position + dir * 0.7
			var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 4.0, ahead + Vector3.DOWN * 3.0, 1, [c.get_rid()]))
			var top: float = (hit.position.y - c.global_position.y) if not hit.is_empty() else -99.0
			var what: String = "?" if hit.is_empty() else ("碎塊" if (hit.collider as Node).is_in_group(&"toy_piece") else ("積木" if hit.collider is ToyBuild else str((hit.collider as Node).name)))
			print("卡 %d%d t=%.1f 地上=%s 牆=%s 前方高 %.2f（%s）" % [hi, di, t, c.is_on_floor(), c.is_on_wall(), top, what])
	# 玩家的習慣：被擋住 0.15 秒就按跳（往前推著按＝先試翻越）
	if (c.is_on_floor() or (c.has_method(&"_wedged") and c._wedged())) and hv < c.walk_speed * 0.5:
		block_t += delta
		if block_t > 0.15:
			block_t = 0.0
			if c.try_vault(true):
				vaults += 1
			else:
				c.velocity.y = c.jump_velocity
				jumps += 1
	else:
		block_t = 0.0
	if d.length() < 1.0 or t > 20.0:
		rows.append([hi, di, d.length() < 1.0, t, d.length(), stuck, jumps, vaults, detours])
		di += 1
		if di >= DIRS:
			di = 0
			hi += 1
		if hi >= houses.size():
			_report()
		else:
			_setup()
	return false

func _report() -> void:
	var ok := 0
	print("房 方向 到了 秒數 剩(m) 卡(秒) 跳 翻越 繞路")
	for r in rows:
		ok += 1 if r[2] else 0
		print("%d  %d  %s  %4.1f  %4.1f  %4.1f  %2d  %2d  %2d" % [r[0], r[1], "是" if r[2] else "否", r[3], r[4], r[5], r[6], r[7], r[8]])
	print("走得過去：%d / %d" % [ok, rows.size()])
	c = null
	_free_map(m)
	quit(0)
