extends Node3D

# The Secret Garden, a real one this time (Hayden's day 1 playtest, 11 Nov 2026: "the secret garden needs to be much
# larger, and it's not very secret right now; maybe we can fix that somehow"). Everybody knows the Secret Gardens up on
# the hill, with your garden plot and the greenhouse; this is the one nobody's found for years. Its way in is an old
# ivy-covered wall at the foot of the hill's north cliff, and only the little wren knows it (scripts/secret_garden_way.gd).
#
# This is the root of scenes/secret_garden/secret_garden.tscn (made by tools/build_secret_garden.gd), which holds only
# this script, an Entrance and the player. Everything else is built here when it loads, like the race circuits and the
# Gloop Kingdom: about 140 by 150 m inside old ivy-covered walls.
#   - the Rose Walk: a tunnel of rose arches from the door, with a little alcove halfway along
#   - the Fountain Lawn in the middle: a round lawn and a fountain with the wren on top
#   - the Hedge Maze to the west (a real maze, the same every time: a seeded maze over a grid of cells)
#   - the Lily Pond to the east: shallow enough to wade, lily pads, and a little island in the middle
#   - the Giant Flowers to the north: a ring of huge flowers, each a bit taller than the last, to climb up to the top
#   - the Great Tree to the north-west, with an old swing
# Five **sleeping seeds** are hidden about (one in each of those places): walk up to one and it wakes into a glowing
# flower. All five and the whole garden wakes up: everything brightens, petals drift down, and you get a reward
# (WAKE_SPARKLES, WAKE_REMNANTS, once). Found seeds are Dialogue flags (sg_seed_<id>, sg_awake), so nothing new in the
# save. Everything you walk on is flush with the ground: the player can't step up a ledge on foot.

const TOWN := "res://scenes/town/town.tscn"
const USE_SPOT := preload("res://scripts/use_spot.gd")
const WATER := preload("res://scripts/water.gd")

const WALL_X := 70.0                          # the walls: x from -70 to 70...
const WALL_Z := Vector2(0, 150)               # ...and z from 0 to 150 (the door's in the south wall, at x 0)
const FOUNTAIN := Vector3(0, 0, 52)
const LAWN_R := 15.0
const MAZE := Vector3(-42, 0, 52)             # the maze's middle
const MAZE_CELLS := 7                         # cells a side (odd, so there's a middle cell)
const MAZE_CELL := 4.2                        # metres a cell
const POND := Vector3(40, 0, 54)
const POND_R := Vector2(17, 13)
const POND_Y := 0.35                          # its surface: shallow, so you wade
const ISLAND_R := 3.6
const FLOWERS := Vector3(0, 0, 108)           # the middle of the ring of giant flowers
const TREE := Vector3(-44, 0, 118)            # the Great Tree
const SEED_REACH := 1.6
const WAKE_SPARKLES := 20
const WAKE_REMNANTS := 2

# The sleeping seeds: id, where, and what the note says when you wake one
const SEEDS := [
	{"id": "walk", "where": "in the Rose Walk's alcove"},
	{"id": "maze", "where": "at the heart of the Hedge Maze"},
	{"id": "pond", "where": "on the Lily Pond's island"},
	{"id": "flower", "where": "on top of the tallest flower"},
	{"id": "tree", "where": "behind the Great Tree"},
]

var seeds := {}                               # id -> {"node": Node3D, "at": Vector3}
var awake := false
var maze_open := []                           # [cell index] -> Array of open sides ("n", "s", "e", "w"), for tests
var flower_tops: Array[Vector3] = []          # the top of each giant flower, lowest first (for tests)
var flower_radii: Array[float] = []           # ...and how wide each one's face is
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _t := 0.0
var _petals: MultiMeshInstance3D
var _petal_pos: Array[Vector3] = []
var _glows: Array[StandardMaterial3D] = []
var _sky: ProceduralSkyMaterial
var _env: Environment
var _home_spot: Area3D


func _enter_tree() -> void:
	# (a marker looks along its -Z, so the Entrance turns round to face into the garden, which is north, along +Z)
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = Vector3(0, 1.0, 3.0)
			(n as Node3D).rotation.y = PI if n.name == "Entrance" else 0.0


func _ready() -> void:
	_rng.seed = 2611
	_environment()
	_ground()
	_walls()
	_rose_walk()
	_fountain()
	_maze()
	_pond()
	_giant_flowers()
	_great_tree()
	_scatter()
	_place_seeds()
	_way_out()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	awake = Dialogue.flags.has("sg_awake")
	_set_awake(1.0 if awake else 0.0)


