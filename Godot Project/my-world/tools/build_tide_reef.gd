extends SceneTree

# Builds res://scenes/portal_worlds/tide_reef.tscn: the Tide Reef, the octopus's home world (plan item 19a world 5).
# A reef city of coral houses and bubble lamps that should be under the sea, but the tide is stuck out: the sea bed is
# bare and cracking, the tide pools are dry, the corals are going pale and a boat lies on its side in the sand. Otto the
# octopus (working name) floats about in a bubble chair he blew himself, which only drifts along when a friend goes
# with him, and thinks he's no use to anyone. Three Tide Pearls call the tide back, and each needs something only Otto
# can do:
#   Pearl1  in the Clam Vault (west): eight latches that all have to turn at once. Eight arms
#   Pearl2  deep in the Kelp Grotto (east): three holes far too deep to reach into. You're the eyes, Otto's the reach
#   Pearl3  on top of the Coral Spire (north-west): Otto blows bubble steps up it (each pops a moment after you land on
#           it), and you ride one of his bubbles back down
# With all three, the Riptide Gloop, who swallowed the tide, wakes in the Deep Basin (north).
# Logic: scripts/tide_reef.gd (on scripts/portal_world.gd) and scripts/riptide_gloop.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_tide_reef.gd

const OUT := "res://scenes/portal_worlds/tide_reef.tscn"
const FLOOR_R := 48.0
const WATER_Y := 0.3                         # the tide pools are shallow once the tide's back: you wade in them
const VAULT := Vector3(-30, 0, 8)            # the Clam Vault (its mouth faces east, towards the middle)
const GROTTO := Vector3(33, 0, 4)            # the Kelp Grotto: a rock with three holes in its west face
const SPIRE := Vector3(-23, 0, -19)          # the Coral Spire
const SPIRE_R := 3.2
const SPIRE_TOP := 10.0
const STEPS := 8                             # Otto's bubble steps up the spire
const STEP_START := 0.5                      # angle round the spire of the first step (the side facing the middle)
const STEP_TURN := -0.56
const BASIN := Vector3(0, 0, -30)            # the Deep Basin, where the Riptide Gloop sits
const BASIN_R := 10.0
# The tide pools (dry beds until the tide's back): centre x, centre z, radius x, radius z (scripts/water.gd ellipses).
# The first is the Deep Basin.
const POOLS := [Vector4(0, -30, 10, 8), Vector4(0, 9, 6, 4), Vector4(-16, 20, 4, 3), Vector4(18, 21, 4, 3.5),
	Vector4(17, -10, 4.5, 3.5), Vector4(-9, -5, 3.5, 3)]
# Coral houses: x, z, size, which colour
const HOUSES := [Vector4(-10.5, 14, 1.0, 0), Vector4(8.5, 14.5, 1.15, 1), Vector4(-18, 2, 1.2, 2), Vector4(11, 0, 1.0, 3),
	Vector4(26, -22, 1.1, 4), Vector4(-36, -6, 1.0, 1), Vector4(22, 32, 0.9, 2), Vector4(-26, 30, 1.0, 3),
	Vector4(38, -8, 0.95, 0), Vector4(-6.5, -15, 0.9, 4)]
const CORALS := [Color(1.0, 0.45, 0.6), Color(1.0, 0.6, 0.3), Color(0.7, 0.5, 1.0), Color(1.0, 0.85, 0.35),
	Color(0.3, 0.85, 0.8)]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}


func _initialize() -> void:
	rng.seed = 58
	world = Node3D.new()
	world.name = "TideReef"
	world.set_script(load("res://scripts/tide_reef.gd"))
	world.set("world_id", "tide_reef")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 36.0)
	_environment()
	_floor()
	_edge()
	_pools()
	for i in HOUSES.size():
		_house(HOUSES[i], i)
	_lamps()
	_vault()
	_grotto()
	_spire()
	_ride()
	_basin()
	_corals()
	_wreck()
	_marker("Otto", Vector3(5.0, 0, 27.0)).rotation.y = atan2(-5.0, 9.0)
	_marker("OttoPerch", BASIN + Vector3(9.5, 0, 11.5))
	_marker("TimeStone", Vector3(8.0, 0, 33))
	_marker("WayHome", Vector3(-8.0, 0, 33)).rotation.y = atan2(8.0, -33.0)
	_marker("Vein1", Vector3(-22, 0, 25))
	_marker("PreviewCentre", Vector3(0, 3, -6))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 36))
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


