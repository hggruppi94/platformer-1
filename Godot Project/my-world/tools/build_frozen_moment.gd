extends SceneTree

# Builds res://scenes/portal_worlds/frozen_moment.tscn: the Frozen Moment, Flurry's home world (plan items 19a world 2
# and 23). A snowy bowl under the mountains where time has stopped mid-moment: snowflakes hang in the air, a great
# clock in the sky is stuck on one tick, and three moments are frozen solid in ice (a fish leaping out of the lake, a
# snowball fight on top of Snowball Hill, a bird mid-flight in the icicle cave). The player thaws all three, which
# wakes the Frost Gloop frozen on its icy throne, the Gloop King's chilly cousin, who's been hoarding the moment.
# Pop it and time ticks on: the snow starts to fall. There's a frozen lake to slide (and skate) across, a hill of snowy
# steps with an ice slide back down, an icicle cave and soft snow drifts that slow you down. Logic:
# scripts/frozen_moment.gd (on scripts/portal_world.gd), which makes the moments, the Frost Gloop, the stuck clock,
# the hanging snowflakes and Flurry at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_frozen_moment.gd

const OUT := "res://scenes/portal_worlds/frozen_moment.tscn"
const FLOOR_R := 42.0                    # the bowl's edge, where the ice crags stand
const LAKE := Vector3(0, 0, -2)          # the frozen lake in the middle
const LAKE_R := 15.0
const HILL := Vector3(-26, 0, -6)        # Snowball Hill: snowy steps up, an ice slide down
const STEPS := [[9.0, 1.2], [7.0, 2.4], [5.0, 3.6], [3.4, 4.8]]   # radius, top: each an easy jump up from the last
const CAVE_FROM := 18.0                  # the icicle cave runs along +X from here...
const CAVE_TO := 34.0                    # ...to here
const CAVE_Z := -6.0
const CAVE_HALF := 3.2
const CAVE_H := 4.5
const THRONE := Vector3(0, 0, -24)       # where the Frost Gloop sits frozen
const DRIFTS := [Vector3(14, 0, 15), Vector3(-13, 0, 17), Vector3(-34, 0, 12), Vector3(33, 0, 11),
	Vector3(-33, 0, -24), Vector3(17, 0, -27), Vector3(-15, 0, -31)]
const SLIDE_PATH := [Vector3(-22.6, 5.0, -6.0), Vector3(-21.0, 4.4, -9.6), Vector3(-17.8, 3.3, -11.2),
	Vector3(-15.0, 2.3, -9.4), Vector3(-14.2, 1.3, -5.6), Vector3(-12.0, 0.25, -2.4)]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}                         # shared meshes, so the scene file stays small


func _initialize() -> void:
	rng.seed = 11
	world = Node3D.new()
	world.name = "Frozen Moment"
	world.set_script(load("res://scripts/frozen_moment.gd"))
	world.set("world_id", "frozen_moment")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 30.0)
	_environment()
	_floor()
	_lake()
	_edge()
	_pines()
	_hill()
	_slide()
	_cave()
	_drifts()
	_throne()
	_marker("Moment1", LAKE + Vector3(5.0, 0.1, -5.0))
	_marker("Moment2", HILL + Vector3(0, STEPS[-1][1], 0))
	_marker("Moment3", Vector3(CAVE_TO - 3.0, 0, CAVE_Z))
	_marker("FrostGloop", THRONE + Vector3(0, 1.2, 0))
	_marker("Clock", Vector3(0, 21, -40))
	_marker("Flurry", Vector3(4.0, 0, 25.0)).rotation.y = atan2(-4.0, -25.0) + PI
	_marker("TimeStone", Vector3(7.5, 0, 28))
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(-7.5, 0, 29)).rotation.y = atan2(7.5, -29.0)
	_marker("Vein1", HILL + Vector3(7.0, 0, 11.0))
	_marker("PreviewCentre", Vector3(0, 3, -6))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 30))      # facing in, towards the lake (-Z)
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


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.8)
	sky_mat.sky_horizon_color = Color(0.86, 0.85, 0.96)
	sky_mat.ground_horizon_color = Color(0.86, 0.88, 0.96)
	sky_mat.ground_bottom_color = Color(0.6, 0.66, 0.78)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88                  # snow everywhere: a touch darker so it isn't all one glare
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.85, 0.96)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	# A low winter sun, a little pink, so the snow isn't one flat white
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.9, 0.88)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38, 35, 0)
	world.add_child(sun)


