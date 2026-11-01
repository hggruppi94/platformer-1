extends SceneTree

# Builds res://scenes/earth/earth.tscn: the Earth town where the player lives, a cozy autumn town with a Halloween
# feel (jack-o'-lanterns, orange and purple string lights, scarecrows, mist on the pond). In the middle, the town green
# with its white gazebo and a street round it: the Hollow Diner, Turn the Page Books, the Corner Market, the Maple Inn,
# the Town Hall (walk in: town meetings happen there) and the homes on the south side, the middle one the player's own
# (walk in: their bed is inside, and a new game starts there). Past the green's southeast corner, the old red barn is
# the dance studio. By the old oak is the portal to Galaxity, open during the Shift. Logic: scripts/earth_world.gd.
#
# Round it (since Oct 30, 2026):
# - Main Street runs north from the green: Crumb & Cauldron Bakery, Gizmo & Gumdrop Toys (both walk-in), Cobweb
#   Corner Antiques, Nuts & Bolts Hardware (with a loading dock to skate), Lantern Hill Library (walk-in, up its steps
#   with handrails to grind), Fire Station No. 1, and Old Oak Elementary at the top, with the Hollow Skate Yard beside it.
# - Maple Lane, the residential street to the south: the Blastoffs' house (Nina, Prue and Bruno; walk in, a bedroom
#   each), Mr. Palmer's house and five more, joined to the green by Hollow Lane. The old covered bridge carries it over
#   Whisper Creek.
# - The park west of the Town Hall: Willow Pond with a dock, the creek and its footbridge, the playground with the
#   slide, the pumpkin patch, and Lookout Hill with Mossy Falls coming off its cliff. The hill's slopes are for riding
#   down: a big kicker at the bottom and a rail all the way down.
# The ground (hills, pond, creek) is scripts/earth_land.gd, which makes its mesh when the town loads. The town map
# (res://ui/earth_map.json) is written from what's built here, for scripts/map_screen.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_earth.gd

const OUT := "res://scenes/earth/earth.tscn"
const MAP_OUT := "res://ui/earth_map.json"
const PLACES_OUT := "res://routines/earth_places.json"     # the paths people walk (scripts/town_paths.gd)
const TOWN := "res://scenes/town/town.tscn"
const GREEN_R := 13.0                             # the town green
const STREET := 21.0                              # the street runs round the green, this far out (a square)
const STREET_W := 6.0
const EDGE := 64.0                                # (the old round edge: trees still ring the old town about here)
const BOUNDS := Rect2(-152, -152, 244, 254)       # the invisible walls: x -152..92, z -152..102
const STUDIO_AT := Vector3(35, 0, 35)             # the barn dance studio, past the southeast corner of the green
const STUDIO_SIZE := Vector3(14, 6, 18)           # width, wall height, depth
const PORTAL_AT := Vector3(-10, 0, 10)            # the old oak and the portal to Galaxity, on the green's corner
const HOME_SIZE := Vector3(10, 4.6, 9)            # the player's house: width, wall height, depth
const MAIN_Z := Vector2(-36, -120)                # Main Street runs north along x = 0, from z -36 to -120
const MAPLE_Z := 58.0                             # Maple Lane runs east-west along this z
const MAPLE_X := Vector2(-150, 62)
const HOLLOW_X := -26.0                           # Hollow Lane, from the green's southwest corner down to Maple Lane
const BRIDGE_X := Vector2(-110, -96)              # the covered bridge's span along Maple Lane
const YARD := Rect2(10, -122, 40, 44)             # the Hollow Skate Yard's concrete: x 10..50, z -122..-78
const YARD_FLOOR := 0.2
# The Autumn Festival's spots round the gazebo (scripts/festival_green.gd SPOTS: the same angles, in degrees). It's put
# up at play time, but the people who come to it need points to walk to: one on a ring round the gazebo in front of
# each spot, and one beside each stall for whoever runs it.
const FESTIVAL := {"hay": 62.6, "apples": 350.6, "treats": 314.6, "pies": 278.6, "lanterns": 242.6, "cider": 206.6}

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var kit: SkateKit
var feet := []                                    # [{name, at: Vector2, size: Vector2, yaw, label, kind}] for the map and clearances
var roads := []                                   # [a: Vector2, b: Vector2, width, kind]
var bulbs := []                                   # [position, colour] for all the string lights (one MultiMesh)
var flags := []                                   # [position, yaw, colour] for all the bunting
var spots := []                                   # [name, Vector2] extra labels for the map (pond, creek, hill...)
var tree_parts := []                              # [kind, Transform3D, colour] for the batched trees


func _initialize() -> void:
	rng.seed = 1999
	world = Node3D.new()
	world.name = "Earth"
	world.set_script(load("res://scripts/earth_world.gd"))
	kit = SkateKit.new(func(n: String, col: Color, rough: float, metal: float) -> Material:
		return mat("Skate " + n, EARTH_SKATE.get(n, col), rough, metal))
	_environment()
	_sky()
	_ground_and_street()
	_gazebo()
	_buildings()
	_main_street()
	_maple_lane()
	_park()
	_water()
	_skate_yard()
	_skate_spots()
	_dance_studio()
	_trees_and_leaves()
	_lamps()
	_halloween()
	_portal()
	_people()
	_light_boxes()
	_strings_and_bunting()
	_own(world)
	var scene := PackedScene.new()
	print("SAVED ", OUT, " pack=", scene.pack(world), " save=", ResourceSaver.save(scene, OUT))
	_write_map()
	_write_places()
	quit()


# The skate pieces in Earth's colours: painted wood ramps, grey concrete, orange rails (it's autumn)
const EARTH_SKATE := {
	"Ramp": Color(0.72, 0.58, 0.42), "Coping": Color(0.8, 0.8, 0.82), "Kicker": Color(0.62, 0.45, 0.3),
	"Funbox": Color(0.45, 0.32, 0.55), "Ledge": Color(0.66, 0.65, 0.63), "Ledge Edge": Color(0.85, 0.85, 0.88),
	"Rail": Color(0.95, 0.5, 0.15), "Concrete": Color(0.66, 0.65, 0.63),
}


func multi(name: String, mesh: Mesh, xforms: Array, cols: Array, m: Material) -> MultiMeshInstance3D:
	# Many copies of one mesh, each with its own place and colour, drawn as one. The instances are kept on the node and
	# put into the MultiMesh when the town loads (scripts/multi_fill.gd): a --headless build can't save them itself.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.name = name
	mi.multimesh = mm
	mi.material_override = m
	MultiFill.pack(mi, xforms, cols)
	return mi


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
	env.fog_density = 0.0035                                       # (lighter since the town grew: it's much wider now)
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
	# The land itself: flat round the town, dipping into the pond and the creek, rising into Lookout Hill. Its mesh
	# and collision are made when the town loads (scripts/earth_land.gd).
	var land := StaticBody3D.new()
	land.name = "Land"
	land.set_script(load("res://scripts/earth_land.gd"))
	g.add_child(land)
	# (The countryside past the walls, rolling up into hills, is made by the land too: EarthLand._build_country().)
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
		var c := out * STREET
		roads.append([Vector2(c.x, c.z) - Vector2(along.x, along.z) * length / 2, Vector2(c.x, c.z) + Vector2(along.x, along.z) * length / 2,
			STREET_W, "street"])
	# A path across the green to the gazebo from each side
	for k in 4:
		var a := k * PI / 2 + PI / 4
		var d := Vector3(cos(a), 0, sin(a))
		mesh_at(box(Vector3(1.6, 0.05, GREEN_R - 4)), walk, d * (4 + (GREEN_R - 4) / 2) + Vector3(0, 0.05, 0), g, atan2(d.x, d.z))
	# Main Street, north from the green between the diner and the bookshop
	_street(g, Vector2(0, -24), Vector2(0, MAIN_Z.y), "Main Street", -36.0)
	# Hollow Lane, from the green's southwest corner down to Maple Lane
	_street(g, Vector2(HOLLOW_X, 24), Vector2(HOLLOW_X, MAPLE_Z - STREET_W / 2), "Hollow Lane", 38.0)
	# Maple Lane, east-west, in two parts either side of the covered bridge
	_street(g, Vector2(MAPLE_X.x, MAPLE_Z), Vector2(BRIDGE_X.x, MAPLE_Z), "Maple Lane")
	_street(g, Vector2(BRIDGE_X.y, MAPLE_Z), Vector2(MAPLE_X.y, MAPLE_Z), "Maple Lane")
	roads.append([Vector2(BRIDGE_X.x, MAPLE_Z), Vector2(BRIDGE_X.y, MAPLE_Z), STREET_W, "bridge"])
	# The edge: invisible walls round the town, past the last houses and trees
	var edge := group("Edge")
	var r := BOUNDS
	for wall in [[Vector3(r.get_center().x, 7, r.position.y), Vector3(r.size.x, 14, 1)], [Vector3(r.get_center().x, 7, r.end.y), Vector3(r.size.x, 14, 1)],
			[Vector3(r.position.x, 7, r.get_center().y), Vector3(1, 14, r.size.y)], [Vector3(r.end.x, 7, r.get_center().y), Vector3(1, 14, r.size.y)]]:
		solid_box(wall[1], wall[0], edge)                          # (tall enough for the hill and big air)
	_far_hills()


func _street(g: Node3D, a: Vector2, b: Vector2, street_name: String, walk_from := INF) -> void:
	# A straight street from a to b with a sidewalk each side (sidewalks start at walk_from along its length, if set,
	# so they don't run into the buildings at a corner), and a name sign at its start
	var road := mat("Street", Color(0.22, 0.22, 0.25), 0.9)
	var walk := mat("Sidewalk", Color(0.72, 0.68, 0.62), 0.9)
	var d := (b - a).normalized()
	var yaw := atan2(d.x, d.y)
	var mid := (a + b) / 2.0
	var length := a.distance_to(b)
	mesh_at(box(Vector3(STREET_W, 0.06, length)), road, Vector3(mid.x, 0.03, mid.y), g, yaw)
	var side_dir := Vector2(d.y, -d.x)
	var wa := a
	if walk_from != INF:
		wa = a + d * absf(walk_from - (a.y if absf(d.y) > 0.5 else a.x))
	var wl := wa.distance_to(b)
	var wm := (wa + b) / 2.0
	for side in [-1.0, 1.0]:
		var c: Vector2 = wm + side_dir * side * (STREET_W / 2 + 0.8)
		mesh_at(box(Vector3(1.6, 0.14, wl)), walk, Vector3(c.x, 0.07, c.y), g, yaw)
	roads.append([a, b, STREET_W, "street"])
	# The street sign: a green board on a post at the corner
	var at: Vector2 = wa + side_dir * (STREET_W / 2 + 1.9) + d * 1.0
	var post := Node3D.new()
	post.name = street_name + " Sign"
	post.position = Vector3(at.x, 0, at.y)
	post.rotation.y = yaw + PI / 2
	g.add_child(post)
	mesh_at(cyl(0.05, 0.05, 2.8, 6), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(0, 1.4, 0), post)
	mesh_at(box(Vector3(2.0, 0.35, 0.05)), mat("Street Sign", Color(0.15, 0.4, 0.25), 0.6), Vector3(0, 2.6, 0), post)
	label(post, street_name, Vector3(0, 2.6, 0.04), 28)
	label(post, street_name, Vector3(0, 2.6, -0.04), 28).rotation.y = PI


func _far_hills() -> void:
	# A ring of soft autumn hills on the horizon, so the town sits in a valley
	var g := group("Far Hills")
	var cols := [Color(0.72, 0.36, 0.14), Color(0.6, 0.25, 0.14), Color(0.75, 0.55, 0.2), Color(0.42, 0.4, 0.2)]
	var hill_rng := RandomNumberGenerator.new()                # its own, so the town's trees stay where they were
	hill_rng.seed = 31
	for k in 26:
		var a := k * TAU / 26 + hill_rng.randf_range(-0.08, 0.08)
		var dist := hill_rng.randf_range(330.0, 420.0)
		var r := hill_rng.randf_range(70.0, 120.0)
		var h := mesh_at(ball(1.0, 16), mat("Far Hill %d" % (k % 4), cols[k % 4], 0.95), Vector3(cos(a) * dist - 30, -r * 0.55, sin(a) * dist - 25), g)
		h.scale = Vector3(r, r * hill_rng.randf_range(0.75, 0.95), r)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clear(p: Vector2, r: float, roads_too := true) -> bool:
	# Whether nothing's been built within r of p: no building, street, water or skate yard
	if not BOUNDS.grow(-2.0).has_point(p):
		return false
	if EarthLand.height(p.x, p.y) < -0.1 or EarthLand.creek_distance(p.x, p.y) < EarthLand.CREEK_HALF + 2.0 + r:
		return false
	if EarthLand.pond_e(p.x, p.y) < 1.2:
		return false
	if YARD.grow(r + 1.0).has_point(p):
		return false
	if p.length() < GREEN_R + 1.0 + r:
		return false
	for f in feet:
		var local: Vector2 = (p - f.at).rotated(f.yaw)
		var half: Vector2 = f.size / 2.0 + Vector2(r, r)
		if absf(local.x) < half.x and absf(local.y) < half.y:
			return false
	if roads_too:
		for rd in roads:
			var a: Vector2 = rd[0]
			var b: Vector2 = rd[1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.distance_to(a + ab * t) < rd[2] / 2.0 + 2.4 + r:
				return false
	return true


func _foot(name: String, at: Vector3, yaw: float, size: Vector2, kind := "building", map_label := "") -> void:
	# Remember a building's footprint (width along its local x, depth along its local z), for the map and to keep
	# trees and props off it
	feet.append({"name": name, "at": Vector2(at.x, at.z), "size": size, "yaw": yaw, "kind": kind,
		"label": map_label if map_label != "" else name})


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
	_foot(name, at, yaw, Vector2(size.x, size.z), "building", sign_text)
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
	# West side: the town hall with its white steeple. Walk in: rows of benches, the podium, and the banner for the
	# town meeting.
	var hall := _walk_in("Earth Town Hall", Vector3(-back, 0, 0), PI / 2, Vector3(12, 6.0, 9), Color(0.96, 0.95, 0.92),
		Color(0.3, 0.3, 0.32), "Town Hall", Color(0, 0, 0, 0), Color(0.93, 0.9, 0.84), Color(0.55, 0.38, 0.25))
	mesh_at(box(Vector3(2.6, 4.0, 2.6)), mat("Steeple", Color(0.97, 0.96, 0.93)), Vector3(0, 8.5, 0), hall)
	mesh_at(cyl(0.0, 1.9, 4.0, 4), mat("Steeple Roof", Color(0.3, 0.3, 0.32)), Vector3(0, 12.5, 0), hall, PI / 4)
	_town_hall_inside(hall, Vector3(12, 6.0, 9))
	# South side: homes
	var home_cols := [Color(0.85, 0.75, 0.55), Color(0.6, 0.7, 0.85), Color(0.85, 0.6, 0.55)]
	for k in [0, 2]:
		_building("Home %d" % (k + 1), Vector3(-14 + k * 14, 0, back), PI, Vector3(8, 5.0, 7), home_cols[k], Color(0.3, 0.25, 0.25), "")
	_my_home(Vector3(0, 0, back + 1.0), home_cols[1])
	_foot("My Home", Vector3(0, 0, back + 1.0), PI, Vector2(HOME_SIZE.x, HOME_SIZE.z), "home", "Home")
	var toward := Vector3(-STUDIO_AT.x, 0, -STUDIO_AT.z).normalized()
	_foot("Dance Studio", STUDIO_AT, atan2(toward.x, toward.z), Vector2(STUDIO_SIZE.x + 1.0, STUDIO_SIZE.z + 1.0), "building")


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
		_look(2, 6, 5, 17, 6, 6, 1.32, 0.8, 0.9), [{"kind": "shawl", "color": Color(0.75, 0.3, 0.6)}], {}, false)


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


func _autumn_tree(parent: Node3D, at: Vector3, h: float, batch := false) -> void:
	# An autumn tree: a trunk and four balls of leaves. In a batch (the town's hundreds of trees), the trunk and
	# leaves go into shared MultiMeshes (_flush_trees()) and only the trunk's collision is its own node.
	var cols := [Color(0.95, 0.45, 0.15), Color(0.85, 0.25, 0.15), Color(0.95, 0.75, 0.2), Color(0.7, 0.35, 0.15)]
	var t := parent
	if batch:
		tree_parts.append(["Trunk", Transform3D(Basis().scaled(Vector3(0.32, h, 0.32)), at + Vector3(0, h / 2, 0)), Color(0.32, 0.22, 0.15)])
		solid_box(Vector3(0.6, 2.0, 0.6), at + Vector3(0, 1.0, 0), parent)
	else:
		t = Node3D.new()
		t.position = at
		parent.add_child(t)
		mesh_at(cyl(0.18, 0.32, h, 8), mat("Trunk", Color(0.32, 0.22, 0.15), 0.95), Vector3(0, h / 2, 0), t)
		solid_box(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0), t)
	for k in 4:
		var c: Color = cols[rng.randi() % cols.size()]
		var r := rng.randf_range(1.4, 2.2)
		var off := Vector3(rng.randf_range(-1, 1), h + rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1))
		if batch:
			tree_parts.append(["Leaves", Transform3D(Basis().scaled(Vector3.ONE * r), at + off), c])
		else:
			mesh_at(ball(r, 12), mat("Leaves %s" % c, c, 0.9), off, t)


func _flush_trees(parent: Node3D) -> void:
	# The batched trees' trunks, leaves and bare branches as three MultiMeshes, each coloured per instance
	var meshes := {"Trunk": cyl(0.56, 1.0, 1.0, 8), "Leaves": ball(1.0, 12), "Branch": cyl(0.4, 1.0, 1.0, 5)}
	for kind in meshes:
		var parts := tree_parts.filter(func(p: Array) -> bool: return p[0] == kind)
		if parts.is_empty():
			continue
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		parent.add_child(multi("Tree " + kind, meshes[kind], parts.map(func(p: Array) -> Transform3D: return p[1]),
			parts.map(func(p: Array) -> Color: return p[2]), m))


