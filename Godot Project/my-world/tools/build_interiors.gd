extends SceneTree

# Builds walkable interiors for town buildings, each a round domed room matching its building:
#   res://scenes/interiors/cafe.tscn, aquarium.tscn, restaurant_and_cafe.tscn, ninas_house.tscn,
#   clothing_boutique.tscn, my_house.tscn, observatory.tscn, town_hall.tscn
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_interiors.gd [-- observatory ...]
#
# Name some after "--" to build only those (rebuilding re-rolls every node's unique_id, so the others stay as they are).
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
	var only := OS.get_cmdline_user_args()
	var all := {"cafe": _cafe, "aquarium": _aquarium, "restaurant_and_cafe": _restaurant, "ninas_house": _ninas_house,
		"clothing_boutique": _clothing_boutique, "my_house": _my_house, "observatory": _observatory,
		"town_hall": _town_hall, "museum": _museum, "library": _library, "potion_shop": _potion_shop,
		"book_store": _book_store, "pet_shop": _pet_shop, "gaming_station": _gaming_station, "dashs_house": _dashs_house,
		"melanies_house": _melanies_house, "empty_home_2": _empty_home_2, "haunted_house": _haunted_house,
		"toy_store": _toy_store}
	for file in all:
		if only.is_empty() or file in only:
			_save(file, (all[file] as Callable).call())
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
	# Her wardrobe, by the bookshelf: change clothes there (scripts/shop.gd, the "Wardrobe")
	wardrobe(root_node, Vector3(5.2, 0, 4.0), -PI / 2 - 0.5)
	light(root_node, Vector3(0, 5, 0), Color(1.0, 0.88, 0.75), 1.2, 14)
	label(root_node, "Nina's House", Vector3(0, 3.6, -7.5), 56, Color(1, 0.92, 0.95))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# The Clothing Boutique in the Market: rails of clothes, mannequins wearing outfits, a counter to buy at (the
# "Boutique" stall, scripts/shop.gd) and a big mirror to change at (the wardrobe)
# -----------------------------------------------------------------------------
func _clothing_boutique() -> Node3D:
	var r := 9.0
	var root_node := dome_room("Clothing Boutique", r, Color(0.98, 0.78, 0.2), Color(0.85, 0.75, 0.9), Color(1.0, 0.92, 0.95))
	var wood := mat("Boutique Wood", Color(0.75, 0.55, 0.4), 0.6)
	var metal := mat("Rail Metal", Color(0.85, 0.85, 0.9), 0.3, 0.8)
	mesh_at(cylinder(3.0, 3.0, 0.04, 32), mat("Boutique Rug", Color(1.0, 0.75, 0.85), 0.9), Vector3(0, 0.02, 0), root_node)
	# The counter at the back, with the shop on it
	var counter := node("Counter", root_node, Vector3(0, 0, -5.4))
	solid_box(Vector3(3.6, 1.0, 1.0), wood, Vector3(0, 0.5, 0), counter)
	mesh_at(box(Vector3(3.8, 0.08, 1.15)), mat("Counter Top", Color(1.0, 0.95, 0.85), 0.4), Vector3(0, 1.04, 0), counter)
	var till := Area3D.new()
	till.name = "BoutiqueCounter"
	till.set_script(load("res://scripts/shop_stall.gd"))
	till.set("stall", "Boutique")
	till.set("radius", 2.6)
	till.position = Vector3(0, 0, 1.2)
	counter.add_child(till)
	label(root_node, "Clothing Boutique", Vector3(0, 3.6, -7.5), 56, Color(1, 0.95, 0.8))
	# Rails of clothes on both sides: hangers with tops in every colour
	var colors := [Color(0.95, 0.4, 0.55), Color(0.45, 0.6, 1.0), Color(1.0, 0.85, 0.3), Color(0.55, 0.95, 0.8),
		Color(0.75, 0.55, 1.0), Color(1.0, 0.6, 0.35)]
	for side in [-1, 1]:
		var rail := node("Clothes Rail %s" % ("East" if side > 0 else "West"), root_node, Vector3(side * 5.2, 0, -1.0), side * PI / 2)
		for x in [-1.3, 1.3]:
			mesh_at(cylinder(0.04, 0.04, 1.8, 8), metal, Vector3(x, 0.9, 0), rail)
		var bar := mesh_at(cylinder(0.03, 0.03, 2.7, 8), metal, Vector3(0, 1.75, 0), rail)
		bar.rotation.z = PI / 2
		for k in 7:
			var shirt := mesh_at(box(Vector3(0.08, 0.7, 0.5)), mat("Rack Shirt %d" % (k % 6), colors[k % 6], 0.8),
				Vector3(-1.1 + k * 0.37, 1.35, 0), rail)
			shirt.rotation.y = PI / 2
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.8, 1.8, 0.6)
		solid(shape, null, null, Vector3(0, 0.9, 0), rail)
	# Mannequins near the door, showing outfits: round bodies, a hat, a scarf
	for m in [[Vector3(-3.2, 0, 3.2), Color(0.45, 0.6, 1.0), Color(0.95, 0.35, 0.45)], [Vector3(3.2, 0, 3.2), Color(0.75, 0.55, 1.0), Color(0.3, 0.75, 0.7)]]:
		var man := node("Mannequin", root_node, m[0], PI)
		solid_cyl(0.35, 0.1, mat("Mannequin Base", Color(0.9, 0.9, 0.95), 0.4), Vector3(0, 0.05, 0), man)
		mesh_at(cylinder(0.03, 0.03, 0.6, 8), metal, Vector3(0, 0.4, 0), man)
		mesh_at(sphere(0.3, 16), mat("Mannequin Top %s" % m[1].to_html(), m[1], 0.8), Vector3(0, 0.95, 0), man).scale = Vector3(1, 1.2, 0.8)
		mesh_at(sphere(0.2, 16), mat("Mannequin Head", Color(0.95, 0.92, 0.9), 0.5), Vector3(0, 1.5, 0), man)
		mesh_at(cylinder(0.16, 0.22, 0.12, 16), mat("Mannequin Scarf %s" % m[2].to_html(), m[2], 0.9), Vector3(0, 1.28, 0), man)
	# The big mirror: change into anything she owns
	wardrobe(root_node, Vector3(-4.4, 0, -4.6), PI / 4, true)
	light(root_node, Vector3(0, 5, 0), Color(1.0, 0.9, 0.85), 1.3, 14)
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# My House: the player's own home (a new game starts here, in bed), decorated their way (scripts/home_decor.gd):
# walls, floor, rug and blanket colours, and what stands in six spots round the room, changed at the Decorate spot
# (the paint pots by the door). Every choice of furniture is built in each spot and the chosen one shown.
# -----------------------------------------------------------------------------
const DECOR_SPOTS := {"spot1": [Vector3(-1.2, 0, -6.4), 0.2], "spot2": [Vector3(2.2, 0, -7.2), 0.0],
	"spot3": [Vector3(7.0, 0, -1.0), -PI / 2], "spot4": [Vector3(-7.0, 0, 0.6), PI / 2],
	"spot5": [Vector3(-4.6, 0, 5.6), PI * 0.8], "spot6": [Vector3(4.6, 0, 5.6), -PI * 0.8]}
const DECOR_ITEMS := ["none", "plant", "bookshelf", "toy_chest", "lamp", "fish_tank", "beanbag", "drum_kit", "easel",
	"telescope", "arcade", "trophy_shelf"]


func _my_house() -> Node3D:
	var r := 9.0
	var root_node := dome_room("My House", r, Color(1.0, 0.88, 0.75), Color(0.62, 0.44, 0.3), Color(1.0, 0.92, 0.85))
	root_node.set_script(load("res://scripts/home_decor.gd"))
	# The parts that take the player's colours: named "Decor <part>" (scripts/home_decor.gd)
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override
		if m and m.resource_name in ["Wall My House", "Dome My House"]:
			(mi as MeshInstance3D).material_override = _decor_mat("walls", Color(1.0, 0.85, 0.9))
		elif m and m.resource_name == "Floor My House":
			(mi as MeshInstance3D).material_override = _decor_mat("floor", Color(0.62, 0.44, 0.3))
	var wood := mat("Home Wood", Color(0.6, 0.38, 0.22), 0.6)
	mesh_at(cylinder(2.8, 2.8, 0.04, 32), _decor_mat("rug", Color(0.75, 0.55, 0.95)), Vector3(0, 0.02, 0), root_node)
	var stage := Marker3D.new()                        # where the character creator stands them, on the rug
	stage.name = "CreatorSpot"
	stage.position = Vector3(0, 1.0, 0.5)
	root_node.add_child(stage)
	# The bed, back left: sleep here (scripts/bed.gd); a new game starts just out of it
	var bed := node("Bed", root_node, Vector3(-3.8, 0, -4.4), 0.35)
	var wake := Marker3D.new()
	wake.name = "BedSpawn"
	wake.position = Vector3(-1.8, 1.0, -2.4)
	wake.rotation.y = atan2(1.8, 2.4) - PI
	root_node.add_child(wake)
	solid_box(Vector3(2.2, 0.5, 3.2), wood, Vector3(0, 0.25, 0), bed)
	mesh_at(box(Vector3(2.0, 0.3, 3.0)), mat("Home Mattress", Color(0.97, 0.94, 0.88), 0.7), Vector3(0, 0.65, 0), bed)
	mesh_at(box(Vector3(2.08, 0.14, 2.0)), _decor_mat("blanket", Color(0.9, 0.12, 0.22)), Vector3(0, 0.84, 0.5), bed)
	mesh_at(box(Vector3(1.3, 0.22, 0.6)), mat("Pillow", Color(1, 1, 1), 0.8), Vector3(0, 0.92, -1.05), bed)
	solid_box(Vector3(2.2, 1.5, 0.2), wood, Vector3(0, 0.75, -1.6), bed)
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
	# Their wardrobe, and the Decorate spot: paint pots and a brush by the door
	wardrobe(root_node, Vector3(5.4, 0, -4.4), -PI / 4)
	var paint := node("Decorate", root_node, Vector3(1.8, 0, 4.6), PI)
	var pots := [Color(1.0, 0.5, 0.7), Color(0.4, 0.75, 1.0), Color(1.0, 0.85, 0.3)]
	for k in 3:
		mesh_at(cylinder(0.22, 0.2, 0.36, 16), mat("Paint Pot %d" % k, pots[k], 0.5), Vector3(-0.5 + k * 0.5, 0.18, 0), paint)
		mesh_at(cylinder(0.2, 0.2, 0.02, 16), mat("Paint %d" % k, pots[k].lightened(0.2), 0.3), Vector3(-0.5 + k * 0.5, 0.37, 0), paint)
	mesh_at(box(Vector3(0.06, 0.6, 0.06)), wood, Vector3(0.3, 0.6, 0.15), paint).rotation.z = 0.5
	var spot := Area3D.new()
	spot.name = "DecorateSpot"
	spot.set_script(load("res://scripts/shop_stall.gd"))
	spot.set("stall", "Decorate")
	paint.add_child(spot)
	label(root_node, "Decorate", Vector3(1.8, 1.4, 4.6), 32, Color(1, 0.95, 0.8))
	# The six spots, each with every piece of furniture built and hidden but one
	var decor := node("Decor", root_node)
	for id in DECOR_SPOTS:
		var holder := node(id, decor, DECOR_SPOTS[id][0], DECOR_SPOTS[id][1])
		for item in DECOR_ITEMS:
			decor_item(item, node("Item " + item, holder))
	light(root_node, Vector3(0, 5, 0), Color(1.0, 0.88, 0.75), 1.2, 14)
	label(root_node, "My House", Vector3(0, 3.6, -7.5), 56, Color(1, 0.92, 0.95))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# Observatory: the Seer's home (scripts/seer.gd) and where the Council meets. A night-sky dome full of slowly turning
