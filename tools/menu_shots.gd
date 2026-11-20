extends SceneTree
## 選單各頁的截圖（docs/企劃/2026-11-20-選單流程.md 前後對照用）。PAGES 用逗號分開，每頁一張 <PREFIX><頁名>.png
##   OUT=docs/image/選單流程 PREFIX=前_ PAGES=home,online,practice godot --path . --resolution 1280x720 --script tools/menu_shots.gd
## 頁名就是 main.LOBBY_PAGES 的鍵；沒登記的頁跳過。room：自己開房（假的兩個人）；room_guest：接著 room，從加入的人看

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
			_m.room.refresh()
		elif pg == &"room_guest":   # 同一個房間，從加入的人看（房主換成別人：設定都是灰的、沒有開始）
			_m.room.host_id = 2
			_m.room.refresh()
		elif _m.LOBBY_PAGES.has(pg):
			_m.lobby_go(pg)
		return false
	RenderingServer.force_draw()   # 視窗被擋住時 macOS 不重畫（同 corpse_shots.gd）
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [OS.get_environment("OUT"), OS.get_environment("PREFIX"), pg])
	_i += 1
	return false
