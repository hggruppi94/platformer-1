extends Node3D

# The Secret Garden's hill (26 Nov 2026, Hayden: "start over from scratch and make it 10x better", "make it way bigger.
# utilize inspiration from the worlds best arboretums and gardens"). The garden is a whole hidden estate on a hillside
# now, about 280 m wide and 320 m deep: you come in at the bottom through the old ivy door (z 0) and climb about 24 m to
# the Old House at the top (the north, +z). Plan: /mnt/project-files (the "Secret Garden, rebuilt" doc).
#
# Like scripts/rhythm_land.gd, this builds its own mesh and height map when the garden loads, and the one height() below
# is what the garden, its pieces and the tests all stand things on. The ground is:
#   - a gentle slope (base()), flat round the lakes at the bottom and rising to the top, never steeper than about 1 in 6;
#   - flat PADS for the gardens that sit level (the Formal Garden, the Overlook, the maze, the glasshouse...), each one
#     easing into the slope round its edge (a walkable bank), or with a stone wall for an edge where `blend` is tiny;
#   - LAKES pressed into the bottom (shallow enough to wade);
#   - the QUARRY, a pit sunk into its terrace, with a path winding down it.
# Paths are painted onto it in gravel (PATHS), and the formal lawns are mown in stripes.
# You can't step up a ledge on foot, so anything you walk between is joined by a slope or a stair walked as a ramp.

const X_HALF := 138.0                 # the garden's walls: x from -138 to 138...
const Z_MAX := 322.0                  # ...and z from 0 (the door's wall) to here
const GRID_X := Vector2i(-176, 176)   # the ground reaches past the walls, so you see hills over them
const GRID_Z := Vector2i(-40, 360)
const TOP := 24.0                     # the Overlook Terrace and the house
const WATER_Y := -0.15                # the lakes' surface

# Level pads: [name, x0, x1, z0, z1, height at z0, height at z1, blend]. Later ones win where they overlap.
const PADS := [
	["Entry Court", -24.0, 24.0, -2.0, 18.0, 0.0, 0.0, 4.0],
	["Tulip Slope", -26.0, 26.0, 95.0, 140.0, 0.0, 6.0, 8.0],
	["Water Terrace", -22.0, 22.0, 140.0, 150.0, 6.0, 6.0, 6.0],
	["Water Stairs", -22.0, 22.0, 150.0, 195.0, 6.0, 14.0, 6.0],
	["Cypress Terrace", -18.0, 18.0, 195.0, 206.0, 14.0, 14.0, 6.0],
	["Cypress Walk", -16.0, 16.0, 206.0, 240.0, 14.0, 18.0, 6.0],
	["Formal Garden", -58.0, 58.0, 240.0, 282.0, 18.0, 18.0, 7.0],
	["Hedge Maze", -128.0, -60.0, 236.0, 284.0, 16.0, 16.0, 8.0],
	["Rill Court", 62.0, 120.0, 244.0, 284.0, 18.0, 18.0, 7.0],
	["Parterre", 54.0, 128.0, 198.0, 236.0, 15.0, 15.0, 8.0],
	["Quarry Rim", -126.0, -58.0, 194.0, 232.0, 12.0, 12.0, 8.0],
	["Glasshouse", 60.0, 124.0, 150.0, 190.0, 9.0, 9.0, 8.0],
	["Supertree Grove", 58.0, 128.0, 100.0, 140.0, 3.0, 3.0, 10.0],
	["Tea Garden", -128.0, -66.0, 106.0, 136.0, 2.0, 2.0, 8.0],
	["Overlook", -64.0, 64.0, 285.0, 340.0, TOP, TOP, 0.25],
]
# The grand stair up the Overlook's wall, from the Formal Garden: [x0, x1, z0, z1, h0, h1] (walked as a ramp)
const STAIR_RAMPS := [
	[-5.5, 5.5, 271.0, 285.6, 18.0, TOP],
	[-49.5, -42.5, 271.0, 285.6, 18.0, TOP],
	[42.5, 49.5, 271.0, 285.6, 18.0, TOP],
]
# The lakes: [name, centre, radii, depth of the bed in the middle, the water's height]. Each outline wobbles a little
# (lake_r()); a lake that's not at the bottom sits on a pad of its own.
const LAKES := [
	["Temple Lake", Vector2(4.0, 56.0), Vector2(36.0, 24.0), 1.05, WATER_Y],
	["Temple Lake Arm", Vector2(56.0, 50.0), Vector2(16.0, 7.0), 0.8, WATER_Y],
	["Lily Pond", Vector2(-90.0, 54.0), Vector2(27.0, 18.0), 0.85, WATER_Y],
	["Koi Pond", Vector2(-102.0, 119.0), Vector2(11.0, 7.0), 0.75, 1.85],
]
# Islands standing up out of the lakes: [centre, radius, top]
const ISLANDS := [
	[Vector2(-78.0, 52.0), 4.6, 0.25],
]
# Streams cut into the ground: [points (x, z), half width, depth]
const STREAMS := [
	[[Vector2(-96.0, 112.0), Vector2(-94.0, 104.0), Vector2(-91.0, 95.0), Vector2(-87.0, 85.0), Vector2(-85.0, 70.0)], 1.5, 0.55],
]
const QUARRY := Vector3(-92.0, 213.0, 15.0)      # the Sunken Quarry Garden: centre x, z and its floor's radius
const QUARRY_FLOOR := 2.0
const QUARRY_WALL := 7.0                         # how far its cliffs take to rise from the floor to the rim

