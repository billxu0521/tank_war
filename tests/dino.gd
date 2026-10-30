extends "res://tests/combat.gd"
## 恐龍：boss、暴龍骨架、體力、衝刺、死亡、攻擊開關、蛋、派對 boss

func _case_dino_death() -> void:
	var m := _new_game()
	var dino: Node = m.players.get_node(^"1")
	# 左輪的持續輸出 = 一輪的傷害 / (打完一輪 + 逐發換彈)
	var gun: Node = m.players.get_node(^"2").viewmodel._weapons[0]
	var cycle: float = gun.capacity * (gun.fire_interval + gun.reload_insert)
	var dps: float = gun.capacity * gun.damage / cycle
	var secs: float = dino.max_hp / (3.0 * dps)
	_ck(secs > 8.0 and secs < 20.0, "平衡目標：3 個牛仔用左輪 8~20 秒打死恐龍（現在 %.1f 秒）" % secs)

	dino.take_damage(dino.max_hp)
	# 牛仔互為對手，所以打死恐龍不是勝利條件，回合要繼續，恐龍會重生
	_ck(not m._over, "恐龍陣亡不該直接結束回合")
	_ck(m._respawn_queue.size() == 1 and bool(m._respawn_queue[0]["dino"]),
		"恐龍要排進重生佇列——牠不重生的話後半場變成無人阻擋的賽跑")
	_ck(m._cowboys == 2, "牛仔數不受影響")
	_end(m)

## 派對模式的尼諾拉：打不死，倒地 15 秒原地起身，起身後 3 秒無敵；玩家操作的倒地時不能動、不能出招
func _case_party_boss() -> void:
	var m := _offline_match()
	m.rules = &"party"
	var b: Node3D = m.spawn_boss()
	b.global_position = m._on_ground(Vector3(0, 4.2, 40))
	b.pilot = 1
	var got := []
	b.knocked_down.connect(func() -> void: got.append(&"down"))
	b.got_up.connect(func() -> void: got.append(&"up"))
	b.take_damage(b.max_hp + 100)
	b._process(DT)
	_ck(b.downed and b.down_left == b.PARTY_KNOCK_TIME and b.hp == b.max_hp and got == [&"down"],
		"派對模式血打光：倒地 %.0f 秒、血補滿、發 knocked_down（%s）" % [b.down_left, got])
	var at: Vector3 = b.global_position
	for i in int((b.PARTY_KNOCK_TIME - 0.1) * 60):
		b.pilot_input(Vector2(0, -1), 0.0, 0.0, b.PIN_RUN | b.PIN_BITE)
		b.think(1.0 / 60.0)
	_ck(b.downed and b.act == b.ACT_NONE and Vector2(b.velocity.x, b.velocity.z).length() < 0.5, "倒地時玩家操作的尼諾拉不能動、不能出招（act=%d 速度 %s）" % [b.act, b.velocity])
	for i in 12:
		b.think(1.0 / 60.0)
	b._process(DT)
	_ck(not b.downed and b.invulnerable and got == [&"down", &"up"] and b.global_position.distance_to(at) < 0.5,
		"15 秒後原地起身、發 got_up、進入無敵（%s）" % [got])
	b.take_damage(100)
	_ck(b.hp == b.max_hp, "起身後無敵期間不扣血")
	for i in int(b.GET_UP_GUARD * 60) + 2:
		b.think(1.0 / 60.0)
	b._process(DT)
	_ck(not b.invulnerable and b.get_node(^"Trex").visible, "%.0f 秒後無敵結束、不再閃" % b.GET_UP_GUARD)
	b.take_damage(100)
	_ck(b.hp == b.max_hp - 100, "無敵結束後會扣血（%d）" % b.hp)
	_end(m)

