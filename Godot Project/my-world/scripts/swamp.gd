extends Node3D

# Swamps (Hayden, 24 Nov 2026: "I want to add a swamp to lanternmoor and a super poison swamp to ducks embrace", and
# "siren-type enemies with giant malformed heads that will slowly wander the swamp and their loud call summons hordes
# of smaller enemies"). Both are put in at play time (no scene rebuilt): `place(world, kind)` from
# scripts/lanternmoor.gd setup() and scripts/scary_world.gd _ready(). Each lies past the edge of its world: a gap
# opens in the fence (or the wood) and a causeway leads out to a round basin of water with islands in it, hills or
# trees all round, and its own fence ("WorldBounds Swamp Fence", so the map's picture takes it in).
#
#   "lanternmoor"  the Mothmire, east of the moor. Atmospheric, not dangerous: dark teal murk you can wade through
#                  (scripts/water.gd: slow, splashy, never deep enough to swim), duckweed, lily pads with glowing
#                  flowers, reeds and cattails, dead mangroves dripping moss, fireflies, wisps, frogs that croak and
#                  hop away, low mist, a broken boardwalk, the Old Mire Hut on its stilts with a lantern, and the Mire
#                  Chest on Glow Isle. One Bog Wailer wanders it (scripts/bog_wailer.gd).
#   "dusk"         the Poison Mire, west of Dusk's Embrace's clearing (through the trees behind the eyes). SUPER
#                  poison: glowing acid-green goo you mustn't touch. Step in and it bumps you (1) and puts you back
#                  where you last stood safe ("Yuck! Super poison!"); a bump, never more, like the volcano's lava. The
#                  way across is the challenge: stepping stones, some of them Sinker Stones that wobble and sink a
#                  moment after you land (they're darker, cracked, with bubbles round them, for those who look), a
#                  mossy log bridge, poison vents that swell and burp a ring of goo across the stones (jump it), and
#                  drifting poison clouds to dodge. Three Bog Wailers call Mucklings. At the far side, the Bog Heart
#                  chest, and a bog bubble that floats you home.
#
# What we read first (Hayden's rule): Malidos/Stylized-Water-Shader (CC0) and paddy-exe/Godot-3D-Stylized-Water (MIT)
# for depth-tinted water with an edge (scripts/swamp_water.gdshader), Chrisknyfe/boujie_water_shader (MIT, waves: not
# for a still bog), Bauxitedev/volumetric-fog-demo (MIT, particle fog: slow) against Godot's FogVolume (used, with
# cheap mist sheets, scripts/swamp_mist.gdshader, for the Simple lighting level). The poison works like the volcano's
# lava (scripts/volcano_depths.gd _lava_bump), and the sinking stones like a "crumbling platform" with a shake first.

