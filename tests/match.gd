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

## 主機合成一包（main.gd 的 net_pack_row／net_pack_for／net_pack_apply）：玩家角色各一筆、時間是本人送出的，
## 給某人的那包沒有他自己；客戶端解回去走 _net_push，其他欄位照同步設定套上
func _case_net_pack() -> void:
	var m := _offline_match()
	var a: Node3D = m._add_player(m.COWBOY, 5)
	var b: Node3D = m._add_player(m.COWBOY, 6)
	_ck(m.net_pack_row(b).is_empty(), "還沒收過位置的不組進包裡")
	a.net_state = [1234.0, Vector3(3, 0, 0), Vector3(0, 1, 0)]
	a.sync_crouching = true
	b.net_state = [99.0, Vector3(0, 0, 4), Vector3.ZERO]
	var rows := {5: m.net_pack_row(a), 6: m.net_pack_row(b)}
	_ck(not rows[5].is_empty() and not rows[6].is_empty(), "收過位置的要有一筆")
	var bot: Node3D = m._add_player(m.COWBOY, -3)
	_ck(m.net_pack_row(bot).is_empty(), "主機自己的（電腦）不經過合包，Godot 的同步器會送")
	a.net_smooth = true
	b.net_smooth = true
	m.net_pack_apply(m.net_pack_for(rows, 7))
	_ck(a._snaps.size() == 1 and b._snaps.size() == 1 and b._snaps[0][2] == Vector3(0, 0, 4), "給別人的那包兩筆都要解得出來（%s／%s）" % [a._snaps, b._snaps])
	a._snaps.clear()
	b._snaps.clear()
	a.sync_crouching = false
	var pack: PackedByteArray = m.net_pack_for(rows, 6)
	m.net_pack_apply(pack)
	_ck(a._snaps.size() == 1 and a._snaps[0][0] == 1234.0 and a._snaps[0][2] == Vector3(3, 0, 0), "收到的位置要進 _snaps、時間是本人送出時的（%s）" % [a._snaps])
	_ck(a.sync_crouching, "蹲要照包裡的套上")
	_ck(b._snaps.is_empty(), "給 6 號的那包不能有他自己")
	_ck(Fighter.sync_of(a) != null and Fighter.sync_of(a).replication_config.has_property(^".:net_state"), "找得到牛仔的同步器")
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
	m.start_match()
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
	_ck(m.room._mode_btns.size() + m.room._other.item_count - 1 == m.RULES.size(), "房間要能選每一種模式")
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
	m.lobby_go(&"dev")
	_ck(m.get_node(^"UI/Root/Lobby/DinoSandboxBtn").visible, "單人頁的「其他」要看得到恐龍沙盒")
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
	m.start_match()
	m._spawn(2)
	_ck(m.players.get_child_count() == 3 and m._cowboys == 2, "要能馬上重開一局（連線模式大家都是牛仔）")
	_ck(m.players.has_node(NodePath(str(m.BOSS_ID))), "連線模式開房要自動生恐龍 boss")
	_end(m)

## 專用伺服器（測試站）：一局結束自動開下一局，人和 boss 都還在
func _case_dedicated_round() -> void:
	var m := _offline_match()
	m._dedicated = true
	m._autoplay = true   # 舊做法（--autoplay）：一局結束自動開下一局
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
	m._match_hud.update_match(b)
	_ck(m._match_hud._pilot_hint.visible and m._match_hud._pilot_hint.text.contains("Q 火球"), "操作尼諾拉時左下角有操作提示")
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
	m._match_hud.update_match(m._me())
	_ck(not m._match_hud._pilot_hint.visible, "變回牛仔：左下角操作提示收起來")
	# 操作的人斷線：電腦接手
	m.want_dino = true
	m._pick_pilot()
	m._despawn(1)
	_ck(b.pilot == 0, "操作尼諾拉的人離線：電腦接手")
	m._pick_pilot()
	_ck(b.pilot == 0, "這局已經抽過：斷線後電腦接手到局末，不再抽別人")
	_end(m)

## 隨機撤離點（WDR77 11-10）：灰盒四個候選，主機每場（派對每回合）抽兩個開；沒開的不顯示、不擋路、不算撤離；
## 抽到的記在 egg.exits，跟著蛋同步（晚進來的也拿得到）
func _case_random_exits() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""   # 主地圖（灰盒）才有四個候選；其他案例照牧場寫的
	var m := _offline_match()
	m._add_player(m.DINO, 1)
	m._add_player(m.COWBOY, 3)
	var on := func() -> Array: return range(m.map._exits.size()).filter(func(i: int) -> bool: return (m.egg.exits >> i) & 1 == 1)
	_ck(m.map._exits.size() == 4 and m.EXITS_OPEN == 2 and on.call().size() == 2 and m._exits.size() == 2,
		"灰盒四個撤離區候選，開場抽兩個（候選 %d、開 %s）" % [m.map._exits.size(), on.call()])
	var shown := range(4).filter(func(i: int) -> bool: return m.map._exit_pads[i].visible)
	_ck(shown == on.call(), "只看得到開著的撤離區（看得到 %s、開著 %s）" % [shown, on.call()])
	var off: int = range(4).filter(func(i: int) -> bool: return not i in on.call())[0]
	var pipe: Node3D = m.map._exit_pipes[off][-1]
	_ck(not pipe.visible and not pipe.can_process(), "沒開的撤離區水管藏起來、碰撞關掉")
	# 電腦牛仔拿著蛋：去開著的撤離區，不去沒開的
	var t3: Node3D = m.players.get_node(^"3")
	m.players.get_node(^"1").global_position = Vector3(0, 500, 0)
	t3.global_position = m.map._exits[off] + Vector3(0, 1, 0)
	m.egg.global_position = t3.global_position
	m.egg.carrier = 3
	var goal: Vector3 = t3._bot_goal(m)
	_ck(m._exits.has(goal), "電腦牛仔帶蛋去開著的撤離區（%s）" % goal)
	# 站在沒開的撤離區待再久也不算
	for i in int(m.EXTRACT_SECONDS / DT) + 2:
		m._egg_step(DT)
	_ck(not m._over and m.egg.extract == 0.0, "沒開的撤離區不算撤離")
	# 每場重抽：每次都是兩個，而且不會每次同一組
	var seen := {}
	for k in 30:
		m.roll_exits()
		_ck(on.call().size() == 2, "每次都開兩個（%s）" % [on.call()])
		seen[m.egg.exits] = true
	_ck(seen.size() > 1, "每場重抽，不會永遠同一組（%s）" % [seen.keys()])
	m._new_round()
	_ck(on.call().size() == 2, "開新的一局也重抽")
	# 客戶端：egg.exits 在蛋的同步清單裡（含晚進來的那一包），收到就換顯示
	var cfg: SceneReplicationConfig = m.egg.get_node(^"MultiplayerSynchronizer").replication_config
	_ck(cfg.has_property(^".:exits") and cfg.property_get_spawn(^".:exits"), "撤離區要跟著蛋同步，晚進來的也拿得到")
	m.egg.exits = 0b0101
	_ck(m.map._exit_pads[0].visible and not m.map._exit_pads[1].visible and m.map._exit_pads[2].visible and not m.map._exit_pads[3].visible,
		"收到主機抽的撤離區就換顯示")
	_end(m)
	# 派對模式：每回合開場重抽（信封也避開抽到的）
	var pm := _offline_match()
	pm._on_mode_picked(pm.RULES.keys().find(&"party"))
	pm._apply_rules()
	pm._physics_process(DT)
	pm.egg.exits = 0
	pm.party._start_round()
	var n := 0
	for i in 4:
		n += (pm.egg.exits >> i) & 1
	_ck(n == 2, "派對每回合開場重抽兩個撤離區（%d）" % n)
	_end(pm)
	Main.level_file = keep

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

## 派對模式甩尾拆積木（樹）：樹幹等級 2（甩一下扣一下、第二下整條樹幹拆斷），樹冠等級 1（甩一下就掉）；
## 樹幹拆斷，上面懸空的跟著鬆脫；不在群組裡的（安全屋）不倒；倒了碰撞沒了。積木房子見 _case_party_cubes、_case_toy
func _case_party_destruction() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _offline_match()
	var tree: ToyBuild = null
	for t: ToyBuild in m.map._toys:
		if t.is_in_group(&"tree"):
			tree = t
			break
	_ck(tree != null, "灰盒地圖要有拆得掉的樹（積木）")
	if tree == null:
		_end(m)
		Main.level_file = keep
		return
	var trunk := _first_brick(tree, 2)   # 最底下那塊樹幹（樹幹先蓋、等級 2）
	var crown := _first_brick(tree, 1)   # 樹冠（等級 1）
	_ck(trunk >= 0 and crown >= 0 and tree.is_standing(trunk) and tree.is_standing(crown), "樹有樹幹（等級 2）和樹冠（等級 1）")
	_ck(not tree.is_in_group(&"stone") and tree.collision_layer & Fighter.SOLID_LAYER == 0, "樹不加 SOLID_LAYER（關碰撞物件時尼諾拉穿過）")
	var b: Node3D = m.spawn_boss()
	_ck(b._sweep_cd_time() == b.SWEEP_CD, "其他模式甩尾冷卻不變")
	m.rules = &"party"   # ponytail: RULES 的 party 是 gameplay 加的，這裡只借 rules 這個值
	_ck(b._sweep_cd_time() == Balance.num("sweep_cd_party"), "派對模式甩尾冷卻照表（%s 秒）" % Balance.num("sweep_cd_party"))
	# 自己操作恐龍時，畫面上看得到甩尾冷卻；冷卻要同步給操作的客戶端（冷卻在主機算）
	var sync: MultiplayerSynchronizer = b.find_children("*", "MultiplayerSynchronizer")[0]
	_ck(sync.replication_config.has_property(^".:sweep_left"), "甩尾冷卻要同步出去")
	_ck(sync.replication_config.has_property(^".:fireball_left"), "火球冷卻要同步出去（駕駛的準心看得到好了沒）")
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
	var ray := PhysicsRayQueryParameters3D.create(tree.global_position + Vector3(-3, 0.6, 0), tree.global_position + Vector3(3, 0.6, 0))   # 高 0.6 公尺：樹幹最底下那塊
	_ck(space.intersect_ray(ray).get(&"collider") == tree, "倒之前樹幹擋得住")
	# 只拆後方半圈：樹在正前方（背後朝 +X）甩不到，背後朝 -X 樹在後面才拆
	b.rotation.y = PI * 0.5
	b._strike_sweep()
	_ck(tree.hp_of(trunk) == 2 and tree.is_standing(crown), "樹在正前方甩不到（只拆後方）")
	b.rotation.y = -PI * 0.5
	b._strike_sweep()
	_ck(not tree.is_standing(crown) and tree.is_standing(trunk) and tree.hp_of(trunk) == 1, "甩一下：樹冠掉了，樹幹（等級 2）還站著")
	b._strike_sweep()
	_ck(not tree.is_standing(trunk), "樹幹甩兩下拆斷")
	_ck(space.intersect_ray(ray).get(&"collider") != tree, "樹拆斷了沒有碰撞（樹幹的塊都鬆脫）")
	_ck(_piece_node(tree, trunk) != null and _piece_node(tree, trunk).collision_layer & Fighter.SOLID_LAYER == 0, "鬆脫的樹幹碎塊也不加 SOLID_LAYER")
	_ck(safe.collision_layer != 0, "不在群組裡的東西（安全屋）甩不倒")
	# 挨打、倒下的回饋（音效檔還沒放進來，前面甩倒的時候已經跑過，不能報錯）：鏡頭晃動設 0 就不震
	var old_shake: Variant = Settings.v.get(&"shake", 1.0)
	Settings.v[&"shake"] = 0.0
	_ck(ToyBuild.hit_fx(tree, tree.global_position, false) == 0.0 and ToyBuild.hit_fx(tree, tree.global_position, true) == 0.0, "鏡頭晃動設 0 時不震")
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
	boss.global_position = m.boss_on_ground(house.global_position + Vector3(0, 0, -30))   # 生怪點是亂抽的：別讓牠的身體擋在射線上
	var lone := _clear_target(house, 3.5)   # 屋頂，等級 1（前面甩倒的那塊不算）
	var b3 := three   # 地基，等級 3
	_spit_at(m, boss, house, lone)
	_ck(not house.is_standing(lone), "派對模式尼諾拉的火球打中等級 1 的方塊：扣一下、倒")
	_spit_at(m, boss, house, b3)
	_ck(house.is_standing(b3) and house.hp_of(b3) == 3, "火球打中等級 3 的方塊不扣")
	# 非派對：火球照拆（沒有模式的擋）。打完前兩發才挑：前面打下來的碎塊（還在飛）和沒倒的別塊可能擋在射線上
	m.rules = &"egg"
	m.map.set_party_house(true)
	var lone2 := _clear_target(house, 3.5, lone)
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
	# 物理規則：沒給材質照等級（1 木頭、2 磚、3 石頭）；左輪（1）穿木頭，步槍（2）穿木頭和磚，石頭都擋
	var s1 := _first_brick(house, 1)
	var s2 := _first_brick(house, 2)
	var s3 := _first_brick(house, 3)
	_ck(Bullet.pierce_left(house, 1, s1) == 0 and not Bullet.pierces(house, 1, s2), "力量 1 穿木頭（剩 0）、擋在磚")
	_ck(Bullet.pierce_left(house, 2, s1) == 1 and Bullet.pierce_left(house, 2, s2) == 0, "力量 2 穿木頭剩 1、穿磚剩 0")
	_ck(not Bullet.pierces(house, 3, s3), "等級 3（石頭）什麼都穿不過")


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

## 屋頂（高於這棟原點 min_y）還站著的等級 1 方塊裡，從前面（-Z）4 公尺打得到的第一塊：射線先打到它，沒有碎塊或別塊擋著。
## away：離這塊 2.5 公尺以上（火球半徑 2 公尺，那一發已經會把近的一起扣掉）
func _clear_target(t: ToyBuild, min_y: float, away := -1) -> int:
	var space: PhysicsDirectSpaceState3D = t.get_world_3d().direct_space_state
	for i in _standing(t, 1):
		if t.center_of(i).y - t.global_position.y <= min_y or (away >= 0 and t.center_of(i).distance_to(t.center_of(away)) <= 2.5):
			continue
		var start: Vector3 = t.center_of(i) + Vector3(0, 0, -4.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + Vector3(0, 0, 7.5)))
		if hit.get(&"collider") == t and hit.get(&"shape") == i:
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
	var houses: Array = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t != party_house and not t.is_in_group(&"tree") and not t.is_in_group(&"fence"))
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
	var nstone: int = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"stone")).size()
	var nonbreak: int = m.map._toys.filter(func(t: ToyBuild) -> bool: return not t.can_break).size()
	_ck(nonbreak == nsafe + nstone, "只有安全屋和石頭拆不掉，掩體方塊是積木、拆得掉（安全屋 %d 個、石頭 %d 個，拆不掉的 %d 個）" % [nsafe, nstone, nonbreak])
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
	# 物理規則：等級 1（木頭）的塊力量 1 就穿
	_ck(Bullet.pierces(col, 1, 1) and Bullet.pierces(col, 1, 2) and not Bullet.pierces(col, 3, 0), "等級 1 的積木（木頭）力量 1 就穿，底下等級 3（石頭）都擋")
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
	# 左上的計分欄：每列 [名次, 名字, 總分, (+10)]（色塊不是字）
	var bar := func() -> Array:
		return hud.scorebar.get_children().map(func(r: Node) -> Array:
			return r.get_child(0).get_children().filter(func(c: Node) -> bool: return c is Label).map(func(l: Label) -> String: return l.text))
	var rows: Array = bar.call()
	_ck(hud.scorebar.visible and rows.map(func(r: Array) -> String: return r[2]) == ["12", "7", "3", "0"], "計分欄照總分排（現在：%s）" % [rows])
	_ck(rows.all(func(r: Array) -> bool: return r.size() == 3), "沒人拿蛋：沒有「+」")
	_ck(rows[0][1].contains("恐龍") and not rows[1][1].contains("恐龍"), "當恐龍的那列有恐龍記號（%s）" % [rows])
	var mine_row: Label = hud.scorebar.get_child(2).get_child(0).get_child(2)
	_ck(mine_row.text.begins_with("阿明") and mine_row.get_theme_color(&"font_color") == hud.GOLD, "自己那列是金色")
	m.egg.carrier = 3
	hud._process(0.0)
	rows = bar.call()
	var plus := "+%d" % (Party.SCORE_EXTRACT + Party.SCORE_SURVIVE)
	_ck(rows[1][1] == "大雄" and rows[1].size() == 4 and rows[1][3] == plus and rows.filter(func(r: Array) -> bool: return r.size() == 4).size() == 1,
		"只有拿蛋的那列有 %s（現在：%s）" % [plus, rows])
	m._match_hud.update_text(null)
	_ck(m.hud.text.contains("被 大雄 拿走了"), "左下角寫拿蛋的人的名字（%s）" % m.hud.text)
	p.scores[4] = 20
	p.changed.emit()
	rows = bar.call()
	_ck(rows.map(func(r: Array) -> String: return r[2]) == ["20", "12", "7", "3"], "分數變了計分欄跟著重排（現在：%s）" % [rows])
	m.egg.carrier = 0
	p.scores[4] = 0
	p.changed.emit()
	# 選重生點：自己死了（場上沒有自己）才有
	m.spawn_points.assign([Vector3(0, 0, -50), Vector3(60, 0, 0), Vector3(0, 0, 40)])
	var mine: Node = m._me()
	if mine:
		mine.get_parent().remove_child(mine)
		mine.free()
	hud._process(0.0)
	_ck(hud.hint.text.contains("1～3") and hud.minimap.visible and hud.picked == -1, "死了：顯示俯視圖、提示按 1～3 或點圖（現在：%s）" % hud.hint.text)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_2
	hud._unhandled_input(key)
	key.physical_keycode = KEY_9   # 超過點數的鍵不理
	hud._unhandled_input(key)
	_ck(p.asked == [1], "按 2 要呼叫 request_respawn_at(1)（現在：%s）" % [p.asked])
	p.spawn_red = 0b100   # 第 3 個附近有敵人
	key.physical_keycode = KEY_3
	hud._unhandled_input(key)
	hud.minimap.chosen.emit(2)
	_ck(p.asked == [1] and hud.picked == 1, "紅的點按鍵、點圖都選不了")
	hud.minimap.chosen.emit(0)   # 點圖選綠點
	_ck(p.asked == [1, 0] and hud.picked == 0, "點圖上的綠點：選第 1 個")
	var mm := hud.minimap
	_ck(mm.point_at(Minimap.to_map(m.spawn_points[0], m.ARENA, Minimap.SIZE) + Vector2(3, 3)) == 0 and mm.point_at(Vector2(-50, -50)) == -1, "點到圖示附近算點到那個重生點")
	p.spawn_red = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 回合結算：中間顯示怎麼結束的，幾秒後自動消失
	p.phase = &"result"
	p.last_result = "時間到，恐龍守住蛋"
	p.changed.emit()
	hud._process(0.0)
	_ck(hud.popup.visible and hud.popup_title.text == p.last_result, "結算要顯示怎麼結束的")
	_ck(not hud.scorebar.visible, "結算時計分欄收起來")
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
	# 跟電腦打（選單流程 M4）：離線的房間、只有自己（房主）；選派對按開始，電腦補到四個；打完回房間、離開回單人頁
	var solo: Node = load("res://main.tscn").instantiate()
	root.add_child(solo)
	_ck(solo.has_node(^"UI/Root/Lobby/VsBotsBtn"), "單人頁要有跟電腦打")
	# 大廳的東西都要登記在某一頁（LOBBY_PAGES），沒登記的換頁時會被藏掉、玩家看不到
	var listed := []
	for pg: Array in solo.LOBBY_PAGES.values():
		listed.append_array(pg)
	var unlisted: Array = solo.lobby.get_children().map(func(c: Node) -> String: return String(c.name)).filter(func(n: String) -> bool: return not n in listed)
	_ck(unlisted.is_empty(), "大廳的按鈕都要登記在 LOBBY_PAGES（漏了 %s）" % [unlisted])
	solo.lobby_go(&"practice")
	_ck(solo.get_node(^"UI/Root/Lobby/VsBotsBtn").visible, "單人頁看得到跟電腦打")
	solo.get_node(^"UI/Root/Lobby/VsBotsBtn").pressed.emit()
	_ck(solo._offline and solo.lobby_page == &"room" and solo.room.order == [1] and solo.room.is_host() and solo.room._start.visible
		and not solo.room._addr.visible and solo.players.get_child_count() == 0, "跟電腦打：先進房間，只有自己、自己是房主")
	solo.room.ask(&"mode", &"party")
	solo.room.ask(&"start")
	solo._physics_process(DT)
	_ck(solo.rules == &"party" and solo.party != null and solo.party.phase == &"prep"
		and solo.party.scores.size() == 4, "按開始：派對直接開第一回合，電腦補到四人")
	solo.room.ask(&"back")
	_ck(solo.lobby_page == &"room" and solo.players.get_child_count() == 0, "跟電腦打也能回房間")
	solo.room.ask(&"mode", &"normal")
	solo.want_dino = true
	solo.room.ask(&"start")
	solo._physics_process(DT)
	_ck(solo.party != null and solo.party.fixed and solo.party._roster.size() == 4, "一般模式也能打（電腦補滿）")
	solo._to_lobby("")
	_ck(solo.lobby_page == &"practice", "離開房間回單人頁")
	_end(solo)
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	_ck(p != null and m.get_node_or_null(^"Party") == p, "派對模式 main 底下要有 $Party")
	_ck(p.use_safe, "派對模式預設用保險箱")
	p.use_safe = false   # 這段驗舊的藏蛋流程（開關關掉還能玩）；保險箱見 _case_safe
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

