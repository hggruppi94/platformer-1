extends RefCounted

# The look shared by every builder (town, school, interiors). Set THEME to "earth" for the original colours, then
# re-run the builders. With "alien", every colour a builder asks for is mapped into the alien palette:
#   yellows/oranges -> teal and cyan      reds/pinks -> magenta      greens -> acid lime
#   blues -> violet                        purples -> hot pink         whites/greys -> lavender
# Builders call tint() for surface colours, light() for lamp colours and backdrop() for background/ambient colours.
# foliage() is the alien undergrowth palette (giant leaves, ferns, glowing mushrooms); it is empty for "earth".

const THEME := "alien"

# Alien undergrowth from Sofi's picture: giant teal and purple leaves, magenta and violet ferns, glowing blue mushrooms
# on pale pink stems. Used by tools/build_town.gd (_foliage) and drawn by scenes/town/foliage.gd.
const FOLIAGE := {
	"leaves": [Color(0.04, 0.62, 0.58), Color(0.02, 0.42, 0.48), Color(0.12, 0.7, 0.66), Color(0.5, 0.2, 0.78),
		Color(0.34, 0.22, 0.8), Color(0.7, 0.24, 0.72)],
	"ferns": [Color(0.95, 0.2, 0.66), Color(0.62, 0.24, 0.98), Color(1.0, 0.42, 0.82), Color(0.78, 0.15, 0.85)],
	"mushroom_caps": [Color(0.22, 0.52, 1.0), Color(0.18, 0.82, 1.0), Color(0.42, 0.4, 1.0)],
	"mushroom_stem": Color(0.88, 0.62, 0.86),
}

# Hue remapping for saturated colours: [input hue, output hue], 0..1 around the colour wheel
const HUE_MAP := [
	[0.00, 0.93], [0.05, 0.96], [0.08, 0.48], [0.17, 0.52], [0.22, 0.27], [0.42, 0.31],
	[0.48, 0.55], [0.62, 0.74], [0.72, 0.80], [0.84, 0.90], [1.00, 0.93],
]


static func alien() -> bool:
	return THEME == "alien"


static func foliage() -> Dictionary:
	return FOLIAGE if alien() else {}


static func tint(c: Color, calm := false) -> Color:
	# calm: for indoor rooms, where big bright painted walls would glare
	if not alien():
		return c
	var out: Color
	if c.s < 0.2:
		# Neutrals (walls, floors, stone, white): lavender, a touch darker, darker ones bluer
		var hue := lerpf(0.68, 0.76, c.v)
		out = Color.from_hsv(hue, 0.1 + 0.12 * c.v + c.s * 0.5, c.v * 0.86)
	else:
		# Indoors, bright painted colours are toned down so big surfaces don't glare
		var glare := clampf((c.v - 0.7) / 0.25, 0.0, 1.0) * clampf((c.s - 0.15) / 0.35, 0.0, 1.0) if calm else 0.0
		out = Color.from_hsv(_map_hue(c.h), minf(c.s * lerpf(1.08, 0.7, glare), 1.0), c.v * lerpf(0.92, 0.66, glare))
	out.a = c.a
	return out


static func light(c: Color) -> Color:
	# Lamps: keep them bright, but cool and violet-pink instead of warm white
	if not alien():
		return c
	var t := tint(c)
	return Color.from_hsv(t.h, minf(t.s, 0.35), 1.0)


static func backdrop(c: Color) -> Color:
	# Backgrounds and ambient light: dusky violet
	if not alien():
		return c
	return Color.from_hsv(0.76, 0.35, clampf(c.v * 0.55, 0.08, 0.6))


static func _map_hue(h: float) -> float:
	for i in HUE_MAP.size() - 1:
		var a: Array = HUE_MAP[i]
		var b: Array = HUE_MAP[i + 1]
		if h >= a[0] and h <= b[0]:
			var f: float = (h - a[0]) / maxf(b[0] - a[0], 0.0001)
			var out_a: float = a[1]
			var out_b: float = b[1]
			if absf(out_b - out_a) > 0.5:            # wrap the short way round the wheel
				if out_b > out_a:
					out_a += 1.0
				else:
					out_b += 1.0
			return fposmod(lerpf(out_a, out_b, f), 1.0)
	return h
