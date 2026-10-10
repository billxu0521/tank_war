class_name OilLantern
extends StaticBody3D
## 油燈：亮著的吊燈（models/kits.glb 的 Lantern，原點在頂上的掛鉤）。
## 被子彈打中（或被爆炸、被旁邊的火燒到）就破掉：玻璃碎片噴出來，燈油潑到正下方的地上燒起來（OilFire）。
## 子彈在每台電腦上都會飛、都會打中，所以每台各自破、各自燒，不用另外同步

const HEIGHT := 0.48        # 燈從掛鉤到底座多高（kit.py 的 lantern_parts）
const SPLASH := 0.3         # 公尺：燈油往打中的方向噴多遠（破的地方不是正下方）

var broken := false
var _mesh: MeshInstance3D
var _light: OmniLight3D


## 擺一盞油燈。hang = true：at 是掛鉤；false：放在地上（at 是地面）
static func place(parent: Node3D, mesh: Mesh, at: Vector3, hang := true) -> OilLantern:
	var l := OilLantern.new()
	l._mesh = MeshInstance3D.new()
	l._mesh.mesh = mesh
	l.add_child(l._mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, HEIGHT, 0.2)    # 比模型略大一點：燈很小，子彈要打得到
	shape.shape = box
	shape.position = Vector3.DOWN * HEIGHT * 0.5
	l.add_child(shape)
	l._light = OmniLight3D.new()
	l._light.light_color = Color(1.0, 0.72, 0.42)
	l._light.light_energy = 0.8
	l._light.omni_range = 5.0
	l._light.shadow_enabled = false
	l._light.position = Vector3.DOWN * 0.29   # 玻璃罩中間
	l._light.add_to_group(&"period_lamp")   # 時段調亮度（period.gd）
	l.add_child(l._light)
	parent.add_child(l)
	l.global_position = at if hang else at + Vector3.UP * HEIGHT
	return l


## 模型上做死的提燈（2026-10-10 使用者：所有光源燈都要打得破、打破會燒）：繫馬柱、穀倉、農舍、店面的燈原本是建築模型的一部分。
## 載入時把那幾盞從模型上挖掉（網格是共用的，挖一次全場都沒了），每個擺出來的建築在原位掛一盞真的油燈。
## 位置：模型座標裡燈罩的大概中心（照 blender/kit.py、props.py、house.py、town.py 換算），再用附近發光面的中心校準
const BAKED := {
	&"HitchRail": [Vector3(0, 1.8, 0)],
	&"Barn": [Vector3(0, 3.0, 0.3), Vector3(-6.3, 1.05, 3.45)],          # 閣樓下吊的、工作台上的
	&"House1": [Vector3(-0.9, 3.0, 4.2), Vector3(-1.65, 1.5, 1.8)],      # 門廊吊的、屋裡桌上的
	&"House2": [Vector3(-0.9, 3.0, 4.2), Vector3(-1.65, 1.5, 1.8)],
	&"House3": [Vector3(0.9, 2.7, 4.2), Vector3(-1.65, 1.5, 1.8)],
	&"Saloon": [Vector3(0, 4.2, 0)], &"Store": [Vector3(0, 3.3, 0)], &"Sheriff": [Vector3(0, 3.3, 0)],
}
const LIT_MATS := ["h_lit", "p_lamp"]
const GLASS_TO_HOOK := 0.29   # 這支的油燈：燈罩中心在掛鉤下面多少


## main.gd 蓋完場景後叫：挖掉模型上的燈、在每個建築的原位掛油燈（伺服器也要：子彈在每台都會打到燈）
static func replace_baked(arena: Node, lantern_mesh: Mesh, meshes: Dictionary) -> void:
	for name: StringName in BAKED:
		var mesh: ArrayMesh = meshes.get(name)
		if mesh and not mesh.has_meta(&"baked_lanterns"):
			mesh.set_meta(&"baked_lanterns", _strip(mesh, BAKED[name]))
	for mi: MeshInstance3D in arena.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh and mi.mesh.has_meta(&"baked_lanterns"):
			for c: Vector3 in mi.mesh.get_meta(&"baked_lanterns"):
				place(arena, lantern_mesh, mi.global_transform * c + Vector3.UP * GLASS_TO_HOOK)


## 校準每盞燈罩的中心，把燈（罩、框、底座、屋簷）那一小塊的三角形全挖掉，掛燈的繩子和鉤子留著。回傳校準後的中心
static func _strip(mesh: ArrayMesh, approx: Array) -> Array[Vector3]:
	var centers: Array[Vector3] = []
	for c0: Vector3 in approx:
		var sum := Vector3.ZERO
		var n := 0
		for i in mesh.get_surface_count():
			if not LIT_MATS.has(String(mesh.surface_get_material(i).resource_name)):
				continue
			for c: Vector3 in _centroids(mesh.surface_get_arrays(i)):
				if c.distance_to(c0) < 0.45:
					sum += c
					n += 1
		centers.append(sum / n if n > 0 else c0)
	var surfaces := []
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var cs := _centroids(a)
		var keep := PackedInt32Array()
		for t in cs.size():
			if not centers.any(func(c: Vector3) -> bool: return _in_lantern(cs[t] - c)):
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		a[Mesh.ARRAY_INDEX] = keep
		surfaces.append([a, mesh.surface_get_material(i), mesh.surface_get_name(i)])
	mesh.clear_surfaces()
	for s: Array in surfaces:
		if (s[0][Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s[0])
		mesh.surface_set_material(mesh.get_surface_count() - 1, s[1])
		mesh.surface_set_name(mesh.get_surface_count() - 1, s[2])
	return centers


## 燈罩中心算起：左右前後 0.2、往下 0.3（底座）、往上 0.25（屋簷、頂蓋；再上面的繩子和鉤子留著）
static func _in_lantern(d: Vector3) -> bool:
	return absf(d.x) < 0.2 and absf(d.z) < 0.2 and d.y > -0.3 and d.y < 0.25


static func _centroids(a: Array) -> PackedVector3Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	for t in range(0, idx.size(), 3):
		out.append((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0)
	return out


func _ready() -> void:
	add_to_group(&"oil_lantern")


## 被打中：from_dir 是子彈飛來的方向（燈油往那邊潑），by 是誰打的
func on_shot(at: Vector3, by: Node, from_dir := Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	var world := get_parent() as Node3D
	var center := global_position + Vector3.DOWN * 0.29
	# 玻璃碎片：亮黃的小碎塊往外噴（Fx 的著彈碎屑換顏色）、一閃
	Fx.hit(world, center, -from_dir if from_dir != Vector3.ZERO else Vector3.UP, &"wood")
	Fx.burst(world, SphereMesh.new(), Color(1.0, 0.8, 0.4, 0.9), center, Vector3.ONE * 0.2, Vector3.ONE * 1.2, 0.15)
	# 燈油落到地上：從燈往下（往子彈的方向偏一點）打一條線找地面
	var down := center + Vector3(from_dir.x, 0, from_dir.z).normalized() * SPLASH if from_dir != Vector3.ZERO else center
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(down + Vector3.UP * 0.1, down + Vector3.DOWN * 20.0)
	ray.exclude = [get_rid()]
	var hit := space.intersect_ray(ray)
	var ground: Vector3 = hit.position if not hit.is_empty() else Vector3(down.x, center.y - HEIGHT, down.z)
	OilFire.spill(world, ground, by)
	# 燈本身掉下去不見（低面數的燈罩碎了）
	_mesh.visible = false
	_light.visible = false
	collision_layer = 0
