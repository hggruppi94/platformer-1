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
	_library_atrium()
	_music_pods()
	_skybridge()
	_floor_2_extras()
	_floor_3_extras()
	_hidden_stair()
	_roof()
	_foyer_dressing()
	_palace()
	_grounds()
	_entrance_garden()
	_courtyard()
	_palm_grove()
	_hedge_maze()
	_quad()
	_festival()
	_pool()
	_view()
	_player()
	own(school)


func _environment() -> void:
	# The town's own sky, seen through the windows and over the Entrance Garden. Rooms keep their own even light.
	var t: Dictionary = BT.THEMES[WT.THEME]
	# The school's own sky is the picture's soft purple (Hayden, 14 Nov 2026), not the town's green; it still darkens
	# with the clock (scripts/day_night.gd starts from these colours)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.26, 0.78)
	sky_mat.sky_horizon_color = Color(0.80, 0.62, 0.96)
	sky_mat.ground_horizon_color = Color(0.80, 0.62, 0.96)
	sky_mat.ground_bottom_color = t.sky_bottom
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.72, 1.0)              # soft cozy purple everywhere
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true                                         # windows, lamps, the fountains and pods glow softly
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
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
	sun.light_color = Color(1.0, 0.88, 0.96)
	school.add_child(sun)
	# Ceiling lights on each floor
	for f in 3:
		for x in [-15.0, 0.0, 15.0]:
			for z in [-12.0, 0.0, 12.0]:
				var l := OmniLight3D.new()
				l.position = Vector3(x, f * FLOOR_H + 5.0, z)
				l.omni_range = 14.0
				l.light_energy = 0.9
				l.light_color = Color(1.0, 0.86, 0.9)                 # warm pink-gold lamps
				school.add_child(l)


func _shell() -> void:
	# Floor slabs, roof and outer walls for the whole building.
	var shell := node("Shell", school)
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var floors := [pal("Floor 1", Color(0.88, 0.84, 0.96), 0.55), pal("Floor 2", Color(0.82, 0.86, 0.98), 0.6),
		pal("Floor 3", Color(0.86, 0.82, 0.94), 0.6)]
	for f in 3:
		var y := f * FLOOR_H
		var slab := node("Slab %d" % (f + 1), shell)
		if f == 1:
			# Floor 2 is open over the library: an oval hole the library rises through (_library_atrium)
			holed_slab(slab, "Gallery Floor", Rect2(X_W, Z_N, X_E - X_W, Z_S - Z_N), LIBRARY_AT, LIBRARY_HOLE, y, 0.3, floors[f],
				pal("Palace Trim", P_TRIM, 0.6))
			continue
		if f == 2:
			# Floor 3 has a round hole in its secret hallway for the hidden stair down (_hidden_stair)
			holed_slab(slab, "Office Floor", Rect2(X_W, Z_N, X_E - X_W, Z_S - Z_N), HIDDEN_STAIR,
				Vector2(STAIR_R + 0.1, STAIR_R + 0.1), y, 0.3, floors[f], pal("Palace Trim", P_TRIM, 0.6), -1.0, 40)
			continue
		solid_box(Vector3(X_E - X_W, 0.3, Z_S - Z_N), floors[f], Vector3((X_W + X_E) / 2, y - 0.15, (Z_N + Z_S) / 2), slab)
	# The roof, with an opening over the atrium for the escalators up to it (ROOF_HOLE, _atrium)
	var rh := ROOF_HOLE
	for piece: Rect2 in [Rect2(X_W, Z_N, X_E - X_W, Z_S - Z_N), Rect2(ATRIUM_W, Z_N, X_W - ATRIUM_W, rh.position.y - Z_N),
			Rect2(ATRIUM_W, rh.end.y, X_W - ATRIUM_W, Z_S - rh.end.y), Rect2(ATRIUM_W, rh.position.y, rh.position.x - ATRIUM_W, rh.size.y),
			Rect2(rh.end.x, rh.position.y, X_W - rh.end.x, rh.size.y)]:
		solid_box(Vector3(piece.size.x, 0.3, piece.size.y), stone,
			Vector3(piece.get_center().x, 3 * FLOOR_H - 0.15, piece.get_center().y), shell)
	solid_box(Vector3(X_W - ATRIUM_W, 0.3, Z_S - Z_N), pal("Floor 1", Color()),
		Vector3((ATRIUM_W + X_W) / 2, -0.15, 0), shell)
	var h := 3 * FLOOR_H
	var outer := node("Outer Walls", shell)
	# North wall: open along the 3rd floor's window wall (glass and frames in _floor_3)
	var sill := 2 * FLOOR_H + WINDOW_Y.x
	var top := 2 * FLOOR_H + WINDOW_Y.y
	# Doors out on three sides as well as the front: north to the overlook walk, east to the quad, west (through the
	# atrium) to the courtyard garden. Only floor 1 has them; the lintel over each runs up to the floor above.
	wall(outer, Vector2(ATRIUM_W, Z_N), Vector2(X_E, Z_N), stone, [(0.0 - ATRIUM_W) / (X_E - ATRIUM_W)], sill, 0.6)
	var above := node("Above Window", outer, Vector3(0, top, 0))
	wall(above, Vector2(ATRIUM_W, Z_N), Vector2(X_E, Z_N), stone, [], h - top, 0.6)
	var beside := node("Beside Window", outer, Vector3(0, sill, 0))
	wall(beside, Vector2(ATRIUM_W, Z_N), Vector2(-WINDOW_X, Z_N), stone, [], top - sill, 0.6)
	wall(beside, Vector2(WINDOW_X, Z_N), Vector2(X_E, Z_N), stone, [], top - sill, 0.6)
	wall(outer, Vector2(ATRIUM_W, Z_S), Vector2(X_E, Z_S), stone, [(0.0 - ATRIUM_W) / (X_E - ATRIUM_W)], h, 0.6)   # front door
	wall(outer, Vector2(ATRIUM_W, Z_N), Vector2(ATRIUM_W, Z_S), stone, [0.5], h, 0.6)
	wall(outer, Vector2(X_E, Z_N), Vector2(X_E, Z_S), stone, [(-8.0 - Z_N) / (Z_S - Z_N)], h, 0.6)


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
	# Floor 3 -> the roof (the sky stair): up through the opening in the roof, from a landing off floor 3's balcony
	escalator(a, "Escalator 3 Up", -37.5, 6, 18, 2 * FLOOR_H, true)
	escalator(a, "Escalator 3 Down", -35.0, 6, 18, 2 * FLOOR_H, false)
	solid_box(Vector3(8, 0.3, 4), deck, Vector3(-36, 2 * FLOOR_H - 0.15, 4), a)
	label(a, "To the Roof", Vector3(-36, 2 * FLOOR_H + 3.6, 3), 0.0, 64)
	# Stairs from floor 1 to floor 2 at the north end, landing on their own platform
	stairs(a, -36, -8, -20, 0)
	solid_box(Vector3(8, 0.3, 4), deck, Vector3(-36, FLOOR_H - 0.15, -22), a)
	# Balconies along the floors' west edge on floors 2 and 3, with glass railings
	var railings := {1: [[-20.0, 0.0], [6.0, 24.0]], 2: [[-24.0, -18.0], [-12.0, 2.0], [6.0, 24.0]]}   # gaps where platforms join
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
	var wall_mat := pal("Wall 1", Color(0.86, 0.79, 0.96), 0.8)
	label(f, "1st Floor", Vector3(0, 4.8, 21), 0.0, 96)
	# Front wall with the main doors into the foyer (replaces the plain outer wall's lower part)
	var foyer := node("Foyer", f)
	solid_box(Vector3(7, 1.1, 1.4), pal("Front Desk", P_NAVY, 0.5, 0.2), Vector3(0, 0.55, 15), foyer)
	mesh_at(box(Vector3(7.2, 0.08, 1.6)), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(0, 1.12, 15), foyer)
	label(foyer, "Foyer", Vector3(0, 3.2, 15), 0.0, 72)
	wall(foyer, Vector2(-14, 10), Vector2(-14, 24), wall_mat, [0.35])
	wall(foyer, Vector2(14, 10), Vector2(14, 24), wall_mat, [0.35])
	wall(foyer, Vector2(-14, 10), Vector2(14, 10), wall_mat, [0.2, 0.5, 0.8])

	# Library: an oval of tall navy bookshelves striped with colour, four openings, reading tables, and the restroom
	# in the middle. It's open up through floor 2 (_library_atrium), so the shelves go up two tiers.
	var lib := node("Library", f, Vector3(LIBRARY_AT.x, 0, LIBRARY_AT.y))
	var shelf := pal("Bookshelf Navy", P_NAVY, 0.8)
	var books := [pal("Book 0", P_PINK, 0.7), pal("Book 1", Color(0.45, 0.82, 1.0), 0.7),
		pal("Book 2", Color(1.0, 0.85, 0.4), 0.7), pal("Book 3", Color(0.7, 0.55, 1.0), 0.7)]
	var book_parts := [[], [], [], []]
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
		solid_box(Vector3(0.8, 5.4, p0.distance_to(p1)), shelf, Vector3(mid.x, 2.7, mid.y), lib, yaw)
		for row in 6:                                   # a band of books on every shelf, both faces
			book_parts[(k + row) % 4].append([box(Vector3(0.9, 0.5, p0.distance_to(p1) * 0.9)),
				xf(Vector3(mid.x, 0.55 + row * 0.82, mid.y), Vector3(0, yaw, 0))])
		mesh_at(box(Vector3(0.9, 0.1, p0.distance_to(p1) + 0.02)), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35),
			Vector3(mid.x, 5.42, mid.y), lib, yaw)
	for k in 4:
		merged_at(book_parts[k], books[k], lib, "Books %d" % k)
	for tx in [-8.0, 8.0]:
		for tz in [-3.0, 3.0]:
			solid_box(Vector3(3, 0.8, 1.6), pal("Table", Color(0.93, 0.9, 1.0), 0.5), Vector3(tx, 0.4, tz), lib)
			mesh_at(cylinder(0.12, 0.18, 0.4, 10), pal("Lamp Glow", P_GLOW, 0.3, 0.0, 2.2), Vector3(tx, 1.0, tz), lib)
	restroom_pod(lib, Vector3(0, 0, 0), 2.4)
	label(lib, "Library", Vector3(0, 4.2, -5), 0.0, 96)

	# Four locker wings, each ringed by restroom pods
	locker_wing(f, "Upper Grade Lockers", Vector3(-19, 0, -16), 0.5, pal("Lockers Upper", Color(0.66, 0.3, 0.78), 0.5, 0.3))
	locker_wing(f, "Upper Grade Lockers ", Vector3(19, 0, -16), -0.5, pal("Lockers Upper", Color()))
	locker_wing(f, "Lower Grade Lockers", Vector3(20, 0, 4), -1.4, pal("Lockers Lower", P_MAGENTA, 0.5, 0.3))
	locker_wing(f, "Lower Grade Lockers ", Vector3(-21, 0, 12), 0.7, pal("Lockers Lower", Color()))

	# Low partitions fanning out from the foyer toward the corners, like the drawing's diagonal walls
	var part := pal("Partition", Color(0.93, 0.89, 0.99), 0.6)
	wall(f, Vector2(-14, 10), Vector2(-26, 2), part, [], 2.4, 0.25)
	wall(f, Vector2(14, 10), Vector2(26, -6), part, [], 2.4, 0.25)
	wall(f, Vector2(-8, -15), Vector2(-14, -22), part, [], 2.4, 0.25)
	wall(f, Vector2(8, -15), Vector2(14, -22), part, [], 2.4, 0.25)


