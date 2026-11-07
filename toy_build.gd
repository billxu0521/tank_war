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
const ARMOR_GROUP := [&"plank", &"double_plank", &"metal"]   # 等級 1、2、3 的子彈穿透材質（bullet.gd ARMOR）
const BASE_TOP := 0.05            # 頂面在這棟原點以下（含）的塊算著地（連通檢查的起點）
const HIT_SOUND := "res://assets/audio/destruction/wood_crack.wav"
const HOUSE_FALL_SOUND := "res://assets/audio/destruction/house_collapse.wav"
const SHAKE_RANGE := 25.0         # 離鏡頭超過這個距離（公尺）就不震
const KICK_COOLDOWN := 500        # 毫秒：同一塊碎塊被踢過之後，這段時間內不再踢

static var _mat: ShaderMaterial

var can_break := true             # 拆得掉（安全屋、掩體方塊、石頭不行，進 destructible 群組也是看這個）
var _layer := 1 | 16             # 碰撞層（make 設；樹是 1、不加 SOLID_LAYER，關碰撞物件時尼諾拉穿過）
var _xf: Array[Transform3D] = []  # 每塊在這棟裡的位置（相對原點）
var _size: Array[Vector3] = []
var _lv := PackedInt32Array()     # 等級：1、2 挨幾下倒，3 打不壞
var _hp := PackedInt32Array()     # 還要挨幾下（主機才看）
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
var _hide_queue: Array = []       # 等著實體停用形狀的塊編號（見 HIDE_PER_FRAME）
var _pending: Array = []          # 等它的塊都藏好才生的大碎塊：{m: 塊編號, from: 衝量的來源}（見 _merge）
var _grid := {}                   # 連通檢查用的鄰居表：格子（Vector3i）-> 蓋到這格的塊編號。第一次要用時建，塊不會動
const GRID := 1.6                 # 鄰居表的格子大小（公尺）
# ponytail: 一次鬆脫最多生 150 個碎塊（每個都是 RigidBody 加一個網格、一個形狀，一次生 1275 個要 70 毫秒的一幀）。
# 超過的那次鬆脫，塊照位置併成大塊（_merge：3 公尺的格子，併完還超過就格子加倍），碎塊總數還在上限內，每一塊都還在場上
const MAX_PIECES := 150
const MERGE_CELL := 3.0
# ponytail: 每停用一個形狀要 O(這棟的塊數) 的時間（1659 塊的大樓一個約 78 微秒），一次藏 1100 塊就卡一幀 110 毫秒。
# 鬆脫的塊分到每幀 HIDE_PER_FRAME 個藏（約 0.3 秒藏完）；大碎塊等它的塊都藏好才生，兩邊接著來，不會疊在一起
const HIDE_PER_FRAME := 64


## bricks：每塊 [Transform3D（相對這棟）, 尺寸 Vector3, 等級 int, 顏色 Color]（Greybox.bricks 切出來的）。
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
	t._mm.mesh = BoxMesh.new()
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
		t._hp.append(b[2])
		t._col.append(b[3])
		t._bb.append(xf * AABB(-size * 0.5, size))
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


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://toy_brick.gdshader")
	return _mat


## 拆（主機才算）：hit 收每塊的世界中心，回傳 true＝打到。打到的、等級 <= max_level、不是 3 的扣一下，扣到 0 鬆脫。
## 然後連通檢查：連不到地面的（懸空）也鬆脫。鬆脫的送 _break；有扣血但沒鬆脫的送 _hurt（各台抖一下）
func smash(hit: Callable, max_level: int, from: Vector3) -> void:
	if not multiplayer.is_server() or not can_break:
		return
	var n := _xf.size()
	var loose := _loose.duplicate()
	var fresh := PackedInt32Array()
	var hurt := false
	for i in n:
		if loose[i] == 1 or _lv[i] >= 3 or _lv[i] > max_level:
			continue
		if not hit.call(global_transform * _xf[i].origin):
			continue
		_hp[i] -= 1
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
			_break.rpc(fresh, PackedInt32Array(), from)
		else:
			_break.rpc(PackedInt32Array(), fresh, from)
	elif hurt:
		_hurt.rpc()


## 連不到地面的塊（loose 為 1 的不算）：從著地的塊（頂面在 BASE_TOP 以下，或等級 3）順著邊界框相接（放大 0.05）一路找，找不到的回傳。
## 只看鄰居表（格子 GRID 公尺，每塊只跟蓋到同一格的比）：第一次用時建一次（1659 塊約 5 毫秒）
func _unsupported(loose: PackedByteArray) -> PackedInt32Array:
	var n := _xf.size()
	if _grid.is_empty():
		for i in n:
			for c: Vector3i in _cells(_bb[i].grow(0.05)):
				if not _grid.has(c):
					_grid[c] = []
				_grid[c].append(i)
	var ok := PackedByteArray()
	ok.resize(n)
	var todo: Array[int] = []
	for i in n:
		if loose[i] == 0 and (_lv[i] == 3 or _bb[i].position.y <= BASE_TOP):
			ok[i] = 1
			todo.append(i)
	while not todo.is_empty():
		var a: int = todo.pop_back()
		var ga := _bb[a].grow(0.05)
		for c: Vector3i in _cells(ga):
			for j: int in _grid.get(c, []):
				if loose[j] == 0 and ok[j] == 0 and ga.intersects(_bb[j]):
					ok[j] = 1
					todo.append(j)
	var out := PackedInt32Array()
	for i in n:
		if loose[i] == 0 and ok[i] == 0:
			out.append(i)
	return out