const NODE := "Swamp"
const WATER := preload("res://scripts/water.gd")
const WATER_SHADER := preload("res://scripts/swamp_water.gdshader")
const MIST_SHADER := preload("res://scripts/swamp_mist.gdshader")
const WAILER := preload("res://scripts/bog_wailer.gd")
const WISP := preload("res://scripts/wisp.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const DANGERS := preload("res://scripts/swamp_dangers.gd")

const SURFACE := -0.12                   # the water's (or goo's) top
const BED := -0.8                        # the basin's floor, under it
const WALK_TOP := 0.28                   # the boardwalks' planks
const STONE_TOP := 0.06
const SINK_AFTER := 0.75                 # a Sinker Stone wobbles this long after she lands on it...
const SINK_WOBBLE := 0.6                 # ...for this long, then sinks...
const SINK_DOWN := 2.2                   # ...stays down this long, then comes back up
const SINK_DEPTH := 1.3
const VENT_EVERY := 5.0
const VENT_SWELL := 1.1
const CLOUD_R := 1.8
const POISON_TELL := 8.0                 # seconds between "Yuck!" messages
const LOOK_TOP := 14.0                   # the lookout's platform, high over the swamp (Hayden: "a view high up at the end")
const LOOK_IN := 0.9                     # its dead tree's trunk...
const LOOK_OUT := 2.4                    # ...and the stair winding round it (1.5 m wide)
const LOOK_RING := 3.6                   # the platform round the top
const LOOK_TURNS := 2.6                  # (about 26 degrees up all the way: walkable on foot)
const LOOK_STEPS := 20                   # stair pieces a turn

const LAYOUTS := {
	"lanternmoor": {
		"title": "the Mothmire", "centre": Vector3(104, 0, 0), "r": 46.0, "poison": false,
		"gap_from": Vector3(42, 0, 0), "gap_to": Vector3(60, 0, 0), "gap_w": 7.0, "world_edge": 46.6,
		"hello": "The Mothmire. Hush... something's out there.",
		# [x, z, radius, name]
		"islands": [[62.0, 0.0, 5.5, "Mire Edge"], [78.0, 12.0, 4.5, "Reed Isle"], [94.0, -4.0, 6.0, "Hut Isle"],
			[110.0, 14.0, 5.0, "Lantern Isle"], [100.0, -26.0, 4.5, "Old Tree Isle"], [126.0, 4.0, 4.0, "Glow Isle"],
			[118.0, -16.0, 3.5, "Frog Isle"], [88.0, 30.0, 3.5, "Moth Isle"],
			[76.0, -18.0, 3.0, "Lost Isle"], [122.0, 26.0, 3.0, "Fooler's Isle"]],    # (dead ends, with a Muck Mimic)
		# boardwalks [from island, to island, broken from, broken to (0..1 along it; equal = not broken)]
		"walks": [[0, 1, 0.0, 0.0], [1, 2, 0.3, 0.7], [2, 3, 0.0, 0.0], [3, 5, 0.0, 0.0], [2, 4, 0.0, 0.0],
			[4, 6, 0.35, 0.65], [6, 5, 0.0, 0.0], [1, 7, 0.0, 0.0], [2, 8, 0.4, 0.55], [3, 9, 0.0, 0.0]],
		"stones": [], "logs": [], "vents": [], "clouds": [],
		"wailers": [[100.0, 8.0, 10.0], [112.0, -12.0, 9.0]],
		"chest": 5, "hut": 2,
		# what makes it hard (scripts/swamp_dangers.gd): dead-end islands with a Muck Mimic, a sign that fibs, the
		# giant asleep in the mud [x, z, name], how many Snap Traps and Lurkers
		"decoys": [8, 9], "fib_sign": [1, 9, "Chest this way!"], "giant": [106.0, -12.0, "Old Mossback"],
		"water": {"murk": Color(0.1, 0.22, 0.18), "deep": Color(0.02, 0.06, 0.05), "scum": Color(0.26, 0.42, 0.16),
			"glow": 0.0, "glow_colour": Color(0.6, 0.8, 1.0), "scum_amount": 0.62, "sheen": 0.3},
		"mist": Color(0.62, 0.58, 0.85), "mist_strength": 0.4,
		"bark": Color(0.17, 0.14, 0.2), "moss": Color(0.36, 0.46, 0.4), "land": Color(0.16, 0.2, 0.26),
		"land_top": Color(0.2, 0.3, 0.3), "stone": Color(0.36, 0.36, 0.44), "hill": Color(0.13, 0.1, 0.22),
		"hill_top": Color(0.24, 0.17, 0.34), "pad": Color(0.2, 0.36, 0.3),
		"flowers": [Color(1.0, 0.6, 0.85), Color(0.5, 0.75, 1.0), Color(1.0, 0.85, 0.5)],
		"motes": Color(1.0, 0.9, 0.5), "frog": Color(0.3, 0.55, 0.45),
		"wailer": {"skin": Color(0.2, 0.22, 0.26), "head": Color(0.4, 0.42, 0.48), "eye": Color(0.7, 0.85, 1.0),
			"muck": {"green": Color(0.18, 0.3, 0.3), "deep": Color(0.04, 0.08, 0.1), "pop": Color(0.55, 0.8, 0.9)}},
		"chest_name": "the Mire Chest", "sparkles": 10, "remnants": 1, "again": 3,
	},
	"dusk": {
		"title": "the Poison Mire", "centre": Vector3(-100, 0, 0), "r": 46.0, "poison": true,
		"gap_from": Vector3(-24, 0, 0), "gap_to": Vector3(-56, 0, 0), "gap_w": 6.0, "world_edge": 32.0,
		"hello": "The Poison Mire! Keep out of the green goo.",
		"islands": [[-58.0, 0.0, 5.0, "Mire Edge"], [-73.0, 10.0, 4.5, "Stump Isle"], [-86.0, -6.0, 5.0, "Toadstool Isle"],
			[-90.0, 22.0, 3.5, "Hush Isle"], [-104.0, 8.0, 4.5, "Bramble Isle"], [-108.0, -18.0, 4.0, "Crook Isle"],
			[-122.0, 4.0, 4.0, "Glimmer Isle"], [-136.0, -4.0, 4.5, "the Bog Heart"],
			[-78.0, -24.0, 3.0, "Fool's Rock"], [-118.0, 28.0, 3.0, "Gloom Isle"]],    # (dead ends, with a Muck Mimic)
		"walks": [],
		# stepping stones [from island, to island, pattern: o a stone, s a Sinker Stone]
		# two ways to the Bog Heart: south over Toadstool and Crook Isles, or north by Hush and Bramble Isles
		"stones": [[0, 1, "osos"], [1, 3, "ososso"], [2, 5, "ossosso"], [4, 6, "osso"], [6, 7, "osss"], [2, 8, "osso"],
			[4, 9, "ososo"]],
		"logs": [[1, 2], [3, 4], [5, 6]],
		# poison vents beside the way across ["stones" or "logs", which, how far along 0..1, which side -1/1], so each
		# vent's burp rolls over the way; poison clouds drifting [from x, z, to x, z]
		"vents": [["stones", 0, 0.5, 1.0], ["logs", 0, 0.3, -1.0], ["logs", 0, 0.75, 1.0], ["stones", 1, 0.5, -1.0],
			["logs", 1, 0.6, 1.0], ["stones", 2, 0.3, -1.0], ["stones", 2, 0.7, 1.0], ["logs", 2, 0.5, -1.0],
			["stones", 3, 0.5, 1.0], ["stones", 4, 0.5, -1.0]],
		# poison clouds drifting back and forth across a way ["stones" or "logs", which, where along it, how far each side]
		"clouds": [["logs", 0, 0.5, 6.0], ["logs", 1, 0.45, 6.0], ["logs", 2, 0.55, 7.0], ["stones", 2, 0.5, 6.0],
			["stones", 4, 0.4, 5.0]],
		"wailers": [[-80.0, 4.0, 6.0], [-96.0, -14.0, 7.0], [-112.0, 16.0, 7.0], [-126.0, -10.0, 6.0]],
		"chest": 7, "hut": -1,
		"decoys": [8, 9], "fib_sign": [2, 8, "Bog Heart this way!"], "giant": [-118.0, -8.0, "the Gulper"],
		"water": {"murk": Color(0.35, 0.75, 0.12), "deep": Color(0.12, 0.3, 0.04), "scum": Color(0.62, 0.9, 0.2),
			"glow": 1.6, "glow_colour": Color(0.55, 1.0, 0.25), "scum_amount": 0.55},
		"mist": Color(0.55, 0.85, 0.4), "mist_strength": 0.45,
		"bark": Color(0.13, 0.1, 0.14), "moss": Color(0.3, 0.4, 0.22), "land": Color(0.14, 0.13, 0.18),
		"land_top": Color(0.2, 0.22, 0.18), "stone": Color(0.4, 0.38, 0.45), "hill": Color(0.08, 0.06, 0.1),
		"hill_top": Color(0.14, 0.12, 0.18), "pad": Color(0.36, 0.24, 0.42),
		"flowers": [Color(0.8, 0.4, 1.0), Color(0.55, 1.0, 0.3)],
		"motes": Color(0.6, 1.0, 0.35), "frog": Color(0.55, 0.3, 0.7),
		"wailer": {"skin": Color(0.16, 0.14, 0.18), "head": Color(0.46, 0.4, 0.5), "eye": Color(0.7, 1.0, 0.35),
			"muck": {"green": Color(0.4, 0.75, 0.12), "deep": Color(0.22, 0.08, 0.3), "pop": Color(0.65, 1.0, 0.3)}},
		"chest_name": "the Bog Heart chest", "sparkles": 25, "remnants": 3, "again": 5,
	},
}

var world: Node3D
var kind := "lanternmoor"
var lay: Dictionary
var centre := Vector3.ZERO
var radius := 26.0
var poison := false
var player: CharacterBody3D
var hazards := true                      # false switches the vents and clouds off (tests)
var water: Node3D                        # the Mothmire's wading water (scripts/water.gd), or null
var wailers: Array[Node3D] = []
var sinkers: Array[Node3D] = []
var vents: Array[Node3D] = []
var clouds: Array[Node3D] = []
var frogs: Array[Node3D] = []
var islands: Array[Dictionary] = []     # {at: Vector3, r, name}
var stones: Array[Vector3] = []          # every stepping stone's top (tests walk them)
var chest: Node3D
var chest_open := false
var bumps := 0                           # (tests read these)
var last_safe := Vector3.ZERO
var arrived := false
var _mats := {}
var _rng := RandomNumberGenerator.new()
var _told := 0.0
var _safe_t := 0.0
var _t := 0.0
var _motes: MultiMesh
var _mote_data: Array = []
var _bubbles: Array[MeshInstance3D] = []
var _floating := false
var _ride_told := 0.0
var lookout: Node3D                      # the Lookout Tree by the chest island (tests read these)
var lookout_top := Vector3.ZERO
var lookout_foot := Vector3.ZERO
var lookout_seen := false
var lookout_a0 := 0.0                     # (the angle round the tree where its stair starts)
var dangers: Node3D


static func place(w: Node3D, which: String) -> Node3D:
	if w.get_node_or_null(NODE) != null:
		return w.get_node(NODE)
	var s := Node3D.new()
	s.name = NODE
	s.set_script(load("res://scripts/swamp.gd"))
	s.set("world", w)
	s.set("kind", which)
	w.add_child(s)
	return s


static func layout(which: String) -> Dictionary:
	return LAYOUTS[which]


# -----------------------------------------------------------------------------------------------------------------
func _ready() -> void:
	if world == null:
		world = get_parent() as Node3D
	add_to_group("no_ride")
	lay = LAYOUTS[kind]
	centre = lay.centre
	radius = float(lay.r)
	poison = bool(lay.poison)
	_rng.seed = hash(kind)
	for i in (lay.islands as Array):
		islands.append({"at": Vector3(float(i[0]), 0, float(i[1])), "r": float(i[2]), "name": str(i[3])})
	_open_gap()
	_basin()
	_causeway()
	_islands()
	_walks()
	_stones()
	_logs()
	_edge()
	_trees()
	_plants()
	_mist()
	_glows()
	_frogs()
	if int(lay.hut) >= 0:
		_hut(islands[int(lay.hut)])
	_chest(islands[int(lay.chest)])
	_vents()
	_clouds()
	_bubbles_pool()
	_wailers()
	_lookout(islands[int(lay.chest)])
	last_safe = islands[0].at + Vector3(0, 1.0, 0)
	dangers = DANGERS.new()
	dangers.name = "Dangers"
	dangers.set("sw", self)
	add_child(dangers)


func _mat(n: String, c: Color, rough := 0.9, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if _mats.has(n):
		return _mats[n]
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_color = Color(c, alpha)
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[n] = m
	return m


func _mesh(mesh: Mesh, m: Material, at: Vector3, parent: Node3D, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _solid(shape: Shape3D, at: Vector3, parent: Node3D, rot := Vector3.ZERO, n := "") -> StaticBody3D:
	var b := StaticBody3D.new()
	if n != "":
		b.name = n
	b.position = at
	b.rotation = rot
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b, true)                           # (readable names: the map and tests look for "WorldBounds...")
	return b


func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s


func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


func _group(n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	add_child(g)
	return g


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))


func _dir_out() -> Vector3:
	# From the basin's middle towards the gap it opens through
	var d: Vector3 = (lay.gap_from as Vector3) - centre
	d.y = 0.0
	return d.normalized()


# The way in -------------------------------------------------------------------------------------------------------
func _open_gap() -> void:
	# Take the world's own fence, trees and hills out of the way of the causeway
	var a := _flat(lay.gap_from)
	var b := _flat(lay.gap_to)
	var half := float(lay.gap_w) / 2.0
	for n in world.find_children("*", "Node3D", true, false):
		if n == self or is_ancestor_of(n) or not n.is_inside_tree():
			continue
		var p := _flat((n as Node3D).global_position)
		var d := _seg_dist(p, a, b)
		var par := n.get_parent()
		if par == null:
			continue
		var pname := str(par.name)
		if n is StaticBody3D and (str(n.name).begins_with("Fence") or pname == "Edge") and d < half + 3.4:
			n.queue_free()                                           # the fence across the way
		elif pname in ["Twisted Trees", "Lantern Trees", "Night Flowers", "Glow"] and d < half + 2.2:
			n.queue_free()                                           # trees, flowers, eyes in the way
		elif pname == "Hills" and n is MeshInstance3D and d < half + 11.0:
			(n as MeshInstance3D).visible = false                    # the hills over the way (they've no collision)


func _causeway() -> void:
	var g := _group("Causeway")
	var a: Vector3 = lay.gap_from
	var b: Vector3 = lay.gap_to
	var mid := (a + b) / 2.0
	var len := a.distance_to(b)
	var yaw := atan2(b.x - a.x, b.z - a.z)
	var w := float(lay.gap_w)
	var land := _mat("Swamp Bank", lay.land_top)
	var m := _mesh(_box(Vector3(w, 0.6, len)), land, mid + Vector3(0, -0.3, 0), g, Vector3(0, yaw, 0))
	m.name = "Causeway Ground"
	_solid(_box_shape(Vector3(w, 0.6, len)), mid + Vector3(0, -0.3, 0), g, Vector3(0, yaw, 0), "Causeway Body").add_to_group("swamp_safe")
	# Its sides: low mounds you can't climb out over, and an unseen fence so nobody falls off into nothing
	var dir := (b - a).normalized()
	var side := Vector3(dir.z, 0, -dir.x)
	var bank := _mat("Swamp Hill", lay.hill)
	for s: float in [-1.0, 1.0]:
		var f := _solid(_box_shape(Vector3(0.6, 6.0, len)), mid + side * s * (w / 2.0 + 0.3) + Vector3(0, 3.0, 0), g,
			Vector3(0, yaw, 0), "WorldBounds Swamp Fence")
		f.add_to_group("no_climb")
		for k in int(len / 3.0):
			var p := a + dir * (1.5 + k * 3.0) + side * s * (w / 2.0 + 1.2 + _rng.randf())
			var h := _mesh(_ball(1.0, 10), bank, p, g)
			h.scale = Vector3(_rng.randf_range(1.6, 2.6), _rng.randf_range(0.9, 2.2), _rng.randf_range(1.6, 2.6))
	# Stepping stones down the middle, and a sign at the start
	var stone := _mat("Path Stone" if not poison else "Swamp Path", lay.stone)
	var k := 0.0
	while k < len - 1.0:
		var p := a + dir * (k + 1.0) + side * _rng.randf_range(-0.6, 0.6)
		_mesh(_cyl(0.5, 0.55, 0.1, 10), stone, p + Vector3(0, 0.02, 0), g).scale = Vector3(1, 1, _rng.randf_range(0.7, 1.0))
		k += 1.6
	var sign := Node3D.new()
	sign.name = "Swamp Sign"
	sign.position = a + dir * 1.5 + side * (w / 2.0 - 0.6)
	g.add_child(sign)
	var post := _mat("Swamp Post", lay.bark)
	_mesh(_cyl(0.08, 0.1, 2.2, 6), post, Vector3(0, 1.1, 0), sign)
	_mesh(_box(Vector3(1.7, 0.5, 0.08)), post, Vector3(0, 1.9, 0), sign, Vector3(0, yaw + PI / 2.0, 0))
	var l := Label3D.new()
	l.text = str(lay.title).capitalize() if not str(lay.title).begins_with("the ") else "The " + str(lay.title).substr(4)
	l.font_size = 56
	l.pixel_size = 0.008
	l.outline_size = 10
	l.modulate = Color(0.85, 1.0, 0.7) if poison else Color(0.85, 0.85, 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = Vector3(0, 2.45, 0)
	sign.add_child(l)


# The basin, its water and its land --------------------------------------------------------------------------------
func _basin() -> void:
	var g := _group("Basin")
	var bed := _mat("Swamp Bed", lay.land.darkened(0.3))
	var R := radius + 3.0
	_mesh(_cyl(R, R, 1.0, 48), bed, centre + Vector3(0, BED - 0.5, 0), g).name = "Bed"
	_solid(_cyl_shape(R, 1.0), centre + Vector3(0, BED - 0.5, 0), g, Vector3.ZERO, "Bed Body")
	var wm := ShaderMaterial.new()
	wm.resource_name = "Swamp Water"
	wm.shader = WATER_SHADER
	var wl: Dictionary = lay.water
	wm.set_shader_parameter("murk", wl.murk)
	wm.set_shader_parameter("deep", wl.deep)
	wm.set_shader_parameter("scum", wl.scum)
	wm.set_shader_parameter("glow", wl.glow)
	wm.set_shader_parameter("glow_colour", wl.glow_colour)
	wm.set_shader_parameter("scum_amount", wl.scum_amount)
	wm.set_shader_parameter("sheen", wl.get("sheen", 0.55))
	wm.set_shader_parameter("motion", 0.3 if Settings.get("reduce_motion") == true else 1.0)
	if poison:
		wm.set_shader_parameter("clear_alpha", 0.85)
		wm.set_shader_parameter("murk_depth", 0.25)
	var surf := _mesh(_disc(R + 1.0, 64), wm, centre + Vector3(0, SURFACE, 0), g)
	surf.name = "Poison" if poison else "Water"
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surf.add_to_group("swamp_surface")
	if poison:
		var glow := OmniLight3D.new()                # the goo lights the mist a little from below
		glow.light_color = (wl.glow_colour as Color)
		glow.light_energy = 0.6
		glow.omni_range = radius * 1.2
		glow.omni_attenuation = 1.6
		glow.shadow_enabled = false
		glow.position = centre + Vector3(0, 1.0, 0)
		g.add_child(glow)
	else:
		water = WATER.new()
		water.name = "Mire Water"
		water.set("ellipses", [Vector4(centre.x, centre.z, R, R)] as Array[Vector4])
		water.set("water_y", SURFACE)
		g.add_child(water)


func _disc(r: float, seg: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for v in [Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * r, Vector3(cos(a0), 0, sin(a0)) * r]:
			st.set_uv(Vector2(v.x, v.z) / (2.0 * r) + Vector2(0.5, 0.5))
			st.add_vertex(v)
	st.generate_tangents()
	return st.commit()


func _islands() -> void:
	var g := _group("Islands")
	var land := _mat("Swamp Land", lay.land)
	var top := _mat("Swamp Moss", lay.land_top)
	for isl in islands:
		var at: Vector3 = isl.at
		var r := float(isl.r)
		var n := Node3D.new()
		n.name = str(isl.name)
		n.position = at
		g.add_child(n)
		# A low mound, its top flat enough to stand on, with a lumpy muddy edge into the water
		_mesh(_cyl(r, r + 0.7, 0.9, 24), land, Vector3(0, -0.45, 0), n)
		_mesh(_cyl(r - 0.2, r, 0.06, 24), top, Vector3(0, 0.0, 0), n)
		for k in int(r * 3.0):
			var a := _rng.randf() * TAU
			var e := _mesh(_ball(1.0, 8), land, Vector3(cos(a), 0, sin(a)) * (r + _rng.randf_range(-0.1, 0.4)) + Vector3(0, -0.15, 0), n)
			e.scale = Vector3(_rng.randf_range(0.5, 0.9), _rng.randf_range(0.15, 0.3), _rng.randf_range(0.5, 0.9))
		var body := _solid(_cyl_shape(r, 1.0), Vector3(0, -0.5, 0), n, Vector3.ZERO, "Island Body")
		body.add_to_group("swamp_safe")
		body.add_to_group("soil")                     # (Bramble's burrow can dig in it)


func _walks() -> void:
	# Old boardwalks on posts between islands (a broken one has a stretch missing: wade across)
	var g := _group("Boardwalks")
	var wood := _mat("Swamp Planks", lay.bark.lightened(0.25))
	var post := _mat("Mangrove Bark", lay.bark)
	for w in (lay.walks as Array):
		var A: Dictionary = islands[int(w[0])]
		var B: Dictionary = islands[int(w[1])]
		var dir: Vector3 = ((B.at as Vector3) - (A.at as Vector3)).normalized()
		var a: Vector3 = (A.at as Vector3) + dir * (float(A.r) - 0.8)
		var b: Vector3 = (B.at as Vector3) - dir * (float(B.r) - 0.8)
		var len := a.distance_to(b)
		var yaw := atan2(dir.x, dir.z)
		var side := Vector3(dir.z, 0, -dir.x)
		var k := 0.0
		while k < len:
			var f := k / len
			if f < float(w[2]) or f > float(w[3]) or float(w[2]) == float(w[3]):
				var p := a + dir * (k + 0.25)
				var plank := _mesh(_box(Vector3(1.9, 0.08, 0.42)), wood, p + Vector3(0, WALK_TOP - 0.04 + _rng.randf_range(-0.02, 0.02), 0), g,
					Vector3(_rng.randf_range(-0.03, 0.03), yaw + _rng.randf_range(-0.05, 0.05), 0))
				plank.name = "Plank"
				if int(k / 0.5) % 4 == 0:
					for s: float in [-0.85, 0.85]:
						_mesh(_cyl(0.07, 0.09, 1.3, 6), post, p + side * s + Vector3(0, WALK_TOP - 0.65, 0), g)
			k += 0.5
		# The planks' solid shape, in pieces so a broken stretch is open
		var pieces: Array = [[0.0, 1.0]] if float(w[2]) == float(w[3]) else [[0.0, float(w[2])], [float(w[3]), 1.0]]
		for pc in pieces:
			var l0 := len * float(pc[0])
			var l1 := len * float(pc[1])
			var c := a + dir * ((l0 + l1) / 2.0)
			_solid(_box_shape(Vector3(1.9, 0.3, l1 - l0)), c + Vector3(0, WALK_TOP - 0.15, 0), g, Vector3(0, yaw, 0),
				"Boardwalk Body").add_to_group("swamp_safe")
			# Its ends: a gentle slope up from the island, or (at a broken stretch) old planks sloping down into the water
			for e in [[l0, -1.0], [l1, 1.0]]:
				var at := a + dir * float(e[0]) + Vector3(0, WALK_TOP, 0)
				var out := dir * float(e[1])
				if (float(e[0]) <= 0.01 and e[1] < 0) or (float(e[0]) >= len - 0.01 and e[1] > 0):
					_ramp(g, at, at + out * 1.6 + Vector3(0, -WALK_TOP - 0.05, 0), wood, false)
				else:
					_ramp(g, at, at + out * 1.7 + Vector3(0, BED - WALK_TOP - 0.05, 0), wood, true)


func _ramp(g: Node3D, top: Vector3, low: Vector3, wood: Material, planks: bool) -> void:
	var mid := (top + low) / 2.0
	var flat := Vector2(low.x - top.x, low.z - top.z)
	var yaw := atan2(low.x - top.x, low.z - top.z)
	var pitch := atan2(top.y - low.y, flat.length())
	var len := top.distance_to(low)
	var rot := Vector3(pitch, yaw, 0)
	var body := _solid(_box_shape(Vector3(1.8, 0.1, len)), mid + Vector3(0, -0.05, 0), g, rot, "Boardwalk Ramp")
	body.add_to_group("swamp_safe")
	if planks:
		var b := Basis.from_euler(rot)
		for k in int(len / 0.45):
			_mesh(_box(Vector3(1.8, 0.07, 0.4)), wood, mid + b * Vector3(0, -0.02, -len / 2.0 + 0.25 + k * 0.45), g,
				rot + Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.06, 0.06)))


func _stones() -> void:
	# Stepping stones across the poison; "s" in a pattern makes a Sinker Stone
	var g := _group("Stepping Stones")
	var rock := _mat("Wet Rock", lay.stone)
	var cracked := _mat("Sinker Rock", lay.stone.darkened(0.35))
	var crack := _mat("Sinker Crack", (lay.water.glow_colour as Color), 0.5, 1.2)
	for s in (lay.stones as Array):
		var A: Dictionary = islands[int(s[0])]
		var B: Dictionary = islands[int(s[1])]
		var pattern := str(s[2])
		var from: Vector3 = A.at
		var to: Vector3 = B.at
		var dir := (to - from).normalized()
		var a := from + dir * float(A.r)
		var b := to - dir * float(B.r)
		var n := pattern.length()
		var side := Vector3(dir.z, 0, -dir.x)
		for i in n:
			var f := (float(i) + 1.0) / (float(n) + 1.0)
			var p := a.lerp(b, f) + side * sin(float(i) * 1.7) * 0.5
			var sink := pattern[i] == "s"
			var body := AnimatableBody3D.new()
			body.name = "Sinker Stone" if sink else "Stone"
			body.sync_to_physics = false
			body.position = Vector3(p.x, STONE_TOP - 0.35, p.z)
			var cs := CollisionShape3D.new()
			cs.shape = _cyl_shape(0.8, 0.7)
			body.add_child(cs)
			g.add_child(body)
			var look := _mesh(_cyl(0.8, 0.95, 0.7, 14), cracked if sink else rock, Vector3.ZERO, body)
			look.name = "Look"
			_mesh(_cyl(0.6, 0.75, 0.04, 12), _mat("Stone Moss", lay.moss), Vector3(0, 0.36, 0), body)
			if sink:
				for c in 3:                                   # glowing cracks across its top: a hint it's not to be trusted
					_mesh(_box(Vector3(0.05, 0.03, 0.9)), crack, Vector3(_rng.randf_range(-0.3, 0.3), 0.385, 0), body,
						Vector3(0, _rng.randf() * PI, 0))
				body.set_meta("rest_y", body.position.y)
				body.set_meta("stood", 0.0)
				body.set_meta("state", "up")
				body.set_meta("t", 0.0)
				body.add_to_group("swamp_sinker")
				sinkers.append(body)
			else:
				body.add_to_group("swamp_safe")
			stones.append(Vector3(p.x, STONE_TOP, p.z))


func _logs() -> void:
	# A fallen, mossy log across from one island to another: narrow, so mind your feet
	var g := _group("Log Bridges")
	var bark := _mat("Mangrove Bark", lay.bark)
	var moss := _mat("Log Moss", lay.moss)
	for l in (lay.logs as Array):
		var A: Dictionary = islands[int(l[0])]
		var B: Dictionary = islands[int(l[1])]
		var from: Vector3 = A.at
		var to: Vector3 = B.at
		var dir := (to - from).normalized()
		var a := from + dir * (float(A.r) - 1.0)
		var b := to - dir * (float(B.r) - 1.0)
		var len := a.distance_to(b)
		var mid := (a + b) / 2.0
		var yaw := atan2(dir.x, dir.z)
		var lg := Node3D.new()
		lg.name = "Log Bridge"
		lg.position = mid + Vector3(0, -0.4, 0)              # sunk in the goo, its top just over it (0.15)
		lg.rotation.y = yaw
		g.add_child(lg)
		_mesh(_cyl(0.55, 0.6, len, 14), bark, Vector3.ZERO, lg, Vector3(PI / 2.0, 0, 0))
		for k in int(len / 1.4):
			_mesh(_ball(0.3, 8), moss, Vector3(_rng.randf_range(-0.2, 0.2), 0.5, -len / 2.0 + 0.7 + k * 1.4), lg).scale = Vector3(1.2, 0.3, 1.6)
		for e: float in [-1.0, 1.0]:
			_mesh(_cyl(0.45, 0.45, 0.03, 14), _mat("Log End", lay.bark.lightened(0.35)), Vector3(0, 0, e * len / 2.0), lg, Vector3(PI / 2.0, 0, 0))
		var body := _solid(_box_shape(Vector3(1.1, 0.4, len)), Vector3(0, 0.35, 0), lg, Vector3.ZERO, "Log Body")
		body.add_to_group("swamp_safe")
		var top := 0.15
		for e: float in [-1.0, 1.0]:                      # a soft slope up onto each end (a root, a mossy hump)
			var end := mid + dir * e * len / 2.0 + Vector3(0, top, 0)
			_ramp(g, end, end + dir * e * 1.2 + Vector3(0, -top - 0.05, 0), bark, false)


func _edge() -> void:
	# Hills (or dark trees) all round, and an unseen fence just inside them, open only at the causeway
	var g := _group("Edge")
	var hill := _mat("Swamp Hill", lay.hill)
	var cap := _mat("Swamp Hill Top", lay.hill_top)
	var out := _dir_out()
	var gap_a := asin(clampf((float(lay.gap_w) / 2.0 + 0.8) / (radius + 1.2), 0.0, 1.0))
	var n := int(TAU * (radius + 1.2) / 3.0)
	for k in n:
		var a := TAU * k / n
		var d := Vector3(cos(a), 0, sin(a))
		if absf(d.signed_angle_to(out, Vector3.UP)) < gap_a:
			continue
		var f := _solid(_box_shape(Vector3(0.6, 7.0, TAU * (radius + 1.2) / n + 0.5)), centre + d * (radius + 1.2) + Vector3(0, 3.0, 0), g,
			Vector3(0, -a, 0), "WorldBounds Swamp Fence")
		f.add_to_group("no_climb")
	var hills := int(radius * 1.1)
	for k in hills:
		var a := TAU * k / float(hills) + _rng.randf_range(-0.05, 0.05)
		var d := Vector3(cos(a), 0, sin(a))
		if absf(d.signed_angle_to(out, Vector3.UP)) < gap_a + 0.25:
			continue
		var p := centre + d * (radius + _rng.randf_range(5.0, 9.0))
		var r := _rng.randf_range(7.0, 11.0)
		var h := _mesh(_ball(1.0, 16), hill, p + Vector3(0, -1.0, 0), g)
		h.scale = Vector3(r, _rng.randf_range(4.0, 9.0), r)
		_mesh(_ball(1.0, 12), cap, p + Vector3(0, h.scale.y * 0.8 - 1.0, 0), g).scale = Vector3(r * 0.5, h.scale.y * 0.22, r * 0.5)
	# A muddy bank round the edge of the water, under the fence
	var bank := _mat("Swamp Bank", lay.land_top)
	var banks := int(radius * 1.7)
	for k in banks:
		var a := TAU * k / float(banks)
		var d := Vector3(cos(a), 0, sin(a))
		if absf(d.signed_angle_to(out, Vector3.UP)) < gap_a:
			continue
		var m := _mesh(_ball(1.0, 10), bank, centre + d * (radius + 2.4) + Vector3(0, -0.3, 0), g)
		m.scale = Vector3(_rng.randf_range(2.5, 3.5), _rng.randf_range(0.6, 1.2), _rng.randf_range(2.5, 3.5))


# Scenery ----------------------------------------------------------------------------------------------------------
func _clear(p: Vector3, room: float) -> bool:
	# Away from the ways across (so nothing stands in the way or hides a stone)
	var f := _flat(p)
	if f.distance_to(_flat(centre)) > radius - 1.0:
		return false
	if _seg_dist(f, _flat(lay.gap_from), _flat(lay.gap_to)) < float(lay.gap_w) / 2.0 + room:
		return false
	for s in stones:
		if f.distance_to(_flat(s)) < 1.4 + room:
			return false
	for pair in (lay.walks as Array) + (lay.logs as Array) + (lay.stones as Array):
		var a := _flat(islands[int(pair[0])].at)
		var b := _flat(islands[int(pair[1])].at)
		if _seg_dist(f, a, b) < 1.6 + room:
			return false
	if chest and f.distance_to(_flat(chest.global_position)) < 2.5 + room:
		return false
	return true


func _on_island(p: Vector3) -> Dictionary:
	for isl in islands:
		if _flat(p).distance_to(_flat(isl.at)) < float(isl.r) - 0.3:
			return isl
	return {}


func _trees() -> void:
	# Dead, twisted swamp trees on roots, moss hanging off their branches like curtains
	var g := _group("Swamp Trees")
	var bark := _mat("Mangrove Bark", lay.bark)
	var moss := _mat("Hanging Moss", lay.moss, 0.95, 0.0, 0.85)
	var placed := 0
	var tries := 0
	while placed < int(radius * 0.75) and tries < 900:
		tries += 1
		var a := _rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, radius - 2.0)
		if not _clear(p, 1.8):
			continue
		var isl := _on_island(p)
		if not isl.is_empty() and _flat(p).distance_to(_flat(isl.at)) < 1.5:
			continue
		var base := 0.0 if not isl.is_empty() else BED
		var h := _rng.randf_range(5.0, 9.0)
		var t := Node3D.new()
		t.name = "Swamp Tree"
		t.position = Vector3(p.x, base, p.z)
		t.rotation.y = _rng.randf() * TAU
		g.add_child(t)
		var lean := _rng.randf_range(-0.12, 0.12)
		_mesh(_cyl(0.16, 0.42, h, 8), bark, Vector3(0, h / 2.0, 0), t, Vector3(lean, 0, 0))
		for k in 5:                                          # arching roots
			var ra := TAU * k / 5.0 + _rng.randf_range(-0.3, 0.3)
			var root := _mesh(_cyl(0.06, 0.13, 1.5, 6), bark, Vector3(cos(ra) * 0.55, 0.45, sin(ra) * 0.55), t)
			root.rotation = Vector3(sin(ra) * 0.8, 0, -cos(ra) * 0.8)       # leaning out, like stilts
		var tops: Array[Vector3] = []
		for k in _rng.randi_range(3, 4):
			var y := h * _rng.randf_range(0.5, 0.92)
			var len := _rng.randf_range(1.4, 2.8)
			var b := Node3D.new()
			b.position = Vector3(0, y, 0)
			b.rotation = Vector3(0, _rng.randf() * TAU, _rng.randf_range(0.8, 1.25))
			t.add_child(b)
			_mesh(_cyl(0.04, 0.11, len, 6), bark, Vector3(0, len / 2.0, 0), b)
			tops.append(b.position + b.transform.basis * Vector3(0, len * 0.6, 0))
		for tp in tops:                                      # moss strands hanging straight down from each branch
			for s in 3:
				var sl := _rng.randf_range(0.8, 2.2)
				_mesh(_box(Vector3(0.18, sl, 0.02)), moss, tp + Vector3(_rng.randf_range(-0.4, 0.4), -sl / 2.0, _rng.randf_range(-0.4, 0.4)), t,
					Vector3(0, _rng.randf() * PI, 0))
		_solid(_cyl_shape(0.42, 3.0), Vector3(0, 1.5, 0), t, Vector3.ZERO, "Trunk Body")
		placed += 1


