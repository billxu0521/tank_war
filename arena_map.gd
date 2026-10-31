class_name ArenaMap
extends Node3D
## 場地：地形、農舍、穀倉、柵欄、灌木、草、撤離區、靶場……（原本全在 main.gd）。掛在 main.tscn 的 Arena 節點上，main 的 _ready 叫它蓋。
## 蓋的順序不能動：Door、Destructible 的 RPC 靠 Arena/Door0…、Arena/Wreck0… 的節點名字找到它們。

@onready var main: Node = get_parent()   # 掛它的 main：讀 mode、greybox、level_path（main.gd 沒有 class_name，用實例讀）
var greybox: bool:
	get: return main.greybox
var level_path: String:
	get: return main.level_path


const ARENA := 168.0        # 場地邊長（320 → 192 → 168：越縮交火越密集）
const SPAWN_CLEARANCE := 7.0  # 出生點離建築至少這麼遠
const FENCE_H := 1.0          # 柵欄高度，要在牛仔的翻越範圍（0.4~1.5）內
const BUILDING_MAX_H := 22.0  # 最高的東西（筒倉＋圓頂約 20、穀倉屋脊約 16）不能超過這個
const GRASS := Color(0.49, 0.34, 0.21)   # 乾草原：黃昏裡偏紅的枯黃
const DIRT := Color(0.52, 0.39, 0.27)    # 沙土路，比草地亮
const PATH := Color(0.74, 0.6, 0.45)     # 荒地小路（Trails）：踩實的乾土，比草地亮一截（夕陽下要一眼看出路線）
const WHEAT := Color(0.45, 0.33, 0.18)
# 場景物件的模型（blender/props.py）。這幾個基準尺寸跟那邊共用，改一邊要改另一邊
const PROPS := preload("res://models/props.glb")
const BARN_BASE := Vector3(14, 8, 20)   # 穀倉模型的寬、牆高、長
const BARN_PITCH := 0.55
const SILO_BASE_H := 15.0
const FENCE_SEG := 2.5
const TREE_BASE_TRUNK := 5.0   # 松樹的基準樹幹高
# 闊葉樹（blender/tree.py → trees.glb）：三種大小各自建模，尺寸就是實際公尺。
# 每種 [樹幹胸口半徑, 碰撞圓柱高（到分叉點再往上一點）]，改了 tree.py 的樹幹這裡要跟著改
const TREES := preload("res://models/trees.glb")
const TREE_KINDS := {&"TreeOakS": [0.17, 1.4], &"TreeOakM": [0.41, 1.8], &"TreeOak": [0.55, 2.4],
	# 五種新樹（blender/grove.py → groves.glb）和柱狀仙人掌（blender/flora.py → floras.glb），一樣是實際公尺
	&"TreeMaple": [0.41, 3.4], &"TreePine2": [0.45, 6.0], &"TreeJoshua": [0.4, 1.9], &"TreeDead": [0.62, 3.4],
	&"TreeWillow": [0.42, 3.0], &"Saguaro": [0.46, 5.0], &"SaguaroS": [0.28, 2.6]}
const GROVES := preload("res://models/groves.glb")
const FLORAS := preload("res://models/floras.glb")
const CLUTTERS := preload("res://models/clutters.glb")   # 環境小物件（blender/clutter.py，_clutter_field 撒）
# 石頭（blender/rock.py → rocks.glb）：Rock01..16，尺寸是實際公尺、原點在底部中央。
# 01~04 大石（最大那顆 6 公尺寬，縮小一點當掩體）、05~11 單顆、12~16 石頭堆
const ROCKS := preload("res://models/rocks.glb")
const ROCK_COVER := [&"Rock01", &"Rock02", &"Rock03", &"Rock04", &"Rock05", &"Rock07", &"Rock12", &"Rock16"]
const ROCK_SCATTER := [&"Rock06", &"Rock08", &"Rock09", &"Rock10", &"Rock11", &"Rock13", &"Rock14", &"Rock15"]
# 門和梯子的位置（blender/props.py 的同名常數，改一邊要改另一邊）
const BARN_T := 0.25
const BARN_DOOR_W := 5.0
const BARN_DOOR_H := 4.8
const BARN_BACK_X := 4.0
const BARN_BACK_W := 1.6   # 後門開口，跟 blender/props.py 一樣
const BARN_BACK_H := 2.8
const BARN_LOFT := 4.0
const BARN_LADDER_X := -2.5
const HOUSE_T := 0.2
# 農舍三種（blender/house.py → houses.glb）：主屋牆都是 10 × 8，門在正面中央，整棟架高 HOUSE_FLOOR。
# 牆、屋頂、煙囪、前廊、台階斜坡的碰撞都在 House<N>Col 裡。每種 [煙囪頂（冒煙的地方）]，跟 house.py 的 CHIMNEY 一樣
const HOUSES := preload("res://models/houses.glb")
# 場景小物件（blender/kit.py → kits.glb）：木桶、木箱、方草捆、車輪、柵欄、圍欄門、繫柱架、風車、倉庫、吊燈
const KIT := preload("res://models/kits.glb")
# 城鎮店面（blender/town.py → towns.glb）：酒館、雜貨店、警長辦公室、水塔，各帶碰撞 <名字>Col。正面朝 +Z
const TOWNS := preload("res://models/towns.glb")
const WINDMILL_HUB := Vector3(0.0, 8.9, 0.9)   # 風車葉輪掛在哪（kit.py 的 WINDMILL_HUB 換成 Godot 座標）
const HAY_BLOCK := Vector3(1.1, 0.48, 0.55)    # 方草捆大小（kit.py 的 HAY_SIZE）
const HOUSE_FLOOR := 0.45
const HOUSE_KINDS := {&"House1": Vector3(5.6, 10.11, -2.0), &"House2": Vector3(-5.6, 7.09, -1.8),
	&"House3": Vector3(3.4, 10.66, -1.6)}
