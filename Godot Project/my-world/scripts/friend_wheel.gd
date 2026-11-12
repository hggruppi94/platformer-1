class_name FriendWheel
extends Control

# The friend wheel's picture (scripts/party.gd works it, like the outfit wheel: scripts/outfit_wheel.gd). Everyone
# who's joined you sits round a ring in Party.ORDER, the first at the top, with "Nobody" last; the one walking with
# you has a teal ring, the one being pointed at is gold and bigger, and the middle says who they are and what their
# Friend move does. Each friend is a little face drawn in code (face()), which the HUD's friend badge
# (scripts/friend_face.gd) uses too, so there are no picture files to keep.

var open := false
var slots: Array = []               # friend ids round the ring ("" is Nobody)
var hover := -1
var mouse := Vector2.ZERO           # how far the mouse has moved since the wheel opened

const PICK := 40.0                  # how far the mouse moves before it points at a slot
const INK := Color(0.12, 0.07, 0.2)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if open and event is InputEventMouseMotion:
		mouse += (event as InputEventMouseMotion).relative
		if mouse.length() > PICK * 3.0:
			mouse = mouse.normalized() * PICK * 3.0
		get_viewport().set_input_as_handled()      # the camera stays still while picking
		queue_redraw()


func slot_angle(i: int) -> float:
	# The first place is at the top, then round clockwise
	return -PI / 2.0 + TAU * i / maxi(slots.size(), 1)


func point(angle: float) -> bool:
	# The slot nearest this direction; says whether that changed
	var best := -1
	var best_d := INF
	for i in slots.size():
		var d := absf(angle_difference(angle, slot_angle(i)))
		if d < best_d:
			best_d = d
			best = i
	if best != hover and best >= 0:
		hover = best
		queue_redraw()
		return true
	return false


func picked() -> String:
	return str(slots[hover]) if hover >= 0 and hover < slots.size() else Party.with_you


func _draw() -> void:
	if not open:
		return
	var font := UiStyle.font()
	var s := Settings.text_scale
	var c := size / 2.0
	var r := 150.0 * s
	draw_circle(c, r + 72.0 * s, Color(0.1, 0.05, 0.18, 0.6))
	draw_arc(c, r + 72.0 * s, 0.0, TAU, 64, UiStyle.TEAL, 4.0, true)
	_text(c + Vector2(-r, -40.0 * s), "Friends", 18, UiStyle.GOLD, r * 2.0)
	for i in slots.size():
		var id := str(slots[i])
		var p := c + Vector2.from_angle(slot_angle(i)) * r
		var on := i == hover
		var rad := (50.0 if on else 40.0) * s
		var ring := UiStyle.GOLD if on else (UiStyle.TEAL if id == Party.with_you else Color(0.2, 0.12, 0.3))
		draw_circle(p, rad + 4.0, ring)
		face(self, id, p, rad)
		var label := "Nobody" if id == "" else str(Party.friend(id).name).replace(" and ", " & ")
		_text(p + Vector2(-rad * 1.6, rad + 24.0 * s), label, 15, Color.WHITE, rad * 3.2)
	if hover >= 0 and hover < slots.size():
		var id := str(slots[hover])
		var title := "Nobody" if id == "" else str(Party.friend(id).name)
		var what := "Walk on your own" if id == "" else "%s: %s" % [Settings.prompt("friend"), Party.friend(id).verb]
		_text(c + Vector2(-r, -4.0 * s), title, 22, Color(1, 0.95, 0.8), r * 2.0)
		_text(c + Vector2(-r, 22.0 * s), what, 15, Color(0.8, 1.0, 0.95), r * 2.0)


func _text(at: Vector2, text: String, fs: int, col: Color, width: float) -> void:
	var font := UiStyle.font()
	var size_px := roundi(fs * Settings.text_scale)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, 6, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, col)


