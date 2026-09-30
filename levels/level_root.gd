@tool
class_name LevelRoot
extends Node3D
## 場景檔（levels/ranch.tscn）的根節點。在 Godot 編輯器裡：
##   - 畫出地形（跟遊戲同一支 Main.make_terrain 算），物件拖到哪就自動貼著地面
##   - 「重算地形」：改了整平區（flat）的位置或大小之後按一下
##   - 「檢查擺設」：貼地、重疊、柵欄穿房子、撤離區、出生點……有問題的列在下面的「輸出」面板，物件頭上標紅
## 遊戲裡不跑這些（main.gd 只讀每個 LevelItem 的資料）。

const Main := preload("res://main.gd")

@export_tool_button("重算地形") var _rebuild_btn := rebuild_terrain
@export_tool_button("檢查擺設") var _check_btn := check

var terrain: Terrain


func _ready() -> void:
	if Engine.is_editor_hint():
		rebuild_terrain()


func items() -> Array[LevelItem]:
	var out: Array[LevelItem] = []
	for n in find_children("*", "", true, false):
		if n is LevelItem:
			out.append(n)
	return out


func rebuild_terrain() -> void:
	var all := items()
	var flats := []
	var wheat: Array[Rect2] = []
	var roads: Array[Rect2] = []
	for it in all:
		var p := it.global_position
		if it.kind == "flat":
			flats.append([Vector2(p.x, p.z), it.amount])
		elif it.kind == "wheat":
			wheat.append(Rect2(p.x - it.amount * 0.5, p.z - it.amount * 0.5, it.amount, it.amount))
		elif it.kind == "road":
			roads.append(Rect2(p.x - it.size.x * 0.5, p.z - it.size.z * 0.5, it.size.x, it.size.z))
	terrain = Main.make_terrain(flats)
	var old := get_node_or_null(^"_terrain_preview")
	if old:
		old.free()
	var t := terrain
	var body := terrain.build(func(x: float, z: float, h: float) -> Color: return Main.ground_color(t, wheat, roads, x, z, h))
	body.name = "_terrain_preview"
	add_child(body)   # 不設 owner：不存進場景檔
	for it in all:
		snap(it)


## 把物件貼到地面上（加上它自己的 lift）。用地形格點查高度：編輯器拖曳時每一格都會叫，要快
func snap(it: LevelItem) -> void:
	if terrain == null:
		return
	var p := it.global_position
	var y := terrain.fast_height(p.x, p.z) + it.lift
	if absf(p.y - y) > 0.001:
		it.global_position = Vector3(p.x, y, p.z)


## 擺設檢查（遊戲的測試也跑同一支）：回傳問題清單，每一筆 [物件, 說明]
func check() -> Array:
	var all := items()
	var problems := LevelCheck.run(all.map(func(it: LevelItem) -> Dictionary:
		var rec := it.to_record()
		rec.node = String(it.name)
		return rec))
	# 有問題的物件頭上放一個紅色方塊（不存進場景檔），修好再按一次就消失
	var bad := {}
	for p: Array in problems:
		printerr("擺設問題：%s —— %s" % [p[0], p[1]])
		bad[p[0]] = true
	for it in all:
		var old := it.get_node_or_null(^"_problem")
		if old:
			old.free()
		if bad.has(String(it.name)):
			var box := BoxMesh.new()
			box.size = Vector3(1.5, 1.5, 1.5)
			var mi := LevelPreview.zone(it, box, Color(1, 0.1, 0.1, 0.6))
			mi.name = "_problem"
			mi.top_level = true
			mi.global_position = it.global_position + Vector3(0, 4, 0)
	print("擺設檢查：" + ("沒有問題" if problems.is_empty() else "%d 個問題（看上面紅字）" % problems.size()))
	return problems
