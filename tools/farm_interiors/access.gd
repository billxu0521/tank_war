extends SceneTree
## 於 v3.0 獨立副本以正式牛仔、物理與互動鍵驗室內和原棚口。
const FARM := preload("res://tools/map_study/farm_trial/match_map.tscn")
const FIT := preload("res://levels/farm_interiors/install.gd")
const PERSON := preload("res://cowboy/cowboy.tscn")
var farm: Node3D
var actor: CharacterBody3D
var site: Node3D
var door: Door
var checks := {}
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(n: int) -> void:
	for _i in n:
		await physics_frame

func record(label: String, ok: bool) -> void:
	checks[label] = ok
	if not ok:
		failures.append(label)
		print("FAILED ",label," ",actor.position if actor else "")

func spawn(at: Vector3) -> void:
	if actor:
		actor.free()
	actor = PERSON.instantiate()
	actor.name = "1"
	actor.position = at + Vector3.UP * .06
	for sound in ["StepSound","JumpSound","LandSound"]:
		actor.get_node(sound).stream = null
	farm.add_child(actor)
	await frames(25)

func walk(at: Vector3) -> bool:
	var reached := false
	var ticks := ceili((actor.global_position.distance_to(at) / actor.get("walk_speed") + 2.4) * Engine.physics_ticks_per_second)
	for _step in ticks:
		var delta := at - actor.global_position
		delta.y = 0
		if delta.length() < .09 and actor.is_on_floor():
			reached = true
			break
		actor.rotation.y = atan2(-delta.x,-delta.z)
		Input.action_press("move_forward", clampf(delta.length()*2.6,.15,1.))
		await physics_frame
	Input.action_release("move_forward")
	await frames(15)
	return reached

func yard(x: float, z: float) -> Vector3:
	return site.to_global(Vector3(x,0,z))

func use_door(label: String, want: bool) -> void:
	var d := door.to_global(Vector3(.80,1.55,0)) - actor.global_position
	actor.rotation.y = atan2(-d.x,-d.z)
	await frames(3)
	record(label+"瞄到門",actor.get("focus") == door)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(35)
	record(label+"門狀態",door.is_open == want)

func open_shed(id: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	await spawn(a)
	record(id+"進棚",await walk(b))
	record(id+"離棚",await walk(c))

func run() -> void:
	farm = FARM.instantiate()
	root.add_child(farm)
	await frames(3)
	record("原場景普通門為零",farm.get("_doors").is_empty())
	FIT.install(farm)
	FIT.install(farm)
	site = farm.get_node_or_null("House1Interior")
	if not site or not site.has_node("SouthDoor"):
		push_error("候選未掛入")
		quit(2)
		return
	door = site.get_node("SouthDoor")
	record("單一可操作門",farm.get("_doors").size()==1)
	await frames(3)
	await spawn(yard(-1.8,-6.35))
	record("從北窗繞西屋角", await walk(yard(-7.95,-6.0)) and await walk(yard(-7.95,5.75)))
	record("從屋角找到南門", await walk(yard(-3.08,5.94)))
	record("關門擋住直走",not await walk(yard(-3.08,3.87)))
	record("退回開門站位",await walk(yard(-3.08,5.98)))
	await use_door("屋外開",true)
	record("門往屋內",site.to_local(door.to_global(Vector3(1.34,1,0))).z < 3.30)
	record("過門檻",await walk(yard(-3.08,2.7)))
	record("站在門扇掃過處",await walk(yard(-3.00,3.71)))
	await use_door("有人站在掃掠區仍保持開",true)
	record("靠近灶與餐桌",await walk(yard(-3.65,-2.45)))
	record("繞隔屏",await walk(yard(.6,2.25)) and await walk(yard(4.25,2.25)))
	record("到床沿",await walk(yard(4.25,-2.55)))
	record("回門內",await walk(yard(4.25,2.55)) and await walk(yard(-1.98,2.55)))
	await use_door("屋內關",false)
	record("到內側開門位",await walk(yard(-3.08,2.65)))
	await use_door("屋內開",true)
	record("門往屋外",site.to_local(door.to_global(Vector3(1.34,1,0))).z > 5.59)
	record("走回宅旁道路",await walk(yard(-3.08,6.05)))
	# 從門側關門，可在扇片掃掠範圍外觸及門把。
	record("到外側門旁",await walk(yard(-2.08,6.00)))
	await use_door("屋外關",false)
	var nw:Node3D=farm.get_node("NorthwestWagonShed")
	var se:Node3D=farm.get_node("SoutheastUnloadingShed")
	await open_shed("西北農車棚",nw.to_global(Vector3(-.21,0,-2.80)),nw.to_global(Vector3(-.21,0,-1.46)),nw.to_global(Vector3(-.21,0,-2.80)))
	await open_shed("東南卸車棚",se.to_global(Vector3(-1.14,0,3.76)),se.to_global(Vector3(-1.14,0,1.54)),se.to_global(Vector3(-1.14,0,3.76)))
	await open_shed("北集乳棚",Vector3(-6,0,-52),Vector3(-6,0,-47),Vector3(-6,0,-42))
	var out := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	out.store_string(JSON.stringify({"項目":checks,"問題":failures},"  "))
	out.close()
	print("ACCESS ",JSON.stringify(failures))
	quit(int(not failures.is_empty()))
