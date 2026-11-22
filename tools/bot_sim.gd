extends SceneTree
## 量電腦牛仔「像不像真人」（docs/企劃/2026-11-13-電腦牛仔像真人.md「怎麼量」）：派對模式、4 個電腦輪流當恐龍（3 個牛仔＋電腦尼諾拉），跑 N 回合。
##   godot --headless --fixed-fps 60 --path . --script tools/bot_sim.gd
##   ROUNDS=20（預設）、SEED=1、BOT_LOG=1（電腦換動作時印一行，打分數版才有）
##   TEAM=1：團隊模式（電腦尼諾拉＋三隊各 3 個電腦獵人，一場 1 局 12 分鐘）；ROUNDS 就是幾場。總表多各隊贏幾場、倒地和救起來幾次
##   SHORT=秒：遊戲階段最多這麼久（只是確認跑得完、不當掉用；量數字不要設）
## 照專用伺服器的開法：物理一秒 60 次、沒有真人（_dedicated）。--fixed-fps 60 讓一幀固定走 1/60 秒、不等真的時間，跑得比實際快；
## 拿掉就照實際速度（一回合 3 分 45 秒）。快轉時用真的時鐘算的東西（尼諾拉撞房子的拖拉、急救包冷卻）會變短，對牛仔的行為影響小。
## 每回合結束 party.gd 印「回合指標」（遊戲本身也印，真人的場次一樣有），最後印總表和「BOT_SIM OK」（Godot 解析錯誤也回 0，要看這行）。

var ROUNDS := int(OS.get_environment("ROUNDS")) if OS.get_environment("ROUNDS") != "" else 20
var _m: Node
var _f := 0
var _rounds: Array = []
var _t0 := 0
var _gold := ""   # 最後一回合：金色小恐龍死了沒
var _star := ""   # 最後一回合：星星在誰身上
var _ms: PackedFloat32Array = []   # 遊戲中每幀的腳本時間（毫秒）：_process＋_physics_process
var _team := OS.get_environment("TEAM") == "1"
var _short := float(OS.get_environment("SHORT")) if OS.get_environment("SHORT") != "" else 0.0
var _wins := {}   # 團隊模式：贏的（隊名、尼諾拉）-> 幾場
var _downs := 0      # 團隊模式：全部場次一共倒地幾次
var _revives := 0    # 救起來幾次
var _pts: Array = []   # 每回合結算後的 [恐龍得分, 獵人裡最高的得分, 獵人平均]（0.8.16 第 1 節：恐龍固定之後公不公平）


