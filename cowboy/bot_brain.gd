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

# 感知（第 2 步）：只知道看得到、聽得到的
const FORGET := 8.0           # 沒再看到，信心幾秒降到 0
const HEARD_CONF := 0.6       # 只聽到：信心從這裡起跳
const UNKNOWN_RISK := 0.1     # 完全不知道恐龍在哪：到處都有一點怕
const SIGHT_DINO := 70.0      # 看得到恐龍多遠（牠 12 公尺高）
const SIGHT_COWBOY := 40.0
const SIGHT_COS := 0.574      # 視野：正前方左右各 55 度（cos 55°）
const FEEL := 6.0             # 貼身：不管方向都知道（腳步震動）
const HEAR_LOUD := 60.0       # 吼叫、出招聽得到多遠
const HEAR_RUN := 25.0        # 跑步
const HEAR_FUZZ := 0.15       # 聽到的位置偏多少（距離的比例，最多 HEAR_FUZZ_MAX 公尺）
const HEAR_FUZZ_MAX := 10.0
const REACT := 0.4            # 發現恐龍到有反應（秒），越遠越久：再加每公尺 REACT_PER_M
const REACT_PER_M := 0.004
# 手腳
const TURN := TAU             # 每秒最多轉多少（弧度）
const AIM_BASE := 1.5         # 瞄準偏差（度）
const AIM_MOVING := 3.0       # 走路再加
const AIM_TURNED := 2.0       # 剛轉過來再加
const AIM_SLIDE := 0.4        # 偏的方向每幾秒換一次，慢慢滑過去
const SHOT_GAP_MIN := 0.15    # 每發之間多等
const SHOT_GAP_MAX := 0.4
const GLANCE_MIN := 3.0       # 每 3～5 秒往旁邊或後面瞄一眼
const GLANCE_MAX := 5.0
const GLANCE_TIME := 0.5

# 看牌、試密碼的手腳（秒）
const READ_MIN := 0.8         # 站在牌前多久才看到數字
const READ_MAX := 1.5
const ARRIVE_MIN := 1.0       # 到箱子旁先等（真人要按 F、看面板）
const ARRIVE_MAX := 2.0
const GAP_MIN := 1.5          # 每次試完等多久才試下一個（加上試本身 1 秒）
const GAP_MAX := 3.0

# 守箱、護送、還擊（第 3 步）
const GUARD_DIST := 10.0      # 守箱站在箱子外多遠（面向恐龍最後出現的方向）
const ESCORT_DIST := 8.0      # 護送走在拿蛋的人和恐龍之間，離他多遠
const FIGHT_RANGE := 40.0     # 還擊：看得到恐龍、在這個距離內
const HIT_RECENT := 3.0       # 幾秒內被打過算「剛被打」
const PROTECT := 20.0         # 恐龍離正在試密碼、拿蛋的隊友這麼近：要還擊
const STRAFE := 4.0           # 還擊時往旁邊挪多遠
const BUSH_REACH := 40.0      # 躲：找多遠內的草叢
const HEAL_BELOW := 0.6       # 躲好了、血比這個少就用急救包

## 個性：同一張分數表乘不同倍數（risk 乘在「險」上，越大越怕）。照編號固定：-1 勇敢、-2 膽小、-3 投機，-4 又是勇敢（決定 3）
const PERSONAS := [
	{"name": "勇敢", "risk": 0.6, "還擊": 1.4, "躲": 0.6, "試密碼": 1.1, "守箱": 0.8, "撿蛋": 1.0, "護送": 1.2, "react": 0.3, "aim": 0.8},
	{"name": "膽小", "risk": 1.5, "還擊": 0.6, "躲": 1.5, "試密碼": 0.9, "守箱": 1.0, "撿蛋": 0.9, "護送": 1.0, "react": 0.5, "aim": 1.2},
	{"name": "投機", "risk": 1.0, "還擊": 0.8, "躲": 1.0, "試密碼": 0.6, "守箱": 1.6, "撿蛋": 1.4, "護送": 0.8, "react": 0.4, "aim": 1.0},
]
const MULT_AS := {"追蛋": "撿蛋"}   # 追蛋用撿蛋的倍數（投機的最想搶）