func restroom_pod(parent: Node, pos: Vector3, r := 1.5) -> void:
	var pod := node("Restroom", parent, pos)
	solid_cylinder(r, 3.0, pal("Restroom", Color(0.62, 0.78, 0.96), 0.5), Vector3(0, 1.5, 0), pod)
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
	var wall_mat := pal("Wall 2", Color(0.86, 0.80, 0.97), 0.8)
	var class_mat := pal("Classroom Wall", Color(0.93, 0.86, 0.99), 0.8)
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
	# (Classroom A is the Nova Lab since slice 2 of the palace: _floor_2_extras() fits it out)
	room(f, "Nova Lab", -26, -19, -11, -9, class_mat, {"s": [0.2], "e": [0.6]}, "s")
	# (B is shallower and C moved east since the library opened up through this floor: they stood over its hole)
	room(f, "Classroom B", 2, -19, 20, -13, class_mat, {"w": [0.5], "s": [0.8]})
	room(f, "Classroom C", 12, -10, 25, 3, class_mat, {"w": [0.5], "s": [0.5]})
	room(f, "Classroom D", -14, 12, 4, 22, class_mat, {"w": [0.5], "e": [0.3]}, "n")

	# Sensory hallways: narrow corridors with rainbow walls and soft bubbles
	sensory_hall(f, Vector2(-7.5, -19), Vector2(-7.5, -12.6))
	sensory_hall(f, Vector2(8.5, 10), Vector2(8.5, 21))

	# Break corners with beanbags
	# (The north-east one sits clear of the Behind the Walls passage: at (X_E - 4, Z_N + 4) its rug and a beanbag stuck
	# through the passage's wall. Hayden, 14 Nov 2026: "Behind the school wall, carpet and bean bags are clipping
	# through". school.tscn had just this node's spot changed, rather than a rebuild's ID shuffle.)
	break_corner(f, Vector2(X_E - 6.7, Z_N + 6.7), -0.8)
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
	restroom_pod(f, Vector3(7, 0, 2.8), 1.3)


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
func _invisible_wall(parent: Node, name: String, size: Vector3, pos: Vector3) -> void:
	# Solid but not drawn: keeps her in without spoiling the view
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(size)
	body.add_child(cs)
	parent.add_child(body)


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
	var hill_top := -2.35
	var town_y := -IN_TOWN.y
	# (wider than the town's hill top, so the whole campus stands on it)
	var top_r := 112.0
	mesh_at(cylinder(top_r, top_r, 0.1, 64), view_mat("View Hill Top", t.hill_grass),
		Vector3(0, hill_top - 0.25, 0), v)
	mesh_at(cylinder(top_r, top_r + 8.0, IN_TOWN.y, 64), view_mat("View Cliff", t.rock),
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


# -----------------------------------------------------------------------------
# The palace look and the campus (Hayden, 14 Nov 2026: "I want the school to look like this now", with a picture of a
# lilac palace school: a courtyard with a tiered glowing fountain and flower planters, crescent-moon banners, glass
# music pods, a hedge maze with a greenhouse, palms and hammocks, a library open over several floors with glass
# balconies, soft cozy purple light. Then: "the sensory school is going to replace the old school", so the grounds
# follow the Void School Sensory Plan: the Entrance Garden and its fountain in front, the walled courtyard garden,
# the palm grove and the hedge maze to the west, the quad, its fountains, the smoothie cart, the mural studio, the
# stair amphitheater and the festival stage to the east, the pool on the east lawn, the overlook walk along the
# Void's edge, and the golf-cart loop round it all, through the "To Town" arch.)
# -----------------------------------------------------------------------------
const CAMPUS := Rect2(-72, -40, 150, 103)       # x -72..78, z -40..63: everything outside you can walk on
const EXIT_Z := 65.0                            # the "To Town" doorway, past the arch at the campus's south edge
const FOUNTAIN := Vector3(0, 0, 32)             # the tiered fountain in front of the palace
const GREENHOUSE := Vector3(-14, 0, 48)
const COURTYARD := Rect2(-66, -26, 20, 36)      # the walled courtyard garden: x -66..-46, z -26..10
const GROVE := Rect2(-66, 11, 20, 12)           # the palm grove's hammocks
const MAZE_AT := Vector2(-64.4, 30.5)           # the hedge maze's north-west corner...
const MAZE_N := Vector2i(12, 8)                 # ...its cells across and down...
const MAZE_CELL := 3.2                          # ...and their size
const QUAD := Rect2(34, -10, 44, 36)            # the east quad: x 34..78, z -10..26
const BOWL := Rect2(38, 34, 36, 23)             # the festival bowl: x 38..74, z 34..57, sunk BOWL_Y
const BOWL_Y := -1.8
const STEPS_Z := Vector2(26, 34)                # the stair amphitheater, from the quad down to the bowl
const POOL := Vector2(53, -21)                  # the pool's middle...
const POOL_R := Vector2(13, 5.5)                # ...its half length and width (an oval)
const POOL_WATER := -0.25
const POOL_FLOOR := -2.4
const PROMENADE_Z := Vector2(-39, -28)          # the overlook walk along the north edge
const LIBRARY_HOLE := Vector2(11.0, 6.5)        # the hole over the library in floor 2's slab (centre LIBRARY_AT)
const LIBRARY_AT := Vector2(0, -6)
const BRIDGE_HALF := 11.0 * 0.258819                # the skybridge's half width: where the gallery rail's 75 degree post is
const HIDDEN_STAIR := Vector2(28.55, -14)          # the spiral stair from floor 3's secret hallway down Behind the Walls
const ROOF_HOLE := Rect2(-39, 5.5, 5.5, 12.5)    # the opening in the roof over the atrium the escalators up go through
const ROOF_Y := 3 * FLOOR_H                      # the roof: the palm terrace, the roof garden and the 4th floor's pavilion
const STAIR_R := 1.3

# The palette, straight (not run through theme.gd's tint: these are the picture's own colours)
const P_STONE := Color(0.80, 0.73, 0.93)
const P_TRIM := Color(0.95, 0.91, 0.99)
const P_ROOF := Color(0.47, 0.38, 0.80)
const P_GOLD := Color(0.96, 0.78, 0.40)
const P_GLOW := Color(1.0, 0.82, 0.62)
const P_NAVY := Color(0.17, 0.15, 0.40)
const P_HEDGE := Color(0.20, 0.47, 0.30)
const P_LEAF := Color(0.18, 0.52, 0.46)
const P_LAWN := Color(0.40, 0.60, 0.47)
const P_PAVING := Color(0.85, 0.80, 0.95)
const P_WATER := Color(0.45, 0.88, 1.0)
const P_PINK := Color(0.98, 0.52, 0.78)
const P_MAGENTA := Color(0.82, 0.28, 0.70)
const P_PLANTER := Color(0.66, 0.42, 0.62)


func pal(name: String, color: Color, rough := 0.85, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	# A material in the palace palette: its colour as given, not tinted by theme.gd
	var key := "palace " + name
	if mats.has(key):
		return mats[key]
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
	mats[key] = m
	return m


func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


func merged(parts: Array) -> ArrayMesh:
	# Many little pieces ([mesh, transform] pairs) as one mesh, so hundreds of flowers or books cost one draw
	var st := SurfaceTool.new()
	for p: Array in parts:
		st.append_from(p[0], 0, p[1])
	return st.commit()


func merged_at(parts: Array, material: Material, parent: Node, name := "") -> MeshInstance3D:
	if parts.is_empty():
		return null
	var mi := mesh_at(merged(parts), material, Vector3.ZERO, parent)
	if name != "":
		mi.name = name
	return mi


func static_box(parent: Node, size: Vector3, pos: Vector3, yaw := 0.0, rot := Vector3.ZERO) -> StaticBody3D:
	# Solid but not drawn (its look is a merged mesh, or nothing)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	var cs := CollisionShape3D.new()
	cs.shape = box_shape(size)
	body.add_child(cs)
	parent.add_child(body)
	return body


func _rect_hit(c: Vector2, a: float, r: Rect2) -> Vector2:
	# Where a ray from c at angle a leaves the rectangle r
	var d := Vector2(cos(a), sin(a))
	var t := INF
	if d.x > 0.0001:
		t = minf(t, (r.end.x - c.x) / d.x)
	elif d.x < -0.0001:
		t = minf(t, (r.position.x - c.x) / d.x)
	if d.y > 0.0001:
		t = minf(t, (r.end.y - c.y) / d.y)
	elif d.y < -0.0001:
		t = minf(t, (r.position.y - c.y) / d.y)
	return c + d * t


func holed_slab(parent: Node, name: String, r: Rect2, c: Vector2, rad: Vector2, top: float, thick: float,
		material: Material, rim_material: Material, rim_depth := -1.0, segs := 96) -> StaticBody3D:
	# A flat slab over the rectangle r (x, z) with an oval hole (middle c, half sizes rad), solid on top and round the
	# hole's rim: the library's open middle in floor 2, and the pool in the east lawn. The rim goes rim_depth down
	# (the slab's own thickness unless asked for more: the pool's sides).
	if rim_depth < 0.0:
		rim_depth = thick
	var angles: Array = []
	for k in segs:
		angles.append(TAU * k / segs)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		angles.append(fposmod(atan2(corner.y - c.y, corner.x - c.x), TAU))
	angles.sort()
	var top_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim_st := SurfaceTool.new()
	rim_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var bottom := top - thick
	for i in angles.size():
		var a0: float = angles[i]
		var a1: float = angles[(i + 1) % angles.size()] + (TAU if i == angles.size() - 1 else 0.0)
		if a1 - a0 < 0.00001:
			continue
		var e0 := c + Vector2(cos(a0) * rad.x, sin(a0) * rad.y)
		var e1 := c + Vector2(cos(a1) * rad.x, sin(a1) * rad.y)
		var o0 := _rect_hit(c, a0, r)
		var o1 := _rect_hit(c, a1, r)
		for y in [top, bottom]:
			var n := Vector3.UP if y == top else Vector3.DOWN
			var tri := [Vector3(e0.x, y, e0.y), Vector3(o0.x, y, o0.y), Vector3(o1.x, y, o1.y),
				Vector3(e0.x, y, e0.y), Vector3(o1.x, y, o1.y), Vector3(e1.x, y, e1.y)]
			for v: Vector3 in tri:
				top_st.set_normal(n)
				top_st.add_vertex(v)
			if y == top:
				faces.append_array(PackedVector3Array(tri))
		var inward := -Vector3((e0.x + e1.x) / 2 - c.x, 0, (e0.y + e1.y) / 2 - c.y).normalized()
		var lo := top - rim_depth
		var quad := [Vector3(e0.x, top, e0.y), Vector3(e1.x, top, e1.y), Vector3(e1.x, lo, e1.y),
			Vector3(e0.x, top, e0.y), Vector3(e1.x, lo, e1.y), Vector3(e0.x, lo, e0.y)]
		for v: Vector3 in quad:
			rim_st.set_normal(inward)
			rim_st.add_vertex(v)
		faces.append_array(PackedVector3Array(quad))
	var body := StaticBody3D.new()
	body.name = name
	parent.add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var top_mat := material.duplicate() as StandardMaterial3D
	top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rim_mat := rim_material.duplicate() as StandardMaterial3D
	rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_at(top_st.commit(), top_mat, Vector3.ZERO, body)
	mesh_at(rim_st.commit(), rim_mat, Vector3.ZERO, body)
	return body


# ----------------------------------------------------------------------------- Little things used all over
func moon_banner(parent: Node, pos: Vector3, yaw: float, size := 1.0) -> void:
	# A navy banner with a gold crescent moon and a star, hanging from a gold rod; it faces local +z
	var b := node("Moon Banner", parent, pos, yaw)
	b.scale = Vector3.ONE * size
	var navy := pal("Banner Navy", P_NAVY, 0.9)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	mesh_at(box(Vector3(1.3, 2.6, 0.05)), navy, Vector3(0, -1.3, 0), b)
	for s in [-1.0, 1.0]:                              # the swallow-tail at the bottom
		mesh_at(box(Vector3(0.65, 0.65, 0.05)), navy, Vector3(s * 0.33, -2.6, 0), b, 0.0, Vector3(0, 0, s * PI / 4))
	mesh_at(box(Vector3(1.3, 0.08, 0.07)), gold, Vector3(0, -0.12, 0.01), b)
	mesh_at(cylinder(0.035, 0.035, 1.6, 8), gold, Vector3.ZERO, b, 0.0, Vector3(0, 0, PI / 2))
	for s in [-1.0, 1.0]:
		mesh_at(sphere(0.07, 8), gold, Vector3(s * 0.82, 0, 0), b)
	# The crescent: a gold disc with a navy one over most of it
	mesh_at(cylinder(0.36, 0.36, 0.02, 24), gold, Vector3(0, -1.15, 0.04), b, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cylinder(0.31, 0.31, 0.02, 24), navy, Vector3(0.14, -1.07, 0.055), b, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(sphere(0.07, 6), gold, Vector3(0.25, -1.55, 0.04), b)


func lamp_post(parent: Node, at: Vector3, with_light := true) -> void:
	var l := node("Lamp Post", parent, at)
	var iron := pal("Lamp Iron", P_NAVY, 0.5, 0.5)
	var glass := pal("Lamp Glow", P_GLOW, 0.3, 0.0, 2.2)
	solid_cylinder(0.09, 3.2, iron, Vector3(0, 1.6, 0), l)
	mesh_at(cylinder(0.2, 0.26, 0.2, 10), iron, Vector3(0, 0.1, 0), l)
	mesh_at(box(Vector3(0.36, 0.5, 0.36)), glass, Vector3(0, 3.45, 0), l)
	mesh_at(cylinder(0.0, 0.3, 0.25, 4), iron, Vector3(0, 3.82, 0), l, PI / 4)
	if with_light:
		var o := OmniLight3D.new()
		o.position = Vector3(0, 3.4, 0)
		o.light_color = P_GLOW
		o.light_energy = 1.1
		o.omni_range = 9.0
		l.add_child(o)


func round_tree(parent: Node, at: Vector3, s := 1.0, leaf: Material = null) -> void:
	# A cloud-puff tree like the picture's: a pale trunk and a round crown of soft puffs
	var t := node("Tree", parent, at)
	var bark := pal("Tree Bark", Color(0.55, 0.42, 0.52), 0.9)
	if leaf == null:
		leaf = pal("Tree Leaf", P_LEAF, 0.9)
	solid_cylinder(0.22 * s, 2.6 * s, bark, Vector3(0, 1.3 * s, 0), t)
	var parts := []
	var puffs := [[Vector3(0, 3.6, 0), 1.7], [Vector3(1.1, 3.2, 0.3), 1.2], [Vector3(-1.0, 3.3, -0.4), 1.25],
		[Vector3(0.2, 3.3, 1.1), 1.15], [Vector3(-0.3, 3.1, -1.1), 1.1], [Vector3(0.1, 4.5, 0.1), 1.1]]
	for p: Array in puffs:
		parts.append([sphere(1.0, 12), xf((p[0] as Vector3) * s, Vector3.ZERO, Vector3.ONE * float(p[1]) * s)])
	merged_at(parts, leaf, t, "Crown")


func blossom_tree(parent: Node, at: Vector3, s := 1.0) -> void:
	round_tree(parent, at, s, pal("Blossom", Color(0.99, 0.72, 0.88), 0.9))


func palm(parent: Node, at: Vector3, lean: float, h := 7.0) -> Vector3:
	# A palm leaning a little towards `lean` (radians round y); gives back its top, for hammocks and lights
	var p := node("Palm", parent, at)
	var bark := pal("Palm Trunk", Color(0.78, 0.55, 0.42), 0.9)
	var frond := pal("Palm Frond", Color(0.24, 0.58, 0.36), 0.85)
	var dir := Vector3(sin(lean), 0, cos(lean))
	var parts := []
	var seg := 10
	var top := Vector3.ZERO
	for k in seg:
		var t := float(k) / seg
		var c := dir * (t * t * 1.4) + Vector3(0, t * h, 0)
		parts.append([cylinder(0.26 - 0.1 * t, 0.3 - 0.1 * t, h / seg + 0.05, 8), xf(c + Vector3(0, h / seg / 2, 0))])
		top = c + Vector3(0, h / seg, 0)
	merged_at(parts, bark, p, "Trunk")
	solid_cylinder(0.3, h * 0.6, pal("Palm Trunk", Color()), Vector3(0, h * 0.3, 0), p).visible = false
	var fronds := []
	for k in 8:
		var a := TAU * k / 8.0
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.55)
		fronds.append([box(Vector3(0.5, 0.06, 3.2)), Transform3D(b, top + b * Vector3(0, 0, 1.5))])
		fronds.append([box(Vector3(0.35, 0.05, 1.4)), Transform3D(b * Basis(Vector3.RIGHT, 0.5), top + b * Vector3(0, -0.4, 3.0))])
	merged_at(fronds, frond, p, "Fronds")
	for k in 3:
		mesh_at(sphere(0.18, 8), pal("Coconut", Color(0.45, 0.32, 0.3)), top + Vector3(cos(k * 2.1) * 0.25, -0.2, sin(k * 2.1) * 0.25), p)
	return at + top


func hammock(parent: Node, a: Vector3, b: Vector3, colour: Color) -> void:
	# A striped hammock slung between two points (palm trunks), sagging in the middle
	var h := node("Hammock", parent)
	var cloth := pal("Hammock %s" % colour.to_html(false), colour, 0.95)
	var stripe := pal("Hammock Stripe", P_TRIM, 0.95)
	var rope := pal("Rope", Color(0.85, 0.78, 0.7), 0.95)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var yaw := atan2(flat.x, flat.z)
	var n := 8
	var cloth_parts := []
	var stripe_parts := []
	var sag := 1.0
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(b, 0.15 + 0.7 * t0) - Vector3(0, sag * sin(PI * t0), 0)
		var p1 := a.lerp(b, 0.15 + 0.7 * t1) - Vector3(0, sag * sin(PI * t1), 0)
		var mid := (p0 + p1) / 2
		var pitch := -atan2(p1.y - p0.y, Vector2(p1.x - p0.x, p1.z - p0.z).length())
		var tr := xf(mid, Vector3(pitch, yaw, 0))
		cloth_parts.append([box(Vector3(1.1, 0.05, p0.distance_to(p1) + 0.02)), tr])
		stripe_parts.append([box(Vector3(0.18, 0.055, p0.distance_to(p1) + 0.02)), tr * Transform3D(Basis(), Vector3(0.3, 0.003, 0))])
		stripe_parts.append([box(Vector3(0.18, 0.055, p0.distance_to(p1) + 0.02)), tr * Transform3D(Basis(), Vector3(-0.3, 0.003, 0))])
	merged_at(cloth_parts, cloth, h, "Cloth")
	merged_at(stripe_parts, stripe, h, "Stripes")
	for e in [[a, a.lerp(b, 0.15)], [b, a.lerp(b, 0.85)]]:
		var p0: Vector3 = e[0]
		var p1: Vector3 = e[1]
		var mi := mesh_at(cylinder(0.025, 0.025, p0.distance_to(p1), 5), rope, (p0 + p1) / 2, h)
		mi.look_at_from_position((p0 + p1) / 2, p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.99 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)


func planter(parent: Node, at: Vector3, size: Vector2, yaw := 0.0, seed_n := 1) -> void:
	# A raised planter box full of tulips and round flowers, like the ones round the picture's fountain
	var p := node("Planter", parent, at, yaw)
	solid_box(Vector3(size.x, 0.7, size.y), pal("Planter", P_PLANTER, 0.8), Vector3(0, 0.35, 0), p)
	mesh_at(box(Vector3(size.x + 0.16, 0.1, size.y + 0.16)), pal("Planter Rim", P_TRIM, 0.6), Vector3(0, 0.72, 0), p)
	mesh_at(box(Vector3(size.x - 0.2, 0.06, size.y - 0.2)), pal("Planter Soil", Color(0.3, 0.22, 0.26)), Vector3(0, 0.74, 0), p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + seed_n
	var leaves := []
	var blooms := [[], [], []]
	var cols := [P_PINK, P_MAGENTA, Color(0.98, 0.85, 0.95)]
	var nx := int(size.x / 0.45)
	var nz := int(size.y / 0.45)
	for ix in nx:
		for iz in nz:
			var q := Vector3(-size.x / 2 + (ix + 0.5) * size.x / nx, 0.78, -size.y / 2 + (iz + 0.5) * size.y / nz)
			q += Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
			leaves.append([sphere(0.22, 6), xf(q + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.8, 1))])
			var hh := rng.randf_range(0.35, 0.6)
			blooms[rng.randi() % 3].append([sphere(0.13, 8), xf(q + Vector3(0, hh, 0), Vector3.ZERO, Vector3(1, 1.35, 1))])
	merged_at(leaves, pal("Planter Leaf", Color(0.25, 0.55, 0.32), 0.9), p, "Leaves")
	for k in 3:
		merged_at(blooms[k], pal("Tulip %d" % k, cols[k], 0.7), p, "Tulips %d" % k)


func bench(parent: Node, at: Vector3, yaw: float) -> void:
	# A lilac garden bench, seat to the front (local +z)
	var b := node("Bench", parent, at, yaw)
	var wood := pal("Bench Seat", Color(0.62, 0.52, 0.80), 0.7)
	var iron := pal("Lamp Iron", P_NAVY, 0.5, 0.5)
	solid_box(Vector3(2.0, 0.08, 0.6), wood, Vector3(0, 0.48, 0), b)
	mesh_at(box(Vector3(2.0, 0.5, 0.06)), wood, Vector3(0, 0.85, -0.3), b, 0.0, Vector3(-0.15, 0, 0))
	for x in [-0.85, 0.85]:
		mesh_at(box(Vector3(0.08, 0.46, 0.55)), iron, Vector3(x, 0.23, 0), b)
		mesh_at(box(Vector3(0.08, 0.6, 0.08)), iron, Vector3(x, 0.8, -0.3), b)


func tiered_fountain(parent: Node, at: Vector3, s := 1.0, name := "Fountain") -> void:
	# The picture's fountain: a round pool and three bowls one above the other, water spilling over each and glowing
	# from inside, with a glowing crystal on top
	var f := node(name, parent, at)
	f.scale = Vector3.ONE * s
	var stone := pal("Fountain Stone", P_TRIM, 0.55)
	var water := pal("Fountain Water", P_WATER, 0.05, 0.0, 1.4, 0.75)
	var fall := pal("Fountain Fall", Color(0.7, 0.95, 1.0), 0.05, 0.0, 1.8, 0.45)
	var crystal := pal("Fountain Crystal", Color(0.75, 0.95, 1.0), 0.05, 0.0, 3.0, 0.9)
	# The pool: a ring of rim (solid, you can sit on it) round a water disc
	for k in 24:
		var a := TAU * k / 24.0
		var p := Vector3(cos(a) * 4.0, 0.3, sin(a) * 4.0)
		var body := solid_box(Vector3(0.6, 0.6, 1.08), stone, p, f, -a)
		body.name = "Rim"
	mesh_at(cylinder(3.75, 3.75, 0.08, 40), water, Vector3(0, 0.4, 0), f)
	mesh_at(cylinder(3.75, 3.75, 0.1, 40), pal("Pool Tile", Color(0.35, 0.55, 0.85)), Vector3(0, 0.05, 0), f)
	# The stem and three bowls
	solid_cylinder(0.55, 1.6, stone, Vector3(0, 0.8, 0), f)
	var bowls := [[2.1, 1.75], [1.25, 2.9], [0.65, 3.85]]
	for k in bowls.size():
		var r: float = bowls[k][0]
		var y: float = bowls[k][1]
		mesh_at(cylinder(r, r * 0.45, 0.45, 32), stone, Vector3(0, y, 0), f)
		mesh_at(cylinder(r * 0.9, r * 0.9, 0.05, 32), water, Vector3(0, y + 0.21, 0), f)
		var sheet := CylinderMesh.new()                 # the water spilling over the rim, a glowing curtain
		sheet.top_radius = r * 1.02
		sheet.bottom_radius = r * 1.15
		var drop: float = (y - 0.45) if k == 0 else (y - float(bowls[k - 1][1]) - 0.2)
		sheet.height = drop
		sheet.cap_top = false
		sheet.cap_bottom = false
		sheet.radial_segments = 32
		mesh_at(sheet, fall, Vector3(0, y + 0.2 - drop / 2, 0), f)
		if k < bowls.size() - 1:
			mesh_at(cylinder(0.3 - k * 0.08, 0.35 - k * 0.08, 1.0, 12), stone, Vector3(0, y + 0.6, 0), f)
	mesh_at(cylinder(0.0, 0.22, 0.7, 6), crystal, Vector3(0, 4.55, 0), f)
	mesh_at(cylinder(0.22, 0.0, 0.35, 6), crystal, Vector3(0, 4.03, 0), f)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = P_WATER
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.position = Vector3(0, 1.6, 0)
	f.add_child(glow)


func arch_window(parts_glass: Array, parts_trim: Array, base: Transform3D, w := 1.6, h := 2.6) -> void:
	# An arched window on a wall, in the frame `base` (x along the wall, y up, z out of it): a glowing pane with a
	# round top, a pale frame round it and a sill
	parts_glass.append([box(Vector3(w, h, 0.06)), base * Transform3D(Basis(), Vector3(0, h / 2, 0.05))])
	parts_glass.append([cylinder(w / 2, w / 2, 0.06, 16), base * xf(Vector3(0, h, 0.05), Vector3(PI / 2, 0, 0))])
	parts_trim.append([box(Vector3(w + 0.3, 0.14, 0.3)), base * Transform3D(Basis(), Vector3(0, -0.05, 0.12))])
	for s in [-1.0, 1.0]:
		parts_trim.append([box(Vector3(0.14, h, 0.14)), base * Transform3D(Basis(), Vector3(s * (w / 2 + 0.07), h / 2, 0.1))])
	parts_trim.append([box(Vector3(0.1, h + w / 2, 0.1)), base * Transform3D(Basis(), Vector3(0, (h + w / 2) / 2, 0.1))])
	for k in 7:
		var a := PI * k / 6.0
		parts_trim.append([box(Vector3(0.22, 0.14, 0.14)), base * xf(Vector3(cos(a) * (w / 2 + 0.07), h + sin(a) * (w / 2 + 0.07), 0.1),
			Vector3(0, 0, a + PI / 2))])


# ----------------------------------------------------------------------------- The palace outside
func _palace() -> void:
	# Dress the building's outside as the picture's palace: pale pilasters and cornices on the lilac walls, rows of
	# warm arched windows on every floor, crescent-moon banners, a grand arched entrance with a gable and rose window
	# over it, a balustrade round the roof and a domed tower at each corner. None of it is solid but the towers and
	# the balustrade: the walls themselves are the building's own (_shell).
	var p := node("Palace", school)
	var glass := []
	var trim := []
	var h := 3 * FLOOR_H
	# Each side: from a to b along the wall, out = which way is outside, doors = distances along it to keep clear
	var sides := [
		[Vector2(ATRIUM_W, Z_S), Vector2(X_E, Z_S), Vector3(0, 0, 1), [40.0]],
		[Vector2(X_E, Z_S), Vector2(X_E, Z_N), Vector3(1, 0, 0), [32.0]],
		[Vector2(X_E, Z_N), Vector2(ATRIUM_W, Z_N), Vector3(0, 0, -1), [30.0]],
		[Vector2(ATRIUM_W, Z_N), Vector2(ATRIUM_W, Z_S), Vector3(-1, 0, 0), [24.0]],
	]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var out: Vector3 = side[2]
		var doors: Array = side[3]
		var length := a.distance_to(b)
		var along := Vector3(b.x - a.x, 0, b.y - a.y) / length
		var basis := Basis(along, Vector3.UP, out)
		var face := Vector3(a.x, 0, a.y) + out * 0.3
		var front: bool = out.z > 0.5
		# Plinth, cornices at each floor and the top, pilasters every 7 m
		trim.append([box(Vector3(length + 0.6, 1.0, 0.5)), Transform3D(basis, face + along * length / 2 + Vector3(0, 0.5, 0))])
		for y in [FLOOR_H, 2 * FLOOR_H, h]:
			trim.append([box(Vector3(length + 0.8, 0.4, 0.7)), Transform3D(basis, face + along * length / 2 + Vector3(0, y, 0) + out * 0.1)])
		var bays := int(round(length / 7.0))
		var north: bool = out.z < -0.5
		for k in bays + 1:
			var px := a.x + along.x * (length * k / bays)
			var ph := (2 * FLOOR_H + WINDOW_Y.x - 0.2) if north and absf(px) < WINDOW_X + 0.5 else h
			trim.append([box(Vector3(0.9, ph, 0.4)), Transform3D(basis, face + along * (length * k / bays) + Vector3(0, ph / 2, 0))])
		# Windows in every bay on every floor, but not where a door is (nor in the front's middle: the entrance)
		for k in bays:
			var d := length * (k + 0.5) / bays
			var x := a.x + along.x * d
			var by_door := false
			for dd: float in doors:
				if absf(d - dd) < 3.0:
					by_door = true
			if front and absf(x) < 6.0:
				continue
			for f in 3:
				if f == 0 and by_door:
					continue
				if f == 2 and north and absf(x) < WINDOW_X + 1.0:
					continue                                    # the 3rd floor's real window wall is there
				var w := 1.8 if f < 2 else 1.5
				arch_window(glass, trim, Transform3D(basis, face + along * d + Vector3(0, f * FLOOR_H + 1.2, 0)), w, 2.6 if f < 2 else 2.2)
			if f_banner(k, bays):
				moon_banner(p, face + along * (d + length / bays / 2) + Vector3(0, 2 * FLOOR_H - 0.5, 0) + out * 0.35,
					atan2(out.x, out.z), 1.1)
		# Door frames on the side doors (the front's is the grand entrance below)
		if not front:
			for dd: float in doors:
				var at := face + along * dd
				trim.append([box(Vector3(DOOR_W + 1.0, 0.5, 0.4)), Transform3D(basis, at + Vector3(0, DOOR_H + 0.25, 0))])
				for s in [-1.0, 1.0]:
					trim.append([box(Vector3(0.45, DOOR_H, 0.4)), Transform3D(basis, at + along * s * (DOOR_W / 2 + 0.22) + Vector3(0, DOOR_H / 2, 0))])
				trim.append([cylinder(DOOR_W / 2 + 0.5, DOOR_W / 2 + 0.5, 0.3, 16), Transform3D(basis, at + Vector3(0, DOOR_H + 0.5, 0)) * xf(Vector3.ZERO, Vector3(PI / 2, 0, 0))])
				glass.append([cylinder(DOOR_W / 2, DOOR_W / 2, 0.32, 16), Transform3D(basis, at + Vector3(0, DOOR_H + 0.5, 0.02)) * xf(Vector3.ZERO, Vector3(PI / 2, 0, 0))])
				moon_banner(p, at + along * 2.4 + Vector3(0, DOOR_H + 1.4, 0) + out * 0.35, atan2(out.x, out.z), 0.8)
				moon_banner(p, at - along * 2.4 + Vector3(0, DOOR_H + 1.4, 0) + out * 0.35, atan2(out.x, out.z), 0.8)
	_entrance(p, glass, trim)
	merged_at(glass, pal("Window Glow", Color(1.0, 0.76, 0.5), 0.3, 0.0, 0.75), p, "Windows")
	merged_at(trim, pal("Palace Trim", P_TRIM, 0.6), p, "Trim")
	_roof_edge(p)
	for c in [Vector2(ATRIUM_W - 2.6, Z_S + 2.6), Vector2(X_E + 2.6, Z_S + 2.6), Vector2(X_E + 2.6, Z_N - 2.6),
			Vector2(ATRIUM_W - 2.6, Z_N - 2.6)]:
		_tower(p, Vector3(c.x, 0, c.y))


func f_banner(k: int, bays: int) -> bool:
	# Banners hang between every other pair of bays
	return k % 2 == 0 and k < bays - 1


func _entrance(p: Node3D, glass: Array, trim: Array) -> void:
	# The grand entrance in the middle of the front: a tall arch round the doors, lanterns and banners each side, a
	# big arched window over it, a rose window above that and a curved gable over the roof line with a crescent on top
	var e := node("Grand Entrance", p, Vector3(0, 0, Z_S + 0.3))
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var h := 3 * FLOOR_H
	# The frontispiece: a slightly forward block of wall the full height, and a gable above the roof
	mesh_at(box(Vector3(12, h, 0.5)), stone, Vector3(0, h / 2, 0.15), e)
	for s in [-1.0, 1.0]:
		trim.append([box(Vector3(1.1, h + 0.5, 0.7)), xf(Vector3(s * 6.3, (h + 0.5) / 2, Z_S + 0.6))])
	# The gable: a stepped curve of stone over the roof line
	var gable := [[11.0, 1.6], [8.6, 3.0], [6.0, 4.2], [3.4, 5.0]]
	for g: Array in gable:
		solid_box(Vector3(g[0], g[1], 0.6), stone, Vector3(0, h + float(g[1]) / 2, 0.15), e)
		trim.append([box(Vector3(float(g[0]) + 0.3, 0.3, 0.8)), xf(Vector3(0, h + float(g[1]), Z_S + 0.45))])
	glass.append([cylinder(1.5, 1.5, 0.1, 24), xf(Vector3(0, h + 2.4, Z_S + 0.8), Vector3(PI / 2, 0, 0))])
	for k in 8:                                        # the rose window's spokes
		trim.append([box(Vector3(0.12, 3.0, 0.1)), xf(Vector3(0, h + 2.4, Z_S + 0.9), Vector3(0, 0, PI * k / 8.0))])
	trim.append([cylinder(1.65, 1.65, 0.08, 24), xf(Vector3(0, h + 2.4, Z_S + 0.75), Vector3(PI / 2, 0, 0))])
	# A gold crescent and star on the gable's top
	mesh_at(cylinder(0.75, 0.75, 0.1, 24), gold, Vector3(0, h + 6.0, 0.15), e, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cylinder(0.64, 0.64, 0.12, 24), pal("Sky Cut", Color(0.62, 0.52, 0.9), 0.8), Vector3(0.28, h + 6.15, 0.17), e, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(sphere(0.18, 8), gold, Vector3(0.6, h + 5.3, 0.15), e)
	# The doorway arch (the doors themselves are the wall's opening, DOOR_W x DOOR_H)
	for s in [-1.0, 1.0]:
		trim.append([box(Vector3(0.7, 4.2, 0.9)), xf(Vector3(s * 2.2, 2.1, Z_S + 0.7))])
		trim.append([cylinder(0.3, 0.36, 4.0, 12), xf(Vector3(s * 3.2, 2.0, Z_S + 0.9))])
	for k in 13:
		var a := PI * k / 12.0
		trim.append([box(Vector3(0.6, 0.35, 0.9)), xf(Vector3(cos(a) * 2.2, 4.2 + sin(a) * 2.2, Z_S + 0.7), Vector3(0, 0, a + PI / 2))])
	glass.append([cylinder(1.9, 1.9, 0.1, 24), xf(Vector3(0, 4.2, Z_S + 0.55), Vector3(PI / 2, 0, 0))])
	glass.append([box(Vector3(3.8, 1.2, 0.1)), xf(Vector3(0, 3.6, Z_S + 0.55))])
	# Glass doors, open, folded back either side of the doorway
	for s in [-1.0, 1.0]:
		mesh_at(box(Vector3(0.06, DOOR_H - 0.1, 1.15)), pal("Door Glass", Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.3, 0.35),
			Vector3(s * (DOOR_W / 2 + 0.05), DOOR_H / 2, 0.8), e)
	# The big window over the doors and the lanterns either side
	arch_window(glass, trim, Transform3D(Basis(), Vector3(0, FLOOR_H + 0.8, Z_S + 0.5)), 3.4, 3.6)
	arch_window(glass, trim, Transform3D(Basis(), Vector3(0, 2 * FLOOR_H + 1.0, Z_S + 0.5)), 2.6, 2.6)
	for s in [-1.0, 1.0]:
		moon_banner(e, Vector3(s * 4.6, 2 * FLOOR_H - 0.3, 0.55), 0.0, 1.3)
		moon_banner(e, Vector3(s * 8.4, FLOOR_H - 0.6, 0.35), 0.0, 1.0)
		var lantern := mesh_at(box(Vector3(0.45, 0.65, 0.45)), pal("Lamp Glow", P_GLOW, 0.3, 0.0, 2.2), Vector3(s * 4.2, 3.4, 0.7), e)
		lantern.name = "Lantern"
		var o := OmniLight3D.new()
		o.position = Vector3(s * 4.2, 3.4, 1.6)
		o.light_color = P_GLOW
		o.light_energy = 1.2
		o.omni_range = 8.0
		e.add_child(o)
	label(e, "The Castle School", Vector3(0, FLOOR_H - 0.6, 1.2), 0.0, 96)


func _roof_edge(p: Node3D) -> void:
	# A balustrade round the roof's edge: little posts under a rail, solid so nobody walks off the roof
	var r := node("Balustrade", p)
	var h := 3 * FLOOR_H
	var posts := []
	var rails := []
	var edges := [[Vector2(ATRIUM_W, Z_S), Vector2(X_E, Z_S)], [Vector2(X_E, Z_S), Vector2(X_E, Z_N)],
		[Vector2(X_E, Z_N), Vector2(ATRIUM_W, Z_N)], [Vector2(ATRIUM_W, Z_N), Vector2(ATRIUM_W, Z_S)]]
	for e: Array in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var yaw := atan2(dir.x, dir.y)
		var mid := (a + b) / 2
		static_box(r, Vector3(0.4, 1.2, length), Vector3(mid.x, h + 0.6, mid.y), yaw)
		rails.append([box(Vector3(0.45, 0.16, length + 0.4)), xf(Vector3(mid.x, h + 1.12, mid.y), Vector3(0, yaw, 0))])
		rails.append([box(Vector3(0.45, 0.16, length + 0.4)), xf(Vector3(mid.x, h + 0.1, mid.y), Vector3(0, yaw, 0))])
		var n := int(length / 0.45)
		for k in n:
			var q := a + dir * (length * (k + 0.5) / n)
			posts.append([cylinder(0.09, 0.12, 0.95, 8), xf(Vector3(q.x, h + 0.6, q.y))])
	merged_at(posts + rails, pal("Palace Trim", P_TRIM, 0.6), r, "Rails")


func _tower(p: Node3D, at: Vector3) -> void:
	# A round corner tower, a little taller than the roof, with slit windows and an onion dome in lavender and gold
	var t := node("Tower", p, at)
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var roof := pal("Dome", P_ROOF, 0.45, 0.2)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var top := 3 * FLOOR_H + 4.0
	solid_cylinder(2.6, top, stone, Vector3(0, top / 2, 0), t)
	var trim := []
	var glass := []
	for y in [1.0, FLOOR_H, 2 * FLOOR_H, 3 * FLOOR_H, top]:
		trim.append([cylinder(2.85, 2.85, 0.4, 32), xf(Vector3(0, y, 0))])
	for f in 4:
		for k in 4:
			var a := TAU * k / 4.0 + f * 0.4
			arch_window(glass, trim, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 2.55, f * FLOOR_H + 1.6, cos(a) * 2.55)), 0.7, 1.8)
	merged_at(trim, pal("Palace Trim", P_TRIM, 0.6), t, "Trim")
	merged_at(glass, pal("Window Glow", Color(1.0, 0.76, 0.5), 0.3, 0.0, 0.75), t, "Windows")
	var dome := mesh_at(sphere(2.9, 24), roof, Vector3(0, top + 1.2, 0), t)
	dome.scale = Vector3(1, 1.3, 1)
	mesh_at(cylinder(0.0, 1.0, 2.6, 16), roof, Vector3(0, top + 5.0, 0), t)
	mesh_at(sphere(0.32, 12), gold, Vector3(0, top + 6.4, 0), t)
	mesh_at(cylinder(0.05, 0.05, 1.2, 6), gold, Vector3(0, top + 7.0, 0), t)
	mesh_at(cylinder(0.32, 0.32, 0.06, 16), gold, Vector3(0, top + 7.7, 0), t, 0.0, Vector3(PI / 2, 0, 0))


# ----------------------------------------------------------------------------- The grounds
func _grounds() -> void:
	# The lawns all round the school, the paths, the overlook walk along the north edge, the golf-cart loop, the
	# campus's edges (walled in, so nobody walks off into the Void), and the way back to town.
	var g := node("Grounds", school)
	var lawn := pal("Lawn", P_LAWN, 0.95)
	var paving := pal("Paving", P_PAVING, 0.75)
	var path := pal("Path", Color(0.92, 0.88, 0.98), 0.7)
	# Lawns, top at y 0, round the building and the east side's pool, quad and bowl
	var pieces := [Rect2(-72, -40, 32, 103), Rect2(-40, -40, 74, 16), Rect2(-40, 24, 74, 39), Rect2(30, -24, 4, 48),
		Rect2(34, 57, 44, 6), Rect2(34, 26, 4, 31), Rect2(74, 26, 4, 31)]
	for r: Rect2 in pieces:
		var deep := 2.6
		var body := solid_box(Vector3(r.size.x, deep, r.size.y), lawn, Vector3(r.get_center().x, -deep / 2, r.get_center().y), g)
		body.name = "Lawn"
	solid_box(Vector3(8, 0.4, 3.5), paving, Vector3(0, -0.2, 64.75), g).name = "Way Out"
	# Paths and paved places (thin, just over the lawn)
	var flat := []
	var paved := [Rect2(-15, 24, 30, 17), Rect2(-2.5, 41, 5, 22), Rect2(-8, 47, 5.5, 2.4),     # plaza, main path, greenhouse
		Rect2(-26, 31, 11, 2.6), Rect2(14, 28.5, 24, 3), Rect2(-2, -28, 4, 4),                   # to the maze, to the quad, north door
		Rect2(30, -9.5, 4, 3), Rect2(-46, -1.5, 6, 3)]                                           # east door, west door
	for r: Rect2 in paved:
		flat.append([box(Vector3(r.size.x, 0.03, r.size.y)), xf(Vector3(r.get_center().x, 0.015, r.get_center().y))])
	merged_at(flat, paving, g, "Paths")
	# The golf-cart loop: round the whole campus and through the "To Town" arch
	var loop := []
	for r: Rect2 in [Rect2(-70.5, -33, 148, 3), Rect2(-70.5, 59, 148, 3), Rect2(-70.5, -33, 3, 95), Rect2(74.5, -33, 3, 95)]:
		var y := 0.02
		loop.append([box(Vector3(r.size.x, 0.03, r.size.y)), xf(Vector3(r.get_center().x, y, r.get_center().y))])
	merged_at(loop, path, g, "Cart Loop")
	label(g, "Golf-Cart Loop", Vector3(-69, 2.6, 0), 0.0, 48)
	_golf_cart(g, Vector3(7.5, 0, 60.5), PI / 2)
	_overlook(g)
	_edges(g)


func _golf_cart(parent: Node, at: Vector3, yaw: float) -> void:
	# A little electric cart parked by the arch, for the loop (for show for now)
	var c := node("Golf Cart", parent, at, yaw)
	var body := pal("Cart Body", Color(0.95, 0.92, 1.0), 0.4, 0.2)
	var seat := pal("Cart Seat", P_MAGENTA, 0.8)
	var tyre := pal("Tyre", Color(0.12, 0.1, 0.16), 0.9)
	solid_box(Vector3(1.4, 0.6, 2.6), body, Vector3(0, 0.6, 0), c)
	mesh_at(box(Vector3(1.3, 0.4, 0.6)), seat, Vector3(0, 1.1, 0.2), c)
	mesh_at(box(Vector3(1.3, 0.6, 0.12)), seat, Vector3(0, 1.4, 0.55), c)
	for s in [-1.0, 1.0]:
		for z in [-0.9, 0.9]:
			mesh_at(cylinder(0.3, 0.3, 0.2, 14), tyre, Vector3(s * 0.72, 0.3, z), c, 0.0, Vector3(0, 0, PI / 2))
		for z in [-1.1, 1.1]:
			mesh_at(cylinder(0.04, 0.04, 1.4, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(s * 0.62, 1.6, z), c)
	mesh_at(box(Vector3(1.5, 0.08, 2.5)), pal("Cart Roof", P_PINK, 0.6), Vector3(0, 2.32, 0), c)
	mesh_at(cylinder(0.25, 0.25, 0.05, 14), tyre, Vector3(0.3, 1.45, -0.5), c, 0.0, Vector3(-0.9, 0, 0))


func _overlook(parent: Node) -> void:
	# The overlook walk: a wide paved promenade along the campus's north edge with a railing, benches facing out over
	# the Void and two viewers on posts
	var o := node("Overlook Walk", parent)
	var paving := pal("Paving", P_PAVING, 0.75)
	var z0 := PROMENADE_Z.x
	var z1 := PROMENADE_Z.y
	mesh_at(box(Vector3(CAMPUS.size.x, 0.03, z1 - z0)), paving, Vector3(CAMPUS.get_center().x, 0.016, (z0 + z1) / 2), o)
	var x0 := CAMPUS.position.x
	var x1 := CAMPUS.end.x
	var rail := []
	var glass := []
	static_box(o, Vector3(x1 - x0, 1.2, 0.3), Vector3((x0 + x1) / 2, 0.6, z0 - 0.3))
	rail.append([box(Vector3(x1 - x0, 0.14, 0.24)), xf(Vector3((x0 + x1) / 2, 1.15, z0 - 0.3))])
	rail.append([box(Vector3(x1 - x0, 0.3, 0.4)), xf(Vector3((x0 + x1) / 2, 0.15, z0 - 0.3))])
	glass.append([box(Vector3(x1 - x0, 0.85, 0.04)), xf(Vector3((x0 + x1) / 2, 0.72, z0 - 0.3))])
	var n := int((x1 - x0) / 3.0)
	for k in n + 1:
		rail.append([box(Vector3(0.14, 1.2, 0.14)), xf(Vector3(x0 + (x1 - x0) * k / n, 0.6, z0 - 0.3))])
	merged_at(rail, pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), o, "Railing")
	merged_at(glass, pal("Rail Glass", Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.2, 0.3), o, "Railing Glass")
	for x in [-60.0, -30.0, -10.0, 10.0, 46.0, 66.0]:
		bench(o, Vector3(x, 0, z0 + 2.0), PI)
	for x in [-45.0, -20.0, 0.0, 20.0, 36.0, 56.0, 76.0]:
		lamp_post(o, Vector3(x, 0, z1 - 0.6), x == 0.0 or x == 56.0 or x == -45.0)
	for x in [-38.0, 28.0]:
		var v := node("Viewer", o, Vector3(x, 0, z0 + 1.0), PI)
		var navy := pal("Lamp Iron", P_NAVY, 0.5, 0.5)
		solid_cylinder(0.08, 1.2, navy, Vector3(0, 0.6, 0), v)
		mesh_at(cylinder(0.12, 0.16, 0.5, 12), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(0, 1.35, 0.1), v, 0.0, Vector3(PI / 2 - 0.2, 0, 0))
	label(o, "Overlook Walk", Vector3(0, 3.0, (z0 + z1) / 2), 0.0, 64)


func _edges(parent: Node) -> void:
	# The campus is walled in all round by see-through walls (the overlook's railing is a real one), with a gap only
	# for the way out to town past the arch; a safety net far below catches anyone who finds a way out anyway.
	var e := node("Edges", parent)
	var x0 := CAMPUS.position.x
	var x1 := CAMPUS.end.x
	var z0 := CAMPUS.position.y
	var z1 := CAMPUS.end.y
	_invisible_wall(e, "Edge North", Vector3(x1 - x0 + 2, 60, 0.6), Vector3((x0 + x1) / 2, 30, z0 - 0.8))
	_invisible_wall(e, "Edge West", Vector3(0.6, 60, z1 - z0 + 2), Vector3(x0 - 0.3, 30, (z0 + z1) / 2))
	_invisible_wall(e, "Edge East", Vector3(0.6, 60, z1 - z0 + 2), Vector3(x1 + 0.3, 30, (z0 + z1) / 2))
	_invisible_wall(e, "Edge South West", Vector3(-4.2 - x0, 60, 0.6), Vector3((x0 - 4.2) / 2, 30, z1 + 0.3))
	_invisible_wall(e, "Edge South East", Vector3(x1 - 4.2, 60, 0.6), Vector3((x1 + 4.2) / 2, 30, z1 + 0.3))
	for s in [-1.0, 1.0]:
		_invisible_wall(e, "Way Out Side", Vector3(0.4, 60, 3.6), Vector3(s * 4.2, 30, z1 + 1.8))
	_invisible_wall(e, "Garden Wall Way Out", Vector3(8.8, 60, 0.4), Vector3(0, 30, EXIT_Z + 1.4))
	var net := Area3D.new()
	net.name = "Fall Catch"
	net.position = Vector3(0, -25, 0)
	net.set_script(load("res://scripts/fall_catch.gd"))
	var ncs := CollisionShape3D.new()
	ncs.shape = box_shape(Vector3(600, 4, 600))
	net.add_child(ncs)
	e.add_child(net)
	door_trigger(e, "ExitToTown", Vector3(0, 1.5, EXIT_Z), Vector3(8, 3, 1.5), "res://scenes/town/town.tscn", "FromSchool")
	label(e, "To Town", Vector3(0, 2.6, EXIT_Z - 1.0), 0.0, 56)
	spawn_marker(e, "FromTown", Vector3(0, 1.0, 52), 0.0)
	net.set("back_to", net.get_path_to(e.get_node("FromTown")))


# ----------------------------------------------------------------------------- The Entrance Garden
func _entrance_garden() -> void:
	# In front of the palace: a paved forecourt round the tiered fountain with tulip planters, puff trees and lamps,
	# then the garden itself (the greenhouse to the west, the vegetable beds to the east, the rose arch between), two
	# hedge alcoves with benches in its front corners, and the flowering "To Town" hedge arch over the cart loop.
	var g := node("Entrance Garden", school)
	tiered_fountain(g, FOUNTAIN, 1.0, "Tiered Fountain")
	for c in [Vector2(-7.5, 27.5), Vector2(7.5, 27.5), Vector2(-7.5, 36.5), Vector2(7.5, 36.5)]:
		planter(g, Vector3(c.x, 0, c.y), Vector2(3.6, 1.6), 0.0, int(c.x + c.y))
	for c in [Vector2(-12.5, 26.5), Vector2(12.5, 26.5), Vector2(-12.5, 39), Vector2(12.5, 39)]:
		round_tree(g, Vector3(c.x, 0, c.y), 0.9)
	for c in [Vector2(-3.4, 25.5), Vector2(3.4, 25.5), Vector2(-3.4, 40.5), Vector2(3.4, 40.5)]:
		lamp_post(g, Vector3(c.x, 0, c.y), c.y > 30.0)
	bench(g, Vector3(-5.5, 0, 32), PI / 2)
	bench(g, Vector3(5.5, 0, 32), -PI / 2)
	# Low hedges round the forecourt's sides, with gaps for the paths
	var hedge := pal("Hedge", P_HEDGE, 0.95)
	for r: Rect2 in [Rect2(-15.4, 24.3, 0.8, 6.4), Rect2(-15.4, 33.5, 0.8, 7.5), Rect2(14.6, 24.3, 0.8, 3.9),
			Rect2(14.6, 31.8, 0.8, 9.2)]:
		solid_box(Vector3(r.size.x, 1.0, r.size.y), hedge, Vector3(r.get_center().x, 0.5, r.get_center().y), g)
	_greenhouse(g, GREENHOUSE)
	var beds := node("Vegetable Garden", g, Vector3(0, 0, 17))
	_vegetable_beds(beds)
	_rose_arch(g, 41.8)
	bench(g, Vector3(3.6, 0, 46), -PI / 2)
	bench(g, Vector3(-3.6, 0, 53), PI / 2)
	_watering_can(g, Vector3(4.6, 0, 44.5), 0.4, mat("Watering Can", Color(0.3, 0.6, 0.9), 0.4, 0.5))
	for s in [-1.0, 1.0]:
		_hedge_alcove(g, Vector3(s * 19.0, 0, 56.0), PI if s < 0 else PI)
	_town_arch(g)
	label(g, "Entrance Garden", Vector3(0, 6.2, 34), 0.0, 72)


func _hedge_alcove(parent: Node, at: Vector3, yaw: float) -> void:
	# A curved niche of hedge with a bench in it: a hidden-feeling nook (the plan's hedge alcoves)
	var a := node("Hedge Alcove", parent, at, yaw)
	var hedge := pal("Hedge", P_HEDGE, 0.95)
	for k in 7:
		var t := PI * k / 6.0
		solid_box(Vector3(1.2, 2.2, 0.8), hedge, Vector3(cos(t) * 2.2, 1.1, -sin(t) * 1.6 + 0.6), a, t - PI / 2)
	bench(a, Vector3(0, 0, -0.4), 0.0)


func _town_arch(parent: Node) -> void:
	# The flowering hedge arch at the garden's far edge, over the cart loop, on the way out to town
	var a := node("To Town Arch", parent, Vector3(0, 0, 60.5))
	var hedge := pal("Hedge", P_HEDGE, 0.95)
	for s in [-1.0, 1.0]:
		solid_box(Vector3(1.4, 4.0, 3.4), hedge, Vector3(s * 4.2, 2.0, 0), a)
	var parts := []
	var flowers := []
	for k in 13:
		var t := PI * k / 12.0
		var p := Vector3(-cos(t) * 4.2, 4.0 + sin(t) * 1.8, 0)
		parts.append([sphere(1.0, 10), xf(p, Vector3.ZERO, Vector3(0.9, 0.8, 1.7))])
		for q in 3:
			flowers.append([sphere(0.14, 6), xf(p + Vector3(sin(k * 3.1 + q) * 0.5, 0.5, -1.2 + q * 1.2))])
	merged_at(parts, hedge, a, "Arch")
	merged_at(flowers, pal("Hedge Flower", Color(0.86, 0.6, 1.0), 0.7, 0.0, 0.3), a, "Flowers")
	var sign := node("Sign", a, Vector3(5.6, 0, 1.6))
	solid_cylinder(0.08, 2.2, pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 1.1, 0), sign)
	moon_banner(sign, Vector3(0, 2.3, 0.1), 0.0, 0.5)