# -----------------------------------------------------------------------------
# Little helpers (the same as the Gloop Kingdom's, scripts/gloop_kingdom.gd)
# -----------------------------------------------------------------------------
func _mat(name: String, c: Color, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, name: String, shape: Shape3D, at: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	body.rotation = rot
	parent.add_child(body)
	return body


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, m: Material, solid := true, yaw := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(parent, bm, at, m)
	mi.name = name
	mi.rotation.y = yaw
	if solid:
		var bs := BoxShape3D.new()
		bs.size = size
		_solid(parent, name + " Body", bs, at, Vector3(0, yaw, 0))
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 20
	var mi := _mesh(parent, cm, at, m)
	mi.name = name
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(r_top, r_bottom)
		cs.height = h
		_solid(parent, name + " Body", cs, at)
	return mi


func _ball(parent: Node3D, r: float, at: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 12
	sm.rings = 6
	return _mesh(parent, sm, at, m, false)


func _label(parent: Node3D, text: String, at: Vector3, yaw: float, size := 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.92, 0.7)
	l.outline_size = 10
	l.outline_modulate = Color(0.15, 0.1, 0.2)
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l


func _leaf() -> StandardMaterial3D:
	return _mat("Garden Leaf", Color(0.2, 0.5, 0.25), 0.8)


func _hedge() -> StandardMaterial3D:
	return _mat("Hedge", Color(0.16, 0.42, 0.22), 0.9)


func _brick() -> StandardMaterial3D:
	return _mat("Old Brick", Color(0.62, 0.44, 0.52), 0.95)


# -----------------------------------------------------------------------------
# Sky, light and the ground
# -----------------------------------------------------------------------------
func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color(0.34, 0.3, 0.6)                     # a soft lilac-blue sky, gold low down
	_sky.sky_horizon_color = Color(0.96, 0.82, 0.72)
	_sky.ground_horizon_color = Color(0.5, 0.6, 0.45)
	_sky.ground_bottom_color = Color(0.2, 0.3, 0.2)
	sky.sky_material = _sky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.adjustment_enabled = true                                  # asleep the colours are a little faded (_set_awake)
	env.adjustment_saturation = 0.9
	_env = env
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.55, 0.72)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.1
	var we := WorldEnvironment.new()
	we.name = "Garden Sky"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	add_child(sun)


func _ground() -> void:
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	var m := StandardMaterial3D.new()
	m.resource_name = "Garden Grass"
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	noise.noise = n
	var grad := Gradient.new()
	grad.set_color(0, Color(0.26, 0.5, 0.26))
	grad.set_color(1, Color(0.42, 0.66, 0.34))
	noise.color_ramp = grad
	m.albedo_texture = noise
	m.uv1_scale = Vector3(36, 36, 1)
	m.roughness = 0.95
	var mi := _mesh(g, plane, Vector3(0, 0, 75), m, false)
	mi.name = "Lawn"
	var bs := BoxShape3D.new()
	bs.size = Vector3(240, 2.0, 240)
	_solid(g, "Ground Body", bs, Vector3(0, -1.0, 75))
	# Gravel paths: thin, flat and only to look at (you walk on the ground under them)
	var gravel := _mat("Gravel Path", Color(0.86, 0.8, 0.7), 0.95)
	for p in [[Vector3(0, 0.02, 40), Vector2(4, 22)], [Vector3(-22, 0.02, 52), Vector2(14, 4)],
			[Vector3(22, 0.02, 52), Vector2(10, 4)], [Vector3(0, 0.02, 82), Vector2(4, 32)],
			[Vector3(-22, 0.02, 108), Vector2(40, 3.5)]]:
		var pm := PlaneMesh.new()
		pm.size = p[1]
		_mesh(g, pm, p[0], gravel, false).name = "Path"


func _walls() -> void:
	# Old brick walls all round, thick with ivy, 5 m high; the only gap is the door in the south wall
	var w := Node3D.new()
	w.name = "Garden Walls"
	add_child(w)
	var h := 5.0
	var span_x := WALL_X * 2.0
	var span_z := WALL_Z.y - WALL_Z.x
	# South wall, either side of the doorway (2.4 m wide)
	for side in [-1.0, 1.0]:
		var len := WALL_X - 1.2
		_box(w, "South Wall", Vector3(len, h, 1.0), Vector3(side * (1.2 + len / 2.0), h / 2.0, WALL_Z.x), _brick())
	_box(w, "Door Lintel", Vector3(3.2, 1.2, 1.2), Vector3(0, 3.6, WALL_Z.x), _brick())
	_box(w, "North Wall", Vector3(span_x, h, 1.0), Vector3(0, h / 2.0, WALL_Z.y), _brick())
	for side in [-1.0, 1.0]:
		_box(w, "Side Wall", Vector3(1.0, h, span_z), Vector3(side * WALL_X, h / 2.0, (WALL_Z.x + WALL_Z.y) / 2.0), _brick())
	# Coping stones on top, and ivy all over the inside faces
	var coping := _mat("Coping Stone", Color(0.8, 0.74, 0.78), 0.8)
	_box(w, "Coping", Vector3(span_x + 1.0, 0.25, 1.4), Vector3(0, h + 0.1, WALL_Z.y), coping, false)
	for side in [-1.0, 1.0]:
		_box(w, "Coping", Vector3(1.4, 0.25, span_z), Vector3(side * WALL_X, h + 0.1, (WALL_Z.x + WALL_Z.y) / 2.0), coping, false)
	var ivy := _mat("Ivy", Color(0.18, 0.46, 0.2), 0.85)
	var ivy2 := _mat("Ivy Light", Color(0.3, 0.58, 0.24), 0.85)
	for k in 260:
		var t := _rng.randf()
		var at := Vector3.ZERO
		var along := _rng.randf()
		match k % 4:
			0:
				at = Vector3(lerpf(-WALL_X, WALL_X, along), 0, WALL_Z.y - 0.6)
			1:
				at = Vector3(-WALL_X + 0.6, 0, lerpf(WALL_Z.x, WALL_Z.y, along))
			2:
				at = Vector3(WALL_X - 0.6, 0, lerpf(WALL_Z.x, WALL_Z.y, along))
			3:
				var sx := -1.0 if _rng.randf() < 0.5 else 1.0
				at = Vector3(sx * lerpf(2.0, WALL_X, along), 0, WALL_Z.x + 0.6)
		at.y = lerpf(0.4, h - 0.2, sqrt(t))
		_ball(w, _rng.randf_range(0.5, 1.1), at, ivy if k % 3 else ivy2, 0.6)
	# Invisible walls a little outside, so nobody climbs out over the top
	var edge := Node3D.new()
	edge.name = "WorldBounds Garden"
	add_child(edge)
	for p in [[Vector3(0, 10, WALL_Z.x - 1.5), Vector3(span_x + 6, 20, 1)], [Vector3(0, 10, WALL_Z.y + 1.5), Vector3(span_x + 6, 20, 1)],
			[Vector3(-WALL_X - 1.5, 10, 75), Vector3(1, 20, span_z + 6)], [Vector3(WALL_X + 1.5, 10, 75), Vector3(1, 20, span_z + 6)]]:
		var bs := BoxShape3D.new()
		bs.size = p[1]
		_solid(edge, "Edge", bs, p[0])
	# Tall old trees just outside the walls, so it feels tucked away
	var trunk := _mat("Old Bark", Color(0.36, 0.26, 0.3), 0.95)
	var crown := _mat("Old Leaves", Color(0.22, 0.44, 0.3), 0.9)
	for k in 30:
		var a := TAU * k / 30.0
		var at := Vector3(cos(a) * 95.0, 0, 75.0 + sin(a) * 100.0)
		var th := _rng.randf_range(12.0, 18.0)
		_cyl(w, "Outer Tree", 0.8, 1.2, th, at + Vector3(0, th / 2.0, 0), trunk, false)
		_ball(w, _rng.randf_range(6.0, 9.0), at + Vector3(0, th + 2.0, 0), crown, 0.8)


# -----------------------------------------------------------------------------
# The Rose Walk: arches from the door up to the lawn
# -----------------------------------------------------------------------------
func _rose_walk() -> void:
	var walk := Node3D.new()
	walk.name = "Rose Walk"
	add_child(walk)
	var iron := _mat("Old Iron", Color(0.3, 0.26, 0.34), 0.5)
	var rose_cols := [_mat("Rose Pink", Color(1.0, 0.5, 0.7), 0.6, 0.15), _mat("Rose Cream", Color(1.0, 0.92, 0.8), 0.6, 0.1),
		_mat("Rose Red", Color(0.92, 0.25, 0.4), 0.6, 0.12)]
	for k in 9:
		var z := 6.0 + k * 3.2
		for side in [-1.0, 1.0]:
			_cyl(walk, "Arch Post", 0.09, 0.09, 3.2, Vector3(side * 1.9, 1.6, z), iron, true)
		var top := TorusMesh.new()
		top.inner_radius = 1.82
		top.outer_radius = 1.98
		top.rings = 24
		var mi := _mesh(walk, top, Vector3(0, 3.2, z), iron)
		mi.rotation = Vector3(PI / 2.0, 0, 0)
		mi.scale = Vector3(1, 1, 1)
		for r in 7:
			var a := PI * r / 6.0
			_ball(walk, _rng.randf_range(0.28, 0.4), Vector3(cos(a) * 1.9, 3.2 + sin(a) * 1.9, z), rose_cols[(k + r) % 3])
			_ball(walk, 0.45, Vector3(cos(a) * 1.9 + 0.2, 3.2 + sin(a) * 1.9 - 0.2, z + 0.4), _leaf(), 0.7)
	# Rose bushes along both sides, and an alcove halfway on the west with a stone bench
	for k in 14:
		for side in [-1.0, 1.0]:
			var z := 5.0 + k * 2.0
			if side < 0.0 and z > 15.0 and z < 22.0:
				continue
			_ball(walk, 0.9, Vector3(side * 3.0, 0.7, z), _leaf(), 0.8)
			_ball(walk, 0.3, Vector3(side * 2.8, 1.3, z + 0.3), rose_cols[k % 3])
	var stone := _mat("Garden Stone", Color(0.78, 0.74, 0.8), 0.8)
	_box(walk, "Alcove Bench", Vector3(1.6, 0.45, 0.6), Vector3(-5.4, 0.23, 18.5), stone, true, PI / 2.0)
	for side in [-1.0, 1.0]:
		_ball(walk, 1.1, Vector3(-4.6, 0.9, 18.5 + side * 2.6), _hedge(), 0.9)


# -----------------------------------------------------------------------------
# The Fountain Lawn
# -----------------------------------------------------------------------------
func _fountain() -> void:
	var f := Node3D.new()
	f.name = "Fountain Lawn"
	f.position = FOUNTAIN
	add_child(f)
	var lawn := CylinderMesh.new()
	lawn.top_radius = LAWN_R
	lawn.bottom_radius = LAWN_R
	lawn.height = 0.04
	lawn.radial_segments = 48
	_mesh(f, lawn, Vector3(0, 0.03, 0), _mat("Fine Lawn", Color(0.38, 0.68, 0.36), 0.9), false)
	var stone := _mat("Garden Stone", Color(0.78, 0.74, 0.8), 0.8)
	_cyl(f, "Fountain Basin", 4.0, 4.2, 0.8, Vector3(0, 0.4, 0), stone, true)
	_cyl(f, "Fountain Water", 3.7, 3.7, 0.1, Vector3(0, 0.78, 0), _mat("Fountain Water", Color(0.45, 0.75, 0.95, 0.8), 0.05, 0.3), false)
	_cyl(f, "Fountain Column", 0.5, 0.7, 2.6, Vector3(0, 1.6, 0), stone, true)
	_cyl(f, "Fountain Bowl", 1.6, 0.6, 0.5, Vector3(0, 3.0, 0), stone, false)
	# The spray: a column of glassy balls bobbing (moved in _process)
	var spray := Node3D.new()
	spray.name = "Spray"
	f.add_child(spray)
	for k in 10:
		_ball(spray, 0.22, Vector3(0, 3.4 + k * 0.25, 0), _mat("Spray", Color(0.7, 0.9, 1.0, 0.7), 0.05, 0.4))
	# A stone wren on top, looking south to the door
	var wren := _wren_model(_mat("Garden Stone", Color(0.78, 0.74, 0.8), 0.8), _mat("Garden Stone", Color(0.78, 0.74, 0.8), 0.8))
	wren.position = Vector3(0, 3.3, 0)
	wren.scale = Vector3.ONE * 2.2
	f.add_child(wren)
	# Benches round the lawn and flower beds round its rim
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		var at := Vector3(cos(a), 0, sin(a)) * (LAWN_R - 2.0)
		_box(f, "Bench", Vector3(2.0, 0.45, 0.6), at + Vector3(0, 0.23, 0), _mat("Bench Wood", Color(0.55, 0.38, 0.32)), true, -a + PI / 2.0)
	var petals := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 0.85, 1.0)]
	for k in 48:
		var a := TAU * k / 48.0
		if absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.25 or absf(wrapf(a, -PI, PI)) < 0.2 or absf(wrapf(a - PI, -PI, PI)) < 0.2 \
				or absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.2:
			continue                                        # (gaps where the paths come in)
		var at := Vector3(cos(a), 0, sin(a)) * (LAWN_R + 0.6)
		_ball(f, 0.35, at + Vector3(0, 0.35, 0), _leaf(), 0.7)
		var m := _mat("Bed Flower %d" % (k % 4), petals[k % 4], 0.6, 0.2)
		_ball(f, 0.18, at + Vector3(0, 0.7, 0), m)
		if not m in _glows:
			_glows.append(m)


