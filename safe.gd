class_name Safe
extends RigidBody3D
## 保險箱（docs/企劃/2026-11-12-保險箱與號碼牌.md）：派對模式把蛋鎖在裡面，牛仔看著按 F 開密碼面板（safe_panel.gd）。
## 主機說了算：密碼只在主機（_code，不進同步器、不進 party 那包）。試開請求送主機，主機等 TRY_SECONDS 再公布。
## 位置走 main.tscn 的同步器（跟蛋一樣）；公開狀態（開了沒、試過的表、誰在試）放 party._sync 那包（state / set_state）。
## 規則每幀由 party.step 推（server_step），不是派對模式 on = false，整個藏起來、沒有碰撞。
##
## 物理（第 4 步）：只有主機算，客戶端 freeze、照同步器的位置和角度擺（跟蛋一樣）。不能撿：炸藥炸得飛（blast）、
## 尼諾拉甩尾掃得飛（push，boss._strike_sweep），走路跑步推不動：角色移動對物理物體是無限大的質量，再重都推得走，
## 所以主機上停下來就凍住（當牆），被炸、被甩、底下空了才解凍。掉出場外、掉到地下、被積木埋住，主機搬回地面（_rescue）。
## 滾進撤離圈不算撤離：撤離看的是拿著蛋的人（蛋鎖著撿不到）

static var TRY_SECONDS: float = Balance.num("safe_try_seconds")
const RANGE := 3.0      # 牛仔離箱子多遠（水平）還能試；試到一半走出去這次作廢
const HALF := 0.5       # 箱子半邊長
const PARK := Vector3(0, -100, 0)   # 還沒放的時候收在地底
static var MASS: float = Balance.num("safe_mass")
static var BLAST_SPEED: float = Balance.num("safe_blast_speed")
static var SWEEP_SPEED: float = Balance.num("safe_sweep_speed")
const UNBURY_STEP := 0.25   # 被積木埋住每次往上抬多少（同 egg.gd）
const UNBURY_MAX := 40
const EDGE := 6.0           # 救回時離場地邊緣至少這麼遠
const REST_SPEED := 0.2     # 比這慢（公尺／秒、弧度／秒）待滿 REST_TIME 就凍住
const REST_TIME := 0.5
var _placed := false        # 主機：這回合放下去了（還收在地底就不算物理）
var _rest := 0.0

var on := false         # 這回合有沒有保險箱
var open := false
var tried := PackedByteArray()   # 100 格：組合 n（十位 n/10、個位 n%10）試過了就是 1
var busy := 0           # 正在試的牛仔編號，0 = 沒人

var _code := -1         # 只在主機：這回合的密碼 00～99
var _try := -1          # 主機：正在試的組合
var _try_left := 0.0
var _door: MeshInstance3D

@onready var main: Node = get_parent()

## 看著箱子時畫面上的提示（cowboy.gd 讀這個）
var prompt: String:
	get:
		if open:
			return "保險箱（開了）"
		return "保險箱（有人在試）" if busy != 0 else "輸入密碼"


func _ready() -> void:
	var body := MeshInstance3D.new()   # ponytail: 方塊當外觀，正式模型第 5 步再換
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * HALF * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.26)
	bm.material = mat
	body.mesh = bm
	add_child(body)
	_door = MeshInstance3D.new()   # 前面那片門：開了就藏起來
	var dm := BoxMesh.new()
	dm.size = Vector3(HALF * 1.6, HALF * 1.6, 0.06)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.55, 0.5, 0.35)
	dm.material = dmat
	_door.mesh = dm
	_door.position = Vector3(0, 0, HALF + 0.03)
	add_child(_door)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	shape.shape = bs
	add_child(shape)
	mass = MASS
	continuous_cd = true   # 炸飛的速度快，不要穿過地形
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	Accent.mark(self)
	reset(false)


func locked() -> bool:
	return on and not open


## 主機：新回合重抽密碼、清表。active = false 就整個收掉（每台都可以叫，客戶端 _code 不會用到）
func reset(active: bool) -> void:
	on = active
	open = false
	tried = PackedByteArray()
	tried.resize(100)
	busy = 0
	_try = -1
	_code = randi() % 100 if active and multiplayer.is_server() else -1
	freeze = true
	_placed = false
	global_position = PARK
	_apply()


## 主機：放在 at（已經貼地）。擺正、速度清掉，開始算物理
func place(at: Vector3) -> void:
	freeze = true
	global_transform = Transform3D(Basis(), at)
	_placed = true
	if multiplayer.is_server():   # 主機先解凍：落地站穩再凍住
		_wake()
	reset_physics_interpolation()


## 主機：解凍、叫醒、速度清掉（凍著的時候設速度沒用，要解凍之後設）
func _wake() -> void:
	freeze = false
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_rest = 0.0


