extends SceneTree

# Builds res://scenes/portal_worlds/rootmind.tscn: the Rootmind, Bramble's home world (plan items 19a world 1 and 22).
# A round clearing on a hive-mind plant world, walled in by giant stems with huge leaves overhead, where every plant
# has eyes and they all blink together in waves. Time here is running backwards: the blooms have closed up, petals
# drift *up* off the ground back towards them, and the hive's newest seedling is shrinking back into a seed. The
# player wakes the three Sun Blooms (one up a spiral of giant leaves, with a leaf slide back down; one hidden in the
# tall grass that sways away as you brush through; one at the end of a tunnel of roots), then calms the Thornknot, a
# tangle of weeds out of step with the hive, by humming along each time the hive blinks. Logic: scripts/rootmind.gd
# (on scripts/portal_world.gd), which puts in the things made in code at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_rootmind.gd

const OUT := "res://scenes/portal_worlds/rootmind.tscn"
const FLOOR_R := 40.0                   # the clearing's edge, where the giant stems stand
const LEAF_STEM := Vector3(-24, 0, -6)  # the giant stem the spiral of leaves climbs
const LEAF_RING := 4.2                  # how far out from the stem the leaves stand
const LEAF_TURN := 0.8                  # radians round the stem from one leaf to the next
const LEAF_RISE := 1.1                  # metres up from one leaf to the next (an easy jump)
const LEAF_COUNT := 8
const MEADOW := Vector3(24, 0, -4)      # the tall grass, with the Whisper Bloom hidden in the middle
const MEADOW_R := 8.0
const TUNNEL_FROM := -16.0              # the root tunnel runs along -Z from here...
const TUNNEL_TO := -28.0                # ...to here, and the Root Bloom waits just past it
const TUNNEL_HALF := 3.2

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}                        # shared meshes, so the scene file stays small


func _initialize() -> void:
	rng.seed = 7
	world = Node3D.new()
	world.name = "Rootmind"
	world.set_script(load("res://scripts/rootmind.gd"))
	world.set("world_id", "rootmind")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 22.0)          # (under the canopy leaves)
	_environment()
	_floor()
	_edge()
	_canopy()
	_leaf_spiral()
	_meadow()
	_tunnel()
	_giant_buds()
	_eyeplants()
	_petals()
	# The Heart Glade in the middle: a mossy mound with the seedling on it, and the Thornknot coiled round it
	mesh_at(cyl(3.6, 4.0, 0.5, 24), mat("Mound Moss", Color(0.26, 0.48, 0.2), 0.95), Vector3(0, 0.25, 0), world)
	var mound := CylinderShape3D.new()
	mound.radius = 4.0
	mound.height = 0.5
	solid(mound, Vector3(0, 0.25, 0), world).name = "Mound"
	_marker("Seedling", Vector3(0, 0.5, 0))
	_marker("Thornknot", Vector3(0, 0, 0))
	_marker("Bloom1", _leaf_at(LEAF_COUNT) + Vector3(0, 0.15, 0))
	_marker("Bloom2", MEADOW)
	_marker("Bloom3", Vector3(0, 0, TUNNEL_TO - 3.5))
	_slide()
	_marker("TimeStone", Vector3(6.5, 0, 23))
	_marker("Bramble", Vector3(3.5, 0, 20.5)).rotation.y = atan2(-3.5, 5.5)
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(-7.5, 0, 27)).rotation.y = atan2(7.5, -27.0)
	_marker("Vein1", Vector3(5.5, 0, TUNNEL_TO - 3.0))
	_marker("PreviewCentre", Vector3(0, 3, -4))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 27))     # facing in, towards the Heart Glade (-Z)
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


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.5, 0.46)
	sky_mat.sky_horizon_color = Color(0.9, 0.76, 0.48)
	sky_mat.ground_horizon_color = Color(0.85, 0.72, 0.46)
	sky_mat.ground_bottom_color = Color(0.32, 0.42, 0.26)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Half the ambient light from a warm green-gold, so the shade under the big leaves stays bright and friendly
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.85, 0.9, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.5)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.78)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-58, 25, 0)
	world.add_child(sun)


