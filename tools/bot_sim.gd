extends SceneTree
## 量電腦牛仔「像不像真人」（docs/企劃/2026-11-13-電腦牛仔像真人.md「怎麼量」）：派對模式、4 個電腦輪流當恐龍（3 個牛仔＋電腦尼諾拉），跑 N 回合。
##   godot --headless --fixed-fps 60 --path . --script tools/bot_sim.gd
##   ROUNDS=20（預設）、SEED=1、BOT_LOG=1（電腦換動作時印一行，打分數版才有）
## 照專用伺服器的開法：物理一秒 60 次、沒有真人（_dedicated）。--fixed-fps 60 讓一幀固定走 1/60 秒、不等真的時間，跑得比實際快；
## 拿掉就照實際速度（一回合 3 分 45 秒）。快轉時用真的時鐘算的東西（尼諾拉撞房子的拖拉、急救包冷卻）會變短，對牛仔的行為影響小。
## 每回合結束 party.gd 印「回合指標」（遊戲本身也印，真人的場次一樣有），最後印總表和「BOT_SIM OK」（Godot 解析錯誤也回 0，要看這行）。

var ROUNDS := int(OS.get_environment("ROUNDS")) if OS.get_environment("ROUNDS") != "" else 20
var _m: Node
var _f := 0
var _rounds: Array = []
var _t0 := 0


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
		_m._on_mode_picked(_m.RULES.keys().find(&"party"))
		_m._enter_game("bot_sim")
		_m._apply_rules()
		_m.spawn_boss()
		return false
	var p: Party = _m.party
	if p == null:
		return false
	if p.phase in [&"prep", &"result", &"final"] and p.time_left > 0.1:
		p.time_left = 0.1   # 準備、結算不用等（牛仔本來就不能動）
	if p.stats.last.size() > 0 and not (_rounds.size() > 0 and is_same(p.stats.last, _rounds.back())):   # report 每回合換一個新的字典
		_rounds.append(p.stats.last)
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
	print("  卡在哪：%s" % "、".join(by.keys().map(func(k: String) -> String: return "%s %.0f 秒" % [k, by[k]])))
	print("BOT_SIM OK")