func _trees_and_leaves() -> void:
	var g := group("Autumn Trees")
	for k in 10:                                                  # round the green
		var a := k * TAU / 10 + 0.15
		_autumn_tree(g, Vector3(cos(a), 0, sin(a)) * (GREEN_R - 1.5), rng.randf_range(4.0, 5.5), true)
	# All round the town, wherever there's room: thick woods out by the walls, scattered trees in the park, along
	# the streets and up the hill. A few bare, twisty ones by the pond and the falls, for that spooky autumn look.
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 230 and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(BOUNDS.position.x + 3, BOUNDS.end.x - 3), rng.randf_range(BOUNDS.position.y + 3, BOUNDS.end.y - 3))
		var near_edge := minf(minf(p.x - BOUNDS.position.x, BOUNDS.end.x - p.x), minf(p.y - BOUNDS.position.y, BOUNDS.end.y - p.y))
		# Fewer trees in the middle of town, more towards the edges
		if near_edge > 14.0 and rng.randf() < 0.55:
			continue
		if p.length() < 40.0 and absf(p.x) < 40.0:
			continue                                              # the old town round the green keeps its look
		if not _clear(p, 2.2):
			continue
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 5.0):
			continue
		if EarthLand.hill(p.x, p.y) > 0.0 and EarthLand.hill(p.x, p.y) < EarthLand.HILL_TOP and \
				absf(p.y - (EarthLand.HILL.y + 4.0)) < 9.0 and p.x > EarthLand.HILL.x:
			continue                                              # the hill rail and kicker run need a clear run down
		placed.append(p)
		var spooky := (EarthLand.pond_e(p.x, p.y) < 1.8 or EarthLand.creek_distance(p.x, p.y) < 9.0) and placed.size() % 3 == 0
		if spooky:
			_bare_tree(g, _on_ground(p), rng.randf_range(4.5, 6.5))
		else:
			_autumn_tree(g, _on_ground(p), rng.randf_range(4.5, 7.0), true)
	_flush_trees(g)
	# Fallen leaves everywhere (one MultiMesh, so it's cheap)
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.22, 0.16)
	var leaves := []
	while leaves.size() < 6000:
		var p := Vector2(rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		if EarthLand.height(p.x, p.y) < -0.05 or YARD.has_point(p) or Vector2(p.x - STUDIO_AT.x, p.y - STUDIO_AT.z).length() < 12.0:
			continue                                              # not in the water, on the yard or the studio's floor
		var inside := false
		for f in feet:
			if f.kind == "inside" or f.kind == "home":
				var local: Vector2 = (p - f.at).rotated(f.yaw)
				if absf(local.x) < f.size.x / 2.0 and absf(local.y) < f.size.y / 2.0:
					inside = true
					break
		if inside:
			continue
		leaves.append(p)
	var xf := []
	var cols := []
	for i in leaves.size():
		var p: Vector2 = leaves[i]
		var basis := Basis(Vector3.RIGHT, -PI / 2).rotated(Vector3.UP, rng.randf() * TAU)
		xf.append(Transform3D(basis, _on_ground(p, 0.06)))
		cols.append([Color(0.95, 0.45, 0.15), Color(0.85, 0.25, 0.15), Color(0.95, 0.75, 0.2)][i % 3])
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.add_child(multi("Fallen Leaves", leaf, xf, cols, lm))


func _bare_tree(parent: Node3D, at: Vector3, h: float) -> void:
	# A bare, twisty dark tree with crooked branches (spooky, but not scary). Batched like the autumn trees.
	var bark := Color(0.18, 0.13, 0.12)
	_branch(at, at + Vector3(0.3, h, 0.25), 0.3, bark)
	solid_box(Vector3(0.6, 2.0, 0.6), at + Vector3(0, 1.0, 0), parent)
	for k in 5:
		var a := k * TAU / 5 + rng.randf_range(-0.3, 0.3)
		var y := h * rng.randf_range(0.55, 0.95)
		var len := rng.randf_range(1.2, 2.2)
		var d := Vector3(cos(a), rng.randf_range(0.4, 0.9), sin(a)).normalized()
		var root_at := at + Vector3(0.3 * y / h, y, 0.25 * y / h)
		_branch(root_at, root_at + d * len, 0.08, bark)
		var d2 := (d + Vector3(rng.randf_range(-0.6, 0.6), 0.3, rng.randf_range(-0.6, 0.6))).normalized()
		_branch(root_at + d * len, root_at + d * len + d2 * len * 0.6, 0.035, bark)


func _branch(a: Vector3, b: Vector3, r: float, c: Color) -> void:
	# One tapering piece of a bare tree, from a (thick end) to b, for the batched "Branch" MultiMesh
	var up := b - a
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	# The base mesh tapers the wrong way round (wide at the bottom), which is what a branch wants
	tree_parts.append(["Branch", Transform3D(Basis(x * r, y * up.length(), z * r), (a + b) / 2.0), c])


func _lamps() -> void:
	var g := group("Street Lamps")
	for k in 4:
		var a := k * PI / 2
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))
		for t in [-14.0, 0.0, 14.0]:
			_lamp_post(g, out * (STREET - STREET_W / 2 - 0.9) + along * t)
	# Down Main Street, both sides (the string lights hang between them), and along Maple Lane and Hollow Lane
	var z := MAIN_Z.x - 4.0
	var side := 1.0
	while z > MAIN_Z.y + 2.0:
		_lamp_post(g, Vector3(-side * (STREET_W / 2 + 0.9), 0, z))
		_lamp_post(g, Vector3(side * (STREET_W / 2 + 0.9), 0, z - 8.0))
		z -= 16.0
	var x := MAPLE_X.y - 6.0
	while x > MAPLE_X.x + 4.0:
		if x < BRIDGE_X.x - 3.0 or x > BRIDGE_X.y + 3.0:
			_lamp_post(g, Vector3(x, 0, MAPLE_Z + (STREET_W / 2 + 0.9) * (1.0 if int(x) % 2 == 0 else -1.0)))
		x -= 18.0
	for zz in [34.0, 46.0]:
		_lamp_post(g, Vector3(HOLLOW_X + STREET_W / 2 + 0.9, 0, zz))
	for p in [Vector2(-42, 11.5), Vector2(-60, 13.5), Vector2(-48, -19.5), Vector2(-72, -31), Vector2(-104, -41)]:
		_lamp_post(g, _on_ground(p))


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


func _person(name: String, id: String, at: Vector3, yaw: float, look: Dictionary, extras := [], outfit := {}, has_routine := true,
		model := "") -> Node3D:
	# Someone who lives here (scripts/townsfolk.gd): the Earth kid body dressed and shaped like a hero in the creator,
	# with a talk spot, and a daily routine on Earth's clock (res://routines/<id>.json) if they have one
	var p := Node3D.new()
	p.name = name.replace(".", "")                     # (a node's name can't have a dot: "Mr Palmer")
	p.set_script(load("res://scripts/townsfolk.gd"))
	p.set("look", look)
	p.set("extras", extras)
	p.set("outfit", outfit)
	if model != "":
		p.set("model_path", model)
	p.position = at
	p.rotation.y = yaw
	people_group().add_child(p)
	if has_routine:
		var r := Node.new()
		r.name = "Routine"
		r.set_script(load("res://scripts/routine.gd"))
		r.set("character_id", id)
		p.add_child(r)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", id)
	talk.set("display_name", name)
	talk.set("name_height", (2.15 if model != "" else 1.39 * float(look.get("height", 1.0))) + 0.35)
	p.add_child(talk)
	return p


func people_group() -> Node3D:
	var g := world.get_node_or_null("Characters") as Node3D
	return g if g else group("Characters")


# Looks, hero style (scripts/hero.gd): colours are Hero.SWATCHES numbers (1 pale skin, 2 light, 3 tan, 4 brown, 5 dark
# brown, 6 black, 7 white, 8 grey, 9 red, 10 orange, 11 yellow, 12 green, 13 teal, 14 sky, 15 blue, 16 purple, 17 lilac,
# 18 pink, 19 taupe, 20 mint); hairstyles are Hairstyles.NAMES (1 short crop, 2 pigtails, 3 ponytail, 4 space buns,
# 5 long, 6 bob, 7 mohawk, 8 afro puffs, 9 braids, 10 curly top, 11 bald). Grown-ups are taller with smaller heads.
func _look(skin: int, hair: int, style: int, top: int, bottoms: int, shoes: int, height: float, head := 1.0, build := 1.0,
		more := {}) -> Dictionary:
	var l := {"colors": {"fur": skin, "hair": hair, "brows": hair if hair != 7 else 8, "top": top, "bottoms": bottoms,
		"shoes": shoes}, "hairstyle": style, "extras": false, "height": height, "head": head, "build": build}
	l.merge(more, true)
	return l


func _people() -> void:
	# Everyone in town, where they'd be in the afternoon (their routines move them about: res://routines/<id>.json).
	# Mr. Palmer has his own human model; everyone else is made like a hero in the creator.
	var adult := 1.32
	var kid := 0.96
	_person("Mr. Palmer", "palmer_earth", Vector3(1.5, 0, 9.0), PI * 0.1, {}, [], {}, true, "res://models/characters/mr_palmer.glb")
	_person("Miss Ivy", "ivy", Vector3(-6.0, 0, -25.4), 0.0, _look(2, 10, 3, 18, 6, 9, 1.28, 0.84, 1.0),
		[{"kind": "apron", "color": Color(0.97, 0.96, 0.92)}])
	_person("Theo", "theo", Vector3(12.0, 0, -25.2), -0.3, _look(4, 6, 10, 12, 15, 7, kid, 1.0, 1.0, {"extras": true}),
		[{"kind": "glasses", "color": Color(0.12, 0.1, 0.1)}, {"kind": "book", "color": Color(0.25, 0.4, 0.8)}])
	_person("Gus", "gus", Vector3(-11.0, 0, -25.4), 0.0, _look(2, 5, 1, 15, 5, 6, 1.36, 0.8, 1.15, {"mouth": 0.85}),
		[{"kind": "cap", "color": Color(0.2, 0.25, 0.4)}, {"kind": "apron", "color": Color(0.85, 0.85, 0.82)}])
	_person("Dottie Pennywhistle", "dottie", Vector3(25.5, 0, 9.0), -PI / 2, _look(1, 11, 10, 18, 17, 18, 1.26, 0.86, 1.15,
		{"eyes": 1.1}), [{"kind": "pearls"}, {"kind": "cardigan", "color": Color(1.0, 0.82, 0.35)}])
	_person("Barnaby Quill", "barnaby", Vector3(-2.5, 0, 8.5), 0.0, _look(3, 4, 5, 13, 4, 5, adult, 0.82, 0.95),
		[{"kind": "guitar", "color": Color(0.45, 0.28, 0.18)}, {"kind": "scarf", "color": Color(0.95, 0.55, 0.15)}])
	_person("Miss Marigold", "marigold", Vector3(-17.0, 1.2, -84.0), PI / 2, _look(4, 6, 9, 7, 16, 6, 1.3, 0.84, 0.95),
		[{"kind": "glasses", "color": Color(0.35, 0.22, 0.12)}, {"kind": "cardigan", "color": Color(0.45, 0.6, 0.4)},
		{"kind": "book", "color": Color(0.75, 0.2, 0.25)}])
	_person("Poppy Crumb", "poppy", Vector3(-9.5, 0, -46.0), PI / 2, _look(2, 10, 3, 7, 19, 16, 1.26, 0.86, 1.2),
		[{"kind": "chef_hat"}, {"kind": "apron", "color": Color(0.55, 0.25, 0.55)}])
	_person("Mr. Gumdrop", "otis", Vector3(-9.5, 0, -62.0), PI / 2, _look(1, 8, 10, 14, 10, 15, 1.24, 0.88, 1.1),
		[{"kind": "glasses", "color": Color(0.85, 0.65, 0.25)}, {"kind": "bow_tie", "color": Color(0.85, 0.15, 0.2)},
		{"kind": "moustache", "color": Color(0.82, 0.82, 0.86)}])
	_person("Mrs. Wren", "wren", Vector3(4.8, 0, -46.0), -PI / 2, _look(2, 6, 6, 16, 6, 6, 1.25, 0.82, 0.9, {"mouth": 0.8}),
		[{"kind": "glasses", "color": Color(0.75, 0.12, 0.15)}, {"kind": "cardigan", "color": Color(0.35, 0.2, 0.4)}])
	_person("Hank", "hank", Vector3(4.8, 0, -62.5), -PI / 2, _look(5, 6, 11, 10, 15, 4, 1.4, 0.78, 1.25),
		[{"kind": "moustache", "color": Color(0.12, 0.1, 0.1)}, {"kind": "apron", "color": Color(0.3, 0.45, 0.3)}])
	_person("Kip", "kip", Vector3(25.5, 0, -8.0), -PI / 2, _look(1, 11, 1, 7, 6, 6, adult, 0.82, 0.85, {"eyes": 1.15}),
		[{"kind": "bow_tie", "color": Color(0.1, 0.1, 0.12)}, {"kind": "clipboard"}])
	_person("Mr. Page", "lionel", Vector3(9.0, 0, -25.4), 0.0, _look(5, 7, 1, 7, 19, 5, 1.34, 0.8, 1.0),
		[{"kind": "glasses", "color": Color(0.1, 0.1, 0.1)}, {"kind": "cardigan", "color": Color(0.5, 0.2, 0.25)},
		{"kind": "book", "color": Color(0.3, 0.55, 0.35)}])
	_person("Juniper", "juniper", Vector3(5.0, 0, -120.0), 0.0, _look(5, 6, 8, 11, 15, 18, kid, 1.0, 1.0, {"extras": true}),
		[{"kind": "headband", "color": Color(1.0, 0.45, 0.65)}, {"kind": "clipboard"}])
	_person("Ozzie", "ozzie", Vector3(14.0, 0.2, -92.0), 0.0, _look(1, 10, 1, 9, 15, 6, 1.0),
		[{"kind": "cap", "color": Color(0.85, 0.2, 0.2)}, {"kind": "skateboard", "color": Color(0.3, 0.75, 0.4)}])
	# The Blastoffs: Nina, human on Earth (red bob, red bow, black turtleneck), and her sister and brother. Prue's look
	# is a PLACEHOLDER until there's a drawing of her as a person. Bruno is Sofi's drawing of him as a person: a mop
	# of golden hair under his black SK8 beanie, an open blue zip hoodie over an olive tee, dark jeans, his board.
	_person("Nina", "nina_earth", Vector3(-40.0, 0, 62.0), PI, _look(1, 9, 6, 6, 6, 9, 1.0, 1.0, 0.95),
		[{"kind": "bow", "color": Color(0.85, 0.1, 0.14)}, {"kind": "turtleneck", "color": Color(0.1, 0.08, 0.1)}])
	_person("Prue", "prue", Vector3(-38.0, 0, 62.0), PI, _look(1, 4, 2, 17, 18, 18, 0.84, 1.06),
		[{"kind": "flower", "color": Color(1.0, 0.6, 0.8)}]).set("placeholder", true)
	_person("Bruno", "bruno", Vector3(-42.0, 0, 62.0), PI, _look(2, 11, 1, 15, 6, 6, 0.92, 1.05, 1.0, {"eyes": 1.08}),
		[{"kind": "open_hoodie", "color": Color(0.35, 0.5, 1.0), "tee": Color(0.45, 0.5, 0.15)},
		{"kind": "bruno_beanie", "color": Color(0.1, 0.1, 0.11)},
		{"kind": "freckles", "color": Color(0.7, 0.45, 0.32)},
		{"kind": "skateboard", "color": Color(0.12, 0.12, 0.14)}])

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