func _floor() -> void:
	# A wide round floor of moss, with soft clover patches and a few roots snaking over it
	var g := Node3D.new()
	g.name = "Floor"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 4.0, FLOOR_R + 4.0, 1.0, 48), mat("Moss", Color(0.2, 0.4, 0.17), 0.95), Vector3(0, -0.5, 0), g)
	var shape := CylinderShape3D.new()
	shape.radius = FLOOR_R + 4.0
	shape.height = 1.0
	solid(shape, Vector3(0, -0.5, 0), g)
	var clover := mat("Clover", Color(0.28, 0.5, 0.2), 0.9)
	for k in 30:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 4.0)
		var r := rng.randf_range(1.2, 3.0)
		mesh_at(cyl(r, r, 0.04, 16), clover, Vector3(cos(a) * d, 0.02, sin(a) * d), g)
	var root := mat("Root", Color(0.45, 0.32, 0.22), 0.9)
	for k in 9:
		var a := k * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var from := Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.0)
		var to := Vector3(cos(a + 0.3), 0, sin(a + 0.3)) * rng.randf_range(16.0, 24.0)
		var mid := (from + to) / 2.0
		var len := from.distance_to(to)
		var m := mesh_at(cyl(0.25, 0.45, len, 8), root, mid + Vector3(0, 0.1, 0), g)
		m.look_at_from_position(m.position, to + Vector3(0, 0.1, 0), Vector3.UP)
		m.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _edge() -> void:
	# Giant stems round the edge (solid), with an invisible fence between them so nobody wanders off the world
	var g := Node3D.new()
	g.name = "Giant Stems"
	world.add_child(g)
	var stem := mat("Giant Stem", Color(0.26, 0.46, 0.2), 0.8)
	var leaf := mat("Giant Leaf", Color(0.32, 0.62, 0.22), 0.7)
	for k in 26:
		var a := k * TAU / 26.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(1.3, 2.0)
		var h := rng.randf_range(18.0, 28.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(-0.5, 1.5))
		mesh_at(cyl(r * 0.6, r, h, 10), stem, p + Vector3(0, h / 2.0, 0), g)
		var c := CylinderShape3D.new()
		c.radius = r
		c.height = h
		solid(c, p + Vector3(0, h / 2.0, 0), g)
		# A huge leaf leaning in from the top of each
		var lf := mesh_at(ball(1.0, 12), leaf, p * 0.86 + Vector3(0, h - 1.0, 0), g)
		lf.scale = Vector3(5.0, 0.25, 2.6)
		lf.rotation = Vector3(0, -a, 0.25)
		lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 48:
		var a := k * TAU / 48.0
		var b := BoxShape3D.new()
		b.size = Vector3(5.6, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.2) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _canopy() -> void:
	# Big leaves high overhead: sunlight comes through between them (they cast no shadow, so it stays bright)
	var g := Node3D.new()
	g.name = "Canopy"
	world.add_child(g)
	var leaf := mat("Canopy Leaf", Color(0.36, 0.66, 0.24), 0.7, 0.0, 0.85)
	var vein := mat("Leaf Vein", Color(0.7, 0.92, 0.45), 0.7)
	for k in 9:
		var a := k * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(16.0, 30.0)
		var p := Vector3(cos(a) * d, rng.randf_range(17.0, 23.0), sin(a) * d)
		var lf := mesh_at(ball(1.0, 14), leaf, p, g)
		lf.scale = Vector3(rng.randf_range(7.0, 10.0), 0.18, rng.randf_range(3.5, 5.0))
		lf.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var v := mesh_at(BoxMesh.new(), vein, Vector3(0, 0.6, 0), lf)
		v.scale = Vector3(1.8, 0.4, 0.04)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _leaf_at(k: int) -> Vector3:
	# The top of leaf k of the spiral round the giant stem (the last one, LEAF_COUNT, is the big top leaf)
	var to_middle := atan2(-LEAF_STEM.z, -LEAF_STEM.x)
	var a := to_middle + k * LEAF_TURN
	var out := LEAF_RING + (0.6 if k == LEAF_COUNT else 0.0)
	return LEAF_STEM + Vector3(cos(a) * out, 0.9 + k * LEAF_RISE, sin(a) * out)


