extends Node3D

# Things happening all round a race circuit, so the track feels alive (Hayden's 14 Nov 2026 note: "I want the maps
# to feel like they are alive and things are happening all around"). A "Life" node race_circuit.gd puts on every
# circuit. Nothing here is solid or gets in the way: it's all for show.
#
#   Set pieces (SETS, by circuit): each waits beside the road and goes off as you come up to it, every lap. Something
#   leaps over the road, geysers or crystals burst up, saucers or crows swoop over, meteors land in the fields, a
#   boulder rolls down the hill, fireworks go up...
#   The crowd in the stand jumps up and cheers as you go by, and a blimp with the track's name circles overhead.
#
# Each set piece is a Node3D named "Set <n> <kind>" with metas "kind", "d" (how far round the road it goes off) and
# "fired" (how many times it has). No class_name on purpose (preload it).

const TRIGGER_NEAR := 18.0           # it goes off when you're between this many metres...
const TRIGGER_FAR := 46.0            # ...and this many before its spot
const REARM := 90.0                  # and gets ready again once you're this far past it
const CHEER_NEAR := 34.0             # how close to the stand the crowd starts cheering

# Per circuit: [segment (checkpoint number, 2.5 is halfway from 2 to 3), kind]
const SETS := {
	"lake_loop": [[1.5, "leaper"], [4.6, "geysers"], [8.6, "saucers"], [11.6, "crystals"], [13.3, "geysers"]],
	"meadow_wiggle": [[2.2, "bloom"], [5.0, "leaper"], [10.2, "moths"], [12.0, "balloons"], [15.6, "bloom"]],
	"observatory_hill": [[1.6, "meteors"], [6.0, "boulder"], [8.6, "saucers"], [11.4, "crystals"], [12.8, "meteors"]],
	"pumpkin_run": [[1.7, "crows"], [5.5, "hayburst"], [8.2, "hot_air"], [10.3, "fireworks"], [13.4, "crows"]],
}

var c: Node3D                        # the circuit (race_circuit.gd)
var sets: Array[Node3D] = []
var cheering := false
var _armed := {}
var _near_i := 0                     # the line point nearest the player, last time (searched from there)
var _blimp: Node3D
var _blimp_t := 0.0
var _fans: Array[Node3D] = []
var _fan_y: Array[float] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(circuit: Node3D) -> void:
	c = circuit
	name = "Life"


func _ready() -> void:
	_rng.seed = hash(str(c.circuit_id) + "life")
	var list: Array = SETS.get(str(c.circuit_id), [])
	for k in list.size():
		var entry: Array = list[k]
		var s := Node3D.new()
		s.name = "Set %d %s" % [k, entry[1]]
		s.set_meta("kind", str(entry[1]))
		s.set_meta("d", float(c.d_at(float(entry[0]))))
		s.set_meta("fired", 0)
		add_child(s)
		sets.append(s)
		call("_build_" + str(entry[1]), s)
		_armed[s] = true
	_blimp_build()
	var stand := c.get_node_or_null("Stand") as Node3D
	if stand:
		for f in stand.get_children():
			if not f is MeshInstance3D:
				_fans.append(f)
				_fan_y.append((f as Node3D).position.y)


func earth() -> bool:
	return str(c.track.get("circuit", {}).get("theme", "void")) == "earth"


# -----------------------------------------------------------------------------
# Where things go
# -----------------------------------------------------------------------------
func _pt(d: float) -> Vector3:
	return c.line[c.index_at(d)]


func _side(d: float) -> Vector3:
	# The road's left at d (a flat unit vector)
	return c._fwd(c.index_at(d)).cross(Vector3.UP).normalized()


func _out(d: float) -> Vector3:
	# The side away from the middle of the loop (where no shortcut ever goes)
	var s := _side(d)
	var p := _pt(d) + s * 25.0
	return -s if c._inside_loop(Vector2(p.x, p.z)) else s


func _off(d: float, metres: float, outward := true) -> Vector3:
	var p: Vector3 = _pt(d) + (_out(d) if outward else -_out(d)) * (c.half_width() + metres)
	p.y = _pt(d).y if metres < 30.0 else 0.0
	return p


func _mat(n: String, col: Color, glow := 0.0) -> StandardMaterial3D:
	return c._mat("Life " + n, col, 0.6, glow)


