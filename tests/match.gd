extends "res://tests/dino.gd"
## 對局：計時、離線、模式與規則、單人打恐龍、回大廳、蛋、重生、專用伺服器、對抗、派對、沙盒、靶場、網路平滑

func _case_timeout() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var t2: Node = m.players.get_node(^"2")
	var bites := ceili(float(t2.max_hp) / d.BITE_DAMAGE)
	_ck(bites == 2, "平衡目標：咬兩口死一個牛仔（現在是 %d 口）" % bites)

	# 恐龍只比牛仔跑步快一點點：跑得掉一段，但不能永遠甩開。兩邊各自改都會被擋下來
	# 規則草案 6.2：獵人移速 ×0.8、恐龍速度不動，比例因此拉大到約 1.32（已確認接受）
	var ratio: float = d.SPEED / t2.sprint_speed
	_ck(ratio > 1.0 and ratio < 1.35, "恐龍基礎速度要比牛仔衝刺快 0~35%%（現在 %.2f 倍）" % ratio)

	# 無限重生，所以殺光牛仔不會結束回合
	m.players.get_node(^"2").take_damage(9999)
	m.players.get_node(^"3").take_damage(9999)
	_ck(not m._over, "牛仔全滅不該結束回合，他們會重生")
	_ck(m._respawn_queue.size() == 2, "兩台都要排進重生佇列（現在 %d 筆）" % m._respawn_queue.size())

	# 時間到才是恐龍的勝利條件
	m._time_left = 0.05
	m._physics_process(0.1)
	_ck(m._over and m.status.text.contains("時間到"),
		"時間到 -> 恐龍獲勝（現在是「%s」）" % m.status.text)
	_end(m)

## 離線 debug 模式：不連線也要能打、能判勝負
func _case_offline() -> void:
	var m := _new_offline_game()
	var me: Node = m.players.get_node(^"1")
	var target: Node = m.players.get_node(^"2")
	_ck(m.players.get_child_count() == 2, "離線應該有一個牛仔 + 一隻恐龍")
	_ck(me.is_multiplayer_authority() and me.is_local, "離線時自己那個牛仔要操控得動")
	_ck(target.bot and not me.bot, "恐龍是 bot，自己不是")
	target.take_damage(9999)
	_ck(not m._over, "打爆靶子不會直接贏，要帶蛋撤離才算")
	_end(m)

## 恐龍對三個牛仔 bot：bot 會自己跑、死了會重生
func _case_offline_dino() -> void:
	var m := _dino_vs_bots()
	var me: Node = m.players.get_node(^"1")
	_ck(m.players.get_child_count() == 4, "應該是一隻恐龍 + 三個牛仔 bot")
	_ck(me.is_in_group(&"dino") and me.is_multiplayer_authority(), "自己是恐龍而且操控得動")
	_ck(not me.bot, "自己那隻不能是靶")
	_ck(m._cowboys == 3, "三個牛仔都要算進勝負")
	for i in 3:
		_ck(m.players.get_node(str(2 + i)).bot, "第 %d 個牛仔要是 bot" % (i + 1))
	# 「靶真的會自己跑」要跨物理幀才驗得到，見最後的 _phase 3

	for i in 3:
		m.players.get_node(str(2 + i)).take_damage(9999)
	_ck(not m._over, "打死三個牛仔也不會結束，他們會重生")
	_ck(m._respawn_queue.size() == 3, "三個都要排進重生佇列")
	_end(m)

## 別人的角色平滑顯示（Fighter.net_step）：畫面晚 NET_DELAY 毫秒，在前後兩筆之間補；
## 封包晚到不影響（用送出時間算），新的還沒到就停在最後一筆
func _case_net_smooth() -> void:
	var m := _offline_match()
	var c: Node3D = m._add_player(m.COWBOY, 5)
	_ck(not c.net_smooth, "主機（離線也算）上不做平滑：咬人、找人要看即時位置")
	c.net_state = [0, Vector3(3, 0, 0), Vector3.ZERO]
	_ck(c.position.x == 3.0, "主機收到位置要直接套")
	c.net_smooth = true
	var r := Vector3(0, 1.0, 0)
	c._snaps = [[0.0, 1000.0, Vector3.ZERO, Vector3.ZERO], [50.0, 1090.0, Vector3(5, 0, 0), r * 0.5],   # 第二包晚到 40 毫秒
		[100.0, 1100.0, Vector3(10, 0, 0), r]]
	var d: float = c.NET_DELAY
	c.net_step(1075.0 + d)   # 畫面時間 = 1075 + 延遲 - 時差 1000 - 延遲 = 75
	_ck(absf(c.position.x - 7.5) < 0.01 and absf(c.rotation.y - 0.75) < 0.01, "要在兩筆之間補（現在 x=%.2f、朝向 %.2f）" % [c.position.x, c.rotation.y])
	c.net_step(1050.0 + d)
	_ck(absf(c.position.x - 5.0) < 0.01, "晚到的那包不影響位置（現在 x=%.2f）" % c.position.x)
	c.net_step(1300.0 + d)
	_ck(c.position.x == 10.0, "新的還沒到就停在最後一筆，不要亂猜")
	_end(m)

## 主機檢查移動（Fighter.net_accept）和每秒傷害額度（Main._dmg_allowed）：正常的全放行，瞬移、狂送扣血要擋。
## 直接給時間（毫秒）算，不靠真的等
func _case_net_check() -> void:
	var m := _offline_match()
	# 第一包直接當基準；之後的包照額度算
	var c: Node3D = m._add_player(m.COWBOY, 5)
	var t := 1000.0
	var p := Vector3.ZERO
	c.net_accept(p, t)
	var ok := true
	for i in 200:   # 正常衝刺：每 25 毫秒走 8.5 × 0.025 公尺
		t += 25.0
		p.x += c.sprint_speed * 0.025
		ok = ok and c.net_accept(p, t)
	_ck(ok, "正常衝刺連續送位置要全部接受")
	var base: Vector3 = c._net_anchor
	_ck(not c.net_accept(p + Vector3(50, 0, 0), t + 25.0), "一包瞬移 50 公尺要擋")
	_ck(c._net_anchor == base, "被擋的那包不能當新基準")
	_ck(c.net_max_speed() == c.sprint_speed and c.net_max_up() >= c.jump_velocity, "牛仔的最快速度從衝刺和跳來的")
	# 客戶端送來的位置走 net_state 進來：被擋就不套（時間是真的，這兩包幾乎同一毫秒）
	var f: Node3D = _net_fresh(m, 11)
	var f_before: Vector3 = f.position
	f.net_state = [0, f_before + Vector3(50, 0, 0), Vector3.ZERO]
	_ck(f.position == f_before, "net_state 送來瞬移的位置，主機不套")
	# 封包擠在一起：同一毫秒來 3 包、合計 3 公尺（額度 4 公尺）要接受
	var b: Node3D = _net_fresh(m, 6)
	ok = true
	for x in [1.0, 2.0, 3.0]:
		ok = ok and b.net_accept(Vector3(x, 0, 0), 1000.0)
	_ck(ok, "同一毫秒來 3 包、合計 3 公尺要全部接受")
	# 掉落 30 公尺：往下不限
	var d: Node3D = _net_fresh(m, 7)
	_ck(d.net_accept(Vector3(0, -30, 0), 3000.0), "掉落 30 公尺要接受")
	# 重生／新局後第一包在很遠的地方：新節點的第一包直接當基準
	var r: Node3D = m._add_player(m.COWBOY, 8)
	_ck(r.net_accept(Vector3(300, 0, -200), 5000.0), "新生出來的第一包不管在哪都要接受")
	# 跳：0.3 秒往上 0.5 公尺，正常；往上飛（每秒 10 公尺）要被擋
	var j: Node3D = _net_fresh(m, 12)
	var jt := 1000.0
	ok = true
	for i in 12:
		jt += 25.0
		ok = ok and j.net_accept(Vector3(0, 0.025 * (i + 1) * 2.0 * 0.5, 0), jt)   # 0.3 秒內 0.5 公尺
	_ck(ok, "跳起來的正常高度要接受")
	var fl: Node3D = _net_fresh(m, 13)
	var fy := 0.0
	var fly_rej := 0
	jt = 1000.0
	for i in 40:
		jt += 25.0
		fy += 0.25
		if not fl.net_accept(Vector3(0, fy, 0), jt):
			fly_rej += 1
	_ck(fly_rej > 0, "往上飛（每秒 10 公尺）要擋掉一部分")
	# 沿 40 度的坡走上去：水平每走 1 公尺升 0.839 公尺，不算往上瞬移
	var s: Node3D = _net_fresh(m, 14)
	var sx := 0.0
	jt = 1000.0
	ok = true
	for i in 200:
		jt += 25.0
		sx += c.sprint_speed * 0.025
		ok = ok and s.net_accept(Vector3(sx, sx * 0.839, 0), jt)
	_ck(ok, "沿 40 度的坡衝上去要全部接受")
	# 恐龍：衝刺 11.7 公尺／秒、跳 6.5 公尺，正常都要過
	var dn: Node3D = m._add_player(m.DINO, 9)
	dn.net_accept(Vector3.ZERO, 1000.0)
	ok = true
	jt = 1000.0
	var dx := 0.0
	for i in 200:
		jt += 25.0
		dx += dn.net_max_speed() * 0.025
		ok = ok and dn.net_accept(Vector3(dx, 0, 0), jt)
	_ck(ok, "恐龍正常衝刺要接受")
	ok = true
	for i in 29:   # 跳到 6.5 公尺高，約 0.7 秒
		jt += 25.0
		ok = ok and dn.net_accept(Vector3(dx, 6.5 * (i + 1) / 29.0, 0), jt)
	_ck(ok, "恐龍跳 6.5 公尺要接受")
	# 開槍位置：1 秒前走過的位置（現在離它約 8.5 公尺）在最近 1.5 秒的歷史裡，要算數；沒去過的遠處要擋
	var rc: Node3D = _net_fresh(m, 15)
	jt = 1000.0
	var rx := 0.0
	for i in 40:
		jt += 25.0
		rx += rc.sprint_speed * 0.025
		rc.net_accept(Vector3(rx, 0, 0), jt)
	rc.global_position = Vector3(rx, 0, 0)
	_ck(rc.near_recent(Vector3.ZERO, 5.0), "1 秒前的位置（在歷史裡）開槍要算數")
	_ck(not rc.near_recent(Vector3(50, 0, 0), 5.0), "沒去過的遠處開槍要擋")

	# 傷害額度：正常射速（左輪每 0.45 秒一發 50）全部算數
	var all := true
	for i in 10:
		all = all and m._dmg_allowed(7, 50, false, 1000.0 + i * 450.0)
	_ck(all, "左輪正常射速的傷害要全部接受")
	# 一秒內 20 次 60 傷害（同一毫秒）：大部分要擋
	var acc := 0
	for i in 20:
		if m._dmg_allowed(8, 60, false, 1000.0):
			acc += 1
	_ck(acc < 10, "同一毫秒狂送 20 次 60 傷害，大部分要擋（現在放行 %d 次）" % acc)
	# 散彈一發全中（10 顆 × 14）：要接受
	all = true
	for i in 10:
		all = all and m._dmg_allowed(9, 14, false, 1000.0)
	_ck(all, "散彈一發 10 顆全中要接受")
	# 爆頭秒殺（傷害＝滿血）：每隔一段時間才一次，不走總傷害
	_ck(m._dmg_allowed(10, 150, true, 1000.0), "第一次爆頭秒殺要接受")
	_ck(not m._dmg_allowed(10, 150, true, 1050.0), "50 毫秒內再一次爆頭秒殺要擋")
	_ck(m._dmg_allowed(10, 150, true, 1200.0), "隔 200 毫秒的爆頭秒殺要接受")
	# 數字從表格來：散彈一發 140、最快間隔是左輪的搧擊錘 0.16 秒
	var lim: Dictionary = m.fire_limits()
	_ck(absf(float(lim["shot"]) - 140.0) < 0.01 and absf(float(lim["gap"]) - 0.16) < 0.001,
		"傷害上限要從 weapons.csv 算（單發 %s、最快間隔 %s）" % [str(lim["shot"]), str(lim["gap"])])
	_ck(c.viewmodel.heavy_damage == m.MELEE_HEAVY, "槍托重擊要跟 Main.MELEE_HEAVY 一樣（改了要一起改）")
	_end(m)

