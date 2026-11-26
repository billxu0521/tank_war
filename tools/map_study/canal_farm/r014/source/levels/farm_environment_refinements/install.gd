extends Node3D
const STONES:=preload("stones.gd")
const TREES:=preload("trees.gd")
const RIDGE:=preload("ridge.gd")
const COVER:=preload("cover.gd")
const ORCHARD:=preload("orchard.res")
static func install(farm:Node3D) -> void:
	if farm.has_node(^"FarmLocalEnvironment"): return
	if not farm.has_node(^"FarmStyleEnvironment") or not farm.has_node(^"北地分水埂"):
		push_error("局部環境包需在 A v3.0 場地生成後接入")
		return
	var piece:=new()
	piece.name=&"FarmLocalEnvironment"
	farm.add_child(piece)
	piece.build(farm)

func build(farm:Node3D) -> void:
	var shell:=farm.get_node(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	for i in shell.mesh.get_surface_count():
		if shell.mesh.surface_get_name(i)=="田間地表與農路":
			var soil:=shell.get_active_material(i).duplicate() as ShaderMaterial
			soil.set_shader_parameter(&"soil_map",ImageTexture.create_from_image(ORCHARD))
			shell.set_surface_override_material(i,soil)
	var bank:=farm.get_node(^"北地分水埂")
	var shape:=RIDGE.make(farm)
	(bank.find_children("*","MeshInstance3D",false,false)[0] as MeshInstance3D).mesh=shape
	(bank.find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D).shape=shape.create_trimesh_shape()
	set_meta(&"tree_results",TREES.install(farm))
	# 場地首次建置需要讓新登記的渠岸與田肩先進入物理空間，再對每一塊石及草根落點。
	for spec:Array in [["CanalReeds",Vector2(-30,5.95),true],["OrchardHedge",Vector2(-42,63),false]]:
		var cover:=COVER.new()
		cover.name=spec[0]
		add_child(cover)
		cover.register(farm,spec[1])
	finalize.call_deferred(farm)

func finalize(farm:Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_meta(&"stone_results",STONES.install(farm))
	for cover in get_children():
		cover.grow(cover.name==&"CanalReeds")
	set_meta(&"ready_for_review",true)
