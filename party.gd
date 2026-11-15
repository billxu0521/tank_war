class_name Party
extends Node
## 派對模式（docs/企劃/派對玩法.md）：四個人輪流當恐龍，四回合加總比排名。
## 派對模式時 main 底下有一個 $Party（main._apply_rules 建）。規則全在主機算（main._physics_process 每幀呼叫 step），
## 算完整包同步給客戶端（_recv）；客戶端只自己倒數 time_left 讓畫面順。畫面在 party_hud.gd，這裡不畫東西。
##
## 一回合：準備 PREP_SECONDS（恐龍藏蛋；保險箱模式箱子已經抽好位置，恐龍先去守。牛仔站著不能動、不能開槍）→ 遊戲 PLAY_SECONDS → 結算 RESULT_SECONDS。
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
# 追分星星（docs/企劃/2026-11-15-畫面與保險箱位置.md 的 1.1）：最後一回合的金色小恐龍（raptors.gd）身上有，死了掉在地上，
# 碰到就撿（不用按鍵）；拿著的牛仔死掉、尼諾拉倒地就掉在原地。回合結束時拿著的人，這回合的分數 × STAR_MULT
static var STAR_REACH: float = Balance.num("star_pickup_reach")
static var STAR_MULT: int = Balance.whole("star_multiplier")
const STAR_EDGE := 6.0        # 掉出場外：搬回離場地邊緣這麼遠（同 safe.gd 的 EDGE）

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
var use_safe := false         # 蛋鎖在保險箱（match_rules 的 safe，_ready 讀；測試可以先關掉走舊的藏蛋）
var env_pos: Array = [Vector3.ZERO, Vector3.ZERO]   # 兩個信封的位置（公開）：0 十位數、1 個位數
var env_open: Array = [false, false]                # 信封有沒有人看過（公開，只分有沒有、不分誰）
var my_digits: Array = [-1, -1]   # 這台的人看過的數字（十位、個位，-1 = 沒看過）。主機只用 rpc_id 送本人，不在 state() 裡
var envelopes: Array[Envelope] = []
var star_holder := 0          # 拿著星星的人（連線編號；尼諾拉是 dino_id）。0 = 沒人拿
var star_on := false          # 星星掉在地上（star_pos）
var star_pos := Vector3.ZERO  # 地上的星星在哪；有人拿著時主機記他最後的位置（掉的時候用）
var _star_mesh: MeshInstance3D   # 每台：地上的星星、頭上的星星（同一顆）

var _roster: Array = []       # 參賽者（照當恐龍的順序）
var _waiting := {}            # 主機：等重生的牛仔編號 -> [剩幾秒, 是不是電腦]
var _pick := {}               # 主機：牛仔選的重生點（編號 -> spawn_points 的索引）
var _sync_left := 0.0
var _known := {}              # 主機：牛仔編號 -> [十位, 個位]（-1 = 沒看過）。跟著人不跟著命，回合開始清掉
var _noted: Array = [false, false]   # 這台已經提示過恐龍「信封被開了」
var stats := RoundStats.new()   # 主機：每回合的指標，結束時印「回合指標」（tools/bot_sim.gd 也讀）

@onready var main: Node = get_parent()
const BOSS_GD := preload("res://boss.gd")   # 尼諾拉的身高（LIFT）：開局放回出生點用


func _ready() -> void:
	use_safe = bool(main.RULES[main.rules].get("safe", false))
	for i in 2:   # 每台都建、名字固定，看牌走 party 的 RPC，信封自己沒有 RPC
		var e := Envelope.new()
		e.name = "Envelope%d" % i
		e.index = i
		e.party = self
		e.visible = false
		e.collision_layer = 0
		add_child(e)
		envelopes.append(e)


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


## 準備階段恐龍按 F 把蛋放在腳下（保險箱模式：放保險箱，蛋在裡面）。客戶端送到主機
@rpc("any_peer", "call_remote", "reliable")
func place_egg() -> void:
	if not multiplayer.is_server():
		place_egg.rpc_id(1)
		return
	var from := multiplayer.get_remote_sender_id()
	if phase != &"prep" or egg_placed or (from if from != 0 else multiplayer.get_unique_id()) != dino_id:
		return
	_hide_egg_at(_dino_pos())
	_sync()


