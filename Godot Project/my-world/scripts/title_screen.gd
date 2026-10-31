extends Node3D

# The title screen (plan prompt F5), the game's first scene (scenes/title/title.tscn). Galaxity at dawn turns slowly
# behind the menu: the town is loaded as scenery with nobody to play it (its Player is taken out), the clock is
# held still and set to dawn just for the view, and both are put back as they were when you leave. Buttons:
#
#   Continue   (only with a save: the hero's name, which night, how long they've played)  -> Game.continue_game()
#   New Game   (asks first if there's a save) -> the opening, then Game.new_game() and the creator
#   Settings   (the pause menu's settings tabs)
#   Quit
#
# The opening (play_opening()) is about 35 seconds and can be skipped any time with Jump, Interact, Esc/Start or a
# click: Stars Hollow asleep at midnight, the old oak humming, a flash of Galaxity outside time, and the watches some
# kids have that tick their own way. Nothing about how Dash's story ends. Tests: tools/test_title.gd.

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const DAWN := 6.6 * 60.0                      # Galaxity's minutes for the view: the sun just up
const ORBIT_CENTRE := Vector3(5, 0, -40)
const ORBIT_RADIUS := 115.0
const ORBIT_HEIGHT := 46.0
const ORBIT_SPEED := 0.018                    # radians a second: slow
const LOOK_AT := Vector3(10, 14, -85)
const OPENING := [
	# [what's on screen, the narration, seconds]
	["earth", "Stars Hollow. A quiet town, fast asleep.", 5.5],
	["oak", "Well... almost everything's asleep. The old oak on the green is humming.", 6.0],
	["flash", "", 0.6],
	["galaxity", "Somewhere outside of time there's a planet where a whole day fits inside one hour.", 7.0],
	["watches", "And a few kids have watches that tick... differently.", 6.5],
	["you", "Tonight, one of them is you.", 4.0],
]

var cam: Camera3D
var ui: CanvasLayer
var menu_box: VBoxContainer
var continue_button: Button
var new_button: Button
var settings_panel: PanelContainer
var confirm_panel: PanelContainer
var caption: Label
var skip_hint: Label
var fader: ColorRect
var opening_on := false
var opening_shot := ""                        # which part of the opening is showing (tools/test_title.gd)
var _skip := false
var _angle := 0.6
var _bg: Node
var _keep := {}                               # the clock as it was, put back on the way out
var _cam_from := Transform3D()
var _cam_to := Transform3D()
var _cam_t := 0.0
var _cam_len := 1.0


func _ready() -> void:
	_keep = {"minutes": Clock.minutes, "earth_minutes": Clock.earth_minutes, "on_earth": Clock.on_earth,
		"mode": Clock.process_mode}
	Clock.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	_show_world("galaxity")
	_build_ui()
	Audio.music("town_day" if Audio.music_path("town_day") != "" else "town")


func _exit_tree() -> void:
	Clock.minutes = float(_keep.get("minutes", Clock.minutes))
	Clock.earth_minutes = float(_keep.get("earth_minutes", Clock.earth_minutes))
	Clock.on_earth = bool(_keep.get("on_earth", Clock.on_earth))
	Clock.process_mode = int(_keep.get("mode", Node.PROCESS_MODE_INHERIT))


func _process(delta: float) -> void:
	if opening_on:
		_cam_t = minf(_cam_t + delta / _cam_len, 1.0)
		var k := _cam_t * _cam_t * (3.0 - 2.0 * _cam_t)
		cam.global_transform = _cam_from.interpolate_with(_cam_to, k)
		return
	_angle += ORBIT_SPEED * delta
	var p := ORBIT_CENTRE + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	cam.global_position = p
	cam.look_at(LOOK_AT)


func _unhandled_input(event: InputEvent) -> void:
	if opening_on and event.is_pressed() and not event.is_echo():
		if event.is_action("jump") or event.is_action("interact") or event.is_action("ui_cancel") \
				or event.is_action("pause") or event.is_action("ui_accept") or event is InputEventMouseButton:
			skip_opening()
			get_viewport().set_input_as_handled()
	elif settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()
	elif confirm_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_confirm()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# The world behind the menu
# -----------------------------------------------------------------------------
func _show_world(which: String) -> void:
	# Galaxity at dawn, or Stars Hollow at midnight, as scenery: nobody to play it
	if _bg:
		_bg.queue_free()
		_bg = null
	var path := TOWN if which == "galaxity" else EARTH
	if which == "galaxity":
		Clock.on_earth = false
		Clock.minutes = DAWN
	else:
		Clock.on_earth = true
		Clock.earth_minutes = 23 * 60.0 + 50.0
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_bg = packed.instantiate()
	for n in ["Player", "HUD", "Hud"]:
		var c := _bg.get_node_or_null(n)
		if c:
			_bg.remove_child(c)
			c.free()
	for c in _bg.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
	add_child(_bg)
	cam.make_current()


