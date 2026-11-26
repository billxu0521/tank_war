extends RefCounted
## 插在 r009 破壞登記整理承座後、建立碎件前。舊整垛碰撞只在本輪場景退場。
const Site := preload("site.gd")
const RECIPES := preload("recipes.json")
const ART := preload("parts.glb")
const WOOD := ["農舍北側柴垛","北站後場木料","南場農車備柴","南田筐料板垛","北集乳車路木料"]
const STOCK := ["YardStack","ApproachStock","TeamStock","NorthStock","StoredFeed","FarmCrates"]
const STONE_POS := [Vector2(75,-75),Vector2(77.55,-75.45)]
var assets := {}
var r:Node
var container:Node3D
var boxes := {}

static func field_stone(body:StaticBody3D) -> bool:
	if body.get_meta(&"farm_field_stone","") != "北圍田清石": return false
	var p := Vector2(body.global_position.x,body.global_position.z)
	for i in STONE_POS.size():
		if p.distance_to(STONE_POS[i])<.03:
			body.set_meta(&"farm_stone_role","loose" if i==1 else "fixed")
			body.add_to_group(&"stone")
			return true
	return false

static func install(registry:Node) -> void:
	if registry.arena.has_node("YardLoadSites"): return
	var builder := new()
	builder.build(registry)

func build(registry:Node) -> void:
	r = registry
	container = Node3D.new()
	container.name = "YardLoadSites"
	r.arena.add_child(container)
	var bank := ART.instantiate()
	var pigment := StandardMaterial3D.new()
	pigment.resource_name = "農莊料垛霧面色漆"
	pigment.vertex_color_use_as_albedo = true
	pigment.vertex_color_is_srgb = false
	pigment.roughness = .87
	pigment.metallic_specular = .23
	pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
	for item:MeshInstance3D in bank.find_children("*","MeshInstance3D",true,false):
		var mesh := item.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count(): mesh.surface_set_material(i,pigment)
		assets[str(item.name)] = mesh
	bank.free()
	r.child_entered_tree.connect(Site.dress_piece)
	var round_keys:Array[String] = []
	var square_groups := {}
	for key:String in r.entries.keys():
		if key.begins_with("bale/"):
			round_keys.append(key)
		elif key.begins_with("hay/") and not r.entries[key].instances.is_empty():
			var batch:MultiMeshInstance3D = r.entries[key].instances[0][0]
			if not square_groups.has(batch): square_groups[batch]=[]
			square_groups[batch].append(key)
		elif key.begins_with("clutters_LogPile/"):
			var p:Dictionary = r.entries[key]
			var art:MeshInstance3D = p.nodes[0][0].find_children("*","MeshInstance3D",true,false)[0]
			var site := open_site("Logs_"+coordinate(art.global_position),"wood",p)
			site.apply_recipe("Log",art.global_transform,RECIPES.data.LogPile)
			close_old(key)
			site.finish()
	for batch in square_groups: square_bales(square_groups[batch])
	while not round_keys.is_empty():
		# 原方位相同、相接的雙捲與上層捲合成一座草垛。隔開的單捲獨立留在原位。
		var group:Array[String] = [round_keys.pop_back()]
		var i := 0
		while i<group.size():
			var old:Node3D = r.entries[group[i]].nodes[0][0]
			for other:String in round_keys.duplicate():
				var neighbor:Node3D = r.entries[other].nodes[0][0]
				var d := neighbor.global_position-old.global_position
				if absf(angle_difference(old.rotation.y,neighbor.rotation.y))<.02 and Vector2(d.x,d.z).length()<=1.43 and absf(d.y)<1.28:
					group.append(other)
					round_keys.erase(other)
			i+=1
		loose_stack(group)
	for i in WOOD.size():
		if r.entries.has(WOOD[i]): board_stack(WOOD[i],i)
	for label:String in STOCK:
		var key := "stock/"+label
		if not r.entries.has(key): continue
		var p:Dictionary=r.entries[key]
		var art:MeshInstance3D = p.nodes[0][0]
		var site := open_site(label,p.family,p)
		site.apply_recipe("Piece",art.global_transform,RECIPES.data[label])
		close_old(key)
		site.finish()
	var unloading := "FarmCanalWorks/UnloadingRack/"
	for id:String in ["SpareGateBoards","WharfStock"]:
		var yard := id=="SpareGateBoards"
		var key := "StoredGateBoards" if yard else unloading+"Stock"
		if not r.entries.has(key): continue
		var p:Dictionary = r.entries[key]
		var rack:Node3D = r.arena.get_node("StoredGateBoards/Stock" if yard else unloading+"Stock")
		var site := open_site(id,"wood",p)
		site.apply_recipe("Rack",rack.global_transform,RECIPES.data.RailRack)
		close_old(key)
		if not yard: close_old(unloading+"Trestles")
		site.finish()
	Site.draw_all(container)
	bind_wharf_deck(r)

