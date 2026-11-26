extends SceneTree
## 編輯來源保留逐件網格，遊戲包依既有破壞分件合批，同一部位沿用原碰撞。
const KIT := "res://levels/farm_stock_assemblies/"
func _initialize() -> void:
	bake.call_deferred()

static func append_surface(bucket:Dictionary, mesh:Mesh, s:int, pose:Transform3D) -> void:
	var arr:=mesh.surface_get_arrays(s)
	var vertices:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arr[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var normal_matrix:=pose.basis.inverse().transposed()
	var start:int=bucket.vertices.size()
	for i in vertices.size():
		bucket.vertices.append(pose*vertices[i])
		bucket.normals.append((normal_matrix*normals[i]).normalized())
	if indices.is_empty():
		for i in vertices.size():bucket.indices.append(start+i)
	else:
		for index in indices:bucket.indices.append(start+index)

func bake() -> void:
	var dest:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dest)
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(KIT+"rooms.json"))
	var results:Dictionary={}
	for id:String in index:
		if index[id]["新組裝分件"]==0: continue
		var authored:Node3D=load(KIT+"rooms/"+id+".tscn").instantiate()
		var runtime:=Node3D.new()
		runtime.name=id
		var count:=0
		for group:Node3D in authored.get_children():
			var buckets:Dictionary={}
			for member in group.get_children():
				if not member.has_meta("stock"):
					push_error(str(member.name)+" 缺少建材身分");quit(2);return
				count+=1
				var meshes:Array=[]
				if member is MeshInstance3D:meshes.append(member)
				else:meshes=member.find_children("*","MeshInstance3D",true,false)
				for item:MeshInstance3D in meshes:
					var pose:=member.transform as Transform3D
					if item!=member: pose=pose*item.transform
					for s in item.mesh.get_surface_count():
						var material:=item.get_active_material(s)
						if not material:
							push_error(str(group.name)+" 缺少材料");quit(2);return
						if not buckets.has(material):
							buckets[material]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array()}
						append_surface(buckets[material],item.mesh,s,pose)
			var view:=MeshInstance3D.new()
			view.name=group.name
			view.set_meta("target",group.get_meta("target"))
			view.set_meta("members",group.get_child_count())
			var mesh:=ArrayMesh.new()
			for material:Material in buckets:
				var bucket:Dictionary=buckets[material]
				var arrays:Array=[]
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX]=bucket.vertices
				arrays[Mesh.ARRAY_NORMAL]=bucket.normals
				arrays[Mesh.ARRAY_INDEX]=bucket.indices
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(mesh.get_surface_count()-1,material)
			view.mesh=mesh
			runtime.add_child(view)
			view.owner=runtime
		var scene:=PackedScene.new()
		if scene.pack(runtime)!=OK or ResourceSaver.save(scene,dest+"/"+id+".scn",ResourceSaver.FLAG_COMPRESS)!=OK:
			quit(2);return
		results[id]=[runtime.get_child_count(),count]
		runtime.free()
		authored.free()
	print("建材與可單獨拆裝分件 ",JSON.stringify(results))
	quit()

