extends RefCounted

# The Void's Museum is an indoor/outdoor museum (Hayden, 20 Nov 2026: "Maybe we can make the museum an indoor/outdoor
# museum?"). scripts/falls_museum.gd calls place() once it has grown and turned the dome, and this lays out the
# Museum Garden on the open lawn between its door, the lake shore and the path to the Secret Gardens:
#   - a Garden Door in the dome's side (a little portico with glass doors), joined to the Garden Door inside the
#     Museum (tools/build_interiors.gd _museum), so you can walk out of the galleries and into the garden
#   - a vine arbor from that door, then a paved walk curving round to the Museum's front door, so it's one loop
#   - five big things too large for a glass case, each on its own spot with a short title: the Sky Stone (a meteorite
#     with glowing cracks), the First Saucer (crashed and half buried), a Star Beast Footprint (sunk in the lawn, walk
#     in it), a Fossil Shell carved in a standing stone, and a Giant Geode split open with crystals glowing inside
#   - lamps along the walk and flowers round the exhibits
# Angles here are round the dome from the way its front door faces (THETA 0), so it all follows the dome if it moves.
# Nothing is in the built town.tscn: like the stream and the water gate, it's put in as the town loads.

const LOCAL_DOOR := 0.687          # where round the dome the Garden Door is (matches the gap in the wall inside)
const WALK_R := 12.5               # the paved walk's distance from the dome's middle
const WALK_FROM := -0.2            # the walk runs from just past the front door...
const WALK_TO := LOCAL_DOOR        # ...round to the Garden Door's arbor
const EXIT_META := "museum_garden_exit"     # set on Game by the Garden Door inside, for a few seconds
const EXIT_FRESH_MS := 20000

# Each exhibit: where round the dome (from the front door), how far out, and which way it turns to face the walk
const EXHIBITS := {
	"sky_stone": {"theta": -0.36, "r": 10.4, "title": "The Sky Stone"},
	"footprint": {"theta": 0.0, "r": 14.4, "title": "Star Beast Footprint"},
	"geode": {"theta": 0.24, "r": 15.8, "title": "Giant Geode"},
	"fossil": {"theta": 0.4, "r": 10.3, "title": "Fossil Shell"},
	"saucer": {"theta": 0.5, "r": 15.7, "title": "The First Saucer"},
}


static func place(scene: Node, m: Node3D) -> Node3D:
	if scene.get_node_or_null("Museum Grounds"):
		return null
	var root := Node3D.new()
	root.name = "Museum Grounds"
	scene.add_child(root)
	var mats := _materials()
	_garden_door(scene, root, m, mats)
	_arbor(scene, root, m, mats)
	_walk(scene, root, m, mats)
	for id: String in EXHIBITS:
		var e: Dictionary = EXHIBITS[id]
		var at := spot(scene, m, float(e["theta"]), float(e["r"]))
		var g := Node3D.new()
		g.name = "Exhibit " + String(e["title"])
		g.set_meta("exhibit", id)
		root.add_child(g)
		g.global_position = at
		# Turned so its front looks back in at the dome (the walk runs between them)
		var to_dome := m.global_position - at
		g.rotation.y = atan2(to_dome.x, to_dome.z)
		match id:
			"sky_stone": _sky_stone(g, mats)
			"footprint": _footprint(g, mats)
			"geode": _geode(g, mats)
			"fossil": _fossil(g, mats)
			"saucer": _saucer(g, mats)
		_flowers(g, mats, id != "footprint")
		_sign(g, String(e["title"]), Vector3(1.9 if id != "fossil" else 1.3, 0, 1.4), mats)
	_sign(root, "Museum Garden", Vector3.ZERO, mats, spot(scene, m, LOCAL_DOOR + 0.2, 10.6), m)
	_exit_here(scene, root)
	# (25 Nov 2026) The exhibits, the walk and the arbor wear the baked surface patches (rock, stone, wood, brushed
	# metal), laid on in world space; the glows, glass, flowers and signs stay as they are
	load("res://scripts/detail_props.gd").dress_place(root, GARDEN_SURFACES)
	return root


