extends "res://tests/base.gd"
## 世界：灰盒地圖、鄉村、地形、互動、翻越、掩蔽、場地牆、派對地圖、特效與環境音

## 鄉村：柵欄翻得過去、有穀倉可以爬、沙盒靶場沒被蓋東西
func _case_rural() -> void:
	var m := _new_game()
	var c: Node = m.players.get_node(^"2")
	_ck(ArenaMap.FENCE_H >= c.vault_min_height and ArenaMap.FENCE_H <= c.vault_max_height,
		"柵欄 %.1f 公尺要在翻越範圍 %.1f~%.1f 內" % [ArenaMap.FENCE_H, c.vault_min_height, c.vault_max_height])
	# 灌木叢：夠多、不長在建築裡和路上；蹲在裡面才藏得住（站著頭會露出來）
	_ck(m.map._bushes.size() > m.ARENA * m.ARENA / 500.0, "要有灌木叢可以躲（現在 %d 叢）" % m.map._bushes.size())   # 每 500 平方公尺至少一叢
	var bad := 0
	for b: Vector3 in m.map._bushes:
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
		var mid: Vector3 = d.global_position + Vector3(ArenaMap.BARN_BACK_W * 0.5 * sc.x, cap.height * 0.5 + 0.05, 0)
		q.transform = Transform3D(Basis(), mid)
		var hits := m.get_viewport().world_3d.direct_space_state.intersect_shape(q, 4)
		_ck(hits.is_empty(), "穀倉後門要過得去（縮放 %.2f × %.2f，%s 卡住）" % [sc.x, sc.y, "站著" if sc.y > 0.8 else "蹲著"])
	_ck(backs > 0, "場上要有穀倉後門")
	c.global_position = m.map._bushes[0] + Vector3(0.3, 0.2, 0)
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
	var probs := LevelCheck.run(m.map._level)
	_ck(probs.is_empty(), "擺設檢查有問題：%s" % [probs.slice(0, 5)])
	_ck(not LevelCheck.run([{kind = &"kit", name = &"Crate", pos = Vector3(3, 0, 40), yaw = 0.0},
		{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = 0.3}]).is_empty(), "擺設檢查要抓得到木箱卡在柵欄裡")
	_ck(not LevelCheck.run([{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = 0.0},
		{kind = &"fence", pos = Vector3(3, 0, 40), length = 10.0, yaw = -PI * 0.5}]).is_empty(), "擺設檢查要抓得到兩道柵欄交叉")
	_ck(LevelCheck.run([{kind = &"fence", pos = Vector3(60, 0, 40), length = 10.0, yaw = 0.0},   # 離開沙盒靶場
		{kind = &"fence", pos = Vector3(65, 0, 45), length = 10.0, yaw = -PI * 0.5},
		{kind = &"kit", name = &"HayBlock", pos = Vector3(63, 0, 30), yaw = 0.0},
		{kind = &"kit", name = &"HayBlock", pos = Vector3(63, ArenaMap.HAY_BLOCK.y, 30), yaw = 0.0}]).is_empty(), "柵欄在轉角接起來、草捆疊高不算重疊")
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
	var b: Rect2 = m.map._blocked[0]
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
	m.map._grass_field(spots)   # 沒畫面時 _build_arena 不長草，這裡直接長一次，拿位置清單來檢查
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
	var b: Rect2 = m.map._blocked[0]
	var c := b.get_center()
	var wall_x: float = c.x + (b.size.x - 2.0 * ArenaMap.SPAWN_CLEARANCE) * 0.5
	me.global_position = m._on_ground(Vector3(wall_x + 0.7, 0, c.y + 3.0))
	me.rotation = Vector3(0, PI * 0.5, 0)   # 面向 -X，對著穀倉右牆
	me.stamina = me.max_stamina
	_ck(not me.try_vault(true), "穀倉的牆太高，不能翻")
	_ck(not me.try_vault(false), "沒按住往前不能翻")
	_end(m)

## 中間隔著建築物，恐龍就咬不到——牛仔躲掩蔽的依據
func _case_cover() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var t: Node = m.players.get_node(^"2")
	m.players.get_node(^"3").global_position = Vector3(0, 500, 0)  # 閃遠一點別干擾

	var b: Rect2 = m.map._blocked[0]        # 第一棟建築（含 8 公尺出生淨空）在 XZ 的範圍
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

