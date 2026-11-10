extends SceneTree

# Builds res://scenes/portal_worlds/far_future.tscn: the Far Future, Dash and Rex's home (plan item 19a world 8, the
# last portal world). Lumen City, a bright neon city from the furthest future there is, and it's FADING: all the time
# broken in the other worlds is catching up with it last of all. The Tomorrow Clock in the middle of the city keeps
# its time, and it's lost its three Time Cores:
#   Core1  Dash's lab (west): the Swap-o-Tron's three Chrono Fuses have blown. Fit new ones: one by the machine, one
#          up on the gallery (a bounce pad gets you there), one on the lab's roof (another bounce pad, outside)
#   Core2  the Skyway Run (scripts/races.gd "skyway_run"): a rocket-ride race round the sky road that rings the city,
#          ten metres up. Its starter waits on the ground under it; finish in any place
#   Core3  the Fading Plaza (east): six people are fading out of time. Reach each one (four on the plaza, two up on the
#          balcony, by the hover steps) and your watch's tick pins them back into it
# With all three cores in, Captain Glitch (the Agent of Chaos's lieutenant, scripts/captain_glitch.gd), flickering on
# the Tomorrow Clock's dais, wakes when you come near. Pop him and the future stops fading.
# Logic: scripts/far_future.gd (on scripts/portal_world.gd), which puts in the fuses, the people, Rex, Dash, the
# cores, the captain and the hover traffic at the markers made here.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_far_future.gd

const OUT := "res://scenes/portal_worlds/far_future.tscn"
const FLOOR_R := 64.0                    # the city's floor; the fence stands just inside it
const CLOCK := Vector3(0, 0, -4)         # the Tomorrow Clock, on its round dais in the middle
const DAIS_R := 13.0
const DAIS_H := 0.4
const LAB := Vector3(-30, 0, -4)         # Dash's lab: a round lab with its open front facing the clock (east)
const LAB_R := 9.0
const LAB_H := 6.0                       # its flat roof
const GALLERY_H := 3.6                   # the gallery round the back wall inside
const PLAZA := Vector3(30, 0, -6)        # the Fading Plaza
const PLAZA_R := 12.0
const BALCONY := Vector3(38, 0, -14)     # the plaza's balcony, up the hover steps
const BALCONY_H := 4.2
const SKY_Y := 10.0                      # the Skyway's road, all the way round
const ROAD_W := 10.0
# The Skyway Run's checkpoints (scripts/races.gd TRACKS "skyway_run" has the same): a wiggly ring round the city
const SKYWAY := [Vector2(52, 8), Vector2(40, 32), Vector2(20, 47), Vector2(0, 50), Vector2(-24, 46), Vector2(-42, 32),
	Vector2(-52, 10), Vector2(-50, -14), Vector2(-38, -36), Vector2(-16, -50), Vector2(10, -52), Vector2(34, -40),
	Vector2(50, -18)]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var meshes := {}
var road := PackedVector3Array()         # the Skyway's middle line, a point every 2 m


