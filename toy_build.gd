class_name ToyBuild
extends StaticBody3D
## 玩具積木的一棟（docs/規劃/2026-11-08-玩具積木場景.md）：房子、掩體、樹、石頭、柵欄都是積木拼的。
## 一棟一個碰撞體、每塊一個 CollisionShape3D；畫面一個 MultiMesh，一次畫完。拆開鬆脫的塊變成 RigidBody3D 碎塊留在場上。
## 拆和碎塊停下來的位置都是主機算，其他台照 RPC 做。
##
## 節點名字由 arena_map.gd 依序取（Toy0、Toy1…），每台一樣，碎塊的名字「%s_P%d」接在後面（數字是碎塊的代表塊，見 _spawn），RPC 才找得到。
## 碎塊的飛行每台自己模擬，停下來以主機的位置為準（_settle），所以最後每台一樣。
##
## ponytail: 碎塊停下來的時間只看 4 秒或睡著，不做真的穩定判斷；停下來前各台位置可能不一樣，停下後才對齊
## ponytail: 子彈排除的是整棟不是單一塊（bullet.gd 的老問題）：同一發子彈穿過一塊，後面的塊也一起穿
## ponytail: 晚加入的人收到的是主機那一刻的狀態（_flush 先把排隊的生完），各台飛行中的位置不一樣的，要等 _settle 才對齊
## ponytail: 超過 MAX_PIECES 的那次鬆脫，併成的大塊共用一個包住它們的方塊碰撞（縫隙也算實心），不是每塊各一個形狀

const SETTLE_TIME := 4.0          # 碎塊飛出去之後幾秒就停下來（主機送 _settle）
const FALL_SPEED := 3.5           # 碎塊飛出去的初速（公尺／秒）
const MASS_PER_M3 := 40.0         # 碎塊質量：0.5 kg 加體積乘這個數
const BASE_TOP := 0.05            # 頂面在這棟原點以下（含）的塊算著地（連通檢查的起點）
const HIT_SOUND := "res://assets/audio/destruction/wood_crack.wav"
const HOUSE_FALL_SOUND := "res://assets/audio/destruction/house_collapse.wav"
const SHAKE_RANGE := 25.0         # 離鏡頭超過這個距離（公尺）就不震
const KICK_COOLDOWN := 500        # 毫秒：同一塊碎塊被踢過之後，這段時間內不再踢
const LAND_DROP := 50.0           # 專用伺服器：碎塊往下找落點最遠幾公尺（見 _land）
const PLOW_CLEAR := 6.5          # 專用伺服器：衝撞拆下的塊落在離路中線這麼遠以外（尼諾拉身體半徑約 3.6，加塊的大小）
const KICK_SHIFT := 4.0           # 專用伺服器：踢出去的碎塊先水平移開這麼遠再落下（公尺）；要比尼諾拉身體半徑（約 3.6）遠，才讓得出路
const LAND_LIFT := 0.5            # 專用伺服器：往下掃之前先抬高這麼多（剛好貼著地面或陷進去一點，掃不到東西）

static var _mat: ShaderMaterial
static var no_flight := false     # 專用伺服器設 true：主機上的碎塊不飛，直接落到正下方（見 _land）；客戶端照飛

var can_break := true             # 拆得掉（安全屋、掩體方塊、石頭不行，進 destructible 群組也是看這個）
var _layer := 1 | 16             # 碰撞層（make 設；樹是 1、不加 SOLID_LAYER，關碰撞物件時尼諾拉穿過）
var _xf: Array[Transform3D] = []  # 每塊在這棟裡的位置（相對原點）
var _size: Array[Vector3] = []
var _lv := PackedInt32Array()     # 等級：1、2 挨幾下倒，3 打不壞
var _mt: Array[StringName] = []   # 材質（HitRules.MATS；子彈穿透照它，碎塊的群組名也是它）
var _hp := PackedInt32Array()     # 還要挨幾下（主機才看）
var _burning := {}                # 塊編號 -> 著火幾秒了（主機才看，見 burn）
var _ash := PackedInt32Array()    # 燒成灰的塊（藏起來、沒有碎塊；晚加入補送用）
var _all := AABB()                # 整棟的邊界框（本地座標）：火離很遠就不用建鄰居表
var _col: Array[Color] = []
var _shape: Array[CollisionShape3D] = []
var _sidx := PackedInt32Array()   # 每塊的碰撞形狀編號（沒有碰撞的塊是 -1，不佔編號）
var _brick_of := PackedInt32Array()   # 碰撞形狀編號 -> 塊編號（子彈查穿透材質用）
var _nshape := 0
var _off := PackedByteArray()     # 形狀是不是停用了（拆掉的塊）
var _loose := PackedByteArray()   # 鬆脫了沒有（碎塊飛著或等著生都算）
var _bb: Array[AABB] = []         # 每塊的邊界框（這棟的本地座標，連通檢查用）
var _mm: MultiMesh
var _pieces := {}                 # 碎塊的代表塊編號（碎塊裡最小的那塊）-> 碎塊節點（飛的時候是 RigidBody3D，停下來換成 StaticBody3D）
var _info := {}                   # 代表塊編號 -> {m: 碎塊裡的塊（小到大）, rel: 每塊相對碎塊原點, box: 碰撞方塊, vol: 體積, lv: 最低等級}
var _age := {}                    # 碎塊飛了多久（主機用）
var _kick_t := {}                 # 踢過的碎塊：代表塊編號 -> 上次踢的毫秒（主機用）
var _touched := false             # 挨過打（鬆脫、或只挨一下），新的一場要還原
var _need_bake := false           # 有碎塊還在飛：停下來之後主機要烘一次導航
var _land_q: Array = []           # 排隊等著生的碎塊：[代表塊編號, 位置, 從哪裡飛出去, 速度, 是不是專用伺服器的落地]。專用伺服器是等落地（LAND_PER_TICK），其他是這一步生太多（SPAWN_PER_TICK）
var _adj: Array[PackedInt32Array] = []   # 連通檢查用：每塊相接的塊（_ensure_adj 建一次）
var _base := PackedInt32Array()          # 著地的塊（頂面在 BASE_TOP 以下，或等級 3）：連通檢查的起點
var _grid := {}                   # 連通檢查用的鄰居表：格子（Vector3i）-> 蓋到這格的塊編號。第一次要用時建，塊不會動
var geo_ver := 0                  # 形狀停用／啟用的次數（導航網格的快取要看這個）
var _landed := {}                 # 專用伺服器：已經落地（直接靜態）、還沒送 _settle 的碎塊：代表塊編號 -> 落地過了幾秒
const GRID := 1.6                 # 鄰居表的格子大小（公尺）
# ponytail: 一次鬆脫最多生 150 個碎塊（每個都是 RigidBody 加一個網格、一個形狀，一次生 1275 個要 70 毫秒的一幀）。
# 超過的那次鬆脫，塊照位置併成大塊（_merge：3 公尺的格子，併完還超過就格子加倍），碎塊總數還在上限內，每一塊都還在場上
const MAX_PIECES := 150
const MERGE_CELL := 3.0
# ponytail: 專用伺服器的落地每塊要往下掃一次（約 45 微秒），排隊分幀做，每幀最多這麼多塊；超過的留到下一幀
const LAND_PER_TICK := 30
# ponytail: 同一次鬆脫的碎塊飛滿 SETTLE_TIME 會在同一步一起停（150 個剛體刪掉、150 個靜態的加進物理，開視窗量到那一步 5～9 毫秒）。
# 這棟一步最多停這麼多個，剩下的下一步（150 個分 5 步，共 42 毫秒）
const SETTLE_PER_TICK := 30
# ponytail: 會飛的碎塊（單機、自己開房、客戶端）一次鬆脫當步最多生這麼多個，超過的排隊（_land_q）之後每步再生這麼多：塊的碰撞當步全關（尼諾拉不會被擋），
# 畫面等輪到它的碎塊生出來才換（牆是幾步之內陸續碎開，不會先破一個洞）。150 個分 4 步、共 33 毫秒。
# 開視窗量過：一步生 150 個要 6～10 毫秒（120 Hz 的一格才 8.3）；40 個約 2 毫秒
const SPAWN_PER_TICK := 40
# 上限是一棟一棟算的：甩尾同一步掃到三棟就是 120 個。要更緊就改成全場共用一個額度
var _spawn_n := 0                 # 這一次鬆脫當步已經生了幾個會飛的碎塊


