extends SceneTree

# Builds res://scenes/town/town.tscn: a walkable blockout of the town, laid out from
# source_art/reference/world/town - map with labels.jpg (lake in the middle, castle school on the hill to the north).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_town.gd
#
# Units are meters. +X is east, -Z is north (toward the castle). Every placement below is a plain number to tweak.

const OUT_DIR := "res://scenes/town"
const OUT := OUT_DIR + "/town.tscn"

# Terrain extent and resolution
const X_MIN := -150.0
const X_MAX := 150.0
const Z_MIN := -260.0
const Z_MAX := 110.0
const STEP := 2.0

# Lake: two ellipses (main lake + north channel), water surface height and basin depth
const LAKE_MAIN := Vector4(0, 0, 40, 17)        # center x, center z, radius x, radius z
const LAKE_NORTH := Vector4(-5, -32, 34, 7)
const WATER_Y := -0.6
const BASIN_DEPTH := 1.6

# Raised ground
const PLATEAU := Vector3(-78, -42, 12)           # Secret Gardens / Hot Springs plateau: x, z, height
const PLATEAU_CLIFF := 33.0                      # cliff radius
const PLATEAU_RAMP := Vector2(-0.6, 0.8)         # direction of the walkable ramp up (southwest)
const CASTLE_HILL := Vector3(15, -150, 16)       # school hill: x, z, height
const CASTLE_HILL_TOP := 62.0                    # flat top radius: Bojnice Castle is real size, 89 x 106 m
const CASTLE_HILL_FOOT := 98.0                   # where the hill meets the town (clear of the north shore shops)
const BOJNICE := "res://tools/bojnice_footprint.json"   # the castle's real footprint (tools/fetch_bojnice.py)
const CASTLE_YAW := PI                           # Bojnice's gate faces north: turned round to face the town
const CASTLE_RAMP := Vector2(-0.124, 0.992)       # the castle rock is a cliff all round except a ramp down this way
const CASTLE_FALLS := [57.0, 137.0]               # degrees round the rock (0 = east, 90 = south): a waterfall at each
const CASTLE_POND := Vector3(76.0, 10.0, 7.0)     # each fall's pond: distance from the hill's middle, radius x, z
const TOWN_SQUARE := Vector3(-12, -21, 10)       # x, z, radius (land between the two lakes)

const SPAWN := Vector3(-72, 0, 80)               # where she appears in town without a door: the market's south entrance

# The town's districts (see C:/Users/hggru/Game_dev/town-plan): the Market Square at the foot of the spa plateau, the
# housing district east of the lake, Sports & Play to the southeast, the Observatory on its own hill to the northeast.
const MARKET := Vector3(-72, 42, 22)              # x, z, plaza radius
const MARKET_RING := 27.0                         # the shops stand round it this far from the fountain
const HOUSING := Vector3(80, 0, 34)               # x, z (its little park), hedge radius
const OBS_HILL := Vector3(105, -88, 16)           # x, z, height
const OBS_HILL_TOP := 10.0
const OBS_HILL_FOOT := 42.0
const SKATE := Vector2(50, 58)
const MOTHERSHIP_PAD := Vector2(118, -42)          # x, z: open ground just east of the Observatory path
# Main paths, painted on the ground: polylines of (x, z)
const MAIN_PATHS := [
	[Vector2(-72, 78), Vector2(-72, 64)],
	[Vector2(-50, 42), Vector2(-26, 23), Vector2(-7, 22), Vector2(22, 20), Vector2(36, 15), Vector2(52, 2), Vector2(70, 2)],
	[Vector2(-12, -42), Vector2(4, -62), Vector2(20, -82), Vector2(35, -93)],
	[Vector2(-7, 22), Vector2(12, 48), Vector2(38, 56), Vector2(80, 50), Vector2(122, 58)],
	[Vector2(88, -32), Vector2(97, -54), Vector2(97, -76)],
	[Vector2(80, 8), Vector2(78, 26), Vector2(76, 46)],
	[Vector2(90, -4), Vector2(93, -20), Vector2(88, -32)],
	[Vector2(-94, 42), Vector2(-110, 30), Vector2(-108, 8)],
	[Vector2(-72, 30), Vector2(-92, 24), Vector2(-108, 8)],
	[Vector2(-12, -42), Vector2(-60, -82), Vector2(-100, -116)],
]

# Tall grass meadows: x, z, radius (tools/build_town.gd _foliage; drawn and made to rustle by scenes/town/foliage.gd)
const GRASS_PATCHES := [Vector3(10, 58, 11), Vector3(-30, 90, 10), Vector3(-118, 66, 10), Vector3(70, -64, 9),
	Vector3(118, 24, 8), Vector3(84, -26, 6), Vector3(-10, 76, 8), Vector3(118, -20, 7)]

# Look of the world. THEME comes from tools/theme.gd (shared with the school and interiors builders): set it to
# "earth" there for the original blue-sky town. The table below is the town's own sky/terrain/water/tree palette;
# everything else (buildings, signs, props) goes through WT.tint().
const WT := preload("res://tools/theme.gd")
const THEME: String = WT.THEME
const THEMES := {
	"earth": {
		"sky_top": Color(0.22, 0.55, 0.95), "sky_horizon": Color(0.7, 0.85, 1.0), "sky_bottom": Color(0.35, 0.5, 0.3),
		"sun": Color(1, 1, 1), "sun_energy": 1.0, "fog": false, "fog_color": Color(), "fog_density": 0.0,
		"grass": Color(0.36, 0.72, 0.27), "hill_grass": Color(0.3, 0.62, 0.24), "sand": Color(0.88, 0.8, 0.58),
		"path": Color(0.86, 0.82, 0.7), "rock": Color(0.55, 0.53, 0.5), "far_grass": Color(0.33, 0.6, 0.27),
		"water": Color(0.12, 0.55, 0.92), "water_glow": 0.0,
		"mountain_far": Color(0.42, 0.5, 0.68), "mountain_near": Color(0.38, 0.55, 0.45), "mountain_sides": 10,
		"trees": [Color(0.2, 0.6, 0.25), Color(0.25, 0.7, 0.3), Color(0.55, 0.3, 0.75), Color(0.9, 0.45, 0.7),
			Color(0.95, 0.6, 0.2), Color(0.18, 0.5, 0.3)],
		"bark": Color(0.45, 0.3, 0.18), "tree_glow": 0.0, "canopy_stretch": 1.15,
		"moons": false, "crystals": 0,
	},
	"alien": {
		# A green midday sky fading to a pale lime-yellow horizon (source_art/reference/world/sky - green midday with
		# mothership.png), a pinkish sun, and a light violet haze over the land
		"sky_top": Color(0.2, 0.6, 0.3), "sky_horizon": Color(0.86, 0.93, 0.6), "sky_bottom": Color(0.1, 0.04, 0.18),
		"sun": Color(1.0, 0.78, 0.7), "sun_energy": 1.15, "fog": true, "fog_color": Color(0.62, 0.38, 0.8),
		"fog_density": 0.0018,
		# Teal moss, blue-violet hills, pink sand, lavender paths, dark indigo rock
		"grass": Color(0.05, 0.48, 0.47), "hill_grass": Color(0.2, 0.26, 0.62), "sand": Color(0.9, 0.55, 0.75),
		"path": Color(0.74, 0.68, 0.9), "rock": Color(0.24, 0.18, 0.36), "far_grass": Color(0.08, 0.42, 0.46),
		# Glowing acid-green lake
		"water": Color(0.3, 1.0, 0.55), "water_glow": 0.6,
		# Faceted dark crystal mountains
		"mountain_far": Color(0.2, 0.12, 0.4), "mountain_near": Color(0.34, 0.12, 0.44), "mountain_sides": 5,
		# Tall glowing pods in magenta, cyan, lime, orange and violet on dark stalks
		"trees": [Color(0.95, 0.22, 0.65), Color(0.15, 0.9, 0.85), Color(0.6, 0.95, 0.2), Color(1.0, 0.55, 0.12),
			Color(0.58, 0.3, 1.0)],
		"bark": Color(0.2, 0.14, 0.26), "tree_glow": 0.45, "canopy_stretch": 1.7,
		# A ringed planet and two moons in the sky, and glowing crystal clusters across the land
		"moons": true, "crystals": 46,
	},
}
var T: Dictionary = THEMES[THEME]

var town: Node3D
var mats := {}
var castle_faces := PackedVector3Array()   # the castle's walls and roofs, for its collision
var castle_outline := PackedVector2Array()  # the castle's outline in town coordinates (x, z)
var castle_spots: Array[Vector3] = []        # x, z, radius: its domed halls, kept clear of the gardens
var castle_gate := Vector3.ZERO              # where she stands in front of the gate
var keep_clear: Array = []      # circles (x, z, r) where no trees are scattered


func _initialize() -> void:
	town = Node3D.new()
	town.name = "Town"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build()
	var scene := PackedScene.new()
	var err := scene.pack(town)
	var save_err := ResourceSaver.save(scene, OUT)
	print("SAVED ", OUT, " pack=", err, " save=", save_err)
	town.free()
	quit()


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func save_external(res: Resource, file: String) -> void:
	# Big generated data lives in its own binary file so town.tscn stays small and readable
	var path := OUT_DIR + "/" + file
	ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
	res.take_over_path(path)


func own(n: Node) -> void:
	if n != town:
		n.owner = town
	if n != town and n.scene_file_path != "":
		return                                    # instanced scene: keep it a reference, not a copy
	for c in n.get_children():
		own(c)


func add(n: Node, parent: Node = null) -> Node:
	(parent if parent else town).add_child(n)
	own(n)
	return n


func mat(name: String, color: Color, rough := 0.85, metal := 0.0, emit := 0.0, alpha := 1.0, themed := true) -> StandardMaterial3D:
	# themed: buildings and props get the shared palette; pass false for colours already chosen from THEMES
	if mats.has(name):
		return mats[name]
	if themed:
		color = WT.tint(color)
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


