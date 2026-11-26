extends Egg
## 農莊樓板可拆。由主機依現場承托物決定無人持有的蛋落在哪一層。
const FLOOR_CLEARANCE := 0.5
var fall_speed := 0.0
@onready var game = get_parent()
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or carrier != 0:
		fall_speed = 0.0
		return
	if (game.lobby.visible or game._over or game._practice() or not game.RULES[game.rules].egg
			or game.safe.locked() or (game.party and game.party.phase != &"play")):
		fall_speed = 0.0
		return
	var before := global_position.y
	super._physics_process(delta)
	if global_position.y > before:
		fall_speed = 0.0
		return
	# 剛開箱的蛋由箱頂承托，箱子飛行時由 Safe 帶著它走。
	if game.safe.on and game.safe.open and global_position.distance_squared_to(game.safe._top()) < 0.0001:
		fall_speed = 0.0
		return
	fall_speed += gravity * delta
	var step := fall_speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (step + FLOOR_CLEARANCE + 0.001), 1 | Fighter.SOLID_LAYER)
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	var hit := space.intersect_ray(ray)
	while hit and (game.players.is_ancestor_of(hit.collider) or hit.collider.is_in_group(&"raptor")):
		excluded.append(hit.rid)
		ray.exclude = excluded
		hit = space.intersect_ray(ray)
	if hit:
		global_position.y = hit.position.y + FLOOR_CLEARANCE
		fall_speed = 0.0
	else:
		global_position.y -= step
