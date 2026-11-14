extends CanvasLayer

# On-screen stats panel (top left), the clock (top center), short messages (bottom center), sound captions (bottom
# left) and a "Saved" note. Once the hero has a watch (their first crossing), the clock is that watch's face beside
# the words (scripts/watch_face.gd, Settings > Display > Clock), and the check_watch key (T, D-pad down) holds it up
# big with what it says (scripts/time_watch.gd).
# Text size and high contrast follow Settings, and everything here is Settings.hud_size smaller or bigger (Small by
# default since Hayden's 7 Nov 2026 playtest said the screen was too busy).
#
# Under the stats, a little "To do" list: what to do right now for the quest being followed (Quests.objectives()).

var panel: PanelContainer
var stats_label: Label
var sparkle_label: Label                    # "✦ 12": sparkles, the money (scripts/game.gd)
var remnant_label: Label                    # "◆ 3 Remnants", the rarer crystal money, once there are any (scripts/remnants.gd)
var mp_bar: ProgressBar
var sp_bar: ProgressBar                     # stamina, spent by rolling
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var todo: PanelContainer                    # the to-do list
var todo_title: Label
var todo_list: VBoxContainer
var _has_todo := false
var _todo_key := ""                         # what the list shows now, so it's only rebuilt when that changes
var bar_labels: Array[Label] = []
var _last_hp := -1
var message_label: Label
var clock_panel: PanelContainer
var clock_label: Label                      # "Day 2   7:15 PM", plus "The Shift" from midnight to 1 AM
var watch_face: WatchFace                   # the hero's watch, beside the words (hidden until they have one)
var glance: PanelContainer                  # checking the watch: the big face and what it says
var glance_face: WatchFace
var glance_label: Label
var _glance_t := 0.0
const GLANCE_TIME := 6.0                    # seconds the big watch stays up
var saved_label: Label
var captions_box: VBoxContainer
var _saved_tween: Tween
var message_time := 0.0


func _ready() -> void:
	add_to_group("hud")                  # the voice in your mind sits under the clock (scripts/divine_mind.gd)
	panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	var v := VBoxContainer.new()
	panel.add_child(v)
	# Compact: the level and an XP bar on top, then HP, MP and SP as bars (the numbers are on the Hero sheet)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	stats_label = Label.new()
	stats_label.tooltip_text = "Your level. Fill the XP bar to go up a level"
	top.add_child(stats_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.tooltip_text = "XP: fill it up to go up a level"
	top.add_child(xp_bar)
	hp_bar = _bar_row(v, "HP", "HP: your health. Lose it all and you wake up at home")
	mp_bar = _bar_row(v, "MP", "MP: magic. A big Star Popper bubble (hold Shoot) takes 1. Refills over time")
	sp_bar = _bar_row(v, "SP", "SP: stamina, spent by rolling. Refills quickly")
	sparkle_label = Label.new()
	sparkle_label.tooltip_text = "Sparkles: bits of broken time. Find them round town, spend them at the market"
	v.add_child(sparkle_label)
	remnant_label = Label.new()
	remnant_label.name = "Remnants"
	remnant_label.tooltip_text = "Remnants: sparkles squeezed into crystals. Harvest them from the glowing veins with Bramble"
	v.add_child(remnant_label)
	add_child(panel)
	_build_todo()

	clock_panel = PanelContainer.new()
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_panel.offset_top = 16
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 10)
	clock_panel.add_child(clock_row)
	watch_face = WatchFace.new()
	watch_face.name = "WatchFace"
	watch_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	watch_face.tooltip_text = "Your watch. Press T (D-pad down) to check it"
	clock_row.add_child(watch_face)
	clock_label = Label.new()
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clock_row.add_child(clock_label)
	add_child(clock_panel)
	_build_glance()

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
	Remnants.changed.connect(_refresh_sparkles)
	Quests.changed.connect(func(_id: String) -> void: _refresh_sparkles())
	Game.message_posted.connect(_show_message)
	Quests.changed.connect(func(_id: String) -> void: _refresh_todo())
	Game.saved.connect(_on_saved)
	Clock.time_changed.connect(_refresh_clock)
	Game.equipment_changed.connect(_refresh_clock)
	Settings.changed.connect(_refresh_clock)
	Audio.caption.connect(_on_caption)
	# The subtitle banner sits where short messages go: keep messages out of the way while someone's talking
	Dialogue.started.connect(func(_id: String) -> void: message_label.visible = false)
	Dialogue.finished.connect(func(_id: String) -> void: message_label.visible = true)
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
	return Settings.hud(px)                 # text size times the HUD size (Settings > Display > Screen stuff size)