func mesh_at(mesh: Mesh, material: Material, pos: Vector3, parent: Node, yaw := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	parent.add_child(mi)
	return mi


func solid(shape: Shape3D, pos: Vector3, parent: Node, yaw := 0.0, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func cylinder(top: float, bottom: float, h: float, segments := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	return c


func sphere(r: float, h := -1.0, segments := 32) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0 else r * 2
	s.radial_segments = segments
	s.rings = segments / 2
	return s


func group(name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation.y = yaw
	town.add_child(g)
	return g


# -----------------------------------------------------------------------------
# Terrain height
# -----------------------------------------------------------------------------
func ellipse(e: Vector4, x: float, z: float) -> float:
	return pow((x - e.x) / e.z, 2) + pow((z - e.y) / e.w, 2)


func lake_f(x: float, z: float) -> float:
	# < 1 inside the lake, > 1 on land
	var f := minf(ellipse(LAKE_MAIN, x, z), ellipse(LAKE_NORTH, x, z))
	var d_sq := Vector2(x - TOWN_SQUARE.x, z - TOWN_SQUARE.y).length() / TOWN_SQUARE.z
	if d_sq < 1.3:
		f = maxf(f, 1.0 + 0.6 * (1.3 - d_sq))       # the town square is dry land between the lakes
	for pond in castle_ponds():
		f = minf(f, ellipse(pond, x, z))
	return f


func castle_ponds() -> Array[Vector4]:
	# The ponds the castle's waterfalls fall into, at the foot of its cliff (as lake ellipses)
	var out: Array[Vector4] = []
	for deg in CASTLE_FALLS:
		var d := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))
		var c := Vector2(CASTLE_HILL.x, CASTLE_HILL.y) + d * CASTLE_POND.x
		out.append(Vector4(c.x, c.y, CASTLE_POND.y, CASTLE_POND.z))
	return out


func height(x: float, z: float) -> float:
	var h := 0.35 * sin(x * 0.07) * cos(z * 0.05)
	var f := lake_f(x, z)
	h = lerpf(h, -BASIN_DEPTH, ss(1.25, 0.85, f))
	# Plateau: a cliff all round (for the caves and waterfalls), except a gentle ramp up on its southwest side
	var v := Vector2(x - PLATEAU.x, z - PLATEAU.y)
	var dp := v.length()
	var ramp := ss(0.8, 0.95, v.normalized().dot(PLATEAU_RAMP)) if dp > 0.01 else 0.0
	h += PLATEAU.z * (1.0 - ss(lerpf(PLATEAU_CLIFF - 3.0, 24.0, ramp), lerpf(PLATEAU_CLIFF + 2.0, 62.0, ramp), dp))
	# Castle rock: a cliff all round (with the waterfalls), except the ramp up from the town
	var vc := Vector2(x - CASTLE_HILL.x, z - CASTLE_HILL.y)
	var dc := vc.length()
	var cramp := ss(0.8, 0.95, vc.normalized().dot(CASTLE_RAMP)) if dc > 0.01 else 0.0
	h += CASTLE_HILL.z * (1.0 - ss(CASTLE_HILL_TOP + 1.0, lerpf(CASTLE_HILL_TOP + 7.0, CASTLE_HILL_FOOT, cramp), dc))
	var dob := Vector2(x - OBS_HILL.x, z - OBS_HILL.y).length()
	h += OBS_HILL.z * (1.0 - ss(OBS_HILL_TOP, OBS_HILL_FOOT, dob))
	return h


func on_path(x: float, z: float, width := 1.8) -> bool:
	# Close to one of the main paths (painted on the ground, MAIN_PATHS)
	var p := Vector2(x, z)
	for line in MAIN_PATHS:
		for k in line.size() - 1:
			var a: Vector2 = line[k]
			var b: Vector2 = line[k + 1]
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) < width:
				return true
	return false


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
func _build() -> void:
	_environment()
	_terrain()
	_far_ground()
	_water()
	_bounds()
	_town_square()
	_boardwalks()
	_market()
	_housing()
	_buildings()
	_castle()
	_plateau_features()
	_castle_grounds()
	_towers()
	_courts()
	_skate_park()
	_sports_sign()
	_boats()
	_town_hall()
	_haunted_house()
	_old_slide()
	_scary_gate()
	_antique_car()
	_welcome_sign()
	_portal()
	_tree_house()
	_rock_wall()
	_cloud_nest()
	_bubble_bath()
	_park_mural()
	_soccer_field()
	_cloud_slide()
	_happy_places()
	_signposts()
	_rex_campaign()
	_town_quests()
	_sparkles()
	_shops()
	_mountains()
	_sky_objects()
	_mothership()
	_characters()
	_trees()
	_foliage()
	_crystals()
	_enemies()
	_player()


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = T.sky_top
	sky_mat.sky_horizon_color = T.sky_horizon
	sky_mat.ground_horizon_color = T.sky_horizon
	sky_mat.ground_bottom_color = T.sky_bottom
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if THEME == "alien":
		# Half the ambient light from a soft lilac instead of the sky, so the green sky doesn't turn everything green
		env.ambient_light_sky_contribution = 0.5
		env.ambient_light_color = Color(0.85, 0.72, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	if T.fog:
		env.fog_enabled = true
		env.fog_light_color = T.fog_color
		env.fog_density = T.fog_density
		env.fog_sky_affect = 0.0
		env.glow_intensity = 1.1
		env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = T.sun
	sun.light_energy = T.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add(sun)
	# Day and night from the game clock: moves the sun, darkens the sky, turns on the lamps (scripts/day_night.gd).
	# The colours above are the noon look it starts from.
	var day_night := Node.new()
	day_night.name = "DayNight"
	day_night.set_script(load("res://scripts/day_night.gd"))
	add(day_night)


func night_light(parent: Node, pos: Vector3, color: Color, energy := 1.2, rng := 7.0) -> OmniLight3D:
	# A lamp's light: off in the day, on at night (scripts/day_night.gd switches the "night_lights" group)
	var l := OmniLight3D.new()
	l.name = "NightLight"
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.add_to_group("night_lights", true)
	parent.add_child(l)
	return l


func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int((X_MAX - X_MIN) / STEP) + 1
	var nz := int((Z_MAX - Z_MIN) / STEP) + 1
	var grass: Color = T.grass
	var hill_grass: Color = T.hill_grass
	var sand: Color = T.sand
	var path: Color = T.path
	var rock: Color = T.rock
	for j in nz:
		for i in nx:
			var x := X_MIN + i * STEP
			var z := Z_MIN + j * STEP
			var h := height(x, z)
			var f := lake_f(x, z)
			var slope := Vector2(height(x + 1, z) - height(x - 1, z), height(x, z + 1) - height(x, z - 1)).length() / 2.0
			var c := grass.lerp(hill_grass, clampf(h / 12.0, 0.0, 1.0))
			if f < 1.12:
				c = sand
			elif f < 1.32 or on_path(x, z):
				c = path                               # shoreline promenade, and the main paths
			if slope > 0.55:
				c = c.lerp(rock, clampf((slope - 0.55) * 3.0, 0.0, 1.0))
			st.set_color(c)
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, h, z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	st.generate_normals()
	var mesh := st.commit()
	save_external(mesh, "terrain_mesh.res")
	var shape := mesh.create_trimesh_shape()
	save_external(shape, "terrain_shape.res")
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	var g := group("Terrain", Vector3.ZERO)
	var mi := mesh_at(mesh, m, Vector3.ZERO, g)
	mi.name = "Ground"
	solid(shape, Vector3.ZERO, g).name = "GroundCollision"
	own(g)


func _far_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var g := group("Far Ground", Vector3.ZERO)
	mesh_at(plane, mat("Far Grass", T.far_grass, 1.0, 0.0, 0.0, 1.0, false), Vector3(0, -0.8, -60), g)
	own(g)


func _water() -> void:
	var g := group("Lake", Vector3.ZERO)
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 90)
	mesh_at(plane, mat("Water", T.water, 0.05, 0.2, T.water_glow, 0.82, false), Vector3(-2, WATER_Y, -10), g).name = "Water"
	# She can wade into it: slower, splashy steps, ripples (scripts/water.gd)
	g.set_script(load("res://scripts/water.gd"))
	var outline: Array[Vector4] = [LAKE_MAIN, LAKE_NORTH]
	g.set("ellipses", outline)
	g.set("water_y", WATER_Y)
	own(g)


func soft_zone(parent: Node3D, kind: String, pos: Vector3, r: float, h: float, color: Color, speed_scale: float,
		gravity_scale: float, fall_cap: float, heal_every := 0.0) -> Area3D:
	# A walk-through place (scripts/soft_zone.gd): a cylinder r wide and h tall standing on pos
	var z := Area3D.new()
	z.name = kind.capitalize() + "Zone"
	z.set_script(load("res://scripts/soft_zone.gd"))
	z.set("kind", kind)
	z.set("color", color)
	z.set("speed_scale", speed_scale)
	z.set("gravity_scale", gravity_scale)
	z.set("fall_cap", fall_cap)
	z.set("heal_every", heal_every)
	z.monitorable = false
	z.position = pos + Vector3(0, h / 2.0, 0)
	var cs := CollisionShape3D.new()
	cs.shape = _cyl_shape(r, h)
	z.add_child(cs)
	parent.add_child(z)
	return z


func cloud_zone(parent: Node3D, top: Vector3, r: float) -> void:
	# The fluffy part of a cloud above its firm floor: floaty and soft (land with a "fwump", little puffs)
	soft_zone(parent, "cloud", top - Vector3(0, 0.3, 0), r + 0.3, 2.6, Color(1, 1, 1, 0.85), 0.75, 0.55, 5.0)


func _bounds() -> void:
	# Invisible walls so she can't walk off the edge of the world
	var g := group("WorldBounds", Vector3.ZERO)
	var h := 60.0
	var w := X_MAX - X_MIN
	var d := Z_MAX - Z_MIN
	var cx := (X_MIN + X_MAX) / 2
	var cz := (Z_MIN + Z_MAX) / 2
	solid(box_shape(Vector3(w, h, 2)), Vector3(cx, h / 2 - 5, Z_MIN + 4), g)
	solid(box_shape(Vector3(w, h, 2)), Vector3(cx, h / 2 - 5, Z_MAX - 4), g)
	solid(box_shape(Vector3(2, h, d)), Vector3(X_MIN + 4, h / 2 - 5, cz), g)
	solid(box_shape(Vector3(2, h, d)), Vector3(X_MAX - 4, h / 2 - 5, cz), g)
	own(g)


func sign_post(parent: Node, text: String, pos: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.name = "Sign"
	s.position = pos
	s.rotation.y = yaw
	parent.add_child(s)
	var wood := mat("Sign Wood", Color(0.42, 0.25, 0.13))
	var width := maxf(2.2, text.length() * 0.32 + 0.8)
	mesh_at(cylinder(0.08, 0.08, 2.0, 8), wood, Vector3(0, 1.0, 0), s)
	mesh_at(box(Vector3(width, 0.9, 0.12)), wood, Vector3(0, 2.1, 0), s)
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = Color(1, 0.97, 0.88)
	label.outline_modulate = Color(0.25, 0.13, 0.05)
	label.position = Vector3(0, 2.1, 0.07)
	s.add_child(label)


func _town_square() -> void:
	var c := ground(TOWN_SQUARE.x, TOWN_SQUARE.y)
	var g := group("TownSquare", c)
	var stone := mat("Plaza Stone", Color(0.85, 0.8, 0.72))
	mesh_at(cylinder(TOWN_SQUARE.z - 1, TOWN_SQUARE.z - 1, 1.0, 48), stone, Vector3(0, -0.4, 0), g)
	solid(_cyl_shape(TOWN_SQUARE.z - 1, 1.0), Vector3(0, -0.4, 0), g)
	# Fountain
	mesh_at(cylinder(2.6, 2.8, 0.8, 32), mat("Fountain Stone", Color(0.75, 0.72, 0.68)), Vector3(0, 0.4, 0), g)
	solid(_cyl_shape(2.8, 0.8), Vector3(0, 0.4, 0), g)
	mesh_at(cylinder(2.3, 2.3, 0.1, 32), mat("Water", Color()), Vector3(0, 0.75, 0), g)
	mesh_at(cylinder(0.35, 0.45, 2.4, 16), mat("Fountain Stone", Color()), Vector3(0, 1.6, 0), g)
	mesh_at(sphere(0.7), mat("Fountain Water", Color(0.6, 0.85, 1.0), 0.1, 0.0, 0.6, 0.7), Vector3(0, 2.9, 0), g)
	sign_post(g, "Island Park", Vector3(0, 0, 6.5), 0.0)
	keep_clear.append(Vector3(TOWN_SQUARE.x, TOWN_SQUARE.y, TOWN_SQUARE.z + 2))
	own(g)


func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c


func boardwalk(name: String, a: Vector2, b: Vector2, width := 3.0) -> void:
	var g := group(name, Vector3.ZERO)
	var wood := mat("Boardwalk", Color(0.62, 0.45, 0.28))
	var post_mat := mat("Boardwalk Post", Color(0.45, 0.3, 0.18))
	var lamp := mat("Lamp", Color(1.0, 0.92, 0.6), 0.3, 0.0, 2.0)
	var dir := (b - a)
	var length := dir.length()
	var yaw := atan2(dir.x, dir.y)
	var mid := (a + b) / 2
	var y := 0.15
	mesh_at(box(Vector3(width, 0.3, length)), wood, Vector3(mid.x, y, mid.y), g, yaw)
	solid(box_shape(Vector3(width, 0.3, length)), Vector3(mid.x, y, mid.y), g, yaw)
	var n := int(length / 4.0)
	for k in n + 1:
		var p := a + dir * (float(k) / n)
		var side := Vector2(cos(yaw), -sin(yaw)) * (width / 2)
		for s in [-1, 1]:
			var q: Vector2 = p + side * s
			mesh_at(cylinder(0.12, 0.12, 2.0, 8), post_mat, Vector3(q.x, -0.7, q.y), g)
		if k % 2 == 0:
			var q2: Vector2 = p + side
			mesh_at(cylinder(0.06, 0.06, 2.2, 8), post_mat, Vector3(q2.x, 1.4, q2.y), g)
			mesh_at(sphere(0.22, -1, 12), lamp, Vector3(q2.x, 2.6, q2.y), g)
			night_light(g, Vector3(q2.x, 2.4, q2.y), lamp.albedo_color)
	own(g)


func _boardwalks() -> void:
	boardwalk("Boardwalk South", Vector2(-6, 21), Vector2(-8, -12))
	boardwalk("Boardwalk North", Vector2(-12, -30), Vector2(-12, -42))
	boardwalk("Boardwalk East", Vector2(30, -20), Vector2(46, -2))
	boardwalk("Dock", Vector2(22, 19), Vector2(22, 9), 2.5)


func dome_building(name: String, x: float, z: float, r: float, yaw: float, color := Color(0.98, 0.78, 0.2),
		extra := [], floor_y := NAN) -> Node3D:
	# floor_y: build it up in the air at that height instead of on the ground (the toy store on the cloud)
	var c := ground(x, z) if is_nan(floor_y) else Vector3(x, floor_y, z)
	var id := name.replace("&", "And").replace("'", "")
	var g := group(name, c, yaw)
	var shell := mat("Dome " + str(color), color, 0.6)
	var trim := mat("Dome Trim", Color(0.85, 0.6, 0.12), 0.7)
	var glass := mat("Window", Color(0.25, 0.6, 0.98), 0.1, 0.1, 0.35)
	var door := mat("Door", Color(0.25, 0.18, 0.12))
	mesh_at(sphere(r, r * 2, 40), shell, Vector3.ZERO, g)
	mesh_at(cylinder(r * 1.04, r * 1.06, 3.0, 40), trim, Vector3(0, -1.2, 0), g)       # base ring, reaches into slopes
	solid(_sphere_shape(r), Vector3.ZERO, g)
	# Window band across the front half
	for k in range(-2, 3):
		var a := k * 0.42
		var wpos := Vector3(sin(a), 0, cos(a)) * (r * 0.93) + Vector3(0, r * 0.42, 0)
		mesh_at(box(Vector3(r * 0.32, r * 0.3, 0.3)), glass, wpos, g, a, Vector3(-0.35, 0, 0))
	mesh_at(box(Vector3(1.8, 2.6, 0.6)), door, Vector3(0, 1.1, r * 0.97), g)
	night_light(g, Vector3(0, 3.2, r + 1.0), WT.light(Color(1.0, 0.85, 0.6)), 1.0, 6.0)     # porch light
	for e in extra:            # extra domes: Vector4(dx, dz, r, height offset)
		mesh_at(sphere(e.z, e.z * 2, 32), shell, Vector3(e.x, e.w, e.y), g)
		mesh_at(cylinder(e.z * 1.04, e.z * 1.06, 3.0, 32), trim, Vector3(e.x, e.w - 1.2, e.y), g)
		solid(_sphere_shape(e.z), Vector3(e.x, e.w, e.y), g)
	sign_post(g, name, Vector3(2.6, 0, r + 2.2), 0.0)
	var area := Area3D.new()
	area.name = "Door"
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", "res://scenes/interiors/%s.tscn" % name.replace("&", "and").replace("'", "").to_snake_case())
	area.set("spawn", "Entrance")
	area.set("place_name", name)
	area.position = Vector3(0, 1.2, r + 0.6)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(2.4, 7.0, 1.2))            # tall, so it still catches her where the ground slopes
	area.add_child(cs)
	g.add_child(area)
	var back := Marker3D.new()                     # where she appears when leaving this building, facing away from it
	back.name = "From" + id.replace(" ", "")
	var front := Vector2(x, z) + Vector2(sin(yaw), cos(yaw)) * (r + 4.5)
	var front_y := height(front.x, front.y) - c.y if is_nan(floor_y) else 0.0
	back.position = Vector3(0, front_y + 1.0, r + 4.5)   # on the ground in front of the door
	back.rotation.y = PI
	g.add_child(back)
	if is_nan(floor_y):
		keep_clear.append(Vector3(x, z, r + 6))
	own(g)
	return g


func _market() -> void:
	# The Market Square, the town centre: a paved plaza with a fountain, six open-air stalls round it (scenery for
	# now), lamps that come on at night (Pip comes to look at them), benches, and the Town Hall at its head.
	# The shops round the edge come from _buildings().
	var c := ground(MARKET.x, MARKET.y)
	var g := group("Market Square", c)
	var stone := mat("Plaza Stone", Color(0.85, 0.8, 0.72))
	mesh_at(cylinder(MARKET.z, MARKET.z, 1.0, 64), stone, Vector3(0, -0.35, 0), g)
	solid(_cyl_shape(MARKET.z, 1.0), Vector3(0, -0.35, 0), g)
	for r in [MARKET.z - 1.0, 9.0]:                                  # rings of darker paving
		mesh_at(cylinder(r, r, 1.01, 64), mat("Plaza Ring", Color(0.75, 0.68, 0.62)), Vector3(0, -0.345, 0), g)
		mesh_at(cylinder(r - 0.6, r - 0.6, 1.02, 64), stone, Vector3(0, -0.34, 0), g)
	# Fountain
	mesh_at(cylinder(2.6, 2.8, 0.8, 32), mat("Fountain Stone", Color(0.75, 0.72, 0.68)), Vector3(0, 0.4, 0), g)
	solid(_cyl_shape(2.8, 0.8), Vector3(0, 0.4, 0), g)
	mesh_at(cylinder(2.3, 2.3, 0.1, 32), mat("Water", Color()), Vector3(0, 0.75, 0), g)
	mesh_at(cylinder(0.35, 0.45, 2.4, 16), mat("Fountain Stone", Color()), Vector3(0, 1.6, 0), g)
	mesh_at(sphere(0.7), mat("Fountain Water", Color(0.6, 0.85, 1.0), 0.1, 0.0, 0.6, 0.7), Vector3(0, 2.9, 0), g)
	# Stalls: a table with goods, a striped awning on four posts, the stall's name, round the fountain on the
	# diagonals (the four ways in and out stay clear)
	var wood := mat("Stall Wood", Color(0.6, 0.4, 0.25))
	var stalls := [["Fruit", 30.0, [Color(0.95, 0.3, 0.3), Color(1.0, 0.75, 0.2), Color(0.5, 0.85, 0.3)]],
		["Sweets", 60.0, [Color(1.0, 0.6, 0.8), Color(0.75, 0.55, 1.0), Color(1.0, 0.95, 0.6)]],
		["Crystals", 120.0, [Color(0.6, 0.9, 1.0), Color(0.85, 0.6, 1.0), Color(0.6, 1.0, 0.8)]],
		["Flowers", 150.0, [Color(1.0, 0.45, 0.7), Color(1.0, 0.9, 0.3), Color(0.7, 0.5, 1.0)]],
		["Records", 210.0, [Color(0.15, 0.15, 0.2), Color(0.95, 0.4, 0.4), Color(0.3, 0.6, 1.0)]],
		["Toys", 330.0, [Color(0.3, 0.8, 1.0), Color(1.0, 0.5, 0.2), Color(0.6, 1.0, 0.4)]]]
	for k in stalls.size():
		var st: Array = stalls[k]
		var a := deg_to_rad(st[1])
		var at := Vector3(cos(a), 0, sin(a)) * 12.0
		var stall := Node3D.new()
		stall.name = st[0] + " Stall"
		stall.position = at
		stall.rotation.y = atan2(-at.x, -at.z)               # front (with the goods) toward the fountain
		g.add_child(stall)
		solid(box_shape(Vector3(2.6, 0.9, 1.2)), Vector3(0, 0.45, 0), stall)
		mesh_at(box(Vector3(2.6, 0.9, 1.2)), wood, Vector3(0, 0.45, 0), stall)
		var cols: Array = st[2]
		for q in 6:                                           # goods on the table
			mesh_at(sphere(0.18, -1, 10), mat("%s Goods %d" % [st[0], q % 3], cols[q % 3], 0.5, 0.0, 0.3),
				Vector3(-1.0 + q * 0.4, 1.05, 0.2 * (q % 2)), stall)
		for px in [-1.2, 1.2]:
			for pz in [-0.5, 0.5]:
				mesh_at(cylinder(0.06, 0.06, 2.4, 6), wood, Vector3(px, 1.2, pz), stall)
		for stripe in 5:                                      # striped awning
			var sc: Color = cols[0] if stripe % 2 == 0 else Color(1, 1, 1)
			mesh_at(box(Vector3(0.58, 0.06, 1.7)), mat("%s Awning %d" % [st[0], stripe % 2], sc, 0.7),
				Vector3(-1.16 + stripe * 0.58, 2.45, 0.1), stall, 0.0, Vector3(0.22, 0, 0))
		label3d(stall, st[0], Vector3(0, 3.1, 0), 56)
	# Lamps round the plaza (on at night), and benches by the fountain
	var lamp := mat("Lamp", Color(1.0, 0.92, 0.6), 0.3, 0.0, 2.0)
	var post := mat("Lamp Post", Color(0.3, 0.3, 0.38), 0.5, 0.5)
	for k in 8:
		var a := deg_to_rad(22.5 + 45.0 * k)
		var lp := Vector3(cos(a), 0, sin(a)) * (MARKET.z - 3.0)
		mesh_at(cylinder(0.08, 0.1, 3.4, 8), post, lp + Vector3(0, 1.7, 0), g)
		mesh_at(sphere(0.3, -1, 12), lamp, lp + Vector3(0, 3.5, 0), g)
		night_light(g, lp + Vector3(0, 3.3, 0), lamp.albedo_color, 1.4, 9.0)
	var bench := mat("Bench Wood", Color(0.65, 0.42, 0.25))
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		var bp := Vector3(cos(a), 0, sin(a)) * 6.0
		mesh_at(box(Vector3(2.0, 0.15, 0.6)), bench, bp + Vector3(0, 0.5, 0), g, atan2(bp.x, bp.z) + PI / 2)
		solid(box_shape(Vector3(2.0, 0.5, 0.6)), bp + Vector3(0, 0.25, 0), g, atan2(bp.x, bp.z) + PI / 2)
	sign_post(g, "Market Square", Vector3(4, 0, MARKET.z + 2.0), 0.0)
	# Where she appears in town when there's no door to come out of (old saves, fainting): the south entrance
	var entrance := Marker3D.new()
	entrance.name = "MarketEntrance"
	entrance.position = Vector3(0, 1.0, MARKET.z + 12.0)
	g.add_child(entrance)
	keep_clear.append(Vector3(MARKET.x, MARKET.y, MARKET.z + 8.0))
	own(g)


func _housing() -> void:
	# The housing district east of the lake: a hedge round it with gaps for the paths (the gate faces the lake), and a
	# little park in the middle where the zipline from the tree house lands. The homes come from _buildings().
	var c := ground(HOUSING.x, HOUSING.y)
	var g := group("Housing District", c)
	var hedge := mat("Hedge", T.grass.darkened(0.25), 0.9)
	var gaps := [180.0, -78.0, 93.0, 2.0]                  # gate (west, to the lake), Observatory path, sports, tree house
	var n := 84
	for k in n:
		var deg := 360.0 * k / n
		var open := false
		for gap in gaps:
			if absf(wrapf(deg - gap, -180.0, 180.0)) < 8.0:
				open = true
		if open:
			continue
		var a := deg_to_rad(deg)
		var hp := Vector2(HOUSING.x, HOUSING.y) + Vector2(cos(a), sin(a)) * HOUSING.z
		var y := height(hp.x, hp.y) - c.y
		var bush := mesh_at(sphere(1.4, -1, 12), hedge, Vector3(hp.x - c.x, y + 0.7, hp.y - c.z), g)
		bush.scale = Vector3(1.0, 0.8, 1.0)
		solid(box_shape(Vector3(2.4, 1.6, 1.2)), Vector3(hp.x - c.x, y + 0.8, hp.y - c.z), g, a + PI / 2)
	sign_post(g, "Homes", Vector3(-HOUSING.z - 2.0, 0, 4.0), -PI / 2)
	# The park: a round lawn bed with flowers and two benches
	var flowers := [Color(1.0, 0.45, 0.7), Color(1.0, 0.9, 0.3), Color(0.7, 0.5, 1.0)]
	mesh_at(cylinder(3.0, 3.2, 0.4, 24), mat("Flower Bed", Color(0.45, 0.3, 0.2)), Vector3(0, 0.0, 0), g)
	for k in 14:
		var a := k * TAU / 14
		mesh_at(sphere(0.3, -1, 8), mat("Bed Flower %d" % (k % 3), flowers[k % 3], 0.6, 0.0, 0.3),
			Vector3(cos(a) * 2.2, 0.35, sin(a) * 2.2), g)
	var bench := mat("Bench Wood", Color(0.65, 0.42, 0.25))
	for side in [-1, 1]:
		mesh_at(box(Vector3(2.0, 0.15, 0.6)), bench, Vector3(side * 5.0, 0.5, -3.0), g, side * 0.6)
		solid(box_shape(Vector3(2.0, 0.5, 0.6)), Vector3(side * 5.0, 0.25, -3.0), g, side * 0.6)
	keep_clear.append(Vector3(HOUSING.x, HOUSING.y, 9.0))
	own(g)


func _sphere_shape(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _buildings() -> void:
	var blue := Color(0.3, 0.62, 0.98)
	# Learning Row on the north shore, on the way up to the school
	dome_building("Museum", -40, -50, 7, 0.0, Color(0.98, 0.78, 0.2), [Vector4(-7, -2, 4.5, 0)])
	dome_building("Library", -12, -50, 8, 0.0, Color(0.98, 0.78, 0.2), [Vector4(8, -3, 5, 0)])
	dome_building("Aquarium", 26, -54, 8, 0.0, blue, [Vector4(8, -3, 5, 0)])
	# Market Square: the shops round the plaza, doors facing the fountain (_market adds the plaza, stalls and lamps)
	for shop in [["Potion Shop", 200.0, 6.0, Color(0.55, 0.3, 0.9)], ["Cafe", 160.0, 5.0, Color(0.98, 0.78, 0.2)],
			["Clothing Boutique", 115.0, 6.0, Color(0.98, 0.78, 0.2)], ["Book Store", 65.0, 6.0, Color(0.98, 0.78, 0.2)],
			["Pet Shop", 20.0, 5.5, Color(0.98, 0.78, 0.2)], ["Restaurant & Cafe", 340.0, 6.0, Color(0.98, 0.78, 0.2)]]:
		var a := deg_to_rad(shop[1])
		var x := MARKET.x + cos(a) * MARKET_RING
		var z := MARKET.y + sin(a) * MARKET_RING
		var g := dome_building(shop[0], x, z, shop[2], atan2(MARKET.x - x, MARKET.y - z), shop[3])
		if shop[0] == "Potion Shop":
			_potion_shop(g)
	# Sports & Play
	dome_building("Gaming Station", 34, 80, 8, PI, blue)
	# Housing district east of the lake: homes round a little park, doors facing it
	for home in [["Nina's House", 62.0, -10.0, 5.0, Color(0.98, 0.78, 0.2)], ["Dash's House", 82.0, -18.0, 4.5, Color(0.75, 0.8, 0.88)],
			["Melanie's House", 98.0, -4.0, 4.5, Color(0.98, 0.78, 0.2)], ["Empty Home", 66.0, 16.0, 4.5, Color(0.9, 0.85, 0.95)],
			["Empty Home 2", 94.0, 16.0, 4.5, Color(0.9, 0.85, 0.95)]]:
		var g := dome_building(home[0], home[1], home[2], home[3], atan2(HOUSING.x - home[1], HOUSING.y - home[2]), home[4])
		if home[0] == "Nina's House":
			_ninas_house(g)
		elif home[0] == "Dash's House":
			_dashs_house(g)
	# The Observatory on top of its hill, door looking back over the town
	_observatory(dome_building("Observatory", OBS_HILL.x, OBS_HILL.y, 7, -0.85, Color(0.85, 0.85, 0.9)))


func _potion_shop(g: Node3D) -> void:
	# A big potion bottle on the roof: a glass bulb with a glowing brew, a neck and a cork
	var glass := mat("Potion Glass", Color(0.75, 0.9, 1.0), 0.05, 0.0, 0.0, 0.45)
	var brew := mat("Potion Brew", Color(0.4, 1.0, 0.5), 0.3, 0.0, 1.4)
	mesh_at(sphere(1.6, -1, 20), glass, Vector3(0, 6.6, -1.0), g)
	mesh_at(sphere(1.25, -1, 20), brew, Vector3(0, 6.4, -1.0), g)
	mesh_at(cylinder(0.45, 0.6, 1.4, 12), glass, Vector3(0, 8.5, -1.0), g)
	mesh_at(cylinder(0.5, 0.45, 0.5, 12), mat("Cork", Color(0.6, 0.42, 0.25)), Vector3(0, 9.4, -1.0), g)
	own(g)


func _ninas_house(g: Node3D) -> void:
	# A big red bow on top, like the one in Nina's hair
	var bow := mat("Nina Bow", Color(0.9, 0.1, 0.2), 0.5)
	for s in [-1, 1]:
		mesh_at(sphere(1.1, 1.4, 16), bow, Vector3(s * 1.0, 5.1, 0), g, 0.0, Vector3(0, 0, s * 0.5))
	mesh_at(sphere(0.5, -1, 12), bow, Vector3(0, 5.1, 0), g)
	own(g)


func _dashs_house(g: Node3D) -> void:
	# Dash is from the future: a silver dome with an antenna mast and glowing rings
	var metal := mat("Future Metal", Color(0.8, 0.82, 0.88), 0.25, 0.8)
	var glow := mat("Future Glow", Color(0.2, 0.95, 1.0), 0.3, 0.0, 2.5)
	mesh_at(cylinder(0.12, 0.18, 4.0, 8), metal, Vector3(0, 6.2, 0), g)
	mesh_at(sphere(0.35, -1, 12), glow, Vector3(0, 8.4, 0), g)
	for k in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7 + k * 0.5
		ring.outer_radius = 0.85 + k * 0.5
		mesh_at(ring, glow, Vector3(0, 6.6 + k * 0.9, 0), g)
	var band := TorusMesh.new()                    # a glowing stripe round the dome
	band.inner_radius = 4.35
	band.outer_radius = 4.6
	mesh_at(band, glow, Vector3(0, 1.2, 0), g)
	own(g)


func _observatory(g: Node3D) -> void:
	# A telescope poking out of a slot in the dome, aimed at the ringed planet
	var tube := mat("Telescope", Color(0.3, 0.32, 0.4), 0.4, 0.6)
	var slot := mat("Dome Slot", Color(0.1, 0.1, 0.16))
	mesh_at(box(Vector3(1.6, 6.0, 0.5)), slot, Vector3(0, 4.4, -3.6), g, 0.0, Vector3(0.55, 0, 0))
	mesh_at(cylinder(0.7, 0.9, 7.0, 16), tube, Vector3(0, 7.2, -3.4), g, 0.0, Vector3(-0.7, 0, 0))
	mesh_at(cylinder(0.95, 0.95, 0.4, 16), mat("Telescope Lens", Color(0.5, 0.8, 1.0), 0.05, 0.0, 1.5), Vector3(0, 9.9, -5.7), g,
		0.0, Vector3(-0.7, 0, 0))
	own(g)


func _castle() -> void:
	# The castle school is Bojnice Castle (Bojnice, Slovakia) at its real size: every tower and wing, its outline and
	# courtyards come from OpenStreetMap's 3D building data (tools/bojnice_footprint.json, made by
	# tools/fetch_bojnice.py; map data (c) OpenStreetMap contributors, ODbL). Bojnice's gate faces north, so the castle
	# is turned round to face the town. Its look comes from source_art/reference/world/castle - lilac fairytale
	# castle.jpg: pale pink stone, lavender pointed roofs, gold-lit windows, round corner towers with tall cones,
	# purple-domed halls beside a glowing golden gate with a rose window above it.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOJNICE))
	var top := ground(CASTLE_HILL.x, CASTLE_HILL.y)
	var g := group("Castle School", top, CASTLE_YAW)
	var surfaces := {}                                   # material -> SurfaceTool, all merged into one mesh
	castle_faces = PackedVector3Array()                  # walls and roofs, for the collision
	var wall := mat("Castle Wall", Color(0.96, 0.86, 0.9), 0.8, 0.0, 0.0, 1.0, false)
	var lit := mat("Castle Window", Color(1.0, 0.78, 0.38), 0.4, 0.0, 1.5, 1.0, false)
	var finial := mat("Castle Finial", Color(1.0, 0.8, 0.4), 0.3, 0.6, 0.0, 1.0, false)
	var cone := mat("Castle Roof Cone", Color(0.7, 0.6, 0.93), 0.5, 0.0, 0.0, 1.0, false)
	var dome := mat("Castle Dome", Color(0.6, 0.48, 0.88), 0.35, 0.2, 0.0, 1.0, false)

	# The base: the whole outline minus the open courtyards, a block as tall as the curtain walls, with battlements
	var ring: Dictionary = data.ring
	var rh: float = ring.height
	var outline := _pts(ring.outline)
	_walls(surfaces, wall, null, outline, -3.0, rh, false)
	for c in ring.courts:
		_walls(surfaces, wall, null, _pts(c), -3.0, rh, true)
	var rp := _pts(ring.points)
	for t in ring.tris:
		var a := Vector3(rp[t[0]].x, rh, rp[t[0]].y)
		var b := Vector3(rp[t[1]].x, rh, rp[t[1]].y)
		var c := Vector3(rp[t[2]].x, rh, rp[t[2]].y)
		_tri(_st(surfaces, wall), true, a, b, c, Vector3.UP)
	var part_polys := []
	for part in data.parts:
		part_polys.append(_pts(part.points))
	for i in outline.size():
		var p0 := outline[i - 1]
		var p1 := outline[i]
		var n := int(p0.distance_to(p1) / 2.4)
		var inward := -_outward(outline, p0, p1)
		for k in n:
			var q := p0.lerp(p1, (k + 0.5) / n)
			if part_polys.any(func(pp: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(q + inward * 0.8, pp)):
				continue                                     # this stretch of wall is a tower or wing, not a curtain wall
			var yaw := atan2(p1.x - p0.x, p1.y - p0.y)
			_box(surfaces, wall, Vector3(q.x, rh + 0.6, q.y), Vector3(0.9, 1.2, 1.2), yaw)

	# Every tower and wing: walls with rows of lit windows, and a steep hipped roof (a pointed one on the towers)
	var gate_part := {}
	for part in data.parts:
		var pts := _pts(part.points)
		var base: float = part.base
		var wall_top: float = part.wall_top
		var roof := mat("Castle Roof " + str(part.roof_colour), _roof_colour(part.roof_colour), 0.55, 0.0, 0.0, 1.0, false)
		_walls(surfaces, wall, lit, pts, base if base > 0.0 else -3.0, wall_top, false)
		var apex := _roof(surfaces, roof, pts, part.tris, wall_top, part.roof, part.inner_radius)
		if part.shape == "pyramidal":
			mesh_at(cylinder(0.0, 0.18, 4.0, 8), finial, apex + Vector3(0, 1.6, 0), g)
			mesh_at(sphere(0.35, -1, 12), finial, apex + Vector3(0, 0.5, 0), g)
		if part.gate:
			gate_part = part

	# The gate: on the gate building's side that faces the town, with the school entrance trigger
	var gp := _pts(gate_part.points)
	var best := -2.0
	var mid := Vector2.ZERO
	var out := Vector2.ZERO
	for i in gp.size():
		var e := gp[i] - gp[i - 1]
		var n2 := _outward(gp, gp[i - 1], gp[i])
		var score := (Basis(Vector3.UP, CASTLE_YAW) * Vector3(n2.x, 0, n2.y)).z + e.length() * 0.001   # faces the town
		if score > best:
			best = score
			mid = (gp[i - 1] + gp[i]) / 2.0
			out = n2
	var door_yaw := atan2(out.x, out.y)
	var dy := _local_ground(g, top, mid)
	var at := Vector3(mid.x, dy, mid.y) + Vector3(out.x, 0, out.y) * 0.35
	var side := Vector2(out.y, -out.x)

	# Round corner towers with tall pointed roofs, and a purple-domed hall on each side of the gate
	_corner_towers(surfaces, wall, cone, lit, outline, mid)
	for s in [-1.0, 1.0]:
		var c2: Vector2 = mid + out * 9.0 + side * s * 15.5
		_domed_hall(surfaces, wall, dome, cone, lit, Vector3(c2.x, _local_ground(g, top, c2), c2.y), 6.0)
		var cw := g.transform * Vector3(c2.x, 0, c2.y)
		castle_spots.append(Vector3(cw.x, cw.z, 8.5))

	var mesh := ArrayMesh.new()
	for m in surfaces:
		var st: SurfaceTool = surfaces[m]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	save_external(mesh, "castle_mesh.res")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(castle_faces)
	save_external(shape, "castle_shape.res")
	var mi := MeshInstance3D.new()
	mi.name = "Bojnice"
	mi.mesh = mesh
	g.add_child(mi)
	solid(shape, Vector3.ZERO, g).name = "BojniceCollision"
	for p in outline:
		var w := g.transform * Vector3(p.x, 0, p.y)
		castle_outline.append(Vector2(w.x, w.z))

	# The gate: a tall glowing golden door in a stone arch, with a rose window above
	var door := mat("Castle Door Glow", Color(0.95, 0.6, 0.2), 0.4, 0.0, 0.3, 1.0, false)
	var arch := mat("Castle Arch", Color(0.88, 0.76, 0.84), 0.7, 0.0, 0.0, 1.0, false)
	var o3 := Vector3(out.x, 0, out.y)               # straight out from the wall
	mesh_at(box(Vector3(6.2, 6.0, 0.8)), arch, at + Vector3(0, 3.0, 0) - o3 * 0.15, g, door_yaw)
	mesh_at(cylinder(3.1, 3.1, 0.8, 28), arch, at + Vector3(0, 6.0, 0) - o3 * 0.15, g, door_yaw, Vector3(PI / 2, 0, 0))
	mesh_at(box(Vector3(4.4, 6.0, 0.6)), door, at + Vector3(0, 3.0, 0) + o3 * 0.12, g, door_yaw)
	mesh_at(cylinder(2.2, 2.2, 0.6, 24), door, at + Vector3(0, 6.0, 0) + o3 * 0.12, g, door_yaw, Vector3(PI / 2, 0, 0))
	var rose := mat("Castle Rose Window", Color(0.95, 0.45, 0.9), 0.3, 0.0, 0.9, 1.0, false)
	var rose_at := at + Vector3(0, 10.8, 0) + o3 * 0.05
	mesh_at(cylinder(2.1, 2.1, 0.3, 32), finial, rose_at, g, door_yaw, Vector3(PI / 2, 0, 0))
	mesh_at(cylinder(1.8, 1.8, 0.4, 32), rose, rose_at, g, door_yaw, Vector3(PI / 2, 0, 0))
	for k in 4:                                    # the star in the middle
		mesh_at(box(Vector3(0.16, 3.2, 0.5)), mat("Castle Rose Star", Color(0.85, 0.95, 1.0), 0.2, 0.0, 1.4, 1.0, false),
			rose_at, g, door_yaw, Vector3(0, 0, k * PI / 4))
	var area := Area3D.new()
	area.name = "SchoolEntrance"
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", "res://scenes/school/school.tscn")
	area.set("spawn", "FromTown")
	area.position = at + Vector3(out.x, 0, out.y) * 1.2 + Vector3(0, 2, 0)
	area.rotation.y = door_yaw
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(4, 4, 1.5))
	area.add_child(cs)
	g.add_child(area)
	var back := Marker3D.new()                   # where she appears when leaving the school, facing the town
	back.name = "FromSchool"
	back.position = at + Vector3(out.x, 0, out.y) * 6.0 + Vector3(0, 1.0, 0)
	back.rotation.y = door_yaw + PI
	g.add_child(back)
	var glow := OmniLight3D.new()                # light spilling out of the gate
	glow.light_color = WT.light(Color(1.0, 0.75, 0.4))
	glow.light_energy = 0.7
	glow.omni_range = 9.0
	glow.position = at + Vector3(out.x, 0, out.y) * 2.5 + Vector3(0, 4, 0)
	g.add_child(glow)
	sign_post(g, "School", at + Vector3(out.x * 5.0 + side.x * 5.0, 0, out.y * 5.0 + side.y * 5.0), door_yaw)
	keep_clear.append(Vector3(CASTLE_HILL.x, CASTLE_HILL.y, CASTLE_HILL_TOP + 4.0))
	own(g)
	var gw := g.transform * at
	castle_gate = g.transform * (at + Vector3(out.x, 0, out.y) * 6.0)
	print("CASTLE gate at (%d, %d)" % [gw.x, gw.z])


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(p[0], p[1]))
	return out


func _st(surfaces: Dictionary, m: Material) -> SurfaceTool:
	if not surfaces.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[m] = st
	return surfaces[m]


func _tri(st: SurfaceTool, collide: bool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# One triangle facing n (Godot's front faces wind clockwise), added to the collision when collide
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)
	if collide:
		castle_faces.append_array([a, b, c])


func _quad(st: SurfaceTool, collide: bool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, collide, a, b, c, n)
	_tri(st, collide, a, c, d, n)


func _box(surfaces: Dictionary, m: Material, at: Vector3, size: Vector3, yaw: float) -> void:
	var bm := box(size)
	var arrays := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis(Vector3.UP, yaw)
	for i in range(0, idx.size(), 3):
		var a := at + basis * verts[idx[i]]
		var b := at + basis * verts[idx[i + 1]]
		var c := at + basis * verts[idx[i + 2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c) / 3.0 - at) < 0.0:
			n = -n
		_tri(_st(surfaces, m), true, a, b, c, n)


func _outward(poly: PackedVector2Array, p0: Vector2, p1: Vector2) -> Vector2:
	# The normal of edge p0-p1 that points out of the polygon
	var d := (p1 - p0).normalized()
	var n := Vector2(d.y, -d.x)
	if Geometry2D.is_point_in_polygon((p0 + p1) / 2.0 + n * 0.05, poly):
		n = -n
	return n


func _walls(surfaces: Dictionary, m: Material, lit: Material, poly: PackedVector2Array,
		y0: float, y1: float, is_hole: bool) -> void:
	# Upright walls round a polygon (facing out of it, or into it for a courtyard), with rows of windows when lit is given
	if y1 - y0 < 0.05:
		return
	var st := _st(surfaces, m)
	for i in poly.size():
		var p0 := poly[i - 1]
		var p1 := poly[i]
		var n2 := _outward(poly, p0, p1) * (-1.0 if is_hole else 1.0)
		var n := Vector3(n2.x, 0, n2.y)
		_quad(st, true, Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), Vector3(p1.x, y1, p1.y), Vector3(p0.x, y1, p0.y), n)
		if lit == null:
			continue
		var length := p0.distance_to(p1)
		var across := int((length - 1.5) / 4.0)
		var y := maxf(y0, 0.0) + 2.6
		while across > 0 and y + 2.8 < y1 - 0.8:
			for k in across:
				var q := p0.lerp(p1, (k + 0.5) / across) + n2 * 0.08
				_window(_st(surfaces, lit), Vector3(q.x, y, q.y), (p1 - p0).normalized(), n)
			y += 4.2


