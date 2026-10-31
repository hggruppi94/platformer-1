class_name GadgetWheel
extends Control

# The gadget wheel and the little gadget readout in the corner (scripts/arsenal.gd). StarPopper puts one on its HUD.
#
#   Hold Gadget wheel (R / D-pad up)   the wheel opens and the game slows right down. Point at a gadget with the
#                                      mouse or either stick and let go to pick it.
#   Tap it                             swaps back to the last gadget.
#   1-8 / D-pad left and right         pick one straight away / the one before or after.
#
# The readout shows the gadget that's out, its version, its ammo and how close it is to growing a version. It only
# shows once she has more than the Star Popper (or a mod).
# Each gadget's two mod slots (Arsenal: mods) show as little dots under it, in the mod's colour (an empty ring for an
# empty slot), and the middle of the wheel names the mods and their combo. Mods are swapped in the Bag.

const HOLD := 0.2                         # seconds held before the wheel opens (shorter is a tap)
const SLOW := 0.2                         # how fast the game runs while the wheel is open
const PICK := 40.0                        # pixels the mouse has to move from the middle to point at a slot

var popper: StarPopper
var open := false
var hover := ""                           # the gadget being pointed at
var _held := 0.0
var _pressed := false
var _mouse := Vector2.ZERO                # how far the mouse has moved since the wheel opened


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Arsenal.changed.connect(queue_redraw)


func _exit_tree() -> void:
	if open:
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)         # the wheel's own timing ignores the slow-down
	var ok := popper != null and popper.can_shoot()
	if not ok:
		if open:
			close(false)
		_pressed = false
		_held = 0.0
		queue_redraw()
		return
	if Input.is_action_just_pressed("gadget_wheel"):
		_pressed = true
		_held = 0.0
	if _pressed and Input.is_action_pressed("gadget_wheel"):
		_held += real
		if _held >= HOLD and not open and Arsenal.owned.size() > 1:
			open_wheel()
	elif _pressed:
		_pressed = false
		if open:
			close(true)
		elif _held < HOLD:
			Arsenal.quick_swap()
	if open:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if left.length() > stick.length():
			stick = left
		if stick.length() > 0.5:
			point(stick.angle())
		elif _mouse.length() > PICK:
			point(_mouse.angle())
	queue_redraw()


func _input(event: InputEvent) -> void:
	if open and event is InputEventMouseMotion:
		_mouse += (event as InputEventMouseMotion).relative
		if _mouse.length() > PICK * 3.0:
			_mouse = _mouse.normalized() * PICK * 3.0
		get_viewport().set_input_as_handled()       # the camera stays still while picking


func _unhandled_input(event: InputEvent) -> void:
	if popper == null or not popper.can_shoot() or event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_8 and not k in Settings.bindings.values():
			var i := k - KEY_1
			if i < Arsenal.ORDER.size():
				Arsenal.select(Arsenal.ORDER[i])
	elif event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT] and not b in Settings.pad_bindings.values():
			Arsenal.cycle(-1 if b == JOY_BUTTON_DPAD_LEFT else 1)


func open_wheel() -> void:
	open = true
	hover = Arsenal.current
	_mouse = Vector2.ZERO
	Engine.time_scale = SLOW
	Audio.play("ui_move", -6.0, 0.0)


func close(pick: bool) -> void:
	open = false
	Engine.time_scale = 1.0
	if pick and hover != "" and Arsenal.owns(hover):
		if hover != Arsenal.current:
			Audio.play("ui_accept", -6.0, 0.0)
		Arsenal.select(hover)


func point(angle: float) -> void:
	# The slot nearest this direction (0 = right, going clockwise on screen)
	var n := Arsenal.ORDER.size()
	var best := ""
	var best_d := INF
	for i in n:
		var d := absf(angle_difference(angle, slot_angle(i)))
		if d < best_d:
			best_d = d
			best = Arsenal.ORDER[i]
	if best != hover and Arsenal.owns(best):
		hover = best
		Audio.play("ui_move", -10.0, 0.0)


func slot_angle(i: int) -> float:
	# The first slot is at the top, then round clockwise
	return -PI / 2.0 + TAU * i / maxi(Arsenal.ORDER.size(), 3)


