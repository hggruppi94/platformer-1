extends SceneTree

# Builds res://scenes/scary_world/scary_world.tscn: the Scary World behind the gate in the town's far northwest woods.
# A small, misty, moonlit clearing ringed by twisted trees, with glowing mushrooms, drifting wisps, eyes in the dark
# (glow-bugs, really) and a stepping-stone path to the hollow log where the centipede lives. The gate you came in by
# is right behind you and always takes you home. Logic: scripts/scary_world.gd, scripts/centipede_friend.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_scary_world.gd

const OUT := "res://scenes/scary_world/scary_world.tscn"
const TOWN := "res://scenes/town/town.tscn"
const RADIUS := 30.0                              # the clearing; trees and an invisible wall round it
const LOG_AT := Vector3(0, 0, -14)

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}


func _initialize() -> void:
	rng.seed = 13
	world = Node3D.new()
	world.name = "ScaryWorld"
	world.set_script(load("res://scripts/scary_world.gd"))
	_environment()
	_ground()
	_trees()
	_glow()
	_path_and_log()
	_gate()
	_own(world)
	var scene := PackedScene.new()
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


func ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.04, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.55)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.26, 0.42)
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.65, 0.7, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, 30, 0)
	world.add_child(moon)
	var moon_ball := mesh_at(ball(6.0, 24), mat("Moon", Color(0.9, 0.92, 1.0), 0.5, 1.6), Vector3(-40, 60, -120), world)
	moon_ball.name = "MoonInTheSky"


func _ground() -> void:
	var g := mesh_at(cyl(RADIUS + 12, RADIUS + 12, 1.0, 48), mat("Moss", Color(0.16, 0.2, 0.2), 0.95), Vector3(0, -0.5, 0), world)
	g.name = "Ground"
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS + 12
	shape.height = 1.0
	solid(shape, Vector3(0, -0.5, 0), world).name = "GroundBody"
	# An invisible wall round the clearing (behind the trees), so the wood seems to go on but she can't get lost
	var walls := Node3D.new()
	walls.name = "Edge"
	world.add_child(walls)
	for k in 36:
		var a := k * TAU / 36
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 8.0, 2 * (RADIUS + 2) * sin(PI / 36) + 0.4)
		solid(box, Vector3(cos(a), 0, sin(a)) * (RADIUS + 2) + Vector3(0, 4, 0), walls, Vector3(0, -a, 0))


func _tree(parent: Node3D, at: Vector3, h: float) -> void:
	# A bare, twisted tree: a leaning trunk with crooked branches
	var bark := mat("Old Bark", Color(0.12, 0.09, 0.13), 0.95)
	var t := Node3D.new()
	t.position = at
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	var lean := rng.randf_range(-0.15, 0.15)
	mesh_at(cyl(0.18, 0.45, h), bark, Vector3(0, h / 2, 0), t, Vector3(lean, 0, 0))
	solid(CylinderShape3D.new(), Vector3(0, 1.0, 0), t).get_child(0).shape.set("radius", 0.45)
	for k in rng.randi_range(3, 5):
		var y := h * rng.randf_range(0.45, 0.9)
		var len := rng.randf_range(1.2, 2.6)
		var a := rng.randf() * TAU
		var b := Node3D.new()
		b.position = Vector3(0, y, 0)
		b.rotation = Vector3(0, a, rng.randf_range(0.7, 1.2))
		t.add_child(b)
		mesh_at(cyl(0.04, 0.12, len, 6), bark, Vector3(0, len / 2, 0), b)
		mesh_at(cyl(0.02, 0.05, len * 0.5, 5), bark, Vector3(0, len, 0), b, Vector3(0, 0, -0.6))