# -----------------------------------------------------------------------------
# Walk-in buildings and what's inside them
# -----------------------------------------------------------------------------
func _walk_in(name: String, at: Vector3, yaw: float, size: Vector3, wall: Color, roof_c: Color, sign_text: String,
		awning := Color(0, 0, 0, 0), inside_c := Color(0.95, 0.9, 0.8), floor_c := Color(0.62, 0.44, 0.3)) -> Node3D:
	# A building you can walk into, its front (+Z) facing the street: hollow like the player's house, with a doorway,
	# a wooden floor, warm lights inside and the "interior" music. Markers: "Doorway" just outside the door and
	# "Inside" in the middle of the room (tools/test_earth.gd walks between them).
	var g := group(name, at, yaw)
	_foot(name, at, yaw, Vector2(size.x, size.z), "inside", sign_text)
	var hd := size.z / 2.0
	var h := size.y
	var wall_m := mat("Wall " + name, wall, 0.85)
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	g.add_child(shell)
	var outer := CSGBox3D.new()
	outer.size = size
	outer.position = Vector3(0, h / 2.0, 0)
	outer.material = wall_m
	shell.add_child(outer)
	var hollow := CSGBox3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = size - Vector3(0.6, 0.2, 0.6)
	hollow.position = Vector3(0, h / 2.0 - 0.2, 0)
	hollow.material = mat("Inside " + name, inside_c, 0.9)
	shell.add_child(hollow)
	var doorway := CSGBox3D.new()
	doorway.operation = CSGShape3D.OPERATION_SUBTRACTION
	doorway.size = Vector3(2.0, 2.8, 1.2)
	doorway.position = Vector3(0, 1.4, hd)
	doorway.material = wall_m
	shell.add_child(doorway)
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 0.6, 2.2, size.z + 0.6)
	mesh_at(roof, mat("Roof " + name, roof_c, 0.8), Vector3(0, h + 1.1, 0), g)
	mesh_at(box(Vector3(size.x - 0.7, 0.04, size.z - 0.7)), mat("Floor " + name, floor_c, 0.7), Vector3(0, 0.02, 0), g)
	var trim := mat("Home Trim", Color(0.96, 0.94, 0.9), 0.7)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.2, 2.9, 0.2)), trim, Vector3(sx * 1.1, 1.45, hd + 0.05), g)
	mesh_at(box(Vector3(2.4, 0.2, 0.2)), trim, Vector3(0, 2.9, hd + 0.05), g)
	var glass := mat("Warm Window", Color(1.0, 0.85, 0.55), 0.3, 1.6)
	for wx in [-size.x * 0.3, size.x * 0.3]:
		mesh_at(box(Vector3(1.6, 1.3, 0.1)), glass, Vector3(wx, 1.7, hd + 0.05), g)
		mesh_at(box(Vector3(1.6, 1.3, 0.1)), glass, Vector3(wx, 1.7, hd - 0.33), g)
		if h > 5.0:
			mesh_at(box(Vector3(1.2, 1.0, 0.1)), glass, Vector3(wx, h - 1.3, hd + 0.05), g)
	if awning.a > 0.0:
		for s in 6:
			var c := awning if s % 2 == 0 else Color(0.95, 0.95, 0.9)
			mesh_at(box(Vector3(size.x / 6, 0.06, 1.4)), mat("Awning %s %d" % [name, s % 2], c, 0.7),
				Vector3(-size.x / 2 + size.x / 12 + s * size.x / 6, 3.1, hd + 0.7), g, 0.0, Vector3(0.3, 0, 0))
	if sign_text != "":
		mesh_at(box(Vector3(maxf(3.0, sign_text.length() * 0.3), 0.7, 0.12)), mat("Sign Board", Color(0.18, 0.25, 0.2)),
			Vector3(0, 3.65, hd + 0.12), g)
		label(g, sign_text, Vector3(0, 3.65, hd + 0.2), 44)
	lamp_light(g, Vector3(0, 2.6, hd + 1.2), Color(1.0, 0.8, 0.55), 1.0, 6.0)
	for k in int(ceil(size.x / 10.0)):                           # warm lights inside, always on
		var inside := OmniLight3D.new()
		inside.light_color = Color(1.0, 0.85, 0.65)
		inside.light_energy = 1.2
		inside.omni_range = maxf(size.z, 9.0)
		inside.position = Vector3(-size.x / 2 + size.x * (k + 0.5) / ceil(size.x / 10.0), h - 0.8, 0)
		g.add_child(inside)
	var zone := Area3D.new()
	zone.name = "Music"
	zone.set_script(load("res://scripts/music_zone.gd"))
	zone.set("track", "interior")
	var zs := CollisionShape3D.new()
	var zb := BoxShape3D.new()
	zb.size = Vector3(size.x - 0.6, 4.0, size.z - 0.6)
	zs.shape = zb
	zs.position = Vector3(0, 2.0, 0)
	zone.add_child(zs)
	g.add_child(zone)
	var m_in := Marker3D.new()
	m_in.name = "Inside"
	m_in.position = Vector3(0, 1.0, 0.5)
	g.add_child(m_in)
	var m_door := Marker3D.new()
	m_door.name = "Doorway"
	m_door.position = Vector3(0, 1.0, hd + 2.2)
	g.add_child(m_door)
	_jack(g, Vector3(size.x * 0.32, 0, hd + 0.7), 0.3)
	return g


func _solid_mesh(size: Vector3, m: Material, pos: Vector3, parent: Node3D, yaw := 0.0) -> MeshInstance3D:
	# A box you can see and bump into
	solid_box(size, pos, parent, yaw)
	return mesh_at(box(size), m, pos, parent, yaw)


func _table(parent: Node3D, at: Vector3, top := Color(0.6, 0.4, 0.25), round_top := true) -> void:
	var wood := mat("Table %s" % top, top, 0.7)
	if round_top:
		mesh_at(cyl(0.6, 0.6, 0.06, 16), wood, at + Vector3(0, 0.78, 0), parent)
	else:
		mesh_at(box(Vector3(1.6, 0.06, 0.9)), wood, at + Vector3(0, 0.78, 0), parent)
	mesh_at(cyl(0.06, 0.08, 0.75, 8), wood, at + Vector3(0, 0.38, 0), parent)
	solid_box(Vector3(0.8, 0.8, 0.8), at + Vector3(0, 0.4, 0), parent)


func _chair(parent: Node3D, at: Vector3, yaw: float, c := Color(0.5, 0.32, 0.2)) -> void:
	var m := mat("Chair %s" % c, c, 0.7)
	var ch := Node3D.new()
	ch.position = at
	ch.rotation.y = yaw
	parent.add_child(ch)
	mesh_at(box(Vector3(0.45, 0.06, 0.45)), m, Vector3(0, 0.45, 0), ch)
	mesh_at(box(Vector3(0.45, 0.5, 0.06)), m, Vector3(0, 0.72, -0.2), ch)
	for sx in [-0.18, 0.18]:
		for sz in [-0.18, 0.18]:
			mesh_at(box(Vector3(0.05, 0.45, 0.05)), m, Vector3(sx, 0.22, sz), ch)


func _shelf(parent: Node3D, at: Vector3, yaw: float, width: float, height: float, book_cols: Array, depth := 0.5) -> void:
	# A tall shelf, its shelves filled with a row of colourful things (books, boxes, jars)
	var s := Node3D.new()
	s.position = at
	s.rotation.y = yaw
	parent.add_child(s)
	var wood := mat("Shelf Wood", Color(0.45, 0.3, 0.2), 0.8)
	mesh_at(box(Vector3(width, height, 0.06)), wood, Vector3(0, height / 2, -depth / 2), s)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.06, height, depth)), wood, Vector3(sx * width / 2, height / 2, 0), s)
	solid_box(Vector3(width, height, depth), Vector3(0, height / 2, 0), s)
	# The books (or boxes) as one MultiMesh per shelf: a library's worth would be thousands of nodes otherwise
	var books := []
	var rows := int(height / 0.45)
	for r in rows:
		var y := 0.1 + r * 0.45
		mesh_at(box(Vector3(width, 0.04, depth)), wood, Vector3(0, y, 0), s)
		var x := -width / 2 + 0.1
		var k := r * 3
		while x < width / 2 - 0.15:
			var w := rng.randf_range(0.06, 0.14)
			var bh := rng.randf_range(0.24, 0.36)
			books.append([Transform3D(Basis().scaled(Vector3(w, bh, depth * 0.8)), Vector3(x + w / 2, y + 0.02 + bh / 2, 0.02)),
				book_cols[k % book_cols.size()]])
			x += w + 0.01
			k += 1
	if not mats.has("Books"):
		var bm := StandardMaterial3D.new()
		bm.vertex_color_use_as_albedo = true
		bm.roughness = 0.8
		mats["Books"] = bm
	s.add_child(multi("Books", box(Vector3.ONE), books.map(func(b: Array) -> Transform3D: return b[0]),
		books.map(func(b: Array) -> Color: return b[1]), mats["Books"]))


func _town_hall_inside(g: Node3D, size: Vector3) -> void:
	# Town meetings: rows of benches facing the podium at the back, a banner, flags and a big clock
	var hd := size.z / 2.0
	var wood := mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7)
	for row in 4:
		for sx in [-1.0, 1.0]:
			var p: Vector3 = Vector3(sx * 2.6, 0, hd - 2.4 - row * 1.4)
			_solid_mesh(Vector3(3.4, 0.45, 0.45), wood, p + Vector3(0, 0.25, 0), g)
			mesh_at(box(Vector3(3.4, 0.5, 0.08)), wood, p + Vector3(0, 0.7, 0.24), g)
	_solid_mesh(Vector3(1.0, 1.15, 0.6), mat("Podium", Color(0.38, 0.22, 0.14), 0.6), Vector3(0, 0.58, -hd + 1.4), g)
	mesh_at(box(Vector3(5.0, 0.1, 1.6)), mat("Stage Rug", Color(0.6, 0.15, 0.2), 0.9), Vector3(0, 0.06, -hd + 1.4), g)
	mesh_at(box(Vector3(5.5, 1.0, 0.05)), mat("Banner", Color(0.95, 0.55, 0.15), 0.8), Vector3(0, 3.8, -hd + 0.35), g)
	label(g, "TOWN MEETING TONIGHT, 7 PM", Vector3(0, 3.8, -hd + 0.4), 36, Color(0.25, 0.1, 0.05)).outline_size = 0
	var clock := mesh_at(cyl(0.55, 0.55, 0.08, 24), mat("Clock Face", Color(0.97, 0.95, 0.88), 0.5), Vector3(0, 5.0, -hd + 0.35), g,
		0.0, Vector3(PI / 2, 0, 0))
	clock.name = "Hall Clock"
	for sx in [-1.0, 1.0]:
		mesh_at(cyl(0.03, 0.03, 2.4, 6), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(sx * 3.4, 1.2, -hd + 0.8), g)
		mesh_at(box(Vector3(0.9, 0.6, 0.02)), mat("Town Flag", Color(0.2, 0.35, 0.6), 0.8), Vector3(sx * 3.4 + 0.45, 2.1, -hd + 0.8), g)
		_jack(g, Vector3(sx * 1.6, 0.0, -hd + 1.0), 0.28)


func _bakery_inside(g: Node3D, size: Vector3) -> void:
	# Pies cooling, a glass case of cupcakes and pumpkin bread, the big oven, and little tables by the window
	var hd := size.z / 2.0
	var counter := mat("Counter", Color(0.95, 0.88, 0.75), 0.6)
	_solid_mesh(Vector3(6.0, 1.0, 0.9), counter, Vector3(0, 0.5, -hd + 2.6), g)
	mesh_at(box(Vector3(5.6, 0.5, 0.7)), mat("Glass Case", Color(0.8, 0.92, 1.0), 0.05, 0.0, 0.35), Vector3(0, 1.27, -hd + 2.6), g)
	var treats := [Color(0.95, 0.55, 0.2), Color(0.98, 0.8, 0.85), Color(0.55, 0.32, 0.2), Color(0.9, 0.85, 0.6), Color(0.6, 0.35, 0.75)]
	for k in 9:
		var c: Color = treats[k % treats.size()]
		mesh_at(cyl(0.09, 0.07, 0.12, 10), mat("Cupcake %d" % (k % 5), c, 0.7), Vector3(-2.4 + k * 0.6, 1.11, -hd + 2.6), g)
		mesh_at(ball(0.09, 8), mat("Frosting %d" % (k % 3), [Color(1, 0.97, 0.95), Color(0.95, 0.5, 0.15), Color(0.5, 0.25, 0.6)][k % 3], 0.6),
			Vector3(-2.4 + k * 0.6, 1.2, -hd + 2.6), g)
	var oven := mat("Oven Brick", Color(0.6, 0.3, 0.22), 0.9)
	_solid_mesh(Vector3(2.4, 2.4, 1.2), oven, Vector3(-size.x / 2 + 1.8, 1.2, -hd + 0.9), g)
	mesh_at(box(Vector3(1.0, 0.7, 0.05)), mat("Oven Glow", Color(1.0, 0.5, 0.15), 0.5, 2.5), Vector3(-size.x / 2 + 1.8, 1.0, -hd + 1.52), g)
	for k in 4:                                                  # pies cooling on the back shelf
		_solid_mesh(Vector3(0.1, 0.1, 0.1), counter, Vector3(1.5 + k * 0.8, 1.55, -hd + 0.6), g)
		mesh_at(cyl(0.3, 0.26, 0.1, 16), mat("Pie Crust", Color(0.85, 0.6, 0.3), 0.8), Vector3(1.5 + k * 0.8, 1.6, -hd + 0.6), g)
		mesh_at(cyl(0.24, 0.24, 0.02, 16), mat("Pumpkin Filling", Color(0.85, 0.42, 0.12), 0.7), Vector3(1.5 + k * 0.8, 1.65, -hd + 0.6), g)
	mesh_at(box(Vector3(4.0, 0.06, 0.5)), mat("Shelf Wood", Color(0.45, 0.3, 0.2), 0.8), Vector3(2.7, 1.52, -hd + 0.6), g)
	for p in [Vector3(-2.6, 0, hd - 2.0), Vector3(2.6, 0, hd - 2.0)]:
		_table(g, p, Color(0.95, 0.9, 0.8))
		_chair(g, p + Vector3(-0.9, 0, 0), PI / 2, Color(0.55, 0.3, 0.6))
		_chair(g, p + Vector3(0.9, 0, 0), -PI / 2, Color(0.95, 0.55, 0.2))


func _toy_shop_inside(g: Node3D, size: Vector3) -> void:
	# Shelves of toys, a table of board games, a train going round the middle and a big teddy in the corner
	var hd := size.z / 2.0
	var toys := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.98, 0.85, 0.25), Color(0.45, 0.8, 0.4), Color(0.75, 0.45, 0.9),
		Color(0.98, 0.55, 0.2)]
	for sx in [-1.0, 1.0]:
		_shelf(g, Vector3(sx * (size.x / 2 - 0.6), 0, -0.5), sx * -PI / 2, 5.0, 2.2, toys, 0.6)
	_table(g, Vector3(0, 0, -hd + 2.0), Color(0.35, 0.55, 0.4), false)
	for k in 5:
		mesh_at(box(Vector3(0.35, 0.06 + k * 0.0, 0.35)), mat("Game Box %d" % k, toys[k], 0.6), Vector3(-0.5 + (k % 3) * 0.5, 0.84 + (k / 3) * 0.07, -hd + 2.0), g)
	# A little train on a round track
	var track := TorusMesh.new()
	track.inner_radius = 1.5
	track.outer_radius = 1.6
	mesh_at(track, mat("Track", Color(0.3, 0.3, 0.32), 0.5), Vector3(0, 0.05, 0.9), g)
	var train := Node3D.new()
	train.name = "Toy Train"
	train.position = Vector3(0, 0.0, 0.9)
	train.set_script(load("res://scripts/spin.gd"))
	g.add_child(train)
	for k in 3:
		var a := -k * 0.45
		mesh_at(box(Vector3(0.3, 0.25, 0.45)), mat("Train %d" % k, toys[k], 0.5), Vector3(cos(a) * 1.55, 0.18, sin(a) * 1.55), train, -a)
	# The big teddy and some blocks
	var bear := mat("Teddy", Color(0.65, 0.42, 0.22), 0.9)
	var tp := Vector3(size.x / 2 - 1.3, 0, hd - 1.3)
	mesh_at(ball(0.55, 12), bear, tp + Vector3(0, 0.55, 0), g)
	mesh_at(ball(0.38, 12), bear, tp + Vector3(0, 1.35, 0), g)
	for sx in [-0.28, 0.28]:
		mesh_at(ball(0.13, 8), bear, tp + Vector3(sx, 1.68, 0), g)
	solid_box(Vector3(1.1, 1.0, 1.1), tp + Vector3(0, 0.5, 0), g)
	for k in 6:
		mesh_at(box(Vector3(0.3, 0.3, 0.3)), mat("Block %d" % k, toys[k], 0.6), Vector3(-size.x / 2 + 1.2 + (k % 3) * 0.32, 0.15 + (k / 3) * 0.3, hd - 1.2), g)


func _library_inside(g: Node3D, size: Vector3) -> void:
	# Rows of bookshelves, reading tables with green lamps, a story corner on a round rug with beanbags
	var hd := size.z / 2.0
	var books := [Color(0.6, 0.15, 0.15), Color(0.15, 0.3, 0.5), Color(0.2, 0.42, 0.25), Color(0.75, 0.6, 0.25), Color(0.45, 0.2, 0.45),
		Color(0.85, 0.45, 0.15)]
	for k in 3:
		for sx in [-1.0, 1.0]:
			_shelf(g, Vector3(sx * (size.x / 2 - 2.6), 0, -hd + 1.5 + k * 2.4), 0.0, 3.6, 2.4, books, 0.5)
	for sx in [-1.0, 1.0]:
		_shelf(g, Vector3(sx * (size.x / 2 - 0.5), 0, 0.5), sx * -PI / 2, 6.0, 3.0, books, 0.5)
	for k in 2:
		var p := Vector3(0, 0, -hd + 2.5 + k * 3.0)
		_table(g, p, Color(0.45, 0.3, 0.18), false)
		mesh_at(cyl(0.12, 0.12, 0.12, 12), mat("Green Lamp", Color(0.2, 0.6, 0.35), 0.4, 1.2), p + Vector3(0, 0.95, 0), g)
		for sx in [-1.0, 1.0]:
			_chair(g, p + Vector3(sx * 0.6, 0, 0.7), PI)
	var rp := Vector3(-size.x / 2 + 3.0, 0, hd - 2.6)
	mesh_at(cyl(2.0, 2.0, 0.04, 32), mat("Story Rug", Color(0.85, 0.5, 0.2), 0.9), rp + Vector3(0, 0.04, 0), g)
	for k in 3:
		var a := k * TAU / 3
		var bb := mesh_at(ball(0.45, 12), mat("Beanbag %d" % k, books[k + 3], 0.9), rp + Vector3(cos(a), 0.3, sin(a)) * Vector3(1.3, 1, 1.3), g)
		bb.scale = Vector3(1, 0.6, 1)
	mesh_at(box(Vector3(1.6, 0.06, 0.6)), mat("Counter", Color(0.95, 0.88, 0.75), 0.6), Vector3(size.x / 2 - 2.5, 1.0, hd - 2.0), g)
	_solid_mesh(Vector3(1.6, 1.0, 0.6), mat("Desk Wood", Color(0.4, 0.26, 0.16), 0.7), Vector3(size.x / 2 - 2.5, 0.5, hd - 2.0), g)
	mesh_at(box(Vector3(2.6, 0.5, 0.05)), mat("Sign Board", Color(0.18, 0.25, 0.2)), Vector3(size.x / 2 - 2.5, 2.4, hd - 2.0), g)
	label(g, "Quiet, please!", Vector3(size.x / 2 - 2.5, 2.4, hd - 1.97), 26)


# -----------------------------------------------------------------------------
# Main Street
# -----------------------------------------------------------------------------
func _side(x_sign: float, depth: float) -> float:
	# The x of a building's middle on Main Street's west (-1) or east (+1) side, behind the sidewalk
	return x_sign * (STREET_W / 2 + 1.6 + 1.0 + depth / 2.0)


