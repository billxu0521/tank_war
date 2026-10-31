class_name Party
extends Node
## 派對模式（docs/企劃/派對玩法.md）：四個人輪流當恐龍，四回合加總比排名。
## 派對模式時 main 底下有一個 $Party（main._apply_rules 建）。規則全在主機算（main._physics_process 每幀呼叫 step），
## 算完整包同步給客戶端（_recv）；客戶端只自己倒數 time_left 讓畫面順。畫面在 party_hud.gd，這裡不畫東西。
##
## 一回合：準備 PREP_SECONDS（恐龍藏蛋，牛仔站著不能動、不能開槍）→ 遊戲 PLAY_SECONDS → 結算 RESULT_SECONDS。
## 參賽者：真人照連線編號排序，不到四個用電腦補在後面。第 N 回合由第 N 個人當恐龍（真人操作尼諾拉、電腦就是 boss 自己跑）。

signal changed

const ROUNDS := 4
const PLAYERS := 4            # 不到這麼多人用電腦補
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var PREP_SECONDS: float = Balance.num("party_prep_seconds")
static var PLAY_SECONDS: float = Balance.num("party_play_seconds")   # 3 分 30 秒
const RESULT_SECONDS := 8.0   # 回合結算停多久再開下一回合
const FINAL_SECONDS := 30.0   # 四回合結束後停多久自動開新的一場
# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var LIVES: int = Balance.whole("party_lives")   # 牛仔每回合幾條命
static var RESPAWN_SECONDS: float = Balance.num("party_respawn_seconds")
static var SCORE_SURVIVE: int = Balance.whole("score_survive")   # 回合結束時還活著
static var SCORE_EXTRACT: int = Balance.whole("score_extract")   # 帶蛋撤離（另外加，合計 10）
static var SCORE_KILL: int = Balance.whole("score_kill")   # 恐龍殺一個牛仔
static var SCORE_GUARD: int = Balance.whole("score_guard")   # 恐龍守住蛋（時間到、或牛仔的命用完）

var rounds := ROUNDS
var round_index := 0
var phase := &""              # &""：還沒開始；prep、play、result、final
var time_left := 0.0
var scores := {}              # 連線編號 -> 總分
var round_scores := {}        # 連線編號 -> 本回合得分
var lives := {}               # 牛仔連線編號 -> 剩幾條命
var dino_id := 0
var names := {}               # 連線編號 -> 顯示名稱
var last_result := ""
var egg_placed := false       # 準備階段恐龍放蛋了沒

var _roster: Array = []       # 參賽者（照當恐龍的順序）
var _waiting := {}            # 主機：等重生的牛仔編號 -> [剩幾秒, 是不是電腦]
var _pick := {}               # 主機：牛仔選的重生點（編號 -> spawn_points 的索引）
var _sync_left := 0.0

@onready var main: Node = get_parent()
const BOSS_GD := preload("res://boss.gd")   # 尼諾拉的身高（LIFT）：開局放回出生點用


## 照總分排的連線編號（高的在前）
func ranking() -> Array:
	var ids := scores.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(scores[a]) > int(scores[b]))
	return ids


## 玩家選重生點（spawn_points 的索引）。客戶端呼叫會送到主機；沒選就隨機
@rpc("any_peer", "call_remote", "reliable")
func request_respawn_at(index: int) -> void:
	if not multiplayer.is_server():
		request_respawn_at.rpc_id(1, index)
		return
	var from := multiplayer.get_remote_sender_id()
	_pick[from if from != 0 else multiplayer.get_unique_id()] = index


## 準備階段恐龍按 F 把蛋放在腳下。客戶端送到主機
@rpc("any_peer", "call_remote", "reliable")
func place_egg() -> void:
	if not multiplayer.is_server():
		place_egg.rpc_id(1)
		return
	var from := multiplayer.get_remote_sender_id()
	if phase != &"prep" or egg_placed or (from if from != 0 else multiplayer.get_unique_id()) != dino_id:
		return
	_drop_egg_at(_dino_pos())
	egg_placed = true
	_sync()


func _process(delta: float) -> void:
	if phase == &"":
		return
	if not multiplayer.is_server():
		time_left = maxf(time_left - delta, 0.0)
	var me := multiplayer.get_unique_id()
	# 準備階段只有恐龍看得到蛋：牛仔要看恐龍往哪走，猜蛋藏在哪
	main.egg.visible = phase != &"prep" or me == dino_id
	if phase == &"prep" and me == dino_id and not egg_placed and Input.is_action_just_pressed(&"interact") \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		place_egg()


