extends SceneTree

# Builds res://scenes/earth/earth.tscn: the little Earth town through the portal. A cozy autumn town: a town green
# with a white gazebo in the middle, a street round it with lamps, a diner, a bookshop, the corner market, an inn,
# the town hall with its white steeple and a few homes, autumn trees, fallen leaves and pumpkins on the steps.
# Nina arrives by the old oak, where the portal home shimmers. Logic: scripts/earth_world.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_earth.gd

const OUT := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const GREEN_R := 13.0                             # the town green
const STREET := 21.0                              # the street runs round the green, this far out (a square)
const STREET_W := 6.0
const EDGE := 42.0                                # an invisible wall this far out
const PORTAL_AT := Vector3(-10, 0, 10)            # the old oak and the portal home, on the green's corner

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}


func _initialize() -> void:
	rng.seed = 1999
	world = Node3D.new()
	world.name = "Earth"
	world.set_script(load("res://scripts/earth_world.gd"))
	_environment()
	_ground_and_street()
	_gazebo()
	_buildings()
	_trees_and_leaves()
	_lamps()
	_portal()
	_people()
	_light_boxes()
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


func mesh_at(mesh: Mesh, m: Material, pos: Vector3, parent: Node, yaw := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	parent.add_child(mi)
	return mi


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func ball(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func solid_box(size: Vector3, pos: Vector3, parent: Node, yaw := 0.0) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)


func group(name: String, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation.y = yaw
	world.add_child(g)
	return g


func label(parent: Node3D, text: String, pos: Vector3, size := 64, color := Color(1, 0.97, 0.88)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.2, 0.12, 0.08)
	l.position = pos
	parent.add_child(l)
	return l


func lamp_light(parent: Node3D, pos: Vector3, color: Color, energy := 1.4, rng_m := 8.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.add_to_group("earth_lamps", true)
	parent.add_child(l)
	return l


# -----------------------------------------------------------------------------
func _environment() -> void:
	var sky_m := ProceduralSkyMaterial.new()
	sky_m.sky_top_color = Color(0.35, 0.5, 0.8)
	sky_m.sky_horizon_color = Color(1.0, 0.65, 0.4)
	sky_m.ground_horizon_color = Color(0.5, 0.4, 0.3)
	sky_m.ground_bottom_color = Color(0.2, 0.15, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_m
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.7, 0.55)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.75, 0.45)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-18, -60, 0)                  # low in the west
	world.add_child(sun)


func _ground_and_street() -> void:
	var g := group("Ground")
	mesh_at(cyl(EDGE + 20, EDGE + 20, 1.0, 48), mat("Autumn Grass", Color(0.45, 0.5, 0.25), 0.95), Vector3(0, -0.5, 0), g)
	var b := StaticBody3D.new()
	b.position = Vector3(0, -0.5, 0)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = EDGE + 20
	shape.height = 1.0
	cs.shape = shape
	b.add_child(cs)
	g.add_child(b)
	mesh_at(cyl(GREEN_R, GREEN_R, 0.06, 48), mat("Town Green", Color(0.38, 0.55, 0.28), 0.95), Vector3(0, 0.02, 0), g)
	var road := mat("Street", Color(0.22, 0.22, 0.25), 0.9)
	var walk := mat("Sidewalk", Color(0.72, 0.68, 0.62), 0.9)
	for k in 4:                                                  # the street: four sides of a square round the green
		var a := k * PI / 2
		var along := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))
		var out := Vector3(cos(a), 0, sin(a))
		var length := STREET * 2 + STREET_W
		mesh_at(box(Vector3(STREET_W, 0.06, length)), road, out * STREET + Vector3(0, 0.03, 0), g, atan2(along.x, along.z))
		for side in [-1, 1]:
			mesh_at(box(Vector3(1.6, 0.14, length + (STREET_W + 1.6) * side)), walk,
				out * (STREET + side * (STREET_W / 2 + 0.8)) + Vector3(0, 0.07, 0), g, atan2(along.x, along.z))
	# A path across the green to the gazebo from each side
	for k in 4:
		var a := k * PI / 2 + PI / 4
		var d := Vector3(cos(a), 0, sin(a))
		mesh_at(box(Vector3(1.6, 0.05, GREEN_R - 4)), walk, d * (4 + (GREEN_R - 4) / 2) + Vector3(0, 0.05, 0), g, atan2(d.x, d.z))
	# The edge: an invisible wall round the town, beyond the houses and trees
	var edge := group("Edge")
	for k in 40:
		var a := k * TAU / 40
		solid_box(Vector3(1.0, 6.0, 2 * EDGE * sin(PI / 40) + 0.5), Vector3(cos(a), 0, sin(a)) * EDGE + Vector3(0, 3, 0), edge, -a)