func _plants() -> void:
	# Reeds and cattails in clumps, and lily pads floating on the water (some with glowing flowers): MultiMeshes
	var g := _group("Plants")
	var reeds: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var pads: Array[Transform3D] = []
	var flowers: Array = []
	for c in int(radius * 2.4):
		var a := _rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, radius - 0.5)
		if _rng.randf() < 0.5 and islands.size() > 0:          # half of them round the islands' edges
			var isl: Dictionary = islands[_rng.randi() % islands.size()]
			var ia := _rng.randf() * TAU
			p = (isl.at as Vector3) + Vector3(cos(ia), 0, sin(ia)) * (float(isl.r) + _rng.randf_range(0.1, 0.8))
		if not _clear(p, 0.4):
			continue
		var base := BED if _on_island(p).is_empty() else 0.0
		for k in _rng.randi_range(6, 11):
			var q := p + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
			var tall := _rng.randf_range(1.2, 2.2) + (SURFACE - base)
			var tilt := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
			var bs := Basis(tilt.normalized(), _rng.randf_range(0.02, 0.14)) if tilt.length() > 0.01 else Basis()
			reeds.append(Transform3D(bs * Basis.from_scale(Vector3(1, tall, 1)), Vector3(q.x, base, q.z) + bs * Vector3(0, tall / 2.0, 0)))
			if _rng.randf() < 0.35:
				heads.append(Transform3D(bs, Vector3(q.x, base, q.z) + bs * Vector3(0, tall * 0.92, 0)))
	for c in int(radius * 5.5):
		var a := _rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, radius - 0.3)
		if not _on_island(p).is_empty() or not _clear(p, -0.6):
			continue
		var s := _rng.randf_range(0.35, 0.8)
		pads.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(s, 1, s)), Vector3(p.x, SURFACE + 0.012, p.z)))
		if _rng.randf() < 0.3:
			flowers.append([Vector3(p.x, SURFACE + 0.1, p.z), _rng.randi() % (lay.flowers as Array).size()])
	var reed_mesh := _cyl(0.02, 0.035, 1.0, 5)
	_multi(g, "Reeds", reed_mesh, _mat("Swamp Reed", lay.moss.lerp(Color(0.5, 0.45, 0.3), 0.35)), reeds)
	var cat := CapsuleMesh.new()
	cat.radius = 0.05
	cat.height = 0.3
	cat.radial_segments = 6
	_multi(g, "Cattails", cat, _mat("Cattail", Color(0.3, 0.2, 0.14)), heads)
	var pad := _pad_mesh()
	_multi(g, "Lily Pads", pad, _mat("Lily Pad", lay.pad, 0.6), pads)
	var fl := Node3D.new()
	fl.name = "Pad Flowers"
	g.add_child(fl)
	for f in flowers:
		var col: Color = (lay.flowers as Array)[int(f[1])]
		var m := _mat("Pad Flower %d" % int(f[1]), col, 0.4, 1.6)
		var at: Vector3 = f[0]
		for k in 5:
			var pa := TAU * k / 5.0
			_mesh(_ball(0.07, 6), m, at + Vector3(cos(pa) * 0.07, 0, sin(pa) * 0.07), fl).scale = Vector3(1.0, 0.5, 1.6)
		_mesh(_ball(0.04, 6), _mat("Pad Flower Heart", Color(1.0, 0.95, 0.6), 0.4, 2.0), at + Vector3(0, 0.03, 0), fl)


