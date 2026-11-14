extends Node3D

# The root of a race circuit: a level of its own for one race (Hayden's day 1 playtest, 11 Nov 2026: "Instead of having
# the races baked into the map, maybe have a separate instance with option to back out, restart the race"). The scenes
# (scenes/races/<id>.tscn, made by tools/build_race_circuits.gd) hold only this script, the player and an Entrance
# marker: everything else is built here when the circuit loads, from the track's entry in Races.TRACKS, so a track can
# be changed by changing its points and nothing has to be rebuilt.
#
# What's built: the sky, the light and the ground; the road, a wide ribbon laid along the same smooth line the racers
# follow (RaceTrack.spline()), with low walls both sides so nobody rolls off, striped kerbs and dashes down it, built
# up on banks where it climbs; and the scenery round it, by the circuit's "theme" (the Void's alien look, autumn on
# Earth, or Dark Hollow's midnight: "dark") and "feature" (a lake in the middle, a flower meadow, a hill with an
# observatory on top, a farm, the misty hollow with the Moon Clock).
# Races (scripts/races.gd) puts the race itself on it as everywhere else (scripts/race_track.gd: the arch, the
# starter, rings, boost pads, Star Boxes, goo and the obstacles), and starts the race once it's ready.

const LIFE := preload("res://scripts/race_life.gd")
const WALL_H := 1.1                   # how high the walls stand above the road
const WALL_T := 0.5                   # ...and how thick
const KERB := 0.9                     # the striped strip along each edge
const GROUND_SIZE := 900.0
const SC_HALF := 3.6                  # a secret shortcut's half width (the road's is 7)
const SC_ROOF := 5.4                  # ...and how high its tunnel's roof is over its floor
const TUNNEL_TOP := 9.5               # a tunnel over the road: its arch's top over the road (rings stand 7.2 m tall)

@export var circuit_id := ""

var track: Dictionary
var line: Array[Vector3] = []          # the middle of the road, about a metre between points, all the way round
var _samples: PackedVector2Array      # every third point of the line, flat, for "how far from the road?"
var _rng := RandomNumberGenerator.new()
var _mats := {}
var dist: Array[float] = []           # how far round each point of the line is (flat metres)
var cp_idx: Array[int] = []           # where each checkpoint is in the line
var total := 0.0                      # the whole loop's length
# Secret shortcuts (Hayden's 13 Nov 2026 playtest: "secret shortcuts, tunnels"): a gap in the wall on the inside of a
# bend, hidden behind a curtain of vines (corn on Earth), into a tunnel that cuts across the middle and comes out
# further round. Each: {name, from, to (checkpoint segments, as everything else in Races.TRACKS), inner (-1 left,
# 1 right), path (the middle of its floor, a point a metre), d0, d1 (how far round the road it leaves and joins)}.
# Races (scripts/races.gd _shortcut()) moves you on past the rings it skips.
var shortcuts: Array = []
var _open := {}                       # line index -> which side's wall is open for a shortcut's mouth (-1 / 1)


func _enter_tree() -> void:
	# Before the player's _ready: the way in (and the player) stand at the start, facing down the straight
	track = Races.TRACKS.get(circuit_id, {})
	if track.is_empty():
		push_error("race_circuit.gd: no track called %s" % circuit_id)
		return
	line = RaceTrack.spline(track.points, cp_idx)
	for i in range(0, line.size(), 3):
		_samples.append(Vector2(line[i].x, line[i].z))
	total = 0.0
	for i in line.size():
		if i > 0:
			total += Vector2(line[i].x, line[i].z).distance_to(Vector2(line[i - 1].x, line[i - 1].z))
		dist.append(total)
	total += Vector2(line[0].x, line[0].z).distance_to(Vector2(line[-1].x, line[-1].z))
	_plan_shortcuts()
	var a := line[line.size() - 8]
	var b := line[0]
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = a + Vector3.UP * 1.0
			(n as Node3D).rotation.y = atan2(b.x - a.x, b.z - a.z)


func _ready() -> void:
	if track.is_empty():
		return
	_rng.seed = hash(circuit_id)
	var c: Dictionary = track.get("circuit", {})
	_environment(str(c.get("theme", "void")))
	_ground(str(c.get("theme", "void")))
	_road(str(c.get("theme", "void")))
	for k in shortcuts.size():
		_shortcut(k, str(c.get("theme", "void")))
	for tn in track.get("tunnels", []):
		_road_tunnel(float(tn[0]), float(tn[1]), str(c.get("theme", "void")))
	match str(c.get("feature", "")):
		"lake":
			_lake()
		"hill":
			_hill()
		"meadow":
			_meadow()
		"farm":
			_farm()
		"hollow":
			_hollow()
	match str(c.get("theme", "void")):
		"earth":
			_earth_scenery()
		"dark":
			_dark_scenery()
		_:
			_void_scenery()
	_crowd(str(c.get("theme", "void")))
	# Things happening all round the road as you race by (scripts/race_life.gd)
	var life: Node3D = LIFE.new()
	life.setup(self)
	add_child(life)


func half_width() -> float:
	return float(track.get("width", 14.0)) / 2.0


func off_road(xz: Vector2) -> float:
	# How far from the middle of the road a spot is (roughly, to the nearest few metres of line)
	var best := INF
	for s in _samples:
		best = minf(best, xz.distance_squared_to(s))
	return sqrt(best)


