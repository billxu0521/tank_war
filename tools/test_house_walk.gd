extends SceneTree
## 農舍走得進去嗎：在每種房子的台階前面放一個膠囊（跟牛仔一樣大），往門口直走 4 秒，
## 要走上前廊（腳到地板高）、停在門前（門關著）。沒過就印出來、結束碼 1。
##   godot --headless --path . --script tools/test_house_walk.gd

var _main: Node
var _f := 0
var _runs: Array = []   # [名字, 膠囊, 起點]
var _t := 0.0

func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _physics_process(delta: float) -> bool:
	_f += 1
	if _f == 5:
		_main._on_sandbox_pressed()
	if _f == 40:
		for mi: MeshInstance3D in _main.find_children("*", "MeshInstance3D", true, false):
			for kind: StringName in _main.HOUSE_KINDS:
				if mi.mesh == _main._props.get(kind):
					var body := CharacterBody3D.new()
					var cs := CollisionShape3D.new()
					var cap := CapsuleShape3D.new()
					cap.radius = 0.35
					cap.height = 1.8
					cs.shape = cap
					cs.position.y = 0.9
					body.add_child(cs)
					_main.add_child(body)
					var start: Vector3 = mi.global_position + Vector3(0, 0.1, 4.0 + 2.6 + 1.6)   # 台階外面
					body.global_position = start
					_runs.append([kind, body, mi.global_position])
		assert(_runs.size() >= 3, "場上找不到三種房子")
	if _f > 40:
		_t += delta
		for r: Array in _runs:
			var b: CharacterBody3D = r[1]
			b.velocity = Vector3(0, b.velocity.y - 9.8 * delta, -3.0)
			b.move_and_slide()
		if _t > 4.0:
			var ok := true
			for r: Array in _runs:
				var b: CharacterBody3D = r[1]
				var rel: Vector3 = b.global_position - r[2]
				var good := rel.y > 0.35 and rel.z < 4.6 and rel.z > 3.5
				print("%s 走到 %s %s" % [r[0], rel, "OK" if good else "卡住"])
				ok = ok and good
			print("通過" if ok else "沒通過")
			quit(0 if ok else 1)
	return false
