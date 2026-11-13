class_name BotBrain
extends RefCounted
## 電腦牛仔的腦（docs/企劃/2026-11-13-電腦牛仔像真人.md）：每 THINK 秒把每個動作算一個分數，做最高分的。
## 只放「算分數＋不反覆」，走路、開槍、看牌這些身體的事在 cowboy.gd。只在主機跑。
## 輸入是 cowboy._bot_ctx 組的一包狀況（見 think），所以測試可以直接給狀況、看選什麼，不用開整場。
## 數字都是起始值，調穩了再搬進 balance.csv。

const THINK := 0.4            # 幾秒想一次
const STICK := 15.0           # 正在做的動作加這麼多分（別的要高過才換）
const LOCK := 2.5             # 換了動作幾秒內不再換（被打、恐龍第一次靠近、動作做不下去例外）
const NOISE := 5.0            # 每個動作 ±這麼多的隨機分，換動作才重抽
const NEAR_R := 35.0          # 險：離恐龍幾公尺內開始怕
const CLOSE := 15.0           # 恐龍第一次進這個距離：馬上重想
const URGENT := 90.0          # 最後幾秒開始急
const FORCE_TRY := 60.0       # 剩不到這麼多秒，一張牌都沒看也硬試
const HUMAN_LEAD := 10.0      # 真人隊友比我近這麼多、又朝那邊走，就當他要去
const HIDE_DIST := 45.0       # 躲：跑到離恐龍這麼遠

# 看牌、試密碼的手腳（秒）
const READ_MIN := 0.8         # 站在牌前多久才看到數字
const READ_MAX := 1.5
const ARRIVE_MIN := 1.0       # 到箱子旁先等（真人要按 F、看面板）
const ARRIVE_MAX := 2.0
const GAP_MIN := 1.5          # 每次試完等多久才試下一個（加上試本身 1 秒）
const GAP_MAX := 3.0

const CARD := ["看牌0", "看牌1"]
const NAMES := {"看牌0": "看牌(十位)", "看牌1": "看牌(個位)"}

var id := 0
var action := ""              # 正在做的動作（""＝還沒想過）
var since := 99.0             # 換到這個動作幾秒了
var scores := {}              # 上次想的分數（含隨機、含 STICK），除錯字和 BOT_LOG 用
var last_ctx := {}            # 上次想的狀況（goal 用：位置晚 0.4 秒沒關係）
static var LOG := OS.get_environment("BOT_LOG") != ""   # BOT_LOG=1：換動作時印一行
var _noise := {}
var _think_left := 0.0
var _was_close := false


func _init(bot_id: int) -> void:
	id = bot_id
	_think_left = THINK * (absi(bot_id) % 3) / 3.0   # 三個人錯開，不擠在同一幀


## 每個物理幀叫：到時間（或 now）就回 true，叫的人再組狀況叫 think
func tick(delta: float, now := false) -> bool:
	since += delta
	_think_left -= delta
	if _think_left > 0.0 and not now:
		return false
	_think_left = THINK
	return true


## 狀況 ctx（cowboy._bot_ctx 組，測試自己組）：
##   me 位置、hp 血量比例、last_life 剩一命、time_left 剩幾秒、hit 上次想之後被打過
##   locked 箱子關著、safe 箱子位置、cards 兩張牌位置、known [十位, 個位]（-1 沒看）
##   carrier 0 沒人拿／1 我拿著／2 別人拿著、holder 拿蛋的人在哪、egg 蛋在哪、exits 開著的撤離點、ffa 各自為隊
##   dino 恐龍在哪（null＝倒地或不在場）
##   mates 別的牛仔 [{pos, vel, act（電腦的動作，真人是 ""）}]
## 回傳有沒有換動作
func think(ctx: Dictionary) -> bool:
	last_ctx = ctx
	var s := score_all(ctx)
	var close := ctx.dino != null and (ctx.me as Vector3).distance_to(ctx.dino) < CLOSE
	var force: bool = ctx.get("hit", false) or (close and not _was_close) or not s.has(action)
	_was_close = close
	for k: String in s:
		s[k] += float(_noise.get(k, 0.0)) + (STICK if k == action else 0.0)
	scores = s
	if s.is_empty():
		return false
	if since < LOCK and not force:
		return false
	var best := action if s.has(action) else ""
	for k: String in s:
		if best == "" or s[k] > s[best]:
			best = k
	if best == action:
		return false
	action = best
	since = 0.0
	_noise.clear()
	for k: String in ["看牌0", "看牌1", "試密碼", "撿蛋", "撤離", "躲", "追蛋"]:
		_noise[k] = randf_range(-NOISE, NOISE)
	return true


