extends "res://tests/world.gd"
## 戰鬥：牛仔、獵人式武器、腳貼地、攻擊、火球、踉蹌、屍體、牛仔叫聲、近戰與穿透

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

## 先讓腳貼地收斂，再把站立動作倒回第 0 格量（站著也會微微晃，不同時間量會差幾公分）
func _ik_ankles() -> Vector2:
	for i in 20:
		_ik_rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_NONE, 0.0)
	_ik_rig.anim.seek(0.0, true)
	_ik_rig.update(0.0, 0.0, 0.0, CowboyRig.ACT_NONE, 0.0)
	var sk := _ik_rig.skeleton
	var l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin
	var r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightFoot")).origin
	return Vector2(l.y, r.y)


## m 是開槍那場（_start_gun_case）：多放一個牛仔 4 在靶場旁邊，不另開一場（另開的要跨幀才收，會擋到別項）
func _case_foot_ik(m: Node) -> void:
	m._add_player(m.COWBOY, 4)
	var c: Node3D = m.players.get_node(^"4")
	c.set_physics_process(false)   # 位置自己擺，不讓它掉
	c.global_position = m._on_ground(Vector3(20, 0, 60))
	_ik_rig = c._rig
	var ex: Array[RID] = [c.get_rid()]
	var sp := c.get_world_3d().direct_space_state
	c.global_position = sp.intersect_ray(PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP * 30.0, c.global_position + Vector3.DOWN * 30.0, 1, ex)).position
	_ik_flat = _ik_ankles()
	var sk := _ik_rig.skeleton
	var foot_l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin
	var foot_r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightFoot")).origin
	var right_side := Vector3(foot_r.x - foot_l.x, 0.0, foot_r.z - foot_l.z).normalized()
	var ground_l: Vector3 = sp.intersect_ray(PhysicsRayQueryParameters3D.create(foot_l + Vector3.UP, foot_l + Vector3.DOWN, 1, ex)).position
	var box := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.3, 0.3, 0.3)
	box.add_child(shape)
	m.add_child(box)
	# 靠右腳那邊的邊緣在左腳外 4 公分（兩腳只隔 8 公分）；頂面比左腳底下的地高 15 公分
	box.global_position = ground_l - right_side * 0.11


func _check_foot_ik() -> void:
	var d := _ik_ankles() - _ik_flat
	_ck(absf(d.x - 0.15) < 0.01 and absf(d.y) < 0.01, "腳貼地：左腳踩上 15 公分的箱子、右腳不動（左 %+.3f 右 %+.3f）" % [d.x, d.y])
	# 人站到箱子上（原點抬高 15 公分）、右腳伸出箱外：臀部要放低，右腳才踩得到下面的地
	var c := _ik_rig.get_parent().get_parent() as Node3D
	c.global_position += Vector3.UP * 0.15
	d = _ik_ankles() - _ik_flat
	_ck(absf(d.x - 0.15) < 0.01 and absf(d.y) < 0.01, "腳貼地：站在箱子邊，右腳伸下去踩地（左 %+.3f 右 %+.3f）" % [d.x, d.y])
	_ik_rig.update(0.1, 0.0, -4.0, CowboyRig.ACT_NONE, 0.0)
	for i in 10:
		_ik_rig.update(0.1, 0.0, -4.0, CowboyRig.ACT_NONE, 0.0)
	_ck(_ik_rig._ik_w == 0.0, "跳起來、掉下去時腳不貼地")


