@tool
class_name LevelItem
extends Node3D
## 場景檔（levels/ranch.tscn）裡的一樣東西。遊戲開始時 main.gd 把每個 LevelItem 換成擺設清單的一筆，照清單蓋出來。
##
## 在 Godot 編輯器裡：拖曳移動、轉向（只看水平方向）、縮放（樹、石頭、灌木）；其他參數在右邊屬性面板改。
## 高度不用管：編輯器裡會自動貼著地形（LevelRoot），要疊高（例如草捆疊第二層）改 lift。
## 種類跟參數的對應（main.gd 的 _build_level 照這個蓋）：
##   flat     整平區，amount = 半徑（公尺）
##   wheat    麥田，amount = 邊長
##   barn     穀倉，size = 寬 × 牆高 × 長（公尺），amount = 出生點要離多遠
##   house    農舍，variant = House1 / House2 / House3
##   silo     筒倉，amount = 高度
##   fence    柵欄，amount = 長度（沿著自己的 X 方向）
##   gate     圍欄門，amount = 往外是 -Z（-1）還是 +Z（+1），flag = 缺口左邊那扇
##   hay_bale 圓草捆，flag = 出生點要避開
##   kit      小物件（木桶、木箱、方草捆……），variant = 模型名
##   prop     只有外觀的模型（篷車），variant = 模型名
##   tree     樹，variant = TreeOak / TreeOakM / TreeOakS / TreePine，大小用節點的縮放
##   rock     石頭，variant = Rock01..16，大小用節點的縮放，flag = 有碰撞（掩體）
##   bush     灌木，大小用節點的縮放
##   shop     城鎮店面，variant = Saloon / Store / Sheriff（正面朝自己的 +Z，轉向用節點的朝向）
##   road     另外鋪的土路（城鎮主街），size 的 X、Z = 長、寬（不轉向）
##   windmill 風車、hay_shed 倉庫、hitch 繫柱架、wheel 靠牆的車輪、water_tower 水塔：只看位置和朝向

@export_enum("flat", "wheat", "barn", "house", "silo", "fence", "gate", "hay_bale", "kit", "prop",
	"tree", "rock", "bush", "windmill", "hay_shed", "hitch", "wheel", "shop", "road", "water_tower") var kind := "kit":
	set(v):
		kind = v
		_refresh()
@export var variant: StringName = &"":
	set(v):
		variant = v
		_refresh()
@export var size := Vector3.ONE:
	set(v):
		size = v
		_refresh()
@export var amount := 0.0:
	set(v):
		amount = v
		_refresh()
@export var flag := false:
	set(v):
		flag = v
		_refresh()
## 離地高度（公尺）。平常是 0；疊起來的東西（上層的草捆）才要填
@export var lift := 0.0:
	set(v):
		lift = v
		_refresh()


## 變成擺設清單的一筆（main.gd 的 _put）。要在場景樹裡才讀得到整體位置（群組節點可以整組搬）
func to_record() -> Dictionary:
	var g := global_transform
	var rec := {kind = StringName(kind), pos = Vector3(g.origin.x, lift, g.origin.z), yaw = global_rotation.y}
	var sc := g.basis.get_scale()
	match kind:
		"flat": rec.r = amount
		"wheat": rec.size = amount
		"barn":
			rec.size = size
			rec.clearance = amount
		"house", "shop": rec.variant = variant
		"road": rec.size = size
		"silo": rec.h = amount
		"fence": rec.length = amount
		"gate":
			rec.out = amount
			rec.left = flag
		"hay_bale": rec.block = flag
		"kit", "prop": rec.name = variant
		"tree":
			rec.mesh = variant
			rec.s = sc.x
		"rock":
			rec.mesh = variant
			rec.s = sc.x
			rec.solid = flag
		"bush": rec.size = sc
	return rec


## 從擺設清單的一筆做出節點（烘焙工具用）
static func from_record(rec: Dictionary) -> LevelItem:
	var it := LevelItem.new()
	it.kind = String(rec.kind)
	var p: Vector3 = rec.pos
	it.lift = p.y
	it.position = p
	it.rotation.y = rec.get("yaw", 0.0)
	match it.kind:
		"flat": it.amount = rec.r
		"wheat": it.amount = rec.size
		"barn":
			it.size = rec.size
			it.amount = rec.clearance
		"house", "shop": it.variant = rec.variant
		"road": it.size = rec.size
		"silo": it.amount = rec.h
		"fence": it.amount = rec.length
		"gate":
			it.amount = rec.out
			it.flag = rec.left
		"hay_bale": it.flag = rec.get("block", false)
		"kit", "prop": it.variant = rec.name
		"tree":
			it.variant = rec.mesh
			it.scale = Vector3.ONE * rec.s
		"rock":
			it.variant = rec.mesh
			it.scale = Vector3.ONE * rec.s
			it.flag = rec.solid
		"bush": it.scale = rec.size
	return it


# --- 編輯器裡的外觀（遊戲裡不跑：遊戲是照清單另外蓋的） ---

const _PREVIEW := &"_preview"   # 預覽模型的節點名字：不存進場景檔（沒有 owner）


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var old := get_node_or_null(NodePath(_PREVIEW))
	if old:
		old.free()
	var root := Node3D.new()
	root.name = _PREVIEW
	add_child(root)   # 不設 owner：存檔時不會存進去
	LevelPreview.build(self, root)
	_snap()


var _root: LevelRoot   # 往上找到的場景根節點（編輯器裡才有）
var _snapping := false  # 貼地時自己改了位置，不要再觸發一次貼地


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_root = null
		var n := get_parent()
		while n and not n is LevelRoot:
			n = n.get_parent()
		_root = n


## 在編輯器裡拖動之後自動貼回地面
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap()


func _snap() -> void:
	if _root and not _snapping:
		_snapping = true
		_root.snap(self)
		_snapping = false
