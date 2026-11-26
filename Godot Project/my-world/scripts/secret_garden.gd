extends Node3D

# The Secret Garden (Hayden's day 1 playtest, 11 Nov 2026: "the secret garden needs to be much larger, and it's not
# very secret right now"). Everybody knows the Secret Gardens up on the hill, with your garden plot and the greenhouse;
# this is the one nobody's found for years. Its way in is an old ivy-covered wall at the foot of the hill's north cliff,
# and only the little wren knows it (scripts/secret_garden_way.gd).
#
# Rebuilt from scratch on 26 Nov 2026 (Hayden: "start over from scratch and make it 10x better", "make it way bigger.
# utilize inspiration from the worlds best arboretums and gardens"). It's a whole hidden estate on a hillside now, about
# 280 m wide and 320 m deep inside old ivy-covered walls, climbing 24 m from the ivy door at the bottom to an old grey
# stone house at the top. Every area is our own take on a famous garden, not a copy:
#   - the hill itself: scripts/secret_garden_land.gd (pads, lakes, the quarry, gravel paths)
#   - the house and the formal spine up the middle (secret_garden_estate.gd): the Old House and Overlook Terrace (after
#     Greystone, Beverly Hills), the Formal Garden and its fountain, the Cypress Walk, the Water Stairs (Villa d'Este)
#     and the Tulip Slope (Keukenhof)
#   - the water gardens low down (secret_garden_waters.gd): Temple Lake (Stourhead), the Lily Pond and its green bridge
#     (Giverny), the Japanese Garden, the Rose Walk by the door
#   - the trees (secret_garden_groves.gd): the Arboretum (Westonbirt, the Arnold), the Great Tree, the Treetop Walk
#     (Kew, Kirstenbosch), the Glasshouse (Kew's Palm House) and the Supertree Grove (Gardens by the Bay)
#   - the garden rooms high up (secret_garden_rooms.gd): the Hedge Maze (Longleat), the Parterre and Potager
#     (Villandry), the Rill Court (the Alhambra), the Sunken Quarry Garden (Butchart)
# This is the root of scenes/secret_garden/secret_garden.tscn (made by tools/build_secret_garden.gd), which holds only
# this script, an Entrance and the player; everything else is built here as it loads.
# Five **sleeping seeds** are hidden about: walk up to one and it wakes into a glowing flower. All five and the whole
# garden wakes up: everything brightens, petals drift down, and you get a reward (WAKE_SPARKLES, WAKE_REMNANTS, once).
# Found seeds are Dialogue flags (sg_seed_<id>, sg_awake), so old saves keep theirs. Nothing you walk on has a ledge.

const TOWN := "res://scenes/town/town.tscn"
const USE_SPOT := preload("res://scripts/use_spot.gd")
const LAND := preload("res://scripts/secret_garden_land.gd")
const PARTS := [
	["estate", preload("res://scripts/secret_garden_estate.gd")],
	["waters", preload("res://scripts/secret_garden_waters.gd")],
	["groves", preload("res://scripts/secret_garden_groves.gd")],
	["rooms", preload("res://scripts/secret_garden_rooms.gd")],
]

const WALL_X := LAND.X_HALF                   # the walls: x from -138 to 138...
const WALL_Z := Vector2(0, LAND.Z_MAX)        # ...and z from 0 to 322 (the door's in the south wall, at x 0)
const WALL_H := 5.0
const DOOR_W := 3.2
const SEED_REACH := 1.6
const WAKE_SPARKLES := 20
const WAKE_REMNANTS := 2
const PETAL_BOX := 26.0                       # petals drift in a box this far round you

# The sleeping seeds: id, and what the note says when you wake one. Where each is comes from the part that holds it
# (put_seed()).
const SEEDS := [
	{"id": "walk", "where": "on the lake temple's steps"},
	{"id": "maze", "where": "at the heart of the Hedge Maze"},
	{"id": "pond", "where": "on the Lily Pond's island"},
	{"id": "flower", "where": "on top of the tallest supertree"},
	{"id": "tree", "where": "up in the Great Tree's crown"},
]