## 牛仔的身分：自己的有相機和 HUD，別人的（含 bot）全關；打中別人要走 deal_damage
## 腳貼地（IK）：別人的牛仔左腳底下墊一塊 15 公分的箱子，左腳要踩上去、右腳留在地上。
## 箱子要等物理世界跑過一幀射線才打得到：這幀先量平地，第 3 幀（_check_foot_ik）再量
func _case_cowboy() -> void:
	var m := _new_game()   # 主機是恐龍，牛仔 2、3 在主機上都是「別人的」
	var c: Node = m.players.get_node(^"2")
	_ck(not c.is_local, "主機上的牛仔是遠端角色")
	_ck(not c.get_node(^"HUD").visible and not c.viewmodel.visible, "遠端角色的 HUD 和槍都要藏起來")
	_ck(c.get_node(^"Body").visible, "遠端角色要看得到身體")
	# 別人的牛仔是有骨架的模型（CowboyRig）：站著播 idle、走起來換 walk、跑換 run，手上有槍
	var rig: CowboyRig = c._rig
	_ck(rig != null and rig.skeleton.get_bone_count() > 20, "遠端角色要換上有骨架的牛仔")
	var head_y: float = rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("mixamorig_Head")).origin.y
	head_y = rig.to_local(rig.skeleton.global_transform * Vector3(0, head_y, 0)).y
	_ck(absf(head_y - 1.6) < 0.2, "頭的骨頭在 1.6 公尺上下（現在 %.2f）" % head_y)
	rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_NONE, 0.0)
	_ck(rig.anim.current_animation == &"idle", "站著要播 idle（現在 %s）" % rig.anim.current_animation)
	rig.update(0.1, 2.5, 0.0, CowboyRig.ACT_NONE, 0.0)
	_ck(rig.anim.current_animation == &"walk", "舉槍、蹲著走要播 walk")
	_ck(absf(rig.anim.speed_scale * CowboyRig.WALK_PACE - 2.5) < 0.01, "走的時候腳步跟得上移動（倍率 %.2f）" % rig.anim.speed_scale)
	rig.update(0.1, c.walk_speed, 0.0, CowboyRig.ACT_NONE, 0.0)
	_ck(rig.anim.current_animation == &"run", "一般走（其實是小跑）要播 run")
	rig.update(0.1, c.sprint_speed, 0.0, CowboyRig.ACT_NONE, 0.0)
	_ck(rig.anim.current_animation == &"run", "衝刺要播 run")
	# 腳不滑：動作播的步速＝實際移動速度
	_ck(absf(rig.anim.speed_scale * CowboyRig.RUN_PACE - c.sprint_speed) < 0.01, "衝刺時腳步跟得上移動（倍率 %.2f）" % rig.anim.speed_scale)
	rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_LADDER, 0.0)
	_ck(rig.anim.current_animation == &"ladder", "爬梯要播 ladder")
	for i in 30:
		rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_NONE, 0.0)
	var hand_flat: Vector3 = rig.hand("Right")
	_ck(hand_flat.z < -0.1 and hand_flat.y > 0.8 and hand_flat.y < 1.4, "端槍：右手在身體前面、腰到胸的高度（現在 %s）" % hand_flat)
	rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_NONE, 0.6)
	_ck(rig.hand("Right").y > hand_flat.y + 0.1, "抬頭時拿槍的手要跟著抬")
	_ck(rig.get_node_or_null(^"Held") != null, "別人的牛仔手上要有槍")
	rig.hit()
	_ck(rig.anim.current_animation == &"hit_to_body_01", "被打要播中彈")
	for i in 20:   # 重擊按住一秒（冷卻比揮砍那段長）
		rig.update(0.05, 0.0, 0.0, CowboyRig.ACT_MELEE, 0.0)
	_ck(rig.anim.assigned_animation != &"slash", "重擊一次只揮一下，揮完不重播")
	for i in 60:   # 掉很久：停在跳躍最後一格，不重播
		rig.update(0.05, 0.0, -4.0, CowboyRig.ACT_NONE, 0.0)
	_ck(rig.anim.assigned_animation == &"jump" and not rig.anim.is_playing(), "掉很久要停在跳躍的最後一格")
	rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_LADDER, 0.0)
	for i in 10:
		rig.update(0.1, 0.0, 0.0, CowboyRig.ACT_LADDER, 0.0)
	_ck(not rig.holding, "爬梯時手臂放開、槍收起來")
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
	_ck(names == ["左輪", "單管散彈", "槓桿步槍", "炸彈長矛"], "1/2/3/4 要是左輪、單管散彈、槓桿步槍、炸彈長矛（現在 %s）" % [names])
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

	# 設計原則：原地平地跳不能超過柵欄高度（過柵欄要翻越）
	var jump_h: float = me.jump_velocity * me.jump_velocity / (2.0 * ProjectSettings.get_setting("physics/3d/default_gravity"))
	_ck(jump_h < ArenaMap.FENCE_H, "原地跳 %.2f 公尺不能超過柵欄 %.2f 公尺" % [jump_h, ArenaMap.FENCE_H])

	# 換彈會放下槍回腰射：舉滿時按 R，按著右鍵也舉不起來；換完才舉回去
	revolver.mag = 3
	vm.ads = 1.0
	vm.try_reload()
	vm._update_ads(true, 1.0)
	_ck(vm.ads == 0.0, "換彈時要回到腰射（ads %.2f）" % vm.ads)
	vm.cancel_reload()
	vm._update_ads(true, 1.0)
	_ck(vm.ads > 0.0, "換彈結束還按著右鍵要舉回去")
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
	_ck(info.visible and info.get_child_count() == (revolver.info_rows().size() + 1) * (vm._weapons.size() + 1), "Esc 選單要有每把槍的武器介紹")
	var ctl: Settings = m.settings
	m.menu.get_node(^"Box/ControlsBtn").pressed.emit()
	_ck(ctl.visible and ctl.tabs.get_current_tab_control().name == &"按鍵" and Settings.CONTROLS.size() > 10, "Esc 選單按「操作說明」要彈出設定的按鍵頁")
	m._set_menu(false)
	_ck(not ctl.visible, "關掉選單時設定視窗也要一起關（不然一局結束會擋住畫面）")

	# 瞄準按住／切換：玩家的設定要存起來，下次開遊戲還在
	m.settings_path = "user://test_settings.cfg"
	m.settings._on_aim_toggle_toggled(true)
	Viewmodel.aim_toggle = false
	m._load_settings()
	_ck(Viewmodel.aim_toggle, "瞄準切換的設定要存起來")
	m.settings._on_fps_cap_selected(2)
	_ck(Engine.max_fps == m.settings._refresh_hz() / 2, "幀率上限選「螢幕的一半」要鎖在刷新率一半（現在 %d）" % Engine.max_fps)
	m.settings._on_vsync_toggled(false)
	m.settings.fps_cap = 0
	m.settings.vsync = true
	m._load_settings()
	_ck(m.settings.fps_cap == 2 and not m.settings.vsync and Engine.max_fps == m.settings._refresh_hz() / 2, "畫面設定要存起來，重開照樣套用")
	m.settings._on_fps_cap_selected(0)
	m.settings._on_vsync_toggled(true)
	_ck(Engine.max_fps == 0, "選「不限」要拿掉上限")
	m.settings._on_aim_toggle_toggled(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.settings_path))
	for w in vm._weapons:
		_ck(w.reserve > 0, "%s 的備彈要有限（Hunt 的子彈要省著用）" % w.display_name)
		_ck(w.get_node_or_null(^"Model") != null, "%s 要有 Blender 建的模型" % w.display_name)
	_ck(rifle.get_node_or_null(rifle.lever_path) != null, "步槍的拉桿要找得到，不然上膛沒動作")
	_ck(revolver.get_node_or_null(revolver.cylinder_path) != null, "左輪的轉輪要找得到")
	_ck(shotgun.get_node_or_null(shotgun.barrel_path) != null, "散彈的槍管要找得到，換彈才折得開")

	# 腰射時槍管要對準準心：槍管往前 30 m 那一點要落在準心附近（照 Hunt 影片 pax.mov：槍口在準心右邊一點，槍管指向準心）
	revolver._since_fire = 9.0
	revolver._procedural(0.016)
	var cam: Camera3D = me.get_node(^"Head/Camera3D")
	var model: Node3D = revolver.get_node(^"Model")
	var far: Vector3 = revolver.muzzle_global() - model.global_basis.z * 30.0
	var off := rad_to_deg((far - cam.global_position).angle_to(-cam.global_basis.z))
	_ck(off < 2.0, "腰射時左輪槍管要對準準心（現在偏 %.1f 度）" % off)

	# 開槍：程式動作要動起來。Pax：槍口大翻、拇指上去扳擊錘，扳到一半轉輪轉一格
	var turns: int = revolver._turns
	revolver.play(&"fire", 0.1, 0.45)
	_ck(revolver._since_fire == 0.0, "開槍要有後座（槍模型的曲線從頭開始走）")
	# 後座力曲線四段 2:1:1:8：衝到頂、多衝一點、小回彈、慢慢回到留著不回正的那段
	var keep := 0.3
	var at := func(n: float) -> float: return Weapon.recoil_curve(n / 12.0, keep)
	_ck(is_zero_approx(at.call(0.0)) and is_equal_approx(at.call(2.0), 1.0) and is_equal_approx(at.call(3.0), Weapon.RECOIL_OVERSHOOT)
		and is_equal_approx(at.call(4.0), Weapon.RECOIL_BOUNCE) and is_equal_approx(at.call(12.0), keep),
		"後座力曲線的節點要在 0、2、3、4、12 格（%.2f %.2f %.2f %.2f %.2f）" % [at.call(0.0), at.call(2.0), at.call(3.0), at.call(4.0), at.call(12.0)])
	_ck(at.call(1.0) > 0.7, "第一段要先快後慢（走一半就過七成，現在 %.2f）" % at.call(1.0))
	_ck(at.call(8.0) - keep < (Weapon.RECOIL_BOUNCE - keep) * 0.3, "回正段也要先快後慢（走一半就回了七成以上）")
	# 準心：連開兩發，曲線疊起來，走完剩下兩發各自不回正的部分
	var vm1: Node = me.viewmodel
	vm1._kicks.clear()   # 前面的案例開過槍，還沒走完的不要混進來
	var pitch0: float = me.head.rotation.x
	var gun: Weapon = vm1.weapon
	var rnd := gun.recoil_pitch_random
	gun.recoil_pitch_random = 0.0
	var sens0: float = Settings.v.get(&"mouse_sens", 1.0)
	Settings.v[&"mouse_sens"] = 2.0   # 靈敏度只乘滑鼠：調高了後座力也不能跟著變大（下面的度數照舊）
	vm1._apply_recoil()
	for i in 6:
		vm1._update_recoil(DT)
	vm1._apply_recoil()
	for i in 120:
		vm1._update_recoil(DT)
	gun.recoil_pitch_random = rnd
	Settings.v[&"mouse_sens"] = sens0
	var want := deg_to_rad(gun.recoil_pitch) * 2.0 * (1.0 - gun.recoil_return_ratio)
	_ck(vm1._kicks.is_empty() and absf((me.head.rotation.x - pitch0) - want) < 0.001,
		"連開兩發後座力要疊起來，最後留 %.2f 度（留了 %.2f）" % [rad_to_deg(want), rad_to_deg(me.head.rotation.x - pitch0)])
	me.head.rotation.x = pitch0
	# 左輪的手帶骨架（weapon.gd 的 use_rig）：量拇指指尖離擊錘尾端多近
	var hammer: Node3D = revolver.get_node(revolver.hammer_path)
	var sk: Skeleton3D = revolver._grip_sk
	var tip_gap := func() -> float:
		var g := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Thumb_Distal"))
		return (g.origin + g.basis.y.normalized() * Weapon.THUMB_TIP).distance_to(hammer.to_global(revolver.hammer_spur))
	var rest_gap: float = tip_gap.call()
	var near := 1e9
	for i in 60:
		revolver._procedural(0.45 / 50.0)
		near = minf(near, tip_gap.call())
	_ck(revolver._turns == turns + 1, "扳完擊錘轉輪要轉一格")
	_ck(near < 0.01 and near < rest_gap * 0.5, "拇指指尖要伸到擊錘上（最近 %.1f mm，握著時 %.1f mm）" % [near * 1000.0, rest_gap * 1000.0])
	_ck(absf(tip_gap.call() - rest_gap) < 0.002, "扳完拇指要放回握把")
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

	# 穿牆：穿透力 ≥ 牆的硬度才穿（輕 1 中 2 重 3 對 單層木板 1 雙層 2 金屬 3），沒標材質的照擋
	for g: StringName in Bullet.ARMOR:
		var wall := StaticBody3D.new()
		wall.add_to_group(g)
		for p in [1, 2, 3]:
			_ck(Bullet.pierces(wall, p) == (p >= Bullet.ARMOR[g]), "穿透力 %d 打 %s 穿不穿不對" % [p, g])
		wall.free()
	var plain := StaticBody3D.new()
	_ck(not Bullet.pierces(plain, 3), "沒標材質的東西重型也不能穿")
	plain.free()
	_ck(Weapon.AMMO_NAMES.size() == 3, "子彈要有輕、中、重三種")

	# 有效射程：射程內全額，超過遞減，射程盡頭剩一半；射程要照步槍 > 左輪 > 散彈排
	for w in vm._weapons:
		if w.harpoon:
			continue   # 炸彈長矛的魚叉不分遠近都是 40，主要傷害是爆炸
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

