extends "res://tests/base.gd"
## 實地測（物理規則第二版）：在真的灰盒房子牆腳點一灘油火，看火燒多快、燒掉幾塊、主機兩幀最久隔幾毫秒
## 用法：godot --headless --path . --script tools/fire_probe.gd（HOUSES=幾棟、DUR=每棟看幾秒）

var m: Node
var houses: Array = []
var NH := int(OS.get_environment("HOUSES")) if OS.get_environment("HOUSES") != "" else 2
var DUR := float(OS.get_environment("DUR")) if OS.get_environment("DUR") != "" else 40.0
var hi := -1
var t := 0.0
var started := false
var wood0 := 0
var max_ms := 0.0
var max_fires := 0
var marks := {}
var last_us := 0

func _process(_d: float) -> bool:
	if not started:
		started = true
		var Main: GDScript = load("res://main.gd")
		Main.level_file = ""
		m = _isolated_match()
		_park(m)
		for tb: ToyBuild in m.map._toys:
			if tb.can_break and tb != m.map._party_house and tb.brick_count() > 200:
				houses.append(tb)
		houses = houses.slice(0, NH)
		_next()
		return false
	if hi >= houses.size():
		return false
	t += _d
	var fires := m.get_tree().get_nodes_in_group(&"oil_fire")
	var live := 0
	for f: Node in fires:
		if f.burning():
			live += 1
	max_fires = maxi(max_fires, live)
	var now := Time.get_ticks_usec()
	if t > 1.0 and last_us > 0:   # 頭一秒是蓋地圖、點火的載入。量兩幀之間隔多久（Performance 的值一秒才更新一次，不準）
		max_ms = maxf(max_ms, (now - last_us) / 1000.0)
	last_us = now
	for s in [10, 20, 40, 60, 90]:
		if t >= s and not marks.has(s):
			marks[s] = wood0 - _wood(houses[hi])
	if t >= DUR or (live == 0 and OilFire.queue.is_empty() and t > 3.0):
		print("房 %d：木頭 %d 塊，%s 秒燒掉 %s；同時最多 %d 灘火；兩幀最久隔 %.2f 毫秒；最後少了 %d 塊（燒成灰 %d、碎塊 %d）（%.1f 秒熄）；還在排隊 %d" % [hi, wood0, marks.keys(), marks.values(), max_fires, max_ms, wood0 - _wood(houses[hi]), houses[hi]._ash.size(), houses[hi].loose_ids().size(), t, OilFire.queue.size()])
		for f: Node in fires:
			f.free()
		OilFire.queue.clear()
		_next()
	return false

func _wood(h: ToyBuild) -> int:
	var n := 0
	for i in h.brick_count():
		if h.is_standing(i) and HitRules.burns(h._mt[i]):
			n += 1
	return n

func _next() -> void:
	hi += 1
	if hi >= houses.size():
		_free_map(m)
		quit(0)
		return
	var h: ToyBuild = houses[hi]
	wood0 = _wood(h)
	t = 0.0; max_ms = 0.0; max_fires = 0; marks = {}
	var lo := Vector3(INF, INF, INF)
	var at := Vector3.ZERO
	for i in h.brick_count():   # 最低的可燃塊旁邊點火
		var c := h.center_of(i)
		if HitRules.burns(h._mt[i]) and c.y < lo.y:
			lo = c
	at = Vector3(lo.x, h.global_position.y, lo.z)
	OilFire.spill(m.map, at, null)
