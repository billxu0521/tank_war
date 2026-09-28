class_name Fighter
extends CharacterBody3D
## 牛仔和恐龍共用的部分：血量、死亡、多人連線權限。
##
## 數值是照 3 個牛仔抓的（佔位版，玩法定了再調）：
##   恐龍咬死一個牛仔 = 2 口（150 血、一口 100）——被咬到一口就該跑
##   3 個牛仔打死恐龍 ≈ 1500 / (3 × 37) = 13.5 秒
##     37 是手槍的持續輸出：12 發 × 25 傷，打完 2.6 秒＋逐發換彈 5.4 秒
##     雙管貼臉更痛（持續約 128/秒），代價是要站進恐龍咬得到的距離
## 場上有建築擋視線，牛仔可以繞柱子拉開距離，恐龍得選好進攻角度。
## ponytail: 數值寫死不隨人數變。2 人或 5 人會偏掉，真的要再說。

signal died(killer: Node)

const GRAVITY := 25.0
const LOOK_SETTLE_MS := 1500  # 滑鼠鎖定後先忽略這麼久的位移

@export var max_hp := 100
## true = 電腦操控。不讀鍵盤，自己照優先序決策。
## 離線練習模式用這個。
@export var bot := false

var hp := 0
var hit_until := 0  # 自己的彈打中人，準心閃紅到這個時刻（毫秒）
var _last_hit_by: Node = null  # 只有主機需要，用來記誰殺了誰
var _was_captured := false
var _settle_until := 0


## 電腦（移動標靶、bot）用負數編號，由主機操控。
## 玩家的連線編號一定是正數（主機 1，其他人是很大的亂數，實測 251338328），負數保證不會撞。
## 不能用「1000 以上」：加入的人編號都比 1000 大，會被當成電腦、自己操控不了
static func is_bot_id(id: int) -> bool:
	return id < 0

func _enter_tree() -> void:
	# 節點名字就是玩家的連線編號，誰的節點誰操控。電腦由主機操控——
	# 不然 authority 是一個不存在的連線，同步器不送位置，其他人看到它站著不動
	var id := name.to_int()
	set_multiplayer_authority(1 if is_bot_id(id) else id)

func _ready() -> void:
	hp = max_hp

## 自己射出去的彈打中有血的東西時呼叫。純本機回饋，不走網路。
func on_hit() -> void:
	hit_until = Time.get_ticks_msec() + 350

## 只有主機會呼叫這個。source 是誰打的，用來記錄擊殺者。
func take_damage(amount: int, source: Node = null) -> void:
	if hp <= 0:
		return
	_last_hit_by = source
	_sync_hp.rpc(hp - amount)

# ponytail: 主機算完傷害直接廣播結果，不驗證來源。原型不防作弊，要防再改成主機權威輸入。
@rpc("any_peer", "call_local", "reliable")
func _sync_hp(v: int) -> void:
	if v < hp:
		_flash_red()
	hp = v
	if hp <= 0:
		died.emit(_last_hit_by)
		if multiplayer.is_server():
			queue_free()  # MultiplayerSpawner 會同步移除其他人畫面上的它

## 取滑鼠這一幀轉了多少。
## 滑鼠一被鎖定，macOS 會噴出一串「游標歸位」的殘留位移（實測從鎖定後 780ms 開始、
## 衰減到 1200ms 才停），不擋掉的話砲塔一進遊戲就自己甩到隨機角度。
## ponytail: 直接用固定時間窗擋掉，夠簡單也夠用。如果哪天在別的機器上還是會甩，
## 就把 LOOK_SETTLE_MS 調大，或改成「等到位移出現一段空檔才開始吃輸入」。
func mouse_look(e: InputEvent) -> Vector2:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured != _was_captured:
		_was_captured = captured
		_settle_until = Time.get_ticks_msec() + LOOK_SETTLE_MS
	if not captured or not is_multiplayer_authority() or not (e is InputEventMouseMotion):
		return Vector2.ZERO
	if Time.get_ticks_msec() < _settle_until:
		return Vector2.ZERO
	return e.relative

## 水平速度用加速度逼近目標，不要瞬間到頂也不要瞬間停住。
## 煞車通常比加速快，放開按鍵才不會像在冰上滑。
func _accelerate(want: Vector3, accel: float, brake: float, delta: float) -> void:
	var rate := accel if want.length_squared() > 0.01 else brake
	velocity.x = move_toward(velocity.x, want.x, rate * delta)
	velocity.z = move_toward(velocity.z, want.z, rate * delta)

func _apply_gravity(delta: float) -> void:
	# 只在往下掉的時候貼地，不然會把跳躍的向上速度也清掉
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


## 中彈閃一下紅。用 material_overlay 蓋在原本材質上，
## 每次都新建材質，才不會跟別台共用的材質互相干擾。
func _flash_red() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.2, 0.15, 0.5)
	var meshes := find_children("*", "MeshInstance3D")
	for mi: MeshInstance3D in meshes:
		mi.material_overlay = mat
	var t := create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	t.tween_callback(func() -> void:
		for mi: MeshInstance3D in meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null)