## 牛仔叫聲：被打會叫、散彈一次多顆不重來，死掉在原地留一聲慘叫（角色刪掉了聲音還在）
func _case_cowboy_voice() -> void:
	var m := _offline_match()
	var c: Node = m._add_player(m.COWBOY, 2)
	c.take_damage(20)
	_ck(c._voice.playing and c._voice.stream in c.HURT_VOICES, "被打要叫一聲")
	c._voice.stream = c.DEATH_VOICES[0]   # 換成受傷聲裡不會抽到的：重來的話會被換掉（headless 沒辦法看播放進度）
	c._voice.play()
	c.take_damage(5)
	_ck(c._voice.stream == c.DEATH_VOICES[0], "還在叫就不重來（散彈一次十幾顆）")
	var before := m.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D).size()
	c.take_damage(500)
	var after := m.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and n.stream in c.DEATH_VOICES).size()
	_ck(after == 1 and before == 0, "死掉要在場上留一聲慘叫")
	# 別人（bot）的槍聲要有位置，聽得出方向；自己的貼在耳邊
	var bot: Node = m._add_player(m.COWBOY, 3)
	var bw: Node = bot.viewmodel._weapons[0]
	bot.viewmodel._remote_shot(0, bot.global_position, PackedVector3Array([Vector3.FORWARD]), 0)
	var s3 := bw.get_node_or_null(^"ShootSound3D") as AudioStreamPlayer3D
	_ck(s3 != null and s3.playing and not bw.get_node(^"ShootSound").playing, "別人的槍聲要用有位置的播放器")
	# 別人的腳步聲：照量到的速度踩，有位置；站著不動不踩
	var hit: Dictionary = bot._ray(bot.global_position + Vector3.UP * 50.0, bot.global_position + Vector3.DOWN * 50.0)
	_ck(not hit.is_empty(), "bot 腳下要找得到地")
	if hit:
		bot.global_position = hit.position   # 剛生出來還沒落地
	bot._speed = 5.0
	bot._remote_footsteps(1.0)
	_ck(bot._step_sound3 != null and bot._step_sound3.playing, "別人走路要有腳步聲，而且有位置")
	bot._step_sound3.stop()
	bot._speed = 0.0
	bot._remote_footsteps(1.0)
	_ck(not bot._step_sound3.playing, "別人站著不動不能有腳步聲")
	bot._speed = 5.0
	bot.global_position.y += 20.0
	bot._remote_footsteps(1.0)
	_ck(not bot._step_sound3.playing, "別人跳在空中不能有腳步聲")
	var me: Node = m._add_player(m.COWBOY, 1)
	me.viewmodel.weapon.mag = 1
	me.viewmodel._fire_cooldown = 0.0
	me.viewmodel.try_fire()
	_ck(me.viewmodel.weapon.get_node_or_null(^"ShootSound3D") == null, "自己的槍聲貼在耳邊，不用有位置")
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

