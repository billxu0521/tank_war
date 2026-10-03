extends SceneTree
## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

var _fails := 0
var _shooter: Node
var _brawler: Node
var _hp_before_shot := 0
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
		_case_mouse_lock()
		_case_hunt_weapons()
		_case_sandbox()
		_case_range()
		_case_net_smooth()
		_case_rural()
		_case_fx_and_ambience()
		_case_terrain()
		_case_interact()
		_case_vault()
		_case_modes()
		_case_match_rules()
		_case_solo_dino()
		_case_controller()
		_case_back_to_lobby()
		_case_cover()
		_case_trex_rig()
		_case_trex_lean()
		_case_trex_flinch()
		_case_stamina()
		_case_sprint_skill()
		_case_egg()
		_case_dino_cannot_take_egg()
		_case_respawn()
		_case_fireball()
		_case_dino_attack_switch()
		_case_ui()
		_case_bug_report()
		_case_stagger()
		_case_arena_walls()
		_case_boss()
		_case_compass()
		_case_dedicated_round()
		_start_gun_case()
		return false
	# 剩下的要跨好幾個 frame 才驗得到。總幀數設上限：腳本編譯壞掉時各階段等不到條件，
	# 沒有上限測試會永遠卡住，而不是回報失敗
	if _frames > 3000:
		_ck(false, "測試跑超過 3000 幀還沒結束（卡在第 %d 階段）" % _phase)
		return _done()
	match _phase:
		0:  # 牛仔開槍打恐龍。等一個物理幀讓位置進到物理世界，射線才打得到；
			# 子彈會飛，15 公尺要飛幾幀才到
			if _frames == 3:
				_check_melee_hits()
				_hp_before_shot = _dino.hp
				_shooter._bot_shoot(_dino)
				_ck(_dino.hp == _hp_before_shot, "子彈會飛，開槍當下不該立刻扣血")
			elif _frames > 3 and _dino.hp < _hp_before_shot:
				_phase = 1
			elif _frames > 120:
				_ck(false, "牛仔開槍要打得到恐龍（子彈飛了 %d 幀還沒到）" % (_frames - 3))
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
		print("OK：生怪、傷害、時間到判勝、重生、咬擊方向、離線兩種模式、牛仔身分與開槍、按鍵綁定、三把槍與左輪扳擊錘換彈動作音效不延遲子彈下墜有效射程爆頭閉氣蹲穩摔落輕重近戰一條體力、沙盒、鄉村柵欄灌木貼圖、著彈碎屑與煙囪煙、地形起伏、F 開門爬梯子、翻柵欄和窗台、手腳、只剩連線和沙盒、遊戲局控制、回大廳重開、建築擋視線、圍牆擋出界、暴龍骨架與尾巴慣性、側傾與位移延遲、開槍命中恐龍、恐龍跳躍、牛仔 bot、體力規則、衝刺技能、蛋與撤離、恐龍撿不到蛋、火球、恐龍攻擊開關、介面（大廳存 IP、勝負畫面、倒數）、中彈踉蹌、恐龍 boss 行為樹（導演、三招預備動作、導航網格）、方位條、測試站自動開下一局、問題回報、滑鼠鎖定不凍視角都正常")
	return true

# --- 共用 ---

## 測試用的對局：不走大廳按鈕（扮演模式拿掉了），直接組。恐龍的規則還要測，恐龍留著
func _offline_match() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	return m

## 恐龍（編號 1，操控得動）＋兩個牛仔（2、3，在這台機器上是「別人的」）
func _new_game() -> Node:
	var m := _offline_match()
	m._add_player(m.DINO, 1)
	m._add_player(m.COWBOY, 2)
	m._add_player(m.COWBOY, 3)
	_ck(m._cowboys == 2, "應該有兩個牛仔")
	_ck(m.players.get_node(^"1").hp == m.players.get_node(^"1").max_hp, "恐龍滿血出生")
	_ck(m.players.get_node(^"2").hp == m.players.get_node(^"2").max_hp, "牛仔滿血出生")
	return m

## 自己的牛仔（編號 1）＋一隻恐龍 bot
func _new_offline_game() -> Node:
	var m := _offline_match()
	m._add_player(m.COWBOY, 1).global_position = m._on_ground(Vector3(-20, 1.0, 15))
	var d: Node3D = m._add_player(m.DINO, 2)
	d.set(&"bot", true)
	return m

## 自己的恐龍（編號 1）＋三個牛仔 bot
func _dino_vs_bots() -> Node:
	var m := _offline_match()
	m._add_player(m.DINO, 1)
	for i in 3:
		m._add_player(m.COWBOY, 2 + i).set(&"bot", true)
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

## 咬只打前方，背後咬不到
func _case_attacks() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var front: Node = m.players.get_node(^"2")
	var back: Node = m.players.get_node(^"3")
	# 沙盒靶場那條整平的空地：沒有建築、也沒有小丘擋視線
	var spot: Vector3 = m._on_ground(Vector3(0, 2.0, 60))
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