## 一個剛生出來、已經收過第一包（原點）的牛仔，給移動檢查的案例用
func _net_fresh(m: Node, id: int) -> Node3D:
	var n: Node3D = m._add_player(m.COWBOY, id)
	n.net_accept(Vector3.ZERO, 1000.0)
	return n

## 靶場：另一張地圖，靶照距離站好、擺設乾淨，打中跳字，回大廳就切回牧場
func _case_range() -> void:
	var Main: GDScript = load("res://main.gd")
	Main.mode = &"range"
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._start_range()
	_ck(m.level_path == Main.RANGE_LEVEL and ResourceLoader.exists(m.level_path), "靶場要讀自己的場景檔")
	_ck(m.players.get_child_count() == 2 + m.RANGE_TARGETS.size() + m.PIERCE_WALLS.size(), "要有自己、恐龍靶、%d 個牛仔靶和 %d 個牆後靶" % [m.RANGE_TARGETS.size(), m.PIERCE_WALLS.size()])
	var me: Node3D = m.players.get_node(^"1")
	var far: Node3D = m.players.get_node(NodePath(str(2 + m.RANGE_TARGETS.size())))
	_ck(absf(-(far.global_position - me.global_position).z - 150.0) < 1.0, "最遠的靶在 150 公尺")
	var probs := LevelCheck.run(m.map._level, null)
	_ck(probs.is_empty(), "靶場擺設檢查有問題：%s" % [probs.slice(0, 5)])
	var before: int = m.get_node(^"Arena").get_child_count()
	m.hit_popup(far.global_position, 42, 150.0, false)
	_ck(m.get_node(^"Arena").get_child_count() == before + 1 and m._last_hit.contains("42"), "打中要跳傷害數字")
	m._process(0.016)
	_ck(m.hud.text.contains("準星距離"), "畫面上要有準星距離")
	m._to_lobby("")
	_ck(Main.mode == &"", "離開靶場要切回牧場")
	_end(m)

## 沙盒：靶站好、沒有時間限制、子彈無限、靶打死生回原地
func _case_sandbox() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_sandbox_pressed()
	var me: Node = m.players.get_node(^"1")
	_ck(me.is_local and not me.bot, "沙盒裡自己是可以操控的牛仔")
	_ck(m.players.get_child_count() == 2 + m.SANDBOX_TARGETS.size(), "要有自己、恐龍靶和 %d 個牛仔靶" % m.SANDBOX_TARGETS.size())
	for w in me.viewmodel._weapons:
		_ck(w.reserve < 0, "沙盒子彈要無限")
	var far: Node3D = m.players.get_node(^"6")
	_ck(absf(far.global_position.distance_to(me.global_position) - 100.0) < 5.0, "最遠的靶在 100 公尺")

	m._time_left = 0.01
	m._physics_process(0.1)
	_ck(not m._over, "沙盒沒有時間到這回事")

	var spot: Vector3 = far.global_position
	far.take_damage(9999)
	far.free()
	m._respawn_queue[0]["at"] = m._time_left + 1.0
	m._respawn_step()
	var back: Node3D = m.players.get_node_or_null(^"6")
	_ck(back != null and back.global_position.distance_to(spot) < 0.1, "靶打死要生回原地")

	m._to_lobby("")
	_ck(m.get_tree().get_nodes_in_group(&"sandbox_prop").is_empty(), "回大廳要把距離牌和練習柵欄清掉")
	_end(m)

## 大廳只剩連線模式和沙盒；連線模式的主機也是牛仔；主機看得到遊戲局控制
func _case_modes() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	_ck(not m.has_node(^"UI/Root/Lobby/OfflineBtn") and not m.has_node(^"UI/Root/Lobby/OfflineDinoBtn"),
		"大廳不該再有扮演（我當恐龍）的按鈕")
	for b in ["HostBtn", "JoinBtn", "SandboxBtn"]:
		_ck(m.has_node(NodePath("UI/Root/Lobby/" + b)), "大廳要有 %s" % b)
	m._on_host_pressed()
	var host: Node = m.players.get_node_or_null(^"1")
	_ck(host != null and not host.is_in_group(&"dino"), "連線模式的主機也是牛仔")
	m._set_menu(true)
	_ck(m.get_node(^"UI/Root/Menu/Box/Controller").visible, "主機按 Esc 要看得到遊戲局控制")
	# 連線模式下 bot 由主機操控：不然同步器不送位置，別人看到它站著不動
	var b: Node = m.add_bot()
	_ck(b.get_multiplayer_authority() == 1 and not b.is_local, "bot 要由主機操控、但不是主機自己（不搶相機）")
	# 加入的人的連線編號很大（實測 251338328），不能被當成電腦
	m._spawn(251338328)
	var guest: Node = m.players.get_node(^"251338328")
	_ck(guest.get_multiplayer_authority() == 251338328, "加入的人要自己操控自己的牛仔")
	_end(m)

## 大廳的對局模式：搶蛋、死鬥（重生 3 次、剩一人贏）、恐龍決鬥（重生 5 次、打死恐龍大家贏）
func _case_match_rules() -> void:
	var m := _offline_match()
	_ck(m.mode_pick.item_count == m.RULES.size(), "大廳要能選每一種模式（現在 %d）" % m.mode_pick.item_count)
	# 死鬥：沒有蛋，每人重生 3 次，用完出局，剩一個人贏
	m._on_mode_picked(m.RULES.keys().find(&"deathmatch"))
	m._apply_rules()
	_ck(m.rules == &"deathmatch" and not m.egg.visible, "死鬥沒有蛋")
	for id in [1, 2, 3]:
		m._add_player(m.COWBOY, id)
	_ck(m._lives.size() == 3 and int(m._lives[2]) == 3, "死鬥每人可以重生 3 次")
	m.players.get_node(^"2").take_damage(9999)
	_ck(int(m._lives[2]) == 2 and m._respawn_queue.size() == 1, "死一次扣一次重生、排進重生佇列")
	m._respawn_queue.clear()
	m.players.remove_child(m.players.get_node(^"2"))   # 死掉的那個還在等刪除，先拿掉才不會撞名
	m._add_player(m.COWBOY, 2)   # 當作重生回來
	m._lives[2] = 0
	m.players.get_node(^"2").take_damage(9999)
	_ck(m._out.has(2) and m._respawn_queue.is_empty(), "重生用完再死就出局、不排重生")
	_ck(not m._over, "還有兩個人，不會結束")
	m._lives[3] = 0
	m.players.get_node(^"3").take_damage(9999)
	_ck(m._over and m.result.visible and m.get_node(^"UI/Root/Result/Box/Text").text.contains("獲勝"),
		"只剩一個人就結束，他獲勝（現在：%s）" % m.get_node(^"UI/Root/Result/Box/Text").text)
	_end(m)
	# 恐龍決鬥：每人重生 5 次，恐龍打得死，打死大家贏
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"dino_duel"))
	m._apply_rules()
	m._add_player(m.COWBOY, 1)
	m._add_player(m.COWBOY, 2)
	var b: Node = m.spawn_boss()
	_ck(int(m._lives[1]) == 5, "恐龍決鬥每人可以重生 5 次")
	_ck(b.max_hp == MatchRules.RULES[&"dino_duel"].boss_hp and b.hp == MatchRules.RULES[&"dino_duel"].boss_hp, "決鬥的恐龍血量 %d" % MatchRules.RULES[&"dino_duel"].boss_hp)
	var c2: Node = m.players.get_node(^"2")
	c2.take_damage(30, m.players.get_node(^"1"))
	_ck(c2.hp == c2.max_hp - 30, "隊友火力：打到隊友會扣血")
	b.take_damage(b.max_hp + 10)
	_ck(m._over and m.get_node(^"UI/Root/Result/Box/Text").text.contains("所有牛仔獲勝"), "恐龍死了大家贏")
	_end(m)
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"dino_duel"))
	m._apply_rules()
	m._add_player(m.COWBOY, 1)
	m._add_player(m.COWBOY, 2)
	m.spawn_boss()
	for id in [1, 2]:
		m._lives[id] = 0
		m.players.get_node(NodePath(str(id))).take_damage(9999)
	_ck(m._over and m.get_node(^"UI/Root/Result/Box/Text").text.contains("恐龍獲勝"), "牛仔全部出局就是恐龍贏")
	# 重開一局：重生次數補滿、出局的人回來、恐龍回場
	m._new_round()
	_ck(not m._over and int(m._lives.get(1, -1)) == 5 and m.players.has_node(^"1") and m.players.has_node(^"2"),
		"重開一局：出局的人回來、重生次數補滿")
	_ck(m.players.has_node(NodePath(str(m.BOSS_ID))), "重開一局恐龍要在")
	_end(m)
	# 搶蛋（原本的模式）：不限重生
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"egg"))
	m._apply_rules()
	m._add_player(m.COWBOY, 1)
	_ck(m.egg.visible and m._lives.is_empty(), "搶蛋模式有蛋、不限重生")
	_end(m)

