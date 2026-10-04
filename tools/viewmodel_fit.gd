extends SceneTree
## 第一人稱槍的擺位，照參考影片反推：影片畫面上量出槍口、擊錘等幾個點的位置（docs/movie/*.mov，
## 量法見 docs/素材流水線/程式建模迭代.md），這裡找 hip_position / hip_rotation（或 ads_position / ads_rotation）
## 讓我們的那幾個點投影到畫面上同樣的位置。直接算投影，不用渲染。
##   godot --headless --path . --script tools/viewmodel_fit.gd
## 座標：(x - 畫面中心) / 畫面高、(y - 中心) / 畫面高，往右、往下為正。FOV 是垂直視角

## 每一組：槍、狀態、鏡頭垂直 FOV、[模型空間的點, 影片上的位置]
const VIDEO_CX := 667.0   # 影片（1628×1034）裡遊戲畫面的中心：三支影片瞄準時準星都在 x≈667
const VIDEO_CY := 517.0
const VIDEO_H := 1034.0


static func gf(x: float, y: float) -> Vector2:
	## 遊戲畫面（1280×720，審查用的比例）上的位置 → 正規化座標
	return Vector2((x - 0.5) * 1280.0 / 720.0, y - 0.5)


static func px(x: float, y: float) -> Vector2:
	## 影片原始畫面（1628×1034）的像素 → 正規化座標。影片的準心＝瞄準時照門缺口 (668, 485)
	return Vector2((x - 668.0) / 1034.0, (y - 485.0) / 1034.0)


static func pxc(x: float, y: float, cx: float, cy: float) -> Vector2:
	## 同 px，但準心另外給（每支影片錄的位置不同：散彈 (676,416)、步槍 (679,455)，從瞄準那格量）
	return Vector2((x - cx) / 1034.0, (y - cy) / 1034.0)


static func aim(n: int) -> Array:
	## 槍管往前 30 m 落在準心，重複 n 次＝加權
	var out := []
	for i in n:
		out.append([Vector3(0, 0.04, -30.0), Vector2.ZERO])
	return out


static func vid(fx: float, fy: float) -> Vector2:
	## 網格圖（裁掉上方 59 px、縮成 960×540）上的比例座標 → 正規化座標
	return Vector2((fx * 1628.0 - VIDEO_CX) / VIDEO_H, (59.0 + fy * 916.0 - VIDEO_CY) / VIDEO_H)


