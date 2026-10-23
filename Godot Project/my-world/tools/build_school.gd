extends SceneTree

# Builds res://scenes/school/school.tscn: a walkable blockout of the castle school interior, from the floor plans in
# source_art/reference/world/ (1st floor: foyer, library, lockers; 2nd: classrooms; 3rd: offices).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_school.gd
#
# Units are meters. +X is east, -Z is north. The main floors span X_W..X_E and Z_N..Z_S; the west atrium
# (ATRIUM_W..X_W) holds the escalators and stairs and is open all the way up.

const WT := preload("res://tools/theme.gd")     # shared look (alien/earth): tools/theme.gd
const BT := preload("res://tools/build_town.gd")   # the town outside: its sky, mountains and clouds, for the view
const OUT_DIR := "res://scenes/school"
const OUT := OUT_DIR + "/school.tscn"

const X_W := -30.0          # west edge of the floors (the atrium is west of this)
const X_E := 30.0
const Z_N := -24.0
const Z_S := 24.0
const ATRIUM_W := -40.0
const FLOOR_H := 6.0        # floor-to-floor height
const WALL_H := 5.7         # interior walls stop just under the next slab
const DOOR_W := 2.4
const DOOR_H := 3.0
const ESCALATOR_SPEED := 1.6
const SLIVER_MP_LEVEL := 3     # MP level needed to pass through the Slivers into Behind the Walls
const WINDOW_X := 24.0         # the 3rd floor's window wall is open from -WINDOW_X to WINDOW_X along the north side
const WINDOW_Y := Vector2(0.8, 4.8)   # its sill and top, above the 3rd floor
# Where the school stands in the town (on the castle hill), so the view out of the windows lines up with the town's
# own mountains and clouds: town position = school position + IN_TOWN
const IN_TOWN := Vector3(BT.CASTLE_HILL.x, BT.CASTLE_HILL.z, BT.CASTLE_HILL.y)

var school: Node3D
var mats := {}


func _initialize() -> void:
	school = Node3D.new()
	school.name = "School"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build()
	var scene := PackedScene.new()
	var err := scene.pack(school)
	print("SAVED ", OUT, " pack=", err, " save=", ResourceSaver.save(scene, OUT))
	school.free()
	quit()


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func own(n: Node) -> void:
	if n != school:
		n.owner = school
	if n != school and n.scene_file_path != "":
		return                                    # instanced scene (the player): keep it a reference, not a copy
	for c in n.get_children():
		own(c)


func mat(name: String, color: Color, rough := 0.85, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
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


func sphere(r: float, segments := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = segments
	s.rings = segments / 2
	return s


func node(name: String, parent: Node, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


func mesh_at(mesh: Mesh, material: Material, pos: Vector3, parent: Node, yaw := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	parent.add_child(mi)
	return mi


func solid_box(size: Vector3, material: Material, pos: Vector3, parent: Node, yaw := 0.0, rot := Vector3.ZERO,
		collide := true) -> Node3D:
	if not collide:
		return mesh_at(box(size), material, pos, parent, yaw, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(size)
	body.add_child(cs)
	mesh_at(box(size), material, Vector3.ZERO, body)
	parent.add_child(body)
	return body


func solid_cylinder(r: float, h: float, material: Material, pos: Vector3, parent: Node) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	mesh_at(cylinder(r, r, h, 24), material, Vector3.ZERO, body)
	parent.add_child(body)
	return body


func label(parent: Node, text: String, pos: Vector3, yaw := 0.0, size := 48) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.15, 0.12, 0.2)
	l.position = pos
	l.rotation.y = yaw
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(l)


func wall(parent: Node, a: Vector2, b: Vector2, material: Material, doors := [], h := WALL_H, thick := 0.3) -> void:
	# A straight wall from a to b (x, z) on the parent's floor. doors: list of positions 0..1 along the wall.
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var yaw := atan2(dir.x, dir.y)
	var cuts: Array = []
	for t in doors:
		cuts.append(Vector2(t * length - DOOR_W / 2, t * length + DOOR_W / 2))
	cuts.sort()
	var start := 0.0
	var pieces: Array = []
	for c in cuts:
		pieces.append(Vector2(start, c.x))
		start = c.y
	pieces.append(Vector2(start, length))
	for p in pieces:
		if p.y - p.x < 0.05:
			continue
		var mid: Vector2 = a + dir * ((p.x + p.y) / 2)
		solid_box(Vector3(thick, h, p.y - p.x), material, Vector3(mid.x, h / 2, mid.y), parent, yaw)
	for c in cuts:                                    # lintel above each doorway
		var mid: Vector2 = a + dir * ((c.x + c.y) / 2)
		solid_box(Vector3(thick, h - DOOR_H, DOOR_W), material, Vector3(mid.x, DOOR_H + (h - DOOR_H) / 2, mid.y), parent, yaw)


func arc_wall(parent: Node, center: Vector2, r: float, a0: float, a1: float, material: Material, segments := 8,
		h := WALL_H) -> void:
	# A curved wall: arc of radius r around center from angle a0 to a1 (radians, 0 = +x, pi/2 = +z).
	for k in segments:
		var t0 := lerpf(a0, a1, float(k) / segments)
		var t1 := lerpf(a0, a1, float(k + 1) / segments)
		var p0 := center + Vector2(cos(t0), sin(t0)) * r
		var p1 := center + Vector2(cos(t1), sin(t1)) * r
		wall(parent, p0, p1, material, [], h, 0.3)


func room(parent: Node, name: String, x0: float, z0: float, x1: float, z1: float, material: Material,
		doors := {}, alcove := "") -> void:
	# Rectangular room. doors: {"n": [t..], "s": [...], "e": [...], "w": [...]}; alcove: side with a round bay.
	var r := node(name, parent)
	var bay_r := minf(absf(x1 - x0), absf(z1 - z0)) * 0.22
	var sides := {"n": [Vector2(x0, z0), Vector2(x1, z0)], "s": [Vector2(x0, z1), Vector2(x1, z1)],
		"w": [Vector2(x0, z0), Vector2(x0, z1)], "e": [Vector2(x1, z0), Vector2(x1, z1)]}
	for side in sides:
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var dl: Array = doors.get(side, [])
		if side == alcove:
			# split the wall around a semicircular bay bulging outward
			var mid := (a + b) / 2
			var dir := (b - a).normalized()
			wall(r, a, mid - dir * bay_r, material, [])
			wall(r, mid + dir * bay_r, b, material, [])
			var outward: Vector2 = {"n": Vector2(0, -1), "s": Vector2(0, 1), "w": Vector2(-1, 0), "e": Vector2(1, 0)}[side]
			var start := atan2(-dir.y, -dir.x)
			var sweep := PI if Vector2(cos(start + PI / 2), sin(start + PI / 2)).dot(outward) > 0 else -PI
			arc_wall(r, mid, bay_r, start, start + sweep, material)
		else:
			wall(r, a, b, material, dl)
	label(r, name, Vector3((x0 + x1) / 2, 3.6, (z0 + z1) / 2), 0.0, 64)


func spawn_marker(parent: Node, name: String, pos: Vector3, yaw: float) -> void:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.rotation.y = yaw
	parent.add_child(m)


func door_trigger(parent: Node, name: String, pos: Vector3, size: Vector3, destination: String, spawn: String) -> void:
	var area := Area3D.new()
	area.name = name
	area.position = pos
	area.set_script(load("res://scripts/door.gd"))
	area.set("destination", destination)
	area.set("spawn", spawn)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(size)
	area.add_child(cs)
	parent.add_child(area)


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
func _build() -> void:
	_environment()
	_shell()
	_atrium()
	_floor_1()
	_floor_2()
	_floor_3()
	_entrance_garden()
	_view()
	_player()
	own(school)


func _environment() -> void:
	# The town's own sky, seen through the windows and over the Entrance Garden. Rooms keep their own even light.
	var t: Dictionary = BT.THEMES[WT.THEME]
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = t.sky_top
	sky_mat.sky_horizon_color = t.sky_horizon
	sky_mat.ground_horizon_color = t.sky_horizon
	sky_mat.ground_bottom_color = t.sky_bottom
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = WT.light(Color(1.0, 0.97, 0.92))
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if t.fog:
		# Haze on the far hills and mountains only, not in the rooms
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = t.fog_color
		env.fog_density = 0.55
		env.fog_depth_begin = 90.0
		env.fog_depth_end = 700.0
		env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	school.add_child(we)
	# The sky outside follows the clock like the town's (scripts/day_night.gd); it has no sun to move in here
	var day_night := Node.new()
	day_night.name = "DayNight"
	day_night.set_script(load("res://scripts/day_night.gd"))
	day_night.set("sun_path", NodePath(""))
	school.add_child(day_night)
	var sun := DirectionalLight3D.new()
	sun.name = "Light"
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 0.6
	school.add_child(sun)
	# Ceiling lights on each floor
	for f in 3:
		for x in [-15.0, 0.0, 15.0]:
			for z in [-12.0, 0.0, 12.0]:
				var l := OmniLight3D.new()
				l.position = Vector3(x, f * FLOOR_H + 5.0, z)
				l.omni_range = 14.0
				l.light_energy = 0.9
				l.light_color = WT.light(Color(1.0, 0.95, 0.85))
				school.add_child(l)


func _shell() -> void:
	# Floor slabs, roof and outer walls for the whole building.
	var shell := node("Shell", school)
	var stone := mat("Outer Wall", Color(0.72, 0.72, 0.78))
	var floors := [mat("Floor 1", Color(0.78, 0.68, 0.55)), mat("Floor 2", Color(0.62, 0.72, 0.82)),
		mat("Floor 3", Color(0.7, 0.66, 0.6))]
	for f in 3:
		var y := f * FLOOR_H
		var slab := node("Slab %d" % (f + 1), shell)
		solid_box(Vector3(X_E - X_W, 0.3, Z_S - Z_N), floors[f], Vector3((X_W + X_E) / 2, y - 0.15, (Z_N + Z_S) / 2), slab)
	solid_box(Vector3(X_E - ATRIUM_W, 0.3, Z_S - Z_N), stone, Vector3((ATRIUM_W + X_E) / 2, 3 * FLOOR_H - 0.15, 0), shell)
	solid_box(Vector3(X_W - ATRIUM_W, 0.3, Z_S - Z_N), mat("Atrium Floor", Color(0.8, 0.78, 0.74)),
		Vector3((ATRIUM_W + X_W) / 2, -0.15, 0), shell)
	var h := 3 * FLOOR_H
	var outer := node("Outer Walls", shell)
	# North wall: open along the 3rd floor's window wall (glass and frames in _floor_3)
	var sill := 2 * FLOOR_H + WINDOW_Y.x
	var top := 2 * FLOOR_H + WINDOW_Y.y
	wall(outer, Vector2(ATRIUM_W, Z_N), Vector2(X_E, Z_N), stone, [], sill, 0.6)
	var above := node("Above Window", outer, Vector3(0, top, 0))
	wall(above, Vector2(ATRIUM_W, Z_N), Vector2(X_E, Z_N), stone, [], h - top, 0.6)
	var beside := node("Beside Window", outer, Vector3(0, sill, 0))
	wall(beside, Vector2(ATRIUM_W, Z_N), Vector2(-WINDOW_X, Z_N), stone, [], top - sill, 0.6)
	wall(beside, Vector2(WINDOW_X, Z_N), Vector2(X_E, Z_N), stone, [], top - sill, 0.6)
	wall(outer, Vector2(ATRIUM_W, Z_S), Vector2(X_E, Z_S), stone, [(0.0 - ATRIUM_W) / (X_E - ATRIUM_W)], h, 0.6)   # front door
	wall(outer, Vector2(ATRIUM_W, Z_N), Vector2(ATRIUM_W, Z_S), stone, [], h, 0.6)
	wall(outer, Vector2(X_E, Z_N), Vector2(X_E, Z_S), stone, [], h, 0.6)


func escalator(parent: Node, name: String, x: float, z_bottom: float, z_top: float, y_bottom: float, up: bool) -> void:
	# A moving ramp from (x, y_bottom, z_bottom) to (x, y_bottom + FLOOR_H, z_top). Carries whoever stands on it.
	var run := z_top - z_bottom
	var length := sqrt(run * run + FLOOR_H * FLOOR_H)
	var pitch := atan2(FLOOR_H, absf(run))
	var dir := Vector3(0, FLOOR_H, run).normalized()
	var body := StaticBody3D.new()
	body.name = name
	body.position = Vector3(x, y_bottom + FLOOR_H / 2, (z_bottom + z_top) / 2)
	body.rotation.x = pitch if run < 0 else -pitch
	var zone := Area3D.new()                         # carries whoever stands on the steps (scripts/escalator.gd)
	zone.name = "Carry"
	zone.set_script(load("res://scripts/escalator.gd"))
	zone.set("carry", dir * ESCALATOR_SPEED * (1.0 if up else -1.0))
	zone.position = Vector3(0, 0.9, 0)
	var zs := CollisionShape3D.new()
	zs.shape = box_shape(Vector3(2.0, 1.5, length))
	zone.add_child(zs)
	body.add_child(zone)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(2.0, 0.3, length))
	body.add_child(cs)
	mesh_at(box(Vector3(2.0, 0.3, length)), mat("Escalator Steps", Color(0.35, 0.37, 0.42), 0.4, 0.6), Vector3.ZERO, body)
	var rail := mat("Escalator Rail", Color(0.15, 0.15, 0.18), 0.3)
	for s in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.15, 1.0, length)), rail, Vector3(s * 1.08, 0.55, 0), body)
	parent.add_child(body)
	label(parent, ("Up" if up else "Down") + " escalator", Vector3(x, y_bottom + (0.0 if up else FLOOR_H) + 2.5,
		z_bottom if up else z_top))


