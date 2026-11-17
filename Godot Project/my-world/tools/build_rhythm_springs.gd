extends SceneTree

# Builds res://scenes/portal_worlds/rhythm_springs.tscn: Rhythm Springs, Melody's home world (plan item 19a world 4).
# A sunny summer valley of warm sandstone, cool spring pools, parasol palms and a big waterfall, where music used to
# play all day. The beat's broken, so time keeps speeding up and slowing down, and the summer sun is stuck at its
# hottest: out in the sun you heat up, and shade and cool water cool you down (Hayden, 9 Nov 2026: "add a summer
# element like fire or extreme heat to the challenge of the world"). Three Song Shells start the beat again:
#   Shell1  across the Sizzle Steps (west): stepping stones over a pit of hot coals. The stones flare with fire in
#           time with the broken beat, so you hop across between flares
#   Shell2  on top of Waterfall Mesa (east): climb the pads spiralling up it in the blazing sun (one has a parasol to
#           cool off under), then ride the water slide down into the Waterfall Pool
#   Shell3  on the Dance Floor (under its striped awning, by the way in): dance with Melody, jumping on her beat
# With all three, the Off-Beat (a stage-sized metronome stuck between tempos) wakes on the Bandstand (north).
# Logic: scripts/rhythm_springs.gd (on scripts/portal_world.gd) and scripts/off_beat.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_rhythm_springs.gd

const OUT := "res://scenes/portal_worlds/rhythm_springs.tscn"
const FLOOR_R := 48.0
const SIZZLE_FROM := Vector3(-12, 0, 4)      # the Sizzle Steps: a pit of coals from here...
const SIZZLE_TO := Vector3(-34, 0, -10)      # ...to here, with stepping stones across it
const SIZZLE_W := 7.0
const STONES := 9
const MESA := Vector3(30, 0, -16)            # Waterfall Mesa: pads spiral up it to the top
const MESA_R := 5.0
const MESA_TOP := 12.0
const PADS := 9
const PAD_START := 2.11                      # angle round the mesa of the first pad (the side facing the way in)
const PAD_STEP := -0.47
const FALLS := 3.36                          # angle round the mesa the waterfall pours down
const DANCE := Vector3(14, 0, 20)            # the Dance Floor, under a striped awning
const DANCE_R := 4.5
const STAGE := Vector3(0, 0, -34)            # the Bandstand, where the Off-Beat stands
const STAGE_R := 8.0
const STAGE_TOP := 0.8
const WATER_Y := 0.32                        # the cool pools are shallow: you wade in them
# The cool pools: centre x, centre z, radius x, radius z (scripts/water.gd ellipses)
const POOLS := [Vector4(0, 12, 5.5, 3.5), Vector4(21, -18, 4.5, 4.0), Vector4(-13, -22, 3.5, 3.0),
	Vector4(-30, 12, 3.5, 3.0)]
const HOT_SPRINGS := [Vector3(-38, 0, 22), Vector3(38, 0, 6), Vector3(-40, 0, -18)]
const PALMS := [Vector3(-6, 0, 22), Vector3(6, 0, 4), Vector3(-20, 0, 14), Vector3(-38, 0, -2), Vector3(-2, 0, -14),
	Vector3(-10, 0, -28), Vector3(11, 0, -28), Vector3(30, 0, 2), Vector3(-24, 0, -24), Vector3(26, 0, 26),
	Vector3(-28, 0, 30), Vector3(36, 0, -32)]

# The island round the valley (Hayden, 16 Nov 2026: "now we are going to work on melodies world", with a sensory map of
# two film islands and nine pictures: bamboo groves, sandstone cliffs with a waterfall to the sea, torch-lit paths, a
# boardwalk over the sea...). Our own island, laid out after that map: you land on a beach by a pier in the south, a
# torch path leads up into the valley, a ridge of stacked sandstone cliffs runs round the north with a waterfall
# pouring into a pool, cool lagoon coves sit along the shore, a bamboo grove with stone lanterns grows in the west,
# and a boardwalk overlooks the sea from the eastern headland.
#
# Hayden then (16 Nov 2026): "you shrunk the size of the map compared to the reference photos ... keep iterating until
# it looks exactly like the pictures", and "the current world is extremely flat ... the reference has cliffs and
# multiple elevation changes". So the island is half as big again and rises in terraces with sandstone cliffs
# (scripts/rhythm_land.gd: its height, its terraces and the ramps up them), and every place is built bigger, the way
# its picture shows it.
const LAND := preload("res://scripts/rhythm_land.gd")
const ISLAND_IN := 53.5                      # the island's ground starts just under the valley's sand floor
const SEA_Y := -0.35
const ARRIVE := Vector3(0, 0, 100)           # the way in: on the beach, at the foot of the pier and the torch path
const WAY_HOME := Vector3(-8, 0, 99)
const TIME_STONE := Vector3(-15, 0, 97)
const PIER_X := 8.0
const PIER_W := 3.2
const PIER_END := 158.0
const GATE := Vector3(0, 6, 70)              # the Springs Gate, on top of the Gate Terrace (6 m up)
const GATE_S := 1.6                          # how much bigger its arch is than the first one (its baked model too)
const FALLS_AT := 262.0                      # the big waterfall: off the North Highlands' upper tier, a stream across the
const SEA_FALLS_AT := 296.0                  # lower tier and down its cliff into the Falls Pool; and one into the sea
const GROVE_A := 190.0                       # the bamboo grove: a long straight path out along this angle on the West
const GROVE_FROM := 77.0                     # Terrace (7 m up), from this far out...
const GROVE_TO := 113.0                      # ...to this far
const GROVE := Vector3(-92.6, 7, -16.3)      # (its middle)
const GROVE_R := 18.0
const TERRACE_Y := 7.0                       # the West Terrace's height (the grove and the legend hut)
const OVERLOOK := Vector3(125.9, 12, 4.4)    # the boardwalk out over the sea from the East Headland (12 m up)
const LAGOON_AT := [30.0, 134.0]             # angles round the island (0 east, 90 south) of the lagoon coves
const PAVILION := Vector3(61.5, 6, 91.1)     # the thatched pavilion, on the Pavilion Bluff's sea edge (6 m up)
const PAV_R := 7.0
const PAV_DECK := 0.9                        # its deck stands up off the ground, with steps up the front
const HUTS := [Vector3(-74.5, 0, 43.0), Vector3(-86.2, 0, 34.8), Vector3(-83.4, 0, 20.8)]   # the stilt treehouses (west)
const HUT_DECK := 5.0                        # how high their decks are
const HUT_R := 4.3                           # their round decks
const CAVE := Vector3(45.3, 0, -45.3)        # the crystal cave, in a notch at the foot of the North Highlands
const CAVE_R := 10.0
const GROTTO := Vector3(16.0, 0, -59.9)      # the waterfall grotto, in another notch in the same cliff
const GROTTO_R := 8.0
const GLADE := Vector3(62.8, 0, 39.2)        # the flower glade (east), a ring of giant flowers round a clearing
const GLADE_R := 8.0
const LEGEND_HUT := Vector3(-71.0, 7, -41.0) # the legend hut, on the West Terrace by the grove
const TIDE_A := [68.0, 71.0, 74.0, 77.0, 80.0]  # angles round the island of the tide pools, out on the beach
const ISLET_A := 115.0                       # the angle round the island of the islet, out past the beach
const ISLET_R := 9.0                         # how big it is
const BAR_W := 2.6                           # the sandbar out to it
# Hayden (16 Nov 2026): "does it make sense geographically?" Water has to come from somewhere and go somewhere, so a
# spring at the foot of the old volcano's peak (scripts/rhythm_land.gd PEAKS) feeds the big waterfall, and the creek
# runs on from the Falls Pool round the valley's edge and out to the sea in the south-west, past the stilt huts,
# which stand in a mangrove marsh where it meets the sea (stilts are for wet ground). [angle, radius] along it.
const CREEK := [[259.0, 57.0], [252.0, 56.5], [244.0, 56.0], [236.0, 55.6], [228.0, 56.0], [220.0, 57.5],
	[211.0, 58.5], [202.0, 58.5], [194.0, 57.5], [186.0, 56.0], [179.0, 56.5], [172.0, 58.5], [166.0, 63.0],
	[163.0, 70.0], [161.5, 78.0], [161.0, 86.0], [161.5, 94.0], [162.0, 102.0], [162.5, 110.0], [163.0, 118.0]]
const CREEK_W := 2.4                         # how wide it is (it opens out to twice that at its mouth)
const CREEK_Y := 0.12                        # its water's height over the ground: shallow, you wade it
# The mangrove marsh round the stilt huts: centre x, centre z, radius x, radius z (scripts/water.gd ellipses)
const MARSH := [Vector4(-74.5, 43.0, 5.5, 5.5), Vector4(-86.2, 34.8, 6.0, 6.0), Vector4(-83.4, 20.8, 5.5, 5.5),
	Vector4(-88.5, 28.5, 5.5, 6.5), Vector4(-93.0, 38.0, 4.5, 4.0), Vector4(-91.0, 16.0, 4.5, 4.0)]


var all_pools: Array = []                    # the valley's pools, the lagoons and the falls pool
var ridge_rocks: Array = []                  # Vector4(x, z, radius, height) of every ridge rock
var paths: Array = []                        # [points, half width, torches?] of every path on the island
var pool_names: Array = []                   # what each of all_pools is called
var falls_r := 60.0                          # how far out the big waterfall comes down
var creek_pts: Array = []                    # the creek's middle line on the ground, from the Falls Pool to the sea
var spring_at := Vector3.ZERO                # the spring at the foot of the volcano's peak
var spring_to := Vector3.ZERO                # ...and where its stream goes over the upper tier's edge

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}


func _initialize() -> void:
	rng.seed = 41
	world = Node3D.new()
	world.name = "RhythmSprings"
	world.set_script(load("res://scripts/rhythm_springs.gd"))
	world.set("world_id", "rhythm_springs")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 36.0)
	_environment()
	_floor()
	_plan_island()
	_island()
	_ridge()
	_pools()
	_hot_springs()
	_sizzle_steps()
	_mesa()
	_slide()
	_dance_floor()
	_stage()
	for i in PALMS.size():
		_palm(PALMS[i], i)
	_torch_path()
	_gate()
	_pavilion()
	_stilt_huts()
	_creek()
	_marsh()
	_crystal_cave()
	_grotto()
	_pier()
	_bamboo_grove()
	_overlook()
	_flower_glade()
	_legend_hut()
	_tide_pools()
	_islet()
	_jungle()
	_flowers()
	_marker("Melody", Vector3(10.5, 0, 25.0)).rotation.y = atan2(DANCE.x - 10.5, DANCE.z - 25.0)
	_marker("TimeStone", TIME_STONE)
	_marker("WayHome", WAY_HOME).rotation.y = atan2(-WAY_HOME.x, -WAY_HOME.z)
	_marker("Vein1", Vector3(-22, 0, 24))
	_marker("PreviewCentre", Vector3(0, 3, -6))
	_marker("OffBeat", STAGE + Vector3(0, STAGE_TOP, -4.5))
	_marker("SunHigh", Vector3(10, 120, 20))
	var entrance := _marker("Entrance", ARRIVE + Vector3(0, 1.0, 0))
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = entrance.position
	world.add_child(player)
	_own(world)
	var scene := PackedScene.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	print("SAVED ", OUT, " pack=", scene.pack(world), " save=", ResourceSaver.save(scene, OUT))
	quit()


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = world
		if c.scene_file_path == "":
			_own(c)


func mat(name: String, color: Color, rough := 0.85, emit := 0.0, alpha := 1.0, metal := 0.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[name] = m
	return m


func mesh_at(mesh: Mesh, m: Material, pos: Vector3, parent: Node, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func solid(shape: Shape3D, pos: Vector3, parent: Node, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation = rot
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)
	return b


func cyl(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	top = snappedf(top, 0.05)
	bottom = snappedf(bottom, 0.05)
	# (At least 0.04: a thin disc snapped to no height at all has no faces to draw, so it never showed.)
	h = maxf(snappedf(h, 0.1), 0.04)
	var key := "c%s/%s/%s/%d" % [top, bottom, h, seg]
	if meshes.has(key):
		return meshes[key]
	var c := CylinderMesh.new()
	meshes[key] = c
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func ball(r: float, seg := 12) -> SphereMesh:
	r = snappedf(r, 0.05)
	var key := "b%s/%d" % [r, seg]
	if meshes.has(key):
		return meshes[key]
	var s := SphereMesh.new()
	meshes[key] = s
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	return s


func box(size: Vector3) -> BoxMesh:
	var key := "x%s" % size
	if meshes.has(key):
		return meshes[key]
	var b := BoxMesh.new()
	meshes[key] = b
	b.size = size
	return b


func cyl_solid(r: float, h: float, at: Vector3, parent: Node) -> StaticBody3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return solid(c, at, parent)


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


func _environment() -> void:
	# A blazing summer noon: a pale hot sky, a white-gold sun high overhead and a warm haze (scripts/rhythm_springs.gd
	# softens it to a golden evening once the beat's back)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.62, 0.95)
	sky_mat.sky_horizon_color = Color(1.0, 0.9, 0.7)
	sky_mat.ground_horizon_color = Color(1.0, 0.9, 0.7)
	sky_mat.ground_bottom_color = Color(0.85, 0.65, 0.45)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.88, 0.75)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.85, 0.65)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-72, 20, 0)
	world.add_child(sun)


func _floor() -> void:
	# Warm sand with paler patches, and paths of terracotta tiles from the way in to each place
	var g := Node3D.new()
	g.name = "Sands"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 6.0, FLOOR_R + 6.0, 1.0, 48), mat("Sand", Color(0.86, 0.66, 0.44), 0.95), Vector3(0, -0.5, 0), g)
	cyl_solid(FLOOR_R + 6.0, 1.0, Vector3(0, -0.5, 0), g)
	var pale := mat("Pale Sand", Color(0.92, 0.76, 0.54), 0.95)
	for k in 20:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 6.0)
		var r := rng.randf_range(1.5, 4.0)
		var p := Vector3(cos(a) * d, 0.02, sin(a) * d)
		if _blocked(p, r):
			continue
		mesh_at(cyl(r, r, 0.04, 16), pale, p, g)
	var tile := mat("Terracotta", Color(0.8, 0.42, 0.3), 0.8)
	var start := Vector3(0, 0, 30)
	for to in [SIZZLE_FROM + Vector3(2, 0, 3), DANCE + Vector3(-3, 0, 2), MESA + Vector3(-4, 0, 9), STAGE + Vector3(0, 0, STAGE_R + 1.0)]:
		var n := int(start.distance_to(to) / 1.3)
		for k in n:
			var p: Vector3 = start.lerp(to, (k + 0.5) / n)
			if _in_pool(p, 0.6):
				continue
			mesh_at(box(Vector3(0.9, 0.06, 0.9)), tile, p + Vector3(rng.randf_range(-0.2, 0.2), 0.03, rng.randf_range(-0.2, 0.2)), g,
				Vector3(0, rng.randf_range(-0.3, 0.3), 0))

static func shore_r(theta: float) -> float:
	# How far out the beach meets the sea at each angle round the island (θ = atan2(z, x)): scripts/rhythm_land.gd
	return LAND.shore_r(theta)


static func islet_at() -> Vector3:
	# The islet stands out in the sea, 20 m past the beach, at ISLET_A degrees round
	var a := deg_to_rad(ISLET_A)
	return Vector3(cos(a), 0, sin(a)) * (shore_r(a) + 20.0)


static func bar_from() -> Vector3:
	# The sandbar starts on dry ground, 7 m in from where the beach meets the sea, so it's flush with the ground
	var a := deg_to_rad(ISLET_A)
	var p := Vector3(cos(a), 0, sin(a)) * (shore_r(a) - 7.0)
	p.y = LAND.height(p.x, p.z)
	return p


static func gy(p: Vector3) -> float:
	# The ground's height under a spot (the valley's floor is 0)
	if Vector2(p.x, p.z).length() < LAND.VALLEY_R - 0.5:
		return 0.0
	return maxf(LAND.height(p.x, p.z), -0.02) if LAND.height(p.x, p.z) > -0.6 else LAND.height(p.x, p.z)


static func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, gy(p), p.z)


static func cliff_edge(deg: float, from_r: float, to_r: float, level: float) -> float:
	# How far out along an angle the ground first climbs to a level (the foot of a cliff, going outwards)
	var r := from_r
	while r < to_r:
		var p := LAND.at(deg, r)
		if LAND.land(p.x, p.z) > level:
			return r
		r += 0.1
	return to_r


func _r_of(p: Vector3) -> float:
	return Vector2(p.x, p.z).length()


func _inland(p: Vector3, room: float) -> bool:
	# Is this spot on dry ground, at least room metres in from the fence along the beach?
	return _r_of(p) < shore_r(atan2(p.z, p.x)) - 4.0 - room


func _flat(p: Vector3, room: float) -> bool:
	# Is the ground flat all round here (not a cliff or a ramp)?
	for o in [Vector2.ZERO, Vector2(room, 0), Vector2(-room, 0), Vector2(0, room), Vector2(0, -room)]:
		if LAND.slope(p.x + o.x, p.z + o.y) > 0.12:
			return false
	return not LAND.on_ramp(p.x, p.z, room + 1.0)