func _main_street() -> void:
	# West side, facing east: the bakery, the toy shop, the library up its steps, the fire station
	var bakery_size := Vector3(11, 5.0, 10)
	var bakery := _walk_in("Bakery", Vector3(_side(-1, 10), 0, -46), PI / 2, bakery_size, Color(0.95, 0.78, 0.55),
		Color(0.45, 0.22, 0.25), "Crumb & Cauldron Bakery", Color(0.55, 0.25, 0.55))
	_bakery_inside(bakery, bakery_size)
	_witch_hat(bakery, Vector3(0, 4.6, 5.25), 0.5)                   # a little witch's hat on the sign
	var toys_size := Vector3(10, 5.0, 10)
	var toys := _walk_in("Toy Shop", Vector3(_side(-1, 10), 0, -62), PI / 2, toys_size, Color(0.55, 0.75, 0.9),
		Color(0.85, 0.35, 0.3), "Gizmo & Gumdrop Toys", Color(0.95, 0.75, 0.2))
	_toy_shop_inside(toys, toys_size)
	_library(Vector3(_side(-1, 13) - 5.5, 0, -84))                  # set back, for its steps
	_fire_station(Vector3(_side(-1, 12) - 4.0, 0, -104))            # set back, for the truck
	# East side, facing west: antiques and the hardware store (the skate yard and the school are further up)
	var antiques := _building("Antiques", Vector3(_side(1, 9), 0, -46), -PI / 2, Vector3(10, 5.5, 9), Color(0.48, 0.35, 0.55),
		Color(0.2, 0.18, 0.22), "Cobweb Corner Antiques", Color(0.3, 0.2, 0.35))
	_cobwebs(antiques, Vector3(10, 5.5, 9))
	_hardware(Vector3(_side(1, 10), 0, -63))
	_school(Vector3(0, 0, MAIN_Z.y - 3.0 - 8.0))
	# Planters and benches down both sidewalks (their edges are grindable, like every box's: scripts/edge_rails.gd)
	var g := group("Main Street Things")
	var planter := mat("Planter Stone", Color(0.62, 0.6, 0.58), 0.85)
	var mums := [Color(0.95, 0.55, 0.15), Color(0.75, 0.2, 0.25), Color(0.95, 0.8, 0.25), Color(0.6, 0.3, 0.6)]
	var bench_m := mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7)
	for z in [-43.0, -59.0, -91.0, -107.0]:                             # (between the lamps)
		for sx in [-1.0, 1.0]:
			var x: float = sx * (STREET_W / 2 + 0.8)
			if sx > 0 and z < -75.0:
				continue                                           # (the skate yard's fence is there)
			_solid_mesh(Vector3(0.9, 0.55, 3.2), planter, Vector3(x, 0.28, z), g)
			for k in 4:
				mesh_at(ball(0.35, 8), mat("Mums %d" % k, mums[k], 0.9), Vector3(x + rng.randf_range(-0.15, 0.15), 0.7, z - 1.2 + k * 0.8), g)
			_bench(g, Vector3(x, 0, z + 3.0), sx * -PI / 2, bench_m)        # (north of it: shop doors are south)


func _bench(parent: Node3D, at: Vector3, yaw: float, m: Material) -> void:
	# A park bench, its seat facing local +Z
	var b := Node3D.new()
	b.position = at
	b.rotation.y = yaw
	parent.add_child(b)
	_solid_mesh(Vector3(1.8, 0.1, 0.5), m, Vector3(0, 0.45, 0), b)
	mesh_at(box(Vector3(1.8, 0.45, 0.08)), m, Vector3(0, 0.8, -0.24), b)
	for sx in [-0.8, 0.8]:
		mesh_at(box(Vector3(0.08, 0.45, 0.45)), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(sx, 0.22, 0), b)


func _library(at: Vector3) -> void:
	# Lantern Hill Library, up on a stone base with wide steps down to the street and a handrail each side of them
	# (grind them!). Walk in at the top.
	var base_h := 1.2
	var size := Vector3(16, 6.5, 13)
	var lib := _walk_in("Library", at + Vector3(0, base_h, 0), PI / 2, size, Color(0.62, 0.32, 0.25), Color(0.25, 0.28, 0.3),
		"Lantern Hill Library", Color(0, 0, 0, 0), Color(0.93, 0.88, 0.78), Color(0.5, 0.33, 0.2))
	_library_inside(lib, size)
	var stone := mat("Library Stone", Color(0.75, 0.73, 0.68), 0.85)
	var hd := size.z / 2.0
	# The base under the building, and a porch in front of the door
	_solid_mesh(Vector3(size.x + 1.0, base_h, size.z + 1.0), stone, Vector3(0, -base_h / 2, 0), lib)
	_solid_mesh(Vector3(8.0, base_h, 2.5), stone, Vector3(0, -base_h / 2, hd + 1.25), lib)
	var steps := 4
	for k in steps:                                                  # steps down to the sidewalk
		var top := base_h * (steps - k - 0.5) / steps
		_solid_mesh(Vector3(8.0, top, 0.5), stone, Vector3(0, top / 2 - base_h, hd + 2.5 + 0.25 + k * 0.5), lib)
	var rail := kit.mat("Rail", 0.25, 0.8)
	for x in [-3.6, 3.6]:
		var a := Vector3(x, 0.8, hd + 1.0)
		var b := Vector3(x, 0.8, hd + 2.5)
		var c := Vector3(x, 0.8 - base_h, hd + 2.5 + steps * 0.5 + 0.6)
		kit.tube(a, b, 0.05, rail, lib)
		kit.tube(b, c, 0.05, rail, lib)
		for p in [[a, 0.0], [b, 0.0], [c, -base_h]]:
			kit.tube(Vector3(p[0].x, p[1], p[0].z), p[0], 0.04, rail, lib)
		kit.grind_line("Handrail " + ("A" if x < 0.0 else "B"), [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, c + Vector3.UP * 0.05], "rail", lib)
	# The library's lanterns, either side of the door
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.35, 0.5, 0.35)), mat("Lamp Glass", Color(1.0, 0.85, 0.55), 0.3, 2.0), Vector3(sx * 1.6, 2.4, hd + 0.3), lib)


func _fire_station(at: Vector3) -> void:
	# Fire Station No. 1: red brick, two big doors (one open, the shiny red truck half out of it), a bell and a
	# dalmatian-spotted bench
	var size := Vector3(12, 6.0, 12)
	var g := _building("Fire Station", at, PI / 2, size, Color(0.62, 0.2, 0.16), Color(0.25, 0.22, 0.22), "Fire Station No. 1")
	var hd := size.z / 2.0
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(4.2, 3.8, 0.1)), mat("Station Door", Color(0.9, 0.88, 0.85), 0.6), Vector3(sx * 3.0, 1.9, hd + 0.06), g)
		for k in 4:
			mesh_at(box(Vector3(4.0, 0.05, 0.12)), mat("Door Line", Color(0.6, 0.6, 0.62), 0.6), Vector3(sx * 3.0, 0.5 + k * 0.9, hd + 0.1), g)
	# The truck, parked on the apron in front of the left door
	var truck := Node3D.new()
	truck.name = "Fire Truck"
	truck.position = Vector3(-3.0, 0, hd + 2.6)
	g.add_child(truck)
	var red := mat("Truck Red", Color(0.85, 0.1, 0.1), 0.35)
	_solid_mesh(Vector3(2.4, 1.6, 5.5), red, Vector3(0, 1.3, 0), truck)
	mesh_at(box(Vector3(2.3, 1.0, 1.6)), red, Vector3(0, 2.6, 1.8), truck)
	mesh_at(box(Vector3(2.2, 0.6, 0.05)), mat("Truck Glass", Color(0.7, 0.85, 0.95), 0.1), Vector3(0, 2.75, 2.62), truck)
	mesh_at(box(Vector3(0.4, 0.15, 0.4)), mat("Siren", Color(1.0, 0.2, 0.2), 0.3, 2.0), Vector3(0, 3.18, 1.8), truck)
	for sx in [-0.5, 0.5]:
		mesh_at(cyl(0.05, 0.05, 4.8, 6), mat("Ladder", Color(0.85, 0.85, 0.88), 0.3), Vector3(sx, 2.25, -0.6), truck, 0.0, Vector3(PI / 2, 0, 0))
	for k in 8:
		mesh_at(box(Vector3(1.0, 0.05, 0.05)), mat("Ladder", Color(0.85, 0.85, 0.88), 0.3), Vector3(0, 2.25, -2.8 + k * 0.6), truck)
	for sx in [-1.25, 1.25]:
		for sz in [-1.8, 1.6]:
			mesh_at(cyl(0.48, 0.48, 0.35, 16), mat("Tyre", Color(0.08, 0.08, 0.09), 0.9), Vector3(sx, 0.48, sz), truck, 0.0, Vector3(0, 0, PI / 2))
	# The bell, on a little frame by the door
	var bell := Node3D.new()
	bell.position = Vector3(4.6, 0, hd + 1.4)
	g.add_child(bell)
	for sx in [-0.6, 0.6]:
		mesh_at(box(Vector3(0.12, 2.2, 0.12)), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(sx, 1.1, 0), bell)
	mesh_at(box(Vector3(1.3, 0.12, 0.12)), mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5), Vector3(0, 2.2, 0), bell)
	mesh_at(cyl(0.12, 0.35, 0.5, 14), mat("Brass", Color(0.85, 0.65, 0.25), 0.3), Vector3(0, 1.85, 0), bell)
	(bell.get_child(bell.get_child_count() - 1) as MeshInstance3D).material_override.metallic = 0.8


func _hardware(at: Vector3) -> void:
	# Nuts & Bolts Hardware, with a loading dock on its north side: a raised concrete dock with a kicker up onto it,
	# a rail along its edge and pallets, the kind of spot skaters always find
	var size := Vector3(12, 5.0, 10)
	var g := _building("Hardware Store", at, -PI / 2, size, Color(0.55, 0.6, 0.5), Color(0.3, 0.25, 0.22), "Nuts & Bolts Hardware",
		Color(0.85, 0.35, 0.15))
	# Wheelbarrows and rakes out front, for raking leaves
	var hd := size.z / 2.0
	for k in 3:
		mesh_at(cyl(0.02, 0.02, 1.6, 6), mat("Rake Handle", Color(0.6, 0.45, 0.3), 0.7), Vector3(-size.x / 2 + 1.0 + k * 0.3, 0.8, hd + 0.2), g,
			0.0, Vector3(-0.2, 0, 0))
		mesh_at(box(Vector3(0.4, 0.05, 0.06)), mat("Rake Head", Color(0.3, 0.3, 0.32), 0.4), Vector3(-size.x / 2 + 1.0 + k * 0.3, 1.6, hd + 0.05), g)
	# The dock: on the store's north side (its local -x), running along the side wall
	var dock := Node3D.new()
	dock.name = "Loading Dock"
	dock.position = Vector3(-size.x / 2 - 2.0, 0, -0.5)
	g.add_child(dock)
	var concrete := kit.mat("Concrete", 0.85)
	var dh := 1.2
	_solid_mesh(Vector3(4.0, dh, 8.0), concrete, Vector3(0, dh / 2, 0), dock)
	kit.kicker(dock, "Dock Kicker", Vector3(0, 0, 4.0 + 3.0), PI, 3.0, dh, 3.0)       # up onto the dock from the front
	kit.flat_rail(dock, "Dock Rail", Vector3(-2.3, dh, -0.5), Vector3(0, 0, 1), 6.0, 0.55)
	for k in 2:
		_solid_mesh(Vector3(1.2, 0.3, 1.0), mat("Pallet", Color(0.7, 0.55, 0.35), 0.9), Vector3(0.8, dh + 0.15 + k * 0.3, -2.8), dock)
	_foot("Loading Dock", g.position + Vector3(-1.5, 0, -size.x / 2 - 2.0), 0.0, Vector2(12.0, 4.0), "skate")


func _school(at: Vector3) -> void:
	# Old Oak Elementary, at the top of Main Street: red brick with a white bell tower, steps with handrails, the
	# flag, a bike rack and a chalk hopscotch on the path
	var size := Vector3(26, 7.0, 14)
	var g := _building("School", at, 0.0, size, Color(0.66, 0.3, 0.24), Color(0.25, 0.25, 0.28), "Old Oak Elementary")
	var white := mat("Gazebo White", Color(0.96, 0.95, 0.92), 0.6)
	mesh_at(box(Vector3(3.0, 3.0, 3.0)), white, Vector3(0, size.y + 3.2, 0), g)
	mesh_at(cyl(0.0, 2.3, 3.0, 4), mat("Steeple Roof", Color(0.3, 0.3, 0.32)), Vector3(0, size.y + 6.2, 0), g, PI / 4)
	mesh_at(cyl(0.3, 0.6, 0.7, 12), mat("Brass", Color(0.85, 0.65, 0.25), 0.3), Vector3(0, size.y + 3.0, 1.55), g)
	var hd := size.z / 2.0
	var glass := mat("Warm Window", Color(1.0, 0.85, 0.55), 0.3, 1.6)
	for k in 6:
		var wx := -size.x / 2 + 2.5 + k * (size.x - 5.0) / 5.0
		if absf(wx) < 2.5:
			continue
		for y in [1.8, 4.8]:
			mesh_at(box(Vector3(1.6, 1.4, 0.1)), glass, Vector3(wx, y, hd + 0.05), g)
	# Wide steps up to the door and their handrails (the stair set is the skate kit's)
	kit.stairs_and_handrail(g, "School Steps", Vector3(-9.0, 0, hd + 11.0))
	# The bike rack and hopscotch
	for k in 5:
		kit.tube(Vector3(6 + k * 0.6, 0, hd + 2.0), Vector3(6 + k * 0.6, 0.8, hd + 2.0), 0.03, kit.mat("Rail", 0.25, 0.8), g)
	kit.tube(Vector3(6, 0.8, hd + 2.0), Vector3(8.4, 0.8, hd + 2.0), 0.03, kit.mat("Rail", 0.25, 0.8), g)
	var chalk := mat("Chalk", Color(0.95, 0.92, 0.98), 0.9)
	for k in 8:
		mesh_at(box(Vector3(0.6, 0.02, 0.6)), chalk, Vector3(2.5 + (0.35 if k % 3 == 1 else 0.0), 0.08, hd + 3.0 + k * 0.7), g)
	_foot("School Steps", g.position + Vector3(-9.0, 0, hd + 9.0), 0.0, Vector2(9, 14), "skate")


func _witch_hat(parent: Node3D, at: Vector3, s: float) -> void:
	var black := mat("Witch Hat", Color(0.12, 0.08, 0.15), 0.7)
	mesh_at(cyl(s * 0.9, s * 0.9, s * 0.08, 16), black, at, parent)
	mesh_at(cyl(0.0, s * 0.45, s * 1.3, 12), black, at + Vector3(0, s * 0.65, 0), parent, 0.0, Vector3(0, 0, 0.15))
	mesh_at(cyl(s * 0.46, s * 0.46, s * 0.12, 12), mat("Hat Band", Color(0.95, 0.5, 0.12), 0.6), at + Vector3(0, s * 0.1, 0), parent)


func _cobwebs(parent: Node3D, size: Vector3) -> void:
	# Spooky-cute cobwebs in the antique shop's top window corners (thin pale threads)
	var web := mat("Cobweb", Color(0.95, 0.95, 0.98), 0.5, 0.4)
	var hd := size.z / 2.0 + 0.08
	for sx in [-1.0, 1.0]:
		var corner := Vector3(sx * size.x / 2, size.y, hd)
		for k in 4:
			var a := PI / 2 * (k + 0.5) / 4.0
			var d := Vector3(-sx * sin(a), -cos(a), 0)
			mesh_at(box(Vector3(0.02, 1.4, 0.02)), web, corner + d * 0.7, parent, 0.0, Vector3(0, 0, atan2(-d.x, d.y)))
		for r in [0.4, 0.8, 1.2]:
			mesh_at(box(Vector3(r * 1.1, 0.02, 0.02)), web, corner + Vector3(-sx * r * 0.5, -r * 0.5, 0), parent, 0.0, Vector3(0, 0, sx * PI / 4))


# -----------------------------------------------------------------------------
# Maple Lane: where people live
# -----------------------------------------------------------------------------
func _maple_lane() -> void:
	var north_z := MAPLE_Z - (STREET_W / 2 + 1.6 + 5.0 + 3.5)     # house middles, behind their front yards
	var south_z := MAPLE_Z + (STREET_W / 2 + 1.6 + 5.0 + 3.5)
	var cols := [Color(0.85, 0.75, 0.55), Color(0.6, 0.7, 0.85), Color(0.85, 0.6, 0.55), Color(0.7, 0.8, 0.65), Color(0.92, 0.88, 0.8),
		Color(0.65, 0.55, 0.75)]
	var roofs := [Color(0.3, 0.25, 0.25), Color(0.25, 0.3, 0.4), Color(0.4, 0.22, 0.2)]
	# North side (facing south): Mr. Palmer's and three neighbours
	var palmer := _house("Palmer House", Vector3(-62, 0, north_z), 0.0, Color(0.88, 0.86, 0.8), Color(0.22, 0.3, 0.25), "Palmer")
	# Mr. Palmer's porch: a rocking chair, a little table with a teacup (he does like his tea) and a tidy garden
	_chair(palmer, Vector3(2.4, 0, 4.6), PI, Color(0.35, 0.25, 0.18))
	_table(palmer, Vector3(3.3, 0, 4.6), Color(0.35, 0.25, 0.18))
	mesh_at(cyl(0.06, 0.05, 0.08, 10), mat("Teacup", Color(0.97, 0.97, 1.0), 0.4), Vector3(3.3, 0.85, 4.6), palmer)
	_house("Maple House 1", Vector3(-84, 0, north_z), 0.0, cols[0], roofs[0], "Hollis")
	_house("Maple House 2", Vector3(-44, 0, north_z), 0.0, cols[3], roofs[1], "Okafor")
	_house("Maple House 3", Vector3(8, 0, north_z), 0.0, cols[2], roofs[2], "Larkspur")
	# South side (facing north): the Blastoffs' (walk in) and two neighbours
	_blastoff_house(Vector3(-40, 0, south_z + 1.9))
	_house("Maple House 4", Vector3(-70, 0, south_z), PI, cols[5], roofs[1], "Quill")
	_house("Maple House 5", Vector3(-10, 0, south_z), PI, cols[4], roofs[0], "Pemberton")
	_house("Maple House 6", Vector3(16, 0, south_z), PI, cols[1], roofs[2], "Bramblewood")