## 單人打恐龍：沙盒的場地、只有自己和恐龍 boss、子彈無限、接關無限
func _case_solo_dino() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	_ck(m.has_node(^"UI/Root/Lobby/SoloDinoBtn"), "大廳要有單人打恐龍")
	m._on_solo_dino_pressed()
	var me: Node3D = m.players.get_node_or_null(^"1")
	var b: Node3D = m.players.get_node_or_null(NodePath(str(m.BOSS_ID)))
	_ck(me != null and b != null and m.players.get_child_count() == 2, "只有自己和恐龍 boss（現在 %d 個）" % m.players.get_child_count())
	_ck(me.global_position.distance_to(b.global_position) > 60.0, "恐龍要生在遠處，靠導演給的方向找過來")
	_ck(me.viewmodel._weapons.all(func(w: Node) -> bool: return w.reserve == -1), "子彈無限")
	for i in 3:   # 死三次都要接得回來
		m.players.get_node(^"1").take_damage(9999)
		m.players.remove_child(m.players.get_node(^"1"))
		m._time_left -= m.RESPAWN_DELAY + 1.0
		m._respawn_step()
	_ck(m.players.has_node(^"1") and m._continues == 3 and not m._over, "接關無限：死了一直回來（接關 %d 次）" % m._continues)
	_ck(m._match_hud._boss_debug().begins_with("恐龍："), "畫面要顯示恐龍在做什麼")
	_end(m)

## 恐龍沙盒：自己當尼諾拉（編號 1 操作），H 叫獵人（最多 6 個）、J 全清；獵人打死不重生；回大廳旗標清掉
func _case_dino_sandbox() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	_ck(m.has_node(^"UI/Root/Lobby/DinoSandboxBtn"), "大廳要有恐龍沙盒")
	m.lobby_go(&"practice")
	_ck(m.get_node(^"UI/Root/Lobby/DinoSandboxBtn").visible, "單人練習那頁要看得到恐龍沙盒")
	m._on_dino_sandbox_pressed()
	var b: Node3D = m.players.get_node_or_null(NodePath(str(m.BOSS_ID)))
	_ck(b != null and b.pilot == 1 and m._me() == b and not m.players.has_node(^"1"), "尼諾拉要生出來，編號 1 操作它")
	_ck(m._dino_sandbox and m._offline and m._hunters().is_empty(), "進來時沒有獵人")

	m._summon_hunter()
	_ck(m._hunters().size() == 1, "按一次 H 多一個獵人")
	for i in m.DINO_SANDBOX_MAX:
		m._summon_hunter()
	_ck(m._hunters().size() == m.DINO_SANDBOX_MAX, "獵人最多 %d 個" % m.DINO_SANDBOX_MAX)

	m.clear_bots()
	_ck(m._hunters().is_empty() and m.players.has_node(NodePath(str(m.BOSS_ID))), "按 J 清掉所有獵人，尼諾拉還在")

	m._summon_hunter()
	var h: Node = m._hunters()[0]
	h.take_damage(9999)
	h.free()
	_ck(m._respawn_queue.is_empty(), "獵人打死不排重生")
	m._time_left -= m.RESPAWN_DELAY + 1.0
	m._respawn_step()
	_ck(m._hunters().is_empty(), "獵人打死後不會回來")

	m._to_lobby("")
	_ck(not m._dino_sandbox, "回大廳要清掉恐龍沙盒的旗標")
	_end(m)

## 回大廳要清乾淨，而且要能馬上重開一局
func _case_back_to_lobby() -> void:
	var m := _new_game()
	m._to_lobby("")
	_ck(m.players.get_child_count() == 0, "回大廳要把玩家清掉")
	_ck(m.multiplayer.multiplayer_peer == null, "回大廳要斷線")
	_ck(m.lobby.visible and not m.menu.visible, "回大廳要看得到大廳、選單要關掉")
	_ck(m._cowboys == 0 and not m._over, "計數和勝負狀態要歸零")

	m._on_host_pressed()  # 連接埠要放掉了，才開得起第二局
	m._spawn(2)
	_ck(m.players.get_child_count() == 3 and m._cowboys == 2, "要能馬上重開一局（連線模式大家都是牛仔）")
	_ck(m.players.has_node(NodePath(str(m.BOSS_ID))), "連線模式開房要自動生恐龍 boss")
	_end(m)

## 專用伺服器（測試站）：一局結束自動開下一局，人和 boss 都還在
func _case_dedicated_round() -> void:
	var m := _offline_match()
	m._dedicated = true
	m._add_player(m.COWBOY, 2)
	var dead: Node = m._add_player(m.COWBOY, -50)   # 電腦牛仔：局末剛死、還在等重生
	dead.set(&"bot", true)
	m.spawn_boss()
	m._on_died(null, dead)
	m.players.remove_child(dead)
	dead.free()
	m._over = true
	m._next_round = 0.0
	m._physics_process(0.1)
	_ck(m.players.has_node(^"-50"), "局末剛死在等重生的人，下一局要生回來（不然卡在觀戰）")
	var late: Node = m._add_player(m.COWBOY, -51)   # 結束畫面時才被打死
	late.set(&"bot", true)
	m._over = true
	m._on_died(null, late)
	m.players.remove_child(late)
	late.free()
	m._next_round = 0.0
	m._physics_process(0.1)
	_ck(m.players.has_node(^"-51"), "結束畫面時才死的人，下一局也要生回來")
	_ck(not m._over and m._time_left > m.MATCH_SECONDS - 1.0, "專用伺服器一局結束要自動開下一局")
	_ck(m.players.has_node(^"2") and m.players.has_node(NodePath(str(m.BOSS_ID))), "開下一局玩家和 boss 都要還在")
	_ck(m._cowboys == 3, "開下一局牛仔數要重算（現在 %d）" % m._cowboys)
	_end(m)

## 對抗模式：玩家操作尼諾拉（docs/規劃/2026-10-18-對抗模式.md）
func _case_versus() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"versus"))
	m._apply_rules()
	m._add_player(m.COWBOY, 1)
	m._add_player(m.COWBOY, 2)
	var b: Node = m.spawn_boss()
	b.global_position = m._on_ground(Vector3(0, BOSS_GD.LIFT, 40))   # 整平的路上，前面沒東西擋
	b.rotation.y = 0.0
	m._pick_pilot()
	_ck(b.pilot == 0, "沒人勾「我想當恐龍」：尼諾拉還是電腦")
	m.want_dino = true
	m._sandbox = true
	m._pick_pilot()
	_ck(b.pilot == 0, "沙盒、單人打恐龍：大廳選了對抗也不抽人")
	m._sandbox = false
	m.want_dino = false
	m.want_dino = true
	m._pick_pilot()
	_ck(b.pilot == 1 and not m.players.has_node(^"1"), "勾了就抽來當尼諾拉，自己的牛仔收掉")
	_ck(m._me() == b, "操作尼諾拉時「自己」就是尼諾拉（畫面資訊、體力條用）")
	# 往前跑：照輸入動、跑吃體力、轉身有限速
	for i in 60:   # 測試在第一格跑，物理還沒開始算、位置不會動：看速度
		b.pilot_input(Vector2(0, -1), 0.0, 0.0, b.PIN_RUN)
		b.think(1.0 / 60.0)
	_ck(b.running and b.velocity.z < -b.RUN * 0.8 and absf(b.velocity.x) < 0.5,
		"駕駛往前推＋Shift：尼諾拉往前跑（速度 %s）" % b.velocity)
	var y0: float = b.rotation.y
	b.pilot_input(Vector2.ZERO, PI * 0.9, 0.0, 0)
	b.think(0.1)
	_ck(absf(wrapf(b.rotation.y - y0, -PI, PI)) <= b.TURN * 0.1 + 0.01, "身體轉向鏡頭有限速（繞著牠跑有用）")
	# 兩招
	b.rotation.y = 0.0
	b.pilot_input(Vector2.ZERO, 0.0, 0.0, b.PIN_BITE)
	b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_BITE_WIND, "左鍵：咬的預備（有預備動作和吼聲）")
	for i in 120:
		b.pilot_input(Vector2.ZERO, 0.0, 0.0, 0)
		b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_NONE, "咬完收招回到可以動")
	b._attack_gap = 0.0
	b.pilot_input(Vector2.ZERO, 0.0, 0.0, b.PIN_SWEEP)
	b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_CHARGE_WIND, "右鍵：蓄力甩尾的預備")
	b.act = b.ACT_NONE
	# 網路斷斷續續：太久沒輸入就當放開
	b.pilot_input(Vector2(0, -1), 0.0, 0.0, 0)
	for i in 60:
		b.think(1.0 / 60.0)
	_ck(b._pin_move == Vector2.ZERO, "超過 %.1f 秒沒收到輸入就停下來" % b.PILOT_STALE)
	# 牛仔撿不到…尼諾拉也撿不到蛋（同搶蛋）；時間到沒人撤離 → 尼諾拉贏
	m._time_left = 0.0
	m._physics_process(1.0 / 60.0)
	_ck(m._over and m.get_node(^"UI/Root/Result/Box/Text").text.contains("尼諾拉獲勝"), "對抗模式時間到：尼諾拉贏")
	# 下一局：上一局的尼諾拉變回牛仔、重抽
	m.want_dino = false
	m._new_round()
	_ck(b.pilot == 0 and m.players.has_node(^"1"), "下一局：操作尼諾拉的人先變回牛仔")
	# 操作的人斷線：電腦接手
	m.want_dino = true
	m._pick_pilot()
	m._despawn(1)
	_ck(b.pilot == 0, "操作尼諾拉的人離線：電腦接手")
	m._pick_pilot()
	_ck(b.pilot == 0, "這局已經抽過：斷線後電腦接手到局末，不再抽別人")
	_end(m)

