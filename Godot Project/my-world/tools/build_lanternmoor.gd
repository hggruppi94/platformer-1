extends SceneTree

# Builds res://scenes/portal_worlds/lanternmoor.tscn: Lanternmoor, Pip's home world (plan item 19a world 3). A soft
# moor under a violet night sky, full of glowing moths and lantern trees, where the sun won't rise: the Dawn Snatcher,
# a big Time Goblin, caught the dawn and shut it in the clock he wears as a hat. Three beacons call the dawn back:
#   Beacon1  at the end of the Night Path (west): light the five lanterns along the path
#   Beacon2  on Moon Rock (east), a tall rock too far to jump to: climb the Tall Lantern Tree's steps and glide across
#            on the moth wings Pip lends you
#   Beacon3  in the middle of the Lantern Grove (north-west): its light ran away as three little runaway lights that
#            flit off when you come near; catch them
# With all three lit, the Dawn Snatcher wakes on Sunrise Hill (north) when you come near. Pop him and the dawn comes up.
# Logic: scripts/lanternmoor.gd (on scripts/portal_world.gd), which makes the lanterns, beacons, runaway lights, Pip,
# the Dawn Snatcher, the stars and the moths at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_lanternmoor.gd

const OUT := "res://scenes/portal_worlds/lanternmoor.tscn"
const FLOOR_R := 48.0                    # the moor's edge, where the dark hills rise
const PATH := [Vector3(-6, 0, 20), Vector3(-14, 0, 17), Vector3(-21, 0, 12), Vector3(-27, 0, 6), Vector3(-30, 0, -1)]
const BEACON1 := Vector3(-33, 0, -7)     # the end of the Night Path
const LAUNCH := Vector3(10, 0, -4)       # the Tall Lantern Tree: steps spiral up to a platform at LAUNCH_TOP
const LAUNCH_TOP := 9.0
const LAUNCH_R := 2.4
const STEP_COUNT := 8
const ISLAND := Vector3(32, 0, -20)      # Moon Rock: sheer sides, too far to jump to, a glide away from the tree
const ISLAND_TOP := 6.5
const ISLAND_R := 3.2
const GROVE := Vector3(-16, 0, -26)      # the Lantern Grove, where the runaway lights flit about
const GROVE_R := 10.0
const HILL := Vector3(4, 0, -38)         # Sunrise Hill: the Dawn Snatcher's dais
const HILL_R := 6.5
const HILL_TOP := 0.6

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}                         # shared meshes, so the scene file stays small


func _initialize() -> void:
	rng.seed = 31
	world = Node3D.new()
	world.name = "Lanternmoor"
	world.set_script(load("res://scripts/lanternmoor.gd"))
	world.set("world_id", "lanternmoor")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 34.0)
	_environment()
	_floor()
	_edge()
	_night_path()
	_launch_tree()
	_moon_rock()
	_grove()
	_hill()
	_lantern_trees()
	_flowers()
	for i in PATH.size():
		_marker("Lantern%d" % (i + 1), PATH[i] + Vector3(1.6 if i % 2 == 0 else -1.6, 0, 0))
	_marker("Beacon1", BEACON1)
	_marker("Beacon2", ISLAND + Vector3(0, ISLAND_TOP, 0))
	_marker("Beacon3", GROVE)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		_marker("Light%d" % (i + 1), GROVE + Vector3(cos(a) * 5.5, 1.2, sin(a) * 5.5))
	_marker("Launch", LAUNCH + Vector3(0, LAUNCH_TOP, 0))
	_marker("Snatcher", HILL + Vector3(0, HILL_TOP + 0.3, 0))
	_marker("SunRise", Vector3(60, 34, -110))          # where the dawn floats off to, low in the north-east sky
	_marker("Moon", Vector3(-70, 80, -120))
	_marker("Pip", Vector3(4.0, 0, 25.0)).rotation.y = atan2(-4.0, -25.0) + PI
	_marker("TimeStone", Vector3(8.0, 0, 30))
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(-8.0, 0, 31)).rotation.y = atan2(8.0, -31.0)
	_marker("Vein1", Vector3(22, 0, 14))
	_marker("PreviewCentre", Vector3(0, 3, -8))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 32))      # facing in, towards the moor (-Z)
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
	h = snappedf(h, 0.1)
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
	# A soft violet night (scripts/lanternmoor.gd brightens it to dawn once the world's mended)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.1, 0.06, 0.24)
	sky_mat.sky_horizon_color = Color(0.36, 0.22, 0.5)
	sky_mat.ground_horizon_color = Color(0.36, 0.22, 0.5)     # (the same as the sky's: no dark band under the hills)
	sky_mat.ground_bottom_color = Color(0.3, 0.18, 0.42)
	sky_mat.sun_angle_max = 10.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.38, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6                     # the lanterns and moths should bloom softly
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.22, 0.5)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	# Moonlight: pale lilac, from the moon's side, enough to see the moor by
	var moon := DirectionalLight3D.new()
	moon.name = "Sun"                            # (the dawn takes this light over: scripts/lanternmoor.gd)
	moon.light_color = Color(0.7, 0.68, 1.0)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-42, -30, 0)
	world.add_child(moon)