func _house(name: String, at: Vector3, yaw: float, wall: Color, roof_c: Color, family: String) -> Node3D:
	# A two-storey house with a porch, a picket fence round its front yard and a mailbox with the family's name
	var size := Vector3(9, 5.6, 7)
	var g := _building(name, at, yaw, size, wall, roof_c, "")
	var hd := size.z / 2.0
	var white := mat("Gazebo White", Color(0.96, 0.95, 0.92), 0.6)
	_solid_mesh(Vector3(5.0, 0.3, 2.0), mat("Porch Wood", Color(0.55, 0.4, 0.28), 0.8), Vector3(0, 0.15, hd + 1.0), g)
	mesh_at(box(Vector3(5.4, 0.15, 2.3)), mat("Porch Roof " + name, roof_c, 0.8), Vector3(0, 3.0, hd + 1.1), g)
	for sx in [-2.4, 2.4]:
		mesh_at(box(Vector3(0.15, 2.8, 0.15)), white, Vector3(sx, 1.5, hd + 2.0), g)
	_picket_fence(g, Vector3(-size.x / 2 - 0.5, 0, hd + 3.6), Vector3(-1.0, 0, hd + 3.6), white)
	_picket_fence(g, Vector3(1.0, 0, hd + 3.6), Vector3(size.x / 2 + 0.5, 0, hd + 3.6), white)
	_mailbox(g, Vector3(1.5, 0, hd + 4.2), family)
	_jack(g, Vector3(-1.6, 0.3, hd + 1.5), 0.26)
	_jack(g, Vector3(1.3, 0.3, hd + 1.6), 0.22)
	return g


func _mailbox(parent: Node3D, at: Vector3, family: String) -> void:
	var m := Node3D.new()
	m.name = "Mailbox"
	m.position = at
	parent.add_child(m)
	mesh_at(box(Vector3(0.1, 1.1, 0.1)), mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8), Vector3(0, 0.55, 0), m)
	var body := mesh_at(cyl(0.18, 0.18, 0.6, 12), mat("Mailbox", Color(0.2, 0.25, 0.3), 0.4), Vector3(0, 1.25, 0), m, 0.0, Vector3(PI / 2, 0, 0))
	body.name = "Box"
	mesh_at(box(Vector3(0.04, 0.25, 0.12)), mat("Mail Flag", Color(0.9, 0.2, 0.15), 0.5), Vector3(0.2, 1.35, -0.1), m)
	var l := label(m, family, Vector3(0, 1.55, 0), 24)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y


func _blastoff_house(at: Vector3) -> void:
	# The Blastoffs' house on Maple Lane, where Nina, Prue and Bruno live. Walk in: a living room with a fireplace at
	# the front, and a bedroom each at the back. Nina's is red and black with her bow on the wall, Prue's is soft
	# lilac with plushies, and Bruno's has skate posters, a board on the wall and a little ramp.
	var size := Vector3(16, 5.0, 12)
	var g := _walk_in("Blastoff House", at, PI, size, Color(0.95, 0.85, 0.6), Color(0.35, 0.22, 0.3), "", Color(0, 0, 0, 0),
		Color(0.96, 0.92, 0.85), Color(0.6, 0.42, 0.28))
	var hd := size.z / 2.0
	var hw := size.x / 2.0
	_mailbox(g, Vector3(2.0, 0, hd + 3.4), "Blastoff")
	var white := mat("Gazebo White", Color(0.96, 0.95, 0.92), 0.6)
	_picket_fence(g, Vector3(-hw - 0.5, 0, hd + 3.0), Vector3(-1.2, 0, hd + 3.0), white)
	_picket_fence(g, Vector3(1.2, 0, hd + 3.0), Vector3(hw + 0.5, 0, hd + 3.0), white)
	_scarecrow(g, Vector3(-4.5, 0, hd + 1.8), 0.4)
	# Inner walls: across the middle (with a doorway into each bedroom) and between the bedrooms
	var inner := mat("Inside Blastoff House", Color(0.96, 0.92, 0.85), 0.9)
	var room_w := (size.x - 0.6) / 3.0
	var wall_h := size.y - 0.3
	for k in 3:
		var cx := -hw + 0.3 + room_w * (k + 0.5)
		for side in [-1.0, 1.0]:
			var seg := (room_w - 1.6) / 2.0
			_solid_mesh(Vector3(seg, wall_h, 0.2), inner, Vector3(cx + side * (0.8 + seg / 2.0), wall_h / 2.0, -0.5), g)
		mesh_at(box(Vector3(1.6, 1.4, 0.2)), inner, Vector3(cx, wall_h - 0.7, -0.5), g)
	for k in [1, 2]:
		_solid_mesh(Vector3(0.2, wall_h, hd - 0.8), inner, Vector3(-hw + 0.3 + room_w * k, wall_h / 2.0, -(hd + 0.5) / 2.0 - 0.0), g)
	# The bedrooms: [name, wall colour, blanket colour, x]
	var rooms := [["Bruno", Color(0.55, 0.7, 0.9), Color(0.95, 0.5, 0.15)], ["Prue", Color(0.85, 0.75, 0.95), Color(0.98, 0.7, 0.8)],
		["Nina", Color(0.18, 0.12, 0.14), Color(0.8, 0.12, 0.15)]]
	for k in 3:
		var cx := -hw + 0.3 + room_w * (k + 0.5)
		var room := Node3D.new()
		room.name = "%s's Room" % rooms[k][0]
		room.position = Vector3(cx, 0, -hd / 2.0 - 0.6)
		g.add_child(room)
		# A painted back wall, the bed, a rug and the name on the door
		mesh_at(box(Vector3(room_w - 0.3, wall_h - 0.2, 0.05)), mat("Room Wall %s" % rooms[k][0], rooms[k][1], 0.9), Vector3(0, wall_h / 2.0, -hd / 2.0 + 0.95), room)
		var bed := Node3D.new()
		bed.position = Vector3(-room_w / 2 + 1.3, 0, -hd / 2.0 + 2.2)
		room.add_child(bed)
		_solid_mesh(Vector3(1.4, 0.45, 2.2), mat("Bed Wood", Color(0.5, 0.32, 0.2), 0.7), Vector3(0, 0.23, 0), bed)
		mesh_at(box(Vector3(1.35, 0.15, 1.5)), mat("Blanket %s" % rooms[k][0], rooms[k][2], 0.8), Vector3(0, 0.52, 0.3), bed)
		mesh_at(box(Vector3(0.9, 0.18, 0.4)), mat("Pillow", Color(1, 1, 1), 0.8), Vector3(0, 0.55, -0.8), bed)
		mesh_at(cyl(0.9, 0.9, 0.03, 24), mat("Rug %s" % rooms[k][0], rooms[k][2].lerp(Color.WHITE, 0.4), 0.9), Vector3(0.6, 0.04, 0.3), room)
		var door_name := label(g, rooms[k][0], Vector3(cx, 2.6, -0.38), 30, Color(1, 0.95, 0.8))
		door_name.name = "%s Door Sign" % rooms[k][0]
	var bruno := g.get_node("Bruno's Room") as Node3D
	var nina := g.get_node("Nina's Room") as Node3D
	var prue := g.get_node("Prue's Room") as Node3D
	var back := -hd / 2.0 + 1.0
	# Bruno's: three skate posters, a board on the wall and a little ramp on the floor
	var poster_cols := [[Color(0.95, 0.4, 0.1), Color(0.15, 0.1, 0.2)], [Color(0.25, 0.75, 0.9), Color(0.98, 0.9, 0.3)],
		[Color(0.6, 0.2, 0.75), Color(0.4, 0.95, 0.5)]]
	for k in 3:
		var px := -1.2 + k * 1.2
		mesh_at(box(Vector3(0.9, 1.2, 0.03)), mat("Poster %d" % k, poster_cols[k][0], 0.8), Vector3(px, 2.6, back + 0.02), bruno)
		var deck := mesh_at(box(Vector3(0.22, 0.85, 0.02)), mat("Poster Deck %d" % k, poster_cols[k][1], 0.6), Vector3(px, 2.6, back + 0.05), bruno)
		deck.rotation.z = 0.35 * (k - 1)
	var board := Node3D.new()
	board.name = "Wall Board"
	board.position = Vector3(room_w / 2 - 0.25, 1.6, 0.6)
	board.rotation = Vector3(0, PI / 2, PI / 2)
	bruno.add_child(board)
	mesh_at(box(Vector3(0.8, 0.03, 0.22)), mat("Deck Top", Color(0.15, 0.15, 0.18), 0.9), Vector3.ZERO, board)
	kit.kicker(bruno, "Bruno's Ramp", Vector3(0.9, 0, 1.0), PI / 2, 1.0, 0.3, 0.8)
	# Prue's: plushies on the bed and a star lamp
	for k in 3:
		mesh_at(ball(0.16, 10), mat("Plush %d" % k, [Color(0.98, 0.75, 0.85), Color(0.75, 0.85, 1.0), Color(1.0, 0.95, 0.7)][k], 0.9),
			Vector3(-room_w / 2 + 0.9 + k * 0.35, 0.78, -hd / 2.0 + 1.6), prue)
	mesh_at(ball(0.2, 8), mat("Star Lamp", Color(1.0, 0.9, 0.5), 0.3, 2.0), Vector3(room_w / 2 - 0.8, 1.2, back + 0.6), prue)
	# Nina's: her big red bow on the wall, and a little desk with a lamp
	var red := mat("Nina Red", Color(0.85, 0.1, 0.14), 0.6)
	for sx in [-1.0, 1.0]:
		var loop := mesh_at(cyl(0.0, 0.4, 0.6, 3), red, Vector3(sx * 0.32, 2.7, back + 0.08), nina, 0.0, Vector3(0, 0, sx * PI / 2))
		loop.scale = Vector3(1, 1, 0.2)
	mesh_at(ball(0.13, 10), red, Vector3(0, 2.7, back + 0.1), nina)
	_solid_mesh(Vector3(1.2, 0.75, 0.6), mat("Desk Wood", Color(0.4, 0.26, 0.16), 0.7), Vector3(room_w / 2 - 1.0, 0.38, back + 0.5), nina)
	mesh_at(cyl(0.1, 0.14, 0.3, 10), mat("Desk Lamp", Color(0.95, 0.85, 0.6), 0.4, 1.5), Vector3(room_w / 2 - 0.7, 0.9, back + 0.5), nina)
	# The living room: a sofa facing the fireplace, a pumpkin on the mantel, the family photo
	var stone := mat("Fireplace Stone", Color(0.55, 0.5, 0.48), 0.9)
	_solid_mesh(Vector3(2.2, 1.6, 0.6), stone, Vector3(-hw + 0.7, 0.8, hd / 2.0), g, PI / 2)
	mesh_at(box(Vector3(1.0, 0.6, 0.05)), mat("Fire Glow", Color(1.0, 0.55, 0.2), 0.5, 2.5), Vector3(-hw + 1.01, 0.5, hd / 2.0), g, PI / 2)
	_jack(g, Vector3(-hw + 0.7, 1.6, hd / 2.0 - 0.5), 0.18)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.6, 0.3)
	fire.light_energy = 1.0
	fire.omni_range = 5.0
	fire.position = Vector3(-hw + 1.6, 0.8, hd / 2.0)
	g.add_child(fire)
	var sofa := mat("Sofa", Color(0.45, 0.55, 0.4), 0.9)
	_solid_mesh(Vector3(0.9, 0.5, 2.6), sofa, Vector3(-hw + 4.2, 0.25, hd / 2.0), g)
	mesh_at(box(Vector3(0.25, 0.9, 2.6)), sofa, Vector3(-hw + 4.6, 0.6, hd / 2.0), g)
	mesh_at(box(Vector3(1.0, 0.7, 0.04)), mat("Family Photo", Color(0.95, 0.85, 0.6), 0.6), Vector3(hw - 0.33, 2.0, hd / 2.0), g, PI / 2)
	label(g, "The Blastoffs", Vector3(hw - 0.36, 2.0, hd / 2.0), 22, Color(0.3, 0.15, 0.1)).rotation.y = -PI / 2
	var bed_spot := Marker3D.new()
	bed_spot.name = "NinaBed"
	bed_spot.position = nina.position + Vector3(-room_w / 2 + 1.3, 1.0, -hd / 2.0 + 2.2)
	g.add_child(bed_spot)


# -----------------------------------------------------------------------------
# The park: Willow Pond, Whisper Creek, Mossy Falls, Lookout Hill, the playground and the pumpkin patch
# -----------------------------------------------------------------------------
func _h(x: float, z: float) -> float:
	return EarthLand.height(x, z)


func _on_ground(p: Vector2, y_off := 0.0) -> Vector3:
	return Vector3(p.x, _h(p.x, p.y) + y_off, p.y)


func _path(parent: Node3D, pts: Array, width := 2.0) -> void:
	# A gravel path through the points, each piece laid on the ground at its middle
	var gravel := mat("Gravel", Color(0.72, 0.66, 0.58), 0.95)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid := (a + b) / 2.0
		var d := b - a
		mesh_at(box(Vector3(width, 0.06, d.length() + width * 0.5)), gravel, _on_ground(mid, 0.035), parent, atan2(d.x, d.y))
		roads.append([a, b, width, "path"])


func _park() -> void:
	var g := group("Park")
	spots.append(["Willow Pond", Vector2(EarthLand.POND.x, EarthLand.POND.y)])
	spots.append(["Whisper Creek", Vector2(-97, -46)])
	spots.append(["Mossy Falls", Vector2(-104, -83)])
	spots.append(["Lookout Hill", EarthLand.HILL])
	# Paths: round the Town Hall to the dock, to the playground, and up past the footbridge to the hill
	_path(g, [Vector2(-25, 14), Vector2(-45, 14), Vector2(-58, 10), Vector2(-61.5, 2)])
	_path(g, [Vector2(-45, 14), Vector2(-52, 24)])
	_path(g, [Vector2(-25, -14), Vector2(-45, -18), Vector2(-70, -28), Vector2(-90.5, -36)])
	_path(g, [Vector2(-100.5, -38.5), Vector2(-112, -46), Vector2(-118, -66)])
	_footbridge(g)
	_dock(g)
	_playground(g, Vector2(-56, 30))
	_pumpkin_patch(g, Vector2(-128, 22))
	_lookout_hill(g)
	_covered_bridge()
	# Benches round the pond (grindable edges) and a few lamps
	var bench_m := mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7)
	for a in [0.5, 1.3, 2.4, 3.6, 4.6]:
		var p := Vector2(EarthLand.POND.x + cos(a) * EarthLand.POND.z * 1.38, EarthLand.POND.y + sin(a) * EarthLand.POND.w * 1.38)
		if _clear(p, 0.5, false) and EarthLand.creek_distance(p.x, p.y) > 7.0:
			var to_pond := (Vector2(EarthLand.POND.x, EarthLand.POND.y) - p).normalized()
			_bench(g, _on_ground(p), atan2(to_pond.x, to_pond.y), bench_m)
	label(g, "Willow Pond", _on_ground(Vector2(-60.5, 6.5), 2.4), 40).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y


func _footbridge(g: Node3D) -> void:
	# A little wooden footbridge over the creek on the way to the hill, with a handrail each side (grind them)
	var c := Vector2(-95.5, -37.25)
	var across := Vector2(0.97, 0.24).normalized()                   # (lined up with the gravel path at each end)
	var a := c - across * 5.2
	var b := c + across * 5.2
	var br := Node3D.new()
	br.name = "Footbridge"
	g.add_child(br)
	var wood := mat("Bridge Wood", Color(0.55, 0.38, 0.25), 0.85)
	var yaw := atan2(across.x, across.y)
	_solid_mesh(Vector3(2.4, 0.25, 10.4), wood, Vector3(c.x, 0.12, c.y), br, yaw)
	var side := Vector2(across.y, -across.x)
	for s in [-1.0, 1.0]:
		var o: Vector2 = side * s * 1.15
		kit.ground_rail(br, "Bridge Rail " + ("A" if s < 0 else "B"), Vector3(a.x + o.x, 0.25, a.y + o.y), Vector3(b.x + o.x, 0.25, b.y + o.y), 0.85)
	feet.append({"name": "Footbridge", "at": c, "size": Vector2(2.4, 10.4), "yaw": yaw, "kind": "bridge", "label": ""})


func _dock(g: Node3D) -> void:
	# A wooden dock out into the pond from its east shore, on posts, with a rowing boat tied up
	var d := Node3D.new()
	d.name = "Dock"
	g.add_child(d)
	var wood := mat("Bridge Wood", Color(0.55, 0.38, 0.25), 0.85)
	var x0 := -61.5
	var x1 := -74.0
	_solid_mesh(Vector3(absf(x1 - x0), 0.2, 2.6), wood, Vector3((x0 + x1) / 2.0, 0.15, 0.0), d)
	for k in 5:
		var x := lerpf(x0, x1, k / 4.0)
		for sz in [-1.2, 1.2]:
			var top := 0.1
			var bottom := _h(x, sz) - 0.3
			mesh_at(cyl(0.12, 0.12, top - bottom, 8), mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8), Vector3(x, (top + bottom) / 2.0, sz), d)
	var boat := Node3D.new()
	boat.name = "Rowing Boat"
	boat.position = Vector3(x1 + 3.0, EarthLand.WATER_Y + 0.1, 2.6)
	boat.rotation.y = 0.3
	d.add_child(boat)
	var hull := mesh_at(ball(1.0, 16), mat("Boat Red", Color(0.7, 0.2, 0.15), 0.6), Vector3(0, 0, 0), boat)
	hull.scale = Vector3(0.9, 0.35, 2.0)
	mesh_at(box(Vector3(1.4, 0.06, 0.35)), wood, Vector3(0, 0.3, 0), boat)
	feet.append({"name": "Dock", "at": Vector2((x0 + x1) / 2.0, 0.0), "size": Vector2(absf(x1 - x0), 2.6), "yaw": 0.0, "kind": "dock", "label": ""})


