class_name Raptors
extends Node3D
## 小恐龍哨兵（docs/企劃/2026-11-13-小恐龍.md 的「已決定（2026-11-15）」）：只有派對模式有。
## 尼諾拉按 E 在腳邊放一隻，每回合最多 MAX 隻（死了不補），下回合清空。
## 第一版不會動、只會叫：遊戲中看到牛仔、一直盯滿 STARE 秒就尖叫，尼諾拉的方位條標「這隻小恐龍」的位置 MARK 秒（不標牛仔）。
## 同一隻 COOLDOWN 秒叫一次。尼諾拉傷不到；子彈、槍托、炸藥、爆炸桶都打得死（血 HP）。
## 主機說了算：放、死、叫都在主機決定，位置和死活整包送（_recv），晚進來的人在 main._spawn 補送（send_to）。照 barrels.gd 的寫法。
## 不放在 Players 底下：那裡的每個節點都會被當成玩家（算牛仔、算存活、找目標）。

# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var MAX: int = Balance.whole("raptor_max")
static var HP: int = Balance.whole("raptor_hp")
static var SIGHT: float = Balance.num("raptor_sight")
static var SIGHT_CROUCH: float = Balance.num("raptor_sight_crouch")
static var STARE: float = Balance.num("raptor_stare")
static var COOLDOWN: float = Balance.num("raptor_scream_cd")
static var MARK: float = Balance.num("raptor_mark_seconds")
static var CLEAR: float = Balance.num("raptor_place_clear")
const FEEL := 3.0            # 這麼近不管方向都會發現
const CONE := 0.5            # cos 60°：正前方左右各 60 度
const EYE := 1.5             # 眼睛離地多高
const LOOK_EVERY := 0.1      # 主機每幾秒看一次（不用每個物理幀打射線）
const HEIGHT := 2.0          # 身高（公尺）
const MODEL_HEIGHT := 5.4    # 尼諾拉模型原本的身高（dino.tscn：膠囊 8.1 ÷ 模型縮放 1.5）
const BODY := Vector3(0.9, 1.7, 2.6)   # 碰撞方塊（寬、高、長）：子彈、槍托打得到身體和頭
const COLOR := Color(0.36, 0.55, 0.3)  # 換色：綠色的小尼諾拉
const SCREAM := preload("res://assets/audio/dino/yelp.wav")   # ponytail: 先把尼諾拉的叫聲調高頂著，正式的尖叫聲之後用 moss-sfx 生

var spots := PackedVector3Array()   # 每隻的位置（地面）
var yaws := PackedFloat32Array()    # 每隻面向哪（跟放的時候的尼諾拉一樣）
var alive := PackedByteArray()      # 1 = 還活著
var marks := {}                     # 每台：第幾隻 -> 方位條標到幾點（毫秒）
var _hp := PackedInt32Array()       # 主機
var _stare := PackedFloat32Array()  # 主機：盯了幾秒
var _cd := PackedFloat32Array()     # 主機：還要幾秒才能再叫
var _acc := 0.0

@onready var main: Node = get_parent()


## 這回合還能放幾隻（死掉的不補回）
func left() -> int:
	return maxi(MAX - spots.size(), 0)


## 主機：清空（新的回合、新的一局）
func clear() -> void:
	spots = PackedVector3Array()
	yaws = PackedFloat32Array()
	alive = PackedByteArray()
	_hp = PackedInt32Array()
	_stare = PackedFloat32Array()
	_cd = PackedFloat32Array()
	_send()


## 主機：在 q（地面）放一隻，面向 yaw
func add(q: Vector3, yaw: float) -> void:
	spots.append(q)
	yaws.append(yaw)
	alive.append(1)
	_hp.append(HP)
	_stare.append(0.0)
	_cd.append(0.0)
	_send()


## 放不放得下（空字串 = 可以）：離保險箱、信封、牛仔出生點至少 CLEAR；不在建築、石頭、樹裡
func why_not(q: Vector3) -> String:
	var p := Vector2(q.x, q.z)
	var near := func(o: Vector3) -> bool: return p.distance_to(Vector2(o.x, o.z)) < CLEAR
	if main.safe.on and near.call(main.safe.global_position):
		return "離保險箱太近，不能放小恐龍"
	if main.party and main.party.env_pos.any(near):
		return "離信封太近，不能放小恐龍"
	if main.spawn_points.any(near):
		return "離牛仔出生點太近，不能放小恐龍"
	if not main._is_clear(p, 0.6):
		return "這裡放不下小恐龍"
	return ""


