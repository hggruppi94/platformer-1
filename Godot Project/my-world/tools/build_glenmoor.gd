extends SceneTree

# Builds res://scenes/portal_worlds/glenmoor.tscn: Glenmoor, Heather's home world (plan item 19a world 6). Misty
# highland hills, purple heather and wildflowers, dry stone walls and fluffy highland critters, home of Heather (the
# cattle girl) and her best friend Isla. The Stormram's whirlwind has set the seasons spinning: spring, summer, autumn
# and winter come round every few seconds, so crops grow and wilt before anyone can pick them. Three Spring Bells
# settle the seasons again:
#   the Fold (west)        herd the five Fluffkins into the stone pen (they trot away from you, so walk round behind)
#   Heather's Croft (east) catch each of her five plants in full bloom and sing it still (a healing-and-growing game)
#   Ben Bonnie (north-west) race Isla up the hill past the six cairns to the summit
# With all three, the Stormram wakes on the Standing Stones (north-east) when you come near.
# Logic: scripts/glenmoor.gd (on scripts/portal_world.gd) and scripts/stormram.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_glenmoor.gd

const OUT := "res://scenes/portal_worlds/glenmoor.tscn"
const FLOOR_R := 50.0
const HILL := Vector3(-20, 0, -20)          # Ben Bonnie
const HILL_R := 22.0                        # its foot...
const HILL_TOP_R := 5.0                     # ...its flat top...
const HILL_H := 8.0                         # ...and how high it is (a gentle 25 degrees)
const CAIRNS := 6
const RACE_START := Vector3(-2, 0, -6)
const FOLD := Vector3(-26, 0, 16)           # the stone pen for the Fluffkins
const FOLD_R := 5.5
const FOLD_GATE := 0.0                      # the gap in its wall faces east (+x), towards the meadow
const CROFT := Vector3(28, 0, 10)           # Heather's farmhouse
const BARN := Vector3(38, 0, -4)
const GARDEN := Vector3(22, 0, 24)          # her five garden beds in a row
const STONES := Vector3(22, 0, -28)         # the Standing Stones, where the Stormram sleeps
const STONES_R := 9.0
const LOCH := Vector4(6, 4, 4.5, 3.0)       # a wee loch in the middle of the glen (x, z, radius x, radius z)
const WATER_Y := 0.3
const FLUFFS := [Vector3(-8, 0, 18), Vector3(-14, 0, 28), Vector3(-36, 0, 2), Vector3(-6, 0, 6), Vector3(-30, 0, 30)]
const TREES := [Vector3(14, 0, 32), Vector3(36, 0, 22), Vector3(40, 0, 10), Vector3(-40, 0, 18), Vector3(4, 0, -22),
	Vector3(10, 0, -40), Vector3(-38, 0, -36), Vector3(32, 0, -42), Vector3(-44, 0, 4), Vector3(18, 0, 6)]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}


func _initialize() -> void:
	rng.seed = 66
	world = Node3D.new()
	world.name = "Glenmoor"
	world.set_script(load("res://scripts/glenmoor.gd"))
	world.set("world_id", "glenmoor")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 38.0)
	_environment()
	_floor()
	_edge()
	_hill()
	_fold()
	_croft()
	_garden()
	_loch()
	_standing_stones()
	_walls()
	for i in TREES.size():
		_tree(TREES[i], i)
	_heather_and_flowers()
	for i in FLUFFS.size():
		_marker("Fluff%d" % (i + 1), FLUFFS[i])
	_marker("Heather", Vector3(4.0, 0, 29.0)).rotation.y = atan2(-4.0, 6.0)
	_marker("Isla", RACE_START + Vector3(2.0, 0, 1.5)).rotation.y = atan2(-2.0, -1.5)
	_marker("TimeStone", Vector3(9.0, 0, 35))
	_marker("WayHome", Vector3(-9.0, 0, 35)).rotation.y = atan2(9.0, -35.0)
	_marker("Vein1", Vector3(-40, 0, -14))
	_marker("PreviewCentre", Vector3(0, 3, -4))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 38))
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
	top = snappedf(top, 0.05)
	bottom = snappedf(bottom, 0.05)
	h = maxf(snappedf(h, 0.1), 0.1)             # (never zero high: a flat disc with no height has no normals)
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