# ----------------------------------------------------------------------------- West: courtyard, palms and maze
func _courtyard() -> void:
	# The walled courtyard garden west of the school, through the glass doors in the atrium: a cloister of arches round
	# blossom trees, a small tiled fountain and benches, with gates to the palm grove and the overlook walk.
	var c := node("Courtyard Garden", school)
	var r := COURTYARD
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var trim := pal("Palace Trim", P_TRIM, 0.6)
	var wh := 4.2
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	# Walls with a gate in each of the east (to the school's west door), south (to the palms) and north (overlook)
	wall(c, Vector2(x0, z0), Vector2(x1, z0), stone, [(-56.0 - x0) / (x1 - x0)], wh, 0.6)
	wall(c, Vector2(x0, z1), Vector2(x1, z1), stone, [(-56.0 - x0) / (x1 - x0)], wh, 0.6)
	wall(c, Vector2(x0, z0), Vector2(x0, z1), stone, [], wh, 0.6)
	wall(c, Vector2(x1, z0), Vector2(x1, z1), stone, [(0.0 - z0) / (z1 - z0)], wh, 0.6)
	# A cornice along the top and pilasters on both faces, so the walls look like part of the palace from either side
	var dress := []
	for side: Array in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z1), Vector2(x1, z1)], [Vector2(x0, z0), Vector2(x0, z1)],
			[Vector2(x1, z0), Vector2(x1, z1)]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var length := a.distance_to(b)
		var mid := (a + b) / 2
		var basis := Basis(Vector3.UP, atan2((b - a).x, (b - a).y) + PI / 2)
		dress.append([box(Vector3(length + 0.9, 0.35, 0.95)), Transform3D(basis, Vector3(mid.x, wh + 0.12, mid.y))])
		for k in range(1, int(length / 4.0)):
			var q := a + (b - a) * (4.0 * k / length)
			if q.distance_to(Vector2(-56, z0)) < 2.2 or q.distance_to(Vector2(-56, z1)) < 2.2 or q.distance_to(Vector2(x1, 0)) < 2.2:
				continue                                    # not over a gate
			dress.append([box(Vector3(0.6, wh - 0.2, 0.9)), Transform3D(basis, Vector3(q.x, (wh - 0.2) / 2, q.y))])
	merged_at(dress, trim, c, "Wall Dressing")
	for bz in [z1 + 0.4]:
		for bx in [-62.0, -50.0]:
			moon_banner(c, Vector3(bx, 2.6, bz), 0.0, 0.8)
	# Tiled floor: a check of two lilacs
	var tiles := [[], []]
	for ix in int(r.size.x / 2.0):
		for iz in int(r.size.y / 2.0):
			tiles[(ix + iz) % 2].append([box(Vector3(1.98, 0.03, 1.98)), xf(Vector3(x0 + 1 + ix * 2.0, 0.017, z0 + 1 + iz * 2.0))])
	merged_at(tiles[0], pal("Tile Light", Color(0.9, 0.86, 0.98), 0.6), c, "Tiles")
	merged_at(tiles[1], pal("Tile Rose", Color(0.86, 0.72, 0.9), 0.6), c, "Tiles Rose")
	# The arcade: columns 2.6 m in from the north, west and south walls with round arches and a roof back to the wall
	var cols := []
	var arches := []
	var lines := [[Vector2(x0 + 2.6, z0 + 2.6), Vector2(x1 - 0.5, z0 + 2.6)], [Vector2(x0 + 2.6, z0 + 2.6), Vector2(x0 + 2.6, z1 - 2.6)],
		[Vector2(x0 + 2.6, z1 - 2.6), Vector2(x1 - 0.5, z1 - 2.6)]]
	for l: Array in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var n := int(a.distance_to(b) / 3.2)
		var dir := (b - a) / a.distance_to(b)
		var yaw := atan2(dir.x, dir.y)
		for k in n + 1:
			var q := a + dir * (a.distance_to(b) * k / n)
			if absf(q.x - (-56.0)) < 1.6 and l != lines[1]:
				continue                                # leave the gates clear
			var body := solid_cylinder(0.25, 3.0, trim, Vector3(q.x, 1.5, q.y), c)
			body.name = "Column"
			if k < n:
				var m := a + dir * (a.distance_to(b) * (k + 0.5) / n)
				for j in 7:
					var t := PI * j / 6.0
					var span := a.distance_to(b) / n / 2
					arches.append([box(Vector3(0.3, 0.3, 0.6)), xf(Vector3(m.x, 3.0 + sin(t) * 0.7, m.y) + Vector3(dir.x, 0, dir.y) * cos(t) * span,
						Vector3(0, yaw, 0))])
		var mid := (a + b) / 2
		var out := Vector2(-dir.y, dir.x)
		if l == lines[1]:
			out = Vector2(-1, 0)
		elif l == lines[0]:
			out = Vector2(0, -1)
		else:
			out = Vector2(0, 1)
		var roof_at := mid + out * 1.3
		arches.append([box(Vector3(2.9, 0.25, a.distance_to(b) + 0.3) if l == lines[1] else Vector3(a.distance_to(b) + 0.3, 0.25, 2.9)),
			xf(Vector3(roof_at.x, 3.85, roof_at.y))])
	merged_at(arches, stone, c, "Arcade")
	# Blossom trees, the fountain, benches and planters along the walls
	for q in [Vector2(-60, -18), Vector2(-52, -18), Vector2(-60, 2), Vector2(-52, 2)]:
		blossom_tree(c, Vector3(q.x, 0, q.y), 0.85)
	tiered_fountain(c, Vector3(-56, 0, -8), 0.55, "Tiled Fountain")
	bench(c, Vector3(-56, 0, -3.2), PI)
	bench(c, Vector3(-56, 0, -12.8), 0.0)
	bench(c, Vector3(-61, 0, -8), PI / 2)
	bench(c, Vector3(-51, 0, -8), -PI / 2)
	for q in [Vector2(-64.2, -14), Vector2(-64.2, -2)]:
		planter(c, Vector3(q.x, 0, q.y), Vector2(0.9, 3.2), 0.0, int(q.y))
	moon_banner(c, Vector3(x1 - 0.35, 3.9, -6), -PI / 2, 0.9)
	moon_banner(c, Vector3(x1 - 0.35, 3.9, 6), -PI / 2, 0.9)
	lamp_post(c, Vector3(-48.5, 0, -1.8), true)
	label(c, "Courtyard Garden", Vector3(-56, 5.0, -8), 0.0, 64)


