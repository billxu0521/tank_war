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
## 射程：子彈飛這麼遠就消失。散彈 30 公尺外彈丸就散光了，步槍打得到場地另一頭。
@export var hit_range := 100.0
## 子彈初速（m/s）。重力是真實的 9.8，所以越慢掉越多：
## 左輪 330 打 50 公尺掉 11 公分，步槍 440 打 150 公尺掉 57 公分
@export var muzzle_velocity := 330.0
## 有效射程：這個距離內傷害全額、打頭一槍死；超過就遞減，到 hit_range 剩 falloff_min
@export var effective_range := 25.0
@export var falloff_min := 0.5

@export_group("Aim")
## 槍口在模型裡的位置（Godot 軸向）。火光和煙從這裡出去；零＝用 ShotFX 原本的位置
@export var muzzle := Vector3.ZERO
## ADS 時模型移到的位置（相對 Viewmodel）。腰射位置就是場景檔裡的 position。
@export var ads_position := Vector3.ZERO
## 腰射時槍多轉這麼多（弧度），舉槍時轉回正。Pax 腰射是往內斜、槍口朝準心
@export var hip_rotation := Vector3.ZERO

@export_group("Anim")
## 動作名 -> String（clip 名）或 Vector2(start, end)（分段）。
## 動作：idle walk run jump_start jump_fall jump_end fire fire_empty
##       reload reload_start reload_round reload_end wield，及 *_EMPTY 變體（值為 String 時）。
@export var anim_map: Dictionary = {}
## 這些動作要循環。命名 clip 改 loop_mode，分段則播到尾跳回頭。
@export var looping: Array[String] = ["idle", "walk", "run", "jump_fall"]

@export_group("Hands")
## 第一人稱的手（models/cowboy.glb 的 HandGrip / HandSupport）掛在哪個零件底下、放哪。
## 掛在會動的零件底下就會跟著動：步槍的右手掛拉桿、散彈的左手掛槍管（換彈折開時手跟著下去）
@export var grip_parent: NodePath = ^"Model"
@export var grip_hand := Transform3D()
## 右手前臂繞手腕多轉多少（弧度）。手轉去包住握把時，手臂要轉回來往畫面外伸
@export var grip_arm_rotation := Vector3.ZERO
## 空的＝單手拿（左輪）
@export var support_parent: NodePath
@export var support_hand := Transform3D()

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

@export_group("Reload pose")
## 換彈時槍移到哪、轉多少：要讓塞子彈的入口朝向鏡頭（左輪的裝填門、步槍右側的門、散彈的膛室）
@export var reload_offset := Vector3(0.0, -0.05, 0.0)
@export var reload_rotation := Vector3(-0.35, 0.0, 0.5)

@export_group("Hand reload")
## 長槍的右手換彈：離開握把、伸到畫面外拿一顆、塞進去、回來握好。
## 子彈的位置寫在 load_space 的座標裡（散彈是折開的槍管，步槍是整把槍）
@export var hand_round_path: NodePath
@export var load_space_path: NodePath = ^"Model"
## 子彈中心：塞之前（對準入口）和塞進去之後
@export var load_out := Vector3.ZERO
@export var load_in := Vector3.ZERO
## 手（拳頭中心）相對子彈中心的位置：拳頭在子彈後面
@export var load_hand_offset := Vector3(0.0, -0.012, 0.045)
## 折開時先把空殼彈出來（散彈）
@export var load_eject := false

@export_group("Revolver")
## 單動左輪的整套動作（照 Hunt 的 Pax）：開槍槍口大翻、拇指扳擊錘；
## 換彈舉起來開裝填門，左手推退殼桿、捏子彈一顆一顆塞。gate_path 空的就不做
@export var gate_path: NodePath
@export var ejector_path: NodePath
@export var round_path: NodePath
## 扳擊錘時拇指轉多少（弧度）：從貼在槍把左邊轉上去勾住扳手
@export var thumb_cock := Vector3.ZERO
## 塞彈的左手在鏡頭座標裡的朝向：從左下方伸過來、指尖朝右上（不跟著槍轉，不然手臂會直直立起來）
@export var load_hand_rotation := Vector3(0.6, -0.5, -0.3)

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
## 把槍放低 0..1（翻越、爬梯子時手要去撐東西），Viewmodel 每幀設
var lower := 0.0
## 舉槍程度 0..1，Viewmodel 每幀設。hip_rotation 乘 (1 - aim)
var aim := 0.0
var _since_fire := 9.0    # 開槍後幾秒，槍口上翻的曲線用
var _round_t := 1.0       # 這一發塞彈進行到哪 0..1，1 = 沒在塞
var _round_dur := 0.55
var _thumb: Node3D
var _load_hand: Node3D
var _round: Node3D
var _gate: Node3D
var _grip: Node3D           # 右手，長槍換彈時會離開握把
var _hand_round: Node3D
var _ejector: Node3D
var _ejector_rest := Vector3.ZERO

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