# stars, the big brass telescope up on its platform, the Council's round table with its glowing orb, and her own
# corner: armchair, tea, star books and star charts.
# -----------------------------------------------------------------------------
const SEER_AT := Vector3(3.2, 0, -1.2)                  # where she stands, by the telescope, facing the door


func _observatory() -> Node3D:
	var r := 11.0
	var root_node := dome_room("Observatory", r, Color(0.16, 0.14, 0.34), Color(0.36, 0.26, 0.2), Color(0.75, 0.7, 0.95))
	# The dome is the night sky: the Seer's star cloth (scripts/star_shawl.gdshader), bigger and slower
	var sky := ShaderMaterial.new()
	sky.shader = load("res://scripts/star_shawl.gdshader")
	sky.set_shader_parameter("density", 70.0)
	sky.set_shader_parameter("drift", 0.0015)
	sky.set_shader_parameter("dusk", Color(0.12, 0.1, 0.3))
	sky.set_shader_parameter("deep", Color(0.04, 0.03, 0.14))
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override
		if m and m.resource_name == "Dome Observatory":
			(mi as MeshInstance3D).material_override = sky
	var brass := mat("Brass", Color(0.8, 0.6, 0.28), 0.35, 0.8)
	var wood := mat("Observatory Wood", Color(0.45, 0.28, 0.16), 0.6)
	var plum := mat("Plum Velvet", Color(0.42, 0.2, 0.45), 0.9)
	var gold_glow := mat("Star Gold", Color(1.0, 0.8, 0.4), 0.4, 0.0, 0.6)
	# A round rug of stars in the middle
	mesh_at(cylinder(4.2, 4.2, 0.03, 40), mat("Star Rug", Color(0.2, 0.16, 0.4), 0.9), Vector3(0, 0.015, 1.0), root_node)
	for k in 12:
		var a := TAU * k / 12.0
		mesh_at(sphere(0.06, 8), gold_glow, Vector3(cos(a) * 3.6, 0.0, 1.0 + sin(a) * 3.6), root_node)

	# The telescope, at the back (north) on a round platform with steps, aimed up at a slot in the dome
	var scope := node("Telescope", root_node, Vector3(0, 0, -6.2))
	solid_cyl(2.6, 0.5, wood, Vector3(0, 0.25, 0), scope)
	solid_cyl(1.6, 0.5, wood, Vector3(0, 0.75, -0.3), scope)
	mesh_at(cylinder(0.35, 0.5, 1.6, 16), brass, Vector3(0, 1.8, -0.3), scope)
	var tube := mesh_at(cylinder(0.55, 0.7, 5.4, 20), mat("Telescope Tube", Color(0.25, 0.25, 0.4), 0.4, 0.6), Vector3(0, 3.8, -1.4), scope)
	tube.rotation.x = -0.75
	for k in 3:
		var band := mesh_at(cylinder(0.72 - k * 0.04, 0.72 - k * 0.04, 0.16, 20), brass, Vector3(0, 2.9 + k * 0.9, -0.55 - k * 0.85), scope)
		band.rotation.x = -0.75
	var lens := mesh_at(cylinder(0.56, 0.56, 0.06, 20), mat("Telescope Lens", Color(0.6, 0.85, 1.0), 0.05, 0.0, 1.5), Vector3(0, 5.75, -3.25), scope)
	lens.rotation.x = -0.75
	mesh_at(box(Vector3(2.2, 7.0, 0.3)), mat("Dome Slot", Color(0.02, 0.02, 0.06), 0.9), Vector3(0, 6.6, -8.2), root_node).rotation.x = 0.7
	label(root_node, "Telescope", Vector3(0, 2.4, -3.9), 36, Color(0.95, 0.9, 1.0))

	# The Council's round table, west: a glowing orb in the middle and six tall-backed chairs, one with her star cushion
	var council := node("Council Table", root_node, Vector3(-5.0, 0, 0.0))
	solid_cyl(1.7, 0.12, mat("Council Table Top", Color(0.3, 0.2, 0.4), 0.4), Vector3(0, 0.95, 0), council)
	mesh_at(cylinder(1.72, 1.72, 0.04, 40), brass, Vector3(0, 1.02, 0), council)
	mesh_at(cylinder(0.25, 0.5, 0.9, 12), wood, Vector3(0, 0.45, 0), council)
	mesh_at(cylinder(0.2, 0.26, 0.12, 12), brass, Vector3(0, 1.08, 0), council)
	var orb := mesh_at(sphere(0.32, 20), mat("Council Orb", Color(0.7, 0.85, 1.0), 0.05, 0.0, 1.6, 0.75), Vector3(0, 1.45, 0), council)
	orb.name = "Council Orb"
	light(council, Vector3(0, 1.6, 0), Color(0.7, 0.8, 1.0), 0.9, 6.0)
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6
		var chair := node("Council Chair %d" % (k + 1), council, Vector3(cos(a) * 2.5, 0, sin(a) * 2.5), -a - PI / 2)
		solid_box(Vector3(0.8, 0.5, 0.8), plum, Vector3(0, 0.25, 0), chair)
		solid_box(Vector3(0.8, 1.9, 0.18), wood, Vector3(0, 0.95, -0.42), chair)
		mesh_at(sphere(0.1, 8), brass, Vector3(-0.32, 1.95, -0.42), chair)
		mesh_at(sphere(0.1, 8), brass, Vector3(0.32, 1.95, -0.42), chair)
		mesh_at(sphere(0.13, 8), gold_glow, Vector3(0, 1.75, -0.32), chair)     # a star on every chair back
		if k == 0:
			mesh_at(cylinder(0.33, 0.35, 0.12, 16), mat("Star Cushion", Color(0.2, 0.15, 0.45), 0.9), Vector3(0, 0.56, 0), chair)
	label(council, "The Council", Vector3(0, 3.0, 0), 56, Color(1.0, 0.9, 0.6))

	# Her corner, east: an armchair, a little table with a teapot and two cups, star books, and a footstool
	var corner := node("Seer's Corner", root_node, Vector3(6.0, 0, 1.5), -PI / 2)
	solid_box(Vector3(1.3, 0.55, 1.2), plum, Vector3(0, 0.28, 0), corner)
	solid_box(Vector3(1.3, 1.3, 0.3), plum, Vector3(0, 0.95, -0.5), corner)
	for s in [-1.0, 1.0]:
		solid_box(Vector3(0.25, 0.8, 1.2), plum, Vector3(s * 0.62, 0.55, 0), corner)
	mesh_at(box(Vector3(1.0, 0.04, 0.9)), mat("Knitted Throw", Color(0.95, 0.75, 0.4), 0.9), Vector3(0, 0.58, 0.05), corner)
	solid_cyl(0.45, 0.06, wood, Vector3(1.4, 0.7, 0.3), corner)
	mesh_at(cylinder(0.06, 0.1, 0.7, 8), wood, Vector3(1.4, 0.35, 0.3), corner)
	mesh_at(sphere(0.14, 12), mat("Teapot", Color(0.95, 0.9, 0.95), 0.3), Vector3(1.35, 0.85, 0.25), corner)
	mesh_at(cylinder(0.02, 0.03, 0.14, 6), mat("Teapot", Color()), Vector3(1.53, 0.86, 0.25), corner).rotation.z = -0.9
	for c in [Vector3(1.6, 0.77, 0.5), Vector3(1.2, 0.77, 0.55)]:
		mesh_at(cylinder(0.05, 0.04, 0.08, 10), mat("Teacup", Color(0.6, 0.75, 1.0), 0.3), c, corner)
	solid_box(Vector3(0.6, 0.35, 0.5), plum, Vector3(0, 0.18, 1.1), corner)        # footstool
	var shelf := node("Star Books", root_node, Vector3(8.6, 0, -4.8), -PI / 3)
	solid_box(Vector3(2.4, 2.6, 0.5), wood, Vector3(0, 1.3, 0), shelf)
	var spines := [Color(0.3, 0.3, 0.7), Color(0.6, 0.3, 0.6), Color(0.85, 0.7, 0.35), Color(0.3, 0.55, 0.6)]
	for row in 3:
		for k in 8:
			mesh_at(box(Vector3(0.22, 0.55, 0.36)), mat("Star Book %d" % ((k + row) % 4), spines[(k + row) % 4], 0.7),
				Vector3(-0.95 + k * 0.27, 0.45 + row * 0.8, 0.12), shelf)
	# Star charts on the wall: dots joined by gold lines, made-up constellations (the Owl, the Teapot, the Lantern)
	var charts := [["The Owl", [Vector2(0, 0.5), Vector2(-0.35, 0.2), Vector2(0.35, 0.2), Vector2(-0.25, -0.35), Vector2(0.25, -0.35), Vector2(0, 0.15)]],
		["The Teapot", [Vector2(-0.5, -0.2), Vector2(-0.2, 0.25), Vector2(0.25, 0.25), Vector2(0.5, 0.05), Vector2(0.3, -0.3), Vector2(-0.3, -0.3)]],
		["The Lantern", [Vector2(0, 0.55), Vector2(-0.3, 0.2), Vector2(0.3, 0.2), Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0, -0.5)]]]
	for k in charts.size():
		var a := PI + 0.55 + k * 0.42                    # round the north-west wall
		var at := Vector3(cos(a) * (r - 0.35), 2.2, sin(a) * (r - 0.35))
		var board := node("Star Chart " + str(charts[k][0]), root_node, at, -a - PI / 2)
		mesh_at(box(Vector3(1.7, 1.5, 0.05)), mat("Chart Paper", Color(0.1, 0.1, 0.25), 0.9), Vector3.ZERO, board)
		var pts: Array = charts[k][1]
		for p in pts:
			mesh_at(sphere(0.05, 8), gold_glow, Vector3(p.x, p.y, 0.05), board)
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var seg := mesh_at(box(Vector3(p0.distance_to(p1), 0.015, 0.01)), gold_glow, Vector3((p0.x + p1.x) / 2, (p0.y + p1.y) / 2, 0.04), board)
			seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
		label(board, str(charts[k][0]), Vector3(0, -0.95, 0.05), 28, Color(1.0, 0.92, 0.7))
	# Lamps low and warm, so the stars still show
	light(root_node, Vector3(0, 6.5, 0), Color(0.75, 0.7, 1.0), 0.7, 16)
	light(root_node, Vector3(6, 2.5, 1.5), Color(1.0, 0.8, 0.55), 0.9, 7)
	light(root_node, Vector3(0, 3.0, 5.0), Color(1.0, 0.85, 0.65), 0.6, 8)
	label(root_node, "Observatory", Vector3(0, 4.8, 3.5), 72, Color(0.95, 0.9, 1.0))
	# The Seer herself (scripts/seer.gd makes her look), with her talk spot (dialogue/seer.json)
	var seer := Node3D.new()
	seer.name = "The Seer"
	seer.set_script(load("res://scripts/seer.gd"))
	seer.position = SEER_AT
	seer.rotation.y = atan2(-SEER_AT.x, r - 4.5 - SEER_AT.z)
	root_node.add_child(seer)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", "seer")
	talk.set("display_name", "The Seer")
	talk.set("name_height", 2.15)
	seer.add_child(talk)
	own(root_node)
	return root_node