func _apply_look() -> void:
	var hc := Settings.high_contrast
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.1, 0.08, 0.15, 0.7)
	style.set_corner_radius_all(_fs(10))
	style.set_content_margin_all(_fs(8))
	if hc:
		style.border_color = Color(1, 1, 1)
		style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	clock_panel.add_theme_stylebox_override("panel", style)
	clock_label.add_theme_font_size_override("font_size", _fs(20))
	watch_face.custom_minimum_size = Vector2.ONE * _fs(58)
	if glance:
		glance.add_theme_stylebox_override("panel", style)
		glance_face.custom_minimum_size = Vector2.ONE * _fs(220)
		glance_label.add_theme_font_size_override("font_size", _fs(20))
		glance_label.add_theme_color_override("font_color", Color(1, 1, 1))
	clock_label.add_theme_color_override("font_color", Color(1, 1, 1))
	stats_label.add_theme_font_override("font", Dialogue.font)
	stats_label.add_theme_font_size_override("font_size", _fs(20))
	stats_label.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(1.0, 0.88, 0.45))
	sparkle_label.add_theme_font_override("font", Dialogue.font)
	sparkle_label.add_theme_font_size_override("font_size", _fs(18))
	sparkle_label.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(1.0, 0.88, 0.45))
	remnant_label.add_theme_font_override("font", Dialogue.font)
	remnant_label.add_theme_font_size_override("font_size", _fs(18))
	remnant_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6) if hc else Color(0.55, 1.0, 0.45))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.25, 0.25, 0.25) if hc else Color(0.2, 0.15, 0.3)
	back.set_corner_radius_all(4)
	var colors := [Color(1.0, 0.3, 0.5) if hc else Color(1.0, 0.45, 0.6),         # HP pink
		Color(0.2, 0.8, 1.0) if hc else Color(0.45, 0.6, 1.0),                   # MP blue
		Color(0.3, 1.0, 0.3) if hc else Color(0.62, 0.95, 0.35)]                 # SP lime
	for i in 3:
		var bar: ProgressBar = [hp_bar, mp_bar, sp_bar][i]
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[i]
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		bar.custom_minimum_size = Vector2(_fs(150), _fs(9))
		bar_labels[i].add_theme_font_size_override("font_size", _fs(14))
		bar_labels[i].add_theme_color_override("font_color", Color(1, 1, 1))
		bar_labels[i].custom_minimum_size.x = _fs(28)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(1, 1, 0.5) if hc else Color(1.0, 0.85, 0.35)
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.add_theme_stylebox_override("background", back)
	xp_bar.custom_minimum_size = Vector2(_fs(100), _fs(7))
	_style_todo(style)
	for l in [message_label, saved_label]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0) if hc else Color(0.1, 0.05, 0.15))
		l.add_theme_constant_override("outline_size", 14 if hc else 8)
		l.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(1, 1, 1))
	message_label.add_theme_font_override("font", Dialogue.font)     # same comic lettering as the subtitles
	message_label.add_theme_font_size_override("font_size", _fs(26))
	saved_label.add_theme_font_size_override("font_size", _fs(16))
	var w := float(_fs(820))
	if Settings.minimap:
		# Clear of the round minimap in the bottom-right corner (scripts/map_screen.gd), both sides so it stays centred
		var vp := get_viewport().get_visible_rect().size.x if is_inside_tree() else 1280.0
		w = minf(w, vp - 2.0 * ((TownMap.MINI_SIZE + TownMap.MINI_RING * 2.0) * Settings.hud_size + 32.0))
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
	stats_label.text = "Lv %d" % Game.level
	xp_bar.max_value = maxi(Game.xp_to_next(), 1)
	xp_bar.value = Game.xp
	hp_bar.max_value = Game.max_hp
	hp_bar.value = Game.hp
	hp_bar.tooltip_text = "HP: your health (%d of %d)" % [Game.hp, Game.max_hp]
	mp_bar.max_value = Game.max_mp
	mp_bar.value = Game.mp
	_refresh_sp()
	_refresh_sparkles()


func _refresh_sparkles() -> void:
	sparkle_label.text = "✦ %d sparkle%s" % [Game.sparkles, "" if Game.sparkles == 1 else "s"]
	remnant_label.visible = Remnants.shown()
	remnant_label.text = Remnants.words(Remnants.count)


