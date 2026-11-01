extends Node3D

# One of Stars Hollow's big days (scripts/festival.gd BIG_DAYS), put up in the Earth town while it's on and taken down
# after. Everything's made from shapes, like the fairs (scripts/festival_green.gd).
# - "lights", Winter Lights (21 Winter, 5 to 10 PM): the Winter Tree on the green's west side, snowy, with presents
#   under it and a gold star on top. At 6 PM it's lit (every bulb and the star glow, a warm light round it, a chime and
#   a sparkle burst). Being near it when it's lit pays its prize.
# - "kites", Kite Day (14 Spring, 10 AM to 5 PM): kites bob over Lookout Hill on long strings, the kids fly their own
#   from the top (their routines' "kites" blocks), and a stand at the foot of the hill lends the player one (the spot
#   "Kite Stand": Festival.kite_lines()). It flies over them wherever they go; at the top of the hill it pays its prize.
# - "fireworks", Firefly Night (28 Summer, 8:30 to 11 PM): rockets go up from a raft in the middle of Willow Pond and
#   burst in colours, with a finale at 10 PM (a rocket every fifth of a second). Watching the finale from round the pond
#   pays its prize.
# An Earth hour is a real minute, so the finale lasts FINALE (in Earth minutes), about twenty real seconds.

const KIDS := ["nina_earth", "bruno", "prue", "juniper", "theo", "ozzie"]
const TREE_NEAR := 25.0             # metres from the tree to see it lit
const HILL_NEAR := 12.0             # metres from the hilltop for a kite to count
const POND_NEAR := 45.0             # metres from the pond's middle to watch the finale
const FINALE := 20.0                # Earth minutes of finale
const ROCKET_RISE := 1.3            # seconds a rocket climbs before it bursts
const SPARKS := 60                  # sparks in a burst
const SPARK_LIFE := 1.9             # seconds a burst lasts
const SPARK_SPEED := 13.0           # metres a second they fly out at first...
const SPARK_DRAG := 1.6             # ...slowing down like this
const COLOURS := [Color(1.0, 0.35, 0.45), Color(0.4, 0.85, 1.0), Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.45),
	Color(0.85, 0.5, 1.0), Color(1.0, 0.6, 0.25)]

var kind := ""
var lit := false                    # Winter Lights: the tree's lit
var rockets_fired := 0              # Firefly Night: how many have gone up
var player_kite: Node3D             # Kite Day: the player's kite, while they've got one

var _mats := {}
var _bulbs: Array[MeshInstance3D] = []
var _star: MeshInstance3D
var _glow: OmniLight3D
var _kites := {}                    # who -> their kite (Node3D, with a "String" child)
var _sky_kites: Array[Node3D] = []
var _rockets: Array = []            # {node, vel, t}
var _bursts: Array = []             # {node, dirs, t}
var _next_rocket := 0.0
var _raft_at := Vector3.ZERO
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = Clock.earth_day() * 31 + kind.hash()
	match kind:
		"lights":
			_winter_tree()
		"kites":
			_kite_stand()
			_hill_kites()
		"fireworks":
			_raft()


func _process(delta: float) -> void:
	_t += delta
	var player := _player()
	match kind:
		"lights":
			_update_tree(player)
		"kites":
			_update_kites(player, delta)
		"fireworks":
			_update_fireworks(player, delta)


func _player() -> Node3D:
	var scene := get_tree().current_scene
	return scene.find_child("Player", true, false) as Node3D if scene else null


static func _flat(a: Vector3, b: Vector2) -> float:
	return Vector2(a.x, a.z).distance_to(b)