func _decor_mat(part: String, color: Color) -> StandardMaterial3D:
	# A material scripts/home_decor.gd recolours (its name says which part); not run through the palette, so the
	# colours picked are the colours seen
	if mats.has("Decor " + part):
		return mats["Decor " + part]
	var m := StandardMaterial3D.new()
	m.resource_name = "Decor " + part
	m.albedo_color = color
	m.roughness = 0.8
	mats["Decor " + part] = m
	return m


func decor_item(id: String, g: Node3D) -> void:
	# A piece of furniture for a decorating spot, standing at the spot's middle and facing into the room (+Z)
	var wood := mat("Home Wood", Color(0.6, 0.38, 0.22), 0.6)
	match id:
		"plant":
			solid_cyl(0.32, 0.6, mat("Plant Pot", Color(0.85, 0.5, 0.35), 0.6), Vector3(0, 0.3, 0), g)
			for k in 5:
				var leaf := mesh_at(sphere(0.32, 10), mat("Plant Leaf", Color(0.35, 0.8, 0.45), 0.7),
					Vector3(cos(k * 1.3) * 0.25, 0.95 + k * 0.12, sin(k * 1.3) * 0.25), g)
				leaf.scale = Vector3(1.0, 0.5, 1.0)
		"bookshelf":
			solid_box(Vector3(1.8, 2.0, 0.45), wood, Vector3(0, 1.0, 0), g)
			var spines := [Color(0.9, 0.4, 0.5), Color(0.4, 0.6, 0.95), Color(0.95, 0.8, 0.35), Color(0.5, 0.85, 0.6)]
			for row in 3:
				for k in 5:
					mesh_at(box(Vector3(0.22, 0.45, 0.3)), mat("Book %d" % ((row + k) % 4), spines[(row + k) % 4], 0.7),
						Vector3(-0.65 + k * 0.32, 0.4 + row * 0.6, 0.12), g)
		"toy_chest":
			solid_box(Vector3(1.3, 0.75, 0.75), mat("Toy Chest", Color(0.95, 0.6, 0.3), 0.6), Vector3(0, 0.37, 0), g)
			mesh_at(sphere(0.3, 12), mat("Toy Ball", Color(0.3, 0.75, 1.0), 0.5), Vector3(0.9, 0.3, 0.4), g)
		"lamp":
			solid_cyl(0.3, 0.6, mat("Nightstand", Color(0.6, 0.38, 0.22), 0.6), Vector3(0, 0.3, 0), g)
			mesh_at(cylinder(0.12, 0.18, 0.5, 12), mat("Lava Lamp", Color(1.0, 0.45, 0.8), 0.3, 0.0, 1.5), Vector3(0, 0.85, 0), g)
			light(g, Vector3(0, 1.2, 0.2), Color(1.0, 0.6, 0.85), 0.6, 4)
		"fish_tank":
			solid_box(Vector3(1.4, 0.7, 0.6), mat("Tank Stand", Color(0.35, 0.3, 0.45), 0.6), Vector3(0, 0.35, 0), g)
			mesh_at(box(Vector3(1.3, 0.7, 0.55)), mat("Tank Water", Color(0.5, 0.85, 1.0), 0.1, 0.0, 0.4, 0.5), Vector3(0, 1.05, 0), g)
			var fish_cols := [Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.3), Color(0.9, 0.4, 0.8)]
			for k in 3:
				mesh_at(sphere(0.07, 8), mat("Tank Fish %d" % k, fish_cols[k], 0.4), Vector3(-0.4 + k * 0.4, 0.95 + k * 0.08, 0), g)
		"beanbag":
			var bag := mesh_at(sphere(0.6, 16), mat("Beanbag", Color(0.6, 0.4, 0.95), 0.9), Vector3(0, 0.35, 0), g)
			bag.scale = Vector3(1.1, 0.6, 1.1)
			var shape := SphereShape3D.new()
			shape.radius = 0.55
			solid(shape, null, null, Vector3(0, 0.3, 0), g)
		"drum_kit":
			var drum := mat("Drum", Color(0.95, 0.3, 0.4), 0.4)
			solid_cyl(0.4, 0.5, drum, Vector3(0, 0.35, 0), g)
			solid_cyl(0.22, 0.25, drum, Vector3(-0.6, 0.6, 0.2), g)
			solid_cyl(0.22, 0.25, drum, Vector3(0.6, 0.6, 0.2), g)
			mesh_at(cylinder(0.3, 0.3, 0.02, 16), mat("Cymbal", Color(1.0, 0.85, 0.35), 0.2, 0.9), Vector3(0.9, 1.1, -0.1), g)
		"easel":
			for x in [-0.35, 0.35]:
				mesh_at(box(Vector3(0.06, 1.6, 0.06)), wood, Vector3(x, 0.8, 0), g)
			mesh_at(box(Vector3(0.9, 0.7, 0.04)), mat("Canvas", Color(1, 1, 1), 0.8), Vector3(0, 1.2, 0.05), g)
			mesh_at(sphere(0.12, 10), mat("Canvas Sun", Color(1.0, 0.8, 0.2), 0.6), Vector3(0.15, 1.3, 0.08), g)
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.9, 1.6, 0.4)
			solid(shape, null, null, Vector3(0, 0.8, 0), g)
		"telescope":
			for k in 3:
				var leg := mesh_at(cylinder(0.03, 0.03, 1.1, 6), mat("Tripod", Color(0.3, 0.3, 0.35), 0.4, 0.6),
					Vector3(cos(k * TAU / 3) * 0.2, 0.5, sin(k * TAU / 3) * 0.2), g)
				leg.rotation = Vector3(sin(k * TAU / 3) * 0.3, 0, -cos(k * TAU / 3) * 0.3)
			var tube := mesh_at(cylinder(0.1, 0.13, 1.0, 12), mat("Telescope", Color(0.4, 0.5, 0.95), 0.4, 0.4), Vector3(0, 1.15, 0.1), g)
			tube.rotation.x = -1.0
			var shape := CylinderShape3D.new()
			shape.radius = 0.35
			shape.height = 1.2
			solid(shape, null, null, Vector3(0, 0.6, 0), g)
		"arcade":
			solid_box(Vector3(0.9, 1.8, 0.8), mat("Arcade", Color(0.3, 0.2, 0.55), 0.5), Vector3(0, 0.9, 0), g)
			mesh_at(box(Vector3(0.7, 0.5, 0.02)), mat("Arcade Screen", Color(0.4, 1.0, 0.7), 0.2, 0.0, 1.5), Vector3(0, 1.3, 0.41), g)
			mesh_at(sphere(0.05, 8), mat("Arcade Button", Color(1.0, 0.3, 0.4), 0.3), Vector3(0.15, 0.95, 0.42), g)
		"trophy_shelf":
			solid_box(Vector3(1.6, 0.9, 0.45), wood, Vector3(0, 0.45, 0), g)
			var gold := mat("Trophy", Color(1.0, 0.82, 0.3), 0.2, 0.9)
			for k in 3:
				mesh_at(cylinder(0.12, 0.06, 0.3, 10), gold, Vector3(-0.5 + k * 0.5, 1.1, 0), g)
				mesh_at(sphere(0.1, 8), gold, Vector3(-0.5 + k * 0.5, 1.3, 0), g)


func wardrobe(parent: Node3D, pos: Vector3, yaw: float, mirror_only := false) -> void:
	# A wardrobe (or, in the shop, a tall mirror): walk up and press Interact to change clothes. It's the "Wardrobe"
	# stall in scripts/shop.gd, which lists her clothing slots with arrows to swap what she's wearing.
	var w := node("Wardrobe", parent, pos, yaw)
	var frame := mat("Wardrobe Wood", Color(0.85, 0.6, 0.75), 0.6)
	var glass := mat("Mirror", Color(0.85, 0.95, 1.0), 0.05, 0.2, 0.35)        # a soft shine, so it reads as a mirror
	if mirror_only:
		solid_box(Vector3(1.4, 2.4, 0.15), frame, Vector3(0, 1.2, 0), w)
		mesh_at(box(Vector3(1.15, 2.1, 0.02)), glass, Vector3(0, 1.2, 0.085), w)
	else:
		solid_box(Vector3(1.8, 2.4, 0.8), frame, Vector3(0, 1.2, 0), w)
		for s in [-1, 1]:
			mesh_at(box(Vector3(0.82, 2.1, 0.02)), frame, Vector3(s * 0.43, 1.2, 0.41), w)
			mesh_at(sphere(0.05, 8), mat("Wardrobe Knob", Color(1.0, 0.85, 0.3), 0.3, 0.6), Vector3(s * 0.1, 1.2, 0.45), w)
		mesh_at(box(Vector3(0.5, 1.2, 0.02)), glass, Vector3(-0.43, 1.25, 0.425), w)
	var spot := Area3D.new()
	spot.name = "WardrobeSpot"
	spot.set_script(load("res://scripts/shop_stall.gd"))
	spot.set("stall", "Wardrobe")
	spot.position = Vector3(0, 0, 1.0)
	w.add_child(spot)


func fish(parent: Node, color: Color, size: float) -> void:
	var body := mesh_at(sphere(size, 10), mat("Fish " + str(color), color, 0.4, 0.0, 0.4), Vector3.ZERO, parent)
	body.scale = Vector3(0.6, 0.8, 1.4)
	var tail := PrismMesh.new()
	tail.size = Vector3(size * 1.2, size * 1.2, size * 0.3)
	var t := mesh_at(tail, mat("Fish " + str(color), color), Vector3(0, 0, size * 1.6), body)
	t.rotation = Vector3(PI / 2, 0, 0)