## bricks：每塊 [Transform3D（相對這棟）, 尺寸 Vector3, 等級 int, 顏色 Color, 有沒有碰撞 bool（可省）, 材質 StringName（可省）]（Greybox.bricks 切出來的）。
## can_break_ = false：不進 destructible 群組（安全屋、掩體方塊、石頭）。layer：碰撞層（預設 1 加 SOLID_LAYER；樹傳 1；不碰撞傳 0）。
static func make(bricks: Array, can_break_ := true, layer := -1) -> ToyBuild:
	var t := ToyBuild.new()
	t.can_break = can_break_
	t._layer = layer if layer >= 0 else (1 | Fighter.SOLID_LAYER)   # 同 _build_arena：建築要擋關碰撞物件的尼諾拉
	t.collision_layer = t._layer
	if can_break_:
		t.add_to_group(&"destructible")
	t._mm = MultiMesh.new()
	t._mm.transform_format = MultiMesh.TRANSFORM_3D
	t._mm.use_colors = true
	t._mm.mesh = box_mesh()
	t._mm.instance_count = bricks.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = t._mm
	mmi.material_override = material()
	t.add_child(mmi)
	t._loose.resize(bricks.size())
	t._off.resize(bricks.size())
	for i in bricks.size():
		var b: Array = bricks[i]
		var xf: Transform3D = b[0]
		var size: Vector3 = b[1]
		t._xf.append(xf)
		t._size.append(size)
		t._lv.append(b[2])
		t._mt.append(b[5] if b.size() > 5 else HitRules.default_mat(b[2]))   # 第 6 個：材質（沒給照等級）
		t._hp.append(b[2])
		t._col.append(b[3])
		t._bb.append(xf * AABB(-size * 0.5, size))
		t._all = t._bb[i] if i == 0 else t._all.merge(t._bb[i])
		t._mm.set_instance_transform(i, Transform3D(xf.basis.scaled(size), xf.origin))
		t._mm.set_instance_color(i, b[3])
		var solid: bool = b[4] if b.size() > 4 else true   # 第 5 個：false＝有畫面、沒有碰撞（樹冠）
		t._sidx.append(-1)
		if solid:
			var sh := BoxShape3D.new()
			sh.size = size
			var cs := CollisionShape3D.new()
			cs.shape = sh
			cs.transform = xf
			t.add_child(cs)
			t._shape.append(cs)
			t._sidx[i] = t._nshape
			t._brick_of.append(i)
			t._nshape += 1
		t._off[i] = 0
		t._loose[i] = 0
	return t


## 全場的積木和碎塊共用一個 1 公尺的方塊網格（大小、顏色在每個實例上）
static var _box: BoxMesh
static func box_mesh() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
	return _box


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://toy_brick.gdshader")
	return _mat


## 拆（主機才算）：hit 收每塊的世界中心，回傳 true＝打到。打到的、等級 <= max_level、不是 3 的扣一下，扣到 0 鬆脫。
## 然後連通檢查：連不到地面的（懸空）也鬆脫。鬆脫的送 _break；有扣血但沒鬆脫的送 _hurt（各台抖一下）
## area 是世界座標的範圍（有體積才用）：只看範圍內的塊（hit 收的點要在範圍裡，範圍外的塊不會被打到）。沒給就是全部的塊
## power：碎塊飛出的速度（公尺／秒）；預設 FALL_SPEED 就是原本的飛法。dmg：每下扣幾點（全速撞的等級 2 扣 2 一下倒）。
## dir：水平的前進方向（專用伺服器全速撞：碎塊往這個方向的兩旁移開，見 _plow_xf）。回傳打到沒有（有扣血或鬆脫）
func smash(hit: Callable, max_level: int, from: Vector3, area := AABB(), power := FALL_SPEED, dmg := 1, dir := Vector3.ZERO) -> bool:
	var t0 := Time.get_ticks_usec()
	var any := _smash(hit, max_level, from, area, power, dmg, dir)
	var ms := (Time.get_ticks_usec() - t0) / 1000
	if ms > 20:   # 停頓記錄：拆一棟太慢時印出來（主機日誌）
		print("拆積木 %d 毫秒（%d 塊）" % [ms, _xf.size()])
	return any

