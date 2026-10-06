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
@export var hip_fov := 70.0   # 照 Hunt 參考影片（docs/movie/pax.mov 等）：槍的擺位是在這個視角下對的，改了要重跑 tools/viewmodel_fit.gd
@export var ads_fov := 43.0
@export var ads_speed_scale := 0.5

@export_group("操作規則")
## 三把槍一致的操作方式（企劃規格裡「待討論」的幾項，先做成開關）
## 提早按開火要不要記住：扳擊錘、拉栓還沒做完就按，等槍好了自動射出。false = 要再按一次
@export var fire_buffer := false
## 逐發裝填中按開火：true = 停下裝填、馬上開槍；false = 只停下裝填，要再按一次才開（規格建議的做法）
@export var reload_fire_shoots := true
## 搧擊錘要持續按住開火鍵多久才算（秒）。快速連點每下都很短，不會被當成搧擊錘連發
@export var fan_hold := 0.2
## 瞄準按一下切換（true）或按住（false）。玩家自己的設定，Esc 選單裡改，存在 user://settings.cfg
static var aim_toggle := false

@export_group("Spread")
## 舉槍時間、腰射／瞄準散布、後座力是每把槍自己的（weapon.gd）。
## 這裡是三把共用的連射散布累積（規格 L1 的 bloom）：每發加多少、上限、每秒縮回多少，散布單位是度
@export var spread_per_shot := 1.5
var remote_shots := 0   # 收到別人這把槍開了幾槍（連線測試用來確認三人以上也看得到）
@export var max_spread := 8.0
@export var spread_recover := 6.0


@export_group("Sway")
## 視角轉動時武器的拖曳量（rad 對 rad），移動時的位移量（公尺）。
## ponytail: 0.8.1 回饋覺得鏡頭和槍不同步、有慣性，先關掉試試（原本 0.06 / 0.03）。確定不要再整段拆掉
@export var sway_amount := 0.0
@export var move_sway := 0.0
@export var sway_return_speed := 6.0

@export_group("Run")
## 跑步（衝刺）時槍放低、往內收、槍口朝下斜（公尺、弧度）。放下舉起各約 0.18 秒——看得出「現在在跑，不能馬上開槍」
@export var sprint_pos := Vector3(0.02, -0.035, 0.03)
@export var sprint_rot := Vector3(-0.1, 0.16, 0.18)
@export var sprint_blend_time := 0.18
## 手跟著腳步晃：走路小、跑步大（公尺）。一步晃一次，跟腳步聲同一個節奏（cowboy 的 step_*_interval）
@export var bob_walk := 0.008
@export var bob_sprint := 0.03

@export_group("Breath")
## 舉槍時準心會慢慢飄（度）。Hunt 的遠距離要閉氣才打得準，就是這個
@export var ads_sway := 0.35
## 閉氣每秒吃多少體力。體力見底放掉，而且晃得更兇
@export var breath_drain := 20.0
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

@onready var _player: Cowboy = owner
@onready var ammo_label: Label = get_node_or_null(ammo_label_path)
@onready var _fx: ShotFX = get_parent().get_node_or_null("ShotFX")
@onready var _camera: Camera3D = get_parent()

var weapon: Weapon
var _weapons: Array[Weapon] = []

