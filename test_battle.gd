extends SceneTree
## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

var _fails := 0
var _shell_target: Node
var _dino: Node
var _jump_from := 0.0
var _phase := 0
var _frames := 0

func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_case_dino_wins()
		_case_tanks_win()
		_case_attacks()
		_case_offline()
		_case_gun_pitch()
		_case_back_to_lobby()
		_case_cover()
		_start_shell_case()
		return false
	# 剩下的要跨好幾個 frame 才驗得到
	match _phase:
		0:  # 等砲彈飛過去打中坦克
			if _shell_target.hp < _shell_target.max_hp:
				_phase = 1
			elif _frames > 200:
				_ck(false, "砲彈沒打中坦克")
				_phase = 1
		1:  # 等恐龍落地才跳得起來
			if _dino.is_on_floor():
				_jump_from = _dino.global_position.y
				_ck(_dino.try_jump(), "站在地上、體力滿應該跳得起來")
				_phase = 2
			elif _frames > 600:
				_ck(false, "恐龍一直沒落地")
				return _done()
		2:  # 確認真的離地
			if _dino.global_position.y - _jump_from > 3.0:
				return _done()
			if _frames > 900:
				_ck(false, "跳躍沒離地（只上升 %.1f 公尺）"
					% (_dino.global_position.y - _jump_from))
				return _done()
	return false

func _done() -> bool:
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、勝負、咬擊方向、離線模式、砲管俯仰、回大廳重開、建築擋視線、砲彈命中、恐龍跳躍都正常")
	return true

# --- 共用 ---

func _new_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()  # 主機 = 恐龍（編號 1）
	m._spawn(2)
	m._spawn(3)
	_ck(m._tanks == 2, "應該有兩台坦克")
	_ck(m.players.get_node(^"1").hp == m.players.get_node(^"1").max_hp, "恐龍滿血出生")
	_ck(m.players.get_node(^"2").hp == m.players.get_node(^"2").max_hp, "坦克滿血出生")
	return m

func _new_offline_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_offline_pressed()  # 離線模式：編號 1 是自己的坦克
	return m

func _end(m: Node) -> void:
	if m.multiplayer.multiplayer_peer != null:
		m.multiplayer.multiplayer_peer.close()
		m.multiplayer.multiplayer_peer = null
	root.remove_child(m)
	m.free()

# --- 案例 ---

func _case_dino_wins() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var t2: Node = m.players.get_node(^"2")
	var bites := ceili(float(t2.max_hp) / d.BITE_DAMAGE)
	_ck(bites == 4, "平衡目標：咬四口才死一台坦克（現在是 %d 口）" % bites)

	for i in bites - 1:
		t2.take_damage(d.BITE_DAMAGE)
	_ck(t2.hp > 0 and m._tanks == 2, "還差一口不該死")
	t2.take_damage(d.BITE_DAMAGE)
	_ck(m._tanks == 1 and not m._over, "死一台，還有一台")

	m.players.get_node(^"3").take_damage(9999)
	_ck(m._over and m.status.text.begins_with("恐龍獲勝"), "坦克全滅 -> 恐龍贏")
	_end(m)

func _case_tanks_win() -> void:
	var m := _new_game()
	var dino: Node = m.players.get_node(^"1")
	var shells := ceili(float(dino.max_hp) / Shell.DAMAGE)
	_ck(shells >= 20 and shells <= 30, "平衡目標：全隊打 20~30 發打死恐龍（現在 %d 發）" % shells)

	for i in shells - 1:
		dino.take_damage(Shell.DAMAGE)
	_ck(not m._over, "還差一發不該結束")
	dino.take_damage(Shell.DAMAGE)
	_ck(m._over and m.status.text.begins_with("坦克獲勝"), "恐龍死 -> 坦克贏")
	_end(m)

## 咬只打前方，背後咬不到
func _case_attacks() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var front: Node = m.players.get_node(^"2")
	var back: Node = m.players.get_node(^"3")
	var spot: Vector3 = m._spawn_point()  # 找一個沒有建築的空地，不然會被視線判定擋掉
	spot.y = 2.0
	d.global_position = spot      # 面向 -Z
	front.global_position = spot + Vector3(0, 0, -4)
	back.global_position = spot + Vector3(0, 0, 4)

	var full: int = front.max_hp
	d._hit_nearby(d.BITE_REACH, d.BITE_DAMAGE, 0.3)
	_ck(front.hp == full - d.BITE_DAMAGE, "咬應該打到前面的坦克")
	_ck(back.hp == full, "咬不該打到後面的坦克")

	# 轉身面向後面那台，就換它挨咬
	d.look_at(back.global_position)
	d._hit_nearby(d.BITE_REACH, d.BITE_DAMAGE, 0.3)
	_ck(back.hp == full - d.BITE_DAMAGE, "轉身後應該咬得到原本在背後的坦克")
	_end(m)

