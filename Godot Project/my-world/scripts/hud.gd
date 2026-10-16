extends CanvasLayer

# On-screen stats panel (top left) and short messages (bottom center).

var panel: PanelContainer
var stats_label: Label
var _last_hp := -1
var message_label: Label
var saved_label: Label
var _saved_tween: Tween
var message_time := 0.0


func _ready() -> void:
	panel = PanelContainer.new()
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
	_show_pending.call_deferred()

	saved_label = Label.new()
	saved_label.text = "Saved"
	saved_label.add_theme_font_size_override("font_size", 16)
	saved_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	saved_label.add_theme_constant_override("outline_size", 6)
	saved_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	saved_label.offset_left = -90
	saved_label.offset_top = 16
	saved_label.offset_right = -16
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved_label.modulate.a = 0.0
	add_child(saved_label)
	Game.saved.connect(_on_saved)


func _show_pending() -> void:
	# Deferred so that on startup it waits until Nina is where the save put her
	if Game.pending_message != "" and not Game.is_resuming():
		_show_message(Game.pending_message)
		Game.pending_message = ""


func _on_saved() -> void:
	if _saved_tween:
		_saved_tween.kill()                       # a save during the last fade-out restarts it
	saved_label.modulate.a = 0.85
	_saved_tween = create_tween()
	_saved_tween.tween_interval(0.8)
	_saved_tween.tween_property(saved_label, "modulate:a", 0.0, 0.6)


func _refresh() -> void:
	if _last_hp >= 0 and Game.hp < _last_hp:          # flash the panel red when she gets hurt
		panel.modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(panel, "modulate", Color.WHITE, 0.5)
	_last_hp = Game.hp
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
