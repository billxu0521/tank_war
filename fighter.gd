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
const HITCH_MS := 250   # 兩幀之間隔超過這麼久算卡頓（4 fps 以下）；見 after_hitch
# 第 5 層（值 16）：地形、場地圍牆、牛仔和恐龍的身體都在這層，同時仍在第 1 層（所以舊的遮罩照樣全看得到）。
# 尼諾拉關掉「碰撞物件」時遮罩只留這層：房子、樹、柵欄（只在第 1 層）穿過去，站地形、撞牛仔照舊（boss.gd 的 _sync_mask）
const SOLID_LAYER := 16

@export var max_hp := 100
## true = 電腦操控。不讀鍵盤，自己照優先序決策。
## 離線練習模式用這個。
@export var bot := false

var hp := 0
# 燃燒：被火球打中就燒一陣子，每秒扣一次，再中一次重設時間（不疊加）。只有主機算。以下從 balance.csv 讀
static var BURN_DPS: int = Balance.whole("burn_dps")
static var BURN_SECONDS: float = Balance.num("burn_seconds")
var burn_left := 0.0       # 還剩幾秒會燒
var _burn_acc := 0.0       # 距離下一次扣血，累積了幾秒
var _burn_src: Node = null # 放火的人，扣血算他的
var hit_until := 0  # 自己的彈打中人，準心閃紅到這個時刻（毫秒）
var _last_hit_by: Node = null  # 只有主機需要，用來記誰殺了誰
var last_from := Vector3.INF   # 最後一下從哪裡打來（每台都有）：屍體往反方向倒
static var diag := {}       # 診斷（暫時，滑鼠視角卡住的 bug 修好就拿掉）：滑鼠事件走到哪一步，main.gd 每半秒印一次
static var _frame_ms := 0   # 上一幀跑完的時刻（毫秒），main.gd 每幀寫

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
	collision_layer |= SOLID_LAYER
	# 物理插值（project.godot 開著）：畫面在前後兩個物理步之間補，高刷新率螢幕才不會一頓一頓。
	# 生出來之後呼叫的人才擺位置，等這一幀結束再重設，不然第一幀會從原點滑過去
	reset_physics_interpolation.call_deferred()
	net_smooth = not is_multiplayer_authority() and not multiplayer.is_server()
	if net_smooth:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # 自己每幀補，不再經過物理插值


func _net_push(v: Array) -> void:
	if not net_smooth:
		# 主機收別人的位置：先查移動額度，不合理就不套、請本人拉回。電腦和主機自己的不用查
		if is_inside_tree() and multiplayer.is_server() and not is_multiplayer_authority() \
				and not net_accept(v[1], float(Time.get_ticks_msec())):
			return
		position = v[1]   # 主機、還沒進場景（生出來那一包）：直接套
		rotation = v[2]
		return
	var now := float(Time.get_ticks_msec())
	_snaps.append([float(v[0]), now, v[1], v[2]])
	while _snaps.size() > 2 and _snaps[0][1] < now - NET_KEEP:
		_snaps.pop_front()


