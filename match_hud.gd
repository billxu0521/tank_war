class_name MatchHud
extends RefCounted
## 局內的畫面資訊（從 main.gd 搬出來）：方位條倒數、準心、boss 條、出局觀戰、右上角網路／FPS、左上角那行字。
## 每幀由 main.gd 的 _process 依序呼叫，這裡不自己跑 _process。讀 main 的成員一律寫 main.xxx。

var main: Node
var _root: Control   # UI/Root：這裡的元件照原本的時機加進去

func _init(m: Node) -> void:
	main = m
	_root = m.get_node(^"UI/Root")

## 每幀最先呼叫（_diag_print 在它後面）：記最慢一幀
func track_frame_time(delta: float) -> void:
	_track_frame_time(delta)

## 右上角網路資訊和方位條的顯示（大廳也跑）
func update_always() -> void:
	_update_net_info()
	if _compass:
		_compass.visible = not main.lobby.visible

## 局內的倒數、觀戰、準心、boss 條、方位條（連線好了才跑）
func update_match(me: Node) -> void:
	_update_center_info(me)
	_update_spectator(me)
	_update_crosshair(me)
	_update_boss_bar(me)
	_update_compass()

## 體力條和左上角那行字
func update_text(me: Node) -> void:
	var dino := main.get_tree().get_first_node_in_group(&"dino")
	main.stamina_bar.visible = me != null and me == dino
	if main.stamina_bar.visible:
		main.stamina_bar.value = me.stamina
		main.stamina_bar.modulate = Color(1, 0.35, 0.3) if me.exhausted else Color.WHITE
	var egg_state := "無人持有"
	if main.egg.carrier == main.multiplayer.get_unique_id():
		egg_state = "在你身上！帶去撤離區"
	elif main.egg.carrier != 0:
		egg_state = "被牛仔 %d 拿走了" % main.egg.carrier
	var mine := str(me.hp) if me != null else "陣亡"
	if main.mode == &"range":
		main.hud.text = "靶場    準星距離：%s    上一發：%s" % [_aim_distance(me), main._last_hit]
		return
	if main._solo_dino:
		main.hud.text = "單人打恐龍    我的血量：%s    接關 %d 次\n%s" % [mine, main._continues, _boss_debug()]
		return
	if main._sandbox:
		main.hud.text = "沙盒    我的血量：%s    恐龍靶血量：%s" % [mine, dino.hp if dino else "重生中"]
		return
	var my_id := main.multiplayer.get_unique_id()
	if main.party:   # 回合、倒數、命數在左上（party_hud.gd）
		main.hud.text = "我的血量：%s    蛋：%s" % [mine, egg_state]
		return
	if main._uses_lives():
		var left := "出局" if main._out.has(my_id) else "剩 %d 次" % int(main._lives.get(my_id, 0))
		main.hud.text = "%s    我的血量：%s    重生：%s    場上還有 %d 名牛仔" % [main.RULES[main.rules].name, mine, left, main._remaining().size()]
		return
	main.hud.text = "⏱ %d:%02d    我的血量：%s    %s存活牛仔：%d    蛋：%s" % [
		maxi(main._clock, 0) / 60, maxi(main._clock, 0) % 60,
		mine,
		("恐龍血量：%d    " % dino.hp) if dino else "",
		main.players.get_child_count() - (1 if dino else 0),
		egg_state]

## 回大廳（_to_lobby）：局內的畫面全收起來
func reset() -> void:
	main.center_info.text = ""
	if _boss_bar:
		_boss_bar.hide()
		_boss_label.hide()
	_had_me = false
	main.crosshair.hide()
	main.stamina_bar.hide()
	main.hud.text = ""

## 新一局開始（_announce）：死過的人重新算
func on_announce() -> void:
	_had_me = false
	_dead_ms = -1   # 不然死過的人在新角色同步到之前會閃一下「重生倒數」

