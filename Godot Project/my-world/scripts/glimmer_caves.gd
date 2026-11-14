extends Node3D

# The Glimmer Caves, under Lanternmoor (Lanternmoor slice two, scripts/lanternmoor.gd). Hayden: "large intricate caves
# in Pip's world for when you gain his ability". When the sun comes up over a mended Lanternmoor a round hollow opens in
# the moor near the way in (HOLLOW, cut through the floor with scripts/ground_hole.gd), and under it is a whole cave
# system, dark as can be. Pip's glow (scripts/pip_glow.gd), learnt the same morning, lights it as you go: the rock
# never sees the moon (scripts/cave_kit.gd shade_from_sun), so only the glow, the caves' mushrooms and the crystals it
# wakes light the way.
#
# The caves (cave_kit.gd build(), made at play time from SHAPES: a second or so, and only once it's mended):
#   the Moth Hall      under the hollow. A moth lift (hold Jump in the column of rising moths) floats you back up.
#   the Crystal Gallery a big hall of sleeping crystals that wake as your glow reaches them, stone columns, a high
#                      ledge (a bouncy mushroom gets you up)
#   the Chasm          a long hall with a deep pit across its middle: a bridge of moth dust only the glow shows
#                      (cave_kit glow_bridge(), planks in "glow_solid") grows ahead of you as you cross
#   the Echo Pool      at the bottom of the pit: a still underground pool with an islet. Fall in and a moth lift
#                      takes you back up to the Chasm
#   the Mushroom Grotto giant glowing mushrooms to bounce on, up to a tunnel high in its wall
#   the Moonroot Chamber under Moon Rock, hung with the rock's glowing roots: the Moon Cache (3 Remnants, once)
#   Lantern Roots      under the Lantern Grove, reached by the long, narrow Gloomie Squeeze from the Moth Hall, where
#                      shy little Gloomies (dark fluffballs with big eyes) scurry off from your glow
# Every room joins up in loops, so you can't get stuck. Five lost **moonmoths** (found moth_1..5) hide in the dark;
# they only show in the glow (group "glow_reveal"). Walk up to one and it flutters off home to Pip; all five and Pip
# gives you MOTH_REMNANTS Remnants and MOTH_SPARKLES sparkles.
# Made by lanternmoor.gd (_open_caves()). Tests: tools/test_lanternmoor.gd.

