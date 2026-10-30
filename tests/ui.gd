extends "res://tests/match.gd"
## 介面：大廳、設定、方位條、問題回報、遊戲局控制、滑鼠鎖定、按鍵綁定

## 遊戲局控制：移動標靶來回走、不開槍、死了照樣生回標靶；bot 在沙盒找玩家；清除清乾淨
func _case_controller() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m._on_sandbox_pressed()
	var before: int = m.players.get_child_count()
	var w: Node3D = m.add_walker()
	_ck(w != null and Fighter.is_bot_id(w.name.to_int()), "移動標靶的編號要是電腦的（負數）")
	_ck(w.walker and w.bot and not w.is_local, "移動標靶是電腦、不是玩家")
	var ground: float = m._terrain.height(w.patrol_a.x, w.patrol_a.z)
	_ck(absf(w.patrol_a.y - ground) < 0.05 and absf(w.patrol_b.y - ground) < 0.5,
		"巡邏點要貼地（在 %.2f，地面 %.2f）" % [w.patrol_a.y, ground])
	_ck(w.patrol_a.distance_to(w.patrol_b) > 10.0, "要左右來回走一段")
	# 剛生出來的角色這一幀還沒進物理世界，移動不了；檢查它想往巡邏點走、不開槍就好
	var mag: int = w.viewmodel.weapon.mag
	for i in 30:
		w._bot_step(1.0 / 60.0)
	var to_b: Vector3 = (w.patrol_b - w.global_position) * Vector3(1, 0, 1)
	_ck(Vector3(w.velocity.x, 0, w.velocity.z).dot(to_b.normalized()) > 1.0,
		"移動標靶要往巡邏點走（速度 %s）" % w.velocity)
	_ck(w.viewmodel.weapon.mag == mag, "移動標靶不開槍")
	var b: Node3D = m.add_bot()
	_ck(b.bot and not b.walker, "牛仔 bot 要會打")
	_ck(b._bot_threat(m) == m.players.get_node(^"1"), "沙盒裡 bot 要找玩家打，不去打站樁的靶")
	_ck(m.players.get_child_count() == before + 2, "要多兩個電腦")
	# 打死移動標靶：生回來還是移動標靶
	var wid: int = w.name.to_int()
	w.take_damage(9999)
	w.free()
	m._respawn_queue[-1]["at"] = m._time_left + 1.0
	m._respawn_step()
	var back: Node = m.players.get_node_or_null(NodePath(str(wid)))
	_ck(back != null and back.walker, "移動標靶打死要生回移動標靶")
	m.clear_bots()
	var left := 0
	for p in m.players.get_children():
		if Fighter.is_bot_id(p.name.to_int()):
			left += 1
	_ck(left == 0 and m.players.get_child_count() == before, "清除要把電腦都清掉（剩 %d 個）" % left)
	_end(m)

## 牛仔的操作都要有綁鍵，鍵盤和手把兩邊都要（FNE 的約定）
## 滑鼠視角：鎖滑鼠全部走 Fighter.lock_mouse()；只丟卡頓那一下湧進來的位移，其他立刻算
## （以前鎖定後一律擋 1.5 秒，進遊戲、關 Esc 選單、重生都會凍住，2026-10-02、10-07 回報）
func _case_mouse_lock() -> void:
	for f in ["res://main.gd", "res://match_hud.gd", "res://arena_map.gd", "res://settings.gd"]:
		var src := FileAccess.get_file_as_string(f)
		_ck(not src.contains("Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"), "%s 鎖滑鼠要走 Fighter.lock_mouse()，不要直接設" % f)
	var keep := Fighter._frame_ms
	Fighter._frame_ms = Time.get_ticks_msec()
	_ck(not Fighter.after_hitch(), "沒卡頓時滑鼠立刻算（2026-10-07 回報進遊戲、關 Esc 後卡 1 秒）")
	Fighter._frame_ms = Time.get_ticks_msec() - Fighter.HITCH_MS - 100
	_ck(Fighter.after_hitch(), "卡頓後湧進來的位移要擋")
	Fighter._frame_ms = keep