## 點都在模型自己的座標（tools/viewmodel_fit.gd 開頭說明）；寬度點（±x）用來定距離：只對槍口和擊錘時，
## 槍大一倍放遠一倍投影一樣，影片裡機匣、轉輪看起來多寬才定得出距離
var ROLL := float(OS.get_environment("ROLL")) if OS.get_environment("ROLL") != "" else 0.6
var REV_Z := float(OS.get_environment("REV_Z")) if OS.get_environment("REV_Z") != "" else -0.13
var REV_PITCH := float(OS.get_environment("REV_PITCH")) if OS.get_environment("REV_PITCH") != "" else 0.2
var CASES := [
	# 左輪：腰射槍管要跟視線平行（test_battle.gd 檢查），只放開位置和側傾；瞄準對準星頂、轉輪左右邊
	# 左輪腰射：槍口落在準心上（照影片：槍身從右下斜伸過來，槍口頂在準心），擊錘在影片的位置；往左傾固定
	# 左輪腰射：影片 pax.mov 0.5 秒那格量的像素（槍口、轉輪左右邊、擊錘尾）；槍正立（側傾 0）
	["revolver", "hip", [[Vector3(0, 0.0475, -0.212), px(775, 475)], [Vector3(0, 0.0475, -0.212), px(775, 475)],
		[Vector3(0, 0.0475, -0.212), px(775, 475)], [Vector3(0, 0.0475, -0.212), px(775, 475)],   # 槍口重複＝加權，一定要對上
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],
		[Vector3(0, 0.0475, -30.0), Vector2.ZERO], [Vector3(0, 0.0475, -30.0), Vector2.ZERO],   # 槍管往前 30 m 落在準心：槍管對準中心（權重最高）
		[Vector3(-0.021, 0.035, -0.03), px(785, 590)], [Vector3(0.021, 0.035, -0.03), px(985, 590)],
		[Vector3(0, 0.055, 0.03), px(920, 765)]],
		[true, true, true, true, true, false], [0.07, -0.06, -0.17, 0.08, 0.0, 0.0]],
	["revolver", "ads", [[Vector3(0, 0.0655, -0.203), vid(0.405, 0.475)],
		[Vector3(-0.021, 0.035, -0.030), vid(0.30, 0.665)], [Vector3(0.021, 0.035, -0.030), vid(0.515, 0.665)]],
		[true, false, true, true, true, true]],
	["revolver", "reload", [[Vector3(0, 0.0475, -0.212), vid(0.665, 0.32)], [Vector3(0, 0.035, -0.06), vid(0.80, 0.66)],
		[Vector3(0.0205, 0.0255, -0.004), vid(0.88, 0.75)]]],
	# 長槍腰射：影片量的像素（散彈 SHOTGUNS.mov 17.5 秒、步槍 LEVER-ACTION_RIFLES.mov 7.0 秒），槍管對準準心權重最高
	["shotgun", "hip", aim(10) + [[Vector3(0, 0.046, -0.786), pxc(742, 482, 676, 416)], [Vector3(0, 0.046, -0.786), pxc(742, 482, 676, 416)],
		[Vector3(0, 0.045, 0.006), pxc(1075, 665, 676, 416)]], [true, true, true, true, true, false], [0.10, -0.11, -0.20, 0.0, 0.0, -0.22]],   # 側傾固定：影片露出機匣側面
	["shotgun", "ads", [[Vector3(0, 0.061, -0.786), gf(0.5, 0.5)],
		[Vector3(-0.0215, 0.03, 0.0), gf(0.405, 0.82)], [Vector3(0.0215, 0.03, 0.0), gf(0.595, 0.82)]]],
	["shotgun", "reload", [[Vector3(0, 0.016, -0.066), vid(0.50, 0.93)], [Vector3(0, 0.026, -0.20), vid(0.40, 0.95)],
		[Vector3(0, 0.046, -0.786), vid(-0.10, 1.25)]]],
	["rifle", "hip", aim(10) + [[Vector3(0, 0.034, -0.695), pxc(752, 462, 679, 455)], [Vector3(0, 0.034, -0.695), pxc(752, 462, 679, 455)],
		[Vector3(0, 0.05, 0.04), pxc(1270, 640, 679, 455)],
		[Vector3(-0.021, 0.0, 0.0), pxc(960, 700, 679, 455)], [Vector3(0.021, 0.0, 0.0), pxc(1230, 700, 679, 455)]],
		[true, true, true, true, true, false], [0.10, -0.07, -0.18, 0.0, 0.0, -0.23]],
	["rifle", "ads", [[Vector3(0, 0.058, -0.69), gf(0.5, 0.5)],
		[Vector3(-0.021, 0.03, 0.03), gf(0.40, 0.85)], [Vector3(0.021, 0.03, 0.03), gf(0.60, 0.85)]]],
	["rifle", "reload", [[Vector3(0, 0.034, -0.695), vid(-0.15, 0.50)], [Vector3(0, 0.012, -0.22), vid(0.18, 0.72)],
		[Vector3(0.021, 0.035, -0.03), vid(0.38, 0.80)], [Vector3(0.021, -0.035, -0.03), vid(0.42, 0.99)]]],
]


static func project(p: Vector3, fov: float) -> Vector2:
	## 鏡頭在原點看 -Z（槍掛在鏡頭底下，位置就是鏡頭座標）
	var t := tan(deg_to_rad(fov) * 0.5)
	return Vector2(p.x / -p.z, -p.y / -p.z) / (2.0 * t)