func coral(k: int) -> StandardMaterial3D:
	# The reef's living colours. Their names start with "Coral": scripts/tide_reef.gd fades those pale while the tide's
	# out and blooms them back when it comes in.
	return mat("Coral %d" % (k % CORALS.size()), CORALS[k % CORALS.size()], 0.7)


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
	# The tide's out: a hazy, dusty, dried-out sky the colour of old sand, and a flat pale sun (scripts/tide_reef.gd
	# clears it to a bright sea-blue once the tide's back)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.62, 0.68, 0.7)
	sky_mat.sky_horizon_color = Color(0.92, 0.85, 0.7)
	sky_mat.ground_horizon_color = Color(0.92, 0.85, 0.7)
	sky_mat.ground_bottom_color = Color(0.7, 0.62, 0.5)
	sky_mat.sun_angle_max = 14.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.9, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.84, 0.7)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48, 35, 0)
	world.add_child(sun)


func _floor() -> void:
	# The bare sea bed: pale sand with ripple marks, darker damp patches and shell-paved paths from the way in
	var g := Node3D.new()
	g.name = "Sea Bed"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 6.0, FLOOR_R + 6.0, 1.0, 48), mat("Sea Sand", Color(0.86, 0.78, 0.6), 0.95), Vector3(0, -0.5, 0), g)
	cyl_solid(FLOOR_R + 6.0, 1.0, Vector3(0, -0.5, 0), g)
	var damp := mat("Damp Sand", Color(0.74, 0.68, 0.54), 0.9)
	for k in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 6.0)
		var r := rng.randf_range(1.5, 4.0)
		var p := Vector3(cos(a) * d, 0.02, sin(a) * d)
		if _blocked(p, r):
			continue
		mesh_at(cyl(r, r, 0.04, 16), damp, p, g)
	# Ripple marks the sea left behind
	var ripple := mat("Sand Ripple", Color(0.92, 0.85, 0.68), 0.95)
	for k in 46:
		var a := rng.randf() * TAU
		var d := rng.randf_range(5.0, FLOOR_R - 5.0)
		var p := Vector3(cos(a) * d, 0.03, sin(a) * d)
		if _blocked(p, 1.2):
			continue
		var r := mesh_at(box(Vector3(2.4, 0.05, 0.16)), ripple, p, g, Vector3(0, 0.35 + rng.randf_range(-0.15, 0.15), 0))
		r.scale.x = rng.randf_range(0.6, 1.3)
	var shell := mat("Path Shell", Color(0.98, 0.9, 0.86), 0.6)
	var shell2 := mat("Path Shell Pink", Color(1.0, 0.78, 0.8), 0.6)
	var start := Vector3(0, 0, 30)
	for to in [VAULT + Vector3(5, 0, 0), GROTTO + Vector3(-7, 0, 0), SPIRE + Vector3(7, 0, 5), BASIN + Vector3(0, 0, BASIN_R + 1.0)]:
		var n := int(start.distance_to(to) / 1.4)
		for k in n:
			var p: Vector3 = start.lerp(to, (k + 0.5) / n)
			if _in_pool(p, 0.5):
				continue
			var s := mesh_at(ball(0.45, 8), shell if k % 3 else shell2, p + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)), g)
			s.scale = Vector3(1.0, 0.14, 0.8)
			s.rotation.y = rng.randf() * TAU


