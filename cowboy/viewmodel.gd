extends Node3D
class_name Viewmodel
## 第一人稱武器 host：輸入、ADS、散布、後座力、射線、HUD、特效、武器切換。
## 武器本體（模型、數值、彈藥、動畫、音效）在 Weapon 場景裡（cowboy/weapons/*.tscn），
## 用 1/2/3 或滾輪切換。武器實例全程活著只切 visible，彈藥狀態不會因切換而消失。
##
## Hunt 式的操作都在這裡：舉槍會晃、Shift 閉氣穩住（吃體力）、左輪腰射按住搧擊錘、
## V 槍托近戰（點＝輕擊、按住蓄力放開＝重擊）、打頭一槍死。

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

@export_group("Breath")
## 舉槍時準心會慢慢飄（度）。Hunt 的遠距離要閉氣才打得準，就是這個
@export var ads_sway := 0.35
## 閉氣每秒吃多少體力。體力見底放掉，而且晃得更兇
@export var breath_drain := 20.0
@export var winded_sway_mult := 2.5
## 蹲下時晃動乘這個。Hunt：蹲下會減少所有槍的晃動——要打遠就蹲
@export var crouch_sway_mult := 0.5

@export_group("Melee")
## 輕擊：便宜、快、痛不太到。Hunt 的近戰是沒子彈或換彈來不及時的保命手段
@export var melee_damage := 25
@export var melee_stamina := 15.0
@export var melee_cooldown := 0.6
## 重擊：按住蓄滿這麼久再放開。兩下半打死一個牛仔，但蓄力時站著挨打
@export var heavy_charge_time := 0.6
@export var heavy_damage := 60
@export var heavy_stamina := 30.0
@export var heavy_cooldown := 1.0
@export var melee_range := 2.2

@export_group("Weapon")
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
var _melee_cooldown := 0.0
## 近戰鍵按住多久了；負數＝沒按
var _melee_held := -1.0
## 舉槍晃動：已經套到視角上的偏移（弧度），下一幀只補差值
var _sway_applied := Vector2.ZERO
var _sway_t := 0.0
## 這一幀是不是在閉氣，給 HUD 和測試看
var holding_breath := false
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
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	_update_spread(delta)
	_update_recoil(delta)
	# 別人的角色不讀輸入。bot 也是「別人」，它直接呼叫 try_fire()，
	# 所以冷卻、散布、後座力回復要在這條線之前照樣跑
	if not _player.is_local:
		return
	# 滑鼠放開（Esc）時不接受開火，不然在選單狀態亂點也會射。爬梯子兩手都在梯子上，也不能開槍
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _player.is_climbing():
		if Input.is_action_just_pressed("fire"):
			try_fire()
		elif weapon.fan_interval > 0.0 and ads < 0.5 and Input.is_action_pressed("fire"):
			try_fire(true)   # 左輪腰射按住＝搧擊錘，快但散
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
		_update_melee_input(delta)
	_update_ads(Input.is_action_pressed("aim"), delta)
	_update_breath(Input.is_action_pressed("sprint"), delta)
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


## 舉槍時準心沿一個慢慢的 8 字飄。直接轉視角，所以真的影響落點——
## 跟後座力同一個做法。閉氣（舉槍時按 Shift）時停住，但吃體力。
func _update_breath(want_hold: bool, delta: float) -> void:
	holding_breath = want_hold and ads >= 1.0 and _player.stamina > 0.0
	if holding_breath:
		_player.spend_stamina(breath_drain * delta)
	var amp := 0.0
	if ads > 0.0 and not holding_breath:
		amp = deg_to_rad(ads_sway) * ads
		if _player.stamina < _player.sprint_min_stamina:
			amp *= winded_sway_mult   # 跑完喘，手會抖
		if _player.sync_crouching:
			amp *= crouch_sway_mult
		_sway_t += delta
	var want := Vector2(sin(_sway_t * 0.9), sin(_sway_t * 1.8) * 0.5) * amp
	# 放掉閉氣不要一下彈回去：往目標慢慢靠
	var step := want - _sway_applied
	if holding_breath:
		step = -_sway_applied * minf(delta * 8.0, 1.0)
	_player.rotate_view(step)
	_sway_applied += step


## 點一下＝輕擊，按住蓄力、放開＝重擊（跟 Hunt 一樣是「放開」才揮出去）。
## 蓄力中槍會往後拉，讓自己和旁人看得出要來一記重的。
func _update_melee_input(delta: float) -> void:
	if Input.is_action_just_pressed("melee"):
		_melee_held = 0.0
	elif _melee_held >= 0.0:
		if Input.is_action_pressed("melee"):
			_melee_held += delta
		else:
			try_melee(_melee_held >= heavy_charge_time)
			_melee_held = -1.0
	weapon.windup = clampf(_melee_held / heavy_charge_time, 0.0, 1.0) if _melee_held >= 0.0 else 0.0