# -----------------------------------------------------------------------------
# Town Hall: Mr. Palmer's office and the council room (16 Nov 2026, "insides for all the buildings"). The show's pilot
# has the town map on his office wall, so the real map hangs there (ui/town_map.png). His big desk on a dais at the
# back (a baked prop, tools/build_prop_furniture.py mayor_desk), a gold clock with a swinging pendulum (the clock
# tower's insides), the council's benches in an arc, banners, the window seat by the window he talks from, plants.
# -----------------------------------------------------------------------------
const DESK := "res://models/props/furniture/mayor_desk.glb"


func _town_hall() -> Node3D:
	var r := 10.0
	var root_node := dome_room("Town Hall", r, Color(0.95, 0.93, 0.88), Color(0.5, 0.36, 0.62), Color(1.0, 0.94, 0.86))
	var gold := mat("Hall Gold", Color(0.98, 0.78, 0.3), 0.3, 0.9)
	var lilac := mat("Hall Lilac", Color(0.68, 0.55, 0.85), 0.6)
	var carpet := mat("Hall Carpet", Color(0.75, 0.2, 0.45), 0.9)
	var stone := mat("Hall Stone", Color(0.92, 0.9, 0.85), 0.7)
	# A carpet runner from the door to the dais, and the dais at the back
	mesh_at(box(Vector3(2.2, 0.03, 12.5)), carpet, Vector3(0, 0.02, 1.2), root_node)
	solid_box(Vector3(7.5, 0.4, 3.4), stone, Vector3(0, 0.2, -6.4), root_node)
	mesh_at(box(Vector3(7.3, 0.04, 3.2)), carpet, Vector3(0, 0.42, -6.4), root_node)
	solid_box(Vector3(1.6, 0.2, 0.6), stone, Vector3(0, 0.1, -4.45), root_node)          # a step up
	# Mr. Palmer's desk (baked), his tall chair and a nameplate
	var office := node("Office", root_node, Vector3(0, 0.4, -6.5))
	if ResourceLoader.exists(DESK):
		var desk := (load(DESK) as PackedScene).instantiate() as Node3D
		desk.name = "Mayor Desk"
		desk.scale = Vector3.ONE * 1.25                 # a mayor's desk: bigger than life
		office.add_child(desk)
	var desk_shape := BoxShape3D.new()
	desk_shape.size = Vector3(1.9, 0.8, 0.9) * 1.25
	solid(desk_shape, null, null, Vector3(0, 0.5, 0), office)
	var chair := node("Chair", office, Vector3(0, 0, -1.1))
	mesh_at(box(Vector3(0.8, 0.12, 0.7)), lilac, Vector3(0, 0.5, 0), chair)
	mesh_at(box(Vector3(0.8, 1.1, 0.12)), lilac, Vector3(0, 1.05, -0.3), chair)
	mesh_at(sphere(0.1, 12), gold, Vector3(-0.38, 1.62, -0.3), chair)
	mesh_at(sphere(0.1, 12), gold, Vector3(0.38, 1.62, -0.3), chair)
	label(office, "MAYOR PALMER", Vector3(0, 1.25, 0.6), 18, Color(0.3, 0.2, 0.05))
	# The town map on the wall behind him (pilot, part 1), in a gold frame
	var map_m := StandardMaterial3D.new()
	map_m.resource_name = "Town Map Picture"
	map_m.albedo_texture = load("res://ui/town_map.png")
	map_m.roughness = 0.8
	var quad := QuadMesh.new()
	quad.size = Vector2(4.2, 3.0)
	var map_node := mesh_at(quad, map_m, Vector3(0, 3.4, -r + 0.75), root_node)
	map_node.name = "Town Map"
	mesh_at(box(Vector3(4.5, 3.3, 0.08)), gold, Vector3(0, 3.4, -r + 0.68), root_node)
	label(root_node, "THE VOID", Vector3(0, 5.2, -r + 0.8), 40, Color(1, 0.92, 0.6))
	# The great clock on the right wall, its pendulum swinging (the clock tower's works)
	var clock := node("Hall Clock", root_node, Vector3(r - 1.3, 0, -3.2), -PI / 2 + 0.35)
	solid_box(Vector3(1.4, 3.6, 0.7), mat("Clock Case", Color(0.42, 0.28, 0.55), 0.6), Vector3(0, 1.8, 0), clock)
	mesh_at(cylinder(0.55, 0.55, 0.06, 32), mat("Clock Face", Color(1.0, 0.97, 0.85), 0.4, 0.0, 0.4), Vector3(0, 3.0, 0.37), clock).rotation.x = PI / 2
	mesh_at(cylinder(0.6, 0.6, 0.04, 32), gold, Vector3(0, 3.0, 0.35), clock).rotation.x = PI / 2
	mesh_at(box(Vector3(0.05, 0.42, 0.03)), mat("Clock Hand", Color(0.1, 0.1, 0.15)), Vector3(0, 3.15, 0.42), clock)
	mesh_at(box(Vector3(0.3, 0.05, 0.03)), mat("Clock Hand", Color(0.1, 0.1, 0.15)), Vector3(0.12, 3.0, 0.42), clock)
	var pend := node("Pendulum", clock, Vector3(0, 2.4, 0.36))
	pend.set_script(load("res://scripts/pendulum_swing.gd"))
	mesh_at(box(Vector3(0.04, 1.2, 0.03)), gold, Vector3(0, -0.6, 0), pend)
	mesh_at(cylinder(0.2, 0.2, 0.05, 24), gold, Vector3(0, -1.25, 0), pend).rotation.x = PI / 2
	mesh_at(box(Vector3(0.9, 1.7, 0.03)), mat("Clock Glass", Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.0, 0.25), Vector3(0, 1.45, 0.37), clock)
	# Council benches in an arc facing the dais
	var bench_m := mat("Council Bench", Color(0.55, 0.36, 0.68), 0.6)
	for row in 2:
		for k in 5:
			if k == 2:
				continue                                  # the aisle
			var a := PI / 2 + (k - 2) * 0.32
			var rad := 3.4 + row * 2.0
			var p := Vector3(cos(a) * rad, 0, sin(a) * rad - 1.6)
			var b := node("Council Bench", root_node, p, -a + PI / 2)
			solid_box(Vector3(2.0, 0.45, 0.55), bench_m, Vector3(0, 0.23, 0), b)
			mesh_at(box(Vector3(2.0, 0.6, 0.08)), bench_m, Vector3(0, 0.75, 0.25), b)
			mesh_at(box(Vector3(2.04, 0.05, 0.6)), gold, Vector3(0, 0.47, 0), b)
	# Banners with the town's crescent, flags beside the dais
	for sx in [-1.0, 1.0]:
		var bp := Vector3(sx * 3.6, 3.6, -r + 1.2)
		mesh_at(box(Vector3(1.0, 2.4, 0.04)), mat("Hall Banner", Color(0.4, 0.25, 0.7), 0.8), bp, root_node)
		mesh_at(box(Vector3(1.06, 0.08, 0.06)), gold, bp + Vector3(0, 1.22, 0), root_node)
		label(root_node, "☾", bp + Vector3(0, 0.3, 0.04), 110, Color(1, 0.85, 0.4))
		mesh_at(cylinder(0.04, 0.04, 3.0, 8), gold, Vector3(sx * 4.2, 1.9, -5.0), root_node)
		mesh_at(box(Vector3(0.9, 0.6, 0.02)), mat("Hall Flag", Color(0.95, 0.4, 0.6), 0.7), Vector3(sx * 4.2 + sx * 0.45, 3.0, -5.0), root_node)
	# The window seat by his window (the window he talks to people from, outside) and plants
	var seat := node("Window Seat", root_node, Vector3(-r + 1.4, 0, 2.6), PI / 2 - 0.5)
	solid_box(Vector3(2.4, 0.5, 0.8), lilac, Vector3(0, 0.25, 0), seat)
	mesh_at(box(Vector3(2.3, 0.14, 0.7)), carpet, Vector3(0, 0.57, 0), seat)
	for k in 2:
		mesh_at(sphere(0.22, 12), mat("Cushion %d" % k, [Color(1.0, 0.85, 0.35), Color(0.45, 0.85, 0.85)][k], 0.9),
			Vector3(-0.7 + k * 1.4, 0.78, -0.2), seat).scale = Vector3(1, 0.7, 0.6)
	for p in [Vector2(-5.5, -6.0), Vector2(5.5, -6.0), Vector2(-7.0, 5.5), Vector2(7.0, 5.5)]:
		solid_cyl(0.4, 0.7, mat("Hall Pot", Color(0.98, 0.78, 0.3), 0.4, 0.5), Vector3(p.x, 0.35, p.y), root_node)
		mesh_at(sphere(0.75, 14), mat("Hall Plant", Color(0.3, 0.75, 0.55), 0.9), Vector3(p.x, 1.35, p.y), root_node)
	# A gold chandelier
	var ch := node("Chandelier", root_node, Vector3(0, 6.6, -1.0))
	mesh_at(cylinder(0.02, 0.02, 1.4, 6), gold, Vector3(0, 0.7, 0), ch)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.1
	mesh_at(ring, gold, Vector3.ZERO, ch)
	for k in 8:
		var a := k * TAU / 8
		mesh_at(sphere(0.12, 10), mat("Chandelier Glow", Color(1.0, 0.9, 0.6), 0.3, 0.0, 2.5), Vector3(cos(a), 0.15, sin(a)) * 1.05, ch)
	light(root_node, Vector3(0, 6.0, -1.0), Color(1.0, 0.9, 0.7), 1.5, 16)
	light(root_node, Vector3(0, 3.0, -6.0), Color(1.0, 0.85, 0.6), 0.9, 8)
	label(root_node, "Town Hall", Vector3(0, 6.2, 3.0), 80, Color(1, 0.95, 0.8))
	own(root_node)
	return root_node


# -----------------------------------------------------------------------------
# The rest of the Void's rooms (16 Nov 2026; Hayden: "add insides to all the buildings"). Every dome door in town
# that used to say "isn't open yet" leads somewhere now. Bookcases and armchairs are the baked props
# (tools/build_prop_furniture.py), the rest is made from shapes in the alien palette.
# -----------------------------------------------------------------------------
const SHELF := "res://models/props/furniture/bookshelf.glb"
const ARMCHAIR := "res://models/props/furniture/armchair.glb"


func prop(file: String, parent: Node3D, pos: Vector3, yaw: float, size: Vector3, name := "") -> void:
	# A baked prop, and a box to bump into (size: its width, height and depth)
	if ResourceLoader.exists(file):
		var p := (load(file) as PackedScene).instantiate() as Node3D
		if name != "":
			p.name = name
		p.position = pos
		p.rotation.y = yaw
		parent.add_child(p)
	var shape := BoxShape3D.new()
	shape.size = size
	solid(shape, null, null, pos + Vector3(0, size.y / 2, 0), parent, yaw)


func facing_in(a: float, rr: float) -> Array:
	# A spot round the wall at angle a (0 east, PI/2 the door), and the turn that faces it into the middle
	return [Vector3(cos(a), 0, sin(a)) * rr, atan2(-cos(a), -sin(a))]