func _edge() -> void:
	# Tall reef walls round the edge (grey rock with pale corals growing up it), and an invisible fence
	var g := Node3D.new()
	g.name = "Reef Walls"
	world.add_child(g)
	var rocks := [mat("Reef Rock", Color(0.5, 0.52, 0.58), 0.9), mat("Reef Rock Dark", Color(0.4, 0.42, 0.5), 0.9),
		mat("Reef Rock Pale", Color(0.62, 0.62, 0.66), 0.9)]
	for k in 30:
		var a := k * TAU / 30.0 + rng.randf_range(-0.04, 0.04)
		var r := rng.randf_range(6.0, 10.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(4.0, 8.0))
		var h := rng.randf_range(6.0, 13.0)
		var rock := mesh_at(cyl(r * 0.55, r, h, 9), rocks[k % 3], p + Vector3(0, h / 2.0, 0), g)
		rock.rotation.y = rng.randf() * TAU
		# A big coral or two growing on top
		for c in 2:
			var top := p + Vector3(rng.randf_range(-2.0, 2.0), h, rng.randf_range(-2.0, 2.0))
			var cb := mesh_at(ball(1.6, 10), coral(k + c), top, g)
			cb.scale = Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.4))
	for k in 52:
		var a := k * TAU / 52.0
		var b := BoxShape3D.new()
		b.size = Vector3(6.2, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _pools() -> void:
	# The tide pools. While the tide's out each is a dry, cracked bed; scripts/tide_reef.gd brings the water back up
	# (the "Surface" of each) when the world's mended, and only then gives the node its outline, so you wade
	# (scripts/water.gd).
	var g := Node3D.new()
	g.name = "Tide Pools"
	g.set_script(load("res://scripts/water.gd"))
	g.set("water_y", WATER_Y)
	var beds: Array = []
	for p in POOLS:
		beds.append(p)
	g.set_meta("beds", beds)
	world.add_child(g)
	var water := mat("Tide Water", Color(0.3, 0.75, 0.9), 0.1, 0.25, 0.8)
	var bed := mat("Dry Bed", Color(0.7, 0.66, 0.56), 0.95)
	var crack := mat("Bed Crack", Color(0.45, 0.4, 0.34), 0.95)
	var pebble := mat("Pool Pebble", Color(0.9, 0.88, 0.84), 0.8)
	for i in POOLS.size():
		var e: Vector4 = POOLS[i]
		var holder := Node3D.new()
		holder.name = "Pool%d" % (i + 1)
		holder.position = Vector3(e.x, 0, e.y)
		g.add_child(holder)
		var bm := mesh_at(cyl(1.0, 1.0, 0.04, 32), bed, Vector3(0, 0.03, 0), holder)
		bm.scale = Vector3(e.z, 1, e.w)
		var cracks := Node3D.new()
		cracks.name = "Cracks"
		holder.add_child(cracks)
		for k in int(e.z * e.w * 0.55):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 0.85
			var c := mesh_at(box(Vector3(rng.randf_range(0.5, 1.4), 0.03, 0.07)), crack, Vector3(cos(a) * d * e.z, 0.06, sin(a) * d * e.w), cracks,
				Vector3(0, rng.randf() * TAU, 0))
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wm := mesh_at(cyl(1.0, 1.0, 0.04, 32), water, Vector3(0, WATER_Y, 0), holder)
		wm.scale = Vector3(e.z, 1, e.w)
		wm.name = "Surface"
		wm.visible = false
		var n := int((e.z + e.w) * 2.0)
		for k in n:
			var a := k * TAU / n
			var pb := mesh_at(ball(0.3, 8), pebble, Vector3(cos(a) * (e.z + 0.2), 0.1, sin(a) * (e.w + 0.2)), holder)
			pb.scale = Vector3(1.2, 0.55, 1.0)
		_marker("Tide%d" % (i + 1), Vector3(e.x, 0, e.y)).set_meta("radius", minf(e.z, e.w))


func _house(h: Vector4, k: int) -> void:
	# A coral house: a round dome with a round door, porthole windows, a wavy chimney of tube coral and a shell porch
	var g := Node3D.new()
	g.name = "Coral House %d" % (k + 1)
	g.position = Vector3(h.x, 0, h.y)
	g.rotation.y = atan2(-h.x, -h.y) + rng.randf_range(-0.3, 0.3)      # the door looks roughly at the middle of town
	world.add_child(g)
	var s := h.z
	var body := coral(int(h.w))
	var trim := mat("House Trim", Color(1.0, 0.95, 0.88), 0.6)
	var dome := mesh_at(ball(2.6, 16), body, Vector3(0, 1.2 * s, 0), g)
	dome.scale = Vector3(s, s * 0.95, s)
	cyl_solid(2.4 * s, 3.4 * s, Vector3(0, 1.7 * s, 0), g)
	# Little bumps of coral over the roof
	for b in 7:
		var a := b * TAU / 7.0 + k
		var bump := mesh_at(ball(0.55, 8), coral(int(h.w) + 1 + b % 2), Vector3(cos(a) * 1.5 * s, 3.2 * s, sin(a) * 1.5 * s), g)
		bump.scale = Vector3(1, 0.7, 1) * s
	var door := mesh_at(cyl(0.75, 0.75, 0.2, 16), mat("House Door", Color(0.35, 0.5, 0.75), 0.6), Vector3(0, 0.95 * s, 2.45 * s), g, Vector3(PI / 2.0, 0, 0))
	door.scale = Vector3(s, 1, s)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.72
	rim.outer_radius = 0.92
	var dr := mesh_at(rim, trim, Vector3(0, 0.95 * s, 2.52 * s), g, Vector3(PI / 2.0, 0, 0))
	dr.scale = Vector3(s, 1, s)
	mesh_at(ball(0.1, 6), mat("Pearl Knob", Color(1.0, 0.95, 0.9), 0.3, 0.3), Vector3(0.4 * s, 0.95 * s, 2.62 * s), g)
	var glass := mat("Porthole", Color(1.0, 0.9, 0.55), 0.3, 0.9)
	for side in [-1.0, 1.0]:
		var a: float = side * 0.75
		var at := Vector3(sin(a) * 2.5 * s, 1.7 * s, cos(a) * 2.5 * s)
		mesh_at(cyl(0.38 * s, 0.38 * s, 0.2, 12), glass, at, g, Vector3(PI / 2.0, a, 0))
		var wr := TorusMesh.new()
		wr.inner_radius = 0.36 * s
		wr.outer_radius = 0.48 * s
		mesh_at(wr, trim, at * 1.02, g, Vector3(PI / 2.0, a, 0))
	# The chimney: three tubes of coral
	for c in 3:
		var hh := (1.6 - c * 0.35) * s
		mesh_at(cyl(0.2 * s, 0.26 * s, hh, 8), coral(int(h.w) + 2), Vector3((-0.9 + c * 0.4) * s, 3.2 * s + hh / 2.0, -0.6 * s), g)
	# A scallop shell for a doorstep
	var step := mesh_at(ball(1.0, 10), trim, Vector3(0, 0.05, 3.3 * s), g)
	step.scale = Vector3(1.2 * s, 0.12, 0.9 * s)


func _lamps() -> void:
	# Bubble lamps: a glass bubble glowing on a curly post of driftwood, along the paths
	var g := Node3D.new()
	g.name = "Bubble Lamps"
	world.add_child(g)
	var post := mat("Lamp Post", Color(0.75, 0.68, 0.6), 0.8)
	var glow := mat("Lamp Bubble", Color(0.65, 0.95, 1.0), 0.1, 1.1, 0.75)
	var spots := [Vector3(-3.5, 0, 26), Vector3(3.5, 0, 20), Vector3(-5, 0, 15), Vector3(-14, 0, 12), Vector3(-22, 0, 9),
		Vector3(14, 0, 12), Vector3(24, 0, 7), Vector3(-8, 0, 3), Vector3(-15, 0, -8), Vector3(3.5, 0, -6), Vector3(-3.5, 0, -17),
		Vector3(12, 0, -17)]
	for k in spots.size():
		var at: Vector3 = spots[k]
		if _in_pool(at, 0.8):
			continue
		mesh_at(cyl(0.07, 0.1, 2.6, 6), post, at + Vector3(0, 1.3, 0), g)
		mesh_at(ball(0.42, 12), glow, at + Vector3(0, 2.95, 0), g).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k % 3 == 0:
			var light := OmniLight3D.new()
			light.light_color = Color(0.65, 0.95, 1.0)
			light.light_energy = 0.8
			light.omni_range = 6.0
			light.position = at + Vector3(0, 2.9, 0)
			g.add_child(light)


func _vault() -> void:
	# The Clam Vault: a giant clam with its mouth to the east, shut tight by eight barnacle latches along its lip. Its
	# top shell (the "Lid") is hinged at the back: scripts/tide_reef.gd swings it up when Otto turns all eight at once.
	var g := Node3D.new()
	g.name = "Clam Vault"
	g.position = VAULT
	world.add_child(g)
	var outside := mat("Clam Shell", Color(0.85, 0.8, 0.9), 0.6)
	var inside := mat("Clam Inside", Color(1.0, 0.82, 0.86), 0.4, 0.15)
	var rib := mat("Clam Rib", Color(0.72, 0.66, 0.82), 0.6)
	var bottom := mesh_at(ball(1.0, 20), outside, Vector3(0, 0.35, 0), g)
	bottom.scale = Vector3(3.2, 0.75, 2.9)
	var lining := mesh_at(cyl(1.0, 1.0, 0.06, 28), inside, Vector3(0, 0.82, 0), g)
	lining.scale = Vector3(2.8, 1, 2.5)
	cyl_solid(2.9, 0.85, Vector3(0, 0.42, 0), g)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(-2.9, 0.85, 0)                          # the hinge, at the back
	g.add_child(lid)
	var top := mesh_at(ball(1.0, 20), outside, Vector3(2.9, 0.25, 0), lid)
	top.scale = Vector3(3.2, 1.1, 2.9)
	var under := mesh_at(cyl(1.0, 1.0, 0.06, 28), inside, Vector3(2.9, 0.02, 0), lid)
	under.scale = Vector3(2.8, 1, 2.5)
	for k in 7:
		var a := lerpf(-1.1, 1.1, k / 6.0)
		var r := mesh_at(box(Vector3(5.4, 0.14, 0.22)), rib, Vector3(2.9, 1.2 - absf(a) * 0.35, sin(a) * 2.2), lid, Vector3(0, -a * 0.35, 0))
		r.scale.x = 1.0 - absf(a) * 0.3
	# The eight latches along the front lip: barnacle knobs, dull until turned
	var latch := mat("Latch", Color(0.5, 0.5, 0.56), 0.5, 0.0, 1.0, 0.4)
	for k in 8:
		var a := lerpf(-1.25, 1.25, k / 7.0)
		var l := mesh_at(cyl(0.16, 0.24, 0.3, 8), latch, Vector3(cos(a) * 3.15, 0.86, sin(a) * 2.85), g)
		l.name = "Latch%d" % (k + 1)
		mesh_at(box(Vector3(0.1, 0.1, 0.5)), latch, Vector3(0, 0.2, 0), l).name = "Handle"
	_marker("Vault", VAULT + Vector3(4.6, 0, 0))
	_marker("Pearl1", VAULT + Vector3(1.9, 0.9, 0))
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "The Clam Vault"
	sign.font_size = 44
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 3.6, 0)
	g.add_child(sign)


