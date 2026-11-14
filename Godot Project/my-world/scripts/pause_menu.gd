extends CanvasLayer

# Autoload "PauseMenu": Esc / P / Start pauses the game.
#   Paused:   Resume · Settings · New Game · Quit
#   Settings: Audio · Controls · Display · Accessibility · Assist   (all saved by scripts/settings.gd)
# Works with mouse, keyboard (arrows/Tab + Enter) and controller (d-pad/stick + A, B to go back).
# The player menu's Settings sheet (scripts/player_menu.gd) shows these same settings tabs (settings_into()).

var root: Control
var box: VBoxContainer                 # the centre panel's contents; rebuilt for each page
var panel: PanelContainer
var page := ""
var _tab := 0
var _rebinding := ""                   # action waiting for a key press
var _rebinding_pad := ""               # ...or for a controller button
var _rebind_label: Label
var _suppress_sound := false
var _host: Control                     # where the settings tabs are: this menu's box, or the player menu's sheet


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
	UiStyle.keep_on_screen(panel)                  # shrinks to fit at the biggest text sizes (scripts/ui_style.gd)
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


func is_rebinding() -> bool:
	# Waiting for a new key or button: nothing else should take it (scripts/player_menu.gd checks this)
	return _rebinding != "" or _rebinding_pad != ""


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
	_rebinding_pad = ""
	root.visible = false
	get_tree().paused = false
	# Back to the game grabs the mouse, unless it's back to the character creator or a race's results buttons,
	# which need the cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Creator.is_open() or Races.choosing() else Input.MOUSE_MODE_CAPTURED
	Audio.play("ui_back", -4.0, 0.0)


func _input(event: InputEvent) -> void:
	# A controller button for rebinding (Esc on the keyboard cancels)
	if _rebinding_pad != "":
		var pressed := -1
		if event is InputEventJoypadButton and event.pressed:
			pressed = event.button_index
		elif event is InputEventJoypadMotion and event.axis_value > 0.6:
			pressed = Settings.PAD_TRIGGERS.find_key(event.axis) if Settings.PAD_TRIGGERS.values().has(event.axis) else -1
		if pressed >= 0:
			get_viewport().set_input_as_handled()
			var pad_action := _rebinding_pad
			_rebinding_pad = ""
			var pad_clash := Settings.rebind_pad(pad_action, pressed)
			_refresh_settings()
			if pad_clash != "":
				_toast("%s was on that button too, so it moved to %s." % [Settings.action_label(pad_clash), Settings.pad_name(pad_clash)])
		elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_rebinding_pad = ""
			_refresh_settings()
		return
	# Key capture for rebinding comes first, before anything else can react to the key
	if _rebinding != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE and _rebinding != "pause":
			_rebinding = ""
			_refresh_settings()
			return
		var action := _rebinding
		_rebinding = ""
		var clash := Settings.rebind(action, event.physical_keycode)
		_refresh_settings()
		if clash != "":
			_toast("%s was on that key too, so it moved to %s." % [Settings.action_label(clash), Settings.key_name(clash)])
		return
	# ...or a mouse button: the clicks and side buttons can be keys too (Aim and Shoot start on the right and left)
	if _rebinding != "" and event is InputEventMouseButton and event.pressed and Settings.MOUSE_NAMES.has(event.button_index):
		get_viewport().set_input_as_handled()
		var mouse_action := _rebinding
		_rebinding = ""
		var mouse_clash := Settings.rebind(mouse_action, -event.button_index)
		_refresh_settings()
		if mouse_clash != "":
			_toast("%s was on that button too, so it moved to %s." % [Settings.action_label(mouse_clash), Settings.key_name(mouse_clash)])
		return
	if _rebinding != "":
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if PlayerMenu.is_open():
			PlayerMenu.close()                     # Pause closes the player menu (the quest log, the map...) first
		elif Shop.is_open():
			Shop.close()
		elif not is_open():
			open()
		elif page == "main":
			close()
		else:
			_back()
	elif is_open() and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()      # controller B: back out of a page (Godot's ui_cancel is only Esc)
		if page == "main":
			close()
		else:
			_back()


func _back() -> void:
	if page in ["settings", "confirm", "worlds"]:
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


# A picture for each of the main page's buttons (scripts/ui_icons.gd), so little ones can find Resume without reading
const ICONS := {"Resume": "resume", "Go ": "home", "Settings": "settings", "How-to tips again": "tips",
	"Show me the menu": "tour", "New Game": "new_game", "Quit": "quit", "Skate lesson": "lesson", "Stop the skate lesson": "lesson"}