## 主機每個物理幀（main._physics_process）
func step(delta: float) -> void:
	if phase == &"":
		start()
		return
	time_left -= delta
	_sync_left -= delta
	if _sync_left <= 0.0:   # 每秒整包送一次：晚加入的人也拿得到，客戶端的倒數不會飄太遠
		_sync()
	match phase:
		&"prep":
			if not egg_placed:
				main.egg.global_position = main._on_ground(_flat(_dino_pos(), 0.5))   # 還沒放：蛋跟著恐龍走
			if time_left <= 0.0:
				if not egg_placed:   # 時間到沒放：放在恐龍腳下
					_drop_egg_at(_dino_pos())
					egg_placed = true
				phase = &"play"
				time_left = PLAY_SECONDS
				main._announce.rpc("開始！")
				_sync()
		&"play":
			_respawn_step(delta)
			_drop_orphan_egg()
			main._egg_step(delta)   # 撿蛋、帶著走、撤離（撤離成功會叫 extracted）
			if phase != &"play":
				return
			if time_left <= 0.0:
				_end_round(true, "時間到，恐龍守住了蛋")
			elif _waiting.is_empty() and _cowboys().is_empty():
				_end_round(true, "牛仔的命用完了，恐龍守住了蛋")
		&"result":
			if time_left <= 0.0:
				round_index += 1
				if round_index >= rounds:
					phase = &"final"
					time_left = FINAL_SECONDS
					last_result = "四回合結束"
					_sync()
				else:
					_start_round()
		&"final":
			if time_left <= 0.0:
				start()


## 開新的一場：分數歸零、排參賽者、開第一回合
func start() -> void:
	var fixed := false
	for w: Destructible in main._wrecks:   # 上一場拆掉的地形立回來
		if w.hits > 0:
			w.restore.rpc()
			fixed = true
	if fixed:
		main.bake_nav(true)
	scores.clear()
	names.clear()
	round_index = 0
	_roster = _humans()
	for i in _roster.size():
		names[_roster[i]] = "玩家 %d" % (i + 1)
	var bot := -1
	while _roster.size() < PLAYERS:
		names[bot] = "電腦 %d" % -bot
		_roster.append(bot)
		bot -= 1
	for id: int in _roster:
		scores[id] = 0
	_start_round()


## 牛仔死了（main._on_died 轉過來）：恐龍殺的加分、扣命、排重生。帶著的蛋由 _drop_orphan_egg 放到地上
func on_died(killer: Node, who: Node) -> void:
	var id := who.name.to_int()
	if is_instance_valid(killer) and killer.is_in_group(&"dino"):
		_add(dino_id, SCORE_KILL)
	lives[id] = int(lives.get(id, LIVES)) - 1
	if int(lives[id]) > 0:
		_waiting[id] = [RESPAWN_SECONDS, bool(who.get(&"bot"))]
	_sync()


## 有人帶蛋撤離（main._egg_step 轉過來）：回合馬上結束
func extracted(id: int) -> void:
	_add(id, SCORE_EXTRACT)
	_end_round(false, "%s 帶蛋撤離" % names.get(id, "牛仔 %d" % id))


func _start_round() -> void:
	_refresh_roster()
	phase = &"prep"
	time_left = PREP_SECONDS
	round_scores.clear()
	lives.clear()
	_waiting.clear()
	_pick.clear()
	last_result = ""
	egg_placed = false
	dino_id = _roster[round_index % _roster.size()]
	# 清場：boss 以外全部收掉再照這回合的角色生（刪掉重生，客戶端的位置才會跟著換；做法同 main._new_round）
	var players: Node = main.players
	for p in players.get_children():
		if not p.is_in_group(&"boss"):
			players.remove_child(p)
			p.queue_free()
	main._cowboys = 0
	main._respawn_queue.clear()
	main._claimer = 0
	var egg: Egg = main.egg
	egg.carrier = 0
	egg.pickup = 0.0
	egg.extract = 0.0
	var spots := range(main.spawn_points.size())
	spots.shuffle()   # 準備階段牛仔隨機出生，各站一個點不擠在一起
	for id: int in _roster:
		if id != dino_id and _present(id):
			_spawn_cowboy(id, id < 0, spots.pop_back() if not spots.is_empty() else -1)
	var b: Node3D = main._boss()
	if b == null:
		b = main.spawn_boss()
	b.pilot = 0
	var c: Vector3 = main.dino_spawn   # 地圖中央（擺設種類 dino_spawn）；沒放就是正中央
	b.global_position = main.boss_on_ground(c)
	b.reset_physics_interpolation()
	b.hp = b.max_hp
	if &"down_left" in b:
		b.down_left = 0.0
		b.guard_left = 0.0
	main._announce.rpc("第 %d 回合：%s 當恐龍" % [round_index + 1, names.get(dino_id, "")])
	if dino_id > 0 and _present(dino_id):
		main.make_pilot(dino_id)   # 真人：操作尼諾拉（對抗模式那套）；電腦：boss 自己跑
	else:   # 電腦不會藏蛋：開場就放在中央（不然蛋跟著牠追到站著不動的牛仔旁邊）
		_drop_egg_at(b.global_position)
		egg_placed = true
	_sync()