func _grotto() -> void:
	# The Kelp Grotto: a hump of dark rock hung with drying kelp, with three round holes in its west face. One of them
	# goes a long way in. scripts/tide_reef.gd puts a glint in one and blinking eyes in the others.
	var g := Node3D.new()
	g.name = "Kelp Grotto"
	g.position = GROTTO
	world.add_child(g)
	var rock := mat("Grotto Rock", Color(0.36, 0.38, 0.46), 0.95)
	var dark := mat("Grotto Hole", Color(0.05, 0.05, 0.1), 1.0)
	var rim := mat("Grotto Rim", Color(0.55, 0.56, 0.62), 0.9)
	var hump := mesh_at(ball(1.0, 16), rock, Vector3(1.5, 1.2, 0), g)
	hump.scale = Vector3(5.5, 4.6, 7.0)
	var face := mesh_at(box(Vector3(1.2, 3.4, 9.0)), rock, Vector3(-2.6, 1.7, 0), g)
	face.name = "Face"
	var b := BoxShape3D.new()
	b.size = Vector3(8.0, 5.0, 10.0)
	solid(b, Vector3(1.0, 2.5, 0), g)
	var kelp := mat("Dry Kelp", Color(0.5, 0.52, 0.3), 0.9)
	for k in 9:
		var z := lerpf(-4.0, 4.0, k / 8.0) + rng.randf_range(-0.2, 0.2)
		if absf(fmod(absf(z) + 0.6, 2.8) - 0.6) < 0.75:
			continue                                              # (not over a hole)
		var len := rng.randf_range(1.2, 2.2)
		mesh_at(box(Vector3(0.06, len, 0.35)), kelp, Vector3(-3.25, 3.3 - len / 2.0, z), g, Vector3(0, 0, rng.randf_range(-0.08, 0.08)))
	for i in 3:
		var z := (i - 1) * 2.8
		mesh_at(cyl(0.62, 0.62, 0.12, 16), dark, Vector3(-3.22, 1.15, z), g, Vector3(0, 0, PI / 2.0))
		var t := TorusMesh.new()
		t.inner_radius = 0.6
		t.outer_radius = 0.85
		mesh_at(t, rim, Vector3(-3.25, 1.15, z), g, Vector3(0, 0, PI / 2.0))
		var m := _marker("Hole%d" % (i + 1), GROTTO + Vector3(-3.3, 0, z))
		m.set_meta("height", 1.15)
	_marker("Grotto", GROTTO + Vector3(-6.0, 0, 0))
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "The Kelp Grotto"
	sign.font_size = 44
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(-3.0, 4.6, 0)
	g.add_child(sign)