func _wren_model(body_m: Material, chest_m: Material) -> Node3D:
	# A little round wren: body, head, a cocked-up tail, a beak and a pink chest (our own bird, made of shapes)
	var w := Node3D.new()
	w.name = "Wren"
	_ball(w, 0.16, Vector3(0, 0.16, 0), body_m, 0.9)
	_ball(w, 0.11, Vector3(0, 0.3, 0.1), body_m)
	_ball(w, 0.1, Vector3(0, 0.15, 0.08), chest_m, 0.9)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.08, 0.2, 0.03)
	var tm := _mesh(w, tail, Vector3(0, 0.3, -0.16), body_m, false)
	tm.rotation.x = -0.6
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.03
	beak.height = 0.08
	var bm := _mesh(w, beak, Vector3(0, 0.3, 0.23), _mat("Beak", Color(1.0, 0.75, 0.3)), false)
	bm.rotation.x = PI / 2.0
	for side in [-1.0, 1.0]:
		_ball(w, 0.025, Vector3(side * 0.06, 0.33, 0.18), _mat("Wren Eye", Color(0.05, 0.05, 0.08)))
	return w


# -----------------------------------------------------------------------------
# The Hedge Maze
# -----------------------------------------------------------------------------
func _maze() -> void:
	var m := Node3D.new()
	m.name = "Hedge Maze"
	m.position = MAZE
	add_child(m)
	var n := MAZE_CELLS
	var size := n * MAZE_CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# A depth-first maze over the cells (every cell joined to every other by exactly one way)
	maze_open = []
	for i in n * n:
		maze_open.append([])
	var seen := {}
	var stack := [Vector2i(n - 1, n / 2)]
	seen[stack[0]] = true
	var dirs := {"n": Vector2i(0, 1), "s": Vector2i(0, -1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
	var back := {"n": "s", "s": "n", "e": "w", "w": "e"}
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var options := []
		for d in dirs:
			var nc: Vector2i = c + dirs[d]
			if nc.x >= 0 and nc.y >= 0 and nc.x < n and nc.y < n and not seen.has(nc):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: String = options[rng.randi() % options.size()]
		var nc: Vector2i = c + dirs[d]
		maze_open[c.y * n + c.x].append(d)
		maze_open[nc.y * n + nc.x].append(back[d])
		seen[nc] = true
		stack.append(nc)
	# The way in: the east side of the middle row, facing the fountain
	maze_open[(n / 2) * n + n - 1].append("e")
	# Hedges: each cell's south and west sides, plus the north and east edges of the whole maze
	var h := 2.8
	var t := 0.9
	var hedge := _hedge()
	var x0 := -size / 2.0
	var z0 := -size / 2.0
	for cy in n:
		for cx in n:
			var open: Array = maze_open[cy * n + cx]
			var cx0 := x0 + cx * MAZE_CELL
			var cz0 := z0 + cy * MAZE_CELL
			if not "s" in open:
				_box(m, "Hedge", Vector3(MAZE_CELL + t, h, t), Vector3(cx0 + MAZE_CELL / 2.0, h / 2.0, cz0), hedge)
			if not "w" in open:
				_box(m, "Hedge", Vector3(t, h, MAZE_CELL + t), Vector3(cx0, h / 2.0, cz0 + MAZE_CELL / 2.0), hedge)
			if cy == n - 1 and not "n" in open:
				_box(m, "Hedge", Vector3(MAZE_CELL + t, h, t), Vector3(cx0 + MAZE_CELL / 2.0, h / 2.0, cz0 + MAZE_CELL), hedge)
			if cx == n - 1 and not "e" in open:
				_box(m, "Hedge", Vector3(t, h, MAZE_CELL + t), Vector3(cx0 + MAZE_CELL, h / 2.0, cz0 + MAZE_CELL / 2.0), hedge)
	# Little round tops on the hedge corners, and a sundial at the heart
	for cy in n + 1:
		for cx in n + 1:
			_ball(m, 0.6, Vector3(x0 + cx * MAZE_CELL, h + 0.2, z0 + cy * MAZE_CELL), hedge, 0.8)
	var stone := _mat("Garden Stone", Color(0.78, 0.74, 0.8), 0.8)
	_cyl(m, "Sundial", 0.35, 0.45, 1.0, Vector3(0.9, 0.5, 0.9), stone, true)
	_cyl(m, "Sundial Face", 0.6, 0.6, 0.08, Vector3(0.9, 1.04, 0.9), _mat("Old Brass", Color(0.85, 0.68, 0.35), 0.3), false)
	_label(m, "THE MAZE", Vector3(size / 2.0 + 0.6, h + 0.9, 0), PI / 2.0, 48)


func maze_cell_at(local: Vector2) -> Vector2i:
	# Which cell (x, y) a point in the maze's own frame (x, z from its middle) is in
	var size := MAZE_CELLS * MAZE_CELL
	return Vector2i(floori((local.x + size / 2.0) / MAZE_CELL), floori((local.y + size / 2.0) / MAZE_CELL))


# -----------------------------------------------------------------------------
# The Lily Pond
# -----------------------------------------------------------------------------
func _pond() -> void:
	var p := Node3D.new()
	p.name = "Lily Pond"
	p.position = POND
	add_child(p)
	var water := CylinderMesh.new()
	water.top_radius = 1.0
	water.bottom_radius = 1.0
	water.height = 0.05
	water.radial_segments = 48
	var wm := _mesh(p, water, Vector3(0, POND_Y, 0), _mat("Pond Water", Color(0.35, 0.6, 0.75, 0.82), 0.05, 0.1), false)
	wm.name = "Pond Surface"
	wm.scale = Vector3(POND_R.x, 1, POND_R.y)
	var w := WATER.new()
	w.name = "Pond Water"
	w.ellipses = [Vector4(POND.x, POND.z, POND_R.x, POND_R.y)]
	w.water_y = POND_Y
	add_child(w)
	# Stones round its edge (only to look at: you wade straight in)
	var stone := _mat("Pond Stone", Color(0.66, 0.62, 0.7), 0.9)
	for k in 40:
		var a := TAU * k / 40.0
		_ball(p, _rng.randf_range(0.35, 0.6), Vector3(cos(a) * (POND_R.x + 0.4), 0.15, sin(a) * (POND_R.y + 0.4)), stone, 0.5)
	# The island: grass over the water, with a little round summerhouse (open sides, a domed roof)
	var isl := CylinderMesh.new()
	isl.top_radius = ISLAND_R
	isl.bottom_radius = ISLAND_R + 0.4
	isl.height = 0.12
	_mesh(p, isl, Vector3(0, POND_Y + 0.04, 0), _mat("Fine Lawn", Color(0.38, 0.68, 0.36), 0.9), false).name = "Island"
	var white := _mat("Summerhouse", Color(0.95, 0.92, 0.96), 0.5)
	for k in 6:
		var a := TAU * k / 6.0
		_cyl(p, "Summerhouse Post", 0.1, 0.1, 2.6, Vector3(cos(a) * 2.6, 1.3, sin(a) * 2.6), white, true)
	var dome := SphereMesh.new()
	dome.radius = 3.0
	dome.height = 3.0
	dome.is_hemisphere = true
	_mesh(p, dome, Vector3(0, 2.6, 0), _mat("Summerhouse Roof", Color(0.7, 0.85, 0.75), 0.5))
	# Lily pads and flowers on the water
	var pad := _mat("Lily Pad", Color(0.25, 0.6, 0.3), 0.6)
	var lily := _mat("Lily", Color(1.0, 0.75, 0.9), 0.5, 0.3)
	_glows.append(lily)
	for k in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(ISLAND_R + 1.2, 0.9)
		var at := Vector3(cos(a) * lerpf(ISLAND_R + 1.2, POND_R.x - 1.0, _rng.randf()), POND_Y + 0.03, sin(a) * lerpf(ISLAND_R + 1.2, POND_R.y - 1.0, _rng.randf()))
		var pm := CylinderMesh.new()
		pm.top_radius = _rng.randf_range(0.5, 0.9)
		pm.bottom_radius = pm.top_radius
		pm.height = 0.03
		_mesh(p, pm, at, pad, false)
		if k % 3 == 0:
			_ball(p, 0.18, at + Vector3(0, 0.12, 0), lily)
		r = r
	# Bulrushes at the back
	var rush := _mat("Bulrush", Color(0.45, 0.32, 0.25))
	for k in 18:
		var a := _rng.randf_range(-0.6, 0.6) + PI / 2.0
		var at := Vector3(cos(a) * (POND_R.x - 0.5) * _rng.randf_range(0.7, 1.0), 0, sin(a) * (POND_R.y - 0.5))
		_cyl(p, "Reed", 0.03, 0.03, 1.8, at + Vector3(0, 0.9, 0), _leaf(), false)
		_cyl(p, "Rush", 0.08, 0.08, 0.35, at + Vector3(0, 1.7, 0), rush, false)


# -----------------------------------------------------------------------------
# The Giant Flowers: a ring of flowers, each taller than the last, up to the top one in the middle
# -----------------------------------------------------------------------------
func _giant_flowers() -> void:
	var g := Node3D.new()
	g.name = "Giant Flowers"
	g.position = FLOWERS
	add_child(g)
	var stem := _mat("Giant Stem", Color(0.3, 0.62, 0.3), 0.7)
	var cols := [Color(1.0, 0.55, 0.75), Color(0.7, 0.55, 1.0), Color(1.0, 0.82, 0.35), Color(0.55, 0.85, 1.0),
		Color(1.0, 0.65, 0.45), Color(0.85, 0.55, 0.95), Color(0.6, 1.0, 0.7), Color(1.0, 0.5, 0.6)]
	flower_tops.clear()
	flower_radii.clear()
	var count := 8
	for k in count + 1:
		var top_y := 1.0 + k * 0.9                               # (each a hop up from the last: a jump's about 1.8 m)
		var at := Vector3.ZERO
		var r := 2.4
		if k < count:
			var a := -PI / 2.0 + k * (TAU / count) * 0.92        # round the ring, starting on the south side
			at = Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
			r = 2.0
		else:
			r = 3.6
		var head := Node3D.new()
		head.name = "Giant Flower %d" % (k + 1)
		head.position = at
		g.add_child(head)
		_cyl(head, "Stem", 0.35, 0.45, top_y, Vector3(0, top_y / 2.0, 0), stem, true)
		# The flower's face: a flat disc you can stand on, petals round it, a big middle
		var petal_m := _mat("Giant Petal %d" % (k % cols.size()), cols[k % cols.size()], 0.5, 0.15)
		_glows.append(petal_m)
		var disc := _cyl(head, "Flower Face", r, r * 0.7, 0.3, Vector3(0, top_y - 0.15, 0), petal_m, true)
		disc.name = "Flower Face"
		for p in 8:
			var pa := TAU * p / 8.0
			var pm := _ball(head, r * 0.45, Vector3(cos(pa) * r * 1.05, top_y - 0.1, sin(pa) * r * 1.05), petal_m, 0.35)
			pm.rotation.y = -pa
		_cyl(head, "Flower Middle", r * 0.45, r * 0.45, 0.12, Vector3(0, top_y + 0.06, 0), _mat("Flower Middle", Color(1.0, 0.85, 0.3), 0.6, 0.3), false)
		flower_tops.append(FLOWERS + at + Vector3(0, top_y, 0))
		flower_radii.append(r)
	_label(g, "THE GIANT FLOWERS", Vector3(0, 2.6, -10.0), PI, 48)


# -----------------------------------------------------------------------------
# The Great Tree and its swing
# -----------------------------------------------------------------------------
func _great_tree() -> void:
	var t := Node3D.new()
	t.name = "Great Tree"
	t.position = TREE
	add_child(t)
	var bark := _mat("Old Bark", Color(0.36, 0.26, 0.3), 0.95)
	_cyl(t, "Trunk", 1.6, 2.4, 12.0, Vector3(0, 6.0, 0), bark, true)
	var crown := _mat("Great Leaves", Color(0.28, 0.55, 0.32), 0.85)
	for k in 9:
		var a := TAU * k / 9.0
		_ball(t, _rng.randf_range(4.0, 5.5), Vector3(cos(a) * 5.0, 13.0 + _rng.randf_range(-1.0, 1.5), sin(a) * 5.0), crown, 0.8)
	_ball(t, 6.0, Vector3(0, 16.0, 0), crown, 0.8)
	# One big branch out east, with the swing hanging from it
	var branch := CylinderMesh.new()
	branch.top_radius = 0.4
	branch.bottom_radius = 0.7
	branch.height = 7.0
	var bm := _mesh(t, branch, Vector3(4.0, 8.5, 0), bark)
	bm.rotation.z = -PI / 2.0 + 0.15
	var swing := Node3D.new()
	swing.name = "Swing"
	swing.position = Vector3(5.5, 8.2, 0)
	t.add_child(swing)
	var rope := _mat("Rope", Color(0.8, 0.7, 0.5))
	for side in [-1.0, 1.0]:
		_cyl(swing, "Rope", 0.04, 0.04, 6.6, Vector3(0, -3.3, side * 0.6), rope, false)
	_box(swing, "Seat", Vector3(0.5, 0.1, 1.4), Vector3(0, -6.6, 0), _mat("Bench Wood", Color(0.55, 0.38, 0.32)), false)
	# Roots round the foot, and flowers in the shade
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var root := CylinderMesh.new()
		root.top_radius = 0.15
		root.bottom_radius = 0.5
		root.height = 3.0
		var rm := _mesh(t, root, Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6), bark)
		rm.rotation = Vector3(0, -a, PI / 2.0 - 0.15)


# -----------------------------------------------------------------------------
# Flowers and bushes all over, and petals in the air
# -----------------------------------------------------------------------------
func _scatter() -> void:
	var s := Node3D.new()
	s.name = "Flowerbeds"
	add_child(s)
	var cols := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 0.85, 1.0), Color(1.0, 1.0, 0.95)]
	var placed := 0
	var tries := 0
	while placed < 320 and tries < 4000:
		tries += 1
		var at := Vector3(_rng.randf_range(-WALL_X + 3, WALL_X - 3), 0, _rng.randf_range(WALL_Z.x + 4, WALL_Z.y - 3))
		if not _open_ground(at):
			continue
		placed += 1
		var c: Color = cols[placed % cols.size()]
		var m := _mat("Wild Flower %d" % (placed % cols.size()), c, 0.6, 0.15)
		if not m in _glows:
			_glows.append(m)
		var h := _rng.randf_range(0.3, 0.8)
		_cyl(s, "Flower Stalk", 0.025, 0.025, h, at + Vector3(0, h / 2.0, 0), _leaf(), false)
		_ball(s, _rng.randf_range(0.12, 0.22), at + Vector3(0, h, 0), m)
		if placed % 5 == 0:
			_ball(s, _rng.randf_range(0.6, 1.0), at + Vector3(0.8, 0.5, 0.3), _leaf(), 0.7)
	# Petals drifting down (moved in _process), many more once the garden's awake
	_petals = MultiMeshInstance3D.new()
	_petals.name = "Petals"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.1)
	mm.mesh = quad
	mm.instance_count = 160
	_petals.multimesh = mm
	var pm := _mat("Petal", Color(1.0, 0.72, 0.85), 0.5, 0.3)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_petals.material_override = pm
	_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_petals)
	for k in mm.instance_count:
		_petal_pos.append(Vector3(_rng.randf_range(-WALL_X, WALL_X), _rng.randf_range(0.0, 10.0), _rng.randf_range(WALL_Z.x, WALL_Z.y)))


