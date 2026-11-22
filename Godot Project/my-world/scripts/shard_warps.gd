extends Node3D

# The Warp Rings on Shard Isle (Hayden, 22 Nov 2026: "you dont really get to see [the islands] from the players
# perspective. Maybe we can add a portaling minigame that gives you options to choose from and only brings you to the
# correct spot after trial and error", "we may have to add more islands with teleporting spots"). Put in at play time
# by scripts/shard_isle.gd setup() (WARPS.place(self)), so the scene wasn't rebuilt.
#
# On the main island stands a **Warp Circle**: four little rings, green, blue, pink and gold. Step into one
# (Interact) and you're whisked to another floating island. Only one ring at each circle takes you on; the others take
# you to a **lookout** (a small rock out in the sky with a view of the islands from somewhere new) whose one ring takes
# you back. A ring you've tried that went the wrong way goes dim, so it's trial and error that always gets there:
#   the Main Island  ->  Skyhook Isle (high over everything, looking down)
#                    ->  Underside Isle (deep under the islands, looking up at the hanging crystals)
#                    ->  Prism Isle (far off, with the Prism Chest: sparkles and Remnants, once)
# Every warp island also has a white ring straight back to the Main Island. Once you've reached Prism Isle the right
# ring at each circle shines with a star, so it's easy to go again. The islands are built like the builder's own
# (tools/build_shard_isle.gd _island, names "Islet Warp ..."), so the detail pipeline dresses them in the baked rock.
# Nothing that's already there moves (Hayden's "keep the forever floating").
#
# (No class_name: tools run with --script compile class_name scripts before the autoloads exist. Load it.)

const USE_SPOT := preload("res://scripts/use_spot.gd")

const COLOURS := {
	"green": Color(0.2, 0.85, 0.35), "blue": Color(0.25, 0.5, 1.0),
	"pink": Color(1.0, 0.3, 0.75), "gold": Color(1.0, 0.7, 0.1), "white": Color(0.9, 0.9, 1.0),
}
const RING_ORDER := ["green", "blue", "pink", "gold"]

# The islands: where its top's middle is, how big, its name, which way you face when you land (towards `look`), and
# where its Warp Circle stands on it (from its middle). "main" is the builder's Main Island.
const ISLANDS := {
	"main": {"at": Vector3(0, 0, 0), "name": "the Main Island", "circle": Vector3(-5.0, 0, -5.5)},
	"skyhook": {"at": Vector3(12, 20, 22), "r": 5.0, "name": "Skyhook Isle", "look": Vector3(0, 0, -3),
		"circle": Vector3(1.6, 0, 1.2)},
	"underside": {"at": Vector3(-14, -24, -10), "r": 5.0, "name": "Underside Isle", "look": Vector3(0, -6, 0),
		"circle": Vector3(-1.4, 0, -1.6)},
	"prism": {"at": Vector3(-40, 12, -40), "r": 6.5, "name": "Prism Isle", "look": Vector3(0, 0, -3),
		"circle": Vector3(-1.5, 0, -1.5)},
	"overlook": {"at": Vector3(36, 9, 14), "r": 3.2, "name": "Echo Overlook", "look": Vector3(0, 0, -3), "lookout": true},
	"drift": {"at": Vector3(0, 3, 40), "r": 3.2, "name": "Drift Rock", "look": Vector3(0, 0, -3), "lookout": true},
	"perch": {"at": Vector3(30, -12, -30), "r": 3.2, "name": "Low Perch", "look": Vector3(0, -3, 0), "lookout": true},
}
# The circles: which ring goes where. One ring at each takes you on; the others to a lookout.
const CIRCLES := {
	"main": {"green": "overlook", "blue": "drift", "pink": "skyhook", "gold": "perch"},
	"skyhook": {"green": "perch", "blue": "underside", "pink": "overlook", "gold": "drift", "white": "main"},
	"underside": {"green": "drift", "blue": "perch", "pink": "overlook", "gold": "prism", "white": "main"},
	"prism": {"white": "main"},
}
const RIGHT := {"main": "pink", "skyhook": "blue", "underside": "gold"}   # the ring at each circle that takes you on
const CHEST_SPARKLES := 12
const CHEST_REMNANTS := 2
const RING_SPREAD := 2.4               # the rings stand in an arc this far round the circle's middle