func _mat(name: String, c: Color, rough := 0.85, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# -----------------------------------------------------------------------------
# Sky, light and ground
# -----------------------------------------------------------------------------
func _environment(theme: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var dark := theme == "dark"
	if dark:
		sm.sky_top_color = Color(0.05, 0.04, 0.14)            # Dark Hollow's midnight: deep violet, a misty glow low down
		sm.sky_horizon_color = Color(0.26, 0.2, 0.42)
		sm.ground_horizon_color = Color(0.2, 0.16, 0.32)
		sm.ground_bottom_color = Color(0.05, 0.04, 0.1)
	elif theme == "earth":
		sm.sky_top_color = Color(0.32, 0.55, 0.88)
		sm.sky_horizon_color = Color(0.86, 0.85, 0.78)
		sm.ground_horizon_color = Color(0.7, 0.62, 0.45)
		sm.ground_bottom_color = Color(0.35, 0.3, 0.2)
	else:
		sm.sky_top_color = Color(0.28, 0.62, 0.5)              # the Void's green sky with a creamy horizon
		sm.sky_horizon_color = Color(0.93, 0.9, 0.72)
		sm.ground_horizon_color = Color(0.6, 0.75, 0.6)
		sm.ground_bottom_color = Color(0.2, 0.3, 0.3)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9 if not dark else 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = sm.sky_horizon_color
	env.fog_density = 0.0025 if not dark else 0.006
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(35), 0)
	sun.light_energy = 1.15 if not dark else 0.55          # (in Dark Hollow it's moonlight)
	sun.light_color = Color(1.0, 0.96, 0.88) if theme == "earth" else (Color(0.65, 0.7, 1.0) if dark else Color(1.0, 0.97, 0.85))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	if dark:
		_night_sky()


func _night_sky() -> void:
	# Stars all over, and a big moon (the Moon Clock's in the middle of the hollow, so this one's just the moon)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.8
	s.radial_segments = 4
	s.rings = 2
	mm.mesh = s
	mm.instance_count = 420
	for k in 420:
		var a := _rng.randf() * TAU
		var up := _rng.randf_range(0.12, 1.0)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.5, 1.4)), dir * 380.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Stars"
	mi.multimesh = mm
	mi.material_override = _mat("Star", Color(1.0, 0.97, 0.85), 0.5, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var moon := SphereMesh.new()
	moon.radius = 22.0
	moon.height = 44.0
	_mesh(self, moon, Vector3(-160, 190, -240), _mat("Moon", Color(0.95, 0.93, 0.8), 0.6, 1.6), false).name = "Moon"


func _ground(theme: String) -> void:
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var m := StandardMaterial3D.new()
	m.resource_name = "Ground"
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	noise.noise = n
	var grad := Gradient.new()
	if theme == "dark":
		grad.set_color(0, Color(0.13, 0.12, 0.22))               # moss in the moonlight
		grad.set_color(1, Color(0.2, 0.26, 0.3))
	elif theme == "earth":
		grad.set_color(0, Color(0.42, 0.52, 0.22))
		grad.set_color(1, Color(0.62, 0.6, 0.28))
	else:
		grad.set_color(0, Color(0.42, 0.78, 0.38))               # the Void's acid-lime grass
		grad.set_color(1, Color(0.3, 0.66, 0.5))
	noise.color_ramp = grad
	m.albedo_texture = noise
	m.uv1_scale = Vector3(40, 40, 1)
	m.roughness = 0.95
	_mesh(g, plane, Vector3.ZERO, m, false)
	var body := StaticBody3D.new()
	body.name = "Ground Body"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 2.0, GROUND_SIZE)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	g.add_child(body)
	# Hills all round the edge, far off, so the world doesn't just stop
	var hill_m := _mat("Far Hills", Color(0.5, 0.55, 0.3) if theme == "earth" else (Color(0.12, 0.1, 0.2) if theme == "dark" else Color(0.38, 0.55, 0.62)))
	for k in 26:
		var a := TAU * k / 26.0 + _rng.randf_range(-0.08, 0.08)
		var r := _rng.randf_range(250.0, 320.0)
		var cone := CylinderMesh.new()
		cone.top_radius = _rng.randf_range(0.0, 10.0) if theme == "earth" else 0.0
		cone.bottom_radius = _rng.randf_range(45.0, 80.0)
		cone.height = _rng.randf_range(35.0, 90.0) if theme != "earth" else _rng.randf_range(20.0, 45.0)
		cone.radial_segments = 10
		_mesh(g, cone, Vector3(cos(a) * r, cone.height / 2.0 - 2.0, sin(a) * r), hill_m, false)


# -----------------------------------------------------------------------------
# The road
# -----------------------------------------------------------------------------
func _road(theme: String) -> void:
	var hw := half_width()
	var n := line.size()
	var dark := theme == "dark"
	var road_c := Color(0.36, 0.33, 0.42) if theme == "earth" else (Color(0.2, 0.18, 0.28) if dark else Color(0.3, 0.26, 0.42))
	var dash_c := Color(0.95, 0.92, 0.8)
	var kerb_a := Color(0.85, 0.2, 0.18) if theme == "earth" else (Color(0.55, 0.35, 0.95) if dark else Color(1.0, 0.45, 0.75))
	var kerb_b := Color(0.97, 0.95, 0.9)
	var wall_c := Color(0.62, 0.5, 0.95) if theme == "void" else (Color(0.3, 0.26, 0.42) if dark else Color(0.78, 0.68, 0.55))
	var top_c := Color(1.0, 0.82, 0.35) if theme != "earth" else Color(0.6, 0.42, 0.25)   # (Dark Hollow: lantern gold)
	var bank_c := Color(0.36, 0.42, 0.3) if theme == "earth" else (Color(0.16, 0.16, 0.26) if dark else Color(0.32, 0.36, 0.5))
	# The road's cross-section, left to right: [metres to the right, metres up (or "down" to the ground), colour]
	var sides: Array[Vector3] = []
	for i in n:
		var f := line[(i + 1) % n] - line[(i - 1 + n) % n]
		f.y = 0.0
		sides.append(f.normalized().cross(Vector3.UP).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in n:
		var j := (i + 1) % n
		var kerb := kerb_a if (i / 2) % 2 == 0 else kerb_b
		var pi := _profile(i, hw, [bank_c, top_c, wall_c, kerb, road_c])
		var pj := _profile(j, hw, [bank_c, top_c, wall_c, kerb, road_c])
		for k in pi.size() - 1:
			var ai := _at(i, sides[i], pi[k])
			var aj := _at(j, sides[j], pj[k])
			var bi := _at(i, sides[i], pi[k + 1])
			var bj := _at(j, sides[j], pj[k + 1])
			var c: Color = pi[k][2]
			# Winding: clockwise seen from the face's outside (the road's top from above)
			for v in [ai, aj, bj, ai, bj, bi]:
				st.set_color(c)
				st.add_vertex(v)
			faces.append_array(PackedVector3Array([ai, aj, bj, ai, bj, bi]))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.resource_name = "Road"
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = st.commit()
	road.material_override = m
	add_child(road)
	var body := StaticBody3D.new()
	body.name = "Road Body"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	road.add_child(body)
	# Dashes down the road, a lane either side of the middle
	var dashes := SurfaceTool.new()
	dashes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, n - 3, 6):
		for lane: float in [-hw / 3.0, hw / 3.0]:
			var a := line[i] + sides[i] * (lane - 0.12) + Vector3.UP * 0.03
			var b := line[i] + sides[i] * (lane + 0.12) + Vector3.UP * 0.03
			var c := line[i + 3] + sides[i + 3] * (lane - 0.12) + Vector3.UP * 0.03
			var d := line[i + 3] + sides[i + 3] * (lane + 0.12) + Vector3.UP * 0.03
			for v in [a, c, d, a, d, b]:
				dashes.add_vertex(v)
	dashes.generate_normals()
	_mesh(self, dashes.commit(), Vector3.ZERO, _mat("Road Dash", dash_c, 0.6), false).name = "Dashes"


func _profile(i: int, hw: float, c: Array) -> Array:
	# The road's cross-section at line point i, left to right: [metres to the right, metres up (or -1: down to the
	# ground), colour]. Where a secret shortcut's mouth is, that side's wall is down to the road (_open).
	var wl := 0.0 if int(_open.get(i, 0)) == -1 else WALL_H
	var wr := 0.0 if int(_open.get(i, 0)) == 1 else WALL_H
	return [[-hw - WALL_T, -1, c[0]], [-hw - WALL_T, wl, c[1]], [-hw, wl, c[2]], [-hw, 0.0, c[3]],
		[-hw + KERB, 0.0, c[4]], [hw - KERB, 0.0, c[3]], [hw, 0.0, c[2]], [hw, wr, c[1]],
		[hw + WALL_T, wr, c[0]], [hw + WALL_T, -1, null]]


