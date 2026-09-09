extends SceneTree
## 全 bot 自動對戰，跑 N 場印統計。
##   godot --headless --script sim.gd -- 20
##
## 目的不是「有對手陪你練」，是把平衡問題變成可量測的：
## 改一個數字，再跑一次，直接看勝率和局長差多少。
## 因為要歸因到參數，bot 刻意寫成固定的優先序策略，不加隨機。

const SPEED_UP := 20.0   # 加速跑，一場四分鐘的比賽約十幾秒跑完

var _matches := 5
var _left := 0
var _m: Node
var _t0 := 0.0
var _prev_carrier := 0
var _pickups := 0
var _closest := 9999.0   # 這場蛋最接近撤離區到幾公尺
var _seen: Dictionary = {}   # 已經計過的死亡事件
var _tank_deaths := 0
var _dino_deaths := 0
var _rows: Array[Dictionary] = []
var _boot := 0
var _events: Array[String] = []      # 這場的事件時間軸
var _all_log := ""                   # 全部場次，最後寫檔
var _by_dino := 0                    # 坦克死在恐龍手上幾次
var _by_tank := 0                    # 坦克死在彼此手上幾次
var _egg_kills := 0                  # 有幾次是持蛋的人被打死

func _process(_dt: float) -> bool:
	_boot += 1
	if _boot == 1:
		var args := OS.get_cmdline_user_args()
		if args.size() > 0 and args[0].is_valid_int():
			_matches = args[0].to_int()
		_left = _matches
		Engine.time_scale = SPEED_UP
		print("跑 %d 場全 bot 對戰（1 恐龍 vs 3 坦克，加速 %.0f 倍）\n" % [_matches, SPEED_UP])
		return false

	if _m == null:
		if _left <= 0:
			_report()
			return true
		_start_match()
		return false

	_watch()
	if _m._over or Time.get_ticks_msec() / 1000.0 - _t0 > 120.0:
		_finish_match()
	return false

func _start_match() -> void:
	_left -= 1
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	_m.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_m._offline = true
	_m._enter_game("sim")
	_events.clear()
	_m.logged.connect(_on_event)
	for i in 4:
		var p: Node3D = _m._add_player(_m.DINO if i == 0 else _m.TANK, i + 1)
		p.set(&"bot", true)
	_t0 = Time.get_ticks_msec() / 1000.0
	_prev_carrier = 0
	_pickups = 0
	_closest = 9999.0
	_seen.clear()
	_tank_deaths = 0
	_dino_deaths = 0

## 事件進來就記下來，順便分類「坦克是死在恐龍還是死在彼此手上」
func _on_event(text: String) -> void:
	_events.append(text)
	# 要看「死的是誰」，不能只看「兇手是誰」——恐龍被坦克打死也符合「被 坦克」
	var parts := text.split(" 被 ")
	if parts.size() == 2 and parts[1].contains("打死") and parts[0].contains("坦克"):
		if parts[1].begins_with("恐龍"):
			_by_dino += 1
		elif parts[1].begins_with("坦克"):
			_by_tank += 1
	if text.contains("（身上有蛋）"):
		_egg_kills += 1

func _watch() -> void:
	# 每筆重生佇列 = 一次死亡。用 id+時間戳當 key，才不會重複計。
	for r: Dictionary in _m._respawn_queue:
		var key := "%d@%d" % [int(r["id"]), int(r["at"])]
		if _seen.has(key):
			continue
		_seen[key] = true
		if bool(r["dino"]):
			_dino_deaths += 1
		else:
			_tank_deaths += 1

	var c: int = _m.egg.carrier
	if c != 0 and _prev_carrier == 0:
		_pickups += 1
	_prev_carrier = c
	if c != 0:
		for e: Vector3 in _m._exits:
			var d := Vector2(_m.egg.global_position.x - e.x, _m.egg.global_position.z - e.z).length()
			_closest = minf(_closest, d)

