extends "res://tests/ui.gd"

## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var Main: GDScript = load("res://main.gd")
		Main.level_file = Main.RANCH_LEVEL   # 舊案例都是照牧場寫的（穀倉門、柵欄、農舍）；灰盒另外測（_case_greybox）
		_case_greybox()
		_case_timeout()
		_case_dino_death()
		_case_attacks()
		_case_offline()
		_case_offline_dino()
		_case_cowboy()
		_case_input_map()
		_case_mouse_lock()
		_case_hunt_weapons()
		_case_hunt_keys()
		_case_medkit()
		_case_sandbox()
		_case_range()
		_case_net_smooth()
		_case_net_check()
		_case_rural()
		_case_fx_and_ambience()
		_case_terrain()
		_case_interact()
		_case_vault()
		_case_modes()
		_case_match_rules()
		_case_solo_dino()
		_case_dino_sandbox()
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
		_case_corpse()
		_case_fireball()
		_case_dino_attack_switch()
		_case_light_cone()
		_case_stomp()
		_case_burn()
		_case_boss_fireball()
		_case_ui()
		_case_bug_report()
		_case_stagger()
		_case_arena_walls()
		_case_boss()
		_case_compass()
		_case_settings()
		_case_dedicated_round()
		_case_cowboy_voice()
		_case_versus()
		_case_party_boss()
		_case_party_map()
		_case_party_destruction()
		_case_party_hud()
		_case_party_gameplay()
		_case_reconnect()
		_case_balance()
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
				_check_foot_ik()
				_check_pierce_flight()
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
		4:  # 火球的物理：要跨物理幀，見 dino.gd 的 _start_fireball_case
			if _fb_step():
				return _done()
		3:  # 移動靶要真的跑起來（move_and_slide 只在物理幀有效，所以得跨幀等）
			_bot_frames += 1
			var now := _bot_cowboy.global_position
			if _bot_from.distance_to(Vector2(now.x, now.z)) > 3.0:
				_end(_bot_game)
				_start_fireball_case()   # 火球的物理要跨幀，接在後面（_phase 4）
				return false
			if _bot_frames > 500:
				_ck(false, "牛仔 bot 沒有自己跑起來")
				_end(_bot_game)
				return _done()
	return false