func _open_ground(at: Vector3) -> bool:
	# Not on a path, the lawn, in the maze or the pond, by the flowers, the tree or the rose walk
	if absf(at.x) < 4.0 and at.z < 36.0:
		return false
	if Vector2(at.x - FOUNTAIN.x, at.z - FOUNTAIN.z).length() < LAWN_R + 2.0:
		return false
	var half := MAZE_CELLS * MAZE_CELL / 2.0 + 2.0
	if absf(at.x - MAZE.x) < half and absf(at.z - MAZE.z) < half:
		return false
	if pow((at.x - POND.x) / (POND_R.x + 1.5), 2) + pow((at.z - POND.z) / (POND_R.y + 1.5), 2) < 1.0:
		return false
	if Vector2(at.x - FLOWERS.x, at.z - FLOWERS.z).length() < 11.0 or Vector2(at.x - TREE.x, at.z - TREE.z).length() < 6.0:
		return false
	if absf(at.x) < 3.0 or absf(at.z - 52.0) < 3.0 or (absf(at.z - 108.0) < 2.5 and at.x < 0.0):
		return false
	return true


# -----------------------------------------------------------------------------
# The sleeping seeds
# -----------------------------------------------------------------------------
func seed_spot(id: String) -> Vector3:
	match id:
		"walk":
			return Vector3(-4.2, 0.0, 18.5)                          # in front of the alcove's bench
		"maze":
			return MAZE + Vector3(-0.6, 0.0, -0.6)                  # in the middle cell, beside the sundial
		"pond":
			return POND + Vector3(0.0, POND_Y + 0.1, 0.0)
		"flower":
			return flower_tops[flower_tops.size() - 1]
		"tree":
			return TREE + Vector3(0.0, 0.0, 3.6)                    # round the back of the trunk, away from the door
	return Vector3.ZERO


