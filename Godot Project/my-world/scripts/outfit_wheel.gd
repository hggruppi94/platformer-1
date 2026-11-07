class_name OutfitWheel
extends Control

# The quick outfit wheel's picture (scripts/quick_outfits.gd works it): six places round a ring, the first at the
# top. Each saved outfit is a little figure in its colours (head in the fur or skin colour, body in the accent, a gold
# ring for a skin) with its number; empty places are dim. The middle names the one being pointed at.

var open := false
var hover := -1
var mouse := Vector2.ZERO           # how far the mouse has moved since the wheel opened

const OWN := Color(0.75, 0.68, 0.9)  # a colour left as the body's own


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if open and event is InputEventMouseMotion:
		mouse += (event as InputEventMouseMotion).relative
		if mouse.length() > QuickOutfits.PICK * 3.0:
			mouse = mouse.normalized() * QuickOutfits.PICK * 3.0
		get_viewport().set_input_as_handled()      # the camera stays still while picking
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	var font := UiStyle.font()
	var s := Settings.text_scale
	var c := size / 2.0
	var r := 150.0 * s
	draw_circle(c, r + 72.0 * s, Color(0.1, 0.05, 0.18, 0.6))
	draw_arc(c, r + 72.0 * s, 0.0, TAU, 64, UiStyle.TEAL, 4.0, true)
	draw_string_outline(font, c + Vector2(-r, -40.0 * s), "Outfits", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
		roundi(18 * s), 6, Color.BLACK)
	draw_string(font, c + Vector2(-r, -40.0 * s), "Outfits", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, roundi(18 * s),
		UiStyle.GOLD)
	for i in QuickOutfits.MAX:
		var o = QuickOutfits.get_slot(i)
		var p := c + Vector2.from_angle(QuickOutfits.slot_angle(i)) * r
		var on := i == hover
		var rad := (50.0 if on else 40.0) * s
		draw_circle(p, rad + 4.0, UiStyle.GOLD if on else Color(0.2, 0.12, 0.3))
		draw_circle(p, rad, Color(0.32, 0.22, 0.46) if o != null else Color(0.22, 0.18, 0.28))
		if o == null:
			draw_string(font, p + Vector2(-rad, 8.0 * s), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0,
				roundi(20 * s), Color(0.55, 0.5, 0.6))
			continue
		_figure(o, p, rad)
		draw_string_outline(font, p + Vector2(-rad, rad + 26.0 * s), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0,
			roundi(18 * s), 6, Color.BLACK)
		draw_string(font, p + Vector2(-rad, rad + 26.0 * s), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0,
			roundi(18 * s), Color.WHITE)
	var h = QuickOutfits.get_slot(hover)
	if h != null:
		for pair in [[str(h.name), -4.0, 22, Color(1, 0.95, 0.8)], [QuickOutfits.describe(h), 22.0, 15, Color(0.8, 1.0, 0.95)]]:
			draw_string_outline(font, c + Vector2(-r, float(pair[1]) * s), pair[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
				roundi(int(pair[2]) * s), 6, Color.BLACK)
			draw_string(font, c + Vector2(-r, float(pair[1]) * s), pair[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
				roundi(int(pair[2]) * s), pair[3])


func _figure(o: Dictionary, p: Vector2, rad: float) -> void:
	# A little person in the outfit's colours
	var cols := Skins.colors_of({"colors": o.colors, "skin": o.skin, "body": Game.hero.get("body", "hippo")})
	var fur := _swatch(cols, "fur")
	var accent := _swatch(cols, "accent")
	var hair := _swatch(cols, "hair")
	var top := _swatch(cols, "top")
	draw_rect(Rect2(p + Vector2(-rad * 0.34, rad * 0.02), Vector2(rad * 0.68, rad * 0.55)), top if cols.has("top") else accent)
	draw_circle(p + Vector2(0, -rad * 0.3), rad * 0.34, fur)
	draw_arc(p + Vector2(0, -rad * 0.3), rad * 0.34, PI * 1.05, PI * 1.95, 12, hair, rad * 0.14, true)
	draw_circle(p + Vector2(-rad * 0.12, -rad * 0.32), rad * 0.05, Color(0.1, 0.08, 0.15))
	draw_circle(p + Vector2(rad * 0.12, -rad * 0.32), rad * 0.05, Color(0.1, 0.08, 0.15))
	if (o.outfit as Dictionary).has("head"):          # a hat
		draw_rect(Rect2(p + Vector2(-rad * 0.3, -rad * 0.8), Vector2(rad * 0.6, rad * 0.18)), accent.darkened(0.2))
	if str(o.skin) != "":
		draw_arc(p, rad - 3.0, 0.0, TAU, 40, UiStyle.GOLD, 3.0, true)


static func _swatch(cols: Dictionary, part: String) -> Color:
	var pick := int(cols.get(part, 0))
	return Hero.SWATCHES[(pick - 1) % Hero.SWATCHES.size()] if pick > 0 else OWN
