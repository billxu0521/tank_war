class_name Raptors
extends Node3D
## 小恐龍哨兵（docs/企劃/2026-11-13-小恐龍.md 的「已決定（2026-11-15）」）：只有派對模式有。
## 尼諾拉按 E 在腳邊放一隻，每回合最多 MAX 隻（死了不補），下回合清空。
## 會全場遊走：遊戲中從目前位置抽 LEG×0.4～LEG 公尺外的隨機點走過去、停 PAUSE 秒左右再換一點，一段一段走遍全場（放下的地方只是起點）。
## 直線走，走之前檢查路上沒牆、不進禁止範圍、不出場；走著前面被擋就停、馬上換一點（換方向）。
## 看到牛仔就停下來、面向他，一直盯滿 STARE 秒就尖叫，尼諾拉的方位條標「這隻小恐龍」的位置 MARK 秒（不標牛仔）。
## 同一隻 COOLDOWN 秒叫一次。尼諾拉傷不到；子彈、槍托、炸藥、爆炸桶都打得死（血 HP）。
## 主機說了算：放、死、叫、要走去哪都在主機決定，位置、目標點和死活整包送（_recv）：只有換目標、停下來時送，
## 每台自己照 SPEED 往目標點走（_physics_process），收到新的一包就對齊主機的位置。晚進來的人在 main._spawn 補送（send_to）。照 barrels.gd 的寫法。
## 不放在 Players 底下：那裡的每個節點都會被當成玩家（算牛仔、算存活、找目標）。
##
## 金色小恐龍（追分星星，docs/企劃/2026-11-15-畫面與保險箱位置.md 的 1.1）：派對第四回合開場 party 叫 add_gold 生一隻（第 gold 隻）。
## 不當哨兵（不看、不尖叫、不報信），一樣全場走；每 GOLD_CALL 秒叫一聲，大家都聽得到；方位條大家都標。
## 血 GOLD_HP，尼諾拉也打得死（boss._victims），炸藥照距離扣血不是一炸就死。死了 party.drop_star 把星星丟在牠的位置。

# 以下從 balance.csv 讀（見 balance.gd），改數字去改表
static var MAX: int = Balance.whole("raptor_max")
static var HP: int = Balance.whole("raptor_hp")
static var SIGHT: float = Balance.num("raptor_sight")
static var SIGHT_CROUCH: float = Balance.num("raptor_sight_crouch")
static var STARE: float = Balance.num("raptor_stare")
static var COOLDOWN: float = Balance.num("raptor_scream_cd")
static var MARK: float = Balance.num("raptor_mark_seconds")
static var CLEAR: float = Balance.num("raptor_place_clear")
static var LEG: float = Balance.num("raptor_leg")
static var SPEED: float = Balance.num("raptor_walk_speed")
static var PAUSE: float = Balance.num("raptor_pause")
static var GOLD_HP: int = Balance.whole("gold_raptor_hp")
static var GOLD_CALL: float = Balance.num("gold_raptor_call_seconds")
const GOLD_COLOR := Color(1.0, 0.78, 0.2)
const FEEL := 3.0            # 這麼近不管方向都會發現
const CONE := 0.5            # cos 60°：正前方左右各 60 度
const EYE := 1.5             # 眼睛離地多高
const KNEE := 0.7            # 檢查路上有沒有東西的射線離地多高
const RAY_STEP := 2.0        # 檢查路上的射線每段多長（每段兩頭貼地，跟著地形起伏）
const LOOK_EVERY := 0.1      # 主機每幾秒看一次（不用每個物理幀打射線）
const HEIGHT := 2.0          # 身高（公尺）
const MODEL_HEIGHT := 5.4    # 尼諾拉模型原本的身高（dino.tscn：膠囊 8.1 ÷ 模型縮放 1.5）
const BODY := Vector3(0.9, 1.7, 2.6)   # 碰撞方塊（寬、高、長）：子彈、槍托打得到身體和頭
const COLOR := Color(0.36, 0.55, 0.3)  # 換色：綠色的小尼諾拉
const SCREAM := preload("res://assets/audio/dino/yelp.wav")   # ponytail: 先把尼諾拉的叫聲調高頂著，正式的尖叫聲之後用 moss-sfx 生

