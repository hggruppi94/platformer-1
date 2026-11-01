class_name WatchFace
extends Control

# The hero's own watch, drawn as the game's clock (the HUD's top middle, and big when they check it: scripts/hud.gd).
# In the show everyone who lands on Galaxity has a watch that tracks time the way it worked where they came from
# (story/how-it-fits.md, "the watches"), and the first time the hero crosses over one appears on their wrist
# (scripts/first_night.gd). So from then on the watch IS the clock.
#
# Which watch it is follows what they're wearing (scripts/time_watch.gd):
# - The Shift Watch "ticks Earth's way": its hands always show Earth's time. During the Shift Earth's clock crawls
#   (one Earth hour is a whole Galaxity day), so in Galaxity its hands barely move and its second hand creeps round:
#   that's the "it ticks... differently here" from the arrival.
# - The Time Keeper (Dash's reward for all twenty lost watches, as a wrist watch or a pendant) "keeps your time": its
#   hands show the time where they are, and a little dial in its face shows the other world's.
#
# Both have the Shift ring round the edge. Outside the Shift, on Earth, a moon sits at twelve and a lavender wedge
# fills from the hour hand up to it as midnight comes: when the hand reaches the moon, the portal opens. During the
# Shift the ring is Galaxity's whole day (dawn to dawn), with a sun or moon going round it, and the part still to come
# glows: when it's all gone, the portal pulls them home. While Rex and Dash's lab quest needs time ripples, a pink
# pointer on the rim points the way to the nearest one (scripts/lab.gd) and pulses faster as they get close.

var big := false                      # the big one (checking the watch), with thicker lines
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	if r < 6.0:
		return
	var c := size * 0.5
	var keeper := TimeWatch.style() == "keeper"
	var hc := Settings.high_contrast
	var w := maxf(r * 0.06, 1.5)                     # line width, in step with the size

	# The case and the face
	var case_col := Color(0.55, 0.35, 0.78) if keeper else Color(0.3, 0.8, 0.75)
	var face_col := Color(0.12, 0.1, 0.3) if keeper else Color(1.0, 0.96, 0.88)
	var ink := Color(1.0, 0.85, 0.35) if keeper else Color(0.15, 0.1, 0.3)
	if hc:
		face_col = Color(0, 0, 0) if keeper else Color(1, 1, 1)
		ink = Color(1, 1, 0.4) if keeper else Color(0, 0, 0)
	draw_circle(c, r, case_col)
	draw_circle(c, r * 0.8, face_col)
	if hc:
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1), w * 0.8, true)

	# The Shift ring, between the case's edge and the face
	_shift_ring(c, r * 0.9, r * 0.12, keeper)

	# Twelve hour marks, the twelve and six bigger
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2(sin(a), -cos(a))
		var long := 0.16 if i % 3 == 0 else 0.08
		draw_line(c + d * r * (0.74 - long), c + d * r * 0.74, ink, w * (1.3 if i % 3 == 0 else 0.8), true)

	# The other world's time, in a little dial (the Time Keeper only)
	if keeper:
		var sc := c + Vector2(0, r * 0.36)
		var sr := r * 0.2
		draw_circle(sc, sr, Color(0.3, 0.8, 0.75) if not hc else Color(1, 1, 1))
		var other := TimeWatch.other_minutes()
		var sub_ink := Color(0.12, 0.1, 0.3) if not hc else Color(0, 0, 0)
		_hand(sc, sr * 0.55, fposmod(other, 720.0) / 720.0, sub_ink, w * 1.1)
		_hand(sc, sr * 0.85, fposmod(other, 60.0) / 60.0, sub_ink, w * 0.7)

	# The hands
	var m := TimeWatch.shown_minutes()
	_hand(c, r * 0.42, fposmod(m, 720.0) / 720.0, ink, w * 2.0)               # hours
	_hand(c, r * 0.64, fposmod(m, 60.0) / 60.0, ink, w * 1.3)                 # minutes
	var secs := fposmod(m * 60.0, 60.0)                                       # the game's own seconds
	_hand(c, r * 0.7, secs / 60.0, Color(1.0, 0.35, 0.65), w * 0.6)           # a pink second hand
	draw_circle(c, w * 1.6, ink)

	# The ripple finder: the way to the nearest time ripple, from where the camera's looking
	var bearing = TimeWatch.ripple_bearing()
	if bearing != null:
		var dist := float(bearing.y)
		var beat := clampf(1.0 - dist / 120.0, 0.15, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * (3.0 + 12.0 * beat))
		var a2 := float(bearing.x)
		var d2 := Vector2(sin(a2), -cos(a2))
		var side := Vector2(-d2.y, d2.x)
		var tip := c + d2 * (r + r * 0.18)
		var col := Color(1.0, 0.35, 0.75).lerp(Color(1, 1, 1), pulse * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, c + d2 * r * 0.86 + side * r * 0.16,
			c + d2 * r * 0.86 - side * r * 0.16]), col)
		draw_arc(c, r * (1.0 + 0.06 * pulse), 0, TAU, 48, Color(1.0, 0.35, 0.75, 0.25 + 0.5 * pulse * beat), w, true)


func _hand(c: Vector2, length: float, turn: float, col: Color, width: float) -> void:
	var a := TAU * turn
	draw_line(c, c + Vector2(sin(a), -cos(a)) * length, col, width, true)


func _shift_ring(c: Vector2, rr: float, width: float, keeper: bool) -> void:
	var lav := Color(0.8, 0.65, 1.0)
	var dim := Color(0.35, 0.28, 0.5, 0.6) if not keeper else Color(0.25, 0.18, 0.4, 0.8)
	if Clock.in_shift():
		# Galaxity's whole day, dawn to dawn, starting at the top. What's left of it glows.
		var gone := 1.0 - Clock.shift_minutes_left() / float(Clock.MINUTES_PER_DAY)
		var start := -PI / 2.0
		draw_arc(c, rr, start, start + TAU * gone, 48, dim, width, true)
		draw_arc(c, rr, start + TAU * gone, start + TAU, 48, lav, width, true)
		var a := start + TAU * gone
		var at := c + Vector2(cos(a), sin(a)) * rr
		if Clock.daylight() > 0.4:
			draw_circle(at, width * 0.9, Color(1.0, 0.85, 0.3))                       # Galaxity's sun...
		else:
			draw_circle(at, width * 0.9, Color(0.9, 0.92, 1.0))                       # ...or its moon
		return
	draw_arc(c, rr, 0, TAU, 48, dim, width, true)
	var moon := c + Vector2(0, -rr)
	if Clock.on_earth:
		# The hour hand creeping up to the moon at twelve: when it gets there, the portal opens
		var to_midnight := Clock.minutes_until_hour(Clock.SHIFT_START_HOUR)
		if to_midnight <= 720.0:
			var hand := -PI / 2.0 - TAU * to_midnight / 720.0
			draw_arc(c, rr, hand, -PI / 2.0, 32, lav, width, true)
	draw_circle(moon, width * 0.85, Color(0.95, 0.95, 1.0))
	draw_circle(moon + Vector2(width * 0.35, -width * 0.15), width * 0.7, Color(0.35, 0.28, 0.5) if not keeper else Color(0.25, 0.18, 0.4))