const KIT := preload("res://scripts/cave_kit.gd")
const HOLE := preload("res://scripts/ground_hole.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const HOLLOW := Vector3(8, 0, 37)         # the way down: clear moor behind the way in, well off the Moon Well's paving
const HOLE_R := 2.6
const TOP := -1.0                          # the moor's floor is a slab from -1 to 0: the caves are all under it
const FALL_BELOW := -42.0                  # the world's fall catch goes under the caves' deepest floor
const LIFT_SPEED := 6.5                    # m/s, floating up a moth lift
const BOUNCE := 15.0                       # m/s, off a bouncy mushroom
const MOTH_NEAR := 1.6
const MOTH_REMNANTS := 6
const MOTH_SPARKLES := 10
const CACHE_REMNANTS := 3
const GLOOMIE_SHY := 6.0                   # a Gloomie scurries off when the glow comes this close
const MOTH_GLOW := Color(0.75, 0.9, 1.0)
const LIFT_GLOW := Color(1.0, 0.85, 0.6)

const SHAPES := [
	# The Moth Hall, under the hollow
	{"kind": "shaft", "at": Vector3(8, -9, 37), "r": 3.0, "top": 3.0},
	{"kind": "room", "at": Vector3(10, -7, 30), "r": 7.0, "floor": -9.0},
	# down to the Crystal Gallery
	{"kind": "tunnel", "points": [Vector3(8, -8, 25), Vector3(5, -9, 18), Vector3(6, -10, 11), Vector3(9, -11, 5)], "r": 2.6},
	{"kind": "room", "at": Vector3(12, -10, -1), "r": 11.0, "squash": 0.55, "floor": -13.0},
	{"kind": "room", "at": Vector3(7, -12, 1), "r": 1.4, "squash": 4.0, "solid": true},       # stone columns
	{"kind": "room", "at": Vector3(15, -12, 3), "r": 1.2, "squash": 4.5, "solid": true},
	{"kind": "room", "at": Vector3(19.5, -13.5, -7), "rx": 3.2, "ry": 3.5, "rz": 3.0, "solid": true},  # the high ledge
	# on to the Chasm, and the pit down to the Echo Pool
	{"kind": "tunnel", "points": [Vector3(10, -13, -10), Vector3(6, -14, -16), Vector3(2, -15, -21)], "r": 2.6},
	{"kind": "room", "at": Vector3(0, -14, -26), "rx": 15.0, "ry": 5.5, "rz": 6.0, "floor": -16.0},
	{"kind": "shaft", "at": Vector3(0, -31, -26), "r": 5.5, "top": -14.0},
	{"kind": "room", "at": Vector3(0, -29, -26), "r": 10.0, "squash": 0.5, "floor": -31.0},
	{"kind": "room", "at": Vector3(1.5, -31, -26), "rx": 3.6, "ry": 2.2, "rz": 3.6, "floor": -33.2},  # the pool's bowl
	{"kind": "room", "at": Vector3(2.6, -32.2, -27), "r": 0.9, "squash": 2.0, "solid": true},        # its islet
	# east to the Mushroom Grotto, up to the Moonroot Chamber, and back down to the Gallery's ledge
	{"kind": "tunnel", "points": [Vector3(13, -15, -26), Vector3(18, -15, -30), Vector3(22, -14, -33)], "r": 2.4},
	{"kind": "room", "at": Vector3(26, -11, -34), "r": 7.0, "squash": 0.9, "floor": -14.0},
	{"kind": "tunnel", "points": [Vector3(27, -7.5, -29), Vector3(29, -7, -24), Vector3(30, -7, -19)], "r": 2.2},
	{"kind": "room", "at": Vector3(30, -6, -15), "r": 5.5, "squash": 0.7, "floor": -8.5},
	{"kind": "tunnel", "points": [Vector3(28, -8, -11), Vector3(24, -9, -8), Vector3(21, -9, -7)], "r": 2.2},
	# the Gloomie Squeeze, from the Moth Hall right round the west to Lantern Roots
	{"kind": "tunnel", "points": [Vector3(4, -8, 31), Vector3(-6, -9, 30), Vector3(-15, -9, 27), Vector3(-24, -10, 20),
		Vector3(-30, -10, 10), Vector3(-30, -11, 0), Vector3(-27, -11, -5)], "r": 1.9},
	{"kind": "room", "at": Vector3(-24, -10, -11), "r": 7.0, "squash": 0.6, "floor": -12.0},
	# and Lantern Roots on to the Chasm's west end
	{"kind": "tunnel", "points": [Vector3(-19, -12, -16), Vector3(-15, -14, -21), Vector3(-11, -15, -25)], "r": 2.4},
]

const ROOMS := {                           # middles, for the decorations and the tests
	"moth_hall": Vector3(10, -8, 30), "gallery": Vector3(12, -12, -1), "chasm": Vector3(0, -15, -26),
	"echo_pool": Vector3(0, -30, -26), "grotto": Vector3(26, -13, -34), "moonroot": Vector3(30, -8, -15),
	"lantern_roots": Vector3(-24, -11, -11),
}
const LIFTS := [                           # moth lifts: bottom, the height they float you to, radius
	{"at": Vector3(8, -9, 37), "top": 1.4, "r": 1.4},
	{"at": Vector3(-2.8, -31, -23.3), "top": -14.4, "r": 1.1},     # beside the bridge, not under it
]
const BOUNCERS := [                        # bouncy mushrooms: where the cap's top is, and its radius
	{"at": Vector3(11, -11.6, -3), "r": 1.1},
	{"at": Vector3(23.5, -12.4, -34), "r": 1.3},
	{"at": Vector3(28.5, -12.0, -37), "r": 1.2},
]
const BRIDGE := [Vector3(-7.0, -16.05, -26), Vector3(7.0, -16.05, -26)]
const LAKE := Vector4(1.5, -26, 3.2, 3.2)  # the Echo Pool's water (scripts/water.gd outline)
const LAKE_Y := -31.15
const MOTHS := [                           # where the five lost moonmoths hide
	Vector3(19.5, -9.6, -7),              # on the Gallery's high ledge (a double jump up)
	Vector3(2.6, -29.4, -27),             # on the Echo Pool's islet
	Vector3(28.5, -6.5, -37),             # over the Grotto, up where only a bounce reaches
	Vector3(32, -7.4, -12),               # in the Moonroot Chamber
	Vector3(-27, -11.0, -14),             # in Lantern Roots
]
const CACHE := Vector3(31.5, -8.5, -17.5)  # the Moon Cache, in the Moonroot Chamber
const GLOOMIES := [Vector3(-6, -9.4, 30), Vector3(-24, -10.5, 20), Vector3(-30, -11.4, 1)]

var world: Node3D
var field := {}
var moths: Array[Node3D] = []              # the moonmoths still to find (null once found)
var gloomies: Array[Node3D] = []
var lifting := false                       # the player's in a moth lift and going up (for the tests)
var bounces := 0                           # bounces off mushrooms (for the tests)
var _lift_motes: Array = []
var _t := 0.0
var _told_lift := false


func build(w: Node3D) -> void:
	world = w
	HOLE.cut(w, Vector2(HOLLOW.x, HOLLOW.z), HOLE_R, TOP - 0.1, 0.6)      # (before the caves are made, so it misses them)
	var res := KIT.build(self, SHAPES, {"top": TOP, "seed": 11, "name": "Glimmer Rock"})
	field = res.field
	KIT.shade_from_sun(w)
	KIT.dark_zone(self, Vector3(2.5, -18.6, -2), Vector3(76, 35.2, 84), "Glimmer Dark")
	w.set("fall_below", FALL_BELOW)
	_mouth()
	_decorate()
	for l in LIFTS:
		_add_lift(l)
	for b in BOUNCERS:
		_add_bouncer(b)
	KIT.glow_bridge(self, BRIDGE[0], BRIDGE[1], 1.8)
	_add_lake()
	for i in MOTHS.size():
		moths.append(null if Portals.has_found(w.world_id, "moth_%d" % (i + 1)) else _add_moth(i))
	_add_cache()
	for g in GLOOMIES:
		gloomies.append(_add_gloomie(g))


# The way down: a ring of old stones round the hollow, and its name -------------------------------------------------------
func _mouth() -> void:
	var g := Node3D.new()
	g.name = "Hollow"
	add_child(g)
	g.position = HOLLOW
	var stone := KIT._mat(Color(0.5, 0.45, 0.62))
	var ring := MeshInstance3D.new()
	var tube := TorusMesh.new()
	tube.inner_radius = HOLE_R - 0.1
	tube.outer_radius = HOLE_R + 0.7
	tube.rings = 32
	ring.mesh = tube
	ring.material_override = stone
	ring.scale = Vector3(1, 0.35, 1)
	g.add_child(ring)
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 1.2 + 0.4 * (i % 3), 0.45)
		s.mesh = b
		s.material_override = stone
		g.add_child(s)
		s.position = Vector3(cos(a), b.size.y * 0.5, sin(a)) * Vector3(HOLE_R + 1.2, 1, HOLE_R + 1.2)
		s.rotation = Vector3(0.08 * (i % 2), -a, 0.05)
		var moss := MeshInstance3D.new()
		var cap := BoxMesh.new()
		cap.size = Vector3(0.62, 0.1, 0.47)
		moss.mesh = cap
		moss.material_override = KIT._mat(KIT.GLOW_MOSS, 0.7)
		s.add_child(moss)
		moss.position.y = b.size.y * 0.5
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "The Glimmer Caves"
	sign.font_size = 72
	sign.outline_size = 14
	sign.modulate = Color(1.0, 0.9, 0.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.add_child(sign)
	sign.position = Vector3(0, 2.7, 0)


# Crystals, mushrooms, moss, stalactites, roots ------------------------------------------------------------------------
func _decorate() -> void:
	var f := field
	var d := Node3D.new()
	d.name = "Decorations"
	add_child(d)
	var crystal_spots := [
		[Vector3(9, -9, 33), KIT.CRYSTAL, 1.0], [Vector3(4, -9, 26), Color(0.85, 0.6, 1.0), 0.8],
		[Vector3(4, -13, -4), KIT.CRYSTAL, 1.5], [Vector3(10, -13, 7), Color(0.85, 0.6, 1.0), 1.2],
		[Vector3(18, -13, 1), Color(0.55, 1.0, 0.9), 1.6], [Vector3(13, -13, -8), KIT.CRYSTAL, 1.3],
		[Vector3(21, -13, 3), Color(1.0, 0.75, 0.9), 1.1], [Vector3(2, -13, 4), Color(0.55, 1.0, 0.9), 1.0],
		[Vector3(-10, -16, -29), KIT.CRYSTAL, 1.2], [Vector3(10, -16, -23), Color(0.85, 0.6, 1.0), 1.2],
		[Vector3(-5, -31, -30), Color(0.55, 1.0, 0.9), 1.4], [Vector3(6, -31, -21), KIT.CRYSTAL, 1.3],
		[Vector3(33, -8.5, -16), Color(1.0, 0.85, 0.55), 1.0], [Vector3(-22, -12, -7), Color(0.85, 0.6, 1.0), 1.1],
		[Vector3(-29, -10, 9), KIT.CRYSTAL, 0.7],
	]
	for i in crystal_spots.size():
		var c: Array = crystal_spots[i]
		KIT.crystals(d, KIT.floor_below(f, c[0] + Vector3(0, 1.5, 0)), c[1], 6, 40 + i, c[2])
	var mushroom_spots := [Vector3(13, -9, 27), Vector3(6, -10, 14), Vector3(5, -13, -6), Vector3(20, -13, -2),
		Vector3(-12, -16, -24), Vector3(9, -16, -29), Vector3(-6, -31, -21), Vector3(22, -14, -37),
		Vector3(29, -14, -31), Vector3(27, -8.5, -14), Vector3(-26, -12, -9), Vector3(-15, -9, 27),
		Vector3(-30, -10, 4), Vector3(18, -15, -30)]
	for i in mushroom_spots.size():
		KIT.mushrooms(d, f, mushroom_spots[i] + Vector3(0, 1.0, 0), 6, 70 + i,
			[KIT.MUSHROOM, Color(0.5, 0.9, 1.0), Color(1.0, 0.6, 0.8)][i % 3])
	for p in [Vector3(8, -9, 30), Vector3(15, -13, -2), Vector3(-2, -16, -24), Vector3(26, -14, -31),
			Vector3(-24, -12, -12), Vector3(-2, -31, -21)]:
		KIT.glow_moss(d, f, p + Vector3(0, 1.0, 0), 1.4)
	var n := 0
	for room in ROOMS:
		KIT.stalactites(d, f, ROOMS[room], 8.0 if room in ["gallery", "chasm", "echo_pool"] else 5.0, 22, 90 + n)
		n += 1
	_roots(d, ROOMS["moonroot"], Color(0.8, 0.85, 1.0), 9)
	_roots(d, ROOMS["lantern_roots"], Color(1.0, 0.8, 0.5), 11)


func _roots(parent: Node3D, centre: Vector3, colour: Color, n: int) -> void:
	# Roots hanging through the ceiling, glowing at their tips: Moon Rock's, and the lantern trees' over Lantern Roots
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centre.x * 13.0 + centre.z)
	var bark := KIT._mat(Color(0.32, 0.26, 0.36))
	bark.disable_ambient_light = true
	var tip := KIT._mat(colour, 1.8)
	for i in n:
		var a := rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.5, 4.5)
		if KIT.field_at(field, p) >= 0.0:
			continue
		var top := KIT.ceiling_above(field, p)
		var h := minf(rng.randf_range(1.2, 3.0), (top.y - KIT.floor_below(field, p).y) * 0.6)
		var r := MeshInstance3D.new()
		r.name = "Root"
		r.mesh = KIT._cone(0.05, 0.14, h, 6)
		r.material_override = bark
		parent.add_child(r)
		r.position = top + Vector3(0, 0.2 - h * 0.5, 0)
		r.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var t := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.12
		b.height = 0.24
		t.mesh = b
		t.material_override = tip
		r.add_child(t)
		t.position.y = -h * 0.5
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 0.5
	light.omni_range = 6.0
	parent.add_child(light)
	light.position = centre + Vector3(0, 1.5, 0)


