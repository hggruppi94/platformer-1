extends SceneTree

# Builds res://scenes/earth/earth.tscn: the little Earth town where the player lives. A cozy autumn town: a town green
# with a white gazebo in the middle, a street round it with lamps, a diner, a bookshop, the corner market, an inn,
# the town hall with its white steeple and a few homes, autumn trees, fallen leaves and pumpkins on the steps. Past the
# green's southeast corner, the old red barn is the dance studio: walk in through its big doors. The middle home on
# the south side is the player's own: walk in, and their bed is inside (a new game starts there).
# By the old oak is the portal to Galaxity, open during the Shift. Logic: scripts/earth_world.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_earth.gd

const OUT := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const GREEN_R := 13.0                             # the town green
const STREET := 21.0                              # the street runs round the green, this far out (a square)
const STREET_W := 6.0
const EDGE := 64.0                                # an invisible wall this far out
const STUDIO_AT := Vector3(35, 0, 35)             # the barn dance studio, past the southeast corner of the green
const STUDIO_SIZE := Vector3(14, 6, 18)           # width, wall height, depth
const PORTAL_AT := Vector3(-10, 0, 10)            # the old oak and the portal to Galaxity, on the green's corner
const HOME_SIZE := Vector3(10, 4.6, 9)            # the player's house: width, wall height, depth

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}


func _initialize() -> void:
	rng.seed = 1999
	world = Node3D.new()
	world.name = "Earth"
	world.set_script(load("res://scripts/earth_world.gd"))
	_environment()
	_sky()
	_ground_and_street()
	_gazebo()
	_buildings()
	_dance_studio()
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
func sky_mat(name: String, color: Color) -> StandardMaterial3D:
	# Unshaded and fog-free, for things far up in the sky. scripts/earth_world.gd recolours them through the day.
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	return m


func _sky() -> void:
	# An Earth sky: soft white clouds drifting high around the town, stars and the moon for the night. The sky's
	# colours, the sun, the moon's place and the clouds' colours change with Earth's clock (scripts/earth_world.gd).
	var g := group("Sky")
	var sky_rng := RandomNumberGenerator.new()           # its own, so the town's trees and leaves stay where they were
	sky_rng.seed = 2024
	var clouds := Node3D.new()
	clouds.name = "Clouds"
	g.add_child(clouds)
	var cloud_m := sky_mat("Earth Cloud", Color(1, 1, 1, 0.92))
	for k in 18:
		# A fluffy cumulus: a flat-bottomed row of puffs, the middle ones biggest
		var a := TAU * k / 18.0 + sky_rng.randf_range(-0.12, 0.12)
		var dist := sky_rng.randf_range(260.0, 420.0)
		var c := Node3D.new()
		c.position = Vector3(cos(a) * dist, sky_rng.randf_range(75.0, 150.0), sin(a) * dist)
		c.rotation.y = -a + PI / 2                       # its long side across the view from town
		clouds.add_child(c)
		var size := sky_rng.randf_range(14.0, 26.0)
		var puffs := sky_rng.randi_range(4, 7)
		for q in puffs:
			var t := (q + 0.5) / puffs - 0.5
			var r := size * (1.0 - absf(t) * 1.1) * sky_rng.randf_range(0.8, 1.1)
			var pm := mesh_at(ball(1.0, 16), cloud_m, Vector3(t * size * 2.4, r * 0.35, sky_rng.randf_range(-0.3, 0.3) * size), c)
			pm.scale = Vector3(r, r * 0.7, r * 0.8)
			pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Stars on a dome, only at night
	var stars := Node3D.new()
	stars.name = "Stars"
	g.add_child(stars)
	var star_m := sky_mat("Earth Star", Color(1, 0.98, 0.9, 0.0))
	for k in 220:
		var a := sky_rng.randf() * TAU
		var up := asin(sky_rng.randf_range(0.12, 1.0))
		var d := Vector3(cos(a) * cos(up), sin(up), sin(a) * cos(up))
		var sm := mesh_at(ball(sky_rng.randf_range(0.9, 2.2), 6), star_m, d * 900.0, stars)
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The moon: a pale disc with a soft glow round it. It rises opposite the sun.
	var moon := Node3D.new()
	moon.name = "Moon"
	moon.position = Vector3(300, 420, -500)
	g.add_child(moon)
	var mm := mesh_at(ball(26.0, 24), sky_mat("Earth Moon", Color(0.97, 0.96, 0.88, 0.0)), Vector3.ZERO, moon)
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sea_m := sky_mat("Earth Moon Sea", Color(0.78, 0.78, 0.76, 0.0))
	for spot in [[Vector3(-7, 8, -20), 6.0], [Vector3(9, -4, -21), 8.0], [Vector3(-2, -12, -22), 4.5]]:   # its grey seas
		var sea := mesh_at(ball(spot[1], 10), sea_m, spot[0], moon)
		sea.scale = Vector3(1, 1, 0.3)
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := mesh_at(ball(48.0, 24), sky_mat("Earth Moon Glow", Color(0.75, 0.82, 1.0, 0.0)), Vector3.ZERO, moon)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	env.fog_sky_affect = 0.15                                      # haze over the town, but the sky keeps its colours
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
	for k in [0, 2]:
		_building("Home %d" % (k + 1), Vector3(-14 + k * 14, 0, back), PI, Vector3(8, 5.0, 7), home_cols[k], Color(0.3, 0.25, 0.25), "")
	_my_home(Vector3(0, 0, back + 1.0), home_cols[1])