func _step_at(i: int) -> Vector3:
	var a := STEP_START + i * STEP_TURN
	return SPIRE + Vector3(cos(a) * (SPIRE_R + 1.7), (i + 1) * SPIRE_TOP / (STEPS + 1), sin(a) * (SPIRE_R + 1.7))


func _spire() -> void:
	# The Coral Spire: a tall tower of coral in rings of colour with a flat top, far too smooth to climb. Markers for
	# Otto's bubble steps spiral up it (scripts/tide_reef.gd makes the bubbles), and the Bubble Pad is at its foot.
	var g := Node3D.new()
	g.name = "Coral Spire"
	world.add_child(g)
	var bands := 8
	for k in bands:
		var h := SPIRE_TOP / bands
		var r0 := SPIRE_R + 0.5 - k * 0.07
		mesh_at(cyl(r0 - 0.07, r0, h, 18), coral(k), SPIRE + Vector3(0, h * (k + 0.5), 0), g)
	cyl_solid(SPIRE_R, SPIRE_TOP, SPIRE + Vector3(0, SPIRE_TOP / 2.0, 0), g)
	mesh_at(cyl(SPIRE_R + 0.2, SPIRE_R + 0.2, 0.1, 18), mat("Spire Top", Color(1.0, 0.93, 0.86), 0.7), SPIRE + Vector3(0, SPIRE_TOP + 0.03, 0), g)
	for k in 10:
		var a := k * TAU / 10.0
		var knob := mesh_at(ball(0.4, 8), coral(k), SPIRE + Vector3(cos(a) * (SPIRE_R + 0.1), SPIRE_TOP + 0.1, sin(a) * (SPIRE_R + 0.1)), g)
		knob.scale = Vector3(1, 0.6, 1)
	for i in STEPS:
		_marker("Step%d" % (i + 1), _step_at(i))
	var first := _step_at(0)
	var out := Vector3(first.x - SPIRE.x, 0, first.z - SPIRE.z).normalized()
	var pad_at := Vector3(first.x, 0, first.z) + out * 2.6
	mesh_at(cyl(1.5, 1.6, 0.12, 20), mat("Bubble Pad", Color(0.6, 0.9, 1.0), 0.4, 0.3), pad_at + Vector3(0, 0.06, 0), g)
	_marker("BubblePad", pad_at)
	_marker("Pearl3", SPIRE + Vector3(-0.8, SPIRE_TOP + 0.1, -0.6))
	_marker("RideTop", SPIRE + Vector3(1.6, SPIRE_TOP + 0.1, 1.2))


