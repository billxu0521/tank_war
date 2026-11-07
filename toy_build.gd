class_name ToyBuild
extends StaticBody3D
## 玩具積木的一棟（docs/規劃/2026-11-08-玩具積木場景.md）：房子、掩體都是積木拼的。
## 一棟一個碰撞體、每塊一個 CollisionShape3D；畫面一個 MultiMesh，一次畫完。拆開鬆脫的塊變成 RigidBody3D 碎塊留在場上。
## 拆和碎塊停下來的位置都是主機算，其他台照 RPC 做（同 Destructible）。
##
## 節點名字由 arena_map.gd 依序取（Toy0、Toy1…），每台一樣，碎塊的名字「%s_P%d」接在後面，RPC 才找得到。
## 碎塊的飛行每台自己模擬，停下來以主機的位置為準（_settle），所以最後每台一樣。
##
## ponytail: 碎塊停下來的時間只看 4 秒或睡著，不做真的穩定判斷；停下來前各台位置可能不一樣，停下後才對齊
## ponytail: 子彈排除的是整棟不是單一塊（bullet.gd 的老問題）：同一發子彈穿過一塊，後面的塊也一起穿
## ponytail: 晚加入的人只補送鬆脫的塊，只挨一下沒倒的傷看不到（主機記得，他不記得）

const SETTLE_TIME := 4.0          # 碎塊飛出去之後幾秒就停下來（主機送 _settle）
const FALL_SPEED := 3.5           # 碎塊飛出去的初速（公尺／秒）
const MASS_PER_M3 := 40.0         # 碎塊質量：0.5 kg 加體積乘這個數
const ARMOR_GROUP := [&"plank", &"double_plank", &"metal"]   # 等級 1、2、3 的子彈穿透材質（bullet.gd ARMOR）
const BASE_TOP := 0.05            # 頂面在這棟原點以下（含）的塊算著地（連通檢查的起點）

static var _mat: ShaderMaterial

var can_break := true             # 拆得掉（安全屋、掩體方塊不行，進 destructible 群組也是看這個）
var _xf: Array[Transform3D] = []  # 每塊在這棟裡的位置（相對原點）
var _size: Array[Vector3] = []
var _lv := PackedInt32Array()     # 等級：1、2 挨幾下倒，3 打不壞
var _hp := PackedInt32Array()     # 還要挨幾下（主機才看）
var _col: Array[Color] = []
var _shape: Array[CollisionShape3D] = []
var _off := PackedByteArray()     # 形狀是不是停用了（拆掉的塊）
var _bb: Array[AABB] = []         # 每塊的邊界框（這棟的本地座標，連通檢查用）
var _mm: MultiMesh
var _pieces := {}                 # 鬆脫的塊編號 -> 碎塊節點（飛的時候是 RigidBody3D，停下來換成 StaticBody3D）
var _age := {}                    # 碎塊飛了多久（主機用）
var _touched := false             # 挨過打（鬆脫、或只挨一下），新的一場要還原
var _need_bake := false           # 有碎塊還在飛：停下來之後主機要烘一次導航
var _gone := {}                   # 鬆脫但沒生碎塊（一次超過 MAX_PIECES 的部分，直接藏起來）：編號 -> true
var _hide_queue: Array = []       # 等著實體停用形狀的塊編號（見 HIDE_PER_FRAME）
var _grid := {}                   # 連通檢查用的鄰居表：格子（Vector3i）-> 蓋到這格的塊編號。第一次要用時建，塊不會動
const GRID := 1.6                 # 鄰居表的格子大小（公尺）
# ponytail: 一次鬆脫最多生 300 個碎塊（每個都是 RigidBody 加一個網格、一個形狀，一次生 1275 個要 70 毫秒的一幀）。
# 超過的塊直接藏起來、不生碎塊（晚加入的人也照樣藏）。要真的一棟一棟飛，調大這個數、或改共用網格
const MAX_PIECES := 150
# ponytail: 每停用一個形狀要 O(這棟的塊數) 的時間（1659 塊的大樓一個約 78 微秒），一次藏 1100 塊就卡一幀 110 毫秒。
# 超過上限的塊邏輯上馬上算藏起來，實體的藏起來分到每幀 HIDE_PER_FRAME 個做（約 0.3 秒藏完）
const HIDE_PER_FRAME := 64


