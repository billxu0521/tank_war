extends RefCounted
const OPEN := preload("farm.scn")
const COVERED := preload("wharf.scn")
const PIER := preload("res://levels/farm_wharf_sections/install.gd")

static func seats(body:StaticBody3D, refs:Array) -> void:
	body.set_meta("support_seats",refs)
	body.set_meta("ground_anchor",refs.is_empty())

static func install(farm:Node3D) -> void:
	var yard:=farm.get_node("NortheastWorkyard/HarvestWagon")
	if yard.has_node("RunningGear"):return
	var north:=farm.get_node("FarmBuildings31/NorthwestWagonShed")
	var dock:=farm.get_node("FarmCanalWorks/UnloadingRack")
	var proxy:=north.get_node("ParkedWagon")
	proxy.set_present(false)
	for old:CollisionShape3D in proxy.shapes:old.disabled=true
	proxy.free()
	yard.get_node("WagonBody").free()
	dock.get_node("ChockedWagon").free()
	for site:Node3D in [yard,north,dock]:
		var wharf:=site==dock
		var rig:Node3D=(COVERED if wharf else OPEN).instantiate()
		site.add_child(rig)
		if wharf:
			rig.rotation.y=-PI*.5;rig.position=Vector3(.02,.05,-.52)
		elif site==north:rig.position=Vector3(-1.062,0,.03)
		for part:StaticBody3D in rig.get_children():
			var id:=str(part.name)
			var supports:Array=[]
			if id.begins_with("Wheel"):
				if wharf:
					var z:=rig.transform*part.position
					supports=[["../"+PIER.deck_path(PIER.deck_index(z.z))]]
			elif id.begins_with("Axle"):
				var end:=id.right(1)
				supports=[["Wheel"+end+"0","Wheel"+end+"1"]]
			elif id.begins_with("Bolster"):supports=[["Axle"+id.right(1)]]
			elif id.begins_with("Runner") or id.begins_with("Bed"):supports=[["Bolster0"],["Bolster1"]]
			elif id=="Tongue":supports=[["Axle1"]]
			elif id.begins_with("Stake"):supports=[["Bed0" if id.substr(5,1)=="0" else "Bed6"]]
			elif id.begins_with("Cleat"):supports=[["Bed1" if id.right(1)=="0" else "Bed5"]]
			elif id.begins_with("Side"):
				var side:=id.substr(4,1)
				supports=[["Stake"+side+"0","Stake"+side+"1","Stake"+side+"2"]]
			elif id.begins_with("End"):
				var side:=id.substr(3,1)
				supports=[["Cleat"+side+"0","Cleat"+side+"1"]]
			elif id.begins_with("Bow"):supports=[["Side02"],["Side12"]]
			elif id=="Canvas":supports=[["Bow0","Bow1"],["Bow3","Bow4"]]
			seats(part,supports)
	for bag:StaticBody3D in yard.find_children("Sack0_*","StaticBody3D",false,false):
		var shape:CollisionShape3D=bag.find_children("*","CollisionShape3D",false,false)[0]
		var box:AABB=yard.global_transform.affine_inverse()*shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
		var boards:=[]
		for i in 7:
			var z:float=(i-3)*.226
			if minf(box.end.z,z+.112)-maxf(box.position.z,z-.112)>.045:boards.append("RunningGear/Bed%d"%i)
		seats(bag,[boards])

