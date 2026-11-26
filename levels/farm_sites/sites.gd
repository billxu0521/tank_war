extends RefCounted

# 世界 X / Z；樓面局部原點在 p01 左上角，+u / +v 對應局部 +X / +Z。
const GRAIN := {"center": Vector2(28.5, -46.5), "yaw": -45.0, "size": Vector2(12, 12)}
const REPAIR := {"center": Vector2(-71, -29), "yaw": 175.0, "size": Vector2(12, 8)}

static func placement(site: Dictionary) -> Transform3D:
	var rotation := Basis(Vector3.UP, deg_to_rad(site.yaw))
	var center: Vector2 = site.center
	var size: Vector2 = site.size
	var half_floor := Vector3(size.x, 0, size.y) * 0.5
	return Transform3D(rotation, Vector3(center.x, 0, center.y) - rotation * half_floor)