func _my_home(at: Vector3, wall: Color) -> void:
	# The player's house, in the middle of the south side, facing the green. Hollow like the barn, with a doorway to walk
	# in by: a wooden floor, a rug, their bed (scripts/bed.gd) at the back, a lamp, and warm windows. A new game starts
	# just out of bed (HomeSpawn), and the character creator stands them on the rug (CreatorSpot).
	var g := group("My Home", at, PI)
	var hd := HOME_SIZE.z / 2.0
	var h := HOME_SIZE.y
	var wall_m := mat("Wall My Home", wall, 0.85)
	var shell := CSGCombiner3D.new()
	shell.name = "House"
	shell.use_collision = true
	g.add_child(shell)
	var outer := CSGBox3D.new()
	outer.size = HOME_SIZE
	outer.position = Vector3(0, h / 2.0, 0)
	outer.material = wall_m
	shell.add_child(outer)
	var hollow := CSGBox3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = HOME_SIZE - Vector3(0.6, 0.2, 0.6)                 # from just under the ground to under the ceiling
	hollow.position = Vector3(0, h / 2.0 - 0.2, 0)
	hollow.material = mat("Wall Inside", Color(0.95, 0.9, 0.8), 0.9)
	shell.add_child(hollow)
	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	doorway.size = Vector3(1.8, 2.7, 1.2)
	doorway.position = Vector3(0, 1.35, hd)
	doorway.material = wall_m
	shell.add_child(doorway)
	var roof := PrismMesh.new()
	roof.size = Vector3(HOME_SIZE.x + 0.6, 2.2, HOME_SIZE.z + 0.6)
	mesh_at(roof, mat("Roof My Home", Color(0.3, 0.25, 0.25), 0.8), Vector3(0, h + 1.1, 0), g)
	mesh_at(box(Vector3(HOME_SIZE.x - 0.7, 0.04, HOME_SIZE.z - 0.7)), mat("Home Floor", Color(0.62, 0.44, 0.3), 0.8),
		Vector3(0, 0.02, 0), g)
	# The front: a door frame, warm windows either side, a sign and a pumpkin on the step
	var trim := mat("Home Trim", Color(0.96, 0.94, 0.9), 0.7)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.2, 2.8, 0.2)), trim, Vector3(sx * 1.0, 1.4, hd + 0.05), g)
	mesh_at(box(Vector3(2.2, 0.2, 0.2)), trim, Vector3(0, 2.8, hd + 0.05), g)
	var glass := mat("Warm Window", Color(1.0, 0.85, 0.55), 0.3, 1.6)
	for wx in [-HOME_SIZE.x * 0.28, HOME_SIZE.x * 0.28]:
		mesh_at(box(Vector3(1.6, 1.2, 0.1)), glass, Vector3(wx, 1.7, hd + 0.05), g)
		mesh_at(box(Vector3(1.6, 1.2, 0.1)), glass, Vector3(wx, 1.7, hd - 0.33), g)
	mesh_at(box(Vector3(3.0, 0.7, 0.12)), mat("Sign Board", Color(0.18, 0.25, 0.2)), Vector3(0, 3.5, hd + 0.12), g)
	label(g, "Home", Vector3(0, 3.5, hd + 0.2), 48)
	_pumpkin(g, Vector3(1.6, 0, hd + 0.6), 0.28)
	lamp_light(g, Vector3(0, 2.4, hd + 1.2), Color(1.0, 0.8, 0.55), 1.0, 6.0)
	# Inside: a warm lamp that's always on, a rug and the bed at the back
	var inside := OmniLight3D.new()
	inside.light_color = Color(1.0, 0.85, 0.65)
	inside.light_energy = 1.3
	inside.omni_range = 9.0
	inside.position = Vector3(0, h - 0.8, 0)
	g.add_child(inside)
	mesh_at(cyl(2.0, 2.0, 0.04, 32), mat("Home Rug", Color(0.6, 0.45, 0.85), 0.9), Vector3(0, 0.05, 0.6), g)
	var stage := Marker3D.new()
	stage.name = "CreatorSpot"
	stage.position = Vector3(0, 1.0, 1.4)
	g.add_child(stage)
	var bed := Node3D.new()
	bed.name = "Bed"
	bed.position = Vector3(-2.8, 0, -2.6)
	g.add_child(bed)
	var frame := mat("Bed Wood", Color(0.5, 0.32, 0.2), 0.7)
	solid_box(Vector3(2.0, 0.5, 3.0), Vector3(0, 0.25, 0), bed)
	mesh_at(box(Vector3(2.0, 0.5, 3.0)), frame, Vector3(0, 0.25, 0), bed)
	mesh_at(box(Vector3(1.9, 0.3, 2.8)), mat("Mattress", Color(0.97, 0.94, 0.88), 0.7), Vector3(0, 0.65, 0), bed)
	mesh_at(box(Vector3(1.98, 0.14, 1.9)), mat("Blanket", Color(0.3, 0.45, 0.75), 0.8), Vector3(0, 0.84, 0.45), bed)
	mesh_at(box(Vector3(1.2, 0.22, 0.55)), mat("Pillow", Color(1, 1, 1), 0.8), Vector3(0, 0.92, -1.0), bed)
	solid_box(Vector3(2.0, 1.4, 0.2), Vector3(0, 0.7, -1.5), bed)
	mesh_at(box(Vector3(2.0, 1.4, 0.2)), frame, Vector3(0, 0.7, -1.5), bed)
	var sleep_area := Area3D.new()
	sleep_area.name = "SleepSpot"
	sleep_area.set_script(load("res://scripts/bed.gd"))
	var scs := CollisionShape3D.new()
	var sshape := SphereShape3D.new()
	sshape.radius = 2.4
	scs.shape = sshape
	scs.position = Vector3(0, 1.0, 0.6)
	sleep_area.add_child(scs)
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = "Press F to sleep"
	prompt.font_size = 44
	prompt.pixel_size = 0.01
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0.15, 0.1, 0.12)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.position = Vector3(0, 2.3, 0)
	sleep_area.add_child(prompt)
	bed.add_child(sleep_area)
	var wake := Marker3D.new()                        # just out of bed, facing the door
	wake.name = "HomeSpawn"
	wake.position = Vector3(-0.9, 1.0, -0.8)
	wake.rotation.y = PI                             # (her -Z faces the doorway, at the house's +Z)
	g.add_child(wake)


