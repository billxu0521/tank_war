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

# --- 別人的角色：平滑顯示 ---
# 同步器只同步 net_state = [送出時的時間, 位置, 朝向]。收到的先存起來，畫面刻意晚 NET_DELAY 毫秒，
# 在前後兩筆之間補（跟 FPS 遊戲的「插值」同一招）：網路一時慢了、一次來兩包，看起來還是順的。
# 只有客戶端這樣做。主機（含測試站）收到就直接套：恐龍咬人、boss 找人都在主機算，不能看慢了的位置。
# 客戶端自己判定打中（Bullet），打的就是畫面上看到的位置，所以「看到哪、打哪」還是對得上。
# 晚越多越順但越不準（躲到牆後還中彈）：同步器每秒送 40 次（cowboy.tscn、boss.tscn 的 replication_interval），
# 晚 60ms 等於手上隨時有兩三筆可以補，晚一包也不會停住
const NET_DELAY := 60.0
const NET_KEEP := 1000.0   # 存最近這麼多毫秒
var net_smooth := false     # _ready 決定；測試會直接打開
var _snaps: Array = []      # [送出時間, 收到時間, 位置, 朝向]，照時間排
var net_state: Array:
	get:
		return [Time.get_ticks_msec(), position, rotation]
	set(v):
		_net_push(v)


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
	# 物理插值（project.godot 開著）：畫面在前後兩個物理步之間補，高刷新率螢幕才不會一頓一頓。
	# 生出來之後呼叫的人才擺位置，等這一幀結束再重設，不然第一幀會從原點滑過去
	reset_physics_interpolation.call_deferred()
	net_smooth = not is_multiplayer_authority() and not multiplayer.is_server()
	if net_smooth:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # 自己每幀補，不再經過物理插值


func _net_push(v: Array) -> void:
	if not net_smooth:
		position = v[1]   # 主機、還沒進場景（生出來那一包）：直接套
		rotation = v[2]
		return
	var now := float(Time.get_ticks_msec())
	_snaps.append([float(v[0]), now, v[1], v[2]])
	while _snaps.size() > 2 and _snaps[0][1] < now - NET_KEEP:
		_snaps.pop_front()


## 照畫面時間在兩筆之間補。對方的時鐘跟我們不一樣：用「收到 - 送出」最小的那筆當兩邊的時差
## （最快到的那包最接近真正的時差），再往回退 NET_DELAY
func net_step(now: float) -> void:
	if _snaps.is_empty():
		return
	var off := INF
	for s: Array in _snaps:
		off = minf(off, s[1] - s[0])
	var t := now - off - NET_DELAY
	var last: Array = _snaps[-1]
	if t >= last[0]:   # 新的還沒到：停在最後一筆，不亂猜
		position = last[2]
		rotation = last[3]
		return
	for i in range(_snaps.size() - 1, 0, -1):
		var a: Array = _snaps[i - 1]
		if a[0] <= t:
			var b: Array = _snaps[i]
			var k := clampf((t - a[0]) / maxf(b[0] - a[0], 0.001), 0.0, 1.0)
			position = (a[2] as Vector3).lerp(b[2], k)
			rotation = Quaternion.from_euler(a[3]).slerp(Quaternion.from_euler(b[3]), k).get_euler()
			return
	position = _snaps[0][2]
	rotation = _snaps[0][3]


func _notification(what: int) -> void:
	# 牛仔、恐龍各有自己的 _process；這裡用通知，子類別不用記得呼叫
	if what == NOTIFICATION_PROCESS and net_smooth:
		net_step(float(Time.get_ticks_msec()))

## 自己射出去的彈打中有血的東西時呼叫。純本機回饋，不走網路。
func on_hit() -> void:
	hit_until = Time.get_ticks_msec() + 350

## 只有主機會呼叫這個。source 是誰打的，用來記錄擊殺者。
func take_damage(amount: int, source: Node = null) -> void:
	if hp <= 0:
		return
	# 選單關掉恐龍攻擊時，恐龍（含 boss、火球）打人不扣血。傷害都在主機算，只看主機的開關就好
	if is_instance_valid(source) and source.is_in_group(&"dino"):
		var g := get_tree().get_first_node_in_group(&"match")
		if g and not g.dino_attacks:
			return
	_last_hit_by = source
	_sync_hp.rpc(hp - amount)

## 血量只有主機能改。annotation 寫 any_peer 是因為牛仔節點的 authority 是玩家本人（他自己控制移動），
## 寫 authority 的話主機反而發不出來；所以收到時自己檢查是不是主機（編號 1）送的
@rpc("any_peer", "call_local", "reliable")
func _sync_hp(v: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
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