func _playground(g: Node3D, at: Vector2) -> void:
	# The playground: a slide (a nod to the show's pilot: the kids asked Mr. Palmer for one), swings, a seesaw and a
	# sandbox, on soft bark
	var p := Node3D.new()
	p.name = "Playground"
	p.position = _on_ground(at)
	g.add_child(p)
	mesh_at(cyl(8.0, 8.0, 0.05, 32), mat("Bark Chips", Color(0.5, 0.35, 0.22), 0.95), Vector3(0, 0.03, 0), p)
	spots.append(["Playground", at])
	_foot("Playground", p.position, 0.0, Vector2(15, 15), "park")
	# The slide: a ladder up to a platform with a roof, and a long yellow slide down
	var post := mat("Play Post", Color(0.25, 0.55, 0.8), 0.6)
	var sl := Node3D.new()
	sl.name = "Slide"
	sl.position = Vector3(-3.0, 0, -1.0)
	p.add_child(sl)
	for sx in [-0.8, 0.8]:
		for sz in [-0.8, 0.8]:
			mesh_at(cyl(0.08, 0.08, 3.4, 8), post, Vector3(sx, 1.7, sz), sl)
	_solid_mesh(Vector3(1.8, 0.15, 1.8), mat("Play Deck", Color(0.95, 0.5, 0.2), 0.7), Vector3(0, 2.0, 0), sl)
	mesh_at(cyl(0.0, 1.4, 0.9, 4), mat("Play Roof", Color(0.85, 0.2, 0.25), 0.6), Vector3(0, 3.8, 0), sl, PI / 4)
	for k in 6:                                                         # the ladder's rungs, up the back
		mesh_at(box(Vector3(1.4, 0.06, 0.06)), post, Vector3(0, 0.3 + k * 0.33, -0.9), sl)
	var chute := Node3D.new()
	chute.position = Vector3(0, 1.05, 2.4)
	chute.rotation.x = atan2(2.0, 3.2)                                 # (its +Z end down)
	sl.add_child(chute)
	var yellow := mat("Slide Yellow", Color(0.98, 0.82, 0.2), 0.3)
	mesh_at(box(Vector3(0.9, 0.06, 3.8)), yellow, Vector3.ZERO, chute)
	for sx in [-0.45, 0.45]:
		mesh_at(box(Vector3(0.06, 0.25, 3.8)), yellow, Vector3(sx, 0.12, 0), chute)
	var sign_post := Node3D.new()
	sign_post.position = Vector3(-6.2, 0, 2.5)
	sign_post.rotation.y = 0.5
	p.add_child(sign_post)
	mesh_at(box(Vector3(0.1, 1.5, 0.1)), mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8), Vector3(0, 0.75, 0), sign_post)
	mesh_at(box(Vector3(1.8, 0.9, 0.06)), mat("Kid Sign", Color(0.98, 0.95, 0.85), 0.8), Vector3(0, 1.5, 0), sign_post)
	label(sign_post, "WE ASKED FOR\nA SLIDE...\nAND WE GOT ONE!", Vector3(0, 1.5, 0.04), 18, Color(0.85, 0.2, 0.25)).outline_size = 0
	# Swings
	var sw := Node3D.new()
	sw.name = "Swings"
	sw.position = Vector3(3.5, 0, -2.0)
	p.add_child(sw)
	for sx in [-1.8, 1.8]:
		for sz in [-0.7, 0.7]:
			mesh_at(cyl(0.06, 0.06, 2.9, 8), post, Vector3(sx, 1.4, sz * 0.5), sw, 0.0, Vector3(sz * 0.4, 0, 0))
	mesh_at(cyl(0.07, 0.07, 3.8, 8), post, Vector3(0, 2.75, 0), sw, 0.0, Vector3(0, 0, PI / 2))
	for sx in [-0.8, 0.8]:
		for rx in [-0.22, 0.22]:
			mesh_at(cyl(0.015, 0.015, 2.1, 4), mat("Chain", Color(0.7, 0.7, 0.72), 0.3), Vector3(sx + rx, 1.7, 0), sw)
		mesh_at(box(Vector3(0.55, 0.05, 0.25)), mat("Swing Seat", Color(0.85, 0.2, 0.25), 0.6), Vector3(sx, 0.62, 0), sw)
	# The sandbox, with a bucket
	var sand := Node3D.new()
	sand.position = Vector3(2.5, 0, 4.0)
	p.add_child(sand)
	_solid_mesh(Vector3(3.0, 0.3, 0.2), mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7), Vector3(0, 0.15, -1.5), sand)
	_solid_mesh(Vector3(3.0, 0.3, 0.2), mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7), Vector3(0, 0.15, 1.5), sand)
	_solid_mesh(Vector3(0.2, 0.3, 3.0), mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7), Vector3(-1.5, 0.15, 0), sand)
	_solid_mesh(Vector3(0.2, 0.3, 3.0), mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7), Vector3(1.5, 0.15, 0), sand)
	mesh_at(box(Vector3(2.8, 0.2, 2.8)), mat("Sand", Color(0.9, 0.8, 0.55), 0.95), Vector3(0, 0.1, 0), sand)
	mesh_at(cyl(0.15, 0.11, 0.22, 10), mat("Bucket", Color(0.3, 0.6, 0.95), 0.5), Vector3(0.6, 0.31, 0.3), sand)


func _scarecrow(parent: Node3D, at: Vector3, yaw: float) -> void:
	# A friendly scarecrow: a post and crossbar, a plaid shirt, a sack head with a stitched smile and a floppy hat
	var s := Node3D.new()
	s.name = "Scarecrow"
	s.position = at
	s.rotation.y = yaw
	parent.add_child(s)
	var wood := mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8)
	mesh_at(box(Vector3(0.12, 2.3, 0.12)), wood, Vector3(0, 1.15, 0), s)
	mesh_at(box(Vector3(1.8, 0.1, 0.1)), wood, Vector3(0, 1.7, 0), s)
	mesh_at(box(Vector3(0.75, 0.8, 0.35)), mat("Plaid Shirt", Color(0.75, 0.3, 0.15), 0.9), Vector3(0, 1.45, 0), s)
	for sx in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.55, 0.22, 0.25)), mat("Plaid Shirt", Color(0.75, 0.3, 0.15), 0.9), Vector3(sx * 0.6, 1.7, 0), s)
		mesh_at(cyl(0.02, 0.08, 0.25, 6), mat("Straw", Color(0.92, 0.8, 0.4), 0.95), Vector3(sx * 0.95, 1.7, 0), s, 0.0, Vector3(0, 0, sx * PI / 2))
	mesh_at(ball(0.27, 12), mat("Sack Head", Color(0.85, 0.72, 0.5), 0.95), Vector3(0, 2.1, 0), s)
	for sx in [-0.09, 0.09]:
		mesh_at(box(Vector3(0.06, 0.06, 0.02)), mat("Stitch", Color(0.15, 0.1, 0.08), 0.9), Vector3(sx, 2.15, 0.26), s)
	mesh_at(box(Vector3(0.18, 0.025, 0.02)), mat("Stitch", Color(0.15, 0.1, 0.08), 0.9), Vector3(0, 2.0, 0.25), s)
	mesh_at(cyl(0.4, 0.4, 0.04, 14), mat("Straw Hat", Color(0.82, 0.68, 0.38), 0.9), Vector3(0, 2.3, 0), s, 0.0, Vector3(0.12, 0, 0))
	mesh_at(cyl(0.16, 0.2, 0.22, 12), mat("Straw Hat", Color(0.82, 0.68, 0.38), 0.9), Vector3(0, 2.42, 0), s)


func _pumpkin_patch(g: Node3D, at: Vector2) -> void:
	# Rows of pumpkins on dark soil, two scarecrows, hay bales and a sign, by the old split-rail fence
	var p := Node3D.new()
	p.name = "Pumpkin Patch"
	p.position = _on_ground(at)
	g.add_child(p)
	spots.append(["Pumpkin Patch", at])
	_foot("Pumpkin Patch", p.position, 0.0, Vector2(18, 12), "park")
	mesh_at(box(Vector3(16, 0.05, 10)), mat("Soil", Color(0.3, 0.22, 0.15), 0.95), Vector3(0, 0.03, 0), p)
	for row in 4:
		for k in 7:
			var pp := Vector3(-6.5 + k * 2.1 + rng.randf_range(-0.4, 0.4), 0.05, -3.6 + row * 2.4 + rng.randf_range(-0.3, 0.3))
			if (row * 7 + k) % 9 == 4:
				_jack(p, pp, rng.randf_range(0.3, 0.42))
			else:
				_pumpkin(p, pp, rng.randf_range(0.25, 0.5))
	_scarecrow(p, Vector3(-3.0, 0, 0.3), 0.3)
	_scarecrow(p, Vector3(4.0, 0, -1.0), -0.4)
	for k in 3:
		var hp := Vector3(9.0, 0.45, -3 + k * 1.3)
		mesh_at(cyl(0.6, 0.6, 1.2, 16), mat("Hay", Color(0.88, 0.74, 0.38), 0.95), hp, p, 0.0, Vector3(0, 0, PI / 2))
		solid_box(Vector3(1.2, 0.9, 1.0), hp, p)
	var wood := mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8)
	for k in 7:                                                       # a split-rail fence along the front
		mesh_at(box(Vector3(0.14, 1.1, 0.14)), wood, Vector3(-8.5 + k * 2.8, 0.55, 5.6), p)
	for y in [0.45, 0.9]:
		_solid_mesh(Vector3(17.0, 0.1, 0.1), wood, Vector3(0, y, 5.6), p)
	var sign_post := Node3D.new()
	sign_post.position = Vector3(10.5, 0, 5.5)
	p.add_child(sign_post)
	mesh_at(box(Vector3(0.1, 1.6, 0.1)), wood, Vector3(0, 0.8, 0), sign_post)
	mesh_at(box(Vector3(2.0, 0.6, 0.06)), mat("Sign Board", Color(0.18, 0.25, 0.2)), Vector3(0, 1.5, 0), sign_post)
	label(sign_post, "Pumpkin Patch", Vector3(0, 1.5, 0.05), 30)


func _lookout_hill(g: Node3D) -> void:
	# The top of Lookout Hill: a bench and a coin telescope looking over town, a sign, and a rail all the way down
	# its east slope with a big kicker at the bottom (ride off the top and fly!)
	var top := Node3D.new()
	top.name = "Lookout"
	var c := EarthLand.HILL + Vector2(7, 5)
	top.position = _on_ground(c)
	g.add_child(top)
	var bench_m := mat("Bench Wood", Color(0.5, 0.33, 0.2), 0.7)
	_bench(top, Vector3(0, 0, 0), PI * 0.8, bench_m)
	var scope := Node3D.new()
	scope.position = Vector3(2.0, 0, 0.6)
	top.add_child(scope)
	var metal := mat("Scope Metal", Color(0.3, 0.5, 0.45), 0.4)
	mesh_at(cyl(0.08, 0.1, 1.1, 8), metal, Vector3(0, 0.55, 0), scope)
	mesh_at(cyl(0.12, 0.16, 0.6, 10), metal, Vector3(0, 1.25, 0.1), scope, 0.0, Vector3(1.2, 0, 0))
	var sign_post := Node3D.new()
	sign_post.position = Vector3(-2.2, 0, 1.0)
	top.add_child(sign_post)
	var wood := mat("Post Wood", Color(0.45, 0.32, 0.22), 0.8)
	mesh_at(box(Vector3(0.1, 1.6, 0.1)), wood, Vector3(0, 0.8, 0), sign_post)
	mesh_at(box(Vector3(2.0, 0.6, 0.06)), mat("Sign Board", Color(0.18, 0.25, 0.2)), Vector3(0, 1.5, 0), sign_post)
	label(sign_post, "Lookout Hill", Vector3(0, 1.5, 0.05), 30)
	# The hill rail: from the top's edge straight down the east slope, following the ground
	var rail_z := EarthLand.HILL.y + 4.0
	var pts := []
	var x := EarthLand.HILL.x + EarthLand.HILL_FLAT - 4.0
	while x <= EarthLand.HILL.x + EarthLand.HILL_FLAT + EarthLand.HILL_SLOPE - 2.0:
		pts.append(Vector3(x, _h(x, rail_z) + 0.6, rail_z))
		x += 2.0
	var hr := Node3D.new()
	hr.name = "Hill Rail"
	g.add_child(hr)
	var rail := kit.mat("Rail", 0.25, 0.8)
	for i in pts.size() - 1:
		kit.tube(pts[i], pts[i + 1], 0.05, rail, hr)
	for i in range(0, pts.size(), 3):
		kit.tube(Vector3(pts[i].x, pts[i].y - 0.8, pts[i].z), pts[i], 0.04, rail, hr)
	var line := []
	for pt in pts:
		line.append(pt + Vector3.UP * 0.05)
	kit.grind_line("Rail", line, "rail", hr)
	# The big kicker at the foot of the slope, beside the rail: down the hill at speed and up you go
	var kx := EarthLand.HILL.x + EarthLand.HILL_FLAT + EarthLand.HILL_SLOPE + 1.5
	var kicker := kit.kicker(g, "Big Air Kicker", Vector3(kx, _h(kx, rail_z - 5.0), rail_z - 5.0), PI / 2, 4.5, 2.2, 4.0)
	feet.append({"name": "Big Air Kicker", "at": Vector2(kx + 2.25, rail_z - 5.0), "size": Vector2(4.5, 4.0), "yaw": 0.0, "kind": "skate", "label": "Big Air!"})
	# A few lanterns on posts up the slope, so the way down is lit at night
	for k in 3:
		var lx := EarthLand.HILL.x + EarthLand.HILL_FLAT + 4.0 + k * 8.0
		_lamp_post(g, Vector3(lx, _h(lx, rail_z + 3.0), rail_z + 3.0))
	kicker.name = "Big Air Kicker"


func _covered_bridge() -> void:
	# The old red covered bridge that carries Maple Lane over Whisper Creek: plank deck, red board walls with little
	# windows, a shingle roof, and a sign over each end
	var g := group("Covered Bridge", Vector3((BRIDGE_X.x + BRIDGE_X.y) / 2.0, 0, MAPLE_Z))
	var length := absf(BRIDGE_X.y - BRIDGE_X.x)
	var red := mat("Barn Red", Color(0.62, 0.14, 0.12), 0.85)
	var white := mat("Barn Trim", Color(0.96, 0.94, 0.9), 0.7)
	var plank := mat("Barn Planks", Color(0.55, 0.38, 0.24), 0.9)
	_solid_mesh(Vector3(length + 1.0, 0.3, STREET_W + 0.6), plank, Vector3(0, 0.0, 0), g)
	for sz in [-1.0, 1.0]:
		var z: float = sz * (STREET_W / 2 + 0.3)
		_solid_mesh(Vector3(length, 3.4, 0.2), red, Vector3(0, 1.85, z), g)
		for k in 3:
			mesh_at(box(Vector3(1.4, 0.6, 0.24)), mat("Bridge Window", Color(0.15, 0.1, 0.08), 0.9), Vector3(-length / 3 + k * length / 3, 2.4, z), g)
		# Its stone feet down in the creek
		for sx in [-1.0, 1.0]:
			var fx: float = sx * (length / 2 - 0.5)
			var bottom := _h(g.position.x + fx, MAPLE_Z + z) - 0.4
			mesh_at(box(Vector3(1.2, -bottom, 1.0)), mat("Library Stone", Color(0.75, 0.73, 0.68), 0.85), Vector3(fx, bottom / 2.0, z), g)
	var roof := PrismMesh.new()
	roof.size = Vector3(STREET_W + 2.0, 1.8, length + 1.2)
	mesh_at(roof, mat("Barn Roof", Color(0.24, 0.22, 0.24), 0.85), Vector3(0, 4.45, 0), g, PI / 2)
	for sx in [-1.0, 1.0]:
		var end := Vector3(sx * (length / 2 + 0.1), 0, 0)
		mesh_at(box(Vector3(0.2, 0.7, STREET_W + 0.6)), white, end + Vector3(0, 3.6, 0), g)
		label(g, "Old Covered Bridge", end + Vector3(sx * 0.12, 3.6, 0), 34, Color(0.3, 0.1, 0.08)).rotation.y = sx * PI / 2
		lamp_light(g, end + Vector3(0, 3.0, 0), Color(1.0, 0.8, 0.55), 1.0, 7.0)
	feet.append({"name": "Covered Bridge", "at": Vector2(g.position.x, MAPLE_Z), "size": Vector2(length + 1.0, STREET_W + 1.0), "yaw": 0.0,
		"kind": "bridge", "label": "Covered Bridge"})


func _lamp_post(parent: Node3D, at: Vector3) -> void:
	var iron := mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5)
	var glow := mat("Lamp Glass", Color(1.0, 0.85, 0.55), 0.3, 2.0)
	mesh_at(cyl(0.07, 0.1, 3.6, 8), iron, at + Vector3(0, 1.8, 0), parent)
	mesh_at(box(Vector3(0.4, 0.5, 0.4)), glow, at + Vector3(0, 3.7, 0), parent)
	lamp_light(parent, at + Vector3(0, 3.5, 0), Color(1.0, 0.82, 0.55), 1.6, 9.0)