func _window(st: SurfaceTool, at: Vector3, along2: Vector2, n: Vector3) -> void:
	# An arched window: 1.1 m wide, 2.2 m to the top of its arch, lying flat on the wall
	var along := Vector3(along2.x, 0, along2.y)
	var w := 0.55
	var h := 1.65
	var bl := at - along * w
	var br := at + along * w
	_quad(st, false, bl, br, br + Vector3.UP * h, bl + Vector3.UP * h, n)
	var c := at + Vector3.UP * h
	for k in 6:
		var a0 := PI * k / 6.0
		var a1 := PI * (k + 1) / 6.0
		_tri(st, false, c, c + (along * cos(a0) + Vector3.UP * sin(a0)) * w, c + (along * cos(a1) + Vector3.UP * sin(a1)) * w, n)


func _roof(surfaces: Dictionary, m: Material, poly: PackedVector2Array, tris: Array,
		y0: float, rise: float, inner: float) -> Vector3:
	# A hipped roof over any outline: the roof rises evenly from every eave, so its height at a point is set by how
	# far that point is from the nearest wall. Triangles are cut small so the ridges and hips come out sharp enough.
	var st := _st(surfaces, m)
	var apex := Vector3(0, -INF, 0)
	var y_at := func(p: Vector2) -> float:
		var d := INF
		for i in poly.size():
			d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i - 1], poly[i])))
		return y0 + rise * clampf(d / maxf(inner, 0.01), 0.0, 1.0)
	for t in tris:
		var A := poly[t[0]]
		var B := poly[t[1]]
		var C := poly[t[2]]
		var n := maxi(1, ceili(maxf(A.distance_to(B), maxf(B.distance_to(C), C.distance_to(A))) / 0.5))
		var grid := {}
		for i in n + 1:
			for j in n + 1 - i:
				var p := A + (B - A) * (float(i) / n) + (C - A) * (float(j) / n)
				var v := Vector3(p.x, y_at.call(p), p.y)
				grid[Vector2i(i, j)] = v
				if v.y > apex.y:
					apex = v
		for i in n:
			for j in n - i:
				var a: Vector3 = grid[Vector2i(i, j)]
				var b: Vector3 = grid[Vector2i(i + 1, j)]
				var c: Vector3 = grid[Vector2i(i, j + 1)]
				_roof_tri(st, a, b, c)
				if i + j < n - 1:
					_roof_tri(st, b, grid[Vector2i(i + 1, j + 1)], c)
	return apex


func _roof_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	_tri(st, true, a, b, c, n)


func _roof_colour(osm: String) -> Color:
	# Lavender roofs as in the picture, a shade lighter where OSM has Bojnice's copper roofs (the big towers) and
	# pinker where it has red tiles (the north towers)
	match osm.to_lower():
		"#badeec":
			return Color(0.76, 0.68, 0.96)
		"#c37465":
			return Color(0.78, 0.58, 0.86)
	return Color(0.66, 0.57, 0.9)


func _local_ground(g: Node3D, top: Vector3, p: Vector2) -> float:
	# The ground's height under a castle-space point, measured from the castle's floor
	var w := g.transform * Vector3(p.x, 0, p.y)
	return height(w.x, w.z) - top.y


func _prim(surfaces: Dictionary, m: Material, mesh: PrimitiveMesh, xf: Transform3D, collide := true) -> void:
	# Copies a primitive (cylinder, sphere...) into the castle's merged mesh, moved by xf, keeping its smooth normals
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := _st(surfaces, m)
	for i in idx.size():
		st.set_normal((xf.basis * norms[idx[i]]).normalized())
		st.add_vertex(xf * verts[idx[i]])
	if collide:
		for i in idx.size():
			castle_faces.append(xf * verts[idx[i]])


func _round_tower(surfaces: Dictionary, wall: Material, roof: Material, lit: Material, c: Vector3, r: float,
		top_y: float, spire: float) -> void:
	# A round tower from below the ground at c up to top_y, a corbelled ring, a pointed roof and rows of windows
	var h := top_y - (c.y - 3.0)
	_prim(surfaces, wall, cylinder(r, r, h, 24), Transform3D(Basis(), Vector3(c.x, c.y - 3.0 + h / 2.0, c.z)))
	_prim(surfaces, wall, cylinder(r * 1.14, r * 0.98, r * 0.4, 24), Transform3D(Basis(), Vector3(c.x, top_y - r * 0.15, c.z)))
	_prim(surfaces, roof, cylinder(0.0, r * 1.22, spire, 24), Transform3D(Basis(), Vector3(c.x, top_y + spire / 2.0, c.z)))
	_prim(surfaces, mats["Castle Finial"], cylinder(0.0, maxf(r * 0.07, 0.08), r * 1.5, 8),
		Transform3D(Basis(), Vector3(c.x, top_y + spire + r * 0.6, c.z)), false)
	var y := c.y + 3.0
	var row := 0
	while y + 2.6 < top_y - 1.5:
		for k in 5:
			var a := (k + 0.5 * (row % 2)) * TAU / 5.0
			var d := Vector2(sin(a), cos(a))
			_window(_st(surfaces, lit), Vector3(c.x + d.x * (r + 0.05), y, c.z + d.y * (r + 0.05)), Vector2(d.y, -d.x),
				Vector3(d.x, 0, d.y))
		y += 4.6
		row += 1


func _corner_towers(surfaces: Dictionary, wall: Material, roof: Material, lit: Material, outline: PackedVector2Array,
		gate: Vector2) -> void:
	# A round tower on each sharp outer corner of the castle's outline (not too close together, or to the gate)
	var area := 0.0
	for i in outline.size():
		area += outline[i - 1].cross(outline[i])
	var placed: Array[Vector2] = []
	var n := outline.size()
	for i in n:
		var v := outline[i]
		var e1 := (v - outline[i - 1]).normalized()
		var e2 := (outline[(i + 1) % n] - v).normalized()
		if e1.cross(e2) * area <= 0.0 or absf(e1.angle_to(e2)) < 0.5:
			continue                                     # an inside corner, or hardly a corner at all
		if v.distance_to(gate) < 16.0 or placed.any(func(q: Vector2) -> bool: return q.distance_to(v) < 15.0):
			continue
		placed.append(v)
		var c := v + (e1 - e2).normalized() * 1.2
		var r := 2.6
		_round_tower(surfaces, wall, roof, lit, Vector3(c.x, 0.0, c.y), r, 18.0 + 3.0 * (placed.size() % 3), 11.0)
	print("CASTLE corner towers ", placed.size())


func _domed_hall(surfaces: Dictionary, wall: Material, dome: Material, roof: Material, lit: Material, c: Vector3,
		r: float) -> void:
	# A round hall with a purple dome, gold windows all round and a little pointed lantern on top
	var drum := 5.0
	_prim(surfaces, wall, cylinder(r, r * 1.03, drum + 3.0, 32), Transform3D(Basis(), c + Vector3(0, (drum - 3.0) / 2.0, 0)))
	_prim(surfaces, mats["Castle Finial"], cylinder(r * 1.06, r * 1.06, 0.4, 32), Transform3D(Basis(), c + Vector3(0, drum, 0)))
	var hemi := sphere(r * 0.98, r * 0.98, 32)
	hemi.is_hemisphere = true
	_prim(surfaces, dome, hemi, Transform3D(Basis(), c + Vector3(0, drum, 0)))
	for k in 10:
		var a := k * TAU / 10.0
		var d := Vector2(sin(a), cos(a))
		_window(_st(surfaces, lit), Vector3(c.x + d.x * (r + 0.06), c.y + 1.2, c.z + d.y * (r + 0.06)), Vector2(d.y, -d.x),
			Vector3(d.x, 0, d.y))
	_round_tower(surfaces, wall, roof, lit, c + Vector3(0, drum + r * 0.98 - 0.5, 0) + Vector3(0, 3.0, 0), 0.8,
		c.y + drum + r * 0.98 + 1.5, 3.2)