func box_solid(size: Vector3, at: Vector3, parent: Node, yaw := 0.0) -> StaticBody3D:
	var b := BoxShape3D.new()
	b.size = size
	return solid(b, at, parent, Vector3(0, yaw, 0))


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


static func hill_height(x: float, z: float) -> float:
	# How high Ben Bonnie's slope is at (x, z) (scripts/glenmoor.gd has the same: it puts the race and cairns on it)
	var r := Vector2(x - HILL.x, z - HILL.z).length()
	return clampf((HILL_R - r) / (HILL_R - HILL_TOP_R), 0.0, 1.0) * HILL_H


func _environment() -> void:
	# A soft misty highland morning: pale blue-grey sky, a low sun through the haze, thick mist far off.
	# scripts/glenmoor.gd tints the sky and light with the spinning seasons, and settles them on spring once mended.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.66, 0.85)
	sky_mat.sky_horizon_color = Color(0.86, 0.88, 0.9)
	sky_mat.ground_horizon_color = Color(0.86, 0.88, 0.9)
	sky_mat.ground_bottom_color = Color(0.45, 0.55, 0.45)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 0.95)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.88, 0.92)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, 30, 0)
	world.add_child(sun)


func _floor() -> void:
	# The glen floor: soft grass (scripts/glenmoor.gd recolours "Glen Grass" with the seasons), and paths of pale
	# gravel from the way in to each place
	var g := Node3D.new()
	g.name = "Glen"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 8.0, FLOOR_R + 8.0, 1.0, 56), mat("Glen Grass", Color(0.45, 0.72, 0.35), 0.95), Vector3(0, -0.5, 0), g)
	cyl_solid(FLOOR_R + 8.0, 1.0, Vector3(0, -0.5, 0), g)
	var gravel := mat("Gravel", Color(0.82, 0.78, 0.7), 0.95)
	var start := Vector3(0, 0, 33)
	for to in [FOLD + Vector3(FOLD_R + 2.0, 0, 0), GARDEN + Vector3(-6, 0, 0), RACE_START + Vector3(0, 0, 2), STONES + Vector3(-4, 0, STONES_R + 1.0),
			CROFT + Vector3(-5, 0, 2)]:
		var n := int(start.distance_to(to) / 1.4)
		for k in n:
			var p: Vector3 = start.lerp(to, (k + 0.5) / n)
			if _in_loch(p, 0.8) or hill_height(p.x, p.z) > 0.05:
				continue
			mesh_at(cyl(0.55, 0.6, 0.1, 7), gravel, p + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)), g)


func _edge() -> void:
	# Rolling misty highland hills all round, layered back into the mist with snow on the far tops (the "Snow Cap"
	# pieces show only in winter), and an invisible fence so nobody wanders off
	var g := Node3D.new()
	g.name = "Highlands"
	world.add_child(g)
	var greens := [mat("Hill Grass", Color(0.4, 0.62, 0.35), 0.95), mat("Far Hills", Color(0.42, 0.52, 0.5), 0.95),
		mat("Heather Hills", Color(0.52, 0.4, 0.55), 0.95)]
	var snow := mat("Snow Cap", Color(0.95, 0.97, 1.0), 0.8)
	for ring in 2:
		var n := 22 if ring == 0 else 16
		for k in n:
			var a := k * TAU / n + rng.randf_range(-0.05, 0.05) + ring * 0.2
			var r := rng.randf_range(12.0, 18.0) * (1.0 + ring * 0.8)
			var d := FLOOR_R + 8.0 + ring * 26.0 + rng.randf_range(0.0, 6.0)
			var h := rng.randf_range(10.0, 18.0) * (1.0 + ring * 0.9)
			var p := Vector3(cos(a), 0, sin(a)) * d
			var hill := mesh_at(ball(1.0, 16), greens[(k + ring) % 3], p, g)
			hill.scale = Vector3(r, h, r * 0.8)
			hill.rotation.y = rng.randf() * TAU
			if ring == 1 or k % 3 == 0:
				var cap := mesh_at(ball(1.0, 16), snow, p + Vector3(0, h * 0.72, 0), g)
				cap.scale = Vector3(r * 0.55, h * 0.32, r * 0.45)
				cap.rotation.y = hill.rotation.y
				cap.name = "Snow Cap %d" % (k + ring * 100)
	for k in 56:
		var a := k * TAU / 56.0
		var body := box_solid(Vector3(6.0, 8.0, 0.6), Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, -a + PI / 2.0)
		body.name = "Fence"


