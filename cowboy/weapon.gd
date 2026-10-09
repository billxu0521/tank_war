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

# 參數名字和分類照企劃的《槍枝參數規格》（docs/企劃/討論紀錄/2026-09-30-槍枝參數規格.md），
# 標 L1、L2 的是規格裡還沒排進這階段、但現在手感已經用到的（先留著，數字不動）。
enum Reload { WHOLE, PER_ROUND }
## 射擊類型。BREAK（折開式散彈）是規格外的，規格只談左輪和手動步槍
enum Action { SINGLE_ACTION, DOUBLE_ACTION, BOLT, LEVER, BREAK, HARPOON }

@export_group("基礎")
@export var display_name := "武器"
## 射擊類型：單動左輪每發前扳擊錘、雙動扣扳機就扳好、栓動拉栓、槓桿壓槓桿
@export var action_type := Action.SINGLE_ACTION
## 每顆彈丸的傷害。總傷害 = damage × pellets 全中。
@export var damage := 25.0
## 彈藥容量：最多裝幾發（現在剩幾發是 mag）
@export var capacity := 12
## 起始備彈：一開始另外帶幾發。-1 = 無限（沙盒）。遊戲中剩多少是 reserve
@export var starting_reserve := -1
## L1 每發彈丸數：霰彈 > 1
@export var pellets := 1
## L2 彈丸各自的額外散布半角（度），疊在散布上
@export var pellet_spread := 0.0

@export_group("動作時間")
## 舉起瞄具、放下瞄具各要幾秒
@export var ads_in := 0.2
@export var ads_out := 0.2
## 最短擊發間隔：開一槍後至少隔幾秒才能開下一槍
@export var fire_interval := 0.22
## 每發之間的操作時間：扳擊錘、拉栓、壓槓桿要幾秒。跟擊發間隔同時起算，兩個都結束才能開下一槍（不是相加）。
## 畫面上的動作也照這個時間做完。0 = 沒有這個動作（折開式散彈）
@export var cycle_time := 0.0
## 裝填類型：WHOLE 整組換（折開式散彈），PER_ROUND 一顆一顆裝（左輪、步槍）
@export var reload_type := Reload.PER_ROUND
## 整組裝填時間（秒）
@export var reload_time := 1.6
## 逐發裝填：開始裝到放得進第一顆的準備時間（打開裝填門）、每顆子彈幾秒、
## 裝完到能開槍的收尾時間（關上裝填門）。總時間 = 準備 + 發數 × 每顆 + 收尾
@export var reload_start := 0.0
@export var reload_insert := 0.45
@export var reload_end := 0.0
## 規格外：腰射按住扳機可以搧擊錘連發（左輪），這是連發間隔。0 = 不能搧
@export var fan_interval := 0.0
## 規格外：搧擊錘時每發額外的散布（度）。快但不準，只適合貼臉
@export var fan_spread := 6.0

@export_group("後座力")
## 垂直後座力：每發往上抬幾度（先射出子彈才抬）
@export var recoil_pitch := 1.2
## L2 每發上抬的隨機範圍（±度）
@export var recoil_pitch_random := 0.4
## L1 水平後座力：每發往左右隨機偏幾度（±）
@export var recoil_yaw := 0.5
## 後座力回復時間：偏掉的準心幾秒內回正
@export var recoil_return_time := 0.25
## 回正多少（1 = 回滿；0.7 = 回七成，剩下的玩家自己壓）
@export var recoil_return_ratio := 0.7

@export_group("散布")
## 腰射、瞄準的散布（度，中心到邊緣）。腰射也是基礎散布
@export var spread_hip := 4.0
@export var spread_ads := 0.3
## 瞄準後第一發完全準：舉滿瞄具、站著不動、沒有連射累積的散布時，這發沒有隨機偏差（後座力照樣有）
@export var ads_first_shot_perfect := false

@export_group("彈道")
## 子彈初速（m/s）。重力是真實的 9.8，所以越慢掉越多：
## 左輪 330 打 50 公尺掉 11 公分，步槍 440 打 150 公尺掉 57 公分
@export var muzzle_velocity := 330.0
## 衰減起始距離：這個距離內傷害全額、打頭一槍死；之後線性遞減，到衰減終止距離剩最低傷害，再遠都是最低傷害
@export var falloff_start := 25.0
@export var falloff_end := 100.0
## 最低傷害（每顆，直接填傷害值）。不能高過基礎傷害；改基礎傷害時這個不會跟著變
@export var minimum_damage := 12.5
## 最大判定距離：子彈飛這麼遠就消失。散彈 30 公尺外彈丸就散光了，步槍打得到場地另一頭
@export var max_range := 100.0
## 槍口煙量：左輪 = 1，越大煙團越大、留越久（Fx.gun_smoke）
@export var smoke := 1.0

@export_group("Aim")
## 槍口在模型裡的位置（Godot 軸向）。火光和煙從這裡出去；零＝用 ShotFX 原本的位置
@export var muzzle := Vector3.ZERO
## ADS 時模型移到的位置（相對 Viewmodel）。腰射位置就是場景檔裡的 position。
@export var ads_position := Vector3.ZERO
## 腰射時槍多轉這麼多（弧度），舉槍時轉回正。Pax 腰射是往內斜、槍口朝準心
@export var hip_rotation := Vector3.ZERO
## 舉槍瞄準時多轉的角度（瞄準 0→1 漸變）：炸彈長矛瞄準時槍頭往玩家這邊仰，刀刃才高過護板看得到
@export var ads_rotation := Vector3.ZERO

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

