extends SceneTree
## 烘焙：跑一次自動擺設，把擺設清單存成場景檔 levels/ranch.tscn，之後在 Godot 編輯器裡手調。
## **會蓋掉手調過的結果**——只在第一次、或確定要從頭來的時候跑（舊版從 git 拿得回來）。
##   godot --headless --path . --script tools/bake_level.gd
##   godot --headless --path . --script tools/bake_level.gd -- --range    靶場（levels/range.tscn）

var OUT := "res://levels/ranch.tscn"
# 分組（編輯器的場景樹比較好找）。建築那組要照原本的順序：門的名字 Door0、Door1… 照蓋的順序
# 街道也會擋出生點，放在建築後面：測試拿「第一個擋住的範圍」當穀倉用
const GROUPS := [["地形", ["flat", "wheat"]], ["建築", ["barn", "house", "silo", "hay_shed", "windmill", "shop", "water_tower"]],
	["街道", ["road"]],
	["柵欄", ["fence", "gate"]], ["雜物", ["kit", "wheel", "hitch", "hay_bale", "prop"]],
	["樹", ["tree"]], ["灌木", ["bush"]], ["石頭", ["rock"]]]
const LABEL := {"flat": "整平區", "wheat": "麥田", "barn": "穀倉", "house": "農舍", "silo": "筒倉", "hay_shed": "倉庫",
	"windmill": "風車", "fence": "柵欄", "gate": "圍欄門", "kit": "", "wheel": "車輪", "hitch": "繫柱架",
	"hay_bale": "圓草捆", "prop": "", "tree": "樹", "bush": "灌木", "rock": "石頭", "shop": "", "road": "街道",
	"water_tower": "水塔"}
const KIT_LABEL := {&"Barrel": "木桶", &"Crate": "木箱", &"HayBlock": "方草捆", &"Wagon": "篷車",
	&"Saloon": "酒館", &"Store": "雜貨店", &"Sheriff": "警長辦公室"}

var _f := 0
var _m: Node


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		if OS.get_cmdline_user_args().has("--range"):
			load("res://main.gd").mode = &"range"
			OUT = load("res://main.gd").RANGE_LEVEL
		_m = load("res://main.tscn").instantiate()
		_m.level_path = ""   # 不讀舊的場景檔：自動擺一份
		root.add_child(_m)
	if _f == 3:
		var level := LevelRoot.new()
		level.name = "Level"
		var count := {}
		for g: Array in GROUPS:
			var group := Node3D.new()
			group.name = g[0]
			level.add_child(group)
			group.owner = level
			for rec: Dictionary in _m._level:
				if not String(rec.kind) in g[1]:
					continue
				var it := LevelItem.from_record(rec)
				var label: String = LABEL[String(rec.kind)]
				if label == "":
					var key: StringName = rec.get("name", rec.get("variant", &""))
					label = KIT_LABEL.get(key, String(key))
				count[label] = count.get(label, 0) + 1
				it.name = "%s%d" % [label, count[label]]
				group.add_child(it)
				it.owner = level
		var packed := PackedScene.new()
		packed.pack(level)
		var err := ResourceSaver.save(packed, OUT)
		print("烘焙 %d 筆 -> %s（%s）" % [_m._level.size(), OUT, "OK" if err == OK else "失敗 %d" % err])
		quit(0 if err == OK else 1)
	return false