func _hill() -> void:
	# Ben Bonnie: a big round grassy hill with a flat top and a cairn on it, walkable all the way up (a convex cone)
	var g := Node3D.new()
	g.name = "Ben Bonnie"
	g.position = HILL
	world.add_child(g)
	var cone := CylinderMesh.new()
	cone.top_radius = HILL_TOP_R
	cone.bottom_radius = HILL_R
	cone.height = HILL_H
	cone.radial_segments = 40
	cone.rings = 1
	mesh_at(cone, mat("Hill Grass", Color(0.4, 0.62, 0.35), 0.95), Vector3(0, HILL_H / 2.0, 0), g)
	var body := StaticBody3D.new()
	body.name = "Slope"
	body.position = Vector3(0, HILL_H / 2.0, 0)
	var cs := CollisionShape3D.new()
	cs.shape = cone.create_convex_shape()
	body.add_child(cs)
	g.add_child(body)
	var hm := _marker("Hill", HILL)
	hm.set_meta("radius", HILL_R)
	hm.set_meta("top_radius", HILL_TOP_R)
	hm.set_meta("height", HILL_H)
	# Heather patches and rocks on its slopes (no collision: they're small)
	var heather := [mat("Heather Bloom", Color(0.72, 0.4, 0.78), 0.9), mat("Heather Bloom Pale", Color(0.85, 0.6, 0.88), 0.9)]
	var rock := mat("Stone", Color(0.6, 0.6, 0.62), 0.9)
	for k in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(HILL_TOP_R + 1.0, HILL_R - 1.0)
		var x := cos(a) * d
		var z := sin(a) * d
		var y := hill_height(HILL.x + x, HILL.z + z)
		var b := mesh_at(ball(0.35, 8), heather[k % 2] if k % 4 else rock, Vector3(x, y + 0.05, z), g)
		b.scale = Vector3(1.4, 0.6, 1.2)
	# The race: six cairns spiralling up from the foot to the summit (markers Cairn1..6, the last on the top), and
	# Isla's racing line through them (scripts/glenmoor.gd runs her along it)
	var pts: Array = [RACE_START + Vector3(0, 0.0, 0)]
	var a0 := atan2(RACE_START.z - HILL.z, RACE_START.x - HILL.x)
	for i in CAIRNS:
		var t := float(i + 1) / CAIRNS
		var a := a0 - t * 1.25 * TAU                    # anticlockwise round and up
		var r := lerpf(HILL_R - 2.5, 0.0, t) if i < CAIRNS - 1 else 0.0
		var x := HILL.x + cos(a) * r
		var z := HILL.z + sin(a) * r
		var at := Vector3(x, hill_height(x, z), z)
		var m := _marker("Cairn%d" % (i + 1), at)
		m.set_meta("summit", i == CAIRNS - 1)
		_cairn(at, i == CAIRNS - 1)
		pts.append(at)
	var line := Curve3D.new()
	for i in pts.size():
		var p: Vector3 = pts[i]
		# (between cairns the line follows the slope, so Isla never cuts through the hill)
		if i > 0:
			var prev: Vector3 = pts[i - 1]
			for s in range(1, 6):
				var q := prev.lerp(p, s / 6.0)
				line.add_point(Vector3(q.x, hill_height(q.x, q.z), q.z))
		else:
			line.add_point(p)
	line.bake_interval = 0.3
	var path := Path3D.new()
	path.name = "RaceLine"
	path.curve = line
	world.add_child(path)
	_marker("RaceStart", RACE_START)