func stairs(parent: Node, x: float, z_bottom: float, z_top: float, y_bottom: float) -> void:
	# Visual steps with a smooth ramp underneath for walking.
	var run := z_top - z_bottom
	var steps := 20
	var tread := mat("Stairs", Color(0.7, 0.62, 0.52))
	for k in steps:
		var z := z_bottom + run * (k + 0.5) / steps
		var y := y_bottom + FLOOR_H * (k + 0.5) / steps
		mesh_at(box(Vector3(4.0, FLOOR_H / steps, absf(run) / steps)), tread, Vector3(x, y - FLOOR_H / steps / 2, z), parent)
	var length := sqrt(run * run + FLOOR_H * FLOOR_H)
	var body := StaticBody3D.new()
	body.position = Vector3(x, y_bottom + FLOOR_H / 2 - 0.1, (z_bottom + z_top) / 2)
	body.rotation.x = atan2(FLOOR_H, absf(run)) * (1.0 if run < 0 else -1.0)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(4.0, 0.2, length))
	body.add_child(cs)
	parent.add_child(body)
	label(parent, "Stairs", Vector3(x, y_bottom + 2.5, z_bottom))


func _atrium() -> void:
	# Open atrium on the west side: escalators up/down between floors, stairs from 1 to 2, balconies to each floor.
	var a := node("Atrium", school)
	var stone := mat("Atrium Wall", Color(0.82, 0.8, 0.86))
	var deck := mat("Balcony", Color(0.75, 0.72, 0.7))
	var glass := mat("Balcony Glass", Color(0.7, 0.9, 1.0), 0.05, 0.0, 0.0, 0.35)
	# Floor 1 -> 2: escalators side by side, plus the platform they arrive on
	escalator(a, "Escalator 1 Up", -37.5, 18, 6, 0, true)
	escalator(a, "Escalator 1 Down", -35.0, 18, 6, 0, false)
	solid_box(Vector3(8, 0.3, 6), deck, Vector3(-36, FLOOR_H - 0.15, 3), a)
	# Floor 2 -> 3
	escalator(a, "Escalator 2 Up", -37.5, 0, -12, FLOOR_H, true)
	escalator(a, "Escalator 2 Down", -35.0, 0, -12, FLOOR_H, false)
	solid_box(Vector3(8, 0.3, 6), deck, Vector3(-36, 2 * FLOOR_H - 0.15, -15), a)
	# Stairs from floor 1 to floor 2 at the north end, landing on their own platform
	stairs(a, -36, -8, -20, 0)
	solid_box(Vector3(8, 0.3, 4), deck, Vector3(-36, FLOOR_H - 0.15, -22), a)
	# Balconies along the floors' west edge on floors 2 and 3, with glass railings
	var railings := {1: [[-20.0, 0.0], [6.0, 24.0]], 2: [[-24.0, -18.0], [-12.0, 24.0]]}   # gaps where platforms join
	for f in [1, 2]:
		var y2: float = f * FLOOR_H
		solid_box(Vector3(2.0, 0.3, Z_S - Z_N), deck, Vector3(X_W - 1.0, y2 - 0.15, 0), a)
		for zz in railings[f]:
			var z0: float = zz[0]
			var z1: float = zz[1]
			solid_box(Vector3(0.1, 1.1, z1 - z0), glass, Vector3(X_W - 2.0, y2 + 0.55, (z0 + z1) / 2), a)
	# Wall between the atrium and the floors, with wide openings on every floor
	for f in 3:
		var fl := node("Atrium Wall %d" % (f + 1), a, Vector3(0, f * FLOOR_H, 0))
		wall(fl, Vector2(X_W, Z_N), Vector2(X_W, Z_S), stone, [0.2, 0.5, 0.8])
	label(a, "Escalators & Stairs", Vector3(-35, 4.5, 21), 0.0, 80)


