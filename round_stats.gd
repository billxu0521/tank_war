class_name RoundStats
extends RefCounted
## 派對每回合的「像不像真人」指標（docs/企劃/2026-11-13-電腦牛仔像真人.md「怎麼量」）。
## 只在主機算：party.step 遊戲中每幀叫 tick，_end_round 叫 report，印一段「回合指標」到記錄檔。電腦和真人同一個格式。
## 全部用輪詢（看信封開了沒、試過的表、命數、彈匣），不在別的檔案插勾子。
## ponytail: 開槍、命中、卡牆、換動作只有電腦算得到（真人的槍在他自己那台），真人印「-」

const SPLIT_SECONDS := 30.0   # 開局多久內看「分頭」
const NEAR_CARD := 8.0        # 走到信封幾公尺內算「去了這張」
const NEAR_DINO := 15.0
const STUCK_SPEED := 0.5      # 想走（不是站著等）卻比這個慢＝卡住
const STUCK_LOG := 5.0        # 連續卡這麼久印一行「卡住」
const STUCK_LONG := 20.0      # 總表數「卡超過 20 秒」幾次
const STUCK_GRACE := 0.5      # 沒卡這麼久才算脫困（速度一閃一閃不算）
const SAFE_NEAR := 30.0       # 恐龍離保險箱幾公尺內算「守著」

var t := 0.0                  # 這回合遊戲時間（準備階段不算）
var first_card := -1.0        # 第一張牌被看的時刻
var open_at := -1.0
var tries: Array = []         # 每次試開被記進表的時刻
var last: Dictionary = {}     # 上一回合的結果（bot_sim 讀）
var _tried := 0
var _cow := {}                # 牛仔編號 -> 這回合的數字（見 _row）
var stuck_by := {}            # 動作 -> 卡住幾秒（看卡在哪種路上，決定要不要接導航網格）
var stuck_long := 0           # 這回合連續卡超過 STUCK_LONG 的次數
var dino_safe := 0.0          # 恐龍離保險箱 SAFE_NEAR 內的秒數
var safe_t := 0.0             # 有保險箱的遊戲秒數（佔比的分母）
var open_dist := -1.0         # 開箱那一刻恐龍離箱子幾公尺
var loots := 0                # 這回合搜刮倒地的尼諾拉幾次（看 boss.looted 變多）
var meals := 0                # 這回合吃了幾塊恐龍肉（看 meat_left 往上跳）
var _looted := 0


func reset() -> void:
	t = 0.0
	first_card = -1.0
	open_at = -1.0
	tries.clear()
	stuck_by = {}
	stuck_long = 0
	dino_safe = 0.0
	safe_t = 0.0
	open_dist = -1.0
	loots = 0
	meals = 0
	_looted = 0
	_tried = 0
	_cow.clear()


func _row(c: Node) -> Dictionary:
	var id := c.name.to_int()
	if not _cow.has(id):
		_cow[id] = {"bot": bool(c.get(&"bot")), "deaths": 0, "near": 0.0, "alive": 0.0, "stuck": 0.0,
			"changes": 0, "act": "", "shots": 0, "hits": 0, "mag": -1, "hit_until": 0, "first_card": -2,
			"run": 0.0, "free": 0.0, "meat_left": 0.0}
	return _cow[id]


func tick(m: Node, p: Node, delta: float) -> void:
	t += delta
	if first_card < 0.0 and (p.env_open[0] or p.env_open[1]):
		first_card = t
	var s: Node = m.safe
	if s.on:
		var n := Array(s.tried).count(1)
		if n > _tried:
			tries.append(t)
			_tried = n
	var dino: Node3D = m._boss()
	if s.on:
		if s.open and open_at < 0.0:
			open_at = t
			if dino:
				open_dist = dino.global_position.distance_to(s.global_position)
		safe_t += delta
		if dino and dino.global_position.distance_to(s.global_position) < SAFE_NEAR:
			dino_safe += delta
	if dino:   # 搜刮：looted 每次倒地清掉，變多的部分就是搜完的次數
		var n: int = dino.looted.size()
		if n > _looted:
			loots += n - _looted
		_looted = n
	for c: Node in m.players.get_children():
		if c.is_in_group(&"dino") or not c is Cowboy:
			continue
		var r := _row(c)
		r.alive += delta
		if c.meat_left > r.meat_left + 0.5:   # 吃完才開始回血：剩幾秒往上跳一次算吃一塊
			meals += 1
		r.meat_left = c.meat_left
		if dino and (c as Node3D).global_position.distance_to(dino.global_position) < NEAR_DINO:
			r.near += delta
		if t < SPLIT_SECONDS and int(r.first_card) == -2:
			for i in 2:
				if s.on and c._flat_to(p.env_pos[i]) < NEAR_CARD:
					r.first_card = i
		if not r.bot:
			continue
		var cb := c as Cowboy
		# 開槍：彈匣少一發算一槍（散彈一槍十幾顆也算一槍）；命中：準心閃紅的時刻換了算一次
		var mag: int = cb.viewmodel.weapon.mag
		if r.mag >= 0 and mag < r.mag:
			r.shots += r.mag - mag
		r.mag = mag
		if cb.hit_until != r.hit_until:
			r.hits += 1
			r.hit_until = cb.hit_until
		var act := _act(cb, m, p)
		if act != r.act:
			if r.act != "":
				r.changes += 1
			r.act = act
		var hold: bool = cb._bot_should_hold(m)
		var to := cb._bot_goal(m) - cb.global_position
		if not hold and Vector2(to.x, to.z).length() > 1.5 and Vector2(cb.velocity.x, cb.velocity.z).length() < STUCK_SPEED and _on_wall(cb):
			r.stuck += delta
			stuck_by[act] = float(stuck_by.get(act, 0.0)) + delta
			r.free = 0.0
			var was: float = r.run
			r.run += delta
			if was < STUCK_LOG and r.run >= STUCK_LOG:
				_log_stuck(cb, p, act, to)
			if was < STUCK_LONG and r.run >= STUCK_LONG:
				stuck_long += 1
				print("卡住 第%d回合 %s 卡超過 %.0f 秒（%s）" % [p.round_index + 1, p.names.get(cb.name.to_int(), cb.name), STUCK_LONG, act])
		elif r.run > 0.0:
			r.free += delta
			if r.free > STUCK_GRACE:
				r.run = 0.0


