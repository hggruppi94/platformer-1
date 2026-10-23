extends SceneTree

# Builds res://scenes/enemies/crocodillo.tscn: the Crocodillo, a hunched crocodile-armadillo
# (source_art/reference/enemies/crocodillo - crocodile armadillo.jpg; logic in scripts/crocodillo.gd).
# A knobbly crocodile head full of teeth, a banded armadillo shell on its back, long arms with green clawed hands,
# bent legs and a thick tail. It can curl up into an armoured ball ("Ball"), hidden until it rolls.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_crocodillo.gd
#
# Feet at the origin, facing +Z like the other characters, about 1.9 m tall. The parts the script moves sit on
# pivots: Body/LegL, LegR (hips), ArmL, ArmR (shoulders), Head (neck), Head/Jaw, Tail.

const OUT_DIR := "res://scenes/enemies"
const OUT := OUT_DIR + "/crocodillo.tscn"

var croc: CharacterBody3D
var scales: StandardMaterial3D
var dark: StandardMaterial3D
var belly: StandardMaterial3D
var knob: StandardMaterial3D
var band: StandardMaterial3D
var hand: StandardMaterial3D
var tooth: StandardMaterial3D
var eye: StandardMaterial3D
var pupil: StandardMaterial3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	croc = CharacterBody3D.new()
	croc.name = "Crocodillo"
	croc.set_script(load("res://scripts/crocodillo.gd"))
	scales = _mat("Croc Scales", Color(0.33, 0.36, 0.2), 0.75)
	dark = _mat("Croc Shell", Color(0.24, 0.26, 0.15), 0.5)
	belly = _mat("Croc Belly", Color(0.62, 0.47, 0.26), 0.8)
	knob = _mat("Croc Knobs", Color(0.58, 0.38, 0.26), 0.85)
	band = _mat("Croc Shell Band", Color(0.5, 0.42, 0.24), 0.6)
	hand = _mat("Croc Hands", Color(0.42, 0.55, 0.2), 0.7)
	tooth = _mat("Croc Teeth", Color(0.97, 0.94, 0.85), 0.4)
	eye = _mat("Croc Eyes", Color(1.0, 0.85, 0.2), 0.3, 0.6)
	pupil = _mat("Croc Pupils", Color(0.05, 0.04, 0.02), 0.2)

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	croc.add_child(cs)
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.85
	hcs.shape = hs
	hcs.position = Vector3(0, 1.0, 0.1)
	hitbox.add_child(hcs)
	croc.add_child(hitbox)

	var visual := _node(croc, "Visual", Vector3.ZERO)
	var body := _node(visual, "Body", Vector3.ZERO)

	# Torso leaning forward, a pale scaly belly, and the banded shell over its back
	_mesh(body, _capsule(0.4, 1.05), scales, Vector3(0, 1.3, 0.08), Vector3(0.55, 0, 0))
	_mesh(body, _capsule(0.3, 0.85), belly, Vector3(0, 1.25, 0.24), Vector3(0.55, 0, 0), Vector3(1.0, 1.0, 0.6))
	var shell := _mesh(body, _sphere(0.62), dark, Vector3(0, 1.42, -0.12), Vector3(0.55, 0, 0), Vector3(1.0, 1.15, 0.72))
	for k in 5:
		var t := TorusMesh.new()
		t.inner_radius = 0.56
		t.outer_radius = 0.66
		t.rings = 24
		var y := -0.42 + k * 0.21
		var r := sqrt(maxf(1.0 - pow(y / 0.62, 2), 0.05))
		var ring := _mesh(shell, t, band, Vector3(0, y, -0.05), Vector3.ZERO, Vector3(r, 0.5, r * 0.85))
		ring.name = "Band%d" % k
	for k in 7:                                        # spiky knobs down the middle of the shell
		_mesh(shell, _cone(0.07, 0.16), knob, Vector3(0, -0.45 + k * 0.15, -0.6), Vector3(-PI / 2, 0, 0))

	# Legs: thigh, shin and a long flat foot, hanging from the hips
	for s in [-1.0, 1.0]:
		var leg := _node(body, "LegL" if s < 0 else "LegR", Vector3(s * 0.22, 0.95, -0.02))
		_mesh(leg, _capsule(0.15, 0.55), scales, Vector3(0, -0.2, 0.08), Vector3(-0.4, 0, 0))
		_mesh(leg, _capsule(0.12, 0.55), scales, Vector3(0, -0.62, 0.06), Vector3(0.25, 0, 0))
		_mesh(leg, _box(Vector3(0.2, 0.1, 0.4)), scales, Vector3(0, -0.9, 0.12))
		for toe in 3:
			_mesh(leg, _cone(0.035, 0.12), tooth, Vector3((toe - 1) * 0.065, -0.92, 0.34), Vector3(PI / 2, 0, 0))

	# Long arms down to green clawed hands
	for s in [-1.0, 1.0]:
		var arm := _node(body, "ArmL" if s < 0 else "ArmR", Vector3(s * 0.42, 1.58, 0.36))
		_mesh(arm, _capsule(0.11, 0.5), scales, Vector3(s * 0.04, -0.2, 0.0), Vector3(0.1, 0, s * 0.15))
		_mesh(arm, _capsule(0.1, 0.5), scales, Vector3(s * 0.07, -0.58, 0.1), Vector3(-0.35, 0, s * 0.05))
		_mesh(arm, _sphere(0.13), hand, Vector3(s * 0.08, -0.85, 0.2), Vector3.ZERO, Vector3(1.0, 0.8, 1.2))
		for c in 3:
			_mesh(arm, _cone(0.03, 0.17), tooth, Vector3(s * 0.08 + (c - 1) * 0.05, -0.93, 0.3), Vector3(2.2, 0, 0))

	# The head: a knobbly skull, a long snout, a snapping jaw, rows of teeth and yellow eyes
	var head := _node(body, "Head", Vector3(0, 1.78, 0.5))
	_mesh(head, _sphere(0.26), scales, Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	_mesh(head, _capsule(0.16, 0.7), scales, Vector3(0, 0.0, 0.32), Vector3(PI / 2, 0, 0), Vector3(1.1, 1.0, 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 16:
		_mesh(head, _sphere(rng.randf_range(0.045, 0.08)), knob,
			Vector3(rng.randf_range(-0.18, 0.18), 0.17 + rng.randf() * 0.05, rng.randf_range(-0.15, 0.45)))
	for s in [-1.0, 1.0]:
		_mesh(head, _sphere(0.07), eye, Vector3(s * 0.15, 0.15, 0.12))
		_mesh(head, _box(Vector3(0.02, 0.09, 0.02)), pupil, Vector3(s * 0.17, 0.15, 0.18))
		for t in 6:                                    # upper teeth, pointing down
			_mesh(head, _cone(0.025, 0.09), tooth, Vector3(s * 0.13, -0.09, 0.12 + t * 0.09), Vector3(PI, 0, 0))
	var jaw := _node(head, "Jaw", Vector3(0, -0.1, 0.02))
	_mesh(jaw, _capsule(0.13, 0.62), belly, Vector3(0, -0.03, 0.3), Vector3(PI / 2, 0, 0), Vector3(1.05, 1.0, 0.55))
	for s in [-1.0, 1.0]:
		for t in 5:                                    # lower teeth, pointing up
			_mesh(jaw, _cone(0.022, 0.08), tooth, Vector3(s * 0.11, 0.04, 0.15 + t * 0.09))

	# A thick tail with a ridge of knobs
	var tail := _node(body, "Tail", Vector3(0, 0.9, -0.3))
	for k in 4:
		var r := 0.2 - k * 0.045
		_mesh(tail, _cylinder(r - 0.04, r, 0.38), scales, Vector3(0, -0.12 - k * 0.09, -0.18 - k * 0.34), Vector3(-1.25, 0, 0))
		_mesh(tail, _cone(0.04, 0.1), knob, Vector3(0, -0.02 - k * 0.09 + r * 0.8, -0.18 - k * 0.34))

	# Curled up: an armoured ball of shell bands (shown while it rolls)
	var ball := _node(visual, "Ball", Vector3(0, 0.72, 0))
	ball.visible = false
	_mesh(ball, _sphere(0.72), dark, Vector3.ZERO)
	for k in 5:
		var t := TorusMesh.new()
		t.inner_radius = 0.66
		t.outer_radius = 0.76
		t.rings = 28
		var x := -0.5 + k * 0.25
		var r := sqrt(maxf(1.0 - pow(x / 0.72, 2), 0.1))
		_mesh(ball, t, band, Vector3(x, 0, 0), Vector3(0, 0, PI / 2), Vector3(r, 0.5, r))
	_mesh(ball, _sphere(0.22), knob, Vector3(0, 0.1, 0.66), Vector3.ZERO, Vector3(1.0, 0.8, 0.5))   # its nose, tucked in

	# Dizzy stars, shown spinning over its head after a roll
	var stars := _node(visual, "Stars", Vector3(0, 2.25, 0.3))
	stars.visible = false
	var star := _mat("Croc Dizzy Star", Color(1.0, 0.92, 0.35), 0.3, 0.0, 2.0)
	for k in 4:
		var a := k * TAU / 4.0
		_mesh(stars, _sphere(0.08), star, Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))

	_own(croc)
	var scene := PackedScene.new()
	print("pack=", scene.pack(croc), " save=", ResourceSaver.save(scene, OUT))
	croc.free()
	quit()


func _mat(name: String, c: Color, rough := 0.6, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _node(parent: Node, name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func _cone(r: float, h: float) -> CylinderMesh:
	return _cylinder(0.0, r, h)


func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = croc
		_own(c)