func _process(delta: float) -> void:
	if phase == &"":
		return
	if not multiplayer.is_server():
		time_left = maxf(time_left - delta, 0.0)
	var me := multiplayer.get_unique_id()
	# 準備階段只有恐龍看得到蛋：牛仔要看恐龍往哪走，猜蛋藏在哪
	main.egg.visible = (phase != &"prep" or me == dino_id) and not main.safe.locked()
	main.safe.visible = main.safe.on and egg_placed and (phase != &"prep" or me == dino_id)
	for i in envelopes.size():
		var e := envelopes[i]
		e.visible = main.safe.on
		e.collision_layer = 1 if main.safe.on else 0
		if e.global_position != env_pos[i]:
			e.global_position = env_pos[i]
		if e.opened != bool(env_open[i]):
			e.set_opened(env_open[i])
		if env_open[i] and not _noted[i] and me == dino_id and phase == &"play" and not main.safe.open:   # 恐龍：第一次被開跳一行字（箱子開了就沒用了）
			main.status.text = "%s的信封被打開了" % Envelope.NAMES[i]
		_noted[i] = bool(env_open[i])
	_show_star()
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
					_hide_egg_at(_dino_pos())
				phase = &"play"
				time_left = PLAY_SECONDS
				stats.reset()
				main._announce.rpc("開始！")
				_sync()
		&"play":
			_respawn_step(delta)
			main.raptors.step(delta)   # 小恐龍看、叫（準備階段牛仔站著不動，不看）
			_star_step()
			stats.tick(main, self, delta)
			main.safe.server_step(delta)   # 試密碼的 1 秒、作廢、開箱
			if main.safe.locked():   # 鎖著：蛋跟著箱子（箱子會被炸飛、甩飛）
				main.egg.global_position = main.safe.global_position
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
	main.restore_terrain()   # 上一場拆掉的樹、積木立回來
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
	if id == star_holder:
		drop_star(who.global_position)
	stats.died(who)
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
	main.safe.reset(use_safe)   # 每回合重抽密碼、清試過的表
	main.roll_exits()   # 每回合重抽撤離區（信封要避開抽到的，所以先抽）
	_known.clear()   # 看過的牌、信封開過沒：每回合重來
	my_digits = [-1, -1]
	env_open = [false, false]
	dino_id = _roster[round_index % _roster.size()]
	# 清場：boss 以外全部收掉再照這回合的角色生（刪掉重生，客戶端的位置才會跟著換；做法同 main._new_round）
	# 恐龍的牛仔留著：make_pilot 要跟他交接（先叫他停送同步再收），不能現在就收
	var players: Node = main.players
	var keep := str(dino_id) if dino_id > 0 and _present(dino_id) else ""
	for p in players.get_children():
		if not p.is_in_group(&"boss") and String(p.name) != keep:
			players.remove_child(p)
			p.queue_free()
	main._cowboys = 1 if keep != "" and players.has_node(keep) else 0
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
	if main.safe.on:   # 保險箱：地圖上的幾個點隨機抽一個（可以重複），恐龍不用放；地圖沒放點就放在恐龍前面
		var pts: Array[Vector3] = main.safe_spots
		_hide_egg_at(pts.pick_random() if not pts.is_empty() else b.global_position, pts.is_empty())
		_place_envelopes()   # 信封離箱子夠遠，所以箱子先放
	elif not (dino_id > 0 and _present(dino_id)):   # 電腦不會藏蛋：開場就放在中央（不然蛋跟著牠追到站著不動的牛仔旁邊）
		_hide_egg_at(b.global_position)
	main.raptors.clear()   # 小恐龍：上回合的清掉，這回合尼諾拉重放
	if not (dino_id > 0 and _present(dino_id)):
		main.raptors.auto_place()   # 電腦當恐龍：開回合自己放（要在信封之後：放在信封附近）
	star_holder = 0
	star_on = false
	if round_index == rounds - 1:
		main.raptors.add_gold()   # 最後一回合：金色小恐龍（身上有星星）
	main.barrels.roll()   # 爆炸桶每回合重抽（要在信封、箱子之後：避開信封和蛋）
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
	_order_scores()


## scores 照 _roster 重排：計分欄的色塊照 scores 的順序給，整包送到客戶端順序也跟著。
## 頂替的人接手被頂掉的那格顏色，重連換編號也不換色
func _order_scores() -> void:
	var s := {}
	for id: int in _roster:
		s[id] = scores.get(id, 0)
	s.merge(scores)   # 不在名單上的（照理沒有）留在後面
	scores = s


func _end_round(dino_win: bool, msg: String) -> void:
	if phase == &"play":
		stats.report(self, dino_win, msg)
	if dino_win:
		_add(dino_id, SCORE_GUARD)
	for p: Node in _cowboys():
		_add(p.name.to_int(), SCORE_SURVIVE)
	if star_holder != 0:   # 拿著星星：這回合的分數（含剛加的守住、活著、撤離）× STAR_MULT
		_add(star_holder, int(round_scores.get(star_holder, 0)) * (STAR_MULT - 1))
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


