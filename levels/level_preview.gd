class_name LevelPreview
extends RefCounted
## 編輯器裡 LevelItem 長什麼樣：照 main.gd 蓋東西的擺法放一樣的模型（只有外觀，沒有碰撞、門、燈）。
## 位置、朝向、縮放跟著 LevelItem 節點本身，這裡只放「相對於節點」的零件。

const Main := preload("res://main.gd")


static func _add(root: Node3D, name: StringName, pos := Vector3.ZERO, scale := Vector3.ONE, basis := Basis()) -> void:
	var m: Mesh = Main.meshes().get(name)
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = Transform3D(basis.scaled(scale), pos)
	root.add_child(mi)


## 半透明的色塊：整平區（藍色圓盤）、麥田（黃色方塊）這種看不見的東西，還有擺設檢查的紅色標記
static func zone(root: Node3D, m: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	root.add_child(mi)
	return mi


static func build(it: LevelItem, root: Node3D) -> void:
	var sc := it.scale
	match it.kind:
		"flat":
			var c := CylinderMesh.new()
			c.top_radius = it.amount
			c.bottom_radius = it.amount
			c.height = 0.1
			zone(root, c, Color(0.3, 0.5, 1.0, 0.25))
		"wheat":
			var b := BoxMesh.new()
			b.size = Vector3(it.amount, 0.1, it.amount)
			zone(root, b, Color(1.0, 0.85, 0.3, 0.3))
		"barn":
			var s := it.size / Main.BARN_BASE
			_add(root, &"Barn", Vector3.ZERO, s)
			_add(root, &"BarnRoof", Vector3(0, it.size.y, 0), Vector3(s.x, s.x, s.z))
		"house", "shop":
			_add(root, it.variant)
		"water_tower":
			_add(root, &"WaterTower")
		"road":
			var b := BoxMesh.new()
			b.size = Vector3(it.size.x, 0.1, it.size.z)
			zone(root, b, Color(0.6, 0.45, 0.3, 0.35))
		"silo":
			_add(root, &"SiloBody", Vector3.ZERO, Vector3(1, it.amount / Main.SILO_BASE_H, 1))
			_add(root, &"SiloDome", Vector3(0, it.amount, 0))
		"fence":
			var n := maxi(ceili(it.amount / Main.FENCE_SEG), 1)
			var seg := it.amount / n
			for i in n:
				_add(root, &"FenceRail", Vector3(-it.amount * 0.5 + (i + 0.5) * seg, 0, 0), Vector3(seg / Main.FENCE_SEG, 1, 1))
			_add(root, &"FencePost", Vector3(it.amount * 0.5, 0, 0))
		"gate":
			_add(root, &"GatePost")
			var leaf := Main.gate_leaf(it.amount, it.flag)
			_add(root, &"FenceGate", leaf.origin, Vector3.ONE, leaf.basis)
		"hay_bale":
			_add(root, &"HayBale", Vector3(0, Main.HAY_BALE_R, 0), Vector3.ONE, Basis(Vector3.BACK, PI * 0.5))
		"kit", "prop":
			_add(root, it.variant)
		"tree":
			_add(root, it.variant, Vector3(0, -0.3 / maxf(sc.y, 0.01), 0))
		"rock":
			_add(root, it.variant, Vector3(0, -0.15, 0))
		"bush":
			_add(root, &"Bush", Vector3(0, -0.15 / maxf(sc.y, 0.01), 0))
		"windmill":
			_add(root, &"Windmill")
			_add(root, &"WindmillRotor", Main.WINDMILL_HUB)
		"hay_shed":
			_add(root, &"HayShed")
			_add(root, &"Lantern", Main.SHED_LANTERN)
		"hitch":
			_add(root, &"HitchRail")
		"wheel":
			_add(root, &"Wheel", Main.WHEEL_POSE.origin, Vector3.ONE, Main.WHEEL_POSE.basis)
