class_name Balance
extends Object
## 平衡數字（balance.csv）。企劃用 Excel 打開改「值」欄、存成 CSV UTF-8、開合併請求。
## 改完重開遊戲生效。表打包進 pck，打包後不能改，要重新打包。
## ponytail: 打包後不能改表；要在打包版上調，改成主機讀執行檔旁的覆寫檔、整張表送客戶端

const TABLE := "res://balance.csv"
static var _vals := {}   # 參數 -> 值（文字）
static var missing: Array[String] = []   # 查不到的參數名；正常應該是空的

static func _load() -> void:
	if not _vals.is_empty():
		return
	var f := FileAccess.open(TABLE, FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()   # 標題列
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 4 or row[0].strip_edges() == "":
			continue
		_vals[row[0].strip_edges()] = row[3].strip_edges()

static func num(key: String) -> float:
	_load()
	if not _vals.has(key):
		push_error("數值表 balance.csv 沒有 %s" % key)
		if not missing.has(key):
			missing.append(key)
		return 0.0
	return float(_vals[key])

static func whole(key: String) -> int:
	return roundi(num(key))

## 連線版本檢查用：數值表和武器表的雜湊前 8 碼，兩邊不同就擋
static func digest() -> String:
	return (FileAccess.get_md5(TABLE) + FileAccess.get_md5(Weapon.TABLE)).md5_text().left(8)
