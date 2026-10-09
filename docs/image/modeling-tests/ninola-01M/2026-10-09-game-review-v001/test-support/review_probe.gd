extends Node
var observer: Camera3D
var mode := 0
var timer := 0.0
var records: Array = []
var shots := 0
var keys: Array = []
var output := ProjectSettings.globalize_path("res://../")
func _ready() -> void:
	observer = Camera3D.new()
	add_child(observer)
	observer.fov = 58.0
func subject() -> Node3D:
	var players = get_parent().get_node_or_null("Players")
	if players == null: return null
	for player in players.get_children():
		if player.is_in_group("dino"): return player
	return null
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		keys.append({"time":Time.get_ticks_msec(),"key":OS.get_keycode_string(event.keycode),"physical":event.physical_keycode})
		if event.keycode == KEY_F6:
			mode = (mode + 1) % 4
			if mode > 0: observer.make_current()
			else:
				var d = subject()
				if d: d.get_node("CamPivot/Camera3D").make_current()
		if event.keycode == KEY_F9: capture.call_deferred()
func _process(delta: float) -> void:
	var d = subject()
	if d == null: return
	if mode > 0:
		var offsets = [Vector3.ZERO,Vector3(-13,7,-16),Vector3(0,6,-18),Vector3(-18,5,0)]
		observer.global_position = d.global_position + d.global_basis * offsets[mode]
		observer.look_at(d.global_position + Vector3(0,3.2,0))
	timer += delta
	if timer < 0.1: return
	timer = 0.0
	var t = d.get_node("Trex")
	records.append({"time":Time.get_ticks_msec(),"position":[d.position.x,d.position.y,d.position.z],"velocity":[d.velocity.x,d.velocity.y,d.velocity.z],"bite":t._bite,"act":t.act,"gait":t._gait,"stamina":d.stamina,"camera_mode":mode,"fps":Engine.get_frames_per_second()})
	var file = FileAccess.open(output + "live_input_telemetry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":records,"key_events":keys,"renderer":RenderingServer.get_current_rendering_method(),"subject":"actual dino.gd authority player 1; only test setup changed","true_input_injected_by_script":false},"\t"))
func capture() -> void:
	await RenderingServer.frame_post_draw
	shots += 1
	get_viewport().get_texture().get_image().save_png(output + "live_%02d_view%d.png" % [shots,mode])
	print("REVIEW_SCREENSHOT ",shots," mode ",mode)