func _palm_grove() -> void:
	# Palms between the courtyard and the maze, with striped hammocks slung between them and soft poufs under them
	var p := node("Palm Grove", school)
	var tops := []
	var spots := [Vector2(-63, 13.5), Vector2(-56, 13), Vector2(-49, 14), Vector2(-62, 21), Vector2(-55, 21.5), Vector2(-48, 20.5)]
	for k in spots.size():
		var s: Vector2 = spots[k]
		tops.append(palm(p, Vector3(s.x, 0, s.y), k * 1.3, 6.5 + (k % 3) * 0.6))
	var cols := [P_PINK, Color(0.7, 0.55, 0.98), Color(0.45, 0.8, 0.95)]
	for k in 3:
		var a: Vector2 = spots[k]
		var b: Vector2 = spots[k + 3]
		hammock(p, Vector3(a.x, 1.9, a.y), Vector3(b.x, 1.9, b.y), cols[k])
	for q in [Vector2(-59.5, 17.5), Vector2(-52.5, 17.0), Vector2(-45.5, 16.0)]:
		var pouf := mesh_at(sphere(0.5, 12), pal("Pouf", P_MAGENTA, 0.95), Vector3(q.x, 0.3, q.y), p)
		pouf.scale = Vector3(1, 0.6, 1)
	mesh_at(cylinder(5.5, 5.5, 0.02, 32), pal("Grove Rug", Color(0.6, 0.5, 0.85), 0.95), Vector3(-55.5, 0.02, 17.2), p)
	label(p, "Palm Grove", Vector3(-55.5, 4.0, 17.2), 0.0, 56)


