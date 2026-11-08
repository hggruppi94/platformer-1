extends SceneTree

# Builds res://scenes/portal_worlds/shard_isle.tscn: Shard Isle, the first portal world and the tutorial (plan item
# 19a, world 0). A little island of pale rock floating in a teal-and-lilac sky, bristling with Remnant-green crystals,
# with three small islets round it reached by floating crystal stepping stones. It's a broken bit of the brain land,
# humming out of tune: the player finds the three Echo Crystals (one on each islet) and sets them in the Heart Stone in
# the middle, and the island hums in tune again. No boss. Logic: scripts/shard_isle.gd (on scripts/portal_world.gd),
# which also puts in the things that come from code (the way home, the Time Stone, the Heart Stone, the Echo
# Crystals, the Remnant vein) at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_shard_isle.gd

const OUT := "res://scenes/portal_worlds/shard_isle.tscn"
const MAIN_R := 14.0                    # the main island's top
const ISLETS := [                       # [centre (top surface), radius, the Echo Crystal's name]
	[Vector3(25, 2.0, -6), 5.0, "Echo1"],
	[Vector3(-5, 4.0, -27), 5.0, "Echo2"],
	[Vector3(-24, 1.2, 9), 5.0, "Echo3"],
]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}


func _initialize() -> void:
	rng.seed = 42
	world = Node3D.new()
	world.name = "ShardIsle"
	world.set_script(load("res://scripts/shard_isle.gd"))
	world.set("world_id", "shard_isle")
	world.set("fall_below", -14.0)
	world.set_meta("preview_radius", 46.0)
	_environment()
	_island(Vector3.ZERO, MAIN_R, 7.0, "Main Island")
	for i in ISLETS:
		_island(i[0], i[1], 4.0, "Islet " + str(i[2]))
		_marker(str(i[2]), i[0] + Vector3(0, 0.0, 0))
		_stones(i[0], i[1])
	_crystals()
	_far_shards()
	_marker("HeartStone", Vector3(0, 0, -3))
	_marker("TimeStone", Vector3(4.5, 0, 7.5))
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(-7.5, 0, 8.0)).rotation.y = atan2(7.5, -11.0)
	_marker("Vein1", ISLETS[2][0] + Vector3(-2.2, 0, -1.5))
	_marker("PreviewCentre", Vector3(0, 2, -6))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 8.5))     # facing in, towards the Heart Stone (-Z)
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


func mat(name: String, color: Color, rough := 0.85, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
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
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func crystal(r: float, h: float) -> CylinderMesh:
	var c := cyl(r * 0.15, r, h, 6)
	c.rings = 1
	return c


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.62, 0.66)
	sky_mat.sky_horizon_color = Color(0.78, 0.66, 0.9)
	sky_mat.ground_horizon_color = Color(0.7, 0.6, 0.86)
	sky_mat.ground_bottom_color = Color(0.5, 0.68, 0.78)       # (it floats in the sky: below is sky too)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Like the Void's own sky (tools/build_town.gd): half the ambient light from a soft lilac, so the teal sky
	# doesn't wash the island out
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.85, 0.72, 0.95)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.66, 0.9)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.85)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 35, 0)
	world.add_child(sun)


func _island(top: Vector3, r: float, depth: float, n: String) -> void:
	# A floating island: a flat grassy-lilac top on a rough upside-down cone of pale rock
	var g := Node3D.new()
	g.name = n
	g.position = top
	world.add_child(g)
	mesh_at(cyl(r, r * 0.96, 0.6, 32), mat("Shard Moss", Color(0.36, 0.72, 0.6), 0.9), Vector3(0, -0.3, 0), g)
	mesh_at(cyl(r * 0.95, r * 0.2, depth, 14), mat("Shard Rock", Color(0.52, 0.46, 0.68), 0.95), Vector3(0, -0.6 - depth / 2.0, 0), g)
	mesh_at(cyl(r * 0.25, 0.05, depth * 0.5, 8), mat("Shard Rock", Color.WHITE), Vector3(0, -0.6 - depth * 1.2, 0), g)
	# Crystals hanging under it, glowing
	for k in int(r):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.7) * r
		var h := rng.randf_range(0.8, 2.0)
		mesh_at(crystal(rng.randf_range(0.15, 0.3), h), mat("Shard Glow", Color(0.4, 0.95, 0.5), 0.15, 0.7),
			Vector3(cos(a) * d, -0.8 - depth * (1.0 - d / r) * 0.6 - h / 2.0, sin(a) * d), g, Vector3(PI, 0, 0))
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 0.6
	solid(shape, Vector3(0, -0.3, 0), g)