func _case_input_map() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
			"crouch", "crouch_toggle", "fire", "aim", "reload", "melee", "interact", "throw", "ammo_next"]:
		_ck(InputMap.has_action(a), "少了按鍵動作 %s" % a)
		if not InputMap.has_action(a):
			continue
		var kb := false
		var pad := false
		for e in InputMap.action_get_events(a):
			kb = kb or e is InputEventKey or e is InputEventMouseButton
			pad = pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		_ck(kb and pad, "%s 要同時綁鍵鼠和手把" % a)

## 主選單兩層、設定視窗（docs/規劃/2026-10-18-玩家設定.md）
func _case_settings() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	m.settings_path = "user://test_settings.cfg"
	root.add_child(m)
	_ck(m.lobby_page == &"home" and m.get_node(^"UI/Root/Lobby/HomeOnline").visible and not m.get_node(^"UI/Root/Lobby/HostBtn").visible, "一開是首頁：只有四顆大按鈕")
	m.get_node(^"UI/Root/Lobby/HomeOnline").pressed.emit()
	_ck(m.get_node(^"UI/Root/Lobby/HostBtn").visible and m.get_node(^"UI/Root/Lobby/BackBtn").visible, "按「連線對戰」看得到開房和返回")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	m._unhandled_input(esc)
	_ck(m.lobby_page == &"home", "大廳第二層按 Esc 回首頁")
	m.get_node(^"UI/Root/Lobby/HomeSettings").pressed.emit()
	_ck(m.settings.visible, "首頁按「設定」要打開設定視窗")
	m._unhandled_input(esc)
	_ck(not m.settings.visible and m.lobby.visible, "設定開著按 Esc 只關設定")
	# 靈敏度、反轉乘在滑鼠位移上；視野、音量改了馬上套用，重開還在
	m.settings.set_value(&"mouse_sens", 2.0)
	m.settings.set_value(&"invert_y", true)
	_ck(Settings.look(Vector2(3, 4)) == Vector2(6, -8), "靈敏度 2 倍、上下反轉（現在 %s）" % Settings.look(Vector2(3, 4)))
	m.settings.set_value(&"fov", 110.0)
	m.settings.set_value(&"volume", 0.0)
	_ck(AudioServer.is_bus_mute(0), "音量拉到 0 要靜音")
	Settings.v.clear()
	m._load_settings()
	_ck(Settings.v[&"mouse_sens"] == 2.0 and Settings.v[&"invert_y"] and is_equal_approx(Settings.h_fov(Settings.v[&"fov"]), 110.0),
		"設定要存起來，重開照樣讀回來")
	_ck(is_equal_approx(roundf(Settings.h_fov(70.0)), 102.0), "預設視野（垂直 70）顯示成水平 102")
	m.settings.tabs.current_tab = 0
	m.settings.tabs.get_child(0).get_child(-1).pressed.emit()   # 操作頁「恢復預設」
	m.settings.tabs.get_child(2).get_child(-1).pressed.emit()   # 聲音頁
	m.settings.tabs.get_child(1).get_child(-1).pressed.emit()   # 畫面頁
	_ck(Settings.v[&"mouse_sens"] == 1.0 and not Settings.v[&"invert_y"] and Settings.v[&"fov"] == 70.0 and not AudioServer.is_bus_mute(0),
		"每頁的恢復預設要回到原本的手感")
	m.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	# 鏡頭晃動調到 0 只是畫面不晃：被打歪、開槍撞一下照樣讓子彈偏，不然調 0 會比別人準
	var g := _offline_match()
	var c: Node = g._add_player(g.COWBOY, 1)
	c._kick = Vector2(0.05, 0.03)
	var shake0: float = Settings.v.get(&"shake", 1.0)
	Settings.v[&"shake"] = 0.0
	c._process(DT)
	c.viewmodel.spread = 0.0
	var dir: Vector3 = c.viewmodel._spread_direction(c._camera)
	var throw_dir: Vector3 = (c.viewmodel._throw_start()[1] - Vector3.UP * 2.5 - c.velocity).normalized()
	Settings.v[&"shake"] = shake0
	_ck(c._camera.rotation.is_zero_approx() and dir.dot(-c._camera.global_basis.z) < 0.9995
		and throw_dir.dot(-c._camera.global_basis.z) < 0.9995,
		"鏡頭晃動 0：畫面不歪，子彈、炸藥、槍托還是照被打歪的方向")
	_end(g)

