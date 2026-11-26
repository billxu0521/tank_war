extends RefCounted
const UNIT=preload("res://levels/farm_buildings_v31/unit.gd")
const STOCK=preload("res://levels/farm_shed_stock/stock.scn")
const CHOCKS=preload("res://levels/farm_stock_assemblies/rooms/NorthwestWagonShed.tscn")
static func make(site:Node3D,key:String,mesh:Mesh,t:Transform3D,seats:Array,mat:Material=null)->StaticBody3D:
	var body:=UNIT.new()
	body.name=key;body.set_meta("support_seats",seats);body.set_meta("ground_anchor",seats.is_empty())
	body.set_meta("structure_material","wood");body.set_meta("component","furniture");body.set_meta("storey",1)
	var view:=MeshInstance3D.new()
	view.name="StockAssembly";view.mesh=mesh;view.transform=t;view.material_override=mat
	body.add_child(view)
	var shape:=CollisionShape3D.new();shape.name="Solid"
	var geometry:=ConcavePolygonShape3D.new()
	var faces:=mesh.get_faces()
	for i in faces.size():faces[i]=t*faces[i]
	geometry.set_faces(faces);shape.shape=geometry;body.add_child(shape)
	site.add_child(body)
	return body
static func retire(old:StaticBody3D):
	old.set_present(false)
	old.get_parent().remove_child(old);old.free()
static func install(farm:Node3D):
	var north:=farm.get_node("FarmBuildings31/NorthwestWagonShed")
	var south:=farm.get_node("FarmBuildings31/SoutheastUnloadingShed")
	if north.has_node("Chock0"):return
	var pieces:=STOCK.instantiate()
	for v:MeshInstance3D in pieces.get_children():
		var label:=str(v.name)
		var is_gate:=label.begins_with("Gate")
		var seats:Array=[] if is_gate else [["Sack0","Sack1"]] if label=="SackTop" else [["ReceivingDeck"]]
		var body:=make(north if is_gate else south,label,v.mesh,v.transform,seats)
		body.set_meta("stock_source","NorthwestWagonShed_r002/WagonGate" if is_gate else "SoutheastUnloadingShed_r003/GrainSacks")
		body.set_meta("stable_id",str(farm.get_path_to(body)))
	pieces.free()
	var template:=CHOCKS.instantiate()
	var i:=0
	for n:Node3D in template.get_node("WheelChocks").get_children():
		var wedge:MeshInstance3D=n.get_node("Part0")
		var body:=make(north,"Chock"+str(i),wedge.mesh,n.transform*wedge.transform,[],wedge.get_active_material(0))
		body.set_meta("stock_source","res://levels/farm_stock_assemblies/stock/wheel_chock.tscn")
		body.set_meta("stable_id",str(farm.get_path_to(body)));i+=1
	template.free()
	retire(north.get_node("WheelChocks"));retire(north.get_node("WagonGate"));retire(south.get_node("GrainSacks"))