# 圍牆不給爬（見 dino.gd 的 _on_climbable_wall），所以恐龍能到的最高點就是
# 「站上最高的屋頂再跳一下」。圍牆要比那個高，才翻不出去。
const WALL_H := 40.0
const WALL_T := 4.0
const EXIT_RADIUS := 14.0     # 撤離區半徑
var _exit_pads: Array[Node3D] = []   # 撤離區的地面標示：沒有蛋的模式藏起來
var _props := {}   # 物件名 -> Mesh，從 props.glb 拿出來共用
var _terrain: Terrain
var _level: Array[Dictionary] = []   # 擺設清單：場地上每樣東西一筆（見 _build_level）
var spawn_points: Array[Vector3] = []   # 牛仔出生／重生候選點（擺設種類 spawn，派對模式用）；空的就用 _spawn_point()
var dino_spawn := Vector3.ZERO           # 恐龍出生點（擺設種類 dino_spawn）；沒放就是場地中央貼地
var _houses_built := 0   # 第幾棟農舍：三種輪流蓋（不用亂數，後面擺的東西位置才不會跟著變）
var _doors: Array[Door] = []   # 晚加入的人連進來時，把開著的門補送給他
var _wrecks: Array[Destructible] = []   # 拆得掉的地形（destructible.gd）：晚加入的人連進來時，把打過的補送給他
var _party_at := Vector3.INF   # 派對方塊房子的位置（灰盒才找；INF = 沒有）
var _party_house: Node3D       # 方塊房子（greybox.gd cube_house）：每台都蓋，不是派對就藏起來（set_party_house）
var _wheat_fields: Array[Rect2] = []   # 地形上色要知道哪裡是麥田
var _roads: Array[Rect2] = []          # 城鎮主街這類另外鋪的土路（地形上色）；彎彎曲曲的荒地小路在 Trails（trails.gd）
var _blocked: Array[Rect2] = []  # 建築物在 XZ 平面佔的範圍
var _drift: Node3D   # 落葉飛蟲，跟著鏡頭走（Fx.drift）
var _bushes: Array[Vector3] = []  # 灌木叢的根部位置（bot 判斷人是不是躲在裡面）
var _exits: Array[Vector3] = []  # 四個撤離區的中心
func _build_arena() -> void:
	# 擺設清單：有手調過的場景檔就照它，沒有就自動擺一份初稿（見 docs/素材流水線/場景編輯.md）
	Trails.enabled = main.mode != &"range" and not greybox   # 自動擺設、地面上色、草都會查小路，最先設
	if _level.is_empty():
		_generate_level()
	# 地形要在擺任何東西之前定案：整平區（農莊、倉庫、牧場的房子……）在清單裡。方塊房子的整平區也要先記進去
	if greybox:
		_party_house_spot()
	_terrain = make_terrain(_level.filter(func(r: Dictionary) -> bool: return r.kind == &"flat") \
		.map(func(r: Dictionary) -> Array: return [Vector2(r.pos.x, r.pos.z), r.r]))
	var ground := _terrain.build(_ground_color, _ground_mix, Greybox.ground_material() if greybox else null)
	ground.add_to_group(&"ground")   # 子彈打到噴土（Bullet.surface_of）
	ground.collision_layer |= Fighter.SOLID_LAYER   # 地形：關碰撞物件時尼諾拉還是站在上面
	add_child(ground)

	# 四周圍牆，東西才不會掉出場外。內側牆面剛好貼齊地板邊緣，不留縫。
	# 牆看不見：外面是一路延伸到地平線的遠景（far_land.gd），邊上一圈柵欄讓人看得出邊界
	var e := (ARENA + WALL_T) * 0.5
	var long := ARENA + WALL_T * 2.0
	for w: Array in [[Vector3(0, WALL_H * 0.5, e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(0, WALL_H * 0.5, -e), Vector3(long, WALL_H, WALL_T)],
			[Vector3(e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)],
			[Vector3(-e, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, long)]]:
		var wall := _solid_box(w[0], w[1])
		wall.add_to_group(&"arena_wall")
		wall.collision_layer |= Fighter.SOLID_LAYER   # 場地圍牆不算建築：關碰撞物件也擋，尼諾拉不會走出場外
	var far_color := (func(_x: float, _z: float, _h: float) -> Color: return Color(0.42, 0.44, 0.4)) if greybox else _ground_color   # 灰盒：場外跟地面一樣灰
	add_child(FarLand.build(_terrain, far_color, [_props[&"TreeOakM"], _props[&"TreeOakS"], _props[&"Bush"],
		_props[&"TreePine2"], _props[&"Saguaro"]],
		_props[&"FenceRail"], FENCE_SEG))

	_build_level()
	if _party_at.is_finite():
		_build_party_house()
	if not greybox:   # ponytail: 灰盒不撒碎物、草、野花、風滾草；只留擺設清單裡的樹、灌木、石頭當遮蔽
		_clutter_field()   # 有碰撞：伺服器也要擺，固定種子每台一樣

	# 草地：畫面用的，伺服器沒畫面就不長（測試會直接呼叫 _grass_field 檢查）
	if DisplayServer.get_name() != "headless" and not greybox:   # 灰盒也不分區調光（Ambience 的區域是照牧場劃的）
		_grass_field()
		_groundcover_field()
		_flora_field()
		_drift = Fx.drift(self)
		var amb := Ambience.new()
		add_child(amb)
		amb.setup(self)
	_lighten_small(self)
	if DisplayServer.get_name() != "headless":
		preload("res://levels/ranch_surface/surface.gd").install(self, ground)

## 減輕負擔：小東西（桶子、箱子、乾草、草叢……最長邊不到 SMALL_SIZE）不投影子、太遠就不畫。
## 影子要把場景再畫好幾遍，是最花的（docs/技術筆記/效能.md 量過：影子的繪製指令是畫面本身的兩倍多）；
## 小東西的影子在夕陽下也很短，遠處的桶子只剩幾個像素，霧又把它蓋淡了
const SMALL_SIZE := 2.0
const SMALL_FAR := 90.0   # 公尺：小東西畫到這麼遠
static func _lighten_small(root: Node) -> void:
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = g.mesh if g is MeshInstance3D else (g.multimesh.mesh if g is MultiMeshInstance3D and g.multimesh else null)
		if mesh == null or g.is_in_group(&"ground"):
			continue
		var size := mesh.get_aabb().size * g.global_basis.get_scale()
		if maxf(size.x, maxf(size.y, size.z)) >= SMALL_SIZE:
			continue
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 撒滿全場的 MultiMesh 是一整個節點，遠近照整片的中心算，設了會整片消失，只關影子
		if g is MeshInstance3D and g.visibility_range_end == 0.0:
			g.visibility_range_end = SMALL_FAR   # 直接消失不淡出：淡出那段要改用半透明畫，反而更貴；90 公尺外有霧，看不太出來

# --- 擺設清單（場景編輯工具，見 docs/規劃/2026-09-30-場景編輯工具.md） ---
# 場地上每樣東西是一筆：{kind, pos（x, 離地高度, z）, yaw, ……}。先有清單（自動擺，或從場景檔讀），再照清單蓋。
# 出生點避開建築（_blocked）、灌木藏人（_bushes）、麥田上色（_wheat_fields）這些「記下來的範圍」在加進清單時就算好（_reserve），
# 所以自動擺的時候，後面的東西看得到前面擺了什麼

## 讀場景檔：每個 LevelItem 變成擺設清單的一筆。沒有場景檔就留空，_build_arena 會自動擺一份
func _load_level() -> void:
	if level_path == "" or not ResourceLoader.exists(level_path):
		return
	var scene: Node = load(level_path).instantiate()
	add_child(scene)   # 要在場景樹裡才讀得到整體位置（群組節點可以整組搬）
	for n in scene.find_children("*", "", true, false):
		if n is LevelItem:
			_put(n.to_record())
	scene.free()

## 地形：固定種子的丘陵，靶場、撤離區固定整平，再加上清單裡的整平區（flats：[[中心, 半徑], ...]）。
## 遊戲和編輯器（LevelRoot）用同一支，編輯器裡看到的地面才跟遊戲一樣
static func make_terrain(flats: Array) -> Terrain:
	var t := Terrain.new(ARENA, 20260927)
	# 沙盒靶場和撤離區不再整平：以前的十字路一整條是平的，現在跟周圍一樣有起伏。只有清單裡的整平區（建築底下、城鎮街道）是平的
	for f: Array in flats:
		t.flatten_circle(f[0], f[1])
	t.settle()   # 靠太近的平地把高度拉近，中間才不會擠出陡坡
	return t

## 每種東西在地面上佔的長方形半寬（沿自己的 X、Z）。出生點避開（_reserve，再加各自的間隔）和擺設檢查（LevelCheck）共用
const FOOTPRINT := {&"house": Vector2(6.0, 6.5), &"silo": Vector2(3.0, 3.0), &"hay_shed": Vector2(4.0, 3.5),
	&"windmill": Vector2(1.5, 1.5), &"tree": Vector2(0.5, 0.5), &"hay_bale": Vector2(0.75, 0.75),
	&"hitch": Vector2(1.7, 0.15), &"gate": Vector2(0.15, 0.15), &"water_tower": Vector2(2.3, 2.3)}
## 店面佔地（半寬）：房子本身＋門口人行道和台階。前後一樣長（背後多留一點空地，比較好算）
const SHOP_HALF := {&"Saloon": Vector2(5.3, 9.5), &"Store": Vector2(4.8, 9.0), &"Sheriff": Vector2(4.3, 8.4)}
## 出生點要再離多遠（穀倉的在清單那一筆自己帶，大穀倉和小棚子不一樣）
const CLEARANCE := {&"house": SPAWN_CLEARANCE, &"silo": 3.0, &"hay_shed": 2.0, &"windmill": 2.0, &"tree": 1.5,
	&"hay_bale": 1.0, &"rock": 1.5, &"fence": 0.6, &"shop": SPAWN_CLEARANCE, &"water_tower": 2.0,
	&"gb_house": 3.0, &"gb_block": 1.0, &"gb_safe": 3.0}

## 這一筆在地面上佔的半寬；沒有碰撞的（灌木、碎石、只有外觀的東西）回傳 ZERO
static func footprint_half(rec: Dictionary) -> Vector2:
	match rec.kind:
		&"barn":
			return Vector2(rec.size.x, rec.size.z) * 0.5
		&"shop":
			return SHOP_HALF.get(rec.variant, Vector2(5, 9))
		&"fence":
			return Vector2(maxf(rec.length * 0.5 - 0.25, 0.0), 0.15)   # 兩端各縮一根柱子：轉角接頭、門柱貼著端點不算佔到
		&"kit":
			var k: Vector3 = KIT_SIZE.get(rec.name, Vector3.ZERO)
			return Vector2(k.x, k.z) * 0.5
		&"rock":
			if not rec.solid:
				return Vector2.ZERO
			var r: Vector3 = meshes()[rec.mesh].get_aabb().size * rec.s
			return Vector2(r.x, r.z) * 0.5
		&"gb_house", &"gb_block", &"gb_safe":
			return Vector2(rec.size.x, rec.size.z) * 0.5
	return FOOTPRINT.get(rec.kind, Vector2.ZERO)

## 加一筆到擺設清單
func _put(rec: Dictionary) -> void:
	_level.append(rec)
	_reserve(rec)

## 這一筆會佔掉哪些範圍（出生點要避開、灌木藏人、麥田上色）
func _reserve(rec: Dictionary) -> void:
	var p: Vector3 = rec.pos
	match rec.kind:
		&"wheat":
			_wheat_fields.append(Rect2(p.x - rec.size * 0.5, p.z - rec.size * 0.5, rec.size, rec.size))
			return
		&"road":
			var r := Rect2(p.x - rec.size.x * 0.5, p.z - rec.size.z * 0.5, rec.size.x, rec.size.z)
			_roads.append(r)
			_block(Vector3(r.get_center().x, 0, r.get_center().y), r.size, 0.0)   # 街上不長樹、不放石頭
			return
		&"bush":
			_bushes.append(Vector3(p.x, 0, p.z))
			return
		&"kit":
			return   # 小物件不擋出生點
		&"hay_bale":
			if not rec.get("block", false):
				return   # 麥田裡的圓捆不擋（空地補的那些才擋）
	# 佔地（照朝向轉過之後的外框）＋間隔。柵欄也佔地：後面擺的樹、石頭、草捆才不會卡在柵欄裡
	var half := footprint_half(rec)
	if half == Vector2.ZERO or not (rec.kind == &"barn" or CLEARANCE.has(rec.kind)):
		return   # 門柱、繫柱架這種細的不擋出生點
	var yaw: float = rec.get("yaw", 0.0)
	var ext := Vector2(absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y, absf(sin(yaw)) * half.x + absf(cos(yaw)) * half.y)
	_block(p, ext * 2.0, rec.clearance if rec.kind == &"barn" else CLEARANCE[rec.kind])

## 照擺設清單把東西蓋出來。順序跟清單一樣（門的名字 Door0、Door1… 照蓋的順序，每台機器要一樣）
func _build_level() -> void:
	var bushes: Array[Transform3D] = []
	dino_spawn = _on_ground(Vector3.ZERO)
	for rec: Dictionary in _level:
		var p: Vector3 = rec.pos
		match rec.kind:
			&"wheat": _wheat(rec)
			&"barn": _barn(p, rec.size)
			&"house": _house(p, rec.variant)
			&"silo": _silo(p, rec.h)
			&"fence": _fence(p, rec.length, rec.yaw)
			&"gate": _gate(p, rec.out, rec.left)
			&"windmill": _windmill(p)
			&"hay_shed": _hay_shed(p)
			&"hay_bale": _hay_bale(p, rec.yaw)
			&"kit": _kit(rec.name, p, rec.yaw)
			&"wheel": _lean_wheel(p, rec.yaw)
			&"hitch": _hitch(p)
			&"shop": _shop(p, rec.variant, rec.yaw)
			&"water_tower": _water_tower(p, rec.yaw)
			&"gb_house": _place_greybox(_destructible(Greybox.house(rec.size, rec.floors, rec.big), 2), p, rec.yaw)
			&"gb_block": _place_greybox(Greybox.block(rec.size), p, rec.yaw)
			&"gb_safe":   # 安全屋：一層的小灰盒房，門窗恐龍擠不進。拆不掉（不進 destructible）
				var safe := Greybox.house(rec.size, 1)
				safe.add_to_group(&"safe_house")
				_place_greybox(safe, p, rec.yaw)
			&"spawn": spawn_points.append(_on_ground(p))
			&"dino_spawn": dino_spawn = _on_ground(p)
			&"tree": _tree(rec)
			&"rock": _rock(rec.mesh, p, rec.s, rec.yaw, rec.solid)
			&"prop": _prop(rec.name, _on_ground(p)).rotation.y = rec.yaw
			&"bush":
				# 埋一點，斜坡下坡那側才不會懸空。灌木幾百叢，用 MultiMesh 一次畫完
				bushes.append(Transform3D(Basis(Vector3.UP, rec.yaw).scaled(rec.size), _on_ground(p) + Vector3.DOWN * 0.15))
	_scatter(&"Bush", bushes, true)

## 灰盒的房子、方塊：貼地擺好。網格合併過，一棟一次繪製
func _place_greybox(body: StaticBody3D, p: Vector3, yaw: float) -> void:
	body.position = _on_ground(p)
	body.rotation.y = yaw
	add_child(body)

## 派對模式的方塊房子（草案 4.1）：找到的位置照 greybox.gd cube_house 的順序，每塊一個 Destructible，名字接在後面（每台一樣）。
## 材質照等級對應子彈穿透（bullet.gd ARMOR）：1 木板、2 雙層木板、3 金屬板
const PARTY_ARMOR := [&"plank", &"double_plank", &"metal"]
func _build_party_house() -> void:
	_party_house = Node3D.new()
	_party_house.name = &"CubeHouse"
	add_child(_party_house)
	_party_house.position = _on_ground(_party_at)
	for cell: Array in Greybox.cube_house():
		var body := Greybox.cube()
		body.position = cell[0]
		_party_house.add_child(body)
		var w := _destructible(body, cell[1])
		w.add_to_group(PARTY_ARMOR[cell[1] - 1])
	set_party_house(false)   # 開場先藏起來，_apply_rules 看模式再開

## 派對模式才看得到、拆得掉：不是派對（或沙盒）就整棟藏起來、碰撞和拆的資格一起拿掉（main.gd 的 _enter_game、_apply_rules 呼叫）
func set_party_house(on: bool) -> void:
	if _party_house == null:
		return
	_party_house.visible = on
	for c in _party_house.get_children():   # 底下還有播完音效的 AudioStreamPlayer3D（destructible.gd 的 _sfx），要跳過
		var w := c as Destructible
		if w == null:
			continue
		var up := on and w.hits < w.hits_needed   # 已經倒的不復活碰撞（新的一場 party.gd 的 restore 會立回來）
		w.collision_layer = 1 if up else 0
		if up:
			w.add_to_group(&"destructible")
		else:
			w.remove_from_group(&"destructible")

## 方塊房子的位置：離場地中心最近、又不擋東西的一塊空地（離出生點、安全屋、撤離區都要有距離）。
## 找到就記成整平區（地形要在它之前定案），並 _block 起來：出生點、蛋的位置（_spawn_point 用 _is_clear）就避開它
func _party_house_spot() -> void:
	var best := Vector3.INF
	for x in range(-60, 61, 4):
		for z in range(-60, 61, 4):
			var p := Vector3(x, 0, z)
			if best.is_finite() and p.length() >= best.length():
				continue
			if not _is_clear(Vector2(x, z), 6.0) or not _free(p, 9.0) or not _inside(p, 12.0):
				continue
			if _level.any(func(r: Dictionary) -> bool:
					return (r.kind == &"spawn" or r.kind == &"dino_spawn") and Vector2(r.pos.x, r.pos.z).distance_to(Vector2(x, z)) < 9.0):
				continue
			best = p
	if not best.is_finite():
		return
	_party_at = best
	_put({kind = &"flat", pos = best, r = 7.0})
	_block(best, Vector2(6, 6), 3.0)

## 拆得掉的地形（destructible.gd，等級 level：1、2 挨 level 下倒，3 打不壞）：照蓋的順序取名 Wreck0、Wreck1…，每台一樣，RPC 才找得到同一個
func _destructible(body: StaticBody3D, level: int, visual: Node3D = null) -> StaticBody3D:
	body.set_script(Destructible)
	var w: Destructible = body
	w.name = "Wreck%d" % _wrecks.size()
	w.level = level
	w.hits_needed = level
	w.visual = visual
	w.add_to_group(&"destructible")
	_wrecks.append(w)
	return w

## 自動擺一份初稿：固定種子的亂數，每台機器擺出來一樣。手調過的場景檔存在時不會跑這個
func _generate_level() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	if main.mode == &"range":
		_generate_range(rng)
		return
	# 場地分四區：西北農社區、東北城鎮、西南麥田、東南森林，之間用彎曲的荒地小路（trails.gd）連起來。
	# 沙盒靶場在南北那條路的南段、撤離點在東西兩端，位置不動。農社區先蓋：_blocked[0] 要是一棟擋得住視線的穀倉（測試靠它）
	_zone_farm(rng)
	_zone_town(rng)
	_zone_wheat(rng)
	_zone_forest(rng)

	# 沿著場邊種一圈樹
	var edge := ARENA * 0.5 - 6.0
	for i in 40:
		var t := float(i) / 40.0 * 4.0
		var side := int(t)
		var u := (t - side) * ARENA - ARENA * 0.5
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u),
			Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		if _free(p, 2) and _is_clear(Vector2(p.x, p.z)) and _inside(p, 2.5) and not ZONE_TOWN.has_point(Vector2(p.x, p.z)) \
				and Trails.edge(p.x, p.z) > 2.0:   # 四個角會跑出場外；主路從東西兩邊出場
			_gen_tree(p, rng, 0.4)

	# 空地補東西：塊跟塊之間本來是一大片空草地，補上樹和乾草捲，走到哪都有東西可以躲。
	# 樹照植被密度（Terrain.vegetation）長：濕地一叢一叢成林、旱地零星；乾草捲不挑地方
	var inner := ARENA * 0.5
	for i in 260:   # 次數照「掩體總量跟改之前差不多」調的
		var p := Vector3(rng.randf_range(-inner + 12, inner - 12), 0, rng.randf_range(-inner + 12, inner - 12))
		if Trails.edge(p.x, p.z) < 3.0 or not _free(p, 6) or not _is_clear(Vector2(p.x, p.z)) \
				or _in_wheat(p) or ZONE_TOWN.has_point(Vector2(p.x, p.z)):
			continue
		var roll := rng.randf()
		if roll < Terrain.vegetation(p.x, p.z) * 0.8:
			_gen_tree(p, rng, 0.3)
		elif roll > 0.8:
			var bale := {kind = &"hay_bale", pos = p, yaw = rng.randf() * PI, block = true}
			if not _overlaps_placed(bale):   # 柵欄不在 _blocked 裡（太細），用擺設檢查的佔地來比
				_put(bale)

	# 灌木叢：兩三叢一群，蹲進去就看不到人。只擋視線不擋子彈，也沒碰撞（跟 Hunt 一樣）。
	# 用自己的亂數，灌木多一叢少一叢不會影響其他東西的位置
	var br := RandomNumberGenerator.new()
	br.seed = 13
	for i in 300:   # 城鎮和麥田不長，其他地方要補多一點
		var c := Vector3(br.randf_range(-inner + 8, inner - 8), 0, br.randf_range(-inner + 8, inner - 8))
		if br.randf() > Terrain.vegetation(c.x, c.z) * 1.6:   # 濕地多、旱地少（不是沒有：旱地也要有地方躲）
			continue
		for k in br.randi_range(2, 4):
			var p := c + Vector3(br.randf_range(-2.5, 2.5), 0, br.randf_range(-2.5, 2.5))
			if Trails.edge(p.x, p.z) < 2.0 or not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)) \
					or _in_wheat(p) or ZONE_TOWN.has_point(Vector2(p.x, p.z)):
				continue
			var s := br.randf_range(0.75, 1.3)
			var yaw := br.randf() * TAU
			_put({kind = &"bush", pos = p, yaw = yaw, size = Vector3(s, s * br.randf_range(0.85, 1.15), s)})
	_gen_rocks(inner)

	# 撤離點旁邊停一台篷車：遠遠就認得出「從這裡走」；旁邊是卸下來的貨
	for ex: Vector2 in exit_spots():
		_put({kind = &"prop", name = &"Wagon", pos = Vector3(ex.x, 0, ex.y + EXIT_RADIUS + 3.0), yaw = 0.4})
		_gen_clutter(Vector3(ex.x + 3.5, 0, ex.y + EXIT_RADIUS + 1.2), 0.4)