## 保險箱（safe.gd、safe_panel.gd，規劃 docs/企劃/2026-11-12-保險箱與號碼牌.md 製作順序第 1 步）
func _case_safe() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)   # 開場：主機（1）當恐龍
	_ck(m.safe_spots.is_empty() and p.egg_placed and s.locked() and Vector2(s.global_position.x - m.dino_spawn.x, s.global_position.z - m.dino_spawn.z).length() < BOSS_GD.BODY_RADIUS + 3.0,
		"地圖沒有保險箱點（牧場）：箱子開場放在恐龍出生點前面（%s）" % s.global_position)
	var b: Node3D = m._boss()
	b.global_position = m._on_ground(Vector3(0, BOSS_GD.LIFT, 40))
	p._hide_egg_at(p._dino_pos())   # 牧場沒有保險箱點：開場已經放在恐龍前面；挪到 (0, 40) 照原本的位置測
	_ck(p.egg_placed and s.locked() and m.egg.global_position.distance_to(s.global_position) < 0.1
		and Vector2(s.global_position.x, s.global_position.z - 40).length() < BOSS_GD.BODY_RADIUS + 3.0, "保險箱放在恐龍前面，蛋鎖在裡面")
	var code: int = s._code
	_ck(code >= 0 and code <= 99, "主機抽了兩位數密碼（%d）" % code)
	# 密碼不在送出去的東西裡：party 那包只有公開的欄位；同步器只送位置
	var st: Dictionary = p.state()
	_ck(st.safe.size() == 4 and not str(st).contains("code"), "party 那包沒有密碼（%s）" % [st.safe.keys()])
	var props: Array = (s.get_node(^"MultiplayerSynchronizer") as MultiplayerSynchronizer).replication_config.get_properties()
	_ck(props.size() == 2 and String(props[0]).ends_with(":position") and String(props[1]).ends_with(":rotation"), "保險箱的同步器只送位置和角度（%s）" % [props])
	var bots: Array = [-1, -2, -3].map(func(id: int) -> Node3D: return m.players.get_node(NodePath(str(id))))
	for c: Node3D in bots:
		c.global_position = Vector3(0, 800, 0)
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"play" and m.egg.global_position.distance_to(s.global_position) < 0.1, "遊戲開始：蛋還在箱子裡")
	var near := s.global_position + Vector3(1.6, 0, 0)
	bots[0].global_position = near
	bots[1].global_position = near + Vector3(0, 0, 0.8)
	var wrong := (code + 37) % 100
	_ck(not s.try_code(1, wrong), "恐龍不能試密碼")
	_ck(not s.try_code(-3, wrong), "離太遠不能試")
	_ck(s.try_code(-1, wrong) and s.busy == -1, "牛仔站旁邊可以試")
	_ck(not s.try_code(-2, code), "一次一個人：別人在試，請求被拒")
	for i in int(Safe.TRY_SECONDS / DT * 0.5):
		m._physics_process(DT)
	_ck(s.busy == -1 and s.tried[wrong] == 0, "試到一半還沒公布")
	for i in int(Safe.TRY_SECONDS / DT * 0.5) + 2:
		m._physics_process(DT)
	_ck(s.busy == 0 and s.tried[wrong] == 1 and s.locked(), "1 秒後公布：猜錯記進表、箱子沒開")
	for i in int(m.pickup_seconds() / DT) + 10:
		m._physics_process(DT)
	_ck(m.egg.carrier == 0, "箱子沒開，站在旁邊也撿不到蛋")
	# 面板：選了十位數，跟它試過的個位數變灰；反過來也一樣
	var panel: SafePanel = m._safe_panel
	panel.tens = wrong / 10
	panel.ones = -1
	_ck(panel.is_gray(1, wrong % 10) and not panel.is_gray(1, (wrong + 1) % 10) and not panel.is_gray(0, wrong / 10), "選了十位數，試過的個位數變灰")
	panel.tens = -1
	panel.ones = wrong % 10
	_ck(panel.is_gray(0, wrong / 10) and not panel.is_gray(0, (wrong / 10 + 1) % 10), "選了個位數，試過的十位數變灰")
	# 試到一半走開：作廢，不記
	_ck(s.try_code(-1, code), "再試一次")
	bots[0].global_position = near + Vector3(20, 0, 0)
	m._physics_process(DT)
	_ck(s.busy == 0 and s.tried[code] == 0 and s.locked(), "試到一半走開：這次作廢，沒記進表")
	# 試到一半死掉：一樣作廢
	_ck(s.try_code(-2, code), "另一個人試")
	var c2: Node3D = bots[1]
	c2.take_damage(9999, b)
	m.players.remove_child(c2)
	c2.free()
	m._physics_process(DT)
	_ck(s.busy == 0 and s.tried[code] == 0 and s.locked(), "試到一半死掉：作廢")
	# 猜對：開箱、蛋放到箱頂，照舊撿
	bots[0].global_position = near
	_ck(s.try_code(-1, code), "猜對的那一次")
	for i in int(Safe.TRY_SECONDS / DT) + 2:
		m._physics_process(DT)
	_ck(s.open and not s.locked() and s.tried[code] == 1 and p.state().safe.open, "猜對：箱子開了（公開狀態）")
	_ck(not s.try_code(-1, wrong), "開了就不收試開")
	for i in int(m.pickup_seconds() / DT) + 10:
		m._physics_process(DT)
	_ck(m.egg.carrier == -1, "開箱後蛋撿得起來")
	# 下一回合重抽、清表
	p._end_round(true, "test")
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"prep" and s.on and not s.open and s.busy == 0 and Array(s.tried).count(1) == 0, "新回合：箱子關上、試過的表清掉")
	_end(m)
	# 其他模式沒有保險箱
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"egg"))
	m._apply_rules()
	_ck(not m.safe.on and not m.safe.visible and m.safe.collision_layer == 0 and not m.safe.locked(), "搶蛋模式沒有保險箱")
	_end(m)

## 信封和號碼牌（envelope.gd、party.gd，規劃 docs/企劃/2026-11-12-保險箱與號碼牌.md 製作順序第 2 步）
func _case_envelope() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)   # 開場：主機（1）當恐龍，電腦 -1～-3 當牛仔
	_ck(p.envelopes.size() == 2 and p.env_open == [false, false], "每回合兩個信封，還沒人看過")
	var e0: Vector3 = p.env_pos[0]
	var e1: Vector3 = p.env_pos[1]
	_ck(Vector2(e0.x - e1.x, e0.z - e1.z).length() > 20.0 and m._exits.all(func(x: Vector3) -> bool:
		return Vector2(e0.x - x.x, e0.z - x.z).length() > m.EXIT_RADIUS and Vector2(e1.x - x.x, e1.z - x.z).length() > m.EXIT_RADIUS),
		"兩個信封分開、不在撤離圈（%s %s）" % [e0, e1])
	# 方位條：信封、保險箱（圖示）；畫面上的標記：撤離、蛋。箱子開了信封、箱子拿掉，畫面上標蛋
	var cm := func(label: String) -> int:
		return m._match_hud.compass_marks(Vector3.ZERO).filter(func(k: Dictionary) -> bool: return String(k.label).begins_with(label) and k.has("icon")).size()
	var wm := func(label: String) -> int:
		return m._match_hud.world_marks().filter(func(k: Dictionary) -> bool: return k.label == label).size()
	p._process(0.0)
	var dino: PhysicsBody3D = m.get_tree().get_first_node_in_group(&"dino")
	_ck(dino != null and p.envelopes.all(func(e: Envelope) -> bool: return dino.get_collision_exceptions().has(e)), "尼諾拉穿過信封（對兩個信封都有碰撞例外）")
	p._process(0.0)
	_ck(dino.get_collision_exceptions().filter(func(b: PhysicsBody3D) -> bool: return b is Envelope).size() == p.envelopes.size(), "每幀跑也不會重複加例外")
	_ck(cm.call(Envelope.NAMES[0]) == 1 and cm.call(Envelope.NAMES[1]) == 1 and wm.call("撤離") == 2 and cm.call("撤離") == 0, "方位條：兩個信封；撤離在畫面上的標記（恐龍一直知道）")
	_ck(cm.call("保險箱") == 1 and wm.call("蛋") == 0, "恐龍看得到保險箱，蛋鎖著不標")
	s.open = true
	p._process(0.0)
	_ck(cm.call(Envelope.NAMES[0]) == 0 and cm.call(Envelope.NAMES[1]) == 0 and cm.call("保險箱") == 0
		and wm.call("蛋") == 1 and wm.call("撤離") == 2, "箱子開了：信封、箱子拿掉，畫面上標蛋，撤離還在")
	s.open = false
	var bots: Array = [-1, -2, -3].map(func(id: int) -> Node3D: return m.players.get_node(NodePath(str(id))))
	_ck(not p.read(-1, 0), "準備階段不能看牌")
	p.time_left = 0.0
	m._physics_process(DT)
	var code: int = s._code
	bots[0].global_position = e0 + Vector3(1, 0.5, 0)
	_ck(not p.read(1, 0), "恐龍不能看牌")
	_ck(not p.read(-2, 0), "離太遠不能看")
	_ck(p.read(-1, 0) and p.env_open == [true, false], "牛仔站旁邊看十位數的牌，信封變成開過（公開）")
	_ck(p._known[-1] == [code / 10, -1], "主機記下他看過十位數 %d" % (code / 10))
	_ck(p.my_digits == [-1, -1] and not p._known.has(1), "數字只給看的人：主機這台（恐龍）沒收到")
	var st: Dictionary = p.state()
	_ck(st.env_open == [true, false] and not st.has("my_digits") and not st.has("_known"), "party 那包有開過沒，沒有誰知道什麼")
	p._process(0.0)   # 外觀每幀照公開狀態套
	_ck(not p.envelopes[0].opened and p.envelopes[0].global_position == e0, "主機這台是恐龍：開過的信封看起來還是沒開（0.8.16 第 4.1 節），擺在抽到的位置")
	_ck(p.read(-1, 0) and p._known[-1] == [code / 10, -1], "牌沒被拿走，可以再看")
	# 下一回合：主機變回牛仔，看過的、開過的都清掉（箱子開著進下一回合，方位條的信封要回來）
	s.open = true
	p._end_round(true, "test")
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.dino_id == -1 and p._known.is_empty() and p.env_open == [false, false] and p.my_digits == [-1, -1], "新回合：看過的牌、開過的信封清掉")
	_ck(cm.call(Envelope.NAMES[0]) == 1 and cm.call(Envelope.NAMES[1]) == 1, "新回合：方位條的信封回來")
	p.time_left = 0.0
	m._physics_process(DT)
	code = s._code
	var me: Cowboy = m.players.get_node(^"1")
	me.global_position = p.env_pos[1] + Vector3(0, 0.5, 1)
	p.envelopes[1].interact(me)   # 按 F 那條路
	_ck(p.my_digits == [-1, code % 10] and p.env_open == [false, true], "主機自己看個位數：收到 %d" % (code % 10))
	p._process(0.0)
	_ck(p.envelopes[1].opened and not p.envelopes[0].opened, "獵人那台：開過的信封換樣子")
	_ck(cm.call(Envelope.NAMES[1]) == 0 and cm.call(Envelope.NAMES[0]) == 1, "看過的信封從自己的方位條拿掉")
	_ck(p.envelopes[1].prompt.contains(str(code % 10)), "看過的信封提示寫數字（%s）" % p.envelopes[1].prompt)
	m._match_hud.update_text(me)
	_ck(m.hud.text.contains("密碼 ? %d" % (code % 10)), "左下角小抄（%s）" % m.hud.text)
	var panel: SafePanel = m._safe_panel
	panel.open_panel()
	_ck(panel.tens == -1 and panel.ones == code % 10, "面板打開：看過的那一位先選好")
	panel.hide()
	# 死了重生還記得
	p.lives[1] = 3
	me.take_damage(9999)
	m.players.remove_child(me)
	me.free()
	m._physics_process(DT)
	p._waiting[1][0] = 0.0
	m._physics_process(DT)
	_ck(m.players.has_node(^"1") and p.my_digits == [-1, code % 10] and p._known[1] == [-1, code % 10], "死了重生還記得看過的牌")
	# 斷線重連：換編號後補送
	p.rekey(1, 7)
	_ck(p._known.has(7) and not p._known.has(1), "重連：看過的牌搬到新編號")
	p.my_digits = [-1, -1]
	p.rekey(7, 1)
	_ck(p.my_digits == [-1, code % 10], "重連後補送給本人")
	# 計分欄的色塊照 scores 的順序：重連、頂替都不能換位置
	var before := p.scores.keys()
	p.rekey(1, 7)
	_ck(p.scores.keys() == before.map(func(id: int) -> int: return 7 if id == 1 else id), "重連後 scores 順序不變（%s → %s）" % [before, p.scores.keys()])
	before = p.scores.keys()
	p._refresh_roster()   # 主機（1）又連著、不在名單上 → 頂掉一個還沒當過恐龍的電腦
	var slot := p._roster.find(1)
	_ck(slot >= 0 and before[slot] < 0 and p.scores.keys() == p._roster, "頂替的人接手電腦那格的顏色（%s → %s）" % [before, p.scores.keys()])
	_end(m)