func _pad_mesh() -> ArrayMesh:
	# A round lily pad with a notch cut in it
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var seg := 16
	for i in seg:
		if i == 0:
			continue                                       # the notch
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1), 0, sin(a1)) * 0.5)
		st.add_vertex(Vector3(cos(a0), 0, sin(a0)) * 0.5)
	return st.commit()


func _multi(parent: Node3D, n: String, mesh: Mesh, m: Material, xf: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.set_meta("transforms", xf)
	parent.add_child(mmi)
	return mmi


func _mist() -> void:
	# Mist lying low over the water: sheets for every lighting level, and a FogVolume for the real haze
	var g := _group("Mist")
	var mm := ShaderMaterial.new()
	mm.resource_name = "Swamp Mist"
	mm.shader = MIST_SHADER
	mm.set_shader_parameter("colour", lay.mist)
	mm.set_shader_parameter("strength", lay.mist_strength)
	mm.set_shader_parameter("motion", 0.3 if Settings.get("reduce_motion") == true else 1.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	for k in int(radius * 0.8):
		var a := _rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * sqrt(_rng.randf()) * (radius - 6.0)
		var sheet := _mesh(plane, mm, Vector3(p.x, SURFACE + 0.25 + 0.12 * (k % 4), p.z), g, Vector3(0, _rng.randf() * TAU, 0))
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.name = "Mist Sheet"
	var fv := FogVolume.new()
	fv.name = "Swamp Fog"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
	fv.size = Vector3(radius * 2.0, 3.0, radius * 2.0)
	fv.position = centre + Vector3(0, 0.6, 0)
	var fm := FogMaterial.new()
	fm.density = 0.06 if poison else 0.045
	fm.albedo = lay.mist
	fm.emission = (lay.mist as Color) * (0.12 if poison else 0.04)
	fm.height_falloff = 0.6
	fm.edge_fade = 0.3
	fv.material = fm
	g.add_child(fv)


func _glows() -> void:
	# Fireflies (or poison spores) drifting about, and a few wisps
	var g := _group("Glows")
	var col: Color = lay.motes
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _ball(0.05, 6)
	mm.instance_count = int(radius * 4.0)
	for i in mm.instance_count:
		var a := _rng.randf() * TAU
		_mote_data.append([centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.0, radius - 1.0), _rng.randf_range(0.6, 2.0),
			_rng.randf_range(0.2, 0.6), _rng.randf() * TAU, _rng.randf_range(0.4, 2.4)])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Spores" if poison else "Fireflies"
	mmi.multimesh = mm
	mmi.material_override = _mat("Swamp Mote", col, 0.3, 4.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mmi)
	_motes = mm
	_move_motes(0.0)
	for k in 10:
		var w := Node3D.new()
		w.name = "Swamp Wisp %d" % (k + 1)
		w.set_script(WISP)
		var a := TAU * k / 10.0 + 0.4
		w.position = centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(6.0, radius - 4.0) + Vector3(0, _rng.randf_range(1.2, 2.6), 0)
		g.add_child(w)
		var wc: Color = (lay.flowers as Array)[k % (lay.flowers as Array).size()]
		_mesh(_ball(0.1), _mat("Swamp Wisp %d" % (k % 3), wc, 0.2, 3.0), Vector3.ZERO, w)
		_mesh(_ball(0.28), _mat("Swamp Wisp Halo %d" % (k % 3), wc, 0.2, 1.0, 0.2), Vector3.ZERO, w)
		var l := OmniLight3D.new()
		l.light_color = wc
		l.light_energy = 0.7
		l.omni_range = 5.0
		w.add_child(l)
	if poison:
		# Glowing toadstools on the islands, lighting the way a little
		var cap := _mat("Toxic Cap", Color(0.75, 0.4, 1.0), 0.4, 2.2)
		var stalk := _mat("Toxic Stalk", Color(0.85, 0.85, 0.75))
		for isl in islands:
			for c in 2:
				var a := _rng.randf() * TAU
				var p: Vector3 = (isl.at as Vector3) + Vector3(cos(a), 0, sin(a)) * (float(isl.r) - 0.9)
				if not _clear(p, -1.0):
					continue
				var cl := Node3D.new()
				cl.name = "Toadstools"
				cl.position = p
				g.add_child(cl)
				for q in 3:
					var off := Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
					var h := _rng.randf_range(0.25, 0.6)
					_mesh(_cyl(0.05, 0.07, h, 6), stalk, off + Vector3(0, h / 2.0, 0), cl)
					_mesh(_ball(0.2 + h * 0.2, 10), cap, off + Vector3(0, h, 0), cl).scale = Vector3(1, 0.5, 1)
				var l := OmniLight3D.new()
				l.light_color = Color(0.75, 0.4, 1.0)
				l.light_energy = 0.8
				l.omni_range = 4.0
				l.position = Vector3(0, 0.7, 0)
				cl.add_child(l)


func _move_motes(delta: float) -> void:
	if _motes == null:
		return
	for i in _mote_data.size():
		var d: Array = _mote_data[i]
		d[3] = float(d[3]) + delta * float(d[2])
		var ph := float(d[3])
		var c: Vector3 = d[0]
		var p := c + Vector3(sin(ph) * float(d[4]), float(d[1]) + sin(ph * 2.3) * 0.3, cos(ph * 0.8) * float(d[4]))
		var blink := 0.6 + 0.4 * sin(ph * 6.0 + float(i))
		_motes.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * blink), p))