## 恐龍 boss：視力差、聽力好、跟蛋無關、導演只給大概方向、追太久會退開、三招都有預備動作、自己的體力、打不死
func _case_boss() -> void:
	var m := _offline_match()
	var c: Node3D = m._add_player(m.COWBOY, 2)
	var other: Node3D = m._add_player(m.COWBOY, 3)
	other.global_position = Vector3(0, 500, 0)
	var b: Node3D = m.spawn_boss()
	_ck(b != null and b.is_in_group(&"boss"), "要生得出恐龍 boss")
	_ck(m.spawn_boss() == null, "boss 場上最多一隻")
	_ck(b.WALK < c.walk_speed and b.RUN > c.sprint_speed,
		"boss 走路要比牛仔慢（%.1f vs %.1f）、跑步要比牛仔快（%.1f vs %.1f）" % [b.WALK, c.walk_speed, b.RUN, c.sprint_speed])
	_ck(is_instance_valid(m._nav_region), "生 boss 要順便烘導航網格")
	_ck(m._match_hud.BOSS_ACTS.size() == b.ACT_SPOT + 1, "每個動作狀態都要有除錯名稱（BOSS_ACTS 有 %d 個）" % m._match_hud.BOSS_ACTS.size())
	# 視力：放在沙盒靶場那條路上（整平、沒蓋東西，視線不會被擋）
	b.global_position = m._on_ground(Vector3(0, 4.2, 40))
	b.rotation.y = 0.0   # 面向 -Z
	c.global_position = m._on_ground(Vector3(0, 0.1, 10))
	_ck(not b.can_see(c), "視力差：正前方 30 公尺看不到")
	c.global_position = m._on_ground(Vector3(0, 0.1, 28))
	_ck(b.can_see(c), "正前方 12 公尺要看得到")
	c.set(&"sync_crouching", true)
	_ck(not b.can_see(c), "蹲著的人 12 公尺看不到")
	c.set(&"sync_crouching", false)
	c.global_position = m._on_ground(Vector3(0, 0.1, 52))
	_ck(not b.can_see(c), "背後 12 公尺看不到")
	c.global_position = m._on_ground(Vector3(0, 0.1, 43))
	_ck(b.can_see(c), "背後 3 公尺（太近）也會發現")
	# 聽力：遠處的槍聲聽得到；放鬆的時候只理近的
	c.global_position = Vector3(0, 500, 0)
	b.hear(m._on_ground(Vector3(60, 1, -60)))
	_ck(b._noise_left > 0.0, "100 公尺外的槍聲要聽得到")
	b._noise_left = 0.0
	b.director.phase = Director.Phase.RELAX
	b.hear(m._on_ground(Vector3(60, 1, -60)))
	_ck(b._noise_left == 0.0, "放鬆的時候遠處的槍聲不理")
	b.director.phase = Director.Phase.BUILD
	# 聲音只聽得出大概在哪：遠的偏得多（但有上限），近的偏得少
	var far_shot: Vector3 = m._on_ground(Vector3(60, 1, -60))
	var max_off := 0.0
	for i in 30:
		b.hear(far_shot)
		max_off = maxf(max_off, Vector2(b._noise.x - far_shot.x, b._noise.z - far_shot.z).length())
	_ck(max_off > 3.0 and max_off <= b.NOISE_FUZZ_MAX + 1.0, "遠處槍聲的位置要有偏差、但不超過上限（最大偏 %.1f）" % max_off)
	var near_shot := b.global_position + Vector3(0, 0, -15)
	max_off = 0.0
	for i in 30:
		b._heard(near_shot)
		max_off = maxf(max_off, Vector2(b._noise.x - near_shot.x, b._noise.z - near_shot.z).length())
	_ck(max_off < 2.5, "15 公尺內的聲音要聽得滿準（最大偏 %.1f）" % max_off)
	b._noise_left = 0.0
	# 看到不等於確定：先停下來盯著，確定了吼一聲，吼完才追
	c.global_position = m._on_ground(Vector3(0, 0.1, 26))   # 正前方 14 公尺
	b.think(1.0 / 60.0)
	_ck(b._sees_now == null and b._glimpse == c and b.mood == b.MOOD_SEARCH, "剛瞄到人還不能確定、要先盯著（心情要是「找」）")
	var spot_frames := 0
	while b.act != b.ACT_SPOT and spot_frames < 120:
		b.think(1.0 / 60.0)
		spot_frames += 1
	_ck(spot_frames > 20 and b.act == b.ACT_SPOT, "盯一下才確定、確定了要吼一聲（%d 幀）" % spot_frames)
	_ck(b.mood == b.MOOD_HUNT, "確定之後心情要是「追」")
	for i in int(b.SPOT_TIME * 60) + 2:
		b.think(1.0 / 60.0)
	_ck(b.act != b.ACT_SPOT and b._sees_now == c, "吼完要開始追或出招（現在 act=%d）" % b.act)
	b.act = b.ACT_NONE
	# 還沒確定就躲起來：去他剛才在的地方找
	b._seen_left = 0.0
	b._suspect = 0.0
	b._sees_now = null
	b.think(1.0 / 60.0)
	for i in 30:
		b.think(1.0 / 60.0)
	var was_at: Vector3 = c.global_position
	c.global_position = Vector3(0, 500, 0)
	b.think(1.0 / 60.0)
	_ck(b._noise_left > 0.0 and b._noise.distance_to(was_at) < 0.5, "還沒確定人就躲了，要去他剛才在的地方找")
	b._noise_left = 0.0
	b._hint = Vector3.INF
	# 跟蛋無關：有人拿著蛋也不會知道他在哪
	m.egg.carrier = 3
	other.global_position = m._on_ground(Vector3(15, 0.1, -20))
	b.think(1.0 / 60.0)
	_ck(b._target != other, "有人拿蛋恐龍也不知道他在哪（不再追持蛋者）")
	m.egg.carrier = 0
	other.global_position = Vector3(0, 500, 0)
	# 導演：閒著太久給一個大概方向，不是那個人的位置
	var rng := RandomNumberGenerator.new()
	var hint: Vector3 = b.director.hint_for(c, rng)
	var off := Vector2(hint.x - c.global_position.x, hint.z - c.global_position.z).length()
	_ck(off >= Director.HINT_FUZZ.x - 0.01 and off <= Director.HINT_FUZZ.y + 0.01, "提示點要離那個人 12~20 公尺（現在 %.1f）" % off)
	var d := Director.new()
	var got := Vector3.INF
	for i in int(Director.HINT_IDLE * 60) + 2:
		var h := d.step(1.0 / 60.0, null, false, [c], rng)
		if h != Vector3.INF:
			got = h
	_ck(got != Vector3.INF, "恐龍閒著 %d 秒，導演要給一次方向" % Director.HINT_IDLE)
	# 威脅滿了就退開，退完放鬆，放鬆完回到醞釀
	d = Director.new()
	for i in int(Director.MENACE_MAX / Director.MENACE_SEE * 60) + 5:
		d.step(1.0 / 60.0, c, false, [c], rng)
	_ck(d.phase == Director.Phase.RETREAT, "一直看到人，威脅滿了要退開")
	b.director = d
	_ck(b._mood() == b.MOOD_RETREAT, "退開時心情要是「退開」（姿勢跟追分得開），現在 %d" % b._mood())
	for i in int((Director.RETREAT_TIME + Director.RELAX_TIME) * 60) + 5:
		d.step(1.0 / 60.0, c, false, [c], rng)
	_ck(d.phase == Director.Phase.BUILD and d.menace < 5.0, "退開、放鬆完回到醞釀，威脅從頭累積")
	# 咬：有預備動作，預備時不扣血，時間到才咬下去
	b.director = Director.new()
	b.global_position = m._on_ground(Vector3(0, 4.2, 40))
	b.rotation.y = 0.0
	c.global_position = m._on_ground(Vector3(0, 0.1, 34))   # 嘴巴正前方
	var hp0: int = c.hp
	b._attack_gap = 0.0
	b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_BITE_WIND, "嘴邊有人要先預備（現在 act=%d）" % b.act)
	for i in int(b.BITE_WIND * 60) - 3:
		b.think(1.0 / 60.0)
	_ck(c.hp == hp0, "預備動作時還不能扣血")
	for i in 6:
		b.think(1.0 / 60.0)
	_ck(c.hp == hp0 - b.BITE_DAMAGE, "預備完要咬下去（%d → %d）" % [hp0, c.hp])
	# 預備時往旁邊閃開就咬不到
	c.hp = c.max_hp
	b.act = b.ACT_NONE
	b._attack_gap = 0.0
	b.think(1.0 / 60.0)
	c.global_position = m._on_ground(Vector3(9, 0.1, 34))
	for i in int(b.BITE_WIND * 60) + 3:
		b.think(1.0 / 60.0)
	_ck(c.hp == c.max_hp, "預備時往旁邊閃開要咬不到")
	# 蓄力甩尾：人在背後就蓄力；打中頭打斷，暈一陣子、不會掃出去
	b.act = b.ACT_NONE
	b._attack_gap = 0.0
	b.sweep_left = 0.0
	c.global_position = m._on_ground(Vector3(0, 0.1, 46))   # 背後 6 公尺
	b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_CHARGE_WIND, "人在背後要蓄力甩尾（現在 act=%d）" % b.act)
	b.head_hit()
	_ck(b.act == b.ACT_STUN, "蓄力時打中頭要打斷")
	for i in int(b.CHARGE_WIND * 60) + 3:
		b.think(1.0 / 60.0)
	_ck(c.hp == c.max_hp, "被打斷就不會掃出去")
	# 沒打斷就整圈掃開
	b.act = b.ACT_NONE
	b._attack_gap = 0.0
	b.sweep_left = 0.0
	b.think(1.0 / 60.0)
	for i in int(b.CHARGE_WIND * 60) + 3:
		b.think(1.0 / 60.0)
	_ck(c.hp == c.max_hp - b.SWEEP_DAMAGE, "蓄力完要掃到背後的人")
	# 自己的體力：一直跑會見底，見底只能走，回到一定量才能再跑
	c.global_position = Vector3(0, 500, 0)
	b.act = b.ACT_NONE
	for i in int(b.STAMINA_MAX / b.RUN_DRAIN * 60) + 60:   # 跑完滿體力再多一秒
		b._move(-b.global_basis.z, true, 1.0 / 60.0)
	_ck(b.exhausted and not b.running, "一直跑體力會見底，見底只能走")
	for i in 30:
		b._move(-b.global_basis.z, true, 1.0 / 60.0)
	_ck(not b.running, "剛見底回一點點還不能跑")
	# 打不死：血打光倒地、血補滿、起來先退開；倒地時打不動
	b.take_damage(b.max_hp + 100, c)
	_ck(is_instance_valid(b) and b.down_left > 0.0 and b.hp == b.max_hp, "boss 打不死：血打光要倒地、血補滿")
	_ck(b.director.phase == Director.Phase.RETREAT, "被打倒之後要退開")
	b.take_damage(100, c)
	_ck(b.hp == b.max_hp, "倒地時打不動")
	# 主機玩家動滑鼠，boss 的頭和身體不能跟著轉（boss 的 authority 也是主機）
	_ck(not b.takes_mouse(), "boss 不能吃主機的滑鼠（不然頭會跟著主機玩家轉）")
	_ck(not m.add_bot().takes_mouse(), "牛仔 bot 也不能吃主機的滑鼠")
	m.clear_bots()
	_ck(m.players.has_node(NodePath(str(m.BOSS_ID))), "清除 bot 不會把 boss 清掉")
	_end(m)

