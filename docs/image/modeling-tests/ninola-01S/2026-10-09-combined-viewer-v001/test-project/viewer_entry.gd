extends ModelViewer
var eval_badge: Label
func _ready() -> void:
	var th := Theme.new()
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["PingFang TC", "Heiti TC", "Arial"])
	th.default_font = sys
	use_theme(th)
	super._ready()
	eval_badge = Label.new()
	eval_badge.position = Vector2(24,72)
	eval_badge.text = "B體態＋1.5°閉合候選｜T：原版／候選比較"
	eval_badge.add_theme_color_override("font_color",Color(1,.85,.4))
	_ui.add_child(eval_badge)
	closed.connect(func(): get_tree().quit())
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../viewer_open.png"))
		print("NINOLA_COMBINED_VIEWER_READY B + 1.5deg")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_trex.eval_changes_enabled = not _trex.eval_changes_enabled
		DisplayServer.window_set_title("Ninola — "+("B + 1.5 deg candidate" if _trex.eval_changes_enabled else "R2 v005 original"))
		eval_badge.text = "B體態＋1.5°闭合候選｜T：切換原版" if _trex.eval_changes_enabled else "R2 v005 原版姿態｜T：切換候選"
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