func _dance_studio() -> void:
	# The old red barn past the southeast corner of the green, made into the town's dance studio. Walk in through the
	# big open doors: a maple floor, a mirror wall, ballet barres down both sides, string lights along the rafters
	# and a disco ball over the middle. Out front: a picket fence, hay bales, pumpkins and a class board.
	var toward := Vector3(-STUDIO_AT.x, 0, -STUDIO_AT.z).normalized()     # its doors face the green
	var g := group("Dance Studio", STUDIO_AT, atan2(toward.x, toward.z))
	var red := mat("Barn Red", Color(0.62, 0.14, 0.12), 0.85)
	var white := mat("Barn Trim", Color(0.96, 0.94, 0.9), 0.7)
	var plank := mat("Barn Planks", Color(0.55, 0.38, 0.24), 0.9)
	var shingle := mat("Barn Roof", Color(0.24, 0.22, 0.24), 0.85)
	var glass := mat("Warm Window", Color(1.0, 0.85, 0.55), 0.3, 1.6)
	var hw := STUDIO_SIZE.x / 2.0                                      # half its width
	var hd := STUDIO_SIZE.z / 2.0                                      # half its depth
	var wall_h := STUDIO_SIZE.y
	# The gambrel shape: steep lower roof, shallow upper roof
	var profile := PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, wall_h), Vector2(hw * 0.63, wall_h + 3.4),
		Vector2(0, wall_h + 4.6), Vector2(-hw * 0.63, wall_h + 3.4), Vector2(-hw, wall_h)])
	var inner := PackedVector2Array()
	for p in profile:
		inner.append(Vector2(p.x * (hw - 0.3) / hw, -0.2 if p.y == 0.0 else p.y - 0.3))

	# The shell: one solid barn, hollowed out, with the doorway cut through the front. Solid to walk against.
	var shell := CSGCombiner3D.new()
	shell.name = "Barn"
	shell.use_collision = true
	g.add_child(shell)
	var outer := CSGPolygon3D.new()
	outer.polygon = profile
	outer.depth = STUDIO_SIZE.z
	outer.position = Vector3(0, 0, hd)
	outer.material = red
	shell.add_child(outer)
	var hollow := CSGPolygon3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.polygon = inner
	hollow.depth = STUDIO_SIZE.z - 0.6
	hollow.position = Vector3(0, 0, hd - 0.3)
	hollow.material = plank
	shell.add_child(hollow)
	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	doorway.size = Vector3(4.6, 4.8, 1.2)
	doorway.position = Vector3(0, 2.4, hd)
	doorway.material = plank
	shell.add_child(doorway)

	# Roof slabs over the gambrel, overhanging a little
	for i in [2, 3, 4, 5]:
		var a := profile[i]
		var b := profile[i + 1]
		var d := b - a
		var n := Vector2(d.y, -d.x).normalized() * (1.0 if i < 4 else 1.0)
		if n.y < 0.0:
			n = -n
		var mid := (a + b) / 2.0 + n * 0.14
		mesh_at(box(Vector3(d.length() + 0.35, 0.22, STUDIO_SIZE.z + 0.8)), shingle, Vector3(mid.x, mid.y, 0), g, 0.0,
			Vector3(0, 0, atan2(d.y, d.x)))
	# White trim: corner boards, the door frame, and the hayloft door up in the gable
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mesh_at(box(Vector3(0.3, wall_h, 0.3)), white, Vector3(sx * (hw + 0.02), wall_h / 2.0, sz * (hd + 0.02)), g)
	mesh_at(box(Vector3(5.2, 0.3, 0.3)), white, Vector3(0, 4.95, hd + 0.05), g)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.3, 4.8, 0.3)), white, Vector3(sx * 2.45, 2.4, hd + 0.05), g)
	mesh_at(box(Vector3(2.4, 2.2, 0.12)), plank, Vector3(0, wall_h + 1.3, hd + 0.03), g)
	_white_x(g, Vector3(0, wall_h + 1.3, hd + 0.1), Vector2(2.4, 2.2), white)
	# The big sliding doors, pushed open either side of the doorway, each with a white X
	for sx in [-1.0, 1.0]:
		var dp: Vector3 = Vector3(sx * 3.6, 2.4, hd + 0.25)
		mesh_at(box(Vector3(2.4, 4.8, 0.15)), red, dp, g)
		_white_x(g, dp + Vector3(0, 0, 0.1), Vector2(2.4, 4.8), white)
	# Windows down both sides, glowing warm from the lights inside
	for sx in [-1.0, 1.0]:
		for k in 3:
			var wz := -hd + 4.0 + k * (STUDIO_SIZE.z - 8.0) / 2.0
			mesh_at(box(Vector3(0.12, 1.4, 1.8)), glass, Vector3(sx * (hw + 0.04), 3.0, wz), g)
			mesh_at(box(Vector3(0.16, 1.6, 0.14)), white, Vector3(sx * (hw + 0.06), 3.0, wz), g)
	label(g, "Dance Studio", Vector3(0, 5.6, hd + 0.25), 72, Color(1.0, 0.92, 0.95))

	# Inside: the maple floor, a mirror wall at the back, barres, benches and a little stage
	mesh_at(box(Vector3(STUDIO_SIZE.x - 0.7, 0.08, STUDIO_SIZE.z - 0.7)), mat("Maple Floor", Color(0.85, 0.66, 0.42), 0.35),
		Vector3(0, 0.04, 0), g)
	var mirror := mat("Studio Mirror", Color(0.78, 0.86, 0.95), 0.05)
	mirror.metallic = 0.9
	mesh_at(box(Vector3(STUDIO_SIZE.x - 1.4, 3.2, 0.08)), mirror, Vector3(0, 2.1, -hd + 0.36), g)
	mesh_at(box(Vector3(STUDIO_SIZE.x - 1.2, 0.12, 0.12)), white, Vector3(0, 3.75, -hd + 0.36), g)
	var wood := mat("Barre Wood", Color(0.72, 0.52, 0.32), 0.5)
	for sx in [-1.0, 1.0]:
		var bx: float = sx * (hw - 0.65)
		mesh_at(cyl(0.05, 0.05, STUDIO_SIZE.z - 5.0, 10), wood, Vector3(bx, 1.05, 0.5), g, 0.0, Vector3(PI / 2, 0, 0))
		for k in 5:
			var bz := -hd + 2.5 + k * (STUDIO_SIZE.z - 5.0) / 4.0 + 0.5
			mesh_at(box(Vector3(0.36, 0.06, 0.06)), mat("Barre Bracket", Color(0.75, 0.75, 0.78), 0.3), Vector3(sx * (hw - 0.47), 1.05, bz), g)
		mesh_at(box(Vector3(0.5, 0.45, 3.2)), plank, Vector3(sx * (hw - 0.6), 0.25, hd - 3.2), g)        # a bench
		solid_box(Vector3(0.5, 0.45, 3.2), Vector3(sx * (hw - 0.6), 0.25, hd - 3.2), g)
	mesh_at(box(Vector3(6.0, 0.4, 2.2)), plank, Vector3(0, 0.2, -hd + 1.9), g)                          # the stage
	solid_box(Vector3(6.0, 0.4, 2.2), Vector3(0, 0.2, -hd + 1.9), g)
	for sx in [-1.0, 1.0]:                                                                              # speakers
		mesh_at(box(Vector3(0.7, 1.1, 0.6)), mat("Speaker", Color(0.12, 0.12, 0.14), 0.6), Vector3(sx * 2.6, 0.95, -hd + 1.6), g)
		mesh_at(cyl(0.22, 0.22, 0.05, 16), mat("Speaker Cone", Color(0.3, 0.3, 0.34), 0.4), Vector3(sx * 2.6, 1.0, -hd + 1.92), g,
			0.0, Vector3(PI / 2, 0, 0))
	# Rafters with string lights, and a disco ball in the middle
	var cols := [Color(1.0, 0.55, 0.8), Color(0.6, 0.85, 1.0), Color(1.0, 0.9, 0.55), Color(0.8, 0.6, 1.0)]
	for k in 5:
		var rz := -hd + 1.5 + k * (STUDIO_SIZE.z - 3.0) / 4.0
		mesh_at(box(Vector3(STUDIO_SIZE.x - 0.6, 0.25, 0.25)), plank, Vector3(0, wall_h - 0.3, rz), g)
		for b in 12:
			var bx := -hw + 1.0 + b * (STUDIO_SIZE.x - 2.0) / 11.0
			mesh_at(ball(0.07, 8), mat("Studio Bulb %d" % (b % 4), cols[b % 4], 0.3, 3.0),
				Vector3(bx, wall_h - 0.55 - 0.12 * absf(sin(b * 0.6)), rz), g)
	var disco := mesh_at(ball(0.55, 20), mat("Disco Ball", Color(0.92, 0.92, 0.98), 0.08, 0.6), Vector3(0, wall_h + 1.6, 0), g)
	(disco.material_override as StandardMaterial3D).metallic = 1.0
	disco.set_script(load("res://scripts/spin.gd"))
	mesh_at(cyl(0.02, 0.02, 1.8, 6), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(0, wall_h + 2.7, 0), g)
	var spots := [[Vector3(-3, wall_h - 0.6, -3), cols[0]], [Vector3(3, wall_h - 0.6, -3), cols[1]],
		[Vector3(-3, wall_h - 0.6, 4), cols[3]], [Vector3(3, wall_h - 0.6, 4), cols[2]]]
	for s in spots:
		var l := OmniLight3D.new()
		l.light_color = s[1]
		l.light_energy = 1.3
		l.omni_range = 9.0
		l.position = s[0]
		g.add_child(l)
	# Music while she's inside (scripts/music_zone.gd)
	var zone := Area3D.new()
	zone.name = "StudioMusic"
	zone.set_script(load("res://scripts/music_zone.gd"))
	zone.set("track", "interior")
	var zs := CollisionShape3D.new()
	var zb := BoxShape3D.new()
	zb.size = Vector3(STUDIO_SIZE.x - 0.6, 5.0, STUDIO_SIZE.z - 0.6)
	zs.shape = zb
	zs.position = Vector3(0, 2.5, 0)
	zone.add_child(zs)
	g.add_child(zone)

	# Out front: a gravel path from the corner of the street, picket fences, hay bales, pumpkins and the class board
	var front := hd + 0.3
	var corner := (STREET + STREET_W / 2.0 + 1.6) * sqrt(2.0)               # the street corner's distance from the middle
	var path_len := STUDIO_AT.length() - front - corner + 1.0
	mesh_at(box(Vector3(3.6, 0.06, path_len)), mat("Gravel", Color(0.72, 0.66, 0.58), 0.95), Vector3(0, 0.04, front + path_len / 2.0), g)
	for sx in [-1.0, 1.0]:
		_picket_fence(g, Vector3(sx * 2.4, 0, front + 0.5), Vector3(sx * hw * 1.05, 0, front + 0.5), white)
		_picket_fence(g, Vector3(sx * hw * 1.05, 0, front + 0.5), Vector3(sx * hw * 1.05, 0, -hd * 0.4), white)
		for k in 2:                                                          # hay bales by the doors
			var hp: Vector3 = Vector3(sx * (3.6 + k * 1.3), 0.45, front + 1.6 + k * 0.4)
			mesh_at(cyl(0.6, 0.6, 1.2, 16), mat("Hay", Color(0.88, 0.74, 0.38), 0.95), hp, g, 0.0, Vector3(0, 0, PI / 2))
			solid_box(Vector3(1.2, 0.9, 1.0), hp, g)
		_pumpkin(g, Vector3(sx * 3.4, 0.9, front + 1.6), 0.3)
		_pumpkin(g, Vector3(sx * 2.6, 0.0, front + 2.6), 0.34)
	var board := Node3D.new()
	board.position = Vector3(4.2, 0, front + 4.0)
	board.rotation.y = -0.35
	g.add_child(board)
	for sx in [-0.45, 0.45]:
		mesh_at(box(Vector3(0.08, 1.5, 0.08)), plank, Vector3(sx, 0.75, 0), board)
	mesh_at(box(Vector3(1.3, 1.0, 0.06)), mat("Chalkboard", Color(0.12, 0.18, 0.15), 0.9), Vector3(0, 1.1, 0), board)
	label(board, "Dance class\ntoday!\nAll welcome", Vector3(0, 1.1, 0.05), 28, Color(0.98, 0.96, 0.9))
	lamp_light(g, Vector3(0, 4.6, front + 1.6), Color(1.0, 0.8, 0.55), 1.4, 9.0)
	# Madame Celeste, who runs the studio
	_person("Madame Celeste", "celeste", STUDIO_AT + toward * 2.0, atan2(toward.x, toward.z),
		{"shirt": Color(0.75, 0.35, 0.6), "trousers": Color(0.15, 0.12, 0.18), "hair": Color(0.12, 0.08, 0.08), "height": 1.72})