static func err(params: Array, pts: Array, fov: float, base := Vector3.ZERO) -> float:
	## base：換彈時槍本身的位置（腰射位置），params 前三個是模型再往哪偏（reload_offset）
	var basis := Basis.from_euler(Vector3(params[3], params[4], params[5]))
	var pos := base + Vector3(params[0], params[1], params[2])
	var e := 0.0
	for pr: Array in pts:
		var q: Vector3 = pos + basis * (pr[0] as Vector3)
		if q.z > -0.03:
			return 1e9   # 跑到鏡頭後面
		e += (project(q, fov) - (pr[1] as Vector2)).length_squared()
	# 轉太多不自然：小小拉回
	return e + 0.002 * (params[3] * params[3] + params[4] * params[4] + params[5] * params[5])


static func fit(pts: Array, fov: float, start: Array, base := Vector3.ZERO, free := [true, true, true, true, true, true]) -> Array:
	var p := start.duplicate()
	var steps := [0.02, 0.02, 0.02, 0.1, 0.1, 0.1]
	var best := err(p, pts, fov, base)
	for round in 400:
		var improved := false
		for i in 6:
			if not free[i]:
				continue
			for s in [-1.0, 1.0]:
				var q := p.duplicate()
				q[i] += s * steps[i]
				var e := err(q, pts, fov, base)
				if e < best:
					best = e
					p = q
					improved = true
		if not improved:
			for i in 6:
				steps[i] *= 0.5
			if steps[0] < 1e-5:
				break
	return [p, best]


func _initialize() -> void:
	## 先對腰射（FOV = HIP_FOV），換彈用對出來的腰射位置當基準；瞄準用 ADS_FOV
	var hip_fov := float(OS.get_environment("HIP_FOV")) if OS.get_environment("HIP_FOV") != "" else 70.0
	var ads_fov := float(OS.get_environment("ADS_FOV")) if OS.get_environment("ADS_FOV") != "" else 43.0
	var hip_of := {}
	for c: Array in CASES:
		var w = load("res://cowboy/weapons/%s.tscn" % c[0]).instantiate()
		var fov := ads_fov if c[1] == "ads" else hip_fov
		var start: Array
		var base := Vector3.ZERO
		match c[1]:
			"hip": start = [w.position.x, w.position.y, w.position.z, w.hip_rotation.x, w.hip_rotation.y, w.hip_rotation.z]
			"ads": start = [w.ads_position.x, w.ads_position.y, w.ads_position.z, w.ads_rotation.x, w.ads_rotation.y, w.ads_rotation.z]
			"reload":
				base = w.position   # 換彈時槍本身在腰射位置（場景裡存的），模型再偏 reload_offset
				start = [w.reload_offset.x, w.reload_offset.y, w.reload_offset.z, w.reload_rotation.x, w.reload_rotation.y, w.reload_rotation.z]
		if c.size() > 4:   # 指定起點（固定的那幾項就停在這裡）
			start = (c[4] as Array).duplicate()
		var r := fit(c[2], fov, start, base, c[3] if c.size() > 3 else [true, true, true, true, true, true])
		var p: Array = r[0]
		if c[1] == "hip":
			hip_of[c[0]] = Vector3(p[0], p[1], p[2])
		var names: Array = {"hip": ["hip_position", "hip_rotation"], "ads": ["ads_position", "ads_rotation"], "reload": ["reload_offset", "reload_rotation"]}[c[1]]
		print("%-8s %-6s FOV %2.0f 每點平均差 %.4f（畫面高）  %s=Vector3(%.3f, %.3f, %.3f);%s=Vector3(%.2f, %.2f, %.2f)" %
			[c[0], c[1], fov, sqrt(r[1] / c[2].size()), names[0], p[0], p[1], p[2], names[1], p[3], p[4], p[5]])
		w.free()
	quit()