func _floor() -> void:
	# A wide round floor of snow, with a few soft humps and sparkly patches on it
	var g := Node3D.new()
	g.name = "Snowfield"
	world.add_child(g)
	mesh_at(cyl(FLOOR_R + 6.0, FLOOR_R + 6.0, 1.0, 48), mat("Snow", Color(0.8, 0.84, 0.94), 0.9), Vector3(0, -0.5, 0), g)
	var shape := CylinderShape3D.new()
	shape.radius = FLOOR_R + 6.0
	shape.height = 1.0
	solid(shape, Vector3(0, -0.5, 0), g)
	var glint := mat("Snow Glint", Color(0.82, 0.88, 1.0), 0.4, 0.15)
	for k in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(LAKE_R + 3.0, FLOOR_R - 4.0)
		var r := rng.randf_range(1.0, 2.6)
		mesh_at(cyl(r, r, 0.04, 16), glint, Vector3(cos(a) * d, 0.02, sin(a) * d) + Vector3(LAKE.x, 0, LAKE.z), g)


func _lake() -> void:
	# The frozen lake: smooth blue ice with a lighter rim and pale cracks. Slippery (the "ice" group, player.gd on_ice())
	var g := Node3D.new()
	g.name = "Frozen Lake"
	world.add_child(g)
	g.position = LAKE
	mesh_at(cyl(LAKE_R + 1.2, LAKE_R + 1.6, 0.16, 48), mat("Lake Rim", Color(0.86, 0.92, 1.0), 0.5), Vector3(0, 0.02, 0), g)
	mesh_at(cyl(LAKE_R, LAKE_R, 0.16, 48), mat("Lake Ice", Color(0.55, 0.78, 0.95), 0.08, 0.05, 1.0, 0.1),
		Vector3(0, 0.05, 0), g)
	var shape := CylinderShape3D.new()
	shape.radius = LAKE_R + 1.0
	shape.height = 0.2
	var body := solid(shape, Vector3(0, 0.03, 0), g)
	body.name = "Ice"
	body.add_to_group("ice", true)
	var crack := mat("Ice Crack", Color(0.9, 0.96, 1.0), 0.2, 0.2)
	for k in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(2.0, LAKE_R - 3.0)
		var len := rng.randf_range(1.5, 4.0)
		mesh_at(box(Vector3(len, 0.02, 0.06)), crack, Vector3(cos(a) * d, 0.14, sin(a) * d), g,
			Vector3(0, rng.randf() * TAU, 0))