# Moth lifts ------------------------------------------------------------------------------------------------------------
func _add_lift(l: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "Moth Lift"
	add_child(g)
	g.position = KIT.floor_below(field, l.at + Vector3(0, 1.0, 0))       # on the real floor, rocky as it is
	var m := KIT._mat(LIFT_GLOW, 3.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	var motes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l.at.x * 7.0)
	for i in 28:
		var mi := MeshInstance3D.new()
		mi.mesh = dot
		mi.material_override = m
		g.add_child(mi)
		motes.append({"node": mi, "a": rng.randf() * TAU, "rr": rng.randf_range(0.2, l.r), "h": rng.randf(),
			"speed": rng.randf_range(0.12, 0.22)})
	_lift_motes.append({"lift": l, "motes": motes, "node": g})
	var pad := MeshInstance3D.new()
	pad.mesh = KIT._cone(l.r, l.r, 0.05, 20)
	pad.material_override = KIT._mat(LIFT_GLOW, 1.2, 0.6)
	g.add_child(pad)
	pad.position.y = 0.04
	var light := OmniLight3D.new()
	light.light_color = LIFT_GLOW
	light.light_energy = 0.9
	light.omni_range = 5.0
	g.add_child(light)
	light.position.y = 1.0


func in_lift(p: Vector3) -> Dictionary:
	for l in LIFTS:
		if Vector2(p.x - l.at.x, p.z - l.at.z).length() <= l.r and p.y > l.at.y - 1.5 and p.y < l.top + 2.0:
			return l
	return {}


# Bouncy mushrooms ------------------------------------------------------------------------------------------------------
func _add_bouncer(b: Dictionary) -> void:
	var g := StaticBody3D.new()
	g.name = "Bouncy Mushroom"
	add_child(g)
	var foot := KIT.floor_below(field, b.at + Vector3(0, -0.3, 0))
	g.position = Vector3(b.at.x, foot.y, b.at.z)
	var h: float = b.at.y - foot.y
	var stem := MeshInstance3D.new()
	stem.mesh = KIT._cone(0.25, 0.4, h, 10)
	var sm := KIT._mat(Color(0.85, 0.82, 0.95))
	sm.disable_ambient_light = true
	stem.material_override = sm
	g.add_child(stem)
	stem.position.y = h * 0.5
	var cap := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = b.r
	sp.height = b.r
	sp.is_hemisphere = true
	cap.mesh = sp
	cap.material_override = KIT._mat(Color(1.0, 0.55, 0.85), 1.3)
	g.add_child(cap)
	cap.position.y = h - 0.35
	cap.scale = Vector3(1, 0.6, 1)
	cap.name = "Cap"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = b.r
	cyl.height = 0.3
	cs.shape = cyl
	g.add_child(cs)
	cs.position.y = h - 0.15
	var cs2 := CollisionShape3D.new()
	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = 0.35
	stem_shape.height = h
	cs2.shape = stem_shape
	g.add_child(cs2)
	cs2.position.y = h * 0.5
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.85)
	light.light_energy = 0.8
	light.omni_range = 5.0
	g.add_child(light)
	light.position.y = h + 0.6
	g.set_meta("top", b.at.y)
	g.set_meta("r", b.r)
	g.add_to_group("bouncy_mushroom")


