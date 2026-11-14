class_name UiIcons
extends RefCounted

# Little picture icons for the menus (Hayden's 7 Nov 2026 playtest: the menus need to work for young kids, who look
# at pictures before words). Drawn here from simple shapes, each with the menus' dark ink outline, in the alien palette
# (scripts/ui_style.gd), so there are no image files to keep: UiIcons.get_icon("map") gives a texture, made the first
# time it's asked for and kept.
#
#   Player menu sheets: quests, goals, map, calendar, hero, bag, skate, settings, save
#   Pause menu:         resume, home, tips, tour, new_game, quit, lesson, clock
#   And:                close (the menus' round X button)

const SIZE := 48                               # pixels; buttons draw them at this size, or smaller
const INK := Color(0.07, 0.03, 0.12)
const OUTLINE := 0.045                         # the ink round every shape, as a share of the icon's width

static var _cache := {}


static func get_icon(kind: String, size := SIZE) -> Texture2D:
	var key := "%s@%d" % [kind, size]
	if not _cache.has(key):
		_cache[key] = _render(_shapes(kind), size)
	return _cache[key]


static func kinds() -> Array[String]:
	return ["quests", "goals", "map", "calendar", "hero", "bag", "skate", "settings", "save",
		"resume", "home", "tips", "tour", "new_game", "quit", "lesson", "clock", "close"]


