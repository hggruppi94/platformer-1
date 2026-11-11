class_name RaceHud
extends CanvasLayer

# What a race puts on screen (scripts/races.gd): the lap, your place and the time across the top, the power-up
# you're holding and the button for it on the left, the big countdown and shouts in the middle, and the results at the
# end. Text size follows Settings, like the main HUD (scripts/hud.gd). On a circuit there's no town map, so it draws a
# little map of the track on the right with everyone on it (you in gold), and the results come with buttons: race
# again, or go back. A line under the place says what just happened ("A Bubble Seeker's after you!", "Got Dash!").

const OUTLINE := Color(0.12, 0.05, 0.2)
const PLACE_COLOURS := [Color(1.0, 0.85, 0.3), Color(0.85, 0.9, 1.0), Color(1.0, 0.7, 0.45), Color(0.75, 0.95, 0.8)]

var lap_label: Label
var place_label: Label
var time_label: Label
var power_box: PanelContainer
var power_label: Label
var big_label: Label
var results: PanelContainer
var results_label: Label
var warn_label: Label
var choice_box: HBoxContainer
var map: Control
var _big_tween: Tween
var _warn_time := 0.0
var _map_track: RaceTrack
var _map_pts := PackedVector2Array()
var _map_rect := Rect2()
var _mouse_was := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 3
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 112                     # under the day and time box (scripts/hud.gd)
	top.add_theme_constant_override("separation", 34)
	add_child(top)
	lap_label = _label(30, Color(1.0, 0.97, 0.8))
	place_label = _label(40, PLACE_COLOURS[0])
	time_label = _label(30, Color(0.75, 0.9, 1.0))
	for l in [lap_label, place_label, time_label]:
		top.add_child(l)

	power_box = PanelContainer.new()
	power_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	power_box.offset_left = 16
	power_box.add_theme_stylebox_override("panel", _panel(Color(0.18, 0.12, 0.3, 0.8)))
	add_child(power_box)
	power_label = _label(24, Color(1.0, 0.95, 0.8))
	power_box.add_child(power_label)

	big_label = _label(96, Color(1.0, 0.85, 0.3))
	big_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	big_label.offset_top = -170
	big_label.offset_bottom = -170
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(big_label)

	results = PanelContainer.new()
	results.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	results.grow_vertical = Control.GROW_DIRECTION_BOTH
	results.add_theme_stylebox_override("panel", _panel(Color(0.16, 0.1, 0.28, 0.9)))
	add_child(results)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	results.add_child(col)
	results_label = _label(28, Color(1.0, 0.97, 0.85))
	results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(results_label)
	choice_box = HBoxContainer.new()
	choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_box.add_theme_constant_override("separation", 24)
	choice_box.visible = false     # hidden from the start: hiding it again later hands the mouse back to the game,
	                               # and doing that as the game loads hid the cursor on the title screen
	col.add_child(choice_box)

	warn_label = _label(26, Color(1.0, 0.75, 0.85))
	warn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)   # (low down, clear of the lap line and
	warn_label.grow_horizontal = Control.GROW_DIRECTION_BOTH                   # the big shouts in the middle)
	warn_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	warn_label.offset_bottom = -150
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(warn_label)

	map = Control.new()
	map.name = "Track Map"
	map.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	map.custom_minimum_size = Vector2(220, 220)
	map.size = Vector2(220, 220)
	map.offset_left = -240
	map.offset_right = -20
	map.offset_top = -110
	map.offset_bottom = 110
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(_draw_map)
	add_child(map)
	clear()


func _process(delta: float) -> void:
	if _warn_time > 0.0:
		_warn_time -= delta
		warn_label.modulate.a = clampf(_warn_time / 0.4, 0.0, 1.0)
	if map.visible:
		map.queue_redraw()


func clear() -> void:
	for l in [lap_label, place_label, time_label]:
		l.text = ""
	power_box.visible = false
	big_label.text = ""
	results.visible = false
	warn_label.text = ""
	hide_choices()


func show_status(lap: int, laps: int, place: int, racers: int, seconds: float) -> void:
	lap_label.text = "Lap %d/%d" % [mini(lap, laps), laps]
	place_label.text = "%s of %d" % [ordinal(place), racers]
	place_label.add_theme_color_override("font_color", PLACE_COLOURS[clampi(place - 1, 0, PLACE_COLOURS.size() - 1)])
	time_label.text = clock(seconds)
	_sizes()


func show_power(name: String) -> void:
	power_box.visible = name != ""
	power_label.text = "%s\nPress %s to use it!" % [name, Settings.prompt("aim")] if name != "" else ""


