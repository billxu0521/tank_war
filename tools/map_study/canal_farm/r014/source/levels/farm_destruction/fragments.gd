extends RefCounted
## 農莊繼續用原件顯示與碰撞；失承後，碎塊交給現役 ToyBuild。
const WAGON := preload("res://levels/farm_wagon_parts/fallen.gd")
const COLORS := {&"wood":Color("#936b48"), &"brick":Color("#ad815c"), &"iron":Color("#646967"), &"stone":Color("#858079")}
var homes := {}
var moving := {}
var fireball_sites := {}
var brick_owners := {}

static func material(part: Dictionary) -> StringName:
	var native: Node = part.native
	var family := str(native.get_meta("structure_material",part.family)) if native else str(part.family)
	match family:
		"brick","adobe","earth": return &"brick"
		"metal","iron": return &"iron"
		"stone": return &"stone"
		_: return &"wood"

func prepare(registry: Node3D) -> void:
	var groups := {}
	var wagon_stock := {}
	registry.child_entered_tree.connect(WAGON.dress)
	var origins := {}
	var opening_frames := {}
	var keys: Array = registry.entries.keys()
	keys.sort()
	for key: String in keys:
		var body: Node = registry.entries[key].native
		if not body or str(body.get_meta("component", "")) not in ["window", "door"]:
			continue
		for seat: Array in registry.support_graph.seats.get(key, []):
			for anchor: String in seat:
				var parent: Node = registry.entries[anchor].native
				if parent and str(parent.get_meta("component", "")) == "frame":
					opening_frames[anchor] = true
	for key: String in keys:
		var part: Dictionary = registry.entries[key]
		var original_mesh: bool = part.native != null and (key.contains("/RunningGear/") or part.native.has_meta("original_debris_mesh"))
		if (part.family in ["soft","glass"] and not original_mesh) or part.nodes.is_empty():
			continue
		var authored: bool = is_instance_valid(part.native) and part.native.has_meta("structure_material")
		if not authored and not key.get_slice("/",0) in ["LoadingStation","PayOffice","MilkStation","RegistrationRoom","FarmCanalWorks","House1Interior"]:
			continue
		var root: Node3D = part.nodes[0][0]
		var location := key.get_slice("/",0)
		if location in ["FarmBuildings31","FarmBuildings004"]:
			location += "/" + key.get_slice("/",1)
		var site := key.get_base_dir() if original_mesh else location
		if root.has_meta("bridge_chip"):
			site += "/Deck"
		var anchor: Node3D = registry.arena.get_node(location)
		if root is Door:
			site = key
			moving[key] = site
		if not groups.has(site):
			groups[site] = []
			origins[site] = root.global_transform if root is Door else Transform3D(Basis(),anchor.global_position)
		var bricks: Array = groups[site]
		var begin := bricks.size()
		var mat := material(part)
		var shutter: Node3D = null
		if authored and str(part.native.get_meta("window_role", "")) == "secured":
			shutter = part.native
		elif authored and str(part.native.get_meta("component", "")) == "window":
			var seats: Array = registry.support_graph.seats.get(key, [])
			if seats.size() == 1 and seats[0].size() == 1:
				var support_node: Node = registry.entries[seats[0][0]].native
				if support_node and str(support_node.get_meta("window_role", "")) == "secured":
					shutter = support_node
		var sealed_mesh: MeshInstance3D
		if shutter:
			var panel: Dictionary = registry.entries[str(registry.arena.get_path_to(shutter))]
			part.shutter_face = panel.shapes[0][0]
			sealed_mesh = part.native.get_node_or_null("StockAssembly")
		if original_mesh:
			WAGON.append(bricks, wagon_stock.get_or_add(site, []), root, origins[site], mat)
			part.wagon_stock = true
		elif sealed_mesh and sealed_mesh.mesh:
			# 通行碰撞把整面窗視為一片。碎塊按封板和木條的模型取樣，以免整窗寬的碎板夾在窗框。
			_append_surface(bricks, sealed_mesh.mesh.get_faces(), origins[site].affine_inverse()*sealed_mesh.global_transform, mat, Vector3(.48,.52,.48))
		elif root.has_meta("bridge_chip"):
			var chip:AABB = root.get_meta("bridge_chip")
			var frame:Transform3D = origins[site].affine_inverse()*root.global_transform
			bricks.append([frame.translated_local(chip.get_center()),chip.size,HitRules.level(mat),COLORS[mat],false,mat])
		else:
			for pair: Array in part.shapes:
				if not pair[1] and not pair[0].get_meta("debris_skip",false):
					_append_shape(bricks,pair[0],origins[site],mat)
		var profile := root.get_node_or_null("TreadProfile")
		if profile:
			for shape: Node in profile.get_children():
				if shape is CollisionShape3D and not shape.disabled:
					_append_shape(bricks,shape,origins[site],mat)
		if bricks.size() == begin and authored:
			# 窗邊飾條與固定釘只有共用建材的畫面，沒有獨立實體碰撞。
			var art := root.get_node_or_null("StockAssembly") as MeshInstance3D
			if art and art.mesh:
				_append_surface(bricks,art.mesh.get_faces(),origins[site].affine_inverse()*art.global_transform,mat)
		if bricks.size() > begin:
			# 活動扇、獨立封板（含兩面木條）、承扇窗框，各有自己的命中單位。
			# 同一單位內受擊會傳到鄰件；承座真的打落時仍交回整棟的失承判定。
			if shutter:
				part.fireball_unit = str(registry.arena.get_path_to(shutter))
			elif opening_frames.has(key) or (authored and str(part.native.get_meta("component", "")) in ["window", "door"]):
				part.fireball_unit = key
			var building := location.get_file().trim_prefix("Extra") if location.contains("/") else location
			var sites: Array = fireball_sites.get_or_add(building, [])
			if site not in sites:
				sites.append(site)
			var owners: Array = brick_owners.get_or_add(site, [])
			var centers := AABB(bricks[begin][0].origin, Vector3.ZERO)
			for i in range(begin, bricks.size()):
				owners.append(key)
				centers = centers.expand(bricks[i][0].origin)
			part.fireball_center = centers.get_center()
			part.fireball_building = building
			part.debris_site = site
			part.debris_start = begin
			part.debris_end = bricks.size()
	for site: String in groups:
		if groups[site].is_empty():
			continue
		var home := ToyBuild.make(groups[site],false)
		home.name = "Debris_" + site.replace("/","_")
		home.get_child(0).hide()
		registry.add_child(home)
		home.global_transform = origins[site]
		# 原件的形狀已承接所有命中。碎塊使用現役材質與碰撞層。
		home.can_break = true
		if wagon_stock.has(site):
			home.set_meta(&"farm_wagon_stock", wagon_stock[site])
		homes[site] = home

