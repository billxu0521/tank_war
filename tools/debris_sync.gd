extends SceneTree
## 碎塊各台位置對不對得上（真的連線）：一台主機＋幾個客戶端，主機照時間表拆一棟房子，停下來後每台把每個碎塊的位置寫成檔，主機比對。
## 一次開完整組用 tools/debris_sync.sh。角色：
##   ROLE=server  主機（HOST=dedicated 專用伺服器、碎塊不飛；HOST=listen 自己開房、碎塊照飛）
##   ROLE=client  客戶端。LATE=1：等主機說「join」才連（晚加入）；DROP=1：主機說「drop」時斷線、場景重載、再連回（重連）
## 環境變數 DIR：各台交換訊號和檔案的資料夾（主機寫 DIR/<訊號>，客戶端看到就做）。
## 每台每幀記每個碎塊經歷過什麼（生R＝生成會飛的、生S＝生成靜態的、停＝飛的換成靜態、踢＝靜態換成飛的（炸藥）、移＝靜態的被搬位置、併N＝N 塊併成一塊）。
## 時間表跟著 #169：落地的碎塊走路、衝撞推不動，只有炸藥推（爆炸推停下的碎塊）。
## 最後主機印「DEBRIS_SYNC OK」或「DEBRIS_SYNC FAIL」（有對不上、有台沒有、掉到地底的就 FAIL；Godot 解析錯誤也回 0，要看這行）。

var _role := OS.get_environment("ROLE")
var _dir := OS.get_environment("DIR")
var _host_kind := OS.get_environment("HOST")
var _name := OS.get_environment("NAME")
var _m: Node
var _f := 0
var _t0 := -1.0        # 主機：客戶端都連上的時刻（秒）
var _step := 0
var _h: ToyBuild       # 主機：拆的那棟
var _hist := {}        # "ToyN/key" -> 經歷（字串）
var _cls := {}         # "ToyN/key" -> "R"／"S"
var _pos := {}         # "ToyN/key" -> 上次看到的位置（靜態的）
var _joined := false
var _seen := {}        # 客戶端：處理過的訊號
var _old_id := 0       # 客戶端：重連前場景的編號（等它換掉）
var _done := false

const N_CLIENTS_ENV := "CLIENTS"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _initialize() -> void:
	seed(1)
	_m = load("res://main.tscn").instantiate()
	root.add_child(_m)
	current_scene = _m   # 回大廳時拆過的場景會重載（main._to_lobby），跟遊戲一樣


func _sig(s: String) -> bool:
	return FileAccess.file_exists(_dir + "/" + s)


func _say(s: String) -> void:
	FileAccess.open(_dir + "/" + s, FileAccess.WRITE).store_string("1")
	print("DS 主機 t=%.1f 訊號 %s" % [_now() - _t0, s])


func _process(_d: float) -> bool:
	_f += 1
	if current_scene != _m and current_scene != null:   # 重載過：換成新的場景
		_m = current_scene
		_hist.clear()
		_cls.clear()
		_pos.clear()
	if not is_instance_valid(_m) or not _m.is_node_ready():
		return false
	_track()
	if _role == "server":
		return _server()
	return _client()


## 每台每幀：記每個碎塊的狀態變化
func _track() -> void:
	if _m.get("map") == null:
		return
	for t: ToyBuild in _m.map._toys:
		if not is_instance_valid(t):
			continue
		for key in t._pieces:
			var n: Node3D = t._pieces[key]
			if not is_instance_valid(n):
				continue
			var id := "%s/%d" % [t.name, key]
			var c := "R" if n is RigidBody3D else "S"
			var prev: String = _cls.get(id, "")
			if prev == "":
				var mem: int = (t._info[key].m as PackedInt32Array).size()
				_hist[id] = ("補" if _joined_late() else "生") + c + ("併%d" % mem if mem > 1 else "")
			elif prev != c:
				_hist[id] += " 停" if c == "S" else " 踢"
			elif c == "S" and n.global_position.distance_to(_pos[id]) > 0.01:
				_hist[id] += " 移"
			_cls[id] = c
			_pos[id] = n.global_position