func _smash(hit: Callable, max_level: int, from: Vector3, area: AABB, power: float, dmg: int, dir: Vector3) -> bool:
	if not multiplayer.is_server() or not can_break:
		return false
	var n := _xf.size()
	var loose := _loose.duplicate()
	var fresh := PackedInt32Array()
	var hurt := false
	for i in bricks_near(area):
		if loose[i] == 1 or _lv[i] >= 3 or _lv[i] > max_level:
			continue
		if not hit.call(global_transform * _xf[i].origin):
			continue
		_hp[i] -= dmg
		hurt = true
		if _hp[i] <= 0:
			loose[i] = 1
			fresh.append(i)
	if not fresh.is_empty():   # 沒有新鬆脫的塊，連通不會變（炸藥炸在空地就不用算）
		for i in _unsupported(loose):
			fresh.append(i)
	if not fresh.is_empty():
		fresh.sort()
		# 不超過上限：每塊一個碎塊（ids）；超過：全部照位置併成大塊（gone，見 _merge）
		if fresh.size() <= MAX_PIECES:
			_break.rpc(fresh, PackedInt32Array(), from, power, dir)
		else:
			_break.rpc(PackedInt32Array(), fresh, from, power, dir)
	elif hurt:
		_hurt.rpc()
	return hurt


## 連不到地面的塊（loose 為 1 的不算）：從著地的塊（頂面在 BASE_TOP 以下，或等級 3）順著邊界框相接（放大 0.05）一路找，找不到的回傳。
## 只看鄰居表（格子 GRID 公尺，每塊只跟蓋到同一格的比）：相接的塊先算好存著（_ensure_adj）
func _unsupported(loose: PackedByteArray) -> PackedInt32Array:
	var n := _xf.size()
	_ensure_adj()
	var ok := PackedByteArray()
	ok.resize(n)
	var todo := PackedInt32Array()
	for i in _base:
		if loose[i] == 0:
			ok[i] = 1
			todo.append(i)
	var h := 0
	while h < todo.size():
		for j in _adj[todo[h]]:
			if loose[j] == 0 and ok[j] == 0:
				ok[j] = 1
				todo.append(j)
		h += 1
	var out := PackedInt32Array()
	for i in n:
		if loose[i] == 0 and ok[i] == 0:
			out.append(i)
	return out


## 每塊相接的塊（_adj）和著地的塊（_base）：塊不會動，算一次就好。
## 以前每次連通檢查都重查格子、重比邊界框，1659 塊的房子一次 6～8 毫秒，尼諾拉撞穿時每 0.1 秒一次；現在只走表，約 1 毫秒
func _ensure_adj() -> void:
	if not _adj.is_empty() or _xf.is_empty():
		return
	_ensure_grid()
	for a in _xf.size():
		if _lv[a] == 3 or _bb[a].position.y <= BASE_TOP:
			_base.append(a)
		var ga := _bb[a].grow(0.05)
		var seen := {}
		var near := PackedInt32Array()
		for c: Vector3i in _cells(ga):
			for j: int in _grid[c]:
				if j != a and not seen.has(j) and ga.intersects(_bb[j]):
					seen[j] = true
					near.append(j)
		_adj.append(near)


## 鬆脫（每台一樣）：ids 每塊馬上生一個碎塊（塊藏起來、碎塊往外飛）；gone 是超過上限的，照位置併成大塊，每組生一個。
## 塊的碰撞一次全部關掉（_set_off 一批）才生碎塊；一步生不完的排隊（SPAWN_PER_TICK）。主機重烘導航（碎塊還沒停下，先不算進去）
@rpc("authority", "call_local", "reliable")
func _break(ids: PackedInt32Array, gone: PackedInt32Array, from: Vector3, power: float, dir: Vector3) -> void:
	_touched = true
	var at := Vector3.ZERO
	var order: Array = Array(ids)
	if ToyBuild.no_flight and multiplayer.is_server():   # 專用伺服器：由低到高落地，後面的疊在前面的上面
		order.sort_custom(func(a: int, b: int) -> bool: return _xf[a].origin.y < _xf[b].origin.y)
	for i in ids:
		_loose[i] = 1
		at += global_transform * _xf[i].origin
	for i in gone:
		_loose[i] = 1
		at += global_transform * _xf[i].origin
	_spawn_n = 0
	_set_off(ids + gone, true)   # 碰撞這一步全關；畫面等碎塊生出來才換（_spawn、_land_next）
	for i in order:
		_spawn(PackedInt32Array([i]), _xf[i], _plow_xf(global_transform * _xf[i], from, dir, power), true, from, power)
	for g: PackedInt32Array in _merge(gone):
		_spawn_group(g, from, power, dir)
	at /= float(maxi(ids.size() + gone.size(), 1))
	sfx(self, HOUSE_FALL_SOUND, 80.0, at)
	Fx.dust_ring(get_parent(), Vector3(at.x, global_position.y, at.z), 4.0, 30, 5.0, 1.4)
	set_physics_process(true)
	if multiplayer.is_server():
		_need_bake = true   # 碎塊停下來才烘（烘的時候碎塊要已經是靜態的）


## 超過上限的那些塊併成大塊（純計算，每台一樣）：照位置分到 MERGE_CELL 公尺的格子，併完還超過 MAX_PIECES 就格子加倍。
## 每組的塊編號由小到大（組的代表塊＝第一個）
func _merge(ids: PackedInt32Array) -> Array:
	var sorted := ids.duplicate()
	sorted.sort()
	var cell := MERGE_CELL
	while true:
		var groups := {}
		for i in sorted:
			var o := _xf[i].origin
			var k := Vector3i(floori(o.x / cell), floori(o.y / cell), floori(o.z / cell))
			if not groups.has(k):
				groups[k] = PackedInt32Array()
			groups[k].append(i)
		if groups.size() <= MAX_PIECES:
			return groups.values()
		cell *= 2.0
	return []


