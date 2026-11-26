extends "res://tools/map_study/farm_trial/field_links.gd"
## 東堤的夯土路面沿用原貼圖。正午仍要能分清堤頂、田路與兩側坡肩。
var levee_ground: MeshInstance3D
var levee_surface_index := -1
var original_override: Material
var noon_soil: StandardMaterial3D
var noon_soil_active := false

func _ready() -> void:
	super()
	levee_ground = get_node(^"FarmShell/場地剖切與渠床") as MeshInstance3D
	for i in levee_ground.mesh.get_surface_count():
		if levee_ground.mesh.surface_get_name(i) != "東堤面":
			continue
		levee_surface_index = i
		original_override = levee_ground.get_surface_override_material(i)
		noon_soil = levee_ground.get_active_material(i).duplicate() as StandardMaterial3D
		noon_soil.albedo_color = Color("#887d68")
		update_levee_soil()
		update_levee_soil.call_deferred()
		return
	set_process(false)

func _process(_delta: float) -> void:
	# 地圖先於大廳讀取時段；主機送來的時段也可能晚於場景建立。
	update_levee_soil()

func update_levee_soil() -> void:
	var use_noon_soil := Period.current == &"noon"
	if use_noon_soil == noon_soil_active:
		return
	noon_soil_active = use_noon_soil
	levee_ground.set_surface_override_material(levee_surface_index, noon_soil if use_noon_soil else original_override)
