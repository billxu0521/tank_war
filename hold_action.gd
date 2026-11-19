class_name HoldAction
extends Node
## 按住幾秒的互動（docs/企劃/2026-11-19-0.8.16-一般模式與規則改動.md 第 3 節）：搜刮倒地的尼諾拉；之後團隊模式的救人、復活、拷問、自救也用這個。
## main 底下一個（名字固定 Hold，RPC 每台找得到）。
## 主機記「誰、在做哪一種、對著誰、做了幾秒」，每個物理幀問那一種的 ok 還成不成立（距離、活著、對方狀態），
## 滿了叫 done，不成立就清掉。客戶端只送「我按下／放開了」；主機回本人「開始／停了」，進度本人自己數（畫在 center_info）。
## 一種互動 = register(種類, 秒數, ok, done, 字)。ok(id, target) -> bool、done(id, target)，都只在主機叫。
## 電腦直接在主機叫 start／stop。

var kinds := {}     # 種類 -> {secs, ok, done, label}
var _doing := {}    # 主機：連線編號 -> [種類, 對象, 做了幾秒]
var mine := &""     # 這台的人正在做的種類（按下就先設，主機拒絕或停了再清）
var mine_t := 0.0   # 這台自己數的進度（秒）

@onready var main: Node = get_parent()


func register(kind: StringName, secs: float, ok: Callable, done: Callable, label: String) -> void:
	kinds[kind] = {secs = secs, ok = ok, done = done, label = label}


func unregister(kind: StringName) -> void:
	kinds.erase(kind)
	for id: int in _doing.keys():
		if _doing[id][0] == kind:
			_doing.erase(id)
	if mine == kind:
		mine = &""


## 本人按下（看著 target 按住 F）。主機自己玩就直接算
func press(kind: StringName, target: Node) -> void:
	if not kinds.has(kind) or mine != &"":
		return
	mine = kind
	mine_t = 0.0
	if multiplayer.is_server():
		start(multiplayer.get_unique_id(), kind, target)
	else:
		_press.rpc_id(1, kind, main.get_path_to(target))


## 本人放開
func release() -> void:
	if mine == &"":
		return
	mine = &""
	if multiplayer.is_server():
		stop(multiplayer.get_unique_id())
	else:
		_release.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _press(kind: StringName, path: NodePath) -> void:
	if multiplayer.is_server() and kinds.has(kind):
		start(multiplayer.get_remote_sender_id(), kind, main.get_node_or_null(path))


@rpc("any_peer", "call_remote", "reliable")
func _release() -> void:
	if multiplayer.is_server():
		stop(multiplayer.get_remote_sender_id())


## 主機：id 開始對 target 做 kind。不成立就回 false（也告訴本人停了）
func start(id: int, kind: StringName, target: Node) -> bool:
	if target == null or not kinds.has(kind) or not kinds[kind].ok.call(id, target):
		_tell(id, &"")
		return false
	_doing[id] = [kind, target, 0.0]
	_tell(id, kind)
	return true


## 主機：id 停下來（放開、被取消）
func stop(id: int) -> void:
	if _doing.erase(id):
		_tell(id, &"")


## 主機：id 正在做的種類（沒在做是 &""）
func doing(id: int) -> StringName:
	return _doing[id][0] if _doing.has(id) else &""


## 主機：id 做了幾秒（沒在做是 -1）
func progress(id: int) -> float:
	return _doing[id][2] if _doing.has(id) else -1.0


func _physics_process(delta: float) -> void:
	if _doing.is_empty() or not multiplayer.is_server():
		return
	for id: int in _doing.keys():
		var d: Array = _doing[id]
		var k: Dictionary = kinds[d[0]]
		if not is_instance_valid(d[1]) or not k.ok.call(id, d[1]):
			stop(id)
			continue
		d[2] += delta
		if d[2] >= k.secs:
			_doing.erase(id)
			_tell(id, &"")
			k.done.call(id, d[1])


func _process(delta: float) -> void:
	if mine != &"":
		mine_t += delta


## 這台的進度字（center_info 用）；沒在做是 ""
func mine_text() -> String:
	if mine == &"" or not kinds.has(mine):
		return ""
	var k: Dictionary = kinds[mine]
	return "%s… %d%%" % [k.label, mini(roundi(mine_t / k.secs * 100.0), 100)]


## 主機：告訴本人開始（kind）或停了（&""）。電腦不用送
func _tell(id: int, kind: StringName) -> void:
	if id == multiplayer.get_unique_id():
		_state(kind)
	elif id > 0 and multiplayer.get_peers().has(id):
		_state.rpc_id(id, kind)


@rpc("authority", "call_remote", "reliable")
func _state(kind: StringName) -> void:
	if kind != mine:
		mine_t = 0.0
	mine = kind