func _place_seeds() -> void:
	var holder := Node3D.new()
	holder.name = "Sleeping Seeds"
	add_child(holder)
	for s in SEEDS:
		var id: String = s.id
		var at := seed_spot(id)
		var n := Node3D.new()
		n.name = "Seed " + id
		n.position = at
		holder.add_child(n)
		var shell := _ball(n, 0.32, Vector3(0, 0.35, 0), _mat("Sleeping Seed", Color(0.75, 0.6, 0.45), 0.6, 0.2), 1.2)
		shell.name = "Shell"
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.5)
		glow.light_energy = 0.6
		glow.omni_range = 2.5
		glow.position = Vector3(0, 0.6, 0)
		n.add_child(glow)
		var bloom := _bloom_model()
		bloom.name = "Bloom"
		bloom.visible = false
		n.add_child(bloom)
		seeds[id] = {"node": n, "at": at}
		if Dialogue.flags.has("sg_seed_" + id):
			_show_bloom(n, false)


func _bloom_model() -> Node3D:
	var b := Node3D.new()
	_cyl(b, "Bloom Stem", 0.05, 0.06, 1.0, Vector3(0, 0.5, 0), _leaf(), false)
	var m := _mat("Wake Bloom", Color(1.0, 0.8, 0.95), 0.4, 1.2)
	for p in 6:
		var a := TAU * p / 6.0
		_ball(b, 0.22, Vector3(cos(a) * 0.25, 1.05, sin(a) * 0.25), m, 0.5)
	_ball(b, 0.14, Vector3(0, 1.08, 0), _mat("Wake Middle", Color(1.0, 0.95, 0.5), 0.4, 1.5))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.95)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.3, 0)
	b.add_child(l)
	return b


