class_name RaceHud
extends CanvasLayer

# What a race puts on screen (scripts/races.gd): the lap, your place and the time across the top, the power-up
# you're holding and the button for it on the left, the big countdown and shouts in the middle, and the results at the
# end. Text size follows Settings, like the main HUD (scripts/hud.gd).

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
var _big_tween: Tween


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
	results_label = _label(28, Color(1.0, 0.97, 0.85))
	results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.add_child(results_label)
	clear()


func clear() -> void:
	for l in [lap_label, place_label, time_label]:
		l.text = ""
	power_box.visible = false
	big_label.text = ""
	results.visible = false


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
	results_label.add_theme_font_size_override("font_size", int(28 * Settings.text_scale))
	results.visible = true
	power_box.visible = false


func hide_results() -> void:
	results.visible = false


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
