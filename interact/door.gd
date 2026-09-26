class_name Door
extends StaticBody3D
## 門：看著它按 F 開關。滑門（穀倉大門）平移，推門（後門、農舍）繞門軸轉。
##
## 主機說了算：誰按 F 都是請主機切換，主機再廣播給所有人（包括自己）。
## 門的節點名字由 main.gd 依序取（Door0、Door1…），每台機器蓋出來的場景一樣，RPC 才找得到同一扇門。
## 晚加入的人由 main.gd 在他連進來時補送一次開著的門。
##
## ponytail: 不檢查誰站在門口，關門會直接把人擠開。真的有人卡門再加。

## 開的時候往哪移（滑門，場地座標）
var slide := Vector3.ZERO
## 開的時候繞 Y 轉多少弧度（推門）
var swing := 0.0
var is_open := false
## 看著門時畫面上的提示（cowboy.gd 讀這個）
var prompt := "開門"

var _closed: Transform3D


func _ready() -> void:
	_closed = transform


func interact(_who: Node) -> void:
	if multiplayer.is_server():
		_set_open.rpc(not is_open)
	else:
		_request.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request() -> void:
	if multiplayer.is_server():
		_set_open.rpc(not is_open)


@rpc("authority", "call_local", "reliable")
func _set_open(v: bool) -> void:
	set_open(v)


## instant = true 直接到位（測試、晚加入的人補狀態），不然動畫推開
func set_open(v: bool, instant := false) -> void:
	is_open = v
	prompt = "關門" if v else "開門"
	var target := _closed
	if v:
		target = Transform3D(_closed.basis.rotated(Vector3.UP, swing), _closed.origin + slide)
	if instant:
		transform = target
		return
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)   # 碰撞跟著物理幀動，不會跟畫面差一幀
	t.tween_property(self, "transform", target, 0.4)