# ----------------------------------------------------------------------------- Floor 1
func _floor_1() -> void:
	var f := node("Floor 1", school)
	var wall_mat := mat("Wall 1", Color(0.96, 0.92, 0.82))
	label(f, "1st Floor", Vector3(0, 4.8, 21), 0.0, 96)
	# Front wall with the main doors into the foyer (replaces the plain outer wall's lower part)
	var foyer := node("Foyer", f)
	solid_box(Vector3(7, 1.1, 1.4), mat("Front Desk", Color(0.55, 0.35, 0.2)), Vector3(0, 0.55, 15), foyer)
	label(foyer, "Foyer", Vector3(0, 3.2, 15), 0.0, 72)
	wall(foyer, Vector2(-14, 10), Vector2(-14, 24), wall_mat, [0.35])
	wall(foyer, Vector2(14, 10), Vector2(14, 24), wall_mat, [0.35])
	wall(foyer, Vector2(-14, 10), Vector2(14, 10), wall_mat, [0.2, 0.5, 0.8])

	# Library: an oval of bookshelves with four openings, reading tables, and the restroom in the middle
	var lib := node("Library", f, Vector3(0, 0, -6))
	var shelf := mat("Bookshelf", Color(0.48, 0.3, 0.17))
	var books := [mat("Books Red", Color(0.8, 0.25, 0.25)), mat("Books Blue", Color(0.25, 0.45, 0.85)),
		mat("Books Green", Color(0.3, 0.65, 0.35)), mat("Books Yellow", Color(0.92, 0.75, 0.25))]
	var rx := 14.0
	var rz := 8.5
	var segments := 28
	for k in segments:
		var t0 := TAU * k / segments
		var t1 := TAU * (k + 1) / segments
		if k % 7 == 0:
			continue                                  # doorways N, E, S, W
		var p0 := Vector2(cos(t0) * rx, sin(t0) * rz)
		var p1 := Vector2(cos(t1) * rx, sin(t1) * rz)
		var mid := (p0 + p1) / 2
		var yaw := atan2(p1.x - p0.x, p1.y - p0.y)
		solid_box(Vector3(0.8, 2.6, p0.distance_to(p1)), shelf, Vector3(mid.x, 1.3, mid.y), lib, yaw)
		mesh_at(box(Vector3(0.9, 0.5, p0.distance_to(p1) * 0.9)), books[k % 4], Vector3(mid.x, 1.9, mid.y), lib, yaw)
	for tx in [-8.0, 8.0]:
		for tz in [-3.0, 3.0]:
			solid_box(Vector3(3, 0.8, 1.6), mat("Table", Color(0.85, 0.7, 0.5)), Vector3(tx, 0.4, tz), lib)
	restroom_pod(lib, Vector3(0, 0, 0), 2.4)
	label(lib, "Library", Vector3(0, 4.2, -5), 0.0, 96)

	# Four locker wings, each ringed by restroom pods
	locker_wing(f, "Upper Grade Lockers", Vector3(-19, 0, -16), 0.5, mat("Lockers Upper", Color(0.3, 0.5, 0.85), 0.5, 0.4))
	locker_wing(f, "Upper Grade Lockers ", Vector3(19, 0, -16), -0.5, mat("Lockers Upper", Color()))
	locker_wing(f, "Lower Grade Lockers", Vector3(20, 0, 4), -1.4, mat("Lockers Lower", Color(0.9, 0.4, 0.35), 0.5, 0.4))
	locker_wing(f, "Lower Grade Lockers ", Vector3(-21, 0, 12), 0.7, mat("Lockers Lower", Color()))

	# Low partitions fanning out from the foyer toward the corners, like the drawing's diagonal walls
	var part := mat("Partition", Color(0.88, 0.85, 0.95))
	wall(f, Vector2(-14, 10), Vector2(-26, 2), part, [], 2.4, 0.25)
	wall(f, Vector2(14, 10), Vector2(26, -6), part, [], 2.4, 0.25)
	wall(f, Vector2(-8, -15), Vector2(-14, -22), part, [], 2.4, 0.25)
	wall(f, Vector2(8, -15), Vector2(14, -22), part, [], 2.4, 0.25)


func restroom_pod(parent: Node, pos: Vector3, r := 1.5) -> void:
	var pod := node("Restroom", parent, pos)
	solid_cylinder(r, 3.0, mat("Restroom", Color(0.45, 0.78, 0.8), 0.5), Vector3(0, 1.5, 0), pod)
	mesh_at(box(Vector3(1.0, 2.2, 0.2)), mat("Restroom Door", Color(0.2, 0.42, 0.5)), Vector3(0, 1.1, r), pod)
	label(pod, "RR", Vector3(0, 3.5, 0), 0.0, 56)


func locker_wing(parent: Node, name: String, pos: Vector3, yaw: float, locker_mat: Material) -> void:
	var w := node(name.strip_edges(), parent, pos, yaw)
	solid_box(Vector3(9, 2.4, 1.0), locker_mat, Vector3(0, 1.2, 0), w)
	var seam := mat("Locker Seams", Color(0.15, 0.15, 0.2))
	for k in 10:
		mesh_at(box(Vector3(0.05, 2.3, 1.05)), seam, Vector3(-4.5 + k * 1.0, 1.2, 0), w)
	label(w, name.strip_edges(), Vector3(0, 3.3, 0), 0.0, 56)
	for k in 5:                                       # restroom pods on an arc behind the lockers
		var a := lerpf(-2.4, -0.7, k / 4.0)
		restroom_pod(w, Vector3(cos(a) * 7.5, 0, sin(a) * 5.5 - 1.0), 1.3)