func _castle_grounds() -> void:
	# The castle's gardens, joining it to the town as in the castle picture: the rock's two waterfalls and their
	# ponds, lamp posts up the ramp, red and pink flowering bushes and tall dark cypresses round the castle
	var g := group("Castle Grounds", Vector3.ZERO)
	var surfaces := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var hill := Vector2(CASTLE_HILL.x, CASTLE_HILL.y)

	# Waterfalls down the cliff, into their ponds
	var wmat := ShaderMaterial.new()
	wmat.shader = load(OUT_DIR + "/waterfall.gdshader")
	var water: Material = mats["Water"]
	var foam := mat("Foam", Color(0.95, 0.98, 1.0), 0.3, 0.0, 0.4, 0.85)
	for deg in CASTLE_FALLS:
		var d := Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))
		var top_p := hill + d * (CASTLE_HILL_TOP + 0.5)
		var bottom_p := hill + d * (CASTLE_HILL_TOP + 7.5)
		var top_y := height(top_p.x, top_p.y) + 0.3
		var drop := top_y - WATER_Y
		var run := top_p.distance_to(bottom_p)
		var q := QuadMesh.new()
		q.size = Vector2(6.0, sqrt(drop * drop + run * run))
		var midp := (top_p + bottom_p) / 2.0
		mesh_at(q, wmat, Vector3(midp.x, (top_y + WATER_Y) / 2.0, midp.y), g, atan2(d.x, d.y), Vector3(-atan2(run, drop), 0, 0))
		mesh_at(cylinder(3.6, 4.6, 0.3, 20), foam, Vector3(bottom_p.x + d.x * 1.5, WATER_Y + 0.1, bottom_p.y + d.y * 1.5), g)
		# a little stream along the top, from the castle's wall to the edge
		var src := hill + d * (CASTLE_HILL_TOP - 3.0)
		var sm := box(Vector3(1.6, 0.2, src.distance_to(top_p) + 0.6))
		mesh_at(sm, water, Vector3((src.x + top_p.x) / 2.0, top_y - 0.32, (src.y + top_p.y) / 2.0), g, atan2(d.x, d.y))
	var ponds := castle_ponds()
	for pond in ponds:
		var disc := mesh_at(cylinder(1.0, 1.0, 0.1, 40), water, Vector3(pond.x, WATER_Y, pond.y), g)
		disc.scale = Vector3(pond.z * 1.08, 1.0, pond.w * 1.08)
	var pond_water := Node3D.new()                 # wading in them works like the lake (scripts/water.gd)
	pond_water.name = "Ponds"
	pond_water.set_script(load("res://scripts/water.gd"))
	pond_water.set("ellipses", ponds)
	pond_water.set("water_y", WATER_Y)
	g.add_child(pond_water)

	# Lamp posts up both sides of the path to the gate
	var lamp_line := [Vector2(4, -62), Vector2(20, -82), Vector2(castle_gate.x, castle_gate.z)]
	var post := mat("Castle Lamp Post", Color(0.35, 0.3, 0.42), 0.4, 0.6, 0.0, 1.0, false)
	var bulb := mat("Lamp", Color(1.0, 0.92, 0.6), 0.3, 0.0, 2.0)
	for k in lamp_line.size() - 1:
		var a: Vector2 = lamp_line[k]
		var b: Vector2 = lamp_line[k + 1]
		var n := int(a.distance_to(b) / 8.0)
		var across := Vector2((b - a).y, -(b - a).x).normalized()
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			for s in [-1.0, 1.0]:
				var q: Vector2 = p + across * 2.8 * s
				var base := ground(q.x, q.y)
				mesh_at(cylinder(0.07, 0.1, 3.2, 8), post, base + Vector3(0, 1.6, 0), g)
				mesh_at(sphere(0.26, -1, 12), bulb, base + Vector3(0, 3.35, 0), g)
				night_light(g, base + Vector3(0, 3.3, 0), Color(1.0, 0.85, 0.55), 1.0, 7.0)

	# Flowering bushes and cypresses: along the path, round the castle's terrace and round the ponds
	var blooms := [mat("Bloom Red", Color(0.92, 0.16, 0.28), 0.8, 0.0, 0.0, 1.0, false),
		mat("Bloom Pink", Color(0.98, 0.42, 0.68), 0.8, 0.0, 0.0, 1.0, false),
		mat("Bloom Coral", Color(1.0, 0.45, 0.35), 0.8, 0.0, 0.0, 1.0, false),
		mat("Bloom Magenta", Color(0.85, 0.2, 0.62), 0.8, 0.0, 0.0, 1.0, false)]
	var leaf := mat("Cypress", Color(0.1, 0.36, 0.28), 0.9, 0.0, 0.0, 1.0, false)
	var bark := mat("Cypress Bark", Color(0.3, 0.2, 0.16), 0.9, 0.0, 0.0, 1.0, false)
	var spots: Array[Vector3] = []                  # x, z, 1 = cypress / 0 = bush
	for k in lamp_line.size() - 1:
		var a: Vector2 = lamp_line[k]
		var b: Vector2 = lamp_line[k + 1]
		var across := Vector2((b - a).y, -(b - a).x).normalized()
		for i in int(a.distance_to(b) / 2.2):
			var p: Vector2 = a.lerp(b, rng.randf()) + across * rng.randf_range(4.0, 8.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			spots.append(Vector3(p.x, p.y, 1.0 if rng.randf() < 0.12 else 0.0))
	for i in 170:
		var a := rng.randf() * TAU
		var p := hill + Vector2(cos(a), sin(a)) * rng.randf_range(CASTLE_HILL_TOP - 7.0, CASTLE_HILL_TOP + 0.3)
		spots.append(Vector3(p.x, p.y, 1.0 if rng.randf() < 0.22 else 0.0))
	for pond in ponds:
		for i in 26:
			var a := rng.randf() * TAU
			var f := rng.randf_range(1.2, 1.55)
			spots.append(Vector3(pond.x + cos(a) * pond.z * f, pond.y + sin(a) * pond.w * f, 1.0 if rng.randf() < 0.25 else 0.0))
	var placed := 0
	for sp in spots:
		var p := Vector2(sp.x, sp.y)
		if not _garden_ok(p):
			continue
		var base := ground(p.x, p.y) - Vector3(0, 0.2, 0)
		if sp.z > 0.5:
			var hgt := rng.randf_range(6.0, 9.5)
			_prim(surfaces, bark, cylinder(0.18, 0.25, 1.6, 8), Transform3D(Basis(), base + Vector3(0, 0.8, 0)), false)
			_prim(surfaces, leaf, sphere(1.15, hgt, 14), Transform3D(Basis(), base + Vector3(0, 1.0 + hgt / 2.0, 0)), false)
		else:
			var m: Material = blooms[rng.randi() % blooms.size()]
			for b in rng.randi_range(2, 4):
				var r := rng.randf_range(0.55, 1.05)
				var off := Vector3(rng.randf_range(-0.9, 0.9), r * 0.6, rng.randf_range(-0.9, 0.9))
				_prim(surfaces, m, sphere(r, r * 1.5, 12), Transform3D(Basis(), base + off), false)
		placed += 1
	var mesh := ArrayMesh.new()
	for m in surfaces:
		(surfaces[m] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	save_external(mesh, "castle_gardens.res")
	var mi := MeshInstance3D.new()
	mi.name = "Gardens"
	mi.mesh = mesh
	g.add_child(mi)
	own(g)
	print("CASTLE gardens ", placed)


func _garden_ok(p: Vector2) -> bool:
	# Somewhere a bush or cypress can grow: not in the castle, its halls, the water, the path or its doorway
	if Geometry2D.is_point_in_polygon(p, castle_outline):
		return false
	for i in castle_outline.size():
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, castle_outline[i - 1], castle_outline[i])) < 2.5:
			return false
	for c in castle_spots:
		if p.distance_to(Vector2(c.x, c.y)) < c.z:
			return false
	if lake_f(p.x, p.y) < 1.15 or on_path(p.x, p.y, 3.2) or p.distance_to(Vector2(castle_gate.x, castle_gate.z)) < 9.0:
		return false
	var slope := Vector2(height(p.x + 1, p.y) - height(p.x - 1, p.y), height(p.x, p.y + 1) - height(p.x, p.y - 1)).length() / 2.0
	return slope < 0.7                               # not on the cliff