## 暴龍骨架：骨頭要建得起來，跑起來兩隻腳要反相擺動
func _case_trex_rig() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"2").get_node(^"Trex")
	_ck(t.skel.get_bone_count() >= 40, "精細骨架應該有 40 根以上骨頭（現在 %d）" % t.skel.get_bone_count())
	_ck(t.skel.find_bone("jaw") >= 0 and t.skel.find_bone("tail%d" % Trex.TAIL_N) >= 0, "下巴和尾巴末端要在")

	# 以 11 m/s（boss 跑步）跑 2.5 秒。腳是真的踩地走（trex.gd 的 _walk），從站著起跑第一步要一點時間。
	# 看兩腳交替：跑步一隻腳只踩四成時間，兩腳不會同時踩著；兩隻腳都要真的抬起來換過好幾步、大腿真的有在擺。
	# 以前用兩條大腿角度的相關係數，但踩地跑的大腿曲線不是 sin（擺得快、踩得慢），係數在 0 附近亂跳
	var body: Node3D = m.players.get_node(^"2")
	var both_down := 0
	var lifts := [0, 0]
	var was := [false, false]
	var lo := INF
	var hi := -INF
	for i in 150:   # 真的往前跑（腳踩在地上，身體不動的話踩著的腳也不會往後掃）
		body.global_position += -body.global_basis.z * (11.0 / 60.0)
		t._process(1.0 / 60.0)
		if i >= 30:
			if not t._swing[0] and not t._swing[1]:
				both_down += 1
			for k in 2:
				if t._swing[k] and not was[k]:
					lifts[k] += 1
				was[k] = t._swing[k]
			var a: float = t.pose_rot("thigh_l").get_euler().x
			lo = minf(lo, a)
			hi = maxf(hi, a)
	_ck(both_down == 0 and lifts[0] >= 2 and lifts[1] >= 2 and hi - lo > 0.2,   # 擺幅每次跑不太一樣（0.3～0.5），只確定真的有在擺
		"跑步時兩腳交替（兩腳同時踩著 %d 幀，應為 0；左右各抬 %d、%d 步；大腿擺幅 %.2f）" % [both_down, lifts[0], lifts[1], hi - lo])

	var closed: float = t.pose_rot("jaw").get_euler().x
	t.bite()
	var opened := closed
	for i in 20:
		t._process(1.0 / 60.0)
		opened = minf(opened, t.pose_rot("jaw").get_euler().x)
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