func _gazebo() -> void:
	var g := group("Gazebo")
	var white := mat("Gazebo White", Color(0.96, 0.95, 0.92), 0.6)
	var roof := mat("Gazebo Roof", Color(0.45, 0.25, 0.22), 0.7)
	mesh_at(cyl(4.2, 4.4, 0.6, 8), white, Vector3(0, 0.3, 0), g, PI / 8)
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 4.3
	shape.height = 0.6
	cs.shape = shape
	cs.position.y = 0.3
	b.add_child(cs)
	g.add_child(b)
	for k in 3:                                                  # steps on the south side
		mesh_at(box(Vector3(2.4, 0.2, 0.6)), white, Vector3(0, 0.1 + k * 0.0, 4.6 + 0.0), g)
	for k in 8:
		var a := k * TAU / 8 + PI / 8
		var p := Vector3(cos(a), 0, sin(a)) * 3.9
		mesh_at(cyl(0.12, 0.12, 2.8, 8), white, p + Vector3(0, 2.0, 0), g)
		if absf(wrapf(a - PI / 2, -PI, PI)) > 0.5:            # railings, open at the front
			var q := Vector3(cos(a + TAU / 16), 0, sin(a + TAU / 16)) * 3.75
			mesh_at(box(Vector3(2.9, 0.1, 0.1)), white, q + Vector3(0, 1.4, 0), g, -(a + TAU / 16) + PI / 2)
			solid_box(Vector3(2.9, 1.0, 0.2), q + Vector3(0, 1.0, 0), g, -(a + TAU / 16) + PI / 2)
	mesh_at(cyl(0.0, 4.8, 2.0, 8), roof, Vector3(0, 4.4, 0), g, PI / 8)
	mesh_at(ball(0.25), white, Vector3(0, 5.5, 0), g)
	# String lights round the roof's edge: grey bulbs until Mr. Palmer has them back (quest earth_lights), then lit
	var unlit := Node3D.new()
	unlit.name = "Gazebo Lights Off"
	unlit.set_script(load("res://scripts/quest_show.gd"))
	unlit.set("quest_done", "earth_lights")
	unlit.set("hide_when_done", true)
	g.add_child(unlit)
	var lit := Node3D.new()
	lit.name = "Gazebo Lights"
	lit.set_script(load("res://scripts/quest_show.gd"))
	lit.set("quest_done", "earth_lights")
	g.add_child(lit)
	var cols := [Color(1.0, 0.8, 0.4), Color(1.0, 0.5, 0.35), Color(1.0, 0.95, 0.7)]
	for k in 32:
		var a := k * TAU / 32
		var p := Vector3(cos(a), 0, sin(a)) * 4.5 + Vector3(0, 3.35 - 0.15 * absf(sin(a * 4)), 0)
		mesh_at(ball(0.07, 8), mat("Bulb Off", Color(0.6, 0.6, 0.6), 0.4), p, unlit)
		mesh_at(ball(0.08, 8), mat("Bulb %d" % (k % 3), cols[k % 3], 0.3, 3.0), p, lit)
	for k in 4:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 1.2
		l.omni_range = 7.0
		l.position = Vector3(cos(k * PI / 2), 0, sin(k * PI / 2)) * 3.0 + Vector3(0, 3.0, 0)
		lit.add_child(l)
	label(g, "Town Green", Vector3(0, 6.6, 0), 56).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for k in 3:                                                  # pumpkins on the gazebo steps
		_pumpkin(g, Vector3(-1.6 + k * 1.6, 0.0, 5.1), 0.3 + 0.08 * k)


func _pumpkin(parent: Node3D, at: Vector3, r: float) -> void:
	var p := mesh_at(ball(r, 12), mat("Pumpkin", Color(0.95, 0.5, 0.12), 0.7), at + Vector3(0, r * 0.7, 0), parent)
	p.scale = Vector3(1.15, 0.8, 1.15)
	mesh_at(cyl(0.03, 0.04, 0.14, 6), mat("Pumpkin Stem", Color(0.3, 0.45, 0.2)), at + Vector3(0, r * 1.4, 0), parent)