# -----------------------------------------------------------------------------
# The to-do list
# -----------------------------------------------------------------------------
func _build_todo() -> void:
	todo = PanelContainer.new()
	todo.name = "ToDo"
	todo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	todo.add_child(v)
	todo_title = Label.new()
	v.add_child(todo_title)
	todo_list = VBoxContainer.new()
	todo_list.add_theme_constant_override("separation", 0)
	v.add_child(todo_list)
	todo.visible = false
	add_child(todo)
	# Fit it again whenever its rows change, even while the game's paused under a menu (no _process then)
	todo.minimum_size_changed.connect(_fit_todo, CONNECT_DEFERRED)


func _style_todo(style: StyleBoxFlat) -> void:
	var s := style.duplicate() as StyleBoxFlat
	if not Settings.high_contrast:
		s.bg_color = Color(0.1, 0.08, 0.15, 0.55)
	todo.add_theme_stylebox_override("panel", s)
	todo_title.add_theme_font_override("font", Dialogue.font)
	todo_title.add_theme_font_size_override("font_size", _fs(17))
	todo_title.add_theme_color_override("font_color", Color(1, 1, 0.6) if Settings.high_contrast else UiStyle.GOLD)
	todo_title.add_theme_color_override("font_outline_color", UiStyle.INK)
	todo_title.add_theme_constant_override("outline_size", _fs(5))
	_todo_key = ""                              # rebuild the rows at the new size
	_refresh_todo()


func todo_items() -> Array:
	# What the list says now: the lines as shown (for tests)
	var out: Array = []
	for row in todo_list.get_children():
		if str(row.get_meta("text", "")) != "":           # (not the name over a second followed quest)
			out.append(row.get_meta("text", ""))
	return out


func _refresh_todo() -> void:
	if todo == null:
		return
	# One block for each thing the player follows (Quests.objectives_all(): quests and board jobs, up to three)
	var all: Array = Quests.objectives_all() if Settings.objectives else []
	var key := str(all)
	if key == _todo_key:
		return
	_todo_key = key
	for c in todo_list.get_children():
		c.queue_free()
		todo_list.remove_child(c)
	_has_todo = not all.is_empty()
	if all.is_empty():
		return
	todo_title.text = "To do: %s" % all[0].name
	for i in all.size():
		var o: Dictionary = all[i]
		if i > 0:
			var head := Label.new()
			head.set_meta("text", "")
			head.text = o.name
			head.add_theme_font_override("font", Dialogue.font)
			head.add_theme_font_size_override("font_size", _fs(15))
			head.add_theme_color_override("font_color", UiStyle.GOLD)
			head.add_theme_color_override("font_outline_color", UiStyle.INK)
			head.add_theme_constant_override("outline_size", _fs(4))
			todo_list.add_child(head)
		_todo_rows(o)


func _todo_rows(o: Dictionary) -> void:
	for item in o.items:
		var row := HBoxContainer.new()
		row.set_meta("text", str(item[0]))
		row.add_theme_constant_override("separation", _fs(6))
		var tick := Label.new()
		tick.text = "●" if item[1] else "○"
		tick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var l := Label.new()
		l.text = str(item[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = _fs(230)
		for x in [tick, l]:
			x.add_theme_font_override("font", Dialogue.font)
			x.add_theme_font_size_override("font_size", _fs(16))
			x.add_theme_color_override("font_outline_color", UiStyle.INK)
			x.add_theme_constant_override("outline_size", _fs(4))
			x.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6, 0.85) if item[1] else Color(1, 1, 1))
		row.add_child(tick)
		row.add_child(l)
		todo_list.add_child(row)


func _fit_todo() -> void:
	# Three followed quests with long checklists, at a big text size, made the list run off the bottom of the screen
	# (Hayden, 14 Nov 2026: "check every single windowed text in the game and make sure nothing is getting cut off").
	# It shrinks from its top left corner to fit the room left under the stats instead.
	var room := get_viewport().get_visible_rect().size.y / maxf(scale.y, 0.01) - todo.position.y - 12.0
	var need := todo.get_combined_minimum_size().y
	todo.size = Vector2.ZERO                    # back to what its rows need (a box never shrinks by itself after a long list)
	var k := clampf(room / maxf(need, 1.0), 0.3, 1.0)
	todo.pivot_offset = Vector2.ZERO
	todo.scale = Vector2(k, k)