## 中彈晃一下：從左邊被打要往右倒、慢慢穩回來；頭被打中要甩頭
func _case_trex_flinch() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"2").get_node(^"Trex")
	for i in 120:
		t._process(1.0 / 60.0)
	var rest: float = t.pose_rot("spine1").get_euler().z   # 站在坡上會往低的那隻腳斜一點（身體跟著腳的高度），晃完回到這裡
	t.flinch(Vector3.RIGHT, 1.0, false)
	var most := 0.0
	for i in 20:
		t._process(1.0 / 60.0)
		most = minf(most, t.pose_rot("spine1").get_euler().z - rest)
	_ck(most < -0.05, "被往右推要往右倒（最多 %.3f，應為負）" % most)
	for i in 300:
		t._process(1.0 / 60.0)
	_ck(absf(t.pose_rot("spine1").get_euler().z - rest) < 0.02, "晃完要自己站穩（回到晃之前的角度）")
	var yaw0: float = t.pose_rot("head").get_euler().y
	t.flinch(Vector3.ZERO, 0.0, true)
	var swing := 0.0
	for i in 15:
		t._process(1.0 / 60.0)
		swing = maxf(swing, absf(t.pose_rot("head").get_euler().y - yaw0))
	_ck(swing > 0.2, "頭被打中要甩頭（甩了 %.2f）" % swing)
	_end(m)