## 鬆脫（每台一樣）：ids 每塊馬上生一個碎塊（塊藏起來、碎塊往外飛）；gone 是超過上限的，照位置併成大塊，
## 等它們的塊分幀藏好才生（_pending）。主機重烘導航（碎塊還沒停下，先不算進去）
@rpc("authority", "call_local", "reliable")
func _break(ids: PackedInt32Array, gone: PackedInt32Array, from: Vector3) -> void:
	_touched = true
	var at := Vector3.ZERO
	for i in ids:
		_loose[i] = 1
		at += global_transform * _xf[i].origin
		_hide_brick(i)
		_fling(_spawn(PackedInt32Array([i]), _xf[i], global_transform * _xf[i], true) as RigidBody3D, from)
	for i in gone:
		_loose[i] = 1
		at += global_transform * _xf[i].origin
		_hide_queue.append(i)
	for g: PackedInt32Array in _merge(gone):
		_pending.append({"m": g, "from": from})
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
func _spawn(mem: PackedInt32Array, local: Transform3D, xf: Transform3D, flying: bool) -> Node3D:
	var rel: Array = []
	var box := AABB()
	var vol := 0.0
	var lv := 3
	var inv := local.affine_inverse()
	for k in mem.size():
		var m := mem[k]
		var r := inv * _xf[m]
		rel.append(r)
		var b := r * AABB(-_size[m] * 0.5, _size[m])
		box = b if k == 0 else box.merge(b)
		vol += _size[m].x * _size[m].y * _size[m].z
		lv = mini(lv, _lv[m])
	_info[mem[0]] = {"m": mem, "rel": rel, "box": box, "vol": vol, "lv": lv}
	return _make(mem[0], flying, xf)


## 大碎塊：等它的塊都藏好了（_physics_process）才生。原點取塊中心的平均；只有一塊的照那塊的位置
func _spawn_group(mem: PackedInt32Array, from: Vector3) -> void:
	var local := _xf[mem[0]]
	if mem.size() > 1:
		var c := Vector3.ZERO
		for m in mem:
			c += _xf[m].origin
		local = Transform3D(Basis(), c / float(mem.size()))
	var rb := _spawn(mem, local, global_transform * local, true) as RigidBody3D
	_fling(rb, from)


## 往外飛：從 from 往碎塊的方向（水平），加一點往上，往前滾
func _fling(rb: RigidBody3D, from: Vector3) -> void:
	var d := rb.global_position - from
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
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
	for i in gone:
		_touched = true
		_loose[i] = 1
		_hide_brick(i)
	for k in ids.size():
		if _pieces.has(ids[k]):
			continue
		_touched = true
		_loose[ids[k]] = 1
		_hide_brick(ids[k])
		_spawn(PackedInt32Array([ids[k]]), _xf[ids[k]], xfs[k], false)


## 晚加入（大碎塊）：碎塊裡的塊和它現在的位置（直接到位、凍住）。原點照塊的平均算，跟主機一樣
@rpc("authority", "reliable")
func _resume_group(mem: PackedInt32Array, xf: Transform3D) -> void:
	_touched = true
	var c := Vector3.ZERO
	for m in mem:
		_loose[m] = 1
		_hide_queue.append(m)
		c += _xf[m].origin
	_spawn(mem, Transform3D(Basis(), c / float(mem.size())), xf, false)
	set_physics_process(true)


## 主機：晚加入的人連進來時呼叫（send_state_to）。先把排隊的藏完、等著生的生完，然後每個碎塊的現在位置：
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
	if not (st.ids as PackedInt32Array).is_empty():
		_resume.rpc_id(peer, st.ids, st.xfs, PackedInt32Array())


## 排隊中的藏完、等著生的照排隊的順序生完（主機補送前用，一次做完、不分幀）
func _flush() -> void:
	while not _hide_queue.is_empty():
		_hide_brick(_hide_queue.pop_front())
	while not _pending.is_empty():
		var p: Dictionary = _pending.pop_front()
		_spawn_group(p.m, p.from)
	set_physics_process(true)