func _button(text: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(_fs(320), _fs(50))
	for key in ICONS:
		if text == key or (key.ends_with(" ") and text.begins_with(key)):
			b.icon = UiIcons.get_icon(ICONS[key])
			b.add_theme_constant_override("icon_max_width", _fs(34))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			break
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
	if Races.circuit != "":
		# On a race circuit (scripts/races.gd): start the race again, or go back to the race gate
		_button("Restart the race", func():
			close()
			Races.restart())
		_button("Leave the race", func():
			close()
			Races.leave_circuit())
	for way in way_home():
		_button(way[0], func():
			close()
			(way[1] as Callable).call())
	if Portals.practice:
		_button("End practice trip", func():
			close()
			Portals.end_practice())
	elif Settings.practice_trips and not Game.on_title():
		_button("Visit a portal world", _show_worlds)
	_button("Settings", func(): _tab = 0; _show_settings())
	if Game.has_item("skateboard"):
		# Coach Bruno's skate lesson (scripts/skate_lesson.gd): start it (or carry on), or stop it
		_button("Stop the skate lesson" if SkateLesson.active else "Skate lesson", func():
			close()
			if SkateLesson.active:
				SkateLesson.stop()
			else:
				SkateLesson.start())
	_button("Show me the menu", func():
		close()
		PlayerMenu.start_tour())                            # the guided look round the player menu (scripts/menu_tour.gd)
	_button("How-to tips again", func():
		close()
		Tips.replay())
	_button("New Game", _show_confirm)
	_button("Quit", _quit)
	_focus(first)


func way_home() -> Array:
	# [button text, what it does] for a quick way home from where the player is (the player menu's Save sheet too)
	if Portals.practice:
		return []                                  # (the pause menu's "End practice trip" is the way home)
	var here := get_tree().current_scene
	if here and here.scene_file_path == "res://scenes/scary_world/scary_world.tscn":
		return [["Go home to town", func(): Game.go(Game.TOWN_SCENE, "FromScaryWorld", "town")]]   # an easy way out, any time
	if here and here.scene_file_path == Clock.EARTH:
		# On Earth, home: in the Shift, a quick way through the portal to the Void
		if Clock.in_shift():
			return [["Go through the portal to the Void", func(): Game.go(Game.TOWN_SCENE, "FromPortaltoEarth", "Void")]]
		return []
	if here and Clock.in_shift():
		return [["Go home to Earth", func(): Game.go(Clock.EARTH, Clock.EARTH_ARRIVAL, "Earth")]]   # before the Shift ends
	return []


func _show_worlds() -> void:
	# Practice trips (Settings > Assist > "Practice trips"; scripts/portals.gd): every built portal world, any time
	page = "worlds"
	_clear()
	_title("Visit a portal world")
	var l := Label.new()
	l.text = "A practice trip: no time limit, and nothing\nyou do there is kept. Your game stays just as it is."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var first: Control = null
	for w in Portals.WORLDS:
		var id := str(w.id)
		if not Portals.is_built(id):
			continue
		var b := _button(str(w.name) + ("  (mended)" if Portals.is_cleared(id) else ""), func():
			close()
			Portals.practice_trip(id))
		if first == null:
			first = b
	var back := _button("Back", _show_main)
	_focus(first if first else back)


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
	_host = box
	var vp := get_viewport().get_visible_rect().size
	# Fit the screen at any text size; the tab pages scroll when their contents are taller
	var tabs := _settings_tabs(box, Vector2(minf(_fs(620), vp.x - 120), minf(_fs(430), vp.y - _fs(40) - _fs(46) - 150)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var back := _button("Back", _show_main, row)
	back.custom_minimum_size.x = _fs(200)
	var reset := _button("Reset to defaults", func(): Settings.reset_to_defaults(); _refresh_settings(), row)
	reset.custom_minimum_size.x = _fs(260)
	_focus(tabs.get_tab_bar())


func settings_into(host: Control) -> TabContainer:
	# The player menu's Settings sheet (scripts/player_menu.gd): the same tabs, filling the sheet, and Reset
	_host = host
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var tabs := _settings_tabs(host, Vector2.ZERO)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var reset := _button("Reset to defaults", func(): Settings.reset_to_defaults(); _refresh_settings(), host)
	reset.custom_minimum_size.x = _fs(260)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tabs


func _settings_tabs(host: Control, size: Vector2) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.custom_minimum_size = size
	host.add_child(tabs)
	_tab_audio(tabs)
	_tab_controls(tabs)
	_tab_display(tabs)
	_tab_access(tabs)
	_tab_assist(tabs)
	tabs.current_tab = _tab
	tabs.tab_changed.connect(func(i): _tab = i; Audio.play("ui_move", -8.0, 0.0))
	return tabs


func _embedded() -> bool:
	return _host != null and is_instance_valid(_host) and _host != box and _host.is_inside_tree()


func _refresh_settings() -> void:
	# After a change that needs the tabs built again (a new key, a layout, the text size), wherever they are
	if _embedded():
		var tabs := settings_into(_host)
		_focus.call_deferred(tabs.get_tab_bar())
	else:
		_show_settings()


func _grid(tabs: TabContainer, name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiStyle.scroll_bar(scroll)                           # a bar on the side you can see and drag
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
		if (str(options[i][1]) == current) if current is String else is_equal_approx(float(options[i][1]), float(current)):
			o.select(i)
	o.item_selected.connect(func(i):
		Audio.play("ui_accept", -6.0, 0.0)
		Settings.set_value(prop, options[i][1])
		if prop == "text_scale":
			_refresh_settings.call_deferred())       # rebuild at the new size
	g.add_child(o)


func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100)


func _tab_audio(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Audio")
	_slider(g, "Master volume", "master_volume", 0, 1, 0.05, _pct)
	_slider(g, "Music volume", "music_volume", 0, 1, 0.05, _pct)
	_slider(g, "Sound effects volume", "sfx_volume", 0, 1, 0.05, _pct)
	_slider(g, "Voices volume", "voice_volume", 0, 1, 0.05, _pct)


func _tab_controls(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Controls")
	_slider(g, "Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.1, func(x): return "%.1fx" % x)
	_slider(g, "Controller look speed", "stick_sensitivity", 0.2, 3.0, 0.1, func(x): return "%.1fx" % x)
	_check(g, "Invert camera up/down", "invert_y")
	_check(g, "Invert camera left/right", "invert_x")
	# Layouts: Classic (Tony Hawk's buttons) or Simple (one trick button, grinds by themselves). Picking one also puts
	# every key and button back where it started.
	_label(g, "Skating layout", "Simple: tap Flip for a flip trick, hold it to grab, and grinds happen by themselves")
	var layouts := HBoxContainer.new()
	layouts.add_theme_constant_override("separation", 8)
	for style in [["Classic", "classic"], ["Simple", "simple"]]:
		var lb := Button.new()
		lb.name = "Layout " + style[1]
		lb.text = style[0]
		lb.toggle_mode = true
		lb.button_pressed = Settings.control_style == style[1]
		lb.custom_minimum_size = Vector2(_fs(130), _fs(38))
		lb.pressed.connect(func():
			Audio.play("ui_accept", -6.0, 0.0)
			Settings.use_layout(style[1])
			_refresh_settings())
		layouts.add_child(lb)
	g.add_child(layouts)
	var head := Label.new()
	head.text = "Keys and controller buttons (click one, then press the new key or button)"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = _fs(300)
	head.add_theme_font_size_override("font_size", _fs(20))
	g.add_child(head)
	g.add_child(Control.new())
	var pad_actions := []
	for pair in Settings.PAD_REBINDABLE:
		pad_actions.append(pair[0])
	for pair in Settings.REBINDABLE:
		var action: String = pair[0]
		if not Settings.action_shown(action):
			continue
		_label(g, pair[1])
		var cells := HBoxContainer.new()
		cells.add_theme_constant_override("separation", 8)
		var b := Button.new()
		b.text = Settings.key_name(action)
		b.custom_minimum_size = Vector2(_fs(130), _fs(38))
		b.pressed.connect(func(): _start_rebind(action, b))
		b.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
		cells.add_child(b)
		var pb := Button.new()
		pb.name = "Pad " + action
		pb.custom_minimum_size = Vector2(_fs(130), _fs(38))
		if action in pad_actions:
			pb.text = "🎮 " + Settings.pad_name(action)
			pb.pressed.connect(func(): _start_pad_rebind(action, pb))
		else:
			pb.text = "🎮 left stick"                  # moving stays on the stick
			pb.disabled = true
		pb.focus_entered.connect(func(): if not _suppress_sound: Audio.play("ui_move", -8.0, 0.0))
		cells.add_child(pb)
		g.add_child(cells)
	var pad := Label.new()
	pad.text = "Controller: left stick moves, right stick turns the camera (and spins and balances on the board). Aim and Shoot can go on the triggers too."
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad.custom_minimum_size.x = _fs(560)
	pad.add_theme_font_size_override("font_size", _fs(16))
	g.add_child(pad)


func _start_pad_rebind(action: String, b: Button) -> void:
	_rebinding_pad = action
	b.text = "Press a button..."
	_toast("Press the controller button for %s (Esc to cancel)" % Settings.action_label(action))


func _start_rebind(action: String, b: Button) -> void:
	_rebinding = action
	b.text = "Press a key..."
	_toast("Press the new key or mouse button for %s%s" % [Settings.action_label(action), "" if action == "pause" else " (Esc to cancel)"])


func _tab_display(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Display")
	_check(g, "Fullscreen", "fullscreen")
	_slider(g, "Field of view", "fov", 60, 100, 1, func(x): return "%d°" % x)
	_choice(g, "Screen stuff size", "hud_size", [["Small", 0.8], ["Medium", 1.0], ["Big", 1.2]],
		"How big the stats, clock, to-do list and minimap are while you play")
	_check(g, "To-do list", "objectives", "A short list of what to do next for your quest, under your stats")
	_check(g, "Corner minimap", "minimap", "A small map in the bottom-right corner (%s opens the big one)" % Settings.key_name("map"))
	_choice(g, "Clock", "clock_style", [["Watch and words", "both"], ["Just the watch", "watch"], ["Just words", "words"]],
		"Once you've got a watch, it's the clock at the top. %s holds it up to check it" % Settings.key_name("check_watch"))


func _tab_access(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Accessibility")
	_choice(g, "Text size", "text_scale", [["Normal", 1.0], ["Large", 1.25], ["Larger", 1.5], ["Largest", 2.0]],
		"Size of the on-screen stats, messages, captions and these menus")
	_choice(g, "Talking speed", "talk_speed", [["Slow", 25.0], ["Normal", 40.0], ["Fast", 70.0], ["All at once", 0.0]],
		"How fast people's words come out when they talk")
	_check(g, "Comic capitals", "talk_caps", "People talk in big comic CAPITALS. Turn off for ordinary letters, easier to read")
	_check(g, "High-contrast HUD", "high_contrast", "Solid dark panels, bright text and heavy outlines")
	_check(g, "Sound captions", "captions", "Shows text for important sounds, like a Gloop giggling nearby")
	_check(g, "Reduce flashing", "reduce_flashing", "No blinking or red flashes when hurt; calmer glowing effects")
	_check(g, "Reduce motion", "reduce_motion", "No camera kick when rolling; calmer bobbing and shimmering")


func _tab_assist(tabs: TabContainer) -> void:
	var g := _grid(tabs, "Assist")
	_choice(g, "Game speed", "game_speed", [["100%", 1.0], ["90%", 0.9], ["75%", 0.75], ["60%", 0.6]],
		"Slows the whole game down to give you more time to react")
	_choice(g, "Skating landings", "skate_assist", [["Relaxed", 0], ["Normal", 1], ["Pro", 2]],
		"Relaxed: hardly ever fall, and keep your combo. Normal: forgiving, keeps half a combo. Pro: the strict rules")
	_slider(g, "Screen shake", "screen_shake", 0.0, 1.0, 0.1, func(x): return "%d%%" % roundi(x * 100.0))
	_check(g, "Controller rumble", "rumble", "The controller buzzes a little on bumps, landings and big pops")
	_check(g, "How-to tips", "tips", "Little pop-ups the first time you do something")
	_check(g, "Race intros", "race_intros", "A flyover of the track and your rivals before each race (Jump skips it)")
	_check(g, "Playtest notes", "playtest",
		"Notes what happens as you play, in a file in the save folder, for a grown-up to read. Nothing leaves this computer")
	_check(g, "Practice trips", "practice_trips",
		"Adds \"Visit a portal world\" to the pause menu: try any world, any time, with no time limit. Nothing done there is kept")
	_check(g, "No damage", "no_damage", "Enemies still bump you, but you never lose HP")
	_check(g, "Infinite stamina", "infinite_sp", "Rolling never runs out of SP")


# ----------------------------------------------------------------------------- look
func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _toast(text: String) -> void:
	if _rebind_label == null or not is_instance_valid(_rebind_label) or _rebind_label.is_queued_for_deletion():
		_rebind_label = Label.new()
		_rebind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rebind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rebind_label.custom_minimum_size.x = _fs(560)
	var host: Control = _host if _embedded() else box
	if _rebind_label.get_parent() != host:
		if _rebind_label.get_parent():
			_rebind_label.get_parent().remove_child(_rebind_label)
		host.add_child(_rebind_label)
	_rebind_label.text = text


func _apply_theme() -> void:
	root.theme = make_theme()
	if is_open() and page == "settings":
		_show_settings.call_deferred()


func make_theme() -> Theme:
	# The menus' look, shared by every menu (scripts/ui_style.gd): the player menu and the title screen wear it too
	return UiStyle.theme()