func on_bouncer(p: Vector3) -> Node3D:
	for g in get_tree().get_nodes_in_group("bouncy_mushroom"):
		if not is_ancestor_of(g):
			continue
		var top: float = g.get_meta("top")
		var gp := (g as Node3D).global_position
		if Vector2(p.x - gp.x, p.z - gp.z).length() <= float(g.get_meta("r")) + 0.2 and absf(p.y - 0.9 - top) < 0.5:
			return g
	return null


# The Echo Pool -------------------------------------------------------------------------------------------------------------
func _add_lake() -> void:
	var w := Node3D.new()
	w.name = "Echo Pool"
	w.set_script(load("res://scripts/water.gd"))
	w.set("ellipses", [LAKE] as Array[Vector4])
	w.set("water_y", LAKE_Y)
	add_child(w)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	var disc := KIT._cone(LAKE.z + 0.6, LAKE.z + 0.6, 0.02, 32)
	surface.mesh = disc
	var m := KIT._mat(Color(0.35, 0.6, 1.0), 0.6, 0.6)
	m.disable_ambient_light = true
	surface.material_override = m
	add_child(surface)
	surface.position = Vector3(LAKE.x, LAKE_Y, LAKE.y)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.7, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 7.0
	add_child(glow)
	glow.position = Vector3(LAKE.x, LAKE_Y - 1.0, LAKE.y)