static func _append_shape(bricks: Array, cs: CollisionShape3D, origin: Transform3D, mat: StringName) -> void:
	var xf := origin.affine_inverse() * cs.global_transform
	if cs.shape is ConcavePolygonShape3D:
		_append_surface(bricks,cs.shape.get_faces(),xf,mat)
		return
	var box := AABB()
	var prism := PackedVector2Array()
	var axis := -1
	if cs.shape is BoxShape3D:
		var size: Vector3 = cs.shape.size
		box = AABB(-size*.5,size)
	elif cs.shape is ConvexPolygonShape3D:
		var points: PackedVector3Array = cs.shape.points
		if points.is_empty(): return
		box = AABB(points[0],Vector3.ZERO)
		for p: Vector3 in points:
			box = box.expand(p)
		# 坡道與山牆是三角柱，碎塊只從斜面內的材積產生。
		for a in 3:
			var projected := PackedVector2Array()
			for p: Vector3 in points:
				var uv := Vector2(p[(a+1)%3],p[(a+2)%3])
				if not uv in projected: projected.append(uv)
			if projected.size() == 3:
				prism = projected
				axis = a
				break
	else:
		return
	var level := HitRules.level(mat)
	for brick: Array in Greybox.bricks([[Transform3D(Basis(),box.get_center()),box.size,level,0]],Vector3.ZERO,level):
		var center: Vector3 = brick[0].origin
		if axis >= 0 and not Geometry2D.is_point_in_polygon(Vector2(center[(axis+1)%3],center[(axis+2)%3]),prism):
			continue
		var dims: Vector3 = brick[1] * xf.basis.get_scale().abs()
		bricks.append([Transform3D(xf.basis.orthonormalized(),xf*center),dims,level,COLORS[mat],false,mat])

## 保留舊棚的柱、敞開跨與薄屋頂。只為三角面實際穿過的格子建立碎塊，
## 每格的厚度取自裁切後的原件表面，避免整跨空間被當成一整面實牆。
static func _append_surface(bricks: Array, faces: PackedVector3Array, xf: Transform3D, mat: StringName, pitch := Vector3(Greybox.BRICK_W,Greybox.BRICK_H,Greybox.BRICK_W)) -> void:
	var cells := {}
	for i in range(0,faces.size(),3):
		var tri := PackedVector3Array([faces[i],faces[i+1],faces[i+2]])
		var lo := Vector3i((tri[0].min(tri[1]).min(tri[2])/pitch).floor())
		var hi := Vector3i((tri[0].max(tri[1]).max(tri[2])/pitch).floor())
		for x in range(lo.x,hi.x+1):
			for y in range(lo.y,hi.y+1):
				for z in range(lo.z,hi.z+1):
					var id := Vector3i(x,y,z)
					var corner := Vector3(id)*pitch
					var polygon := tri
					for axis in 3:
						if lo[axis] == hi[axis]: continue
						var normal := Vector3.ZERO
						normal[axis] = 1.0
						polygon = Geometry3D.clip_polygon(polygon,Plane(-normal,-corner[axis]))
						if polygon.size() < 3: break
						polygon = Geometry3D.clip_polygon(polygon,Plane(normal,corner[axis]+pitch[axis]))
						if polygon.size() < 3: break
					if polygon.size() < 3: continue
					var bounds: AABB = cells.get(id,AABB(polygon[0],Vector3.ZERO))
					for vertex in polygon: bounds = bounds.expand(vertex)
					cells[id] = bounds
	var order := cells.keys()
	order.sort()
	var level := HitRules.level(mat)
	for id: Vector3i in order:
		var bounds: AABB = cells[id]
		# 純共面貼飾仍有極薄的碎形。大塊、散落與落點沿用 ToyBuild。
		var size: Vector3 = bounds.size.max(Vector3.ONE*.018)*xf.basis.get_scale().abs()
		bricks.append([Transform3D(xf.basis.orthonormalized(),xf*bounds.get_center()),size,level,COLORS[mat],false,mat])

