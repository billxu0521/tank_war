extends SceneTree
## 第一人稱武器的姿勢截圖：開沙盒，拿出第 SLOT 把（1 起算），拍「拿著、舉槍瞄、換彈的幾個時刻、開槍」，存到 OUT。
## SET="hip_rotation=Vector3(1,0,0);grip_hand=Transform3D(...)"：拍之前臨時改這把槍的參數（Godot 的寫法，分號隔開），調姿勢不用一直改場景檔
## 另外認 hip_position（腰射位置＝場景根節點位置）和 hip_fov / ads_fov（Viewmodel 的鏡頭視角）
##   SLOT=4 OUT=/tmp/pose godot --path . --resolution 1280x720 --script tools/viewmodel_shots.gd

var _f := 0
var _t := -1.0
var m: Node
var vm: Viewmodel
var _n := 0
var MARKS := [[0.0, "hip"], [1.05, "ads"], [1.6, "reload_25"], [2.0, "reload_50"], [2.7, "reload_75"], [3.4, "fire"]]
## RELOAD_AT=2.3：換彈那張（reload_50）改在這個時間拍——三把槍換彈節奏不同，挑「塞子彈」那一刻跟影片比


func _initialize() -> void:
	if OS.get_environment("RELOAD_AT") != "":
		MARKS[3][0] = float(OS.get_environment("RELOAD_AT"))
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _process(d: float) -> bool:
	_f += 1
	if _f == 5:
		m._on_sandbox_pressed()
	if _f == 60:
		vm = m.players.get_node(^"1").viewmodel
		vm.switch_weapon(int(OS.get_environment("SLOT")) - 1 if OS.get_environment("SLOT") != "" else 0)
		for kv in OS.get_environment("SET").split(";", false):
			var k := kv.get_slice("=", 0).strip_edges()
			if k == "hip_position":   # 腰射位置是場景根節點的位置，開場時記在 Viewmodel 裡
				vm._hip_positions[vm._index] = str_to_var(kv.substr(kv.find("=") + 1))
				continue
			if k == "hip_fov" or k == "ads_fov":
				vm.set(k, str_to_var(kv.substr(kv.find("=") + 1)))
				continue
			vm.weapon.set(k, str_to_var(kv.substr(kv.find("=") + 1)))
			if k == "grip_hand" or k == "support_hand":
				var hand := vm.weapon.find_child("HandGrip" if k == "grip_hand" else "HandSupport", true, false) as Node3D
				if hand:
					hand.transform = vm.weapon.get(k)
		# 不要在這裡重設 _rest_rot：這時模型的角度已經加上腰射角度，拿它當靜止姿勢，腰射角度會算兩次、舉槍時也歪著
	if _f > 60:
		m.menu.visible = false
		for n in OS.get_environment("HIDE").split(",", false):   # HIDE=HandGripArm,HandSupport：藏起來，查畫面上那塊是誰
			for c in vm.weapon.find_children(n, "", true, false):
				(c as Node3D).visible = false
		# 視角固定朝前：滑鼠、沙盒的東西會把鏡頭轉走，拍到天空或地面就不能跟影片比（開槍那張要看後座的抬頭，不鎖）
		if _n < MARKS.size() - 1:
			var me := m.players.get_node(^"1") as Node3D
			me.rotation.y = 0.0
			me.head.rotation.x = 0.0
	if _f == 140:
		_t = 0.0
	if _t < 0.0:
		return false
	_t += d
	var w := vm.weapon
	vm.ads = 1.0 if _t >= 0.5 and _t < 1.1 else (0.0 if _t >= 1.1 else vm.ads)
	if _t >= 1.15 and not vm._reloading and w.mag == w.capacity and _n == 2:
		w.mag = 0
		w.reserve = maxi(w.reserve, w.capacity)   # 備彈給滿：只給一發的話換彈很快就結束，拍不到換彈中的姿勢
		vm.try_reload()
	if _t >= 3.2 and _n == 5:
		vm._fire_cooldown = 0.0
		if w.mag == 0:
			w.mag = 1
		vm.try_fire()
	if _n < MARKS.size() and _t >= MARKS[_n][0] + (0.05 if MARKS[_n][1] == "fire" else 0.0):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%d_%s.png" % [_n, MARKS[_n][1]])
		if OS.get_environment("PROBE") != "" and w.muzzle != Vector3.ZERO:   # 槍口實際投影到畫面哪裡（對 viewmodel_fit.gd 的算法用）
			var cam := root.get_viewport().get_camera_3d()
			var mp := cam.unproject_position(w._model.to_global(w.muzzle))
			var vs := root.get_viewport().get_visible_rect().size
			if OS.get_environment("GAP") != "":   # 手到槍的最近距離：> 幾 mm 就是沒握到（手浮在槍外）
				var gp := PackedVector3Array()   # 槍的每個零件（散彈的槍管、步槍的拉桿是分開的網格）
				for gun in w._model.find_children("*", "MeshInstance3D", true, false):
					if gun.name.begins_with("Hand") or not gun.is_visible_in_tree():
						continue
					for v in (gun as MeshInstance3D).mesh.get_faces():
						gp.append(gun.to_global(v))
				for hn in [w._grip, w._support, w._load_hand]:
					if hn and hn.is_visible_in_tree() and hn is MeshInstance3D:
						var best := 1e9
						var hv: PackedVector3Array = (hn as MeshInstance3D).mesh.get_faces()
						for i in range(0, hv.size(), 6):
							var q: Vector3 = (hn as MeshInstance3D).to_global(hv[i])
							for j in range(0, gp.size(), 3):
								best = minf(best, q.distance_squared_to(gp[j]))
						print("GAP %s %s 到槍最近 %.1f mm" % [MARKS[_n][1], hn.name, sqrt(best) * 1000.0])
			if w._grip:
				for c in w._grip.get_children():
					var ab := (c as MeshInstance3D).get_aabb()
					var p0 := cam.unproject_position((c as Node3D).to_global(ab.position))
					var p1 := cam.unproject_position((c as Node3D).to_global(ab.end))
					print("PROBE %s 握槍手的子節點 %s rot %s 畫面 %s → %s" % [MARKS[_n][1], c.name, c.rotation, p0, p1])
				var gab := (w._grip as MeshInstance3D).get_aabb()
				print("PROBE %s 握槍手本身 畫面 %s → %s 網格 %s" % [MARKS[_n][1], cam.unproject_position(w._grip.to_global(gab.position)), cam.unproject_position(w._grip.to_global(gab.end)), gab.size])
			if w._support:
				var sp := cam.unproject_position(w._support.global_position)
				print("PROBE %s 左手 (%.0f, %.0f) visible %s" % [MARKS[_n][1], sp.x, sp.y, w._support.is_visible_in_tree()])
			var far := cam.unproject_position(w._model.to_global(w.muzzle + Vector3(0, 0, -20.0)))   # 槍管往前 20 m 那一點：槍管實際指的地方
			print("PROBE %s 槍管指向 (%.0f, %.0f) 畫面中心 (%.0f, %.0f)" % [MARKS[_n][1], far.x, far.y, vs.x / 2, vs.y / 2])
			print("PROBE %s 槍口 (%.4f, %.4f) fov %.1f 槍 %s 模型 %s %s cam->weapon %s" % [MARKS[_n][1], (mp.x - vs.x / 2) / vs.y, (mp.y - vs.y / 2) / vs.y,
				cam.fov, w.position, w._model.position, w._model.rotation, cam.global_transform.affine_inverse() * w.global_position])
		var me := m.players.get_node(^"1") as Node3D
		print("%s 抬頭 %.1f 度 手上那支 %s" % [MARKS[_n][1], rad_to_deg(me.head.rotation.x), w._hand_round.visible if w._hand_round else "-"])
		_n += 1
	return _n >= MARKS.size()