## 主機：電腦當恐龍時開回合放滿：雙數隻放在信封附近（離信封 CLEAR～CLEAR+10 公尺、面向信封），其餘放隨機空地、隨便面向。
## 抽不到合格的位置就少放一隻
func auto_place() -> void:
	var envs: Array = main.party.env_pos if main.party and main.safe.on else []
	for k in MAX:
		for tries in 50:
			var e: Vector3 = envs[(k / 2) % envs.size()] if k % 2 == 0 and not envs.is_empty() else Vector3.INF
			var q: Vector3 = main._spawn_point() if e == Vector3.INF \
				else e + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(CLEAR, CLEAR + 10.0)
			q = main._on_ground(Vector3(q.x, 0.0, q.z))
			if why_not(q) == "":
				add(q, randf() * TAU if e == Vector3.INF else atan2(q.x - e.x, q.z - e.z))
				break


## 主機：id 這個人要放一隻（在尼諾拉前面腳邊）。回傳空字串 = 放了，不然是不能放的原因
func place_by(id: int) -> String:
	var p: Party = main.party
	var b: Node3D = main._boss()
	if p == null or b == null or p.dino_id != id or b.pilot != id or not p.phase in [&"prep", &"play"]:
		return "現在不能放小恐龍"
	if left() <= 0:
		return "小恐龍放完了"
	if b.down_left > 0.0:
		return "倒地中不能放小恐龍"
	var fwd := -b.global_basis.z
	var at: Vector3 = b.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * (b.BODY_RADIUS + 1.0)
	var q: Vector3 = main._on_ground(Vector3(at.x, 0.0, at.z))
	var why := why_not(q)
	if why == "":
		add(q, b.rotation.y)
	return why


## 尼諾拉按 E（_process）：客戶端送到主機。不能放的原因送回本人
@rpc("any_peer", "call_remote", "reliable")
func request_place() -> void:
	if not multiplayer.is_server():
		request_place.rpc_id(1)
		return
	var from := multiplayer.get_remote_sender_id()
	var id := from if from != 0 else multiplayer.get_unique_id()
	var why := place_by(id)
	if why == "":
		return
	if id == multiplayer.get_unique_id():
		_say(why)
	else:
		_say.rpc_id(id, why)


@rpc("authority", "call_remote", "reliable")
func _say(msg: String) -> void:
	main.status.text = msg


func _process(_delta: float) -> void:
	var p: Party = main.party
	if p == null or multiplayer.multiplayer_peer == null or p.dino_id != multiplayer.get_unique_id() or not p.phase in [&"prep", &"play"]:
		return
	if Input.is_action_just_pressed(&"dino_raptor") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		request_place()


## 主機、遊戲中每個物理幀（party.step）：每 LOOK_EVERY 秒看一次。一直看得到人滿 STARE 秒就叫
func step(delta: float) -> void:
	_acc += delta
	if _acc < LOOK_EVERY:
		return
	var dt := _acc
	_acc = 0.0
	var cows: Array = main.players.get_children().filter(func(c: Node) -> bool:
		return c is Cowboy and c.hp > 0 and not c.is_queued_for_deletion())
	for i in spots.size():
		if alive[i] == 0:
			continue
		_cd[i] -= dt
		_stare[i] = _stare[i] + dt if cows.any(func(c: Node3D) -> bool: return can_see(i, c)) else 0.0
		if _stare[i] >= STARE and _cd[i] <= 0.0:
			_stare[i] = 0.0
			_cd[i] = COOLDOWN
			_scream.rpc(i)
			var b: Node = main._boss()
			if b and b.pilot == 0:   # 電腦尼諾拉：跑過去看
				b.alarm(spots[i])