## 新的一場（party.gd start、main.restore_terrain）：碎塊刪掉、每塊放回原位、血量回滿。碰撞層和群組由 set_on 管
@rpc("authority", "call_local", "reliable")
func restore() -> void:
	for n: Node3D in _pieces.values():
		n.queue_free()
	_pieces.clear()
	_info.clear()
	_age.clear()
	_kick_t.clear()
	_pending.clear()
	_hide_queue.clear()
	for i in _xf.size():
		_hp[i] = _lv[i]
		_loose[i] = 0
		_set_off(i, false)
		_mm.set_instance_transform(i, Transform3D(_xf[i].basis.scaled(_size[i]), _xf[i].origin))
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
	if not _info.has(key) and not _pending.is_empty():   # 大碎塊還在排隊：先生完
		_flush()
	var n: Node3D = _pieces.get(key)
	if n == null:
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


## 這塊的材質（子彈穿透用）：等級對應 ARMOR_GROUP；不能拆的沒有材質（照以前不穿）。shape 是碰撞形狀的編號（= 塊的編號）
func armor_of(shape: int) -> StringName:
	if not can_break or shape < 0 or shape >= _brick_of.size():
		return &""
	return ARMOR_GROUP[_lv[_brick_of[shape]] - 1]


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


## 每幀：先藏鬆脫的塊（分幀）、藏完的大碎塊生出來；主機再看碎塊睡著或飛滿 SETTLE_TIME 秒的，送 _settle（連同它的位置）
func _physics_process(delta: float) -> void:
	var k := 0
	while k < HIDE_PER_FRAME and not _hide_queue.is_empty():
		_hide_brick(_hide_queue.pop_front())
		k += 1
	while not _pending.is_empty() and _all_hidden(_pending[0].m):
		var p: Dictionary = _pending.pop_front()
		_spawn_group(p.m, p.from)
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
		# 凍在尼諾拉身體裡會把牠頂起來：等牠出來再凍；但最多等 SETTLE_TIME 的 3 倍，之後不管重疊直接凍
		var stuck: bool = _age[key] < SETTLE_TIME * 3.0 and _in_boss(n)
		if ((n as RigidBody3D).sleeping or _age[key] >= SETTLE_TIME) and not stuck:
			ids.append(key)
			xfs.append(n.global_transform)
	if not ids.is_empty():
		_settle.rpc(ids, xfs)
	if _need_bake and _idle() and not _has_flying():   # 這棟的碎塊全部停下來、形狀也藏完了：烘一次
		_need_bake = false
		_bake()
	if _idle() and not _has_flying():
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


## 沒有排隊要藏的，也沒有等著生的大碎塊
func _idle() -> bool:
	return _hide_queue.is_empty() and _pending.is_empty()


func _all_hidden(mem: PackedInt32Array) -> bool:
	for m in mem:
		if _off[m] == 0:
			return false
	return true


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


## 形狀停用／啟用：直接叫物理伺服器（CollisionShape3D.disabled 每次要 78 微秒，一棟大樓一拆就卡一幀）
func _set_off(i: int, off: bool) -> void:
	_off[i] = 1 if off else 0
	if _sidx[i] >= 0:
		PhysicsServer3D.body_set_shape_disabled(get_rid(), _sidx[i], off)


func _hide_brick(i: int) -> void:
	_set_off(i, true)
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
		n.add_to_group(ARMOR_GROUP[int(info.lv) - 1])
	var box: AABB = info.box
	var sh := BoxShape3D.new()
	sh.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = box.get_center()
	n.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = mem.size()
	for k in mem.size():
		var r: Transform3D = info.rel[k]
		mm.set_instance_transform(k, Transform3D(r.basis.scaled(_size[mem[k]]), r.origin))
		mm.set_instance_color(k, _col[mem[k]])
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
	get_parent().add_child(n)
	n.global_transform = xf
	_pieces[key] = n
	return n


## 碎塊停下來：飛的換成靜態的（同名、同位置），靜態的只移位置
func _freeze(key: int, xf: Transform3D) -> void:
	if not _info.has(key) and not _pending.is_empty():   # 大碎塊還在排隊：先生完才認得出它
		_flush()
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
	var cam := on.get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	# 從鏡頭往上找第一個有 add_shake 的（牛仔的鏡頭在 Head 底下，恐龍的在 CamPivot 底下）
	var who: Node = cam.get_parent()
	while who and not who.has_method(&"add_shake"):
		who = who.get_parent()
	if who == null:
		return 0.0
	var k: float = clampf(1.0 - cam.global_position.distance_to(at) / SHAKE_RANGE, 0.0, 1.0) * Settings.v.get(&"shake", 1.0)
	var amount: float = (0.08 if down else 0.03) * k
	who.add_shake(amount)
	if who.has_method(&"add_hitstop"):
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


## 炸藥爆炸（主機才算）：範圍內等級 1 的塊扣一下（一下就倒），等級 2、3 不受影響（草案 4.2 一般炸彈）。
## ponytail: 只看距離，不算中間有沒有牆擋住；方塊房子的牆互相擋住的話，爆炸會穿過去拆後面的等級 1 方塊
static func blast(world: Node3D, at: Vector3, radius: float) -> void:
	for w: Node in world.get_tree().get_nodes_in_group(&"destructible"):
		if w is ToyBuild:
			(w as ToyBuild).smash(func(p: Vector3) -> bool: return p.distance_to(at) < radius, 1, at)