func _frogs() -> void:
	# Frogs on the lily pads and island edges: they puff their throats and croak, and hop off when you come close
	var g := _group("Frogs")
	var body := _mat("Swamp Frog", lay.frog, 0.5)
	var belly := _mat("Frog Belly", (lay.frog as Color).lightened(0.4), 0.6)
	var eye := _mat("Frog Eye", Color(1.0, 0.9, 0.4), 0.3, 1.5)
	var dark := _mat("Frog Pupil", Color(0.02, 0.02, 0.02))
	var placed := 0
	var tries := 0
	while placed < 10 and tries < 400:
		tries += 1
		var isl: Dictionary = islands[_rng.randi() % islands.size()]
		var a := _rng.randf() * TAU
		var p: Vector3 = (isl.at as Vector3) + Vector3(cos(a), 0, sin(a)) * (float(isl.r) - 0.6)
		if not _clear(p, -0.8):
			continue
		var f := Node3D.new()
		f.name = "Frog %d" % (placed + 1)
		f.position = p + Vector3(0, 0.03, 0)
		f.rotation.y = a + PI
		g.add_child(f)
		_mesh(_ball(0.16, 10), body, Vector3(0, 0.12, 0), f).scale = Vector3(1.0, 0.7, 1.25)
		_mesh(_ball(0.12, 8), belly, Vector3(0, 0.08, 0.06), f).scale = Vector3(1.0, 0.6, 1.0)
		var throat := _mesh(_ball(0.08, 8), belly, Vector3(0, 0.08, 0.17), f)
		throat.name = "Throat"
		for s: float in [-1.0, 1.0]:
			_mesh(_ball(0.055, 8), eye, Vector3(s * 0.08, 0.24, 0.1), f)
			_mesh(_ball(0.03, 6), dark, Vector3(s * 0.085, 0.25, 0.15), f)
			_mesh(_ball(0.07, 6), body, Vector3(s * 0.13, 0.04, -0.1), f).scale = Vector3(0.8, 0.5, 1.6)
		f.set_meta("home", f.position)
		f.set_meta("croak", _rng.randf_range(1.0, 6.0))
		f.set_meta("hop", 0.0)
		frogs.append(f)
		placed += 1


func _hut(isl: Dictionary) -> void:
	# The Old Mire Hut: a tumbledown shack on stilts at the edge of Hut Isle, a lantern glowing in its window
	var g := _group("Old Mire Hut")
	var wood := _mat("Hut Boards", lay.bark.lightened(0.15))
	var roof := _mat("Hut Thatch", Color(0.3, 0.26, 0.2))
	var post := _mat("Mangrove Bark", lay.bark)
	var out := ((isl.at as Vector3) - centre).normalized()
	var at: Vector3 = (isl.at as Vector3) + out * (float(isl.r) + 1.6)
	var yaw := atan2(out.x, out.z)
	var h := Node3D.new()
	h.name = "Hut"
	h.position = at
	h.rotation.y = yaw
	g.add_child(h)
	for x: float in [-1.3, 1.3]:
		for z: float in [-1.3, 1.3]:
			_mesh(_cyl(0.09, 0.11, 2.4, 6), post, Vector3(x, 0.0, z), h)
	_mesh(_box(Vector3(3.2, 0.12, 3.2)), wood, Vector3(0, 1.1, 0), h)
	_solid(_box_shape(Vector3(3.2, 0.3, 3.2)), Vector3(0, 1.0, 0), h)
	for wall in [[Vector3(0, 2.1, 1.5), Vector3(3.0, 1.9, 0.1)], [Vector3(0, 2.1, -1.5), Vector3(3.0, 1.9, 0.1)],
			[Vector3(1.5, 2.1, 0), Vector3(0.1, 1.9, 3.0)], [Vector3(-1.5, 2.1, 0), Vector3(0.1, 1.9, 3.0)]]:
		_mesh(_box(wall[1]), wood, wall[0], h, Vector3(0, 0, _rng.randf_range(-0.03, 0.03)))
		_solid(_box_shape(wall[1]), wall[0], h)
	_mesh(_cyl(0.0, 2.6, 1.4, 4), roof, Vector3(0, 3.7, 0), h, Vector3(0, PI / 4.0, 0.06))
	# A window with the lantern's glow in it, facing the island
	_mesh(_box(Vector3(0.7, 0.5, 0.04)), _mat("Hut Window", Color(1.0, 0.75, 0.4), 0.5, 2.5), Vector3(0, 2.3, -1.56), h)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.light_energy = 1.4
	l.omni_range = 7.0
	l.position = Vector3(0, 2.3, -2.4)
	h.add_child(l)
	# A ladder down to the island (a ramp of rungs you can walk up)
	var ramp_len := 2.2
	for k in 6:
		_mesh(_box(Vector3(1.0, 0.06, 0.12)), wood, Vector3(0, 0.15 + k * 0.18, -1.6 - ramp_len + k * 0.38), h)
	var ramp := _solid(_box_shape(Vector3(1.1, 0.1, 2.6)), Vector3(0, 0.6, -1.6 - ramp_len / 2.0 - 0.1), h, Vector3(-0.42, 0, 0))
	ramp.name = "Hut Ladder"