## 生一個碎塊（主機和各台都走這裡）：mem 是碎塊裡的塊，local 是碎塊的原點（相對這棟），xf 是它現在的世界位置。
## 碰撞用一個包住所有塊的方塊、畫面用一個 MultiMesh（每塊一個實例）。名字用代表塊編號
## flying：剛鬆脫的（從 from 用 power 的速度飛出去）；這一步生太多、或專用伺服器要落地的，先排隊（回傳 null）
func _spawn(mem: PackedInt32Array, local: Transform3D, xf: Transform3D, flying: bool, from := Vector3.ZERO, power := FALL_SPEED) -> Node3D:
	var rel: Array = []
	var box := AABB()
	var vol := 0.0
	var lv := 3
	var mt := &"stone"
	var inv := local.affine_inverse()
	for k in mem.size():
		var m := mem[k]
		var r := inv * _xf[m]
		rel.append(r)
		var b := r * AABB(-_size[m] * 0.5, _size[m])
		box = b if k == 0 else box.merge(b)
		vol += _size[m].x * _size[m].y * _size[m].z
		if HitRules.thick(_mt[m]) < HitRules.thick(mt):   # 併起來的碎塊照最薄的材質（子彈穿得過最薄那塊）
			mt = _mt[m]
		lv = mini(lv, _lv[m])
	_info[mem[0]] = {"m": mem, "rel": rel, "box": box, "vol": vol, "lv": lv, "mt": mt}
	if flying:
		var lands := ToyBuild.no_flight and multiplayer.is_server()
		if lands:
			# ponytail: 專用伺服器的碎塊不飛：直接靜態、落到正下方，不是真的散落；要真的散落就用少一點的剛體模擬
			_landed[mem[0]] = 0.0
		if lands or _spawn_n >= SPAWN_PER_TICK:
			_land_q.append([mem[0], xf, from, power, lands])   # 排隊（_physics_process 分幀生）；晚加入補送前由 _flush 全部做完
			return null
		_spawn_n += 1
	_hide_look(mem)
	var n := _make(mem[0], flying, xf)
	if flying:
		_fling(n as RigidBody3D, from, power)
	return n



## 大碎塊：原點取塊中心的平均；只有一塊的照那塊的位置
func _spawn_group(mem: PackedInt32Array, from: Vector3, power: float, dir: Vector3) -> void:
	var local := _xf[mem[0]]
	if mem.size() > 1:
		var c := Vector3.ZERO
		for m in mem:
			c += _xf[m].origin
		local = Transform3D(Basis(), c / float(mem.size()))
	_spawn(mem, local, _plow_xf(global_transform * local, from, dir, power), true, from, power)


## 專用伺服器的全速撞（碎塊不飛、直接落地）：落地前先往尼諾拉兩旁移開 KICK_SHIFT（同 boss.gd _kick_piece），不然碎塊落在路上、又擋住下一下。
## power 不超過 FALL_SPEED（一般的撞）或不是專用伺服器就原樣回傳
func _plow_xf(xf: Transform3D, from: Vector3, dir: Vector3, power: float) -> Transform3D:
	if power <= FALL_SPEED or not (ToyBuild.no_flight and multiplayer.is_server()):
		return xf
	var fwd := Vector3(dir.x, 0.0, dir.z).normalized()
	var lat := xf.origin - from
	lat.y = 0.0
	lat -= fwd * lat.dot(fwd)
	var side := lat.length()
	if side < 0.3:   # 正在路中間：隨便挑一邊（只在主機算，落點之後照主機同步）
		lat = fwd.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	# 移到尼諾拉身體掃過的路外面（離路中線至少 PLOW_CLEAR），不然落在路上又把牠擋停；本來就在外面的再往外 1 公尺
	xf.origin += lat.normalized() * (maxf(PLOW_CLEAR, side + 1.0) - side)
	return xf


## 專用伺服器的落地（no_flight）：xf 是碎塊現在的位置、box 是它的邊界框（碎塊本地）。扶正（保留偏航角），往正下方落到第一個擋住的。
## 擋的有兩種：這棟自己站著的塊（不在物理查詢裡，照本地的鄰居表算頂面）、其他東西（物理查詢，排除自己、skip、尼諾拉）。取近的那個。
## 回傳落地後的位置（只改高度）。沒有擋的（物理查不到、這棟也沒有）就落 LAND_DROP 公尺
func _land(xf: Transform3D, box: AABB, skip: Array[RID]) -> Transform3D:
	var up := Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), xf.origin)
	var wb := up * box
	# 這棟自己的塊：沒鬆脫、沒藏、有碰撞，邊界框跟碎塊的水平範圍相接、頂面在碎塊底下的，取最高的
	_ensure_grid()
	var lb := global_transform.affine_inverse() * wb
	var bottom := lb.position.y
	var top := -INF
	for c: Vector3i in _cells(lb):
		for j: int in _grid.get(c, []):
			var b := _bb[j]
			if _loose[j] == 0 and _off[j] == 0 and _sidx[j] >= 0 and b.end.y <= bottom + 0.01 and b.end.y > top \
					and b.end.x >= lb.position.x and b.position.x <= lb.end.x and b.end.z >= lb.position.z and b.position.z <= lb.end.z:
				top = b.end.y
	var d := INF if top == -INF else bottom - top
	# 其他東西（地形、別棟、別的碎塊、掩體）：方塊往下掃，碰到的第一個
	var sh := BoxShape3D.new()
	sh.size = box.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = up * Transform3D(Basis(), box.get_center() + Vector3.UP * LAND_LIFT)
	q.motion = Vector3.DOWN * (LAND_DROP + LAND_LIFT)
	var ex: Array[RID] = skip.duplicate()
	ex.append(get_rid())
	for b in get_tree().get_nodes_in_group(&"boss"):
		if b is CollisionObject3D:
			ex.append((b as CollisionObject3D).get_rid())
	q.exclude = ex
	var drop := minf(maxf(get_world_3d().direct_space_state.cast_motion(q)[0] * (LAND_DROP + LAND_LIFT) - LAND_LIFT, 0.0), d)
	return Transform3D(up.basis, up.origin + Vector3.DOWN * drop)


