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
## 打在恐龍頭的位置這麼近算打中頭（boss 放大 1.5 倍，頭約 1.2 × 2 公尺）
const DINO_HEAD := 1.6

var origin := Vector3.ZERO
var vel := Vector3.ZERO
var shooter: Node          # Cowboy。可能在子彈飛行中死掉被砍，用前要檢查
var weapon: Weapon         # 傷害、有效射程、射程都照這把槍
var fx: ShotFX             # 火花、彈孔、著彈聲
var mask := 1
var visual_only := false
## 霰彈十顆同時打到，著彈聲只要第一顆出聲
var sound := true
## 炸彈長矛的魚叉：開槍那台打到任何東西時呼叫（位置），用來引爆。其他台的只有外觀
var on_impact := Callable()
## 飛出去的樣子（魚叉）。有的話一出槍口就看得到，不畫曳光
var model: Node3D

var _traveled := 0.0
var _streak: MeshInstance3D


func _ready() -> void:
	global_position = origin
	if model:
		add_child(model)
		model.visible = false   # 從鏡頭中心出發：前一公尺不畫，不然整支魚叉貼在臉上（一團黑）
		look_at(origin + vel)
	elif fx and fx.tracer_material:
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
		if _traveled > weapon.max_range:
			if on_impact.is_valid() and not visual_only:   # 魚叉飛到射程盡頭沒打到東西：在空中炸（不要憑空消失）
				on_impact.call(global_position)
			queue_free()
			return
		if _streak:
			_streak.visible = _traveled > SHOW_AFTER
		if model:
			model.visible = _traveled > 1.0
		# 曳光、魚叉沿著飛行方向，看得出往下彎
		if (_streak or model) and not vel.normalized().is_equal_approx(Vector3.UP):
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
	if target.has_method(&"on_shot"):   # 油燈：每台電腦的子彈都會打到，各自破、各自燒（含 visual_only）
		target.on_shot(hit["position"], shooter, vel.normalized())
	if on_impact.is_valid() and not visual_only:
		on_impact.call(hit["position"] + hit["normal"] * 0.15)
	if visual_only or not flesh or not is_instance_valid(shooter):
		return
	var dmg := weapon.damage_at(_traveled)
	# 爆頭秒殺只在有效射程內成立，跟 Hunt 一樣。距離用子彈實際飛了多遠
	var head: bool = _traveled <= weapon.falloff_start and Viewmodel.is_headshot(target, hit["position"])
	if head:
		dmg = target.max_hp
	# 恐龍 boss 沒有爆頭秒殺，但打中頭可以打斷牠的蓄力（boss.gd 的 head_hit）
	var dino_head: bool = target.has_method(&"head_position") and hit["position"].distance_to(target.head_position()) < DINO_HEAD
	shooter.deal_damage(target, roundi(dmg), dino_head)
	var g := get_tree().get_first_node_in_group(&"match")
	if g:
		g.hit_popup(hit["position"], roundi(dmg), _traveled, head)   # 靶場才會跳字
