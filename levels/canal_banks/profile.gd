extends RefCounted
## v2.6 原床斷面（世界 X、中心 Z、外緣半寬）。三處原渡口由母圖保有。
const BASE := [
	[-84,8.8125,4.069705],[-69,6,4.034853],[-54,6,4],[-47,6,4],
	[-40,8,4.160062],[-26,12,4.081143],[-2,12.8,4.002221],[4,13,4.076837],
	[10,11.333333,4.151454],[22,8,4.327428],[44,-3.379310,4.503401],
	[51,-7,4.28449],[58,-8.272727,4.065578],[73,-11,4.032788],[84,-11,4]]
## 退挖量（X、北、南，公尺）。渠底趾線不移，兩岸各自展寬或收回。
## 西灘前後的淤坡、中橋橋台與東堤石翼接土處保留原斷面。
const CUT := [
	[-84,0,0],[-82,1.4,1.1],[-78,2.8,1.9],[-73,2.5,2.9],[-69,1.5,2.7],
	[-66,0,2.1],[-64,.15,2.2],[-61,2.3,2.7],[-57,2.0,1.8],[-54,0,0],
	[-40,0,0],[-37,1.9,2.6],[-32,2.7,2.1],[-28,2.6,1.2],[-25,2.5,0],
	[-23,2.4,.2],[-20,1.7,2.4],[-15,1.7,3.1],[-10,2.5,2.3],[-5,1.8,1.6],[-2,0,0],
	[10,0,0],[13,1.6,2.1],[18,2.1,2.8],[23,2.7,2.4],[27,2.4,1.7],
	[30,0,1.8],[32,.12,2.2],[35,1.8,2.4],[40,2.2,1.7],[44,0,0],
	[58,0,0],[61,1.5,2.0],[64,2.1,2.3],[67,2.4,.12],[69,1.7,.15],
	[72,1.9,1.8],[76,2.5,2.7],[80,2.0,2.4],[82,1.5,1.6],[84,0,0]]
const WATER_Y := -1.38

static func _span(rows: Array, x: float) -> int:
	for i in range(1,rows.size()):
		if x <= float(rows[i][0]):
			return i
	return rows.size()-1

static func _pair(rows: Array, x: float, ease: bool) -> Vector2:
	var i := _span(rows,x)
	var a: Array = rows[i-1]
	var b: Array = rows[i]
	var t := clampf(inverse_lerp(float(a[0]),float(b[0]),x),0,1)
	if ease:
		t = smoothstep(0,1,t)
	return Vector2(a[1],a[2]).lerp(Vector2(b[1],b[2]),t)

static func section_at(x: float) -> Dictionary:
	if x < -84 or x > 84:
		return {}
	var base := _pair(BASE,x,false)
	# 烘焙以整公尺橫斷分段，查詢在兩站間沿同一條直邊插值。
	var extra := _pair(CUT,floorf(x),true).lerp(_pair(CUT,ceilf(x),true),x-floorf(x))
	var center := base.x
	var half_width := base.y
	var top := Vector2(center-half_width-extra.x,center+half_width+extra.y)
	var toe := Vector2(center-.6*half_width,center+.6*half_width)
	var offset := 0.0
	if x > -59 and x < -54: offset = 1.65*smoothstep(-59.,-54.,x)
	elif x >= -40 and x < -35: offset = 1.65*(1.-smoothstep(-40.,-35.,x))
	toe += Vector2(offset,-offset)
	var bed := -1.8
	var kind := "普通渠"
	if x >= -54 and x < -40:
		kind = "西灘"
		var table: Array = preload("res://levels/gate_water/west_ford.json").data
		var t := (x+54.)*4.
		var i := clampi(floori(t),0,table.size()-2)
		var a: Array = table[i]
		var b: Array = table[i+1]
		var crest := lerpf(a[1],b[1],t-i)
		var foot := lerpf(a[2],b[2],t-i)
		top = Vector2(center-crest,center+crest)
		toe = Vector2(center-foot,center+foot)
		bed = lerpf(a[3],b[3],t-i)
	elif x >= -2 and x < 10:
		kind = "中橋"
		top = Vector2(4,22)
	elif x >= 44 and x < 58:
		kind = "東堤"
		bed = 0
	var wet := Vector2.INF
	if x < 44.0:
		var table: Array = preload("res://levels/gate_water/open_water.json").data
		var t := (x+84.)*4.
		var i := clampi(floori(t),0,table.size()-1)
		var a: Array = table[i]
		var b: Array = table[mini(i+1,table.size()-1)]
		wet = Vector2(a[0],a[1]).lerp(Vector2(b[0],b[1]),t-i)
	elif x <= 58.194:
		var z := lerpf(-5.45,-8.27273,clampf((x-44.0)/(58.0-44.0),0.,1.))
		wet = Vector2(z-0.58,z+0.58)
	return {"x":x,"kind":kind,"center_z":center,"top_z":top,"toe_z":toe,
		"bed_y":bed,"water_z":wet,"extra":extra,"base_half":half_width}

static func map_z(x: float, z: float, section: Dictionary) -> float:
	var north := z < float(section.center_z)
	var side := -1.0 if north else 1.0
	var half_width: float = section.base_half
	var away := (z-float(section.center_z))*side
	var extra: float = section.extra.x if north else section.extra.y
	if extra <= 0 or away <= .6*half_width:
		return z
	var influence: float
	if away <= half_width:
		influence = inverse_lerp(.6*half_width,half_width,away)
	else:
		# 只伸展渠岸。平田上保留相同世界座標的底圖，場邊不動。
		influence = clampf((84.0-side*float(section.center_z)-away)/(84.0-side*float(section.center_z)-half_width),0,1)
	return z+side*extra*influence
