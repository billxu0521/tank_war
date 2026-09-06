extends SceneTree
## 自我檢查：跑 `godot --headless --script test_battle.gd`
## 有失敗會印 FAIL 並回傳非 0，不會假裝過關。

var _fails := 0
var _shell_target: Node
var _frames := 0

func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_case_dino_wins()
		_case_tanks_win()
		_case_attacks()
		_case_offline()
		_case_gun_pitch()
		_start_shell_case()
		return false
	# 砲彈要飛好幾個 frame 才會打到人
	if _shell_target.hp < 60:
		return _done()
	if _frames > 120:
		_ck(false, "砲彈沒打中坦克")
		return _done()
	return false

func _done() -> bool:
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、勝負、咬/橫掃範圍、離線模式、砲管俯仰、砲彈命中都正常")
	return true

# --- 共用 ---

func _new_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_host_pressed()  # 主機 = 恐龍（編號 1）
	m._spawn(2)
	m._spawn(3)
	_ck(m._tanks == 2, "應該有兩台坦克")
	_ck(m.players.get_node(^"1").hp == 400, "恐龍 400 血")
	_ck(m.players.get_node(^"2").hp == 60, "坦克 60 血")
	return m

func _new_offline_game() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_offline_pressed()  # 離線模式：編號 1 是自己的坦克
	return m

func _end(m: Node) -> void:
	m.multiplayer.multiplayer_peer.close()
	m.multiplayer.multiplayer_peer = null
	root.remove_child(m)
	m.free()

# --- 案例 ---

func _case_dino_wins() -> void:
	var m := _new_game()
	var t2: Node = m.players.get_node(^"2")
	t2.take_damage(35)
	_ck(t2.hp == 25 and m._tanks == 2, "咬一口還沒死")
	t2.take_damage(35)
	_ck(m._tanks == 1 and not m._over, "死一台，還有一台")
	m.players.get_node(^"3").take_damage(60)
	_ck(m._over and m.status.text.begins_with("恐龍獲勝"), "坦克全滅 -> 恐龍贏")
	_end(m)

func _case_tanks_win() -> void:
	var m := _new_game()
	var dino: Node = m.players.get_node(^"1")
	for i in 40:
		dino.take_damage(10)
	_ck(m._over and m.status.text.begins_with("坦克獲勝"), "恐龍死 -> 坦克贏")
	_end(m)

## 咬只打前方，橫掃四面八方都打到
func _case_attacks() -> void:
	var m := _new_game()
	var d: Node = m.players.get_node(^"1")
	var front: Node = m.players.get_node(^"2")
	var back: Node = m.players.get_node(^"3")
	d.global_position = Vector3.ZERO       # 面向 -Z
	front.global_position = Vector3(0, 1, -4)
	back.global_position = Vector3(0, 1, 4)

	d._hit_nearby(d.BITE_REACH, d.BITE_DAMAGE, 0.3)
	_ck(front.hp == 25, "咬應該打到前面的坦克")
	_ck(back.hp == 60, "咬不該打到後面的坦克")

	d._hit_nearby(d.SWEEP_REACH, d.SWEEP_DAMAGE, -1.0)
	_ck(front.hp == 3 and back.hp == 38, "橫掃應該前後都打到")
	_end(m)

## 離線 debug 模式：不連線也要能打、能判勝負
func _case_offline() -> void:
	var m := _new_offline_game()
	var tank: Node = m.players.get_node(^"1")
	_ck(m.players.get_child_count() == 2, "離線應該有一台坦克 + 一隻靶")
	_ck(tank.is_multiplayer_authority(), "離線時自己那台坦克要操控得動")
	_ck(m.players.get_node(^"2").global_position.z == -8.0, "靶要放在固定位置")
	m.players.get_node(^"2").take_damage(400)
	_ck(m._over and m.status.text.begins_with("坦克獲勝"), "打爆靶子 -> 坦克贏")
	_end(m)

## 砲管上下角度要夾在俯 8 度 ~ 仰 20 度之間
func _case_gun_pitch() -> void:
	var m := _new_offline_game()
	var t: Node = m.players.get_node(^"1")

	t.aim(Vector2(0, -9999))  # 滑鼠一路往上
	_ck(is_equal_approx(t.gun_pitch, t.PITCH_MAX), "抬到底要停在仰角上限")
	t.aim(Vector2(0, 9999))   # 一路往下
	_ck(is_equal_approx(t.gun_pitch, t.PITCH_MIN), "壓到底要停在俯角下限")

	t.gun_pitch = 0.2
	t._physics_process(0.016)
	_ck(is_equal_approx(t.gun.rotation.x, 0.2), "砲管模型要跟著轉")
	_end(m)

## 砲彈要真的飛過去打中人（跨好幾個 frame）
func _start_shell_case() -> void:
	var m := _new_game()
	m.players.get_node(^"1").global_position = Vector3(25, 3, 25)   # 恐龍閃遠一點
	_shell_target = m.players.get_node(^"2")
	_shell_target.global_position = Vector3(0, 1, 0)
	m.players.get_node(^"3").global_position = Vector3(-25, 3, -25)
	m.players.get_node(^"3")._fire(Vector3(0, 1, 10), Vector3(0, 0, -1))