var seeds := {}                               # id -> {"node": Node3D, "at": Vector3}
var seed_at := {}                             # id -> where it sits (from the parts)
var parts := {}                               # "estate", "waters", "groves", "rooms" -> the part
var awake := false
var land: Node3D
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _t := 0.0
var _petals: MultiMeshInstance3D
var _petal_pos: Array[Vector3] = []
var _glows: Array[StandardMaterial3D] = []
var _sky: ProceduralSkyMaterial
var _env: Environment
var _home_spot: Area3D


func _enter_tree() -> void:
	# (a marker looks along its -Z, so the Entrance turns round to face into the garden, which is north, along +Z)
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = Vector3(0, LAND.height(0.0, 4.0) + 1.0, 4.0)
			(n as Node3D).rotation.y = PI if n.name == "Entrance" else 0.0


func _ready() -> void:
	_rng.seed = 2611
	_environment()
	land = LAND.new()
	land.name = "Land"
	add_child(land)
	_walls()
	for p in PARTS:
		var part: Node3D = (p[1] as Script).new()
		parts[p[0]] = part
		part.call("build", self)
	_scatter()
	_place_seeds()
	_way_out()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	awake = Dialogue.flags.has("sg_awake")
	_set_awake(1.0 if awake else 0.0)


func ground(x: float, z: float) -> float:
	return LAND.height(x, z)


func put_seed(id: String, at: Vector3) -> void:
	seed_at[id] = at