var world: Node3D                      # Shard Isle
var world_id := "shard_isle"
var came_from := "main"                # where a lookout's ring takes you back to
var tried := {}                        # "<circle>:<colour>" -> true: rings tried this visit that went the wrong way
var warps := 0                         # (for tests) how many times you've warped this visit
var _rings := {}                       # "<circle>:<colour>" -> the ring's Node3D


static func place(w: Node3D) -> Node3D:
	var s = (load("res://scripts/shard_warps.gd") as GDScript).new()
	s.name = "Warps"
	s.world = w
	s.world_id = str(w.get("world_id"))
	w.add_child(s)
	s._build()
	# Under Underside Isle there's a lot further to fall than the island's own catch allowed
	w.set("fall_below", minf(float(w.get("fall_below")), -36.0))
	return s


func _build() -> void:
	for id: String in ISLANDS:
		var i: Dictionary = ISLANDS[id]
		if id != "main":
			_island(id, i)
	for id: String in ISLANDS:
		var i: Dictionary = ISLANDS[id]
		if i.get("lookout", false):
			_ring(id, "back", top(id) - _away(id) * 1.9, COLOURS.white, landing(id))   # (behind you as you land)
		elif CIRCLES.has(id):
			_circle(id)
	if found_prism():
		_chest_opened()
	_refresh()


# Where things are ------------------------------------------------------------------------------------------------
func top(id: String) -> Vector3:
	return ISLANDS[id].at


func landing(id: String) -> Vector3:
	# Where you land: a little in from the island's edge on the side its view lies, so nothing of the island itself
	# hides the view (from high up the island's own ground filled the picture); its rings are behind you
	var i: Dictionary = ISLANDS[id]
	if id == "main":
		return Vector3(-2.0, 1.0, -9.5)
	var r := float(i.r)
	return top(id) + _away(id) * r * 0.55 + Vector3(0, 1.0, 0)


func _away(id: String) -> Vector3:
	# The way the island's view lies (flat), from its middle
	var i: Dictionary = ISLANDS[id]
	var to: Vector3 = Vector3(i.get("look", Vector3.ZERO)) - top(id)
	to.y = 0.0
	return to.normalized() if to.length() > 0.1 else Vector3.FORWARD


func ring_at(circle: String, colour: String) -> Node3D:
	return _rings.get(circle + ":" + colour)


func ring_to(circle: String, colour: String) -> String:
	if colour == "back":
		return came_from
	return str(CIRCLES[circle].get(colour, ""))


func found_prism() -> bool:
	return Portals.has_found(world_id, "warp_prism")


func is_dim(circle: String, colour: String) -> bool:
	return tried.has(circle + ":" + colour)


# Warping ---------------------------------------------------------------------------------------------------------
func warp(circle: String, colour: String) -> void:
	var to := ring_to(circle, colour)
	if to == "":
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	if ISLANDS[to].get("lookout", false):
		came_from = circle
		if RIGHT.get(circle, "") != colour:
			tried[circle + ":" + colour] = true
	var from_at := player.global_position
	var c: Color = COLOURS.get(colour, COLOURS.white)
	Fx.burst(world, from_at + Vector3(0, 1.0, 0), c, 26, 0.08, 4.0, -1.0, 0.8)
	var land := landing(to)
	player.global_position = land
	player.velocity = Vector3.ZERO
	var look: Vector3 = Vector3(ISLANDS[to].get("look", Vector3(0, 0, -3)))
	var d := look - land
	var yaw := atan2(-d.x, -d.z)                     # (like arriving at a marker: models face +Z, the camera behind)
	var visual := player.get("visual") as Node3D
	if visual:
		visual.rotation.y = yaw + PI
	var arm := player.get("spring_arm") as Node3D
	if arm:
		arm.rotation.y = yaw
	warps += 1
	_flash(c)
	Fx.burst(world, land + Vector3(0, 0.5, 0), c, 26, 0.08, 4.0, -1.0, 0.8)
	Juice.blip("whoosh", 1.1, -4.0)
	Juice.rumble(0.25, 0.2)
	var i: Dictionary = ISLANDS[to]
	if to == "prism" and not found_prism():
		Portals.note_found(world_id, "warp_prism")
		Game.message("Prism Isle! You found the way.")
		Juice.blip("chime", 1.2, -3.0)
	elif i.get("lookout", false):
		Game.message("%s. What a view! Try another ring." % i.name)
	else:
		Game.message(str(i.name).capitalize() if to == "main" else str(i.name) + "!")
	_refresh()


