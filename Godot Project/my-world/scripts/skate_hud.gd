extends CanvasLayer

# What skating puts on screen (scenes/player/skate.gd): the trick combo building up along the bottom ("Kickflip +
# 50-50 + 360", "450 x 3"), the balance meter on a rail or in a manual, the score and the special meter in the top
# right, and big words that pop up in the middle (a bail, a special, a combo paid out). Text size follows Settings,
# like the main HUD (scripts/hud.gd).

const METER_W := 320.0
const OUTLINE := Color(0.12, 0.05, 0.2)

var balance_box: Control
var needle: ColorRect
var shout_label: Label
var combo_label: Label
var points_label: Label
var score_label: Label
var special_back: ColorRect
var special_bar: ColorRect
var special_label: Label
var _shout_tween: Tween
var _tricks: SkateTricks
var _special_glow := 0.0


func _ready() -> void:
	layer = 2
	# The balance meter: a bar, green in the middle, red at the ends, with a needle. Low down, under Nina.
	balance_box = Control.new()
	balance_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	balance_box.offset_top = -175
	balance_box.offset_left = -METER_W / 2
	add_child(balance_box)
	var bands := [[0.0, 0.18, Color(0.95, 0.35, 0.45)], [0.18, 0.36, Color(1.0, 0.8, 0.35)],
		[0.36, 0.64, Color(0.5, 0.95, 0.6)], [0.64, 0.82, Color(1.0, 0.8, 0.35)], [0.82, 1.0, Color(0.95, 0.35, 0.45)]]
	for b in bands:
		var r := ColorRect.new()
		r.color = b[2]
		r.position = Vector2(METER_W * b[0], 0)
		r.size = Vector2(METER_W * (b[1] - b[0]), 14)
		balance_box.add_child(r)
	needle = ColorRect.new()
	needle.color = Color(0.1, 0.08, 0.2)
	needle.size = Vector2(6, 26)
	needle.position = Vector2(METER_W / 2 - 3, -6)
	balance_box.add_child(needle)
	balance_box.visible = false

	# The combo along the bottom (like Tony Hawk's): trick names, and the points times the multiplier under them
	combo_label = _label(26, Color(1.0, 0.97, 0.8))
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	combo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	combo_label.offset_bottom = -110
	combo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combo_label.custom_minimum_size.x = 900
	points_label = _label(34, Color(0.6, 1.0, 0.7))
	points_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	points_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	points_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	points_label.offset_bottom = -66

	# Score and the special meter, top right under the "Saved" note
	score_label = _label(26, Color(1.0, 0.97, 0.8))
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.offset_right = -16
	score_label.offset_top = 52
	special_back = ColorRect.new()
	special_back.color = Color(0.12, 0.05, 0.2, 0.75)
	special_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	special_back.offset_left = -216
	special_back.offset_right = -16
	special_back.offset_top = 92
	special_back.offset_bottom = 106
	add_child(special_back)
	special_bar = ColorRect.new()
	special_bar.color = Color(1.0, 0.6, 0.95)
	special_bar.position = Vector2(2, 2)
	special_bar.size = Vector2(0, 10)
	special_back.add_child(special_bar)
	special_label = _label(18, Color(1.0, 0.75, 0.98))
	special_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	special_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	special_label.offset_right = -16
	special_label.offset_top = 108

	shout_label = _label(44, Color.WHITE)
	shout_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	shout_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shout_label.offset_top = 120
	shout_label.modulate.a = 0.0


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * Settings.text_scale))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func watch(t: SkateTricks) -> void:
	_tricks = t
	t.changed.connect(_refresh)
	t.banked.connect(_on_banked)
	_refresh()


func update_skate(s: Skate) -> void:
	balance_box.visible = s.balancing()
	if balance_box.visible:
		needle.position.x = METER_W / 2 * (1.0 + clampf(s.balance, -1.0, 1.0)) - 3
	# A full special meter glows
	if _tricks and _tricks.special >= 1.0:
		_special_glow += get_process_delta_time() * 6.0
		special_bar.color = Color(1.0, 0.6, 0.95).lerp(Color(1.0, 1.0, 0.7), 0.5 + 0.5 * sin(_special_glow))
	else:
		special_bar.color = Color(1.0, 0.6, 0.95)


func _refresh() -> void:
	if _tricks == null:
		return
	var active := _tricks.is_active() and (_tricks.points() > 0 or not _tricks.names().is_empty())
	combo_label.text = _tricks.names() if active else ""
	points_label.text = ("%d x %d" % [_tricks.points(), _tricks.multiplier()]) if active and _tricks.points() > 0 else ""
	score_label.text = "Score %s" % _commas(_tricks.score)
	special_bar.size.x = 196.0 * clampf(_tricks.special, 0.0, 1.0)
	special_label.text = "SPECIAL ready!  %s + %s" % [Settings.key_name("skate_flip"), Settings.key_name("skate_grab")] \
		if _tricks.special >= 1.0 else ""


func _on_banked(points: int, _names: String) -> void:
	shout("+" + _commas(points), Color(0.6, 1.0, 0.7))


func shout(text: String, color := Color.WHITE) -> void:
	shout_label.text = text
	shout_label.add_theme_color_override("font_color", color)
	shout_label.add_theme_font_size_override("font_size", int(44 * Settings.text_scale))
	shout_label.pivot_offset = shout_label.size / 2
	if _shout_tween:
		_shout_tween.kill()
	shout_label.modulate.a = 1.0
	shout_label.scale = Vector2(1.3, 1.3)
	_shout_tween = create_tween()
	_shout_tween.tween_property(shout_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_shout_tween.tween_interval(0.8)
	_shout_tween.tween_property(shout_label, "modulate:a", 0.0, 0.4)


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
