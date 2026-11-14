extends Node3D

# The Gloop Kingdom, the Gloop King's own domain (Hayden's day 1 playtest, 11 Nov 2026: "I want the gloop king to have
# his own domain instead of just being in a field"). A level of its own (scenes/bosses/gloop_kingdom.tscn, made by
# tools/build_gloop_kingdom.gd: only this script, an Entrance and the player). Everything else is built here when it
# loads, so it can be changed without rebuilding anything.
#
# The way in is the Gloop Gate out in the Void's west fields, where he used to hold court (scripts/bosses.gd): a big
# mound of goo with a crown on top. Inside, from the gate (south) to his throne (north, +z):
#   - The Bog Road: a raised road of gold flagstones over a bubbling goo bog, with goo lanterns, his banners and
#     two Royal Guard Gloops in little gold helmets. Falling into the bog doesn't hurt: it's just slow, sticky going.
#   - The Goo Moat: wide and sticky; bouncy goo-bubble stepping pads hop you over it (or wade the long way round).
#   - The Palace Gate: two gold towers with crowns on and a gooey arch.
#   - The Royal Court: a round floor of gold and green tiles inside dripping goo-falls, his courtiers watching from the
#     stands (they wobble and cheer for him), and his throne on a dais at the far end. He sits there until you come
#     into his court, then shouts and comes down to fight (scripts/gloop_king.gd, the same fight as before).
#   - Pop him and the Royal Treasure chest opens on the dais (sparkles, the first time each Void day: flag
#     "gloop_treasure_<visit day>"), and a goo bubble by the throne takes you home. He's back on your next visit.
# The way home is a goo bubble just inside the gate (and the one by the throne after he's popped): it puts you back in
# the west fields in front of the Gloop Gate (Bosses.GATE_OUT).

const KING_SCENE := "res://scenes/enemies/gloop_king.tscn"
const SLIME_FLOOD := preload("res://scripts/slime_flood.gd")
const GLOOP_SCENE := "res://scenes/enemies/gloop.tscn"
const USE_SPOT := preload("res://scripts/use_spot.gd")
const TOWN := "res://scenes/town/town.tscn"

const COURT := Vector3(0, 0, 88)              # the middle of the Royal Court
const COURT_RADIUS := 19.0
const THRONE := Vector3(0, 0, 103)            # the throne, on its dais at the court's far end
const MOAT_Z := Vector2(42, 56)               # the moat runs across from here to here
const WAKE_RANGE := 16.0                      # come this far into his court (from its middle) and he wakes up
const TREASURE := 12                          # sparkles in the Royal Treasure

var king: CharacterBody3D
var flood: Node3D                              # his court floods with goo in the fight (scripts/slime_flood.gd)
var awake := false
var treasure_open := false
var popped := false                            # he's been popped this visit (the treasure's open and a way home's up)
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _courtiers: Array[Node3D] = []
var _pads: Array[Node3D] = []
var _t := 0.0
var _chest: Node3D
var _home_bubble: Node3D


func _enter_tree() -> void:
	# The way in (and the player) stand just inside the gate, facing up the Bog Road
	# (a marker looks along its -Z, so the Entrance turns round to face up the road, which runs north along +Z)
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = Vector3(0, 1.0, 3.0)
			(n as Node3D).rotation.y = PI if n.name == "Entrance" else 0.0


func _ready() -> void:
	_rng.seed = 1029
	_environment()
	_ground()
	_bog_road()
	_moat()
	_palace_gate()
	_court()
	_throne()
	_walls()
	_add_king()
	_add_flood()
	_add_guards()
	_way_home(Vector3(0, 0, -1.5), "Way Out")
	_player = get_tree().get_first_node_in_group("player") as Node3D