func _cairn(at: Vector3, summit: bool) -> void:
	# A cairn: a little stack of stones with a tartan flag on a pole (no collision: you run past it)
	var g := Node3D.new()
	g.name = "Summit Cairn" if summit else "Cairn"
	g.position = at
	world.add_child(g)
	var stone := mat("Stone", Color(0.6, 0.6, 0.62), 0.9)
	var n := 6 if summit else 4
	for k in n:
		var s := mesh_at(ball(0.5 - k * 0.06, 8), stone, Vector3(0, 0.25 + k * 0.38, 0), g)
		s.scale = Vector3(1.2, 0.7, 1.0)
	mesh_at(cyl(0.04, 0.04, 2.6, 6), mat("Pole", Color(0.5, 0.36, 0.25), 0.8), Vector3(0.6, 1.3, 0), g)
	var flag := mesh_at(box(Vector3(0.9, 0.55, 0.04)), mat("Tartan", Color(0.75, 0.2, 0.25), 0.8), Vector3(1.05, 2.3, 0), g)
	flag.name = "Flag"
	mesh_at(box(Vector3(0.9, 0.08, 0.05)), mat("Tartan Stripe", Color(0.2, 0.35, 0.6), 0.8), Vector3(1.05, 2.4, 0), g)
	mesh_at(box(Vector3(0.08, 0.55, 0.05)), mat("Tartan Stripe", Color(0.2, 0.35, 0.6), 0.8), Vector3(1.05, 2.3, 0), g)


func _fold() -> void:
	# The Fold: a round dry stone pen for the Fluffkins, with a gap in its wall facing the meadow
	var g := Node3D.new()
	g.name = "The Fold"
	g.position = FOLD
	world.add_child(g)
	var stone := [mat("Stone", Color(0.6, 0.6, 0.62), 0.9), mat("Stone Dark", Color(0.48, 0.48, 0.52), 0.9)]
	var n := 22
	for k in n:
		var a := k * TAU / n
		if absf(wrapf(a - FOLD_GATE, -PI, PI)) < 0.4:
			continue                                    # the gate
		var p := Vector3(cos(a), 0, sin(a)) * FOLD_R
		var blk := mesh_at(box(Vector3(1.7, 0.9, 0.7)), stone[k % 2], p + Vector3(0, 0.45, 0), g, Vector3(0, -a + PI / 2.0, 0))
		blk.name = "Wall"
		box_solid(Vector3(1.7, 1.0, 0.7), p + Vector3(0, 0.5, 0), g, -a + PI / 2.0)
		mesh_at(box(Vector3(1.6, 0.2, 0.8)), stone[(k + 1) % 2], p + Vector3(0, 0.95, 0), g, Vector3(0, -a + PI / 2.0, 0))
	mesh_at(cyl(FOLD_R - 0.5, FOLD_R - 0.5, 0.1, 28), mat("Straw", Color(0.9, 0.8, 0.45), 0.95), Vector3(0, 0.0, 0), g)
	var m := _marker("Fold", FOLD)
	m.set_meta("radius", FOLD_R)
	m.set_meta("gate", FOLD_GATE)
	var sign := Label3D.new()
	sign.text = "The Fold"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position = Vector3(cos(FOLD_GATE), 0, sin(FOLD_GATE)) * (FOLD_R + 1.2) + Vector3(0, 1.9, 1.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)


