extends "res://levels/gate_water/flow_map.gd"

const BUILDINGS := preload("res://levels/farm_style_buildings/install.gd")
const LANDSCAPE := preload("res://levels/farm_style_environment/install.gd")
const OUTDOORS := preload("res://levels/farm_outdoor_r003_r002/install.gd")
const SITES := preload("res://levels/farm_sites/sites.gd")
const REVISED_BUILDINGS := preload("res://levels/farm_buildings_r004/install.gd")
var painted := false

func _ready() -> void:
	super()
	BUILDINGS.install(self)
	LANDSCAPE.install(self)
	preload("res://levels/farm_land_use/install.gd").install(self)
	add_child(preload("res://levels/farm_style/bridge_details.glb").instantiate())
	preload("res://levels/farm_buildings_v31/install.gd").install(self)
	OUTDOORS.install(self, [OUTDOORS.SOUTH_FIELD, OUTDOORS.EAST_FIELD], true)
	preload("res://levels/farm_stock_groups/install.gd").install(self)
	REVISED_BUILDINGS.install(self, {
		"GrainTransfer": SITES.placement(SITES.GRAIN),
		"WheelShop": SITES.placement(SITES.REPAIR),
	})
	preload("res://levels/farm_interior_followup/install.gd").install(self)
	preload("res://levels/farm_interior_followup/upper.gd").install(self)
	preload("res://levels/farm_ground_windows/install.gd").install(self)
	preload("res://levels/farm_world_lettering/install.gd").install(self)
	preload("res://levels/farm_eave_seats/install.gd").install(self)
	preload("res://levels/farm_sites/footprints.gd").install(self)
	preload("res://levels/farm_loading_sections/install.gd").install(self)
	preload("res://levels/farm_roof_sections/install.gd").install(self)
	preload("res://levels/farm_yard_sections/install.gd").install(self)
	preload("res://levels/farm_wharf_sections/install.gd").install(self)
	preload("res://levels/farm_house1_furniture/install.gd").install(self)
	preload("res://levels/farm_shed_stock/install.gd").install(self)
	preload("res://levels/farm_masonry/install.gd").install(self)
	preload("res://levels/farm_large_sections/install.gd").install(self)
	preload("res://levels/farm_house1_sections/install.gd").install(self)
	preload("res://levels/farm_loft_sections/install.gd").install(self)
	preload("res://levels/farm_shed_envelope_r002/install.gd").install(self)
	preload("res://levels/farm_bridge_bearings/install.gd").install(self)
	preload("res://levels/farm_wagon_parts/install.gd").install(self)
	preload("res://levels/farm_grain_drive/install.gd").install(self)
	var damage := preload("res://levels/farm_destruction/registry.gd").install(self)
	REVISED_BUILDINGS.bind_hits(damage)
	preload("res://levels/farm_large_sections/install.gd").bind(damage)
	preload("res://levels/farm_loft_sections/install.gd").bind(damage)
	preload("res://levels/farm_yard_sections/install.gd").bind_sacks(damage)
	preload("res://levels/farm_yard_loads/install.gd").bind_wharf_deck(damage)
	preload("res://levels/farm_north_ditch_trees/install.gd").install(self)
	painted = true

func update_levee_soil() -> void:
	if not painted:
		super()