## 保險箱四選一（規劃 docs/企劃/2026-11-15-畫面與保險箱位置.md 第 3 步）：灰盒有四個保險箱點，每回合主機抽一個放箱子，恐龍不用放
func _case_safe_spots() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""   # 灰盒才有保險箱點
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	var spots: Array[Vector3] = m.safe_spots
	var exits: Array = ArenaMap.exit_spots(true)
	_ck(spots.size() == 4 and spots.all(func(q: Vector3) -> bool:
		return exits.all(func(e: Vector2) -> bool: return Vector2(q.x, q.z).distance_to(e) > m.EXIT_RADIUS)), "灰盒有四個保險箱點、都不在撤離圈（%s）" % [spots])
	var at := func() -> int:   # 箱子在第幾個點（水平 1 公尺內），不在就 -1
		for i in spots.size():
			if Vector2(s.global_position.x - spots[i].x, s.global_position.z - spots[i].z).length() < 1.0:
				return i
		return -1
	m._physics_process(DT)
	_ck(p.phase == &"prep" and p.egg_placed and s.locked() and at.call() >= 0 and m.egg.global_position.distance_to(s.global_position) < 0.1,
		"回合開始不用按 F：箱子在保險箱點上、蛋鎖在裡面（%s）" % s.global_position)
	var before := s.global_position
	p.place_egg()
	_ck(s.global_position == before, "保險箱模式按 F 不會搬箱子")
	var seen := {}
	var far := 0
	for i in 20:
		p._start_round()
		seen[at.call()] = true
		far += int(p.env_pos.all(func(e: Vector3) -> bool: return Vector2(e.x - s.global_position.x, e.z - s.global_position.z).length() >= Party.ENV_FROM_SAFE))
	_ck(not seen.has(-1) and seen.size() >= 2, "連開 20 回合：每次都在點上、抽到兩個以上的點（%s）" % [seen.keys()])
	_ck(far >= 15, "信封離箱子 %d 公尺以上（20 回合有 %d 回合沒放寬）" % [Party.ENV_FROM_SAFE, far])
	p.round_index = 1   # 第二個人（電腦 -1）當恐龍
	p._start_round()
	_ck(p.dino_id < 0 and at.call() >= 0 and Vector2(s.global_position.x, s.global_position.z).length() > 20.0, "電腦當恐龍：箱子也在保險箱點，不在中央")
	_end(m)
	Main.level_file = keep

## 電腦牛仔開保險箱（cowboy.gd 的 _bot_safe_act、bot_brain.gd）：看牌、去箱子、試對得上的組合、開了照舊撿蛋。
## 看牌要站一下、試密碼放慢（規劃「試密碼放慢」）。恐龍（主機 1）不動。bot 不在物理幀裡，手動叫 _bot_step，走路用瞬移代替
func _case_bot_safe() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)   # 牧場沒有保險箱點：箱子開場放在恐龍前面（中央）
	p.time_left = 0.0
	m._physics_process(DT)
	var code: int = s._code
	var b: Cowboy = m.players.get_node(^"-1")
	var b2: Cowboy = m.players.get_node(^"-2")
	m.players.get_node(^"-3").global_position = Vector3(0, 800, 0)
	var d: Node3D = m.players.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"dino"))[0]   # 不用 get_first_node_in_group：前面案例的對局還沒真的刪掉
	d.global_position = s.global_position + Vector3(0, 0, -200)   # 恐龍放遠：不怕
	b.bot_fire_range = 0.0   # 只看開箱，不打恐龍
	b.global_position = s.global_position + Vector3(0, 0, 50)
	var run := func(sec: float, until: Callable) -> float:
		var f := 0
		while not until.call() and f < int(sec / DT):
			b._bot_step(DT)
			m._physics_process(DT)
			f += 1
		return f * DT
	var goal: Vector3 = b._bot_goal(m)
	var ci: int = p.env_pos.find(goal)
	_ck(p.phase == &"play" and ci >= 0 and b.bot_action == "看牌%d" % ci, "箱子沒開：bot 先去看牌（%s）" % b.bot_action)
	b.global_position = p.env_pos[ci] + Vector3(1, 0.5, 0)
	var k: Array = []
	var t: float = run.call(BotBrain.READ_MAX + 0.2, func() -> bool: return int(p._known.get(-1, [-1, -1])[ci]) >= 0)
	k = p._known.get(-1, [-1, -1])
	_ck(k[ci] == p.digit(ci) and k[1 - ci] == -1 and t >= BotBrain.READ_MIN - 0.05, "走到牌前站一下才看到（%.1f 秒，%s）" % [t, k])
	var near := s.global_position + Vector3(1.6, 0.5, 0)
	b.global_position = near
	run.call(1.0, func() -> bool: return b.bot_action == "試密碼")
	_ck(b.bot_action == "試密碼" and b._bot_goal(m) == s.global_position and b._bot_should_hold(m), "看過一張：去箱子旁邊站著試（%s）" % b.bot_action)
	m.debug_hud = true   # F3：頭上一行字、右上角一行
	run.call(0.1, func() -> bool: return false)
	_ck(b._bot_label != null and b._bot_label.visible and b._bot_label.text.contains("試密碼") and m._match_hud._bots_debug().contains("試密碼"),
		"F3 開著：電腦頭上和右上角寫它在做什麼（%s）" % (b._bot_label.text if b._bot_label else "沒有字"))
	m.debug_hud = false
	# 別人在試：bot 在旁邊等，不送
	b2.global_position = near + Vector3(0, 0, 0.8)
	var other := (code + 50) % 100
	_ck(s.try_code(-2, other), "另一個人先試")
	run.call(Safe.TRY_SECONDS * 0.5, func() -> bool: return false)
	_ck(s.busy == -2 and Array(s.tried).count(1) == 0, "箱子忙的時候 bot 不送試開")
	b2.global_position = near + Vector3(0, 0, 80)
	# 在箱子旁邊試密碼時不開槍，恐龍就在面前也一樣（恐龍倒地：不怕，不會跑去躲）；挨打才還手
	d.global_position = near + Vector3(3, 0, 0)
	d.down_left = 999.0
	b.bot_fire_range = 40.0
	b.viewmodel._fire_cooldown = 0.0   # 這裡只跑 _bot_step，viewmodel 的冷卻不會自己倒數：先清掉，扣扳機就真的會射
	var mag: int = b.viewmodel.weapon.mag
	run.call(1.0, func() -> bool: return false)
	_ck(b._bot_threat(m) == d and b.viewmodel.weapon.mag == mag, "在箱子旁邊試密碼：恐龍在面前也不開槍（瞄 %s、彈匣 %d -> %d）" % [b._bot_threat(m), mag, b.viewmodel.weapon.mag])
	b.take_damage(1)
	run.call(Cowboy.BOT_ALERT, func() -> bool: return b.viewmodel.weapon.mag < mag)
	_ck(b.viewmodel.weapon.mag < mag, "挨打就還手（彈匣 %d -> %d）" % [mag, b.viewmodel.weapon.mag])
	b.bot_fire_range = 0.0
	d.global_position = near + Vector3(0, 0, -200)
	d.down_left = 0.0
	# 試密碼放慢：到箱子先等、每次試完再等；看過一張最多 10 次，最慢約 2 + 10 × 4 秒
	var tried: Array = []
	var stamps: Array = []
	var f := 0
	while not s.open and f < int(45.0 / DT):
		b._bot_step(DT)
		m._physics_process(DT)
		f += 1
		var n := Array(s.tried).count(1)
		if n > tried.size():
			tried.append(n)
			stamps.append(f * DT)
	var tries := Array(s.tried).count(1)
	var gap: float = (stamps[-1] - stamps[0]) / (stamps.size() - 1) if stamps.size() > 1 else 3.0
	_ck(s.open and tries <= 11, "bot 試對得上的組合開箱（%.1f 秒、試了 %d 次）" % [f * DT, tries])
	_ck(gap >= Safe.TRY_SECONDS + BotBrain.GAP_MIN - 0.05, "每次試開隔 2.5 秒以上（平均 %.1f 秒）" % gap)
	var off := 0
	for n in 100:
		if s.tried[n] == 1 and n != other and (n / 10 if ci == 0 else n % 10) != k[ci]:
			off += 1
	_ck(off == 0, "只試跟看過的那一位對得上的")
	run.call(m.pickup_seconds() + 1.0, func() -> bool: return m.egg.carrier == -1)
	_ck(m.egg.carrier == -1, "開了照舊撿蛋（%s）" % b.bot_action)
	_end(m)

## 電腦尼諾拉守箱（boss.gd 的 _act_guard，docs/企劃/2026-11-16-未完成事項.md 第 1 項）：看不到人時巡箱子和沒開的信封；
## 開信封、猜錯、開箱叫牠過去；開箱後往蛋走；真人駕駛不守。boss 不在物理幀裡，手動叫 think
func _case_boss_guard() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)   # 遊戲開始
	var b: Node3D = m._boss()
	var c: Cowboy = m.players.get_node(^"-1")
	for id in [-1, -2, -3]:
		m.players.get_node(NodePath(str(id))).global_position = Vector3(0, 800, 0)   # 看不到、聽不到
	b.pilot = 0
	var flat := func(a: Vector3, z: Vector3) -> float: return Vector2(a.x - z.x, a.z - z.z).length()
	var near_guard := func() -> float:   # 離箱子、沒開的信封最近多遠
		var d: float = flat.call(b.global_position, s.global_position)
		for i in 2:
			if not p.env_open[i]:
				d = minf(d, flat.call(b.global_position, p.env_pos[i]))
		return d
	var best := Vector3.ZERO   # 起點：場上離三個點都遠的地方
	var far := 0.0
	for k in 16:
		var at: Vector3 = b._clamp_arena(s.global_position + Vector3(cos(k * TAU / 16), 0, sin(k * TAU / 16)) * 60.0)
		b.global_position = m._on_ground(Vector3(at.x, BOSS_GD.LIFT, at.z))
		if near_guard.call() > far:
			far = near_guard.call()
			best = b.global_position
	b.global_position = best
	_ck(b._guarding() and far > 25.0, "派對有保險箱、電腦操作：守箱（起點離最近的守點 %.0f 公尺）" % far)
	# 測試在第一格跑，物理還沒開始算、位置不會動：看目的地和速度
	for i in int(1.0 / DT):
		b.think(DT)
	var wt: Vector3 = b._wander_to
	var wt_ok: bool = wt != Vector3.INF and (flat.call(wt, s.global_position) < 25.0 or [0, 1].any(func(i: int) -> bool: return flat.call(wt, p.env_pos[i]) < 25.0))
	_ck(wt_ok and Vector2(b.velocity.x, b.velocity.z).length() > 1.0, "看不到人：往箱子或沒開的信封走（目的地 %s、速度 %.1f）" % [wt, Vector2(b.velocity.x, b.velocity.z).length()])
	b.global_position = best
	# 信封被開：尼諾拉不知道（0.8.16 第 4.1 節），不叫牠、守點照舊有兩個信封
	c.global_position = p.env_pos[0] + Vector3(0.5, 0.5, 0)
	_ck(p.read(-1, 0), "牛仔看牌")
	_ck(b._noise_left <= 0.0 and b._guard_points().size() == 3, "信封被開：不叫恐龍，守點還是箱子＋兩個信封")
	# 猜錯：叫牠去箱子
	b._noise_left = 0.0
	c.global_position = s.global_position + Vector3(1.6, 0.5, 0)
	var code: int = s._code
	_ck(s.try_code(-1, (code + 37) % 100), "牛仔試錯的組合")
	for i in int(Safe.TRY_SECONDS / DT) + 2:
		m._physics_process(DT)
	_ck(s.locked() and b._noise_left > 0.0 and flat.call(b._noise, s.global_position) < BOSS_GD.NOISE_FUZZ_MAX + 5.0, "猜錯：恐龍往箱子去（偏 %.0f 公尺）" % flat.call(b._noise, s.global_position))
	_ck(b._guard_points() == [s.global_position] and not b._near_guard(p.env_pos[0], BOSS_GD.GUARD_HEAR), "有人試過密碼：守點只剩箱子，信封那邊的聲音不理")
	# 開箱：往蛋走
	b._noise_left = 0.0
	_ck(s.try_code(-1, code), "牛仔試對的組合")
	for i in int(Safe.TRY_SECONDS / DT) + 2:
		m._physics_process(DT)
	_ck(s.open and b._noise_left > 0.0, "開箱：叫恐龍過去")
	c.global_position = Vector3(0, 800, 0)
	b._noise_left = 0.0
	b._stuck_t = 0.0   # 物理沒跑、位置不動：前面幾段累積的「卡住」計時清掉，不然這一秒裡會觸發脫困往旁邊退
	b._stuck_at = Vector3.INF
	b._unstick_left = 0.0
	# 這一段只看牠決定往哪走，不看撞牆：think 裡的 move_and_slide 真的會撞，起點（照信封亂抽）偶爾貼著房子或石頭，
	# 貼牆時 _go 偏 0.9 弧度滑開，速度方向就不朝蛋（以前時好時壞的原因）。碰撞先關掉，看完再開
	var mask: int = b.collision_mask
	b.collision_mask = 0
	for i in int(1.0 / DT):
		b.think(DT)
	b.collision_mask = mask
	var to_egg: Vector3 = (m.egg.global_position - b.global_position) * Vector3(1, 0, 1)
	var goal_ok: bool = b._path_goal.distance_to(m.egg.global_position) < 2.0 if NavigationServer3D.map_get_iteration_id(b.get_world_3d().navigation_map) > 0 \
		else Vector3(b.velocity.x, 0, b.velocity.z).normalized().dot(to_egg.normalized()) > 0.7
	_ck(goal_ok and b.running, "開箱後跑去蛋那裡（路的終點 %s、蛋 %s）" % [b._path_goal, m.egg.global_position])
	# 真人駕駛：不守
	b.pilot = 1
	_ck(not b._guarding(), "真人駕駛不守箱")
	_end(m)

## 選重生點（0.8.16 第 6 節）：10 公尺內有敵人（其他活著的獵人、尼諾拉從身體邊緣算）是紅的；重生那一刻再檢查，
## 變紅換最近的綠點、全紅放離敵人最遠的；電腦挑綠點裡離尼諾拉最遠的；圖上的座標
func _case_respawn_pick() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)
	var a := Vector3(-60, 0, 0)
	var bb := Vector3(0, 0, 0)
	var c := Vector3(60, 0, 0)
	m.spawn_points.assign([a, bb, c])
	var cows: Array = [-1, -2, -3].map(func(id: int) -> Node3D: return m.players.get_node(NodePath(str(id))))
	for k: Node3D in cows:
		k.global_position = Vector3(0, 0, 5000)
	var boss: Node3D = m._boss()
	boss.global_position = Vector3(5000, 0, 0)
	_ck(p.red_mask() == 0, "附近沒人：全部綠的")
	cows[0].global_position = a + Vector3(9, 0, 0)
	_ck(p.red_mask() == 0b001, "獵人站在重生點 9 公尺：紅")
	cows[0].global_position = a + Vector3(11, 0, 0)
	_ck(p.red_mask() == 0, "11 公尺：綠")
	boss.global_position = bb + Vector3(0, 0, BOSS_GD.BODY_RADIUS + 9.0)
	_ck(p.red_mask() == 0b010, "尼諾拉身體邊緣離 9 公尺：紅")
	p._red_left = 0.0
	p._respawn_step(DT)
	_ck(p.spawn_red == 0b010 and p.state().spawn_red == 0b010, "主機每半秒算一次、放進同步的那包")
	_ck(p.respawn_index(1, false) == 0, "選的點變紅：換離它最近的綠點（左邊那個比右邊近：%d）" % p.respawn_index(1, false))
	_ck(p.respawn_index(2, false) == 2, "選的點還是綠的：用它")
	_ck(p.respawn_index(-1, false) in [0, 2], "沒選：隨機一個綠點")
	boss.global_position = c + Vector3(0, 0, BOSS_GD.BODY_RADIUS + 9.0)
	_ck(p.respawn_index(-1, true) == 0, "電腦：尼諾拉在右邊，挑左邊")
	cows[1].global_position = bb + Vector3(5, 0, 0)
	cows[2].global_position = a + Vector3(2, 0, 0)
	_ck(p.red_mask() == 0b111 and p.respawn_index(0, false) == 2, "全紅：放離所有敵人最遠的（右邊那個，尼諾拉 9 公尺；左 2、中 5）")
	# 死了：選的點清掉（每次死都重選）
	p._pick[-1] = 2
	cows[0].take_damage(9999)
	_ck(not p._pick.has(-1), "死了清掉上次選的點")
	# 圖上的座標：四個角、中央
	var half: float = m.ARENA * 0.5
	_ck(Minimap.to_map(Vector3.ZERO, m.ARENA, 400.0) == Vector2(200, 200) and Minimap.to_map(Vector3(-half, 0, -half), m.ARENA, 400.0) == Vector2.ZERO
		and Minimap.to_map(Vector3(half, 0, half), m.ARENA, 400.0) == Vector2(400, 400) and Minimap.to_map(Vector3(half, 0, -half), m.ARENA, 400.0) == Vector2(400, 0)
		and Minimap.to_map(Vector3(-half, 0, half), m.ARENA, 400.0) == Vector2(0, 400), "世界座標換成圖上座標（四個角、中央；北在上）")
	_end(m)