## rec 的佔地跟已經擺好的東西重不重疊（跟擺設檢查 LevelCheck 同一套算法）
func _overlaps_placed(rec: Dictionary) -> bool:
	var fp := LevelCheck.footprint(rec)
	return not fp.is_empty() and _level.any(func(o: Dictionary) -> bool:
		var f := LevelCheck.footprint(o)
		return not f.is_empty() and LevelCheck.overlap(fp, f))

## 離場邊至少 margin 公尺（場邊有看不見的牆）
func _inside(p: Vector3, margin: float) -> bool:
	return absf(p.x) < ARENA * 0.5 - margin and absf(p.z) < ARENA * 0.5 - margin

## 一棵樹：亂數決定種類（松樹、闊葉樹大中小）、大小、朝向
func _gen_tree(p: Vector3, rng: RandomNumberGenerator, pine_chance := 0.0) -> void:
	var h := rng.randf_range(4.0, 6.0)
	var rec := {kind = &"tree", pos = p}
	if rng.randf() < pine_chance:
		rec.mesh = &"TreePine"
		rec.s = h / TREE_BASE_TRUNK
	else:
		# 闊葉樹：同一個亂數 h 決定大中小（小 25%、中 40%、大 35%）和 ±10% 的縮放
		var t := (h - 4.0) / 2.0
		rec.mesh = &"TreeOakS" if t < 0.25 else (&"TreeOakM" if t < 0.65 else &"TreeOak")
		rec.s = 0.9 + 0.2 * fmod(t * 7.0, 1.0)
	rec.yaw = rng.randf() * TAU   # 每棵轉個角度，一整排才不會長得一模一樣
	_put(rec)

## 穀倉＋門口外面的東西：一邊一堆雜物、另一邊牆上靠一個車輪（放在滑門拉開的範圍外），側牆邊疊草捆
func _gen_barn(p: Vector3, size: Vector3, clearance := SPAWN_CLEARANCE) -> void:
	_put({kind = &"barn", pos = p, size = size, clearance = clearance})
	var s := size / BARN_BASE
	_gen_clutter(p + Vector3(-(BARN_DOOR_W * s.x + 1.9), 0, size.z * 0.5 + 1.3), 0.0)
	_put({kind = &"wheel", pos = p + Vector3(BARN_DOOR_W * s.x + 0.9, 0, size.z * 0.5), yaw = 0.0})
	_gen_hay_stack(p + Vector3(-(size.x * 0.5 + 0.8), 0, size.z * 0.15), PI * 0.5)

## 農舍（三種輪流：不用亂數，後面擺的東西位置才不會跟著變）＋門前的繫柱架、左側牆邊一排木桶木箱
func _gen_house(p: Vector3, variant: StringName = &"") -> void:
	if variant == &"":
		variant = HOUSE_KINDS.keys()[_houses_built % HOUSE_KINDS.size()]
		_houses_built += 1
	_put({kind = &"house", pos = p, variant = variant})
	_put({kind = &"hitch", pos = p + Vector3(-4.5, 0, 10.5)})   # 台階旁邊，不擋路
	_gen_clutter(p + Vector3(-6.9, 0, 1.4), PI * 0.5)

## 一小堆雜物（木桶、木箱、方草捆）排成一列：蹲得進去的矮掩體，擋子彈。
## 用自己的亂數（照位置算）：多擺少擺不影響其他東西的位置
func _gen_clutter(p: Vector3, yaw: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(p.x * 131.0 + p.z * 17.0)
	var along := Basis(Vector3.UP, yaw)
	var kinds: Array[StringName] = [&"Barrel", &"Crate", &"HayBlock"]
	var n := r.randi_range(2, 4)
	for i in n:
		var k := kinds[r.randi() % kinds.size()]
		var off := along * Vector3((i - (n - 1) * 0.5) * 1.25, 0, r.randf_range(-0.3, 0.3))
		_put({kind = &"kit", name = k, pos = p + off, yaw = yaw + r.randf_range(-0.3, 0.3)})

## 疊起來的方草捆：底下兩捆、上面一捆（pos.y 是離地高度）
func _gen_hay_stack(p: Vector3, yaw: float) -> void:
	var along := Basis(Vector3.UP, yaw)
	for off: Vector3 in [Vector3(-0.56, 0, 0), Vector3(0.56, 0, 0), Vector3(0, HAY_BLOCK.y, 0)]:
		_put({kind = &"kit", name = &"HayBlock", pos = p + along * Vector3(off.x, 0, 0) + Vector3(0, off.y, 0), yaw = yaw})

## 描線：一片蓋滿畫面的方塊，用 outline.gdshader 從深度和法線畫出輪廓和稜線。
## 放在場地底下，任何相機（玩家、檢視模式、截圖）都會畫到；剔除邊界拉很大，不會因為方塊不在視野裡被跳過
func _use_outline() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://outline.gdshader")
	mat.render_priority = Material.RENDER_PRIORITY_MIN   # 比火光、煙先畫：它們蓋在線上，不會被框一圈黑邊
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = &"Outline"   # tools/style_shots.gd 用名字找它調油畫感
	mi.mesh = quad
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## 天空換成 sky.gdshader（有雲、有太陽盤）。霧只蓋一點點天空，不然雲全被霧洗掉
func _use_sky() -> void:
	var env: Environment = $WorldEnvironment.environment
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://sky.gdshader")
	env.sky.sky_material = mat
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64   # 環境光只要大概的顏色
	env.fog_sky_affect = 0.0   # 霧的灰紫色會混進地平線的橘

## 石頭：空地上零星的大石當掩體（有碰撞、擋子彈），山崖腳下堆一圈碎石和石頭堆（把牆腳藏起來）。
## 用自己的亂數，多一顆少一顆不會影響其他東西的位置
func _gen_rocks(inner: float) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = 21
	for i in 120:   # 空地：大石和石頭堆，當掩體。旱地多（植被密度低的地方），樹林裡少
		var p := Vector3(rr.randf_range(-inner + 12, inner - 12), 0, rr.randf_range(-inner + 12, inner - 12))
		if rr.randf() < Terrain.vegetation(p.x, p.z) * 0.8:
			continue
		var kind: StringName = ROCK_COVER[rr.randi() % ROCK_COVER.size()]
		var s := rr.randf_range(0.45, 0.7) if kind in [&"Rock01", &"Rock02", &"Rock03", &"Rock04"] else rr.randf_range(0.8, 1.2)
		var yaw := rr.randf() * TAU
		var half: float = _props.get(kind).get_aabb().size.x * s * 0.5
		if Trails.edge(p.x, p.z) < 3.0 or not _free(p, 5) or not _is_clear(Vector2(p.x, p.z), half) or _in_wheat(p) \
				or ZONE_TOWN.has_point(Vector2(p.x, p.z)) \
				or _near_bush(p, half + 2.0):
			continue
		_put({kind = &"rock", mesh = kind, pos = p, s = s, yaw = yaw, solid = true})
	var edge := inner - 4.0
	for i in 70:   # 山崖腳下：碎石、小石頭堆，只是外觀
		var t := rr.randf() * 4.0
		var side := int(t)
		var u := (t - side) * inner * 2.0 - inner
		var p: Vector3 = [Vector3(u, 0, -edge), Vector3(edge, 0, u), Vector3(-u, 0, edge), Vector3(-edge, 0, -u)][side]
		p += Vector3(rr.randf_range(-2.5, 2.5), 0, rr.randf_range(-2.5, 2.5))
		var kind: StringName = ROCK_SCATTER[rr.randi() % ROCK_SCATTER.size()]
		var s := rr.randf_range(0.9, 1.6)
		var yaw := rr.randf() * TAU
		if Trails.edge(p.x, p.z) < 1.0 or not _free(p, 3) or not _is_clear(Vector2(p.x, p.z)) or not _inside(p, 2.0):
			continue
		_put({kind = &"rock", mesh = kind, pos = p, s = s, yaw = yaw, solid = false})

## 灌木先撒，石頭後放：石頭不能壓在灌木上（灌木會被圈進石頭的保留區）
func _near_bush(p: Vector3, r: float) -> bool:
	for b: Vector3 in _bushes:
		if Vector2(p.x, p.z).distance_to(Vector2(b.x, b.z)) < r:
			return true
	return false

## 一顆石頭：往下埋一點（斜坡上才不會懸空）。solid 的用模型的凸包當碰撞，擋人也擋子彈
func _rock(kind: StringName, p: Vector3, s: float, yaw: float, solid: bool) -> void:
	var at := _on_ground(p) + Vector3.DOWN * 0.15 * s
	var mesh: Mesh = _props.get(kind)
	if solid:
		var hull := mesh.create_convex_shape() as ConvexPolygonShape3D
		var pts := PackedVector3Array()
		for v in hull.points:
			pts.append(v * s)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var body := _body(at, shape)
		body.add_to_group(&"stone")   # 子彈打到噴石屑
		body.rotation.y = yaw
		_prop(kind, Vector3.ZERO, Vector3.ONE * s, body)
	else:
		var mi := _prop(kind, at, Vector3.ONE * s)
		mi.rotation.y = yaw

## 蹲在灌木叢裡（離某叢中心 1.2 公尺內）：灌木 1.5 公尺高，站著頭會露出來，蹲下才藏得住
func hidden_in_bush(who: Node3D) -> bool:
	if who.get(&"sync_crouching") != true:
		return false
	var at := Vector2(who.global_position.x, who.global_position.z)
	for b: Vector3 in _bushes:
		if at.distance_to(Vector2(b.x, b.z)) < 1.2:
			return true
	return false

func _in_wheat(p: Vector3) -> bool:
	for f: Rect2 in _wheat_fields:
		if f.grow(2.0).has_point(Vector2(p.x, p.z)):
			return true
	return false

## 荒野的矮植物（blender/flora.py）：草叢、灌木、小仙人掌。只有外觀、沒碰撞也不藏人（都不到一公尺半），
## 伺服器不長。城鎮區是荒漠長得最多、也只有那裡有球形仙人掌和仙人掌片；其他地方零星幾叢。路上、建築旁、麥田、靶場、撤離區不長。
## 用自己的亂數，每台機器長得一樣。名字: [城鎮區幾叢, 其他地方幾叢]
## 城鎮區以外照植被密度（Terrain.vegetation）挑地方：高草長在濕地（樹林旁），矮灌木、仙人掌長在旱地
const FLORA_WET := [&"GrassTall", &"GrassDense", &"GrassSmall"]
const FLORA_MIX := {&"GrassTall": [70, 110], &"GrassDense": [60, 90], &"GrassSmall": [90, 150], &"ScrubBush": [60, 40],
	&"DesertBush": [15, 30], &"BarrelCactus": [18, 0], &"PricklyPear": [14, 0]}
func _flora_field() -> void:
	var fr := RandomNumberGenerator.new()
	fr.seed = 29
	var half := ARENA * 0.5 - 3.0
	for name: StringName in FLORA_MIX:
		var pts: Array[Transform3D] = []
		for zone in 2:
			var want: int = FLORA_MIX[name][zone]
			var placed := 0
			for i in want * 8:   # 試到種滿為止，擋到的位置跳過
				if placed == want:
					break
				var p := Vector2(fr.randf_range(ZONE_TOWN.position.x, ZONE_TOWN.end.x), fr.randf_range(ZONE_TOWN.position.y, ZONE_TOWN.end.y)) \
					if zone == 0 else Vector2(fr.randf_range(-half, half), fr.randf_range(-half, half))
				var yaw := fr.randf() * TAU
				var s := fr.randf_range(0.8, 1.2)
				var v := Terrain.vegetation(p.x, p.y)
				if zone == 1 and fr.randf() > (v if name in FLORA_WET else 1.0 - v):
					continue
				if Trails.edge(p.x, p.y) < 1.0 or (zone == 1 and ZONE_TOWN.has_point(p)) or not _is_clear(p, 0.5) \
						or _in_wheat(Vector3(p.x, 0, p.y)) or not _free(Vector3(p.x, 0, p.y), 1.0) \
						or _roads.any(func(r: Rect2) -> bool: return r.has_point(p)):
					continue
				pts.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), _on_ground(Vector3(p.x, 0, p.y)) + Vector3.DOWN * 0.05))
				placed += 1
		_scatter(name, pts, name in [&"BarrelCactus", &"PricklyPear", &"DesertBush"])