# --- Winter Lights ------------------------------------------------------------------------------------------------
func _winter_tree() -> void:
	var at := Festival.TREE_AT
	var root := Node3D.new()
	root.name = "Winter Tree"
	add_child(root)
	root.position = Vector3(at.x, EarthLand.height(at.x, at.y), at.y)
	_mesh(root, _cyl(0.3, 0.35, 1.2), Vector3(0, 0.6, 0), _mat(Color(0.4, 0.27, 0.16)))
	# Four tiers of branches, each dusted with snow on top
	var tiers := [[2.4, 0.9, 2.3], [1.95, 2.3, 2.1], [1.5, 3.6, 1.9], [1.0, 4.8, 1.6]]
	for t in tiers:
		_mesh(root, _cyl(0.0, t[0], t[2]), Vector3(0, t[1] + t[2] / 2.0, 0), _mat(Color(0.12, 0.36, 0.2)))
		_mesh(root, _cyl(0.0, t[0] * 0.55, t[2] * 0.5), Vector3(0, t[1] + t[2] * 0.78, 0), _mat(Color(0.9, 0.93, 0.97)))
	# Bulbs round the tiers, dark until it's lit
	for i in 64:
		var tier: Array = tiers[i % tiers.size()]
		var up := _rng.randf_range(0.1, 0.75)
		var r: float = tier[0] * (1.0 - up) + 0.06
		var a := _rng.randf() * TAU
		var bulb := _mesh(root, _sphere(0.11), Vector3(cos(a) * r, tier[1] + tier[2] * up, sin(a) * r),
			_mat(COLOURS[i % COLOURS.size()]))
		_bulbs.append(bulb)
	# The star: five gold points
	var star := Node3D.new()
	star.position = Vector3(0, 6.75, 0)
	root.add_child(star)
	var gold := _mat(Color(1.0, 0.82, 0.3))
	for k in 5:
		var point := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.28, 0.42, 0.08)
		point.mesh = pm
		point.material_override = gold
		point.rotation.z = k * TAU / 5.0
		point.position = Vector3(-sin(k * TAU / 5.0), cos(k * TAU / 5.0), 0) * 0.22
		star.add_child(point)
	_star = _mesh(star, _sphere(0.17), Vector3.ZERO, gold)
	# Presents underneath
	for p in [[Vector3(1.4, 0.25, 0.6), Color(0.85, 0.2, 0.25)], [Vector3(-1.1, 0.2, 1.2), Color(0.3, 0.55, 0.9)],
			[Vector3(0.3, 0.3, -1.5), Color(0.95, 0.8, 0.3)], [Vector3(-1.5, 0.22, -0.5), Color(0.5, 0.8, 0.4)]]:
		var b := BoxMesh.new()
		b.size = Vector3(0.6, p[0].y * 2.0, 0.6)
		_mesh(root, b, p[0], _mat(p[1]))
		var ribbon := BoxMesh.new()
		ribbon.size = Vector3(0.62, p[0].y * 2.0 + 0.02, 0.12)
		_mesh(root, ribbon, p[0], _mat(Color(0.97, 0.95, 0.9)))
	# A sign, and something solid to bump into
	var sign := Label3D.new()
	sign.text = "WINTER LIGHTS"
	sign.font_size = 56
	sign.outline_size = 10
	sign.modulate = Color(1.0, 0.9, 0.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 7.6, 0)
	root.add_child(sign)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)
	root.add_child(body)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.8, 0.55)
	_glow.light_energy = 0.0
	_glow.omni_range = 14.0
	_glow.position = Vector3(0, 3.5, 0)
	root.add_child(_glow)
	_set_lit(Festival.big_moment(), false)


func _update_tree(player: Node3D) -> void:
	var now := Festival.big_moment()
	if now != lit:
		_set_lit(now, true)
	if lit:
		_star.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 3.0))
		for i in _bulbs.size():
			# (a slow twinkle: each bulb's own phase)
			_bulbs[i].transparency = 0.25 * (0.5 + 0.5 * sin(_t * 2.2 + i * 1.7))
		if player and _flat(player.global_position, Festival.TREE_AT) < TREE_NEAR:
			Festival.big_day_reached("lights")


func _set_lit(on: bool, show: bool) -> void:
	lit = on
	for b in _bulbs:
		var m := b.material_override as StandardMaterial3D
		m.emission_enabled = on
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.1
	var sm := _star.material_override as StandardMaterial3D
	sm.emission_enabled = on
	sm.emission = sm.albedo_color
	sm.emission_energy_multiplier = 3.0
	_glow.light_energy = 2.5 if on else 0.0
	var player := _player()
	if on and show and player and _flat(player.global_position, Festival.TREE_AT) < TREE_NEAR * 2.0:
		Juice.blip("chime", 1.0, -6.0)
		Juice.burst(self, _star.global_position, Color(1.0, 0.85, 0.4), 30, 0.12, 4.0, 1.2)
		Game.message("Three, two, one... the Winter Tree's lit! Everyone on the green cheers.")