## 蛋：牛仔靠近撿走、跟著人跑、持有者死了掉在原地、帶進撤離區就贏
func _case_egg() -> void:
	var m := _new_game()
	var t2: Node3D = m.players.get_node(^"2")
	var t3: Node3D = m.players.get_node(^"3")
	m.players.get_node(^"1").global_position = Vector3(0, 500, 0)  # 恐龍閃遠一點
	t3.global_position = Vector3(0, 500, 40)

	# 撿蛋不是碰到就拿，要待滿 PICKUP_SECONDS
	t2.global_position = Vector3(0, 1, 0)
	m.egg.global_position = Vector3(1.5, 1, 0)
	m.egg.carrier = 0
	m._egg_step(DT)
	_ck(m.egg.carrier == 0 and m.egg.pickup > 0.0, "剛靠近只是開始撿，還沒拿到")

	# 中途走開會歸零
	t2.global_position = Vector3(60, 1, 0)
	m._egg_step(DT)
	_ck(is_zero_approx(m.egg.pickup), "離開就重來")

	# 回來待滿才真的拿到
	t2.global_position = Vector3(0, 1, 0)
	for i in int(m.PICKUP_SECONDS / DT) + 2:
		m._egg_step(DT)
	_ck(m.egg.carrier == 2, "待滿 %.0f 秒才撿得到（carrier=%d）" % [m.PICKUP_SECONDS, m.egg.carrier])

	# 跟著人跑
	t2.global_position = Vector3(20, 1, 20)
	m._egg_step(DT)
	_ck(m.egg.global_position.distance_to(t2.global_position) < 5.0, "蛋要跟著持有者移動")

	# 持有者陣亡 -> 蛋掉在原地，不會跟著消失
	var dropped: Vector3 = m.egg.global_position
	t2.free()
	m._egg_step(DT)
	_ck(m.egg.carrier == 0, "持有者陣亡後蛋要變成無人持有")
	_ck(m.egg.global_position.is_equal_approx(dropped), "蛋要留在原地，不會回到出生點")

	# 帶進撤離區 -> 牛仔獲勝
	_ck(m._exits.size() == 2, "應該有兩個撤離區（現在 %d 個）" % m._exits.size())
	t3.global_position = m._exits[0] + Vector3(0, 1, 0)
	m.egg.global_position = t3.global_position
	m.egg.carrier = 3

	# 進圈子還不算數，要待滿 EXTRACT_SECONDS
	m._egg_step(DT)
	_ck(not m._over and m.egg.extract > 0.0, "剛進撤離區只是開始倒數，還不能贏")

	# 中途離開會歸零
	t3.global_position = m._exits[0] + Vector3(0, 1, m.EXIT_RADIUS + 20.0)
	m._egg_step(DT)
	_ck(is_zero_approx(m.egg.extract), "離開撤離區進度要歸零")

	# 回來待滿才贏
	t3.global_position = m._exits[0] + Vector3(0, 1, 0)
	var steps := int(m.EXTRACT_SECONDS / DT) + 2
	for i in steps:
		m._egg_step(DT)
	_ck(m._over and m.status.text.contains("撤離"), "待滿 %.0f 秒才算撤離成功" % m.EXTRACT_SECONDS)
	_ck(m.status.text.contains("3") or m.status.text.contains("你"),
		"獲勝訊息要指名是哪個牛仔（現在是「%s」）" % m.status.text)
	_end(m)

## 重生：排隊、時間到才回場、靶的身分要保留
func _case_respawn() -> void:
	var m := _new_offline_game()
	var target: Node = m.players.get_node(^"2")
	_ck(target.bot, "靶一開始就是 bot")

	target.take_damage(9999)
	_ck(m._respawn_queue.size() == 1, "死掉要排進重生佇列")
	var r: Dictionary = m._respawn_queue[0]
	_ck(int(r["id"]) == 2 and bool(r["bot"]), "佇列要記住編號和靶的身分")

	m._respawn_step()
	_ck(m._respawn_queue.size() == 1, "還沒到時間不該重生")

	target.free()   # 模擬五秒後，屍體已經清掉
	m._respawn_queue[0]["at"] = m._time_left + 1.0
	m._respawn_step()
	var back: Node = m.players.get_node_or_null(^"2")
	_ck(back != null, "時間到要生回來")
	if back != null:
		_ck(back.hp == back.max_hp, "重生要滿血")
		_ck(back.bot, "重生後靶還是靶，不會變成真人操控的")
	_end(m)

## 派對模式甩尾拆地形（destructible.gd）：樹兩下倒、不在群組裡的（安全屋）不倒、倒了碰撞沒了。積木房子見 _case_party_cubes、_case_toy
func _case_party_destruction() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _offline_match()
	var tree: Destructible = null
	for w: Destructible in m._wrecks:
		if w.visual != null:   # 樹（外觀另外擺）
			tree = w
			break
	_ck(tree != null, "灰盒地圖要有拆得掉的樹（%d 樣）" % m._wrecks.size())
	if tree == null:
		_end(m)
		Main.level_file = keep
		return
	var b: Node3D = m.spawn_boss()
	_ck(b._sweep_cd_time() == b.SWEEP_CD, "其他模式甩尾冷卻不變")
	m.rules = &"party"   # ponytail: RULES 的 party 是 gameplay 加的，這裡只借 rules 這個值
	_ck(b._sweep_cd_time() == Balance.num("sweep_cd_party"), "派對模式甩尾冷卻照表（%s 秒）" % Balance.num("sweep_cd_party"))
	# 自己操作恐龍時，畫面上看得到甩尾冷卻；冷卻要同步給操作的客戶端（冷卻在主機算）
	var sync: MultiplayerSynchronizer = b.find_children("*", "MultiplayerSynchronizer")[0]
	_ck(sync.replication_config.has_property(^".:sweep_left"), "甩尾冷卻要同步出去")
	b.pilot = 1
	b.sweep_left = 12.3
	m._match_hud._update_boss_bar(b)
	_ck(m._match_hud._boss_label.text.ends_with("甩尾 13 秒"), "操作恐龍要看得到甩尾還剩幾秒（現在「%s」）" % m._match_hud._boss_label.text)
	b.sweep_left = 0.0
	m._match_hud._update_boss_bar(b)
	_ck(m._match_hud._boss_label.text.ends_with("甩尾 可用"), "冷卻好了要寫可用")
	b.pilot = 0
	m._match_hud._update_boss_bar(b)
	_ck(not "甩尾" in m._match_hud._boss_label.text, "別人操作（或電腦）的恐龍不顯示甩尾冷卻")
	# 恐龍站在樹旁邊甩尾，旁邊擺一間沒進群組的安全屋
	var base := Vector3(tree.global_position.x, 0, tree.global_position.z)
	b.global_position = m._on_ground(base + Vector3(4, BOSS_GD.LIFT, 0))
	var safe := Greybox.house(Vector3(5, 3, 5), 1)
	safe.add_to_group(&"safe_house")
	m.map._place_greybox(safe, b.global_position * Vector3(1, 0, 1) + Vector3(0, 0, 6), 0.0)
	var space: PhysicsDirectSpaceState3D = m.get_viewport().world_3d.direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(tree.global_position + Vector3(-3, 0, 0), tree.global_position + Vector3(3, 0, 0))
	_ck(space.intersect_ray(ray).get(&"collider") == tree, "倒之前樹幹擋得住")
	# 只拆後方半圈：樹在正前方（背後朝 +X）甩不到，背後朝 -X 樹在後面才倒
	b.rotation.y = PI * 0.5
	b._strike_sweep()
	_ck(tree.hits == 0 and tree.is_in_group(&"destructible"), "樹在正前方甩不到（只拆後方）")
	b.rotation.y = -PI * 0.5
	b._strike_sweep()
	_ck(tree.hits == 1 and tree.collision_layer != 0 and tree.is_in_group(&"destructible"), "樹（等級 2）甩一下還站著")
	b._strike_sweep()
	_ck(tree.hits == 2 and tree.collision_layer == 0 and not tree.is_in_group(&"destructible"), "樹甩兩下就倒")
	_ck(space.intersect_ray(ray).get(&"collider") != tree, "倒了的樹沒有碰撞")
	_ck(safe.collision_layer != 0, "不在群組裡的東西（安全屋）甩不倒")
	# 挨打、倒下的回饋（音效檔還沒放進來，前面甩倒的時候已經跑過，不能報錯）：鏡頭晃動設 0 就不震
	var old_shake: Variant = Settings.v.get(&"shake", 1.0)
	Settings.v[&"shake"] = 0.0
	_ck(tree._smash_fx(false) == 0.0 and Destructible.hit_fx(tree, tree.global_position, true) == 0.0, "鏡頭晃動設 0 時不震")
	Settings.v[&"shake"] = old_shake
	m.rules = &"egg"
	_end(m)
	Main.level_file = keep

## 派對方塊房子（草案 4.1、4.2）：只在派對模式看得到、拆得掉；53 塊、等級 1、2、3 各 29、12、12；門口和窗戶留空；
## 甩尾（smash）、火球（boss._spit_fire 設 wreck，半徑 2 公尺內的塊）、炸藥（viewmodel._explode）各照等級拆；子彈穿材質照等級
func _case_party_cubes() -> void:
	_party_cubes_body()

func _party_cubes_body() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	_park(m)   # 物理那段才放回去（見 _with_first）
	var house: ToyBuild = m.map._party_house
	_ck(house != null, "灰盒地圖要有方塊房子")
	if house == null:
		_end(m)
		Main.level_file = keep
		return
	var n := house.brick_count()
	var by := {1: 0, 2: 0, 3: 0}
	for i in n:
		by[house.level_of(i)] += 1
	_ck(n == 53 and by == {1: 29, 2: 12, 3: 12}, "方塊房子 53 塊、等級 1、2、3 各 29、12、12（現在 %d 塊 %s）" % [n, by])
	_ck(house.name == "Toy%d" % m.map._toys.find(house), "方塊房子名字要照蓋的順序（%s）" % house.name)
	# 門口（正面靠左那一格）兩層都空；窗戶（左側牆中間那格）只留窗台
	_ck(_brick_at(house, Vector3(-0.75, 0.75, 2.25)) == -1 and _brick_at(house, Vector3(-0.75, 2.25, 2.25)) == -1, "門口兩層都空")
	_ck(_brick_at(house, Vector3(-2.25, 0.75, -0.75)) != -1 and _brick_at(house, Vector3(-2.25, 2.25, -0.75)) == -1, "窗戶只留窗台、窗頂以上空")
	_ck(m.map._party_at.is_finite() and m.map.spawn_points.all(func(s: Vector3) -> bool: return Vector2(s.x - m.map._party_at.x, s.z - m.map._party_at.z).length() > 6.0), "方塊房子離出生點要有距離")
	# 不是派對：整棟藏起來，碰撞和群組都拿掉
	_ck(not house.visible and house.collision_layer == 0 and not house.is_in_group(&"destructible"), "非派對模式房子藏起來、沒有碰撞")
	m.rules = &"party"
	m.map.set_party_house(m.party_mode())
	_ck(house.visible and house.collision_layer != 0 and house.is_in_group(&"destructible"), "派對模式房子看得到、拆得掉")
	# 甩尾：等級 1 一下倒、等級 2 兩下、等級 3 甩多少下都不倒（挑的塊都在地基或屋頂，不會連帶掉別的塊）
	var one := _first_brick(house, 1, 3.5)   # 屋頂
	var two := _first_brick(house, 2)        # 地板（在地基上）
	var three := _first_brick(house, 3)      # 地基
	_hit_brick(house, one, 2)
	_ck(not house.is_standing(one), "等級 1 的方塊甩一下就倒")
	_hit_brick(house, two, 2)
	_ck(house.is_standing(two) and house.hp_of(two) == 1, "等級 2 的方塊甩一下還站著")
	_hit_brick(house, two, 2)
	_ck(not house.is_standing(two), "等級 2 的方塊甩兩下倒")
	for k in 5:
		_hit_brick(house, three, 2)
	_ck(house.is_standing(three) and house.hp_of(three) == 3, "等級 3 的方塊甩五下還是不倒")
	# 火球、炸藥、子彈要跑物理（射線、形狀查詢），過幾幀再驗
	_defer(4, func() -> void:
		_with_first(m, func() -> void: _cubes_physics(m, house, one, three))
		_free_map(m))
	Main.level_file = keep