func _croft() -> void:
	# Heather's Croft: a white stone farmhouse with a red door and a big front porch (half highland croft, half the
	# farm back home she talks about), and a red barn with a hayloft behind it
	var g := Node3D.new()
	g.name = "Heather's Croft"
	g.position = CROFT
	world.add_child(g)
	var white := mat("Whitewash", Color(0.95, 0.93, 0.88), 0.9)
	var slate := mat("Slate", Color(0.35, 0.38, 0.45), 0.8)
	var red := mat("Barn Red", Color(0.72, 0.22, 0.2), 0.8)
	var wood := mat("Porch Wood", Color(0.62, 0.45, 0.3), 0.8)
	mesh_at(box(Vector3(9.0, 4.0, 6.0)), white, Vector3(0, 2.0, 0), g)
	box_solid(Vector3(9.0, 4.0, 6.0), Vector3(0, 2.0, 0), g)
	var roof := mesh_at(cyl(0.0, 4.6, 9.4, 3), slate, Vector3(0, 5.1, 0), g, Vector3(0, 0, PI / 2.0))
	roof.scale = Vector3(1.0, 1.0, 0.75)
	for s in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.9, 2.2, 0.9)), white, Vector3(s * 3.6, 6.6, 0), g)          # chimneys
	mesh_at(box(Vector3(1.2, 2.1, 0.1)), red, Vector3(-1.0, 1.05, -3.02), g)                # the front door (facing the glen)
	for x in [-3.2, 2.0]:
		mesh_at(box(Vector3(1.2, 1.0, 0.1)), mat("Window", Color(1.0, 0.9, 0.6), 0.3, 0.4), Vector3(x, 2.2, -3.02), g)
	# The porch: boards, posts, a little roof, a rocking chair
	mesh_at(box(Vector3(9.0, 0.3, 2.4)), wood, Vector3(0, 0.15, -4.2), g)
	box_solid(Vector3(9.0, 0.3, 2.4), Vector3(0, 0.15, -4.2), g)
	for x in [-4.2, -1.4, 1.4, 4.2]:
		mesh_at(cyl(0.1, 0.1, 2.6, 6), wood, Vector3(x, 1.6, -5.2), g)
	mesh_at(box(Vector3(9.4, 0.2, 2.8)), red, Vector3(0, 3.0, -4.3), g, Vector3(-0.15, 0, 0))
	mesh_at(box(Vector3(0.6, 0.8, 0.6)), wood, Vector3(2.6, 0.7, -4.3), g)
	# The barn
	var b := Node3D.new()
	b.name = "Barn"
	b.position = BARN
	world.add_child(b)
	mesh_at(box(Vector3(8.0, 6.0, 10.0)), red, Vector3(0, 3.0, 0), b)
	box_solid(Vector3(8.0, 6.0, 10.0), Vector3(0, 3.0, 0), b)
	var br := mesh_at(cyl(0.0, 4.6, 10.2, 4), slate, Vector3(0, 7.4, 0), b, Vector3(PI / 2.0, PI / 4.0, 0))
	br.scale = Vector3(1.0, 1.0, 0.55)
	for z in [-1.0, 1.0]:
		mesh_at(box(Vector3(3.2, 3.6, 0.1)), white, Vector3(-4.02, 1.8, z * 1.6), b, Vector3(0, PI / 2.0, 0))
	mesh_at(box(Vector3(1.6, 1.6, 0.1)), white, Vector3(-4.02, 4.6, 0), b, Vector3(0, PI / 2.0, 0))
	for k in 5:                                         # hay bales out front
		var hb := mesh_at(cyl(0.7, 0.7, 1.0, 12), mat("Hay", Color(0.92, 0.8, 0.42), 0.95), Vector3(-6.5, 0.7, -3.5 + k * 1.6), b,
			Vector3(PI / 2.0, 0, 0))
		hb.name = "Hay Bale"
	box_solid(Vector3(1.4, 1.4, 8.0), Vector3(-6.5, 0.7, -0.3), b)


func _garden() -> void:
	# Heather's garden: five raised beds in a row with a low picket fence (scripts/glenmoor.gd grows a plant in each,
	# Bed1..5, round and round with the spinning seasons)
	var g := Node3D.new()
	g.name = "Croft Garden"
	g.position = GARDEN
	world.add_child(g)
	var soil := mat("Soil", Color(0.35, 0.24, 0.16), 0.95)
	var plank := mat("Bed Plank", Color(0.62, 0.45, 0.3), 0.85)
	for i in 5:
		var x := (i - 2) * 3.2
		mesh_at(box(Vector3(2.2, 0.4, 2.2)), plank, Vector3(x, 0.2, 0), g)
		mesh_at(box(Vector3(1.9, 0.1, 1.9)), soil, Vector3(x, 0.42, 0), g)
		box_solid(Vector3(2.2, 0.4, 2.2), Vector3(x, 0.2, 0), g)
		_marker("Bed%d" % (i + 1), GARDEN + Vector3(x, 0.45, 0))
	var picket := mat("Picket", Color(0.97, 0.96, 0.92), 0.8)
	for k in 26:
		var x := -8.6 + k * 0.7
		if absf(x) < 1.2:
			continue                                    # a gap in the middle to walk in
		mesh_at(box(Vector3(0.12, 0.8, 0.06)), picket, Vector3(x, 0.4, 2.6), g)
	var sign := Label3D.new()
	sign.text = "Heather's Garden"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position = Vector3(0, 1.6, 2.8)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)