## 牛仔的身分：自己的有相機和 HUD，別人的（含 bot）全關；打中別人要走 deal_damage
func _case_cowboy() -> void:
	var m := _new_game()   # 主機是恐龍，牛仔 2、3 在主機上都是「別人的」
	var c: Node = m.players.get_node(^"2")
	_ck(not c.is_local, "主機上的牛仔是遠端角色")
	_ck(not c.get_node(^"HUD").visible and not c.viewmodel.visible, "遠端角色的 HUD 和槍都要藏起來")
	_ck(c.get_node(^"Body").visible, "遠端角色要看得到身體")
	var body_mesh: Mesh = c.get_node(^"Body").mesh
	_ck(body_mesh != null and absf(body_mesh.get_aabb().end.y - 1.5) < 0.2,
		"身體要換上 Blender 的牛仔（肩膀約 1.5 公尺高）")
	var hat: Mesh = c.get_node(^"Head/Face").mesh
	_ck(hat != null and absf(hat.get_aabb().end.y - 0.28) < 0.06,
		"頭要換上牛仔的頭，帽頂在眼睛上方約 28 公分（現在 %s）" % (hat.get_aabb().end.y if hat else -1.0))
	_ck(c.max_hp == 150, "牛仔 150 血（Hunt 的數字）")

	# 主機上呼叫 deal_damage 直接扣血，而且記得是誰打的
	var victim: Node = m.players.get_node(^"3")
	c.deal_damage(victim, 30)
	_ck(victim.hp == victim.max_hp - 30, "主機上打中要直接扣血（現在 %d）" % victim.hp)
	_ck(victim._last_hit_by == c, "要記得是誰打的，擊殺播報才對得上")
	# 客戶端請主機扣血（Main.request_damage）：主機要檢查合不合理
	var eye: Vector3 = c.global_position + Vector3.UP * 1.6
	_ck(m.apply_damage_request(2, victim, 30, eye) and victim.hp == victim.max_hp - 60, "合理的一發要扣")
	_ck(not m.apply_damage_request(2, victim, 100, eye), "一發超過最大傷害（又不是打頭秒殺）不能扣")
	_ck(not m.apply_damage_request(2, victim, 30, eye + Vector3(100, 0, 0)), "開槍位置離開槍者太遠不能扣")
	var hp_c: int = c.hp
	_ck(m.apply_damage_request(2, victim, victim.max_hp, eye) and victim.hp <= 0, "打頭秒殺（傷害＝滿血）要扣")
	# 同時開槍：3 號剛被打死（主機上已經刪掉），他死前打出的那發在寬限時間內還是要算——同歸於盡
	var eye3: Vector3 = victim.global_position + Vector3.UP * 1.6
	victim.get_parent().remove_child(victim)
	_ck(m.apply_damage_request(3, c, 30, eye3) and c.hp == hp_c - 30, "剛死的人打出的子彈要算（同歸於盡）")
	m._died_at[3][0] = int(m._died_at[3][0]) - m.DEATH_GRACE_MS - 100
	_ck(not m.apply_damage_request(3, c, 30, eye3), "死了超過寬限時間就不算")
	# 最大傷害要跟著槍的數字走：改了槍的傷害、忘了改 MAX_HIT，主機會把正常的一發擋掉
	for w: Node in c.viewmodel._weapons:
		_ck(w.damage <= m.MAX_HIT, "%s 單發 %d 超過 Main.MAX_HIT" % [w.name, w.damage])
	_ck(c.viewmodel.heavy_damage <= m.MAX_HIT and c.viewmodel.melee_damage <= m.MAX_HIT, "槍托傷害超過 Main.MAX_HIT")
	_end(m)

	m = _new_offline_game()
	var me: Node = m.players.get_node(^"1")
	_ck(me.is_local and me.get_node(^"Head/Camera3D").current, "自己的牛仔要用自己的相機")
	_ck(me.get_node(^"Body").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"第一人稱看不到自己的身體，但要有影子")
	_ck(me.get_node(^"Body/LegL").mesh != null and me.get_node(^"Body/LegL").visible, "低頭要看得到自己的腿")
	# 走路擺腿：往前走一段，兩條腿要往相反方向擺
	for i in 20:
		me.global_position += Vector3(0, 0, -0.05)
		me._swing_legs(1.0 / 60.0)
	var l: float = me.get_node(^"Body/LegL").rotation.x
	var r: float = me.get_node(^"Body/LegR").rotation.x
	_ck(absf(l) > 0.02 and l * r < 0.0, "走路時兩條腿要反向擺（左 %.2f 右 %.2f）" % [l, r])
	var gun: Node = me.viewmodel._weapons[2]
	_ck(gun.get_node_or_null(^"Model/RifleLever/HandGrip") != null and gun.get_node_or_null(^"Model/HandSupport") != null,
		"步槍要有兩隻手：右手在拉桿上、左手托護木")
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
	_ck(shotgun.capacity == 1 and shotgun.reload_type == Weapon.Reload.WHOLE, "單管散彈一次一發、折開整個換")
	_ck(rifle.max_range > revolver.max_range and revolver.max_range > shotgun.max_range,
		"射程要是步槍 > 左輪 > 散彈")
	# 散布、舉槍時間、後座力是每把槍自己的：換到步槍就用步槍的數字
	vm.switch_weapon(2)
	rifle.spread_hip = 2.0
	vm.spread = 0.0
	vm.ads = 0.0
	vm._update_spread(0.1)
	_ck(is_equal_approx(vm.spread, 2.0), "腰射散布要用手上那把槍自己的（現在 %.1f）" % vm.spread)
	rifle.spread_hip = 4.0

	# 拉栓（cycle_time）比擊發間隔長時，要等拉栓做完才能開，兩段同時起算不相加
	var old_interval: float = rifle.fire_interval
	var old_cycle: float = rifle.cycle_time
	rifle.fire_interval = 0.3
	rifle.cycle_time = 1.0
	rifle.mag = rifle.capacity
	vm._fire_cooldown = 0.0
	vm.try_fire()
	vm._process(0.5)
	vm.try_fire()
	_ck(rifle.mag == rifle.capacity - 1, "拉栓還沒做完不能開下一槍")
	vm._process(0.55)
	vm.try_fire()
	_ck(rifle.mag == rifle.capacity - 2, "拉栓做完（1 秒，不是 1.3 秒）就能開")
	rifle.fire_interval = old_interval
	rifle.cycle_time = old_cycle
	vm.switch_weapon(0)

	# 傷害衰減：起點前全額、終點剩最低傷害、再遠也是最低傷害
	_ck(is_equal_approx(revolver.damage_at(revolver.falloff_end), revolver.minimum_damage)
		and is_equal_approx(revolver.damage_at(revolver.falloff_end * 2.0), revolver.minimum_damage)
		and is_equal_approx(revolver.damage_at((revolver.falloff_start + revolver.falloff_end) * 0.5),
			(revolver.damage + revolver.minimum_damage) * 0.5),
		"傷害衰減要是：起點全額、中間一半、終點以後都是最低傷害")

	# 瞄準後第一發完全準（開關打開時）：舉滿、站著、沒有累積散布 -> 正正打在準心
	revolver.ads_first_shot_perfect = true
	vm.ads = 1.0
	vm.spread = revolver.spread_ads
	me.velocity = Vector3.ZERO
	var eye: Camera3D = vm._camera
	_ck(vm._spread_direction(eye).is_equal_approx(-eye.global_transform.basis.z), "瞄準第一發要完全準")
	revolver.ads_first_shot_perfect = false
	vm.ads = 0.0

	# 逐發裝填中按開火：reload_fire_shoots 關掉時只停止裝填，不開槍
	vm.reload_fire_shoots = false
	revolver.mag = 3
	vm._fire_cooldown = 0.0
	vm.try_reload()
	vm.try_fire()
	_ck(revolver.mag == 3 and not vm._reloading, "裝填中按開火（只停不開）：停下裝填、不開槍")
	vm.reload_fire_shoots = true
	revolver.mag = revolver.capacity

	# 參數表（cowboy/weapons/weapons.csv）：每一列都要是真的參數、三把槍都有欄、選項翻得回來、改了會生效
	var table: Dictionary = Weapon.table()
	_ck(table.has("revolver") and table.has("shotgun") and table.has("rifle"), "參數表要有三把槍的欄")
	for key: String in table.get("revolver", {}):
		_ck(revolver.get(key) != null, "參數表的 %s 不是槍的參數（打錯字？）" % key)
	_ck(revolver.action_type == Weapon.Action.SINGLE_ACTION and shotgun.reload_type == Weapon.Reload.WHOLE
		and revolver.ads_first_shot_perfect == false, "參數表的選項（射擊類型、裝填類型、是／否）要翻對")
	var old_dmg: String = table["rifle"]["damage"]
	table["rifle"]["damage"] = "77"
	rifle.apply_table()
	_ck(is_equal_approx(rifle.damage, 77.0), "改參數表要生效")
	table["rifle"]["damage"] = old_dmg
	rifle.apply_table()

	# 武器介紹的射速：用規格第 07 節的例子——裝 3 發、每發拉栓 2 秒、整組裝填 9 秒 -> 不含裝填 30、含裝填 12 發／分
	var ex: Weapon = Weapon.new()
	ex.capacity = 3
	ex.fire_interval = 0.5
	ex.cycle_time = 2.0
	ex.reload_type = Weapon.Reload.WHOLE
	ex.reload_time = 9.0
	_ck(is_equal_approx(ex.rpm(), 30.0) and is_equal_approx(ex.rpm(true), 12.0),
		"射速算法要跟規格的例子一樣（現在 %.1f / %.1f）" % [ex.rpm(), ex.rpm(true)])
	ex.free()
	_ck(is_equal_approx(revolver.full_reload_time(),
		revolver.reload_start + revolver.capacity * revolver.reload_insert + revolver.reload_end), "逐發裝填總時間 = 準備 + 發數 × 每顆 + 收尾")
	m._set_menu(true)
	var info: GridContainer = m.menu.get_node(^"WeaponInfo")
	_ck(info.visible and info.get_child_count() == (revolver.info_rows().size() + 1) * 4, "Esc 選單要有三把槍的武器介紹")
	m._set_menu(false)

	# 瞄準按住／切換：玩家的設定要存起來，下次開遊戲還在
	m.settings_path = "user://test_settings.cfg"
	m._on_aim_toggle_toggled(true)
	Viewmodel.aim_toggle = false
	m._load_settings()
	_ck(Viewmodel.aim_toggle, "瞄準切換的設定要存起來")
	m._on_fps_cap_selected(2)
	_ck(Engine.max_fps == m._refresh_hz() / 2, "幀率上限選「螢幕的一半」要鎖在刷新率一半（現在 %d）" % Engine.max_fps)
	m._on_vsync_toggled(false)
	m.fps_cap = 0
	m.vsync = true
	m._load_settings()
	_ck(m.fps_cap == 2 and not m.vsync and Engine.max_fps == m._refresh_hz() / 2, "畫面設定要存起來，重開照樣套用")
	m._on_fps_cap_selected(0)
	m._on_vsync_toggled(true)
	_ck(Engine.max_fps == 0, "選「不限」要拿掉上限")
	m._on_aim_toggle_toggled(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.settings_path))
	for w in vm._weapons:
		_ck(w.reserve > 0, "%s 的備彈要有限（Hunt 的子彈要省著用）" % w.display_name)
		_ck(w.get_node_or_null(^"Model") != null, "%s 要有 Blender 建的模型" % w.display_name)
	_ck(rifle.get_node_or_null(rifle.lever_path) != null, "步槍的拉桿要找得到，不然上膛沒動作")
	_ck(revolver.get_node_or_null(revolver.cylinder_path) != null, "左輪的轉輪要找得到")
	_ck(shotgun.get_node_or_null(shotgun.barrel_path) != null, "散彈的槍管要找得到，換彈才折得開")

	# 腰射時槍管要跟視線平行：從玩家眼睛看，槍管才會指向準心
	revolver._since_fire = 9.0
	revolver._procedural(0.016)
	var cam: Camera3D = me.get_node(^"Head/Camera3D")
	var bore: Vector3 = -revolver.get_node(^"Model").global_basis.z
	var off := rad_to_deg(bore.angle_to(-cam.global_basis.z))
	_ck(off < 1.0, "腰射時左輪槍管要朝正前方（現在偏 %.1f 度）" % off)

	# 開槍：程式動作要動起來。Pax：槍口大翻、拇指上去扳擊錘，扳到一半轉輪轉一格
	var turns: int = revolver._turns
	revolver.play(&"fire", 0.1, 0.45)
	_ck(revolver._kick > 0.0, "開槍要有後座")
	var thumb_max := 0.0
	for i in 60:
		revolver._procedural(0.45 / 50.0)
		thumb_max = maxf(thumb_max, revolver._thumb.rotation.length())
	_ck(revolver._turns == turns + 1, "扳完擊錘轉輪要轉一格")
	_ck(thumb_max > 1.0 and revolver._thumb.rotation.length() < 0.05, "拇指要伸上去扳擊錘、再放回來")
	var hammer: Node3D = revolver.get_node(revolver.hammer_path)
	_ck(absf(hammer.rotation.x) < 0.01, "扳完擊錘要停在扳起來的位置")
	_ck(revolver.muzzle_global() != null, "左輪要設槍口位置，火光和煙才對得上")
	# 瞄準高度要等於準星頂（＝槍身最高點）。改了模型沒跟著改，舉槍就會對歪
	var body: MeshInstance3D = revolver.get_node(^"Model/Revolver")
	var sight_top := body.position.y + body.mesh.get_aabb().end.y
	_ck(absf(revolver.ads_position.y + sight_top) < 0.001,
		"左輪舉槍高度 %.4f 要對上準星頂 %.4f" % [-revolver.ads_position.y, sight_top])

	# 換彈：舉起來開裝填門，左手推退殼桿、捏著子彈塞進去，塞完轉一格
	revolver.play(&"reload_start")
	revolver.play(&"reload_round", 0.1, 0.55)
	var gate: Node3D = revolver.get_node(revolver.gate_path)
	var ejector: Node3D = revolver.get_node(revolver.ejector_path)
	var round_seen := false
	var hand_seen := false
	var pushed := 0.0
	var gate_open := 0.0
	turns = revolver._turns
	for i in 60:
		revolver._procedural(0.55 / 50.0)
		round_seen = round_seen or revolver._round.visible
		hand_seen = hand_seen or revolver._load_hand.visible
		pushed = maxf(pushed, ejector.position.z - revolver._ejector_rest.z)
		gate_open = minf(gate_open, gate.rotation.z)
	_ck(gate_open < -1.0, "換彈要打開裝填門")
	_ck(pushed > 0.02 and round_seen and hand_seen, "左手要推退殼桿、拿子彈塞進去")
	_ck(revolver._turns == turns + 1, "塞完一發轉輪要轉一格")
	revolver.stop_reload()
	for i in 60:
		revolver._procedural(1.0 / 60.0)
	_ck(gate.rotation.z > -0.05 and not revolver._load_hand.visible, "換彈中斷，門要關、左手要收走")

	# 長槍換彈：右手離開握把、拿一顆塞進去、再回來握好
	for w: Node in [shotgun, rifle]:
		var rest: Vector3 = w.grip_hand.origin
		w.play(&"reload_round", 0.1, 0.8)
		var left := 0.0
		var seen := false
		for i in 60:
			w._procedural(0.8 / 50.0)
			left = maxf(left, w._grip.position.distance_to(rest))
			seen = seen or w._hand_round.visible
		_ck(left > 0.1 and seen, "%s 換彈時右手要離開握把、拿著子彈" % w.display_name)
		_ck(w._grip.position.distance_to(rest) < 0.01, "%s 換完右手要回到握把" % w.display_name)
		w.stop_reload()

	# 音效開頭不能有空白：扣扳機到出聲超過 20 毫秒就會覺得延遲
	for w in vm._weapons:
		for snd in ["ShootSound", "ReloadSound", "EmptySound"]:
			var lead := _sound_lead(w.get_node(snd).stream)
			_ck(lead <= 0.02, "%s 的 %s 開頭空了 %.3f 秒，會聽起來延遲" % [w.display_name, snd, lead])

	# 子彈會掉：從高空水平射出，飛 0.5 秒要往下掉約 ½gt²
	var b := Bullet.new()
	b.origin = Vector3(0, 400, 0)
	b.vel = Vector3(0, 0, -rifle.muzzle_velocity)
	b.weapon = rifle
	m.get_node(^"Arena").add_child(b)
	for i in 60:
		b.advance(1.0 / 120.0)
	var drop: float = 400.0 - b.global_position.y
	_ck(absf(drop - 0.5 * Bullet.GRAVITY * 0.25) < 0.1, "飛 0.5 秒要掉 1.2 公尺左右（掉了 %.2f）" % drop)
	_ck(absf(-b.global_position.z - rifle.muzzle_velocity * 0.5) < 2.0,
		"子彈要照初速往前飛（飛了 %.0f 公尺）" % -b.global_position.z)
	b.free()
	_ck(rifle.muzzle_velocity > revolver.muzzle_velocity, "步槍子彈要比左輪快")

	# 有效射程：射程內全額，超過遞減，射程盡頭剩一半；射程要照步槍 > 左輪 > 散彈排
	for w in vm._weapons:
		_ck(is_equal_approx(w.damage_at(w.falloff_start * 0.5), w.damage), "%s 有效射程內要全額" % w.display_name)
		_ck(w.damage_at(w.max_range) < w.damage * 0.6, "%s 射程盡頭傷害要打折" % w.display_name)
	_ck(rifle.falloff_start > revolver.falloff_start and revolver.falloff_start > shotgun.falloff_start,
		"有效射程要是步槍 > 左輪 > 散彈")

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

	# 摔落：4 公尺以下沒事、15 公尺必死、中間照比例
	_ck(me.fall_damage(3.0) == 0, "摔 3 公尺不該扣血")
	_ck(me.fall_damage(15.0) >= me.max_hp, "摔 15 公尺要摔死")
	var mid: int = me.fall_damage(9.5)
	_ck(mid > 0 and mid < me.max_hp, "摔 9.5 公尺要扣一部分（現在 %d）" % mid)
	# 剛出生從半空掉下來不算；站穩之後從高處落地才算
	var hp_before: int = me.hp
	me._fall_top = -INF
	me._land()
	_ck(me.hp == hp_before, "第一次落地（出生）不算摔")
	me._fall_top = me.global_position.y + 9.5
	me._land()
	_ck(me.hp == hp_before - mid, "從 9.5 公尺落地要扣 %d（現在扣 %d）" % [mid, hp_before - me.hp])
	me._land()
	_ck(me.hp == hp_before - mid, "站著不動不能一直扣")

	# 近戰：輕擊便宜、重擊痛但貴；體力不夠重擊就退成輕擊
	_ck(vm.heavy_damage > vm.melee_damage and vm.heavy_stamina > vm.melee_stamina,
		"重擊要比輕擊痛、也比較貴")
	# 真的敲到人要跨物理幀，見 _phase 0

	# 一條體力：跑、跳、翻越、槍托都吃它；不夠只影響移動速度，其他照樣做得到
	me.stamina = me.max_stamina
	var t := 0.0
	while me.update_stamina(true, 0.1) and t < 120.0:
		t += 0.1
	_ck(t > 12.0 and t < 30.0, "全力跑要撐 12~30 秒（現在 %.1f 秒）" % t)
	_ck(not me.update_stamina(true, 0.1), "體力見底要跑不動")
	me.stamina = 50.0
	vm._melee_cooldown = 0.0
	vm.try_melee()
	_ck(is_equal_approx(me.stamina, 50.0 - vm.melee_stamina), "槍托吃同一條體力")
	var after: float = me.stamina
	me.update_stamina(false, 0.5)
	_ck(is_equal_approx(me.stamina, after), "剛出力完還在回復延遲內，不回")
	for i in 60:
		me.update_stamina(false, 0.1)
	_ck(me.stamina > after, "延遲過後要回")
	me.stamina = 0.0
	vm._melee_cooldown = 0.0
	vm.try_melee(true)
	_ck(is_equal_approx(vm._melee_cooldown, vm.heavy_cooldown), "體力見底照樣重擊，不變慢（冷卻 %.2f）" % vm._melee_cooldown)
	# 蓄力近戰時按右鍵舉不起槍；放掉近戰才舉得起來
	Input.action_press("aim")
	vm._melee_held = 0.1
	vm.ads = 0.0
	vm._process(0.1)
	_ck(vm.ads == 0.0, "蓄力近戰時不能舉槍（ads %.2f）" % vm.ads)
	vm._melee_held = -1.0
	vm._process(0.1)
	_ck(vm.ads > 0.0, "沒在蓄力就舉得起槍")
	Input.action_release("aim")
	vm.ads = 0.0
	_end(m)