# Gravel paths: [points (x, z), half width]. They're painted on the ground (you walk on the ground under them).
const PATHS := [
	[[Vector2(0, -2), Vector2(0, 16)], 2.2],                                                     # from the door
	[[Vector2(0, 16), Vector2(-22, 22), Vector2(-42, 36), Vector2(-47, 58), Vector2(-44, 78), Vector2(-36, 94),
		Vector2(-14, 100), Vector2(0, 100)], 1.8],                                               # round the lake, west
	[[Vector2(0, 16), Vector2(24, 22), Vector2(44, 30), Vector2(50, 38), Vector2(50, 64), Vector2(42, 80),
		Vector2(26, 92), Vector2(8, 98), Vector2(0, 100)], 1.8],                                 # ...and east, over the bridge
	[[Vector2(-30, 81), Vector2(-40, 86)], 1.4],                                                # to the temple
	[[Vector2(0, 100), Vector2(0, 140)], 2.2],                                                  # up the Tulip Slope
	[[Vector2(0, 206), Vector2(0, 240)], 3.0],                                                  # the Cypress Walk
	[[Vector2(0, 240), Vector2(0, 271)], 2.4],                                                  # the Formal Garden's cross
	[[Vector2(-58, 261), Vector2(58, 261)], 2.0],
	[[Vector2(-46, 248), Vector2(-46, 271)], 1.6],                                              # ...to the side stairs
	[[Vector2(46, 248), Vector2(46, 271)], 1.6],
	[[Vector2(-58, 246), Vector2(58, 246)], 1.6],
	[[Vector2(-130, 144), Vector2(-60, 141), Vector2(-26, 138)], 1.6],                          # across, low down
	[[Vector2(26, 120), Vector2(60, 122), Vector2(78, 116), Vector2(108, 116), Vector2(128, 120)], 1.6],
	[[Vector2(-130, 172), Vector2(-60, 170), Vector2(-24, 172)], 1.6],                          # across the middle
	[[Vector2(24, 172), Vector2(56, 162), Vector2(92, 155), Vector2(92, 160)], 1.6],          # to the Glasshouse
	[[Vector2(92, 180), Vector2(92, 196)], 1.6],
	[[Vector2(-31, 171), Vector2(-32, 167)], 1.4],                                              # to the Treetop Walk
	[[Vector2(-128, 188), Vector2(-96, 186), Vector2(-60, 189), Vector2(-18, 200)], 1.6],                          # by the Cypress Terrace
	[[Vector2(18, 200), Vector2(54, 196), Vector2(128, 196)], 1.6],
	[[Vector2(-78, 261.5), Vector2(-60, 262), Vector2(-58, 262)], 1.6],                         # maze to formal
	[[Vector2(-78, 194.6), Vector2(-74, 188.5)], 1.4],                                          # to the quarry ramp
	[[Vector2(58, 262), Vector2(62, 262)], 1.6],                                                # formal to rill court
	[[Vector2(-47, 58), Vector2(-63, 52)], 1.4],                                                # to the green bridge
	[[Vector2(-62, 70), Vector2(-72, 90), Vector2(-84, 100), Vector2(-100, 104), Vector2(-116, 110),
		Vector2(-118, 126), Vector2(-108, 136), Vector2(-90, 140)], 1.3],                       # the Japanese Garden
	[[Vector2(-44, 78), Vector2(-62, 70)], 1.4],
	[[Vector2(74, 30), Vector2(90, 60), Vector2(92, 100)], 1.6],                                # the Rose Walk up
	[[Vector2(24, 22), Vector2(74, 30)], 1.6],
	[[Vector2(-22, 22), Vector2(-60, 40)], 1.4],
]