## 側傾與位移延遲：往旁邊移動時身體要往內倒、慢半拍才跟上，頭要保持水平
func _case_trex_lean() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"2").get_node(^"Trex")
	var d: Node3D = m.players.get_node(^"2")
	# 放在整平的沙盒靶場路上：出生點是隨機的，落在坡上時兩腳高低差會吃掉側傾，偶爾只量到 -0.028（門檻 -0.03）
	d.global_position = m._on_ground(Vector3(0, 4.2, 40))
	d.reset_physics_interpolation()
	for i in 120:   # 先站穩，記下站著的側傾（坡上會往低的那隻腳斜一點，身體跟著腳的高度）
		t._last_pos = t.global_position
		t._process(1.0 / 60.0)
	var rest: float = t.pose_rot("spine1").get_euler().z

	var drag := 0.0
	for i in 40:  # 假裝以 10 m/s 往右（本地 +X）平移
		t._last_pos = t.global_position - d.global_basis.x * (10.0 / 60.0)
		t._process(1.0 / 60.0)
		drag = maxf(drag, absf(t.skel.position.x))   # 只有加速那幾幀才拖得到
	var roll: float = t.pose_rot("spine1").get_euler().z - rest
	_ck(roll < -0.03, "往右移動時軀幹要往右倒（現在 %.3f，應為負）" % roll)

	var head: float = t.pose_rot("head").get_euler().z
	_ck(head * roll < 0.0, "頭要反向轉回來保持水平（軀幹 %.3f 頭 %.3f）" % [roll, head])
	_ck(drag > 0.05, "起步那下身體要被拖著走，不是瞬間跟上（最大位移 %.3f）" % drag)

	for i in 600:  # 停下來，側傾要收斂回去
		t._last_pos = t.global_position
		t._process(1.0 / 60.0)
	# 停下來：側傾回到「坡度該有的斜」（兩腳高低差帶來的那一點，trex.gd 的 _foot_tilt），不是一直倒著
	_ck(absf(t._lean.x + t._foot_tilt * 0.5) < 0.03,
		"停下來側傾要收回去（剩 %.3f）" % (t._lean.x + t._foot_tilt * 0.5))
	_end(m)

