class_name Director
extends RefCounted
## 恐龍的導演（主機上跑，boss.gd 每幀呼叫 step）。做法照 Alien Isolation 和 Left 4 Dead（知識庫的敵人設計筆記）：
##
## - 導演知道每個牛仔在哪，但**只給恐龍大概方向**：恐龍閒著太久，就挑一個最近沒被追過的人，
##   給他附近 HINT_FUZZ 公尺內的一點。恐龍走到那裡之後還是要自己看、自己聽才找得到人。
## - **威脅值**：恐龍看到人、追人、出招都會累積，滿了就叫恐龍**退開**（RETREAT）一段，
##   再**放鬆**（RELAX）一段：不給提示、遠處的槍聲不理；之後回到**醞釀**（BUILD）。
##   節奏就是「累積 → 高峰 → 退潮 → 放鬆」一圈一圈轉。
## - 恐龍被打到倒地也算高峰：起來先退開。開槍打恐龍是有用的。

enum Phase { BUILD, RETREAT, RELAX }

const MENACE_MAX := 100.0
const MENACE_SEE := 7.0      # 每秒：看得到人
const MENACE_CHASE := 3.0    # 每秒：沒看到但在追（往最後看到的地方、聽到的聲音）
const MENACE_ATTACK := 12.0  # 每次出招
const MENACE_DECAY := 2.5    # 每秒：什麼都沒在做
const RETREAT_TIME := 12.0
const RELAX_TIME := 15.0
const HINT_IDLE := 6.0       # 恐龍閒著這麼久，導演給一次方向
const HINT_FUZZ := Vector2(12.0, 20.0)   # 提示點離那個人多遠（公尺）：不給準確位置
const RELAX_HEAR := 40.0     # 放鬆的時候，只理這麼近的槍聲

var phase := Phase.BUILD
var menace := 0.0
var phase_left := 0.0
var idle := 0.0
var _last_hunted := {}       # 牛仔的節點名字 -> 上次被追的時刻（秒）
var _clock := 0.0


## 一幀。sees：恐龍這一幀看得到人；chasing：在追（最後看到的位置、聲音）；
## 回傳要不要給恐龍一個提示點（不用就回傳 Vector3.INF）
func step(delta: float, sees: Node3D, chasing: bool, cowboys: Array, rng: RandomNumberGenerator) -> Vector3:
	_clock += delta
	if sees:
		_last_hunted[sees.name] = _clock
	match phase:
		Phase.BUILD:
			if sees:
				menace += MENACE_SEE * delta
			elif chasing:
				menace += MENACE_CHASE * delta
			else:
				menace = maxf(menace - MENACE_DECAY * delta, 0.0)
			if menace >= MENACE_MAX:
				peak()
				return Vector3.INF
			idle = 0.0 if sees or chasing else idle + delta
			if idle >= HINT_IDLE and not cowboys.is_empty():
				idle = 0.0
				return hint_for(_pick(cowboys), rng)
		Phase.RETREAT, Phase.RELAX:
			phase_left -= delta
			if phase_left <= 0.0:
				if phase == Phase.RETREAT:
					phase = Phase.RELAX
					phase_left = RELAX_TIME
				else:
					phase = Phase.BUILD
					idle = 0.0
	return Vector3.INF


## 出了一招
func attacked() -> void:
	if phase == Phase.BUILD:
		menace += MENACE_ATTACK


## 威脅滿了（或恐龍被打倒）：退開
func peak() -> void:
	phase = Phase.RETREAT
	phase_left = RETREAT_TIME
	menace = 0.0


## 那個人附近的一點（不是他的位置）
func hint_for(p: Node3D, rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	return p.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(HINT_FUZZ.x, HINT_FUZZ.y)


## 最久沒被追的人（沒被追過的最優先）
func _pick(cowboys: Array) -> Node3D:
	var best: Node3D = null
	var best_t := INF
	for p: Node3D in cowboys:
		var t: float = _last_hunted.get(p.name, -INF)
		if best == null or t < best_t:
			best = p
			best_t = t
	return best
