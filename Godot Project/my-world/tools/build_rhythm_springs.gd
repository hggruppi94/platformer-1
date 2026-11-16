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
const ISLAND_IN := 53.5                      # the island's ground starts just under the valley's sand floor
const SEA_Y := -0.35
const ARRIVE := Vector3(0, 0, 60)            # the way in: on the beach, at the foot of the pier
const WAY_HOME := Vector3(-7, 0, 57)
const TIME_STONE := Vector3(-13, 0, 52)
const PIER_X := 8.0
const PIER_W := 3.2
const PIER_END := 100.0
const FALLS_ROCK := Vector3(20, 0, -64)      # the ridge's waterfall rock
const FALLS_ROCK_R := 7.0
const FALLS_ROCK_H := 16.0
const GROVE := Vector3(-60, 0, -22)          # the bamboo grove
const GROVE_R := 11.0
const OVERLOOK := Vector3(73, 0, -12)        # the boardwalk on the eastern headland
const LAGOON_AT := [128.0, 150.0, 40.0]      # angles round the island (0 east, 90 south) of the lagoon coves
const GATE := Vector3(0, 0, 47)              # the gate over the torch path, where it comes up into the valley
const PAVILION := Vector3(30, 0, 52)         # the thatched pavilion on the south-east lawn
const HUTS := [Vector3(-57, 0, 17), Vector3(-66, 0, 9), Vector3(-63, 0, -1)]   # the stilt treehouses (west)
const HUT_DECK := 3.6                        # how high their decks are
const CAVE := Vector3(53, 0, -31)            # the crystal cave (north-east)
const CAVE_R := 7.5

var all_pools: Array = []                    # the valley's pools, the lagoons and the falls pool
var ridge_rocks: Array = []                  # Vector4(x, z, radius, height) of every ridge rock
var paths: Array = []                        # [from, to, half width] of every path on the island

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
	_crystal_cave()
	_pier()
	_bamboo_grove()
	_overlook()
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
	env.fog_density = 0.0022
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
	# How far out the beach meets the sea at each angle round the island (θ = atan2(z, x)): a wobbly coast, never
	# closer than about 62 m from the middle
	return 78.0 + 9.0 * sin(2.0 * theta + 0.6) + 5.0 * sin(3.0 * theta + 1.9) + 2.5 * sin(7.0 * theta + 0.3)


static func ground_y(r: float, rs: float) -> float:
	# The island's ground at a distance r from the middle where the shore is at rs: flat inland, a beach sloping into
	# the sea and a seabed falling away
	if r <= rs - 6.0:
		return -0.02
	if r <= rs:
		return lerpf(-0.02, -0.6, (r - (rs - 6.0)) / 6.0)
	if r <= rs + 12.0:
		return lerpf(-0.6, -3.0, (r - rs) / 12.0)
	return lerpf(-3.0, -8.0, clampf((r - rs - 12.0) / 30.0, 0.0, 1.0))


func _r_of(p: Vector3) -> float:
	return Vector2(p.x, p.z).length()


func _inland(p: Vector3, room: float) -> bool:
	# Is this spot on dry ground, at least room metres in from the fence along the beach?
	return _r_of(p) < shore_r(atan2(p.z, p.x)) - 4.0 - room


func _plan_island() -> void:
	_find_cross_up()
	# Works out the lagoons, the falls pool and the island's paths before anything's built, so the planting can keep
	# out of them all
	all_pools = POOLS.duplicate()
	for deg in LAGOON_AT:
		var a := deg_to_rad(float(deg))
		var r := shore_r(a) - 11.0
		all_pools.append(Vector4(cos(a) * r, sin(a) * r, 4.2, 3.2))
	all_pools.append(Vector4(CAVE.x, CAVE.z, 3.2, 2.6))           # the crystal cave's pool
	var out := Vector3(-FALLS_ROCK.x, 0, -FALLS_ROCK.z).normalized()
	var fp := FALLS_ROCK + out * (FALLS_ROCK_R + 5.0)
	all_pools.append(Vector4(fp.x, fp.z, 4.5, 3.5))
	paths = [[ARRIVE + Vector3(0, 0, 3), Vector3(0, 0, 31), 1.4],
		[Vector3(-44, 0, -4), GROVE + Vector3(4, 0, 6), 1.2],
		[Vector3(42, 0, -2), OVERLOOK + Vector3(-6, 0, 0), 1.2]]