func _leaf_spiral() -> void:
	# A giant stem with leaves sticking out round it in a spiral, each a short jump up from the last
	var g := Node3D.new()
	g.name = "Leaf Climb"
	world.add_child(g)
	var stem := mat("Giant Stem", Color.WHITE)
	var h := 16.0
	mesh_at(cyl(1.6, 2.4, h, 14), stem, LEAF_STEM + Vector3(0, h / 2.0, 0), g)
	var c := CylinderShape3D.new()
	c.radius = 2.4
	c.height = h
	solid(c, LEAF_STEM + Vector3(0, h / 2.0, 0), g)
	var leaf := mat("Step Leaf", Color(0.5, 0.78, 0.22), 0.6)
	for k in LEAF_COUNT + 1:
		var top := k == LEAF_COUNT
		var r := 2.8 if top else 1.6
		var p := _leaf_at(k)
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = 0.3
		var body := solid(shape, p - Vector3(0, 0.15, 0), g)
		body.name = "Leaf"
		var m := mesh_at(ball(1.0, 12), leaf, Vector3.ZERO, body)
		m.scale = Vector3(r * 1.15, 0.16, r)
		m.rotation.y = atan2(p.x - LEAF_STEM.x, p.z - LEAF_STEM.z)
		# A little stalk joining it to the stem
		var mid := (p + Vector3(LEAF_STEM.x, p.y, LEAF_STEM.z)) / 2.0
		var s := mesh_at(cyl(0.14, 0.18, LEAF_RING, 6), stem, mid - Vector3(0, 0.2, 0), g)
		s.look_at_from_position(s.position, Vector3(LEAF_STEM.x, p.y - 0.2, LEAF_STEM.z), Vector3.UP)
		s.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _slide() -> void:
	# The leaf slide: a long vine curling down from the top leaf to the floor near the Heart Glade. Interact at the top
	# rides a leaf down it (scripts/rootmind.gd); the path is kept on the marker
	var top := _leaf_at(LEAF_COUNT)
	var outward := (Vector3(top.x, 0, top.z) - Vector3(LEAF_STEM.x, 0, LEAF_STEM.z)).normalized()
	var start := top + outward * 1.8 + Vector3(0, 0.3, 0)
	var land := Vector3(-9.0, 0.3, 3.0)
	var path := PackedVector3Array()
	for k in 25:
		var t := float(k) / 24.0
		var p := start.lerp(land, t)
		p.y = lerpf(start.y, land.y, t * t * (3.0 - 2.0 * t)) + sin(t * PI) * 1.5
		var side := (land - start).cross(Vector3.UP).normalized()
		p += side * sin(t * PI * 2.0) * 3.0
		path.append(p)
	var m := _marker("Slide", start)
	m.set_meta("path", path)
	var vine := mat("Slide Vine", Color(0.4, 0.66, 0.25), 0.7)
	var g := Node3D.new()
	g.name = "Slide Vine"
	world.add_child(g)
	for k in path.size() - 1:
		var a := path[k] - Vector3(0, 0.35, 0)
		var b := path[k + 1] - Vector3(0, 0.35, 0)
		var s := mesh_at(cyl(0.22, 0.22, a.distance_to(b) + 0.1, 8), vine, (a + b) / 2.0, g)
		s.look_at_from_position(s.position, b, Vector3.UP)
		s.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if k % 3 == 0:
			var lf := mesh_at(ball(0.4, 8), mat("Step Leaf", Color.WHITE), a + Vector3(0, 0.1, 0), g)
			lf.scale = Vector3(1.4, 0.2, 0.7)


func _meadow() -> void:
	# Tall grass taller than a kid, each blade on a pivot at the ground so it can bend away as you brush through it
	var g := Node3D.new()
	g.name = "Tall Meadow"
	g.position = MEADOW
	world.add_child(g)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.16, 2.6, 0.05)
	var greens := [mat("Grass A", Color(0.38, 0.66, 0.22), 0.8), mat("Grass B", Color(0.5, 0.74, 0.26), 0.8),
		mat("Grass C", Color(0.3, 0.56, 0.26), 0.8)]
	var n := 0
	while n < 210:
		var p := Vector2(rng.randf_range(-MEADOW_R, MEADOW_R), rng.randf_range(-MEADOW_R, MEADOW_R))
		if p.length() > MEADOW_R or p.length() < 1.6:
			continue
		var pivot := Node3D.new()
		pivot.name = "Blade"
		pivot.position = Vector3(p.x, 0, p.y)
		pivot.rotation.y = rng.randf() * TAU
		g.add_child(pivot)
		var m := mesh_at(blade, greens[n % 3], Vector3(0, 1.3, 0), pivot)
		m.scale.y = rng.randf_range(0.8, 1.2)
		m.position.y *= m.scale.y
		n += 1