# -----------------------------------------------------------------------------
# The menu
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = PauseMenu.make_theme()
	ui.add_child(root)

	var title := Label.new()
	title.text = "Galaxity"
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(0.93, 0.86, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.4))
	title.add_theme_constant_override("outline_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-400, 70)
	title.size = Vector2(800, 130)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "a planet outside of time"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.75, 1.0, 0.95))
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.25))
	sub.add_theme_constant_override("outline_size", 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-400, 195)
	sub.size = Vector2(800, 40)
	root.add_child(sub)

	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.position = Vector2(-210, -20)
	menu_box.custom_minimum_size = Vector2(420, 0)
	root.add_child(menu_box)
	if has_save():
		continue_button = _button("Continue", continue_game)
		var info := Label.new()
		info.name = "SaveInfo"
		info.text = save_info()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 20)
		info.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
		info.add_theme_constant_override("outline_size", 8)
		menu_box.add_child(info)
	new_button = _button("New Game", _ask_new_game)
	_button("Settings", _open_settings)
	_button("Quit", func() -> void: get_tree().quit())
	(continue_button if continue_button else new_button).grab_focus.call_deferred()

	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.offset_left = 120
	settings_panel.offset_right = -120
	settings_panel.offset_top = 80
	settings_panel.offset_bottom = -60
	settings_panel.visible = false
	root.add_child(settings_panel)

	confirm_panel = PanelContainer.new()
	confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	confirm_panel.position = Vector2(-300, -110)
	confirm_panel.custom_minimum_size = Vector2(600, 220)
	confirm_panel.visible = false
	root.add_child(confirm_panel)
	var cb := VBoxContainer.new()
	cb.name = "Box"
	cb.add_theme_constant_override("separation", 14)
	confirm_panel.add_child(cb)
	var q := Label.new()
	q.name = "Question"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cb.add_child(q)
	var yes := Button.new()
	yes.name = "Yes"
	yes.text = "Yes, start a new game"
	yes.pressed.connect(func() -> void:
		_close_confirm()
		play_opening())
	cb.add_child(yes)
	var no := Button.new()
	no.name = "No"
	no.text = "No, go back"
	no.pressed.connect(_close_confirm)
	cb.add_child(no)

	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fader)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption.position = Vector2(-560, -170)
	caption.size = Vector2(1120, 100)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	caption.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.12))
	caption.add_theme_constant_override("outline_size", 14)
	caption.modulate.a = 0.0
	root.add_child(caption)
	skip_hint = Label.new()
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.position = Vector2(-380, -50)
	skip_hint.size = Vector2(360, 30)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.add_theme_font_size_override("font_size", 18)
	skip_hint.modulate = Color(1, 1, 1, 0.75)
	skip_hint.visible = false
	root.add_child(skip_hint)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = text
	b.text = text
	b.custom_minimum_size = Vector2(420, 58)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Audio.play("ui_move", -10.0, 0.0))
	menu_box.add_child(b)
	return b


static func has_save() -> bool:
	return FileAccess.file_exists(Game.SAVE_PATH) and not Game.needs_creator


static func save_info() -> String:
	# "Sunny  ·  Night 3  ·  played 1 h 12 min"
	var who := Dialogue.player_name()
	var mins := int(Game.play_time / 60.0)
	var played := "%d h %d min" % [mins / 60, mins % 60] if mins >= 60 else "%d min" % maxi(mins, 1)
	return "%s  ·  Night %d  ·  played %s" % [who, Nights.night(), played]


func continue_game() -> void:
	Audio.play("ui_accept", -6.0, 0.0)
	Game.continue_game()


func _ask_new_game() -> void:
	Audio.play("ui_accept", -6.0, 0.0)
	if not has_save():
		play_opening()
		return
	(confirm_panel.get_node("Box/Question") as Label).text = \
		"Start a new game? %s's adventure so far will be gone." % Dialogue.player_name()
	menu_box.visible = false
	confirm_panel.visible = true
	(confirm_panel.get_node("Box/No") as Button).grab_focus()


func _close_confirm() -> void:
	confirm_panel.visible = false
	menu_box.visible = true
	new_button.grab_focus()


func _open_settings() -> void:
	Audio.play("ui_accept", -6.0, 0.0)
	menu_box.visible = false
	settings_panel.visible = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	for c in settings_panel.get_children():
		c.queue_free()
	settings_panel.add_child(box)
	var host := VBoxContainer.new()                  # (the settings tabs and their Reset button stack in it)
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_theme_constant_override("separation", 10)
	box.add_child(host)
	var tabs: TabContainer = PauseMenu.settings_into(host)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(240, 50)
	back.pressed.connect(_close_settings)
	box.add_child(back)
	if tabs:
		tabs.get_tab_bar().grab_focus.call_deferred()
	else:
		back.grab_focus.call_deferred()


func _close_settings() -> void:
	settings_panel.visible = false
	menu_box.visible = true
	(continue_button if continue_button else new_button).grab_focus()