func _initialize() -> void:
	rng.seed = 88
	world = Node3D.new()
	world.name = "FarFuture"
	world.set_script(load("res://scripts/far_future.gd"))
	world.set("world_id", "far_future")
	world.set("fall_below", -10.0)
	world.set_meta("preview_radius", 46.0)
	_environment()
	_floor()
	_edge()
	_skyway()
	_clock()
	_lab()
	_plaza()
	_inner_towers()
	_skyline()
	_streetlights()
	# Markers for scripts/far_future.gd
	_marker("Fuse1", LAB + Vector3(2.8, 0, 3.2))
	_marker("Fuse2", LAB + Vector3(-7.2, GALLERY_H, 0))
	_marker("Fuse3", LAB + Vector3(-5.2, LAB_H + 0.3, -5.2))
	_marker("Lift1", LAB + Vector3(-3.6, 0, -2.6))
	_marker("Lift1Top", LAB + Vector3(-6.6, GALLERY_H, -2.4))
	_marker("Lift2", LAB + Vector3(5.0, 0, -11.0))
	_marker("Lift2Top", LAB + Vector3(3.6, LAB_H + 0.3, -6.6))
	_marker("SwapOTron", LAB + Vector3(-3.0, 0, 2.0))
	_marker("Dash", LAB + Vector3(4.2, 0, 1.0)).rotation.y = PI / 2.0
	_marker("Rex", Vector3(5.5, 0, 37)).rotation.y = atan2(-5.5, 7.0)
	var folk := [PLAZA + Vector3(-6, 0, 4), PLAZA + Vector3(3, 0, 7), PLAZA + Vector3(7, 0, -1), PLAZA + Vector3(-4, 0, -6),
		BALCONY + Vector3(-2.2, BALCONY_H, -0.6), BALCONY + Vector3(2.2, BALCONY_H, 0.6)]
	for i in folk.size():
		_marker("Folk%d" % (i + 1), folk[i]).rotation.y = rng.randf() * TAU
	for i in 3:
		var a := PI / 2.0 + (i - 1) * 2.1
		_marker("Socket%d" % (i + 1), CLOCK + Vector3(cos(a) * 4.6, DAIS_H, sin(a) * 4.6))
	_marker("Captain", CLOCK + Vector3(0, DAIS_H, 8.0))
	_marker("TimeStone", Vector3(9.0, 0, 44))
	# The way home stands off to one side of where you arrive, facing the middle (so the camera never starts inside it)
	_marker("WayHome", Vector3(-9.0, 0, 46)).rotation.y = atan2(9.0, -46.0)
	_marker("Vein1", Vector3(-13, 0, 31))
	_marker("PreviewCentre", Vector3(0, 6, -4))
	var entrance := _marker("Entrance", Vector3(0, 1.0, 44))      # facing in, towards the clock (-Z)
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


# Helpers ------------------------------------------------------------------------------------------------------------
func mat(name: String, color: Color, rough := 0.6, emit := 0.0, alpha := 1.0, metal := 0.0) -> StandardMaterial3D:
	# Materials whose names start "Neon" are the city's lights: scripts/far_future.gd dims them while it's fading
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
	h = maxf(snappedf(h, 0.1), 0.05)          # (a 0.04 disc would snap to nothing: see the Tide Reef's builder)
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
	size = size.snappedf(0.01)
	var key := "x%s" % size
	if meshes.has(key):
		return meshes[key]
	var b := BoxMesh.new()
	meshes[key] = b
	b.size = size
	return b


func solid_box(size: Vector3, pos: Vector3, m: Material, parent: Node, rot := Vector3.ZERO) -> StaticBody3D:
	mesh_at(box(size), m, pos, parent, rot)
	var b := BoxShape3D.new()
	b.size = size
	return solid(b, pos, parent, rot)


func cyl_solid(r: float, h: float, at: Vector3, parent: Node) -> StaticBody3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return solid(c, at, parent)


func label(text: String, at: Vector3, parent: Node, size := 64, colour := Color(0.75, 1.0, 1.0), yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = colour
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l


func _marker(n: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = at
	world.add_child(m)
	return m


func _group(n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	world.add_child(g)
	return g


# The sky and the light ----------------------------------------------------------------------------------------------
func _environment() -> void:
	# A bright future evening: deep teal overhead, pink and gold at the horizon (scripts/far_future.gd washes the
	# colour out while the city's fading, with the environment's saturation)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.08, 0.2, 0.42)
	sky_mat.sky_horizon_color = Color(0.95, 0.5, 0.75)
	sky_mat.ground_horizon_color = Color(0.95, 0.5, 0.75)
	sky_mat.ground_bottom_color = Color(0.2, 0.12, 0.3)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.85)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7                     # neon should bloom
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.45, 0.7)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true                # (saturation: the fading, scripts/far_future.gd set_fade())
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.8, 0.85)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, 40, 0)
	world.add_child(sun)