@export_group("魚叉")
## 炸彈長矛：射出去的不是子彈，是這個節點的樣子（魚叉），打中東西就爆（Viewmodel.KIND_HARPOON）。
## 有裝填時它插在發射管裡看得到，射掉了就藏起來
@export var harpoon_path: NodePath
## 換彈用左手（HandSupport）去拿、塞，右手一直握著（炸彈長矛：平常只有右手拿，左手放在畫面外，換彈才伸進來）
@export var reload_with_support := false
## 換彈時手去哪拿子彈（槍模型座標）。預設是右手的畫面外右下（HAND_POCKET）；炸彈長矛的左手從左下拿
@export var fetch_pocket := Vector3(0.14, -0.26, 0.16)
## 換彈時手在鏡頭裡再轉多少（弧度）：手保持腰射時的朝向，再加這個；讓前臂從畫面右下伸進來，不要橫過畫面
@export var reload_hand_turn := Vector3.ZERO
## 捏子彈的手繞子彈再轉多少（弧度，子彈座標）：讓手從畫面外側伸進來
@export var pinch_rotation := Vector3.ZERO
## 舉槍時左手繞槍管再轉多少（弧度，乘舉槍程度）
@export var ads_support_turn := 0.0
## 腰射時左手繞槍管再轉多少（弧度，乘 1 - 舉槍程度）：讓護木躺在掌心、拇指在左、四指從下面繞到右邊（影片的握法）
@export var hip_support_turn := 0.0
## 會動的手：腰射時左手手腕往手背方向折幾度，前臂順著伸出去（負的＝照 glb 烘好的方向）
@export var support_wrist_ext := -1.0
## 會動的手：腰射時左手拇指尖要去的地方——離護木軸多遠（往鏡頭左邊）、沿護木往槍口多遠（公尺）。零＝不動
@export var support_thumb := Vector2.ZERO
## 會動的手：腰射時左手四指第二、三節再往掌心彎多少（度）
@export var support_finger_curl := 0.0
## 左手只在舉槍時出現（左輪：腰射單手、舉槍雙手）
@export var support_only_ads := false
## 舉槍時左手再移多少（父節點座標，乘舉槍程度）：影片舉槍時左手看起來很近很大
@export var ads_support_shift := Vector3.ZERO
## 舉槍時左手再整個轉多少（弧度，父節點座標，乘舉槍程度）：讓前臂往左下出畫面
@export var ads_support_rot := Vector3.ZERO
## 換彈時左手繞槍管轉多少（弧度）：槍翻過來時左手改從下面托（影片步槍換彈）
@export var reload_support_turn := 0.0

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
## 塞彈的左手繞子彈轉多少（弧度，子彈座標）：手跟著子彈（拇指頂彈底），前臂另外用 pinch_arm_dir 轉出畫面
@export var load_hand_rotation := Vector3.ZERO

@export_group("Rig")
## 用會動的手（models/cowboy.glb 的 RigGrip / RigSupport / RigLoad：帶骨架，靜止姿勢＝握姿）。
## 開槍食指扣扳機；左輪拇指扳擊錘是一節一節彎；長槍換彈捏子彈的手塞完會張開放手（_rig_pose）。炸彈長矛還是固定網格
@export var use_rig := false
## 扳擊錘時拇指最後一節再往下勾多少（度）：勾住擊錘往後拉（影片 7.5、15.5 秒）
@export var thumb_cock_curl := 35.0
## 開槍時食指往掌心扣多少（度，第二、三節各一半）
@export var trigger_pull := 25.0
## 扳擊錘時拇指指尖要去的地方（擊錘自己的座標）：擊錘尾端上緣，指腹壓在上面往後拉
@export var hammer_spur := Vector3(0.0, 0.031, 0.027)
## 長槍換彈塞完子彈放手時，手指張開多少（度）
@export var release_open := 70.0
## 長槍換彈拿子彈到入口那段，從槍上方繞多高（公尺）
@export var approach_lift := 0.04
## 長槍換彈捏子彈時前臂往哪伸（鏡頭座標）：影片步槍、散彈都是從畫面右邊橫著伸進來。
## 零＝不轉（照 glb 裡烘好的方向，會直直朝鏡頭、蓋住半個畫面）
@export var pinch_arm_dir := Vector3(0.35, -1.0, 0.0)   # 往下、偏右伸出畫面（審查：往右橫著伸手臂太高、蓋住右半畫面；往鏡頭後伸手肘貼著鏡頭）

var mag: int
var harpoon: MeshInstance3D   # 炸彈長矛管裡那支魚叉（沒有就是一般的槍）
var reserve := 0   # 遊戲中還剩幾發備彈，-1 = 無限
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
var _pinch_mesh: Mesh   # 長槍換彈時拿子彈的手（HandLoad）
var _hold_mesh: Mesh    # 換彈那隻手原本的網格
var _round: Node3D
var _gate: Node3D
var _grip: Node3D           # 右手，長槍換彈時會離開握把
var _support: Node3D        # 左手
var _hand_round: Node3D
const HAND_SHELL_HALF := 0.0325   # 拿子彈的手（HandLoad）照多長的子彈擺：blender/hands.py 的 SHELL_LEN 一半（散彈）
var _pinch_shift := 0.0          # 手裡的子彈比散彈短多少的一半：手往子彈前面（-Z）挪這麼多
var _ejector: Node3D
var _ejector_rest := Vector3.ZERO
# 會動的手（use_rig）：每隻手的骨架，和骨架空間 ← 外層節點（原本固定網格的座標）的轉換
var _grip_sk: Skeleton3D
var _grip_sk_basis := Basis.IDENTITY
var _load_sk: Skeleton3D
var _support_sk: Skeleton3D
var _pinch_rig: Node3D   # 長槍換彈：握槍那隻手裡另一副捏子彈的手（跟握槍的手切換顯示）
var _pinch_sk: Skeleton3D
var _release := 0.0      # 長槍換彈塞完放手 0..1（手指張開）
const THUMB_TIP := 0.026   # 拇指最後一節從關節到指尖多長（glb 不存骨頭尾端，照 hands.py 的 THUMB_LEN）

