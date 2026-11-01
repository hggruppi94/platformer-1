extends SceneTree

# Builds the Time Goblins, the Agent of Chaos's cheeky little helpers (asked for by Hayden, Nov 1, 2026):
#
#   res://scenes/enemies/time_goblin.tscn       a Time Goblin (logic in scripts/time_goblin.gd)
#   res://scenes/enemies/time_goblin_boss.tscn  Grandfather Tock, their boss: a big old goblin with a grandfather clock
#                                               for a hat and a swinging pendulum (logic in scripts/time_goblin_boss.gd)
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_time_goblin.gd
#
# Made from simple shapes in the alien palette, like the gadgets: a round teal goblin on short legs, with long pointy
# ears, big glowing amber eyes, a long nose and a wide grin, a little top hat with a brass cog, and a gold pocket watch
# set in its belly whose hands run backwards. Feet at the origin, facing +Z like the glTF characters.
# The script finds these by name: Visual, Visual/Body, Visual/Head, Visual/Watch/Hour, Visual/Watch/Minute,
# Visual/LegL, Visual/LegR, Visual/ArmL, Visual/ArmR (and on the boss Visual/Head/Clock/Pendulum).

const OUT_DIR := "res://scenes/enemies"

const SKIN := Color(0.12, 0.52, 0.48)         # teal, like the town's leaves
const SKIN_DARK := Color(0.08, 0.42, 0.42)
const CLOTH := Color(0.42, 0.2, 0.62)         # plum waistcoat and trousers
const CLOTH_DARK := Color(0.22, 0.1, 0.34)
const GOLD := Color(1.0, 0.76, 0.28)
const BRASS := Color(0.78, 0.55, 0.22)
const FACE := Color(0.98, 0.95, 0.85)
const EYE := Color(1.0, 0.72, 0.15)
const INK := Color(0.08, 0.05, 0.12)
const WOOD := Color(0.45, 0.22, 0.18)

var _mats := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_goblin("Time Goblin", "res://scripts/time_goblin.gd", false), OUT_DIR + "/time_goblin.tscn")
	_save(_goblin("Grandfather Tock", "res://scripts/time_goblin_boss.gd", true), OUT_DIR + "/time_goblin_boss.tscn")
	quit()


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var scene := PackedScene.new()
	print("pack=", scene.pack(root), " save=", ResourceSaver.save(scene, path), " ", path)
	root.free()


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)