func _flash(c: Color) -> void:
	# A quick wash of the ring's colour over the screen (soft with Reduce flashing)
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(c, 0.35 if Settings.reduce_flashing else 0.7)
	layer.add_child(rect)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.45)
	tw.tween_callback(layer.queue_free)


func _ring_offer(circle: String, colour: String) -> String:
	if colour == "back":
		return "go back through the ring"
	if colour == "white":
		return "go back to the Main Island"
	return "step into the %s ring" % colour


# The Prism Chest -------------------------------------------------------------------------------------------------
func chest_open() -> bool:
	return Portals.has_found(world_id, "warp_chest")


func _chest_offer() -> String:
	return "open the Prism Chest" if not chest_open() else ""


func open_chest() -> void:
	if chest_open():
		return
	Portals.note_found(world_id, "warp_chest")
	if not Portals.practice:
		Game.add_sparkles(CHEST_SPARKLES, "the Prism Chest")
		Remnants.add(CHEST_REMNANTS, "Remnants!")
	var chest := world.get_node_or_null("Islet Warp Prism/Prism Chest") as Node3D
	if chest:
		Fx.burst(world, chest.global_position + Vector3(0, 1.0, 0), COLOURS.gold, 30, 0.08, 4.0, -2.0, 1.0)
	Juice.blip("sparkle", 1.2, -4.0)
	_chest_opened()


func _chest_opened() -> void:
	var lid := world.get_node_or_null("Islet Warp Prism/Prism Chest/Lid") as Node3D
	if lid:
		lid.rotation.x = -1.6


func _refresh() -> void:
	# Tried rings that went the wrong way go dim; once Prism Isle's found the right ones wear a star
	for key: String in _rings:
		var g := _rings[key] as Node3D
		if not is_instance_valid(g):
			continue
		var parts := key.split(":")
		var dim := tried.has(key)
		var swirl := g.get_node_or_null("Swirl") as MeshInstance3D
		if swirl:
			(swirl.material_override as StandardMaterial3D).emission_energy_multiplier = 0.1 if dim else 0.7
		var light := g.get_node_or_null("Glow") as OmniLight3D
		if light:
			light.light_energy = 0.15 if dim else 1.2
		var star := g.get_node_or_null("Star") as Node3D
		if star:
			star.visible = found_prism() and RIGHT.get(parts[0], "") == parts[1]


