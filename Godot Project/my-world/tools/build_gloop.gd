extends SceneTree

# Builds res://scenes/enemies/gloop.tscn: the Gloop enemy (logic in scripts/gloop.gd).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_gloop.gd
#
# Feet at the origin, facing +Z like the glTF characters. Size and colour are set per Gloop where it's placed.

const OUT_DIR := "res://scenes/enemies"
const OUT := OUT_DIR + "/gloop.tscn"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var root := CharacterBody3D.new()
	root.name = "Gloop"
	root.set_script(load("res://scripts/gloop.gd"))

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var body_shape := SphereShape3D.new()
	body_shape.radius = 0.42
	cs.shape = body_shape
	cs.position = Vector3(0, 0.42, 0)
	root.add_child(cs)

	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hit_shape := SphereShape3D.new()
	hit_shape.radius = 0.62
	hcs.shape = hit_shape
	hcs.position = Vector3(0, 0.45, 0)
	hitbox.add_child(hcs)
	root.add_child(hitbox)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var jelly := StandardMaterial3D.new()
	jelly.resource_name = "Gloop Jelly"
	jelly.albedo_color = Color(0.5, 0.28, 0.92, 0.94)
	jelly.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jelly.roughness = 0.3
	jelly.rim_enabled = true
	jelly.rim = 0.25
	jelly.emission_enabled = true
	jelly.emission = jelly.albedo_color
	jelly.emission_energy_multiplier = 0.1
	var white := _mat("Gloop Eye", Color(1, 1, 1), 0.3)
	var black := _mat("Gloop Pupil", Color(0.05, 0.03, 0.08), 0.2)
	var brow := _mat("Gloop Brow", Color(0.22, 0.1, 0.35), 0.6)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.8
	body.mesh = sm
	body.material_override = jelly
	body.position = Vector3(0, 0.4, 0)
	visual.add_child(body)

	# Face lives on the body so it squishes with it
	for s in [-1, 1]:
		var eye := _sphere(0.12, white)
		eye.position = Vector3(0.17 * s, 0.12, 0.38)
		body.add_child(eye)
		var pupil := _sphere(0.06, black)
		pupil.position = Vector3(0.0, -0.01, 0.09)
		eye.add_child(pupil)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.17, 0.04, 0.04)
		b.mesh = bm
		b.material_override = brow
		b.position = Vector3(0.16 * s, 0.27, 0.42)
		b.rotation.z = 0.45 * s                        # inner ends lower: grumpy
		body.add_child(b)

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


func _sphere(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = m
	return mi


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)