## 灰盒地圖（預設的主地圖）：擺設乾淨、固定正午不開像素風；牛仔進得了一般門、恐龍只進得了大門；斜坡上得了二樓
func _case_greybox() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _offline_match()
	_ck(m.level_path == Main.GREYBOX_LEVEL and m.greybox, "主地圖要是灰盒")
	_ck(m.period == &"noon" and not m.get_node(^"PixelStyle").on, "灰盒固定正午、不開像素風")
	var probs := LevelCheck.run(m.map._level, Main.lane_of(m.level_path))
	_ck(probs.is_empty(), "灰盒擺設檢查有問題：%s" % [probs.slice(0, 5)])
	var c: Node3D = m._add_player(m.COWBOY, 2)
	var cow: CapsuleShape3D = c.get_node(^"CollisionShape3D").shape
	var boss: Node = m.BOSS.instantiate()
	var dino: CapsuleShape3D = boss.get_node(^"CollisionShape3D").shape
	boss.free()
	var ground: StaticBody3D = m.get_tree().get_first_node_in_group(&"ground")
	var space: PhysicsDirectSpaceState3D = m.get_viewport().world_3d.direct_space_state
	## 膠囊站在這棟的前門正中間（地板上）會不會卡到東西
	var stuck := func(body: Node3D, rec: Dictionary, cap: CapsuleShape3D) -> bool:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.exclude = [ground.get_rid()]
		q.transform = Transform3D(body.global_basis, body.global_transform * Vector3(0, cap.height * 0.5 + Greybox.FLOOR + 0.05, rec.size.z * 0.5 - Greybox.T * 0.5))
		return not space.intersect_shape(q, 1).is_empty()
	var small := 0
	var big := 0
	for rec: Dictionary in m.map._level:
		if rec.kind != &"gb_house":
			continue
		var body: Node3D = null
		for n in m.get_node(^"Arena").get_children():
			if n is StaticBody3D and n.global_position.is_equal_approx(m._on_ground(rec.pos)):
				body = n
		_ck(not stuck.call(body, rec, cow), "牛仔要走得過灰盒房子的前門（%s）" % rec.pos)
		if rec.big:
			big += 1
			_ck(not stuck.call(body, rec, dino), "恐龍要走得過大門（%s）" % rec.pos)
		else:
			small += 1
			_ck(stuck.call(body, rec, dino), "恐龍不能擠進一般門（%s）" % rec.pos)
			# 門寬就是 DOOR.x：比門寬 0.2 的薄板放在門洞會碰到兩邊的牆（膠囊只證明門比恐龍窄）
			var q := PhysicsShapeQueryParameters3D.new()
			var slab := BoxShape3D.new()
			slab.size = Vector3(Greybox.DOOR.x + 0.2, 1.0, 0.05)
			q.shape = slab
			q.transform = Transform3D(body.global_basis, body.global_transform * Vector3(0, 1.0, rec.size.z * 0.5 - Greybox.T * 0.5))
			_ck(not space.intersect_shape(q, 1).is_empty(), "一般門要是 %.1f 公尺寬（%s）" % [Greybox.DOOR.x, rec.pos])
		if rec.floors > 1:   # 斜坡中段：往下打得到坡面（高度在樓高一半），往上不能撞到樓板（頭頂要空）
			var s: Vector3 = rec.size
			var mid := Vector3(-s.x * 0.5 + Greybox.T + Greybox.RAMP_W * 0.5, 0, s.z * 0.5 - Greybox.T - 1.0 - s.y / tan(deg_to_rad(Greybox.RAMP_DEG)) * 0.5)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(body.global_transform * (mid + Vector3.UP * (s.y - 0.5)), body.global_transform * (mid + Vector3.DOWN)))
			_ck(not hit.is_empty() and absf(hit.position.y - body.global_position.y - s.y * 0.5) < 0.3, "上樓的斜坡中段要在樓高一半（%s）" % rec.pos)
			var head := space.intersect_ray(PhysicsRayQueryParameters3D.create(body.global_transform * (mid + Vector3.UP * (s.y * 0.5 + 0.1)), body.global_transform * (mid + Vector3.UP * (s.y * 0.5 + 2.0))))
			_ck(head.is_empty(), "斜坡上頭頂要空著（%s）" % rec.pos)
	_ck(small >= 10 and big >= 2, "灰盒要有一般房子和恐龍進得去的大建築（%d、%d）" % [small, big])
	# 灰盒房子、方塊只有中心貼地、整塊水平：佔地四角的地面不能高過中心太多（埋掉）或低過埋深（浮起來），不平就要加整平區
	var tilted := []
	for rec: Dictionary in m.map._level:
		if rec.kind != &"gb_house" and rec.kind != &"gb_block":
			continue
		var y0: float = m._terrain.height(rec.pos.x, rec.pos.z)
		var basis := Basis(Vector3.UP, rec.yaw)
		for corner: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var at: Vector3 = rec.pos + basis * (corner * rec.size * 0.5)
			var dy: float = m._terrain.height(at.x, at.z) - y0
			# 房子門口要平（0.3）；小方塊埋掉三分之一以內還看得出來、翻得過
			if dy > (0.3 if rec.kind == &"gb_house" else rec.size.y * 0.35) or dy < -Greybox.BURY + 0.1:
				tilted.append("%s %.1f" % [rec.pos, dy])
				break
	_ck(tilted.is_empty(), "灰盒物件底下的地不平（中心位置、高低差）：%s" % [tilted])
	# 畫出來的地形（格點內插，fast_height）不能高過一樓地板：會從地板穿出來一塊塊閃（2026-10-19 回報的室內反光）
	var poke := []
	for rec: Dictionary in m.map._level:
		if rec.kind != &"gb_house":
			continue
		var top: float = m._terrain.height(rec.pos.x, rec.pos.z) + Greybox.FLOOR - 0.01
		var basis := Basis(Vector3.UP, rec.yaw)
		for i in 81:
			var at: Vector3 = rec.pos + basis * Vector3((i % 9 / 8.0 - 0.5) * rec.size.x, 0, (i / 9 / 8.0 - 0.5) * rec.size.z)
			if m._terrain.fast_height(at.x, at.z) > top:
				poke.append(rec.pos)
				break
	_ck(poke.is_empty(), "地形從灰盒房子的地板穿出來：%s" % [poke])
	# 柵欄一段只有兩端貼地、中間是直的：沿線的地面不能比柵欄底部低（中段懸空能從底下鑽過）或高太多（埋掉）
	var hanging := []
	for rec: Dictionary in m.map._level:
		if rec.kind != &"fence":
			continue
		var dir: Vector3 = Basis(Vector3.UP, rec.yaw) * Vector3.RIGHT * rec.length * 0.5
		var a: Vector3 = m._on_ground(rec.pos - dir)
		var b: Vector3 = m._on_ground(rec.pos + dir)
		for i in 11:
			var at := a.lerp(b, i / 10.0)
			var dy: float = m._terrain.height(at.x, at.z) - at.y
			if dy < -0.3 or dy > 0.5:
				hanging.append("%s %.1f" % [rec.pos, dy])
				break
	_ck(hanging.is_empty(), "灰盒的柵欄要貼著地（中心位置、地面減柵欄底）：%s" % [hanging])
	_end(m)
	Main.level_file = keep