# --- 炸藥（G）：按住點燃，放開丟出去。引信按著的時間也算，按太久在手上爆（規劃 docs/規劃/2026-10-04-炸藥與炸彈長矛.md） ---
const DYNAMITE_MAX := 2
const FUSE := 4.0
const THROW_SPEED := 16.0
const MAX_BLAST_DIST := 60.0   # 主機檢查：爆炸位置離丟的人不能更遠
enum { KIND_DYNAMITE, KIND_HARPOON }
## 每種爆炸 [半徑, 中心傷害]
const BLASTS := [[6.0, 150], [2.0, 120]]
var dynamite := DYNAMITE_MAX   # 身上還有幾根，-1 = 無限（沙盒、靶場）
var _cook := -1.0              # 點燃後按著多久，-1 = 沒拿著
var _hand_stick: Node3D       # 右手＋炸藥＋引信火花（點燃到丟出去）
var _throw_t := -1.0          # 丟出去的手部動作進行到哪（秒），-1 = 沒在丟
const THROW_ANIM := 0.45
## 拿著點燃的炸藥：右手在右下，炸藥橫著（參考 docs/image/explosives/炸藥_參考.png「點燃」那張）。
## 丟的時候手往前上方甩出去，放開後收回畫面外
## 丟的三段（審查第 10 條）：0–0.1 秒手往上往後拉到耳朵旁、炸藥轉成豎的（預備）→ 0.1–0.25 秒從上面往前下甩出去 → 停一下再收回
const STICK_HOLD := Vector3(0.17, -0.19, -0.36)
const STICK_HOLD_ROT := Vector3(0.15, 0.35, 1.25)
const STICK_WINDUP := Vector3(0.22, 0.02, -0.18)
const STICK_WINDUP_ROT := Vector3(0.5, 0.2, 0.15)
const STICK_THROW := Vector3(0.0, -0.05, -0.60)
const STICK_THROW_ROT := Vector3(-1.45, 0.0, 0.4)   # 出手：手腕往下壓（甩完的收尾，第二輪審查：以前看起來像伸食指指東西）
const STICK_AWAY := Vector3(0.22, -0.34, -0.30)
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
var _sway_pos := Vector3.ZERO   # 轉視角、移動的拖曳（目前關著）
var _sway_rot := Vector3.ZERO
var sprint_k := 0.0             # 0 = 平常，1 = 完全是跑步姿勢
var _bob_t := 0.0
var _bob_amp := 0.0
var _sway_t := 0.0
## 這一幀是不是在閉氣，給 HUD 和測試看
var holding_breath := false
## 還沒回復掉的後座力（x = 上抬，y = 水平），單位弧度
var _recoil_left := Vector2.ZERO
var _recoil_time_left := 0.0
## 每開一輪裝填就 +1，讓上一輪的 await 醒來時知道自己已經過期
var _reload_id := 0
var _fire_queued := false   # 等槍好了自動射的那一發：裝填中按開火（槍回正後射），或 fire_buffer 開著時提早按的
var _aim_latched := false   # aim_toggle 開著時：現在是不是舉著
var _fire_hold := 0.0       # 開火鍵這一次已經按住多久


func _ready() -> void:
	for scene in weapon_scenes:
		var w: Weapon = scene.instantiate()
		add_child(w)
		_weapons.append(w)
		_hip_positions.append(w.position)
		w.visible = false
	weapon = _weapons[_index]
	weapon.visible = true
	_hand_stick = _make_stick_hand()
	_hand_stick.visible = false
	add_child(_hand_stick)
	_refresh_ammo()
	weapon.play(&"idle", blend)
	_mark_for_outline()
	add_to_group(&"viewmodel")
	apply_brightness()


## 描線（outline.gdshader）認槍和手的記號：粗糙度剛好 OUTLINE_MARK。以前用「離鏡頭 1.5 公尺內」認，
## 貼近牆和木桶時它們也被當成槍、黑邊突然變粗；有些零件的粗糙度又剛好撞到草（0.5）和遠山（0.75）的記號。
## 材質複製一份再改，不動到別人（第三人稱、場景裡）共用的同一個材質
const OUTLINE_MARK := 0.65
## 目標（恐龍、別人的牛仔、靶）：outline.gdshader 不抹油畫、加輪廓光和較粗的線，遠處也認得出來（美術風格指南第 11 節）
const TARGET_MARK := 0.87

func _mark_for_outline() -> void:
	mark_meshes(self, OUTLINE_MARK)