func _hedge_maze() -> void:
	# The hedge maze south-west of the school, the same every time (a seeded maze over MAZE_N cells), with flowering
	# hedges, a crescent sign at the way in, willow arches to crawl under and a crescent-moon sundial at its heart.
	var m := node("Hedge Maze", school, Vector3(MAZE_AT.x, 0, MAZE_AT.y))
	var nx := MAZE_N.x
	var nz := MAZE_N.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var open := []
	for i in nx * nz:
		open.append([])
	var seen := {}
	var start := Vector2i(nx - 1, 0)
	var stack := [start]
	seen[start] = true
	var dirs := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
	var back := {"n": "s", "s": "n", "e": "w", "w": "e"}
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var options := []
		for d in dirs:
			var nc: Vector2i = c + dirs[d]
			if nc.x >= 0 and nc.y >= 0 and nc.x < nx and nc.y < nz and not seen.has(nc):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: String = options[rng.randi() % options.size()]
		var nc: Vector2i = c + dirs[d]
		open[c.y * nx + c.x].append(d)
		open[nc.y * nx + nc.x].append(back[d])
		seen[nc] = true
		stack.append(nc)
	open[0 * nx + nx - 1].append("e")                   # the way in, facing the forecourt
	open[(nz - 1) * nx + 0].append("w")                 # and a way out onto the cart loop
	var h := 2.6
	var t := 0.8
	var hedge := pal("Hedge", P_HEDGE, 0.95)
	var looks := []
	var flowers := []
	var cell := MAZE_CELL
	var add := func(size: Vector3, pos: Vector3) -> void:
		static_box(m, size, pos)
		looks.append([box(size), xf(pos)])
		for q in int(maxf(size.x, size.z) / 1.1):
			var along := Vector3(1, 0, 0) if size.x > size.z else Vector3(0, 0, 1)
			var off := -maxf(size.x, size.z) / 2 + (q + 0.5) * 1.1
			var side := Vector3(0, 0, 1) if size.x > size.z else Vector3(1, 0, 0)
			var sgn := 1.0 if (q + int(pos.x * 3 + pos.z)) % 2 == 0 else -1.0
			flowers.append([sphere(0.12, 6), xf(pos + along * off + side * sgn * (t / 2 + 0.02) + Vector3(0, fposmod(q * 0.73 + pos.x, 1.6) - 0.4, 0))])
	for cy in nz:
		for cx in nx:
			var o: Array = open[cy * nx + cx]
			var x0 := cx * cell
			var z0 := cy * cell
			if not "n" in o:
				add.call(Vector3(cell + t, h, t), Vector3(x0 + cell / 2, h / 2, z0))
			if not "w" in o:
				add.call(Vector3(t, h, cell + t), Vector3(x0, h / 2, z0 + cell / 2))
			if cy == nz - 1 and not "s" in o:
				add.call(Vector3(cell + t, h, t), Vector3(x0 + cell / 2, h / 2, z0 + cell))
			if cx == nx - 1 and not "e" in o:
				add.call(Vector3(t, h, cell + t), Vector3(x0 + cell, h / 2, z0 + cell / 2))
	merged_at(looks, hedge, m, "Hedges")
	merged_at(flowers, pal("Hedge Flower", Color(0.86, 0.6, 1.0), 0.7, 0.0, 0.3), m, "Hedge Flowers")
	# Willow arches over three of the paths, low enough to feel like crawling through
	var willow := pal("Willow", Color(0.42, 0.6, 0.4), 0.95)
	var arches := []
	for q in [Vector2i(nx - 2, 0), Vector2i(4, 3), Vector2i(1, nz - 1)]:
		var cpos := Vector3((q.x + 0.5) * cell, 0, (q.y + 0.5) * cell)
		for k in 9:
			var a := PI * k / 8.0
			arches.append([sphere(0.45, 8), xf(cpos + Vector3(-cos(a) * 1.3, 1.6 + sin(a) * 0.9, 0), Vector3.ZERO, Vector3(1, 1, 2.4))])
	merged_at(arches, willow, m, "Willow Arches")
	# The heart: a crescent-moon sundial on a little round lawn
	var heart := Vector3((nx / 2 + 0.5) * cell, 0, (nz / 2 + 0.5) * cell)
	solid_cylinder(0.35, 1.0, pal("Palace Trim", P_TRIM, 0.6), heart + Vector3(0, 0.5, 0), m)
	mesh_at(cylinder(0.6, 0.6, 0.08, 20), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), heart + Vector3(0, 1.04, 0), m)
	mesh_at(cylinder(0.4, 0.4, 0.04, 20), pal("Banner Navy", P_NAVY, 0.9), heart + Vector3(0.15, 1.1, 0), m)
	# The sign at the way in, like the picture's
	var sign := node("Maze Sign", m, Vector3(nx * cell + 1.6, 0, 0.3))
	solid_cylinder(0.08, 2.0, pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 1.0, 0), sign)
	moon_banner(sign, Vector3(0, 2.1, 0.1), PI / 2, 0.55)
	label(m, "Hedge Maze", Vector3(nx * cell + 1.6, 3.4, 1.6), 0.0, 56)


# ----------------------------------------------------------------------------- East: quad, studio, stage, pool
func _quad() -> void:
	# The main quad east of the school: a paved plaza with two fountains with sitting ledges, a striped smoothie and
	# coffee cart with tables, puff trees and lamps, and the mural art studio on its east side.
	var q := node("Quad", school)
	var r := QUAD
	solid_box(Vector3(r.size.x, 0.4, r.size.y), pal("Paving", P_PAVING, 0.75), Vector3(r.get_center().x, -0.2, r.get_center().y), q).name = "Quad Paving"
	tiered_fountain(q, Vector3(44, 0, 17), 0.6, "Quad Fountain West")
	tiered_fountain(q, Vector3(60, 0, 17), 0.6, "Quad Fountain East")
	for c in [Vector2(38, -6), Vector2(38, 10), Vector2(52, -6), Vector2(52, 23), Vector2(70, 22)]:
		round_tree(q, Vector3(c.x, 0, c.y), 0.85)
	for c in [Vector2(36, 3), Vector2(52, 10), Vector2(68, 12)]:
		lamp_post(q, Vector3(c.x, 0, c.y), true)
	_smoothie_cart(q, Vector3(52, 0, 3))
	_studio(q)
	label(q, "The Quad", Vector3(52, 5.5, 14), 0.0, 72)