func _plateau_features() -> void:
	# Secret Gardens: greenhouse and garden plots on top of the plateau
	var top := ground(PLATEAU.x - 2, PLATEAU.y - 6)
	var g := group("Secret Gardens", top)
	var glass := mat("Greenhouse Glass", Color(0.7, 0.95, 1.0), 0.05, 0.0, 0.0, 0.35)
	var frame := mat("Greenhouse Frame", Color(0.9, 0.92, 0.95), 0.4, 0.4)
	mesh_at(box(Vector3(12, 5, 8)), glass, Vector3(0, 2.5, 0), g)
	mesh_at(box(Vector3(12.2, 0.3, 8.2)), frame, Vector3(0, 5.0, 0), g)
	solid(box_shape(Vector3(12, 5, 8)), Vector3(0, 2.5, 0), g)
	var soil := mat("Garden Soil", Color(0.4, 0.26, 0.14))
	var leaf := mat("Garden Leaf", Color(0.25, 0.65, 0.2))
	for row in 4:
		var pz := 9.0 + row * 3.0
		mesh_at(box(Vector3(14, 0.5, 1.6)), soil, Vector3(0, 0.2, pz), g)
		for k in 7:
			mesh_at(sphere(0.6, -1, 12), leaf, Vector3(-6 + k * 2, 0.7, pz), g)
	sign_post(g, "Secret Gardens", Vector3(9, 0, 6), 0.3)
	keep_clear.append(Vector3(PLATEAU.x - 2, PLATEAU.y + 2, 16))
	own(g)

	# Hot Springs: glowing caves in the plateau's south face
	var hs := group("Hot Springs", Vector3.ZERO)
	var cave := mat("Cave", Color(0.12, 0.08, 0.07))
	var rock := mat("Cave Rock", Color(0.5, 0.48, 0.45), 0.95)
	var fire := mat("Cave Glow", Color(1.0, 0.45, 0.1), 0.5, 0.0, 3.0)
	var steam := mat("Spring Water", Color(0.55, 0.85, 0.95), 0.1, 0.0, 0.3, 0.8)
	for cx in [-80.0, -71.0, -62.0]:                 # along the south cliff, east of the ramp
		var dz := sqrt(pow(PLATEAU_CLIFF + 1.5, 2) - pow(cx - PLATEAU.x, 2))
		var p := ground(cx, PLATEAU.y + dz)
		mesh_at(cylinder(3.2, 3.2, 2.5, 24), rock, p + Vector3(0, 1.0, 0), hs, 0.0, Vector3(PI / 2, 0, 0))
		mesh_at(cylinder(2.4, 2.4, 2.7, 24), cave, p + Vector3(0, 1.0, 0.1), hs, 0.0, Vector3(PI / 2, 0, 0))
		mesh_at(sphere(0.8, -1, 12), fire, p + Vector3(0, 0.6, -0.6), hs)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 3.0
		light.omni_range = 8.0
		light.position = p + Vector3(0, 1.2, 1.5)
		hs.add_child(light)
		var pool := ground(cx, PLATEAU.y + dz + 4.0)          # on the ground in front of the cave (not up on the cliff)
		mesh_at(cylinder(2.2, 2.2, 0.15, 24), steam, pool + Vector3(0, 0.05, 0), hs)
		soft_zone(hs, "spring", pool + Vector3(0, -0.3, 0), 2.3, 2.0, Color(1, 1, 1, 0.55), 0.85, 1.0, 1000.0, 2.0)
	sign_post(hs, "Hot Springs", ground(-73, PLATEAU.y + PLATEAU_CLIFF + 7), 0.0)
	keep_clear.append(Vector3(-78, -4, 18))
	own(hs)

	# Waterfalls from the plateau into the lakes
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(0.75, 0.92, 1.0, 0.85);
void fragment() {
	float s = fract(UV.y * 5.0 + UV.x * 0.7 - TIME * 1.4);
	ALBEDO = mix(color.rgb, vec3(1.0), smoothstep(0.75, 1.0, s) * 0.7);
	ALPHA = color.a;
}"""
	ResourceSaver.save(shader, OUT_DIR + "/waterfall.gdshader", ResourceSaver.FLAG_CHANGE_PATH)
	var wmat := ShaderMaterial.new()
	wmat.shader = shader
	var wf := group("Waterfalls", Vector3.ZERO)
	var falls := 0
	for w in [Vector2(0.15, 7.0), Vector2(0.55, 5.0)]:   # angle around the plateau (radians from east), width
		falls += 1
		var dirv := Vector2(cos(w.x), sin(w.x))
		var edge := Vector2(PLATEAU.x, PLATEAU.y) + dirv * (PLATEAU_CLIFF + 0.5)
		var top_y := PLATEAU.z + 0.3
		var bottom_y := height(edge.x + dirv.x * 4, edge.y + dirv.y * 4)
		var h := top_y - bottom_y
		var q := QuadMesh.new()
		q.size = Vector2(w.y, h)
		mesh_at(q, wmat, Vector3(edge.x, bottom_y + h / 2, edge.y), wf, atan2(dirv.x, dirv.y))
		mesh_at(cylinder(w.y * 0.6, w.y * 0.8, 0.4, 16), mat("Foam", Color(0.95, 0.98, 1.0), 0.3, 0.0, 0.4, 0.85),
			Vector3(edge.x + dirv.x * 2.5, bottom_y + 0.1, edge.y + dirv.y * 2.5), wf)
		var foot := Vector3(edge.x + dirv.x * 2.5, bottom_y + 0.4, edge.y + dirv.y * 2.5)
		var mist := CPUParticles3D.new()                    # spray drifting up off the splash
		mist.name = "Mist %d" % falls
		mist.position = foot
		mist.amount = 40
		mist.lifetime = 2.2
		mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		mist.emission_sphere_radius = w.y * 0.5
		mist.direction = Vector3(dirv.x, 1.2, dirv.y)
		mist.spread = 35.0
		mist.initial_velocity_min = 0.6
		mist.initial_velocity_max = 1.6
		mist.gravity = Vector3(0, 0.3, 0)
		var mist_ball := sphere(0.35, -1, 6)
		mist_ball.material = mat("Mist", Color(0.9, 0.97, 1.0), 0.5, 0.0, 0.3, 0.35, false)
		mist.mesh = mist_ball
		var fade := Curve.new()
		fade.add_point(Vector2(0, 0.3))
		fade.add_point(Vector2(0.3, 1))
		fade.add_point(Vector2(1, 0))
		mist.scale_amount_curve = fade
		wf.add_child(mist)
		var rush := AudioStreamPlayer3D.new()               # the rushing sound, loudest close by
		rush.name = "Rush %d" % falls
		rush.set_script(load("res://scripts/ambient_loop.gd"))
		rush.set("sound", "waterfall")
		rush.position = foot
		rush.unit_size = 6.0
		rush.max_distance = 45.0
		rush.volume_db = -4.0
		wf.add_child(rush)
	own(wf)


func mushroom_tower(name: String, x: float, z: float, h: float, gold := false) -> void:
	# gold: keep the yellow and blue of Sofi's picture instead of the world theme (the ones beside the castle)
	var g := group(name, ground(x, z))
	var k := " Gold" if gold else ""
	var yellow := mat("Tower Yellow" + k, Color(0.98, 0.8, 0.25), 0.5, 0.0, 0.0, 1.0, not gold)
	var band := mat("Tower Band" + k, Color(0.85, 0.55, 0.1), 0.6, 0.0, 0.0, 1.0, not gold)
	var cap_glass := mat("Tower Glass" + k, Color(0.35, 0.75, 1.0), 0.05, 0.1, 0.4, 0.7, not gold)
	mesh_at(cylinder(0.9, 1.4, h, 16), yellow, Vector3(0, h / 2, 0), g)
	solid(_cyl_shape(1.4, h), Vector3(0, h / 2, 0), g)
	mesh_at(cylinder(4.5, 3.2, 1.0, 32), yellow, Vector3(0, h + 0.4, 0), g)
	mesh_at(cylinder(4.6, 4.6, 0.3, 32), band, Vector3(0, h + 0.95, 0), g)
	mesh_at(sphere(2.0, 2.4, 24), cap_glass, Vector3(0, h + 1.3, 0), g)
	mesh_at(cylinder(0.0, 0.25, 2.0, 8), yellow, Vector3(0, h + 3.4, 0), g)
	keep_clear.append(Vector3(x, z, 6))
	own(g)


func _towers() -> void:
	mushroom_tower("Tower", -92, -58, 26)
	mushroom_tower("Tower 2", -74, -64, 20)
	mushroom_tower("Tower 3", -104, -38, 16)
	mushroom_tower("Tower 4", 104, -60, 22)
	mushroom_tower("Tower 5", 48, -78, 18)
	# Golden ones flanking the castle school, as in Sofi's picture
	mushroom_tower("Castle Tower West", -60, -112, 24, true)
	mushroom_tower("Castle Tower East", 80, -118, 20, true)
	mushroom_tower("Castle Tower Back", -50, -190, 28, true)


func court(name: String, x: float, z: float, size: Vector2, color: Color, basketball: bool, pickleball := false) -> void:
	var g := group(name, ground(x, z))
	mesh_at(box(Vector3(size.x + 3, 0.3, size.y + 3)), mat("Court Edge", Color(0.3, 0.55, 0.35)), Vector3(0, 0.05, 0), g)
	mesh_at(box(Vector3(size.x, 0.32, size.y)), mat("Court " + name, color, 0.7), Vector3(0, 0.07, 0), g)
	solid(box_shape(Vector3(size.x + 3, 0.4, size.y + 3)), Vector3(0, 0.05, 0), g)
	var line := mat("Court Line", Color(1, 1, 1), 0.6)
	mesh_at(box(Vector3(0.12, 0.34, size.y)), line, Vector3(0, 0.08, 0), g)
	mesh_at(box(Vector3(size.x, 0.34, 0.12)), line, Vector3(0, 0.08, size.y / 2 - 0.06), g)
	mesh_at(box(Vector3(size.x, 0.34, 0.12)), line, Vector3(0, 0.08, -size.y / 2 + 0.06), g)
	var metal := mat("Court Metal", Color(0.75, 0.76, 0.8), 0.4, 0.7)
	if basketball:
		for s in [-1, 1]:
			var px: float = s * (size.x / 2 - 1)
			mesh_at(cylinder(0.12, 0.12, 3.4, 8), metal, Vector3(px, 1.7, 0), g)
			mesh_at(box(Vector3(0.1, 1.1, 1.8)), mat("Backboard", Color(1, 1, 1), 0.3), Vector3(px - s * 0.2, 3.3, 0), g)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.22
			ring.outer_radius = 0.27
			mesh_at(ring, mat("Hoop", Color(1.0, 0.4, 0.1), 0.4, 0.5), Vector3(px - s * 0.55, 3.0, 0), g)
	else:
		mesh_at(box(Vector3(0.08, 1.0, size.y)), mat("Net", Color(0.95, 0.95, 0.95), 0.6, 0.0, 0.0, 0.6),
			Vector3(0, 0.6, 0), g)
		for s in [-1, 1]:
			mesh_at(cylinder(0.06, 0.06, 1.2, 8), metal, Vector3(0, 0.6, s * size.y / 2), g)
	if pickleball:
		# A smaller pickleball court painted inside the tennis court, in its own colour
		var pl := mat("Pickleball Line", Color(1.0, 0.85, 0.2), 0.6)
		var p := size * Vector2(0.56, 0.56)
		mesh_at(box(Vector3(p.x, 0.36, p.y)), mat("Pickleball Court", Color(0.35, 0.75, 0.5), 0.7), Vector3(0, 0.075, 0), g)
		for s in [-1, 1]:
			mesh_at(box(Vector3(p.x, 0.38, 0.1)), pl, Vector3(0, 0.08, s * p.y / 2), g)
			mesh_at(box(Vector3(0.1, 0.38, p.y)), pl, Vector3(s * p.x / 2, 0.08, 0), g)
			mesh_at(box(Vector3(0.1, 0.38, p.y)), pl, Vector3(s * p.x * 0.16, 0.08, 0), g)     # kitchen lines
	var label := "Basketball Court" if basketball else ("Tennis & Pickleball" if pickleball else "Tennis Court")
	sign_post(g, label, Vector3(0, 0, size.y / 2 + 2.5), 0.0)
	keep_clear.append(Vector3(x, z, maxf(size.x, size.y) / 2 + 3))
	own(g)


func _courts() -> void:
	court("Basketball Court", 96, 56, Vector2(28, 15), Color(0.25, 0.55, 0.9), true)
	court("Tennis Court", 112, 77, Vector2(24, 11), Color(0.3, 0.62, 0.95), false, true)


func _skate_park() -> void:
	var c := ground(SKATE.x, SKATE.y)
	var g := group("Skate Park", c)
	var colors := [Color(0.98, 0.7, 0.8), Color(0.75, 0.7, 0.98), Color(0.7, 0.9, 0.98), Color(0.98, 0.9, 0.65),
		Color(0.75, 0.95, 0.75), Color(0.98, 0.78, 0.6)]
	for k in colors.size():                      # pastel rings
		var r := 13.0 - k * 2.0
		mesh_at(cylinder(r, r, 0.3, 48), mat("Skate " + str(k), colors[k], 0.6), Vector3(0, 0.08 + k * 0.01, 0), g)
	solid(_cyl_shape(13, 0.4), Vector3(0, 0.05, 0), g)
	var ramp := mat("Ramp", Color(0.85, 0.82, 0.9), 0.5)
	for r in [Vector4(-6, 0, 0, 0.3), Vector4(6, 0, PI, 0.3), Vector4(0, -7, PI / 2, 0.4)]:   # x, z, yaw, tilt
		mesh_at(box(Vector3(4, 0.4, 5)), ramp, Vector3(r.x, 0.9, r.y), g, r.z, Vector3(r.w, 0, 0))
		solid(box_shape(Vector3(4, 0.4, 5)), Vector3(r.x, 0.9, r.y), g, r.z, Vector3(r.w, 0, 0))
	sign_post(g, "Skate Park", Vector3(9, 0, 10), -0.4)
	# The skateboard waiting to be picked up (scripts/pickup.gd); gone once she owns it
	var pick := Area3D.new()
	pick.name = "SkateboardPickup"
	pick.set_script(load("res://scripts/pickup.gd"))
	pick.set("item", "skateboard")
	pick.position = Vector3(0, 0.4, 4)
	var pcs := CollisionShape3D.new()
	pcs.shape = _sphere_shape(1.2)
	pick.add_child(pcs)
	var board: Node3D = load("res://scenes/items/skateboard.tscn").instantiate()
	board.scale = Vector3.ONE * 1.6
	pick.add_child(board)
	g.add_child(pick)
	keep_clear.append(Vector3(-8, 42, 16))
	own(g)


func _sports_sign() -> void:
	# The sign from Sofi's picture, at the way into Sports & Play
	var g := group("Sports Sign", ground(36, 50))
	sign_post(g, "Dream  Play  Explore  Grow", Vector3.ZERO, -0.6)
	own(g)


func _boats() -> void:
	var g := group("Sailboats", Vector3.ZERO)
	var hull := mat("Boat Hull", Color(0.95, 0.95, 0.95), 0.5)
	var sails := [Color(0.98, 0.85, 0.2), Color(0.95, 0.5, 0.8), Color(0.75, 0.55, 0.95)]
	var spots := [Vector3(12, 4, 0.3), Vector3(-22, -4, 1.2), Vector3(26, -8, 2.0), Vector3(-25, -33, 0.8), Vector3(5, -34, 2.5)]
	for k in spots.size():
		var s: Vector3 = spots[k]
		var boat := Node3D.new()
		boat.position = Vector3(s.x, WATER_Y + 0.15, s.y)
		boat.rotation.y = s.z
		g.add_child(boat)
		mesh_at(box(Vector3(1.0, 0.4, 2.6)), hull, Vector3.ZERO, boat)
		var sail := PrismMesh.new()
		sail.size = Vector3(0.1, 2.4, 1.8)
		sail.left_to_right = 1.0
		mesh_at(sail, mat("Sail " + str(k % 3), sails[k % 3], 0.6), Vector3(0, 1.5, 0), boat)
	own(g)


func _mountains() -> void:
	var g := group("Mountains", Vector3.ZERO)
	var far := mat("Mountain", T.mountain_far, 1.0 if THEME == "earth" else 0.35, 0.0 if THEME == "earth" else 0.3, 0.0, 1.0, false)
	var near := mat("Mountain Near", T.mountain_near, 1.0 if THEME == "earth" else 0.35, 0.0 if THEME == "earth" else 0.3, 0.0, 1.0, false)
	var peaks := mountain_peaks()
	for k in peaks.size():
		var peak: Array = peaks[k]
		var p: Vector3 = peak[0]
		var h: float = peak[1]
		mesh_at(cylinder(0.0, h * 0.75, h, T.mountain_sides), far if k % 2 == 0 else near, p + Vector3(0, h / 2, 0), g,
			peak[2])
	own(g)


static func mountain_peaks() -> Array:
	# The ring of mountains to the north: [foot position, height, turn] each. The school's 3rd-floor window shows the
	# same peaks (tools/build_school.gd).
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 22:
		var a := lerpf(-PI * 0.95, -PI * 0.05, k / 21.0) + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(260, 310)
		var h := rng.randf_range(55, 110)
		var p := Vector3(cos(a) * dist, -5, sin(a) * dist - 60)   # well behind the castle hill
		out.append([p, h, rng.randf() * TAU])
	return out


func _sky_objects() -> void:
	# A huge ringed planet low in the northeast sky, and two small moons. Unshaded so they glow like sky objects.
	if not T.moons:
		return
	var g := group("Sky Objects", Vector3.ZERO)
	var bodies := [
		# position, radius, color
		[Vector3(420, 140, -520), 95.0, Color(0.55, 0.85, 0.95)],
		[Vector3(-380, 230, -430), 22.0, Color(1.0, 0.75, 0.85)],
		[Vector3(-250, 300, -560), 12.0, Color(0.85, 0.95, 0.7)],
	]
	for k in bodies.size():
		var b: Array = bodies[k]
		var m := StandardMaterial3D.new()
		m.resource_name = "Sky Body " + str(k)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = b[2]
		m.disable_fog = true
		var mi := mesh_at(sphere(b[1], -1, 48), m, b[0], g)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k == 0:
			# Bands across the planet, and its ring
			var band := StandardMaterial3D.new()
			band.resource_name = "Planet Band"
			band.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			band.albedo_color = Color(0.4, 0.62, 0.9)
			band.disable_fog = true
			for y in [-35.0, 18.0, 52.0]:
				var r := sqrt(pow(b[1] + 0.6, 2) - y * y)
				var bm := mesh_at(cylinder(r, r, 9.0, 64), band, b[0] + Vector3(0, y, 0), g)
				bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ring := TorusMesh.new()
			ring.inner_radius = b[1] * 1.35
			ring.outer_radius = b[1] * 1.9
			ring.rings = 96
			var rm := StandardMaterial3D.new()
			rm.resource_name = "Planet Ring"
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.albedo_color = Color(0.95, 0.85, 0.7, 0.75)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rm.disable_fog = true
			var ri := mesh_at(ring, rm, b[0], g, 0.0, Vector3(0.35, 0.0, -0.3))
			ri.scale = Vector3(1, 0.04, 1)
			ri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds(g)
	own(g)


func _clouds(g: Node3D) -> void:
	# Long cream streaks of cloud, as in the green sky picture. They fade out at night (scripts/day_night.gd).
	var m := StandardMaterial3D.new()
	m.resource_name = "Sky Cloud"
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.99, 0.93, 0.72, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	for s: Array in cloud_streaks():
		var mi := mesh_at(sphere(1.0, -1, 24), m, s[0], g, s[1], Vector3(0, 0, s[2]))
		mi.scale = s[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func cloud_streaks() -> Array:
	# [position, turn, tip, scale] for each streak of cloud. The school's 3rd-floor window shows them too.
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 22:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(260.0, 480.0)
		# Long and thin, turned to face the town so they read as streaks across the sky, tipped a little
		var p := Vector3(cos(a) * dist, rng.randf_range(110.0, 240.0), sin(a) * dist - 60.0)
		var tip := rng.randf_range(-0.3, 0.3)
		out.append([p, atan2(-cos(a), -sin(a)), tip, Vector3(rng.randf_range(50.0, 120.0), rng.randf_range(3.0, 7.0), 2.0)])
	return out


func _mothership() -> void:
	# The mothership cruising round high over the town (scenes/vehicles/mothership.tscn, scripts/mothership.gd)
	var ship: Node3D = load("res://scenes/vehicles/mothership.tscn").instantiate()
	ship.position = Vector3(140, 95, -60)
	town.add_child(ship)
	ship.owner = town
	# The Mothership Pad, where Nina calls it down to fly it (scripts/mothership_pad.gd): a round metal landing pad
	# with three glowing rings, low enough to walk straight onto
	var g := group("Mothership Pad", ground(MOTHERSHIP_PAD.x, MOTHERSHIP_PAD.y))
	var metal := mat("Pad Metal", Color(0.72, 0.75, 0.82), 0.35, 0.6)
	mesh_at(cylinder(4.0, 4.3, 0.4, 40), metal, Vector3(0, -0.1, 0), g)
	solid(_cyl_shape(4.0, 0.4), Vector3(0, -0.1, 0), g)
	var glow := mat("Pad Ring", Color(0.5, 0.88, 1.0), 0.3, 0.0, 1.6, 1.0, false)   # the same blue as the ship's lights
	for k in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 1.0 + k * 1.1
		ring.outer_radius = 1.25 + k * 1.1
		ring.rings = 48
		var mi := mesh_at(ring, glow, Vector3(0, 0.11, 0), g)
		mi.name = "Pad Ring %d" % (k + 1)
	var pad_area := Area3D.new()
	pad_area.name = "PadCall"
	pad_area.set_script(load("res://scripts/mothership_pad.gd"))
	pad_area.position = Vector3(0, 1.1, 0)                  # 1 m over the pad's top (its ground_offset)
	var cs := CollisionShape3D.new()
	cs.shape = _cyl_shape(4.0, 2.2)
	pad_area.add_child(cs)
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.font_size = 44
	prompt.pixel_size = 0.01
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0.15, 0.1, 0.12)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.position = Vector3(0, 1.4, 0)
	pad_area.add_child(prompt)
	g.add_child(pad_area)
	sign_post(g, "Mothership Pad", Vector3(-5.5, 0, 2.5), -0.5)
	keep_clear.append(Vector3(MOTHERSHIP_PAD.x, MOTHERSHIP_PAD.y, 8))
	own(g)


func _crystals() -> void:
	# Clusters of glowing crystal shards scattered across the land (solid: you can hop on the big ones)
	var count: int = T.crystals
	if count == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var tints := [Color(0.3, 0.95, 1.0), Color(1.0, 0.35, 0.85), Color(0.7, 0.45, 1.0), Color(0.45, 1.0, 0.6)]
	var g := group("Crystals", Vector3.ZERO)
	var placed := 0
	var tries := 0
	while placed < count and tries < 4000:
		tries += 1
		var x := rng.randf_range(X_MIN + 12, X_MAX - 12)
		var z := rng.randf_range(Z_MIN + 12, Z_MAX - 12)
		if lake_f(x, z) < 1.5 or not _clear_spot(x, z, 1.5, 14.0):        # not on paths or in buildings' space
			continue
		var ok := true
		for c in keep_clear:
			if Vector2(x - c.x, z - c.y).length() < c.z:
				ok = false
				break
		if not ok:
			continue
		var tint: Color = tints[rng.randi() % tints.size()]
		var m := mat("Crystal " + str(tints.find(tint)), tint, 0.1, 0.2, 1.1, 0.9, false)
		var cluster := Node3D.new()
		cluster.position = ground(x, z)
		g.add_child(cluster)
		var big := rng.randf() < 0.3
		var shards := rng.randi_range(3, 6)
		for k in shards:
			var h := rng.randf_range(1.8, 4.2) * (2.0 if big and k == 0 else 1.0)
			var r := h * rng.randf_range(0.14, 0.22)
			var off := Vector3.ZERO if k == 0 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * r * 2.2
			var tilt := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35)) * (0.3 if k == 0 else 1.0)
			var shard := Node3D.new()
			shard.position = off
			shard.rotation = tilt + Vector3(0, rng.randf() * TAU, 0)
			cluster.add_child(shard)
			mesh_at(cylinder(0.0, r, h * 0.35, 5), m, Vector3(0, h * 0.825, 0), shard)    # point
			mesh_at(cylinder(r, r * 0.8, h * 0.65, 5), m, Vector3(0, h * 0.325, 0), shard)  # body
			if k == 0:
				solid(_cyl_shape(r, h), Vector3(0, h / 2, 0), shard)
		placed += 1
	own(g)
	print("CRYSTALS ", placed)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var palette: Array = T.trees
	var spots: Array = []
	var tries := 0
	while spots.size() < 320 and tries < 6000:
		tries += 1
		var x := rng.randf_range(X_MIN + 8, X_MAX - 8)
		var z := rng.randf_range(Z_MIN + 8, Z_MAX - 8)
		if lake_f(x, z) < 1.45:
			continue
		var ok := true
		for c in keep_clear:
			if Vector2(x - c.x, z - c.y).length() < c.z:
				ok = false
				break
		if ok and (Vector2(x - SPAWN.x, z - SPAWN.z).length() < 10 or on_path(x, z, 3.0)):
			ok = false
		if ok:
			spots.append(Vector3(x, height(x, z), z))
	# The trees build themselves at load time from these lists (see scenes/town/trees.gd)
	var g := group("Trees", Vector3.ZERO)
	g.set_script(load("res://scenes/town/trees.gd"))
	var positions := PackedVector3Array()
	var sizes := PackedFloat32Array()
	var colors := PackedColorArray()
	for p in spots:
		positions.append(p)
		sizes.append(rng.randf_range(1.2, 2.6))
		colors.append(palette[rng.randi() % palette.size()])
	g.set("positions", positions)
	g.set("sizes", sizes)
	g.set("colors", colors)
	g.set("bark_color", T.bark)
	g.set("glow", T.tree_glow)
	g.set("canopy_stretch", T.canopy_stretch)
	own(g)
	print("TREES ", spots.size())


func _clear_spot(x: float, z: float, lake_margin: float, spawn_r: float) -> bool:
	if lake_f(x, z) < lake_margin or Vector2(x - SPAWN.x, z - SPAWN.z).length() < spawn_r:
		return false
	if x < X_MIN + 6 or x > X_MAX - 6 or z < Z_MIN + 6 or z > Z_MAX - 6:
		return false
	for c in keep_clear:
		if Vector2(x - c.x, z - c.y).length() < c.z:
			return false
	return not on_path(x, z, 3.0)                     # keep the main paths clear of plants and crystals


func _foliage() -> void:
	# Alien undergrowth (palette in tools/theme.gd): patches of giant leaves, ferns and glowing mushrooms all over the
	# land, plus loose ferns and leaves in between. Plants build themselves at load time (scenes/town/foliage.gd).
	var pal: Dictionary = WT.foliage()
	if pal.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var positions := PackedVector3Array()
	var kinds := PackedInt32Array()
	var sizes := PackedFloat32Array()
	var yaws := PackedFloat32Array()
	var colors := PackedColorArray()
	var counts := [0, 0, 0, 0]
	var plant := func(kind: int, x: float, z: float, size: float, color: Color) -> void:
		positions.append(ground(x, z))
		kinds.append(kind)
		sizes.append(size)
		yaws.append(rng.randf() * TAU)
		colors.append(color)
		counts[kind] += 1
	var leaves: Array = pal.leaves
	var ferns: Array = pal.ferns
	var caps: Array = pal.mushroom_caps

	# Patches: a few of each kind huddled together, like the corner of Sofi's picture
	var patches := 0
	var tries := 0
	while patches < 120 and tries < 5000:
		tries += 1
		var cx := rng.randf_range(X_MIN + 10, X_MAX - 10)
		var cz := rng.randf_range(Z_MIN + 10, Z_MAX - 10)
		if not _clear_spot(cx, cz, 1.3, 12.0):
			continue
		patches += 1
		var radius := rng.randf_range(4.0, 9.0)
		var leaf_col: Color = leaves[rng.randi() % leaves.size()]
		var fern_col: Color = ferns[rng.randi() % ferns.size()]
		var cap_col: Color = caps[rng.randi() % caps.size()]
		var want := [rng.randi_range(2, 4), rng.randi_range(3, 7), rng.randi_range(0, 4) if rng.randf() < 0.75 else 0]
		var big_mushroom := rng.randf() < 0.4
		for kind in 3:
			for k in want[kind]:
				var a := rng.randf() * TAU
				var d := sqrt(rng.randf()) * radius
				var x := cx + cos(a) * d
				var z := cz + sin(a) * d
				if not _clear_spot(x, z, 1.25 if kind == 1 else 1.35, 9.0):
					continue
				match kind:
					0:
						var c: Color = leaf_col if rng.randf() < 0.6 else leaves[rng.randi() % leaves.size()]
						plant.call(0, x, z, rng.randf_range(2.4, 4.6), c)
					1:
						plant.call(1, x, z, rng.randf_range(0.9, 1.8), fern_col if rng.randf() < 0.7 else ferns[rng.randi() % ferns.size()])
					2:
						var s := rng.randf_range(2.4, 4.2) if big_mushroom and k == 0 else rng.randf_range(0.5, 1.6)
						plant.call(2, x, z, s, cap_col)
	# Loose ferns and leaf clumps in between
	tries = 0
	var loose := 0
	while loose < 320 and tries < 5000:
		tries += 1
		var x := rng.randf_range(X_MIN + 8, X_MAX - 8)
		var z := rng.randf_range(Z_MIN + 8, Z_MAX - 8)
		if not _clear_spot(x, z, 1.25, 8.0):
			continue
		loose += 1
		if rng.randf() < 0.65:
			plant.call(1, x, z, rng.randf_range(0.8, 1.5), ferns[rng.randi() % ferns.size()])
		else:
			plant.call(0, x, z, rng.randf_range(1.8, 3.2), leaves[rng.randi() % leaves.size()])

	# Tall grass in the open meadows: clumps you can run through (they sway, part and swish)
	var grass_cols := [T.grass.lightened(0.25), T.hill_grass.lightened(0.3), T.grass.lerp(Color(0.6, 1.0, 0.5), 0.35)]
	for patch in GRASS_PATCHES:
		var n := int(PI * patch.z * patch.z / 1.6)
		for k in n:
			var a := rng.randf() * TAU
			var d: float = sqrt(rng.randf()) * patch.z
			var x: float = patch.x + cos(a) * d
			var z: float = patch.y + sin(a) * d
			if not _clear_spot(x, z, 1.3, 6.0):
				continue
			plant.call(3, x, z, rng.randf_range(0.9, 1.45), grass_cols[rng.randi() % grass_cols.size()])

	var g := group("Foliage", Vector3.ZERO)
	g.set_script(load("res://scenes/town/foliage.gd"))
	g.set("positions", positions)
	g.set("kinds", kinds)
	g.set("sizes", sizes)
	g.set("yaws", yaws)
	g.set("colors", colors)
	g.set("stem_color", pal.mushroom_stem)
	own(g)
	print("FOLIAGE leaves=%d ferns=%d mushrooms=%d grass=%d" % counts)


func _enemies() -> void:
	# Gloops (scenes/enemies/gloop.tscn) in small packs out in the meadows, and big ones guarding the plateau.
	# x, z, big?  Spots in the lake, inside a building's clear zone or near the spawn are skipped with a warning.
	var spots := [
		# Far south meadow
		Vector3(20, 100, 0), Vector3(-22, 100, 0), Vector3(-5, 102, 0),
		# Far east, past the homes and the Observatory's hill
		Vector3(135, -45, 0), Vector3(132, -62, 0), Vector3(138, 30, 0),
		# Foot of the castle hill
		Vector3(-40, -75, 0), Vector3(-15, -80, 0), Vector3(-2, -66, 0),
		# West fields, past the market
		Vector3(-132, 10, 0), Vector3(-138, -8, 0),
		# On the plateau, around the Secret Gardens: big Gloops
		Vector3(-98, -48, 1), Vector3(-55, -30, 1), Vector3(-95, -25, 1),
	]
	var gloop: PackedScene = load("res://scenes/enemies/gloop.tscn")
	var g := group("Enemies", Vector3.ZERO)
	var placed := 0
	for s in spots:
		var why := ""
		if lake_f(s.x, s.y) < 1.45:
			why = "in the lake"
		elif Vector2(s.x - SPAWN.x, s.y - SPAWN.z).length() < 20:
			why = "too close to the spawn"
		else:
			for c in keep_clear:
				if Vector2(s.x - c.x, s.y - c.y).length() < c.z:
					why = "inside a clear zone at (%d, %d)" % [c.x, c.y]
					break
		if why != "":
			print("SKIPPED Gloop at (%d, %d): %s" % [s.x, s.y, why])
			continue
		var e: Node3D = gloop.instantiate()
		e.name = "Big Gloop %d" % placed if s.z > 0 else "Gloop %d" % placed
		e.position = ground(s.x, s.y) + Vector3(0, 0.3, 0)
		if s.z > 0:
			e.set("size", 1.5)
			e.set("color", Color(0.9, 0.25, 0.55))
			e.set("stomps_to_defeat", 2)
			e.set("damage", 3)
			e.set("xp_reward", 12)
		g.add_child(e)
		placed += 1
	print("GLOOPS ", placed)
	# Crocodillos (scenes/enemies/crocodillo.tscn): by the castle's ponds and off in the wilder corners
	var croc: PackedScene = load("res://scenes/enemies/crocodillo.tscn")
	var crocs := 0
	for c in [Vector2(70, -78), Vector2(-28, -88), Vector2(-122, -62), Vector2(128, -12)]:
		var why := ""
		if lake_f(c.x, c.y) < 1.45:
			why = "in the water"
		else:
			for k in keep_clear:
				if c.distance_to(Vector2(k.x, k.y)) < k.z:
					why = "inside a clear zone at (%d, %d)" % [k.x, k.y]
					break
		if why != "":
			print("SKIPPED Crocodillo at (%d, %d): %s" % [c.x, c.y, why])
			continue
		var e: Node3D = croc.instantiate()
		e.name = "Crocodillo %d" % crocs
		e.position = ground(c.x, c.y) + Vector3(0, 0.2, 0)
		g.add_child(e)
		crocs += 1
	own(g)
	print("CROCODILLOS ", crocs)


func _characters() -> void:
	# Sofi's characters standing around town (scenes/town/characters.tscn, edit their spots there).
	# Trees are kept off the spots they stand on.
	var chars: Node3D = load("res://scenes/town/characters.tscn").instantiate()
	town.add_child(chars)
	chars.owner = town                      # saved as a reference to characters.tscn, not a copy of its insides
	for c in chars.get_children():
		keep_clear.append(Vector3(c.position.x, c.position.z, 4.0))


func _player() -> void:
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = ground(SPAWN.x, SPAWN.z) + Vector3(0, 1.0, 0)
	town.add_child(player)
	player.owner = town                     # saved as a reference to player.tscn, not a copy of its insides


# -----------------------------------------------------------------------------
# Places from the show (story/show-notes.md): Mr. Palmer's town map, the pilot's haunted house and cloud water slide,
# the happy places, and the portal to Earth. The town itself is Galaxity.
# -----------------------------------------------------------------------------
const TOWN_HALL := Vector3(-72, 16, 0.0)          # x, z, yaw (head of the Market Square, door facing the fountain)
const HAUNTED_HOUSE := Vector3(-112, -128, 0.82)  # x, z, yaw (off in the far northwest woods, door facing the town)
const PORTAL := Vector3(36, 13, -1.1)             # x, z, yaw (on the lake shore by the dock, facing the promenade)
const TREE_HOUSE := Vector2(122, 2)               # at the housing district's east edge
const ZIPLINE_END := Vector2(86, 9)               # lands in the neighbourhood park (the cable runs between the houses)
const ROCK_WALL := Vector3(126, 58, -PI / 2)      # x, z, yaw (climbing face looks west)
const CLOUD_NEST := Vector2(-60, -50)             # above the plateau, a few cloud hops up from the Secret Gardens
const BUBBLE_BATH := Vector2(-60, 5)
const MURAL := Vector3(50, 40, 0.0)               # x, z, yaw (painted side faces the skate park, south of it)
const SOCCER := Vector2(78, 90)
const SLIDE_CLOUD := Vector3(-28, 6, 20)          # x, z, height: the cloud the water slide starts from, over the lake
const SLIDE_FLAG := "cloud_slide"                 # Game item that unlocks it (the end of the pilot story)


func door(parent: Node3D, destination: String, place_name: String, pos: Vector3, size: Vector3) -> void:
	# A doorway trigger (scripts/door.gd), plus the marker you come back out at, in front of it
	var area := Area3D.new()
	area.name = "Door"
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", destination)
	area.set("spawn", "Entrance")
	area.set("place_name", place_name)
	area.position = pos
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(size)
	area.add_child(cs)
	parent.add_child(area)
	var back := Marker3D.new()
	back.name = "From" + place_name.replace(" ", "").replace("'", "")
	back.position = pos + Vector3(0, 0, 4.0)
	back.rotation.y = PI
	parent.add_child(back)


func shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func label3d(parent: Node3D, text: String, pos: Vector3, size := 96, color := Color(1, 0.97, 0.88)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.2, 0.1, 0.25)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	parent.add_child(l)
	return l


func puff(parent: Node3D, center: Vector3, r: float, m: Material, seed_value: int, count := 9) -> void:
	# A puffy cloud: a squashed body with round puffs around and on top of it
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := mesh_at(sphere(r, r * 0.8, 24), m, center, parent)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in count:
		var a := k * TAU / count + rng.randf_range(-0.2, 0.2)
		var pr := r * rng.randf_range(0.35, 0.55)
		var p := center + Vector3(cos(a) * r * 0.8, rng.randf_range(-0.15, 0.1) * r, sin(a) * r * 0.8)
		mesh_at(sphere(pr, pr * 1.6, 16), m, p, parent).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _town_hall() -> void:
	# Mr. Palmer's office: a big dome with a clock tower behind it and the town map on the wall inside (pilot, part 1)
	var g := dome_building("Town Hall", TOWN_HALL.x, TOWN_HALL.y, 7, TOWN_HALL.z, Color(0.95, 0.93, 0.88))
	var stone := mat("Town Hall Stone", Color(0.92, 0.9, 0.85), 0.7)
	var roof := mat("Town Hall Roof", Color(0.2, 0.55, 0.85), 0.5)
	var tower_z := -5.0
	mesh_at(box(Vector3(3.2, 13, 3.2)), stone, Vector3(0, 6.5, tower_z), g)
	solid(box_shape(Vector3(3.2, 13, 3.2)), Vector3(0, 6.5, tower_z), g)
	mesh_at(cylinder(0.0, 2.6, 3.4, 4), roof, Vector3(0, 14.7, tower_z), g, PI / 4)
	var face := mat("Clock Face", Color(1.0, 0.97, 0.85), 0.4, 0.0, 0.5)
	var hand := mat("Clock Hand", Color(0.1, 0.1, 0.15))
	mesh_at(cylinder(1.2, 1.2, 0.2, 24), face, Vector3(0, 10.8, tower_z + 1.65), g, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(box(Vector3(0.12, 0.9, 0.08)), hand, Vector3(0, 11.2, tower_z + 1.8), g)
	mesh_at(box(Vector3(0.7, 0.12, 0.08)), hand, Vector3(0.3, 10.8, tower_z + 1.8), g)
	mesh_at(cylinder(0.06, 0.06, 4.0, 6), hand, Vector3(0, 18.4, tower_z), g)             # flag pole
	mesh_at(box(Vector3(0.05, 1.0, 1.6)), mat("Town Flag", Color(0.95, 0.4, 0.6), 0.6), Vector3(0, 19.8, tower_z + 0.8), g)
	own(g)


func _haunted_house() -> void:
	# The pilot's cliffhanger: the old house the rich guy offers for the water slide. They try to buy it and an evil
	# spirit escapes. Crooked, boarded up, faint green light in the windows, bare trees round it.
	var c := ground(HAUNTED_HOUSE.x, HAUNTED_HOUSE.y)
	var g := group("Haunted House", c, HAUNTED_HOUSE.z)
	var wall := mat("Haunted Wall", Color(0.3, 0.27, 0.36), 0.95, 0.0, 0.0, 1.0, false)
	var roof := mat("Haunted Roof", Color(0.14, 0.11, 0.18), 0.9, 0.0, 0.0, 1.0, false)
	var ghost := mat("Haunted Window", Color(0.55, 1.0, 0.6), 0.5, 0.0, 1.3, 1.0, false)
	var plank := mat("Haunted Plank", Color(0.32, 0.22, 0.16), 0.95, 0.0, 0.0, 1.0, false)
	# Main house, sunk a little into the ground and leaning slightly
	mesh_at(box(Vector3(11, 8, 9)), wall, Vector3(0, 3.0, 0), g, 0.0, Vector3(0, 0, 0.03))
	solid(box_shape(Vector3(11, 8, 9)), Vector3(0, 3.0, 0), g)
	var gable := PrismMesh.new()
	gable.size = Vector3(12, 4.5, 10)
	mesh_at(gable, roof, Vector3(0, 9.2, 0), g, 0.0, Vector3(0, 0, 0.05))
	# Crooked corner tower with a witch-hat roof
	mesh_at(cylinder(2.0, 2.2, 13, 12), wall, Vector3(4.6, 5.0, 3.0), g, 0.0, Vector3(0.04, 0, -0.06))
	solid(_cyl_shape(2.2, 13), Vector3(4.6, 5.0, 3.0), g)
	mesh_at(cylinder(0.0, 2.8, 5.5, 12), roof, Vector3(4.2, 14.2, 3.0), g, 0.0, Vector3(0.1, 0, -0.18))
	# Windows: two rows, some glowing, some boarded
	for row in 2:
		for k in 3:
			var wx := -3.4 + k * 3.0
			var wy := 2.4 + row * 3.4
			mesh_at(box(Vector3(1.4, 1.8, 0.2)), ghost if (row + k) % 2 == 0 else roof, Vector3(wx, wy, 4.55), g)
			if (row + k) % 2 == 1:
				for s in [-1, 1]:
					mesh_at(box(Vector3(2.0, 0.25, 0.12)), plank, Vector3(wx, wy, 4.7), g, 0.0, Vector3(0, 0, s * 0.6))
	mesh_at(box(Vector3(1.6, 1.6, 0.2)), ghost, Vector3(4.6, 9.0, 5.15), g)
	# Front door and porch steps
	mesh_at(box(Vector3(2.2, 3.4, 0.3)), roof, Vector3(0, 0.7, 4.6), g)
	mesh_at(box(Vector3(5, 0.5, 2.0)), plank, Vector3(0, -0.5, 5.6), g)
	door(g, "res://scenes/interiors/haunted_house.tscn", "Haunted House", Vector3(0, 1.2, 5.0), Vector3(2.4, 4.0, 1.2))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 1.0, 0.6)
	glow.light_energy = 1.6
	glow.omni_range = 14.0
	glow.position = Vector3(0, 4, 7)
	g.add_child(glow)
	sign_post(g, "For Sale!", Vector3(-6.5, 0, 7.5), 0.3)
	# Bare, twisted trees in the yard
	var bark := mat("Dead Bark", Color(0.18, 0.14, 0.16), 0.95, 0.0, 0.0, 1.0, false)
	for t in [Vector3(-10, 8, 0.2), Vector3(9, 9, -0.3), Vector3(-9, -7, 0.5), Vector3(11, -5, -0.1)]:
		var base := ground(c.x + t.x * cos(HAUNTED_HOUSE.z) + t.y * sin(HAUNTED_HOUSE.z),
			c.z - t.x * sin(HAUNTED_HOUSE.z) + t.y * cos(HAUNTED_HOUSE.z)) - c
		mesh_at(cylinder(0.25, 0.45, 6, 6), bark, base + Vector3(0, 3, 0), g, 0.0, Vector3(t.z, 0, t.z * 0.5))
		for b in 3:
			mesh_at(cylinder(0.05, 0.15, 2.6, 5), bark, base + Vector3(0.3 * (b - 1), 4.5 + b * 0.6, 0), g, b * 2.1,
				Vector3(0.9, 0, 0))
	keep_clear.append(Vector3(HAUNTED_HOUSE.x, HAUNTED_HOUSE.y, 18))
	own(g)


func _old_slide() -> void:
	# The old water slide by the Haunted House (the pilot's first idea), boarded up: a ladder, a long sagging chute,
	# planks nailed across, and a CLOSED sign
	var c := ground(HAUNTED_HOUSE.x + 16, HAUNTED_HOUSE.y + 8)
	var g := group("Old Slide", c, HAUNTED_HOUSE.z)
	var wood := mat("Old Slide Wood", Color(0.36, 0.28, 0.22), 0.95, 0.0, 0.0, 1.0, false)
	var plank := mat("Haunted Plank", Color(0.32, 0.22, 0.16), 0.95, 0.0, 0.0, 1.0, false)
	for x in [-0.7, 0.7]:
		mesh_at(box(Vector3(0.2, 7.0, 0.2)), wood, Vector3(x, 3.5, 0), g)
	for k in 10:
		mesh_at(box(Vector3(1.5, 0.1, 0.12)), wood, Vector3(0, 0.6 + k * 0.65, 0), g)
	solid(box_shape(Vector3(1.8, 7.0, 0.6)), Vector3(0, 3.5, 0), g)
	var chute := mesh_at(box(Vector3(1.6, 0.2, 13.0)), wood, Vector3(0, 3.6, 6.2), g, 0.0, Vector3(0.55, 0, 0))
	chute.name = "Chute"
	for k in 4:                                         # boarded up
		mesh_at(box(Vector3(2.2, 0.25, 0.08)), plank, Vector3(0, 1.0 + k * 0.6, -0.15), g, 0.0, Vector3(0, 0, 0.2 * (k % 2 * 2 - 1)))
	sign_post(g, "CLOSED", Vector3(2.0, 0, -1.5), 0.2)
	keep_clear.append(Vector3(c.x, c.z, 10))
	own(g)


func _scary_gate() -> void:
	# The way to the Scary World (where the centipede lives): a stone wall across the far northwest woods with an old
	# iron gate. Going in is up to Nina (scenes/scary_world/scary_world.tscn, built by tools/build_scary_world.gd).
	var c := ground(-128, -150)
	var g := group("Scary World Gate", c, 0.7)
	var stone := mat("Old Wall Stone", Color(0.32, 0.3, 0.36), 0.95, 0.0, 0.0, 1.0, false)
	var iron := mat("Gate Iron", Color(0.12, 0.12, 0.14), 0.4, 0.8, 0.0, 1.0, false)
	for side in [-1, 1]:
		mesh_at(box(Vector3(14.0, 5.0, 1.4)), stone, Vector3(side * 9.5, 2.0, 0), g)
		solid(box_shape(Vector3(14.0, 5.0, 1.4)), Vector3(side * 9.5, 2.0, 0), g)
		mesh_at(box(Vector3(1.4, 6.5, 1.6)), stone, Vector3(side * 2.6, 2.75, 0), g)
		solid(box_shape(Vector3(1.4, 6.5, 1.6)), Vector3(side * 2.6, 2.75, 0), g)
	for k in 7:                                         # iron bars
		mesh_at(cylinder(0.07, 0.07, 4.6, 6), iron, Vector3(-1.5 + k * 0.5, 2.3, 0), g)
	mesh_at(box(Vector3(3.8, 0.15, 0.15)), iron, Vector3(0, 4.5, 0), g)
	mesh_at(box(Vector3(3.8, 0.15, 0.15)), iron, Vector3(0, 0.6, 0), g)
	solid(box_shape(Vector3(3.8, 4.6, 0.4)), Vector3(0, 2.3, 0), g)
	mesh_at(box(Vector3(0.5, 0.6, 0.25)), mat("Padlock", Color(0.8, 0.65, 0.3), 0.3, 0.9), Vector3(0, 2.4, 0.25), g)
	sign_post(g, "Scary World - Keep Out!", Vector3(4.5, 0, 2.5), 0.2)
	# Walking up to it asks whether she wants to go in (dialogue/scary_gate.json): a clear yes or no, and the answer
	# is kept in the save. Yes takes her through; she comes back out here.
	var ask := Node3D.new()
	ask.name = "Gate Question"
	ask.position = Vector3(0, 0, 1.6)
	g.add_child(ask)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", "scary_gate")
	talk.set("display_name", "The Old Gate")
	talk.set("name_height", 3.4)
	talk.set("turns", false)
	ask.add_child(talk)
	var back := Marker3D.new()                         # where she comes back out, facing away from the gate
	back.name = "FromScaryWorld"
	back.position = Vector3(0, 1.0, 4.0)
	back.rotation.y = PI
	g.add_child(back)
	keep_clear.append(Vector3(c.x, c.z, 12))
	own(g)


func _antique_car() -> void:
	# A shiny old-fashioned car parked in the South Meadow picnic park (the show's antique car theme)
	var g := group("Antique Car", ground(16, 56) + Vector3(0, 0.1, 0), 0.35)
	var paint := mat("Car Paint", Color(0.6, 0.08, 0.14), 0.3, 0.3, 0.0, 1.0, false)
	var black := mat("Car Black", Color(0.06, 0.05, 0.07), 0.5, 0.2, 0.0, 1.0, false)
	var brass := mat("Car Brass", Color(0.9, 0.7, 0.3), 0.3, 0.9, 0.0, 1.0, false)
	var cream := mat("Car Cream", Color(0.95, 0.9, 0.78), 0.5, 0.0, 0.0, 1.0, false)
	var glass := mat("Car Glass", Color(0.75, 0.9, 1.0), 0.05, 0.0, 0.0, 0.35, false)
	mesh_at(box(Vector3(1.7, 0.3, 3.9)), black, Vector3(0, 0.75, 0), g)                     # chassis
	mesh_at(box(Vector3(1.15, 0.65, 1.3)), paint, Vector3(0, 1.2, 1.2), g)                  # hood
	mesh_at(box(Vector3(1.0, 0.75, 0.1)), brass, Vector3(0, 1.2, 1.88), g)                  # radiator
	mesh_at(box(Vector3(1.6, 0.8, 1.9)), paint, Vector3(0, 1.3, -0.6), g)                   # body
	mesh_at(box(Vector3(1.7, 0.1, 2.0)), cream, Vector3(0, 2.5, -0.65), g)                  # roof
	for s in [-1, 1]:
		mesh_at(box(Vector3(0.08, 0.8, 0.08)), black, Vector3(s * 0.78, 2.05, 0.3), g)       # roof posts
		mesh_at(box(Vector3(0.08, 0.8, 0.08)), black, Vector3(s * 0.78, 2.05, -1.6), g)
		mesh_at(box(Vector3(0.3, 0.06, 2.6)), black, Vector3(s * 0.95, 0.6, 0), g)          # running boards
		mesh_at(sphere(0.2, -1, 12), brass, Vector3(s * 0.48, 1.45, 1.95), g)               # headlights
		for zz in [1.3, -1.3]:
			var w := mesh_at(cylinder(0.48, 0.48, 0.24, 18), black, Vector3(s * 0.88, 0.48, zz), g, 0.0, Vector3(0, 0, PI / 2))
			w.name = "Wheel"
			mesh_at(cylinder(0.16, 0.16, 0.26, 10), brass, Vector3(s * 0.88, 0.48, zz), g, 0.0, Vector3(0, 0, PI / 2))
			mesh_at(sphere(0.62, 0.5, 14), paint, Vector3(s * 0.88, 0.95, zz), g)            # fenders
	mesh_at(box(Vector3(1.4, 0.55, 0.06)), glass, Vector3(0, 2.0, 0.32), g)                 # windshield
	var spare := TorusMesh.new()
	spare.inner_radius = 0.25
	spare.outer_radius = 0.45
	mesh_at(spare, black, Vector3(0, 1.3, -2.0), g, 0.0, Vector3(PI / 2, 0, 0))
	solid(box_shape(Vector3(1.9, 1.8, 4.1)), Vector3(0, 1.1, 0), g)
	own(g)
	# The rest of the picnic park: blankets with baskets
	var p := group("South Meadow", ground(8, 52))
	var cloth := [Color(0.95, 0.4, 0.4), Color(0.4, 0.7, 1.0), Color(1.0, 0.85, 0.3)]
	for k in 3:
		var at := Vector3(cos(k * 2.3) * 6.0, 0.05, sin(k * 2.3) * 5.0)
		mesh_at(box(Vector3(2.4, 0.04, 1.8)), mat("Picnic Blanket %d" % k, cloth[k], 0.9), at, p, k * 0.7)
		mesh_at(box(Vector3(0.6, 0.4, 0.4)), mat("Picnic Basket", Color(0.7, 0.5, 0.3), 0.8), at + Vector3(0.6, 0.2, 0.3), p, k * 0.7)
	sign_post(p, "South Meadow", Vector3(-4, 0, -8), 0.3)
	own(p)


func _welcome_sign() -> void:
	# At the market's south entrance, where you arrive in town
	var g := group("Welcome Sign", ground(MARKET.x + 6.0, MARKET.y + MARKET.z + 8.0))
	sign_post(g, "Welcome to Galaxity", Vector3.ZERO, 0.0)
	own(g)


func _portal() -> void:
	# A ring of light on a stone base: the way to Earth. It only opens during the Shift, midnight to 1 AM
	# (scripts/portal.gd shows the swirl, sparkles and glow then), and the door goes to Earth (scenes/earth/earth.tscn).
	var g := group("Portal to Earth", ground(PORTAL.x, PORTAL.y), PORTAL.z)
	g.set_script(load("res://scripts/portal.gd"))
	var stone := mat("Portal Stone", Color(0.55, 0.5, 0.7), 0.8)
	mesh_at(cylinder(3.4, 3.8, 0.8, 32), stone, Vector3(0, 0.2, 0), g)
	solid(_cyl_shape(3.8, 0.8), Vector3(0, 0.2, 0), g)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.6
	ring.outer_radius = 3.2
	ring.rings = 48
	var ring_mi := mesh_at(ring, mat("Portal Ring", Color(0.95, 0.75, 0.3), 0.3, 0.6, 0.8), Vector3(0, 3.7, 0), g, 0.0,
		Vector3(PI / 2, 0, 0))
	ring_mi.name = "Ring"
	var swirl := shader_mat("""shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	float s = sin(a * 3.0 + r * 9.0 - TIME * 2.5) * 0.5 + 0.5;
	vec3 sky = mix(vec3(0.25, 0.55, 1.0), vec3(0.4, 0.85, 0.5), s);
	ALBEDO = mix(sky, vec3(1.0), smoothstep(0.6, 1.0, s) * (1.0 - r));
	ALPHA = 0.85;
}""")
	var q := QuadMesh.new()
	q.size = Vector2(5.4, 5.4)
	var swirl_mi := mesh_at(q, swirl, Vector3(0, 3.7, 0), g)
	swirl_mi.name = "Swirl"
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0, 3.7, 1.0)
	glow.light_color = Color(0.5, 0.75, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 14.0
	g.add_child(glow)
	var hood := OmniLight3D.new()                  # in the Shift the portal lights up the neighbourhood next door
	hood.name = "NeighbourhoodGlow"
	hood.position = Vector3(0, 9.0, 0)
	hood.light_color = Color(0.55, 0.75, 1.0)
	hood.light_energy = 2.2
	hood.omni_range = 60.0
	hood.omni_attenuation = 0.6
	g.add_child(hood)
	# Sparkles drifting out of the swirl while it's open
	var sparkles := CPUParticles3D.new()
	sparkles.name = "Sparkles"
	sparkles.position = Vector3(0, 3.7, 0)
	sparkles.emitting = false
	sparkles.amount = 60
	sparkles.lifetime = 2.5
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 2.4
	sparkles.direction = Vector3(0, 0.3, 1)
	sparkles.spread = 60.0
	sparkles.gravity = Vector3(0, 0.4, 0)
	sparkles.initial_velocity_min = 0.3
	sparkles.initial_velocity_max = 1.2
	sparkles.scale_amount_min = 0.6
	sparkles.scale_amount_max = 1.4
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.2, 1))
	fade.add_point(Vector2(1, 0))
	sparkles.scale_amount_curve = fade
	var dot := sphere(0.07, -1, 6)
	dot.material = mat("Portal Sparkle", Color(0.75, 0.9, 1.0), 0.2, 0.0, 4.0, 1.0, false)
	sparkles.mesh = dot
	g.add_child(sparkles)
	door(g, "res://scenes/earth/earth.tscn", "Portal to Earth", Vector3(0, 2.4, 0.4), Vector3(4.0, 4.0, 1.0))
	sign_post(g, "Portal to Earth", Vector3(4.5, 0, 2.5), 0.0)
	keep_clear.append(Vector3(PORTAL.x, PORTAL.y, 7))
	own(g)


func _tree_house() -> void:
	# A giant tree with a house in its branches, plank steps spiralling up round it, and a zipline down to the west
	# fields: press Interact at the handle to ride it (scripts/zipline.gd).
	var c := ground(TREE_HOUSE.x, TREE_HOUSE.y)
	var g := group("Tree House", c)
	var bark := mat("Big Bark", Color(0.42, 0.28, 0.18))
	var wood := mat("Tree House Wood", Color(0.7, 0.5, 0.3))
	var leaf := mat("Big Leaves", T.trees[1], 0.8, 0.0, T.tree_glow, 1.0, false)
	var deck_y := 7.0
	mesh_at(cylinder(1.1, 1.6, 14, 14), bark, Vector3(0, 7, 0), g)
	solid(_cyl_shape(1.4, 14), Vector3(0, 7, 0), g)
	for k in 5:
		puff(g, Vector3(cos(k * 1.3) * 3.5, 14 + (k % 2) * 1.5, sin(k * 1.3) * 3.5), 4.5, leaf, 300 + k, 6)
	# Steps spiralling up OUTSIDE the deck's edge (they used to sit under the deck, so you hit your head and couldn't
	# get up), each a small hop above the last, the top one level with the deck at the gap in the railing.
	var steps := 11
	var step_r := 5.6                                  # deck radius 4.5: the steps' inner ends stay clear of it
	var gap_angle := 4 * TAU / 14                      # where the railing has its gap (k == 4 below)
	for k in steps:
		var a := gap_angle - (steps - 1 - k) * 0.52
		var y := 0.55 + k * (deck_y + 0.075 - 0.55) / (steps - 1)    # the last step's top is level with the deck's
		var p := Vector3(cos(a) * step_r, y, sin(a) * step_r)
		mesh_at(box(Vector3(2.2, 0.25, 1.4)), wood, p, g, -a)
		solid(box_shape(Vector3(2.2, 0.25, 1.4)), p, g, -a)
		if k > 0:                                      # a post under each step, down to the ground
			mesh_at(cylinder(0.1, 0.1, y, 6), wood, p - Vector3(0, y / 2, 0), g)
	# Deck, railing and the little house
	mesh_at(cylinder(4.5, 4.5, 0.4, 20), wood, Vector3(0, deck_y, 0), g)
	solid(_cyl_shape(4.5, 0.4), Vector3(0, deck_y, 0), g)
	for k in 14:
		var a := k * TAU / 14
		if k == 4:
			continue                                     # gap where the steps arrive
		mesh_at(box(Vector3(0.12, 1.0, 0.12)), wood, Vector3(cos(a) * 4.3, deck_y + 0.6, sin(a) * 4.3), g)
	mesh_at(box(Vector3(3.6, 2.6, 3.0)), mat("Tree House Wall", Color(0.85, 0.6, 0.35)), Vector3(-1.2, deck_y + 1.5, -1.2), g)
	solid(box_shape(Vector3(3.6, 2.6, 3.0)), Vector3(-1.2, deck_y + 1.5, -1.2), g)
	var gable := PrismMesh.new()
	gable.size = Vector3(4.2, 1.6, 3.6)
	mesh_at(gable, mat("Tree House Roof", Color(0.85, 0.3, 0.3)), Vector3(-1.2, deck_y + 3.6, -1.2), g)
	sign_post(g, "Tree House", Vector3(3.5, 0, 3.5), 0.6)
	# Zipline: a cable from a post at the deck's edge (on the landing's side, so she's off the deck straight away)
	# down to a landing post
	var metal := mat("Zipline Metal", Color(0.7, 0.72, 0.78), 0.3, 0.8)
	var end := ground(ZIPLINE_END.x, ZIPLINE_END.y) - c + Vector3(0, 3.0, 0)
	var out := Vector3(end.x, 0, end.z).normalized()
	var post := out * 4.0
	var top := post + Vector3(0, deck_y + 4.0, 0)
	mesh_at(cylinder(0.12, 0.12, 4.0, 8), metal, post + Vector3(0, deck_y + 2.0, 0), g)
	mesh_at(cylinder(0.15, 0.15, 3.0, 8), metal, end - Vector3(0, 1.5, 0), g)
	var span := end - top
	var cable := mesh_at(cylinder(0.04, 0.04, span.length(), 6), metal, top + span / 2, g)
	cable.look_at_from_position(c + top + span / 2, c + end, Vector3.UP)
	cable.rotate_object_local(Vector3.RIGHT, PI / 2)
	cable.position = top + span / 2
	var handle := mesh_at(box(Vector3(0.6, 0.6, 0.15)), mat("Zipline Handle", Color(1.0, 0.6, 0.15), 0.5), top + Vector3(0, -0.4, 0), g)
	handle.name = "ZiplineHandle"
	for m in [["ZipTop", top], ["ZipEnd", end]]:
		var marker := Marker3D.new()
		marker.name = m[0]
		marker.position = m[1]
		g.add_child(marker)
	var ride := Area3D.new()                           # stand by the handle and press Interact
	ride.name = "Zipline"
	ride.set_script(load("res://scripts/zipline.gd"))
	ride.position = post - out * 1.2 + Vector3(0, deck_y + 1.0, 0)
	var rcs := CollisionShape3D.new()
	rcs.shape = _sphere_shape(2.2)
	ride.add_child(rcs)
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.font_size = 44
	prompt.pixel_size = 0.01
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0.15, 0.1, 0.12)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.position = Vector3(0, 1.6, 0)
	ride.add_child(prompt)
	g.add_child(ride)
	sign_post(g, "Zipline", end - Vector3(1.5, 3.0, 0), 0.0)
	keep_clear.append(Vector3(TREE_HOUSE.x, TREE_HOUSE.y, 9))
	keep_clear.append(Vector3(ZIPLINE_END.x, ZIPLINE_END.y, 4))
	own(g)


func _rock_wall() -> void:
	# A climbing wall with colourful holds; the big holds are ledges you can jump up
	var g := group("Rock Wall", ground(ROCK_WALL.x, ROCK_WALL.y), ROCK_WALL.z)
	var wall := mat("Climbing Wall", Color(0.55, 0.5, 0.6), 0.9)
	mesh_at(box(Vector3(9, 10, 1.6)), wall, Vector3(0, 4.5, 0), g)
	solid(box_shape(Vector3(9, 10, 1.6)), Vector3(0, 4.5, 0), g)
	var colors := [Color(1.0, 0.3, 0.4), Color(0.2, 0.8, 1.0), Color(1.0, 0.85, 0.2), Color(0.5, 1.0, 0.4), Color(0.8, 0.4, 1.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 40:                                   # small holds for looks
		var p := Vector3(rng.randf_range(-4.2, 4.2), rng.randf_range(0.5, 9.2), 0.85)
		mesh_at(sphere(0.18, 0.22, 8), mat("Hold %d" % (k % 5), colors[k % 5], 0.6), p, g)
	for k in 7:                                    # ledges zig-zagging up, 1.3 m apart
		var p := Vector3(-3.0 + (k % 2) * 3.0 + (1.5 if k % 4 >= 2 else 0.0), 1.1 + k * 1.3, 1.25)
		var m := mat("Ledge %d" % (k % 5), colors[k % 5], 0.6)
		mesh_at(box(Vector3(1.6, 0.35, 0.9)), m, p, g)
		solid(box_shape(Vector3(1.6, 0.35, 0.9)), p, g)
	mesh_at(box(Vector3(9.4, 0.4, 2.4)), wall, Vector3(0, 9.7, 0), g)            # flat top to stand on
	solid(box_shape(Vector3(9.4, 0.4, 2.4)), Vector3(0, 9.7, 0), g)
	mesh_at(box(Vector3(10, 0.4, 5)), mat("Crash Mat", Color(0.25, 0.45, 0.95), 0.9), Vector3(0, 0.1, 3.2), g)
	sign_post(g, "Rock Wall", Vector3(5.8, 0, 3.5), 0.0)
	keep_clear.append(Vector3(ROCK_WALL.x, ROCK_WALL.y, 9))
	own(g)


func _cloud_nest() -> void:
	# The Cloud Nest from Mr. Palmer's map: two cloud rooms floating over the plateau, a Quiet Side with pillows and a
	# Loud Side with speakers and a drum. Small clouds lead up from beside the Secret Gardens.
	var start := ground(-70, -36)
	var quiet := Vector3(CLOUD_NEST.x - 4.5, start.y + 5.8, CLOUD_NEST.y)
	var loud := Vector3(CLOUD_NEST.x + 5.0, start.y + 5.8, CLOUD_NEST.y - 1.0)
	var g := group("Cloud Nest", Vector3.ZERO)
	var cloud := mat("Cloud", Color(0.97, 0.97, 1.0), 0.9)
	var quiet_m := mat("Cloud Quiet", Color(0.75, 0.85, 1.0), 0.9)
	var loud_m := mat("Cloud Loud", Color(1.0, 0.75, 0.88), 0.9)
	for lobe in [[quiet, quiet_m, 21], [loud, loud_m, 22]]:
		var p: Vector3 = lobe[0]
		puff(g, p - Vector3(0, 0.9, 0), 4.6, lobe[1], lobe[2])
		mesh_at(cylinder(4.3, 4.3, 0.3, 32), lobe[1], p + Vector3(0, -0.05, 0), g)
		solid(_cyl_shape(4.4, 1.2), p - Vector3(0, 0.6, 0), g)
		cloud_zone(g, p, 4.4)
	var bridge := quiet.lerp(loud, 0.5)                     # the two sides join in the middle
	puff(g, bridge - Vector3(0, 0.9, 0), 2.6, cloud, 23, 6)
	solid(_cyl_shape(2.6, 1.2), bridge - Vector3(0, 0.6, 0), g)
	cloud_zone(g, bridge, 2.6)
	# Quiet Side: pillows and a blanket
	var pillow := mat("Pillow", Color(0.85, 0.8, 1.0), 0.9)
	for k in 4:
		var a := k * 1.4
		mesh_at(sphere(0.7, 0.5, 14), pillow, quiet + Vector3(cos(a) * 2.4, 0.3, sin(a) * 2.4), g)
	mesh_at(box(Vector3(2.4, 0.08, 1.8)), mat("Blanket", Color(0.5, 0.7, 1.0), 0.9), quiet + Vector3(0, 0.15, 0), g)
	label3d(g, "Quiet Side", quiet + Vector3(0, 2.6, 0), 72, Color(0.85, 0.92, 1.0))
	# Loud Side: two speakers and a drum
	var dark := mat("Speaker", Color(0.15, 0.12, 0.2), 0.6)
	var cone := mat("Speaker Cone", Color(1.0, 0.4, 0.75), 0.4, 0.0, 1.0)
	for s in [-1, 1]:
		var sp := loud + Vector3(s * 2.4, 1.1, -1.8)
		mesh_at(box(Vector3(1.2, 2.0, 1.0)), dark, sp, g)
		mesh_at(cylinder(0.4, 0.4, 0.1, 16), cone, sp + Vector3(0, 0.3, 0.52), g, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cylinder(0.8, 0.8, 0.9, 20), mat("Drum", Color(1.0, 0.55, 0.2), 0.5), loud + Vector3(0, 0.6, 0.8), g)
	label3d(g, "Loud Side", loud + Vector3(0, 3.4, 0), 72, Color(1.0, 0.85, 0.95))
	label3d(g, "Cloud Nest", bridge + Vector3(0, 4.6, 0), 120)
	# Stepping clouds from the plateau up to the Quiet Side
	var steps := 4
	for k in steps:
		var t := float(k + 1) / (steps + 1)
		var p := start.lerp(quiet - Vector3(0, 0, -4.4).rotated(Vector3.UP, 0.4), t)
		p.y = start.y + 1.2 * (k + 1)
		puff(g, p - Vector3(0, 0.4, 0), 1.4, cloud, 40 + k, 5)
		solid(_cyl_shape(1.4, 0.8), p - Vector3(0, 0.4, 0), g)
		cloud_zone(g, p, 1.4)
	own(g)


func _bubble_bath() -> void:
	# The magic bubble bath: a big tub of glowing pink water with bubbles rising out of it
	var g := group("Magic Bubble Bath", ground(BUBBLE_BATH.x, BUBBLE_BATH.y))
	var tub := mat("Tub", Color(0.98, 0.96, 0.98), 0.3, 0.1)
	var water := mat("Bath Water", Color(1.0, 0.55, 0.85), 0.1, 0.0, 0.8, 0.85)
	# The tub: a solid rim all round and a floor, so she can climb in and wade (scripts/soft_zone.gd "bath")
	mesh_at(cylinder(4.2, 3.8, 1.4, 40), tub, Vector3(0, 0.5, 0), g)
	var rim_h := 1.4
	for k in 24:
		var a := k * TAU / 24
		solid(box_shape(Vector3(0.45, rim_h, 2 * 4.0 * sin(PI / 24) + 0.1)), Vector3(cos(a) * 4.0, 0.5, sin(a) * 4.0), g, -a)
	solid(_cyl_shape(3.8, 1.0), Vector3(0, 0.1, 0), g)                        # the floor inside: waist-deep water for her
	mesh_at(cylinder(3.8, 3.8, 0.1, 40), water, Vector3(0, 1.22, 0), g)
	for k in 2:                                                                 # two steps up to the rim
		var st := Vector3(0, 0, 4.9 + 0.7 * k)
		var hgt := 0.85 - k * 0.4
		mesh_at(box(Vector3(2.0, hgt, 0.7)), tub, st + Vector3(0, hgt / 2.0 - 0.1, 0), g)
		solid(box_shape(Vector3(2.0, hgt, 0.7)), st + Vector3(0, hgt / 2.0 - 0.1, 0), g)
	soft_zone(g, "bath", Vector3(0, 0.15, 0), 3.4, 1.1, Color(1.0, 0.8, 0.95, 0.75), 0.5, 0.45, 3.0)
	var bubble := mat("Bubble", Color(0.85, 0.95, 1.0), 0.05, 0.0, 0.5, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 18:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 3.2
		mesh_at(sphere(rng.randf_range(0.3, 0.8), -1, 12), bubble, Vector3(cos(a) * d, 1.4, sin(a) * d), g)
	var rising := CPUParticles3D.new()
	rising.name = "Bubbles"
	rising.amount = 40
	rising.lifetime = 4.0
	var bm := sphere(0.18, -1, 8)
	bm.material = bubble
	rising.mesh = bm
	rising.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rising.emission_sphere_radius = 3.0
	rising.direction = Vector3.UP
	rising.spread = 15.0
	rising.gravity = Vector3(0, 0.6, 0)
	rising.initial_velocity_min = 0.3
	rising.initial_velocity_max = 0.8
	rising.position = Vector3(0, 1.4, 0)
	g.add_child(rising)
	sign_post(g, "Magic Bubble Bath", Vector3(5.5, 0, 3.0), -0.3)
	keep_clear.append(Vector3(BUBBLE_BATH.x, BUBBLE_BATH.y, 8))
	own(g)


func _park_mural() -> void:
	# The magically changing park mural: a long wall whose painting slowly swirls from one picture to the next
	var g := group("Park Mural", ground(MURAL.x, MURAL.y), MURAL.z)
	var frame := mat("Mural Frame", Color(0.85, 0.82, 0.9), 0.8)
	mesh_at(box(Vector3(12.6, 5.6, 0.8)), frame, Vector3(0, 2.6, -0.1), g)
	solid(box_shape(Vector3(12.6, 5.6, 0.8)), Vector3(0, 2.6, -0.1), g)
	var paint := shader_mat("""shader_type spatial;