## 戰場資訊（0.8.16 第 4 節）：尼諾拉不知道信封開過；保險箱開場大家都標；蛋的標記每 5 秒跟上一次（尼諾拉也是）
func _case_battle_info() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)   # 遊戲開始：主機（1）是恐龍
	var b: Node3D = m._boss()
	b.pilot = 1   # 真人駕駛也不叫
	var marks := func(label: String) -> Array:
		return m._match_hud.compass_marks(Vector3.ZERO).filter(func(k: Dictionary) -> bool: return String(k.label).begins_with(label))
	var c: Cowboy = m.players.get_node(^"-1")
	c.global_position = p.env_pos[0] + Vector3(0.5, 0.5, 0)
	b._noise_left = 0.0
	_ck(p.read(-1, 0) and b._noise_left <= 0.0, "看牌不叫恐龍（真人駕駛）")
	p._process(0.0)
	var env: Array = marks.call(Envelope.NAMES[0])
	_ck(env.size() == 1 and env[0].label == Envelope.NAMES[0] and env[0].color == marks.call(Envelope.NAMES[1])[0].color and not p.envelopes[0].opened,
		"恐龍那台：開過的信封方位條不變灰、不寫已開，看起來也沒開")
	_ck(marks.call("保險箱").size() == 1 and marks.call("蛋").is_empty(), "恐龍：保險箱標著，蛋鎖著不另外標")
	p.dino_id = -2   # 換成從沒看過牌的獵人那台看
	p._process(0.0)
	env = marks.call(Envelope.NAMES[0])
	_ck(env.size() == 1 and env[0].color != marks.call(Envelope.NAMES[1])[0].color and p.envelopes[0].opened, "獵人那台：開過的信封變灰")
	_ck(p.my_digits == [-1, -1] and marks.call("保險箱").size() == 1, "沒看過牌的獵人：方位條上有保險箱")
	p.dino_id = 1
	# 箱子開了：標蛋，位置 5 秒跟上一次
	s.open = true
	p._process(0.0)
	var at: Vector3 = m.egg.global_position
	var egg := func() -> Array: return m._match_hud.world_marks().filter(func(k: Dictionary) -> bool: return k.label == "蛋")
	_ck(egg.call().size() == 1 and marks.call("保險箱").is_empty() and egg.call()[0].pos == at, "箱子開了：恐龍也標蛋（畫面上）、不標箱子")
	m.egg.global_position = at + Vector3(20, 0, 0)
	_ck(egg.call()[0].pos == at, "蛋動了：5 秒內標記停在原地")
	m._match_hud._seen[&"egg"][1] -= int(m._match_hud.MARK_REFRESH * 1000.0) + 1
	_ck(egg.call()[0].pos == m.egg.global_position, "過 5 秒：跟上新位置")
	_end(m)

## 撤離點誰知道、畫面上的標記（0.8.16 第 7 節）：獵人看過信、搜過吞掉的信封、拿過蛋才知道（死了還記得）；尼諾拉一直知道；
## 不知道的人連地上的光圈、水管都看不到（碰撞照舊）。星星每 5 秒跟上
func _case_exit_knowledge() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)   # 遊戲開始：主機（1）是恐龍
	var exits := func() -> int: return m._match_hud.world_marks().filter(func(k: Dictionary) -> bool: return k.label == "撤離").size()
	var pads := func() -> Array: return range(m.map._exit_pads.size()).filter(func(i: int) -> bool: return m.map._exit_pads[i].visible)
	var on: Array = range(m.map._exits.size()).filter(func(i: int) -> bool: return (m.egg.exits >> i) & 1 == 1)
	p._process(0.0)
	_ck(p.knows_exits() and exits.call() == 2 and pads.call() == on, "尼諾拉一直知道撤離點、看得到光圈")
	p.dino_id = -2   # 換成獵人那台
	p._process(0.0)
	var pipe: Node3D = m.map._exit_pipes[on[0]][-1]
	_ck(not p.knows_exits() and exits.call() == 0 and pads.call().is_empty() and not pipe.visible and pipe.can_process(),
		"沒看過信、沒拿過蛋的獵人：沒有標記、光圈水管看不到（碰撞還在）")
	p.my_hint = [[1, 2, 3, 4, 5], [1, 2, 3, 4, 5]]
	_ck(p.knows_exits(), "搜過吞掉的信封：知道")
	p.my_hint = []
	p.my_digits = [-1, 4]
	p._process(0.0)
	_ck(p.knows_exits() and exits.call() == 2 and pads.call() == on, "看過一封信：有標記、看得到光圈")
	p.my_digits = [-1, -1]
	m.egg.carrier = 1
	p._process(0.0)
	m.egg.carrier = 0
	p._process(0.0)
	_ck(p.touched_egg and p.knows_exits(), "拿過蛋：放下了還是知道")
	p.phase = &"result"
	p._process(0.0)
	_ck(not p.knows_exits(), "回合外清掉")
	p.phase = &"play"
	# 星星：每 5 秒跟上
	var star := func() -> Array: return m._match_hud.world_marks().filter(func(k: Dictionary) -> bool: return k.label == "★星星")
	p.star_on = true
	p.star_pos = Vector3(10, 0, 10)
	var first: Vector3 = star.call()[0].pos
	p.star_pos = Vector3(30, 0, 10)
	_ck(star.call()[0].pos == first, "星星動了：5 秒內標記停在原地")
	m._match_hud._seen[&"star"][1] -= int(m._match_hud.MARK_REFRESH * 1000.0) + 1
	_ck(absf(star.call()[0].pos.x - 30.0) < 0.01, "過 5 秒：跟上新位置")
	_ck(m._match_hud.compass_marks(Vector3.ZERO).all(func(k: Dictionary) -> bool: return k.has("icon") and not k.label in ["撤離", "蛋", "★星星"]),
		"方位條全是圖示，撤離、蛋、星星不在方位條")
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
	_toy_fire_case()

## 物理規則第二版（docs/規劃/2026-11-10-物理規則.md）：火燒可燃的塊（燒成灰、不留碎塊、原地生新火、一路燒過去），磚不燒；
## 全場火的上限；火球打可燃的塊留火、打磚不留；炸藥推碎塊；新的一場燒掉的塊回來
func _toy_fire_case() -> void:
	var m := _toy_map()
	var tree := m.get_tree()
	var row := []
	for k in 4:   # 一排 4 塊木頭（間隔 0.9 公尺），最後一塊磚
		row.append([Transform3D(Basis(), Vector3(k * 0.9, 0.5, 0)), Vector3(0.9, 1.0, 0.3), 1, Color.RED])
	row.append([Transform3D(Basis(), Vector3(4 * 0.9, 0.5, 0)), Vector3(0.9, 1.0, 0.3), 2, Color.BLUE])
	var t := ToyBuild.make(row)
	t.name = "ToyFire"
	m.map.add_child(t)
	t.position = Vector3(30, 50, 30)   # 空中：地圖上的東西碰不到
	var fires := func() -> int: return tree.get_nodes_in_group(&"oil_fire").size()
	var n0: int = fires.call()
	var f := OilFire.spill(m.map, t.global_position, null, 0.6, 6.0, false)
	Balance._vals["fire_burns_toys"] = "0"
	for k in 8:
		f._burn_toys(0.6)
	t.fireball_fire(t.center_of(0), 0.5)
	_ck(t.is_standing(0) and fires.call() == n0 + 1, "開關關著：火不燒積木、火球不留火")
	f._t = 0.0
	t._burning.clear()
	Balance._vals["fire_burns_toys"] = "1"   # 下面測打開的樣子，測完關回去
	for k in 5:
		f._burn_toys(0.6)
	_ck(t.is_standing(0), "木頭在火裡 2.5 秒還沒燒掉")
	f._burn_toys(0.6)
	_ck(not t.is_standing(0) and _piece_node(t, 0) == null and t.loose_ids().is_empty(), "木頭在火裡 3 秒燒成灰、不留碎塊")
	_ck(fires.call() == n0 + 2, "燒掉的塊原地生一灘新火（有 %d 灘）" % (fires.call() - n0))
	for k in 40:   # 每灘火都燒 20 秒：一塊接一塊燒過去
		for g: Node in tree.get_nodes_in_group(&"oil_fire"):
			if g.burning():
				g._burn_toys(g.radius)
	_ck(not t.is_standing(1) and not t.is_standing(2) and not t.is_standing(3), "火一路燒過去，整排木頭都燒掉")
	_ck(t.is_standing(4) and t.hp_of(4) == 2, "磚不燒")
	for g: Node in tree.get_nodes_in_group(&"oil_fire"):
		g.free()
	# 上限：還在燒的火滿 fire_max 灘就不生
	var made := 0
	while t.fire_at(t.global_position + Vector3(made, 0, 0), 1.0, 6.0) and made < 100:
		made += 1
	_ck(made == Balance.whole("fire_max") and not t.fire_at(t.global_position, 1.0, 6.0), "全場最多 %d 灘火（生了 %d）" % [Balance.whole("fire_max"), made])
	for g: Node in tree.get_nodes_in_group(&"oil_fire"):
		g.free()
	# 新的一場：燒掉的回來
	t.restore()
	_ck(t.is_standing(0) and t.is_standing(3) and t._ash.is_empty(), "新的一場：燒掉的塊回來")
	# 火球：打可燃的塊留火，打磚不留
	t.fireball_fire(t.center_of(4), 0.5)
	_ck(fires.call() == 0, "火球打磚不留火")
	t.fireball_fire(t.center_of(0), 0.5)
	_ck(fires.call() == 1, "火球打木頭留一灘火")
	for g: Node in tree.get_nodes_in_group(&"oil_fire"):
		g.free()
	# 炸藥推碎塊：先拆一塊變碎塊、等它落地凍住，爆炸在它旁邊，它要被炸飛（變回會飛的）
	_hit_brick(t, 3, 1)
	var key := 3
	_ck(t._info.has(key), "拆下來的木頭變成碎塊")
	t._physics_process(ToyBuild.SETTLE_TIME + 0.1)
	_ck(t._pieces[key] is StaticBody3D, "前提：木頭碎塊落地凍住")
	ToyBuild.blast(m.map, t.center_of(3) + Vector3(0, 0, -1.0), 3.0)
	_ck(t._pieces[key] is RigidBody3D, "炸藥炸得飛落地的木頭碎塊（推不動只管走路、跑步、衝撞）")
	Balance._vals["fire_burns_toys"] = "0"
	_free_map(m)

func _toy_bullet_case() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	Main.level_file = keep
	_park(m)
	# 前牆是等級 1（木板），後面一塊等級 2（雙層）：分級先關，力量 3 的子彈也停在前牆前面（前牆前面在 2.85 公尺）；放在 50 公尺高的空中，地圖上的積木和碎塊擋不到
	var wall := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.5, 1.5, 0.3), 1, Color.RED],
		[Transform3D(Basis(), Vector3(0, 0.75, 0.45)), Vector3(1.5, 1.5, 0.3), 2, Color.BLUE]])
	wall.name = "ToyWall"
	m.map.add_child(wall)
	wall.position = Vector3(0, 50, 0)
	var b := Bullet.new()
	var wp := Weapon.new()   # 不在場景樹裡：測完自己 free
	b.weapon = wp
	b.power = 2   # 步槍：穿前面的木頭（剩 1），停在後面的磚
	b.vel = Vector3(0, 0, 600)   # 一幀就飛過整個牆
	m.map.add_child(b)
	b.global_position = Vector3(0, 50.75, -3)
	b.set_physics_process(false)   # 自己不飛，等物理幀過了再由這裡推一次（advance）
	_defer(4, func() -> void:
		b.advance(1.0 / 120.0)
		_ck(b.is_queued_for_deletion() and b._pierced == 1 and b.power == 1, "力量 2 的子彈穿過木頭前牆、停在磚（穿了 %d 片、剩 %d）" % [b._pierced, b.power])
		_ck(absf(b._traveled - 3.30) < 0.05, "子彈停在磚牆前面（飛了 %.2f，磚牆在 3.30）" % b._traveled)
		_ck(wall.is_standing(0) and wall.is_standing(1) and wall.hp_of(0) == 1, "子彈不拆積木：穿過的木頭也沒扣血")
		_free_map(m)
		wp.free())

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

## 玩具積木第二批（docs/規劃/2026-11-08-玩具積木場景-二.md）：積木樹、石頭、柵欄的樣子和碰撞；超過上限的一次鬆脫併成大塊（每塊都還在場上），
## 晚加入的人一樣、還原照樣。尼諾拉撞積木、踢碎塊是物理的，見 dino.gd 的 _start_toyb_case
func _case_toy_b() -> void:
	_toy_b_static()
	_toy_b_merge()
	_toy_b_armor()
	_toy_b_freeze()

func _toy_b_static() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _toy_map()
	# 樹：積木、在 tree 群組、碰撞層只有 1（不加 SOLID_LAYER，關碰撞物件時尼諾拉穿過）、拆得掉；樹幹（最底下）等級 2、樹冠（最上面）等級 1
	var trees: Array = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"tree"))
	var tree_ok := not trees.is_empty()
	for t: ToyBuild in trees:
		tree_ok = tree_ok and t.collision_layer == 1 and t.can_break and t.level_of(0) == 2 and t.level_of(t.brick_count() - 1) == 1
	_ck(tree_ok, "積木樹（%d 棵）：碰撞層只有 1、拆得掉、樹幹等級 2、樹冠等級 1" % trees.size())
	# 石頭：積木、全部等級 3、拆不掉、有碰撞、群組 stone
	var stones: Array = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"stone"))
	var stone_ok := not stones.is_empty()
	for t: ToyBuild in stones:
		stone_ok = stone_ok and not t.can_break and not t.is_in_group(&"destructible") and (t.collision_layer & Fighter.SOLID_LAYER) != 0
		for i in t.brick_count():
			stone_ok = stone_ok and t.level_of(i) == 3
	_ck(stone_ok, "石頭（%d 顆）：積木、全部等級 3、拆不掉、有碰撞" % stones.size())
	# 樹冠沒有碰撞（射線穿過去）；只打樹幹最下面那塊兩下（max_level 2）→ 樹幹斷，樹冠因連通檢查跟著鬆脫
	var tr: ToyBuild = trees[0]
	var crown := _first_brick(tr, 1)
	var trunk0 := _first_brick(tr, 2)
	_defer(4, func() -> void:
		var space := tr.get_world_3d().direct_space_state
		var cc := tr.center_of(crown)
		var ray := PhysicsRayQueryParameters3D.create(cc + Vector3(-3, 0, 0), cc + Vector3(3, 0, 0))
		_ck(space.intersect_ray(ray).get(&"collider") != tr, "樹冠沒有碰撞：射線穿過樹冠")
		_hit_brick(tr, trunk0, 2)
		_hit_brick(tr, trunk0, 2)
		_ck(not tr.is_standing(trunk0) and not tr.is_standing(crown), "只打樹幹最下面那塊兩下：樹幹斷，樹冠跟著鬆脫")
	)
	# 柵欄：積木、等級 1、頂端還是 FENCE_H（翻越的高度不變）
	var fences: Array = m.map._toys.filter(func(t: ToyBuild) -> bool: return t.is_in_group(&"fence"))
	var fence_ok := not fences.is_empty()
	for t: ToyBuild in fences:
		var top := -INF
		for i in t.brick_count():
			fence_ok = fence_ok and t.level_of(i) == 1
			top = maxf(top, t._xf[i].origin.y + t._size[i].y * 0.5)
		fence_ok = fence_ok and absf(top - ArenaMap.FENCE_H) < 0.01
	_ck(fence_ok, "柵欄（%d 段）：積木、等級 1、頂端還是 FENCE_H（%.2f）" % [fences.size(), ArenaMap.FENCE_H])
	# 甩尾一下就拆柵欄：柵欄在恐龍後方（背朝 -X），離得夠近、在甩尾範圍內
	var fence: ToyBuild = m.map._fence(Vector3(-40, 0, -40), 6.0, 0.0)
	_defer(4, func() -> void:
		_with_first(m, func() -> void:
			var b: Node3D = m.spawn_boss()
			b.rotation.y = -PI * 0.5   # 背後朝 -X，柵欄在後面
			b.global_position = m.map._on_ground(Vector3(-30, 0, -40)) + Vector3(0, BOSS_GD.LIFT, 0)
			b._strike_sweep())
		var down := 0
		for i in fence.brick_count():
			if not fence.is_standing(i):
				down += 1
		_ck(down > 0 and fence.has_damage(), "甩尾一下柵欄就拆（%d 塊鬆脫）" % down)
		_free_map(m))
	Main.level_file = keep

func _toy_b_merge() -> void:
	var m := _toy_map()
	_merge_run(m, 0.2, "擠在 4 公尺內")   # 格子 3 公尺就夠，一組一組併
	_merge_run(m, 3.0, "散在 60 公尺內")   # 每塊各一格：格子要加倍才到 150 以內，一格裡有好幾塊
	_free_map(m)

## 400 塊（超過 MAX_PIECES）一次全拆：每塊都在某個碎塊裡；碎塊總數在上限內；晚加入一樣；還原照樣
func _merge_run(m: Node, spacing: float, label: String) -> void:
	var bricks := []
	for ix in 20:
		for iz in 20:
			bricks.append([Transform3D(Basis(), Vector3(ix * spacing, 0.25, iz * spacing)), Vector3(0.2, 0.5, 0.2), 1, Color.RED])
	var t := ToyBuild.make(bricks)
	t.name = "ToyMerge"
	m.map.add_child(t)
	t.position = m.map._on_ground(Vector3(-60, 0, -60))
	t.smash(func(_p: Vector3) -> bool: return true, 1, t.global_position)
	for _k in 12:   # 碎塊分幀生（一步最多 SPAWN_PER_TICK 個）
		t._physics_process(0.0)
	var n := t.brick_count()
	var covered := {}
	var biggest := 0
	for key in t._info:
		biggest = maxi(biggest, (t._info[key].m as PackedInt32Array).size())
		for mb: int in t._info[key].m:
			covered[mb] = true
	_ck(covered.size() == n and t._idle(), "超過上限一次鬆脫（%s）：每塊都在某個碎塊裡（%d 塊，併成 %d 個碎塊）" % [label, covered.size(), t.loose_ids().size()])
	_ck(t.loose_ids().size() <= ToyBuild.MAX_PIECES and t.loose_ids().size() > 0, "碎塊總數在上限 %d 內（%s）" % [ToyBuild.MAX_PIECES, label])
	_ck(biggest >= 2 or spacing < 1.0, "格子加倍後一格裡有好幾塊（%s，最大一組 %d 塊）" % [label, biggest])
	var all_down := true
	for i in n:
		all_down = all_down and not t.is_standing(i)
	_ck(all_down, "拆掉的塊都不站著（%s）" % label)
	# 晚加入：照主機的補送內容擺出一樣的碎塊（位置一樣、塊都藏起來）
	var st: Dictionary = t.state()
	var late := ToyBuild.make(bricks)
	late.name = "ToyMergeLate"
	m.map.add_child(late)
	late.position = t.position
	for g: Array in st.groups:
		late._resume_group(g[0], g[1])
	late._resume(st.ids, st.xfs, PackedInt32Array())
	for _k in 12:
		late._physics_process(0.0)
	var same := late.loose_ids().size() == t.loose_ids().size()
	for key in t._pieces:
		var lp: Node3D = late._pieces.get(key)
		same = same and lp != null and lp.global_transform.is_equal_approx((t._pieces[key] as Node3D).global_transform)
	var late_all_down := true
	for i in n:
		late_all_down = late_all_down and not late.is_standing(i)
	_ck(same and late_all_down, "晚加入的人：碎塊的位置一樣、塊都藏起來（%s）" % label)
	# 還原：每塊回來、碎塊刪掉
	t.restore()
	late.restore()
	var back := true
	for i in n:
		back = back and t.is_standing(i) and late.is_standing(i)
	_ck(back and t.loose_ids().is_empty() and late.loose_ids().is_empty(), "新的一場：大碎塊刪掉，每塊回來（%s）" % label)


