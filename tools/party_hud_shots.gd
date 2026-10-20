extends SceneTree
## 派對畫面（party_hud.gd）的排版截圖：開沙盒，塞一個假的 Party，各階段各拍一張。
##   OUT=docs/image/派對畫面 godot --path . --resolution 1600x900 --script tools/party_hud_shots.gd

var _f := 0
var _main: Node
var _hud: PartyHud
var _p: Party


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


## 沒放進場景樹的 Party：自己不跑規則，只拿來裝畫面要的值
func _fake_party() -> Party:
	var p := Party.new()
	p.round_index = 1
	p.phase = &"prep"
	p.time_left = 12.0
	p.scores = {1: 13, 2: 21, 3: 9, 4: 4}
	p.round_scores = {1: 2, 2: 1, 3: 0, 4: 10}
	p.lives = {1: 2, 2: 3, 3: 1}
	p.dino_id = 4
	p.names = {1: "阿明", 2: "小華", 3: "大雄", 4: "胖虎"}
	p.last_result = "牛仔 小華 帶蛋撤離"
	return p


func _process(_delta: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 60:
		_main.menu.visible = false
		_hud = _main.get_node("UI/Root").get_children().filter(func(n: Node) -> bool: return n is PartyHud).front()
		_p = _fake_party()
		_main.party = _p
	if _f == 70:
		_save("1_準備_牛仔")
	if _f == 71:
		_p.dino_id = 1
		_p.round_index = 0
		_p.changed.emit()
	if _f == 80:
		_save("2_準備_恐龍")
	if _f == 81:
		_p.dino_id = 4
		_p.phase = &"play"
		_p.time_left = 154.0
		_p.changed.emit()
	if _f == 82:
		_hud.set_process(false)   # Tab 讀的是真鍵盤，截圖時直接打開分數板
		_hud.update_live()
		_hud.board.visible = true
	if _f == 90:
		_save("3_分數板")
		_hud.board.visible = false
		_hud.set_process(true)
		_main.spawn_points.assign([Vector3(-60, 0, -60), Vector3(70, 0, -20), Vector3(40, 0, 70), Vector3(-70, 0, 30),
			Vector3(0, 0, -80), Vector3(-20, 0, 75)])
		var me: Node = _main._me()
		if me:
			me.get_parent().remove_child(me)
			me.free()
	if _f == 92:
		_hud.picked = 2   # 選了第 3 個（Party 沒放進場景樹，不能真的送 request_respawn_at）
	if _f == 100:
		_save("4_選重生點")
	if _f == 101:
		_p.phase = &"result"
		_p.time_left = 5.0
		_p.round_scores = {1: 2, 2: 10, 3: 0, 4: 2}
		_p.changed.emit()
	if _f == 110:
		_save("5_回合結算")
	if _f == 111:
		_p.phase = &"final"
		_p.changed.emit()
	if _f == 120:
		_save("6_最終排名")
		return true
	return false


func _save(n: String) -> void:
	RenderingServer.force_draw()   # 視窗被擋住時 macOS 不重畫（同 corpse_shots.gd）
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % n)