## 牛仔死掉留一具會癱倒的屍體（corpse.gd）：四塊、不擋人不擋子彈、往被打的反方向倒；自己的那具帶死亡鏡頭
func _case_corpse() -> void:
	var m := _new_offline_game()
	var me: Node3D = m.players.get_node(^"1")
	var dino: Node3D = m.players.get_node(^"2")
	dino.global_position = me.global_position + Vector3(0, 0, -8)   # 恐龍在北邊
	me.take_damage(9999, dino)
	var bodies := m.get_children().filter(func(n: Node) -> bool: return n is Corpse)
	_ck(bodies.size() == 1, "牛仔死掉要留一具屍體（現在 %d 具）" % bodies.size())
	if bodies.size() == 1:
		var k: Corpse = bodies[0]
		_ck(k.parts.size() == 4, "屍體是身體、頭、兩條腿四塊")
		_ck(k.parts.values().all(func(p: RigidBody3D) -> bool: return p.collision_layer == 0), "屍體不擋人、不擋子彈（collision_layer 0）")
		_ck((k.parts.torso as RigidBody3D).linear_velocity.z > 0.0, "恐龍從北邊咬，屍體要往南（+Z）倒")
		_ck(k._cam != null and k._cam.current, "自己的屍體要帶死亡鏡頭")
		var meshes := k.find_children("*", "MeshInstance3D", true, false)
		_ck(meshes.size() == 5, "屍體要有身體、手、頭、兩條腿五個網格（現在 %d）" % meshes.size())
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
	# 穿牆實飛用：高空一面金屬板（要等一個物理幀才進得了物理世界，所以先放、第 3 幀才打）
	_pierce_wall = StaticBody3D.new()
	_pierce_wall.add_to_group(&"metal")
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(4, 4, 0.03)
	_pierce_wall.add_child(cs)
	m.get_node(^"Arena").add_child(_pierce_wall)
	_pierce_wall.global_position = Vector3(0, 400, -5)
	var back := _pierce_wall.duplicate() as StaticBody3D
	back.remove_from_group(&"metal")
	m.get_node(^"Arena").add_child(back)
	back.global_position = Vector3(0, 400, -8)
	_case_foot_ik(m)