@onready var _anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

## 分段播放的看門狗狀態
var _seg_end := -1.0
var _seg_start := 0.0
var _seg_loop := false


const ARMS := preload("res://models/cowboy.glb")


func _ready() -> void:
	apply_table()
	mag = capacity
	reserve = starting_reserve
	_add_hands()
	_model = get_node_or_null(model_path)
	if _model:
		_rest_pos = _model.position
		_rest_rot = _model.rotation
	_gate = get_node_or_null(gate_path)
	_ejector = get_node_or_null(ejector_path)
	if _ejector:
		_ejector_rest = _ejector.position
	harpoon = get_node_or_null(harpoon_path) as MeshInstance3D
	if harpoon and hand_round_path.is_empty():   # 換彈時手上拿的那支：跟管裡的同一個樣子
		var copy := MeshInstance3D.new()
		copy.mesh = harpoon.mesh
		(_model if _model else self).add_child(copy)
		hand_round_path = get_path_to(copy)
	_round = get_node_or_null(round_path)
	if _round:
		_round.visible = false
	_hand_round = get_node_or_null(hand_round_path)
	if _hand_round:
		_hand_round.visible = false
		if _hand_round is MeshInstance3D:   # 拿子彈的手是照散彈擺的：短的子彈手要往前挪，拇指才頂得到它的底
			_pinch_shift = HAND_SHELL_HALF - (_hand_round as MeshInstance3D).get_aabb().size.z * 0.5
	# GLTF 匯進來每個 clip 都不循環，把 looping 名單（含 _EMPTY 變體）改掉
	for action in looping:
		for n in [anim_map.get(action), anim_map.get(action + "_EMPTY")]:
			if n is String and _anim and _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR


func _process(delta: float) -> void:
	if harpoon:
		harpoon.visible = mag > 0 or (_round_t >= (0.62 if reload_with_support else 0.72) and _round_t < 1.0)   # 塞進去那一刻就看得到（彈數要等換彈計時結束才加）
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


# --- 參數表（企劃改的表格，蓋過場景裡的數字） ---

## 一列一個參數、一欄一把槍（欄名 = 場景檔名，例如 revolver）。Excel 打得開，改完重開遊戲就生效。
## 場景裡的數字只是預設值；表格裡有的以表格為準
const TABLE := "res://cowboy/weapons/weapons.csv"
const ACTION_NAMES := ["單動左輪", "雙動左輪", "栓動步槍", "槓桿步槍", "折開式", "魚叉發射管"]   # 跟 Action 同順序
const RELOAD_NAMES := ["整組", "逐發"]                                                # 跟 Reload 同順序
static var _table := {}   # 槍的 id -> {參數: 表格裡的文字}

static func table() -> Dictionary:
	if _table.is_empty():
		var f := FileAccess.open(TABLE, FileAccess.READ)
		if f == null:
			return _table
		var head := f.get_csv_line()
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() < head.size() or row[0].strip_edges() == "":
				continue
			for c in range(3, head.size()):
				var id := head[c].strip_edges()
				if not _table.has(id):
					_table[id] = {}
				_table[id][row[0].strip_edges()] = row[c].strip_edges()
	return _table


## 把表格裡這把槍的數字套上來。文字照參數原本的型別轉：數字、是／否、選項（射擊類型、裝填類型）
func apply_table() -> void:
	var vals: Dictionary = table().get(scene_file_path.get_file().get_basename(), {})
	for key: String in vals:
		var txt: String = vals[key]
		var cur: Variant = get(key)
		if key == "action_type":
			set(key, maxi(ACTION_NAMES.find(txt), 0))
		elif key == "reload_type":
			set(key, maxi(RELOAD_NAMES.find(txt), 0))
		elif cur is bool:
			set(key, txt in ["是", "true", "TRUE", "1"])
		elif cur is int:
			set(key, txt.to_int())
		elif cur is float:
			set(key, txt.to_float())
		elif cur is String:
			set(key, txt)
		else:
			push_warning("武器參數表：%s 不是槍的參數（打錯字？）" % key)


# --- 武器介紹：從設定算出來，不另外填（算法照規格第 07 節） ---

## 換彈姿勢收回來要多久（_procedural 裡每秒收 5 成 = 0.2 秒）
const POSE_RETURN := 0.2

## 裝填被開火打斷時，槍要多久才回正、能開：關上裝填門（收尾）和姿勢收回，取長的
func ready_after_reload() -> float:
	return maxf(reload_end, POSE_RETURN)


## 兩槍之間實際要等多久：擊發間隔和上膛動作同時起算，取長的
func shot_gap() -> float:
	return maxf(fire_interval, cycle_time)


## 打空到裝滿要幾秒。逐發 = 準備 + 容量 × 每顆 + 收尾
func full_reload_time() -> float:
	if reload_type == Reload.WHOLE:
		return reload_time
	return reload_start + capacity * reload_insert + reload_end


## 每分鐘射速。with_reload = true 是持續平均：打完一輪（每發都算上膛）再裝滿，一分鐘平均幾發
func rpm(with_reload := false) -> float:
	if not with_reload:
		return 60.0 / shot_gap()
	return 60.0 * capacity / (capacity * shot_gap() + full_reload_time())


