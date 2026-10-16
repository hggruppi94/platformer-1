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

	# Face lives on the body so it squishes with it. Wide staring eyes with pinprick pupils, raised brows,
	# and a too-wide grin full of teeth.
	for s in [-1, 1]:
		var eye := _sphere(0.13, white)
		eye.position = Vector3(0.17 * s, 0.13, 0.37)
		body.add_child(eye)
		var pupil := _sphere(0.032, black)
		pupil.position = Vector3(0.015 * s, 0.0, 0.115)   # slightly wall-eyed
		eye.add_child(pupil)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 0.03, 0.03)
		b.mesh = bm
		b.material_override = brow
		b.position = Vector3(0.18 * s, 0.31, 0.37)
		b.rotation.z = -0.3 * s                        # outer ends lower: raised in the middle, eerily delighted
		body.add_child(b)
	var mouth_mat := _mat("Gloop Mouth", Color(0.16, 0.0, 0.05), 0.9)
	mouth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mouth_mat.emission_enabled = true
	mouth_mat.emission = Color(0.9, 0.05, 0.15)       # a faint red glow from inside
	mouth_mat.emission_energy_multiplier = 0.35
	var tooth_mat := _mat("Gloop Teeth", Color(0.98, 0.96, 0.85), 0.4)
	tooth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mouth := MeshInstance3D.new()
	mouth.name = "Grin"
	mouth.mesh = _grin_mesh()
	mouth.material_override = mouth_mat
	body.add_child(mouth)
	var teeth := MeshInstance3D.new()
	teeth.name = "Teeth"
	teeth.mesh = _teeth_mesh()
	teeth.material_override = tooth_mat
	body.add_child(teeth)

	_own(root, root)
	var scene := PackedScene.new()
	print("pack=", scene.pack(root), " save=", ResourceSaver.save(scene, OUT), " ", OUT)
	root.free()
	quit()


# --- Grin ------------------------------------------------------------------
# The mouth is drawn on the body's surface (an ellipsoid, radii BODY_R) as a crescent between two arcs, given
# in longitude/latitude around the face. t runs -1..1 from one corner of the mouth to the other.
const BODY_R := Vector3(0.5, 0.4, 0.5)
const GRIN_HALF_WIDTH := 0.95      # radians of longitude each side of center: very wide, almost ear to ear
const GRIN_SEGMENTS := 28


func _surface(lon: float, lat: float, lift := 1.012) -> Vector3:
	return Vector3(BODY_R.x * cos(lat) * sin(lon), BODY_R.y * sin(lat), BODY_R.z * cos(lat) * cos(lon)) * lift


func _grin_top(t: float) -> float:
	return 0.06 - 0.2 * (1.0 - t * t) + 0.14 * pow(absf(t), 6.0)       # corners curl up toward the eyes


func _grin_bottom(t: float) -> float:
	return _grin_top(t) - 0.42 * pow(1.0 - t * t, 0.8)                 # deepest in the middle, pinched at the ends


func _grin_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Subdivided top-to-bottom too, so the flat pieces hug the curved body instead of sinking into it
	var rows := 6
	for i in GRIN_SEGMENTS:
		var t0 := lerpf(-1.0, 1.0, float(i) / GRIN_SEGMENTS)
		var t1 := lerpf(-1.0, 1.0, float(i + 1) / GRIN_SEGMENTS)
		for r in rows:
			var f0 := float(r) / rows
			var f1 := float(r + 1) / rows
			var a := _surface(t0 * GRIN_HALF_WIDTH, lerpf(_grin_top(t0), _grin_bottom(t0), f0))
			var b := _surface(t1 * GRIN_HALF_WIDTH, lerpf(_grin_top(t1), _grin_bottom(t1), f0))
			var c := _surface(t0 * GRIN_HALF_WIDTH, lerpf(_grin_top(t0), _grin_bottom(t0), f1))
			var d := _surface(t1 * GRIN_HALF_WIDTH, lerpf(_grin_top(t1), _grin_bottom(t1), f1))
			for v in [a, c, b, b, c, d]:
				st.set_normal(v.normalized())
				st.add_vertex(v)
	return st.commit()


func _teeth_mesh() -> ArrayMesh:
	# Rows of small pointed teeth hanging from the top lip and rising from the bottom lip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 13
	for row in [0, 1]:
		for k in n:
			var t0 := lerpf(-0.9, 0.9, float(k) / n)
			var t1 := lerpf(-0.9, 0.9, float(k + 1) / n)
			var tm := (t0 + t1) / 2.0
			var depth := (_grin_top(tm) - _grin_bottom(tm)) * (0.42 if row == 0 else 0.3)
			var lift := 1.025                          # teeth sit just in front of the mouth
			var a: Vector3
			var b: Vector3
			var tip: Vector3
			if row == 0:
				a = _surface(t0 * GRIN_HALF_WIDTH, _grin_top(t0) + 0.01, lift)
				b = _surface(t1 * GRIN_HALF_WIDTH, _grin_top(t1) + 0.01, lift)
				tip = _surface(tm * GRIN_HALF_WIDTH, _grin_top(tm) - depth, lift)
			else:
				a = _surface(t0 * GRIN_HALF_WIDTH, _grin_bottom(t0) - 0.01, lift)
				b = _surface(t1 * GRIN_HALF_WIDTH, _grin_bottom(t1) - 0.01, lift)
				tip = _surface(tm * GRIN_HALF_WIDTH, _grin_bottom(tm) + depth, lift)
			for v in [a, tip, b]:
				st.set_normal(v.normalized())
				st.add_vertex(v)
	return st.commit()


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
