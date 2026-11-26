extends "res://tools/map_study/farm_trial/farm.gd"
## 建築、田塊、農車與四處場界共用四席母圖的規則點。
const WORKS := preload("res://models/farm_canal_works/canal_works.tscn")
const RECEIVING := preload("res://models/farm_receiving/MilkReceiving.tscn")
const WEST_HOUSE := preload("res://models/farm_receiving/WestToolHouse.tscn")
const PAY_OFFICE := preload("res://models/farm_pay_office/pay_office.tscn")
const WEIGH_ROOM := preload("res://models/farm_weigh_room/registration_room_r004.tscn")
const ENVIRONMENT := preload("res://levels/farm_environment/install.gd")
const LAND := preload("res://tools/map_study/farm_trial/farm_edges.gd")

func place_milk_furniture(shed: Node3D) -> void:
	shed.add_child(RECEIVING.instantiate())

func _ready() -> void:
	super()
	# 排尾兩垛靠北側坡邊待搬，留出繞筐回坡腳的空隙。
	$LoadingStation/WorkingCrates/Stack05.global_position = Vector3(-26,0,40)
	$LoadingStation/WorkingCrates/Stack15.global_position = Vector3(-25.15,0,40)
	for old in ["中橋通過面","西灘閘具房","橋西水車機座","東卸料車架","發薪房屋頂"]:
		$FarmShell.get_node(old).free()
	for i in range(1,9):
		$FarmShell.get_node("中橋板縫 %d" % i).free()
	for row in [[0,3],[1,6],[3,6]]:
		for i in range(1,row[1]+1):
			$LocalGeometry.get_node("Wall%d_%d" % [row[0],i]).free()
	$LocalGeometry/YardProp3_1.free()
	place(WEST_HOUSE,Vector3(-53.5,0,-10.5))
	place(PAY_OFFICE,Vector3(-36,0,-31))
	place(WEIGH_ROOM,Vector3(25.6618,0,26.6635),8.0)
	var works := place(WORKS,Vector3.ZERO)
	for path in ["CenterBridge/Span/Surface","UnloadingRack/Surface"]:
		var surface: StaticBody3D = works.get_node(path)
		surface.collision_layer |= FLOOR_LAYER
		surface.add_to_group(&"ground")
	ENVIRONMENT.install(self)
	LAND.install(self)

func place(scene: PackedScene, p: Vector3, degrees := 0.0) -> Node3D:
	var unit: Node3D = scene.instantiate()
	unit.position = p
	unit.rotation.y = deg_to_rad(degrees)
	add_child(unit)
	return unit