## 方位條：0 = 北（-Z），順時針，東 = 90
func _case_compass() -> void:
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(0, 0, -10)), 0.0), "正北（-Z）是 0 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(10, 0, 0)), 90.0), "正東（+X）是 90 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(0, 0, 10)), 180.0), "正南（+Z）是 180 度")
	_ck(is_equal_approx(Compass.bearing(Vector3.ZERO, Vector3(-10, 0, 0)), 270.0), "正西（-X）是 270 度")

## 0.8.1 回饋的介面：大廳順序和存 IP、勝負畫面、重開一局、倒數、boss 體力條、右上角
## 問題回報：錯誤會被記下來、警告不算，F8 存出來的檔有版本、遊戲狀況和錯誤內容
func _case_bug_report() -> void:
	var m := _new_offline_game()
	var r := BugReport.instance
	_ck(r != null, "開遊戲要掛上 bug 收集器")
	r.take_new_error()
	var before := r.error_count()
	push_warning("bug 收集器測試：這是警告")
	_ck(r.error_count() == before and not r.take_new_error(), "警告不算錯誤，不跳提示")
	push_error("bug 收集器測試：這是錯誤")
	push_error("bug 收集器測試：這是錯誤")
	_ck(r.error_count() == before + 1 and r.take_new_error(), "錯誤要記下來、跳提示，同一個只記一次")
	push_error("Node not found: \"Main/Players/123456/Sync\" (relative to \"/root\").")
	push_error("Node not found: \"Main/Players/987654/Sync\" (relative to \"/root\").")
	_ck(r.error_count() == before + 2 and not r.take_new_error(), "玩家加入的時間差錯誤要併成一筆、不跳提示")
	var path: String = m.report_bug()
	_ck(path != "" and FileAccess.file_exists(path), "F8 要存出回報檔（%s）" % path)
	var text := FileAccess.get_file_as_string(path)
	_ck(text.contains("版本：0.8.5") or text.contains("版本：" + str(ProjectSettings.get_setting("application/config/version"))),
		"回報要有版本")
	_ck(text.contains("這是錯誤") and text.contains("共 2 次"), "回報要有錯誤內容和次數")
	_ck(text.contains("遊戲：") and text.contains("當"), "回報要寫在玩什麼、當誰")
	DirAccess.remove_absolute(path)
	# 遊戲裡的版本要跟打包設定一樣（打包只改 export_presets.cfg 的話，回報的版本會是舊的）
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var ver := ""
	for sec in cfg.get_sections():
		if cfg.has_section_key(sec, "application/version"):
			ver = cfg.get_value(sec, "application/version")
	_ck(ver == ProjectSettings.get_setting("application/config/version"),
		"project.godot 的 config/version（%s）要跟 export_presets.cfg 的版本（%s）一樣" % [ProjectSettings.get_setting("application/config/version"), ver])
	_end(m)

