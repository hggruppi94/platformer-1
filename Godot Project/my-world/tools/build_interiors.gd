extends SceneTree

# Builds walkable interiors for town buildings, each a round domed room matching its building:
#   res://scenes/interiors/cafe.tscn, aquarium.tscn, restaurant_and_cafe.tscn, ninas_house.tscn
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_interiors.gd
#
# Each interior has an "Entrance" spawn marker (where you appear coming in from town) and an exit door that takes
# you back to the "From<Building>" marker in front of the building in town. The door is on the south (+Z) side.

const WT := preload("res://tools/theme.gd")     # shared look (alien/earth): tools/theme.gd
const OUT_DIR := "res://scenes/interiors"
const TOWN := "res://scenes/town/town.tscn"

var scene_root: Node3D
var mats := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("cafe", _cafe())
	_save("aquarium", _aquarium())
	_save("restaurant_and_cafe", _restaurant())
	_save("ninas_house", _ninas_house())
	quit()


func _save(file: String, root_node: Node3D) -> void:
	var scene := PackedScene.new()
	var err := scene.pack(root_node)
	print("SAVED ", file, " pack=", err, " save=", ResourceSaver.save(scene, "%s/%s.tscn" % [OUT_DIR, file]))
	root_node.free()


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func own(n: Node) -> void:
	if n != scene_root:
		n.owner = scene_root
	if n != scene_root and n.scene_file_path != "":
		return
	for c in n.get_children():
		own(c)