func _ride() -> void:
	# The way a bubble floats down from the top of the spire: out over the town in a slow loop and down to the little
	# tide pool south-east of it. scripts/tide_reef.gd carries you along the BubbleRide path.
	var top := SPIRE + Vector3(1.6, SPIRE_TOP + 1.6, 1.2)
	var pts := [top, SPIRE + Vector3(6, SPIRE_TOP + 2.4, 4), Vector3(-8, 10.5, -22), Vector3(6, 8.5, -16), Vector3(10, 6.5, -4),
		Vector3(2, 4.8, 3), Vector3(-8, 3.2, 2), Vector3(-10, 1.9, -3), Vector3(-9, 1.25, -5)]
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
	path.name = "BubbleRide"
	path.curve = curve
	world.add_child(path)
	# A trail of little bubble rings to show the way
	var g := Node3D.new()
	g.name = "Ride Rings"
	world.add_child(g)
	var ring := mat("Ride Ring", Color(0.7, 0.95, 1.0), 0.2, 0.8, 0.7)
	var length := curve.get_baked_length()
	var d := 6.0
	while d < length - 4.0:
		var a := curve.sample_baked(d)
		var b := curve.sample_baked(d + 0.5)
		var t := TorusMesh.new()
		t.inner_radius = 1.5
		t.outer_radius = 1.65
		var r := mesh_at(t, ring, a, g)
		r.look_at_from_position(a, b, Vector3.UP)
		r.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d += 9.0