# -----------------------------------------------------------------------------
# Little helpers
# -----------------------------------------------------------------------------
func _mat(name: String, c: Color, rough := 0.6, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _goo_mat() -> StandardMaterial3D:
	# The King's goo: glossy green with a gold glint (the same look as the Gloops, scripts/gloop.gd)
	var m := _mat("Royal Goo", Color(0.55, 0.78, 0.2), 0.12, 0.25, 0.1)
	m.rim_enabled = true
	m.rim = 0.6
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	return m


func _gold() -> StandardMaterial3D:
	return _mat("Royal Gold", Color(1.0, 0.78, 0.25), 0.25, 0.15, 0.8)


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


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(parent, bm, at, m)
	mi.name = name
	if solid:
		var bs := BoxShape3D.new()
		bs.size = size
		_solid(parent, name + " Body", bs, at)
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 24
	var mi := _mesh(parent, cm, at, m)
	mi.name = name
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(r_top, r_bottom)
		cs.height = h
		_solid(parent, name + " Body", cs, at)
	return mi


func _sign(parent: Node3D, text: String, at: Vector3, yaw := PI, size := 34) -> void:
	var post := _box(parent, "Sign Post", Vector3(0.2, 2.2, 0.2), at + Vector3(0, 1.1, 0), _mat("Sign Wood", Color(0.45, 0.3, 0.2)), false)
	post.name = "Sign Post"
	var board := Node3D.new()
	board.name = "Sign"
	board.position = at + Vector3(0, 2.1, 0)
	board.rotation.y = yaw
	parent.add_child(board)
	var back := BoxMesh.new()
	back.size = Vector3(3.4, 1.0, 0.12)
	_mesh(board, back, Vector3.ZERO, _mat("Sign Board", Color(0.3, 0.22, 0.35)))
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.88, 0.45)
	label.outline_size = 8
	label.outline_modulate = Color(0.12, 0.08, 0.15)
	# The writing faces along the board's +Z: a sign turned with yaw PI faces back down the Bog Road (-Z), towards you
	# as you come in. (It was on the far side, so you only saw the back of the board walking in: Hayden's 14 Nov 2026
	# playtest. tools/audit_signs.gd checks it.)
	label.position = Vector3(0, 0, 0.08)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 520
	board.add_child(label)


func _goo_zone(parent: Node3D, name: String, size: Vector3, at: Vector3) -> Area3D:
	# Sticky goo you can wade through (scripts/soft_zone.gd "goo": slow going, never any harm)
	var z := Area3D.new()
	z.name = name
	z.set_script(load("res://scripts/soft_zone.gd"))
	z.set("kind", "goo")
	z.set("speed_scale", 0.45)
	z.set("gravity_scale", 1.0)
	z.set("fall_cap", 30.0)
	z.set("color", Color(0.6, 0.85, 0.25, 0.9))
	z.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	z.add_child(cs)
	z.position = at
	parent.add_child(z)
	return z


# -----------------------------------------------------------------------------
# Sky, light and the ground
# -----------------------------------------------------------------------------
func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.16, 0.42)                   # a purple alien sky, going gooey green-gold low down
	sm.sky_horizon_color = Color(0.72, 0.86, 0.42)
	sm.ground_horizon_color = Color(0.45, 0.55, 0.3)
	sm.ground_bottom_color = Color(0.2, 0.25, 0.1)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.6, 0.45)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.name = "Kingdom Sky"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.92, 0.7)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	add_child(sun)


func _ground() -> void:
	# The whole kingdom sits on one flat floor; the bog and the moat are goo lying on it
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 260)
	var m := StandardMaterial3D.new()
	m.resource_name = "Bog Ground"
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.04
	noise.noise = n
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.26, 0.1))
	grad.set_color(1, Color(0.3, 0.4, 0.14))
	noise.color_ramp = grad
	m.albedo_texture = noise
	m.uv1_scale = Vector3(30, 30, 1)
	m.roughness = 0.9
	var mi := _mesh(g, plane, Vector3(0, 0, 60), m, false)
	mi.name = "Bog Floor"
	var bs := BoxShape3D.new()
	bs.size = Vector3(260, 2.0, 260)
	_solid(g, "Ground Body", bs, Vector3(0, -1.0, 60))
	# Far off: gooey hills with gold drips, so the kingdom sits in a bowl
	var hill := _mat("Goo Hills", Color(0.24, 0.42, 0.16), 0.3)
	for k in 22:
		var a := TAU * k / 22.0
		var r := _rng.randf_range(95.0, 120.0)
		var dome := SphereMesh.new()
		dome.radius = _rng.randf_range(22.0, 34.0)
		dome.height = dome.radius * _rng.randf_range(1.2, 1.8)
		_mesh(g, dome, Vector3(cos(a) * r, -dome.radius * 0.2, 60 + sin(a) * r), hill, false)