static var _cache := {}


static func ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func base(x: float, z: float) -> float:
	# The hill: level by the lakes, rising to about 22 m at the top, with a gentle roll; outside the walls it rises on
	# into wooded hills (you see them over the walls, you can't get there)
	var h := 22.0 * ss(95.0, 300.0, z)
	h += 0.6 * sin(x * 0.047 + 0.8) * cos(z * 0.039) * ss(60.0, 140.0, z)
	var out := maxf(maxf(absf(x) - X_HALF, z - Z_MAX), -z)
	if out > 0.0:
		h += out * 0.45 + 2.5 * sin(x * 0.06 + z * 0.03) * ss(0.0, 30.0, out)
	return h


static func pad_in(p: Array, x: float, z: float) -> float:
	# How far inside a pad this spot is, in metres (less than 0: outside)
	return minf(minf(x - float(p[1]), float(p[2]) - x), minf(z - float(p[3]), float(p[4]) - z))


static func pad_height(p: Array, z: float) -> float:
	return lerpf(float(p[5]), float(p[6]), clampf((z - float(p[3])) / (float(p[4]) - float(p[3])), 0.0, 1.0))


static func lake_r(lake: Array, x: float, z: float) -> float:
	# How far out from a lake's middle this is, 1 at its shore (a wobbly ellipse)
	var c: Vector2 = lake[1]
	var r: Vector2 = lake[2]
	var d := Vector2((x - c.x) / r.x, (z - c.y) / r.y)
	var a := atan2(d.y, d.x)
	return d.length() / (1.0 + 0.07 * sin(3.0 * a + c.x) + 0.04 * sin(5.0 * a + 1.3))


static func in_lake(x: float, z: float, margin := 0.0) -> String:
	# Which lake this is in ("" for none), margin metres out past the shore too
	for lake in LAKES:
		var r: Vector2 = lake[2]
		if lake_r(lake, x, z) < 1.0 + margin / minf(r.x, r.y):
			return lake[0]
	return ""


static func quarry_dist(x: float, z: float) -> float:
	return Vector2(x - QUARRY.x, z - QUARRY.y).length()