func _plan_island() -> void:
	_find_cross_up()
	# Works out the lagoons, the cave and grotto pools, the falls pool and the island's paths before anything's built,
	# so the planting can keep out of them all
	all_pools = POOLS.duplicate()
	pool_names = []
	for i in POOLS.size():
		pool_names.append("Pool%d" % (i + 1))
	for i in LAGOON_AT.size():
		var a := deg_to_rad(float(LAGOON_AT[i]))
		var r := shore_r(a) - 13.0
		all_pools.append(Vector4(cos(a) * r, sin(a) * r, 6.0, 4.5))
		pool_names.append("Lagoon %d" % (i + 1))
	var cave_in := Vector3(-CAVE.x, 0, -CAVE.z).normalized()
	all_pools.append(Vector4(CAVE.x - cave_in.x * 1.5, CAVE.z - cave_in.z * 1.5, 5.0, 4.0))
	pool_names.append("Crystal Pool")
	var grotto_in := Vector3(-GROTTO.x, 0, -GROTTO.z).normalized()
	all_pools.append(Vector4(GROTTO.x - grotto_in.x * 2.5, GROTTO.z - grotto_in.z * 2.5, 4.2, 3.4))
	pool_names.append("Grotto Pool")
	falls_r = cliff_edge(FALLS_AT, 58.0, 80.0, 9.5)
	var fp := LAND.at(FALLS_AT, falls_r - 6.5)
	all_pools.append(Vector4(fp.x, fp.z, 4.5, 3.5))
	pool_names.append("Falls Pool")
	creek_pts = []
	for q in CREEK:
		creek_pts.append(ground(LAND.at(q[0], q[1])))
	var pk: Array = LAND.PEAKS[0]
	var peak := LAND.at(pk[0], pk[1])
	spring_to = LAND.at(FALLS_AT, cliff_edge(FALLS_AT, 70.0, 100.0, 21.0) + 1.0, 22.0)
	spring_at = peak + Vector3(spring_to.x - peak.x, 0, spring_to.z - peak.z).normalized() * (float(pk[2]) * 1.17 + 1.5)
	spring_at.y = LAND.height(spring_at.x, spring_at.z)
	# The paths (each a line of points on the ground, its half width, and whether torches line it)
	var pv_in := Vector3(-PAVILION.x, 0, -PAVILION.z).normalized()
	paths = [
		[[ARRIVE + Vector3(0, 0, 4), Vector3(0, 0, 86), Vector3(0, 0, 73), Vector3(0, 0, 67), Vector3(0, 0, 55), Vector3(0, 0, 31)], 1.6, true],
		[[LAND.at(184, 50), LAND.at(184, 57), LAND.at(189, 75), LAND.at(GROVE_A, GROVE_FROM)], 1.3, true],
		[[LAND.at(GROVE_A, GROVE_FROM + 3.0), LAND.at(200, 80), LEGEND_HUT + (LAND.at(196, 80) - LEGEND_HUT).normalized() * 6.0], 1.1, false],
		[[LAND.at(-16, 50), LAND.at(-16, 70), LAND.at(-10, 84), LAND.at(-5, 96), OVERLOOK + Vector3(-9, 0, 0)], 1.3, true],
		[[LAND.at(46, 50), LAND.at(46, 72), LAND.at(50, 87), PAVILION + pv_in * (PAV_R + 4.0)], 1.3, true],
		[[LAND.at(236, 50), LAND.at(236, 57), LAND.at(240, 70), LAND.at(246, 82), LAND.at(270, 80), LAND.at(302, 76),
			LAND.at(298, 89), LAND.at(288, 100), LAND.at(270, 98)], 1.2, true],
	]


func _island() -> void:
	# The island's ground (scripts/rhythm_land.gd builds it when the world loads: the terraces, cliffs, ramps and
	# beach, solid), the sea all round, far islands on the horizon and an invisible fence along the beach and the
	# cliff tops so nobody wades or falls off
	var g := Node3D.new()
	g.name = "Island"
	world.add_child(g)
	var land := Node3D.new()
	land.name = "Island Land"
	land.set_script(LAND)
	g.add_child(land)
	# The sea: clear turquoise over the sand, darker further out
	var sea := PlaneMesh.new()
	sea.size = Vector2(1400, 1400)
	var water := mat("Sea", Color(0.08, 0.6, 0.72), 0.05, 0.05, 0.82)
	mesh_at(sea, water, Vector3(0, SEA_Y, 0), g).name = "Sea"
	_marker("SeaLevel", Vector3(0, SEA_Y, 0))
	# Far islands on the horizon, like the hazy ones in the pictures
	var far := [mat("Far Cliff", Color(0.86, 0.66, 0.52), 0.95), mat("Far Green", Color(0.5, 0.7, 0.5), 0.95)]
	for k in 7:
		var a := deg_to_rad(15.0 + k * 50.0 + rng.randf_range(-12.0, 12.0))
		var d := rng.randf_range(330.0, 470.0)
		var at := Vector3(cos(a) * d, SEA_Y, sin(a) * d)
		var w := rng.randf_range(30.0, 70.0)
		var h := rng.randf_range(14.0, 40.0)
		var isle := mesh_at(cyl(w * 0.55, w, h, 12), far[0], at + Vector3(0, h / 2.0 - 2.0, 0), g)
		isle.scale = Vector3(1.0, 1.0, rng.randf_range(0.4, 0.8))
		isle.rotation.y = rng.randf() * TAU
		isle.name = "Far Island"
		var top := mesh_at(cyl(w * 0.5, w * 0.56, 2.0, 12), far[1], Vector3(0, h / 2.0 + 0.8, 0), isle)
		top.name = "Far Island Top"
	# The fence along the beach and the cliff tops, with a gap where the pier goes out
	var fence := Node3D.new()
	fence.name = "WorldBounds Fence"           # ("WorldBounds": the map's picture covers everything inside it)
	g.add_child(fence)
	var fsegs := 260
	for i in fsegs:
		var a0 := i * TAU / fsegs
		var a1 := (i + 1) * TAU / fsegs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (shore_r(a0) - 3.0)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (shore_r(a1) - 3.0)
		var mid := (p0 + p1) / 2.0
		if mid.z > 0.0 and absf(mid.x - PIER_X) < PIER_W / 2.0 + 0.2:
			continue
		var bar_dir := Vector3(cos(deg_to_rad(ISLET_A)), 0, sin(deg_to_rad(ISLET_A)))
		if mid.dot(bar_dir) > 0.0 and (mid - bar_dir * mid.dot(bar_dir)).length() < p0.distance_to(p1) / 2.0 + BAR_W / 2.0:
			continue            # (the gap where the sandbar goes out to the islet: _islet() closes it up to the bar)
		var ov_dir := LAND.at(2.0, 1.0)
		if mid.dot(ov_dir) > 0.0 and (mid - ov_dir * mid.dot(ov_dir)).length() < p0.distance_to(p1) / 2.0 + 1.9:
			continue            # (the gap where the overlook's boardwalk goes out over the sea: its own rails close it)
		var top_y := maxf(maxf(gy(p0), gy(p1)), gy(mid))
		var b := BoxShape3D.new()
		b.size = Vector3(p0.distance_to(p1) + 0.5, 8.0 + top_y - minf(gy(p0), gy(p1)), 0.6)
		var d := p1 - p0
		solid(b, Vector3(mid.x, minf(gy(p0), gy(p1)) - 0.5 + b.size.y / 2.0, mid.z), fence,
			Vector3(0, -atan2(d.z, d.x), 0)).name = "Fence %d" % i
	# ...and two short pieces either side of the overlook's boardwalk, so the fence meets its rails
	var oa := deg_to_rad(2.0)
	var od := Vector3(cos(oa), 0, sin(oa))
	var ot := od.cross(Vector3.UP)
	for sx in [-1.0, 1.0]:
		var at: Vector3 = od * (shore_r(oa) - 3.0) + ot * sx * 4.4
		var ob := BoxShape3D.new()
		ob.size = Vector3(5.4, 10.0, 0.6)
		solid(ob, at + Vector3(0, gy(at) + 3.5, 0), fence, Vector3(0, -atan2(ot.z, ot.x), 0)).name = "Fence Overlook"


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, faces = null) -> void:
	# One triangle, turned so its front faces up (whichever way round Godot draws fronts: worked out once from a test)
	if a.is_equal_approx(b) or b.is_equal_approx(c) or a.is_equal_approx(c):
		return
	if ((b - a).cross(c - a).y > 0.0) != _cross_up:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.add_vertex(v)
		if faces != null:
			faces.append(v)


var _cross_up := true


func _find_cross_up() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)]:
		st.add_vertex(v)
	st.generate_normals()
	var n := (st.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
	# (0,0,1) x (1,0,0) points up, so if Godot's normal points up too, "cross up" is the front
	_cross_up = n.y > 0.0


func _sheet(g: Node3D, name: String, top: Vector3, bottom_y: float, out: Vector3, width: float) -> MeshInstance3D:
	# A sheet of falling water from top down to bottom_y, facing out
	var falls := mat("Falls", Color(0.6, 0.9, 1.0), 0.1, 0.5, 0.7)
	var h := top.y - bottom_y
	var s := mesh_at(box(Vector3(width, h, 0.25)), falls, Vector3(top.x, bottom_y + h / 2.0, top.z) + out * 0.3, g,
		Vector3(0, atan2(out.x, out.z), 0))
	s.name = name
	return s


func _foam(g: Node3D, at: Vector3, spread: float, n: int) -> void:
	var foam := mat("Foam", Color(1, 1, 1), 0.3, 0.4, 0.85)
	for k in n:
		var f := mesh_at(ball(0.6, 8), foam, at + Vector3(rng.randf_range(-spread, spread), 0.3, rng.randf_range(-spread, spread)), g)
		f.scale = Vector3(1.4, 0.5, 1.4)


func _ridge() -> void:
	# The North Highlands' dressing (the cliffs themselves are the ground: scripts/rhythm_land.gd): the big waterfall
	# off the upper tier, a stream across the lower tier and down its cliff into the Falls Pool, a waterfall off the
	# coast into the sea, sea stacks of banded sandstone, and trees all along the cliff tops like in the pictures
	var g := Node3D.new()
	g.name = "Ridge"
	world.add_child(g)
	var out := -LAND.at(FALLS_AT, 1.0)                        # (towards the valley)
	var upper_r := cliff_edge(FALLS_AT, 70.0, 100.0, 21.0)
	var stream := mat("Stream", Color(0.45, 0.85, 0.95), 0.1, 0.3, 0.85)
	_sheet(g, "Upper Falls", LAND.at(FALLS_AT, upper_r, 22.0), 10.0, out, 4.0)
	_foam(g, LAND.at(FALLS_AT, upper_r - 2.0, 10.0), 1.6, 6)
	var s0 := LAND.at(FALLS_AT, upper_r - 1.0, 10.08)
	var s1 := LAND.at(FALLS_AT, falls_r + 0.5, 10.08)
	var st := mesh_at(box(Vector3(3.2, 0.06, s0.distance_to(s1))), stream, (s0 + s1) / 2.0, g, Vector3(0, atan2(out.x, out.z), 0))
	st.name = "Highland Stream"
	# Where that water comes from: a spring bubbling up out of the rocks at the foot of the old volcano's peak, and its
	# stream across the upper tier to the falls' lip
	var sp := Node3D.new()
	sp.name = "Volcano Spring"
	sp.position = spring_at
	g.add_child(sp)
	var lava := [mat("Lava Rock", Color(0.42, 0.34, 0.36), 0.95), mat("Lava Rock Rust", Color(0.6, 0.42, 0.34), 0.95)]
	mesh_at(cyl(1.7, 1.7, 0.04, 20), stream, Vector3(0, 0.1, 0), sp).name = "Spring Water"
	for k in 10:
		var a := k * TAU / 10.0
		if absf(wrapf(a - atan2(spring_to.z - spring_at.z, spring_to.x - spring_at.x), -PI, PI)) < 0.5:
			continue                          # (the gap it spills out of)
		var rk := mesh_at(ball(rng.randf_range(0.45, 0.75), 7), lava[k % 2], Vector3(cos(a), 0, sin(a)) * 2.0 + Vector3(0, 0.2, 0), sp)
		rk.scale = Vector3(1.2, rng.randf_range(0.6, 1.0), 1.1)
	_foam(sp, Vector3(0, 0.05, 0), 0.6, 4)
	var sp0 := spring_at + Vector3(0, 0.08, 0)
	var sp1 := spring_to + Vector3(0, 0.08, 0)
	var sflat := Vector3(sp1.x - sp0.x, 0, sp1.z - sp0.z)
	var ss := mesh_at(box(Vector3(2.4, 0.06, sflat.length())), stream, (sp0 + sp1) / 2.0, g, Vector3(0, atan2(sflat.x, sflat.z), 0))
	ss.name = "Spring Stream"
	# The peak's crater: a little warm lake with steam drifting off it, so you can see from anywhere that the island
	# was a volcano (and why the valley has hot springs)
	var crater := LAND.peak_top()
	var cl := mesh_at(cyl(LAND.CRATER_R - 0.6, LAND.CRATER_R - 0.6, 0.04, 20), mat("Crater Lake", Color(0.3, 0.75, 0.7), 0.1, 0.3, 0.85),
		crater + Vector3(0, 0.6, 0), g)
	cl.name = "Crater Lake"
	var steam := mat("Steam", Color(1, 1, 1), 0.3, 0.25, 0.4)
	for k in 6:
		var m := mesh_at(ball(rng.randf_range(1.2, 2.2), 8), steam, crater + Vector3(rng.randf_range(-1.2, 1.2), 2.5 + k * 1.6,
			rng.randf_range(-1.2, 1.2)) + Vector3(0.5, 0, 0.3) * k, g)
		m.name = "Crater Steam"
	# The big one (scripts/big_falls.gd builds it big, with its own secret cove: "ridge_falls")
	var sheet := _sheet(g, "Waterfall", LAND.at(FALLS_AT, falls_r + 0.2, 10.0), 0.0, out, 3.4)
	sheet.set_meta("fall_id", "ridge_falls")
	_foam(g, LAND.at(FALLS_AT, falls_r - 2.0, 0.0), 1.4, 6)
	# Into the sea off the highlands' coast
	var sea_out := LAND.at(SEA_FALLS_AT, 1.0)
	var coast := cliff_edge(SEA_FALLS_AT, 60.0, 120.0, 9.5)
	var far_edge := coast
	while LAND.land(LAND.at(SEA_FALLS_AT, far_edge).x, LAND.at(SEA_FALLS_AT, far_edge).z) > 9.0 and far_edge < 140.0:
		far_edge += 0.2
	# (wide and white, with a brighter curtain down its middle and a cloud of spray at its foot, as in the picture, so
	# it shows from right across the bay)
	var top := LAND.at(SEA_FALLS_AT, far_edge - 0.4, 10.0)
	_sheet(g, "Sea Falls", top, SEA_Y, sea_out, 7.0)
	var white := mat("Falls White", Color(0.92, 0.98, 1.0), 0.1, 0.4, 0.8)
	for k in 3:
		var off := sea_out.cross(Vector3.UP).normalized() * (k - 1) * 2.0
		var c := mesh_at(box(Vector3(0.9, 10.0 - SEA_Y, 0.2)), white, Vector3(top.x, (10.0 + SEA_Y) / 2.0, top.z) + off + sea_out * 0.55,
			g, Vector3(0, atan2(sea_out.x, sea_out.z), 0))
		c.name = "Sea Falls Curtain"
	var lip := mesh_at(cyl(4.4, 4.0, 0.5, 10), mat("Stream", Color(0.45, 0.85, 0.95), 0.1, 0.3, 0.85), LAND.at(SEA_FALLS_AT, far_edge - 3.0, 10.1), g)
	lip.scale = Vector3(1, 1, 0.6)
	lip.rotation.y = atan2(sea_out.x, sea_out.z)
	_foam(g, LAND.at(SEA_FALLS_AT, far_edge + 2.5, SEA_Y), 4.0, 18)
	var mist := mat("Mist", Color(1, 1, 1), 0.3, 0.2, 0.45)
	for k in 8:
		var m := mesh_at(ball(rng.randf_range(1.4, 2.4), 8), mist, LAND.at(SEA_FALLS_AT, far_edge + rng.randf_range(1.0, 5.0), SEA_Y + rng.randf_range(0.6, 2.6))
			+ sea_out.cross(Vector3.UP).normalized() * rng.randf_range(-4.0, 4.0), g)
		m.name = "Sea Falls Mist"
	var rocks := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var cap := mat("Cliff Green", Color(0.38, 0.66, 0.32), 0.9)
	# Sea stacks: banded towers of sandstone standing in the sea off the cliffs
	for k in 9:
		var deg := rng.randf_range(225.0, 345.0)
		var a := deg_to_rad(deg)
		var r := shore_r(a) + rng.randf_range(6.0, 20.0)
		var at := Vector3(cos(a) * r, LAND.height(cos(a) * r, sin(a) * r), sin(a) * r)
		var rad := rng.randf_range(2.5, 5.0)
		var h := rng.randf_range(8.0, 20.0) - at.y
		var holder := Node3D.new()
		holder.name = "Sea Stack %d" % (k + 1)
		holder.position = at
		g.add_child(holder)
		var tiers := 4
		for t in tiers:
			var th := h / tiers
			var r0 := rad * (1.0 - t * 0.09)
			var sm := mesh_at(cyl(r0 * 0.94, r0, th, 9), rocks[(k + t) % 3], Vector3(0, th * (t + 0.5), 0), holder)
			sm.rotation.y = rng.randf() * TAU
			if t > 0:
				mesh_at(cyl(r0 * 1.04, r0 * 1.04, 0.3, 9), rocks[(k + t + 1) % 3], Vector3(0, th * t, 0), holder)
		mesh_at(cyl(rad * 0.65, rad * 0.65 + 0.2, 0.6, 9), cap, Vector3(0, h + 0.2, 0), holder)
		ridge_rocks.append(Vector4(at.x, at.z, rad, h))
	# Ledges of rock along the cliff faces: stacked slabs jutting out at each band, so the cliffs look layered
	var ledge := 0
	var tries := 0
	while ledge < 140 and tries < 6000:
		tries += 1
		var p := Vector3(rng.randf_range(-140, 140), 0, rng.randf_range(-140, 140))
		if _r_of(p) < LAND.VALLEY_R + 2.0 or LAND.on_ramp(p.x, p.z, 3.0):
			continue
		var sl := LAND.slope(p.x, p.z)
		var h := LAND.height(p.x, p.z)
		if sl < 2.5 or h < 1.0 or LAND.peak_rise(p.x, p.z) > 0.0:
			continue                          # (not on the volcano's peak: its rock isn't layered sandstone)
		var down := Vector3(LAND.height(p.x + 0.5, p.z) - LAND.height(p.x - 0.5, p.z), 0,
			LAND.height(p.x, p.z + 0.5) - LAND.height(p.x, p.z - 0.5)).normalized() * -1.0
		var y := snappedf(h, 1.6) - 0.3
		if y < 0.6:
			continue
		var slab := mesh_at(box(Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(0.5, 1.1), rng.randf_range(1.2, 2.0))),
			rocks[ledge % 3], Vector3(p.x, y, p.z) + down * 0.4, g, Vector3(0, atan2(down.x, down.z), 0))
		slab.name = "Cliff Ledge"
		ledge += 1
	# Round green trees all along the tops of the cliffs
	var leaves := [mat("Tree Leaf", Color(0.35, 0.65, 0.3), 0.85), mat("Tree Leaf Light", Color(0.48, 0.75, 0.35), 0.85)]
	var bark := mat("Palm Bark", Color(0.7, 0.5, 0.35), 0.9)
	var trees := 0
	tries = 0
	while trees < 70 and tries < 6000:
		tries += 1
		var p := Vector3(rng.randf_range(-140, 140), 0, rng.randf_range(-140, 140))
		var h := LAND.height(p.x, p.z)
		if h < 4.0 or not _inland(p, 1.0) or not _flat(p, 1.5) or _blocked(p, 1.0):
			continue
		trees += 1
		var t := Node3D.new()
		t.name = "Cliff Tree"
		t.position = Vector3(p.x, h, p.z)
		g.add_child(t)
		var th := rng.randf_range(2.5, 4.5)
		mesh_at(cyl(0.18, 0.28, th, 7), bark, Vector3(0, th / 2.0, 0), t)
		cyl_solid(0.3, th, Vector3(0, th / 2.0, 0), t)
		for k in rng.randi_range(3, 5):
			var lf := mesh_at(ball(rng.randf_range(1.3, 2.1), 9), leaves[k % 2], Vector3(rng.randf_range(-1.2, 1.2),
				th + rng.randf_range(0.2, 1.4), rng.randf_range(-1.2, 1.2)), t)
			lf.scale = Vector3(1.2, 0.85, 1.2)
		ridge_rocks.append(Vector4(p.x, p.z, 1.6, h + th))


