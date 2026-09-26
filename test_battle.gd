extends SceneTree
## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

var _fails := 0
var _shooter: Node
var _brawler: Node
var _dino: Node
var _jump_from := 0.0
var _phase := 0
var _bot_game: Node
var _bot_cowboy: Node3D
var _bot_from := Vector2.ZERO
var _bot_frames := 0
var _frames := 0
const DT := 1.0 / 120.0

func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_case_timeout()
		_case_dino_death()
		_case_attacks()
		_case_offline()
		_case_offline_dino()
		_case_cowboy()
		_case_input_map()
		_case_hunt_weapons()
		_case_sandbox()
		_case_rural()
		_case_back_to_lobby()
		_case_cover()
		_case_trex_rig()
		_case_trex_lean()
		_case_stamina()
		_case_sprint_skill()
		_case_egg()
		_case_dino_cannot_take_egg()
		_case_respawn()
		_case_fireball()
		_case_stagger()
		_case_arena_walls()
		_start_gun_case()
		return false
	# 剩下的要跨好幾個 frame 才驗得到
	match _phase:
		0:  # 牛仔開槍打恐龍。等一個物理幀讓位置進到物理世界，射線才打得到
			if _frames == 3:
				_check_melee_hits()
				_shooter._bot_shoot(_dino)
			elif _frames > 3:
				_ck(_dino.hp < _dino.max_hp, "牛仔開槍要打得到恐龍（恐龍血量 %d）" % _dino.hp)
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
				_start_bot_case()
			elif _frames > 900:
				_ck(false, "跳躍沒離地（只上升 %.1f 公尺）"
					% (_dino.global_position.y - _jump_from))
				_start_bot_case()
		3:  # 移動靶要真的跑起來（move_and_slide 只在物理幀有效，所以得跨幀等）
			_bot_frames += 1
			var now := _bot_cowboy.global_position
			if _bot_from.distance_to(Vector2(now.x, now.z)) > 3.0:
				_end(_bot_game)
				return _done()
			if _bot_frames > 500:
				_ck(false, "牛仔 bot 沒有自己跑起來")
				_end(_bot_game)
				return _done()
	return false

func _done() -> bool:
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、時間到判勝、重生、咬擊方向、離線兩種模式、牛仔身分與開槍、按鍵綁定、三把槍與爆頭閉氣蹲穩輕重近戰兩條體力、沙盒、鄉村柵欄、回大廳重開、建築擋視線、圍牆擋出界、暴龍骨架與尾巴慣性、側傾與位移延遲、開槍命中恐龍、恐龍跳躍、牛仔 bot、體力規則、衝刺技能、蛋與撤離、恐龍撿不到蛋、火球、中彈踉蹌都正常")
	return true

# --- 共用 ---

func _new_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()  # 主機 = 恐龍（編號 1）
	m._spawn(2)
	m._spawn(3)
	_ck(m._cowboys == 2, "應該有兩個牛仔")
	_ck(m.players.get_node(^"1").hp == m.players.get_node(^"1").max_hp, "恐龍滿血出生")
	_ck(m.players.get_node(^"2").hp == m.players.get_node(^"2").max_hp, "牛仔滿血出生")
	return m

func _new_offline_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_offline_pressed()  # 離線模式：編號 1 是自己的牛仔
	return m

func _end(m: Node) -> void:
	if m.multiplayer.multiplayer_peer != null:
		m.multiplayer.multiplayer_peer.close()
		m.multiplayer.multiplayer_peer = null
	root.remove_child(m)
	m.free()

# --- 案例 ---

func _case_timeout() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var t2: Node = m.players.get_node(^"2")
	var bites := ceili(float(t2.max_hp) / d.BITE_DAMAGE)
	_ck(bites == 2, "平衡目標：咬兩口死一個牛仔（現在是 %d 口）" % bites)

	# 恐龍只比牛仔跑步快一點點：跑得掉一段，但不能永遠甩開。兩邊各自改都會被擋下來
	var ratio: float = d.SPEED / t2.sprint_speed
	_ck(ratio > 1.0 and ratio < 1.15, "恐龍基礎速度要比牛仔跑步快 0~15%%（現在 %.2f 倍）" % ratio)

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