## 方塊房子的物理部分（_case_party_cubes 過幾幀才跑）：火球、炸藥、子彈穿材質
func _cubes_physics(m: Node, house: ToyBuild, one: int, three: int) -> void:
	# 火球：走 boss._spit_fire（它設 wreck）；打中的塊半徑 2 公尺內都算。等級 3 的不扣
	var boss: Node3D = m.spawn_boss()
	var lone := _first_standing(house, 1, 3.5)   # 屋頂，等級 1（前面甩倒的那塊不算）
	var lone2 := -1
	for i in _standing(house, 1):   # 離 lone 2.5 公尺以上：火球半徑 2 公尺，lone 那一發已經會把近的一起扣掉
		if house.center_of(i).y - house.global_position.y > 3.5 and house.center_of(i).distance_to(house.center_of(lone)) > 2.5:
			lone2 = i
			break
	var b3 := three   # 地基，等級 3
	_spit_at(m, boss, house, lone)
	_ck(not house.is_standing(lone), "派對模式尼諾拉的火球打中等級 1 的方塊：扣一下、倒")
	_spit_at(m, boss, house, b3)
	_ck(house.is_standing(b3) and house.hp_of(b3) == 3, "火球打中等級 3 的方塊不扣")
	# 非派對：火球照拆（沒有模式的擋）
	m.rules = &"egg"
	m.map.set_party_house(true)
	_spit_at(m, boss, house, lone2)
	_ck(not house.is_standing(lone2), "非派對模式尼諾拉的火球也拆方塊")
	m.rules = &"party"
	m.map.set_party_house(true)
	# 炸藥：爆炸點在房子前面（-Z）4 公尺，範圍 6 公尺內的等級 1 要拆
	var at := house.global_position + Vector3(0, 1.5, -4.0)
	var player: Node3D = m._add_player(m.COWBOY, 1)
	player.global_position = m._on_ground(Vector3(house.global_position.x, 0, house.global_position.z - 8.0))
	var vm = player.viewmodel
	# (b) 派對、丟的人被自己炸死（扣血前活著）：範圍內等級 1 照拆
	player.hp = 1
	var inside := _standing(house, 1).filter(func(i: int) -> bool: return house.center_of(i).distance_to(at) < 6.0)
	vm._explode(at, Viewmodel.KIND_DYNAMITE)
	_ck(player.hp <= 0, "丟的人被自己的炸藥炸死（前提）")
	_ck(not inside.is_empty() and inside.all(func(i: int) -> bool: return not house.is_standing(i)), "丟的人自己被炸死，範圍內等級 1 照拆")
	# (c) 丟的人是恐龍（沒有獵人身分）：不拆
	var dino_thrower: Node3D = m._add_player(m.COWBOY, 5)
	dino_thrower.global_position = m._on_ground(Vector3(house.global_position.x, 0, house.global_position.z + 8.0))
	dino_thrower.add_to_group(&"dino")
	var at2 := house.global_position + Vector3(0, 1.5, 4.0)
	var before := _standing(house, 1).size()
	dino_thrower.viewmodel._explode(at2, Viewmodel.KIND_DYNAMITE)
	_ck(_standing(house, 1).size() == before, "丟的人是恐龍，炸藥不拆方塊")
	# 等級 3 不受炸藥影響
	_ck(house.is_standing(three) and house.hp_of(three) == 3, "炸藥不影響等級 3")
	# 子彈穿材質：木板（等級 1）力量 1 穿得過，雙層（2）要 2，金屬（3）要 3
	var s1 := _first_brick(house, 1)
	var s2 := _first_brick(house, 2)
	var s3 := _first_brick(house, 3)
	_ck(Bullet.pierces(house, 1, s1) and not Bullet.pierces(house, 1, s2) and Bullet.pierces(house, 2, s2) and not Bullet.pierces(house, 2, s3) and Bullet.pierces(house, 3, s3), "方塊的子彈穿透照等級")


## 還站著、等級 level 的方塊編號
func _standing(t: ToyBuild, level: int) -> Array:
	var out := []
	for i in t.brick_count():
		if t.level_of(i) == level and t.is_standing(i):
			out.append(i)
	return out

## 第一塊等級 level 的方塊編號（min_y：高於這棟原點幾公尺，預設不限；用來挑屋頂或地基）
func _first_brick(t: ToyBuild, level: int, min_y := -INF) -> int:
	for i in t.brick_count():
		if t.level_of(i) == level and t.center_of(i).y - t.global_position.y > min_y:
			return i
	return -1

## 第一塊還站著、等級 level、高於 min_y 的方塊編號
func _first_standing(t: ToyBuild, level: int, min_y := -INF) -> int:
	for i in _standing(t, level):
		if t.center_of(i).y - t.global_position.y > min_y:
			return i
	return -1

## 這棟本地座標 local 上的那一塊的編號（沒有就 -1）
func _brick_at(t: ToyBuild, local: Vector3) -> int:
	var g := t.global_transform * local
	for i in t.brick_count():
		if t.center_of(i).distance_to(g) < 0.01:
			return i
	return -1

## 打第 i 塊一下（只打它：hit 只認它的中心）
func _hit_brick(t: ToyBuild, i: int, max_level: int) -> void:
	var c := t.center_of(i)
	t.smash(func(p: Vector3) -> bool: return p.distance_to(c) < 0.01, max_level, Vector3.ZERO)

## 尼諾拉從房子前面（-Z）吐一顆火球打第 i 塊（boss._spit_fire 設 wreck）。先確認射線真的先打到那一塊
func _spit_at(m: Node, boss: Node3D, house: ToyBuild, i: int) -> void:
	var start: Vector3 = house.center_of(i) + Vector3(0, 0, -4.0)
	var space: PhysicsDirectSpaceState3D = house.get_world_3d().direct_space_state
	var pre := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + Vector3(0, 0, 7.5)))
	_ck(pre.get(&"collider") == house and pre.get(&"shape") == i, "火球的射線要先打到目標（積木 %d）" % i)
	boss._spit_fire(Vector3(0, 0, 1), start)
	var fb: Fireball = m.get_node(^"Arena").get_children().filter(func(c: Node) -> bool: return c is Fireball).back()
	fb._physics_process(0.3)   # 25 公尺／秒 × 0.3 秒 = 7.5 公尺，剛好打到目標

## 玩具積木（toy_build.gd、greybox.gd bricks）：房子切成積木、安全屋和掩體拆不掉、連通檢查（懸空的鬆脫）、碎塊留在場上、
## 碎塊停下來（主機送、各台一樣）、晚加入補送、新的一場還原、非派對模式甩尾也拆得到
func _case_toy() -> void:
	_toy_body()