func _pools() -> void:
	# The cool spring pools: shallow, clear and blue, ringed with smooth pebbles. Wading in one cools you right down
	# (scripts/rhythm_springs.gd); the water itself is scripts/water.gd, so you splash and slow down in it.
	var g := Node3D.new()
	g.name = "Cool Pools"
	g.set_script(load("res://scripts/water.gd"))
	var outline: Array[Vector4] = []
	for p in all_pools:
		outline.append(p)
	g.set("ellipses", outline)
	g.set("water_y", WATER_Y)
	world.add_child(g)
	var water := mat("Cool Water", Color(0.35, 0.8, 0.95), 0.1, 0.25, 0.8)
	var bed := mat("Pool Bed", Color(0.55, 0.85, 0.9), 0.6)
	var pebble := mat("Pebble", Color(0.92, 0.88, 0.8), 0.8)
	var lagoon_bed := mat("Lagoon Bed", Color(0.45, 0.88, 0.85), 0.6)
	var lagoon_water := mat("Lagoon Water", Color(0.25, 0.85, 0.85), 0.1, 0.3, 0.75)
	var lagoon_rock := mat("Lagoon Rock", Color(0.78, 0.66, 0.52), 0.9)
	for i in all_pools.size():
		var e: Vector4 = all_pools[i]
		var holder := Node3D.new()
		var lagoon := i >= POOLS.size()
		# The valley's springs are Pool1..4; out on the island the lagoon coves by the beach, and the pool the ridge's
		# waterfall drops into (last)
		holder.name = pool_names[i]
		holder.position = Vector3(e.x, 0, e.y)
		g.add_child(holder)
		var bm := mesh_at(cyl(1.0, 1.0, 0.04, 32), lagoon_bed if lagoon else bed, Vector3(0, 0.03, 0), holder)
		bm.scale = Vector3(e.z, 1, e.w)
		var wm := mesh_at(cyl(1.0, 1.0, 0.04, 32), lagoon_water if lagoon else water, Vector3(0, WATER_Y, 0), holder)
		wm.scale = Vector3(e.z, 1, e.w)
		wm.name = "Surface"
		var n := int((e.z + e.w) * 2.2)
		for k in n:
			var a := k * TAU / n
			if lagoon:
				# Big smooth boulders round a lagoon cove, with a gap or two to walk in
				if k % 5 == 2:
					continue
				var rk := mesh_at(ball(rng.randf_range(0.5, 0.85), 8), lagoon_rock, Vector3(cos(a) * (e.z + 0.5), 0.2,
					sin(a) * (e.w + 0.5)), holder)
				rk.scale = Vector3(1.3, rng.randf_range(0.6, 1.0), 1.1)
				continue
			var pb := mesh_at(ball(0.3, 8), pebble, Vector3(cos(a) * (e.z + 0.2), 0.12, sin(a) * (e.w + 0.2)), holder)
			pb.scale = Vector3(1.2, 0.6, 1.0)
		var m := _marker("Cool%d" % (i + 1), Vector3(e.x, 0, e.y))
		m.set_meta("radius", minf(e.z, e.w))


func _hot_springs() -> void:
	# Steaming hot springs in rings of red rock. The broken beat's turned them up to boiling: step in and you're out
	# again in a hurry (scripts/rhythm_springs.gd). Once the beat's back they're just right for a soak.
	var g := Node3D.new()
	g.name = "Hot Springs"
	world.add_child(g)
	var hot := mat("Hot Water", Color(1.0, 0.55, 0.45), 0.1, 0.6, 0.85)
	var rim := mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9)
	for i in HOT_SPRINGS.size():
		var at: Vector3 = HOT_SPRINGS[i]
		var holder := Node3D.new()
		holder.name = "Hot Spring %d" % (i + 1)
		holder.position = at
		g.add_child(holder)
		var surface := mesh_at(cyl(3.0, 3.0, 0.05, 28), hot, Vector3(0, 0.3, 0), holder)
		surface.name = "Surface"
		for k in 14:
			var a := k * TAU / 14.0
			var r := mesh_at(ball(0.55, 8), rim, Vector3(cos(a) * 3.3, 0.25, sin(a) * 3.3), holder)
			r.scale = Vector3(1.3, 0.8, 1.0)
		var m := _marker("Hot%d" % (i + 1), at)
		m.set_meta("radius", 3.0)