func spinner(name: String, parent: Node3D, pos: Vector3, speed: float) -> Node3D:
	var n := node(name, parent, pos)
	n.set_script(load("res://scripts/spin.gd"))
	n.set("speed", speed)
	return n


func plant(parent: Node3D, pos: Vector3, c := Color(0.3, 0.65, 0.3)) -> void:
	solid_cyl(0.45, 0.7, mat("Pot", Color(0.85, 0.5, 0.35), 0.8), pos + Vector3(0, 0.35, 0), parent)
	mesh_at(sphere(0.8, 12), mat("Plant", c, 0.9), pos + Vector3(0, 1.4, 0), parent)


func shelves_round(parent: Node3D, r: float, from_a: float, to_a: float, n: int) -> void:
	# Bookcases round the wall between two angles (the door's at PI/2)
	for k in n:
		var a := lerpf(from_a, to_a, (k + 0.5) / n)
		var at: Array = facing_in(a, r - 0.6)
		prop(SHELF, parent, at[0], at[1], Vector3(1.2, 2.0, 0.36), "Bookcase %d" % (k + 1))


func _museum() -> Node3D:
	# The Void's Museum: the skeleton of a long-necked star beast in the middle, cases of treasures round the wall
	# (a meteorite, a singing crystal, the first Shift Watch, a fossil fern), paintings and a rope to keep back from it
	var r := 13.0
	var root_node := dome_room("Museum", r, Color(0.92, 0.9, 0.86), Color(0.55, 0.45, 0.4), Color(1.0, 0.95, 0.88))
	var bone := mat("Bone", Color(0.95, 0.92, 0.82), 0.7)
	var stone := mat("Museum Stone", Color(0.85, 0.83, 0.8), 0.7)
	var gold := mat("Museum Gold", Color(0.98, 0.78, 0.3), 0.3, 0.9)
	# The star beast's skeleton on its plinth
	solid_box(Vector3(9.0, 0.5, 3.0), stone, Vector3(0, 0.25, -1.0), root_node)
	var beast := node("Star Beast", root_node, Vector3(0, 0.5, -1.0))
	for k in 9:                                        # the spine, rising into the neck
		var x := -3.6 + k * 0.7
		var y := 2.2 + maxf(0.0, x - 1.0) * 0.9
		mesh_at(sphere(0.22, 10), bone, Vector3(x, y, 0), beast)
		if k < 6:
			for sz in [-1.0, 1.0]:                          # ribs
				var rib := mesh_at(cylinder(0.05, 0.05, 1.4, 6), bone, Vector3(x, y - 0.6, sz * 0.45), beast)
				rib.rotation.x = sz * 0.5
	mesh_at(sphere(0.45, 12), bone, Vector3(3.0, 5.2, 0), beast)                   # the head
	for sx in [-0.15, 0.15]:
		mesh_at(sphere(0.08, 8), mat("Bone Eye", Color(0.2, 0.2, 0.25), 0.5), Vector3(3.3, 5.3, sx), beast)
	for leg in [Vector2(-2.6, -0.5), Vector2(-2.6, 0.5), Vector2(0.4, -0.5), Vector2(0.4, 0.5)]:
		mesh_at(cylinder(0.12, 0.1, 2.0, 8), bone, Vector3(leg.x, 1.0, leg.y), beast)
	var tail := mesh_at(cylinder(0.04, 0.16, 2.4, 8), bone, Vector3(-4.6, 1.8, 0), beast)
	tail.rotation.z = 1.1
	label(root_node, "The Star Beast\n(a very long time ago)", Vector3(0, 0.9, 0.7), 28, Color(0.95, 0.9, 0.8))
	# A rope round it on brass posts
	for k in 6:
		var x := -4.5 + k * 1.8
		mesh_at(cylinder(0.05, 0.08, 1.0, 8), gold, Vector3(x, 0.5, 1.2), root_node)
	mesh_at(box(Vector3(9.0, 0.06, 0.06)), mat("Museum Rope", Color(0.75, 0.15, 0.3), 0.8), Vector3(0, 0.9, 1.2), root_node)
	# Glass cases round the wall, each with a treasure inside
	var glass := mat("Case Glass", Color(0.8, 0.95, 1.0), 0.05, 0.0, 0.0, 0.3)
	var treasures := [["Meteorite", Color(0.35, 0.3, 0.32)], ["Singing Crystal", Color(0.6, 0.9, 1.0)],
		["The First Shift Watch", Color(0.95, 0.8, 0.35)], ["Fossil Fern", Color(0.6, 0.55, 0.45)],
		["Moon Pebble", Color(0.85, 0.85, 0.95)], ["Gloop in a Jar", Color(0.4, 0.9, 0.4)]]
	for k in treasures.size():
		var a := PI / 2 + 0.9 + k * ((TAU - 1.8) / (treasures.size() - 1))
		var at: Array = facing_in(a, r - 2.0)
		var case := node(String(treasures[k][0]), root_node, at[0], at[1])
		solid_box(Vector3(1.2, 1.0, 1.2), stone, Vector3(0, 0.5, 0), case)
		mesh_at(box(Vector3(1.0, 0.9, 1.0)), glass, Vector3(0, 1.45, 0), case)
		mesh_at(sphere(0.25, 12), mat("Treasure %d" % k, treasures[k][1], 0.3, 0.3, 0.6 if k == 1 else 0.0), Vector3(0, 1.3, 0), case)
		label(case, String(treasures[k][0]), Vector3(0, 2.2, 0.0), 24, Color(0.95, 0.92, 0.85))
	# Paintings high up
	for k in 5:
		var a := PI / 2 + 1.2 + k * 0.95
		var p := Vector3(cos(a), 0, sin(a)) * (r - 0.45) + Vector3(0, 4.0, 0)
		var frame := mesh_at(box(Vector3(0.08, 1.3, 1.8)), gold, p, root_node, -a)
		frame.name = "Painting %d" % (k + 1)
		mesh_at(box(Vector3(0.05, 1.1, 1.6)), mat("Painting %d" % k, Color.from_hsv(k / 5.0, 0.45, 0.8), 0.8),
			p - Vector3(cos(a), 0, sin(a)) * 0.05, root_node, -a)
	light(root_node, Vector3(0, 8, 0), Color(1.0, 0.95, 0.85), 1.6, 22)
	light(root_node, Vector3(0, 4, -1), Color(1.0, 0.9, 0.75), 1.0, 9)
	label(root_node, "Museum", Vector3(0, 8.0, -4), 96, Color(1, 0.95, 0.85))
	own(root_node)
	return root_node


func _library() -> Node3D:
	# The Void's Library: bookcases all round, reading tables with lamps, the librarian's desk, and a swirl of books
	# flying round and round over the middle
	var r := 12.0
	var root_node := dome_room("Library", r, Color(0.75, 0.6, 0.85), Color(0.45, 0.32, 0.25), Color(0.95, 0.88, 1.0))
	var wood := mat("Library Wood", Color(0.5, 0.32, 0.2), 0.6)
	shelves_round(root_node, r, PI / 2 + 0.55, PI / 2 + TAU - 0.55, 22)
	# Reading tables with green lamps
	for t in [Vector2(-4, -1), Vector2(4, -1), Vector2(-4, 3.5), Vector2(4, 3.5)]:
		solid_box(Vector3(2.4, 0.08, 1.2), wood, Vector3(t.x, 0.8, t.y), root_node)
		for sx in [-1.0, 1.0]:
			mesh_at(box(Vector3(0.1, 0.8, 1.0)), wood, Vector3(t.x + sx * 1.0, 0.4, t.y), root_node)
		mesh_at(cylinder(0.2, 0.25, 0.15, 12), mat("Reading Lamp", Color(0.3, 0.75, 0.45), 0.4, 0.0, 1.2), Vector3(t.x, 1.25, t.y), root_node)
		mesh_at(cylinder(0.02, 0.02, 0.4, 6), mat("Lamp Brass", Color(0.9, 0.72, 0.35), 0.3, 0.8), Vector3(t.x, 1.0, t.y), root_node)
		for sz in [-1.0, 1.0]:
			solid_box(Vector3(2.0, 0.45, 0.45), mat("Library Bench", Color(0.55, 0.25, 0.35), 0.8), Vector3(t.x, 0.23, t.y + sz * 1.0), root_node)
	# The librarian's desk
	solid_box(Vector3(3.0, 1.0, 1.0), wood, Vector3(0, 0.5, -6.0), root_node)
	mesh_at(box(Vector3(0.4, 0.06, 0.3)), mat("Stamp Pad", Color(0.75, 0.2, 0.3), 0.6), Vector3(0.6, 1.03, -5.9), root_node)
	label(root_node, "Shhh... (mostly)", Vector3(0, 1.6, -5.5), 28, Color(0.95, 0.9, 1.0))
	# The flying books
	var swirl := spinner("Flying Books", root_node, Vector3(0, 5.0, 1.0), 0.5)
	var covers := [Color(0.85, 0.3, 0.3), Color(0.3, 0.5, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.45), Color(0.7, 0.4, 0.8)]
	for k in 12:
		var a := TAU * k / 12
		var b := mesh_at(box(Vector3(0.4, 0.08, 0.55)), mat("Flying Book %d" % (k % 5), covers[k % 5], 0.6),
			Vector3(cos(a) * 2.6, sin(a * 3) * 0.5, sin(a) * 2.6), swirl, -a)
		b.rotation.z = 0.4
	light(swirl, Vector3.ZERO, Color(1.0, 0.9, 0.7), 1.0, 7)
	light(root_node, Vector3(0, 7, 0), Color(1.0, 0.92, 0.8), 1.4, 20)
	label(root_node, "Library", Vector3(0, 7.5, -3), 96, Color(0.98, 0.92, 1.0))
	own(root_node)
	return root_node