# --- Kite Day -----------------------------------------------------------------------------------------------------
func _kite_stand() -> void:
	var at := Festival.KITE_STAND_AT
	var stand := Node3D.new()
	stand.name = "Kite Stand Stall"
	add_child(stand)
	stand.position = Vector3(at.x, EarthLand.height(at.x, at.y), at.y)
	var top := BoxMesh.new()
	top.size = Vector3(1.8, 0.1, 0.9)
	_mesh(stand, top, Vector3(0, 0.85, 0), _mat(Color(0.75, 0.55, 0.35)))
	for x in [-0.8, 0.8]:
		for z in [-0.35, 0.35]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.08, 0.85, 0.08)
			_mesh(stand, leg, Vector3(x, 0.42, z), _mat(Color(0.55, 0.38, 0.24)))
	# A box of kites leaning up, each a different colour
	for i in 5:
		var k := _kite_shape(COLOURS[i], 0.5)
		k.position = Vector3(-0.6 + i * 0.3, 1.25, 0)
		k.rotation = Vector3(-0.3, 0, 0)
		stand.add_child(k)
	var sign := Label3D.new()
	sign.text = "KITE DAY!\nBorrow a kite"
	sign.font_size = 40
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.2, 0)
	stand.add_child(sign)
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = "Kite Stand"
	spot.set("verb", "borrow a kite")
	spot.set("radius", 2.2)
	spot.set("jobs", Festival)
	spot.position = stand.position + Vector3(0, 0, 1.0)
	add_child(spot)


func _hill_kites() -> void:
	# Kites already flying over the hill, tied to stakes near the top
	var top := _hilltop()
	for i in 7:
		var a := i * TAU / 7.0 + 0.4
		var anchor := top + Vector3(cos(a) * 6.0, 0.0, sin(a) * 6.0)
		anchor.y = EarthLand.height(anchor.x, anchor.z)
		var k := _flying_kite(COLOURS[i % COLOURS.size()], 2.6)
		k.set_meta("anchor", anchor)
		k.set_meta("phase", i * 1.3)
		k.set_meta("lift", 14.0 + (i % 3) * 4.0)
		_sky_kites.append(k)


func _hilltop() -> Vector3:
	var p: Vector2 = TownPaths.get_shared(TownPaths.EARTH_FILE).points.get("hill_top", Vector2(-112, -87))
	return Vector3(p.x, EarthLand.height(p.x, p.y), p.y)


func _update_kites(player: Node3D, delta: float) -> void:
	for k in _sky_kites:
		var ph: float = k.get_meta("phase")
		var anchor: Vector3 = k.get_meta("anchor")
		var at: Vector3 = anchor + Vector3(sin(_t * 0.4 + ph) * 3.0 - 4.0, float(k.get_meta("lift")) + sin(_t * 0.9 + ph) * 1.2, 6.0)
		_fly(k, at, anchor + Vector3(0, 0.3, 0), _t + ph)
	# The kids flying theirs from the top
	for id in KIDS:
		var r: Node = Dialogue.routine_of(id)
		var body: Node3D = r.get_parent() as Node3D if r else null
		var flying: bool = r != null and r.activity() == "kites" and r.is_present() and body != null and body.is_visible_in_tree()
		if flying and not _kites.has(id):
			_kites[id] = _flying_kite(COLOURS[KIDS.find(id) % COLOURS.size()])
		elif not flying and _kites.has(id):
			_kites[id].queue_free()
			_kites.erase(id)
		if flying:
			_follow(_kites[id], body.global_position, delta, KIDS.find(id) * 0.9)
	# The player's, once they've borrowed one
	var has := player != null and Festival.kite_day == Clock.earth_day()
	if has and player_kite == null:
		player_kite = _flying_kite(Color(1.0, 0.85, 0.3))
		player_kite.name = "Player Kite"
		player_kite.global_position = player.global_position + Vector3(0, 6, 3)
	elif not has and player_kite != null:
		player_kite.queue_free()
		player_kite = null
	if player_kite:
		_follow(player_kite, player.global_position, delta, 0.0)
		var top := _hilltop()
		if _flat(player.global_position, Vector2(top.x, top.z)) < HILL_NEAR and player.global_position.y > top.y - 2.0:
			Festival.big_day_reached("kites")


