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

var of := {}      # 連線編號（電腦是負的）-> 第幾隊（0 紅、1 藍、2 綠）。尼諾拉不在表上
var zones: Array = []   # 主機：這場各隊的出生區中心（第 i 個給第 i 隊）


## 主機：獵人照名單順序輪流分（1 紅、2 藍、3 綠、4 紅…）。名單是真人在前、電腦補在後，所以電腦自然補在人少的隊
func assign(hunters: Array) -> void:
	of.clear()
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