func _building(name: String, at: Vector3, yaw: float, size: Vector3, wall: Color, roof_c: Color, sign_text: String,
		awning := Color(0, 0, 0, 0)) -> Node3D:
	# A shop or house along the street, its front (+Z) facing the green
	var g := group(name, at, yaw)
	mesh_at(box(size), mat("Wall " + name, wall, 0.85), Vector3(0, size.y / 2, 0), g)
	solid_box(size, Vector3(0, size.y / 2, 0), g)
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 0.6, 2.2, size.z + 0.6)
	mesh_at(roof, mat("Roof " + name, roof_c, 0.8), Vector3(0, size.y + 1.1, 0), g)
	mesh_at(box(Vector3(1.3, 2.3, 0.15)), mat("Front Door", Color(0.25, 0.15, 0.1)), Vector3(0, 1.15, size.z / 2 + 0.05), g)
	var glass := mat("Warm Window", Color(1.0, 0.85, 0.55), 0.3, 1.6)
	for wx in [-size.x * 0.3, size.x * 0.3]:
		mesh_at(box(Vector3(1.4, 1.2, 0.1)), glass, Vector3(wx, 1.6, size.z / 2 + 0.05), g)
		mesh_at(box(Vector3(1.2, 1.0, 0.1)), glass, Vector3(wx, size.y - 1.2, size.z / 2 + 0.05), g)
	lamp_light(g, Vector3(0, 2.0, size.z / 2 + 1.2), Color(1.0, 0.8, 0.55), 1.0, 6.0)
	if awning.a > 0.0:
		for s in 6:
			var c := awning if s % 2 == 0 else Color(0.95, 0.95, 0.9)
			mesh_at(box(Vector3(size.x / 6, 0.06, 1.4)), mat("Awning %s %d" % [name, s % 2], c, 0.7),
				Vector3(-size.x / 2 + size.x / 12 + s * size.x / 6, 2.9, size.z / 2 + 0.7), g, 0.0, Vector3(0.3, 0, 0))
	if sign_text != "":
		mesh_at(box(Vector3(maxf(3.0, sign_text.length() * 0.32), 0.7, 0.12)), mat("Sign Board", Color(0.18, 0.25, 0.2)),
			Vector3(0, 3.4, size.z / 2 + 0.12), g)
		label(g, sign_text, Vector3(0, 3.4, size.z / 2 + 0.2), 48)
	_pumpkin(g, Vector3(size.x * 0.35 - 0.2, 0, size.z / 2 + 0.6), 0.28)
	return g


func _buildings() -> void:
	var back := STREET + STREET_W / 2 + 1.6 + 5.0                # building centres, behind the sidewalk
	# North side
	_building("Hollow Diner", Vector3(-9, 0, -back), 0.0, Vector3(10, 4.2, 8), Color(0.75, 0.3, 0.25), Color(0.25, 0.22, 0.22),
		"Hollow Diner", Color(0.2, 0.45, 0.35))
	_building("Bookshop", Vector3(9, 0, -back), 0.0, Vector3(9, 5.0, 8), Color(0.35, 0.45, 0.4), Color(0.3, 0.2, 0.18),
		"Turn the Page Books", Color(0.55, 0.2, 0.25))
	# East side
	_building("Corner Market", Vector3(back, 0, -8), -PI / 2, Vector3(10, 4.0, 8), Color(0.92, 0.88, 0.78), Color(0.35, 0.3, 0.3),
		"Corner Market", Color(0.25, 0.4, 0.6))
	_building("Maple Inn", Vector3(back, 0, 9), -PI / 2, Vector3(11, 6.5, 8), Color(0.95, 0.94, 0.9), Color(0.25, 0.3, 0.4),
		"Maple Inn")
	# West side: the town hall with its white steeple
	var hall := _building("Earth Town Hall", Vector3(-back, 0, 0), PI / 2, Vector3(12, 6.0, 9), Color(0.96, 0.95, 0.92),
		Color(0.3, 0.3, 0.32), "Town Hall")
	mesh_at(box(Vector3(2.6, 4.0, 2.6)), mat("Steeple", Color(0.97, 0.96, 0.93)), Vector3(0, 8.5, 0), hall)
	mesh_at(cyl(0.0, 1.9, 4.0, 4), mat("Steeple Roof", Color(0.3, 0.3, 0.32)), Vector3(0, 12.5, 0), hall, PI / 4)
	# South side: homes
	var home_cols := [Color(0.85, 0.75, 0.55), Color(0.6, 0.7, 0.85), Color(0.85, 0.6, 0.55)]
	for k in 3:
		_building("Home %d" % (k + 1), Vector3(-14 + k * 14, 0, back), PI, Vector3(8, 5.0, 7), home_cols[k], Color(0.3, 0.25, 0.25), "")


