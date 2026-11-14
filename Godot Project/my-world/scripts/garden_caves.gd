extends Node

# The Undergardens: caves under the Secret Gardens hill in the Void, explored with Pip's glow (scripts/pip_glow.gd,
# Lanternmoor's reward). Hayden: "I want to make some of the secret garden caves as well", alongside Lanternmoor's
# own caves; both use the shared pieces in scripts/cave_kit.gd, so they look and work the same.
#
# The way in is the **Rootwell**, a round hole on top of the hill west of the greenhouse, ringed with roots. Until
# Pip's glow is yours a tangle of roots covers it ("too dark down there"). Then a spiral of root steps goes down the
# shaft into one loop of caves under the whole hill (each spot checked inside the hill, under the gardens, by
# tools/test_garden_caves.gd):
#   - the Root Hall, under the greenhouse: the garden's roots hang down through the ceiling, with eyes (every plant
#     in the Void has eyes). A Glowcap spore sits high on a root ledge, up moth-dust steps only the glow shows.
#   - the Mushroom Grotto: giant mushroom caps to climb to a spore on a high shelf.
#   - the Crystal Pool: a deep pool (scripts/water.gd: float or swim across) round an island with a spore on it.
#   - the Deep Crack: a chasm with a rock pillar in the middle; the spore on the pillar is reached by glow bridges.
#     Falling in floats you back to the edge.
#   - the Taproot's Hollow: the Old Taproot, the hill's oldest root, asleep since the Void cracked. Pip's glow wakes
#     him (glow_wake). Bring him the four spores and he gives you Glowcap seeds for your garden (scripts/farm.gd), a
#     crop that glows at night. Quest quests/undergardens.json; Bramble tells you about the caves once Lanternmoor's
#     mended (dialogue/bramble.json), and going down there yourself starts it too.
# Everything goes in at play time (like the garden and the deep pools): the ground over the Rootwell is cut away by
# scripts/ground_hole.gd, nothing in a builder or town.tscn changed. Found things are Dialogue flags (ug_*), so
# nothing new in the save.
#
# It lives under the Farm autoload ("Farm/Caves"), so dialogue can reach it ("do": "Farm/Caves.hand_in").