# -----------------------------------------------------------------------------
# The Bog Road
# -----------------------------------------------------------------------------
func _bog_road() -> void:
	var road := Node3D.new()
	road.name = "Bog Road"
	add_child(road)
	# The bog both sides: a goo surface a hair over the floor, sticky to wade
	for side in [-1.0, 1.0]:
		var goo := PlaneMesh.new()
		goo.size = Vector2(26, 40)
		var mi := _mesh(road, goo, Vector3(side * 17.0, 0.05, 20), _goo_mat(), false)
		mi.name = "Bog Goo"
		_goo_zone(road, "Bog", Vector3(26, 2.0, 40), Vector3(side * 17.0, 0.9, 20))
	# The road itself: gold flagstones on a causeway, flush with the ground (no step up out of the bog: you'd stick)
	_box(road, "Causeway", Vector3(8.0, 0.4, 42.0), Vector3(0, -0.15, 20), _mat("Causeway Stone", Color(0.52, 0.44, 0.62)))
	for k in 14:
		var stone := BoxMesh.new()
		stone.size = Vector3(7.2, 0.06, 2.6)
		_mesh(road, stone, Vector3(0, 0.08, 1.5 + k * 3.0), _mat("Gold Flagstone" if k % 2 == 0 else "Pale Flagstone",
			Color(0.95, 0.78, 0.35) if k % 2 == 0 else Color(0.88, 0.85, 0.62), 0.5, 0.0, 0.3 if k % 2 == 0 else 0.0), false)
	# Goo lanterns all along, and his banners
	for k in 6:
		for side in [-1.0, 1.0]:
			var at := Vector3(side * 4.6, 0, 4 + k * 7.0)
			_box(road, "Lantern Post", Vector3(0.25, 3.0, 0.25), at + Vector3(0, 1.5, 0), _gold(), true)
			var bulb := SphereMesh.new()
			bulb.radius = 0.4
			bulb.height = 0.8
			_mesh(road, bulb, at + Vector3(0, 3.3, 0), _mat("Goo Lantern", Color(0.7, 1.0, 0.35), 0.2, 2.5), false)
			if k % 2 == 1:
				_banner(road, at + Vector3(0, 0, 0) + Vector3(side * 0.6, 0, 0))
	# Bubbles plopping in the bog
	for k in 18:
		var b := SphereMesh.new()
		b.radius = _rng.randf_range(0.2, 0.6)
		b.height = b.radius * 2.0
		var side := -1.0 if k % 2 == 0 else 1.0
		var mi := _mesh(road, b, Vector3(side * _rng.randf_range(7.0, 28.0), 0.1, _rng.randf_range(2.0, 38.0)), _goo_mat(), false)
		mi.name = "Bog Bubble"
		mi.set_meta("phase", _rng.randf() * TAU)
	_sign(road, "THE GLOOP KINGDOM\nBy order of the King: NO POPPING", Vector3(-5.5, 0, 6.5), PI + 0.4, 30)


func _banner(parent: Node3D, at: Vector3) -> void:
	# A tall gold pole with a green banner and his crown on it
	_box(parent, "Banner Pole", Vector3(0.18, 5.2, 0.18), at + Vector3(0, 2.6, 0), _gold(), false)
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.06, 2.4, 1.3)
	_mesh(parent, cloth, at + Vector3(0, 3.6, 0.7), _mat("Royal Banner", Color(0.3, 0.6, 0.2)), false)
	var crown := _crown(1.0)
	crown.position = at + Vector3(0.06, 3.9, 0.7)
	crown.rotation.z = PI / 2.0
	crown.scale = Vector3.ONE * 0.35
	parent.add_child(crown)