func _ball(parent: Node3D, r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return c._mesh(parent, s, at, m, false)


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return c._mesh(parent, b, at, m, false)


func _cone(parent: Node3D, r: float, h: float, at: Vector3, m: Material, sides := 6) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return c._mesh(parent, cm, at, m, false)


func _shake(amount: float) -> void:
	# Only when it's going off right by you (Juice scales it by Settings > Assist > Screen shake, none with Reduce motion)
	var j := get_tree().root.get_node_or_null("Juice")
	if j:
		j.shake(amount)


func _sound(n: String, vol := -6.0) -> void:
	var a := get_tree().root.get_node_or_null("Audio")
	if a:
		a.play(n, vol, 0.15)


func _splash(at: Vector3, col: Color, n := 14, speed := 7.0, size := 0.35) -> void:
	# Droplets (or sparks) flung up and out from a spot, falling back down and fading
	var m := _mat("Splash %s" % col.to_html(), col, 0.6)
	for k in n:
		var b := _ball(self, size * _rng.randf_range(0.6, 1.2), at, m)
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.8, 1.6), _rng.randf_range(-1, 1)).normalized()
		var top := at + dir * speed * 0.55
		var down := top + Vector3(dir.x, 0, dir.z) * speed * 0.3 + Vector3.DOWN * speed * 0.6
		var tw := create_tween()
		tw.tween_property(b, "position", top, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(b, "position", down, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(b, "scale", Vector3.ONE * 0.05, 0.45)
		tw.tween_callback(b.queue_free)


func _ring(at: Vector3, col: Color, grow := 9.0) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.8
	t.outer_radius = 1.2
	var r: MeshInstance3D = c._mesh(self, t, at + Vector3.UP * 0.15, _mat("Ring %s" % col.to_html(), col, 1.2), false)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3(grow, 1.0, grow), 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "transparency", 1.0, 0.7)
	tw.tween_callback(r.queue_free)


# -----------------------------------------------------------------------------
# Every frame: who's where, what goes off
# -----------------------------------------------------------------------------
func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func player_d() -> float:
	# How far round the road the player is (searched from last time's point, so it's quick)
	var p := _player()
	if p == null or c.line.is_empty():
		return -1.0
	var n: int = c.line.size()
	var xz := Vector2(p.global_position.x, p.global_position.z)
	var best := INF
	var at := _near_i
	var span := 40
	for k in range(-span, span + 1):
		var i := (_near_i + k + n) % n
		var dd := xz.distance_squared_to(Vector2(c.line[i].x, c.line[i].z))
		if dd < best:
			best = dd
			at = i
	if best > 30.0 * 30.0:                            # (somewhere else altogether: a full search)
		for i in n:
			var dd := xz.distance_squared_to(Vector2(c.line[i].x, c.line[i].z))
			if dd < best:
				best = dd
				at = i
	_near_i = at
	return c.dist[at]


func _process(delta: float) -> void:
	_t += delta
	_blimp_move(delta)
	var pd := player_d()
	if pd < 0.0:
		return
	for s in sets:
		var ahead := fposmod(float(s.get_meta("d")) - pd, float(c.total))
		if _armed[s] and ahead > TRIGGER_NEAR and ahead < TRIGGER_FAR:
			fire(s)
		elif not _armed[s] and ahead > REARM and ahead < float(c.total) - REARM:
			_armed[s] = true
	_cheer(delta)


func fire(s: Node3D) -> void:
	_armed[s] = false
	s.set_meta("fired", int(s.get_meta("fired")) + 1)
	call("_fire_" + str(s.get_meta("kind")), s)


# -----------------------------------------------------------------------------
# The crowd and the blimp
# -----------------------------------------------------------------------------
func _cheer(delta: float) -> void:
	var stand := c.get_node_or_null("Stand") as Node3D
	var p := _player()
	cheering = stand != null and p != null and p.global_position.distance_to(stand.global_position) < CHEER_NEAR + 8.0
	for k in _fans.size():
		var f := _fans[k]
		if not is_instance_valid(f):
			continue
		var want := _fan_y[k]
		if cheering:
			want += absf(sin(_t * 7.0 + k * 1.3)) * 0.7
		f.position.y = lerpf(f.position.y, want, minf(1.0, delta * 12.0))


func _blimp_build() -> void:
	_blimp = Node3D.new()
	_blimp.name = "Blimp"
	add_child(_blimp)
	var body := CapsuleMesh.new()
	body.radius = 2.6
	body.height = 13.0
	var col := Color(0.95, 0.85, 0.3) if earth() else Color(0.75, 0.55, 1.0)
	var hull: MeshInstance3D = c._mesh(_blimp, body, Vector3.ZERO, _mat("Blimp", col, 0.1), false)
	hull.rotation.x = PI / 2.0                         # (lying along its own +Z, the way it flies)
	for k in 4:
		var fin := _box(_blimp, Vector3(0.2, 3.0, 2.2), Vector3(0, 0, -5.6), _mat("Blimp Fin", col.darkened(0.25)))
		fin.rotation.z = k * PI / 2.0
		fin.position = Vector3(sin(k * PI / 2.0) * -1.8, cos(k * PI / 2.0) * 1.8, -5.6)
	_box(_blimp, Vector3(1.4, 0.9, 2.4), Vector3(0, -2.9, 0.5), _mat("Blimp Cab", Color(0.3, 0.3, 0.45)))
	for sd in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = str(c.track.get("name", "RACE")).to_upper()
		l.font_size = 140
		l.outline_size = 28
		l.pixel_size = 0.012
		l.modulate = Color(0.25, 0.12, 0.4) if not earth() else Color(0.6, 0.15, 0.1)
		l.position = Vector3(2.65 * sd, 0, 0)
		l.rotation.y = PI / 2.0 * sd
		_blimp.add_child(l)


func _blimp_move(delta: float) -> void:
	if _blimp == null:
		return
	_blimp_t += delta
	var mid: Vector2 = c._inside()
	var r := 70.0
	var a := _blimp_t * 0.06
	var at := Vector3(mid.x + cos(a) * r, 46.0 + sin(_blimp_t * 0.4) * 1.5, mid.y + sin(a) * r)
	_blimp.position = at
	_blimp.look_at(at + Vector3(-sin(a), 0, cos(a)), Vector3.UP)
	_blimp.rotate_object_local(Vector3.UP, PI)          # (its nose is +Z)


# -----------------------------------------------------------------------------
# Leaper: something big leaps right over the road (a Lake Puff out of the lake, a Bounce Bun in the meadow)
# -----------------------------------------------------------------------------
func _build_leaper(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var critter := Node3D.new()
	critter.name = "Critter"
	s.add_child(critter)
	var meadow := str(c.circuit_id) == "meadow_wiggle"
	var skin := _mat("Bun" if meadow else "Puff", Color(1.0, 0.65, 0.85) if meadow else Color(0.3, 0.85, 0.95), 0.25)
	var body := _ball(critter, 2.2, Vector3.ZERO, skin)
	body.scale = Vector3(1.0, 0.85, 1.35)
	var eye := _mat("Eye", Color(0.1, 0.08, 0.15))
	var white := _mat("Eye White", Color(1, 1, 1))
	for sd in [-1.0, 1.0]:
		_ball(critter, 0.55, Vector3(sd * 1.0, 0.7, 2.2), white)
		_ball(critter, 0.3, Vector3(sd * 1.0, 0.75, 2.6), eye)
		if meadow:
			var ear := _ball(critter, 0.6, Vector3(sd * 0.9, 2.4, 0.2), skin)
			ear.scale = Vector3(0.6, 1.8, 0.6)
		else:
			var fin := _ball(critter, 0.7, Vector3(sd * 2.2, -0.2, 0), skin)
			fin.scale = Vector3(1.6, 0.3, 0.9)
	var tail := _ball(critter, 0.9, Vector3(0, 0.3, -2.9), skin)
	tail.scale = Vector3(1.6, 0.4, 0.8) if not meadow else Vector3.ONE
	critter.visible = false
	# From inside the loop (the lake's side) to the far side
	s.set_meta("from", _off(d, 16.0, false))
	s.set_meta("to", _off(d + 6.0, 16.0, true))


func _fire_leaper(s: Node3D) -> void:
	var critter := s.get_node("Critter") as Node3D
	var a: Vector3 = s.get_meta("from")
	var b: Vector3 = s.get_meta("to")
	var meadow := str(c.circuit_id) == "meadow_wiggle"
	var col := Color(1.0, 0.75, 0.9) if meadow else Color(0.55, 0.95, 1.0)
	critter.visible = true
	critter.position = a
	_splash(a, col, 16, 9.0)
	_ring(a, col)
	_sound("boing" if meadow else "bubbles", -4.0)
	var top := 13.0
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		var p := a.lerp(b, u) + Vector3.UP * (4.0 * top * u * (1.0 - u))
		var nxt := a.lerp(b, minf(u + 0.02, 1.0)) + Vector3.UP * (4.0 * top * minf(u + 0.02, 1.0) * (1.0 - minf(u + 0.02, 1.0)))
		critter.position = p
		if nxt.distance_to(p) > 0.01:
			critter.look_at(nxt, Vector3.UP)
			critter.rotate_object_local(Vector3.UP, PI), 0.0, 1.0, 1.7)
	tw.tween_callback(func() -> void:
		_splash(b, col, 16, 9.0)
		_ring(b, col)
		_shake(0.25)
		critter.visible = false)


# -----------------------------------------------------------------------------
# Geysers: a row of them erupts along the bank, one after another
# -----------------------------------------------------------------------------
func _build_geysers(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	for k in 6:
		var g := Node3D.new()
		g.name = "Geyser %d" % k
		s.add_child(g)
		g.position = _off(d + k * 7.0 - 6.0, 5.5 + (k % 2) * 3.0, true)
		var vent := CylinderMesh.new()
		vent.top_radius = 1.6
		vent.bottom_radius = 2.1
		vent.height = 0.4
		c._mesh(g, vent, Vector3(0, 0.2, 0), _mat("Vent", Color(0.45, 0.4, 0.6)), false)
		var col := CylinderMesh.new()
		col.top_radius = 1.5
		col.bottom_radius = 1.1
		col.height = 1.0
		var jet: MeshInstance3D = c._mesh(g, col, Vector3(0, 0.5, 0), _mat("Geyser", Color(0.6, 0.95, 1.0, 0.8), 0.5), false)
		jet.name = "Jet"
		jet.scale = Vector3(1, 0.01, 1)
		jet.visible = false


func _fire_geysers(s: Node3D) -> void:
	_sound("fwump", -3.0)
	for k in s.get_child_count():
		var g := s.get_child(k) as Node3D
		var jet := g.get_node("Jet") as Node3D
		var tw := create_tween()
		tw.tween_interval(k * 0.2)
		tw.tween_callback(func() -> void:
			jet.visible = true
			_splash(g.global_position + Vector3.UP * 15.0, Color(0.7, 0.95, 1.0), 16, 9.0, 0.5))
		tw.tween_property(jet, "scale", Vector3(1, 16.0, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(jet, "position:y", 8.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(1.6)
		tw.tween_property(jet, "scale", Vector3(1, 0.01, 1), 0.6).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(jet, "position:y", 0.5, 0.6)
		tw.tween_callback(func() -> void: jet.visible = false)


# -----------------------------------------------------------------------------
# Saucers: three little saucers swoop low over the road ahead, then zoom up and away
# -----------------------------------------------------------------------------
func _build_saucers(s: Node3D) -> void:
	var cols := [Color(1.0, 0.5, 0.8), Color(0.4, 0.95, 0.9), Color(1.0, 0.85, 0.35)]
	for k in 3:
		var u := Node3D.new()
		u.name = "Saucer %d" % k
		s.add_child(u)
		var disc := CylinderMesh.new()
		disc.top_radius = 1.6
		disc.bottom_radius = 2.2
		disc.height = 0.5
		c._mesh(u, disc, Vector3.ZERO, _mat("Saucer %d" % k, cols[k], 0.3), false)
		var dome := _ball(u, 0.9, Vector3(0, 0.4, 0), _mat("Dome", Color(0.75, 1.0, 1.0, 0.7), 0.6))
		dome.scale = Vector3(1, 0.7, 1)
		for j in 6:
			var a := j * TAU / 6.0
			_ball(u, 0.16, Vector3(cos(a) * 1.9, -0.1, sin(a) * 1.9), _mat("Saucer Light", Color(1, 1, 0.7), 2.0))
		u.scale = Vector3.ONE * 1.8
		u.visible = false


func _fire_saucers(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	_sound("beam", -6.0)
	for k in s.get_child_count():
		var u := s.get_child(k) as Node3D
		var off := (k - 1) * 7.0
		var path: Array[Vector3] = []
		for j in 7:
			var dd := d - 40.0 + j * 18.0
			var p := _pt(dd) + _side(dd) * off + Vector3.UP * (24.0 - 14.0 * sin(PI * j / 6.0))
			path.append(p)
		path.append(path[-1] + Vector3.UP * 40.0 + (path[-1] - path[-2]) * 2.0)
		u.visible = true
		u.position = path[0]
		var tw := create_tween()
		tw.tween_interval(k * 0.18)
		for j in range(1, path.size()):
			tw.tween_property(u, "position", path[j], 0.38).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(u, "rotation:y", TAU * 2.0, 2.6).from(0.0)
		tw.tween_callback(func() -> void: u.visible = false)


# -----------------------------------------------------------------------------
# Crystals: a cluster of crystal spires bursts up out of the ground beside the road, then sinks back
# -----------------------------------------------------------------------------
func _build_crystals(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var cols := [Color(0.6, 0.95, 1.0), Color(0.95, 0.6, 1.0), Color(0.75, 0.7, 1.0)]
	for k in 9:
		var x := Node3D.new()
		x.name = "Spire %d" % k
		s.add_child(x)
		x.position = _off(d + k * 3.5 - 8.0, 5.0 + (k % 3) * 3.5, true)
		var h := 8.0 + (k % 3) * 3.5
		_cone(x, 1.6 + (k % 2) * 0.6, h, Vector3(0, h / 2.0, 0), _mat("Spire %d" % (k % 3), cols[k % 3], 0.8))
		x.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0, TAU), _rng.randf_range(-0.25, 0.25))
		x.scale = Vector3(1, 0.01, 1)
		x.visible = false


func _fire_crystals(s: Node3D) -> void:
	_sound("pop", -2.0)
	_shake(0.3)
	for k in s.get_child_count():
		var x := s.get_child(k) as Node3D
		var tw := create_tween()
		tw.tween_interval(k * 0.09)
		tw.tween_callback(func() -> void:
			x.visible = true
			_splash(x.global_position + Vector3.UP * 0.5, Color(0.8, 0.75, 1.0), 10, 7.0, 0.4))
		tw.tween_property(x, "scale", Vector3.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(6.0)
		tw.tween_property(x, "scale", Vector3(1, 0.01, 1), 1.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: x.visible = false)


# -----------------------------------------------------------------------------
# Bloom: giant flowers beside the road open up as you come by, then close again
# -----------------------------------------------------------------------------
func _build_bloom(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var cols := [Color(1.0, 0.45, 0.7), Color(1.0, 0.8, 0.3), Color(0.6, 0.55, 1.0)]
	for k in 4:
		var f := Node3D.new()
		f.name = "Flower %d" % k
		s.add_child(f)
		f.position = _off(d + k * 9.0, 5.0 + (k % 2) * 4.0, k % 2 == 0)
		var h := 5.0 + (k % 3) * 1.5
		var stem := CylinderMesh.new()
		stem.top_radius = 0.25
		stem.bottom_radius = 0.35
		stem.height = h
		c._mesh(f, stem, Vector3(0, h / 2.0, 0), _mat("Stem", Color(0.35, 0.8, 0.35)))
		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0, h, 0)
		f.add_child(head)
		_ball(head, 0.8, Vector3.ZERO, _mat("Flower Heart", Color(1.0, 0.95, 0.5), 0.6))
		for j in 7:
			var hinge := Node3D.new()
			hinge.name = "Petal %d" % j
			hinge.rotation.y = j * TAU / 7.0
			head.add_child(hinge)
			var p := _ball(hinge, 1.0, Vector3(0, 0, 1.6), _mat("Petal %d" % (k % 3), cols[k % 3], 0.2))
			p.scale = Vector3(0.9, 0.2, 1.6)
			hinge.rotation.x = -1.35                   # (shut: petals folded up into a bud)


func _fire_bloom(s: Node3D) -> void:
	_sound("rustle", -2.0)
	for k in s.get_child_count():
		var head := (s.get_child(k) as Node3D).get_node("Head") as Node3D
		var tw := create_tween()
		tw.tween_interval(k * 0.2)
		tw.tween_callback(func() -> void: _splash(head.global_position, Color(1.0, 0.85, 0.95), 10, 5.0, 0.22))
		for j in head.get_child_count():
			var hinge := head.get_child(j) as Node3D
			if hinge is MeshInstance3D:
				continue
			tw.parallel().tween_property(hinge, "rotation:x", 0.25, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(8.0)
		for j in head.get_child_count():
			var hinge := head.get_child(j) as Node3D
			if hinge is MeshInstance3D:
				continue
			tw.parallel().tween_property(hinge, "rotation:x", -1.35, 1.0)


func bloomed(s: Node3D) -> bool:
	var head := (s.get_child(0) as Node3D).get_node("Head") as Node3D
	return (head.get_node("Petal 0") as Node3D).rotation.x > -0.5


# -----------------------------------------------------------------------------
# Moths: a swarm of glowing moths sweeps across over the road
# -----------------------------------------------------------------------------
func _build_moths(s: Node3D) -> void:
	var cols := [Color(1.0, 0.9, 0.5), Color(0.6, 1.0, 0.95), Color(1.0, 0.6, 0.9)]
	for k in 30:
		var m := Node3D.new()
		m.name = "Moth %d" % k
		m.scale = Vector3.ONE * 2.2
		s.add_child(m)
		for sd in [-1.0, 1.0]:
			var w := _box(m, Vector3(0.7, 0.05, 0.5), Vector3(sd * 0.38, 0, 0), _mat("Moth %d" % (k % 3), cols[k % 3], 1.5))
			w.name = "Wing L" if sd < 0 else "Wing R"
		m.visible = false


func _fire_moths(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var a := _off(d, 14.0, false) + Vector3.UP * 3.0
	var b := _off(d + 8.0, 18.0, true) + Vector3.UP * 9.0
	_sound("rustle", -6.0)
	for k in s.get_child_count():
		var m := s.get_child(k) as Node3D
		var jitter := Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-1.5, 4), _rng.randf_range(-6, 6))
		m.visible = true
		var tw := create_tween()
		tw.tween_method(func(u: float) -> void:
			m.position = a.lerp(b, u) + jitter + Vector3(0, sin(u * 14.0 + k) * 1.2 + 5.0 * sin(PI * u), 0)
			var flap := sin(_t * 30.0 + k) * 0.8
			(m.get_node("Wing L") as Node3D).rotation.z = flap
			(m.get_node("Wing R") as Node3D).rotation.z = -flap, 0.0, 1.0, 3.0 + k * 0.05)
		tw.tween_callback(func() -> void: m.visible = false)


# -----------------------------------------------------------------------------
# Balloons: a bunch let go beside the road, floating up and away
# -----------------------------------------------------------------------------
func _build_balloons(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var cols := [Color(1.0, 0.35, 0.5), Color(0.35, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.7, 0.45, 1.0), Color(0.45, 1.0, 0.6)]
	var base := _off(d, 7.0, true)
	var post := CylinderMesh.new()
	post.top_radius = 0.12
	post.bottom_radius = 0.12
	post.height = 3.0
	c._mesh(s, post, base + Vector3.UP * 1.5, _mat("Balloon Post", Color(0.9, 0.9, 1.0)), false)
	for k in 18:
		var b := Node3D.new()
		b.name = "Balloon %d" % k
		b.scale = Vector3.ONE * 1.8
		s.add_child(b)
		var home := base + Vector3(_rng.randf_range(-2.0, 2.0), 4.0 + _rng.randf_range(0, 2.5), _rng.randf_range(-2.0, 2.0))
		b.position = home
		b.set_meta("home", home)
		var ball := _ball(b, 0.6, Vector3.ZERO, _mat("Balloon %d" % (k % 5), cols[k % 5], 0.15))
		ball.scale = Vector3(1, 1.2, 1)
		_box(b, Vector3(0.03, 1.2, 0.03), Vector3(0, -1.3, 0), _mat("String", Color(1, 1, 1)))


func _fire_balloons(s: Node3D) -> void:
	_sound("pop", -8.0)
	for b in s.get_children():
		if not b.has_meta("home"):
			continue
		var home: Vector3 = b.get_meta("home")
		var drift := Vector3(_rng.randf_range(-8, 8), 34.0 + _rng.randf_range(0, 10), _rng.randf_range(-8, 8))
		var tw := create_tween()
		tw.tween_property(b, "position", home + drift, 7.0 + _rng.randf_range(0, 2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			(b as Node3D).position = home - Vector3.UP * 3.0)
		tw.tween_property(b, "position", home, 1.0).set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# Meteors: shooting stars come down in the fields beside the road with a flash
# -----------------------------------------------------------------------------
func _build_meteors(s: Node3D) -> void:
	for k in 5:
		var m := Node3D.new()
		m.name = "Meteor %d" % k
		s.add_child(m)
		_ball(m, 1.8, Vector3.ZERO, _mat("Meteor", Color(1.0, 0.9, 0.55), 3.0))
		var trail := _cone(m, 1.6, 16.0, Vector3(0, 8.0, 0), _mat("Meteor Trail", Color(1.0, 0.7, 0.9, 0.5), 2.0), 8)
		trail.rotation.x = PI                          # (fat at the meteor, thin behind)
		trail.position = Vector3(0, 8.0, 0)
		m.visible = false


func _fire_meteors(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	for k in s.get_child_count():
		var m := s.get_child(k) as Node3D
		var land := _off(d + k * 8.0 - 6.0, 7.0 + (k % 3) * 5.0, k % 2 == 0)
		var from := land + Vector3(-18.0, 60.0, 10.0)
		m.position = from
		m.look_at(land, Vector3.UP)
		m.rotate_object_local(Vector3.RIGHT, -PI / 2.0)  # (its trail points back up the way it came)
		var tw := create_tween()
		tw.tween_interval(k * 0.35)
		tw.tween_callback(func() -> void:
			m.visible = true
			_sound("fwump", -8.0))
		tw.tween_property(m, "position", land, 0.7).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			m.visible = false
			_splash(land + Vector3.UP * 0.3, Color(1.0, 0.85, 0.45), 24, 13.0, 0.5)
			_ring(land, Color(1.0, 0.8, 0.5), 16.0)
			if k == 0:
				_shake(0.35))


# -----------------------------------------------------------------------------
# Boulder: a big round rock comes rolling down beside the road, then bursts into bits
# -----------------------------------------------------------------------------
func _build_boulder(s: Node3D) -> void:
	var rock := Node3D.new()
	rock.name = "Boulder"
	s.add_child(rock)
	var r := _ball(rock, 4.0, Vector3.ZERO, _mat("Boulder", Color(0.55, 0.5, 0.65)))
	r.scale = Vector3(1.0, 0.92, 1.05)
	for k in 6:
		var a := k * TAU / 6.0
		_ball(rock, 1.2, Vector3(cos(a) * 3.4, sin(a) * 3.4, 1.0), _mat("Boulder Lump", Color(0.48, 0.44, 0.58)))
	rock.visible = false


func _fire_boulder(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var rock := s.get_node("Boulder") as Node3D
	var path: Array[Vector3] = []
	for j in 7:
		path.append(_off(d - 10.0 + j * 9.0, 8.5, true) + Vector3.UP * 4.0)
	rock.visible = true
	rock.position = path[0] + Vector3.UP * 10.0
	_sound("fwump", -3.0)
	var tw := create_tween()
	tw.tween_property(rock, "position", path[0], 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _shake(0.3))
	for j in range(1, path.size()):
		tw.tween_property(rock, "position", path[j], 0.28)
		tw.parallel().tween_property(rock, "rotation:x", rock.rotation.x + 2.6, 0.28).as_relative()
	tw.tween_callback(func() -> void:
		rock.visible = false
		_splash(path[-1], Color(0.6, 0.55, 0.7), 24, 11.0, 0.7)
		_sound("pop", -2.0))


# -----------------------------------------------------------------------------
# Crows (Earth): a flock takes off from the field and flaps over the road
# -----------------------------------------------------------------------------
func _build_crows(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var black := _mat("Crow", Color(0.12, 0.1, 0.14))
	for k in 24:
		var b := Node3D.new()
		b.name = "Crow %d" % k
		b.scale = Vector3.ONE * 2.0
		s.add_child(b)
		var home := _off(d + _rng.randf_range(-8, 8), 6.0 + _rng.randf_range(0, 8), true)
		b.position = home
		b.set_meta("home", home)
		_ball(b, 0.3, Vector3.ZERO, black).scale = Vector3(0.8, 0.8, 1.4)
		_cone(b, 0.1, 0.3, Vector3(0, 0, 0.5), _mat("Beak", Color(0.95, 0.75, 0.2))).rotation.x = PI / 2.0
		for sd in [-1.0, 1.0]:
			var w := _box(b, Vector3(0.8, 0.05, 0.4), Vector3(sd * 0.45, 0.05, 0), black)
			w.name = "Wing L" if sd < 0 else "Wing R"


func _fire_crows(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	_sound("rustle", -2.0)
	for b in s.get_children():
		var home: Vector3 = b.get_meta("home")
		var away := _off(d + _rng.randf_range(0, 20), 30.0, false) + Vector3(0, 14.0 + _rng.randf_range(0, 8), 0)
		var k := b.get_index()
		var tw := create_tween()
		tw.tween_interval(_rng.randf_range(0, 0.4))
		tw.tween_method(func(u: float) -> void:
			var p := home.lerp(away, u) + Vector3.UP * sin(PI * u) * 4.0
			(b as Node3D).look_at(p + (away - home).normalized(), Vector3.UP)
			(b as Node3D).rotate_object_local(Vector3.UP, PI)
			(b as Node3D).position = p
			var flap := sin(_t * 22.0 + k) * 0.9
			(b.get_node("Wing L") as Node3D).rotation.z = flap
			(b.get_node("Wing R") as Node3D).rotation.z = -flap, 0.0, 1.0, 3.0)
		tw.tween_interval(6.0)
		tw.tween_callback(func() -> void: (b as Node3D).position = home)


# -----------------------------------------------------------------------------
# Hay burst (Earth): a stack of hay bales tumbles over in a burst of straw, then gets stacked again
# -----------------------------------------------------------------------------
func _build_hayburst(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var base := _off(d, 7.0, true)
	var hay := _mat("Hay", Color(0.9, 0.75, 0.35))
	var n := 0
	for row in 4:
		for k in 4 - row:
			var b := _box(s, Vector3(2.0, 1.1, 1.3), base + Vector3((k - (3 - row) / 2.0) * 2.1, 0.55 + row * 1.1, 0), hay)
			b.name = "Bale %d" % n
			b.set_meta("home", b.position)
			n += 1


func _fire_hayburst(s: Node3D) -> void:
	_sound("fwump", -2.0)
	_shake(0.2)
	var mid := Vector3.ZERO
	for b in s.get_children():
		mid += (b as Node3D).position
	mid /= maxf(1.0, s.get_child_count())
	_splash(mid + Vector3.UP, Color(0.95, 0.85, 0.4), 34, 12.0, 0.3)
	for b in s.get_children():
		var home: Vector3 = b.get_meta("home")
		var fling := Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-2, 6))
		var land := Vector3(home.x + fling.x, 0.55, home.z + fling.z)
		var tw := create_tween()
		tw.tween_property(b, "position", home + Vector3.UP * 4.0 + fling * 0.5, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "rotation", Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-2, 2), 0), 0.8)
		tw.tween_property(b, "position", land, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_interval(7.0)
		tw.tween_property(b, "position", home, 0.8)
		tw.parallel().tween_property(b, "rotation", Vector3.ZERO, 0.8)


# -----------------------------------------------------------------------------
# Hot-air balloon (Earth): rises up out of the field beside the road
# -----------------------------------------------------------------------------
func _build_hot_air(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var b := Node3D.new()
	b.name = "Balloon"
	s.add_child(b)
	var home := _off(d + 10.0, 18.0, true)
	b.position = home
	b.scale = Vector3.ONE * 1.4
	b.set_meta("home", home)
	var env := _ball(b, 4.5, Vector3(0, 9.0, 0), _mat("Hot Air", Color(0.95, 0.35, 0.25)))
	env.scale = Vector3(1, 1.2, 1)
	for k in 4:
		var stripe := _ball(b, 4.55, Vector3(0, 9.0, 0), _mat("Hot Air Stripe", Color(1.0, 0.85, 0.3)))
		stripe.scale = Vector3(0.18, 1.21, 1.01)
		stripe.rotation.y = k * PI / 4.0
	_box(b, Vector3(1.6, 1.2, 1.6), Vector3(0, 1.0, 0), _mat("Basket", Color(0.6, 0.42, 0.25)))
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		_box(b, Vector3(0.05, 3.4, 0.05), Vector3(cos(a) * 0.8, 3.3, sin(a) * 0.8), _mat("Rope", Color(0.85, 0.8, 0.7)))


func _fire_hot_air(s: Node3D) -> void:
	var b := s.get_node("Balloon") as Node3D
	var home: Vector3 = b.get_meta("home")
	_sound("fwump", -8.0)
	var tw := create_tween()
	tw.tween_property(b, "position", home + Vector3(6.0, 22.0, -4.0), 9.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(4.0)
	tw.tween_property(b, "position", home, 6.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# -----------------------------------------------------------------------------
# Fireworks (Earth): rockets go up beside the road and burst over it
# -----------------------------------------------------------------------------
func _build_fireworks(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var base := _off(d, 5.0, true)
	_box(s, Vector3(2.4, 0.6, 1.2), base + Vector3.UP * 0.3, _mat("Firework Crate", Color(0.7, 0.2, 0.2)))
	s.set_meta("base", base)


func _fire_fireworks(s: Node3D) -> void:
	var d: float = s.get_meta("d")
	var base: Vector3 = s.get_meta("base")
	var cols := [Color(1.0, 0.35, 0.45), Color(0.4, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.5)]
	for k in 7:
		var top := _pt(d + 2.0 + k * 5.0) + Vector3.UP * (14.0 + (k % 3) * 4.0) + _side(d) * _rng.randf_range(-4, 4)
		var rocket := _ball(self, 0.25, base + Vector3.UP, _mat("Rocket", Color(1, 0.95, 0.8), 2.0))
		var col: Color = cols[k % cols.size()]
		var tw := create_tween()
		tw.tween_interval(k * 0.22)
		tw.tween_callback(func() -> void: _sound("pop", -10.0))
		tw.tween_property(rocket, "position", top, 0.8).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			rocket.queue_free()
			_splash(top, col, 34, 16.0, 0.5)
			_sound("pop", -4.0))
