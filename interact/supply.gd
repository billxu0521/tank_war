class_name SupplyCrate
extends StaticBody3D
## 補給箱：場上原本擺的木箱（Crate）都是。看著按 F，炸藥和炸彈長矛的魚叉補滿。
## 同一個箱子補過要等 COOLDOWN 秒。冷卻只記在自己這台（每個人各算各的），不用同步（規劃 docs/規劃/2026-10-04-炸藥與炸彈長矛.md）

const COOLDOWN := 60.0
var _ready_at := 0.0   # 這台的遊戲時間（秒）到這之後才能再補

## 看著箱子時畫面上的提示（cowboy.gd 讀這個）
var prompt: String:
	get:
		var left := _ready_at - _now()
		return "補給（炸藥、魚叉）" if left <= 0.0 else "補給箱（還要 %d 秒）" % ceili(left)


func interact(who: Node) -> void:
	if _now() < _ready_at:
		return
	if who.viewmodel.resupply():
		_ready_at = _now() + COOLDOWN


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
