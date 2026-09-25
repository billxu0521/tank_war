extends Node3D
class_name Viewmodel
## 第一人稱武器 host：輸入、ADS、散布、後座力、射線、HUD、特效、武器切換。
## 武器本體（模型、數值、彈藥、動畫、音效）在 Weapon 場景裡（scenes/weapons/*.tscn），
## 用 1/2/3 或滾輪切換。武器實例全程活著只切 visible，彈藥狀態不會因切換而消失。

@export var weapon_scenes: Array[PackedScene] = []

@export_group("Aim")
@export var hip_fov := 90.0
@export var ads_fov := 55.0
## 舉槍到定位要多久。過渡期間散布還是腰射值——「舉槍要時間」不用另外寫規則。
@export var ads_time := 0.2
@export var ads_speed_scale := 0.5

@export_group("Spread")
## 散布半角，單位是度。
@export var hip_spread := 4.0
@export var ads_spread := 0.3
@export var spread_per_shot := 1.5
@export var max_spread := 8.0
@export var spread_recover := 6.0

@export_group("Recoil")
@export var recoil_up := 1.2
@export var recoil_up_var := 0.4
@export var recoil_side := 0.5
## 只回復這個比例。回滿等於沒有後座力——連射到最後準心還在原地。
@export var recoil_recover_ratio := 0.7
@export var recoil_recover_time := 0.25

@export_group("Sway")
## 視角轉動時武器的拖曳量（rad 對 rad），移動時的位移量（公尺）。
@export var sway_amount := 0.06
@export var move_sway := 0.03
@export var sway_return_speed := 6.0

@export_group("Weapon")
@export var hit_range := 100.0
## 子彈打得到的層。這個專案沒分層，牆、恐龍、別的牛仔都在第 1 層
@export_flags_3d_physics var hit_mask := 1
## 切換動作的交叉淡入秒數。
@export var blend := 0.15
## 落地動畫的門檻：滯空短於這個秒數就不播，免得走下小台階也在那邊落地。
@export var land_anim_min_air_time := 0.25

@export_group("HUD")
## 存 NodePath 而不是直接 export Label：匯出的節點參考是在建立節點的當下解析的，
## HUD 在場景檔裡排在這個節點之後，那時候還不存在，只會拿到 null。
@export var ammo_label_path: NodePath
@export var crosshair_path: NodePath

@onready var _player: Cowboy = owner
@onready var ammo_label: Label = get_node_or_null(ammo_label_path)
@onready var crosshair: Control = get_node_or_null(crosshair_path)
@onready var _fx: ShotFX = get_parent().get_node_or_null("ShotFX")
@onready var _camera: Camera3D = get_parent()

var weapon: Weapon
var _weapons: Array[Weapon] = []
var _index := 0
## 每把武器的腰射位置（場景檔的 position），ADS 過渡和切換時用。
var _hip_positions: Array[Vector3] = []

## 0 = 腰射，1 = 舉滿。中間是過渡。
var ads := 0.0
## 目前的散布半角（度）
var spread := 0.0
var _air_time := 0.0
var _was_on_floor := true
var _reloading := false
## 大於 0 的時候不讓移動動作蓋掉開槍／落地／換武器動作
var _anim_lock := 0.0
var _fire_cooldown := 0.0
## 還沒回復掉的後座力（x = 上抬，y = 水平），單位弧度
var _recoil_left := Vector2.ZERO
var _recoil_time_left := 0.0
## 每開一輪裝填就 +1，讓上一輪的 await 醒來時知道自己已經過期
var _reload_id := 0


func _ready() -> void:
	for scene in weapon_scenes:
		var w: Weapon = scene.instantiate()
		add_child(w)
		_weapons.append(w)
		_hip_positions.append(w.position)
		w.visible = false
	weapon = _weapons[_index]
	weapon.visible = true
	_refresh_ammo()
	weapon.play(&"idle", blend)


func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_update_spread(delta)
	_update_recoil(delta)
	# 別人的角色不讀輸入。bot 也是「別人」，它直接呼叫 try_fire()，
	# 所以冷卻、散布、後座力回復要在這條線之前照樣跑
	if not _player.is_local:
		return
	# 滑鼠放開（Esc）時不接受開火，不然在選單狀態亂點也會射
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("fire"):
			try_fire()
		elif Input.is_action_just_pressed("reload"):
			try_reload()
		elif Input.is_action_just_pressed("weapon_next"):
			switch_weapon((_index + 1) % _weapons.size())
		elif Input.is_action_just_pressed("weapon_prev"):
			switch_weapon((_index - 1 + _weapons.size()) % _weapons.size())
		else:
			for i in _weapons.size():
				if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
					switch_weapon(i)
	_update_ads(Input.is_action_pressed("aim"), delta)
	_update_sway(delta)
	_update_anim(delta)


