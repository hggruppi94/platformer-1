class_name ShockRing
extends Node3D

# A ring that rolls out across the ground from a boss (Grandfather Tock's chimes, the Boulderdillo's slams, the Agent
# of Chaos's big ring...). It only bumps the player if they're standing on the ground right where the ring's edge is
# passing, so jumping over it is always the trick. Kid-safe: a bump, like touching a Gloop.
#
# Every boss's ring has its own look (Hayden, 21 Nov 2026: "If there is a Shockwave, it needs to be unique and have
# more intricate visuals"). A style (STYLES) dresses the same rolling edge: a glowing band, a fainter echo rolling
# behind it, sometimes a see-through curtain rising off it, little shapes riding the edge (goo blobs, gears, notes,
# rocks, glitch cubes, thorns...: scripts/boss_bits.gd) and things it leaves in its wake (drips, ice spikes, dust,
# embers, feathers...). The style never changes where the edge is or when it bumps you: only how it looks.
#
#   ShockRing.spawn(parent, at, reach, colour, damage, time, style)

const BITS := preload("res://scripts/boss_bits.gd")
const GOLD := Color(1.0, 0.82, 0.3)
const WHITE := Color(1.0, 1.0, 1.0)
const DARK := Color(0.12, 0.08, 0.2)

# Each style:
#   band   [thickness (of the radius), height, glow] of the main band
#   echo   a fainter band rolling a little way behind the edge
#   wall   how tall a see-through curtain rises off the edge (0: none)
#   bits   shapes riding the edge: k (boss_bits.gd kind), n (how many on a 10 m ring), s (size), c (colour: none is
#          the ring's own, "light"/"dark" a shade of it), move (how they ride: see _ride()), y (how high)
#   trail  what it leaves behind as it goes: k, every (seconds), s, c, move (see _leave())
const STYLES := {
	"plain": {"band": [0.12, 3.0, 1.2], "echo": true, "wall": 0.0,
		"bits": [{"k": "spark", "n": 18, "s": 0.16, "c": "light", "move": "rise"}],
		"trail": {}},
	# The Gloop King: a rolling wave of shiny goo with blobs sloshing on its crest, gold flecks, and drips left behind
	"goo": {"band": [0.2, 2.2, 0.8], "echo": true, "wall": 0.7, "glossy": true,
		"bits": [{"k": "blob", "n": 22, "s": 0.5, "move": "bob", "y": 0.25},
			{"k": "fleck", "n": 14, "s": 0.12, "c": GOLD, "move": "sparkle", "y": 0.55}],
		"trail": {"k": "drop", "every": 0.04, "s": 0.2, "move": "fall"}},
	# Tuskwinter: a frosty edge that throws up ice spikes in its wake, with snowflakes swirling up
	"frost": {"band": [0.08, 2.0, 1.4], "echo": true, "wall": 1.1,
		"bits": [{"k": "shard", "n": 20, "s": 0.9, "c": "light", "move": "pop"},
			{"k": "star", "n": 12, "s": 0.22, "c": WHITE, "move": "rise"}],
		"trail": {"k": "shard", "every": 0.035, "s": 0.7, "c": "light", "move": "spike"}},
	# Grumblefin: a sea wave with foam bubbles riding its crest and spray left behind
	"tide": {"band": [0.18, 3.0, 0.9], "echo": true, "wall": 1.4, "glossy": true,
		"bits": [{"k": "bubble", "n": 24, "s": 0.32, "c": WHITE, "move": "bob", "y": 0.9},
			{"k": "drop", "n": 12, "s": 0.18, "c": "light", "move": "rise"}],
		"trail": {"k": "bubble", "every": 0.05, "s": 0.22, "c": WHITE, "move": "rise"}},
	# Grandfather Tock: a ring of chimes: spinning gears and clock ticks round the edge, notes floating off it
	"chime": {"band": [0.06, 2.5, 1.8], "echo": true, "wall": 0.0,
		"bits": [{"k": "gear", "n": 10, "s": 0.8, "move": "spin", "y": 0.0},
			{"k": "bar", "n": 24, "s": 0.35, "c": GOLD, "move": "tick"},
			{"k": "note", "n": 8, "s": 0.5, "c": "light", "move": "rise"}],
		"trail": {"k": "note", "every": 0.09, "s": 0.45, "c": "light", "move": "rise"}},
	# The Dawn Snatcher: a gust of night feathers with stolen sunlight glinting in it
	"dawn": {"band": [0.08, 2.0, 1.5], "echo": true, "wall": 0.6,
		"bits": [{"k": "feather", "n": 16, "s": 0.8, "c": DARK, "move": "tumble", "y": 0.4},
			{"k": "spark", "n": 14, "s": 0.16, "c": GOLD, "move": "rise"}],
		"trail": {"k": "feather", "every": 0.07, "s": 0.6, "c": DARK, "move": "drift"}},
	# The Boulderdillo: rubble tumbling along the edge, pebbles hopping, dust rolling up behind
	"rubble": {"band": [0.22, 1.6, 0.4], "echo": false, "wall": 0.8,
		"bits": [{"k": "rock", "n": 18, "s": 0.6, "c": "dark", "move": "tumble", "y": 0.2},
			{"k": "rock", "n": 16, "s": 0.22, "move": "hop"}],
		"trail": {"k": "blob", "every": 0.04, "s": 0.7, "c": "light", "move": "puff"}},
	# The Stormram: a gust of storm wind: leaves swirling up, little lightning bolts flickering in it
	"gust": {"band": [0.05, 3.0, 1.4], "echo": true, "wall": 1.6,
		"bits": [{"k": "leaf", "n": 18, "s": 0.6, "c": Color(0.55, 0.9, 0.4), "move": "swirl"},
			{"k": "bolt", "n": 7, "s": 1.0, "c": Color(1.0, 0.95, 0.5), "move": "flicker"}],
		"trail": {"k": "leaf", "every": 0.06, "s": 0.5, "c": Color(0.55, 0.9, 0.4), "move": "drift"}},
	# The Off-Beat: a heat ring that throbs like a speaker: equaliser bars bouncing, little flames, sour notes
	"beat": {"band": [0.1, 2.0, 1.6], "echo": true, "wall": 0.0,
		"bits": [{"k": "bar", "n": 28, "s": 1.0, "move": "pulse"},
			{"k": "flame", "n": 10, "s": 0.6, "c": Color(1.0, 0.55, 0.2), "move": "lick"},
			{"k": "note", "n": 6, "s": 0.55, "c": "light", "move": "rise"}],
		"trail": {"k": "ember", "every": 0.05, "s": 0.12, "c": Color(1.0, 0.6, 0.25), "move": "rise"}},
	# Captain Glitch: glitch cubes snapping about on the edge, which flickers like a bad picture
	"glitch": {"band": [0.1, 2.5, 1.6], "echo": true, "wall": 0.9, "flicker": true,
		"bits": [{"k": "cube", "n": 22, "s": 0.4, "move": "jitter", "y": 0.3},
			{"k": "cube", "n": 14, "s": 0.2, "c": Color(0.35, 1.0, 0.95), "move": "jitter", "y": 0.8}],
		"trail": {"k": "cube", "every": 0.05, "s": 0.3, "c": "light", "move": "blink"}},
	# Fizzlers and Big Buzz: crackling static: bolts snapping up off the edge and sparks hopping
	"static": {"band": [0.05, 2.0, 2.0], "echo": true, "wall": 0.0, "flicker": true,
		"bits": [{"k": "bolt", "n": 14, "s": 0.9, "move": "flicker"},
			{"k": "spark", "n": 16, "s": 0.14, "c": WHITE, "move": "hop"}],
		"trail": {"k": "spark", "every": 0.04, "s": 0.12, "c": "light", "move": "rise"}},
	# The Gloam: a wave of gloom: dark wisps curling up off it, with tiny stars twinkling in the dark
	"gloom": {"band": [0.14, 2.0, 0.8], "echo": true, "wall": 1.3,
		"bits": [{"k": "wisp", "n": 18, "s": 0.7, "c": "dark", "move": "rise"},
			{"k": "star", "n": 10, "s": 0.2, "c": "light", "move": "sparkle", "y": 0.6}],
		"trail": {"k": "wisp", "every": 0.06, "s": 0.6, "c": "dark", "move": "rise"}},
	# The Hush: a pale, soft "Shhhh": mist curling up and little ghost wisps floating off
	"hush": {"band": [0.1, 2.0, 1.0], "echo": true, "wall": 1.0,
		"bits": [{"k": "wisp", "n": 16, "s": 0.6, "c": "light", "move": "rise"},
			{"k": "blob", "n": 12, "s": 0.4, "c": WHITE, "move": "bob", "y": 0.1}],
		"trail": {"k": "wisp", "every": 0.07, "s": 0.5, "c": "light", "move": "rise"}},
	# The Agent of Chaos: a gold ring with a tall chaos curtain, glitch cubes, magenta cracks, gold skulls and sparks
	"chaos": {"band": [0.08, 3.0, 2.0], "echo": true, "wall": 1.8, "flicker": true,
		"bits": [{"k": "cube", "n": 26, "s": 0.5, "c": Color(0.55, 0.2, 0.8), "move": "jitter", "y": 0.4},
			{"k": "bolt", "n": 10, "s": 1.2, "c": Color(1.0, 0.3, 0.75), "move": "flicker"},
			{"k": "skull", "n": 6, "s": 0.7, "c": GOLD, "move": "bob", "y": 0.3},
			{"k": "spark", "n": 16, "s": 0.16, "c": GOLD, "move": "rise"}],
		"trail": {"k": "cube", "every": 0.035, "s": 0.35, "c": Color(0.55, 0.2, 0.8), "move": "blink"}},
	# The Starhorn: starlight: crystal shards bursting up, stars spinning round the edge
	"star": {"band": [0.08, 2.5, 2.0], "echo": true, "wall": 0.9,
		"bits": [{"k": "star", "n": 12, "s": 0.6, "c": "light", "move": "spin", "y": 0.3},
			{"k": "shard", "n": 14, "s": 0.9, "move": "pop"}],
		"trail": {"k": "star", "every": 0.06, "s": 0.3, "c": "light", "move": "rise"}},
	# Old Ember: a ring of lava: crusted rock tumbling in it, flames licking up, embers flying
	"lava": {"band": [0.22, 1.8, 2.2], "echo": true, "wall": 0.8,
		"bits": [{"k": "rock", "n": 14, "s": 0.5, "c": Color(0.18, 0.1, 0.08), "move": "tumble", "y": 0.15},
			{"k": "flame", "n": 16, "s": 0.8, "c": Color(1.0, 0.75, 0.25), "move": "lick"},
			{"k": "ember", "n": 14, "s": 0.12, "c": Color(1.0, 0.9, 0.4), "move": "rise"}],
		"trail": {"k": "ember", "every": 0.03, "s": 0.14, "c": Color(1.0, 0.65, 0.2), "move": "rise"}},
	# Cyber gorillas: a pulse of red energy, three thin bands like a scan, sparks off it
	"energy": {"band": [0.05, 1.5, 2.4], "echo": true, "wall": 0.6, "scan": true,
		"bits": [{"k": "bar", "n": 16, "s": 0.5, "move": "pulse"},
			{"k": "spark", "n": 12, "s": 0.14, "c": WHITE, "move": "hop"}],
		"trail": {"k": "spark", "every": 0.05, "s": 0.12, "move": "rise"}},
	# The Thornknot: thorny vines lashing up out of the ground, with leaves and petals flying
	"thorn": {"band": [0.1, 1.5, 0.9], "echo": false, "wall": 0.0,
		"bits": [{"k": "thorn", "n": 26, "s": 1.0, "move": "pop"},
			{"k": "leaf", "n": 10, "s": 0.5, "c": Color(0.45, 0.85, 0.35), "move": "swirl"}],
		"trail": {"k": "petal", "every": 0.06, "s": 0.4, "c": Color(1.0, 0.6, 0.85), "move": "drift"}},
	# Glimmerwing: stardust and little moths fluttering round the edge
	"moth": {"band": [0.07, 2.0, 1.8], "echo": true, "wall": 0.7,
		"bits": [{"k": "moth", "n": 10, "s": 0.7, "c": "light", "move": "flutter", "y": 0.4},
			{"k": "star", "n": 10, "s": 0.22, "c": WHITE, "move": "sparkle", "y": 0.5}],
		"trail": {"k": "spark", "every": 0.04, "s": 0.12, "c": "light", "move": "rise"}},
	# Old Bubblebeard: a splash of pond water full of bubbles, lily-green
	"bubble": {"band": [0.16, 2.2, 0.8], "echo": true, "wall": 1.0, "glossy": true,
		"bits": [{"k": "bubble", "n": 26, "s": 0.42, "c": "light", "move": "bob", "y": 0.4}],
		"trail": {"k": "bubble", "every": 0.045, "s": 0.3, "c": "light", "move": "rise"}},
	# Ribbontail: a kite's gust: ribbons streaming and waving, bright paper confetti
	"ribbon": {"band": [0.06, 2.5, 1.4], "echo": true, "wall": 1.2,
		"bits": [{"k": "ribbon", "n": 14, "s": 1.2, "move": "flutter", "y": 0.5},
			{"k": "petal", "n": 14, "s": 0.3, "c": Color(1.0, 0.9, 0.4), "move": "swirl"}],
		"trail": {"k": "petal", "every": 0.05, "s": 0.3, "c": Color(0.5, 0.8, 1.0), "move": "drift"}},
}

