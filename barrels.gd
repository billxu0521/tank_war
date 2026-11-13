class_name Barrels
extends Node3D
## 爆炸桶（docs/企劃/設計討論.md 2026-11-10 第一則第 3 項：隨機位置的場景物件，先加爆炸桶）。
## 主機每局（派對每回合）在隨機的空地擺 COUNT 個紅桶；打一槍就爆，爆炸走炸藥同一條路（Explosive）：
## 範圍傷害不分敵我、炸飛保險箱、拆積木、引來恐龍，炸到別的桶會連環爆。
## 主機說了算：位置和「爆了沒」由主機送（_recv），晚進來的人在 main._spawn 補送（send_to）。
## 子彈每台都會飛、都會打到桶，但只有主機那份算數（shot）。

static var COUNT: int = Balance.whole("barrel_count")   # 測試會改成 0（舊案例不要被亂擺的桶干擾）
static var RADIUS: float = Balance.num("barrel_blast_radius")
static var DAMAGE: int = Balance.whole("barrel_blast_damage")
const SIZE := Vector3(0.7, 0.93, 0.7)   # 同 kits.glb 的木桶（arena_map.gd 的 KIT_SIZE）
const APART := 15.0          # 桶跟桶至少相距（抽不到就放寬）
const FROM_CENTER := 12.0    # 離恐龍出生點（保險箱、蛋大概在那附近）
const FROM_SPOT := 5.0       # 離出生點、信封、蛋
static var CHAIN_DELAY := 0.15   # 連環爆：被炸到的桶隔一下才爆，看得出一個接一個（測試設 0：當場爆完）

var spots := PackedVector3Array()   # 每個桶的位置（地面）
var alive := PackedByteArray()      # 1 = 還在
var _gen := 0                       # 主機：第幾次擺；連環爆等到一半換了一批就作廢

@onready var main: Node = get_parent()


## 主機：重抽位置（新的一局、派對的每回合）。練習場叫 clear
func roll() -> void:
	var pts := PackedVector3Array()
	var apart := APART
	for tries in 400:
		if pts.size() >= COUNT:
			break
		if tries % 100 == 99:
			apart *= 0.7
		var q: Vector3 = main._spawn_point()
		q = main._on_ground(Vector3(q.x, 0, q.z))
		if _ok(q, pts, apart):
			pts.append(q)
	_set_all(pts)


func clear() -> void:
	_set_all(PackedVector3Array())


func _set_all(pts: PackedVector3Array) -> void:
	_gen += 1
	var a := PackedByteArray()
	a.resize(pts.size())
	a.fill(1)
	_recv(pts, a)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_recv.rpc(pts, a)


## 合格的空地：不在建築、石頭、樹裡，不在撤離圈、靶場，離中央、出生點、信封、蛋、別的桶夠遠
func _ok(q: Vector3, pts: PackedVector3Array, apart: float) -> bool:
	var p := Vector2(q.x, q.z)
	if not main._is_clear(p, 1.5) or main.map._near_level(p, 1.0) or not main.map._free(q, 1.0):
		return false
	var far := func(o: Vector3, d: float) -> bool: return p.distance_to(Vector2(o.x, o.z)) >= d
	if not far.call(main.dino_spawn, FROM_CENTER) or not far.call(main.egg.global_position, FROM_SPOT):
		return false
	if not main._exits.all(func(x: Vector3) -> bool: return far.call(x, main.EXIT_RADIUS + 3.0)):
		return false
	var others: Array = main.spawn_points.duplicate()
	if main.party:
		others.append_array(main.party.env_pos)
	if not others.all(func(o: Vector3) -> bool: return far.call(o, FROM_SPOT)):
		return false
	return Array(pts).all(func(o: Vector3) -> bool: return far.call(o, apart))


## 主機：晚進來的人補送一次
func send_to(id: int) -> void:
	_recv.rpc_id(id, spots, alive)


@rpc("authority", "call_remote", "reliable")
func _recv(pts: PackedVector3Array, a: PackedByteArray) -> void:
	spots = pts
	alive = a
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var mesh: Mesh = main.map._props.get(&"Barrel")
	if mesh == null:   # ponytail: 模型沒載到（沒匯入的環境）用圓柱
		var cyl := CylinderMesh.new()
		cyl.top_radius = SIZE.x * 0.5
		cyl.bottom_radius = SIZE.x * 0.5
		cyl.height = SIZE.y
		mesh = cyl
	var red := StandardMaterial3D.new()   # ponytail: 木桶模型整個塗紅當爆炸桶，正式模型之後再做
	red.albedo_color = Color(0.62, 0.12, 0.08)
	red.roughness = 0.8
	for i in spots.size():
		var b := Barrel.new()
		b.name = "B%d" % i
		b.index = i
		b.barrels = self
		var shape := CollisionShape3D.new()
		var s := CylinderShape3D.new()   # 圓的：bot、尼諾拉撞到會滑開，不會卡在角上
		s.radius = SIZE.x * 0.5
		s.height = SIZE.y
		shape.shape = s
		shape.position.y = SIZE.y * 0.5
		b.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = red
		if mesh is CylinderMesh:
			mi.position.y = SIZE.y * 0.5
		b.add_child(mi)
		b.add_to_group(&"iron")   # 鐵桶：子彈打不穿、打到噴石屑（bullet.gd）
		add_child(b)
		b.global_position = spots[i]
		b.rotation.y = float(i) * 1.7
		_show(i)


func _show(i: int) -> void:
	var b := get_child(i) as StaticBody3D
	var on := alive[i] == 1
	b.visible = on
	b.collision_layer = 1 if on else 0


func count_alive() -> int:
	return Array(alive).count(1)


## 子彈打到第 i 個桶（每台都會叫）：只有主機算數
func shot(i: int, shooter: Node) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		explode(i, shooter)


## 主機：範圍 radius 內的桶連環爆（Explosive.damage 叫）
func blast(at: Vector3, radius: float, shooter: Node) -> void:
	for i in spots.size():
		if alive[i] == 1 and spots[i].distance_to(at) < radius:
			explode(i, shooter, CHAIN_DELAY)


## 主機：第 i 個桶爆炸。先記成爆了（同一個不會爆兩次），delay 秒後才真的炸
func explode(i: int, shooter: Node, delay := 0.0) -> void:
	if i < 0 or i >= alive.size() or alive[i] == 0:
		return
	alive[i] = 0
	var gen := _gen
	if delay > 0.0:
		await get_tree().create_timer(delay, false, true).timeout
		if gen != _gen:
			return
	_boom.rpc(i)
	var who: Node = shooter if is_instance_valid(shooter) else null
	Explosive.damage(main.map, spots[i], RADIUS, DAMAGE, who)
	ToyBuild.blast(main.map, spots[i], RADIUS)
	get_tree().call_group(&"boss", &"hear", spots[i])


## 每台：藏起來、播爆炸
@rpc("authority", "call_local", "reliable")
func _boom(i: int) -> void:
	if i < 0 or i >= alive.size():
		return
	alive[i] = 0
	_show(i)
	Explosive.play(main.map, spots[i], RADIUS)


class Barrel extends StaticBody3D:
	var index := 0
	var barrels: Barrels

	## 子彈打到（bullet.gd，每台都會叫）
	func on_shot(_at: Vector3, shooter: Node, _dir := Vector3.ZERO) -> void:
		barrels.shot(index, shooter)
