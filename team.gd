class_name Team
extends RefCounted
## 團隊模式的隊伍（docs/企劃/2026-11-19-團隊模式.md 第 1 節）：誰在哪一隊、各隊的出生區。
## party.gd 在團隊模式建一份（party.team），回合流程還是 party.gd 跑。隊伍表 of 跟著 party.state() 送給每台。
## 之後的倒地（T2）、隊伍情報（T3）也放這裡。

const COUNT := 3   # 三隊
const NAMES := ["紅隊", "藍隊", "綠隊"]
const COLORS := [Color(0.9, 0.3, 0.25), Color(0.3, 0.6, 0.95), Color(0.35, 0.8, 0.4)]   # 同計分欄（party_hud.SWATCH）的前三個
static var SIZE: int = Balance.whole("team_size")   # 每隊幾個獵人
static var ZONE_APART: float = Balance.num("team_zone_apart")   # 出生區之間至少隔多遠
static var ZONE_GAP: float = Balance.num("team_zone_gap")   # 同一區的點隔多遠
# 倒地、救人（第 3、4 節）：倒地的狀態在牛仔身上（cowboy.down、bleed_left），倒數和救人的規則在 party.gd（_down_step、can_revive）
static var BLEED_SECONDS: float = Balance.num("team_bleed_seconds")   # 倒地多久沒人救就出局
static var CRAWL_SPEED: float = Balance.num("team_crawl_speed")
static var REVIVE_SECONDS: float = Balance.num("team_revive_seconds")
static var REVIVE_HP: int = Balance.whole("team_revive_hp")
static var REVIVE_RANGE: float = Balance.num("team_revive_range")
static var REVIVE_PAUSE: float = Balance.num("team_revive_pause")   # 有人在救時倒數暫停，每次倒地最多停這麼久
static var REVIVE_GUARD: float = Balance.num("team_revive_guard")   # 救起來之後這麼久打不動

var of := {}      # 連線編號（電腦是負的）-> 第幾隊（0 紅、1 藍、2 綠）。尼諾拉不在表上
var zones: Array = []   # 主機：這場各隊的出生區中心（第 i 個給第 i 隊）
var downs := 0     # 主機：這場倒地幾次（tools/bot_sim.gd 的總表）
var revives := 0   # 主機：這場救起來幾次


## 主機：獵人照名單順序輪流分（1 紅、2 藍、3 綠、4 紅…）。名單是真人在前、電腦補在後，所以電腦自然補在人少的隊
func assign(hunters: Array) -> void:
	of.clear()
	downs = 0
	revives = 0
	for i in hunters.size():
		of[hunters[i]] = i % COUNT


func team_of(id: int) -> int:
	return int(of.get(id, -1))


## 同一隊（自己跟自己不算）
func same(a: int, b: int) -> bool:
	return a != b and of.has(a) and of.has(b) and of[a] == of[b]


## 兩個節點是不是隊友：都是牛仔（不是恐龍）、名字是連線編號
func same_side(a: Node, b: Node) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and not a.is_in_group(&"dino") and not b.is_in_group(&"dino") \
		and same(a.name.to_int(), b.name.to_int())


func mates(id: int) -> Array:
	return of.keys().filter(func(o: int) -> bool: return same(id, o))


## 換編號（重連、中途接手電腦）：隊伍跟著
func rekey(old: int, new: int) -> void:
	if of.has(old):
		of[new] = of[old]
		of.erase(old)


## 主機：從地圖的牛仔出生點裡抽 COUNT 個當出生區中心，兩兩至少隔 ZONE_APART（抽不到就放寬）。
## 地圖沒放夠出生點（牧場）就用四個角落（離中心 arena × 0.3）。
## ponytail: 用現有的出生點（地圖邊上那圈），沒有另外擺「出生區」；要專門的區再在關卡加一種擺設
static func pick_zones(points: Array, arena: float) -> Array:
	var cand := points.duplicate()
	if cand.size() < COUNT:
		var r := arena * 0.3
		cand = [Vector3(r, 0, r), Vector3(-r, 0, r), Vector3(r, 0, -r), Vector3(-r, 0, -r)]
	var apart := ZONE_APART
	var out: Array = []
	for tries in 60:
		if tries % 20 == 19:
			apart *= 0.7
		cand.shuffle()
		out = []
		for q: Vector3 in cand:
			if out.size() < COUNT and out.all(func(z: Vector3) -> bool: return Vector2(z.x - q.x, z.z - q.z).length() >= apart):
				out.append(q)
		if out.size() == COUNT:
			break
	return out