# ----------------------------------------------------------------------------- Floor 2
func _floor_2() -> void:
	var f := node("Floor 2", school, Vector3(0, FLOOR_H, 0))
	var wall_mat := mat("Wall 2", Color(0.9, 0.93, 0.98))
	var class_mat := mat("Classroom Wall", Color(0.98, 0.9, 0.7))
	label(f, "2nd Floor - Classrooms", Vector3(-25, 4.8, 18), 0.0, 80)

	# "Behind the Walls": a hidden passage along the north and east edges. The only ways in are the two Slivers,
	# which stay sealed until the player's MP level is high enough (scripts/sliver.gd).
	var behind := node("Behind The Walls", f)
	var inner := mat("Inner Wall", Color(0.9, 0.93, 0.98))
	wall(behind, Vector2(X_W + 3, Z_N + 3), Vector2(X_E - 3, Z_N + 3), inner, [0.85])
	wall(behind, Vector2(X_E - 3, Z_N + 3), Vector2(X_E - 3, Z_S), inner, [0.85])
	sliver(behind, Vector2(X_W + 3 + (X_E - X_W - 6) * 0.85, Z_N + 3), true, SLIVER_MP_LEVEL)     # by the NE break corner
	sliver(behind, Vector2(X_E - 3, Z_N + 3 + (Z_S - Z_N - 3) * 0.85), false, SLIVER_MP_LEVEL)   # by the SE break corner
	wall(behind, Vector2(X_W, Z_N + 3), Vector2(X_W + 3, Z_N + 3), inner)      # seal the west end: only the Slivers lead in
	label(behind, "Behind the Walls", Vector3(0, 3.0, Z_N + 1.5), 0.0, 56)
	_behind_the_walls(behind)

	# Classrooms with round bays, laid out like the drawing
	room(f, "Classroom A", -26, -19, -11, -9, class_mat, {"s": [0.2], "e": [0.6]}, "s")
	room(f, "Classroom B", 2, -19, 20, -9, class_mat, {"w": [0.6], "s": [0.8]}, "s")
	room(f, "Classroom C", -8, -5, 10, 2, class_mat, {"w": [0.5], "e": [0.5]}, "n")
	room(f, "Classroom D", -14, 12, 4, 22, class_mat, {"w": [0.5], "e": [0.3]}, "n")

	# Sensory hallways: narrow corridors with rainbow walls and soft bubbles
	sensory_hall(f, Vector2(-7.5, -19), Vector2(-7.5, -8))
	sensory_hall(f, Vector2(8.5, 10), Vector2(8.5, 21))

	# Break corners with beanbags
	break_corner(f, Vector2(X_E - 4, Z_N + 4), -0.8)
	break_corner(f, Vector2(-27, 4), 0.6)
	break_corner(f, Vector2(-27, 21), 0.2)
	break_corner(f, Vector2(22, 21), -0.3)

	# The middle corridor with its two Exclusive doors
	var corridor := node("Exclusive Corridor", f)
	wall(corridor, Vector2(-22, 5), Vector2(25, 5), wall_mat, [0.05, 0.95])
	wall(corridor, Vector2(-22, 9), Vector2(25, 9), wall_mat, [0.05, 0.9])
	exclusive_door(corridor, Vector2(-14, 7))
	exclusive_door(corridor, Vector2(14, 7))

	restroom_pod(f, Vector3(-24, 0, -4), 1.6)
	restroom_pod(f, Vector3(22, 0, 0), 1.6)


func _behind_the_walls(behind: Node3D) -> void:
	# What lives up here: the centipede (scenes/creatures/centipede.tscn), plus its music and its lighting.
	var zone := Area3D.new()                  # Nina's inside its territory: eerie music, and it takes notice
	zone.name = "Territory"
	zone.set_script(load("res://scripts/music_zone.gd"))
	zone.set("track", "behind_walls")
	zone.monitorable = false
	behind.add_child(zone)
	var north := CollisionShape3D.new()
	north.shape = box_shape(Vector3(X_E - X_W, 5.0, 2.7))
	north.position = Vector3((X_W + X_E) / 2, 2.5, Z_N + 1.65)
	zone.add_child(north)
	var east := CollisionShape3D.new()
	east.shape = box_shape(Vector3(2.7, 5.0, Z_S - Z_N - 3.3))
	east.position = Vector3(X_E - 1.65, 2.5, (Z_N + 3 + Z_S) / 2)
	zone.add_child(east)

	# Its crawl route: a narrow loop along the ceiling of both arms of the passage
	var y := FLOOR_H - 0.15 - 0.05              # just under the slab above
	var a := Z_N + 1.15                         # two lanes along the north arm...
	var b := Z_N + 2.1
	var e1 := X_E - 1.15                        # ...and along the east arm
	var e2 := X_E - 2.1
	var c: Node3D = load("res://scenes/creatures/centipede.tscn").instantiate()
	c.name = "Centipede"
	c.set("route", PackedVector3Array([
		Vector3(X_W + 1.0, y, a), Vector3(e1, y, a), Vector3(e1, y, Z_S - 1.5), Vector3(e2, y, Z_S - 1.5),
		Vector3(e2, y, b), Vector3(X_W + 1.0, y, b)]))
	behind.add_child(c)
	c.set("territory", c.get_path_to(zone))

	# Dark, stained lining over the passage's floor, ceiling and walls (no collision; the walls behind are solid).
	# Gaps are left where the Slivers are.
	var grime := mat("Passage Grime", Color(0.14, 0.12, 0.16), 0.95)
	var floor_dark := mat("Passage Floor", Color(0.1, 0.09, 0.11), 0.9)
	var nw := X_E - X_W
	var lane := 2.55
	var ez0 := Z_N + 3.0
	var el := Z_S - ez0
	mesh_at(box(Vector3(nw, 0.02, lane)), floor_dark, Vector3((X_W + X_E) / 2, 0.012, Z_N + 0.3 + lane / 2), behind)
	mesh_at(box(Vector3(lane, 0.02, el)), floor_dark, Vector3(X_E - 0.3 - lane / 2, 0.012, ez0 + el / 2), behind)
	mesh_at(box(Vector3(nw, 0.02, lane)), grime, Vector3((X_W + X_E) / 2, FLOOR_H - 0.31, Z_N + 0.3 + lane / 2), behind)
	mesh_at(box(Vector3(lane, 0.02, el)), grime, Vector3(X_E - 0.3 - lane / 2, FLOOR_H - 0.31, ez0 + el / 2), behind)
	var h := WALL_H
	# outer walls (north and east), full length
	mesh_at(box(Vector3(nw, h, 0.02)), grime, Vector3((X_W + X_E) / 2, h / 2, Z_N + 0.31), behind)
	mesh_at(box(Vector3(0.02, h, Z_S - Z_N)), grime, Vector3(X_E - 0.31, h / 2, (Z_N + Z_S) / 2), behind)
	# inner walls, split around the Sliver openings
	var gap := DOOR_W / 2 + 0.1
	var sx := X_W + 3 + (X_E - X_W - 6) * 0.85
	var sz := Z_N + 3 + (Z_S - Z_N - 3) * 0.85
	for span in [Vector2(X_W, sx - gap), Vector2(sx + gap, X_E - 3)]:
		mesh_at(box(Vector3(span.y - span.x, h, 0.02)), grime, Vector3((span.x + span.y) / 2, h / 2, Z_N + 3 - 0.17), behind)
	for span in [Vector2(Z_N + 3, sz - gap), Vector2(sz + gap, Z_S)]:
		mesh_at(box(Vector3(0.02, h, span.y - span.x)), grime, Vector3(X_E - 3 + 0.17, h / 2, (span.x + span.y) / 2), behind)

	# Sickly green lights, low and far apart, that flicker
	var points := [Vector3(-22, 0, Z_N + 1.5), Vector3(-6, 0, Z_N + 1.5), Vector3(10, 0, Z_N + 1.5),
		Vector3(X_E - 1.5, 0, -8), Vector3(X_E - 1.5, 0, 10)]
	for p in points:
		var l := OmniLight3D.new()
		l.name = "Flicker Light"
		l.position = p + Vector3(0, 2.2, 0)
		l.light_color = Color(0.55, 1.0, 0.65)            # sickly green either way
		l.light_energy = 0.7
		l.omni_range = 7.0
		l.set_script(load("res://scripts/flicker_light.gd"))
		behind.add_child(l)
		mesh_at(sphere(0.08, 8), mat("Flicker Bulb", Color(0.6, 1.0, 0.7), 0.3, 0.0, 2.5), l.position, behind)


func secret_panel(parent: Node, at: Vector2, yaw: float) -> void:
	# Fills a doorway with something that looks like wall but has no collision.
	mesh_at(box(Vector3(0.32, DOOR_H, DOOR_W)), mat("Secret Door", Color(0.86, 0.9, 0.97)), Vector3(at.x, DOOR_H / 2, at.y),
		parent, yaw + PI / 2 if yaw == 0.0 else 0.0)
	label(parent, "?", Vector3(at.x, DOOR_H + 0.4, at.y), 0.0, 40)