func _at(i: int, side: Vector3, p: Array) -> Vector3:
	# A point of the cross-section at line point i: "-1" for the height means down into the ground
	var c := line[i]
	var y := c.y + float(p[1]) if float(p[1]) >= 0.0 else -0.4
	return Vector3(c.x, y, c.z) + side * float(p[0])


# -----------------------------------------------------------------------------
# Secret shortcuts and tunnels
# -----------------------------------------------------------------------------
func d_at(seg: float) -> float:
	# How far round the road a checkpoint segment value is (2.5: halfway from checkpoint 2 to 3)
	var i := clampi(int(floor(seg)), 0, cp_idx.size() - 1)
	var a := dist[cp_idx[i]]
	var b := dist[cp_idx[i + 1]] if i + 1 < cp_idx.size() else total
	return a + (b - a) * (seg - i)


func index_at(d: float) -> int:
	d = fposmod(d, total)
	var lo := 0
	var hi := dist.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if dist[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _fwd(i: int) -> Vector3:
	var n := line.size()
	var f := line[(i + 1) % n] - line[(i - 1 + n) % n]
	f.y = 0.0
	return f.normalized()


func _plan_shortcuts() -> void:
	# Each shortcut's path: a smooth curve leaving the road on the inside of the bend, angled in, across the middle
	# and back onto the road further round, angled out again
	var hw := half_width()
	var n := line.size()
	for sc in track.get("shortcuts", []):
		var d0 := d_at(float(sc.from))
		var d1 := d_at(float(sc.to))
		var i0 := index_at(d0)
		var i1 := index_at(d1)
		var f0 := _fwd(i0)
		var f1 := _fwd(i1)
		var s0 := f0.cross(Vector3.UP).normalized()
		var s1 := f1.cross(Vector3.UP).normalized()
		var probe := line[i0] + s0 * 25.0
		var inner := 1.0 if _inside_loop(Vector2(probe.x, probe.z)) else -1.0
		var a := line[i0] + s0 * inner * (hw - SC_HALF)             # (it starts on the road, so the floors meet)
		var b := line[i1] + s1 * inner * (hw - SC_HALF)
		var span := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		var t0 := (f0 * cos(0.55) + s0 * inner * sin(0.55)).normalized()
		var t1 := (f1 * cos(0.55) - s1 * inner * sin(0.55)).normalized()
		var p1 := a + t0 * span * 0.3
		var p2 := b - t1 * span * 0.3
		var dense: Array[Vector3] = []
		for k in 401:
			var u := k / 400.0
			var v := 1.0 - u
			dense.append(v * v * v * a + 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u * b)
		var path: Array[Vector3] = [dense[0]]
		var run := 0.0
		for k in range(1, dense.size()):
			run += Vector2(dense[k].x, dense[k].z).distance_to(Vector2(dense[k - 1].x, dense[k - 1].z))
			if run >= 1.0 or k == dense.size() - 1:
				path.append(dense[k])
				run = 0.0
		# Near the mouths the floor is at the road's own height where it lies over the road, easing to the curve's
		# height further off, so on a hill there's no step up onto it from the lane next to it
		for k in path.size():
			if k > path.size() / 4 and k < path.size() * 3 / 4:
				continue
			var xz := Vector2(path[k].x, path[k].z)
			var best := INF
			var road_y := 0.0
			for ri in n:
				var dd := xz.distance_squared_to(Vector2(line[ri].x, line[ri].z))
				if dd < best:
					best = dd
					road_y = line[ri].y
			var off := clampf((sqrt(best) - hw) / 8.0, 0.0, 1.0)
			path[k].y = lerpf(road_y - 0.02, path[k].y, off)
		var length := 0.0
		for k in range(1, path.size()):
			length += Vector2(path[k].x, path[k].z).distance_to(Vector2(path[k - 1].x, path[k - 1].z))
		shortcuts.append({"name": str(sc.get("name", "Secret Shortcut")), "from": float(sc.from), "to": float(sc.to),
			"inner": inner, "path": path, "length": length, "d0": d0, "d1": d1})
		# The road's wall on that side opens wherever the shortcut's floor runs through it
		for i in range(-30, 31):
			for at: int in [i0, i1]:
				var ii: int = (at + i + n) % n
				var w := line[ii] + _fwd(ii).cross(Vector3.UP).normalized() * inner * (hw + WALL_T * 0.5)
				if _to_path(Vector2(w.x, w.z), path) < SC_HALF + WALL_T + 0.4:
					_open[ii] = int(inner)


static func _to_path(xz: Vector2, path: Array) -> float:
	var best := INF
	for k in range(1, path.size()):
		var a := Vector2(path[k - 1].x, path[k - 1].z)
		var b := Vector2(path[k].x, path[k].z)
		best = minf(best, xz.distance_to(Geometry2D.get_closest_point_to_segment(xz, a, b)))
	return best


func shortcut_at(pos: Vector3) -> int:
	# Which secret shortcut a spot is in (-1: none): over its floor, give or take a metre
	for k in shortcuts.size():
		var path: Array = shortcuts[k].path
		var xz := Vector2(pos.x, pos.z)
		var near := INF
		var y := 0.0
		for i in range(0, path.size(), 2):
			var q: Vector3 = path[i]
			var dd := xz.distance_squared_to(Vector2(q.x, q.z))
			if dd < near:
				near = dd
				y = q.y
		if sqrt(near) < SC_HALF + 2.0 and absf(pos.y - y) < 4.5:
			return k
	return -1


func shortcut_progress(k: int, pos: Vector3) -> float:
	# How far through shortcut k a spot is, 0 at its mouth on the road to 1 where it comes back out
	var path: Array = shortcuts[k].path
	var xz := Vector2(pos.x, pos.z)
	var best := 0
	var near := INF
	for i in path.size():
		var dd := xz.distance_squared_to(Vector2(path[i].x, path[i].z))
		if dd < near:
			near = dd
			best = i
	return float(best) / maxf(1.0, path.size() - 1)


func near_shortcut(xz: Vector2, margin: float) -> bool:
	for sc in shortcuts:
		if _to_path(xz, sc.path) < SC_HALF + WALL_T + margin:
			return true
	return false


func _shortcut(k: int, theme: String) -> void:
	# Its floor and walls (one ribbon with its own collision, like the road), then a tunnel over it from where its walls
	# are up, lit by a row of glowing lamps along the top, with a curtain hiding each end from the road
	var sc: Dictionary = shortcuts[k]
	var path: Array = sc.path
	var hw := half_width()
	var h := SC_HALF
	var earth := theme == "earth"
	var floor_c := Color(0.45, 0.33, 0.22) if earth else Color(0.24, 0.2, 0.38)
	var wall_c := Color(0.6, 0.42, 0.26) if earth else Color(0.5, 0.4, 0.85)
	var top_c := Color(0.72, 0.55, 0.32) if earth else Color(1.0, 0.82, 0.35)
	var bank_c := Color(0.36, 0.42, 0.3) if earth else Color(0.32, 0.36, 0.5)
	var holder := Node3D.new()
	holder.name = "Shortcut %d" % k
	add_child(holder)
	var n := path.size()
	var sides: Array[Vector3] = []
	var walls: Array[float] = []
	for i in n:
		var f: Vector3 = path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		f.y = 0.0
		var sd := f.normalized().cross(Vector3.UP).normalized()
		sides.append(sd)
		# (Its walls only stand where they're off the road: at each end its floor runs onto the road)
		var up := true
		for sgn in [-1.0, 1.0]:
			var w: Vector3 = path[i] + sd * sgn * (h + WALL_T * 0.5)
			if off_road(Vector2(w.x, w.z)) < hw + WALL_T + 0.6:
				up = false
		walls.append(WALL_H if up else 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in n - 1:
		var j := i + 1
		var pi := [[-h - WALL_T, -1.0, bank_c], [-h - WALL_T, walls[i], top_c], [-h, walls[i], wall_c], [-h, 0.0, floor_c],
			[h, 0.0, wall_c], [h, walls[i], top_c], [h + WALL_T, walls[i], bank_c], [h + WALL_T, -1.0, null]]
		var pj := [[-h - WALL_T, -1.0], [-h - WALL_T, walls[j]], [-h, walls[j]], [-h, 0.0],
			[h, 0.0], [h, walls[j]], [h + WALL_T, walls[j]], [h + WALL_T, -1.0]]
		for q in pi.size() - 1:
			var ai := _sc_at(path[i], sides[i], pi[q])
			var aj := _sc_at(path[j], sides[j], pj[q])
			var bi := _sc_at(path[i], sides[i], pi[q + 1])
			var bj := _sc_at(path[j], sides[j], pj[q + 1])
			for v in [ai, aj, bj, ai, bj, bi]:
				st.set_color(pi[q][2])
				st.add_vertex(v)
			faces.append_array(PackedVector3Array([ai, aj, bj, ai, bj, bi]))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.resource_name = "Shortcut"
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	floor_mi.mesh = st.commit()
	floor_mi.material_override = m
	holder.add_child(floor_mi)
	_solid(floor_mi, faces)
	# The tunnel, over the stretch where both walls stand
	var first := -1
	var last := -1
	for i in n:
		if walls[i] > 0.0:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return
	var rows: Array[Vector3] = []
	var rsides: Array[Vector3] = []
	for i in range(first, last + 1):
		rows.append(path[i])
		rsides.append(sides[i])
	_arch(holder, rows, rsides, h + WALL_T * 0.5, WALL_H, SC_ROOF, Color(0.55, 0.38, 0.22) if earth else Color(0.36, 0.28, 0.62),
		Color(1.0, 0.7, 0.3) if earth else Color(0.3, 0.95, 0.95), 5)
	for end in [first, last]:
		_curtain(holder, path[end], sides[end], h, earth)
	sc["mouths"] = [path[first], path[last]]


func _sc_at(c: Vector3, side: Vector3, p: Array) -> Vector3:
	var y := c.y - 0.03 + float(p[1]) if float(p[1]) >= 0.0 else -0.4
	var v := Vector3(c.x, y, c.z) + side * float(p[0])
	if float(p[1]) == 0.0:
		# Where the floor's edge lies over the road (at a mouth, on a hill), keep it just under the road's surface
		var best := INF
		var road_y := 0.0
		for i in line.size():
			var dd := Vector2(v.x, v.z).distance_squared_to(Vector2(line[i].x, line[i].z))
			if dd < best:
				best = dd
				road_y = line[i].y
		if sqrt(best) < half_width() + 4.0:
			v.y = minf(v.y, road_y - 0.08)
	return v


func _arch(holder: Node3D, rows: Array[Vector3], rsides: Array[Vector3], half: float, foot: float, top: float, c: Color,
		lamp_c: Color, lamp_every: int) -> void:
	# A round-topped roof over a row of points: from both walls' tops up to "top" over the middle. Seen from inside and
	# out (no back faces culled), solid (so a big jump bumps your head), with a glowing lamp every few metres
	const SEGS := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var ring := func(i: int, a: int) -> Vector3:
		var ang := PI * a / SEGS
		return rows[i] + rsides[i] * half * cos(ang) + Vector3.UP * (foot + (top - foot) * sin(ang))
	for i in rows.size() - 1:
		for a in SEGS:
			var p00: Vector3 = ring.call(i, a)
			var p01: Vector3 = ring.call(i, a + 1)
			var p10: Vector3 = ring.call(i + 1, a)
			var p11: Vector3 = ring.call(i + 1, a + 1)
			var shade := c.darkened(0.12) if (i / 2) % 2 == 0 else c
			for v in [p00, p10, p11, p00, p11, p01]:
				st.set_color(shade)
				st.add_vertex(v)
			faces.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.resource_name = "Tunnel"
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	var roof := MeshInstance3D.new()
	roof.name = "Tunnel Roof"
	roof.mesh = st.commit()
	roof.material_override = m
	holder.add_child(roof)
	_solid(roof, faces, true)
	var lamp := SphereMesh.new()
	lamp.radius = 0.28
	lamp.height = 0.4
	var lm := _mat("Tunnel Lamp %s" % lamp_c.to_html(), lamp_c, 0.4, 2.5)
	for i in range(2, rows.size() - 2, lamp_every):
		for sgn in [-0.55, 0.55]:
			var at: Vector3 = rows[i] + rsides[i] * half * sgn + Vector3.UP * (foot + (top - foot) * 0.82 - 0.2)
			_mesh(holder, lamp, at, lm, false)


func _solid(mi: MeshInstance3D, faces: PackedVector3Array, roof := false) -> void:
	var body := StaticBody3D.new()
	if roof:
		body.add_to_group("race_roof")             # (RaceTrack.ground_at looks through it for the road underneath)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


func _curtain(holder: Node3D, at: Vector3, side: Vector3, half: float, earth: bool) -> void:
	# Hanging vines (cornstalks on Earth) right across a tunnel's mouth: from the road it looks like a leafy bit of wall.
	# Nothing solid: ride straight through.
	var c := holder.get_node_or_null("Curtain")
	var strands := Node3D.new()
	strands.name = "Curtain" if c == null else "Curtain 2"
	strands.position = at
	holder.add_child(strands)
	var greens := [Color(0.3, 0.75, 0.35), Color(0.45, 0.85, 0.3), Color(0.25, 0.6, 0.4)] if not earth else \
		[Color(0.78, 0.66, 0.32), Color(0.66, 0.55, 0.25), Color(0.85, 0.75, 0.4)]
	var count := int(half * 2.0 / 0.42)
	for k in count + 1:
		var x := -half + 2.0 * half * k / count
		var ln := SC_ROOF - 0.4 - absf(x) * 0.25 - _rng.randf_range(0.0, 1.0)
		var vine := BoxMesh.new()
		vine.size = Vector3(0.28, ln, 0.08)
		var v := _mesh(strands, vine, side * x + Vector3.UP * (SC_ROOF - ln / 2.0 - 0.2), _mat("Vine %d" % (k % 3),
			greens[k % 3]), false)
		v.basis = Basis(side, Vector3.UP, side.cross(Vector3.UP).normalized())
		for b in 3:
			var leaf := SphereMesh.new()
			leaf.radius = 0.22
			leaf.height = 0.18
			_mesh(strands, leaf, side * (x + _rng.randf_range(-0.12, 0.12)) + Vector3.UP * (SC_ROOF - 0.6 - _rng.randf() * ln),
				_mat("Leaf %d" % (b % 3), greens[(k + b) % 3]), false)


func _road_tunnel(from: float, to: float, theme: String) -> void:
	# A tunnel right over the road between two checkpoints (never round a ring): crystal on the Void's tracks, a
	# covered bridge's red barn roof on Earth's
	var a := index_at(d_at(from))
	var b := index_at(d_at(to))
	var rows: Array[Vector3] = []
	var rsides: Array[Vector3] = []
	var i := a
	while i != b:
		rows.append(line[i])
		rsides.append(_fwd(i).cross(Vector3.UP).normalized())
		i = (i + 1) % line.size()
	var holder := Node3D.new()
	holder.name = "Tunnel %.1f" % from
	add_child(holder)
	var earth := theme == "earth"
	_arch(holder, rows, rsides, half_width() + WALL_T * 0.5, WALL_H, TUNNEL_TOP,
		Color(0.7, 0.2, 0.16) if earth else Color(0.55, 0.45, 0.95), Color(1.0, 0.75, 0.35) if earth else Color(1.0, 0.82, 0.35), 4)
	# A name over each end, so you know it's a tunnel and not the end of the road
	for end in [0, rows.size() - 1]:
		var sign_l := Label3D.new()
		sign_l.text = str(track.get("tunnel_name", "TUNNEL"))
		sign_l.font_size = 64
		sign_l.pixel_size = 0.02
		sign_l.outline_size = 16
		sign_l.modulate = Color(1.0, 0.92, 0.6)
		sign_l.outline_modulate = Color(0.15, 0.08, 0.2)
		sign_l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sign_l.position = rows[end] + Vector3.UP * (TUNNEL_TOP + 0.9)
		holder.add_child(sign_l)


# -----------------------------------------------------------------------------
# Features
# -----------------------------------------------------------------------------
func _inside() -> Vector2:
	# The middle of the loop (the average of its points)
	var sum := Vector2.ZERO
	for p in line:
		sum += Vector2(p.x, p.z)
	return sum / line.size()


func _lake() -> void:
	# A lake in the middle of the Lake Loop, as far out as it can go and still leave a bank before the road
	var mid := _inside()
	var r := INF
	for s in _samples:
		r = minf(r, s.distance_to(mid))
	r -= half_width() + 7.0
	var water := CylinderMesh.new()
	water.top_radius = r
	water.bottom_radius = r
	water.height = 0.1
	water.radial_segments = 48
	var m := _mat("Lake", Color(0.35, 0.8, 0.85, 0.85), 0.05, 0.15)
	m.metallic = 0.3
	var lake := _mesh(self, water, Vector3(mid.x, 0.06, mid.y), m, false)
	lake.name = "Lake"
	lake.scale = Vector3(1.0, 1.0, 1.0)
	var shore := CylinderMesh.new()
	shore.top_radius = r + 2.0
	shore.bottom_radius = r + 2.5
	shore.height = 0.08
	shore.radial_segments = 48
	_mesh(self, shore, Vector3(mid.x, 0.03, mid.y), _mat("Shore", Color(0.95, 0.88, 0.7)), false)
	# Lily pads and a little island with an orb tree
	for k in 14:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(4.0, r - 2.0)
		var pad := CylinderMesh.new()
		pad.top_radius = _rng.randf_range(0.6, 1.2)
		pad.bottom_radius = pad.top_radius
		pad.height = 0.04
		_mesh(self, pad, Vector3(mid.x + cos(a) * d, 0.13, mid.y + sin(a) * d), _mat("Lily Pad", Color(0.5, 0.9, 0.35)), false)
	_orb_tree(Vector3(mid.x, 0.0, mid.y), 1.6)
	var isle := CylinderMesh.new()
	isle.top_radius = 4.0
	isle.bottom_radius = 5.0
	isle.height = 0.6
	_mesh(self, isle, Vector3(mid.x, 0.1, mid.y), _mat("Island", Color(0.45, 0.8, 0.4)))


func _hill() -> void:
	# A big round hill in the middle with the Observatory's dome on top; the road climbs round its flanks
	var mid := _inside()
	var top := 0.0
	for p in line:
		top = maxf(top, p.y)
	var h := top + 6.0
	var r := INF
	for s in _samples:
		r = minf(r, s.distance_to(mid))
	r -= half_width() + 3.0
	var hill := SphereMesh.new()
	hill.radius = r
	hill.height = h * 2.0
	hill.radial_segments = 48
	hill.rings = 24
	_mesh(self, hill, Vector3(mid.x, 0.0, mid.y), _mat("Hill", Color(0.4, 0.74, 0.4)))
	var base := CylinderMesh.new()
	base.top_radius = 6.0
	base.bottom_radius = 6.5
	base.height = 5.0
	_mesh(self, base, Vector3(mid.x, h + 2.0, mid.y), _mat("Observatory", Color(0.92, 0.88, 0.98)))
	var dome := SphereMesh.new()
	dome.radius = 6.0
	dome.height = 6.0
	_mesh(self, dome, Vector3(mid.x, h + 4.5, mid.y), _mat("Dome", Color(0.62, 0.5, 0.95), 0.3))
	var scope := CylinderMesh.new()
	scope.top_radius = 0.9
	scope.bottom_radius = 1.2
	scope.height = 7.0
	var sc := _mesh(self, scope, Vector3(mid.x + 2.0, h + 8.0, mid.y), _mat("Telescope", Color(1.0, 0.82, 0.35), 0.4, 0.3))
	sc.rotation.z = -0.7
	for k in 3:
		var star := SphereMesh.new()
		star.radius = 1.4
		star.height = 2.8
		_mesh(self, star, Vector3(mid.x + cos(k * 2.1) * 30.0, h + 30.0 + k * 6.0, mid.y + sin(k * 2.1) * 30.0),
			_mat("Day Star", Color(1.0, 0.95, 0.6), 0.5, 3.0), false)


func _meadow() -> void:
	# The south meadow: flowers everywhere, in every colour the Void has
	var cols := [Color(1.0, 0.45, 0.75), Color(1.0, 0.85, 0.3), Color(0.6, 0.5, 1.0), Color(0.3, 0.95, 0.95), Color(1.0, 0.98, 0.9)]
	for ci in cols.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.4
		s.radial_segments = 6
		s.rings = 3
		mm.mesh = s
		var spots: Array[Transform3D] = []
		for k in 900:
			var p := Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-170, 170))
			if off_road(p) < half_width() + 2.0 or near_shortcut(p, 0.8):
				continue
			spots.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.7, 1.4)), Vector3(p.x, 0.35, p.y)))
		mm.instance_count = spots.size()
		for k in spots.size():
			mm.set_instance_transform(k, spots[k])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Flowers %d" % ci
		mi.multimesh = mm
		mi.material_override = _mat("Flower %d" % ci, cols[ci], 0.6, 0.3)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	for k in 10:                                         # giant mushrooms to wiggle round
		var p := _free_spot(half_width() + 6.0, 140.0)
		_mushroom(Vector3(p.x, 0, p.y), _rng.randf_range(1.5, 3.0))