func _island() -> void:
	# The island's ground: one ring from the valley's edge out to the seabed (solid, sandy), a green ring of grass on
	# the dry part, the sea all round, and an invisible fence along the beach so nobody wades off
	var g := Node3D.new()
	g.name = "Island"
	world.add_child(g)
	var segs := 240
	var ring_pts: Array[PackedVector3Array] = []
	for i in segs + 1:
		var a := i * TAU / segs
		var rs := shore_r(a)
		var radii := []
		for k in 6:                      # (every row has the same number of points, so rows join up neatly)
			radii.append(lerpf(ISLAND_IN, rs - 6.0, k / 6.0))
		for extra in [rs - 6.0, rs - 3.0, rs, rs + 4.0, rs + 12.0, rs + 26.0, rs + 42.0]:
			radii.append(extra)
		var row := PackedVector3Array()
		for rr in radii:
			row.append(Vector3(cos(a) * rr, ground_y(rr, rs), sin(a) * rr))
		ring_pts.append(row)
	var faces := []                # (an Array: packed arrays are copied when passed to _tri)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var r0: PackedVector3Array = ring_pts[i]
		var r1: PackedVector3Array = ring_pts[i + 1]
		for k in r0.size() - 1:
			_tri(st, r0[k], r1[k], r0[k + 1], faces)
			_tri(st, r0[k + 1], r1[k], r1[k + 1], faces)
	st.generate_normals()
	var mesh := st.commit()
	var ground := mesh_at(mesh, mat("Beach Sand", Color(0.94, 0.8, 0.6), 0.95), Vector3.ZERO, g)
	ground.name = "Beach"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(faces))
	solid(shape, Vector3.ZERO, g).name = "Island Ground"
	# Green on the dry land: a ring of grass from just outside the valley to a little way back from the beach
	var gs := SurfaceTool.new()
	gs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat_up := Vector3.UP
	for i in segs:
		var a0 := i * TAU / segs
		var a1 := (i + 1) * TAU / segs
		var in0 := 57.0 + 1.6 * sin(5.0 * a0 + 0.4)
		var in1 := 57.0 + 1.6 * sin(5.0 * a1 + 0.4)
		var out0 := shore_r(a0) - 10.0 + 1.2 * sin(9.0 * a0)
		var out1 := shore_r(a1) - 10.0 + 1.2 * sin(9.0 * a1)
		var p00 := Vector3(cos(a0) * in0, 0.012, sin(a0) * in0)
		var p01 := Vector3(cos(a0) * out0, 0.012, sin(a0) * out0)
		var p10 := Vector3(cos(a1) * in1, 0.012, sin(a1) * in1)
		var p11 := Vector3(cos(a1) * out1, 0.012, sin(a1) * out1)
		gs.set_normal(flat_up)
		_tri(gs, p00, p01, p10)
		_tri(gs, p10, p01, p11)
	mesh_at(gs.commit(), mat("Island Grass", Color(0.47, 0.72, 0.36), 0.95), Vector3.ZERO, g).name = "Island Grass"
	# The sea: clear turquoise over the sand, darker further out
	var sea := PlaneMesh.new()
	sea.size = Vector2(900, 900)
	var water := mat("Sea", Color(0.08, 0.6, 0.72), 0.05, 0.05, 0.82)
	mesh_at(sea, water, Vector3(0, SEA_Y, 0), g).name = "Sea"
	_marker("SeaLevel", Vector3(0, SEA_Y, 0))
	# The fence along the beach, with a gap where the pier goes out
	var fence := Node3D.new()
	fence.name = "WorldBounds Fence"           # ("WorldBounds": the map's picture covers everything inside it)
	g.add_child(fence)
	var fsegs := 160
	for i in fsegs:
		var a0 := i * TAU / fsegs
		var a1 := (i + 1) * TAU / fsegs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (shore_r(a0) - 3.0)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (shore_r(a1) - 3.0)
		var mid := (p0 + p1) / 2.0
		if mid.z > 0.0 and absf(mid.x - PIER_X) < PIER_W / 2.0 + 0.2:
			continue
		var b := BoxShape3D.new()
		b.size = Vector3(p0.distance_to(p1) + 0.4, 8.0, 0.6)
		var d := p1 - p0
		solid(b, mid + Vector3(0, 3.5, 0), fence, Vector3(0, -atan2(d.z, d.x), 0)).name = "Fence %d" % i


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