func _crown(size: float) -> Node3D:
	# The King's crown: a gold band with five points and a red gem
	var c := Node3D.new()
	c.name = "Crown"
	var band := CylinderMesh.new()
	band.top_radius = size
	band.bottom_radius = size
	band.height = size * 0.6
	_mesh(c, band, Vector3.ZERO, _gold(), false)
	for k in 5:
		var a := TAU * k / 5.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = size * 0.32
		spike.height = size * 0.8
		_mesh(c, spike, Vector3(cos(a) * size * 0.85, size * 0.65, sin(a) * size * 0.85), _gold(), false)
	var gem := SphereMesh.new()
	gem.radius = size * 0.22
	gem.height = size * 0.44
	_mesh(c, gem, Vector3(0, 0, size * 1.02), _mat("Ruby", Color(0.95, 0.15, 0.25), 0.1, 0.8), false)
	return c


# -----------------------------------------------------------------------------
# The Goo Moat and its bouncy pads
# -----------------------------------------------------------------------------
func _moat() -> void:
	var moat := Node3D.new()
	moat.name = "Goo Moat"
	add_child(moat)
	var w := MOAT_Z.y - MOAT_Z.x
	var goo := PlaneMesh.new()
	goo.size = Vector2(90, w)
	var mi := _mesh(moat, goo, Vector3(0, 0.06, (MOAT_Z.x + MOAT_Z.y) / 2.0), _goo_mat(), false)
	mi.name = "Moat Goo"
	_goo_zone(moat, "Moat", Vector3(90, 2.0, w), Vector3(0, 0.9, (MOAT_Z.x + MOAT_Z.y) / 2.0))
	# Bouncy goo pads across it, in a little zig-zag, each a hop from the last
	var spots := [Vector3(0, 0.5, 44.5), Vector3(2.4, 0.9, 47.6), Vector3(-0.6, 1.3, 50.6), Vector3(1.8, 0.9, 53.6)]
	for k in spots.size():
		var pad := Node3D.new()
		pad.name = "Goo Pad %d" % (k + 1)
		pad.position = spots[k]
		moat.add_child(pad)
		var top := CylinderMesh.new()
		top.top_radius = 1.25
		top.bottom_radius = 1.45
		top.height = 0.5
		_mesh(pad, top, Vector3.ZERO, _mat("Goo Pad", Color(0.75, 0.95, 0.3), 0.1, 0.6), true)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.5
		stem.bottom_radius = 0.7
		stem.height = spots[k].y
		_mesh(pad, stem, Vector3(0, -spots[k].y / 2.0, 0), _goo_mat(), false)
		var cs := CylinderShape3D.new()
		cs.radius = 1.4
		cs.height = 0.5
		_solid(pad, "Pad Body", cs, Vector3.ZERO)
		_pads.append(pad)
	# Gold landings both sides
	_box(moat, "Near Landing", Vector3(10, 0.4, 2.0), Vector3(0, -0.15, MOAT_Z.x - 1.0), _mat("Causeway Stone", Color(0.52, 0.44, 0.62)))
	_box(moat, "Far Landing", Vector3(12, 0.4, 3.0), Vector3(0, -0.15, MOAT_Z.y + 1.5), _mat("Causeway Stone", Color(0.52, 0.44, 0.62)))
	_sign(moat, "Hop the pads\n(or wade, if you like sticky)", Vector3(5.5, 0, MOAT_Z.x - 2.5), PI - 0.5, 28)