func _farm() -> void:
	# Stars Hollow's farms in autumn: a red barn and a silo, a windmill, pumpkins and hay
	var mid := _inside()
	var barn := Node3D.new()
	barn.name = "Barn"
	barn.position = Vector3(mid.x + 10, 0, mid.y - 6)
	add_child(barn)
	var walls := BoxMesh.new()
	walls.size = Vector3(14, 8, 18)
	_mesh(barn, walls, Vector3(0, 4, 0), _mat("Barn", Color(0.72, 0.16, 0.12)))
	var roof := PrismMesh.new()
	roof.size = Vector3(15, 5, 19)
	_mesh(barn, roof, Vector3(0, 10.5, 0), _mat("Barn Roof", Color(0.3, 0.28, 0.3)))
	var door := BoxMesh.new()
	door.size = Vector3(5, 5.5, 0.2)
	_mesh(barn, door, Vector3(0, 2.75, 9.05), _mat("Barn Door", Color(0.95, 0.92, 0.85)))
	var silo := CylinderMesh.new()
	silo.top_radius = 3.0
	silo.bottom_radius = 3.0
	silo.height = 16
	_mesh(barn, silo, Vector3(10, 8, -4), _mat("Silo", Color(0.75, 0.75, 0.78)))
	var cap := SphereMesh.new()
	cap.radius = 3.0
	cap.height = 3.0
	_mesh(barn, cap, Vector3(10, 16, -4), _mat("Silo Cap", Color(0.45, 0.45, 0.5)))
	# Rows of pumpkins
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 0.8
	mm.mesh = s
	var spots: Array[Transform3D] = []
	for k in 500:
		var p := Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-170, 170))
		if off_road(p) < half_width() + 3.0 or near_shortcut(p, 1.0) or p.distance_to(Vector2(barn.position.x, barn.position.z)) < 16.0:
			continue
		spots.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.3)), Vector3(p.x, 0.3, p.y)))
	mm.instance_count = spots.size()
	for k in spots.size():
		mm.set_instance_transform(k, spots[k])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Pumpkins"
	mi.multimesh = mm
	mi.material_override = _mat("Pumpkin", Color(0.95, 0.5, 0.12), 0.7)
	add_child(mi)


