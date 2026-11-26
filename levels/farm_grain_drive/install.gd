extends RefCounted
## 原牆、頭輪、暫存斗保留原破壞識別和支點。只更換帶孔板、卸料槽與相應碰撞。
const UNIT := preload("res://levels/farm_buildings_v31/unit.gd")
const BUILD := preload("res://levels/farm_buildings_r004/install.gd")
const MACHINES := {
	"North":[preload("baked/North.scn"),preload("North.json")],
	"South":[preload("baked/South.scn"),preload("South.json")],
}
const EDIT_MESH := preload("baked/Edits.scn")
const EDIT_DATA := preload("Edits.json")

static func mesh_and_solids(unit:StaticBody3D, art:Node3D, key:String, row:Dictionary) -> void:
	var view:MeshInstance3D=art.get_node(NodePath(key))
	art.remove_child(view);view.name="StockAssembly";unit.add_child(view)
	for i in row.shapes.size():
		BUILD.collision(unit,row.shapes[i],"Solid%d"%i)

static func equipment(farm:Node3D, parent:Node3D, kind:String) -> void:
	var spec:Dictionary=MACHINES[kind][1].data
	var art:Node3D=MACHINES[kind][0].instantiate()
	var rig:=Node3D.new();rig.name="GrainMachinery";parent.add_child(rig)
	for id:String in spec:
		var row:Dictionary=spec[id]
		var body:=UNIT.new()
		body.name=id;rig.add_child(body)
		body.set_meta("component",row.kind);body.set_meta("structure_material",row.material)
		body.set_meta("storey",int(row.level));body.set_meta("ground_anchor",row.get("ground",false))
		body.set_meta("stock_source","res://levels/farm_grain_drive/author/"+kind+".tscn")
		mesh_and_solids(body,art,id,row)
		var seats:Array=[]
		for group:Array in row.seats:
			var paths:Array=[]
			for piece:String in group:
				paths.append(str(rig.get_path_to(farm.get_node(piece.substr(1)))) if piece.begins_with("@") else piece)
			seats.append(paths)
		body.set_meta("support_seats",seats)
	art.free()

static func install(farm:Node3D) -> void:
	var north:=farm.get_node("FarmBuildings004/GrainTransfer")
	if north.has_node("GrainMachinery"):return
	var art:=EDIT_MESH.instantiate()
	for id:String in EDIT_DATA.data:
		var unit:=north.get_node(NodePath(id)) as StaticBody3D
		unit.get_node("StockAssembly").free()
		for shape:CollisionShape3D in unit.find_children("*","CollisionShape3D",false,false):shape.free()
		mesh_and_solids(unit,art,id,EDIT_DATA.data[id])
	art.free()
	equipment(farm,north,"North")
	equipment(farm,farm.get_node("FarmBuildings31/RegistrationRoom/SeedCleaningLoft"),"South")