func _floor() -> void:
	# The city floor: dark glassy paving with a glowing grid, and lit lanes from the way in to the clock, the lab and
	# the plaza
	var g := _group("City Floor")
	mesh_at(cyl(FLOOR_R + 8.0, FLOOR_R + 8.0, 1.0, 64), mat("Paving", Color(0.12, 0.13, 0.24), 0.35, 0.0, 1.0, 0.3),
		Vector3(0, -0.5, 0), g)
	cyl_solid(FLOOR_R + 8.0, 1.0, Vector3(0, -0.5, 0), g)
	var grid := mat("Neon Grid", Color(0.3, 0.85, 1.0), 0.4, 1.4)
	for k in range(-60, 61, 8):
		var half := sqrt(maxf(FLOOR_R * FLOOR_R - k * k, 0.0))
		if half < 4.0:
			continue
		mesh_at(box(Vector3(half * 2.0, 0.02, 0.08)), grid, Vector3(0, 0.01, k), g)
		mesh_at(box(Vector3(0.08, 0.02, half * 2.0)), grid, Vector3(k, 0.01, 0), g)
	var lane := mat("Neon Lane", Color(1.0, 0.45, 0.85), 0.4, 1.6)
	for to in [CLOCK + Vector3(0, 0, DAIS_R), LAB + Vector3(LAB_R, 0, 0), PLAZA - Vector3(PLAZA_R, 0, 0)]:
		var from := Vector3(0, 0, 40) if to.z > 0.0 else CLOCK
		var d: Vector3 = to - from
		var mid: Vector3 = from + d / 2.0
		var yaw := atan2(d.x, d.z)
		for side in [-1.4, 1.4]:
			var off: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * side
			mesh_at(box(Vector3(0.12, 0.03, d.length())), lane, mid + off + Vector3(0, 0.02, 0), g, Vector3(0, yaw, 0))