func switch_weapon(index: int) -> void:
	if index == _index or index < 0 or index >= _weapons.size():
		return
	# 換槍等於放棄這輪裝填
	cancel_reload()
	weapon.visible = false
	_index = index
	weapon = _weapons[index]
	weapon.visible = true
	weapon.position = _hip_positions[index].lerp(weapon.ads_position, ads)
	_refresh_ammo()
	# 有 wield 動畫就播，播完前不能開火
	var t := weapon.play(&"wield", blend)
	_anim_lock = t
	_fire_cooldown = maxf(t, 0.2)


## 舉槍／放下的過渡。衝刺會強制放下。
func _update_ads(wants: bool, delta: float) -> void:
	var aiming := wants and not _player.is_sprinting()
	ads = clampf(ads + (delta / ads_time) * (1.0 if aiming else -1.0), 0.0, 1.0)
	_camera.fov = lerpf(hip_fov, ads_fov, ads)
	weapon.position = _hip_positions[_index].lerp(weapon.ads_position, ads)
	if crosshair:
		crosshair.visible = ads < 1.0


func _update_spread(delta: float) -> void:
	# 舉滿了才吃 ADS 的精準值，過渡期間一律當腰射
	var base := ads_spread if ads >= 1.0 else hip_spread
	spread = maxf(spread - spread_recover * delta, base)


## 把剩下的量平均分配到剩下的時間裡。用 delta/剩餘時間 而不是 delta/總時間，
## 才會真的收斂到零——後者是指數逼近，永遠留一點殘值。
func _update_recoil(delta: float) -> void:
	if _recoil_time_left <= 0.0:
		return
	var step := _recoil_left * minf(delta / _recoil_time_left, 1.0)
	_player.rotate_view(Vector2(step.y, step.x))
	_recoil_left -= step
	_recoil_time_left -= delta


## 武器搖擺：視角轉動時武器往反方向拖一點，移動時往側面帶一點。
## 作用在 Viewmodel 自己身上，跟 ADS 動的武器 position 分開，兩者不打架。
func _update_sway(delta: float) -> void:
	var look := _player.consume_look_delta()
	# ADS 時手要穩，搖擺壓到兩成
	var strength := 1.0 - ads * 0.8
	var target_rot := Vector3(-look.y, -look.x, 0.0) * sway_amount * 60.0 * strength
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target_pos := Vector3(-input.x, 0.0, -input.y) * move_sway * strength
	rotation = rotation.lerp(target_rot.limit_length(0.08), sway_return_speed * delta)
	position = position.lerp(target_pos, sway_return_speed * delta)


func try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	if _reloading:
		# 折開式換到一半槍是拆開的，打不了；逐發裝填則隨時可以中止開打
		if weapon.reload_whole_mag:
			return
		cancel_reload()
	if weapon.mag == 0:
		if weapon.reserve != 0:
			try_reload()
		else:
			weapon.play_sound(&"Empty")
		return

	weapon.mag -= 1
	_refresh_ammo()
	_fire_cooldown = weapon.fire_interval
	weapon.play_sound(&"Shoot")
	# 最後一發用 _EMPTY 版本（手槍滑套後定）
	var action := &"fire"
	if weapon.mag == 0 and weapon.has_action(&"fire_EMPTY"):
		action = &"fire_EMPTY"
	_anim_lock = weapon.play(action, blend, weapon.fire_interval)

	# 每顆彈丸各射一條線。霰彈的體感就是這裡來的：近距離全中、遠距離散光
	var first_hit := Vector3.INF
	var first_end := Vector3.INF
	# 同一個目標的彈丸先加總，一槍只送一次傷害——霰彈八顆不用發八個 RPC
	var damage := {}
	for i in weapon.pellets:
		var hit := _raycast(weapon.pellet_spread)
		var target: Object = hit.get("collider")
		# 認方法不認型別：恐龍、別的牛仔都吃同一發子彈
		if target and target.has_method(&"take_damage"):
			damage[target] = damage.get(target, 0.0) + weapon.damage
		if _fx:
			var solid: bool = target != null and not target.has_method(&"take_damage")
			_fx.fire(hit["end"], hit.get("normal", Vector3.ZERO), hit.has("collider"), solid)
		if first_hit == Vector3.INF and hit.has("position"):
			first_hit = hit["position"]
		if first_end == Vector3.INF:
			first_end = hit["end"]
	for target: Node in damage:
		_player.deal_damage(target, roundi(damage[target]))
	if _fx and first_hit != Vector3.INF:
		_fx.impact_sound(first_hit)
	# bot 在主機上跑，authority 卻是它自己的編號，不能用 authority 的身分廣播
	if is_multiplayer_authority() and first_end != Vector3.INF:
		_remote_shot.rpc(_index, first_end)

	_apply_recoil()
	spread = minf(spread + spread_per_shot, max_spread)


## 別人畫面上的這一槍：火光、曳光、槍聲。不做射線也不扣血——扣血只在開槍的人
## 那邊判定一次，再請主機執行（Cowboy.deal_damage）。
##
## ponytail: ENet 不會把 rpc 從客戶端直送另一個客戶端，三人以上時客戶端 A
## 開的槍客戶端 B 看不到。要補就讓主機收到之後再轉發一次。
@rpc("authority", "call_remote", "unreliable")
func _remote_shot(index: int, to: Vector3) -> void:
	if index >= 0 and index < _weapons.size():
		_weapons[index].play_sound(&"Shoot")
	if _fx:
		_fx.fire(to, Vector3.ZERO, false)


