extends SceneTree
## 從母圖的兩個出生落點，用正式時段及遊戲牛仔鏡頭比較預設朝向與轉看棚內的畫面。
class LightRig extends Node3D:
	var _drift: Node
	var greybox := false
	var settings_path := "res://tools/map_study/farm_trial/preview-default-settings.cfg"

const MAP := preload("res://tools/map_study/farm_trial/farm.tscn")
const GAME := preload("res://main.tscn")
const COWBOY := preload("res://cowboy/cowboy.tscn")
const SITES := [
	["NW","InitialSpawns/NW","NorthwestWagonShed",Vector3(-2.35,1.04,.03)],
	["SE","ReturnZones/SE/Pad3","SoutheastUnloadingShed",Vector3(.59,1.19,.41)]]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_environment("FARM_VIEW_OUT")
	var rendered := DisplayServer.get_name() != "headless"
	if output.is_empty():
		quit(2)
		return
	var viewport: Viewport = root
	if not rendered:
		var frame := SubViewport.new()
		frame.size = Vector2i(1280,720)
		root.add_child(frame)
		viewport = frame
	var rig := LightRig.new()
	viewport.add_child(rig)
	var main := GAME.instantiate()
	var arena = main.get_node("Arena")
	main.remove_child(arena)
	main.free()
	rig.add_child(arena)
	arena._use_sky()
	arena._use_outline()
	Period.snapshot(rig)
	rig.add_child(preload("res://pixel_style.gd").new())
	var farm := MAP.instantiate()
	for item in ["World","Sun","Overview"]:
		farm.get_node(item).free()
	rig.add_child(farm)
	var actor := COWBOY.instantiate()
	var eye: Camera3D = actor.get_node("Head/Camera3D")
	var eye_offset: Transform3D = actor.transform * actor.get_node("Head").transform * eye.transform
	var camera := Camera3D.new()
	camera.near = eye.near
	camera.fov = eye.fov
	camera.keep_aspect = eye.keep_aspect
	actor.free()
	rig.add_child(camera)
	camera.make_current()
	await physics_frame
	await physics_frame
	var stats: Array = []
	var errors := []
	for period_name: StringName in [&"noon",&"sunset",&"midnight"]:
		Period.apply(rig,period_name)
		for site in SITES:
			var spawn: Vector3 = farm.get_node("Anchors/"+site[1]).global_position
			var anchor: Vector3 = farm.floor_hit(spawn.x,spawn.z).position
			var target: Vector3 = farm.get_node(site[2]).to_global(site[3])
			camera.transform = Transform3D(Basis.IDENTITY,anchor)*eye_offset
			var poses := ["default","turned"]
			if site[0] == "NW": poses.append("cart_road")
			for pose in poses:
				if pose == "turned":
					camera.look_at(target)
				elif pose == "cart_road":
					camera.look_at(Vector3(-55,camera.position.y,-73))
				for i in 4: await process_frame
				var key := "%s_%s_%s"%[site[0],period_name,pose]
				var ray := PhysicsRayQueryParameters3D.create(camera.position,target,1)
				var hit: Dictionary = farm.get_world_3d().direct_space_state.intersect_ray(ray)
				var first := str(farm.get_path_to(hit.collider)) if not hit.is_empty() else ""
				var in_view := camera.is_position_in_frustum(target)
				stats.append({"view":key,"in_frame":in_view,"first_hit":first,"angle_deg":snappedf(rad_to_deg((-camera.basis.z).angle_to(camera.position.direction_to(target))),.1),"sun_energy":arena.get_node("Sun").light_energy})
				if pose == "turned" and (not in_view or not first.contains("ParkedWagon" if site[0]=="NW" else "GrainSacks")):
					errors.append(key)
				if rendered:
					await RenderingServer.frame_post_draw
					var img := root.get_texture().get_image()
					if img == null or img.is_empty() or img.save_png(output.path_join(key+".png"))!=OK:
						errors.append(key+" 儲圖")
	var evidence := FileAccess.open(output.path_join("views.json"),FileAccess.WRITE)
	evidence.store_line(JSON.stringify({"rendered":rendered,"viewport_px":[viewport.get_visible_rect().size.x,viewport.get_visible_rect().size.y],"views":stats,"errors":errors},"\t"))
	evidence.close()
	print("SHED_VIEWS ",stats.size()," ",errors)
	rig.free()
	quit(0 if errors.is_empty() else 1)