func _case_dino_death() -> void:
	var m := _new_game()
	var dino: Node = m.players.get_node(^"1")
	# 左輪的持續輸出 = 一輪的傷害 / (打完一輪 + 逐發換彈)
	var gun: Node = m.players.get_node(^"2").viewmodel._weapons[0]
	var cycle: float = gun.mag_size * (gun.fire_interval + gun.reload_time)
	var dps: float = gun.mag_size * gun.damage / cycle
	var secs: float = dino.max_hp / (3.0 * dps)
	_ck(secs > 8.0 and secs < 20.0, "平衡目標：3 個牛仔用左輪 8~20 秒打死恐龍（現在 %.1f 秒）" % secs)

	dino.take_damage(dino.max_hp)
	# 牛仔互為對手，所以打死恐龍不是勝利條件，回合要繼續，恐龍會重生
	_ck(not m._over, "恐龍陣亡不該直接結束回合")
	_ck(m._respawn_queue.size() == 1 and bool(m._respawn_queue[0]["dino"]),
		"恐龍要排進重生佇列——牠不重生的話後半場變成無人阻擋的賽跑")
	_ck(m._cowboys == 2, "牛仔數不受影響")
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
	_ck(front.hp == full - d.BITE_DAMAGE, "咬應該打到前面的牛仔")
	_ck(back.hp == full, "咬不該打到後面的牛仔")

	# 轉身面向後面那台，就換它挨咬
	d.look_at(back.global_position)
	d._hit_nearby(d.BITE_REACH, d.BITE_DAMAGE, 0.3)
	_ck(back.hp == full - d.BITE_DAMAGE, "轉身後應該咬得到原本在背後的牛仔")
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

## 離線當恐龍：自己控恐龍，三個牛仔 bot 會自己跑
func _case_offline_dino() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_offline_dino_pressed()
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

## 牛仔的身分：自己的有相機和 HUD，別人的（含 bot）全關；打中別人要走 deal_damage
func _case_cowboy() -> void:
	var m := _new_game()   # 主機是恐龍，牛仔 2、3 在主機上都是「別人的」
	var c: Node = m.players.get_node(^"2")
	_ck(not c.is_local, "主機上的牛仔是遠端角色")
	_ck(not c.get_node(^"HUD").visible and not c.viewmodel.visible, "遠端角色的 HUD 和槍都要藏起來")
	_ck(c.get_node(^"Body").visible, "遠端角色要看得到身體")
	_ck(c.max_hp == 150, "牛仔 150 血（Hunt 的數字）")

	# 主機上呼叫 deal_damage 直接扣血，而且記得是誰打的
	var victim: Node = m.players.get_node(^"3")
	c.deal_damage(victim, 30)
	_ck(victim.hp == victim.max_hp - 30, "主機上打中要直接扣血（現在 %d）" % victim.hp)
	_ck(victim._last_hit_by == c, "要記得是誰打的，擊殺播報才對得上")
	_end(m)

	m = _new_offline_game()
	var me: Node = m.players.get_node(^"1")
	_ck(me.is_local and me.get_node(^"Head/Camera3D").current, "自己的牛仔要用自己的相機")
	_ck(not me.get_node(^"Body").visible, "第一人稱看不到自己的身體")
	_end(m)