func sliver(parent: Node, at: Vector2, along_x: bool, required: int) -> void:
	# Fills a doorway with wall, leaving a narrow shimmering slit that opens at the required MP level
	var s := node("Sliver", parent, Vector3(at.x, 0, at.y), 0.0 if along_x else PI / 2)
	s.set_script(load("res://scripts/sliver.gd"))
	s.set("required_mp_level", required)
	var slit := 0.9
	var side_w := (DOOR_W - slit) / 2
	for side in [-1.0, 1.0]:
		solid_box(Vector3(side_w, DOOR_H, 0.3), mat("Inner Wall", Color()), Vector3(side * (slit + side_w) / 2, DOOR_H / 2, 0), s)
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.position = Vector3(0, DOOR_H / 2, 0)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(Vector3(slit, DOOR_H, 0.3))
	blocker.add_child(cs)
	s.add_child(blocker)
	var glow := mesh_at(box(Vector3(slit, DOOR_H, 0.12)), mat("Sliver", Color(0.62, 0.76, 1.0), 0.1, 0.9, 1.0, 0.9),
		Vector3(0, DOOR_H / 2, 0), s)
	glow.name = "Glow"
	var sense := Area3D.new()
	sense.name = "Sense"
	sense.position = Vector3(0, DOOR_H / 2, 0)
	var ss := CollisionShape3D.new()
	ss.shape = box_shape(Vector3(DOOR_W, DOOR_H, 3.0))
	sense.add_child(ss)
	s.add_child(sense)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "Sliver"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Color(0.9, 0.93, 1.0)
	sign.position = Vector3(0, DOOR_H + 0.7, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.add_child(sign)


func sensory_hall(parent: Node, a: Vector2, b: Vector2) -> void:
	var h := node("Sensory Hallway", parent)
	var colors := [Color(0.95, 0.45, 0.45), Color(0.98, 0.7, 0.35), Color(0.98, 0.92, 0.4), Color(0.5, 0.85, 0.5),
		Color(0.45, 0.7, 0.98), Color(0.7, 0.5, 0.95)]
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var side := Vector2(dir.y, -dir.x) * 1.4
	var n := colors.size()
	for k in n:
		var p0 := a + dir * (length * k / n)
		var p1 := a + dir * (length * (k + 1) / n)
		var m := mat("Sensory %d" % k, colors[k], 0.6)
		wall(h, p0 + side, p1 + side, m, [], 3.2, 0.25)
		wall(h, p0 - side, p1 - side, m, [], 3.2, 0.25)
	for k in 5:
		var p := a + dir * (length * (k + 0.5) / 5)
		mesh_at(sphere(0.35), mat("Bubble", Color(0.8, 0.95, 1.0), 0.1, 0.0, 0.6, 0.7), Vector3(p.x, 2.6 + 0.3 * (k % 2), p.y), h)
	label(h, "Sensory Hallway", Vector3(a.x, 3.6, a.y), 0.0, 48)


func break_corner(parent: Node, at: Vector2, yaw: float) -> void:
	var c := node("Break Corner", parent, Vector3(at.x, 0, at.y), yaw)
	var colors := [Color(0.95, 0.5, 0.6), Color(0.5, 0.75, 0.95), Color(0.98, 0.85, 0.4)]
	for k in 3:
		var bb := mesh_at(sphere(0.7), mat("Beanbag %d" % k, colors[k], 0.9), Vector3(-1.5 + k * 1.5, 0.45, 0), c)
		bb.scale = Vector3(1, 0.65, 1)
	solid_box(Vector3(5, 0.05, 4), mat("Rug", Color(0.75, 0.6, 0.9)), Vector3(0, 0.02, 0), c)
	label(c, "Break Corner", Vector3(0, 2.4, 0), 0.0, 48)


func exclusive_door(parent: Node, at: Vector2) -> void:
	var gold := mat("Exclusive Door", Color(0.95, 0.75, 0.25), 0.3, 0.8)
	solid_box(Vector3(0.3, DOOR_H, 4.0), gold, Vector3(at.x, DOOR_H / 2, at.y), parent)
	label(parent, "Exclusive", Vector3(at.x, DOOR_H + 0.6, at.y), 0.0, 48)


# ----------------------------------------------------------------------------- Floor 3
func _floor_3() -> void:
	var f := node("Floor 3", school, Vector3(0, 2 * FLOOR_H, 0))
	var wall_mat := mat("Wall 3", Color(0.93, 0.9, 0.86))
	var office_mat := mat("Office Wall", Color(0.85, 0.88, 0.8))
	label(f, "3rd Floor - Offices", Vector3(-25, 4.8, 18), 0.0, 80)
	# Window wall along the north side: big clear panes looking out over the town to the mountains (_view)
	var glass := mat("Window Wall", Color(0.8, 0.92, 1.0), 0.02, 0.1, 0.0, 0.12)
	var frame := mat("Window Frame", Color(0.95, 0.93, 0.9), 0.5)
	var wy := (WINDOW_Y.x + WINDOW_Y.y) / 2
	var wh := WINDOW_Y.y - WINDOW_Y.x
	solid_box(Vector3(2 * WINDOW_X, wh, 0.08), glass, Vector3(0, wy, Z_N), f)
	solid_box(Vector3(2 * WINDOW_X + 0.4, 0.2, 0.9), frame, Vector3(0, WINDOW_Y.x - 0.1, Z_N + 0.15), f)   # the sill
	mesh_at(box(Vector3(2 * WINDOW_X + 0.4, 0.25, 0.7)), frame, Vector3(0, WINDOW_Y.y + 0.1, Z_N), f)
	mesh_at(box(Vector3(2 * WINDOW_X, 0.12, 0.25)), frame, Vector3(0, WINDOW_Y.x + wh * 0.72, Z_N), f)   # transom
	var panes := 12
	for k in panes + 1:
		mesh_at(box(Vector3(0.22, wh, 0.3)), frame, Vector3(-WINDOW_X + 2 * WINDOW_X * k / panes, wy, Z_N), f)
	label(f, "Window Wall", Vector3(0, 5.3, Z_N + 1.2), 0.0, 48)

	# Restrooms cut across the four corners
	for c in [[Vector2(X_W, Z_N + 6), Vector2(X_W + 6, Z_N)], [Vector2(X_E - 6, Z_N), Vector2(X_E, Z_N + 6)],
			[Vector2(X_W, Z_S - 6), Vector2(X_W + 6, Z_S)], [Vector2(X_E - 6, Z_S), Vector2(X_E, Z_S - 6)]]:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		wall(f, a, b, mat("Restroom", Color()), [0.5])
		var corner := (a + b) / 2 + ((a + b) / 2 - Vector2(0, 0)).normalized() * 1.2
		label(f, "RR", Vector3(corner.x, 3.5, corner.y), 0.0, 56)

	# Secret hallways along the east and south edges
	var sec := node("Secret Hallway", f)
	wall(sec, Vector2(X_E - 3.5, Z_N + 6), Vector2(X_E - 3.5, Z_S - 6), wall_mat, [0.5])
	wall(sec, Vector2(X_W + 6, Z_S - 3.5), Vector2(X_E - 6, Z_S - 3.5), wall_mat, [0.3])
	secret_panel(sec, Vector2(X_E - 3.5, 0), PI / 2)
	secret_panel(sec, Vector2(X_W + 6 + (X_E - X_W - 12) * 0.3, Z_S - 3.5), 0.0)
	label(sec, "Secret Hallway", Vector3(X_E - 1.7, 3.0, 8), 0.0, 48)

	# Three rows of offices with aisles between them
	var desk := mat("Desk", Color(0.6, 0.42, 0.25))
	office_row(f, "Office", -25, -16, -18, 18, 8, "e", office_mat, desk)
	office_row(f, "Office", -7, 3, -18, 18, 4, "w", office_mat, desk)
	office_row(f, "Office", 12, 20, -18, 18, 6, "w", office_mat, desk)


func office_row(parent: Node, name: String, x0: float, x1: float, z0: float, z1: float, count: int, door_side: String,
		material: Material, desk: Material) -> void:
	var depth := (z1 - z0) / count
	for k in count:
		var za := z0 + depth * k
		var zb := za + depth
		var doors := {door_side: [0.5]}
		room(parent, "%s %d" % [name, k + 1], x0, za, x1, zb, material, doors)
		solid_box(Vector3(2.2, 0.8, 1.0), desk, Vector3((x0 + x1) / 2, 0.4, (za + zb) / 2), parent)


# ----------------------------------------------------------------------------- Outside
func _entrance_garden() -> void:
	# The school's garden, between the front doors and the way back to town: a glass greenhouse to walk into, raised
	# vegetable beds, flower borders, benches, a rose arch over the path and watering cans left out by the beds.
	var g := node("Entrance Garden", school)
	var can := mat("Watering Can", Color(0.3, 0.6, 0.9), 0.4, 0.5)
	solid_box(Vector3(40, 0.3, 18), mat("Garden Grass", Color(0.38, 0.72, 0.3)), Vector3(0, -0.15, Z_S + 9), g)
	var path := mat("Garden Path", Color(0.88, 0.82, 0.68))
	solid_box(Vector3(4, 0.32, 18), path, Vector3(0, -0.13, Z_S + 9), g)
	solid_box(Vector3(4.2, 0.32, 2.4), path, Vector3(-4.1, -0.13, Z_S + 9), g)          # across to the greenhouse door
	var gravel := mat("Garden Gravel", Color(0.78, 0.74, 0.7))
	for z in [Z_S + 1.4, Z_S + 5.6, Z_S + 9.8, Z_S + 14.0]:                           # between the vegetable beds
		mesh_at(box(Vector3(14, 0.04, 1.4)), gravel, Vector3(12, 0.02, z), g)
	_greenhouse(g, Vector3(-12, 0, Z_S + 9))
	_vegetable_beds(g)
	_flower_borders(g)
	# Benches beside the path, facing it
	_bench(g, Vector3(3.6, 0, Z_S + 6), -PI / 2)
	_bench(g, Vector3(-3.6, 0, Z_S + 13), PI / 2)
	_rose_arch(g, Z_S + 15.5)
	_watering_can(g, Vector3(4.6, 0, Z_S + 3.2), 0.4, can)
	_watering_can(g, Vector3(19.0, 0, Z_S + 12.0), 2.2, mat("Watering Can Red", Color(0.9, 0.3, 0.3), 0.4, 0.5))
	# Low garden walls so she can't wander off
	var hedge := mat("Hedge", Color(0.25, 0.55, 0.25))
	solid_box(Vector3(0.8, 1.6, 18), hedge, Vector3(-20, 0.8, Z_S + 9), g)
	solid_box(Vector3(0.8, 1.6, 18), hedge, Vector3(20, 0.8, Z_S + 9), g)
	solid_box(Vector3(16, 1.6, 0.8), hedge, Vector3(-12, 0.8, Z_S + 18), g)
	solid_box(Vector3(16, 1.6, 0.8), hedge, Vector3(12, 0.8, Z_S + 18), g)
	label(g, "Entrance Garden", Vector3(0, 4.2, Z_S + 6), 0.0, 72)
	label(g, "To Town", Vector3(0, 2.6, Z_S + 17), 0.0, 56)
	door_trigger(g, "ExitToTown", Vector3(0, 1.5, Z_S + 18.5), Vector3(8, 3, 1.5), "res://scenes/town/town.tscn", "FromSchool")
	spawn_marker(g, "FromTown", Vector3(0, 1.0, Z_S + 13), 0.0)


func _greenhouse(parent: Node, at: Vector3) -> void:
	# A glass house 12 m square with a pitched glass roof and its door on the path side (east). Inside: potting
	# benches full of seedlings, tomato plants on canes, hanging baskets and a watering can.
	var gh := node("Greenhouse", parent, at)
	var half := 6.0
	var wall_h := 3.2
	var glass := mat("Greenhouse Glass", Color(0.82, 0.95, 0.9), 0.05, 0.0, 0.0, 0.22)
	var frame := mat("Greenhouse Frame", Color(0.96, 0.96, 0.94), 0.5)
	var brick := mat("Greenhouse Brick", Color(0.7, 0.42, 0.32))
	solid_box(Vector3(2 * half, 0.1, 2 * half), mat("Greenhouse Floor", Color(0.72, 0.6, 0.48)), Vector3(0, 0.03, 0), gh)
	# Glass walls (solid) on a low brick base, the east one with the doorway in the middle
	wall(gh, Vector2(-half, -half), Vector2(half, -half), glass, [], wall_h, 0.08)
	wall(gh, Vector2(-half, half), Vector2(half, half), glass, [], wall_h, 0.08)
	wall(gh, Vector2(-half, -half), Vector2(-half, half), glass, [], wall_h, 0.08)
	wall(gh, Vector2(half, -half), Vector2(half, half), glass, [0.5], wall_h, 0.08)
	for side in [[Vector3(0, 0.3, -half), Vector3(2 * half, 0.6, 0.3)], [Vector3(0, 0.3, half), Vector3(2 * half, 0.6, 0.3)],
			[Vector3(-half, 0.3, 0), Vector3(0.3, 0.6, 2 * half)]]:
		mesh_at(box(side[1]), brick, side[0], gh)
	for z in [-half / 2 - DOOR_W / 4, half / 2 + DOOR_W / 4]:                    # beside the doorway
		mesh_at(box(Vector3(0.3, 0.6, half - DOOR_W / 2)), brick, Vector3(half, 0.3, z), gh)
	# White frame: posts round the walls, a beam along the top, the doorway's frame
	for k in 7:
		var t := -half + k * 2.0
		for p in [Vector3(t, 0, -half), Vector3(t, 0, half), Vector3(-half, 0, t), Vector3(half, 0, t)]:
			if absf(p.x - half) < 0.01 and absf(p.z) < DOOR_W / 2:
				continue                                                            # not across the doorway
			mesh_at(box(Vector3(0.14, wall_h, 0.14)), frame, p + Vector3(0, wall_h / 2, 0), gh)
	for p in [[Vector3(0, wall_h, -half), Vector3(2 * half, 0.16, 0.16)], [Vector3(0, wall_h, half), Vector3(2 * half, 0.16, 0.16)],
			[Vector3(-half, wall_h, 0), Vector3(0.16, 0.16, 2 * half)], [Vector3(half, wall_h, 0), Vector3(0.16, 0.16, 2 * half)]]:
		mesh_at(box(p[1]), frame, p[0], gh)
	for z in [-DOOR_W / 2, DOOR_W / 2]:
		mesh_at(box(Vector3(0.2, DOOR_H, 0.2)), frame, Vector3(half, DOOR_H / 2, z), gh)
	# Pitched glass roof, ridge running north-south, with glass gables at the ends
	var rise := 1.6
	var slope := atan2(rise, half)
	var run := sqrt(half * half + rise * rise)
	for s in [-1.0, 1.0]:
		mesh_at(box(Vector3(run + 0.2, 0.06, 2 * half + 0.3)), glass, Vector3(s * half / 2, wall_h + rise / 2, 0), gh, 0.0,
			Vector3(0, 0, -s * slope))
		for k in 7:                                                                  # rafters
			mesh_at(box(Vector3(run, 0.1, 0.1)), frame, Vector3(s * half / 2, wall_h + rise / 2 + 0.05, -half + k * 2.0), gh,
				0.0, Vector3(0, 0, -s * slope))
	mesh_at(box(Vector3(0.2, 0.2, 2 * half + 0.4)), frame, Vector3(0, wall_h + rise, 0), gh)        # ridge
	var gable := PrismMesh.new()
	gable.size = Vector3(2 * half, rise, 0.06)
	for z in [-half, half]:
		mesh_at(gable, glass, Vector3(0, wall_h + rise / 2, z), gh)
	label(gh, "Greenhouse", Vector3(half + 0.3, wall_h + 0.9, 0), 0.0, 56)
	# Potting benches: one along the back (west) wall, one along the north wall, an island in the middle
	var wood := mat("Potting Bench", Color(0.6, 0.42, 0.26))
	var pot := mat("Flower Pot", Color(0.78, 0.42, 0.28))
	var soil := mat("Garden Soil", Color(0.36, 0.24, 0.15))
	var leaf := mat("Garden Leaf", Color(0.3, 0.68, 0.25))
	var blooms := [mat("Bloom Pink", Color(0.98, 0.5, 0.7)), mat("Bloom Yellow", Color(0.98, 0.86, 0.3)),
		mat("Bloom Violet", Color(0.68, 0.48, 0.95)), mat("Bloom White", Color(0.97, 0.96, 0.92))]
	var benches := [[Vector3(-half + 0.9, 0, 0), Vector3(1.2, 0.9, 2 * half - 1.0)],
		[Vector3(-0.8, 0, -half + 0.9), Vector3(6.6, 0.9, 1.2)],
		[Vector3(-0.6, 0, 0.6), Vector3(1.3, 0.9, 5.0)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for b in benches:
		var c: Vector3 = b[0]
		var size: Vector3 = b[1]
		solid_box(Vector3(size.x, 0.12, size.z), wood, c + Vector3(0, size.y - 0.06, 0), gh)
		solid_box(Vector3(size.x * 0.9, 0.08, size.z * 0.9), wood, c + Vector3(0, 0.25, 0), gh, 0.0, Vector3.ZERO, false)
		for lx in [-0.5, 0.5]:
			for lz in [-0.5, 0.5]:
				mesh_at(box(Vector3(0.1, size.y, 0.1)), wood, c + Vector3(lx * (size.x - 0.2), size.y / 2, lz * (size.z - 0.2)), gh)
		# A row of pots along the bench, each with a seedling or a flower
		var long := size.z > size.x
		var n := int((size.z if long else size.x) / 0.7)
		for k in n:
			var t := -0.5 + (k + 0.5) / n
			var p := c + (Vector3(0, 0, t * size.z) if long else Vector3(t * size.x, 0, 0)) + Vector3(0, size.y, 0)
			var r := rng.randf_range(0.16, 0.24)
			mesh_at(cylinder(r, r * 0.75, r * 1.4, 10), pot, p + Vector3(0, r * 0.7, 0), gh)
			mesh_at(cylinder(r * 0.92, r * 0.92, 0.04, 10), soil, p + Vector3(0, r * 1.38, 0), gh)
			if k % 3 == 1:
				mesh_at(sphere(r * 0.9, 8), blooms[rng.randi() % blooms.size()], p + Vector3(0, r * 1.4 + r * 0.6, 0), gh)
			else:
				for q in 3:
					var a := TAU * q / 3 + rng.randf()
					mesh_at(sphere(r * 0.45, 6), leaf, p + Vector3(cos(a) * r * 0.4, r * 1.6 + rng.randf() * 0.15, sin(a) * r * 0.4), gh)
	# Tomato plants on canes in the southeast corner, by the door
	var cane := mat("Garden Cane", Color(0.75, 0.62, 0.4))
	var tomato := mat("Tomato", Color(0.9, 0.2, 0.15), 0.4)
	for k in 4:
		var p := Vector3(3.2 + (k % 2) * 1.4, 0, 3.6 + floorf(k / 2.0) * 1.4)
		mesh_at(cylinder(0.3, 0.24, 0.4, 10), pot, p + Vector3(0, 0.2, 0), gh)
		mesh_at(cylinder(0.025, 0.025, 2.0, 6), cane, p + Vector3(0, 1.1, 0), gh)
		for q in 5:
			var a := rng.randf() * TAU
			mesh_at(sphere(0.28, 8), leaf, p + Vector3(cos(a) * 0.18, 0.6 + q * 0.3, sin(a) * 0.18), gh)
			if q % 2 == 1:
				mesh_at(sphere(0.09, 8), tomato, p + Vector3(cos(a + 1.5) * 0.28, 0.55 + q * 0.3, sin(a + 1.5) * 0.28), gh)
	# Hanging baskets of flowers from the roof beam
	var chain := mat("Basket Chain", Color(0.35, 0.35, 0.38), 0.4, 0.6)
	for k in 3:
		var p := Vector3(1.6, 0, -3.5 + k * 3.5)
		mesh_at(cylinder(0.02, 0.02, 1.0, 4), chain, p + Vector3(0, wall_h + 0.5, 0), gh)
		mesh_at(sphere(0.32, 10), mat("Basket", Color(0.55, 0.38, 0.22)), p + Vector3(0, wall_h - 0.1, 0), gh)
		mesh_at(sphere(0.3, 8), leaf, p + Vector3(0, wall_h + 0.1, 0), gh)
		for q in 5:
			var a := TAU * q / 5
			mesh_at(sphere(0.12, 6), blooms[(k + q) % blooms.size()], p + Vector3(cos(a) * 0.3, wall_h + 0.05, sin(a) * 0.3), gh)
	_watering_can(gh, Vector3(4.6, 0, -2.2), -0.6, mat("Watering Can", Color()))
	# Soft green light in the glass house
	var l := OmniLight3D.new()
	l.position = Vector3(0, wall_h, 0)
	l.omni_range = 9.0
	l.light_energy = 0.5
	l.light_color = WT.light(Color(0.9, 1.0, 0.85))
	gh.add_child(l)


func _vegetable_beds(parent: Node) -> void:
	# Three raised wooden beds east of the path, low enough to hop onto: cabbages, carrots, and pumpkins with
	# sunflowers along the back.
	var g := node("Vegetable Beds", parent)
	var plank := mat("Bed Plank", Color(0.58, 0.4, 0.24))
	var soil := mat("Garden Soil", Color())
	var leaf := mat("Garden Leaf", Color())
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var beds := [Z_S + 3.5, Z_S + 7.7, Z_S + 11.9]
	for i in beds.size():
		var c := Vector3(12, 0, beds[i])
		solid_box(Vector3(11, 0.55, 2.6), plank, c + Vector3(0, 0.275, 0), g)
		mesh_at(box(Vector3(10.6, 0.04, 2.2)), soil, c + Vector3(0, 0.56, 0), g)
		for k in 9:
			var x := -4.6 + k * 1.15
			for row in [-0.55, 0.55]:
				var p := c + Vector3(x + rng.randf_range(-0.1, 0.1), 0.58, row)
				match i:
					0:                                                               # cabbages
						mesh_at(sphere(0.32, 10), mat("Cabbage", Color(0.55, 0.82, 0.4)), p + Vector3(0, 0.22, 0), g)
						mesh_at(sphere(0.2, 8), mat("Cabbage Heart", Color(0.75, 0.92, 0.55)), p + Vector3(0, 0.4, 0), g)
					1:                                                               # carrots: orange tops and feathery leaves
						mesh_at(cylinder(0.07, 0.05, 0.08, 8), mat("Carrot", Color(0.98, 0.55, 0.15)), p + Vector3(0, 0.04, 0), g)
						for q in 3:
							mesh_at(cylinder(0.0, 0.05, 0.45, 5), leaf, p + Vector3(0, 0.28, 0), g, q * 1.0,
								Vector3(0.3, 0, 0))
					2:                                                               # pumpkins in front, sunflowers behind
						if row < 0 and k % 2 == 0:
							var pm := mesh_at(sphere(0.3, 12), mat("Pumpkin", Color(0.95, 0.5, 0.1)), p + Vector3(0, 0.22, 0), g)
							pm.scale = Vector3(1.2, 0.8, 1.2)
							mesh_at(cylinder(0.03, 0.04, 0.12, 6), leaf, p + Vector3(0, 0.5, 0), g)
						elif row > 0 and k % 2 == 1:
							var h := rng.randf_range(1.7, 2.3)
							mesh_at(cylinder(0.04, 0.05, h, 6), leaf, p + Vector3(0, h / 2, 0), g)
							mesh_at(cylinder(0.32, 0.32, 0.06, 14), mat("Sunflower", Color(0.98, 0.82, 0.15)), p + Vector3(0, h, 0.05),
								g, 0.0, Vector3(PI / 2 - 0.3, 0, 0))
							mesh_at(cylinder(0.15, 0.15, 0.08, 12), mat("Sunflower Middle", Color(0.4, 0.25, 0.12)), p + Vector3(0, h, 0.07),
								g, 0.0, Vector3(PI / 2 - 0.3, 0, 0))
							mesh_at(sphere(0.2, 6), leaf, p + Vector3(0.15, h * 0.5, 0), g)
	label(g, "Vegetable Beds", Vector3(12, 2.8, Z_S + 1.4), 0.0, 56)


func _flower_borders(parent: Node) -> void:
	# Flowers on stems along the front of the school and the hedges
	var g := node("Flower Borders", parent)
	var stem := mat("Flower Stem", Color(0.3, 0.6, 0.25))
	var colors := [Color(0.95, 0.4, 0.6), Color(0.98, 0.85, 0.3), Color(0.7, 0.45, 0.95), Color(0.98, 0.55, 0.3),
		Color(0.97, 0.96, 0.92)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var spots := []
	for k in 13:                                   # along the school's front wall, both sides of the doors
		spots.append(Vector3(-3.2 - k * 0.65, 0, Z_S + 0.6))
		spots.append(Vector3(3.2 + k * 0.65, 0, Z_S + 0.6))
	for k in 20:                                   # along the back hedges by the way out
		spots.append(Vector3(-4.4 - k * 0.75, 0, Z_S + 17.1))
		spots.append(Vector3(4.4 + k * 0.75, 0, Z_S + 17.1))
	for k in 9:                                    # along the east hedge
		spots.append(Vector3(19.0, 0, Z_S + 15.6 - k * 0.6))
	for p: Vector3 in spots:
		p += Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.2, 0.2))
		var h := rng.randf_range(0.45, 0.85)
		var c: int = rng.randi() % colors.size()
		mesh_at(cylinder(0.025, 0.03, h, 5), stem, p + Vector3(0, h / 2, 0), g)
		mesh_at(sphere(0.13, 8), mat("Flower %d" % c, colors[c], 0.9), p + Vector3(0, h, 0), g)
		mesh_at(sphere(0.05, 6), mat("Flower Middle", Color(0.98, 0.9, 0.4)), p + Vector3(0, h + 0.1, 0), g)
		if rng.randf() < 0.5:
			mesh_at(sphere(0.1, 6), mat("Garden Leaf", Color()), p + Vector3(0.08, h * 0.4, 0), g)


func _bench(parent: Node, at: Vector3, yaw: float) -> void:
	# A garden bench, seat to the front (local +z), so yaw turns it to face the path
	var b := node("Bench", parent, at, yaw)
	var wood := mat("Bench Wood", Color(0.62, 0.44, 0.28))
	var iron := mat("Bench Iron", Color(0.2, 0.22, 0.24), 0.5, 0.6)
	solid_box(Vector3(2.0, 0.08, 0.6), wood, Vector3(0, 0.48, 0), b)
	mesh_at(box(Vector3(2.0, 0.5, 0.06)), wood, Vector3(0, 0.85, -0.3), b, 0.0, Vector3(-0.15, 0, 0))
	for x in [-0.85, 0.85]:
		mesh_at(box(Vector3(0.08, 0.46, 0.55)), iron, Vector3(x, 0.23, 0), b)
		mesh_at(box(Vector3(0.08, 0.6, 0.08)), iron, Vector3(x, 0.8, -0.3), b)


func _rose_arch(parent: Node, z: float) -> void:
	# An arch over the path near the way out, covered in climbing roses
	var a := node("Rose Arch", parent, Vector3(0, 0, z))
	var frame := mat("Arch Frame", Color(0.96, 0.96, 0.94), 0.5)
	var leaf := mat("Garden Leaf", Color())
	var rose := mat("Rose", Color(0.95, 0.35, 0.5))
	for x in [-2.4, 2.4]:
		solid_box(Vector3(0.16, 3.0, 0.16), frame, Vector3(x, 1.5, 0), a)
	for k in 12:                                    # the curve over the top, in short pieces
		var a0 := PI * k / 12.0
		var a1 := PI * (k + 1) / 12.0
		var p0 := Vector2(-cos(a0) * 2.4, sin(a0) * 1.44)
		var p1 := Vector2(-cos(a1) * 2.4, sin(a1) * 1.44)
		var mid := (p0 + p1) / 2
		mesh_at(box(Vector3(p0.distance_to(p1) + 0.05, 0.16, 0.16)), frame, Vector3(mid.x, 3.0 + mid.y, 0), a, 0.0,
			Vector3(0, 0, atan2(p1.y - p0.y, p1.x - p0.x)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for k in 22:
		var t := k / 21.0
		var p: Vector3
		if t < 0.3:
			p = Vector3(-2.4, t / 0.3 * 3.0, 0)
		elif t > 0.7:
			p = Vector3(2.4, (1.0 - t) / 0.3 * 3.0, 0)
		else:
			var ang := PI * (t - 0.3) / 0.4
			p = Vector3(-cos(ang) * 2.4, 3.0 + sin(ang) * 1.44, 0)
		p += Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		mesh_at(sphere(0.26, 8), leaf, p, a)
		if k % 2 == 0:
			mesh_at(sphere(0.11, 6), rose, p + Vector3(0, 0.12, 0.2), a)


func _watering_can(parent: Node, at: Vector3, yaw: float, m: Material) -> void:
	var w := node("Watering Can", parent, at, yaw)
	mesh_at(cylinder(0.18, 0.2, 0.36, 14), m, Vector3(0, 0.18, 0), w)
	mesh_at(cylinder(0.025, 0.035, 0.5, 8), m, Vector3(0.3, 0.3, 0), w, 0.0, Vector3(0, 0, -0.9))      # spout
	mesh_at(cylinder(0.06, 0.03, 0.06, 8), m, Vector3(0.5, 0.46, 0), w, 0.0, Vector3(0, 0, -0.9))       # its rose
	var handle := TorusMesh.new()
	handle.inner_radius = 0.12
	handle.outer_radius = 0.15
	mesh_at(handle, m, Vector3(-0.02, 0.38, 0), w, 0.0, Vector3(PI / 2, 0, 0))


func _view() -> void:
	# What's outside the school, for its windows and the garden: the castle hill's top it stands on, the cliff down
	# to the town, the town's land, and the town's own mountains and cloud streaks (tools/build_town.gd), all where
	# they are in the town. Nothing here is solid; she can't get out to it.
	var v := node("View", school)
	var t: Dictionary = BT.THEMES[WT.THEME]
	var alien := WT.alien()
	var hill_top := -0.06
	var town_y := -IN_TOWN.y
	mesh_at(cylinder(BT.CASTLE_HILL_TOP, BT.CASTLE_HILL_TOP, 0.1, 64), view_mat("View Hill Top", t.hill_grass),
		Vector3(0, hill_top - 0.05, 0), v)
	mesh_at(cylinder(BT.CASTLE_HILL_TOP, BT.CASTLE_HILL_TOP + 8.0, IN_TOWN.y, 64), view_mat("View Cliff", t.rock),
		Vector3(0, hill_top - 0.1 - IN_TOWN.y / 2, 0), v)
	mesh_at(cylinder(700, 700, 0.2, 64), view_mat("View Land", t.far_grass), Vector3(0, town_y - 0.1, 0), v)
	var far := view_mat("Mountain", t.mountain_far, 0.35 if alien else 1.0, 0.3 if alien else 0.0)
	var near := view_mat("Mountain Near", t.mountain_near, 0.35 if alien else 1.0, 0.3 if alien else 0.0)
	var peaks := BT.mountain_peaks()
	var mg := node("Mountains", v)
	for k in peaks.size():
		var peak: Array = peaks[k]
		var h: float = peak[1]
		var p: Vector3 = peak[0] - IN_TOWN
		var mi := mesh_at(cylinder(0.0, h * 0.75, h, t.mountain_sides), far if k % 2 == 0 else near, p + Vector3(0, h / 2, 0), mg,
			peak[2])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cream cloud streaks; they fade at night with the town's (scripts/day_night.gd looks for "Sky Cloud")
	var cloud := StandardMaterial3D.new()
	cloud.resource_name = "Sky Cloud"
	cloud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.albedo_color = Color(0.99, 0.93, 0.72, 0.85) if alien else Color(1, 1, 1, 0.85)
	cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.disable_fog = true
	var cg := node("Clouds", v)
	for s: Array in BT.cloud_streaks():
		var mi := mesh_at(sphere(1.0, 24), cloud, s[0] - IN_TOWN, cg, s[1], Vector3(0, 0, s[2]))
		mi.scale = s[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func view_mat(name: String, color: Color, rough := 1.0, metal := 0.0) -> StandardMaterial3D:
	# Colours straight from the town's theme (already in its palette, so not tinted again)
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _player() -> void:
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 1.0, Z_S + 13)
	school.add_child(player)
	player.owner = school