## 場地四周要有牆，而且要高過恐龍「跳 + 爬」能到的高度
func _case_arena_walls() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	# 圍牆不給爬，所以恐龍能到的最高點 = 站上最高的屋頂再跳一下
	var jump_h: float = d.JUMP_SPEED * d.JUMP_SPEED / (2.0 * d.GRAVITY)
	var reach: float = Terrain.AMP + ArenaMap.BUILDING_MAX_H + jump_h
	_ck(ArenaMap.WALL_H > reach,
		"圍牆 %.0f 公尺要高過「最高的地 %.0f + 最高屋頂 %.0f + 跳 %.1f」= %.1f 公尺"
		% [ArenaMap.WALL_H, Terrain.AMP, ArenaMap.BUILDING_MAX_H, jump_h, reach])

	# 建築不能蓋超過上限，不然上面那條就白算了
	var tallest := 0.0
	for c in m.get_node(^"Arena").get_children():
		if c.is_in_group(&"arena_wall") or c.name == &"FarLand":   # 遠景在牆外、沒有碰撞，不是建築
			continue
		for mi in c.get_children():
			if mi is MeshInstance3D:
				tallest = maxf(tallest, mi.get_aabb().size.y)
	_ck(tallest <= ArenaMap.BUILDING_MAX_H + 0.01,
		"最高的建築 %.1f 不能超過上限 %.0f" % [tallest, ArenaMap.BUILDING_MAX_H])

	var walls := m.get_tree().get_nodes_in_group(&"arena_wall")
	_ck(walls.size() == 4, "四面都要有圍牆（現在 %d 面）" % walls.size())
	_end(m)