func _smoothie_cart(parent: Node, at: Vector3) -> void:
	var c := node("Smoothie Cart", parent, at, -PI / 2)
	var white := pal("Cart Body", Color(0.95, 0.92, 1.0), 0.4, 0.2)
	solid_box(Vector3(3.0, 1.1, 1.4), white, Vector3(0, 0.75, 0), c)
	mesh_at(box(Vector3(3.1, 0.12, 1.5)), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(0, 1.35, 0), c)
	for s in [-1.0, 1.0]:
		mesh_at(cylinder(0.3, 0.3, 0.16, 14), pal("Tyre", Color(0.12, 0.1, 0.16), 0.9), Vector3(s * 1.0, 0.3, 0.72), c, 0.0, Vector3(PI / 2, 0, 0))
		mesh_at(cylinder(0.04, 0.04, 1.6, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(s * 1.4, 2.2, 0.55), c)
	for k in 6:                                          # the striped awning
		mesh_at(box(Vector3(0.55, 0.06, 1.7)), pal("Awning %d" % (k % 2), P_PINK if k % 2 == 0 else P_TRIM, 0.7),
			Vector3(-1.38 + k * 0.55, 3.0, 0.4), c, 0.0, Vector3(0.25, 0, 0))
	var cups := [Color(0.98, 0.6, 0.8), Color(0.6, 0.9, 0.7), Color(0.8, 0.65, 1.0)]
	for k in 3:
		mesh_at(cylinder(0.09, 0.07, 0.25, 10), pal("Cup %d" % k, cups[k], 0.5), Vector3(-0.6 + k * 0.6, 1.53, 0.4), c)
	label(c, "Smoothies & Coffee", Vector3(0, 3.7, 0.4), 0.0, 48)
	for k in 3:
		var t := node("Cafe Table", parent, at + Vector3(-3.5, 0, -4.5 + k * 4.5))
		solid_cylinder(0.55, 0.06, white, Vector3(0, 0.75, 0), t)
		mesh_at(cylinder(0.05, 0.05, 0.75, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 0.37, 0), t)
		mesh_at(cylinder(0.02, 0.02, 2.0, 6), white, Vector3(0, 1.75, 0), t)
		mesh_at(cylinder(0.0, 1.2, 0.5, 12), pal("Awning 0", P_PINK, 0.7), Vector3(0, 2.7, 0), t)
		for s in [-1.0, 1.0]:
			var stool := mesh_at(cylinder(0.25, 0.25, 0.45, 12), pal("Pouf", P_MAGENTA, 0.95), Vector3(s * 0.85, 0.23, 0), t)
			stool.name = "Stool"


func _studio(parent: Node) -> void:
	# The mural art studio: a little lilac building with its roll-up door wide open onto the quad, paint everywhere
	# inside (on the walls and the floor), easels, a clay table and a big mural on its outside wall
	var s := node("Mural Studio", parent, Vector3(68, 0, -2))
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var w := 12.0
	var d := 14.0
	var h := 4.6
	wall(s, Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), stone, [], h, 0.4)
	wall(s, Vector2(-w / 2, d / 2), Vector2(w / 2, d / 2), stone, [], h, 0.4)
	wall(s, Vector2(w / 2, -d / 2), Vector2(w / 2, d / 2), stone, [], h, 0.4)
	for z in [-d / 2, 2.5]:                              # the west front, with a 4.5 m opening
		var z1: float = (-2.0) if z < 0.0 else d / 2
		wall(s, Vector2(-w / 2, z), Vector2(-w / 2, z1), stone, [], h, 0.4)
	solid_box(Vector3(0.4, h - 3.4, 4.5), stone, Vector3(-w / 2, 3.4 + (h - 3.4) / 2, 0.25), s)
	mesh_at(cylinder(0.35, 0.35, 4.6, 14), pal("Roll Door", Color(0.7, 0.66, 0.85), 0.5, 0.3), Vector3(-w / 2 - 0.2, 3.1, 0.25), s, 0.0, Vector3(PI / 2, 0, 0))
	solid_box(Vector3(w + 0.8, 0.3, d + 0.8), pal("Dome", P_ROOF, 0.45, 0.2), Vector3(0, h + 0.15, 0), s)
	mesh_at(box(Vector3(w, 0.03, d)), pal("Studio Floor", Color(0.92, 0.9, 0.96), 0.8), Vector3(0, 0.015, 0), s)
	# Paint splats: on the floor, the inside walls and the outside wall to the quad
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var cols := [P_PINK, Color(0.45, 0.85, 1.0), Color(1.0, 0.85, 0.35), Color(0.55, 0.95, 0.6), Color(0.7, 0.5, 1.0)]
	var splats := [[], [], [], [], []]
	for k in 60:
		var c: int = rng.randi() % cols.size()
		var r := rng.randf_range(0.15, 0.6)
		var where := rng.randi() % 3
		var tr: Transform3D
		if where == 0:
			tr = xf(Vector3(rng.randf_range(-w / 2 + 0.6, w / 2 - 0.6), 0.035, rng.randf_range(-d / 2 + 0.6, d / 2 - 0.6)))
		elif where == 1:
			tr = xf(Vector3(w / 2 - 0.22, rng.randf_range(0.4, 3.8), rng.randf_range(-d / 2 + 0.5, d / 2 - 0.5)), Vector3(0, 0, PI / 2))
		else:
			tr = xf(Vector3(rng.randf_range(-w / 2 + 0.5, w / 2 - 0.5), rng.randf_range(0.4, 3.8), -d / 2 + 0.22), Vector3(PI / 2, 0, 0))
		splats[c].append([cylinder(r, r, 0.02, 12), tr])
	# The mural on the outside of the north wall, to the quad: a big crescent moon over stripes of colour
	for k in 5:
		splats[k].append([box(Vector3(w - 1.0, 0.7, 0.04)), xf(Vector3(0, 0.6 + k * 0.75, -d / 2 - 0.23))])
	for k in cols.size():
		merged_at(splats[k], pal("Paint %d" % k, cols[k], 0.5, 0.0, 0.15), s, "Paint %d" % k)
	mesh_at(cylinder(1.3, 1.3, 0.05, 32), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(-2.5, 2.6, -d / 2 - 0.27), s, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(cylinder(1.1, 1.1, 0.05, 32), pal("Paint 4", cols[4], 0.5, 0.0, 0.15), Vector3(-2.0, 2.8, -d / 2 - 0.3), s, 0.0, Vector3(PI / 2, 0, 0))
	# Easels and a clay table
	var wood := pal("Easel Wood", Color(0.7, 0.55, 0.62), 0.8)
	for k in 3:
		var e := node("Easel", s, Vector3(-2.5 + k * 2.8, 0, -3.5), 0.2 * (k - 1))
		for sx in [-0.4, 0.4]:
			mesh_at(box(Vector3(0.06, 1.9, 0.06)), wood, Vector3(sx, 0.95, 0), e, 0.0, Vector3(0.12, 0, 0))
		solid_box(Vector3(1.1, 0.8, 0.05), pal("Canvas", Color(0.98, 0.97, 1.0), 0.8), Vector3(0, 1.4, 0.12), e)
		mesh_at(cylinder(0.25, 0.25, 0.02, 12), pal("Paint %d" % k, cols[k], 0.5, 0.0, 0.15), Vector3(0, 1.45, 0.15), e, 0.0, Vector3(PI / 2, 0, 0))
	solid_box(Vector3(3, 0.9, 1.6), wood, Vector3(1.5, 0.45, 3.5), s)
	for k in 4:
		mesh_at(sphere(0.22, 10), pal("Clay", Color(0.75, 0.5, 0.45), 0.9), Vector3(0.6 + k * 0.6, 1.05, 3.5), s)
	var o := OmniLight3D.new()
	o.position = Vector3(0, 3.8, 0)
	o.light_color = Color(1.0, 0.92, 0.95)
	o.omni_range = 10.0
	s.add_child(o)
	label(s, "Mural Studio", Vector3(-w / 2 - 0.8, 5.3, 0.25), 0.0, 56)


func _festival() -> void:
	# From the quad, wide steps go down into a sunken lawn (the stair amphitheater) where the festival stage stands
	# under string lights, with food stalls along the sides.
	var f := node("Festival", school)
	var lawn := pal("Lawn", P_LAWN, 0.95)
	var stone := pal("Palace Stone", P_STONE, 0.8)
	var r := BOWL
	solid_box(Vector3(r.size.x, 0.4, r.size.y), lawn, Vector3(r.get_center().x, BOWL_Y - 0.2, r.get_center().y), f).name = "Bowl Lawn"
	# The steps: eight wide stone steps to look at, a smooth slope under them to walk on
	var n := 8
	var run := STEPS_Z.y - STEPS_Z.x
	var steps := []
	for k in n:
		var top := BOWL_Y * float(k + 1) / n
		var z0 := STEPS_Z.x + run * k / n
		var hh := top - BOWL_Y + 0.02
		steps.append([box(Vector3(r.size.x, hh, run / n)), xf(Vector3(r.get_center().x, BOWL_Y + hh / 2, z0 + run / n / 2))])
	merged_at(steps, stone, f, "Amphitheater Steps")
	var length := sqrt(run * run + BOWL_Y * BOWL_Y)
	static_box(f, Vector3(r.size.x, 0.2, length), Vector3(r.get_center().x, BOWL_Y / 2 - 0.1, (STEPS_Z.x + STEPS_Z.y) / 2), 0.0,
		Vector3(atan2(-BOWL_Y, run), 0, 0)).name = "Steps Slope"
	# The stage at the bowl's far end, a ramp up its west side, an arch behind it and speakers
	var stage_y := BOWL_Y + 1.0
	solid_box(Vector3(20, 1.0, 7), pal("Stage", Color(0.36, 0.3, 0.6), 0.6), Vector3(56, BOWL_Y + 0.5, 52.5), f).name = "Stage"
	mesh_at(box(Vector3(20.2, 0.08, 7.2)), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(56, stage_y + 0.01, 52.5), f)
	static_box(f, Vector3(3.2, 0.2, 3.0), Vector3(44.4, BOWL_Y + 0.42, 52.5), 0.0, Vector3(0, 0, atan2(1.0, 3.0))).name = "Stage Ramp"
	mesh_at(box(Vector3(3.2, 0.2, 3.0)), stone, Vector3(44.4, BOWL_Y + 0.42, 52.5), f, 0.0, Vector3(0, 0, atan2(1.0, 3.0)))
	for s in [-1.0, 1.0]:
		solid_box(Vector3(1.2, 6.0, 1.2), stone, Vector3(56 + s * 9.4, stage_y + 3.0, 55.6), f)
		solid_box(Vector3(1.2, 2.0, 1.0), pal("Speaker", Color(0.15, 0.13, 0.25), 0.6), Vector3(56 + s * 8.0, stage_y + 1.0, 54.8), f)
		mesh_at(cylinder(0.35, 0.35, 0.05, 16), pal("Speaker Cone", Color(0.5, 0.4, 0.9), 0.3, 0.0, 0.8), Vector3(56 + s * 8.0, stage_y + 1.3, 54.28), f, 0.0, Vector3(PI / 2, 0, 0))
	mesh_at(box(Vector3(20, 1.4, 1.2)), stone, Vector3(56, stage_y + 6.7, 55.6), f)
	mesh_at(box(Vector3(17.6, 5.9, 0.2)), pal("Backdrop", Color(0.3, 0.22, 0.55), 0.8), Vector3(56, stage_y + 2.95, 56.2), f)
	moon_banner(f, Vector3(56, stage_y + 5.6, 56.05), 0.0, 1.4)
	# Food stalls down both sides of the bowl
	for k in 2:
		_food_stall(f, Vector3(40.5, BOWL_Y, 39.5 + k * 6.5), PI / 2, k)
		_food_stall(f, Vector3(71.5, BOWL_Y, 39.5 + k * 6.5), -PI / 2, k + 2)
	# String lights across the bowl between poles, and bunting
	var poles := [Vector3(38.6, 0, 34.6), Vector3(73.4, 0, 34.6), Vector3(38.6, 0, 56.4), Vector3(73.4, 0, 56.4)]
	var bulbs := []
	var cords := []
	for p: Vector3 in poles:
		solid_cylinder(0.1, 6.0, pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(p.x, BOWL_Y + 3.0, p.z), f)
	for pair in [[0, 3], [1, 2], [0, 1], [2, 3], [0, 2], [1, 3]]:
		var a: Vector3 = poles[pair[0]] + Vector3(0, BOWL_Y + 5.8, 0)
		var b: Vector3 = poles[pair[1]] + Vector3(0, BOWL_Y + 5.8, 0)
		var m := int(a.distance_to(b) / 1.4)
		for k in m + 1:
			var t := float(k) / m
			var p := a.lerp(b, t) - Vector3(0, sin(PI * t) * 1.2, 0)
			bulbs.append([sphere(0.13, 8), xf(p - Vector3(0, 0.15, 0))])
			if k < m:
				var p2 := a.lerp(b, float(k + 1) / m) - Vector3(0, sin(PI * float(k + 1) / m) * 1.2, 0)
				var mid := (p + p2) / 2
				var dir := (p2 - p).normalized()
				cords.append([box(Vector3(0.03, 0.03, p.distance_to(p2))), Transform3D(Basis.looking_at(dir, Vector3.UP), mid)])
	merged_at(bulbs, pal("Bulb", Color(1.0, 0.88, 0.6), 0.3, 0.0, 3.0), f, "String Lights")
	merged_at(cords, pal("Lamp Iron", P_NAVY, 0.5, 0.5), f, "Cords")
	for p in [Vector3(56, BOWL_Y + 4.0, 45.5), Vector3(46, BOWL_Y + 4.0, 40), Vector3(66, BOWL_Y + 4.0, 40)]:
		var o := OmniLight3D.new()
		o.position = p
		o.light_color = Color(1.0, 0.85, 0.65)
		o.light_energy = 1.0
		o.omni_range = 13.0
		f.add_child(o)
	label(f, "Festival Stage", Vector3(56, stage_y + 8.2, 55.6), 0.0, 72)
	label(f, "Stair Amphitheater", Vector3(56, 2.0, 27.5), 0.0, 48)


func _food_stall(parent: Node, at: Vector3, yaw: float, k: int) -> void:
	var s := node("Food Stall", parent, at, yaw)
	var cols := [P_PINK, Color(0.45, 0.8, 0.95), Color(0.7, 0.55, 0.98), Color(1.0, 0.75, 0.45)]
	solid_box(Vector3(3.0, 1.1, 1.2), pal("Cart Body", Color(0.95, 0.92, 1.0), 0.4, 0.2), Vector3(0, 0.55, 0), s)
	for x in [-1.4, 1.4]:
		mesh_at(cylinder(0.05, 0.05, 2.6, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(x, 1.3, -0.5), s)
		mesh_at(cylinder(0.05, 0.05, 2.6, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(x, 1.3, 0.5), s)
	for j in 6:
		mesh_at(box(Vector3(0.52, 0.06, 1.6)), pal("Stall %d %d" % [k, j % 2], cols[k] if j % 2 == 0 else P_TRIM, 0.7),
			Vector3(-1.3 + j * 0.52, 2.65, 0.15), s, 0.0, Vector3(0.2, 0, 0))
	var foods := ["Moon Pies", "Star Pops", "Comet Corn", "Void Fizz"]
	label(s, foods[k], Vector3(0, 3.2, 0.3), 0.0, 40)


func _pool() -> void:
	# The pool on the east lawn: an oval of glowing blue water, deep enough to swim, set in a lilac paved deck with
	# loungers and sun umbrellas. Its water is a scripts/water.gd like the lake's, so wading and swimming work.
	var p := node("Pool", school)
	var deck := pal("Paving", P_PAVING, 0.75)
	var tile := pal("Pool Tile", Color(0.35, 0.55, 0.85))
	holed_slab(p, "Pool Deck", Rect2(34, -40, 44, 30), POOL, POOL_R, 0.0, 0.4, deck, tile, -POOL_FLOOR)
	solid_box(Vector3(POOL_R.x * 2 + 2, 0.3, POOL_R.y * 2 + 2), tile, Vector3(POOL.x, POOL_FLOOR - 0.15, POOL.y), p).name = "Pool Floor"
	var water := mesh_at(cylinder(1.0, 1.0, 0.05, 48), pal("Pool Water", P_WATER, 0.05, 0.1, 0.6, 0.72), Vector3(POOL.x, POOL_WATER, POOL.y), p)
	water.name = "Pool Surface"
	water.scale = Vector3(POOL_R.x - 0.02, 1, POOL_R.y - 0.02)
	var w := Node3D.new()
	w.name = "Pool Water"
	w.set_script(load("res://scripts/water.gd"))
	var ell: Array[Vector4] = [Vector4(POOL.x, POOL.y, POOL_R.x, POOL_R.y)]
	w.set("ellipses", ell)
	w.set("water_y", POOL_WATER)
	p.add_child(w)
	# A coping ring round the edge, steps down into the shallow west end, a light under the water
	var ring := []
	for k in 64:
		var a := TAU * k / 64.0
		var q := POOL + Vector2(cos(a) * (POOL_R.x + 0.3), sin(a) * (POOL_R.y + 0.3))
		var t := Vector2(-sin(a) * POOL_R.x, cos(a) * POOL_R.y).normalized()
		ring.append([box(Vector3(0.62, 0.06, TAU * POOL_R.x / 64.0 * 1.3)), xf(Vector3(q.x, 0.03, q.y), Vector3(0, atan2(t.x, t.y), 0))])
	merged_at(ring, pal("Palace Trim", P_TRIM, 0.6), p, "Coping")
	for k in 4:
		var y := -0.5 - k * 0.45
		solid_box(Vector3(1.0, 0.2, 3.0), tile, Vector3(POOL.x - POOL_R.x + 1.2 + k * 1.0, y, POOL.y), p).name = "Pool Step"
	var glow := OmniLight3D.new()
	glow.light_color = P_WATER
	glow.light_energy = 1.4
	glow.omni_range = 14.0
	glow.position = Vector3(POOL.x, -1.0, POOL.y)
	p.add_child(glow)
	# Loungers and umbrellas along the north and south sides
	for k in 4:
		for s in [-1.0, 1.0]:
			var at := Vector3(POOL.x - 9 + k * 6, 0, POOL.y + s * (POOL_R.y + 2.6))
			var l := node("Lounger", p, at, 0.0 if s > 0 else PI)
			solid_box(Vector3(0.8, 0.35, 2.0), pal("Cart Body", Color(0.95, 0.92, 1.0), 0.4, 0.2), Vector3(0, 0.2, 0), l)
			mesh_at(box(Vector3(0.75, 0.08, 1.9)), pal("Lounger Pad", P_PINK if k % 2 == 0 else Color(0.5, 0.8, 0.95), 0.9), Vector3(0, 0.42, 0), l)
			mesh_at(box(Vector3(0.75, 0.08, 0.8)), pal("Lounger Pad", Color()), Vector3(0, 0.7, 0.75), l, 0.0, Vector3(-0.7, 0, 0))
			if k % 2 == 0:
				mesh_at(cylinder(0.04, 0.04, 2.6, 6), pal("Cart Body", Color()), at + Vector3(1.3, 1.3, 0), p)
				mesh_at(cylinder(0.0, 1.6, 0.6, 12), pal("Awning %d" % (k / 2 % 2), P_PINK, 0.7), at + Vector3(1.3, 2.6, 0), p)
	label(p, "Pool", Vector3(POOL.x, 3.5, POOL.y), 0.0, 64)


# ----------------------------------------------------------------------------- Inside
func _library_atrium() -> void:
	# The library is open up through floor 2 now (the hole in floor 2's slab, _shell): its shelves go up two tiers,
	# floor 2's gallery rings the hole with a glass balustrade, banners hang into it and a chandelier of glowing
	# crystals hangs in the middle from floor 3's ceiling.
	var a := node("Library Atrium", school)
	var c := Vector3(LIBRARY_AT.x, 0, LIBRARY_AT.y)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var glass := pal("Rail Glass", Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.2, 0.3)
	# The gallery's glass balustrade round the hole, solid
	var n := 48
	var rails := []
	var panes := []
	for k in n:
		var t0 := TAU * k / n
		var t1 := TAU * (k + 1) / n
		var p0 := Vector2(cos(t0) * LIBRARY_HOLE.x, sin(t0) * LIBRARY_HOLE.y) + LIBRARY_AT
		var p1 := Vector2(cos(t1) * LIBRARY_HOLE.x, sin(t1) * LIBRARY_HOLE.y) + LIBRARY_AT
		var mid := (p0 + p1) / 2
		var yaw := atan2(p1.x - p0.x, p1.y - p0.y)
		if absf(p0.x) < BRIDGE_HALF - 0.01 or absf(p1.x) < BRIDGE_HALF - 0.01:
			continue                                  # open where the skybridge meets the gallery (_skybridge)
		static_box(a, Vector3(0.2, 1.15, p0.distance_to(p1) + 0.05), Vector3(mid.x, FLOOR_H + 0.575, mid.y), yaw)
		panes.append([box(Vector3(0.04, 0.95, p0.distance_to(p1))), xf(Vector3(mid.x, FLOOR_H + 0.55, mid.y), Vector3(0, yaw, 0))])
		rails.append([box(Vector3(0.14, 0.1, p0.distance_to(p1) + 0.06)), xf(Vector3(mid.x, FLOOR_H + 1.12, mid.y), Vector3(0, yaw, 0))])
		rails.append([cylinder(0.04, 0.04, 1.1, 6), xf(Vector3(p0.x, FLOOR_H + 0.55, p0.y))])
		# the slab's edge, a pale band you see from below
		rails.append([box(Vector3(0.1, 0.34, p0.distance_to(p1) + 0.06)), xf(Vector3(mid.x, FLOOR_H - 0.15, mid.y), Vector3(0, yaw, 0))])
	merged_at(panes, glass, a, "Gallery Glass")
	merged_at(rails, gold, a, "Gallery Rail")
	# The chandelier: rings of glowing crystals under floor 3's slab
	var ch := node("Chandelier", a, c + Vector3(0, 2 * FLOOR_H - 0.3, 0))
	var crystals := []
	for ring in 3:
		var r := 2.6 - ring * 0.8
		var y := -1.0 - ring * 0.9
		crystals.append([cylinder(r, r, 0.08, 32), xf(Vector3(0, y, 0))])
		for k in int(r * 6):
			var t := TAU * k / int(r * 6)
			crystals.append([cylinder(0.0, 0.1, 0.45, 5), xf(Vector3(cos(t) * r, y - 0.3, sin(t) * r), Vector3(PI, 0, 0))])
	crystals.append([cylinder(0.0, 0.5, 1.0, 6), xf(Vector3(0, -3.0, 0), Vector3(PI, 0, 0))])
	merged_at(crystals, pal("Chandelier Glow", Color(1.0, 0.86, 0.95), 0.2, 0.2, 1.8), ch, "Crystals")
	for k in 4:
		mesh_at(cylinder(0.02, 0.02, 1.0, 4), gold, Vector3(cos(k * PI / 2) * 2.6, -0.5, sin(k * PI / 2) * 2.6), ch)
	var o := OmniLight3D.new()
	o.position = Vector3(0, -3.0, 0)
	o.light_color = Color(1.0, 0.82, 0.92)
	o.light_energy = 1.6
	o.omni_range = 16.0
	ch.add_child(o)
	# Banners hanging into the open middle from floor 3's slab, at the hole's four sides
	for k in 4:
		var t := TAU * k / 4.0 + PI / 4
		var q := Vector2(cos(t) * (LIBRARY_HOLE.x - 1.2), sin(t) * (LIBRARY_HOLE.y - 1.0)) + LIBRARY_AT
		moon_banner(a, Vector3(q.x, 2 * FLOOR_H - 0.6, q.y), atan2(cos(t), sin(t)), 1.4)
	# Reading benches and lamps round the gallery
	for k in 6:
		var t := TAU * k / 6.0 + PI / 6
		var q := Vector2(cos(t) * (LIBRARY_HOLE.x + 1.6), sin(t) * (LIBRARY_HOLE.y + 1.4)) + LIBRARY_AT
		if absf(q.x) < 3.0 and q.y > 0.0:
			continue
		bench(a, Vector3(q.x, FLOOR_H, q.y), atan2(-cos(t), -sin(t)))
	for q in [Vector2(-12.6, -6), Vector2(-4.6, -13.6)]:
		var p := node("Gallery Plant", a, Vector3(q.x, FLOOR_H, q.y))
		mesh_at(cylinder(0.45, 0.35, 0.7, 12), pal("Planter", P_PLANTER, 0.8), Vector3(0, 0.35, 0), p)
		mesh_at(sphere(0.75, 10), pal("Planter Leaf", Color(0.25, 0.55, 0.32), 0.9), Vector3(0, 1.2, 0), p)
	label(a, "Library Gallery", Vector3(0, FLOOR_H + 3.6, LIBRARY_AT.y - LIBRARY_HOLE.y - 1.5), 0.0, 64)


func _music_pods() -> void:
	# The music practice pods, tucked in the south-east corner of floor 1 (by the foyer and the lower lockers): four
	# round glass pods, each glowing its own colour with an instrument inside and a note over it, guitars on the wall,
	# a music stand, a shelf of music books and a crescent banner, like the picture.
	var m := node("Music Pods", school)
	var cols := [Color(0.45, 0.82, 1.0), Color(0.6, 0.55, 1.0), Color(0.98, 0.45, 0.8), Color(0.45, 0.9, 0.95)]
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var trim := pal("Palace Trim", P_TRIM, 0.6)
	for k in 4:
		var at := Vector3(17.6 + k * 3.55, 0, 20.6)
		var pod := node("Pod %d" % (k + 1), m, at)
		var glass := pal("Pod Glass %d" % k, cols[k], 0.05, 0.0, 0.7, 0.45)
		var r := 1.45
		var segs := 14
		var panes := []
		for j in segs:
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			if j == 10 or j == 11:                        # the doorway, facing north into the room
				continue
			var p0 := Vector2(cos(t0), sin(t0)) * r
			var p1 := Vector2(cos(t1), sin(t1)) * r
			var mid := (p0 + p1) / 2
			var yaw := atan2(p1.x - p0.x, p1.y - p0.y)
			static_box(pod, Vector3(0.08, 2.9, p0.distance_to(p1)), Vector3(mid.x, 1.45, mid.y), yaw)
			panes.append([box(Vector3(0.05, 2.9, p0.distance_to(p1) + 0.02)), xf(Vector3(mid.x, 1.45, mid.y), Vector3(0, yaw, 0))])
		merged_at(panes, glass, pod, "Glass")
		mesh_at(cylinder(r + 0.12, r + 0.12, 0.3, 28), trim, Vector3(0, 3.05, 0), pod)
		mesh_at(cylinder(r + 0.1, r + 0.1, 0.06, 28), pal("Pod Rug %d" % k, cols[k].darkened(0.3), 0.95), Vector3(0, 0.03, 0), pod)
		mesh_at(cylinder(0.25, 0.3, 0.3, 12), gold, Vector3(0, 3.35, 0), pod)
		mesh_at(sphere(0.18, 8), pal("Lamp Glow", P_GLOW, 0.3, 0.0, 2.2), Vector3(0, 3.6, 0), pod)
		var note := Label3D.new()
		note.name = "Note"
		note.text = "♪" if k % 2 == 0 else "♫"
		note.font_size = 220
		note.pixel_size = 0.006
		note.modulate = Color(1, 1, 1, 0.95)
		note.outline_size = 0
		note.position = Vector3(0, 1.9, 0)
		note.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		pod.add_child(note)
		var o := OmniLight3D.new()
		o.light_color = cols[k]
		o.light_energy = 0.9
		o.omni_range = 4.0
		o.position = Vector3(0, 2.4, 0)
		pod.add_child(o)
		_instrument(pod, k)
	# Guitars on the east wall, a music stand, a bookshelf, a stool and plants
	for k in 3:
		var gpos := Vector3(X_E - 0.35, 2.0 + (k % 2) * 0.25, 13.0 + k * 1.2)
		var g := node("Guitar", m, gpos, -PI / 2)
		var wood := pal("Guitar Wood", Color(0.78, 0.45, 0.32) if k != 1 else Color(0.95, 0.75, 0.55), 0.5)
		for b in [[0.0, 0.36], [0.45, 0.28]]:
			var body := mesh_at(cylinder(float(b[1]), float(b[1]), 0.14, 18), wood, Vector3(0, -0.5 + float(b[0]), 0), g, 0.0, Vector3(PI / 2, 0, 0))
			body.name = "Body"
		mesh_at(box(Vector3(0.08, 0.9, 0.05)), pal("Guitar Neck", Color(0.35, 0.22, 0.2), 0.6), Vector3(0, 0.45, 0.02), g)
		mesh_at(cylinder(0.09, 0.09, 0.15, 12), pal("Banner Navy", P_NAVY, 0.9), Vector3(0, -0.5, 0.06), g, 0.0, Vector3(PI / 2, 0, 0))
	var stand := node("Music Stand", m, Vector3(26.5, 0, 15.5), 0.6)
	mesh_at(cylinder(0.03, 0.03, 1.3, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 0.65, 0), stand)
	mesh_at(box(Vector3(0.6, 0.4, 0.04)), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 1.35, 0), stand, 0.0, Vector3(-0.4, 0, 0))
	var shelf := node("Music Shelf", m, Vector3(X_E - 0.5, 0, 11.6), -PI / 2)
	solid_box(Vector3(2.4, 2.4, 0.5), pal("Bookshelf Navy", P_NAVY, 0.8), Vector3(0, 1.2, 0), shelf)
	var books := [[], [], []]
	var bc := [P_PINK, Color(0.45, 0.82, 1.0), Color(1.0, 0.85, 0.4)]
	for row in 4:
		for k in 10:
			books[(row + k) % 3].append([box(Vector3(0.18, 0.42, 0.36)), xf(Vector3(-1.0 + k * 0.22, 0.35 + row * 0.55, 0.1))])
	for k in 3:
		merged_at(books[k], pal("Book %d" % k, bc[k], 0.7), shelf, "Books %d" % k)
	var stool := mesh_at(cylinder(0.3, 0.25, 0.5, 12), pal("Pouf", P_MAGENTA, 0.95), Vector3(16.5, 0.25, 15.8), m)
	stool.name = "Stool"
	moon_banner(m, Vector3(X_E - 0.15, 4.6, 18.0), -PI / 2, 1.0)
	label(m, "Music Pods", Vector3(22.9, 4.3, 17.6), 0.0, 72)


func _instrument(pod: Node3D, k: int) -> void:
	# Something to play in each pod: an upright piano, a drum kit, a harp, a keyboard and stool
	var dark := pal("Instrument Dark", Color(0.18, 0.15, 0.3), 0.4, 0.2)
	var keys := pal("Piano Keys", Color(0.97, 0.96, 1.0), 0.4)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	match k:
		0:
			solid_box(Vector3(1.4, 1.3, 0.55), dark, Vector3(0, 0.65, 0.65), pod)
			mesh_at(box(Vector3(1.3, 0.06, 0.25)), keys, Vector3(0, 0.78, 0.3), pod)
			mesh_at(box(Vector3(0.7, 0.45, 0.4)), pal("Pouf", P_MAGENTA, 0.95), Vector3(0, 0.23, -0.35), pod)
		1:
			for d in [[Vector3(0, 0.35, 0.5), 0.45, 0.5], [Vector3(-0.6, 0.55, 0.2), 0.25, 0.3], [Vector3(0.6, 0.55, 0.2), 0.28, 0.3],
					[Vector3(-0.7, 0.4, 0.7), 0.3, 0.6]]:
				mesh_at(cylinder(float(d[1]), float(d[1]), float(d[2]), 16), pal("Drum", Color(0.95, 0.55, 0.85), 0.5), d[0], pod)
			mesh_at(cylinder(0.35, 0.35, 0.02, 16), gold, Vector3(0.75, 1.2, 0.6), pod)
			mesh_at(cylinder(0.02, 0.02, 1.2, 6), dark, Vector3(0.75, 0.6, 0.6), pod)
		2:
			var harp := node("Harp", pod, Vector3(0, 0, 0.4))
			mesh_at(box(Vector3(0.12, 1.7, 0.12)), gold, Vector3(-0.35, 0.85, 0), harp, 0.0, Vector3(0, 0, -0.15))
			mesh_at(box(Vector3(0.8, 0.12, 0.12)), gold, Vector3(0.0, 1.6, 0), harp, 0.0, Vector3(0, 0, -0.35))
			for j in 7:
				mesh_at(cylinder(0.008, 0.008, 1.1 - j * 0.1, 4), keys, Vector3(-0.25 + j * 0.08, 0.75 + j * 0.06, 0), harp)
		_:
			solid_box(Vector3(1.3, 0.12, 0.4), dark, Vector3(0, 0.85, 0.45), pod)
			mesh_at(box(Vector3(1.2, 0.03, 0.2)), keys, Vector3(0, 0.92, 0.4), pod)
			for x in [-0.5, 0.5]:
				mesh_at(box(Vector3(0.05, 0.85, 0.05)), dark, Vector3(x, 0.42, 0.45), pod, 0.0, Vector3(0, 0, 0.3 * signf(x)))
			mesh_at(cylinder(0.25, 0.25, 0.5, 12), pal("Pouf", P_MAGENTA, 0.95), Vector3(0, 0.25, -0.3), pod)


func _foyer_dressing() -> void:
	# The foyer, as a palace hall: a round rug, a chandelier, crescent banners, palms in pots and lanterns by the doors
	var f := node("Foyer Dressing", school)
	mesh_at(cylinder(5.5, 5.5, 0.03, 40), pal("Foyer Rug", Color(0.55, 0.42, 0.85), 0.95), Vector3(0, 0.02, 18.5), f)
	mesh_at(cylinder(4.6, 4.6, 0.035, 40), pal("Foyer Rug Inner", Color(0.72, 0.6, 0.95), 0.95), Vector3(0, 0.025, 18.5), f)
	var ch := node("Foyer Chandelier", f, Vector3(0, FLOOR_H - 0.3, 18.5))
	var parts := []
	for ring in 2:
		var r := 1.5 - ring * 0.6
		parts.append([cylinder(r, r, 0.06, 24), xf(Vector3(0, -0.6 - ring * 0.6, 0))])
		for k in int(r * 6):
			var t := TAU * k / int(r * 6)
			parts.append([cylinder(0.0, 0.08, 0.35, 5), xf(Vector3(cos(t) * r, -0.85 - ring * 0.6, sin(t) * r), Vector3(PI, 0, 0))])
	merged_at(parts, pal("Chandelier Glow", Color(1.0, 0.86, 0.95), 0.2, 0.2, 1.8), ch, "Crystals")
	for s in [-1.0, 1.0]:
		moon_banner(f, Vector3(s * 13.8, 4.8, 17.0), -s * PI / 2, 1.1)
		var pot := node("Potted Palm", f, Vector3(s * 3.6, 0, 22.6))
		mesh_at(cylinder(0.45, 0.35, 0.7, 12), pal("Planter", P_PLANTER, 0.8), Vector3(0, 0.35, 0), pot)
		var plant := node("Plant", pot, Vector3(0, 0.6, 0))
		plant.scale = Vector3.ONE * 0.4
		palm(plant, Vector3.ZERO, s, 5.0)
	moon_banner(f, Vector3(0, 5.2, 10.35), 0.0, 1.2)


func _player() -> void:
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 1.0, Z_S + 13)
	school.add_child(player)
	player.owner = school


# ----------------------------------------------------------------------------- Slice 2: floors 2 and 3
func _skybridge() -> void:
	# A glass bridge straight across the open library on floor 2, north to south, between the gallery's two sides: a
	# shortcut with the library glowing below and the chandelier overhead.
	var b := node("Skybridge", school)
	var x := BRIDGE_HALF
	var z0 := LIBRARY_AT.y - LIBRARY_HOLE.y - 0.6
	var z1 := LIBRARY_AT.y + LIBRARY_HOLE.y + 0.6
	var glass := pal("Bridge Glass", Color(0.78, 0.9, 1.0), 0.05, 0.0, 0.25, 0.45)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var rail_glass := pal("Rail Glass", Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.2, 0.3)
	static_box(b, Vector3(2 * x, 0.2, z1 - z0), Vector3(0, FLOOR_H - 0.1, (z0 + z1) / 2)).name = "Bridge Deck"
	mesh_at(box(Vector3(2 * x, 0.12, z1 - z0)), glass, Vector3(0, FLOOR_H - 0.06, (z0 + z1) / 2), b)
	# its edges, a gold frame under the glass, and a pale strip down the middle to walk along
	var frame := []
	for sx in [-1.0, 1.0]:
		frame.append([box(Vector3(0.2, 0.3, z1 - z0)), xf(Vector3(sx * (x - 0.1), FLOOR_H - 0.2, (z0 + z1) / 2))])
	for k in 7:
		frame.append([box(Vector3(2 * x, 0.12, 0.12)), xf(Vector3(0, FLOOR_H - 0.16, lerpf(z0, z1, k / 6.0)))])
	merged_at(frame, gold, b, "Bridge Frame")
	mesh_at(box(Vector3(1.2, 0.02, z1 - z0)), pal("Bridge Runner", Color(0.93, 0.8, 1.0), 0.6, 0.0, 0.3), Vector3(0, FLOOR_H + 0.01, (z0 + z1) / 2), b)
	# Railings along both sides, from where the gallery's rail stops to where it starts again
	var rz := LIBRARY_HOLE.y * sqrt(1.0 - (x / LIBRARY_HOLE.x) * (x / LIBRARY_HOLE.x))
	var ra := LIBRARY_AT.y - rz
	var rb := LIBRARY_AT.y + rz
	var rails := []
	var panes := []
	for sx in [-1.0, 1.0]:
		static_box(b, Vector3(0.2, 1.15, rb - ra), Vector3(sx * x, FLOOR_H + 0.575, (ra + rb) / 2))
		panes.append([box(Vector3(0.04, 0.95, rb - ra)), xf(Vector3(sx * x, FLOOR_H + 0.55, (ra + rb) / 2))])
		rails.append([box(Vector3(0.14, 0.1, rb - ra + 0.06)), xf(Vector3(sx * x, FLOOR_H + 1.12, (ra + rb) / 2))])
		for k in 9:
			rails.append([cylinder(0.04, 0.04, 1.1, 6), xf(Vector3(sx * x, FLOOR_H + 0.55, lerpf(ra, rb, k / 8.0)))])
	merged_at(panes, rail_glass, b, "Bridge Glass Rail")
	merged_at(rails, gold, b, "Bridge Rail")
	# Little glowing studs in the deck, so it sparkles from below
	var studs := []
	for k in 12:
		for sx in [-1.0, 1.0]:
			studs.append([cylinder(0.07, 0.07, 0.03, 8), xf(Vector3(sx * (x - 0.45), FLOOR_H + 0.01, lerpf(z0 + 0.5, z1 - 0.5, k / 11.0)))])
	merged_at(studs, pal("Bridge Stud", Color(0.75, 0.9, 1.0), 0.3, 0.0, 2.0), b, "Bridge Lights")
	label(b, "Skybridge", Vector3(0, FLOOR_H + 2.6, z1 - 0.8), 0.0, 56)


func _floor_2_extras() -> void:
	var f := school.get_node("Floor 2") as Node3D
	# The library mezzanine: a reading nook on the gallery south of the hole, with beanbags, a lamp and low shelves,
	# looking down into the library over the glass rail.
	var m := node("Library Mezzanine", f, Vector3(-7.2, 0, 2.6))
	solid_box(Vector3(6.0, 0.04, 3.4), pal("Mezzanine Rug", Color(0.55, 0.38, 0.85), 0.95), Vector3(0, 0.02, 0), m)
	var bags := [P_PINK, Color(0.45, 0.82, 1.0), Color(1.0, 0.85, 0.4), Color(0.7, 0.55, 1.0)]
	for k in 4:
		var bb := mesh_at(sphere(0.6, 12), pal("Beanbag %d" % k, bags[k], 0.95), Vector3(-2.2 + k * 1.45, 0.38, -0.6 + 0.4 * (k % 2)), m)
		bb.scale = Vector3(1.1, 0.62, 1.0)
	var shelf := pal("Library Shelf", P_NAVY, 0.7)
	solid_box(Vector3(5.6, 1.1, 0.5), shelf, Vector3(0, 0.55, 1.95), m)
	var books := []
	for k in 14:
		books.append([box(Vector3(0.3, 0.42 + 0.08 * (k % 3), 0.4)), xf(Vector3(-2.6 + k * 0.4, 1.3, 1.95))])
	merged_at(books, pal("Book 0", P_PINK, 0.7), m, "Books")
	mesh_at(cylinder(0.04, 0.04, 1.6, 6), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(2.7, 0.8, 1.2), m)
	mesh_at(cylinder(0.18, 0.32, 0.36, 12), pal("Lamp Glow", P_GLOW, 0.3, 0.0, 2.2), Vector3(2.7, 1.7, 1.2), m)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(2.7, 1.8, 1.0)
	lamp.light_color = Color(1.0, 0.82, 0.62)
	lamp.light_energy = 0.8
	lamp.omni_range = 5.0
	m.add_child(lamp)
	label(m, "Library Mezzanine", Vector3(0, 2.4, 0), 0.0, 48)

	# The Nova Lab: classroom A fitted out as an inventor's lab, benches of bubbling glass and blinking panels.
	var lab := node("Nova Lab Kit", f)
	var bench_mat := pal("Lab Bench", Color(0.95, 0.94, 1.0), 0.5)
	var top_mat := pal("Lab Top", P_NAVY, 0.4, 0.2)
	var fluids := [pal("Lab Fluid Pink", P_PINK, 0.2, 0.0, 1.4, 0.8), pal("Lab Fluid Cyan", Color(0.4, 0.95, 1.0), 0.2, 0.0, 1.4, 0.8),
		pal("Lab Fluid Lime", Color(0.65, 1.0, 0.45), 0.2, 0.0, 1.4, 0.8), pal("Lab Fluid Gold", Color(1.0, 0.8, 0.35), 0.2, 0.0, 1.4, 0.8)]
	var flask_glass := pal("Lab Glass", Color(0.85, 0.95, 1.0), 0.05, 0.0, 0.0, 0.35)
	for bz in [-16.5, -12.5]:
		solid_box(Vector3(9.0, 0.95, 1.2), bench_mat, Vector3(-18.5, 0.475, bz), lab)
		mesh_at(box(Vector3(9.1, 0.06, 1.3)), top_mat, Vector3(-18.5, 0.98, bz), lab)
		for k in 8:
			var at := Vector3(-22.3 + k * 1.1, 1.01, bz + (0.2 if k % 2 == 0 else -0.2))
			var h := 0.3 + 0.12 * (k % 3)
			mesh_at(cylinder(0.11, 0.16, h, 10), fluids[k % 4], at + Vector3(0, h / 2, 0), lab)
			mesh_at(cylinder(0.05, 0.19, h + 0.25, 10), flask_glass, at + Vector3(0, (h + 0.25) / 2, 0), lab)
			for q in 2:
				mesh_at(sphere(0.04 + 0.02 * q, 6), flask_glass, at + Vector3(0.03 * q, h + 0.35 + 0.18 * q, 0), lab)
	# a wall of blinking lights and dials on the west wall, and a glowing coil in the corner
	var panel := node("Lab Panel", lab, Vector3(-25.75, 0, -14.0), PI / 2)
	solid_box(Vector3(6.0, 2.8, 0.3), pal("Lab Panel", Color(0.25, 0.2, 0.42), 0.5, 0.3), Vector3(0, 1.6, 0), panel)
	var lights := [[], [], []]
	for r in 4:
		for c in 12:
			lights[(r * 5 + c * 3) % 3].append([sphere(0.07, 6), xf(Vector3(-2.6 + c * 0.47, 2.6 - r * 0.3, 0.17))])
	merged_at(lights[0], pal("Lab Light Red", Color(1.0, 0.4, 0.55), 0.3, 0.0, 2.5), panel, "Lights A")
	merged_at(lights[1], pal("Lab Light Green", Color(0.5, 1.0, 0.6), 0.3, 0.0, 2.5), panel, "Lights B")
	merged_at(lights[2], pal("Lab Light Blue", Color(0.45, 0.8, 1.0), 0.3, 0.0, 2.5), panel, "Lights C")
	for c in 4:
		mesh_at(cylinder(0.28, 0.28, 0.06, 18), pal("Lab Dial", Color(0.95, 0.93, 1.0), 0.4), Vector3(-2.1 + c * 1.4, 1.05, 0.17), panel, 0.0, Vector3(PI / 2, 0, 0))
	var coil := node("Nova Coil", lab, Vector3(-24.5, 0, -10.5))
	solid_cylinder(0.45, 1.0, pal("Lab Top", P_NAVY, 0.4, 0.2), Vector3(0, 0.5, 0), coil)
	for k in 8:
		mesh_at(cylinder(0.32, 0.32, 0.06, 16), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(0, 1.1 + k * 0.14, 0), coil)
	mesh_at(sphere(0.38, 14), pal("Coil Glow", Color(0.75, 0.6, 1.0), 0.2, 0.0, 2.8), Vector3(0, 2.4, 0), coil)
	var spark := OmniLight3D.new()
	spark.position = Vector3(0, 2.4, 0)
	spark.light_color = Color(0.75, 0.6, 1.0)
	spark.light_energy = 1.2
	spark.omni_range = 6.0
	coil.add_child(spark)

	# The gadget wall beside the west break corner: screens, switches and dials to press and turn
	var g := node("Gadget Wall", f, Vector3(X_W + 0.3, 0, 12.5), PI / 2)   # between the two west break corners
	solid_box(Vector3(6.4, 2.6, 0.25), pal("Gadget Board", Color(0.35, 0.3, 0.6), 0.5, 0.2), Vector3(0, 1.5, 0), g)
	var screens := [Color(0.45, 0.95, 1.0), P_PINK, Color(1.0, 0.85, 0.4), Color(0.65, 1.0, 0.5)]
	for k in 4:
		mesh_at(box(Vector3(1.2, 0.8, 0.06)), pal("Gadget Screen %d" % k, screens[k], 0.2, 0.0, 1.6), Vector3(-2.3 + k * 1.53, 2.15, 0.15), g)
	var buttons := [[], []]
	for k in 10:
		buttons[k % 2].append([cylinder(0.12, 0.12, 0.08, 12), xf(Vector3(-2.7 + k * 0.6, 1.2, 0.16), Vector3(PI / 2, 0, 0))])
	merged_at(buttons[0], pal("Gadget Button A", P_MAGENTA, 0.4, 0.0, 1.0), g, "Buttons A")
	merged_at(buttons[1], pal("Gadget Button B", Color(0.45, 0.95, 1.0), 0.4, 0.0, 1.0), g, "Buttons B")
	var switches := []
	for k in 8:
		switches.append([box(Vector3(0.08, 0.3, 0.08)), xf(Vector3(-2.4 + k * 0.7, 0.75, 0.2), Vector3(0.4 if k % 2 == 0 else -0.4, 0, 0))])
	merged_at(switches, pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), g, "Switches")
	label(g, "Gadget Wall", Vector3(0, 3.2, 0.3), 0.0, 48)


