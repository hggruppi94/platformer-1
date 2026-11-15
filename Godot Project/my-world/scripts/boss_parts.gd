extends RefCounted

# Shapes for building a boss's own look in code (Hayden, 15 Nov 2026: "the portal worlds bosses each need new unique
# designs instead of being copy paste of old bosses"). The four bosses that were built on an older boss's scene
# (Tuskwinter on the Gloop King, Grumblefin on the Gloop King, the Dawn Snatcher on Grandfather Tock, the Stormram on
# the Boulderdillo) keep that scene's nodes, because the fight code moves and squashes them, but take every mesh off
# (strip()) and hang their own parts on the same nodes. No class_name: preload it.


static func mat(c: Color, rough := 0.6, glow := 0.0, alpha := 1.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func strip(n: Node) -> void:
	# Takes the old look off without taking the nodes away: whatever the fight code moves stays where it expects it
	for c in n.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).mesh = null
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = null


static func _add(parent: Node, mesh: Mesh, at: Vector3, m: Material, scl := Vector3.ONE, rot := Vector3.ZERO,
		name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name != "":
		mi.name = name
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func ball(parent: Node, r: float, at: Vector3, m: Material, scl := Vector3.ONE, name := "") -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return _add(parent, s, at, m, scl, Vector3.ZERO, name)


static func cyl(parent: Node, top: float, bottom: float, h: float, at: Vector3, m: Material, rot := Vector3.ZERO,
		name := "", sides := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _add(parent, c, at, m, Vector3.ONE, rot, name)


static func box(parent: Node, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO, name := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, at, m, Vector3.ONE, rot, name)


static func ring(parent: Node, inner: float, outer: float, at: Vector3, m: Material, rot := Vector3.ZERO,
		name := "") -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	return _add(parent, t, at, m, Vector3.ONE, rot, name)


static func pivot(parent: Node, at: Vector3, name: String, rot := Vector3.ZERO) -> Node3D:
	var p := Node3D.new()
	p.name = name
	p.position = at
	p.rotation = rot
	parent.add_child(p)
	return p


static func spike(parent: Node, base: Vector3, out: Vector3, length: float, r: float, m: Material) -> MeshInstance3D:
	# A cone standing on `base` and pointing along `out` (a horn, a tusk, a pufferfish spine, an icicle)
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	var dir := out.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var x := up.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	mi.transform = Transform3D(Basis(x, dir, z), base + dir * (length * 0.5))
	return mi


static func face(mi: Node3D, dir: Vector3) -> Node3D:
	# Turns a part so its own up points along `dir`, keeping its place and its scale (a spot or a barnacle on a body)
	var y := dir.normalized()
	var up := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var x := up.cross(y).normalized()
	var z := x.cross(y).normalized()
	var s := mi.scale
	mi.basis = Basis(x * s.x, y * s.y, z * s.z)
	return mi
