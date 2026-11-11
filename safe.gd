class_name Safe
extends StaticBody3D
## 保險箱（docs/企劃/2026-11-12-保險箱與號碼牌.md）：派對模式把蛋鎖在裡面，牛仔看著按 F 開密碼面板（safe_panel.gd）。
## 主機說了算：密碼只在主機（_code，不進同步器、不進 party 那包）。試開請求送主機，主機等 TRY_SECONDS 再公布。
## 位置走 main.tscn 的同步器（跟蛋一樣）；公開狀態（開了沒、試過的表、誰在試）放 party._sync 那包（state / set_state）。
## 規則每幀由 party.step 推（server_step），不是派對模式 on = false，整個藏起來、沒有碰撞。
##
## ponytail: 現在是 StaticBody3D、不會動。第 4 步要物理就換成 RigidBody3D（主機算、客戶端 freeze），同步器加 rotation；
## 其他程式只碰 global_position，不用改

static var TRY_SECONDS: float = Balance.num("safe_try_seconds")
const RANGE := 3.0      # 牛仔離箱子多遠（水平）還能試；試到一半走出去這次作廢
const HALF := 0.5       # 箱子半邊長
const PARK := Vector3(0, -100, 0)   # 還沒放的時候收在地底

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
	global_position = PARK
	_apply()


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
		main.egg.global_position = global_position + Vector3.UP * (HALF + 0.3)   # 蛋放到箱頂，照舊撿
		main.egg.reset_physics_interpolation()
	busy = 0
	main.party._sync()


func _near(id: int) -> bool:
	var c := main.players.get_node_or_null(NodePath(str(id))) as Cowboy
	return c != null and c.hp > 0 and not c.is_queued_for_deletion() \
		and Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length() < RANGE
