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
const Z_MIN := -175.0
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
const CASTLE_HILL := Vector3(20, -108, 20)       # school hill: x, z, height
const CASTLE_HILL_TOP := 30.0                    # flat top radius: wide enough for the whole castle, domed halls too
const CASTLE_HILL_FOOT := 66.0                   # where the hill meets the town (clear of the north shore shops)
const TOWN_SQUARE := Vector3(-12, -21, 10)       # x, z, radius (land between the two lakes)
const CASTLE_SCALE := 1.6

const SPAWN := Vector3(5, 0, 62)

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
		# Violet sky fading to a hot pink horizon, a pinkish sun, and a light violet haze
		"sky_top": Color(0.12, 0.05, 0.3), "sky_horizon": Color(0.95, 0.42, 0.58), "sky_bottom": Color(0.1, 0.04, 0.18),
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
	return f


func height(x: float, z: float) -> float:
	var h := 0.35 * sin(x * 0.07) * cos(z * 0.05)
	var f := lake_f(x, z)
	h = lerpf(h, -BASIN_DEPTH, ss(1.25, 0.85, f))
	# Plateau: a cliff all round (for the caves and waterfalls), except a gentle ramp up on its southwest side
	var v := Vector2(x - PLATEAU.x, z - PLATEAU.y)
	var dp := v.length()
	var ramp := ss(0.8, 0.95, v.normalized().dot(PLATEAU_RAMP)) if dp > 0.01 else 0.0
	h += PLATEAU.z * (1.0 - ss(lerpf(PLATEAU_CLIFF - 3.0, 24.0, ramp), lerpf(PLATEAU_CLIFF + 2.0, 62.0, ramp), dp))
	var dc := Vector2(x - CASTLE_HILL.x, z - CASTLE_HILL.y).length()
	h += CASTLE_HILL.z * (1.0 - ss(CASTLE_HILL_TOP, CASTLE_HILL_FOOT, dc))
	return h


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
	_buildings()
	_castle()
	_plateau_features()
	_towers()
	_courts()
	_skate_park()
	_fence_and_sign()
	_boats()
	_town_hall()
	_haunted_house()
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
	_mountains()
	_sky_objects()
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
			elif f < 1.32:
				c = path                               # shoreline promenade around the lake
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
	plane.size = Vector2(700, 700)
	var g := group("Far Ground", Vector3.ZERO)
	mesh_at(plane, mat("Far Grass", T.far_grass, 1.0, 0.0, 0.0, 1.0, false), Vector3(0, -0.8, -30), g)
	own(g)


func _water() -> void:
	var g := group("Lake", Vector3.ZERO)
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 90)
	mesh_at(plane, mat("Water", T.water, 0.05, 0.2, T.water_glow, 0.82, false), Vector3(-2, WATER_Y, -10), g).name = "Water"
	own(g)


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
	sign_post(g, "Town Square", Vector3(0, 0, 6.5), 0.0)
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


