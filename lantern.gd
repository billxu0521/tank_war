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
	l.add_child(l._light)
	parent.add_child(l)
	l.global_position = at if hang else at + Vector3.UP * HEIGHT
	return l


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