func _case_ui() -> void:
	var m := _new_game()
	var lobby: Node = m.lobby
	_ck(lobby.get_node(^"HostBtn").get_index() < lobby.get_node(^"JoinBtn").get_index()
		and lobby.get_node(^"JoinBtn").get_index() < lobby.get_node(^"IPRow").get_index(),
		"大廳順序要是：開房、加入、IP 列")
	# 存 IP：換一個測試用的檔，不動到真的清單
	m.saved_ips_path = "user://test_saved_ips.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.saved_ips_path))
	m._load_saved_ips()
	_ck(m.saved_ips.disabled, "沒存過 IP 時「⋯」要是灰的")
	m.ip_edit.text = "10.1.2.3"
	m._on_save_ip_pressed()
	m._on_save_ip_pressed()
	var popup: PopupMenu = m.saved_ips.get_popup()
	_ck(popup.item_count == 1 and popup.get_item_text(0) == "10.1.2.3", "「＋」要存下目前的 IP，而且不重複")
	m.ip_edit.text = ""
	popup.index_pressed.emit(0)
	_ck(m.ip_edit.text == "10.1.2.3", "「⋯」選了要填回 IP 欄")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.saved_ips_path))

	# boss 體力條：牛仔看不到
	var boss: Node = m.spawn_boss()
	m._match_hud._update_boss_bar(m.players.get_node(^"2"))
	_ck(not m._match_hud._boss_bar.visible, "當牛仔時不該看到 boss 體力條")

	# 倒數：死了之後方位條下面出現重生倒數；撤離中出現撤離倒數
	var me: Node = m.players.get_node(^"2")
	m._match_hud._update_center_info(me)
	m._match_hud._update_center_info(null)
	_ck(m.center_info.text.contains("秒後重生"), "死了要顯示重生倒數（現在「%s」）" % m.center_info.text)
	m._match_hud._update_center_info(me)
	m.egg.carrier = 3
	m.egg.extract = 2.0
	m._match_hud._update_center_info(me)
	_ck(m.center_info.text.contains("還剩 3.0"), "撤離要倒數（現在「%s」）" % m.center_info.text)
	m.egg.extract = 0.0
	m.egg.carrier = 0

	# 勝負：畫面中間大字＋按鈕；主機按重開一局就開新的一局，bot 照樣是 bot
	var bot: Node = m.add_bot()
	var bot_id := bot.name
	m._over = true
	m._finish("時間到，沒有人把蛋帶走")
	_ck(m.result.visible and m.get_node(^"UI/Root/Result/Box/Text").text.contains("時間到"), "勝負要顯示在畫面中間")
	_ck(m.get_node(^"UI/Root/Result/Box/RestartBtn").visible, "開房的人要看得到重開一局")
	m._on_restart_pressed()
	_ck(not m.result.visible and not m._over, "重開一局後勝負畫面要收掉、比賽重新開始")
	_ck(m.players.get_node(NodePath(bot_id)).bot, "重開一局後 bot 還是 bot")
	m._match_hud._update_net_info()
	_ck(m.net_info.text.contains("本機 IP") and m.net_info.text.contains("FPS"), "右上角要有本機 IP 和 FPS（現在「%s」）" % m.net_info.text)
	_ck(m.get_tree().get_nodes_in_group(&"exit_pipe").size() == m._exits.size() * 2, "每個撤離點中間都要有綠色水管")
	m._to_lobby("")
	_ck(not m.result.visible and not m._match_hud._boss_bar.visible, "回大廳後勝負畫面和 boss 體力條都要收掉")
	_end(m)

## 數值表（balance.csv）：讀得到、每列的值都是數字、參數不重複；載入主要場景後沒有查不到的參數；版本檢查的訊息分得清楚
func _case_balance() -> void:
	var f := FileAccess.open(Balance.TABLE, FileAccess.READ)
	_ck(f != null, "數值表 balance.csv 要讀得到")
	if f != null:
		f.get_csv_line()   # 標題列
		var seen := {}
		var rows := 0
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() < 4 or row[0].strip_edges() == "":
				continue
			var key := row[0].strip_edges()
			rows += 1
			_ck(row[3].strip_edges().is_valid_float(), "數值表 %s 的值不是數字（%s）" % [key, row[3]])
			_ck(not seen.has(key), "數值表參數重複：%s" % key)
			seen[key] = true
		_ck(rows > 0, "數值表要有參數")
	_ck(Balance.whole("sweep_damage") == 60 and Balance.num("score_guard") == 12.0 and Balance.num("cowboy_walk") == 4.0,
		"草案數字要照表：甩尾 60、守蛋 12、牛仔走 4.0")
	_ck(Balance.digest().length() == 8, "數值表雜湊要 8 碼")
	var m := _offline_match()
	_ck(Balance.missing.is_empty(), "載入主要場景後，數值表不能查不到參數（%s）" % str(Balance.missing))
	_end(m)
	var Main: GDScript = load("res://main.gd")
	_ck(Main.auth_verdict("0.8.5+aa", "0.8.5+aa") == "", "版本和數值表都一樣：放行")
	var ver_diff: String = Main.auth_verdict("0.8.4+aa", "0.8.5+aa")
	_ck(ver_diff.contains("版本不同") and not ver_diff.contains("aa"), "版本不同：只顯示版本，不顯示雜湊（%s）" % ver_diff)
	var tbl_diff: String = Main.auth_verdict("0.8.5+bb", "0.8.5+aa")
	_ck(tbl_diff.contains("數值表不同") and tbl_diff.contains("aa") and tbl_diff.contains("bb"), "版本一樣、數值表不同：數值表不同的訊息（%s）" % tbl_diff)
	_ck(Main.auth_verdict("0.8.5", "0.8.5+aa").contains("版本不同"), "舊客戶端只送版本：當作版本不同")
