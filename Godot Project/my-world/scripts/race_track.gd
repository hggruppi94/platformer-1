class_name RaceTrack
extends Node3D

# One race track (scripts/races.gd places it and runs the race): the smooth line the racers follow, worked out from
# the track's checkpoints and laid on the real ground, and everything on it. Always there: the start arch (also the
# finish line), the boost pads, the starter alien with her flag and the race board. Only while racing: a glowing ring
# at each checkpoint (the next one gold), the Star Boxes that give power-ups, and goo puddles that slow you down.
# Built from shapes, in the town's alien palette, so it needs no model and the town scene isn't rebuilt.

const RING_RADIUS := 4.2
const RING_HEIGHT := 3.0             # the ring's middle above the ground
const STEP := 1.0                    # metres between the line's points
const PAD_SIZE := Vector3(2.6, 0.06, 3.4)
const BOX_SPACING := 2.6             # metres between the Star Boxes across the track
const STARTER_MODEL := "res://models/characters/little_alien_pink.glb"

const NEXT_COLOUR := Color(1.0, 0.82, 0.3)
const LATER_COLOUR := Color(0.62, 0.5, 0.95)
const PASSED_COLOUR := Color(0.4, 0.95, 0.75)

var track: Dictionary
var line := PackedVector3Array()     # the racing line, a point every STEP metres, on the ground, all the way round
var dist := PackedFloat32Array()     # how far round each point is
var length := 0.0
var cp_dist: Array[float] = []       # how far round each checkpoint is (checkpoint 0 is the start and finish)
var rings: Array[Node3D] = []
var pads: Array[Node3D] = []
var boxes: Array[Node3D] = []
var goo: Array[Node3D] = []
var board_text: Label3D
var starter: Node3D
var ready_to_race := false
var _t := 0.0
var _ring_mats: Array[StandardMaterial3D] = []


func setup(t: Dictionary) -> void:
	track = t


func _ready() -> void:
	# The ground is only there to feel for once physics has had a frame with the town in it
	await get_tree().physics_frame
	await get_tree().physics_frame
	_make_line()
	_arch()
	_starter()
	_board()
	for b in track.get("boosts", []):
		pads.append(_pad(at(float(b[0])), float(b[1]) if b.size() > 1 else 0.0))
	for i in cp_dist.size():
		rings.append(_ring(i))
	for b in track.get("boxes", []):
		for k in 3:
			boxes.append(_box(at(float(b[0])), (k - 1) * BOX_SPACING))
	for g in track.get("goo", []):
		goo.append(_goo(at(float(g[0])), float(g[1])))
	show_race(false)
	ready_to_race = true
	board_text.text = Races.board_text(str(get_meta("track_id", "")))


# -----------------------------------------------------------------------------
# The racing line
# -----------------------------------------------------------------------------
func _make_line() -> void:
	# A smooth loop through the checkpoints (Catmull-Rom, so it passes right through each one), then each point is
	# dropped onto whatever's under it
	var pts: Array = track.points
	var n := pts.size()
	var flat: Array[Vector2] = []
	var cp_index: Array[int] = []
	for i in n:
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var p3: Vector2 = pts[(i + 2) % n]
		var steps := maxi(2, int(ceil(p1.distance_to(p2) / STEP)))
		cp_index.append(flat.size())
		for s in steps:
			var t := float(s) / steps
			flat.append(_catmull(p0, p1, p2, p3, t))
	line.resize(flat.size())
	dist.resize(flat.size())
	var total := 0.0
	for i in flat.size():
		line[i] = ground_at(flat[i])
		if i > 0:
			total += Vector2(line[i].x, line[i].z).distance_to(Vector2(line[i - 1].x, line[i - 1].z))
		dist[i] = total
	length = total + Vector2(line[0].x, line[0].z).distance_to(Vector2(line[-1].x, line[-1].z))
	cp_dist.clear()
	for i in cp_index:
		cp_dist.append(dist[i])


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func ground_at(xz: Vector2) -> Vector3:
	# The top of whatever solid thing is under this spot: the ground, a path, the paving in the square. Moving things
	# (the player, little aliens, Gloops) are looked through.
	var space := get_world_3d().direct_space_state
	var from := Vector3(xz.x, 60.0, xz.y)
	var skip: Array[RID] = []
	for k in 6:
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(xz.x, -40.0, xz.y))
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if hit.collider is StaticBody3D:
			return hit.position
		skip.append(hit.rid)
	return Vector3(xz.x, 0.0, xz.y)


