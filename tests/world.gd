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
	for n in [&"Barn", &"BarnRoof", &"SiloBody", &"SiloDome", &"FenceRail",
			&"FencePost", &"HayBale", &"TreeOak", &"TreeOakM", &"TreeOakS", &"TreePine", &"Bush", &"WheatTuft", &"GrassClump",
			&"Egg", &"Wagon", &"Rock01", &"Rock16", &"Lantern", &"Barrel", &"Crate", &"HayBlock", &"Wheel",
			&"FenceGate", &"GatePost", &"HitchRail", &"Windmill", &"WindmillRotor", &"HayShed", &"HayShedCol",
			&"TreeMaple", &"TreePine2", &"TreeJoshua", &"TreeDead", &"TreeWillow", &"Saguaro", &"SaguaroS", &"BarrelCactus",
			&"PricklyPear", &"GrassTall", &"GrassDense", &"GrassSmall", &"DesertBush", &"ScrubBush"]:
		_ck(m._props.get(n) is Mesh, "模型檔（props、trees、rocks、kits、groves、floras、clutters）裡要有 %s" % n)
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
	_end(m)

## 著彈照材質噴不同碎屑
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
	_end(m)

## 地形：有起伏、該平的地方平、碰撞跟畫面對得上
## 農莊影子合併（levels/farm_destruction/farm_batch.gd）：合了的零件自己不投影子；藏起來（拆掉）當下影子跟著拿掉；換局立回來影子也回來
func _case_farm_shadow_batch() -> void:
	var farm := Node3D.new()
	root.add_child(farm)
	var house := Node3D.new()
	farm.add_child(house)
	var parts: Array[MeshInstance3D] = []
	for i in 3:
		var p := MeshInstance3D.new()
		p.mesh = BoxMesh.new()
		p.position = Vector3(i * 2.0, 0, 0)
		house.add_child(p)
		parts.append(p)
	var glass := MeshInstance3D.new()   # 半透明：不合，照舊自己投影
	glass.mesh = BoxMesh.new()
	var see := StandardMaterial3D.new()
	see.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = see
	house.add_child(glass)
	var wavy := MeshInstance3D.new()   # 著色器會動頂點：不合
	wavy.mesh = BoxMesh.new()
	wavy.material_override = ShaderMaterial.new()
	wavy.material_override.shader = Shader.new()
	wavy.material_override.shader.code = "shader_type spatial;\nvoid vertex() { VERTEX.y += sin(TIME); }"
	house.add_child(wavy)
	var paint := MeshInstance3D.new()   # 著色器只讀頂點（像農莊的牆）：合
	paint.mesh = BoxMesh.new()
	paint.position = Vector3(1, 0, 1)
	paint.material_override = ShaderMaterial.new()
	paint.material_override.shader = Shader.new()
	paint.material_override.shader.code = "shader_type spatial;\nrender_mode cull_back;\nvarying vec3 p;\nvoid vertex() { p = VERTEX; }\nvoid fragment() { ALBEDO = p; }"
	house.add_child(paint)
	var door := RigidBody3D.new()   # 會動的：不合
	var leaf := MeshInstance3D.new()
	leaf.mesh = BoxMesh.new()
	door.add_child(leaf)
	farm.add_child(door)
	var batch: Node = preload("res://levels/farm_destruction/farm_batch.gd").install(farm, true)
	_ck(batch != null and batch.get_children().filter(func(c): return c.name.begins_with("Shadow")).size() == 1, "三塊靠在一起的零件要合成一塊影子")
	var shadow: MeshInstance3D = batch.get_child(0)
	_ck(shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "合併的網格只投影子、自己不畫")
	_ck(parts.all(func(p): return p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and p.visible and batch.casting(p)), "合了的零件自己不投影子，但還在場上、影子在合併網格裡")
	_ck(wavy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and batch.casting(paint), "會動頂點的著色器不合，只讀頂點的合")
	_ck(glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and leaf.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "半透明、會動的零件不合，照舊自己投影子")
	parts[1].visible = false   # 拆掉一塊
	_ck(not batch.casting(parts[1]) and batch.casting(parts[0]), "拆掉的那塊影子當下拿掉，旁邊的不變")
	house.visible = false   # 整棟退場（藏上層）
	_ck(not batch.casting(parts[0]) and not batch.casting(parts[2]), "整棟藏起來影子全拿掉")
	house.visible = true
	parts[1].visible = true   # 換局立回來
	_ck(parts.all(func(p): return batch.casting(p)), "換局立回來影子要全部回來")
	_ck(parts.all(func(p): return p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "立回來後還是由合併網格投影子（不會投兩次）")
	farm.free()

## 農莊畫面合併（P3，同一個檔）：同格同材質的零件合成一段；原零件不畫（layers 0）但還在場上、碰撞照舊；
## 拆一塊當下從合併網格拿掉；換局立回來；不會畫兩次；用到物件空間座標的著色器不合畫面（只合影子）
func _case_farm_draw_batch() -> void:
	var farm := Node3D.new()
	root.add_child(farm)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.RED
	var red2 := red.duplicate()   # 參數一樣的另一份：當同一種
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color.BLUE
	var parts: Array[MeshInstance3D] = []
	for mat in [red, red2, blue]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		var p := MeshInstance3D.new()
		p.mesh = BoxMesh.new()
		p.material_override = mat
		p.layers = 5
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 不投影子的也要合畫面
		body.position = Vector3(parts.size() * 2.0, 0, 0)
		body.add_child(p)
		farm.add_child(body)
		parts.append(p)
	parts[1].scale = Vector3(-1, 1, 1)   # 鏡像的
	var local := MeshInstance3D.new()   # 著色器用到物件空間的頂點：合了會變樣，不合畫面
	local.mesh = BoxMesh.new()
	local.material_override = ShaderMaterial.new()
	local.material_override.shader = Shader.new()
	local.material_override.shader.code = "shader_type spatial;\nvarying vec3 p;\nvoid vertex() { p = VERTEX; }\nvoid fragment() { ALBEDO = p; }"
	farm.add_child(local)
	var world := MeshInstance3D.new()   # 只用世界座標的（像農莊的地面）：合
	world.mesh = BoxMesh.new()
	world.material_override = ShaderMaterial.new()
	world.material_override.shader = Shader.new()
	world.material_override.shader.code = "shader_type spatial;\nvarying vec3 w;\nvoid vertex() { w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() { ALBEDO = w; }"
	world.layers = 5
	farm.add_child(world)
	var batch: Node = preload("res://levels/farm_destruction/farm_batch.gd").install(farm, true)
	var cells := batch.get_children().filter(func(c): return c.name.begins_with("Cell"))
	_ck(cells.size() == 1, "同一格、同 layers 的零件畫面合成一個網格")
	var mesh: ArrayMesh = cells[0].mesh
	_ck(mesh.get_surface_count() == 3, "參數一樣的兩份紅色當一種：紅、藍、世界座標著色器三段（現在 %d）" % mesh.get_surface_count())
	_ck(cells[0].layers == 5 and cells[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "合併網格照原本的 layers 畫、自己不投影子（影子另一塊）")
	_ck(parts.all(func(p): return p.layers == 0 and p.visible and p.is_inside_tree() and batch.drawing(p)), "合了的零件不畫（layers 0），但還在場上")
	_ck(parts.all(func(p): return not p.get_parent().get_child(0).disabled), "碰撞照舊")
	_ck(batch.drawing(world) and not batch.drawing(local) and local.layers == 1, "物件空間座標的著色器不合畫面，照舊自己畫")
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	_ck(tris == 4 * 12, "合併網格的三角形就是四個方塊的（不會畫兩次）")
	parts[0].get_parent().visible = false   # 拆掉一塊（藏上層）
	_ck(not batch.drawing(parts[0]) and batch.drawing(parts[1]) and parts[0].layers == 0, "拆掉的那塊當下從合併網格拿掉，旁邊的不變，原零件也不會冒出來")
	parts[0].get_parent().visible = true   # 換局立回來
	_ck(parts.all(func(p): return batch.drawing(p) and p.layers == 0), "換局立回來：回到合併網格，原零件還是不畫")
	farm.free()

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
	var exits: Array = ArenaMap.exit_spots(m.greybox)
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

## 爆炸桶（barrels.gd）：每局隨機擺、位置合格、派對每回合重抽、打一槍就爆（扣血、連環爆）、客戶端收到同一批
func _case_barrels() -> void:
	var keep := Barrels.COUNT
	Barrels.COUNT = 6
	var m := _offline_match()
	var bs: Barrels = m.barrels
	_ck(bs.spots.size() == 6 and bs.count_alive() == 6 and bs.get_child_count() == 6, "開局擺 6 個爆炸桶（%d）" % bs.spots.size())
	var flat := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
	for i in bs.spots.size():
		var q: Vector3 = bs.spots[i]
		var p: Vector2 = flat.call(q)
		_ck(m._is_clear(p, 1.0) and not m.map._near_level(p, 0.5), "桶不在建築、石頭、樹裡（%s）" % q)
		_ck(m._exits.all(func(x: Vector3) -> bool: return p.distance_to(flat.call(x)) > m.EXIT_RADIUS), "桶不在撤離圈（%s）" % q)
		_ck(p.distance_to(flat.call(m.dino_spawn)) >= Barrels.FROM_CENTER - 0.01, "桶離中央（保險箱、蛋）夠遠（%s）" % q)
		_ck(absf(q.y - m._on_ground(Vector3(q.x, 0, q.z)).y) < 0.01, "桶貼地（%s）" % q)
		for j in i:
			_ck(p.distance_to(flat.call(bs.spots[j])) > 5.0, "桶跟桶分開（%s %s）" % [q, bs.spots[j]])
	# 客戶端：收到主機那包，擺出一樣的一批
	var c := Barrels.new()   # 客戶端那份：掛在同一個 main 底下（main.map 拿模型），不另開對局（_end 會清掉共用的連線）
	m.add_child(c)
	c._recv(bs.spots, bs.alive)
	_ck(c.get_child_count() == 6 and range(6).all(func(i: int) -> bool:
		return (c.get_child(i) as Node3D).global_position.is_equal_approx(bs.spots[i])), "客戶端收到同一批桶")
	m.remove_child(c)
	c.free()
	# 打一槍：爆、旁邊的牛仔扣血、範圍裡的桶連環爆、遠的不爆。
	# 擺在沙盒靶場那條路上（整平、沒蓋東西）：用隨機的桶位的話，坡上中間隆起的地形會擋住爆炸（照規則就炸不到），測試時好時壞
	var a: Vector3 = m._on_ground(Vector3(0, 0, 40))
	bs._recv(PackedVector3Array([a, m._on_ground(Vector3(0, 0, 43)), m._on_ground(Vector3(0, 0, 60))]), PackedByteArray([1, 1, 1]))
	var cow: Node3D = m._add_player(m.COWBOY, 2)
	cow.global_position = m._on_ground(Vector3(0, 0, 37))
	var hp0: int = cow.hp
	var delay := Barrels.CHAIN_DELAY
	Barrels.CHAIN_DELAY = 0.0   # 當場爆完：不用等計時器（對局留著等會搶到別的案例的「第一個場地」）
	_with_first(m, func() -> void: (bs.get_child(0) as Object).call(&"on_shot", a, null, Vector3.ZERO))
	Barrels.CHAIN_DELAY = delay
	_ck(bs.alive[0] == 0 and not (bs.get_child(0) as Node3D).visible and (bs.get_child(0) as CollisionObject3D).collision_layer == 0, "打到的桶爆掉、收起來")
	_ck(cow.hp < hp0 and cow.hp > 0, "3 公尺外的牛仔被炸到扣血（%d -> %d）" % [hp0, cow.hp])
	_ck(bs.alive[1] == 0 and not (bs.get_child(1) as Node3D).visible and bs.alive[2] == 1, "範圍裡的桶連環爆，遠的不爆")
	_end(m)
	# 派對：每回合重抽，避開信封
	var pm := _offline_match()
	pm._on_mode_picked(pm.RULES.keys().find(&"party"))
	pm._apply_rules()
	var before: PackedVector3Array = pm.barrels.spots
	pm._physics_process(DT)   # 第一回合
	var p: Party = pm.party
	var r1: PackedVector3Array = pm.barrels.spots
	_ck(r1.size() == 6 and r1 != before, "派對開回合重抽爆炸桶")
	for q: Vector3 in r1:
		_ck(p.env_pos.all(func(e: Vector3) -> bool: return flat.call(q).distance_to(flat.call(e)) >= Barrels.FROM_SPOT - 0.01), "桶不擋信封（%s）" % q)
	pm.barrels.explode(0, null)
	p._end_round(true, "test")
	p.time_left = 0.0
	pm._physics_process(DT)
	_ck(p.phase == &"prep" and pm.barrels.spots != r1 and pm.barrels.count_alive() == 6, "下一回合重抽，爆掉的也補回來")
	_end(pm)
	# 練習場沒有桶
	var sb := _offline_match()
	sb._sandbox = true
	sb._enter_game("test")
	_ck(sb.barrels.spots.is_empty() and sb.barrels.get_child_count() == 0, "沙盒沒有爆炸桶")
	_end(sb)
	Barrels.COUNT = keep

## 小恐龍哨兵（raptors.gd）：尼諾拉放（上限、距離限制、倒地）、看見才叫（站著、蹲著、灌木、背後）、方位條、一槍死、尼諾拉傷不到、
## 炸死、死了不補、晚加入看得到、閒晃（不超過半徑、不進禁止範圍、盯人停下、晚加入位置對）、下回合清空、不混進 Players、非派對模式沒有
func _case_raptors() -> void:
	# 固定亂數種子：信封、放的位置、每段走去哪都是抽的。不固定的話偶爾抽到地圖邊角被出生點、信封禁止範圍圍住的一小塊，
	# 走不遠、前面一擋就沒別的方向可走（照規則就是站著），測試時好時壞
	seed(20261116)
	_ck(InputMap.has_action(&"dino_raptor") and InputMap.action_get_events(&"dino_raptor").any(func(e: InputEvent) -> bool: return e is InputEventKey)
		and InputMap.action_get_events(&"dino_raptor").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton), "放小恐龍要綁鍵盤和手把")
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	m._physics_process(DT)   # 開場：主機（1）當恐龍
	var p: Party = m.party
	var r: Raptors = m.raptors
	var b: Node3D = m._boss()
	_ck(p.phase == &"prep" and b.pilot == 1 and r.left() == Raptors.MAX and Raptors.MAX == 5, "開回合：尼諾拉有 5 隻可以放")
	# 距離限制
	var safe: Vector3 = m.safe.global_position
	_ck(r.why_not(safe + Vector3(2, 0, 0)).contains("保險箱"), "保險箱旁邊不能放")
	_ck(r.why_not(p.env_pos[0] + Vector3(2, 0, 0)) != "" and r.why_not(p.env_pos[1] + Vector3(0, 0, 2)) != "", "信封旁邊不能放")
	_ck(m.spawn_points.all(func(s: Vector3) -> bool: return r.why_not(s + Vector3(2, 0, 0)) != ""), "牛仔出生點旁邊不能放")
	# 找一塊放得下的空地，尼諾拉站在它後面、面向 -Z
	var q := Vector3.INF
	for k in 400:
		var t: Vector3 = m._on_ground(m._spawn_point() * Vector3(1, 0, 1))
		var flat_ok := [-13.0, -8.0, 8.0].all(func(dz: float) -> bool: return absf(m._on_ground(Vector3(t.x, 0, t.z + dz)).y - t.y) < 0.4)   # 前後平的：射線不被坡擋
		var los := [-5.0, -8.0, -13.0].all(func(dz: float) -> bool: return m.get_world_3d().direct_space_state.intersect_ray(   # 前面沒東西擋（樹、碎塊）
			PhysicsRayQueryParameters3D.create(t + Vector3.UP * 1.5, m._on_ground(Vector3(t.x, 1.0, t.z + dz)))).is_empty())
		if r.why_not(t) == "" and r.why_not(t + Vector3(0, 0, -12)) == "" and flat_ok and los:
			q = t
			break
	_ck(q != Vector3.INF, "找得到放小恐龍的空地")
	if q == Vector3.INF:
		_end(m)
		return
	b.rotation.y = 0.0
	b.global_position = m.boss_on_ground(q + Vector3(0, 0, BOSS_GD.BODY_RADIUS + 1.0))
	b.down_left = 1.0
	_ck(r.place_by(1) != "" and r.spots.is_empty(), "倒地中不能放")
	b.down_left = 0.0
	_ck(r.place_by(-1) != "" and r.spots.is_empty(), "不是尼諾拉不能放")
	_ck(r.place_by(1) == "" and r.spots.size() == 1 and Vector2(r.spots[0].x - q.x, r.spots[0].z - q.z).length() < 0.5, "尼諾拉按 E：放在腳邊（%s）" % [r.spots])
	_ck(r.get_child_count() == 1 and (r.get_child(0) as Node3D).visible and m.players.get_children().all(func(c: Node) -> bool: return not c.is_in_group(&"raptor")),
		"小恐龍生出來，不在 Players 底下")
	m._match_hud._update_pilot_hint(b)
	_ck(m._match_hud._pilot_hint.text.contains("E 放小恐龍（剩 4 隻）"), "左下角提示剩幾隻（%s）" % m._match_hud._pilot_hint.text)
	for k in 4:
		r.place_by(1)
	_ck(r.spots.size() == 5 and r.left() == 0 and r.place_by(1).contains("放完了"), "每回合最多 5 隻")
	# 看見、盯、叫：只留一隻在 q、面向 -Z
	r.clear()
	r.add(q, 0.0)
	var cows: Array = [-1, -2, -3].map(func(id: int) -> Node3D: return m.players.get_node(NodePath(str(id))))
	for c: Node3D in cows:
		c.global_position = Vector3(0, 800, 0)
	var c: Node3D = cows[0]
	var at := func(off: Vector3, crouch: bool) -> bool:
		c.global_position = m._on_ground(Vector3(q.x + off.x, 0, q.z + off.z))
		c.set(&"sync_crouching", crouch)
		return r.can_see(0, c)
	_ck(at.call(Vector3(0, 0, -8), false), "站著 8 公尺、在正前方：看得到")
	_ck(not at.call(Vector3(0, 0, -13), false), "站著 13 公尺：看不到")
	_ck(not at.call(Vector3(0, 0, -8), true) and at.call(Vector3(0, 0, -5), true), "蹲著 8 公尺看不到、5 公尺看得到")
	_ck(not at.call(Vector3(0, 0, 8), false) and at.call(Vector3(0, 0, 2), false), "背後 8 公尺看不到、2 公尺不管方向都會發現")
	var bush: Vector3 = m.map._bushes[0]
	r.clear()
	r.add(m._on_ground(Vector3(bush.x, 0, bush.z + 4)), 0.0)
	var spot: Vector3 = m._on_ground(Vector3(bush.x + 0.3, 0, bush.z))
	var hid: bool = at.call(spot - q, true)
	var stood: bool = at.call(spot - q, false)
	_ck(not hid and stood, "蹲在灌木裡看不到，站起來就看得到（%s %s）" % [hid, stood])
	r.clear()
	r.add(q, 0.0)
	p.phase = &"play"
	at.call(Vector3(0, 0, -8), false)
	for k in 7:
		r.step(0.1)
	_ck(r.marked().is_empty(), "盯不到 0.8 秒還不叫")
	r.step(0.1)
	r.step(0.1)
	_ck(r.marked().size() == 1 and r.marked()[0] == q and m.status.text.contains("小恐龍"), "盯滿 0.8 秒尖叫，尼諾拉知道是哪一隻")
	var marks: Array = m._match_hud.compass_marks(q + Vector3(30, 0, 0))
	_ck(marks.any(func(k: Dictionary) -> bool: return k.label == "小恐龍叫" and absf(k.dist - 30.0) < 1.0), "尼諾拉的方位條標叫聲（小恐龍的位置）")
	var first: int = r.marks.get(0, -1)
	for k in 100:
		r.step(0.1)
	_ck(int(r.marks.get(0, -2)) == first, "同一隻 20 秒內不再叫")
	r.marks[0] = Time.get_ticks_msec() - 1
	_ck(r.marked().is_empty() and not m._match_hud.compass_marks(q).any(func(k: Dictionary) -> bool: return k.label == "小恐龍叫"), "標示時間到就收掉")
	# 打：尼諾拉傷不到；一槍（散彈一顆也算）就死；死了不補
	var body: Node = r.get_child(0)
	body.take_damage(100, b)
	_ck(r.alive[0] == 1, "尼諾拉傷不到小恐龍")
	c.global_position = q + Vector3(0, 0, -8)
	_ck(m.apply_damage_request(-1, body, 7, c.global_position + Vector3.UP * 1.6) and r.alive[0] == 0
		and not (body as Node3D).visible and (body as CollisionObject3D).collision_layer == 0, "一顆散彈就打死、收起來")
	_ck(r.left() == 4, "打死的不補回可以放的數量")
	r.add(q + Vector3(1, 0, 0), 0.0)
	r.get_child(1).take_damage(25, c)
	_ck(r.alive[1] == 0, "輕槍托一下就死")
	r.add(q + Vector3(2, 0, 0), 0.0)
	r.add(q + Vector3(40, 0, 0), 0.0)
	_with_first(m, func() -> void: Explosive.damage(m.map, q + Vector3(3, 0.5, 0), 6.0, 150, null))
	_ck(r.alive[2] == 0 and r.alive[3] == 1, "炸藥炸死旁邊的，遠的沒事")
	# 晚加入：收到主機那包，看得到一樣的一批（死的收著）
	var cl := Raptors.new()
	m.add_child(cl)
	cl._recv(r.spots, r.yaws, r.alive, r.goals)
	_ck(cl.get_child_count() == 4 and (cl.get_child(3) as Node3D).global_position.is_equal_approx(r.spots[3])
		and (cl.get_child(3) as Node3D).visible and not (cl.get_child(0) as Node3D).visible, "晚加入的人看得到現有的小恐龍")
	m.remove_child(cl)
	cl.free()
	# 全場遊走：沒人看到時一段一段走開，走得比一段遠、不出場、不進禁止範圍，身體面向走的方向
	r.clear()
	r.add(q, 0.0)
	for n: Node3D in cows:
		n.global_position = Vector3(0, 800, 0)
	var far := 0.0
	var bad := 0
	var faced := true
	for k in 1200:   # 120 秒
		r.step(0.1)
		r._physics_process(0.1)
		far = maxf(far, Vector2(r.spots[0].x - q.x, r.spots[0].z - q.z).length())
		var sp := Vector2(r.spots[0].x, r.spots[0].z)   # 禁止範圍：留 0.3 公尺給抽查的間隔
		var near := func(o: Vector3) -> bool: return sp.distance_to(Vector2(o.x, o.z)) < Raptors.CLEAR - 0.3
		bad += int((m.safe.on and near.call(m.safe.global_position)) or p.env_pos.any(near) or m.spawn_points.any(near) or not m._is_clear(sp, 0.3) or not m.map._inside(r.spots[0], 2.9))
		var go := Vector2(r.goals[0].x - r.spots[0].x, r.goals[0].z - r.spots[0].z)
		if go.length() > 0.5:
			faced = faced and Vector2(-sin(r.yaws[0]), -cos(r.yaws[0])).dot(go.normalized()) > 0.99
	_ck(far > 20.0 and bad == 0, "全場遊走：離起點超過 20 公尺、不出場、不進禁止範圍（最遠 %.1f、違規 %d）" % [far, bad])
	_ck(faced, "走路時面向走的方向")
	# 走到一半：晚加入的人收到那一包，接著自己走，位置跟主機一樣
	for k in 200:
		if r.goals[0].distance_to(r.spots[0]) > 1.0:
			break
		r.step(0.1)
		r._physics_process(0.1)
	_ck(r.goals[0].distance_to(r.spots[0]) > 1.0, "找得到正在走的時候")
	var late := Raptors.new()
	m.add_child(late)
	late._recv(r.spots, r.yaws, r.alive, r.goals)
	for k in 3:
		r._physics_process(0.1)
		late._physics_process(0.1)
	_ck(late.spots[0].distance_to(r.spots[0]) < 0.01 and (late.get_child(0) as Node3D).global_position.distance_to(r.spots[0]) < 0.01,
		"晚加入的人看到的位置跟主機一樣（%s %s）" % [late.spots[0], r.spots[0]])
	m.remove_child(late)
	late.free()
	# 走著前面被擋（擺一個箱子）：停下來、換一個方向走
	var dir := (r.goals[0] - r.spots[0]).normalized()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3, 3, 0.5)
	wall.add_child(shape)
	m.add_child(wall)
	wall.global_position = r.spots[0] + dir * 1.0 + Vector3.UP
	wall.look_at(wall.global_position + dir)
	PhysicsServer3D.body_set_state(wall.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, wall.global_transform)   # 不等物理幀，射線馬上打得到
	r.step(0.1)
	var stopped := r.goals[0] == r.spots[0]
	for k in 20:
		if r.goals[0] != r.spots[0]:
			break
		r.step(0.1)
	_ck(stopped and r.goals[0] != r.spots[0] and (r.goals[0] - r.spots[0]).normalized().dot(dir) < 0.99, "前面被擋就停下來，換一個方向走")
	wall.free()
	# 盯人：停下來、面向牛仔；叫完站一下再走
	var head: Vector3 = r.spots[0]
	c.global_position = r.spots[0] + (r.goals[0] - r.spots[0]).normalized().rotated(Vector3.UP, 1.0) * 2.5   # 3 公尺內：不管方向都看得到
	r._cd[0] = 0.0
	r.step(0.1)
	r._physics_process(0.1)
	var tc := c.global_position - r.spots[0]
	_ck(r.goals[0] == r.spots[0] and r.spots[0].is_equal_approx(head) and absf(angle_difference(r.yaws[0], atan2(-tc.x, -tc.z))) < 0.01, "看到牛仔就停下來、面向他")
	for k in 9:
		r.step(0.1)
		r._physics_process(0.1)
	_ck(r.marked().size() == 1 and r.spots[0].is_equal_approx(head), "盯的時候不走，盯滿就叫")
	var again := false
	for k in 150:
		r.step(0.1)
		r._physics_process(0.1)
		again = again or r.goals[0].distance_to(r.spots[0]) > 0.5
	_ck(again, "叫完再回去閒晃")
	r.clear()
	# 下回合清空
	p._end_round(true, "test")
	p.time_left = 0.0
	m._physics_process(DT)
	# 下回合：上回合的清掉；這回合電腦當恐龍，開回合自己放滿（一半在信封附近）
	var near_env := func(v: Vector3) -> bool: return p.env_pos.any(func(e: Vector3) -> bool: return Vector2(v.x - e.x, v.z - e.z).length() < Raptors.CLEAR + 10.5)
	_ck(p.phase == &"prep" and p.dino_id < 0 and r.spots.size() == 5 and r.get_child_count() == 5 and r.alive.count(1) == 5,
		"下回合清空；電腦當恐龍自己放滿 5 隻（%d）" % r.spots.size())
	_ck(Array(r.spots).all(func(v: Vector3) -> bool: return r.why_not(v) == "") and Array(r.spots).filter(near_env).size() >= 2,
		"電腦放的位置合格，信封附近有（%s）" % [r.spots])
	# 電腦尼諾拉聽到叫聲跑過去；電腦牛仔看得到小恐龍就打
	b = m._boss()
	_ck(b.pilot == 0, "這回合尼諾拉是電腦")
	r.clear()
	r.add(q, 0.0)
	p.phase = &"play"
	b.global_position = q + Vector3(0, 0, 150)
	var all: Array = m.players.get_children().filter(func(n: Node) -> bool: return n is Cowboy)
	for n: Node3D in all:
		n.global_position = q + Vector3(300, 0, 0)
	var shooter: Node3D = all[0]
	shooter.global_position = m._on_ground(Vector3(q.x, 0, q.z - 8))
	shooter.rotation.y = PI   # 面向 +Z：看著小恐龍
	shooter.set(&"sync_crouching", false)
	shooter.call(&"_bot_sense", m, 0.1)
	_ck(shooter.get(&"_bot_target") == r.get_child(0), "電腦牛仔看得到小恐龍就當成要打的（%s）" % shooter.get(&"_bot_target"))
	b._noise_left = 0.0
	for k in 10:
		r.step(0.1)
	_ck(r.marked().size() == 1 and b._noise_left > 0.0 and Vector2(b._noise.x - q.x, b._noise.z - q.z).length() < 16.0, "電腦尼諾拉聽到叫聲，往那裡去（%s）" % b._noise)
	r.kill(0)
	_ck(shooter.call(&"_bot_threat", m) == null, "小恐龍死了，電腦牛仔不再打牠")
	_end(m)
	# 非派對模式沒有小恐龍
	var e := _offline_match()
	e._add_player(e.COWBOY, 1)
	_ck(e.raptors.place_by(1) != "" and e.raptors.spots.is_empty() and e.raptors.get_child_count() == 0, "非派對模式沒有小恐龍")
	_end(e)