## 槍托敲人，吃近戰體力（左下黃條）。照 Hunt：體力不夠重擊就退成輕擊；
## 見底了還能輕擊，但慢一倍（傷害不變）。
func try_melee(heavy := false) -> void:
	if heavy and _player.combat_stamina < heavy_stamina:
		heavy = false
	if _melee_cooldown > 0.0:
		return
	var cost := heavy_stamina if heavy else melee_stamina
	var winded: bool = _player.combat_stamina < cost
	cancel_reload()
	_melee_cooldown = (heavy_cooldown if heavy else melee_cooldown) * (2.0 if winded else 1.0)
	_player.spend_combat(cost)
	_anim_lock = weapon.play(&"melee", blend)
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * melee_range
	var q := PhysicsRayQueryParameters3D.create(from, to, hit_mask, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Object = hit.get("collider")
	if target and target.has_method(&"take_damage"):
		_player.deal_damage(target, heavy_damage if heavy else melee_damage)


## 打到的是不是牛仔的頭。Hunt 的規則：打頭一槍死，不管什麼槍。
## 恐龍沒有這條——1500 血的東西被一槍爆頭就沒得玩了。
static func is_headshot(target: Object, at: Vector3) -> bool:
	return target is Cowboy and at.y > (target as Cowboy).head.global_position.y - 0.18


func try_fire(fanning := false) -> void:
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
	_fire_cooldown = weapon.fan_interval if fanning else weapon.fire_interval
	weapon.play_sound(&"Shoot")
	# 最後一發用 _EMPTY 版本（手槍滑套後定）
	var action := &"fire"
	if weapon.mag == 0 and weapon.has_action(&"fire_EMPTY"):
		action = &"fire_EMPTY"
	_anim_lock = weapon.play(action, blend, _fire_cooldown)

	# 每顆彈丸一顆子彈，各自帶散布。霰彈的體感就是這裡來的：近距離全中、遠距離散光
	var dirs := PackedVector3Array()
	for i in weapon.pellets:
		dirs.append(_spread_direction(_camera, weapon.pellet_spread + (weapon.fan_spread if fanning else 0.0)))
	var from := _camera.global_position
	_launch(_index, from, dirs, false)
	if _fx:
		_fx.flash()
	# bot 在主機上跑，authority 卻是它自己的編號，不能用 authority 的身分廣播
	if is_multiplayer_authority():
		_remote_shot.rpc(_index, from, dirs)

	_apply_recoil()
	spread = minf(spread + spread_per_shot, max_spread)


## 別人畫面上的這一槍：火光、槍聲、同樣起點和方向的子彈（只有外觀）。
## 扣血只在開槍的人那邊判定一次，再請主機執行（Cowboy.deal_damage）。
##
## ponytail: ENet 不會把 rpc 從客戶端直送另一個客戶端，三人以上時客戶端 A
## 開的槍客戶端 B 看不到。要補就讓主機收到之後再轉發一次。
@rpc("authority", "call_remote", "unreliable")
func _remote_shot(index: int, from: Vector3, dirs: PackedVector3Array) -> void:
	if index < 0 or index >= _weapons.size():
		return
	_weapons[index].play_sound(&"Shoot")
	if _fx:
		_fx.flash()
	_launch(index, from, dirs, true)


## 生子彈。從鏡頭中心出發（所以瞄具不用歸零：近距離打哪中哪，遠了往下掉）。
## ponytail: 霰彈每顆彈丸打中都各送一次傷害，客戶端一槍最多 10 個 RPC。
## 真的卡再改成同一幀的命中先加總。
func _launch(index: int, from: Vector3, dirs: PackedVector3Array, visual_only: bool) -> void:
	var w := _weapons[index]
	var world := get_tree().get_first_node_in_group(&"arena")
	if world == null:
		world = get_tree().current_scene
	for i in dirs.size():
		var b := Bullet.new()
		b.origin = from
		b.vel = dirs[i] * w.muzzle_velocity
		b.shooter = _player
		b.weapon = w
		b.fx = _fx
		b.mask = hit_mask
		b.visual_only = visual_only
		b.sound = i == 0
		world.add_child(b)


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
		ammo_label.text = "%s  %d | %s" % [
			weapon.display_name, weapon.mag,
			"∞" if weapon.reserve < 0 else str(weapon.reserve),
		]
