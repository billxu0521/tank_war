extends Node3D
class_name Weapon
## 一把武器：模型、數值、彈藥、動畫、音效。掛在 Viewmodel 底下，輸入和射線都在 host。
##
## 動畫有兩種來源，anim_map 的值型別決定用哪種：
##   String  = GLTF 的命名 clip（pistol、shotgun）
##   Vector2 = 單一長條時間軸上的 (start, end) 分段（sawnoff 這類只匯出一條 allanims 的模型）
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

var mag: int
var current_action := &""

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

## 分段播放的看門狗狀態
var _seg_end := -1.0
var _seg_start := 0.0
var _seg_loop := false


func _ready() -> void:
	mag = mag_size
	# GLTF 匯進來每個 clip 都不循環，把 looping 名單（含 _EMPTY 變體）改掉
	for action in looping:
		for n in [anim_map.get(action), anim_map.get(action + "_EMPTY")]:
			if n is String and _anim and _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR


func _process(_delta: float) -> void:
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
		return 0.0
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
