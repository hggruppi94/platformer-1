extends SceneTree

# Builds res://scenes/portal_worlds/dark_hollow.tscn: Dark Hollow, the centipede's home world (plan items 19a world 7
# and 21). The opt-in scary world: there's no portal to it. You talk to the centipede in her corner Behind the Walls in
# the castle school (the Sliver: scripts/centipede_corner.gd), say yes, and she gulps you up and you slide down here.
# A misty, moonlit hollow, cozy-spooky, ringed by crooked trees, where shadows are eating up moments of time: the Moon
# Clock in the sky has three dark pieces missing and its hands are stuck at midnight. Three Moon Pieces mend it:
#   Piece1  the Ghost Glade (west): pop its eight shadow ghosts (lost bits of time) and their wisps gather into it
#   Piece2  on top of the Crooked Spire (north-east), too high and sheer to climb: jump into the Big Hole in the middle
#           and it spits you out up there
#   Piece3  the Hollow Run, a spooky race round the whole hollow (scripts/races.gd "hollow_run"): finish it
# With all three, the Hush (a big shadow ghost, scripts/the_hush.gd) wakes over Hush Hill (north) when you come near.
# Logic: scripts/dark_hollow.gd (on scripts/portal_world.gd), which makes the ghosts, the pieces, the moon lamps, the
# Hush, the Moon Clock, the centipede and the mist at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_dark_hollow.gd

const OUT := "res://scenes/portal_worlds/dark_hollow.tscn"
const FLOOR_R := 58.0                    # the hollow's edge, where the crooked trees and dark banks rise
const HOLE_R := 4.5                      # the Big Hole, right in the middle
const HOLE_DEPTH := 7.0
const SPIRE := Vector3(22, 0, -18)       # the Crooked Spire: sheer rock, its top only reached by the hole's spit
const SPIRE_TOP := 14.0
const SPIRE_R := 3.4
const GLADE := Vector3(-26, 0, -4)       # the Ghost Glade, where the shadow ghosts flicker about
const GLADE_R := 10.0
const HILL := Vector3(0, 0, -28)         # Hush Hill: where the Hush sleeps, curled up in a cloud of dark
const HILL_R := 7.0
const HILL_TOP := 0.6
const LAMP_R := 9.5                      # the four moon lamps round the hill
const SPOUTS := [Vector3(-15, 0, 20), Vector3(16, 0, 18), Vector3(-12, 0, -16)]     # little holes the Big Hole spits you out of
# The Hollow Run's checkpoints (scripts/races.gd TRACKS "hollow_run" has the same): a wiggly ring round the hollow,
# starting on the south side heading west. Nothing solid is built near it.
const TRACK := [Vector2(8, 40), Vector2(-14, 40), Vector2(-32, 30), Vector2(-43, 12), Vector2(-45, -8),
	Vector2(-38, -28), Vector2(-22, -41), Vector2(0, -45), Vector2(22, -41), Vector2(38, -28), Vector2(45, -8),
	Vector2(43, 12), Vector2(32, 30), Vector2(18, 39)]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}                         # shared meshes, so the scene file stays small