func _chest(isl: Dictionary) -> void:
	var g := _group("Swamp Chest")
	var at: Vector3 = (isl.at as Vector3) + ((isl.at as Vector3) - centre).normalized() * (float(isl.r) * 0.35)
	chest = Node3D.new()
	chest.name = "Chest"
	chest.position = at
	chest.rotation.y = atan2(centre.x - at.x, centre.z - at.z)
	g.add_child(chest)
	var wood := _mat("Chest Wood", lay.bark.lightened(0.3))
	var trim := _mat("Chest Trim", Color(0.7, 0.85, 0.4) if poison else Color(0.75, 0.7, 0.95), 0.4, 0.6)
	_mesh(_box(Vector3(1.1, 0.6, 0.7)), wood, Vector3(0, 0.3, 0), chest)
	for x: float in [-0.45, 0.45]:
		_mesh(_box(Vector3(0.08, 0.62, 0.72)), trim, Vector3(x, 0.3, 0), chest)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.6, -0.35)
	chest.add_child(lid)
	_mesh(_box(Vector3(1.12, 0.22, 0.72)), wood, Vector3(0, 0.11, 0.35), lid)
	_mesh(_box(Vector3(0.16, 0.16, 0.06)), trim, Vector3(0, 0.0, 0.72), lid)
	_solid(_box_shape(Vector3(1.1, 0.8, 0.7)), Vector3(0, 0.4, 0), chest)
	var l := OmniLight3D.new()
	l.light_color = (lay.water.glow_colour as Color) if poison else Color(0.8, 0.75, 1.0)
	l.light_energy = 0.9
	l.omni_range = 4.0
	l.position = Vector3(0, 1.2, 0.6)
	chest.add_child(l)
	var spot := USE_SPOT.make(Vector3(0, 0.2, 0.9), _chest_offer, open_chest, 2.2, 2.4)
	spot.name = "Chest Spot"
	chest.add_child(spot)
	if poison:
		var ride := USE_SPOT.make(Vector3(1.6, 0.2, 0.4), _float_offer, float_home, 2.0, 2.4)
		ride.name = "Bubble Spot"
		chest.add_child(ride)


func _chest_offer() -> String:
	return "open " + str(lay.chest_name) if not chest_open else ""


func chest_flag() -> String:
	return "swamp_%s_chest" % kind


func open_chest() -> void:
	if chest_open:
		return
	chest_open = true
	var lid := chest.get_node("Lid") as Node3D
	lid.create_tween().tween_property(lid, "rotation:x", -1.1, 0.5).set_trans(Tween.TRANS_BACK)
	var at := chest.global_position + Vector3(0, 1.0, 0)
	Fx.burst(self, at, (lay.water.glow_colour as Color) if poison else Color(0.85, 0.8, 1.0), 24, 0.12, 4.0, 3.0)
	Juice.blip("chime", 1.0, -4.0)
	if not Dialogue.flags.has(chest_flag()):
		Dialogue.set_flag(chest_flag())
		Game.add_sparkles(int(lay.sparkles))
		Remnants.add(int(lay.remnants))
		Game.message("%s! ✦ %d sparkles, +%d Remnant%s." % [str(lay.chest_name).substr(4).capitalize() if str(lay.chest_name).begins_with("the ")
			else str(lay.chest_name), int(lay.sparkles), int(lay.remnants), "" if int(lay.remnants) == 1 else "s"])
		return
	var day := "%s_%d" % [chest_flag(), Requests.visit_day()]
	if Dialogue.flags.has(day):
		Game.message("Empty today. Come back next time!")
		return
	Dialogue.set_flag(day)
	Game.add_sparkles(int(lay.again))
	Game.message("✦ %d sparkles." % int(lay.again))


func _float_offer() -> String:
	return "float home in a bog bubble" if chest_open and not _floating else ""


func float_home() -> void:
	# A big bubble carries you back over the goo to the Mire Edge
	if _floating or player == null:
		return
	_floating = true
	Game.hold_controls("swamp_bubble", true)
	var from := player.global_position
	var to: Vector3 = (islands[0].at as Vector3) + Vector3(0, 1.0, 0)
	var bubble := _mesh(_ball(1.0, 16), _mat("Bog Bubble", Color(0.75, 1.0, 0.7), 0.05, 0.4, 0.3), Vector3.ZERO, self)
	bubble.name = "Bog Bubble"
	Juice.blip("pop", 0.5, -6.0)
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void:
		if not is_instance_valid(player):
			return
		var p := from.lerp(to, f) + Vector3(0, sin(PI * f) * 6.0, 0)
		player.global_position = p
		player.velocity = Vector3.ZERO
		bubble.global_position = p + Vector3(0, 0.1, 0)
		bubble.scale = Vector3.ONE * (1.1 + 0.05 * sin(f * 30.0)), 0.0, 1.0, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		Fx.burst(self, bubble.global_position, Color(0.75, 1.0, 0.7), 16, 0.1, 3.0, -2.0, 0.6)
		Juice.blip("pop", 1.0, -6.0)
		bubble.queue_free()
		Game.hold_controls("swamp_bubble", false)
		last_safe = to
		_floating = false)


# Dangers (the Poison Mire) ----------------------------------------------------------------------------------------
func _vents() -> void:
	var g := _group("Poison Vents")
	var goo := _mat("Vent Goo", (lay.water.scum as Color), 0.15, 1.0)
	for i in (lay.vents as Array).size():
		var v: Array = lay.vents[i]
		var n := Node3D.new()
		n.name = "Vent %d" % (i + 1)
		var at := vent_spot(v)
		n.position = Vector3(at.x, SURFACE, at.z)
		g.add_child(n)
		_mesh(_ball(0.9, 14), goo, Vector3.ZERO, n).scale = Vector3(1.0, 0.25, 1.0)
		var bub := _mesh(_ball(0.5, 14), _mat("Vent Bubble", (lay.water.glow_colour as Color), 0.1, 1.4, 0.7), Vector3(0, 0.1, 0), n)
		bub.name = "Bubble"
		bub.scale = Vector3.ONE * 0.3
		n.set_meta("t", fmod(float(i) * 1.7, VENT_EVERY))
		n.set_meta("swell", 0.0)
		n.set_meta("bursts", 0)
		vents.append(n)


func way(which: String, i: int) -> Array:
	# [from, to]: a way across's two ends, at the edges of its islands
	var pair: Array = (lay[which] as Array)[i]
	var A: Dictionary = islands[int(pair[0])]
	var B: Dictionary = islands[int(pair[1])]
	var dir: Vector3 = ((B.at as Vector3) - (A.at as Vector3)).normalized()
	return [(A.at as Vector3) + dir * float(A.r), (B.at as Vector3) - dir * float(B.r)]


func vent_spot(v: Array) -> Vector3:
	var ends := way(str(v[0]), int(v[1]))
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var dir := (b - a).normalized()
	return a.lerp(b, float(v[2])) + Vector3(dir.z, 0, -dir.x) * float(v[3]) * 2.0


func _clouds() -> void:
	var g := _group("Poison Clouds")
	var puff := _mat("Poison Cloud", (lay.water.scum as Color).lerp(Color(0.8, 1.0, 0.6), 0.3), 0.9, 0.8, 0.45)
	for i in (lay.clouds as Array).size():
		var c: Array = lay.clouds[i]
		var n := Node3D.new()
		n.name = "Poison Cloud %d" % (i + 1)
		var ends := way(str(c[0]), int(c[1]))
		var dir := ((ends[1] as Vector3) - (ends[0] as Vector3)).normalized()
		var mid := (ends[0] as Vector3).lerp(ends[1], float(c[2]))
		var across := Vector3(dir.z, 0, -dir.x) * float(c[3])
		var a := mid + across + Vector3(0, 1.0, 0)
		var b := mid - across + Vector3(0, 1.0, 0)
		n.position = a
		n.set_meta("a", a)
		n.set_meta("b", b)
		n.set_meta("f", float(i) * 0.5)
		g.add_child(n)
		for k in 7:
			var off := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.5), _rng.randf_range(-1, 1)) * CLOUD_R * 0.6
			var m := _mesh(_ball(_rng.randf_range(0.6, 1.0), 12), puff, off, n)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.light_color = (lay.water.glow_colour as Color)
		l.light_energy = 0.6
		l.omni_range = 4.0
		n.add_child(l)
		clouds.append(n)


func _bubbles_pool() -> void:
	# Bubbles that come up through the water and pop (just to look at)
	var g := _group("Bubbles")
	var m := _mat("Swamp Bubble", (lay.water.scum as Color).lightened(0.3), 0.1, 0.8 if poison else 0.0, 0.6)
	for k in 24:
		var b := _mesh(_ball(0.12, 8), m, Vector3.ZERO, g)
		b.visible = false
		b.set_meta("t", -_rng.randf_range(0.0, 3.0))
		_bubbles.append(b)