func _sizzle_steps() -> void:
	# A long pit of glowing coals in a sandstone border, with stepping stones across it. scripts/rhythm_springs.gd
	# makes the stones flare in time with the beat.
	var g := Node3D.new()
	g.name = "Sizzle Steps"
	world.add_child(g)
	var dir := (SIZZLE_TO - SIZZLE_FROM).normalized()
	var length := SIZZLE_FROM.distance_to(SIZZLE_TO)
	var yaw := atan2(dir.x, dir.z)
	var mid := (SIZZLE_FROM + SIZZLE_TO) / 2.0
	var coals := mat("Hot Coals", Color(1.0, 0.35, 0.12), 0.9, 1.4)
	var ash := mat("Coal Crust", Color(0.35, 0.16, 0.12), 0.95)
	var border := mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9)
	mesh_at(box(Vector3(SIZZLE_W, 0.05, length - 2.0)), coals, mid + Vector3(0, 0.03, 0), g, Vector3(0, yaw, 0))
	for k in 40:
		var along := rng.randf_range(-length / 2.0 + 1.5, length / 2.0 - 1.5)
		var side := rng.randf_range(-SIZZLE_W / 2.0 + 0.4, SIZZLE_W / 2.0 - 0.4)
		var p := mid + dir * along + dir.cross(Vector3.UP) * side
		var c := mesh_at(ball(0.3, 6), ash, p + Vector3(0, 0.05, 0), g)
		c.scale = Vector3(rng.randf_range(0.8, 1.6), 0.3, rng.randf_range(0.8, 1.4))
	for s in [-1.0, 1.0]:
		var edge: Vector3 = mid + dir.cross(Vector3.UP) * (SIZZLE_W / 2.0 + 0.3) * s
		mesh_at(box(Vector3(0.6, 0.5, length - 2.0)), border, edge + Vector3(0, 0.25, 0), g, Vector3(0, yaw, 0))
		var b := BoxShape3D.new()
		b.size = Vector3(0.6, 0.5, length - 2.0)
		solid(b, edge + Vector3(0, 0.25, 0), g, Vector3(0, yaw, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.25)
	light.light_energy = 1.5
	light.omni_range = 14.0
	light.position = mid + Vector3(0, 2.0, 0)
	g.add_child(light)
	# The stepping stones (markers: scripts/rhythm_springs.gd adds the stones themselves, so it can light them up)
	for i in STONES:
		var t := (i + 1) * length / (STONES + 1)
		var wobble := dir.cross(Vector3.UP) * (0.9 if i % 2 == 0 else -0.9)
		_marker("Stone%d" % (i + 1), SIZZLE_FROM + dir * t + wobble)
	var start := _marker("SizzleStart", SIZZLE_FROM + dir * 0.2)          # (just off the coals, which start 1 m in)
	start.set_meta("yaw", yaw)
	var end_at := SIZZLE_TO + dir * 2.5
	mesh_at(cyl(2.2, 2.4, 0.3, 20), border, end_at + Vector3(0, 0.15, 0), g)
	cyl_solid(2.2, 0.3, end_at + Vector3(0, 0.15, 0), g)
	_marker("Shell1", end_at + Vector3(0, 0.3, 0))
	var pit := _marker("SizzlePit", mid)
	pit.set_meta("yaw", yaw)
	pit.set_meta("length", length - 2.0)
	pit.set_meta("width", SIZZLE_W)


func _pad_at(i: int) -> Vector3:
	var a := PAD_START + i * PAD_STEP
	return MESA + Vector3(cos(a) * (MESA_R + 1.0), (i + 1) * MESA_TOP / (PADS + 1), sin(a) * (MESA_R + 1.0))


func _mesa() -> void:
	# Waterfall Mesa: a tall round tower of striped sandstone with flat sandy pads spiralling up its side, a waterfall
	# pouring off its west face into a cool pool, and a flat top with the second Song Shell
	var g := Node3D.new()
	g.name = "Waterfall Mesa"
	world.add_child(g)
	var stripes := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var bands := 6
	for k in bands:
		var h := MESA_TOP / bands
		var r0 := MESA_R + 0.4 - k * 0.06
		mesh_at(cyl(r0 - 0.06, r0, h, 20), stripes[k % 3], MESA + Vector3(0, h * (k + 0.5), 0), g)
	cyl_solid(MESA_R, MESA_TOP, MESA + Vector3(0, MESA_TOP / 2.0, 0), g)
	mesh_at(cyl(MESA_R + 0.1, MESA_R + 0.1, 0.1, 20), mat("Pale Sand", Color(0.92, 0.76, 0.54), 0.95), MESA + Vector3(0, MESA_TOP + 0.03, 0), g)
	var pad := mat("Pad Stone", Color(0.9, 0.7, 0.5), 0.85)
	for i in PADS:
		var p := _pad_at(i)
		mesh_at(cyl(1.3, 1.15, 0.35, 14), pad, p, g)
		cyl_solid(1.3, 0.35, p, g)
	# A parasol on the middle pad: somewhere to cool off on the way up
	var mid_pad := _pad_at(PADS / 2)
	_parasol(g, mid_pad + Vector3(0, 0.17, 0), 1.6, 2.2, 4)
	var shade := _marker("Shade Mesa", mid_pad + Vector3(0, 0.17, 0))
	shade.set_meta("radius", 1.6)
	shade.set_meta("height", 2.2)
	# The top: a little shell shrine, and the water slide's start at the falls' edge
	_marker("Shell2", MESA + Vector3(1.2, MESA_TOP + 0.1, 1.2))
	var edge := Vector3(cos(FALLS), 0, sin(FALLS))
	_marker("SlideTop", MESA + edge * (MESA_R - 1.4) + Vector3(0, MESA_TOP + 0.1, 0))
	# The waterfall: a sheet of falling water down the west face, with foam where it lands
	var falls := mat("Falls", Color(0.6, 0.9, 1.0), 0.1, 0.5, 0.7)
	var sheet := mesh_at(box(Vector3(2.4, MESA_TOP, 0.25)), falls, MESA + edge * (MESA_R + 0.15) + Vector3(0, MESA_TOP / 2.0, 0), g,
		Vector3(0, atan2(edge.x, edge.z), 0))
	sheet.name = "Waterfall"
	var foam := mat("Foam", Color(1, 1, 1), 0.3, 0.4, 0.85)
	for k in 6:
		var f := mesh_at(ball(0.5, 8), foam, MESA + edge * (MESA_R + 0.8) + Vector3(rng.randf_range(-1.0, 1.0), 0.35, rng.randf_range(-1.0, 1.0)), g)
		f.scale = Vector3(1.3, 0.5, 1.3)


func _slide() -> void:
	# The water slide: a blue trough winding down from the top of the mesa, round past the Bandstand side and into the
	# Waterfall Pool. scripts/rhythm_springs.gd rides you down it along the Slide path.
	var edge := Vector3(cos(FALLS), 0, sin(FALLS))
	var top := MESA + edge * (MESA_R - 0.4) + Vector3(0, MESA_TOP + 0.5, 0)
	var pts := [top, MESA + edge * (MESA_R + 2.5) + Vector3(-1, MESA_TOP - 1.0, -4), Vector3(18, 9.5, -27), Vector3(10, 7.5, -24),
		Vector3(8, 5.5, -14), Vector3(13, 3.6, -8), Vector3(20, 2.0, -9), Vector3(23, 1.0, -14), Vector3(21, 0.6, -17)]
	var curve := Curve3D.new()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tin := Vector3.ZERO
		var tout := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			var t: Vector3 = (pts[i + 1] - pts[i - 1]) * 0.25
			tin = -t
			tout = t
		curve.add_point(p, tin, tout)
	curve.bake_interval = 0.25
	var path := Path3D.new()
	path.name = "Slide"
	path.curve = curve
	world.add_child(path)
	var g := Node3D.new()
	g.name = "Water Slide"
	world.add_child(g)
	var trough := mat("Slide", Color(0.3, 0.6, 1.0), 0.3)
	var water := mat("Slide Water", Color(0.6, 0.92, 1.0), 0.1, 0.5, 0.75)
	var post := mat("Slide Post", Color(1.0, 0.95, 0.9), 0.6)
	var length := curve.get_baked_length()
	var step := 1.0
	var d := 0.0
	var k := 0
	while d < length:
		var a := curve.sample_baked(d)
		var b := curve.sample_baked(minf(d + step, length))
		var mid := (a + b) / 2.0
		var seg := mesh_at(box(Vector3(1.6, 0.25, step + 0.12)), trough, mid, g)
		seg.look_at_from_position(mid, b if b.distance_to(a) > 0.01 else a + Vector3.FORWARD, Vector3.UP)
		var w := mesh_at(box(Vector3(1.2, 0.05, step + 0.12)), water, Vector3.ZERO, g)
		w.transform = seg.transform
		w.position += Vector3(0, 0.15, 0)
		for s in [-1.0, 1.0]:
			var lip := mesh_at(box(Vector3(0.15, 0.4, step + 0.12)), trough, Vector3.ZERO, g)
			lip.transform = seg.transform
			lip.position += seg.transform.basis.x * 0.8 * s + Vector3(0, 0.2, 0)
		if k % 4 == 0 and mid.y > 1.0:
			var h := mid.y - 0.15
			mesh_at(cyl(0.12, 0.15, h, 6), post, Vector3(mid.x, h / 2.0, mid.z), g)
		d += step
		k += 1


func _dance_floor() -> void:
	# The Dance Floor: a round floor of coloured tiles in rings, under a big striped awning on four poles (shade!)
	var g := Node3D.new()
	g.name = "Dance Floor"
	world.add_child(g)
	g.position = DANCE
	var base := mat("Floor Base", Color(0.95, 0.92, 0.88), 0.6)
	mesh_at(cyl(DANCE_R, DANCE_R + 0.2, 0.2, 32), base, Vector3(0, 0.1, 0), g)
	cyl_solid(DANCE_R, 0.2, Vector3(0, 0.1, 0), g)
	# (scripts/rhythm_springs.gd lights the tiles in time with Melody's beat: they're markers' children it makes)
	_marker("DanceFloor", DANCE + Vector3(0, 0.2, 0)).set_meta("radius", DANCE_R)
	var stripe := [mat("Awning Pink", Color(1.0, 0.55, 0.75), 0.7), mat("Awning Cream", Color(1.0, 0.95, 0.85), 0.7)]
	var pole := mat("Pole", Color(1.0, 0.95, 0.9), 0.5)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var p := Vector3(cos(a), 0, sin(a)) * (DANCE_R + 0.4)
		mesh_at(cyl(0.12, 0.14, 4.6, 8), pole, p + Vector3(0, 2.3, 0), g)
		cyl_solid(0.14, 4.6, p + Vector3(0, 2.3, 0), g)
	for k in 12:
		var a := k * TAU / 12.0
		var piece := mesh_at(cyl(0.0, DANCE_R + 1.2, 1.4, 3), stripe[k % 2], Vector3(0, 5.0, 0), g)
		piece.rotation.y = a
		piece.scale = Vector3(1, 1, 0.55)
	var shade := _marker("Shade Dance", DANCE)
	shade.set_meta("radius", DANCE_R + 1.0)
	shade.set_meta("height", 4.5)


func _stage() -> void:
	# The Bandstand: a round stage with a scalloped roof at the back (not over the middle: the Off-Beat's too tall),
	# speakers either side and four drum pads round the front. scripts/off_beat.gd lights the drums.
	var g := Node3D.new()
	g.name = "Bandstand"
	world.add_child(g)
	g.position = STAGE
	var wood := mat("Stage Wood", Color(0.62, 0.36, 0.26), 0.8)
	var trim := mat("Stage Gold", Color(1.0, 0.8, 0.4), 0.4, 0.3, 1.0, 0.6)
	mesh_at(cyl(STAGE_R, STAGE_R + 0.4, STAGE_TOP, 40), wood, Vector3(0, STAGE_TOP / 2.0, 0), g)
	cyl_solid(STAGE_R + 0.2, STAGE_TOP, Vector3(0, STAGE_TOP / 2.0, 0), g)
	var rim := TorusMesh.new()
	rim.inner_radius = STAGE_R - 0.25
	rim.outer_radius = STAGE_R + 0.1
	rim.rings = 48
	mesh_at(rim, trim, Vector3(0, STAGE_TOP, 0), g)
	# The shell-shaped back wall: ribs fanning up behind the Off-Beat
	var shell := [mat("Shell Pink", Color(1.0, 0.7, 0.75), 0.7), mat("Shell Cream", Color(1.0, 0.93, 0.85), 0.7)]
	for k in 9:
		var a := lerpf(-1.2, 1.2, k / 8.0)
		var rib := mesh_at(box(Vector3(1.4, 9.0, 0.3)), shell[k % 2], Vector3(sin(a) * 6.0, STAGE_TOP + 4.0, -7.0 + (1.0 - cos(a)) * 3.0), g)
		rib.rotation = Vector3(0.25, -a, 0)
	for s in [-1.0, 1.0]:
		var spk := mesh_at(box(Vector3(1.4, 2.6, 1.2)), mat("Speaker", Color(0.2, 0.15, 0.25), 0.6), Vector3(s * 7.0, STAGE_TOP + 1.3, -3.0), g)
		spk.rotation.y = s * 0.5
		var b := BoxShape3D.new()
		b.size = Vector3(1.4, 2.6, 1.2)
		solid(b, Vector3(s * 7.0, STAGE_TOP + 1.3, -3.0), g, Vector3(0, s * 0.5, 0))
		for c in 2:
			var cone := mesh_at(cyl(0.4 - c * 0.15, 0.4 - c * 0.15, 0.05, 16), mat("Speaker Cone", Color(0.5, 0.45, 0.55), 0.5),
				Vector3(s * 7.0, STAGE_TOP + 1.9 - c * 1.0, -3.0) + Vector3(sin(s * 0.5), 0, cos(s * 0.5)) * 0.62, g)
			cone.rotation = Vector3(PI / 2.0, s * 0.5, 0)
	for i in 4:
		var at := [Vector3(-5.0, 0, 0.5), Vector3(5.0, 0, 0.5), Vector3(-2.6, 0, 4.4), Vector3(2.6, 0, 4.4)][i] as Vector3
		_marker("Drum%d" % (i + 1), STAGE + at + Vector3(0, STAGE_TOP, 0))
	# Steps up the front
	for k in 2:
		var stp := mesh_at(box(Vector3(4.0, 0.3, 0.8)), wood, Vector3(0, 0.15 + k * 0.3, STAGE_R + 0.9 - k * 0.7), g)
		var b := BoxShape3D.new()
		b.size = Vector3(4.0, 0.3 * (k + 1), 0.8)
		solid(b, Vector3(0, 0.15 * (k + 1), STAGE_R + 0.9 - k * 0.7), g)
		stp.name = "Step"


func _parasol(parent: Node3D, at: Vector3, r: float, h: float, k: int) -> void:
	var colours := [Color(1.0, 0.55, 0.65), Color(0.4, 0.8, 0.95), Color(1.0, 0.85, 0.4), Color(0.7, 0.6, 1.0)]
	var pole := mat("Pole", Color(1.0, 0.95, 0.9), 0.5)
	mesh_at(cyl(0.05, 0.06, h, 6), pole, at + Vector3(0, h / 2.0, 0), parent)
	var c: Color = colours[k % colours.size()]
	var top := mesh_at(cyl(0.05, r, 0.5, 12), mat("Parasol %d" % (k % colours.size()), c, 0.7), at + Vector3(0, h, 0), parent)
	top.name = "Parasol"

func _palm(at: Vector3, k: int) -> void:
	# A palm, tall and leaning like the ones in the pictures: a curvy striped trunk with a wide crown of big leaves that
	# throws a good pool of shade (scripts/detail_props.gd swaps it for the baked palm, sized from its coconut)
	var g := Node3D.new()
	g.name = "Parasol Palm %d" % (k + 1)
	g.position = at
	world.add_child(g)
	var bark := [mat("Palm Bark", Color(0.7, 0.5, 0.35), 0.9), mat("Palm Bark Light", Color(0.85, 0.65, 0.45), 0.9)]
	var leaf := [mat("Palm Leaf", Color(0.35, 0.75, 0.45), 0.8), mat("Palm Leaf Light", Color(0.5, 0.85, 0.45), 0.8)]
	var h := rng.randf_range(6.0, 8.5)
	var lean := Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
	var segs := 7
	for s in segs:
		var t := (s + 0.5) / segs
		mesh_at(cyl(0.24, 0.3, h / segs + 0.05, 8), bark[s % 2], lean * t * t + Vector3(0, h * t, 0), g)
	cyl_solid(0.32, h, Vector3(0, h / 2.0, 0), g)
	var top := lean + Vector3(0, h, 0)
	for l in 9:
		var a := l * TAU / 9.0 + rng.randf() * 0.2
		var lf := mesh_at(ball(1.0, 8), leaf[l % 2], top + Vector3(cos(a), -0.2, sin(a)) * 1.9, g)
		lf.scale = Vector3(2.4, 0.12, 0.8)
		lf.rotation = Vector3(0, -a, -0.25)
	mesh_at(ball(0.38, 8), mat("Coconut", Color(0.45, 0.3, 0.2), 0.9), top + Vector3(0, -0.3, 0), g)
	var shade := _marker("Shade Palm %d" % (k + 1), at + lean)
	shade.set_meta("radius", 3.4)
	shade.set_meta("height", h)
func _flowers() -> void:
	# Bright summer flowers in clumps (no collision)
	var g := Node3D.new()
	g.name = "Summer Flowers"
	world.add_child(g)
	var stem := mat("Flower Stem", Color(0.3, 0.6, 0.3), 0.9)
	var petals := [mat("Petal Pink", Color(1.0, 0.5, 0.7), 0.6, 0.2), mat("Petal Orange", Color(1.0, 0.6, 0.25), 0.6, 0.2),
		mat("Petal Yellow", Color(1.0, 0.9, 0.3), 0.6, 0.2), mat("Petal Blue", Color(0.4, 0.7, 1.0), 0.6, 0.2)]
	for c in 34:
		var a := rng.randf() * TAU
		var d := rng.randf_range(5.0, FLOOR_R - 4.0)
		var centre := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(centre, 0.5):
			continue
		for k in 5:
			var p := centre + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
			mesh_at(cyl(0.05, 0.05, 0.45, 4), stem, p + Vector3(0, 0.22, 0), g)
			mesh_at(ball(0.09, 6), petals[(c + k) % 4], p + Vector3(0, 0.47, 0), g)

func _torch_path() -> void:
	# Terracotta paths out across the island, lined with tiki torches like the concept's torch-lit path: from the beach
	# up the cutting to the gate and down into the valley, up to the bamboo grove, the legend hut, the overlook, the
	# pavilion and both tiers of the North Highlands. Tiles follow the ground, tilted on the ramps.
	var g := Node3D.new()
	g.name = "Torch Paths"
	world.add_child(g)
	var tile := [mat("Terracotta", Color(0.8, 0.42, 0.3), 0.8), mat("Terracotta Pale", Color(0.86, 0.55, 0.38), 0.8)]
	var post := mat("Torch Post", Color(0.45, 0.3, 0.2), 0.9)
	var bind := mat("Torch Binding", Color(0.85, 0.7, 0.45), 0.9)
	var flame := mat("Torch Flame", Color(1.0, 0.6, 0.2), 0.5, 3.0)
	var lit := 0
	for pi in paths.size():
		var path: Array = paths[pi]
		var pts: Array = path[0]
		var half: float = path[1]
		var torches: bool = path[2]
		var along := 0.0
		for si in pts.size() - 1:
			var from: Vector3 = ground(pts[si])
			var to: Vector3 = ground(pts[si + 1])
			var flat := Vector3(to.x - from.x, 0, to.z - from.z)
			var seg := flat.length()
			if seg < 0.1:
				continue
			var dir := flat / seg
			var side := dir.cross(Vector3.UP)
			var n := int(seg / 0.95)
			for k in n:
				var p: Vector3 = from.lerp(to, (k + 0.5) / n)
				if _in_pool(p, 0.6):
					continue
				var cols := [-0.5, 0.5] if half > 1.4 else ([0.0] if half < 1.2 else [-0.3, 0.3])
				for w in cols:
					var q: Vector3 = p + side * float(w) * half * 1.3
					var y0 := gy(q - dir * 0.45)
					var y1 := gy(q + dir * 0.45)
					var t := mesh_at(box(Vector3(0.95, 0.08, 0.95)), tile[(k + int(w * 4)) % 2], Vector3(q.x, (y0 + y1) / 2.0 + 0.03, q.z), g)
					t.basis = Basis.looking_at(Vector3(dir.x, (y1 - y0) / 0.9, dir.z).normalized(), Vector3.UP) * \
						Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
			if not torches:
				along += seg
				continue
			# Torches: both sides of the way in from the beach every 6 m, one side or the other every 8 m elsewhere
			var step := 6.0 if pi == 0 else 8.0
			var d := fposmod(-along, step)
			while d < seg:
				var p: Vector3 = from.lerp(to, d / seg)
				var sides := [-1.0, 1.0] if pi == 0 else [1.0 if int((along + d) / step) % 2 == 0 else -1.0]
				for sx in sides:
					var tp: Vector3 = p + side * float(sx) * (half + 0.4)
					tp.y = gy(tp)
					if _in_pool(tp, 0.3) or _r_of(tp) < LAND.VALLEY_R - 2.0:
						continue
					var t := Node3D.new()
					t.name = "Torch"
					t.position = tp
					g.add_child(t)
					mesh_at(cyl(0.07, 0.09, 1.9, 6), post, Vector3(0, 0.95, 0), t)
					mesh_at(cyl(0.16, 0.1, 0.3, 8), bind, Vector3(0, 1.95, 0), t)
					var f := mesh_at(ball(0.16, 8), flame, Vector3(0, 2.2, 0), t)
					f.scale = Vector3(1, 1.6, 1)
					f.name = "Flame"
					if lit < 10 and pi == 0 and int(d) % 12 < 6:
						var l := OmniLight3D.new()
						l.light_color = Color(1.0, 0.6, 0.3)
						l.light_energy = 0.8
						l.omni_range = 7.0
						l.position = Vector3(0, 2.3, 0)
						t.add_child(l)
						lit += 1
				d += step
			along += seg
	_path_fences()
	_path_rocks()


func _path_fences() -> void:
	# Post-and-rail fences along both sides of the way up from the beach, like the picture's torch path (solid, so the
	# way up's edges are kept)
	var g := Node3D.new()
	g.name = "Path Fences"
	world.add_child(g)
	var wood := mat("Fence Wood", Color(0.55, 0.38, 0.25), 0.9)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 2.25
		var z := 98.0
		var last := Vector3(x, gy(Vector3(x, 0, z)), z)
		while z > 74.5:
			z -= 2.2
			var p := Vector3(x, gy(Vector3(x, 0, z)), z)
			mesh_at(cyl(0.07, 0.08, 1.2, 6), wood, p + Vector3(0, 0.6, 0), g)
			for ry in [0.55, 1.0]:
				var rail := mesh_at(box(Vector3(0.07, 0.07, last.distance_to(p))), wood, (last + p) / 2.0 + Vector3(0, float(ry), 0), g)
				rail.basis = Basis.looking_at(p - last, Vector3.UP)
			var wall := BoxShape3D.new()
			wall.size = Vector3(0.2, 2.2, last.distance_to(p))
			solid(wall, (last + p) / 2.0 + Vector3(0, 1.0, 0), g).basis = Basis.looking_at(p - last, Vector3.UP)
			last = p


func _path_rocks() -> void:
	# Stacks of banded sandstone on both sides of where the path leaves the beach, so it climbs between rock walls
	var g := Node3D.new()
	g.name = "Path Rocks"
	world.add_child(g)
	var rocks := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var cap := mat("Cliff Green", Color(0.38, 0.66, 0.32), 0.9)
	var k := 0
	for sx in [-1.0, 1.0]:
		for z in [87.0, 91.0, 95.0]:
			var at := Vector3(sx * rng.randf_range(4.6, 6.2), 0, z + rng.randf_range(-0.8, 0.8))
			at.y = gy(at) - 0.2
			var rad := rng.randf_range(1.6, 2.2)
			var h := rng.randf_range(4.0, 7.5) * (1.3 if z < 90.0 else 1.0)
			var holder := Node3D.new()
			holder.name = "Path Rock %d" % (k + 1)
			holder.position = at
			g.add_child(holder)
			for t in 3:
				var th := h / 3.0
				var r0 := rad * (1.0 - t * 0.12)
				var m := mesh_at(cyl(r0 * 0.92, r0, th, 7), rocks[(k + t) % 3], Vector3(0, th * (t + 0.5), 0), holder)
				m.rotation.y = rng.randf() * TAU
			mesh_at(cyl(rad * 0.6, rad * 0.65, 0.5, 7), cap, Vector3(0, h + 0.2, 0), holder)
			cyl_solid(rad, h, Vector3(0, h / 2.0, 0), holder)
			ridge_rocks.append(Vector4(at.x, at.z, rad, h))
			k += 1


func _gate() -> void:
	# The Springs Gate on top of the Gate Terrace, looking down into the valley, like the concept's temple gate: two
	# stacked sandstone pillars, a lintel with a glowing sun and a row of gold "notes", purple banners with gold
	# crescents; and either side of it a high wall running out to square towers with plants on top. The gate's own
	# pieces sit in "Gate Core", scaled up (scripts/detail_props.gd swaps them for the baked gate, which scales with it).
	var g := Node3D.new()
	g.name = "Springs Gate"
	g.position = GATE
	world.add_child(g)
	var core := Node3D.new()
	core.name = "Gate Core"
	core.scale = Vector3.ONE * GATE_S
	g.add_child(core)
	var stone := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var band := mat("Gate Teal", Color(0.2, 0.62, 0.65), 0.7)
	var gold := mat("Banner Gold", Color(1.0, 0.8, 0.35), 0.4, 0.3, 1.0, 0.5)
	var cloth := mat("Banner Purple", Color(0.42, 0.22, 0.6), 0.8)
	var sun := mat("Gate Sun", Color(1.0, 0.75, 0.3), 0.4, 1.2)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 3.2
		for k in 4:
			mesh_at(box(Vector3(1.3 - k * 0.08, 1.4, 1.3 - k * 0.08)), stone[k % 2], Vector3(x, 0.7 + k * 1.4, 0), core)
			mesh_at(box(Vector3(1.45 - k * 0.08, 0.15, 1.45 - k * 0.08)), band, Vector3(x, 1.4 + k * 1.4, 0), core)
		var b := BoxShape3D.new()
		b.size = Vector3(1.3, 5.6, 1.3) * GATE_S
		solid(b, Vector3(x, 2.8, 0) * GATE_S, g)
		for face in [1.0, -1.0]:
			mesh_at(box(Vector3(0.9, 2.2, 0.05)), cloth, Vector3(x, 3.4, 0.7 * face), core).name = "Banner"
			var moon := TorusMesh.new()
			moon.inner_radius = 0.22
			moon.outer_radius = 0.32
			mesh_at(moon, gold, Vector3(x, 3.6, 0.74 * face), core, Vector3(PI / 2.0, 0, 0))
			mesh_at(cyl(0.24, 0.24, 0.04, 14), cloth, Vector3(x + 0.11, 3.66, 0.77 * face), core, Vector3(PI / 2.0, 0, 0))
	mesh_at(box(Vector3(8.4, 0.9, 1.6)), stone[0], Vector3(0, 6.05, 0), core)
	mesh_at(box(Vector3(9.0, 0.25, 1.8)), band, Vector3(0, 6.6, 0), core)
	mesh_at(box(Vector3(5.0, 0.6, 1.2)), stone[1], Vector3(0, 7.0, 0), core)
	for face in [1.0, -1.0]:
		mesh_at(cyl(0.55, 0.55, 0.06, 18), sun, Vector3(0, 7.05, 0.62 * face), core, Vector3(PI / 2.0, 0, 0))
		for k in 9:
			mesh_at(ball(0.17, 8), gold, Vector3(-3.2 + k * 0.8, 6.05, 0.82 * face), core)
	var top := BoxShape3D.new()
	top.size = Vector3(8.4, 1.2, 1.6) * GATE_S
	solid(top, Vector3(0, 6.2, 0) * GATE_S, g)
	# The walls and towers either side
	var walls := Node3D.new()
	walls.name = "Gate Walls"
	g.add_child(walls)
	var leaf := mat("Jungle Leaf", Color(0.3, 0.62, 0.32), 0.8)
	var inner := 3.2 * GATE_S + 1.3 * GATE_S / 2.0
	for sx in [-1.0, 1.0]:
		var x0: float = sx * inner
		var x1: float = sx * 15.0
		var mid := (x0 + x1) / 2.0
		var wl := absf(x1 - x0)
		for row in 5:
			var wb := mesh_at(box(Vector3(wl, 1.2, 1.4)), stone[row % 2], Vector3(mid, 0.6 + row * 1.2, 0), walls)
			wb.name = "Gate Wall"
		mesh_at(box(Vector3(wl + 0.2, 0.25, 1.7)), band, Vector3(mid, 6.1, 0), walls)
		var ws := BoxShape3D.new()
		ws.size = Vector3(wl, 7.0, 1.4)
		solid(ws, Vector3(mid, 3.5, 0), walls)
		# A tower at the end, its own little roof garden on top
		var tx: float = sx * 17.0
		for row in 7:
			mesh_at(box(Vector3(3.8 - (row % 2) * 0.2, 1.6, 3.8 - (row % 2) * 0.2)), stone[(row + 1) % 2],
				Vector3(tx, 0.8 + row * 1.6, 0), walls).name = "Gate Tower"
		mesh_at(box(Vector3(4.3, 0.4, 4.3)), band, Vector3(tx, 11.4, 0), walls)
		for k in 4:
			var lf := mesh_at(ball(1.0, 8), leaf, Vector3(tx + rng.randf_range(-1.0, 1.0), 12.0, rng.randf_range(-1.0, 1.0)), walls)
			lf.scale = Vector3(1.1, 0.6, 1.1)
		var ts := BoxShape3D.new()
		ts.size = Vector3(3.8, 11.6, 3.8)
		solid(ts, Vector3(tx, 5.8, 0), walls)
		ridge_rocks.append(Vector4(GATE.x + tx, GATE.z, 3.0, 12.0))
		# A big purple banner with a gold crescent on each wall, both faces
		for face in [1.0, -1.0]:
			var bx: float = sx * 9.5
			mesh_at(box(Vector3(1.8, 4.2, 0.06)), cloth, Vector3(bx, 3.6, 0.74 * face), walls).name = "Banner"
			var moon := TorusMesh.new()
			moon.inner_radius = 0.38
			moon.outer_radius = 0.56
			mesh_at(moon, gold, Vector3(bx, 4.4, 0.78 * face), walls, Vector3(PI / 2.0, 0, 0))
			mesh_at(cyl(0.42, 0.42, 0.04, 14), cloth, Vector3(bx + 0.19, 4.5, 0.82 * face), walls, Vector3(PI / 2.0, 0, 0))


func _thatch(parent: Node3D, at: Vector3, r: float, h: float, layers := 3) -> void:
	# A conical thatched roof: layers of straw-coloured cones, each a little wider and lower, with a knob on top
	var straw := [mat("Thatch", Color(0.82, 0.66, 0.38), 0.95), mat("Thatch Dark", Color(0.7, 0.54, 0.3), 0.95)]
	for k in layers:
		var rr := r * (1.0 - k * 0.22)
		var piece := mesh_at(cyl(0.05, rr, h / layers * 1.4, 16), straw[k % 2], at + Vector3(0, h / layers * (k + 0.7), 0), parent)
		piece.name = "Thatch Roof"
	mesh_at(ball(0.25, 8), straw[1], at + Vector3(0, h + 0.2, 0), parent)


func _rail_ring(g: Node3D, r: float, y: float, gaps: Array, gap_w: float) -> void:
	# A rail round a round deck at height y (posts, a rope and unseen walls), with gaps (angles, radians) to come in
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var rope := mat("Rope", Color(0.85, 0.75, 0.55), 0.9)
	var n := 24
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		var am := (a0 + a1) / 2.0
		var skip := false
		for ga in gaps:
			if absf(wrapf(am - float(ga), -PI, PI)) < gap_w / r:
				skip = true
		if skip:
			continue
		var p0 := Vector3(cos(a0), 0, sin(a0)) * r + Vector3(0, y, 0)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * r + Vector3(0, y, 0)
		mesh_at(cyl(0.06, 0.07, 1.0, 6), post, p0 + Vector3(0, 0.5, 0), g)
		var rl := mesh_at(cyl(0.035, 0.035, p0.distance_to(p1), 5), rope, (p0 + p1) / 2.0 + Vector3(0, 0.95, 0), g)
		rl.basis = Basis.looking_at(p1 - p0, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		var w := BoxShape3D.new()
		w.size = Vector3(0.2, 2.4, p0.distance_to(p1) + 0.1)
		solid(w, (p0 + p1) / 2.0 + Vector3(0, 1.2, 0), g).basis = Basis.looking_at(p1 - p0, Vector3.UP)


func _pavilion() -> void:
	# The pavilion on the Pavilion Bluff's sea edge, like the picture: a round deck raised off the ground with steps up
	# the front (a gentle ramp under them, as you can't step up a ledge on foot), a rail round it, eight posts with
	# curtains tied back, lanterns hanging, cushions round a low table and a big two-layered thatched roof
	var g := Node3D.new()
	g.name = "Pavilion"
	g.position = PAVILION
	var inward := Vector3(-PAVILION.x, 0, -PAVILION.z).normalized()
	g.rotation.y = atan2(inward.x, inward.z)                # its +z faces back inland, where the steps are
	world.add_child(g)
	var wood := [mat("Boardwalk", Color(0.7, 0.5, 0.33), 0.85), mat("Boardwalk Dark", Color(0.58, 0.42, 0.28), 0.85)]
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var curtain := [mat("Curtain Cream", Color(1.0, 0.95, 0.85), 0.8), mat("Curtain Coral", Color(1.0, 0.6, 0.5), 0.8)]
	var glow := mat("Lantern Glow", Color(1.0, 0.82, 0.5), 0.5, 2.0)
	var r := PAV_R
	var d := PAV_DECK
	mesh_at(cyl(r, r + 0.15, d, 32), wood[1], Vector3(0, d / 2.0, 0), g)
	mesh_at(cyl(r + 0.1, r + 0.1, 0.1, 32), wood[0], Vector3(0, d - 0.03, 0), g)
	cyl_solid(r, d, Vector3(0, d / 2.0, 0), g)
	# The steps up the front: drawn steps over a ramp
	var run := 4.6
	for k in 5:
		var sy := d * (k + 1) / 5.0
		mesh_at(box(Vector3(2.8, sy, run / 5.0 + 0.02)), wood[k % 2], Vector3(0, sy / 2.0, r + run - (k + 0.5) * run / 5.0 - 0.2), g)
	var ramp := BoxShape3D.new()
	ramp.size = Vector3(2.8, 0.2, sqrt(run * run + d * d))
	var rb := solid(ramp, Vector3(0, d / 2.0 - 0.1, r + run / 2.0 - 0.2), g)
	rb.rotation.x = atan2(d, run)
	rb.name = "Pavilion Steps"
	_rail_ring(g, r - 0.15, d, [PI / 2.0], 1.6)
	for k in 8:
		var a := k * TAU / 8.0 + TAU / 16.0
		var p := Vector3(cos(a), 0, sin(a)) * (r - 0.5) + Vector3(0, d, 0)
		mesh_at(cyl(0.17, 0.2, 4.6, 8), post, p + Vector3(0, 2.3, 0), g)
		cyl_solid(0.2, 4.6, p + Vector3(0, 2.3, 0), g)
		var c := mesh_at(cyl(0.25, 0.5, 3.9, 8), curtain[k % 2], p + Vector3(0, 2.4, 0) - Vector3(cos(a), 0, sin(a)) * 0.2, g)
		c.scale = Vector3(1, 1, 0.45)
		c.rotation.y = -a
		c.name = "Curtain"
		var a2 := a + TAU / 16.0
		var swag := mesh_at(ball(1.0, 10), curtain[k % 2], Vector3(cos(a2), 0, sin(a2)) * (r - 0.6) + Vector3(0, d + 4.35, 0), g)
		swag.scale = Vector3(0.12, 0.4, 2.4)
		swag.rotation.y = -a2
		var ln := mesh_at(cyl(0.18, 0.22, 0.45, 8), glow, Vector3(cos(a2), 0, sin(a2)) * (r - 1.2) + Vector3(0, d + 3.6, 0), g)
		ln.name = "Pavilion Lantern"
	mesh_at(cyl(r + 0.2, r + 0.2, 0.3, 32), wood[1], Vector3(0, d + 4.7, 0), g)
	_thatch(g, Vector3(0, d + 4.7, 0), r + 2.2, 4.5)
	mesh_at(cyl(1.3, 1.3, 0.1, 18), wood[0], Vector3(0, d + 0.55, 0), g)
	mesh_at(cyl(0.2, 0.25, 0.5, 8), post, Vector3(0, d + 0.25, 0), g)
	for k in 8:
		var a := k * TAU / 8.0
		var cu := mesh_at(ball(0.5, 8), curtain[(k + 1) % 2], Vector3(cos(a), 0, sin(a)) * 2.5 + Vector3(0, d + 0.2, 0), g)
		cu.scale = Vector3(1.3, 0.4, 1.3)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.55)
	l.light_energy = 0.9
	l.omni_range = 10.0
	l.position = Vector3(0, d + 3.2, 0)
	g.add_child(l)
	var shade := _marker("Shade Pavilion", PAVILION + Vector3(0, d, 0))
	shade.set_meta("radius", r)
	shade.set_meta("height", 4.5)
	_marker("PavilionTop", PAVILION + Vector3(0, d + 0.05, 0))


func _hut_ramp_mid() -> Vector3:
	return HUTS[0] + (Vector3(-HUTS[0].x, 0, -HUTS[0].z).normalized() * (HUT_R + 7.0))


func _plank_walk(g: Node3D, from: Vector3, to: Vector3, w: float, walls := true) -> void:
	# A walk of planks from one point to another (they may be at different heights), solid, with rope rails and
	# unseen walls along both sides so nobody falls off
	var plank := [mat("Pier Plank", Color(0.66, 0.48, 0.32), 0.85), mat("Pier Plank Dark", Color(0.56, 0.4, 0.27), 0.85)]
	var rope := mat("Rope", Color(0.85, 0.75, 0.55), 0.9)
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var length := from.distance_to(to)
	var dir := (to - from) / length
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var side := flat.cross(Vector3.UP)
	var basis := Basis.looking_at(dir, Vector3.UP)
	var n := int(length / 0.5)
	for k in n:
		var p := from.lerp(to, (k + 0.5) / n)
		var pl := mesh_at(box(Vector3(w, 0.1, 0.42)), plank[k % 2], p - Vector3(0, 0.05, 0), g)
		pl.basis = basis
	var deck := BoxShape3D.new()
	deck.size = Vector3(w, 0.2, length)
	var body := solid(deck, (from + to) / 2.0 - basis.y * 0.1, g)
	body.basis = basis
	for sx in [-1.0, 1.0]:
		var a: Vector3 = from + side * sx * (w / 2.0)
		var b: Vector3 = to + side * sx * (w / 2.0)
		var rail := mesh_at(cyl(0.035, 0.035, length, 6), rope, (a + b) / 2.0 + Vector3(0, 0.95, 0), g)
		rail.basis = basis * Basis(Vector3.RIGHT, PI / 2.0)
		for k in int(length / 2.5) + 1:
			var pp := a.lerp(b, float(k) / maxf(1.0, float(int(length / 2.5))))
			mesh_at(cyl(0.06, 0.06, 1.0, 6), post, pp + Vector3(0, 0.5, 0), g)
		if walls:
			var wall := BoxShape3D.new()
			wall.size = Vector3(0.2, 2.4, length)
			var wb := solid(wall, (a + b) / 2.0 + side * sx * 0.1 + Vector3(0, 1.1, 0), g)
			wb.basis = basis


func _stilt_huts() -> void:
	# Three round treehouses high on stilts in the west, like the picture: round railed decks, round thatched huts
	# with a doorway, rope bridges between them and a ramp up to the first. Under them is shade.
	var g := Node3D.new()
	g.name = "Stilt Huts"
	world.add_child(g)
	var wood := mat("Hut Wood", Color(0.62, 0.44, 0.3), 0.85)
	var wall := mat("Hut Wall", Color(0.85, 0.7, 0.48), 0.9)
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var hammock := mat("Curtain Coral", Color(1.0, 0.6, 0.5), 0.8)
	var glow := mat("Lantern Glow", Color(1.0, 0.82, 0.5), 0.5, 2.0)
	for i in HUTS.size():
		var at: Vector3 = HUTS[i]
		at.y = 0.0
		var h := Node3D.new()
		h.name = "Stilt Hut %d" % (i + 1)
		h.position = at
		g.add_child(h)
		mesh_at(cyl(HUT_R, HUT_R, 0.3, 28), wood, Vector3(0, HUT_DECK - 0.15, 0), h)
		cyl_solid(HUT_R, 0.3, Vector3(0, HUT_DECK - 0.15, 0), h)
		for k in 6:
			var a := k * TAU / 6.0 + 0.3
			var p := Vector3(cos(a), 0, sin(a)) * (HUT_R - 0.4)
			var foot := gy(at + p)
			var ph := HUT_DECK - foot
			mesh_at(cyl(0.18, 0.24, ph, 8), post, p + Vector3(0, foot + ph / 2.0, 0), h)
			cyl_solid(0.22, ph, p + Vector3(0, foot + ph / 2.0, 0), h)
			# Cross braces between the stilts
			var a2 := (k + 1) * TAU / 6.0 + 0.3
			var q := Vector3(cos(a2), 0, sin(a2)) * (HUT_R - 0.4)
			var br := mesh_at(cyl(0.06, 0.06, p.distance_to(q) * 1.25, 5), post, (p + q) / 2.0 + Vector3(0, HUT_DECK * 0.45, 0), h)
			br.basis = Basis.looking_at((q - p) + Vector3(0, HUT_DECK * 0.6, 0), Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		# Gaps in the rail where a bridge or the ramp comes in
		var gaps := []
		for j in [i - 1, i + 1]:
			if j >= 0 and j < HUTS.size():
				var to: Vector3 = HUTS[j] - HUTS[i]
				gaps.append(atan2(to.z, to.x))
		var face := Vector3(-at.x, 0, -at.z).normalized()
		if i == 0:
			gaps.append(atan2(face.z, face.x))
		_rail_ring(h, HUT_R - 0.15, HUT_DECK, gaps, 1.1)
		# The round hut, its doorway facing the valley
		var door := atan2(face.z, face.x)
		var hr := 2.4
		for k in 14:
			var a := k * TAU / 14.0
			if absf(wrapf(a - door, -PI, PI)) < 0.42:
				continue
			var wp := Vector3(cos(a), 0, sin(a)) * hr + Vector3(0, HUT_DECK + 1.15, 0)
			var wm := mesh_at(box(Vector3(1.12, 2.3, 0.15)), wall, wp, h)
			wm.rotation.y = -a + PI / 2.0
			var wb := BoxShape3D.new()
			wb.size = Vector3(1.12, 2.3, 0.15)
			solid(wb, wp, h, Vector3(0, -a + PI / 2.0, 0))
		_thatch(h, Vector3(0, HUT_DECK + 2.3, 0), hr + 1.2, 2.4)
		var lamp := mesh_at(cyl(0.15, 0.18, 0.35, 8), glow, Vector3(cos(door), 0, sin(door)) * (hr + 0.5) + Vector3(0, HUT_DECK + 2.1, 0), h)
		lamp.name = "Hut Lantern"
		var hm := mesh_at(ball(1.0, 10), hammock, Vector3(0, gy(at) + 1.1, 0), h)
		hm.scale = Vector3(2.0, 0.18, 0.55)
		var shade := _marker("Shade Hut %d" % (i + 1), at)
		shade.set_meta("radius", HUT_R)
		shade.set_meta("height", HUT_DECK - 0.3)
	# The ramp up to the first hut, from the valley side
	var in_dir := Vector3(-HUTS[0].x, 0, -HUTS[0].z).normalized()
	var base0 := Vector3(HUTS[0].x, 0, HUTS[0].z)
	var top: Vector3 = base0 + in_dir * (HUT_R - 0.1) + Vector3(0, HUT_DECK, 0)
	var foot: Vector3 = base0 + in_dir * (HUT_R + 14.0)
	foot.y = gy(foot)
	_plank_walk(g, foot, top, 1.8)
	# The rope bridges between the huts
	for i in HUTS.size() - 1:
		var a: Vector3 = Vector3(HUTS[i].x, HUT_DECK, HUTS[i].z)
		var b: Vector3 = Vector3(HUTS[i + 1].x, HUT_DECK, HUTS[i + 1].z)
		var dd := (b - a).normalized()
		_plank_walk(g, a + dd * (HUT_R - 0.2), b - dd * (HUT_R - 0.2), 1.4)
	_marker("HutTop", Vector3(HUTS[2].x, HUT_DECK + 0.1, HUTS[2].z) + Vector3(-HUTS[2].x, 0, -HUTS[2].z).normalized() * 3.3)


func _creek() -> void:
	# The creek: the big waterfall's water runs on out of the Falls Pool round the valley's edge, under the stilt huts'
	# rope bridge and out across the beach into the sea. Shallow: you wade it (scripts/water.gd), and stepping stones
	# carry the paths over it.
	var g := Node3D.new()
	g.name = "Creek"
	world.add_child(g)
	var water := mat("Creek Water", Color(0.4, 0.82, 0.92), 0.1, 0.25, 0.8)
	var bed := mat("Creek Bed", Color(0.62, 0.74, 0.62), 0.9)
	var pebble := mat("Pebble", Color(0.92, 0.88, 0.8), 0.8)
	# A smooth line through its points, a point every metre
	var line: Array = []
	for i in creek_pts.size() - 1:
		var a: Vector3 = creek_pts[i]
		var b: Vector3 = creek_pts[i + 1]
		var n := maxi(1, int(a.distance_to(b)))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			line.append(ground(p))
	line.append(ground(creek_pts[-1]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bst := SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector4] = []
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_bl := Vector3.ZERO
	var prev_br := Vector3.ZERO
	for i in line.size():
		var p: Vector3 = line[i]
		var nxt: Vector3 = line[mini(i + 1, line.size() - 1)]
		var prv: Vector3 = line[maxi(i - 1, 0)]
		var dir := Vector3(nxt.x - prv.x, 0, nxt.z - prv.z).normalized()
		var side := dir.cross(Vector3.UP)
		var mouth := clampf((_r_of(p) - 96.0) / 20.0, 0.0, 1.0)
		var half := CREEK_W / 2.0 * (1.0 + mouth) + 0.25 * sin(i * 0.7)
		var l := ground(p + side * half)
		var r := ground(p - side * half)
		l.y += CREEK_Y
		r.y += CREEK_Y
		var bl := ground(p + side * (half + 0.5))
		var br := ground(p - side * (half + 0.5))
		bl.y += 0.04
		br.y += 0.04
		if i > 0:
			_tri(st, prev_l, prev_r, l)
			_tri(st, prev_r, r, l)
			_tri(bst, prev_bl, prev_br, bl)
			_tri(bst, prev_br, br, bl)
		prev_l = l
		prev_r = r
		prev_bl = bl
		prev_br = br
		if i % 2 == 0 and gy(p) > -0.4:
			outline.append(Vector4(p.x, p.z, half + 0.2, half + 0.2))
		# Pebbles along its banks
		if i % 3 == 1:
			for sx in [-1.0, 1.0]:
				var pb := mesh_at(ball(rng.randf_range(0.18, 0.3), 7), pebble, ground(p + side * sx * (half + 0.35)) + Vector3(0, 0.06, 0), g)
				pb.scale = Vector3(1.2, 0.6, 1.0)
	st.generate_normals()
	bst.generate_normals()
	var bm := MeshInstance3D.new()
	bm.name = "Creek Bed"
	bm.mesh = bst.commit()
	bm.material_override = bed
	g.add_child(bm)
	var wm := MeshInstance3D.new()
	wm.name = "Creek Water"
	wm.mesh = st.commit()
	wm.material_override = water
	g.add_child(wm)
	var wet := Node3D.new()
	wet.name = "Creek Wading"
	wet.set_script(load("res://scripts/water.gd"))
	wet.set("ellipses", outline)
	wet.set("water_y", CREEK_Y)
	g.add_child(wet)
	# Stepping stones where a path crosses it
	var stone := mat("Stepping Stone", Color(0.86, 0.78, 0.66), 0.9)
	var crossings := 0
	for path in paths:
		var pts: Array = path[0]
		for j in pts.size() - 1:
			for i in line.size() - 1:
				var hit = Geometry2D.segment_intersects_segment(Vector2(pts[j].x, pts[j].z), Vector2(pts[j + 1].x, pts[j + 1].z),
					Vector2(line[i].x, line[i].z), Vector2(line[i + 1].x, line[i + 1].z))
				if hit == null:
					continue
				var at := Vector3(hit.x, 0, hit.y)
				var across: Vector3 = (pts[j + 1] - pts[j])
				across = Vector3(across.x, 0, across.z).normalized()
				for k in 4:
					var sp := ground(at + across * (k - 1.5) * 1.0)
					var sm := mesh_at(cyl(0.45, 0.5, 0.2, 9), stone, sp + Vector3(0, 0.08, 0), g)
					sm.name = "Stepping Stone"
				crossings += 1
	g.set_meta("crossings", crossings)
	_marker("CreekMouth", creek_pts[-1])


func _marsh() -> void:
	# The mangrove marsh round the stilt huts, where the creek meets the sea: shallow brown-green water, mangrove trees
	# up on their arching roots, and reeds
	var g := Node3D.new()
	g.name = "Mangrove Marsh"
	g.set_script(load("res://scripts/water.gd"))
	var outline: Array[Vector4] = []
	for e in MARSH:
		outline.append(e)
	g.set("ellipses", outline)
	g.set("water_y", CREEK_Y)
	world.add_child(g)
	var water := mat("Marsh Water", Color(0.36, 0.62, 0.55), 0.1, 0.15, 0.82)
	var mud := mat("Marsh Mud", Color(0.45, 0.42, 0.3), 0.95)
	for i in MARSH.size():
		var e: Vector4 = MARSH[i]
		var at := Vector3(e.x, 0, e.y)
		var bm := mesh_at(cyl(1.0, 1.0, 0.04, 28), mud, ground(at) + Vector3(0, 0.02, 0), g)
		bm.scale = Vector3(e.z + 0.6, 1, e.w + 0.6)
		var wm := mesh_at(cyl(1.0, 1.0, 0.04, 28), water, ground(at) + Vector3(0, CREEK_Y, 0), g)
		wm.scale = Vector3(e.z, 1, e.w)
		wm.name = "Marsh Water %d" % (i + 1)
	var bark := mat("Mangrove Bark", Color(0.5, 0.4, 0.32), 0.9)
	var leaf := [mat("Mangrove Leaf", Color(0.24, 0.5, 0.3), 0.85), mat("Mangrove Leaf Light", Color(0.34, 0.6, 0.34), 0.85)]
	var reed := mat("Reed", Color(0.5, 0.66, 0.32), 0.9)
	var trees := 0
	var tries := 0
	while trees < 16 and tries < 3000:
		tries += 1
		var e: Vector4 = MARSH[rng.randi() % MARSH.size()]
		var a := rng.randf() * TAU
		var k := rng.randf_range(0.35, 1.05)
		var p := Vector3(e.x + cos(a) * e.z * k, 0, e.y + sin(a) * e.w * k)
		if not _marsh_spot_clear(p):
			continue
		trees += 1
		var t := Node3D.new()
		t.position = ground(p)
		g.add_child(t)
		t.name = "Mangrove"                  # (after it's in, so the second one is "Mangrove2", not a made-up name)
		var lift := rng.randf_range(1.1, 1.6)
		var th := rng.randf_range(2.2, 3.4)
		mesh_at(cyl(0.16, 0.22, th, 7), bark, Vector3(0, lift + th / 2.0, 0), t)
		cyl_solid(0.25, lift + th, Vector3(0, (lift + th) / 2.0, 0), t)
		# Its roots arch out from the trunk and down into the water, like legs
		for r in 6:
			var ra := r * TAU / 6.0 + rng.randf() * 0.4
			var out := Vector3(cos(ra), 0, sin(ra))
			var top := Vector3(0, lift + 0.3, 0)
			var knee := out * 0.8 + Vector3(0, lift * 0.75, 0)
			var foot := out * 1.5
			for seg in [[top, knee], [knee, foot]]:
				var a0: Vector3 = seg[0]
				var a1: Vector3 = seg[1]
				var rm := mesh_at(cyl(0.05, 0.07, a0.distance_to(a1), 5), bark, (a0 + a1) / 2.0, t)
				rm.basis = Basis.looking_at(a1 - a0, Vector3.UP if absf((a1 - a0).normalized().y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2.0)
		for c in rng.randi_range(4, 6):
			var lf := mesh_at(ball(rng.randf_range(1.0, 1.6), 8), leaf[c % 2], Vector3(rng.randf_range(-1.1, 1.1),
				lift + th + rng.randf_range(-0.2, 0.8), rng.randf_range(-1.1, 1.1)), t)
			lf.scale = Vector3(1.25, 0.75, 1.25)
	var reeds := 0
	tries = 0
	while reeds < 40 and tries < 3000:
		tries += 1
		var e: Vector4 = MARSH[rng.randi() % MARSH.size()]
		var a := rng.randf() * TAU
		var p := Vector3(e.x + cos(a) * (e.z + 0.3), 0, e.y + sin(a) * (e.w + 0.3))
		if not _marsh_spot_clear(p):
			continue
		reeds += 1
		var rd := Node3D.new()
		rd.position = ground(p)
		g.add_child(rd)
		rd.name = "Reeds"
		for k in 5:
			var h := rng.randf_range(0.8, 1.5)
			var rs := mesh_at(cyl(0.025, 0.04, h, 4), reed, Vector3(rng.randf_range(-0.3, 0.3), h / 2.0, rng.randf_range(-0.3, 0.3)), rd)
			rs.rotation = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
	print("MARSH mangroves=", trees, " reeds=", reeds)


func _marsh_spot_clear(p: Vector3) -> bool:
	# Not in a hut's stilts, under its ramp or bridges, in the creek, or out of the island
	var flat := Vector2(p.x, p.z)
	for h in HUTS:
		if flat.distance_to(Vector2(h.x, h.z)) < HUT_R + 1.6:
			return false
	if _near_line(flat, [HUTS[0], HUTS[1], HUTS[2]], 2.4):
		return false
	if flat.distance_to(Vector2(_hut_ramp_mid().x, _hut_ramp_mid().z)) < 9.5:
		return false
	if _near_line(flat, creek_pts, CREEK_W + 1.0):
		return false
	return _inland(p, 1.0) and _flat(p, 1.0)


func _crystal_cave() -> void:
	# The crystal cave in its notch at the foot of the North Highlands, like the picture: a great mouth framed by
	# boulders, a hollow roof of rock, a turquoise pool (one of the cool pools) and huge glowing crystals all round.
	var g := Node3D.new()
	g.name = "Crystal Cave"
	g.position = CAVE
	world.add_child(g)
	var rock := [mat("Cave Rock", Color(0.66, 0.5, 0.42), 0.95), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9)]
	var face := Vector3(-CAVE.x, 0, -CAVE.z).normalized()
	var door_a := atan2(face.z, face.x)
	for k in 26:
		var a := k * TAU / 26.0
		if absf(wrapf(a - door_a, -PI, PI)) < 0.36:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * CAVE_R
		var hh := rng.randf_range(6.0, 8.0)
		var r := mesh_at(cyl(1.5, 2.1, hh, 9), rock[k % 3], p + Vector3(0, hh / 2.0, 0), g)
		r.rotation.y = rng.randf() * TAU
		cyl_solid(2.0, hh, p + Vector3(0, hh / 2.0, 0), g)
		var bl := mesh_at(ball(rng.randf_range(1.8, 2.6), 9), rock[(k + 1) % 3], p * 1.05 + Vector3(0, hh - 0.4, 0), g)
		bl.scale = Vector3(1.2, 0.8, 1.1)
	var dome_mat := mat("Cave Roof", Color(0.6, 0.46, 0.4), 0.95).duplicate() as StandardMaterial3D
	dome_mat.resource_name = "Cave Roof"
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dome := SphereMesh.new()
	dome.radius = CAVE_R + 2.2
	dome.height = (CAVE_R + 2.2) * 2.0
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 9
	var roof := mesh_at(dome, dome_mat, Vector3(0, 6.0, 0), g)
	roof.scale = Vector3(1, 0.32, 1)
	roof.name = "Cave Roof"
	mesh_at(cyl(2.4, 3.0, 1.2, 10), mat("Cliff Green", Color(0.38, 0.66, 0.32), 0.9), Vector3(0, 9.6, 0), g)
	# The mouth: an arch of boulders over the doorway
	for k in 9:
		var t := float(k) / 8.0
		var ang := PI * t
		var off := Vector3(cos(door_a + PI / 2.0), 0, sin(door_a + PI / 2.0)) * cos(ang) * 4.2
		var bp := face * (CAVE_R + 0.4) + off + Vector3(0, 1.0 + sin(ang) * 5.4, 0)
		var bl := mesh_at(ball(rng.randf_range(1.3, 1.8), 8), rock[k % 3], bp, g)
		bl.scale = Vector3(1.1, 0.9, 1.2)
	for sx in [-1.0, 1.0]:
		var side: Vector3 = Vector3(cos(door_a + PI / 2.0), 0, sin(door_a + PI / 2.0)) * sx * 4.6
		cyl_solid(1.2, 6.0, face * (CAVE_R + 0.4) + side + Vector3(0, 3.0, 0), g)
	# Crystals: six great hexagonal clusters round the pool and walls, and little ones everywhere, glowing
	var cols := [mat("Crystal Teal", Color(0.4, 0.95, 0.9), 0.2, 1.4), mat("Crystal Lilac", Color(0.75, 0.55, 1.0), 0.2, 1.4),
		mat("Crystal Pink", Color(1.0, 0.55, 0.8), 0.2, 1.2), mat("Crystal Blue", Color(0.45, 0.6, 1.0), 0.2, 1.4)]
	for k in 6:
		var a := door_a + PI + (k - 2.5) * 0.55
		var base := Vector3(cos(a), 0, sin(a)) * (CAVE_R - 2.6)
		var cl := Node3D.new()
		cl.name = "Crystal Cluster %d" % (k + 1)
		cl.position = base
		g.add_child(cl)
		for c in 5:
			var hh := rng.randf_range(1.6, 4.2) * (1.4 if c == 0 else 1.0)
			var cr := mesh_at(cyl(0.05, rng.randf_range(0.35, 0.6), hh, 6), cols[(k + c) % 4],
				Vector3(rng.randf_range(-0.6, 0.6), hh / 2.0 - 0.2, rng.randf_range(-0.6, 0.6)), cl)
			cr.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
		cyl_solid(0.8, 3.0, Vector3(0, 1.5, 0), cl)
	for k in 22:
		var a := rng.randf() * TAU
		if absf(wrapf(a - door_a, -PI, PI)) < 0.5:
			continue
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(5.0, CAVE_R - 1.2)
		for c in rng.randi_range(2, 4):
			var hh := rng.randf_range(0.6, 1.8)
			var cr := mesh_at(cyl(0.0, rng.randf_range(0.15, 0.3), hh, 6), cols[(k + c) % 4],
				base + Vector3(rng.randf_range(-0.3, 0.3), hh / 2.0, rng.randf_range(-0.3, 0.3)), g)
			cr.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	for k in 3:
		var l := OmniLight3D.new()
		l.light_color = [Color(0.5, 0.95, 0.95), Color(0.75, 0.55, 1.0), Color(0.5, 0.6, 1.0)][k]
		l.light_energy = 1.4
		l.omni_range = 11.0
		l.position = Vector3(-3.0 + k * 3.0, 3.0, 0)
		g.add_child(l)
	var shade := _marker("Shade Cave", CAVE)
	shade.set_meta("radius", CAVE_R - 0.5)
	shade.set_meta("height", 6.0)


func _grotto() -> void:
	# The waterfall grotto in another notch in the highlands' cliff, like the picture: an overhang of rock, a falls
	# pouring down the back wall into its pool, and purple crystals glowing round the edge. Cool and shady inside.
	var g := Node3D.new()
	g.name = "Waterfall Grotto"
	g.position = GROTTO
	world.add_child(g)
	var out := Vector3(GROTTO.x, 0, GROTTO.z).normalized()          # (towards the cliff)
	var door_a := atan2(-out.z, -out.x)
	var rock := [mat("Cave Rock", Color(0.66, 0.5, 0.42), 0.95), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9)]
	for k in 18:
		var a := k * TAU / 18.0
		if absf(wrapf(a - door_a, -PI, PI)) < 0.75:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * GROTTO_R
		var hh := rng.randf_range(6.0, 9.0)
		mesh_at(cyl(1.4, 2.0, hh, 9), rock[k % 2], p + Vector3(0, hh / 2.0, 0), g).rotation.y = rng.randf() * TAU
		cyl_solid(1.8, hh, p + Vector3(0, hh / 2.0, 0), g)
	var over_mat := mat("Cave Roof", Color(0.6, 0.46, 0.4), 0.95).duplicate() as StandardMaterial3D
	over_mat.resource_name = "Cave Roof"
	over_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dome := SphereMesh.new()
	dome.radius = GROTTO_R + 2.0
	dome.height = (GROTTO_R + 2.0) * 2.0
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	var roof := mesh_at(dome, over_mat, out * 2.0 + Vector3(0, 6.5, 0), g)
	roof.scale = Vector3(1, 0.35, 1)
	roof.name = "Grotto Roof"
	# The falls down the back wall (its own name, so scripts/big_falls.gd leaves it as it is)
	_sheet(g, "Grotto Falls", out * (GROTTO_R - 1.6) + Vector3(0, 9.0, 0), 0.0, -out, 2.6)
	_foam(g, out * (GROTTO_R - 3.0), 1.2, 5)
	var crystal := [mat("Crystal Lilac", Color(0.75, 0.55, 1.0), 0.2, 1.4), mat("Crystal Purple", Color(0.6, 0.35, 0.95), 0.2, 1.6)]
	for k in 12:
		var a := rng.randf() * TAU
		if absf(wrapf(a - door_a, -PI, PI)) < 0.8:
			continue
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(GROTTO_R - 3.0, GROTTO_R - 1.2)
		for c in rng.randi_range(2, 4):
			var hh := rng.randf_range(0.8, 2.4)
			var cr := mesh_at(cyl(0.02, rng.randf_range(0.18, 0.35), hh, 6), crystal[(k + c) % 2],
				base + Vector3(rng.randf_range(-0.3, 0.3), hh / 2.0, rng.randf_range(-0.3, 0.3)), g)
			cr.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.5, 1.0)
	l.light_energy = 1.4
	l.omni_range = 11.0
	l.position = Vector3(0, 3.0, 0)
	g.add_child(l)
	var shade := _marker("Shade Grotto", GROTTO)
	shade.set_meta("radius", GROTTO_R - 0.5)
	shade.set_meta("height", 6.0)


func _pier() -> void:
	# The pier: a plank walk on posts from the beach out over the sea, with rope rails (and unseen walls, so nobody
	# tumbles in) and a little boat tied up at the end
	var g := Node3D.new()
	g.name = "Pier"
	world.add_child(g)
	var start_z := shore_r(PI / 2.0) - 9.0
	var length := PIER_END - start_z
	var plank := [mat("Pier Plank", Color(0.66, 0.48, 0.32), 0.85), mat("Pier Plank Dark", Color(0.56, 0.4, 0.27), 0.85)]
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var rope := mat("Rope", Color(0.85, 0.75, 0.55), 0.9)
	var k := 0
	var z := start_z
	while z < PIER_END:
		mesh_at(box(Vector3(PIER_W, 0.12, 0.55)), plank[k % 2], Vector3(PIER_X, -0.05, z + 0.3), g)
		z += 0.62
		k += 1
	var deck := BoxShape3D.new()
	deck.size = Vector3(PIER_W, 0.3, length)
	solid(deck, Vector3(PIER_X, -0.15, start_z + length / 2.0), g).name = "Pier Deck"
	var pz := start_z + 1.0
	while pz < PIER_END:
		for sx in [-1.0, 1.0]:
			var x: float = PIER_X + sx * (PIER_W / 2.0 + 0.05)
			var bottom := LAND.height(x, pz) - 0.3
			var h := 1.1 - bottom
			mesh_at(cyl(0.12, 0.14, h, 8), post, Vector3(x, bottom + h / 2.0, pz), g)
		pz += 3.0
	for sx in [-1.0, 1.0]:
		var x: float = PIER_X + sx * (PIER_W / 2.0 + 0.05)
		var r := mesh_at(cyl(0.035, 0.035, length - 1.0, 6), rope, Vector3(x, 0.95, start_z + length / 2.0 + 0.5), g,
			Vector3(PI / 2.0, 0, 0))
		r.name = "Rope Rail"
		var wall := BoxShape3D.new()
		wall.size = Vector3(0.3, 3.0, length + 1.0)
		solid(wall, Vector3(x + sx * 0.1, 1.2, start_z + length / 2.0 - 0.5), g).name = "Pier Rail"
	var end := BoxShape3D.new()
	end.size = Vector3(PIER_W + 0.6, 3.0, 0.3)
	solid(end, Vector3(PIER_X, 1.2, PIER_END + 0.2), g).name = "Pier End"
	var boat := Node3D.new()
	boat.name = "Boat"
	boat.position = Vector3(PIER_X + PIER_W / 2.0 + 1.6, SEA_Y + 0.1, PIER_END - 6.0)
	g.add_child(boat)
	var hull := mat("Boat Hull", Color(0.3, 0.6, 0.85), 0.6)
	var trim := mat("Boat Trim", Color(1.0, 0.95, 0.85), 0.6)
	var b := mesh_at(cyl(1.0, 0.7, 0.7, 12), hull, Vector3(0, 0.2, 0), boat)
	b.scale = Vector3(1, 1, 2.4)
	var rim := mesh_at(cyl(1.02, 1.02, 0.08, 12), trim, Vector3(0, 0.56, 0), boat)
	rim.scale = Vector3(1, 1, 2.4)
	mesh_at(box(Vector3(1.6, 0.08, 0.35)), plank[0], Vector3(0, 0.45, 0.4), boat)


func _multi(parent: Node3D, n: String, mesh: Mesh, m: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.multimesh = mm
	mi.material_override = m
	parent.add_child(mi)
	MultiFill.pack(mi, xforms, [])
	return mi


func _grove_frame() -> Array:
	# The grove's path runs straight out along GROVE_A on the West Terrace: [its direction, its side]
	var dir := LAND.at(GROVE_A, 1.0)
	return [dir, dir.cross(Vector3.UP)]


func _bamboo_grove() -> void:
	# The bamboo grove, like the picture: a long straight stone path on the West Terrace walled in by tall bamboo that
	# leans in and arches over it, post lanterns glowing all along both sides and pink flowers at its feet. The
	# stalks are merged into a few meshes (hundreds of them), with unseen walls behind the first row.
	var g := Node3D.new()
	g.name = "Bamboo Grove"
	world.add_child(g)
	var fr := _grove_frame()
	var dir: Vector3 = fr[0]
	var side: Vector3 = fr[1]
	var y := TERRACE_Y
	var stone := [mat("Path Stone", Color(0.78, 0.74, 0.66), 0.9), mat("Path Stone Dark", Color(0.66, 0.62, 0.56), 0.9)]
	var s := GROVE_FROM
	var k := 0
	while s < GROVE_TO - 0.5:
		var p := dir * s + Vector3(0, y + 0.03, 0)
		var slab := mesh_at(box(Vector3(2.6, 0.08, 1.0)), stone[k % 2], p + side * rng.randf_range(-0.1, 0.1), g)
		slab.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05))
		s += 1.12
		k += 1
	# The stalks
	var stalk_mats := [mat("Bamboo", Color(0.55, 0.75, 0.35), 0.7), mat("Bamboo Light", Color(0.7, 0.82, 0.4), 0.7),
		mat("Bamboo Dark", Color(0.4, 0.6, 0.3), 0.7)]
	var leaf_mat := mat("Bamboo Leaf", Color(0.45, 0.72, 0.3), 0.8)
	# (Hundreds of stalks, rings and leaves: each kind is one MultiMesh, kept as transforms: scripts/multi_fill.gd)
	var sts := [[], [], []]
	var rings := []
	var lst := []
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.09
	stalk.bottom_radius = 0.12
	stalk.height = 1.0
	stalk.radial_segments = 6
	stalk.rings = 0
	var ring := CylinderMesh.new()
	ring.top_radius = 0.135
	ring.bottom_radius = 0.135
	ring.height = 0.07
	ring.radial_segments = 6
	ring.rings = 0
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1.0
	leaf.radial_segments = 6
	leaf.rings = 3
	var count := 0
	for sx in [-1.0, 1.0]:
		s = GROVE_FROM + 1.0
		while s < GROVE_TO:
			s += rng.randf_range(0.1, 0.22)
			var lat := rng.randf_range(2.8, 7.5)
			if sx > 0.0 and s < GROVE_FROM + 7.0:
				continue                      # (the way through to the legend hut)
			var base: Vector3 = dir * s + side * sx * lat
			if LAND.height(base.x, base.z) < y - 0.5:
				continue
			base.y = LAND.height(base.x, base.z)
			var h := rng.randf_range(11.0, 16.0)
			# It leans in over the path, the further out the more, so the tops meet overhead
			var lean := (lat - 0.8) * rng.randf_range(0.45, 0.7)
			var tip: Vector3 = base + Vector3(0, h, 0) - side * sx * lean + dir * rng.randf_range(-0.5, 0.5)
			var up: Vector3 = (tip - base).normalized()
			var slen: float = base.distance_to(tip)
			var bas := Basis(up.cross(dir).normalized(), up, up.cross(dir).normalized().cross(up))
			var m := count % 3
			sts[m].append(Transform3D(bas.scaled_local(Vector3(1, slen, 1)), base + up * slen / 2.0))
			var rk := 1.5
			while rk < slen - 1.0:
				rings.append(Transform3D(bas, base + up * rk))
				rk += rng.randf_range(1.3, 1.7)
			for l in 4:
				var lp: Vector3 = base + up * (slen - l * 1.2 - 0.4)
				var lb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
				lst.append(Transform3D(lb.scaled_local(Vector3(2.6, 0.22, 0.8)), lp))
			count += 1
	for i in 3:
		_multi(g, "Bamboo Stalks %d" % (i + 1), stalk, stalk_mats[i], sts[i])
	_multi(g, "Bamboo Rings", ring, mat("Bamboo Ring", Color(0.35, 0.5, 0.22), 0.8), rings)
	_multi(g, "Bamboo Leaves", leaf, leaf_mat, lst)
	# Unseen walls behind the first stalks, and one across the far end
	for sx in [-1.0, 1.0]:
		var s0 := GROVE_FROM + (7.5 if sx > 0.0 else 2.0)
		var w := BoxShape3D.new()
		w.size = Vector3(0.6, 5.0, GROVE_TO - s0)
		solid(w, dir * ((s0 + GROVE_TO) / 2.0) + side * sx * 3.1 + Vector3(0, y + 2.4, 0), g).basis = Basis.looking_at(dir, Vector3.UP)
	var endw := BoxShape3D.new()
	endw.size = Vector3(7.0, 5.0, 0.6)
	solid(endw, dir * (GROVE_TO + 0.4) + Vector3(0, y + 2.4, 0), g).basis = Basis.looking_at(dir, Vector3.UP)
	# Post lanterns all along both sides (scripts/detail_props.gd swaps them for the baked ones)
	var post := mat("Lantern Stone", Color(0.72, 0.7, 0.66), 0.9)
	var glow := mat("Lantern Glow", Color(1.0, 0.82, 0.5), 0.5, 2.0)
	var roof := mat("Lantern Roof", Color(0.32, 0.25, 0.2), 0.9)
	s = GROVE_FROM + 4.0
	var n := 0
	while s < GROVE_TO - 1.0:
		for sx in [-1.0, 1.0]:
			var ln := Node3D.new()
			ln.name = "Stone Lantern"
			ln.position = dir * s + side * sx * 2.0 + Vector3(0, y, 0)
			g.add_child(ln)
			mesh_at(cyl(0.12, 0.16, 1.1, 6), post, Vector3(0, 0.55, 0), ln)
			mesh_at(box(Vector3(0.42, 0.45, 0.42)), glow, Vector3(0, 1.32, 0), ln)
			mesh_at(cyl(0.05, 0.42, 0.25, 4), roof, Vector3(0, 1.68, 0), ln)
			cyl_solid(0.25, 1.6, Vector3(0, 0.8, 0), ln)
			n += 1
		s += 6.0
	var flowers := [mat("Petal Pink", Color(1.0, 0.5, 0.7), 0.6, 0.2), mat("Hibiscus Red", Color(1.0, 0.35, 0.4), 0.6, 0.15)]
	for f in 40:
		var fs := rng.randf_range(GROVE_FROM + 2.0, GROVE_TO - 1.0)
		var fp := dir * fs + side * (1.0 if f % 2 == 0 else -1.0) * rng.randf_range(2.3, 2.8) + Vector3(0, y + 0.25, 0)
		mesh_at(ball(0.16, 6), flowers[f % 2], fp, g)
	for k2 in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 0.8
		l.omni_range = 12.0
		l.position = dir * lerpf(GROVE_FROM + 8.0, GROVE_TO - 8.0, k2) + Vector3(0, y + 2.5, 0)
		g.add_child(l)
	var shade := _marker("Shade Bamboo", GROVE)
	shade.set_meta("radius", GROVE_R)
	shade.set_meta("height", 10.0)
	print("GROVE stalks=", count, " lanterns=", n)