# ----------------------------------------------------------------------------- drawing
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var s := Settings.text_scale
	if (Arsenal.owned.size() > 1 or not Arsenal.mods_owned.is_empty()) and not open:
		_draw_readout(font, s)
	if open:
		_draw_wheel(font, s)


func _draw_readout(font: Font, s: float) -> void:
	var id := Arsenal.current
	var w := 250.0 * s
	var h := 64.0 * s
	var at := Vector2(size.x - w - 24.0, size.y - h - 24.0)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.12, 0.07, 0.2, 0.7))
	draw_circle(at + Vector2(h / 2.0, h / 2.0), h * 0.32, Arsenal.colour(id))
	_icon(id, at + Vector2(h / 2.0, h / 2.0), h * 0.26)
	var x := at.x + h
	draw_string(font, Vector2(x, at.y + 24.0 * s), "%s  V%d" % [Arsenal.gadget_name(id), Arsenal.level(id)],
		HORIZONTAL_ALIGNMENT_LEFT, w - h - 8.0, roundi(17 * s), Color(1, 0.95, 0.8))
	var am := Arsenal.ammo_of(id)
	var ammo_text := "∞" if am < 0 else "%d / %d" % [am, Arsenal.max_ammo(id)]
	draw_string(font, Vector2(x, at.y + 46.0 * s), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(17 * s),
		Color(1.0, 0.55, 0.6) if am == 0 else Color(0.8, 1.0, 0.95))
	_mod_dots(id, Vector2(at.x + w - 40.0 * s, at.y + 42.0 * s), 6.0 * s)
	var bar := Rect2(Vector2(x, at.y + h - 10.0 * s), Vector2(w - h - 12.0, 5.0 * s))
	draw_rect(bar, Color(1, 1, 1, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * Arsenal.progress(id), bar.size.y)), Color(1.0, 0.82, 0.3))


func _draw_wheel(font: Font, s: float) -> void:
	var c := size / 2.0
	var r := 150.0 * s
	draw_circle(c, r + 70.0 * s, Color(0.1, 0.05, 0.18, 0.55))
	draw_arc(c, r + 70.0 * s, 0.0, TAU, 64, Color(1.0, 0.82, 0.3, 0.8), 3.0, true)
	for i in Arsenal.ORDER.size():
		var id: String = Arsenal.ORDER[i]
		var p := c + Vector2.from_angle(slot_angle(i)) * r
		var have := Arsenal.owns(id)
		var on := id == hover
		var rad := (52.0 if on else 42.0) * s
		draw_circle(p, rad + 4.0, Color(1.0, 0.85, 0.35) if on else Color(0.2, 0.12, 0.3))
		draw_circle(p, rad, Arsenal.colour(id) if have else Color(0.3, 0.25, 0.35))
		if have:
			_icon(id, p, rad * 0.8)
			# How close it is to its next version, round the edge
			draw_arc(p, rad + 9.0, -PI / 2.0, -PI / 2.0 + TAU * Arsenal.progress(id), 32, Color(1.0, 0.82, 0.3), 4.0, true)
			var am := Arsenal.ammo_of(id)
			draw_string(font, p + Vector2(-rad, rad + 28.0 * s), "∞" if am < 0 else str(am), HORIZONTAL_ALIGNMENT_CENTER,
				rad * 2.0, roundi(16 * s), Color(1.0, 0.55, 0.6) if am == 0 else Color(1, 1, 1))
			_mod_dots(id, p + Vector2(0, -rad - 14.0 * s), 5.0 * s)
		else:
			draw_string(font, p + Vector2(-rad, 10.0 * s), "?", HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, roundi(30 * s),
				Color(0.7, 0.65, 0.75))
	# In the middle: what's being pointed at
	if hover != "":
		draw_string(font, c + Vector2(-r, -6.0 * s), Arsenal.gadget_name(hover), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
			roundi(22 * s), Color(1, 0.95, 0.8))
		draw_string(font, c + Vector2(-r, 22.0 * s), "V%d" % Arsenal.level(hover), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
			roundi(18 * s), Color(1.0, 0.82, 0.3))
		var ms := Arsenal.mods(hover)
		if not ms.is_empty():
			var names: Array[String] = []
			for m in ms:
				names.append(str(Arsenal.MODS[m].name))
			draw_string(font, c + Vector2(-r, 46.0 * s), " + ".join(names), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
				roundi(15 * s), Color(0.8, 1.0, 0.95))
			var combo := Arsenal.combo_name(hover)
			if combo != "":
				draw_string(font, c + Vector2(-r, 68.0 * s), combo + "!", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0,
					roundi(17 * s), Color(1.0, 0.6, 0.9))