## 第 i 隻看不看得到 c：3 公尺內一定看到；蹲在灌木裡看不到；站著 SIGHT、蹲著 SIGHT_CROUCH；只看前方；被牆擋住看不到
func can_see(i: int, c: Node3D) -> bool:
	var to := c.global_position - spots[i]
	var flat := Vector2(to.x, to.z).length()
	if flat < FEEL:
		return true
	if main.hidden_in_bush(c) or flat > (SIGHT_CROUCH if c.get(&"sync_crouching") == true else SIGHT):
		return false
	if Vector2(-sin(yaws[i]), -cos(yaws[i])).dot(Vector2(to.x, to.z) / flat) < CONE:
		return false
	var q := PhysicsRayQueryParameters3D.create(spots[i] + Vector3.UP * EYE, c.global_position + Vector3.UP,
		1, [(get_child(i) as CollisionObject3D).get_rid(), (c as CollisionObject3D).get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 每台：第 i 隻尖叫。尼諾拉那台在方位條標牠 MARK 秒、跳一行字；牛仔聽得到
@rpc("authority", "call_local", "reliable")
func _scream(i: int) -> void:
	if i < 0 or i >= spots.size() or i >= get_child_count():
		return
	marks[i] = Time.get_ticks_msec() + int(MARK * 1000.0)
	var s := AudioStreamPlayer3D.new()
	s.stream = SCREAM
	s.pitch_scale = 1.7
	s.unit_size = 15.0
	s.max_db = 4.0
	get_child(i).add_child(s)
	s.position.y = EYE
	s.play()
	s.finished.connect(s.queue_free)
	var p: Party = main.party
	if p and multiplayer.multiplayer_peer != null and p.dino_id == multiplayer.get_unique_id():
		main.status.text = "小恐龍在叫！"


## 尼諾拉的方位條：正在標的小恐龍位置
func marked() -> Array:
	var now := Time.get_ticks_msec()
	var out := []
	for i: int in marks:
		if int(marks[i]) > now and i < alive.size() and alive[i] == 1:
			out.append(spots[i])
	return out


## 主機：第 i 隻挨打（Raptor.take_damage）。尼諾拉打的不算
func hurt(i: int, amount: int, source: Node) -> void:
	if not multiplayer.is_server() or i < 0 or i >= alive.size() or alive[i] == 0 or amount <= 0:
		return
	if is_instance_valid(source) and source.is_in_group(&"dino"):
		return
	_hp[i] -= amount
	if _hp[i] <= 0:
		kill(i)


## 主機：爆炸（Explosive.damage）範圍裡的都死。ponytail: 不看有沒有擋住（同爆炸桶的 blast）
func blast(at: Vector3, radius: float) -> void:
	var hit := false
	for i in spots.size():
		if alive[i] == 1 and (spots[i] + Vector3.UP).distance_to(at) < radius:
			alive[i] = 0
			hit = true
	if hit:
		_send()


func kill(i: int) -> void:
	alive[i] = 0
	_send()


func _send() -> void:
	_recv(spots, yaws, alive)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_recv.rpc(spots, yaws, alive)


## 主機：晚進來的人補送一次
func send_to(id: int) -> void:
	_recv.rpc_id(id, spots, yaws, alive)


@rpc("authority", "call_remote", "reliable")
func _recv(pts: PackedVector3Array, ys: PackedFloat32Array, a: PackedByteArray) -> void:
	spots = pts
	yaws = ys
	alive = a
	while get_child_count() > spots.size():
		var c := get_child(get_child_count() - 1)
		remove_child(c)
		c.queue_free()
	for i in range(get_child_count(), spots.size()):
		_make(i)
	for i in spots.size():
		var r := get_child(i) as StaticBody3D
		r.visible = alive[i] == 1
		r.collision_layer = 1 if alive[i] == 1 else 0
	if spots.is_empty():
		marks.clear()


func _make(i: int) -> void:
	var r := Raptor.new()
	r.name = "R%d" % i
	r.index = i
	r.raptors = self
	r.max_hp = HP
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY
	shape.shape = box
	shape.position.y = BODY.y * 0.5
	r.add_child(shape)
	# 外觀：尼諾拉的模型縮小、換色（擺著不動，不跑 trex.gd 的骨架動畫）
	var m: Node3D = Trex.MODEL_TRIPO.instantiate()
	m.scale = Vector3.ONE * HEIGHT / MODEL_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.9
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	r.add_child(m)
	r.add_to_group(&"raptor")
	add_child(r)
	r.global_position = spots[i]
	r.rotation.y = yaws[i]
	var b: Node = main._boss()
	if b:   # 不擋尼諾拉的路
		b.add_collision_exception_with(r)


class Raptor extends StaticBody3D:
	var index := 0
	var raptors: Raptors
	var max_hp := 1

	## 子彈、槍托（主機，Cowboy.deal_damage／main.request_damage）
	func take_damage(amount: int, source: Node = null) -> void:
		raptors.hurt(index, amount, source)
