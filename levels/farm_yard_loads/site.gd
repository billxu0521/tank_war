extends StaticBody3D
## 同一料垛共用物理物體。命中由形狀索引對到單件，固定外觀按網格批次繪製。
var registry: Node
var catalog: Dictionary
var parts: Array[Dictionary] = []
var batches := {}
var site_key: String
var family: String

func setup(r:Node, id:String, type:String, layer:int, assets:Dictionary, cushioned:bool) -> void:
	registry = r
	catalog = assets
	site_key = "yardload/" + id
	family = type
	name = id
	collision_layer = layer
	if cushioned: add_to_group(&"soft")

func put(id:String, mesh:Mesh, world:Transform3D, seats:Array, hull:=false, old_instance:=[], material:Material=null, solid_size:=Vector3.ZERO, hulls:=[]) -> String:
	var key := site_key + "/" + id
	var box := mesh.get_aabb()
	var scale3 := world.basis.get_scale().abs()
	var centered := Transform3D(world.basis.orthonormalized(),world*box.get_center())
	var size := (box.size if solid_size==Vector3.ZERO else solid_size) * scale3
	var shapes := []
	if not hulls.is_empty():
		for cloud:Array in hulls:
			var points := PackedVector3Array()
			for a:Array in cloud: points.append(Vector3(a[0],a[1],a[2])*scale3)
			var convex := ConvexPolygonShape3D.new()
			convex.points = points
			shapes.append(convex)
	elif hull:
		var convex := ConvexPolygonShape3D.new()
		var verts := mesh.get_faces()
		for i in verts.size():
			verts[i] = (verts[i]-box.get_center()) * scale3
		convex.points = verts
		shapes.append(convex)
	else:
		var solid := BoxShape3D.new()
		solid.size = size
		shapes.append(solid)
	var collisions := []
	for solid:Shape3D in shapes:
		var child := CollisionShape3D.new()
		child.name = "Hit_%s_%d"%[id,collisions.size()]
		child.shape = solid
		add_child(child)
		child.global_transform = centered
		collisions.append(child)
	var entry:Dictionary = registry.register(key,family,[],collisions)
	if family=="soft" or name==&"FarmCrates":
		entry.yard_bundle = true
	if not old_instance.is_empty():
		entry.instances.append(old_instance)
	else:
		var token := [mesh,material]
		if not batches.has(token): batches[token] = []
		batches[token].append([entry,get_parent().global_transform.affine_inverse()*world])
	parts.append({"entry":entry,"seats":seats,"mesh":mesh,"paint":material,
		"frame":centered,"relative":centered.affine_inverse()*world,"size":size})
	return key

func apply_recipe(name_:String, frame:Transform3D, recipe:Array) -> void:
	var keys:Array[String] = []
	for i in recipe.size():
		var cell:Dictionary = recipe[i]
		var seats := []
		for indices:Array in cell.seats:
			var group := []
			for index in indices: group.append(keys[int(index)])
			seats.append(group)
		var a:Array = cell.p
		var pos := Vector3(a[0],a[1],a[2])
		keys.append(put("%s%03d"%[name_,i], catalog[cell.m],frame*Transform3D(Basis(),pos),seats,cell.convex,[],null,Vector3.ZERO,cell.get("hulls",[])))

static func draw_all(parent:Node3D) -> void:
	var combined := {}
	for site in parent.get_children():
		for token:Array in site.batches:
			var rows:Array = combined.get_or_add(token,[])
			rows.append_array(site.batches[token])
		site.batches.clear()
	for token:Array in combined:
		var rows:Array = combined[token]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = token[0]
		mm.instance_count = rows.size()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = mm
		batch.material_override = token[1]
		parent.add_child(batch)
		var bounds:AABB
		for i in rows.size():
			var xf:Transform3D = rows[i][1]
			mm.set_instance_transform(i,xf)
			var b := xf*mm.mesh.get_aabb()
			bounds = b if i==0 else bounds.merge(b)
			rows[i][0].instances.append([batch,i,xf])
		mm.custom_aabb = bounds

func finish() -> void:
	var bricks := []
	for item:Dictionary in parts:
		var entry:Dictionary=item.entry
		if not item.seats.is_empty(): registry.require_seats(entry.key,item.seats)
		entry.debris_site = site_key
		entry.debris_start = bricks.size()
		entry.debris_end = bricks.size()+1
		bricks.append([global_transform.affine_inverse()*item.frame,item.size,HitRules.level(&"wood"),Color.WHITE,false,&"wood"])
	var home := ToyBuild.make(bricks,false,collision_layer)
	home.name = "LoadDebris_"+str(name)
	home.get_child(0).hide()
	home.can_break = true
	registry.add_child(home)
	home.global_transform = global_transform
	home.set_meta(&"farm_yard_source",self)
	registry.fragments.homes[site_key] = home

## 碎塊沿用現役 ToyBuild 的飛落、停定及復原，畫面換回該捆草或該塊木料。
static func dress_piece(piece:Node) -> void:
	if not piece.has_meta(&"toy_home"): return
	var home:ToyBuild = piece.get_meta(&"toy_home")
	if not is_instance_valid(home) or not home.has_meta(&"farm_yard_source"): return
	var site = home.get_meta(&"farm_yard_source")
	var info:Dictionary = home._info[piece.get_meta(&"toy_key")]
	for view:MultiMeshInstance3D in piece.find_children("*","MultiMeshInstance3D",false,false):
		view.hide()
	if site.is_in_group(&"soft"): piece.add_to_group(&"soft")
	for j in info.m.size():
		var item:Dictionary = site.parts[info.m[j]]
		var view := MeshInstance3D.new()
		view.name = "YardMaterial"+str(j)
		view.mesh = item.mesh
		view.material_override = item.paint
		view.transform = info.rel[j]*item.relative
		piece.add_child(view)

## 緊貼鄰捆的直接命中件從受擊面翻出。失承的鄰件依重力原位掉下。
static func release_edge(fragments, part:Dictionary, at:Vector3, dir:Vector3, power:float) -> bool:
	if not part.has("yard_bundle") or not at.is_finite(): return false
	var cs:CollisionShape3D=part.shapes[0][0]
	var home:ToyBuild=fragments.homes[part.debris_site]
	var idx:int=part.debris_start
	var hit:=cs.to_local(at)
	var half:Vector3=home._size[idx]*.5
	if absf(hit.x)>half.x+.025 or absf(hit.y)>half.y+.025 or absf(hit.z)>half.z+.025: return false
	var offset:=at-cs.global_position
	offset.y=0.
	if offset.length_squared()<.005: return false
	home.release_parts(PackedInt32Array([idx]),cs.global_position,power,dir,offset.normalized()*.28)
	return true
