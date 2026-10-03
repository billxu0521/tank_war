extends SceneTree
## 種植被（blender/grove.py、flora.py 的新樹和仙人掌）到手調過的 levels/ranch.tscn：
##   1. 舊松樹 TreePine 全換成 TreePine2；森林區的闊葉樹 25% 換楓樹、8% 換柳樹；農社區 15% 換楓樹；其他地方 8% 換枯樹
##   2. 城鎮區（荒漠）店面後面兩條空地，種一個「植被」群組：柱狀仙人掌大小、約書亞樹、枯樹（都有碰撞，是 tree 類）
## 草叢、小仙人掌、灌木沒有碰撞，不進場景檔，遊戲開場時撒（main.gd 的 _flora_field）。
## 重跑會先刪掉舊的「植被」群組，換樹種的規則只換還是闊葉樹／舊松樹的，所以重跑結果一樣。
##   godot --headless --path . --script tools/plant_flora.gd
const PATH := "res://levels/ranch.tscn"
const Main := preload("res://main.gd")


func _initialize() -> void:
	var level: Node = load(PATH).instantiate()
	var taken: Array[Vector2] = []
	var changed := 0
	var rng := RandomNumberGenerator.new()
	for it: LevelItem in level.find_children("*", "LevelItem", true, false):
		var p := _world_xz(it)
		taken.append(p)
		if it.kind != "tree":
			continue
		rng.seed = hash(Vector2i(p.round()))   # 每棵自己的亂數：重跑、增刪別的東西都不影響
		var roll := rng.randf()
		var v := it.variant
		if v == &"TreePine":
			v = &"TreePine2"
		elif String(v).begins_with("TreeOak"):
			if Main.ZONE_FOREST.has_point(p):
				v = &"TreeMaple" if roll < 0.25 else (&"TreeWillow" if roll < 0.33 else v)
			elif Main.ZONE_FARM.has_point(p):
				v = &"TreeMaple" if roll < 0.15 else v
			elif roll < 0.08:
				v = &"TreeDead"
		if v != it.variant:
			it.variant = v
			changed += 1

	var old := level.get_node_or_null("植被")
	if old:
		level.remove_child(old)
		old.free()
	var group := Node3D.new()
	group.name = "植被"
	level.add_child(group)
	group.owner = level
	# 店面在主街（z = -46）兩側各佔到 z ±23 左右；後面兩條空地：北 z -83~-72、南 z -20~-10
	rng.seed = 20261001
	var kinds := [[&"Saguaro", 0.45, "仙人掌"], [&"SaguaroS", 0.3, "小仙人掌"], [&"TreeJoshua", 0.15, "約書亞樹"], [&"TreeDead", 0.1, "枯樹"]]
	var count := {}
	var tries := 0
	while group.get_child_count() < 18 and tries < 2000:
		tries += 1
		var z := rng.randf_range(-83, -72) if rng.randf() < 0.5 else rng.randf_range(-20, -10)
		var p := Vector2(rng.randf_range(12, 82), z)
		if p.distance_to(Vector2(78, -78)) < 6.0 or taken.any(func(q: Vector2) -> bool: return q.distance_to(p) < 5.0) \
				or Main.SANDBOX_RANGE.grow(4.0).has_point(p) \
				or Main.exit_spots().any(func(e: Vector2) -> bool: return e.distance_to(p) < Main.EXIT_RADIUS + 8.0):   # 靶場、撤離區要空著
			continue
		var r := rng.randf()
		var k: Array = kinds[-1]
		for c: Array in kinds:
			if r < c[1]:
				k = c
				break
			r -= c[1]
		var it := LevelItem.new()
		it.kind = "tree"
		it.variant = k[0]
		count[k[2]] = count.get(k[2], 0) + 1
		it.name = "%s%d" % [k[2], count[k[2]]]
		it.position = Vector3(p.x, 0, p.y)
		it.rotation.y = rng.randf() * TAU
		it.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
		group.add_child(it)
		it.owner = level
		taken.append(p)
	var packed := PackedScene.new()
	packed.pack(level)
	var err := ResourceSaver.save(packed, PATH)
	print("換樹種 %d 棵、植被 %d 棵 -> %s（%s）" % [changed, group.get_child_count(), PATH, "OK" if err == OK else "失敗 %d" % err])
	level.free()
	quit(0 if err == OK else 1)


## 不在場景樹裡讀不到 global_position：自己把父節點的位移一路乘上去（群組節點可以整組搬）
func _world_xz(n: Node3D) -> Vector2:
	var g := n.transform
	var p := n.get_parent()
	while p is Node3D:
		g = (p as Node3D).transform * g
		p = p.get_parent()
	return Vector2(g.origin.x, g.origin.z)