## 手上的槍和手整體亮度：顏色 × brightness + lift。像素風（pixel_style.gd）壓暗了全畫面的影子，槍會變成一團黑看不出零件，
## 開著時把這裡調高抵消；改了之後對 "viewmodel" 群組呼叫 apply_brightness()。材質是 mark_meshes 複製過的，不影響別人
static var brightness := 1.0
## 再加上的底亮（0..1）：槍的鐵件接近全黑，只乘倍數還是黑的，要加一點才看得出零件
static var lift := 0.0

func apply_brightness() -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				if not mat.has_meta(&"base_value"):
					mat.set_meta(&"base_value", mat.get_shader_parameter(&"value") if mat.get_shader_parameter(&"value") != null else 1.0)
				mat.set_shader_parameter(&"value", mat.get_meta(&"base_value") * brightness)
				if not mat.has_meta(&"base_albedo"):
					mat.set_meta(&"base_albedo", mat.get_shader_parameter(&"albedo") if mat.get_shader_parameter(&"albedo") != null else Color.WHITE)
				var a: Color = mat.get_meta(&"base_albedo")
				mat.set_shader_parameter(&"albedo", Color(a.r + lift, a.g + lift, a.b + lift * 1.3, a.a))   # 底亮帶一點藍：參考圖的槍是灰藍
			elif mat is BaseMaterial3D:
				if not mat.has_meta(&"base_albedo"):
					mat.set_meta(&"base_albedo", mat.albedo_color)
				var c: Color = mat.get_meta(&"base_albedo")
				mat.albedo_color = Color(c.r * brightness + lift, c.g * brightness + lift, c.b * brightness + lift * 1.3, c.a)

## 把 root 底下所有不透明材質的粗糙度改成 mark，給 outline.gdshader 認
static func mark_meshes(root: Node, mark: float) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == preload("res://facet.gdshader"):   # 共用材質（main.gd 的 _to_facet）
				mat = mat.duplicate()
				mat.set_shader_parameter(&"roughness", mark)
				mi.set_surface_override_material(i, mat)
			elif mat is BaseMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:   # 火光這類半透明的不寫粗糙度，不用改
				mat = mat.duplicate()
				mat.roughness = mark
				mi.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _fire_queued and _fire_cooldown <= 0.0:
		_fire_queued = false
		try_fire()
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	_update_spread(delta)
	_update_recoil(delta)
	# 別人的角色不讀輸入。bot 也是「別人」，它直接呼叫 try_fire()，
	# 所以冷卻、散布、後座力回復要在這條線之前照樣跑
	if not _player.is_local:
		return
	# 滑鼠放開（Esc）時不接受開火，不然在選單狀態亂點也會射。爬梯子兩手都在梯子上，也不能開槍
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _player.is_climbing():
		if _melee_held >= 0.0 or _cook >= 0.0:
			pass   # 蓄力近戰中、拿著點燃的炸藥：不能開槍、換彈、換槍
		elif Input.is_action_just_pressed("fire"):
			if _fire_cooldown > 0.0 and fire_buffer and not _reloading:
				_fire_queued = true
			else:
				try_fire()
		elif _wants_fan():
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
		if _cook < 0.0 and _melee_held < 0.0 and dynamite != 0 and Input.is_action_just_pressed("throw"):
			_light_dynamite()
	_update_cook(delta)
	# 翻越、爬梯子、拿著炸藥時槍放低（手去撐東西了）
	weapon.lower = move_toward(weapon.lower, 1.0 if (_player.vaulting or _player.is_climbing() or _cook >= 0.0) else 0.0, delta * 6.0)
	weapon.aim = ads
	_fire_hold = _fire_hold + delta if Input.is_action_pressed("fire") else 0.0
	var wants_aim := Input.is_action_pressed("aim")
	if aim_toggle:
		if Input.is_action_just_pressed("aim"):
			_aim_latched = not _aim_latched
		if _player.is_sprinting():
			_aim_latched = false   # 衝刺會放下槍，切換模式也一樣
		wants_aim = _aim_latched
	_update_ads(wants_aim and _melee_held < 0.0, delta)
	_update_breath(Input.is_action_pressed("sprint"), delta)
	_update_sway(delta)
	_update_anim(delta)