## 恐龍藏蛋（按 F、時間到、電腦開場）、保險箱模式回合開始放箱子（蛋鎖在箱子裡）。
## ahead：p 是恐龍的位置，箱子往牠前面挪（不然卡在牠身體裡）；抽到的保險箱點就直接放
func _hide_egg_at(p: Vector3, ahead := true) -> void:
	egg_placed = true
	if not main.safe.on:
		_drop_egg_at(p)
		return
	var b: Node3D = main._boss()
	if b and ahead:
		var fwd := -b.global_basis.z
		p += Vector3(fwd.x, 0.0, fwd.z).normalized() * (BOSS_GD.BODY_RADIUS + Safe.HALF + 1.0)
	main.safe.place(main._on_ground(_flat(p, Safe.HALF)))
	main.egg.global_position = main.safe.global_position
	main.egg.reset_physics_interpolation()


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

## 斷線重連（main._reclaim）：舊編號的分數、名字、命數、名單位置、看過的牌都換成新編號（看過的牌在 _sync 補送）
func rekey(old: int, new: int) -> void:
	for d: Dictionary in [scores, round_scores, lives, names, _waiting, _pick, _known]:
		if d.has(old):
			d[new] = d[old]
			d.erase(old)
	var i := _roster.find(old)
	if i >= 0:
		_roster[i] = new
	_order_scores()
	if dino_id == old:
		dino_id = new
	if star_holder == old:
		star_holder = new
	_sync()


func _add(id: int, pts: int) -> void:
	scores[id] = int(scores.get(id, 0)) + pts
	round_scores[id] = int(round_scores.get(id, 0)) + pts


func _sync() -> void:
	_sync_left = 1.0
	_recv.rpc(state())
	for id: int in _known:   # 看過的牌每次跟著補送本人：重連、晚建好 Party 的也拿得到
		_tell(id)
	changed.emit()


## 每秒送給大家的整包（公開的東西）。保險箱只有 safe.state()：密碼不在裡面
func state() -> Dictionary:
	return {rounds = rounds, round_index = round_index, phase = phase, time_left = time_left, scores = scores,
		round_scores = round_scores, lives = lives, dino_id = dino_id, names = names, last_result = last_result,
		egg_placed = egg_placed, safe = main.safe.state(), env_pos = env_pos, env_open = env_open,
		star_holder = star_holder, star_on = star_on, star_pos = star_pos}


@rpc("authority", "call_remote", "reliable")
func _recv(s: Dictionary) -> void:
	for k: String in s:
		if k == "safe":
			main.safe.set_state(s[k])
		else:
			set(k, s[k])
	if phase != &"play":   # 回合外看過的牌作廢（主機在 _start_round 清 _known）
		my_digits = [-1, -1]
	changed.emit()


## 信封：兩個隨機的空地（main._spawn_point，搶蛋模式放蛋也用它），不在撤離圈、離保險箱和彼此夠遠。
## 抽不到合格的就放寬距離再抽
const ENV_APART := 60.0       # 兩個信封至少相距
const ENV_FROM_SAFE := 40.0   # 離保險箱
func _place_envelopes() -> void:
	var apart := ENV_APART
	var center := ENV_FROM_SAFE
	for tries in 200:
		if tries % 40 == 39:
			apart *= 0.7
			center *= 0.7
		var pts: Array = [_env_spot(), _env_spot()]
		var ok := pts.all(func(q: Vector3) -> bool:
			return _flat(q, 0).distance_to(_flat(main.safe.global_position, 0)) >= center \
				and main._exits.all(func(x: Vector3) -> bool: return _flat(q, 0).distance_to(_flat(x, 0)) > main.EXIT_RADIUS + 3.0))
		if ok and _flat(pts[0], 0).distance_to(_flat(pts[1], 0)) >= apart or tries == 199:
			env_pos = pts
			return


func _env_spot() -> Vector3:
	return main._on_ground(_flat(main._spawn_point(), 0.0))


## 牛仔看著信封按 F（envelope.gd）：客戶端送到主機
@rpc("any_peer", "call_remote", "reliable")
func read_envelope(i: int) -> void:
	if not multiplayer.is_server():
		read_envelope.rpc_id(1, i)
		return
	var from := multiplayer.get_remote_sender_id()
	read(from if from != 0 else multiplayer.get_unique_id(), i)


## 主機：id 這個牛仔看第 i 張牌。全部重新檢查（遊戲中、有保險箱、活著的牛仔、不是恐龍、夠近）。
## 數字只記進 _known、只送給他本人（_tell）；公開的只有「這個信封開過」。電腦牛仔（第 3 步）直接叫這個
func read(id: int, i: int) -> bool:
	if phase != &"play" or not main.safe.on or i < 0 or i > 1 or id == dino_id:
		return false
	var c := main.players.get_node_or_null(NodePath(str(id))) as Cowboy
	if c == null or c.hp <= 0 or c.is_queued_for_deletion() or _flat(c.global_position, 0).distance_to(_flat(env_pos[i], 0)) >= Envelope.RANGE:
		return false
	var k: Array = _known.get(id, [-1, -1])
	k[i] = digit(i)
	_known[id] = k
	env_open[i] = true
	_sync()   # 公開的「開過了」＋補送本人
	return true