func _edge() -> void:
	# An invisible fence just inside the floor's edge (named Fence, so wall crawl never climbs it), and a low glowing
	# kerb to show where it is
	var g := _group("Edge")
	var kerb := mat("Neon Kerb", Color(0.4, 1.0, 0.85), 0.4, 1.2)
	for k in 64:
		var a := k * TAU / 64.0
		var p := Vector3(cos(a), 0, sin(a)) * (FLOOR_R - 1.2)
		mesh_at(box(Vector3(6.4, 0.3, 0.3)), kerb, p + Vector3(0, 0.15, 0), g, Vector3(0, -a + PI / 2.0, 0))
		var b := BoxShape3D.new()
		b.size = Vector3(6.6, 30.0, 0.6)
		var body := solid(b, p + Vector3(0, 15.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
		body.name = "Fence"


# The Skyway --------------------------------------------------------------------------------------------------------
static func catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _skyway() -> void:
	# The sky road: the same smooth loop scripts/race_track.gd works out from the checkpoints, ten metres up, with
	# glowing rails both sides (low enough to see over, high enough to keep a board on) and pillars down to the floor
	var g := _group("Skyway")
	var n := SKYWAY.size()
	for i in n:
		var p0 := Vector3(SKYWAY[(i - 1 + n) % n].x, 0, SKYWAY[(i - 1 + n) % n].y)
		var p1 := Vector3(SKYWAY[i].x, 0, SKYWAY[i].y)
		var p2 := Vector3(SKYWAY[(i + 1) % n].x, 0, SKYWAY[(i + 1) % n].y)
		var p3 := Vector3(SKYWAY[(i + 2) % n].x, 0, SKYWAY[(i + 2) % n].y)
		var steps := maxi(2, int(ceil(p1.distance_to(p2) / 2.0)))
		for s in steps:
			road.append(catmull(p0, p1, p2, p3, float(s) / steps))
	var deck := mat("Skyway Deck", Color(0.2, 0.18, 0.34), 0.5, 0.0, 1.0, 0.2)
	var rail := mat("Neon Rail", Color(0.35, 0.95, 1.0), 0.4, 1.8)
	var stripe := mat("Neon Stripe", Color(1.0, 0.8, 0.35), 0.4, 1.4)
	var pillar := mat("Pillar", Color(0.3, 0.28, 0.45), 0.5, 0.0, 1.0, 0.3)
	for i in road.size():
		var a := road[i]
		var b := road[(i + 1) % road.size()]
		var d := b - a
		var yaw := atan2(d.x, d.z)
		var mid := (a + b) / 2.0
		var len := d.length() + 0.6                    # (a little overlap, so the joins on the bends have no gaps)
		solid_box(Vector3(ROAD_W, 0.6, len), mid + Vector3(0, SKY_Y - 0.3, 0), deck, g, Vector3(0, yaw, 0))
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		for s in [-1.0, 1.0]:
			var at: Vector3 = mid + side * s * (ROAD_W / 2.0 - 0.15) + Vector3(0, SKY_Y + 0.45, 0)
			var r := solid_box(Vector3(0.3, 0.9, len), at, rail, g, Vector3(0, yaw, 0))
			r.name = "Skyway Rail"
		if i % 2 == 0:
			mesh_at(box(Vector3(0.3, 0.03, 1.0)), stripe, mid + Vector3(0, SKY_Y + 0.01, 0), g, Vector3(0, yaw, 0))
		if i % 7 == 0:
			mesh_at(cyl(0.7, 0.9, SKY_Y - 0.6, 10), pillar, mid + Vector3(0, (SKY_Y - 0.6) / 2.0, 0), g)
			cyl_solid(0.8, SKY_Y - 0.6, mid + Vector3(0, (SKY_Y - 0.6) / 2.0, 0), g)
	label("SKYWAY", Vector3(52, SKY_Y + 3.5, 8), g, 140, Color(0.6, 1.0, 1.0), PI / 2.0)


func _near_road(p: Vector3, room: float) -> bool:
	for r in road:
		if Vector2(r.x - p.x, r.z - p.z).length() < ROAD_W / 2.0 + room:
			return true
	return false


# The Tomorrow Clock ------------------------------------------------------------------------------------------------
func _clock() -> void:
	# A round dais, a tall slim spire with a big clock face on each side, and three empty sockets round its foot
	var g := _group("Tomorrow Clock")
	g.position = CLOCK
	var stone := mat("Dais", Color(0.35, 0.33, 0.55), 0.4, 0.0, 1.0, 0.4)
	var trim := mat("Neon Dais Rim", Color(1.0, 0.45, 0.85), 0.4, 1.6)
	mesh_at(cyl(DAIS_R, DAIS_R + 0.3, DAIS_H, 48), stone, Vector3(0, DAIS_H / 2.0, 0), g)
	cyl_solid(DAIS_R, DAIS_H, Vector3(0, DAIS_H / 2.0, 0), g)
	mesh_at(cyl(DAIS_R + 0.32, DAIS_R + 0.32, 0.1, 48), trim, Vector3(0, DAIS_H - 0.05, 0), g)
	var body := mat("Spire", Color(0.82, 0.86, 1.0), 0.25, 0.0, 1.0, 0.6)
	var glow := mat("Neon Spire", Color(0.4, 1.0, 1.0), 0.3, 2.0)
	mesh_at(cyl(1.2, 2.4, 22.0, 6), body, Vector3(0, DAIS_H + 11.0, 0), g)
	cyl_solid(2.2, 22.0, Vector3(0, DAIS_H + 11.0, 0), g)
	for k in 6:                                   # glowing seams up its six edges
		var a := k * TAU / 6.0
		var m := mesh_at(box(Vector3(0.12, 22.0, 0.12)), glow, Vector3(cos(a) * 1.85, DAIS_H + 11.0, sin(a) * 1.85), g)
		m.rotation = Vector3(0, -a, 0.055 * 0)
	mesh_at(cyl(0.0, 1.3, 4.0, 6), glow, Vector3(0, DAIS_H + 24.0, 0), g)
	var face := mat("Clock Face", Color(0.95, 0.97, 1.0), 0.3, 0.6)
	var hand := mat("Clock Hand", Color(0.1, 0.1, 0.25))
	for k in 4:
		var yaw := k * PI / 2.0
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var f := mesh_at(cyl(2.6, 2.6, 0.2, 32), face, dir * 2.2 + Vector3(0, DAIS_H + 16.0, 0), g, Vector3(PI / 2.0, yaw, 0))
		f.name = "Face%d" % k
		mesh_at(box(Vector3(0.18, 1.8, 0.1)), hand, dir * 2.36 + Vector3(0, DAIS_H + 16.7, 0), g, Vector3(0, yaw, 0))
		mesh_at(box(Vector3(1.2, 0.16, 0.1)), hand, dir * 2.36 + Vector3(0, DAIS_H + 16.0, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * 0.5,
			g, Vector3(0, yaw, 0))
	label("THE TOMORROW CLOCK", Vector3(0, DAIS_H + 3.4, 2.6), g, 56, Color(1.0, 0.85, 1.0))
	# Three sockets (scripts/far_future.gd lights them as the cores come home)
	for i in 3:
		var a := PI / 2.0 + (i - 1) * 2.1
		var p := Vector3(cos(a) * 4.6, DAIS_H, sin(a) * 4.6)
		mesh_at(cyl(0.7, 0.9, 1.0, 8), stone, p + Vector3(0, 0.5, 0), g)
		cyl_solid(0.8, 1.0, p + Vector3(0, 0.5, 0), g)


# Dash's lab -----------------------------------------------------------------------------------------------------------
func _lab() -> void:
	# A round lab with a glass dome, open to the east (towards the clock). Inside: the Swap-o-Tron (put in by
	# scripts/far_future.gd), Dash's console, and a gallery round the back wall. A flat roof ring round the dome's foot.
	var g := _group("Dash's Lab")
	g.position = LAB
	var wall := mat("Lab Wall", Color(0.88, 0.9, 1.0), 0.35, 0.0, 1.0, 0.3)
	var trim := mat("Neon Lab Trim", Color(0.55, 1.0, 0.4), 0.4, 1.6)
	var floor_mat := mat("Lab Floor", Color(0.3, 0.32, 0.48), 0.4, 0.0, 1.0, 0.3)
	mesh_at(cyl(LAB_R, LAB_R, 0.2, 40), floor_mat, Vector3(0, 0.1, 0), g)
	cyl_solid(LAB_R, 0.2, Vector3(0, 0.1, 0), g)
	var segs := 28
	for k in segs:
		var a := (k + 0.5) * TAU / segs
		if absf(wrapf(a, -PI, PI)) < 0.75:          # the open front, facing +X
			continue
		var p := Vector3(cos(a), 0, sin(a)) * LAB_R
		solid_box(Vector3(2.15, LAB_H, 0.5), p + Vector3(0, LAB_H / 2.0, 0), wall, g, Vector3(0, -a + PI / 2.0, 0))
		mesh_at(box(Vector3(2.15, 0.15, 0.55)), trim, p + Vector3(0, 1.0, 0), g, Vector3(0, -a + PI / 2.0, 0))
	# The roof: a flat ring you can walk on (the dome's in the middle)
	for k in segs:
		var a := (k + 0.5) * TAU / segs
		var p := Vector3(cos(a), 0, sin(a)) * (LAB_R - 1.6)
		solid_box(Vector3(2.6, 0.3, 3.8), p + Vector3(0, LAB_H + 0.15, 0), wall, g, Vector3(0, -a + PI / 2.0, 0))
	var glass := mat("Lab Dome", Color(0.6, 0.95, 1.0), 0.1, 0.3, 0.3)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dome := mesh_at(ball(LAB_R - 3.2, 24), glass, Vector3(0, LAB_H, 0), g)
	dome.scale = Vector3(1, 0.55, 1)
	var dome_body := cyl_solid(LAB_R - 3.3, 0.3, Vector3(0, LAB_H + 0.15, 0), g)    # (so the roof has no hole to fall in)
	dome_body.name = "Dome Floor"
	mesh_at(cyl(LAB_R + 0.1, LAB_R + 0.1, 0.18, 40), trim, Vector3(0, LAB_H + 0.32, 0), g)
	# The gallery round the back (west) wall, with a glowing edge
	for k in 9:
		var a := PI - 1.1 + k * 2.2 / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (LAB_R - 1.8)
		solid_box(Vector3(2.2, 0.3, 2.6), p + Vector3(0, GALLERY_H - 0.15, 0), floor_mat, g, Vector3(0, -a + PI / 2.0, 0))
		mesh_at(box(Vector3(2.2, 0.1, 0.12)), trim, p * ((LAB_R - 3.1) / (LAB_R - 1.8)) + Vector3(0, GALLERY_H, 0), g,
			Vector3(0, -a + PI / 2.0, 0))
	# Dash's console, and a big screen
	solid_box(Vector3(1.0, 1.0, 2.2), Vector3(5.2, 0.5, 1.0), mat("Console", Color(0.2, 0.22, 0.36), 0.4, 0.0, 1.0, 0.5), g)
	mesh_at(box(Vector3(0.9, 0.05, 2.0)), mat("Neon Console", Color(0.4, 0.8, 1.0), 0.3, 1.6), Vector3(5.2, 1.03, 1.0), g)
	mesh_at(box(Vector3(0.1, 2.2, 4.0)), mat("Neon Screen", Color(0.25, 0.6, 1.0), 0.3, 1.0), Vector3(-LAB_R + 0.6, 3.0 + GALLERY_H, 0), g)
	label("DASH'S LAB", Vector3(LAB_R + 0.3, LAB_H - 0.9, 0), g, 72, Color(0.75, 1.0, 0.6), PI / 2.0)
	label("(Rex's too. Mostly Dash's.)", Vector3(LAB_R + 0.3, LAB_H - 1.6, 0), g, 30, Color(0.9, 0.95, 1.0), PI / 2.0)


# The Fading Plaza -----------------------------------------------------------------------------------------------------
func _plaza() -> void:
	# A round plaza with a hologram fountain, benches, a balcony up on four pillars with hover steps up to it
	var g := _group("Fading Plaza")
	g.position = PLAZA
	var tile := mat("Plaza Tile", Color(0.42, 0.38, 0.62), 0.4, 0.0, 1.0, 0.2)
	var rim := mat("Neon Plaza Rim", Color(1.0, 0.85, 0.35), 0.4, 1.4)
	mesh_at(cyl(PLAZA_R, PLAZA_R, 0.15, 40), tile, Vector3(0, 0.075, 0), g)
	cyl_solid(PLAZA_R, 0.15, Vector3(0, 0.075, 0), g)
	mesh_at(cyl(PLAZA_R + 0.2, PLAZA_R + 0.2, 0.1, 40), rim, Vector3(0, 0.06, 0), g)
	# The hologram fountain: a basin and a slowly turning holo-sphere over it
	mesh_at(cyl(2.4, 2.6, 0.7, 24), mat("Fountain", Color(0.75, 0.78, 0.95), 0.3, 0.0, 1.0, 0.4), Vector3(0, 0.35, 0), g)
	cyl_solid(2.5, 0.7, Vector3(0, 0.35, 0), g)
	var holo := mat("Neon Holo", Color(0.45, 1.0, 1.0), 0.2, 1.6, 0.45)
	var sphere := mesh_at(ball(1.2, 16), holo, Vector3(0, 2.6, 0), g)
	sphere.name = "Holo Globe"
	label("FADING PLAZA", Vector3(0, 4.6, 0), g, 56, Color(1.0, 0.9, 0.6)).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var bench := mat("Bench", Color(0.85, 0.85, 1.0), 0.4, 0.0, 1.0, 0.4)
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var p := Vector3(cos(a), 0, sin(a)) * 9.5
		solid_box(Vector3(2.4, 0.5, 0.7), p + Vector3(0, 0.25, 0), bench, g, Vector3(0, -a + PI / 2.0, 0))
	# The balcony: a slab on four glowing pillars, with a rail on its far sides
	var bal := BALCONY - PLAZA
	solid_box(Vector3(7.0, 0.4, 4.0), bal + Vector3(0, BALCONY_H - 0.2, 0), tile, g)
	for sx in [-3.2, 3.2]:
		for sz in [-1.7, 1.7]:
			mesh_at(cyl(0.22, 0.22, BALCONY_H - 0.4, 8), rim, bal + Vector3(sx, (BALCONY_H - 0.4) / 2.0, sz), g)
			cyl_solid(0.25, BALCONY_H - 0.4, bal + Vector3(sx, (BALCONY_H - 0.4) / 2.0, sz), g)
	solid_box(Vector3(7.0, 0.8, 0.2), bal + Vector3(0, BALCONY_H + 0.4, -1.9), rim, g)
	solid_box(Vector3(0.2, 0.8, 4.0), bal + Vector3(3.4, BALCONY_H + 0.4, 0), rim, g)
	# Hover steps up to it: floating discs, each a short hop above the last
	var step := mat("Neon Hover Step", Color(0.5, 0.9, 1.0), 0.3, 0.9)
	for i in 4:
		var p := bal + Vector3(-6.8 + i * 1.1, 0.9 + i * 0.85, 3.6 - i * 1.15)
		var s := mesh_at(cyl(0.9, 0.7, 0.22, 16), step, p, g)
		s.name = "Hover Step %d" % (i + 1)
		cyl_solid(0.9, 0.22, p, g).name = "Hover Step Body %d" % (i + 1)


# Towers ----------------------------------------------------------------------------------------------------------------
func _tower(parent: Node3D, at: Vector3, w: float, h: float, k: int) -> Node3D:
	# A neon tower: a tall glassy block in one of the city's colours, with lit window strips and a glowing crown
	var t := Node3D.new()
	t.name = "Tower %d" % k
	t.position = at
	parent.add_child(t)
	var colours := [Color(0.35, 0.95, 1.0), Color(1.0, 0.45, 0.85), Color(0.6, 1.0, 0.4), Color(1.0, 0.82, 0.35), Color(0.65, 0.55, 1.0)]
	var c: Color = colours[k % colours.size()]
	var body := mat("Tower Glass %d" % (k % 5), Color(0.16, 0.18, 0.32).lerp(c, 0.12), 0.2, 0.0, 1.0, 0.6)
	var lit := mat("Neon Windows %d" % (k % 5), c, 0.3, 1.5)
	var round := k % 3 == 1
	if round:
		mesh_at(cyl(w * 0.5, w * 0.55, h, 12), body, Vector3(0, h / 2.0, 0), t)
	else:
		mesh_at(box(Vector3(w, h, w)), body, Vector3(0, h / 2.0, 0), t)
	var b := BoxShape3D.new()
	b.size = Vector3(w, h, w)
	solid(b, Vector3(0, h / 2.0, 0), t)
	var y := 3.0
	while y < h - 2.0:
		if round:
			mesh_at(cyl(w * 0.53, w * 0.53, 0.25, 12), lit, Vector3(0, y, 0), t)
		else:
			mesh_at(box(Vector3(w + 0.06, 0.25, w + 0.06)), lit, Vector3(0, y, 0), t)
		y += rng.randf_range(2.2, 3.6)
	mesh_at(cyl(0.0, w * 0.35, 3.0, 4 if not round else 8), lit, Vector3(0, h + 1.5, 0), t)
	return t


func _inner_towers() -> void:
	# A few towers inside the Skyway's ring, clear of the lanes, the lab, the plaza and the clock
	var g := _group("Towers")
	var spots := [Vector3(-20, 0, 24), Vector3(22, 0, 22), Vector3(-16, 0, -30), Vector3(16, 0, -30), Vector3(-2, 0, -36),
		Vector3(-34, 0, 18), Vector3(36, 0, 14), Vector3(-30, 0, -24)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		var w := rng.randf_range(4.5, 6.5)
		if _near_road(p, w):
			continue
		_tower(g, p, w, rng.randf_range(16.0, 30.0), i)


func _skyline() -> void:
	# The skyline: tall towers outside the fence, all the way round, some of them bridged with glowing sky tubes.
	# These are the ones that flicker out while the city's fading (scripts/far_future.gd, the "Skyline" node).
	var g := _group("Skyline")
	var n := 30
	for i in n:
		var a := i * TAU / n + rng.randf_range(-0.04, 0.04)
		var r := FLOOR_R + rng.randf_range(6.0, 22.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		_tower(g, p, rng.randf_range(6.0, 11.0), rng.randf_range(26.0, 70.0), i + 10)
	# Hover rings floating high above, like the city's own little moons
	var ring := mat("Neon Sky Ring", Color(1.0, 0.6, 0.95), 0.3, 1.8)
	for k in 3:
		var t := TorusMesh.new()
		t.inner_radius = 6.0 + k * 3.0
		t.outer_radius = 6.4 + k * 3.0
		var m := mesh_at(t, ring, Vector3(-20 + k * 24, 46 + k * 6, -70 + k * 12), g, Vector3(0.4, k * 0.8, 0.2))
		m.name = "Sky Ring %d" % (k + 1)


func _streetlights() -> void:
	# Little glowing posts along the lanes
	var g := _group("Streetlights")
	var post := mat("Post", Color(0.3, 0.3, 0.45), 0.4, 0.0, 1.0, 0.5)
	var bulb := mat("Neon Bulb", Color(0.9, 0.95, 1.0), 0.3, 2.0)
	for z in range(36, 12, -8):
		for sx in [-3.2, 3.2]:
			var p := Vector3(sx, 0, z)
			mesh_at(cyl(0.08, 0.1, 3.0, 6), post, p + Vector3(0, 1.5, 0), g)
			cyl_solid(0.12, 3.0, p + Vector3(0, 1.5, 0), g)
			mesh_at(ball(0.25, 8), bulb, p + Vector3(0, 3.1, 0), g)