func _initialize() -> void:
	rng.seed = 77
	world = Node3D.new()
	world.name = "Dark Hollow"
	world.set_script(load("res://scripts/dark_hollow.gd"))
	world.set("world_id", "dark_hollow")
	world.set("fall_below", -30.0)                   # (the Big Hole catches you long before this)
	world.set_meta("preview_radius", 40.0)
	world.set_meta("always_night", true)              # (Pip's glow shines here: scripts/pip_glow.gd)
	_environment()
	_floor()
	_hole()
	_edge()
	_spire()
	_glade()
	_hill()
	_spouts()
	_nest()
	_crooked_trees()
	_mushrooms()
	_track_lamps()
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		var d := 3.0 + (i % 3) * 2.2
		_marker("Ghost%d" % (i + 1), GLADE + Vector3(cos(a) * d, 0.0, sin(a) * d))
	_marker("Piece1", GLADE + Vector3(0, 1.4, 0))
	_marker("Piece2", SPIRE + Vector3(0, SPIRE_TOP + 1.2, 0))
	_marker("Spout1", SPIRE + Vector3(0, SPIRE_TOP, 0))                # the first spit always lands you up here
	for i in SPOUTS.size():
		_marker("Spout%d" % (i + 2), SPOUTS[i])
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		_marker("Lamp%d" % (i + 1), HILL + Vector3(cos(a), 0, sin(a)) * LAMP_R)
	_marker("Hush", HILL + Vector3(0, HILL_TOP, 0))
	_marker("MoonClock", Vector3(0, 62, -150))
	_marker("Centipede", Vector3(-9.0, 0, 47.0)).rotation.y = atan2(9.0, -47.0)
	_marker("TimeStone", Vector3(-15.0, 0, 50.0))
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(10.0, 0, 51.0)).rotation.y = atan2(-10.0, -51.0)
	_marker("Vein1", Vector3(34, 0, 6))
	_marker("PreviewCentre", Vector3(0, 3, -6))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 50.0))      # facing in, towards the hollow (-Z)
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
	h = maxf(snappedf(h, 0.1), 0.04)            # (snapping a thin disc to 0 leaves a cylinder with no height)
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
	# A deep blue-violet midnight with a lot of soft mist (scripts/dark_hollow.gd clears it a little once it's mended)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.04, 0.12)
	sky_mat.sky_horizon_color = Color(0.2, 0.17, 0.33)
	sky_mat.ground_horizon_color = Color(0.2, 0.17, 0.33)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.18)
	sky_mat.sun_angle_max = 10.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.62)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7                     # the mushrooms, eyes and wisps bloom softly
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.26, 0.26, 0.42)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.fog_height = 1.5                         # thick low mist hugging the ground, thinner higher up
	env.fog_height_density = 0.12
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	# Moonlight: pale blue, from the Moon Clock's side, enough to see by
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.66, 0.74, 1.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-38, 180, 0)
	world.add_child(moon)


func _floor() -> void:
	# The hollow's floor: a wide round of dark mossy ground with a round hole in the middle (a ring mesh, so the Big
	# Hole is a real hole), soft lighter patches of moss and a faint ring of pale stones round the hole
	var g := Node3D.new()
	g.name = "Hollow Floor"
	world.add_child(g)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var radii := [HOLE_R, 16.0, FLOOR_R + 8.0]
	for k in segs:
		var a0 := k * TAU / segs
		var a1 := (k + 1) * TAU / segs
		for r in radii.size() - 1:
			var r0: float = radii[r]
			var r1: float = radii[r + 1]
			var p00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p.x, p.z) * 0.1)
				st.add_vertex(p)
	var floor_mesh := st.commit()
	var fm := mesh_at(floor_mesh, mat("Hollow Moss", Color(0.11, 0.13, 0.2), 0.95), Vector3.ZERO, g)
	fm.name = "Ground"
	var body := StaticBody3D.new()
	body.name = "Ground Body"
	var cs := CollisionShape3D.new()
	cs.shape = floor_mesh.create_trimesh_shape()
	body.add_child(cs)
	g.add_child(body)
	var moss := mat("Soft Moss", Color(0.15, 0.2, 0.28), 0.95)
	for k in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, FLOOR_R - 6.0)
		var r := rng.randf_range(1.5, 4.0)
		mesh_at(cyl(r, r, 0.04, 16), moss, Vector3(cos(a) * d, 0.02, sin(a) * d), g)