## 分段播放的看門狗狀態
var _seg_end := -1.0
var _seg_start := 0.0
var _seg_loop := false


const ARMS := preload("res://models/cowboy.glb")


func _ready() -> void:
	mag = mag_size
	_add_hands()
	_model = get_node_or_null(model_path)
	if _model:
		_rest_pos = _model.position
		_rest_rot = _model.rotation
	_gate = get_node_or_null(gate_path)
	_ejector = get_node_or_null(ejector_path)
	if _ejector:
		_ejector_rest = _ejector.position
	_round = get_node_or_null(round_path)
	if _round:
		_round.visible = false
	_hand_round = get_node_or_null(hand_round_path)
	if _hand_round:
		_hand_round.visible = false
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


## 這個距離打中的傷害。有效射程內全額，之後線性遞減到射程盡頭剩 falloff_min。
func damage_at(dist: float) -> float:
	var t := inverse_lerp(effective_range, hit_range, dist)
	return damage * lerpf(1.0, falloff_min, clampf(t, 0.0, 1.0))


func _add_hands() -> void:
	var src := ARMS.instantiate()
	for h: Array in [[&"HandGrip", grip_parent, grip_hand], [&"HandSupport", support_parent, support_hand]]:
		var parent := get_node_or_null(h[1] as NodePath) if h[1] != NodePath() else null
		var from := src.get_node_or_null(String(h[0])) as MeshInstance3D
		if parent and from:
			var mi := MeshInstance3D.new()
			mi.name = String(h[0])
			mi.mesh = from.mesh
			mi.transform = h[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 視角模型貼著鏡頭，影子會怪
			parent.add_child(mi)
			if h[0] == &"HandGrip":
				_grip = mi
				_thumb = _copy_mesh(src, &"HandGripThumb", mi)
				var arm := _copy_mesh(src, &"HandGripArm", mi)
				if arm:
					arm.rotation = grip_arm_rotation
	if not gate_path.is_empty():
		_load_hand = _copy_mesh(src, &"HandLoad", get_node(model_path))
		_load_hand.visible = false
	src.free()


## 從 cowboy.glb 拿一個網格掛到 parent 底下，位置用它在 glb 裡的節點位置
## （拇指的節點位置就是拇指根部在手裡的位置）
func _copy_mesh(src: Node, mesh_name: StringName, parent: Node) -> MeshInstance3D:
	var from := src.get_node_or_null(String(mesh_name)) as MeshInstance3D
	if from == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = String(mesh_name)
	mi.mesh = from.mesh
	mi.transform = from.transform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func has_action(action: StringName) -> bool:
	if not _anim and _gate and action in [&"reload_start", &"reload_end"]:
		return true
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


## 槍口的世界座標；沒設 muzzle 回傳 null
func muzzle_global() -> Variant:
	if muzzle == Vector3.ZERO or not _model:
		return null
	return _model.to_global(muzzle)


## 換彈被中斷（開槍、換槍、近戰）：姿勢馬上開始收回，手上那顆不塞了
func stop_reload() -> void:
	_reload_left = 0.0
	_round_t = 1.0


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
			_since_fire = 0.0
			_cycle = 0.0
			_cycle_time = maxf(fitted, 0.05)
			_reload_left = 0.0     # 換到一半開槍：槍直接回來
			_round_t = 1.0
			if not _gate:
				_turns += 1        # 左輪的轉輪是扳擊錘時才轉（_procedural 裡）
			return _cycle_time
		&"reload_start":
			_reload_left = 0.5
			return 0.3
		&"reload", &"reload_round":
			var t := fitted if fitted > 0.0 else 0.5
			# 多撐一點：逐發裝填每發之間姿勢不要彈回去又拉下來
			_reload_left = t + 0.15
			_round_t = 0.0
			_round_dur = t
			return t
		&"reload_end":
			_reload_left = 0.0
			return 0.3
		&"melee":
			_melee = 1.0
			return 0.35
	return 0.0


func _procedural(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 7.0)
	var was := _cycle
	_cycle = minf(_cycle + delta / _cycle_time, 1.0)
	_since_fire += delta
	_melee = move_toward(_melee, 0.0, delta * 3.0)
	_reload_left = maxf(_reload_left - delta, 0.0)
	_reload_pose = move_toward(_reload_pose, 1.0 if _reload_left > 0.0 else 0.0, delta * 5.0)
	var cock := 0.0   # 拇指扳擊錘 0..1（只有左輪）

	if _gate:
		# 開槍 0.03 秒內槍口翻到頂，再慢慢回來。Pax 的後座是一大翻，不是往後頓一下
		var flip := _since_fire / 0.03 if _since_fire < 0.03 else exp(-(_since_fire - 0.03) * 9.0)
		# 扳擊錘：上膛時間的後半段。拇指伸上去勾住扳手（0.35–0.55）、連擊錘一起往下拉（0.55–0.85）、放回去
		cock = smoothstep(0.35, 0.55, _cycle) - 0.4 * smoothstep(0.55, 0.85, _cycle) - 0.6 * smoothstep(0.85, 1.0, _cycle)
		if was < 0.75 and _cycle >= 0.75:
			_turns += 1    # 擊錘扳到一半轉輪就轉到下一格
		var rp := smoothstep(0.0, 1.0, _reload_pose)
		var hip := 1.0 - aim
		if _model:
			var thrust := sin(PI * _melee)
			_model.position = _rest_pos + reload_offset * rp + Vector3(0.12 * lower, 0.025 * flip - 0.22 * lower,
				0.05 * flip - 0.18 * thrust + 0.12 * windup + 0.05 * lower)
			_model.rotation = _rest_rot + hip_rotation * hip * (1.0 - rp) + reload_rotation * rp \
				+ Vector3(0.55 * flip - 0.3 * thrust - 0.8 * lower, 0.0, 0.1 * flip - 0.12 * cock + 0.4 * windup + 0.5 * lower)
		_revolver_reload(delta, rp)
	elif _model:
		var thrust := sin(PI * _melee)   # 推出去再收回來
		# 後座：往後退、槍口上揚。換彈：往下沉、往內側翻，看得到裝填口。近戰：往前捅
		var rp := smoothstep(0.0, 1.0, _reload_pose)
		_model.position = _rest_pos + reload_offset * rp + Vector3(0.12 * lower, -0.22 * lower,
			0.06 * _kick - 0.18 * thrust + 0.12 * windup + 0.05 * lower)
		_model.rotation = _rest_rot + hip_rotation * (1.0 - aim) * (1.0 - rp) + reload_rotation * rp \
			+ Vector3(0.22 * _kick - 0.3 * thrust - 0.8 * lower, 0.0, 0.4 * windup + 0.5 * lower)
	if not _gate:
		_hand_reload(delta)

	# 擊錘：模型建的是扳起來的樣子。開槍瞬間往前打下去，上膛後半段扳回來
	var hammer := get_node_or_null(hammer_path) as Node3D
	if hammer:
		var back := smoothstep(0.55, 0.85, _cycle) if _gate else smoothstep(0.35, 1.0, _cycle)
		hammer.rotation.x = -0.55 * (1.0 - back)
	if _thumb and _gate:
		_thumb.rotation = thumb_cock * cock
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


const HAND_POCKET := Vector3(0.14, -0.26, 0.16)   # 右手去拿子彈的地方（畫面外右下）


## 長槍換一發（_round_t 0→1）：右手離開握把→畫面外拿子彈→對準入口→塞進去→回來握好。
## 散彈折開的前段先把空殼往後上彈出來
func _hand_reload(delta: float) -> void:
	if not _grip or not _hand_round or not _model:
		return
	if _round_t < 1.0:
		_round_t = minf(_round_t + delta / _round_dur, 1.0)
	var t := _round_t
	var space := get_node(load_space_path) as Node3D
	var parent := _grip.get_parent() as Node3D
	var to_parent := parent.global_transform.affine_inverse()
	var rest := grip_hand.origin
	var pocket := to_parent * _model.to_global(HAND_POCKET)
	var out := to_parent * space.to_global(load_out + load_hand_offset)
	var inn := to_parent * space.to_global(load_in + load_hand_offset)
	var round_on := false
	var round_at := Vector3.ZERO    # load_space 座標
	if t < 1.0:
		var hand := rest
		if t < 0.25:
			hand = rest.lerp(pocket, smoothstep(0.0, 0.25, t))
		elif t < 0.5:
			hand = pocket.lerp(out, smoothstep(0.25, 0.5, t))
		elif t < 0.72:
			hand = out.lerp(inn, smoothstep(0.5, 0.72, t))
		else:
			hand = inn.lerp(rest, smoothstep(0.72, 1.0, t))
		_grip.position = hand
		if t >= 0.3 and t < 0.72:
			round_on = true
			round_at = space.to_local(parent.to_global(hand)) - load_hand_offset
		elif load_eject and t > 0.03 and t < 0.3:
			var k := t / 0.3
			round_at = load_in + Vector3(0.05 * k, 0.06 * k - 0.4 * k * k, 0.08 * k)   # 往後彈出一點、掉下去
			round_on = true
	else:
		# 沒在換（或被打斷）：手滑回握把，不要瞬間跳回去
		_grip.position = _grip.position.lerp(rest, minf(delta * 12.0, 1.0))
	_hand_round.visible = round_on
	if round_on:
		_hand_round.global_transform = Transform3D(space.global_basis, space.to_global(round_at))


# 塞彈的關鍵位置（槍模型座標，Godot 軸向）。捏的那一點＝彈底
const LOAD_AWAY := Vector3(-0.10, -0.20, 0.20)       # 手在畫面外左下
const LOAD_FETCH := Vector3(-0.04, -0.08, 0.09)      # 伸去拿子彈
const LOAD_KNOB := Vector3(0.016, 0.036, -0.162)     # 退殼桿推鈕前面
const LOAD_PUSHED := Vector3(0.016, 0.036, -0.130)
const LOAD_OUT := Vector3(0.0108, 0.0288, 0.035)     # 對準裝填門後面
const LOAD_IN := Vector3(0.0108, 0.0288, -0.006)     # 子彈塞進去了
const ROUND_HALF := 0.0148                           # 子彈原點到彈底


## 一發的流程（_round_t 0→1）：伸手→推退殼桿把空殼頂出來→拿子彈→對準裝填門塞進去→放手。
## 轉輪在塞完之後轉一格，下一發對到裝填門
func _revolver_reload(delta: float, rp: float) -> void:
	if _gate:
		_gate.rotation.z = -1.4 * smoothstep(0.3, 0.8, rp)   # 往右下翻開
	var was := _round_t
	if _round_t < 1.0:
		_round_t = minf(_round_t + delta / _round_dur, 1.0)
	var t := _round_t
	var hand := LOAD_AWAY
	var push := 0.0
	var round_at := Vector3.ZERO
	var round_on := false
	if t < 1.0:
		if t < 0.15:
			hand = LOAD_AWAY.lerp(LOAD_KNOB, smoothstep(0.0, 0.15, t))
		elif t < 0.3:
			push = smoothstep(0.15, 0.28, t)
			hand = LOAD_KNOB.lerp(LOAD_PUSHED, push)
		elif t < 0.48:
			push = 1.0 - smoothstep(0.3, 0.4, t)
			hand = LOAD_PUSHED.lerp(LOAD_FETCH, smoothstep(0.3, 0.48, t))
		elif t < 0.66:
			hand = LOAD_FETCH.lerp(LOAD_OUT, smoothstep(0.48, 0.66, t))
		elif t < 0.82:
			hand = LOAD_OUT.lerp(LOAD_IN, smoothstep(0.66, 0.82, t))
		else:
			hand = LOAD_IN.lerp(LOAD_AWAY, smoothstep(0.82, 1.0, t))
		# 空殼：推退殼桿時從裝填門往後彈出、往下掉
		if t > 0.2 and t < 0.45:
			var k := t - 0.2
			round_at = LOAD_IN + Vector3(0.0, 0.0, -ROUND_HALF) + Vector3(0.05 * k, -1.2 * k * k, 0.35 * k)
			round_on = true
		elif t >= 0.45 and t < 0.82:
			round_at = hand + Vector3(0.0, 0.0, -ROUND_HALF)
			round_on = true
		if was < 0.85 and t >= 0.85:
			_turns += 1
	if _ejector:
		_ejector.position = _ejector_rest + Vector3(0.0, 0.0, 0.032 * push)
	if _load_hand:
		# 沒在塞的時候手慢慢退到畫面外；退到了就藏起來
		_load_hand.position = hand if t < 1.0 else _load_hand.position.lerp(LOAD_AWAY, minf(delta * 10.0, 1.0))
		if _model:
			_load_hand.basis = _model.basis.inverse() * Basis.from_euler(load_hand_rotation)
		_load_hand.visible = rp > 0.05 and (t < 1.0 or _load_hand.position.distance_to(LOAD_AWAY) > 0.01)
	if _round:
		_round.visible = round_on
		_round.position = round_at