func _initialize() -> void:
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1)
	OS.low_processor_usage_mode_sleep_usec = 1
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	_t0 = Time.get_ticks_msec()


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_m._offline = true
		_m._dedicated = true   # 主機不是玩家：派對用電腦補滿四個
		ToyBuild.no_flight = true
		_m._on_mode_picked(_m.RULES.keys().find(&"team" if _team else &"party"))
		_m._enter_game("bot_sim")
		_m._apply_rules()
		_m.spawn_boss()
		if _team:
			_m.party.start()   # 固定恐龍的模式要等真人才開（party.step），這裡沒有真人：直接開
		return false
	var p: Party = _m.party
	if p == null:
		return false
	if p.phase == &"play":
		_ms.append(1000.0 * (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
	if _short > 0.0 and p.phase == &"play" and p.time_left > _short:
		p.time_left = _short
	if p.phase in [&"prep", &"result", &"final"] and p.time_left > 0.1:
		p.time_left = 0.1   # 準備、結算不用等（牛仔本來就不能動）
	if p.phase == &"play" and p.round_index == p.rounds - 1:   # 追分星星：最後一回合記金色小恐龍死了沒、星星在誰身上
		var r: Raptors = _m.raptors
		_gold = "打死了" if r.gold >= 0 and r.alive[r.gold] == 0 else "還活著"
		_star = p.names.get(p.star_holder, "") if p.star_holder != 0 else ("地上" if p.star_on else "沒掉出來")
	elif p.phase == &"result" and _gold != "":
		print("BOT_SIM 星星：金色小恐龍%s，回合結束時星星在 %s" % [_gold, _star])
		_gold = ""
	if p.stats.last.size() > 0 and not (_rounds.size() > 0 and is_same(p.stats.last, _rounds.back())):   # report 每回合換一個新的字典
		_rounds.append(p.stats.last)
		if _team:
			var w: String = Team.NAMES[p.winner_team] if p.winner_team >= 0 else "尼諾拉"
			_wins[w] = int(_wins.get(w, 0)) + 1
			_downs += p.team.downs
			_revives += p.team.revives
		var hs: Array = p._roster.filter(func(id: int) -> bool: return id != p.dino_id).map(func(id: int) -> int: return int(p.round_scores.get(id, 0)))
		_pts.append([int(p.round_scores.get(p.dino_id, 0)), hs.max() if hs.size() > 0 else 0, hs.reduce(func(a: int, b: int) -> int: return a + b, 0) / maxf(hs.size(), 1.0)])
		if _rounds.size() >= ROUNDS:
			_summary()
			return true
	return false


func _summary() -> void:
	var n := _rounds.size()
	var opened := _rounds.filter(func(r: Dictionary) -> bool: return r.open >= 0.0)
	var carded := _rounds.filter(func(r: Dictionary) -> bool: return r.first_card >= 0.0)
	var gapped := _rounds.filter(func(r: Dictionary) -> bool: return r.tries > 1)
	var deaths := 0
	var near := 0.0
	var alive := 0.0
	var stuck := 0.0
	var changes := 0
	var shots := 0
	var hits := 0
	var cows := 0
	var by := {}
	for r: Dictionary in _rounds:
		for k: String in r.stuck_by:
			by[k] = float(by.get(k, 0.0)) + r.stuck_by[k]
		for c: Dictionary in r.cow.values():
			cows += 1
			deaths += int(c.deaths)
			near += c.near
			alive += c.alive
			stuck += c.stuck
			changes += int(c.changes)
			shots += int(c.shots)
			hits += int(c.hits)
	var avg := func(a: Array, k: String) -> String:
		var s := 0.0
		for r: Dictionary in a:
			s += float(r[k])
		return "%.1f" % (s / a.size()) if a.size() > 0 else "-"
	print("BOT_SIM 總表（%d 回合，實際跑了 %.0f 秒）" % [n, (Time.get_ticks_msec() - _t0) / 1000.0])
	print("  第一張牌被看 %s 秒（%d/%d 回合有人看）" % [avg.call(carded, "first_card"), carded.size(), n])
	print("  開箱 %s 秒（%d/%d 回合開了）" % [avg.call(opened, "open"), opened.size(), n])
	print("  試密碼 %s 次／回合，間隔 %s 秒" % [avg.call(_rounds, "tries"), avg.call(gapped, "gap")])
	print("  撤離成功 %d/%d（%.0f%%）" % [_rounds.filter(func(r: Dictionary) -> bool: return r.extract).size(), n,
		100.0 * _rounds.filter(func(r: Dictionary) -> bool: return r.extract).size() / n])
	print("  牛仔死 %.1f 次／回合" % (float(deaths) / n))
	print("  分頭 %d/%d 回合" % [_rounds.filter(func(r: Dictionary) -> bool: return r.split).size(), n])
	print("  換動作 %.1f 次／分鐘（每個電腦）" % (changes / maxf(alive / 60.0, 0.001)))
	print("  命中 %d/%d（%.0f%%）" % [hits, shots, 100.0 * hits / maxi(shots, 1)])
	print("  離恐龍 15 公尺內 %.0f 秒／人／回合" % (near / maxi(cows, 1)))
	print("  卡牆 %.0f 秒／人／回合（活著的 %.1f%%）" % [stuck / maxi(cows, 1), 100.0 * stuck / maxf(alive, 0.001)])
	var stuck_long := 0
	var dino_safe := 0.0
	var safe_t := 0.0
	var dists: Array = []
	for r: Dictionary in _rounds:
		stuck_long += int(r.stuck_long)
		dino_safe += r.dino_safe
		safe_t += r.safe_t
		if r.open_dist >= 0.0:
			dists.append(r.open_dist)
	dists.sort()
	print("  卡超過 20 秒 %d 次" % stuck_long)
	print("  恐龍離保險箱 30 公尺內 %.0f%% 的時間；開箱時恐龍離箱 %s" % [100.0 * dino_safe / maxf(safe_t, 0.001),
		"%.0f～%.0f 公尺（中間值 %.0f）" % [dists[0], dists[-1], dists[dists.size() / 2]] if dists.size() > 0 else "-"])
	var ms := _ms.duplicate()
	ms.sort()
	var tot := 0.0
	for v in ms:
		tot += v
	print("  每幀腳本時間 平均 %.2f 毫秒，最慢 1%% %.2f 毫秒（%d 幀）" % [tot / maxi(ms.size(), 1),
		ms[int(ms.size() * 0.99)] if ms.size() > 0 else 0.0, ms.size()])
	print("  搜刮 %s 次／回合、吃肉 %s 次／回合；獵人新得分（信封、開箱、打死拿蛋的）%s 分／回合" % [avg.call(_rounds, "loots"),
		avg.call(_rounds, "meals"), avg.call(_rounds, "new_pts")])
	var dsum := 0.0
	var tsum := 0.0
	var hsum := 0.0
	for v: Array in _pts:
		dsum += v[0]
		tsum += v[1]
		hsum += v[2]
	print("  恐龍 %.1f 分／回合、獵人最高 %.1f、獵人平均 %.1f；恐龍是獵人最高的 %.2f 倍（星星 ×2 只在每 4 回合的最後一回合）" % [dsum / maxi(n, 1),
		tsum / maxi(n, 1), hsum / maxi(n, 1), dsum / maxf(tsum, 0.001)])
	print("  卡在哪：%s" % "、".join(by.keys().map(func(k: String) -> String: return "%s %.0f 秒" % [k, by[k]])))
	if _team:
		print("  團隊模式誰贏：%s" % "、".join(_wins.keys().map(func(k: String) -> String: return "%s %d 場" % [k, _wins[k]])))
		print("  倒地 %d 次、救起來 %d 次（%.0f%%）" % [_downs, _revives, 100.0 * _revives / maxf(_downs, 1.0)])
	print("BOT_SIM OK")