static func land(x: float, z: float) -> float:
	# The ground before the stairs
	var h := base(x, z)
	for p in PADS:
		var d := pad_in(p, x, z)
		var blend: float = p[7]
		if d > -blend:
			h = lerpf(h, pad_height(p, z), ss(-blend, 0.0, d))
	for lake in LAKES:
		var lr := lake_r(lake, x, z)
		if lr < 1.25:
			# The shore falls gently past the waterline to the bed (each lake at its own water height)
			var surf: float = lake[4]
			var bed := surf + 0.15 - (float(lake[3]) + 0.15) * ss(1.0, 0.45, lr)
			h = minf(h, lerpf(bed, h, ss(0.95, 1.25, lr)))
	for isle in ISLANDS:
		var c: Vector2 = isle[0]
		var r: float = isle[1]
		var d := Vector2(x, z).distance_to(c)
		if d < r + 3.0:
			h = maxf(h, lerpf(float(isle[2]), h, ss(r, r + 3.0, d)))
	var sd := stream_dist(x, z)
	if sd < 1.0:
		h -= float(STREAMS[0][2]) * ss(1.0, -0.4, sd)
	var q := quarry_dist(x, z)
	if q < QUARRY.z + QUARRY_WALL + 0.5:
		h = lerpf(QUARRY_FLOOR, h, ss(QUARRY.z, QUARRY.z + QUARRY_WALL, q))
	return h


static func stair_at(x: float, z: float) -> float:
	# The height of a stair's ramp here, or -1000 if not on one
	for s in STAIR_RAMPS:
		if x >= s[0] and x <= s[1] and z >= s[2] and z <= s[3]:
			return lerpf(float(s[4]), float(s[5]), (z - float(s[2])) / (float(s[3]) - float(s[2])))
	return -1000.0


static func height(x: float, z: float) -> float:
	# The ground's height anywhere in (and round) the garden. Cached to the centimetre grid, since lots ask.
	var key := Vector2i(roundi(x * 4.0), roundi(z * 4.0))
	if _cache.has(key):
		return _cache[key]
	var h := land(x, z)
	var st := stair_at(x, z)
	if st > -999.0:
		h = st
	if _cache.size() > 400000:
		_cache.clear()
	_cache[key] = h
	return h


static func slope(x: float, z: float) -> float:
	return Vector2(land(x + 0.5, z) - land(x - 0.5, z), land(x, z + 0.5) - land(x, z - 0.5)).length()


static func _line_dist(pts: Array, x: float, z: float) -> float:
	var best := INF
	var p := Vector2(x, z)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


static func stream_dist(x: float, z: float) -> float:
	var best := INF
	for st in STREAMS:
		best = minf(best, _line_dist(st[0], x, z) - float(st[1]))
	return best


static func path_dist(x: float, z: float) -> float:
	# How far this is from the edge of the nearest gravel path (less than 0: on one)
	var best := INF
	var p := Vector2(x, z)
	for path in PATHS:
		var pts: Array = path[0]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a.lerp(b, t)) - float(path[1]))
	return best


static func pad_named(n: String) -> Array:
	for p in PADS:
		if p[0] == n:
			return p
	return []


static func on_pad(x: float, z: float, margin := 0.0) -> String:
	# The pad this is on ("" for none), at least margin metres in from its edge
	var found := ""
	for p in PADS:
		if pad_in(p, x, z) >= margin:
			found = p[0]
	return found