func _show_bloom(n: Node3D, fresh: bool) -> void:
	(n.get_node("Shell") as Node3D).visible = false
	var bloom := n.get_node("Bloom") as Node3D
	bloom.visible = true
	if fresh:
		bloom.scale = Vector3.ONE * 0.05
		var tw := bloom.create_tween()
		tw.tween_property(bloom, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func seeds_woken() -> int:
	var n := 0
	for s in SEEDS:
		if Dialogue.flags.has("sg_seed_" + str(s.id)):
			n += 1
	return n


func wake_seed(id: String) -> void:
	var flag := "sg_seed_" + id
	if Dialogue.flags.has(flag) or not seeds.has(id):
		return
	Dialogue.set_flag(flag)
	var n: Node3D = seeds[id].node
	_show_bloom(n, true)
	Fx.burst(self, n.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.8, 0.95), 18, 0.1, 3.0, -2.0)
	Juice.blip("chime", 1.0 + seeds_woken() * 0.1, -4.0)
	var where := ""
	for s in SEEDS:
		if s.id == id:
			where = s.where
	var left := SEEDS.size() - seeds_woken()
	if left > 0:
		Game.message("A sleeping seed %s wakes into a glowing flower! (%d still sleeping)" % [where, left])
	else:
		_wake_garden()