# The lost moonmoths ---------------------------------------------------------------------------------------------------------
static func moth_model() -> Node3D:
	var g := Node3D.new()
	var body := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = 0.09
	b.height = 0.32
	body.mesh = b
	body.material_override = KIT._mat(Color(0.9, 0.95, 1.0), 1.5)
	body.rotation.x = PI / 2.0
	g.add_child(body)
	for side in [-1, 1]:
		var wing := MeshInstance3D.new()
		wing.name = "Wing"
		var q := SphereMesh.new()
		q.radius = 0.2
		q.height = 0.04
		wing.mesh = q
		wing.material_override = KIT._mat(MOTH_GLOW, 2.2, 0.85)
		g.add_child(wing)
		wing.position = Vector3(0.2 * side, 0, 0)
		wing.scale = Vector3(1.0, 1.0, 1.3)
		wing.set_meta("side", side)
	var light := OmniLight3D.new()
	light.light_color = MOTH_GLOW
	light.light_energy = 0.6
	light.omni_range = 2.5
	g.add_child(light)
	return g


func _add_moth(i: int) -> Node3D:
	var m := moth_model()
	m.name = "Moonmoth%d" % (i + 1)
	m.add_to_group("glow_reveal", true)
	add_child(m)
	m.position = MOTHS[i]
	m.set_meta("home", MOTHS[i])
	return m