func _joined_late() -> bool:
	return _role == "client" and (OS.get_environment("LATE") != "" or _seen.has("drop")) and _f < _join_f + 30
var _join_f := 0
var _drop_f := 0


func _client() -> bool:
	if _f == 2 and OS.get_environment("LATE") == "":
		_join()
	if OS.get_environment("LATE") != "" and not _seen.has("join") and _sig("join"):
		_seen["join"] = true
		_join()
	if OS.get_environment("DROP") != "" and not _seen.has("drop") and _sig("drop"):
		_seen["drop"] = true
		_drop_f = _f
		print("DS %s 斷線" % _name)
		_old_id = _m.get_instance_id()
		_m._to_lobby("debris_sync 斷線")   # 拆過的：場景重載（跟遊戲一樣）
	if _old_id != 0 and _m.get_instance_id() != _old_id and _m.is_node_ready() and _f > _drop_f + 60 and not _seen.has("rejoin"):
		_seen["rejoin"] = true
		print("DS %s 重連" % _name)
		_join()
	for p in ["dump1", "dump2"]:
		if not _seen.has(p) and _sig(p):
			_seen[p] = true
			_dump(p)
	return _sig("quit")


func _join() -> void:
	_join_f = _f
	_m.ip_edit.text = "127.0.0.1"
	_m.player_key = "ds-" + _name
	_m._on_join_pressed()


## 這台的每個碎塊：編號、R／S、位置、經歷；孤兒（場上有、但不在任何一棟的 _pieces 裡）；每棟鬆脫了幾塊
func _dump(tag: String) -> void:
	var f := FileAccess.open("%s/%s_%s.txt" % [_dir, _name, tag], FileAccess.WRITE)
	var owned := {}
	for t: ToyBuild in _m.map._toys:
		var loose := 0
		var h := 0
		for i in t._loose.size():
			if t._loose[i] == 1:
				loose += 1
				h = (h * 31 + i) % 1000000007
		if loose > 0:
			f.store_line("%s\tLOOSE\t%d\t%d" % [t.name, loose, h])
		for key in t._pieces:
			var n: Node3D = t._pieces[key]
			if not is_instance_valid(n):
				continue
			owned[n] = true
			var id := "%s/%d" % [t.name, key]
			var p := n.global_position
			f.store_line("%s\t%s\t%.3f\t%.3f\t%.3f\t%s" % [id, "R" if n is RigidBody3D else "S", p.x, p.y, p.z, _hist.get(id, "?")])
	for n: Node in get_nodes_in_group(&"toy_piece"):
		if not owned.has(n) and not n.is_queued_for_deletion():
			var p := (n as Node3D).global_position
			f.store_line("orphan:%s\t%s\t%.3f\t%.3f\t%.3f\t孤兒" % [n.name, "R" if n is RigidBody3D else "S", p.x, p.y, p.z])
	f.close()
	FileAccess.open("%s/%s_%s.ok" % [_dir, _name, tag], FileAccess.WRITE).store_string("1")
	print("DS %s 寫 %s" % [_name, tag])


# ---- 主機 ----