func _wake_garden() -> void:
	if Dialogue.flags.has("sg_awake"):
		return
	Dialogue.set_flag("sg_awake")
	awake = true
	Game.add_sparkles(WAKE_SPARKLES)
	Remnants.add(WAKE_REMNANTS)
	Game.message("The Secret Garden's awake! ✦ %d and %s." % [WAKE_SPARKLES, Remnants.words(WAKE_REMNANTS)])
	Juice.shake(0.2)
	var tw := create_tween()
	tw.tween_method(_set_awake, 0.0, 1.0, 3.0)


func _set_awake(k: float) -> void:
	# Asleep the garden's a little dim and dusty; awake, every flower glows and the sky's brighter
	for m in _glows:
		m.emission_energy_multiplier = lerpf(0.12, 0.7, k)
	if _env:
		_env.adjustment_saturation = lerpf(0.9, 1.35, k)
	if _sky:
		_sky.sky_top_color = Color(0.34, 0.3, 0.6).lerp(Color(0.36, 0.5, 0.85), k)
		_sky.sky_horizon_color = Color(0.96, 0.82, 0.72).lerp(Color(1.0, 0.85, 0.9), k)


# -----------------------------------------------------------------------------
# The way out
# -----------------------------------------------------------------------------
func _way_out() -> void:
	# The old door, open, just behind where you come in: step back through to go home
	var d := Node3D.new()
	d.name = "Old Door"
	d.position = Vector3(0, 0, WALL_Z.x)
	add_child(d)
	var wood := _mat("Door Wood", Color(0.45, 0.32, 0.4), 0.9)
	var door := _box(d, "Door Leaf", Vector3(0.12, 2.9, 2.3), Vector3(-1.15, 1.45, 1.1), wood, false)
	door.rotation.y = 0.0
	_box(d, "Doorway Dark", Vector3(2.4, 3.0, 0.1), Vector3(0, 1.5, -0.4), _mat("Doorway", Color(0.05, 0.05, 0.08)), false)
	_home_spot = USE_SPOT.make(Vector3(0, 0, 1.0), func() -> String: return "go back out through the old door",
		go_home, 2.0, 2.4)
	_home_spot.name = "Door Spot"
	d.add_child(_home_spot)


