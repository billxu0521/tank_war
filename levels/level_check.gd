class_name LevelCheck
extends RefCounted
## 擺設檢查：編輯器的「檢查擺設」按鈕（LevelRoot）和遊戲的測試（test_battle.gd）跑同一支。
## 輸入是擺設清單（main.gd 的 _level，每筆可以帶 node = 節點名字），回傳 [[物件, 說明], ...]，沒問題就是空的。
##
## 查的東西：
##   - 會擋人的東西不能互相重疊（柵欄穿房子、木箱卡在柵欄裡……）。佔地大小跟出生點避開用同一份（main.gd 的 footprint_half），
##     照朝向比；疊高的東西（上層的草捆）連高度一起比
##   - 撤離區、靶場要空著
##   - 不能擺到場外
##   - 型號要存在（打錯字會變成看不見的空氣）
##   - 建築不能高過「恐龍爬得到的上限」（圍牆就是照這個高度算的）

const Main := preload("res://main.gd")
const SHRINK := 0.05   # 貼在一起不算重疊（木桶並排、草捆疊起來）
const TALL := 100.0    # 不是小物件的東西，高度當成從地面一路到頂


## 這一筆佔的空間：{c 中心, half 半寬, yaw, box 轉過之後的外框, y0, y1 高度範圍}；沒有碰撞的回傳空的
static func footprint(rec: Dictionary) -> Dictionary:
	var half := Main.footprint_half(rec)
	if half == Vector2.ZERO:
		return {}
	var p: Vector3 = rec.pos
	var yaw: float = rec.get("yaw", 0.0)
	var ext := Vector2(absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y, absf(sin(yaw)) * half.x + absf(cos(yaw)) * half.y)
	var height: float = Main.KIT_SIZE.get(rec.get("name", &""), Vector3.ONE * TALL).y if rec.kind == &"kit" else TALL
	return {c = Vector2(p.x, p.z), half = half, yaw = yaw, box = Rect2(Vector2(p.x, p.z) - ext, ext * 2.0),
		y0 = p.y, y1 = p.y + height}


## 兩個有朝向的長方形重不重疊（分離軸：四條邊的方向都投影看看，有一條分得開就沒重疊）。先比高度和外框，大部分一下就排除
static func overlap(a: Dictionary, b: Dictionary) -> bool:
	if a.y1 - SHRINK <= b.y0 or b.y1 - SHRINK <= a.y0 or not a.box.grow(-SHRINK).intersects(b.box.grow(-SHRINK)):
		return false
	for f: Dictionary in [a, b]:
		for ax: Vector2 in [Vector2(cos(f.yaw), -sin(f.yaw)), Vector2(sin(f.yaw), cos(f.yaw))]:
			if absf((a.c - b.c).dot(ax)) > _radius(a, ax) + _radius(b, ax):
				return false
	return true


static func _radius(f: Dictionary, ax: Vector2) -> float:
	var h: Vector2 = f.half - Vector2.ONE * SHRINK
	# 自己的 X、Z 軸：Godot 繞 Y 轉 yaw 之後，+X 指向 (cos, -sin)、+Z 指向 (sin, cos)
	return absf(Vector2(cos(f.yaw), -sin(f.yaw)).dot(ax)) * maxf(h.x, 0.0) \
		+ absf(Vector2(sin(f.yaw), cos(f.yaw)).dot(ax)) * maxf(h.y, 0.0)


## ranch：牧場才要檢查沙盒靶道和撤離區（靶場地圖沒有這兩樣）
static func run(recs: Array, ranch := true) -> Array:
	var problems := []
	var half := Main.ARENA * 0.5
	var meshes := Main.meshes()
	var placed := []   # [名字, 佔的空間]
	for i in recs.size():
		var rec: Dictionary = recs[i]
		var name: String = rec.get("node", "%s#%d" % [rec.kind, i])
		var p: Vector3 = rec.pos
		if absf(p.x) > half - 1.0 or absf(p.z) > half - 1.0:
			problems.append([name, "擺到場外了（%.0f, %.0f）" % [p.x, p.z]])
		for key in ["name", "mesh", "variant"]:   # 小物件、樹、石頭、農舍的型號都是模型名
			if rec.has(key) and not meshes.has(rec[key]):
				problems.append([name, "沒有「%s」這個模型（打錯字？）" % rec[key]])
		if rec.kind == &"barn":
			var top: float = rec.size.y + rec.size.x * 0.5 * tan(Main.BARN_PITCH)
			if top > Main.BUILDING_MAX_H:
				problems.append([name, "穀倉太高（屋頂 %.1f 公尺，上限 %.0f）" % [top, Main.BUILDING_MAX_H]])
		if rec.kind == &"silo" and rec.h + 1.6 > Main.BUILDING_MAX_H:
			problems.append([name, "筒倉太高（%.1f 公尺，上限 %.0f）" % [rec.h + 1.6, Main.BUILDING_MAX_H]])
		var fp := footprint(rec)
		if fp.is_empty():
			continue
		if ranch and Main.SANDBOX_RANGE.grow(-SHRINK).intersects(fp.box):
			problems.append([name, "擋到沙盒靶場"])
		for e: Vector2 in Main.exit_spots() if ranch else []:
			if (fp.c as Vector2).distance_to(e) < Main.EXIT_RADIUS:
				problems.append([name, "擋在撤離區裡"])
		for other: Array in placed:
			if overlap(fp, other[1]):
				problems.append([name, "跟「%s」重疊" % other[0]])
		placed.append([name, fp])
	return problems