## 武器介紹的每一列 [項目, 這把槍的值]
func info_rows() -> Array:
	var reserve_txt := "∞" if starting_reserve < 0 else str(starting_reserve)
	var pellet_txt := "" if pellets <= 1 else "×%d" % pellets
	return [
		["傷害", "%d%s" % [damage, pellet_txt]],
		["彈藥＋備彈", "%d＋%s" % [capacity, reserve_txt]],
		["射速（發／分）", str(roundi(rpm()))],
		["含裝填射速", str(roundi(rpm(true)))],
		["打空裝滿（秒）", "%.1f" % full_reload_time()],
		["初速（公尺／秒）", str(roundi(muzzle_velocity))],
		["衰減（公尺→最低）", "%d–%d→%d" % [falloff_start, falloff_end, minimum_damage]],
		["射程（公尺）", str(roundi(max_range))],
	]


## 這個距離打中的傷害（每顆）。超過最大判定距離子彈早就消失了（bullet.gd），這裡不管
func damage_at(dist: float) -> float:
	var t := inverse_lerp(falloff_start, falloff_end, dist)
	return lerpf(damage, minf(minimum_damage, damage), clampf(t, 0.0, 1.0))


func _add_hands() -> void:
	var src := ARMS.instantiate()
	if use_rig:
		_add_rig_hands(src)
		src.free()
		return
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
			if h[0] == &"HandSupport":
				_support = mi
			if h[0] == &"HandGrip":
				_grip = mi
				_thumb = _copy_mesh(src, &"HandGripThumb", mi)
				var arm := _copy_mesh(src, &"HandGripArm", mi)
				if arm:
					arm.rotation = grip_arm_rotation
	var pinch := src.get_node_or_null(^"HandLoad") as MeshInstance3D
	var reloader := _support if reload_with_support else _grip
	if pinch and reloader is MeshInstance3D and gate_path.is_empty() and harpoon_path.is_empty():
		_pinch_mesh = pinch.mesh
		_hold_mesh = (reloader as MeshInstance3D).mesh
	if not gate_path.is_empty():
		_load_hand = _copy_mesh(src, &"HandLoad", get_node(model_path))
		_load_hand.visible = false
	src.free()


## 會動的手：外層一個空節點（名字、位置跟原本的固定網格一樣，所以擺手的程式不用改），
## 裡面放 glb 的骨架組（RigGrip 等，自己的節點位置就是原本烘進網格的那個轉換）
func _add_rig_hands(src: Node) -> void:
	for h: Array in [[&"HandGrip", &"RigGrip", grip_parent, grip_hand], [&"HandSupport", &"RigSupport", support_parent, support_hand]]:
		var parent := get_node_or_null(h[2] as NodePath) if h[2] != NodePath() else null
		if parent == null:
			continue
		var holder := _rig_holder(src, h[0], h[1], parent)
		if holder == null:
			continue
		holder.transform = h[3]
		if h[0] == &"HandGrip":
			_grip = holder
			_grip_sk = holder.find_children("*", "Skeleton3D", true, false)[0]
			_grip_sk_basis = (holder.get_child(0) as Node3D).basis   # 骨架空間 → 外層節點空間
		else:
			_support = holder
			_support_sk = holder.find_children("*", "Skeleton3D", true, false)[0]
	# 長槍換彈：握槍的手裡多放一副捏子彈的手，拿子彈那段切過去（以前是換網格）
	var reloader := _support if reload_with_support else _grip
	if reloader and gate_path.is_empty() and harpoon_path.is_empty():
		var rig := src.get_node_or_null(^"RigLoad") as Node3D
		if rig:
			_pinch_rig = rig.duplicate() as Node3D
			for mi: MeshInstance3D in _pinch_rig.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_pinch_rig.visible = false
			reloader.add_child(_pinch_rig)
			_pinch_sk = _pinch_rig.find_children("*", "Skeleton3D", true, false)[0]
	if not gate_path.is_empty():
		_load_hand = _rig_holder(src, &"HandLoad", &"RigLoad", get_node(model_path))
		if _load_hand:
			_load_hand.visible = false
			_load_sk = _load_hand.find_children("*", "Skeleton3D", true, false)[0]


func _rig_holder(src: Node, holder_name: StringName, rig_name: StringName, parent: Node) -> Node3D:
	var rig := src.get_node_or_null(String(rig_name)) as Node3D
	if rig == null:
		return null
	var holder := Node3D.new()
	holder.name = String(holder_name)
	var copy := rig.duplicate() as Node3D
	holder.add_child(copy)
	for mi: MeshInstance3D in copy.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 視角模型貼著鏡頭，影子會怪
	parent.add_child(holder)
	return holder


