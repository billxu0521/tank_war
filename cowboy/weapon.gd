extends Node3D
class_name Weapon
## 一把武器：模型、數值、彈藥、動畫、音效。掛在 Viewmodel 底下，輸入和射線都在 host。
##
## 動畫有三種來源：
##   anim_map 的值是 String  = GLTF 的命名 clip
##   anim_map 的值是 Vector2 = 單一長條時間軸上的 (start, end) 分段
##   模型裡沒有 AnimationPlayer = 程式動作（blender/weapons.py 建的槍都是這種）：
##     後座、擊錘、轉輪、拉桿、折開槍管，零件節點名字填在 Procedural 那組
## host 一律用動作名呼叫 play()，不需要知道底下是哪一種。

## 支援的動作名。movement 類缺漏時退回 idle。
const MOVEMENT_FALLBACK: Array[StringName] = [&"walk", &"run", &"jump_start", &"jump_fall", &"jump_end"]

@export_group("Stats")
@export var display_name := "武器"
@export var mag_size := 12
## 每顆彈丸的傷害。總傷害 = damage × pellets 全中。
@export var damage := 25.0
## 一發射出幾顆彈丸。霰彈 > 1。
@export var pellets := 1
## 彈丸各自的額外散布半角（度），疊在 host 的散布上。
@export var pellet_spread := 0.0
@export var fire_interval := 0.22
## true = 一次換整匣（sawnoff 折開式），false = 一發一發壓（手槍、泵動霰彈）。
@export var reload_whole_mag := false
## 逐發模式是每發秒數；整匣模式是總秒數。
@export var reload_time := 0.45
## host 的後座力乘上這個倍率。霰彈 > 1。
@export var recoil_scale := 1.0
## 彈匣外的備彈。-1 = 無限。
@export var reserve := -1
## 腰射按住扳機可以搧擊錘連發（左輪），這是連發間隔。0 = 不能搧。
@export var fan_interval := 0.0
## 搧擊錘時每發額外的散布（度）。快但不準，只適合貼臉。
@export var fan_spread := 6.0
## 射程。散彈 30 公尺外彈丸就散光了，步槍打得到場地另一頭。
@export var hit_range := 100.0

@export_group("Aim")
## ADS 時模型移到的位置（相對 Viewmodel）。腰射位置就是場景檔裡的 position。
@export var ads_position := Vector3.ZERO

@export_group("Anim")
## 動作名 -> String（clip 名）或 Vector2(start, end)（分段）。
## 動作：idle walk run jump_start jump_fall jump_end fire fire_empty
##       reload reload_start reload_round reload_end wield，及 *_EMPTY 變體（值為 String 時）。
@export var anim_map: Dictionary = {}
## 這些動作要循環。命名 clip 改 loop_mode，分段則播到尾跳回頭。
@export var looping: Array[String] = ["idle", "walk", "run", "jump_fall"]

@export_group("Procedural")
## 沒有 AnimationPlayer 時用這些零件做動作。路徑相對於武器根節點，沒有就留空。
@export var model_path: NodePath = ^"Model"
## 左輪轉輪：每開一槍轉 60 度
@export var cylinder_path: NodePath
@export var hammer_path: NodePath
## 槓桿：開槍後往下拉再推回去，就是 fire_interval 那段時間
@export var lever_path: NodePath
## 折開式的槍管：換彈時往下折
@export var barrel_path: NodePath

var mag: int
var current_action := &""

var _model: Node3D
var _rest_pos := Vector3.ZERO
var _rest_rot := Vector3.ZERO
var _kick := 0.0         # 1 = 剛開槍，衰減到 0
var _cycle := 1.0        # 上膛進度 0..1，1 = 可以再開
var _cycle_time := 0.3
var _turns := 0          # 轉輪轉了幾格
var _reload_left := 0.0  # 換彈姿勢還要維持多久
var _reload_pose := 0.0  # 0 = 平常，1 = 換彈姿勢
var _melee := 0.0        # 近戰槍托往前推，1 → 0
## 重擊蓄力 0..1，Viewmodel 每幀設。蓄越滿槍拉得越後面
var windup := 0.0

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

## 分段播放的看門狗狀態
var _seg_end := -1.0
var _seg_start := 0.0
var _seg_loop := false


func _ready() -> void:
	mag = mag_size
	_model = get_node_or_null(model_path)
	if _model:
		_rest_pos = _model.position
		_rest_rot = _model.rotation
	# GLTF 匯進來每個 clip 都不循環，把 looping 名單（含 _EMPTY 變體）改掉
	for action in looping:
		for n in [anim_map.get(action), anim_map.get(action + "_EMPTY")]:
			if n is String and _anim and _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR


func _process(delta: float) -> void:
	if not _anim:
		_procedural(delta)
		return
	# 分段模式的「播完」要自己判斷：到了 end 就停（或跳回 start 循環）
	if _seg_end < 0.0 or not _anim or not _anim.is_playing():
		return
	if _anim.current_animation_position >= _seg_end:
		if _seg_loop:
			_anim.seek(_seg_start, true)
		else:
			_anim.pause()
			_seg_end = -1.0


func has_action(action: StringName) -> bool:
	return anim_map.has(String(action))


## 播一個動作。fitted > 0 時調速讓它剛好在 fitted 秒內播完。
## 回傳實際會播多久（缺這個動作回傳 0）。
func play(action: StringName, blend := 0.15, fitted := -1.0) -> float:
	if not _anim:
		return _play_procedural(action, fitted)
	if not has_action(action) and action in MOVEMENT_FALLBACK:
		action = &"idle"
	var entry = anim_map.get(String(action))
	if entry == null:
		return 0.0
	# 同一個循環動作不重播，不然永遠停在第 0 格
	if action == current_action and String(action) in looping:
		return 0.0
	current_action = action

	if entry is String:
		var a := _anim.get_animation(entry)
		if not a:
			return 0.0
		_seg_end = -1.0
		var speed := (a.length / maxf(fitted, 0.01)) if fitted > 0.0 else 1.0
		_anim.play(entry, blend, speed)
		return a.length / speed

	# Vector2 分段：播那條唯一的長動畫，seek 到起點，看門狗管結尾
	var strip := _anim.get_animation_list()[0]
	var length: float = entry.y - entry.x
	var speed2 := (length / maxf(fitted, 0.01)) if fitted > 0.0 else 1.0
	_seg_start = entry.x
	_seg_end = entry.y
	_seg_loop = String(action) in looping
	_anim.play(strip, blend, speed2)
	_anim.seek(entry.x, true)
	return length / speed2


## 名稱對應場景裡的 AudioStreamPlayer 子節點（ShootSound / ReloadSound / EmptySound）。
## 沒放就不出聲，不會爆。
func play_sound(name: StringName) -> void:
	var node := get_node_or_null(String(name) + "Sound")
	if node is AudioStreamPlayer:
		node.play()


# --- 程式動作（Blender 建的槍沒有動畫） ---

## 只處理有「事件」的動作；走路、待機這些持續動作交給 Viewmodel 的搖擺，回傳 0。
func _play_procedural(action: StringName, fitted: float) -> float:
	current_action = action
	match action:
		&"fire", &"fire_EMPTY":
			_kick = 1.0
			_cycle = 0.0
			_cycle_time = maxf(fitted, 0.05)
			_turns += 1
			return _cycle_time
		&"reload", &"reload_round":
			var t := fitted if fitted > 0.0 else 0.5
			# 多撐一點：逐發裝填每發之間姿勢不要彈回去又拉下來
			_reload_left = t + 0.15
			return t
		&"melee":
			_melee = 1.0
			return 0.35
	return 0.0


func _procedural(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 7.0)
	_cycle = minf(_cycle + delta / _cycle_time, 1.0)
	_melee = move_toward(_melee, 0.0, delta * 3.0)
	_reload_left = maxf(_reload_left - delta, 0.0)
	_reload_pose = move_toward(_reload_pose, 1.0 if _reload_left > 0.0 else 0.0, delta * 6.0)

	if _model:
		var thrust := sin(PI * _melee)   # 推出去再收回來
		# 後座：往後退、槍口上揚。換彈：往下沉、往內側翻，看得到裝填口。近戰：往前捅
		_model.position = _rest_pos + Vector3(0.0, -0.05 * _reload_pose,
			0.06 * _kick - 0.18 * thrust + 0.12 * windup)
		_model.rotation = _rest_rot + Vector3(0.22 * _kick - 0.35 * _reload_pose - 0.3 * thrust,
			0.0, 0.5 * _reload_pose + 0.4 * windup)

	# 擊錘：模型建的是扳起來的樣子。開槍瞬間往前打下去，上膛後半段扳回來
	var hammer := get_node_or_null(hammer_path) as Node3D
	if hammer:
		hammer.rotation.x = -0.55 * (1.0 - smoothstep(0.35, 1.0, _cycle))
	var cyl := get_node_or_null(cylinder_path) as Node3D
	if cyl:
		cyl.rotation.z = rotate_toward(cyl.rotation.z, wrapf(_turns * TAU / 6.0, -PI, PI), delta * 12.0)
	# 槓桿：上膛前 80% 的時間拉下去再推回來
	var lever := get_node_or_null(lever_path) as Node3D
	if lever:
		lever.rotation.x = 0.9 * sin(PI * clampf(_cycle / 0.8, 0.0, 1.0))
	var barrel := get_node_or_null(barrel_path) as Node3D
	if barrel:
		barrel.rotation.x = -0.6 * _reload_pose