func _stones(to: Vector3, r: float) -> void:
	# Floating crystal stepping stones from the main island's rim out to an islet, rising a little at a time
	var flat := Vector3(to.x, 0, to.z)
	var dir := flat.normalized()
	var start := dir * (MAIN_R - 0.6)
	var end := flat - dir * (r - 0.6)
	var length := start.distance_to(end)
	var n := maxi(int(ceil(length / 2.5)) - 1, 1)
	var stone := mat("Stepping Crystal", Color(0.6, 0.85, 0.95), 0.2, 0.25)
	for k in n:
		var t := float(k + 1) / float(n + 1)
		var p := start.lerp(end, t)
		p.y = lerpf(0.0, to.y, t) - 0.25
		var side := dir.cross(Vector3.UP) * sin(t * PI * 2.0) * 0.6
		var b := BoxShape3D.new()
		b.size = Vector3(1.7, 0.5, 1.7)
		var body := solid(b, p + side, world, Vector3(0, rng.randf() * TAU, 0))
		body.name = "Stone"
		var m := mesh_at(BoxMesh.new(), stone, Vector3.ZERO, body)
		m.scale = b.size
		mesh_at(crystal(0.25, 0.9), mat("Shard Glow", Color.WHITE), Vector3(0, -0.6, 0), body, Vector3(PI, 0, 0))


func _crystals() -> void:
	# Big Remnant-green crystal clusters round the main island's rim (the ones near the edge are solid, to lean on)
	var glow := mat("Shard Glow", Color.WHITE)
	var pale := mat("Pale Crystal", Color(0.78, 0.7, 0.98), 0.15, 0.25)
	for k in 14:
		var a := k * TAU / 14.0 + rng.randf_range(-0.12, 0.12)
		var gap := false
		for i in ISLETS:
			var to := Vector3(i[0].x, 0, i[0].z).normalized()
			if Vector3(cos(a), 0, sin(a)).dot(to) > 0.93:
				gap = true
		if gap or absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.35:
			continue                         # leave the way to the islets and the way home clear
		var d := MAIN_R - rng.randf_range(1.0, 2.0)
		var cluster := Node3D.new()
		cluster.name = "Crystal Cluster"
		cluster.position = Vector3(cos(a) * d, 0, sin(a) * d)
		world.add_child(cluster)
		for j in 4:
			var h := rng.randf_range(1.2, 3.6)
			mesh_at(crystal(rng.randf_range(0.25, 0.5), h), glow if j % 2 == 0 else pale,
				Vector3(rng.randf_range(-0.6, 0.6), h / 2.0, rng.randf_range(-0.6, 0.6)), cluster,
				Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)))
		var cs := CylinderShape3D.new()
		cs.radius = 0.9
		cs.height = 3.0
		solid(cs, Vector3(0, 1.5, 0), cluster)
	# The out-of-tune shards: little floating pieces over the island that stutter until it's mended
	var jitter := Node3D.new()
	jitter.name = "Jitter"
	world.add_child(jitter)
	for k in 10:
		var a := rng.randf() * TAU
		var d := rng.randf_range(3.0, 11.0)
		var s := mesh_at(crystal(rng.randf_range(0.15, 0.3), rng.randf_range(0.5, 1.0)), pale,
			Vector3(cos(a) * d, rng.randf_range(3.0, 6.0), sin(a) * d), jitter, Vector3(rng.randf(), rng.randf(), rng.randf()))
		s.name = "Shard"


func _far_shards() -> void:
	# Far-off floating rocks in the sky, so the island isn't alone
	var rock := mat("Shard Rock", Color.WHITE)
	var glow := mat("Shard Glow", Color.WHITE)
	var far := Node3D.new()
	far.name = "Far Shards"
	world.add_child(far)
	for k in 16:
		var a := k * TAU / 16.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(70.0, 120.0)
		var p := Vector3(cos(a) * d, rng.randf_range(-20.0, 25.0), sin(a) * d)
		var r := rng.randf_range(2.0, 7.0)
		mesh_at(cyl(r, r * 0.15, r * 1.6, 9), rock, p, far)
		mesh_at(crystal(r * 0.18, r * 0.8), glow, p + Vector3(0, r * 0.45, 0), far)
