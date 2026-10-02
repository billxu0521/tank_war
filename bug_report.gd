class_name BugReport
extends Logger
## Bug 收集器：攔下 Godot 印出來的訊息和錯誤，記住最近的一段。
## 玩家按 F8（或 Esc 選單的「回報問題」）就把版本、電腦、遊戲狀況、錯誤和最近的紀錄
## 存成一個文字檔，同時複製到剪貼簿，貼到 Discord 那一版的討論串就好。
##
## Logger 的回呼可能從別的執行緒來，所以記錄都包在 mutex 裡；畫面上的提示由 main.gd 每幀來問 take_new_error()。
##
## ponytail: 只存檔＋複製，不自動上傳。要自動送就在 save() 之後加 HTTPRequest 送到 Discord webhook，
## 但 webhook 網址放在遊戲裡等於公開，要先想好被灌爆怎麼辦。
## 遊戲整個當掉時這裡來不及存——Godot 自己的 user://logs/godot.log 還在，報告裡會寫它在哪。

const KEEP_LINES := 200    # 最近幾行訊息
const KEEP_ERRORS := 30    # 最多記幾種錯誤（同一個錯誤只記一次、算次數）
const DIR := "user://bug_reports"

static var instance: BugReport

var _mutex := Mutex.new()
var _lines: Array[String] = []
var _errors := {}          # 錯誤的位置＋內容 -> {text, count, first}
var _new_error := false
var _started := Time.get_ticks_msec()


## 掛上去（重複呼叫沒關係：測試會開很多個 Main）
static func install() -> BugReport:
	if instance == null:
		instance = BugReport.new()
		OS.add_logger(instance)
	return instance


func _log_message(message: String, error: bool) -> void:
	_add_line(("[stderr] " if error else "") + message.strip_edges(false, true))


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind: String = ["錯誤", "警告", "腳本錯誤", "著色器錯誤"][clampi(error_type, 0, 3)]
	var what := rationale if rationale != "" else code
	var where := "%s:%d（%s）" % [file, line, function]
	_add_line("[%s] %s @ %s" % [kind, what, where])
	if error_type == ERROR_TYPE_WARNING:
		return   # 警告只進紀錄、不算錯誤（導航網格每局都會印兩行）
	var text := "[%s] %s\n    @ %s" % [kind, what, where]
	for bt in script_backtraces:
		text += "\n" + bt.format(4)
	_mutex.lock()
	var key := where + what
	if _errors.has(key):
		_errors[key].count += 1
	elif _errors.size() < KEEP_ERRORS:
		_errors[key] = {text = text, count = 1, first = _clock()}
		_new_error = true
	_mutex.unlock()


func _add_line(s: String) -> void:
	_mutex.lock()
	_lines.append("%s %s" % [_clock(), s])
	if _lines.size() > KEEP_LINES:
		_lines.remove_at(0)
	_mutex.unlock()


func _clock() -> String:
	var t := (Time.get_ticks_msec() - _started) / 1000
	return "%02d:%02d:%02d" % [t / 3600, t / 60 % 60, t % 60]


## 從上次問到現在有沒有新的錯誤（畫面上跳提示用）
func take_new_error() -> bool:
	_mutex.lock()
	var n := _new_error
	_new_error = false
	_mutex.unlock()
	return n


func error_count() -> int:
	_mutex.lock()
	var n := _errors.size()
	_mutex.unlock()
	return n


## 整份報告的文字。game_state 是 main.gd 填的遊戲狀況（模式、角色、連線）
func build(game_state: String, note := "") -> String:
	_mutex.lock()
	var errs := _errors.values()
	var lines := _lines.duplicate()
	_mutex.unlock()
	var out := PackedStringArray()
	out.append("== OvD 問題回報 ==")
	out.append("版本：%s　時間：%s" % [ProjectSettings.get_setting("application/config/version", "?"),
		Time.get_datetime_string_from_system(false, true)])
	out.append("電腦：%s %s　顯示卡：%s　語系：%s" % [OS.get_name(), OS.get_version(),
		RenderingServer.get_video_adapter_name(), OS.get_locale()])
	out.append("遊戲：" + game_state)
	out.append("開了多久：" + _clock())
	if note != "":
		out.append("玩家說明：" + note)
	out.append("")
	out.append("== 錯誤（%d 種）==" % errs.size())
	if errs.is_empty():
		out.append("（沒有記到錯誤）")
	for e: Dictionary in errs:
		out.append("%s 第一次，共 %d 次" % [e.first, e.count])
		out.append(e.text)
	out.append("")
	out.append("== 最近 %d 行紀錄 ==" % lines.size())
	out.append_array(lines)
	out.append("")
	out.append("遊戲當掉的話，完整紀錄在：" + ProjectSettings.globalize_path("user://logs"))
	return "\n".join(out)


## 存檔＋複製到剪貼簿，回傳存檔的完整路徑（失敗回傳空字串）
func save(game_state: String, note := "") -> String:
	var text := build(game_state, note)
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/OvD_%s.txt" % [DIR, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	DisplayServer.clipboard_set(text)
	return ProjectSettings.globalize_path(path)
