extends RefCounted

# Insides for Stars Hollow's buildings (16 Nov 2026; Hayden: "I want to add insides to all the buildings and give
# everything the baked in details"). The builder (tools/build_earth.gd _building) makes most of the town's shops and
# houses as one solid box with a door and windows painted on. This turns them into rooms you walk straight into, at
# play time, so earth.tscn isn't rebuilt:
#   - the solid box and its collision come out, and walls go up in their place with a real doorway where the painted
#     door was (the door swings open against the wall), a ceiling, a floor and the room's own wallpaper and lights,
#   - each room is furnished (FURNISH), using baked props (models/props/furniture, tools/build_prop_furniture.py) as
#     MultiMeshes, so a room full of booths is one draw for the graphics card, and the builder-style pieces merged
#     (scripts/static_batch.gd) as soon as the room's made,
#   - a room only draws when you're close (ROOM_RANGE): from the street you see its warm windows, as before.
#
# What we read first (Hayden's rule): DigitallyTailored/Godot-Open-World-Database (MIT, streams chunks in and out by
# distance: our rooms are small enough to keep and just not draw), Rytelier/Godot-4-interior-mapping-shader and
# OBKF/Fake-Interior-Shader (MIT, "interior mapping": a window that shows a room that isn't there; kept for windows
# you can't reach), and the walk-in rooms Stars Hollow already had (build_earth.gd _walk_in: seamless, no loading,
# the same doorway, Inside and Doorway markers, and the "interior" music). Seamless rooms suit a little town where
# you pop in and out; the Void's domes keep their doors to rooms of their own (tools/build_interiors.gd).

const STATIC_BATCH := preload("res://scripts/static_batch.gd")
const FURNITURE := "res://models/props/furniture/"
const HOLLOW_META := "hollowed"          # on the building's group once it's a room (tests and the occluders read it)
const NO_CRAWL_GROUP := "no_crawl_room"   # rooms nobody can wall-crawl in (scripts/wall_crawl.gd reads them)
const NO_CRAWL_META := "no_crawl_size"     # ...and the box, in the group's own space, that counts as inside
const WALL := 0.3                         # wall thickness (m)
const DOOR := Vector2(1.6, 2.5)           # the doorway's width and height
const ROOM_RANGE := 45.0                  # a room's insides stop drawing past this (m); its windows still glow
const FADE := 6.0

# Which buildings get insides, and what goes in them. "size" is the builder's (tools/build_earth.gd), so the old
# box is found by its size; "paper" the walls inside, "floor" the floor ("checker" makes a black and white one).
const ROOMS := {
	"Hollow Diner": {"size": Vector3(10, 4.2, 8), "paper": Color(0.96, 0.9, 0.78), "floor": "checker",
		"furnish": "_diner", "shop": Vector3(0.6, 1.0, -0.6)},
	"Bookshop": {"size": Vector3(9, 5.0, 8), "paper": Color(0.78, 0.86, 0.78), "floor": Color(0.5, 0.33, 0.2),
		"furnish": "_bookshop", "label": "Turn the Page Books"},
	"Corner Market": {"size": Vector3(10, 4.0, 8), "paper": Color(0.95, 0.95, 0.9), "floor": Color(0.82, 0.8, 0.74),
		"furnish": "_market", "shop": Vector3(-2.6, 1.0, 1.4)},
	"Maple Inn": {"size": Vector3(11, 6.5, 8), "paper": Color(0.86, 0.8, 0.9), "floor": Color(0.45, 0.28, 0.18),
		"furnish": "_inn"},
	"Antiques": {"size": Vector3(10, 5.5, 9), "paper": Color(0.62, 0.5, 0.62), "floor": Color(0.38, 0.25, 0.17),
		"furnish": "_antiques", "label": "Cobweb Corner Antiques"},
	"Hardware Store": {"size": Vector3(12, 5.0, 10), "paper": Color(0.86, 0.9, 0.82), "floor": Color(0.62, 0.62, 0.6),
		"furnish": "_hardware", "label": "Nuts & Bolts Hardware"},
	"Fire Station": {"size": Vector3(12, 6.0, 12), "paper": Color(0.92, 0.88, 0.82), "floor": Color(0.55, 0.55, 0.55),
		"furnish": "_fire_station", "label": "Fire Station No. 1"},
	"School": {"size": Vector3(26, 7.0, 14), "paper": Color(0.95, 0.9, 0.72), "floor": Color(0.62, 0.45, 0.3),
		"furnish": "_school", "label": "Old Oak Elementary"},
	"Home 1": {"size": Vector3(8, 5.0, 7), "paper": Color(0.92, 0.85, 0.75), "floor": Color(0.55, 0.38, 0.24),
		"furnish": "_home"},
	"Home 3": {"size": Vector3(8, 5.0, 7), "paper": Color(0.8, 0.88, 0.9), "floor": Color(0.5, 0.35, 0.22),
		"furnish": "_home"},
	"Palmer House": {"size": Vector3(9, 5.6, 7), "paper": Color(0.78, 0.86, 0.8), "floor": Color(0.42, 0.28, 0.18),
		"furnish": "_palmer"},
	"Maple House 1": {"size": Vector3(9, 5.6, 7), "paper": Color(0.95, 0.88, 0.75), "floor": Color(0.55, 0.38, 0.24),
		"furnish": "_home"},
	"Maple House 2": {"size": Vector3(9, 5.6, 7), "paper": Color(0.85, 0.9, 0.8), "floor": Color(0.48, 0.32, 0.2),
		"furnish": "_home"},
	"Maple House 3": {"size": Vector3(9, 5.6, 7), "paper": Color(0.95, 0.82, 0.8), "floor": Color(0.58, 0.4, 0.26),
		"furnish": "_home"},
	"Maple House 4": {"size": Vector3(9, 5.6, 7), "paper": Color(0.86, 0.82, 0.94), "floor": Color(0.45, 0.3, 0.2),
		"furnish": "_home"},
	"Maple House 5": {"size": Vector3(9, 5.6, 7), "paper": Color(0.94, 0.92, 0.84), "floor": Color(0.55, 0.36, 0.22),
		"furnish": "_home"},
	"Maple House 6": {"size": Vector3(9, 5.6, 7), "paper": Color(0.8, 0.86, 0.94), "floor": Color(0.5, 0.34, 0.2),
		"furnish": "_home"},
}

static var _meshes := {}                  # baked prop path -> [its Mesh, where it sits in the glb] (loaded once)
static var _checker: StandardMaterial3D
static var _mats := {}                    # one material per look, shared, so the merged pieces need fewer draws


# Hollows and furnishes every building in ROOMS that's in the scene. Returns how many it did.
static func dress_earth(scene: Node) -> int:
	var made := 0
	for name in ROOMS:
		var g := scene.get_node_or_null(name) as Node3D
		if g == null or g.has_meta(HOLLOW_META):
			continue
		if hollow(g, ROOMS[name]):
			made += 1
	return made


# The names of the buildings that are rooms now (scripts/town_occluders.gd leaves them out: an occluder inside would
# hide the room seen through its door).
static func hollowed(scene: Node) -> Array:
	var out := []
	for name in ROOMS:
		var g := scene.get_node_or_null(name)
		if g and g.has_meta(HOLLOW_META):
			out.append(name)
			if ROOMS[name].has("label"):
				out.append(ROOMS[name].label)           # (the map calls some of them by their sign)
	return out


static func hollow(g: Node3D, spec: Dictionary) -> bool:
	var size: Vector3 = spec.size
	var wall_m: Material = null
	# Take out the solid box (its mesh and its collision) and the painted door
	for c in g.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var mi := c as MeshInstance3D
			var bs := (mi.mesh as BoxMesh).size
			if bs.is_equal_approx(size):
				wall_m = mi.material_override
				g.remove_child(mi)
				mi.queue_free()
			elif mi.material_override and mi.material_override.resource_name == "Front Door":
				_open_door(g, mi, size)
		elif c is StaticBody3D:
			var cs := c.get_child(0) as CollisionShape3D if c.get_child_count() > 0 else null
			if cs and cs.shape is BoxShape3D and (cs.shape as BoxShape3D).size.is_equal_approx(size):
				g.remove_child(c)
				c.queue_free()
	if wall_m == null:
		return false
	var room := Node3D.new()
	room.name = "Room"
	g.add_child(room)
	_walls(room, size, wall_m, _plain("Paper " + g.name, spec.paper, 0.9))
	var hd := size.z / 2.0
	var floor_m: Material = _checker_mat() if spec.floor is String else _plain("Floor " + g.name, spec.floor, 0.7)
	_box(room, Vector3(size.x - WALL * 2, 0.04, size.z - WALL * 2), floor_m, Vector3(0, 0.02, 0))
	# The windows from inside: the builder's glowing panes sit on the outside of the wall, so a second pane on the
	# inside face of each one (below the ceiling) shows from in the room (the way _walk_in does it)
	var glass := _plain("Inside Window", Color(0.78, 0.88, 0.98), 0.2, 0.45)
	for c in g.get_children():
		var w := c as MeshInstance3D
		if w == null or not (w.mesh is BoxMesh) or w.material_override == null:
			continue
		if w.material_override.resource_name != "Warm Window" or w.position.z < hd - 0.2:
			continue
		var ws := (w.mesh as BoxMesh).size
		if w.position.y + ws.y / 2 < size.y - 0.3:
			_box(room, Vector3(ws.x, ws.y, 0.04), glass, Vector3(w.position.x, w.position.y, hd - WALL - 0.03))
	var furn := Node3D.new()
	furn.name = "Furniture"
	room.add_child(furn)
	Callable(load("res://scripts/insides.gd"), spec.furnish).call(furn, size)
	# Warm lights, always on (no shadows: cheap), and the room's music
	for k in int(ceil(size.x / 8.0)):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.7)
		l.light_energy = 1.5
		l.omni_range = maxf(size.z, 8.0)
		l.position = Vector3(-size.x / 2 + size.x * (k + 0.5) / ceil(size.x / 8.0), size.y - 0.7, 0)
		l.distance_fade_enabled = true             # (lights fade out by distance, not visibility ranges)
		l.distance_fade_begin = ROOM_RANGE - FADE
		l.distance_fade_length = FADE
		room.add_child(l)
	_music(room, size)
	if g.get_node_or_null("Inside") == null:
		var m_in := Marker3D.new()
		m_in.name = "Inside"
		m_in.position = Vector3(0, 1.0, hd - 2.0)
		g.add_child(m_in)
		var m_door := Marker3D.new()
		m_door.name = "Doorway"
		m_door.position = Vector3(0, 1.0, hd + 2.2)
		g.add_child(m_door)
	_clear_floor(g, size)
	# A shop's counter is inside now (scripts/earth_town.gd reads "shop_at", whichever of the two runs first)
	if spec.has("shop"):
		g.set_meta("shop_at", spec.shop)
		for c in g.get_children():
			if c is Area3D and String(c.name).begins_with("Shop "):
				(c as Node3D).position = spec.shop
	# Merge the room's still pieces now (one mesh per material), then only draw them near
	STATIC_BATCH.batch(room)
	# The pieces that went into the merge aren't needed after: nothing in a room moves (the fans and pendulums have
	# scripts, so they're never merged), and the room's solid parts are their own bodies. So the room needs no Batch
	# Watch looking over them every frame (17 of them cost about 25 ms a frame), and the hidden pieces can go.
	var watch := room.get_node_or_null("Batch Watch")
	if watch:
		room.remove_child(watch)
		watch.free()
	for n in room.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.layers == 0 and mi.has_meta(STATIC_BATCH.MERGED_META):
			mi.get_parent().remove_child(mi)
			mi.free()
	_near_only(room)
	g.set_meta(HOLLOW_META, true)
	# No wall crawl in here (scripts/wall_crawl.gd): up a wall she'd crawl the ceiling and slip out through the gap
	# over the walls, into the hollow under the roof and out of the town. Outside, the walls still climb as before.
	g.set_meta(NO_CRAWL_META, size)
	g.add_to_group(NO_CRAWL_GROUP)
	return true