## 準星指到多遠：從鏡頭中心往前掃 400 公尺，撞到什麼就量到那裡
func _aim_distance(me: Node3D) -> String:
	var cam := main.get_viewport().get_camera_3d()
	if cam == null or me == null:
		return "—"
	var from := cam.global_position
	var mine: Array[RID] = [me.get_rid()]   # 自己身上的碰撞（頭、身體的判定區）和看不見的圍牆都不算
	for n in me.find_children("*", "CollisionObject3D", true, false) + main.get_tree().get_nodes_in_group(&"arena_wall"):
		mine.append(n.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 400.0, 1, mine)
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
	return "—" if hit.is_empty() else "%.1f m" % from.distance_to(hit["position"])

var _had_me := false    # 這局我已經生出來過；之後角色不見了就是死了，開始重生倒數
var _dead_ms := -1

## 出局之後觀戰：鏡頭跟在一個還在場上的牛仔後上方（左鍵換人）
var _spectator: Camera3D
var _watch := 0
func _update_spectator(me: Node) -> void:
	var out: bool = me == null and main._is_out(main.multiplayer.get_unique_id())
	if not out:
		if _spectator and _spectator.current:
			_spectator.current = false
		return
	var alive: Array = main.players.get_children().filter(func(p: Node) -> bool: return not p.is_in_group(&"dino"))
	if alive.is_empty():
		return
	if _spectator == null:
		_spectator = Camera3D.new()
		main.add_child(_spectator)
	if Input.is_action_just_pressed(&"fire"):
		_watch += 1
	var p: Node3D = alive[_watch % alive.size()]
	var back := p.global_basis.z
	back.y = 0.0
	_spectator.look_at_from_position(p.global_position + back.normalized() * 6.0 + Vector3.UP * 4.0, p.global_position + Vector3.UP * 1.5)
	_spectator.current = true

## 單人打恐龍的除錯資訊：導演在哪個階段、威脅值、恐龍在做什麼
const BOSS_ACTS := ["", "咬（預備）", "咬！", "蓄力甩尾（打頭打斷）", "甩尾！", "撲擊（預備）", "撲擊！", "收招", "被打斷", "發現你了（吼）"]
func _boss_debug() -> String:
	var b := main.get_tree().get_first_node_in_group(&"boss")
	if b == null:
		return "恐龍：不在場上"
	var d: Director = b.director
	var phase: String = ["醞釀", "退開", "放鬆"][d.phase]
	var doing: String = "倒地" if b.down_left > 0.0 else BOSS_ACTS[b.act]
	if doing == "":
		doing = "追人" if b._sees_now else ("盯著（還不確定）" if b._glimpse else ("找最後看到的地方" if b._seen_left > 0.0 else ("查聲音" if b._noise_left > 0.0
			else ("照導演的方向找" if b._hint != Vector3.INF else "閒逛"))))
	var extra := "　剩 %d 秒" % ceili(d.phase_left) if d.phase != Director.Phase.BUILD else "　威脅 %d / %d" % [roundi(d.menace), roundi(Director.MENACE_MAX)]
	return "恐龍：%s%s　｜　%s　｜　距離 %d m" % [phase, extra, doing, _dist_to_boss(b)]

func _dist_to_boss(b: Node3D) -> int:
	var me := main.players.get_node_or_null(^"1") as Node3D
	return roundi(me.global_position.distance_to(b.global_position)) if me else -1

## 方位條下面的倒數：重生、撤離、撿蛋。重生倒數用自己這台的時間算（主機的重生佇列客戶端看不到）
func _update_center_info(me: Node) -> void:
	var now := Time.get_ticks_msec()
	if me != null:
		_had_me = true
		_dead_ms = -1
	elif _had_me and _dead_ms < 0:
		_dead_ms = now
	var t := ""
	if main.result.visible or (main.party and main.party.phase != &"play"):
		t = ""
	elif me == null and main._is_out(main.multiplayer.get_unique_id()):
		t = "你出局了，觀戰中"
	elif me == null and _dead_ms >= 0:
		var delay: float = Party.RESPAWN_SECONDS if main.party else main.RESPAWN_DELAY
		t = "%d 秒後重生" % maxi(1, ceili(delay - (now - _dead_ms) / 1000.0))
	elif main.egg.extract > 0.0:
		var who := "你" if main.egg.carrier == main.multiplayer.get_unique_id() else "牛仔 %d" % main.egg.carrier
		t = "%s撤離中：還剩 %.1f 秒" % [who, maxf(main.EXTRACT_SECONDS - main.egg.extract, 0.0)]
	elif main.egg.pickup > 0.0:
		t = "有人在撿蛋：還剩 %.1f 秒" % maxf(main.PICKUP_SECONDS - main.egg.pickup, 0.0)
	main.center_info.text = t