func _fit_clock() -> void:
	# The clock sits in the top middle, but at a big HUD and text size it's wide enough to cover the stats in the corner:
	# then it moves right, clear of them, and shrinks if there still isn't room before the screen's edge
	var vp := get_viewport().get_visible_rect().size
	var w := clock_panel.size.x
	var clear := panel.position.x + panel.size.x + 10.0
	var x := maxf((vp.x - w) / 2.0, clear)
	var room := vp.x - 16.0 - x
	var k := clampf(room / maxf(w, 1.0), 0.5, 1.0)
	clock_panel.offset_left = x - vp.x / 2.0
	clock_panel.offset_right = clock_panel.offset_left + w
	clock_panel.pivot_offset = Vector2.ZERO
	clock_panel.scale = Vector2(k, k)


func _refresh_clock() -> void:
	# On Earth, the day of the week, Earth's time and when the portal opens; in the Void, its own day and time, and Earth's crawling clock
	var text := "Day %d     %s" % [Clock.day, Clock.time_string()]
	if Clock.on_earth:
		text = "Earth, %s     %s" % [Clock.date_string(), Clock.earth_time_string()]
		# Nothing about the portal until they've seen the old oak open for themselves (Hayden's day 1 playtest, 11 Nov
		# 2026: the game mustn't give away what's going to happen)
		if HummingOak.awake():
			text += "\n" + ("The Shift! The Void: %s" % Clock.time_string() if Clock.in_shift() else "The crack opens at midnight")
	elif Clock.in_shift():
		text += "\nThe Shift (Earth %s)" % Clock.earth_time_string()
	clock_label.text = text
	# The watch face once they've got one; the words unless they've picked "Just the watch" (Settings > Display)
	var watch := TimeWatch.has_watch() and Settings.clock_style != "words"
	watch_face.visible = watch
	clock_label.visible = not watch or Settings.clock_style != "watch"
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
	l.add_theme_font_override("font", Dialogue.font)
	l.add_theme_font_size_override("font_size", _fs(20))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", _fs(6))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0, 0, 0, 0.6)
	s.set_content_margin_all(6)
	s.set_corner_radius_all(6)
	l.add_theme_stylebox_override("normal", s)
	l.add_theme_color_override("font_color", Color(1, 1, 1))


# -----------------------------------------------------------------------------
# Checking the watch
# -----------------------------------------------------------------------------
func _build_glance() -> void:
	glance = PanelContainer.new()
	glance.name = "WatchGlance"
	glance.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glance.grow_horizontal = Control.GROW_DIRECTION_BOTH
	glance.grow_vertical = Control.GROW_DIRECTION_BOTH
	glance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glance.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	glance.add_child(row)
	glance_face = WatchFace.new()
	glance_face.big = true
	glance_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glance_face)
	glance_label = Label.new()
	glance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glance_label.custom_minimum_size.x = 380
	glance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(glance_label)
	add_child(glance)


func check_watch() -> void:
	# Hold the watch up (or put it away if it's up)
	if glance.visible:
		_glance_t = 0.0
		glance.visible = false
		return
	if not TimeWatch.has_watch():
		Game.message("You haven't got a watch yet. Something tells you one will turn up...")
		return
	glance_label.text = "\n".join(TimeWatch.lines())
	glance.visible = true
	_glance_t = GLANCE_TIME
	Audio.play("pickup", -14.0, 0.0)
	Juice.rumble(0.12, 0.08)


func _can_check_watch() -> bool:
	return not get_tree().paused and not Dialogue.is_active() and not Shop.is_open()


func _process(delta: float) -> void:
	# The to-do list sits just under the stats (their height changes with the text size), and checks itself now and
	# then: checklist ticks are flags, which don't say when they change
	todo.position = Vector2(panel.position.x, panel.position.y + panel.size.y + _fs(6))
	_fit_todo()
	_fit_clock()
	if Engine.get_process_frames() % 20 == 0:
		_refresh_todo()
	todo.visible = _has_todo and not Dialogue.is_active()
	if InputMap.has_action("check_watch") and Input.is_action_just_pressed("check_watch") and _can_check_watch():
		check_watch()
	if _glance_t > 0.0:
		_glance_t -= delta
		if Engine.get_process_frames() % 30 == 0:
			glance_label.text = "\n".join(TimeWatch.lines())
		glance.modulate.a = clampf(_glance_t / 0.4, 0.0, 1.0)
		if _glance_t <= 0.0:
			glance.visible = false
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