# ----------------------------------------------------------------------------- the faces
static func face(ci: CanvasItem, id: String, p: Vector2, rad: float, dim := false) -> void:
	# A friend's little face, filling a circle of radius rad round p. Nina and Bruno are two faces side by side.
	if id == "":
		ci.draw_circle(p, rad, Color(0.22, 0.18, 0.28))
		ci.draw_arc(p, rad * 0.55, 0.0, TAU, 32, Color(0.55, 0.5, 0.62), maxf(2.0, rad * 0.08), true)
		ci.draw_line(p + Vector2(-rad * 0.38, rad * 0.38), p + Vector2(rad * 0.38, -rad * 0.38), Color(0.55, 0.5, 0.62),
			maxf(2.0, rad * 0.08), true)
		return
	ci.draw_circle(p, rad, Color(0.32, 0.22, 0.46))
	match id:
		"nina_bruno":
			_head(ci, p + Vector2(-rad * 0.36, rad * 0.06), rad * 0.5, Color(1.0, 0.72, 0.82), "nina")
			_head(ci, p + Vector2(rad * 0.36, rad * 0.1), rad * 0.46, Color(0.62, 0.78, 1.0), "bruno")
		_:
			var col: Color = Party.friend(id).get("colour", Color.WHITE)
			_head(ci, p + Vector2(0, rad * 0.08), rad * 0.66, col.lightened(0.15), id)
	if dim:
		ci.draw_circle(p, rad, Color(0.1, 0.05, 0.18, 0.55))


static func _head(ci: CanvasItem, p: Vector2, r: float, skin: Color, who: String) -> void:
	# What makes each one them, behind and on top of a round head with two eyes and a smile
	var w := maxf(1.5, r * 0.12)
	match who:
		"bramble":                      # a cap of leaves
			for k in 5:
				var a := PI + PI * (k + 0.5) / 5.0
				ci.draw_circle(p + Vector2.from_angle(a) * r * 0.95, r * 0.32, Color(0.3, 0.7, 0.3))
		"flurry":                       # pointy fox ears
			for sx in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(sx * r * 0.9, -r * 0.25),
					p + Vector2(sx * r * 0.75, -r * 1.25), p + Vector2(sx * r * 0.2, -r * 0.8)]), Color(0.95, 0.97, 1.0))
		"heather":                      # little horns
			for sx in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(sx * r * 0.55, -r * 0.7),
					p + Vector2(sx * r * 1.05, -r * 1.15), p + Vector2(sx * r * 0.85, -r * 0.5)]), Color(0.96, 0.9, 0.75))
		"melody":                       # a big ponytail with a purple scrunchie
			ci.draw_circle(p + Vector2(r * 0.85, -r * 0.55), r * 0.42, Color(0.6, 0.3, 0.15))
			ci.draw_circle(p + Vector2(r * 0.55, -r * 0.7), r * 0.16, Color(0.6, 0.3, 0.9))
		"bruno":                        # his black SK8 beanie
			pass
	ci.draw_circle(p, r, skin)
	match who:
		"nina":                         # her red bob and bow
			ci.draw_arc(p, r * 0.92, PI * 1.05, PI * 1.95, 16, Color(0.9, 0.35, 0.2), r * 0.3, true)
			ci.draw_circle(p + Vector2(r * 0.55, -r * 0.8), r * 0.2, Color(0.95, 0.15, 0.25))
		"bruno":
			ci.draw_arc(p, r * 0.9, PI * 1.02, PI * 1.98, 16, Color(0.1, 0.1, 0.12), r * 0.42, true)
		"heather":                      # her fringe
			ci.draw_arc(p, r * 0.9, PI * 1.15, PI * 1.85, 16, Color(0.55, 0.35, 0.2), r * 0.25, true)
		"melody":
			ci.draw_arc(p, r * 0.9, PI * 1.1, PI * 1.9, 16, Color(0.6, 0.3, 0.15), r * 0.25, true)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(p + Vector2(sx * r * 0.33, -r * 0.05), r * 0.13, INK)
		ci.draw_circle(p + Vector2(sx * r * 0.33 + r * 0.04, -r * 0.1), r * 0.04, Color.WHITE)
	ci.draw_arc(p + Vector2(0, r * 0.2), r * 0.3, PI * 0.15, PI * 0.85, 12, INK, w, true)
	if who in ["bramble", "nina", "melody"]:          # rosy cheeks
		for sx in [-1.0, 1.0]:
			ci.draw_circle(p + Vector2(sx * r * 0.58, r * 0.25), r * 0.12, Color(1.0, 0.45, 0.6, 0.6))