func _edge() -> void:
	# Tall ice crags round the edge (solid), with an invisible fence between them so nobody wanders off the world
	var g := Node3D.new()
	g.name = "Ice Crags"
	world.add_child(g)
	var crag := mat("Crag Ice", Color(0.7, 0.82, 0.95), 0.3, 0.05)
	var cap := mat("Crag Snow", Color(0.95, 0.96, 1.0), 0.9)
	for k in 30:
		var a := k * TAU / 30.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(3.0, 5.0)
		var h := rng.randf_range(14.0, 26.0)
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R + rng.randf_range(0.0, 3.0))
		mesh_at(cyl(0.0, r, h, 7), crag, p + Vector3(0, h / 2.0, 0), g, Vector3(0, rng.randf() * TAU, 0))
		mesh_at(cyl(0.0, r * 0.45, h * 0.3, 7), cap, p + Vector3(0, h * 0.85, 0), g)
		var c := CylinderShape3D.new()
		c.radius = r * 0.7
		c.height = h
		solid(c, p + Vector3(0, h / 2.0, 0), g)
	for k in 48:
		var a := k * TAU / 48.0
		var b := BoxShape3D.new()
		b.size = Vector3(5.8, 8.0, 0.6)
		var body := solid(b, Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.4) + Vector3(0, 4.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


func _pines() -> void:
	# Snowy pines dotted round the outside of the bowl (a trunk and three snowy tiers each)
	var g := Node3D.new()
	g.name = "Pines"
	world.add_child(g)
	var bark := mat("Pine Bark", Color(0.35, 0.26, 0.22), 0.9)
	var needles := mat("Pine Needles", Color(0.2, 0.42, 0.38), 0.85)
	var snow := mat("Snow", Color(0.8, 0.84, 0.94), 0.9)
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(30.0, FLOOR_R - 4.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(p, 4.0):
			continue
		placed += 1
		var s := rng.randf_range(0.8, 1.3)
		mesh_at(cyl(0.18 * s, 0.25 * s, 1.6 * s, 6), bark, p + Vector3(0, 0.8 * s, 0), g)
		for t in 3:
			var w := (2.0 - t * 0.55) * s
			var y := (1.6 + t * 1.3) * s
			mesh_at(cyl(0.0, w, 1.8 * s, 8), needles, p + Vector3(0, y + 0.9 * s, 0), g)
			mesh_at(cyl(0.0, w * 0.55, 0.6 * s, 8), snow, p + Vector3(0, y + 1.45 * s, 0), g)
		var c := CylinderShape3D.new()
		c.radius = 0.35 * s
		c.height = 3.0 * s
		solid(c, p + Vector3(0, 1.5 * s, 0), g)


func _blocked(p: Vector3, room: float) -> bool:
	# Keeps scenery off the lake, the hill, the cave, the throne, the drifts and the way in
	var flat := Vector2(p.x, p.z)
	if flat.distance_to(Vector2(LAKE.x, LAKE.z)) < LAKE_R + 2.0 + room:
		return true
	if flat.distance_to(Vector2(HILL.x, HILL.z)) < STEPS[0][0] + room:
		return true
	if p.x > CAVE_FROM - 3.0 - room and p.x < CAVE_TO + 3.0 + room and absf(p.z - CAVE_Z) < CAVE_HALF + 3.0 + room:
		return true
	if flat.distance_to(Vector2(THRONE.x, THRONE.z)) < 5.0 + room:
		return true
	for d in DRIFTS:
		if flat.distance_to(Vector2(d.x, d.z)) < 3.5 + room:
			return true
	return flat.distance_to(Vector2(0, 28)) < 9.0 + room


func _hill() -> void:
	# Snowball Hill: four round snowy steps, each an easy jump up from the last, with the frozen snowball fight on top
	var g := Node3D.new()
	g.name = "Snowfield Hill"                 # "Snowfield" in its name: soft snow underfoot (scripts/surfaces.gd)
	world.add_child(g)
	g.position = HILL
	var snow := mat("Snow", Color(0.8, 0.84, 0.94), 0.9)
	var side := mat("Hill Side", Color(0.8, 0.85, 0.95), 0.85)
	for s in STEPS:
		var r: float = s[0]
		var top: float = s[1]
		mesh_at(cyl(r, r + 0.4, top, 32), side, Vector3(0, top / 2.0, 0), g)
		mesh_at(cyl(r - 0.1, r - 0.1, 0.12, 32), snow, Vector3(0, top + 0.02, 0), g)
		var c := CylinderShape3D.new()
		c.radius = r
		c.height = top
		solid(c, Vector3(0, top / 2.0, 0), g)


func _slide() -> void:
	# The ice slide: a chute of ice curling from the top of Snowball Hill down to the lake. Interact at the top and you
	# ride it down (scripts/frozen_moment.gd slide_down(), along the "path" kept on the marker).
	var g := Node3D.new()
	g.name = "Ice Slide"
	world.add_child(g)
	var ice := mat("Slide Ice", Color(0.62, 0.84, 1.0), 0.1, 0.08, 0.92)
	var lip := mat("Slide Lip", Color(0.9, 0.95, 1.0), 0.3)
	for i in SLIDE_PATH.size() - 1:
		var a: Vector3 = SLIDE_PATH[i] - Vector3(0, 0.35, 0)
		var b: Vector3 = SLIDE_PATH[i + 1] - Vector3(0, 0.35, 0)
		var len := a.distance_to(b) + 0.4
		var mid := (a + b) / 2.0
		var chute := mesh_at(box(Vector3(1.6, 0.12, snappedf(len, 0.1))), ice, mid, g)
		chute.look_at_from_position(mid, b, Vector3.UP)
		for side in [-1, 1]:
			var rail := mesh_at(box(Vector3(0.14, 0.32, snappedf(len, 0.1))), lip, Vector3.ZERO, chute)
			rail.position = Vector3(side * 0.8, 0.16, 0)
	var m := _marker("Slide", SLIDE_PATH[0] - Vector3(0, 0.3, 0))
	m.set_meta("path", PackedVector3Array(SLIDE_PATH))


func _cave() -> void:
	# The icicle cave: a tunnel of blue ice with icicles hanging from its roof, the frozen bird at the far end
	var g := Node3D.new()
	g.name = "Icicle Cave"
	world.add_child(g)
	var wall := mat("Cave Ice", Color(0.55, 0.75, 0.95), 0.15, 0.12, 0.88)
	var outer := mat("Crag Ice", Color(0.7, 0.82, 0.95), 0.3, 0.05)
	var icicle := mat("Icicle", Color(0.82, 0.93, 1.0), 0.05, 0.25, 0.9)
	var len := CAVE_TO - CAVE_FROM
	var mid := Vector3((CAVE_FROM + CAVE_TO) / 2.0, 0, CAVE_Z)
	for side in [-1, 1]:
		var at := mid + Vector3(0, CAVE_H / 2.0, side * (CAVE_HALF + 0.5))
		mesh_at(box(Vector3(len, CAVE_H, 1.0)), wall, at, g)
		var b := BoxShape3D.new()
		b.size = Vector3(len, CAVE_H, 1.0)
		solid(b, at, g)
	var roof_at := mid + Vector3(0, CAVE_H + 0.4, 0)
	mesh_at(box(Vector3(len + 1.0, 0.8, CAVE_HALF * 2.0 + 2.0)), wall, roof_at, g)
	var rb := BoxShape3D.new()
	rb.size = Vector3(len + 1.0, 0.8, CAVE_HALF * 2.0 + 2.0)
	solid(rb, roof_at, g)
	var back_at := Vector3(CAVE_TO + 0.5, CAVE_H / 2.0, CAVE_Z)
	mesh_at(box(Vector3(1.0, CAVE_H, CAVE_HALF * 2.0 + 2.0)), wall, back_at, g)
	var bb := BoxShape3D.new()
	bb.size = Vector3(1.0, CAVE_H, CAVE_HALF * 2.0 + 2.0)
	solid(bb, back_at, g)
	# Rough lumps of ice heaped over it, so it reads as a cave in a glacier, not a box
	for k in 12:
		var x := lerpf(CAVE_FROM + 1.0, CAVE_TO, k / 11.0)
		var lump := mesh_at(ball(1.0, 10), outer, Vector3(x, CAVE_H + 0.6, CAVE_Z + rng.randf_range(-2.0, 2.0)), g)
		lump.scale = Vector3(rng.randf_range(2.0, 3.0), rng.randf_range(1.2, 2.2), rng.randf_range(2.6, 3.6))
	# Icicles from the roof inside, and along the mouth
	for k in 22:
		var x := rng.randf_range(CAVE_FROM + 0.3, CAVE_TO - 0.5)
		var z := CAVE_Z + rng.randf_range(-CAVE_HALF + 0.4, CAVE_HALF - 0.4)
		var h := rng.randf_range(0.5, 1.3)
		mesh_at(cyl(0.0, 0.16, h, 6), icicle, Vector3(x, CAVE_H - h / 2.0, z), g, Vector3(PI, 0, 0))
	var glow := OmniLight3D.new()
	glow.name = "Cave Glow"
	glow.light_color = Color(0.55, 0.8, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 10.0
	glow.position = mid + Vector3(2.0, CAVE_H - 1.0, 0)
	g.add_child(glow)


func _drifts() -> void:
	# Soft snow drifts: you sink in and wade slowly through (scripts/soft_zone.gd, kind "snow"); no collision
	var g := Node3D.new()
	g.name = "Snow Drifts"
	world.add_child(g)
	var snow := mat("Drift Snow", Color(0.86, 0.89, 0.97), 0.95)
	for i in DRIFTS.size():
		var p: Vector3 = DRIFTS[i]
		var zone := Area3D.new()
		zone.name = "Drift%d" % (i + 1)
		zone.set_script(load("res://scripts/soft_zone.gd"))
		zone.set("kind", "snow")
		zone.set("speed_scale", 0.55)
		zone.set("gravity_scale", 1.0)
		zone.set("fall_cap", 1000.0)
		zone.set("color", Color(1, 1, 1, 0.95))
		zone.position = p
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 3.0
		c.height = 2.0
		cs.shape = c
		cs.position.y = 1.0
		zone.add_child(cs)
		g.add_child(zone)
		var hump := mesh_at(ball(1.0, 16), snow, Vector3(0, 0.0, 0), zone)
		hump.scale = Vector3(3.3, 0.75, 3.0)


func _throne() -> void:
	# The Frost Gloop's throne: a round dais of packed ice the Gloop sits frozen on (scripts/frozen_moment.gd)
	var g := Node3D.new()
	g.name = "Frost Throne"
	world.add_child(g)
	g.position = THRONE
	mesh_at(cyl(4.2, 4.6, 0.6, 32), mat("Throne Ice", Color(0.62, 0.8, 0.98), 0.2, 0.08), Vector3(0, 0.3, 0), g)
	var c := CylinderShape3D.new()
	c.radius = 4.6
	c.height = 0.6
	var body := solid(c, Vector3(0, 0.3, 0), g)
	body.add_to_group("ice", true)
	var spike := mat("Icicle", Color(0.82, 0.93, 1.0), 0.05, 0.25, 0.9)
	for k in 9:
		var a := k * TAU / 9.0
		var h := 1.4 + (k % 3) * 0.7
		mesh_at(cyl(0.0, 0.35, h, 6), spike, Vector3(cos(a) * 4.0, 0.6 + h / 2.0, sin(a) * 4.0), g)
