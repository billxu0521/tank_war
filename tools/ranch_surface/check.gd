extends SceneTree
## 可在乾淨checkout無視窗執行：依賴完整、貼圖資料與小物件預算檢查。
var seen: Dictionary = {}
func _initialize() -> void:
	for name: String in ["ground.res","outline_data.res","decor.scn","wear.scn"]:
		_walk("res://levels/ranch_surface/"+name)
	var document := GLTFDocument.new();var state := GLTFState.new()
	assert(document.append_from_file("res://levels/ranch_surface/ground_fragments.glb",state)==OK)
	var source := document.generate_scene(state);var count := 0;var total := 0
	for n: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var tris := 0
		for surface in n.mesh.get_surface_count():
			var arrays := n.mesh.surface_get_arrays(surface);tris += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
		assert(tris<=48);total+=tris;count+=1
	assert(count==12 and total==240)
	source.free()
	var ground: ShaderMaterial = load("res://levels/ranch_surface/ground.res")
	assert(ground.get_shader_parameter(&"wear_mask")==null,"採原生磨耗Decal，不常駐替代烘焙圖")
	print("RANCH_SURFACE_CHECK_OK dependencies=",seen.size()," meshes=",count," triangles=",total)
	quit()
func _walk(path: String) -> void:
	if seen.has(path):return
	assert(ResourceLoader.exists(path),"資源不可缺失："+path)
	assert(not path.contains("ground_study") and not path.contains("/Users/"))
	seen[path]=true
	for dep: String in ResourceLoader.get_dependencies(path):
		var ref := dep.get_slice("::",dep.get_slice_count("::")-1)
		_walk(ref)
