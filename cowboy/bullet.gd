extends Node3D
class_name Bullet
## 會飛、會掉的子彈（Hunt 1896 起全部武器都是這樣）。
## 每幀用一小段射線掃過這一幀的位移，不靠碰撞區域——子彈一幀跑三四公尺，用區域會直接穿過人。
## 以前坦克的砲彈（shell.gd）也是這招。
##
## 開槍那台電腦上的子彈才會扣血：打中了照舊請主機代扣（Cowboy.deal_damage）。
## 其他人畫面上的是 visual_only，一樣會飛會掉、會噴火花，但不扣血。
## ponytail: 兩邊各飛各的，不同步位置。彈道是固定的拋物線，起點和方向一樣就會長得一樣。

const GRAVITY := 9.8
## 從鏡頭中心出發，前幾公尺不畫，不然第一幀整條曳光糊在自己臉上
const SHOW_AFTER := 3.0
const STREAK_LENGTH := 1.5

var origin := Vector3.ZERO
var vel := Vector3.ZERO
var shooter: Node          # Cowboy。可能在子彈飛行中死掉被砍，用前要檢查
var weapon: Weapon         # 傷害、有效射程、射程都照這把槍
var fx: ShotFX             # 火花、彈孔、著彈聲
var mask := 1
var visual_only := false
## 霰彈十顆同時打到，著彈聲只要第一顆出聲
var sound := true

var _traveled := 0.0
var _streak: MeshInstance3D


func _ready() -> void:
	global_position = origin
	if fx and fx.tracer_material:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(fx.tracer_width, fx.tracer_width, STREAK_LENGTH)
		mesh.material = fx.tracer_material
		_streak = MeshInstance3D.new()
		_streak.mesh = mesh
		_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_streak.visible = false
		add_child(_streak)


func _physics_process(delta: float) -> void:
	advance(delta)


## 往前飛一幀。拆出來是為了讓測試可以直接驅動，不用等物理幀。
func advance(delta: float) -> void:
	if not is_instance_valid(weapon):
		queue_free()
		return
	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta
	var exclude: Array[RID] = []
	if is_instance_valid(shooter):
		exclude.append(shooter.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_traveled += from.distance_to(to)
		global_position = to
		if _traveled > weapon.hit_range:
			queue_free()
			return
		if _streak:
			_streak.visible = _traveled > SHOW_AFTER
			# 曳光沿著飛行方向，看得出子彈往下彎
			if not vel.normalized().is_equal_approx(Vector3.UP):
				look_at(to + vel)
		return
	_traveled += from.distance_to(hit["position"])
	_impact(hit)
	queue_free()


## 打到的是什麼材質：會扣血的噴血，地形噴土，石頭噴石屑，其他（房子、柵欄、樹）都當木頭
static func surface_of(target: Object) -> StringName:
	if target.has_method(&"take_damage"):
		return &"blood"
	if target is Node and target.is_in_group(&"ground"):
		return &"dirt"
	if target is Node and target.is_in_group(&"stone"):
		return &"stone"
	return &"wood"


func _impact(hit: Dictionary) -> void:
	var target: Object = hit["collider"]
	# 認方法不認型別：恐龍、別的牛仔都吃同一發子彈
	var flesh: bool = target.has_method(&"take_damage")
	if is_instance_valid(fx):
		fx.impact(hit["position"], hit["normal"], surface_of(target), sound)
	if visual_only or not flesh or not is_instance_valid(shooter):
		return
	var dmg := weapon.damage_at(_traveled)
	# 爆頭秒殺只在有效射程內成立，跟 Hunt 一樣。距離用子彈實際飛了多遠
	if _traveled <= weapon.effective_range and Viewmodel.is_headshot(target, hit["position"]):
		dmg = target.max_hp
	shooter.deal_damage(target, roundi(dmg))