## 音檔開頭到第一個超過 -40dB 的樣本有幾秒。只認 16 位元 WAV（槍聲都轉成這種了）
func _sound_lead(stream: AudioStream) -> float:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return 99.0
	var data := wav.data
	var ch := 2 if wav.stereo else 1
	for i in range(0, data.size() - 1, 2):
		if absi(data.decode_s16(i)) > 328:   # 32768 × 0.01 ≈ -40dB
			return float(i / 2 / ch) / wav.mix_rate
	return 99.0

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

## 靶場：另一張地圖，靶照距離站好、擺設乾淨，打中跳字，回大廳就切回牧場
func _case_range() -> void:
	var Main: GDScript = load("res://main.gd")
	Main.mode = &"range"
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._start_range()
	_ck(m.level_path == Main.RANGE_LEVEL and ResourceLoader.exists(m.level_path), "靶場要讀自己的場景檔")
	_ck(m.players.get_child_count() == 2 + m.RANGE_TARGETS.size(), "要有自己、恐龍靶和 %d 個牛仔靶" % m.RANGE_TARGETS.size())
	var me: Node3D = m.players.get_node(^"1")
	var far: Node3D = m.players.get_node(NodePath(str(2 + m.RANGE_TARGETS.size())))
	_ck(absf(-(far.global_position - me.global_position).z - 150.0) < 1.0, "最遠的靶在 150 公尺")
	var probs := LevelCheck.run(m._level, false)
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

