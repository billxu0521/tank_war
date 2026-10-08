extends SceneTree
## 從「想要在畫面上看到的樣子」反算換彈姿勢（reload_offset / reload_rotation）。
## 每把槍指定：哪個點（模型座標）要落在畫面哪裡（比例）、離鏡頭多遠、槍管往哪、哪一面朝哪。
## 用影片換彈那格量出來的位置寫，比讓優化器亂找穩定。
##   godot --headless --path . --script tools/pose_from_camera.gd
const FOV := 70.0
const ASPECT := 1280.0 / 720.0

## [槍, 模型上的點, 畫面位置 (0..1, 0..1), 離鏡頭距離, 槍管方向（鏡頭座標，槍管是模型 -Z）, 模型 +X 大致朝哪]
const POSES := [
	# 左輪：轉輪在右下、槍管往左上翹約 60 度，右側（裝填門）朝鏡頭
	# 左輪：以裝填門（LOAD_OUT 附近）定位——影片 20～24 秒門在畫面 (0.86, 0.70)；以前用轉輪前緣定，門落在右下角，塞彈的手只露出邊邊
	["revolver", Vector3(0.0108, 0.0288, 0.02), Vector2(0.84, 0.68), 0.20, Vector3(-0.40, 0.85, -0.35), Vector3(0.2, 0.1, 1.0)],
	# 散彈：折開的膛口在下方中間偏左、「折下來的槍管」往左下出畫面（槍身本身再往上翹 BREAK），頂面朝上偏鏡頭
	["shotgun", Vector3(0, 0.016, -0.066), Vector2(0.52, 0.93), 0.18, Vector3(-0.72, -0.50, -0.48), Vector3(0.3, 0.3, -1.0)],
	# 步槍：機匣在下方偏左、槍管往左上出畫面，右側（裝填口）朝上
	["rifle", Vector3(0, 0.0, -0.03), Vector2(0.46, 0.81), 0.18, Vector3(-0.85, 0.22, -0.48), Vector3(0.0, 1.0, 0.4)],
]


## 腰射（長槍）：機匣在畫面哪、多近，槍口在畫面哪 → 槍口的深度由槍長解出來；roll_up = 模型 +Y 大致朝哪（鏡頭座標）
## [槍, 機匣（模型點）, 機匣畫面位置, 機匣距離, 槍口（模型點）, 槍口畫面位置, 模型 +Y 朝哪]
const HIPS := [
	["shotgun", Vector3(0, 0.03, 0.0), Vector2(0.66, 0.88), 0.13, Vector3(0, 0.046, -0.786), Vector2(0.46, 0.48), Vector3(-0.45, 1.0, 0.0)],
	["rifle", Vector3(0, 0.02, 0.0), Vector2(0.72, 0.86), 0.11, Vector3(0, 0.034, -0.695), Vector2(0.47, 0.48), Vector3(-0.45, 1.0, 0.0)],
]


static func ray(sp: Vector2) -> Vector3:
	var t := tan(deg_to_rad(FOV) * 0.5)
	return Vector3((sp.x - 0.5) * 2.0 * t * ASPECT, -(sp.y - 0.5) * 2.0 * t, -1.0)


func _initialize() -> void:
	for h: Array in HIPS:
		var a: Vector3 = ray(h[2]) * float(h[3])
		var L: float = ((h[4] as Vector3) - (h[1] as Vector3)).length()
		var r := ray(h[5])
		var d := 0.1   # 槍口深度：讓機匣到槍口的距離 = 槍上兩點的距離
		for i in 200:
			if (r * d - a).length() < L:
				d += 0.01
		d -= 0.01
		for i in 100:
			if (r * d - a).length() < L:
				d += 0.0001
		var m := r * d
		var z := (a - m).normalized()          # 模型 +Z：從槍口往機匣
		var yv: Vector3 = h[6]
		var x := yv.cross(z).normalized()
		var y := z.cross(x).normalized()
		var b := Basis(x, y, z)
		var origin := a - b * (h[1] as Vector3)
		var e := b.get_euler()
		print("%s hip_position=Vector3(%.3f, %.3f, %.3f) hip_rotation=Vector3(%.3f, %.3f, %.3f)" % [h[0], origin.x, origin.y, origin.z, e.x, e.y, e.z])
	var t := tan(deg_to_rad(FOV) * 0.5)
	for p: Array in POSES:
		var w = load("res://cowboy/weapons/%s.tscn" % p[0]).instantiate()
		var sp: Vector2 = p[2]
		var d: float = p[3]
		var cam_pt := Vector3((sp.x - 0.5) * 2.0 * t * ASPECT * d, -(sp.y - 0.5) * 2.0 * t * d, -d)
		var z := -(p[4] as Vector3).normalized()                     # 模型 +Z = 槍管反方向
		var x := (p[5] as Vector3)
		x = (x - z * x.dot(z)).normalized()
		var y := z.cross(x).normalized()
		var b := Basis(x, y, z)
		if p[0] == "shotgun":   # 指定的是折下來的槍管方向；槍身＝槍管再轉回去（weapon.gd：barrel.rotation.x = -0.6 × 換彈姿勢）
			b = b * Basis(Vector3.RIGHT, 0.6)
		# 模型原點：讓指定的點落在 cam_pt
		var origin := cam_pt - b * (p[1] as Vector3)
		var offset: Vector3 = origin - w.position
		var e := b.get_euler()
		print("%s reload_offset=Vector3(%.3f, %.3f, %.3f) reload_rotation=Vector3(%.3f, %.3f, %.3f)" %
			[p[0], offset.x, offset.y, offset.z, e.x, e.y, e.z])
		w.free()
	quit()