func _white_x(parent: Node3D, at: Vector3, size: Vector2, m: Material) -> void:
	# A white X brace across a barn door (and the frame round it)
	var diag := atan2(size.y, size.x)
	var len := size.length() - 0.2
	for s in [-1.0, 1.0]:
		mesh_at(box(Vector3(len, 0.18, 0.06)), m, at, parent, 0.0, Vector3(0, 0, s * diag))
	for sy in [-1.0, 1.0]:
		mesh_at(box(Vector3(size.x, 0.18, 0.06)), m, at + Vector3(0, sy * (size.y / 2.0 - 0.09), 0), parent)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.18, size.y, 0.06)), m, at + Vector3(sx * (size.x / 2.0 - 0.09), 0, 0), parent)


func _picket_fence(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	# A white picket fence from a to b, solid to walk against
	var d := b - a
	var yaw := atan2(d.x, d.z)
	var n := int(d.length() / 0.35)
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(n, 1))
		mesh_at(box(Vector3(0.1, 1.0, 0.06)), m, p + Vector3(0, 0.5, 0), parent, yaw + PI / 2)
		mesh_at(cyl(0.0, 0.07, 0.14, 4), m, p + Vector3(0, 1.07, 0), parent, yaw + PI / 2 + PI / 4)
	for y in [0.35, 0.8]:
		mesh_at(box(Vector3(0.06, 0.08, d.length())), m, (a + b) / 2.0 + Vector3(0, y, 0), parent, yaw)
	solid_box(Vector3(0.15, 1.0, d.length()), (a + b) / 2.0 + Vector3(0, 0.5, 0), parent, yaw)


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
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(EDGE - 6, EDGE - 1)
		if at.distance_to(STUDIO_AT) < 16.0:
			continue                                              # not on the dance studio
		_autumn_tree(g, at, rng.randf_range(5.0, 7.0))
	# Fallen leaves everywhere (one MultiMesh, so it's cheap)
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.22, 0.16)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = leaf
	mm.instance_count = 1500
	for i in mm.instance_count:
		var r := sqrt(rng.randf()) * (EDGE - 2)
		var a := rng.randf() * TAU
		if Vector3(cos(a) * r, 0, sin(a) * r).distance_to(STUDIO_AT) < 12.0:
			r *= 0.5                                              # not on the studio's floor
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
	# The old oak by the green, and the portal to Galaxity beside it (open during the Shift: scripts/earth_world.gd shows
	# its swirl and glow then). Coming home from Galaxity, the player arrives here.
	var toward := Vector3(-PORTAL_AT.x, 0, -PORTAL_AT.z).normalized()       # from the portal toward the green's middle
	var g := group("Portal Home", PORTAL_AT, atan2(toward.x, toward.z))     # the ring faces the green
	_autumn_tree(g, Vector3(-2.5, 0, -1.5), 6.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.5
	ring.outer_radius = 1.8
	mesh_at(ring, mat("Portal Ring", Color(0.7, 0.5, 1.0), 0.3, 2.0), Vector3(0, 1.8, 0), g, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cyl(1.5, 1.5, 0.05, 32), mat("Portal Swirl", Color(0.6, 0.4, 1.0), 0.2, 1.5, 0.55), Vector3(0, 1.8, 0), g, 0.0,
		Vector3(PI / 2, 0, 0)).name = "Portal Swirl"
	var l := OmniLight3D.new()
	l.name = "Portal Glow"
	l.light_color = Color(0.7, 0.5, 1.0)
	l.light_energy = 1.5
	l.omni_range = 7.0
	l.position = Vector3(0, 1.8, 1.0)
	g.add_child(l)
	label(g, "Portal to Galaxity", Vector3(0, 4.0, 0), 56, Color(0.9, 0.8, 1.0)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var exit := Area3D.new()
	exit.name = "PortalToGalaxity"
	exit.set_script(load("res://scripts/door.gd"))
	exit.set("destination", TOWN)
	exit.set("spawn", "FromPortaltoEarth")
	exit.set("place_name", "Galaxity")
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