func _autumn_tree(parent: Node3D, at: Vector3, h: float) -> void:
	var cols := [Color(0.95, 0.45, 0.15), Color(0.85, 0.25, 0.15), Color(0.95, 0.75, 0.2), Color(0.7, 0.35, 0.15)]
	var t := Node3D.new()
	t.position = at
	parent.add_child(t)
	mesh_at(cyl(0.18, 0.32, h, 8), mat("Trunk", Color(0.32, 0.22, 0.15), 0.95), Vector3(0, h / 2, 0), t)
	solid_box(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0), t)
	for k in 4:
		var c: Color = cols[rng.randi() % cols.size()]
		var r := rng.randf_range(1.4, 2.2)
		mesh_at(ball(r, 12), mat("Leaves %s" % c, c, 0.9), Vector3(rng.randf_range(-1, 1), h + rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)), t)


func _trees_and_leaves() -> void:
	var g := group("Autumn Trees")
	for k in 10:                                                  # round the green
		var a := k * TAU / 10 + 0.15
		_autumn_tree(g, Vector3(cos(a), 0, sin(a)) * (GREEN_R - 1.5), rng.randf_range(4.0, 5.5))
	for k in 34:                                                  # behind the buildings, to the edge
		var a := k * TAU / 34
		_autumn_tree(g, Vector3(cos(a), 0, sin(a)) * rng.randf_range(EDGE - 6, EDGE - 1), rng.randf_range(5.0, 7.0))
	# Fallen leaves everywhere (one MultiMesh, so it's cheap)
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.22, 0.16)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = leaf
	mm.instance_count = 900
	for i in mm.instance_count:
		var r := sqrt(rng.randf()) * (EDGE - 2)
		var a := rng.randf() * TAU
		var basis := Basis(Vector3.RIGHT, -PI / 2).rotated(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(a) * r, 0.1, sin(a) * r)))
		mm.set_instance_color(i, [Color(0.95, 0.45, 0.15), Color(0.85, 0.25, 0.15), Color(0.95, 0.75, 0.2)][i % 3])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fallen Leaves"
	mmi.multimesh = mm
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = lm
	g.add_child(mmi)


func _lamps() -> void:
	var g := group("Street Lamps")
	var iron := mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5)
	var glow := mat("Lamp Glass", Color(1.0, 0.85, 0.55), 0.3, 2.0)
	for k in 4:
		var a := k * PI / 2
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))
		for t in [-14.0, 0.0, 14.0]:
			var p: Vector3 = out * (STREET - STREET_W / 2 - 0.9) + along * t
			mesh_at(cyl(0.07, 0.1, 3.6, 8), iron, p + Vector3(0, 1.8, 0), g)
			mesh_at(box(Vector3(0.4, 0.5, 0.4)), glow, p + Vector3(0, 3.7, 0), g)
			lamp_light(g, p + Vector3(0, 3.5, 0), Color(1.0, 0.82, 0.55), 1.6, 9.0)