## 兩套接入先後可互換。新版面板建好後再呼叫一次，以實際兩個腳掌接觸面重綁。
static func bind_wharf_deck(registry:Node) -> Dictionary:
	var base := "FarmCanalWorks/UnloadingRack/"
	var rack:Node3D = registry.arena.get_node(base.trim_suffix("/"))
	var segmented:=true
	for j in 30:
		if not registry.entries.has(base+"WharfSections/Deck%02d"%j):
			segmented=false
			break
	var result := {}
	for i in 4:
		var key := "yardload/WharfStock/Rack%03d"%i
		if not registry.entries.has(key): continue
		var seats := []
		var feet := []
		for row:Array in registry.entries[key].shapes:
			var cs:CollisionShape3D=row[0]
			var bounds:AABB
			var first:=true
			for pt:Vector3 in cs.shape.points:
				var q:=rack.to_local(cs.to_global(pt))
				if first: bounds=AABB(q,Vector3.ZERO); first=false
				else: bounds=bounds.expand(q)
			if bounds.size.x>.2 or bounds.size.y<1.: continue
			var contact := []
			for board in 30:
				var lo := -3.5+board*7./30.
				if minf(lo+7./30.-.003,bounds.end.z)-maxf(lo+.003,bounds.position.z)>.012:
					contact.append(base+"WharfSections/Deck%02d"%board)
			feet.append([bounds.get_center().x,bounds.position.y,bounds.get_center().z,contact])
			if segmented: seats.append(contact)
			elif registry.entries.has(base+"WharfDeck"): seats.append([base+"WharfDeck"])
		if seats.size()==2: registry.require_seats(key,seats)
		result[key]=feet
	return result

static func coordinate(p:Vector3) -> String:
	return "%d_%d"%[roundi(p.x*100),roundi(p.z*100)]

func open_site(id:String, family:String, old:Dictionary) -> Site:
	var col:CollisionShape3D = old.shapes[0][0]
	var body := col.get_parent() as CollisionObject3D
	var site := Site.new()
	site.setup(r,id,family,body.collision_layer,assets,body.is_in_group(&"soft"))
	container.add_child(site)
	site.global_position = col.global_position
	return site

func close_old(key:String, keep_instances:=false) -> void:
	var part:Dictionary = r.entries[key]
	r.require_seats(key,[])
	for v:Array in part.nodes: v[0].hide()
	for v:Array in part.shapes:
		v[0].disabled = true
		r.by_shape.erase(v[0])
	if not keep_instances:
		for v:Array in part.instances:
			v[0].multimesh.set_instance_transform(v[1],Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	r.entries.erase(key)

func square_bales(keys:Array) -> void:
	var old:Dictionary = r.entries[keys[0]]
	var id := "SouthHay" if old.shapes[0][0].global_position.x<0 else "CartHay"
	var site := open_site(id,"soft",old)
	var items := []
	for key:String in keys: items.append_array(r.entries[key].instances)
	items.sort_custom(func(a,b):return a[1]<b[1])
	var below := {}
	for item:Array in items:
		var batch:MultiMeshInstance3D=item[0]
		var xf:Transform3D=batch.global_transform*item[2]
		var col := coordinate(xf.origin)
		var seats := [[below[col]]] if below.has(col) else []
		var mesh := batch.multimesh.mesh
		below[col] = site.put("B%03d"%item[1],mesh,xf,seats,false,item,batch.material_override,r.arena.HAY_BLOCK)
	for key:String in keys: close_old(key,true)
	site.finish()

func loose_stack(keys:Array[String]) -> void:
	keys.sort()
	var old:Dictionary = r.entries[keys[0]]
	var body:Node3D = old.nodes[0][0]
	var pose := Transform3D(Basis(Vector3.UP,body.rotation.y),body.global_position)
	var bounds := AABB()
	for i in keys.size():
		var p:Vector3 = pose.affine_inverse()*r.entries[keys[i]].nodes[0][0].global_position
		var box := AABB(p-Vector3(.65,.7,.7),Vector3(1.30,1.40,1.40))
		bounds = box if i==0 else bounds.merge(box)
	var bottom := bounds.get_center()-Vector3.UP*bounds.size.y*.5
	var world := pose*Transform3D(Basis.from_scale(bounds.size),bottom)
	var site := open_site("Loose_"+coordinate(world.origin),"soft",old)
	site.apply_recipe("Fork",world,RECIPES.data.LooseStack)
	for key:String in keys: close_old(key)
	site.finish()

func board_stack(key:String, number:int) -> void:
	var old:Dictionary=r.entries[key]
	var rack:Node3D=old.nodes[0][0]
	var site := open_site("Timber%d"%number,"wood",old)
	var views := rack.find_children("*","MeshInstance3D",false,false)
	for side in 2:
		var feet:Array[String]=[]
		var rows:Array[MeshInstance3D]=[]
		for vis:MeshInstance3D in views:
			if (vis.position.x>1.4) != (side==1): continue
			var size:Vector3=vis.mesh.size
			if size.x<.3:
				feet.append(site.put("S%dFoot%d"%[side,feet.size()],vis.mesh,vis.global_transform,[],false,[],vis.get_active_material(0)))
			else:
				rows.append(vis)
		rows.sort_custom(func(a,b):return a.position.y<b.position.y)
		var last := {}
		for tier in rows.size():
			var view := rows[tier]
			var line:Vector3 = view.mesh.size
			var size := Vector3(line.x,line.y,line.z/3.0-.014)
			if not boxes.has(size):
				var mesh := BoxMesh.new()
				mesh.size=size
				boxes[size]=mesh
			for strip in 3:
				var seats := [[last[strip]]] if last.has(strip) else [[feet[0]],[feet[1]]]
				var xf := view.global_transform.translated_local(Vector3.BACK*((strip-1)*line.z/3.0))
				last[strip]=site.put("S%dRow%dBoard%d"%[side,tier,strip],boxes[size],xf,seats,false,[],view.get_active_material(0))
	close_old(key)
	site.finish()