func _overlook() -> void:
	# The overlook, like the picture: a boardwalk running off the East Headland's cliff top out over the sea to a
	# railed platform, a purple crescent banner and a bench to watch the sea from, and a lighthouse on a rock off the
	# point. Its +z runs out to sea.
	var g := Node3D.new()
	g.name = "Overlook"
	var out := LAND.at(2.0, 1.0)
	var from_r := 117.0
	g.position = LAND.at(2.0, from_r, OVERLOOK.y)
	g.rotation.y = atan2(out.x, out.z)
	world.add_child(g)
	var wood := [mat("Boardwalk", Color(0.7, 0.5, 0.33), 0.85), mat("Boardwalk Dark", Color(0.58, 0.42, 0.28), 0.85)]
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var rope := mat("Rope", Color(0.85, 0.75, 0.55), 0.9)
	var walk_w := 3.4
	var walk_l := 19.0
	var plat := 8.0
	for k in int(walk_l / 0.6):
		mesh_at(box(Vector3(walk_w, 0.12, 0.55)), wood[k % 2], Vector3(0, -0.06, k * 0.6 + 0.3), g)
	var deck := BoxShape3D.new()
	deck.size = Vector3(walk_w, 0.3, walk_l)
	solid(deck, Vector3(0, -0.15, walk_l / 2.0), g).name = "Overlook Walk"
	for k in int(plat / 0.6):
		mesh_at(box(Vector3(plat + 1.0, 0.12, 0.55)), wood[(k + 1) % 2], Vector3(0, -0.06, walk_l + k * 0.6 + 0.3), g)
	var pd := BoxShape3D.new()
	pd.size = Vector3(plat + 1.0, 0.3, plat)
	solid(pd, Vector3(0, -0.15, walk_l + plat / 2.0), g).name = "Overlook Deck"
	# Posts down into the sea (or the cliff) under it
	var z := 3.0
	while z < walk_l + plat:
		var hw := walk_w / 2.0 if z < walk_l else (plat + 1.0) / 2.0
		for sx in [-1.0, 1.0]:
			var wp := g.position + Basis(Vector3.UP, g.rotation.y) * Vector3(sx * hw, 0, z)
			var bottom := LAND.height(wp.x, wp.z) - OVERLOOK.y - 0.5
			if bottom > -0.4:
				continue
			mesh_at(cyl(0.16, 0.2, -bottom, 8), post, Vector3(sx * hw, bottom / 2.0, z), g)
		z += 3.5
	# Rails and unseen walls round it
	var rails := [[Vector3(-walk_w / 2.0, 0, 0), Vector3(-walk_w / 2.0, 0, walk_l)], [Vector3(walk_w / 2.0, 0, 0), Vector3(walk_w / 2.0, 0, walk_l)],
		[Vector3(-walk_w / 2.0, 0, walk_l), Vector3(-(plat + 1.0) / 2.0, 0, walk_l)], [Vector3(walk_w / 2.0, 0, walk_l), Vector3((plat + 1.0) / 2.0, 0, walk_l)],
		[Vector3(-(plat + 1.0) / 2.0, 0, walk_l), Vector3(-(plat + 1.0) / 2.0, 0, walk_l + plat)],
		[Vector3((plat + 1.0) / 2.0, 0, walk_l), Vector3((plat + 1.0) / 2.0, 0, walk_l + plat)],
		[Vector3(-(plat + 1.0) / 2.0, 0, walk_l + plat), Vector3((plat + 1.0) / 2.0, 0, walk_l + plat)]]
	for rdef in rails:
		var a: Vector3 = rdef[0]
		var b: Vector3 = rdef[1]
		var rl := mesh_at(cyl(0.04, 0.04, a.distance_to(b), 6), rope, (a + b) / 2.0 + Vector3(0, 1.0, 0), g)
		rl.basis = Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		var pn := int(a.distance_to(b) / 2.0) + 1
		for k in pn + 1:
			mesh_at(cyl(0.08, 0.09, 1.1, 6), post, a.lerp(b, float(k) / pn) + Vector3(0, 0.55, 0), g)
		var w := BoxShape3D.new()
		w.size = Vector3(0.3, 2.6, a.distance_to(b) + 0.3)
		solid(w, (a + b) / 2.0 + Vector3(0, 1.2, 0), g).basis = Basis.looking_at(b - a, Vector3.UP)
	var bench := mesh_at(box(Vector3(2.6, 0.15, 0.6)), wood[1], Vector3(0, 0.5, walk_l + 3.0), g)
	bench.name = "Bench"
	for x in [-1.1, 1.1]:
		mesh_at(box(Vector3(0.15, 0.45, 0.5)), post, Vector3(x, 0.22, walk_l + 3.0), g)
	var cloth := mat("Banner Purple", Color(0.42, 0.22, 0.6), 0.8)
	var gold := mat("Banner Gold", Color(1.0, 0.8, 0.35), 0.4, 0.3, 1.0, 0.5)
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * (plat / 2.0 + 0.2), 0, walk_l + 1.0)
		mesh_at(cyl(0.09, 0.11, 6.0, 8), post, at + Vector3(0, 3.0, 0), g)
		mesh_at(box(Vector3(0.08, 0.08, 1.6)), post, at + Vector3(0, 5.8, 0.7), g)
		var banner := mesh_at(box(Vector3(0.05, 3.0, 1.3)), cloth, at + Vector3(0, 4.2, 0.75), g)
		banner.name = "Banner"
		var moon := TorusMesh.new()
		moon.inner_radius = 0.3
		moon.outer_radius = 0.44
		for face in [1.0, -1.0]:
			mesh_at(moon, gold, at + Vector3(0.05 * face, 4.5, 0.75), g, Vector3(0, 0, PI / 2.0))
			var bite := mesh_at(cyl(0.33, 0.33, 0.04, 14), cloth, at + Vector3(0.09 * face, 4.58, 0.6), g, Vector3(0, 0, PI / 2.0))
			bite.name = "Banner Bite"
	_marker("OverlookEnd", g.position + Basis(Vector3.UP, g.rotation.y) * Vector3(0, 0.05, walk_l + 4.0))
	# The lighthouse on its rock off the point
	var lh := Node3D.new()
	lh.name = "Lighthouse"
	var la := LAND.at(-12.0, 178.0)
	la.y = LAND.height(la.x, la.z)
	lh.position = la
	world.add_child(lh)
	var rk := mesh_at(cyl(6.0, 9.0, 4.0 - la.y, 10), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9), Vector3(0, (4.0 - la.y) / 2.0, 0), lh)
	rk.name = "Lighthouse Rock"
	var white := mat("Lighthouse White", Color(0.97, 0.95, 0.9), 0.7)
	var red := mat("Lighthouse Red", Color(0.85, 0.25, 0.25), 0.7)
	for k in 5:
		mesh_at(cyl(1.6 - k * 0.12, 1.72 - k * 0.12, 2.6, 14), white if k % 2 == 0 else red, Vector3(0, 4.0 - la.y + 1.3 + k * 2.6, 0), lh)
	var top_y := 4.0 - la.y + 13.0
	mesh_at(cyl(1.0, 1.0, 1.6, 12), mat("Lighthouse Lamp", Color(1.0, 0.92, 0.6), 0.3, 2.5), Vector3(0, top_y + 0.8, 0), lh)
	mesh_at(cyl(0.1, 1.4, 1.2, 12), red, Vector3(0, top_y + 2.2, 0), lh)