func _potion_shop() -> Node3D:
	# The Potion Shop: a big bubbling cauldron, shelves of glowing bottles, herbs hanging from the ceiling, a crystal
	# ball and spell books on the counter
	var r := 10.0
	var root_node := dome_room("Potion Shop", r, Color(0.45, 0.3, 0.6), Color(0.3, 0.22, 0.3), Color(0.8, 0.7, 1.0))
	var wood := mat("Potion Wood", Color(0.35, 0.22, 0.15), 0.6)
	# The cauldron
	solid_cyl(1.2, 1.1, mat("Cauldron", Color(0.12, 0.12, 0.14), 0.5, 0.6), Vector3(0, 0.55, -1.0), root_node)
	mesh_at(cylinder(1.05, 1.05, 0.05, 24), mat("Brew", Color(0.4, 1.0, 0.5), 0.2, 0.0, 2.0), Vector3(0, 1.12, -1.0), root_node)
	for k in 5:
		var bub := mesh_at(sphere(0.12 + 0.04 * (k % 2), 8), mat("Brew Bubble", Color(0.6, 1.0, 0.7), 0.2, 0.0, 1.5),
			Vector3(cos(k * 1.3) * 0.6, 1.2, -1.0 + sin(k * 1.3) * 0.6), root_node)
		bub.name = "Bubble %d" % (k + 1)
	light(root_node, Vector3(0, 1.8, -1.0), Color(0.5, 1.0, 0.6), 1.5, 6)
	# Shelves of glowing bottles round the back
	var bottles := [Color(1.0, 0.4, 0.6), Color(0.4, 0.8, 1.0), Color(0.9, 0.85, 0.3), Color(0.7, 0.45, 1.0), Color(0.4, 1.0, 0.6)]
	for k in 5:
		var a := PI + 0.4 + k * 0.6 + PI / 2 - 0.2
		var at: Array = facing_in(a, r - 0.6)
		var shelf := node("Potion Shelf %d" % (k + 1), root_node, at[0], at[1])
		solid_box(Vector3(2.0, 2.6, 0.5), wood, Vector3(0, 1.3, -0.1), shelf)
		for row in 3:
			for j in 5:
				mesh_at(cylinder(0.08, 0.1, 0.3, 8), mat("Potion %d" % ((j + row + k) % 5), bottles[(j + row + k) % 5], 0.2, 0.0, 1.4),
					Vector3(-0.8 + j * 0.4, 0.6 + row * 0.75, 0.2), shelf)
	# Herbs hanging from the ceiling
	for k in 8:
		var a := TAU * k / 8
		mesh_at(cylinder(0.12, 0.02, 0.6, 6), mat("Herbs", Color(0.4, 0.6, 0.3), 0.9), Vector3(cos(a) * 4.0, 4.6, sin(a) * 4.0), root_node)
	# The counter with the crystal ball and spell books
	solid_box(Vector3(3.0, 1.0, 0.9), wood, Vector3(4.0, 0.5, 2.0), root_node, -0.6)
	mesh_at(sphere(0.3, 14), mat("Crystal Ball", Color(0.7, 0.6, 1.0), 0.05, 0.0, 1.2), Vector3(4.2, 1.3, 1.9), root_node)
	for k in 3:
		mesh_at(box(Vector3(0.35, 0.08, 0.45)), mat("Spell Book %d" % k, bottles[k + 1].darkened(0.3), 0.6),
			Vector3(3.4, 1.05 + k * 0.08, 2.3), root_node, 0.3 * k)
	plant(root_node, Vector3(-6, 0, 3), Color(0.55, 0.35, 0.7))
	light(root_node, Vector3(0, 5.5, 0), Color(0.85, 0.7, 1.0), 1.0, 16)
	label(root_node, "Potion Shop", Vector3(0, 6.0, -3), 80, Color(0.9, 0.85, 1.0))
	own(root_node)
	return root_node


func _book_store() -> Node3D:
	# The Book Store: bookcases round the wall, tables of new books, armchairs round a rug, and the shop cat
	var r := 10.0
	var root_node := dome_room("Book Store", r, Color(0.95, 0.85, 0.65), Color(0.5, 0.35, 0.22), Color(1.0, 0.92, 0.8))
	var wood := mat("Store Wood", Color(0.5, 0.32, 0.2), 0.6)
	shelves_round(root_node, r, PI / 2 + 0.6, PI / 2 + TAU - 0.6, 16)
	var covers := [Color(0.85, 0.3, 0.3), Color(0.3, 0.5, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.45), Color(0.7, 0.4, 0.8)]
	for t in [Vector2(-3, -2), Vector2(3, -2)]:
		solid_box(Vector3(2.0, 0.8, 1.0), wood, Vector3(t.x, 0.4, t.y), root_node)
		for k in 6:
			mesh_at(box(Vector3(0.3, 0.06 + 0.04 * (k % 3), 0.4)), mat("New Book %d" % (k % 5), covers[k % 5], 0.6),
				Vector3(t.x - 0.75 + k * 0.3, 0.83 + 0.02 * (k % 3), t.y), root_node, 0.1 * (k % 2))
	label(root_node, "NEW!", Vector3(-3, 1.4, -2), 36, Color(1.0, 0.9, 0.5))
	mesh_at(cylinder(2.0, 2.0, 0.03, 24), mat("Store Rug", Color(0.7, 0.3, 0.4), 0.95), Vector3(0, 0.02, 2.5), root_node)
	for k in 3:
		var a := PI + 0.3 + k * 1.2
		prop(ARMCHAIR, root_node, Vector3(cos(a) * 1.6, 0, 2.5 + sin(a) * 1.6), atan2(-cos(a), -sin(a)), Vector3(0.9, 0.5, 0.85),
			"Armchair %d" % (k + 1))
	solid_box(Vector3(2.4, 1.0, 0.9), wood, Vector3(-4.0, 0.5, 3.5), root_node, 0.8)
	var cat := node("Store Cat", root_node, Vector3(-4.1, 1.0, 3.4))
	var fur := mat("Cat Fur Grey", Color(0.55, 0.55, 0.6), 0.9)
	mesh_at(sphere(0.2, 10), fur, Vector3(0, 0.1, 0), cat).scale = Vector3(1.3, 0.65, 1)
	mesh_at(sphere(0.1, 8), fur, Vector3(0.2, 0.13, 0.05), cat)
	light(root_node, Vector3(0, 5.5, 0), Color(1.0, 0.88, 0.7), 1.4, 16)
	label(root_node, "Book Store", Vector3(0, 6.0, -3), 80, Color(1, 0.95, 0.85))
	own(root_node)
	return root_node


func _pet_shop() -> Node3D:
	# The Pet Shop: pens of bouncy little critters, fish tanks, bird cages with birds that turn, bags of pet food and
	# a counter with a bowl of treats
	var r := 10.0
	var root_node := dome_room("Pet Shop", r, Color(0.7, 0.9, 0.75), Color(0.6, 0.55, 0.45), Color(0.95, 1.0, 0.92))
	var wood := mat("Pet Wood", Color(0.62, 0.45, 0.3), 0.7)
	var critter := [Color(0.95, 0.75, 0.5), Color(0.9, 0.9, 0.95), Color(0.6, 0.45, 0.35), Color(0.95, 0.6, 0.75)]
	# Two pens of critters
	for p in [Vector2(-3.5, -2.5), Vector2(3.5, -2.5)]:
		var pen := node("Pen", root_node, Vector3(p.x, 0, p.y))
		for k in 4:
			var a := k * PI / 2
			solid_box(Vector3(3.0, 0.7, 0.1), wood, Vector3(cos(a) * 1.5, 0.35, sin(a) * 1.5), pen, a + PI / 2)
		mesh_at(box(Vector3(2.9, 0.04, 2.9)), mat("Pen Straw", Color(0.95, 0.85, 0.5), 0.95), Vector3(0, 0.03, 0), pen)
		for k in 3:
			var c := node("Critter", pen, Vector3(-0.7 + k * 0.7, 0, 0.3 * (k % 2)))
			c.set_script(load("res://scripts/spin.gd"))
			c.set("speed", 0.6 + 0.3 * k)
			var col: Color = critter[(k + int(p.x > 0)) % 4]
			mesh_at(sphere(0.25, 10), mat("Critter %s" % col.to_html(false), col, 0.9), Vector3(0.2, 0.22, 0), c).scale = Vector3(1.2, 0.85, 1)
			for ex in [-0.08, 0.08]:
				mesh_at(sphere(0.04, 6), mat("Critter Eye", Color(0.1, 0.1, 0.12), 0.3), Vector3(0.45, 0.3, ex), c)
	# Fish tanks along the back
	var water := mat("Pet Tank Water", Color(0.3, 0.7, 1.0), 0.05, 0.0, 0.6, 0.45)
	for k in 3:
		var a := PI + 0.9 + k * 0.6 + PI / 2 - 0.9
		var at: Array = facing_in(a, r - 1.0)
		var tank := node("Fish Tank %d" % (k + 1), root_node, at[0], at[1])
		solid_box(Vector3(1.6, 0.8, 0.8), wood, Vector3(0, 0.4, 0), tank)
		solid_box(Vector3(1.5, 1.0, 0.7), water, Vector3(0, 1.3, 0), tank)
		var school := node("Fish", tank, Vector3(0, 1.3, 0))
		school.set_script(load("res://scripts/fish_school.gd"))
		school.set("half_size", Vector3(0.6, 0.35, 0.25))
		for f in 3:
			fish(school, critter[(f + k) % 4].lightened(0.2), 0.1)
	# Bird cages on stands
	for k in 2:
		var cp := Vector3(-5.5 + k * 11.0, 0, 2.5)
		mesh_at(cylinder(0.03, 0.03, 1.6, 6), mat("Cage Gold", Color(0.95, 0.78, 0.35), 0.3, 0.8), cp + Vector3(0, 0.8, 0), root_node)
		mesh_at(cylinder(0.05, 0.45, 0.9, 12), mat("Cage Bars", Color(0.95, 0.78, 0.35), 0.3, 0.8, 0.0, 0.5), cp + Vector3(0, 2.05, 0), root_node)
		var bird := spinner("Bird", root_node, cp + Vector3(0, 1.85, 0), 0.4)
		mesh_at(sphere(0.12, 8), mat("Bird %d" % k, [Color(0.4, 0.8, 1.0), Color(1.0, 0.85, 0.3)][k], 0.6), Vector3(0.15, 0, 0), bird)
	# Pet food and the counter
	for k in 4:
		mesh_at(box(Vector3(0.5, 0.7, 0.25)), mat("Pet Food %d" % k, critter[k].darkened(0.2), 0.8), Vector3(-6.0 + k * 0.55, 0.35, -5.6), root_node)
	solid_box(Vector3(2.6, 1.0, 0.9), wood, Vector3(5.5, 0.5, -3.5), root_node, -0.8)
	mesh_at(cylinder(0.2, 0.15, 0.12, 12), mat("Treat Bowl", Color(0.95, 0.5, 0.5), 0.5), Vector3(5.4, 1.06, -3.4), root_node)
	plant(root_node, Vector3(-7, 0, -1))
	light(root_node, Vector3(0, 5.5, 0), Color(1.0, 0.95, 0.85), 1.4, 16)
	label(root_node, "Pet Shop", Vector3(0, 6.0, -3), 80, Color(0.95, 1.0, 0.92))
	own(root_node)
	return root_node