func switch_weapon(index: int) -> void:
	if index == _index or index < 0 or index >= _weapons.size():
		return
	# 換槍等於放棄這輪裝填，排隊中的那一發也不射
	cancel_reload()
	_fire_queued = false
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
	# 舉槍到定位要時間，過渡期間散布還是腰射值——「舉槍要時間」不用另外寫規則
	ads = clampf(ads + (delta / weapon.ads_in if aiming else -delta / weapon.ads_out), 0.0, 1.0)
	_camera.fov = lerpf(hip_fov, ads_fov, ads)
	weapon.position = _hip_positions[_index].lerp(weapon.ads_position, ads)


func _update_spread(delta: float) -> void:
	# 舉滿了才吃 ADS 的精準值，過渡期間一律當腰射
	var base := weapon.spread_ads if ads >= 1.0 else weapon.spread_hip
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
	_sway_rot = _sway_rot.lerp(target_rot.limit_length(0.08), sway_return_speed * delta)
	_sway_pos = _sway_pos.lerp(target_pos, sway_return_speed * delta)

	# 跑步姿勢和腳步晃動：直接疊上去，不走上面的 lerp（lerp 會把晃動磨平、慢半拍）
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var moving := _player.is_on_floor() and speed > 0.5
	var sprinting := moving and _player.is_sprinting()
	sprint_k = move_toward(sprint_k, 1.0 if sprinting else 0.0, delta / sprint_blend_time)
	var e := smoothstep(0.0, 1.0, sprint_k)
	var interval: float = _player.step_sprint_interval if sprinting else _player.step_walk_interval
	if moving:
		_bob_t += delta * PI / interval   # 半圈一步
	var want_amp := (lerpf(bob_walk, bob_sprint, e) if moving else 0.0) * (1.0 - ads)
	_bob_amp = move_toward(_bob_amp, want_amp, delta * 0.2)   # 停下來慢慢收，不要一下子定住
	# 左右各一步，上下每步沉一次（8 字）；跑步時再加一點側傾
	var bob := Vector3(cos(_bob_t), -absf(sin(_bob_t)) * 0.8, 0.0) * _bob_amp
	position = _sway_pos + sprint_pos * e + bob
	rotation = _sway_rot + sprint_rot * e + Vector3(0.0, 0.0, cos(_bob_t) * _bob_amp * 2.0)


## 舉槍時準心沿一個慢慢的 8 字飄。直接轉視角，所以真的影響落點——
## 跟後座力同一個做法。閉氣（舉槍時按 Shift）時停住，但吃體力。
func _update_breath(want_hold: bool, delta: float) -> void:
	holding_breath = want_hold and ads >= 1.0 and _player.stamina > 0.0
	if holding_breath:
		_player.spend_stamina(breath_drain * delta)
	var amp := 0.0
	if ads > 0.0 and not holding_breath:
		amp = deg_to_rad(ads_sway) * ads
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


