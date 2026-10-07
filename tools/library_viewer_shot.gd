extends SceneTree
## 檢視模式「5 素材庫」：models/ 每個 glb 各截一張（整包、排開），看有沒有貼地、鏡頭有沒有框到。
##   OUT=/tmp/lib godot --path . --resolution 1280x720 --script tools/library_viewer_shot.gd
var _f := 0
var _shot := 0
var v: ModelViewer


func _initialize() -> void:
	v = (load("res://viewer.gd") as GDScript).new()
	root.add_child(v)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		v._moving = false
		v._select("library")
		assert(not v._lib_files.is_empty(), "models/ 裡應該有 glb")
		print("素材庫列到 %d 個：%s" % [v._lib_files.size(), ", ".join(v._lib_files)])
	if _f > 3 and _f % 15 == 0:
		var name: String = v._lib_files[v._lib_i].get_basename() + ("_spread" if v._lib_spread else "")
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%02d_%s.png" % [_shot, name])
		_shot += 1
		v._lib_spread = not v._lib_spread
		if not v._lib_spread:
			if v._lib_i + 1 >= v._lib_files.size():
				return true
			v._lib_i += 1
		v._show_lib()
	return false
