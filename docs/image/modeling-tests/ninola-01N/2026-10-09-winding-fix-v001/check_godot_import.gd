extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func inspect(path: String) -> Dictionary:
	var packed = load(path)
	assert(packed is PackedScene)
	var node = packed.instantiate()
	root.add_child(node)
	var skeletons = node.find_children("*", "Skeleton3D", true, false)
	assert(skeletons.size() == 1)
	var skeleton: Skeleton3D = skeletons[0]
	var bones: Array = []
	for i in skeleton.get_bone_count():
		bones.append({"name": skeleton.get_bone_name(i), "parent": skeleton.get_bone_parent(i), "rest": str(skeleton.get_bone_rest(i))})
	assert(bones.size() == 45)
	var triangles := 0
	var bounds: Array = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		assert(mesh.skin != null and mesh.skin.get_bind_count() == 45)
		bounds.append(str(mesh.get_aabb()))
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	assert(triangles == 6906)
	node.queue_free()
	return {"bones": bones, "triangles": triangles, "bounds": bounds}
func run() -> void:
	var a = inspect("res://models/N1v003_eight_weights.glb")
	var b = inspect("res://models/N1v004_eight_weights.glb")
	assert(a == b)
	var result = {"godot_import_pass": true, "bone_count": b.bones.size(), "triangles": b.triangles, "runtime_skeleton_rest_and_bounds_exact": true, "real_game_input_test": false, "scope": "isolated import only; compatibility renderer, not Forward Plus visual test"}
	var file = FileAccess.open("res://../godot_import_verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("IMPORT CHECK OK ", JSON.stringify(result))
	quit(0)
