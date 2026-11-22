extends "res://tests/ui.gd"
## 團隊模式（docs/企劃/2026-11-19-團隊模式.md 第 13 節）。T1：隊伍骨架


## 跟電腦打、選團隊、按開始：1 個真人＋9 個電腦（電腦尼諾拉、三隊各 3 個），準備結束進 12 分鐘的遊戲
func _team_match() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_vs_bots_pressed()
	m.room.ask(&"mode", &"team")
	m.room.ask(&"start")
	m._physics_process(DT)   # party.step：開第一局（準備）
	return m


func _case_team() -> void:
	var m := _team_match()
	var p: Party = m.party
	var t: Team = p.team
	_ck(m.rules == &"team" and m.room._mode_btns.has(&"team") and not m.room._mode_btns[&"team"].disabled and m.room._dino_row.visible,
		"房間選得到團隊（不是灰的），有「誰當恐龍」")
	_ck(t != null and p.fixed and p.rounds == 1 and p._roster.size() == 10 and p.dino_id < 0, "團隊模式：1 局、10 個人、沒人勾就電腦當恐龍（%s）" % [p._roster])
	var hunters := p._roster.filter(func(id: int) -> bool: return id != p.dino_id)
	var per := [0, 0, 0]
	for id: int in hunters:
		per[t.team_of(id)] += 1
	_ck(hunters.size() == 9 and per == [3, 3, 3] and t.team_of(1) == 0 and not t.of.has(p.dino_id), "1 個真人＋9 個電腦：三隊各 3 人，第一個進來的是紅隊（%s）" % [per])
	_ck(p.state().team_of == t.of, "隊伍表跟著整包送給每台")
	# 出生區：同隊站在一起，不同隊隔很遠
	var pos := func(id: int) -> Vector3: return (m.players.get_node(str(id)) as Node3D).global_position
	var mates: Array = t.mates(1)
	var enemy: int = hunters.filter(func(id: int) -> bool: return t.team_of(id) == 1)[0]
	_ck(mates.size() == 2 and mates.all(func(id: int) -> bool: return Vector2(pos.call(id).x - pos.call(1).x, pos.call(id).z - pos.call(1).z).length() < 10.0)
		and Vector2(pos.call(enemy).x - pos.call(1).x, pos.call(enemy).z - pos.call(1).z).length() > 40.0, "同隊在同一個出生區，別隊在別區")
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"play" and p.time_left == 720.0 and int(p.lives[1]) == 1, "準備結束：12 分鐘、每人 1 條命")
	var me: Cowboy = m.players.get_node(^"1")
	var mate: Cowboy = m.players.get_node(str(mates[0]))
	var foe: Cowboy = m.players.get_node(str(enemy))
	_with_first(m, func() -> void:
		mate.take_damage(30, me)
		_ck(mate.hp == mate.max_hp, "隊友打不到隊友")
		foe.take_damage(30, me)
		_ck(foe.hp == foe.max_hp - 30, "打敵隊扣血")
		me.take_damage(10, me)
		_ck(me.hp == me.max_hp - 10, "自己的炸藥炸得到自己")
		Fighter.any_side = true
		mate.take_damage(5, me)
		Fighter.any_side = false
		_ck(mate.hp == mate.max_hp - 5, "爆炸桶不分敵我")
		# 電腦不打隊友：隊友、敵人都貼在面前，選敵人
		mate.brain = BotBrain.new(mate.name.to_int())
		var front := mate.global_position - mate.global_basis.z * 1.0
		me.global_position = front
		foe.global_position = front + Vector3(0.5, 0, 0)
		mate._bot_sense(m, 0.1)
		_ck(mate._bot_target == foe, "電腦看到隊友和敵人：打敵人（%s）" % [mate._bot_target])
		foe.global_position = Vector3(60, 1, 60)
		mate._bot_sense(m, 0.1)
		_ck(mate._bot_target != me, "電腦不打隊友")
		m.egg.carrier = 1
		_ck(not mate._bot_ctx(m).ffa, "隊友拿著蛋：護送，不追")
		m.egg.carrier = enemy
		_ck(mate._bot_ctx(m).ffa, "敵隊拿著蛋：追")
		m.egg.carrier = 0
		# 出局：1 條命，死了不重生，觀戰
		foe.take_damage(9999, me))
	_ck(int(p.lives[enemy]) == 0 and not p._waiting.has(enemy) and m._is_out(enemy) and p.phase == &"play", "死了就出局：不排重生，比賽繼續")
	# 中途加入：接手電腦，隊伍跟著
	var bot: int = p._cowboys().filter(func(c: Node) -> bool: return c.name.to_int() < 0)[0].name.to_int()   # take_bot 接手的那個
	var bot_team := t.team_of(bot)
	p.take_bot(7)
	_ck(t.team_of(7) == bot_team and not t.of.has(bot), "中途加入接手電腦隊員：隊伍跟著換")
	# 撤離的隊贏
	p.extracted(7)
	_ck(p.phase == &"final" and p.winner_team == bot_team and p.last_result.contains(Team.NAMES[bot_team]) and p.last_result.ends_with("獲勝"), "帶蛋撤離：他那一隊贏（%s）" % p.last_result)
	_end(m)
	# 時間到：尼諾拉贏
	m = _team_match()
	p = m.party
	p.time_left = 0.0
	m._physics_process(DT)
	p.time_left = 0.0
	m._physics_process(DT)
	_ck(p.phase == &"final" and p.winner_team == -1 and p.last_result.contains("尼諾拉獲勝"), "時間到沒人撤離：尼諾拉贏（%s）" % p.last_result)
	_end(m)
	# 9 個人全出局：尼諾拉贏
	m = _team_match()
	p = m.party
	p.time_left = 0.0
	m._physics_process(DT)
	_with_first(m, func() -> void:
		for c: Node in p._cowboys():
			c.take_damage(9999))
	m._physics_process(DT)
	_ck(p.phase == &"final" and p.winner_team == -1, "全部出局：尼諾拉贏（%s）" % p.last_result)
	_end(m)