func _toy_body() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	_park(m)   # 物理那段才放回去（見 _with_first）
	var party_house: ToyBuild = m.map._party_house
	# 灰盒的房子是積木；切出來的塊不超過 1.5 × 0.75（斜坡整片一塊，不算）；每棟幾十到幾百塊
	var recs: Array = m.map._level.filter(func(r: Dictionary) -> bool: return r.kind == &"gb_house")
	var houses: Array = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t != party_house)
	var nblock: int = m.map._level.filter(func(r: Dictionary) -> bool: return r.kind == &"gb_block").size()
	_ck(recs.size() > 0 and houses.size() == recs.size() + nblock, "灰盒房子和掩體方塊每棟都是積木、拆得掉（房子 %d 棟、掩體 %d 個，積木 %d 棟）" % [recs.size(), nblock, houses.size()])
	var lim_ok := true
	var sized := true
	for rec: Dictionary in recs:
		var bl := Greybox.bricks(Greybox.house_pieces(rec.size, rec.floors, rec.big), rec.pos)
		sized = sized and bl.size() >= 30 and bl.size() <= 2000   # 一般的 180 到 700 塊；最大的兩棟（高 13 公尺）過千
		for b: Array in bl:
			var xf: Transform3D = b[0]
			var s: Vector3 = b[1]
			if xf.basis.is_equal_approx(Basis()) and (s.x > Greybox.BRICK_W + 0.01 or s.z > Greybox.BRICK_W + 0.01 or s.y > Greybox.BRICK_H + 0.01):
				lim_ok = false
	_ck(lim_ok, "切出來的積木不超過 1.5 × 0.75（斜坡除外）")
	_ck(sized, "每棟房子幾十到幾百塊")
	var total := 0
	for t: ToyBuild in m.map._toys:
		total += t.brick_count()   # 每塊一個碰撞形狀
	print("玩具積木：整張灰盒地圖 %d 個積木（%d 棟，每塊一個碰撞形狀）" % [total, m.map._toys.size()])
	# 安全屋：積木、全部等級 3、不進 destructible；掩體方塊也不進 destructible
	var safes := m.get_tree().get_nodes_in_group(&"safe_house")
	var safe_ok := not safes.is_empty()
	for s: Node in safes:
		var st := s as ToyBuild
		safe_ok = safe_ok and st != null and not st.can_break and not st.is_in_group(&"destructible")
		if st:
			for i in st.brick_count():
				safe_ok = safe_ok and st.level_of(i) == 3
	_ck(safe_ok, "安全屋是積木、全部等級 3、拆不掉（不進 destructible）")
	var nsafe: int = m.map._level.filter(func(r: Dictionary) -> bool: return r.kind == &"gb_safe").size()
	var nonbreak: int = m.map._toys.filter(func(t: ToyBuild) -> bool: return not t.can_break).size()
	_ck(nonbreak == nsafe, "只有安全屋拆不掉，掩體方塊是積木、拆得掉（安全屋 %d 個，拆不掉的 %d 個）" % [nsafe, nonbreak])
	# 連通檢查：中間那塊拆掉，上面懸空的也鬆脫；底下的站著
	var col := ToyBuild.make(_column_bricks())
	col.name = "ToyCol"
	m.map.add_child(col)
	col.position = m.map._on_ground(Vector3(-50, 0, -50))
	_hit_brick(col, 1, 1)
	_ck(not col.is_standing(1) and not col.is_standing(2) and col.is_standing(0), "拆掉中間那塊，懸空的上面那塊也鬆脫，底下的站著")
	var rb := _piece_node(col, 1)
	_ck(rb is RigidBody3D and rb.collision_layer == 1 | Fighter.SOLID_LAYER and rb.is_in_group(&"toy_piece"), "鬆脫的塊變成碎塊（RigidBody3D、碰撞層 1 加 16、群組 toy_piece）")
	_ck(_piece_node(col, 2) is RigidBody3D, "懸空的那塊也變成碎塊")
	# 碎塊還在飛：沒停下來前是 RigidBody3D；4 秒後（主機送 _settle）換成靜態的，還在場上
	col._physics_process(4.1)
	var st := _piece_node(col, 2)
	_ck(st is StaticBody3D and st.is_in_group(&"toy_piece") and not st.is_queued_for_deletion(), "4 秒後碎塊停下來（靜態），還在場上、沒被刪")
	# 停下來的位置照主機算的擺（兩台一致）：直接呼叫 _settle 到指定位置
	var ids := col.loose_ids()
	var moved: Array = col.loose_xforms().map(func(x: Transform3D) -> Transform3D: return x.translated(Vector3(0, 1, 0)))
	col._settle(ids, moved)
	_ck(_piece_node(col, 1).global_transform.is_equal_approx(moved[0]) and _piece_node(col, 1) is StaticBody3D, "_settle 後碎塊到指定位置並凍住")
	# 導航烘焙要讀得到凍住的碎塊（靜態碰撞體）：從碎塊本身解析，有頂點才算
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var sv := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, sv, _piece_node(col, 1))
	_ck(sv.get_vertices().size() > 0, "導航烘焙讀得到凍住的碎塊（靜態碰撞體）")
	# 晚加入：另一份積木照補送的資料擺，鬆脫的塊一樣、碎塊在同樣位置
	var late := ToyBuild.make(_column_bricks())
	late.name = "ToyLate"
	m.map.add_child(late)
	late.position = col.position
	late._resume(ids, moved, PackedInt32Array())
	_ck(not late.is_standing(1) and not late.is_standing(2) and late.is_standing(0), "晚加入的人：鬆脫的塊一樣")
	_ck(_piece_node(late, 1) != null and _piece_node(late, 1).global_transform.is_equal_approx(moved[0]) and _piece_node(late, 2).global_transform.is_equal_approx(moved[1]), "晚加入的人：碎塊在同樣位置")
	_end_piece(late)   # 測試用的積木用完就收
	# 挨一下沒倒（等級 2）：站著、扣了血、有挨打記號
	var hurt := ToyBuild.make([[Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.5, 1.5, 1.5), 2, Color.RED]])
	hurt.name = "ToyHurt"
	m.map.add_child(hurt)
	hurt.position = m.map._on_ground(Vector3(-50, 0, -40))
	_hit_brick(hurt, 0, 2)
	_ck(hurt.is_standing(0) and hurt.hp_of(0) == 1 and hurt.has_damage() and hurt.get_parent().get_node_or_null(NodePath("%s_P0" % hurt.name)) == null, "等級 2 挨一下還站著、有挨打記號、沒有碎塊")
	# 新的一場：碎塊刪掉、塊回來、血量回滿
	col.restore()
	_ck(_piece_node(col, 1) == null and col.loose_ids().is_empty() and col.is_standing(1) and col.hp_of(1) == 1 and not col.has_damage(), "新的一場：碎塊刪掉、塊回來、血量回滿")
	hurt.restore()
	_ck(not hurt.has_damage() and hurt.hp_of(0) == 2, "新的一場：挨一下的也回滿")
	# 子彈穿材質：單塊的（等級 1 木板）力量 1 穿得過；安全屋沒有材質，照以前穿不過
	_ck(Bullet.pierces(col, 1, 1) and not Bullet.pierces(col, 1, 0) and Bullet.pierces(col, 3, 0), "積木的子彈穿透照塊的等級")
	# 非派對模式甩尾（_wreck_around）也拆得到積木；派對方塊房子這時藏著
	m.rules = &"egg"
	var base := Vector3(20, 0, -20)
	var one := ToyBuild.make([[Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.5, 1.5, 1.5), 1, Color.BLUE]])
	one.name = "ToyOne"
	m.map.add_child(one)
	one.position = m.map._on_ground(base)
	_ck(not m.party_mode() and not party_house.visible and party_house.collision_layer == 0 and not party_house.is_in_group(&"destructible"), "非派對模式：派對方塊房子藏起來、沒有碰撞")
	_defer(4, func() -> void:
		_with_first(m, func() -> void:
			var b: Node3D = m.spawn_boss()
			b.rotation.y = -PI * 0.5   # 背後朝 -X
			b.global_position = m.map._on_ground(base + Vector3(4, BOSS_GD.LIFT, 0))
			b._strike_sweep())
		_ck(not one.is_standing(0), "非派對模式（死鬥）甩尾也拆得到積木（後方半圈）")
		_free_map(m))
	Main.level_file = keep

## 連通檢查用的三塊直條：底下是地基（等級 3），中間一塊等級 1，最上面一塊等級 1 懸在中間那塊上面
func _column_bricks() -> Array:
	return [
		[Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.5, 0.5, 1.5), 3, Color(0.5, 0.5, 0.5)],
		[Transform3D(Basis(), Vector3(0, 0.875, 0)), Vector3(1.5, 0.75, 1.5), 1, Color.RED],
		[Transform3D(Basis(), Vector3(0, 1.625, 0)), Vector3(1.5, 0.75, 1.5), 1, Color.RED],
	]

## 碎塊的節點（已經排進刪除佇列的不算）
func _piece_node(t: ToyBuild, i: int) -> Node3D:
	var n: Node3D = t.get_parent().get_node_or_null(NodePath("%s_P%d" % [t.name, i]))
	return null if n == null or n.is_queued_for_deletion() else n

## 測試用的積木用完就收掉
func _end_piece(t: ToyBuild) -> void:
	t.get_parent().remove_child(t)
	t.free()

## 派對畫面（party_hud.gd）：用沒放進場景樹的 Party（只裝值，request_respawn_at 改成記下來）驗各階段文字、分數板排序、選重生點
func _case_party_hud() -> void:
	var fake := GDScript.new()
	fake.source_code = """extends Party
var asked: Array = []
func request_respawn_at(i: int) -> void:
	asked.append(i)
"""
	fake.reload()
	var m := _offline_match()
	var hud: PartyHud = m.get_node("UI/Root").get_children().filter(func(n: Node) -> bool: return n is PartyHud).front()
	hud._process(0.0)
	_ck(not hud.visible, "不是派對模式（party 是 null）整個畫面要藏起來")
	var me: int = m.multiplayer.get_unique_id()
	var p: Party = fake.new()   # 不放進場景樹：自己不跑規則，只拿來裝值
	p.phase = &"prep"
	p.time_left = 15.0
	p.names = {me: "阿明", 2: "小華", 3: "大雄", 4: "胖虎"}
	p.scores = {me: 3, 2: 12, 3: 7, 4: 0}
	p.round_scores = {me: 1, 2: 10, 3: 2, 4: 0}
	p.lives = {me: 3, 3: 3, 4: 3}
	p.dino_id = 2
	m.party = p
	hud._process(0.0)
	_ck(hud.visible, "派對模式要顯示")
	_ck(hud.top.text.begins_with("第 1／4 回合　　準備 0:15"), "上方要寫回合和準備倒數（現在：%s）" % hud.top.text)
	_ck("恐龍：小華" in hud.top.text and "你剩 3 條命" in hud.top.text, "上方要寫誰是恐龍、自己剩幾條命（現在：%s）" % hud.top.text)
	_ck(hud.hint.text == "看恐龍把蛋藏去哪", "準備階段牛仔的提示（現在：%s）" % hud.hint.text)
	p.dino_id = me
	hud._process(0.0)
	_ck("F" in hud.hint.text and "命" not in hud.top.text, "準備階段恐龍要提示按 F 放蛋、不顯示命（現在：%s／%s）" % [hud.hint.text, hud.top.text])
	p.dino_id = 2
	p.phase = &"play"
	p.time_left = 210.0
	p.changed.emit()
	hud._process(0.0)
	_ck("遊戲 3:30" in hud.top.text, "遊戲階段倒數 3:30（現在：%s）" % hud.top.text)
	# 分數板：照總分排（表頭 4 格之後，每列 4 格：名次、名字、本回合、總分）
	var names := []
	var cells := hud.board_rows.get_children()
	for i in range(5, cells.size(), 4):
		names.append(cells[i].text)
	_ck(names == ["小華", "大雄", "阿明（你）", "胖虎"], "分數板要照總分排（現在：%s）" % [names])
	# 選重生點：自己死了（場上沒有自己）才有
	m.spawn_points.assign([Vector3(0, 0, -50), Vector3(60, 0, 0), Vector3(0, 0, 40)])
	var mine: Node = m._me()
	if mine:
		mine.get_parent().remove_child(mine)
		mine.free()
	hud._process(0.0)
	_ck(hud.hint.text.begins_with("按 1～3 選重生點"), "死了要提示按 1～3 選重生點（現在：%s）" % hud.hint.text)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_2
	hud._unhandled_input(key)
	key.physical_keycode = KEY_9   # 超過點數的鍵不理
	hud._unhandled_input(key)
	_ck(p.asked == [1], "按 2 要呼叫 request_respawn_at(1)（現在：%s）" % [p.asked])
	# 回合結算：中間顯示怎麼結束的，幾秒後自動消失
	p.phase = &"result"
	p.last_result = "時間到，恐龍守住蛋"
	p.changed.emit()
	hud._process(0.0)
	_ck(hud.popup.visible and hud.popup_title.text == p.last_result, "結算要顯示怎麼結束的")
	hud._process(hud.RESULT_SHOW + 0.1)
	_ck(not hud.popup.visible, "結算框幾秒後要自己消失")
	# 四回合結束：冠軍放大
	p.phase = &"final"
	p.round_index = 4   # 跟 party.gd 一樣：final 時已經加到 rounds
	p.changed.emit()
	hud._process(0.0)
	_ck(hud.top.text.begins_with("第 4／4 回合") and "命" not in hud.top.text, "結束時停在第 4／4 回合、不顯示命（現在：%s）" % hud.top.text)
	_ck(hud.popup.visible and hud.popup_champ.visible and "小華" in hud.popup_champ.text,
		"最終排名第一名要放大顯示（現在：%s）" % hud.popup_champ.text)
	m.party = null
	p.free()
	_end(m)


