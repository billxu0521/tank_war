extends "res://levels/farm_buildings_v31/room.gd"

func build_tower() -> void:
	width=6.
	depth=7.
	ground_floor("wood")
	for floor_i in 3:
		level=floor_i+1
		var y:=deck*floor_i
		var windows:Dictionary
		if level==1:
			windows={"S":[[.60,1.52,0,2.27,"slide",1]],"E":[[-1.24,1.04,1.04,2.2,"high"]]}
		elif level==2:
			windows={"E":[[.8,1.24,1.10,2.2,"high"]],"N":[[1.22,1.,1.16,2.16,"light"]]}
		else:
			windows={"E":[[-.8,1.64,1.05,2.3,"high"]],"S":[[1.03,1.27,1.08,2.18,"high"]]}
		for side in ["N","S","E","W"]:
			face(side,windows.get(side,[]),y,y+deck,"wood")
		if floor_i>0:
			var sign_:float=-1. if floor_i==1 else 1.
			var xmin:float=-2.68 if floor_i==1 else -1.16
			var xmax:=xmin+1.44
			var bay:="Work"+str(level)
			var beam:=box(bay+"Tie",Vector3(1.5,y-.23,0),Vector3(.20,.22,6.8),DARK,"frame","wood",bay)
			var anchors:=PackedStringArray()
			for z_:float in [-3.17,3.17]:
				var support_id:=bay+("NorthPost" if z_<0 else "SouthPost")
				box(support_id,Vector3(1.5,y-deck*.5,z_),Vector3(.20,deck-.22,.20),DARK,"support","wood",bay)
				anchors.append(support_id)
			beam.set_meta("depends_on",anchors)
			box(bay+"Floor",Vector3((xmax+3)*.5,y-.09,0),Vector3(3-xmax,.18,7),OAK,"floor","wood",bay,[str(beam.name)])
			box(bay+"Edge",Vector3((-3+xmin)*.5,y-.09,0),Vector3(xmin+3,.18,7),OAK,"floor","wood",bay,[str(beam.name)])
			for end_:float in [-1.,1.]:
				box(bay+("NorthLanding" if end_<0 else "SouthLanding"),Vector3((xmin+xmax)*.5,y-.09,end_*2.95),Vector3(1.44,.18,1.10),END,"floor","wood",bay,[str(beam.name)])
			box(bay+"Guard",Vector3(xmax+.018,y+.91,0),Vector3(.085,.13,4.79),DARK,"frame","wood",bay,[str(beam.name)])
			for z_:float in [-2.28,0,2.28]:
				box(bay+"RailPost"+str(roundi(z_*10)+24),Vector3(xmax+.018,y+.45,z_),Vector3(.075,.9,.075),DARK,"support","wood",bay,[str(beam.name)])
			if floor_i==2:
				# 三樓工作面與收料斗；入口窗檻與護木包住吊運側。
				fit("ReceivingHopper",1.89,-1.45,y,Vector3(1.33,1.04,1.13),"hopper")
			else: fit("GrainScreen",1.87,-.64,y,Vector3(1.43,.91,.93),"screen")
		else:
			fit("BaggingBench",2.09,-1.72,0,Vector3(1.21,.87,.77),"bench")
		if floor_i<2:
			var lane:float=-1.96 if floor_i==0 else -.44
			var dir:float=-1. if floor_i==0 else 1.
			for step in 16:
				var z:float=-dir*2.4+dir*(step+.5)*.30
				box("Flight"+str(level)+"Tread"+str(step+1),Vector3(lane,y+(step+.5)*.18,z),Vector3(1.40,.18,.30),OAK,"floor","wood","Flight"+str(level))
	var arm:=unit("HoistArm","frame","wood","Hoist")
	arm.cuboid(Vector3(2.56,8.08,.80),Vector3(1.72,.20,.20),DARK)
	arm.cuboid(Vector3(2.32,7.68,.80),Vector3(.18,.98,.16),OAK,true,Vector3(0,0,-.58))
	arm.cuboid(Vector3(3.31,7.80,.80),Vector3(.16,.38,.17),IRON)
	arm.cuboid(Vector3(3.31,7.22,.80),Vector3(.033,.86,.033),DARK,false)
	arm.finish()
	roof(3*deck)