# ----------------------------------------------------------------------------- the pictures
# Each is a list of [distance function, colour] (or [.., .., false]: no outline), bottom to top. A distance function takes a point (0..1 across and
# down) and gives how far it is outside the shape (less than 0 inside).
static func _shapes(kind: String) -> Array:
	const GOLD := Color(1.0, 0.85, 0.35)
	const TEAL := Color(0.45, 1.0, 0.85)
	const MAGENTA := Color(1.0, 0.45, 0.75)
	const LAVENDER := Color(0.75, 0.65, 1.0)
	const WHITE := Color(0.97, 0.95, 1.0)
	const LIME := Color(0.62, 0.95, 0.35)
	const SKY := Color(0.45, 0.65, 1.0)
	match kind:
		"quests":                              # a gold badge with a "!"
			return [[_circle(0.5, 0.5, 0.4), GOLD],
				[_box(0.5, 0.4, 0.065, 0.19, 0.05), INK],
				[_circle(0.5, 0.75, 0.075), INK]]
		"goals":                               # a flag on a pole
			return [[_seg(0.28, 0.12, 0.28, 0.9, 0.045), WHITE],
				[_poly([Vector2(0.31, 0.12), Vector2(0.88, 0.3), Vector2(0.31, 0.5)]), MAGENTA]]
		"map":                                 # a folded map with a pin
			return [[_poly([Vector2(0.1, 0.22), Vector2(0.37, 0.12), Vector2(0.63, 0.22), Vector2(0.9, 0.12),
					Vector2(0.9, 0.8), Vector2(0.63, 0.9), Vector2(0.37, 0.8), Vector2(0.1, 0.9)]), TEAL],
				[_seg(0.37, 0.14, 0.37, 0.8, 0.012), Color(0.2, 0.6, 0.5), false],
				[_seg(0.63, 0.22, 0.63, 0.88, 0.012), Color(0.2, 0.6, 0.5), false],
				[_circle(0.52, 0.42, 0.12), MAGENTA],
				[_circle(0.52, 0.42, 0.04), WHITE, false]]
		"calendar":                            # a page with a coloured top and days
			var c := [[_box(0.5, 0.56, 0.37, 0.33, 0.07), WHITE], [_box(0.5, 0.3, 0.37, 0.09, 0.05), MAGENTA],
				[_seg(0.33, 0.13, 0.33, 0.26, 0.035), INK], [_seg(0.67, 0.13, 0.67, 0.26, 0.035), INK]]
			for i in 3:
				for j in 2:
					c.append([_circle(0.3 + 0.2 * i, 0.55 + 0.18 * j, 0.05), Color(0.45, 0.35, 0.7), false])
			return c
		"hero":                                # a little person
			return [[_box(0.5, 0.8, 0.27, 0.2, 0.16), LAVENDER],
				[_circle(0.5, 0.36, 0.2), Color(1.0, 0.82, 0.68)],
				[_circle(0.43, 0.36, 0.028), INK, false], [_circle(0.57, 0.36, 0.028), INK, false],
				[_ring(0.5, 0.4, 0.07, 0.012), INK, false]]
		"bag":                                 # a backpack
			return [[_ring(0.5, 0.33, 0.16, 0.04), Color(0.75, 0.45, 0.25)],
				[_box(0.5, 0.62, 0.34, 0.28, 0.12), Color(0.95, 0.6, 0.3)],
				[_box(0.5, 0.72, 0.2, 0.11, 0.05), Color(1.0, 0.75, 0.45)]]
		"skate", "lesson":                     # a skateboard, from the side
			return [[_box(0.5, 0.48, 0.42, 0.075, 0.075), TEAL],
				[_circle(0.29, 0.66, 0.095), LAVENDER], [_circle(0.71, 0.66, 0.095), LAVENDER]]
		"settings":                            # a cog
			return [[_gear(0.5, 0.5, 0.31, 0.09, 8), LAVENDER], [_circle(0.5, 0.5, 0.11), INK]]
		"save":                                # a floppy disk
			return [[_box(0.5, 0.5, 0.37, 0.37, 0.06), SKY],
				[_box(0.5, 0.26, 0.19, 0.11, 0.02), WHITE],
				[_box(0.5, 0.7, 0.25, 0.15, 0.03), WHITE]]
		"resume":                              # a "play" arrow
			return [[_poly([Vector2(0.3, 0.16), Vector2(0.84, 0.5), Vector2(0.3, 0.84)]), LIME]]
		"home":                                # a house
			return [[_box(0.5, 0.66, 0.3, 0.24, 0.03), WHITE],
				[_poly([Vector2(0.1, 0.48), Vector2(0.5, 0.12), Vector2(0.9, 0.48)]), MAGENTA],
				[_box(0.5, 0.76, 0.08, 0.14, 0.02), Color(0.6, 0.4, 0.25)]]
		"tips":                                # a light bulb
			return [[_box(0.5, 0.78, 0.13, 0.1, 0.03), LAVENDER],
				[_circle(0.5, 0.42, 0.28), GOLD],
				[_seg(0.43, 0.46, 0.5, 0.56, 0.02), Color(0.85, 0.55, 0.1), false],
				[_seg(0.57, 0.46, 0.5, 0.56, 0.02), Color(0.85, 0.55, 0.1), false],
				[_circle(0.42, 0.33, 0.06), Color(1, 1, 0.85), false]]
		"tour":                                # a speech bubble with "..."
			return [[_poly([Vector2(0.25, 0.62), Vector2(0.4, 0.66), Vector2(0.2, 0.88)]), WHITE],
				[_box(0.5, 0.42, 0.4, 0.28, 0.16), WHITE],
				[_circle(0.32, 0.42, 0.06), Color(0.45, 0.35, 0.7), false], [_circle(0.5, 0.42, 0.06), Color(0.45, 0.35, 0.7), false],
				[_circle(0.68, 0.42, 0.06), Color(0.45, 0.35, 0.7), false]]
		"new_game":                            # a twinkly star
			return [[_star(0.5, 0.52, 0.42, 0.19, 5), GOLD]]
		"quit":                                # a door
			return [[_box(0.5, 0.52, 0.27, 0.38, 0.05), Color(0.75, 0.45, 0.3)],
				[_box(0.5, 0.52, 0.18, 0.3, 0.03), Color(0.9, 0.58, 0.38)],
				[_circle(0.6, 0.55, 0.045), GOLD]]
		"clock":                               # a clock face
			return [[_circle(0.5, 0.5, 0.4), WHITE],
				[_ring(0.5, 0.5, 0.33, 0.03), LAVENDER, false],
				[_seg(0.5, 0.5, 0.5, 0.24, 0.045), INK, false],
				[_seg(0.5, 0.5, 0.69, 0.6, 0.045), INK, false],
				[_circle(0.5, 0.5, 0.05), MAGENTA, false]]
		"close":                               # a round X
			return [[_circle(0.5, 0.5, 0.4), MAGENTA],
				[_seg(0.35, 0.35, 0.65, 0.65, 0.055), WHITE, false], [_seg(0.65, 0.35, 0.35, 0.65, 0.055), WHITE, false]]
	return [[_circle(0.5, 0.5, 0.35), LAVENDER]]


