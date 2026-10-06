class_name Explosive
## 炸藥、魚叉共用的爆炸：特效、聲音（每台都播）、範圍傷害（只有主機算）。
## 規劃見 docs/規劃/2026-10-04-炸藥與炸彈長矛.md。不分敵我：自己、隊友、恐龍都會被炸

const BOOM := preload("res://assets/audio/weapons/boom.wav")

## 爆炸的樣子（審查第 13 條：以前是一顆模糊的光球加一圈模糊的黑環，像太陽，跟平面硬邊的畫風不搭）：
##   白光只亮一下（0.06 秒）→ 8 團橘黃的低面數火球往外脹 0.3 秒 → 10 團深灰的低面數煙團往上飄 2–3 公尺、停 3 秒再縮掉；
##   地上一圈塵土、噴起來的泥土碎塊、照亮四周的閃光燈
static func play(world: Node3D, at: Vector3, radius: float) -> void:
	if world == null:
		return
	var up := Vector3.UP
	Fx.burst(world, SphereMesh.new(), Color(1.0, 0.95, 0.8, 1.0), at + up * 0.8, Vector3.ONE * radius * 0.2, Vector3.ONE * radius * 0.5, 0.06)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 3.0   # 太亮會在地上照出一團模糊的橘光（第二輪審查）
	light.omni_range = radius * 3.0
	world.add_child(light)
	light.global_position = at + up * 1.5
	var t := light.create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.35)
	t.tween_callback(light.queue_free)
	var fire := [Color(1.0, 0.55, 0.12), Color(1.0, 0.78, 0.25)]
	for k in 8:
		var off := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)) * radius * 0.25
		_blob(world, at + up * 0.6 + off, fire[k % 2], true, radius * 0.08, radius * randf_range(0.14, 0.2),
			off * 1.2, 0.15, 0.1)   # 0.25 秒內就沒了：主體是後面的黑煙
	# 煙：深棕灰兩個色階，一邊長大一邊往上飄（每秒約 1.5 公尺），1 秒時要看得出一根往上的煙柱（審查第三輪：以前像一堆貼地的黑石頭）
	var smoke := [Color(0.231, 0.196, 0.173), Color(0.341, 0.29, 0.25)]
	for k in 14:
		var off := Vector3(randf_range(-1, 1), randf_range(0.0, 0.8), randf_range(-1, 1)) * radius * 0.3
		var rise := Vector3(randf_range(-0.4, 0.4), randf_range(3.6, 5.0), randf_range(-0.4, 0.4))
		var r := radius * randf_range(0.12, 0.18)
		_blob(world, at + up * 0.8 + off, smoke[k % 2], false, r * 0.5, r * 1.5, rise, 3.0, 0.8)
	for l: Node in world.get_tree().get_nodes_in_group(&"oil_lantern"):   # 爆炸範圍裡的油燈一起破（各端各自）
		if (l as Node3D).global_position.distance_to(at) < radius:
			l.on_shot((l as Node3D).global_position, null, ((l as Node3D).global_position - at).normalized())
	Fx.hit(world, at, up, &"dirt")
	Fx.hit(world, at + up * 0.3, up, &"dirt")
	_ground_ring(world, at, radius)
	var s := AudioStreamPlayer3D.new()
	s.stream = BOOM
	s.unit_size = 30.0         # 很大聲：整張地圖都聽得到（恐龍也聽得到，見 Viewmodel._explode）
	s.max_db = 6.0
	world.add_child(s)
	s.global_position = at
	s.play()
	s.finished.connect(s.queue_free)


## 地上一圈往外擴散的塵土環：扁平、土黃、硬邊，0.4 秒從 1 公尺擴到 4 公尺再淡掉（第二輪審查：以前是一團模糊的粒子）
static func _ground_ring(world: Node3D, at: Vector3, radius: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.8
	ring.outer_radius = 1.0
	ring.rings = 16
	ring.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.42, 0.28, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.15
	mi.scale = Vector3(1.0, 0.25, 1.0)
	var end := radius * 0.67
	var t := mi.create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3(end, 0.25, end), 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.6)
	t.chain().tween_callback(mi.queue_free)


## 一團低面數的火球或煙：平面著色（每一面一個顏色、硬邊）。從 r0 脹到 r1 同時移動 move，維持 hold 秒，最後 shrink 秒縮掉
static var _blob_mesh: Mesh
static func _blob(world: Node3D, at: Vector3, color: Color, glow: bool, r0: float, r1: float,
		move: Vector3, hold: float, shrink: float) -> void:
	if _blob_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radial_segments = 7
		sphere.rings = 4
		var st := SurfaceTool.new()
		st.create_from(sphere, 0)
		st.deindex()            # 每個三角形自己的頂點，法線才不會被抹圓
		st.generate_normals()
		_blob_mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = at
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	mi.scale = Vector3.ONE * r0 * 2.0
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, minf(0.3, hold)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(mi, "global_position", at + move, hold).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(mi, "scale", Vector3.ONE * 0.01, shrink).set_ease(Tween.EASE_IN)
	t.tween_callback(mi.queue_free)


## 範圍傷害（只在主機叫）：radius 內每個會受傷的東西，照距離線性遞減（中心 max_damage、邊緣 0）。
## 中間隔著場景的東西（牆、石頭、地形）就炸不到。目標的大小：有 blast_reach 屬性就從那麼遠算起（恐龍很長，炸到尾巴也算）
static func damage(world: Node3D, at: Vector3, radius: float, max_damage: int, shooter: Node) -> void:
	var space := world.get_world_3d().direct_space_state
	var game := world.get_tree().get_first_node_in_group(&"match")
	if game == null:
		return
	# 會受傷的都是牛仔或恐龍，都掛在 players 底下。不用範圍查詢：地形是很多小塊碰撞，結果名額會被地形塞滿
	for target: Node in game.players.get_children():
		if not target.has_method(&"take_damage") or not target is CollisionObject3D:
			continue
		var center: Vector3 = (target as Node3D).global_position + Vector3.UP * 0.9
		var reach = target.get(&"blast_reach")
		var d := maxf(at.distance_to(center) - (float(reach) if reach != null else 0.0), 0.0)
		if d >= radius:
			continue
		# 擋住了嗎：從爆炸點往目標打一條線，先碰到別的、不會受傷的東西（場景）就算擋住
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, center)
		ray.exclude = [(target as CollisionObject3D).get_rid()]
		var block := space.intersect_ray(ray)
		if not block.is_empty() and not block.collider.has_method(&"take_damage"):
			continue
		var amount := int(round(max_damage * (1.0 - d / radius)))
		if amount > 0:
			target.take_damage(amount, shooter)