# Building --------------------------------------------------------------------------------------------------------
func _mat(c: Color, rough := 0.85, glow := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _named(m: StandardMaterial3D, n: String) -> StandardMaterial3D:
	m.resource_name = n
	return m


func _cyl(top_r: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _island(id: String, i: Dictionary) -> void:
	# Built like the builder's floating islands (tools/build_shard_isle.gd _island), so it looks the same and the
	# detail pipeline (detail_props.gd dress_shard_isle) gives it the baked rock: a mossy disc on a cone of rock with
	# a tip, glowing crystals hanging under it, and a solid top
	var r := float(i.r)
	var depth := 3.0 + r * 0.6
	var g := Node3D.new()
	g.name = "Islet Warp " + str(i.name).replace(" Isle", "").replace(" ", "")
	world.add_child(g)
	g.position = top(id)
	_put(g, _cyl(r, r * 0.96, 0.6, 32), _named(_mat(Color(0.36, 0.72, 0.6), 0.9), "Shard Moss"), Vector3(0, -0.3, 0))
	var rock := _named(_mat(Color(0.52, 0.46, 0.68), 0.95), "Shard Rock")
	_put(g, _cyl(r * 0.95, r * 0.2, depth, 14), rock, Vector3(0, -0.6 - depth / 2.0, 0))
	_put(g, _cyl(r * 0.25, 0.05, depth * 0.5, 8), rock, Vector3(0, -0.6 - depth * 1.2, 0))
	var glow := _named(_mat(Color(0.4, 0.95, 0.5), 0.15, 0.7), "Shard Glow")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for k in int(r) + 1:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.7) * r
		var h := rng.randf_range(0.8, 2.0)
		var cr := rng.randf_range(0.15, 0.3)
		var c := _cyl(cr * 0.15, cr, h, 6)
		c.rings = 1
		_put(g, c, glow, Vector3(cos(a) * d, -0.8 - depth * (1.0 - d / r) * 0.6 - h / 2.0, sin(a) * d), Vector3(PI, 0, 0))
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 0.6
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(0, -0.3, 0)
	g.add_child(body)
	# An invisible low wall round the rim, so the view's safe to walk up to
	var fence := StaticBody3D.new()
	fence.name = "Edge Fence"
	for k in 16:
		var a := k * TAU / 16.0
		var w := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(r * TAU / 16.0 + 0.3, 1.4, 0.3)
		w.shape = b
		w.position = Vector3(cos(a) * (r - 0.1), 0.7, sin(a) * (r - 0.1))
		w.rotation.y = -a + PI / 2.0
		fence.add_child(w)
	g.add_child(fence)
	var sign := Label3D.new()
	sign.name = "Name"
	sign.text = str(i.name)
	sign.font_size = 40
	sign.pixel_size = 0.008
	sign.outline_size = 12
	sign.modulate = Color(0.95, 0.9, 1.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.position = _away(id).cross(Vector3.UP) * -r * 0.7 + Vector3(0, 2.0, 0)   # (off to one side of the view)
	g.add_child(sign)
	if id == "prism":
		_prism_dressing(g, r)


func _prism_dressing(g: Node3D, r: float) -> void:
	# Prism Isle: a ring of tall rainbow crystals and the Prism Chest in the middle
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var c := Color.from_hsv(float(k) / 7.0, 0.75, 0.95)
		var gem := MeshInstance3D.new()
		gem.mesh = Remnants.crystal_mesh(0.3, 2.2)
		var m := Remnants.crystal_mat()
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = 0.6
		gem.material_override = m
		gem.position = Vector3(cos(a) * (r - 1.2), 1.1, sin(a) * (r - 1.2))
		gem.rotation = Vector3(0.12 * sin(a), 0, 0.12 * cos(a))
		g.add_child(gem)
	var chest := Node3D.new()
	chest.name = "Prism Chest"
	chest.position = Vector3(1.5, 0, 1.5)
	g.add_child(chest)
	var wood := _mat(Color(0.55, 0.42, 0.75), 0.6)
	var gold := _mat(Color(1.0, 0.82, 0.4), 0.3, 0.4)
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.7, 0.8)
	_put(chest, box, wood, Vector3(0, 0.35, 0))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.7, -0.4)
	chest.add_child(lid)
	var lb := BoxMesh.new()
	lb.size = Vector3(1.24, 0.25, 0.84)
	_put(lid, lb, wood, Vector3(0, 0.12, 0.42))
	var band := BoxMesh.new()
	band.size = Vector3(0.14, 0.74, 0.84)
	_put(chest, band, gold, Vector3(0, 0.36, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position.y = 1.4
	chest.add_child(light)
	var solid := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 0.8, 0.8)
	cs.shape = bs
	cs.position.y = 0.4
	solid.add_child(cs)
	chest.add_child(solid)
	var spot := USE_SPOT.make(Vector3.ZERO, _chest_offer, open_chest, 2.0, 1.6)
	spot.name = "Spot"
	chest.add_child(spot)


func _circle(id: String) -> void:
	# A Warp Circle: its rings in an arc facing in, a ring of stones round where you stand, and a sign
	var middle: Vector3 = top(id) + Vector3(ISLANDS[id].circle)
	var colours: Array = []
	for c in RING_ORDER:
		if CIRCLES[id].has(c):
			colours.append(c)
	if CIRCLES[id].has("white"):
		colours.append("white")
	var out := Vector3(middle.x - top(id).x, 0, middle.z - top(id).z)
	if out.length() < 0.5:
		out = -_away(id)
	out = out.normalized()
	var n := colours.size()
	for k in n:
		var t := 0.0 if n == 1 else (float(k) / float(n - 1) - 0.5)
		var dir := out.rotated(Vector3.UP, t * 2.2)
		_ring(id, colours[k], middle + dir * RING_SPREAD, COLOURS[colours[k]], middle)
	var pad := _mat(Color(0.42, 0.36, 0.58), 0.5)
	var disc := MeshInstance3D.new()
	disc.name = "Warp Circle Pad"
	disc.mesh = _cyl(1.3, 1.3, 0.06, 24)
	disc.material_override = pad
	disc.position = middle + Vector3(0, 0.03, 0)
	world.add_child(disc)


func _ring(circle: String, colour: String, at: Vector3, c: Color, face := Vector3.INF) -> void:
	# One warp ring: a glowing hoop on a little stone foot, a swirl inside it and a star over it (shown when it's the
	# way on and you've been to Prism Isle). Its Interact spot sits just in front of it.
	var g := Node3D.new()
	g.name = "Warp Ring %s %s" % [circle, colour]
	world.add_child(g)
	g.position = at
	if face == Vector3.INF:
		face = top(circle) - _away(circle) * 3.0
	var d := Vector3(face.x - at.x, 0, face.z - at.z)
	if d.length() > 0.05:
		g.rotation.y = atan2(d.x, d.z)                 # its front (+Z) towards where you stand
	var foot := _mat(Color(0.3, 0.26, 0.4), 0.7)
	_put(g, _cyl(0.45, 0.6, 0.35, 8), foot, Vector3(0, 0.17, 0))
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.72
	hoop.outer_radius = 0.86
	hoop.rings = 24
	_put(g, hoop, _mat(c, 0.25, 0.9), Vector3(0, 1.25, 0), Vector3(PI / 2.0, 0, 0))
	var swirl := _put(g, _cyl(0.72, 0.72, 0.04, 24), _mat(c, 0.1, 0.7, 0.45), Vector3(0, 1.25, 0), Vector3(PI / 2.0, 0, 0))
	swirl.name = "Swirl"
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = c
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 1.25, 0.4)
	g.add_child(light)
	var star := MeshInstance3D.new()
	star.name = "Star"
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	star.mesh = sm
	star.material_override = _mat(Color(1.0, 0.9, 0.4), 0.2, 3.0)
	star.position = Vector3(0, 2.45, 0)
	star.visible = false
	g.add_child(star)
	var solid := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 0.35
	cs.shape = cyl
	cs.position.y = 0.17
	solid.add_child(cs)
	g.add_child(solid)
	var spot := USE_SPOT.make(Vector3(0, 0, 0.9), _ring_offer.bind(circle, colour), warp.bind(circle, colour), 1.1, 2.4)
	spot.name = "Spot"
	g.add_child(spot)
	_rings[circle + ":" + colour] = g


func _process(delta: float) -> void:
	for g in _rings.values():
		var swirl := (g as Node3D).get_node_or_null("Swirl") as Node3D
		if swirl:
			swirl.rotate_object_local(Vector3.UP, delta * 1.5)