func _hollow() -> void:
	# Dark Hollow: the misty hollow in the middle of the loop, with the Moon Clock standing in it, its hands ticking on
	# (it's mended now: Dark Hollow's moon pieces are why you're racing)
	var mid := _inside()
	var r := INF
	for s in _samples:
		r = minf(r, s.distance_to(mid))
	r -= half_width() + 8.0
	var pit := CylinderMesh.new()
	pit.top_radius = r
	pit.bottom_radius = r * 0.85
	pit.height = 0.3
	pit.radial_segments = 48
	_mesh(self, pit, Vector3(mid.x, 0.02, mid.y), _mat("Hollow Floor", Color(0.06, 0.05, 0.12)), false).name = "Hollow"
	# Mist lying in it, in see-through layers
	for k in 3:
		var mist := CylinderMesh.new()
		mist.top_radius = r * (0.95 - k * 0.12)
		mist.bottom_radius = mist.top_radius
		mist.height = 0.05
		mist.radial_segments = 40
		_mesh(self, mist, Vector3(mid.x, 0.5 + k * 0.9, mid.y), _mat("Mist %d" % k, Color(0.7, 0.65, 1.0, 0.16 - k * 0.04), 0.9, 0.4), false)
	# The Moon Clock on its crooked stone pillar
	var clock := Node3D.new()
	clock.name = "Moon Clock"
	clock.position = Vector3(mid.x, 0, mid.y)
	add_child(clock)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 1.6
	pillar.bottom_radius = 2.6
	pillar.height = 16.0
	pillar.radial_segments = 7
	_mesh(clock, pillar, Vector3(0, 8.0, 0), _mat("Pillar", Color(0.25, 0.22, 0.32)))
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, 21.0, 0)
	clock.add_child(face)
	var disc := CylinderMesh.new()
	disc.top_radius = 6.0
	disc.bottom_radius = 6.0
	disc.height = 0.8
	disc.radial_segments = 40
	_mesh(face, disc, Vector3.ZERO, _mat("Moon Face", Color(0.95, 0.92, 0.72), 0.5, 1.4), false).rotation.x = PI / 2.0
	var rim := TorusMesh.new()
	rim.inner_radius = 5.9
	rim.outer_radius = 6.6
	_mesh(face, rim, Vector3.ZERO, _mat("Clock Rim", Color(0.55, 0.45, 0.95), 0.4, 0.8), false).rotation.x = PI / 2.0
	for k in 12:
		var a := TAU * k / 12.0
		var tick := BoxMesh.new()
		tick.size = Vector3(0.35, 1.0 if k % 3 == 0 else 0.6, 0.2)
		var t := _mesh(face, tick, Vector3(sin(a) * 5.0, cos(a) * 5.0, 0.5), _mat("Clock Ink", Color(0.2, 0.14, 0.35)), false)
		t.rotation.z = -a
	for hand in [["Hour Hand", 3.0, 0.5], ["Minute Hand", 4.6, 0.32]]:
		var pivot := Node3D.new()
		pivot.name = str(hand[0])
		pivot.position = Vector3(0, 0, 0.62)
		face.add_child(pivot)
		var bar := BoxMesh.new()
		bar.size = Vector3(float(hand[2]), float(hand[1]), 0.12)
		_mesh(pivot, bar, Vector3(0, float(hand[1]) / 2.0 - 0.3, 0), _mat("Clock Ink", Color(0.2, 0.14, 0.35)), false)
	# (The clock faces the start straight, so you see it ticking as you come round)
	var start := line[0]
	face.look_at(Vector3(start.x, face.global_position.y if face.is_inside_tree() else 21.0, start.z), Vector3.UP)
	face.rotate_object_local(Vector3.UP, PI)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.82, 1.0)
	glow.light_energy = 2.5
	glow.omni_range = 40.0
	glow.position = Vector3(0, 20.0, 0)
	clock.add_child(glow)
	set_meta("moon_clock", face)