# --- 主機檢查移動（別人的角色，主機收到位置時） ---
# 用額度做，不逐包比速度：封包會擠在一起到，一包的距離超過這一包的時間算不準。
# 每個角色一個水平額度和一個往上額度，每秒依「合法最快速度 × NET_REFILL」補，上限 NET_BURST／NET_BURST_UP 公尺；
# 每包扣掉跟上一個已接受位置的距離，額度不夠這包就不接受。時間用主機收到的時間，不信客戶端的。
const NET_BURST := 8.0           # 額度上限（公尺）：衝刺中網路卡 0.9 秒內不會被拉回；再大會讓瞬移外掛一次跳更遠
const NET_BURST_UP := 4.0        # 往上的額度上限（公尺）：跳、翻越一次用不到這麼多
const NET_REFILL := 1.5          # 補速是合法最快速度的幾倍：正常玩家差很遠，超過才是作弊
const NET_WALK_SLOPE := 0.84     # tan 40 度：地圖最陡的可走坡（main.gd 的 nav agent_max_slope）。沿坡走上去不算往上
const NET_REJECT_LOG := 20       # 5 秒內被拒這麼多次，主機印一行（先不踢人）
const NET_CORRECT_GAP := 500.0   # 拉回同一個人之後這麼久（毫秒）內不再拉，不然會洗版
# ponytail: 網路整段斷掉（約 0.9 秒以上、正在衝刺）之後第一包會被拒、拉回。有人回報再改用送出時間算間隔
var _net_anchor := Vector3.ZERO     # 上一個接受的位置（主機）
var _net_h := 0.0                   # 水平剩下的額度（公尺）
var _net_v := 0.0                   # 往上剩下的額度（公尺）
var _net_t := -1.0                  # 上次算額度的時刻（毫秒）；-1＝還沒收過，第一包直接當基準
var _net_rejects: Array = []        # 最近被拒的時刻（毫秒）
var _net_corrected := -INF          # 上次拉回的時刻（毫秒）
var _net_hist: Array = []           # 最近接受的位置 [時刻毫秒, 位置]，給 near_recent 用
const NET_HIST_MS := 1500.0         # 只往回看這麼久

## 合法的最快水平速度（公尺／秒），各角色覆寫
func net_max_speed() -> float:
	return 0.0

## 合法的最快往上速度（公尺／秒），各角色覆寫。往下不限（掉落）
func net_max_up() -> float:
	return 0.0

## 主機收到一包位置：合法就記下並回傳 true；不合法回傳 false（位置不要套）。now 是毫秒，測試可以自己給
func net_accept(p: Vector3, now: float) -> bool:
	if _net_t < 0.0:   # 第一包（剛生出來、重生、新局）：直接當基準
		_net_anchor = p
		_net_h = NET_BURST
		_net_v = NET_BURST_UP
		_net_t = now
		_net_remember(p, now)
		return true
	var dt := maxf(now - _net_t, 0.0) / 1000.0
	_net_t = now
	_net_h = minf(NET_BURST, _net_h + net_max_speed() * NET_REFILL * dt)
	_net_v = minf(NET_BURST_UP, _net_v + net_max_up() * NET_REFILL * dt)
	var dh := Vector2(p.x - _net_anchor.x, p.z - _net_anchor.z).length()
	var up := maxf(p.y - _net_anchor.y - dh * NET_WALK_SLOPE, 0.0)
	if dh > _net_h or up > _net_v:
		_net_reject(now)
		return false
	_net_h -= dh
	_net_v -= up
	_net_anchor = p
	_net_remember(p, now)
	return true

## 記下主機接受的位置（只留最近 NET_HIST_MS 毫秒）
func _net_remember(p: Vector3, now: float) -> void:
	_net_hist.append([now, p])
	while float(_net_hist[0][0]) < now - NET_HIST_MS:
		_net_hist.pop_front()

## 現在位置，或最近 1.5 秒內主機接受過的位置，有一個離 p 在 r 公尺內就 true。
## 給「開槍時的位置」用：客戶端的必達訊息可能晚到，衝刺中的人會比主機現在記的位置遠
# ponytail: 只往回看 1.5 秒；卡更久的訊息還是會被丟。電腦（沒有歷史）只比現在位置
func near_recent(p: Vector3, r: float) -> bool:
	if global_position.distance_to(p) <= r:
		return true
	for h in _net_hist:
		if (h[1] as Vector3).distance_to(p) <= r:
			return true
	return false

func _net_reject(now: float) -> void:
	_net_rejects.append(now)
	while not _net_rejects.is_empty() and now - float(_net_rejects[0]) > 5000.0:
		_net_rejects.pop_front()
	var id := name.to_int()
	# 拉回：把位置改回主機上最後一個合法的位置。電腦和測試（沒有連線的人）不用
	if multiplayer.is_server() and multiplayer.get_peers().has(id) and now - _net_corrected >= NET_CORRECT_GAP:
		_net_corrected = now
		_net_correct.rpc_id(id, _net_anchor)
	if _net_rejects.size() >= NET_REJECT_LOG:
		print("[移動檢查] 玩家 %d 5 秒內被拒 %d 次，主機上最後合法位置 %s（先不踢人）" % [id, _net_rejects.size(), str(_net_anchor)])
		_net_rejects.clear()