## 每幀從靜止姿勢（＝握姿）重擺：前臂轉回來、拇指扳擊錘、食指扣扳機
func _rig_pose(cock: float) -> void:
	if _grip_sk:
		var sk := _grip_sk
		sk.reset_bone_poses()
		# 前臂繞手腕轉（原本 HandGripArm 的 rotation，外層座標 → 骨架座標）
		_rotate_bone_global(sk, "LowerArm", Basis.from_euler(grip_arm_rotation))
		# 長槍換彈：手翻來翻去，前臂常常正對鏡頭、手肘的袖子變成一個圓盤擋在手旁邊；照換彈姿勢的程度把前臂轉往畫面外
		var cam := get_viewport().get_camera_3d()
		if not _gate and cam and pinch_arm_dir != Vector3.ZERO and _reload_pose > 0.0:
			var i := sk.find_bone("LowerArm")
			var cur := (sk.global_basis * sk.get_bone_global_pose(i).basis.y).normalized()
			var want := cam.global_basis * pinch_arm_dir.normalized()
			_aim_bone(sk, "LowerArm", cur.slerp(want, smoothstep(0.0, 1.0, _reload_pose)))
		# 拇指：指尖自己找擊錘（審查：固定角度轉，舉槍時拇指從左邊橫掃過槍頂、腰射壓在槍背中段碰不到擊錘）。
		# 最後一節先往下勾，再讓掌骨和中間那節把指尖帶到擊錘尾端，最後照扳擊錘進度從握姿漸變過去
		var hammer := get_node_or_null(hammer_path) as Node3D
		if cock > 0.0 and hammer:
			_bend(sk, "Thumb_Distal", thumb_cock_curl)
			var target := sk.global_transform.affine_inverse() * hammer.to_global(hammer_spur)
			_reach(sk, ["Thumb_Distal", "Thumb_Intermediate", "Thumb_Proximal"], "Thumb_Distal", target, cock)
		# 食指扣扳機：開槍那一下（0.12 秒內扣下再放開）
		var pull := clampf(1.0 - absf(_since_fire - 0.04) / 0.08, 0.0, 1.0)
		if pull > 0.0:
			_bend(sk, "Index_Intermediate", trigger_pull * 0.5 * pull)
			_bend(sk, "Index_Distal", trigger_pull * 0.5 * pull)
	if _support_sk:
		_support_sk.reset_bone_poses()
		var cam2 := get_viewport().get_camera_3d()
		if cam2 and support_wrist_ext >= 0.0 and aim < 1.0:
			# 先擺好手（掌心朝上托護木），前臂順著手腕伸出去：手腕只往手背方向折（托東西時真人可以折 70 度），
			# 不往側邊歪。不要先定前臂再扳手腕（使用者：左手扭曲很嚴重；掌心朝下蓋在護木上是反握）
			var i := _support_sk.find_bone("LowerArm")
			var cur := (_support_sk.global_basis * _support_sk.get_bone_global_pose(i).basis.y).normalized()
			var hand_y := (_support_sk.global_basis * _support_sk.get_bone_global_pose(_support_sk.find_bone("Hand")).basis.y).normalized()
			var palm := palm_dir(_support_sk)
			var e := deg_to_rad(support_wrist_ext)
			_aim_bone(_support_sk, "LowerArm", cur.slerp((-hand_y * cos(e) - palm * sin(e)).normalized(), 1.0 - aim))
		if cam2 and support_thumb != Vector2.ZERO and aim < 1.0:
			# 拇指貼在護木靠鏡頭左邊那側、往槍口方向（影片的握法）；不然轉過來之後拇指懸在半空
			var ax := _support.global_basis.z.normalized()        # 護木的軸（HandSupport 的 +Z）
			var mz: Variant = muzzle_global()
			if mz != null and ax.dot((mz as Vector3) - _support.global_position) > 0.0:
				ax = -ax   # 讓 -ax 指向槍口（support_thumb.y 是往槍口多遠）
			var left := -cam2.global_basis.x
			left = (left - ax * left.dot(ax)).normalized()
			var p := _support.global_position - ax * support_thumb.y + left * support_thumb.x
			# 只動掌骨和中間那節，最後一節伸直：三節一起反算會把末節勾下去、再拉回來，拇指變成一個鉤子（審查第三輪）
			# （烘好的握姿拇指本來就是彎的，所以最後一節要對齊中間那節，才是真的伸直）
			var mid := _support_sk.find_bone("Thumb_Intermediate")
			_aim_bone(_support_sk, "Thumb_Distal", _support_sk.global_basis * _support_sk.get_bone_global_pose(mid).basis.y)
			_bend(_support_sk, "Thumb_Distal", 10.0)   # 留一點彎：完全對齊時兩節交界的皮會翻出一片三角（審查第四輪）
			_reach(_support_sk, ["Thumb_Intermediate", "Thumb_Proximal"], "Thumb_Distal",
				_support_sk.global_transform.affine_inverse() * p, 1.0 - aim)
		if support_finger_curl != 0.0 and aim < 1.0:
			# 四指多包一點：腰射時指尖從護木右側翻上來看得到（只彎手指，整隻手往上轉會變回反握）
			# 正數＝多彎、負數＝打開（四指握成拳包進護木裡時用負的，讓指尖從護木右側伸出來）
			for f in ["Index", "Middle", "Ring", "Little"]:
				_bend(_support_sk, f + "_Proximal", support_finger_curl * 0.6 * (1.0 - aim))
				_bend(_support_sk, f + "_Intermediate", support_finger_curl * (1.0 - aim))
				_bend(_support_sk, f + "_Distal", support_finger_curl * 0.8 * (1.0 - aim))
	if _pinch_sk and _pinch_rig.visible:
		# 塞完放手：拇指、食指往外張開（影片散彈 9、26.5 秒，塞完手是張開退出去的）
		_pinch_sk.reset_bone_poses()
		var o := release_open * _release
		_bend(_pinch_sk, "Index_Proximal", -o * 0.5)
		_bend(_pinch_sk, "Index_Intermediate", -o * 0.4)
		_bend(_pinch_sk, "Index_Distal", -o * 0.2)
		_bend(_pinch_sk, "Thumb_Intermediate", -o * 0.5)
		_bend(_pinch_sk, "Thumb_Distal", -o * 0.3)
		var cam := get_viewport().get_camera_3d()
		if cam and pinch_arm_dir != Vector3.ZERO:
			_aim_bone(_pinch_sk, "LowerArm", cam.global_basis * pinch_arm_dir.normalized())


