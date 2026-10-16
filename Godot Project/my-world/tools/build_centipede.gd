extends SceneTree

# Builds res://scenes/creatures/centipede.tscn: the thing Behind the Walls (logic in scripts/centipede.gd).
# Only the human Head is modelled here; the segmented body and legs are built by the script at runtime.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_centipede.gd
#
# The head faces +Z with its crown at +Y. It's deliberately a little too big and too smooth: a doll-like human face.

const OUT_DIR := "res://scenes/creatures"
const OUT := OUT_DIR + "/centipede.tscn"
const SKIN := Color(0.86, 0.78, 0.74)
const EYE_R := 0.036


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var root := Node3D.new()
	root.name = "Centipede"
	root.set_script(load("res://scripts/centipede.gd"))
	var head := Node3D.new()
	head.name = "Head"
	root.add_child(head)

	var skin := _mat("Pale Skin", SKIN, 0.55)
	skin.rim_enabled = true
	skin.rim = 0.3
	var lip := _mat("Lips", Color(0.66, 0.42, 0.44), 0.45)
	var hair := _mat("Hair", Color(0.08, 0.06, 0.06), 0.35)
	var white := _mat("Eye White", Color(0.95, 0.94, 0.9), 0.15)
	var iris := _mat("Iris", Color(0.3, 0.42, 0.45), 0.2)
	var pupil := _mat("Pupil", Color(0.02, 0.02, 0.02), 0.1)
	var brow := _mat("Brow", Color(0.12, 0.08, 0.07), 0.6)
	var dark := _mat("Mouth Line", Color(0.25, 0.1, 0.12), 0.8)

	# Skull, cheeks and jaw
	_ball(head, "Skull", 0.17, skin, Vector3(0, 0.02, 0), Vector3(1.0, 1.22, 1.06))
	_ball(head, "Jaw", 0.13, skin, Vector3(0, -0.1, 0.035), Vector3(0.95, 0.8, 1.0))
	for s in [-1, 1]:
		_ball(head, "Ear", 0.035, skin, Vector3(0.168 * s, 0.0, 0.0), Vector3(0.45, 1.25, 0.9))
	# Neck stump that joins the first body segment
	var neck := MeshInstance3D.new()
	neck.name = "Neck"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.09
	cyl.height = 0.22
	neck.mesh = cyl
	neck.material_override = skin
	neck.position = Vector3(0, -0.2, -0.06)
	neck.rotation.x = 0.5
	head.add_child(neck)
	# Hair: a dark slicked-back cap and a centre part
	_ball(head, "Hair", 0.178, hair, Vector3(0, 0.07, -0.03), Vector3(1.02, 1.12, 1.05))
	# Nose
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var pm := PrismMesh.new()
	pm.size = Vector3(0.045, 0.075, 0.04)
	nose.mesh = pm
	nose.material_override = skin
	nose.position = Vector3(0, -0.005, 0.18)
	head.add_child(nose)
	_ball(head, "NoseTip", 0.019, skin, Vector3(0, -0.035, 0.195), Vector3.ONE)
	# Closed mouth with a faint, patient smile
	for s in [-1, 1]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.009, 0.012)
		m.mesh = bm
		m.material_override = dark
		m.position = Vector3(0.02 * s, -0.085, 0.165)
		m.rotation = Vector3(0, -0.35 * s, 0.22 * s)         # corners turned up: a small, patient smile
		head.add_child(m)
	_ball(head, "Lip", 0.026, lip, Vector3(0, -0.096, 0.156), Vector3(1.3, 0.22, 0.55))
	# Eyes: pivots so the script can turn them to follow Nina; lids that drop down over them to blink
	for s in [-1, 1]:
		var side := "L" if s < 0 else "R"
		var eye := Node3D.new()
		eye.name = "Eye" + side
		eye.position = Vector3(0.058 * s, 0.035, 0.142)
		head.add_child(eye)
		_ball(eye, "White", EYE_R, white, Vector3.ZERO, Vector3.ONE)
		_ball(eye, "Iris", EYE_R * 0.52, iris, Vector3(0, 0, EYE_R * 0.9), Vector3(1, 1, 0.35))
		_ball(eye, "Pupil", EYE_R * 0.2, pupil, Vector3(0, 0, EYE_R * 1.02), Vector3(1, 1, 0.35))
		var lid := Node3D.new()                  # pivot at the top of the eye; scaling Y lowers the lid
		lid.name = "Lid" + side
		lid.position = eye.position + Vector3(0, EYE_R * 0.95, 0)
		lid.scale = Vector3(1, 0.05, 1)
		head.add_child(lid)
		_ball(lid, "Lid", EYE_R * 1.12, skin, Vector3(0, -EYE_R * 1.0, 0.002), Vector3(1.0, 1.0, 1.0))
		var b := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.06, 0.012, 0.015)
		b.mesh = bm2
		b.material_override = brow
		b.position = Vector3(0.06 * s, 0.085, 0.158)
		b.rotation.z = -0.15 * s                 # inner ends raised: mild, interested
		head.add_child(b)
	head.scale = Vector3.ONE * 1.25              # a little too big for a person

	_own(root, root)
	var scene := PackedScene.new()
	print("pack=", scene.pack(root), " save=", ResourceSaver.save(scene, OUT), " ", OUT)
	root.free()
	quit()


func _mat(n: String, c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_color = c
	m.roughness = rough
	return m


func _ball(parent: Node, n: String, r: float, m: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)