## 環境小物件（blender/clutter.py；清單和參考圖是 GPT 建議的，docs/image/clutter/）。
## 照雜訊撒：每種一張自己的低頻雜訊（不同種子），雜訊高的地方才放，同種東西會聚成幾群、群和群之間是空地，
## 不是均勻灑胡椒；同種之間再隔 spacing 公尺。where 決定候選點從哪來（要有故事：飲水槽靠柵欄、柴堆靠房子、礦車靠石頭）：
##   fence 柵欄外側 1 公尺、順著柵欄｜house 房子、店旁邊 2～4 公尺｜rock 大石頭旁邊｜trail 小路邊 1.5～3 公尺
##   desert 荒地（植被稀、離房子 20 公尺以上）｜settle 農莊、城鎮裡
## [名字, 數量, 碰撞大小（Godot 的 x 寬、y 高、z 深）, 同種間距, 雜訊門檻, where]
const CLUTTER := [
	[&"WaterTrough", 6, Vector3(2.0, 0.5, 0.7), 12.0, 0.0, &"fence"],
	[&"Outhouse", 3, Vector3(1.2, 2.2, 1.2), 25.0, 0.0, &"house"],
	[&"LogPile", 6, Vector3(2.0, 1.0, 1.6), 10.0, 0.0, &"house"],
	[&"SignPost", 6, Vector3(0.2, 2.5, 0.2), 18.0, -0.2, &"trail"],
	[&"CollapsedShed", 2, Vector3(3.2, 1.6, 2.3), 45.0, 0.0, &"desert"],
	[&"DinoSkull", 3, Vector3(3.0, 1.2, 1.6), 18.0, -0.2, &"desert"],   # 荒野只有區域之間那幾條帶子，間距大了放不滿
	[&"MineCart", 1, Vector3(1.2, 0.9, 0.75), 30.0, -1.0, &"rock"],   # 區域外夠大的石頭只有一兩顆
]
const BUILDING_KINDS := [&"barn", &"house", &"shop", &"silo", &"hay_shed", &"water_tower", &"windmill"]

## 一個候選點 [位置, 朝向]；沒找到回傳空陣列
func _clutter_candidate(where: StringName, cr: RandomNumberGenerator, half: float) -> Array:
	var anchors: Array = []
	match where:
		&"fence": anchors = _level.filter(func(r: Dictionary) -> bool: return r.kind == &"fence")
		&"house": anchors = _level.filter(func(r: Dictionary) -> bool: return r.kind in BUILDING_KINDS)
		&"rock": anchors = _level.filter(func(r: Dictionary) -> bool: return r.kind == &"rock" and r.solid and _big_rock(r) \
				and not _in_zones(Vector2(r.pos.x, r.pos.z)) and _building_gap(Vector2(r.pos.x, r.pos.z)) >= 15.0)   # 礦場在荒野的大石頭旁（直立的小圓石像墓碑）；沒有就不放，不要放進人家院子
	if where in [&"fence", &"house", &"rock"]:
		if anchors.is_empty():
			return []
		var rec: Dictionary = anchors[cr.randi() % anchors.size()]
		var c := Vector2(rec.pos.x, rec.pos.z)
		match where:
			&"fence":   # 柵欄上隨便一點，往外推 1 公尺，槽順著柵欄
				var yaw: float = rec.yaw
				var d := Vector2(cos(yaw), -sin(yaw))
				var n := Vector2(-d.y, d.x) * (1.0 if cr.randf() < 0.5 else -1.0)
				return [c + d * cr.randf_range(-0.4, 0.4) * rec.length + n * 1.4, yaw, rec]
			&"house":   # 房子外緣再出去 2～4 公尺，背靠房子
				var h := footprint_half(rec)
				var a := cr.randf() * TAU
				var dir := Vector2(cos(a), sin(a))
				var p := c + dir * (maxf(h.x, h.y) + cr.randf_range(3.0, 5.0))   # 屋簷比牆身寬，2 公尺時廁所的屋頂插進牆
				return [p, atan2(dir.x, dir.y), rec]
			&"rock":
				var r: float = (meshes()[rec.mesh].get_aabb().size * rec.s).length() * 0.35
				var a := cr.randf() * TAU
				return [c + Vector2(cos(a), sin(a)) * (r + 2.5), a, rec]
	var p := Vector2(cr.randf_range(-half, half), cr.randf_range(-half, half))
	var veg := Terrain.vegetation(p.x, p.y)
	match where:
		&"trail":
			var e := Trails.edge(p.x, p.y)
			if e < 1.5 or e > 3.0:
				return []
			return [p, cr.randi_range(0, 3) * PI * 0.5]
		&"desert":
			if veg > 0.3 or not _wild(p):
				return []
			return [p, cr.randf() * TAU]
	return [p, cr.randf() * TAU]

## 荒野：四個區域（農莊、城鎮、麥田、森林）以外，離房子 20 公尺、離樹 6 公尺以上（頭骨、廢屋、礦車不在林邊住家旁）
func _in_zones(p: Vector2) -> bool:   # 區域外擴 2 公尺（再大的話區域之間的空地就沒了；離房子遠近另外用 _building_gap 管）
	for z: Rect2 in [ZONE_TOWN, ZONE_FARM, ZONE_WHEAT, ZONE_FOREST]:
		if z.grow(2.0).has_point(p):
			return true
	return false

## 離最近的建築外緣多遠（中心距離扣掉建築的半寬：大穀倉 20 公尺寬，只量中心會放進院子裡）
func _building_gap(p: Vector2) -> float:
	var best := INF
	for rec: Dictionary in _level:
		if rec.kind in BUILDING_KINDS:
			var h := footprint_half(rec)
			best = minf(best, Vector2(rec.pos.x, rec.pos.z).distance_to(p) - maxf(h.x, h.y))
	return best

func _wild(p: Vector2) -> bool:
	if _in_zones(p):
		return false
	for rec: Dictionary in _level:
		var d := Vector2(rec.pos.x, rec.pos.z).distance_to(p)
		if rec.kind == &"tree" and d < 6.0:
			return false
	return _building_gap(p) >= 15.0

## 大石頭：至少 1.5 公尺高、寬比高大
func _big_rock(rec: Dictionary) -> bool:
	var sz: Vector3 = meshes()[rec.mesh].get_aabb().size * rec.s
	return sz.y >= 1.5 and maxf(sz.x, sz.z) > sz.y

## 離柵欄多近（點到每段柵欄線段的最短距離）
func _fence_dist(p: Vector2) -> float:
	var best := INF
	for rec: Dictionary in _level:
		if rec.kind != &"fence":
			continue
		var d: Vector2 = Vector2(cos(rec.yaw), -sin(rec.yaw)) * float(rec.length) * 0.5
		var a: Vector2 = Vector2(rec.pos.x, rec.pos.z) - d
		var ab: Vector2 = d * 2.0
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

## 離場上已經擺的東西（石頭、樹、房子、箱子……）太近：石頭、樹不一定在 _blocked 裡，戶外廁所會插進大石頭（第一輪截圖）
func _near_level(p: Vector2, r: float, skip: Variant = null) -> bool:
	for rec: Dictionary in _level:
		if rec.kind in [&"fence", &"road", &"wheat"] or is_same(rec, skip):
			continue
		var h := footprint_half(rec)
		var reach := maxf(maxf(h.x, h.y), 1.5 if rec.kind == &"tree" else 0.5)
		if Vector2(rec.pos.x, rec.pos.z).distance_to(p) < r + reach:
			return true
	return false

## 記下擺好的位置（測試、截圖工具用）
var clutter_spots: Array = []

func _clutter_field() -> void:
	var cr := RandomNumberGenerator.new()
	cr.seed = 1009
	var half := ARENA * 0.5 - 4.0
	for k in CLUTTER.size():
		var row: Array = CLUTTER[k]
		var noise := FastNoiseLite.new()
		noise.seed = 700 + k
		noise.frequency = 0.035   # 一群約 15～30 公尺
		var size: Vector3 = row[2]
		var placed: Array[Vector2] = []
		var why := {}   # 為什麼放不下（除錯：CLUTTER_DEBUG=1 印出來）
		for i in 4000:
			if placed.size() >= row[1]:
				break
			var cand := _clutter_candidate(row[5], cr, half)
			if cand.is_empty():
				continue
			var p: Vector2 = cand[0]
			var anchor: Variant = cand[2] if cand.size() > 2 else null
			# 靠著東西擺的（飲水槽靠柵欄、柴堆靠房子、礦車靠石頭）只用窄邊的半寬檢查、不算自己靠的那個，不然永遠擠不進去
			var r := minf(size.x, size.z) * 0.5 if anchor != null else maxf(size.x, size.z) * 0.5
			if absf(p.x) > half or absf(p.y) > half or noise.get_noise_2d(p.x, p.y) < row[4]:
				continue
			var fail := ""
			if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < row[3]): fail = "spacing"
			elif clutter_spots.any(func(c: Array) -> bool: return Vector2(c[1].x, c[1].z).distance_to(p) < 8.0): fail = "other"
			elif load("res://main.gd").SANDBOX_RANGE.grow(2.0).has_point(p): fail = "sandbox"
			elif _near_level(p, r + 0.5, anchor): fail = "level"
			elif anchor == null and not _is_clear(p, r + 0.5): fail = "blocked"
			elif row[5] != &"fence" and _fence_dist(p) < maxf(size.x, size.z) * 0.5 + 1.0: fail = "fence"   # 柴堆貼著柵欄會穿模
			elif not _free(Vector3(p.x, 0, p.y), r + 0.5): fail = "reserved"
			elif _in_wheat(Vector3(p.x, 0, p.y)): fail = "wheat"
			elif Trails.edge(p.x, p.y) < 1.0 or _roads.any(func(q: Rect2) -> bool: return q.grow(r).has_point(p)): fail = "road"
			if fail != "":
				why[fail] = why.get(fail, 0) + 1
				continue
			var at := _on_ground(Vector3(p.x, 0, p.y)) + Vector3.DOWN * 0.08   # 埋一點：坡地下坡那側才不會浮起來
			var body := _solid_box(at + Vector3(0, size.y * 0.5, 0), size)
			body.rotation.y = cand[1]
			_prop(row[0], Vector3(0, -size.y * 0.5, 0), Vector3.ONE, body)
			# 草、灌木、出生點避開（範圍是正的長方形，不跟著轉：取最長邊的正方形）。礦車連 4 公尺鐵軌，不然草蓋住鐵軌
			var foot := 4.3 if row[0] == &"MineCart" else maxf(size.x, size.z) * 1.2
			_block(Vector3(p.x, 0, p.y), Vector2(foot, foot), 0.5)
			placed.append(p)
			clutter_spots.append([row[0], at, cand[1]])
		if OS.get_environment("CLUTTER_DEBUG") != "":
			print("clutter ", row[0], " ", placed.size(), "/", row[1], " ", why)

const GRASS_CHUNK := 16.0
const GRASS_SIZE := 1.2     # 整片草的大小倍數（2026-10-06 使用者：草放大兩成）
const GRASS_PER_M2 := 6.0   # 效能旋鈕：電腦跑不動就調低（3 看得出一叢一叢的空隙）
const GRASS_SHADER := preload("res://grass.gdshader")