func moths_found() -> int:
	var n := 0
	for i in MOTHS.size():
		if Portals.has_found(world.world_id, "moth_%d" % (i + 1)):
			n += 1
	return n


func catch_moth(i: int) -> bool:
	var id := "moth_%d" % (i + 1)
	if Portals.has_found(world.world_id, id):
		return false
	Portals.note_found(world.world_id, id)
	var m := moths[i]
	moths[i] = null
	if m and is_instance_valid(m):
		m.remove_from_group("glow_reveal")
		m.visible = true
		Fx.burst(self, m.global_position, MOTH_GLOW, 16, 0.06, 2.0, 0.0, 0.8)
		var tw := m.create_tween()
		tw.tween_property(m, "position", m.position + Vector3(0, 4.0, 0), 1.6).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(m, "scale", Vector3.ONE * 0.2, 1.6)
		tw.tween_callback(m.queue_free)
	Juice.blip("sparkle", 1.2, -4.0)
	var n := moths_found()
	if n >= MOTHS.size():
		Remnants.add(MOTH_REMNANTS, "moonmoths")
		Game.add_sparkles(MOTH_SPARKLES, "moonmoths")
		Game.message("All five moonmoths home! %s and %d sparkles!" %
			[Remnants.words(MOTH_REMNANTS), MOTH_SPARKLES])
		Juice.blip("chime", 1.0, -3.0)
	else:
		Game.message("A lost moonmoth! It flutters off home to Pip. (%d of %d found)" % [n, MOTHS.size()])
	return true