func _trees() -> void:
	var g := Node3D.new()
	g.name = "Twisted Trees"
	world.add_child(g)
	for k in 70:                                         # a thick ring round the edge
		var a := k * TAU / 70 + rng.randf_range(-0.04, 0.04)
		var r := RADIUS + rng.randf_range(-3.0, 6.0)
		_tree(g, Vector3(cos(a), 0, sin(a)) * r, rng.randf_range(6.0, 11.0))
	var placed := 0
	while placed < 14:                                   # and a few inside, off the path and away from the log
		var p := Vector3(rng.randf_range(-RADIUS + 6, RADIUS - 6), 0, rng.randf_range(-RADIUS + 6, RADIUS - 6))
		if p.length() > RADIUS - 5 or absf(p.x) < 4.0 or p.distance_to(LOG_AT) < 8.0:
			continue
		_tree(g, p, rng.randf_range(5.0, 9.0))
		placed += 1


func _glow() -> void:
	# Glowing mushrooms, drifting wisps, and eyes in the dark between the trees (glow-bugs)
	var wisp := load("res://scripts/wisp.gd")
	var g := Node3D.new()
	g.name = "Glow"
	world.add_child(g)
	var cols := [Color(0.4, 1.0, 0.9), Color(0.75, 0.5, 1.0), Color(0.5, 0.75, 1.0)]
	for k in 22:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, RADIUS - 3)
		if absf(p.x) < 2.0:
			continue
		var col: Color = cols[k % 3]
		var cluster := Node3D.new()
		cluster.position = p
		g.add_child(cluster)
		for q in rng.randi_range(2, 4):
			var off := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			var h := rng.randf_range(0.2, 0.5)
			mesh_at(cyl(0.04, 0.05, h, 6), mat("Stalk", Color(0.85, 0.85, 0.9), 0.8), off + Vector3(0, h / 2, 0), cluster)
			var cap := mesh_at(ball(0.16 + h * 0.2), mat("Glow Cap %d" % (k % 3), col, 0.4, 2.0), off + Vector3(0, h, 0), cluster)
			cap.scale = Vector3(1, 0.5, 1)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.6
		l.omni_range = 3.5
		l.position = Vector3(0, 0.6, 0)
		cluster.add_child(l)
	for k in 10:
		var w := Node3D.new()
		w.name = "Wisp %d" % (k + 1)
		w.set_script(wisp)
		var a := rng.randf() * TAU
		w.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(5.0, RADIUS - 6) + Vector3(0, rng.randf_range(1.5, 3.0), 0)
		g.add_child(w)
		var col: Color = cols[k % 3]
		mesh_at(ball(0.12), mat("Wisp %d" % (k % 3), col, 0.2, 3.0), Vector3.ZERO, w)
		mesh_at(ball(0.3), mat("Wisp Halo %d" % (k % 3), col, 0.2, 1.0, 0.2), Vector3.ZERO, w)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.8
		l.omni_range = 5.0
		w.add_child(l)
	for k in 12:
		var eyes := Node3D.new()
		eyes.name = "Eyes %d" % (k + 1)
		eyes.set_script(wisp)
		eyes.set("blink", true)
		var a := k * TAU / 12 + 0.2
		eyes.position = Vector3(cos(a), 0, sin(a)) * (RADIUS - 0.5) + Vector3(0, rng.randf_range(1.0, 2.6), 0)
		eyes.rotation.y = atan2(-cos(a), -sin(a))             # looking in at the clearing
		g.add_child(eyes)
		for s in [-1, 1]:
			mesh_at(ball(0.07), mat("Eye Glow", Color(1.0, 0.9, 0.4), 0.2, 3.0), Vector3(s * 0.14, 0, 0), eyes)


