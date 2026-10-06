extends SceneTree
## 油燈和燈油火的檢查：打破會潑油燒起來、火會擴散、站在火裡扣血（站外面不會）、燒到旁邊的油燈會連鎖、
## 爆炸會打破油燈、燒完會熄滅。時間加速 4 倍跑。
##   godot --headless --path . --script tools/test_lantern_fire.gd

var _fails := 0
var _frames := 0
var m: Node


func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_run()
	if _frames > 60 * 120:
		printerr("FAIL: 跑太久")
		quit(1)
	return false


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _run() -> void:
	seed(20261005)
	Engine.time_scale = 4.0
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	await _wait(0.2)
	var sp: Vector3 = m._spawn_point()
	var hit: Dictionary = m.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sp + Vector3.UP * 30, sp + Vector3.DOWN * 60))
	var at: Vector3 = hit.position   # 出生點在空中：擺東西要貼在真正的地面（碰撞）上
	var shooter: Node3D = m._add_player(m.COWBOY, 1)
	shooter.global_position = at + Vector3(0, 0, 10)
	var victim: Node3D = m._add_player(m.COWBOY, 5)
	victim.global_position = at
	var safe: Node3D = m._add_player(m.COWBOY, 6)
	safe.global_position = at + Vector3(8, 0, 0)
	var arena: Node3D = m.get_node(^"Arena")
	var mesh: Mesh = m._props.get(&"Lantern")
	var lamp := OilLantern.place(arena, mesh, at, false)
	var next := OilLantern.place(arena, mesh, at + Vector3(1.0, 0, 0), false)   # 第一灘火燒得到（每個方向至少 1.1 公尺）
	var lone := OilLantern.place(arena, mesh, at + Vector3(0, 0, -15), false)  # 太遠，燒不到
	await _wait(0.2)
	var hp0: int = victim.hp
	var safe0: int = safe.hp
	lamp.on_shot(lamp.global_position, shooter, Vector3.FORWARD)
	_ck(lamp.broken, "打中的油燈要破")
	var fires := root.get_tree().get_nodes_in_group(&"oil_fire")
	_ck(fires.size() == 1, "打破要潑出一灘火（現在 %d 灘）" % fires.size())
	if fires.is_empty():
		_end()
		return
	var fire: OilFire = fires[0]
	_ck(fire.global_position.distance_to(at) < 1.5, "火要在燈下面的地上（現在差 %.1f 公尺）" % fire.global_position.distance_to(at))
	await _wait(0.4)
	var r_early := fire._flames.filter(func(f: Node3D) -> bool: return f.scale.y > 0.01).size()
	await _wait(OilFire.SPREAD)
	var r_full := fire._flames.filter(func(f: Node3D) -> bool: return f.scale.y > 0.01).size()
	_ck(r_full > r_early, "火要往外擴散（一開始 %d 簇、燒滿 %d 簇）" % [r_early, r_full])
	_ck(next.broken, "火燒到旁邊的油燈要連鎖破掉")
	_ck(not lone.broken, "太遠的油燈不會被點燃")
	await _wait(2.0)
	_ck(victim.hp < hp0, "站在火裡要扣血（%d → %d）" % [hp0, victim.hp])
	_ck(safe.hp == safe0, "站在火外面不扣血（%d → %d）" % [safe0, safe.hp])
	# 爆炸也會打破油燈
	Explosive.play(arena, lone.global_position + Vector3(2, 0, 0), 5.0)
	_ck(lone.broken, "爆炸範圍裡的油燈要破")
	await _wait(OilFire.BURN + OilFire.FADE + 1.0)
	_ck(not fire._light.visible, "燒完要熄滅")
	_end()


func _end() -> void:
	Engine.time_scale = 1.0
	print("油燈、燈油火檢查：", "通過" if _fails == 0 else "%d 項沒過" % _fails)
	quit(1 if _fails else 0)
