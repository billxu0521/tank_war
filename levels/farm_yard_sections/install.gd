extends RefCounted
## 原砌塊、貨袋與車楔具有獨立落點；活動車體留作完整的組裝件。
const UNIT := preload("res://levels/farm_buildings_v31/unit.gd")
const BATCH := preload("batch.gd")
const PALETTE := preload("res://levels/farm_style_buildings/install.gd")
const WALLS := {
	"NorthWall":preload("NorthWall.scn"),
	"WestWall":preload("WestWall.scn"),
	"ShortWall":preload("ShortWall.scn"),
}
const FULL_SACK := preload("FullSack.scn")
const HALF_SACK := preload("HalfSack.scn")

static func install(farm: Node3D) -> void:
	for id: String in WALLS:
		var wall: Node3D=farm.get_node("FarmCanalWorks/"+id)
		if wall.has_node("MasonrySections"): continue
		var kit: Node3D=WALLS[id].instantiate()
		for unit in kit.get_children():
			for view in unit.get_children():
				if not view is MeshInstance3D: continue
				var source: MeshInstance3D=wall.get_node(view.get_meta("source_path","WallFacing"))
				view.material_override=source.get_active_material(view.get_meta("source_slot"))
		wall.get_node("WallFacing").hide()
		wall.get_node("WallCap").hide()
		wall.get_node("Surface").free()
		wall.add_child(kit)
		BATCH.collect(kit,kit.get_children(),true)
	var wagon:=farm.get_node("NortheastWorkyard/HarvestWagon") as Node3D
	if wagon.has_node("WagonBody"): return
	var copy:=unit_at(wagon,"WagonBody","wood",[])
	var original:=wagon.get_node("ParkedWagon") as MeshInstance3D
	for shape: CollisionShape3D in original.find_children("*","CollisionShape3D",true,false):
		copy.collision_layer=shape.get_parent().collision_layer
		shape.reparent(copy,true)
	original.reparent(copy,true)
	split_chocks(wagon,"WheelChocks")
	install_sacks(wagon)
	BATCH.collect(wagon,wagon.find_children("Sack*","StaticBody3D",false,false),false)
	wagon.get_node("GrainLoad").free()
	split_chocks(farm.get_node("FarmCanalWorks/UnloadingRack"),"Chocks")

static func unit_at(parent: Node3D, id: String, family: String, seats: Array) -> StaticBody3D:
	var unit:=UNIT.new()
	unit.name=id
	unit.set_meta("structure_material",family)
	unit.set_meta("component","furniture")
	unit.set_meta("ground_anchor",seats.is_empty())
	unit.set_meta("support_seats",seats)
	parent.add_child(unit)
	return unit

static func split_chocks(parent: Node3D, path: String) -> void:
	var old:=parent.get_node(path) as MeshInstance3D
	var center:=old.mesh.get_aabb().get_center()
	var data:=old.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX]
	if indices.is_empty(): indices=PackedInt32Array(range(points.size()))
	var groups: Dictionary={}
	for t in range(0,indices.size(),3):
		var midpoint: Vector3=(points[indices[t]]+points[indices[t+1]]+points[indices[t+2]])/3.
		var id:="WheelStop%d%d"%[int(midpoint.x>center.x),int(midpoint.z>center.z)]
		if not groups.has(id):
			var builder:=SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[id]=builder
		var builder: SurfaceTool=groups[id]
		for j in 3:
			var ix:=indices[t+j]
			builder.set_normal(normals[ix])
			builder.add_vertex(points[ix])
	for id: String in groups:
		var builder: SurfaceTool=groups[id]
		builder.index()
		var art:=MeshInstance3D.new()
		art.mesh=builder.commit()
		art.material_override=old.get_active_material(0)
		var unit:=unit_at(parent,id,"wood",[])
		unit.transform=old.transform
		unit.add_child(art)
		var shape:=CollisionShape3D.new()
		shape.shape=art.mesh.create_convex_shape()
		unit.add_child(shape)
	old.free()

static func install_sacks(wagon: Node3D) -> void:
	# 原車載料表的四層排法，底層托在車斗，之上依袋身的實際水平交疊找承托。
	var tiers := [
		[[-1.14,-.38,.38,1.14],[-.247,.247],.904,0.],
		[[-1.,-.5,0.,.5,1.],[-.35,.35],1.162,90.],
		[[-.75,0.,.75],[-.247,.247],1.420,0.],
		[[-.37,.36],[0.],1.677,0.],
	]
	var below: Dictionary={}
	var paint: Dictionary={}
	for level in tiers.size():
		var tier: Array=tiers[level]
		var current: Dictionary={}
		for x: float in tier[0]:
			for z: float in tier[1]:
				var id:="Sack%d_%02d"%[level,current.size()]
				var unit:=unit_at(wagon,id,"soft",[])
				unit.position=Vector3(x,tier[2],z)
				unit.rotation.y=deg_to_rad((83. if x<0. else 90.) if level==3 else tier[3])
				var bag: Node3D=(HALF_SACK if level==3 else FULL_SACK).instantiate()
				unit.add_child(bag)
				var points:=PackedVector3Array()
				for item: MeshInstance3D in bag.find_children("*","MeshInstance3D",true,false):
					PALETTE._paint_view(item,paint,"NortheastWorkyard")
					var rel:=unit.global_transform.affine_inverse()*item.global_transform
					points.append_array(rel*item.mesh.get_faces())
				var hull:=ConvexPolygonShape3D.new()
				hull.points=points
				var shape:=CollisionShape3D.new()
				shape.shape=hull
				unit.add_child(shape)
				var box: AABB=unit.transform*hull.get_debug_mesh().get_aabb()
				var feet:=Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
				var seats: Array=[] if level>0 else ["WagonBody"]
				for key: String in below:
					var contact:=feet.intersection(below[key])
					if contact.get_area()>.018: seats.append(key)
				unit.set_meta("support_seats",[seats])
				unit.set_meta("ground_anchor",false)
				current[id]=feet
		below=current

## 原袋四個表面依原色合成一個落件外觀，交給戶外料垛的飛落、停定與重連還原。
static func bind_sacks(registry: Node) -> void:
	var wagon: Node3D = registry.arena.get_node("NortheastWorkyard/HarvestWagon")
	if wagon.has_node("HarvestSacks"): return
	var bags := wagon.find_children("Sack*","StaticBody3D",false,false)
	var site := preload("res://levels/farm_yard_loads/site.gd").new()
	site.setup(registry,"HarvestSacks","soft",bags[0].collision_layer,{},true)
	wagon.add_child(site)
	var meshes := {}
	for unit: StaticBody3D in bags:
		var key := str(registry.arena.get_path_to(unit))
		var bag: Node3D = unit.get_child(0)
		var asset := bag.scene_file_path
		if not meshes.has(asset):
			var merged := ArrayMesh.new()
			for view: MeshInstance3D in bag.find_children("*","MeshInstance3D",true,false):
				var pose := unit.global_transform.affine_inverse()*view.global_transform
				for surface in view.mesh.get_surface_count():
					var builder := SurfaceTool.new()
					builder.append_from(view.mesh,surface,pose)
					builder.set_material(view.get_active_material(surface))
					builder.commit(merged)
			meshes[asset] = merged
		var art: Mesh = meshes[asset]
		var box := art.get_aabb()
		var center := unit.global_transform.translated_local(box.get_center())
		site.parts.append({"entry":registry.entries[key],"seats":[],
			"mesh":art,"paint":null,"size":box.size,"frame":center,
			"relative":Transform3D(Basis(),-box.get_center())})
	site.finish()