func _follow(k: Node3D, hand: Vector3, delta: float, phase: float) -> void:
	# A kite trails up and behind whoever holds it, higher the higher they are, and catches up if they run
	var want := hand + Vector3(sin(_t * 0.6 + phase) * 1.5 - 3.0, 9.0 + sin(_t * 1.1 + phase) * 0.8, 4.0)
	var at := k.global_position.lerp(want, clampf(delta * 1.5, 0.0, 1.0))
	if at.distance_to(want) > 25.0:
		at = want
	_fly(k, at, hand + Vector3(0, 1.0, 0), _t + phase)


func _fly(k: Node3D, at: Vector3, hand: Vector3, t: float) -> void:
	k.global_position = at
	k.rotation = Vector3(-0.5, 0.0, sin(t * 1.3) * 0.35)
	var string := k.get_node("String") as MeshInstance3D
	var d := hand - at
	string.global_position = at + d / 2.0
	var side := _perp(d)
	string.global_basis = Basis(side, d, side.cross(d.normalized()))


static func _perp(d: Vector3) -> Vector3:
	var p := d.cross(Vector3.FORWARD)
	if p.length() < 0.01:
		p = d.cross(Vector3.RIGHT)
	return p.normalized()


func _flying_kite(colour: Color, size := 1.6) -> Node3D:
	var k := _kite_shape(colour, size)
	add_child(k)
	var string := MeshInstance3D.new()
	string.name = "String"
	var line := CylinderMesh.new()
	line.top_radius = 0.012
	line.bottom_radius = 0.012
	line.height = 1.0
	line.radial_segments = 4
	string.mesh = line
	string.material_override = _mat(Color(0.95, 0.95, 0.92))
	string.top_level = true
	k.add_child(string)
	return k


func _kite_shape(colour: Color, size: float) -> Node3D:
	# A diamond kite with crossed sticks and a tail of bows
	var k := Node3D.new()
	var sail := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.75, 0.75, 0.03) * Vector3(size, size, 1)
	sail.mesh = b
	sail.material_override = _mat(colour)
	sail.rotation.z = PI / 4.0
	sail.scale = Vector3(1.0, 1.35, 1.0)
	k.add_child(sail)
	for i in 4:
		var bow := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.16, 0.07, 0.02) * size
		bow.mesh = bb
		bow.material_override = _mat(COLOURS[(COLOURS.find(colour) + 1 + i) % COLOURS.size()])
		bow.position = Vector3(0, -0.6 - i * 0.28, 0) * size
		k.add_child(bow)
	return k


# --- Firefly Night ------------------------------------------------------------------------------------------------
func _raft() -> void:
	_raft_at = Vector3(EarthLand.POND.x, EarthLand.WATER_Y + 0.1, EarthLand.POND.y)
	var raft := Node3D.new()
	raft.name = "Firework Raft"
	add_child(raft)
	raft.position = _raft_at
	var deck := BoxMesh.new()
	deck.size = Vector3(3.0, 0.25, 3.0)
	_mesh(raft, deck, Vector3.ZERO, _mat(Color(0.5, 0.36, 0.22)))
	for i in 6:
		var tube := _mesh(raft, _cyl(0.12, 0.12, 0.7), Vector3(-0.9 + (i % 3) * 0.9, 0.45, -0.5 + int(i / 3.0) * 1.0),
			_mat(COLOURS[i]))
		tube.rotation.x = 0.08 * (i - 3)
	_next_rocket = 0.5


