extends Node3D

# Rhythm Springs' island ground (tools/build_rhythm_springs.gd puts this node in the scene). Like scripts/earth_land.gd
# it builds its own mesh and height map when the world loads, so the scene keeps no huge ground in it, and the one
# height() below is what the builder, the game and the tests all stand things on.
#
# Hayden's pictures (16 Nov 2026) have cliffs and many levels, so the island isn't flat: round the valley (which stays
# flat, at 0) the land rises in terraces with steep sandstone cliffs between them:
#   - the North Highlands, two tiers (10 m, then 22 m), dropping straight into the sea, with the crystal cave and the
#     waterfall grotto in notches at the foot of the lower tier, and the big waterfall off the upper tier;
#   - the East Headland (12 m) with the overlook out over the sea;
#   - the Pavilion Bluff (6 m) in the south-east, the pavilion on its sea edge;
#   - the Gate Terrace (6 m) south of the valley: the torch path climbs to it from the beach through a cutting between
#     rock walls, and the Springs Gate stands on top looking down into the valley;
#   - the West Terrace (7 m): the bamboo grove's long path and the legend hut.
# You can't step up a ledge on foot, so every level is reached by a ramp (RAMPS), cut into the cliff or built up on it.
#
# Hayden then asked (16 Nov 2026) whether it all makes sense geographically. So the island is an old volcano: the
# terraces round the valley are what's left of its rim (the valley is its crater, which is why it has hot springs),
# and its last peak (PEAKS) still stands on the North Highlands, with a little crater lake on top. A spring at its
# foot feeds the big waterfall, and the water runs on out of the valley to the sea (the builder's creek).

const SHORE_BASE := 118.0
const CLIFF_W := 1.4                  # how far a cliff takes to go from its foot to its top: steep, never walkable
const GRID := 170                     # the ground covers -GRID..GRID in x and z, a metre a step
const VALLEY_R := 54.5                # inside this the valley's own sand floor is the ground

# Terraces: [centre angle (degrees round, 0 east, 90 south), half its span (degrees), inner radius, outer radius (0 or
# less: that far in from the shore, so it drops straight into the sea), height]
const PLATEAUS := [
	[276.0, 54.0, 66.0, -1.0, 10.0],      # North Highlands, lower tier (222 to 330 degrees)
	[262.0, 30.0, 86.0, -1.0, 22.0],      # North Highlands, upper tier
	[0.0, 24.0, 80.0, -1.0, 12.0],        # East Headland
	[54.0, 12.0, 82.0, -1.0, 6.0],        # Pavilion Bluff
	[90.0, 26.0, 60.0, 86.0, 6.0],        # Gate Terrace
	[195.0, 22.0, 64.0, -7.0, 7.0],       # West Terrace
]
# The old volcano's last peak, standing up off the North Highlands' upper tier: [angle, radius out, how far its foot
# reaches, the height it stands on, its rim's height]. Too steep to climb; it's to look at from all over the island.
const PEAKS := [
	[248.0, 101.0, 12.0, 22.0, 40.0],
]
const CRATER_R := 3.6                 # the crater in its top
const CRATER_DEEP := 5.0              # how far down the crater lake is from the rim
# Notches cut back to the lowland at the foot of a cliff: [angle, radius out, size, floor height]
const NOTCHES := [
	[315.0, 64.0, 12.5, 0.0],             # the crystal cave
	[285.0, 62.0, 10.5, 0.0],             # the waterfall grotto
]
# Ramps up the cliffs: a list of [angle, radius, height] points and the half width of the way up
const RAMPS := [
	[[[90.0, 99.0, 0.0], [90.0, 86.0, 3.2], [90.0, 73.0, 6.0]], 2.4],     # the torch path, up from the beach to the gate
	[[[90.0, 67.0, 6.0], [90.0, 55.0, 0.0]], 2.6],                         # ...and down from the gate into the valley
	[[[236.0, 57.0, 0.0], [240.0, 70.0, 5.0], [246.0, 82.0, 10.0]], 2.0],  # up the North Highlands' lower tier
	[[[302.0, 76.0, 10.0], [292.0, 80.0, 16.0], [280.0, 88.0, 22.0]], 2.0],    # ...and on up to the upper tier
	[[[-16.0, 70.0, 0.0], [-10.0, 84.0, 6.0], [-5.0, 96.0, 12.0]], 2.0],  # up the East Headland
	[[[46.0, 72.0, 0.0], [50.0, 87.0, 6.0]], 2.0],                         # up the Pavilion Bluff
	[[[184.0, 57.0, 0.0], [189.0, 75.0, 7.0]], 2.2],                       # up the West Terrace to the bamboo grove
]

static var _ramp_pts: Array = []


