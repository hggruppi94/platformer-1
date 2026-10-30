class_name EarthLand
extends StaticBody3D

# The ground of the Earth town (scenes/earth/earth.tscn): one height for every spot, shared by the builder
# (tools/build_earth.gd puts things on it), the game (this node makes the ground's mesh and collision when the town
# loads, so no big binary ground file has to live in the repo) and the tests. Mostly flat, as a town is, with:
# - Willow Pond in the park west of the green, a shallow bowl you can wade into,
# - Whisper Creek, from the foot of Mossy Falls down into the pond and out again, south under the covered bridge,
# - Lookout Hill in the northwest, a broad round hill with gentle slopes to ride down, and a rocky cliff on its pond
#   side where the falls come over.
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
	var h := hill(x, z)
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