## 派對模式（party.gd）：輪流當恐龍、計分、命數、蛋。舊模式不受影響
func _case_party_gameplay() -> void:
	# 大廳的單人派對：離線、一個人就開得了，電腦補到四個
	var solo: Node = load("res://main.tscn").instantiate()
	root.add_child(solo)
	_ck(solo.has_node(^"UI/Root/Lobby/SoloPartyBtn"), "大廳要有單人派對")
	# 大廳的東西都要登記在某一頁（LOBBY_PAGES），沒登記的換頁時會被藏掉、玩家看不到
	var listed := []
	for pg: Array in solo.LOBBY_PAGES.values():
		listed.append_array(pg)
	var unlisted: Array = solo.lobby.get_children().map(func(c: Node) -> String: return String(c.name)).filter(func(n: String) -> bool: return not n in listed)
	_ck(unlisted.is_empty(), "大廳的按鈕都要登記在 LOBBY_PAGES（漏了 %s）" % [unlisted])
	solo.lobby_go(&"practice")
	_ck(solo.get_node(^"UI/Root/Lobby/SoloPartyBtn").visible, "單人練習那頁要看得到單人派對")
	solo._on_solo_party_pressed()
	solo._physics_process(DT)
	_ck(solo.rules == &"party" and solo._offline and solo.party != null and solo.party.phase == &"prep"
		and solo.party.scores.size() == 4, "單人派對要直接開第一回合，電腦補到四人")
	_end(solo)
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	_ck(p != null and m.get_node_or_null(^"Party") == p, "派對模式 main 底下要有 $Party")
	m._physics_process(DT)   # 第一幀開場
	_ck(p.phase == &"prep" and p.round_index == 0 and p.time_left == p.PREP_SECONDS, "開場是第一回合的準備階段")
	_ck(p.scores.size() == 4 and p.scores.has(-3), "不到四人用電腦補到四個")
	_ck(p.dino_id == 1, "第一回合由編號最小的真人（主機 1）當恐龍")
	var b: Node3D = m._boss()
	_ck(b != null and b.pilot == 1 and not m.players.has_node(^"1"), "真人當恐龍：操作尼諾拉，自己的牛仔收掉")
	var bots: Array = [-1, -2, -3].map(func(id: int) -> Node: return m.players.get_node_or_null(NodePath(str(id))))
	_ck(not bots.has(null) and bots.all(func(c: Node) -> bool: return c.bot), "其他三個是牛仔 bot")
	_ck(m.party_frozen() and bots[0].frozen(), "準備階段牛仔不能動、不能開槍")
	var hp0: int = bots[0].hp
	bots[0].take_damage(30, b)
	_ck(bots[0].hp == hp0, "準備階段不扣血")
	# 準備階段恐龍按 F 放蛋
	b.global_position = m._on_ground(Vector3(0, BOSS_GD.LIFT, 40))
	p.place_egg()
	_ck(p.egg_placed and Vector2(m.egg.global_position.x - 0, m.egg.global_position.z - 40).length() < 0.1, "恐龍按 F 蛋放在腳下")
	for c: Node3D in bots:
		c.global_position = Vector3(0, 800, 0)   # 牛仔閃遠一點
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"play" and p.time_left == p.PLAY_SECONDS and not m.party_frozen(), "準備時間到進遊戲時間，牛仔能動了")
	for i in 30:
		m._physics_process(DT)
	_ck(m.egg.carrier == 0, "恐龍站在蛋上也撿不到")
	b.take_damage(b.max_hp + 10)
	_ck(is_instance_valid(b) and not b.is_queued_for_deletion(), "派對模式恐龍不會死")
	# 帶蛋的被恐龍殺：恐龍 +1、扣一條命、10 秒後重生、蛋掉在原地
	var c1: Node3D = bots[0]
	c1.global_position = m._on_ground(Vector3(-30, 1.0, 20))
	m.egg.carrier = -1
	m._physics_process(DT)
	c1.take_damage(9999, b)
	m.players.remove_child(c1)
	c1.free()
	m._physics_process(DT)
	_ck(m.egg.carrier == 0 and m.egg.global_position.distance_to(m._on_ground(Vector3(-30, 0.5, 20))) < 0.1, "帶蛋的死了，蛋掉在原地的地上")
	_ck(int(p.scores[1]) == 1 and int(p.lives[-1]) == 2 and p._waiting.has(-1), "恐龍殺一個 +1、牛仔扣一條命、排重生")
	p._waiting[-1][0] = 0.0
	m._physics_process(DT)
	_ck(m.players.has_node(^"-1"), "重生時間到生回來")
	# 牛仔的命全部用完 → 恐龍贏（守蛋 +10）
	for id in [-1, -2, -3]:
		p.lives[id] = 1
		var c: Node = m.players.get_node(NodePath(str(id)))
		c.take_damage(9999, b)
		m.players.remove_child(c)
		c.free()
	_ck(p._waiting.is_empty(), "最後一條命死了不排重生")
	_ck(m._is_out(-1) and not m._is_out(1), "命用完算出局（接觀戰鏡頭），恐龍不算")
	m._physics_process(DT)
	_ck(p.phase == &"result" and int(p.scores[1]) == 4 * p.SCORE_KILL + p.SCORE_GUARD, "命用完恐龍贏：4 殺 + 守蛋 %d（現在 %s）" % [p.SCORE_GUARD, p.scores])
	_ck(not m.result.visible and not m._over, "回合之間不跳舊的勝負畫面")
	# 第二回合換人當恐龍：電腦（-1）當，主機變回牛仔
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.round_index == 1 and p.phase == &"prep" and p.dino_id == -1, "第二回合由第二個人當恐龍")
	_ck(b.pilot == 0 and m.players.has_node(^"1") and not m.players.has_node(^"-1"), "電腦當恐龍：boss 自己跑，主機變回牛仔")
	_ck(int(p.lives[1]) == p.LIVES and p.round_scores.is_empty(), "新回合命補滿、本回合分數歸零")
	p.time_left = 0.0
	m._physics_process(DT)
	# 帶蛋撤離 → 回合馬上結束：撤離的 8 + 活著 2，其他活著的 2
	var me: Node3D = m.players.get_node(^"1")
	for id in [-2, -3]:
		m.players.get_node(NodePath(str(id))).global_position = Vector3(0, 800, 0)
	me.global_position = m._exits[0] + Vector3(0, 1, 0)
	m.egg.carrier = 1
	m.egg.extract = m.extract_seconds() - DT * 0.5   # 派對模式的撤離時間（表裡的派對值，不是非派對的 EXTRACT_SECONDS）
	m._physics_process(DT)
	_ck(p.phase == &"result" and int(p.round_scores.get(1, 0)) == 10 and int(p.round_scores.get(-2, 0)) == 2
		and int(p.round_scores.get(-1, 0)) == 0, "帶蛋撤離 10 分、其他活著的 2 分、恐龍沒守住 0 分（%s）" % p.round_scores)
	_ck(not m.result.visible and not m._over, "撤離也不跳舊的勝負畫面")
	# 第三回合時間到：恐龍守蛋 +10、活著的牛仔 +2
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.dino_id == -2, "第三回合由第三個人當恐龍")
	p.time_left = 0.0
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"result" and int(p.round_scores.get(-2, 0)) == p.SCORE_GUARD and int(p.round_scores.get(1, 0)) == 2, "時間到：恐龍 %d、活著的牛仔 2（%s）" % [p.SCORE_GUARD, p.round_scores])
	# 四回合後排名
	p.round_index = 3
	p.time_left = 0.0
	m._physics_process(DT)
	# 1 號的總分：第一回合當恐龍（4 殺＋守蛋）、第二回合撤離＋活著、第三回合活著
	_ck(p.phase == &"final" and p.ranking()[0] == 1 and int(p.scores[1]) == 4 * p.SCORE_KILL + p.SCORE_GUARD + p.SCORE_EXTRACT + 2 * p.SCORE_SURVIVE, "四回合結束、照總分排名（%s）" % p.scores)
	_end(m)
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"egg"))
	m._apply_rules()
	_ck(m.party == null and not m.party_frozen(), "其他模式沒有 $Party")
	_end(m)

## 斷線重連：60 秒內同一個代號連回來，拿回命數、出局狀態、派對分數；過期、新局就當新人
func _case_reconnect() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"deathmatch"))
	m._apply_rules()
	for id in [1, 2, 3]:
		m._add_player(m.COWBOY, id)
	m._key_of[2] = "k2"
	m._lives[2] = 1
	m._despawn(2)
	_ck(not m._lives.has(2) and m._held.has("k2"), "斷線：命數先拿掉、資料存起來")
	m._key_of[9] = "k2"
	m._reclaim(9)
	_ck(int(m._lives.get(9, -1)) == 1 and not m._held.has("k2"), "同代號連回來拿回剩 1 次")
	# 出局的人連回來還是出局
	m._key_of[3] = "k3"
	m._out[3] = false
	m._despawn(3)
	m._key_of[10] = "k3"
	m._reclaim(10)
	_ck(m._out.has(10) and m._is_out(10), "出局的人連回來還是出局")
	# 過期
	m._key_of[9] = "k2"   # 9 再斷一次
	m._despawn(9)
	m._held["k2"].at -= m.RECONNECT_MS + 1000
	m._key_of[11] = "k2"
	m._reclaim(11)
	_ck(not m._lives.has(11), "超過時間連回來當新人")
	# 同代號還在線上（主機還沒發現舊連線斷）：新編號接手，舊的當斷線；舊的之後再斷一次不重扣人數
	m._add_player(m.COWBOY, 4)
	m._key_of[4] = "k4"
	m._lives[4] = 1
	var n: int = m._cowboys
	m._claim_key(12, "k4")
	_ck(not m._key_of.has(4) and m._key_of.get(12) == "k4" and m._held.has("k4") and m._cowboys == n - 1,
		"同代號在線上：舊的當斷線、資料進 _held、新的接手")
	m._despawn(4)
	_ck(m._cowboys == n - 1, "舊編號再斷一次不重扣人數")
	m._reclaim(12)
	_ck(int(m._lives.get(12, -1)) == 1 and m._held.is_empty(), "同代號在線上重連：命數接回 1")
	# 新的一局清掉
	m._key_of[11] = "k2"
	m._despawn(11)
	m._new_round()
	_ck(m._held.is_empty(), "新的一局清掉斷線資料")
	_end(m)
	# 派對：分數、名字、名單位置搬到新編號
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	m.party.scores[5] = 7
	m.party.names[5] = "玩家 2"
	m.party._roster = [1, 5, -1, -2]
	m._key_of[5] = "p5"
	m._despawn(5)
	m._key_of[6] = "p5"
	m._reclaim(6)
	_ck(int(m.party.scores.get(6, -1)) == 7 and m.party.names.get(6) == "玩家 2" and m.party._roster[1] == 6
		and not m.party.scores.has(5), "派對：重連拿回分數、名字、名單位置")
	_end(m)