func _update_fireworks(player: Node3D, delta: float) -> void:
	var finale := Festival.big_moment() and Clock.earth_minutes < Festival.BIG_DAYS.fireworks.moment + FINALE
	_next_rocket -= delta
	if _next_rocket <= 0.0:
		_launch(player)
		_next_rocket = 0.2 if finale else _rng.randf_range(0.8, 1.8)
	for r in _rockets.duplicate():
		r.t += delta
		var node: Node3D = r.node
		var vel: Vector3 = r.vel
		node.global_position += vel * delta
		vel.y -= 6.0 * delta
		r.vel = vel
		if r.t >= ROCKET_RISE:
			_burst(node.global_position, r.colour, player)
			node.queue_free()
			_rockets.erase(r)
	_update_bursts(delta)
	if Festival.big_moment() and player and _flat(player.global_position, Vector2(_raft_at.x, _raft_at.z)) < POND_NEAR:
		Festival.big_day_reached("fireworks")


func _launch(player: Node3D) -> void:
	rockets_fired += 1
	var colour: Color = COLOURS[_rng.randi() % COLOURS.size()]
	var rocket := _mesh(self, _sphere(0.12), _raft_at + Vector3(0, 0.6, 0), _glow_mat(Color(1.0, 0.9, 0.7)))
	rocket.name = "Rocket"
	_rockets.append({"node": rocket, "vel": Vector3(_rng.randf_range(-3, 3), _rng.randf_range(24, 30), _rng.randf_range(-3, 3)),
		"t": 0.0, "colour": colour})
	if player and player.global_position.distance_to(_raft_at) < 90.0:
		Juice.blip("whoosh", _rng.randf_range(1.2, 1.6), -16.0)


func _burst(at: Vector3, colour: Color, player: Node3D) -> void:
	# A ball of glowing sparks flying out from where the rocket burst, slowing, drooping and shrinking away. Moved
	# here each frame (_update_bursts), so it looks the same however fast the game's running.
	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.mesh = _spark_mesh(colour)
	dots.instance_count = SPARKS
	var mm := MultiMeshInstance3D.new()
	mm.name = "Burst"
	mm.multimesh = dots
	mm.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	add_child(mm)
	mm.global_position = at
	var dirs := PackedVector3Array()
	for i in SPARKS:
		# (spread evenly over a ball: a Fibonacci sphere, wobbled a little)
		var y := 1.0 - 2.0 * (i + 0.5) / SPARKS
		var r := sqrt(1.0 - y * y)
		var a := i * 2.39996 + _rng.randf_range(-0.2, 0.2)
		dirs.append(Vector3(cos(a) * r, y, sin(a) * r) * _rng.randf_range(0.85, 1.1))
	_bursts.append({"node": mm, "dirs": dirs, "t": 0.0})
	var flash := OmniLight3D.new()
	flash.light_color = colour
	flash.light_energy = 4.0
	flash.omni_range = 45.0
	mm.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.6)
	_update_burst(_bursts[-1])
	if player and player.global_position.distance_to(at) < 110.0:
		Juice.blip("thud", _rng.randf_range(0.45, 0.6), -12.0)


func _update_bursts(delta: float) -> void:
	for b in _bursts.duplicate():
		b.t += delta
		if b.t >= SPARK_LIFE:
			b.node.queue_free()
			_bursts.erase(b)
		else:
			_update_burst(b)


func _update_burst(b: Dictionary) -> void:
	var t: float = b.t
	var out := SPARK_SPEED * (1.0 - exp(-SPARK_DRAG * t)) / SPARK_DRAG
	var droop := Vector3(0, -1.6 * t * t, 0)
	var size := 1.0 - smoothstep(0.55, 1.0, t / SPARK_LIFE)
	var dots: MultiMesh = (b.node as MultiMeshInstance3D).multimesh
	var dirs: PackedVector3Array = b.dirs
	for i in dirs.size():
		dots.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * maxf(size, 0.01)), dirs[i] * out + droop))


func _spark_mesh(colour: Color) -> Mesh:
	var key := "spark %s" % colour
	if _mats.has(key):
		return _mats[key]
	var dot := SphereMesh.new()
	dot.radius = 0.28
	dot.height = 0.56
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _glow_mat(colour)
	_mats[key] = dot
	return dot


# --- Shapes -------------------------------------------------------------------------------------------------------
func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


func _mat(c: Color) -> StandardMaterial3D:
	# (the bulbs each need their own, since lighting the tree changes them)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


func _glow_mat(c: Color) -> StandardMaterial3D:
	var key := "glow %s" % c
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	_mats[key] = m
	return m