## 主機：id 的出生位置：他那隊的區中心，同隊第 k 個往橫的方向排開 ZONE_GAP（橫＝垂直於朝場地中央的方向）
func spot(id: int) -> Vector3:
	var t := team_of(id)
	if t < 0 or t >= zones.size():
		return Vector3.INF
	var k := of.keys().filter(func(o: int) -> bool: return of[o] == t).find(id)
	var c: Vector3 = zones[t]
	var side := Vector3(-c.z, 0.0, c.x).normalized() if Vector2(c.x, c.z).length() > 0.1 else Vector3.RIGHT
	return c + side * ZONE_GAP * (k - (SIZE - 1) * 0.5)


# ── T3：三位數密碼、兩種信封、隊內共享（團隊模式第 5、6 節）──
const PLACES := ["百位", "十位", "個位"]
static var DUAL_CANDS: int = Balance.whole("team_dual_candidates")   # 雙位提示每位幾個候選（含正確的）

var env_info: Array = []   # 主機：每封信的內容，每位 [] 沒有、[d] 確定、[a, b, c] 候選。公開的只有 cover_of 算出來的種類
var intel: Array = []      # 主機：每隊三格，每格「還有哪些數字可能」
var seen: Array = []       # 主機：每隊看過哪幾封（信封索引）


## 主機：新回合清掉每隊的情報
func reset_intel() -> void:
	intel = []
	seen = []
	for t in COUNT:
		intel.append([range(10), range(10), range(10)])
		seen.append([])


## 主機：t 隊看了第 i 封，三格跟它取交集。回傳變了的位數（[] = 沒有新東西）
func merge(t: int, i: int) -> Array:
	if not seen[t].has(i):
		seen[t].append(i)
	var got: Array = []
	for k in 3:
		var info: Array = env_info[i][k]
		if info.is_empty():
			continue
		var left: Array = intel[t][k].filter(func(d: int) -> bool: return info.has(d))
		if left.size() < intel[t][k].size():
			intel[t][k] = left
			got.append(k)
	return got


## 每位確定的數字（-1 = 還不確定）
static func sure(cands: Array) -> Array:
	return cands.map(func(c: Array) -> int: return c[0] if c.size() == 1 else -1)


## 信封的種類（公開，方位條、牌面畫圖示用）：每位 2 確定、1 候選、0 沒有
static func cover_of(info: Array) -> Array:
	return info.map(func(c: Array) -> int: return 0 if c.is_empty() else (2 if c.size() == 1 else 1))


## 圖示的字（牌面、提示）：■ 確定、▣ 候選、□ 沒有
static func cover_text(cover: Array) -> String:
	return "".join(cover.map(func(v: int) -> String: return ["□", "▣", "■"][v]))


## 主機：電腦看的隊伍情報：known 每位確定的數字、cands 每位的候選、useful 本隊沒看過又蓋得到還不確定那位的信封
func bot_view(id: int, covers: Array) -> Dictionary:
	var t := team_of(id)
	if t < 0 or intel.is_empty():
		return {}
	var c: Array = intel[t]
	var useful: Array = []
	for i in covers.size():
		if not seen[t].has(i) and range(3).any(func(k: int) -> bool: return covers[i][k] > 0 and c[k].size() > 1):
			useful.append(i)
	return {"known": sure(c), "cands": c, "useful": useful}


## 這一場的 n 封信（第 5 節）：雙位提示 5 封（8 封時）或 6 封，「百十、百個、十個」輪流放；其餘單位提示，百、十、個各一，
## 10 封多一封隨機一位。同一位的雙位提示假數字都不重複：同一位看兩封雙位就確定。順序打亂
static func roll_envelopes(code: int, n: int) -> Array:
	var digit := [code / 100, code / 10 % 10, code % 10]
	var wrong: Array = []   # 每位還沒用過的假數字
	for k in 3:
		var w: Array = range(10)
		w.erase(digit[k])
		w.shuffle()
		wrong.append(w)
	var out: Array = []
	var pairs := [[0, 1], [0, 2], [1, 2]]
	var first := randi() % 3
	for j in (5 if n <= 8 else 6):
		var info: Array = [[], [], []]
		for k: int in pairs[(first + j) % 3]:
			var c: Array = [digit[k]]
			for q in DUAL_CANDS - 1:
				c.append(wrong[k].pop_back())
			c.sort()
			info[k] = c
		out.append(info)
	var singles: Array = [0, 1, 2]
	while out.size() + singles.size() < n:
		singles.append(randi() % 3)
	for k: int in singles:
		var info: Array = [[], [], []]
		info[k] = [digit[k]]
		out.append(info)
	out.shuffle()
	return out
