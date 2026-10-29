extends CanvasLayer

# On-screen stats panel (top left), the clock (top center), short messages (bottom center), sound captions (bottom
# left) and a "Saved" note.
# Text size and high contrast follow Settings.

var panel: PanelContainer
var stats_label: Label
var sparkle_label: Label                    # "✦ 12": sparkles, the money (scripts/game.gd)
var mp_bar: ProgressBar
var sp_bar: ProgressBar                     # stamina, spent by rolling
var bar_labels: Array[Label] = []
var _last_hp := -1
var message_label: Label
var clock_panel: PanelContainer
var clock_label: Label                      # "Day 2   7:15 PM", plus "The Shift" from midnight to 1 AM
var saved_label: Label
var captions_box: VBoxContainer
var _saved_tween: Tween
var message_time := 0.0


func _ready() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	var v := VBoxContainer.new()
	panel.add_child(v)
	stats_label = Label.new()
	v.add_child(stats_label)
	mp_bar = _bar_row(v, "MP", "MP: magic, for abilities to come. Refills over time")
	sp_bar = _bar_row(v, "SP", "SP: stamina, spent by rolling. Refills quickly")
	sparkle_label = Label.new()
	sparkle_label.tooltip_text = "Sparkles: bits of broken time. Find them round town, spend them at the market"
	v.add_child(sparkle_label)
	add_child(panel)

	clock_panel = PanelContainer.new()
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_panel.offset_top = 16
	clock_label = Label.new()
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_panel.add_child(clock_label)
	add_child(clock_panel)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(message_label)

	captions_box = VBoxContainer.new()
	captions_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	captions_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	captions_box.offset_left = 20
	captions_box.offset_bottom = -20
	add_child(captions_box)

	saved_label = Label.new()
	saved_label.text = "Saved"
	saved_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	saved_label.offset_right = -16
	saved_label.offset_top = 16
	saved_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved_label.modulate.a = 0.0
	add_child(saved_label)

	Game.stats_changed.connect(_refresh)
	Game.sp_changed.connect(_refresh_sp)
	Game.sparkles_changed.connect(_refresh_sparkles)
	Game.message_posted.connect(_show_message)
	Game.saved.connect(_on_saved)
	Clock.time_changed.connect(_refresh_clock)
	Audio.caption.connect(_on_caption)
	Settings.changed.connect(_apply_look)
	_apply_look()
	_refresh()
	_refresh_sp()
	_refresh_clock()
	_show_pending.call_deferred()


func _bar_row(parent: Control, label_text: String, tip: String) -> ProgressBar:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	row.add_child(l)
	bar_labels.append(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.tooltip_text = tip
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	parent.add_child(row)
	return bar


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _apply_look() -> void:
	var hc := Settings.high_contrast
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.1, 0.08, 0.15, 0.7)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	if hc:
		style.border_color = Color(1, 1, 1)
		style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	clock_panel.add_theme_stylebox_override("panel", style)
	clock_label.add_theme_font_size_override("font_size", _fs(20))
	clock_label.add_theme_color_override("font_color", Color(1, 1, 1))
	stats_label.add_theme_font_size_override("font_size", _fs(20))
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1))
	sparkle_label.add_theme_font_size_override("font_size", _fs(20))
	sparkle_label.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(1.0, 0.88, 0.45))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.25, 0.25, 0.25) if hc else Color(0.2, 0.15, 0.3)
	back.set_corner_radius_all(4)
	var colors := [Color(0.2, 0.8, 1.0) if hc else Color(0.45, 0.6, 1.0),        # MP blue
		Color(0.3, 1.0, 0.3) if hc else Color(0.62, 0.95, 0.35)]                 # SP lime
	for i in 2:
		var bar: ProgressBar = [mp_bar, sp_bar][i]
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[i]
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		bar.custom_minimum_size = Vector2(_fs(170), _fs(10))
		bar_labels[i].add_theme_font_size_override("font_size", _fs(14))
		bar_labels[i].add_theme_color_override("font_color", Color(1, 1, 1))
		bar_labels[i].custom_minimum_size.x = _fs(28)
	for l in [message_label, saved_label]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0) if hc else Color(0.1, 0.05, 0.15))
		l.add_theme_constant_override("outline_size", 14 if hc else 8)
		l.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(1, 1, 1))
	message_label.add_theme_font_size_override("font_size", _fs(24))
	saved_label.add_theme_font_size_override("font_size", _fs(16))
	var w := _fs(820)
	message_label.offset_left = -w / 2.0
	message_label.offset_right = w / 2.0
	message_label.offset_bottom = -40
	message_label.offset_top = -40 - _fs(64)
	for c in captions_box.get_children():
		_style_caption(c)


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
	if _last_hp >= 0 and Game.hp < _last_hp and not Settings.reduce_flashing:   # flash red when she gets hurt
		panel.modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(panel, "modulate", Color.WHITE, 0.5)
	_last_hp = Game.hp
	stats_label.text = "Lv %d    XP %d/%d\nHP %d/%d    MP %d/%d\nMP Lv %d" % [Game.level, Game.xp, Game.xp_to_next(),
		Game.hp, Game.max_hp, Game.mp, Game.max_mp, Game.mp_level]
	mp_bar.max_value = Game.max_mp
	mp_bar.value = Game.mp
	_refresh_sp()
	_refresh_sparkles()


func _refresh_sparkles() -> void:
	sparkle_label.text = "✦ %d sparkle%s" % [Game.sparkles, "" if Game.sparkles == 1 else "s"]


func _refresh_clock() -> void:
	# On Earth, Earth's time and when the portal opens; in Galaxity, its own day and time, and Earth's crawling clock
	var text := "Day %d     %s" % [Clock.day, Clock.time_string()]
	if Clock.on_earth:
		text = "Earth     %s\n%s" % [Clock.earth_time_string(),
			"The Shift! Galaxity: %s" % Clock.time_string() if Clock.in_shift() else "The portal opens at midnight"]
	elif Clock.in_shift():
		text += "\nThe Shift (Earth %s)" % Clock.earth_time_string()
	clock_label.text = text
	var shift_tint := Color(1.0, 0.8, 1.0) if Settings.high_contrast else Color(0.9, 0.7, 1.0)
	clock_label.add_theme_color_override("font_color", shift_tint if Clock.in_shift() else Color(1, 1, 1))


func _refresh_sp() -> void:
	sp_bar.max_value = Game.max_sp
	sp_bar.value = Game.sp


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_time = 3.0 + 0.04 * text.length()          # longer messages stay up longer


func _on_caption(text: String) -> void:
	if not Settings.captions:
		return
	var l := Label.new()
	l.text = text
	_style_caption(l)
	captions_box.add_child(l)
	while captions_box.get_child_count() > 4:
		captions_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _style_caption(l: Label) -> void:
	var hc := Settings.high_contrast
	l.add_theme_font_size_override("font_size", _fs(18))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0, 0, 0, 0.6)
	s.set_content_margin_all(6)
	s.set_corner_radius_all(6)
	l.add_theme_stylebox_override("normal", s)
	l.add_theme_color_override("font_color", Color(1, 1, 1))


func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
