class_name Cosmetics
extends RefCounted

# What the market's hats and sash stickers (res://shop/items.json) look like on Nina, built from simple shapes.
# scenes/player/player.gd puts the hat on her head and the stickers on Rex's sash.

const HAT_Y := 1.40                                # the top of her head (hair included), in her model's space
# Hats that cover the top of the head: a hairstyle's buns or mohawk tuck in under them (scripts/clothes.gd)
const COVERS := ["propeller_cap", "sk8_beanie"]
const STICKER_ANGLES := {"star_sticker": -0.95, "daisy_sticker": -0.5, "note_sticker": 0.5, "paw_sticker": 0.95,
	"watch_sticker": 1.4}


static func _mat(color: Color, emit := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 16
	s.rings = 8
	return s


static func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 8
	return t


static func hat(id: String) -> Node3D:
	# A hat to sit on top of her head (its origin goes at HAT_Y); null for no hat
	var h := Node3D.new()
	h.name = "Hat"
	h.position.y = HAT_Y
	match id:
		"propeller_cap":
			var cap := _mat(Color(0.95, 0.3, 0.3))
			var stripe := _mat(Color(0.3, 0.55, 1.0))
			_mesh(h, _sphere(0.3), cap, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
			_mesh(h, _torus(0.27, 0.31), stripe, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3(1, 0.6, 1))        # a band
			_mesh(h, _cyl(0.2, 0.2, 0.02), stripe, Vector3(0, -0.07, 0.3), Vector3.ZERO, Vector3(1, 1, 0.7))    # the brim
			_mesh(h, _cyl(0.02, 0.02, 0.18), stripe, Vector3(0, 0.15, 0))
			var prop := Node3D.new()
			prop.name = "Propeller"                       # player.gd spins it
			prop.position.y = 0.24
			h.add_child(prop)
			var blade := _mat(Color(1.0, 0.85, 0.2))
			for k in 2:
				var b := BoxMesh.new()
				b.size = Vector3(0.36, 0.015, 0.07)
				_mesh(prop, b, blade, Vector3.ZERO, Vector3(0, k * PI / 2, 0))
		"flower_crown":
			_mesh(h, _torus(0.21, 0.25), _mat(Color(0.35, 0.65, 0.3)), Vector3(0, -0.04, 0))
			var cols := [Color(1.0, 0.45, 0.7), Color(1.0, 0.9, 0.3), Color(0.7, 0.5, 1.0), Color(1.0, 0.6, 0.35)]
			for k in 8:
				var a := k * TAU / 8
				_mesh(h, _sphere(0.065), _mat(cols[k % 4]), Vector3(sin(a) * 0.23, 0.0, cos(a) * 0.23))
		"crystal_tiara":
			_mesh(h, _torus(0.21, 0.235), _mat(Color(0.85, 0.85, 0.95), 0.0, 0.8), Vector3(0, -0.06, 0))
			var glow := _mat(Color(0.6, 0.9, 1.0), 1.4)
			for k in 5:
				var a := (k - 2) * 0.32
				var tall := 0.2 if k == 2 else 0.12
				var p := PrismMesh.new()
				p.size = Vector3(0.07, tall, 0.04)
				_mesh(h, p, glow, Vector3(sin(a) * 0.23, -0.04 + tall / 2, cos(a) * 0.23), Vector3(0, a, 0))
		"headphones":
			# A band over the top from ear to ear, and a cup on each ear. scripts/clothes.gd remakes the band and
			# moves the cups to fit whoever wears them, so they sit on the sides of their head.
			var band := _mat(Color(0.25, 0.2, 0.4))
			var cups := _mat(Color(0.55, 0.4, 1.0), 0.4)
			for p in band_arc(Vector3(0, -0.36, 0), 0.36, 0.38):
				_mesh(h, p[0], band, p[1], p[2]).set_meta("fit", "band")
			for s in [-1, 1]:
				var cup := _mesh(h, _cyl(0.1, 0.1, 0.08), cups, Vector3(s * 0.33, -0.36, 0), Vector3(0, 0, PI / 2))
				cup.set_meta("fit", "cup")
				_mesh(cup, _sphere(0.035), _mat(Color(1, 0.95, 0.5), 1.5), Vector3(0, -s * 0.05, 0))   # a little star
		"sk8_beanie":
			# A slouchy knitted beanie with a folded cuff and a pom-pom, a bit back on her head
			var knit := _mat(Color(0.25, 0.75, 0.7))
			_mesh(h, _sphere(0.29), knit, Vector3(0, -0.02, -0.04), Vector3(-0.25, 0, 0), Vector3(1, 0.75, 1.05))
			_mesh(h, _torus(0.24, 0.31), _mat(Color(0.95, 0.4, 0.6)), Vector3(0, -0.1, 0.0), Vector3(-0.2, 0, 0), Vector3(1, 1.4, 1))
			_mesh(h, _sphere(0.07), _mat(Color(1.0, 0.95, 0.6)), Vector3(0, 0.2, -0.12))
		"witch_hat":
			# From the toy shop on Earth: a wide brim, a tall cone with a little bend back at the tip, a gold buckle
			var felt := _mat(Color(0.35, 0.18, 0.5))
			_mesh(h, _cyl(0.4, 0.4, 0.03), felt, Vector3(0, -0.04, 0))
			_mesh(h, _cyl(0.1, 0.22, 0.3), felt, Vector3(0, 0.12, -0.01), Vector3(-0.08, 0, 0))
			_mesh(h, _cyl(0.0, 0.1, 0.26), felt, Vector3(0, 0.37, -0.06), Vector3(-0.35, 0, 0))
			_mesh(h, _torus(0.205, 0.235), _mat(Color(0.95, 0.5, 0.15)), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
			var buckle := BoxMesh.new()
			buckle.size = Vector3(0.09, 0.07, 0.02)
			_mesh(h, buckle, _mat(Color(1.0, 0.82, 0.3), 0.4, 0.8), Vector3(0, 0.0, 0.225))
		"pumpkin_hat":
			# Also from the toy shop: a little pumpkin with its ribs, a curly stem and a leaf
			var orange := _mat(Color(0.97, 0.52, 0.12))
			for k in 6:
				var a := k * TAU / 6
				_mesh(h, _sphere(0.15), orange, Vector3(sin(a) * 0.12, 0.0, cos(a) * 0.12), Vector3.ZERO, Vector3(1, 0.9, 1))
			_mesh(h, _sphere(0.2), orange, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.2, 0.75, 1.2))
			_mesh(h, _cyl(0.025, 0.04, 0.14), _mat(Color(0.35, 0.5, 0.2)), Vector3(0, 0.17, 0), Vector3(0, 0, 0.3))
			var leaf := PrismMesh.new()
			leaf.size = Vector3(0.12, 0.1, 0.01)
			_mesh(h, leaf, _mat(Color(0.4, 0.65, 0.25)), Vector3(0.07, 0.15, 0.02), Vector3(PI / 2, 0, 0.6))
		_:
			return null
	return h


static func band_arc(mid: Vector3, half_width: float, height: float) -> Array:
	# A headphone band: an arch of short pieces from one ear (mid - half_width) over the top to the other.
	# [[mesh, position, rotation], ...]
	var out := []
	var n := 10
	for k in n:
		var a0 := PI * k / n
		var a1 := PI * (k + 1) / n
		var p0 := mid + Vector3(cos(a0) * half_width, sin(a0) * height, 0)
		var p1 := mid + Vector3(cos(a1) * half_width, sin(a1) * height, 0)
		var b := BoxMesh.new()
		b.size = Vector3(p0.distance_to(p1) + 0.012, 0.035, 0.06)
		out.append([b, (p0 + p1) / 2.0, Vector3(0, 0, atan2(p1.y - p0.y, p1.x - p0.x))])
	return out


static func sticker(id: String) -> Node3D:
	# A sticker for the sash's front (player.gd places it along the sash)
	var s := Node3D.new()
	s.name = "Sticker " + id
	var face := Vector3(PI / 2, 0, 0)                     # flat discs facing out
	match id:
		"star_sticker":
			_mesh(s, _cyl(0.05, 0.05, 0.012, 5), _mat(Color(1.0, 0.85, 0.2), 0.6), Vector3.ZERO, face)
		"daisy_sticker":
			_mesh(s, _cyl(0.05, 0.05, 0.012, 10), _mat(Color(1, 1, 1)), Vector3.ZERO, face)
			_mesh(s, _cyl(0.02, 0.02, 0.016, 10), _mat(Color(1.0, 0.85, 0.2)), Vector3(0, 0, 0.004), face)
		"note_sticker":
			_mesh(s, _cyl(0.045, 0.045, 0.012, 12), _mat(Color(0.35, 0.25, 0.6)), Vector3.ZERO, face)
			_mesh(s, _sphere(0.016), _mat(Color(1, 1, 1)), Vector3(-0.01, -0.012, 0.008))
			var stem := BoxMesh.new()
			stem.size = Vector3(0.006, 0.04, 0.004)
			_mesh(s, stem, _mat(Color(1, 1, 1)), Vector3(0.004, 0.01, 0.008))
		"paw_sticker":
			_mesh(s, _cyl(0.045, 0.045, 0.012, 12), _mat(Color(0.55, 0.4, 0.3)), Vector3.ZERO, face)
			for t in 3:
				_mesh(s, _sphere(0.011), _mat(Color(1, 0.95, 0.9)), Vector3(-0.018 + t * 0.018, 0.012, 0.008))
			_mesh(s, _sphere(0.016), _mat(Color(1, 0.95, 0.9)), Vector3(0, -0.012, 0.008))
		"watch_sticker":                                  # Dash's thank-you for 15 lost watches (scripts/watches.gd)
			_mesh(s, _cyl(0.05, 0.05, 0.012, 16), _mat(Color(1.0, 0.82, 0.3)), Vector3.ZERO, face)
			_mesh(s, _cyl(0.04, 0.04, 0.016, 16), _mat(Color(0.8, 0.7, 1.0)), Vector3.ZERO, face)
			for k in 2:
				var hand := BoxMesh.new()
				hand.size = Vector3(0.006, 0.034 - k * 0.012, 0.004)
				_mesh(s, hand, _mat(Color(0.2, 0.12, 0.3)), Vector3(0, 0, 0.01), Vector3(0, 0, 0.5 + k * 2.0))
		_:
			return null
	return s


static func sticker_place(id: String) -> Transform3D:
	# Where on the sash (in the sash's space, scenes/player/player.gd _add_sash: a tilted ring round her middle)
	var a: float = STICKER_ANGLES.get(id, 0.0)
	var local := Vector3(sin(a) * 0.335, 0, cos(a) * 0.335 * 0.85)
	var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(44))
	var p := tilt * local
	return Transform3D(Basis(Vector3.UP, atan2(p.x, p.z)), p)