## 子彈穿材質用的形狀編號要對到塊（沒碰撞的塊排前面也不能錯位）：第 0 個形狀是第 1 塊（等級 2）；有給材質的照給的
func _toy_b_armor() -> void:
	var t := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.5, 0.5, 0.5), 1, Color.RED, false],   # 樹冠式的沒碰撞塊（等級 1）
		[Transform3D(Basis(), Vector3(2, 0.5, 0)), Vector3(0.5, 0.5, 0.5), 2, Color.BLUE],        # 有碰撞（等級 2，沒給材質 = 磚）
		[Transform3D(Basis(), Vector3(4, 0.5, 0)), Vector3(0.5, 0.5, 0.5), 2, Color.BROWN, true, &"tree"]])   # 樹幹
	_ck(t.material_of(0) == &"brick" and t.material_of(1) == &"tree" and t.material_of(2) == &"", "子彈的材質照形狀對到塊（形狀 0 是等級 2 的磚、形狀 1 是樹）")
	t.free()
	# 規則表：每種材質四列都在 balance.csv；壞和穿照規格
	for mt: StringName in HitRules.MATS:
		HitRules.level(mt); HitRules.burns(mt); HitRules.thick(mt); HitRules.pushable(mt)
	_ck(Balance.missing.is_empty(), "材質表每列都在 balance.csv（少了 %s）" % [Balance.missing])
	_ck(not HitRules.breaks(2, &"stone") and not HitRules.breaks(3, &"iron") and HitRules.breaks(2, &"brick") and not HitRules.breaks(1, &"tree"), "壞：力道 ≥ 耐久，耐久 3 永遠不壞")
	_ck(HitRules.pierce(2, &"wood") == 1 and HitRules.pierce(1, &"brick") == HitRules.BLOCK and HitRules.pierce(3, &"iron") == 0, "穿：力道 ≥ 厚度才穿，剩力道 - 厚度")

## 碎塊在尼諾拉身體裡（真的 boss，不在對局裡不跑思考）：照時間凍（不等牠離開），飛的、凍住的都不跟牠相撞；比碎塊晚生的尼諾拉也一樣
func _toy_b_freeze() -> void:
	var m := _toy_map()
	var boss: Node3D = m.spawn_boss()
	boss.set_physics_process(false)
	var a := _brick_at_ground(m, Vector3(-60, 0, 30))
	_defer(3, func() -> void:
		_put_boss_over(boss, a)
		_defer(2, func() -> void:   # 身體移過去要跑一個物理幀
			_ck((a._pieces[0] as PhysicsBody3D).get_collision_exceptions().has(boss), "飛的碎塊不跟尼諾拉相撞")
			a._physics_process(ToyBuild.SETTLE_TIME + 0.1)
			var st: PhysicsBody3D = a._pieces[0]
			_ck(st is StaticBody3D, "碎塊在尼諾拉身體裡：時間到照凍（StaticBody3D）")
			_ck(st.get_collision_exceptions().has(boss), "凍住的碎塊也不跟尼諾拉相撞（推不動，尼諾拉走得過去）")
			var late: Node3D = load("res://boss.tscn").instantiate()
			m.add_child(late)
			_ck(st.get_collision_exceptions().has(late), "比碎塊晚生的尼諾拉也不跟它相撞")
			late.free()
			_free_map(m)))

## 一塊積木在 at（地面），炸開成碎塊（碎塊在原地飛）
func _brick_at_ground(m: Node, at: Vector3) -> ToyBuild:
	var t := ToyBuild.make([[Transform3D(Basis(), Vector3.ZERO), Vector3(0.6, 0.6, 0.6), 1, Color.RED]])
	t.name = "ToyFreeze%d" % m.map._toys.size()
	m.map.add_child(t)
	t.position = m.map._on_ground(at)
	t.smash(func(_p: Vector3) -> bool: return true, 1, t.global_position)
	return t

## 尼諾拉的身體壓在碎塊上
func _put_boss_over(boss: Node3D, t: ToyBuild) -> void:
	boss.global_position = t.global_position + Vector3(0, boss.LIFT, 0)

## 專用伺服器的碎塊（ToyBuild.no_flight，只在這裡開、測完關）：拆開直接靜態落地、沒有 RigidBody；
## 底下有東西就疊在上面（塊或碎塊），底下沒有的落到地上；底下是站著的塊就落在它頂面；踢開的先水平移開再落；_settle 等 SETTLE_TIME 秒才送
func _case_toy_nofly() -> void:
	var m := _toy_map()
	var size := Vector3(1.0, 0.5, 1.0)
	var t := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 0.25, 0)), size, 1, Color.RED],     # 0 底排（拆）
		[Transform3D(Basis(), Vector3(1, 0.25, 0)), size, 1, Color.RED],     # 1 底排（拆）
		[Transform3D(Basis(), Vector3(0, 0.75, 0)), size, 1, Color.RED],     # 2 壓在 0 上，連不到地面就掉
		[Transform3D(Basis(), Vector3(2.5, 0.75, 0)), size, 1, Color.RED],   # 3 懸空（底下沒有），要落到地上
		[Transform3D(Basis(), Vector3(0, 1.25, 0)), size, 1, Color.RED],     # 4 壓在 2 上
		[Transform3D(Basis(), Vector3(7, 0.25, 0)), size, 3, Color.GRAY],    # 5 站著的地基（等級 3，拆不掉）
		[Transform3D(Basis(), Vector3(7, 1.25, 0)), size, 1, Color.RED],     # 6 懸在地基上面，拆下來落在地基頂
	])
	t.name = "ToyNoFly"
	m.map.add_child(t)
	t.position = m.map._on_ground(Vector3(-70, 0, -60))
	var inv := t.global_transform.affine_inverse()
	ToyBuild.no_flight = true
	t.smash(func(p: Vector3) -> bool:
		var l := inv * p
		return l.y < 0.4 and l.x < 1.5, 1, t.global_position)
	t._flush()   # 專用伺服器的落地分幀做（每幀 LAND_PER_TICK 塊）；這個案例要一次全部落完才查
	ToyBuild.no_flight = false
	_ck(not t._has_flying() and t._pieces.size() == 6, "專用伺服器拆開：主機上沒有 RigidBody 碎塊（%d 個碎塊，都是靜態的）" % t._pieces.size())
	var all_static := true
	for key in t._pieces:
		all_static = all_static and t._pieces[key] is StaticBody3D
	# 疊在上面的：底面正好是底下那塊的頂面（2 壓 0、4 壓 2）；落在站著的地基頂的（6）：底面在地基頂（相對這棟的原點 0.5）
	var stacked := absf(_piece_bottom(t, 2) - _piece_bottom(t, 0) - 0.5) < 0.01 and absf(_piece_bottom(t, 4) - _piece_bottom(t, 2) - 0.5) < 0.01
	var on_base := absf(_piece_bottom(t, 6) - t.global_position.y - 0.5) < 0.01
	_ck(all_static and t._pieces.size() == 6, "碎塊都是靜態的")
	_ck(stacked and on_base, "疊得住：2 壓在 0 上、4 壓在 2 上（底面貼頂面）；6 落在站著的地基頂")
	var saved := {}
	for key in t._pieces:
		saved[key] = (t._pieces[key] as Node3D).global_transform
	_defer(2, func() -> void:   # 物理下一幀才看得到新的靜態碰撞體，射線也要等
		var rest := true
		for key in t._pieces:
			var gap := _rest_gap(t, key)
			rest = rest and absf(gap) <= 0.3
		_ck(rest, "每個碎塊底下都有東西擋：從中心往下射線打到的地方在底面 0.3 公尺內")
		# 炸開（炸藥炸碎塊，ToyBuild.blast 走 kick）：先水平移開 KICK_SHIFT 公尺再落下，還是靜態、落地
		var before := (t._pieces[3] as Node3D).global_position
		ToyBuild.no_flight = true
		t.kick(3, Vector3.RIGHT, 3.0)
		ToyBuild.no_flight = false
		var after := (t._pieces[3] as Node3D).global_position
		_ck(t._pieces[3] is StaticBody3D and t._landed.has(3) and absf(after.x - before.x - ToyBuild.KICK_SHIFT) < 0.01 and absf(_rest_gap(t, 3)) <= 0.3, "炸開的碎塊：水平移開 %.1f 公尺、落地（底下有東西擋）、還是靜態" % ToyBuild.KICK_SHIFT)
		# _settle：落地後 SETTLE_TIME 秒才送；送的位置就是落地的位置（前面還沒到時間，位置不動）
		t._physics_process(ToyBuild.SETTLE_TIME * 0.5)
		_ck(t._landed.size() == t._pieces.size(), "落地的碎塊還在等 SETTLE_TIME 秒（%d 個）" % t._landed.size())
		t._physics_process(ToyBuild.SETTLE_TIME)
		var moved := 0
		for key in saved:
			if key != 3 and not (t._pieces[key] as Node3D).global_transform.is_equal_approx(saved[key]):
				moved += 1
		_ck(t._landed.is_empty() and moved == 0, "時間到，_settle 送出，其他碎塊的位置和落地時一樣（沒有被改動）")
		_ck(t.loose_ids().size() == 6 and t.is_standing(5), "拆掉的 6 塊都還在場上（碎塊），地基還站著")
		_free_map(m)
	)

## 專用伺服器的碎塊對得上、不掉到地底（tools/debris_sync 抓到的兩個）：
## 1. 埋在地裡的塊（房子最底排頂面在地面下）拆下來，落在地面上，不從地形底下掉 50 公尺
## 2. 這棟的碎塊全停了（每幀處理關著）再被炸藥推：每幀處理要打開，SETTLE_TIME 秒後送 _settle（不然客戶端那塊一直飛）
## 3. 早就穿到地底的（飛的碎塊從地形底下掉下去）停在地面上；底下什麼都沒有、又在地面上面的（推到地圖外）留在原高度
func _case_toy_sync() -> void:
	var m := _toy_map()
	var t := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(1.0, 0.5, 1.0), 1, Color.RED],   # 0 埋在地裡（頂面 -0.25）
		[Transform3D(Basis(), Vector3(4, 0.25, 0)), Vector3(1.0, 0.5, 1.0), 3, Color.GRAY],  # 1 拆不掉
	])
	t.name = "ToySync"
	m.map.add_child(t)
	t.position = m.map._on_ground(Vector3(-60, 0, -40))
	ToyBuild.no_flight = true
	t.smash(func(p: Vector3) -> bool: return p.distance_to(t.center_of(0)) < 0.3, 1, t.global_position + Vector3(-2, 0, 0))
	t._flush()
	ToyBuild.no_flight = false
	_ck(t._pieces.has(0) and t._pieces[0] is StaticBody3D, "埋在地裡的塊拆下來：專用伺服器上是靜態碎塊")
	var bottom := _piece_bottom(t, 0) - t.global_position.y
	_ck(bottom > -0.3 and bottom < 0.5, "埋在地裡的塊落在地面上（底面比原點 %.2f 公尺），不掉到地底" % bottom)
	_defer(2, func() -> void:   # 靜態碰撞下一幀才在物理世界
		for i in 3:
			t._physics_process(ToyBuild.SETTLE_TIME)
		_ck(t._landed.is_empty() and not t.is_physics_processing(), "落地滿 SETTLE_TIME 秒送完 _settle，每幀處理關掉")
		ToyBuild.no_flight = true
		t.kick(0, Vector3.RIGHT, 3.0)
		ToyBuild.no_flight = false
		_ck(t.is_physics_processing() and t._landed.has(0), "全停之後被炸：每幀處理打開、等著送 _settle")
		t._physics_process(ToyBuild.SETTLE_TIME)
		_ck(t._landed.is_empty(), "炸開的碎塊 SETTLE_TIME 秒後送 _settle（客戶端那塊會停下來）")
		var box: AABB = t._info[0].box
		var none: Array[RID] = []
		var deep := t._land(Transform3D(Basis(), t.global_position + Vector3(0, -60, 0)), box, none)
		var deep_b := (deep * box.get_center()).y - box.size.y * 0.5 - t.global_position.y
		_ck(deep_b > -0.3 and deep_b < 0.5, "穿到地底的碎塊停在地面上（底面比原點 %.2f 公尺）" % deep_b)
		var out := Transform3D(Basis(), Vector3(5000, t.global_position.y + 2.0, 5000))
		_ck(absf(t._land(out, box, none).origin.y - out.origin.y) < 0.01, "推到地圖外、底下什麼都沒有：留在原高度，不往下掉 %d 公尺" % int(ToyBuild.LAND_DROP))
		_free_map(m)
	)

## 碎塊的底面高度（世界座標）：碎塊扶正（方塊本地的邊界框中心）算的
func _piece_bottom(t: ToyBuild, key: int) -> float:
	var n: Node3D = t._pieces[key]
	var box: AABB = t._info[key].box
	return (n.global_transform * box.get_center()).y - box.size.y * 0.5

## 碎塊中心往下射線打到的高度，減掉底面（0 代表剛好貼著；打不到回 999）
func _rest_gap(t: ToyBuild, key: int) -> float:
	var n: Node3D = t._pieces[key]
	var box: AABB = t._info[key].box
	var c := n.global_transform * box.get_center()
	var q := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 50.0)
	q.exclude = [(n as StaticBody3D).get_rid()]
	var hit := t.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 999.0
	return hit.position.y - _piece_bottom(t, key)

## 範圍拆（smash 的 area）：同一堵牆，有範圍和沒範圍拆到的塊一樣；範圍也真的縮小了要看的塊
func _case_toy_area() -> void:
	var m := _toy_map()
	var grid := []
	for ix in 12:
		for iy in 3:
			grid.append([Transform3D(Basis(), Vector3(ix, 0.25 + iy * 0.5, 0)), Vector3(1.0, 0.5, 1.0), 1, Color.RED])
	var a := ToyBuild.make(grid)
	var b := ToyBuild.make(grid)
	for pair: Array in [[a, "ToyAreaA", Vector3(-80, 0, -80)], [b, "ToyAreaB", Vector3(-80, 0, -70)]]:
		var t: ToyBuild = pair[0]
		t.name = pair[1]
		m.map.add_child(t)
		t.position = m.map._on_ground(pair[2])
	var c_local := Vector3(2.0, 0.75, 0.0)
	var c := b.global_transform * c_local
	var hit := func(p: Vector3) -> bool: return p.distance_to(c) < 1.2
	var area := AABB(c - Vector3.ONE * 1.2, Vector3.ONE * 2.4)
	var near := b.bricks_near(area).size()
	a.smash(func(p: Vector3) -> bool: return p.distance_to(a.global_transform * c_local) < 1.2, 1, a.global_position)
	b.smash(hit, 1, b.global_position, area)
	var same := true
	var loose := 0
	for i in a.brick_count():
		same = same and a.is_standing(i) == b.is_standing(i)
		if not a.is_standing(i):
			loose += 1
	_ck(same and loose > 0 and loose < a.brick_count(), "範圍拆和全部拆拆到的塊一樣（%d 塊鬆脫）" % loose)
	_ck(near > 0 and near < b.brick_count(), "範圍只看附近的塊（%d 塊，全部 %d 塊）" % [near, b.brick_count()])
	_free_map(m)

## 導航網格解析（main.gd _parse_arena）：沒拆過的積木存起來重用，拆過的重解析；和整個場地一次解析的頂點、索引數一樣
func _case_nav_parse() -> void:
	var Main: GDScript = load("res://main.gd")
	var m := _toy_map()
	var t := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.0, 0.5, 1.0), 1, Color.RED],
		[Transform3D(Basis(), Vector3(1, 0.25, 0)), Vector3(1.0, 0.5, 1.0), 1, Color.RED],
		[Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.0, 0.5, 1.0), 1, Color.RED],
	])
	t.name = "ToyNavParse"
	m.map.add_child(t)
	t.position = m.map._on_ground(Vector3(-70, 0, -50))
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nm.geometry_source_group_name = Main.NAV_GROUP
	var full_nm := NavigationMesh.new()
	full_nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var check := func(tag: String) -> void:
		var full := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(full_nm, full, m.map)
		var mine: NavigationMeshSourceGeometryData3D = m._parse_arena(nm)
		var same := mine.get_vertices().size() == full.get_vertices().size() and mine.get_indices().size() == full.get_indices().size()
		_ck(same, "%s：分段解析和整個場地一次解析的頂點、索引數一樣（%d/%d 對 %d/%d）" % [tag, mine.get_vertices().size(), mine.get_indices().size(), full.get_vertices().size(), full.get_indices().size()])
	check.call("沒拆過")
	_ck(m._toy_nav.has(t), "沒拆過的積木解析後存進快取")
	var cached: Variant = m._toy_nav[t][1]
	check.call("快取重用")
	_ck(m._toy_nav[t][1] == cached, "第二次解析沿用快取（同一份幾何，沒有重解析）")
	var inv := t.global_transform.affine_inverse()
	ToyBuild.no_flight = true
	t.smash(func(p: Vector3) -> bool:
		var l := inv * p
		return l.y < 0.4 and l.x < 1.5, 1, t.global_position)
	ToyBuild.no_flight = false
	_defer(2, func() -> void:   # 碎塊的靜態碰撞要過一幀才在場景裡
		_ck(t.has_damage(), "拆過的積木：有挨打")
		check.call("拆過之後")
		_free_map(m)
	)