static func shore_r(theta: float) -> float:
	# How far out the beach meets the sea at each angle round the island (θ = atan2(z, x)): a wobbly coast, about
	# 95 to 140 m from the middle
	return SHORE_BASE + 13.0 * sin(2.0 * theta + 0.6) + 7.0 * sin(3.0 * theta + 1.9) + 3.5 * sin(7.0 * theta + 0.3)


static func beach(r: float, rs: float) -> float:
	# The low ground: flat inland, a beach sloping into the sea and a seabed falling away
	if r <= rs - 10.0:
		return -0.02
	if r <= rs:
		return lerpf(-0.02, -0.6, (r - (rs - 10.0)) / 10.0)
	if r <= rs + 12.0:
		return lerpf(-0.6, -3.0, (r - rs) / 12.0)
	return lerpf(-3.0, -8.0, clampf((r - rs - 12.0) / 30.0, 0.0, 1.0))


static func at(deg: float, r: float, h := 0.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(cos(a) * r, h, sin(a) * r)


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func peak_rise(x: float, z: float) -> float:
	# How far the volcano's peak rises above the upper tier here (0 off it). Its sides steepen towards a ragged rim,
	# lowest where it broke away on the sea side, and a crater dips in the middle.
	for pk in PEAKS:
		var c := at(pk[0], pk[1])
		var off := Vector2(x - c.x, z - c.z)
		var d := off.length()
		var phi := atan2(off.y, off.x)
		var foot: float = float(pk[2]) * (1.0 + 0.1 * sin(5.0 * phi + 1.0) + 0.05 * sin(11.0 * phi))
		if d >= foot:
			continue
		var rim := CRATER_R + 1.0
		var t := clampf((foot - d) / (foot - rim), 0.0, 1.0)
		var rise: float = (float(pk[4]) - float(pk[3])) * pow(t, 1.5)
		# The broken side faces out to sea
		var sea := deg_to_rad(float(pk[0]))
		rise *= 1.0 - 0.3 * pow(maxf(0.0, cos(phi - sea)), 3.0) * t
		if d < rim:
			rise -= CRATER_DEEP * _ss(rim, CRATER_R - 1.6, d)
		return rise
	return 0.0


static func peak_top() -> Vector3:
	# The middle of the crater, at its floor
	var pk: Array = PEAKS[0]
	var c := at(pk[0], pk[1])
	return Vector3(c.x, land(c.x, c.z), c.z)


static func plateau_in(p: Array, theta: float, r: float, rs: float) -> float:
	# How far inside a terrace this spot is, in metres (less than 0: outside), with wobbly edges so the cliffs look
	# natural
	var c_deg: float = p[0]
	var span: float = p[1]
	var r0: float = p[2]
	var r1: float = p[3] if p[3] > 0.0 else rs + p[3]
	var dd := absf(wrapf(rad_to_deg(theta) - c_deg, -180.0, 180.0))
	var wob := 1.6 * sin(theta * 11.0 + c_deg) + 0.9 * sin(theta * 27.0 + r0)
	var side := deg_to_rad(span - dd) * r + 1.4 * sin(r * 0.31 + c_deg)
	return minf(minf(r - r0 + wob, r1 - r + (0.6 * sin(theta * 17.0) if p[3] > 0.0 else 0.0)), side)


static func ramp_points() -> Array:
	if _ramp_pts.is_empty():
		for rp in RAMPS:
			var pts: Array = []
			for q in rp[0]:
				pts.append(at(q[0], q[1], q[2]))
			_ramp_pts.append([pts, rp[1]])
	return _ramp_pts


static func ramp_at(x: float, z: float) -> Vector3:
	# The nearest ramp here: Vector3(its height, how far from its middle line, its half width), or y -1 if none near
	var best := Vector3(0, 1e9, -1.0)
	var flat := Vector2(x, z)
	for rp in ramp_points():
		var pts: Array = rp[0]
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var a2 := Vector2(a.x, a.z)
			var b2 := Vector2(b.x, b.z)
			var u := clampf((flat - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
			var d := flat.distance_to(a2.lerp(b2, u))
			if d < best.y:
				best = Vector3(lerpf(a.y, b.y, u), d, rp[1])
	return best


static func land(x: float, z: float) -> float:
	# The terraces and the beach, before the ramps and notches
	var r := Vector2(x, z).length()
	var theta := atan2(z, x)
	var rs := shore_r(theta)
	var h := beach(r, rs)
	for p in PLATEAUS:
		var d := plateau_in(p, theta, r, rs)
		if d > 0.0:
			h = maxf(h, float(p[4]) * _ss(0.0, CLIFF_W, d))
	if h > 20.0:
		h += peak_rise(x, z)
	for n in NOTCHES:
		var c := at(n[0], n[1])
		var dist := Vector2(x - c.x, z - c.z).length()
		h = lerpf(float(n[3]), h, _ss(float(n[2]), float(n[2]) + CLIFF_W, dist))
	return h


static func height(x: float, z: float) -> float:
	# The ground's height anywhere on the island
	if Vector2(x, z).length() < VALLEY_R:
		var rp0 := ramp_at(x, z)
		return maxf(-0.05, rp0.x) if rp0.z > 0.0 and rp0.y < rp0.z and rp0.x > 0.0 else -0.05
	var h := land(x, z)
	var rp := ramp_at(x, z)
	if rp.z > 0.0 and rp.y < rp.z + 2.5:
		h = lerpf(rp.x, h, _ss(rp.z, rp.z + 2.5, rp.y))
	return h


static func on_ramp(x: float, z: float, room := 0.0) -> bool:
	var rp := ramp_at(x, z)
	return rp.z > 0.0 and rp.y < rp.z + room


static func slope(x: float, z: float) -> float:
	# How steep the ground is here (rise over run)
	return Vector2(height(x + 0.5, z) - height(x - 0.5, z), height(x, z + 0.5) - height(x, z - 0.5)).length()


static func color_at(x: float, z: float, h: float, steep: float) -> Color:
	var r := Vector2(x, z).length()
	var rs := shore_r(atan2(z, x))
	var grain := 0.5 + 0.5 * sin(x * 0.37 + z * 0.21) * cos(z * 0.43 - x * 0.17)
	if h > 22.3 and steep > 0.3:
		# The volcano's peak: dark old lava rock in layers, rusty near the top
		var vband := int(floor(h / 2.2 + 0.4 * sin(x * 0.13 + z * 0.11)))
		var vcols := [Color(0.3, 0.24, 0.27), Color(0.4, 0.3, 0.29), Color(0.25, 0.21, 0.25), Color(0.5, 0.33, 0.27)]
		return (vcols[posmod(vband, 4)] as Color).darkened(0.1 * grain)
	if steep > 1.1:
		# Banded sandstone, like the cliffs in the pictures: warm orange, red and pale layers, each band about 1.6 m
		var band := int(floor(h / 1.6 + 0.3 * sin(x * 0.09 + z * 0.07)))
		var cols := [Color(0.88, 0.58, 0.38), Color(0.8, 0.46, 0.33), Color(0.93, 0.7, 0.5), Color(0.84, 0.52, 0.36)]
		return (cols[posmod(band, 4)] as Color).darkened(0.08 * grain)
	if on_ramp(x, z, 0.4):
		return Color(0.88, 0.7, 0.5).lerp(Color(0.8, 0.62, 0.44), grain)
	if h < 0.1 and r > rs - 11.0:
		if h < -0.7:
			return Color(0.78, 0.68, 0.52)                                # under the sea
		return Color(0.95, 0.83, 0.62).lerp(Color(0.9, 0.76, 0.56), grain)
	if steep > 0.45:
		return Color(0.55, 0.6, 0.32).lerp(Color(0.86, 0.62, 0.42), (steep - 0.45) / 0.65)
	var grass := Color(0.45, 0.72, 0.34).lerp(Color(0.55, 0.78, 0.36), grain)
	if h > 3.0:
		grass = grass.lerp(Color(0.38, 0.66, 0.3), 0.4)
	# A sandy fringe where the grass meets the beach
	return grass.lerp(Color(0.92, 0.8, 0.58), _ss(rs - 16.0, rs - 10.5, r))


func _ready() -> void:
	if get_child_count() == 0:
		build()


func build() -> void:
	var w := GRID * 2 + 1
	var heights := PackedFloat32Array()
	heights.resize(w * w)
	for j in w:
		for i in w:
			heights[j * w + i] = height(i - GRID, j - GRID)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(w * w)
	normals.resize(w * w)
	colors.resize(w * w)
	for j in w:
		for i in w:
			var k := j * w + i
			var h := heights[k]
			var hl := heights[j * w + maxi(i - 1, 0)]
			var hr := heights[j * w + mini(i + 1, w - 1)]
			var hu := heights[maxi(j - 1, 0) * w + i]
			var hd := heights[mini(j + 1, w - 1) * w + i]
			verts[k] = Vector3(i - GRID, h, j - GRID)
			normals[k] = Vector3(hl - hr, 2.0, hu - hd).normalized()
			colors[k] = color_at(i - GRID, j - GRID, h, Vector2(hl - hr, hu - hd).length() * 0.5)
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (w - 1) * 6)
	var q := 0
	for j in w - 1:
		for i in w - 1:
			var a := j * w + i
			idx[q] = a
			idx[q + 1] = a + 1
			idx[q + 2] = a + w
			idx[q + 3] = a + 1
			idx[q + 4] = a + w + 1
			idx[q + 5] = a + w
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
	m.resource_name = "Island Land"
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Island Terrain"
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Island Ground"
	add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = w
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.name = "Ground Shape"
	cs.shape = shape
	body.add_child(cs)
