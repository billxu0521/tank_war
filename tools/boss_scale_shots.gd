extends SceneTree
## 尼諾拉放大後的拍照（dino_height，boss.gd 的 GROW）：派對（灰盒）地圖上，拍四張——
##   side.png：側面，旁邊站一個牛仔（比例）；house.png：站在房子前面（比房子大多少）；
##   third.png：恐龍自己的第三人稱鏡頭；cowboy.png：牛仔第一人稱看恐龍（從 14 公尺外）。
## 恐龍和牛仔都先凍住，只拍不動。存到 OUT：
##   OUT=/path/to/folder godot --path . --resolution 1280x720 --script tools/boss_scale_shots.gd

var _f := 0
var _m: Node
var _boss: Node3D
var _cow: Node3D
var _shot := 0

func _initialize() -> void:
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_m._offline = true
		_m._enter_game("test")
	if _f == 3:
		_m.get_node(^"UI").visible = false   # 結算畫面、準心和血條都拿掉，只拍場景
		_cow = _m._add_player(_m.COWBOY, 2)
		_boss = _m.spawn_boss()
		_boss.set_physics_process(false)
		_cow.set_physics_process(false)
	if _f < 20:
		return false
	if _f == 20:
		_place_side()
		return false
	if _f < 30:
		return false
	if _f == 30:
		_snap("side")
		_place_house()
		return false
	if _f < 40:
		return false
	if _f == 40:
		_snap("house")
		_place_third()
		return false
	if _f < 50:
		return false
	if _f == 50:
		_snap("third")
		_place_cowboy_view()
		return false
	if _f < 60:
		return false
	if _f == 60:
		_snap("cowboy")
		quit()
		return true
	return false

## 恐龍站在地圖中央附近一塊平地（離房子遠），牛仔在它右邊 9 公尺；鏡頭在側面 30 公尺
func _place_side() -> void:
	var at := _flat_spot()
	_boss.global_position = at
	_boss.rotation.y = 0.0
	_cow.global_position = _m._on_ground(Vector3(at.x, 0, at.z + 12.0))   # 恐龍的尾巴那一側，鏡頭看得到
	_cow.rotation.y = -PI * 0.5   # 面向 +X（鏡頭那邊）
	_cam_at(at + Vector3(28, 3.0, 0), at + Vector3(0, 1.0, 0))

## 恐龍站在一棟灰盒房子正前方 10 公尺，面向房子；鏡頭斜上方
func _place_house() -> void:
	var rec: Dictionary = {}
	for r: Dictionary in _m.map._level:
		if r.kind == &"gb_house" and not r.big and r.size.x >= 10.0:
			rec = r
			break
	var yaw: float = rec.yaw
	var front := Basis(Vector3.UP, yaw) * Vector3(0, 0, rec.size.z * 0.5 + 10.0)
	var p: Vector3 = rec.pos + front
	var at: Vector3 = _m._on_ground(Vector3(p.x, _boss.LIFT, p.z))
	_boss.global_position = at
	_boss.rotation.y = yaw
	_cow.global_position = _m._on_ground(Vector3(at.x + 6.0, 0, at.z))
	_cow.rotation.y = 0.0
	var mid: Vector3 = (at + _m._on_ground(Vector3(rec.pos.x, 0, rec.pos.z))) * 0.5 + Vector3(0, 2.5, 0)
	_cam_at(mid + Vector3(22, 9, 22), mid)

## 恐龍自己的第三人稱：用它的 CamPivot 鏡頭（回到平地）
func _place_third() -> void:
	var at := _flat_spot()
	_boss.global_position = at
	_boss.rotation.y = 0.0
	_cow.global_position = _m._on_ground(Vector3(at.x + 9.0, 0, at.z + 4.0))
	var cam: Camera3D = _boss.get_node(^"CamPivot/Camera3D")
	cam.current = true
	_boss.get_node(^"CamPivot").rotation.x = _boss.CAM_BASE

## 牛仔第一人稱：在恐龍周圍 12～25 公尺的圓上，挑一個地面跟恐龍腳下差不多高（3 公尺內）、眼睛（1.7 公尺）到恐龍之間沒有東西擋的點。
## 不用牛仔自己的 Head/Camera3D（身體和槍會擋鏡頭），另外放一台鏡頭在眼睛的位置，牛仔模型先藏起來
func _place_cowboy_view() -> void:
	var at := _flat_spot()
	_boss.global_position = at
	_boss.rotation.y = 0.0
	var space := _boss.get_world_3d().direct_space_state
	var ex := [_boss.get_rid(), _cow.get_rid()]
	var target := at + Vector3(0, 1.0, 0)
	var ground: float = at.y - _boss.LIFT
	var eye := target
	var found := false
	for r in [12.0, 16.0, 20.0, 25.0]:   # 由近到遠，第一個視線通的點
		for k in 36:
			var a := TAU * float(k) / 36.0
			var x: float = at.x + sin(a) * r
			var z: float = at.z + cos(a) * r
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -100, z), 1, ex))
			if hit.is_empty() or absf(hit.position.y - ground) > 3.0:
				continue
			var e: Vector3 = hit.position + Vector3(0, 1.7, 0)
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(e, target, 1, ex)).is_empty():
				eye = e
				found = true
				break
		if found:
			break
	if not found:
		push_error("25 公尺內找不到看得到恐龍的地方，牛仔第一人稱照原點拍")
	_cow.visible = false
	_cam_at(eye, at + Vector3(0, 1.0, 0))

func _cam_at(from: Vector3, to: Vector3) -> void:
	var cam := root.get_node_or_null(^"ShotCam") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		cam.fov = 50
		root.add_child(cam)
	cam.current = true
	cam.look_at_from_position(from, to)

func _snap(name: String) -> void:
	var path := OS.get_environment("OUT") + "/%s.png" % name
	root.get_viewport().get_texture().get_image().save_png(path)
	print("存 ", path)

## 找一塊平、四周 16 公尺內沒有樹幹和房子的地方（射線打地面）
func _flat_spot() -> Vector3:
	var space := _boss.get_world_3d().direct_space_state
	var ex := [_boss.get_rid(), _cow.get_rid()]
	for ring in range(0, 90, 6):
		for k in range(maxi(1, ring / 3)):
			var a := TAU * float(k) / float(maxi(1, ring / 3))
			var x := sin(a) * ring
			var z := cos(a) * ring
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -100, z), 1, ex))
			if hit.is_empty() or hit.normal.y < 0.99:
				continue
			var g: float = hit.position.y
			var ok := true
			for dir in 12:
				var d := Vector3(sin(TAU * dir / 12.0), 0, cos(TAU * dir / 12.0))
				for hgt in [1.5, 6.0]:
					var o := Vector3(x, g + hgt, z)
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 16.0, 1, ex)):
						ok = false
			if ok:
				return Vector3(x, g + _boss.LIFT, z)
	push_error("附近找不到空地，照原點拍")
	return Vector3(0, _boss.LIFT, 0)