func _server() -> bool:
	if _f == 2 and _host_kind == "listen":
		_m._on_host_pressed()
	var need := int(OS.get_environment(N_CLIENTS_ENV))
	if _t0 < 0:
		if _m.multiplayer.multiplayer_peer == null or _m.multiplayer.get_peers().size() < need:
			if _f > 60 * 60:
				print("DEBRIS_SYNC FAIL: 等不到 %d 個客戶端" % need)
				return true
			return false
		_t0 = _now()
		_pick()
	var t := _now() - _t0
	var plan := [
		[2.0, "炸藥（爆炸拆牆）", _blast_wall],
		[6.0, "火球", _fireball],
		[10.0, "衝撞（全速撞；落地的碎塊推不動，#169）", _charge],
		[23.0, "炸碎塊（爆炸推停下的碎塊，這棟的碎塊這時都停了）", _blast_pieces],
		[29.0, "晚加入", func() -> void: _say("join")],
		[33.0, "斷線重連", func() -> void: _say("drop")],
		[40.0, "第二棟撞垮半棟（併成大塊；晚加入、重連的人都在）", _blast_other],
		[44.0, "火球（第二棟）", _fireball_other],
		[60.0, "比對 1", func() -> void: _say("dump1"); _dump("dump1")],
		[75.0, "比對 2（再等 15 秒，看是不是一直不一樣）", func() -> void: _say("dump2"); _dump("dump2")],
	]
	if _step < plan.size() and t >= plan[_step][0]:
		print("DS 主機 t=%.1f %s" % [t, plan[_step][1]])
		(plan[_step][2] as Callable).call()
		_step += 1
	if _step >= plan.size() and not _done:
		var want := ["host"]
		for n in OS.get_environment("NAMES").split(" ", false):
			want.append(n)
		if want.all(func(n: String) -> bool: return FileAccess.file_exists("%s/%s_dump2.ok" % [_dir, n])):
			_done = true
			var ok1 := _compare(want, "dump1")
			var ok2 := _compare(want, "dump2")
			_say("quit")
			print("DEBRIS_SYNC OK" if ok1 and ok2 else "DEBRIS_SYNC FAIL: 有對不上、有台沒有、或掉到地底的碎塊")
		elif t > 120.0:
			print("DEBRIS_SYNC FAIL: 等不到每台的檔案")
			_say("quit")
			return true
	return _done and t > 0.0 and _f % 120 == 0   # 等客戶端看到 quit 再走（幾幀就好）


## 拆的那棟：看得到、拆得掉、塊最多的。第二棟：其次的
var _h2: ToyBuild
func _pick() -> void:
	var c: Array = _m.map._toys.filter(func(t: ToyBuild) -> bool: return t.can_break and t.visible and t.brick_count() > 30)
	c.sort_custom(func(a: ToyBuild, b: ToyBuild) -> bool: return a.brick_count() > b.brick_count())
	_h = c[0]
	_h2 = c[1] if c.size() > 1 else c[0]
	print("DS 主機 拆 %s（%d 塊）、第二棟 %s（%d 塊）、模式 %s" % [_h.name, _h.brick_count(), _h2.name, _h2.brick_count(), _host_kind])


## 這棟靠地面、某一側的一塊（世界座標）
func _wall_point(t: ToyBuild, side: float) -> Vector3:
	var best := 0
	var score := -INF
	for i in t.brick_count():
		var l: Vector3 = t._xf[i].origin
		var s := l.x * side - absf(l.y - 1.0) * 3.0
		if t.is_standing(i) and t.level_of(i) < 3 and s > score:
			score = s
			best = i
	return t.center_of(best)


func _blast_wall() -> void:
	ToyBuild.blast(_m.map, _wall_point(_h, 1.0), 4.0)


func _fireball() -> void:
	var at := _wall_point(_h, -1.0)
	_h.fireball_fire(at, 2.5)
	_h.smash(func(p: Vector3) -> bool: return p.distance_to(at) < 2.5, Balance.whole("hit_fireball_force"), at + Vector3(-2, 0, 0), AABB(at - Vector3.ONE * 2.5, Vector3.ONE * 5.0))


func _fireball_other() -> void:
	var at := _wall_point(_h2, -1.0)
	_h2.fireball_fire(at, 2.5)
	_h2.smash(func(p: Vector3) -> bool: return p.distance_to(at) < 2.5, Balance.whole("hit_fireball_force"), at + Vector3(-2, 0, 0), AABB(at - Vector3.ONE * 2.5, Vector3.ONE * 5.0))