## 槍托敲人，吃體力（跟跑步同一條）。體力不夠也照樣揮——體力只影響移動速度
func try_melee(heavy := false) -> void:
	if _melee_cooldown > 0.0:
		return
	cancel_reload()
	_melee_cooldown = heavy_cooldown if heavy else melee_cooldown
	_player.spend_stamina(heavy_stamina if heavy else melee_stamina)
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
		if weapon.reload_type == Weapon.Reload.WHOLE:
			return
		cancel_reload()
		# 槍還在裝填姿勢（裝填門開著、手在塞子彈）：先回正，回好了才射這一發，不在半路開槍
		_fire_cooldown = maxf(_fire_cooldown, weapon.ready_after_reload())
		if reload_fire_shoots:
			_fire_queued = true
		return
	if weapon.mag == 0:
		weapon.play_sound(&"Empty")   # 硬派：打空不自動換彈，自己按 R
		return

	weapon.mag -= 1
	_refresh_ammo()
	# 擊發間隔和扳擊錘／拉栓同時起算，兩個都結束才能開下一槍。搧擊錘是手掌拍擊錘，沒有另外的上膛動作
	_fire_cooldown = weapon.fan_interval if fanning else maxf(weapon.fire_interval, weapon.cycle_time)
	weapon.play_sound(&"Shoot")
	# 最後一發用 _EMPTY 版本（手槍滑套後定）
	var action := &"fire"
	if weapon.mag == 0 and weapon.has_action(&"fire_EMPTY"):
		action = &"fire_EMPTY"
	# 畫面上的扳擊錘／拉栓照 cycle_time 做完：還沒拉好不會先看起來已經好了
	_anim_lock = weapon.play(action, blend, weapon.cycle_time if weapon.cycle_time > 0.0 and not fanning else _fire_cooldown)

	# 每顆彈丸一顆子彈，各自帶散布。霰彈的體感就是這裡來的：近距離全中、遠距離散光
	var dirs := PackedVector3Array()
	for i in weapon.pellets:
		dirs.append(_spread_direction(_camera, weapon.pellet_spread + (weapon.fan_spread if fanning else 0.0)))
	var from := _camera.global_position
	_launch(_index, from, dirs, false)
	_alert_boss(from)
	_muzzle_flash(weapon)
	# 自己開的槍、或主機上的 bot 開的槍（bot 的 authority 是主機），廣播給其他人看火光和子彈
	if is_multiplayer_authority():
		_remote_shot.rpc(_index, from, dirs)

	_apply_recoil()
	spread = minf(spread + spread_per_shot, max_spread)


## 別人畫面上的這一槍：火光、槍聲、同樣起點和方向的子彈（只有外觀）。
## 扣血只在開槍的人那邊判定一次，再請主機執行（Cowboy.deal_damage）。
## 客戶端 A 開的槍，主機會轉發給客戶端 B（SceneMultiplayer 的 server_relay 預設開著）。
## 2026-09-29 用專用伺服器＋兩個客戶端實測過：B 收得到 A 的每一槍
## 保證送到（reliable）：槍聲是情報，恐龍 boss 也靠它找人，掉一包就少聽到一槍。手動槍射速慢，多花的頻寬可以不計
@rpc("authority", "call_remote", "reliable")
func _remote_shot(index: int, from: Vector3, dirs: PackedVector3Array) -> void:
	if index < 0 or index >= _weapons.size():
		return
	remote_shots += 1
	_weapons[index].play_sound(&"Shoot")
	_muzzle_flash(_weapons[index])
	_launch(index, from, dirs, true)
	_alert_boss(from)


## 槍聲引來恐龍 boss。boss 在主機上跑：主機自己（和主機上的 bot）開槍走 try_fire，
## 客戶端開槍時主機收到的是 _remote_shot，兩邊都會通知到
func _alert_boss(at: Vector3) -> void:
	if multiplayer.is_server():
		get_tree().call_group(&"boss", &"hear", at)


## 火光和煙擺到這把槍真正的槍口（槍在動，每把槍的槍口也不一樣）
func _muzzle_flash(w: Weapon) -> void:
	if not _fx:
		return
	if w.harpoon:   # 魚叉發射管不是火藥槍：沒有槍口火光，只冒一小股煙（火光貼在長矛頂端會整片白）
		var at = w.muzzle_global()
		if at != null:
			Fx.puff(_arena(), at, -_camera.global_basis.z, Color(0.8, 0.79, 0.76, 0.5), 0.8, 0.08, 6)
		return
	var at = w.muzzle_global()
	if at != null:
		_fx.global_position = at
	_fx.flash(w.smoke)


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
		if w.harpoon:   # 炸彈長矛：飛出去的是魚叉，打中就爆
			var mi := MeshInstance3D.new()
			mi.mesh = w.harpoon.mesh
			b.model = mi
			if not visual_only:
				b.on_impact = func(at: Vector3) -> void: _explode.rpc(at, KIND_HARPOON)
		world.add_child(b)