## 蛋被碎塊包住（房子拆倒、碎塊堆在蛋上）就往上抬到露出來；積木一塊都不動、不消失。旁邊沒包住的蛋不動
func _case_egg_unbury() -> void:
	var m := _toy_map()
	var base: Vector3 = m.map._on_ground(Vector3(-70, 0, -50))
	var b := ToyBuild.make([
		[Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(2, 2, 2), 1, Color.RED],
	])
	b.name = "ToyEggBrick"
	m.map.add_child(b)
	b.position = base
	var egg: Egg = m.egg
	egg.carrier = 0
	egg.global_position = base + Vector3(0, 1.0, 0)   # 蛋的位置在積木正中間
	_defer(4, func() -> void:   # 積木的靜態碰撞要過一幀才查得到
		egg._physics_process(DT)
		_ck(egg.global_position.y >= base.y + 1.99, "蛋被積木包住要往上抬到頂（現在 y=%.2f，頂在 %.2f）" % [egg.global_position.y, base.y + 2.0])
		_ck(b.is_standing(0), "蛋抬起來時積木不能被拿掉")
		egg.global_position = base + Vector3(3, 1, 0)   # 旁邊 3 公尺，沒包住
		var before := egg.global_position
		egg._physics_process(DT)
		_ck(egg.global_position.is_equal_approx(before), "沒被包住的蛋不該動")
		_free_map(m)
	)

## ---- 保險箱的物理（safe.gd 第 4 步）：接在自動跨上矮碎塊後面（_phase 8，每個物理幀推）。
## 尼諾拉、牛仔的物理關掉，照 _physics_process 的順序直接推；對局本身（party.step、箱子的救回）照常每個物理幀跑
var _sp_m: Node
var _sp_s: Safe
var _sp_b: Node3D
var _sp_c: Node3D
var _sp_stage := 0
var _sp_t := 0.0
var _sp_from := Vector3.ZERO
var _sp_code := -1
const SP_AT := Vector3(-30, 0, 40)
var _sp_plat: Node
var _sp_wall: Node