var spots := PackedVector3Array()   # 每隻現在的位置（地面；每台自己往 goals 走）
var goals := PackedVector3Array()   # 每隻要走去哪（地面；跟 spots 一樣就是站著）
var yaws := PackedFloat32Array()    # 每隻面向哪（放的時候跟尼諾拉一樣；走路面向走的方向、盯人面向牛仔）
var alive := PackedByteArray()      # 1 = 還活著
var marks := {}                     # 每台：第幾隻 -> 方位條標到幾點（毫秒）
var _hp := PackedInt32Array()       # 主機
var _stare := PackedFloat32Array()  # 主機：盯了幾秒
var _cd := PackedFloat32Array()     # 主機：還要幾秒才能再叫
var _wait := PackedFloat32Array()   # 主機：走到了還要停幾秒
var _acc := 0.0
var gold := -1                      # 金色小恐龍是第幾隻（-1 = 沒有）

@onready var main: Node = get_parent()


## 這回合還能放幾隻（死掉的不補回）
func left() -> int:
	return maxi(MAX - spots.size() + (1 if gold >= 0 else 0), 0)


## 主機：清空（新的回合、新的一局）
func clear() -> void:
	spots = PackedVector3Array()
	goals = PackedVector3Array()
	yaws = PackedFloat32Array()
	alive = PackedByteArray()
	_hp = PackedInt32Array()
	_stare = PackedFloat32Array()
	_cd = PackedFloat32Array()
	_wait = PackedFloat32Array()
	gold = -1
	_send()


## 主機：在 q（地面）放一隻，面向 yaw
func add(q: Vector3, yaw: float) -> void:
	spots.append(q)
	goals.append(q)
	yaws.append(yaw)
	alive.append(1)
	_hp.append(HP)
	_stare.append(0.0)
	_cd.append(0.0)
	_wait.append(randf() * PAUSE)
	_send()


## 主機：在隨機空地（爆炸桶的抽法）生金色小恐龍。抽不到合格的就放在最後抽的那點
func add_gold() -> void:
	var q := Vector3.ZERO
	for tries in 100:
		q = main._on_ground(main._spawn_point() * Vector3(1, 0, 1))
		if why_not(q) == "" and main.barrels._ok(q, PackedVector3Array(), 0.0):
			break
	gold = spots.size()
	add(q, randf() * TAU)
	_hp[gold] = GOLD_HP
	_cd[gold] = GOLD_CALL * 0.5


## 活著的金色小恐龍（沒有就 null）：尼諾拉的攻擊、方位條用
func gold_body() -> Node3D:
	return get_child(gold) as Node3D if gold >= 0 and gold < alive.size() and gold < get_child_count() and alive[gold] == 1 else null


