extends SceneTree
## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

var _fails := 0
var _shell_target: Node
var _dino: Node
var _jump_from := 0.0
var _phase := 0
var _dummy_game: Node
var _dummy_tank: Node3D
var _dummy_from := Vector2.ZERO
var _dummy_frames := 0
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
		_case_offline_dino()
		_case_gun_pitch()
		_case_throttle()
		_case_back_to_lobby()
		_case_cover()
		_case_trex_rig()
		_case_stamina()
		_case_arena_walls()
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
				_start_dummy_case()
			elif _frames > 900:
				_ck(false, "跳躍沒離地（只上升 %.1f 公尺）"
					% (_dino.global_position.y - _jump_from))
				_start_dummy_case()
		3:  # 移動靶要真的跑起來（move_and_slide 只在物理幀有效，所以得跨幀等）
			_dummy_frames += 1
			var now := _dummy_tank.global_position
			if _dummy_from.distance_to(Vector2(now.x, now.z)) > 3.0:
				_end(_dummy_game)
				return _done()
			if _dummy_frames > 500:
				_ck(false, "坦克靶沒有自己跑起來")
				_end(_dummy_game)
				return _done()
	return false

func _done() -> bool:
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、勝負、咬擊方向、離線兩種模式、砲管俯仰與轉速上限、油門手感、回大廳重開、建築擋視線、圍牆擋出界、暴龍骨架與尾巴慣性、砲彈命中、恐龍跳躍、移動靶、體力規則都正常")
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
	var target: Node = m.players.get_node(^"2")
	_ck(m.players.get_child_count() == 2, "離線應該有一台坦克 + 一隻靶")
	_ck(tank.is_multiplayer_authority(), "離線時自己那台坦克要操控得動")
	_ck(target.dummy and not tank.dummy, "恐龍是會自己跑的靶，坦克不是")
	target.take_damage(9999)
	_ck(m._over and m.status.text.begins_with("坦克獲勝"), "打爆靶子 -> 坦克贏")
	_end(m)

## 離線當恐龍：自己控恐龍，三台坦克靶會自己跑
func _case_offline_dino() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_offline_dino_pressed()
	var me: Node = m.players.get_node(^"1")
	_ck(m.players.get_child_count() == 4, "應該是一隻恐龍 + 三台坦克靶")
	_ck(me.is_in_group(&"dino") and me.is_multiplayer_authority(), "自己是恐龍而且操控得動")
	_ck(not me.dummy, "自己那隻不能是靶")
	_ck(m._tanks == 3, "三台坦克都要算進勝負")
	for i in 3:
		_ck(m.players.get_node(str(2 + i)).dummy, "第 %d 台坦克要是會自己跑的靶" % (i + 1))
	# 「靶真的會自己跑」要跨物理幀才驗得到，見最後的 _phase 3

	for i in 3:
		m.players.get_node(str(2 + i)).take_damage(9999)
	_ck(m._over and m.status.text.begins_with("恐龍獲勝"), "打爆三台靶 -> 恐龍贏")
	_end(m)

## 砲管上下角度要夾在俯 8 度 ~ 仰 20 度之間，而且不能瞬間跟上滑鼠
func _case_gun_pitch() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"1")
	var dt := 1.0 / 120.0

	t.aim(Vector2(0, -9999))  # 滑鼠一路往上
	_ck(is_equal_approx(t.aim_pitch, t.PITCH_MAX), "抬到底要停在仰角上限")
	t.aim(Vector2(0, 9999))   # 一路往下
	_ck(is_equal_approx(t.aim_pitch, t.PITCH_MIN), "壓到底要停在俯角下限")

	# 砲管不能瞬間貼上去：一幀最多轉 ELEVATE * delta
	t.aim_pitch = t.PITCH_MAX
	t.gun_pitch = 0.0
	t._physics_process(dt)
	_ck(t.gun_pitch <= t.ELEVATE * dt + 0.0001 and t.gun_pitch > 0.0,
		"砲管一幀最多抬 %.4f 弧度（實際 %.4f）" % [t.ELEVATE * dt, t.gun_pitch])

	# 給它足夠時間就要追到
	for i in 200:
		t._physics_process(dt)
	_ck(is_equal_approx(t.gun_pitch, t.PITCH_MAX), "轉夠久要追上目標角度")
	_ck(is_equal_approx(t.gun.rotation.x, t.gun_pitch), "砲管模型要跟著轉")

	# 砲塔左右也一樣有轉速上限
	t.aim_yaw = 3.0
	t.turret_yaw = 0.0
	t._physics_process(dt)
	_ck(t.turret_yaw <= t.TRAVERSE * dt + 0.0001 and t.turret_yaw > 0.0,
		"砲塔一幀最多轉 %.4f 弧度（實際 %.4f）" % [t.TRAVERSE * dt, t.turret_yaw])
	_end(m)