## bricks：每塊 [Transform3D（相對這棟）, 尺寸 Vector3, 等級 int, 顏色 Color]（Greybox.bricks 切出來的）。
## can_break = false：不進 destructible 群組（安全屋、掩體方塊）。
static func make(bricks: Array, can_break_ := true) -> ToyBuild:
	var t := ToyBuild.new()
	t.can_break = can_break_
	t.collision_layer = 1 | Fighter.SOLID_LAYER   # 同 _build_arena：建築要擋關碰撞物件的尼諾拉
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
		var sh := BoxShape3D.new()
		sh.size = size
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.transform = xf
		t.add_child(cs)
		t._shape.append(cs)
		t._off.append(0)
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
	var loose := PackedByteArray()
	loose.resize(n)
	for i in n:
		loose[i] = 1 if (_pieces.has(i) or _gone.has(i)) else 0
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
		_break.rpc(fresh.slice(0, MAX_PIECES), fresh.slice(MAX_PIECES), from)
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


## 鬆脫：每台拿掉碰撞、實例縮成 0，在同一個位置生碎塊、給衝量往外飛。主機重烘導航（碎塊還沒停下，先不算進去）
@rpc("authority", "call_local", "reliable")
func _break(ids: PackedInt32Array, gone: PackedInt32Array, from: Vector3) -> void:
	_touched = true
	for i in gone:
		_gone[i] = true
		_hide_queue.append(i)
	if not _hide_queue.is_empty():
		set_physics_process(true)
	var at := Vector3.ZERO
	for i in ids:
		var c := global_transform * _xf[i].origin
		at += c
		_hide_brick(i)
		var rb: RigidBody3D = _piece(i, true, global_transform * _xf[i]) as RigidBody3D
		var d := c - from
		d.y = 0.0
		d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		var dir := (d + Vector3.UP * 0.4).normalized()
		rb.apply_central_impulse(dir * FALL_SPEED * rb.mass)
		rb.angular_velocity = Vector3(d.z, 0.0, -d.x) * 4.0   # 往前滾
	at /= maxi(ids.size(), 1)
	Destructible.sfx(self, Destructible.HOUSE_FALL_SOUND, 80.0, at)
	Fx.dust_ring(get_parent(), Vector3(at.x, global_position.y, at.z), 4.0, 30, 5.0, 1.4)
	if multiplayer.is_server():
		set_physics_process(true)
		_need_bake = true   # 碎塊停下來才烘（烘的時候碎塊要已經是靜態的）


## 挨了一下沒倒：各台抖一下、播打擊聲（照 Destructible._smash_fx）
@rpc("authority", "call_local", "reliable")
func _hurt() -> void:
	_touched = true
	Destructible.hit_fx(self, global_position + Vector3.UP, false)


## 碎塊停下來（主機送，各台照做）：換成靜態的，放在主機算的位置。導航網格要讀得到，所以不留 RigidBody3D
@rpc("authority", "call_local", "reliable")
func _settle(ids: PackedInt32Array, xfs: Array) -> void:
	for k in ids.size():
		_freeze(ids[k], xfs[k])


## 晚加入：主機把鬆脫的塊和它們現在的位置補給他（直接到位、凍住、不播音效）
@rpc("authority", "reliable")
func _resume(ids: PackedInt32Array, xfs: Array, gone: PackedInt32Array) -> void:
	for i in gone:
		_touched = true
		_hide_brick(i)
		_gone[i] = true
	for k in ids.size():
		if _pieces.has(ids[k]):
			continue
		_touched = true
		_hide_brick(ids[k])
		_piece(ids[k], false, xfs[k])


## 新的一場（party.gd start）：碎塊刪掉、每塊放回原位、血量回滿。碰撞層和群組由 set_on 管
@rpc("authority", "call_local", "reliable")
func restore() -> void:
	for i in _pieces:
		_pieces[i].queue_free()
	_pieces.clear()
	_age.clear()
	for i in _xf.size():
		_hp[i] = _lv[i]
		_set_off(i, false)
		_mm.set_instance_transform(i, Transform3D(_xf[i].basis.scaled(_size[i]), _xf[i].origin))
	_gone.clear()
	_hide_queue.clear()
	_touched = false
	set_physics_process(false)


## 派對模式才看得到、拆得掉（arena_map.gd 的 set_party_house）：不是派對就整棟藏起來、碰撞和群組拿掉，碎塊也藏
func set_on(on: bool) -> void:
	visible = on
	collision_layer = (1 | Fighter.SOLID_LAYER) if on else 0
	if on and can_break:
		add_to_group(&"destructible")
	else:
		remove_from_group(&"destructible")
	for n: Node3D in _pieces.values():
		n.visible = on
		n.collision_layer = (1 | Fighter.SOLID_LAYER) if on else 0


## 挨過打沒有（新的一場要不要還原）
func has_damage() -> bool:
	return _touched


## 目前鬆脫的塊編號和碎塊現在的位置（晚加入補送用）
func loose_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _pieces:
		out.append(i)
	return out