## 放不放得下、走不走得到（空字串 = 可以）：離保險箱、信封、牛仔出生點至少 CLEAR；不在建築、石頭、樹裡；不在場外
func why_not(q: Vector3) -> String:
	var p := Vector2(q.x, q.z)
	var near := func(o: Vector3) -> bool: return p.distance_to(Vector2(o.x, o.z)) < CLEAR
	if main.safe.on and near.call(main.safe.global_position):
		return "離保險箱太近，不能放小恐龍"
	if main.party and main.party.env_pos.any(near):
		return "離信封太近，不能放小恐龍"
	if main.spawn_points.any(near):
		return "離牛仔出生點太近，不能放小恐龍"
	if not main._is_clear(p, 0.6) or not main.map._inside(q, 3.0):
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
	var changed := false
	for i in spots.size():
		if alive[i] == 0:
			continue
		_cd[i] -= dt
		var who: Node3D = null
		if i == gold:   # 金色：不看人，時間到就叫
			if _cd[i] <= 0.0:
				_cd[i] = GOLD_CALL
				_scream.rpc(i)
		else:
			for c: Node3D in cows:
				if can_see(i, c):
					who = c
					break
		_stare[i] = _stare[i] + dt if who else 0.0
		if _stare[i] >= STARE and _cd[i] <= 0.0:
			_stare[i] = 0.0
			_cd[i] = COOLDOWN
			_wait[i] = PAUSE   # 叫完站一下再走
			_scream.rpc(i)
			var b: Node = main._boss()
			if b and b.pilot == 0:   # 電腦尼諾拉：跑過去看
				b.alarm(spots[i])
		elif who and _cd[i] <= 0.0:   # 盯著：停下來、面向牛仔（轉超過 10 度才送）
			var d := who.global_position - spots[i]
			var y := atan2(-d.x, -d.z)
			if goals[i] != spots[i] or absf(angle_difference(yaws[i], y)) > 0.17:
				goals[i] = spots[i]
				yaws[i] = y
				changed = true
		elif goals[i] == spots[i]:   # 站著：停夠了就換一點
			_wait[i] -= dt
			if _wait[i] <= 0.0:
				var t := _pick(i)   # 抽不到就下次再抽
				if t != spots[i]:
					_wait[i] = PAUSE * randf_range(0.5, 1.5)
					goals[i] = t
					yaws[i] = atan2(spots[i].x - t.x, spots[i].z - t.z)
					changed = true
		elif not _ray_clear(spots[i], spots[i] + (goals[i] - spots[i]).normalized() * 1.2, i):   # 走著：前面被擋（倒下的積木、人）就停，下次換一點
			goals[i] = spots[i]
			_wait[i] = 0.0
			changed = true
	if changed:
		_send()


## 主機：第 i 隻下一段要走去的點：目前位置 LEG×0.4～LEG 公尺外隨機抽，路上不進禁止範圍、不出場、沒有東西擋。抽不到就原地（回傳 spots[i]）
func _pick(i: int) -> Vector3:
	var a := spots[i]
	for tries in 8:
		var t: Vector3 = main._on_ground((a + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(LEG * 0.4, LEG)) * Vector3(1, 0, 1))
		var n := ceili(a.distance_to(t) / 0.5)   # ponytail: 每半公尺抽查一點，轉角可能擦過幾公分
		if range(1, n + 1).all(func(k: int) -> bool: return why_not(a.lerp(t, float(k) / n)) == "") and _ray_clear(a, t, i):
			return t
	return a


## 從 a 到 b（地面）膝蓋高的地方有沒有東西擋（第 i 隻自己不算）。
## 每 RAY_STEP 公尺一段、每段兩頭貼地：一條直線拉過起伏的地形會打到中間隆起的坡，山坡上就一直抽不到點、卡著不走
func _ray_clear(a: Vector3, b: Vector3, i: int) -> bool:
	var space := get_world_3d().direct_space_state
	var me := [(get_child(i) as CollisionObject3D).get_rid()]
	var n := maxi(ceili(a.distance_to(b) / RAY_STEP), 1)
	var from := a
	for k in range(1, n + 1):
		var to: Vector3 = b if k == n else main._on_ground(a.lerp(b, float(k) / n) * Vector3(1, 0, 1))
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * KNEE, to + Vector3.UP * KNEE, 1, me)).is_empty():
			return false
		from = to
	return true


