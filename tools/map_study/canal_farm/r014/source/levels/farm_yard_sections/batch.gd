extends RefCounted
const GROUPS:=preload("res://levels/farm_stock_groups/install.gd")

# 同一院牆的石腳原型只有縮放與色料差異。袋身各自共用同款已匯入的網格。
static func collect(root: Node3D, units: Array, masonry: bool) -> void:
	var groups: Dictionary={}
	var views: Array[Node3D]=[]
	var frames: Array[Transform3D]=[]
	var base:=root.global_transform.affine_inverse()
	for unit: Node3D in units:
		var owner_index:=views.size()
		views.append(unit)
		frames.append(Transform3D.IDENTITY)
		for view: MeshInstance3D in unit.find_children("*","MeshInstance3D",true,false):
			var material:=view.get_active_material(0)
			var kind: String=str(view.name) if masonry else str(view.mesh.get_instance_id())
			var key:=kind+"_"+str(material.get_instance_id())
			if not groups.has(key):
				groups[key]={"mesh":view.mesh,"material":material,"owners":PackedInt32Array(),"poses":PackedVector3Array(),"views":[]}
			var group: Dictionary=groups[key]
			var pose:=base*view.global_transform
			if masonry:
				var model: AABB=group.mesh.get_aabb()
				var target:=view.mesh.get_aabb()
				var scale:=target.size/model.size
				pose*=Transform3D(Basis.from_scale(scale),target.position-model.position*scale)
			group.owners.append(owner_index)
			group.poses.append_array(PackedVector3Array([pose.basis.x,pose.basis.y,pose.basis.z,pose.origin]))
			group.views.append(view)
	var holder:=Node3D.new()
	holder.name="StockBatches"
	root.add_child(holder)
	for key: String in groups:
		var group: Dictionary=groups[key]
		var mesh:=MultiMeshInstance3D.new()
		holder.add_child(mesh)
		mesh.material_override=group.material
		mesh.set_meta("owners",group.owners)
		mesh.set_meta("poses",group.poses)
		mesh.set_meta("prototype",group.mesh)
		GROUPS.Batch.new().start(mesh,frames,views)
		for view: MeshInstance3D in group.views: view.hide()
