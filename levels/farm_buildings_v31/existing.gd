extends StaticBody3D
## 保留原有特殊互動節點的路徑，將同一段的顯示和碰撞交同一個開關。
var shapes:Array[CollisionShape3D]=[]
var visuals:Array[Node3D]=[]
var present:=true
func capture(n:Node) -> void:
	if n is CollisionShape3D:
		if not n.disabled and not shapes.has(n): shapes.append(n)
	elif n is GeometryInstance3D and n.visible:
		if not visuals.has(n): visuals.append(n)
	for child in n.get_children(): capture(child)

func set_present(value:bool) -> void:
	present=value
	for v in visuals: v.visible=value
	for shape in shapes: shape.set_deferred("disabled",not value)