# The Moon Cache ---------------------------------------------------------------------------------------------------------
func _add_cache() -> void:
	var g := Node3D.new()
	g.name = "Moon Cache"
	add_child(g)
	g.position = KIT.floor_below(field, CACHE + Vector3(0, 1.0, 0))
	var stone := KIT._mat(Color(0.55, 0.52, 0.7))
	stone.disable_ambient_light = true
	var base := MeshInstance3D.new()
	base.mesh = KIT._cone(0.55, 0.65, 0.6, 10)
	base.material_override = stone
	g.add_child(base)
	base.position.y = 0.3
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = KIT._cone(0.6, 0.6, 0.15, 10)
	lid.material_override = stone
	g.add_child(lid)
	lid.position.y = 0.68
	var moon := MeshInstance3D.new()
	var mb := SphereMesh.new()
	mb.radius = 0.16
	mb.height = 0.32
	moon.mesh = mb
	moon.material_override = KIT._mat(Color(0.9, 0.92, 1.0), 2.0)
	lid.add_child(moon)
	moon.position.y = 0.16
	if Portals.has_found(world.world_id, "moon_cache"):
		lid.position = Vector3(0.5, 0.45, 0)
		lid.rotation.z = -0.8
	var spot := USE_SPOT.make(Vector3(0, 0.3, 0),
		func() -> String: return "" if Portals.has_found(world.world_id, "moon_cache") else "open the Moon Cache",
		open_cache, 2.0, 2.0)
	spot.name = "Spot"
	g.add_child(spot)


func open_cache() -> bool:
	if Portals.has_found(world.world_id, "moon_cache"):
		return false
	Portals.note_found(world.world_id, "moon_cache")
	Remnants.add(CACHE_REMNANTS, "moon cache")
	var lid := get_node_or_null("Moon Cache/Lid") as Node3D
	if lid:
		var tw := lid.create_tween()
		tw.tween_property(lid, "position", Vector3(0.5, 0.45, 0), 0.5)
		tw.parallel().tween_property(lid, "rotation:z", -0.8, 0.5)
		Fx.burst(self, lid.global_position, Color(0.9, 0.95, 1.0), 20, 0.08, 2.5, -1.0, 0.8)
	Juice.blip("chime", 1.2, -3.0)
	Game.message("The Moon Cache! Moonlight crystals inside: %s." % Remnants.words(CACHE_REMNANTS))
	return true


# Gloomies -------------------------------------------------------------------------------------------------------------------
static func gloomie_model() -> Node3D:
	var g := Node3D.new()
	var fluff := MeshInstance3D.new()
	fluff.name = "Fluff"
	var b := SphereMesh.new()
	b.radius = 0.45
	b.height = 0.8
	fluff.mesh = b
	var m := KIT._mat(Color(0.1, 0.06, 0.16))
	m.roughness = 1.0
	fluff.material_override = m
	g.add_child(fluff)
	fluff.position.y = 0.4
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var e := SphereMesh.new()
		e.radius = 0.11
		e.height = 0.22
		eye.mesh = e
		eye.material_override = KIT._mat(Color(1.0, 1.0, 0.85), 2.5)
		fluff.add_child(eye)
		eye.position = Vector3(0.15 * side, 0.08, 0.36)
		var pupil := MeshInstance3D.new()
		var pp := SphereMesh.new()
		pp.radius = 0.05
		pp.height = 0.1
		pupil.mesh = pp
		pupil.material_override = KIT._mat(Color(0.05, 0.02, 0.1))
		eye.add_child(pupil)
		pupil.position = Vector3(0, 0, 0.08)
	return g