func _sphere_shape(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _buildings() -> void:
	var blue := Color(0.3, 0.62, 0.98)
	# North shore row (faces south, toward the lake)
	dome_building("Museum", -40, -50, 7, 0.0, Color(0.98, 0.78, 0.2), [Vector4(-7, -2, 4.5, 0)])
	dome_building("Library", -12, -50, 8, 0.0, Color(0.98, 0.78, 0.2), [Vector4(8, -3, 5, 0)])
	dome_building("Cafe", 12, -47, 5, 0.0)
	_potion_shop(dome_building("Potion Shop", 30, -47, 6, 0.0, Color(0.55, 0.3, 0.9)))
	dome_building("Pet Shop", 48, -45, 5.5, 0.0)
	dome_building("Pet Shop 2", 64, -43, 5.5, 0.0)
	# East side (faces west, toward the lake)
	dome_building("Gaming Station", 90, -36, 8, -PI / 2, blue)
	dome_building("Aquarium", 92, -10, 8, -PI / 2, blue, [Vector4(8, -3, 5, 0)])      # side dome, clear of the door
	# South shore shops (face south, toward the courts)
	dome_building("Restaurant & Cafe", 35, 31, 6, 0.0)
	dome_building("Clothing Boutique", 52, 32, 6, 0.0)
	dome_building("Book Store", 69, 31, 6, 0.0)
	# Homes west of the lake, under the plateau
	_ninas_house(dome_building("Nina's House", -48, 24, 5, 0.4))
	_dashs_house(dome_building("Dash's House", -62, 30, 4.5, 0.3, Color(0.75, 0.8, 0.88)))
	dome_building("Melanie's House", -30, 30, 4.5, 0.0)
	# The Observatory on the northeast meadow, door facing the lake
	_observatory(dome_building("Observatory", 100, -88, 7, -0.85, Color(0.85, 0.85, 0.9)))


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
	# The castle school from Sofi's picture (source_art/reference/world/town - cast in front of the castle.webp):
	# a tall grey-blue fairytale castle, a crowd of slender towers with dark needle spires, gold-lit arched windows,
	# little turrets hanging off the big towers, and domed halls at its feet. Its colours skip the world theme on
	# purpose so it looks like her drawing. Positions are in castle units, multiplied by CASTLE_SCALE.
	var top := ground(CASTLE_HILL.x, CASTLE_HILL.y)
	var g := group("Castle School", top)
	var S := CASTLE_SCALE
	var stone := mat("Castle Stone", Color(0.34, 0.48, 0.72), 0.85, 0.0, 0.0, 1.0, false)
	var stone_dark := mat("Castle Stone Dark", Color(0.27, 0.38, 0.6), 0.85, 0.0, 0.0, 1.0, false)
	var roof := mat("Castle Roof", Color(0.11, 0.14, 0.24), 0.55, 0.1, 0.0, 1.0, false)
	var lit := mat("Castle Window", Color(1.0, 0.76, 0.28), 0.5, 0.0, 1.6, 1.0, false)
	var door := mat("Castle Door", Color(0.28, 0.2, 0.16), 0.8, 0.0, 0.0, 1.0, false)

	# Keep: the wide body the towers grow out of, with a battlement ring and rows of windows
	var keep_r := 9.0 * S
	var keep_h := 15.0 * S
	mesh_at(cylinder(keep_r * 0.96, keep_r, keep_h + 4 * S, 16), stone, Vector3(0, keep_h / 2 - 2 * S, 0), g)
	solid(_cyl_shape(keep_r, keep_h + 4 * S), Vector3(0, keep_h / 2 - 2 * S, 0), g)
	mesh_at(cylinder(keep_r * 1.04, keep_r * 0.96, 1.2 * S, 16), stone_dark, Vector3(0, keep_h + 0.6 * S, 0), g)
	for k in 16:
		var a := k * TAU / 16
		mesh_at(box(Vector3(1.4, 1.2, 1.0) * S), stone_dark, Vector3(sin(a), 0, cos(a)) * keep_r + Vector3(0, keep_h + 1.7 * S, 0), g, a)
	for row in 2:
		for k in 10:
			var a := (k + 0.5 * row) * TAU / 10
			if row == 0 and absf(wrapf(a, -PI, PI)) < 0.35:
				continue                                  # leave the gate clear
			arch_window(g, lit, Vector3.ZERO, a, keep_r * 0.98, (6.0 + row * 5.0) * S, 1.1 * S)

	# Towers: x, z, radius, height (top of the wall; the needle spire sits above it)
	var towers := [
		Vector4(0, -3, 3.6, 46),                          # the tall middle tower
		Vector4(-5, -7, 2.8, 36), Vector4(5, -7.5, 2.8, 39), Vector4(0, -11, 2.6, 33),
		Vector4(-3.5, 2.5, 2.3, 30), Vector4(3.8, 2, 2.2, 33),
		Vector4(-11, 2, 3.0, 24), Vector4(11, 2, 3.0, 26), Vector4(-8.5, -9, 2.6, 28), Vector4(8.5, -10, 2.6, 27),
		Vector4(-15, -5, 2.2, 20), Vector4(15, -5, 2.2, 21), Vector4(-5, 7, 2.2, 19), Vector4(5, 7, 2.2, 19),
		Vector4(-12, -12, 1.8, 18), Vector4(12, -13, 1.8, 19),
	]
	for i in towers.size():
		towers[i] = towers[i] * S
		var t: Vector4 = towers[i]
		var inside := Vector2(t.x, t.y).length() + t.z < keep_r     # windows only where they show above the keep
		castle_tower(g, Vector3(t.x, -2 * S, t.y), t.z, t.w, stone if i % 3 else stone_dark, roof, lit, i == 0, true,
			keep_h if inside else 0.0)

	# Castle walls joining the two outer back towers to the keep (they used to stand on their own beside it)
	for i in [10, 11]:
		var t: Vector4 = towers[i]
		var c := Vector2(t.x, t.y)
		var dir := c.normalized()
		var from := dir * (keep_r - 1.5 * S)                     # starts inside the keep's wall...
		var to := c - dir * (t.z * 0.4)                          # ...and ends inside the tower
		var mid := (from + to) / 2.0
		var length := from.distance_to(to)
		var yaw := atan2(dir.x, dir.y)
		var wall_h := 10.0 * S
		var wall_y := -2.0 * S + wall_h / 2.0
		mesh_at(box(Vector3(2.0 * S, wall_h, length)), stone_dark, Vector3(mid.x, wall_y, mid.y), g, yaw)
		solid(box_shape(Vector3(2.0 * S, wall_h, length)), Vector3(mid.x, wall_y, mid.y), g, yaw)
		var n := int(length / (1.6 * S))
		for k in n:                                            # battlements along both edges of the top
			var along := from + dir * ((k + 0.5) * length / n)
			for side in [-1, 1]:
				var off: Vector2 = Vector2(dir.y, -dir.x) * (0.75 * S) * side
				mesh_at(box(Vector3(0.5, 0.8, 0.7) * S), stone_dark, Vector3(along.x + off.x, wall_y + wall_h / 2.0 + 0.4 * S,
					along.y + off.y), g, yaw)
		for k in 2:                                            # a lit window on each face
			var w := from.lerp(to, 0.5)
			var face := Vector2(dir.y, -dir.x) * (1.05 * S) * (1 if k == 0 else -1)
			mesh_at(box(Vector3(0.9, 1.6, 0.1) * S), lit, Vector3(w.x + face.x, wall_y + 2.0 * S, w.y + face.y), g, yaw + PI / 2.0)

	# Turrets hanging off the big towers, high up: parent tower index, angle around it, radius, height above base
	var turrets := [
		Vector4(0, 0.9, 1.1, 30), Vector4(0, -0.9, 1.0, 34), Vector4(0, PI, 1.0, 26),
		Vector4(1, -1.3, 0.9, 24), Vector4(2, 1.4, 0.9, 27), Vector4(3, PI, 0.8, 22),
		Vector4(6, -1.6, 1.0, 16), Vector4(7, 1.6, 1.0, 18), Vector4(8, -2.2, 0.9, 19), Vector4(9, 2.2, 0.9, 18),
		Vector4(4, -0.7, 0.8, 21), Vector4(5, 0.7, 0.8, 23),
	]
	for tu in turrets:
		var p: Vector4 = towers[int(tu.x)]
		var dir := Vector3(sin(tu.y), 0, cos(tu.y))
		var r: float = tu.z * S
		var base: Vector3 = Vector3(p.x, tu.w * S, p.y) + dir * (p.z + r * 0.6)
		mesh_at(cylinder(r, 0.0, r * 2.2, 16), stone_dark, base + Vector3(0, -r * 1.1, 0), g)     # corbel underneath
		castle_tower(g, base, r, base.y + 4.5 * S, stone, roof, lit, false, false)

	# Domed halls at the castle's feet, left and right of the gate: x, z, radius
	for d in [Vector3(-16, 5, 6.0), Vector3(16, 5, 6.0), Vector3(-11.5, 11, 3.6), Vector3(11.5, 11, 3.6)]:
		var dp := Vector3(d.x, 0, d.y) * S
		dp.y = height(top.x + dp.x, top.z + dp.z) - top.y
		var low := dp.y                               # lowest ground round its wall, so no side floats on a slope
		for k in 12:
			var a := k * TAU / 12
			low = minf(low, height(top.x + dp.x + sin(a) * d.z * S, top.z + dp.z + cos(a) * d.z * S) - top.y)
		domed_hall(g, dp, d.z * S, stone, roof, lit, dp.y - low + 2.0)

	# Front gate (south): an arched door between two pillars, with the school entrance trigger
	var front := keep_r
	mesh_at(box(Vector3(5, 7, 1.2)), door, Vector3(0, 3.5, front + 0.2), g)
	mesh_at(cylinder(2.5, 2.5, 1.2, 24), door, Vector3(0, 7, front + 0.2), g, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(box(Vector3(7.5, 1.2, 1.6)), stone_dark, Vector3(0, 10.1, front + 0.4), g)
	for s in [-1, 1]:
		mesh_at(box(Vector3(1.2, 9.5, 1.6)), stone_dark, Vector3(s * 3.2, 4.75, front + 0.4), g)
	var area := Area3D.new()
	area.name = "SchoolEntrance"
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", "res://scenes/school/school.tscn")
	area.set("spawn", "FromTown")
	var back := Marker3D.new()                   # where she appears when leaving the school, facing the town
	back.name = "FromSchool"
	back.position = Vector3(0, 1.0, front + 6)
	back.rotation.y = PI
	g.add_child(back)
	area.position = Vector3(0, 2, front + 1.5)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(4, 4, 1.5))
	area.add_child(cs)
	g.add_child(area)
	var glow := OmniLight3D.new()                # warm light spilling out of the gate
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.light_energy = 2.0
	glow.omni_range = 10.0
	glow.position = Vector3(0, 4, front + 3)
	g.add_child(glow)
	sign_post(g, "School", Vector3(6, 0, front + 5), 0.0)
	keep_clear.append(Vector3(CASTLE_HILL.x, CASTLE_HILL.y, 40))
	own(g)


func arch_window(parent: Node, lit: Material, center: Vector3, a: float, r: float, y: float, w: float) -> void:
	# A gold-lit arched window on a round wall: wall centre (x, z), angle around it, wall radius, sill height, width
	var out := Vector3(center.x + sin(a) * r, y, center.z + cos(a) * r)
	mesh_at(box(Vector3(w, w * 1.3, 0.3)), lit, out + Vector3(0, w * 0.65, 0), parent, a)
	mesh_at(cylinder(w / 2, w / 2, 0.3, 12), lit, out + Vector3(0, w * 1.3, 0), parent, a, Vector3(PI / 2, 0, 0))


func castle_tower(parent: Node, base: Vector3, r: float, top_y: float, stone: Material, roof: Material, lit: Material,
		tallest := false, collide := true, windows_from := 0.0) -> void:
	# A slender round tower from base up to top_y, a corbelled ring, and a dark needle spire with a finial
	var h := top_y - base.y
	var pos := Vector3(base.x, base.y + h / 2, base.z)
	mesh_at(cylinder(r * 0.94, r, h, 20), stone, pos, parent)
	if collide:
		solid(_cyl_shape(r, h), pos, parent)
	mesh_at(cylinder(r * 1.18, r * 0.96, r * 0.45, 20), stone, Vector3(base.x, top_y - r * 0.1, base.z), parent)
	var spire := r * (8.5 if tallest else 6.5)
	mesh_at(cylinder(0.0, r * 1.1, spire, 20), roof, Vector3(base.x, top_y + r * 0.12 + spire / 2, base.z), parent)
	mesh_at(cylinder(0.0, maxf(r * 0.08, 0.06), r * 1.6, 6), roof, Vector3(base.x, top_y + spire + r * 0.7, base.z), parent)
	# Gold arched windows in staggered rows, more of them on the wider towers
	var per_row := 4 if r > 2.5 else 3
	var w := clampf(r * 0.32, 0.45, 1.6)
	var y := maxf(maxf(base.y, 0.0) + r * 2.0, windows_from + w)
	var row := 0
	while y < top_y - w * 2.5:
		for k in per_row:
			arch_window(parent, lit, base, (k + 0.5 * (row % 2)) * TAU / per_row + 0.3, r * 0.96, y, w)
		y += maxf(w * 4.5, h / 5.0)
		row += 1


func domed_hall(parent: Node, pos: Vector3, r: float, stone: Material, roof: Material, lit: Material, skirt := 3.0) -> void:
	# A round hall with a grey stone dome, gold arched windows all round, and a little spire on top.
	# skirt: how far its wall reaches below its centre, so it meets the ground on a slope
	var drum_h := r * 0.7
	mesh_at(cylinder(r, r * 1.03, drum_h + skirt, 32), stone, pos + Vector3(0, (drum_h - skirt) / 2, 0), parent)
	solid(_cyl_shape(r * 1.03, drum_h + skirt), pos + Vector3(0, (drum_h - skirt) / 2, 0), parent)
	mesh_at(cylinder(r * 1.06, r * 1.06, r * 0.12, 32), roof, pos + Vector3(0, drum_h, 0), parent)
	mesh_at(sphere(r * 0.98, r * 0.98 * 2, 32), stone, pos + Vector3(0, drum_h, 0), parent)
	solid(_sphere_shape(r * 0.98), pos + Vector3(0, drum_h, 0), parent)
	var n := int(r * 1.4)
	for k in n:
		arch_window(parent, lit, pos, k * TAU / n, r * 1.0, pos.y + drum_h * 0.15, r * 0.24)
	var spire_base := pos + Vector3(0, drum_h + r * 0.85, 0)
	castle_tower(parent, spire_base, r * 0.12, spire_base.y + r * 0.4, stone, roof, lit, false, false)


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
		mesh_at(cylinder(2.2, 2.2, 0.15, 24), steam, p + Vector3(0, 0.05, 4.0), hs)
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
	for w in [Vector2(0.15, 7.0), Vector2(0.55, 5.0)]:   # angle around the plateau (radians from east), width
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
	mushroom_tower("Castle Tower West", -24, -96, 24, true)
	mushroom_tower("Castle Tower East", 66, -104, 20, true)
	mushroom_tower("Castle Tower Back", 52, -132, 28, true)


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
	court("Basketball Court", 58, 52, Vector2(28, 15), Color(0.25, 0.55, 0.9), true)
	court("Tennis Court", 92, 52, Vector2(24, 11), Color(0.3, 0.62, 0.95), false, true)


func _skate_park() -> void:
	var c := ground(-8, 42)
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


func _fence_and_sign() -> void:
	var g := group("Fence", Vector3.ZERO)
	var wood := mat("Fence Wood", Color(0.6, 0.38, 0.2))
	var a := Vector2(-95, 38)
	var b := Vector2(-35, 72)
	var n := 22
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var y := height(p.x, p.y)
		mesh_at(box(Vector3(0.3, 1.6, 0.3)), wood, Vector3(p.x, y + 0.8, p.y), g)
	var dir := b - a
	var yaw := atan2(dir.x, dir.y)
	var mid := (a + b) / 2
	for rail_y in [0.6, 1.2]:
		mesh_at(box(Vector3(0.12, 0.18, dir.length())), wood, Vector3(mid.x, height(mid.x, mid.y) + rail_y, mid.y), g, yaw)
	sign_post(g, "Dream  Play  Explore  Grow", ground(-38, 58), 0.5)
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 22:
		var a := lerpf(-PI * 0.95, -PI * 0.05, k / 21.0) + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(210, 260)
		var h := rng.randf_range(55, 110)
		var p := Vector3(cos(a) * dist, -5, sin(a) * dist - 30)
		mesh_at(cylinder(0.0, h * 0.75, h, T.mountain_sides), far if k % 2 == 0 else near, p + Vector3(0, h / 2, 0), g,
			rng.randf() * TAU)
	own(g)


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
		if lake_f(x, z) < 1.5 or Vector2(x - SPAWN.x, z - SPAWN.z).length() < 14:
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
		if ok and Vector2(x - SPAWN.x, z - SPAWN.z).length() < 10:
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
	return true


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
	var counts := [0, 0, 0]
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

	var g := group("Foliage", Vector3.ZERO)
	g.set_script(load("res://scenes/town/foliage.gd"))
	g.set("positions", positions)
	g.set("kinds", kinds)
	g.set("sizes", sizes)
	g.set("yaws", yaws)
	g.set("colors", colors)
	g.set("stem_color", pal.mushroom_stem)
	own(g)
	print("FOLIAGE leaves=%d ferns=%d mushrooms=%d" % counts)


func _enemies() -> void:
	# Gloops (scenes/enemies/gloop.tscn) in small packs out in the meadows, and big ones guarding the plateau.
	# x, z, big?  Spots in the lake, inside a building's clear zone or near the spawn are skipped with a warning.
	var spots := [
		# South meadow, past the spawn
		Vector3(20, 98, 0), Vector3(-22, 82, 0), Vector3(-5, 100, 0),
		# East meadow beside the courts
		Vector3(115, 12, 0), Vector3(120, -25, 0), Vector3(112, 40, 0),
		# Foot of the castle hill
		Vector3(-40, -75, 0), Vector3(-15, -80, 0), Vector3(-2, -66, 0),
		# West fields
		Vector3(-100, 10, 0), Vector3(-115, -5, 0),
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
	own(g)
	print("GLOOPS ", placed)


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
# the happy places, and the portal to Earth. The town itself is Galactopia.
# -----------------------------------------------------------------------------
const TOWN_HALL := Vector3(16, 34, 0.0)           # x, z, yaw (door faces south, toward the spawn)
const HAUNTED_HOUSE := Vector3(-55, -95, 0.53)    # x, z, yaw (door faces the town)
const PORTAL := Vector3(30, 72, -1.95)            # x, z, yaw (faces the spawn)
const TREE_HOUSE := Vector2(-120, 25)
const ZIPLINE_END := Vector2(-130, -10)
const ROCK_WALL := Vector3(126, 58, -PI / 2)      # x, z, yaw (climbing face looks west)
const CLOUD_NEST := Vector2(-60, -50)             # above the plateau, a few cloud hops up from the Secret Gardens
const BUBBLE_BATH := Vector2(-60, 5)
const MURAL := Vector3(-30, 48, PI / 2)           # x, z, yaw (painted side faces the skate park)
const SOCCER := Vector2(62, 84)
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


func _antique_car() -> void:
	# A shiny old-fashioned car parked on the Town Square (the show's antique car theme)
	var sq := ground(TOWN_SQUARE.x, TOWN_SQUARE.y)
	var g := group("Antique Car", sq + Vector3(-5.6, 0.1, 1.5), 0.35)
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


func _welcome_sign() -> void:
	var g := group("Welcome Sign", ground(-1, 53))
	sign_post(g, "Welcome to Galactopia", Vector3.ZERO, 0.0)
	own(g)


func _portal() -> void:
	# A ring of light on a stone base: the way to Earth. It only opens during the Shift, midnight to 1 AM
	# (scripts/portal.gd shows the swirl, sparkles and glow then). There's no Earth scene yet, so the door says so.
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
	var bridge := quiet.lerp(loud, 0.5)                     # the two sides join in the middle
	puff(g, bridge - Vector3(0, 0.9, 0), 2.6, cloud, 23, 6)
	solid(_cyl_shape(2.6, 1.2), bridge - Vector3(0, 0.6, 0), g)
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
	own(g)


func _bubble_bath() -> void:
	# The magic bubble bath: a big tub of glowing pink water with bubbles rising out of it
	var g := group("Magic Bubble Bath", ground(BUBBLE_BATH.x, BUBBLE_BATH.y))
	var tub := mat("Tub", Color(0.98, 0.96, 0.98), 0.3, 0.1)
	var water := mat("Bath Water", Color(1.0, 0.55, 0.85), 0.1, 0.0, 0.8, 0.85)
	mesh_at(cylinder(4.2, 3.8, 1.4, 40), tub, Vector3(0, 0.5, 0), g)
	solid(_cyl_shape(4.2, 1.4), Vector3(0, 0.5, 0), g)
	mesh_at(cylinder(3.8, 3.8, 0.1, 40), water, Vector3(0, 1.22, 0), g)
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
	label3d(g, "Cloud Water Slide", center + Vector3(0, 9, 0), 140)
	own(g)


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
		["observatory", "Observatory", ground(92, -80)],
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
