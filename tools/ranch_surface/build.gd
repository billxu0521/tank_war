extends SceneTree
## 離線重建本圖資源；因MultiMesh GPU buffer讀回，需要已核准的圖形時段。
var m: Node
var frame := 0
func _initialize() -> void:
	assert(DisplayServer.get_name() != "headless", "裝飾保存必須有真渲染後端；dummy不能取代MultiMesh讀回")
	assert(OS.get_cmdline_user_args().has("--original-ground"),"重建需原版場地，避免重複裝飾")
	m = load("res://main.tscn").instantiate();root.add_child(m)
func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:m._on_sandbox_pressed()
	if frame == 40:
		var generator := preload("res://tools/ranch_surface/generator.gd").new()
		generator.install(m);generator.export_assets()
		print("RANCH_SURFACE_BUILD_OK");quit();return true
	return false
