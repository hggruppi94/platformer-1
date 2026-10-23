extends CanvasLayer

# What skating puts on screen (scenes/player/skate.gd): the balance meter while grinding, and big words that pop up
# in the middle (a bail now; trick names and scores to come). Text size and high contrast follow Settings, like the
# main HUD (scripts/hud.gd).

const METER_W := 320.0

var balance_box: Control
var needle: ColorRect
var shout_label: Label
var _shout_tween: Tween


func _ready() -> void:
	layer = 2
	# The balance meter: a bar, green in the middle, red at the ends, with a needle
	balance_box = Control.new()
	balance_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)   # low down, clear of Nina
	balance_box.offset_top = -150
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

	shout_label = Label.new()
	shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	shout_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shout_label.offset_top = 120
	shout_label.add_theme_font_size_override("font_size", 44)
	shout_label.add_theme_constant_override("outline_size", 12)
	shout_label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2))
	shout_label.modulate.a = 0.0
	add_child(shout_label)


func update_skate(s: Skate) -> void:
	var grinding := s.state == Skate.State.GRIND
	balance_box.visible = grinding
	if grinding:
		var w := clampf(s.balance, -1.0, 1.0)
		needle.position.x = METER_W / 2 * (1.0 + w) - 3


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