# -----------------------------------------------------------------------------
# The Palace Gate and the Royal Court
# -----------------------------------------------------------------------------
func _palace_gate() -> void:
	var gate := Node3D.new()
	gate.name = "Palace Gate"
	gate.position = Vector3(0, 0, 63)
	add_child(gate)
	var stone := _mat("Palace Stone", Color(0.74, 0.62, 0.88), 0.7)
	for side in [-1.0, 1.0]:
		_cyl(gate, "Gate Tower", 2.2, 2.6, 11.0, Vector3(side * 6.5, 5.5, 0), stone)
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 3.0
		roof.height = 3.6
		_mesh(gate, roof, Vector3(side * 6.5, 12.8, 0), _goo_mat(), false)
		var crown := _crown(0.9)
		crown.position = Vector3(side * 6.5, 15.0, 0)
		gate.add_child(crown)
		# Goo running down each tower
		for k in 3:
			var drip := CapsuleMesh.new()
			drip.radius = 0.28
			drip.height = _rng.randf_range(2.5, 5.0)
			var a := -PI / 2.0 + (k - 1) * 0.6
			_mesh(gate, drip, Vector3(side * 6.5 + cos(a) * 2.3, 11.0 - drip.height / 2.0, sin(a) * 2.3), _goo_mat(), false)
	# The arch across, with the crown sign
	_box(gate, "Gate Arch", Vector3(10.8, 1.8, 2.2), Vector3(0, 9.6, 0), stone, true)
	var label := Label3D.new()
	label.text = "THE ROYAL COURT"
	label.font_size = 72
	label.pixel_size = 0.012
	label.modulate = Color(1.0, 0.85, 0.35)
	label.outline_size = 14
	label.outline_modulate = Color(0.15, 0.1, 0.05)
	label.position = Vector3(0, 9.6, -1.15)
	label.rotation.y = PI
	gate.add_child(label)
	# The road on through the gate to the court
	_box(gate, "Gate Road", Vector3(8.0, 0.4, 10.0), Vector3(0, -0.15, 0), _mat("Causeway Stone", Color(0.52, 0.44, 0.62)))