func _hole() -> void:
	# The Big Hole: a deep round shaft with roots round its lip and a slow purple swirl far down at the bottom. It's
	# open: fall in and you drop through the swirl (scripts/dark_hollow.gd watches for you below HOLE_CATCH and spits
	# you out somewhere else). A low ring of old stones round the edge, with gaps, so you can't fall in by accident
	# without meaning to jump.
	var g := Node3D.new()
	g.name = "The Big Hole"
	world.add_child(g)
	var wall := CylinderMesh.new()
	wall.top_radius = HOLE_R
	wall.bottom_radius = HOLE_R - 0.6
	wall.height = HOLE_DEPTH
	wall.radial_segments = 40
	wall.cap_top = false
	wall.cap_bottom = false
	var wm := mat("Hole Wall", Color(0.06, 0.05, 0.1), 0.95)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_at(wall, wm, Vector3(0, -HOLE_DEPTH / 2.0, 0), g)
	var swirl := mesh_at(cyl(HOLE_R - 0.6, HOLE_R - 0.6, 0.04, 40), mat("Hole Swirl", Color(0.45, 0.25, 0.85), 0.5, 1.4),
		Vector3(0, -HOLE_DEPTH + 0.2, 0), g)
	swirl.name = "Swirl"
	var stone := mat("Old Stone", Color(0.3, 0.29, 0.4), 0.9)
	for k in 14:
		if k % 4 == 3:
			continue                                     # gaps to walk up to the lip through
		var a := k * TAU / 14.0
		var p := Vector3(cos(a), 0, sin(a)) * (HOLE_R + 0.7)
		var h := rng.randf_range(0.45, 0.8)
		mesh_at(box(Vector3(0.9, h, 0.5)), stone, p + Vector3(0, h / 2.0, 0), g, Vector3(0, -a + PI / 2.0, rng.randf_range(-0.12, 0.12)))
		var b := BoxShape3D.new()
		b.size = Vector3(0.9, h, 0.5)
		solid(b, p + Vector3(0, h / 2.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
	var root := mat("Root", Color(0.2, 0.14, 0.18), 0.9)
	for k in 9:                                          # roots curling over the lip and down the wall
		var a := k * TAU / 9.0 + 0.2
		var p := Vector3(cos(a), 0, sin(a)) * (HOLE_R - 0.15)
		mesh_at(cyl(0.08, 0.14, 2.4, 6), root, p + Vector3(0, -1.0, 0), g, Vector3(0.25 * sin(a * 3.0), 0, 0.2))
	var sign_post := mesh_at(cyl(0.07, 0.08, 1.6, 6), root, Vector3(0, 0.8, HOLE_R + 2.6), g)
	sign_post.name = "Sign Post"
	var sign := Label3D.new()
	sign.text = "THE BIG HOLE\n(jump in!)"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.modulate = Color(0.85, 0.8, 1.0)
	sign.position = Vector3(0, 2.0, HOLE_R + 2.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)
	var glow := OmniLight3D.new()
	glow.name = "Hole Glow"
	glow.light_color = Color(0.55, 0.35, 1.0)
	glow.light_energy = 2.0
	glow.omni_range = 9.0
	glow.position = Vector3(0, -3.0, 0)
	g.add_child(glow)


func _edge() -> void:
	# Dark banks round the edge with crooked tree silhouettes on top, and an invisible fence so nobody wanders off
	var g := Node3D.new()
	g.name = "Banks"
	world.add_child(g)
	var bank := mat("Bank", Color(0.08, 0.07, 0.14), 0.95)
	for k in 30:
		var a := k * TAU / 30.0 + rng.randf_range(-0.04, 0.04)
		var r := rng.randf_range(8.0, 12.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(4.0, 8.0))
		var h := mesh_at(ball(1.0, 16), bank, p, g)
		h.scale = Vector3(r, rng.randf_range(6.0, 13.0), r)
		_dead_tree(g, p + Vector3(0, h.scale.y * 0.8, 0) - p.normalized() * 2.0, rng.randf_range(1.4, 2.2), false)
	for k in 60:
		var a := k * TAU / 60.0
		var b := BoxShape3D.new()
		b.size = Vector3(6.4, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _dead_tree(parent: Node3D, at: Vector3, s: float, solid_trunk: bool) -> void:
	# A crooked bare tree: a leaning, twisting trunk and a few bent, spidery branches. Spooky, not scary.
	var g := Node3D.new()
	g.name = "Crooked Tree"
	g.position = at
	g.rotation.y = rng.randf() * TAU
	g.scale = Vector3.ONE * s
	parent.add_child(g)
	var bark := mat("Crooked Bark", Color(0.12, 0.09, 0.14), 0.9)
	var lean := rng.randf_range(-0.12, 0.12)
	mesh_at(cyl(0.16, 0.3, 2.2, 7), bark, Vector3(0, 1.1, 0), g, Vector3(lean, 0, 0))
	mesh_at(cyl(0.1, 0.16, 1.6, 6), bark, Vector3(0.1, 2.9, lean * 2.0), g, Vector3(-lean, 0, 0.22))
	for k in 4:
		var a := k * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
		var branch := Node3D.new()
		branch.position = Vector3(0, 2.0 + k * 0.4, 0)
		branch.rotation = Vector3(0, a, 0)
		g.add_child(branch)
		mesh_at(cyl(0.04, 0.08, 1.4, 5), bark, Vector3(0, 0.45, 0.45), branch, Vector3(0.9, 0, 0))
		mesh_at(cyl(0.02, 0.04, 0.8, 4), bark, Vector3(0, 1.05, 0.95), branch, Vector3(0.3, 0, 0))
	if solid_trunk:
		var c := CylinderShape3D.new()
		c.radius = 0.3 * s
		c.height = 2.6 * s
		solid(c, at + Vector3(0, 1.3 * s, 0), parent)


func _spire() -> void:
	# The Crooked Spire: a tall, leaning stack of dark rock, far too sheer to climb, with a flat top and a little stone
	# ring where the Moon Piece sits. The Big Hole spits you out on top of it.
	var g := Node3D.new()
	g.name = "Crooked Spire"
	g.position = SPIRE
	world.add_child(g)
	var rock := mat("Spire Rock", Color(0.16, 0.14, 0.24), 0.9)
	var top := mat("Spire Top", Color(0.24, 0.24, 0.36), 0.9)
	var heights := [0.0, 3.6, 7.0, 10.6]
	for k in heights.size():
		var h0: float = heights[k]
		var h1: float = heights[k + 1] if k + 1 < heights.size() else SPIRE_TOP
		var r := SPIRE_R + 0.4 - k * 0.15
		mesh_at(cyl(r - 0.2, r + 0.2, h1 - h0, 9), rock, Vector3(0.15 * sin(k * 1.7), (h0 + h1) / 2.0, 0.15 * cos(k * 2.1)), g,
			Vector3(0, k * 0.7, 0))
	cyl_solid(SPIRE_R + 0.2, SPIRE_TOP, Vector3(0, SPIRE_TOP / 2.0, 0), g)
	mesh_at(cyl(SPIRE_R + 0.5, SPIRE_R + 0.3, 0.4, 16), top, Vector3(0, SPIRE_TOP + 0.2, 0), g)
	cyl_solid(SPIRE_R + 0.5, 0.4, Vector3(0, SPIRE_TOP + 0.2, 0), g)
	var stone := mat("Old Stone", Color(0.3, 0.29, 0.4), 0.9)
	for k in 7:                                       # a ring of little standing stones on the top (not solid: room to move)
		var a := k * TAU / 7.0
		mesh_at(box(Vector3(0.35, 0.7, 0.25)), stone, Vector3(cos(a) * (SPIRE_R - 0.1), SPIRE_TOP + 0.75, sin(a) * (SPIRE_R - 0.1)), g,
			Vector3(0, -a, 0))
	var fungus := mat("Spire Fungus", Color(0.4, 1.0, 0.85), 0.5, 1.3)
	for k in 10:                                      # glowing shelf fungus up its sides
		var a := rng.randf() * TAU
		var y := rng.randf_range(1.5, SPIRE_TOP - 1.0)
		var shelf := mesh_at(cyl(0.45, 0.35, 0.08, 10), fungus, Vector3(cos(a) * (SPIRE_R + 0.45), y, sin(a) * (SPIRE_R + 0.45)), g)
		shelf.scale = Vector3(1.0, 1.0, 0.6)
		shelf.rotation.y = -a
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.85)
	light.light_energy = 1.0
	light.omni_range = 7.0
	light.position = Vector3(0, SPIRE_TOP + 2.0, 0)
	g.add_child(light)


func _glade() -> void:
	# The Ghost Glade: a ring of crooked trees round a clearing of old leaning stones and cobwebby stumps, with gaps
	# to walk in through. The shadow ghosts flicker about in here.
	var g := Node3D.new()
	g.name = "Ghost Glade"
	world.add_child(g)
	for k in 11:
		if k % 4 == 1:
			continue
		var a := k * TAU / 11.0
		_dead_tree(g, GLADE + Vector3(cos(a), 0, sin(a)) * (GLADE_R + 1.0), rng.randf_range(1.0, 1.4), true)
	var stone := mat("Old Stone", Color(0.3, 0.29, 0.4), 0.9)
	var web := mat("Cobweb", Color(0.85, 0.85, 0.95), 0.6, 0.15, 0.35)
	for k in 6:
		var a := k * TAU / 6.0 + 0.5
		var p := GLADE + Vector3(cos(a), 0, sin(a)) * rng.randf_range(5.5, 8.0)
		mesh_at(box(Vector3(0.6, 0.9, 0.2)), stone, p + Vector3(0, 0.4, 0), g, Vector3(rng.randf_range(-0.2, 0.2), -a, rng.randf_range(-0.15, 0.15)))
		mesh_at(box(Vector3(0.7, 0.5, 0.01)), web, p + Vector3(0, 0.95, 0), g, Vector3(0, -a, 0.3))
	var sign := Label3D.new()
	sign.text = "Ghost Glade"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.modulate = Color(0.75, 0.85, 1.0)
	sign.position = GLADE + Vector3(GLADE_R + 1.5, 2.6, 4.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)


func _hill() -> void:
	# Hush Hill: a low round mound with a crooked crown of stones, where the Hush sleeps in a cloud of dark
	var g := Node3D.new()
	g.name = "Hush Hill"
	g.position = HILL
	world.add_child(g)
	mesh_at(cyl(HILL_R, HILL_R + 1.2, HILL_TOP, 32), mat("Hill Moss", Color(0.13, 0.15, 0.24), 0.95), Vector3(0, HILL_TOP / 2.0, 0), g)
	var c := CylinderShape3D.new()
	c.radius = HILL_R + 0.6
	c.height = HILL_TOP
	solid(c, Vector3(0, HILL_TOP / 2.0, 0), g)
	var stone := mat("Old Stone", Color(0.3, 0.29, 0.4), 0.9)
	for k in 9:                                       # a crown of tall leaning stones round the top (not solid)
		var a := k * TAU / 9.0
		var h := rng.randf_range(1.6, 2.6)
		mesh_at(box(Vector3(0.5, h, 0.35)), stone, Vector3(cos(a), 0, sin(a)) * (HILL_R - 0.4) + Vector3(0, HILL_TOP + h / 2.0, 0), g,
			Vector3(rng.randf_range(-0.12, 0.12), -a, rng.randf_range(-0.15, 0.15)))


func _spouts() -> void:
	# Little round holes in the ground the Big Hole can spit you out of (the spire's top is the first one)
	var g := Node3D.new()
	g.name = "Spouts"
	world.add_child(g)
	var dark := mat("Spout Dark", Color(0.08, 0.04, 0.14), 0.6, 0.6)
	var rim := mat("Old Stone", Color(0.3, 0.29, 0.4), 0.9)
	for p in SPOUTS:
		mesh_at(cyl(1.0, 1.0, 0.04, 20), dark, p + Vector3(0, 0.03, 0), g)
		for k in 8:
			var a := k * TAU / 8.0
			mesh_at(box(Vector3(0.4, 0.2, 0.3)), rim, p + Vector3(cos(a) * 1.15, 0.1, sin(a) * 1.15), g, Vector3(0, -a, 0))


func _nest() -> void:
	# The centipede's home by the way in: a great hollow log, curled round with moss, glowing mushrooms on top
	var g := Node3D.new()
	g.name = "Hollow Log"
	g.position = Vector3(-21.0, 0, 50.0)
	g.rotation.y = 0.35
	world.add_child(g)
	var bark := mat("Log Bark", Color(0.22, 0.15, 0.16), 0.9)
	var inside := mat("Log Inside", Color(0.08, 0.05, 0.08), 0.95)
	mesh_at(cyl(1.3, 1.3, 6.0, 14), bark, Vector3(0, 1.2, 0), g, Vector3(0, 0, PI / 2.0))
	mesh_at(cyl(1.0, 1.0, 0.05, 14), inside, Vector3(3.02, 1.2, 0), g, Vector3(0, 0, PI / 2.0))
	var b := BoxShape3D.new()
	b.size = Vector3(6.0, 2.4, 2.4)
	solid(b, Vector3(0, 1.2, 0), g)
	var cap := mat("Mushroom Teal", Color(0.4, 1.0, 0.9), 0.5, 1.2)
	for k in 5:
		mesh_at(ball(0.25 + k * 0.03, 10), cap, Vector3(-2.2 + k * 1.0, 2.5, rng.randf_range(-0.3, 0.3)), g).scale = Vector3(1, 0.5, 1)


func _blocked(p: Vector3, room: float) -> bool:
	var flat := Vector2(p.x, p.z)
	for q in TRACK:
		if flat.distance_to(q) < 6.0 + room:
			return true
	for i in TRACK.size():                            # and the lines between the checkpoints
		var a: Vector2 = TRACK[i]
		var b: Vector2 = TRACK[(i + 1) % TRACK.size()]
		var t := clampf((flat - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if flat.distance_to(a.lerp(b, t)) < 6.0 + room:
			return true
	for c in [[Vector3.ZERO, HOLE_R + 3.0], [SPIRE, SPIRE_R + 2.0], [GLADE, GLADE_R + 2.5], [HILL, LAMP_R + 3.0],
			[Vector3(0, 0, 50), 9.0], [Vector3(-21, 0, 50), 4.5], [Vector3(34, 0, 6), 2.0]]:
		if flat.distance_to(Vector2(c[0].x, c[0].z)) < float(c[1]) + room:
			return true
	for s in SPOUTS:
		if flat.distance_to(Vector2(s.x, s.z)) < 2.5 + room:
			return true
	return false


func _crooked_trees() -> void:
	# Crooked trees dotted round the hollow (kept off the track and everything else)
	var g := Node3D.new()
	g.name = "Crooked Trees"
	world.add_child(g)
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 800:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(8.0, FLOOR_R - 3.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(p, 1.5):
			continue
		_dead_tree(g, p, rng.randf_range(1.0, 1.5), true)
		placed += 1


func _mushrooms() -> void:
	# Clusters of glowing mushrooms: the hollow's night lights (teal, violet and a soft pink), a few with a real light
	var g := Node3D.new()
	g.name = "Glow Mushrooms"
	world.add_child(g)
	var cols := [Color(0.4, 1.0, 0.9), Color(0.75, 0.55, 1.0), Color(1.0, 0.6, 0.85)]
	var stalk := mat("Mushroom Stalk", Color(0.75, 0.75, 0.85), 0.8, 0.2)
	var placed := 0
	var tries := 0
	while placed < 30 and tries < 800:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, FLOOR_R - 4.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(p, 0.0) and not Vector2(p.x - GLADE.x, p.z - GLADE.z).length() < GLADE_R:
			continue
		var c: Color = cols[placed % 3]
		var cap := mat("Mushroom %d" % (placed % 3), c, 0.5, 1.3)
		for k in rng.randi_range(2, 4):
			var q := p + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			var h := rng.randf_range(0.2, 0.55)
			mesh_at(cyl(0.04, 0.06, h, 5), stalk, q + Vector3(0, h / 2.0, 0), g)
			mesh_at(ball(0.16 + h * 0.3, 10), cap, q + Vector3(0, h, 0), g).scale = Vector3(1, 0.55, 1)
		if placed % 5 == 0:
			var light := OmniLight3D.new()
			light.light_color = c
			light.light_energy = 0.8
			light.omni_range = 5.0
			light.position = p + Vector3(0, 0.8, 0)
			g.add_child(light)
		placed += 1


func _track_lamps() -> void:
	# Little crooked lamp posts along the Hollow Run, outside its lanes, so you can see where it goes in the dark
	var g := Node3D.new()
	g.name = "Run Lamps"
	world.add_child(g)
	var post := mat("Lamp Post", Color(0.15, 0.12, 0.18), 0.8)
	var flame := mat("Lamp Flame", Color(0.55, 1.0, 0.8), 0.4, 1.6)
	for i in TRACK.size():
		var a: Vector2 = TRACK[i]
		var b: Vector2 = TRACK[(i + 1) % TRACK.size()]
		var mid := a.lerp(b, 0.5)
		var out := mid.normalized() * 6.5                 # outside the ring, clear of the lanes
		var p := Vector3(mid.x + out.x, 0, mid.y + out.y)
		mesh_at(cyl(0.05, 0.07, 2.2, 6), post, p + Vector3(0, 1.1, 0), g, Vector3(0, 0, 0.12))
		mesh_at(ball(0.18, 10), flame, p + Vector3(0.14, 2.25, 0), g)
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.light_color = Color(0.55, 1.0, 0.8)
			light.light_energy = 0.9
			light.omni_range = 7.0
			light.position = p + Vector3(0.14, 2.3, 0)
			g.add_child(light)