## 讓 tip 骨頭的指尖碰到 target（骨架座標）：鏈上的骨頭從末端往根部輪流轉向目標，幾輪就收斂（CCD）。
## 算完再照 weight 從原本的姿勢漸變過去（指尖沿弧線過去，不會直線穿過槍）
func _reach(sk: Skeleton3D, chain: Array, tip: String, target: Vector3, weight: float) -> void:
	var ids := chain.map(func(n: String) -> int: return sk.find_bone(n))
	var t := sk.find_bone(tip)
	if t < 0 or ids.has(-1):
		return
	var before := ids.map(func(i: int) -> Quaternion: return sk.get_bone_pose_rotation(i))
	for _it in 8:
		for i: int in ids:
			var g := sk.get_bone_global_pose(i)
			var tg := sk.get_bone_global_pose(t)
			var tip_at := tg.origin + tg.basis.y.normalized() * THUMB_TIP
			var a := (tip_at - g.origin).normalized()
			var b := (target - g.origin).normalized()
			if a.dot(b) > 0.99999:
				continue
			var q := Quaternion(a, b)
			sk.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))
	for k in ids.size():
		var i: int = ids[k]
		sk.set_bone_pose_rotation(i, (before[k] as Quaternion).slerp(sk.get_bone_pose_rotation(i), weight))


## 骨頭（連子骨頭）繞根部轉，讓骨頭的方向（+Y，根部→尾端）指向世界座標的 dir。
## 骨架可能是鏡射過的（左手的 glb 拿來當右手用），轉動先換到骨架座標
func _aim_bone(sk: Skeleton3D, bone_name: String, dir: Vector3) -> void:
	var i := sk.find_bone(bone_name)
	if i < 0:
		return
	var to_world := sk.global_basis
	var g := sk.get_bone_global_pose(i)
	var cur := (to_world * g.basis.y).normalized()
	var want := dir.normalized()
	if cur.dot(want) > 0.9999:
		return
	var r := Basis(Quaternion(cur, want))
	var rs := to_world.inverse() * r * to_world
	sk.set_bone_global_pose(i, Transform3D(rs * g.basis, g.origin))


## 掌心朝哪（世界座標）：手指往掌心彎，中指從指根到指尖、扣掉手的方向，就是掌心那一面。骨架鏡射過也對
func palm_dir(sk: Skeleton3D) -> Vector3:
	var h := (sk.global_basis * sk.get_bone_global_pose(sk.find_bone("Hand")).basis.y).normalized()
	var a := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Middle_Proximal")).origin
	var b := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Middle_Distal")).origin
	var v := b - a
	return (v - h * v.dot(h)).normalized()


## 手腕彎幾度（手的方向和前臂反方向的夾角，伸直＝0）、往側邊歪幾度。檢查用
func wrist_angles(sk: Skeleton3D) -> Vector2:
	var h := sk.get_bone_global_pose(sk.find_bone("Hand")).basis
	var a := sk.get_bone_global_pose(sk.find_bone("LowerArm")).basis.y.normalized()
	var back := -a
	var bend := rad_to_deg(back.angle_to(h.y.normalized()))
	var side := rad_to_deg(asin(clampf(back.dot(h.x.normalized()), -1.0, 1.0)))
	return Vector2(bend, side)


## 骨頭往掌心彎 deg 度（骨頭自己的 X 軸是彎曲軸，hands.py 的 bend 一樣是繞 X 轉負角）
func _bend(sk: Skeleton3D, bone_name: String, deg: float) -> void:
	var i := sk.find_bone(bone_name)
	if i < 0:
		return
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, deg_to_rad(-deg)))


## 骨頭（連子骨頭）繞自己的根部轉 r：r 是外層節點座標（原本固定網格的座標）裡的轉動
func _rotate_bone_global(sk: Skeleton3D, bone_name: String, r: Basis) -> void:
	var i := sk.find_bone(bone_name)
	if i < 0:
		return
	var rs := _grip_sk_basis.inverse() * r * _grip_sk_basis
	var g := sk.get_bone_global_pose(i)
	sk.set_bone_global_pose(i, Transform3D(rs * g.basis, g.origin))


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
			var t := fitted if fitted > 0.0 else 0.3
			_reload_left = t + 0.2
			return t
		&"reload", &"reload_round":
			var t := fitted if fitted > 0.0 else 0.5
			# 多撐一點：逐發裝填每發之間姿勢不要彈回去又拉下來
			_reload_left = t + 0.15
			_round_t = 0.0
			_round_dur = t
			return t
		&"reload_end":
			_reload_left = 0.0
			return fitted if fitted > 0.0 else 0.3
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
	_reload_pose = move_toward(_reload_pose, 1.0 if _reload_left > 0.0 else 0.0, delta / POSE_RETURN)
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
		_model.rotation = _rest_rot + hip_rotation * (1.0 - aim) * (1.0 - rp) + ads_rotation * aim * (1.0 - rp) + reload_rotation * rp \
			+ Vector3(0.22 * _kick - 0.3 * thrust - 0.8 * lower, 0.0, 0.4 * windup + 0.5 * lower)
	if _support and support_only_ads:   # 左輪：舉槍時才用左手托住右手（雙手握，照影片）
		_support.visible = aim > 0.3 and _reload_pose < 0.1
	if _support and not reload_with_support:
		# 舉槍時左手繞槍管轉回來：腰射槍往左傾、手設成從左側托；舉槍槍是正的，不轉回來前臂會橫過畫面
		_support.basis = Basis.from_euler(ads_support_rot * aim) * Basis(Vector3.BACK, ads_support_turn * aim + hip_support_turn * (1.0 - aim) + reload_support_turn * smoothstep(0.0, 1.0, _reload_pose)) \
			* support_hand.basis.orthonormalized()
		if _reload_left <= 0.0:
			_support.position = support_hand.origin + Vector3(ads_support_shift.x, ads_support_shift.y, ads_support_shift.z) * aim
	if not _gate:
		_hand_reload(delta)

	# 擊錘：模型建的是扳起來的樣子。開槍瞬間往前打下去，上膛後半段扳回來
	var hammer := get_node_or_null(hammer_path) as Node3D
	if hammer:
		var back := smoothstep(0.55, 0.85, _cycle) if _gate else smoothstep(0.35, 1.0, _cycle)
		hammer.rotation.x = -0.55 * (1.0 - back)
	if _thumb and _gate:
		_thumb.rotation = thumb_cock * cock
	if use_rig:
		_rig_pose(cock)
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