func shout(text: String, color := Color(1.0, 0.85, 0.3), hold := 0.6) -> void:
	big_label.text = text
	big_label.add_theme_color_override("font_color", color)
	big_label.add_theme_font_size_override("font_size", int(96 * Settings.text_scale))
	big_label.pivot_offset = big_label.size / 2
	if _big_tween:
		_big_tween.kill()
	big_label.modulate.a = 1.0
	big_label.scale = Vector2(1.4, 1.4)
	_big_tween = create_tween()
	_big_tween.tween_property(big_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_big_tween.tween_interval(hold)
	_big_tween.tween_property(big_label, "modulate:a", 0.0, 0.35)


func show_results(text: String) -> void:
	for l in [lap_label, place_label, time_label]:
		l.text = ""
	results_label.text = text
	results_label.add_theme_font_size_override("font_size", int((22 if text.count("\n") > 10 else 28) * Settings.text_scale))
	results.visible = true
	power_box.visible = false


func hide_results() -> void:
	results.visible = false


func warn(text: String) -> void:
	warn_label.text = text
	warn_label.add_theme_font_size_override("font_size", int(26 * Settings.text_scale))
	warn_label.modulate.a = 1.0
	_warn_time = 1.8


func show_choices(text: String, choices: Array) -> void:
	# The results with buttons ([text, Callable] each); the mouse is free while they're up
	show_results(text)
	for c in choice_box.get_children():
		c.queue_free()
	var first: Button
	for c in choices:
		var b := Button.new()
		b.text = str(c[0])
		b.custom_minimum_size = Vector2(220, 56)
		b.add_theme_font_size_override("font_size", int(26 * Settings.text_scale))
		var call: Callable = c[1]
		b.pressed.connect(func() -> void:
			Audio.play("ui_accept", -4.0, 0.0)
			call.call())
		choice_box.add_child(b)
		if first == null:
			first = b
	choice_box.visible = true
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first:
		first.grab_focus.call_deferred()


func hide_choices() -> void:
	if choice_box == null or not choice_box.visible:
		return
	choice_box.visible = false
	for c in choice_box.get_children():
		c.queue_free()
	results.visible = false
	Input.mouse_mode = _mouse_was if _mouse_was != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED


func choosing() -> bool:
	return choice_box.visible


func show_map(t: RaceTrack) -> void:
	# The little track map (circuits only: out in the world the minimap shows the race)
	_map_track = t if t and t.width > 0.0 else null
	map.visible = _map_track != null
	_map_pts = PackedVector2Array()
	if _map_track == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(0, t.line.size(), 4):
		var p := Vector2(t.line[i].x, t.line[i].z)
		lo = lo.min(p)
		hi = hi.max(p)
	_map_rect = Rect2(lo, hi - lo)
	for i in range(0, t.line.size(), 4):
		_map_pts.append(_to_map(t.line[i]))
	_map_pts.append(_map_pts[0])


func _to_map(p: Vector3) -> Vector2:
	var s := 190.0 / maxf(_map_rect.size.x, _map_rect.size.y)
	var off := (Vector2(220, 220) - _map_rect.size * s) / 2.0
	return off + (Vector2(p.x, p.z) - _map_rect.position) * s


func _draw_map() -> void:
	if _map_track == null or not is_instance_valid(_map_track) or _map_pts.size() < 3:
		return
	map.draw_rect(Rect2(Vector2.ZERO, Vector2(220, 220)), Color(0.12, 0.08, 0.22, 0.55))
	map.draw_polyline(_map_pts, Color(0.12, 0.05, 0.2, 0.8), 9.0, true)
	map.draw_polyline(_map_pts, Color(0.85, 0.8, 1.0, 0.9), 5.0, true)
	var start := _to_map(_map_track.point_at(0.0))
	map.draw_circle(start, 5.0, Color(1, 1, 1))
	for r in Races.rivals:
		if is_instance_valid(r):
			map.draw_circle(_to_map(r.global_position), 5.0, Color(1.0, 0.55, 0.75))
			map.draw_arc(_to_map(r.global_position), 5.0, 0, TAU, 12, Color(0.25, 0.05, 0.15), 1.5)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		map.draw_circle(_to_map(p.global_position), 7.0, Color(1.0, 0.85, 0.3))
		map.draw_arc(_to_map(p.global_position), 7.0, 0, TAU, 14, Color(0.2, 0.1, 0.05), 2.0)


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


static func clock(seconds: float) -> String:
	var s := maxf(seconds, 0.0)
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


func _sizes() -> void:
	lap_label.add_theme_font_size_override("font_size", int(30 * Settings.text_scale))
	place_label.add_theme_font_size_override("font_size", int(40 * Settings.text_scale))
	time_label.add_theme_font_size_override("font_size", int(30 * Settings.text_scale))
	power_label.add_theme_font_size_override("font_size", int(24 * Settings.text_scale))


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 10)
	return l


func _panel(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.border_color = Color(1.0, 0.82, 0.35, 0.9)
	sb.set_border_width_all(3)
	return sb