static func color_at(x: float, z: float, h: float, steep: float) -> Color:
	var grain := 0.5 + 0.5 * sin(x * 0.37 + z * 0.21) * cos(z * 0.43 - x * 0.17)
	var lake := ""
	var surface := WATER_Y
	for l in LAKES:
		if lake_r(l, x, z) < 1.08:
			lake = l[0]
			surface = l[4]
	if h < surface + 0.12 and lake != "":
		return Color(0.32, 0.36, 0.3).lerp(Color(0.42, 0.42, 0.34), grain)          # mud under the water
	if lake != "" and h < surface + 0.35:
		return Color(0.55, 0.5, 0.38).lerp(Color(0.48, 0.5, 0.36), grain)          # a damp shore
	if stream_dist(x, z) < 0.6:
		return Color(0.45, 0.44, 0.4).lerp(Color(0.56, 0.54, 0.5), grain)          # the stream's pebbly bed
	if quarry_dist(x, z) < QUARRY.z + QUARRY_WALL and steep > 0.5:
		# The old quarry's cliffs: pale limestone in layers
		var band := int(floor(h / 1.2 + 0.3 * sin(x * 0.2 + z * 0.15)))
		var cols := [Color(0.74, 0.72, 0.68), Color(0.66, 0.63, 0.6), Color(0.8, 0.77, 0.7)]
		return (cols[posmod(band, 3)] as Color).darkened(0.08 * grain)
	var outside := absf(x) > X_HALF or z > Z_MAX or z < 0.0
	if path_dist(x, z) < 0.0 and not outside:
		return Color(0.82, 0.76, 0.64).lerp(Color(0.74, 0.68, 0.58), grain)
	var grass := Color(0.3, 0.55, 0.27).lerp(Color(0.4, 0.62, 0.3), grain)
	if outside:
		return Color(0.22, 0.4, 0.22).lerp(Color(0.3, 0.46, 0.25), grain)
	var pad := on_pad(x, z, 1.0)
	if pad in ["Formal Garden", "Overlook", "Cypress Walk", "Cypress Terrace", "Rill Court", "Entry Court"]:
		# A mown lawn: stripes 3 m wide, light and dark
		var stripe := posmod(int(floor(x / 3.0)), 2)
		grass = Color(0.36, 0.62, 0.3) if stripe == 0 else Color(0.3, 0.55, 0.27)
	if steep > 0.42:
		grass = grass.lerp(Color(0.42, 0.4, 0.3), clampf((steep - 0.42) * 1.6, 0.0, 0.7))
	return grass


func _ready() -> void:
	if get_child_count() == 0:
		build()


func build() -> void:
	var wx := GRID_X.y - GRID_X.x + 1
	var wz := GRID_Z.y - GRID_Z.x + 1
	var heights := PackedFloat32Array()
	heights.resize(wx * wz)
	for j in wz:
		for i in wx:
			heights[j * wx + i] = height(i + GRID_X.x, j + GRID_Z.x)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(wx * wz)
	normals.resize(wx * wz)
	colors.resize(wx * wz)
	for j in wz:
		for i in wx:
			var k := j * wx + i
			var h := heights[k]
			var hl := heights[j * wx + maxi(i - 1, 0)]
			var hr := heights[j * wx + mini(i + 1, wx - 1)]
			var hu := heights[maxi(j - 1, 0) * wx + i]
			var hd := heights[mini(j + 1, wz - 1) * wx + i]
			var x := float(i + GRID_X.x)
			var z := float(j + GRID_Z.x)
			verts[k] = Vector3(x, h, z)
			normals[k] = Vector3(hl - hr, 2.0, hu - hd).normalized()
			colors[k] = color_at(x, z, h, Vector2(hl - hr, hu - hd).length() * 0.5)
	var idx := PackedInt32Array()
	idx.resize((wx - 1) * (wz - 1) * 6)
	var q := 0
	for j in wz - 1:
		for i in wx - 1:
			var a := j * wx + i
			idx[q] = a
			idx[q + 1] = a + 1
			idx[q + 2] = a + wx
			idx[q + 3] = a + 1
			idx[q + 4] = a + wx + 1
			idx[q + 5] = a + wx
			q += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.resource_name = "Garden Land"
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Garden Hill"
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Garden Ground"
	# The height map's middle is its centre point, so the body sits at the grid's middle
	body.position = Vector3((GRID_X.x + GRID_X.y) / 2.0, 0, (GRID_Z.x + GRID_Z.y) / 2.0)
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = wx
	shape.map_depth = wz
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.name = "Ground Shape"
	cs.shape = shape
	body.add_child(cs)