const HAND_POCKET := Vector3(0.14, -0.26, 0.16)
const RELEASE_END := 0.84   # 長槍會動的手：塞完（0.72）到這裡停在入口放手   # 右手去拿子彈的地方（畫面外右下）


## 長槍換一發（_round_t 0→1）：右手離開握把→畫面外拿子彈→對準入口→塞進去→回來握好。
## 散彈折開的前段先把空殼往後上彈出來
func _hand_reload(delta: float) -> void:
	var hand_node := _support if reload_with_support else _grip
	if not hand_node or not _hand_round or not _model:
		return
	if _round_t < 1.0:
		_round_t = minf(_round_t + delta / _round_dur, 1.0)
	var t := _round_t
	var space := get_node(load_space_path) as Node3D
	var parent := hand_node.get_parent() as Node3D
	var to_parent := parent.global_transform.affine_inverse()
	var rest := support_hand.origin if reload_with_support else grip_hand.origin
	var pocket := to_parent * to_global(fetch_pocket)   # 拿子彈的地方以鏡頭（武器節點）為準：換彈時槍翻很大，跟著槍會跑到鏡頭前
	var out := to_parent * space.to_global(load_out + load_hand_offset)
	var inn := to_parent * space.to_global(load_in + load_hand_offset)
	var round_on := false
	var round_at := Vector3.ZERO    # load_space 座標
	var pinching := false           # 會動的手：這幀用捏子彈的手
	var pinch_at := Vector3.ZERO
	if t < 1.0:
		var hand := rest
		if reload_with_support:
			# 左手送魚叉：拿到（0–0.25）→ 對準管口（–0.45）→ 插進去（–0.62）→ 直接往左下退出畫面（審查：插好之後畫面上不要再有左手）
			if t < 0.25:
				hand = rest.lerp(pocket, smoothstep(0.0, 0.25, t))
			elif t < 0.45:
				hand = pocket.lerp(out, smoothstep(0.25, 0.45, t))
			elif t < 0.62:
				hand = out.lerp(inn, smoothstep(0.45, 0.62, t))
			else:
				hand = inn.lerp(pocket, smoothstep(0.62, 0.8, t)).lerp(rest, smoothstep(0.8, 1.0, t))
		elif t < 0.25:
			hand = rest.lerp(pocket, smoothstep(0.0, 0.25, t))
		elif t < 0.5:
			# 從槍的上方繞一個小弧線到入口（審查：直線過去散彈的彈殼會先切進機匣）
			var k := smoothstep(0.25, 0.5, t)
			hand = pocket.lerp(out, k) + to_parent.basis * space.global_basis.y.normalized() * (approach_lift * sin(PI * k))
		elif t < 0.72:
			hand = out.lerp(inn, smoothstep(0.5, 0.72, t))
		elif _pinch_rig and t < RELEASE_END:
			hand = inn   # 會動的手：塞完先停在入口張開手指放手，再換回握槍的手往回走（邊退邊轉會擦過鏡頭前）
		else:
			hand = inn.lerp(rest, smoothstep(RELEASE_END if _pinch_rig else 0.72, 1.0, t))
		hand_node.position = hand
		var put := 0.62 if reload_with_support else 0.72   # 塞進去的那一刻
		if t >= (0.1 if reload_with_support else 0.3) and t < put:   # 左手送魚叉：一伸進畫面手上就要拿著（第二輪審查）
			round_on = true
			round_at = space.to_local(parent.to_global(hand)) - load_hand_offset
		# 會動的手：捏子彈的手塞完不馬上變回握槍的拳頭，先張開放手、退一段才換回去
		if _pinch_rig and t >= 0.3 and t < RELEASE_END:
			pinching = true
			pinch_at = space.to_local(parent.to_global(hand)) - load_hand_offset
			_release = smoothstep(put, RELEASE_END - 0.02, t)
		elif load_eject and t > 0.03 and t < 0.3:
			var k := t / 0.3
			round_at = load_in + Vector3(0.05 * k, 0.06 * k - 0.4 * k * k, 0.08 * k)   # 往後彈出一點、掉下去
			round_on = true
	else:
		# 沒在換（或被打斷）：手滑回握把，不要瞬間跳回去
		hand_node.position = hand_node.position.lerp(rest, minf(delta * 12.0, 1.0))
	# 手的朝向：換彈時槍翻轉很大（照影片：步槍把右側裝填口翻上來），手跟著翻的話整條前臂會橫過畫面。
	# 換彈姿勢越到位，手越保持腰射時在鏡頭裡的朝向
	var rest_basis := (support_hand.basis if reload_with_support else grip_hand.basis).orthonormalized()   # 場景裡存的有捨入誤差，slerp 要正規化過的
	var keep := global_basis * Basis.from_euler(reload_hand_turn) * Basis.from_euler(hip_rotation) * rest_basis
	var k := smoothstep(0.0, 1.0, _reload_pose)
	hand_node.basis = rest_basis.slerp((parent.global_basis.inverse() * keep).orthonormalized(), k)
	# 拿著子彈的那段換成拿子彈的手（HandLoad，原點在子彈中心）：握槍的拳頭拿子彈，手指是對著空氣彎的
	if _pinch_mesh and hand_node is MeshInstance3D:
		var mi := hand_node as MeshInstance3D
		mi.mesh = _pinch_mesh if round_on else _hold_mesh
		if round_on:
			# HandLoad 原點在子彈中心、子彈沿 -Z（拇指頂彈底、食指搭在彈殼上），直接疊在子彈上
			var flip := Basis.IDENTITY if reload_with_support else Basis.from_scale(Vector3(-1, 1, 1))   # HandLoad 是左手，右手用要鏡射
			mi.global_transform = Transform3D(space.global_basis * Basis.from_euler(pinch_rotation) * flip,
				space.to_global(round_at + Vector3(0, 0, -_pinch_shift)))
		for c in mi.get_children():   # 拇指、前臂是握槍姿勢的，捏的時候藏起來
			(c as Node3D).visible = not round_on
	elif _pinch_rig:
		# 會動的手：握槍的那副和捏子彈的那副切換顯示；捏的時候整個外層節點擺到子彈那裡（跟以前換網格一樣的擺法）
		for c in hand_node.get_children():
			(c as Node3D).visible = (c == _pinch_rig) == pinching
		if pinching:
			var flip := Basis.IDENTITY if reload_with_support else Basis.from_scale(Vector3(-1, 1, 1))   # 捏子彈的手是左手，右手用要鏡射
			hand_node.global_transform = Transform3D(space.global_basis * Basis.from_euler(pinch_rotation) * flip,
				space.to_global(pinch_at + Vector3(0, 0, -_pinch_shift)))
	_hand_round.visible = round_on
	if round_on:
		_hand_round.global_transform = Transform3D(space.global_basis, space.to_global(round_at))


