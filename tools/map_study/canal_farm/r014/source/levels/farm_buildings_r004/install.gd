extends RefCounted
## 在現行建材合批之後、母圖破壞登記之前呼叫。新增棟的位置由地圖傳入。
const KIT := "res://levels/farm_buildings_r004/"
const UNIT := preload("res://levels/farm_buildings_v31/unit.gd")
const LEAF := preload("res://levels/farm_buildings_v31/leaf.gd")
const FLOOR := 1<<16
const HIT := 1<<25
static func v(a:Array) -> Vector3: return Vector3(a[0],a[1],a[2])
static func xf(a:Array) -> Transform3D: return Transform3D(v(a[0]),v(a[1]),v(a[2]),v(a[3]))

static func collision(n:Node3D, data:Array, label:String) -> CollisionShape3D:
	var c:=CollisionShape3D.new()
	var b:=BoxShape3D.new()
	b.size=v(data[1]);c.shape=b;c.name=label;c.transform=xf(data[0]);n.add_child(c)
	return c

static func ramp(body:StaticBody3D, original:CollisionShape3D, direction:Vector3, low:float, high:float) -> void:
	# 同一部位的兩個接觸面：腳下斜面和原本踏鼻直面。後者用母圖攻擊遮罩。
	var hit:=StaticBody3D.new();hit.name="TreadProfile";hit.collision_layer=HIT;hit.collision_mask=0;body.add_child(hit)
	var solid:=CollisionShape3D.new();solid.shape=original.shape;solid.transform=original.transform;hit.add_child(solid)
	var b:BoxShape3D=original.shape
	var side:=direction.cross(Vector3.UP)
	var world_size:Vector3=original.transform.basis*b.size
	world_size=world_size.abs()
	var half_width:=absf(side.dot(world_size))*.5
	var half_run:=absf(direction.dot(world_size))*.5
	var center:=original.position
	var pts:=PackedVector3Array()
	for end_:float in [-1.,1.]:
		for edge:float in [-1.,1.]:
			var pt:=center+direction*end_*half_run+side*edge*half_width
			pt.y=low if end_<0 else high
			pts.append(pt);pts.append(pt-Vector3.UP*.08)
	var slope:=ConvexPolygonShape3D.new();slope.points=pts
	original.transform=Transform3D.IDENTITY;original.shape=slope
	original.set_meta("debris_skip",true)
	body.collision_layer|=FLOOR
	body.visibility_changed.connect(func():solid.set_deferred("disabled",not body.is_visible_in_tree()))

static func make_site(farm:Node3D, parent:Node3D, id:String, local:Transform3D) -> Node3D:
	var site:=Node3D.new();site.name=id;site.transform=local;parent.add_child(site)
	var spec:Dictionary=load(KIT+id+".json").data
	var art:Node3D=load(KIT+"baked/"+id+".scn").instantiate()
	for key:String in spec:
		var row:Dictionary=spec[key]
		var n:StaticBody3D
		if row.has("hinge"):
			var h:Array=row.hinge
			var door:=LEAF.new();door.name=key;door.position=v(h[0]);door.rotation.y=h[1]
			door.width=h[2];door.height=h[3];door.shutter=h[4];door.prompt="開窗" if door.shutter else "開門"
			door.travel=row.get("slide",0.)
			n=door;farm._doors.append(door)
		else: n=UNIT.new();n.name=key
		n.set_meta("component",row.kind);n.set_meta("structure_material",row.material);n.set_meta("storey",int(row.level));n.set_meta("bay",key)
		n.set_meta("stock_source",KIT+"author/"+id+".tscn");n.set_meta("ground_anchor",row.get("ground",false))
		if row.has("window_role"):n.set_meta("window_role",row.window_role)
		if row.has("endpoints"):n.set_meta("seat_endpoints",row.endpoints)
		n.add_to_group("farm_building_parts");site.add_child(n)
		n.set_meta("stable_id",str(farm.get_path_to(n)))
		if row.kind=="floor":n.collision_layer|=FLOOR
		var mesh:=art.get_node(NodePath(key)) as MeshInstance3D
		mesh.owner=null;art.remove_child(mesh);mesh.name="StockAssembly";n.add_child(mesh)
		for i in row.shapes.size():
			var c:=collision(n,row.shapes[i],"Solid" if i==0 else "Solid"+str(i))
			if i==0 and row.has("ramp"):
				var r:Array=row.ramp
				ramp(n,c,Vector3(r[0],0,r[1]),r[2],r[3])
	for key:String in spec:
		var n:=site.get_node(NodePath(key))
		var seats:Array=[]
		for group:Array in spec[key].seats:
			var paths:Array=[]
			for entry:String in group:
				if entry.begins_with("@"):
					var target:=farm.get_node_or_null(NodePath(entry.substr(1)))
					if target==null:push_error("必要支點缺件 "+entry);continue
					paths.append(str(site.get_path_to(target)))
				else: paths.append(entry)
			seats.append(paths)
		n.set_meta("support_seats",seats)
	art.free()
	return site

static func install(farm:Node3D, placements:Dictionary={}) -> Node3D:
	var previous:=farm.get_node_or_null("FarmBuildings004") as Node3D
	if previous:return previous
	var holder:=Node3D.new();holder.name="FarmBuildings004";farm.add_child(holder)
	for id:String in ["GrainTransfer","WheelShop"]:
		if placements.has(id):make_site(farm,holder,id,placements[id])
	preload("res://levels/farm_buildings_r004/retrofit.gd").install(farm,holder)
	return holder

static func bind_hits(registry:Node) -> void:
	for k:String in registry.entries:
		var body:Node=registry.entries[k].native
		if not is_instance_valid(body):continue
		var profile:=body.get_node_or_null("TreadProfile")
		if profile:
			for sh in profile.get_children():registry.by_shape[sh]=k