func _tunnel() -> void:
	# A tunnel of arching roots, with walls you can't walk through, ending in a little hollow for the Root Bloom
	var g := Node3D.new()
	g.name = "Root Tunnel"
	world.add_child(g)
	var root := mat("Root", Color.WHITE)
	var arch := TorusMesh.new()
	arch.inner_radius = TUNNEL_HALF - 0.35
	arch.outer_radius = TUNNEL_HALF + 0.35
	arch.rings = 16
	arch.ring_segments = 8
	var z := TUNNEL_FROM
	while z >= TUNNEL_TO:
		mesh_at(arch, root, Vector3(0, 0, z), g, Vector3(PI / 2.0, 0, 0))
		z -= 2.4
	var length := absf(TUNNEL_TO - TUNNEL_FROM) + 1.0
	for side in [-1.0, 1.0]:
		var b := BoxShape3D.new()
		b.size = Vector3(0.6, 4.0, length)
		solid(b, Vector3(side * (TUNNEL_HALF + 0.2), 2.0, (TUNNEL_FROM + TUNNEL_TO) / 2.0), g)
		var wall := mesh_at(BoxMesh.new(), mat("Root Wall", Color(0.38, 0.27, 0.2), 0.95),
			Vector3(side * (TUNNEL_HALF + 0.4), 1.6, (TUNNEL_FROM + TUNNEL_TO) / 2.0), g)
		wall.scale = Vector3(0.5, 3.2, length)
	# The hollow at the end: a ring of roots round the bloom, open towards the tunnel
	var end := Vector3(0, 0, TUNNEL_TO - 3.5)
	for k in 9:
		var a := PI / 2.0 + 0.5 + k * (TAU - 1.0) / 8.0
		var p := end + Vector3(cos(a), 0, sin(a)) * 4.0
		mesh_at(cyl(0.3, 0.6, 3.5, 8), root, p + Vector3(0, 1.75, 0), g, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
		var c := CylinderShape3D.new()
		c.radius = 0.6
		c.height = 3.5
		solid(c, p + Vector3(0, 1.75, 0), g)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 1.2
	glow.omni_range = 9.0
	glow.position = Vector3(0, 2.5, (TUNNEL_FROM + TUNNEL_TO) / 2.0)
	g.add_child(glow)


func _giant_buds() -> void:
	# Huge flowers round the clearing, shut tight while time runs backwards (scripts/rootmind.gd opens them when it's
	# mended: each has a closed Bud and a hidden Open flower)
	var g := Node3D.new()
	g.name = "Giant Buds"
	world.add_child(g)
	var stem := mat("Giant Stem", Color.WHITE)
	var colours := [Color(1.0, 0.55, 0.75), Color(0.75, 0.55, 1.0), Color(1.0, 0.8, 0.35), Color(0.55, 0.8, 1.0)]
	for k in 10:
		var a := k * TAU / 10.0 + 0.3
		var d := rng.randf_range(29.0, 34.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := rng.randf_range(6.0, 10.0)
		var flower := Node3D.new()
		flower.name = "Giant Flower"
		flower.position = p
		g.add_child(flower)
		mesh_at(cyl(0.3, 0.45, h, 8), stem, Vector3(0, h / 2.0, 0), flower)
		var col: Color = colours[k % colours.size()]
		var petal := mat("Petal %d" % (k % colours.size()), col, 0.6, 0.15)
		var bud := mesh_at(ball(1.0, 12), petal, Vector3(0, h + 1.2, 0), flower)
		bud.name = "Bud"
		bud.scale = Vector3(1.1, 1.8, 1.1)
		var open := Node3D.new()
		open.name = "Open"
		open.position = Vector3(0, h + 0.6, 0)
		open.visible = false
		flower.add_child(open)
		for j in 6:
			var pa := j * TAU / 6.0
			var pm := mesh_at(ball(1.0, 10), petal, Vector3(cos(pa) * 1.4, 0.3, sin(pa) * 1.4), open, Vector3(0, -pa, 0.5))
			pm.scale = Vector3(1.6, 0.25, 0.9)
		mesh_at(ball(0.8, 10), mat("Flower Heart", Color(1.0, 0.9, 0.4), 0.5, 0.6), Vector3(0, 0.5, 0), open)


func _eyeplants() -> void:
	# Every plant here has eyes. Little flowers, ferny tufts and a few tall ones, each with a Head that turns to watch
	# the player and two eyes that blink together with the whole hive (scripts/rootmind.gd)
	var g := Node3D.new()
	g.name = "Eyeplants"
	world.add_child(g)
	var spots: Array = []
	for k in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(7.0, FLOOR_R - 3.0)
		spots.append(Vector3(cos(a) * d, 0, sin(a) * d))
	# Along the root tunnel's walls, and round the Heart Glade
	var z := TUNNEL_FROM - 0.8
	while z >= TUNNEL_TO:
		for side in [-1.0, 1.0]:
			spots.append(Vector3(side * (TUNNEL_HALF - 0.5), 0, z))
		z -= 3.0
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		spots.append(Vector3(cos(a), 0, sin(a)) * 8.0)
	var colours := [Color(1.0, 0.55, 0.75), Color(0.75, 0.55, 1.0), Color(1.0, 0.8, 0.35), Color(0.55, 0.8, 1.0),
		Color(1.0, 0.65, 0.4)]
	var stem := mat("Eyeplant Stem", Color(0.4, 0.65, 0.3), 0.8)
	var white := mat("Eye White", Color(0.98, 0.98, 0.95), 0.3)
	var pupil := mat("Pupil", Color(0.08, 0.06, 0.12), 0.2)
	for i in spots.size():
		var p: Vector3 = spots[i]
		if _blocked(p):
			continue
		var tall := i % 9 == 0
		var h := rng.randf_range(3.0, 4.5) if tall else rng.randf_range(0.6, 1.4)
		var size := 2.2 if tall else rng.randf_range(0.8, 1.2)
		var plant := Node3D.new()
		plant.name = "Eyeplant"
		plant.position = p
		g.add_child(plant)
		mesh_at(cyl(0.04 * size, 0.07 * size, h, 6), stem, Vector3(0, h / 2.0, 0), plant)
		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0, h, 0)
		head.scale = Vector3.ONE * size
		plant.add_child(head)
		var col: Color = colours[i % colours.size()]
		var petals := mat("Eyeplant Petal %d" % (i % colours.size()), col, 0.6)
		for j in 5:
			var pa := j * TAU / 5.0
			var pm := mesh_at(ball(0.16, 8), petals, Vector3(cos(pa) * 0.2, sin(pa) * 0.2, -0.02), head)
			pm.scale = Vector3(1.0, 1.0, 0.35)
		var face := mesh_at(ball(0.17, 10), mat("Eyeplant Face", Color(0.6, 0.85, 0.4), 0.7), Vector3.ZERO, head)
		face.scale = Vector3(1.0, 1.0, 0.6)
		for side in [-1.0, 1.0]:
			var eye := Node3D.new()
			eye.name = "EyeL" if side < 0.0 else "EyeR"
			eye.position = Vector3(side * 0.075, 0.03, 0.08)
			head.add_child(eye)
			mesh_at(ball(0.065, 8), white, Vector3.ZERO, eye)
			mesh_at(ball(0.035, 6), pupil, Vector3(0, -0.005, 0.045), eye)


func _blocked(p: Vector3) -> bool:
	# Keep the eyeplants off the paths, the meadow, the leaf climb, the slide's landing and the arrival spot
	var flat := Vector2(p.x, p.z)
	if flat.distance_to(Vector2(LEAF_STEM.x, LEAF_STEM.z)) < LEAF_RING + 3.5:
		return true
	if flat.distance_to(Vector2(MEADOW.x, MEADOW.z)) < MEADOW_R + 1.0:
		return true
	if flat.distance_to(Vector2(0, 25)) < 8.0 or flat.distance_to(Vector2(-9, 3)) < 3.0:
		return true
	if absf(p.x) < TUNNEL_HALF + 1.5 and absf(p.x) > TUNNEL_HALF - 0.3 and p.z < TUNNEL_FROM + 2.0 and p.z > TUNNEL_TO:
		return true                                    # in the tunnel's walls
	if flat.distance_to(Vector2(0, TUNNEL_TO - 3.5)) < 5.0:
		return true                                    # the Root Bloom's hollow
	if absf(p.x) < 2.0 and p.z > 4.0:
		return true                                    # the path from the arrival to the Heart Glade
	return flat.length() < 6.5                       # the Thornknot's glade


func _petals() -> void:
	# Petals that drift UP off the floor, back towards the closed flowers: time running backwards (moved in code)
	var g := Node3D.new()
	g.name = "Backwards Petals"
	world.add_child(g)
	var colours := [Color(1.0, 0.6, 0.8), Color(0.8, 0.65, 1.0), Color(1.0, 0.85, 0.45)]
	for k in 36:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, 30.0)
		var m := mesh_at(ball(0.12, 6), mat("Drift Petal %d" % (k % 3), colours[k % 3], 0.6, 0.3),
			Vector3(cos(a) * d, rng.randf_range(0.2, 6.0), sin(a) * d), g, Vector3(rng.randf(), rng.randf(), rng.randf()))
		m.scale = Vector3(1.0, 0.25, 0.7)
		m.name = "Petal"
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