## 移動要有加速度：不會瞬間全速，也不會瞬間停住；倒車比前進慢
func _case_throttle() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"1")
	var dt := 1.0 / 120.0
	var full := Vector3(0, 0, -t.SPEED)

	t.velocity = Vector3.ZERO
	t._accelerate(full, t.ACCEL, t.BRAKE, dt)
	_ck(absf(t.velocity.z) < t.SPEED * 0.5, "踩下去不能瞬間全速（現在 %.2f / %.1f）"
		% [absf(t.velocity.z), t.SPEED])

	var secs := 0.0
	while absf(t.velocity.z) < t.SPEED - 0.01 and secs < 10.0:
		t._accelerate(full, t.ACCEL, t.BRAKE, dt)
		secs += dt
	_ck(secs > 0.3 and secs < 3.0, "加速到全速該花 1 秒上下（實際 %.2f 秒）" % secs)

	# 放開按鍵要煞得比加速快
	var stop := 0.0
	while absf(t.velocity.z) > 0.01 and stop < 10.0:
		t._accelerate(Vector3.ZERO, t.ACCEL, t.BRAKE, dt)
		stop += dt
	_ck(stop < secs, "煞車要比加速快（煞 %.2f 秒 vs 加速 %.2f 秒）" % [stop, secs])
	_ck(t.REVERSE < 1.0, "倒車要比前進慢")
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

## 暴龍骨架：骨頭要建得起來，跑起來兩隻腳要反相擺動
func _case_trex_rig() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"2").get_node(^"Trex")
	_ck(t.skel.get_bone_count() == 18, "骨架應該有 18 根骨頭（現在 %d）" % t.skel.get_bone_count())
	_ck(t.skel.find_bone("jaw") >= 0 and t.skel.find_bone("tail4") >= 0, "下巴和尾巴末端要在")

	for i in 6:  # 假裝以 18 m/s 在跑
		t._last_pos = t.global_position + Vector3(0, 0, 0.3)
		t._process(1.0 / 60.0)
	var l: float = t.skel.get_bone_pose_rotation(t._idx["thigh_l"]).get_euler().x
	var r: float = t.skel.get_bone_pose_rotation(t._idx["thigh_r"]).get_euler().x
	_ck(absf(l) > 0.1 and l * r < 0.0, "跑步時兩隻大腿要反相擺動（左 %.2f 右 %.2f）" % [l, r])

	var closed: float = t.skel.get_bone_pose_rotation(t._idx["jaw"]).get_euler().x
	t.bite()
	var opened := closed
	for i in 20:
		t._process(1.0 / 60.0)
		opened = minf(opened, t.skel.get_bone_pose_rotation(t._idx["jaw"]).get_euler().x)
	_ck(rad_to_deg(absf(opened - closed)) > 25.0,
		"咬的時候嘴要張開超過 25 度（現在 %.0f）" % rad_to_deg(absf(opened - closed)))

	# 旋轉延遲傳遞：轉身時尾巴根先動、尖跟不上，停下後會反向甩再收斂
	var d: Node3D = m.players.get_node(^"2")
	for i in 30:
		d.rotate_y(0.09)
		t._process(1.0 / 120.0)
	_ck(absf(t._tail_yaw[0]) > absf(t._tail_yaw[3]) * 3.0,
		"轉身當下尾巴尖要明顯落後根部（根 %.3f 尖 %.3f）" % [t._tail_yaw[0], t._tail_yaw[3]])
	var sign_at_turn: float = signf(t._tail_yaw[0])
	var overshoot := 0.0
	for i in 800:  # 停止轉身；四節的鏈子要晃約 6 秒才完全停下來
		t._process(1.0 / 120.0)
		overshoot = maxf(overshoot, -sign_at_turn * t._tail_yaw[3])
	_ck(overshoot > 0.05, "停止轉身後尾尖要反向甩過頭（過衝 %.3f）" % overshoot)
	_ck(absf(t._tail_yaw[3]) < 0.05, "最後要收斂回中間，不能一直晃（現在 %.3f）" % t._tail_yaw[3])
	_end(m)