# ----------------------------------------------------------------------------- drawing
static func _render(shapes: Array, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var px := 1.0 / size                                   # one pixel, in the 0..1 units
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size)
			var col := Color(0, 0, 0, 0)
			for s in shapes:
				var d: float = (s[0] as Callable).call(p)
				# The ink outline under the shape (unless it's a little detail), then the shape, both softened over a
				# pixel (anti-aliased)
				if s.size() < 3 or s[2]:
					col = _over(col, Color(INK, clampf(0.5 - (d - OUTLINE) / px, 0.0, 1.0)))
				col = _over(col, Color(s[1], clampf(0.5 - d / px, 0.0, 1.0)))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _over(under: Color, top: Color) -> Color:
	var a := top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(top.r, top.g, top.b) * top.a + Vector3(under.r, under.g, under.b) * under.a * (1.0 - top.a)) / a
	return Color(rgb.x, rgb.y, rgb.z, a)


static func _circle(cx: float, cy: float, r: float) -> Callable:
	return func(p: Vector2) -> float: return p.distance_to(Vector2(cx, cy)) - r


static func _ring(cx: float, cy: float, r: float, w: float) -> Callable:
	return func(p: Vector2) -> float: return absf(p.distance_to(Vector2(cx, cy)) - r) - w


static func _box(cx: float, cy: float, hx: float, hy: float, round_r: float) -> Callable:
	return func(p: Vector2) -> float:
		var q := (p - Vector2(cx, cy)).abs() - Vector2(hx, hy) + Vector2(round_r, round_r)
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round_r


static func _seg(ax: float, ay: float, bx: float, by: float, r: float) -> Callable:
	return func(p: Vector2) -> float:
		var a := Vector2(ax, ay)
		var ba := Vector2(bx, by) - a
		var h := clampf((p - a).dot(ba) / ba.dot(ba), 0.0, 1.0)
		return (p - a - ba * h).length() - r


static func _poly(v: Array) -> Callable:
	# Distance to a polygon (Inigo Quilez's sdPolygon)
	return func(p: Vector2) -> float:
		var d := (p - (v[0] as Vector2)).length_squared()
		var s := 1.0
		var n := v.size()
		var j := n - 1
		for i in n:
			var vi: Vector2 = v[i]
			var vj: Vector2 = v[j]
			var e := vj - vi
			var w := p - vi
			var b := w - e * clampf(w.dot(e) / e.dot(e), 0.0, 1.0)
			d = minf(d, b.length_squared())
			var c1 := p.y >= vi.y
			var c2 := p.y < vj.y
			var c3 := e.x * w.y > e.y * w.x
			if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
				s = -s
			j = i
		return s * sqrt(d)


static func _star(cx: float, cy: float, r_out: float, r_in: float, points: int) -> Callable:
	var v: Array = []
	for i in points * 2:
		var ang := -PI / 2.0 + PI * i / points
		var r := r_out if i % 2 == 0 else r_in
		v.append(Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r)
	return _poly(v)


static func _gear(cx: float, cy: float, r: float, tooth: float, teeth: int) -> Callable:
	return func(p: Vector2) -> float:
		var q := p - Vector2(cx, cy)
		var bump := clampf(cos(q.angle() * teeth) * 2.5, -1.0, 1.0) * 0.5 + 0.5
		return (q.length() - (r + tooth * bump)) * 0.8