## 新加入的真人頂掉還沒當過恐龍的電腦；沒有空位就排在最後（還是有分數，只是這場輪不到當恐龍）。
## 離開的人留在名單上：輪到他時恐龍由電腦操作
func _refresh_roster() -> void:
	for h: int in _humans():
		if _roster.has(h):
			continue
		var slot := -1
		for i in range(round_index, _roster.size()):   # 這回合那格的電腦也還沒當過
			if _roster[i] < 0:
				slot = i
				break
		var n := _roster.size() - _roster.filter(func(id: int) -> bool: return id < 0).size() + 1
		names[h] = "玩家 %d" % n
		scores[h] = int(scores.get(h, 0))   # 中途加入那回合賺的分留著
		if slot >= 0:
			scores.erase(_roster[slot])
			names.erase(_roster[slot])
			_roster[slot] = h
		else:
			_roster.append(h)


func _end_round(dino_win: bool, msg: String) -> void:
	if dino_win:
		_add(dino_id, SCORE_GUARD)
	for p: Node in _cowboys():
		_add(p.name.to_int(), SCORE_SURVIVE)
	phase = &"result"
	time_left = RESULT_SECONDS
	last_result = msg
	_waiting.clear()
	main.egg.carrier = 0
	main.egg.extract = 0.0
	main._announce.rpc(msg)
	_sync()


func _respawn_step(delta: float) -> void:
	for id: int in _waiting.keys():
		_waiting[id][0] -= delta
		if _waiting[id][0] > 0.0:
			continue
		var bot: bool = _waiting[id][1]
		_waiting.erase(id)
		if _present(id) and not main.players.has_node(NodePath(str(id))):
			_spawn_cowboy(id, bot, int(_pick.get(id, -1)))   # 選的點整回合有效（畫面也一直亮著那個）


func _spawn_cowboy(id: int, bot: bool, index: int) -> void:
	var c: Node3D = main._add_player(main.COWBOY, id)
	c.set(&"bot", bot)
	if bot:   # 電腦：散彈或步槍隨機拿一把（主機決定，別人的畫面靠 gun 看見）
		(c as Cowboy).viewmodel.switch_weapon([1, 2].pick_random())
	c.global_position = main._on_ground(_flat(_spawn_spot(index), 0.5))
	if not lives.has(id):
		lives[id] = LIVES


## 牛仔出生／重生點：選了就用選的，沒選就隨機；地圖沒放（spawn_points 空的）就退回 main._spawn_point
func _spawn_spot(index: int) -> Vector3:
	var pts: Array[Vector3] = main.spawn_points
	if pts.is_empty():
		return main._spawn_point()
	return pts[index] if index >= 0 and index < pts.size() else pts.pick_random()


## 帶蛋的人不見了（死了或離線）：蛋掉在他最後的位置，落到地上
func _drop_orphan_egg() -> void:
	var egg: Egg = main.egg
	if egg.carrier != 0 and not main.players.has_node(NodePath(str(egg.carrier))):
		egg.carrier = 0
		egg.extract = 0.0
		_drop_egg_at(egg.global_position)


func _drop_egg_at(p: Vector3) -> void:
	main.egg.global_position = main._on_ground(_flat(p, 0.5))
	main.egg.reset_physics_interpolation()


func _dino_pos() -> Vector3:
	var b: Node3D = main._boss()
	return b.global_position if b else main.egg.global_position


## 水平位置＋離地高度（main._on_ground 吃的格式）
static func _flat(p: Vector3, h: float) -> Vector3:
	return Vector3(p.x, h, p.z)


## 場上活著的牛仔（排除正在刪的）
func _cowboys() -> Array:
	return main.players.get_children().filter(func(p: Node) -> bool:
		return not p.is_in_group(&"dino") and not p.is_queued_for_deletion() and p.hp > 0)


## 連著的真人，照連線編號排（專用伺服器的主機自己不算）
func _humans() -> Array:
	var ids: Array = multiplayer.get_peers().duplicate()
	if not main._dedicated:
		ids.append(1)
	ids.sort()
	return ids


func _present(id: int) -> bool:
	return id < 0 or (id == 1 and not main._dedicated) or multiplayer.get_peers().has(id)

## 斷線重連（main._reclaim）：舊編號的分數、名字、命數、名單位置都換成新編號
func rekey(old: int, new: int) -> void:
	for d: Dictionary in [scores, round_scores, lives, names, _waiting, _pick]:
		if d.has(old):
			d[new] = d[old]
			d.erase(old)
	var i := _roster.find(old)
	if i >= 0:
		_roster[i] = new
	if dino_id == old:
		dino_id = new
	_sync()


func _add(id: int, pts: int) -> void:
	scores[id] = int(scores.get(id, 0)) + pts
	round_scores[id] = int(round_scores.get(id, 0)) + pts


func _sync() -> void:
	_sync_left = 1.0
	_recv.rpc({rounds = rounds, round_index = round_index, phase = phase, time_left = time_left, scores = scores,
		round_scores = round_scores, lives = lives, dino_id = dino_id, names = names, last_result = last_result,
		egg_placed = egg_placed})
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _recv(s: Dictionary) -> void:
	for k: String in s:
		set(k, s[k])
	changed.emit()