func _flower_glade() -> void:
	# A clearing ringed by giant flowers taller than you, with butterflies resting on them and a ring of flat stones in
	# the middle to sit on
	var g := Node3D.new()
	g.name = "Flower Glade"
	g.position = GLADE
	world.add_child(g)
	var stem := mat("Flower Stem", Color(0.3, 0.6, 0.3), 0.9)
	var leafy := mat("Jungle Leaf Light", Color(0.45, 0.75, 0.35), 0.8)
	var petals := [mat("Hibiscus Red", Color(1.0, 0.35, 0.4), 0.6, 0.15), mat("Petal Pink", Color(1.0, 0.5, 0.7), 0.6, 0.2),
		mat("Petal Orange", Color(1.0, 0.6, 0.25), 0.6, 0.2), mat("Petal Yellow", Color(1.0, 0.9, 0.3), 0.6, 0.2)]
	var heart := mat("Flower Heart", Color(1.0, 0.95, 0.6), 0.5, 0.6)
	var stone := mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)
	var wings := [mat("Wing Blue", Color(0.35, 0.65, 1.0), 0.5, 0.4), mat("Wing Lilac", Color(0.8, 0.6, 1.0), 0.5, 0.4)]
	for k in 11:
		var a := k * TAU / 11.0 + 0.2
		var at := Vector3(cos(a), 0, sin(a)) * GLADE_R
		var h := rng.randf_range(3.0, 4.8)
		mesh_at(cyl(0.16, 0.22, h, 8), stem, at + Vector3(0, h / 2.0, 0), g)
		cyl_solid(0.22, h, at + Vector3(0, h / 2.0, 0), g)
		for side in [-1.0, 1.0]:
			var lf := mesh_at(ball(0.9, 8), leafy, at + Vector3(0, h * 0.4, 0) + Vector3(cos(a + side * 1.2), 0, sin(a + side * 1.2)) * 0.7, g)
			lf.scale = Vector3(0.35, 0.06, 1.0)
			lf.rotation.y = -(a + side * 1.2) + PI / 2.0
		var bloom := Node3D.new()
		bloom.position = at + Vector3(0, h, 0)
		bloom.rotation = Vector3(-0.9, -a - PI / 2.0, 0)
		bloom.scale = Vector3.ONE * 1.6
		g.add_child(bloom)
		for pk in 5:
			var pa := pk * TAU / 5.0
			var pt := mesh_at(ball(0.55, 10), petals[k % 4], Vector3(cos(pa), sin(pa), 0) * 0.5, bloom)
			pt.scale = Vector3(1.0, 1.0, 0.18)
		mesh_at(ball(0.18, 8), heart, Vector3(0, 0, 0.12), bloom)
		mesh_at(cyl(0.03, 0.03, 0.7, 4), heart, Vector3(0, 0.15, 0.4), bloom, Vector3(PI / 2.0 - 0.3, 0, 0))
		if k % 3 == 0:
			var bf := Node3D.new()
			bf.position = at + Vector3(0, h + 1.0, 0)
			bf.rotation.y = rng.randf() * TAU
			g.add_child(bf)
			for side in [-1.0, 1.0]:
				var wg := mesh_at(ball(0.2, 6), wings[k % 2], Vector3(side * 0.17, 0, 0), bf, Vector3(0, 0, side * 0.5))
				wg.scale = Vector3(1.0, 0.12, 0.8)
	for k in 6:
		var a := k * TAU / 6.0
		var st := mesh_at(cyl(0.45, 0.5, 0.25, 8), stone, Vector3(cos(a), 0, sin(a)) * 2.6 + Vector3(0, 0.1, 0), g)
		st.rotation.y = a
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.7)
	l.light_energy = 0.6
	l.omni_range = 10.0
	l.position = Vector3(0, 3.5, 0)
	g.add_child(l)