func at(seg: float) -> float:
	# A checkpoint number plus how far on to the next one (2.5: halfway from checkpoint 2 to 3) -> metres round
	var i := clampi(int(floor(seg)), 0, cp_dist.size() - 1)
	var a: float = cp_dist[i]
	var b: float = cp_dist[i + 1] if i + 1 < cp_dist.size() else length
	return a + (b - a) * (seg - i)


func laps_length(laps: int) -> float:
	return length * laps


func point_at(d: float) -> Vector3:
	# The racing line this far round (any distance: it wraps round the loop)
	d = fposmod(d, length)
	var i := _index_at(d)
	var j := (i + 1) % line.size()
	var span := (dist[j] if j > 0 else length) - dist[i]
	var f := clampf((d - dist[i]) / maxf(span, 0.001), 0.0, 1.0)
	return line[i].lerp(line[j], f)


func dir_at(d: float) -> Vector3:
	var a := point_at(d - 1.5)
	var b := point_at(d + 1.5)
	var v := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


func side_at(d: float) -> Vector3:
	# To the right of the way the race goes
	return dir_at(d).cross(Vector3.UP).normalized()


func _index_at(d: float) -> int:
	# Binary search for the last point at or before d
	var lo := 0
	var hi := dist.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if dist[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


func nearest(pos: Vector3, around := -1.0, reach := 40.0) -> float:
	# How far round the line the nearest point to pos is. With "around", only near there (so a loop that comes back
	# close to itself can't jump ahead).
	var best := 0.0
	var best_d2 := INF
	var p := Vector2(pos.x, pos.z)
	for i in line.size():
		if around >= 0.0:
			var off := absf(fposmod(dist[i] - around + length / 2.0, length) - length / 2.0)
			if off > reach:
				continue
		var d2 := p.distance_squared_to(Vector2(line[i].x, line[i].z))
		if d2 < best_d2:
			best_d2 = d2
			best = dist[i]
	return best


func off_line(pos: Vector3, d: float) -> float:
	# How far to the side of the line (metres) pos is, at d
	var c := point_at(d)
	return Vector2(pos.x - c.x, pos.z - c.z).length()


func place_on(node: Node3D, d: float, side := 0.0, up := 0.0) -> void:
	var at := point_at(d) + side_at(d) * side
	at = ground_at(Vector2(at.x, at.z)) + Vector3.UP * up
	var f := dir_at(d)
	node.global_position = at
	node.global_basis = Basis.looking_at(-f, Vector3.UP)          # +Z faces the way the race goes


# -----------------------------------------------------------------------------
# What's on the track
# -----------------------------------------------------------------------------
func show_race(on: bool) -> void:
	for r in rings:
		r.visible = on
	for b in boxes:
		b.visible = on
		b.set_meta("gone", 0.0)
	for g in goo:
		g.visible = on
	if on:
		light_rings(1)


func light_rings(next: int) -> void:
	# The next checkpoint glows gold, the rest lilac; the finish arch has its own lights
	for i in _ring_mats.size():
		var c := NEXT_COLOUR if i == next else LATER_COLOUR
		_ring_mats[i].albedo_color = Color(c, 0.9 if i == next else 0.45)
		_ring_mats[i].emission = c
		_ring_mats[i].emission_energy_multiplier = 2.2 if i == next else 0.6
		rings[i].scale = Vector3.ONE * (1.0 if i == next else 0.9)


func _process(delta: float) -> void:
	_t += delta
	for pad in pads:
		var glow := pad.get_node_or_null("Glow") as MeshInstance3D
		if glow:
			(glow.material_override as StandardMaterial3D).emission_energy_multiplier = 1.4 + sin(_t * 6.0) * 0.6
		for k in 3:
			var chevron := pad.get_node_or_null("Chevron%d" % k) as Node3D
			if chevron:
				chevron.position.z = -1.0 + fposmod(k * 0.9 + _t * 2.4, 2.7)
	for b in boxes:
		var spin := b.get_node_or_null("Spin") as Node3D
		if spin:
			spin.rotation.y = _t * 1.6
			spin.position.y = 1.1 + sin(_t * 2.5 + b.position.x) * 0.15
		var gone := float(b.get_meta("gone", 0.0))
		if gone > 0.0:
			gone -= delta
			b.set_meta("gone", gone)
			if spin:
				spin.visible = gone <= 0.0
	for r in rings:
		if r.visible:
			r.get_node("Ring").rotation.z = _t * 0.4


func _mat(c: Color, glow := 0.0, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _label(parent: Node3D, text: String, size: int, at: Vector3, c := Color(1, 0.95, 0.75)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = c
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.position = at
	parent.add_child(l)
	return l


func _ring(i: int) -> Node3D:
	# A big glowing hoop standing across the track at a checkpoint. No collision: it's to ride through.
	var holder := Node3D.new()
	holder.name = "Checkpoint %d" % i
	add_child(holder)
	place_on(holder, cp_dist[i])
	var ring := Node3D.new()
	ring.name = "Ring"
	ring.position.y = RING_HEIGHT
	holder.add_child(ring)
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.25
	torus.outer_radius = RING_RADIUS + 0.25
	torus.rings = 48
	var m := _mat(Color(LATER_COLOUR, 0.6), 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mats.append(m)
	var mi := _mesh(ring, torus, Vector3.ZERO, m)
	mi.rotation.x = PI / 2.0                     # stand it up, facing along the track
	# Little stars round the hoop, so it twinkles as it turns
	var star_m := _mat(Color(1, 1, 0.9), 3.0)
	for k in 8:
		var a := TAU * k / 8.0
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		_mesh(ring, s, Vector3(cos(a), sin(a), 0) * RING_RADIUS, star_m)
	if i == 0:
		holder.visible = false                    # the start arch is checkpoint 0's ring
	return holder


func _arch() -> void:
	# The start and finish: two lilac towers with gold tops, a banner across with a chequered strip, and the race's
	# name on it. Solid towers, so they're a landmark, set back off the line so nobody hits them.
	var arch := Node3D.new()
	arch.name = "Start Arch"
	add_child(arch)
	place_on(arch, cp_dist[0])
	var half := 6.2
	var tower := _mat(Color(0.62, 0.5, 0.95))
	var gold := _mat(Color(1.0, 0.82, 0.35), 0.4, 0.3)
	for side in [-1.0, 1.0]:
		var t := CylinderMesh.new()
		t.top_radius = 0.45
		t.bottom_radius = 0.6
		t.height = 6.0
		_mesh(arch, t, Vector3(side * half, 3.0, 0), tower)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.7
		cone.height = 1.2
		_mesh(arch, cone, Vector3(side * half, 6.6, 0), gold)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.6
		shape.height = 6.0
		cs.shape = shape
		body.position = Vector3(side * half, 3.0, 0)
		body.add_child(cs)
		arch.add_child(body)
	var banner := BoxMesh.new()
	banner.size = Vector3(half * 2.0, 1.3, 0.2)
	_mesh(arch, banner, Vector3(0, 5.4, 0), _mat(Color(0.22, 0.16, 0.34)))
	# The chequered strip along the bottom of the banner
	var cells := 24
	for k in cells:
		for row in 2:
			var cell := BoxMesh.new()
			cell.size = Vector3(half * 2.0 / cells, 0.18, 0.24)
			var white := (k + row) % 2 == 0
			_mesh(arch, cell, Vector3(-half + (k + 0.5) * half * 2.0 / cells, 4.66 + row * 0.18, 0),
				_mat(Color(0.98, 0.96, 0.9) if white else Color(0.15, 0.1, 0.25)))
	for face in [1.0, -1.0]:
		var l := _label(arch, track.get("name", "Race").to_upper(), 64, Vector3(0, 5.45, 0.12 * face))
		l.rotation.y = 0.0 if face > 0 else PI
	# The line on the ground
	for k in 12:
		for row in 2:
			var tile := BoxMesh.new()
			tile.size = Vector3(half * 2.0 / 12.0, 0.03, 0.5)
			_mesh(arch, tile, Vector3(-half + (k + 0.5) * half * 2.0 / 12.0, 0.04, (row - 0.5) * 0.5),
				_mat(Color(0.98, 0.96, 0.9) if (k + row) % 2 == 0 else Color(0.15, 0.1, 0.25)))


func _starter() -> void:
	# Zippy, the pink little alien who starts the races, beside the line with a chequered flag
	var d := cp_dist[0] - 4.0
	starter = Node3D.new()
	starter.name = "Zippy"
	add_child(starter)
	place_on(starter, d, 8.5)                         # on the town side of the line, away from the lake
	_face(starter, point_at(d))
	var model := (load(STARTER_MODEL) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 1.9
	starter.add_child(model)
	LittleAliens.vary_snout(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.35, 0.5, 0.15)
	starter.add_child(flag)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.02
	pole.bottom_radius = 0.02
	pole.height = 1.3
	_mesh(flag, pole, Vector3(0, 0.6, 0), _mat(Color(1.0, 0.82, 0.35), 0.0, 0.3))
	for k in 4:
		for row in 3:
			var cell := BoxMesh.new()
			cell.size = Vector3(0.012, 0.11, 0.11)
			_mesh(flag, cell, Vector3(0, 1.18 - row * 0.11, 0.07 + k * 0.11),
				_mat(Color(0.98, 0.96, 0.9) if (k + row) % 2 == 0 else Color(0.15, 0.1, 0.25)))
	_label(starter, "Zippy", 26, Vector3(0, 1.9, 0)).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var spot := (load("res://scripts/race_spot.gd") as GDScript).new() as Area3D
	spot.name = "Race Talk"
	spot.set("verb", "race")
	starter.add_child(spot)


func _face(node: Node3D, target: Vector3) -> void:
	# Turn to face a spot (models and boards face +Z)
	var to := Vector3(target.x - node.global_position.x, 0.0, target.z - node.global_position.z)
	if to.length() > 0.01:
		node.global_basis = Basis.looking_at(-to.normalized(), Vector3.UP)


func _board() -> void:
	# The race board beside Zippy: the race, the prizes, the best time and the trophies so far (written by Races)
	var board := Node3D.new()
	board.name = "Race Board"
	add_child(board)
	place_on(board, cp_dist[0] - 9.0, 9.5)
	_face(board, point_at(cp_dist[0] - 9.0))
	var wood := _mat(Color(0.36, 0.22, 0.42))
	for side in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.14, 3.3, 0.14)
		_mesh(board, post, Vector3(side * 1.45, 1.65, 0), wood)
	var face := BoxMesh.new()
	face.size = Vector3(2.9, 2.3, 0.1)
	_mesh(board, face, Vector3(0, 2.05, 0), _mat(Color(0.22, 0.16, 0.34)))
	var top := BoxMesh.new()
	top.size = Vector3(3.1, 0.12, 0.16)
	_mesh(board, top, Vector3(0, 3.25, 0.01), _mat(Color(1.0, 0.82, 0.35), 0.4, 0.3))
	board_text = _label(board, "", 24, Vector3(0, 2.0, 0.07))
	board_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_text.width = 270
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.9, 3.0, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 1.5, 0)
	body.add_child(cs)
	board.add_child(body)


func _pad(d: float, side: float) -> Node3D:
	# A boost pad: a glowing teal pad with gold chevrons sliding along it the way the race goes
	var pad := Node3D.new()
	pad.name = "Boost Pad"
	add_child(pad)
	place_on(pad, d, side, 0.02)
	var base := BoxMesh.new()
	base.size = PAD_SIZE
	_mesh(pad, base, Vector3.ZERO, _mat(Color(0.12, 0.3, 0.4)))
	var glow := BoxMesh.new()
	glow.size = Vector3(PAD_SIZE.x - 0.3, 0.02, PAD_SIZE.z - 0.3)
	var g := _mesh(pad, glow, Vector3(0, 0.04, 0), _mat(Color(0.3, 0.95, 0.95), 1.6))
	g.name = "Glow"
	var chev_m := _mat(Color(1.0, 0.85, 0.35), 2.5)
	chev_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var chevron := Node3D.new()
		chevron.name = "Chevron%d" % k
		chevron.position = Vector3(0, 0.07, 0)
		pad.add_child(chevron)
		for s in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.95, 0.03, 0.22)
			var b := _mesh(chevron, bar, Vector3(s * 0.38, 0, -0.2), chev_m)
			b.rotation.y = s * 0.7
	pad.set_meta("d", d)
	return pad


func _box(d: float, side: float) -> Node3D:
	# A Star Box: a floating, turning, see-through lilac cube with a gold star inside. Ride through it for a power-up.
	var holder := Node3D.new()
	holder.name = "Star Box"
	add_child(holder)
	place_on(holder, d, side)
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position.y = 1.1
	holder.add_child(spin)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.9
	var m := _mat(Color(0.75, 0.6, 1.0, 0.55), 0.8)
	_mesh(spin, cube, Vector3.ZERO, m).rotation = Vector3(0.6, 0, 0.6)
	var star_m := _mat(Color(1.0, 0.85, 0.3), 2.5)
	for k in 5:
		var spike := PrismMesh.new()
		spike.size = Vector3(0.16, 0.24, 0.08)
		var sp := _mesh(spin, spike, Vector3(sin(TAU * k / 5.0) * -0.12, cos(TAU * k / 5.0) * 0.12, 0), star_m)
		sp.rotation.z = TAU * k / 5.0
	var q := _label(spin, "?", 48, Vector3(0, 0, 0.47), Color(1, 1, 1))
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.set_meta("d", d)
	return holder


func _goo(d: float, side: float) -> Node3D:
	# A puddle of the Gloop King's goo across part of the track: rolling through it is slow going
	var puddle := Node3D.new()
	puddle.name = "Goo Puddle"
	add_child(puddle)
	place_on(puddle, d, side, 0.03)
	var goo_m := _mat(Color(0.55, 0.85, 0.2), 0.5, 0.15)
	var blob := CylinderMesh.new()
	blob.top_radius = 1.9
	blob.bottom_radius = 2.0
	blob.height = 0.06
	_mesh(puddle, blob, Vector3.ZERO, goo_m)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		var lump := CylinderMesh.new()
		lump.top_radius = 0.6
		lump.bottom_radius = 0.7
		lump.height = 0.05
		_mesh(puddle, lump, Vector3(cos(a) * 1.8, 0.0, sin(a) * 1.8), goo_m)
		var bubble := SphereMesh.new()
		bubble.radius = 0.12 + 0.05 * (k % 2)
		bubble.height = bubble.radius * 2.0
		_mesh(puddle, bubble, Vector3(cos(a * 2.0) * 0.9, 0.06, sin(a * 2.0) * 0.9), _mat(Color(0.7, 0.95, 0.35, 0.8), 0.6))
	puddle.set_meta("d", d)
	return puddle
