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
const CASTLE_HILL := Vector3(20, -100, 20)       # school hill: x, z, height
const TOWN_SQUARE := Vector3(-12, -21, 10)       # x, z, radius (land between the two lakes)
const CASTLE_SCALE := 1.6

const SPAWN := Vector3(5, 0, 62)

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
	n.owner = town
	for c in n.get_children():
		own(c)


func add(n: Node, parent: Node = null) -> Node:
	(parent if parent else town).add_child(n)
	own(n)
	return n


func mat(name: String, color: Color, rough := 0.85, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
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
	h += CASTLE_HILL.z * (1.0 - ss(24.0, 62.0, dc))
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
	_mountains()
	_trees()
	_player()


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.55, 0.95)
	sky_mat.sky_horizon_color = Color(0.7, 0.85, 1.0)
	sky_mat.ground_horizon_color = Color(0.7, 0.85, 1.0)
	sky_mat.ground_bottom_color = Color(0.35, 0.5, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add(sun)


func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int((X_MAX - X_MIN) / STEP) + 1
	var nz := int((Z_MAX - Z_MIN) / STEP) + 1
	var grass := Color(0.36, 0.72, 0.27)
	var hill_grass := Color(0.3, 0.62, 0.24)
	var sand := Color(0.88, 0.8, 0.58)
	var path := Color(0.86, 0.82, 0.7)
	var rock := Color(0.55, 0.53, 0.5)
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
	mesh_at(plane, mat("Far Grass", Color(0.33, 0.6, 0.27), 1.0), Vector3(0, -0.8, -30), g)
	own(g)


func _water() -> void:
	var g := group("Lake", Vector3.ZERO)
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 90)
	mesh_at(plane, mat("Water", Color(0.12, 0.55, 0.92), 0.05, 0.2, 0.0, 0.82), Vector3(-2, WATER_Y, -10), g).name = "Water"
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
	own(g)


func _boardwalks() -> void:
	boardwalk("Boardwalk South", Vector2(-6, 21), Vector2(-8, -12))
	boardwalk("Boardwalk North", Vector2(-12, -30), Vector2(-12, -42))
	boardwalk("Boardwalk East", Vector2(30, -20), Vector2(46, -2))
	boardwalk("Dock", Vector2(22, 19), Vector2(22, 9), 2.5)


func dome_building(name: String, x: float, z: float, r: float, yaw: float, color := Color(0.98, 0.78, 0.2),
		extra := []) -> void:
	var c := ground(x, z)
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
	for e in extra:            # extra domes: Vector4(dx, dz, r, height offset)
		mesh_at(sphere(e.z, e.z * 2, 32), shell, Vector3(e.x, e.w, e.y), g)
		mesh_at(cylinder(e.z * 1.04, e.z * 1.06, 3.0, 32), trim, Vector3(e.x, e.w - 1.2, e.y), g)
		solid(_sphere_shape(e.z), Vector3(e.x, e.w, e.y), g)
	sign_post(g, name, Vector3(2.6, 0, r + 2.2), 0.0)
	var area := Area3D.new()
	area.name = "Door"
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", "res://scenes/interiors/%s.tscn" % name.to_snake_case())    # interiors come later
	area.set("spawn", "Entrance")
	area.position = Vector3(0, 1.2, r + 0.6)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(2.4, 2.6, 1.2))
	area.add_child(cs)
	g.add_child(area)
	keep_clear.append(Vector3(x, z, r + 6))
	own(g)


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
	dome_building("Pharmacy", 30, -47, 6, 0.0)
	dome_building("Pet Shop", 48, -45, 5.5, 0.0)
	dome_building("Pet Shop 2", 64, -43, 5.5, 0.0)
	# East side (faces west, toward the lake)
	dome_building("Gaming Station", 90, -36, 8, -PI / 2, blue)
	dome_building("Aquarium", 92, -10, 8, -PI / 2, blue, [Vector4(-3, 8, 5, 0)])
	# South shore shops (face south, toward the courts)
	dome_building("Restaurant & Cafe", 35, 31, 6, 0.0)
	dome_building("Clothing Boutique", 52, 32, 6, 0.0)
	dome_building("Book Store", 69, 31, 6, 0.0)
	# Homes west of the lake, under the plateau
	dome_building("House", -48, 24, 5, 0.4)
	dome_building("House 2", -62, 30, 4.5, 0.3)
	dome_building("House 3", -30, 30, 4.5, 0.0)