# -----------------------------------------------------------------------------
# Little helpers (the same as the Gloop Kingdom's, scripts/gloop_kingdom.gd)
# -----------------------------------------------------------------------------
func _mat(name: String, c: Color, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, name: String, shape: Shape3D, at: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	body.rotation = rot
	parent.add_child(body)
	return body


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, m: Material, solid := true, yaw := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(parent, bm, at, m)
	mi.name = name
	mi.rotation.y = yaw
	if solid:
		var bs := BoxShape3D.new()
		bs.size = size
		_solid(parent, name + " Body", bs, at, Vector3(0, yaw, 0))
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 20
	var mi := _mesh(parent, cm, at, m)
	mi.name = name
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(r_top, r_bottom)
		cs.height = h
		_solid(parent, name + " Body", cs, at)
	return mi


func _ball(parent: Node3D, r: float, at: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 12
	sm.rings = 6
	return _mesh(parent, sm, at, m, false)


func _label(parent: Node3D, text: String, at: Vector3, yaw: float, size := 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.92, 0.7)
	l.outline_size = 10
	l.outline_modulate = Color(0.15, 0.1, 0.2)
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l


func _leaf() -> StandardMaterial3D:
	return _mat("Garden Leaf", Color(0.2, 0.5, 0.25), 0.8)


func _hedge() -> StandardMaterial3D:
	return _mat("Hedge", Color(0.16, 0.4, 0.22), 0.9)


# -----------------------------------------------------------------------------
# Sky and light
# -----------------------------------------------------------------------------
func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color(0.34, 0.42, 0.66)                   # a soft blue sky, warm gold low down
	_sky.sky_horizon_color = Color(0.94, 0.84, 0.74)
	_sky.ground_horizon_color = Color(0.5, 0.6, 0.45)
	_sky.ground_bottom_color = Color(0.2, 0.3, 0.2)
	sky.sky_material = _sky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.adjustment_enabled = true                                  # asleep the colours are a little faded (_set_awake)
	env.adjustment_saturation = 0.92
	_env = env
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.72, 0.78)
	env.fog_density = 0.0007                                       # the far side of the garden softly hazy
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.name = "Garden Sky"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.rotation = Vector3(deg_to_rad(-42), deg_to_rad(-150), 0)       # from the south-west, lighting the house's front
	add_child(sun)


# -----------------------------------------------------------------------------
# The walls: old ivy-covered stone all round, following the hill, the ivy door in the middle of the south wall
# -----------------------------------------------------------------------------
func wall_line() -> Array:
	# The walls' lengths: [from, to, inside facing] on the ground plane, the south wall in two either side of the door
	return [
		[Vector2(-WALL_X, WALL_Z.x), Vector2(-DOOR_W / 2.0, WALL_Z.x), Vector2(0, 1)],
		[Vector2(DOOR_W / 2.0, WALL_Z.x), Vector2(WALL_X, WALL_Z.x), Vector2(0, 1)],
		[Vector2(WALL_X, WALL_Z.y), Vector2(-WALL_X, WALL_Z.y), Vector2(0, -1)],
		[Vector2(-WALL_X, WALL_Z.y), Vector2(-WALL_X, WALL_Z.x), Vector2(1, 0)],
		[Vector2(WALL_X, WALL_Z.x), Vector2(WALL_X, WALL_Z.y), Vector2(-1, 0)],
	]


func _walls() -> void:
	var w := Node3D.new()
	w.name = "Garden Walls"
	add_child(w)
	# The wall is laid in 4 m lengths, each standing on the lower of its two ends and tall enough to stand 5 m over the
	# higher (sunk well into the ground), so it steps up the hill. The baked ivy wall when the detail pipeline's on.
	var baked: Mesh = load("res://scripts/detail_props.gd").call("baked_mesh", "res://models/props/secret_garden/ivy_wall.glb")
	var plain := BoxMesh.new()
	plain.size = Vector3(4.0, WALL_H, 1.0)
	var xfs: Array = []
	for seg in wall_line():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var inside: Vector2 = seg[2]
		var n := ceili(a.distance_to(b) / 4.0)
		var dir := (b - a) / n
		for i in n:
			var p0 := a + dir * i
			var p1 := a + dir * (i + 1)
			var mid := (p0 + p1) / 2.0
			var low := minf(LAND.height(p0.x, p0.y), LAND.height(p1.x, p1.y)) - 1.0
			var high := maxf(LAND.height(p0.x, p0.y), LAND.height(p1.x, p1.y)) + WALL_H
			var k := (high - low) / WALL_H
			var along_len := p0.distance_to(p1) / 4.0 + 0.02
			# local x along the wall, local +z to the inside
			var x_axis := Vector3(dir.x, 0, dir.y).normalized() * along_len
			var z_axis := Vector3(inside.x, 0, inside.y)
			var basis := Basis(x_axis, Vector3(0, k, 0), z_axis)
			var origin := Vector3(mid.x, low, mid.y) + (Vector3.ZERO if baked else Vector3(0, WALL_H * k / 2.0, 0))
			xfs.append(Transform3D(basis, origin))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = baked if baked else plain
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Ivy Walls"
	mmi.multimesh = mm
	mmi.set_meta("transforms", xfs)
	if baked == null:
		mmi.material_override = _mat("Old Wall Stone", Color(0.55, 0.5, 0.52), 0.95)
	w.add_child(mmi)
	# Solid all along, and invisible walls a little outside so nobody climbs out over the top
	for seg in wall_line():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b)
		var bs := BoxShape3D.new()
		bs.size = Vector3(length, 80.0, 1.0)
		var body := _solid(w, "Wall Body", bs, Vector3(mid.x, 20.0, mid.y))
		body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var edge := Node3D.new()
	edge.name = "WorldBounds Garden"
	add_child(edge)
	var span_x := WALL_X * 2.0
	var span_z := WALL_Z.y - WALL_Z.x
	for p in [[Vector3(0, 30, WALL_Z.x - 1.8), Vector3(span_x + 6, 100, 1)], [Vector3(0, 30, WALL_Z.y + 1.8), Vector3(span_x + 6, 100, 1)],
			[Vector3(-WALL_X - 1.8, 30, span_z / 2.0), Vector3(1, 100, span_z + 6)], [Vector3(WALL_X + 1.8, 30, span_z / 2.0), Vector3(1, 100, span_z + 6)]]:
		var bs := BoxShape3D.new()
		bs.size = p[1]
		_solid(edge, "Edge", bs, p[0])
	# The door's stone frame: two piers and a lintel with a rounded hood
	var frame := Node3D.new()
	frame.name = "Ivy Door Frame"
	w.add_child(frame)
	var y0 := LAND.height(0, 0)
	var dark := _mat("Estate Stone Dark", Color(0.47, 0.46, 0.5), 0.85)
	for side: float in [-1.0, 1.0]:
		_box(frame, "Door Pier", Vector3(1.2, 5.6, 1.6), Vector3(side * (DOOR_W / 2.0 + 0.6), y0 + 2.4, 0), dark, true)
	_box(frame, "Door Lintel", Vector3(DOOR_W + 2.4, 1.0, 1.6), Vector3(0, y0 + 4.2, 0), dark, true)
	# Great old trees outside the walls all round, so it feels tucked away in a wood
	var outer := _OUTER.new()
	outer.build(self)


