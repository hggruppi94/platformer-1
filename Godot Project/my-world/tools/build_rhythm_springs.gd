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
	_edge()
	_pools()
	_hot_springs()
	_sizzle_steps()
	_mesa()
	_slide()
	_dance_floor()
	_stage()
	for i in PALMS.size():
		_palm(PALMS[i], i)
	_flowers()
	_marker("Melody", Vector3(10.5, 0, 25.0)).rotation.y = atan2(DANCE.x - 10.5, DANCE.z - 25.0)
	_marker("TimeStone", Vector3(8.0, 0, 33))
	_marker("WayHome", Vector3(-8.0, 0, 33)).rotation.y = atan2(8.0, -33.0)
	_marker("Vein1", Vector3(-22, 0, 24))
	_marker("PreviewCentre", Vector3(0, 3, -6))
	_marker("OffBeat", STAGE + Vector3(0, STAGE_TOP, -4.5))
	_marker("SunHigh", Vector3(10, 120, 20))
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
	env.fog_density = 0.004
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


func _edge() -> void:
	# Sandstone cliffs and dunes round the edge in warm stripes, with an invisible fence so nobody wanders off
	var g := Node3D.new()
	g.name = "Cliffs"
	world.add_child(g)
	var rocks := [mat("Sandstone", Color(0.9, 0.62, 0.42), 0.9), mat("Sandstone Red", Color(0.82, 0.48, 0.36), 0.9),
		mat("Sandstone Pale", Color(0.9, 0.68, 0.48), 0.9)]
	for k in 28:
		var a := k * TAU / 28.0 + rng.randf_range(-0.04, 0.04)
		var r := rng.randf_range(7.0, 11.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(4.0, 8.0))
		var h := rng.randf_range(6.0, 14.0)
		for layer in 3:
			var s := mesh_at(cyl(r * (0.8 - layer * 0.15), r * (0.9 - layer * 0.15), h / 3.0, 12), rocks[(k + layer) % 3],
				p + Vector3(0, h / 6.0 + layer * h / 3.0, 0), g)
			s.rotation.y = rng.randf() * TAU
	for k in 52:
		var a := k * TAU / 52.0
		var b := BoxShape3D.new()
		b.size = Vector3(6.2, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _pools() -> void:
	# The cool spring pools: shallow, clear and blue, ringed with smooth pebbles. Wading in one cools you right down
	# (scripts/rhythm_springs.gd); the water itself is scripts/water.gd, so you splash and slow down in it.
	var g := Node3D.new()
	g.name = "Cool Pools"
	g.set_script(load("res://scripts/water.gd"))
	var outline: Array[Vector4] = []
	for p in POOLS:
		outline.append(p)
	g.set("ellipses", outline)
	g.set("water_y", WATER_Y)
	world.add_child(g)
	var water := mat("Cool Water", Color(0.35, 0.8, 0.95), 0.1, 0.25, 0.8)
	var bed := mat("Pool Bed", Color(0.55, 0.85, 0.9), 0.6)
	var pebble := mat("Pebble", Color(0.92, 0.88, 0.8), 0.8)
	for i in POOLS.size():
		var e: Vector4 = POOLS[i]
		var holder := Node3D.new()
		holder.name = "Pool%d" % (i + 1)
		holder.position = Vector3(e.x, 0, e.y)
		g.add_child(holder)
		var bm := mesh_at(cyl(1.0, 1.0, 0.04, 32), bed, Vector3(0, 0.03, 0), holder)
		bm.scale = Vector3(e.z, 1, e.w)
		var wm := mesh_at(cyl(1.0, 1.0, 0.04, 32), water, Vector3(0, WATER_Y, 0), holder)
		wm.scale = Vector3(e.z, 1, e.w)
		wm.name = "Surface"
		var n := int((e.z + e.w) * 2.2)
		for k in n:
			var a := k * TAU / n
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
	for c in [[MESA, MESA_R + 2.5], [DANCE, DANCE_R + 2.0], [STAGE, STAGE_R + 2.0], [Vector3(0, 0, 33), 9.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	for h in HOT_SPRINGS:
		if flat.distance_to(Vector2(h.x, h.z)) < 4.0 + room:
			return true
	var a := Vector2(SIZZLE_FROM.x, SIZZLE_FROM.z)
	var b := Vector2(SIZZLE_TO.x, SIZZLE_TO.z)
	var t := clampf((flat - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return flat.distance_to(a.lerp(b, t)) < SIZZLE_W / 2.0 + 3.0 + room