## 派對模式的地圖（灰盒）：安全屋兩間（牛仔進得去、恐龍擠不進）、牛仔出生點散在四周、恐龍在中央出生
func _case_party_map() -> void:
	var Main: GDScript = load("res://main.gd")
	var keep: String = Main.level_file
	Main.level_file = ""
	var m := _offline_match()
	var probs := LevelCheck.run(m.map._level, Main.lane_of(m.level_path))
	_ck(probs.is_empty(), "派對地圖擺設檢查有問題：%s" % [probs.slice(0, 5)])
	var safes: Array = m.get_tree().get_nodes_in_group(&"safe_house")
	_ck(safes.size() == 2, "安全屋要 2 間（%d）" % safes.size())
	var c: Node3D = m._add_player(m.COWBOY, 2)
	var cow: CapsuleShape3D = c.get_node(^"CollisionShape3D").shape
	var boss: Node = m.BOSS.instantiate()
	var dino: CapsuleShape3D = boss.get_node(^"CollisionShape3D").shape
	boss.free()
	var ground: StaticBody3D = m.get_tree().get_first_node_in_group(&"ground")
	var space: PhysicsDirectSpaceState3D = m.get_viewport().world_3d.direct_space_state
	## 膠囊站在安全屋裡 at（房子自己的座標，地板上）會不會卡到東西
	var stuck := func(body: Node3D, at: Vector3, cap: CapsuleShape3D) -> bool:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.exclude = [ground.get_rid()]
		q.transform = Transform3D(body.global_basis, body.global_transform * (at + Vector3.UP * (cap.height * 0.5 + Greybox.FLOOR + 0.05)))
		return not space.intersect_shape(q, 1).is_empty()
	var exits: Array = ArenaMap.exit_spots()
	for rec: Dictionary in m.map._level:
		if rec.kind != &"gb_safe":
			continue
		var inner: Vector3 = rec.size - Vector3.ONE * Greybox.T * 2.0
		_ck(inner.x * inner.z > 14.0 and inner.x * inner.z < 20.0, "安全屋內部要約 5 坪（%.1f 平方公尺）" % (inner.x * inner.z))
		var body: Node3D = null
		for b: Node3D in safes:
			if b.global_position.is_equal_approx(m._on_ground(rec.pos)):
				body = b
		_ck(body != null, "安全屋 %s 要有蓋出來的房子" % rec.pos)
		if body == null:
			continue
		var door := Vector3(0, 0, rec.size.z * 0.5 - Greybox.T * 0.5)
		_ck(not stuck.call(body, door, cow) and not stuck.call(body, Vector3.ZERO, cow), "牛仔要走得進安全屋（%s）" % rec.pos)
		_ck(stuck.call(body, door, dino) and stuck.call(body, -door, dino), "恐龍不能擠進安全屋的門（%s）" % rec.pos)
		var xz := Vector2(rec.pos.x, rec.pos.z)
		_ck(xz.length() > 50.0 and exits.all(func(e: Vector2) -> bool: return xz.distance_to(e) > 40.0),
			"安全屋要離蛋區和撤離區有一段路（%s）" % rec.pos)
		var y0: float = m._terrain.height(rec.pos.x, rec.pos.z)
		for corner: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var at: Vector3 = rec.pos + Basis(Vector3.UP, rec.yaw) * (corner * rec.size * 0.5)
			_ck(absf(m._terrain.height(at.x, at.z) - y0) < 0.3, "安全屋底下的地要平（%s）" % rec.pos)
	_ck(m.spawn_points.size() >= 6, "牛仔出生點至少 6 個（%d）" % m.spawn_points.size())
	var sides := {}
	for p: Vector3 in m.spawn_points:
		_ck(m._is_clear(Vector2(p.x, p.z)), "出生點不能在建築裡（%s）" % p)
		sides[Vector2i(signi(roundi(p.x / 40.0)), signi(roundi(p.z / 40.0)))] = true
	_ck(sides.size() >= 5, "出生點要散在地圖四周（只在 %d 個方向）" % sides.size())
	_ck(Vector2(m.dino_spawn.x, m.dino_spawn.z).length() < 10.0 and absf(m.dino_spawn.y - m._terrain.height(m.dino_spawn.x, m.dino_spawn.z)) < 0.01,
		"恐龍出生點要在中央、貼地（%s）" % m.dino_spawn)
	_end(m)
	Main.level_file = keep