func _ridge() -> void:
	# The ridge: stacked sandstone rocks with green tops round the north of the island, running out into the sea, and
	# one great rock with a waterfall pouring off it into the Falls Pool
	var g := Node3D.new()
	g.name = "Ridge"
	world.add_child(g)
	var rocks := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var cap := mat("Cliff Green", Color(0.38, 0.66, 0.32), 0.9)
	ridge_rocks.append(Vector4(FALLS_ROCK.x, FALLS_ROCK.z, FALLS_ROCK_R, FALLS_ROCK_H))
	var deg := 228.0
	while deg <= 318.0:
		var a := deg_to_rad(deg + rng.randf_range(-2.0, 2.0))
		var rs := shore_r(a)
		for row in 2:
			var r := rng.randf_range(60.0, 64.0) + row * rng.randf_range(7.0, 10.0)
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if Vector2(p.x - FALLS_ROCK.x, p.z - FALLS_ROCK.z).length() < FALLS_ROCK_R + 4.0:
				continue
			if r > rs + 6.0:
				continue
			var rad := rng.randf_range(4.5, 7.0)
			var h := rng.randf_range(9.0, 15.0) + row * rng.randf_range(2.0, 6.0)
			ridge_rocks.append(Vector4(p.x, p.z, rad, h))
		deg += 7.5
	for i in ridge_rocks.size():
		var rk: Vector4 = ridge_rocks[i]
		var at := Vector3(rk.x, 0, rk.y)
		var base := ground_y(_r_of(at), shore_r(atan2(at.z, at.x)))
		var holder := Node3D.new()
		holder.name = "Falls Rock" if i == 0 else "Ridge Rock %d" % i
		holder.position = Vector3(at.x, base, at.z)
		g.add_child(holder)
		var tiers := 4
		var h := rk.w - base
		for t in tiers:
			var th := h / tiers
			var r0 := rk.z * (1.0 - t * 0.08)
			var s := mesh_at(cyl(r0 * 0.94, r0, th, 14), rocks[(i + t) % 3], Vector3(0, th * (t + 0.5), 0), holder)
			s.rotation.y = rng.randf() * TAU
			# A ledge between tiers, like the stacked cliffs in the pictures
			if t > 0:
				mesh_at(cyl(r0 * 1.03, r0 * 1.03, 0.3, 14), rocks[(i + t + 1) % 3], Vector3(0, th * t, 0), holder)
		mesh_at(cyl(rk.z * 0.72, rk.z * 0.72 + 0.2, 0.6, 14), cap, Vector3(0, h + 0.2, 0), holder)
		for b in 3:
			var bush := mesh_at(ball(rng.randf_range(0.8, 1.4), 8), cap, Vector3(rng.randf_range(-1, 1) * rk.z * 0.4,
				h + 0.5, rng.randf_range(-1, 1) * rk.z * 0.4), holder)
			bush.scale = Vector3(1.2, 0.7, 1.2)
		cyl_solid(rk.z, h, Vector3(0, h / 2.0, 0), holder)
	# The waterfall: down the great rock's face towards the valley, into the Falls Pool (scripts/big_falls.gd builds
	# it big, with a cove of its own behind it: "ridge_falls")
	var out := Vector3(-FALLS_ROCK.x, 0, -FALLS_ROCK.z).normalized()
	var falls := mat("Falls", Color(0.6, 0.9, 1.0), 0.1, 0.5, 0.7)
	var sheet := mesh_at(box(Vector3(3.0, FALLS_ROCK_H, 0.25)), falls,
		FALLS_ROCK + out * (FALLS_ROCK_R + 0.15) + Vector3(0, FALLS_ROCK_H / 2.0, 0), g,
		Vector3(0, atan2(out.x, out.z), 0))
	sheet.name = "Waterfall"
	sheet.set_meta("fall_id", "ridge_falls")
	var foam := mat("Foam", Color(1, 1, 1), 0.3, 0.4, 0.85)
	for k in 6:
		var f := mesh_at(ball(0.5, 8), foam, FALLS_ROCK + out * (FALLS_ROCK_R + 0.9) + Vector3(rng.randf_range(-1.2, 1.2), 0.35,
			rng.randf_range(-1.0, 1.0)), g)
		f.scale = Vector3(1.3, 0.5, 1.3)


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
		holder.name = "Pool%d" % (i + 1) if not lagoon else ("Falls Pool" if i == all_pools.size() - 1 else
			("Crystal Pool" if i == all_pools.size() - 2 else "Lagoon %d" % (i - POOLS.size() + 1)))
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
	# A parasol palm: a curvy striped trunk with a wide flat crown of big leaves that throws a good pool of shade
	var g := Node3D.new()
	g.name = "Parasol Palm %d" % (k + 1)
	g.position = at
	world.add_child(g)
	var bark := [mat("Palm Bark", Color(0.7, 0.5, 0.35), 0.9), mat("Palm Bark Light", Color(0.85, 0.65, 0.45), 0.9)]
	var leaf := [mat("Palm Leaf", Color(0.35, 0.75, 0.45), 0.8), mat("Palm Leaf Light", Color(0.5, 0.85, 0.45), 0.8)]
	var h := rng.randf_range(4.5, 5.5)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var segs := 6
	for s in segs:
		var t := (s + 0.5) / segs
		mesh_at(cyl(0.22, 0.28, h / segs + 0.05, 8), bark[s % 2], lean * t * t + Vector3(0, h * t, 0), g)
	cyl_solid(0.3, h, Vector3(0, h / 2.0, 0), g)
	var top := lean + Vector3(0, h, 0)
	for l in 8:
		var a := l * TAU / 8.0 + rng.randf() * 0.2
		var lf := mesh_at(ball(1.0, 8), leaf[l % 2], top + Vector3(cos(a), -0.15, sin(a)) * 1.5, g)
		lf.scale = Vector3(1.9, 0.12, 0.7)
		lf.rotation = Vector3(0, -a, -0.18)
	mesh_at(ball(0.35, 8), mat("Coconut", Color(0.45, 0.3, 0.2), 0.9), top + Vector3(0, -0.3, 0), g)
	var shade := _marker("Shade Palm %d" % (k + 1), at + lean)
	shade.set_meta("radius", 3.0)
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
	# Terracotta paths out across the island, lined with tiki torches: from the beach up into the valley (it joins
	# the valley's own paths), out to the bamboo grove and out to the overlook
	var g := Node3D.new()
	g.name = "Torch Paths"
	world.add_child(g)
	var tile := mat("Terracotta", Color(0.8, 0.42, 0.3), 0.8)
	var post := mat("Torch Post", Color(0.45, 0.3, 0.2), 0.9)
	var bind := mat("Torch Binding", Color(0.85, 0.7, 0.45), 0.9)
	var flame := mat("Torch Flame", Color(1.0, 0.6, 0.2), 0.5, 3.0)
	var lit := 0
	for path in paths:
		var from: Vector3 = path[0]
		var to: Vector3 = path[1]
		var half: float = path[2]
		var dir := (to - from).normalized()
		var side := dir.cross(Vector3.UP)
		var n := int(from.distance_to(to) / 1.3)
		for k in n:
			var p: Vector3 = from.lerp(to, (k + 0.5) / n)
			if _in_pool(p, 0.6):
				continue
			for w in [-0.5, 0.5] if half > 1.3 else [0.0]:
				mesh_at(box(Vector3(0.9, 0.06, 0.9)), tile, p + side * w + Vector3(rng.randf_range(-0.15, 0.15), 0.03,
					rng.randf_range(-0.15, 0.15)), g, Vector3(0, rng.randf_range(-0.3, 0.3), 0))
		var tn := int(from.distance_to(to) / 6.0)
		for k in tn:
			var p: Vector3 = from.lerp(to, (k + 0.5) / tn) + side * (half + 0.9) * (1.0 if k % 2 == 0 else -1.0)
			var t := Node3D.new()
			t.name = "Torch"
			t.position = p
			g.add_child(t)
			mesh_at(cyl(0.07, 0.09, 1.9, 6), post, Vector3(0, 0.95, 0), t)
			mesh_at(cyl(0.16, 0.1, 0.3, 8), bind, Vector3(0, 1.95, 0), t)
			var f := mesh_at(ball(0.16, 8), flame, Vector3(0, 2.2, 0), t)
			f.scale = Vector3(1, 1.6, 1)
			f.name = "Flame"
			if lit < 6 and k % 3 == 1:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.6, 0.3)
				l.light_energy = 0.8
				l.omni_range = 7.0
				l.position = Vector3(0, 2.3, 0)
				t.add_child(l)
				lit += 1