# -----------------------------------------------------------------------------
# The shell
# -----------------------------------------------------------------------------
static func _walls(room: Node3D, size: Vector3, outer: Material, inner: Material) -> void:
	var hw := size.x / 2.0
	var hd := size.z / 2.0
	var h := size.y
	var t := WALL
	# Back and sides
	_solid(room, Vector3(size.x, h, t), outer, Vector3(0, h / 2, -hd + t / 2))
	for sx in [-1.0, 1.0]:
		_solid(room, Vector3(t, h, size.z), outer, Vector3(sx * (hw - t / 2), h / 2, 0))
	# The front, round the doorway
	var side_w := (size.x - DOOR.x) / 2.0
	for sx in [-1.0, 1.0]:
		_solid(room, Vector3(side_w, h, t), outer, Vector3(sx * (DOOR.x / 2 + side_w / 2), h / 2, hd - t / 2))
	_solid(room, Vector3(DOOR.x, h - DOOR.y, t), outer, Vector3(0, DOOR.y + (h - DOOR.y) / 2, hd - t / 2))
	# The ceiling (the roof's prism sits on top, as before)
	_solid(room, Vector3(size.x, 0.2, size.z), outer, Vector3(0, h - 0.1, 0))
	# Wallpaper and a skirting board inside, a hair in from each wall
	var in_w := size.x - t * 2
	var in_d := size.z - t * 2
	_box(room, Vector3(in_w, h - 0.2, 0.02), inner, Vector3(0, (h - 0.2) / 2, -hd + t + 0.011))
	for sx in [-1.0, 1.0]:
		_box(room, Vector3(0.02, h - 0.2, in_d), inner, Vector3(sx * (hw - t - 0.011), (h - 0.2) / 2, 0))
		_box(room, Vector3((in_w - DOOR.x) / 2, h - 0.2, 0.02), inner,
			Vector3(sx * (DOOR.x / 2 + (in_w - DOOR.x) / 4), (h - 0.2) / 2, hd - t - 0.011))
	_box(room, Vector3(DOOR.x, h - 0.2 - DOOR.y, 0.02), inner, Vector3(0, DOOR.y + (h - 0.2 - DOOR.y) / 2, hd - t - 0.011))
	_box(room, Vector3(in_w, 0.02, in_d), _plain("Ceiling", Color(0.97, 0.96, 0.93), 0.9), Vector3(0, h - 0.21, 0))
	var skirt := _plain("Skirting", Color(0.35, 0.24, 0.16), 0.7)
	_box(room, Vector3(in_w, 0.16, 0.04), skirt, Vector3(0, 0.08, -hd + t + 0.03))
	for sx in [-1.0, 1.0]:
		_box(room, Vector3(0.04, 0.16, in_d), skirt, Vector3(sx * (hw - t - 0.03), 0.08, 0))


static func _open_door(g: Node3D, door: MeshInstance3D, size: Vector3) -> void:
	# The painted door swings open into the room, against the wall beside the doorway (hinged on its left)
	var hinge := Node3D.new()
	hinge.name = "Open Door"
	hinge.position = Vector3(-DOOR.x / 2, 0, size.z / 2 - WALL)
	g.add_child(hinge)
	door.reparent(hinge, false)
	door.position = Vector3(0.65, 1.15, 0.1)
	hinge.rotation.y = deg_to_rad(172)           # (nearly flat against the wall, inside)
	door.name = "Door Leaf"


static func _clear_floor(g: Node3D, size: Vector3) -> void:
	# The fallen leaves (and spring's flowers, winter's drifts) were scattered over the whole town, the solid box hid the
	# ones under it; now there's a floor there, so the ones inside the walls go (tiny, the way seasons.gd hides one)
	var scene := g.get_parent()
	var mmi := scene.find_child("Fallen Leaves", true, false) as MultiMeshInstance3D
	if mmi == null:
		return
	var to_local := g.global_transform.affine_inverse()
	var half := Vector2(size.x / 2.0 + 0.2, size.z / 2.0 + 0.2)
	var gone := Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -50, 0))
	var inside := func(p: Vector3) -> bool:
		var l: Vector3 = to_local * (mmi.global_transform * p)
		return absf(l.x) < half.x and absf(l.z) < half.y
	# The builder's saved copy (scripts/multi_fill.gd), which the seasons read their list from...
	if "transforms" in mmi:
		var xf: PackedFloat32Array = mmi.get("transforms")
		for i in xf.size() / 12:
			if inside.call(Vector3(xf[i * 12 + 9], xf[i * 12 + 10], xf[i * 12 + 11])):
				for k in 9:
					xf[i * 12 + k] = 0.0001 if k % 4 == 0 else 0.0
				xf[i * 12 + 10] = -50.0
		mmi.set("transforms", xf)
	# ...the seasons' own list if they've read it already...
	var seasons := scene.get_node_or_null("Seasons")
	if seasons and "_fallen_xf" in seasons:
		var list: Array = seasons.get("_fallen_xf")
		for i in list.size():
			if inside.call((list[i] as Transform3D).origin):
				list[i] = gone
	# ...and what's drawn now
	var mm := mmi.multimesh
	if mm:
		for i in mm.instance_count:
			if inside.call(mm.get_instance_transform(i).origin):
				mm.set_instance_transform(i, gone)