## 逐發：一次壓一發，隨時可被開火中斷。整匣：播完 reload 一次補滿。
func try_reload() -> void:
	if _reloading or weapon.mag == weapon.mag_size or weapon.reserve == 0:
		return
	_reload_id += 1
	var id := _reload_id
	_reloading = true
	weapon.play_sound(&"Reload")

	if weapon.reload_whole_mag:
		weapon.play(&"reload", blend, weapon.reload_time)
		await get_tree().create_timer(weapon.reload_time).timeout
		if id != _reload_id:
			return
		var take := weapon.mag_size - weapon.mag
		if weapon.reserve > 0:
			take = mini(take, weapon.reserve)
			weapon.reserve -= take
		weapon.mag += take
		_refresh_ammo()
		_reloading = false
		return

	if weapon.has_action(&"reload_start"):
		var lead := weapon.play(&"reload_start", blend)
		await get_tree().create_timer(lead).timeout
		if id != _reload_id:
			return
	while weapon.mag < weapon.mag_size and weapon.reserve != 0:
		weapon.play(&"reload_round", blend, weapon.reload_time)
		# 用計時器而不是 animation_finished：不會被其他動作的 finished 訊號搶走
		await get_tree().create_timer(weapon.reload_time).timeout
		# 序號對不上代表這輪已經被中止（或被新的一輪取代），直接收手。
		# 只看 _reloading 旗標不夠：中止後馬上重按 R，舊迴圈會誤以為是自己還活著
		if id != _reload_id:
			return
		weapon.mag += 1
		if weapon.reserve > 0:
			weapon.reserve -= 1
		_refresh_ammo()
	if weapon.has_action(&"reload_end"):
		_anim_lock = weapon.play(&"reload_end", blend)
	_reloading = false


func cancel_reload() -> void:
	_reload_id += 1
	_reloading = false


## 從畫面中央射一條線出去（帶散布偏移），牆會擋住。
## 回傳 intersect_ray 的結果再加一個 end：打中就是命中點，沒打中就是射程盡頭。
func _raycast(extra_spread := 0.0) -> Dictionary:
	# 用自己的相機不用 viewport 的：bot 和遠端角色的 viewport 相機是本機玩家那台
	var from := _camera.global_position
	var to := from + _spread_direction(_camera, extra_spread) * hit_range
	var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask, [_player.get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	result["end"] = result.get("position", to)
	return result


## 在正前方為軸的圓錐內隨機取一個方向。sqrt 是為了讓落點在圓面上均勻，
## 不加的話會過度集中在中心。
func _spread_direction(cam: Camera3D, extra := 0.0) -> Vector3:
	var basis := cam.global_transform.basis
	var forward := -basis.z
	var total := spread + extra
	if total <= 0.0:
		return forward
	var angle := deg_to_rad(total) * sqrt(randf())
	var roll := randf() * TAU
	var side := basis.x * cos(roll) + basis.y * sin(roll)
	return (forward + side * tan(angle)).normalized()


## 直接轉視角而不是只晃畫面，這樣它真的影響下一發落點。
func _apply_recoil() -> void:
	var s := weapon.recoil_scale
	var up := deg_to_rad(recoil_up + randf_range(-recoil_up_var, recoil_up_var)) * s
	var side := deg_to_rad(randf_range(-recoil_side, recoil_side)) * s
	_player.rotate_view(Vector2(-side, -up))
	_recoil_left += Vector2(up, side) * recoil_recover_ratio
	_recoil_time_left = recoil_recover_time


func _update_anim(delta: float) -> void:
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor and _air_time >= land_anim_min_air_time:
		_anim_lock = _play_move(&"jump_end")
	_air_time = 0.0 if on_floor else _air_time + delta
	_was_on_floor = on_floor

	_anim_lock = maxf(_anim_lock - delta, 0.0)
	if _reloading or _anim_lock > 0.0:
		return

	if not on_floor:
		_play_move(&"jump_start" if _player.velocity.y > 0.0 else &"jump_fall")
		return

	# 蹲下沒有專屬動作，速度落在走路區間，會播 WALK
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 0.5:
		_play_move(&"idle")
	elif speed > _player.walk_speed + 0.5:
		_play_move(&"run")
	else:
		_play_move(&"walk")


## 移動動作：彈匣空且有 _EMPTY 變體就用變體（滑套後定），同一個動作不重播。
func _play_move(base: StringName) -> float:
	var action := base
	if weapon.mag == 0:
		var empty := StringName(String(base) + "_EMPTY")
		if weapon.has_action(empty):
			action = empty
	if weapon.current_action == action:
		return 0.0
	return weapon.play(action, blend)


func _refresh_ammo() -> void:
	if ammo_label:
		ammo_label.text = "%s  %d / %s" % [
			weapon.display_name, weapon.mag,
			"∞" if weapon.reserve < 0 else str(weapon.reserve),
		]