func _icon(id: String, p: Vector2, r: float) -> void:
	# A little picture of each gadget, drawn with shapes
	var white := Color(1, 1, 1, 0.95)
	match id:
		"popper":
			draw_circle(p, r * 0.55, Color(0.85, 1.0, 1.0, 0.6))
			_star(p, r * 0.4, Color(1.0, 0.82, 0.3))
		"fizz":
			draw_rect(Rect2(p + Vector2(-r * 0.25, -r * 0.3), Vector2(r * 0.5, r * 0.85)), Color(0.15, 0.55, 0.7))
			draw_rect(Rect2(p + Vector2(-r * 0.12, -r * 0.6), Vector2(r * 0.24, r * 0.32)), Color(0.15, 0.55, 0.7))
			draw_rect(Rect2(p + Vector2(-r * 0.14, -r * 0.72), Vector2(r * 0.28, r * 0.14)), Color(1.0, 0.5, 0.78))
			for k in 3:
				draw_circle(p + Vector2(r * (0.45 + 0.1 * k), -r * (0.3 + 0.25 * k)), r * 0.09, white)
		"disco":
			draw_circle(p, r * 0.6, Color(0.85, 0.85, 0.95))
			for k in 6:
				var a := TAU * k / 6.0
				draw_rect(Rect2(p + Vector2.from_angle(a) * r * 0.3 - Vector2(r, r) * 0.08, Vector2(r, r) * 0.16),
					DiscoBall.COLOURS[k % DiscoBall.COLOURS.size()])
			draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, -r * 0.9), Color(1.0, 0.82, 0.3), 2.0)
		"plush":
			draw_circle(p + Vector2(0, r * 0.15), r * 0.42, Color(1.0, 0.85, 0.92))
			draw_circle(p + Vector2(0, -r * 0.35), r * 0.3, Color(1.0, 0.85, 0.92))
			for k in [-1, 1]:
				draw_circle(p + Vector2(k * r * 0.25, -r * 0.6), r * 0.13, Color(1.0, 0.85, 0.92))
				draw_circle(p + Vector2(k * r * 0.1, -r * 0.38), r * 0.05, Color(0.15, 0.08, 0.2))
		"buzz":
			for k in 3:
				var bp := p + Vector2.from_angle(-PI / 2.0 + TAU * k / 3.0) * r * 0.45
				draw_circle(bp, r * 0.22, Color(1.0, 0.92, 0.55))
				draw_circle(bp + Vector2(0, -r * 0.02), r * 0.1, Color(0.3, 0.9, 0.82))
		"rainbow":
			for k in RainbowRay.STRIPES.size():
				draw_arc(p + Vector2(0, r * 0.3), r * (0.75 - 0.1 * k), PI, TAU, 16, RainbowRay.STRIPES[k], r * 0.1, true)
		"jelly":
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				pts.append(p + Vector2(cos(a) * r * 0.65, sin(a) * r * 0.5 + r * 0.25))
			draw_colored_polygon(pts, Color(0.95, 0.45, 0.6))
			draw_circle(p + Vector2(-r * 0.2, -r * 0.02), r * 0.08, white)


func _mod_dots(id: String, centre: Vector2, r: float) -> void:
	# The gadget's mod slots: a dot in the mod's colour, or an empty ring
	if Arsenal.mods_owned.is_empty():
		return
	var slots := Arsenal.slots_of(id)
	for i in Arsenal.SLOTS:
		var p := centre + Vector2((i - 0.5) * r * 3.0, 0)
		var m := str(slots[i])
		if m != "":
			draw_circle(p, r + 1.5, Color(0.1, 0.05, 0.18))
			draw_circle(p, r, Arsenal.MODS[m].colour)
		else:
			draw_arc(p, r, 0.0, TAU, 16, Color(1, 1, 1, 0.5), 1.5, true)


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