# Which of the garden's materials wear which patch (detail_props.gd dress_place), and how big it's laid on
const GARDEN_SURFACES := [["Sky Stone Rock", "rock", 1.2], ["Geode Rock", "rock", 1.2], ["Fossil Sandstone", "rock"],
	["Fossil Shell", "stone", 2.0], ["Garden Stone", "stone"], ["Garden Paving", "stone", 1.4],
	["Garden Paving Dark", "stone", 1.4], ["Garden Wood", "maple"], ["Saucer Metal", "brushed_metal"],
	["Saucer Underside", "brushed_metal"]]


static func direction(m: Node3D, theta: float) -> Vector3:
	# Straight out from the dome's middle, theta round from the way its front door faces
	var d := m.global_basis.orthonormalized() * Vector3(sin(theta), 0, cos(theta))
	return Vector3(d.x, 0, d.z).normalized()


static func spot(scene: Node, m: Node3D, theta: float, r: float) -> Vector3:
	var p := m.global_position + direction(m, theta) * r
	return Vector3(p.x, ground(scene, p, m), p.z)


static func ground(scene: Node, at: Vector3, skip: Node = null) -> float:
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 30.0, at.z), Vector3(at.x, at.y - 30.0, at.z))
	var ex: Array[RID] = []
	for n: Node in [skip, scene.get_node_or_null("Museum Grounds")]:
		if n:
			for b in n.find_children("*", "CollisionObject3D", true, false):
				ex.append((b as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else at.y


static func _exit_here(scene: Node, root: Node3D) -> void:
	# Someone who just came out through the Garden Door arrived at the Museum's front (the town has no marker of
	# theirs when the player appears: these grounds are only made afterwards), so move them to the arbor, turned
	# the way player.gd turns her at any marker (only her model and the camera)
	if not Game.has_meta(EXIT_META):
		return
	var when := int(Game.get_meta(EXIT_META))
	Game.remove_meta(EXIT_META)
	if Time.get_ticks_msec() - when > EXIT_FRESH_MS:
		return
	var out := root.get_node_or_null("FromMuseumGarden") as Node3D
	var player := scene.find_child("Player", true, false) as Node3D
	if out == null or player == null:
		return
	player.global_position = out.global_position + Vector3(0, 0.2, 0)
	player.rotation = Vector3.ZERO
	var yaw := out.global_rotation.y
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.y = yaw + PI
	var arm = player.get("spring_arm")
	if arm is Node3D:
		(arm as Node3D).rotation.y = yaw


# ---------------------------------------------------------------------------------------------------------------------
# The Garden Door, the arbor and the walk
# ---------------------------------------------------------------------------------------------------------------------

static func _garden_door(scene: Node, root: Node3D, m: Node3D, mats: Dictionary) -> void:
	# A little portico standing out of the dome's side, glass doors glowing in it, and the door itself (an Area3D
	# like every town door) going in to the Museum's Garden Door
	var d := direction(m, LOCAL_DOOR)
	var r := 7.0 * m.global_basis.get_scale().x
	var base := m.global_position + d * (r + 0.05)
	var g := Node3D.new()
	g.name = "Garden Door"
	root.add_child(g)
	g.global_position = Vector3(base.x, ground(scene, base, m), base.z)
	g.rotation.y = atan2(d.x, d.z)                     # its +Z looks out into the garden
	for s: float in [-1.0, 1.0]:
		_solid_box(g, "Portico Pillar", Vector3(0.45, 3.3, 0.45), Vector3(s * 1.45, 1.65, 0.35), mats.stone)
		_box(g, "Pillar Cap", Vector3(0.6, 0.18, 0.6), Vector3(s * 1.45, 3.35, 0.35), mats.trim)
		_box(g, "Pillar Foot", Vector3(0.6, 0.2, 0.6), Vector3(s * 1.45, 0.1, 0.35), mats.trim)
	_box(g, "Portico Lintel", Vector3(3.6, 0.4, 1.2), Vector3(0, 3.6, 0.1), mats.stone)
	for k in 5:                                         # a stepped little pediment on top
		var w := 3.4 - k * 0.68
		_box(g, "Pediment", Vector3(w, 0.22, 1.0), Vector3(0, 3.91 + k * 0.22, 0.05), mats.stone)
	_box(g, "Portico Back", Vector3(2.5, 3.0, 0.9), Vector3(0, 1.5, -0.45), mats.dark)
	for s: float in [-1.0, 1.0]:
		_box(g, "Garden Door Glass", Vector3(1.1, 2.6, 0.06), Vector3(s * 0.58, 1.3, 0.02), mats.door_glass)
		_box(g, "Door Frame", Vector3(0.08, 2.7, 0.1), Vector3(s * 1.17, 1.35, 0.05), mats.trim)
		_box(g, "Door Handle", Vector3(0.05, 0.4, 0.08), Vector3(s * 0.14, 1.2, 0.09), mats.gold)
	_box(g, "Door Frame Top", Vector3(2.4, 0.1, 0.1), Vector3(0, 2.66, 0.05), mats.trim)
	_box(g, "Door Step", Vector3(3.2, 0.12, 1.3), Vector3(0, 0.06, 0.55), mats.trim)
	var title := _label(g, "Garden", Vector3(0, 3.6, 0.72), 40)
	title.name = "Garden Door Sign"
	var lamp := OmniLight3D.new()
	lamp.name = "Garden Door Glow"
	lamp.light_color = Color(1.0, 0.92, 0.7)
	lamp.light_energy = 0.9
	lamp.omni_range = 5.0
	g.add_child(lamp)
	lamp.position = Vector3(0, 2.4, 1.2)
	var door := Area3D.new()
	door.name = "Door"
	door.set_script(load("res://scripts/door.gd"))
	door.set("destination", "res://scenes/interiors/museum.tscn")
	door.set("spawn", "GardenEntrance")
	door.set("place_name", "Museum")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 3.0, 1.2)
	cs.shape = shape
	door.add_child(cs)
	g.add_child(door)
	door.position = Vector3(0, 1.5, 0.75)
	# Where you come out: in the arbor, facing out into the garden
	var out := Marker3D.new()
	out.name = "FromMuseumGarden"
	root.add_child(out)
	var p := spot(scene, m, LOCAL_DOOR, r + 2.6)
	out.global_position = p + Vector3(0, 1.0, 0)
	out.rotation.y = atan2(d.x, d.z) + PI              # player.gd: a marker's -Z is the way she faces


static func _arbor(scene: Node, root: Node3D, m: Node3D, mats: Dictionary) -> void:
	# Three arches of vines over the way out of the Garden Door, flowers hanging off them
	var d := direction(m, LOCAL_DOOR)
	var side := Vector3(d.z, 0, -d.x)
	var g := Node3D.new()
	g.name = "Vine Arbor"
	root.add_child(g)
	for k in 3:
		var c := spot(scene, m, LOCAL_DOOR, 9.7 + k * 1.3)
		var arch := Node3D.new()
		arch.name = "Arbor Arch %d" % (k + 1)
		g.add_child(arch)
		arch.global_position = c
		arch.rotation.y = atan2(side.x, side.z)         # its +Z runs across the way, so its posts stand either side
		for s: float in [-1.0, 1.0]:
			_solid_cyl(arch, "Arbor Post", 0.09, 2.6, Vector3(0, 1.3, s * 1.55), mats.wood)
		for j in 9:                                    # the arch's top, and the vines and flowers along it
			var a := PI * j / 8.0
			var p := Vector3(0, 2.6 + sin(a) * 0.7, -cos(a) * 1.55)
			var seg := _box(arch, "Arbor Top", Vector3(0.14, 0.14, 0.62), p, mats.wood)
			seg.rotation.x = -a + PI / 2
			for v in 2:
				var leaf := _sphere(arch, "Vine Leaves", 0.26 + 0.06 * sin(j * 1.7 + v + k), mats.vine,
					p + Vector3((v - 0.5) * 0.3, 0.08, 0.1 * sin(j + v)))
				leaf.scale = Vector3(1.0, 0.7, 1.0)
			if j % 2 == 1:
				var hang: Material = mats.blooms[(j + k) % mats.blooms.size()]
				_sphere(arch, "Vine Flower", 0.1, hang, p + Vector3(0.2, -0.3, 0))
				_sphere(arch, "Vine Flower", 0.08, hang, p + Vector3(-0.15, -0.5, 0.05))
		for s: float in [-1.0, 1.0]:                    # vines climbing the posts
			for j in 5:
				_sphere(arch, "Vine Leaves", 0.17, mats.vine, Vector3(0.05 * s, 0.3 + j * 0.5, s * 1.55 + 0.05))


static func _walk(scene: Node, root: Node3D, m: Node3D, mats: Dictionary) -> void:
	# Flat paving stones (not solid: they lie on the lawn) from the arbor round to the front door, lamps along it, and
	# a short run of paving out of the arbor to meet it
	var g := Node3D.new()
	g.name = "Garden Walk"
	root.add_child(g)
	var span := WALK_TO - WALK_FROM
	var n := int(span * WALK_R / 1.05)
	for k in n + 1:
		var theta := WALK_FROM + span * k / n
		_paving(scene, g, m, theta, WALK_R, mats, k)
	for k in 3:
		_paving(scene, g, m, LOCAL_DOOR, 8.9 + k * 1.15, mats, k + 50, true)
	for k in 4:
		var theta := WALK_FROM + span * (k + 0.5) / 4.0
		var at := spot(scene, m, theta, WALK_R + 1.45)
		var lamp := Node3D.new()
		lamp.name = "Garden Lamp %d" % (k + 1)
		g.add_child(lamp)
		lamp.global_position = at
		_solid_cyl(lamp, "Lamp Post", 0.08, 2.6, Vector3(0, 1.3, 0), mats.iron)
		_box(lamp, "Lamp Foot", Vector3(0.35, 0.2, 0.35), Vector3(0, 0.1, 0), mats.iron)
		_sphere(lamp, "Lamp Globe", 0.24, mats.lamp_glow, Vector3(0, 2.8, 0))
		_box(lamp, "Lamp Cap", Vector3(0.4, 0.08, 0.4), Vector3(0, 3.06, 0), mats.iron)
		var light := OmniLight3D.new()
		light.name = "Lamp Light"
		light.light_color = Color(1.0, 0.88, 0.6)
		light.light_energy = 0.7
		light.omni_range = 6.0
		lamp.add_child(light)
		light.position = Vector3(0, 2.7, 0)


static func _paving(scene: Node, g: Node3D, m: Node3D, theta: float, r: float, mats: Dictionary, k: int,
		across := false) -> void:
	var at := spot(scene, m, theta, r)
	var d := direction(m, theta)
	var stone := MeshInstance3D.new()
	stone.name = "Paving %d" % k
	var b := BoxMesh.new()
	b.size = Vector3(2.0 if not across else 2.4, 0.08, 0.95 if not across else 1.05)
	stone.mesh = b
	stone.material_override = mats.paving if k % 3 != 1 else mats.paving_dark
	g.add_child(stone)
	stone.global_position = at + Vector3(0, 0.03, 0)
	# Along the walk its long side runs out from the dome; out of the arbor it runs across the way
	stone.rotation.y = atan2(d.x, d.z) + (PI / 2 if across else 0.0)
	stone.rotation.y += 0.04 * sin(k * 2.1)
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------------------------------------------------
# The exhibits (each built round its own spot, its front at +Z towards the dome)
# ---------------------------------------------------------------------------------------------------------------------

static func _sky_stone(g: Node3D, mats: Dictionary) -> void:
	# A big dark lumpy meteorite on a round plinth, with cracks glowing like it's still warm from falling
	_solid_cyl(g, "Plinth", 1.35, 0.5, Vector3(0, 0.25, 0), mats.stone)
	_cyl(g, "Plinth Rim", 1.45, 0.12, Vector3(0, 0.52, 0), mats.trim)
	var rock := Node3D.new()
	rock.name = "Sky Stone"
	g.add_child(rock)
	rock.position = Vector3(0, 1.45, 0)
	var lumps := [[Vector3(0, 0, 0), 1.0], [Vector3(0.55, 0.25, 0.2), 0.65], [Vector3(-0.5, -0.1, -0.3), 0.7],
		[Vector3(0.1, 0.55, -0.35), 0.55], [Vector3(-0.2, -0.35, 0.5), 0.6]]
	for l: Array in lumps:
		var s := _sphere(rock, "Stone Lump", l[1], mats.meteor, l[0])
		s.scale = Vector3(1.0, 0.82, 0.95)
	for k in 7:                                         # the glowing cracks over its front and top
		var a := k * 0.9
		var crack := _box(rock, "Glow Crack", Vector3(0.06, 0.5 + 0.2 * sin(k), 0.05),
			Vector3(sin(a) * 0.62, 0.3 * cos(a * 1.3), cos(a) * 0.62 + 0.25), mats.ember)
		crack.rotation = Vector3(0.4 * sin(k), a, 0.6 * cos(k * 1.7))
	var body := StaticBody3D.new()
	body.name = "Sky Stone Body"
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.05
	cs.shape = sh
	body.add_child(cs)
	rock.add_child(body)
	var glow := OmniLight3D.new()
	glow.name = "Sky Stone Glow"
	glow.light_color = Color(1.0, 0.5, 0.25)
	glow.light_energy = 0.6
	glow.omni_range = 3.5
	g.add_child(glow)
	glow.position = Vector3(0, 1.5, 1.2)


static func _footprint(g: Node3D, mats: Dictionary) -> void:
	# A giant three-toed footprint pressed into the lawn: walk right into it (it isn't solid, and it's only a few
	# centimetres deep), with a ring of little stones round it
	var print_node := Node3D.new()
	print_node.name = "Footprint"
	g.add_child(print_node)
	var heel := _cyl(print_node, "Print Heel", 1.25, 0.04, Vector3(0, 0.02, -0.2), mats.print_mud)
	heel.scale = Vector3(1.0, 1.0, 1.35)
	var edge := _cyl(print_node, "Print Heel Edge", 1.36, 0.02, Vector3(0, 0.01, -0.2), mats.print_edge)
	edge.scale = Vector3(1.0, 1.0, 1.35)
	for t in 3:                                          # three toes, fanned out to the front
		var a := (t - 1) * 0.55
		var p := Vector3(sin(a) * 2.0, 0.025, cos(a) * 2.0 - 0.1)
		var toe := _cyl(print_node, "Print Toe", 0.5, 0.04, p, mats.print_mud)
		toe.scale = Vector3(0.8, 1.0, 1.5)
		toe.rotation.y = a
		var claw := _box(print_node, "Print Claw", Vector3(0.18, 0.04, 0.5), p + Vector3(sin(a), 0, cos(a)) * 0.95,
			mats.print_mud)
		claw.rotation.y = a
	for k in 14:                                         # little stones round it, like a rope round a museum piece
		var a := TAU * k / 14.0
		_sphere(g, "Print Stone", 0.13, mats.stone, Vector3(cos(a) * 2.9, 0.06, sin(a) * 3.0 + 0.2))


static func _geode(g: Node3D, mats: Dictionary) -> void:
	# A boulder split open towards the walk, its inside packed with glowing purple crystals
	_solid_cyl(g, "Plinth", 1.25, 0.35, Vector3(0, 0.18, 0), mats.stone)
	var shell := MeshInstance3D.new()
	shell.name = "Geode Shell"
	var hs := SphereMesh.new()
	hs.radius = 1.25
	hs.height = 2.5
	hs.radial_segments = 20
	hs.rings = 10
	hs.is_hemisphere = true
	shell.mesh = hs
	shell.material_override = mats.geode_rock
	g.add_child(shell)
	shell.position = Vector3(0, 1.3, -0.1)
	shell.rotation.x = -PI / 2                           # the cut face looks out at the walk (+Z)
	var inside := _cyl(g, "Geode Inside", 1.08, 0.08, Vector3(0, 1.3, -0.05), mats.geode_in)
	inside.rotation.x = PI / 2
	for k in 16:                                         # crystals pointing out of the hollow
		var a := TAU * k / 16.0
		var rr := 0.25 + 0.65 * fmod(k * 0.618, 1.0)
		var p := Vector3(cos(a) * rr, 1.3 + sin(a) * rr, 0.05)
		var c := MeshInstance3D.new()
		c.name = "Geode Crystal"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.09 + 0.04 * sin(k)
		cm.height = 0.38 + 0.14 * cos(k * 1.3)
		cm.radial_segments = 6
		c.mesh = cm
		c.material_override = mats.crystal
		g.add_child(c)
		c.position = p
		c.rotation = Vector3(PI / 2 - 0.3 * sin(a), 0, -a * 0.2)
	var body := StaticBody3D.new()
	body.name = "Geode Body"
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.2
	cs.shape = sh
	body.add_child(cs)
	g.add_child(body)
	body.position = Vector3(0, 1.25, -0.3)
	var glow := OmniLight3D.new()
	glow.name = "Geode Glow"
	glow.light_color = Color(0.75, 0.45, 1.0)
	glow.light_energy = 0.9
	glow.omni_range = 4.0
	g.add_child(glow)
	glow.position = Vector3(0, 1.3, 1.0)


static func _fossil(g: Node3D, mats: Dictionary) -> void:
	# A sandy standing stone with a great spiral shell carved in its face
	_solid_box(g, "Fossil Base", Vector3(2.0, 0.3, 0.9), Vector3(0, 0.15, 0), mats.stone)
	_solid_box(g, "Fossil Stone", Vector3(1.7, 2.1, 0.55), Vector3(0, 1.35, 0), mats.sand)
	var top := _box(g, "Fossil Top", Vector3(1.5, 0.3, 0.5), Vector3(0, 2.5, 0), mats.sand)
	top.rotation.z = 0.08
	for k in 34:                                         # the shell's spiral, little ridges growing outwards
		var a := k * 0.42
		var rr := 0.08 + k * 0.019
		var bump := _sphere(g, "Fossil Ridge", 0.05 + k * 0.0032, mats.fossil,
			Vector3(cos(a) * rr, 1.4 + sin(a) * rr, 0.3))
		bump.scale = Vector3(1.0, 1.0, 0.5)


static func _saucer(g: Node3D, mats: Dictionary) -> void:
	# The first saucer anyone found here: tipped over and half buried, its dome cracked, its little lights still
	# blinking now and then (a pulsing glow)
	var ship := Node3D.new()
	ship.name = "First Saucer"
	g.add_child(ship)
	ship.position = Vector3(0, 0.35, -0.2)
	ship.rotation = Vector3(0.32, 0.4, 0.12)
	var hull := _cyl(ship, "Saucer Hull", 1.9, 0.42, Vector3.ZERO, mats.metal)
	(hull.mesh as CylinderMesh).top_radius = 1.2
	var under := _cyl(ship, "Saucer Under", 1.85, 0.3, Vector3(0, -0.34, 0), mats.metal_dark)
	(under.mesh as CylinderMesh).bottom_radius = 0.9
	_cyl(ship, "Saucer Rim", 1.98, 0.1, Vector3(0, -0.1, 0), mats.trim)
	var dome := _sphere(ship, "Saucer Dome", 0.85, mats.saucer_glass, Vector3(0, 0.3, 0))
	dome.scale = Vector3(1.0, 0.7, 1.0)
	var crack := _box(ship, "Dome Crack", Vector3(0.03, 0.5, 0.03), Vector3(0.35, 0.65, 0.55), mats.dark)
	crack.rotation.z = 0.6
	for k in 8:
		var a := TAU * k / 8.0
		_sphere(ship, "Saucer Light", 0.09, mats.saucer_light, Vector3(cos(a) * 1.75, -0.08, sin(a) * 1.75))
	for k in 9:                                          # the dirt it ploughed up when it came down
		var a := PI * (0.15 + 0.7 * k / 8.0) + PI
		var clod := _sphere(g, "Dirt Heap", 0.38 + 0.12 * sin(k * 2.3), mats.dirt, Vector3(cos(a) * 1.9, 0.05, sin(a) * 1.6 - 0.4))
		clod.scale = Vector3(1.0, 0.45, 1.0)
	var body := StaticBody3D.new()
	body.name = "Saucer Body"
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.8
	sh.height = 1.3
	cs.shape = sh
	body.add_child(cs)
	g.add_child(body)
	body.position = Vector3(0, 0.55, -0.2)


static func _flowers(g: Node3D, mats: Dictionary, near: bool) -> void:
	# A few clumps of flowers round the exhibit's foot (not solid)
	var ring := 1.75 if near else 3.3
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var c := Vector3(cos(a) * ring, 0, sin(a) * ring)
		if c.z > 0.9 and absf(c.x) < 1.2:
			continue                                     # leave its front open towards the walk
		var leaves := _sphere(g, "Flower Leaves", 0.24, mats.vine, c + Vector3(0, 0.12, 0))
		leaves.scale = Vector3(1.3, 0.6, 1.3)
		for j in 3:
			_sphere(g, "Flower", 0.08, mats.blooms[(k + j) % mats.blooms.size()],
				c + Vector3(cos(j * 2.1) * 0.15, 0.28, sin(j * 2.1) * 0.15))


static func _sign(parent: Node3D, text: String, local: Vector3, mats: Dictionary, world := Vector3.INF,
		m: Node3D = null) -> void:
	# A little post with a board and the exhibit's title (only the title: Hayden wants less reading)
	var s := Node3D.new()
	s.name = "Sign " + text
	parent.add_child(s)
	if world != Vector3.INF:
		s.global_position = world
		if m:
			var out := world - m.global_position
			s.rotation.y = atan2(out.x, out.z)            # its board faces out, the way you come through the arbor
	else:
		s.position = local
	_box(s, "Sign Post", Vector3(0.1, 1.1, 0.1), Vector3(0, 0.55, 0), mats.wood)
	_box(s, "Sign Board", Vector3(1.5 if text.length() < 16 else 2.0, 0.42, 0.08), Vector3(0, 1.15, 0), mats.board)
	var l := _label(s, text, Vector3(0, 1.15, 0.06), 30)
	l.modulate = Color(0.25, 0.18, 0.12)
	l.outline_size = 0
	var back := _label(s, text, Vector3(0, 1.15, -0.06), 30)
	back.modulate = Color(0.25, 0.18, 0.12)
	back.outline_size = 0
	back.rotation.y = PI


# ---------------------------------------------------------------------------------------------------------------------
# Little helpers
# ---------------------------------------------------------------------------------------------------------------------

static func _materials() -> Dictionary:
	var blooms: Array = []
	for c: Color in [Color(1.0, 0.55, 0.75), Color(0.98, 0.85, 0.35), Color(0.7, 0.55, 1.0), Color(0.95, 0.95, 1.0)]:
		blooms.append(_mat("Garden Flower", c, 0.6))
	return {
		"stone": _mat("Garden Stone", Color(0.86, 0.84, 0.8), 0.8),
		"trim": _mat("Garden Trim", Color(0.96, 0.92, 0.82), 0.6),
		"dark": _mat("Garden Shadow", Color(0.12, 0.1, 0.16), 0.9),
		"door_glass": _mat("Garden Door Glass", Color(0.65, 0.9, 1.0), 0.1, 0.0, 0.7),
		"gold": _mat("Garden Gold", Color(0.98, 0.78, 0.3), 0.3, 0.9),
		"wood": _mat("Garden Wood", Color(0.5, 0.33, 0.2), 0.75),
		"board": _mat("Garden Sign Board", Color(0.92, 0.84, 0.66), 0.8),
		"vine": _mat("Garden Vine", Color(0.38, 0.72, 0.36), 0.8),
		"blooms": blooms,
		"paving": _mat("Garden Paving", Color(0.82, 0.78, 0.72), 0.85),
		"paving_dark": _mat("Garden Paving Dark", Color(0.72, 0.68, 0.64), 0.85),
		"iron": _mat("Garden Iron", Color(0.2, 0.19, 0.24), 0.45, 0.7),
		"lamp_glow": _mat("Garden Lamp Glow", Color(1.0, 0.9, 0.65), 0.3, 0.0, 1.6),
		"meteor": _mat("Sky Stone Rock", Color(0.24, 0.21, 0.24), 0.9, 0.3),
		"ember": _mat("Sky Stone Ember", Color(1.0, 0.45, 0.2), 0.4, 0.0, 2.4),
		"print_mud": _mat("Footprint Mud", Color(0.3, 0.24, 0.2), 0.95),
		"print_edge": _mat("Footprint Edge", Color(0.45, 0.38, 0.3), 0.95),
		"geode_rock": _mat("Geode Rock", Color(0.5, 0.46, 0.5), 0.9),
		"geode_in": _mat("Geode Inside", Color(0.35, 0.18, 0.5), 0.5, 0.0, 0.5),
		"crystal": _mat("Geode Crystal", Color(0.8, 0.55, 1.0), 0.15, 0.0, 1.4),
		"sand": _mat("Fossil Sandstone", Color(0.86, 0.74, 0.55), 0.9),
		"fossil": _mat("Fossil Shell", Color(0.7, 0.58, 0.42), 0.8),
		"metal": _mat("Saucer Metal", Color(0.72, 0.74, 0.8), 0.35, 0.8),
		"metal_dark": _mat("Saucer Underside", Color(0.42, 0.42, 0.5), 0.5, 0.7),
		"saucer_glass": _mat("Saucer Dome", Color(0.55, 0.95, 0.85), 0.1, 0.0, 0.4),
		"saucer_light": _mat("Saucer Light", Color(0.5, 1.0, 0.7), 0.3, 0.0, 2.0),
		"dirt": _mat("Saucer Dirt", Color(0.42, 0.33, 0.25), 0.95),
	}


static func _mat(name: String, color: Color, rough := 0.7, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	return mi


static func _sphere(parent: Node3D, name: String, r: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	return mi


static func _cyl(parent: Node3D, name: String, r: float, h: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	mi.mesh = c
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	return mi


static func _solid_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := _box(parent, name, size, pos, material)
	var body := StaticBody3D.new()
	body.name = name + " Body"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	return mi


static func _solid_cyl(parent: Node3D, name: String, r: float, h: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := _cyl(parent, name, r, h, pos, material)
	var body := StaticBody3D.new()
	body.name = name + " Body"
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	return mi


static func _label(parent: Node3D, text: String, pos: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.name = "Label"
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.modulate = Color(1.0, 0.96, 0.88)
	parent.add_child(l)
	l.position = pos
	return l