## 往外飛：從 from 往碎塊的方向（水平），加一點往上，往前滾
## power 比一般的 FALL_SPEED 快（全速撞）：往上飛高一點、亂轉，速度照 power（碎塊照撞的速度飛）
func _fling(rb: RigidBody3D, from: Vector3, power := FALL_SPEED) -> void:
	var d := rb.global_position - from
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	if power > FALL_SPEED:
		var up := (d + Vector3.UP * 0.6).normalized()
		rb.apply_central_impulse(up * power * rb.mass)
		rb.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		return
	var dir := (d + Vector3.UP * 0.4).normalized()
	rb.apply_central_impulse(dir * FALL_SPEED * rb.mass)
	rb.angular_velocity = Vector3(d.z, 0.0, -d.x) * 4.0   # 往前滾


## 挨了一下沒倒：各台抖一下、播打擊聲
@rpc("authority", "call_local", "reliable")
func _hurt() -> void:
	_touched = true
	hit_fx(self, global_position + Vector3.UP, false)


## 碎塊停下來（主機送，各台照做）：換成靜態的，放在主機算的位置。導航網格要讀得到，所以不留 RigidBody3D
@rpc("authority", "call_local", "reliable")
func _settle(ids: PackedInt32Array, xfs: Array) -> void:
	for k in ids.size():
		_freeze(ids[k], xfs[k])


## 晚加入（單塊的碎塊）：主機把鬆脫的塊和它們現在的位置補給他（直接到位、凍住、不播音效）。
## gone：藏起來沒有碎塊的。send_state_to 先把排隊的生完，所以主機現在送的是空的，留著給同一套的補送
@rpc("authority", "reliable")
func _resume(ids: PackedInt32Array, xfs: Array, gone: PackedInt32Array) -> void:
	var hide := PackedInt32Array()
	for i in gone:
		_touched = true
		_loose[i] = 1
		hide.append(i)
	var todo: Array[int] = []
	for k in ids.size():
		if _pieces.has(ids[k]):
			continue
		_touched = true
		_loose[ids[k]] = 1
		hide.append(ids[k])
		todo.append(k)
	_hide_bricks(hide)
	for k in todo:
		_spawn(PackedInt32Array([ids[k]]), _xf[ids[k]], xfs[k], false)


## 晚加入（大碎塊）：碎塊裡的塊和它現在的位置（直接到位、凍住）。原點照塊的平均算，跟主機一樣
@rpc("authority", "reliable")
func _resume_group(mem: PackedInt32Array, xf: Transform3D) -> void:
	_touched = true
	var c := Vector3.ZERO
	for m in mem:
		_loose[m] = 1
		c += _xf[m].origin
	_hide_bricks(mem)
	_spawn(mem, Transform3D(Basis(), c / float(mem.size())), xf, false)


## 主機：晚加入的人連進來時呼叫（send_state_to）。先把排隊要落地的落完，然後每個碎塊的現在位置：
## ids／xfs 是單塊的碎塊（_resume），groups 是大碎塊 [塊編號, 位置]（_resume_group）
func state() -> Dictionary:
	_flush()
	var ids := PackedInt32Array()
	var xfs := []
	var groups := []
	for key in _pieces:
		var n: Node3D = _pieces[key]
		var mem: PackedInt32Array = _info[key].m
		if mem.size() == 1:
			ids.append(mem[0])
			xfs.append(n.global_transform)
		else:
			groups.append([mem, n.global_transform])
	return {"ids": ids, "xfs": xfs, "groups": groups}


func send_state_to(peer: int) -> void:
	var st := state()
	for g: Array in st.groups:
		_resume_group.rpc_id(peer, g[0], g[1])
	if not (st.ids as PackedInt32Array).is_empty() or not _ash.is_empty():
		_resume.rpc_id(peer, st.ids, st.xfs, _ash)   # 燒成灰的走 gone：藏起來、不生碎塊


## 排隊要落地的照排隊的順序全部落完（主機補送前用，一次做完、不分幀）
func _flush() -> void:
	while not _land_q.is_empty():
		_land_next()


## 排隊的第一塊：專用伺服器算落點、生成靜態的碎塊；其他生成會飛的
func _land_next() -> void:
	var p: Array = _land_q.pop_front()
	_hide_look(_info[p[0]].m)
	if _pieces.has(p[0]):   # 排隊的時候已經照主機的位置生好了（_settle 先到）
		return
	if p[4]:   # 排隊那時候是專用伺服器的落地
		var none: Array[RID] = []
		_make(p[0], false, _land(p[1], _info[p[0]].box, none))
	else:
		_fling(_make(p[0], true, p[1]) as RigidBody3D, p[2], p[3])


## 新的一場（party.gd start、main.restore_terrain）：碎塊刪掉、每塊放回原位、血量回滿。碰撞層和群組由 set_on 管
@rpc("authority", "call_local", "reliable")
func restore() -> void:
	for n: Node3D in _pieces.values():
		n.queue_free()
	_pieces.clear()
	_info.clear()
	_age.clear()
	_kick_t.clear()
	_landed.clear()
	_land_q.clear()
	_burning.clear()
	_ash.clear()
	OilFire.queue = OilFire.queue.filter(func(q: Array) -> bool: return q[0] != self)   # 排隊要生的火也不要了
	for i in _xf.size():
		_hp[i] = _lv[i]
		_loose[i] = 0
		_mm.set_instance_transform(i, Transform3D(_xf[i].basis.scaled(_size[i]), _xf[i].origin))
	_set_off(PackedInt32Array(range(_xf.size())), false)
	_touched = false
	set_physics_process(false)


## 尼諾拉踢碎塊（主機才叫，尼諾拉跑進碎塊時 boss.gd 呼叫）：dir 是水平的前進方向，speed 是速度（公尺／秒，balance.csv 的 toy_kick）。
## 衝量＝速度乘質量，各台算一樣。同一塊 KICK_COOLDOWN 毫秒內只踢一次
func kick(key: int, dir: Vector3, speed: float) -> void:
	if not multiplayer.is_server() or not _info.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_kick_t.get(key, -KICK_COOLDOWN)) < KICK_COOLDOWN:
		return
	_kick_t[key] = now
	var mass := 0.5 + float(_info[key].vol) * MASS_PER_M3
	_kick.rpc(key, dir * speed * mass)