func _water() -> void:
	# The pond, the creek and the falls: water surfaces just below the banks (the land under them is scooped out:
	# scripts/earth_land.gd), lily pads and cattails, a soft evening mist, and the wading zone (scripts/water.gd)
	var g := group("Water")
	g.set_script(load("res://scripts/water.gd"))
	g.set("ellipses", EarthLand.water_circles())
	g.set("water_y", EarthLand.WATER_Y)
	var water := mat("Pond Water", Color(0.22, 0.42, 0.48), 0.05, 0.0, 0.82)
	water.metallic = 0.2
	var wy := EarthLand.WATER_Y
	var pond := mesh_at(cyl(1.0, 1.0, 0.02, 48), water, Vector3(EarthLand.POND.x, wy, EarthLand.POND.y), g)
	pond.scale = Vector3(EarthLand.POND.z * 1.2, 1, EarthLand.POND.w * 1.2)
	pond.name = "Pond Surface"
	for i in EarthLand.CREEK.size() - 1:
		var a: Vector2 = EarthLand.CREEK[i]
		var b: Vector2 = EarthLand.CREEK[i + 1]
		var d := b - a
		var mid := (a + b) / 2.0
		mesh_at(box(Vector3(EarthLand.CREEK_HALF * 2.0 + 2.6, 0.02, d.length() + 1.0)), water, Vector3(mid.x, wy - 0.005 * (i % 2), mid.y), g, atan2(d.x, d.y))
	var pool := mesh_at(cyl(6.5, 6.5, 0.02, 32), water, Vector3(EarthLand.FALLS_POOL.x, wy, EarthLand.FALLS_POOL.z), g)
	pool.name = "Falls Pool"
	# Lily pads and cattails
	var pad := mat("Lily Pad", Color(0.3, 0.5, 0.22), 0.8)
	var pond_rng := RandomNumberGenerator.new()                  # its own, so the rest of the town stays where it was
	pond_rng.seed = 77
	for k in 26:
		var a := pond_rng.randf() * TAU
		var r := pond_rng.randf_range(0.35, 0.8)
		var p := Vector3(EarthLand.POND.x + cos(a) * r * EarthLand.POND.z, wy + 0.02, EarthLand.POND.y + sin(a) * r * EarthLand.POND.w)
		if p.distance_to(Vector3(-68, wy, 0)) < 7.0:
			continue                                            # not round the dock
		mesh_at(cyl(0.45, 0.45, 0.02, 12), pad, p, g)
		if k % 5 == 0:
			mesh_at(ball(0.12, 8), mat("Lily Flower", Color(0.98, 0.75, 0.85), 0.6), p + Vector3(0.15, 0.08, 0.1), g)
	var reed := mat("Cattail Stem", Color(0.45, 0.5, 0.25), 0.9)
	var head := mat("Cattail Head", Color(0.4, 0.25, 0.15), 0.9)
	for k in 40:
		var a := pond_rng.randf() * TAU
		var p := Vector3(EarthLand.POND.x + cos(a) * 0.97 * EarthLand.POND.z, 0, EarthLand.POND.y + sin(a) * 0.97 * EarthLand.POND.w)
		if absf(p.z) < 3.0 and p.x > EarthLand.POND.x:
			continue
		p.y = _h(p.x, p.z)
		var h := pond_rng.randf_range(1.0, 1.6)
		mesh_at(cyl(0.02, 0.025, h, 4), reed, p + Vector3(0, h / 2, 0), g)
		mesh_at(cyl(0.05, 0.05, 0.25, 6), head, p + Vector3(0, h - 0.1, 0), g)
	# A thin mist over the pond (a Halloween-y touch)
	var mist := mat("Pond Mist", Color(0.85, 0.85, 0.95), 1.0, 0.0, 0.12)
	for k in 5:
		var m := mesh_at(cyl(1.0, 1.0, 0.02, 24), mist, Vector3(EarthLand.POND.x + pond_rng.randf_range(-8, 8), wy + 0.3 + k * 0.12,
			EarthLand.POND.y + pond_rng.randf_range(-5, 5)), g)
		m.scale = Vector3(pond_rng.randf_range(7, 12), 1, pond_rng.randf_range(4, 7))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Three ducks
	for k in 3:
		var d := Node3D.new()
		d.name = "Duck %d" % (k + 1)
		d.position = Vector3(EarthLand.POND.x - 6 + k * 1.4, wy + 0.12, EarthLand.POND.y - 4 + k * 0.9)
		d.rotation.y = 0.6
		g.add_child(d)
		var body := mesh_at(ball(0.22, 10), mat("Duck %d" % (k % 2), [Color(0.95, 0.85, 0.3), Color(0.55, 0.4, 0.25)][k % 2], 0.8), Vector3.ZERO, d)
		body.scale = Vector3(0.8, 0.7, 1.2)
		mesh_at(ball(0.11, 8), mat("Duck %d" % (k % 2), [Color(0.95, 0.85, 0.3), Color(0.55, 0.4, 0.25)][k % 2], 0.8), Vector3(0, 0.2, 0.2), d)
		mesh_at(cyl(0.0, 0.05, 0.1, 6), mat("Beak", Color(0.95, 0.55, 0.15), 0.6), Vector3(0, 0.19, 0.33), d, 0.0, Vector3(PI / 2, 0, 0))
	_falls(g)


func _falls(g: Node3D) -> void:
	# Mossy Falls: a spring pool on the hilltop spilling over the rocky cliff into the plunge pool below
	var dir2 := EarthLand.falls_dir()
	var dir := Vector3(dir2.x, 0, dir2.y)
	var c := Vector3(EarthLand.HILL.x, 0, EarthLand.HILL.y)
	var top := c + dir * (EarthLand.HILL_FLAT - 0.2) + Vector3(0, EarthLand.HILL_TOP + 0.05, 0)
	var bottom := c + dir * (EarthLand.HILL_FLAT + EarthLand.CLIFF + 0.8) + Vector3(0, EarthLand.WATER_Y, 0)
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall"
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, top.distance_to(bottom), 0.12)
	fall.mesh = bm
	fall.material_override = mat("Falling Water", Color(0.75, 0.9, 1.0), 0.1, 0.6, 0.75)
	var up := (top - bottom).normalized()
	var right := Vector3.UP.cross(dir).normalized()
	var fwd := right.cross(up).normalized()
	fall.transform = Transform3D(Basis(right, up, fwd), (top + bottom) / 2.0 + dir * 0.25)
	g.add_child(fall)
	# Foam where it lands, and the spring pool at the top with its stones
	var foam := mat("Foam", Color(0.95, 0.97, 1.0), 0.6, 0.3, 0.8)
	for k in 7:
		var f := mesh_at(ball(0.5, 10), foam, bottom + right * (k - 3) * 0.5 + dir * 0.6 + Vector3(0, 0.05, 0), g)
		f.scale = Vector3(1.0, 0.35, 1.0)
	var spring_at := c + dir * (EarthLand.HILL_FLAT - 4.0) + Vector3(0, EarthLand.HILL_TOP + 0.04, 0)
	mesh_at(cyl(2.6, 2.6, 0.04, 24), mat("Pond Water", Color(0.22, 0.42, 0.48), 0.05, 0.0, 0.82), spring_at, g)
	mesh_at(box(Vector3(2.8, 0.04, 4.0)), mat("Pond Water", Color(0.22, 0.42, 0.48), 0.05, 0.0, 0.82),
		(spring_at + top) / 2.0 + Vector3(0, 0.01, 0), g, atan2(dir.x, dir.z))
	var rock := mat("Rock", Color(0.42, 0.42, 0.4), 0.95)
	var moss := mat("Moss", Color(0.3, 0.42, 0.2), 0.95)
	for k in 10:
		var a := k * TAU / 10
		var rp := spring_at + Vector3(cos(a), 0, sin(a)) * 2.9
		if Vector3(cos(a), 0, sin(a)).dot(dir) > 0.7:
			continue
		var r := mesh_at(ball(0.5, 8), rock if k % 3 else moss, rp, g)
		r.scale = Vector3(1.0, 0.6, 0.9)
	# Big mossy rocks along the cliff either side of the falls
	var falls_rng := RandomNumberGenerator.new()
	falls_rng.seed = 5
	for k in 16:
		var ang := deg_to_rad(-40.0 + k * 80.0 / 15.0)
		if absf(ang) < deg_to_rad(5.0):
			continue
		var d2 := dir2.rotated(ang)
		var dd := EarthLand.HILL_FLAT + falls_rng.randf_range(0.8, 2.6)
		var p := Vector2(c.x, c.z) + d2 * dd
		var r := mesh_at(ball(1.0, 10), rock if k % 4 else moss, Vector3(p.x, _h(p.x, p.y) - 0.3, p.y), g)
		r.scale = Vector3(falls_rng.randf_range(1.4, 2.4), falls_rng.randf_range(1.2, 2.2), falls_rng.randf_range(1.4, 2.2))
	var splash := OmniLight3D.new()
	splash.light_color = Color(0.7, 0.85, 1.0)
	splash.light_energy = 0.6
	splash.omni_range = 6.0
	splash.position = bottom + Vector3(0, 1.0, 0) + dir
	g.add_child(splash)


# -----------------------------------------------------------------------------
# Skating: the Hollow Skate Yard, and spots round town
# -----------------------------------------------------------------------------
func _skate_yard() -> void:
	# The Hollow Skate Yard beside the school, on a big concrete pad behind a chain-link fence: the Big Vert (a tall
	# half-pipe for BIG air), a mini ramp, the gap jump (a kicker and a landing deck with a gap between), a funbox,
	# a stair set with handrails, ledges and rails, a bank, and the Skaters' Corner to swap who's riding.
	var c := YARD.get_center()
	var g := group("Hollow Skate Yard", Vector3(c.x, 0, c.y))
	_foot("Hollow Skate Yard", g.position, 0.0, YARD.size, "skate")
	var floor_y := 0.2
	var concrete := kit.mat("Concrete", 0.85)
	_solid_mesh(Vector3(YARD.size.x, floor_y, YARD.size.y), concrete, Vector3(0, floor_y / 2.0, 0), g)
	var hx := YARD.size.x / 2.0
	var hz := YARD.size.y / 2.0
	# The Big Vert at the north end: two tall quarter pipes facing each other, 4.8 m up, nearly vertical at the top
	kit.quarter_pipe(g, "Big Vert West", Vector3(-7.5, floor_y, -hz + 9.0), -PI / 2, 12.0, 4.8, 86.0, 2.0)
	kit.quarter_pipe(g, "Big Vert East", Vector3(7.5, floor_y, -hz + 9.0), PI / 2, 12.0, 4.8, 86.0, 2.0)
	# The mini ramp, middle east
	kit.quarter_pipe(g, "Mini Ramp North", Vector3(12.0, floor_y, -2.5), PI, 7.0, 1.8, 70.0, 1.5)
	kit.quarter_pipe(g, "Mini Ramp South", Vector3(12.0, floor_y, 3.5), 0.0, 7.0, 1.8, 70.0, 1.5)
	# The gap: a kicker west of the middle, a 7 m gap, then a landing deck sloping down
	kit.kicker(g, "Gap Kicker", Vector3(-hx + 2.0, floor_y, 1.0), PI / 2, 4.5, 1.9, 4.0)
	var land := kit.group(g, "Gap Landing", Vector3(-hx + 2.0 + 4.5 + 7.0, floor_y, 1.0), PI / 2)
	kit.prism(PackedVector2Array([Vector2(0, 0), Vector2(0, 1.9), Vector2(2.0, 1.9), Vector2(7.0, 0)]), 4.0, kit.mat("Kicker", 0.6), land)
	# Funbox, a stair set, a ledge, two flat rails and a kinked ground rail, a bank against the south fence
	kit.funbox(g, "Funbox", Vector3(1.0, floor_y, 6.5), PI / 2)
	kit.stairs_and_handrail(g, "Yard Stairs", Vector3(-11.0, floor_y, 13.0))
	kit.ledge(g, "Long Ledge", Vector3(4.0, floor_y, 15.0), Vector3(1, 0, 0), 10.0, 0.55)
	kit.flat_rail(g, "Flat Rail", Vector3(-2.0, floor_y, -3.5), Vector3(1, 0, 0), 9.0, 0.5)
	kit.flat_rail(g, "Long Rail", Vector3(4.0, floor_y, 10.5), Vector3(1, 0, 0), 12.0, 0.75)
	kit.prism(PackedVector2Array([Vector2(0, 0), Vector2(3.0, 1.4), Vector2(4.0, 1.4), Vector2(4.0, 0)]), 14.0, kit.mat("Ramp", 0.55),
		kit.group(g, "South Bank", Vector3(9.0, floor_y, hz - 4.2), 0.0))
	kit.skaters_corner(g, Vector3(-hx + 3.0, floor_y, hz - 3.0))
	kit.kicker(g, "Gate Ramp", Vector3(-hx - 1.6, 0, 0), PI / 2, 1.6, floor_y, 4.0)    # a little ramp up through the gate
	# The chain-link fence round it, with the gate on Main Street's side
	var fence := mat("Chain Link", Color(0.6, 0.62, 0.65), 0.4, 0.0, 0.55)
	var post := mat("Lamp Iron", Color(0.1, 0.1, 0.12), 0.5)
	for side in [[Vector3(0, 0, -hz), Vector3(YARD.size.x, 0, 0)], [Vector3(0, 0, hz), Vector3(YARD.size.x, 0, 0)],
			[Vector3(hx, 0, 0), Vector3(0, 0, YARD.size.y)]]:
		var at: Vector3 = side[0]
		var span: Vector3 = side[1]
		mesh_at(box(Vector3(maxf(span.x, 0.05), 2.4, maxf(span.z, 0.05))), fence, at + Vector3(0, 1.4, 0), g)
		solid_box(Vector3(maxf(span.x, 0.2), 2.4, maxf(span.z, 0.2)), at + Vector3(0, 1.4, 0), g)
	for z0 in [[-hz, -4.0], [4.0, hz]]:                                    # the west side, with a gate in the middle
		var len: float = z0[1] - z0[0]
		mesh_at(box(Vector3(0.05, 2.4, len)), fence, Vector3(-hx, 1.4, (z0[0] + z0[1]) / 2.0), g)
		solid_box(Vector3(0.2, 2.4, len), Vector3(-hx, 1.4, (z0[0] + z0[1]) / 2.0), g)
	for k in 9:
		for sx in [-hx, hx]:
			mesh_at(cyl(0.05, 0.05, 2.6, 6), post, Vector3(sx, 1.3, -hz + k * YARD.size.y / 8.0), g)
	var sign_post := Node3D.new()
	sign_post.position = Vector3(-hx - 0.5, 0, -5.0)
	sign_post.rotation.y = -PI / 2
	g.add_child(sign_post)
	mesh_at(box(Vector3(4.2, 1.0, 0.1)), mat("Yard Sign", Color(0.15, 0.1, 0.18), 0.6), Vector3(0, 3.1, 0), sign_post)
	label(sign_post, "HOLLOW SKATE YARD", Vector3(0, 3.1, -0.07), 44, Color(1.0, 0.6, 0.2)).rotation.y = PI
	for sx in [-1.8, 1.8]:
		mesh_at(cyl(0.06, 0.06, 3.6, 6), post, Vector3(sx, 1.8, 0), sign_post)
	# Floodlights, for skating after dark
	for p in [Vector3(-hx + 0.6, 0, -hz + 0.6), Vector3(hx - 0.6, 0, -hz + 0.6), Vector3(-hx + 0.6, 0, hz - 0.6), Vector3(hx - 0.6, 0, hz - 0.6)]:
		mesh_at(cyl(0.1, 0.14, 7.0, 8), post, p + Vector3(0, 3.5, 0), g)
		mesh_at(box(Vector3(0.8, 0.4, 0.4)), mat("Lamp Glass", Color(1.0, 0.85, 0.55), 0.3, 2.0), p + Vector3(0, 7.1, 0), g)
		lamp_light(g, p + Vector3(0, 6.8, 0) - p.normalized() * 1.5, Color(1.0, 0.92, 0.8), 2.2, 22.0)
	# Graffiti-style murals on the north wall (just colour: pumpkins and a big moon)
	var wall := mat("Yard Wall", Color(0.55, 0.55, 0.58), 0.9)
	_solid_mesh(Vector3(YARD.size.x - 2.0, 2.2, 0.4), wall, Vector3(0, 1.1 + floor_y, -hz + 0.6), g)
	mesh_at(cyl(1.0, 1.0, 0.05, 24), mat("Mural Moon", Color(0.98, 0.92, 0.6), 0.6), Vector3(-12.0, 1.5, -hz + 0.84), g, 0.0, Vector3(PI / 2, 0, 0))
	for k in 5:
		mesh_at(ball(0.5, 10), mat("Mural %d" % (k % 3), [Color(0.95, 0.5, 0.12), Color(0.6, 0.3, 0.75), Color(0.35, 0.85, 0.5)][k % 3], 0.6),
			Vector3(-6.0 + k * 3.2, 1.3, -hz + 0.84), g).scale = Vector3(1.2, 0.9, 0.1)


func _skate_spots() -> void:
	# A few more spots round town where they'd really be (the library's and school's handrails, the hardware store's
	# dock and the hill rail are with their buildings): rails along the creek path, and a kicker ramp by the
	# playground path made from an old ramp the kids left out
	var g := group("Skate Spots")
	var rail_line := [Vector2(-79, -26.5), Vector2(-87, -29.6)]
	kit.ground_rail(g, "Creek Path Rail", _on_ground(rail_line[0]), _on_ground(rail_line[1]), 0.55)
	kit.ground_rail(g, "Pond Path Rail", _on_ground(Vector2(-34, 16.8)), _on_ground(Vector2(-43, 16.8)), 0.5)
	kit.ledge(g, "Town Hall Ledge", Vector3(-30.0, 0, -16.8), Vector3(1, 0, 0), 7.0, 0.5)
	kit.kicker(g, "Pond Path Kicker", _on_ground(Vector2(-48, 9.8)), -PI / 2, 2.5, 0.9, 2.2)
	# A curb-cut rail outside the Corner Market's car park
	kit.flat_rail(g, "Market Rail", Vector3(STREET + STREET_W / 2 + 1.6 + 1.0, 0, 19.0), Vector3(0, 0, 1), 5.0, 0.45)


# -----------------------------------------------------------------------------
# Autumn and Halloween: jack-o'-lanterns, string lights, bunting, cornstalks, scarecrows, hay
# -----------------------------------------------------------------------------
func _jack(parent: Node3D, at: Vector3, r: float) -> void:
	# A jack-o'-lantern: a pumpkin with a friendly carved face that glows (always: it's that time of year)
	_pumpkin(parent, at, r)
	var glow := mat("Jack Glow", Color(1.0, 0.65, 0.15), 0.5, 3.0)
	var face := Node3D.new()
	face.position = at + Vector3(0, r * 0.75, r * 1.08)
	parent.add_child(face)
	for sx in [-1.0, 1.0]:
		mesh_at(cyl(0.0, r * 0.2, 0.02, 3), glow, Vector3(sx * r * 0.33, r * 0.18, 0), face, 0.0, Vector3(PI / 2, 0, 0))
	var smile := mesh_at(box(Vector3(r * 0.85, r * 0.16, 0.02)), glow, Vector3(0, -r * 0.2, 0), face)
	smile.name = "Smile"