func _add_gloomie(at: Vector3) -> Node3D:
	var g := gloomie_model()
	g.name = "Gloomie"
	add_child(g)
	g.position = KIT.floor_below(field, at + Vector3(0, 0.6, 0))
	g.set_meta("home", g.position)
	g.set_meta("shy", 0.0)
	return g


# Every frame ---------------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var p := player.global_position
	# A moth lift: hold Jump and the moths float you up
	lifting = false
	var l := in_lift(p)
	if not l.is_empty():
		if not _told_lift:
			_told_lift = true
			Game.message(Settings.fill("A moth lift! Hold {jump} and the moths will float you up."))
		if Input.is_action_pressed("jump") and not player.input_locked:
			lifting = true
			if p.y < l.top:
				player.velocity.y = move_toward(player.velocity.y, LIFT_SPEED, 30.0 * delta)
			else:
				player.velocity.y = maxf(player.velocity.y, 0.0)
	# A bouncy mushroom springs you up off its cap
	if player.velocity.y <= 0.5 and player.is_on_floor():
		var b := on_bouncer(p)
		if b:
			player.velocity.y = BOUNCE
			bounces += 1
			var cap := b.get_node_or_null("Cap") as Node3D
			if cap:
				var tw := cap.create_tween()
				tw.tween_property(cap, "scale", Vector3(1.25, 0.35, 1.25), 0.07)
				tw.tween_property(cap, "scale", Vector3(1, 0.6, 1), 0.25).set_trans(Tween.TRANS_ELASTIC)
			Juice.blip("pop", 0.7, -4.0)


func _process(delta: float) -> void:
	_t += delta
	for lm in _lift_motes:
		var lf: Dictionary = lm.lift
		var height: float = lf.top - (lm.node as Node3D).position.y + 1.0
		for mo in lm.motes:
			mo.h = fposmod(mo.h + mo.speed * delta * 6.0 / height, 1.0)
			var a: float = mo.a + _t * 0.8
			(mo.node as Node3D).position = Vector3(cos(a) * mo.rr, mo.h * height, sin(a) * mo.rr)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var glow: Node = player.get("pip_glow") if player else null
	for i in moths.size():
		var m := moths[i]
		if m == null or not is_instance_valid(m):
			continue
		var home: Vector3 = m.get_meta("home")
		m.position = home + Vector3(sin(_t * 1.3 + i) * 0.25, sin(_t * 2.1 + i) * 0.15, cos(_t * 1.1 + i) * 0.25)
		for wing in m.get_children():
			if wing.has_meta("side"):
				(wing as Node3D).rotation.z = sin(_t * 14.0 + i) * 0.6 * float(wing.get_meta("side"))
		if player and player.global_position.distance_to(m.global_position + Vector3(0, -0.6, 0)) < MOTH_NEAR \
				and (glow == null or glow.shining()):
			catch_moth(i)
	for g in gloomies:
		if g == null or not is_instance_valid(g):
			continue
		var home: Vector3 = g.get_meta("home")
		var shy: float = g.get_meta("shy")
		var near: bool = player != null and glow != null and glow.shining() \
			and player.global_position.distance_to(home) < GLOOMIE_SHY
		shy = move_toward(shy, 1.0 if near else 0.0, delta * (2.5 if near else 0.4))
		g.set_meta("shy", shy)
		var away := Vector3.ZERO
		if player:
			away = (home - player.global_position)
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		g.position = home + away * shy * 3.0 + Vector3(0, absf(sin(_t * 9.0)) * 0.12 * shy, 0)
		g.scale = Vector3.ONE * lerpf(1.0, 0.25, shy)
		g.visible = shy < 0.98
		if player and shy < 0.5:
			var look := player.global_position
			look.y = g.global_position.y
			if look.distance_to(g.global_position) > 0.1:
				g.look_at(look, Vector3.UP, true)


func gloomie_hiding(i: int) -> bool:
	return float(gloomies[i].get_meta("shy")) > 0.9
