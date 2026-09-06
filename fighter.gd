extends CharacterBody3D
## 坦克和恐龍共用的部分：血量、死亡、多人連線權限。

signal died

const GRAVITY := 25.0
const LOOK_SETTLE_MS := 1500  # 滑鼠鎖定後先忽略這麼久的位移

@export var max_hp := 100

var hp := 0
var _was_captured := false
var _settle_until := 0


func _enter_tree() -> void:
	# 節點名字就是玩家的連線編號，誰的節點誰操控
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	hp = max_hp

## 只有主機會呼叫這個
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	_sync_hp.rpc(hp - amount)

# ponytail: 主機算完傷害直接廣播結果，不驗證來源。原型不防作弊，要防再改成主機權威輸入。
@rpc("any_peer", "call_local", "reliable")
func _sync_hp(v: int) -> void:
	if v < hp:
		_flash_red()
	hp = v
	if hp <= 0:
		died.emit()
		if multiplayer.is_server():
			queue_free()  # MultiplayerSpawner 會同步移除其他人畫面上的它

## 取滑鼠這一幀轉了多少。
## 滑鼠一被鎖定，macOS 會噴出一串「游標歸位」的殘留位移（實測從鎖定後 780ms 開始、
## 衰減到 1200ms 才停），不擋掉的話砲塔一進遊戲就自己甩到隨機角度。
## ponytail: 直接用固定時間窗擋掉，夠簡單也夠用。如果哪天在別的機器上還是會甩，
## 就把 LOOK_SETTLE_MS 調大，或改成「等到位移出現一段空檔才開始吃輸入」。
func mouse_look(e: InputEvent) -> Vector2:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured != _was_captured:
		_was_captured = captured
		_settle_until = Time.get_ticks_msec() + LOOK_SETTLE_MS
	if not captured or not is_multiplayer_authority() or not (e is InputEventMouseMotion):
		return Vector2.ZERO
	if Time.get_ticks_msec() < _settle_until:
		return Vector2.ZERO
	return e.relative

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


## 中彈閃一下紅。用 material_overlay 蓋在原本材質上，
## 每次都新建材質，才不會跟別台共用的材質互相干擾。
func _flash_red() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.2, 0.15, 0.5)
	var meshes := find_children("*", "MeshInstance3D")
	for mi: MeshInstance3D in meshes:
		mi.material_overlay = mat
	var t := create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	t.tween_callback(func() -> void:
		for mi: MeshInstance3D in meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null)