# -----------------------------------------------------------------------------
# Scenery
# -----------------------------------------------------------------------------
func _free_spot(near: float, far: float) -> Vector2:
	# Somewhere off the road (at least "near" from its middle) and not too far out
	for k in 60:
		var p := Vector2(_rng.randf_range(-far - 60.0, far + 60.0), _rng.randf_range(-far - 60.0, far + 60.0))
		var d := off_road(p)
		if d > near and d < far and not near_shortcut(p, 4.0):
			return p
	return Vector2(far, far)


func _void_scenery() -> void:
	for k in 46:
		var p := _free_spot(half_width() + 6.0, 90.0)
		if str(track.circuit.get("feature", "")) in ["lake", "hill"] and p.distance_to(_inside()) < 50.0 and _inside_loop(p):
			continue                                     # (the lake or the hill's there)
		match k % 3:
			0, 1:
				_orb_tree(Vector3(p.x, 0, p.y), _rng.randf_range(0.8, 1.5))
			2:
				_crystals(Vector3(p.x, 0, p.y))


func _inside_loop(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _samples)


func _dark_scenery() -> void:
	# Dark Hollow: crooked bare trees, glowing mushrooms and lamp posts along the road's edge
	for k in 44:
		var p := _free_spot(half_width() + 6.0, 95.0)
		if p.distance_to(_inside()) < 45.0 and _inside_loop(p):
			continue                                     # (the hollow's there)
		if k % 3 == 2:
			_glow_mushrooms(Vector3(p.x, 0, p.y))
		else:
			_crooked_tree(Vector3(p.x, 0, p.y), _rng.randf_range(0.8, 1.5))
	# Lamp posts round the outside of the road, every so far, warm lantern light (a real light on every third)
	var lamps := Node3D.new()
	lamps.name = "Lamp Posts"
	add_child(lamps)
	var n := line.size()
	var step := 26
	var lit := 0
	for i in range(0, n, step):
		var f := _fwd(i)
		var side := f.cross(Vector3.UP).normalized()
		var out := side if not _inside_loop(Vector2(line[i].x + side.x * 25.0, line[i].z + side.z * 25.0)) else -side
		var at := line[i] + out * (half_width() + 2.2)
		if near_shortcut(Vector2(at.x, at.z), 3.0):
			continue
		var post := Node3D.new()
		post.name = "Lamp Post"
		post.position = Vector3(at.x, line[i].y - 0.2, at.z)
		lamps.add_child(post)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.1
		pole.bottom_radius = 0.16
		pole.height = 4.6
		_mesh(post, pole, Vector3(0, 2.3, 0), _mat("Lamp Pole", Color(0.18, 0.14, 0.26)))
		var bulb := SphereMesh.new()
		bulb.radius = 0.38
		bulb.height = 0.76
		_mesh(post, bulb, Vector3(0, 4.8, 0), _mat("Lamp Glow", Color(1.0, 0.82, 0.45), 0.4, 3.0), false)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = 0.55
		cap.height = 0.45
		_mesh(post, cap, Vector3(0, 5.3, 0), _mat("Lamp Pole", Color(0.18, 0.14, 0.26)), false)
		if (i / step) % 3 == 0 and lit < 10:
			lit += 1
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.5)
			l.light_energy = 1.6
			l.omni_range = 13.0
			l.position = Vector3(0, 4.6, 0)
			post.add_child(l)