## 草地：16 公尺一塊的 MultiMesh，每塊自己剔除、45 公尺外不畫。
## 顏色取地形頂點的顏色（麥田裡自動變黃），根部暗、尖端亮，風一波一波吹過去，腳邊的草會被撥開。
## 路上、建築周圍不長。用自己的亂數，每台機器長得一樣。
## spots 給一個陣列就把每叢的位置也放進去（測試用：沒畫面的伺服器讀不回 MultiMesh 裡的位置）
func _grass_field(spots: Variant = null) -> void:
	var mesh := _grass_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	var gr := RandomNumberGenerator.new()
	gr.seed = 7
	var per := int(GRASS_CHUNK * GRASS_CHUNK * GRASS_PER_M2)
	var cells := int(ARENA / GRASS_CHUNK)
	var half := GRASS_CHUNK * 0.5
	for cx in cells:
		for cz in cells:
			var o := Vector3((cx + 0.5) * GRASS_CHUNK - ARENA * 0.5, 0, (cz + 0.5) * GRASS_CHUNK - ARENA * 0.5)
			# 先挑出碰到這塊的建築：每叢都掃全場的建築會慢到讀圖卡好幾秒
			var area := Rect2(o.x - half, o.z - half, GRASS_CHUNK, GRASS_CHUNK)
			var near: Array[Rect2] = []
			for r: Rect2 in _blocked + _roads:   # 鋪的路（城鎮主街、靶場的靶道）上也不長
				if r.intersects(area):
					near.append(r)
			var xf: Array[Transform3D] = []
			var cols: Array[Color] = []
			for i in per:
				var x := o.x + gr.randf_range(-half, half)
				var z := o.z + gr.randf_range(-half, half)
				var a := gr.randf() * TAU
				var s := gr.randf_range(0.7, 1.3) * GRASS_SIZE
				if Trails.edge(x, z) < 0.3:   # 路邊一點點草探進路面，比切齊的邊自然
					continue
				# 植被密度：濕地長滿，旱地剩三成——一片一片的草地和裸土，不是整片均勻的地毯
				if gr.randf() > lerpf(0.3, 1.0, Terrain.vegetation(x, z)):
					continue
				var inside := false
				for r in near:
					if r.has_point(Vector2(x, z)):
						inside = true
						break
				if inside:
					continue
				xf.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * s),
					Vector3(x - o.x, _terrain.fast_height(x, z) - 0.03, z - o.z)))   # 相對塊中心
				cols.append(_terrain.fast_color(x, z))
				if spots != null:
					spots.append(Vector2(x, z))
			if xf.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true            # 一定要在 instance_count 之前設
			mm.mesh = mesh
			mm.instance_count = xf.size()
			# ponytail: 一叢一叢設，全場約 30 萬次。讀圖太慢再改成一次填 mm.buffer
			#（但沒畫面的伺服器不會存 buffer，測試會讀不到位置）
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
				mm.set_instance_color(i, cols[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Grass"
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.position = Vector3(o.x, 0, o.z)   # 節點放在塊中心，可見距離才算得對
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 45.0
			mmi.extra_cull_margin = 1.0   # 風吹會把葉子推出 AABB
			mmi.add_to_group(&"grass")
			add_child(mmi)

## 地被三種（GPT 建議，docs/image/ground/gpt_suggestions.json、ref_*.png）：荒地乾穗草（原本是野花，太繽紛換掉）、鼠尾草叢、匍匐藤。
## 都是小網格（頂點色上色），16 公尺一塊的 MultiMesh、34 公尺外不畫、不投影子；groundcover.gdshader。
## 哪裡長照雜訊和地面材質（_ground_mix）：一片一片的，不是到處都有
const GROUNDCOVER_SHADER := preload("res://groundcover.gdshader")
## 荒地植物的穗頭顏色：乾草、鏽紅、灰褐、暗赭（2026-10-09 使用者：野花太繽紛，跟遊戲調性不合，改成荒地植物）
const FLOWER_COLORS := [Color("a08a5a"), Color("8a5a3a"), Color("857262"), Color("9a7a40")]

## 一個小方塊（地被的葉子、花頭用）：c 是頂點色，透明度 1 = 用每叢自己的顏色
static func _gc_box(st: SurfaceTool, at: Vector3, size: Vector3, c: Color, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var h := size * 0.5
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.BACK, Vector3.UP, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], [Vector3.LEFT, Vector3.UP, Vector3.BACK], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var cen := n * h
		var du := u * h
		var dv := v * h
		var q := [cen - du - dv, cen + du - dv, cen + du + dv, cen - du + dv]
		var lin := Color(c.srgb_to_linear(), c.a)   # 上面寫的是 sRGB 顏色；shader 直接當 ALBEDO（線性）用，不換的話全部偏白
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lin)
			st.set_normal(b * n)
			st.add_vertex(at + b * (q[i] as Vector3))

## 一片平的葉子（只有朝上那面，兩個三角形）：貼地的藤用方塊的話一叢上千個三角形，全場幾十萬（審查：幀數掉）
static func _gc_leaf(st: SurfaceTool, at: Vector3, size: Vector2, c: Color, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var q := [Vector3(-size.x, 0, -size.y), Vector3(size.x, 0, -size.y), Vector3(size.x, 0, size.y), Vector3(-size.x, 0, size.y)]
	var lin := Color(c.srgb_to_linear(), c.a)
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(lin)
		st.set_normal(Vector3.UP)
		st.add_vertex(at + b * ((q[i] as Vector3) * 0.5))

static func _groundcover_mesh(kind: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 40 + kind
	match kind:
		0:   # 荒地乾穗草（原本是野花）：一叢細莖斜著散開，頂上一節細長的乾穗（穗色每叢不同，都是乾草、鏽紅那類暗色）
			for k in 7:
				var a := r.randf() * TAU
				var tilt := r.randf_range(0.05, 0.4)
				var h := r.randf_range(0.22, 0.42)
				var dir := Vector3(sin(tilt) * cos(a), cos(tilt), sin(tilt) * sin(a))
				for j in 3:   # 莖：三小段
					_gc_box(st, dir * h * (j + 0.5) / 3.0, Vector3(0.01, h / 3.0 + 0.01, 0.01), Color(0.42, 0.36, 0.22, 0.0), a)
				# 乾穗：細（1.8 公分）、上面一節收尖；一半往外彎下去（每根都挺直的話像香蒲，審查）
				var tip := dir
				if k % 2 == 0:
					tip = (dir + Vector3(cos(a), -0.6, sin(a)) * 0.8).normalized()
				var base := dir * h
				_gc_box(st, base + tip * 0.035, Vector3(0.018, 0.07, 0.018), Color(1, 1, 1, 1.0), a)
				_gc_box(st, base + tip * 0.085, Vector3(0.009, 0.035, 0.009), Color(1, 1, 1, 1.0), a)
		1:   # 鼠尾草叢（照參考圖）：一團蓬鬆的圓球，很多 5 公分的灰綠小方塊（#8A9A82 上下），底下幾根短細枝，寬約高的 1.2 倍。
			# 上一版枝頭放大扁方塊，像蘑菇、灰色小傘（審查）
			for k in 4:
				var a := k * TAU / 4.0 + r.randf_range(-0.3, 0.3)
				_gc_box(st, Vector3(cos(a) * 0.05, 0.08, sin(a) * 0.05), Vector3(0.012, 0.16, 0.012), Color(0.3, 0.22, 0.15, 0.0), a)
			for k in 36:
				var d := Vector3(r.randf_range(-1, 1), r.randf_range(-0.2, 1), r.randf_range(-1, 1)).normalized() * sqrt(r.randf())
				var sz := r.randf_range(0.04, 0.06)
				_gc_box(st, Vector3(d.x * 0.24, 0.2 + d.y * 0.16, d.z * 0.24), Vector3(sz, sz, sz),
					Color(Color("7f9070"), 0.0).lerp(Color(Color("6c8260"), 0.0), r.randf()), r.randf() * TAU)   # 透明度 0：不是花頭（1 會被換成花色）
		2:   # 匍匐藤（照參考圖）：貼地一整片連起來的深綠葉（平的四邊形，只有上面），紅果只點綴兩顆
			for k in 40:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.45
				_gc_leaf(st, Vector3(cos(a) * d, r.randf_range(0.01, 0.06), sin(a) * d), Vector2(0.12, 0.09),
					Color(0.16, 0.28, 0.12, 0.0).lerp(Color(0.22, 0.36, 0.16, 0.0), r.randf()), r.randf() * TAU)
			# 果實：透明度 1 = 顏色用每叢自己的（_groundcover_field 只給三分之一的藤紅色，其他給葉子的綠，
			# 每片都有紅果的話遠看像撒了一地紅點，審查）
			for k in 2:
				var a := r.randf() * TAU
				_gc_box(st, Vector3(cos(a) * 0.2, 0.07, sin(a) * 0.2), Vector3(0.03, 0.03, 0.03), Color(1, 1, 1, 1.0))
	return st.commit()

func _groundcover_field() -> void:
	if OS.get_environment("GROUND_OFF") != "":
		return
	var mat := ShaderMaterial.new()
	mat.shader = GROUNDCOVER_SHADER
	var meshes_gc: Array[ArrayMesh] = [_groundcover_mesh(0), _groundcover_mesh(1), _groundcover_mesh(2)]
	var patch := FastNoiseLite.new()   # 野花一片一片
	patch.seed = 77
	patch.frequency = 0.035
	var gr := RandomNumberGenerator.new()
	gr.seed = 13
	var per := [2.6, 0.45, 2.4]   # 每平方公尺試幾次（條件過了才長）。2026-10-09 使用者：密一點、一眼看出豐富
	var cells := int(ARENA / GRASS_CHUNK)
	var half := GRASS_CHUNK * 0.5
	for cx in cells:
		for cz in cells:
			var o := Vector3((cx + 0.5) * GRASS_CHUNK - ARENA * 0.5, 0, (cz + 0.5) * GRASS_CHUNK - ARENA * 0.5)
			var area := Rect2(o.x - half, o.z - half, GRASS_CHUNK, GRASS_CHUNK)
			var near: Array[Rect2] = []
			for r: Rect2 in _blocked + _roads:
				if r.intersects(area):
					near.append(r)
			for kind in 3:
				var xf: Array[Transform3D] = []
				var cus: Array[Color] = []
				for i in int(GRASS_CHUNK * GRASS_CHUNK * per[kind]):
					var x := o.x + gr.randf_range(-half, half)
					var z := o.z + gr.randf_range(-half, half)
					if Trails.edge(x, z) < 0.5 or near.any(func(r: Rect2) -> bool: return r.has_point(Vector2(x, z))):
						continue
					var h := _terrain.fast_height(x, z)
					var ok := false
					match kind:
						0:   # 荒地乾穗草：雜訊高的一片片，在谷地或麥田邊
							ok = patch.get_noise_2d(x, z) > 0.05 and (h < 2.0 or _in_wheat(Vector3(x, 0, z))) and not _in_wheat_core(x, z)
						1:   # 鼠尾草：碎石、岩盤上
							var w := _ground_mix(x, z, h)
							ok = maxf(w.r, w.a) > 0.3 and patch.get_noise_2d(x * 1.7, z * 1.7) > 0.1   # 一叢叢聚著，不要平均撒滿中景
						2:   # 匍匐藤：濕泥、森林裡植被濃的地方
							var w := _ground_mix(x, z, h)
							ok = w.b > 0.3 or (ZONE_FOREST.has_point(Vector2(x, z)) and Terrain.vegetation(x, z) > 0.5 and patch.get_noise_2d(z, x) > 0.0)
					if not ok:
						continue
					xf.append(Transform3D(Basis(Vector3.UP, gr.randf() * TAU).scaled(Vector3.ONE * gr.randf_range(0.8, 1.25)),
						Vector3(x - o.x, h - 0.02, z - o.z)))
					if kind == 2:
						cus.append((Color(0.45, 0.1, 0.07) if gr.randf() < 0.33 else Color(0.18, 0.31, 0.13)).srgb_to_linear())
					else:
						cus.append((FLOWER_COLORS[gr.randi() % FLOWER_COLORS.size()] as Color).srgb_to_linear())
				if xf.is_empty():
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true   # 一定要在 instance_count 之前設
				mm.mesh = meshes_gc[kind]
				mm.instance_count = xf.size()
				for i in xf.size():
					mm.set_instance_transform(i, xf[i])
					mm.set_instance_custom_data(i, cus[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Groundcover"
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.position = Vector3(o.x, 0, o.z)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 30.0
				mmi.extra_cull_margin = 0.5
				add_child(mmi)

## 麥田裡面（離邊 4 公尺以上）：野花只長在麥田邊，裡面看不到
func _in_wheat_core(x: float, z: float) -> bool:
	for f: Rect2 in _wheat_fields:
		if f.grow(-4.0).has_point(Vector2(x, z)):
			return true
	return false

## 一叢七片葉子，每片兩段（根部四邊形＋尖端三角形）。UV.y＝離地高度比例，shader 靠它做漸層和擺動
func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for k in 7:
		var a := r.randf() * TAU
		var h := r.randf_range(0.3, 0.55)
		var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.05, 0.2)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.018   # 像素版：直的長方形葉子，0.035 寬的話分段收尖像竹筍（第五輪審查）
		var at := Vector3(r.randf_range(-0.12, 0.12), 0, r.randf_range(-0.12, 0.12))
		var mid := at + lean * 0.4 + Vector3(0, h * 0.5, 0)
		var tip := at + lean + Vector3(0, h, 0)
		# 兩段長方形（不收尖）：葉子變細是 grass.gdshader 照高度分段挖掉兩側，邊緣是一階一階的（像素風）
		for q: Array in [[at - side, 0.0], [at + side, 1.0], [mid + side, 1.0], [at - side, 0.0], [mid + side, 1.0], [mid - side, 0.0],
				[mid - side, 0.0], [mid + side, 1.0], [tip + side, 1.0], [mid - side, 0.0], [tip + side, 1.0], [tip - side, 0.0]]:
			var p: Vector3 = q[0]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[1], p.y / h))
			st.add_vertex(p)
	return st.commit()

## 地面顏色直接畫在地形頂點上：泥土路跟著地形起伏、麥田是黃的、
## 坡頂偏乾黃、山谷偏深綠、陡坡露土、農莊的院子踩出一片泥地
func _ground_color(x: float, z: float, h: float) -> Color:
	return ground_color(_terrain, _wheat_fields, _roads, x, z, h)

## 地面顏色：路、麥田、草地（越高越黃、越陡越露土）。編輯器畫地形（LevelRoot）也用這支
static func ground_color(t: Terrain, wheat: Array[Rect2], roads: Array[Rect2], x: float, z: float, h: float) -> Color:
	if roads.any(func(r: Rect2) -> bool: return r.has_point(Vector2(x, z))):
		return DIRT   # 透明度 1：地面 shader 換成小路的紋理（terrain.gdshader）
	for f: Rect2 in wheat:
		if f.has_point(Vector2(x, z)):
			return Color(WHEAT, 0.0)   # 透明度 0：不是路
	var c := GRASS.lerp(Color(0.86, 0.71, 0.43), clampf((h + Terrain.AMP) / (Terrain.AMP * 2.0), 0.0, 1.0) * 0.55)
	# 旱地（植被密度低）偏乾土色，跟上面長的草、仙人掌、石頭對得上
	c = c.lerp(DIRT, (1.0 - Terrain.vegetation(x, z)) * 0.35)
	c = c.lerp(DIRT, clampf(t.slope(x, z) * 5.0, 0.0, 0.7))
	# 荒地小路：顏色往乾土拉，透明度 = 路的濃度（terrain.gdshader 照它換紋理）
	var w := Trails.weight(x, z)
	c = c.lerp(PATH, w)
	c.a = w
	return c

## 四種地面材質的權重（terrain.gdshader 的 CUSTOM0；GPT 建議的規則，docs/image/ground/gpt_suggestions.json）：
##   r 碎石：陡坡、房子和小路周圍，雜訊一塊一塊｜g 乾裂土：低窪又乾的地方｜b 濕泥：森林裡的低處、植被濃｜a 岩盤：高處的稜線
## 每種再乘一張自己的雜訊，同一種條件下也是一塊有、一塊沒有（不會整片同一種）。路、麥田不疊
static var _mix_noise: Array[FastNoiseLite] = []
func _ground_mix(x: float, z: float, h: float) -> Color:
	if OS.get_environment("GROUND_OFF") != "":   # 對照用：關掉地面材質和地被
		return Color(0, 0, 0, 0)
	if _roads.any(func(r: Rect2) -> bool: return r.has_point(Vector2(x, z))) or _in_wheat(Vector3(x, 0, z)):
		return Color(0, 0, 0, 0)
	if _mix_noise.is_empty():
		for k in 4:
			var n := FastNoiseLite.new()
			n.seed = 900 + k
			n.frequency = 0.035   # 一片一片大一點（0.06 時太碎，一般視角看不出來）
			n.fractal_octaves = 2
			_mix_noise.append(n)
	var slope := _terrain.slope(x, z)
	var veg := Terrain.vegetation(x, z)
	var hn := h / Terrain.AMP   # -1 谷底 ～ 1 山頂
	var trail := Trails.weight(x, z)
	var p := Vector2(x, z)
	var near_town := ZONE_TOWN.grow(4.0).has_point(p) or ZONE_FARM.grow(4.0).has_point(p)
	var gravel: float = maxf(smoothstep(0.1, 0.3, slope), maxf(trail, 0.6 if near_town else 0.48)) * (0.55 + 0.45 * smoothstep(-0.2, 0.3, _mix_noise[0].get_noise_2d(z * 0.5, x * 0.5)))   # 底子：大片一點、再被第二層雜訊挖洞，院子裡還看得到一塊塊的土 * smoothstep(-0.35, 0.05, _mix_noise[0].get_noise_2d(x, z))
	var clay: float = smoothstep(0.25, -0.1, hn) * smoothstep(0.8, 0.4, veg) * (0.0 if ZONE_FOREST.grow(8.0).has_point(p) else 1.0)   # 林邊不要乾裂土（審查：林邊一片磚紋） * smoothstep(-0.35, 0.05, _mix_noise[1].get_noise_2d(x, z))
	var mud: float = smoothstep(0.35, 0.0, hn) * smoothstep(0.35, 0.6, veg) * (1.0 if ZONE_FOREST.grow(6.0).has_point(p) else 0.4) * smoothstep(-0.35, 0.05, _mix_noise[2].get_noise_2d(x, z))
	var rock: float = smoothstep(0.05, 0.3, hn) * (0.6 + 0.4 * smoothstep(0.03, 0.1, slope)) * smoothstep(-0.35, 0.05, _mix_noise[3].get_noise_2d(x, z))
	var c := Color(gravel, clay, mud, rock)
	var sum := c.r + c.g + c.b + c.a
	return c / sum if sum > 1.0 else c

## 把「離地多高」換成實際位置：v.y 當作離地面的高度
func _on_ground(v: Vector3) -> Vector3:
	return Vector3(v.x, _terrain.height(v.x, v.z) + v.y, v.z)

## 這塊地能不能蓋東西：沙盒的靶場、撤離區要空著。
func _free(pos: Vector3, radius: float) -> bool:
	for r: Rect2 in _reserved():
		if r.grow(radius).has_point(Vector2(pos.x, pos.z)):
			return false
	return true

func _reserved() -> Array[Rect2]:
	var out: Array[Rect2] = [load("res://main.gd").SANDBOX_RANGE]
	for e: Vector2 in exit_spots():
		out.append(Rect2(e.x - EXIT_RADIUS - 4, e.y - EXIT_RADIUS - 4, EXIT_RADIUS * 2 + 8, EXIT_RADIUS * 2 + 8))
	return out

## 兩個撤離區的中心：東西兩端（南北向那條路留給沙盒靶場）
static func exit_spots() -> Array[Vector2]:
	var d := ARENA * 0.5 - 22.0
	return [Vector2(d, 0), Vector2(-d, 0)]

## 農莊：穀倉＋農舍＋筒倉，外面一圈柵欄。穀倉是恐龍爬上去看全場的制高點
func _farmstead(c: Vector3, rng: RandomNumberGenerator) -> void:
	var barn := c + Vector3(-8, 0, -4)
	if _free(barn, 14):
		_gen_barn(barn, Vector3(rng.randf_range(12, 16), rng.randf_range(7, 9), rng.randf_range(18, 24)))
	var house := c + Vector3(12, 0, 8)
	if _free(house, 8):
		_gen_house(house)
	var silo := c + Vector3(4, 0, -16)
	if _free(silo, 4):
		_put({kind = &"silo", pos = silo, h = rng.randf_range(13, 18)})
	# 柵欄圍一圈，留兩個缺口當出入口
	var r := 24.0
	for side in 4:
		for k in 8:
			if k == 3 or k == 4:
				if side % 2 == 0:
					continue   # 南北兩邊中間留門
			var u := -r + (k + 0.5) * (r * 2.0 / 8.0)
			var p: Vector3 = [Vector3(u, 0, -r), Vector3(r, 0, u), Vector3(u, 0, r), Vector3(-r, 0, u)][side]
			if _free(c + p, 2):
				_put({kind = &"fence", pos = c + p, length = r * 2.0 / 8.0, yaw = -PI * 0.5 if side % 2 == 1 else 0.0})
	# 南北兩個缺口各一對圍欄門，敞開往外。缺口太靠場地邊緣（門開出去會撞到場邊柵欄）就不裝
	for zz: float in [-r, r]:
		if _free(c + Vector3(0, 0, zz), 7) and absf(c.z + zz) < ARENA * 0.5 - 6.0:
			# 門柱往缺口內縮一點，不跟柵欄端點的木樁疊在一起
			_put({kind = &"gate", pos = c + Vector3(-r / 4.0 + 0.2, 0, zz), out = signf(zz), left = true})
			_put({kind = &"gate", pos = c + Vector3(r / 4.0 - 0.2, 0, zz), out = signf(zz), left = false})
	var mill := c + Vector3(15, 0, -12)
	if _free(mill, 3) and _is_clear(Vector2(mill.x, mill.z)):
		_put({kind = &"windmill", pos = mill})

## 靶場的地圖：整片壓平，中間一條靶道，每 10 公尺一條橫的土線；兩側柵欄，射擊線後面擺個棚子和雜物，
## 盡頭一排樹當背景。靶（牛仔、恐龍）是開局才生的，不在清單裡（見 _start_range）
func _generate_range(rng: RandomNumberGenerator) -> void:
	_put({kind = &"flat", pos = Vector3.ZERO, r = 150.0})
	var z0: float = load("res://main.gd").RANGE_START.z
	_put({kind = &"road", pos = Vector3(0, 0, z0), size = Vector3(44, 0, 6)})   # 射擊線
	# 中間的靶道和 75 公尺那條橫路（以前是牧場十字路順便畫的，牧場改成彎曲小路後自己鋪）
	_put({kind = &"road", pos = Vector3.ZERO, size = Vector3(8, 0, ARENA)})
	_put({kind = &"road", pos = Vector3.ZERO, size = Vector3(ARENA, 0, 8)})
	for d in range(10, 160, 10):
		if d != 75:   # 75 公尺那條是上面的橫路
			_put({kind = &"road", pos = Vector3(0, 0, z0 - d), size = Vector3(36, 0, 2)})
	for side: float in [-1.0, 1.0]:
		for k in 15:
			_put({kind = &"fence", pos = Vector3(side * 20.0, 0, z0 - 3.0 - k * 10.0), length = 10.0, yaw = -PI * 0.5})
	var shed := Vector3(-34, 0, z0 - 4)
	_gen_barn(shed, Vector3(8, 4, 6), 3.0)
	_gen_clutter(Vector3(10, 0, z0 + 3.5), 0.0)
	_gen_clutter(Vector3(-10, 0, z0 + 3.5), 0.0)
	_put({kind = &"prop", name = &"Wagon", pos = Vector3(30, 0, z0 - 2), yaw = 0.3})
	for x in range(-44, 45, 7):
		_gen_tree(Vector3(x + rng.randf_range(-2, 2), 0, -79 + rng.randf_range(-1.5, 1.5)), rng, 0.3)
	for i in 24:   # 靶道兩側外面零星的樹
		var p := Vector3((30 + rng.randf_range(0, 45)) * (1 if i % 2 else -1), 0, rng.randf_range(-70, 55))
		if _free(p, 2) and _is_clear(Vector2(p.x, p.z), 2.0):
			_gen_tree(p, rng, 0.3)

## 四個區域（x、z 範圍）。中間留 16 公尺寬的十字空帶（以前是十字路，現在是主路和空地）；西南那塊的東邊讓給沙盒靶場
const ZONE_FARM := Rect2(-84, -84, 76, 76)
const ZONE_TOWN := Rect2(8, -84, 76, 76)
const ZONE_WHEAT := Rect2(-84, 8, 62, 76)
const ZONE_FOREST := Rect2(22, 8, 62, 76)

## 農社區（西北）：一座大農莊（穀倉、農舍、筒倉、風車、一圈柵欄），往路口那邊兩戶人家，路口旁一小塊牧場
func _zone_farm(rng: RandomNumberGenerator) -> void:
	var a := Vector3(-56, 0, -56)
	_put({kind = &"flat", pos = a, r = 30.0})
	_farmstead(a, rng)
	for z: float in [-70.0, -48.0]:
		var h := Vector3(-22, 0, z)
		_put({kind = &"flat", pos = h, r = 10.0})
		_gen_house(h)
	# 牧場：柵欄隔成欄位（翻越練習），旁邊一間小棚子
	var shed := Vector3(-12, 0, -40)   # 再往南會壓到沙盒靶場（z > -30）
	_put({kind = &"flat", pos = shed, r = 10.0})
	_gen_barn(shed, Vector3(8, 4, 6), 3.0)
	for k in 3:
		for seg in 2:
			var p := Vector3(-39 + seg * 10.0, 0, -26 + k * 8.0)
			if _free(p, 2) and rng.randf() > 0.2 and _is_clear(Vector2(p.x, p.z)):
				_put({kind = &"fence", pos = p, length = 10.0, yaw = 0.0})

## 城鎮（東北）：一條東西向的主街，兩排店面面對面（北排朝南、南排朝北），店門口有繫柱架，
## 街上停一台篷車，後面一座水塔當制高點
func _zone_town(rng: RandomNumberGenerator) -> void:
	var sz := -46.0   # 主街中線
	_put({kind = &"road", pos = Vector3(46, 0, sz), size = Vector3(76, 0, 8)})
	for x: float in [16.0, 36.0, 56.0, 76.0]:
		_put({kind = &"flat", pos = Vector3(x, 0, sz), r = 22.0})
	var north := [[&"Saloon", 18.0], [&"Store", 32.0], [&"Sheriff", 45.0], [&"house", 58.0], [&"Store", 72.0]]
	var south := [[&"Store", 26.0], [&"Sheriff", 38.0], [&"Saloon", 51.0], [&"Store", 65.0]]   # 西邊讓給沙盒靶場
	for row: Array in [[north, sz - 14.0, 0.0, -1.0], [south, sz + 14.0, PI, 1.0]]:
		for b: Array in row[0]:
			var p := Vector3(b[1], 0, row[1])
			if b[0] == &"house":
				_gen_house(p)
				continue
			_put({kind = &"shop", pos = p, variant = b[0], yaw = row[2]})
			# 門口的繫柱架：台階旁邊，在街上
			_put({kind = &"hitch", pos = Vector3(b[1] + 3.6, 0, sz + row[3] * 3.0)})
		for i in row[0].size() - 1:   # 兩棟之間的巷子口堆一點雜物（農舍自己會堆，旁邊不再堆）
			if &"house" in [row[0][i][0], row[0][i + 1][0]]:
				continue
			var x: float = (row[0][i][1] + row[0][i + 1][1]) * 0.5
			_gen_clutter(Vector3(x, 0, row[1] - row[3] * 4.0), PI * 0.5)
	_put({kind = &"prop", name = &"Wagon", pos = Vector3(54, 0, sz + 1.5), yaw = 0.1 + rng.randf() * 0.2})
	_put({kind = &"water_tower", pos = Vector3(78, 0, -78), yaw = 0.0})

## 麥田（西南）：一大片麥子，裡面散著圓捆當掩體，東北角一間倉庫，西邊一座風車
func _zone_wheat(rng: RandomNumberGenerator) -> void:
	var c := Vector3(-52, 0, 50)
	_put({kind = &"wheat", pos = c, size = 58.0})
	# 田裡的車輪痕：一橫一直兩條窄土路，不長麥子
	_put({kind = &"road", pos = Vector3(-52, 0, 44), size = Vector3(58, 0, 2.5)})
	_put({kind = &"road", pos = Vector3(-45, 0, 50), size = Vector3(2.5, 0, 58)})
	var shed := Vector3(-30, 0, 28)
	_put({kind = &"flat", pos = shed, r = 7.0})
	_put({kind = &"hay_shed", pos = shed})
	_gen_hay_stack(shed + Vector3(-4.2, 0, 1.5), PI * 0.5)
	_gen_clutter(shed + Vector3(4.5, 0, 4.2), 0.0)
	for i in 12:
		var p := c + Vector3(rng.randf_range(-27, 27), 0, rng.randf_range(-27, 27))
		var yaw := rng.randf() * PI
		if _free(p, 2) and not _shed_rect(shed).has_point(Vector2(p.x, p.z)) and _is_clear(Vector2(p.x, p.z)):
			_put({kind = &"hay_bale", pos = p, yaw = yaw})
	_put({kind = &"windmill", pos = Vector3(-78, 0, 12)})   # 麥田外面，西北角

## 森林（東南）：一整片林子（闊葉樹為主、三成松樹），中間一塊空地有間圓木小屋和柴堆
func _zone_forest(rng: RandomNumberGenerator) -> void:
	var cabin := Vector3(52, 0, 48)
	_put({kind = &"flat", pos = cabin, r = 11.0})
	_gen_house(cabin, &"House2")
	_gen_clutter(cabin + Vector3(7.5, 0, -3.0), PI * 0.5)
	var z := ZONE_FOREST.position.y + 4.0
	while z < ZONE_FOREST.end.y - 2.0:
		var x := ZONE_FOREST.position.x + 3.0
		while x < ZONE_FOREST.end.x - 2.0:
			var p := Vector3(x + rng.randf_range(-2.5, 2.5), 0, z + rng.randf_range(-2.5, 2.5))
			# 植被密度低的地方是林間空地（不是一整片格子排的樹）；最稀也還有四成多，看起來還是森林
			if rng.randf() < lerpf(0.45, 1.0, Terrain.vegetation(p.x, p.z)) and _free(p, 2) and _is_clear(Vector2(p.x, p.z)) and _inside(p, 3.0):
				_gen_tree(p, rng, 0.35)
			x += 6.5
		z += 6.5

## 麥田裡的麥子：一叢一叢，大約 80 公分高，蹲在裡面會被擋掉一部分。沒有碰撞，子彈照樣穿過去。
## 麥田的黃色畫在地形上（_ground_color）。倉庫蓋在哪，那塊就不長麥子。
## 用自己的亂數（照麥田位置算）：麥子只是外觀，不該影響其他東西的位置
func _wheat(rec: Dictionary) -> void:
	var c: Vector3 = rec.pos
	var sheds: Array[Rect2] = _roads.duplicate()   # 路上和倉庫那塊不長麥子
	for other: Dictionary in _level:
		if other.kind == &"hay_shed":
			sheds.append(_shed_rect(other.pos))
	var wr := RandomNumberGenerator.new()
	wr.seed = int(c.x * 7919.0 + c.z)
	var pts: Array[Transform3D] = []
	const STEP := 0.8   # 每叢間距（一叢三張卡片）：要擋得住視線（使用者 2026-10-09）；以前 1.1 一叢一張
	var n := int(rec.size / STEP)
	var start: float = -rec.size * 0.5 + 0.5
	for gx in n:
		for gz in n:
			var at := _on_ground(c + Vector3(start + gx * STEP + wr.randf_range(-0.3, 0.3), 0,
				start + gz * STEP + wr.randf_range(-0.3, 0.3)))
			if sheds.any(func(r: Rect2) -> bool: return r.has_point(Vector2(at.x, at.z))):
				continue
			pts.append(Transform3D(Basis(Vector3.UP, wr.randf() * TAU).scaled(Vector3.ONE * wr.randf_range(0.9, 1.1)), at))
	_scatter_mesh(wheat_card(), pts)

## 麥子：只會水平轉向鏡頭的看板（billboard），貼上麥穗的透明圖（tools/make_wheat_card.py 畫的）。
## 一叢是三張卡片（左、中、右前後錯開、高矮不同、左右翻面），轉向鏡頭時三張有前後層次，比一張平面密、擋得住視線。
## 圖是 1:2，最高的穗在卡片高度約 82%。2026-10-09 使用者：麥子要比人高（牛仔 1.8、眼睛 1.6）、要有遮蔽效果：
## 卡片 2.6 高，最高的穗約 2.1 公尺；隨機縮放 0.9～1.1 → 1.9～2.35
static var _wheat_mesh: ArrayMesh
const WHEAT_CARDS := [[-0.35, 0.15, 0.95, false], [0.0, -0.1, 1.0, true], [0.35, 0.2, 0.9, false]]   # [左右, 前後, 高度倍數, 翻面]
static func wheat_card() -> Mesh:
	if _wheat_mesh == null:
		var mat := ShaderMaterial.new()   # 只繞垂直軸轉的看板、近處變少、穗尖壓暗（見 wheat.gdshader）
		mat.shader = preload("res://wheat.gdshader")
		mat.set_shader_parameter(&"card_tex", preload("res://assets/textures/wheat_card.png"))
		mat.set_shader_parameter(&"near_thin", 0.0)   # 要擋視線：近處不藏
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.BACK)
		for c: Array in WHEAT_CARDS:
			var w := 0.65
			var h := 2.6 * float(c[2])
			var x: float = c[0]
			var z: float = c[1]
			var u0 := 1.0 if c[3] else 0.0
			var u1 := 1.0 - u0
			var q := [[Vector3(x - w, 0, z), Vector2(u0, 1)], [Vector3(x + w, 0, z), Vector2(u1, 1)],
				[Vector3(x + w, h, z), Vector2(u1, 0)], [Vector3(x - w, h, z), Vector2(u0, 0)]]
			for i: int in [0, 2, 1, 0, 3, 2]:   # Godot 正面是順時針：反過來的話是背面，打光整片暗
				st.set_uv(q[i][1])
				st.add_vertex(q[i][0])
		_wheat_mesh = st.commit()
		_wheat_mesh.surface_set_material(0, mat)
	return _wheat_mesh

## 倉庫連門口那塊地（不長麥子、不放圓捆）
func _shed_rect(p: Vector3) -> Rect2:
	return Rect2(p.x - 5.5, p.z - 5.0, 12.0, 11.0)

## 穀倉：空心的，進得去。牆（含門洞、窗洞）、閣樓、柱子、隔間的碰撞是 Blender 的 BarnCol，
## 屋頂碰撞是兩片斜板（看不見）。整棟照實際大小縮放，屋頂的寬和高用同一個倍率縮，斜度才跟碰撞一樣。
## 小棚子也用這個，只是小一號（閣樓 2 公尺、門 2.9 × 2.4，一樣進得去、爬得上去）。
func _barn(p: Vector3, size: Vector3) -> void:
	p = _on_ground(p)
	var s := size / BARN_BASE
	_solid_mesh(p, _props.get(&"BarnCol"), s)
	_roof(p, size, BARN_PITCH)
	_prop(&"Barn", p, s)
	_prop(&"BarnRoof", p + Vector3(0, size.y, 0), Vector3(s.x, s.x, s.z))
	if DisplayServer.get_name() != "headless":
		_barn_light(p, size)
	# 正面兩扇滑門：關著剛好蓋住門洞，開的時候各往外滑半個門寬
	var front := size.z * 0.5 + 0.12
	for side in [-1.0, 1.0]:
		var d := _door(&"BarnDoorSlide", p + Vector3(side * BARN_DOOR_W * 0.25 * s.x, 0, front),
			Vector3(BARN_DOOR_W * 0.5, BARN_DOOR_H, 0.16), Vector3.ZERO, Vector3(s.x, s.y, 1))
		d.slide = Vector3(side * BARN_DOOR_W * 0.5 * s.x, 0, 0)
	# 後門：門軸在開口左緣，往裡推開
	var back := _door(&"BarnBackDoor", p + Vector3((BARN_BACK_X - BARN_BACK_W * 0.5) * s.x, 0, -(BARN_BASE.z * 0.5 - BARN_T * 0.5) * s.z),
		Vector3(BARN_BACK_W, BARN_BACK_H, 0.08), Vector3(BARN_BACK_W * 0.5, 0, 0), Vector3(s.x, s.y, 1))
	back.swing = -PI * 0.5
	# 閣樓的梯子：靠在閣樓邊緣（z=0），人站在梯子前面（+Z 那側）面向 -Z 爬
	var loft := BARN_LOFT * s.y
	var lx := BARN_LADDER_X * s.x
	_ladder(p + Vector3(lx, 0, 0.15 * s.z), loft + 1.0, p + Vector3(lx, 0, 0.15 * s.z + 0.5), loft,
		p + Vector3(lx, loft + 0.1, -1.0 * s.z), 0.0)

## 農舍：空心的，進得去。kind 是三種外觀之一（前廊農舍、圓木小屋、直板高屋），碰撞跟著外觀走
func _house(p: Vector3, kind: StringName) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(StringName(kind + "Col")), Vector3.ONE)
	Fx.chimney(self, p + HOUSE_KINDS[kind])
	_prop(kind, p)
	# 前門：門軸在門洞左緣，往屋裡推開
	var d := _door(&"HouseDoor", p + Vector3(-0.55, HOUSE_FLOOR, 4.0 - HOUSE_T * 0.5),
		Vector3(1.1, 2.2, 0.08), Vector3(0.55, 0, 0), Vector3.ONE)
	d.swing = PI * 0.5