func _sp_box(m: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1 | Fighter.SOLID_LAYER
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	m.map.add_child(b)
	b.global_position = at
	return b   # 牧場這附近是空地

func _su_end() -> bool:
	_free_map(_su_m)
	_start_safe_physics()
	return false

func _physics_process(delta: float) -> bool:
	if _phase == 8:
		return _sp_physics(delta)
	return super(delta)

func _start_safe_physics() -> void:
	_phase = 8
	_case_safe_client()
	var m := _isolated_match()   # 自己的物理世界：前面的案例留下的地圖不會撞到
	_sp_m = m
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	m._physics_process(DT)   # 開場：主機（1）當恐龍，-1～-3 是電腦牛仔
	_sp_s = m.safe
	_sp_b = m._boss()
	_sp_b.set_physics_process(false)
	_sp_b.global_position = Vector3(0, 800, 0)
	for id in [-1, -2, -3]:
		var c: Node3D = m.players.get_node(NodePath(str(id)))
		c.set_physics_process(false)
		c.global_position = Vector3(id * 5, 800, 0)
	_sp_c = m.players.get_node(^"-1")
	m.party._hide_egg_at(SP_AT)
	m.party.time_left = 0.0
	m._physics_process(DT)
	_sp_s.place(m._on_ground(SP_AT + Vector3(0, Safe.HALF, 0)))
	_sp_code = _sp_s._code
	_ck(m.party.phase == &"play" and _sp_s.locked() and not _sp_s.freeze, "遊戲開始：箱子鎖著、主機算物理")
	_sp_next(0)

## 客戶端的箱子不自己算：凍著，推了也不動
func _case_safe_client() -> void:
	var vp := SubViewport.new()
	root.add_child(vp)
	var mp := SceneMultiplayer.new()
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	mp.multiplayer_peer = peer
	set_multiplayer(mp, vp.get_path())
	var s := Safe.new()
	vp.add_child(s)
	s.reset(true)
	s.place(Vector3(0, 50, 0))
	s.push(Vector3.UP * 10.0)
	_ck(not s.multiplayer.is_server() and s.freeze and s.linear_velocity == Vector3.ZERO, "客戶端的保險箱凍著，不自己算物理")
	peer.close()
	root.remove_child(vp)
	vp.free()

func _sp_next(stage: int) -> void:
	_sp_stage = stage
	_sp_t = 0.0
	_sp_from = _sp_s.global_position

func _sp_moved() -> float:
	var d := _sp_s.global_position - _sp_from
	return Vector2(d.x, d.z).length()

## 箱子鎖著時蛋跟著（party.step 每幀擺）
func _sp_egg_follows() -> bool:
	return _sp_s.locked() and _sp_m.egg.global_position.distance_to(_sp_s.global_position) < 0.5 and _sp_m.egg.carrier == 0

func _sp_physics(delta: float) -> bool:
	_sp_t += delta
	var s := _sp_s
	var m := _sp_m
	var c := _sp_c
	var b := _sp_b
	match _sp_stage:
		0:   # 放好，等它站穩、凍住
			if _sp_t > 1.5:
				_ck(s.freeze, "保險箱停下來就凍住（當牆，角色推不動）")
				_sp_next(1)
				c.global_position = s.global_position + Vector3(-2.0, -Safe.HALF, 0)
				c.velocity = Vector3.ZERO
		1:   # 牛仔一直往箱子走：推不太動
			if not c.is_on_floor():
				c.velocity += c.get_gravity() * delta
			c._move_flat(Vector3.RIGHT * c.walk_speed, delta)
			if _sp_t > 2.0:
				_ck(_sp_moved() < 0.3, "牛仔走路撞保險箱：推不太動（動了 %.2f 公尺）" % _sp_moved())
				c.global_position = Vector3(0, 800, 0)
				b.rotation.y = -PI * 0.5   # 面向 +X
				b.global_position = m.boss_on_ground(s.global_position + Vector3(-(b.BODY_RADIUS + 1.0), 0, 0))
				b.velocity = Vector3.ZERO
				_sp_next(2)
		2:   # 尼諾拉走路、跑步撞上去：推不太動
			b._move(Vector3.RIGHT, _sp_t > 1.5, delta)
			if _sp_t > 3.0:
				_ck(_sp_moved() < 1.0, "尼諾拉走路跑步撞保險箱：推不太動（動了 %.2f 公尺）" % _sp_moved())
				_ck(_sp_egg_follows(), "撞過之後蛋還鎖在箱子裡、跟著箱子")
				_ck(s.freeze, "撞完還凍著")
				b.global_position = Vector3(0, 800, 0)
				_sp_from = s.global_position   # 炸凍著的箱子（實戰幾乎都是凍著的時候被炸）
				c.global_position = s.global_position + Vector3(0, -Safe.HALF, Safe.RANGE - 0.5)   # 站旁邊，不擋在箱子飛的方向（+X）
				_ck(s.try_code(-1, (_sp_code + 37) % 100), "炸之前有人在試")
				_sp_stage = 3
				_sp_t = 0.0
				var at := s.global_position + Vector3(-2.0, -Safe.HALF, 0)
				_with_first(m, func() -> void: Explosive.damage(m.map, at, 6.0, 0, null))   # 前面的案例可能留著別的對局：爆炸找第一個
		3:   # 炸藥：被炸飛；試的人站著不動，箱子飛走了這次作廢
			if _sp_t > 1.5:
				_ck(_sp_moved() > 2.0, "炸藥把保險箱炸飛（飛了 %.2f 公尺）" % _sp_moved())
				_ck(s.busy == 0 and Array(s.tried).count(1) == 0, "試到一半箱子被炸走（離開互動距離）：這次作廢")
				_ck(_sp_egg_follows(), "炸飛之後蛋還鎖在箱子裡、跟著箱子")
				c.global_position = Vector3(0, 800, 0)
				s.place(m._on_ground(SP_AT + Vector3(0, Safe.HALF, 0)))
				_sp_next(10)
		10:   # 等它凍住再甩
			if _sp_t > 1.5:
				_ck(s.freeze, "放好停下來凍住")
				b.rotation.y = 0.0   # 面向 -Z，後方是 +Z：箱子擺在尾根後面 4 公尺
				b.global_position = m.boss_on_ground(s.global_position - Vector3(0, 0, b.SWEEP_ROOT_BACK + 4.0))
				_sp_next(4)
				_with_first(m, func() -> void: b._strike_sweep())
		4:   # 甩尾：掃飛（往 +Z）
			if _sp_t > 1.5:
				_ck(_sp_moved() > 3.0 and s.global_position.z > _sp_from.z, "甩尾把保險箱掃飛（飛了 %.2f 公尺）" % _sp_moved())
				_ck(_sp_egg_follows(), "甩飛之後蛋還鎖在箱子裡、跟著箱子")
				b.global_position = Vector3(0, 800, 0)
				# 擺在一塊 2 公尺高的平台上（像積木屋頂），旁邊貼一面牆；凍住之後把平台拿掉，要掉下來
				var g: Vector3 = m._on_ground(SP_AT)
				_sp_plat = _sp_box(m, g + Vector3(0, 1.75, 0), Vector3(3, 0.5, 3))
				_sp_wall = _sp_box(m, g + Vector3(Safe.HALF + 0.25, 3.0, 0), Vector3(0.5, 2.0, 3))
				s.place(g + Vector3(0, 2.0 + Safe.HALF, 0))
				_sp_next(11)
		11:
			if _sp_t > 1.5:
				_ck(s.freeze, "停在平台上凍住")
				_sp_plat.free()
				_sp_next(12)
		12:   # 平台拆了：底下空了就解凍、掉回地面（旁邊貼著牆也一樣）
			if _sp_t > 1.5:
				var g: float = m._on_ground(Vector3(s.global_position.x, 0, s.global_position.z)).y
				_ck(s.global_position.y < g + 1.0, "底下的平台拆掉，凍著的箱子掉回地面（高 %.2f）" % (s.global_position.y - g))
				_sp_wall.free()
				s.global_position = Vector3(m.ARENA, -30.0, 0)   # 飛出場外、掉到地下
				_sp_next(5)
		5:   # 救回：搬回場內的地面
			if _sp_t > 0.1:
				var g: float = m._on_ground(Vector3(s.global_position.x, 0, s.global_position.z)).y
				_ck(absf(s.global_position.x) < m.ARENA * 0.5 and s.global_position.y > g - 0.1 and s.global_position.y < g + 2.0,
					"掉出場外的保險箱搬回場內地面（%s）" % s.global_position)
				s.global_position.y = g - 3.0
				_sp_next(6)
		6:
			if _sp_t > 0.1:
				var g: float = m._on_ground(Vector3(s.global_position.x, 0, s.global_position.z)).y
				_ck(s.global_position.y > g - 0.1 and _sp_egg_follows(), "掉到地面以下也搬回地面，蛋跟著（高 %.2f）" % (s.global_position.y - g))
				var ex: Vector2 = m.map.exit_spots()[0]
				s.place(m._on_ground(Vector3(ex.x, Safe.HALF, ex.y)))
				_sp_next(7)
		7:   # 滾進撤離圈不算撤離
			if _sp_t > 1.0:
				_ck(m.party.phase == &"play" and m.egg.extract == 0.0 and _sp_egg_follows(), "保險箱在撤離圈裡不算撤離")
				s.place(m._on_ground(SP_AT + Vector3(0, Safe.HALF, 0)))
				s.rotation = Vector3(PI * 0.5, 0.7, 0)   # 被炸翻過：躺著、轉了
				c.global_position = s.global_position + Vector3(1.6, -Safe.HALF, 0)
				_ck(s.try_code(-1, _sp_code), "箱子翻過還是試得開")
				_sp_next(8)
		8:   # 開箱：蛋放在箱頂，撿得起來
			if _sp_t > Safe.TRY_SECONDS + 0.3:
				var top := s.global_position + Vector3.UP * Safe.HALF
				_ck(s.open and m.egg.carrier == 0 and m.egg.global_position.y > top.y and Vector2(m.egg.global_position.x - top.x, m.egg.global_position.z - top.z).length() < 0.3,
					"箱子翻過再打開：蛋在箱頂（蛋 %s，箱 %s）" % [m.egg.global_position, s.global_position])
				_sp_next(9)
		9:
			if _sp_t > m.pickup_seconds() + 0.5:
				_ck(m.egg.carrier == -1, "箱子動過之後，開了蛋照舊撿得起來")
				_free_map(m)
				return _done()
	return false

## 電腦牛仔的腦（bot_brain.gd）：給一組狀況，看最高分的動作（docs/企劃/2026-11-13-電腦牛仔像真人.md「測試」）
func _case_bot_brain() -> void:
	var base := func() -> Dictionary:
		return {"me": Vector3.ZERO, "hp": 1.0, "last_life": false, "time_left": 200.0, "locked": true,
			"safe": Vector3(0, 0, -40), "cards": [Vector3(-40, 0, 0), Vector3(40, 0, 0)], "known": [-1, -1],
			"carrier": 0, "holder": Vector3.ZERO, "egg": Vector3(0, 0, -40), "exits": [Vector3(100, 0, 0), Vector3(-100, 0, 0)],
			"ffa": true, "dino": Vector3(0, 0, 200), "mates": []}
	var pick := func(ctx: Dictionary) -> String:
		var b := BotBrain.new(-1, {})
		b.think(ctx)
		return b.action
	var c: Dictionary = base.call()
	var a: String = pick.call(c)
	_ck(a in ["看牌0", "看牌1"], "開局：去看牌（%s）" % a)
	# 有人搶：隊友（電腦）比我近、也要去看牌0 → 我去看牌1
	c.cards = [Vector3(-30, 0, 0), Vector3(40, 0, 0)]
	c.mates = [{"pos": Vector3(-20, 0, 0), "vel": Vector3.ZERO, "act": "看牌0"}]
	_ck(pick.call(c) == "看牌1", "隊友比我近、要去同一張：我去另一張（%s）" % pick.call(c))
	# 真人隊友：比我近 10 公尺以上、正朝那張牌走，也算有人搶
	c.mates = [{"pos": Vector3(-15, 0, 0), "vel": Vector3(-5, 0, 0), "act": ""}]
	_ck(pick.call(c) == "看牌1", "真人隊友朝那張牌跑：我去另一張（%s）" % pick.call(c))
	# 箱子有人在試：看過一張的我不擠過去試，去看另一張
	c = base.call()
	c.known = [4, -1]
	c.mates = [{"pos": Vector3(0, 0, -39), "vel": Vector3.ZERO, "act": "試密碼"}]
	_ck(pick.call(c) in ["看牌1", "守箱"], "箱子有人在試：我不試，去看另一張或守箱（%s）" % pick.call(c))
	c.mates = []
	_ck(pick.call(c) == "試密碼", "看過一張、沒人在試：去試（第二張扣 25 分）（%s）" % pick.call(c))
	# 恐龍貼身、半血：躲
	c.dino = Vector3(0, 0, 3)
	c.hp = 0.5
	_ck(pick.call(c) == "躲", "恐龍貼身、半血：躲（%s）" % pick.call(c))
	var b := BotBrain.new(-1, {})
	b.think(c)
	var g: Vector3 = b.goal(c)
	_ck(g.distance_to(c.dino) > 40.0 and g.z < 0.0, "躲：往遠離恐龍的方向跑（%s）" % g)
	# 恐龍倒地（null）：險歸 0，箱子開了就衝去撿蛋
	c = base.call()
	c.locked = false
	c.dino = null
	_ck(pick.call(c) == "撿蛋", "箱子開了、恐龍倒地：撿蛋（%s）" % pick.call(c))
	# 拿著蛋：撤離，挑沒有恐龍的那個撤離點
	c.carrier = 1
	c.dino = Vector3(95, 0, 0)
	b = BotBrain.new(-1, {})
	b.think(c)
	_ck(b.action == "撤離" and b.goal(c) == c.exits[1], "拿著蛋：撤離，避開恐龍守著的撤離點（%s %s）" % [b.action, b.goal(c)])
	# 別人拿著蛋（各自為隊）：追他（決定 1）
	c.carrier = 2
	c.holder = Vector3(10, 0, 0)
	c.dino = Vector3(0, 0, 200)
	_ck(pick.call(c) == "追蛋", "別人拿著蛋：追他（%s）" % pick.call(c))
	# 不反覆：選了看牌0 之後，別的只高一點不換；2.5 秒內高很多也不換；被打到馬上換
	c = base.call()
	c.cards = [Vector3(-10, 0, 0), Vector3(60, 0, 0)]
	b = BotBrain.new(-1, {})
	b.think(c)
	_ck(b.action == "看牌0", "近的那張先（%s）" % b.action)
	b.since = BotBrain.LOCK + 1.0
	c.cards = [Vector3(-30, 0, 0), Vector3(20, 0, 0)]   # 看牌1 只多 3 分
	b.think(c)
	_ck(b.action == "看牌0", "別的只高一點：不換（%s）" % b.describe())
	b.since = 0.5
	c.dino = Vector3(-30, 0, 8)   # 恐龍守著看牌0：看牌1 高很多
	b.think(c)
	_ck(b.action == "看牌0", "剛換動作 2.5 秒內：不換（%s）" % b.describe())
	b.since = BotBrain.LOCK + 0.1
	b.think(c)
	_ck(b.action == "看牌1", "過了 2.5 秒：換（%s）" % b.describe())
	b.since = 0.5
	c.dino = Vector3(20, 0, 3)   # 恐龍改守看牌1
	c.hit = true
	b.think(c)
	_ck(b.action == "看牌0", "被打到：2.5 秒內也馬上重選（%s）" % b.describe())
	# 記憶：看到信心 1，8 秒降到 0；不知道在哪時險固定 0.1；只聽到不蓋掉看到的
	b = BotBrain.new(-1, {})
	b.remember(Vector3(0, 0, 10), 1.0)
	b.tick(BotBrain.FORGET * 0.5)
	_ck(absf(b.conf - 0.5) < 0.01, "沒再看到：信心慢慢降（%.2f）" % b.conf)
	b.remember(Vector3(0, 0, 50), BotBrain.HEARD_CONF)
	_ck(b.dino_mem == Vector3(0, 0, 50) and b.conf == BotBrain.HEARD_CONF, "信心比聽到的低了：聽到的蓋上去")
	b.remember(Vector3(0, 0, 90), 0.3)
	_ck(b.dino_mem == Vector3(0, 0, 50), "比較不確定的不蓋掉")
	b.tick(BotBrain.FORGET)
	c = base.call()
	c.conf = 0.0
	_ck(b.conf == 0.0 and is_equal_approx(b.risk(c, Vector3.ZERO), BotBrain.UNKNOWN_RISK), "忘了恐龍在哪：到處都有一點怕（%.2f）" % b.risk(c, Vector3.ZERO))
	c.conf = 0.5
	c.dino = Vector3(0, 0, 0)
	_ck(is_equal_approx(b.risk(c, Vector3.ZERO), 0.5), "險＝信心 × 離記得的位置多近")
	# 個性（照編號固定）：恐龍 10 公尺、半血、剛被打 → 膽小的躲、勇敢的還擊
	_ck(BotBrain.new(-1).persona.name == "勇敢" and BotBrain.new(-2).persona.name == "膽小" and BotBrain.new(-3).persona.name == "投機"
		and BotBrain.new(-4).persona.name == "勇敢", "個性照編號固定")
	c = base.call()
	c.dino = Vector3(0, 0, 10)
	c.hp = 0.5
	c.sees = true
	c.hit_ago = 0.5
	var timid := BotBrain.new(-2)
	timid.think(c)
	var brave := BotBrain.new(-1)
	brave.think(c)
	_ck(timid.action == "躲" and brave.action == "還擊", "恐龍 10 公尺、半血、剛被打：膽小的躲（%s）、勇敢的還擊（%s）" % [timid.describe(), brave.describe()])
	# 投機的：有人在試密碼，我去守箱（站在箱子外 10 公尺、朝恐龍那邊）
	c = base.call()
	c.known = [4, -1]
	c.mates = [{"pos": Vector3(0, 0, -39), "vel": Vector3.ZERO, "act": "試密碼"}]
	var opp := BotBrain.new(-3)
	opp.think(c)
	var gp: Vector3 = opp.goal(c)
	_ck(opp.action == "守箱" and is_equal_approx(gp.distance_to(c.safe), BotBrain.GUARD_DIST) and gp.z > (c.safe as Vector3).z,
		"有人在試：投機的去守箱，面向恐龍那邊（%s %s）" % [opp.describe(), gp])
	# 不是各自為隊的模式：隊友拿著蛋就護送
	c = base.call()
	c.locked = false
	c.carrier = 2
	c.holder = Vector3(10, 0, 0)
	c.ffa = false
	_ck(pick.call(c) == "護送", "隊友拿著蛋（同一隊）：護送（%s）" % pick.call(c))

## 電腦牛仔只看得到看得到的（cowboy.gd 的 _bot_sees，恐龍、牛仔同一套，只差距離）：中間有牆看不到、背後看不到、貼身一定知道。射線要等牆進物理世界，跨幀
func _case_bot_sight() -> void:
	var m := _offline_match()
	var d: Node3D = m._add_player(m.COWBOY, 7)   # 看的對象用牛仔（恐龍編號 1 是本機操控，會搶後面槍的案例的那隻）
	var c: Cowboy = m._add_player(m.COWBOY, -5)   # 不設 bot：只測眼睛，不讓它自己跑
	_park(m)   # 要跨幀：不能搶後面案例的「第一個對局」
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(20, 30, 0.5)
	wall.add_child(cs)
	m.get_node(^"Arena").add_child(wall)
	wall.global_position = Vector3(300, 600, -15)
	var place := func(dz: float) -> void:
		c.global_position = Vector3(300, 600, 0)
		c.rotation.y = 0.0   # 面向 -Z
		d.global_position = Vector3(300, 600, dz)
	_defer(3, func() -> void:
		place.call(-30.0)
		_ck(not c._bot_sees(m, d, BotBrain.SIGHT_COWBOY), "中間有牆：看不到")
		wall.global_position = Vector3(300, 900, -15)
		_defer(3, func() -> void:
			place.call(-30.0)
			_ck(c._bot_sees(m, d, BotBrain.SIGHT_COWBOY), "拿掉牆：看得到")
			place.call(30.0)
			_ck(not c._bot_sees(m, d, BotBrain.SIGHT_COWBOY), "在背後：看不到")
			place.call(4.0)
			_ck(c._bot_sees(m, d, BotBrain.SIGHT_COWBOY), "貼身：不管方向都知道")
			place.call(-90.0)
			_ck(not c._bot_sees(m, d, BotBrain.SIGHT_COWBOY), "太遠看不到")
			root.remove_child(m)   # 不用 _end：它會關掉共用的連線，這時候槍的案例還在跑
			m.free()))


## party_hud.refresh：內容沒變不重建（_sync 每秒都發 changed，重建約 70 個節點會讓主機頓一下）
func _case_party_hud_same() -> void:
	var m := _offline_match()
	var hud: PartyHud = m.get_node("UI/Root").get_children().filter(func(n: Node) -> bool: return n is PartyHud).front()
	var me: int = m.multiplayer.get_unique_id()
	var p := Party.new()   # 不放進場景樹：只拿來裝值
	p.phase = &"play"
	p.names = {me: "阿明", 2: "小華"}
	p.scores = {me: 3, 2: 12}
	p.round_scores = {me: 1, 2: 10}
	p.dino_id = 2
	m.party = p
	hud._process(0.0)
	var rows := hud.scorebar.get_children()
	var cells := hud.board_rows.get_children()
	p.changed.emit()
	p.changed.emit()
	_ck(hud.scorebar.get_children() == rows and hud.board_rows.get_children() == cells, "狀態沒變時 refresh 不重建計分欄和分數板")
	p.scores[me] = 30   # 原地改：雜湊要看內容
	p.changed.emit()
	_ck(hud.scorebar.get_children() != rows, "分數變了要重建")
	var first: Label = hud.scorebar.get_child(0).get_child(0).get_child(2)
	_ck(first.text.begins_with("阿明"), "分數變了重排（現在第一列：%s）" % first.text)
	p.star_holder = me
	p.changed.emit()
	_ck("★" in (hud.scorebar.get_child(0).get_child(0).get_child(2) as Label).text, "拿到星星要畫 ★")
	m.party = null
	p.free()
	_end(m)

## 電腦牛仔卡在積木房子的牆角（docs/企劃/2026-11-16-未完成事項.md 第 2 項）：離導航網格遠、頂著牆 2 秒，就照走過的點退回網格再問路。
## 灰盒 Toy193 旁的牆角（bot_sim SEED=2 卡了 91 秒的那個），往撤離點 (62, 0) 走：10 秒內要離開原地 5 公尺以上。導航網格在背景烘，烘好才跑。
## ponytail: 靜態擺出來的牆角改前也走得出來（bot_sim 那種卡法要先繞進去），這裡只守「退得出來、不出錯」；真的驗收看 bot_sim 的「卡超過 20 秒」
func _case_bot_corner() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _isolated_match()
	Main.level_file = keep
	_park(m)
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	m._physics_process(DT)
	m.party.time_left = 0.0
	m._physics_process(DT)
	m.bake_nav()
	var b: Cowboy = m.players.get_node(^"-1")
	for c: Node in m.players.get_children():
		if c is Cowboy:
			c.bot_fire_range = 0.0   # 等網格的時候電腦自己會跑：不開槍（子彈找不到收起來的場地）
		if c != b:
			c.global_position = Vector3(0, 800, 0)   # 別人和恐龍放遠：不怕、不擋
	_bot_corner_wait(m, 0)

func _bot_corner_wait(m: Node, n: int) -> void:
	var map: RID = m.map.get_world_3d().navigation_map
	var ready: bool = is_instance_valid(m._nav_region) and m._nav_region.navigation_mesh != null and NavigationServer3D.map_get_iteration_id(map) > 0
	if not ready and n < 1200:
		_defer(1, func() -> void: _bot_corner_wait(m, n + 1))
		return
	_ck(ready, "導航網格烘好了")
	var b: Cowboy = m.players.get_node(^"-1")
	var corner: Vector3 = m._on_ground(Vector3(30.9, 1.0, 18.9))
	b.brain.action = "撿蛋"   # 借「撿蛋」的目標：直接指定要去哪，不重想
	b.brain.last_ctx = {"egg": Vector3(62, 0, 0), "me": corner}
	b.brain._think_left = 999.0
	var out := NavigationServer3D.map_get_closest_point(map, corner)
	_ck(corner.distance_to(out) > 1.5, "牆角離導航網格 1.5 公尺以上（%.1f 公尺）" % corner.distance_to(out))
	b.global_position = corner
	b.velocity = Vector3.ZERO
	b._trail = PackedVector3Array([out, out.lerp(corner, 0.5), corner])   # 走幾步進來的路
	var far := [0.0]   # lambda 抓的是複本：用陣列帶出來
	_with_first(m, func() -> void:
		for f in int(10.0 / DT):
			b._bot_step(DT)
			m._physics_process(DT)
			far[0] = maxf(far[0], Vector2(b.global_position.x - corner.x, b.global_position.z - corner.z).length())
			if far[0] > 5.0:
				break)
	_ck(far[0] > 5.0, "卡在牆角：10 秒內離開原地 5 公尺以上（最遠 %.1f 公尺，在 %s）" % [far[0], b.global_position])
	_free_map(m)

## 0.8.16 新得分（docs/企劃/2026-11-19-0.8.16-一般模式與規則改動.md 第 2 節）：第一個開信封 1（結算才公開）、開箱 3、打死拿蛋的 1
func _case_new_scores() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var s: Safe = m.safe
	m._physics_process(DT)   # 開場：主機（1）當恐龍，電腦 -1～-3 當牛仔
	var bots: Array = [-1, -2, -3].map(func(id: int) -> Node3D: return m.players.get_node(NodePath(str(id))))
	for c: Node3D in bots:
		c.global_position = Vector3(0, 800, 0)
	p.time_left = 0.0
	m._physics_process(DT)
	var sc := func(id: int) -> int: return int(p.scores.get(id, 0))
	# 信封：A 先看、B 後看同一封 → 只有 A 記 1 分，結算前計分欄不動
	bots[0].global_position = p.env_pos[0] + Vector3(1, 0.5, 0)
	bots[1].global_position = p.env_pos[0] + Vector3(-1, 0.5, 0)
	_ck(p.read(-1, 0) and p.read(-2, 0) and p.read(-1, 0), "兩個人看同一封、A 再看一次")
	_ck(p._env_bonus == {-1: 1} and sc.call(-1) == 0 and sc.call(-2) == 0 and not p.state().has("_env_bonus"), "第一個開信封：只記 A 1 分、還沒進計分欄（%s）" % p._env_bonus)
	# 開箱：試對的人 +3
	bots[1].global_position = s.global_position + Vector3(1.6, 0, 0)
	_ck(s.try_code(-2, s._code), "B 試正確密碼")
	s.server_step(Safe.TRY_SECONDS + 0.1)
	_ck(s.open and sc.call(-2) == 3, "開箱：試對的 B +3（%d）" % sc.call(-2))
	# 打死拿蛋的人：獵人 +1；自己炸死自己、恐龍咬死都不加
	m.egg.carrier = -1
	p.on_died(bots[2], bots[0])
	_ck(sc.call(-3) == 1, "C 打死拿蛋的 A：+1（%d）" % sc.call(-3))
	m.egg.carrier = -3
	p.on_died(bots[2], bots[2])
	_ck(sc.call(-3) == 1, "自己炸死自己不加")
	p.on_died(null, bots[2])
	_ck(sc.call(-3) == 1, "沒有兇手不加")
	var d0: int = sc.call(1)
	p.on_died(m._boss(), bots[2])
	_ck(sc.call(1) == d0 + 1, "尼諾拉咬死拿蛋的：只拿殺人的 1 分（%d → %d）" % [d0, sc.call(1)])
	m.egg.carrier = 0
	p.on_died(bots[0], bots[1])
	_ck(sc.call(-1) == 0, "打死沒拿蛋的不加")
	# 結算：信封的分併進去、跟著星星 × 2
	p.star_holder = -1
	var alive := p._cowboys().has(bots[0])
	p._end_round(false, "test")
	var want := (1 + (Party.SCORE_SURVIVE if alive else 0)) * Party.STAR_MULT
	_ck(sc.call(-1) == want and p._env_bonus.is_empty(), "結算：A 的信封分公開、拿星星一起 × 2（%d，要 %d）" % [sc.call(-1), want])
	_end(m)

## 0.8.16 搜刮倒地的尼諾拉（第 3.1 節，hold_action.gd）：沒倒地搜不了、按滿才拿到肉、差一點放開沒有、同一次倒地只能搜一次、
## 兩個人各算各的、走遠或牠起來就停、肉最多帶 1 塊；電腦會挑搜刮、會走過去按住
func _case_loot() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var h: HoldAction = m.hold
	m._physics_process(DT)   # 開場：主機（1）當恐龍，電腦 -1～-3 當牛仔
	p.time_left = 0.0
	m._physics_process(DT)
	var b: Node3D = m._boss()
	var a: Cowboy = m.players.get_node(^"-1")
	var a2: Cowboy = m.players.get_node(^"-2")
	var near := Party.loot_dist() - 0.5
	a.global_position = b.global_position + Vector3(near, 0, 0)
	a2.global_position = b.global_position + Vector3(-near, 0, 0)
	b.down_left = 0.0
	_ck(not h.start(-1, &"loot", b) and b.prompt == "", "尼諾拉沒倒地：搜不了、沒有提示")
	b.down_left = 15.0
	var secs := Party.LOOT_SECONDS
	_ck(b.prompt != "", "倒地：看著有「按住搜刮」的提示（%s）" % b.prompt)
	_ck(h.start(-1, &"loot", b), "倒地、夠近：開始搜")
	h._physics_process(secs - 0.1)
	h.stop(-1)
	_ck(a.meat == 0 and not b.looted.has(-1), "搜到差 0.1 秒放開：什麼都沒有")
	_ck(h.start(-1, &"loot", b) and h.start(-2, &"loot", b), "兩個人可以同時搜")
	h._physics_process(secs * 0.5)
	a2.global_position = b.global_position + Vector3(-(Party.loot_dist() + 1.0), 0, 0)
	h._physics_process(secs * 0.5 + 0.01)
	_ck(a.meat == 1 and b.looted.has(-1) and h.doing(-1) == &"", "按滿 %.0f 秒：拿到一塊肉（%d）" % [secs, a.meat])
	_ck(h.doing(-2) == &"" and a2.meat == 0, "另一個人搜到一半走遠：停、沒拿到")
	_ck(not h.start(-1, &"loot", b), "同一次倒地搜第二次不行")
	p.rekey(-1, 9)   # 同一次倒地斷線重連（換了編號）：搜過的紀錄跟著換
	_ck(b.looted.has(9) and not b.looted.has(-1), "重連換編號：搜過的紀錄搬到新編號（%s）" % b.looted)
	p.rekey(9, -1)
	a2.global_position = b.global_position + Vector3(-near, 0, 0)
	h.start(-2, &"loot", b)
	b.down_left = 0.0
	h._physics_process(0.1)
	_ck(h.doing(-2) == &"", "搜到一半牠起來：停")
	# 下一次倒地（_knock 清掉 looted）：可以再搜，但肉最多帶 1 塊
	b.down_left = 15.0
	b.looted.clear()
	h.start(-1, &"loot", b)
	h._physics_process(secs + 0.01)
	_ck(b.looted.has(-1) and a.meat == Fighter.MEAT_MAX, "已經帶滿：搜完也不再給（%d）" % a.meat)
	# 電腦：尼諾拉倒在附近、血少（或一張牌都沒看）就去搜；走到了自己按住，搜完拿到肉
	a2.hp = 40
	a2.brain = BotBrain.new(-2, {})
	var ctx: Dictionary = a2._bot_ctx(m)
	_ck(ctx.loot != null, "電腦的狀況裡有倒地的尼諾拉")
	a2.brain.think(ctx)
	_ck(a2.bot_action == "搜刮", "電腦血少、尼諾拉倒在旁邊：去搜刮（%s）" % a2.brain.describe())
	a2.global_position = b.global_position + Vector3(-(Party.loot_dist() - 1.5), 0, 0)   # 走到了（貼著牠的身體）
	for i in 3:
		a2._bot_loot(m)
	_ck(h.doing(-2) == &"loot", "電腦走到了自己按住")
	h._physics_process(secs + 0.01)
	a2._bot_loot(m)
	_ck(a2.meat == 1 and a2._bot_now, "電腦搜完拿到肉、馬上重想")
	var brain := BotBrain.new(-3, {})
	var c3: Dictionary = ctx.duplicate()
	c3.hp = 1.0
	c3.known = [3, -1]
	brain.think(c3)
	_ck(brain.action != "搜刮", "血多、看過牌的電腦不去搜（%s）" % brain.action)
	_end(m)

## 0.8.16 吞掉的信封（第 3.2 節）：每位 5 個候選、一定含正確的、每回合開場抽好大家一樣、每人每回合一次、只送本人、
## 死了還記得、回合重來清掉；面板上候選以外變暗；小抄括號列候選；電腦只從候選裡試
func _case_swallowed_envelope() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	var p: Party = m.party
	var h: HoldAction = m.hold
	var s: Safe = m.safe
	m._physics_process(DT)   # 開場：主機（1）當恐龍，電腦 -1～-3 當牛仔
	p.time_left = 0.0
	m._physics_process(DT)
	var code: int = s._code
	_ck(p._cands.size() == 2 and p._cands[0].size() == Party.HINT_COUNT and p._cands[1].size() == Party.HINT_COUNT
		and p._cands[0].has(code / 10) and p._cands[1].has(code % 10), "候選每位 %d 個、含正確的（%s，密碼 %02d）" % [Party.HINT_COUNT, p._cands, code])
	for t in 20:
		var c: Array = Party.roll_candidates(t * 5)
		_ck(c[0].has(t * 5 / 10) and c[1].has(t * 5 % 10) and c[0].size() == 5, "抽 %02d 的候選一定含正確的" % (t * 5))
	var b: Node3D = m._boss()
	var a: Cowboy = m.players.get_node(^"-1")
	var a2: Cowboy = m.players.get_node(^"-2")
	a.global_position = b.global_position + Vector3(Party.loot_dist() - 0.5, 0, 0)
	a2.global_position = b.global_position + Vector3(-(Party.loot_dist() - 0.5), 0, 0)
	b.down_left = 15.0
	h.start(-1, &"loot", b)
	h.start(-2, &"loot", b)
	h._physics_process(Party.LOOT_SECONDS + 0.01)
	_ck(p._hinted.has(-1) and p._hinted.has(-2) and p.my_hint.is_empty(), "兩個人都拿到（同一份 _cands）、主機自己（恐龍）沒拿到")
	_ck(not p.state().has("_cands") and not p.state().has("my_hint"), "候選不在公開的整包裡")
	# 下一次倒地再搜：吞掉的信封每回合一次，拿過的不會換一份
	var before: Array = p._cands.duplicate(true)
	b.looted.clear()
	h.start(-1, &"loot", b)
	h._physics_process(Party.LOOT_SECONDS + 0.01)
	_ck(p._cands == before, "同一回合候選不變")
	# 死了還記得（跟著人不跟著命）
	p.on_died(null, a)
	_ck(p._hinted.has(-1), "死了還記得")
	# 這台（主機）收到候選：面板變暗、小抄列候選
	p._got_hint(p._cands)
	var panel: SafePanel = m._safe_panel
	var out := -1
	for d in 10:
		if not p._cands[0].has(d):
			out = d
	_ck(panel.is_gray(0, out) and not panel.is_gray(0, code / 10), "面板：十位不在候選裡的變暗（%d），正確的不暗" % out)
	_ck(p.in_hint(1, code % 10) and not p.in_hint(0, out), "in_hint 對得上")
	p.my_digits = [code / 10, -1]
	m._match_hud.update_text(null)
	_ck(m.hud.text.contains("密碼 %d ?（%s）" % [code / 10, Party._digits_text(p._cands[1])]), "小抄：看過十位，個位括號列候選（%s）" % m.hud.text)
	# 電腦只從候選裡試
	a2.global_position = s.global_position + Vector3(1.6, 0, 0)
	a2.brain = BotBrain.new(-2, {})
	a2.brain.action = "試密碼"
	a2.brain.last_ctx = a2._bot_ctx(m)
	var cands: Array = p._cands
	var ok := true
	for t in 15:
		a2._bot_wait_for = "試密碼"
		a2._bot_wait = 0.0
		s.busy = 0
		a2._bot_safe_act(m, 0.01)
		if s.busy == -2:
			var n: int = s._try
			ok = ok and cands[0].has(n / 10) and cands[1].has(n % 10)
			s.busy = 0
	_ck(ok, "電腦只從候選裡試")
	# 回合重來：清掉
	p._start_round()
	_ck(p._hinted.is_empty() and p.my_hint.is_empty(), "新回合清掉吞掉的信封")
	_end(m)

## 一般模式（0.8.16 第 1 節）：整場固定一個人當恐龍，準備結束那一刻從想當的人裡抽；沒人勾電腦當；1 局直接到最終畫面
## 房間（選單流程 M2）：開房先進房間、不生人；房主改模式和局數、別人改不了；想當恐龍隨時改；按開始才生；晚加入接著打
func _case_room() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()
	var r: Room = m.room
	_ck(m.lobby.visible and m.lobby_page == &"room" and r.visible and m.players.get_child_count() == 0,
		"開房先進房間：大廳那一頁換成房間，還沒有人生出來")
	_ck(r.order == [1] and r.host_id == 1 and r.is_host() and r._start.visible, "開房的人是房主，看得到開始")
	m._on_peer_connected(7)
	_ck(r.order == [1, 7] and not m.players.has_node(^"7"), "有人連進來：排在名單後面，房間裡不生牛仔")
	r.ask(&"mode", &"party")
	_ck(m.rules == &"party" and r.mode == &"party" and r._mode_btns[&"party"].button_pressed, "房主選派對")
	r.handle(7, &"mode", &"egg")
	r.handle(7, &"start")
	_ck(m.rules == &"party" and not r.playing, "不是房主：改不了模式、按不了開始")
	r.ask(&"mode", &"normal")
	r.ask(&"rounds", 1)
	_ck(m.normal_rounds == 1 and r.rounds == 1 and r._rounds_row.visible, "一般模式才有局數，房主選 1 局")
	r._want.toggled.emit(true)
	_ck(m.want_dino and r.want.has(1), "勾「我想當恐龍」：名單上看得到")
	m._despawn(7)
	_ck(r.order == [1], "離線的人從名單拿掉")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	m._unhandled_input(esc)
	_ck(m.lobby_page == &"room", "房間按 Esc 不會離開")
	r.ask(&"start")
	_ck(r.playing and not m.lobby.visible and m.players.has_node(^"1") and m.party != null and m.party.rounds == 1,
		"按開始：進場、生出房主、一般模式照房間選的 1 局")
	m._on_peer_connected(9)
	_ck(r.order == [1, 9] and m.players.has_node(^"9"), "打到一半連進來：排進名單、照舊生（晚加入）")
	m._to_lobby("")
	_ck(not r.active and m.lobby_page == &"online", "離開房間：斷線、回連線頁")
	_end(m)

## 打完回房間（選單流程 M3）：結算 15 秒回房間、連線留著；房主「同設定再來一場」「回房間」；Esc「結束這場，回房間」；別人按不了
func _case_room_return() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()
	var r: Room = m.room
	r.ask(&"mode", &"egg")
	r.ask(&"start")
	m._on_peer_connected(7)
	_ck(m.players.has_node(^"1") and m.players.has_node(^"7"), "開打：兩個人都在")
	m._end_round()
	m._finish("時間到")
	_ck(m.result.visible and m.get_node(^"UI/Root/Result/Box/RestartBtn").text == "同設定再來一場" and m._back_btn.visible
		and m.get_node(^"UI/Root/Result/Box/Sub").text.contains("回房間"), "結算：房主看得到同設定再來一場、回房間，倒數回房間")
	r.handle(7, &"back")
	_ck(r.playing, "不是房主按不了回房間")
	r.ask(&"again")
	_ck(not m._over and not m.result.visible and m.players.has_node(^"1"), "同設定再來一場：直接開下一局")
	m._set_menu(true)
	_ck(m._end_btn.visible and m.get_node(^"UI/Root/Menu/Box/LeaveBtn").text == "關掉房間", "Esc：房主有「結束這場，回房間」，離開的字是「關掉房間」")
	m._set_menu(false)
	m._end_round()
	m._finish("x")
	m._physics_process(m.NEXT_ROUND_DELAY + 1.0)
	_ck(not r.playing and m.lobby.visible and m.lobby_page == &"room" and m.players.get_child_count() == 0 and not m.result.visible and r.order == [1, 7],
		"結算 15 秒到：回房間，場上清空，名單還在")
	_ck(m.multiplayer.multiplayer_peer != null, "回房間不斷線")
	# 一般模式 1 局：最後結算也有按鈕，房主按回房間
	r.ask(&"mode", &"normal")
	r.ask(&"rounds", 1)
	r.ask(&"start")
	m._physics_process(DT)   # 派對開第一局
	var p: Party = m.party
	p.time_left = 0.0
	m._physics_process(DT)
	p.extracted(1)
	_ck(p.phase == &"final" and m.result.visible and not m.get_node(^"UI/Root/Result/Box/Text").visible, "一般模式最後結算：只出按鈕（排名框是派對畫面畫的）")
	r.ask(&"back")
	_ck(not r.playing and m.party == null and m.lobby_page == &"room", "房主按回房間：派對收掉，回房間")
	# 最後結算時間到：回房間（延後到這一幀結束才收，Party 還在 step 裡面）
	r.ask(&"start")
	m._physics_process(DT)
	m.party.phase = &"final"
	m.party.time_left = 0.0
	m._physics_process(DT)
	_ck(m.party.phase == &"done", "最後結算時間到：排好回房間")
	m.back_to_room()   # 測試不等下一幀，直接做延後的那一步（之後延後的那次看到不在打就不動）
	_ck(not r.playing and m.party == null and m.lobby_page == &"room", "最後結算時間到：回房間")
	_end(m)

## 房間的準備、誰當恐龍（選單流程 M5）：準備只是燈；抽想當的人在按開始那一刻抽、電腦就是電腦、指定就是他；回房間準備清掉
func _case_room_dino() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()
	var r: Room = m.room
	m._on_peer_connected(7)
	r.handle(7, &"ready")
	_ck(r.prepared == [7] and r._list.get_child(1).text.contains("準備好了") and r._list.get_child(0).text.contains("還沒"), "按準備：名單上亮燈")
	r.handle(7, &"ready")
	_ck(r.prepared.is_empty(), "再按一次取消準備")
	r.handle(7, &"ready")
	r.handle(7, &"dino", 7)
	_ck(r.dino_pick == 0, "不是房主不能指定恐龍")
	_ck(r._dino_row.visible and r._dino_opt.item_count == 4, "一般模式：抽、電腦、指定玩家 1、玩家 2")
	r.ask(&"dino", 7)
	_ck(r.dino_pick == 7 and r._dino_opt.get_selected_metadata() == 7, "房主指定玩家 2")
	m._despawn(7)
	_ck(r.dino_pick == 0 and r.prepared.is_empty(), "指定的人走了：改回抽，準備也拿掉")
	r.ask(&"dino", 1)
	r.ask(&"start")
	m._physics_process(DT)
	var p: Party = m.party
	_ck(p.dino_id == 1 and p.fixed_id == 1 and m._boss().pilot == 1 and p._roster.size() == 4 and not p.names.values().has("電腦尼諾拉"),
		"指定自己：開場就當恐龍，獵人電腦補 3 個")
	r.ask(&"back")
	r.ask(&"dino", -1)
	m.want_dino = true
	r.ask(&"start")
	m._physics_process(DT)
	p = m.party
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"play" and p.dino_id < 0 and m.players.has_node(^"1"), "選電腦：有人想當也是電腦當")
	r.ask(&"back")
	r.ask(&"dino", 0)
	r.ask(&"start")
	m._physics_process(DT)
	_ck(m.party.dino_id == 1, "抽想當的人：按開始那一刻就抽")
	_end(m)

