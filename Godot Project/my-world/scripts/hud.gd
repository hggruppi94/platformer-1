extends CanvasLayer

# On-screen stats panel (top left) and short messages (bottom center).

var stats_label: Label
var message_label: Label
var message_time := 0.0


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.7)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(stats_label)
	add_child(panel)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_top = -90
	message_label.offset_bottom = -40
	message_label.offset_left = -400
	message_label.offset_right = 400
	add_child(message_label)

	Game.stats_changed.connect(_refresh)
	Game.message_posted.connect(_show_message)
	_refresh()


func _refresh() -> void:
	stats_label.text = "Lv %d    XP %d/%d\nHP %d/%d    MP %d/%d\nMP Lv %d" % [Game.level, Game.xp, Game.xp_to_next(),
		Game.hp, Game.max_hp, Game.mp, Game.max_mp, Game.mp_level]


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_time = 3.0


func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