## 連續卡 STUCK_LOG 秒印一行：誰、動作、位置、目標、離導航網格多遠、撞到什麼和牆的方向
func _log_stuck(c: Cowboy, p: Node, act: String, to: Vector3) -> void:
	var pos := c.global_position
	var map := c.get_world_3d().navigation_map
	var nav := "-"
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		nav = "%.1f 公尺" % pos.distance_to(NavigationServer3D.map_get_closest_point(map, pos))
	var hit := "-"
	for i in c.get_slide_collision_count():
		var k := c.get_slide_collision(i)
		if absf(k.get_normal().y) < 0.7 and not k.get_collider() is Fighter:
			var o := k.get_collider() as Node
			var n := k.get_normal()
			hit = "%s 牆朝 (%.1f, %.1f)" % [o.name if o else "?", n.x, n.z]
			break
	var g := pos + to
	print("卡住 第%d回合 %s 卡 %.0f 秒 動作 %s 在 (%.1f, %.1f) 目標 (%.1f, %.1f) 離導航網格 %s 撞到 %s" % [p.round_index + 1,
		p.names.get(c.name.to_int(), c.name), STUCK_LOG, act, pos.x, pos.z, g.x, g.z, nav, hit])


## 頂著牆、房子、碎塊（不算頂著人或恐龍：那是被擋，不是路不通）
static func _on_wall(c: CharacterBody3D) -> bool:
	for i in c.get_slide_collision_count():
		var k := c.get_slide_collision(i)
		if absf(k.get_normal().y) < 0.7 and not k.get_collider() is Fighter:
			return true
	return false


## 這個電腦在做什麼：有 bot_action（打分數版）就用它，沒有就照目標猜（舊版）
func _act(c: Cowboy, m: Node, p: Node) -> String:
	var a = c.get(&"bot_action")
	if a != null:
		return str(a)
	var goal: Vector3 = c._bot_goal(m)
	if m.safe.on and m.safe.locked():
		for i in 2:
			if goal == p.env_pos[i]:
				return "看牌%d" % i
		return "試密碼"
	if m.egg.carrier == c.name.to_int():
		return "撤離"
	return "撿蛋" if m.egg.carrier == 0 else "追蛋"


## 有人死了（party.on_died 叫）
func died(who: Node) -> void:
	_row(who).deaths += 1


func report(p: Node, dino_win: bool, msg: String) -> void:
	var gaps: Array = []
	for i in range(1, tries.size()):
		gaps.append(tries[i] - tries[i - 1])
	var firsts := {}
	for r: Dictionary in _cow.values():
		firsts[r.first_card] = true
	last = {"round": p.round_index + 1, "extract": not dino_win, "t": t, "first_card": first_card, "open": open_at,
		"tries": tries.size(), "gap": _mean(gaps), "split": firsts.size() > 1, "stuck_by": stuck_by, "stuck_long": stuck_long,
		"dino_safe": dino_safe, "safe_t": safe_t, "open_dist": open_dist, "cow": _cow.duplicate(true),
		"loots": loots, "meals": meals, "new_pts": _new_points(p, dino_win)}
	print("回合指標 第%d回合 %s（%.0f 秒）第一張牌 %s 開箱 %s 試 %d 次 間隔 %s 分頭 %s 恐龍守箱 %s 開箱時恐龍離箱 %s 搜刮 %d 吃肉 %d 新得分 %d" % [last.round, msg, t,
		_sec(first_card), _sec(open_at), tries.size(), "%.1f 秒" % last.gap if gaps.size() > 0 else "-", "是" if last.split else "否",
		"%.0f%%" % (100.0 * dino_safe / safe_t) if safe_t > 0.0 else "-", "%.0f 公尺" % open_dist if open_dist >= 0.0 else "-", loots, meals, last.new_pts])
	for id: int in _cow:
		var r: Dictionary = _cow[id]
		var b: bool = r.bot
		print("回合指標   %s 死 %d 恐龍%d公尺內 %.0f 秒 活著 %.0f 秒 卡牆 %s 換動作 %s 開槍 %s 命中 %s" % [p.names.get(id, str(id)), r.deaths,
			NEAR_DINO, r.near, r.alive, "%.0f 秒" % r.stuck if b else "-", "%d 次" % r.changes if b else "-",
			r.shots if b else "-", r.hits if b else "-"])


## 獵人這回合從 0.8.16 新得分拿到的總分（第一個開信封、開保險箱、打死拿蛋的人）。report 在 _end_round 加分之前叫：
## 這時獵人的 round_scores 只有撤離和這兩種馬上加的，信封的分還在 _env_bonus
func _new_points(p: Node, dino_win: bool) -> int:
	var n := 0
	for id: int in p.round_scores:
		if id != p.dino_id:
			n += int(p.round_scores[id])
	for id: int in p._env_bonus:
		n += int(p._env_bonus[id])
	return n - (0 if dino_win else Party.SCORE_EXTRACT)


static func _sec(v: float) -> String:
	return "%.0f 秒" % v if v >= 0.0 else "-"

static func _mean(a: Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / a.size() if a.size() > 0 else 0.0
