extends Door
## 門與通風窗兩側有握位。對開大門各扇有自己的握位、掃掠與穩定身分。
var width:=1.3
var height:=2.2
var travel:=0.0
var shutter:=false
var hand:=1.
var direction:=1.
var present:=true
var motion:Tween

func pose(open:bool, sign_:float, amount:=1.) -> Transform3D:
	var p:=_closed
	if open:
		if travel!=0.: p.origin+=p.basis*Vector3(travel*amount,0,0)
		else: p.basis=p.basis*Basis(Vector3.UP,hand*sign_*float(get_meta("opening_angle",1.53))*amount)
	return p

func set_present(value:bool) -> void:
	present=value
	visible=value
	$Solid.set_deferred("disabled",not value)
	if not value: set_open(false,true)

func interact(who:Node) -> void:
	if not present or not who is Node3D: return
	if multiplayer.is_server(): operate(who)
	else: _request.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _request() -> void:
	if not multiplayer.is_server(): return
	var farm:Node=get_parent()
	while farm and not farm is ArenaMap: farm=farm.get_parent()
	if farm:
		var who:=farm.get_parent().get_node_or_null("Players/"+str(multiplayer.get_remote_sender_id()))
		if who is Node3D: operate(who)

func operate(who:Node3D) -> void:
	if not present or (motion and motion.is_running()): return
	var parent:=get_parent() as Node3D
	var local:=_closed.affine_inverse()*parent.to_local(who.global_position)
	var handpoint:=to_global(Vector3(hand*width*.76,height*.54,0))
	if handpoint.distance_to(who.global_position+Vector3.UP*1.25)>3.15: return
	var sign_:=direction if is_open else (1. if local.z>=0 else -1.)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=$Solid.shape
	query.exclude=[get_rid()]
	for i in 13:
		query.transform=parent.global_transform*pose(true,sign_,i/12.)*$Solid.transform
		for contact in get_world_3d().direct_space_state.intersect_shape(query,24):
			if contact.collider is CharacterBody3D: return
	_apply.rpc(not is_open,sign_,false)

@rpc("authority","call_local","reliable")
func _apply(value:bool,sign_:float,instant:bool) -> void:
	direction=sign_
	is_open=value
	prompt=("關窗" if value else "開窗") if shutter else ("關門" if value else "開門")
	if motion: motion.kill()
	var target:=pose(value,sign_)
	if instant: transform=target
	else:
		motion=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		motion.tween_property(self,"transform",target,.34)

func set_open(value:bool,instant:=false) -> void:
	if value and not multiplayer.is_server(): request_pose.rpc_id(1)
	else: _apply(value,direction,instant)

@rpc("any_peer","call_remote","reliable")
func request_pose() -> void:
	if multiplayer.is_server(): _apply.rpc_id(multiplayer.get_remote_sender_id(),is_open,direction,true)