func _gaming_station() -> Node3D:
	# The Gaming Station: rows of glowing arcade cabinets, a big racing screen with beanbags, a claw machine full of
	# plushies and the token counter, under neon
	var r := 11.0
	var root_node := dome_room("Gaming Station", r, Color(0.2, 0.18, 0.3), Color(0.15, 0.13, 0.2), Color(0.6, 0.5, 0.9))
	var cab := mat("Cabinet", Color(0.25, 0.2, 0.4), 0.5)
	var screens := [Color(0.3, 1.0, 0.8), Color(1.0, 0.4, 0.7), Color(1.0, 0.9, 0.3), Color(0.5, 0.6, 1.0)]
	for k in 7:
		var a := PI + 0.2 + k * 0.42 + PI / 2 - 1.0
		var at: Array = facing_in(a, r - 1.0)
		var c := node("Arcade %d" % (k + 1), root_node, at[0], at[1])
		solid_box(Vector3(0.9, 1.9, 0.8), cab, Vector3(0, 0.95, 0), c)
		mesh_at(box(Vector3(0.7, 0.55, 0.05)), mat("Screen %d" % (k % 4), screens[k % 4], 0.2, 0.0, 2.2), Vector3(0, 1.4, 0.42), c)
		mesh_at(box(Vector3(0.8, 0.08, 0.35)), mat("Controls", Color(0.12, 0.12, 0.15), 0.4), Vector3(0, 1.0, 0.5), c)
		mesh_at(sphere(0.05, 6), mat("Joystick Red", Color(1.0, 0.2, 0.25), 0.3), Vector3(-0.2, 1.1, 0.55), c)
		mesh_at(box(Vector3(0.9, 0.2, 0.05)), mat("Marquee %d" % (k % 4), screens[(k + 1) % 4], 0.2, 0.0, 1.8), Vector3(0, 1.82, 0.41), c)
	# The big racing screen with beanbags
	var big := node("Big Screen", root_node, Vector3(0, 0, -r + 1.0))
	mesh_at(box(Vector3(5.0, 2.8, 0.1)), mat("Big Screen Glow", Color(0.4, 0.8, 1.0), 0.2, 0.0, 1.6), Vector3(0, 2.6, 0), big)
	label(big, "LAP 3/3", Vector3(0, 3.4, 0.1), 60, Color(1.0, 1.0, 0.7))
	for k in 4:
		var bb := mesh_at(sphere(0.45, 10), mat("Beanbag %d" % k, screens[k], 0.9), Vector3(-2.4 + k * 1.6, 0.3, 3.0), big)
		bb.scale = Vector3(1.1, 0.65, 1.1)
	# The claw machine
	var claw := node("Claw Machine", root_node, Vector3(6.0, 0, 2.0), -0.9)
	solid_box(Vector3(1.4, 1.0, 1.4), mat("Claw Base", Color(1.0, 0.4, 0.6), 0.5), Vector3(0, 0.5, 0), claw)
	mesh_at(box(Vector3(1.3, 1.3, 1.3)), mat("Claw Glass", Color(0.85, 0.95, 1.0), 0.05, 0.0, 0.0, 0.25), Vector3(0, 1.65, 0), claw)
	for k in 6:
		mesh_at(sphere(0.18, 8), mat("Claw Plush %d" % (k % 4), screens[k % 4].lightened(0.2), 0.9),
			Vector3(-0.35 + (k % 3) * 0.35, 1.2, -0.25 + (k / 3) * 0.5), claw)
	mesh_at(cylinder(0.02, 0.02, 0.6, 6), mat("Claw Metal", Color(0.8, 0.8, 0.85), 0.3, 0.9), Vector3(0, 2.0, 0), claw)
	# The token counter
	solid_box(Vector3(2.6, 1.0, 0.9), cab, Vector3(-6.0, 0.5, 2.0), root_node, 0.9)
	label(root_node, "TOKENS", Vector3(-6.0, 1.6, 2.0), 30, Color(1.0, 0.9, 0.3))
	light(root_node, Vector3(0, 5.5, 0), Color(0.7, 0.5, 1.0), 1.2, 18)
	light(root_node, Vector3(0, 2.5, -r + 2.5), Color(0.4, 0.8, 1.0), 1.2, 8)
	label(root_node, "Gaming Station", Vector3(0, 6.5, -4), 80, Color(1.0, 0.5, 0.85))
	own(root_node)
	return root_node


func _dashs_house() -> Node3D:
	# Dash's house: a tinkerer's mess. His workbench with tools and a half-built robot, blueprints pinned up, bike
	# parts, jars of bolts, his bed, and a dog bed beside it (for his twin, for now)
	var r := 9.0
	var root_node := dome_room("Dash's House", r, Color(0.55, 0.75, 0.9), Color(0.5, 0.42, 0.35), Color(0.9, 0.95, 1.0))
	var wood := mat("Dash Wood", Color(0.55, 0.38, 0.24), 0.6)
	var metal := mat("Dash Metal", Color(0.7, 0.72, 0.78), 0.3, 0.9)
	# The workbench and the robot on it
	solid_box(Vector3(3.2, 0.9, 1.0), wood, Vector3(-3.0, 0.45, -5.5), root_node, 0.3)
	var bot := node("Robot", root_node, Vector3(-3.0, 0.9, -5.5))
	mesh_at(box(Vector3(0.5, 0.6, 0.4)), metal, Vector3(0, 0.3, 0), bot)
	mesh_at(sphere(0.22, 10), metal, Vector3(0, 0.8, 0), bot)
	mesh_at(sphere(0.06, 6), mat("Robot Eye", Color(0.3, 0.9, 1.0), 0.2, 0.0, 2.0), Vector3(0.08, 0.84, 0.2), bot)
	mesh_at(cylinder(0.02, 0.02, 0.3, 6), metal, Vector3(0, 1.1, 0), bot)
	for k in 4:
		mesh_at(box(Vector3(0.05, 0.3, 0.05)), mat("Tool Red", Color(0.9, 0.3, 0.2), 0.5), Vector3(-4.2 + k * 0.25, 1.05, -5.9), root_node)
	for k in 3:
		mesh_at(cylinder(0.1, 0.1, 0.22, 10), mat("Bolt Jar", Color(0.85, 0.95, 1.0), 0.1, 0.0, 0.0, 0.5), Vector3(-1.9 + k * 0.25, 1.01, -5.2), root_node)
	# Blueprints pinned up round the wall
	for k in 4:
		var a := PI + 0.6 + k * 0.45 + PI / 2 - 1.2
		var p := Vector3(cos(a), 0, sin(a)) * (r - 0.35) + Vector3(0, 2.2, 0)
		mesh_at(box(Vector3(0.04, 0.9, 1.2)), mat("Blueprint", Color(0.25, 0.45, 0.85), 0.8, 0.0, 0.3), p, root_node, -a)
	# His bed, and the dog bed beside it
	solid_box(Vector3(1.4, 0.5, 2.2), mat("Dash Bed", Color(0.3, 0.55, 0.9), 0.8), Vector3(4.5, 0.25, -3.5), root_node, -0.4)
	mesh_at(box(Vector3(0.6, 0.15, 0.4)), mat("Pillow", Color(0.95, 0.95, 0.97), 0.8), Vector3(4.9, 0.55, -4.4), root_node, -0.4)
	mesh_at(cylinder(0.7, 0.6, 0.25, 16), mat("Dog Bed", Color(0.8, 0.45, 0.3), 0.9), Vector3(5.0, 0.13, -0.8), root_node)
	mesh_at(cylinder(0.55, 0.55, 0.05, 16), mat("Dog Bed Cushion", Color(0.95, 0.85, 0.7), 0.9), Vector3(5.0, 0.25, -0.8), root_node)
	label(root_node, "REX", Vector3(5.0, 0.6, -0.1), 24, Color(1.0, 0.9, 0.6))
	# Bike parts: two wheels against the wall
	for k in 2:
		var w := mesh_at(cylinder(0.45, 0.45, 0.06, 20), mat("Wheel", Color(0.12, 0.12, 0.14), 0.7), Vector3(-6.2, 0.45, 1.5 + k * 0.3), root_node)
		w.rotation.x = PI / 2
	plant(root_node, Vector3(6, 0, 3))
	light(root_node, Vector3(0, 5.0, 0), Color(0.95, 0.95, 1.0), 1.3, 14)
	light(root_node, Vector3(-3.0, 2.5, -5.0), Color(1.0, 0.9, 0.7), 1.0, 5)
	label(root_node, "Dash's House", Vector3(0, 5.5, -3), 70, Color(0.9, 0.95, 1.0))
	own(root_node)
	return root_node


func _melanies_house() -> Node3D:
	# Melanie's house: all about slides. Slide drawings on every wall, a toy slide, a pool float, her bed and a desk
	# covered in plans
	var r := 9.0
	var root_node := dome_room("Melanie's House", r, Color(0.95, 0.8, 0.9), Color(0.55, 0.45, 0.4), Color(1.0, 0.92, 0.96))
	var wood := mat("Melanie Wood", Color(0.75, 0.55, 0.4), 0.6)
	solid_box(Vector3(1.4, 0.5, 2.2), mat("Melanie Bed", Color(0.95, 0.5, 0.7), 0.8), Vector3(-4.5, 0.25, -3.5), root_node, 0.4)
	mesh_at(box(Vector3(0.6, 0.15, 0.4)), mat("Pillow", Color(0.95, 0.95, 0.97), 0.8), Vector3(-4.9, 0.55, -4.4), root_node, 0.4)
	# The toy slide in the middle
	var slide := node("Toy Slide", root_node, Vector3(1.0, 0, -1.0), 0.4)
	for k in 5:
		solid_box(Vector3(0.9, 0.3 * (k + 1), 0.3), mat("Slide Steps", Color(0.4, 0.75, 0.95), 0.5), Vector3(-1.4, 0.15 * (k + 1), -0.6 + k * 0.3), slide)
	var chute := mesh_at(box(Vector3(0.9, 0.08, 2.6)), mat("Slide Chute", Color(1.0, 0.85, 0.3), 0.3), Vector3(-1.4, 0.8, 1.9), slide)
	chute.rotation.x = 0.55
	# Her desk of plans and the drawings round the wall
	solid_box(Vector3(1.6, 0.75, 0.8), wood, Vector3(4.5, 0.38, -3.5), root_node, -0.6)
	for k in 3:
		mesh_at(box(Vector3(0.4, 0.01, 0.3)), mat("Plan Paper", Color(0.97, 0.97, 1.0), 0.9), Vector3(4.3 + k * 0.2, 0.77 + k * 0.005, -3.5), root_node, 0.2 * k)
	for k in 6:
		var a := PI + 0.4 + k * 0.42 + PI / 2 - 1.2
		var p := Vector3(cos(a), 0, sin(a)) * (r - 0.35) + Vector3(0, 2.0 + 0.3 * (k % 2), 0)
		mesh_at(box(Vector3(0.04, 0.6, 0.8)), mat("Slide Drawing %d" % k, Color.from_hsv(k / 6.0, 0.4, 0.95), 0.9), p, root_node, -a)
	label(root_node, "WE NEED A SLIDE!", Vector3(0, 3.6, -r + 0.6), 40, Color(0.95, 0.4, 0.6))
	var ring := mesh_at(cylinder(0.6, 0.6, 0.25, 20), mat("Pool Float", Color(1.0, 0.5, 0.4), 0.4), Vector3(-2.5, 0.12, 2.5), root_node)
	ring.scale = Vector3(1, 1, 1)
	mesh_at(cylinder(0.3, 0.3, 0.27, 16), mat("Pool Float Hole", Color(0.55, 0.45, 0.4), 0.9), Vector3(-2.5, 0.13, 2.5), root_node)
	plant(root_node, Vector3(6, 0, 2), Color(0.9, 0.5, 0.7))
	light(root_node, Vector3(0, 5.0, 0), Color(1.0, 0.92, 0.95), 1.3, 14)
	label(root_node, "Melanie's House", Vector3(0, 5.5, -3), 70, Color(1.0, 0.9, 0.95))
	own(root_node)
	return root_node


