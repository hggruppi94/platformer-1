extends CanvasLayer

# Autoload "PauseMenu": Esc / P / Start pauses the game.
#   Paused:   Resume · Settings · New Game · Quit
#   Settings: Audio · Controls · Display · Accessibility · Assist   (all saved by scripts/settings.gd)
# Works with mouse, keyboard (arrows/Tab + Enter) and controller (d-pad/stick + A, B to go back).

var root: Control
var box: VBoxContainer                 # the centre panel's contents; rebuilt for each page
var panel: PanelContainer
var page := ""
var _tab := 0
var _rebinding := ""                   # action waiting for a key press
var _rebind_label: Label
var _suppress_sound := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	Settings.changed.connect(_apply_theme)
	_apply_theme()


func is_open() -> bool:
	return root.visible


# ----------------------------------------------------------------------------- open / close
func open() -> void:
	if is_open() or get_tree().paused:
		return                                     # already paused by something else, e.g. sleeping in a bed
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()
	Audio.play("ui_accept", -4.0, 0.0)


func close() -> void:
	if not is_open():
		return
	_rebinding = ""
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.play("ui_back", -4.0, 0.0)


func _input(event: InputEvent) -> void:
	# Key capture for rebinding comes first, before anything else can react to the key
	if _rebinding != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE and _rebinding != "pause":
			_rebinding = ""
			_show_settings()
			return
		var action := _rebinding
		_rebinding = ""
		var clash := Settings.rebind(action, event.physical_keycode)
		_show_settings()
		if clash != "":
			_toast("%s was on that key too, so it moved to %s." % [Settings.action_label(clash), Settings.key_name(clash)])
		return
	if _rebinding != "":
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if Quests.is_log_open():
			Quests.toggle_log()                    # Pause closes the quest log or the map first
		elif TownMap.is_open():
			TownMap.toggle()
		elif Shop.is_open():
			Shop.close()
		elif not is_open():
			open()
		elif page == "main":
			close()
		else:
			_back()
	elif is_open() and event.is_action_pressed("ui_cancel") and not event is InputEventKey:
		get_viewport().set_input_as_handled()      # controller B: back out of a page
		if page == "main":
			close()
		else:
			_back()


func _back() -> void:
	if page in ["settings", "confirm"]:
		_show_main()
	else:
		close()
	Audio.play("ui_back", -4.0, 0.0)


# ----------------------------------------------------------------------------- pages
func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", _fs(36) if Settings.text_scale < 1.5 else _fs(28))
	box.add_child(l)
	return l


