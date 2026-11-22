extends "res://tests/ui.gd"
## 團隊模式（docs/企劃/2026-11-19-團隊模式.md 第 13 節）。T1：隊伍骨架；T2：倒地、爬、失血、隊友救


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
		# 出局：1 條命，倒地倒數完不重生，觀戰
		foe.take_damage(9999, me)
		p._down_step(Team.BLEED_SECONDS + 1.0))
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
			c.take_damage(9999)
		m._physics_process(DT)
		_ck(p.phase == &"play", "9 個人全倒地：還沒結束，各自倒數完才算")
		p._down_step(Team.BLEED_SECONDS + 1.0))
	m._physics_process(DT)
	_ck(p.phase == &"final" and p.winner_team == -1, "全部出局：尼諾拉贏（%s）" % p.last_result)
	_end(m)


## T2：倒地、爬、失血、隊友救（第 3、4 節）
func _case_team_down() -> void:
	var m := _team_match()
	var p: Party = m.party
	var t: Team = p.team
	p.time_left = 0.0
	m._physics_process(DT)   # 進遊戲
	var me: Cowboy = m.players.get_node(^"1")
	var ids: Array = t.mates(1)
	var mate: Cowboy = m.players.get_node(str(ids[0]))
	var mate2: Cowboy = m.players.get_node(str(ids[1]))
	var enemy: int = t.of.keys().filter(func(id: int) -> bool: return t.team_of(id) == 1)[0]
	var foe: Cowboy = m.players.get_node(str(enemy))
	mate.brain = BotBrain.new(mate.name.to_int())
	_with_first(m, func() -> void:
		m.egg.carrier = 1
		me.take_damage(9999, foe)
		_ck(me.down and me.hp == 0 and not me.is_queued_for_deletion() and int(p.lives[1]) == 1 and t.downs == 1
			and is_equal_approx(me.bleed_left, Team.BLEED_SECONDS), "血歸零：倒地不是死，25 秒倒數")
		p._drop_orphan_egg()
		_ck(m.egg.carrier == 0, "倒地：手上的蛋掉下來")
		me.take_damage(50, foe)
		p._down_step(5.0)
		_ck(me.hp == 0 and is_equal_approx(me.bleed_left, Team.BLEED_SECONDS - 5.0), "倒地被打：血和倒數都不變（%.1f）" % me.bleed_left)
		_ck(not m._boss()._cowboys().has(me) and not mate._bot_ctx(m).mates.any(func(x: Dictionary) -> bool: return x.pos == me.global_position),
			"尼諾拉不選倒地的人（咬了沒用），電腦不把他當成在做事的隊友")
		me._crawl(Vector2(0, -1), 0.5)
		var v := Vector2(me.velocity.x, me.velocity.z).length()
		_ck(v > 0.0 and v <= Team.CRAWL_SPEED + 0.01, "倒地只能慢慢爬（%.2f 公尺／秒）" % v)
		# 救：敵人不行、太遠不行、隊友 2 公尺內按住 5 秒
		foe.global_position = me.global_position + Vector3(1, 0, 0)
		_ck(not m.hold.start(enemy, &"revive", me), "敵人不能救")
		mate.global_position = me.global_position + Vector3(5, 0, 0)
		_ck(not m.hold.start(mate.name.to_int(), &"revive", me), "太遠救不到")
		mate.global_position = me.global_position + Vector3(1.5, 0, 0)
		_ck(m.hold.start(mate.name.to_int(), &"revive", me), "隊友 2 公尺內開始救")
		mate2.global_position = me.global_position + Vector3(0, 0, 1)
		_ck(not m.hold.start(mate2.name.to_int(), &"revive", me), "同時只能一個人救")
		p._down_step(3.0)
		_ck(is_equal_approx(me.bleed_left, Team.BLEED_SECONDS - 5.0) and is_equal_approx(me.down_paused, 3.0), "有人在救：倒數暫停")
		m.hold._physics_process(Team.REVIVE_SECONDS - 0.1)
		m.hold.stop(mate.name.to_int())
		_ck(me.down, "救到 4.9 秒放開：還倒著")
		m.hold.start(mate.name.to_int(), &"revive", me)
		m.hold._physics_process(Team.REVIVE_SECONDS + 0.1)
		_ck(not me.down and me.hp == Team.REVIVE_HP and t.revives == 1, "按滿 5 秒：站起來，半血（%d）" % me.hp)
		me.take_damage(10, foe)
		_ck(me.hp == Team.REVIVE_HP, "剛救起來 1 秒打不動")
		# 救的時候倒數最多停 10 秒
		me._guard_ms = 0
		me.take_damage(9999, foe)
		_ck(me.down and is_equal_approx(me.bleed_left, Team.BLEED_SECONDS), "再倒地：還是 25 秒")
		m.hold.start(mate.name.to_int(), &"revive", me)
		for i in 12:
			p._down_step(1.0)
		_ck(is_equal_approx(me.bleed_left, Team.BLEED_SECONDS - 2.0), "救的時候倒數最多停 10 秒（%.1f）" % me.bleed_left)
		m.hold.stop(mate.name.to_int())
		# 電腦：隊友倒地會去救；自己倒地往隊友爬
		var ctx := mate._bot_ctx(m)
		_ck(ctx.revive != null and mate.brain.score_all(ctx).has("救人"), "電腦看到倒地的隊友：有「救人」可選")
		mate.brain.think(ctx)
		mate.brain.action = "救人"
		mate.brain.last_ctx = ctx
		mate._bot_loot(m)
		_ck(m.hold.doing(mate.name.to_int()) == &"revive", "電腦走到旁邊：按住救人")
		m.hold.stop(mate.name.to_int())
		mate2.global_position = me.global_position + Vector3(20, 0, 0)
		mate.global_position = mate2.global_position + Vector3(0, 0, 30)
		mate2._guard_ms = 0
		mate2.take_damage(9999, foe)
		mate2.brain = BotBrain.new(mate2.name.to_int())
		mate2._bot_crawl(m, 0.5)
		_ck(mate2.velocity.z > 0.0 and absf(mate2.velocity.x) < 0.01, "電腦倒地：往最近的站著的隊友爬（倒地的不算）（%s）" % mate2.velocity)
		# 斷線：原地倒地，不收
		_ck(p.down_on_leave(mate) and mate.down and not mate.is_queued_for_deletion(), "團隊模式斷線：原地倒地，不收掉")
		# 倒數完：出局，留屍體，不重生
		p._down_step(Team.BLEED_SECONDS + 1.0))
	_ck(me.is_queued_for_deletion() and int(p.lives[1]) == 0 and not p._waiting.has(1) and m._is_out(1) and p.phase == &"play",
		"倒數完沒人救：出局、不重生，比賽繼續")
	_end(m)
