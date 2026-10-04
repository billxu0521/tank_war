extends SceneTree
## 長槍舉槍時左手的姿勢反算（ads_support_rot / ads_support_shift）：照影片，掌心貼著護木左側、
## 前臂往畫面左下後方出去。HandSupport 網格（blender/hands.py）裡：前臂方向 ARM、掌心朝 +Y（托護木時掌心朝上）。
##   godot --headless --path . --script tools/support_ads_pose.gd
const ARM := Vector3(-0.30, -0.70, 0.60)        # HandSupport 自己座標裡前臂往哪（hands.py 的 ARM_L 換成 Godot 軸）
## HandGrip 自己座標：前臂（HandGripArm 從手腕往 hands.py 的 ARM_R）、掌心朝 -X（握把在手的左邊）
const GRIP_ARM := Vector3(0.22, 0.55, 0.80)   # 實測：照 hands.py 推的軸向反了，用渲染對過的這個
const GRIP_PALM := Vector3(-1, 0, 0)
const WANT_ARM := Vector3(-0.55, -0.60, 0.58)   # 鏡頭座標：前臂往左下、往後
const WANT_PALM := Vector3(0.95, 0.25, 0.0)     # 鏡頭座標：掌心朝右（朝槍）
## 手的原點（握的那一點）要在父節點座標的哪裡：護木左側
const HOLD := {"shotgun": Vector3(-0.044, -0.016, -0.02), "rifle": Vector3(-0.024, -0.016, -0.10)}


static func frame(a: Vector3, p: Vector3) -> Basis:
	var x := a.normalized()
	var y := (p - x * p.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _initialize() -> void:
	for g: String in ["shotgun", "rifle"]:
		var w = load("res://cowboy/weapons/%s.tscn" % g).instantiate()
		var r_cam := frame(WANT_ARM, WANT_PALM) * frame(ARM, Vector3.UP).inverse()   # 手在鏡頭座標的朝向
		var r_ads := Basis.from_euler(w.ads_rotation)                              # 父節點（模型／槍管）舉槍時的朝向
		var local := r_ads.inverse() * r_cam
		var rest: Basis = w.support_hand.basis.orthonormalized()
		var rot := (local * rest.inverse()).get_euler()
		var shift: Vector3 = HOLD[g] - w.support_hand.origin
		print("%s ads_support_turn=0.0;ads_support_rot=Vector3(%.3f, %.3f, %.3f);ads_support_shift=Vector3(%.3f, %.3f, %.3f)" %
			[g, rot.x, rot.y, rot.z, shift.x, shift.y, shift.z])
		# 換彈時右手（HandGrip）：前臂往右下後方、掌心朝下（影片：手從右邊壓在機匣上，拇指推子彈）
		var r_hand := frame(Vector3(0.20, -0.95, 0.25), Vector3(-0.2, -0.9, -0.3)) * frame(GRIP_ARM, GRIP_PALM).inverse()
		var keep_now := Basis.from_euler(w.hip_rotation) * (w.grip_hand.basis as Basis).orthonormalized()
		var turn := (r_hand * keep_now.inverse()).get_euler()
		print("%s reload_hand_turn=Vector3(%.3f, %.3f, %.3f)" % [g, turn.x, turn.y, turn.z])
		w.free()
	quit()