func _mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [c, glow, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35 if metal > 0.0 else 0.6
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _mesh(parent: Node3D, n: String, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _sphere(r: float, segs := 20) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 14
	c.rings = 4
	return c


func _cyl(top: float, bottom: float, h: float, segs := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _goblin(n: String, script: String, boss: bool) -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = n
	root.set_script(load(script))

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.9
	cs.shape = cap
	cs.position = Vector3(0, 0.45, 0)
	root.add_child(cs)

	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.5
	hcs.shape = hs
	hcs.position = Vector3(0, 0.5, 0)
	hitbox.add_child(hcs)
	root.add_child(hitbox)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	# Legs and pointy curled shoes (the legs swing from the hip, so each is a pivot with the leg hanging below)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.name = "LegL" if side < 0 else "LegR"
		hip.position = Vector3(0.11 * side, 0.3, 0)
		visual.add_child(hip)
		_mesh(hip, "Leg", _capsule(0.065, 0.3), _mat(CLOTH_DARK), Vector3(0, -0.13, 0))
		_mesh(hip, "Shoe", _sphere(0.08, 12), _mat(INK), Vector3(0, -0.27, 0.05), Vector3.ZERO, Vector3(0.9, 0.6, 1.6))
		_mesh(hip, "Toe", _cyl(0.0, 0.04, 0.12, 8), _mat(INK), Vector3(0, -0.25, 0.17), Vector3(1.2, 0, 0))

	# The round body: a pot belly in a plum waistcoat, with the pocket watch set in front
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.48, 0)
	visual.add_child(body)
	_mesh(body, "Belly", _sphere(0.27, 24), _mat(SKIN), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.95, 0.9))
	_mesh(body, "Waistcoat", _sphere(0.275, 24), _mat(CLOTH), Vector3(0, 0.02, -0.02), Vector3.ZERO,
		Vector3(1.02, 0.85, 0.86))
	for i in 3:
		_mesh(body, "Button%d" % i, _sphere(0.018, 8), _mat(GOLD, 0.0, 0.8), Vector3(0.13, 0.12 - i * 0.07, 0.22))

	var watch := Node3D.new()
	watch.name = "Watch"
	watch.position = Vector3(0, 0.48, 0.235)
	visual.add_child(watch)
	_mesh(watch, "Case", _cyl(0.13, 0.13, 0.05, 28), _mat(GOLD, 0.0, 0.9), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_mesh(watch, "Face", _cyl(0.11, 0.11, 0.02, 28), _mat(FACE, 0.35), Vector3(0, 0, 0.02), Vector3(PI / 2, 0, 0))
	_mesh(watch, "Crown", _cyl(0.025, 0.025, 0.04, 10), _mat(GOLD, 0.0, 0.9), Vector3(0, 0.15, 0))
	for i in 12:
		var a := TAU * i / 12.0
		var tick := _mesh(watch, "Tick%d" % i, _box(Vector3(0.008, 0.022 if i % 3 == 0 else 0.012, 0.004)), _mat(INK),
			Vector3(sin(a) * 0.09, cos(a) * 0.09, 0.032))
		tick.rotation.z = -a
	# Hands pivot at the middle of the face; the script turns them (backwards)
	var hour := Node3D.new()
	hour.name = "Hour"
	hour.position = Vector3(0, 0, 0.036)
	watch.add_child(hour)
	_mesh(hour, "Hand", _box(Vector3(0.012, 0.055, 0.005)), _mat(INK), Vector3(0, 0.026, 0))
	var minute := Node3D.new()
	minute.name = "Minute"
	minute.position = Vector3(0, 0, 0.04)
	watch.add_child(minute)
	_mesh(minute, "Hand", _box(Vector3(0.008, 0.085, 0.005)), _mat(Color(0.75, 0.15, 0.3)), Vector3(0, 0.04, 0))
	_mesh(watch, "Pin", _cyl(0.012, 0.012, 0.012, 8), _mat(GOLD, 0.0, 0.9), Vector3(0, 0, 0.045),
		Vector3(PI / 2, 0, 0))
	# A chain looping from the watch to a waistcoat button
	for i in 5:
		var t := (i + 1) / 6.0
		_mesh(watch, "Chain%d" % i, _sphere(0.012, 6), _mat(GOLD, 0.0, 0.9),
			Vector3(lerpf(0.12, 0.13, t), lerpf(0.0, -0.2, t) * 0.5 - sin(t * PI) * 0.06, -0.01 + 0.01 * sin(t * PI)))

	# Long thin arms with big hands (they swing from the shoulder)
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.name = "ArmL" if side < 0 else "ArmR"
		sh.position = Vector3(0.26 * side, 0.62, 0)
		sh.rotation.z = 0.35 * side
		visual.add_child(sh)
		_mesh(sh, "Arm", _capsule(0.045, 0.34), _mat(SKIN), Vector3(0, -0.15, 0))
		_mesh(sh, "Hand", _sphere(0.065, 12), _mat(SKIN_DARK), Vector3(0, -0.33, 0.01), Vector3.ZERO,
			Vector3(1.0, 1.1, 0.8))
		for f in 3:
			_mesh(sh, "Finger%d" % f, _capsule(0.016, 0.07), _mat(SKIN_DARK),
				Vector3((f - 1) * 0.03, -0.39, 0.02), Vector3(0.2, 0, 0))

	# The head: wide and round, big ears, glowing eyes, a long nose and a cheeky grin
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.86, 0.02)
	visual.add_child(head)
	_mesh(head, "Skull", _sphere(0.22, 24), _mat(SKIN), Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 0.92, 1.0))
	for side in [-1.0, 1.0]:
		var ear := _mesh(head, "Ear" + ("L" if side < 0 else "R"), _cyl(0.0, 0.07, 0.34, 10), _mat(SKIN),
			Vector3(0.3 * side, 0.06, -0.02), Vector3(0, 0, -side * 1.25), Vector3(1.0, 1.0, 0.45))
		_mesh(ear, "Inner", _cyl(0.0, 0.045, 0.26, 8), _mat(Color(0.85, 0.45, 0.6)), Vector3(0, -0.02, 0.018),
			Vector3.ZERO, Vector3(1.0, 1.0, 0.4))
		_mesh(head, "Eye" + ("L" if side < 0 else "R"), _sphere(0.06, 14), _mat(EYE, 2.2),
			Vector3(0.085 * side, 0.04, 0.17), Vector3.ZERO, Vector3(1.0, 1.15, 0.6))
		_mesh(head, "Pupil" + ("L" if side < 0 else "R"), _sphere(0.026, 10), _mat(INK),
			Vector3(0.085 * side, 0.035, 0.205), Vector3.ZERO, Vector3(0.7, 1.4, 0.5))
		_mesh(head, "Brow" + ("L" if side < 0 else "R"), _box(Vector3(0.08, 0.018, 0.02)), _mat(SKIN_DARK),
			Vector3(0.09 * side, 0.115, 0.18), Vector3(0, 0, side * 0.35))
	_mesh(head, "Nose", _cyl(0.0, 0.045, 0.16, 10), _mat(SKIN_DARK), Vector3(0, -0.01, 0.25), Vector3(1.35, 0, 0))
	# A wide cheeky grin, curling up at the corners
	_mesh(head, "Grin", _sphere(0.1, 16), _mat(INK), Vector3(0, -0.075, 0.175), Vector3.ZERO, Vector3(1.2, 0.28, 0.4))
	for side in [-1.0, 1.0]:
		_mesh(head, "Corner" + ("L" if side < 0 else "R"), _capsule(0.012, 0.06), _mat(INK),
			Vector3(0.12 * side, -0.055, 0.165), Vector3(0, 0, side * 0.9))
	for t in 2:
		_mesh(head, "Tooth%d" % t, _box(Vector3(0.025, 0.03, 0.01)), _mat(FACE),
			Vector3(-0.03 + 0.06 * t, -0.085, 0.205))

	if boss:
		_clock_hat(head)
		# A long plum coat-tail cape and a gold sash: the old goblin dresses up
		_mesh(visual, "Coat", _cyl(0.2, 0.34, 0.5, 20), _mat(CLOTH_DARK), Vector3(0, 0.36, -0.05))
		_mesh(body, "Sash", _box(Vector3(0.08, 0.6, 0.03)), _mat(GOLD, 0.2, 0.6), Vector3(0, 0, 0.24),
			Vector3(0, 0, 0.7))
		# Spectacles on the end of his nose
		for side in [-1.0, 1.0]:
			var lens := TorusMesh.new()
			lens.inner_radius = 0.035
			lens.outer_radius = 0.045
			lens.rings = 14
			lens.ring_segments = 4
			_mesh(head, "Lens" + ("L" if side < 0 else "R"), lens, _mat(GOLD, 0.0, 0.9),
				Vector3(0.085 * side, 0.04, 0.215), Vector3(PI / 2, 0, 0))
	else:
		_top_hat(head)
	return root