func _legend_hut() -> void:
	# The legend hut on the West Terrace by the grove: a round hut, open towards the grove's path, with the island's
	# story painted round its wall in four pictures (no words): the springs and their great drum, the beat breaking
	# and the sun stuck hot, a girl dancing it back, and the whole island singing. A drum stands in the middle
	var g := Node3D.new()
	g.name = "Legend Hut"
	g.position = LEGEND_HUT
	var to_path := LAND.at(196, 80) - Vector3(LEGEND_HUT.x, 0, LEGEND_HUT.z)
	g.rotation.y = atan2(to_path.x, to_path.z)      # its open side (+z) faces the path from the grove
	world.add_child(g)
	var wall := mat("Hut Wall", Color(0.85, 0.7, 0.48), 0.9)
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var r := 4.5
	for k in 18:
		var a := k * TAU / 18.0
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.7:
			continue                                      # (the open side)
		var at := Vector3(cos(a), 0, sin(a)) * r
		var w := mesh_at(box(Vector3(1.62, 3.0, 0.2)), wall, at + Vector3(0, 1.5, 0), g)
		w.rotation.y = -a + PI / 2.0
		var wb := BoxShape3D.new()
		wb.size = Vector3(1.62, 3.0, 0.2)
		solid(wb, at + Vector3(0, 1.5, 0), g, Vector3(0, -a + PI / 2.0, 0))
	for sx in [-1.0, 1.0]:
		var a: float = PI / 2.0 + sx * 0.72
		mesh_at(cyl(0.16, 0.18, 3.2, 8), post, Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 1.6, 0), g)
	_thatch(g, Vector3(0, 3.0, 0), r + 1.4, 3.0)
	var paint := {
		"sky": mat("Paint Sky", Color(0.55, 0.8, 0.95), 0.9), "sand": mat("Paint Sand", Color(0.95, 0.78, 0.5), 0.9),
		"sea": mat("Paint Sea", Color(0.2, 0.6, 0.75), 0.9), "sun": mat("Paint Sun", Color(1.0, 0.85, 0.3), 0.6, 0.3),
		"hot": mat("Paint Hot", Color(1.0, 0.4, 0.2), 0.6, 0.3), "drum": mat("Paint Drum", Color(0.7, 0.35, 0.3), 0.9),
		"girl": mat("Paint Purple", Color(0.6, 0.35, 0.85), 0.8), "note": mat("Paint Note", Color(1.0, 1.0, 1.0), 0.6, 0.3),
		"frame": mat("Paint Frame", Color(0.42, 0.3, 0.2), 0.9)}
	for i in 4:
		var a := PI / 2.0 + PI + (i - 1.5) * 0.55
		var at := Vector3(cos(a), 0, sin(a)) * (r - 0.14)
		var panel := Node3D.new()
		panel.name = "Legend %d" % (i + 1)
		panel.position = at + Vector3(0, 1.6, 0)
		panel.rotation.y = -a - PI / 2.0
		panel.scale = Vector3.ONE * 1.25
		g.add_child(panel)
		mesh_at(box(Vector3(1.2, 1.2, 0.04)), paint.frame, Vector3(0, 0, 0), panel)
		mesh_at(box(Vector3(1.05, 0.62, 0.02)), paint.hot if i == 1 else paint.sky, Vector3(0, 0.2, 0.03), panel)
		mesh_at(box(Vector3(1.05, 0.25, 0.02)), paint.sea, Vector3(0, -0.4, 0.03), panel)
		mesh_at(box(Vector3(0.7, 0.18, 0.02)), paint.sand, Vector3(0, -0.22, 0.04), panel)
		mesh_at(cyl(0.12, 0.12, 0.02, 12), paint.sun if i != 1 else paint.hot, Vector3(0.32, 0.36, 0.05), panel,
			Vector3(PI / 2.0, 0, 0))
		match i:
			0:
				mesh_at(cyl(0.13, 0.13, 0.02, 10), paint.drum, Vector3(-0.05, -0.04, 0.05), panel, Vector3(PI / 2.0, 0, 0))
			1:
				mesh_at(box(Vector3(0.1, 0.24, 0.02)), paint.drum, Vector3(-0.14, -0.04, 0.05), panel, Vector3(0, 0, 0.4))
				mesh_at(box(Vector3(0.1, 0.24, 0.02)), paint.drum, Vector3(0.04, -0.04, 0.05), panel, Vector3(0, 0, -0.4))
			2:
				mesh_at(box(Vector3(0.12, 0.3, 0.02)), paint.girl, Vector3(-0.05, -0.02, 0.05), panel, Vector3(0, 0, 0.25))
				for nk in 3:
					mesh_at(cyl(0.035, 0.035, 0.02, 8), paint.note, Vector3(-0.3 + nk * 0.25, 0.2 + (nk % 2) * 0.08, 0.05), panel,
						Vector3(PI / 2.0, 0, 0))
			3:
				for nk in 6:
					var na := nk * TAU / 6.0
					mesh_at(cyl(0.035, 0.035, 0.02, 8), paint.note, Vector3(cos(na) * 0.3, 0.15 + sin(na) * 0.12, 0.05), panel,
						Vector3(PI / 2.0, 0, 0))
	mesh_at(cyl(0.7, 0.6, 1.0, 16), paint.drum, Vector3(0, 0.5, 0), g)
	mesh_at(cyl(0.72, 0.72, 0.06, 16), mat("Drum Skin", Color(0.95, 0.88, 0.7), 0.8), Vector3(0, 1.02, 0), g)
	cyl_solid(0.7, 1.05, Vector3(0, 0.52, 0), g)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.55)
	l.light_energy = 0.8
	l.omni_range = 7.0
	l.position = Vector3(0, 2.2, 0)
	g.add_child(l)
	var shade := _marker("Shade Legend Hut", LEGEND_HUT)
	shade.set_meta("radius", r - 0.3)
	shade.set_meta("height", 3.4)


