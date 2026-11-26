extends RefCounted

const DITCH := preload("ditch.gd")
const FORMS := preload("tree_forms.gd")
const TREE_GROUPS := {
	"Cottonwood": [
		[-76.0, 15.0, 10.8, 0.23], [-72.0, 15.4, 9.2, 1.19],
		[-68.0, 16.0, 11.2, -0.34], [-65.0, 17.8, 8.5, 2.05],
		[-61.0, 18.5, 9.7, 0.71],
	],
	"Juniper": [
		[-55.0, -81.0, 6.7, 1.87], [-51.4, -78.9, 5.3, -0.42],
		[-47.0, -81.1, 6.9, 0.48], [-45.7, -76.9, 5.9, 2.25],
		[-49.0, -73.3, 6.2, -1.14],
	],
}

# 在母圖的最後一個場景安裝呼叫之後執行，讓 _toy 延用原有的對局識別順序。
static func install(farm: Node3D) -> void:
	if farm.has_node(^"NorthDitchTrees"):
		return
	var style := farm.get_node_or_null(^"FarmStyleEnvironment")
	if not style or not DITCH.install(farm):
		push_error("北田乾溝未套用，請核對 r011 地形和安裝順序")
		return
	var marker := Node3D.new()
	marker.name = "NorthDitchTrees"
	farm.add_child(marker)
	for group: String in TREE_GROUPS:
		var form := FORMS.make(group == "Cottonwood")
		for i in TREE_GROUPS[group].size():
			var spec: Array = TREE_GROUPS[group][i]
			var tree := build_tree(group, spec[2], i, spec[3])
			tree.set_meta(&"farm_landmark_tree", "%s%02d" % [group, i + 1])
			tree.set_meta(&"farm_tree_form", form)
			tree.add_to_group(&"tree")
			farm._place_greybox(farm._toy(tree), Vector3(spec[0], 0.0, spec[1]), spec[3])
			style.style_tree(tree)

static func build_tree(group: String, height: float, index: int, yaw: float) -> ToyBuild:
	var bricks: Array = []
	var leafy := group == "Cottonwood"
	var width: float = height * (0.054 if leafy else 0.087)
	var bark := Color("715948") if leafy else Color("6b4937")
	var canopy := Color("72913d") if leafy else Color("46634b")
	if leafy:
		stem(bricks, Vector3(0, -0.29, 0), Vector3(-0.04, height * .24, 0), width, bark)
		stem(bricks, Vector3(-0.04, height * .24, 0), Vector3(0.10, height * .48, .03), width * .88, bark)
		stem(bricks, Vector3(.10, height * .48, .03), Vector3(.34, height * .67, .06), width * .77, bark)
		crown(bricks, Vector3(-.10, .69, .03) * height, Vector3(.47, .34, .36) * height, canopy, -.12)
		crown(bricks, Vector3(.12, .73, -.03) * height, Vector3(.43, .38, .38) * height, canopy, .23)
		crown(bricks, Vector3(.025, .84, .025) * height, Vector3(.36, .32, .32) * height, canopy, .14 + .07 * index)
		open_cottonwood_skyline(bricks, index, yaw)
	else:
		stem(bricks, Vector3(0, -.26, 0), Vector3(0, height * .24, 0), width, bark)
		stem(bricks, Vector3(0, height * .24, 0), Vector3(-.16, height * .48, .03), width * .8, bark)
		stem(bricks, Vector3(-.16, height * .48, .03), Vector3(.20, height * .67, -.04), width * .69, bark)
		crown(bricks, Vector3(-.09, .49, .06) * height, Vector3(.49, .42, .43) * height, canopy, .10)
		crown(bricks, Vector3(.12, .66, -.02) * height, Vector3(.45, .38, .42) * height, canopy, -.24)
		crown(bricks, Vector3(-.03 + .017 * index, .86, .015) * height, Vector3(.37, .28, .27) * height, canopy, .17)
	return ToyBuild.make(bricks, true, 1)

static func open_cottonwood_skyline(bricks: Array, index: int, yaw: float) -> void:
	# Cottonwood02 和 Cottonwood03 的冠緣各往同組其餘樹伸，讓兩組之間透天。
	if index != 1 and index != 2:
		return
	var lateral := -.54 if index == 1 else .65
	var offset := Vector3(lateral, -.16 if index == 1 else .06, 0.).rotated(Vector3.UP, -yaw)
	var crown_width := .73 if index == 1 else .77
	for part in range(3, 6):
		var crown_part: Array = bricks[part]
		var pose: Transform3D = crown_part[0]
		var size: Vector3 = crown_part[1]
		pose.origin += offset
		crown_part[0] = pose
		crown_part[1] = size * Vector3(crown_width, .94, crown_width)

static func stem(bricks: Array, bottom: Vector3, top: Vector3, width: float, color: Color) -> void:
	var delta := top - bottom
	var rotation := Basis(Quaternion(Vector3.UP, delta.normalized()))
	bricks.append([Transform3D(rotation, (bottom + top) * .5), Vector3(width, delta.length() + .10, width), 2, color, true, &"tree"])

static func crown(bricks: Array, origin: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	bricks.append([Transform3D(Basis(Vector3.UP, yaw), origin), size, 1, color, false])
