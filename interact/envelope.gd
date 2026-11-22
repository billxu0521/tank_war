class_name Envelope
extends StaticBody3D
## 信封（docs/企劃/2026-11-12-保險箱與號碼牌.md 第 1、2、8 項）：派對保險箱模式每回合兩個，0 號是十位數（白底黑字）、1 號是個位數（黑底白字）。
## 牛仔看著按 F 請主機看牌（party.read_envelope），主機只把數字回給他一個人。牌不會被拿走，別人可以再來看。
## 這裡只有外觀和按 F：位置、開過沒都是 party 那包（env_pos、env_open）的公開狀態，party._process 每幀套過來。
## 數字不在這裡（只有主機的 party._known 和自己的 party.my_digits）。沒有 take_damage：打不壞。

const RANGE := 3.0   # 牛仔離信封多遠（水平）還能看
const NAMES := ["十位數", "個位數"]

var index := 0
var cover: Array = []   # 團隊模式：這封蓋到哪幾位（Team.cover_of，每位 2 確定、1 候選、0 沒有）。派對是 []
var opened := false   # 有人看過（公開）
var party: Node
var _card: StandardMaterial3D
var _label: Label3D

## 看著信封時畫面上的提示（cowboy.gd 讀這個）
var prompt: String:
	get:
		if not cover.is_empty():
			return "信封 %s%s" % [Team.cover_text(cover), "（你們隊看過了）" if opened else "：看信"]
		var mine: bool = party != null and int(party.my_digits[index]) >= 0
		return "%s的牌：%d" % [NAMES[index], party.my_digits[index]] if mine else "看%s的牌" % NAMES[index]


func _ready() -> void:
	# ponytail: 立著的一張牌當外觀（站著看得到、準心對得到），正式模型第 5 步再換
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.8, 0.06)
	_card = StandardMaterial3D.new()
	bm.material = _card
	mi.mesh = bm
	mi.position = Vector3(0, 1.0, 0)
	add_child(mi)
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.004
	_label.position = Vector3(0, 1.0, 0.04)
	_label.outline_size = 0
	add_child(_label)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 1.4, 0.3)
	shape.shape = bs
	shape.position = Vector3(0, 0.7, 0)
	add_child(shape)
	Accent.mark(self)
	set_opened(false)


## 開過的樣子：牌變灰、寫「已開」（每台照公開狀態換）
func set_opened(v: bool) -> void:
	opened = v
	if not cover.is_empty() or index >= NAMES.size():   # 團隊模式：米色的牌，寫三個方格（看得出蓋到哪幾位）
		_card.albedo_color = Color(0.95, 0.9, 0.75).lerp(Color(0.5, 0.45, 0.4), 0.5) if v else Color(0.95, 0.9, 0.75)
		_label.modulate = Color.BLACK
		_label.text = "百十個\n" + Team.cover_text(cover) + ("\n（看過了）" if v else "")
		return
	var bg := Color.WHITE if index == 0 else Color.BLACK
	var fg := Color.BLACK if index == 0 else Color.WHITE
	_card.albedo_color = bg.lerp(Color(0.5, 0.45, 0.4), 0.5) if v else bg
	_label.modulate = fg
	_label.text = NAMES[index] + ("\n（已開）" if v else "")


func interact(who: Node) -> void:
	if party != null and who == party.main._me():
		party.read_envelope(index)
