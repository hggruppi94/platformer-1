extends RefCounted

# Little shapes the bosses' shockwaves (scripts/shock_ring.gd) and the things they throw (scripts/boss_moves.gd) are
# dressed in: goo blobs, gears, music notes, rocks, ice shards, feathers, leaves, glitch cubes, thorns, bubbles...
# Each is made once from Godot's own shapes (merged into one mesh, so a ring of twenty gears is twenty draws, not two
# hundred) and kept, and every ring and throw reuses it.
#
# No class_name (tools run with --script compile class_name scripts before the autoloads exist): preload it.
#
#   const BITS := preload("res://scripts/boss_bits.gd")
#   piece.mesh = BITS.mesh("gear")
#   piece.material_override = BITS.mat(colour, 1.5)

static var _meshes := {}


# A shape, about 1 m across, standing on its own middle (so a ring can sit it on the ground and scale it).
static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m := _make(kind)
	_meshes[kind] = m
	return m


# A glowing, see-through-able look in one colour. Unshaded, so it reads in every light (night, caves, the Void's
# green sky) and never casts a shadow.
static func mat(col: Color, glow := 1.2, alpha := 1.0, glossy := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glossy:
		m.metallic = 0.3
		m.roughness = 0.05
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = glow > 0.0
	m.emission = col
	m.emission_energy_multiplier = glow
	return m


static func _make(kind: String) -> Mesh:
	match kind:
		"blob":
			return _sphere(0.5, 0.42, 12, 6)
		"drop":
			return _merge([[_sphere(0.5, 0.5, 10, 5), Transform3D()],
				[_cone(0.32, 0.6, 8), Transform3D(Basis(), Vector3(0, 0.45, 0))]])
		"fleck", "spark", "ember":
			return _sphere(0.5, 0.5, 6, 3)
		"bubble":
			return _merge([[_sphere(0.5, 0.5, 14, 7), Transform3D()],
				[_sphere(0.12, 0.12, 6, 3), Transform3D(Basis(), Vector3(-0.2, 0.22, 0.32))]])
		"gear":
			return _gear()
		"note":
			return _note()
		"star":
			return _star()
		"shard", "thorn":
			return _cone(0.22 if kind == "shard" else 0.14, 1.0, 5 if kind == "shard" else 6)
		"flame":
			return _merge([[_sphere(0.32, 0.3, 8, 4), Transform3D(Basis(), Vector3(0, 0.15, 0))],
				[_cone(0.32, 0.8, 8), Transform3D(Basis(), Vector3(0, 0.55, 0))]])
		"rock":
			return _sphere(0.5, 0.42, 6, 3)                        # a few big facets: a chunk of rock
		"cube":
			return _box(Vector3(0.6, 0.6, 0.6))
		"bar":
			return _box(Vector3(0.22, 1.0, 0.22), Vector3(0, 0.5, 0))
		"bolt":
			return _bolt()
		"wisp":
			return _merge([[_sphere(0.4, 0.4, 10, 5), Transform3D()],
				[_sphere(0.26, 0.3, 8, 4), Transform3D(Basis(), Vector3(0.08, 0.45, 0))],
				[_sphere(0.15, 0.2, 6, 3), Transform3D(Basis(), Vector3(-0.05, 0.8, 0))]])
		"leaf", "petal":
			return _leaf(kind == "petal")
		"feather":
			return _feather()
		"moth":
			return _moth()
		"ribbon":
			return _box(Vector3(0.12, 0.02, 1.0))
		"skull":
			return _skull()
	return _sphere(0.5, 0.5, 8, 4)


# -----------------------------------------------------------------------------
# Shapes
# -----------------------------------------------------------------------------
static func _sphere(r: float, half_h: float, segs: int, rings: int) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = half_h * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s


static func _cone(r: float, h: float, segs: int) -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	# Stood on its base, not its middle
	return _merge([[c, Transform3D(Basis(), Vector3(0, h * 0.5, 0))]])


static func _box(size: Vector3, at := Vector3.ZERO) -> Mesh:
	var b := BoxMesh.new()
	b.size = size
	if at == Vector3.ZERO:
		return b
	return _merge([[b, Transform3D(Basis(), at)]])


static func _merge(parts: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var m: Mesh = p[0]
		for s in m.get_surface_count():
			st.append_from(m, s, p[1])
	st.generate_normals()
	return st.commit()


static func _gear() -> Mesh:
	var hub := CylinderMesh.new()
	hub.top_radius = 0.36
	hub.bottom_radius = 0.36
	hub.height = 0.14
	hub.radial_segments = 16
	var parts := [[hub, Transform3D()]]
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.14, 0.14, 0.18)
	for i in 10:
		var a := TAU * i / 10.0
		parts.append([tooth, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * 0.42)])
	var axle := CylinderMesh.new()
	axle.top_radius = 0.1
	axle.bottom_radius = 0.1
	axle.height = 0.22
	parts.append([axle, Transform3D()])
	# Stood up on its edge, like a coin rolling
	var up := Basis(Vector3.RIGHT, PI * 0.5)
	for p in parts:
		p[1] = Transform3D(up, Vector3(0, 0.5, 0)) * p[1]
	return _merge(parts)