func _gate() -> void:
	# The gate over the torch path where it comes up into the valley: two stacked sandstone pillars banded in teal, a
	# carved lintel with a row of round "notes" along it, and a crescent banner hanging from each pillar
	var g := Node3D.new()
	g.name = "Springs Gate"
	g.position = GATE
	world.add_child(g)
	var stone := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	var band := mat("Gate Teal", Color(0.2, 0.62, 0.65), 0.7)
	var gold := mat("Banner Gold", Color(1.0, 0.8, 0.35), 0.4, 0.3, 1.0, 0.5)
	var cloth := mat("Banner Teal", Color(0.2, 0.62, 0.65), 0.8)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 3.2
		for k in 4:
			mesh_at(box(Vector3(1.3 - k * 0.08, 1.4, 1.3 - k * 0.08)), stone[k % 2], Vector3(x, 0.7 + k * 1.4, 0), g)
			mesh_at(box(Vector3(1.45 - k * 0.08, 0.15, 1.45 - k * 0.08)), band, Vector3(x, 1.4 + k * 1.4, 0), g)
		var b := BoxShape3D.new()
		b.size = Vector3(1.3, 5.6, 1.3)
		solid(b, Vector3(x, 2.8, 0), g)
		# The banner on the pillar's valley side and its emblem (both faces)
		mesh_at(box(Vector3(0.9, 2.2, 0.05)), cloth, Vector3(x, 3.4, -0.7), g).name = "Banner"
		var moon := TorusMesh.new()
		moon.inner_radius = 0.22
		moon.outer_radius = 0.32
		for face in [1.0, -1.0]:
			mesh_at(moon, gold, Vector3(x, 3.6, -0.7 + 0.04 * face), g, Vector3(PI / 2.0, 0, 0))
			mesh_at(cyl(0.24, 0.24, 0.04, 14), cloth, Vector3(x + 0.11, 3.66, -0.7 + 0.07 * face), g, Vector3(PI / 2.0, 0, 0))
	mesh_at(box(Vector3(8.4, 0.9, 1.6)), stone[0], Vector3(0, 6.05, 0), g)
	mesh_at(box(Vector3(9.0, 0.25, 1.8)), band, Vector3(0, 6.6, 0), g)
	mesh_at(box(Vector3(5.0, 0.6, 1.2)), stone[1], Vector3(0, 7.0, 0), g)
	for k in 9:
		for face in [1.0, -1.0]:
			mesh_at(ball(0.17, 8), gold, Vector3(-3.2 + k * 0.8, 6.05, 0.82 * face), g)
	var top := BoxShape3D.new()
	top.size = Vector3(8.4, 1.2, 1.6)
	solid(top, Vector3(0, 6.2, 0), g)


func _thatch(parent: Node3D, at: Vector3, r: float, h: float, layers := 3) -> void:
	# A conical thatched roof: layers of straw-coloured cones, each a little wider and lower, with a knob on top
	var straw := [mat("Thatch", Color(0.82, 0.66, 0.38), 0.95), mat("Thatch Dark", Color(0.7, 0.54, 0.3), 0.95)]
	for k in layers:
		var rr := r * (1.0 - k * 0.22)
		var piece := mesh_at(cyl(0.05, rr, h / layers * 1.4, 14), straw[k % 2], at + Vector3(0, h / layers * (k + 0.7), 0), parent)
		piece.name = "Thatch Roof"
	mesh_at(ball(0.25, 8), straw[1], at + Vector3(0, h + 0.2, 0), parent)