## 踢（各台）：靜態的碎塊換成飛的（同名、同位置、同一個代表塊），給衝量。主機之後照 _physics_process 停下來再 _settle
@rpc("authority", "call_local", "reliable")
func _kick(key: int, impulse: Vector3) -> void:
	var n: Node3D = _pieces.get(key)
	if n == null:
		return
	if n is StaticBody3D and ToyBuild.no_flight and multiplayer.is_server():   # 專用伺服器：不飛，先水平移開再直接落地
		var xf := n.global_transform
		var ex: Array[RID] = [(n as StaticBody3D).get_rid()]   # 舊的還在場上（queue_free 到幀尾才刪），落點不算它
		n.name = n.name + "~"
		n.queue_free()
		var shift := Vector3(impulse.x, 0.0, impulse.z).normalized() * KICK_SHIFT
		_landed[key] = 0.0
		_make(key, false, _land(Transform3D(xf.basis, xf.origin + shift), _info[key].box, ex))
		_need_bake = true
		_age.erase(key)
		return
	if n is StaticBody3D:
		var xf := n.global_transform
		n.name = n.name + "~"   # 讓出名字，新的才能用同一個
		n.queue_free()
		n = _make(key, true, xf)
	(n as RigidBody3D).apply_central_impulse(impulse)
	set_physics_process(true)
	if multiplayer.is_server():
		_age.erase(key)   # 踢完重新算飛的時間
		_need_bake = true


## 挨過打沒有（新的一場要不要還原）
func has_damage() -> bool:
	return _touched


## 碎塊的代表塊編號和碎塊現在的位置（測試和晚加入用）
func loose_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _pieces:
		out.append(i)
	return out


func loose_xforms() -> Array:
	var out := []
	for i in _pieces:
		out.append((_pieces[i] as Node3D).global_transform)
	return out


## 這塊的材質（HitRules.MATS）：子彈穿透查表用。不能拆的沒有材質（照以前一律擋）。shape 是碰撞形狀的編號
func material_of(shape: int) -> StringName:
	if not can_break or shape < 0 or shape >= _brick_of.size():
		return &""
	return _mt[_brick_of[shape]]


## 測試用：塊現在還站著（沒鬆脫）、它的等級、剩幾下、它的世界中心
func is_standing(i: int) -> bool:
	return _loose[i] == 0


func level_of(i: int) -> int:
	return _lv[i]


func hp_of(i: int) -> int:
	return _hp[i]


func center_of(i: int) -> Vector3:
	return global_transform * _xf[i].origin


func brick_count() -> int:
	return _xf.size()


## 進場景樹時關掉每幀處理：只有鬆脫後才開（_break、_kick），碎塊停下來就關
func _ready() -> void:
	set_physics_process(false)
	if can_break:
		_ensure_adj()   # 載入時先建好（全場約 12000 塊共幾十毫秒），不要留到第一次被撞的那一幀


## 每幀：先生排隊的碎塊（分幀）；主機再看碎塊睡著或飛滿 SETTLE_TIME 秒的，送 _settle（連同它的位置）
func _physics_process(delta: float) -> void:
	var k := 0
	while not _land_q.is_empty() and k < (LAND_PER_TICK if _land_q[0][4] else SPAWN_PER_TICK):
		_land_next()
		k += 1
	if not multiplayer.is_server():
		if _idle():
			set_physics_process(false)
		return
	var ids := PackedInt32Array()
	var xfs := []
	for key in _pieces:
		var n: Node3D = _pieces[key]
		if not n is RigidBody3D:
			continue
		_age[key] = _age.get(key, 0.0) + delta
		# 已經停了（睡著或飛滿 SETTLE_TIME）才看卡不卡：凍在尼諾拉身體裡會把牠頂起來：等牠出來再凍；但最多等 SETTLE_TIME 的 3 倍，之後不管重疊直接凍
		if ids.size() < SETTLE_PER_TICK and ((n as RigidBody3D).sleeping or _age[key] >= SETTLE_TIME) and not (_age[key] < SETTLE_TIME * 3.0 and _in_boss(n)):
			ids.append(key)
			xfs.append(n.global_transform)
	for key in _landed.keys():   # 專用伺服器落地的碎塊：落地滿 SETTLE_TIME 秒才送最後位置（各台的碎塊飛完才對齊）
		_landed[key] += delta
		if _landed[key] >= SETTLE_TIME and _pieces.has(key):
			_landed.erase(key)
			ids.append(key)
			xfs.append((_pieces[key] as Node3D).global_transform)
	if not ids.is_empty():
		_settle.rpc(ids, xfs)
	if _need_bake and _idle() and not _has_flying():   # 這棟的碎塊全部停下來、形狀也藏完了：烘一次（專用伺服器的碎塊落地就是停了）
		_need_bake = false
		_bake()
	if _idle() and not _has_flying() and _landed.is_empty():
		set_physics_process(false)


## 碎塊的形狀有沒有跟尼諾拉（boss 群組）重疊（主機凍住前看）
func _in_boss(n: Node3D) -> bool:
	var cs: CollisionShape3D = null
	for c in n.get_children():
		if c is CollisionShape3D:
			cs = c
	if cs == null or cs.shape == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = n.global_transform * cs.transform
	q.exclude = [n.get_rid()]
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var c: Object = r.collider
		if c is Node3D and (c as Node3D).is_in_group(&"boss"):
			return true
	return false


## 沒有排隊要生的碎塊
func _idle() -> bool:
	return _land_q.is_empty()


## 鄰居表：第一次要用時建（連通檢查、範圍內的塊都用它）
func _ensure_grid() -> void:
	if not _grid.is_empty():
		return
	for i in _xf.size():
		for c: Vector3i in _cells(_bb[i].grow(0.05)):
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append(i)


## 範圍（世界座標）蓋到的塊編號，由小到大；範圍沒有體積就是全部的塊。範圍內的塊一定在鄰居表的格子裡（格子蓋的是邊界框）
func bricks_near(area: AABB) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not area.has_volume():
		out.resize(_xf.size())
		for i in _xf.size():
			out[i] = i
		return out
	_ensure_grid()
	# 只看範圍和這棟重疊的部分：甩尾的範圍是 24 公尺的方塊（3000 多格），一格一格查要 1.3 毫秒，大部分在這棟外面
	var la := (global_transform.affine_inverse() * area).intersection(_all.grow(GRID))
	if not la.has_volume():
		return out
	var seen := PackedByteArray()
	seen.resize(_xf.size())
	for c: Vector3i in _cells(la):
		for j: int in _grid.get(c, []):
			if seen[j] == 0:
				seen[j] = 1
				out.append(j)
	out.sort()
	return out