func _path_and_log() -> void:
	var g := Node3D.new()
	g.name = "Hollow Log"
	world.add_child(g)
	var stone := mat("Path Stone", Color(0.4, 0.38, 0.45), 0.9)
	var z := RADIUS - 6.0
	while z > LOG_AT.z + 4.0:                             # stepping stones from the gate to the log
		var s := mesh_at(cyl(0.5, 0.55, 0.12, 10), stone, Vector3(rng.randf_range(-0.6, 0.6), 0.04, z), g)
		s.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.0))
		z -= 1.6
	var wood := mat("Log Wood", Color(0.28, 0.18, 0.14), 0.95)
	var log_body := mesh_at(cyl(1.5, 1.6, 7.0, 16), wood, LOG_AT + Vector3(-3.0, 1.4, 0), g, Vector3(0, 0, PI / 2))
	log_body.name = "Log"
	var shape := CylinderShape3D.new()
	shape.radius = 1.55
	shape.height = 7.0
	solid(shape, LOG_AT + Vector3(-3.0, 1.4, 0), g, Vector3(0, 0, PI / 2))
	mesh_at(cyl(1.2, 1.2, 0.05, 16), mat("Log Inside", Color(0.05, 0.03, 0.05)), LOG_AT + Vector3(0.53, 1.4, 0), g, Vector3(0, 0, PI / 2))
	for k in 6:                                            # moss and a few mushrooms on top
		mesh_at(ball(0.35), mat("Log Moss", Color(0.25, 0.45, 0.3), 0.95), LOG_AT + Vector3(-5.5 + k * 1.0, 2.8, rng.randf_range(-0.5, 0.5)), g)
	# The centipede, curled up beside the log, with its talk spot
	var c := Node3D.new()
	c.name = "Centipede"
	c.set_script(load("res://scripts/centipede_friend.gd"))
	c.position = LOG_AT + Vector3(3.5, 0, 1.5)
	c.rotation.y = 0.4
	g.add_child(c)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", "centipede")
	talk.set("display_name", "The Centipede")
	talk.set("talk_radius", 4.0)
	talk.set("name_height", 2.0)
	talk.set("turns", false)
	talk.position = Vector3(0, 0, 1.6)
	c.add_child(talk)
	var l := OmniLight3D.new()
	l.light_color = Color(0.8, 0.7, 1.0)
	l.light_energy = 0.9
	l.omni_range = 7.0
	l.position = c.position + Vector3(0, 3.0, 2.0)
	g.add_child(l)


func _gate() -> void:
	# The inside of the gate she came through: the way home, always right there
	var g := Node3D.new()
	g.name = "Gate Home"
	g.position = Vector3(0, 0, RADIUS - 2.0)
	world.add_child(g)
	var stone := mat("Old Wall Stone", Color(0.32, 0.3, 0.36), 0.95)
	var iron := mat("Gate Iron", Color(0.12, 0.12, 0.14), 0.4)
	for side in [-1, 1]:
		mesh_at(BoxMesh.new(), stone, Vector3(side * 2.6, 2.75, 0), g).scale = Vector3(1.4, 6.5, 1.6)
		var b := BoxShape3D.new()
		b.size = Vector3(1.4, 6.5, 1.6)
		solid(b, Vector3(side * 2.6, 2.75, 0), g)
	for k in 7:
		mesh_at(cyl(0.07, 0.07, 4.6, 6), iron, Vector3(-1.5 + k * 0.5, 2.3, 0.6), g, Vector3(0, 0, 0)).rotation.y = 0.0
	var glow := mat("Home Glow", Color(1.0, 0.85, 0.55), 0.5, 2.0, 0.5)
	mesh_at(BoxMesh.new(), glow, Vector3(0, 2.3, 0.2), g).scale = Vector3(3.6, 4.6, 0.1)
	var home_light := OmniLight3D.new()
	home_light.light_color = Color(1.0, 0.85, 0.55)
	home_light.light_energy = 1.4
	home_light.omni_range = 8.0
	home_light.position = Vector3(0, 2.5, -1.5)
	g.add_child(home_light)
	var sign := Label3D.new()
	sign.text = "Way home"
	sign.font_size = 72
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.modulate = Color(1, 0.95, 0.75)
	sign.position = Vector3(0, 5.4, -0.2)
	sign.rotation.y = PI
	g.add_child(sign)
	var exit := Area3D.new()
	exit.name = "ExitToTown"
	exit.set_script(load("res://scripts/door.gd"))
	exit.set("destination", TOWN)
	exit.set("spawn", "FromScaryWorld")
	exit.set("place_name", "town")
	exit.position = Vector3(0, 1.5, 0.6)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 3.0, 1.0)
	cs.shape = box
	exit.add_child(cs)
	g.add_child(exit)
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	entrance.position = Vector3(0, 1.0, RADIUS - 6.5)       # a few steps in, facing into the wood (-Z)
	world.add_child(entrance)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = entrance.position
	world.add_child(player)