func _court() -> void:
	var court := Node3D.new()
	court.name = "Royal Court"
	court.position = COURT
	add_child(court)
	# The floor: rings of gold and green tiles, flush with the ground so you walk straight in
	var floor := CylinderMesh.new()
	floor.top_radius = COURT_RADIUS
	floor.bottom_radius = COURT_RADIUS
	floor.height = 0.4
	floor.radial_segments = 48
	_mesh(court, floor, Vector3(0, -0.15, 0), _mat("Court Green", Color(0.3, 0.6, 0.32), 0.4))
	var fs := CylinderShape3D.new()
	fs.radius = COURT_RADIUS
	fs.height = 0.4
	_solid(court, "Court Floor", fs, Vector3(0, -0.15, 0))
	for r in [15.0, 10.0, 5.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - 0.6
		ring.outer_radius = r
		ring.rings = 48
		var mi := _mesh(court, ring, Vector3(0, 0.06, 0), _gold(), false)
		mi.scale.y = 0.05
	# The wall round it, with goo-falls pouring down its inside, and the stands behind
	var stone := _mat("Palace Stone", Color(0.74, 0.62, 0.88), 0.7)
	var n := 28
	for k in n:
		var a := TAU * k / n
		var gap := absf(wrapf(a - PI / 2.0 * 3.0, -PI, PI)) < 0.32           # the way in from the gate (south)
		var at := Vector3(cos(a), 0, sin(a)) * (COURT_RADIUS + 0.6)
		if gap:
			continue
		var seg := _box(court, "Court Wall", Vector3(1.0, 6.0, TAU * (COURT_RADIUS + 0.6) / n + 0.2), at + Vector3(0, 3.0, 0), stone, true)
		seg.rotation.y = -a
		(court.get_child(court.get_child_count() - 1) as Node3D).rotation.y = -a
		if k % 3 == 0:
			var fall := BoxMesh.new()
			fall.size = Vector3(0.15, 5.6, 2.0)
			var f := _mesh(court, fall, Vector3(cos(a), 0, sin(a)) * (COURT_RADIUS - 0.05) + Vector3(0, 3.0, 0), _mat("Goo Fall", Color(0.6, 0.9, 0.25, 0.85), 0.05, 0.8), false)
			f.name = "Goo Fall"
			f.rotation.y = -a
			var pool := CylinderMesh.new()
			pool.top_radius = 1.4
			pool.bottom_radius = 1.6
			pool.height = 0.1
			_mesh(court, pool, Vector3(cos(a), 0, sin(a)) * (COURT_RADIUS - 1.0) + Vector3(0, 0.1, 0), _goo_mat(), false)
	# The stands, with his courtiers watching
	for k in 10:
		var a := PI / 2.0 * 3.0 + 0.7 + k * (TAU - 1.4) / 9.0
		var at := Vector3(cos(a), 0, sin(a)) * (COURT_RADIUS + 3.5)
		var step := _box(court, "Court Stand", Vector3(3.2, 6.6, 3.2), at + Vector3(0, 3.3, 0), stone, true)
		step.rotation.y = -a
		var gl := (load(GLOOP_SCENE) as PackedScene).instantiate() as Node3D
		gl.name = "Courtier %d" % (k + 1)                     # (not "Gloop …": they're watching, not fighting)
		gl.process_mode = Node.PROCESS_MODE_DISABLED
		court.add_child(gl)
		gl.position = at + Vector3(0, 6.6, 0)
		gl.look_at(court.global_position + Vector3(0, 6.6, 0), Vector3.UP, true)
		for c in gl.find_children("*", "CollisionShape3D", true, false):
			(c as CollisionShape3D).disabled = true
		gl.remove_from_group.call_deferred("enemies")         # (only watching: bubbles don't aim at them)
		_courtiers.append(gl)
	_sign(court, "Kneel before\nHIS GOOEYNESS", Vector3(5.0, 0.05, -COURT_RADIUS + 3.0), PI + 0.3, 30)


func _throne() -> void:
	var t := Node3D.new()
	t.name = "Throne"
	t.position = THRONE
	add_child(t)
	var stone := _mat("Palace Stone", Color(0.74, 0.62, 0.88), 0.7)
	# The dais: three steps up
	for k in 3:
		_cyl(t, "Dais %d" % (k + 1), 6.0 - k * 1.4, 6.0 - k * 1.4, 0.5, Vector3(0, 0.25 + k * 0.5 + 0.4, 0), stone if k != 2 else _gold())
	# The throne: a great gold chair with goo cushions and a tall back with his crown
	var gold := _gold()
	_box(t, "Throne Seat", Vector3(4.6, 1.2, 3.2), Vector3(0, 2.5, 0.6), gold, true)
	_box(t, "Throne Back", Vector3(5.0, 7.0, 0.8), Vector3(0, 5.4, 2.0), gold, true)
	for side in [-1.0, 1.0]:
		_box(t, "Throne Arm", Vector3(0.7, 1.4, 3.0), Vector3(side * 2.6, 3.4, 0.6), gold, true)
	var cushion := SphereMesh.new()
	cushion.radius = 2.0
	cushion.height = 1.2
	_mesh(t, cushion, Vector3(0, 3.2, 0.6), _goo_mat(), false)
	var crown := _crown(1.6)
	crown.position = Vector3(0, 9.4, 2.0)
	t.add_child(crown)
	for side in [-1.0, 1.0]:
		_banner(t, Vector3(side * 5.0, 1.9, 2.4))
	# The Royal Treasure, shut until he's popped
	_chest = Node3D.new()
	_chest.name = "Royal Treasure"
	_chest.position = Vector3(3.6, 1.9, -1.6)
	t.add_child(_chest)
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.8, 0.9)
	_mesh(_chest, box, Vector3(0, 0.4, 0), _mat("Chest Wood", Color(0.5, 0.28, 0.15)))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.8, 0.45)
	_chest.add_child(lid)
	var lid_m := BoxMesh.new()
	lid_m.size = Vector3(1.5, 0.3, 0.95)
	_mesh(lid, lid_m, Vector3(0, 0.15, -0.45), gold)
	var spot := USE_SPOT.make(Vector3(0, 0, -1.2), _treasure_offer, _open_treasure, 2.2, 1.8)
	spot.name = "Treasure Spot"
	_chest.add_child(spot)


func _walls() -> void:
	# Invisible walls round the whole kingdom, so nobody wanders off the edge of the world
	var edge := Node3D.new()
	edge.name = "WorldBounds Kingdom"
	add_child(edge)
	for w in [[Vector3(0, 5, -10), Vector3(100, 10, 1)], [Vector3(0, 5, 125), Vector3(100, 10, 1)],
			[Vector3(-48, 5, 57), Vector3(1, 10, 140)], [Vector3(48, 5, 57), Vector3(1, 10, 140)]]:
		var bs := BoxShape3D.new()
		bs.size = w[1]
		_solid(edge, "Edge", bs, w[0])
	# Gooey rock spires all round the edge so the walls look like something
	var rock := _mat("Goo Rock", Color(0.38, 0.26, 0.5), 0.5)
	for k in 40:
		var along := float(k) / 40.0
		var at: Vector3
		match k % 4:
			0:
				at = Vector3(lerpf(-46, 46, along), 0, -8)
			1:
				at = Vector3(lerpf(-46, 46, along), 0, 123)
			2:
				at = Vector3(-46, 0, lerpf(-8, 123, along))
			_:
				at = Vector3(46, 0, lerpf(-8, 123, along))
		var spire := CylinderMesh.new()
		spire.top_radius = _rng.randf_range(0.3, 1.2)
		spire.bottom_radius = _rng.randf_range(2.5, 4.5)
		spire.height = _rng.randf_range(8.0, 18.0)
		spire.radial_segments = 8
		_mesh(edge, spire, at + Vector3(0, spire.height / 2.0 - 0.5, 0), rock, false)