static func _music(room: Node3D, size: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = "Music"
	zone.set_script(load("res://scripts/music_zone.gd"))
	zone.set("track", "interior")
	var zs := CollisionShape3D.new()
	var zb := BoxShape3D.new()
	zb.size = Vector3(size.x - WALL * 2, 3.5, size.z - WALL * 2)
	zs.shape = zb
	zs.position = Vector3(0, 1.75, 0)
	zone.add_child(zs)
	room.add_child(zone)


static func _near_only(room: Node3D) -> void:
	for n in room.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi is MeshInstance3D and (gi as MeshInstance3D).layers == 0:
			continue
		gi.visibility_range_end = ROOM_RANGE
		gi.visibility_range_end_margin = FADE
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


# -----------------------------------------------------------------------------
# Pieces
# -----------------------------------------------------------------------------
static func _plain(name: String, c: Color, rough := 0.8, emit := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f|%.2f" % [name, c.to_html(), rough, emit, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	_mats[key] = m
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _checker_mat() -> StandardMaterial3D:
	# A black and white tiled floor: a 2x2 picture repeated, tiles 0.5 m (world-space so every room lines up)
	if _checker == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.set_pixel(0, 0, Color(0.95, 0.94, 0.9))
		img.set_pixel(1, 1, Color(0.95, 0.94, 0.9))
		img.set_pixel(1, 0, Color(0.12, 0.12, 0.14))
		img.set_pixel(0, 1, Color(0.12, 0.12, 0.14))
		_checker = StandardMaterial3D.new()
		_checker.resource_name = "Checker Floor"
		_checker.albedo_texture = ImageTexture.create_from_image(img)
		_checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_checker.uv1_triplanar = true
		_checker.uv1_world_triplanar = true
		_checker.uv1_scale = Vector3(1, 1, 1)
		_checker.roughness = 0.35
	return _checker


static func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bottom: float, h: float, m: Material, pos: Vector3, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _solid(parent: Node3D, size: Vector3, m: Material, pos: Vector3, yaw := 0.0) -> void:
	_box(parent, size, m, pos, yaw)
	_collide(parent, size, pos, yaw)


static func _collide(parent: Node3D, size: Vector3, pos: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	b.add_child(cs)
	parent.add_child(b)
	return b


static func _label(parent: Node3D, text: String, pos: Vector3, size := 40, c := Color(1, 0.97, 0.88), yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 8
	l.modulate = c
	l.outline_modulate = Color(0.1, 0.08, 0.08)
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


static func baked(file: String) -> Mesh:
	# The mesh of a baked prop (its one MeshInstance3D), loaded once. null if it isn't there (not imported yet).
	_load_baked(file)
	return _meshes[FURNITURE + file + ".glb"][0]


static func baked_offset(file: String) -> Transform3D:
	# Where that mesh sits in its glb (Blender keeps each object's origin where it was made: the desk's is up at its
	# top), so a copy placed with its feet on the floor stands on the floor
	_load_baked(file)
	return _meshes[FURNITURE + file + ".glb"][1]


static func _load_baked(file: String) -> void:
	var path := FURNITURE + file + ".glb"
	if _meshes.has(path):
		return
	var mesh: Mesh = null
	var at := Transform3D.IDENTITY
	if ResourceLoader.exists(path):
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		var mis := inst.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi := mis[0] as MeshInstance3D
			mesh = mi.mesh
			var n: Node = mi
			while n != inst and n is Node3D:
				at = (n as Node3D).transform * at
				n = n.get_parent()
		inst.free()
	_meshes[path] = [mesh, at]


static func many(parent: Node3D, file: String, xforms: Array, name := "") -> MultiMeshInstance3D:
	# Copies of one baked prop, all drawn at once
	var mesh := baked(file)
	if mesh == null or xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var at := baked_offset(file)
	for k in xforms.size():
		mm.set_instance_transform(k, (xforms[k] as Transform3D) * at)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name if name != "" else file.capitalize()
	mmi.multimesh = mm
	mmi.set_meta("transforms", xforms)        # (a headless run keeps no MultiMesh transforms: tests read these)
	parent.add_child(mmi)
	return mmi


static func _xf(pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


# -----------------------------------------------------------------------------
# What's in each room
# -----------------------------------------------------------------------------
static func _diner(f: Node3D, size: Vector3) -> void:
	# The Hollow Diner: a long counter with stools down the back, red booths along both sides, a jukebox, a pie case,
	# a menu board, a neon sign, pendant lamps and ceiling fans
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var h := size.y
	var chrome := _plain("Diner Chrome", Color(0.85, 0.86, 0.9), 0.15, 0.0, 1.0)
	var mint := _plain("Diner Mint", Color(0.55, 0.85, 0.75), 0.5)
	var red := _plain("Diner Red", Color(0.78, 0.13, 0.15), 0.4)
	var white := _plain("Diner White", Color(0.97, 0.96, 0.92), 0.4)
	# A mint stripe round the walls at table height
	_box(f, Vector3(hw * 2 - 0.02, 0.18, 0.03), mint, Vector3(0, 1.0, -hd + 0.02))
	for sx in [-1.0, 1.0]:
		_box(f, Vector3(0.03, 0.18, hd * 2 - 0.02), mint, Vector3(sx * (hw - 0.02), 1.0, 0))
	# The counter along the back, with a chrome edge and the stools in front
	var cz := -hd + 1.55
	_solid(f, Vector3(6.2, 1.0, 0.7), mint, Vector3(0.6, 0.5, cz))
	_box(f, Vector3(6.4, 0.06, 0.85), white, Vector3(0.6, 1.03, cz + 0.05))
	_box(f, Vector3(6.4, 0.05, 0.04), chrome, Vector3(0.6, 0.99, cz + 0.48))
	_box(f, Vector3(6.2, 0.12, 0.04), chrome, Vector3(0.6, 0.12, cz + 0.36))
	var stools := []
	for k in 6:
		stools.append(_xf(Vector3(-1.9 + k * 1.0, 0, cz + 0.85)))
	many(f, "diner_stool", stools, "Stools")
	for x in [-1.9, -0.9, 0.1, 1.1, 2.1, 3.1]:
		_collide(f, Vector3(0.4, 0.76, 0.4), Vector3(x, 0.38, cz + 0.85))
	# Behind the counter: the back bar with the coffee machine, the milkshake mixer, the pie case and the hatch
	_solid(f, Vector3(hw * 2, 0.95, 0.5), white, Vector3(0, 0.48, -hd + 0.25))
	_box(f, Vector3(1.0, 0.6, 0.45), chrome, Vector3(-2.0, 1.25, -hd + 0.28))                     # coffee machine
	_box(f, Vector3(0.3, 0.06, 0.3), _plain("Coffee Glow", Color(1.0, 0.45, 0.2), 0.4, 1.5), Vector3(-2.0, 1.35, -hd + 0.52))
	for k in 3:                                                                                # milkshake mixer cups
		_cyl(f, 0.06, 0.05, 0.22, chrome, Vector3(-0.8 + k * 0.2, 1.08, -hd + 0.3), 10)
	var case_glass := StandardMaterial3D.new()
	case_glass.albedo_color = Color(0.85, 0.95, 1.0, 0.3)
	case_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	case_glass.roughness = 0.05
	_box(f, Vector3(1.2, 0.5, 0.5), case_glass, Vector3(2.4, 1.3, cz + 0.05))                  # the pie case
	for k in 3:
		_cyl(f, 0.18, 0.16, 0.07, _plain("Pie Crust", Color(0.86, 0.6, 0.3), 0.8), Vector3(2.0 + k * 0.4, 1.1, cz + 0.05))
		_cyl(f, 0.14, 0.14, 0.02, _plain("Pie Filling %d" % k, [Color(0.85, 0.42, 0.12), Color(0.6, 0.1, 0.2),
			Color(0.95, 0.85, 0.5)][k], 0.6), Vector3(2.0 + k * 0.4, 1.15, cz + 0.05))
	_box(f, Vector3(1.8, 0.7, 0.06), _plain("Hatch Dark", Color(0.2, 0.18, 0.18), 0.8), Vector3(1.0, 2.0, -hd + 0.03))
	_box(f, Vector3(1.9, 0.06, 0.3), chrome, Vector3(1.0, 1.62, -hd + 0.15))
	_label(f, "ORDER UP!", Vector3(1.0, 2.5, -hd + 0.06), 24, Color(0.2, 0.2, 0.2)).outline_size = 0
	# The menu board and the neon sign
	_box(f, Vector3(2.6, 1.0, 0.06), _plain("Menu Board", Color(0.12, 0.14, 0.13), 0.9), Vector3(-2.2, 2.4, -hd + 0.04))
	_label(f, "TODAY\nPumpkin pie  Pancakes\nMilkshakes  Hot cocoa", Vector3(-2.2, 2.4, -hd + 0.08), 22,
		Color(1, 0.97, 0.88)).outline_size = 0
	var neon := _label(f, "EAT", Vector3(3.6, 3.15, -hd + 0.06), 90, Color(1.0, 0.35, 0.45))
	neon.outline_modulate = Color(1.0, 0.6, 0.7)
	neon.outline_size = 14
	# Booths along both side walls, in pairs back to back, each pair round a table
	var booths := []
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw - 0.85)
		for z in [-0.1, 2.15]:
			# A table between two booths facing each other along z (the booth's front is its +Z)
			booths.append(_xf(Vector3(x, 0, z - 0.95), 0.0))
			booths.append(_xf(Vector3(x, 0, z + 0.95), PI))
			_solid(f, Vector3(1.1, 0.05, 0.75), white, Vector3(x, 0.74, z))
			_box(f, Vector3(1.12, 0.03, 0.77), chrome, Vector3(x, 0.71, z))
			_cyl(f, 0.05, 0.05, 0.7, chrome, Vector3(x, 0.36, z), 8)
			_box(f, Vector3(0.12, 0.12, 0.08), chrome, Vector3(x + sx * 0.4, 0.82, z))             # napkins
			_cyl(f, 0.03, 0.03, 0.14, red, Vector3(x + sx * 0.25, 0.84, z - 0.1), 8)               # ketchup
			_cyl(f, 0.03, 0.03, 0.14, _plain("Mustard", Color(0.95, 0.8, 0.2), 0.5), Vector3(x + sx * 0.25, 0.84, z + 0.1), 8)
	many(f, "diner_booth", booths, "Booths")
	for b: Transform3D in booths:
		_collide(f, Vector3(1.6, 0.46, 0.55), b.origin + Vector3(0, 0.23, 0))
		_collide(f, Vector3(1.6, 1.15, 0.2), b.origin + b.basis * Vector3(0, 0.57, -0.24))
	# The jukebox in the front corner
	var jx := hw - 0.5
	var jz := hd - 0.55
	_solid(f, Vector3(0.8, 1.3, 0.5), red, Vector3(jx, 0.65, jz))
	var arch := _cyl(f, 0.4, 0.4, 0.5, _plain("Jukebox Glow", Color(1.0, 0.75, 0.3), 0.3, 1.8), Vector3(jx, 1.3, jz), 20)
	arch.rotation.x = PI / 2
	_box(f, Vector3(0.5, 0.3, 0.02), _plain("Jukebox Window", Color(0.4, 0.8, 1.0), 0.2, 1.2), Vector3(jx, 0.9, jz - 0.26))
	# Pendant lamps over the counter and the tables, and two slow ceiling fans
	var shade := _plain("Lamp Shade", Color(0.55, 0.85, 0.75), 0.4, 0.6)
	for x in [-1.4, 0.6, 2.6]:
		_cyl(f, 0.01, 0.01, 1.0, chrome, Vector3(x, h - 0.7, cz + 0.2), 6)
		_cyl(f, 0.08, 0.28, 0.25, shade, Vector3(x, h - 1.3, cz + 0.2), 16)
	for x in [-2.0, 2.0]:
		var fan := Node3D.new()
		fan.name = "Ceiling Fan"
		fan.position = Vector3(x, h - 0.5, 1.4)
		fan.set_script(load("res://scripts/spin.gd"))
		f.add_child(fan)
		_cyl(fan, 0.12, 0.12, 0.15, chrome, Vector3.ZERO, 12)
		var blade_m := _plain("Fan Blade", Color(0.45, 0.3, 0.2), 0.6)
		for k in 4:
			var a := k * PI / 2
			_box(fan, Vector3(1.1, 0.02, 0.18), blade_m, Vector3(cos(a) * 0.6, -0.05, -sin(a) * 0.6), a)
	# A plant by the door
	_cyl(f, 0.25, 0.2, 0.45, _plain("Pot", Color(0.85, 0.5, 0.35), 0.8), Vector3(-hw + 0.5, 0.22, hd - 0.5))
	var leaf := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	leaf.mesh = sm
	leaf.material_override = _plain("Plant", Color(0.3, 0.55, 0.3), 0.9)
	leaf.position = Vector3(-hw + 0.5, 0.9, hd - 0.5)
	f.add_child(leaf)


# -----------------------------------------------------------------------------
# Shared furniture made from shapes (merged per material once the room's made)
# -----------------------------------------------------------------------------
static func _ball(parent: Node3D, r: float, m: Material, pos: Vector3, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func _plant(f: Node3D, pos: Vector3, s := 1.0) -> void:
	_cyl(f, 0.25 * s, 0.2 * s, 0.45 * s, _plain("Pot", Color(0.85, 0.5, 0.35), 0.8), pos + Vector3(0, 0.22 * s, 0))
	_ball(f, 0.45 * s, _plain("Plant", Color(0.3, 0.55, 0.3), 0.9), pos + Vector3(0, 0.9 * s, 0))


static func _rug(f: Node3D, pos: Vector3, w: float, d: float, c: Color) -> void:
	_box(f, Vector3(w, 0.02, d), _plain("Rug", c, 0.95), pos + Vector3(0, 0.05, 0))
	_box(f, Vector3(w - 0.3, 0.022, d - 0.3), _plain("Rug Middle", c.lightened(0.25), 0.95), pos + Vector3(0, 0.052, 0))


static func _table(f: Node3D, pos: Vector3, w: float, d: float, h: float, m: Material) -> void:
	_solid(f, Vector3(w, 0.05, d), m, pos + Vector3(0, h - 0.025, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(f, Vector3(0.06, h - 0.05, 0.06), m, pos + Vector3(sx * (w / 2 - 0.08), (h - 0.05) / 2, sz * (d / 2 - 0.08)))


static func _chair(f: Node3D, pos: Vector3, yaw: float, m: Material) -> void:
	# A plain wooden chair, its back on its -Z (you sit facing +Z, turned by yaw)
	var b := Basis(Vector3.UP, yaw)
	_box(f, Vector3(0.42, 0.04, 0.42), m, pos + Vector3(0, 0.45, 0), yaw)
	_box(f, Vector3(0.42, 0.45, 0.04), m, pos + b * Vector3(0, 0.7, -0.19), yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(f, Vector3(0.04, 0.45, 0.04), m, pos + b * Vector3(sx * 0.18, 0.22, sz * 0.18), yaw)
	_collide(f, Vector3(0.42, 0.47, 0.42), pos + Vector3(0, 0.235, 0), yaw)


static func _lamp(f: Node3D, pos: Vector3) -> void:
	var brass := _plain("Lamp Brass", Color(0.8, 0.62, 0.3), 0.3, 0.0, 0.8)
	_cyl(f, 0.16, 0.18, 0.04, brass, pos + Vector3(0, 0.02, 0), 12)
	_cyl(f, 0.02, 0.02, 1.5, brass, pos + Vector3(0, 0.77, 0), 6)
	_cyl(f, 0.14, 0.26, 0.3, _plain("Lamp Shade Warm", Color(1.0, 0.85, 0.6), 0.6, 1.2), pos + Vector3(0, 1.6, 0), 14)


static func _picture(f: Node3D, pos: Vector3, yaw: float, w: float, h: float, c: Color) -> void:
	# A framed picture hung flat on a wall (its face towards +Z, turned by yaw)
	var b := Basis(Vector3.UP, yaw)
	_box(f, Vector3(w + 0.12, h + 0.12, 0.04), _plain("Frame Gold", Color(0.82, 0.65, 0.3), 0.35, 0.0, 0.7), pos, yaw)
	_box(f, Vector3(w, h, 0.02), _plain("Picture", c, 0.8), pos + b * Vector3(0, 0, 0.022), yaw)
	_box(f, Vector3(w * 0.5, h * 0.35, 0.01), _plain("Picture Hill", c.darkened(0.35), 0.8), pos + b * Vector3(-w * 0.1, -h * 0.2, 0.035), yaw)
	_ball(f, minf(w, h) * 0.12, _plain("Picture Sun", Color(1.0, 0.85, 0.4), 0.8), pos + b * Vector3(w * 0.25, h * 0.2, 0.03),
		Vector3(1, 1, 0.1))


static func _fireplace(f: Node3D, pos: Vector3, yaw: float) -> void:
	# Against a wall, its opening towards +Z (turned by yaw), with a glowing fire and a mantel
	var b := Basis(Vector3.UP, yaw)
	var stone := _plain("Fireplace Stone", Color(0.62, 0.58, 0.55), 0.9)
	_solid(f, Vector3(1.8, 1.3, 0.5), stone, pos + Vector3(0, 0.65, 0), yaw)
	_box(f, Vector3(1.0, 0.8, 0.06), _plain("Hearth Dark", Color(0.08, 0.06, 0.06), 0.9), pos + b * Vector3(0, 0.45, 0.24), yaw)
	_box(f, Vector3(2.1, 0.1, 0.62), _plain("Mantel Wood", Color(0.4, 0.25, 0.15), 0.6), pos + b * Vector3(0, 1.35, 0.04), yaw)
	_box(f, Vector3(2.0, 0.08, 0.7), stone, pos + b * Vector3(0, 0.04, 0.55), yaw)
	var flame := _plain("Fire Glow", Color(1.0, 0.5, 0.15), 0.5, 3.0)
	for k in 3:
		_ball(f, 0.14 - k * 0.02, flame, pos + b * Vector3(-0.2 + k * 0.2, 0.3, 0.2), Vector3(1, 1.6, 1))
	_box(f, Vector3(0.7, 0.08, 0.12), _plain("Log", Color(0.35, 0.22, 0.12), 0.9), pos + b * Vector3(0, 0.13, 0.2), yaw)
	# Things on the mantel: a clock and two candlesticks
	_box(f, Vector3(0.25, 0.3, 0.12), _plain("Mantel Clock", Color(0.55, 0.36, 0.2), 0.5), pos + b * Vector3(0, 1.55, 0.05), yaw)
	for sx in [-0.7, 0.7]:
		_cyl(f, 0.03, 0.04, 0.25, _plain("Candlestick", Color(0.85, 0.7, 0.35), 0.3, 0.0, 0.8), pos + b * Vector3(sx, 1.52, 0.05), 8)


static func _goods_shelf(f: Node3D, pos: Vector3, yaw: float, w: float, h: float, levels: int, cols: Array,
		both_sides := false, goods := "box") -> void:
	# A shop's shelving unit, its front towards +Z (turned by yaw), stacked with goods in cols: boxes, cans or jars
	var b := Basis(Vector3.UP, yaw)
	var d := 0.8 if both_sides else 0.45
	var frame := _plain("Shelf Frame", Color(0.85, 0.85, 0.82), 0.6)
	_box(f, Vector3(w, h, 0.04), frame, pos + b * Vector3(0, h / 2, 0.0 if both_sides else -d / 2 + 0.02), yaw)
	_collide(f, Vector3(w, h, d), pos + Vector3(0, h / 2, 0), yaw)
	for sx in [-1.0, 1.0]:
		_box(f, Vector3(0.04, h, d), frame, pos + b * Vector3(sx * (w / 2 - 0.02), h / 2, 0), yaw)
	var step := (h - 0.15) / levels
	var k := 0
	for lv in levels:
		var y := 0.1 + lv * step
		_box(f, Vector3(w, 0.03, d), frame, pos + b * Vector3(0, y, 0), yaw)
		for side in ([-1.0, 1.0] if both_sides else [1.0]):
			var x := -w / 2 + 0.16
			while x < w / 2 - 0.12:
				var c: Color = cols[k % cols.size()]
				k += 1
				var z: float = side * (d / 2 - 0.13) if both_sides else d / 2 - 0.18
				var at := pos + b * Vector3(x, y + 0.015, z)
				match goods:
					"can":
						_cyl(f, 0.06, 0.06, 0.16, _plain("Can", c, 0.35, 0.0, 0.5), at + Vector3(0, 0.08, 0), 10)
						x += 0.15
					"jar":
						_cyl(f, 0.07, 0.07, 0.2, _plain("Jar", c, 0.3), at + Vector3(0, 0.1, 0), 10)
						_cyl(f, 0.072, 0.072, 0.04, _plain("Jar Lid", Color(0.85, 0.75, 0.4), 0.3, 0.0, 0.7), at + Vector3(0, 0.21, 0), 10)
						x += 0.18
					_:
						var bh := 0.18 + 0.1 * float((k * 7) % 3) / 2.0
						_box(f, Vector3(0.2, bh, 0.24), _plain("Goods", c, 0.6), at + Vector3(0, bh / 2, 0), yaw)
						x += 0.24


static func _bookshelves(f: Node3D, xforms: Array, name := "Bookshelves") -> void:
	many(f, "bookshelf", xforms, name)
	for t: Transform3D in xforms:
		_collide(f, Vector3(1.2, 2.0, 0.36), t.origin + Vector3(0, 1.0, 0), t.basis.get_euler().y)


static func _armchairs(f: Node3D, xforms: Array) -> void:
	many(f, "armchair", xforms, "Armchairs")
	for t: Transform3D in xforms:
		_collide(f, Vector3(0.9, 0.45, 0.85), t.origin + Vector3(0, 0.225, 0), t.basis.get_euler().y)
		_collide(f, Vector3(0.9, 1.0, 0.2), t.origin + t.basis * Vector3(0, 0.5, -0.33), t.basis.get_euler().y)


static func _cat(f: Node3D, pos: Vector3, c: Color) -> void:
	# A cat curled up asleep
	var fur := _plain("Cat Fur", c, 0.9)
	_ball(f, 0.18, fur, pos + Vector3(0, 0.1, 0), Vector3(1.3, 0.65, 1))
	_ball(f, 0.09, fur, pos + Vector3(0.18, 0.12, 0.06))
	for ex in [-0.05, 0.05]:
		var ear := _cyl(f, 0.0, 0.035, 0.07, fur, pos + Vector3(0.2, 0.22, 0.06 + ex), 4)
		ear.rotation.z = -0.3
	var tail := _cyl(f, 0.025, 0.03, 0.35, fur, pos + Vector3(-0.05, 0.05, 0.16), 6)
	tail.rotation = Vector3(0, 0.6, PI / 2)


static func _cobweb(f: Node3D, corner: Vector3, sx: float, sz: float) -> void:
	# A pale cobweb across a top corner inside (threads fanning out from it)
	var web := _plain("Cobweb", Color(0.95, 0.95, 0.98), 0.5, 0.3)
	for k in 4:
		var a := PI / 2 * (k + 0.5) / 4.0
		var d := Vector3(-sx * sin(a) * 0.7, -cos(a) * 0.7, -sz * 0.0)
		var t := _box(f, Vector3(0.015, 0.9, 0.015), web, corner + d * 0.6 + Vector3(0, 0, -sz * 0.05))
		t.rotation.z = atan2(-d.x, d.y) + PI
	for r in [0.3, 0.6]:
		var ring := _box(f, Vector3(r * 1.2, 0.015, 0.015), web, corner + Vector3(-sx * r * 0.5, -r * 0.5, -sz * 0.05))
		ring.rotation.z = sx * PI / 4


static func _variant(f: Node3D) -> int:
	# Which way round a house is done (from its name, so it's the same every time)
	var g := f.get_parent().get_parent()
	return absi(String(g.name).hash()) if g else 0


# -----------------------------------------------------------------------------
# The rest of Stars Hollow's rooms
# -----------------------------------------------------------------------------
static func _bookshop(f: Node3D, size: Vector3) -> void:
	# Turn the Page Books: shelves all round, a reading nook with an armchair and a lamp, a table of staff picks, the
	# rolling ladder, and Mr. Page's counter with the shop cat asleep on it
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var wood := _plain("Bookshop Wood", Color(0.42, 0.27, 0.16), 0.6)
	var shelves := []
	for k in 7:
		shelves.append(_xf(Vector3(-3.6 + k * 1.2, 0, -hd + 0.19)))
	for z in [-2.1, -0.9, 0.3]:
		shelves.append(_xf(Vector3(-hw + 0.19, 0, z), PI / 2))
		shelves.append(_xf(Vector3(hw - 0.19, 0, z), -PI / 2))
	_bookshelves(f, shelves)
	# The rolling ladder on the back shelves
	var lad := _plain("Ladder Wood", Color(0.55, 0.38, 0.22), 0.6)
	for sx in [-0.22, 0.22]:
		var rail := _box(f, Vector3(0.05, 2.3, 0.05), lad, Vector3(-1.6 + sx, 1.1, -hd + 0.75))
		rail.rotation.x = -0.25
	for k in 7:
		_box(f, Vector3(0.44, 0.04, 0.05), lad, Vector3(-1.6, 0.2 + k * 0.3, -hd + 1.02 - k * 0.075))
	# The staff picks table in the middle
	_table(f, Vector3(0, 0, -0.6), 1.8, 0.9, 0.78, wood)
	var covers := [Color(0.62, 0.16, 0.16), Color(0.16, 0.32, 0.55), Color(0.85, 0.65, 0.2), Color(0.2, 0.45, 0.28),
		Color(0.45, 0.22, 0.5)]
	for k in 5:
		for j in 1 + k % 3:
			_box(f, Vector3(0.24, 0.05, 0.32), _plain("Book Cover", covers[(k + j) % 5], 0.6),
				Vector3(-0.7 + k * 0.35, 0.8 + j * 0.052, -0.6 + (0.1 if k % 2 else -0.1)), 0.1 * (j - k % 2))
	_label(f, "STAFF PICKS", Vector3(0, 1.25, -0.6), 20, Color(0.2, 0.15, 0.1)).outline_size = 0
	# The reading nook, front left
	_rug(f, Vector3(-2.5, 0, 1.6), 2.2, 1.8, Color(0.55, 0.2, 0.25))
	_armchairs(f, [_xf(Vector3(-3.2, 0, 1.4), PI / 2 + 0.3)])
	_lamp(f, Vector3(-3.7, 0, 2.5))
	_table(f, Vector3(-2.1, 0, 1.9), 0.5, 0.5, 0.5, wood)
	_cyl(f, 0.05, 0.04, 0.09, _plain("Teacup", Color(0.97, 0.97, 1.0), 0.4), Vector3(-2.1, 0.55, 1.9), 10)
	# The counter, front right, with the till and the shop cat
	_solid(f, Vector3(1.9, 1.0, 0.7), wood, Vector3(2.6, 0.5, 1.5))
	_box(f, Vector3(2.0, 0.05, 0.8), _plain("Counter Top", Color(0.3, 0.2, 0.12), 0.4), Vector3(2.6, 1.02, 1.5))
	_box(f, Vector3(0.4, 0.25, 0.3), _plain("Till", Color(0.25, 0.25, 0.28), 0.4, 0.0, 0.5), Vector3(3.1, 1.17, 1.4))
	_cat(f, Vector3(2.2, 1.05, 1.45), Color(0.95, 0.6, 0.25))
	_plant(f, Vector3(hw - 0.5, 0, hd - 0.5), 0.8)
	_label(f, "Read something new!", Vector3(0, 3.4, -hd + 0.06), 26, Color(0.3, 0.2, 0.1)).outline_size = 0


static func _market(f: Node3D, size: Vector3) -> void:
	# The Corner Market: two aisles of shelves, a long glowing fridge at the back, crates of apples and pumpkins by the
	# windows, and the till by the door (the shop spot)
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var bright := [Color(0.9, 0.25, 0.2), Color(0.95, 0.75, 0.2), Color(0.25, 0.55, 0.85), Color(0.3, 0.7, 0.35),
		Color(0.95, 0.55, 0.15), Color(0.7, 0.3, 0.65)]
	_goods_shelf(f, Vector3(0.6, 0, -0.9), PI / 2, 3.2, 1.6, 3, bright, true)
	_goods_shelf(f, Vector3(2.9, 0, -0.9), PI / 2, 3.2, 1.6, 3, bright.slice(2) + bright.slice(0, 2), true, "can")
	# The fridge along the back: glass doors glowing cold, bottles inside
	var fx := Vector3(0, 0, -hd + 0.35)
	_solid(f, Vector3(hw * 2 - 1.0, 2.1, 0.6), _plain("Fridge", Color(0.9, 0.92, 0.95), 0.4), fx + Vector3(0, 1.05, 0))
	_box(f, Vector3(hw * 2 - 1.2, 1.7, 0.03), _plain("Fridge Glow", Color(0.75, 0.9, 1.0), 0.15, 0.7), fx + Vector3(0, 1.1, 0.31))
	var drinks := [Color(0.9, 0.3, 0.3), Color(0.3, 0.75, 0.4), Color(0.95, 0.8, 0.3), Color(0.95, 0.95, 0.95)]
	for row in 3:
		for k in 16:
			_cyl(f, 0.045, 0.045, 0.22, _plain("Bottle", drinks[(k + row) % 4], 0.3), fx + Vector3(-3.6 + k * 0.48, 0.5 + row * 0.55, 0.2), 8)
	for k in 5:
		_box(f, Vector3(0.03, 1.7, 0.05), _plain("Fridge Frame", Color(0.7, 0.72, 0.75), 0.3, 0.0, 0.8), fx + Vector3(-3.6 + k * 1.8, 1.1, 0.33))
	# Crates of fruit and veg by the front window
	var crate := _plain("Crate Wood", Color(0.7, 0.52, 0.32), 0.85)
	var fruit := [[Color(0.85, 0.15, 0.15), 0.06], [Color(0.95, 0.55, 0.1), 0.06], [Color(0.95, 0.5, 0.12), 0.14],
		[Color(0.5, 0.75, 0.25), 0.06]]
	for k in 4:
		var at := Vector3(hw - 0.5, 0, -1.2 + k * 0.85)
		_solid(f, Vector3(0.7, 0.6, 0.7), crate, at + Vector3(0, 0.3, 0))
		var fr: Array = fruit[k]
		var r: float = fr[1]
		var n := 2 if r > 0.1 else 4
		for i in n:
			for j in n:
				_ball(f, r, _plain("Fruit", fr[0], 0.5), at + Vector3(-0.22 + i * 0.44 / max(n - 1, 1), 0.6 + r * 0.6, -0.22 + j * 0.44 / max(n - 1, 1)))
	# The till counter, front left, a gumball machine and the OPEN sign
	var counter := _plain("Market Counter", Color(0.25, 0.4, 0.6), 0.6)
	_solid(f, Vector3(2.0, 1.0, 0.7), counter, Vector3(-2.6, 0.5, 0.4))
	_box(f, Vector3(2.1, 0.05, 0.8), _plain("Counter Top Light", Color(0.92, 0.9, 0.85), 0.4), Vector3(-2.6, 1.02, 0.4))
	_box(f, Vector3(0.45, 0.28, 0.35), _plain("Till", Color(0.25, 0.25, 0.28), 0.4, 0.0, 0.5), Vector3(-3.1, 1.19, 0.35))
	_cyl(f, 0.06, 0.12, 0.5, _plain("Gumball Red", Color(0.85, 0.15, 0.15), 0.4), Vector3(-1.9, 1.3, 0.35), 10)
	var gum := StandardMaterial3D.new()
	gum.albedo_color = Color(0.9, 0.95, 1.0, 0.35)
	gum.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ball(f, 0.16, gum, Vector3(-1.9, 1.7, 0.35))
	for k in 6:
		_ball(f, 0.035, _plain("Gumball", bright[k], 0.3), Vector3(-1.95 + (k % 3) * 0.05, 1.62 + (k / 3) * 0.06, 0.33 + (k % 2) * 0.05))
	var open := _label(f, "OPEN", Vector3(-hw * 0.6, 2.3, hd - 0.02), 40, Color(1.0, 0.4, 0.5), PI)
	open.outline_modulate = Color(1.0, 0.65, 0.75)
	_label(f, "Fresh today!", Vector3(hw - 0.5, 1.5, 0.6), 22, Color(0.2, 0.3, 0.2), -PI / 2).outline_size = 0


static func _inn(f: Node3D, size: Vector3) -> void:
	# The Maple Inn's lobby: a reception desk with a bell and the room keys, armchairs round the fire, and a staircase
	# up to the rooms
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var wood := _plain("Inn Wood", Color(0.42, 0.26, 0.15), 0.55)
	# Reception, back right
	_solid(f, Vector3(3.0, 1.1, 0.7), wood, Vector3(2.8, 0.55, -1.9))
	_box(f, Vector3(3.1, 0.05, 0.8), _plain("Counter Top", Color(0.3, 0.2, 0.12), 0.4), Vector3(2.8, 1.12, -1.9))
	_cyl(f, 0.08, 0.1, 0.07, _plain("Bell Brass", Color(0.9, 0.72, 0.3), 0.25, 0.0, 0.9), Vector3(2.0, 1.18, -1.75), 12)
	_box(f, Vector3(0.45, 0.04, 0.32), _plain("Guest Book", Color(0.55, 0.15, 0.2), 0.6), Vector3(3.0, 1.16, -1.8), 0.2)
	_box(f, Vector3(1.6, 0.9, 0.05), wood, Vector3(2.8, 2.1, -hd + 0.03))
	for k in 8:
		_cyl(f, 0.02, 0.02, 0.12, _plain("Key Gold", Color(0.95, 0.78, 0.3), 0.3, 0.0, 0.9),
			Vector3(2.2 + (k % 4) * 0.4, 2.3 - (k / 4) * 0.4, -hd + 0.08), 6)
	_label(f, "WELCOME", Vector3(2.8, 2.8, -hd + 0.06), 28, Color(0.35, 0.2, 0.12)).outline_size = 0
	# The fire on the left wall, two armchairs and a rug in front of it
	_fireplace(f, Vector3(-hw + 0.25, 0, 0.6), PI / 2)
	_rug(f, Vector3(-2.6, 0, 0.6), 2.6, 2.4, Color(0.3, 0.4, 0.55))
	_armchairs(f, [_xf(Vector3(-2.0, 0, -0.5), -0.6), _xf(Vector3(-2.0, 0, 1.8), PI + 0.6)])
	_table(f, Vector3(-2.6, 0, 0.6), 0.7, 0.7, 0.45, wood)
	_cyl(f, 0.08, 0.1, 0.16, _plain("Teapot", Color(0.95, 0.95, 0.97), 0.35), Vector3(-2.6, 0.53, 0.6), 12)
	# The stairs up the back wall to a landing and the rooms' door
	var step_m := _plain("Stair Wood", Color(0.5, 0.32, 0.2), 0.6)
	var sz := -hd + 0.55
	for k in 15:
		var top := 0.2 * (k + 1)
		_solid(f, Vector3(0.28, top, 1.0), step_m, Vector3(0.9 - k * 0.28, top / 2, sz))
	var land_x := -hw + 0.75
	_solid(f, Vector3(1.5, 3.0, 1.0), step_m, Vector3(land_x, 1.5, sz))
	var rail := _plain("Banister", Color(0.3, 0.18, 0.1), 0.5)
	for k in 6:
		_box(f, Vector3(0.05, 0.9, 0.05), rail, Vector3(0.9 - k * 0.8, 0.2 * (k * 0.8 / 0.28 + 1) + 0.45, sz + 0.47))
	var hand := _box(f, Vector3(4.4, 0.06, 0.08), rail, Vector3(-1.2, 2.0, sz + 0.47))
	hand.rotation.z = -atan(0.2 / 0.28)
	_box(f, Vector3(1.0, 2.1, 0.06), _plain("Room Door", Color(0.55, 0.2, 0.25), 0.6), Vector3(land_x, 4.05, -hd + 0.04))
	_label(f, "Rooms", Vector3(land_x, 5.3, -hd + 0.06), 26, Color(0.35, 0.2, 0.12)).outline_size = 0
	_picture(f, Vector3(-2.8, 3.0, -hd + 0.03), 0.0, 1.0, 0.7, Color(0.55, 0.75, 0.9))
	_plant(f, Vector3(hw - 0.5, 0, hd - 0.6))
	_plant(f, Vector3(-hw + 0.5, 0, hd - 0.6), 0.8)
	# A chandelier
	_cyl(f, 0.5, 0.3, 0.25, _plain("Chandelier", Color(1.0, 0.88, 0.6), 0.3, 1.5), Vector3(0, size.y - 1.2, 0.5), 16)


static func _antiques(f: Node3D, size: Vector3) -> void:
	# Cobweb Corner Antiques: a jumble of old things. A grandfather clock that still swings, cabinets, a gramophone, old
	# trunks, mirrors, a rocking horse, a crystal ball, paintings and (of course) cobwebs
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var dark := _plain("Antique Wood", Color(0.32, 0.2, 0.12), 0.5)
	var gold := _plain("Antique Gold", Color(0.85, 0.66, 0.3), 0.3, 0.0, 0.8)
	_rug(f, Vector3(0, 0, 0), 4.0, 3.0, Color(0.5, 0.15, 0.2))
	# The grandfather clock, back left
	var cx := Vector3(-hw + 0.5, 0, -hd + 0.4)
	_solid(f, Vector3(0.6, 2.3, 0.4), dark, cx + Vector3(0, 1.15, 0))
	_cyl(f, 0.22, 0.22, 0.04, _plain("Clock Face", Color(0.95, 0.92, 0.82), 0.5), cx + Vector3(0, 1.9, 0.21), 16).rotation.x = PI / 2
	var pend := Node3D.new()
	pend.name = "Pendulum"
	pend.position = cx + Vector3(0, 1.5, 0.21)
	pend.set_script(load("res://scripts/pendulum_swing.gd"))
	f.add_child(pend)
	_box(pend, Vector3(0.02, 0.6, 0.02), gold, Vector3(0, -0.3, 0))
	_cyl(pend, 0.08, 0.08, 0.02, gold, Vector3(0, -0.62, 0)).rotation.x = PI / 2
	# Cabinets of curiosities along the right wall (the bookcases), and the counter at the back
	_bookshelves(f, [_xf(Vector3(hw - 0.19, 0, -1.5), -PI / 2), _xf(Vector3(hw - 0.19, 0, -0.3), -PI / 2),
		_xf(Vector3(-0.6, 0, -hd + 0.19))], "Cabinets")
	_solid(f, Vector3(2.0, 1.0, 0.6), dark, Vector3(1.8, 0.5, -hd + 0.6))
	_box(f, Vector3(0.45, 0.35, 0.35), gold, Vector3(2.2, 1.18, -hd + 0.55))         # the old brass till
	# The gramophone on a little table, and an armchair to listen in
	_table(f, Vector3(-2.6, 0, 0.4), 0.6, 0.6, 0.75, dark)
	_box(f, Vector3(0.35, 0.18, 0.35), dark, Vector3(-2.6, 0.84, 0.4))
	var horn := _cyl(f, 0.3, 0.03, 0.55, gold, Vector3(-2.45, 1.15, 0.3), 16)
	horn.rotation = Vector3(0.9, 0, -0.5)
	_armchairs(f, [_xf(Vector3(-1.4, 0, 1.4), PI + 0.8)])
	# Old trunks, a rocking horse, a mirror and a dressmaker's dummy
	for k in 2:
		var t := Vector3(-hw + 0.6, 0, 1.0 + k * 1.0)
		_solid(f, Vector3(0.9, 0.5 - k * 0.1, 0.6), _plain("Trunk", [Color(0.45, 0.3, 0.2), Color(0.25, 0.35, 0.45)][k], 0.7),
			t + Vector3(0, (0.5 - k * 0.1) / 2, 0), PI / 2)
		_box(f, Vector3(0.62, 0.06, 0.92), gold, t + Vector3(0, 0.5 - k * 0.1, 0))
	var horse := _plain("Rocking Horse", Color(0.92, 0.88, 0.8), 0.6)
	var hp := Vector3(1.4, 0, 1.8)
	_ball(f, 0.25, horse, hp + Vector3(0, 0.6, 0), Vector3(1.6, 0.8, 0.7))
	_ball(f, 0.14, horse, hp + Vector3(0.38, 0.85, 0), Vector3(1.3, 1, 0.8))
	_box(f, Vector3(1.2, 0.06, 0.08), _plain("Rocker Red", Color(0.7, 0.15, 0.15), 0.6), hp + Vector3(0, 0.05, -0.18))
	_box(f, Vector3(1.2, 0.06, 0.08), _plain("Rocker Red", Color(0.7, 0.15, 0.15), 0.6), hp + Vector3(0, 0.05, 0.18))
	for sx in [-0.3, 0.3]:
		_box(f, Vector3(0.05, 0.45, 0.05), horse, hp + Vector3(sx, 0.3, 0))
	_box(f, Vector3(0.7, 1.6, 0.06), gold, Vector3(hw - 0.05, 1.4, 1.0), PI / 2)
	_box(f, Vector3(0.6, 1.5, 0.02), _plain("Mirror", Color(0.8, 0.88, 0.92), 0.05, 0.0, 1.0), Vector3(hw - 0.09, 1.4, 1.0), PI / 2)
	_ball(f, 0.25, _plain("Dummy", Color(0.85, 0.75, 0.6), 0.7), Vector3(0.4, 1.3, -1.6), Vector3(1, 1.5, 0.8))
	_cyl(f, 0.03, 0.03, 1.0, dark, Vector3(0.4, 0.5, -1.6), 6)
	# The crystal ball on its stand, glowing a little
	_cyl(f, 0.12, 0.18, 0.6, dark, Vector3(-0.6, 0.3, 0.6), 10)
	_ball(f, 0.17, _plain("Crystal Ball", Color(0.6, 0.5, 0.9), 0.05, 1.2), Vector3(-0.6, 0.77, 0.6))
	for k in 3:
		_picture(f, Vector3(-2.6 + k * 1.6, 3.2, -hd + 0.03), 0.0, 0.8, 0.6, [Color(0.4, 0.55, 0.4), Color(0.7, 0.55, 0.35),
			Color(0.45, 0.45, 0.65)][k])
	var h := size.y - 0.3
	_cobweb(f, Vector3(-hw, h, -hd + 0.05), -1.0, -1.0)
	_cobweb(f, Vector3(hw, h, -hd + 0.05), 1.0, -1.0)
	_lamp(f, Vector3(hw - 0.5, 0, hd - 0.5))


static func _hardware(f: Node3D, size: Vector3) -> void:
	# Nuts & Bolts Hardware: aisles of tools, paint cans in a pyramid, a pegboard of tools, ladders, a wheelbarrow and
	# Hank's counter with the key cutter
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var tools := [Color(0.85, 0.35, 0.15), Color(0.3, 0.3, 0.32), Color(0.95, 0.75, 0.2), Color(0.25, 0.5, 0.75),
		Color(0.4, 0.6, 0.3)]
	_goods_shelf(f, Vector3(-3.0, 0, -0.8), PI / 2, 4.0, 1.9, 4, tools, true)
	_goods_shelf(f, Vector3(3.0, 0, -0.8), PI / 2, 4.0, 1.9, 4, tools.slice(1) + tools.slice(0, 1), true, "jar")
	# The pegboard along the back with hammers, saws, spanners and screwdrivers on it
	var peg := _plain("Pegboard", Color(0.78, 0.62, 0.42), 0.8)
	_box(f, Vector3(hw * 2 - 1.0, 1.8, 0.04), peg, Vector3(0, 1.8, -hd + 0.03))
	var metal := _plain("Tool Steel", Color(0.7, 0.72, 0.75), 0.3, 0.0, 0.9)
	var handle := _plain("Tool Handle", Color(0.85, 0.35, 0.15), 0.5)
	for k in 14:
		var x := -hw + 1.0 + k * (hw * 2 - 2.0) / 13.0
		var y := 2.2 if k % 2 == 0 else 1.5
		match k % 4:
			0:
				_box(f, Vector3(0.05, 0.35, 0.04), handle, Vector3(x, y, -hd + 0.08))
				_box(f, Vector3(0.18, 0.06, 0.05), metal, Vector3(x, y + 0.18, -hd + 0.08))
			1:
				_box(f, Vector3(0.45, 0.14, 0.01), metal, Vector3(x, y, -hd + 0.07))
				_box(f, Vector3(0.12, 0.16, 0.04), handle, Vector3(x + 0.27, y + 0.02, -hd + 0.08))
			2:
				_box(f, Vector3(0.04, 0.38, 0.02), metal, Vector3(x, y, -hd + 0.07))
			_:
				_box(f, Vector3(0.04, 0.2, 0.04), _plain("Tool Handle Yellow", Color(0.95, 0.8, 0.2), 0.5), Vector3(x, y + 0.1, -hd + 0.08))
				_box(f, Vector3(0.015, 0.18, 0.015), metal, Vector3(x, y - 0.08, -hd + 0.08))
	_label(f, "TOOLS", Vector3(0, 3.0, -hd + 0.06), 34, Color(0.85, 0.35, 0.15))
	# A pyramid of paint cans by the front, and paint chips on the wall
	var paints := [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.8), Color(0.95, 0.85, 0.3), Color(0.35, 0.65, 0.35)]
	for row in 3:
		for k in 3 - row:
			_cyl(f, 0.15, 0.15, 0.3, _plain("Paint Can", paints[(k + row) % 4], 0.35, 0.0, 0.4),
				Vector3(-hw + 0.8 + k * 0.32 + row * 0.16, 0.15 + row * 0.3, hd - 1.2), 12)
	for k in 12:
		_box(f, Vector3(0.12, 0.2, 0.01), _plain("Paint Chip", Color.from_hsv(k / 12.0, 0.55, 0.9), 0.8),
			Vector3(-hw + 0.02, 1.4 + (k / 6) * 0.25, 0.4 + (k % 6) * 0.16), PI / 2)
	# Ladders against the right wall and a wheelbarrow
	var lad := _plain("Ladder Metal", Color(0.75, 0.78, 0.8), 0.3, 0.0, 0.8)
	for n in 2:
		var lz := 1.6 + n * 0.8
		for sz in [-0.2, 0.2]:
			var r := _box(f, Vector3(0.05, 2.4, 0.05), lad, Vector3(hw - 0.35, 1.18, lz + sz))
			r.rotation.z = 0.15
		for k in 7:
			_box(f, Vector3(0.04, 0.04, 0.4), lad, Vector3(hw - 0.17 - k * 0.045, 0.25 + k * 0.3, lz))
	var barrow := _plain("Wheelbarrow Green", Color(0.3, 0.55, 0.3), 0.5, 0.0, 0.3)
	_box(f, Vector3(0.7, 0.3, 0.9), barrow, Vector3(1.2, 0.55, hd - 1.2), 0.3)
	_cyl(f, 0.15, 0.15, 0.08, _plain("Tyre", Color(0.08, 0.08, 0.09), 0.9), Vector3(1.0, 0.15, hd - 1.7), 12).rotation.z = PI / 2
	# Hank's counter by the door, with the key cutter
	var counter := _plain("Hardware Counter", Color(0.85, 0.35, 0.15), 0.6)
	_solid(f, Vector3(2.2, 1.0, 0.7), counter, Vector3(3.2, 0.5, 2.2))
	_box(f, Vector3(2.3, 0.05, 0.8), _plain("Counter Top Light", Color(0.92, 0.9, 0.85), 0.4), Vector3(3.2, 1.02, 2.2))
	_box(f, Vector3(0.4, 0.3, 0.3), metal, Vector3(2.6, 1.2, 2.15))
	_box(f, Vector3(0.45, 0.28, 0.35), _plain("Till", Color(0.25, 0.25, 0.28), 0.4, 0.0, 0.5), Vector3(3.7, 1.19, 2.15))


static func _fire_station(f: Node3D, size: Vector3) -> void:
	# Fire Station No. 1 from inside: the fire pole down from the bunks, helmets and coats on their hooks with boots
	# underneath, a hose reel, the crew's kitchen table with a pot of chili, and Sparky the station dog in his basket
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var red := _plain("Fire Red", Color(0.85, 0.12, 0.12), 0.4)
	var yellow := _plain("Fire Yellow", Color(0.95, 0.8, 0.15), 0.6)
	var brass := _plain("Pole Brass", Color(0.92, 0.75, 0.35), 0.15, 0.0, 1.0)
	# Yellow lines on the floor where the truck parks (it's out front)
	for sx in [-1.0, 1.0]:
		_box(f, Vector3(0.15, 0.015, 7.0), yellow, Vector3(sx * 1.6 + 2.6, 0.05, 0.5))
	# The fire pole, back left, down through a hole in the ceiling
	var pole := Vector3(-3.6, 0, -3.4)
	_cyl(f, 0.06, 0.06, size.y, brass, pole + Vector3(0, size.y / 2, 0), 12)
	_cyl(f, 0.6, 0.6, 0.03, _plain("Pole Hole", Color(0.05, 0.05, 0.06), 0.9), pole + Vector3(0, size.y - 0.23, 0), 16)
	_cyl(f, 0.7, 0.7, 0.06, _plain("Pole Mat", Color(0.15, 0.15, 0.18), 0.9), pole + Vector3(0, 0.07, 0), 16)
	_collide(f, Vector3(0.14, size.y, 0.14), pole + Vector3(0, size.y / 2, 0))
	# Coats and helmets on hooks along the left wall, boots below
	var coat := _plain("Fire Coat", Color(0.75, 0.55, 0.2), 0.8)
	for k in 5:
		var z := -1.8 + k * 1.0
		_box(f, Vector3(0.12, 1.0, 0.6), coat, Vector3(-hw + 0.12, 1.3, z))
		_box(f, Vector3(0.13, 0.06, 0.62), yellow, Vector3(-hw + 0.13, 1.1, z))
		_ball(f, 0.18, red, Vector3(-hw + 0.25, 2.05, z), Vector3(1, 0.7, 1.2))
		for bz in [-0.12, 0.12]:
			_box(f, Vector3(0.28, 0.32, 0.14), _plain("Boot", Color(0.12, 0.12, 0.13), 0.7), Vector3(-hw + 0.3, 0.16, z + bz))
	_label(f, "CREW", Vector3(-hw + 0.04, 2.6, 0.2), 30, Color(0.85, 0.12, 0.12), PI / 2).outline_size = 0
	# A hose reel on the back wall
	var reel := _cyl(f, 0.55, 0.55, 0.35, red, Vector3(1.6, 1.4, -hd + 0.25), 20)
	reel.rotation.x = PI / 2
	var hose := _cyl(f, 0.45, 0.45, 0.37, _plain("Hose", Color(0.85, 0.85, 0.8), 0.7), Vector3(1.6, 1.4, -hd + 0.25), 20)
	hose.rotation.x = PI / 2
	# The crew's table with the chili pot, back right
	var wood := _plain("Kitchen Wood", Color(0.55, 0.38, 0.24), 0.6)
	_table(f, Vector3(3.8, 0, -2.4), 2.0, 1.0, 0.78, wood)
	for sx in [-0.6, 0.6]:
		_chair(f, Vector3(3.8 + sx, 0, -1.6), PI, wood)
		_chair(f, Vector3(3.8 + sx, 0, -3.2), 0.0, wood)
	_cyl(f, 0.2, 0.18, 0.25, _plain("Pot Steel", Color(0.6, 0.62, 0.65), 0.3, 0.0, 0.8), Vector3(3.8, 0.92, -2.4), 14)
	_cyl(f, 0.17, 0.17, 0.02, _plain("Chili", Color(0.7, 0.2, 0.1), 0.6), Vector3(3.8, 1.04, -2.4), 14)
	# Sparky in his basket
	var dog := _plain("Dalmatian", Color(0.97, 0.97, 0.95), 0.8)
	var spot := _plain("Dalmatian Spot", Color(0.08, 0.08, 0.09), 0.8)
	var bp := Vector3(hw - 0.9, 0, 2.6)
	_cyl(f, 0.6, 0.5, 0.25, _plain("Basket", Color(0.7, 0.5, 0.3), 0.9), bp + Vector3(0, 0.12, 0), 16)
	_ball(f, 0.3, dog, bp + Vector3(0, 0.38, 0), Vector3(1.4, 0.7, 0.9))
	_ball(f, 0.16, dog, bp + Vector3(-0.42, 0.42, 0.05))
	for k in 5:
		_ball(f, 0.05, spot, bp + Vector3(-0.25 + k * 0.12, 0.52, -0.1 + (k % 2) * 0.2), Vector3(1, 0.4, 1))
	for ez in [-0.1, 0.1]:
		_ball(f, 0.06, spot, bp + Vector3(-0.45, 0.5, 0.05 + ez), Vector3(0.6, 1.3, 0.6))
	_label(f, "SPARKY", Vector3(hw - 0.9, 0.35, 3.25), 16, Color(0.3, 0.2, 0.1)).outline_size = 0
	# Two worn armchairs by Sparky, for the crew's naps between calls
	_armchairs(f, [Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(hw - 0.7, 0, 0.9)),
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(hw - 0.7, 0, -0.3))])
	# The station's chalkboard
	_box(f, Vector3(2.0, 1.1, 0.05), _plain("Chalkboard", Color(0.15, 0.22, 0.18), 0.9), Vector3(-1.2, 2.0, -hd + 0.03))
	_label(f, "TODAY\nCat up a tree (again)\nChili night!", Vector3(-1.2, 2.0, -hd + 0.07), 20, Color(0.95, 0.95, 0.9)).outline_size = 0


static func _school(f: Node3D, size: Vector3) -> void:
	# Old Oak Elementary's big classroom: rows of desks facing the chalkboard, the teacher's desk with an apple on it,
	# a reading corner with beanbags on the left, an art corner with easels and drawings on the right, cubbies with
	# backpacks, the alphabet along the top of the board, a globe and a clock
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var wood := _plain("School Wood", Color(0.62, 0.45, 0.28), 0.6)
	# The chalkboard and the alphabet
	_box(f, Vector3(8.0, 2.2, 0.06), _plain("Chalkboard", Color(0.15, 0.22, 0.18), 0.9), Vector3(0, 2.3, -hd + 0.04))
	_box(f, Vector3(8.2, 0.08, 0.15), wood, Vector3(0, 1.17, -hd + 0.1))
	_label(f, "Good morning, class!\n2 + 2 = 4", Vector3(-1.5, 2.6, -hd + 0.08), 36, Color(0.95, 0.95, 0.9)).outline_size = 0
	_label(f, "A  B  C  D  E  F  G  H  I  J  K  L  M  N  O  P  Q  R  S  T  U  V  W  X  Y  Z", Vector3(0, 4.0, -hd + 0.04),
		30, Color(0.85, 0.3, 0.25)).outline_size = 0
	# The clock above the door, inside
	_cyl(f, 0.35, 0.35, 0.06, _plain("Clock Face", Color(0.95, 0.92, 0.82), 0.5), Vector3(0, 3.6, hd - 0.04), 20).rotation.x = PI / 2
	# The teacher's desk and the class's desks (baked; one draw for all of them)
	_solid(f, Vector3(1.8, 0.78, 0.8), wood, Vector3(-4.6, 0.39, -hd + 1.6))
	_ball(f, 0.07, _plain("Apple", Color(0.85, 0.15, 0.15), 0.4), Vector3(-4.2, 0.85, -hd + 1.5))
	_chair(f, Vector3(-4.6, 0, -hd + 2.3), PI, wood)
	var desks := []
	for row in 4:
		for col in 6:
			var x := -6.25 + col * 2.5
			desks.append(_xf(Vector3(x, 0, -2.4 + row * 1.7), PI))
	many(f, "school_desk", desks, "Desks")
	for t: Transform3D in desks:
		_collide(f, Vector3(0.7, 0.76, 0.5), t.origin + Vector3(0, 0.38, 0))
	# The reading corner, left: bookcases, a rug and beanbags
	_bookshelves(f, [_xf(Vector3(-hw + 0.19, 0, -2.0), PI / 2), _xf(Vector3(-hw + 0.19, 0, -0.8), PI / 2),
		_xf(Vector3(-hw + 1.4, 0, -hd + 0.19))])
	_rug(f, Vector3(-10.0, 0, 0.0), 3.6, 3.6, Color(0.3, 0.55, 0.75))
	var bags := [Color(0.9, 0.4, 0.3), Color(0.95, 0.8, 0.3), Color(0.5, 0.75, 0.4), Color(0.6, 0.45, 0.8)]
	for k in 4:
		_ball(f, 0.38, _plain("Beanbag", bags[k], 0.9), Vector3(-10.8 + (k % 2) * 1.4, 0.25, -0.8 + (k / 2) * 1.5),
			Vector3(1.1, 0.65, 1.1))
	_label(f, "Reading Corner", Vector3(-10.0, 3.2, -hd + 0.06), 34, Color(0.2, 0.4, 0.6)).outline_size = 0
	# The art corner, right: easels, a paint table and the class's drawings
	var easel := _plain("Easel Wood", Color(0.7, 0.55, 0.35), 0.7)
	for k in 3:
		var e := Vector3(8.6 + k * 1.4, 0, -1.0)
		for sx in [-0.3, 0.3]:
			_box(f, Vector3(0.05, 1.6, 0.05), easel, e + Vector3(sx, 0.8, 0)).rotation.z = -sx * 0.25
		_box(f, Vector3(0.75, 0.6, 0.03), _plain("Canvas", Color(0.97, 0.96, 0.93), 0.9), e + Vector3(0, 1.25, 0.06))
		_ball(f, 0.12, _plain("Paint Blob", bags[k], 0.6), e + Vector3(0, 1.3, 0.08), Vector3(1, 1, 0.1))
	_table(f, Vector3(10.0, 0, 1.6), 2.0, 1.0, 0.6, wood)
	for k in 4:
		_cyl(f, 0.06, 0.06, 0.1, _plain("Paint Pot", bags[k], 0.4), Vector3(9.4 + k * 0.4, 0.65, 1.6), 10)
	for k in 8:
		var c := Color.from_hsv(k / 8.0, 0.45, 0.95)
		var d := _box(f, Vector3(0.6, 0.45, 0.02), _plain("Drawing", c, 0.9), Vector3(7.6 + (k % 4) * 1.15, 2.6 + (k / 4) * 0.7, -hd + 0.03))
		d.rotation.z = 0.06 * (k % 3 - 1)
	_label(f, "Art Corner", Vector3(9.3, 3.8, -hd + 0.06), 34, Color(0.75, 0.3, 0.45)).outline_size = 0
	# Cubbies with backpacks along the right wall
	_solid(f, Vector3(0.45, 1.2, 4.0), wood, Vector3(hw - 0.25, 0.6, 3.6))
	for k in 6:
		_box(f, Vector3(0.25, 0.35, 0.4), _plain("Backpack", bags[k % 4], 0.8), Vector3(hw - 0.55, 1.4, 2.0 + k * 0.62))
	# A globe on the teacher's side
	_cyl(f, 0.04, 0.12, 0.8, wood, Vector3(-6.0, 0.4, -hd + 1.0), 8)
	_ball(f, 0.25, _plain("Globe", Color(0.3, 0.55, 0.85), 0.5), Vector3(-6.0, 1.05, -hd + 1.0))
	_ball(f, 0.2, _plain("Globe Land", Color(0.4, 0.7, 0.35), 0.6), Vector3(-5.92, 1.1, -hd + 1.06), Vector3(1, 0.7, 0.9))
	_plant(f, Vector3(hw - 0.6, 0, -hd + 0.6))
	_plant(f, Vector3(-hw + 0.6, 0, hd - 0.6))


static func _home(f: Node3D, size: Vector3) -> void:
	# A family's front room: a kitchen along the back (cupboards, a stove, the fridge), a table and chairs, a sofa of
	# two armchairs round a rug, the fireplace on a side wall, a bookcase, a lamp and pictures. Which side each goes
	# on, and the colours, change from house to house.
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var v := _variant(f)
	var sx := 1.0 if v % 2 == 0 else -1.0                # kitchen on the left or the right
	var fronts := [Color(0.95, 0.94, 0.9), Color(0.55, 0.7, 0.62), Color(0.55, 0.65, 0.8), Color(0.9, 0.82, 0.6)]
	var front := _plain("Kitchen Front", fronts[v % fronts.size()], 0.6)
	var top := _plain("Kitchen Top", Color(0.3, 0.28, 0.27), 0.4)
	var wood := _plain("Home Wood", Color(0.5, 0.33, 0.2), 0.6)
	# The kitchen along the back, one side
	var kx := -sx * (hw - 1.7)
	_solid(f, Vector3(3.2, 0.9, 0.6), front, Vector3(kx, 0.45, -hd + 0.3))
	_box(f, Vector3(3.3, 0.05, 0.65), top, Vector3(kx, 0.92, -hd + 0.32))
	_box(f, Vector3(3.2, 0.7, 0.35), front, Vector3(kx, 2.0, -hd + 0.18))
	_box(f, Vector3(0.6, 0.02, 0.5), _plain("Stove Black", Color(0.08, 0.08, 0.09), 0.5), Vector3(kx + sx * 0.6, 0.955, -hd + 0.3))
	for k in 2:
		_cyl(f, 0.09, 0.09, 0.01, _plain("Burner Glow", Color(1.0, 0.35, 0.15), 0.5, 1.5), Vector3(kx + sx * (0.45 + k * 0.3), 0.97, -hd + 0.3), 12)
	_cyl(f, 0.14, 0.12, 0.18, _plain("Pot Red", Color(0.8, 0.2, 0.15), 0.4), Vector3(kx + sx * 0.45, 1.06, -hd + 0.3), 12)
	_solid(f, Vector3(0.8, 1.9, 0.65), _plain("Fridge", Color(0.9, 0.92, 0.95), 0.4), Vector3(kx - sx * 2.05, 0.95, -hd + 0.33))
	for k in 3:                                          # drawings stuck on the fridge
		_box(f, Vector3(0.18, 0.22, 0.01), _plain("Fridge Drawing", Color.from_hsv((v % 7 + k * 2) / 7.0, 0.45, 0.95), 0.9),
			Vector3(kx - sx * 2.05 + (k - 1) * 0.22, 1.4, -hd + 0.66))
	# The table and chairs in front of the kitchen
	var tx := kx + sx * 0.2
	_table(f, Vector3(tx, 0, -0.6), 1.3, 0.8, 0.76, wood)
	for cx in [-0.35, 0.35]:
		_chair(f, Vector3(tx + cx, 0, -1.2), 0.0, wood)
		_chair(f, Vector3(tx + cx, 0, 0.0), PI, wood)
	_cyl(f, 0.12, 0.08, 0.12, _plain("Fruit Bowl", Color(0.95, 0.95, 0.97), 0.4), Vector3(tx, 0.82, -0.6), 12)
	for k in 3:
		_ball(f, 0.05, _plain("Fruit", [Color(0.85, 0.15, 0.15), Color(0.95, 0.55, 0.1), Color(0.5, 0.75, 0.25)][k], 0.5),
			Vector3(tx - 0.05 + k * 0.05, 0.9, -0.6 + (k % 2) * 0.04))
	# The sitting side: the fireplace on the side wall, two armchairs, a rug and a coffee table, a bookcase, a lamp
	var lx := sx * (hw - 1.6)
	_fireplace(f, Vector3(sx * (hw - 0.25), 0, -0.6), -sx * PI / 2)
	_rug(f, Vector3(lx, 0, -0.2), 2.2, 2.6, Color.from_hsv((v % 5) / 5.0, 0.45, 0.6))
	_armchairs(f, [_xf(Vector3(lx - sx * 0.8, 0, 0.9), PI + sx * 0.5), _xf(Vector3(lx - sx * 0.9, 0, -1.4), sx * 0.7)])
	_table(f, Vector3(lx - sx * 0.2, 0, -0.2), 0.8, 0.5, 0.42, wood)
	_bookshelves(f, [_xf(Vector3(sx * (hw - 0.8), 0, -hd + 0.19))])
	_lamp(f, Vector3(sx * (hw - 0.4), 0, 1.6))
	_picture(f, Vector3(sx * (hw - 0.02), 1.9, -0.6), -sx * PI / 2, 0.9, 0.6, Color.from_hsv((v % 9) / 9.0, 0.35, 0.85))
	_plant(f, Vector3(-sx * (hw - 0.5), 0, hd - 0.5), 0.8)
	if v % 3 == 0:
		_cat(f, Vector3(lx, 0.06, -0.2 + 0.9), Color(0.3, 0.3, 0.32))


static func _palmer(f: Node3D, size: Vector3) -> void:
	# Mr. Palmer's front room: tidy, with tea everywhere. His armchair by the fire, a tea trolley, a cabinet of teacups,
	# a grandfather clock, the town's map on the wall, his own portrait (he chose the frame) and a pile of letters in
	# lilac envelopes on his writing desk
	var hw := size.x / 2.0 - WALL
	var hd := size.z / 2.0 - WALL
	var wood := _plain("Palmer Wood", Color(0.36, 0.22, 0.13), 0.5)
	_fireplace(f, Vector3(-hw + 0.25, 0, -0.6), PI / 2)
	_rug(f, Vector3(-2.2, 0, -0.4), 2.4, 2.8, Color(0.25, 0.4, 0.32))
	_armchairs(f, [_xf(Vector3(-1.6, 0, -1.6), -0.7), _xf(Vector3(-1.6, 0, 0.8), PI + 0.7)])
	# The tea trolley
	_table(f, Vector3(-2.3, 0, -0.4), 0.8, 0.5, 0.6, _plain("Trolley Brass", Color(0.85, 0.68, 0.32), 0.3, 0.0, 0.8))
	_cyl(f, 0.09, 0.11, 0.18, _plain("Teapot", Color(0.95, 0.95, 0.97), 0.35), Vector3(-2.4, 0.71, -0.4), 12)
	for k in 3:
		_cyl(f, 0.045, 0.035, 0.07, _plain("Teacup", Color(0.97, 0.97, 1.0), 0.4), Vector3(-2.05 - k * 0.15, 0.66, -0.25 + k * 0.08), 10)
	# The cabinet of teacups and the grandfather clock along the back
	_solid(f, Vector3(1.6, 2.0, 0.45), wood, Vector3(1.6, 1.0, -hd + 0.25))
	for row in 3:
		_box(f, Vector3(1.4, 0.03, 0.35), _plain("Cabinet Shelf", Color(0.85, 0.8, 0.7), 0.6), Vector3(1.6, 0.8 + row * 0.42, -hd + 0.3))
		for k in 5:
			_cyl(f, 0.045, 0.035, 0.07, _plain("Teacup Blue", Color(0.75, 0.85, 0.95), 0.4), Vector3(1.0 + k * 0.3, 0.86 + row * 0.42, -hd + 0.38), 10)
	var cx := Vector3(3.2, 0, -hd + 0.3)
	_solid(f, Vector3(0.55, 2.2, 0.35), wood, cx + Vector3(0, 1.1, 0))
	_cyl(f, 0.2, 0.2, 0.04, _plain("Clock Face", Color(0.95, 0.92, 0.82), 0.5), cx + Vector3(0, 1.8, 0.19), 16).rotation.x = PI / 2
	var pend := Node3D.new()
	pend.name = "Pendulum"
	pend.position = cx + Vector3(0, 1.45, 0.19)
	pend.set_script(load("res://scripts/pendulum_swing.gd"))
	f.add_child(pend)
	_box(pend, Vector3(0.02, 0.55, 0.02), _plain("Antique Gold", Color(0.85, 0.66, 0.3), 0.3, 0.0, 0.8), Vector3(0, -0.28, 0))
	# His writing desk by the window with the lilac letters, and his portrait and the town map
	_table(f, Vector3(2.4, 0, 1.6), 1.2, 0.6, 0.76, wood)
	_chair(f, Vector3(2.4, 0, 1.0), 0.0, wood)
	for k in 4:
		_box(f, Vector3(0.24, 0.01, 0.16), _plain("Lilac Envelope", Color(0.8, 0.7, 0.95), 0.8),
			Vector3(2.1 + (k % 2) * 0.05, 0.77 + k * 0.012, 1.55 - (k % 2) * 0.04), 0.15 * k)
	_cyl(f, 0.04, 0.035, 0.08, _plain("Teacup", Color(0.97, 0.97, 1.0), 0.4), Vector3(2.8, 0.8, 1.55), 10)
	_picture(f, Vector3(-1.0, 2.2, -hd + 0.03), 0.0, 0.7, 0.9, Color(0.75, 0.6, 0.5))
	_ball(f, 0.14, _plain("Portrait Face", Color(0.95, 0.8, 0.68), 0.8), Vector3(-1.0, 2.3, -hd + 0.07), Vector3(1, 1.15, 0.1))
	_box(f, Vector3(0.2, 0.04, 0.01), _plain("Portrait Moustache", Color(0.5, 0.5, 0.52), 0.8), Vector3(-1.0, 2.24, -hd + 0.085))
	_box(f, Vector3(1.4, 0.9, 0.03), _plain("Town Map Paper", Color(0.92, 0.88, 0.75), 0.9), Vector3(hw - 0.02, 2.0, -0.4), -PI / 2)
	_label(f, "Stars Hollow", Vector3(hw - 0.05, 2.35, -0.4), 22, Color(0.3, 0.25, 0.2), -PI / 2).outline_size = 0
	_box(f, Vector3(0.9, 0.04, 0.02), _plain("Map Road", Color(0.6, 0.5, 0.4), 0.9), Vector3(hw - 0.04, 1.9, -0.4), -PI / 2)
	_ball(f, 0.12, _plain("Map Green", Color(0.45, 0.65, 0.35), 0.9), Vector3(hw - 0.04, 1.85, -0.3), Vector3(0.1, 1, 1))
	_plant(f, Vector3(hw - 0.5, 0, hd - 0.5), 0.8)
	_lamp(f, Vector3(-hw + 0.4, 0, 1.8))
