extends RefCounted
## 在建築及家具安裝之後、全圖破壞登記之前安裝。
const KIT := "res://levels/farm_eave_seats/"

static func install(farm:Node3D) -> void:
	if farm.has_meta("farm_eave_seats"): return
	var layout:Dictionary=load(KIT+"layout.json").data
	var scenes:Dictionary={}
	for profile:String in layout.cuts:
		scenes[profile]=load(KIT+profile+".tscn")
	for house:String in layout.houses:
		var site:=farm.get_node("FarmBuildings31/"+house) as Node3D
		var end_seats:Dictionary={}
		for row:Dictionary in layout.houses[house]:
			var bay:="RoofBay%d"%int(row.bay)
			var tie:=bay+"Tie"
			var north:=int(row.side)==0
			var id:=bay+("NorthSeat" if north else "SouthSeat")
			var part:StaticBody3D=scenes[row.cut].instantiate()
			part.name=id
			part.position=Vector3(row.position[0],row.position[1],row.position[2])
			part.rotation.y=0.0 if north else PI
			part.set_meta("structure_material","wood")
			part.set_meta("component","support")
			part.set_meta("bay",bay)
			part.set_meta("storey",2)
			part.set_meta("depends_on",PackedStringArray([tie]))
			part.set_meta("support_seats",[[tie]])
			part.add_to_group("farm_building_parts")
			site.add_child(part)
			part.set_meta("stable_id",str(farm.get_path_to(part)))
			if not end_seats.has(bay): end_seats[bay]=[]
			end_seats[bay].append(id)
		for bay:String in end_seats:
			var ends:Array=end_seats[bay]
			var cover:=site.get_node(bay+"Cover")
			cover.set_meta("depends_on",PackedStringArray(ends))
			cover.set_meta("support_seats",[[ends[0]],[ends[1]]])
	farm.set_meta("farm_eave_seats",true)