const KIT := preload("res://scripts/cave_kit.gd")
const HOLE := preload("res://scripts/ground_hole.gd")
const WATER := preload("res://scripts/water.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const TOWN := "res://scenes/town/town.tscn"
const QUEST := "undergardens"
const WORLD := "lanternmoor"                       # Pip's glow comes from mending it

const MOUTH := Vector2(-97.0, -46.0)                # the Rootwell, on top of the hill
const MOUTH_R := 3.0                                # the shaft, inside
const TOP := 11.6                                   # the cave never reaches higher (the hill's top is about 12)
const FLOOR := 3.0                                  # most of the cave's floor
const STEP_RISE := 0.5
const STEP_TURN := 0.5                              # radians round the shaft per step
const CRACK := Vector3(-89.0, 3.0, -36.0)           # the Deep Crack's middle (its pillar)
const CRACK_HALF := 4.0                             # half its width, east to west
const PIT_FLOOR := -6.0
const POOL := Vector3(-74.0, 0.0, -31.0)            # the Crystal Pool's middle (x, -, z)
const POOL_R := Vector2(4.6, 3.6)
const POOL_Y := 2.55                                # its surface: just under the room's floor
const TAPROOT := Vector3(-95.5, FLOOR, -37.0)

# The spores: flag, where, and what the note says when you find one
const SPORES := [
	{"flag": "ug_spore_hall", "at": Vector3(-84.5, 7.6, -53.0), "where": "high in the Root Hall's roots"},
	{"flag": "ug_spore_grotto", "at": Vector3(-58.0, 8.7, -42.5), "where": "on the Mushroom Grotto's top shelf"},
	{"flag": "ug_spore_pool", "at": Vector3(-74.0, 3.9, -31.0), "where": "on the Crystal Pool's island"},
	{"flag": "ug_spore_chasm", "at": Vector3(-89.0, 3.9, -36.0), "where": "on the pillar in the Deep Crack"},
]
const SPORE_REACH := 1.4
const SPORE_COLOUR := Color(0.55, 0.95, 1.0)
const GIVE_SEEDS := 3
const GLOOP_CLEAR := 13.0                           # no Gloop's home this near the Rootwell (they'd wander in)

# The cave, as cave_kit shapes (see its header)
const SHAPES := [
	{"kind": "shaft", "at": Vector3(-97.0, FLOOR, -46.0), "r": MOUTH_R, "top": 14.0},
	{"kind": "tunnel", "points": [Vector3(-97.0, 4.2, -46.0), Vector3(-93.0, 4.4, -51.0), Vector3(-87.0, 4.4, -52.0)], "r": 2.3, "floor": 0.55},
	{"kind": "room", "at": Vector3(-80.0, 6.0, -50.0), "rx": 8.0, "ry": 4.6, "rz": 6.0, "floor": FLOOR},
	{"kind": "tunnel", "points": [Vector3(-73.0, 4.4, -50.0), Vector3(-68.0, 4.4, -48.5), Vector3(-64.0, 4.4, -46.0)], "r": 2.3, "floor": 0.55},
	{"kind": "room", "at": Vector3(-61.0, 6.0, -44.0), "rx": 6.0, "ry": 4.4, "rz": 6.0, "floor": FLOOR},
	{"kind": "tunnel", "points": [Vector3(-62.0, 4.4, -39.0), Vector3(-65.0, 4.4, -34.5), Vector3(-69.0, 4.4, -32.0)], "r": 2.3, "floor": 0.55},
	{"kind": "room", "at": Vector3(-74.0, 5.5, -31.0), "rx": 7.0, "ry": 4.0, "rz": 4.6, "floor": FLOOR},
	{"kind": "room", "at": Vector3(-74.0, 1.5, -31.0), "rx": POOL_R.x, "ry": 2.5, "rz": POOL_R.y, "floor": -0.6},
	{"kind": "room", "at": Vector3(-74.0, 0.0, -31.0), "rx": 1.4, "ry": 3.6, "rz": 1.4, "solid": true},
	{"kind": "tunnel", "points": [Vector3(-80.0, 4.4, -31.5), Vector3(-83.0, 4.4, -34.0), Vector3(-85.0, 4.4, -36.0)], "r": 2.3, "floor": 0.55},
	{"kind": "room", "at": Vector3(-89.0, 6.0, -36.0), "rx": 7.0, "ry": 4.2, "rz": 3.4, "floor": FLOOR},
	{"kind": "room", "at": Vector3(-89.0, -1.0, -36.0), "rx": CRACK_HALF, "ry": 6.5, "rz": 2.8, "floor": PIT_FLOOR},
	{"kind": "room", "at": Vector3(-89.0, -1.5, -36.0), "rx": 1.1, "ry": 4.4, "rz": 1.1, "solid": true},
	{"kind": "room", "at": Vector3(-96.5, 6.0, -37.5), "rx": 4.8, "ry": 4.4, "rz": 4.4, "floor": FLOOR},
	{"kind": "tunnel", "points": [Vector3(-97.0, 4.4, -40.5), Vector3(-97.5, 4.4, -43.5)], "r": 2.2, "floor": 0.55},
]

var _scene: Node
var _holder: Node3D
var _taproot: Node3D
var _field := {}
var _spores := {}                                   # flag -> its pickup
var _check := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_holder = null
		if s and s.scene_file_path == TOWN and not s.has_meta("preview"):
			_place_in.call_deferred(s)
	if not is_instance_valid(_holder):
		return
	_t += delta
	for f in _spores:
		var p := _spores[f] as Node3D
		if is_instance_valid(p):
			p.get_child(0).position.y = sin(_t * 2.0 + p.position.x) * 0.12
			p.rotation.y += delta * 0.8
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.15
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_update_lid()
	var here := player.global_position
	if in_cave(here) and glow_ready() and not Dialogue.flags.has("undergardens_start"):
		Dialogue.set_flag("undergardens_start")         # finding it yourself starts the quest too
	for f in _spores.keys():
		var p := _spores[f] as Node3D
		if is_instance_valid(p) and here.distance_to(p.global_position) < SPORE_REACH + 0.8:
			_collect(str(f))
	_catch_gloops()
	# Fell into the Deep Crack: float back up to its east edge, like the portal worlds' fall catch
	if here.y < PIT_FLOOR + 3.0 and absf(here.x - CRACK.x) < CRACK_HALF + 1.0 and absf(here.z - CRACK.z) < 4.0:
		var back := Vector3(CRACK.x + CRACK_HALF + 1.6, FLOOR + 1.0, CRACK.z)
		player.global_position = back
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		Game.message("Whoosh! The roots lift you back up.")


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
func glow_ready() -> bool:
	return Portals.is_cleared(WORLD)


func has_spore(flag: String) -> bool:
	return Dialogue.flags.has(flag)


func spores_found() -> int:
	return SPORES.filter(func(s: Dictionary) -> bool: return has_spore(s.flag)).size()


func given() -> bool:
	return Dialogue.flags.has("ug_taproot_given")


func taproot_awake() -> bool:
	return Dialogue.flags.has("ug_taproot_woken")


func in_cave(p: Vector3) -> bool:
	# In the cave's air (its own grid says so), below the hill's top
	return not _field.is_empty() and inside(p) and p.y < TOP - 0.5 and KIT.field_at(_field, p) < 0.0


static func inside(p: Vector3) -> bool:
	# Under the hill, in the caves (roughly: the box the dark zone covers)
	return p.x > -103.0 and p.x < -53.0 and p.z > -58.0 and p.z < -24.0 and p.y < TOP and p.y > PIT_FLOOR - 1.0


# -----------------------------------------------------------------------------
# Putting it in
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D:
		return
	_holder = Node3D.new()
	_holder.name = "Undergardens"
	s.add_child(_holder)
	var space := (s as Node3D).get_world_3d().direct_space_state
	var g := _height(space, MOUTH)
	var reach := HOLE.cut(s, MOUTH, MOUTH_R + 0.2, TOP - 1.0, g + 1.0)
	var built := KIT.build(_holder, SHAPES, {"cell": 0.75, "top": TOP, "seed": 12, "name": "Undergardens Rock",
		"rock": Color(0.4, 0.33, 0.28)})
	_field = built.field
	KIT.shade_from_sun(s)
	KIT.dark_zone(_holder, Vector3(-78.0, 3.0, -41.0), Vector3(50.0, 17.0, 34.0), "Undergardens Dark")
	_mouth(g, reach)
	_steps()
	_root_hall()
	_grotto()
	_pool()
	_crack()
	_taproot_hollow()
	_dress()
	_move_gloops(s)
	_spores.clear()
	for sp in SPORES:
		if not has_spore(sp.flag):
			var p := spore_model()
			p.name = "Spore " + str(sp.flag)
			_holder.add_child(p)
			p.global_position = sp.at
			_spores[sp.flag] = p
	_update_lid()


func _move_gloops(s: Node) -> void:
	# The Secret Gardens' big Gloops amble round a home spot; one that lives by the Rootwell would wander in and fall
	# down the shaft, so any home near the hole moves away from it
	for n in s.find_children("*", "CharacterBody3D", true, false):
		if n.get("home") == null or n.is_in_group("player"):
			continue
		var h: Vector3 = n.get("home")
		var off := Vector2(h.x, h.z) - MOUTH
		if h.y > TOP - 2.0 and off.length() < GLOOP_CLEAR:
			var dir := off.normalized() if off.length() > 0.1 else Vector2(1, 0)
			var to := MOUTH + dir * GLOOP_CLEAR
			var moved := Vector3(to.x, h.y, to.y)
			n.set("home", moved)
			n.set("target", moved)
			(n as Node3D).global_position = moved + Vector3(0, 0.3, 0)


func _catch_gloops() -> void:
	# ...and if one does tumble in anyway (chasing you to the edge), it's whisked back home
	if not is_instance_valid(_scene):
		return
	for n in get_tree().get_nodes_in_group("enemies") if get_tree().has_group("enemies") else _scene.find_children("Gloop*", "CharacterBody3D", true, false):
		if n is Node3D and n.get("home") != null and in_cave((n as Node3D).global_position):
			(n as Node3D).global_position = (n.get("home") as Vector3) + Vector3(0, 0.3, 0)
			n.set("target", n.get("home"))
			if n is CharacterBody3D:
				(n as CharacterBody3D).velocity = Vector3.ZERO


func _height(space: PhysicsDirectSpaceState3D, at: Vector2) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80, at.y), Vector3(at.x, -60, at.y))
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 12.0