class _OUTER extends "res://scripts/secret_garden_kit.gd":
	# The wood outside the walls (only to look at: nobody can get out there)
	func build(garden: Node3D) -> void:
		start(garden, "Outer Wood", 77)
		var kinds := ["oak", "oak", "redwood", "copper", "cedar", "oak", "birch"]
		var k := 0
		var x := -170.0
		while x <= 170.0:
			for row in 2:
				for z: float in [-14.0 - row * 13.0, LAND.Z_MAX + 12.0 + row * 13.0]:
					var at := Vector3(x + _rng.randf_range(-3, 3) + row * 6.0, 0, z + _rng.randf_range(-3, 3))
					at.y = LAND.height(at.x, at.z)
					tree(kinds[k % kinds.size()], at, _rng.randf_range(1.0, 1.4))
					k += 1
			x += 13.0
		var z := 0.0
		while z <= LAND.Z_MAX:
			for row in 2:
				for side: float in [-1.0, 1.0]:
					var at := Vector3(side * (LAND.X_HALF + 12.0 + row * 13.0) + _rng.randf_range(-3, 3), 0, z + _rng.randf_range(-3, 3) + row * 6.0)
					at.y = LAND.height(at.x, at.z)
					tree(kinds[k % kinds.size()], at, _rng.randf_range(1.0, 1.4))
					k += 1
			z += 13.0
		finish([["Oak Bark", "bark", 0.8]])


# -----------------------------------------------------------------------------
# Wild flowers and grass in the long grass, and petals in the air
# -----------------------------------------------------------------------------
func open_ground(at: Vector3) -> bool:
	# Where wild flowers and grass may grow: not on a path, a pad's formal lawn, in water, on the steep, or anywhere a
	# part says it has something
	if LAND.path_dist(at.x, at.z) < 0.6 or LAND.in_lake(at.x, at.z, 1.5) != "":
		return false
	if LAND.slope(at.x, at.z) > 0.45 or LAND.on_pad(at.x, at.z, -3.0) != "":
		return false
	if LAND.quarry_dist(at.x, at.z) < LAND.QUARRY.z + LAND.QUARRY_WALL + 2.0:
		return false
	for p in parts.values():
		if p.has_method("blocks") and p.call("blocks", at):
			return false
	return true


func _scatter() -> void:
	var s := Node3D.new()
	s.name = "Wildflowers"
	add_child(s)
	var cols := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 0.85, 1.0), Color(1.0, 1.0, 0.95)]
	var heads := []
	for c in cols:
		heads.append([])
	var stalks: Array = []
	var tufts: Array = []
	var tries := 0
	var placed := 0
	while placed < 2600 and tries < 16000:
		tries += 1
		var at := Vector3(_rng.randf_range(-WALL_X + 3, WALL_X - 3), 0, _rng.randf_range(WALL_Z.x + 4, WALL_Z.y - 3))
		if not open_ground(at):
			continue
		at.y = LAND.height(at.x, at.z)
		placed += 1
		if placed % 3 == 0:
			tufts.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, _rng.randf_range(0.6, 1.2), 1)), at))
			continue
		var h := _rng.randf_range(0.3, 0.75)
		stalks.append(Transform3D(Basis.from_scale(Vector3(1, h, 1)), at + Vector3(0, h / 2.0, 0)))
		var r := _rng.randf_range(0.1, 0.2)
		heads[placed % cols.size()].append(Transform3D(Basis.from_scale(Vector3(r, r * 0.7, r)), at + Vector3(0, h, 0)))
	var head := SphereMesh.new()
	head.radius = 1.0
	head.height = 2.0
	head.radial_segments = 8
	head.rings = 4
	for i in cols.size():
		var m := _mat("Wild Flower %d" % i, cols[i], 0.6, 0.15)
		if not m in _glows:
			_glows.append(m)
		_multi(s, "Flower Heads %d" % i, head, heads[i], m)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.022
	stalk.bottom_radius = 0.028
	stalk.height = 1.0
	stalk.radial_segments = 4
	_multi(s, "Flower Stalks", stalk, stalks, _leaf())
	# Tufts of long grass: three crossed blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 5:
		var a := TAU * b / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		var tip := d * 0.28 + Vector3(0, 0.62, 0)
		st.set_normal(Vector3.UP)
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(tip)
	var tuft := st.commit()
	var gm := _mat("Long Grass", Color(0.36, 0.58, 0.28), 0.9)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multi(s, "Grass Tufts", tuft, tufts, gm)
	# Petals drifting down round you (moved in _process), many more once the garden's awake
	_petals = MultiMeshInstance3D.new()
	_petals.name = "Petals"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.1)
	mm.mesh = quad
	mm.instance_count = 200
	_petals.multimesh = mm
	var pm := _mat("Petal", Color(1.0, 0.72, 0.85), 0.5, 0.3)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_petals.material_override = pm
	_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_petals)
	for k in mm.instance_count:
		_petal_pos.append(Vector3(_rng.randf_range(-PETAL_BOX, PETAL_BOX), _rng.randf_range(0.0, 10.0), _rng.randf_range(-PETAL_BOX, PETAL_BOX)))


