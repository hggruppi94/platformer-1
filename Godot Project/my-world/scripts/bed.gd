extends Area3D

# A bed (Nina's, in tools/build_interiors.gd). Stand next to it and press Interact to sleep, at any time of day.
# A small picker asks how long: 1 to 12 hours (left/right to change), until morning, or until the Shift. It shows when
# she'll wake up. A nap that would run past midnight stops there, so the Shift is never skipped by accident; "until
# morning" is a clear choice to sleep through the night, so it goes straight on to 7:00 AM.
# Sleeping fades the screen out, moves the clock on, refills HP/MP/SP (fully after 8 hours or more, a share of it for
# a nap), saves, and fades back in.

const FADE_TIME := 1.2
const HOLD_TIME := 1.6               # seconds of "Zzz..." on the dark screen
const MIN_HOURS := 1
const MAX_HOURS := 12
const FULL_REST_HOURS := 8.0         # this long or more fills HP/MP/SP; less fills a share of it

var hours := 8                       # the picker remembers the last choice
var _near := false
var _busy := false                   # picker open or asleep
var _picker: CanvasLayer
var _hours_button: Button
var _preview: Label
var _wake_text := ""                 # what she says on waking, worked out when the clock jumps
@onready var _prompt: Label3D = $Prompt


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # the picker works while the game is paused under it
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_near = true
		_prompt.text = "Press %s to sleep" % Settings.key_name("interact")
		_prompt.visible = not _busy


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _near and not _busy and not get_tree().paused and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		open_picker()


func _input(event: InputEvent) -> void:
	if _picker == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_picker()
	elif _hours_button.has_focus() and _left_right(event) != 0:
		get_viewport().set_input_as_handled()
		_set_hours(hours + _left_right(event))
	elif event.is_action_pressed("interact"):           # the same key that opened it picks the highlighted option
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _left_right(event: InputEvent) -> int:
	# Arrow keys, A/D or d-pad: -1, +1, or 0 for anything else
	if event is InputEventJoypadMotion:
		return 0                                     # sticks repeat too fast for this; the d-pad works
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		return -1
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		return 1
	return 0


# -----------------------------------------------------------------------------
# The picker
# -----------------------------------------------------------------------------
func open_picker() -> void:
	_busy = true
	_prompt.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play("ui_accept", -4.0, 0.0)
	var hc := Settings.high_contrast
	_picker = CanvasLayer.new()
	_picker.layer = 40
	_picker.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.1, 0.08, 0.15, 0.92)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	if hc:
		style.border_color = Color(1, 1, 1)
		style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _fs(10))
	panel.add_child(box)
	_label(box, "How long will Nina sleep?", 28)
	_hours_button = _option(box, "", _sleep_for_hours)
	_hours_button.custom_minimum_size.x = _fs(380)
	var tip := _label(box, "Left / right: more or less sleep", 15)
	tip.modulate.a = 0.7
	var morning := _option(box, "Until morning (%s)" % Clock.format_time(Clock.WAKE_HOUR * 60.0),
		func() -> void: _start_sleep(Clock.minutes_until_hour(Clock.WAKE_HOUR), false))
	var shift := _option(box, "Until the Shift (midnight)",
		func() -> void: _start_sleep(Clock.minutes_until_hour(Clock.SHIFT_START_HOUR)))
	_option(box, "Not now", close_picker)
	_preview = _label(box, "", 18)
	_preview.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else Color(0.9, 0.78, 1.0))
	# The preview line says when she'll wake up for whichever option is highlighted
	_hours_button.focus_entered.connect(func() -> void: _show_wake(hours * 60.0))
	morning.focus_entered.connect(func() -> void: _show_wake(Clock.minutes_until_hour(Clock.WAKE_HOUR), false))
	shift.focus_entered.connect(func() -> void: _show_wake(Clock.minutes_until_hour(Clock.SHIFT_START_HOUR)))
	get_tree().root.add_child(_picker)
	_set_hours(hours)
	_hours_button.grab_focus()


func close_picker() -> void:
	if _picker:
		_picker.queue_free()
		_picker = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_busy = false
	_prompt.visible = _near


func _set_hours(h: int) -> void:
	hours = clampi(h, MIN_HOURS, MAX_HOURS)
	_hours_button.text = "<   Sleep %d hour%s   >" % [hours, "" if hours == 1 else "s"]
	_show_wake(hours * 60.0)


func _show_wake(want_minutes: float, wake_for_shift := true) -> void:
	var length := Clock.sleep_length(want_minutes) if wake_for_shift else want_minutes
	var text := "She'll wake up at %s" % Clock.format_time(Clock.minutes + length)
	if length < want_minutes:
		text += ", for the Shift!"
	_preview.text = text


func _sleep_for_hours() -> void:
	_start_sleep(hours * 60.0)


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	return l


func _option(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _fs(22))
	var focus := StyleBoxFlat.new()                  # a clear outline on the highlighted option, for controllers
	focus.draw_center = false
	focus.border_color = Color(1, 1, 0.6) if Settings.high_contrast else Color(0.9, 0.75, 1.0)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -----------------------------------------------------------------------------
# Sleeping
# -----------------------------------------------------------------------------
func sleep_for(want_minutes: float, wake_for_shift := true) -> void:
	# Sleep straight away, without the picker (also used by tools/test_clock.gd)
	_busy = true
	_prompt.visible = false
	get_tree().paused = true
	_start_sleep(want_minutes, wake_for_shift)


func _start_sleep(want_minutes: float, wake_for_shift := true) -> void:
	# wake_for_shift: stop at midnight rather than sleep through the Shift
	if _picker:
		_picker.queue_free()
		_picker = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var length := Clock.sleep_length(want_minutes) if wake_for_shift else want_minutes
	# A dark screen on top of everything; it keeps animating while the game is paused underneath
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.02, 0.1)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.modulate.a = 0.0
	layer.add_child(dark)
	var text := Label.new()
	text.text = "Zzz..."
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", _fs(40))
	text.add_theme_color_override("font_color", Color(1, 0.95, 1))
	dark.add_child(text)
	get_tree().root.add_child(layer)
	Audio.play("ui_back", -6.0)

	var tw := layer.create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		Clock.advance(length)
		_rest(length / 60.0)
		Game.save_game()
		_wake_text = _wake_message()                 # a member, not a local: lambdas copy locals when they're made
		text.text = "Zzz...\n\n%s\nDay %d, %s" % [_wake_text.get_slice("!", 0) + "!", Clock.day, Clock.time_string()])
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(dark, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		layer.queue_free()
		_busy = false
		_prompt.visible = _near
		Game.message(_wake_text))


func _rest(slept_hours: float) -> void:
	var share := clampf(slept_hours / FULL_REST_HOURS, 0.0, 1.0)
	Game.hp = mini(Game.max_hp, Game.hp + ceili(Game.max_hp * share))
	Game.mp = mini(Game.max_mp, Game.mp + ceili(Game.max_mp * share))
	Game.sp = minf(Game.max_sp, Game.sp + Game.max_sp * share)
	Game.stats_changed.emit()
	Game.sp_changed.emit()


func _wake_message() -> String:
	if Clock.in_shift():
		return "Wake up! It's midnight: the Shift has begun, and the portal is open."
	var h := Clock.hour()
	if h >= 5 and h < 12:
		return "Good morning! It's day %d. You feel well rested." % Clock.day
	return "Nina wakes up! It's %s." % Clock.time_string()