func _floor_3_extras() -> void:
	var f := school.get_node("Floor 3") as Node3D
	# Window seats: cushioned benches along the window wall, with pillows, looking out over the Void
	var seat := node("Window Seats", f)
	var base := pal("Seat Base", Color(0.93, 0.9, 1.0), 0.6)
	var cushion := pal("Seat Cushion", Color(0.6, 0.42, 0.9), 0.95)
	var pillows := [P_PINK, Color(0.45, 0.82, 1.0), Color(1.0, 0.85, 0.4)]
	for span: Vector2 in [Vector2(-17, -9), Vector2(-3.5, 3.5), Vector2(9, 17)]:
		var mid := (span.x + span.y) / 2
		var w := span.y - span.x
		solid_box(Vector3(w, 0.5, 0.9), base, Vector3(mid, 0.25, Z_N + 0.95), seat)
		mesh_at(box(Vector3(w - 0.1, 0.16, 0.8)), cushion, Vector3(mid, 0.58, Z_N + 0.95), seat)
		for k in int(w / 1.6):
			var px := span.x + 0.8 + k * 1.6
			var pill := mesh_at(sphere(0.28, 10), pal("Pillow %d" % (k % 3), pillows[k % 3], 0.95), Vector3(px, 0.82, Z_N + 0.7), seat)
			pill.scale = Vector3(1.2, 0.8, 0.5)
	label(seat, "Window Seats", Vector3(0, 2.2, Z_N + 1.6), 0.0, 48)


func _hidden_stair() -> void:
	# A narrow spiral stair inside floor 3's secret hallway, winding down two turns to Behind the Walls on floor 2:
	# the two hidden routes join up. (The lower level it will reach later is still to be built.)
	var s := node("Hidden Stair", school, Vector3(HIDDEN_STAIR.x, 0, HIDDEN_STAIR.y))
	var stone := pal("Hidden Stone", Color(0.55, 0.5, 0.7), 0.9)
	var turns := 2.0
	var steps := 36
	var top := 2 * FLOOR_H
	var bottom := FLOOR_H
	var start := PI / 2                             # the top step leaves floor 3 on the south side, along the hallway
	var inner := 0.22
	# Walking surface: a smooth helix (a stair you can't trip on), steps drawn on top of it
	var faces := PackedVector3Array()
	var n := steps * 3
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var a0 := start + TAU * turns * t0
		var a1 := start + TAU * turns * t1
		var y0 := lerpf(top, bottom, t0) - 0.02
		var y1 := lerpf(top, bottom, t1) - 0.02
		var i0 := Vector3(cos(a0) * inner, y0, sin(a0) * inner)
		var o0 := Vector3(cos(a0) * STAIR_R, y0, sin(a0) * STAIR_R)
		var i1 := Vector3(cos(a1) * inner, y1, sin(a1) * inner)
		var o1 := Vector3(cos(a1) * STAIR_R, y1, sin(a1) * STAIR_R)
		faces.append_array(PackedVector3Array([i0, o0, o1, i0, o1, i1]))
	var body := StaticBody3D.new()
	body.name = "Stair Ramp"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	s.add_child(body)
	var treads := []
	for k in steps:
		var a := start + TAU * turns * (k + 0.5) / steps
		var y := lerpf(top, bottom, (k + 0.5) / steps)
		var mid := (inner + STAIR_R) / 2
		treads.append([box(Vector3(STAIR_R - inner, 0.12, 0.42)), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * mid, y - 0.08, sin(a) * mid))])
	merged_at(treads, stone, s, "Steps")
	solid_cylinder(inner, top - bottom + 1.0, stone, Vector3(0, (top + bottom) / 2 + 0.5, 0), s)
	# a dim glow on the way down, and a rail round the hole up on floor 3 except where the top step leaves
	for y in [bottom + 1.8, (top + bottom) / 2 + 1.5]:
		var o := OmniLight3D.new()
		o.position = Vector3(0, y, 0)
		o.light_color = Color(0.7, 0.55, 1.0)
		o.light_energy = 0.6
		o.omni_range = 4.0
		s.add_child(o)
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var posts := []
	for k in 12:
		var a0 := start + PI / 3 + (TAU - PI / 3 - 0.2) * k / 12.0
		var a1 := start + PI / 3 + (TAU - PI / 3 - 0.2) * (k + 1) / 12.0
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (STAIR_R + 0.15)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (STAIR_R + 0.15)
		var mid := (p0 + p1) / 2
		static_box(s, Vector3(0.1, 1.0, p0.distance_to(p1) + 0.05), Vector3(mid.x, top + 0.5, mid.z), atan2(p1.x - p0.x, p1.z - p0.z))
		posts.append([box(Vector3(0.08, 0.08, p0.distance_to(p1) + 0.05)), Transform3D(Basis(Vector3.UP, atan2(p1.x - p0.x, p1.z - p0.z)), mid + Vector3(0, top + 1.0, 0))])
		posts.append([cylinder(0.03, 0.03, 1.0, 6), xf(p0 + Vector3(0, top + 0.5, 0))])
	merged_at(posts, gold, s, "Rail")


