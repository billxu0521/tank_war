extends RefCounted
## 高處通風窗的兩面仍由同一扇和正式互動鍵控制。
static func install(farm:Node3D) -> void:
	for path:String in ["FarmBuildings31/NortheastFarmhouse/S2Opening0LeafL",
			"FarmBuildings31/RegistrationRoom/SeedCleaningLoft/S3Opening0LeafL"]:
		farm.get_node(path).set_meta("opening_angle",deg_to_rad(28.))