func _empty_home_2() -> Node3D:
	# A home nobody lives in yet: moving boxes, a broom, a rolled-up rug and a window seat waiting for someone
	var r := 9.0
	var root_node := dome_room("Empty Home 2", r, Color(0.9, 0.88, 0.82), Color(0.6, 0.5, 0.4), Color(1.0, 0.97, 0.9))
	var cardboard := mat("Cardboard", Color(0.78, 0.6, 0.4), 0.9)
	for k in 7:
		var p := Vector3(-3.0 + (k % 4) * 1.1, 0, -3.5 + (k / 4) * 1.2)
		var h := 0.5 + 0.15 * (k % 3)
		solid_box(Vector3(0.8, h, 0.8), cardboard, p + Vector3(0, h / 2, 0), root_node, 0.2 * (k % 3))
		mesh_at(box(Vector3(0.82, 0.04, 0.15)), mat("Tape", Color(0.85, 0.8, 0.6), 0.4), p + Vector3(0, h + 0.01, 0), root_node, 0.2 * (k % 3))
	var rug := mesh_at(cylinder(0.3, 0.3, 2.4, 12), mat("Rolled Rug", Color(0.6, 0.3, 0.45), 0.9), Vector3(3.0, 0.3, -2.0), root_node)
	rug.rotation.z = PI / 2
	var broom := mesh_at(cylinder(0.03, 0.03, 1.5, 6), mat("Broom Handle", Color(0.7, 0.55, 0.35), 0.7), Vector3(-6.5, 0.75, 1.5), root_node)
	broom.rotation.z = 0.25
	mesh_at(box(Vector3(0.35, 0.3, 0.12)), mat("Broom Straw", Color(0.95, 0.85, 0.5), 0.9), Vector3(-6.7, 0.15, 1.5), root_node)
	solid_box(Vector3(2.4, 0.5, 0.8), mat("Window Seat", Color(0.7, 0.85, 0.95), 0.8), Vector3(0, 0.25, -r + 1.0), root_node)
	label(root_node, "Waiting for someone", Vector3(0, 2.8, -r + 0.8), 36, Color(0.95, 0.92, 0.85))
	light(root_node, Vector3(0, 5.0, 0), Color(1.0, 0.95, 0.85), 1.2, 14)
	label(root_node, "Empty Home", Vector3(0, 5.5, -3), 70, Color(1.0, 0.97, 0.9))
	own(root_node)
	return root_node


func _haunted_house() -> Node3D:
	# The Haunted House, now its giggly spirit has gone (episodes.gd: the door only opens once it's let out). Dusty
	# sheets over the furniture, cobwebs, a cracked portrait, candles, an old piano, and a trail of glowing green goo
	# where the spirit went
	var r := 11.0
	var root_node := dome_room("Haunted House", r, Color(0.35, 0.3, 0.4), Color(0.28, 0.22, 0.2), Color(0.55, 0.5, 0.7))
	var sheet := mat("Dust Sheet", Color(0.9, 0.9, 0.92), 0.95)
	for p in [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(-5, 0, 2)]:
		solid_box(Vector3(1.6, 0.9, 0.9), sheet, p + Vector3(0, 0.45, 0), root_node)
		mesh_at(sphere(0.5, 10), sheet, p + Vector3(0.3, 0.95, 0), root_node).scale = Vector3(1.4, 0.4, 0.9)
	# The old piano
	var piano := node("Old Piano", root_node, Vector3(0, 0, -r + 1.6))
	solid_box(Vector3(2.4, 1.3, 0.8), mat("Piano Black", Color(0.08, 0.07, 0.08), 0.4), Vector3(0, 0.65, 0), piano)
	mesh_at(box(Vector3(2.2, 0.06, 0.25)), mat("Piano Keys", Color(0.95, 0.94, 0.88), 0.4), Vector3(0, 0.85, 0.5), piano)
	# A crooked portrait and candles
	var frame := mesh_at(box(Vector3(1.0, 1.3, 0.06)), mat("Haunted Frame", Color(0.6, 0.45, 0.25), 0.5, 0.6), Vector3(3.5, 2.6, -r + 1.2), root_node, -0.3)
	frame.rotation.z = 0.15
	mesh_at(box(Vector3(0.8, 1.1, 0.02)), mat("Portrait Grey", Color(0.45, 0.45, 0.5), 0.8), Vector3(3.49, 2.6, -r + 1.24), root_node, -0.3).rotation.z = 0.15
	for k in 3:
		mesh_at(cylinder(0.04, 0.04, 0.3, 8), mat("Candle", Color(0.97, 0.95, 0.85), 0.6), Vector3(-0.6 + k * 0.6, 1.45, -r + 1.6), root_node)
		mesh_at(sphere(0.04, 6), mat("Candle Flame", Color(1.0, 0.7, 0.3), 0.3, 0.0, 3.0), Vector3(-0.6 + k * 0.6, 1.65, -r + 1.6), root_node)
	light(root_node, Vector3(0, 2.0, -r + 2.0), Color(1.0, 0.7, 0.4), 1.0, 6)
	# The goo trail, giggling off to the door
	var goo := mat("Spirit Goo", Color(0.5, 1.0, 0.5), 0.2, 0.0, 1.6)
	for k in 9:
		var p := Vector3(sin(k * 0.8) * 1.2, 0.02, -6.0 + k * 1.3)
		mesh_at(cylinder(0.3 - 0.015 * k, 0.3 - 0.015 * k, 0.02, 12), goo, p, root_node)
	# Cobwebs in the dome
	var web := mat("Haunted Cobweb", Color(0.95, 0.95, 0.98), 0.5, 0.0, 0.3)
	for k in 6:
		var a := TAU * k / 6 + 0.3
		var w := mesh_at(box(Vector3(0.02, 2.0, 0.02)), web, Vector3(cos(a) * (r - 1.5), 4.0, sin(a) * (r - 1.5)), root_node)
		w.rotation.z = 0.6
	light(root_node, Vector3(0, 5.0, 0), Color(0.6, 0.55, 0.85), 0.8, 18)
	label(root_node, "Haunted House", Vector3(0, 6.0, -3), 80, Color(0.75, 1.0, 0.75))
	own(root_node)
	return root_node


func _toy_store() -> Node3D:
	# The Toy Store: shelves of blocks, balls and plushies, a toy train going round and round on its track, a giant
	# teddy, kites hanging from the dome, a rocking horse and the counter
	var r := 11.0
	var root_node := dome_room("Toy Store", r, Color(1.0, 0.85, 0.5), Color(0.55, 0.42, 0.3), Color(1.0, 0.95, 0.85))
	var wood := mat("Toy Wood", Color(0.75, 0.55, 0.35), 0.6)
	var bright := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.95, 0.8, 0.25), Color(0.4, 0.8, 0.45), Color(0.8, 0.45, 0.9)]
	for k in 5:
		var a := PI + 0.3 + k * 0.55 + PI / 2 - 1.2
		var at: Array = facing_in(a, r - 0.7)
		var shelf := node("Toy Shelf %d" % (k + 1), root_node, at[0], at[1])
		solid_box(Vector3(2.2, 2.4, 0.5), wood, Vector3(0, 1.2, -0.1), shelf)
		for row in 3:
			for j in 4:
				var c: Color = bright[(j + row + k) % 5]
				var y := 0.55 + row * 0.75
				match (j + row) % 3:
					0:
						mesh_at(box(Vector3(0.3, 0.3, 0.3)), mat("Toy Block %d" % ((j + row + k) % 5), c, 0.6), Vector3(-0.75 + j * 0.5, y, 0.2), shelf)
					1:
						mesh_at(sphere(0.17, 10), mat("Toy Ball %d" % ((j + row + k) % 5), c, 0.4), Vector3(-0.75 + j * 0.5, y, 0.2), shelf)
					_:
						mesh_at(sphere(0.15, 8), mat("Plushie %d" % ((j + row + k) % 5), c.lightened(0.3), 0.95), Vector3(-0.75 + j * 0.5, y, 0.2), shelf)
	# The train going round
	mesh_at(cylinder(3.0, 3.0, 0.04, 40), mat("Train Track", Color(0.45, 0.35, 0.3), 0.8), Vector3(0, 0.02, -1.0), root_node)
	mesh_at(cylinder(2.7, 2.7, 0.05, 40), mat("Track Middle", Color(0.4, 0.7, 0.4), 0.9), Vector3(0, 0.03, -1.0), root_node)
	var train := spinner("Toy Train", root_node, Vector3(0, 0, -1.0), 0.6)
	for k in 4:
		var a := k * 0.35
		var car := mesh_at(box(Vector3(0.4, 0.35, 0.6)), mat("Train %d" % k, bright[k], 0.4), Vector3(cos(a) * 2.85, 0.22, sin(a) * 2.85), train, -a)
		car.name = "Car %d" % (k + 1)
	# The giant teddy
	var fur := mat("Teddy Fur", Color(0.75, 0.5, 0.3), 0.95)
	var teddy := node("Giant Teddy", root_node, Vector3(5.5, 0, 2.5), -1.0)
	mesh_at(sphere(0.9, 14), fur, Vector3(0, 0.9, 0), teddy)
	mesh_at(sphere(0.6, 14), fur, Vector3(0, 2.1, 0), teddy)
	for sx in [-0.45, 0.45]:
		mesh_at(sphere(0.2, 10), fur, Vector3(sx, 2.6, 0), teddy)
		mesh_at(sphere(0.07, 6), mat("Teddy Eye", Color(0.1, 0.08, 0.08), 0.3), Vector3(sx * 0.45, 2.2, 0.53), teddy)
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	solid(shape, null, null, Vector3(5.5, 0.9, 2.5), root_node)
	# Kites up in the dome
	for k in 4:
		var a := TAU * k / 4 + 0.4
		var kite := mesh_at(box(Vector3(0.8, 0.8, 0.03)), mat("Kite %d" % k, bright[k], 0.6), Vector3(cos(a) * 5.0, 5.0, sin(a) * 5.0 - 1.0), root_node, -a)
		kite.rotation.z = PI / 4
	# The counter
	solid_box(Vector3(2.6, 1.0, 0.9), wood, Vector3(-5.5, 0.5, 2.5), root_node, 1.0)
	light(root_node, Vector3(0, 6.0, 0), Color(1.0, 0.92, 0.75), 1.5, 18)
	label(root_node, "Toy Store", Vector3(0, 6.5, -4), 90, Color(1.0, 0.92, 0.6))
	own(root_node)
	return root_node