## 體力：耗光會力竭，要回到門檻以上才能再衝刺／攀爬
func _case_stamina() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	_ck(d.stamina == d.STAMINA_MAX and d.can_exert(), "一開始滿體力，衝得動")

	# 一直衝，看幾秒耗光
	var secs := 0.0
	while d.stamina > 0.0 and secs < 20.0:
		d._update_stamina(1.0 / 120.0, d.SPRINT_DRAIN, true)
		secs += 1.0 / 120.0
	_ck(secs > 2.0 and secs < 4.5, "全滿應該衝得了 3 秒左右（實際 %.1f 秒）" % secs)
	_ck(not d.can_exert(), "體力歸零 -> 力竭，不能再衝刺")

	# 回一點點還是不行，這是防止在 0 附近抽動
	for i in 120:
		d._update_stamina(1.0 / 120.0, 0.0, true)
	_ck(d.stamina > 0.0 and d.stamina < d.EXHAUSTED_UNTIL, "回復中但還沒到門檻")
	_ck(not d.can_exert(), "沒回到門檻之前不能衝刺")

	# 回到門檻以上才解除
	while d.stamina < d.EXHAUSTED_UNTIL:
		d._update_stamina(1.0 / 120.0, 0.0, false)
	_ck(d.can_exert(), "回到門檻以上才能再出力")

	# 站著回得比走著快
	var a: Node = m.players.get_node(^"1")
	a.stamina = 50.0
	for i in 120:
		a._update_stamina(1.0 / 120.0, 0.0, false)
	var still_gain: float = a.stamina - 50.0
	a.stamina = 50.0
	for i in 120:
		a._update_stamina(1.0 / 120.0, 0.0, true)
	var moving_gain: float = a.stamina - 50.0
	_ck(still_gain > moving_gain * 1.5,
		"站著回得該比走著快很多（站 %.1f vs 走 %.1f）" % [still_gain, moving_gain])
	_end(m)

## 場地四周要有牆，而且要高過恐龍「跳 + 爬」能到的高度
func _case_arena_walls() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	# 圍牆不給爬，所以恐龍能到的最高點 = 站上最高的屋頂再跳一下
	var jump_h: float = d.JUMP_SPEED * d.JUMP_SPEED / (2.0 * d.GRAVITY)
	var reach: float = m.BUILDING_MAX_H + jump_h
	_ck(m.WALL_H > reach,
		"圍牆 %.0f 公尺要高過「最高屋頂 %.0f + 跳 %.1f」= %.1f 公尺"
		% [m.WALL_H, m.BUILDING_MAX_H, jump_h, reach])

	# 建築不能蓋超過上限，不然上面那條就白算了
	var tallest := 0.0
	for c in m.get_node(^"Arena").get_children():
		if c.is_in_group(&"arena_wall"):
			continue
		for mi in c.get_children():
			if mi is MeshInstance3D:
				tallest = maxf(tallest, mi.get_aabb().size.y)
	_ck(tallest <= m.BUILDING_MAX_H + 0.01,
		"最高的建築 %.1f 不能超過上限 %.0f" % [tallest, m.BUILDING_MAX_H])

	var walls := m.get_tree().get_nodes_in_group(&"arena_wall")
	_ck(walls.size() == 4, "四面都要有圍牆（現在 %d 面）" % walls.size())
	_end(m)

## 開一局「我當恐龍」，等下面的 _phase 3 看坦克靶會不會自己跑
func _start_dummy_case() -> void:
	_phase = 3
	_dummy_game = load("res://main.tscn").instantiate()
	root.add_child(_dummy_game)
	_dummy_game._on_offline_dino_pressed()
	_dummy_tank = _dummy_game.players.get_node(^"2")
	_dummy_from = Vector2(_dummy_tank.global_position.x, _dummy_tank.global_position.z)

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