# -----------------------------------------------------------------------------
# The opening
# -----------------------------------------------------------------------------
func play_opening() -> void:
	if opening_on:
		return
	opening_on = true
	_skip = false
	menu_box.visible = false
	for c in ui.get_child(0).get_children():
		if c is Label and c != caption and c != skip_hint:
			c.visible = false
	skip_hint.text = "%s to skip" % Settings.fill("{jump}")
	skip_hint.visible = true
	for shot in OPENING:
		if _skip:
			break
		opening_shot = str(shot[0])
		await _shot(opening_shot, str(shot[1]), float(shot[2]))
	_finish_opening()


func skip_opening() -> void:
	_skip = true


func _shot(which: String, text: String, seconds: float) -> void:
	match which:
		"earth":
			await _fade(1.0, 0.4)
			_show_world("earth")
			Audio.music("earth_night" if Audio.music_path("earth_night") != "" else "town")
			var oak := _find("PortalToGalaxity")
			var at := oak.global_position if oak else Vector3(0, 0, 20)
			_move(Vector3(at.x + 60, 34, at.z + 70), at + Vector3(-20, 0, -30), Vector3(at.x + 40, 22, at.z + 45), at, seconds + 6.0)
			await _fade(0.0, 1.0)
		"oak":
			var oak := _find("PortalToGalaxity")
			var at := oak.global_position if oak else Vector3(0, 0, 20)
			_move(cam.global_position, at, at + Vector3(7, 4, 9), at + Vector3(0, 2.5, 0), seconds)
			Audio.play("beam", -14.0, 0.0)
		"flash":
			fader.color = Color(1, 1, 1, 0)
			await _fade(1.0, 0.25)
			_show_world("galaxity")
			Audio.music("town_day" if Audio.music_path("town_day") != "" else "town")
			_move(Vector3(-40, 80, 120), Vector3(10, 10, -60), Vector3(30, 40, 40), LOOK_AT, 7.5)
			await _fade(0.0, 0.5)
			fader.color = Color(0, 0, 0, 0)
			return
		"galaxity":
			pass
		"watches":
			await _fade(1.0, 0.5)
			_watch_stage()
			await _fade(0.0, 0.6)
		"you":
			pass
	await _say(text, seconds)


func _say(text: String, seconds: float) -> void:
	if text == "":
		return
	caption.text = text
	var tw := create_tween()
	tw.tween_property(caption, "modulate:a", 1.0, 0.5)
	var t := 0.0
	while t < seconds and not _skip and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > seconds - 0.6:
			caption.modulate.a = maxf(caption.modulate.a - get_process_delta_time() / 0.5, 0.0)


func _fade(to: float, time: float) -> void:
	if _skip:
		fader.color.a = to
		return
	var tw := create_tween()
	tw.tween_property(fader, "color:a", to, time)
	await tw.finished


func _move(from: Vector3, from_look: Vector3, to: Vector3, to_look: Vector3, seconds: float) -> void:
	_cam_from = Transform3D(Basis(), from).looking_at(from_look) if from.distance_to(from_look) > 0.1 else cam.global_transform
	_cam_to = Transform3D(Basis(), to).looking_at(to_look)
	_cam_t = 0.0
	_cam_len = maxf(seconds, 0.1)


func _watch_stage() -> void:
	# A dark little stage with five watches turning, each its own way (one of them backwards)
	if _bg:
		_bg.queue_free()
	var stage := Node3D.new()
	stage.name = "Watch Stage"
	_bg = stage
	add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.04, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.45, 0.7)
	e.glow_enabled = true
	env.environment = e
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.4, 0)
	stage.add_child(light)
	var ids := ["water_clock", "cuckoo", "digital", "backwards", "galaxy"]
	for i in ids.size():
		var w: Node3D = Watches.model(ids[i])
		w.name = "Opening " + ids[i]
		w.position = Vector3((i - 2) * 1.5, sin(i * 1.7) * 0.25, 0)
		w.scale = Vector3.ONE * 2.2
		stage.add_child(w)
		var spin := create_tween().set_loops()
		var dir := -1.0 if ids[i] == "backwards" else 1.0
		spin.tween_property(w, "rotation:y", dir * TAU, 3.0 + i * 0.7).as_relative()
	var stage_from := Transform3D(Basis(), Vector3(0, 0.4, 6.5)).looking_at(Vector3(0, 0, 0))
	var stage_to := Transform3D(Basis(), Vector3(0, 0.2, 5.0)).looking_at(Vector3(0, 0, 0))
	_cam_from = stage_from
	_cam_to = stage_to
	_cam_t = 0.0
	_cam_len = 11.0
	cam.global_transform = stage_from


func _finish_opening() -> void:
	opening_shot = "done"
	skip_hint.visible = false
	fader.color = Color(0, 0, 0, fader.color.a)
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.0 if _skip else 0.6)
	tw.tween_property(caption, "modulate:a", 0.0, 0.2)
	await tw.finished
	Game.new_game()


func _find(n: String) -> Node3D:
	return _bg.find_child(n, true, false) as Node3D if _bg else null
