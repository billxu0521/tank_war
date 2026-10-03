extends SceneTree
## 場地指紋：把整個場地蓋出來的東西（每個模型、每個碰撞形狀、每叢灌木麥子、地形高度、出生點避開的範圍……）
## 全部寫成一行一行的文字，排序後存檔。重構「怎麼蓋場地」的程式之前先存一份，改完再存一份，兩份一模一樣才算沒改壞。
##   OUT=/tmp/before.txt godot --headless --path . --script tools/level_fingerprint.gd

var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var m: Node = load("res://main.tscn").instantiate()
		root.add_child(m)
	if _f == 3:
		var m: Node = root.get_child(root.get_child_count() - 1)
		var lines: PackedStringArray = []
		for n in m.get_node(^"Arena").find_children("*", "", true, false):
			var t := ""
			if n is Node3D:
				t = _xf((n as Node3D).global_transform)
			if n is MeshInstance3D and n.mesh:
				if n.mesh.resource_name.ends_with("WindmillRotor"):
					t = str((n as Node3D).global_position.snapped(Vector3.ONE * 0.001))   # 葉輪一直在轉，只比位置
				lines.append("mesh %s %s %s" % [n.mesh.resource_name, n.name if n.name.begins_with("Door") else "", t])
			elif n is CollisionShape3D and n.shape:
				var s: Shape3D = n.shape
				var d := ""
				if s is BoxShape3D:
					d = str((s as BoxShape3D).size.snapped(Vector3.ONE * 0.001))
				elif s is CylinderShape3D:
					d = "%.3f %.3f" % [s.radius, s.height]
				elif s is ConcavePolygonShape3D:
					d = str(s.get_faces().size())
				elif s is ConvexPolygonShape3D:
					d = str(s.points.size())
				lines.append("shape %s %s %s" % [s.get_class(), d, t])
			elif n is MultiMeshInstance3D and n.multimesh:
				var mm: MultiMesh = n.multimesh
				var sum := Vector3.ZERO
				for i in mm.instance_count:
					sum += mm.get_instance_transform(i).origin
				lines.append("multimesh %s %d %s" % [mm.mesh.resource_name if mm.mesh else "", mm.instance_count, sum.snapped(Vector3.ONE * 0.01)])
			elif n is Light3D:
				lines.append("light %s" % t)
		var h := 0.0
		for i in 200:
			h += m._terrain.height(-90.0 + i * 0.9, -80.0 + i * 0.8)
		lines.append("terrain %.3f" % h)
		for r: Rect2 in m._blocked:
			lines.append("blocked %s %s" % [r.position.snapped(Vector2.ONE * 0.001), r.size.snapped(Vector2.ONE * 0.001)])
		lines.append("bushes %d" % m._bushes.size())
		for r: Rect2 in m._wheat_fields:
			lines.append("wheat %s" % str(r))
		lines.sort()
		var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		print("fingerprint lines: ", lines.size())
		quit()
	return false


func _xf(t: Transform3D) -> String:
	return "%s %s %s %s" % [t.origin.snapped(Vector3.ONE * 0.001), t.basis.x.snapped(Vector3.ONE * 0.001),
		t.basis.y.snapped(Vector3.ONE * 0.001), t.basis.z.snapped(Vector3.ONE * 0.001)]