## T3：三位數密碼、兩種信封、隊內共享（第 5、6 節）
func _case_team_code() -> void:
	# 信封內容：抽很多次，規則每次都對
	var rules_ok := true
	for r in 200:
		var code := randi() % 1000
		var n := 8 + r % 3
		var env := Team.roll_envelopes(code, n)
		var dig := [code / 100, code / 10 % 10, code % 10]
		var duals := env.filter(func(e: Array) -> bool: return e.any(func(c: Array) -> bool: return c.size() == Team.DUAL_CANDS))
		rules_ok = rules_ok and env.size() == n and duals.size() == (5 if n == 8 else 6)
		for k in 3:
			var decoys: Array = []
			var hit := 0
			for e: Array in env:
				var c: Array = e[k]
				rules_ok = rules_ok and (c.is_empty() or c.has(dig[k])) and c.size() in [0, 1, Team.DUAL_CANDS]
				if c.size() == 1:
					hit += 1
				for d: int in c:
					if d != dig[k]:
						decoys.append(d)
			var uniq := {}
			for d: int in decoys:
				uniq[d] = true
			rules_ok = rules_ok and uniq.size() == decoys.size() and hit >= 1   # 同一位的假數字不重複（看兩封雙位就確定）、每位都有單位提示
		# 看完全部：三位都確定
		var t := Team.new()
		t.env_info = env
		t.reset_intel()
		for i in n:
			t.merge(0, i)
		rules_ok = rules_ok and Team.sure(t.intel[0]) == dig
	_ck(rules_ok, "信封內容：8～10 封、雙位 5～6 封、候選含正確的、同一位假數字不重複、看完全部三位都確定")
	var tt := Team.new()
	tt.env_info = [[[1, 2, 5], [], [3, 4, 7]], [[2, 5, 8], [5, 6, 9], []]]
	tt.reset_intel()
	tt.merge(0, 0)
	_ck(tt.merge(0, 1) == [0, 1] and tt.intel[0][0] == [2, 5] and tt.intel[0][1] == [5, 6, 9] and tt.merge(0, 1).is_empty(), "取交集；同一隊看第二次沒有新東西")
	_ck(Team.cover_of(tt.env_info[0]) == [1, 0, 1] and Team.cover_text([2, 0, 1]) == "■□▣", "信封種類和圖示的字")

	var m := _team_match()
	var p: Party = m.party
	var t: Team = p.team
	var s: Safe = m.safe
	p.time_left = 0.0
	m._physics_process(DT)
	var n := p.env_pos.size()
	p._process(0.0)   # 每台每幀把信封擺好、套種類
	_ck(p.phase == &"play" and s.digits == 3 and s.tried.size() == 1000 and s._code >= 0 and s._code < 1000, "團隊模式：三位數密碼（%d）" % s._code)
	_ck(n >= 8 and n <= 10 and p.env_cover.size() == n and p.envelopes.filter(func(e: Envelope) -> bool: return e.visible).size() == n, "團隊模式：%d 封信，種類公開" % n)
	_ck(p.state().has("env_cover") and not str(p.state()).contains(str(t.intel)) and p._cands.is_empty(), "整包裡有信封種類、沒有隊伍情報；搜刮不給吞掉的信封")
	var dist_ok := true
	for i in n:
		for j in range(i + 1, n):
			dist_ok = dist_ok and Vector2(p.env_pos[i].x - p.env_pos[j].x, p.env_pos[i].z - p.env_pos[j].z).length() > 10.0
	_ck(dist_ok, "信封不擠在一起")
	var st := s.state()
	_ck(st.digits == 3 and (st.tried as PackedByteArray).decompress(1000, FileAccess.COMPRESSION_DEFLATE) == s.tried and (st.tried as PackedByteArray).size() < 200,
		"三位數試過的表壓縮送（%d 位元組）" % (st.tried as PackedByteArray).size())
	s.set_state(st)
	_ck(s.digits == 3 and s.tried.size() == 1000, "客戶端收到：解壓回 1000 格")
	# 紅隊（我）開一封：我和隊友的三格跟著變，別隊不變
	var me: Cowboy = m.players.get_node(^"1")
	var mate_id: int = t.mates(1)[0]
	var foe_id: int = t.of.keys().filter(func(id: int) -> bool: return t.team_of(id) == 1)[0]
	var i0 := 0
	me.global_position = p.env_pos[i0] + Vector3(0.5, 0.5, 0)
	_ck(p.read(1, i0) and p.env_open[i0] and t.seen[0] == [i0] and t.seen[1].is_empty(), "開信：紅隊記下看過，藍隊沒有")
	var red: Array = t.intel[0]
	p._process(0.0)
	_ck(p.my_hint == red and p.my_digits == Team.sure(red) and t.intel[1] == [range(10), range(10), range(10)], "我的小抄＝隊伍的三格；別隊的不變")
	var mate: Cowboy = m.players.get_node(str(mate_id))
	mate.brain = BotBrain.new(mate_id)
	var ctx := mate._bot_ctx(m)
	_ck(ctx.has("useful") and not (ctx.useful as Array).has(i0) and ctx.known == Team.sure(red) and ctx.cands == red, "電腦隊友拿到隊伍的情報，不再去看那封（%s）" % [ctx.get("useful")])
	var foe: Cowboy = m.players.get_node(str(foe_id))
	foe.brain = BotBrain.new(foe_id)
	_ck((foe._bot_ctx(m).useful as Array).has(i0), "別隊電腦還會去看那封")
	var acts: Array = mate.brain.score_all(ctx).keys().filter(func(k: String) -> bool: return k.begins_with("看牌"))
	_ck(not acts.is_empty() and acts.all(func(k: String) -> bool: return (ctx.useful as Array).has(BotBrain.card_of(k))) and not mate.brain.score_all(ctx).has("試密碼"),
		"電腦只挑補得到缺的那位的信；三格沒確定不去試（%s）" % [acts])
	m._match_hud.update_text(me)
	var cell := func(k: int) -> String: return str(red[k][0]) if red[k].size() == 1 else ("［%s］" % Party._digits_text(red[k]) if red[k].size() < 10 else "?")
	_ck(m.hud.text.contains("密碼 %s %s %s" % [cell.call(0), cell.call(1), cell.call(2)]), "小抄三格（%s）" % m.hud.text)
	# 方位條：本隊看過的那封拿掉
	var env_marks := func() -> int: return m._match_hud.compass_marks(Vector3.ZERO).filter(func(k: Dictionary) -> bool: return k.get("icon") == &"envelope3").size()
	_ck(env_marks.call() == n - 1 and p.envelopes[i0].opened and not p.envelopes[1].opened, "方位條標其他 %d 封（圖示看得出蓋哪幾位），看過的拿掉、牌面變灰" % (n - 1))
	# 面板三排：不可能的數字暗的，確定的先選好
	var panel: SafePanel = m._safe_panel
	panel.open_panel()
	var k0: int = range(3).filter(func(k: int) -> bool: return red[k].size() < 10)[0]   # 這封蓋到的一位
	var out: int = range(10).filter(func(d: int) -> bool: return not red[k0].has(d))[0]
	_ck(panel.pick.size() == 3 and panel._row_box[0][1].visible and panel.is_gray(k0, out) and not panel.is_gray(k0, red[k0][0])
		and panel.pick == Team.sure(red), "面板三排：不在候選裡的變暗，確定的先選好（%s）" % [panel.pick])
	panel.hide()
	# 看完全部：三格都確定，電腦去試；試對開箱
	for i in n:
		t.merge(0, i)
	ctx = mate._bot_ctx(m)
	_ck(ctx.known == [s._code / 100, s._code / 10 % 10, s._code % 10] and (ctx.useful as Array).is_empty() and mate.brain.score_all(ctx).has("試密碼"), "三格都確定：電腦去試密碼")
	me.global_position = s.global_position + Vector3(1.0, 0.5, 0)
	_ck(s.try_code(1, (s._code + 1) % 1000) and not s.try_code(1, 1000), "三位數也是一次試一個、1000 以上不收")
	_end(m)