## 逐發：一次壓一發，隨時可被開火中斷。整匣：播完 reload 一次補滿。
func try_reload() -> void:
	if _reloading or weapon.mag == weapon.capacity or weapon.reserve == 0:
		return
	_reload_id += 1
	var id := _reload_id
	_reloading = true
	weapon.play_sound(&"Reload")

	if weapon.reload_type == Weapon.Reload.WHOLE:
		weapon.play(&"reload", blend, weapon.reload_time)
		await get_tree().create_timer(weapon.reload_time).timeout
		if id != _reload_id:
			return
		var take := weapon.capacity - weapon.mag
		if weapon.reserve > 0:
			take = mini(take, weapon.reserve)
			weapon.reserve -= take
		weapon.mag += take
		_refresh_ammo()
		_reloading = false
		return

	if weapon.reload_start > 0.0:
		weapon.play(&"reload_start", blend, weapon.reload_start)
		await get_tree().create_timer(weapon.reload_start).timeout
		if id != _reload_id:
			return
	while weapon.mag < weapon.capacity and weapon.reserve != 0:
		weapon.play(&"reload_round", blend, weapon.reload_insert)
		# 用計時器而不是 animation_finished：不會被其他動作的 finished 訊號搶走
		await get_tree().create_timer(weapon.reload_insert).timeout
		# 序號對不上代表這輪已經被中止（或被新的一輪取代），直接收手。
		# 只看 _reloading 旗標不夠：中止後馬上重按 R，舊迴圈會誤以為是自己還活著
		if id != _reload_id:
			return
		weapon.mag += 1
		if weapon.reserve > 0:
			weapon.reserve -= 1
		_refresh_ammo()
	if weapon.reload_end > 0.0:
		_anim_lock = weapon.play(&"reload_end", blend, weapon.reload_end)
		_fire_cooldown = maxf(_fire_cooldown, weapon.reload_end)   # 裝填門還沒關好不能開
	_reloading = false


func cancel_reload() -> void:
	_reload_id += 1
	_reloading = false
	weapon.stop_reload()


## 在正前方為軸的圓錐內隨機取一個方向。sqrt 是為了讓落點在圓面上均勻，
## 不加的話會過度集中在中心。
func _spread_direction(cam: Camera3D, extra := 0.0) -> Vector3:
	var basis := cam.global_transform.basis
	var forward := -basis.z
	var total := spread + extra
	if _first_shot_perfect():
		total = extra   # 霰彈的彈丸還是各自散開
	if total <= 0.0:
		return forward
	var angle := deg_to_rad(total) * sqrt(randf())
	var roll := randf() * TAU
	var side := basis.x * cos(roll) + basis.y * sin(roll)
	return (forward + side * tan(angle)).normalized()


## 搧擊錘：左輪腰射、開火鍵「持續」按住夠久。只看「現在按著」的話，快速連點時某一下剛好跨過冷卻結束，
## 就會被當成搧擊錘，用 0.16 秒的間隔連發出去
func _wants_fan() -> bool:
	return weapon.fan_interval > 0.0 and ads < 0.5 and _fire_hold >= fan_hold


## 瞄準後第一發完全準：舉滿瞄具、站著不動、沒有連射累積的散布
func _first_shot_perfect() -> bool:
	return weapon.ads_first_shot_perfect and ads >= 1.0 and spread <= weapon.spread_ads + 0.001 \
		and Vector2(_player.velocity.x, _player.velocity.z).length() < 0.5


