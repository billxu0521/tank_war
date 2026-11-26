extends RefCounted
const ROOM:=preload("res://levels/farm_buildings_v31/room.gd")
const WORKS:=preload("res://levels/farm_buildings_v31/works.gd")
const SITES:=preload("res://levels/farm_buildings_v31/sites.json")
const PLACES:=preload("res://levels/farm_style_buildings/placement.json")
const NORTH:=preload("res://levels/farm_house1_r002/install.gd")
const STOCK:={"YardHouse":[12,2.9,3.2,"N",0.,1.4,"slide"],"YardStore":[3.84,3.4,2.7,"S",0.,1.1,"slide"],"ToolStore":[5,5,3.2,"S",-1.1,1.4,"slide"],"GateStore":[5,8,3.35,"S",0.,3.48,"pairhinge"],"WestToolHouse":[3,3,2.60,"E",0.,1.05,"swing"],"EastGageHouse":[4.5,6,3.12,"S",-.93,1.23,"swing"]}

static func retire(n:Node) -> void:
	if not n: return
	if n is Node3D: n.visible=false
	if n is CollisionShape3D: n.disabled=true
	for c in n.get_children(): retire(c)

static func house(room:Node3D,id:String) -> void:
	if id in ["NortheastFarmhouse","House5","House7"]:
		room.study_upper(id!="House5",id=="House7")
		return
	if STOCK.has(id):
		var data:Array=STOCK[id]
		var faces:Dictionary={}
		faces[data[3]]=[[data[4],data[5],0.,2.21,data[6]]]
		var furniture:Array
		match id:
			"YardHouse":
				faces.N.append([3.46,1.38,1.1,2.1,"service",1])
				furniture=[["ReceiptCounter",3.5,-.87,1.7,.85,.55,"table"],["LedgerShelf",-3.9,.98,1.65,1.43,.42,"rack"]]
			"YardStore": furniture=[["TwineShelf",-1.1,-1.20,.94,1.35,.45,"rack"]]
			"ToolStore": furniture=[["RepairBench",.85,-1.92,2.04,.85,.77,"table"],["ToolShelf",-1.87,-.60,.48,1.56,1.54,"rack"]]
			"GateStore": furniture=[["ClampBench",1.89,-2.61,.66,.86,1.62,"table"],["StoredPlanks",-2.16,-1.16,.42,1.40,3.15,"rack"],["CanalSpareBoards",-2.71,-.93,.40,1.54,3.12,"rack"]]
			"WestToolHouse": furniture=[["ToolRack",-.97,.15,.43,1.46,1.36,"rack"],["BankWorkBench",.02,-1.76,1.53,.81,.45,"table"]]
			"EastGageHouse":
				faces.N=[[.61,.91,1.17,2.15,"high"]]
				furniture=[["RecordDesk",1.68,-1.58,.62,.85,1.56,"table"],["MeasuringRodRack",2.45,-.38,.24,1.62,1.21,"rack"]]
		room.single(data[0],data[1],data[2],"wood",faces,furniture)
		return
	var h2:=id=="House2"
	var h6:=id=="House6"
	var w:=12. if h2 else (13. if h6 else 11.)
	var front:="S" if h6 else "N"
	var back:="N" if h6 else "S"
	var doors:Dictionary={}
	doors[front]=[[-.22*w,1.4,0,2.28,"swing"],[2.54,1.27,1.03,2.20,"shutter"]]
	doors[back]=[[.25,1.44,.86,2.54,"pane"]]
	doors.E=[[1.04,1.14,1.18,2.16,"high"]]
	doors.W=[[-.88,1.12,1.06,2.12,"board"]]
	var fits:Array
	if h2:
		fits=[["MilkWashBench",3.6,-3.45,1.86,.87,.67,"table"],["MilkDryingRack",-5.34,.74,.6,1.39,1.42,"rack"],["Bed",-3.75,2.66,1.30,.6,2.03,"bed"],["ClothesChest",3.85,2.97,1.26,.63,.66,"chest"]]
	elif h6:
		fits=[["BreadOven",-5.43,-2.95,1.53,1.05,.97,"hearth"],["CookTable",-3.87,-3.34,1.48,.86,.67,"table"],["MessTable",4.07,2.60,2.48,.85,.78,"table"],["NightBed",5.20,-2.24,1.05,.62,2.03,"bed"]]
	else:
		fits=[["Cot",-4.38,1.96,1.27,.60,2.03,"bed"],["MendingTable",4.80,-.92,.71,.84,1.47,"table"],["LinenChest",-4.23,-2.95,1.32,.64,.60,"chest"]]
	room.single(w,8,3.42,"brick",doors,fits)
	if h6:
		var screen=room.unit("NightScreen","wall","wood","BedAlcove")
		screen.cuboid(Vector3(3.74,.77,-2.45),Vector3(.09,1.54,1.73),ROOM.OAK)
		screen.cuboid(Vector3(3.74,1.56,-2.45),Vector3(.13,.075,1.78),ROOM.DARK,false)
		screen.finish()

static func install(farm:Node3D) -> void:
	if farm.has_node("FarmBuildings31"): return
	if not farm.has_node("FarmStyleBuildings"):
		if not farm.is_node_ready():
			farm.ready.connect(install.bind(farm),CONNECT_ONE_SHOT)
		else: push_error("建築套件需在 FarmStyleBuildings 之後安裝。")
		return
	NORTH.install(farm)
	var group:=Node3D.new()
	group.name="FarmBuildings31"
	farm.add_child(group)
	var jobs:Dictionary={}
	for row:Dictionary in PLACES.data: jobs[row.model]=row
	for spec:Array in SITES.data:
		var id:String=spec[0]
		var site:=ROOM.new()
		site.name=id
		site.farm=farm
		site.purpose=spec[1]
		site.set_meta("use",spec[1])
		site.set_meta("exterior_by_storey",spec[2])
		site.set_meta("levels",spec[3])
		group.add_child(site)
		if id=="House1":
			site.global_transform=farm.get_node("House1Interior").global_transform
			WORKS.house_one(farm,site)
		elif id in ["PayOffice","RegistrationRoom","MilkStation","NorthwestWagonShed","SoutheastUnloadingShed"]:
			site.global_transform=farm.get_node(id).global_transform
			WORKS.service(farm,site,id)
		else:
			var source:Node3D
			if jobs.has(id):
				var art:=farm.get_node("FarmStyleBuildings/"+id) as Node3D
				source=farm.get_node(jobs[id].targets[0])
				site.global_transform=art.global_transform
				art.hide()
			else:
				source=farm.get_node(id)
				site.global_transform=source.global_transform
			retire(source)
			house(site,id)
	WORKS.bridge(farm,group)
	WORKS.boundaries(farm,group)
	for part in farm.get_tree().get_nodes_in_group("farm_building_parts"):
		if farm.is_ancestor_of(part):
			part.set_meta("stable_id",str(farm.get_path_to(part)))
	group.set_meta("building_count",SITES.data.size())