func _crooked_tree(at: Vector3, size: float) -> void:
	# A bare, twisty tree: a leaning trunk and a few bent branches, purple-black against the sky
	var tree := Node3D.new()
	tree.name = "Crooked Tree"
	tree.position = at
	tree.rotation.y = _rng.randf() * TAU
	add_child(tree)
	var bark := _mat("Night Bark", Color(0.12, 0.1, 0.16))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2 * size
	trunk.bottom_radius = 0.55 * size
	trunk.height = 6.0 * size
	var t := _mesh(tree, trunk, Vector3(0, 2.9 * size, 0), bark)
	t.rotation.z = _rng.randf_range(-0.2, 0.2)
	for b in 4:
		var br := CylinderMesh.new()
		br.top_radius = 0.04 * size
		br.bottom_radius = 0.18 * size
		br.height = _rng.randf_range(2.0, 3.4) * size
		var m := _mesh(tree, br, Vector3(0, (3.8 + b * 0.7) * size, 0), bark)
		var a := b * 1.7 + _rng.randf()
		m.rotation = Vector3(cos(a) * 0.9, 0, sin(a) * 0.9)
		m.position += Vector3(sin(a), 0.5, cos(a)) * 0.9 * size


func _glow_mushrooms(at: Vector3) -> void:
	# A clump of glowing mushrooms (teal, pink or gold), a bit of light in the dark
	var cols := [Color(0.3, 0.95, 0.95), Color(1.0, 0.45, 0.85), Color(1.0, 0.85, 0.35)]
	var holder := Node3D.new()
	holder.name = "Glow Mushrooms"
	holder.position = at
	add_child(holder)
	var col: Color = cols[_rng.randi() % cols.size()]
	for k in 4:
		var size := _rng.randf_range(0.5, 1.5)
		var off := Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6))
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.15 * size
		stalk.bottom_radius = 0.22 * size
		stalk.height = 1.4 * size
		_mesh(holder, stalk, off + Vector3(0, 0.7 * size, 0), _mat("Glow Stalk", Color(0.85, 0.85, 0.95)), false)
		var cap := SphereMesh.new()
		cap.radius = 0.8 * size
		cap.height = 0.8 * size
		_mesh(holder, cap, off + Vector3(0, 1.45 * size, 0), _mat("Glow Cap %s" % col.to_html(), col, 0.4, 2.2), false)


func _earth_scenery() -> void:
	var leaf := [Color(0.92, 0.45, 0.12), Color(0.85, 0.25, 0.12), Color(0.95, 0.75, 0.2), Color(0.55, 0.6, 0.2)]
	for k in 54:
		var p := _free_spot(half_width() + 5.0, 95.0)
		var tree := Node3D.new()
		tree.name = "Tree"
		tree.position = Vector3(p.x, 0, p.y)
		add_child(tree)
		var size := _rng.randf_range(0.8, 1.4)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.3 * size
		trunk.bottom_radius = 0.45 * size
		trunk.height = 4.0 * size
		_mesh(tree, trunk, Vector3(0, 2.0 * size, 0), _mat("Bark", Color(0.4, 0.27, 0.18)))
		var c: Color = leaf[k % leaf.size()]
		for b in 3:
			var ball := SphereMesh.new()
			ball.radius = (1.8 - b * 0.3) * size
			ball.height = ball.radius * 1.8
			ball.radial_segments = 10
			ball.rings = 6
			_mesh(tree, ball, Vector3(_rng.randf_range(-0.7, 0.7), (4.2 + b * 1.0) * size, _rng.randf_range(-0.7, 0.7)),
				_mat("Leaves %d" % (k % leaf.size()), c))
	# Hay bales and fences along the road's outside
	for k in 30:
		var p := _free_spot(half_width() + 3.0, half_width() + 9.0)
		var bale := CylinderMesh.new()
		bale.top_radius = 0.8
		bale.bottom_radius = 0.8
		bale.height = 1.3
		var b := _mesh(self, bale, Vector3(p.x, 0.8, p.y), _mat("Hay", Color(0.86, 0.7, 0.34)))
		b.rotation = Vector3(0, _rng.randf() * TAU, PI / 2.0)
	# A windmill on a hill, turning
	var mill := Node3D.new()
	mill.name = "Windmill"
	var at := _free_spot(40.0, 80.0)
	mill.position = Vector3(at.x, 0, at.y)
	add_child(mill)
	var tower := CylinderMesh.new()
	tower.top_radius = 2.0
	tower.bottom_radius = 3.4
	tower.height = 14.0
	_mesh(mill, tower, Vector3(0, 7, 0), _mat("Mill", Color(0.95, 0.92, 0.85)))
	var sails := Node3D.new()
	sails.name = "Sails"
	sails.position = Vector3(0, 13, 2.4)
	mill.add_child(sails)
	for k in 4:
		var sail := BoxMesh.new()
		sail.size = Vector3(1.4, 7.0, 0.15)
		var s := _mesh(sails, sail, Vector3.ZERO, _mat("Sail", Color(0.75, 0.55, 0.35)))
		s.rotation.z = k * PI / 2.0
		s.position = Vector3(sin(k * PI / 2.0) * -3.5, cos(k * PI / 2.0) * 3.5, 0)
	set_meta("sails", sails)