func _pavilion() -> void:
	# The pavilion on the lawn: a round wooden floor laid nearly flush with the ground (you can't step up a ledge on
	# foot, so its top is only 4 cm up), eight posts with curtains tied back to
	# them, and a big thatched roof. Shade all through, and a breeze off the sea
	var g := Node3D.new()
	g.name = "Pavilion"
	g.position = PAVILION
	world.add_child(g)
	var wood := mat("Boardwalk", Color(0.7, 0.5, 0.33), 0.85)
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var curtain := [mat("Curtain Cream", Color(1.0, 0.95, 0.85), 0.8), mat("Curtain Coral", Color(1.0, 0.6, 0.5), 0.8)]
	var r := 5.5
	mesh_at(cyl(r, r + 0.2, 0.3, 24), wood, Vector3(0, -0.11, 0), g)
	cyl_solid(r, 0.3, Vector3(0, -0.11, 0), g)
	for k in 8:
		var a := k * TAU / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (r - 0.3)
		mesh_at(cyl(0.14, 0.17, 4.2, 8), post, p + Vector3(0, 2.4, 0), g)
		cyl_solid(0.17, 4.2, p + Vector3(0, 2.4, 0), g)
		# A curtain gathered at each post, swagged across the top between posts
		var c := mesh_at(cyl(0.22, 0.4, 3.4, 8), curtain[k % 2], p + Vector3(0, 2.4, 0), g)
		c.scale = Vector3(1, 1, 0.5)
		c.rotation.y = -a
		c.name = "Curtain"
		var a2 := a + TAU / 16.0
		var swag := mesh_at(ball(1.0, 10), curtain[k % 2], Vector3(cos(a2), 0, sin(a2)) * (r - 0.4) + Vector3(0, 4.15, 0), g)
		swag.scale = Vector3(0.12, 0.35, 1.9)
		swag.rotation.y = -a2
	_thatch(g, Vector3(0, 4.4, 0), r + 1.4, 3.6)
	# A low round table in the middle with cushions round it
	mesh_at(cyl(1.0, 1.0, 0.1, 16), wood, Vector3(0, 0.75, 0), g)
	mesh_at(cyl(0.15, 0.2, 0.45, 8), post, Vector3(0, 0.5, 0), g)
	for k in 6:
		var a := k * TAU / 6.0
		var cu := mesh_at(ball(0.45, 8), curtain[(k + 1) % 2], Vector3(cos(a), 0, sin(a)) * 2.0 + Vector3(0, 0.45, 0), g)
		cu.scale = Vector3(1.2, 0.4, 1.2)
	var shade := _marker("Shade Pavilion", PAVILION)
	shade.set_meta("radius", r)
	shade.set_meta("height", 4.5)


func _hut_ramp_mid() -> Vector3:
	return HUTS[0] + (Vector3(-HUTS[0].x, 0, -HUTS[0].z).normalized() * 7.5)


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
	# Three little treehouses up on stilts at the west of the island, joined by rope bridges, with a ramp up to the
	# first. Each has a thatched roof and a hammock-shady deck; under them is shade too.
	var g := Node3D.new()
	g.name = "Stilt Huts"
	world.add_child(g)
	var wood := mat("Hut Wood", Color(0.62, 0.44, 0.3), 0.85)
	var wall := mat("Hut Wall", Color(0.85, 0.7, 0.48), 0.9)
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var hammock := mat("Curtain Coral", Color(1.0, 0.6, 0.5), 0.8)
	var half := 2.6
	for i in HUTS.size():
		var at: Vector3 = HUTS[i]
		var h := Node3D.new()
		h.name = "Stilt Hut %d" % (i + 1)
		h.position = at
		g.add_child(h)
		mesh_at(box(Vector3(half * 2.0, 0.25, half * 2.0)), wood, Vector3(0, HUT_DECK - 0.125, 0), h)
		var deck := BoxShape3D.new()
		deck.size = Vector3(half * 2.0, 0.25, half * 2.0)
		solid(deck, Vector3(0, HUT_DECK - 0.125, 0), h)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := Vector3(sx * (half - 0.2), 0, sz * (half - 0.2))
				mesh_at(cyl(0.16, 0.2, HUT_DECK, 8), post, p + Vector3(0, HUT_DECK / 2.0, 0), h)
				cyl_solid(0.2, HUT_DECK, p + Vector3(0, HUT_DECK / 2.0, 0), h)
		# A hut on the back half of the deck: three walls and a doorway facing the valley, under a thatched roof
		var face := Vector3(-at.x, 0, -at.z).normalized()
		var hut := Node3D.new()
		hut.name = "Hut"
		hut.position = Vector3(0, HUT_DECK, 0)
		hut.rotation.y = atan2(face.x, face.z)
		h.add_child(hut)
		# Small enough to leave a 1.2 m walk round it on the deck, so the ramp and both bridges join up
		for wdef in [[Vector3(0, 1.1, -1.3), Vector3(2.75, 2.2, 0.15)], [Vector3(-1.3, 1.1, 0), Vector3(0.15, 2.2, 2.6)],
				[Vector3(1.3, 1.1, 0), Vector3(0.15, 2.2, 2.6)], [Vector3(-0.95, 1.1, 1.3), Vector3(0.85, 2.2, 0.15)],
				[Vector3(0.95, 1.1, 1.3), Vector3(0.85, 2.2, 0.15)]]:
			mesh_at(box(wdef[1]), wall, wdef[0], hut)
			var wbox := BoxShape3D.new()
			wbox.size = wdef[1]
			solid(wbox, wdef[0], hut)
		_thatch(hut, Vector3(0, 2.2, 0), 2.3, 1.9, 2)
		# A hammock slung under the deck, between two stilts
		var hm := mesh_at(ball(1.0, 10), hammock, Vector3(0, 1.0, half - 0.2), h)
		hm.scale = Vector3(1.9, 0.18, 0.5)
		var shade := _marker("Shade Hut %d" % (i + 1), at)
		shade.set_meta("radius", half)
		shade.set_meta("height", HUT_DECK - 0.3)
		# A rail round the deck's open edges (the bridges and the ramp come in through gaps)
	# The ramp up to the first hut, from the valley side
	var in_dir := Vector3(-HUTS[0].x, 0, -HUTS[0].z).normalized()
	var top: Vector3 = HUTS[0] + in_dir * half + Vector3(0, HUT_DECK, 0)
	var foot: Vector3 = HUTS[0] + in_dir * (half + 10.0)
	_plank_walk(g, foot + Vector3(0, 0.0, 0), top, 1.8)
	# The rope bridges between the huts
	for i in HUTS.size() - 1:
		var a: Vector3 = HUTS[i]
		var b: Vector3 = HUTS[i + 1]
		var d := (b - a).normalized()
		_plank_walk(g, a + d * half + Vector3(0, HUT_DECK, 0), b - d * half + Vector3(0, HUT_DECK, 0), 1.4)
	_marker("HutTop", HUTS[2] + Vector3(0, HUT_DECK + 0.1, 0))