## 像 boss.gd 的全速撞：從 +Z 那側往 -Z 撞進去，身體前面的方塊範圍（落地的碎塊推不動，不踢）
func _charge() -> void:
	var c := _h.global_position + Vector3(0, 1.5, 0)
	var from := c + Vector3(0, 0, 6)
	var dir := Vector3(0, 0, -1)
	_h.smash(func(p: Vector3) -> bool: return absf(p.x - c.x) < 3.6 and p.y < c.y + 6.0 and p.z > c.z - 2.0, 2, from, AABB(c - Vector3(4, 2, 4), Vector3(8, 9, 12)), 7.5, 1, dir)


## 炸停下的碎塊：爆心放在碎塊堆的中間，只做 ToyBuild.blast 推碎塊那一半（不拆新的塊；拆到新的塊會順便打開每幀處理，蓋掉「全停後被炸」的情況）
func _blast_pieces() -> void:
	var c := Vector3.ZERO
	var n := 0
	for key in _h._pieces:
		c += (_h._pieces[key] as Node3D).global_position
		n += 1
	if n == 0:
		return
	c /= n
	var best := INF   # 爆心：離碎塊堆中間最近的那塊（中間本身可能是空的）
	var at := c
	for key in _h._pieces:
		var q := (_h._pieces[key] as Node3D).global_position
		if HitRules.pushable(_h._info[key].mt) and q.distance_to(c) < best:
			best = q.distance_to(c)
			at = q + Vector3(0.5, 0, 0.5)
	c = at
	var r := 4.0
	var k := 0
	var was := "開著" if _h.is_physics_processing() else "關著"
	for key in _h._pieces.keys():
		var d := (_h._pieces[key] as Node3D).global_position - c
		if d.length() < r and HitRules.pushable(_h._info[key].mt):
			_h.kick(key, (d.normalized() + Vector3.UP * 0.6).normalized(), Balance.num("blast_push") * (1.0 - d.length() / r))
			k += 1
	print("DS 主機 炸到 %d 塊（炸之前這棟的每幀處理 %s）" % [k, was])


## 第二棟整片撞垮（等級 2 以下、半棟）：一次鬆脫超過 MAX_PIECES，走併成大塊（_merge）
func _blast_other() -> void:
	var c := _h2.global_position
	var n := 0
	for i in _h2.brick_count():
		if _h2.center_of(i).x > c.x and _h2.is_standing(i) and _h2.level_of(i) <= 2:
			n += 1
	print("DS 主機 第二棟撞垮半棟（約 %d 塊）" % n)
	_h2.smash(func(p: Vector3) -> bool: return p.x > c.x, 2, c + Vector3(-8, 1, 0), AABB(), 7.5, 2, Vector3(1, 0, 0))


const DEEP := 10.0   # 比那棟原點低這麼多公尺算掉到地底


