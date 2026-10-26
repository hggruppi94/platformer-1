class_name Hairstyles
extends RefCounted

# Hairstyles for the character creator (scripts/hero.gd). Each is built from simple shapes round the head and swaps in
# for the body's own hair (which is hidden). Style 0 is the body's own hair as Sofi drew it, and "Bald" has none.
#
# Made on Nina's head (her model's space: head bone at y 0.9, eyes at y 1.13, the front of her face at z 0.29, the top
# of her hair at 1.46), then fitted to whoever wears it like a hat (scripts/clothes.gd, the "head" fit).

const NAMES := ["Their own", "Short crop", "Pigtails", "Ponytail", "Space buns", "Long and flowy", "Bob", "Mohawk",
	"Afro puffs", "Braids", "Curly top", "Bald"]

# The scalp: a shell over the top and back of the head, leaving the face clear
const CROWN := Vector3(0, 1.2, -0.11)
const CROWN_R := 0.37


static func build(style: int, color: Color) -> Node3D:
	# The hairstyle in Nina's model space, or null for style 0 (their own) and Bald
	var name: String = NAMES[clampi(style, 0, NAMES.size() - 1)]
	if style <= 0 or name == "Bald":
		return null
	var g := Node3D.new()
	g.name = "Hairstyle"
	var hair := _mat(color)
	var tie := _mat(Color(1.0, 0.5, 0.75))
	match name:
		"Short crop":
			_crown(g, hair, 1.0)
		"Pigtails":
			_crown(g, hair, 1.0)
			for s in [-1, 1]:
				_ball(g, hair, Vector3(s * 0.38, 1.12, -0.12), 0.09, Vector3(1, 1, 1))
				_ball(g, hair, Vector3(s * 0.47, 0.95, -0.12), 0.12, Vector3(0.9, 1.6, 0.9))
				_ball(g, tie, Vector3(s * 0.42, 1.06, -0.12), 0.05, Vector3.ONE)
		"Ponytail":
			_crown(g, hair, 1.0)
			_ball(g, tie, Vector3(0, 1.3, -0.45), 0.06, Vector3.ONE)
			_ball(g, hair, Vector3(0, 1.12, -0.55), 0.14, Vector3(0.9, 1.8, 0.8))
		"Space buns":
			_crown(g, hair, 1.0)
			for s in [-1, 1]:
				_up(_ball(g, hair, Vector3(s * 0.22, 1.5, -0.12), 0.13, Vector3.ONE))
		"Long and flowy":
			_crown(g, hair, 1.0)
			_ball(g, hair, Vector3(0, 1.0, -0.33), 0.3, Vector3(1.3, 1.5, 0.45))
			for s in [-1, 1]:
				_ball(g, hair, Vector3(s * 0.32, 1.0, 0.0), 0.12, Vector3(0.7, 2.2, 0.9))
		"Bob":
			_crown(g, hair, 1.04)
			_ball(g, hair, Vector3(0, 1.08, -0.2), 0.32, Vector3(1.25, 0.9, 0.9))
			for s in [-1, 1]:
				_ball(g, hair, Vector3(s * 0.33, 1.05, 0.04), 0.13, Vector3(0.75, 1.35, 1.1))
		"Mohawk":
			_crown(g, _mat(color.darkened(0.25)), 0.97)
			for k in 6:
				var a := lerpf(-0.4, 1.9, k / 5.0)
				var p := PrismMesh.new()
				p.size = Vector3(0.06, 0.24, 0.16)
				var mi := _up(_mesh(g, p, hair, CROWN + Vector3(0, cos(a) * (CROWN_R + 0.06), sin(a) * (CROWN_R + 0.06))))
				mi.rotation.x = a
		"Afro puffs":
			_crown(g, hair, 1.02)
			for s in [-1, 1]:
				for k in 7:
					var o := Vector3(cos(k * TAU / 7) * 0.09, sin(k * 2.3) * 0.06, sin(k * TAU / 7) * 0.09)
					_up(_ball(g, hair, Vector3(s * 0.3, 1.45, -0.1) + o, 0.1, Vector3.ONE))
		"Braids":
			_crown(g, hair, 1.0)
			for s in [-1, 1]:
				for k in 6:
					_ball(g, hair, Vector3(s * (0.3 + k * 0.01), 1.05 - k * 0.09, 0.02 + k * 0.03), 0.065, Vector3.ONE)
				_ball(g, tie, Vector3(s * 0.36, 0.5 + 0.0, 0.2), 0.04, Vector3.ONE)
		"Curly top":
			_crown(g, hair, 0.98)
			for k in 14:
				var a := k * 2.4
				var r := 0.12 + 0.12 * fmod(k * 0.37, 1.0)
				_up(_ball(g, hair, CROWN + Vector3(cos(a) * r, 0.3 - r * 0.4, sin(a) * r - 0.02), 0.11, Vector3.ONE))
	return g


static func _crown(g: Node3D, m: Material, size: float) -> void:
	# A cap of hair over the top and back of the head, with a fringe over the forehead. A hat sits on top of it
	# (scripts/clothes.gd).
	_ball(g, m, CROWN, CROWN_R * size, Vector3(1.08, 0.82, 1.0)).set_meta("hair", "crown")
	_ball(g, m, Vector3(0, 1.36, 0.12), 0.2 * size, Vector3(1.4, 0.45, 0.8)).set_meta("hair", "crown")


static func _up(mi: MeshInstance3D) -> MeshInstance3D:
	# Something sticking up off the top of the head, tucked under a hat that covers it (scripts/clothes.gd)
	mi.set_meta("hair", "up")
	return mi


static func _ball(g: Node3D, m: Material, pos: Vector3, r: float, scale: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := _mesh(g, s, m, pos)
	mi.scale = scale
	return mi


static func _mesh(g: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	g.add_child(mi)
	return mi


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m
