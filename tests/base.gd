extends SceneTree

const BOSS_GD := preload("res://boss.gd")   # 尼諾拉的尺寸（LIFT 等），生怪要用
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

var _deferred: Array = []   # [到期的幀數, Callable]：要等物理幀才驗得到的（剛加進場景的物體，射線和形狀查詢要跑過一幀才看得到）

## 過 after 幀再執行 fn（test_battle.gd 的 _process 每幀呼叫 _run_deferred）
func _defer(after: int, fn: Callable) -> void:
	_deferred.append([_frames + after, fn])

func _run_deferred() -> void:
	for d: Array in _deferred.duplicate():
		if _frames >= d[0]:
			_deferred.erase(d)
			d[1].call()

## 測試的對局收起來：match、arena、ground 群組拿掉。這些群組的「第一個」是正式的對局（HUD、子彈、火球、爆炸都找它），
## 測試的對局不能搶；要跑物理的那段才用 _with_first 放回去
func _park(m: Node) -> void:
	m.remove_from_group(&"match")
	m.map.remove_from_group(&"arena")
	for c: Node in m.map.get_children():
		if c.is_in_group(&"ground"):
			c.remove_from_group(&"ground")
			c.set_meta(&"parked", true)

## 這一段要用「第一個」對局、場地、地面、boss、dino（子彈、火球、爆炸、HUD 都找它們）：別處的先移出群組，做完再放回去（順序不變）
const FIRST_GROUPS := [&"match", &"arena", &"ground", &"boss", &"dino"]
func _with_first(m: Node, fn: Callable) -> void:
	var others := {}
	for g: StringName in FIRST_GROUPS:
		var list: Array = get_nodes_in_group(g).filter(func(n: Node) -> bool: return not (n == m or m.map.is_ancestor_of(n)))
		others[g] = list
		for o: Node in list:
			o.remove_from_group(g)
	m.add_to_group(&"match")
	m.map.add_to_group(&"arena")
	_unpark_ground(m, true)
	fn.call()
	m.remove_from_group(&"match")
	m.map.remove_from_group(&"arena")
	_unpark_ground(m, false)
	for g: StringName in FIRST_GROUPS:
		for o: Node in others[g]:
			o.add_to_group(g)

func _unpark_ground(m: Node, on: bool) -> void:
	for c: Node in m.map.get_children():
		if on and c.has_meta(&"parked"):
			c.add_to_group(&"ground")
			c.remove_meta(&"parked")
		elif not on and c.is_in_group(&"ground"):
			c.remove_from_group(&"ground")
			c.set_meta(&"parked", true)

## 要跑物理的測試對局放在自己的物理世界（SubViewport 的 own_world_3d）：和別的測試的場地不互撞、射線打不到別人的地形
func _isolated_match() -> Node:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	root.add_child(vp)
	var m: Node = load("res://main.tscn").instantiate()
	vp.add_child(m)
	m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	m._offline = true
	m._enter_game("test")
	return m

## 收掉 _isolated_match 的對局（不動連線：多個對局共用同一個 root 的 multiplayer，_end 會把它設成 null，別的測試還在用）
func _free_map(m: Node) -> void:
	var vp := m.get_parent()
	root.remove_child(vp)
	vp.free()

func _ck(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)

func _done() -> bool:
	if not _deferred.is_empty():
		_ck(false, "延後的檢查沒有跑完（還剩 %d 個）" % _deferred.size())
	if _fails > 0:
		printerr("有 %d 項失敗" % _fails)
		quit(1)
	else:
		print("OK：生怪、傷害、時間到判勝、重生、咬擊方向、離線兩種模式、牛仔身分與開槍、按鍵綁定、三把槍與左輪扳擊錘換彈動作音效不延遲子彈下墜有效射程爆頭閉氣蹲穩摔落輕重近戰一條體力、沙盒、鄉村柵欄灌木貼圖、著彈碎屑與煙囪煙、地形起伏、F 開門爬梯子、翻柵欄和窗台、手腳、只剩連線和沙盒、遊戲局控制、回大廳重開、建築擋視線、圍牆擋出界、暴龍骨架與尾巴慣性、側傾與位移延遲、開槍命中恐龍、恐龍跳躍、牛仔 bot、體力規則、衝刺技能、蛋與撤離、恐龍撿不到蛋、火球、恐龍攻擊開關、介面（大廳存 IP、勝負畫面、倒數）、中彈踉蹌、恐龍 boss 行為樹（導演、兩招預備動作、導航網格）、方位條、測試站自動開下一局、問題回報、滑鼠鎖定不凍視角、灰盒地圖都正常、主機檢查移動和傷害額度、斷線重連拿回命數和分數、恐龍沙盒叫獵人清獵人、數值表、主副武器鍵、補血包、輕攻擊扇形、甩尾半圈、踩踏、燃燒、火球、選裝、彈藥數量、方塊房子（等級 1、2、3、火球、炸藥、子彈穿材質）、玩具積木第二批（積木樹石頭柵欄、衝撞踢碎塊、超過上限併成大塊）、玩具積木（切塊、安全屋、連通、碎塊停下、晚加入、新的一場、非派對甩尾、子彈穿塊、甩尾上限、真房子拆下排）、尼諾拉放大細節（生怪高度、炸藥、撿蛋、電腦起招、火球俯角、甩尾拆地形、空材質、恐龍碰撞開關）、專用伺服器碎塊直接落地（不飛、疊得住、踢開）、積木範圍拆、導航網格解析（沒拆過的積木存起來重用、拆過的重解析）、蛋不被碎塊埋住、尼諾拉操作提示與命中回饋、子彈不穿牆（分級先關）、尼諾拉踩碎塊不踢、走路推開碎塊、伺服器往兩旁踢、尼諾拉衝撞不停（先拆再走、撞進去卡一下、碎塊照速度飛）、獵人跳高一點（低於柵欄）、自動跨上矮碎塊、翻高到 2.2 公尺、卡在碎塊中間也能跳、保險箱密碼（猜錯變灰、一次一人、走開作廢、開箱撿蛋）")
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