## 藏起來沒生碎塊的塊（超過 MAX_PIECES 的那些）
func gone_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _gone:
		out.append(i)
	return out


func loose_xforms() -> Array:
	var out := []
	for i in _pieces:
		out.append((_pieces[i] as Node3D).global_transform)
	return out


## 這塊的材質（子彈穿透用）：等級對應 ARMOR_GROUP；不能拆的沒有材質（照以前不穿）。shape 是碰撞形狀的編號（= 塊的編號）
func armor_of(shape: int) -> StringName:
	if not can_break or shape < 0 or shape >= _lv.size():
		return &""
	return ARMOR_GROUP[_lv[shape] - 1]


## 測試用：塊現在還站著（沒鬆脫、沒被縮掉）、它的等級、剩幾下、它的世界中心
func is_standing(i: int) -> bool:
	return not _pieces.has(i) and _off[i] == 0


func level_of(i: int) -> int:
	return _lv[i]


func hp_of(i: int) -> int:
	return _hp[i]


func center_of(i: int) -> Vector3:
	return global_transform * _xf[i].origin


func brick_count() -> int:
	return _xf.size()


## 進場景樹時關掉每幀處理：只有主機在鬆脫後才開（_break），碎塊停下來就關
func _ready() -> void:
	set_physics_process(false)


## 碎塊的物理：主機每幀看一次，睡著或飛滿 SETTLE_TIME 秒的，送 _settle（連同它的位置）
func _physics_process(delta: float) -> void:
	var k := 0
	while k < HIDE_PER_FRAME and not _hide_queue.is_empty():
		_hide_brick(_hide_queue.pop_front())
		k += 1
	if not multiplayer.is_server():
		if _hide_queue.is_empty():
			set_physics_process(false)
		return
	var ids := PackedInt32Array()
	var xfs := []
	for i in _pieces:
		var n: Node3D = _pieces[i]
		if not n is RigidBody3D:
			continue
		_age[i] = _age.get(i, 0.0) + delta
		if (n as RigidBody3D).sleeping or _age[i] >= SETTLE_TIME:
			ids.append(i)
			xfs.append(n.global_transform)
	if not ids.is_empty():
		_settle.rpc(ids, xfs)
	if _need_bake and not _has_flying():   # 這棟的碎塊全部停下來了：烘一次
		_need_bake = false
		_bake()
	if not _has_flying() and _hide_queue.is_empty():
		set_physics_process(false)


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
	PhysicsServer3D.body_set_shape_disabled(get_rid(), i, off)


func _hide_brick(i: int) -> void:
	_set_off(i, true)
	_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## 碎塊節點：flying 是剛鬆脫、還在飛（RigidBody3D）；否則是靜態的（StaticBody3D）。名字每台一樣
func _piece(i: int, flying: bool, xf: Transform3D) -> Node3D:
	var n: Node3D = RigidBody3D.new() if flying else StaticBody3D.new()
	n.name = "%s_P%d" % [name, i]
	n.collision_layer = collision_layer   # 跟這棟一樣（派對房子藏起來時碎塊也藏、沒有碰撞）
	n.visible = visible
	n.collision_mask = 1
	n.add_to_group(&"toy_piece")
	if can_break:
		n.add_to_group(ARMOR_GROUP[_lv[i] - 1])
	var sh := BoxShape3D.new()
	sh.size = _size[i]
	var cs := CollisionShape3D.new()
	cs.shape = sh
	n.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(_size[i]), Vector3.ZERO))
	mm.set_instance_color(0, _col[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material()
	n.add_child(mmi)
	if flying:
		var s := _size[i]
		(n as RigidBody3D).mass = 0.5 + s.x * s.y * s.z * MASS_PER_M3
	get_parent().add_child(n)
	n.global_transform = xf
	_pieces[i] = n
	return n


## 碎塊停下來：飛的換成靜態的（同名、同位置），靜態的只移位置
func _freeze(i: int, xf: Transform3D) -> void:
	var old: Node3D = _pieces.get(i)
	_age.erase(i)
	if old == null:
		_piece(i, false, xf)
		return
	if old is StaticBody3D:
		old.global_transform = xf
		return
	old.name = old.name + "~"   # 讓出名字，新的才能用同一個
	old.queue_free()
	_piece(i, false, xf)


## 碎塊停下來後要重烘導航（碎塊會擋恐龍的路）：主機在這棟的碎塊全部停下來之後呼叫一次
func _bake() -> void:
	var g := get_tree().get_first_node_in_group(&"match")
	if g and g.has_method(&"bake_nav"):
		g.bake_nav(true)