## 主機：給一個速度變化（公尺／秒，跟質量無關）。施力點在中心上方一點，會翻滾
func push(v: Vector3) -> void:
	if not on or not _placed or not multiplayer.is_server():
		return
	if freeze:
		_wake()
	sleeping = false
	apply_impulse(v * mass, Vector3.UP * HALF * 0.5)


## 主機：爆炸（Explosive.damage）。範圍內往外推，照距離線性遞減，帶一點往上
func blast(at: Vector3, radius: float) -> void:
	var to := global_position - at
	var k := 1.0 - to.length() / radius
	if k > 0.0:
		push((to.normalized() + Vector3.UP * 0.5).normalized() * BLAST_SPEED * k)


## 公開的狀態（party._sync 送給大家）。密碼不在裡面
func state() -> Dictionary:
	return {on = on, open = open, tried = tried, busy = busy}


func set_state(s: Dictionary) -> void:
	on = s.on
	open = s.open
	tried = s.tried
	busy = s.busy
	_apply()


func _apply() -> void:
	collision_layer = (1 | Fighter.SOLID_LAYER) if on else 0
	_door.visible = not open
	if not on:
		visible = false


func interact(who: Node) -> void:
	if locked() and who == main._me():
		main._safe_panel.open_panel()


## 面板按「試開」：客戶端送到主機
@rpc("any_peer", "call_remote", "reliable")
func request_try(n: int) -> void:
	if not multiplayer.is_server():
		request_try.rpc_id(1, n)
		return
	var from := multiplayer.get_remote_sender_id()
	try_code(from if from != 0 else multiplayer.get_unique_id(), n)


## 主機：id 這個牛仔試組合 n。全部重新檢查（遊戲中、箱子關著、沒人在試、活著的牛仔、不是恐龍、夠近）。
## 電腦牛仔（第 3 步）直接叫這個
func try_code(id: int, n: int) -> bool:
	var p: Node = main.party
	if not locked() or busy != 0 or n < 0 or n > 99 or p == null or p.phase != &"play" or id == p.dino_id or not _near(id):
		return false
	busy = id
	_try = n
	_try_left = TRY_SECONDS
	p._sync()
	return true


## 主機每個物理幀（party.step 的遊戲階段）：試的人死了、走開，這次作廢不記；滿 1 秒公布
func server_step(delta: float) -> void:
	if busy == 0:
		return
	if not _near(busy):
		busy = 0
		main.party._sync()
		return
	_try_left -= delta
	if _try_left > 0.0:
		return
	tried[_try] = 1
	if _try == _code:
		open = true
		_apply()
		main.egg.global_position = _top()   # 蛋放到箱頂，照舊撿
		main.egg.reset_physics_interpolation()
	busy = 0
	main.party._sync()


## 主機每個物理幀（準備階段也算：放好之後恐龍就甩得到）：先看要不要救回；凍著就看底下空了沒（積木被拆掉）；動著停下來就凍住
func _physics_process(delta: float) -> void:
	if not _placed or not on or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_rescue()
	if open and main.egg.carrier == 0 and not freeze and main.egg.global_position.distance_to(_top()) < 1.5:
		main.egg.global_position = _top()   # 開了、蛋還在箱頂：箱子被炸走蛋跟著，不會懸在半空撿不到
	if freeze:
		# 底下空了（積木被拆掉）就解凍。用往下的射線：test_move 碰到旁邊的牆也算碰到
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (HALF * 1.8 + 0.1))
		ray.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			_wake()
		return
	var slow := linear_velocity.length() < REST_SPEED and angular_velocity.length() < REST_SPEED
	_rest = _rest + delta if slow else 0.0
	if _rest >= REST_TIME:
		freeze = true


## 主機：出場外、掉到地面以下、被積木埋住 → 搬回最近的地面。卡在屋頂上不管（爬得上去就算）
func _rescue() -> void:
	var p := global_position
	var edge: float = main.ARENA * 0.5   # 圍牆那條線：出了這裡才算場外，搬回離邊 EDGE 公尺
	var half := edge - EDGE
	var ground: float = main._on_ground(Vector3(p.x, 0, p.z)).y
	if absf(p.x) > edge or absf(p.z) > edge or p.y < ground - HALF:
		place(main._on_ground(Vector3(clampf(p.x, -half, half), HALF, clampf(p.z, -half, half))))
		return
	var q := PhysicsPointQueryParameters3D.new()
	var space := get_world_3d().direct_space_state
	for i in UNBURY_MAX:
		q.position = global_position
		var buried := space.intersect_point(q, 8).any(func(r: Dictionary) -> bool:
			return r.collider is ToyBuild or (r.collider as Node).is_in_group(&"toy_piece"))
		if not buried:
			return
		global_position.y += UNBURY_STEP
		_wake()


func _top() -> Vector3:
	return global_position + Vector3.UP * (HALF + 0.3)


func _near(id: int) -> bool:
	var c := main.players.get_node_or_null(NodePath(str(id))) as Cowboy
	return c != null and c.hp > 0 and not c.is_queued_for_deletion() \
		and Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length() < RANGE