func _tide_pools() -> void:
	# Little rock pools out on the beach where the waves don't reach: shallow water, a starfish or a shell in each, and
	# a crab here and there (only to look at)
	var g := Node3D.new()
	g.name = "Tide Pools"
	world.add_child(g)
	var rock := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Cave Rock", Color(0.66, 0.5, 0.42), 0.95)]
	var water := mat("Lagoon Water", Color(0.35, 0.85, 0.85), 0.1, 0.0, 0.75)
	var star := [mat("Starfish Orange", Color(1.0, 0.5, 0.25), 0.7), mat("Starfish Pink", Color(1.0, 0.45, 0.6), 0.7)]
	var shell := mat("Shell", Color(1.0, 0.92, 0.85), 0.5)
	var crab := mat("Crab Red", Color(0.95, 0.3, 0.25), 0.6)
	# Real tide pools sit in hollows in flat rock, not in sand, so they're on a shelf of wet, dark sandstone at the foot
	# of the Pavilion Bluff's cliff, with boulders along its sea edge
	var shelf := [mat("Wet Rock", Color(0.6, 0.46, 0.38), 0.5), mat("Wet Rock Dark", Color(0.5, 0.38, 0.33), 0.5)]
	var weed := mat("Seaweed", Color(0.3, 0.5, 0.3), 0.8)
	var shelf_g := Node3D.new()
	shelf_g.name = "Rock Shelf"
	g.add_child(shelf_g)
	var deg: float = TIDE_A[0] - 3.0
	while deg <= TIDE_A[-1] + 3.0:
		var a := deg_to_rad(deg)
		for rr in [-9.0, -6.5, -4.0, -1.8]:
			var p: Vector3 = Vector3(cos(a), 0, sin(a)) * (shore_r(a) + rr + rng.randf_range(-0.6, 0.6))
			p.y = LAND.height(p.x, p.z)
			var sr := rng.randf_range(1.6, 2.4)
			var sl := mesh_at(cyl(sr, sr * 1.08, 0.18, 9), shelf[int(deg) % 2], p + Vector3(0, 0.0, 0), shelf_g)
			sl.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.0))
			sl.rotation.y = rng.randf() * TAU
			sl.name = "Shelf Slab"
		var edge := Vector3(cos(a), 0, sin(a)) * (shore_r(a) + 0.4)
		edge.y = LAND.height(edge.x, edge.z)
		var bo := mesh_at(ball(rng.randf_range(0.5, 0.9), 7), shelf[1], edge + Vector3(0, 0.15, 0), shelf_g)
		bo.scale = Vector3(1.3, 0.7, 1.1)
		if int(deg) % 3 == 0:
			var wd := mesh_at(ball(0.35, 6), weed, edge + Vector3(0.3, 0.12, 0.2), shelf_g)
			wd.scale = Vector3(1.6, 0.25, 1.0)
		deg += 2.2
	for i in TIDE_A.size():
		var a: float = deg_to_rad(TIDE_A[i])
		var rs := shore_r(a)
		var r := rs - 5.0 - (i % 2) * 1.2
		var at := Vector3(cos(a), 0, sin(a)) * r
		at.y = LAND.height(at.x, at.z)
		var pool := Node3D.new()
		pool.name = "Tide Pool %d" % (i + 1)
		pool.position = at
		g.add_child(pool)
		var pr := rng.randf_range(0.9, 1.3)
		mesh_at(cyl(pr, pr, 0.04, 14), water, Vector3(0, 0.1, 0), pool).name = "Tide Water"
		for k in 7:
			var ka := k * TAU / 7.0 + rng.randf() * 0.4
			var bs := rng.randf_range(0.28, 0.45)
			var b := mesh_at(ball(bs, 7), rock[k % 2], Vector3(cos(ka), 0, sin(ka)) * (pr + 0.15) + Vector3(0, bs * 0.3, 0), pool)
			b.scale = Vector3(1.2, 0.6, 1.0)
		if i % 2 == 0:
			var sf := Node3D.new()
			sf.position = Vector3(rng.randf_range(-0.3, 0.3), 0.06, rng.randf_range(-0.3, 0.3))
			sf.rotation.y = rng.randf() * TAU
			pool.add_child(sf)
			for k in 5:
				var arm := mesh_at(ball(0.12, 6), star[i % 2], Vector3(cos(k * TAU / 5.0), 0, sin(k * TAU / 5.0)) * 0.11, sf)
				arm.scale = Vector3(1.4, 0.3, 0.6)
				arm.rotation.y = -k * TAU / 5.0
		else:
			var sh := mesh_at(ball(0.13, 8), shell, Vector3(0.2, 0.07, -0.1), pool)
			sh.scale = Vector3(1.0, 0.5, 1.3)
		if i == 2:
			var c := Node3D.new()
			c.name = "Crab"
			c.position = Vector3(pr + 0.7, 0.12, 0.2)
			pool.add_child(c)
			var bd := mesh_at(ball(0.16, 8), crab, Vector3.ZERO, c)
			bd.scale = Vector3(1.3, 0.6, 1.0)
			for side in [-1.0, 1.0]:
				mesh_at(ball(0.07, 6), crab, Vector3(side * 0.24, 0.04, 0.1), c)
				mesh_at(ball(0.04, 6), mat("Eye White", Color(1, 1, 1), 0.4), Vector3(side * 0.06, 0.12, 0.1), c)


func _islet() -> void:
	# A little islet out in the sea, reached along a sandbar with stepping stones (railed with unseen walls so nobody
	# slips into the deep water): a sandy mound with a palm, a ring of shells and a glowing conch on a rock
	var g := Node3D.new()
	g.name = "Islet"
	world.add_child(g)
	var centre := islet_at()
	var from := bar_from()
	var dir := Vector3(centre.x - from.x, 0, centre.z - from.z).normalized()
	var to := centre - dir * (ISLET_R - 0.5)
	to.y = 0.0
	var flat_from := Vector3(from.x, 0, from.z)
	var length := flat_from.distance_to(to)
	var sand := mat("Beach Sand", Color(0.94, 0.8, 0.6), 0.95)
	var stone := [mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9), mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9)]
	var basis := Basis.looking_at(dir, Vector3.UP)
	# The sandbar: a long bank of wet sand rising out of the sea to just above it, level with the beach where it starts
	var top_y := from.y
	var bar := mesh_at(box(Vector3(BAR_W + 1.6, 9.0, length + 2.0)), sand, (flat_from + to) / 2.0 + Vector3(0, top_y - 4.5, 0), g)
	bar.basis = basis
	bar.name = "Sandbar"
	var walk := BoxShape3D.new()
	walk.size = Vector3(BAR_W, 0.4, length + 1.0)
	solid(walk, (flat_from + to) / 2.0 + Vector3(0, top_y - 0.2, 0), g).basis = basis
	var n := int(length / 1.5)
	for k in n:
		var p := flat_from.lerp(to, (k + 0.5) / n) + basis.x * rng.randf_range(-0.35, 0.35) + Vector3(0, top_y, 0)
		var st := mesh_at(cyl(0.55, 0.6, 0.12, 9), stone[k % 2], p, g)
		st.rotation.y = rng.randf() * TAU
	var side := basis.x
	var start := flat_from + dir * 2.0
	var fence_at := dir * (shore_r(deg_to_rad(ISLET_A)) - 3.0)
	for sx in [-1.0, 1.0]:
		var fill := BoxShape3D.new()
		fill.size = Vector3(3.6, 8.0, 0.6)
		var fb := solid(fill, fence_at + side * sx * (BAR_W / 2.0 + 0.15 + 1.8) + Vector3(0, 3.5, 0), g)
		fb.basis = basis
		fb.name = "WorldBounds Bar Fence"
	for sx in [-1.0, 1.0]:
		var wall := BoxShape3D.new()
		wall.size = Vector3(0.3, 3.0, to.distance_to(start) + 1.0)
		var wb := solid(wall, (start + to) / 2.0 + side * sx * (BAR_W / 2.0 + 0.15) + Vector3(0, top_y + 1.2, 0), g)
		wb.basis = basis
		wb.name = "WorldBounds Bar Wall"
	var cy := top_y
	var mound := mesh_at(cyl(ISLET_R - 0.4, ISLET_R + 4.0, 9.0, 28), sand, centre + Vector3(0, cy - 4.5, 0), g)
	mound.name = "Islet Sand"
	cyl_solid(ISLET_R, 0.6, centre + Vector3(0, cy - 0.3, 0), g)
	var in_a := atan2(-dir.z, -dir.x)
	for k in 24:
		var a := k * TAU / 24.0
		if absf(wrapf(a - in_a, -PI, PI)) < 0.2:
			continue
		var p := centre + Vector3(cos(a), 0, sin(a)) * (ISLET_R + 0.1)
		var b := BoxShape3D.new()
		b.size = Vector3(TAU * (ISLET_R + 0.1) / 24.0 + 0.3, 3.0, 0.4)
		solid(b, p + Vector3(0, cy + 1.2, 0), g, Vector3(0, -a + PI / 2.0, 0)).name = "WorldBounds Islet %d" % k
	_palm(centre + Vector3(2.4, cy, -1.6), 99)
	var shell := [mat("Shell", Color(1.0, 0.92, 0.85), 0.5), mat("Starfish Pink", Color(1.0, 0.45, 0.6), 0.7)]
	for k in 10:
		var a := k * TAU / 10.0
		var sh := mesh_at(ball(0.12, 6), shell[k % 2], centre + Vector3(cos(a), 0, sin(a)) * 2.0 + Vector3(0, cy + 0.03, 0), g)
		sh.scale = Vector3(1.0, 0.5, 1.3)
	var rk := mesh_at(ball(0.7, 8), stone[1], centre + Vector3(0, cy + 0.2, 0), g)
	rk.scale = Vector3(1.0, 0.6, 0.9)
	cyl_solid(0.65, 0.6, centre + Vector3(0, cy + 0.28, 0), g)
	var conch := mesh_at(cyl(0.02, 0.22, 0.5, 10), mat("Conch Glow", Color(1.0, 0.7, 0.8), 0.4, 0.8), centre + Vector3(0, cy + 0.82, 0), g,
		Vector3(0, 0, PI / 2.0 - 0.4))
	conch.name = "Glowing Conch"
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.85)
	l.light_energy = 0.8
	l.omni_range = 5.0
	l.position = centre + Vector3(0, cy + 1.5, 0)
	g.add_child(l)
	_marker("IsletTop", centre + Vector3(0, cy + 0.1, 2.5))


func _jungle() -> void:
	# All over the island, on the lowland and up on the terraces: palms (tall, leaning, like the pictures), leafy
	# bushes and big tropical leaves, and bright flowers
	var leafy := [mat("Jungle Leaf", Color(0.3, 0.62, 0.32), 0.8), mat("Jungle Leaf Light", Color(0.45, 0.75, 0.35), 0.8),
		mat("Jungle Leaf Dark", Color(0.22, 0.5, 0.3), 0.8)]
	var bloom := [mat("Petal Pink", Color(1.0, 0.5, 0.7), 0.6, 0.2), mat("Petal Orange", Color(1.0, 0.6, 0.25), 0.6, 0.2),
		mat("Petal Yellow", Color(1.0, 0.9, 0.3), 0.6, 0.2)]
	var g := Node3D.new()
	g.name = "Jungle"
	world.add_child(g)
	var palms := 0
	var tries := 0
	while palms < 90 and tries < 8000:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(57.0, shore_r(a) - 6.0)
		if _blocked(p, 3.0) or not _inland(p, 1.5) or not _flat(p, 1.5):
			continue
		_palm(ground(p), PALMS.size() + palms)
		ridge_rocks.append(Vector4(p.x, p.z, 1.0, 5.0))      # (so nothing else grows into it)
		palms += 1
	var bushes := 0
	tries = 0
	while bushes < 320 and tries < 6000:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(56.0, shore_r(a) - 6.0)
		if _blocked(p, 1.0) or not _inland(p, 0.5) or not _flat(p, 1.0):
			continue
		bushes += 1
		var b := Node3D.new()
		b.name = "Bush"
		b.position = ground(p)
		g.add_child(b)
		for k in rng.randi_range(2, 4):
			var s := mesh_at(ball(rng.randf_range(0.6, 1.2), 8), leafy[(bushes + k) % 3], Vector3(rng.randf_range(-0.7, 0.7),
				0.4, rng.randf_range(-0.7, 0.7)), b)
			s.scale = Vector3(1.2, rng.randf_range(0.7, 1.1), 1.2)
		if bushes % 3 == 0:
			for k in 3:
				var lf := mesh_at(ball(0.9, 8), leafy[k % 3], Vector3(0, 1.1, 0), b, Vector3(0.5, k * TAU / 3.0, 0))
				lf.scale = Vector3(0.45, 0.08, 1.4)
		if bushes % 2 == 0:
			for k in 4:
				mesh_at(ball(0.12, 6), bloom[(bushes + k) % 3], Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.6, 1.1),
					rng.randf_range(-0.8, 0.8)), b)
	print("ISLAND palms=", palms, " bushes=", bushes)


func _in_pool(p: Vector3, room: float) -> bool:
	for e: Vector4 in (all_pools if not all_pools.is_empty() else POOLS):
		var dx := (p.x - e.x) / (e.z + room)
		var dz := (p.z - e.y) / (e.w + room)
		if dx * dx + dz * dz < 1.0:
			return true
	return false


func _near_line(flat: Vector2, pts: Array, reach: float) -> bool:
	for i in pts.size() - 1:
		var pa := Vector2(pts[i].x, pts[i].z)
		var pb := Vector2(pts[i + 1].x, pts[i + 1].z)
		var u := clampf((flat - pa).dot(pb - pa) / maxf((pb - pa).length_squared(), 0.001), 0.0, 1.0)
		if flat.distance_to(pa.lerp(pb, u)) < reach:
			return true
	return false


func _blocked(p: Vector3, room: float) -> bool:
	var flat := Vector2(p.x, p.z)
	if _in_pool(p, room + 1.0):
		return true
	for c in [[MESA, MESA_R + 2.5], [DANCE, DANCE_R + 2.0], [STAGE, STAGE_R + 2.0], [Vector3(0, 0, 33), 9.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	for h in HOT_SPRINGS:
		if flat.distance_to(Vector2(h.x, h.z)) < 4.0 + room:
			return true
	for rk: Vector4 in ridge_rocks:
		if flat.distance_to(Vector2(rk.x, rk.y)) < rk.z + 2.0 + room:
			return true
	for c in [[ARRIVE, 7.0], [WAY_HOME, 6.0], [TIME_STONE, 3.0], [GATE, 8.0],
			[PAVILION, PAV_R + 6.5], [CAVE, CAVE_R + 2.5], [GROTTO, GROTTO_R + 2.5], [HUTS[0], HUT_R + 1.5],
			[HUTS[1], HUT_R + 1.5], [HUTS[2], HUT_R + 1.5], [_hut_ramp_mid(), 9.0],
			[(HUTS[0] + HUTS[1]) / 2.0, 3.0], [(HUTS[1] + HUTS[2]) / 2.0, 3.0],
			[GLADE, GLADE_R + 1.5], [LEGEND_HUT, 6.5], [bar_from(), 4.0], [islet_at(), ISLET_R]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	# Nothing in the creek or the marsh, on the volcano's peak or in the spring's stream
	if _near_line(flat, creek_pts, CREEK_W + 1.0 + room):
		return true
	for e: Vector4 in MARSH:
		var mx := (p.x - e.x) / (e.z + 1.0 + room)
		var mz := (p.z - e.y) / (e.w + 1.0 + room)
		if mx * mx + mz * mz < 1.0:
			return true
	for pk in LAND.PEAKS:
		var pc := LAND.at(pk[0], pk[1])
		if flat.distance_to(Vector2(pc.x, pc.z)) < float(pk[2]) * 1.17 + 1.0 + room:
			return true
	if spring_at != Vector3.ZERO and _near_line(flat, [spring_at, spring_to], 3.0 + room):
		return true
	# Nothing on the ramps up the cliffs
	if LAND.on_ramp(p.x, p.z, 2.5 + room):
		return true
	# The gate's walls, the grove, the overlook's boardwalk and the pier
	if absf(p.z - GATE.z) < 3.0 + room and absf(p.x - GATE.x) < 20.0 + room:
		return true
	if _near_line(flat, [LAND.at(GROVE_A, GROVE_FROM - 2.0), LAND.at(GROVE_A, GROVE_TO + 1.0)], 8.0 + room):
		return true
	if _near_line(flat, [LAND.at(2.0, 112.0), LAND.at(2.0, 146.0)], 6.0 + room):
		return true
	if p.z > 40.0 and absf(p.x - PIER_X) < PIER_W / 2.0 + 1.5 + room:
		return true
	for path in paths:
		if _near_line(flat, path[0], float(path[1]) + 1.5 + room):
			return true
	# The Hum Heads stand round the north-west (scripts/stone_heads.gd: 41 m out, 215 to 255 degrees)
	for deg in [215.0, 225.0, 235.0, 245.0, 255.0]:
		var hd := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * 41.0
		if flat.distance_to(hd) < 3.5 + room:
			return true
	var a := Vector2(SIZZLE_FROM.x, SIZZLE_FROM.z)
	var b := Vector2(SIZZLE_TO.x, SIZZLE_TO.z)
	var t := clampf((flat - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return flat.distance_to(a.lerp(b, t)) < SIZZLE_W / 2.0 + 3.0 + room