## 鄉村：柵欄翻得過去、有穀倉可以爬、沙盒靶場沒被蓋東西
func _case_rural() -> void:
	var m := _new_game()
	var c: Node = m.players.get_node(^"2")
	_ck(m.FENCE_H >= c.vault_min_height and m.FENCE_H <= c.vault_max_height,
		"柵欄 %.1f 公尺要在翻越範圍 %.1f~%.1f 內" % [m.FENCE_H, c.vault_min_height, c.vault_max_height])
	# 灌木叢：夠多、不長在建築裡和路上；蹲在裡面才藏得住（站著頭會露出來）
	_ck(m._bushes.size() > m.ARENA * m.ARENA / 500.0, "要有灌木叢可以躲（現在 %d 叢）" % m._bushes.size())   # 每 500 平方公尺至少一叢
	var bad := 0
	for b: Vector3 in m._bushes:
		if not m._is_clear(Vector2(b.x, b.z)) or Trails.edge(b.x, b.z) < 0.0:
			bad += 1
	_ck(bad == 0, "灌木不能長在建築裡或路上（%d 叢）" % bad)
	_ck(Trails.ARENA == m.ARENA, "trails.gd 的 ARENA 要跟 main.gd 一樣")
	# 穀倉後門：大穀倉站著走得過去，小棚子蹲著鑽得過去（0.8.1 回饋：門小到人過不去）
	var backs := 0
	for d in m.get_node(^"Arena").get_children():
		if not d is Door or (d.get_child(1) as MeshInstance3D).mesh != m._props[&"BarnBackDoor"]:
			continue
		backs += 1
		var sc: Vector3 = (d.get_child(1) as MeshInstance3D).scale
		var cap := CapsuleShape3D.new()
		cap.radius = c.get_node(^"CollisionShape3D").shape.radius
		cap.height = c.stand_height if sc.y > 0.8 else c.crouch_height
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.exclude = [d.get_rid()]
		var mid: Vector3 = d.global_position + Vector3(m.BARN_BACK_W * 0.5 * sc.x, cap.height * 0.5 + 0.05, 0)
		q.transform = Transform3D(Basis(), mid)
		var hits := m.get_viewport().world_3d.direct_space_state.intersect_shape(q, 4)
		_ck(hits.is_empty(), "穀倉後門要過得去（縮放 %.2f × %.2f，%s 卡住）" % [sc.x, sc.y, "站著" if sc.y > 0.8 else "蹲著"])
	_ck(backs > 0, "場上要有穀倉後門")
	c.global_position = m._bushes[0] + Vector3(0.3, 0.2, 0)
	c.sync_crouching = false
	_ck(not m.hidden_in_bush(c), "站在灌木裡頭會露出來，不算藏住")
	c.sync_crouching = true
	_ck(m.hidden_in_bush(c), "蹲在灌木裡要藏得住")
	c.sync_crouching = false
	var fences := 0
	for b in m.get_node(^"Arena").get_children():
		if b is StaticBody3D and m.SANDBOX_RANGE.has_point(Vector2(b.global_position.x, b.global_position.z)) \
				and b.global_position.y > 0.5:
			_ck(false, "沙盒靶場裡不該蓋東西（%s 在 %s）" % [b.name, b.global_position])
		if b is StaticBody3D and b.get_child_count() > 3:
			fences += 1
	_ck(fences > 20, "鄉村要有柵欄（現在 %d 段）" % fences)
	# 場景物件的模型都要載得到，名字對不上的話會變成看不見的空氣牆
	for n in [&"Barn", &"BarnRoof", &"House1", &"House2", &"House3", &"House1Col", &"HouseDoor", &"SiloBody", &"SiloDome", &"FenceRail",
			&"FencePost", &"HayBale", &"TreeOak", &"TreeOakM", &"TreeOakS", &"TreePine", &"Bush", &"WheatTuft", &"GrassClump",
			&"Egg", &"Wagon", &"Rock01", &"Rock16", &"Lantern", &"Barrel", &"Crate", &"HayBlock", &"Wheel",
			&"FenceGate", &"GatePost", &"HitchRail", &"Windmill", &"WindmillRotor", &"HayShed", &"HayShedCol",
			&"Saloon", &"SaloonCol", &"Store", &"StoreCol", &"Sheriff", &"SheriffCol", &"WaterTower", &"WaterTowerCol",
			&"TreeMaple", &"TreePine2", &"TreeJoshua", &"TreeDead", &"TreeWillow", &"Saguaro", &"SaguaroS", &"BarrelCactus",
			&"PricklyPear", &"GrassTall", &"GrassDense", &"GrassSmall", &"DesertBush", &"ScrubBush"]:
		_ck(m._props.get(n) is Mesh, "模型檔（props、trees、rocks、houses、kits、towns、groves、floras）裡要有 %s" % n)
	# 場景小物件要貼著地面：不能浮在半空、也不能埋進地裡（車輪是輪軸中心，另外算）
	var floating := []
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for kind: StringName in [&"Barrel", &"Crate", &"HitchRail", &"GatePost", &"FenceGate", &"Windmill", &"HayShed", &"Wheel"]:
			if mi.mesh == m._props.get(kind):
				var p := mi.global_position
				var above: float = p.y - m._terrain.height(p.x, p.z) - (0.6 if kind == &"Wheel" else 0.0)
				if absf(above) > 0.35:
					floating.append("%s %.1f" % [kind, above])
	_ck(floating.is_empty(), "場景小物件要貼地（離地多少公尺：%s）" % [floating])
	# 擺設檢查（編輯器的「檢查擺設」按鈕跑的同一支）：場景檔要乾淨；檢查本身要抓得到重疊
	var probs := LevelCheck.run(m._level)
	_ck(probs.is_empty(), "擺設檢查有問題：%s" % [probs.slice(0, 5)])
	_ck(not LevelCheck.run([{kind = &"kit", name = &"Crate", pos = Vector3(3, 0, 40), yaw = 0.0},
		{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = 0.3}]).is_empty(), "擺設檢查要抓得到木箱卡在柵欄裡")
	_ck(not LevelCheck.run([{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = 0.0},
		{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = -PI * 0.5}]).is_empty(), "擺設檢查要抓得到兩道柵欄交叉")
	_ck(LevelCheck.run([{kind = &"fence", pos = Vector3(60, 0, 40), length = 10.0, yaw = 0.0},   # 離開沙盒靶場
		{kind = &"fence", pos = Vector3(65, 0, 45), length = 10.0, yaw = -PI * 0.5},
		{kind = &"kit", name = &"HayBlock", pos = Vector3(63, 0, 30), yaw = 0.0},
		{kind = &"kit", name = &"HayBlock", pos = Vector3(63, m.HAY_BLOCK.y, 30), yaw = 0.0}]).is_empty(), "柵欄在轉角接起來、草捆疊高不算重疊")
	_ck(m.level_path != "" and ResourceLoader.exists(m.level_path), "場地要照場景檔 levels/ranch.tscn 蓋")
	# 柵欄不能穿過農舍（牧場的房子以前跨到隔壁格，隔壁農莊的圍欄從房子中間穿過去）
	var houses: Array[Vector3] = []
	var rails: Array[Vector3] = []
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh in [m._props.get(&"House1"), m._props.get(&"House2"), m._props.get(&"House3")]:
			houses.append(mi.global_position)
		elif mi.mesh == m._props.get(&"FenceRail"):
			rails.append(mi.global_position)
	var through := 0
	for h in houses:
		for r in rails:
			if absf(r.x - h.x) < 5.2 and absf(r.z - h.z) < 4.2:
				through += 1
	_ck(houses.size() >= 3 and through == 0, "柵欄不能穿過農舍（%d 段穿過）" % through)
	_end(m)