## 讀每台的檔、照碎塊編號對：印差最多的幾塊、它在每台經歷過什麼
func _compare(names: Array, tag: String) -> bool:
	var data := {}   # 名字 -> {id: [cls, pos, hist]}
	var loose := {}  # 名字 -> {toy: "數量/雜湊"}
	for nm: String in names:
		var d := {}
		var l := {}
		var f := FileAccess.open("%s/%s_%s.txt" % [_dir, nm, tag], FileAccess.READ)
		while f and not f.eof_reached():
			var s := f.get_line().split("\t")
			if s.size() == 4 and s[1] == "LOOSE":
				l[s[0]] = s[2] + "/" + s[3]
			elif s.size() >= 6:
				d[s[0]] = [s[1], Vector3(float(s[2]), float(s[3]), float(s[4])), s[5]]
		data[nm] = d
		loose[nm] = l
	var ids := {}
	for nm in names:
		for id in data[nm]:
			ids[id] = true
	var rows := []
	var missing := 0
	var orphans := 0
	var under := {}   # 名字 -> 掉到地底的塊數（比那棟原點低 DEEP 公尺）
	var toy_y := {}
	for t: ToyBuild in _m.map._toys:
		toy_y[String(t.name)] = t.global_position.y
	for nm in names:
		under[nm] = 0
		for id: String in data[nm]:
			if (data[nm][id][1] as Vector3).y < toy_y.get(id.get_slice("/", 0), -INF) - DEEP:
				under[nm] += 1
	for id: String in ids:
		if id.begins_with("orphan:"):
			orphans += 1
			continue
		var worst := 0.0
		var miss := []
		for a in names:
			if not data[a].has(id):
				miss.append(a)
				continue
			for b in names:
				if data[b].has(id):
					worst = maxf(worst, (data[a][id][1] as Vector3).distance_to(data[b][id][1]))
		if not miss.is_empty():
			missing += 1
		rows.append([worst, id, miss])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] + (1e5 if not (a[2] as Array).is_empty() else 0.0) > b[0] + (1e5 if not (b[2] as Array).is_empty() else 0.0))
	var bad := rows.filter(func(r: Array) -> bool: return r[0] > 0.05 or not (r[2] as Array).is_empty())
	print("DS ==== %s：%d 個碎塊，對不上（差 > 5 公分）%d 個、有台沒有 %d 個、孤兒 %d 個、掉到地底 %s" % [tag, rows.size(), bad.size(), missing, orphans, " ".join(names.map(func(nm: String) -> String: return "%s=%d" % [nm, under[nm]]))])
	var toys := {}
	for nm in names:
		for t in loose[nm]:
			toys[t] = true
	for t in toys:
		var v := names.map(func(nm: String) -> String: return "%s=%s" % [nm, loose[nm].get(t, "0")])
		var same := names.all(func(nm: String) -> bool: return loose[nm].get(t, "0") == loose[names[0]].get(t, "0"))
		print("DS   %s 鬆脫的塊 %s %s" % [t, "一樣" if same else "不一樣", " ".join(v) if not same else str(loose[names[0]].get(t, "0"))])
	# 依經歷分類（主機那邊的經歷）：哪一種情況對不上
	var by := {}
	for r: Array in bad:
		var key := _kind(data, names, r[1])
		by[key] = by.get(key, 0) + 1
	for k in by:
		print("DS   對不上的類別：%s ×%d" % [k, by[k]])
	for r: Array in bad.slice(0, 10):
		var parts := []
		for nm in names:
			if data[nm].has(r[1]):
				var e: Array = data[nm][r[1]]
				parts.append("%s %s (%.2f,%.2f,%.2f) [%s]" % [nm, e[0], e[1].x, e[1].y, e[1].z, e[2]])
			else:
				parts.append("%s 沒有" % nm)
		print("DS   差 %.2f 公尺 %s：%s" % [r[0], r[1], "；".join(parts)])
	for nm in names:
		for id: String in data[nm]:
			if id.begins_with("orphan:"):
				var e: Array = data[nm][id]
				print("DS   孤兒 %s %s %s (%.2f,%.2f,%.2f)" % [nm, id, e[0], e[1].x, e[1].y, e[1].z])
	return bad.is_empty() and missing == 0 and under.values().all(func(u: int) -> bool: return u == 0)


## 一塊對不上的情況：每台的 R／S 和主機的經歷，例如「主機 S [生S 踢] 客戶端 R」
func _kind(data: Dictionary, names: Array, id: String) -> String:
	var out := []
	for nm in names:
		if data[nm].has(id):
			var e: Array = data[nm][id]
			var h: String = e[2]
			out.append("%s:%s[%s]" % [nm, e[0], " ".join(Array(h.split(" ")).map(func(w: String) -> String: return w.rstrip("0123456789")))])
		else:
			out.append("%s:沒有" % nm)
	return " ".join(out)
