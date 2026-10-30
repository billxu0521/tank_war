extends SceneTree

var _fails := 0
var _shooter: Node
var _brawler: Node
var _hp_before_shot := 0
var _dino: Node
var _jump_from := 0.0
var _phase := 0
var _bot_game: Node
var _bot_cowboy: Node3D
var _bot_from := Vector2.ZERO
var _bot_frames := 0
var _frames := 0
const DT := 1.0 / 120.0

func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)

func _done() -> bool:
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、時間到判勝、重生、咬擊方向、離線兩種模式、牛仔身分與開槍、按鍵綁定、三把槍與左輪扳擊錘換彈動作音效不延遲子彈下墜有效射程爆頭閉氣蹲穩摔落輕重近戰一條體力、沙盒、鄉村柵欄灌木貼圖、著彈碎屑與煙囪煙、地形起伏、F 開門爬梯子、翻柵欄和窗台、手腳、只剩連線和沙盒、遊戲局控制、回大廳重開、建築擋視線、圍牆擋出界、暴龍骨架與尾巴慣性、側傾與位移延遲、開槍命中恐龍、恐龍跳躍、牛仔 bot、體力規則、衝刺技能、蛋與撤離、恐龍撿不到蛋、火球、恐龍攻擊開關、介面（大廳存 IP、勝負畫面、倒數）、中彈踉蹌、恐龍 boss 行為樹（導演、兩招預備動作、導航網格）、方位條、測試站自動開下一局、問題回報、滑鼠鎖定不凍視角、灰盒地圖都正常、主機檢查移動和傷害額度、斷線重連拿回命數和分數、恐龍沙盒叫獵人清獵人、數值表、主副武器鍵")
	return true

# --- 共用 ---

## 測試用的對局：不走大廳按鈕（扮演模式拿掉了），直接組。恐龍的規則還要測，恐龍留著
func _offline_match() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	return m

## 恐龍（編號 1，操控得動）＋兩個牛仔（2、3，在這台機器上是「別人的」）
func _new_game() -> Node:
	var m := _offline_match()
	m._add_player(m.DINO, 1)
	m._add_player(m.COWBOY, 2)
	m._add_player(m.COWBOY, 3)
	_ck(m._cowboys == 2, "應該有兩個牛仔")
	_ck(m.players.get_node(^"1").hp == m.players.get_node(^"1").max_hp, "恐龍滿血出生")
	_ck(m.players.get_node(^"2").hp == m.players.get_node(^"2").max_hp, "牛仔滿血出生")
	return m

## 自己的牛仔（編號 1）＋一隻恐龍 bot
func _new_offline_game() -> Node:
	var m := _offline_match()
	m._add_player(m.COWBOY, 1).global_position = m._on_ground(Vector3(-20, 1.0, 15))
	var d: Node3D = m._add_player(m.DINO, 2)
	d.set(&"bot", true)
	return m

## 自己的恐龍（編號 1）＋三個牛仔 bot
func _dino_vs_bots() -> Node:
	var m := _offline_match()
	m._add_player(m.DINO, 1)
	for i in 3:
		m._add_player(m.COWBOY, 2 + i).set(&"bot", true)
	return m

func _end(m: Node) -> void:
	if m.multiplayer.multiplayer_peer != null:
		m.multiplayer.multiplayer_peer.close()
		m.multiplayer.multiplayer_peer = null
	root.remove_child(m)
	m.free()

# --- 案例 ---

var _ik_rig: CowboyRig
var _ik_flat := Vector2.ZERO   # 平地時左、右腳踝的高度


var _pierce_wall: StaticBody3D