# ----------------------------------------------------------------------------- The roof (slice 3)
func _roof() -> void:
	# Up on the roof, reached by the escalators through the atrium: the 4th floor's Sky Pavilion (the upper commons
	# and the magic-craft pods), the palm terrace with loungers, hammocks and string lights, and the roof garden with
	# its gazebo and telescope. The balustrade round the edge is the palace's (_roof_edge).
	var r := node("Floor 4", school, Vector3(0, ROOF_Y, 0))
	label(r, "Roof", Vector3(-30, 3.6, 21), 0.0, 80)
	# A rail round the opening the escalators come up through, open at the end they arrive at
	var rh := ROOF_HOLE
	var gold := pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35)
	var rails := []
	for e: Array in [[Vector2(rh.position.x, rh.position.y), Vector2(rh.end.x, rh.position.y)],
			[Vector2(rh.position.x, rh.position.y), Vector2(rh.position.x, rh.end.y)],
			[Vector2(rh.end.x, rh.position.y), Vector2(rh.end.x, rh.end.y)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var mid := (a + b) / 2
		var yaw := atan2(b.x - a.x, b.y - a.y)
		static_box(r, Vector3(0.12, 1.1, a.distance_to(b)), Vector3(mid.x, 0.55, mid.y), yaw)
		rails.append([box(Vector3(0.12, 0.1, a.distance_to(b))), xf(Vector3(mid.x, 1.1, mid.y), Vector3(0, yaw, 0))])
		for k in int(a.distance_to(b) / 1.2) + 1:
			var q := a.lerp(b, k * 1.2 / a.distance_to(b))
			rails.append([cylinder(0.035, 0.035, 1.1, 6), xf(Vector3(q.x, 0.55, q.y))])
	merged_at(rails, gold, r, "Opening Rail")
	# A pale path from the escalators to everything up here
	var path := pal("Roof Path", Color(0.93, 0.89, 0.99), 0.7)
	var paths := [[box(Vector3(30, 0.04, 2.4)), xf(Vector3(-18, 0.02, 21))], [box(Vector3(2.4, 0.04, 26)), xf(Vector3(-2, 0.02, 9))],
		[box(Vector3(2.4, 0.04, 6)), xf(Vector3(2, 0.02, -4))], [box(Vector3(4.4, 0.04, 2.4)), xf(Vector3(0, 0.02, -2.2))]]
	merged_at(paths, path, r, "Paths")
	_sky_pavilion(r)
	_palm_terrace(r)
	_roof_garden(r)


func half_dome(r: float) -> SphereMesh:
	# The top half of a ball, for domes that sit on a roof without bulging down into the room under them
	var m := sphere(r, 24)
	m.is_hemisphere = true
	m.height = r
	return m


func _sky_pavilion(r: Node3D) -> void:
	# The 4th floor: a glass pavilion on the roof's north side. Three magic-craft pods along its back (potions, star
	# charms, crystals), and the upper commons in front: sofas, a rug, beanbags and lamps.
	var p := node("Sky Pavilion", r)
	var x0 := -10.0
	var x1 := 14.0
	var z0 := -21.0
	var z1 := -7.0
	var base := pal("Palace Stone", P_STONE, 0.8)
	var glass := pal("Pavilion Glass", Color(0.8, 0.9, 1.0), 0.05, 0.1, 0.0, 0.22)
	var trim := pal("Palace Trim", P_TRIM, 0.6)
	var h := 4.2
	# low stone walls with glass above, a door in the middle of the front
	for e: Array in [[Vector2(x0, z0), Vector2(x1, z0), []], [Vector2(x0, z1), Vector2(x1, z1), [0.5]],
			[Vector2(x0, z0), Vector2(x0, z1), []], [Vector2(x1, z0), Vector2(x1, z1), []]]:
		wall(p, e[0], e[1], glass, e[2], h, 0.12)
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var mid := (a + b) / 2
		var yaw := atan2(b.x - a.x, b.y - a.y)
		var parts := [[box(Vector3(0.3, 0.2, a.distance_to(b) + 0.3)), xf(Vector3(mid.x, h, mid.y), Vector3(0, yaw, 0))]]
		if e[2].is_empty():
			mesh_at(box(Vector3(0.3, 0.9, a.distance_to(b))), base, Vector3(mid.x, 0.45, mid.y), p, yaw)
		for k in int(a.distance_to(b) / 3.0) + 1:
			var q := a.lerp(b, minf(1.0, k * 3.0 / a.distance_to(b)))
			parts.append([box(Vector3(0.22, h, 0.22)), xf(Vector3(q.x, h / 2, q.y))])
		merged_at(parts, trim, p, "Frame")
	# the roof: a flat slab and a lavender dome with a gold tip, like the towers'
	solid_box(Vector3(x1 - x0 + 0.6, 0.3, z1 - z0 + 0.6), pal("Dome", P_ROOF, 0.45, 0.2), Vector3((x0 + x1) / 2, h + 0.25, (z0 + z1) / 2), p)
	var dome := mesh_at(half_dome(4.5), pal("Dome", P_ROOF, 0.45, 0.2), Vector3((x0 + x1) / 2, h + 0.4, (z0 + z1) / 2), p)
	dome.scale = Vector3(1, 0.7, 1)
	mesh_at(sphere(0.4, 12), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3((x0 + x1) / 2, h + 3.7, (z0 + z1) / 2), p)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3((x0 + x1) / 2, h - 0.6, (z0 + z1) / 2)
	lamp.light_color = Color(1.0, 0.85, 0.95)
	lamp.light_energy = 0.8
	lamp.omni_range = 16.0
	p.add_child(lamp)
	label(p, "4th Floor - Sky Pavilion", Vector3((x0 + x1) / 2, h + 1.0, z1 + 0.4), 0.0, 64)
	# The magic-craft pods: round glass booths, each with a table, a glowing ball and stools
	var pods := [["Potion Pod", Color(0.55, 1.0, 0.7)], ["Star Charm Pod", Color(1.0, 0.85, 0.4)], ["Crystal Pod", Color(0.7, 0.6, 1.0)]]
	for k in 3:
		var c := Vector2(-4.0 + k * 8.0, z0 + 3.4)
		var pod := node(str(pods[k][0]), p, Vector3(c.x, 0, c.y))
		var tint: Color = pods[k][1]
		arc_wall(pod, Vector2.ZERO, 2.6, PI * 1.15, PI * 1.85 + PI * 0.3, pal("Pod Glass", Color(0.85, 0.9, 1.0), 0.05, 0.1, 0.0, 0.25), 8, 2.8)
		mesh_at(cylinder(2.7, 2.7, 0.12, 24), pal("Pod Top", P_ROOF, 0.45, 0.2), Vector3(0, 2.9, 0), pod)
		mesh_at(cylinder(2.5, 2.5, 0.03, 24), pal("Pod Rug %d" % k, tint.lerp(Color(0.6, 0.5, 0.9), 0.5), 0.95), Vector3(0, 0.02, 0), pod)
		solid_cylinder(0.75, 0.8, pal("Craft Table", Color(0.55, 0.42, 0.75), 0.7), Vector3(0, 0.4, -0.3), pod)
		mesh_at(sphere(0.32, 16), pal("Craft Glow %d" % k, tint, 0.2, 0.0, 2.2), Vector3(0, 1.15, -0.3), pod)
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 1.4, -0.3)
		glow.light_color = tint
		glow.light_energy = 0.7
		glow.omni_range = 3.5
		pod.add_child(glow)
		for s in [-1.0, 1.0]:
			solid_cylinder(0.28, 0.5, pal("Stool", P_PINK, 0.8), Vector3(s * 1.1, 0.25, 0.5), pod)
		var bits := []
		for j in 5:
			var a := TAU * j / 5.0
			bits.append([sphere(0.07, 6), xf(Vector3(cos(a) * 0.55, 0.88, -0.3 + sin(a) * 0.45))])
		merged_at(bits, pal("Craft Bits %d" % k, tint, 0.3, 0.0, 1.0), pod, "Bits")
		label(pod, str(pods[k][0]), Vector3(0, 2.5, 1.0), 0.0, 40)
	label(p, "Magic-Craft Pods", Vector3(4, 3.4, z0 + 6.8), 0.0, 48)
	# The upper commons: two sofas facing over a rug, beanbags, lamps and plants
	var cm := node("Upper Commons", p, Vector3(2, 0, z1 - 3.4))
	mesh_at(box(Vector3(9, 0.03, 4.6)), pal("Commons Rug", Color(0.62, 0.45, 0.88), 0.95), Vector3(0, 0.02, 0), cm)
	var sofa := pal("Sofa", Color(0.98, 0.6, 0.82), 0.95)
	for s in [-1.0, 1.0]:
		var so := node("Sofa", cm, Vector3(s * 3.6, 0, 0), PI / 2 * -s)
		solid_box(Vector3(3.2, 0.45, 1.0), sofa, Vector3(0, 0.22, 0), so)
		mesh_at(box(Vector3(3.2, 0.7, 0.3)), sofa, Vector3(0, 0.7, -0.45), so)
		for x in [-1.75, 1.75]:
			mesh_at(box(Vector3(0.3, 0.6, 1.0)), sofa, Vector3(x, 0.4, 0), so)
	solid_box(Vector3(1.6, 0.4, 1.0), pal("Craft Table", Color()), Vector3(0, 0.2, 0), cm)
	var bean_cols := [Color(0.45, 0.82, 1.0), P_PINK, Color(1.0, 0.85, 0.4)]
	for k in 3:
		var b := mesh_at(sphere(0.55, 12), pal("Beanbag %d" % k, bean_cols[k], 0.95), Vector3(-1.4 + k * 1.4, 0.32, 1.7), cm)
		b.scale = Vector3(1, 0.6, 1)
	for q in [Vector3(-5.6, 0, -1.8), Vector3(5.6, 0, -1.8)]:
		mesh_at(cylinder(0.03, 0.03, 1.6, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), q + Vector3(0, 0.8, 0), cm)
		mesh_at(cylinder(0.18, 0.3, 0.35, 12), pal("Lamp Shade", Color(1.0, 0.92, 0.8), 0.6, 0.0, 1.2), q + Vector3(0, 1.7, 0), cm)
	label(cm, "Upper Commons", Vector3(0, 2.6, 0), 0.0, 48)


func _palm_terrace(r: Node3D) -> void:
	# The roof's south-east: a wooden deck with palms in big planters, striped hammocks slung between them,
	# loungers looking out over the grounds and string lights criss-crossing overhead.
	var t := node("Palm Terrace", r)
	var planks := []
	for k in 22:
		planks.append([box(Vector3(22.6, 0.05, 0.86)), xf(Vector3(16, 0.03, 1.5 + k * 0.92))])
	merged_at(planks, pal("Deck", Color(0.78, 0.6, 0.55), 0.8), t, "Deck")
	var spots := [Vector2(8, 5), Vector2(16, 5), Vector2(24, 5), Vector2(8, 13), Vector2(16, 13), Vector2(24, 13)]
	var tops := []
	for k in spots.size():
		var sp: Vector2 = spots[k]
		solid_cylinder(0.8, 0.6, pal("Planter", P_PLANTER, 0.8), Vector3(sp.x, 0.3, sp.y), t)
		mesh_at(cylinder(0.72, 0.72, 0.05, 16), pal("Planter Soil", Color(0.3, 0.22, 0.26)), Vector3(sp.x, 0.62, sp.y), t)
		tops.append(palm(t, Vector3(sp.x, 0.6, sp.y), 0.6 + k * 1.1, 5.0 + (k % 3) * 0.5))
	var cols := [P_PINK, Color(0.7, 0.55, 0.98), Color(0.45, 0.8, 0.95)]
	for k in 3:
		var a: Vector2 = spots[k]
		var b: Vector2 = spots[k + 3]
		hammock(t, Vector3(a.x, 1.9, a.y + 0.4), Vector3(b.x, 1.9, b.y - 0.4), cols[k])
	# loungers along the front, under little parasols
	for k in 5:
		var lo := node("Lounger", t, Vector3(6.5 + k * 4.6, 0, 19.5), PI)
		var frame := pal("Lounger Frame", P_TRIM, 0.6)
		solid_box(Vector3(0.8, 0.35, 1.5), frame, Vector3(0, 0.18, 0.3), lo)
		mesh_at(box(Vector3(0.8, 0.7, 0.12)), frame, Vector3(0, 0.6, -0.6), lo, 0.0, Vector3(-0.6, 0, 0))
		mesh_at(box(Vector3(0.7, 0.08, 1.4)), pal("Lounger Pad %d" % (k % 3), cols[k % 3], 0.95), Vector3(0, 0.39, 0.3), lo)
		mesh_at(box(Vector3(0.7, 0.08, 0.65)), pal("Lounger Pad %d" % (k % 3), cols[k % 3], 0.95), Vector3(0, 0.66, -0.52), lo, 0.0, Vector3(-0.6, 0, 0))
		if k < 4:
			var u := node("Parasol", t, Vector3(8.8 + k * 4.6, 0, 20.4))
			mesh_at(cylinder(0.04, 0.04, 2.4, 6), pal("Lamp Iron", P_NAVY, 0.5, 0.5), Vector3(0, 1.2, 0), u)
			mesh_at(cylinder(0.05, 1.3, 0.5, 16), pal("Parasol %d" % (k % 3), cols[(k + 1) % 3], 0.9), Vector3(0, 2.45, 0), u)
	# string lights from poles at the deck's corners and over the palms
	var poles := [Vector3(4.6, 0, 1.6), Vector3(27.4, 0, 1.6), Vector3(27.4, 0, 21.6), Vector3(4.6, 0, 21.6)]
	var iron := pal("Lamp Iron", P_NAVY, 0.5, 0.5)
	for q: Vector3 in poles:
		solid_cylinder(0.07, 3.6, iron, q + Vector3(0, 1.8, 0), t)
	var bulbs := []
	var cords := []
	for pair in [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2], [1, 3]]:
		var a: Vector3 = poles[pair[0]] + Vector3(0, 3.5, 0)
		var b: Vector3 = poles[pair[1]] + Vector3(0, 3.5, 0)
		var m := int(a.distance_to(b) / 1.3)
		for k in m + 1:
			var u := float(k) / m
			var q := a.lerp(b, u) - Vector3(0, sin(PI * u) * 0.9, 0)
			bulbs.append([sphere(0.11, 8), xf(q - Vector3(0, 0.13, 0))])
			if k < m:
				var q2 := a.lerp(b, float(k + 1) / m) - Vector3(0, sin(PI * float(k + 1) / m) * 0.9, 0)
				cords.append([box(Vector3(0.03, 0.03, q.distance_to(q2))), Transform3D(Basis.looking_at((q2 - q).normalized(), Vector3.UP), (q + q2) / 2)])
	merged_at(bulbs, pal("Bulb", Color(1.0, 0.88, 0.6), 0.3, 0.0, 3.0), t, "String Lights")
	merged_at(cords, iron, t, "Cords")
	var glow := OmniLight3D.new()
	glow.position = Vector3(16, 3.0, 11)
	glow.light_color = Color(1.0, 0.85, 0.6)
	glow.light_energy = 0.8
	glow.omni_range = 14.0
	t.add_child(glow)
	label(t, "Palm Terrace", Vector3(16, 4.2, 9), 0.0, 64)


func _roof_garden(r: Node3D) -> void:
	# The roof's south-west: flower planters and little trees in pots round a gazebo with a dome, and inside it a
	# brass telescope pointing up at the Void's sky.
	var g := node("Roof Garden", r)
	var c := Vector2(-16, 11)
	mesh_at(cylinder(9.0, 9.0, 0.04, 40), pal("Roof Lawn", P_LAWN, 0.95), Vector3(c.x, 0.02, c.y), g)
	# the gazebo: a raised round floor, eight slim columns, a ring and a dome with a gold tip
	var gz := node("Gazebo", g, Vector3(c.x, 0, c.y))
	var trim := pal("Palace Trim", P_TRIM, 0.6)
	solid_cylinder(3.6, 0.25, trim, Vector3(0, 0.125, 0), gz)
	var cols := []
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8
		cols.append([cylinder(0.14, 0.17, 3.2, 10), xf(Vector3(cos(a) * 3.2, 1.85, sin(a) * 3.2))])
	cols.append([cylinder(3.5, 3.5, 0.3, 32), xf(Vector3(0, 3.55, 0))])
	merged_at(cols, trim, gz, "Columns")
	var dome := mesh_at(half_dome(3.7), pal("Dome", P_ROOF, 0.45, 0.2), Vector3(0, 3.7, 0), gz)
	dome.scale = Vector3(1, 0.75, 1)
	mesh_at(sphere(0.3, 12), pal("Banner Gold", P_GOLD, 0.35, 0.6, 0.35), Vector3(0, 6.5, 0), gz)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.0, 0)
	lamp.light_color = Color(1.0, 0.85, 0.65)
	lamp.light_energy = 0.6
	lamp.omni_range = 6.0
	gz.add_child(lamp)
	# the telescope: a tripod, a brass tube tipped up to the north-east, an eyepiece
	var ts := node("Telescope", gz, Vector3(0, 0.25, 0))
	var brass := pal("Brass", P_GOLD, 0.3, 0.8)
	var legs := []
	for k in 3:
		var a := TAU * k / 3.0
		var foot := Vector3(cos(a) * 0.6, 0, sin(a) * 0.6)
		var top := Vector3(0, 1.3, 0)
		legs.append([cylinder(0.03, 0.03, foot.distance_to(top), 6), Transform3D(Basis.looking_at((top - foot).normalized(), Vector3.RIGHT if absf((top - foot).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI / 2), (foot + top) / 2)])
	merged_at(legs, pal("Lamp Iron", P_NAVY, 0.5, 0.5), ts, "Tripod")
	var tube := mesh_at(cylinder(0.14, 0.2, 1.8, 16), brass, Vector3(0, 1.55, 0), ts)
	tube.rotation = Vector3(-0.75, PI * 0.75, 0)
	var eye := mesh_at(cylinder(0.05, 0.05, 0.3, 8), brass, Vector3(0.35, 1.2, 0.35), ts)
	eye.rotation = Vector3(-0.75, PI * 0.75, 0)
	label(gz, "Telescope", Vector3(0, 2.6, 0), 0.0, 40)
	# planters and potted trees round it, and benches facing it
	for k in 6:
		var a := TAU * k / 6.0
		var q := c + Vector2(cos(a), sin(a)) * 7.2
		if k % 2 == 0:
			planter(g, Vector3(q.x, 0, q.y), Vector2(2.6, 1.0), -a + PI / 2, 60 + k)
		else:
			solid_cylinder(0.7, 0.7, pal("Planter", P_PLANTER, 0.8), Vector3(q.x, 0.35, q.y), g)
			blossom_tree(g, Vector3(q.x, 0.7, q.y), 0.6)
	for k in 3:
		var a := TAU * (k + 0.5) / 6.0 * 2.0 + PI / 6
		var q := c + Vector2(cos(a), sin(a)) * 5.2
		bench(g, Vector3(q.x, 0, q.y), atan2(c.x - q.x, c.y - q.y))
	label(g, "Roof Garden", Vector3(c.x, 6.8, c.y), 0.0, 64)