func _floor() -> void:
	# The moor: a wide round floor of dark heather with softer, lighter patches of moss
	var g := Node3D.new()
	g.name = "Moor"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 6.0, FLOOR_R + 6.0, 1.0, 48), mat("Heather", Color(0.15, 0.17, 0.3), 0.95), Vector3(0, -0.5, 0), g)
	cyl_solid(FLOOR_R + 6.0, 1.0, Vector3(0, -0.5, 0), g)
	var moss := mat("Moss", Color(0.18, 0.26, 0.3), 0.95)
	for k in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 6.0)
		var r := rng.randf_range(1.5, 4.0)
		mesh_at(cyl(r, r, 0.04, 16), moss, Vector3(cos(a) * d, 0.02, sin(a) * d), g)


func _edge() -> void:
	# Soft dark hills round the edge, a little misty, with an invisible fence between them so nobody wanders off
	var g := Node3D.new()
	g.name = "Hills"
	world.add_child(g)
	var hill := mat("Hill", Color(0.13, 0.1, 0.22), 0.95)
	var top := mat("Hill Heather", Color(0.24, 0.17, 0.34), 0.95)
	for k in 26:
		var a := k * TAU / 26.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(8.0, 12.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(4.0, 8.0))
		var h := mesh_at(ball(1.0, 16), hill, p, g)
		h.scale = Vector3(r, rng.randf_range(5.0, 11.0), r)
		var cap := mesh_at(ball(1.0, 12), top, p + Vector3(0, h.scale.y * 0.82, 0), g)
		cap.scale = Vector3(r * 0.5, h.scale.y * 0.22, r * 0.5)
	for k in 52:
		var a := k * TAU / 52.0
		var b := BoxShape3D.new()
		b.size = Vector3(6.2, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _night_path() -> void:
	# The Night Path: pale stepping stones winding west from the way in to the first beacon
	var g := Node3D.new()
	g.name = "Night Path"
	world.add_child(g)
	var stone := mat("Path Stone", Color(0.55, 0.5, 0.68), 0.9)
	var pts: Array = [Vector3(0, 0, 27)] + PATH + [BEACON1]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := int(a.distance_to(b) / 1.4)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n) + Vector3(rng.randf_range(-0.3, 0.3), 0.03, rng.randf_range(-0.3, 0.3))
			mesh_at(cyl(0.45, 0.5, 0.06, 8), stone, p, g, Vector3(0, rng.randf() * TAU, 0))
	# The beacon's base: a ring of standing stones round it
	var ring := mat("Standing Stone", Color(0.32, 0.28, 0.42), 0.9)
	for k in 6:
		var a := k * TAU / 6.0
		var p := BEACON1 + Vector3(cos(a), 0, sin(a)) * 3.6
		mesh_at(box(Vector3(0.7, 2.2, 0.5)), ring, p + Vector3(0, 1.1, 0), g, Vector3(0, -a, 0))
		var b := BoxShape3D.new()
		b.size = Vector3(0.7, 2.2, 0.5)
		solid(b, p + Vector3(0, 1.1, 0), g, Vector3(0, -a, 0))