# 塞彈的關鍵位置（槍模型座標，Godot 軸向）。捏的那一點＝彈底
# 照影片 20～25 秒：每一發手從畫面左下捏著子彈伸進來、塞進裝填門、往右下角收出畫面（武器節點座標＝鏡頭附近）
const LOAD_ENTER_VIEW := Vector3(0.0, -0.30, 0.05)
const LOAD_AWAY_VIEW := Vector3(0.16, -0.30, 0.05)
const LOAD_OUT := Vector3(0.0108, 0.0288, 0.035)     # 對準裝填門後面
const LOAD_IN := Vector3(0.0108, 0.0288, -0.006)     # 子彈塞進去了
const ROUND_HALF := 0.0148                           # 子彈原點到彈底


## 一發的流程（_round_t 0→1）：退殼桿把空殼頂出來、手捏著子彈從左下伸進來→對準裝填門塞進去→往右下收手。
## 轉輪在塞完之後轉一格，下一發對到裝填門
func _revolver_reload(delta: float, rp: float) -> void:
	if _gate:
		_gate.rotation.z = -1.4 * smoothstep(0.3, 0.8, rp)   # 往右下翻開
	var was := _round_t
	if _round_t < 1.0:
		_round_t = minf(_round_t + delta / _round_dur, 1.0)
	var t := _round_t
	# 手的起點、拿子彈的地方照鏡頭定（畫面右下方外面）：照槍定的話，換彈時槍翻過來，手會從左上方伸過來
	var to_model := _model.transform.affine_inverse() if _model else Transform3D.IDENTITY
	var away: Vector3 = to_model * LOAD_AWAY_VIEW
	var enter: Vector3 = to_model * LOAD_ENTER_VIEW
	var hand := away
	var push := 0.0
	var round_at := Vector3.ZERO
	var round_on := false
	if t < 1.0:
		# 手不去槍口推退殼桿（伸到畫面正中間會擋住視線，影片也沒有）：退殼桿自己推出空殼，手同時從左下伸進來
		push = smoothstep(0.0, 0.12, t) - smoothstep(0.2, 0.3, t)
		if t < 0.45:
			hand = enter.lerp(LOAD_OUT, smoothstep(0.0, 0.45, t))
		elif t < 0.65:
			hand = LOAD_OUT.lerp(LOAD_IN, smoothstep(0.45, 0.65, t))
		else:
			hand = LOAD_IN.lerp(away, smoothstep(0.65, 1.0, t))
		# 空殼從裝填門往後彈出、往下掉；新的那顆捏在手上直到塞進去
		if t > 0.05 and t < 0.3:
			var k := t - 0.05
			round_at = LOAD_IN + Vector3(0.0, 0.0, -ROUND_HALF) + Vector3(0.05 * k, -1.2 * k * k, 0.35 * k)
			round_on = true
		elif t >= 0.3 and t < 0.65:
			round_at = hand + Vector3(0.0, 0.0, -ROUND_HALF)
			round_on = true
		if was < 0.85 and t >= 0.85:
			_turns += 1
	if _ejector:
		_ejector.position = _ejector_rest + Vector3(0.0, 0.0, 0.032 * push)
	if _load_hand:
		# 沒在塞的時候手慢慢退到畫面外；退到了就藏起來
		# hand 是彈底那一點；HandLoad 是照散彈擺的（原點在散彈中心、拇指頂彈底），往子彈那邊挪半顆散彈，拇指就頂在這顆的底
		var at := hand + Vector3(0.0, 0.0, -HAND_SHELL_HALF)
		_load_hand.position = at if t < 1.0 else _load_hand.position.lerp(away, minf(delta * 10.0, 1.0))
		_load_hand.basis = Basis.from_euler(load_hand_rotation)   # 外層是槍模型，子彈在模型裡沿 -Z
		var cam := get_viewport().get_camera_3d()
		if _load_sk and cam and pinch_arm_dir != Vector3.ZERO:   # 手跟著子彈斜，前臂不轉出去會直直立起來
			_load_sk.reset_bone_poses()
			_aim_bone(_load_sk, "LowerArm", cam.global_basis * pinch_arm_dir.normalized())
		_load_hand.visible = rp > 0.05 and (t < 1.0 or _load_hand.position.distance_to(away) > 0.01)
	if _round:
		_round.visible = round_on
		_round.position = round_at