## 邊界框蓋到的格子
func _cells(bb: AABB) -> Array:
	var a := Vector3i(floori(bb.position.x / GRID), floori(bb.position.y / GRID), floori(bb.position.z / GRID))
	var b := Vector3i(floori(bb.end.x / GRID), floori(bb.end.y / GRID), floori(bb.end.z / GRID))
	var out := []
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				out.append(Vector3i(x, y, z))
	return out


func _has_flying() -> bool:
	for n: Node3D in _pieces.values():
		if n is RigidBody3D:
			return true
	return false


## 一批形狀停用／啟用（拆掉的塊、還原）。每改一個形狀，物理伺服器要重算整棟（1659 塊的房子一個 87 微秒），所以先把這棟移出物理空間，
## 一批關完再放回去（同一幀做完，量過 150 塊 0.16 毫秒；物理要到下一步才看得到）
func _set_off(ids: PackedInt32Array, off: bool) -> void:
	var sh := PackedInt32Array()
	for i in ids:
		_off[i] = 1 if off else 0
		if _sidx[i] >= 0:
			sh.append(_sidx[i])
	geo_ver += 1   # 形狀變了：導航網格重烘時要重新解析（main.gd _parse_arena）
	if sh.is_empty():
		return
	var rid := get_rid()
	var space := PhysicsServer3D.body_get_space(rid)
	PhysicsServer3D.body_set_space(rid, RID())
	for s in sh:
		PhysicsServer3D.body_set_shape_disabled(rid, s, off)
	PhysicsServer3D.body_set_space(rid, space)


## 藏起來：碰撞形狀停用、畫面縮成零
func _hide_bricks(ids: PackedInt32Array) -> void:
	_set_off(ids, true)
	_hide_look(ids)


## 只藏畫面（碰撞另外關）：塊換成碎塊的那一刻叫
func _hide_look(ids: PackedInt32Array) -> void:
	for i in ids:
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## 碎塊節點：flying 是剛鬆脫、還在飛（RigidBody3D）；否則是靜態的（StaticBody3D）。名字每台一樣。
## 中繼資料：toy_key 是代表塊編號、toy_home 是這棟（boss.gd 撞到碎塊時用）
func _make(key: int, flying: bool, xf: Transform3D) -> Node3D:
	var info: Dictionary = _info[key]
	var mem: PackedInt32Array = info.m
	var n: Node3D = RigidBody3D.new() if flying else StaticBody3D.new()
	n.name = "%s_P%d" % [name, key]
	n.collision_layer = collision_layer   # 跟這棟一樣（派對房子藏起來時碎塊也藏、沒有碰撞；樹的碎塊不加 SOLID_LAYER）
	n.visible = visible
	n.collision_mask = 1
	n.set_meta(&"toy_key", key)
	n.set_meta(&"toy_home", self)
	n.add_to_group(&"toy_piece")
	if can_break:
		n.add_to_group(info.mt)   # 子彈照材質穿碎塊（Bullet.pierce_left）
	var box: AABB = info.box
	var sh := BoxShape3D.new()
	sh.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = box.get_center()
	n.add_child(cs)
	# 碎塊的畫面只建一次、存在 info 裡：飛的換成靜態的（_freeze）、被踢（_kick）都是刪掉重生，重生時接著用。
	# 開視窗量過：生 150 個碎塊 4.5 毫秒裡 2.6 毫秒是每個都新建一個方塊網格和 MultiMesh（沒畫面的量法看不到，那邊不用真的建）
	var mm: MultiMesh = info.get("mm")
	if mm == null:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box_mesh()
		mm.instance_count = mem.size()
		for k in mem.size():
			var r: Transform3D = info.rel[k]
			mm.set_instance_transform(k, Transform3D(r.basis.scaled(_size[mem[k]]), r.origin))
			mm.set_instance_color(k, _col[mem[k]])
		info.mm = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material()
	n.add_child(mmi)
	if flying:
		(n as RigidBody3D).mass = 0.5 + float(info.vol) * MASS_PER_M3
		# 飛的時候不跟尼諾拉（boss 群組）相撞：碎塊常是生在身體裡（貼著墻撞的、身體下面的）。撞進去會被身體推開，速度大到炸飛。
		# 落地（_settle 凍住）以後才照常擋；尼諾拉要踢碎塊是從前面踢（boss.gd 的 _kick_ahead）
		for b in get_tree().get_nodes_in_group(&"boss"):
			if b is PhysicsBody3D:
				(n as RigidBody3D).add_collision_exception_with(b)
	if ToyBuild.no_flight and not flying:   # 專用伺服器的靜態碎塊：先擺好位置再進場景樹（進了才改的位置，物理要到下一步才看得到）
		n.transform = get_parent().global_transform.affine_inverse() * xf
	get_parent().add_child(n)
	n.global_transform = xf
	_pieces[key] = n
	return n


## 碎塊停下來：飛的換成靜態的（同名、同位置），靜態的只移位置
func _freeze(key: int, xf: Transform3D) -> void:
	var old: Node3D = _pieces.get(key)
	_age.erase(key)
	if old is StaticBody3D:
		old.global_transform = xf
		return
	if old:
		old.name = old.name + "~"   # 讓出名字，新的才能用同一個
		old.queue_free()
	if _info.has(key):
		_make(key, false, xf)


## 碎塊停下來後要重烘導航（碎塊會擋恐龍的路）：主機在這棟的碎塊全部停下來之後呼叫一次
func _bake() -> void:
	var g := get_tree().get_first_node_in_group(&"match")
	if g and g.has_method(&"bake_nav"):
		g.bake_nav(true)


## 派對模式才看得到、拆得掉（arena_map.gd 的 set_party_house）：不是派對就整棟藏起來、碰撞和群組拿掉，碎塊也藏
func set_on(on: bool) -> void:
	visible = on
	collision_layer = _layer if on else 0
	if on and can_break:
		add_to_group(&"destructible")
	else:
		remove_from_group(&"destructible")
	for n: Node3D in _pieces.values():
		n.visible = on
		n.collision_layer = _layer if on else 0


## ---- 挨打、倒下的回饋（積木共用）----

