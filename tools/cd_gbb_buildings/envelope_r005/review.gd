extends Node3D
## 隔離建築驗收場，沿用牛仔膠囊與翻越。
const BUILDING = preload("res://tools/cd_gbb_buildings/envelope_r005/building.gd")
var houses: Array[Node3D] = []
var player: CharacterBody3D
var camera: Camera3D
var hint: Label

func _ready() -> void:
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	var outline:=ShaderMaterial.new()
	outline.shader=load("res://outline.gdshader")
	outline.render_priority=Material.RENDER_PRIORITY_MIN
	quad.material=outline
	var om:=MeshInstance3D.new()
	om.mesh=quad
	om.extra_cull_margin=16384
	om.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(om)
	for number in [1, 7, 2, 15]:
		var house := BUILDING.new()
		add_child(house)
		house.build(number, true)
		houses.append(house)
		for mi:MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			for surface in mi.mesh.get_surface_count():
				var mat:=mi.mesh.surface_get_material(surface) as BaseMaterial3D
				if mat and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and mat.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL:
					mi.set_surface_override_material(surface,facet(mat))
		# 只是隔離測試地台，不代表正式地勢或接坡已完成。
		var pad := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(32, 0.2, 24)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		pad.add_child(collider)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.26, 0.21, 0.15)
		mat.roughness = 1.0
		mesh.material_override = mat
		pad.add_child(mesh)
		house.add_child(pad)
		pad.position = Vector3(house.spec.placement.w / 2.0, -0.3, -house.spec.placement.d / 2.0)
	get_window().title="CD-GBB 四棟建築基礎版"
	setup_player()

func setup_player() -> void:
	# 使用專案牛仔原本的膠囊與翻越；地台保留自己的自由觀察操控。
	player = load("res://cowboy/cowboy.tscn").instantiate()
	player.name = "1"
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	for node in player.get_children():
		node.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("HUD").hide()
	player.hide()
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 70.0
	camera.near = 0.02
	player.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	hint = Label.new()
	hint.position = Vector2(18, 18)
	ui.add_child(hint)
	add_child(ui)
	teleport(0)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func teleport(index: int) -> void:
	if player.vaulting: return
	var house := houses[index]
	var starts: Array[Vector3] = [Vector3(8,.1,-13.4),Vector3(10,.1,3),Vector3(11,.1,-13.4),Vector3(5,.1,2)]
	var start: Vector3 = starts[index]
	player.global_position = house.to_global(start)
	player.rotation.y = house.rotation.y + (PI if index in [0,2] else 0.0)
	camera.rotation.x = 0
	player.velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: teleport(0)
			KEY_F2: teleport(1)
			KEY_F3: teleport(2)
			KEY_F4: teleport(3)
			KEY_F5: camera.fov = 90.0 if camera.fov < 80.0 else 70.0
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_E:
				var target := focus()
				if target and target.has_method("interact"): target.interact(player)
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
			var pane := focus()
			if pane and pane.has_method("on_shot"):
				pane.on_shot(camera.global_position, player, -camera.global_basis.z)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.002)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.4, 1.4)

func focus() -> Node:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 2.5)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() else null

func try_window_vault() -> bool:
	var from := player.global_position + Vector3.UP * 1.45
	var to: Vector3 = from - player.global_basis.z * (player.vault_reach + player.vault_landing_offset)
	for house in houses:
		for window in house.fixed_windows:
			if window.blocks_crossing(from, to, player._capsule.radius):
				return false
	return player.try_vault(true)

func _physics_process(delta: float) -> void:
	if player.vaulting: return
	var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction := player.basis * Vector3(axis.x, 0, axis.y)
	player.velocity.x = direction.x * 4.0
	player.velocity.z = direction.z * 4.0
	player.velocity.y -= 18.0 * delta
	if player.is_on_floor() and Input.is_action_just_pressed("jump"):
		if axis.y < 0 and try_window_vault(): return
		player.velocity.y = player.jump_velocity
	player.move_and_slide()
	var target := focus()
	hint.text = "四棟建築基礎版（無AO）｜F1 農宅 · F2 木棚 · F3 糧庫 · F4 宿舍 · F5 視角｜WASD 移動 · Space 跳躍 · W＋Space 翻越 · E 門窗 · 左鍵擊破固定窗 · Esc 釋放滑鼠\n隔離地台／單人測試，非正式地圖與戰鬥驗收｜眼高 1.60m · 垂直視角 %.0f°" % camera.fov + ("\nE " + str(target.prompt) if target and target.has_method("interact") else ("\n左鍵 擊破固定窗" if target and target.has_method("on_shot") else ""))

func facet(m: BaseMaterial3D) -> ShaderMaterial:
	var f:=ShaderMaterial.new()
	f.shader=load("res://tools/cd_gbb_buildings/style_compare/facet_ao_diagnostic.gdshader")
	f.set_shader_parameter("albedo",m.albedo_color)
	f.set_shader_parameter("use_vcol",m.vertex_color_use_as_albedo)
	# 此shader的ROUGHNESS同時供outline分類；.87是角色目標標記。
	# 建築金屬屋面維持原材質資料，只在風格化接入使用一般建築分類。
	var surface_mark: float = 1.0 if "roof" in m.resource_name.to_lower() else m.roughness
	f.set_shader_parameter("roughness",surface_mark)
	if m.albedo_texture:
		f.set_shader_parameter("use_tex",true)
		f.set_shader_parameter("albedo_tex",m.albedo_texture)
		f.set_shader_parameter("use_triplanar",m.uv1_triplanar)
	f.set_shader_parameter("uv_scale",m.uv1_scale)
	f.set_shader_parameter("uv_offset",m.uv1_offset)
	var n:=m.resource_name
	if ["wood","plank","trim","post"].any(func(k):return k in n):
		f.set_shader_parameter("shade_tint",Vector3(.96,.90,1.06))
		f.set_shader_parameter("lit_tint",Vector3(1.06,.98,.84))
	elif ["stone","mortar"].any(func(k):return k in n):
		f.set_shader_parameter("shade_tint",Vector3(.92,.96,1.06))
		f.set_shader_parameter("lit_tint",Vector3(1.04,1,.94))
	f.set_shader_parameter("compare_use_normal",m.normal_enabled and m.normal_texture!=null)
	f.set_shader_parameter("compare_normal",m.normal_texture)
	f.set_shader_parameter("compare_use_ao",m.ao_texture!=null)
	f.set_shader_parameter("compare_ao",m.ao_texture)
	f.set_shader_parameter("compare_ao_strength",0.0)
	return f