static func _note() -> Mesh:
	var head := _sphere(0.2, 0.15, 10, 5)
	var stem := BoxMesh.new()
	stem.size = Vector3(0.05, 0.7, 0.05)
	var flag := BoxMesh.new()
	flag.size = Vector3(0.22, 0.08, 0.05)
	return _merge([[head, Transform3D(Basis(Vector3.BACK, 0.4), Vector3(0, 0.15, 0))],
		[stem, Transform3D(Basis(), Vector3(0.17, 0.5, 0))],
		[flag, Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.26, 0.8, 0))]])


static func _star() -> Mesh:
	# Five points round a middle, flat, stood up facing out of the ring
	var parts := []
	var mid := _sphere(0.18, 0.08, 10, 4)
	parts.append([mid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)])
	var pt := CylinderMesh.new()
	pt.top_radius = 0.0
	pt.bottom_radius = 0.14
	pt.height = 0.36
	pt.radial_segments = 4
	for i in 5:
		var a := TAU * i / 5.0
		var b := Basis(Vector3.BACK, a)
		parts.append([pt, Transform3D(b, b * Vector3(0, 0.3, 0))])
	for p in parts:
		p[1] = Transform3D(Basis(), Vector3(0, 0.5, 0)) * p[1]
	return _merge(parts)


static func _bolt() -> Mesh:
	# A zigzag of lightning, about 1 m tall
	var seg := BoxMesh.new()
	seg.size = Vector3(0.07, 0.4, 0.07)
	return _merge([[seg, Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0, 0.18, 0))],
		[seg, Transform3D(Basis(Vector3.BACK, -0.6), Vector3(0.05, 0.5, 0))],
		[seg, Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0, 0.82, 0))]])


static func _leaf(petal: bool) -> Mesh:
	var blade := _sphere(0.22 if petal else 0.18, 0.04, 8, 4)
	var parts := [[blade, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 2.2 if not petal else 1.4)), Vector3(0, 0.2, 0))]]
	if not petal:
		var stalk := BoxMesh.new()
		stalk.size = Vector3(0.03, 0.03, 0.7)
		parts.append([stalk, Transform3D(Basis(), Vector3(0, 0.23, 0.05))])
	return _merge(parts)


static func _feather() -> Mesh:
	var vane := _sphere(0.14, 0.03, 8, 4)
	var quill := BoxMesh.new()
	quill.size = Vector3(0.025, 0.025, 0.9)
	return _merge([[vane, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 3.0)), Vector3(0, 0.2, 0.05))],
		[quill, Transform3D(Basis(), Vector3(0, 0.22, 0))]])


static func _moth() -> Mesh:
	var wing := _sphere(0.24, 0.02, 10, 4)
	var body := _sphere(0.06, 0.16, 6, 3)
	return _merge([[wing, Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.22, 0.4, 0))],
		[wing, Transform3D(Basis(Vector3.UP, -0.4), Vector3(-0.22, 0.4, 0))],
		[body, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.4, 0))]])


static func _skull() -> Mesh:
	# A friendly little gold skull, like the one on the Agent of Chaos: round head, two eye holes as bumps, a jaw
	var head := _sphere(0.4, 0.36, 12, 6)
	var jaw := _box(Vector3(0.42, 0.18, 0.3))
	var eye := _sphere(0.1, 0.1, 6, 3)
	return _merge([[head, Transform3D(Basis(), Vector3(0, 0.55, 0))],
		[jaw, Transform3D(Basis(), Vector3(0, 0.22, 0.08))],
		[eye, Transform3D(Basis(), Vector3(0.15, 0.58, 0.33))],
		[eye, Transform3D(Basis(), Vector3(-0.15, 0.58, 0.33))]])
