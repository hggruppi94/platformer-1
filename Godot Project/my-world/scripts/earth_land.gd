class_name EarthLand
extends StaticBody3D

# The ground of the Earth town (scenes/earth/earth.tscn): one height for every spot, shared by the builder
# (tools/build_earth.gd puts things on it), the game (this node makes the ground's mesh and collision when the town
# loads, so no big binary ground file has to live in the repo) and the tests. Mostly flat, as a town is, with:
# - Willow Pond in the park west of the green, a shallow bowl you can wade into,
# - Whisper Creek, from the foot of Mossy Falls down into the pond and out again, south under the covered bridge,
# - Lookout Hill in the northwest, a broad round hill with gentle slopes to ride down, and a rocky cliff on its pond
#   side where the falls come over,
# - rolling hills (ROLLS, since Oct 31, 2026) in the open ground the town hasn't built on: the east fields, the
#   meadows north of the creek path, west of the creek and past the back gardens of Maple Lane. Gentle round humps
#   to roll and pump over on a board, never on a street, path, building or yard,
# - and past the walls, the countryside (country()): flat at the town's edge, then rolling up into fields and wooded
#   hills, so the town sits in a valley. That part is only to look at, so it has a mesh and no collision.
# Water sits at WATER_Y; scripts/water.gd (wading, splashes) gets the pond and the creek as circles and ellipses.

const X0 := -160.0                       # the ground covers x X0..X1 and z Z0..Z1, one metre a step
const X1 := 100.0
const Z0 := -160.0
const Z1 := 110.0
const WATER_Y := -0.35
const POND := Vector4(-85, 0, 20, 14)    # centre x, centre z, radius x, radius z (where the bank starts to dip)
const POND_DEPTH := 1.7
const CREEK := [Vector2(-104, -77), Vector2(-100, -55), Vector2(-95, -35), Vector2(-90, -17), Vector2(-85, 0),
	Vector2(-89, 16), Vector2(-95, 32), Vector2(-101, 46), Vector2(-103, 58), Vector2(-106, 80), Vector2(-108, 112)]
const CREEK_HALF := 2.6                  # half the creek's width at the water line, about
const CREEK_DEPTH := 1.2
const FALLS_POOL := Vector3(-104, 0, -77)  # x, radius 5 (y unused), z: the plunge pool at the foot of the falls
const HILL := Vector2(-110, -100)        # Lookout Hill's middle
const HILL_TOP := 6.5                    # its flat top's height
const HILL_FLAT := 16.0                  # the flat top's radius
const HILL_SLOPE := 28.0                 # how far the gentle slopes run out from the top's edge
const CLIFF := 3.0                       # ...and how far the cliff does, on the falls side

# The rolling hills: x, z, radius, height. Each is a smooth round hump (a cosine bump) and they add up where they
# overlap, so neighbours run together into a roll of hills. Each one stays inside open ground (test_earth checks
# nothing built sits on one), and their slopes stay under about 25 degrees, so a board rolls up and over them.
const ROLLS := [
	# The east fields, past the Corner Market and the skate yard, up to the wall
	Vector4(72, -134, 15, 4.2), Vector4(70, -104, 17, 4.8), Vector4(76, -76, 14, 3.9), Vector4(70, -50, 15, 4.2),
	Vector4(76, -24, 13, 3.5), Vector4(78, 0, 11, 2.5), Vector4(56, -60, 9, 2),
	# South of the dance studio, east of Maple Lane's last house
	Vector4(72, 36, 14, 3.5),
	# The meadow north of the creek path, between Lookout Hill's run-out and Main Street's back lots
	Vector4(-46, -138, 12, 3.4), Vector4(-48, -66, 11, 3),
	# West of the creek: between the hill and the pumpkin patch, and past Maple Lane's west end
	Vector4(-136, -30, 13, 3.6), Vector4(-140, -2, 9, 2.5), Vector4(-133, 84, 14, 3.9),
	# Behind Maple Lane's back gardens, by the south wall
	Vector4(-62, 95, 11, 3), Vector4(-6, 96, 10, 2.5), Vector4(40, 92, 13, 3.5), Vector4(74, 84, 14, 3.9),
]
const COUNTRY := 420.0                   # how far past the town's ground the countryside runs
const COUNTRY_STEP := 6.0                # its mesh's grid, in metres
const SKIRT := 3000.0                    # ...plus one last wide ring out to here, so from up high there's no edge

const GRASS := Color(0.47, 0.5, 0.25)
const MUD := Color(0.32, 0.28, 0.2)
const SAND := Color(0.62, 0.55, 0.4)
const ROCK := Color(0.45, 0.43, 0.42)