## 最近一秒最慢的一幀。平均 FPS 看不出卡頓：60 FPS 裡夾幾幀 50 毫秒，數字照樣是 60
var _slow := 0.0
var _slow_shown := 0.0
var _slow_since := 0

func _track_frame_time(delta: float) -> void:
	_slow = maxf(_slow, delta * 1000.0)
	var now := Time.get_ticks_msec()
	if now - _slow_since >= 1000:
		_slow_shown = _slow
		_slow = 0.0
		_slow_since = now

## 右上角：本機 IP（開房的人報給朋友用）、連線延遲、每秒畫面數、最慢一幀。
## 遊戲中是開發資訊，平常收起來，F3 打開（2026-10-10 FPS 角度評估 #5）
func _update_net_info() -> void:
	main.net_info.visible = main.lobby.visible or main.debug_hud
	var parts: Array[String] = ["本機 IP：" + main._ips]
	var peer := main.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not main.lobby.visible and peer and not main.multiplayer.is_server() \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := peer.get_peer(1)
		if p:
			parts.append("延遲 %d ms" % p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			# 掉包率：ENet 的統計是乘了 PACKET_LOSS_SCALE（65536）的比例
			parts.append("掉包 %.1f%%" % (100.0 * p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / ENetPacketPeer.PACKET_LOSS_SCALE))
	if not main.lobby.visible:
		parts.append("%d FPS（最慢一幀 %.0f ms）" % [Engine.get_frames_per_second(), _slow_shown])
	main.net_info.text = "　".join(parts)

## 準心畫在「火球會落到哪」，不是螢幕正中央——抬頭時看得出彈道往上跑。
## 牛仔的準心在自己的 HUD 裡（子彈是直線，畫正中央就對），沒有 aim_point，這裡就不顯示。
func _update_crosshair(me: Node) -> void:
	var cam := main.get_viewport().get_camera_3d()
	if me == null or cam == null or not me.has_method("aim_point") or me.is_in_group(&"boss"):   # 操作尼諾拉時沒有火球，不畫準心
		main.crosshair.hide()
		return
	# 打中人準心閃紅。遠距離看不出血條掉，這是唯一的命中確認
	main.crosshair.modulate = Color(1, 0.3, 0.25) if me.hit_until > Time.get_ticks_msec() else Color.WHITE
	var p: Vector3 = me.aim_point()
	main.crosshair.visible = not cam.is_position_behind(p)
	main.crosshair.position = cam.unproject_position(p) - main.crosshair.size * 0.5

## 上方的方位條：看著的方向、蛋在哪、兩個撤離區在哪（都附距離）。
## 蛋在自己身上就不標蛋；沙盒沒有蛋也不標
var _compass: Compass
func _update_compass() -> void:
	var cam := main.get_viewport().get_camera_3d()
	if _compass == null:
		_compass = Compass.new()
		_root.add_child(_compass)
	if cam == null:
		return
	_compass.set_view(cam)
	var at := cam.global_position
	var marks := []
	# 派對模式蛋是恐龍藏的：沒人拿起來之前不標
	if main.egg.visible and main.egg.carrier != main.multiplayer.get_unique_id() and (main.party == null or main.egg.carrier != 0):
		marks.append({"deg": Compass.bearing(at, main.egg.global_position), "dist": at.distance_to(main.egg.global_position),
			"color": Compass.EGG_COLOR, "label": "蛋"})
	for e: Vector3 in (main._exits if main.RULES[main.rules].egg and not main._solo_dino else []):
		marks.append({"deg": Compass.bearing(at, e), "dist": at.distance_to(e),
			"color": Compass.EXIT_COLOR, "label": "撤離"})
	var boss := main.get_tree().get_first_node_in_group(&"boss") as Node3D
	if main.party and main._party_hud._party == main.party and main._party_hud.waiting_respawn():   # 畫面還沒換到新的 Party 時別問它   # 派對模式等重生：標出能選的重生點
		var pts: Array = main._party_hud.spawn_points()
		for i in pts.size():
			if i == main._party_hud.picked:
				marks.append({"deg": Compass.bearing(at, pts[i]), "dist": at.distance_to(pts[i]), "color": Color(0.4, 0.9, 0.5), "label": "重生點 %d" % (i + 1)})
			elif main._party_hud.picked < 0:   # 還沒選：只寫編號（九個都寫距離會疊在一起，距離看中間的清單）
				marks.append({"deg": Compass.bearing(at, pts[i]), "color": Color(0.4, 0.9, 0.5), "label": str(i + 1)})
	if main._solo_dino and boss:   # 測恐龍行為：標出恐龍在哪
		marks.append({"deg": Compass.bearing(at, boss.global_position), "dist": at.distance_to(boss.global_position),
			"color": Color(1, 0.35, 0.3), "label": "恐龍"})
	_compass.marks = marks
	_compass.queue_redraw()

## boss 的體力條（畫面上方中間，每個人都看得到）：看牠還跑不跑得動，決定現在要逃還是要躲。
## 跑不動（力竭）變紅、倒地變灰
var _boss_bar: ProgressBar
var _boss_label: Label
func _update_boss_bar(me: Node) -> void:
	var b := main.get_tree().get_first_node_in_group(&"boss")
	# 當牛仔時不顯示（0.8.1 回饋）。沙盒是測恐龍行為的地方，留著
	var duel: bool = main.rules == &"dino_duel" and not main._sandbox and main.mode != &"range"
	if not main._sandbox and not duel and not (me != null and me.is_in_group(&"dino")):
		b = null
	if _boss_bar == null:
		_boss_bar = ProgressBar.new()
		_boss_bar.show_percentage = false
		_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_bar.offset_left = -160
		_boss_bar.offset_right = 160
		_boss_bar.offset_top = 140   # 在方位條（compass.gd）和倒數（CenterInfo）下面
		_boss_bar.offset_bottom = 154
		_boss_bar.add_theme_stylebox_override(&"background", main.stamina_bar.get_theme_stylebox(&"background"))
		_boss_bar.add_theme_stylebox_override(&"fill", main.stamina_bar.get_theme_stylebox(&"fill"))
		_boss_label = Label.new()
		_boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_label.offset_left = -240   # 比體力條寬：操作恐龍時後面多「甩尾 N 秒」
		_boss_label.offset_right = 240
		_boss_label.offset_top = 116
		_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(_boss_label)
		_root.add_child(_boss_bar)
	_boss_bar.visible = b != null
	_boss_label.visible = b != null
	if b == null:
		return
	if duel:   # 恐龍決鬥：大家要看的是牠還剩多少血
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp
		_boss_bar.modulate = Color(1, 0.45, 0.35)
		_boss_label.text = "恐龍　%d / %d" % [b.hp, b.max_hp]
		return
	_boss_bar.max_value = 100
	_boss_bar.value = b.stamina
	var state := "奔跑中" if b.running else "走路"
	if b.down_left > 0.0:
		state = "倒地 %d 秒" % ceili(b.down_left)
		_boss_bar.modulate = Color(0.6, 0.6, 0.6)
	elif b.exhausted:
		state = "跑不動了！"
		_boss_bar.modulate = Color(1, 0.35, 0.3)
	else:
		_boss_bar.modulate = Color.WHITE
	_boss_label.text = "恐龍 boss　體力（%s）" % state
	if b.pilot == main.multiplayer.get_unique_id():   # 自己操作的恐龍才看得到甩尾冷卻（牛仔看不到）
		_boss_label.text += "　甩尾 %s" % ("可用" if b.sweep_left <= 0.0 else "%d 秒" % ceili(b.sweep_left))