## --- 場景小物件（kits.glb） ---
## 下面這些函式都自己貼地：p 給不含高度的位置（p.y 是離地高度，通常 0）。
## 已經 _on_ground 過的座標要先把 y 歸零，不然地面多高就浮多高

## 小物件的碰撞方塊大小（底部貼地）。表裡沒有的只有外觀
const KIT_SIZE := {&"Barrel": Vector3(0.7, 0.93, 0.7), &"Crate": Vector3(0.8, 0.8, 0.8), &"HayBlock": HAY_BLOCK,
	&"GatePost": Vector3(0.24, 1.6, 0.24)}

## 擺一個小物件。方草捆跟圓捆一樣算軟：掉在上面摔落傷害減半
func _kit(name: StringName, p: Vector3, yaw: float) -> Node3D:
	p = _on_ground(p)
	var size: Vector3 = KIT_SIZE.get(name, Vector3.ZERO)
	if size == Vector3.ZERO:
		var mi := _prop(name, p)
		mi.rotation.y = yaw
		return mi
	var body := _solid_box(p + Vector3(0, size.y * 0.5, 0), size)
	body.rotation.y = yaw
	if name == &"HayBlock":
		body.add_to_group(&"soft")
	elif name == &"Crate":
		body.set_script(SupplyCrate)   # 木箱都是補給箱（F 補炸藥）
	_prop(name, Vector3(0, -size.y * 0.5, 0), Vector3.ONE, body)
	if name == &"Crate":
		Accent.mark(body)
	return body