## 每台每個物理幀：往目標點走（照地形貼地）、身體慢慢轉到 yaws、走路時上下晃
func _physics_process(delta: float) -> void:
	for i in mini(spots.size(), get_child_count()):
		if alive[i] == 0:
			continue
		var to := (goals[i] - spots[i]) * Vector3(1, 0, 1)
		var walking := goals[i] != spots[i]
		if walking:
			spots[i] = goals[i] if to.length() <= SPEED * delta else main._on_ground((spots[i] + to.normalized() * SPEED * delta) * Vector3(1, 0, 1))
		var r := get_child(i) as Raptor
		r.global_position = spots[i]
		r.rotation.y = lerp_angle(r.rotation.y, yaws[i], minf(1.0, delta * 8.0))
		r.model.position.y = absf(sin(Time.get_ticks_msec() * 0.012)) * 0.12 if walking else 0.0   # ponytail: 沒跑骨架動畫，走路只上下晃


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
	if i == gold:   # 金色：低一點、傳很遠，大家都跳一行字
		_play(i, 0.8, 60.0)
		if main.party:
			main.status.text = "金色小恐龍在叫！打死牠拿星星"
		return
	marks[i] = Time.get_ticks_msec() + int(MARK * 1000.0)
	_play(i, 1.7, 15.0)
	var p: Party = main.party
	if p and multiplayer.multiplayer_peer != null and p.dino_id == multiplayer.get_unique_id():
		main.status.text = "小恐龍在叫！"


func _play(i: int, pitch: float, unit: float) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = SCREAM
	s.pitch_scale = pitch
	s.unit_size = unit
	s.max_db = 4.0
	get_child(i).add_child(s)
	s.position.y = EYE
	s.play()
	s.finished.connect(s.queue_free)


## 尼諾拉的方位條：正在標的小恐龍位置
func marked() -> Array:
	var now := Time.get_ticks_msec()
	var out := []
	for i: int in marks:
		if int(marks[i]) > now and i < alive.size() and alive[i] == 1:
			out.append(spots[i])
	return out


## 主機：第 i 隻挨打（Raptor.take_damage）。尼諾拉打的不算（金色的算）
func hurt(i: int, amount: int, source: Node) -> void:
	if not multiplayer.is_server() or i < 0 or i >= alive.size() or alive[i] == 0 or amount <= 0:
		return
	if i != gold and is_instance_valid(source) and source.is_in_group(&"dino"):
		return
	_hp[i] -= amount
	if _hp[i] <= 0:
		kill(i)


## 主機：爆炸（Explosive.damage）範圍裡的都死；金色的照距離扣血（中心 dmg、邊緣 0）。ponytail: 不看有沒有擋住（同爆炸桶的 blast）
func blast(at: Vector3, radius: float, dmg := 0) -> void:
	var hit := false
	for i in spots.size():
		var d := (spots[i] + Vector3.UP).distance_to(at)
		if alive[i] == 0 or d >= radius:
			continue
		if i == gold:
			hurt(i, int(dmg * (1.0 - d / radius)), null)
		else:
			alive[i] = 0
			hit = true
	if hit:
		_send()


func kill(i: int) -> void:
	alive[i] = 0
	_send()
	if i == gold and main.party:
		main.party.drop_star(spots[i])


func _send() -> void:
	_recv(spots, yaws, alive, goals, gold)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_recv.rpc(spots, yaws, alive, goals, gold)


## 主機：晚進來的人補送一次（現在的位置和要去的點：接著自己走，跟主機一樣）
func send_to(id: int) -> void:
	_recv.rpc_id(id, spots, yaws, alive, goals, gold)


@rpc("authority", "call_remote", "reliable")
func _recv(pts: PackedVector3Array, ys: PackedFloat32Array, a: PackedByteArray, gs: PackedVector3Array, g := -1) -> void:
	gold = g
	spots = pts.duplicate()
	goals = gs.duplicate()
	yaws = ys.duplicate()
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
	r.max_hp = GOLD_HP if i == gold else HP
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
	mat.albedo_color = GOLD_COLOR if i == gold else COLOR
	mat.roughness = 0.35 if i == gold else 0.9
	mat.metallic = 0.8 if i == gold else 0.0
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	r.add_child(m)
	r.model = m
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
	var model: Node3D

	## 子彈、槍托（主機，Cowboy.deal_damage／main.request_damage）
	func take_damage(amount: int, source: Node = null) -> void:
		raptors.hurt(index, amount, source)