func _launch_tree() -> void:
	# The Tall Lantern Tree: a huge twisty trunk with lantern-pod steps spiralling up it to a round platform at the top,
	# looking out east to Moon Rock
	var g := Node3D.new()
	g.name = "Tall Lantern Tree"
	world.add_child(g)
	g.position = LAUNCH
	var bark := mat("Bark", Color(0.2, 0.13, 0.22), 0.9)
	var pad := mat("Pod Pad", Color(0.42, 0.3, 0.6), 0.7)
	var glow := mat("Pod Glow", Color(1.0, 0.7, 0.4), 0.4, 1.1)
	mesh_at(cyl(1.0, 1.5, LAUNCH_TOP, 12), bark, Vector3(0, LAUNCH_TOP / 2.0, 0), g)
	cyl_solid(1.2, LAUNCH_TOP, Vector3(0, LAUNCH_TOP / 2.0, 0), g)
	for k in STEP_COUNT:
		var a := k * 0.9 + PI                    # starting on the side facing the way in
		var y := (k + 1) * LAUNCH_TOP / (STEP_COUNT + 1)
		var p := Vector3(cos(a) * 2.5, y, sin(a) * 2.5)
		mesh_at(cyl(1.1, 0.9, 0.3, 14), pad, p, g)
		mesh_at(ball(0.18, 8), glow, p + Vector3(0, -0.35, 0), g)
		cyl_solid(1.1, 0.3, p, g)
	# The top: a wide, flat crown of leaves to stand on, with a lantern at its edge pointing the way
	mesh_at(cyl(LAUNCH_R, LAUNCH_R - 0.3, 0.4, 20), pad, Vector3(0, LAUNCH_TOP + 0.2, 0), g)
	cyl_solid(LAUNCH_R, 0.4, Vector3(0, LAUNCH_TOP + 0.2, 0), g)
	var leaves := mat("Lantern Leaves", Color(0.32, 0.2, 0.46), 0.85)
	for k in 7:
		var a := k * TAU / 7.0
		var leaf := mesh_at(ball(1.0, 10), leaves, Vector3(cos(a) * (LAUNCH_R + 0.6), LAUNCH_TOP + 0.1, sin(a) * (LAUNCH_R + 0.6)), g)
		leaf.scale = Vector3(1.2, 0.2, 0.7)
		leaf.rotation.y = -a
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.5)
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = Vector3(0, LAUNCH_TOP + 1.5, 0)
	g.add_child(light)


func _moon_rock() -> void:
	# Moon Rock: a tall pillar of pale stone, sheer all round (too tall to climb, too far to jump to), soft moss on top
	var g := Node3D.new()
	g.name = "Moon Rock"
	world.add_child(g)
	g.position = ISLAND
	var rock := mat("Moon Stone", Color(0.6, 0.58, 0.75), 0.9)
	var moss := mat("Moss", Color(0.18, 0.26, 0.3), 0.95)
	mesh_at(cyl(ISLAND_R, ISLAND_R + 0.6, ISLAND_TOP, 14), rock, Vector3(0, ISLAND_TOP / 2.0, 0), g)
	cyl_solid(ISLAND_R, ISLAND_TOP, Vector3(0, ISLAND_TOP / 2.0, 0), g)
	mesh_at(cyl(ISLAND_R - 0.1, ISLAND_R, 0.1, 14), moss, Vector3(0, ISLAND_TOP + 0.03, 0), g)
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var lump := mesh_at(ball(1.0, 10), rock, Vector3(cos(a) * (ISLAND_R + 0.2), rng.randf_range(1.0, ISLAND_TOP - 1.5), sin(a) * (ISLAND_R + 0.2)), g)
		lump.scale = Vector3(1.2, 1.6, 1.2)


func _grove() -> void:
	# The Lantern Grove: a ring of little lantern trees with gaps to walk in through, and a beacon in the middle.
	# The runaway lights stay inside its ring (scripts/lanternmoor.gd GROVE_R).
	var g := Node3D.new()
	g.name = "Lantern Grove"
	world.add_child(g)
	g.position = GROVE
	for k in 10:
		if k % 3 == 1:
			continue                              # gaps to walk in through
		var a := k * TAU / 10.0
		_tree(g, Vector3(cos(a), 0, sin(a)) * (GROVE_R + 1.0), rng.randf_range(0.8, 1.1), k)
	var flat := mat("Grove Moss", Color(0.22, 0.3, 0.38), 0.9)
	mesh_at(cyl(GROVE_R, GROVE_R, 0.03, 32), flat, Vector3(0, 0.02, 0), g)


func _hill() -> void:
	# Sunrise Hill: a low round dais of pale stone with a sundial ring, where the Dawn Snatcher sleeps
	var g := Node3D.new()
	g.name = "Sunrise Hill"
	world.add_child(g)
	g.position = HILL
	mesh_at(cyl(HILL_R, HILL_R + 0.5, HILL_TOP, 32), mat("Dais Stone", Color(0.5, 0.45, 0.62), 0.85), Vector3(0, HILL_TOP / 2.0, 0), g)
	cyl_solid(HILL_R + 0.25, HILL_TOP, Vector3(0, HILL_TOP / 2.0, 0), g)
	var gold := mat("Sundial Gold", Color(0.9, 0.7, 0.4), 0.4, 0.4, 1.0, 0.6)
	for k in 12:
		var a := k * TAU / 12.0
		mesh_at(box(Vector3(0.25, 0.04, 0.9 if k % 3 == 0 else 0.5)), gold, Vector3(cos(a), 0, sin(a)) * (HILL_R - 0.8) + Vector3(0, HILL_TOP + 0.02, 0), g, Vector3(0, -a, 0))