func _castle() -> void:
	var top := ground(CASTLE_HILL.x, CASTLE_HILL.y)
	var g := group("Castle School", top)
	var stone := mat("Castle Stone", Color(0.66, 0.66, 0.72), 0.9)
	var roof := mat("Castle Roof", Color(0.36, 0.42, 0.58), 0.6)
	var lit := mat("Castle Window", Color(1.0, 0.85, 0.4), 0.5, 0.0, 1.5)
	var door := mat("Door", Color())
	# Keep and towers: (dx, dz, radius, height), scaled up so the school looms over the town
	var towers := [Vector4(0, 0, 9, 18), Vector4(0, -4, 3.2, 40), Vector4(-11, 2, 3.4, 26), Vector4(11, 2, 3.4, 26),
		Vector4(-8, -9, 3.0, 30), Vector4(8, -9, 3.0, 30), Vector4(-15, -5, 2.6, 22), Vector4(15, -5, 2.6, 22),
		Vector4(-5, 7, 2.4, 20), Vector4(5, 7, 2.4, 20)]
	for i in towers.size():
		towers[i] = towers[i] * CASTLE_SCALE
	for t in towers:
		mesh_at(cylinder(t.z, t.z * 1.05, t.w + 4, 32), stone, Vector3(t.x, t.w / 2 - 2, t.y), g)
		solid(_cyl_shape(t.z * 1.05, t.w + 4), Vector3(t.x, t.w / 2 - 2, t.y), g)
		mesh_at(cylinder(0.0, t.z * 1.25, t.z * 2.4, 32), roof, Vector3(t.x, t.w + t.z * 1.2, t.y), g)
		for k in 4:                                   # lit window slits
			var a := k * PI / 2 + 0.4
			mesh_at(box(Vector3(0.5, 1.4, 0.3)), lit, Vector3(t.x + sin(a) * t.z, t.w * 0.7, t.y + cos(a) * t.z), g, a)
	# Front gate (south) with the school entrance trigger
	var front := 9.0 * CASTLE_SCALE
	mesh_at(box(Vector3(5, 7, 1.2)), door, Vector3(0, 3.5, front + 0.2), g)
	mesh_at(box(Vector3(7.5, 1.2, 1.6)), stone, Vector3(0, 7.6, front + 0.4), g)
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
	sign_post(g, "School", Vector3(6, 0, front + 5), 0.0)
	keep_clear.append(Vector3(CASTLE_HILL.x, CASTLE_HILL.y, 24))
	own(g)


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


func mushroom_tower(name: String, x: float, z: float, h: float) -> void:
	var g := group(name, ground(x, z))
	var yellow := mat("Tower Yellow", Color(0.98, 0.8, 0.25), 0.5)
	var band := mat("Tower Band", Color(0.85, 0.55, 0.1), 0.6)
	var cap_glass := mat("Tower Glass", Color(0.35, 0.75, 1.0), 0.05, 0.1, 0.4, 0.7)
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


func court(name: String, x: float, z: float, size: Vector2, color: Color, basketball: bool) -> void:
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
	sign_post(g, "Basketball Court" if basketball else "Tennis Court", Vector3(0, 0, size.y / 2 + 2.5), 0.0)
	keep_clear.append(Vector3(x, z, maxf(size.x, size.y) / 2 + 3))
	own(g)


func _courts() -> void:
	court("Basketball Court", 58, 52, Vector2(28, 15), Color(0.25, 0.55, 0.9), true)
	court("Tennis Court", 92, 52, Vector2(24, 11), Color(0.3, 0.62, 0.95), false)


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
	var far := mat("Mountain", Color(0.42, 0.5, 0.68), 1.0)
	var near := mat("Mountain Near", Color(0.38, 0.55, 0.45), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 22:
		var a := lerpf(-PI * 0.95, -PI * 0.05, k / 21.0) + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(210, 260)
		var h := rng.randf_range(55, 110)
		var p := Vector3(cos(a) * dist, -5, sin(a) * dist - 30)
		mesh_at(cylinder(0.0, h * 0.75, h, 10), far if k % 2 == 0 else near, p + Vector3(0, h / 2, 0), g)
	own(g)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var palette := [Color(0.2, 0.6, 0.25), Color(0.25, 0.7, 0.3), Color(0.55, 0.3, 0.75), Color(0.9, 0.45, 0.7),
		Color(0.95, 0.6, 0.2), Color(0.18, 0.5, 0.3)]
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
	own(g)
	print("TREES ", spots.size())


func _player() -> void:
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = ground(SPAWN.x, SPAWN.z) + Vector3(0, 1.0, 0)
	town.add_child(player)
	player.owner = town                     # saved as a reference to player.tscn, not a copy of its insides