func _button(text: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(_fs(320), _fs(46))
	b.pressed.connect(func():
		Audio.play("ui_accept", -4.0, 0.0)
		cb.call())
	b.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
	(parent if parent else box).add_child(b)
	return b


func _show_main() -> void:
	page = "main"
	_clear()
	_title("Paused")
	var first := _button("Resume", close)
	var here := get_tree().current_scene
	if here and here.scene_file_path == "res://scenes/scary_world/scary_world.tscn":
		_button("Go home to town", func():                 # the Scary World: an easy way out, any time
			close()
			Game.go(Game.TOWN_SCENE, "FromScaryWorld", "town"))
	if here and here.scene_file_path == "res://scenes/earth/earth.tscn":
		_button("Go back through the portal", func():     # Earth: home before the Shift ends, any time
			close()
			Game.go(Game.TOWN_SCENE, "FromPortaltoEarth", "home"))
	_button("Settings", func(): _tab = 0; _show_settings())
	_button("New Game", _show_confirm)
	_button("Quit", _quit)
	_focus(first)


func _show_confirm() -> void:
	page = "confirm"
	_clear()
	_title("Start a new game?")
	var l := Label.new()
	l.text = "This erases your saved progress:\nlevel, XP and items."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var keep := _button("No, keep playing", _show_main)
	_button("Yes, start over", func():
		close()
		Game.new_game())
	_focus(keep)


func _quit() -> void:
	Game.save_game()
	get_tree().quit()


func _focus(c: Control) -> void:
	_suppress_sound = true
	c.grab_focus()
	_suppress_sound = false


# ----------------------------------------------------------------------------- settings
func _show_settings() -> void:
	page = "settings"
	_clear()
	_title("Settings")
	var tabs := TabContainer.new()
	var vp := get_viewport().get_visible_rect().size
	# Fit the screen at any text size; the tab pages scroll when their contents are taller
	tabs.custom_minimum_size = Vector2(minf(_fs(620), vp.x - 120), minf(_fs(430), vp.y - _fs(40) - _fs(46) - 150))
	box.add_child(tabs)
	_tab_audio(tabs)
	_tab_controls(tabs)
	_tab_display(tabs)
	_tab_access(tabs)
	_tab_assist(tabs)
	tabs.current_tab = _tab
	tabs.tab_changed.connect(func(i): _tab = i; Audio.play("ui_move", -8.0, 0.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var back := _button("Back", _show_main, row)
	back.custom_minimum_size.x = _fs(200)
	var reset := _button("Reset to defaults", func(): Settings.reset_to_defaults(); _show_settings(), row)
	reset.custom_minimum_size.x = _fs(260)
	_focus(tabs.get_tab_bar())


func _grid(tabs: TabContainer, name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(g)
	return g


func _label(g: GridContainer, text: String, hint := "") -> void:
	var l := Label.new()
	l.text = text
	l.tooltip_text = hint
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(l)


func _slider(g: GridContainer, text: String, prop: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	_label(g, text)
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = _fs(280)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Settings.get(prop)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Label.new()
	v.custom_minimum_size.x = _fs(64)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = fmt.call(s.value)
	s.value_changed.connect(func(x):
		v.text = fmt.call(x)
		Settings.set_value(prop, x))
	s.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
	row.add_child(s)
	row.add_child(v)
	g.add_child(row)


func _check(g: GridContainer, text: String, prop: String, hint := "") -> void:
	# A wide On/Off button (clearer than a small switch, and easy to hit with any input)
	_label(g, text, hint)
	var c := Button.new()
	c.toggle_mode = true
	c.button_pressed = Settings.get(prop)
	c.text = "On" if c.button_pressed else "Off"
	c.tooltip_text = hint
	c.custom_minimum_size = Vector2(_fs(110), _fs(38))
	c.toggled.connect(func(on):
		c.text = "On" if on else "Off"
		Audio.play("ui_accept", -6.0, 0.0)
		Settings.set_value(prop, on))
	c.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
	g.add_child(c)


func _choice(g: GridContainer, text: String, prop: String, options: Array, hint := "") -> void:
	# options: [[label, value], ...]
	_label(g, text, hint)
	var o := OptionButton.new()
	o.tooltip_text = hint
	var current = Settings.get(prop)
	for i in options.size():
		o.add_item(options[i][0], i)
		if is_equal_approx(float(options[i][1]), float(current)):
			o.select(i)
	o.item_selected.connect(func(i):
		Audio.play("ui_accept", -6.0, 0.0)
		Settings.set_value(prop, options[i][1])
		if prop == "text_scale":
			_show_settings.call_deferred())          # rebuild at the new size
	g.add_child(o)


func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100)


func _tab_audio(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Audio")
	_slider(g, "Master volume", "master_volume", 0, 1, 0.05, _pct)
	_slider(g, "Music volume", "music_volume", 0, 1, 0.05, _pct)
	_slider(g, "Sound effects volume", "sfx_volume", 0, 1, 0.05, _pct)


func _tab_controls(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Controls")
	_slider(g, "Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.1, func(x): return "%.1fx" % x)
	_slider(g, "Controller look speed", "stick_sensitivity", 0.2, 3.0, 0.1, func(x): return "%.1fx" % x)
	_check(g, "Invert camera up/down", "invert_y")
	_check(g, "Invert camera left/right", "invert_x")
	var head := Label.new()
	head.text = "Keys (click, then press a new key)"
	head.add_theme_font_size_override("font_size", _fs(20))
	g.add_child(head)
	g.add_child(Control.new())
	for pair in Settings.REBINDABLE:
		var action: String = pair[0]
		_label(g, pair[1])
		var b := Button.new()
		b.text = Settings.key_name(action)
		b.custom_minimum_size = Vector2(_fs(160), _fs(38))
		b.pressed.connect(func(): _start_rebind(action, b))
		b.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
		g.add_child(b)
	var pad := Label.new()
	pad.text = "Controller: left stick move · right stick camera · A jump (again in the air to double jump) · X or RB roll · Y skateboard · Start pause"
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad.custom_minimum_size.x = _fs(560)
	pad.add_theme_font_size_override("font_size", _fs(16))
	g.add_child(pad)


func _start_rebind(action: String, b: Button) -> void:
	_rebinding = action
	b.text = "Press a key..."
	_toast("Press the new key for %s%s" % [Settings.action_label(action), "" if action == "pause" else " (Esc to cancel)"])


func _tab_display(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Display")
	_check(g, "Fullscreen", "fullscreen")
	_slider(g, "Field of view", "fov", 60, 100, 1, func(x): return "%d°" % x)
	_check(g, "Corner minimap", "minimap", "A small map in the bottom-right corner (%s opens the big one)" % Settings.key_name("map"))


func _tab_access(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Accessibility")
	_choice(g, "Text size", "text_scale", [["Normal", 1.0], ["Large", 1.25], ["Larger", 1.5], ["Largest", 2.0]],
		"Size of the on-screen stats, messages, captions and these menus")
	_check(g, "High-contrast HUD", "high_contrast", "Solid dark panels, bright text and heavy outlines")
	_check(g, "Sound captions", "captions", "Shows text for important sounds, like a Gloop giggling nearby")
	_check(g, "Reduce flashing", "reduce_flashing", "No blinking or red flashes when hurt; calmer glowing effects")
	_check(g, "Reduce motion", "reduce_motion", "No camera kick when rolling; calmer bobbing and shimmering")


func _tab_assist(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Assist")
	_choice(g, "Game speed", "game_speed", [["100%", 1.0], ["90%", 0.9], ["75%", 0.75], ["60%", 0.6]],
		"Slows the whole game down to give you more time to react")
	_check(g, "No damage", "no_damage", "Enemies still bump you, but you never lose HP")
	_check(g, "Infinite stamina", "infinite_sp", "Rolling never runs out of SP")


# ----------------------------------------------------------------------------- look
func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _toast(text: String) -> void:
	if _rebind_label == null or not is_instance_valid(_rebind_label):
		_rebind_label = Label.new()
		_rebind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rebind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rebind_label.custom_minimum_size.x = _fs(560)
	if _rebind_label.get_parent() != box:
		box.add_child(_rebind_label)
	_rebind_label.text = text


func _apply_theme() -> void:
	var t := Theme.new()
	var hc := Settings.high_contrast
	t.default_font_size = _fs(22)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.97) if hc else Color(0.13, 0.08, 0.22, 0.95)
	bg.set_corner_radius_all(14)
	bg.border_color = Color(1, 1, 1) if hc else Color(0.55, 0.4, 0.9)
	bg.set_border_width_all(3 if hc else 2)
	t.set_stylebox("panel", "PanelContainer", bg)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.1) if hc else Color(0.25, 0.16, 0.42)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(8)
	normal.border_color = Color(1, 1, 1) if hc else Color(0.4, 0.3, 0.65)
	normal.set_border_width_all(2 if hc else 1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.3, 0.3) if hc else Color(0.36, 0.24, 0.6)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Color(1, 0.9, 0.1) if hc else Color(0.45, 1.0, 0.85)
	focus.set_border_width_all(4 if hc else 3)
	var on := normal.duplicate() as StyleBoxFlat           # a toggled-on button: bright fill
	on.bg_color = Color(1, 0.9, 0.1) if hc else Color(0.25, 0.75, 0.62)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, on if cls == "Button" else hover)
		t.set_stylebox("hover_pressed", cls, on)
		t.set_stylebox("focus", cls, focus)
	t.set_color("font_pressed_color", "Button", Color(0, 0, 0) if hc else Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", "Button", Color(0, 0, 0) if hc else Color(1, 1, 1))
	t.set_color("font_color", "Label", Color(1, 1, 1) if hc else Color(0.95, 0.92, 1.0))
	t.set_color("font_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", Color(1, 0.9, 0.1) if hc else Color(0.6, 1.0, 0.9))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0))
	t.set_constant("outline_size", "Label", 4 if hc else 0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 0.9, 0.1) if hc else Color(0.45, 1.0, 0.85)
	grab.set_corner_radius_all(10)
	t.set_icon("grabber", "HSlider", _dot(_fs(18), grab.bg_color))
	t.set_icon("grabber_highlight", "HSlider", _dot(_fs(22), grab.bg_color))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.5, 0.5, 0.5) if hc else Color(0.35, 0.25, 0.55)
	track.content_margin_top = _fs(4)
	track.content_margin_bottom = _fs(4)
	track.set_corner_radius_all(4)
	t.set_stylebox("slider", "HSlider", track)
	root.theme = t
	if is_open() and page == "settings":
		_show_settings.call_deferred()


func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
