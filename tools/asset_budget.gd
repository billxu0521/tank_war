extends SceneTree
## 美術風格指南第 4、5 節的資產檢查：每個模型的三角面數有沒有超預算、貼圖有沒有超量。
## 指南：docs/美術/Low_Poly_西部奇幻FPS_美術風格指南.docx。檢驗流程見 docs/美術/美術風格檢驗.md。
##   godot --headless --path . --script tools/asset_budget.gd
## 超過「可提高到」的上限 → FAIL（回傳 1）；超過建議範圍但沒到上限 → 注意（只列出來）。

## [檔案, 類別]：類別對到下面的 BUDGET。一個檔裡每個模型各自算；角色、恐龍、槍是整個檔加總算一隻
const FILES := [
	["res://models/rocks.glb", "小型道具"], ["res://models/floras.glb", "小型道具"],
	["res://models/props.glb", "中型道具"], ["res://models/kits.glb", "中型道具"],
	["res://models/trees.glb", "樹"], ["res://models/groves.glb", "樹"],
	["res://models/houses.glb", "大型建築"], ["res://models/towns.glb", "大型建築"],
	["res://models/cowboy.glb", "一般敵人"], ["res://models/trex_hd.glb", "Boss"],
	["res://models/revolver.glb", "第一人稱武器"], ["res://models/rifle.glb", "第一人稱武器"], ["res://models/shotgun.glb", "第一人稱武器"],
]
## 同一個檔裡混了不同大小的東西：照名字改類別
const NAME_CLASS := {&"Barn": "大型建築", &"BarnRoof": "大型建築", &"SiloBody": "大型建築", &"SiloDome": "大型建築",
	&"HayShed": "大型建築", &"Windmill": "大型建築", &"WindmillRotor": "中型道具"}
## 類別: [建議下限, 建議上限, 可提高到, 整檔加總?]（指南第 4 節的表；樹指南沒列，暫用中型道具和大型建築之間）
const BUDGET := {
	"小型道具": [50, 300, 500, false],
	"中型道具": [150, 700, 1000, false],
	"樹": [150, 1500, 2500, false],
	"大型建築": [500, 2500, 4000, false],
	"一般敵人": [2000, 5000, 8000, true],
	"Boss": [5000, 15000, 25000, true],
	"第一人稱武器": [3000, 8000, 12000, true],
}
## 指南第 5 節：一般環境物件 0～1 張底色貼圖，法線、粗糙度、AO 貼圖不列為基本要求（只有英雄資產例外）
const MAX_TEX := 1


func _initialize() -> void:
	var fails := 0
	var warns := 0
	for f: Array in FILES:
		var root: Node = load(f[0]).instantiate()
		var items := []   # [名字, 三角面, 貼圖數, 有法線貼圖]
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			items.append([mi.name, _tris(mi.mesh), _textures(mi), _has_normal_map(mi)])
		var whole: bool = BUDGET[f[1]][3]
		if whole:   # 整檔加總：角色是好幾個零件拼成一隻
			var sum := [String(f[0]).get_file().get_basename(), 0, 0, false]
			for it in items:
				sum[1] += it[1]
				sum[2] = maxi(sum[2], it[2])
				sum[3] = sum[3] or it[3]
			items = [sum]
		for it in items:
			var cls: String = NAME_CLASS.get(StringName(it[0]), f[1])
			var b: Array = BUDGET[cls]
			var tag := ""
			if it[1] > b[2]:
				tag = "FAIL 面數 %d 超過上限 %d" % [it[1], b[2]]
				fails += 1
			elif it[1] > b[1]:
				tag = "注意 面數 %d 超過建議 %d" % [it[1], b[1]]
				warns += 1
			if it[2] > MAX_TEX and not b[3]:
				tag += ("；" if tag else "注意 ") + "貼圖 %d 張" % it[2]
				warns += 1
			if it[3] and not b[3]:
				tag += ("；" if tag else "注意 ") + "有法線貼圖"
				warns += 1
			if tag:
				print("%s  %-16s %-8s %s" % [String(f[0]).get_file(), it[0], cls, tag])
		root.free()
	print("資產檢查：%d 個超過上限、%d 個注意" % [fails, warns])
	quit(1 if fails > 0 else 0)


func _tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _textures(mi: MeshInstance3D) -> int:
	var seen := {}
	for s in mi.mesh.get_surface_count() if mi.mesh else 0:
		var m := mi.get_active_material(s) as BaseMaterial3D
		if m == null:
			continue
		for t in [m.albedo_texture, m.normal_texture, m.roughness_texture, m.metallic_texture, m.ao_texture, m.emission_texture]:
			if t:
				seen[t] = true
	return seen.size()


func _has_normal_map(mi: MeshInstance3D) -> bool:
	for s in mi.mesh.get_surface_count() if mi.mesh else 0:
		var m := mi.get_active_material(s) as BaseMaterial3D
		if m and m.normal_enabled and m.normal_texture:
			return true
	return false