## 主機：第 i 位的數字（0 十位、1 個位）。只在主機有意義（客戶端的 _code 是 -1）
func digit(i: int) -> int:
	var code: int = main.safe._code
	return code / 10 if i == 0 else code % 10


## 主機：把 id 看過的數字送給他一個人。主機自己是玩家就直接寫；電腦（負的編號）不用送
func _tell(id: int) -> void:
	if id == multiplayer.get_unique_id():
		_got_digits(_known[id])
	elif id > 0 and multiplayer.get_peers().has(id):
		_got_digits.rpc_id(id, _known[id])


@rpc("authority", "call_remote", "reliable")
func _got_digits(k: Array) -> void:
	if phase == &"play":
		my_digits = k.duplicate()
	changed.emit()


## 主機：星星掉在 at（金色小恐龍死了、拿著的人死了或倒地）。出場外的搬回場內、掉到地下的放回地面（同 safe._rescue）
func drop_star(at: Vector3) -> void:
	var half: float = main.ARENA * 0.5 - STAR_EDGE
	star_holder = 0
	star_on = true
	star_pos = main._on_ground(Vector3(clampf(at.x, -half, half), 0.0, clampf(at.z, -half, half)))
	_sync()


## 星星在誰身上（場上的節點）：尼諾拉是 boss；牛仔不在場（死了、斷線）是 null
func star_node() -> Node3D:
	if star_holder == 0:
		return null
	if star_holder == dino_id:
		return main._boss()
	return main.players.get_node_or_null(NodePath(str(star_holder))) as Node3D


## 主機、遊戲中每幀：拿著的人不見了（斷線）、尼諾拉倒地就掉；地上的星星誰先碰到（STAR_REACH）誰拿
func _star_step() -> void:
	if star_holder != 0:
		var n := star_node()
		if n == null or n.is_queued_for_deletion() or n.get(&"hp") <= 0 or float(n.get(&"down_left") if &"down_left" in n else 0.0) > 0.0:
			drop_star(n.global_position if n else star_pos)
		else:
			star_pos = n.global_position
		return
	if not star_on:
		return
	var b: Node3D = main._boss()
	if b and b.down_left <= 0.0 and _flat(b.global_position, 0).distance_to(_flat(star_pos, 0)) < BOSS_GD.BODY_RADIUS + STAR_REACH:
		_take_star(dino_id)
		return
	for c: Node3D in _cowboys():
		if _flat(c.global_position, 0).distance_to(_flat(star_pos, 0)) < STAR_REACH and absf(c.global_position.y - star_pos.y) < 2.5:
			_take_star(c.name.to_int())
			return


func _take_star(id: int) -> void:
	star_holder = id
	star_on = false
	main._announce.rpc("%s 拿到星星" % names.get(id, "玩家 %d" % id))
	_sync()


## 每台每幀：星星擺在地上（轉著）或拿著的人頭上；都沒有就藏起來
func _show_star() -> void:
	if _star_mesh == null:
		_star_mesh = MeshInstance3D.new()
		_star_mesh.mesh = star_mesh()
		_star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_mesh)
	var n := star_node() if phase in [&"prep", &"play"] else null
	_star_mesh.visible = n != null or (star_on and phase == &"play")
	_star_mesh.scale = Vector3.ONE * (3.0 if n and n.is_in_group(&"boss") else 1.0)   # 尼諾拉 12 公尺高，小星星看不到
	if n:
		_star_mesh.global_position = (n.head_position() + Vector3.UP * 3.0) if n.has_method(&"head_position") else n.global_position + Vector3.UP * 2.6
	elif star_on:
		_star_mesh.global_position = star_pos + Vector3.UP * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.004))


## 一顆五角星（平的、永遠面向鏡頭、會發光）。ponytail: 程式畫的，美術給模型再換
static func star_mesh() -> ArrayMesh:
	var pts := PackedVector3Array()
	for k in 10:
		var a := TAU * k / 10.0
		pts.append(Vector3(sin(a), cos(a), 0) * (0.5 if k % 2 == 0 else 0.22))
	var tris := PackedVector3Array()
	for k in 10:
		tris.append_array([Vector3.ZERO, pts[(k + 1) % 10], pts[k]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = tris
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	m.surface_set_material(0, mat)
	return m