## 離線 debug 模式：不連線也要能打、能判勝負
func _case_offline() -> void:
	var m := _new_offline_game()
	var tank: Node = m.players.get_node(^"1")
	_ck(m.players.get_child_count() == 2, "離線應該有一台坦克 + 一隻靶")
	_ck(tank.is_multiplayer_authority(), "離線時自己那台坦克要操控得動")
	_ck(m.players.get_node(^"2").global_position.z == -8.0, "靶要放在固定位置")
	m.players.get_node(^"2").take_damage(9999)
	_ck(m._over and m.status.text.begins_with("坦克獲勝"), "打爆靶子 -> 坦克贏")
	_end(m)

## 砲管上下角度要夾在俯 8 度 ~ 仰 20 度之間
func _case_gun_pitch() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"1")

	t.aim(Vector2(0, -9999))  # 滑鼠一路往上
	_ck(is_equal_approx(t.gun_pitch, t.PITCH_MAX), "抬到底要停在仰角上限")
	t.aim(Vector2(0, 9999))   # 一路往下
	_ck(is_equal_approx(t.gun_pitch, t.PITCH_MIN), "壓到底要停在俯角下限")

	t.gun_pitch = 0.2
	t._physics_process(0.016)
	_ck(is_equal_approx(t.gun.rotation.x, 0.2), "砲管模型要跟著轉")
	_end(m)

## 回大廳要清乾淨，而且要能馬上重開一局
func _case_back_to_lobby() -> void:
	var m := _new_game()
	m._to_lobby("")
	_ck(m.players.get_child_count() == 0, "回大廳要把玩家清掉")
	_ck(m.multiplayer.multiplayer_peer == null, "回大廳要斷線")
	_ck(m.lobby.visible and not m.menu.visible, "回大廳要看得到大廳、選單要關掉")
	_ck(m._tanks == 0 and not m._over, "計數和勝負狀態要歸零")

	m._on_host_pressed()  # 連接埠要放掉了，才開得起第二局
	m._spawn(2)
	_ck(m.players.get_child_count() == 2 and m._tanks == 1, "要能馬上重開一局")
	_end(m)

## 中間隔著建築物，恐龍就咬不到——坦克躲掩蔽的依據
func _case_cover() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var t: Node = m.players.get_node(^"2")
	m.players.get_node(^"3").global_position = Vector3(0, 500, 0)  # 閃遠一點別干擾

	var b: Rect2 = m._blocked[0]        # 第一棟建築（含 8 公尺出生淨空）在 XZ 的範圍
	var c := b.get_center()
	var d_side := b.size.y * 0.5 + 2.0  # Rect2 的 size.y 是 Z 方向
	d.global_position = Vector3(c.x, 2.0, c.y + d_side)
	d.look_at(Vector3(c.x, 2.0, c.y - d_side))  # 面向建築

	# 對照組：同一側，中間沒東西擋（射程放大到 100，只想單獨測視線）
	t.global_position = d.global_position + Vector3(0, 0, -3)
	d._hit_nearby(100.0, d.BITE_DAMAGE, 0.3)
	_ck(t.hp == t.max_hp - d.BITE_DAMAGE, "沒遮蔽時應該打得到")

	# 實驗組：躲到建築後面
	t.global_position = Vector3(c.x, 2.0, c.y - d_side)
	var before: int = t.hp
	d._hit_nearby(100.0, d.BITE_DAMAGE, 0.3)
	_ck(t.hp == before, "躲在建築後面就不該被打到")
	_end(m)

## 砲彈要真的飛過去打中人（跨好幾個 frame）
func _start_shell_case() -> void:
	var m := _new_game()
	var spot: Vector3 = m._spawn_point()  # 挑淨空點，不然彈道會先撞到建築
	spot.y = 1.0
	_dino = m.players.get_node(^"1")
	_dino.global_position = m._spawn_point()  # 另外一點，等它落地測跳躍
	_shell_target = m.players.get_node(^"2")
	_shell_target.global_position = spot
	var shooter: Node = m.players.get_node(^"3")
	shooter.global_position = spot + Vector3(200, 0, 0)  # 射手閃開，別擋在彈道上
	shooter._fire(spot + Vector3(0, 0.5, 6), Vector3(0, 0, -1))
