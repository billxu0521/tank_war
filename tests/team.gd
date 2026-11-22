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
