extends RefCounted

# The Gloop Kingdom as you see it from outside (Hayden, 14 Nov 2026: "I like the current gloop kingdom entrance, but
# it makes it seem like the kingdom is small and then when you enter it's huge"). The Gloop Gate itself, the goo mound
# with the crown and the gold arch (scripts/bosses.gd), stays just as it was. Built round it, in the gate's own space
# (its +Z is the mouth, facing the town; its -Z runs west, away from the town):
#   - The Kingdom Wall: lilac palace-stone walls with a goo top run back from both sides of the mound to two tall
#     corner towers (goo roofs and crowns, like the Palace Gate inside), so the mound reads as a gatehouse in a wall.
#   - The kingdom beyond: past the edge of the fields (where you can't walk), a whole goo city rises up: a ring of
#     walls and towers, goo spires, goo-falls, and his palace in the middle with a giant goo dome and a giant crown on
#     top. Big enough to see from the market, with glowing goo lanterns so it shows at night too.
# Only the near walls are solid; the city beyond the edge is just to look at.

const STONE := Color(0.74, 0.62, 0.88)          # Palace Stone, as inside (scripts/gloop_kingdom.gd)
const GOO := Color(0.55, 0.78, 0.2)
const GOLD := Color(1.0, 0.78, 0.25)

var _mats := {}
var _rng := RandomNumberGenerator.new()


static func palace_view(parent: Node3D, at: Vector3) -> void:
	# Just his palace, for the skyline inside the kingdom (scripts/gloop_kingdom.gd), so it's the same palace you saw
	# from the fields
	var v := new()
	v._rng.seed = 1114
	var root := Node3D.new()
	root.name = "Palace View"
	parent.add_child(root)
	root.position = at
	root.rotation.y = PI                 # (its lit windows and the crown's ruby face back towards the way in)
	v._palace(root, Vector3.ZERO, 30.0)


static func build(gate: Node3D, radius: float) -> void:
	var v := new()
	v._rng.seed = 1114
	var root := Node3D.new()
	root.name = "Gloop Kingdom View"
	gate.add_child(root)
	v._near_walls(root, radius)
	v._kingdom_beyond(root)


# -----------------------------------------------------------------------------
# Materials and little helpers
# -----------------------------------------------------------------------------
func _mat(name: String, c: Color, rough := 0.6, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _stone() -> StandardMaterial3D:
	return _mat("Palace Stone", STONE, 0.7)


func _goo() -> StandardMaterial3D:
	var m := _mat("Royal Goo", GOO, 0.12, 0.25, 0.1)
	m.rim_enabled = true
	m.rim = 0.6
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	return m


func _gold() -> StandardMaterial3D:
	return _mat("Royal Gold", GOLD, 0.25, 0.15, 0.8)


func _lamp() -> StandardMaterial3D:
	return _mat("Goo Lantern", Color(0.75, 1.0, 0.35), 0.2, 2.2)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, sides := 20) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = sides
	return _mesh(parent, cm, at, m)


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, at, m)