func _portal() -> void:
	# The old oak by the green, and the portal home shimmering beside it. Nina arrives here.
	var toward := Vector3(-PORTAL_AT.x, 0, -PORTAL_AT.z).normalized()       # from the portal toward the green's middle
	var g := group("Portal Home", PORTAL_AT, atan2(toward.x, toward.z))     # the ring faces the green
	_autumn_tree(g, Vector3(-2.5, 0, -1.5), 6.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.5
	ring.outer_radius = 1.8
	mesh_at(ring, mat("Portal Ring", Color(0.7, 0.5, 1.0), 0.3, 2.0), Vector3(0, 1.8, 0), g, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cyl(1.5, 1.5, 0.05, 32), mat("Portal Swirl", Color(0.6, 0.4, 1.0), 0.2, 1.5, 0.55), Vector3(0, 1.8, 0), g, 0.0, Vector3(PI / 2, 0, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.5, 1.0)
	l.light_energy = 1.5
	l.omni_range = 7.0
	l.position = Vector3(0, 1.8, 1.0)
	g.add_child(l)
	label(g, "Portal home", Vector3(0, 4.0, 0), 56, Color(0.9, 0.8, 1.0)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var exit := Area3D.new()
	exit.name = "PortalHome"
	exit.set_script(load("res://scripts/door.gd"))
	exit.set("destination", TOWN)
	exit.set("spawn", "FromPortaltoEarth")
	exit.set("place_name", "home")
	exit.position = Vector3(0, 1.6, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.2, 0.6)
	cs.shape = shape
	exit.add_child(cs)
	g.add_child(exit)
	var entrance := Marker3D.new()                               # arriving: a few steps out of the portal, facing the gazebo
	entrance.name = "Entrance"
	entrance.position = PORTAL_AT + toward * 5.5 + Vector3(0, 1.0, 0)
	entrance.rotation.y = atan2(-toward.x, -toward.z)                      # her -Z faces the green; the portal's behind
	world.add_child(entrance)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = entrance.position
	world.add_child(player)


func _person(name: String, id: String, at: Vector3, yaw: float, look: Dictionary) -> void:
	var p := Node3D.new()
	p.name = name
	p.set_script(load("res://scripts/earth_person.gd"))
	for k in look:
		p.set(k, look[k])
	p.position = at
	p.rotation.y = yaw
	world.add_child(p)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", id)
	talk.set("display_name", name)
	talk.set("name_height", 2.1)
	p.add_child(talk)


func _people() -> void:
	# Placeholders (simple shapes, no models yet). Mr. Palmer is here in person, at the gazebo.
	_person("Mr. Palmer", "palmer_earth", Vector3(1.5, 0, 6.0), PI * 0.1,
		{"shirt": Color(0.25, 0.3, 0.45), "trousers": Color(0.2, 0.2, 0.25), "glasses": true, "grey_hair": true,
		"tie": Color(0.8, 0.25, 0.3, 1.0), "height": 1.8})
	_person("Miss Ivy", "ivy", Vector3(-6.0, 0, -(STREET + STREET_W / 2 + 1.6) + 0.6), 0.0,
		{"shirt": Color(0.85, 0.4, 0.45), "trousers": Color(0.3, 0.25, 0.3), "hair": Color(0.55, 0.25, 0.15), "height": 1.68})
	_person("Theo", "theo", Vector3(12.0, 0, -(STREET + STREET_W / 2 + 1.6) + 0.8), -0.3,
		{"shirt": Color(0.35, 0.6, 0.4), "trousers": Color(0.25, 0.3, 0.45), "hair": Color(0.15, 0.1, 0.08), "height": 1.3,
		"glasses": true, "skin": Color(0.55, 0.4, 0.3)})


func _light_boxes() -> void:
	# The gazebo's lost boxes of string lights (quest earth_lights): by the diner, the bookshop and the inn
	var spots := [[Vector3(-13.5, 0, -(STREET + STREET_W / 2 + 1.0)), "lights_diner"],
		[Vector3(4.5, 0, -(STREET + STREET_W / 2 + 1.0)), "lights_bookshop"],
		[Vector3(STREET + STREET_W / 2 + 1.0, 0, 14.5), "lights_inn"]]
	var g := group("Lost Lights")
	for k in spots.size():
		var a := Area3D.new()
		a.name = "Light Box %d" % (k + 1)
		a.set_script(load("res://scripts/quest_spot.gd"))
		a.set("quest", "earth_lights")
		a.set("step", "find")
		a.set("flag", spots[k][1])
		a.set("action", "pick up the box of lights")
		a.set("done_message", "A box of string lights for the gazebo!")
		a.position = spots[k][0]
		g.add_child(a)
		var before := Node3D.new()
		before.name = "Before"
		a.add_child(before)
		mesh_at(box(Vector3(0.6, 0.4, 0.45)), mat("Cardboard", Color(0.7, 0.55, 0.35)), Vector3(0, 0.2, 0), before)
		for q in 3:
			mesh_at(ball(0.07, 8), mat("Bulb %d" % q, [Color(1.0, 0.8, 0.4), Color(1.0, 0.5, 0.35), Color(1.0, 0.95, 0.7)][q], 0.3, 3.0),
				Vector3(-0.15 + q * 0.15, 0.45, 0), before)
		var done := Node3D.new()
		done.name = "Done"
		a.add_child(done)