# -----------------------------------------------------------------------------
# The King, his guards, and the way home
# -----------------------------------------------------------------------------
func _add_king() -> void:
	king = (load(KING_SCENE) as PackedScene).instantiate() as CharacterBody3D
	king.name = "The Gloop King"                             # not "Gloop …", so finding Gloops by name skips him
	king.set("size", 2.2)
	king.set("color", Color(0.95, 0.78, 0.25))
	king.set("goldness", 0.7)
	king.set("stomps_to_defeat", 12)
	king.set("damage", 3)
	king.set("xp_reward", 40)
	king.set("wander_radius", 8.0)
	king.set("sight_range", 20.0)
	king.set("leash_range", COURT_RADIUS + 6.0)
	king.set("wander_speed", 1.0)
	king.set("chase_speed", 2.6)
	king.set("respawns", false)                              # (popped for this visit; he's back on the next one)
	king.process_mode = Node.PROCESS_MODE_DISABLED           # sat on his throne until you come into his court
	king.position = THRONE + Vector3(0, 3.25, 0.4)
	add_child(king)
	# Looking down the court (towards the gate, -z). Only his Visual turns: Gloops steer by turning the Visual to their
	# world heading (scripts/gloop.gd), so turning his whole body round as well left him walking backwards once the
	# fight started (Hayden's playtest, 14 Nov 2026).
	(king.get("visual") as Node3D).rotation.y = PI


func _add_flood() -> void:
	# The court's Lily Pads and the goo that floods it once the fight's on (Hayden, 14 Nov 2026: "Can we add a
	# mechanic where the arena fills with slime?")
	flood = SLIME_FLOOD.new()
	flood.name = "Slime Flood"
	flood.position = COURT
	add_child(flood)
	flood.call("build", COURT_RADIUS, _goo_mat(), _gold())
	flood.set("king", king)


func _add_guards() -> void:
	# Two Royal Guards on the Bog Road, and two more at the Palace Gate: Gloops in little gold helmets
	var spots := [Vector3(-2.5, 0.8, 22), Vector3(2.5, 0.8, 26), Vector3(-3.0, 0.8, 60), Vector3(3.0, 0.8, 60)]
	for k in spots.size():
		var g := (load(GLOOP_SCENE) as PackedScene).instantiate() as Node3D
		g.name = "Gloop Guard %d" % (k + 1)
		g.set("size", 1.3)
		g.set("stomps_to_defeat", 2)
		g.set("wander_radius", 2.5)
		g.set("respawn_clear", 25.0)
		g.position = spots[k]
		add_child(g)
		var helmet := SphereMesh.new()
		helmet.radius = 0.42
		helmet.height = 0.42
		helmet.is_hemisphere = true
		var vis := g.get_node_or_null("Visual") as Node3D
		var mi := _mesh(vis if vis else g, helmet, Vector3(0, 1.0, 0), _gold(), false)
		mi.name = "Guard Helmet"


func _way_home(at: Vector3, name: String) -> Node3D:
	# A big goo bubble you can step into to go home (back to the west fields, in front of the Gloop Gate)
	var b := Node3D.new()
	b.name = name
	b.position = at
	add_child(b)
	var ball := SphereMesh.new()
	ball.radius = 1.3
	ball.height = 2.6
	var mi := _mesh(b, ball, Vector3(0, 1.4, 0), _mat("Home Bubble", Color(0.7, 1.0, 0.5, 0.55), 0.05, 0.8), false)
	mi.name = "Bubble"
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "go home to the Void", go_home, 2.4, 3.2)
	spot.name = "Home Spot"
	b.add_child(spot)
	return b