## 直接轉視角而不是只晃畫面，這樣它真的影響下一發落點。
## 只回正一部分（recoil_return_ratio）：回滿等於沒有後座力——連射到最後準心還在原地
func _apply_recoil() -> void:
	var w := weapon
	var up := deg_to_rad(w.recoil_pitch + randf_range(-w.recoil_pitch_random, w.recoil_pitch_random))
	var side := deg_to_rad(randf_range(-w.recoil_yaw, w.recoil_yaw))
	_player.rotate_view(Vector2(-side, -up))
	_recoil_left += Vector2(up, side) * w.recoil_return_ratio
	_recoil_time_left = w.recoil_return_time


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
		ammo_label.text = "%s  %d | %s    炸藥 %s" % [
			weapon.display_name, weapon.mag,
			"∞" if weapon.reserve < 0 else str(weapon.reserve),
			"∞" if dynamite < 0 else str(dynamite),
		]


## 沙盒、靶場：子彈和炸藥都無限
func set_infinite() -> void:
	for w in _weapons:
		w.reserve = -1
	dynamite = -1
	_refresh_ammo()


## 補給箱：炸藥、長矛的魚叉補滿（一般子彈不補）。回傳有沒有補到東西
func resupply() -> bool:
	var got := false
	if dynamite >= 0 and dynamite < DYNAMITE_MAX:
		dynamite = DYNAMITE_MAX
		got = true
	for w in _weapons:
		if w.harpoon and w.reserve >= 0 and w.reserve < w.starting_reserve:
			w.reserve = w.starting_reserve
			got = true
	_refresh_ammo()
	return got


# --- 炸藥 ---

## 右手握著炸藥（手是牛仔模型的握把手，炸藥沿手的握把方向插在掌心）、引信冒火花
func _make_stick_hand() -> Node3D:
	var holder := Node3D.new()
	var arms := Weapon.ARMS.instantiate()
	for part: StringName in [&"HandGrip", &"HandGripThumb", &"HandGripArm"]:
		var src := arms.get_node_or_null(String(part)) as MeshInstance3D
		if src:
			var mi := MeshInstance3D.new()
			mi.mesh = src.mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if part == &"HandGripArm":
				mi.rotation = Vector3(0, 0.7, 0)   # 跟左輪一樣，前臂往右後方伸出畫面
			holder.add_child(mi)
	arms.free()
	var stick := Dynamite.stick_mesh()
	stick.position = Vector3(0, 0.02, 0.0)
	holder.add_child(stick)
	var spark := Dynamite.spark()
	spark.position = Vector3(0, 0.02 + Dynamite.LENGTH * 0.5 + Dynamite.WICK, 0)   # 引信尖端
	holder.add_child(spark)
	return holder


func _light_dynamite() -> void:
	cancel_reload()
	_fire_queued = false
	_cook = 0.0
	_throw_t = -1.0
	_hand_stick.visible = true
	_hand_stick.position = STICK_AWAY


## 手的動作：點燃時從畫面外抬到右下拿好；丟的時候往前上甩、放開後收回畫面外
func _update_stick_hand(delta: float) -> void:
	weapon.visible = _cook < 0.0 and _throw_t < 0.0   # 拿炸藥時槍收起來：不然畫面上同時有兩隻右手（審查第 8 條）
	if _cook >= 0.0:
		var k := minf(_cook / 0.1, 1.0)
		_hand_stick.position = _hand_stick.position.lerp(STICK_HOLD, minf(delta * 14.0, 1.0)) if k >= 1.0 else STICK_AWAY.lerp(STICK_HOLD, smoothstep(0.0, 1.0, k))
		_hand_stick.rotation = STICK_HOLD_ROT
		return
	if _throw_t < 0.0:
		return
	_throw_t += delta
	var u := _throw_t / THROW_ANIM
	if u >= 1.0:
		_throw_t = -1.0
		_hand_stick.visible = false
		for c in _hand_stick.get_children():
			c.visible = true   # 下次點燃時炸藥、火花都要在
		return
	var t := _throw_t
	if t < 0.1:   # 預備：往上往後拉
		var k := smoothstep(0.0, 0.1, t)
		_hand_stick.position = STICK_HOLD.lerp(STICK_WINDUP, k)
		_hand_stick.rotation = STICK_HOLD_ROT.lerp(STICK_WINDUP_ROT, k)
	elif t < 0.25:   # 甩出去
		var k := smoothstep(0.1, 0.25, t)
		_hand_stick.position = STICK_WINDUP.lerp(STICK_THROW, k)
		_hand_stick.rotation = STICK_WINDUP_ROT.lerp(STICK_THROW_ROT, k)
	else:   # 停一下再收回畫面外
		var k := smoothstep(0.32, THROW_ANIM, t)
		_hand_stick.position = STICK_THROW.lerp(STICK_AWAY, k)
		_hand_stick.rotation = STICK_THROW_ROT