## Hunt 式的三把槍和它們的規則
func _case_hunt_weapons() -> void:
	var m := _new_offline_game()
	var me: Node = m.players.get_node(^"1")
	var vm: Node = me.viewmodel
	var names: Array = vm._weapons.map(func(w: Node) -> String: return w.display_name)
	_ck(names == ["左輪", "單管散彈", "槓桿步槍"], "1/2/3 要是左輪、單管散彈、槓桿步槍（現在 %s）" % [names])
	var revolver: Node = vm._weapons[0]
	var shotgun: Node = vm._weapons[1]
	var rifle: Node = vm._weapons[2]
	_ck(revolver.fan_interval > 0.0 and revolver.fan_interval < revolver.fire_interval,
		"左輪要能搧擊錘，而且比正常扳擊錘快")
	_ck(shotgun.mag_size == 1 and shotgun.reload_whole_mag, "單管散彈一次一發、折開整個換")
	_ck(rifle.hit_range > revolver.hit_range and revolver.hit_range > shotgun.hit_range,
		"射程要是步槍 > 左輪 > 散彈")
	for w in vm._weapons:
		_ck(w.reserve > 0, "%s 的備彈要有限（Hunt 的子彈要省著用）" % w.display_name)
		_ck(w.get_node_or_null(^"Model") != null, "%s 要有 Blender 建的模型" % w.display_name)
	_ck(rifle.get_node_or_null(rifle.lever_path) != null, "步槍的拉桿要找得到，不然上膛沒動作")
	_ck(revolver.get_node_or_null(revolver.cylinder_path) != null, "左輪的轉輪要找得到")
	_ck(shotgun.get_node_or_null(shotgun.barrel_path) != null, "散彈的槍管要找得到，換彈才折得開")

	# 開槍：程式動作要動起來（轉輪轉一格、後座）
	var turns: int = revolver._turns
	revolver.play(&"fire", 0.1, 0.45)
	_ck(revolver._turns == turns + 1 and revolver._kick > 0.0, "開槍要有後座、轉輪要轉")

	# 爆頭一槍死：打到頭的高度才算，打身體不算
	var other: Node3D = m._add_player(m.COWBOY, 5)
	other.global_position = Vector3(0, 0, 0)
	var head_y: float = other.head.global_position.y
	_ck(vm.is_headshot(other, Vector3(0, head_y, 0)), "打到頭的高度要算爆頭")
	_ck(not vm.is_headshot(other, Vector3(0, 1.0, 0)), "打到腰不算爆頭")
	_ck(not vm.is_headshot(m.players.get_node(^"2"), Vector3(0, 99, 0)), "恐龍沒有爆頭秒殺")

	# 閉氣：舉滿才閉得住，而且吃體力
	vm.ads = 1.0
	me.stamina = me.max_stamina
	vm._update_breath(true, 0.5)
	_ck(vm.holding_breath and me.stamina < me.max_stamina, "舉槍按 Shift 要閉氣、吃體力")
	vm.ads = 0.0
	vm._update_breath(true, 0.1)
	_ck(not vm.holding_breath, "沒舉槍不能閉氣")

	# 蹲下晃得少：同一個時間點比較站著和蹲著的飄移量
	vm.ads = 1.0
	me.stamina = me.max_stamina
	vm._sway_t = 0.7
	vm._sway_applied = Vector2.ZERO
	me.sync_crouching = false
	vm._update_breath(false, 0.0)
	var stand_sway: float = vm._sway_applied.length()
	vm._sway_applied = Vector2.ZERO
	me.sync_crouching = true
	vm._update_breath(false, 0.0)
	_ck(stand_sway > 0.0 and vm._sway_applied.length() < stand_sway * 0.75,
		"蹲下要晃得比站著少（站 %.5f 蹲 %.5f）" % [stand_sway, vm._sway_applied.length()])
	me.sync_crouching = false
	vm.ads = 0.0

	# 近戰：輕擊便宜、重擊痛但貴；體力不夠重擊就退成輕擊
	_ck(vm.heavy_damage > vm.melee_damage and vm.heavy_stamina > vm.melee_stamina,
		"重擊要比輕擊痛、也比較貴")
	# 真的敲到人要跨物理幀，見 _phase 0

	# 兩條體力：跑步不吃近戰體力、近戰不吃跑步體力；出力時兩條都不回
	me.stamina = me.max_stamina
	me.combat_stamina = me.max_combat
	var t := 0.0
	while me.update_stamina(true, 0.1) and t < 120.0:
		t += 0.1
	_ck(t > 12.0 and t < 30.0, "全力跑要撐 12~30 秒（現在 %.1f 秒）" % t)
	_ck(is_equal_approx(me.combat_stamina, me.max_combat), "跑步不該吃近戰體力")
	me.stamina = 50.0
	vm._melee_cooldown = 0.0
	vm.try_melee()
	_ck(is_equal_approx(me.stamina, 50.0) and me.combat_stamina < me.max_combat,
		"槍托吃近戰體力，不吃跑步體力")
	var combat_after: float = me.combat_stamina
	me.update_stamina(false, 0.5)
	_ck(is_equal_approx(me.stamina, 50.0) and is_equal_approx(me.combat_stamina, combat_after),
		"剛敲完還在回復延遲內，兩條都不回")
	for i in 60:
		me.update_stamina(false, 0.1)
	_ck(me.stamina > 50.0 and me.combat_stamina > combat_after, "延遲過後兩條都要回")
	# 近戰體力見底：還能輕擊，但慢一倍
	me.combat_stamina = 0.0
	vm._melee_cooldown = 0.0
	vm.try_melee(true)
	_ck(is_equal_approx(vm._melee_cooldown, vm.melee_cooldown * 2.0),
		"黃條見底時重擊退成輕擊，而且慢一倍（冷卻 %.2f）" % vm._melee_cooldown)
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