## 著彈照材質噴不同碎屑；煙囪冒煙
func _case_fx_and_ambience() -> void:
	var m := _new_game()
	var arena: Node = m.get_node(^"Arena")
	var kinds := {}
	for b in arena.get_children():
		if b is StaticBody3D:
			kinds[Bullet.surface_of(b)] = true
	_ck(kinds.has(&"dirt") and kinds.has(&"stone") and kinds.has(&"wood"),
		"場上要打得出土、石屑、木屑三種（現在 %s）" % [kinds.keys()])
	_ck(Bullet.surface_of(m.players.get_node(^"1")) == &"blood", "打到恐龍要噴血")
	var before := arena.get_child_count()
	for surface: StringName in Fx.SURFACES:
		Fx.hit(arena, Vector3(0, 1, 0), Vector3.UP, surface)
	_ck(arena.get_child_count() > before + Fx.SURFACES.size() - 1, "每種著彈都要生出粒子")
	var smoke := 0
	for n in arena.get_children():
		if n is CPUParticles3D and not n.one_shot:
			smoke += 1
	_ck(smoke > 0, "房子的煙囪要冒煙")
	_end(m)

## 地形：有起伏、該平的地方平、碰撞跟畫面對得上
func _case_terrain() -> void:
	var m := _new_game()
	var t: Terrain = m._terrain
	var lo := 999.0
	var hi := -999.0
	for ix in range(-150, 151, 10):
		for iz in range(-150, 151, 10):
			var h := t.height(ix, iz)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	_ck(hi - lo > 6.0, "地形要有高低差（現在最高最低只差 %.1f 公尺）" % (hi - lo))
	_ck(hi <= Terrain.AMP + 0.01 and lo >= -Terrain.AMP - 0.01, "地形不能超出 ±%.0f 公尺" % Terrain.AMP)

	# 最陡的坡要走得上去（CharacterBody3D 預設 45 度以上當牆）
	var steep := 0.0
	for ix in range(-150, 151, 4):
		for iz in range(-150, 151, 4):
			steep = maxf(steep, t.slope(ix, iz))
	_ck(steep < 1.0 - cos(deg_to_rad(40.0)), "最陡的坡要在 40 度內（現在 %.0f 度）" % rad_to_deg(acos(1.0 - steep)))

	# 穀倉底下要是平的。沙盒靶場不整平了（以前的十字路改成有起伏的丘陵）；量距離準不準去靶場地圖（levels/range.tscn）
	var b: Rect2 = m._blocked[0]
	var c := b.get_center()
	var spread := 0.0
	for dx in [-8.0, 0.0, 8.0]:
		for dz in [-10.0, 0.0, 10.0]:
			spread = maxf(spread, absf(t.height(c.x + dx, c.y + dz) - t.height(c.x, c.y)))
	_ck(spread < 0.05, "穀倉底下要是平地（高低差 %.2f 公尺）" % spread)

	# 碰撞跟畫面同一份高度：往下打射線，打到的高度要等於 height()
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	for p in [Vector2(22, -49), Vector2(-60, 8), Vector2(40, 40), Vector2(-3, 78)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 100, p.y), Vector3(p.x, -100, p.y))
		var hit: Dictionary = space.intersect_ray(q)
		# 上面可能剛好有樹、乾草捲：穿過去，只量地形（有 HeightMapShape3D 的那個）
		while not hit.is_empty() and not hit["collider"].get_children().any(
				func(c: Node) -> bool: return c is CollisionShape3D and c.shape is HeightMapShape3D):
			q.exclude = q.exclude + [hit["rid"]]
			hit = space.intersect_ray(q)
		var want := t.height(p.x, p.y)
		_ck(not hit.is_empty() and absf(hit["position"].y - want) < 0.3,
			"(%d, %d) 的地面碰撞要在 %.2f（打到 %s）" % [p.x, p.y, want, hit.get("position", "沒打到")])
	_end(m)