func _wailers() -> void:
	var g := _group("Wailers")
	var w: Dictionary = lay.wailer
	for i in (lay.wailers as Array).size():
		var d: Array = lay.wailers[i]
		var c := WAILER.new() as CharacterBody3D
		c.name = "Bog Wailer %d" % (i + 1)
		c.set("wander_radius", float(d[2]))
		c.set("skin", w.skin)
		c.set("head_colour", w.head)
		c.set("eye_colour", w.eye)
		c.set("muck", w.muck)
		c.set("bed_y", BED)
		c.set("murk_top", SURFACE)
		c.position = Vector3(float(d[0]), BED + 0.1, float(d[1]))
		g.add_child(c)
		wailers.append(c)


# Every frame -------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	_told = maxf(_told - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if player == null:
			return
	var near := _flat(player.global_position).distance_to(_flat(centre)) < radius + 10.0
	if not near:
		return
	if not arrived and _flat(player.global_position).distance_to(_flat(centre)) < radius:
		arrived = true
		Game.message(str(lay.hello))
	_ride_told = maxf(_ride_told - delta, 0.0)
	_no_rides()
	_lookout_step()
	_sinkers_step(delta)
	if poison:
		_poison_step(delta)
		if hazards:
			_vents_step(delta)
			_clouds_step(delta)


func _process(delta: float) -> void:
	if player == null or _flat(player.global_position).distance_to(_flat(centre)) > radius + 40.0:
		return
	_move_motes(delta)
	_bubbles_step(delta)
	_frogs_step(delta)


func _standing_on() -> Node:
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0, -1.3, 0))
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider as Node if not hit.is_empty() else null


func _sinkers_step(delta: float) -> void:
	var under: Node = _standing_on() if player.is_on_floor() else null
	for s in sinkers:
		var st := str(s.get_meta("state"))
		var t := float(s.get_meta("t")) + delta
		var rest := float(s.get_meta("rest_y"))
		var look := s.get_node("Look") as Node3D
		match st:
			"up":
				if under == s:
					s.set_meta("stood", float(s.get_meta("stood")) + delta)
					if float(s.get_meta("stood")) >= SINK_AFTER:
						st = "wobble"
						t = 0.0
						Juice.blip("squish", 0.6, -8.0)
				else:
					s.set_meta("stood", maxf(float(s.get_meta("stood")) - delta * 0.5, 0.0))
				look.position = Vector3.ZERO
			"wobble":
				look.position = Vector3(sin(t * 50.0) * 0.05, 0, cos(t * 43.0) * 0.05)
				if fmod(t, 0.2) < delta:
					Fx.burst(self, s.global_position + Vector3(0, 0.3, 0), (lay.water.scum as Color), 3, 0.06, 1.2, -4.0, 0.4)
				if t >= SINK_WOBBLE:
					st = "sinking"
					t = 0.0
			"sinking":
				look.position = Vector3.ZERO
				s.position.y = lerpf(rest, rest - SINK_DEPTH, clampf(t / 0.45, 0.0, 1.0))
				if t >= SINK_DOWN:
					st = "rising"
					t = 0.0
			"rising":
				s.position.y = lerpf(rest - SINK_DEPTH, rest, clampf(t / 0.8, 0.0, 1.0))
				if t >= 0.8:
					st = "up"
					t = 0.0
					s.set_meta("stood", 0.0)
		s.set_meta("state", st)
		s.set_meta("t", t)


func no_ride_here(p: Vector3) -> String:
	# Rides don't work in the swamps (Hayden, 24 Nov 2026): too squelchy. Game.ride_blocked() asks this.
	return "No rides in the swamp! Too squelchy." if in_basin(p) else ""


func _no_rides() -> void:
	# Ride in (or get put on a ride) and you're tipped off it at the swamp's edge
	if Game.riding and in_basin(player.global_position) and not _floating:
		Game.riding = false
		Game.equipment_changed.emit()
		Juice.blip("squish", 0.7, -4.0)
		Fx.burst(self, player.global_position + Vector3(0, 0.2, 0), (lay.water.scum as Color), 10, 0.08, 2.0, -4.0, 0.5)
		if _ride_told <= 0.0:
			_ride_told = POISON_TELL
			Game.message(no_ride_here(player.global_position))


func _lookout(isl: Dictionary) -> void:
	# The Lookout Tree: a huge dead tree just past the chest island with a plank stair winding up round it to a
	# railed platform 14 m up, where you can see the whole swamp (and which way you should have gone).
	var g := _group("Lookout")
	lookout = g
	var out := ((isl.at as Vector3) - centre).normalized()
	var at: Vector3 = (isl.at as Vector3) + out * (float(isl.r) + 1.2)
	g.position = at
	var land := _mat("Swamp Land", lay.land)
	var moss := _mat("Swamp Moss", lay.land_top)
	var bark := _mat("Lookout Bark", lay.bark)
	var wood := _mat("Lookout Planks", lay.bark.lightened(0.3))
	var rope := _mat("Lookout Rope", lay.bark.lightened(0.5))
	# Its own little mound, joined onto the island
	_mesh(_cyl(3.0, 3.7, 0.9, 24), land, Vector3(0, -0.45, 0), g)
	_mesh(_cyl(2.8, 3.0, 0.06, 24), moss, Vector3(0, 0.0, 0), g)
	var mound := _solid(_cyl_shape(3.0, 1.0), Vector3(0, -0.5, 0), g, Vector3.ZERO, "Lookout Mound")
	mound.add_to_group("swamp_safe")
	# The trunk, with roots and dead branches
	_mesh(_cyl(LOOK_IN * 0.8, LOOK_IN * 1.15, LOOK_TOP + 1.2, 14), bark, Vector3(0, (LOOK_TOP + 1.2) / 2.0, 0), g)
	_solid(_cyl_shape(LOOK_IN, LOOK_TOP), Vector3(0, LOOK_TOP / 2.0, 0), g, Vector3.ZERO, "Lookout Trunk")
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		_mesh(_cyl(0.12, 0.35, 2.2, 8), bark, Vector3(cos(a) * 1.1, 0.2, sin(a) * 1.1), g, Vector3(0, -a, 1.1))
	for k in 3:
		var a := TAU * k / 3.0 + 1.0
		_mesh(_cyl(0.06, 0.2, 3.0, 6), bark, Vector3(cos(a) * 1.6, LOOK_TOP + 1.6, sin(a) * 1.6), g, Vector3(0, -a, 0.9))
	# The stair: starts at the ground on the island's side and winds up anticlockwise
	var a0 := atan2(-out.z, -out.x)
	lookout_a0 = a0
	var n := int(LOOK_TURNS * LOOK_STEPS)
	var step := TAU / LOOK_STEPS
	var rise := LOOK_TOP / (n - 2)                        # (the last few are flat: a landing under the open bit)
	var mid_r := (LOOK_IN + LOOK_OUT) / 2.0
	var piece := 2.0 * LOOK_OUT * sin(step / 2.0) + 0.12
	var pitch := atan2(rise, mid_r * step)
	for j in n + 3:
		var a := a0 + (j + 0.5) * step
		var y := minf((j + 0.5) * rise, LOOK_TOP)
		var p := Vector3(cos(a) * mid_r, y - 0.08, sin(a) * mid_r)
		var flat := j >= n - 2
		# (a box's length runs along its z: turn it to run round the tree, then tip it up the slope)
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.0 if flat else -pitch)
		var body := Node3D.new()                          # (just the plank you see: what you walk on is one smooth ramp, below)
		body.name = "Lookout Plank"
		body.transform = Transform3D(b, p)
		g.add_child(body, true)
		_mesh(_box(Vector3(LOOK_OUT - LOOK_IN, 0.12, piece - 0.06)), wood, Vector3.ZERO, body,
			Vector3(0, _rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.03, 0.03)))
		# A rope rail on posts round the outside (not on the landing, which opens onto the platform)
		if j < n - 3:
			var post := p + Vector3(cos(a), 0, sin(a)) * ((LOOK_OUT - LOOK_IN) / 2.0 - 0.06)
			if j % 2 == 0:
				_mesh(_cyl(0.05, 0.06, 1.1, 6), bark, post + Vector3(0, 0.55, 0), g)
			var rail := StaticBody3D.new()
			rail.name = "Lookout Rail"
			rail.transform = Transform3D(b, post + Vector3(0, 0.55, 0))
			var rs := CollisionShape3D.new()
			rs.shape = _box_shape(Vector3(0.1, 1.1, piece))
			rail.add_child(rs)
			g.add_child(rail, true)
			_mesh(_box(Vector3(0.05, 0.05, piece)), rope, Vector3(0, 0.45, 0), rail)
		if j == 0:
			lookout_foot = at + Vector3(cos(a) * mid_r, 0.3, sin(a) * mid_r)
	# What you walk on: one smooth winding ramp under the planks. (Separate tipped boxes left little lips at every
	# join, and one at the top caught her feet.)
	var faces := PackedVector3Array()
	var subs := 4
	var total := (n + 3) * subs
	for i in total:
		var t0 := float(i) / subs
		var t1 := float(i + 1) / subs
		var aa := a0 + t0 * step
		var ab := a0 + t1 * step
		var ya := minf(t0 * rise, LOOK_TOP)
		var yb := minf(t1 * rise, LOOK_TOP)
		var ia := Vector3(cos(aa) * LOOK_IN, ya, sin(aa) * LOOK_IN)
		var oa := Vector3(cos(aa) * LOOK_OUT, ya, sin(aa) * LOOK_OUT)
		var ib := Vector3(cos(ab) * LOOK_IN, yb, sin(ab) * LOOK_IN)
		var ob := Vector3(cos(ab) * LOOK_OUT, yb, sin(ab) * LOOK_OUT)
		faces.append_array([ia, ob, oa, ia, ib, ob])        # (facing up)
	var ramp_shape := ConcavePolygonShape3D.new()
	ramp_shape.set_faces(faces)
	ramp_shape.backface_collision = true
	var ramp := StaticBody3D.new()
	ramp.name = "Lookout Stair"
	var rcs := CollisionShape3D.new()
	rcs.shape = ramp_shape
	ramp.add_child(rcs)
	g.add_child(ramp, true)
	ramp.add_to_group("swamp_safe")
	# The platform: a ring of planks round the top of the tree, railed all round
	var ring_n := 28
	var hole_from := a0 + (n - 10) * step                 # (open over the stair's last bit, for headroom, but only as wide
	var hole_to := a0 + n * step                          # as the stair: a walkway stays round the outside)
	for k in ring_n:
		var a := TAU * k / ring_n
		var into := fposmod(a - hole_from, TAU)
		var hole := into < hole_to - hole_from
		var inner := LOOK_OUT + 0.1 if hole else LOOK_IN
		var r := (inner + LOOK_RING) / 2.0
		var w := 2.0 * LOOK_RING * sin(PI / ring_n) + 0.1
		var b := Basis(Vector3.UP, -a)
		var rail := StaticBody3D.new()
		rail.name = "Lookout Rail"
		rail.transform = Transform3D(b, Vector3(cos(a) * (LOOK_RING - 0.05), LOOK_TOP + 0.55, sin(a) * (LOOK_RING - 0.05)))
		var rs := CollisionShape3D.new()
		rs.shape = _box_shape(Vector3(0.1, 1.1, w))
		rail.add_child(rs)
		g.add_child(rail, true)
		_mesh(_box(Vector3(0.06, 0.06, w)), rope, Vector3(0, 0.45, 0), rail)
		if k % 2 == 0:
			_mesh(_cyl(0.06, 0.07, 1.2, 6), bark, Vector3(cos(a) * (LOOK_RING - 0.05), LOOK_TOP + 0.6, sin(a) * (LOOK_RING - 0.05)), g)
		var body := StaticBody3D.new()
		body.name = "Lookout Platform"
		body.transform = Transform3D(b, Vector3(cos(a) * r, LOOK_TOP - 0.08, sin(a) * r))
		var cs := CollisionShape3D.new()
		cs.shape = _box_shape(Vector3(LOOK_RING - inner, 0.16, w))
		body.add_child(cs)
		g.add_child(body, true)
		body.add_to_group("swamp_safe")
		_mesh(_box(Vector3(LOOK_RING - inner, 0.12, w - 0.05)), wood, Vector3.ZERO, body)
	var look_a := a0 + TAU * 0.8                         # (a spot on the platform away from the stair's hole)
	lookout_top = at + Vector3(cos(look_a), 0, sin(look_a)) * ((LOOK_IN + LOOK_RING) / 2.0) + Vector3(0, LOOK_TOP + 0.3, 0)
	# A lantern up top, so it's easy to spot from the way in, and a little sign at the foot
	var glow := _mat("Lookout Glow", (lay.water.glow_colour as Color) if poison else Color(1.0, 0.85, 0.5), 0.4, 2.0)
	_mesh(_ball(0.3, 10), glow, Vector3(0, LOOK_TOP + 1.9, 0), g)
	var l := OmniLight3D.new()
	l.light_color = (glow.emission as Color)
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.position = Vector3(0, LOOK_TOP + 1.9, 0)
	g.add_child(l)
	var sign := Label3D.new()
	sign.text = "Lookout"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.modulate = Color(0.95, 0.9, 0.8)
	sign.outline_size = 10
	sign.position = Vector3(cos(a0) * 3.1, 1.4, sin(a0) * 3.1)
	sign.rotation.y = -a0 + PI / 2.0
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)