## 鄉村：柵欄翻得過去、有穀倉可以爬、沙盒靶場沒被蓋東西
func _case_rural() -> void:
	var m := _new_game()
	var c: Node = m.players.get_node(^"2")
	_ck(m.FENCE_H >= c.vault_min_height and m.FENCE_H <= c.vault_max_height,
		"柵欄 %.1f 公尺要在翻越範圍 %.1f~%.1f 內" % [m.FENCE_H, c.vault_min_height, c.vault_max_height])
	var fences := 0
	for b in m.get_node(^"Arena").get_children():
		if b is StaticBody3D and m.SANDBOX_RANGE.has_point(Vector2(b.global_position.x, b.global_position.z)) \
				and b.global_position.y > 0.5:
			_ck(false, "沙盒靶場裡不該蓋東西（%s 在 %s）" % [b.name, b.global_position])
		if b is StaticBody3D and b.get_child_count() > 3:
			fences += 1
	_ck(fences > 20, "鄉村要有柵欄（現在 %d 段）" % fences)
	_end(m)

## 牛仔的操作都要有綁鍵，鍵盤和手把兩邊都要（FNE 的約定）
func _case_input_map() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
			"crouch", "crouch_toggle", "fire", "aim", "reload", "melee"]:
		_ck(InputMap.has_action(a), "少了按鍵動作 %s" % a)
		if not InputMap.has_action(a):
			continue
		var kb := false
		var pad := false
		for e in InputMap.action_get_events(a):
			kb = kb or e is InputEventKey or e is InputEventMouseButton
			pad = pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		_ck(kb and pad, "%s 要同時綁鍵鼠和手把" % a)

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
	_ck(m.players.get_child_count() == 2 and m._cowboys == 1, "要能馬上重開一局")
	_end(m)

## 中間隔著建築物，恐龍就咬不到——牛仔躲掩蔽的依據
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

## 側傾與位移延遲：往旁邊移動時身體要往內倒、慢半拍才跟上，頭要保持水平
func _case_trex_lean() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"2").get_node(^"Trex")
	var d: Node3D = m.players.get_node(^"2")

	var drag := 0.0
	for i in 40:  # 假裝以 10 m/s 往右（本地 +X）平移
		t._last_pos = t.global_position - d.global_basis.x * (10.0 / 60.0)
		t._process(1.0 / 60.0)
		drag = maxf(drag, absf(t.skel.position.x))   # 只有加速那幾幀才拖得到
	var roll: float = t.skel.get_bone_pose_rotation(t._idx["spine1"]).get_euler().z
	_ck(roll < -0.03, "往右移動時軀幹要往右倒（現在 %.3f，應為負）" % roll)

	var head: float = t.skel.get_bone_pose_rotation(t._idx["head"]).get_euler().z
	_ck(head * roll < 0.0, "頭要反向轉回來保持水平（軀幹 %.3f 頭 %.3f）" % [roll, head])
	_ck(drag > 0.05, "起步那下身體要被拖著走，不是瞬間跟上（最大位移 %.3f）" % drag)

	for i in 600:  # 停下來，側傾要收斂回去
		t._last_pos = t.global_position
		t._process(1.0 / 60.0)
	_ck(absf(t.skel.get_bone_pose_rotation(t._idx["spine1"]).get_euler().z) < 0.03,
		"停下來要站回直的")
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