func _top_hat(head: Node3D) -> void:
	var hat := Node3D.new()
	hat.name = "Hat"
	hat.position = Vector3(0.02, 0.17, -0.02)
	hat.rotation.z = -0.22
	head.add_child(hat)
	_mesh(hat, "Brim", _cyl(0.17, 0.17, 0.02, 24), _mat(INK), Vector3.ZERO)
	_mesh(hat, "Crown", _cyl(0.1, 0.11, 0.2, 20), _mat(INK), Vector3(0, 0.11, 0))
	_mesh(hat, "Band", _cyl(0.112, 0.112, 0.04, 20), _mat(CLOTH), Vector3(0, 0.035, 0))
	_cog(hat, Vector3(0.0, 0.07, 0.11), 0.05)


func _cog(parent: Node3D, pos: Vector3, r: float) -> void:
	var cog := Node3D.new()
	cog.name = "Cog"
	cog.position = pos
	parent.add_child(cog)
	_mesh(cog, "Wheel", _cyl(r, r, 0.02, 16), _mat(BRASS, 0.0, 0.85), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		var t := _mesh(cog, "Tooth%d" % i, _box(Vector3(r * 0.4, r * 0.4, 0.02)), _mat(BRASS, 0.0, 0.85),
			Vector3(sin(a) * r * 1.1, cos(a) * r * 1.1, 0))
		t.rotation.z = -a
	_mesh(cog, "Hub", _cyl(r * 0.3, r * 0.3, 0.03, 10), _mat(GOLD, 0.0, 0.9), Vector3(0, 0, 0.005),
		Vector3(PI / 2, 0, 0))


func _clock_hat(head: Node3D) -> void:
	# A grandfather clock worn as a tall hat: a wooden case with a peaked top, a glowing clock face and a gold
	# pendulum swinging in a glass window underneath
	var clock := Node3D.new()
	clock.name = "Clock"
	clock.position = Vector3(0, 0.2, -0.02)
	head.add_child(clock)
	_mesh(clock, "Base", _box(Vector3(0.3, 0.04, 0.22)), _mat(WOOD), Vector3(0, 0, 0))
	_mesh(clock, "Case", _box(Vector3(0.24, 0.5, 0.18)), _mat(WOOD), Vector3(0, 0.27, 0))
	_mesh(clock, "Window", _box(Vector3(0.15, 0.22, 0.01)), _mat(Color(0.5, 0.85, 0.9, 1.0), 0.6),
		Vector3(0, 0.17, 0.091))
	var pend := Node3D.new()
	pend.name = "Pendulum"
	pend.position = Vector3(0, 0.27, 0.098)
	clock.add_child(pend)
	_mesh(pend, "Rod", _box(Vector3(0.01, 0.16, 0.005)), _mat(GOLD, 0.0, 0.9), Vector3(0, -0.08, 0))
	_mesh(pend, "Bob", _cyl(0.03, 0.03, 0.01, 16), _mat(GOLD, 0.3, 0.9), Vector3(0, -0.16, 0), Vector3(PI / 2, 0, 0))
	_mesh(clock, "Hood", _box(Vector3(0.28, 0.2, 0.2)), _mat(WOOD), Vector3(0, 0.6, 0))
	_mesh(clock, "Face", _cyl(0.085, 0.085, 0.01, 24), _mat(FACE, 0.8), Vector3(0, 0.6, 0.1), Vector3(PI / 2, 0, 0))
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, 0.6, 0.108)
	clock.add_child(hand)
	_mesh(hand, "Stick", _box(Vector3(0.01, 0.07, 0.004)), _mat(INK), Vector3(0, 0.03, 0))
	var peak := PrismMesh.new()
	peak.size = Vector3(0.32, 0.12, 0.2)
	_mesh(clock, "Peak", peak, _mat(WOOD), Vector3(0, 0.76, 0))
	_mesh(clock, "Finial", _sphere(0.03, 10), _mat(GOLD, 0.0, 0.9), Vector3(0, 0.84, 0))
	_cog(clock, Vector3(0.13, 0.4, 0.0), 0.05)