func lookout_flag() -> String:
	return "swamp_lookout_%s" % kind


func _lookout_step() -> void:
	# At the top: once a visit "What a view!", and 3 sparkles the very first time
	if lookout == null or lookout_seen:
		return
	var p := player.global_position
	if p.y < LOOK_TOP - 0.5 or _flat(p).distance_to(_flat(lookout.global_position)) > LOOK_RING + 0.5:
		return
	lookout_seen = true
	Juice.blip("sparkle", 1.0, -4.0)
	Fx.burst(self, p + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.6), 18, 0.1, 3.0, 2.0)
	if not Dialogue.flags.has(lookout_flag()):
		Dialogue.set_flag(lookout_flag())
		Game.add_sparkles(3)
		Game.message("What a view! You can see the whole swamp. ✦ 3 sparkles.")
	else:
		Game.message("What a view!")


func in_basin(p: Vector3) -> bool:
	return _flat(p).distance_to(_flat(centre)) < radius + 2.0


func _poison_step(delta: float) -> void:
	var p := player.global_position
	if not in_basin(p):
		return
	var feet := p.y - 0.8
	# Remember where she last stood safe (never on a Sinker Stone: it might be down when she's put back)
	if player.is_on_floor() and feet > SURFACE + 0.05:
		_safe_t -= delta
		if _safe_t <= 0.0:
			_safe_t = 0.2
			var under := _standing_on()
			if under and under.is_in_group("swamp_safe"):
				last_safe = p + Vector3(0, 0.2, 0)
	if feet < SURFACE - 0.02 and not _floating:
		var b: Variant = player.get("burrow")
		if b != null and is_instance_valid(b) and bool(b.get("active")):
			return
		poison_bump(p)


func poison_bump(from: Vector3) -> void:
	# Super poison! A bump (when she can be hurt), and back where she last stood safe
	bumps += 1
	if not player.call("is_invulnerable"):
		player.call("hurt", 1, from + Vector3(0.01, 0, 0))
	player.velocity = Vector3.ZERO
	player.global_position = last_safe
	var col: Color = lay.water.glow_colour
	Fx.burst(self, Vector3(from.x, SURFACE + 0.1, from.z), col, 18, 0.1, 3.5, -6.0, 0.7)
	Fx.burst(self, last_safe, col, 10, 0.08, 2.0, 0.0, 0.5)
	Juice.blip("squish", 0.5, -2.0)
	if _told <= 0.0:
		_told = POISON_TELL
		Game.message("Yuck! Super poison! Keep to the stones.")


func _vents_step(delta: float) -> void:
	for v in vents:
		var far := _flat(v.global_position).distance_to(_flat(player.global_position)) > 28.0
		var t := float(v.get_meta("t")) + delta
		var bub := v.get_node("Bubble") as Node3D
		var swell_at := VENT_EVERY - VENT_SWELL
		if t >= swell_at:
			var k := (t - swell_at) / VENT_SWELL
			bub.scale = Vector3.ONE * lerpf(0.3, 1.5, k * k) * (1.0 + 0.04 * sin(t * 40.0))
			v.set_meta("swell", k)
		else:
			bub.scale = Vector3.ONE * (0.3 + 0.03 * sin(t * 3.0))
			v.set_meta("swell", 0.0)
		if t >= VENT_EVERY:
			t = 0.0
			if not far:
				burst_vent(v)
		v.set_meta("t", t)


func burst_vent(v: Node3D) -> void:
	v.set_meta("bursts", int(v.get_meta("bursts")) + 1)
	var col: Color = lay.water.glow_colour
	var r := ShockRing.spawn(self, v.global_position, 3.4, col, 1, 0.9, "goo")
	r.name = "Vent Ring"
	Fx.burst(self, v.global_position + Vector3(0, 0.3, 0), col, 16, 0.12, 4.0, -6.0, 0.7)
	Audio.play_at("bubbles", v.global_position, -2.0, 0.2)
	Juice.blip("pop", 0.45, -6.0)


func _clouds_step(delta: float) -> void:
	for c in clouds:
		var f := float(c.get_meta("f")) + delta * 0.06
		c.set_meta("f", f)
		var k := 0.5 - 0.5 * cos(f * TAU)                     # back and forth, easing at the ends
		c.position = (c.get_meta("a") as Vector3).lerp(c.get_meta("b"), k) + Vector3(0, sin(f * 9.0) * 0.15, 0)
		c.rotation.y += delta * 0.3
		var to := player.global_position - c.global_position
		if Vector2(to.x, to.z).length() < CLOUD_R + 0.3 and to.y > -2.0 and to.y < 2.2 and not _floating \
				and not player.call("is_invulnerable"):
			player.call("hurt", 1, c.global_position)
			if _told <= 0.0:
				_told = POISON_TELL
				Game.message("Pee-yew! A poison cloud!")


func _bubbles_step(delta: float) -> void:
	for b in _bubbles:
		var t := float(b.get_meta("t")) + delta
		if t < 0.0:
			b.set_meta("t", t)
			continue
		if not b.visible:
			var a := _rng.randf() * TAU
			var p := centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, radius - 1.0)
			if not _on_island(p).is_empty():
				b.set_meta("t", -0.2)
				continue
			b.position = Vector3(p.x, SURFACE, p.z)
			b.visible = true
			t = 0.0
		var life := 1.6
		b.scale = Vector3.ONE * (0.3 + t / life) * Vector3(1, 0.6, 1)
		if t >= life:
			b.visible = false
			Fx.burst(self, b.position + Vector3(0, 0.05, 0), (lay.water.scum as Color).lightened(0.3), 4, 0.04, 1.2, -6.0, 0.35)
			t = -_rng.randf_range(0.3, 2.0)
		b.set_meta("t", t)


func _frogs_step(delta: float) -> void:
	for f in frogs:
		var throat := f.get_node("Throat") as Node3D
		var c := float(f.get_meta("croak")) - delta
		var hop := float(f.get_meta("hop"))
		if hop > 0.0:
			hop -= delta
			var k := 1.0 - hop / 0.5
			var from: Vector3 = f.get_meta("from")
			var to: Vector3 = f.get_meta("to")
			f.position = from.lerp(to, k) + Vector3(0, sin(PI * k) * 0.6, 0)
			f.set_meta("hop", hop)
			continue
		if player and _flat(player.global_position).distance_to(_flat(f.global_position)) < 2.5:
			# Off it hops, away from her, onto the water (and then back home a while later)
			var away := (f.global_position - player.global_position) * Vector3(1, 0, 1)
			var to := f.position + away.normalized() * 1.6
			to.y = maxf(SURFACE + 0.02, f.position.y - 0.2) if _on_island(to).is_empty() else f.position.y
			f.set_meta("from", f.position)
			f.set_meta("to", to)
			f.set_meta("hop", 0.5)
			f.rotation.y = atan2(away.x, away.z)
			Juice.blip("croak", 1.4, -12.0)
			continue
		if c <= 0.0:
			c = _rng.randf_range(3.0, 8.0)
			if player and _flat(player.global_position).distance_to(_flat(f.global_position)) < 14.0:
				Juice.blip("croak", _rng.randf_range(0.85, 1.15), -12.0)
			var tw := f.create_tween()
			tw.tween_property(throat, "scale", Vector3(1.8, 1.8, 1.8), 0.12)
			tw.tween_property(throat, "scale", Vector3.ONE, 0.2)
		f.set_meta("croak", c)