## 靠在牆上的車輪（只有外觀）。p 是牆腳，牆面朝 yaw 方向（0 = 朝 +Z），輪子頂端往牆那邊倒一點
func _lean_wheel(p: Vector3, yaw: float) -> void:
	_prop(&"Wheel", Vector3.ZERO).transform = Transform3D(Basis(Vector3.UP, yaw), _on_ground(p)) * WHEEL_POSE

## 靠牆車輪相對牆腳的擺法：輪軸轉到跟牆垂直、頂端往牆倒一點、輪心離地 0.6（編輯器預覽也用）
const WHEEL_POSE := Transform3D(Basis(Vector3.RIGHT, -0.18) * Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.6, 0.24))

## 馬匹繫柱架：兩根柱子有碰撞，中間的繫馬橫桿 1 公尺高，翻得過去
func _hitch(p: Vector3) -> void:
	p = _on_ground(p)
	_prop(&"HitchRail", p)
	for sx: float in [-1.6, 1.6]:
		_solid_box(p + Vector3(sx, 1.25, 0), Vector3(0.2, 2.5, 0.2))
	_solid_box(p + Vector3(0, 1.0, 0), Vector3(3.2, 0.1, 0.1))

## 圍欄門：門柱有碰撞，門板敞開往外（只有外觀，不擋路）。left = 缺口左邊（-X 那側）；out = 往外是 -Z（-1）還是 +Z（+1）
func _gate(p: Vector3, out: float, left: bool) -> void:
	_kit(&"GatePost", p, 0.0)
	_prop(&"FenceGate", Vector3.ZERO).transform = Transform3D(Basis(), _on_ground(p)) * gate_leaf(out, left)

## 圍欄門的門板相對門柱的擺法：門板本來往 +X 長，轉過去朝外敞開（編輯器預覽也用）
static func gate_leaf(out: float, left: bool) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(100.0 if left else 80.0) * -out), Vector3(0.12 if left else -0.12, 0, 0))

## 風車塔：四根塔腳底部有碰撞；葉輪一直慢慢轉
func _windmill(p: Vector3) -> void:
	p = _on_ground(p)
	_prop(&"Windmill", p)
	for sx: float in [-1.2, 1.2]:
		for sz: float in [-1.2, 1.2]:
			_solid_box(p + Vector3(sx, 1.5, sz), Vector3(0.3, 3.0, 0.3))
	var rotor := _prop(&"WindmillRotor", p + WINDMILL_HUB)
	rotor.create_tween().set_loops().tween_property(rotor, ^"rotation:z", TAU, 7.0).as_relative()

const SHED_LANTERN := Vector3(2.0, 2.95, 3.25)   # 倉庫門口的吊燈（編輯器預覽也用）

## 倉庫／圍棚：門朝 +Z 敞開，裡面疊著方草捆。牆、屋頂、草捆的碰撞是 HayShedCol
## 城鎮店面（酒館、雜貨店、警長辦公室）：空心的，門窗是開口（沒有門板）。碰撞是 Blender 的 <名字>Col，
## 跟著朝向轉（yaw 0 正面朝 +Z，PI 朝 -Z）。裡面吊的提燈是打得破的油燈（lantern.gd 的 replace_baked），屋裡的光就是它
func _shop(p: Vector3, variant: StringName, yaw: float) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(StringName(variant + "Col")), Vector3.ONE).rotation.y = yaw
	_prop(variant, p).rotation.y = yaw

## 水塔：四根腳和水桶有碰撞（恐龍爬得上去，當城鎮的制高點）
func _water_tower(p: Vector3, yaw: float) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(&"WaterTowerCol"), Vector3.ONE).rotation.y = yaw
	_prop(&"WaterTower", p).rotation.y = yaw

func _hay_shed(p: Vector3) -> void:
	p = _on_ground(p)
	_solid_mesh(p, _props.get(&"HayShedCol"), Vector3.ONE)
	_prop(&"HayShed", p)
	OilLantern.place(self, _props.get(&"Lantern"), p + SHED_LANTERN)   # 打得破的油燈：射它會潑油燒起來

func _silo(p: Vector3, h: float) -> void:
	p = _on_ground(p)
	_solid_cyl(p + Vector3(0, h * 0.5, 0), 3.0, h)
	_solid_cyl(p + Vector3(0, h + 0.8, 0), 1.6, 1.6)   # 圓頂中間站得住的地方（爬梯子上來就站這）
	# 外側的爬梯（模型本來就有）：F 爬到頂，全場最高的狙擊點，摔下來也必死
	_ladder(p + Vector3(3.25, 0, 0), h, p + Vector3(3.25 + 0.5, 0, 0), h,
		p + Vector3(0, h + 1.7, 0), PI * 0.5)
	_prop(&"SiloBody", p, Vector3(1, h / SILO_BASE_H, 1))
	_prop(&"SiloDome", p + Vector3(0, h, 0))