## 挨打的回饋：碎裂聲在 at，鏡頭震離 at 越遠越小，操作恐龍的那台停一下。回傳鏡頭震了多少（測試用）
static func hit_fx(on: Node3D, at: Vector3, down: bool) -> float:
	sfx(on, HIT_SOUND, 40.0, at)
	var r := Fx.shake(on, at, 0.08 if down else 0.03, SHAKE_RANGE)
	var who: Node = r[0]
	var amount: float = r[1]
	if who == null:
		return 0.0
	# 尼諾拉正在全速撞：停頓只在第一下給（boss.gd _plow_fed），這裡不再停
	if who.has_method(&"add_hitstop") and not (who.has_method(&"is_plowing") and who.is_plowing()):
		who.add_hitstop(0.1 if down else 0.06)
	return amount


## 3D 音效播一次、播完自己收掉（照 shot_fx.gd 的 impact_sound）。檔案還沒放進來就安靜跳過
static func sfx(on: Node3D, path: String, max_dist: float, at: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var snd := AudioStreamPlayer3D.new()
	on.get_parent().add_child(snd)
	snd.stream = load(path)
	snd.max_distance = max_dist
	snd.global_position = at
	snd.play()
	snd.finished.connect(snd.queue_free)


## 火燒（主機才算，OilFire 每 TICK 叫）：covers 收塊上離火（at）最近的一點（世界座標），回傳 true＝在火裡（大片牆板中心離很遠也燒得到）。可燃（HitRules.burns）、還站著的塊累積著火秒數，
## 滿 fire_catch_seconds 就燒成灰（藏起來、不留碎塊）；燒掉以後懸空的照常鬆脫成碎塊。一次最多燒 limit 塊。回傳燒掉的塊中心（生新火用）
func burn(covers: Callable, at: Vector3, area: AABB, dt: float, limit: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not multiplayer.is_server() or not can_break or not _all.intersects(global_transform.affine_inverse() * area):
		return out
	var catch := Balance.num("fire_catch_seconds")
	var la := global_transform.affine_inverse() * at
	var loose := _loose.duplicate()
	var ash := PackedInt32Array()
	for i in bricks_near(area):
		if loose[i] == 1 or not HitRules.burns(_mt[i]):
			continue
		var near := (_xf[i].affine_inverse() * la).clamp(-_size[i] * 0.5, _size[i] * 0.5)   # 塊自己的座標：離火最近的一點
		if not covers.call(global_transform * (_xf[i] * near)):
			continue
		var c := global_transform * _xf[i].origin
		_burning[i] = float(_burning.get(i, 0.0)) + dt
		if _burning[i] >= catch and ash.size() < limit:
			loose[i] = 1
			ash.append(i)
			out.append(c)
	if ash.is_empty():
		return out
	for i in ash:
		_burning.erase(i)
	_ash_off.rpc(ash)
	var fall := _unsupported(loose)
	if fall.size() > MAX_PIECES:
		_break.rpc(PackedInt32Array(), fall, out[0], FALL_SPEED, Vector3.ZERO)
	elif not fall.is_empty():
		_break.rpc(fall, PackedInt32Array(), out[0], FALL_SPEED, Vector3.ZERO)
	return out


## 燒成灰（各台）：塊藏起來、不生碎塊
@rpc("authority", "call_local", "reliable")
func _ash_off(ids: PackedInt32Array) -> void:
	_touched = true
	for i in ids:
		_loose[i] = 1
		_ash.append(i)
	_hide_bricks(ids)
	set_physics_process(true)
	if multiplayer.is_server():
		_need_bake = true


## 在 at 生一灘火（主機叫；各台都生，見 _fire）。全場還在燒的火滿 fire_max 灘就不生。回傳生了沒有
func fire_at(at: Vector3, r: float, secs: float) -> bool:
	if not multiplayer.is_server():
		return false
	var live := 0
	for f: Node in get_tree().get_nodes_in_group(&"oil_fire"):
		if f.burning():
			live += 1
	if live >= Balance.whole("fire_max"):
		return false
	_fire.rpc(at, r, secs)
	return true


## 火球打到這棟：命中點 reach 內有可燃、還站著的塊就在命中點留一灘火（先查再拆，拆掉的塊也算）
func fireball_fire(at: Vector3, reach: float) -> void:
	if Balance.whole("fire_burns_toys") == 0:
		return
	for i in bricks_near(AABB(at - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)):
		if _loose[i] == 0 and HitRules.burns(_mt[i]) and (global_transform * _xf[i].origin).distance_to(at) < reach:
			fire_at(at, Balance.num("fire_ball_radius"), Balance.num("fire_ball_seconds"))
			return


@rpc("authority", "call_local", "reliable")
func _fire(at: Vector3, r: float, secs: float) -> void:
	OilFire.spill(get_parent(), at, null, r, secs, false)


## 炸藥爆炸（主機才算）：範圍內力道（hit_blast_force，1）打得壞的塊扣一下：木頭一下就倒，樹、磚、石頭不受影響（草案 4.2 一般炸彈）。
## ponytail: 只看距離，不算中間有沒有牆擋住；方塊房子的牆互相擋住的話，爆炸會穿過去拆後面的等級 1 方塊
static func blast(world: Node3D, at: Vector3, radius: float) -> void:
	# 先推碎塊（物理規則第二版）：範圍內可推的碎塊從爆心往外、往上噴（新拆下來的本來就會飛，不用再推）
	var push := Balance.num("blast_push")
	for n: Node in world.get_tree().get_nodes_in_group(&"toy_piece"):
		var home: Variant = n.get_meta(&"toy_home", null)
		var d := (n as Node3D).global_position - at
		if d.length() >= radius or not is_instance_valid(home) or not (home as ToyBuild)._info.has(n.get_meta(&"toy_key")):
			continue
		if HitRules.pushable((home as ToyBuild)._info[n.get_meta(&"toy_key")].mt):
			(home as ToyBuild).kick(n.get_meta(&"toy_key"), (d.normalized() + Vector3.UP * 0.6).normalized(), push * (1.0 - d.length() / radius))
	for w: Node in world.get_tree().get_nodes_in_group(&"destructible"):
		if w is ToyBuild:
			(w as ToyBuild).smash(func(p: Vector3) -> bool: return p.distance_to(at) < radius, Balance.whole("hit_blast_force"), at, AABB(at - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