func _multi(parent: Node3D, nm: String, mesh: Mesh, xfs: Array, m: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 90.0
	mmi.set_meta("transforms", xfs)
	parent.add_child(mmi)
	return mmi


# -----------------------------------------------------------------------------
# The sleeping seeds
# -----------------------------------------------------------------------------
func seed_spot(id: String) -> Vector3:
	if seed_at.has(id):
		return seed_at[id]
	# (a part that hasn't put its seed: by the door, so it can still be found)
	var i := 0
	for s in SEEDS:
		if s.id == id:
			break
		i += 1
	return Vector3(-8.0 + i * 4.0, LAND.height(-8.0 + i * 4.0, 12.0), 12.0)


func _place_seeds() -> void:
	var holder := Node3D.new()
	holder.name = "Sleeping Seeds"
	add_child(holder)
	for s in SEEDS:
		var id: String = s.id
		var at := seed_spot(id)
		var n := Node3D.new()
		n.name = "Seed " + id
		n.position = at
		holder.add_child(n)
		var shell := _ball(n, 0.32, Vector3(0, 0.35, 0), _mat("Sleeping Seed", Color(0.75, 0.6, 0.45), 0.6, 0.2), 1.2)
		shell.name = "Shell"
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.5)
		glow.light_energy = 0.6
		glow.omni_range = 2.5
		glow.position = Vector3(0, 0.6, 0)
		n.add_child(glow)
		var bloom := _bloom_model()
		bloom.name = "Bloom"
		bloom.visible = false
		n.add_child(bloom)
		seeds[id] = {"node": n, "at": at}
		if Dialogue.flags.has("sg_seed_" + id):
			_show_bloom(n, false)


func _bloom_model() -> Node3D:
	var b := Node3D.new()
	_cyl(b, "Bloom Stem", 0.05, 0.06, 1.0, Vector3(0, 0.5, 0), _leaf(), false)
	var m := _mat("Wake Bloom", Color(1.0, 0.8, 0.95), 0.4, 1.2)
	for p in 6:
		var a := TAU * p / 6.0
		_ball(b, 0.22, Vector3(cos(a) * 0.25, 1.05, sin(a) * 0.25), m, 0.5)
	_ball(b, 0.14, Vector3(0, 1.08, 0), _mat("Wake Middle", Color(1.0, 0.95, 0.5), 0.4, 1.5))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.95)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.3, 0)
	b.add_child(l)
	return b


func _show_bloom(n: Node3D, fresh: bool) -> void:
	(n.get_node("Shell") as Node3D).visible = false
	var bloom := n.get_node("Bloom") as Node3D
	bloom.visible = true
	if fresh:
		bloom.scale = Vector3.ONE * 0.05
		var tw := bloom.create_tween()
		tw.tween_property(bloom, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func seeds_woken() -> int:
	var n := 0
	for s in SEEDS:
		if Dialogue.flags.has("sg_seed_" + str(s.id)):
			n += 1
	return n


func wake_seed(id: String) -> void:
	var flag := "sg_seed_" + id
	if Dialogue.flags.has(flag) or not seeds.has(id):
		return
	Dialogue.set_flag(flag)
	var n: Node3D = seeds[id].node
	_show_bloom(n, true)
	Fx.burst(self, n.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.8, 0.95), 18, 0.1, 3.0, -2.0)
	Juice.blip("chime", 1.0 + seeds_woken() * 0.1, -4.0)
	var where := ""
	for s in SEEDS:
		if s.id == id:
			where = s.where
	var left := SEEDS.size() - seeds_woken()
	if left > 0:
		Game.message("A sleeping seed %s wakes into a glowing flower! (%d still sleeping)" % [where, left])
	else:
		_wake_garden()