func _finish_match() -> void:
	var timeout: bool = _m.status.text.contains("時間到") or not _m._over
	var left: float = maxf(_m._time_left, 0.0)
	_rows.append({
		"dino_win": timeout,
		"secs": _m.MATCH_SECONDS - left,
		"pickups": _pickups,
		"closest": _closest,
		"tank_deaths": _tank_deaths,
		"dino_deaths": _dino_deaths,
	})
	var head := "第 %d 場：%s，%.0f 秒，撿蛋 %d 次，坦克死 %d 次，恐龍死 %d 次" % [
		_rows.size(), "恐龍贏（時間到）" if timeout else "坦克贏（撤離成功）",
		_m.MATCH_SECONDS - left, _pickups, _tank_deaths, _dino_deaths]
	print(head)
	_all_log += "\n===== %s =====\n" % head
	for e: String in _events:
		_all_log += e + "\n"
	if _rows.size() <= 2:   # 前兩場印時間軸出來看，其餘只寫檔
		for e: String in _events:
			print("    " + e)
	_m.multiplayer.multiplayer_peer = null
	root.remove_child(_m)
	_m.free()
	_m = null

func _report() -> void:
	var dino_wins := 0
	var secs := 0.0
	var pickups := 0
	var closest := 0.0
	var reached := 0
	for r: Dictionary in _rows:
		if bool(r["dino_win"]):
			dino_wins += 1
		secs += float(r["secs"])
		pickups += int(r["pickups"])
		if float(r["closest"]) < 9999.0:
			closest += float(r["closest"])
			reached += 1
	var n := _rows.size()
	print("\n===== %d 場統計 =====" % n)
	print("恐龍勝率　　%d%%（%d 場時間到沒人撤離）" % [100 * dino_wins / n, dino_wins])
	print("坦克勝率　　%d%%（%d 場成功撤離）" % [100 * (n - dino_wins) / n, n - dino_wins])
	print("平均局長　　%.0f 秒（上限 %.0f）" % [secs / n, 240.0])
	print("平均撿蛋　　%.1f 次／場" % (float(pickups) / n))
	var td := 0
	var dd := 0
	for r: Dictionary in _rows:
		td += int(r["tank_deaths"])
		dd += int(r["dino_deaths"])
	print("平均死亡　　坦克 %.1f 次／場，恐龍 %.1f 次／場" % [float(td) / n, float(dd) / n])
	if td > 0:
		print("坦克死因　　恐龍 %d 次（%d%%），彼此互殺 %d 次（%d%%）" % [
			_by_dino, 100 * _by_dino / td, _by_tank, 100 * _by_tank / td])
	print("持蛋被殺　　%d 次（佔撿蛋 %d 次的 %d%%）" % [
		_egg_kills, pickups, 100 * _egg_kills / maxi(pickups, 1)])
	if reached > 0:
		print("蛋平均最接近出口 %.0f 公尺（有撿起來的 %d 場）" % [closest / reached, reached])
	_write_files()

func _write_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://sim_out"))
	var log_file := FileAccess.open("res://sim_out/sim_log.txt", FileAccess.WRITE)
	log_file.store_string(_all_log)
	log_file.close()

	var csv := FileAccess.open("res://sim_out/sim_results.csv", FileAccess.WRITE)
	csv.store_line("match,winner,seconds,pickups,tank_deaths,dino_deaths,closest_to_exit")
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		csv.store_line("%d,%s,%.0f,%d,%d,%d,%.0f" % [
			i + 1, "dino" if bool(r["dino_win"]) else "tank",
			float(r["secs"]), int(r["pickups"]),
			int(r["tank_deaths"]), int(r["dino_deaths"]),
			float(r["closest"]) if float(r["closest"]) < 9999.0 else -1.0])
	csv.close()
	print("\n時間軸 -> sim_out/sim_log.txt，每場一行 -> sim_out/sim_results.csv")