static func _ss(a: float, b: float, x: float) -> float:
	# smoothstep that works either way round (a > b falls from 1 to 0)
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func falls_dir() -> Vector2:
	return (Vector2(FALLS_POOL.x, FALLS_POOL.z) - HILL).normalized()


static func hill(x: float, z: float) -> float:
	var off := Vector2(x, z) - HILL
	var d := off.length()
	if d > HILL_FLAT + HILL_SLOPE:
		return 0.0
	# The cliff: a wedge facing the pond, where the slope is short and steep
	var facing := 0.0 if d < 0.01 else off.normalized().dot(falls_dir())
	var wedge := _ss(0.82, 0.93, facing)
	var reach := lerpf(HILL_SLOPE, CLIFF, wedge)
	return HILL_TOP * _ss(HILL_FLAT + reach, HILL_FLAT, d)


static func rolls(x: float, z: float) -> float:
	var h := 0.0
	for r: Vector4 in ROLLS:
		var d := Vector2(x - r.x, z - r.y).length()
		if d < r.z:
			h += r.w * 0.5 * (1.0 + cos(PI * d / r.z))
	return h


static func country(x: float, z: float) -> float:
	# The countryside past the town's ground: 0 at its edge, then rolling fields and hills, higher further out
	var out := maxf(maxf(X0 - x, x - X1), maxf(Z0 - z, z - Z1))
	if out <= 0.0:
		return 0.0
	var rise := _ss(0.0, 70.0, out)
	var roll := 0.5 + 0.22 * sin(x * 0.021 + 1.3) * cos(z * 0.017 - 0.4) + 0.18 * sin((x - z) * 0.013 + 2.1) \
		+ 0.1 * cos((x + 2.0 * z) * 0.031) + 0.06 * sin(x * 0.067) * sin(z * 0.059)
	return rise * (4.0 + 26.0 * _ss(20.0, 260.0, out)) * roll


static func creek_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in CREEK.size() - 1:
		var a: Vector2 = CREEK[i]
		var b: Vector2 = CREEK[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func pond_e(x: float, z: float) -> float:
	# 1.0 on the pond's outline, less inside
	return Vector2((x - POND.x) / POND.z, (z - POND.y) / POND.w).length()


static func height(x: float, z: float) -> float:
	var h := hill(x, z) + rolls(x, z)
	var dip := 0.0
	dip = minf(dip, -POND_DEPTH * _ss(1.12, 0.55, pond_e(x, z)))
	dip = minf(dip, -CREEK_DEPTH * _ss(CREEK_HALF + 1.6, CREEK_HALF - 0.8, creek_distance(x, z)))
	dip = minf(dip, -1.6 * _ss(6.5, 3.0, Vector2(x - FALLS_POOL.x, z - FALLS_POOL.z).length()))
	return h + dip


static func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_Y - 0.05


static func water_circles() -> Array[Vector4]:
	# The creek and the plunge pool as a chain of circles (and the pond as its ellipse), for scripts/water.gd
	var out: Array[Vector4] = [Vector4(POND.x, POND.y, POND.z * 0.98, POND.w * 0.98),
		Vector4(FALLS_POOL.x, FALLS_POOL.z, 4.6, 4.6)]
	for i in CREEK.size() - 1:
		var a: Vector2 = CREEK[i]
		var b: Vector2 = CREEK[i + 1]
		var n := int(ceil(a.distance_to(b) / 2.0))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			out.append(Vector4(p.x, p.y, CREEK_HALF, CREEK_HALF))
	return out


static func color_at(x: float, z: float, h: float, slope: float) -> Color:
	if h < WATER_Y - 0.1:
		return MUD
	if h < WATER_Y + 0.25 and (pond_e(x, z) < 1.25 or creek_distance(x, z) < CREEK_HALF + 2.2):
		return SAND
	if slope > 0.9:
		return ROCK
	# A little variety in the grass: autumn browns and greens in big soft patches
	var n := sin(x * 0.11) * cos(z * 0.13) + 0.5 * sin((x + z) * 0.05)
	return GRASS.lerp(Color(0.55, 0.45, 0.22), clampf(n * 0.35 + 0.2, 0.0, 0.6))


static func country_color(x: float, z: float, h: float) -> Color:
	# Autumn farmland: fields in big patches (stubble gold, ploughed brown, late green), woods on the higher hills
	var fx := floorf((x + 0.37 * z) / 55.0)
	var fz := floorf((z - 0.21 * x) / 45.0)
	var pick := absi(int(fx * 7.0 + fz * 13.0)) % 4
	var field: Color = [Color(0.66, 0.56, 0.3), Color(0.42, 0.33, 0.22), Color(0.45, 0.5, 0.25), Color(0.58, 0.5, 0.28)][pick]
	var woods := Color(0.62, 0.3, 0.12).lerp(Color(0.72, 0.5, 0.16), 0.5 + 0.5 * sin(x * 0.05 + z * 0.04))
	return GRASS.lerp(field, _ss(4.0, 30.0, maxf(maxf(X0 - x, x - X1), maxf(Z0 - z, z - Z1)))).lerp(woods, _ss(12.0, 20.0, h))


func _ready() -> void:
	if get_child_count() == 0:
		build()


func build() -> void:
	# The ground's mesh (vertex coloured) and a height map to stand on, a metre a step
	var w := int(X1 - X0) + 1
	var d := int(Z1 - Z0) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for j in d:
		for i in w:
			heights[j * w + i] = height(X0 + i, Z0 + j)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(w * d)
	normals.resize(w * d)
	colors.resize(w * d)
	for j in d:
		for i in w:
			var h := heights[j * w + i]
			var hl := heights[j * w + maxi(i - 1, 0)]
			var hr := heights[j * w + mini(i + 1, w - 1)]
			var hu := heights[maxi(j - 1, 0) * w + i]
			var hd := heights[mini(j + 1, d - 1) * w + i]
			var n := Vector3(hl - hr, 2.0, hu - hd).normalized()
			var k := j * w + i
			verts[k] = Vector3(X0 + i, h, Z0 + j)
			normals[k] = n
			colors[k] = color_at(X0 + i, Z0 + j, h, Vector2(hl - hr, hu - hd).length() * 0.5)
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (d - 1) * 6)
	var q := 0
	for j in d - 1:
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
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Ground Mesh"
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.name = "Ground Shape"
	cs.shape = shape
	cs.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)   # a height map is centred on its node
	add_child(cs)
	_build_country(m)