## 點燃之後：放開就丟，按太久在手上爆。不管滑鼠有沒有鎖住都要算（按 Esc 時引信照樣燒）
func _update_cook(delta: float) -> void:
	_update_stick_hand(delta)
	if _cook < 0.0:
		return
	_cook += delta
	if _cook >= FUSE:
		_use_dynamite()
		_throw_t = THROW_ANIM   # 在手上爆了：沒有丟的動作，手直接收掉（下一幀 _update_stick_hand 收尾）
		_explode.rpc(_camera.global_position - _camera.global_basis.z * 0.4, KIND_DYNAMITE)
	elif not Input.is_action_pressed("throw"):
		var left := FUSE - _cook   # 先算：_use_dynamite 會把 _cook 歸成 -1
		_use_dynamite()
		# ponytail: 放開當下就丟出去（手的甩動是 0.1 秒後才到最前面）。引信、連線都照放開那一刻算，比較單純
		var fwd := -_camera.global_basis.z
		var from := _camera.global_position + fwd * 0.5 + _camera.global_basis.x * 0.15
		_throw.rpc(from, fwd * THROW_SPEED + Vector3.UP * 2.5 + _player.velocity, left)


func _use_dynamite() -> void:
	_cook = -1.0
	_throw_t = 0.0   # 手往前甩出去（_update_stick_hand），手上的炸藥在這一刻放開
	_hand_stick.get_child(_hand_stick.get_child_count() - 2).visible = false   # 炸藥
	_hand_stick.get_child(_hand_stick.get_child_count() - 1).visible = false   # 火花
	if dynamite > 0:
		dynamite -= 1
	_refresh_ammo()


## 每台都生一根往外飛的炸藥（外觀）；丟的人那台的引信燒完才廣播爆炸
@rpc("authority", "call_local", "reliable")
func _throw(from: Vector3, vel: Vector3, fuse: float) -> void:
	var d := Dynamite.new()
	d.vel = vel
	d.fuse = fuse
	d.ignore = [_player.get_rid()]
	if is_multiplayer_authority():
		d.on_explode = func(at: Vector3) -> void: _explode.rpc(at, KIND_DYNAMITE)
	_arena().add_child(d)
	d.global_position = from


## 爆炸：每台播特效和聲音、引來恐龍；主機算範圍傷害（丟的人自己、隊友都會被炸）
@rpc("authority", "call_local", "reliable")
func _explode(at: Vector3, kind: int) -> void:
	if kind < 0 or kind >= BLASTS.size():
		return
	var radius: float = BLASTS[kind][0]
	Explosive.play(_arena(), at, radius)
	_alert_boss(at)
	if multiplayer.is_server() and at.distance_to(_player.global_position) <= MAX_BLAST_DIST:
		Explosive.damage(_arena(), at, radius, BLASTS[kind][1], _player)


func _arena() -> Node3D:
	var world := get_tree().get_first_node_in_group(&"arena") as Node3D
	return world if world else get_tree().current_scene as Node3D