## 柵欄：碰撞是一整片 1 公尺高的板子——剛好在翻越範圍內。外觀是一段段 2.5 公尺的
## 木樁＋橫木排過去（長度不整除就每段稍微拉長），最後補一根收尾的木樁
func _fence(p: Vector3, length: float, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	# 兩端各自貼地，整段沿著坡度斜過去。p.y 是離地高度（沙盒的練習柵欄用）。yaw 0 沿 X，-90 度沿 +Z
	var dir := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var a := _on_ground(p - dir * length * 0.5)
	var b := _on_ground(p + dir * length * 0.5)
	var x := (b - a).normalized()
	var z := x.cross(Vector3.UP).normalized()
	body.transform = Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, FENCE_H, 0.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = FENCE_H * 0.5
	body.add_child(cs)
	var n := maxi(ceili(length / FENCE_SEG), 1)
	var seg := length / n
	for i in n:
		_prop(&"FenceRail", Vector3(-length * 0.5 + (i + 0.5) * seg, 0, 0), Vector3(seg / FENCE_SEG, 1, 1), body)
	_prop(&"FencePost", Vector3(length * 0.5, 0, 0), Vector3.ONE, body)
	add_child(body)
	return body

const HAY_BALE_R := 0.7   # 圓捆半徑（躺著放，軸心離地這麼高；編輯器預覽也用）
func _hay_bale(p: Vector3, yaw: float) -> StaticBody3D:
	# 圓捆躺著放：直徑 1.4 公尺，翻得過去也蹲得進後面。模型的軸是直的，跟著碰撞圓柱一起放倒
	var body := _solid_cyl(_on_ground(p) + Vector3(0, HAY_BALE_R, 0), HAY_BALE_R, 1.3)
	body.rotation = Vector3(0, yaw, PI * 0.5)
	body.add_to_group(&"soft")   # 從屋頂跳下來落在乾草上，摔落傷害減半
	_prop(&"HayBale", Vector3.ZERO, Vector3.ONE, body)
	return body

## 樹：只有樹幹有碰撞，擋子彈；樹冠擋視線不擋子彈，躲在樹下只是比較難被看到。
## pine_chance：林子邊緣混一點松樹，果園只種闊葉樹
func _tree(rec: Dictionary) -> void:
	var p := _on_ground(rec.pos) + Vector3.DOWN * 0.3   # 往下埋一點：斜坡上樹根的下坡那側才不會懸空
	var s: float = rec.s
	var body: StaticBody3D
	if rec.mesh == &"TreePine":
		var h := s * TREE_BASE_TRUNK
		body = _solid_cyl(p + Vector3(0, h * 0.5, 0), 0.35, h)
	else:
		var trunk: Array = TREE_KINDS[rec.mesh]
		body = _solid_cyl(p + Vector3(0, trunk[1] * s * 0.5, 0), trunk[0] * s, trunk[1] * s)
	var mi := _prop(rec.mesh, p, Vector3.ONE * s)
	mi.rotation.y = rec.yaw
	_destructible(body, 2, mi)   # 甩兩下才倒（草案 4.2 等級 2）

## 人字屋頂的碰撞：兩片斜板。斜度在 45 度以內，恐龍爬上來站得住。
## 外觀在 Blender 的模型裡（blender/props.py 的 gable_roof() 照這個擺法建的）
func _roof(p: Vector3, size: Vector3, pitch: float) -> void:
	var run := size.x * 0.5
	var rise := run * tan(pitch)
	var w := run / cos(pitch) + 0.5   # 多出來的是屋簷
	for sx in [-1.0, 1.0]:
		var b := _solid_box(p + Vector3(sx * run * 0.5, size.y + rise * 0.5, 0), Vector3(w, 0.3, size.z + 1.0))
		b.rotation.z = -sx * pitch

## 穀倉裡的夕陽光柱和飄浮的灰塵（2026-10-10 環境感）：太陽那側的牆（+X）透進三道光，照太陽方向斜斜射進來，
## 在閣樓（-Z 那半）底下的另一半。只是畫面，伺服器不做
const SHAFT_SHADER := preload("res://light_shaft.gdshader")
func _barn_light(p: Vector3, size: Vector3) -> void:
	var d := -FarLand.TO_SUN.normalized()
	for z: float in [0.12, 0.25, 0.38]:
		var a := p + Vector3(size.x * 0.5 - 0.3, size.y * 0.42, z * size.z)
		var reach := minf((a.y - p.y - 0.3) / -d.y, minf((size.x - 0.6) / -d.x, (p.z + size.z * 0.5 - 0.3 - a.z) / d.z))
		var q := QuadMesh.new()   # 繞長軸轉向鏡頭（見 light_shaft.gdshader）
		q.size = Vector2(1.1, reach)
		q.material = ShaderMaterial.new()
		q.material.shader = SHAFT_SHADER
		q.custom_aabb = AABB(Vector3(-1, -reach * 0.5, -1), Vector3(2, reach, 2))   # 頂點在 shader 裡轉，原本的扁盒子會被誤判看不到
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group(&"barn_light")   # 時段：正午關、午夜換月光色（period.gd）
		add_child(mi)
		var side := d.cross(Vector3.UP).normalized()
		# 方形的 Y 軸順著光，UV.y = 0 在入口
		mi.global_transform = Transform3D(Basis(side, -d, side.cross(-d)), a + d * reach * 0.5)
	var motes := CPUParticles3D.new()
	motes.mesh = Fx._box(0.02, Color(1.0, 0.85, 0.6))
	motes.mesh.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	motes.amount = 60
	motes.lifetime = 8.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(size.x * 0.4, size.y * 0.2, size.z * 0.2)
	motes.gravity = Vector3(0, -0.02, 0)
	motes.spread = 180.0
	motes.initial_velocity_max = 0.08
	motes.tangential_accel_min = -0.05
	motes.tangential_accel_max = 0.05
	motes.color_ramp = Fx._fade(Color(1, 1, 1, 0.7))
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.add_to_group(&"barn_light")
	add_child(motes)
	motes.global_position = p + Vector3(0, size.y * 0.3, size.z * 0.25)
	motes.emitting = true

## 窗戶不發光（2026-10-10 使用者：之後改建模，不會有只有窗、裡面沒有室內的房子）：亮窗改成暗色玻璃。
## 窗和燈罩共用同一個發光材質（h_lit），油燈（Lantern）先換一份自己的，燈照樣亮
func _dark_windows() -> void:
	var lantern: Mesh = _props.get(&"Lantern")
	for i in lantern.get_surface_count():
		var m := lantern.surface_get_material(i)
		if m and String(m.resource_name) == "h_lit" and not m.has_meta(&"own"):
			var own := m.duplicate()
			own.set_meta(&"own", true)
			lantern.surface_set_material(i, own)
	for f: ShaderMaterial in ModelMaterials._facet_of.values():
		if String(f.resource_name) == "h_lit":
			f.set_shader_parameter(&"emission", Color.BLACK)
			f.set_shader_parameter(&"albedo", Color(0.09, 0.09, 0.11))

## 會動的門：碰撞是一塊板（看不見），外觀是 Blender 的門。
## pivot 是門軸／底部中央的位置；box 是門板大小（沒縮放前），center 是門板中心相對門軸的位置。
## 名字依序取 Door0、Door1…：每台機器蓋場景的順序一樣，RPC 才找得到同一扇門
func _door(mesh: StringName, pivot: Vector3, box: Vector3, center: Vector3, scale: Vector3) -> Door:
	var d := Door.new()
	d.name = "Door%d" % _doors.size()
	d.position = pivot
	var shape := BoxShape3D.new()
	shape.size = box * scale
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = (center + Vector3(0, box.y * 0.5, 0)) * scale
	d.add_child(cs)
	_prop(mesh, Vector3.ZERO, scale, d)
	Accent.mark(d)
	add_child(d)
	_doors.append(d)
	return d

## 梯子：thin 的碰撞板讓射線打得到（F 才有反應）。
## at 梯子底部中央；height 梯子多高；foot 人抓住時站的位置；top_y 腳到這個高度就算爬上去；
## exit 爬上去之後站的位置；yaw 爬的時候面向哪
func _ladder(at: Vector3, height: float, foot: Vector3, top_y: float, exit: Vector3, yaw: float) -> void:
	var l := Ladder.new()
	l.position = at + Vector3(0, height * 0.5, 0)
	l.rotation.y = yaw
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, height, 0.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	l.add_child(cs)
	l.foot = foot
	l.top_y = top_y
	l.exit = exit
	l.yaw = yaw
	# 梯子的模型是建築的一部分，強調色疊不上去：兩側另外貼兩條強調色的細條
	for x: float in [-0.22, 0.22]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, height, 0.06)
		rail.mesh = bm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Accent.COLOR
		rail.material_override = rm
		rail.position = Vector3(x, 0, 0.06)
		l.add_child(rail)
	Accent.mark(l)
	add_child(l)

## 空心建築的碰撞：直接拿 Blender 的碰撞模型（BarnCol / HouseCol）當形狀，照實際大小縮放。
## 縮放烘進頂點，不縮碰撞節點——物理引擎對非等比縮放的網格形狀支援不一
func _solid_mesh(pos: Vector3, mesh: Mesh, scale: Vector3) -> StaticBody3D:
	var faces := mesh.get_faces()
	for i in faces.size():
		faces[i] *= scale
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true   # 牆只有幾公分厚，兩面都要擋
	return _body(pos, shape)

## 一次撒幾千個一樣的東西（麥子、草叢）：MultiMesh 一次畫完，一叢一個節點會卡。
## 不投影子：幾千叢的影子很貴，而且貼著地面本來就看不太出來
func _scatter(name: StringName, pts: Array[Transform3D], shadows := false) -> void:
	_scatter_mesh(_props.get(name), pts, shadows)

func _scatter_mesh(mesh: Mesh, pts: Array[Transform3D], shadows := false) -> void:
	add_child(FarLand._scatter(mesh, pts, shadows))   # 整片一個 MultiMesh（試過分塊：影子少兩成三角形，繪製指令卻多一倍，不划算）

## 擺一個 Blender 建的場景物件（models/props.glb）。parent 預設是場地
func _prop(name: StringName, pos: Vector3, scale := Vector3.ONE, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _props.get(name)
	mi.position = pos
	mi.scale = scale
	(parent if parent else self).add_child(mi)
	return mi

## 蛋換成 Blender 的模型（下胖上尖、有斑點），再疊一層加亮：場上最重要的東西要遠遠就看得到
func _skin_egg() -> void:
	var mi: MeshInstance3D = $"../Egg"/MeshInstance3D
	mi.mesh = _props.get(&"Egg")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.28, 0.24, 0.14)
	mi.material_overlay = glow

## 從 props.glb、trees.glb 把每個物件的網格拿出來，場上幾百個物件共用同一份
func _load_props() -> void:
	_props = meshes()

## 全部模型（props、樹、石頭、農舍、小物件）名字 -> Mesh。遊戲、編輯器預覽（LevelPreview）、擺設檢查（LevelCheck）共用這一份
static var _mesh_table := {}
static func meshes() -> Dictionary:
	if _mesh_table.is_empty():
		for glb: PackedScene in [PROPS, TREES, ROCKS, HOUSES, KIT, TOWNS, GROVES, FLORAS, CLUTTERS]:
			var src := glb.instantiate()
			for c in src.get_children():
				if c is MeshInstance3D:
					_mesh_table[StringName(c.name)] = c.mesh
			src.free()
	return _mesh_table

## 出生點避開這塊地
func _block(p: Vector3, size: Vector2, clearance: float) -> void:
	_blocked.append(Rect2(p.x - size.x * 0.5 - clearance, p.z - size.y * 0.5 - clearance,
		size.x + clearance * 2, size.y + clearance * 2))

## 兩個撤離區，對邊各一個。只有一個出口的話恐龍蹲在那裡就好；
## 兩個保留了選擇，但競爭比四個集中，撤離區更容易變成三方交會的爭奪點。
func _build_exits() -> void:
	for e: Vector2 in exit_spots():
		var c := _on_ground(Vector3(e.x, 0, e.y))
		_exits.append(c)
		# 地面標示用貼花（Decal）從上往下投在地上：撤離區沒整平（高低差可到 10 公尺），平板會一半埋進坡裡、一半浮在空中。
		# 圓形：裡面淡淡一層暖金，邊上一圈比較亮，站在圈外也看得出邊界
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.88, 0.95, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var d := Decal.new()
		d.texture_albedo = tex
		d.modulate = Color(0.95, 0.78, 0.4)   # 暖金：看得出來，又不像貼上去的藍色佔位片
		d.size = Vector3(EXIT_RADIUS * 2.0, Terrain.AMP * 3.0, EXIT_RADIUS * 2.0)   # 上下各投 15 公尺，坡再陡也蓋得到
		d.position = c
		add_child(d)
		_exit_pads.append(d)
		_exit_pipe(c)   # 旁邊的篷車和貨在擺設清單裡（_generate_level）

## 撤離點中間的綠色水管：遠遠就看得到撤離點在哪（0.8.1 回饋 U14）。
## ponytail: 佔位用的，之後換正式的撤離標的物模型。有碰撞，不然會變成看得到摸不到的東西
func _exit_pipe(c: Vector3) -> void:
	const R := 1.2
	const H := 6.0   # 比柵欄、乾草高很多，隔著小丘也看得到管口
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.62, 0.22)
	mat.roughness = 0.6
	for part: Array in [[R, H, H * 0.5], [R + 0.25, 0.8, H - 0.4]]:   # [半徑, 高, 中心高]：管身＋頂上一圈管口
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = part[1]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = c + Vector3(0, part[2], 0)
		mi.add_to_group(&"exit_pipe")
		add_child(mi)
	_solid_cyl(c + Vector3(0, H * 0.5, 0), R + 0.25, H)

## 找一個不在建築物裡面的出生點
func _spawn_point(span := ARENA * 0.45) -> Vector3:
	for i in 80:
		var p := Vector2(randf_range(-span, span), randf_range(-span, span))
		if _is_clear(p):
			return _on_ground(Vector3(p.x, 5.0, p.y))
	# 建築只蓋在中間，外圍一定是空的
	var edge := ARENA * 0.46
	var corner := Vector2(edge, edge).rotated(randf() * TAU)
	return _on_ground(Vector3(corner.x, 5.0, corner.y))

func _is_clear(p: Vector2, radius := 0.0) -> bool:   # radius：東西本身的半寬
	for r: Rect2 in _blocked:
		if r.grow(radius).has_point(p):
			return false
	return true

## 只有碰撞、沒有外觀：外觀由 Blender 的模型負責
func _solid_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _body(pos, shape)

func _solid_cyl(pos: Vector3, r: float, h: float) -> StaticBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	return _body(pos, shape)

func _body(pos: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body

# --- 雜項 ---