const CARD := ["看牌0", "看牌1"]
const NAMES := {"看牌0": "看牌(十位)", "看牌1": "看牌(個位)"}

var id := 0
var persona: Dictionary       # PERSONAS 其中一個；{}＝普通（測試用，全部 1 倍）
var action := ""              # 正在做的動作（""＝還沒想過）
var since := 99.0             # 換到這個動作幾秒了
var scores := {}              # 上次想的分數（含隨機、含 STICK），除錯字和 BOT_LOG 用
var last_ctx := {}            # 上次想的狀況（goal 用：位置晚 0.4 秒沒關係）
static var LOG := OS.get_environment("BOT_LOG") != ""   # BOT_LOG=1：換動作時印一行
var dino_mem := Vector3.ZERO  # 記得的恐龍位置
var conf := 0.0               # 有多確定（看到 1，FORGET 秒降到 0）
var seen_ago := INF           # 上次看到（或聽到）幾秒前
var _noise := {}
var _think_left := 0.0
var _was_close := false


func _init(bot_id: int, p: Variant = null) -> void:
	id = bot_id
	persona = p if p != null else PERSONAS[(absi(bot_id) - 1) % PERSONAS.size()]
	_think_left = THINK * (absi(bot_id) % 3) / 3.0   # 三個人錯開，不擠在同一幀


## 每個物理幀叫：到時間（或 now）就回 true，叫的人再組狀況叫 think
func tick(delta: float, now := false) -> bool:
	since += delta
	conf = maxf(conf - delta / FORGET, 0.0)
	seen_ago += delta
	_think_left -= delta
	if _think_left > 0.0 and not now:
		return false
	_think_left = THINK
	return true


## 看到（c = 1）、聽到（HEARD_CONF）恐龍在 pos。只聽到不蓋掉比較確定的記憶
func remember(pos: Vector3, c: float) -> void:
	if c < conf:
		return
	dino_mem = pos
	conf = c
	seen_ago = 0.0


## 狀況 ctx（cowboy._bot_ctx 組，測試自己組）：
##   me 位置、hp 血量比例、last_life 剩一命、time_left 剩幾秒、hit 上次想之後被打過
##   locked 箱子關著、safe 箱子位置、cards 兩張牌位置、known [十位, 個位]（-1 沒看）
##   carrier 0 沒人拿／1 我拿著／2 別人拿著、holder 拿蛋的人在哪、egg 蛋在哪、exits 開著的撤離點、ffa 各自為隊
##   dino 記得的恐龍位置（null＝看到牠倒地、或不在場）、conf 信心（0＝不知道在哪）
##   mates 別的牛仔 [{pos, vel, act（電腦的動作，真人是 ""）, carry 拿著蛋}]
##   sees 現在看得到恐龍、hit_ago 上次被打幾秒前、bushes 草叢位置
## 回傳有沒有換動作
func think(ctx: Dictionary) -> bool:
	last_ctx = ctx
	var s := score_all(ctx)
	var close := ctx.dino != null and float(ctx.get("conf", 1.0)) > 0.0 and (ctx.me as Vector3).distance_to(ctx.dino) < CLOSE
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
	for k: String in s:
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
		if _mate_doing(ctx, "試密碼", ctx.safe):
			out["守箱"] = 35.0 - minf(0.1 * _flat(me, ctx.safe), 15.0) - 30.0 * risk(ctx, me)
	else:
		match int(ctx.get("carrier", 0)):
			0:
				var e: Vector3 = ctx.egg
				out["撿蛋"] = 75.0 + 25.0 * urgent - minf(0.2 * _flat(me, e), 30.0) - 35.0 * risk(ctx, e) - 20.0 * _taken(ctx, "撿蛋", e)
			1:
				if not (ctx.exits as Array).is_empty():
					out["撤離"] = 95.0
			2:
				var h: Vector3 = ctx.holder
				if ctx.get("ffa", false):   # 各自為隊：打死拿蛋的人，蛋掉下來再撿（決定 1）
					out["追蛋"] = 60.0 + 25.0 * urgent - minf(0.2 * _flat(me, h), 30.0) - 30.0 * risk(ctx, h)
				else:
					out["護送"] = 55.0 - minf(0.15 * _flat(me, h), 25.0)
	if int(ctx.get("carrier", 0)) != 1:   # 拿蛋的人只管跑
		out["躲"] = 10.0 + 80.0 * risk(ctx, me) * (0.4 + 0.6 * hurt) + 15.0 * last
	if ctx.get("sees", false) and ctx.dino != null and _flat(me, ctx.dino) < FIGHT_RANGE:
		var guard := 0.0   # 恐龍離正在試密碼或拿蛋的隊友很近
		for m: Dictionary in ctx.get("mates", []):
			if (m.act == "試密碼" or m.get("carry", false) or (m.act == "" and ctx.get("locked", false) and _flat(m.pos, ctx.safe) < 3.0)) \
					and _flat(m.pos, ctx.dino) < PROTECT:
				guard = 1.0
		out["還擊"] = 10.0 + 25.0 * float(ctx.hp) + (25.0 if float(ctx.get("hit_ago", INF)) < HIT_RECENT else 0.0) + 25.0 * guard - 20.0 * last
	for k: String in out:
		out[k] *= float(persona.get(MULT_AS.get(k, k), 1.0))
	return out