static func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.8
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _mesh(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	mi.rotation = rot
	mi.scale = scl
	return mi


static func _cyl(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = maxf(h, 0.04)
	c.radial_segments = seg
	c.rings = 1
	return c


static func _sph(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 12
	s.rings = 6
	return s


static func _solid_box(parent: Node3D, size: Vector3, at: Vector3, m: Material, yaw := 0.0, shown := true) -> StaticBody3D:
	var b := StaticBody3D.new()
	parent.add_child(b)
	b.position = at
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	if shown:
		var bm := BoxMesh.new()
		bm.size = size
		_mesh(b, bm, m, Vector3.ZERO)
	return b


const BARK := Color(0.42, 0.28, 0.18)
const ROOT := Color(0.55, 0.38, 0.24)


func _mouth(g: float, reach: float) -> void:
	# A ring of fat roots round the hole's ragged edge, a sign, and the lid: a tangle of roots over the hole until
	# Pip's glow is yours
	var m := Node3D.new()
	m.name = "The Rootwell"
	_holder.add_child(m)
	m.position = Vector3(MOUTH.x, g, MOUTH.y)
	var bark := _mat(BARK)
	var ring_r := maxf(reach, MOUTH_R + 0.3) + 0.35
	var body := StaticBody3D.new()
	body.name = "Rim"
	m.add_child(body)
	var n := 14
	for i in n:
		var a := i * TAU / n
		var seg := TAU * ring_r / n * 1.15
		var at := Vector3(cos(a) * ring_r, 0.15, sin(a) * ring_r)
		_mesh(m, _cyl(0.38, 0.45, seg), bark, at, Vector3(PI / 2.0, -a, 0.0))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 0.5, seg)
		cs.shape = bs
		cs.position = at
		cs.rotation.y = -a
		body.add_child(cs)
		if i % 3 == 0:                                       # little leafy sprigs on the roots
			_mesh(m, _sph(0.32, 0.18), _mat(Color(0.35, 0.85, 0.45)), at + Vector3(0, 0.45, 0))
	# Ragged turf skirt round the outside, so the cut edge doesn't show
	var skirt := TorusMesh.new()
	skirt.inner_radius = ring_r - 0.2
	skirt.outer_radius = ring_r + 1.7
	skirt.rings = 28
	_mesh(m, skirt, _mat(Color(0.32, 0.7, 0.45)), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.06, 1.0))
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = "The Rootwell"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.86, 0.62)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.0, ring_r + 0.6)
	m.add_child(sign)
	# The lid: woven roots, solid, with a spot that says why you can't go in yet
	var lid := StaticBody3D.new()
	lid.name = "Tangle"
	m.add_child(lid)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ring_r
	cyl.height = 0.5
	cs.shape = cyl
	cs.position.y = 0.1
	lid.add_child(cs)
	for k in 7:
		var a := k * PI / 7.0
		_mesh(lid, _cyl(0.2, 0.24, ring_r * 2.0), bark, Vector3(0, 0.15 + (k % 2) * 0.12, 0), Vector3(PI / 2.0, a, 0.0))
	var spot := USE_SPOT.make(Vector3(0, 0, 0), func() -> String:
		return "" if glow_ready() else "peer down", _peer, ring_r + 1.5)
	spot.name = "Peer"
	m.add_child(spot)