func _wake_garden() -> void:
	if Dialogue.flags.has("sg_awake"):
		return
	Dialogue.set_flag("sg_awake")
	awake = true
	Game.add_sparkles(WAKE_SPARKLES)
	Remnants.add(WAKE_REMNANTS)
	Game.message("The Secret Garden's awake! ✦ %d and %s." % [WAKE_SPARKLES, Remnants.words(WAKE_REMNANTS)])
	Juice.shake(0.2)
	var tw := create_tween()
	tw.tween_method(_set_awake, 0.0, 1.0, 3.0)


func _set_awake(k: float) -> void:
	# Asleep the garden's a little dim and dusty; awake, every flower glows and the sky's brighter
	for m in _glows:
		m.emission_energy_multiplier = lerpf(0.12, 0.7, k)
	if _env:
		_env.adjustment_saturation = lerpf(0.92, 1.3, k)
	if _sky:
		_sky.sky_top_color = Color(0.34, 0.42, 0.66).lerp(Color(0.36, 0.52, 0.86), k)
		_sky.sky_horizon_color = Color(0.94, 0.84, 0.74).lerp(Color(1.0, 0.86, 0.9), k)
	for p in parts.values():
		if p.has_method("wake"):
			p.call("wake", k)


# -----------------------------------------------------------------------------
# The way out
# -----------------------------------------------------------------------------
func _way_out() -> void:
	# The old door, open, just behind where you come in: step back through to go home
	var d := Node3D.new()
	d.name = "Old Door"
	d.position = Vector3(0, LAND.height(0, 0), WALL_Z.x)
	add_child(d)
	var wood := _mat("Door Wood", Color(0.45, 0.32, 0.3), 0.9)
	var door := _box(d, "Door Leaf", Vector3(0.12, 3.4, 2.9), Vector3(-1.5, 1.7, 1.4), wood, false)
	door.rotation.y = 0.0
	_box(d, "Doorway Dark", Vector3(DOOR_W, 3.7, 0.1), Vector3(0, 1.85, -0.4), _mat("Doorway", Color(0.05, 0.05, 0.08)), false)
	_home_spot = USE_SPOT.make(Vector3(0, 0, 1.0), func() -> String: return "go back out through the old door",
		go_home, 2.0, 2.4)
	_home_spot.name = "Door Spot"
	d.add_child(_home_spot)


func go_home() -> void:
	Farm.get_node("SecretGarden").leave_garden()


# -----------------------------------------------------------------------------
# Every frame: the petals, the seeds bobbing, waking them
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	if _petals:
		var mm := _petals.multimesh
		var fall := 0.4 + (0.6 if awake else 0.0)
		var shown := mm.instance_count if awake else mm.instance_count / 3
		mm.visible_instance_count = shown
		var here := _player.global_position if _player and is_instance_valid(_player) else Vector3.ZERO
		_petals.global_position = Vector3(here.x, here.y - 2.0, here.z)
		for k in shown:
			var p := _petal_pos[k]
			p.y -= delta * fall
			p.x += sin(_t + k) * delta * 0.3
			if p.y < 0.05:
				p.y = 10.0
			_petal_pos[k] = p
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, _t + k).rotated(Vector3.RIGHT, _t * 0.7 + k), p))
	for id in seeds:
		var n: Node3D = seeds[id].node
		var shell := n.get_node("Shell") as Node3D
		if shell.visible:
			shell.position.y = 0.35 + sin(_t * 2.0 + n.position.x) * 0.06


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var p := _player.global_position
	for id in seeds:
		var at: Vector3 = seeds[id].at
		if Vector2(p.x - at.x, p.z - at.z).length() < SEED_REACH and absf(p.y - 0.9 - at.y) < 1.5:
			wake_seed(id)
