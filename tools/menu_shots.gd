extends SceneTree
## 選單各頁的截圖（docs/企劃/2026-11-20-選單流程.md 前後對照用）。PAGES 用逗號分開，每頁一張 <PREFIX><頁名>.png
##   OUT=docs/image/選單流程 PREFIX=前_ PAGES=home,online,practice godot --path . --resolution 1280x720 --script tools/menu_shots.gd
## 頁名就是 main.LOBBY_PAGES 的鍵；沒登記的頁跳過。room：自己開房（假的兩個人）；room_guest：接著 room，從加入的人看。
## result、menu、final 要照這個順序：結算畫面、再來一場後的 Esc 選單、一般模式最後結算

var _f := 0
var _m: Node
var _pages: PackedStringArray = OS.get_environment("PAGES").split(",", false)
var _i := 0


func _initialize() -> void:
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)


func _process(_d: float) -> bool:
	_f += 1
	if _f < 20 or _f % 10 != 0:
		return false
	if _i >= _pages.size():
		return true
	var pg := StringName(_pages[_i])
	if _f % 20 == 0:   # 換頁，下一個 10 幀再拍（排版要一幀才會算好）
		if pg == &"room":   # 房間：自己開房，假裝又連進來兩個人（一個勾了想當恐龍）
			_m._on_host_pressed()
			_m.room.join(2)
			_m.room.join(3)
			_m.room.want = [3]
			_m.room.prepared = [1, 3]
			_m.room.refresh()
		elif pg == &"room_guest":   # 同一個房間，從加入的人看（房主換成別人：設定都是灰的、沒有開始）
			_m.room.host_id = 2
			_m.room.refresh()
		elif pg == &"vsbots":   # 單人頁的跟電腦打（離線的房間）
			_m._on_vs_bots_pressed()
		elif pg == &"result":   # 舊模式打完的結算（房主看到的）
			if not _m.room.active:
				_m._on_host_pressed()
			_m.room.ask(&"mode", &"egg")
			_m.room.ask(&"start")
			_m._end_round()
			_m._finish("時間到，沒有人把蛋帶走")
		elif pg == &"menu":   # 同設定再來一場，按 Esc
			_m.room.ask(&"again")
			_m._set_menu(true)
		elif pg == &"final":   # 一般模式 1 局的最後結算（排名框＋按鈕）
			_m._set_menu(false)
			_m.back_to_room()
			_m.room.ask(&"mode", &"normal")
			_m.room.ask(&"rounds", 1)
			_m.room.ask(&"start")
			_m.party.start()
			_m.party.time_left = 0.0
			_m.party.step(0.01)
			_m.party.extracted(1)
		elif _m.LOBBY_PAGES.has(pg):
			_m.lobby_go(pg)
		return false
	RenderingServer.force_draw()   # 視窗被擋住時 macOS 不重畫（同 corpse_shots.gd）
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [OS.get_environment("OUT"), OS.get_environment("PREFIX"), pg])
	_i += 1
	return false