## F 互動：看著門會提示、按了會開關；梯子爬得上閣樓、放得開
func _case_interact() -> void:
	var m := _new_offline_game()
	var me: Node3D = m.players.get_node(^"1")
	# 草不能長進屋裡
	var inside := 0
	var spots := []
	m._grass_field(spots)   # 沒畫面時 _build_arena 不長草，這裡直接長一次，拿位置清單來檢查
	for s: Vector2 in spots:
		if not m._is_clear(s):
			inside += 1
	var blades := 0
	for n in m.get_tree().get_nodes_in_group(&"grass"):
		blades += n.multimesh.instance_count
	# 草照植被密度長（旱地剩三成），一片一片的，所以門檻是每平方公尺 1.5 叢不是 2
	_ck(blades > m.ARENA * m.ARENA * 1.5 and blades == spots.size(), "草地要長滿（現在 %d 叢）" % blades)
	_ck(inside == 0, "草叢不能長在建築裡（有 %d 叢）" % inside)
	_ck(m._doors.size() >= 3, "每棟穀倉至少兩扇滑門＋後門（現在全場 %d 扇門）" % m._doors.size())
	var d: Door = m._doors[0]   # 第一棟穀倉左邊那扇滑門

	# 站在門前 2 公尺、面向門：F 的目標就是它
	me.global_position = d.global_position + Vector3(0, 0, 2.0)
	me.rotation.y = 0.0
	me.head.rotation.x = 0.0
	me.update_focus()
	_ck(me.focus == d, "看著門要能互動（看到的是 %s）" % me.focus)
	_ck(me.get_node(^"HUD/PromptLabel").text.contains("開門"), "看著門要提示 [F] 開門")

	# 按 F：開、再按：關。滑門開的時候真的滑開半個門寬
	var closed: Vector3 = d.position
	me.focus.interact(me)
	_ck(d.is_open and d.prompt == "關門", "按 F 門要打開")
	d.set_open(true, true)
	_ck(d.position.distance_to(closed) > 2.0, "滑門打開要滑開（只動了 %.2f 公尺）" % d.position.distance_to(closed))
	d.interact(me)
	_ck(not d.is_open, "再按一次要關上")
	d.set_open(false, true)
	_ck(d.position.is_equal_approx(closed), "關上要回到原位")

	# 梯子：抓住往上爬，爬到頂站到閣樓上
	var lad: Ladder = null
	for n in m.get_node(^"Arena").get_children():
		# 挑最高的一座（大穀倉）；牧場的小棚子閣樓本來就只有 2 公尺
		if n is Ladder and (lad == null or n.top_y - n.foot.y > lad.top_y - lad.foot.y):
			lad = n
	_ck(lad != null, "穀倉裡要有梯子")
	if lad:
		me.start_climb(lad)
		_ck(me.is_climbing(), "F 要能抓住梯子")
		_ck(Vector2(me.global_position.x, me.global_position.z).distance_to(Vector2(lad.foot.x, lad.foot.z)) < 0.01,
			"抓住梯子要貼到梯子前面")
		var steps := 0
		while me.is_climbing() and steps < 200:
			me.climb_step(0.1, 1.0, false)
			steps += 1
		_ck(not me.is_climbing() and me.global_position.is_equal_approx(lad.exit),
			"爬到頂要站上閣樓（在 %s，應該在 %s）" % [me.global_position, lad.exit])
		_ck(lad.top_y - lad.foot.y > 3.0, "閣樓要有 3 公尺以上高")
		me.global_position = lad.foot
		me.start_climb(lad)
		me.climb_step(0.5, 1.0, false)
		me.climb_step(0.1, 0.0, true)
		_ck(not me.is_climbing(), "爬到一半要放得開")
	_end(m)

## 翻越：柵欄、窗台翻得過去（不用先撞上去），穀倉的牆太高翻不過去
func _case_vault() -> void:
	var m := _new_offline_game()
	var me: Node3D = m.players.get_node(^"1")
	m.players.get_node(^"2").global_position = Vector3(0, 300, 0)   # 恐龍閃開

	# 柵欄：找一段柵欄，站在它前面 0.7 公尺、面向它
	var fence: Node3D = null
	for n in m.get_node(^"Arena").get_children():
		if n is StaticBody3D and n.get_child_count() > 3 and absf(n.global_basis.x.y) < 0.02:
			fence = n   # 挑一段平的，斜坡上的柵欄起跳點不好算
			break
	_ck(fence != null, "場上要有柵欄")
	if fence:
		var normal: Vector3 = fence.global_basis.z
		var at: Vector3 = fence.global_position + normal * 0.7
		me.global_position = m._on_ground(Vector3(at.x, 0, at.z))   # _on_ground 的 y 是離地高度，別把已經貼地的高度再加一次
		me.rotation = Vector3(0, atan2(normal.x, normal.z), 0)
		var before: float = me.stamina
		_ck(me.try_vault(true), "站在柵欄前按 Space 要翻得過去（不用先撞上去）")
		_ck(me.vaulting and me.stamina < before, "翻越要開始動作、吃體力")
		me.vaulting = false
		me.stamina = 0.0
		_ck(me.try_vault(true), "體力見底也要翻得過去（體力只影響移動速度）")
		me.vaulting = false

	# 農舍的窗：窗台離地 1 公尺，從窗外翻進屋裡（用左側牆的窗：正面有前廊擋著）
	var house := Vector3.ZERO
	for n in m.get_node(^"Arena").get_children():
		if n is MeshInstance3D and n.mesh == m._props[&"House1"]:
			house = n.global_position
			break
	me.global_position = m._on_ground(Vector3(house.x - 5.0 - 0.7, 0, house.z))
	me.rotation = Vector3(0, -PI * 0.5, 0)   # 面向 +X，對著左牆的窗
	me.stamina = me.max_stamina
	_ck(me.try_vault(true), "站在窗外要能從窗戶翻進去")
	me.vaulting = false

	# 穀倉的牆 8 公尺：翻不過去
	var b: Rect2 = m._blocked[0]
	var c := b.get_center()
	var wall_x: float = c.x + (b.size.x - 2.0 * m.SPAWN_CLEARANCE) * 0.5
	me.global_position = m._on_ground(Vector3(wall_x + 0.7, 0, c.y + 3.0))
	me.rotation = Vector3(0, PI * 0.5, 0)   # 面向 -X，對著穀倉右牆
	me.stamina = me.max_stamina
	_ck(not me.try_vault(true), "穀倉的牆太高，不能翻")
	_ck(not me.try_vault(false), "沒按住往前不能翻")
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
	_ck(m.mode_pick.item_count == 3, "大廳要能選三種模式（現在 %d）" % m.mode_pick.item_count)
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
	_ck(b.max_hp == m.DUEL_BOSS_HP and b.hp == m.DUEL_BOSS_HP, "決鬥的恐龍血量 %d" % m.DUEL_BOSS_HP)
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
	_ck(m._boss_debug().begins_with("恐龍："), "畫面要顯示恐龍在做什麼")
	_end(m)

## 遊戲局控制：移動標靶來回走、不開槍、死了照樣生回標靶；bot 在沙盒找玩家；清除清乾淨
func _case_controller() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_sandbox_pressed()
	var before: int = m.players.get_child_count()
	var w: Node3D = m.add_walker()
	_ck(w != null and Fighter.is_bot_id(w.name.to_int()), "移動標靶的編號要是電腦的（負數）")
	_ck(w.walker and w.bot and not w.is_local, "移動標靶是電腦、不是玩家")
	var ground: float = m._terrain.height(w.patrol_a.x, w.patrol_a.z)
	_ck(absf(w.patrol_a.y - ground) < 0.05 and absf(w.patrol_b.y - ground) < 0.5,
		"巡邏點要貼地（在 %.2f，地面 %.2f）" % [w.patrol_a.y, ground])
	_ck(w.patrol_a.distance_to(w.patrol_b) > 10.0, "要左右來回走一段")
	# 剛生出來的角色這一幀還沒進物理世界，移動不了；檢查它想往巡邏點走、不開槍就好
	var mag: int = w.viewmodel.weapon.mag
	for i in 30:
		w._bot_step(1.0 / 60.0)
	var to_b: Vector3 = (w.patrol_b - w.global_position) * Vector3(1, 0, 1)
	_ck(Vector3(w.velocity.x, 0, w.velocity.z).dot(to_b.normalized()) > 1.0,
		"移動標靶要往巡邏點走（速度 %s）" % w.velocity)
	_ck(w.viewmodel.weapon.mag == mag, "移動標靶不開槍")
	var b: Node3D = m.add_bot()
	_ck(b.bot and not b.walker, "牛仔 bot 要會打")
	_ck(b._bot_threat(m) == m.players.get_node(^"1"), "沙盒裡 bot 要找玩家打，不去打站樁的靶")
	_ck(m.players.get_child_count() == before + 2, "要多兩個電腦")
	# 打死移動標靶：生回來還是移動標靶
	var wid: int = w.name.to_int()
	w.take_damage(9999)
	w.free()
	m._respawn_queue[-1]["at"] = m._time_left + 1.0
	m._respawn_step()
	var back: Node = m.players.get_node_or_null(NodePath(str(wid)))
	_ck(back != null and back.walker, "移動標靶打死要生回移動標靶")
	m.clear_bots()
	var left := 0
	for p in m.players.get_children():
		if Fighter.is_bot_id(p.name.to_int()):
			left += 1
	_ck(left == 0 and m.players.get_child_count() == before, "清除要把電腦都清掉（剩 %d 個）" % left)
	_end(m)