func _loch() -> void:
	# A wee loch in the middle of the glen: shallow, so you wade (scripts/water.gd)
	var g := Node3D.new()
	g.name = "Wee Loch"
	g.set_script(load("res://scripts/water.gd"))
	var outline: Array[Vector4] = [LOCH]
	g.set("ellipses", outline)
	g.set("water_y", WATER_Y)
	world.add_child(g)
	var holder := Node3D.new()
	holder.name = "Loch"
	holder.position = Vector3(LOCH.x, 0, LOCH.y)
	g.add_child(holder)
	var bed := mesh_at(cyl(1.0, 1.0, 0.1, 32), mat("Loch Bed", Color(0.3, 0.42, 0.4), 0.7), Vector3(0, -0.02, 0), holder)
	bed.scale = Vector3(LOCH.z, 1, LOCH.w)
	var water := mesh_at(cyl(1.0, 1.0, 0.1, 32), mat("Loch Water", Color(0.35, 0.55, 0.7), 0.1, 0.15, 0.8), Vector3(0, WATER_Y - 0.05, 0), holder)
	water.scale = Vector3(LOCH.z, 1, LOCH.w)
	water.name = "Surface"
	var reed := mat("Reed", Color(0.45, 0.55, 0.3), 0.9)
	for k in 14:
		var a := k * TAU / 14.0 + rng.randf_range(-0.1, 0.1)
		mesh_at(cyl(0.03, 0.04, 1.1, 4), reed, Vector3(cos(a) * (LOCH.z + 0.3), 0.55, sin(a) * (LOCH.w + 0.3)), holder)


func _standing_stones() -> void:
	# The Standing Stones: a ring of tall old stones on a little rise, where the Stormram lies curled up asleep.
	# Wide gaps between them, so you can run in and out.
	var g := Node3D.new()
	g.name = "Standing Stones"
	g.position = STONES
	world.add_child(g)
	var stone := [mat("Stone", Color(0.6, 0.6, 0.62), 0.9), mat("Stone Dark", Color(0.48, 0.48, 0.52), 0.9)]
	var moss := mat("Moss", Color(0.38, 0.55, 0.3), 0.95)
	for k in 9:
		var a := k * TAU / 9.0 + 0.2
		var p := Vector3(cos(a), 0, sin(a)) * STONES_R
		var h := rng.randf_range(3.2, 4.6)
		var s := mesh_at(box(Vector3(1.2, h, 0.8)), stone[k % 2], p + Vector3(0, h / 2.0, 0), g, Vector3(0, -a, rng.randf_range(-0.06, 0.06)))
		s.name = "Stone"
		mesh_at(box(Vector3(1.25, 0.3, 0.85)), moss, p + Vector3(0, 0.15, 0), g, Vector3(0, -a, 0))
		box_solid(Vector3(1.2, h, 0.8), p + Vector3(0, h / 2.0, 0), g, -a)
	mesh_at(cyl(STONES_R - 1.0, STONES_R - 0.5, 0.1, 32), mat("Worn Grass", Color(0.55, 0.6, 0.4), 0.95), Vector3(0, 0.0, 0), g)
	_marker("Stormram", STONES + Vector3(0, 0.4, 0))


func _walls() -> void:
	# Dry stone dykes along the glen, the way highland fields are marked out (low: you can hop them)
	var g := Node3D.new()
	g.name = "Dry Stone Walls"
	world.add_child(g)
	var stone := [mat("Stone", Color(0.6, 0.6, 0.62), 0.9), mat("Stone Dark", Color(0.48, 0.48, 0.52), 0.9)]
	var runs := [[Vector3(-46, 0, -2), Vector3(-34, 0, -6)], [Vector3(12, 0, -12), Vector3(30, 0, -14)],
		[Vector3(40, 0, 30), Vector3(44, 0, 14)], [Vector3(-46, 0, 36), Vector3(-36, 0, 40)], [Vector3(12, 0, 40), Vector3(26, 0, 36)]]
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var n := int(a.distance_to(b) / 1.2)
		var yaw := atan2(b.x - a.x, b.z - a.z)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			mesh_at(box(Vector3(0.7, 0.8, 1.3)), stone[k % 2], p + Vector3(0, 0.4, 0), g, Vector3(0, yaw + rng.randf_range(-0.05, 0.05), 0))
		box_solid(Vector3(0.7, 0.8, a.distance_to(b)), (a + b) / 2.0 + Vector3(0, 0.4, 0), g, yaw)


