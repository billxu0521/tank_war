class_name Destructible
extends StaticBody3D
## 派對模式拆得掉的地形（docs/企劃/派對玩法.md、規則草案 4.2）。等級 1 挨一下就倒、2 挨兩下、3 打不壞（甩尾、火球、炸藥都不行）。
## 樹是 2、灰盒房子是 2、方塊房子的每一塊照它的等級。
## arena_map.gd 蓋場地時把樹幹、灰盒房子的 body 換成這個腳本、加進群組 destructible（_destructible）。安全屋不加，拆不掉。
##
## 主機說了算：boss.gd 的甩尾打中就呼叫 tail_hit，主機記次數、廣播給所有人（包括自己）。
## 節點名字由 arena_map.gd 依序取（Wreck0、Wreck1…），每台蓋出來一樣，RPC 才找得到同一個（同 Door）。
## 晚加入的人由 main.gd 在他連進來時補送被打過的（instant 直接到位）。
##
## ponytail: 倒了只是藏起來、碰撞拿掉，節點留著：晚加入補送、重複的 RPC 都還找得到它。bot 找掩體用的擺設清單（_level）不會跟著改

var level := 1         # 耐久等級（草案 4.2）：1、2 挨 hits_needed 下倒，3 不能被甩尾、火球、炸藥破壞
var hits_needed := 1   # 倒下要挨的次數（等級 1、2 就是等級本身）
var hits := 0
## 外觀不在這個 body 底下的（樹的模型是另外擺的），倒的時候一起動、一起藏
var visual: Node3D
var _home: Array = []   # 第一次挨打前的樣子 [自己的 transform, 外觀的 transform, 碰撞層]，restore 用

## 挨打、倒下的回饋：鏡頭震（離本機鏡頭越遠越小）、操作恐龍的那台停一下、播音效。各台自己算，不另外送 RPC
const SHAKE_RANGE := 25.0   # 離鏡頭超過這個距離（公尺）就不震
const HIT_SOUND := "res://assets/audio/destruction/wood_crack.wav"
const TREE_FALL_SOUND := "res://assets/audio/destruction/tree_fall.wav"
const HOUSE_FALL_SOUND := "res://assets/audio/destruction/house_collapse.wav"


## 甩尾、火球打中一下（主機才算）
func tail_hit(from: Vector3) -> void:
	if multiplayer.is_server() and level < 3 and hits < hits_needed:
		_set_hits.rpc(hits + 1, from, false)


## 炸藥爆炸（主機才算）：範圍內等級 1 的挨一下（一下就倒），等級 2、3 不受影響（草案 4.2 一般炸彈）。
## ponytail: 只看距離，不算中間有沒有牆擋住；方塊房子的牆互相擋住的話，爆炸會穿過去拆後面的等級 1 方塊
static func blast(world: Node3D, at: Vector3, radius: float) -> void:
	for w: Node in world.get_tree().get_nodes_in_group(&"destructible"):
		var d := w as Destructible
		if d and d.level == 1 and d.global_position.distance_to(at) < radius:
			d.tail_hit(at)


@rpc("authority", "call_local", "reliable")
func _set_hits(n: int, from: Vector3, instant: bool) -> void:
	if _home.is_empty():
		_home = [transform, visual.transform if visual else Transform3D(), collision_layer]
	hits = n
	if n < hits_needed:
		if not instant:
			_shake()
			_smash_fx(false)
		return
	collision_layer = 0   # 碰撞馬上拿掉：人、子彈、恐龍都穿得過，重烘導航網格也不會算進去
	remove_from_group(&"destructible")
	if multiplayer.is_server():
		var g := get_tree().get_first_node_in_group(&"match")
		if g and g.has_method(&"bake_nav"):
			g.bake_nav(true)
	if instant:
		_hide_all()
	elif visual:
		_smash_fx(true)
		_sfx(TREE_FALL_SOUND, 80.0)
		_topple(from)
	else:
		_smash_fx(true)
		_sfx(HOUSE_FALL_SOUND, 80.0)
		_collapse()


## 挨打（down = 這一下把它打倒）：碎裂聲、鏡頭震、操作恐龍的那台停一下。回傳這台鏡頭震了多少（測試用）
func _smash_fx(down: bool) -> float:
	_sfx(HIT_SOUND, 40.0)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	# 從鏡頭往上找第一個有 add_shake 的（牛仔的鏡頭在 Head 底下，恐龍的在 CamPivot 底下）
	var who: Node = cam.get_parent()
	while who and not who.has_method(&"add_shake"):
		who = who.get_parent()
	if who == null:
		return 0.0
	var k: float = clampf(1.0 - cam.global_position.distance_to(global_position) / SHAKE_RANGE, 0.0, 1.0) * Settings.v.get(&"shake", 1.0)
	var amount: float = (0.08 if down else 0.03) * k
	who.add_shake(amount)
	if who.has_method(&"add_hitstop"):
		who.add_hitstop(0.1 if down else 0.06)
	return amount


## 3D 音效播一次、播完自己收掉（照 shot_fx.gd 的 impact_sound）。檔案還沒放進來就安靜跳過
func _sfx(path: String, max_dist: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var snd := AudioStreamPlayer3D.new()
	get_parent().add_child(snd)
	snd.stream = load(path)
	snd.max_distance = max_dist
	snd.global_position = global_position + Vector3.UP * _height() * 0.5
	snd.play()
	snd.finished.connect(snd.queue_free)


## 還沒倒：抖一下、掉一點灰（看得出來挨了一下）
func _shake() -> void:
	var p := position
	var t := create_tween()
	for i in 4:
		t.tween_property(self, "position", p + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)), 0.05)
	t.tween_property(self, "position", p, 0.05)
	Fx.dust(get_parent(), global_position + Vector3.UP * _height(), Vector3.DOWN, 1.2, 14, 2.0, 2.0)


## 樹：往被甩的反方向倒下，揚一團土，過一下沉進地裡
func _topple(from: Vector3) -> void:
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var b0 := visual.basis
	var t := create_tween()
	t.tween_method(func(a: float) -> void: visual.basis = Basis(axis, a) * b0, 0.0, PI * 0.5, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: Fx.dust(get_parent(), visual.global_position + away * 3.0, Vector3.UP, 1.4, 16, 3.0, 2.0))
	t.tween_interval(3.0)
	t.tween_property(visual, "position", visual.position + Vector3.DOWN * 2.0, 1.5)
	t.tween_callback(_hide_all)


## 房子：整棟往下塌進地裡，周圍一圈土
func _collapse() -> void:
	var h := _height()
	Fx.dust_ring(get_parent(), global_position, 6.0, 40, 6.0, 1.6)
	var t := create_tween()
	t.tween_property(self, "position", position + Vector3.DOWN * (h + 1.0), 1.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_hide_all)


## 新的一場（party.gd 的 start）：拆過的全部立回來。導航網格由呼叫的人重烘一次
@rpc("authority", "call_local", "reliable")
func restore() -> void:
	if _home.is_empty():
		return
	# ponytail: 不管還在播的倒下動畫：動畫 5 秒內播完，新的一場在 final 30 秒之後
	hits = 0
	transform = _home[0]
	if visual:
		visual.transform = _home[1]
		visual.show()
	collision_layer = _home[2]
	add_to_group(&"destructible")
	show()


func _hide_all() -> void:
	hide()
	if visual:
		visual.hide()


## 外觀多高（灰盒房子的網格在自己底下；樹沒有，給個大概）
func _height() -> float:
	for c in get_children():
		if c is MeshInstance3D:
			return (c as MeshInstance3D).get_aabb().end.y
	return 3.0