func go_home() -> void:
	var out: Dictionary = Bosses.gate_out()
	Game.pending_message = "Back out in the west fields, by the Gloop Gate."
	Bosses.coming_out = true
	Game.go_to_point(TOWN, out.position, float(out.yaw), "the Void")


# -----------------------------------------------------------------------------
# Every frame: wobbly courtiers, bouncing pads, the King waking up
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	for k in _courtiers.size():
		var c := _courtiers[k]
		var cheer := 1.0 if awake and is_instance_valid(king) and not bool(king.get("defeated")) else 0.35
		c.position.y = 6.9 + absf(sin(_t * (2.0 + cheer * 3.0) + k)) * 0.5 * cheer
	for k in _pads.size():
		var s := 1.0 + sin(_t * 3.0 + k * 1.3) * 0.06
		(_pads[k] as Node3D).scale = Vector3(s, 2.0 - s, s)
	for b in get_node("Bog Road").get_children():
		if b.name.begins_with("Bog Bubble"):
			var ph: float = b.get_meta("phase")
			(b as Node3D).scale = Vector3.ONE * (0.4 + absf(sin(_t * 1.3 + ph)))
	if _home_bubble:
		_home_bubble.rotation.y += delta * 0.4


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if not is_instance_valid(king):
		return
	if not awake and Vector2(_player.global_position.x - COURT.x, _player.global_position.z - COURT.z).length() < WAKE_RANGE:
		wake()
	if awake and bool(king.get("defeated")) and not popped:
		_his_majesty_popped()


func wake() -> void:
	# "Who dares?!" He hops down off his throne into the court and the fight's on
	if awake:
		return
	awake = true
	king.process_mode = Node.PROCESS_MODE_INHERIT
	king.set("home", COURT + Vector3(0, 0.8, 4.0))
	king.set("target", COURT + Vector3(0, 0.8, 4.0))
	king.velocity = Vector3(0, 7.0, -4.0)
	if flood:
		flood.call("start")
	# Ammo crates round the court (he takes a lot of popping now, and the Star Popper's tank can run dry)
	var supplies := Node3D.new()
	supplies.name = "Court Supplies"
	add_child(supplies)
	supplies.global_position = global_position + COURT + Vector3(0, 1.0, 0)
	Arsenal.supply_boss(supplies, 8.5, 4)
	Game.message("THE GLOOP KING: \"WHO DARES drip in MY court?!\"")
	Audio.play_at("gloop_giggle", king.global_position, 4.0)
	Juice.shake(0.3)


func _his_majesty_popped() -> void:
	# The chest's lid pops up and a way home appears by the throne
	popped = true
	var lid := _chest.get_node("Lid") as Node3D
	var tw := lid.create_tween()
	tw.tween_property(lid, "rotation:x", -1.1, 0.5).set_trans(Tween.TRANS_BACK)
	Fx.burst(self, _chest.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 24, 0.12, 4.0, 3.0)
	for c in _courtiers:
		Fx.burst(self, c.global_position + Vector3(0, 0.8, 0), Color(0.7, 1.0, 0.4), 6, 0.1, 2.0, 2.0)
	if _home_bubble == null:
		_home_bubble = _way_home(THRONE + Vector3(-4.0, 1.9, -1.8), "Throne Way Out")


func _treasure_offer() -> String:
	if not awake or not is_instance_valid(king) or not bool(king.get("defeated")):
		return ""
	return "open the Royal Treasure" if not treasure_open else ""


func _open_treasure() -> void:
	if treasure_open:
		return
	treasure_open = true
	var flag := "gloop_treasure_%d" % Requests.visit_day()
	if Dialogue.flags.has(flag):
		Game.message("Empty today. Come back next time!")
		return
	Dialogue.set_flag(flag)
	Game.add_sparkles(TREASURE)
	Game.message("The Royal Treasure! ✦ %d sparkles (he won't mind... much)." % TREASURE)
	Juice.blip("chime", 1.0, -4.0)