func _tree(at: Vector3, k: int) -> void:
	# A rowan tree: a crooked trunk and round puffs of leaves (scripts/glenmoor.gd turns the "Leaves" with the seasons:
	# blossom, deep green, red and gold, bare with snow), with red berries
	var g := Node3D.new()
	g.name = "Rowan %d" % (k + 1)
	g.position = at
	world.add_child(g)
	var bark := mat("Bark", Color(0.42, 0.33, 0.28), 0.9)
	var leaves := mat("Leaves", Color(0.4, 0.7, 0.35), 0.85)
	var h := rng.randf_range(3.6, 5.0)
	mesh_at(cyl(0.18, 0.28, h, 7), bark, Vector3(0, h / 2.0, 0), g, Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)))
	cyl_solid(0.3, h, Vector3(0, h / 2.0, 0), g)
	for l in 5:
		var a := l * TAU / 5.0 + rng.randf()
		var p := Vector3(cos(a) * 1.1, h + rng.randf_range(-0.3, 0.5), sin(a) * 1.1)
		var puff := mesh_at(ball(1.1, 10), leaves, p, g)
		puff.name = "Leaf Puff"
		puff.scale = Vector3(1.0, 0.8, 1.0)
	var cap := mesh_at(ball(1.0, 10), mat("Snow Cap", Color(0.95, 0.97, 1.0), 0.8), Vector3(0, h + 0.9, 0), g)
	cap.scale = Vector3(1.6, 0.35, 1.6)
	cap.name = "Snow Cap"


func _heather_and_flowers() -> void:
	# Purple heather in clumps everywhere (Glenmoor's own flower, and Heather's name), yellow gorse bushes, and
	# wildflowers (no collision)
	var g := Node3D.new()
	g.name = "Heather and Wildflowers"
	world.add_child(g)
	var purple := [mat("Heather Bloom", Color(0.72, 0.4, 0.78), 0.9), mat("Heather Bloom Pale", Color(0.85, 0.6, 0.88), 0.9)]
	var gorse := mat("Gorse", Color(1.0, 0.85, 0.25), 0.8, 0.1)
	var gorse_green := mat("Gorse Green", Color(0.3, 0.45, 0.25), 0.9)
	var stem := mat("Flower Stem", Color(0.3, 0.6, 0.3), 0.9)
	var petals := [mat("Petal White", Color(1.0, 0.98, 0.95), 0.6, 0.1), mat("Petal Blue", Color(0.45, 0.6, 1.0), 0.6, 0.1),
		mat("Petal Pink", Color(1.0, 0.6, 0.75), 0.6, 0.1)]
	for c in 60:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 3.0)
		var centre := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(centre, 0.8):
			continue
		match c % 4:
			0, 1:
				for k in 4:
					var p := centre + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
					var b := mesh_at(ball(0.35, 8), purple[(c + k) % 2], p + Vector3(0, 0.15, 0), g)
					b.scale = Vector3(1.3, 0.75, 1.1)
			2:
				var b := mesh_at(ball(0.6, 8), gorse_green, centre + Vector3(0, 0.4, 0), g)
				b.scale = Vector3(1.3, 0.9, 1.2)
				for k in 8:
					var q := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.3, 0.9), rng.randf_range(-0.6, 0.6))
					mesh_at(ball(0.1, 6), gorse, centre + q, g)
			3:
				for k in 5:
					var p := centre + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
					mesh_at(cyl(0.04, 0.04, 0.4, 4), stem, p + Vector3(0, 0.2, 0), g)
					mesh_at(ball(0.1, 6), petals[(c + k) % 3], p + Vector3(0, 0.42, 0), g)


func _in_loch(p: Vector3, room: float) -> bool:
	var dx := (p.x - LOCH.x) / (LOCH.z + room)
	var dz := (p.z - LOCH.y) / (LOCH.w + room)
	return dx * dx + dz * dz < 1.0


func _blocked(p: Vector3, room: float) -> bool:
	var flat := Vector2(p.x, p.z)
	if _in_loch(p, room + 1.0):
		return true
	for c in [[HILL, HILL_R + 1.0], [FOLD, FOLD_R + 1.5], [CROFT, 9.0], [BARN, 9.0], [GARDEN, 9.0], [STONES, STONES_R + 2.0],
			[Vector3(0, 0, 34), 10.0], [RACE_START, 4.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	for t in TREES:
		if flat.distance_to(Vector2(t.x, t.z)) < 1.5 + room:
			return true
	return false