func _peer() -> void:
	var spot := _holder.get_node_or_null("The Rootwell/Peer") as Node3D if is_instance_valid(_holder) else null
	if spot:
		Dialogue.say(spot, "The Rootwell", ["(It's pitch dark. Something's snoring...)",
			"(You need a light. Someone who glows?)"], "ug_peer")


func _update_lid() -> void:
	if not is_instance_valid(_holder):
		return
	var lid := _holder.get_node_or_null("The Rootwell/Tangle") as Node3D
	if lid == null:
		return
	var open := glow_ready()
	if lid.visible == open:
		lid.visible = not open
		for c in lid.find_children("*", "CollisionShape3D", true, false):
			(c as CollisionShape3D).set_deferred("disabled", open)


func _steps() -> void:
	# A spiral of root steps down the shaft's wall, from the cave's floor to just under the hole
	var g := Node3D.new()
	g.name = "Root Steps"
	_holder.add_child(g)
	var root := _mat(ROOT)
	var y := FLOOR + STEP_RISE
	var a := PI * 0.75                                     # the bottom step faces the tunnel (south-east)
	var i := 0
	while y < TOP - 0.2:
		var r := MOUTH_R - 0.75
		var at := Vector3(MOUTH.x + cos(a) * r, y - 0.18, MOUTH.y + sin(a) * r)
		var b := _solid_box(g, Vector3(1.5, 0.36, 1.25), at, root, -a, false)
		b.name = "Step%d" % (i + 1)
		_mesh(b, _cyl(0.3, 0.36, 1.6), root, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
		y += STEP_RISE
		a -= STEP_TURN
		i += 1
	KIT.in_the_dark(g)


func _root_hall() -> void:
	# The garden's roots hanging through the ceiling, some with eyes, and moth-dust steps up to a root ledge
	var g := Node3D.new()
	g.name = "Root Hall"
	_holder.add_child(g)
	var root := _mat(ROOT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 14:
		var p := Vector3(-80.0 + rng.randf_range(-6.5, 6.5), 0.0, -50.0 + rng.randf_range(-4.5, 4.5))
		var top := KIT.ceiling_above(_field, Vector3(p.x, 6.0, p.z))
		var len := rng.randf_range(1.5, 3.5)
		_mesh(g, _cyl(0.22, 0.05, len, 7), root, top - Vector3(0, len * 0.5 - 0.3, 0),
			Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
		if k % 3 == 0:
			_eyes(g, top - Vector3(0, len * 0.6, -0.18), 0.12)
	# The ledge: a big root across the north-west corner, its top at 7 m
	var ledge := _solid_box(g, Vector3(3.0, 0.6, 2.2), Vector3(-84.5, 6.7, -53.0), root, 0.2)
	ledge.name = "Root Ledge"
	# Moth-dust steps up to it: only there in Pip's glow
	var dust := _mat(KIT.DUST, 1.6, 0.8)
	var steps := [Vector3(-79.5, 3.9, -52.0), Vector3(-81.0, 4.8, -53.6), Vector3(-82.6, 5.7, -52.4)]
	for i in steps.size():
		var b := _solid_box(g, Vector3(1.3, 0.25, 1.3), steps[i], dust)
		b.name = "Dust Step%d" % (i + 1)
		b.add_to_group("glow_solid", true)
	KIT.in_the_dark(g)
	for c in g.get_children():
		if str(c.name).begins_with("Dust"):
			for mi in c.find_children("*", "GeometryInstance3D", true, false):
				(mi as GeometryInstance3D).layers = 1          # the dust glows by itself: keep it on the normal layer
	KIT.stalactites(_holder, _field, Vector3(-80.0, 6.0, -50.0), 6.0, 18, 3)
	KIT.glow_moss(_holder, _field, Vector3(-77.0, 4.0, -47.5), 1.4)
	KIT.crystals(_holder, KIT.floor_below(_field, Vector3(-74.5, 4.0, -53.5)), KIT.CRYSTAL, 6, 4)


func _eyes(parent: Node3D, at: Vector3, size: float) -> void:
	var white := _mat(Color(1, 1, 1), 0.5)
	var dark := _mat(Color(0.08, 0.04, 0.12))
	for side in [-1, 1]:
		var e := at + Vector3(side * size * 0.9, 0, 0)
		_mesh(parent, _sph(size * 0.55), white, e)
		_mesh(parent, _sph(size * 0.3), dark, e + Vector3(0, 0, size * 0.35))


func _grotto() -> void:
	# Giant mushrooms to climb, each cap a little higher, up to a shelf in the north-east corner
	var g := Node3D.new()
	g.name = "Mushroom Grotto"
	_holder.add_child(g)
	var stem := _mat(Color(0.88, 0.85, 0.96))
	var caps := [Color(0.75, 0.5, 1.0), Color(1.0, 0.5, 0.8), Color(0.55, 0.85, 1.0), Color(0.75, 0.5, 1.0)]
	var spots := [Vector3(-64.0, 4.0, -46.0), Vector3(-62.0, 5.0, -43.0), Vector3(-59.5, 6.0, -45.5), Vector3(-60.5, 7.0, -40.5)]
	for i in spots.size():
		var top: Vector3 = spots[i]
		var h: float = top.y - FLOOR
		var b := StaticBody3D.new()
		b.name = "Mushroom%d" % (i + 1)
		g.add_child(b)
		b.position = Vector3(top.x, FLOOR, top.z)
		_mesh(b, _cyl(0.32, 0.45, h), stem, Vector3(0, h * 0.5, 0))
		var cap := MeshInstance3D.new()
		var sp := _sph(1.25, 1.0)
		sp.is_hemisphere = true
		cap.mesh = sp
		cap.material_override = _mat(caps[i], 0.9)
		b.add_child(cap)
		cap.position.y = h - 0.05
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 1.2
		cy.height = 0.3
		cs.shape = cy
		cs.position.y = h - 0.1
		b.add_child(cs)
		var light := OmniLight3D.new()
		light.light_color = caps[i]
		light.light_energy = 0.7
		light.omni_range = 4.0
		light.position.y = h + 0.6
		b.add_child(light)
	var shelf := _solid_box(g, Vector3(3.0, 0.8, 2.6), Vector3(-58.0, 7.9, -42.5), _mat(KIT.ROCK), 0.0)
	shelf.name = "Shelf"
	KIT.in_the_dark(g)
	for c in g.find_children("*", "GeometryInstance3D", true, false):
		if (c as GeometryInstance3D).material_override is StandardMaterial3D and \
				((c as GeometryInstance3D).material_override as StandardMaterial3D).emission_enabled:
			(c as GeometryInstance3D).layers = 1               # glowing caps glow whatever the light
	KIT.mushrooms(_holder, _field, Vector3(-62.0, 4.0, -48.0), 8, 5)
	KIT.mushrooms(_holder, _field, Vector3(-57.5, 4.0, -46.0), 6, 6, Color(1.0, 0.5, 0.8))
	KIT.stalactites(_holder, _field, Vector3(-61.0, 6.0, -44.0), 4.5, 10, 7)


func _pool() -> void:
	# Deep blue water round the island; water.gd makes it wadeable / swimmable, and a glowing bed shows its depth
	var g := Node3D.new()
	g.name = "Crystal Pool"
	_holder.add_child(g)
	var water := Node3D.new()
	water.name = "Water"
	water.set_script(WATER)
	var outline: Array[Vector4] = [Vector4(POOL.x, POOL.z, POOL_R.x + 0.4, POOL_R.y + 0.4)]
	water.set("ellipses", outline)
	water.set("water_y", POOL_Y)
	g.add_child(water)
	var surf := MeshInstance3D.new()
	surf.name = "Surface"
	var disc := _cyl(1.0, 1.0, 0.04, 32)
	surf.mesh = disc
	var wm := _mat(Color(0.3, 0.7, 0.95), 0.35, 0.45)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	surf.material_override = wm
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(surf)
	surf.position = Vector3(POOL.x, POOL_Y, POOL.z)
	surf.scale = Vector3(POOL_R.x + 0.6, 1.0, POOL_R.y + 0.6)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.85, 1.0)
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = Vector3(POOL.x, POOL_Y - 1.2, POOL.z)
	g.add_child(light)
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		KIT.crystals(_holder, KIT.floor_below(_field, Vector3(POOL.x + cos(a) * 6.0, 4.0, POOL.z + sin(a) * 4.0)),
			Color(0.5, 0.85, 1.0), 5, 20 + k, 1.2)
	# A flat stone on the island's top to stand on
	var top := _solid_box(g, Vector3(2.0, 0.3, 2.0), Vector3(POOL.x, 3.0, POOL.z), _mat(KIT.ROCK.lightened(0.1)))
	top.name = "Island"
	KIT.in_the_dark(top)


func _crack() -> void:
	# Glow bridges from each edge out to the pillar, a flat top on the pillar, and a glow from far down the pit
	var g := Node3D.new()
	g.name = "Deep Crack"
	_holder.add_child(g)
	var y := FLOOR + 0.05
	KIT.glow_bridge(g, Vector3(CRACK.x + CRACK_HALF + 0.6, y, CRACK.z), Vector3(CRACK.x + 1.1, y, CRACK.z))
	var west := KIT.glow_bridge(g, Vector3(CRACK.x - 1.1, y, CRACK.z), Vector3(CRACK.x - CRACK_HALF - 0.6, y, CRACK.z))
	west.name = "Glow Bridge West"
	var top := _solid_box(g, Vector3(2.4, 0.4, 2.4), Vector3(CRACK.x, FLOOR - 0.15, CRACK.z), _mat(KIT.ROCK.lightened(0.1)))
	top.name = "Pillar Top"
	KIT.in_the_dark(top)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.4, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	glow.position = Vector3(CRACK.x + 2.5, PIT_FLOOR + 1.0, CRACK.z)
	g.add_child(glow)
	KIT.crystals(_holder, Vector3(CRACK.x + 2.5, PIT_FLOOR + 0.5, CRACK.z + 1.0), Color(0.7, 0.5, 1.0), 6, 40, 1.4)


func _taproot_hollow() -> void:
	_taproot = taproot_model(taproot_awake())
	_taproot.name = "The Old Taproot"
	_holder.add_child(_taproot)
	_taproot.position = TAPROOT
	_taproot.rotation.y = PI * 0.5                           # facing east, towards the crack he's heard you cross
	var waker := Node3D.new()                                # Pip's glow reaching him wakes him (pip_glow.gd "glow_wake")
	waker.name = "Waker"
	waker.set_script(TAPROOT_WAKER)
	waker.set("caves", self)
	waker.set("awake", taproot_awake())
	_taproot.add_child(waker)
	waker.position = Vector3(1.4, 2.2, 0)
	var spot := USE_SPOT.make(Vector3(1.6, 0, 0), _taproot_offer, _talk, 2.6, 2.4)
	spot.name = "Taproot Talk"  # (not "Talk": that name is for townsfolk talk spots)
	_taproot.add_child(spot)
	KIT.mushrooms(_holder, _field, TAPROOT + Vector3(2.0, 1.0, 2.8), 7, 8, Color(0.55, 0.95, 1.0))


const TAPROOT_WAKER := preload("res://scripts/taproot_waker.gd")


func wake_taproot() -> void:
	if taproot_awake() or not is_instance_valid(_taproot):
		return
	Dialogue.set_flag("ug_taproot_woken")
	var lids := _taproot.get_node_or_null("Face/Lids") as Node3D
	var eyes := _taproot.get_node_or_null("Face/Eyes") as Node3D
	if lids:
		lids.visible = false
	if eyes:
		eyes.visible = true
	Game.message("Something very old and very big just opened its eyes...")
	Juice.blip("chime", 0.7, -6.0)


func _taproot_offer() -> String:
	return "talk to the Old Taproot" if taproot_awake() else "listen to the snoring"


func _talk() -> void:
	var spot := _taproot.get_node_or_null("Taproot Talk") as Node3D
	if not taproot_awake():
		Dialogue.say(spot, "???", ["(A huge root, snoring very slowly.)",
			"(Too dark! If only you had a light...)"], "ug_snore")
		return
	Dialogue.say(spot, "The Old Taproot", lines(), "ug_taproot")


func lines() -> Array:
	# What the Old Taproot says, from first hello to after the spores
	if given():
		return ["Ahh, {player}. My Glowcaps love your garden!"]
	var n := spores_found()
	var out: Array = []
	if not Dialogue.flags.has("ug_taproot_met"):
		Dialogue.set_flag("ug_taproot_met")
		out.append_array(["Mmmh? A LIGHT? How lovely!",
			"I'm the Old Taproot. Every plant here grows from me.",
			"I lost four glowing spores in the dark.",
			"Will you find them?"])
		if not Dialogue.flags.has("undergardens_start"):
			Dialogue.set_flag("undergardens_start")
	if n < SPORES.size():
		out.append("%d of my four spores! Keep looking." % n
			if n > 0 else "Your glow will show the way.")
		return out
	out.append_array(["All FOUR! Oh, they're warm!",
		{"do": "Farm/Caves.hand_in"}])
	return out


func hand_in() -> Array:
	# The four spores back: Glowcap seeds for your garden, once
	if given() or spores_found() < SPORES.size():
		return []
	Dialogue.set_flag("ug_taproot_given")                   # finishes the quest (reward: sparkles)
	Farm.give_seeds("glowcap", GIVE_SEEDS)
	Game.save_game()
	var lights := _taproot.get_node_or_null("Glow") as OmniLight3D if is_instance_valid(_taproot) else null
	if lights:
		lights.light_energy = 2.5
	return ["Here, Glowcap seeds for your garden!",
		"(You got %d Glowcap seeds!)" % GIVE_SEEDS]


func _collect(flag: String) -> void:
	if has_spore(flag):
		return
	Dialogue.set_flag(flag)
	if not Dialogue.flags.has("undergardens_start"):
		Dialogue.set_flag("undergardens_start")
	var p := _spores.get(flag) as Node3D
	if is_instance_valid(p):
		Fx.burst(_holder, p.global_position + Vector3(0, 0.4, 0), SPORE_COLOUR, 14, 0.06, 2.0)
		p.queue_free()
	_spores.erase(flag)
	var n := spores_found()
	Juice.chime_pickup()
	Game.message("A Glowcap spore! (%d of %d)" % [n, SPORES.size()] if n < SPORES.size()
		else "All four! Take them to the Old Taproot.")
	Game.save_game()


# -----------------------------------------------------------------------------
# Models (static, for captures and tests)
# -----------------------------------------------------------------------------
static func spore_model() -> Node3D:
	# A glowing blue puffball with a little cap of tiny dots, bobbing (the bob is its child's y)
	var root := Node3D.new()
	var g := Node3D.new()
	g.name = "Bob"
	root.add_child(g)
	_mesh(g, _sph(0.28), _mat(SPORE_COLOUR, 1.8, 0.9), Vector3(0, 0.35, 0))
	for k in 6:
		var a := k * TAU / 6.0
		_mesh(g, _sph(0.05), _mat(Color(1, 1, 1), 2.0), Vector3(cos(a) * 0.22, 0.48, sin(a) * 0.22))
	var light := OmniLight3D.new()
	light.light_color = SPORE_COLOUR
	light.light_energy = 1.0
	light.omni_range = 3.0
	light.position.y = 0.4
	g.add_child(light)
	return root


static func taproot_model(awake := false) -> Node3D:
	# The hill's oldest root: a great gnarled trunk coming down out of the ceiling into the floor, bending at its foot,
	# with a kind old face in its bark (lids shut while he sleeps), a mossy beard and little roots all round
	var root := Node3D.new()
	var bark := _mat(BARK)
	var dark := _mat(BARK.darkened(0.35))
	_mesh(root, _cyl(1.3, 1.6, 9.0, 12), bark, Vector3(0, 4.5, 0))
	for k in 6:                                               # feet spreading into the floor
		var a := k * TAU / 6.0
		_mesh(root, _cyl(0.25, 0.55, 2.6, 8), bark, Vector3(cos(a) * 1.6, 0.4, sin(a) * 1.6),
			Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
	# The face, on his +x side
	var face := Node3D.new()
	face.name = "Face"
	root.add_child(face)
	face.position = Vector3(1.35, 2.4, 0)
	face.rotation.y = PI * 0.5
	_mesh(face, _sph(0.32, 0.4), dark, Vector3(0, -0.15, 0.1), Vector3.ZERO, Vector3(1.0, 0.6, 0.6))        # nose knot
	_mesh(face, _cyl(0.5, 0.5, 0.08, 16), dark, Vector3(0, -0.7, 0.05), Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.35))
	var eyes := Node3D.new()
	eyes.name = "Eyes"
	face.add_child(eyes)
	var lids := Node3D.new()
	lids.name = "Lids"
	face.add_child(lids)
	for side in [-1, 1]:
		var e := Vector3(side * 0.42, 0.3, 0.05)
		_mesh(eyes, _sph(0.2), _mat(Color(1.0, 0.95, 0.75), 1.2), e)
		_mesh(eyes, _sph(0.1), _mat(Color(0.1, 0.06, 0.04)), e + Vector3(0, 0, 0.15))
		_mesh(lids, _sph(0.22, 0.12), dark, e + Vector3(0, -0.02, 0.06))
	eyes.visible = awake
	lids.visible = not awake
	# Mossy beard
	for k in 7:
		_mesh(face, _cyl(0.08, 0.02, 0.9 + (k % 3) * 0.3, 6), _mat(Color(0.35, 0.75, 0.5)),
			Vector3(-0.45 + k * 0.15, -1.25, 0.1))
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(0.55, 0.95, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	glow.position = Vector3(2.2, 2.0, 0)
	root.add_child(glow)
	return root


func _dress() -> void:
	# A few more cave things along the tunnels, so every stretch has something glowing to walk towards
	KIT.glow_moss(_holder, _field, Vector3(-91.0, 4.0, -50.5), 1.0)
	KIT.glow_moss(_holder, _field, Vector3(-68.0, 4.0, -48.5), 1.0)
	KIT.glow_moss(_holder, _field, Vector3(-65.0, 4.0, -34.8), 1.0)
	KIT.glow_moss(_holder, _field, Vector3(-83.0, 4.0, -34.0), 1.0)
	KIT.crystals(_holder, KIT.floor_below(_field, Vector3(-99.5, 4.0, -40.0)), KIT.CRYSTAL, 5, 50)
	KIT.stalactites(_holder, _field, Vector3(-74.0, 6.0, -31.0), 5.0, 10, 9)
	KIT.stalactites(_holder, _field, Vector3(-96.5, 6.0, -37.5), 3.5, 8, 11)