func _tree(parent: Node3D, at: Vector3, s: float, k: int) -> void:
	# One lantern tree: a dark twisty trunk with two bent branches, round leaf puffs and glowing lantern pods hanging
	var g := Node3D.new()
	g.name = "Lantern Tree"
	g.position = at
	parent.add_child(g)
	var bark := mat("Bark", Color(0.2, 0.13, 0.22), 0.9)
	var leaves := mat("Lantern Leaves", Color(0.32, 0.2, 0.46), 0.85)
	var pods := [mat("Pod Glow", Color(1.0, 0.7, 0.4), 0.4, 1.1), mat("Pod Pink", Color(1.0, 0.5, 0.78), 0.4, 1.1),
		mat("Pod Blue", Color(0.5, 0.72, 1.0), 0.4, 1.1)]
	mesh_at(cyl(0.22 * s, 0.38 * s, 3.2 * s, 8), bark, Vector3(0, 1.6 * s, 0), g)
	cyl_solid(0.35 * s, 3.2 * s, Vector3(0, 1.6 * s, 0), g)
	for b in 2:
		var a := rng.randf() * TAU
		var arm := mesh_at(cyl(0.08 * s, 0.14 * s, 1.6 * s, 6), bark, Vector3(cos(a) * 0.5 * s, 3.0 * s, sin(a) * 0.5 * s), g)
		arm.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)
		var puff := mesh_at(ball(1.0, 10), leaves, Vector3(cos(a) * 1.1 * s, 3.7 * s, sin(a) * 1.1 * s), g)
		puff.scale = Vector3(1.1, 0.7, 1.1) * s
		var pod := mesh_at(ball(0.22, 10), pods[(k + b) % pods.size()], Vector3(cos(a) * 1.3 * s, 2.7 * s, sin(a) * 1.3 * s), g)
		pod.scale = Vector3(1.0, 1.3, 1.0)
	var top := mesh_at(ball(1.0, 10), leaves, Vector3(0, 3.8 * s, 0), g)
	top.scale = Vector3(1.4, 0.9, 1.4) * s


func _lantern_trees() -> void:
	# Lantern trees dotted over the moor (kept off the paths, the tree, the rock, the grove and the hill), a few
	# carrying a real light so the moor glows in pools
	var g := Node3D.new()
	g.name = "Lantern Trees"
	world.add_child(g)
	var placed := 0
	var tries := 0
	while placed < 24 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, FLOOR_R - 5.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(p, 3.0):
			continue
		_tree(g, p, rng.randf_range(0.9, 1.4), placed)
		if placed % 4 == 0:
			var light := OmniLight3D.new()
			light.light_color = [Color(1.0, 0.75, 0.5), Color(1.0, 0.6, 0.85), Color(0.6, 0.75, 1.0)][placed % 3]
			light.light_energy = 0.9
			light.omni_range = 6.0
			light.position = p + Vector3(0, 2.8, 0)
			g.add_child(light)
		placed += 1


func _blocked(p: Vector3, room: float) -> bool:
	var flat := Vector2(p.x, p.z)
	var pts: Array = [Vector3(0, 0, 27)] + PATH + [BEACON1]
	for q in pts:
		if flat.distance_to(Vector2(q.x, q.z)) < 3.5 + room:
			return true
	for c in [[LAUNCH, 4.0], [ISLAND, ISLAND_R + 2.0], [GROVE, GROVE_R + 2.0], [HILL, HILL_R + 2.0],
			[Vector3(0, 0, 28), 9.0], [Vector3(22, 0, 14), 2.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	# Keep the glide line from the tree to Moon Rock clear too
	var a := Vector2(LAUNCH.x, LAUNCH.z)
	var b := Vector2(ISLAND.x, ISLAND.z)
	var t := clampf((flat - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return flat.distance_to(a.lerp(b, t)) < 3.0 + room


func _flowers() -> void:
	# Little glowing night flowers in clumps over the moor (no collision)
	var g := Node3D.new()
	g.name = "Night Flowers"
	world.add_child(g)
	var stem := mat("Flower Stem", Color(0.2, 0.3, 0.3), 0.9)
	var petals := [mat("Petal Blue", Color(0.5, 0.75, 1.0), 0.5, 1.0), mat("Petal Pink", Color(1.0, 0.6, 0.85), 0.5, 1.0),
		mat("Petal Gold", Color(1.0, 0.85, 0.5), 0.5, 1.0)]
	for c in 30:
		var a := rng.randf() * TAU
		var d := rng.randf_range(5.0, FLOOR_R - 4.0)
		var centre := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(centre, 0.0):
			continue
		for k in 5:
			var p := centre + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
			mesh_at(cyl(0.02, 0.02, 0.4, 4), stem, p + Vector3(0, 0.2, 0), g)
			mesh_at(ball(0.07, 6), petals[(c + k) % 3], p + Vector3(0, 0.42, 0), g)