## 牛仔的操作都要有綁鍵，鍵盤和手把兩邊都要（FNE 的約定）
## 滑鼠視角：鎖滑鼠全部走 Fighter.lock_mouse()，擋殘留位移的時間從「鎖定那一刻」算，不是從玩家第一次動滑鼠才算
## （不然剛進遊戲、關 Esc 選單、重生，一動滑鼠就被凍住，2026-10-02 回報）
func _case_mouse_lock() -> void:
	var src := FileAccess.get_file_as_string("res://main.gd")
	_ck(not src.contains("Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"), "main.gd 鎖滑鼠要走 Fighter.lock_mouse()，不要直接設")
	_ck(not FileAccess.get_file_as_string("res://fighter.gd").contains("var _settle_until"),
		"擋殘留位移的時間不能記在各角色身上（重生的新角色會重新等）")
	var t0 := Time.get_ticks_msec()
	Fighter.lock_mouse()   # headless 鎖不住，所以每次都會走到「剛鎖定」那段
	var wait := Fighter._look_from - t0
	if OS.get_name() == "macOS":
		_ck(wait > 0 and wait <= Fighter.LOOK_SETTLE_MS + 50, "macOS 鎖定後擋 %d 毫秒，從鎖定那一刻算（現在 %d）" % [Fighter.LOOK_SETTLE_MS, wait])
	else:
		_ck(wait <= 0, "macOS 以外鎖定後不擋滑鼠（現在擋 %d 毫秒）" % wait)
	Fighter._look_from = 0

func _case_input_map() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
			"crouch", "crouch_toggle", "fire", "aim", "reload", "melee", "interact"]:
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
	_ck(m.players.get_child_count() == 3 and m._cowboys == 2, "要能馬上重開一局（連線模式大家都是牛仔）")
	_ck(m.players.has_node(NodePath(str(m.BOSS_ID))), "連線模式開房要自動生恐龍 boss")
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
	d.global_position = m._on_ground(Vector3(c.x, 2.0, c.y + d_side))   # 穀倉在整平的農莊裡，兩側一樣高
	d.look_at(m._on_ground(Vector3(c.x, 2.0, c.y - d_side)))  # 面向建築

	# 對照組：同一側，中間沒東西擋（射程放大到 100，只想單獨測視線）
	t.global_position = d.global_position + Vector3(0, 0, -3)
	d._hit_nearby(100.0, d.BITE_DAMAGE, 0.3)
	_ck(t.hp == t.max_hp - d.BITE_DAMAGE, "沒遮蔽時應該打得到")

	# 實驗組：躲到建築後面
	t.global_position = m._on_ground(Vector3(c.x, 2.0, c.y - d_side))
	var before: int = t.hp
	d._hit_nearby(100.0, d.BITE_DAMAGE, 0.3)
	_ck(t.hp == before, "躲在建築後面就不該被打到")
	_end(m)

## 專用伺服器（測試站）：一局結束自動開下一局，人和 boss 都還在
func _case_dedicated_round() -> void:
	var m := _offline_match()
	m._dedicated = true
	m._add_player(m.COWBOY, 2)
	m.spawn_boss()
	m._over = true
	m._next_round = 0.0
	m._physics_process(0.1)
	_ck(not m._over and m._time_left > m.MATCH_SECONDS - 1.0, "專用伺服器一局結束要自動開下一局")
	_ck(m.players.has_node(^"2") and m.players.has_node(NodePath(str(m.BOSS_ID))), "開下一局玩家和 boss 都要還在")
	_ck(m._cowboys == 1, "開下一局牛仔數要重算（現在 %d）" % m._cowboys)
	_end(m)