func _halloween() -> void:
	# Dressing the whole town for autumn: cornstalk bundles on the street lamps round the green, jack-o'-lanterns on
	# steps and the gazebo, hay bales and scarecrows at the corners, a ghost (a friendly sheet one) in a few windows
	var g := group("Autumn Dressing")
	var stalk := mat("Cornstalk", Color(0.8, 0.68, 0.4), 0.95)
	for k in 4:
		var a := k * PI / 2
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))
		for t in [-14.0, 14.0]:
			var p: Vector3 = out * (STREET - STREET_W / 2 - 0.9) + along * t
			for q in 5:
				var off := Vector3(cos(q * 1.3), 0, sin(q * 1.3)) * 0.22
				mesh_at(cyl(0.02, 0.05, 2.2, 5), stalk, p + off + Vector3(0, 1.1, 0), g, 0.0, Vector3(off.z * 0.4, 0, -off.x * 0.4))
	# Hay bales, scarecrows and pumpkins at the green's four corners
	for k in 4:
		var a := k * PI / 2 + PI / 4
		var p := Vector3(cos(a), 0, sin(a)) * (GREEN_R + 1.8)
		if p.distance_to(PORTAL_AT) < 6.0:
			continue                                                  # (the old oak's corner has the portal)
		mesh_at(cyl(0.6, 0.6, 1.2, 16), mat("Hay", Color(0.88, 0.74, 0.38), 0.95), p + Vector3(0, 0.45, 0), g, -a, Vector3(0, 0, PI / 2))
		solid_box(Vector3(1.2, 0.9, 1.0), p + Vector3(0, 0.45, 0), g, -a)
		_jack(g, p + Vector3(0, 0.9, 0), 0.3)
		_scarecrow(g, p + Vector3(cos(a + 0.5), 0, sin(a + 0.5)) * 1.6, -a + PI / 2)
	for k in 6:                                                       # jack-o'-lanterns round the gazebo
		var a := k * TAU / 6 + 0.3
		_jack(g, Vector3(cos(a), 0, sin(a)) * 4.9, 0.25)
	# Friendly sheet ghosts in some upstairs windows on Main Street (just for fun)
	var sheet := mat("Ghost Sheet", Color(0.97, 0.97, 1.0), 0.8, 0.4)
	for spot in [[Vector3(_side(-1, 10) + 5.06, 4.0, -46 + 3.3), PI / 2], [Vector3(_side(1, 9) - 4.56, 4.2, -46 - 3.0), -PI / 2],
			[Vector3(_side(-1, 10) + 5.06, 3.9, -62 - 3.0), PI / 2]]:
		var ghost := Node3D.new()
		ghost.position = spot[0]
		ghost.rotation.y = spot[1]
		g.add_child(ghost)
		mesh_at(ball(0.35, 10), sheet, Vector3(0, 0.2, 0), ghost).scale = Vector3(1, 1.3, 0.3)
		for sx in [-0.12, 0.12]:
			mesh_at(ball(0.05, 6), mat("Ghost Eye", Color(0.1, 0.08, 0.12), 0.5), Vector3(sx, 0.3, 0.1), ghost)
	# String lights zig-zagging across Main Street and Maple Lane, and round the gazebo square; bunting over the
	# green's streets
	var orange := Color(1.0, 0.55, 0.15)
	var purple := Color(0.7, 0.35, 1.0)
	var warm := Color(1.0, 0.85, 0.5)
	var z := MAIN_Z.x - 4.0
	var side := 1.0
	while z > MAIN_Z.y + 6.0:
		_string(Vector3(-side * (STREET_W / 2 + 0.9), 4.6, z), Vector3(side * (STREET_W / 2 + 0.9), 4.6, z - 8.0), [orange, purple, warm])
		z -= 8.0
		side = -side
	var x := HOLLOW_X - 8.0
	while x > -90.0:
		_string(Vector3(x, 4.4, MAPLE_Z - (STREET_W / 2 + 0.9)), Vector3(x - 10.0, 4.4, MAPLE_Z + (STREET_W / 2 + 0.9)), [orange, warm])
		x -= 10.0
	for k in 4:
		var a := k * PI / 2
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2))
		var p: Vector3 = out * (STREET - STREET_W / 2 - 0.9)
		_bunting(p - along * 14.0 + Vector3(0, 4.2, 0), p + Vector3(0, 4.2, 0) + out * (STREET_W + 1.8) * 0.0)
		_bunting(p + Vector3(0, 4.2, 0), p + along * 14.0 + Vector3(0, 4.2, 0))


func _string(a: Vector3, b: Vector3, cols: Array, sag := 0.6) -> void:
	# A string of bulbs from a to b, sagging a little in the middle
	var n := int(a.distance_to(b) / 0.6)
	for k in n + 1:
		var t := float(k) / n
		bulbs.append([a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0), cols[k % cols.size()]])


func _bunting(a: Vector3, b: Vector3) -> void:
	# A line of little triangle flags in orange, purple, black and cream
	var cols := [Color(0.95, 0.5, 0.12), Color(0.5, 0.25, 0.65), Color(0.12, 0.1, 0.12), Color(0.96, 0.92, 0.8)]
	var n := int(a.distance_to(b) / 0.7)
	var d := b - a
	for k in n + 1:
		var t := float(k) / n
		flags.append([a.lerp(b, t) - Vector3(0, 0.5 * 4.0 * t * (1.0 - t), 0), atan2(d.x, d.z), cols[k % cols.size()]])


func _strings_and_bunting() -> void:
	# All the bulbs as one MultiMesh (glowing, coloured per bulb) and all the flags as another: thousands of little
	# things for the price of two
	var g := group("String Lights")
	var bulb := SphereMesh.new()
	bulb.radius = 0.11
	bulb.height = 0.22
	bulb.radial_segments = 6
	bulb.rings = 3
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.emission_enabled = true
	bm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	bm.emission = Color(1, 1, 1)
	bm.emission_energy_multiplier = 3.0
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := multi("Bulbs", bulb, bulbs.map(func(b: Array) -> Transform3D: return Transform3D(Basis(), b[0])),
		bulbs.map(func(b: Array) -> Color: return b[1]), bm)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	var flag := PrismMesh.new()
	flag.size = Vector3(0.35, 0.45, 0.02)
	var flm := StandardMaterial3D.new()
	flm.vertex_color_use_as_albedo = true
	flm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flm.roughness = 0.8
	g.add_child(multi("Bunting", flag, flags.map(func(f: Array) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, f[1] + PI / 2) * Basis(Vector3.RIGHT, PI), f[0] - Vector3(0, 0.22, 0))),
		flags.map(func(f: Array) -> Color: return f[2]), flm))


# -----------------------------------------------------------------------------
# The town map (scripts/map_screen.gd draws it from this)
# -----------------------------------------------------------------------------
func _write_map() -> void:
	var r2 := func(v: float) -> float: return snappedf(v, 0.1)
	var streets := []
	for rd in roads:
		streets.append([r2.call(rd[0].x), r2.call(rd[0].y), r2.call(rd[1].x), r2.call(rd[1].y), rd[2], rd[3]])
	var buildings := []
	for f in feet:
		buildings.append([f.label, r2.call(f.at.x), r2.call(f.at.y), r2.call(f.size.x), r2.call(f.size.y), snappedf(f.yaw, 0.001), f.kind])
	var creek := []
	for p in EarthLand.CREEK:
		creek.append([p.x, p.y])
	var labels := []
	for s in spots:
		labels.append([s[0], r2.call(s[1].x), r2.call(s[1].y)])
	labels.append(["Main Street", 0.0, -78.0])
	labels.append(["Maple Lane", -50.0, MAPLE_Z])
	labels.append(["The Green", 0.0, 0.0])
	var data := {
		"bounds": [BOUNDS.position.x, BOUNDS.position.y, BOUNDS.end.x, BOUNDS.end.y],
		"green": [0.0, 0.0, GREEN_R],
		"streets": streets,
		"buildings": buildings,
		"pond": [EarthLand.POND.x, EarthLand.POND.y, EarthLand.POND.z, EarthLand.POND.w],
		"creek": creek,
		"creek_width": EarthLand.CREEK_HALF * 2.0,
		"pool": [EarthLand.FALLS_POOL.x, EarthLand.FALLS_POOL.z, 5.0],
		"hill": [EarthLand.HILL.x, EarthLand.HILL.y, EarthLand.HILL_FLAT, EarthLand.HILL_FLAT + EarthLand.HILL_SLOPE],
		"rolls": EarthLand.ROLLS.map(func(r: Vector4) -> Array: return [r.x, r.y, r.z, r.w]),
		"portal": [PORTAL_AT.x, PORTAL_AT.z],
		"labels": labels,
	}
	var f := FileAccess.open(MAP_OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t") + "\n")
	f.close()
	print("SAVED ", MAP_OUT, " (", buildings.size(), " places)")


# -----------------------------------------------------------------------------
# Where people go: the named places of the town and the links they walk along (res://routines/earth_places.json,
# read by scripts/town_paths.gd for everyone's routine). Made here so it always matches the buildings.
# -----------------------------------------------------------------------------
var places := {}                                   # name -> [x, z] or [x, z, floor height]
var place_links := []


func _at(n: Node3D) -> Vector3:
	# Where a node in the town ends up (it isn't in a tree yet, so add up the transforms by hand)
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p and p != world:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t.origin


func _place(name: String, p: Vector2, floor_y := NAN) -> void:
	places[name] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01)] if is_nan(floor_y) else \
		[snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(floor_y, 0.01)]


func _walk(names: Array) -> void:
	for i in names.size() - 1:
		place_links.append([names[i], names[i + 1]])


func _rooms(building: String, prefix: String) -> void:
	# A walk-in building's doorstep and middle ("<prefix>_door", "<prefix>"), joined
	var b := world.get_node(building) as Node3D
	var door := _at(b.get_node("Doorway") as Node3D)
	var inside := _at(b.get_node("Inside") as Node3D)
	_place(prefix + "_door", Vector2(door.x, door.z), b.position.y if b.position.y > 0.1 else NAN)
	_place(prefix, Vector2(inside.x, inside.z), b.position.y)
	_walk([prefix + "_door", prefix])


func _write_places() -> void:
	var g := STREET
	# Round the green, on the street, and across the grass to the gazebo's steps and the old oak
	for k in 8:
		var names := ["green_e", "green_se", "green_s", "green_sw", "green_w", "green_nw", "green_n", "green_ne"]
		var a := k * PI / 4
		var r := g if k % 2 == 0 else g * sqrt(2.0)
		_place(names[k], Vector2(cos(a), sin(a)) * r)
	_walk(["green_e", "green_se", "green_s", "green_sw", "green_w", "green_nw", "green_n", "green_ne", "green_e"])
	_place("gazebo", Vector2(0, 8.0))
	_place("old_oak", Vector2(PORTAL_AT.x + 4.5, PORTAL_AT.z + 4.5))
	_place("green_bench", Vector2(10.5, 10.5))
	_walk(["green_s", "gazebo", "old_oak", "green_s"])
	_walk(["gazebo", "green_bench", "green_se"])
	# The Autumn Festival (Saturday evenings): round the gazebo from its steps, and beside each stall
	var ring := ["gazebo"]
	for what in FESTIVAL:
		var a := deg_to_rad(float(FESTIVAL[what]))
		_place("fest_" + what, Vector2(cos(a), sin(a)) * 7.3)
		ring.append("fest_" + what)
		if what != "hay":
			var b := a + deg_to_rad(15.0)
			_place("fest_%s_stall" % what, Vector2(cos(b), sin(b)) * 9.6)
			_walk(["fest_" + what, "fest_%s_stall" % what])
	_walk(ring)
	# The shops round the green (their fronts) and the walk-in Town Hall
	var front := g + STREET_W / 2 + 1.6 + 0.3
	_place("diner", Vector2(-9, -front))
	_place("bookshop", Vector2(9, -front))
	_place("market", Vector2(front, -8))
	_place("inn", Vector2(front, 9))
	_place("home_1", Vector2(-14, front))
	_place("home_3", Vector2(14, front))
	_walk(["green_nw", "diner", "green_n", "bookshop", "green_ne"])
	_walk(["green_ne", "market", "green_e", "inn", "green_se"])
	_walk(["green_sw", "home_1", "green_s", "home_3", "green_se"])
	_rooms("Earth Town Hall", "town_hall")
	_walk(["green_w", "town_hall_door"])
	# Main Street, its shops and the school at the top; the skate yard through its gate
	var main := []
	for z in [-30, -46, -62, -73, -84, -94, -104, -116]:
		_place("main_%d" % -z, Vector2(0, z))
		main.append("main_%d" % -z)
	_walk(["green_n"] + main)
	_rooms("Bakery", "bakery")
	_rooms("Toy Shop", "toy_shop")
	_rooms("Library", "library")
	_walk(["main_46", "bakery_door"])
	_walk(["main_62", "toy_shop_door"])
	_place("library_steps", Vector2(-5.2, -84))
	_walk(["main_84", "library_steps", "library_door"])
	_place("antiques", Vector2(4.9, -46))
	_place("hardware", Vector2(4.9, -62.5))
	_place("fire_station", Vector2(-6.5, -106.5))
	_place("school", Vector2(5.0, -119.5))
	_place("skate_gate", Vector2(8.0, -96.9))
	_place("skate_in", Vector2(11.5, -96.9), YARD_FLOOR)         # (through the gate, beside the gate ramp)
	_place("skate_yard", Vector2(14.5, -92.5), YARD_FLOOR)
	_walk(["main_46", "antiques"])
	_walk(["main_62", "hardware"])
	_walk(["main_104", "fire_station"])
	_walk(["main_116", "school"])
	_walk(["main_94", "skate_gate", "skate_in", "skate_yard"])
	# Hollow Lane down to Maple Lane, and along it (over the covered bridge to the pumpkin patch)
	_place("hollow_top", Vector2(HOLLOW_X, 27))
	_place("hollow_mid", Vector2(HOLLOW_X, 42))
	var lane := [16, 8, -10, -26, -40, -44, -62, -70, -84, -94, -112, -120]
	for x in lane:
		_place("maple_%s" % (("w%d" % -x) if x < 0 else str(x)), Vector2(x, MAPLE_Z))
	var lane_names := lane.map(func(x: int) -> String: return "maple_%s" % (("w%d" % -x) if x < 0 else str(x)))
	_walk(lane_names)
	_walk(["green_sw", "hollow_top", "hollow_mid", "maple_w26"])
	# The houses: the gate in each front fence, and the porch
	var north_z := MAPLE_Z - (STREET_W / 2 + 1.6 + 5.0 + 3.5)
	var south_z := MAPLE_Z + (STREET_W / 2 + 1.6 + 5.0 + 3.5)
	for h in [["palmer_house", -62, north_z + 4.6, "maple_w62"], ["hollis_house", -84, north_z + 4.6, "maple_w84"],
			["okafor_house", -44, north_z + 4.6, "maple_w44"], ["larkspur_house", 8, north_z + 4.6, "maple_8"],
			["quill_house", -70, south_z - 4.6, "maple_w70"], ["pemberton_house", -10, south_z - 4.6, "maple_w10"],
			["bramblewood_house", 16, south_z - 4.6, "maple_16"]]:
		_place(h[0], Vector2(h[1], h[2]))
		_walk([h[3], h[0]])
	_place("palmer_porch", Vector2(-59.8, north_z + 4.6))
	_walk(["palmer_house", "palmer_porch"])
	# The Blastoffs': in through the front door, and into each bedroom through its own door
	_rooms("Blastoff House", "blastoff")
	_walk(["maple_w40", "blastoff_door"])
	var house := world.get_node("Blastoff House") as Node3D
	for who in ["Nina", "Prue", "Bruno"]:
		var room := house.get_node("%s's Room" % who) as Node3D
		var c := _at(room)
		var id := "%s_room" % who.to_lower()
		_place(id + "_door", Vector2(c.x, (house.transform * Vector3(room.position.x, 0, -0.5)).z), 0.0)
		_place(id, Vector2(c.x, c.z), 0.0)
		_walk(["blastoff", id + "_door", id])
	# The park: past the Town Hall to the pond's dock and the playground; north over the footbridge to the hill
	_place("park_gate", Vector2(-25, 14))
	_place("park_fork", Vector2(-45, 14))
	_place("pond_path", Vector2(-58.5, 10.5))
	_place("dock", Vector2(-64.5, 0.0), 0.25)
	_place("playground", Vector2(-52.5, 25.0))
	_walk(["green_sw", "park_gate", "park_fork", "pond_path", "dock"])
	_walk(["park_fork", "playground"])
	_place("north_path", Vector2(-25, -14))
	_place("north_path_2", Vector2(-45, -18))
	_place("north_path_3", Vector2(-70, -28))
	_place("footbridge_e", Vector2(-90.5, -36))
	_place("footbridge_w", Vector2(-100.5, -38.5), 0.6)
	_place("hill_path", Vector2(-112, -46))
	_place("hill_foot", Vector2(-118, -66))
	_place("hill_top", Vector2(-112, -87))
	_walk(["green_nw", "north_path", "north_path_2", "north_path_3", "footbridge_e", "footbridge_w", "hill_path", "hill_foot",
		"hill_top"])
	_place("pumpkin_patch", Vector2(-119, 31))
	_walk(["maple_w120", "pumpkin_patch"])
	# A look for anything a link crosses that it shouldn't: water, or a building that isn't its own door's
	for l in place_links:
		var a := Vector2(places[l[0]][0], places[l[0]][1])
		var b := Vector2(places[l[1]][0], places[l[1]][1])
		for k in 21:
			var p := a.lerp(b, k / 20.0)
			if EarthLand.is_water(p.x, p.y) and not "footbridge" in str(l) and not "dock" in str(l) and not "w94" in str(l) \
					and not "w112" in str(l):
				push_warning("Path %s - %s crosses water at %s" % [l[0], l[1], p])
				break
	var f := FileAccess.open(PLACES_OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"points": places, "links": place_links}, "\t") + "\n")
	f.close()
	print("SAVED ", PLACES_OUT, " (", places.size(), " places, ", place_links.size(), " links)")
