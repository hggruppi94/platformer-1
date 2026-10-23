extends SceneTree

# Builds res://scenes/vehicles/mothership.tscn: the flying saucer from source_art/reference/world/sky - green midday
# with mothership.png (logic in scripts/mothership.gd). A grey disc 36 m across with a row of gold windows, gold and
# blue lights round its rim, a pale blue glass dome with three spires on top, and a glowing blue light underneath.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_mothership.gd
#
# Its middle is at the origin and it faces +Z. A seat ("Cockpit", a Marker3D under the dome) is where a pilot will sit.

const OUT_DIR := "res://scenes/vehicles"
const OUT := OUT_DIR + "/mothership.tscn"
const R := 18.0                                   # hull radius

var ship: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	ship = Node3D.new()
	ship.name = "Mothership"
	ship.set_script(load("res://scripts/mothership.gd"))
	var hull := Node3D.new()
	hull.name = "Hull"
	ship.add_child(hull)

	var metal := _mat("Ship Metal", Color(0.8, 0.82, 0.88), 0.3, 0.6)
	var under := _mat("Ship Underside", Color(0.5, 0.53, 0.6), 0.4, 0.6)
	var glass := _mat("Ship Dome", Color(0.58, 0.82, 0.96, 0.82), 0.05, 0.1, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var spire := _mat("Ship Spire", Color(0.72, 0.75, 0.82), 0.25, 0.8)
	var gold := _mat("Ship Light Gold", Color(1.0, 0.82, 0.35), 0.3, 0.0, 2.5)
	var blue := _mat("Ship Light Blue", Color(0.5, 0.88, 1.0), 0.3, 0.0, 2.5)
	var window := _mat("Ship Window", Color(1.0, 0.86, 0.45), 0.4, 0.0, 1.6)
	var beam := _mat("Ship Glow", Color(0.55, 0.9, 1.0), 0.2, 0.0, 3.0)

	_mesh(hull, _sphere(R, 5.5, 64), metal, Vector3.ZERO)                     # the disc
	_mesh(hull, _cyl(R * 0.99, R * 0.99, 0.35, 64), under, Vector3(0, -0.2, 0)) # the seam round its edge
	_mesh(hull, _sphere(R * 0.68, 4.2, 48), under, Vector3(0, -1.6, 0))        # the lower hull
	_mesh(hull, _cyl(6.0, 6.0, 0.3, 40), beam, Vector3(0, -3.6, 0))            # the glowing light underneath
	var dome := _sphere(7.6, 7.6, 40)
	dome.is_hemisphere = true
	_mesh(hull, dome, glass, Vector3(0, 1.6, 0))
	for s in [[0.0, 11.0, 0.0], [-2.6, 7.5, -0.4], [2.6, 7.5, 0.4]]:           # three spires: x, height, z
		var base := Vector3(s[0], 6.4, s[2])
		_mesh(hull, _cyl(0.0, 0.75, s[1], 12), spire, base + Vector3(0, s[1] / 2.0, 0))
		_mesh(hull, _sphere(0.42, 0.84, 12), gold, base + Vector3(0, s[1] + 0.3, 0))
	# Gold windows along the top of the disc, and rim lights in gold and blue
	for k in 18:
		var a := k * TAU / 18.0
		var d := Vector3(sin(a), 0, cos(a))
		var w := _mesh(hull, _box(Vector3(1.6, 0.55, 0.3)), window, d * (R * 0.64) + Vector3(0, 2.1, 0))
		w.rotation = Vector3(-0.42, a, 0)
	var lights := Node3D.new()
	lights.name = "RimLights"
	hull.add_child(lights)
	for k in 28:
		var a := k * TAU / 28.0
		_mesh(lights, _sphere(0.38, 0.76, 10), gold if k % 2 == 0 else blue, Vector3(sin(a), 0, cos(a)) * (R * 0.93)
			+ Vector3(0, -0.9, 0))
	var glow := OmniLight3D.new()
	glow.name = "UnderLight"
	glow.light_color = Color(0.55, 0.9, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	glow.position = Vector3(0, -6, 0)
	hull.add_child(glow)
	var seat := Marker3D.new()
	seat.name = "Cockpit"                          # where a pilot will sit, under the dome
	seat.position = Vector3(0, 2.2, 0)
	hull.add_child(seat)

	_own(ship)
	var scene := PackedScene.new()
	print("pack=", scene.pack(ship), " save=", ResourceSaver.save(scene, OUT))
	ship.free()
	quit()


func _mat(name: String, c: Color, rough := 0.6, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.disable_fog = true                            # high in the sky: keep it crisp through the haze
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emit
	return m


func _mesh(parent: Node, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(r: float, h: float, seg: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = seg
	s.rings = seg / 4
	return s


func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = ship
		_own(c)