## 方位條：0 = 北（-Z），順時針，東 = 90
func _case_compass() -> void:
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(0, 0, -10)), 0.0), "正北（-Z）是 0 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(10, 0, 0)), 90.0), "正東（+X）是 90 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(0, 0, 10)), 180.0), "正南（+Z）是 180 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(-10, 0, 0)), 270.0), "正西（-X）是 270 度")

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
	_ck(m.BOSS_ACTS.size() == b.ACT_SPOT + 1, "每個動作狀態都要有除錯名稱（BOSS_ACTS 有 %d 個）" % m.BOSS_ACTS.size())
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
	b._pounce_cd = 0.0
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
	b._sweep_cd = 0.0
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
	b._sweep_cd = 0.0
	b.think(1.0 / 60.0)
	for i in int(b.CHARGE_WIND * 60) + 3:
		b.think(1.0 / 60.0)
	_ck(c.hp == c.max_hp - b.SWEEP_DAMAGE, "蓄力完要掃到背後的人")
	# 撲擊：起跳那一刻方向鎖死，之後閃開就撲不到
	c.hp = c.max_hp
	b.act = b.ACT_NONE
	b._attack_gap = 0.0
	b._sweep_cd = 99.0
	b._pounce_cd = 0.0
	b.global_position = m._on_ground(Vector3(0, 4.2, 60))
	b.rotation.y = 0.0
	c.global_position = m._on_ground(Vector3(0, 0.1, 44))   # 正前方 16 公尺
	_ck(b.pounce_clear(c.global_position), "靶場那條路上撲過去的路線要是空的")
	b._seen_left = b.MEMORY   # 已經在追他了（剛看丟又看到的人不用重新確定）
	b.think(1.0 / 60.0)
	_ck(b.act == b.ACT_POUNCE_WIND, "中距離正前方要撲（現在 act=%d）" % b.act)
	for i in int(b.POUNCE_WIND * 60) + 2:
		b.think(1.0 / 60.0)
	c.global_position = m._on_ground(Vector3(8, 0.1, 44))   # 起跳之後往旁邊閃
	for i in 70:
		b.think(1.0 / 60.0)
	_ck(c.hp == c.max_hp, "起跳後方向鎖死，往旁邊閃要撲不到（%d）" % c.hp)
	# 自己的體力：一直跑會見底，見底只能走，回到一定量才能再跑
	c.global_position = Vector3(0, 500, 0)
	b.act = b.ACT_NONE
	for i in 600:
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
	_ck(both_down == 0 and lifts[0] >= 2 and lifts[1] >= 2 and hi - lo > 0.4,
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

## 0.8.1 回饋的介面：大廳順序和存 IP、勝負畫面、重開一局、倒數、boss 體力條、右上角
## 問題回報：錯誤會被記下來、警告不算，F8 存出來的檔有版本、遊戲狀況和錯誤內容
func _case_bug_report() -> void:
	var m := _new_offline_game()
	var r := BugReport.instance
	_ck(r != null, "開遊戲要掛上 bug 收集器")
	r.take_new_error()
	var before := r.error_count()
	push_warning("bug 收集器測試：這是警告")
	_ck(r.error_count() == before and not r.take_new_error(), "警告不算錯誤，不跳提示")
	push_error("bug 收集器測試：這是錯誤")
	push_error("bug 收集器測試：這是錯誤")
	_ck(r.error_count() == before + 1 and r.take_new_error(), "錯誤要記下來、跳提示，同一個只記一次")
	var path: String = m.report_bug()
	_ck(path != "" and FileAccess.file_exists(path), "F8 要存出回報檔（%s）" % path)
	var text := FileAccess.get_file_as_string(path)
	_ck(text.contains("版本：0.8.5") or text.contains("版本：" + str(ProjectSettings.get_setting("application/config/version"))),
		"回報要有版本")
	_ck(text.contains("這是錯誤") and text.contains("共 2 次"), "回報要有錯誤內容和次數")
	_ck(text.contains("遊戲：") and text.contains("當"), "回報要寫在玩什麼、當誰")
	DirAccess.remove_absolute(path)
	# 遊戲裡的版本要跟打包設定一樣（打包只改 export_presets.cfg 的話，回報的版本會是舊的）
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var ver := ""
	for sec in cfg.get_sections():
		if cfg.has_section_key(sec, "application/version"):
			ver = cfg.get_value(sec, "application/version")
	_ck(ver == ProjectSettings.get_setting("application/config/version"),
		"project.godot 的 config/version（%s）要跟 export_presets.cfg 的版本（%s）一樣" % [ProjectSettings.get_setting("application/config/version"), ver])
	_end(m)

func _case_ui() -> void:
	var m := _new_game()
	var lobby: Node = m.lobby
	_ck(lobby.get_node(^"HostBtn").get_index() < lobby.get_node(^"JoinBtn").get_index()
		and lobby.get_node(^"JoinBtn").get_index() < lobby.get_node(^"IPRow").get_index(),
		"大廳順序要是：開房、加入、IP 列")
	# 存 IP：換一個測試用的檔，不動到真的清單
	m.saved_ips_path = "user://test_saved_ips.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.saved_ips_path))
	m._load_saved_ips()
	_ck(m.saved_ips.disabled, "沒存過 IP 時「⋯」要是灰的")
	m.ip_edit.text = "10.1.2.3"
	m._on_save_ip_pressed()
	m._on_save_ip_pressed()
	var popup: PopupMenu = m.saved_ips.get_popup()
	_ck(popup.item_count == 1 and popup.get_item_text(0) == "10.1.2.3", "「＋」要存下目前的 IP，而且不重複")
	m.ip_edit.text = ""
	popup.index_pressed.emit(0)
	_ck(m.ip_edit.text == "10.1.2.3", "「⋯」選了要填回 IP 欄")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.saved_ips_path))

	# boss 體力條：牛仔看不到
	var boss: Node = m.spawn_boss()
	m._update_boss_bar(m.players.get_node(^"2"))
	_ck(not m._boss_bar.visible, "當牛仔時不該看到 boss 體力條")

	# 倒數：死了之後方位條下面出現重生倒數；撤離中出現撤離倒數
	var me: Node = m.players.get_node(^"2")
	m._update_center_info(me)
	m._update_center_info(null)
	_ck(m.center_info.text.contains("秒後重生"), "死了要顯示重生倒數（現在「%s」）" % m.center_info.text)
	m._update_center_info(me)
	m.egg.carrier = 3
	m.egg.extract = 2.0
	m._update_center_info(me)
	_ck(m.center_info.text.contains("還剩 3.0"), "撤離要倒數（現在「%s」）" % m.center_info.text)
	m.egg.extract = 0.0
	m.egg.carrier = 0

	# 勝負：畫面中間大字＋按鈕；主機按重開一局就開新的一局，bot 照樣是 bot
	var bot: Node = m.add_bot()
	var bot_id := bot.name
	m._over = true
	m._finish("時間到，沒有人把蛋帶走")
	_ck(m.result.visible and m.get_node(^"UI/Root/Result/Box/Text").text.contains("時間到"), "勝負要顯示在畫面中間")
	_ck(m.get_node(^"UI/Root/Result/Box/RestartBtn").visible, "開房的人要看得到重開一局")
	m._on_restart_pressed()
	_ck(not m.result.visible and not m._over, "重開一局後勝負畫面要收掉、比賽重新開始")
	_ck(m.players.get_node(NodePath(bot_id)).bot, "重開一局後 bot 還是 bot")
	m._update_net_info()
	_ck(m.net_info.text.contains("本機 IP") and m.net_info.text.contains("FPS"), "右上角要有本機 IP 和 FPS（現在「%s」）" % m.net_info.text)
	_ck(m.get_tree().get_nodes_in_group(&"exit_pipe").size() == m._exits.size() * 2, "每個撤離點中間都要有綠色水管")
	m._to_lobby("")
	_ck(not m.result.visible and not m._boss_bar.visible, "回大廳後勝負畫面和 boss 體力條都要收掉")
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

## 場地四周要有牆，而且要高過恐龍「跳 + 爬」能到的高度
func _case_arena_walls() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	# 圍牆不給爬，所以恐龍能到的最高點 = 站上最高的屋頂再跳一下
	var jump_h: float = d.JUMP_SPEED * d.JUMP_SPEED / (2.0 * d.GRAVITY)
	var reach: float = Terrain.AMP + m.BUILDING_MAX_H + jump_h
	_ck(m.WALL_H > reach,
		"圍牆 %.0f 公尺要高過「最高的地 %.0f + 最高屋頂 %.0f + 跳 %.1f」= %.1f 公尺"
		% [m.WALL_H, Terrain.AMP, m.BUILDING_MAX_H, jump_h, reach])

	# 建築不能蓋超過上限，不然上面那條就白算了
	var tallest := 0.0
	for c in m.get_node(^"Arena").get_children():
		if c.is_in_group(&"arena_wall") or c.name == &"FarLand":   # 遠景在牆外、沒有碰撞，不是建築
			continue
		for mi in c.get_children():
			if mi is MeshInstance3D:
				tallest = maxf(tallest, mi.get_aabb().size.y)
	_ck(tallest <= m.BUILDING_MAX_H + 0.01,
		"最高的建築 %.1f 不能超過上限 %.0f" % [tallest, m.BUILDING_MAX_H])

	var walls := m.get_tree().get_nodes_in_group(&"arena_wall")
	_ck(walls.size() == 4, "四面都要有圍牆（現在 %d 面）" % walls.size())
	_end(m)

## 開一局恐龍對三個牛仔 bot，等下面的 _phase 3 看牛仔 bot 會不會自己跑
func _start_bot_case() -> void:
	_phase = 3
	_bot_game = _dino_vs_bots()
	_bot_cowboy = _bot_game.players.get_node(^"2")
	_bot_from = Vector2(_bot_cowboy.global_position.x, _bot_cowboy.global_position.z)

## 牛仔開槍要真的打中恐龍（射線要等位置進物理世界，所以跨幀，見 _phase 0）
func _start_gun_case() -> void:
	var m := _new_game()
	# 沙盒靶場那條整平的空地：子彈不會先打到建築或小丘
	var spot: Vector3 = m._on_ground(Vector3(0, 0, 60))
	_dino = m.players.get_node(^"1")
	_dino.global_position = spot + Vector3(0, 4.1, -15.0)   # 原點在身體中心，腳剛好著地
	_shooter = m.players.get_node(^"3")
	_shooter.global_position = spot
	# 牛仔 2 貼在恐龍另一側練槍托（恐龍半徑 2.4，站 3.4 公尺外剛好在 2.2 的近戰距離內）
	_brawler = m.players.get_node(^"2")
	_brawler.global_position = spot + Vector3(0, 0, -15.0 - 3.4)
	_brawler.rotation.y = PI   # 面向 +Z，對著恐龍

## 重擊比輕擊痛；體力見底照樣重擊
func _check_melee_hits() -> void:
	var vm: Node = _brawler.viewmodel
	_brawler.stamina = _brawler.max_stamina
	var hp0: int = _dino.hp
	vm.try_melee(true)
	_ck(hp0 - _dino.hp == vm.heavy_damage, "重擊要打出 %d 傷（打出 %d）" % [vm.heavy_damage, hp0 - _dino.hp])
	_ck(is_equal_approx(_brawler.stamina, _brawler.max_stamina - vm.heavy_stamina),
		"重擊要扣 %.0f 體力" % vm.heavy_stamina)
	_brawler.stamina = 0.0
	vm._melee_cooldown = 0.0
	hp0 = _dino.hp
	vm.try_melee(true)
	_ck(hp0 - _dino.hp == vm.heavy_damage, "體力見底照樣重擊（打出 %d）" % (hp0 - _dino.hp))
