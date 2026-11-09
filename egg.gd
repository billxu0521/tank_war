class_name Egg
extends Node3D
## 蛋。位置和持有者都由主機決定再同步出去，客戶端只負責畫。

## 0 = 沒人拿，其他 = 拿著它的牛仔編號
@export var carrier := 0
## 撿取進度（秒）。換人或走開就歸零。
@export var pickup := 0.0
## 撤離進度（秒）。離開圈子或陣亡就歸零；敵人站在圈內不會中斷。
@export var extract := 0.0

const UNBURY_STEP := 0.25   # 每次往上抬多少（公尺）
const UNBURY_MAX := 40      # 最多抬 10 公尺（碎塊堆不會更高）

## 主機每幀：沒人拿的蛋被碎塊或積木包住就往上抬，直到露出來（碎塊不動、不消失）。只查積木，不管站在蛋上的牛仔
func _physics_process(_delta: float) -> void:
	if carrier != 0 or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	var q := PhysicsPointQueryParameters3D.new()
	var space := get_world_3d().direct_space_state
	for i in UNBURY_MAX:
		q.position = global_position
		var buried := space.intersect_point(q, 8).any(func(r: Dictionary) -> bool:
			return r.collider is ToyBuild or (r.collider as Node).is_in_group(&"toy_piece"))
		if not buried:
			return
		global_position.y += UNBURY_STEP