func _crystal_cave() -> void:
	# The crystal cave: a hollow hill of rock in the north-east with a doorway facing the valley, a turquoise pool in
	# the middle (one of the cool pools) and glowing crystals growing round the walls. Cool and shady inside
	var g := Node3D.new()
	g.name = "Crystal Cave"
	g.position = CAVE
	world.add_child(g)
	var rock := [mat("Cave Rock", Color(0.66, 0.5, 0.42), 0.95), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9)]
	var face := Vector3(-CAVE.x, 0, -CAVE.z).normalized()
	var door_a := atan2(face.z, face.x)
	for k in 22:
		var a := k * TAU / 22.0
		if absf(wrapf(a - door_a, -PI, PI)) < 0.32:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * CAVE_R
		var hh := rng.randf_range(4.0, 5.5)
		var r := mesh_at(cyl(1.4, 1.9, hh, 10), rock[k % 2], p + Vector3(0, hh / 2.0, 0), g)
		r.rotation.y = rng.randf() * TAU
		cyl_solid(1.8, hh, p + Vector3(0, hh / 2.0, 0), g)
	# The roof: a low dome seen from inside as well as out
	var dome_mat := mat("Cave Roof", Color(0.6, 0.46, 0.4), 0.95).duplicate() as StandardMaterial3D
	dome_mat.resource_name = "Cave Roof"
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dome := SphereMesh.new()
	dome.radius = CAVE_R + 1.6
	dome.height = (CAVE_R + 1.6) * 2.0
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	var roof := mesh_at(dome, dome_mat, Vector3(0, 3.2, 0), g)
	roof.scale = Vector3(1, 0.42, 1)
	roof.name = "Cave Roof"
	mesh_at(cyl(1.6, 1.9, 1.2, 10), mat("Cliff Green", Color(0.38, 0.66, 0.32), 0.9), Vector3(0, 6.6, 0), g)
	# The doorway's arch
	var arch := TorusMesh.new()
	arch.inner_radius = 1.8
	arch.outer_radius = 2.6
	var ar := mesh_at(arch, rock[1], face * CAVE_R + Vector3(0, 1.2, 0), g, Vector3(PI / 2.0, 0, 0))
	ar.rotation = Vector3(PI / 2.0, -door_a + PI / 2.0, 0)
	ar.scale = Vector3(1, 1, 1.3)
	# Crystals round the walls and the pool, in teal, lilac and pink, glowing
	var cols := [mat("Crystal Teal", Color(0.4, 0.95, 0.9), 0.2, 1.4), mat("Crystal Lilac", Color(0.75, 0.55, 1.0), 0.2, 1.4),
		mat("Crystal Pink", Color(1.0, 0.55, 0.8), 0.2, 1.2)]
	for k in 18:
		var a := rng.randf() * TAU
		if absf(wrapf(a - door_a, -PI, PI)) < 0.45:
			continue
		var d := rng.randf_range(4.2, CAVE_R - 1.2)
		var base := Vector3(cos(a), 0, sin(a)) * d
		for c in rng.randi_range(2, 4):
			var hh := rng.randf_range(0.6, 1.8)
			var cr := mesh_at(cyl(0.0, rng.randf_range(0.15, 0.3), hh, 6), cols[(k + c) % 3],
				base + Vector3(rng.randf_range(-0.3, 0.3), hh / 2.0, rng.randf_range(-0.3, 0.3)), g)
			cr.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	for k in 2:
		var l := OmniLight3D.new()
		l.light_color = [Color(0.5, 0.95, 0.95), Color(0.85, 0.6, 1.0)][k]
		l.light_energy = 1.2
		l.omni_range = 9.0
		l.position = Vector3(-1.5 + k * 3.0, 2.2, 0)
		g.add_child(l)
	var shade := _marker("Shade Cave", CAVE)
	shade.set_meta("radius", CAVE_R - 0.5)
	shade.set_meta("height", 4.0)


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
			var bottom := ground_y(pz, shore_r(PI / 2.0)) - 0.3
			var h := 1.1 - bottom
			mesh_at(cyl(0.12, 0.14, h, 8), post, Vector3(x, bottom + h / 2.0, pz), g)
		pz += 3.0
	for sx in [-1.0, 1.0]:
		var x: float = PIER_X + sx * (PIER_W / 2.0 + 0.05)
		var r := mesh_at(cyl(0.035, 0.035, length - 1.0, 6), rope, Vector3(x, 0.95, start_z + length / 2.0 + 0.5), g,
			Vector3(PI / 2.0, 0, 0))
		r.name = "Rope Rail"
		var wall := BoxShape3D.new()
		wall.size = Vector3(0.3, 3.0, length + 6.0)
		solid(wall, Vector3(x + sx * 0.1, 1.2, start_z + length / 2.0 - 3.0), g).name = "Pier Rail"
	var end := BoxShape3D.new()
	end.size = Vector3(PIER_W + 0.6, 3.0, 0.3)
	solid(end, Vector3(PIER_X, 1.2, PIER_END + 0.2), g).name = "Pier End"
	# The boat (only to look at, for now)
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