render_mode unshaded;
vec3 pal(float t) { return 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + t)); }
void fragment() {
	vec2 p = UV * vec2(12.0, 5.0);
	float t = TIME * 0.05;
	float v = sin(p.x * 0.8 + sin(p.y * 1.3 + t * 7.0) * 1.5 + t * 3.0) + sin(length(p - vec2(6.0 + sin(t * 4.0) * 4.0, 2.5)) * 1.6 - t * 9.0);
	float stars = step(0.985, fract(sin(dot(floor(p * 6.0), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = mix(pal(v * 0.25 + t), vec3(1.0), stars * 0.8);
}""")
	var q := QuadMesh.new()
	q.size = Vector2(12, 5)
	mesh_at(q, paint, Vector3(0, 2.6, 0.32), g)
	sign_post(g, "Park Mural", Vector3(7.2, 0, 2.0), 0.0)
	keep_clear.append(Vector3(MURAL.x, MURAL.y, 8))
	own(g)


func _soccer_field() -> void:
	# The ever-changing deluxe soccer court: its turf slowly cycles through colours and patterns
	var size := Vector2(30, 18)
	var g := group("Soccer Field", ground(SOCCER.x, SOCCER.y))
	mesh_at(box(Vector3(size.x + 3, 0.3, size.y + 3)), mat("Court Edge", Color(0.3, 0.55, 0.35)), Vector3(0, 0.05, 0), g)
	solid(box_shape(Vector3(size.x + 3, 0.4, size.y + 3)), Vector3(0, 0.05, 0), g)
	var turf := shader_mat("""shader_type spatial;
vec3 pal(float t) { return 0.5 + 0.5 * cos(6.2832 * (vec3(0.1, 0.4, 0.7) + t)); }
void fragment() {
	vec2 p = UV * vec2(30.0, 18.0);
	float t = TIME * 0.04;
	float stripes = step(0.5, fract(p.x / 3.0 + floor(t * 4.0) * 0.25));
	float checks = step(0.5, fract(p.x / 3.0)) == step(0.5, fract(p.y / 3.0)) ? 1.0 : 0.0;
	float pattern = mix(stripes, checks, step(0.5, fract(t * 2.0)));
	vec3 c = pal(t) * mix(0.75, 1.0, pattern);
	float line = 0.0;
	line += step(abs(p.x - 15.0), 0.08);
	line += step(abs(length(p - vec2(15.0, 9.0)) - 3.0), 0.08);
	line += step(p.x, 0.12) + step(29.88, p.x) + step(p.y, 0.12) + step(17.88, p.y);
	ALBEDO = mix(c, vec3(1.0), clamp(line, 0.0, 1.0));
	ROUGHNESS = 0.8;
}""")
	var top := PlaneMesh.new()
	top.size = size
	mesh_at(top, turf, Vector3(0, 0.22, 0), g)
	var post := mat("Goal Post", Color(1, 1, 1), 0.4)
	var net := mat("Goal Net", Color(0.95, 0.95, 1.0), 0.6, 0.0, 0.0, 0.45)
	for s in [-1, 1]:
		var gx: float = s * (size.x / 2 + 0.6)
		for side in [-1, 1]:
			mesh_at(cylinder(0.1, 0.1, 2.2, 8), post, Vector3(gx, 1.3, side * 3.0), g)
		mesh_at(cylinder(0.1, 0.1, 6.0, 8), post, Vector3(gx, 2.4, 0), g, 0.0, Vector3(PI / 2, 0, 0))
		mesh_at(box(Vector3(1.2, 2.2, 6.0)), net, Vector3(gx + s * 0.6, 1.3, 0), g)
	mesh_at(sphere(0.3, -1, 14), mat("Soccer Ball", Color(1, 1, 1), 0.5), Vector3(0, 0.55, 0), g)
	sign_post(g, "Soccer Field", Vector3(0, 0, size.y / 2 + 2.5), 0.0)
	keep_clear.append(Vector3(SOCCER.x, SOCCER.y, maxf(size.x, size.y) / 2 + 3))
	own(g)


func _cloud_slide() -> void:
	# The end of the pilot: "it doesn't have to be on the waterfall". A magic floating cloud over the lake with a water
	# slide spiralling down into it, and a toy store on top. Cloud steps spiral up to it from the Town Square.
	# Hidden until the story unlocks it (scripts/unlockable.gd checks Game.has_item(SLIDE_FLAG)).
	var g := group("Cloud Water Slide", Vector3.ZERO)
	g.set_script(load("res://scripts/unlockable.gd"))
	g.set("flag", SLIDE_FLAG)
	g.set_meta("unlock_flag", SLIDE_FLAG)
	var center := Vector3(SLIDE_CLOUD.x, SLIDE_CLOUD.z, SLIDE_CLOUD.y)
	var cloud := mat("Cloud", Color(0.97, 0.97, 1.0), 0.9)
	puff(g, center - Vector3(0, 1.2, 0), 8.5, cloud, 77, 12)
	mesh_at(cylinder(8.2, 8.2, 0.3, 40), cloud, center, g)
	solid(_cyl_shape(8.3, 1.6), center - Vector3(0, 0.8, 0), g)
	cloud_zone(g, center, 8.3)
	# Toy store on top (Melanie finally gets one)
	var store := dome_building("Toy Store", center.x - 2.5, center.z - 2.0, 3.6, 0.6, Color(1.0, 0.6, 0.3), [], center.y)
	store.get_parent().remove_child(store)
	store.owner = null                                # own(g) below sets it again
	g.add_child(store)
	# The slide: a trough with water running in it, two turns down to the lake
	var trough := mat("Slide", Color(0.2, 0.75, 1.0), 0.3, 0.1)
	var rail := mat("Slide Rail", Color(1.0, 0.85, 0.3), 0.4)
	var flow := shader_mat("""shader_type spatial;
render_mode unshaded;
void fragment() {
	float s = fract(UV.y * 3.0 - TIME * 2.0);
	ALBEDO = mix(vec3(0.6, 0.9, 1.0), vec3(1.0), smoothstep(0.8, 1.0, s));
	ALPHA = 0.8;
}""")
	var radius := 10.0
	var turns := 2.0
	var segs := 60
	var top_y := center.y + 0.2
	var bottom_y := WATER_Y + 0.3
	var a0 := -PI / 2                                 # start on the cloud's south rim
	var prev := Vector3.ZERO
	for k in segs + 1:
		var t := float(k) / segs
		var a := a0 + t * turns * TAU
		var r := lerpf(radius * 0.85, radius, t)
		var p := Vector3(center.x + cos(a) * r, lerpf(top_y, bottom_y, pow(t, 0.9)), center.z + sin(a) * r)
		if k > 0:
			var d := p - prev
			var mid := (p + prev) / 2
			var yaw := atan2(d.x, d.z)
			var pitch := atan2(-d.y, Vector2(d.x, d.z).length())
			var length := d.length() + 0.15
			mesh_at(box(Vector3(2.4, 0.25, length)), trough, mid, g, yaw, Vector3(pitch, 0, 0))
			solid(box_shape(Vector3(2.4, 0.25, length)), mid, g, yaw, Vector3(pitch, 0, 0))
			mesh_at(box(Vector3(2.0, 0.05, length)), flow, mid + Vector3(0, 0.16, 0), g, yaw, Vector3(pitch, 0, 0))
			for s in [-1, 1]:
				var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 1.15 * s
				mesh_at(box(Vector3(0.15, 0.6, length)), rail, mid + side + Vector3(0, 0.3, 0), g, yaw, Vector3(pitch, 0, 0))
				solid(box_shape(Vector3(0.15, 0.6, length)), mid + side + Vector3(0, 0.3, 0), g, yaw, Vector3(pitch, 0, 0))
		prev = p
	mesh_at(cylinder(3.0, 3.5, 0.3, 24), mat("Foam", Color(0.95, 0.98, 1.0), 0.3, 0.0, 0.4, 0.85), prev + Vector3(0, -0.2, 0), g)
	# Cloud steps: a spiral of small clouds rising from the Town Square's edge to the big cloud
	var spiral := Vector3(-20, 0, -6)
	var to_square := (Vector2(TOWN_SQUARE.x, TOWN_SQUARE.y) - Vector2(spiral.x, spiral.z)).angle()
	var to_cloud := (Vector2(center.x, center.z) - Vector2(spiral.x, spiral.z)).angle()
	var rise := 1.25
	var n := int(ceil((top_y - 1.4) / rise))
	var sweep := wrapf(to_cloud - to_square, 0.0, TAU) + TAU          # one and a bit turns
	for k in n:
		var t := float(k) / (n - 1)
		var a := to_square + sweep * t
		var p := Vector3(spiral.x + cos(a) * 4.2, 1.2 + k * rise, spiral.z + sin(a) * 4.2)
		puff(g, p - Vector3(0, 0.35, 0), 1.3, cloud, 90 + k, 5)
		solid(_cyl_shape(1.3, 0.7), p - Vector3(0, 0.35, 0), g)
		cloud_zone(g, p, 1.3)
	label3d(g, "Cloud Water Slide", center + Vector3(0, 9, 0), 140)
	own(g)


func crossroads(at: Vector2, arms: Array) -> void:
	# A signpost with one board per arm, each pointing the way to where it says: [text, Vector2 target (x, z)]
	var base := ground(at.x, at.y)
	var g := group("Signpost %s" % arms[0][0], base)                      # named by its first arm
	var wood := mat("Signpost Wood", Color(0.55, 0.36, 0.22))
	var board_m := mat("Signpost Board", Color(0.25, 0.2, 0.32))
	mesh_at(cylinder(0.12, 0.14, 3.6, 8), wood, Vector3(0, 1.8, 0), g)
	solid(_cyl_shape(0.18, 3.6), Vector3(0, 1.8, 0), g)
	for k in arms.size():
		var arm: Array = arms[k]
		var to: Vector2 = (arm[1] as Vector2) - at
		var dir := to.normalized()
		var yaw := atan2(-dir.y, dir.x)                     # the board's long side points along dir
		var board := Node3D.new()
		board.position = Vector3(dir.x * 1.1, 3.2 - k * 0.55, dir.y * 1.1)
		board.rotation.y = yaw
		g.add_child(board)
		mesh_at(box(Vector3(2.2, 0.42, 0.08)), board_m, Vector3.ZERO, board)
		var tip := PrismMesh.new()                          # the pointy end
		tip.size = Vector3(0.42, 0.4, 0.08)
		mesh_at(tip, board_m, Vector3(1.3, 0, 0), board, 0.0, Vector3(0, 0, -PI / 2))
		for side in [1, -1]:                                # the words on both faces
			var l := Label3D.new()
			l.text = arm[0]
			l.font_size = 40
			l.pixel_size = 0.01
			l.outline_size = 6
			l.modulate = Color(1, 0.97, 0.85)
			l.position = Vector3(0, 0, 0.05 * side)
			l.rotation.y = 0.0 if side == 1 else PI
			l.double_sided = false
			board.add_child(l)
	own(g)


func _signposts() -> void:
	# At the main crossroads, pointing the way
	var market := Vector2(MARKET.x, MARKET.y)
	var homes := Vector2(HOUSING.x, HOUSING.y)
	var castle := Vector2(CASTLE_HILL.x, CASTLE_HILL.y)
	var sports := Vector2(80, 64)
	crossroads(Vector2(-40, 47), [["Market", market], ["Homes", homes], ["Castle & School", castle], ["Spa & Gardens", Vector2(-62, 0)]])
	crossroads(Vector2(1, 27), [["Market", market], ["Castle & School", Vector2(-8, -12)], ["Homes", homes], ["Sports & Play", sports]])
	crossroads(Vector2(30, 23), [["Portal", Vector2(PORTAL.x, PORTAL.y)], ["Homes", homes], ["Market", market], ["South Meadow", Vector2(12, 52)]])
	crossroads(Vector2(46, 9), [["Homes", homes], ["Observatory", Vector2(OBS_HILL.x, OBS_HILL.y)], ["Market", market], ["Sports & Play", sports]])
	crossroads(Vector2(-4, -40), [["Castle & School", castle], ["Library", Vector2(-12, -50)], ["Haunted House", Vector2(HAUNTED_HOUSE.x, HAUNTED_HOUSE.y)], ["Market", market]])


# -----------------------------------------------------------------------------
# Rex's campaign (res://quests/rex_campaign.json): where Nina hangs his posters (three signposts and a noticeboard
# in the Market Square), and Mr. Palmer's office window at the Town Hall, where she can talk to him (he has no
# model yet: he's a voice from behind the lit window).
# -----------------------------------------------------------------------------
const POSTER_SPOTS := [[Vector2(-40, 47), "poster_1"], [Vector2(30, 23), "poster_2"], [Vector2(46, 9), "poster_3"]]
const NOTICEBOARD_ANGLE := 290.0                  # degrees round the fountain: between the Town Hall path and the Toys stall


func _rex_campaign() -> void:
	var g := group("Rex Campaign", Vector3.ZERO)
	var market := Vector2(MARKET.x, MARKET.y)
	for k in POSTER_SPOTS.size():
		var at: Vector2 = POSTER_SPOTS[k][0]
		var spot := quest_spot(g, POSTER_SPOTS[k][1], ground(at.x, at.y), "Poster up! VOTE REX!")
		spot.name = "Poster Spot %d" % (k + 1)
		var to := (market - at).normalized()
		var yaw := atan2(to.x, to.y)                       # one poster faces the way to the market, one the other way
		for side in [0.0, PI]:
			var face := Vector3(sin(yaw + side), 0, cos(yaw + side))
			poster(spot.get_node("Done"), face * 0.15 + Vector3(0, 0.95, 0), yaw + side)    # under the lowest board
	# The noticeboard by the fountain
	var a := deg_to_rad(NOTICEBOARD_ANGLE)
	var c := ground(MARKET.x, MARKET.y)
	var nb_pos := Vector3(MARKET.x + cos(a) * 13.0, c.y + 0.15, MARKET.y + sin(a) * 13.0)
	var nb := group("Noticeboard", nb_pos, atan2(-cos(a), -sin(a)))           # facing the fountain
	var wood := mat("Stall Wood", Color(0.6, 0.4, 0.25))
	var cork := mat("Cork", Color(0.72, 0.55, 0.36))
	for px in [-0.95, 0.95]:
		mesh_at(cylinder(0.07, 0.07, 2.4, 8), wood, Vector3(px, 1.2, 0), nb)
	mesh_at(box(Vector3(2.1, 1.3, 0.1)), cork, Vector3(0, 1.55, 0), nb)
	mesh_at(box(Vector3(2.3, 0.1, 0.4)), wood, Vector3(0, 2.3, 0.05), nb, 0.0, Vector3(0.2, 0, 0))     # little roof
	solid(box_shape(Vector3(2.1, 2.4, 0.3)), Vector3(0, 1.2, 0), nb)
	var notes := [[Vector3(-0.7, 1.75, 0.06), Color(1.0, 0.95, 0.6)], [Vector3(-0.65, 1.3, 0.06), Color(0.7, 0.9, 1.0)],
		[Vector3(0.75, 1.5, 0.06), Color(1.0, 0.75, 0.85)]]
	for n in notes:
		mesh_at(box(Vector3(0.35, 0.42, 0.02)), mat("Note %s" % n[1], n[1], 0.9), n[0], nb)
	label3d(nb, "Notices", Vector3(0, 2.6, 0), 44)
	var board_spot := quest_spot(nb, "poster_4", Vector3(0, 0, 0.6), "Poster up on the noticeboard! VOTE REX!")
	board_spot.name = "Poster Spot 4"
	poster(board_spot.get_node("Done"), Vector3(0.05, 1.55, -0.53), 0.0)
	own(nb)
	# Mr. Palmer's window: the Town Hall's front-left window, lit, with a flower box and a sign. Talk to him here.
	var hall := town.get_node("Town Hall") as Node3D
	var r := 7.0
	var wa := -0.42
	var w := Node3D.new()
	w.name = "Palmers Window"
	var front := Vector3(sin(wa), 0, cos(wa))
	var stand := Vector2(TOWN_HALL.x, TOWN_HALL.y) + Vector2(front.x, front.z) * (r + 1.6)
	w.position = front * (r + 1.6) + Vector3(0, height(stand.x, stand.y) - hall.position.y, 0)
	w.rotation.y = wa
	hall.add_child(w)
	var lit := mat("Palmers Window Light", Color(1.0, 0.86, 0.55), 0.4, 0.0, 1.6)
	var pane := mesh_at(box(Vector3(r * 0.32 - 0.25, r * 0.3 - 0.25, 0.34)), lit, Vector3.ZERO, hall, wa, Vector3(-0.35, 0, 0))
	pane.position = front * (r * 0.93) + Vector3(0, r * 0.42, 0)
	pane.name = "Palmers Window Pane"
	var curtain := mat("Curtain", Color(0.75, 0.25, 0.35), 0.9)
	for side in [-1, 1]:
		var cpos: Vector3 = front * (r * 0.93 + 0.05) + Vector3(0, r * 0.42, 0) + Vector3(cos(wa), 0, -sin(wa)) * (0.75 * side)
		mesh_at(box(Vector3(0.35, r * 0.3 - 0.25, 0.36)), curtain, cpos, hall, wa, Vector3(-0.35, 0, 0))
	var planter := mat("Planter", Color(0.5, 0.32, 0.2))
	var box_pos := front * (r * 0.93 + 0.3) + Vector3(0, r * 0.42 - 1.5, 0)
	mesh_at(box(Vector3(1.9, 0.3, 0.4)), planter, box_pos, hall, wa)
	mesh_at(box(Vector3(1.8, 0.04, 0.32)), mat("Soil", Color(0.3, 0.2, 0.12), 0.95), box_pos + Vector3(0, 0.15, 0), hall, wa)
	# (the flowers come with Bramble's quest: _town_quests())
	var office := Label3D.new()
	office.text = "Mayor's Office
(knock on the window)"
	office.font_size = 30
	office.pixel_size = 0.01
	office.outline_size = 8
	office.modulate = Color(1, 0.97, 0.88)
	office.outline_modulate = Color(0.2, 0.1, 0.25)
	office.position = Vector3(0, 1.0, -0.6)
	w.add_child(office)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", "mr_palmer")
	talk.set("display_name", "Mr. Palmer")
	talk.set("name_height", 2.6)
	talk.set("turns", false)
	w.add_child(talk)
	own(hall)
	own(g)


func quest_spot(parent: Node3D, flag: String, pos: Vector3, message: String, quest := "rex_campaign", step := "posters",
		action := "hang a poster") -> Area3D:
	# A spot (scripts/quest_spot.gd) where Nina can do something for a quest step (hang one of Rex's posters, pick
	# up a glow shell, fill a window box). What shows once it's done goes under its "Done" child, and what shows
	# only while it's waiting under "Before".
	var a := Area3D.new()
	a.set_script(load("res://scripts/quest_spot.gd"))
	a.set("quest", quest)
	a.set("step", step)
	a.set("flag", flag)
	a.set("done_message", message)
	a.set("action", action)
	a.position = pos
	parent.add_child(a)
	for child in ["Done", "Before"]:
		var n := Node3D.new()
		n.name = child
		a.add_child(n)
	return a


func quest_show(parent: Node3D, name: String, quest_done: String, hide_when_done := false) -> Node3D:
	# Part of the town that changes for good when a quest's finished (scripts/quest_show.gd)
	var n := Node3D.new()
	n.name = name
	n.set_script(load("res://scripts/quest_show.gd"))
	n.set("quest_done", quest_done)
	n.set("hide_when_done", hide_when_done)
	parent.add_child(n)
	return n


func poster(parent: Node3D, pos: Vector3, yaw: float) -> void:
	# A VOTE REX poster: yellow paper, red words, a paw print
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	mesh_at(box(Vector3(0.62, 0.84, 0.03)), mat("Poster Paper", Color(1.0, 0.9, 0.35), 0.9, 0.0, 0.0, 1.0, false), Vector3.ZERO, p)
	var l := Label3D.new()
	l.text = "VOTE
REX!"
	l.font_size = 34
	l.pixel_size = 0.006
	l.outline_size = 0
	l.modulate = Color(0.85, 0.15, 0.2)
	l.position = Vector3(0, 0.08, 0.02)
	l.double_sided = false
	p.add_child(l)
	var paw := mat("Poster Paw", Color(0.45, 0.3, 0.6), 0.8, 0.0, 0.0, 1.0, false)
	mesh_at(cylinder(0.07, 0.07, 0.01, 12), paw, Vector3(0, -0.27, 0.02), p, 0.0, Vector3(PI / 2, 0, 0))
	for t in 3:
		mesh_at(cylinder(0.03, 0.03, 0.01, 8), paw, Vector3(-0.07 + t * 0.07, -0.17 - absf(t - 1) * 0.02, 0.02), p, 0.0,
			Vector3(PI / 2, 0, 0))


# -----------------------------------------------------------------------------
# Pip's lamps and Bramble's window flowers (res://quests/pip_lamps.json, bramble_flowers.json): glow shells to find
# round the lake, lanterns along the boardwalks that light up once Pip has them, and window boxes on the homes and
# shops that bloom as Nina fills them (and the rest of them once Bramble's quest is done).
# -----------------------------------------------------------------------------
const GLOW_SHELLS := [Vector2(-29, 27), Vector2(-11, 26), Vector2(26, 23), Vector2(-50, 9), Vector2(-8, -30)]
const SHELL_PLACES := ["the southwest shore", "the south shore", "the dock", "the west shore", "the north boardwalk"]
const FLOWER_BOXES := [["Nina's House", "flowers_ninas_house"], ["Potion Shop", "flowers_potion_shop"],
	["Book Store", "flowers_book_store"], ["Dash's House", "flowers_dashs_house"]]
const BONUS_BOXES := ["Cafe", "Clothing Boutique", "Pet Shop", "Restaurant & Cafe", "Melanie's House", "Library"]
const FLOWER_COLORS := [Color(1.0, 0.45, 0.7), Color(1.0, 0.9, 0.3), Color(0.7, 0.5, 1.0), Color(1.0, 0.55, 0.35)]


func _town_quests() -> void:
	# Glow shells round the lake (only there while Pip's quest is looking for them)
	var shells := group("Glow Shells", Vector3.ZERO)
	for k in GLOW_SHELLS.size():
		var at: Vector2 = GLOW_SHELLS[k]
		var spot := quest_spot(shells, "glow_%d" % (k + 1), ground(at.x, at.y), "You found a glow shell!", "pip_lamps",
			"find", "pick up the glow shell")
		spot.name = "Glow Shell %d" % (k + 1)
		var shell := spot.get_node("Before") as Node3D
		var col: Color = [Color(0.5, 0.95, 1.0), Color(1.0, 0.6, 0.9), Color(1.0, 0.9, 0.5)][k % 3]
		var glow := mat("Glow Shell %d" % (k % 3), col, 0.2, 0.0, 2.2, 1.0, false)
		var body := mesh_at(sphere(0.28, 0.32, 16), glow, Vector3(0, 0.2, 0), shell)
		body.scale = Vector3(1.0, 1.0, 0.8)
		mesh_at(cylinder(0.0, 0.16, 0.3, 10), glow, Vector3(0, 0.45, 0), shell, 0.0, Vector3(0, 0, 0.5))
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.8
		light.omni_range = 3.0
		light.position = Vector3(0, 0.5, 0)
		shell.add_child(light)
	own(shells)
	# Pip's lanterns along the boardwalks: dim glass until the quest's done, then glowing moon-lamps
	var lanterns := group("Pip's Lanterns", Vector3.ZERO)
	var post_mat := mat("Boardwalk Post", Color(0.45, 0.3, 0.18))
	var dim := mat("Lantern Glass", Color(0.55, 0.55, 0.6), 0.2, 0.0, 0.0, 0.7, false)
	var cols := [Color(0.5, 0.95, 1.0), Color(1.0, 0.6, 0.9), Color(1.0, 0.9, 0.5)]
	var count := 0
	for bw in [[Vector2(-6, 21), Vector2(-8, -12), 3.0], [Vector2(-12, -30), Vector2(-12, -42), 3.0]]:
		var a: Vector2 = bw[0]
		var dir: Vector2 = bw[1] - a
		var yaw := atan2(dir.x, dir.y)
		var n := int(dir.length() / 4.0)
		var side := Vector2(cos(yaw), -sin(yaw)) * (float(bw[2]) / 2)
		for k in range(0, n + 1, 2):
			var q: Vector2 = a + dir * (float(k) / n) - side           # the other side from the boardwalk's own lamps
			var lp := Vector3(q.x, 0, q.y)
			mesh_at(cylinder(0.06, 0.06, 2.4, 8), post_mat, lp + Vector3(0, 1.4, 0), lanterns)
			mesh_at(box(Vector3(0.5, 0.06, 0.06)), post_mat, lp + Vector3(0, 2.55, 0), lanterns, yaw + PI / 2)
			var hang := lp + Vector3(0, 2.2, 0) + Vector3(side.x, 0, side.y).normalized() * -0.25
			var before := quest_show(lanterns, "Unlit Lantern %d" % count, "pip_lamps", true)
			mesh_at(sphere(0.2, -1, 12), dim, hang, before)
			var lit := quest_show(lanterns, "Lit Lantern %d" % count, "pip_lamps")
			var col: Color = cols[count % 3]
			mesh_at(sphere(0.26, -1, 14), mat("Moon Lamp %d" % (count % 3), col, 0.2, 0.0, 3.0, 1.0, false), hang, lit)
			mesh_at(sphere(0.45, -1, 14), mat("Moon Lamp Halo %d" % (count % 3), col, 0.2, 0.0, 1.0, 0.25, false), hang, lit)
			var l := night_light(lit, hang, col, 1.6, 8.0)
			l.name = "NightLight %d" % count
			count += 1
	own(lanterns)
	# Window boxes: Mr. Palmer's (on the Town Hall) and four more get flowers from Nina; the rest bloom at the end
	var hall := town.get_node("Town Hall") as Node3D
	var wa := -0.42
	var r := 7.0
	var front := Vector3(sin(wa), 0, cos(wa))
	var box_pos := front * (r * 0.93 + 0.3) + Vector3(0, r * 0.42 - 1.5, 0)
	_flower_spot(hall, "flowers_town_hall", box_pos, wa, front * (r + 2.6))
	for fb in FLOWER_BOXES:
		var g := town.get_node(fb[0]) as Node3D
		var br := ((g.get_child(0) as MeshInstance3D).mesh as SphereMesh).radius
		var bp := _window_box(g, br, 0.84)
		_flower_spot(g, fb[1], bp, 0.84, Vector3(sin(0.84), 0, cos(0.84)) * (br + 1.8))
	for name in BONUS_BOXES:
		var g := town.get_node(name) as Node3D
		var br := ((g.get_child(0) as MeshInstance3D).mesh as SphereMesh).radius
		var bp := _window_box(g, br, -0.84)
		var bloom := quest_show(g, "Window Flowers", "bramble_flowers")
		_flowers(bloom, bp, -0.84)
		own(g)


func _window_box(g: Node3D, r: float, a: float) -> Vector3:
	# An empty planter under the dome's window at angle a; returns where it is (in g's space)
	var out := Vector3(sin(a), 0, cos(a))
	var bp := out * (r * 0.93 + 0.45) + Vector3(0, r * 0.42 - r * 0.15 - 0.25, 0)
	mesh_at(box(Vector3(1.6, 0.3, 0.4)), mat("Planter", Color(0.5, 0.32, 0.2)), bp, g, a)
	mesh_at(box(Vector3(1.5, 0.04, 0.32)), mat("Soil", Color(0.3, 0.2, 0.12), 0.95), bp + Vector3(0, 0.15, 0), g, a)
	return bp


func _flower_spot(g: Node3D, flag: String, box_pos: Vector3, a: float, stand: Vector3) -> void:
	# Where Nina fills a window box for Bramble: she stands in front, the flowers go in the box
	var world := g.position + stand.rotated(Vector3.UP, g.rotation.y)
	stand.y = height(world.x, world.z) - g.position.y
	var spot := quest_spot(g, flag, stand, "The window box is blooming!", "bramble_flowers", "deliver",
		"put flowers in the window box")
	spot.name = "Flower Spot"
	_flowers(spot.get_node("Done"), box_pos - stand, a)
	own(g)


func _flowers(parent: Node3D, box_pos: Vector3, a: float) -> void:
	var along := Vector3(cos(a), 0, -sin(a))
	for q in 6:
		var col: Color = FLOWER_COLORS[q % FLOWER_COLORS.size()]
		var fp: Vector3 = box_pos + along * (-0.62 + q * 0.25) + Vector3(0, 0.3 + 0.06 * (q % 2), 0)
		mesh_at(cylinder(0.02, 0.02, 0.3, 5), mat("Flower Stem", Color(0.3, 0.6, 0.25), 0.8, 0.0, 0.0, 1.0, false),
			fp - Vector3(0, 0.15, 0), parent)
		mesh_at(sphere(0.13, -1, 10), mat("Window Flower %d" % (q % FLOWER_COLORS.size()), col, 0.6, 0.0, 0.2, 1.0, false),
			fp, parent)


# -----------------------------------------------------------------------------
# Sparkles (scripts/sparkle.gd): bits of broken time to find round town, the money for the market stalls. Most are
# out in the open off the paths; a few sit somewhere worth climbing or exploring to.
# -----------------------------------------------------------------------------
const SPARKLE_COUNT := 36
const SPARKLE_SPOTS := [Vector3(124.8, 7.3, 3.0), Vector3(-60, 0, -50), Vector3(-12, 0, -15), Vector3(-112, 0, -118),
	Vector3(105, 0, -80), Vector3(50, 0, 58), Vector3(78, 0, 90), Vector3(-26, 0, 23)]   # y 0: on the ground there


func _sparkles() -> void:
	var g := group("Sparkles", Vector3.ZERO)
	var script := load("res://scripts/sparkle.gd")
	var k := 0
	for at in SPARKLE_SPOTS:
		var p: Vector3 = ground(at.x, at.z) + Vector3(0, at.y, 0)
		_sparkle(g, script, k, p)
		k += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var tries := 0
	while k < SPARKLE_COUNT and tries < 4000:
		tries += 1
		var x := rng.randf_range(X_MIN + 15, X_MAX - 15)
		var z := rng.randf_range(Z_MIN + 15, Z_MAX - 15)
		if lake_f(x, z) < 2.0 or not _clear_spot(x, z, 2.0, 6.0):
			continue
		_sparkle(g, script, k, ground(x, z))
		k += 1
	own(g)
	print("SPARKLES ", k)


func _sparkle(g: Node3D, script: Script, k: int, p: Vector3) -> void:
	var a := Area3D.new()
	a.name = "Sparkle %d" % (k + 1)
	a.set_script(script)
	a.position = p
	g.add_child(a)


func _shops() -> void:
	# A shop spot in front of each market stall (scripts/shop_stall.gd; what they sell: res://shop/items.json)
	var square := town.get_node("Market Square") as Node3D
	for name in ["Fruit", "Sweets", "Crystals", "Flowers", "Records", "Toys"]:
		var stall := square.get_node("%s Stall" % name) as Node3D
		var a := Area3D.new()
		a.name = "Shop"
		a.set_script(load("res://scripts/shop_stall.gd"))
		a.set("stall", name)
		a.position = Vector3(0, 0, 1.7)                  # in front of the goods (the stall faces the fountain)
		stall.add_child(a)
	own(square)


func _happy_places() -> void:
	# Happy places (safe, calm spots from the show): find them all. Each one fills HP and MP and saves the game
	# (scripts/happy_place.gd). id, name, position
	var cave_z := PLATEAU.y + sqrt(pow(PLATEAU_CLIFF + 1.5, 2) - pow(-71.0 - PLATEAU.x, 2))
	var spots := [
		["cozy_cave", "Cozy Cave", ground(-71, cave_z + 3.0)],
		["cloud_nest", "Cloud Nest", Vector3(CLOUD_NEST.x - 4.5, ground(-70, -36).y + 5.8, CLOUD_NEST.y)],
		["tree_house", "Tree House", ground(TREE_HOUSE.x, TREE_HOUSE.y) + Vector3(1.5, 7.2, -1.0)],
		["warm_bath", "Warm Bath", ground(BUBBLE_BATH.x + 5.2, BUBBLE_BATH.y - 1.5)],
		["empty_library", "Empty Library", ground(-21, -41)],
		["observatory", "Observatory", ground(OBS_HILL.x - 9.0, OBS_HILL.y + 5.0)],
	]
	var g := group("Happy Places", Vector3.ZERO)
	var glow := mat("Happy Glow", Color(1.0, 0.8, 0.55), 0.2, 0.0, 2.5, 1.0, false)
	var halo := mat("Happy Halo", Color(1.0, 0.65, 0.85), 0.2, 0.0, 1.5, 0.7, false)
	for s in spots:
		var area := Area3D.new()
		area.name = "HappyPlace " + s[1]
		area.set_script(load("res://scripts/happy_place.gd"))
		area.set("place_id", s[0])
		area.set("place_name", s[1])
		area.set("total", spots.size())
		area.position = s[2]
		var cs := CollisionShape3D.new()
		cs.shape = _sphere_shape(1.6)
		cs.position = Vector3(0, 1.0, 0)
		area.add_child(cs)
		var vis := Node3D.new()
		vis.name = "Glow"
		vis.position = Vector3(0, 1.4, 0)
		area.add_child(vis)
		mesh_at(sphere(0.35, -1, 16), glow, Vector3.ZERO, vis)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.55
		ring.outer_radius = 0.65
		mesh_at(ring, halo, Vector3.ZERO, vis, 0.0, Vector3(PI / 2, 0, 0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.6)
		light.light_energy = 0.8
		light.omni_range = 4.0
		vis.add_child(light)
		g.add_child(area)
		keep_clear.append(Vector3(s[2].x, s[2].z, 2.5))
	own(g)
