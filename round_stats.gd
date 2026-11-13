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

var t := 0.0                  # 這回合遊戲時間（準備階段不算）
var first_card := -1.0        # 第一張牌被看的時刻
var open_at := -1.0
var tries: Array = []         # 每次試開被記進表的時刻
var last: Dictionary = {}     # 上一回合的結果（bot_sim 讀）
var _tried := 0
var _cow := {}                # 牛仔編號 -> 這回合的數字（見 _row）
var stuck_by := {}            # 動作 -> 卡住幾秒（看卡在哪種路上，決定要不要接導航網格）


func reset() -> void:
	t = 0.0
	first_card = -1.0
	open_at = -1.0
	tries.clear()
	stuck_by = {}
	_tried = 0
	_cow.clear()


func _row(c: Node) -> Dictionary:
	var id := c.name.to_int()
	if not _cow.has(id):
		_cow[id] = {"bot": bool(c.get(&"bot")), "deaths": 0, "near": 0.0, "alive": 0.0, "stuck": 0.0,
			"changes": 0, "act": "", "shots": 0, "hits": 0, "mag": -1, "hit_until": 0, "first_card": -2}
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
		if s.open and open_at < 0.0:
			open_at = t
	var dino: Node3D = m._boss()
	for c: Node in m.players.get_children():
		if c.is_in_group(&"dino") or not c is Cowboy:
			continue
		var r := _row(c)
		r.alive += delta
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
		"tries": tries.size(), "gap": _mean(gaps), "split": firsts.size() > 1, "stuck_by": stuck_by, "cow": _cow.duplicate(true)}
	print("回合指標 第%d回合 %s（%.0f 秒）第一張牌 %s 開箱 %s 試 %d 次 間隔 %s 分頭 %s" % [last.round, msg, t,
		_sec(first_card), _sec(open_at), tries.size(), "%.1f 秒" % last.gap if gaps.size() > 0 else "-", "是" if last.split else "否"])
	for id: int in _cow:
		var r: Dictionary = _cow[id]
		var b: bool = r.bot
		print("回合指標   %s 死 %d 恐龍%d公尺內 %.0f 秒 活著 %.0f 秒 卡牆 %s 換動作 %s 開槍 %s 命中 %s" % [p.names.get(id, str(id)), r.deaths,
			NEAR_DINO, r.near, r.alive, "%.0f 秒" % r.stuck if b else "-", "%d 次" % r.changes if b else "-",
			r.shots if b else "-", r.hits if b else "-"])


static func _sec(v: float) -> String:
	return "%.0f 秒" % v if v >= 0.0 else "-"

static func _mean(a: Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / a.size() if a.size() > 0 else 0.0