func fireball_parts(part: Dictionary, entries: Dictionary, at: Vector3, reach: float) -> Dictionary:
	var keys := {}
	if not part.has("fireball_building") or reach <= 0.0:
		keys[part.key] = true
		return keys
	if part.get("wagon_stock", false):
		keys[part.key] = true
	var extent := Vector3.ONE * reach
	var box := AABB(at - extent, extent * 2.0)
	var scope: String = part.get("fireball_unit", "")
	for site: String in fireball_sites[part.fireball_building]:
		var home: ToyBuild = homes[site]
		if moving.has(site):
			# 活動窗在打落前使用原件的即時姿勢。
			if not home.has_damage():
				home.global_transform = entries[site].nodes[0][0].global_transform
		for i in home.bricks_near(box):
			if not home.is_standing(i) or home.center_of(i).distance_squared_to(at) >= reach * reach:
				continue
			var key: String = brick_owners[site][i]
			var neighbor: Dictionary = entries[key]
			if neighbor.get("fireball_unit", "") != scope:
				continue
			# 原件的整根梁／整片牆共用一條耐久。只擦到鄰梁一端，不能整梁受擊。
			if key == part.key or home.to_global(neighbor.fireball_center).distance_squared_to(at) < reach * reach:
				keys[key] = true
	return keys

func moving_poses(fallen: Dictionary, entries: Dictionary) -> Dictionary:
	var poses := {}
	for key: String in fallen:
		if moving.has(key) and homes.has(moving[key]):
			poses[moving[key]] = entries[key].nodes[0][0].global_transform
	return poses

func set_poses(poses: Dictionary) -> void:
	for site: String in poses:
		if homes.has(site):
			homes[site].global_transform = poses[site]

func release(fallen: Dictionary, entries: Dictionary, at: Vector3, dir: Vector3, power: float, bite_faces := {}) -> void:
	var by_site := {}
	for key: String in fallen:
		var part: Dictionary = entries[key]
		if part.has("infill"):
			# 牆腳或固定框被拔掉，剩餘原生木板走自己的掉落與多人同步；先前打落的不重生。
			var timber:ToyBuild=part.infill
			var standing:=PackedInt32Array()
			for i in timber.brick_count():
				if timber.is_standing(i): standing.append(i)
			timber.release_parts(standing,at,power,dir)
		if not part.has("debris_site"): continue
		if part.get("debris_site","") == "yardload/FarmCrates" and bite_faces.has(key):
			# 外排空箱被咬住時往外翻，免得所有落箱重新擠回原列。失承帶落的箱照常落下。
			var face: Vector3 = bite_faces[key]
			face.y = 0.0
			var outward := face.normalized() if face.length_squared() > 0.01 else -dir
			var crate: ToyBuild = homes[part.debris_site]
			var center: Vector3 = part.shapes[0][0].global_position
			crate.release_parts(PackedInt32Array([part.debris_start]),center,power,outward,outward*.28)
			continue
		if part.has("yard_bundle") and preload("res://levels/farm_yard_loads/site.gd").release_edge(self,part,at,dir,power): continue
		if part.has("shutter_face"):
			var shape: CollisionShape3D = part.shutter_face
			var normal := shape.global_basis.z.normalized()
			if normal.dot(at-shape.global_position) < 0.0:
				normal = -normal
			var source := shape.global_position + normal
			var pieces := PackedInt32Array(range(part.debris_start, part.debris_end))
			# 窗板崩出窗槽再起算碰撞。用相同的初始位移交給會飛與直接落地兩種現役模式。
			homes[part.debris_site].release_parts(pieces, source, power, dir, -normal*.34)
			continue
		if not by_site.has(part.debris_site):
			by_site[part.debris_site] = PackedInt32Array()
		for i in range(part.debris_start,part.debris_end):
			by_site[part.debris_site].append(i)
	for site: String in by_site:
		homes[site].release_parts(by_site[site],at,power,dir)

func send_state_to(peer: int) -> void:
	for home: ToyBuild in homes.values():
		if home.has_damage():
			home.send_state_to(peer)

func restore() -> void:
	for home: ToyBuild in homes.values():
		if home.has_damage():
			home.restore()