var reach := 6.0
var time := 0.8
var damage := 2
var colour := Color(1, 1, 1)
var style := "plain"
var _t := 0.0
var _hit := false
var _band: MeshInstance3D
var _echo: MeshInstance3D
var _wall: MeshInstance3D
var _scans: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []      # faded together as the ring dies away
var _alphas: Array[float] = []
var _bits: Array[Dictionary] = []             # {node, a, ph, move, s, y}
var _trail := {}
var _trail_t := 0.0
var _trail_mat: StandardMaterial3D
var _jit_t := 0.0


static func spawn(parent: Node, at: Vector3, reach_m: float, col: Color, dmg := 2, secs := 0.8, look := "plain") -> ShockRing:
	var r := ShockRing.new()
	r.name = "ShockRing"
	r.reach = reach_m
	r.colour = col
	r.damage = dmg
	r.time = secs
	r.style = look if STYLES.has(look) else "plain"
	parent.add_child(r)
	r.global_position = at + Vector3(0, 0.15, 0)
	return r


func _ready() -> void:
	var st: Dictionary = STYLES[style]
	var band: Array = st.band
	_band = _torus("Band", 1.0 - float(band[0]), colour, float(band[2]), 0.85, bool(st.get("glossy", false)))
	if st.get("echo", false):
		_echo = _torus("Echo", 0.94, colour.lightened(0.3), float(band[2]) * 0.6, 0.35, false)
	if st.get("scan", false):
		for i in 2:
			_scans.append(_torus("Scan %d" % (i + 1), 0.97, colour.lightened(0.2), float(band[2]), 0.6, false))
	if float(st.get("wall", 0.0)) > 0.0:
		_make_wall()
	var big := clampf(reach / 10.0, 0.4, 2.2)              # more shapes on a bigger ring
	var size := clampf(reach / 8.0, 0.6, 1.4)
	var holder := Node3D.new()
	holder.name = "Bits"
	add_child(holder)
	for b in st.bits:
		var bit: Dictionary = b
		var n := maxi(4, roundi(float(bit.n) * big))
		var m := _mat_for(bit.get("c", null), 1.6)
		var mesh := BITS.mesh(str(bit.k))
		for i in n:
			var piece := MeshInstance3D.new()
			piece.mesh = mesh
			piece.material_override = m
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(piece)
			_bits.append({"node": piece, "a": TAU * (i + randf_range(-0.3, 0.3)) / n, "ph": randf(),
				"move": str(bit.move), "s": float(bit.s) * size * randf_range(0.8, 1.2), "y": float(bit.get("y", 0.0)),
				"spin": randf_range(-1.0, 1.0)})
	_trail = st.get("trail", {})
	if not _trail.is_empty():
		_trail_mat = BITS.mat(_shade(_trail.get("c", null)), 1.6)
	_place(radius(), 1.0)