## 實際飛一發打金屬板（5 公尺外，後面 8 公尺外一面沒標材質的牆）：輕型停在金屬板，重型穿過去停在後牆
## 子彈走 _launch 生，順便驗子彈種類有變成穿透力
func _check_pierce_flight() -> void:
	var vm: Node = _shooter.viewmodel
	var arena: Node = _pierce_wall.get_parent()
	for ammo in Weapon.AMMO_NAMES.size():
		var before := arena.get_child_count()
		vm._launch(0, Vector3(0, 400, 0), PackedVector3Array([Vector3.FORWARD]), true, ammo)
		var b: Bullet = arena.get_child(before)
		b.fx = null   # 不出著彈聲：測試結束時還在播會算成沒清掉的物件
		_ck(b.power == ammo + 1, "%s型彈穿透力要是 %d（是 %d）" % [Weapon.AMMO_NAMES[ammo], ammo + 1, b.power])
		for i in 20:
			if b.is_queued_for_deletion():
				break
			b.advance(1.0 / 120.0)
		var want := 5.0 if ammo < 2 else 8.0
		_ck(b.is_queued_for_deletion() and absf(b._traveled - want) < 0.1,
			"%s型彈打金屬板要停在 %.0f 公尺（飛了 %.2f）" % [Weapon.AMMO_NAMES[ammo], want, b._traveled])
		b.free()
	for i in vm._weapons.size():
		if vm._weapons[i].harpoon:
			var before := arena.get_child_count()
			vm._launch(i, Vector3(0, 400, 0), PackedVector3Array([Vector3.FORWARD]), true, 2)
			_ck((arena.get_child(before) as Bullet).power == 0, "魚叉什麼都不能穿")
			arena.get_child(before).free()

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