func _bamboo_grove() -> void:
	# The bamboo grove: tall clumps of green stalks with dark rings, a path of stepping stones winding through and
	# stone lanterns glowing along it. It's cool in there (shade all through)
	var g := Node3D.new()
	g.name = "Bamboo Grove"
	g.position = GROVE
	world.add_child(g)
	var stalk := [mat("Bamboo", Color(0.55, 0.75, 0.35), 0.7), mat("Bamboo Light", Color(0.7, 0.82, 0.4), 0.7)]
	var ring := mat("Bamboo Ring", Color(0.35, 0.5, 0.22), 0.8)
	var leaf := mat("Bamboo Leaf", Color(0.45, 0.72, 0.3), 0.8)
	var stone := mat("Lantern Stone", Color(0.72, 0.7, 0.66), 0.9)
	var glow := mat("Lantern Glow", Color(1.0, 0.82, 0.5), 0.5, 2.0)
	# The path through: from the grove's east side round to its west
	var way := [Vector3(4, 0, 6), Vector3(1, 0, 2), Vector3(-2, 0, -1), Vector3(-6, 0, -2), Vector3(-9, 0, -5)]
	var near_way := func(p: Vector3) -> bool:
		for i in way.size() - 1:
			var a: Vector3 = way[i]
			var b: Vector3 = way[i + 1]
			var u := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if p.distance_to(a.lerp(b, u)) < 2.2:
				return true
		return false
	var clumps := 0
	var tries := 0
	while clumps < 26 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * GROVE_R
		var c := Vector3(cos(a) * d, 0, sin(a) * d)
		if near_way.call(c) or not _inland(GROVE + c, 1.0):
			continue
		clumps += 1
		var cl := Node3D.new()
		cl.name = "Bamboo Clump %d" % clumps
		cl.position = c
		g.add_child(cl)
		for s in rng.randi_range(5, 8):
			var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			var h := rng.randf_range(6.0, 9.5)
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
			var st := mesh_at(cyl(0.08, 0.1, h, 6), stalk[s % 2], off + Vector3(0, h / 2.0, 0), cl, lean)
			st.name = "Stalk"
			for k in int(h / 1.2):
				mesh_at(cyl(0.11, 0.11, 0.05, 6), ring, off + Vector3(lean.z * -1.2 * k, 1.0 + k * 1.2, lean.x * 1.2 * k), cl)
			for l in 3:
				var lf := mesh_at(ball(0.6, 6), leaf, off + Vector3(rng.randf_range(-0.6, 0.6), h - l * 0.8, rng.randf_range(-0.6, 0.6)), cl)
				lf.scale = Vector3(1.4, 0.25, 0.5)
				lf.rotation.y = rng.randf() * TAU
		cyl_solid(0.75, 4.0, Vector3(0, 2.0, 0), cl)
	for i in way.size():
		var p: Vector3 = way[i]
		mesh_at(cyl(0.7, 0.75, 0.08, 10), stone, p + Vector3(0, 0.04, 0), g)
		if i % 2 == 0:
			var lp: Vector3 = p + Vector3(1.4, 0, 0.6)
			var ln := Node3D.new()
			ln.name = "Stone Lantern"
			ln.position = lp
			g.add_child(ln)
			mesh_at(cyl(0.18, 0.25, 0.7, 6), stone, Vector3(0, 0.35, 0), ln)
			mesh_at(box(Vector3(0.5, 0.4, 0.5)), glow, Vector3(0, 0.9, 0), ln)
			mesh_at(cyl(0.05, 0.5, 0.3, 6), stone, Vector3(0, 1.25, 0), ln)
			cyl_solid(0.3, 1.4, Vector3(0, 0.7, 0), ln)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 0.7
	l.omni_range = 9.0
	l.position = Vector3(0, 2.0, 0)
	g.add_child(l)
	var shade := _marker("Shade Bamboo", GROVE)
	shade.set_meta("radius", GROVE_R)
	shade.set_meta("height", 7.0)