## 主機說你超速了：拉回主機記的合法位置（只收主機送的）。
## 本人的位置照常由自己控制；拉回只是讓之後送出的位置接得上主機的記錄
@rpc("any_peer", "call_remote", "reliable")
func _net_correct(p: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	position = p
	reset_physics_interpolation()


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
	if what == NOTIFICATION_PROCESS and burn_left > 0.0 and multiplayer.is_server():   # 沒在燒就不碰 multiplayer（沒有連線時會報錯）
		burn_step(get_process_delta_time())

## 自己射出去的彈打中有血的東西時呼叫。純本機回饋，不走網路。
func on_hit() -> void:
	hit_until = Time.get_ticks_msec() + 350

## 被火球打中（只有主機呼叫）：燒 BURN_SECONDS 秒，再中一次就重設時間
func ignite(src: Node = null) -> void:
	burn_left = BURN_SECONDS
	_burn_src = src
	_burn_notice.rpc(name.to_int())

## 燃燒每幀（主機）：累積滿一秒扣一次 BURN_DPS，算在放火的人身上。測試直接呼叫這個
func burn_step(delta: float) -> void:
	if burn_left <= 0.0:
		return
	burn_left -= delta
	_burn_acc += delta
	if _burn_acc >= 1.0:
		_burn_acc -= 1.0
		take_damage(BURN_DPS, _burn_src)
	if burn_left <= 0.0:
		_burn_acc = 0.0

## 燒起來：只有被燒的那台顯示「著火了！」（其他人畫面上的火焰以後再做）
# ponytail: 別人身上的火焰特效以後再做
@rpc("any_peer", "call_local", "reliable")
func _burn_notice(id: int) -> void:
	if multiplayer.get_remote_sender_id() != 1 or id != multiplayer.get_unique_id():
		return
	var g := get_tree().get_first_node_in_group(&"match")
	if g:
		g.status.text = "著火了！"

## 只有主機會呼叫這個。source 是誰打的，用來記錄擊殺者。
func take_damage(amount: int, source: Node = null) -> void:
	if hp <= 0:
		return
	var g := get_tree().get_first_node_in_group(&"match")
	if g and g.party_frozen():   # 派對模式準備、結算時誰都不扣血
		return
	# 選單關掉恐龍攻擊時，恐龍（含 boss、火球）打人不扣血。傷害都在主機算，只看主機的開關就好
	if is_instance_valid(source) and source.is_in_group(&"dino"):
		if g and not g.dino_attacks:
			return
	_last_hit_by = source
	# 從哪裡打來的（給被打的人畫受傷方向）：恐龍是身體中心、牛仔是胸口；摔落沒有來源
	var from := Vector3.INF
	if is_instance_valid(source) and source is Node3D and source != self:
		from = (source as Node3D).global_position + (Vector3.ZERO if source.is_in_group(&"dino") else Vector3.UP * 1.3)
	_sync_hp.rpc(hp - amount, from)

## 血量只有主機能改。annotation 寫 any_peer 是因為牛仔節點的 authority 是玩家本人（他自己控制移動），
## 寫 authority 的話主機反而發不出來；所以收到時自己檢查是不是主機（編號 1）送的
@rpc("any_peer", "call_local", "reliable")
func _sync_hp(v: int, from := Vector3.INF) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if v < hp:
		last_from = from
		_flash_red()
		_on_hurt(hp - v, from)
	hp = v
	if hp <= 0:
		burn_left = 0.0   # 死了就不燒了
		died.emit(_last_hit_by)
		if multiplayer.is_server():
			queue_free()  # MultiplayerSpawner 會同步移除其他人畫面上的它

## 鎖住滑鼠（進遊戲、關選單、點畫面、系統放掉後鎖回來）都要走這裡。
static func lock_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## 上一幀跑完到現在超過 HITCH_MS＝剛卡了一下（載入、第一次編譯著色器）。卡住時累積的滑鼠位移會一次湧進來，
## 視角甩到亂七八糟的角度（以前以為是 macOS 鎖滑鼠噴的殘留位移，實測鎖定後不碰滑鼠一個事件都沒有）。
## 以前的做法是鎖定後一律擋 1.5 秒，結果進遊戲、關 Esc 都卡約 1 秒轉不了視角（2026-10-07 回報）。
## 現在只丟卡頓那一下湧進來的，其他立刻算。_frame_ms 由 main.gd 每幀更新；0＝還沒開始跑，不擋
static func after_hitch() -> bool:
	return _frame_ms > 0 and Time.get_ticks_msec() - _frame_ms > HITCH_MS

## 這個角色吃不吃這台電腦的滑鼠：要是自己操控的，而且不是電腦。
## 電腦（boss、bot、移動標靶）也是主機在操控，authority 是主機——不擋的話主機玩家一動滑鼠，
## 牠們的頭和身體也跟著轉（恐龍的頭跟主機玩家一起轉的 bug、0.8.1 回饋 B4）
func takes_mouse() -> bool:
	return is_multiplayer_authority() and not is_bot_id(name.to_int())

## 取滑鼠這一幀轉了多少
func mouse_look(e: InputEvent) -> Vector2:
	if e is InputEventMouseMotion and takes_mouse():
		_diag("角色收到")
		if after_hitch():
			_diag("卡頓擋掉")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not takes_mouse() or not (e is InputEventMouseMotion):
		return Vector2.ZERO
	if after_hitch():
		return Vector2.ZERO
	_diag("有轉")
	# screen_relative：relative 會跟著畫面縮放（canvas_items）變，全螢幕和小視窗靈敏度會不一樣
	return Settings.look(e.screen_relative)

static func _diag(k: String) -> void:
	diag[k] = diag.get(k, 0) + 1

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
## 被打了（每台都會呼叫）。牛仔在這裡做自己畫面上的受傷回饋（cowboy.gd）；from 是傷害來源，摔落是 INF
func _on_hurt(_amount: int, _from: Vector3) -> void:
	pass

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

# --- 補血包（草案 3.2）：牛仔用，恐龍生出來也有但不按 3 ---
## 補血包：每個回多少、補一次要多久（主機以 0.8 倍防狂送）。數值在 balance.csv
static var medkit_heal: int = Balance.whole("medkit_heal")
static var medkit_seconds: float = Balance.num("medkit_seconds")
## 剩幾個。主機記帳；本人那台跟著主機回報（_medkit_left）。生出來就是滿的，重生、新的一局都是新節點
var medkits: int = Balance.whole("medkit_count")
signal medkits_changed
var _medkit_ms := -100000000   # 主機記：上次補血的時刻（毫秒），防狂送

## 本人補好了（時間到）：主機自己直接算，客戶端送給主機
func request_heal() -> void:
	if multiplayer.is_server():
		_do_heal()
	else:
		_request_heal.rpc_id(1)

## 來源一定要是這個角色的主人（節點名字就是連線編號）
@rpc("any_peer", "call_remote", "reliable")
func _request_heal() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == name.to_int():
		_do_heal()

## 只有主機算：有包、活著、沒滿，離上次補至少 medkit_seconds × 0.8 才算。扣包、加血，剩幾包回報給本人
func _do_heal() -> void:
	var now := Time.get_ticks_msec()
	if medkits <= 0 or hp <= 0 or hp >= max_hp or now - _medkit_ms < medkit_seconds * 800.0:
		return
	_medkit_ms = now
	medkits -= 1
	medkits_changed.emit()
	_sync_hp.rpc(mini(hp + medkit_heal, max_hp))   # 血變多，_sync_hp 不會當受傷
	if name.to_int() != 1:   # 主機自己那台的包數就是 medkits，不用再送
		_medkit_left.rpc_id(name.to_int(), medkits)

@rpc("any_peer", "call_remote", "reliable")
func _medkit_left(n: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		medkits = n
		medkits_changed.emit()