## 有沒有隊友在做這件事（電腦看動作；真人站在 p 旁邊 3 公尺內就算）
func _mate_doing(ctx: Dictionary, key: String, p: Vector3) -> bool:
	for m: Dictionary in ctx.get("mates", []):
		if m.act == key or (m.act == "" and _flat(m.pos, p) < 3.0):
			return true
	return false


## 那個地方多危險（0～1）：信心 × 離記得的恐龍位置多近。看到恐龍倒地是 0；完全不知道在哪固定 UNKNOWN_RISK
func risk(ctx: Dictionary, p: Vector3) -> float:
	if ctx.dino == null:
		return 0.0
	var c := float(ctx.get("conf", 1.0))
	if c <= 0.0:
		return UNKNOWN_RISK * float(persona.get("risk", 1.0))
	return c * clampf(1.0 - p.distance_to(ctx.dino) / NEAR_R, 0.0, 1.0) * float(persona.get("risk", 1.0))


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
		"守箱":   # 箱子外 GUARD_DIST，朝恐龍最後出現的方向（不知道就朝我這邊）
			var sp: Vector3 = ctx.safe
			return sp + _dir(sp, ctx.dino if ctx.dino != null and float(ctx.get("conf", 1.0)) > 0.0 else me) * GUARD_DIST
		"護送":   # 走在拿蛋的人和恐龍之間
			var h: Vector3 = ctx.holder
			return h + _dir(h, ctx.dino if ctx.dino != null and float(ctx.get("conf", 1.0)) > 0.0 else me) * ESCORT_DIST
		"還擊":   # 橫著走：往恐龍的側邊挪，每次換動作換邊
			var side := _dir(me, ctx.dino).cross(Vector3.UP) * (1.0 if _noise.get("還擊", 0.0) > 0.0 else -1.0)
			return me + side * STRAFE
		"躲":
			if ctx.dino == null or float(ctx.get("conf", 1.0)) <= 0.0:
				return me
			# 草叢：BUSH_REACH 內、比我離恐龍遠（不往牠那邊跑）的最近一個；沒有就往反方向跑
			var dino: Vector3 = ctx.dino
			var best := Vector3.INF
			for b: Vector3 in ctx.get("bushes", []):
				if _flat(me, b) < BUSH_REACH and _flat(b, dino) > _flat(me, dino) and (best == Vector3.INF or _flat(me, b) < _flat(me, best)):
					best = b
			if best != Vector3.INF:
				return Vector3(best.x, me.y, best.z)
			return dino + _dir(dino, me) * HIDE_DIST
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
	var mem := "恐龍：%s" % ("不知道" if conf <= 0.0 else ("看得到" if seen_ago < 0.5 else "%d 秒前" % roundi(seen_ago)))
	return "%s｜%s｜%s｜%s" % [persona.get("name", "普通"), NAMES.get(action, action), "　".join(parts), mem]


## from 往 to 的水平方向（同一點就往前）
static func _dir(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length() > 0.1 else Vector3.FORWARD


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