## 專用伺服器的房間（選單流程 M6）：沒人不開局；最早進來的人當房主，走了換下一個；沒人了設定回到預設；
## 打完回房間不自動開下一局；打到一半所有人都走了，30 秒後回房間
func _case_dedicated_room() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()   # 不開真的連線（_start_dedicated 會改物理頻率）
	m._on_mode_picked(m.RULES.keys().find(&"party"))   # 啟動參數 --mode party
	m._open_dedicated_room()
	var r: Room = m.room
	m._physics_process(1.0)
	_ck(r.active and not r.playing and r.host_id == 0 and m.players.get_child_count() == 0, "沒人：在房間、沒有房主、不開局不跑電腦")
	r.join(5)
	r.join(6)
	_ck(r.host_id == 5, "最早進來的人當房主")
	r.handle(6, &"start")
	r.handle(5, &"mode", &"normal")
	_ck(not r.playing and m.rules == &"normal", "房主能改模式，別人按不了開始")
	r.leave(5)
	_ck(r.host_id == 6 and m.status.text.contains("現在是房主"), "房主走了：交給下一個最早進來的，大家看到一行字")
	r.join(5)
	_ck(r.order == [6, 5] and r.host_id == 6, "原本的房主連回來排最後，不還給他")
	r.leave(6)
	r.leave(5)
	_ck(m.rules == &"party" and r.host_id == 0, "沒人了：設定回到啟動參數給的預設")
	r.join(8)
	r.handle(8, &"mode", &"egg")
	r.handle(8, &"start")
	_ck(r.playing and not m.lobby.visible, "房主按開始才開打")
	m._end_round()
	m._physics_process(m.NEXT_ROUND_DELAY + 1.0)
	_ck(not r.playing and m.lobby_page == &"room", "打完回房間，不自動開下一局")
	r.handle(8, &"start")
	m._physics_process(m.EMPTY_END - 1.0)
	_ck(r.playing, "所有人都走了：先等")
	m._physics_process(2.0)
	_ck(not r.playing and m.rules == &"party" and m.players.get_child_count() == 0, "等 30 秒沒人回來：結束這場、回房間、設定回到預設")
	m._dedicated = false
	_end(m)

func _case_normal_mode() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"normal"))
	m._apply_rules()
	var p: Party = m.party
	_ck(m.party_mode() and p.fixed and p.rounds == 4, "一般模式：派對那套、固定恐龍、預設 4 局")
	m._physics_process(DT)
	_ck(p.dino_id < 0 and p.names[p.dino_id] == "電腦尼諾拉" and m.players.has_node(^"1"), "開始時沒人想當：先由電腦當恐龍，主機站在牛仔那邊")
	m.want_dino = true   # 補救：開場後才勾，準備結束那一刻換他
	p.time_left = 0.0
	m._physics_process(DT)
	var hunters := p._roster.filter(func(id: int) -> bool: return id != p.dino_id)
	_ck(p.phase == &"play" and p.dino_id == 1 and p.fixed_id == 1 and m._boss().pilot == 1 and hunters.size() == 3 and hunters.all(func(id: int) -> bool: return id < 0),
		"準備結束：勾的人當恐龍、電腦補滿 3 個獵人（%s）" % [p._roster])
	_ck(not p.scores.keys().any(func(id: int) -> bool: return p.names.get(id, "") == "電腦尼諾拉"), "電腦恐龍那格拿掉")
	for r in 3:
		p._end_round(true, "test")
		p.time_left = 0.0
		m._physics_process(DT)
		_ck(p.phase == &"prep" and p.dino_id == 1, "第 %d 局還是同一個人當恐龍" % (r + 2))
		p.time_left = 0.0
		m._physics_process(DT)
	_end(m)
	# 沒人勾：電腦當恐龍、主機當獵人，每局都是
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"normal"))
	m._apply_rules()
	p = m.party
	m._physics_process(DT)
	for r in 2:
		p.time_left = 0.0
		m._physics_process(DT)
		_ck(p.phase == &"play" and p.dino_id < 0 and m._boss().pilot == 0 and m.players.has_node(^"1"), "沒人勾：電腦當恐龍、主機當獵人（第 %d 局）" % (r + 1))
		p._end_round(true, "test")
		p.time_left = 0.0
		m._physics_process(DT)
	# 中途連進來：接手一個活著的電腦獵人（位置、血、命數、看過的牌）
	p.time_left = 0.0
	m._physics_process(DT)
	var bot: Cowboy = p._cowboys().filter(func(c: Node) -> bool: return c.name.to_int() < 0)[0]
	var old := bot.name.to_int()
	bot.global_position = Vector3(12, 1, 7)
	bot.hp = 80
	p.lives[old] = 2
	p._known[old] = [3, -1]
	p.take_bot(7)
	var c := m.players.get_node_or_null(^"7") as Cowboy
	_ck(c != null and not p._roster.has(old) and p._roster.has(7) and c.global_position.distance_to(Vector3(12, 1, 7)) < 0.1 and c.hp == 80
		and int(p.lives[7]) == 2 and p._known[7] == [3, -1], "中途加入：接手電腦獵人的位置、血、命數、看過的牌")
	_end(m)
	# 1 局：撤離就直接到最終畫面，不出金色小恐龍
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"normal"))
	m.normal_rounds = 1
	m._apply_rules()
	p = m.party
	m._physics_process(DT)
	_ck(p.rounds == 1 and p.state().rounds == 1, "1 局：送給客戶端的也是 1 局")
	p.time_left = 0.0
	m._physics_process(DT)
	p.extracted(1)
	_ck(p.phase == &"final" and p.last_result.ends_with("獲勝"), "1 局：帶蛋撤離直接到最終畫面（%s）" % p.last_result)
	_end(m)
	# 專用伺服器：沒有真人不開第一局
	m = _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"normal"))
	m._apply_rules()
	m._dedicated = true
	m.party.step(DT)
	_ck(m.party.phase == &"", "專用伺服器沒有真人：不開第一局")
	m._dedicated = false
	_end(m)