## 體力：耗光會力竭，要回到門檻以上才能再衝刺／攀爬
func _case_stamina() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	_ck(d.stamina == d.STAMINA_MAX and d.can_exert(), "一開始滿體力，衝得動")

	# 一直爬，看幾秒耗光（衝刺已經改成技能制、不吃體力了）
	var secs := 0.0
	while d.stamina > 0.0 and secs < 30.0:
		d._update_stamina(1.0 / 120.0, d.CLIMB_DRAIN, true)
		secs += 1.0 / 120.0
	_ck(secs > 3.0 and secs < 8.0, "全滿應該爬得了 4 秒左右（實際 %.1f 秒）" % secs)
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

	# 回復速度已經統一，站著和移動一樣快
	var a: Node = m.players.get_node(^"1")
	a.stamina = 50.0
	for i in 120:
		a._update_stamina(1.0 / 120.0, 0.0, false)
	var still_gain: float = a.stamina - 50.0
	a.stamina = 50.0
	for i in 120:
		a._update_stamina(1.0 / 120.0, 0.0, true)
	var moving_gain: float = a.stamina - 50.0
	_ck(is_equal_approx(still_gain, moving_gain),
		"回復速度站著和移動要一樣（站 %.1f vs 走 %.1f）" % [still_gain, moving_gain])
	_end(m)

## 恐龍不能撿蛋
func _case_dino_cannot_take_egg() -> void:
	var m := _new_game()
	var d: Node3D = m.players.get_node(^"1")
	m.players.get_node(^"2").global_position = Vector3(0, 800, 0)
	m.players.get_node(^"3").global_position = Vector3(0, 800, 40)
	d.global_position = Vector3(0, 1, 0)
	m.egg.global_position = Vector3(1, 1, 0)   # 直接貼在恐龍身上
	m.egg.carrier = 0
	for i in 10:
		m._egg_step(DT)
	_ck(m.egg.carrier == 0, "恐龍站在蛋上面也不能撿（carrier=%d）" % m.egg.carrier)
	_end(m)

## 衝刺改成技能：按一下衝固定秒數，然後進 CD，全程不吃體力
## 選單的恐龍攻擊開關：關掉時恐龍打人不扣血，牛仔互打照扣
func _case_dino_attack_switch() -> void:
	var m := _new_game()
	var dino: Node = m.players.get_node(^"1")
	var c: Node = m.players.get_node(^"2")
	var hp0: int = c.hp
	m._on_dino_attack_toggled(false)
	c.take_damage(50, dino)
	_ck(c.hp == hp0, "關掉恐龍攻擊，恐龍打人不該扣血")
	c.take_damage(10, m.players.get_node(^"3"))
	_ck(c.hp == hp0 - 10, "關掉恐龍攻擊，牛仔互打還是要扣血")
	m._on_dino_attack_toggled(true)
	c.take_damage(50, dino)
	_ck(c.hp == hp0 - 60, "打開恐龍攻擊，恐龍打人要扣血")
	_ck(m.get_node(^"UI/Root/Menu/Box/Controller/DinoAttackBtn").button_pressed, "選單開關預設是開的")
	_end(m)

func _case_sprint_skill() -> void:
	var m := _new_game()   # 主機 = 恐龍，編號 1
	var d: Node = m.players.get_node(^"1")
	var dt := 1.0 / 120.0
	var full: float = d.STAMINA_MAX

	d.stamina = full
	d.move_step(dt, Vector3(0, 0, -1), true, false, false)   # 按下衝刺
	_ck(d._sprint_left > 0.0, "按下去要開始衝")
	_ck(is_equal_approx(d.stamina, full), "衝刺不該扣體力（現在 %.1f）" % d.stamina)

	# 衝完會停，而且進 CD
	var t := 0.0
	while d._sprint_left > 0.0 and t < 10.0:
		d.move_step(dt, Vector3(0, 0, -1), true, false, false)
		t += dt
	_ck(absf(t - d.SPRINT_TIME) < 0.2, "衝刺該持續 %.0f 秒（實際 %.1f）" % [d.SPRINT_TIME, t])
	_ck(d._sprint_cd > 0.0, "衝完要進冷卻")

	# CD 沒好之前再按也不會衝
	d.move_step(dt, Vector3(0, 0, -1), true, false, false)
	_ck(d._sprint_left <= 0.0, "冷卻中不該衝得起來")

	# 咬要吃體力。牛仔兩口就死，一管體力咬得完——這是刻意的，被咬到就該跑
	_ck(d.BITE_COST > 0.0, "咬要吃體力")
	_end(m)

## 開一局恐龍對三個牛仔 bot，等下面的 _phase 3 看牛仔 bot 會不會自己跑
func _start_bot_case() -> void:
	_phase = 3
	_bot_game = _dino_vs_bots()
	_bot_cowboy = _bot_game.players.get_node(^"2")
	_bot_from = Vector2(_bot_cowboy.global_position.x, _bot_cowboy.global_position.z)