func _process(delta: float) -> void:
	var sails: Node3D = get_meta("sails") if has_meta("sails") else null
	if sails:
		sails.rotation.z += delta * 0.6
	var face: Node3D = get_meta("moon_clock") if has_meta("moon_clock") else null
	if face:
		# The Moon Clock's hands: the minute hand ticks round once a minute, the hour hand a twelfth as fast
		var t := Time.get_ticks_msec() / 1000.0
		(face.get_node("Minute Hand") as Node3D).rotation.z = -floorf(t) / 60.0 * TAU
		(face.get_node("Hour Hand") as Node3D).rotation.z = -t / 720.0 * TAU


func _orb_tree(at: Vector3, size: float) -> void:
	# The Void's orb trees: a leaning stalk and a big glowing ball (like scenes/town/trees.gd's, in shapes)
	var cols := [Color(1.0, 0.45, 0.75), Color(0.3, 0.95, 0.95), Color(0.75, 0.6, 1.0), Color(1.0, 0.82, 0.35)]
	var tree := Node3D.new()
	tree.name = "Orb Tree"
	tree.position = at
	tree.rotation.y = _rng.randf() * TAU
	add_child(tree)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.18 * size
	stalk.bottom_radius = 0.32 * size
	stalk.height = 5.0 * size
	var s := _mesh(tree, stalk, Vector3(0, 2.4 * size, 0), _mat("Stalk", Color(0.55, 0.4, 0.7)))
	s.rotation.z = 0.12
	var c: Color = cols[_rng.randi() % cols.size()]
	var orb := SphereMesh.new()
	orb.radius = 1.7 * size
	orb.height = 3.4 * size
	_mesh(tree, orb, Vector3(-0.6 * size, 5.4 * size, 0), _mat("Orb %s" % c.to_html(), c, 0.35, 0.7))
	for k in 2:
		var small := SphereMesh.new()
		small.radius = 0.6 * size
		small.height = 1.2 * size
		_mesh(tree, small, Vector3((k * 2 - 1) * 1.4 * size, 3.6 * size, 0.4), _mat("Orb %s" % c.to_html(), c, 0.35, 0.7))


func _crystals(at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Crystals"
	holder.position = at
	add_child(holder)
	for k in 5:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = _rng.randf_range(0.4, 0.9)
		c.height = _rng.randf_range(2.0, 5.0)
		c.radial_segments = 6
		var m := _mesh(holder, c, Vector3(_rng.randf_range(-1.2, 1.2), c.height * 0.4, _rng.randf_range(-1.2, 1.2)),
			_mat("Crystal", Color(0.45, 1.0, 0.6), 0.2, 1.2))
		m.rotation = Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))


func _mushroom(at: Vector3, size: float) -> void:
	var holder := Node3D.new()
	holder.name = "Mushroom"
	holder.position = at
	add_child(holder)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.5 * size
	stalk.bottom_radius = 0.7 * size
	stalk.height = 3.0 * size
	_mesh(holder, stalk, Vector3(0, 1.5 * size, 0), _mat("Mushroom Stalk", Color(0.98, 0.95, 0.88)))
	var cap := SphereMesh.new()
	cap.radius = 2.0 * size
	cap.height = 2.0 * size
	_mesh(holder, cap, Vector3(0, 3.2 * size, 0), _mat("Mushroom Cap", Color(0.62, 0.5, 0.95), 0.5, 0.3))


func _crowd(theme: String) -> void:
	# A stand full of friends cheering beside the start straight
	var i := line.size() - 30
	var side := (line[(i + 1) % line.size()] - line[i - 1]).normalized().cross(Vector3.UP).normalized()
	var stand := Node3D.new()
	stand.name = "Stand"
	add_child(stand)
	var at := line[i] - side * (half_width() + 8.0)
	stand.position = Vector3(at.x, 0, at.z)
	stand.look_at(Vector3(line[i].x, 0, line[i].z), Vector3.UP)
	stand.rotate_y(PI)                                   # (its +Z faces the road)
	var wood := _mat("Stand", Color(0.55, 0.38, 0.25) if theme == "earth" else Color(0.62, 0.5, 0.95))
	for step in 3:
		var bench := BoxMesh.new()
		bench.size = Vector3(22, 0.9, 2.2)
		_mesh(stand, bench, Vector3(0, 0.45 + step * 0.9, -step * 2.2), wood)
	var roof := BoxMesh.new()
	roof.size = Vector3(23, 0.25, 8.0)
	_mesh(stand, roof, Vector3(0, 6.0, -2.4), _mat("Stand Roof", Color(0.85, 0.2, 0.18) if theme == "earth" else Color(0.3, 0.85, 0.85)))
	for x in [-11.0, 11.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.3, 6.0, 0.3)
		_mesh(stand, post, Vector3(x, 3.0, -5.5), wood)
	if theme == "earth":
		var shirts := [Color(0.85, 0.25, 0.2), Color(0.25, 0.45, 0.85), Color(0.95, 0.75, 0.2), Color(0.35, 0.65, 0.35)]
		for k in 18:
			var fan := Node3D.new()
			fan.position = Vector3(-10 + (k % 9) * 2.5, 1.0 + (k / 9) * 0.9 + 0.9, -(k / 9) * 2.2 - 2.2)
			stand.add_child(fan)
			var body := CapsuleMesh.new()
			body.radius = 0.3
			body.height = 1.1
			_mesh(fan, body, Vector3(0, 0.55, 0), _mat("Fan %d" % (k % 4), shirts[k % 4]))
			var head := SphereMesh.new()
			head.radius = 0.25
			head.height = 0.5
			_mesh(fan, head, Vector3(0, 1.3, 0), _mat("Fan Face", Color(0.95, 0.78, 0.62)))
		return
	var colours := ["pink", "orange", "blue", "green", "purple", "yellow"]
	for k in 12:
		var path := "res://models/characters/little_alien_%s.glb" % colours[k % colours.size()]
		if not ResourceLoader.exists(path):
			continue
		var a := (load(path) as PackedScene).instantiate() as Node3D
		a.scale = Vector3.ONE * 1.6
		a.position = Vector3(-9 + (k % 6) * 3.6, 0.9 + (k / 6) * 0.9 + 0.9, -(k / 6) * 2.2 - 0.6)
		stand.add_child(a)
		var anim := a.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation("idle"):
			anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("idle")
