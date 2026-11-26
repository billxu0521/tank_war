extends Door
## 可從兩面推開。由主機依開門者站側選方向，晚加入者向主機取同一扇門的轉向。
const TRAVEL := 1.53589
var opening_sign := 1.0
var motion: Tween

func interact(who: Node) -> void:
	if not who is Node3D:
		return
	if multiplayer.is_server():
		operate(who)
	else:
		_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request() -> void:
	if not multiplayer.is_server():
		return
	var farm := get_parent().get_parent()
	var players := farm.get_parent().get_node_or_null("Players")
	if players:
		var who := players.get_node_or_null(str(multiplayer.get_remote_sender_id())) as Node3D
		if who:
			operate(who)

func operate(who: Node3D) -> void:
	if motion and motion.is_running():
		return
	var jamb := get_parent() as Node3D
	var relative := _closed.affine_inverse() * jamb.to_local(who.global_position)
	var grip := to_global(Vector3(.75, 1.10, 0))
	if grip.distance_to(who.global_position + Vector3.UP) > 2.95:
		return
	var direction := opening_sign if is_open else (1.0 if relative.z >= 0 else -1.0)
	if sweep_occupied(direction):
		return
	_apply_pose.rpc(not is_open, direction, false)

func sweep_occupied(direction: float) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = $Solid.shape
	query.exclude = [get_rid()]
	var jamb := get_parent() as Node3D
	for step in range(13):
		var turn := Transform3D(Basis(Vector3.UP, direction * TRAVEL * step / 12.0), Vector3.ZERO)
		query.transform = jamb.global_transform * _closed * turn * $Solid.transform
		for hit in space.intersect_shape(query, 16):
			if hit.collider is CharacterBody3D:
				return true
	return false

@rpc("authority", "call_local", "reliable")
func _apply_pose(v: bool, direction: float, instant: bool) -> void:
	opening_sign = direction
	swing = direction * TRAVEL
	is_open = v
	prompt = "關門" if v else "開門"
	if motion:
		motion.kill()
	var target := _closed * Transform3D(Basis(Vector3.UP, swing if v else 0.0), Vector3.ZERO)
	if instant:
		transform = target
	else:
		motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		motion.tween_property(self, "transform", target, .36)

func set_open(v: bool, instant := false) -> void:
	if v and not multiplayer.is_server():
		_request_pose.rpc_id(1)
	else:
		_apply_pose(v, opening_sign, instant)

@rpc("any_peer", "call_remote", "reliable")
func _request_pose() -> void:
	if multiplayer.is_server():
		_apply_pose.rpc_id(multiplayer.get_remote_sender_id(), is_open, opening_sign, true)