func radius() -> float:
	return lerpf(0.3, reach, clampf(_t / time, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_t += delta
	var r := radius()
	var fade := 1.0 - clampf((_t - time * 0.6) / (time * 0.4), 0.0, 1.0)
	_place(r, fade)
	_leave_trail(delta, r, fade)
	if not _hit and damage > 0:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.is_on_floor() and not p.is_invulnerable():
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if absf(d - r) < 0.9 and absf(p.global_position.y - 0.8 - global_position.y) < 1.5:
				_hit = true
				p.hurt(damage, global_position)
	if _t >= time:
		queue_free()


# -----------------------------------------------------------------------------
# The look
# -----------------------------------------------------------------------------
func _shade(c: Variant) -> Color:
	if c is Color:
		return c
	if str(c) == "light":
		return colour.lightened(0.45)
	if str(c) == "dark":
		return colour.darkened(0.45)
	return colour


func _mat_for(c: Variant, glow: float) -> StandardMaterial3D:
	var m := BITS.mat(_shade(c), glow, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.append(m)
	_alphas.append(1.0)
	return m


func _torus(nm: String, inner: float, col: Color, glow: float, alpha: float, glossy: bool) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = tm
	var m := BITS.mat(col, glow, alpha, glossy)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.append(m)
	_alphas.append(alpha)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _make_wall() -> void:
	# A see-through curtain rising off the edge, strongest at the bottom and fading out at the top
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 48
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 32
	var m := BITS.mat(colour.lightened(0.2), 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.append(m)
	_alphas.append(0.45)
	_wall = MeshInstance3D.new()
	_wall.name = "Wall"
	_wall.mesh = cm
	_wall.material_override = m
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)


func _place(r: float, fade: float) -> void:
	var st: Dictionary = STYLES[style]
	var band: Array = st.band
	var h := float(band[1])
	_band.scale = Vector3(r, h, r)
	if _echo:
		var er := maxf(0.2, r * 0.82)
		_echo.scale = Vector3(er, h * 0.6, er)
	for i in _scans.size():
		var sr := maxf(0.2, r * (0.9 - 0.08 * i))
		_scans[i].scale = Vector3(sr, h * 0.5, sr)
	if _wall:
		var wh := float(st.wall) * (0.6 + 0.4 * fade)
		_wall.scale = Vector3(r, wh, r)
		_wall.position.y = wh * 0.5
	var flick := 1.0
	if st.get("flicker", false) and not Settings.reduce_flashing:
		flick = 0.55 + 0.45 * float(int(_t * 30.0) % 3 != 0)
	for i in _mats.size():
		_mats[i].albedo_color.a = _alphas[i] * fade * flick
	_jit_t -= get_physics_process_delta_time()
	var snap := _jit_t <= 0.0
	if snap:
		_jit_t = 0.06
	for b in _bits:
		_ride(b, r, fade, snap)


# How each shape rides the edge
func _ride(b: Dictionary, r: float, fade: float, snap: bool) -> void:
	var n: MeshInstance3D = b.node
	var s: float = b.s * (0.3 + 0.7 * fade)
	var a: float = b.a
	var y: float = b.y
	var t := _t
	var ph: float = b.ph
	var sc := Vector3.ONE * s
	var rot := Vector3(0, a, 0)
	var rr := r
	match b.move:
		"bob":
			y += 0.15 * s * sin(t * 9.0 + ph * TAU)
			sc *= 1.0 + 0.2 * sin(t * 7.0 + ph * TAU)
		"spin":
			rot.z = t * 6.0 * (1.0 if b.spin > 0.0 else -1.0)
		"rise":
			var u := fmod(t * 1.6 + ph, 1.0)
			y += u * 1.8
			rr -= u * 0.4
			sc *= 1.0 - u
			rot.y += u * 2.0
		"pop":
			var u := fmod(t * 2.2 + ph, 1.0)
			sc = Vector3(s, s * sin(PI * u), s)
			rot.x = 0.35                                          # leaning out, the way the ring's going
		"tumble":
			rot = Vector3(t * 7.0 * b.spin, a, t * 5.0)
			y += absf(sin(t * 8.0 + ph * TAU)) * 0.3 * s
		"hop":
			y += absf(sin(t * 11.0 + ph * TAU)) * 0.6
		"flicker":
			n.visible = fmod(t * 9.0 + ph * 3.0, 1.0) < 0.55
			if snap:
				b.a = a + randf_range(-0.05, 0.05)
			rot.y += sin(t * 40.0 + ph * 9.0) * 0.6
			sc *= 0.7 + 0.3 * fmod(t * 13.0 + ph, 1.0)
		"jitter":
			if snap:
				b.j = Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.5), randf_range(-0.25, 0.25))
				b.jr = Vector3(randf() * TAU, randf() * TAU, 0)
			var j: Vector3 = b.get("j", Vector3.ZERO)
			y += j.y
			rr += j.x
			rot += b.get("jr", Vector3.ZERO)
		"sparkle":
			sc *= absf(sin(t * 12.0 + ph * TAU))
			rot.z = t * 4.0
		"tick":
			sc = Vector3(s * 0.6, s * (0.6 + 0.4 * float(int(t * 8.0 + ph * 8.0) % 2)), s * 0.6)
		"pulse":
			sc = Vector3(s * 0.6, s * (0.25 + 0.95 * absf(sin(t * 10.0 + a * 3.0))), s * 0.6)
		"lick":
			sc = Vector3(s, s * (0.6 + 0.6 * absf(sin(t * 14.0 + ph * TAU))), s)
			rot.y += sin(t * 9.0 + ph) * 0.4
		"swirl":
			var u := fmod(t * 1.3 + ph, 1.0)
			a += u * 1.4
			y += u * 2.4
			sc *= 1.0 - u * 0.6
			rot = Vector3(t * 6.0, a, t * 4.0 * b.spin)
		"flutter":
			y += 0.3 * sin(t * 6.0 + ph * TAU)
			rot.x = sin(t * 18.0 + ph * TAU) * 0.6
			rot.z = sin(t * 5.0 + ph) * 0.4
	n.position = Vector3(sin(a), 0, cos(a)) * rr + Vector3(0, y, 0)
	n.rotation = rot
	n.scale = sc.max(Vector3.ONE * 0.001)


# What the ring leaves behind it as it goes: these stay in the world a moment after the edge has passed
func _leave_trail(delta: float, r: float, fade: float) -> void:
	if _trail.is_empty() or fade < 0.3 or r < 1.0:
		return
	_trail_t -= delta
	var every := float(_trail.every) * clampf(10.0 / maxf(reach, 1.0), 0.5, 2.0)
	while _trail_t <= 0.0:
		_trail_t += every
		var a := randf() * TAU
		var at := global_position + Vector3(sin(a), 0, cos(a)) * r * randf_range(0.92, 1.0)
		_leave(at, a)


func _leave(at: Vector3, a: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var n := MeshInstance3D.new()
	n.name = "Ring Bit"
	n.mesh = BITS.mesh(str(_trail.k))
	n.material_override = _trail_mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	var s := float(_trail.s) * clampf(reach / 8.0, 0.6, 1.4) * randf_range(0.7, 1.3)
	n.global_position = at
	n.rotation = Vector3(0, a, 0)
	n.scale = Vector3.ONE * s
	var tw := n.create_tween()
	match str(_trail.get("move", "rise")):
		"fall":                                                     # a drip falling off the crest
			n.global_position.y += 0.6
			tw.set_parallel()
			tw.tween_property(n, "global_position:y", at.y - 0.05, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(n, "scale", Vector3(s * 1.6, s * 0.2, s * 1.6), 0.15).set_delay(0.45)
			tw.chain().tween_property(n, "scale", Vector3.ONE * 0.001, 0.35)
		"spike":                                                    # an ice spike shooting up, then shattering away
			n.scale = Vector3(s, 0.001, s)
			n.rotation.x = randf_range(-0.3, 0.3)
			tw.tween_property(n, "scale", Vector3(s, s * 1.4, s), 0.1).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.35)
			tw.tween_property(n, "scale", Vector3(s * 0.2, 0.001, s * 0.2), 0.25).set_ease(Tween.EASE_IN)
		"puff":                                                     # dust billowing up and away
			tw.set_parallel()
			tw.tween_property(n, "scale", Vector3.ONE * s * 2.6, 0.7).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "global_position:y", at.y + 0.9, 0.7)
			tw.chain().tween_property(n, "scale", Vector3.ONE * 0.001, 0.25)
		"blink":                                                    # a glitch cube that pops in, flickers and goes
			n.global_position.y += randf_range(0.2, 1.4)
			tw.tween_property(n, "scale", Vector3.ONE * s * 1.3, 0.05)
			for i in 3:
				tw.tween_interval(0.07)
				tw.tween_callback(n.set_visible.bind(false))
				tw.tween_interval(0.05)
				tw.tween_callback(n.set_visible.bind(true))
			tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.1)
		"drift":                                                    # a feather, leaf or petal floating down
			n.global_position.y += randf_range(1.0, 2.2)
			tw.set_parallel()
			tw.tween_property(n, "global_position:y", at.y + 0.05, 1.1).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "rotation", Vector3(randf_range(-2, 2), a + randf_range(-3, 3), randf_range(-2, 2)), 1.1)
			tw.chain().tween_property(n, "scale", Vector3.ONE * 0.001, 0.3)
		_:                                                          # "rise": floating up and away
			tw.set_parallel()
			tw.tween_property(n, "global_position:y", at.y + randf_range(1.2, 2.6), 0.8).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(n.queue_free)