func _overlook() -> void:
	# The overlook: a boardwalk deck on the eastern headland, railed on the sea side, with two crescent banners (our
	# own: a gold crescent cradling a music note) and a bench to watch the sea from
	var g := Node3D.new()
	g.name = "Overlook"
	g.position = OVERLOOK
	g.rotation.y = -atan2(OVERLOOK.z, OVERLOOK.x) + PI / 2.0    # its +z faces out to sea
	world.add_child(g)
	var wood := [mat("Boardwalk", Color(0.7, 0.5, 0.33), 0.85), mat("Boardwalk Dark", Color(0.58, 0.42, 0.28), 0.85)]
	var post := mat("Pier Post", Color(0.42, 0.3, 0.2), 0.9)
	var rope := mat("Rope", Color(0.85, 0.75, 0.55), 0.9)
	for k in 12:
		mesh_at(box(Vector3(8.0, 0.12, 0.55)), wood[k % 2], Vector3(0, 0.0, -3.2 + k * 0.6), g)
	var deck := BoxShape3D.new()
	deck.size = Vector3(8.0, 0.24, 7.2)
	solid(deck, Vector3(0, -0.06, 0.1), g)
	for x in [-3.9, -1.3, 1.3, 3.9]:
		mesh_at(cyl(0.1, 0.12, 1.2, 8), post, Vector3(x, 0.6, 3.6), g)
	mesh_at(cyl(0.04, 0.04, 7.8, 6), rope, Vector3(0, 1.0, 3.6), g, Vector3(0, 0, PI / 2.0))
	var rail := BoxShape3D.new()
	rail.size = Vector3(8.4, 2.5, 0.3)
	solid(rail, Vector3(0, 1.2, 3.7), g)
	var bench := mesh_at(box(Vector3(2.4, 0.15, 0.6)), wood[1], Vector3(0, 0.5, 1.6), g)
	bench.name = "Bench"
	for x in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.15, 0.45, 0.5)), post, Vector3(x, 0.22, 1.6), g)
	var cloth := mat("Banner Teal", Color(0.2, 0.62, 0.65), 0.8)
	var gold := mat("Banner Gold", Color(1.0, 0.8, 0.35), 0.4, 0.3, 1.0, 0.5)
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * 4.6, 0, -2.6)
		mesh_at(cyl(0.08, 0.1, 5.0, 8), post, at + Vector3(0, 2.5, 0), g)
		mesh_at(box(Vector3(1.4, 0.08, 0.08)), post, at + Vector3(0, 4.8, 0), g)
		var banner := mesh_at(box(Vector3(1.2, 2.6, 0.05)), cloth, at + Vector3(0, 3.4, 0), g)
		banner.name = "Banner"
		var moon := TorusMesh.new()
		moon.inner_radius = 0.28
		moon.outer_radius = 0.4
		for face in [1.0, -1.0]:
			# The emblem on both sides: a crescent (a gold ring with the banner's colour biting out of it) and a note
			mesh_at(moon, gold, at + Vector3(0, 3.6, 0.05 * face), g, Vector3(PI / 2.0, 0, 0))
			var bite := mesh_at(cyl(0.3, 0.3, 0.04, 14), cloth, at + Vector3(0.14, 3.68, 0.09 * face), g, Vector3(PI / 2.0, 0, 0))
			bite.name = "Banner Bite"
			mesh_at(ball(0.09, 6), gold, at + Vector3(-0.05, 3.45, 0.12 * face), g)
			mesh_at(cyl(0.02, 0.02, 0.35, 4), gold, at + Vector3(0.03, 3.6, 0.12 * face), g)


func _jungle() -> void:
	# Out on the island: parasol palms for shade, leafy bushes and big tropical leaves, and bright flowers
	var leafy := [mat("Jungle Leaf", Color(0.3, 0.62, 0.32), 0.8), mat("Jungle Leaf Light", Color(0.45, 0.75, 0.35), 0.8),
		mat("Jungle Leaf Dark", Color(0.22, 0.5, 0.3), 0.8)]
	var bloom := [mat("Petal Pink", Color(1.0, 0.5, 0.7), 0.6, 0.2), mat("Petal Orange", Color(1.0, 0.6, 0.25), 0.6, 0.2),
		mat("Petal Yellow", Color(1.0, 0.9, 0.3), 0.6, 0.2)]
	var g := Node3D.new()
	g.name = "Jungle"
	world.add_child(g)
	var palms := 0
	var tries := 0
	while palms < 42 and tries < 1500:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(57.0, shore_r(a) - 9.0)
		if _blocked(p, 3.0) or not _inland(p, 3.0):
			continue
		_palm(p, PALMS.size() + palms)
		ridge_rocks.append(Vector4(p.x, p.z, 1.0, 5.0))      # (so nothing else grows into it)
		palms += 1
	var bushes := 0
	tries = 0
	while bushes < 150 and tries < 2500:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(56.0, shore_r(a) - 7.0)
		if _blocked(p, 1.0) or not _inland(p, 1.0):
			continue
		bushes += 1
		var b := Node3D.new()
		b.name = "Bush"
		b.position = p
		g.add_child(b)
		for k in rng.randi_range(2, 4):
			var s := mesh_at(ball(rng.randf_range(0.6, 1.1), 8), leafy[(bushes + k) % 3], Vector3(rng.randf_range(-0.7, 0.7),
				0.4, rng.randf_range(-0.7, 0.7)), b)
			s.scale = Vector3(1.2, rng.randf_range(0.7, 1.1), 1.2)
		if bushes % 3 == 0:
			# A big tropical leaf or two, fanned out
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
	# Out on the island: the ridge, the grove, the overlook, the pier, the way in and the paths
	for rk: Vector4 in ridge_rocks:
		if flat.distance_to(Vector2(rk.x, rk.y)) < rk.z + 2.0 + room:
			return true
	for c in [[GROVE, GROVE_R + 1.0], [OVERLOOK, 8.0], [ARRIVE, 7.0], [WAY_HOME, 6.0], [TIME_STONE, 3.0], [GATE, 5.0],
			[PAVILION, 7.5], [CAVE, CAVE_R + 2.0], [HUTS[0], 4.0], [HUTS[1], 4.0], [HUTS[2], 4.0], [_hut_ramp_mid(), 6.0],
			[(HUTS[0] + HUTS[1]) / 2.0, 3.0], [(HUTS[1] + HUTS[2]) / 2.0, 3.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	if p.z > 40.0 and absf(p.x - PIER_X) < PIER_W / 2.0 + 1.5 + room:
		return true
	for path in paths:
		var pa := Vector2(path[0].x, path[0].z)
		var pb := Vector2(path[1].x, path[1].z)
		var u := clampf((flat - pa).dot(pb - pa) / (pb - pa).length_squared(), 0.0, 1.0)
		if flat.distance_to(pa.lerp(pb, u)) < float(path[2]) + 1.5 + room:
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