func _ball(parent: Node3D, r: float, at: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	return _mesh(parent, sm, at, m)


func _crown(parent: Node3D, size: float, at: Vector3) -> Node3D:
	# The King's crown: a gold band with five points and a red gem (the same crown as on the mound and inside)
	var c := Node3D.new()
	c.name = "Crown"
	c.position = at
	parent.add_child(c)
	_cyl(c, size, size, size * 0.6, Vector3.ZERO, _gold())
	for k in 5:
		var a := TAU * k / 5.0 + PI / 2.0
		_cyl(c, 0.0, size * 0.32, size * 0.8, Vector3(cos(a) * size * 0.85, size * 0.65, sin(a) * size * 0.85), _gold(), 8)
	_ball(c, size * 0.24, Vector3(0, 0, size * 1.02), _mat("Ruby", Color(0.95, 0.15, 0.25), 0.1, 0.9))
	return c


func _tower(parent: Node3D, at: Vector3, r: float, h: float, crown := true, sink := 0.0) -> void:
	# A round palace-stone tower with a gold band, a goo cone roof, goo running down it, a glowing goo lantern
	# window and (most of them) a crown on top. "sink" carries it on down below the ground (past the field's edge).
	_cyl(parent, r, r * 1.12, h + sink, at + Vector3(0, (h - sink) / 2.0, 0), _stone(), 16)
	_cyl(parent, r * 1.08, r * 1.08, r * 0.35, at + Vector3(0, h - r * 0.2, 0), _gold(), 16)
	var roof_h := r * 1.7
	_cyl(parent, 0.0, r * 1.3, roof_h, at + Vector3(0, h + roof_h / 2.0, 0), _goo(), 16)
	for k in 3:
		var a := _rng.randf_range(0.0, TAU)
		var drip := CapsuleMesh.new()
		drip.radius = r * 0.13
		drip.height = _rng.randf_range(0.25, 0.5) * h
		_mesh(parent, drip, at + Vector3(cos(a) * r * 1.02, h - drip.height / 2.0, sin(a) * r * 1.02), _goo(), false)
	# A lit window facing the town (+Z)
	_box(parent, Vector3(r * 0.5, r * 0.9, 0.2), at + Vector3(0, h * 0.7, r * 1.02), _lamp())
	if crown:
		_crown(parent, r * 0.5, at + Vector3(0, h + roof_h + r * 0.15, 0))


func _wall(parent: Node3D, a: Vector3, b: Vector3, h: float, thick: float, solid: bool, sink := 0.0) -> void:
	# A straight run of palace-stone wall from a to b with goo along the top, gold blocks on it and goo drips
	var mid := (a + b) / 2.0
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var yaw := atan2(b.x - a.x, b.z - a.z)
	var seg := Node3D.new()
	seg.name = "Kingdom Wall"
	seg.position = mid
	seg.rotation.y = yaw
	parent.add_child(seg)
	_box(seg, Vector3(thick, h + sink, length), Vector3(0, (h - sink) / 2.0, 0), _stone())
	# Goo poured over the top, dripping down both faces
	var top := CapsuleMesh.new()
	top.radius = thick * 0.62
	top.height = length
	var cap := _mesh(seg, top, Vector3(0, h, 0), _goo())
	cap.rotation.x = PI / 2.0
	var drips := int(length / 2.2)
	for k in drips:
		var z := lerpf(-length / 2.0 + 1.0, length / 2.0 - 1.0, (k + 0.5) / drips)
		var drip := CapsuleMesh.new()
		drip.radius = thick * 0.2
		drip.height = _rng.randf_range(0.18, 0.45) * h
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.6:
				_mesh(seg, drip, Vector3(side * thick * 0.52, h - drip.height / 2.0, z + _rng.randf_range(-0.4, 0.4)), _goo(), false)
	# Gold battlement blocks along the top
	var blocks := int(length / 3.0)
	for k in blocks:
		var z := lerpf(-length / 2.0 + 1.5, length / 2.0 - 1.5, (k + 0.5) / blocks)
		_box(seg, Vector3(thick * 0.9, thick * 0.5, thick * 0.5), Vector3(0, h + thick * 0.75, z), _gold())
	if solid:
		var body := StaticBody3D.new()
		body.name = "Kingdom Wall Body"
		seg.add_child(body)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(thick, h + 1.0, length)
		cs.shape = bs
		cs.position.y = (h + 1.0) / 2.0 - 0.5
		body.add_child(cs)


func _solid_cyl(parent: Node3D, at: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Kingdom Tower Body"
	body.position = at + Vector3(0, h / 2.0, 0)
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r * 1.1
	shape.height = h
	cs.shape = shape
	body.add_child(cs)


func _banner(parent: Node3D, at: Vector3, h: float) -> void:
	# A long green banner with a gold crown, hanging down a tower's town side
	var cloth := _box(parent, Vector3(h * 0.22, h, 0.1), at - Vector3(0, h / 2.0, 0), _mat("Royal Banner", Color(0.3, 0.6, 0.2)))
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(parent, Vector3(h * 0.26, h * 0.04, 0.14), at, _gold())
	var c := _crown(parent, h * 0.07, at - Vector3(0, h * 0.3, -0.12))
	c.rotation.x = PI / 2.0


# -----------------------------------------------------------------------------
# The near walls: the mound becomes the gatehouse in the Kingdom Wall
# -----------------------------------------------------------------------------
func _near_walls(root: Node3D, radius: float) -> void:
	for side in [-1.0, 1.0]:
		# A little tower where the wall meets the mound, so the wall never pokes out over the goo
		var join := Vector3(side * (radius - 0.4), 0, -2.6)
		_tower(root, join, 1.6, 7.5, true, 3.0)
		_solid_cyl(root, join - Vector3(0, 1, 0), 1.6, 9.5)
		var corner := Vector3(side * 12.5, 0, -10.5)
		_wall(root, join, corner, 5.5, 1.6, true, 3.0)
		_tower(root, corner, 2.6, 14.0, true, 3.0)
		_solid_cyl(root, corner - Vector3(0, 1, 0), 2.6, 16.0)
		_banner(root, corner + Vector3(0, 11.5, 2.75), 6.0)
		# A goo lantern post either side of the mouth
		var post := Vector3(side * (radius + 0.6), 0, radius * 0.55)
		_cyl(root, 0.12, 0.16, 3.4, post + Vector3(0, 1.7, 0), _gold(), 8)
		_ball(root, 0.45, post + Vector3(0, 3.6, 0), _lamp())


# -----------------------------------------------------------------------------
# The kingdom beyond the edge of the fields: just to look at, too far to walk to
# -----------------------------------------------------------------------------
func _kingdom_beyond(root: Node3D) -> void:
	var city := Node3D.new()
	city.name = "Kingdom Beyond"
	root.add_child(city)
	var sink := 30.0                                       # (carry everything well down: the fields stop at the edge)
	var middle := Vector3(0, 0, -88)
	# The bog it all sits in
	_cyl(city, 70.0, 74.0, 6.0, middle + Vector3(0, -3.5, 0), _mat("Bog Goo", Color(0.38, 0.55, 0.16), 0.2, 0.15), 48)
	# The great outer wall: a ring of wall and towers round the city
	var ring_r := 46.0
	var n := 12
	for k in n:
		var a0 := TAU * k / n + PI / 2.0
		var a1 := TAU * (k + 1) / n + PI / 2.0
		var p0 := middle + Vector3(cos(a0), 0, sin(a0)) * ring_r
		var p1 := middle + Vector3(cos(a1), 0, sin(a1)) * ring_r
		_wall(city, p0, p1, 13.0, 3.2, false, sink)
		_tower(city, p0, 4.2, 20.0 + _rng.randf_range(-2.0, 3.0), true, sink)
		# Goo-falls pouring over the wall on the town side
		if sin(a0 + PI / n) > 0.2 and k % 2 == 0:
			var mid := (p0 + p1) / 2.0
			var out := Vector3(mid.x - middle.x, 0, mid.z - middle.z).normalized()
			var fall := _box(city, Vector3(3.5, 13.5, 0.3), mid + out * 1.8 + Vector3(0, 6.5, 0), _mat("Goo Fall", Color(0.6, 0.9, 0.25, 0.85), 0.05, 0.8))
			fall.rotation.y = atan2(out.x, out.z)
			fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The great gate in the near side of the ring, facing the town: two big towers with a goo arch
	var near := middle + Vector3(0, 0, ring_r)
	for side in [-1.0, 1.0]:
		_tower(city, near + Vector3(side * 8.0, 0, 1.0), 5.0, 30.0, true, sink)
		_banner(city, near + Vector3(side * 8.0, 26.0, 6.2), 12.0)
	var arch := TorusMesh.new()
	arch.inner_radius = 5.0
	arch.outer_radius = 6.6
	var ar := _mesh(city, arch, near + Vector3(0, 13.0, 1.6), _gold())
	ar.rotation.x = PI / 2.0
	_box(city, Vector3(10.0, 11.0, 0.4), near + Vector3(0, 7.0, 1.0), _mat("Gate Dark", Color(0.1, 0.16, 0.05)))
	# Goo spires among the houses inside
	for k in 14:
		var a := _rng.randf_range(0.0, TAU)
		var d := _rng.randf_range(14.0, ring_r - 9.0)
		var at := middle + Vector3(cos(a) * d, 0, sin(a) * d)
		var h := _rng.randf_range(16.0, 30.0)
		if k % 2 == 0:
			_tower(city, at, _rng.randf_range(2.4, 3.6), h, k % 4 == 0, sink)
		else:
			_cyl(city, 0.0, _rng.randf_range(2.6, 3.8), h, at + Vector3(0, h / 2.0, 0), _goo(), 12)
			for ring in 2:
				_cyl(city, 1.4 - ring * 0.5, 1.6 - ring * 0.5, 0.6, at + Vector3(0, h * (0.35 + ring * 0.25), 0), _gold(), 12)
			_ball(city, 0.9, at + Vector3(0, h + 0.4, 0), _lamp())
	# Goo houses: little blobby domes crowded round the palace
	for k in 26:
		var a := _rng.randf_range(0.0, TAU)
		var d := _rng.randf_range(16.0, ring_r - 5.0)
		var at := middle + Vector3(cos(a) * d, 0, sin(a) * d)
		var r := _rng.randf_range(3.0, 5.5)
		_ball(city, r, at + Vector3(0, r * 0.3, 0), _goo(), 0.75)
		_box(city, Vector3(r * 0.5, r * 0.5, 0.3), at + Vector3(0, r * 0.4, r * 0.95), _lamp())
	# His palace in the middle
	_palace(city, middle + Vector3(0, 0, -6), sink)


func _palace(city: Node3D, keep: Vector3, sink: float) -> void:
	# His palace: a great tower under a giant goo dome, with a giant crown on top and four towers round it
	_cyl(city, 11.0, 12.5, 36.0 + sink, keep + Vector3(0, (36.0 - sink) / 2.0, 0), _stone(), 32)
	_cyl(city, 11.6, 11.6, 2.0, keep + Vector3(0, 35.0, 0), _gold(), 32)
	_ball(city, 13.0, keep + Vector3(0, 37.0, 0), _goo(), 0.9)
	for k in 10:
		var a := TAU * k / 10.0
		var drip := CapsuleMesh.new()
		drip.radius = 1.1
		drip.height = _rng.randf_range(6.0, 12.0)
		_mesh(city, drip, keep + Vector3(cos(a) * 12.0, 36.0 - drip.height * 0.3, sin(a) * 12.0), _goo(), false)
	for k in 6:
		var a := TAU * k / 6.0
		_box(city, Vector3(2.4, 4.0, 0.4), keep + Vector3(cos(a) * 11.6, 24.0, sin(a) * 11.6), _lamp()).rotation.y = -a + PI / 2.0
	var big_crown := _crown(city, 8.0, keep + Vector3(0, 52.0, 0))
	big_crown.name = "Giant Crown"
	# Four palace towers round the dome
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_tower(city, keep + Vector3(cos(a) * 17.0, 0, sin(a) * 17.0), 3.6, 30.0, true, sink)
