extends SceneTree
## 產生物件庫：levels/物件庫/ 底下每種東西一個小場景檔。在 Godot 編輯器裡從「檔案系統」面板拖進 ranch.tscn 就是新增一個。
## 新增了物件種類（main.gd 的 _build_level、LevelItem）就在下面加一行，再跑一次：
##   godot --headless --path . --script tools/make_kit_presets.gd

const DIR := "res://levels/物件庫/"
# [檔名, kind, variant, size, amount, flag, 縮放]
const PRESETS := [
	["穀倉", "barn", &"", Vector3(14, 8, 20), 7.0, false, 1.0],
	["小棚子", "barn", &"", Vector3(8, 4, 6), 3.0, false, 1.0],
	["前廊農舍", "house", &"House1", Vector3.ONE, 0.0, false, 1.0],
	["圓木小屋", "house", &"House2", Vector3.ONE, 0.0, false, 1.0],
	["直板高屋", "house", &"House3", Vector3.ONE, 0.0, false, 1.0],
	["筒倉", "silo", &"", Vector3.ONE, 15.0, false, 1.0],
	["倉庫", "hay_shed", &"", Vector3.ONE, 0.0, false, 1.0],
	["風車", "windmill", &"", Vector3.ONE, 0.0, false, 1.0],
	["柵欄10公尺", "fence", &"", Vector3.ONE, 10.0, false, 1.0],
	["柵欄6公尺", "fence", &"", Vector3.ONE, 6.0, false, 1.0],
	["圍欄門_左", "gate", &"", Vector3.ONE, -1.0, true, 1.0],
	["圍欄門_右", "gate", &"", Vector3.ONE, -1.0, false, 1.0],
	["繫柱架", "hitch", &"", Vector3.ONE, 0.0, false, 1.0],
	["靠牆車輪", "wheel", &"", Vector3.ONE, 0.0, false, 1.0],
	["木桶", "kit", &"Barrel", Vector3.ONE, 0.0, false, 1.0],
	["木箱", "kit", &"Crate", Vector3.ONE, 0.0, false, 1.0],
	["方草捆", "kit", &"HayBlock", Vector3.ONE, 0.0, false, 1.0],
	["吊燈", "kit", &"Lantern", Vector3.ONE, 0.0, false, 1.0],
	["圓草捆", "hay_bale", &"", Vector3.ONE, 0.0, true, 1.0],
	["篷車", "prop", &"Wagon", Vector3.ONE, 0.0, false, 1.0],
	["闊葉樹_大", "tree", &"TreeOak", Vector3.ONE, 0.0, false, 1.0],
	["闊葉樹_中", "tree", &"TreeOakM", Vector3.ONE, 0.0, false, 1.0],
	["闊葉樹_小", "tree", &"TreeOakS", Vector3.ONE, 0.0, false, 1.0],
	["松樹", "tree", &"TreePine2", Vector3.ONE, 0.0, false, 1.0],
	["楓樹", "tree", &"TreeMaple", Vector3.ONE, 0.0, false, 1.0],
	["柳樹", "tree", &"TreeWillow", Vector3.ONE, 0.0, false, 1.0],
	["約書亞樹", "tree", &"TreeJoshua", Vector3.ONE, 0.0, false, 1.0],
	["枯樹", "tree", &"TreeDead", Vector3.ONE, 0.0, false, 1.0],
	["仙人掌_大", "tree", &"Saguaro", Vector3.ONE, 0.0, false, 1.0],
	["仙人掌_小", "tree", &"SaguaroS", Vector3.ONE, 0.0, false, 1.0],
	["灌木", "bush", &"", Vector3.ONE, 0.0, false, 1.0],
	["整平區", "flat", &"", Vector3.ONE, 12.0, false, 1.0],
	["麥田", "wheat", &"", Vector3.ONE, 40.0, false, 1.0],
	["酒館", "shop", &"Saloon", Vector3.ONE, 0.0, false, 1.0],
	["雜貨店", "shop", &"Store", Vector3.ONE, 0.0, false, 1.0],
	["警長辦公室", "shop", &"Sheriff", Vector3.ONE, 0.0, false, 1.0],
	["水塔", "water_tower", &"", Vector3.ONE, 0.0, false, 1.0],
	["街道", "road", &"", Vector3(40, 0, 8), 0.0, false, 1.0],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var n := 0
	for p: Array in PRESETS:
		n += _save(p[0], p[1], p[2], p[3], p[4], p[5], p[6])
	# 石頭 16 種：大石、單顆（有碰撞，當掩體）和碎石（只有外觀）各一個
	for i in 16:
		var name := "Rock%02d" % (i + 1)
		n += _save("石頭_%s" % name, "rock", StringName(name), Vector3.ONE, 0.0, true, 0.6 if i < 4 else 1.0)
	print("物件庫：%d 個 -> %s" % [n, DIR])
	quit()


func _save(file: String, kind: String, variant: StringName, size: Vector3, amount: float, flag: bool, s: float) -> int:
	var it := LevelItem.new()
	it.name = file
	it.kind = kind
	it.variant = variant
	it.size = size
	it.amount = amount
	it.flag = flag
	it.scale = Vector3.ONE * s
	var packed := PackedScene.new()
	packed.pack(it)
	var err := ResourceSaver.save(packed, DIR + file + ".tscn")
	it.free()
	return 1 if err == OK else 0
