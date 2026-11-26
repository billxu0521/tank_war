extends RefCounted
## 在農莊完成既有作物、建物與積木登記後呼叫。兩端同步追加相同的樹序。
const MARGIN := preload("res://levels/east_field_margin/east_margin.tscn")

static func install(farm: ArenaMap) -> void:
	if farm.has_node(^"EastFieldMargin"):
		return
	var margin := MARGIN.instantiate()
	farm.add_child(margin)
	for marker: LevelItem in margin.get_node("TreePositions").get_children():
		farm._tree(marker.to_record())