## 玩具積木的測試對局：一定是灰盒地圖（level_file 空字串），用完再還原
func _toy_map() -> Node:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	Main.level_file = keep
	_park(m)
	return m

## 玩具積木（續）：子彈穿塊、甩尾的上限和前方、安全屋（甩、炸、火球各一次）、真的灰盒房子拆下排、掩體方塊拆得掉、
## 新的一局還原、碎塊停下來時照這棟的顯示和碰撞、晚加入的補送路徑。每一段自己蓋一個物理世界（_isolated_match）
func _case_toy_more() -> void:
	_toy_bullet_case()
	_toy_sweep_cap_case()
	_toy_house_band_case()
	_toy_safe_case()
	_toy_restore_case()

func _toy_bullet_case() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	Main.level_file = keep
	_park(m)
	# 前牆是等級 1（木板，力量 1 穿得過），後面一塊等級 2（雙層，要力量 2）：力量 1 的子彈穿過前牆、停在後牆前面
	var wall := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.5, 1.5, 0.3), 1, Color.RED],
		[Transform3D(Basis(), Vector3(0, 0.75, 0.45)), Vector3(1.5, 1.5, 0.3), 2, Color.BLUE]])
	wall.name = "ToyWall"
	m.map.add_child(wall)
	wall.position = Vector3(0, 0, 0)
	var b := Bullet.new()
	b.weapon = Weapon.new()
	b.power = 1
	b.vel = Vector3(0, 0, 600)   # 一幀就飛過整個牆
	m.map.add_child(b)
	b.global_position = Vector3(0, 0.75, -3)
	b.set_physics_process(false)   # 自己不飛，等物理幀過了再由這裡推一次（advance）
	_defer(4, func() -> void:
		b.advance(1.0 / 120.0)
		_ck(b.is_queued_for_deletion(), "子彈穿過等級 1 的前牆後，停在等級 2 的後牆")
		_ck(absf(b._traveled - 3.28) < 0.05, "子彈停的位置在後牆前面（飛了 %.2f，要約 3.28）" % b._traveled)
		_ck(wall.is_standing(0) and wall.is_standing(1), "子彈只是穿過，積木沒被打掉（力量 1 打不掉等級 2）")
		_free_map(m))

func _toy_sweep_cap_case() -> void:
	var m := _toy_map()
	var base: Vector3 = m.map._on_ground(Vector3(0, 0, -30))
	# 大樓：400 塊（每塊一個形狀）、等級 2（挨一下只扣血，不倒）；小房子一塊等級 1，在同一個甩尾範圍裡
	var big_bricks := []
	for ix in 20:
		for iz in 20:
			big_bricks.append([Transform3D(Basis(), Vector3(-4.0 - ix * 0.2, 0.25, -2.0 + iz * 0.2)), Vector3(0.2, 0.5, 0.2), 2, Color.GREEN])
	var big := ToyBuild.make(big_bricks)
	big.name = "ToyBig"
	m.map.add_child(big)
	big.position = base
	var small := ToyBuild.make([[Transform3D(Basis(), Vector3(-10, 0.25, 0)), Vector3(0.6, 0.5, 0.6), 1, Color.RED]])
	small.name = "ToySmall"
	m.map.add_child(small)
	small.position = base
	# 甩尾的前方（+X 那側，後方半圈之外）一塊等級 1：甩尾不該拆到
	var front := ToyBuild.make([[Transform3D(Basis(), Vector3(3, 0.25, 0)), Vector3(0.6, 0.5, 0.6), 1, Color.BLUE]])
	front.name = "ToyFront"
	m.map.add_child(front)
	front.position = base
	_defer(4, func() -> void:
		_with_first(m, func() -> void:
			var b: Node3D = m.spawn_boss()
			var space := big.get_world_3d().direct_space_state
			var sph := SphereShape3D.new()
			sph.radius = b.SWEEP_RADIUS
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sph
			q.transform = Transform3D(Basis(), base)
			var skip: Array[RID] = [b.get_rid()]
			for g in m.get_tree().get_nodes_in_group(&"ground"):
				skip.append((g as CollisionObject3D).get_rid())
			q.exclude = skip
			_ck(space.intersect_shape(q, 256).size() == 256, "前提：這次甩尾的一輪查詢會被大樓吃滿 256 筆")
			b._wreck_around(base, Vector3.LEFT, b.SWEEP_RADIUS, b.SWEEP_COS)
		)
		_ck(big.has_damage() and big.hp_of(0) == 1, "大樓的塊在甩尾範圍內都挨了一下（上限滿了還要繼續查）")
		_ck(not small.is_standing(0), "同一次甩尾，後面的小房子也被拆到（沒有被大樓吃掉）")
		_ck(front.is_standing(0) and front.hp_of(0) == 1, "甩尾的前方（不在後方半圈）的塊沒被拆")
		_free_map(m))

func _toy_house_band_case() -> void:
	var m := _toy_map()
	var house: ToyBuild = null
	for t: ToyBuild in m.map._toys:
		if t.can_break and t != m.map._party_house and t.brick_count() > 300:
			house = t
			break
	_ck(house != null, "灰盒地圖要有一棟真的房子（300 塊以上）來拆下排")
	if house == null:
		_free_map(m)
		return
	var inv := house.global_transform.affine_inverse()
	var hx := 0.0
	var hz := 0.0
	for i in house.brick_count():
		var l := inv * house.center_of(i)
		hx = maxf(hx, absf(l.x))
		hz = maxf(hz, absf(l.z))
	# 拆一樓外牆的下排（離外緣 1.6 公尺內、矮於 0.5 公尺、等級 1、2；地基等級 3 不動）
	var band := func(p: Vector3) -> bool:
		var l := inv * p
		return l.y < 0.5 and (absf(l.x) > hx - 1.6 or absf(l.z) > hz - 1.6)
	house.smash(band, 2, house.global_position)
	house.smash(band, 2, house.global_position)   # 角落的柱子等級 2，第二下才倒
	_defer(4, func() -> void:
		var upper := 0
		var base_ok := true
		for i in house.brick_count():
			var l := inv * house.center_of(i)
			if house.level_of(i) == 3 and not house.is_standing(i):
				base_ok = false
			if l.y > 0.8 and (absf(l.x) > hx - 0.6 or absf(l.z) > hz - 0.6) and not house.is_standing(i):
				upper += 1
		_ck(base_ok, "拆下排的時候，地基（等級 3）一塊都不動")
		_ck(upper > 0, "拆掉一樓外牆的下排，上面懸空的牆也鬆脫（外牆上層鬆脫 %d 塊）" % upper)
		_free_map(m))

func _toy_safe_case() -> void:
	var m := _toy_map()
	var safe: ToyBuild = null
	for t: ToyBuild in m.map._toys:
		if not t.can_break:
			safe = t
			break
	_ck(safe != null, "灰盒地圖要有安全屋")
	if safe == null:
		_free_map(m)
		return
	var before := safe.brick_count()
	var n_ok := true
	for i in before:
		n_ok = n_ok and safe.level_of(i) == 3
	_ck(n_ok, "安全屋全部等級 3")
	var c := safe.global_position
	_defer(4, func() -> void:
		_with_first(m, func() -> void:
			var b: Node3D = m.spawn_boss()
			b.rotation.y = -PI * 0.5   # 背後朝 -X，安全屋在後面
			b.global_position = c + Vector3(4, BOSS_GD.LIFT, 0)
			b._strike_sweep()
			var top := 0
			for i in safe.brick_count():   # 火球打安全屋最高的一塊（地基在地下，射線從地下出發會先打到地形）
				if safe.center_of(i).y > safe.center_of(top).y:
					top = i
			_spit_at(m, b, safe, top)
			var at := c + Vector3(0, 1.5, 0)
			var p: Node3D = m._add_player(m.COWBOY, 1)
			p.global_position = m._on_ground(Vector3(c.x, 0, c.z - 8.0))
			p.viewmodel._explode(at, Viewmodel.KIND_DYNAMITE)
		)
		var all_ok := true
		for i in before:
			all_ok = all_ok and safe.is_standing(i) and safe.hp_of(i) == 3
		_ck(all_ok, "安全屋被甩尾、炸藥、火球各打一次，積木都還在（等級 3）")
		_ck(not safe.is_in_group(&"destructible"), "安全屋仍不在 destructible 群組")
		_free_map(m))

func _toy_restore_case() -> void:
	var m := _toy_map()
	m.rules = &"egg"   # 非派對模式（死鬥、蛋）也要還原
	var h: ToyBuild = null
	for k: ToyBuild in m.map._toys:
		if k.can_break and k != m.map._party_house and k.brick_count() > 300:
			h = k
			break
	var first1 := _first_brick(h, 1)
	_hit_brick(h, first1, 1)   # 鬆脫（碎塊）
	_ck(h.has_damage() and h.loose_ids().size() > 0, "前提：非派對模式也拆得到積木（碎塊 %d 個）" % h.loose_ids().size())
	m.restore_terrain()
	_ck(not h.has_damage() and h.is_standing(first1) and h.loose_ids().is_empty(), "新的一局（restore_terrain）：真的房子的積木和碎塊都回來")
	var t := ToyBuild.make(_column_bricks())
	t.name = "ToyRestore"
	m.map.add_child(t)
	t.position = m.map._on_ground(Vector3(-60, 0, 60))
	_ck(not t.is_physics_processing(), "積木進場景樹時不跑每幀處理（只有主機鬆脫後才開）")
	# 碎塊停下來時照這棟的顯示和碰撞（派對房子這時藏起來）
	_hit_brick(t, 2, 1)
	t.set_on(false)
	var ids := t.loose_ids()
	var xfs := t.loose_xforms()
	t._physics_process(4.1)
	var st := _piece_node(t, ids[0])
	_ck(st is StaticBody3D and not st.visible and st.collision_layer == 0, "藏起來的積木，碎塊停下來也藏、沒有碰撞")
	t.set_on(true)
	# 晚加入：main 的補送路徑（_spawn 對別人那條）跑得過；送來的資料在另一份積木上擺出一樣的結果
	m._spawn(2)   # 對不存在的連線送 RPC 會失敗（只印錯誤），這裡只確認路徑不炸
	var late := ToyBuild.make(_column_bricks())
	late.name = "ToyLate2"
	m.map.add_child(late)
	late.position = t.position
	late._resume(ids, xfs, PackedInt32Array())
	_ck(not late.is_standing(2) and late.is_standing(0), "晚加入的人：鬆脫的塊一樣")
	_free_map(m)