func mat(name: String, color: Color, rough := 0.8, metal := 0.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	color = WT.tint(color, true)
	m.resource_name = name
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[name] = m
	return m


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func cylinder(top: float, bottom: float, h: float, segments := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	return c


func sphere(r: float, segments := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = segments
	s.rings = segments / 2
	return s


func node(name: String, parent: Node, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


func mesh_at(mesh: Mesh, material: Material, pos: Vector3, parent: Node, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func solid(shape: Shape3D, mesh: Mesh, material: Material, pos: Vector3, parent: Node, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	if mesh:
		mesh_at(mesh, material, Vector3.ZERO, body)
	parent.add_child(body)
	return body


func solid_box(size: Vector3, material: Material, pos: Vector3, parent: Node, yaw := 0.0) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return solid(shape, box(size), material, pos, parent, yaw)


func solid_cyl(r: float, h: float, material: Material, pos: Vector3, parent: Node) -> StaticBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	return solid(shape, cylinder(r, r, h), material, pos, parent)


func label(parent: Node, text: String, pos: Vector3, size := 56, color := Color(1, 1, 1)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.15, 0.1, 0.12)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(l)


func light(parent: Node, pos: Vector3, color: Color, energy := 1.0, rng := 12.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = WT.light(color)
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)


func dome_room(name: String, r: float, shell_color: Color, floor_color: Color, ambient: Color) -> Node3D:
	# A round room under a dome: floor, ring wall with a doorway on the south, dome ceiling seen from inside,
	# windows, exit door back to town, and the entrance spawn marker.
	scene_root = Node3D.new()
	scene_root.name = name.replace(" ", "")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = WT.backdrop(Color(0.1, 0.1, 0.12))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = WT.light(ambient)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	scene_root.add_child(we)

	solid_cyl(r + 1, 0.4, mat("Floor " + name, floor_color, 0.7), Vector3(0, -0.2, 0), scene_root)
	var dome := SphereMesh.new()
	dome.radius = r
	dome.height = r * 1.6
	dome.radial_segments = 48
	dome.rings = 24
	dome.is_hemisphere = true
	dome.flip_faces = true                              # we see it from inside
	mesh_at(dome, mat("Dome " + name, shell_color, 0.7), Vector3(0, -0.1, 0), scene_root)     # its flat base hides under the floor
	var wall_m := mat("Wall " + name, shell_color.darkened(0.08), 0.8)
	var segments := 32
	for k in segments:
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		var mid := (a0 + a1) / 2
		if absf(wrapf(mid - PI / 2, -PI, PI)) < 0.12:
			continue                                     # doorway at the south (+Z)
		var p := Vector3(cos(mid), 0, sin(mid)) * r
		var seg_len := 2 * r * sin(PI / segments) + 0.05
		solid_box(Vector3(0.4, 3.2, seg_len), wall_m, p + Vector3(0, 1.6, 0), scene_root, -mid)
	# Window band like the outside of the domes
	var glass := mat("Window Glow", Color(0.55, 0.8, 1.0), 0.1, 0.0, 1.2)
	for k in 10:
		var a := PI / 2 + PI * 0.18 + k * (PI * 1.64 / 9)
		mesh_at(box(Vector3(0.1, 1.2, 1.8)), glass, Vector3(cos(a), 0, sin(a)) * (r - 0.25) + Vector3(0, 2.6, 0), scene_root, -a)
	# Exit back to town and the spawn point just inside the door
	solid_box(Vector3(2.6, 3.2, 0.2), mat("Door Glow", Color(1.0, 0.9, 0.6), 0.5, 0.0, 1.5), Vector3(0, 1.6, r + 0.6), scene_root)
	label(scene_root, "Exit", Vector3(0, 3.6, r + 0.3), 40)
	var exit := Area3D.new()
	exit.name = "ExitToTown"
	exit.position = Vector3(0, 1.5, r + 0.3)
	exit.set_script(load("res://scripts/door.gd"))
	exit.set("destination", TOWN)
	exit.set("spawn", "From" + name.replace(" ", "").replace("&", "And").replace("'", ""))
	var ecs := CollisionShape3D.new()
	var eshape := BoxShape3D.new()
	eshape.size = Vector3(2.4, 3.0, 1.0)
	ecs.shape = eshape
	exit.add_child(ecs)
	scene_root.add_child(exit)
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	entrance.position = Vector3(0, 1.0, r - 4.5)
	scene_root.add_child(entrance)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = entrance.position
	scene_root.add_child(player)
	return scene_root


# -----------------------------------------------------------------------------
# Cafe: counter, pastry case, coffee machine, menu board, tables
# -----------------------------------------------------------------------------
func _cafe() -> Node3D:
	var r := 11.0
	var root_node := dome_room("Cafe", r, Color(0.98, 0.84, 0.45), Color(0.62, 0.42, 0.26), Color(1.0, 0.9, 0.75))
	var wood := mat("Cafe Wood", Color(0.5, 0.3, 0.16), 0.6)
	var cream := mat("Cafe Cream", Color(0.97, 0.93, 0.85), 0.5)
	# Counter along the back (north) with the register and coffee machine
	solid_box(Vector3(8, 1.1, 1.2), wood, Vector3(0, 0.55, -6), root_node)
	mesh_at(box(Vector3(8.2, 0.1, 1.4)), cream, Vector3(0, 1.15, -6), root_node)
	mesh_at(box(Vector3(0.6, 0.4, 0.5)), mat("Register", Color(0.2, 0.2, 0.22), 0.4, 0.5), Vector3(-2.5, 1.4, -6), root_node)
	var steel := mat("Steel", Color(0.75, 0.76, 0.8), 0.25, 0.9)
	solid_box(Vector3(1.6, 1.3, 0.9), steel, Vector3(2.8, 0.65 + 1.15, -6.6), root_node)
	mesh_at(cylinder(0.12, 0.12, 0.3, 12), mat("Cup", Color(1, 1, 1), 0.3), Vector3(2.5, 1.35, -6.0), root_node)
	label(root_node, "Coffee", Vector3(2.8, 3.0, -6.6), 40)
	# Glass pastry case with colorful treats
	solid_box(Vector3(3.6, 1.0, 1.0), wood, Vector3(-4.5, 0.5, -4.4), root_node)
	mesh_at(box(Vector3(3.6, 0.7, 1.0)), mat("Case Glass", Color(0.8, 0.95, 1.0), 0.05, 0.0, 0.0, 0.3), Vector3(-4.5, 1.35, -4.4), root_node)
	var treats := [Color(0.95, 0.55, 0.7), Color(0.98, 0.85, 0.45), Color(0.6, 0.4, 0.25), Color(0.75, 0.6, 0.95)]
	for k in 6:
		mesh_at(sphere(0.18, 10), mat("Treat %d" % (k % 4), treats[k % 4], 0.6), Vector3(-5.9 + k * 0.56, 1.2, -4.4), root_node)
	# Menu board on the back wall
	mesh_at(box(Vector3(4.5, 2.2, 0.15)), mat("Chalkboard", Color(0.12, 0.18, 0.15), 0.9), Vector3(0, 3.0, -r + 0.5), root_node)
	label(root_node, "MENU\nCocoa  Latte  Juice\nCupcakes  Cookies", Vector3(0, 3.0, -r + 0.7), 40, Color(1, 0.98, 0.9))
	# Round tables with stools
	for t in [Vector2(-5, 2), Vector2(0, 1), Vector2(5, 2), Vector2(-3, 6), Vector2(3, 6)]:
		solid_cyl(0.9, 0.08, cream, Vector3(t.x, 0.95, t.y), root_node)
		mesh_at(cylinder(0.08, 0.15, 0.95, 8), wood, Vector3(t.x, 0.47, t.y), root_node)
		for k in 3:
			var a := TAU * k / 3 + 0.5
			solid_cyl(0.3, 0.6, mat("Stool", Color(0.9, 0.45, 0.4), 0.6), Vector3(t.x + cos(a) * 1.5, 0.3, t.y + sin(a) * 1.5), root_node)
	# Plants and warm lights
	for p in [Vector2(-8, -3), Vector2(8, -3), Vector2(-7.5, 5.5), Vector2(7.5, 5.5)]:
		solid_cyl(0.45, 0.7, mat("Pot", Color(0.85, 0.5, 0.35), 0.8), Vector3(p.x, 0.35, p.y), root_node)
		mesh_at(sphere(0.8, 12), mat("Plant", Color(0.3, 0.65, 0.3), 0.9), Vector3(p.x, 1.4, p.y), root_node)
	light(root_node, Vector3(0, 6, 0), Color(1.0, 0.85, 0.6), 1.6, 16)
	light(root_node, Vector3(0, 3, -5), Color(1.0, 0.8, 0.55), 1.0, 8)
	label(root_node, "Cafe", Vector3(0, 5.5, -2), 96, Color(1, 0.95, 0.8))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# Aquarium: glowing tanks of swimming fish around the wall and a tall center tank
# -----------------------------------------------------------------------------
func _aquarium() -> Node3D:
	var r := 13.0
	var root_node := dome_room("Aquarium", r, Color(0.35, 0.6, 0.95), Color(0.2, 0.3, 0.45), Color(0.55, 0.75, 1.0))
	var water := mat("Tank Water", Color(0.2, 0.6, 0.95), 0.05, 0.0, 0.8, 0.45)
	var frame := mat("Tank Frame", Color(0.15, 0.2, 0.3), 0.4, 0.6)
	var fish_colors := [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.2), Color(0.95, 0.4, 0.65), Color(0.4, 0.95, 0.8),
		Color(0.7, 0.55, 1.0)]
	# Wall tanks around the room (leaving the doorway clear)
	for k in 8:
		var a := PI / 2 + 0.6 + k * ((TAU - 1.2) / 7)
		var p := Vector3(cos(a), 0, sin(a)) * (r - 1.6)
		var tank := node("Tank %d" % (k + 1), root_node, p, -a)
		solid_box(Vector3(1.6, 2.6, 3.4), water, Vector3(0, 1.6, 0), tank)
		mesh_at(box(Vector3(1.8, 0.3, 3.6)), frame, Vector3(0, 0.15, 0), tank)
		mesh_at(box(Vector3(1.8, 0.2, 3.6)), frame, Vector3(0, 3.0, 0), tank)
		var school := node("Fish", tank, Vector3(0, 1.6, 0))
		school.set_script(load("res://scripts/fish_school.gd"))
		school.set("half_size", Vector3(0.5, 0.9, 1.4))
		for f in 4:
			fish(school, fish_colors[(k + f) % fish_colors.size()], 0.16 + 0.05 * (f % 2))
	# Tall center tank with a bigger school and a glow
	var center := node("Center Tank", root_node)
	solid_cyl(3.0, 0.4, frame, Vector3(0, 0.2, 0), center)
	var big := solid_cyl(2.8, 5.0, water, Vector3(0, 2.9, 0), center)
	big.name = "Water"
	mesh_at(cylinder(3.0, 3.0, 0.3, 32), frame, Vector3(0, 5.5, 0), center)
	var big_school := node("Fish", center, Vector3(0, 2.9, 0))
	big_school.set_script(load("res://scripts/fish_school.gd"))
	big_school.set("radius", 2.2)
	big_school.set("half_size", Vector3(0, 2.0, 0))
	for f in 10:
		fish(big_school, fish_colors[f % fish_colors.size()], 0.22 + 0.06 * (f % 3))
	for k in 4:                                       # glowing jellyfish
		var j := mesh_at(sphere(0.35, 12), mat("Jelly", Color(0.95, 0.6, 1.0), 0.2, 0.0, 2.0, 0.7),
			Vector3(cos(k * 1.6) * 1.2, 4.2 - k * 0.7, sin(k * 1.6) * 1.2), center)
		j.scale = Vector3(1, 0.7, 1)
	light(center, Vector3(0, 3, 0), Color(0.4, 0.75, 1.0), 2.0, 12)
	# Benches facing the center tank
	for k in 4:
		var a := k * TAU / 4 + PI / 4
		solid_box(Vector3(2.4, 0.5, 0.7), mat("Bench", Color(0.85, 0.85, 0.9), 0.5), Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3(0, 0.25, 0),
			root_node, -a + PI / 2)
	light(root_node, Vector3(0, 7, 0), Color(0.6, 0.8, 1.0), 1.0, 20)
	label(root_node, "Aquarium", Vector3(0, 7.2, -3), 96, Color(0.85, 0.95, 1.0))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# Restaurant & Cafe: booths around the wall, a kitchen pass with a chef station, dining tables with cloths
# -----------------------------------------------------------------------------
func _restaurant() -> Node3D:
	var r := 12.0
	var root_node := dome_room("Restaurant & Cafe", r, Color(0.98, 0.8, 0.4), Color(0.55, 0.35, 0.22), Color(1.0, 0.88, 0.72))
	var wood := mat("Resto Wood", Color(0.45, 0.26, 0.14), 0.6)
	var red := mat("Booth Red", Color(0.78, 0.22, 0.22), 0.6)
	var cloth := mat("Tablecloth", Color(0.98, 0.97, 0.93), 0.7)
	var steel := mat("Steel", Color(0.75, 0.76, 0.8), 0.25, 0.9)
	# Kitchen at the back: pass-through counter, stove, chef's hat on a hook
	solid_box(Vector3(10, 1.1, 1.0), steel, Vector3(0, 0.55, -7.2), root_node)
	mesh_at(box(Vector3(10.2, 0.1, 1.2)), wood, Vector3(0, 1.15, -7.2), root_node)
	solid_box(Vector3(3.0, 0.9, 1.2), mat("Stove", Color(0.2, 0.2, 0.22), 0.4, 0.6), Vector3(-2.5, 0.45, -9.2), root_node)
	for k in 4:
		mesh_at(cylinder(0.25, 0.25, 0.05, 16), mat("Burner", Color(0.95, 0.35, 0.1), 0.5, 0.0, 1.5),
			Vector3(-3.4 + k * 0.6, 0.93, -9.2), root_node)
	mesh_at(cylinder(0.3, 0.25, 0.35, 16), mat("Pot Steel", Color(0.7, 0.72, 0.76), 0.3, 0.9), Vector3(-2.2, 1.1, -9.2), root_node)
	for k in 3:
		mesh_at(sphere(0.22, 10), mat("Plate Food %d" % k, [Color(0.95, 0.75, 0.3), Color(0.5, 0.75, 0.35), Color(0.85, 0.35, 0.3)][k], 0.6),
			Vector3(-1.5 + k * 1.5, 1.35, -7.2), root_node)
	label(root_node, "Kitchen", Vector3(0, 3.0, -8.5), 48)
	# Booths around the side walls
	for k in 6:
		var a := PI / 2 + 0.75 + k * ((TAU - 1.5) / 5)
		if absf(wrapf(a - (-PI / 2), -PI, PI)) < 0.7:
			continue                                     # leave the kitchen side clear
		var p := Vector3(cos(a), 0, sin(a)) * (r - 1.8)
		var booth := node("Booth %d" % (k + 1), root_node, p, -a)
		solid_box(Vector3(0.6, 1.3, 2.4), red, Vector3(0.9, 0.65, 0), booth)
		solid_box(Vector3(1.0, 0.75, 1.2), cloth, Vector3(-0.2, 0.37, 0), booth)
		solid_box(Vector3(0.6, 0.6, 2.4), red, Vector3(-1.3, 0.3, 0), booth)
	# Dining tables in the middle with tablecloths and a candle each
	for t in [Vector2(-3.5, -1.5), Vector2(3.5, -1.5), Vector2(0, 2), Vector2(-4, 4.5), Vector2(4, 4.5)]:
		solid_cyl(1.0, 0.85, cloth, Vector3(t.x, 0.42, t.y), root_node)
		mesh_at(cylinder(0.05, 0.05, 0.25, 8), mat("Candle", Color(1.0, 0.85, 0.5), 0.5, 0.0, 2.0), Vector3(t.x, 1.0, t.y), root_node)
		for k in 4:
			var a := TAU * k / 4 + 0.4
			solid_cyl(0.28, 0.55, wood, Vector3(t.x + cos(a) * 1.5, 0.27, t.y + sin(a) * 1.5), root_node)
	# Specials board and a dessert counter by the door
	mesh_at(box(Vector3(3.6, 1.8, 0.15)), mat("Chalkboard", Color(0.12, 0.18, 0.15), 0.9), Vector3(5.5, 2.6, -8.8), root_node, -0.5)
	label(root_node, "Today\nPasta  Soup\nPancakes", Vector3(5.6, 2.6, -8.6), 36, Color(1, 0.98, 0.9))
	solid_box(Vector3(2.4, 1.0, 1.0), wood, Vector3(-7.0, 0.5, 5.0), root_node, 0.6)
	for k in 4:
		mesh_at(sphere(0.2, 10), mat("Treat %d" % k, [Color(0.95, 0.55, 0.7), Color(0.98, 0.85, 0.45), Color(0.6, 0.4, 0.25), Color(0.75, 0.6, 0.95)][k], 0.6),
			Vector3(-7.6 + k * 0.4, 1.2, 5.0 + k * 0.25), root_node)
	light(root_node, Vector3(0, 6, 0), Color(1.0, 0.85, 0.6), 1.5, 18)
	light(root_node, Vector3(0, 3, -7.5), Color(1.0, 0.9, 0.7), 1.0, 8)
	label(root_node, "Restaurant & Cafe", Vector3(0, 5.8, -2), 80, Color(1, 0.95, 0.8))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# Nina's House: her bedroom, with the bed she sleeps in (scripts/bed.gd: sleep until morning and save), a desk with
# crayons and drawings, a bookshelf, a toy chest and a round rug
# -----------------------------------------------------------------------------
func _ninas_house() -> Node3D:
	var r := 9.0
	var root_node := dome_room("Nina's House", r, Color(0.98, 0.75, 0.8), Color(0.62, 0.44, 0.3), Color(1.0, 0.9, 0.85))
	var wood := mat("Nina Wood", Color(0.6, 0.38, 0.22), 0.6)
	var cream := mat("Nina Cream", Color(0.97, 0.94, 0.88), 0.7)
	var red := mat("Nina Red", Color(0.9, 0.12, 0.22), 0.7)              # the red of the bow in her hair
	# Round rug in the middle
	mesh_at(cylinder(2.6, 2.6, 0.04, 32), mat("Rug", Color(0.75, 0.55, 0.95), 0.9), Vector3(0, 0.02, 0), root_node)
	mesh_at(cylinder(1.6, 1.6, 0.05, 32), mat("Rug Middle", Color(0.98, 0.8, 0.45), 0.9), Vector3(0, 0.03, 0), root_node)
	# The bed, against the back wall on the left: frame, mattress, red blanket, pillow and headboard
	var bed := node("Bed", root_node, Vector3(-3.6, 0, -4.6), 0.35)
	var wake := Marker3D.new()                         # a new game starts here, just out of bed, facing the room
	wake.name = "BedSpawn"
	wake.position = Vector3(-1.6, 1.0, -2.6)
	wake.rotation.y = atan2(1.6, 2.6) - PI             # she faces the marker's -Z: toward the middle of the room
	root_node.add_child(wake)
	solid_box(Vector3(2.2, 0.5, 3.2), wood, Vector3(0, 0.25, 0), bed)
	mesh_at(box(Vector3(2.0, 0.3, 3.0)), cream, Vector3(0, 0.65, 0), bed)
	mesh_at(box(Vector3(2.08, 0.14, 2.0)), red, Vector3(0, 0.84, 0.5), bed)
	mesh_at(box(Vector3(1.3, 0.22, 0.6)), mat("Pillow", Color(1, 1, 1), 0.8), Vector3(0, 0.92, -1.05), bed)
	solid_box(Vector3(2.2, 1.5, 0.2), wood, Vector3(0, 0.75, -1.6), bed)
	for k in 2:                                       # a little bow on the headboard
		mesh_at(sphere(0.2, 10), red, Vector3(-0.22 + k * 0.44, 1.6, -1.55), bed)
	var sleep_area := Area3D.new()
	sleep_area.name = "SleepSpot"
	sleep_area.set_script(load("res://scripts/bed.gd"))
	var scs := CollisionShape3D.new()
	var sshape := SphereShape3D.new()
	sshape.radius = 2.4
	scs.shape = sshape
	scs.position = Vector3(0, 1.0, 0.6)
	sleep_area.add_child(scs)
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = "Press F to sleep"
	prompt.font_size = 44
	prompt.pixel_size = 0.01
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0.15, 0.1, 0.12)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.position = Vector3(0, 2.3, 0)
	sleep_area.add_child(prompt)
	bed.add_child(sleep_area)
	# Nightstand with a little lamp
	solid_box(Vector3(0.8, 0.7, 0.7), wood, Vector3(-1.7, 0.35, -5.6), root_node, 0.35)
	mesh_at(cylinder(0.1, 0.25, 0.5, 12), mat("Lamp Shade", Color(1.0, 0.85, 0.55), 0.6, 0.0, 1.2), Vector3(-1.7, 0.95, -5.6), root_node)
	light(root_node, Vector3(-1.7, 1.4, -5.4), Color(1.0, 0.8, 0.55), 0.8, 5)
	# Desk and chair on the right, with paper and crayons (she likes to draw)
	solid_box(Vector3(2.2, 0.08, 1.0), wood, Vector3(4.3, 0.85, -4.2), root_node, -0.45)
	for c in [Vector2(-0.95, -0.4), Vector2(0.95, -0.4), Vector2(-0.95, 0.4), Vector2(0.95, 0.4)]:
		var leg := Vector3(c.x, 0, c.y).rotated(Vector3.UP, -0.45)
		mesh_at(box(Vector3(0.08, 0.85, 0.08)), wood, Vector3(4.3, 0.42, -4.2) + leg, root_node, -0.45)
	mesh_at(box(Vector3(0.6, 0.01, 0.45)), cream, Vector3(4.1, 0.9, -4.1), root_node, -0.3)
	var crayons := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(0.4, 0.85, 0.4), Color(1.0, 0.85, 0.3)]
	for k in 4:
		mesh_at(cylinder(0.025, 0.025, 0.25, 6), mat("Crayon %d" % k, crayons[k], 0.6), Vector3(4.7 + k * 0.08, 0.92, -4.4), root_node, 0.0)
	solid_box(Vector3(0.6, 0.5, 0.6), mat("Chair", Color(0.55, 0.75, 0.95), 0.6), Vector3(3.6, 0.25, -3.2), root_node, -0.45)
	# Bookshelf by the wall, and a toy chest
	var shelf := node("Bookshelf", root_node, Vector3(6.3, 0, 1.2), -PI / 2 + 0.2)
	solid_box(Vector3(2.0, 2.2, 0.5), wood, Vector3(0, 1.1, 0), shelf)
	var spines := [Color(0.9, 0.4, 0.5), Color(0.4, 0.6, 0.95), Color(0.95, 0.8, 0.35), Color(0.5, 0.85, 0.6), Color(0.75, 0.5, 0.95)]
	for row in 3:
		for k in 6:
			mesh_at(box(Vector3(0.2, 0.5, 0.35)), mat("Book %d" % ((row + k) % 5), spines[(row + k) % 5], 0.7),
				Vector3(-0.75 + k * 0.3, 0.4 + row * 0.7, 0.1), shelf)
	solid_box(Vector3(1.4, 0.8, 0.8), mat("Toy Chest", Color(0.95, 0.6, 0.3), 0.6), Vector3(-6.0, 0.4, 1.5), root_node, PI / 2 - 0.2)
	mesh_at(sphere(0.35, 12), mat("Toy Ball", Color(0.3, 0.75, 1.0), 0.5), Vector3(-5.2, 0.35, 3.0), root_node)
	light(root_node, Vector3(0, 5, 0), Color(1.0, 0.88, 0.75), 1.2, 14)
	label(root_node, "Nina's House", Vector3(0, 3.6, -7.5), 56, Color(1, 0.92, 0.95))
	own(root_node)
	return root_node


func fish(parent: Node, color: Color, size: float) -> void:
	var body := mesh_at(sphere(size, 10), mat("Fish " + str(color), color, 0.4, 0.0, 0.4), Vector3.ZERO, parent)
	body.scale = Vector3(0.6, 0.8, 1.4)
	var tail := PrismMesh.new()
	tail.size = Vector3(size * 1.2, size * 1.2, size * 0.3)
	var t := mesh_at(tail, mat("Fish " + str(color), color), Vector3(0, 0, size * 1.6), body)
	t.rotation = Vector3(PI / 2, 0, 0)