func go_home() -> void:
	Farm.get_node("SecretGarden").leave_garden()


# -----------------------------------------------------------------------------
# Every frame: the fountain, the petals, the seeds waking
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var spray := get_node_or_null("Fountain Lawn/Spray") as Node3D
	if spray:
		for k in spray.get_child_count():
			var b := spray.get_child(k) as Node3D
			b.position.y = 3.4 + fposmod(_t * 1.2 + k * 0.25, 2.5)
			b.position.x = sin(_t * 2.0 + k) * 0.1 * (b.position.y - 3.4)
	if _petals:
		var mm := _petals.multimesh
		var fall := 0.4 + (0.6 if awake else 0.0)
		var shown := mm.instance_count if awake else mm.instance_count / 3
		mm.visible_instance_count = shown
		for k in shown:
			var p := _petal_pos[k]
			p.y -= delta * fall
			p.x += sin(_t + k) * delta * 0.3
			if p.y < 0.05:
				p.y = 10.0
			_petal_pos[k] = p
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, _t + k).rotated(Vector3.RIGHT, _t * 0.7 + k), p))
	for id in seeds:
		var n: Node3D = seeds[id].node
		var shell := n.get_node("Shell") as Node3D
		if shell.visible:
			shell.position.y = 0.35 + sin(_t * 2.0 + n.position.x) * 0.06


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var p := _player.global_position
	for id in seeds:
		var at: Vector3 = seeds[id].at
		if Vector2(p.x - at.x, p.z - at.z).length() < SEED_REACH and absf(p.y - 0.9 - at.y) < 1.5:
			wake_seed(id)