func _build_country(m: Material) -> void:
	# The countryside round the town's ground, one mesh in a square ring (the middle, where the town's ground is,
	# left out), on a coarser grid. Its inner edge lands on the ground's edge, where both are flat.
	var n := int(ceil(COUNTRY / COUNTRY_STEP))
	var xs := PackedFloat32Array([X0 - SKIRT])
	var zs := PackedFloat32Array([Z0 - SKIRT])
	for i in range(-n, 0):
		xs.append(X0 + i * COUNTRY_STEP)
		zs.append(Z0 + i * COUNTRY_STEP)
	var inner_x := int(ceil((X1 - X0) / COUNTRY_STEP))
	var inner_z := int(ceil((Z1 - Z0) / COUNTRY_STEP))
	for i in inner_x + 1:
		xs.append(minf(X0 + i * COUNTRY_STEP, X1))
	for i in inner_z + 1:
		zs.append(minf(Z0 + i * COUNTRY_STEP, Z1))
	for i in range(1, n + 1):
		xs.append(X1 + i * COUNTRY_STEP)
		zs.append(Z1 + i * COUNTRY_STEP)
	xs.append(X1 + SKIRT)
	zs.append(Z1 + SKIRT)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := xs.size()
	var d := zs.size()
	var ys := PackedFloat32Array()
	ys.resize(w * d)
	for j in d:
		for i in w:
			ys[j * w + i] = country(xs[i], zs[j])
	for j in d:
		for i in w:
			var y := ys[j * w + i]
			var dx := (ys[j * w + mini(i + 1, w - 1)] - ys[j * w + maxi(i - 1, 0)]) / maxf(xs[mini(i + 1, w - 1)] - xs[maxi(i - 1, 0)], 0.1)
			var dz := (ys[mini(j + 1, d - 1) * w + i] - ys[maxi(j - 1, 0) * w + i]) / maxf(zs[mini(j + 1, d - 1)] - zs[maxi(j - 1, 0)], 0.1)
			st.set_normal(Vector3(-dx, 1.0, -dz).normalized())
			st.set_color(country_color(xs[i], zs[j], y))
			st.add_vertex(Vector3(xs[i], y - 0.02, zs[j]))   # (a hair under, so the town's own ground wins at the seam)
	for j in d - 1:
		for i in w - 1:
			var cx := (xs[i] + xs[i + 1]) / 2.0
			var cz := (zs[j] + zs[j + 1]) / 2.0
			if cx > X0 and cx < X1 and cz > Z0 and cz < Z1:
				continue                                          # the town's own ground is here
			var a := j * w + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + w)
			st.add_index(a + 1)
			st.add_index(a + w + 1)
			st.add_index(a + w)
	var mi := MeshInstance3D.new()
	mi.name = "Countryside"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