## 中彈踉蹌：恐龍被打中會短暫跑不快，時間過了要自己回復
func _case_stagger() -> void:
	var m := _new_game()
	var d: Node3D = m.players.get_node(^"1")
	var fwd := Vector3(0, 0, -1)

	d.take_damage(1)
	for i in int(0.3 / DT):
		d.move_step(DT, fwd, false, false, false)
	var slow := Vector2(d.velocity.x, d.velocity.z).length()
	_ck(slow < d.SPEED * 0.6, "中彈後應該跑不快（實際 %.1f，全速 %.1f）" % [slow, d.SPEED])

	for i in int(1.0 / DT):
		d.move_step(DT, fwd, false, false, false)
	var full := Vector2(d.velocity.x, d.velocity.z).length()
	_ck(full > d.SPEED * 0.9, "踉蹌過了要回到全速（實際 %.1f）" % full)
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

## 恐龍的火球：吃體力、有冷卻、真的會生出一顆
func _case_fireball() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var before: float = d.stamina
	d._spit()
	var balls := 0
	for c in m.get_node(^"Arena").get_children():
		if c is Fireball:
			balls += 1
	_ck(balls == 1, "吐一次應該生出一顆火球（現在 %d 顆）" % balls)
	_ck(ceili(150.0 / Fireball.DAMAGE) >= 3, "火球要三顆以上才打死牛仔，它是逼位不是主力")
	_ck(d.FIRE_COST > 0.0 and d.FIRE_COOLDOWN > 0.0, "火球要吃體力也要有冷卻，不然可以無限噴")
	d.stamina = before
	_end(m)

## 衝刺改成技能：按一下衝固定秒數，然後進 CD，全程不吃體力
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

## 開一局「我當恐龍」，等下面的 _phase 3 看牛仔 bot 會不會自己跑
func _start_bot_case() -> void:
	_phase = 3
	_bot_game = load("res://main.tscn").instantiate()
	root.add_child(_bot_game)
	_bot_game._on_offline_dino_pressed()
	_bot_cowboy = _bot_game.players.get_node(^"2")
	_bot_from = Vector2(_bot_cowboy.global_position.x, _bot_cowboy.global_position.z)

## 牛仔開槍要真的打中恐龍（射線要等位置進物理世界，所以跨幀，見 _phase 0）
func _start_gun_case() -> void:
	var m := _new_game()
	var spot: Vector3 = m._spawn_point()  # 挑淨空點，不然子彈會先打到建築
	_dino = m.players.get_node(^"1")
	_dino.global_position = Vector3(spot.x, 4.1, spot.z - 15.0)   # 原點在身體中心，腳剛好著地
	_shooter = m.players.get_node(^"3")
	_shooter.global_position = Vector3(spot.x, 0.0, spot.z)
	# 牛仔 2 貼在恐龍另一側練槍托（恐龍半徑 2.4，站 3.4 公尺外剛好在 2.2 的近戰距離內）
	_brawler = m.players.get_node(^"2")
	_brawler.global_position = Vector3(spot.x, 0.0, spot.z - 15.0 - 3.4)
	_brawler.rotation.y = PI   # 面向 +Z，對著恐龍

## 重擊比輕擊痛；體力不夠重擊就退成輕擊
func _check_melee_hits() -> void:
	var vm: Node = _brawler.viewmodel
	_brawler.combat_stamina = _brawler.max_combat
	var hp0: int = _dino.hp
	vm.try_melee(true)
	_ck(hp0 - _dino.hp == vm.heavy_damage, "重擊要打出 %d 傷（打出 %d）" % [vm.heavy_damage, hp0 - _dino.hp])
	_ck(is_equal_approx(_brawler.combat_stamina, _brawler.max_combat - vm.heavy_stamina),
		"重擊要扣 %.0f 近戰體力" % vm.heavy_stamina)
	_brawler.combat_stamina = vm.heavy_stamina - 1.0
	vm._melee_cooldown = 0.0
	hp0 = _dino.hp
	vm.try_melee(true)
	_ck(hp0 - _dino.hp == vm.melee_damage, "體力不夠重擊，要退成輕擊（打出 %d）" % (hp0 - _dino.hp))