## 追分星星（docs/企劃/2026-11-15-畫面與保險箱位置.md 的 1.1）：只有派對第四回合有金色小恐龍，打死掉星星、碰到就撿、
## 拿著的人死掉或倒地就掉、回合結束拿著的人分數 × 2
func _case_golden_star() -> void:
	var m := _offline_match()
	m._on_mode_picked(m.RULES.keys().find(&"party"))
	m._apply_rules()
	m._physics_process(DT)
	var p: Party = m.party
	var r: Raptors = m.raptors
	_ck(r.gold == -1 and r.gold_body() == null and not p.star_on and p.star_holder == 0, "第一回合沒有金色小恐龍")
	for k in 3:
		p._end_round(true, "test")
		p.time_left = 0.0
		m._physics_process(DT)
		_ck(p.round_index == k + 1 and (r.gold >= 0) == (k == 2), "第 %d 回合%s金色小恐龍" % [k + 2, "有" if k == 2 else "沒有"])
	var g: Node3D = r.gold_body()
	_ck(g != null and r._hp[r.gold] == Raptors.GOLD_HP and Raptors.GOLD_HP == 150 and r.left() == 0 and m.players.get_children().all(func(c: Node) -> bool: return c != g),
		"第四回合：金色小恐龍 150 血，不佔可以放的數量，不在 Players 底下")
	if g == null:
		_end(m)
		return
	p.phase = &"play"
	p.time_left = 100.0
	var cows: Array = m.players.get_children().filter(func(c: Node) -> bool: return c is Cowboy)
	for c: Node3D in cows:
		c.global_position = Vector3(0, 800, 0)
	var c: Cowboy = cows.filter(func(n: Node) -> bool: return n.name != "1")[0]   # 不是自己（自己拿著不標）
	var cid := c.name.to_int()
	c.global_position = r.spots[r.gold] + Vector3(0, 0, -2)   # 貼著也不報信
	r._cd[r.gold] = 0.0
	r.step(0.1)
	_ck(r.marked().is_empty() and m.status.text.contains("金色小恐龍"), "金色小恐龍不報信，時間到叫一聲大家都聽得到")
	var far := r.spots[r.gold] + Vector3(40, 0, 0)
	_ck(m._match_hud.compass_marks(far).any(func(k: Dictionary) -> bool: return k.label == "金色小恐龍" and absf(k.dist - 40.0) < 2.0), "大家的方位條都標金色小恐龍")
	# 尼諾拉打得到；死了星星掉在原地
	var b: Node3D = m._boss()
	var at: Vector3 = r.spots[r.gold]
	g.take_damage(100, b)
	_ck(r.alive[r.gold] == 1 and r._hp[r.gold] == 50, "尼諾拉打得到金色小恐龍（還剩 50）")
	b.global_position = Vector3(0, 0, 300)
	g.take_damage(60, c)
	_ck(r.alive[r.gold] == 0 and p.star_on and p.star_holder == 0 and Vector2(p.star_pos.x - at.x, p.star_pos.z - at.z).length() < 0.5, "打死掉星星")
	_ck(m._match_hud.world_marks().any(func(k: Dictionary) -> bool: return k.label == "★星星"), "地上的星星標在畫面上")
	# 碰到就撿
	c.global_position = p.star_pos + Vector3(3, 0, 0)
	p._star_step()
	_ck(p.star_on, "還沒碰到不撿")
	c.global_position = p.star_pos + Vector3(0.5, 0, 0)
	p._star_step()
	_ck(not p.star_on and p.star_holder == cid, "碰到就撿起來")
	p._show_star()
	_ck(p._star_mesh.visible and p._star_mesh.global_position.y > c.global_position.y + 2.0, "頭上浮一顆星")
	_ck(m._match_hud.world_marks().any(func(k: Dictionary) -> bool: return k.label == "★星星" and far.distance_to(k.pos) < 45.0), "拿星星的人標在畫面上")
	# 計分欄：★、拿蛋的 +20
	m.egg.carrier = cid
	m._party_hud._party = p
	m._party_hud._fill_scorebar()
	var texts: Array = m._party_hud.scorebar.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_ck(texts.any(func(t: String) -> bool: return t.contains("★")) and texts.has("+20"), "計分欄：拿星星有 ★，也拿著蛋寫 +20（%s）" % [texts])
	m.egg.carrier = 0
	# 拿星星的人死掉：掉在原地
	var died_at := c.global_position
	p.on_died(null, c)
	_ck(p.star_on and p.star_holder == 0 and Vector2(p.star_pos.x - died_at.x, p.star_pos.z - died_at.z).length() < 0.5, "拿星星的牛仔死了，星星掉在原地")
	# 尼諾拉撿、倒地就掉
	b.global_position = m.boss_on_ground(p.star_pos)
	p._star_step()
	_ck(p.star_holder == p.dino_id, "尼諾拉也撿得到")
	b.down_left = 1.0
	p._star_step()
	_ck(p.star_on and p.star_holder == 0, "尼諾拉被打倒，星星掉在原地")
	b.down_left = 0.0
	# 掉出場外、地下：搬回場內地面
	p.drop_star(Vector3(9999, -80, 0))
	var ground: float = m._on_ground(Vector3(p.star_pos.x, 0, p.star_pos.z)).y
	_ck(absf(p.star_pos.x) < m.ARENA * 0.5 and absf(p.star_pos.y - ground) < 0.1, "掉出場外、地下：搬回地面（%s）" % p.star_pos)
	# 晚加入、重連
	var cl := Raptors.new()
	m.add_child(cl)
	cl._recv(r.spots, r.yaws, r.alive, r.goals, r.gold)
	_ck(cl.gold == r.gold and (cl.get_child(r.gold) as Raptors.Raptor).max_hp == 150, "晚加入的人知道哪隻是金色的")
	m.remove_child(cl)
	cl.free()
	p.star_holder = cid
	p.star_on = false
	var st := p.state()
	_ck(st.star_holder == cid and st.has("star_on") and st.has("star_pos"), "星星的狀態在每秒送的那包裡（晚加入看得到）")
	p.rekey(cid, 77)
	_ck(p.star_holder == 77, "斷線重連：星星跟著換編號")
	p.rekey(77, cid)
	# × 2：牛仔活到最後、撤離、尼諾拉守住
	var live: Array = p._cowboys()
	var who: int = live[0].name.to_int()
	p.round_scores.clear()
	p.star_holder = who
	p._end_round(true, "test")
	_ck(int(p.round_scores.get(who, 0)) == Party.SCORE_SURVIVE * 2 and int(p.round_scores.get(p.dino_id, 0)) == Party.SCORE_GUARD, "拿星星活到最後：分數 × 2（%s）" % [p.round_scores])
	p.phase = &"play"
	p.round_scores.clear()
	p.star_holder = who
	p.extracted(who)
	_ck(int(p.round_scores.get(who, 0)) == (Party.SCORE_EXTRACT + Party.SCORE_SURVIVE) * 2, "拿星星帶蛋撤離：× 2（%s）" % [p.round_scores])
	p.phase = &"play"
	p.round_scores.clear()
	p._add(p.dino_id, Party.SCORE_KILL)
	p.star_holder = p.dino_id
	p._end_round(true, "test")
	_ck(int(p.round_scores.get(p.dino_id, 0)) == (Party.SCORE_KILL + Party.SCORE_GUARD) * 2 and int(p.round_scores.get(who, 0)) == Party.SCORE_SURVIVE,
		"尼諾拉拿星星守住：殺人加守住全部 × 2（%s）" % [p.round_scores])
	# 電腦：牛仔的「星星」動作（投機的比膽小的想搶），看到金色小恐龍遠一點也打、ctx 帶星星要去哪
	var ctx := {"me": Vector3.ZERO, "hp": 1.0, "time_left": 200.0, "locked": false, "carrier": 2, "holder": Vector3(0, 0, 500),
		"egg": Vector3(0, 0, 500), "exits": [], "ffa": true, "dino": Vector3(0, 0, 200), "mates": [], "star": Vector3(20, 0, 0)}
	var sc := func(persona: int) -> float: return BotBrain.new(-1, BotBrain.PERSONAS[persona]).score_all(ctx).get("星星", 0.0)
	_ck(sc.call(2) > sc.call(1) and sc.call(2) > 0.0, "投機的比膽小的想搶星星（%.0f %.0f）" % [sc.call(2), sc.call(1)])
	var bb := BotBrain.new(-3)
	bb.think(ctx)
	_ck(bb.action == "星星" and bb.goal(ctx) == Vector3(20, 0, 0), "沒別的事：投機的去搶星星（%s）" % bb.action)
	p.phase = &"play"
	p.star_holder = 0
	p.star_on = true
	var bc: Cowboy = p._cowboys().filter(func(n: Node) -> bool: return n.name != "1")[0]
	bc.brain = BotBrain.new(bc.name.to_int())
	_ck(bc._bot_ctx(m).star == p.star_pos, "電腦牛仔知道星星在哪")
	_end(m)
	# 非派對模式沒有
	var e := _offline_match()
	e._add_player(e.COWBOY, 1)
	e._physics_process(DT)
	_ck(e.party == null and e.raptors.gold == -1 and e.raptors.gold_body() == null, "非派對模式沒有金色小恐龍")
	_end(e)