func _basin() -> void:
	# The Deep Basin, the reef's old harbour: a ring of mooring posts and an anchor round the biggest dry bed, where the
	# Riptide Gloop sits, swollen with the whole tide
	var g := Node3D.new()
	g.name = "Deep Basin"
	g.position = BASIN
	world.add_child(g)
	var post := mat("Mooring Post", Color(0.5, 0.4, 0.34), 0.9)
	var rope := mat("Mooring Rope", Color(0.85, 0.78, 0.6), 0.9)
	for k in 10:
		var a := k * TAU / 10.0 + 0.3
		var p := Vector3(cos(a) * (BASIN_R + 1.6), 0, sin(a) * (BASIN_R - 0.4))
		if p.z > BASIN_R - 3.5 and absf(p.x) < 4.0:
			continue                                              # (the way in from town stays open)
		mesh_at(cyl(0.22, 0.26, 1.5, 8), post, p + Vector3(0, 0.75, 0), g)
		mesh_at(cyl(0.3, 0.3, 0.14, 8), rope, p + Vector3(0, 1.15, 0), g)
		cyl_solid(0.26, 1.5, p + Vector3(0, 0.75, 0), g)
	_marker("RiptideGloop", BASIN + Vector3(0, 0.3, -1.0))
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "The Deep Basin"
	sign.font_size = 44
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.6, BASIN_R + 2.0)
	g.add_child(sign)


func _corals() -> void:
	# Corals all over the sea bed: branching ones, brain corals, tubes and fans, with starfish and shells between them.
	# The living ones use the "Coral" materials, so they go pale while the tide's out. Only the big ones are solid.
	var g := Node3D.new()
	g.name = "Corals"
	world.add_child(g)
	var star := mat("Starfish", Color(1.0, 0.6, 0.45), 0.8)
	var shell := mat("Sea Shell", Color(0.98, 0.92, 0.88), 0.5)
	for c in 64:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 3.5)
		var at := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(at, 1.6):
			continue
		match c % 5:
			0:                                                    # branching coral
				var m := coral(c)
				var h := rng.randf_range(1.6, 2.8)
				mesh_at(cyl(0.14, 0.24, h, 7), m, at + Vector3(0, h / 2.0, 0), g)
				cyl_solid(0.3, h, at + Vector3(0, h / 2.0, 0), g)
				for b in 4:
					var ba := b * TAU / 4.0 + rng.randf()
					var bl := rng.randf_range(0.7, 1.2)
					var base := at + Vector3(0, h * rng.randf_range(0.45, 0.9), 0)
					var dir := Vector3(cos(ba) * 0.6, 0.8, sin(ba) * 0.6).normalized()
					var br := mesh_at(cyl(0.08, 0.12, bl, 6), m, base + dir * bl / 2.0, g)
					br.look_at_from_position(base + dir * bl / 2.0, base + dir * bl + Vector3(0.01, 0, 0), Vector3.UP)
					br.rotate_object_local(Vector3.RIGHT, PI / 2.0)
					mesh_at(ball(0.16, 6), m, base + dir * bl, g)
			1:                                                    # brain coral
				var r := rng.randf_range(0.6, 1.2)
				var bc := mesh_at(ball(r, 12), coral(c), at + Vector3(0, r * 0.45, 0), g)
				bc.scale = Vector3(1.2, 0.75, 1.1)
				cyl_solid(r, r, at + Vector3(0, r * 0.5, 0), g)
			2:                                                    # tube coral
				for t in 5:
					var th := rng.randf_range(0.5, 1.5)
					var off := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
					mesh_at(cyl(0.16, 0.13, th, 7), coral(c + t % 2), at + off + Vector3(0, th / 2.0, 0), g)
			3:                                                    # sea fan
				var f := mesh_at(ball(1.0, 10), coral(c), at + Vector3(0, 1.1, 0), g)
				f.scale = Vector3(1.1, 1.1, 0.07)
				f.rotation.y = rng.randf() * TAU
				mesh_at(cyl(0.07, 0.1, 0.5, 6), coral(c), at + Vector3(0, 0.25, 0), g)
			4:                                                    # a starfish and a shell or two
				for arm in 5:
					var aa := arm * TAU / 5.0
					var s := mesh_at(ball(0.3, 6), star, at + Vector3(cos(aa) * 0.3, 0.06, sin(aa) * 0.3), g)
					s.scale = Vector3(1.5, 0.25, 0.5)
					s.rotation.y = -aa
				var sh := mesh_at(ball(0.3, 8), shell, at + Vector3(0.9, 0.1, 0.4), g)
				sh.scale = Vector3(1.0, 0.5, 0.8)