## 每個能選的動作的原始分數（不含隨機、不含 STICK）
func score_all(ctx: Dictionary) -> Dictionary:
	var me: Vector3 = ctx.me
	var out := {}
	var hurt := 1.0 - float(ctx.hp)
	var last := 1.0 if ctx.get("last_life", false) else 0.0
	var urgent := clampf(1.0 - float(ctx.get("time_left", 999.0)) / URGENT, 0.0, 1.0)
	if ctx.get("locked", false):
		var known: Array = ctx.known
		var seen := int(known[0] >= 0) + int(known[1] >= 0)
		for i in 2:
			if known[i] < 0:
				var p: Vector3 = ctx.cards[i]
				out[CARD[i]] = 60.0 - minf(0.3 * _flat(me, p), 35.0) - 30.0 * _taken(ctx, CARD[i], p) - 40.0 * risk(ctx, p) - (25.0 if seen > 0 else 0.0)
		if seen > 0 or float(ctx.get("time_left", 999.0)) < FORCE_TRY:
			var sp: Vector3 = ctx.safe
			out["試密碼"] = 55.0 + (15.0 if seen == 2 else 0.0) + 25.0 * urgent - minf(0.2 * _flat(me, sp), 30.0) \
				- 45.0 * risk(ctx, sp) - 35.0 * _taken(ctx, "試密碼", sp)
	else:
		match int(ctx.get("carrier", 0)):
			0:
				var e: Vector3 = ctx.egg
				out["撿蛋"] = 75.0 + 25.0 * urgent - minf(0.2 * _flat(me, e), 30.0) - 35.0 * risk(ctx, e) - 20.0 * _taken(ctx, "撿蛋", e)
			1:
				if not (ctx.exits as Array).is_empty():
					out["撤離"] = 95.0
			2:
				if ctx.get("ffa", false):   # 各自為隊：打死拿蛋的人，蛋掉下來再撿（決定 1）
					var h: Vector3 = ctx.holder
					out["追蛋"] = 60.0 + 25.0 * urgent - minf(0.2 * _flat(me, h), 30.0) - 30.0 * risk(ctx, h)
	if int(ctx.get("carrier", 0)) != 1:   # 拿蛋的人只管跑
		out["躲"] = 10.0 + 80.0 * risk(ctx, me) * (0.4 + 0.6 * hurt) + 15.0 * last
	return out


## 那個地方離恐龍多近（0～1）。恐龍倒地或不在場是 0
## ponytail: 第 1 步恐龍位置直接讀（全知），第 2 步換成記得的位置和信心
func risk(ctx: Dictionary, p: Vector3) -> float:
	if ctx.dino == null:
		return 0.0
	return clampf(1.0 - p.distance_to(ctx.dino) / NEAR_R, 0.0, 1.0)


## 有沒有別人正要去同一個地方、而且比我近（1／0）。電腦看他的動作；真人看「比我近 HUMAN_LEAD 以上又朝那邊走」，或已經站在那裡
func _taken(ctx: Dictionary, key: String, p: Vector3) -> float:
	var mine := _flat(ctx.me, p)
	for m: Dictionary in ctx.get("mates", []):
		var d := _flat(m.pos, p)
		if d >= mine:
			continue
		if m.act == key:
			return 1.0
		if m.act == "":   # 真人
			var to := p - (m.pos as Vector3)
			var v: Vector3 = m.vel
			if d < 3.0 or (mine - d > HUMAN_LEAD and Vector2(v.x, v.z).length() > 1.0
					and Vector2(v.x, v.z).normalized().dot(Vector2(to.x, to.z).normalized()) > 0.7):
				return 1.0
	return 0.0


## 照現在的動作要去哪
func goal(ctx: Dictionary) -> Vector3:
	var me: Vector3 = ctx.me
	match action:
		"看牌0", "看牌1":
			return ctx.cards[int(action[-1])]
		"試密碼":
			return ctx.safe
		"撿蛋":
			return ctx.egg
		"追蛋":
			return ctx.holder
		"撤離":
			return _pick_exit(ctx)
		"躲":
			if ctx.dino == null:
				return me
			var away: Vector3 = me - ctx.dino
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3.FORWARD
			return (ctx.dino as Vector3) + away.normalized() * HIDE_DIST
	return me


## 撤離點：距離＋60×險最小的那個（不一定最近，會避開恐龍）。每幀重挑：恐龍移過去就換一個
func _pick_exit(ctx: Dictionary) -> Vector3:
	var ex: Array = ctx.exits
	var best := 0
	var cost := INF
	for i in ex.size():
		var c := _flat(ctx.me, ex[i]) + 60.0 * risk(ctx, ex[i])
		if c < cost:
			cost = c
			best = i
	return ex[best]


## 一行字：動作、前三名分數
func describe() -> String:
	var keys := scores.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return scores[a] > scores[b])
	var parts: Array = []
	for k: String in keys.slice(0, 3):
		parts.append("%s %d" % [NAMES.get(k, k), roundi(scores[k])])
	return "%s｜%s" % [NAMES.get(action, action), "　".join(parts)]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