func _wreck() -> void:
	# A little fishing boat left on its side when the tide went, and an anchor, by the way in
	var g := Node3D.new()
	g.name = "Stranded Boat"
	g.position = Vector3(-17, 0, 31)
	g.rotation = Vector3(0, 0.6, 0.38)
	world.add_child(g)
	var hull := mat("Boat Hull", Color(0.35, 0.6, 0.75), 0.7)
	var wood := mat("Boat Wood", Color(0.75, 0.6, 0.45), 0.8)
	var body := mesh_at(ball(1.0, 12), hull, Vector3(0, 0.7, 0), g)
	body.scale = Vector3(1.2, 0.8, 2.8)
	mesh_at(box(Vector3(1.9, 0.12, 4.4)), wood, Vector3(0, 1.05, 0), g)
	mesh_at(cyl(0.07, 0.09, 3.2, 6), wood, Vector3(0, 2.6, 0.3), g)
	mesh_at(box(Vector3(0.04, 1.6, 1.4)), mat("Boat Sail", Color(1.0, 0.95, 0.85), 0.8), Vector3(0, 3.0, -0.5), g)
	var b := BoxShape3D.new()
	b.size = Vector3(2.2, 1.6, 5.0)
	solid(b, Vector3(-17, 0.7, 31), world, Vector3(0, 0.6, 0)).name = "Boat Solid"


func _in_pool(p: Vector3, room: float) -> bool:
	for e: Vector4 in POOLS:
		var dx := (p.x - e.x) / (e.z + room)
		var dz := (p.z - e.y) / (e.w + room)
		if dx * dx + dz * dz < 1.0:
			return true
	return false


func _blocked(p: Vector3, room: float) -> bool:
	var flat := Vector2(p.x, p.z)
	if _in_pool(p, room + 1.0):
		return true
	for c in [[VAULT, 7.5], [GROTTO, 9.0], [SPIRE, SPIRE_R + 6.5], [Vector3(0, 0, 33), 9.0], [Vector3(-17, 0, 31), 4.0],
			[BASIN + Vector3(9.5, 0, 11.5), 2.5], [Vector3(-9, 0, -5), 5.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	for h: Vector4 in HOUSES:
		if flat.distance_to(Vector2(h.x, h.y)) < 4.6 * h.z + room:
			return true
	# Keep the paths from the way in clear
	var start := Vector2(0, 30)
	for to in [VAULT + Vector3(5, 0, 0), GROTTO + Vector3(-7, 0, 0), SPIRE + Vector3(7, 0, 5), BASIN + Vector3(0, 0, BASIN_R + 1.0)]:
		var b := Vector2(to.x, to.z)
		var t := clampf((flat - start).dot(b - start) / (b - start).length_squared(), 0.0, 1.0)
		if flat.distance_to(start.lerp(b, t)) < 1.6 + room:
			return true
	return false
