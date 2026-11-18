extends SportGame

# Sky Sweep (scripts/sports.gd), the broom sport, played in the sky over the Void's Soccer Field with Swoosh. Hayden
# (18 Nov 2026): "the broom sport is reminiscent of quidditch". Our own game, names and look: you fly a broom, grab
# the glowing Sparkball and carry it (or throw it) through one of the three gold hoops at the far end. Zip and Zap,
# two little aliens on brooms, try to swipe it and fly it through the hoops at your end. With half a minute to go
# the Glimmer Moth flutters out: catch it for 3 goals and the match is over.
#
#   Fly:   move as on foot (where the camera looks), hold Jump to go up, hold Roll to go down
#   Throw: Interact while you've got the Sparkball (close to a hoop it always goes in)
#
# Before writing this we read open-source flying and broom games (Hayden's rule): jacobbabula/retro-quidditch (no
# licence, so only read for ideas, nothing copied: a ball you carry and a charged throw, three hoops a side, rivals that
# chase whoever has the ball and tackle, a golden flier let out near the end that finishes the match) and
# mlavik1/GodotSimpleAirplaneController (MIT: speed easing towards a target, and a bank that leans into turns and eases
# back to level when you let go). We kept it much simpler for small hands: no stamina, no throttle, no stalls, the
# broom goes where you push and stops when you let go, and the rivals are a little slower than you.

const TIME := 90.0
const MOTH_AT := 30.0                          # seconds left when the Glimmer Moth comes out
const MOTH_GOALS := 3
const END_X := 22.0                            # the hoops' line at each end (yours to score in at +x)
const HOOPS := [Vector3(0, 7.0, -6.0), Vector3(0, 10.0, 0.0), Vector3(0, 7.0, 6.0)]   # (y, z) of each hoop
const HOOP_R := 1.7
const BOX_MIN := Vector3(-26.0, 2.6, -16.0)    # where you can fly, in the field's space
const BOX_MAX := Vector3(26.0, 17.0, 16.0)
const SPEED := 10.0
const CLIMB := 6.5
const ACCEL := 22.0
const BANK := 0.5                              # how far the broom leans into a turn
const GRAB := 1.7                              # this close to the Sparkball (or whoever has it) and it's yours
const GRACE := 1.6                             # just after a grab nobody can take it straight back
const THROW_REACH := 15.0                      # a throw at a hoop this close always goes in
const RIVAL_SPEED := 6.2
const CENTRE := Vector3(0, 8.5, 0)

var you := 0                                   # your goals
var them := 0                                  # Zip and Zap's goals
var ball_node: Node3D
var holder: Node3D = null                      # who has the Sparkball: the hero, a rival, or nobody (loose)
var rivals: Array[Node3D] = []
var moth: Node3D
var moth_caught := false
var last := ""                                 # "you", "them", "moth", "swiped", "took"
var vel := Vector3.ZERO
var rng := RandomNumberGenerator.new()

var _grace := 0.0
var _pause := 0.0                              # a moment after a goal before play goes on
var _hero_prev := Vector3.ZERO
var _ball_prev := Vector3.ZERO
var _throw_t := -1.0
var _throw_from := Vector3.ZERO
var _throw_to := Vector3.ZERO
var _throw_in := false
var _broom: Node3D
var _seat: Node3D
var _bank := 0.0
var _moth_to := Vector3.ZERO
var _moth_turn := 0.0
var _hoop_nodes: Array[Node3D] = []
var _flying := false
var rivals_on := true                          # (tests stop Zip and Zap to try one thing at a time)


func setup() -> void:
	hold = true                                # (we read the controls ourselves: nothing else moves her)
	rng.randomize()
	if Game.riding:
		Game.riding = false                    # (off the board and onto the broom)
		Game.equipment_changed.emit()
	for side in [-1.0, 1.0]:
		for h in HOOPS:
			_hoop_nodes.append(_make_hoop(Vector3(side * END_X, h.y, h.z), side > 0.0))
	ball_node = _make_ball()
	for k in 2:
		rivals.append(_make_rival(k))
	_reset_play(false)
	place_hero(Vector3(-12.0, 0.4, 0.0), Vector3(END_X, 0, 0))
	_take_off()
	p.global_position = to_global(Vector3(-12.0, CENTRE.y - 1.0, 0.0))
	_hero_prev = to_local(_hero_centre())


func go() -> void:
	sports.shout("Grab the Sparkball!", Color(0.5, 1.0, 1.0), 0.9)


# -----------------------------------------------------------------------------
# Flying
# -----------------------------------------------------------------------------
func _take_off() -> void:
	# Onto the broom: nothing else moves her while we fly her (carried, like the zipline), her legs sit astride it
	_flying = true
	p.set("carried", true)
	p.velocity = Vector3.ZERO
	vel = Vector3.ZERO
	var model := p.get("model") as Node3D
	var anim := p.get("anim") as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var hips_y := -0.3
	var skel := Clothes._skeleton(model) if model else null
	if skel:
		var hb := skel.find_bone("hips")
		if hb >= 0:
			hips_y = clampf(visual.to_local(skel.global_transform * skel.get_bone_global_pose(hb).origin).y, -1.5, 1.5)
		_seat = Seat.new()
		_seat.name = "Broom Seat"
		skel.add_child(_seat)
	_broom = Node3D.new()
	_broom.name = "Broom"
	visual.add_child(_broom)
	_broom.position = Vector3(0, hips_y - 0.06, 0.0)
	_build_broom(_broom, Color(0.55, 0.35, 0.2), Color(1.0, 0.8, 0.35), Color(0.45, 0.95, 1.0))


func _land(local: Vector3) -> void:
	# Off the broom, onto the ground beside the field, facing it
	if not _flying:
		return
	_flying = false
	if is_instance_valid(_broom):
		_broom.queue_free()
	if is_instance_valid(_seat):
		_seat.queue_free()
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0
	p.set("carried", false)
	place_hero(local, Vector3(0, 0, 0))


func put_hero(local: Vector3) -> void:
	# Straight to a spot in the field's space (where her middle goes), with no line drawn from where she was
	p.global_position = to_global(local) - Vector3.UP * 0.7
	vel = Vector3.ZERO
	_hero_prev = local


func _hero_centre() -> Vector3:
	return p.global_position + Vector3.UP * 0.7


func _fly(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var arm := p.get("spring_arm") as Node3D
	var basis := arm.global_transform.basis if arm else global_basis
	var fwd := -basis.z
	var right := basis.x
	fwd.y = 0.0
	right.y = 0.0
	fwd = fwd.normalized()
	right = right.normalized()
	var want := (right * input.x - fwd * input.y) * SPEED
	if Input.is_action_pressed("jump"):
		want.y = CLIMB
	elif Input.is_action_pressed("dash"):
		want.y = -CLIMB
	steer(want, delta)


func steer(want: Vector3, delta: float) -> void:
	# Ease towards the wanted speed and move; the broom stays inside the pitch. (Tests call this with a direction.)
	vel = vel.move_toward(want, ACCEL * delta)
	var to := p.global_position + vel * delta
	var local := to_local(to)
	local = local.clamp(BOX_MIN, BOX_MAX)
	p.global_position = to_global(local)
	p.velocity = vel
	# Her model turns to where she's going, and leans into turns and up or down (easing back to level)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var flat := Vector3(vel.x, 0, vel.z)
	var lean := 0.0
	if flat.length() > 0.6:
		var yaw := atan2(flat.x, flat.z)
		var turn := wrapf(yaw - visual.rotation.y, -PI, PI)
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, minf(1.0, delta * 7.0))
		lean = clampf(-turn * 1.4, -BANK, BANK)
	_bank = lerpf(_bank, lean, minf(1.0, delta * 5.0))
	visual.rotation.z = _bank
	visual.rotation.x = lerpf(visual.rotation.x, clampf(-vel.y / CLIMB, -1.0, 1.0) * 0.25, minf(1.0, delta * 5.0))


# -----------------------------------------------------------------------------
# The match
# -----------------------------------------------------------------------------
func tick(delta: float) -> void:
	super.tick(delta)
	if _flying:
		_fly(delta)
	_grace -= delta
	_spin_bits(delta)
	if _pause > 0.0:
		_pause -= delta
		_hero_prev = to_local(_hero_centre())
		_ball_prev = ball_node.position
		return
	if rivals_on:
		for k in rivals.size():
			_rival(k, delta)
	_ball(delta)
	_moth_tick(delta)
	_hero_prev = to_local(_hero_centre())
	if TIME - time <= 0.0:
		_finish("time")


func _ball(delta: float) -> void:
	if _throw_t >= 0.0:
		_throw_t += delta / 0.7
		ball_node.position = arc(_throw_from, _throw_to, 1.2, _throw_t)
		if _throw_t >= 1.0:
			_throw_t = -1.0
			if _throw_in:
				_scored(true)
			else:
				holder = null
		_ball_prev = ball_node.position
		return
	if holder == null:
		# Loose: it bobs where it is and drifts back towards the middle
		ball_node.position = ball_node.position.move_toward(CENTRE, delta * 0.8)
		ball_node.position.y += sin(time * 3.0) * delta * 0.3
		if _grace <= 0.0 and to_local(_hero_centre()).distance_to(ball_node.position) < GRAB:
			_grab(p)
		else:
			for r in rivals:
				if r.position.distance_to(ball_node.position) < GRAB:
					_grab(r)
					break
	elif holder == p:
		var at := to_local(_hero_centre())
		var visual := p.get_node_or_null("Visual") as Node3D
		var ahead := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y)) if visual else Vector3.RIGHT
		ball_node.position = at + global_basis.inverse() * ahead * 0.55 + Vector3.UP * 0.25
		# Carried through one of the far hoops: a goal
		if _through(_hero_prev, at, 1.0) >= 0:
			_scored(true)
			return
		for r in rivals:
			if _grace <= 0.0 and r.position.distance_to(at) < GRAB * 0.8:
				_grab(r)
				last = "swiped"
				sports.shout("Swiped!", Color(1.0, 0.5, 0.6), 0.6)
				break
	else:
		ball_node.position = holder.position + Vector3(0, 0.9, 0)
		if _through(_ball_prev, ball_node.position, -1.0) >= 0:
			_scored(false)
			return
		if _grace <= 0.0 and to_local(_hero_centre()).distance_to(holder.position + Vector3.UP * 0.5) < GRAB:
			_grab(p)
			last = "took"
			sports.shout("Got it back!", Color(0.5, 1.0, 0.6), 0.6)
	_ball_prev = ball_node.position


func _through(a: Vector3, b: Vector3, side: float) -> int:
	# Which hoop (0..2) at that end the line from a to b passed through this frame, or -1
	var x := side * END_X
	if (a.x - x) * (b.x - x) > 0.0 or is_equal_approx(a.x, b.x):
		return -1
	var k := (x - a.x) / (b.x - a.x)
	var hit := a.lerp(b, k)
	for i in HOOPS.size():
		var h: Vector3 = HOOPS[i]
		if Vector2(hit.y - h.y, hit.z - h.z).length() < HOOP_R:
			return i
	return -1


func _grab(who: Node3D) -> void:
	holder = who
	_grace = GRACE
	_throw_t = -1.0
	if who == p:
		Juice.blip("pop", 1.2)
	else:
		Juice.blip("whoosh", 0.9, -4.0)


func action() -> void:
	# Interact with the Sparkball: throw it. At a hoop near enough in front it always goes in; otherwise it flies on
	# ahead and floats there, loose.
	if holder != p or _pause > 0.0:
		return
	var at := to_local(_hero_centre())
	var visual := p.get_node_or_null("Visual") as Node3D
	var ahead := global_basis.inverse() * (Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y)) if visual else Vector3.RIGHT)
	var best := -1
	var best_d := THROW_REACH
	for i in HOOPS.size():
		var h: Vector3 = HOOPS[i]
		var c := Vector3(END_X, h.y, h.z)
		var d := at.distance_to(c)
		if d < best_d and (c - at).normalized().dot(ahead) > 0.2:
			best = i
			best_d = d
	_throw_from = ball_node.position
	if best >= 0:
		var h: Vector3 = HOOPS[best]
		_throw_to = Vector3(END_X + 1.5, h.y, h.z)
		_throw_in = true
	else:
		_throw_to = (at + ahead * 8.0).clamp(BOX_MIN, BOX_MAX)
		_throw_in = false
	_throw_t = 0.0
	holder = null
	_grace = 0.5
	Juice.blip("whoosh", 1.1)


func _scored(yours: bool) -> void:
	if yours:
		you += 1
		last = "you"
		sports.shout("GOAL!", Color(0.5, 1.0, 0.6), 0.7)
		Audio.play("level_up")
		Juice.burst(self, to_global(Vector3(END_X, 8.5, 0)), Color(1.0, 0.85, 0.3), 24, 0.14)
	else:
		them += 1
		last = "them"
		sports.shout("Zip and Zap score!", Color(1.0, 0.55, 0.6), 0.7)
		Juice.blip("thud")
	_reset_play(true)


func _reset_play(pause: bool) -> void:
	holder = null
	_throw_t = -1.0
	ball_node.position = CENTRE
	_ball_prev = CENTRE
	_grace = 0.0
	for k in rivals.size():
		rivals[k].position = Vector3(10.0, 8.0, -4.0 if k == 0 else 4.0)
		face(rivals[k], to_global(Vector3(-END_X, 8.0, 0)))
	if pause:
		_pause = 1.2


func _rival(k: int, delta: float) -> void:
	# Zip and Zap: with the Sparkball loose, both go for it; you've got it, one chases you and the other blocks your
	# way to the hoops; one of them has it, they fly it at the middle hoop at your end and the other keeps close.
	var r := rivals[k]
	var speed: float = RIVAL_SPEED * [0.85, 1.0, 1.2][clampi(Settings.skate_assist, 0, 2)]
	var target := r.position
	var me := to_local(_hero_centre())
	if holder == null:
		target = ball_node.position
	elif holder == p:
		target = me if k == 0 else Vector3(END_X - 4.0, me.y, me.z * 0.6)
	elif holder == r:
		var h: Vector3 = HOOPS[1]
		target = Vector3(-END_X - 4.0, h.y, h.z)
		speed *= 0.8                           # (carrying slows them down: you can catch them)
		if r.position.x > -END_X + 3.0:
			target = Vector3(-END_X + 2.0, h.y, h.z) if absf(r.position.z) > 1.0 or absf(r.position.y - h.y) > 1.0 \
				else target
	else:
		target = holder.position + Vector3(0, 0, 2.5 if k == 1 else -2.5)
	var to := target - r.position
	if to.length() > 0.05:
		r.position += to.normalized() * minf(to.length(), speed * delta)
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > 0.2:
			r.rotation.y = lerp_angle(r.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))
	r.position.y = clampf(r.position.y, BOX_MIN.y, BOX_MAX.y)
	r.position.x = clampf(r.position.x, -END_X - 4.0, END_X + 4.0)
	r.position.z = clampf(r.position.z, BOX_MIN.z, BOX_MAX.z)
	var seat := r.get_node_or_null("Seat") as Node3D
	if seat:
		seat.position.y = 0.4 + sin(time * 2.4 + k) * 0.08


func _moth_tick(delta: float) -> void:
	if moth_caught:
		return
	if moth == null:
		if TIME - time <= MOTH_AT:
			moth = _make_moth()
			moth.position = Vector3(rng.randf_range(-15, 15), rng.randf_range(6, 13), rng.randf_range(-10, 10))
			_moth_to = moth.position
			sports.shout("The Glimmer Moth!", Color(1.0, 0.85, 0.3), 0.9)
			Juice.blip("sparkle")
		return
	# It flutters from spot to spot, and darts away when you get close (a bit slower than you)
	var me := to_local(_hero_centre())
	_moth_turn -= delta
	var near := moth.position.distance_to(me) < 6.0
	if _moth_turn <= 0.0 or moth.position.distance_to(_moth_to) < 0.5:
		_moth_turn = rng.randf_range(0.8, 1.6)
		var away := (moth.position - me).normalized() * 6.0 if near else Vector3.ZERO
		_moth_to = (moth.position + away + Vector3(rng.randf_range(-5, 5), rng.randf_range(-2.5, 2.5),
			rng.randf_range(-5, 5))).clamp(BOX_MIN + Vector3(3, 2, 3), BOX_MAX - Vector3(3, 2, 3))
	var speed := 7.0 if near else 4.0
	moth.position = moth.position.move_toward(_moth_to, speed * delta) + Vector3(0, sin(time * 9.0) * 0.02, 0)
	var flat := _moth_to - moth.position
	if Vector2(flat.x, flat.z).length() > 0.1:
		moth.rotation.y = atan2(flat.x, flat.z)
	for w in ["WingL", "WingR"]:
		var wing := moth.get_node_or_null(w) as Node3D
		if wing:
			wing.rotation.z = (1.0 if w == "WingL" else -1.0) * (0.3 + sin(time * 30.0) * 0.6)
	if moth.position.distance_to(me) < GRAB * 0.85:
		catch_moth()


func catch_moth() -> void:
	if moth_caught or moth == null:
		return
	moth_caught = true
	you += MOTH_GOALS
	last = "moth"
	Juice.burst(self, moth.global_position, Color(1.0, 0.85, 0.3), 24, 0.12)
	moth.queue_free()
	Juice.blip("sparkle")
	Audio.play("level_up")
	_finish("moth")


func _finish(why: String) -> void:
	_land(Vector3(3.0, 0.4, 11.0))
	var head := "You win!" if you > them else ("A draw!" if you == them else "Zip and Zap win!")
	if why == "moth":
		head = "Glimmer Moth! " + head
	sports.over(float(you), head)


func status() -> Array:
	return ["You %d  Zip & Zap %d" % [you, them], "%d s" % ceili(maxf(0.0, TIME - time))]


func teardown() -> void:
	if _flying:
		_land(Vector3(3.0, 0.4, 11.0))
	super.teardown()


# -----------------------------------------------------------------------------
# The pieces
# -----------------------------------------------------------------------------
func _make_hoop(at: Vector3, yours: bool) -> Node3D:
	# A gold hoop on a tall thin pole, a little flag on top in the colour of whose end it is
	var g := Node3D.new()
	g.name = "Sky Hoop"
	add_child(g)
	g.position = at
	var t := TorusMesh.new()
	t.inner_radius = HOOP_R - 0.12
	t.outer_radius = HOOP_R + 0.08
	var ring_m := mesh_on(g, t, Vector3.ZERO, mat(Color(1.0, 0.82, 0.3), 0.9, 0.6))
	ring_m.rotation.z = PI / 2.0                           # (standing up, the hole facing along the field)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = at.y - HOOP_R
	mesh_on(g, pole, Vector3(0, -HOOP_R - pole.height / 2.0, 0), mat(Color(0.85, 0.8, 0.95), 0.0, 0.5))
	var flag := BoxMesh.new()
	flag.size = Vector3(0.05, 0.4, 0.6)
	var colour := Color(0.45, 0.95, 1.0) if yours else Color(1.0, 0.45, 0.6)
	mesh_on(g, flag, Vector3(0, HOOP_R + 0.4, 0.3), mat(colour, 0.6))
	var stick := CylinderMesh.new()
	stick.top_radius = 0.025
	stick.bottom_radius = 0.025
	stick.height = 0.7
	mesh_on(g, stick, Vector3(0, HOOP_R + 0.3, 0), mat(Color(1, 1, 1)))
	g.set_meta("yours", yours)
	return g


func _make_ball() -> Node3D:
	# The Sparkball: a glowing teal ball with a gold star ring spinning round it
	var b := Node3D.new()
	b.name = "Sparkball"
	add_child(b)
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	mesh_on(b, s, Vector3.ZERO, mat(Color(0.45, 1.0, 0.95), 1.6))
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.48
	var r := mesh_on(b, t, Vector3.ZERO, mat(Color(1.0, 0.85, 0.35), 1.0, 0.6))
	r.name = "Spin"
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.95)
	light.omni_range = 4.0
	light.light_energy = 1.2
	b.add_child(light)
	return b


func _make_rival(k: int) -> Node3D:
	# Zip (red) and Zap (blue): little aliens sitting on brooms
	var r := Node3D.new()
	r.name = "Zip" if k == 0 else "Zap"
	add_child(r)
	var model := (load("res://models/characters/little_alien_%s.glb" % ("red" if k == 0 else "blue")) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * 1.7
	# A holder lifts it so it sits on the stick (its "sit" animation moves the model's own root, so that can't)
	var lift := Node3D.new()
	lift.name = "Seat"
	lift.position.y = 0.4
	r.add_child(lift)
	lift.add_child(model)
	LittleAliens.vary_snout(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		var a := "sit" if anim.has_animation("sit") else "idle"
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.play(a)
	var broom := Node3D.new()
	broom.name = "Broom"
	r.add_child(broom)
	broom.position = Vector3(0, 0.38, 0)
	broom.scale = Vector3.ONE * 0.85
	_build_broom(broom, Color(0.4, 0.25, 0.18), Color(0.85, 0.85, 0.95),
		Color(1.0, 0.4, 0.4) if k == 0 else Color(0.45, 0.6, 1.0))
	var l := label_on(r, r.name, 22, Vector3(0, 1.6, 0))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return r


func _make_moth() -> Node3D:
	# The Glimmer Moth: a little gold moth that glows, with fluttering wings
	var m := Node3D.new()
	m.name = "Glimmer Moth"
	add_child(m)
	var body := CapsuleMesh.new()
	body.radius = 0.09
	body.height = 0.4
	mesh_on(m, body, Vector3.ZERO, mat(Color(1.0, 0.85, 0.35), 2.0, 0.6)).rotation.x = PI / 2.0
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if side < 0.0 else "WingR"
		m.add_child(w)
		var wing := SphereMesh.new()
		wing.radius = 0.3
		wing.height = 0.04
		mesh_on(w, wing, Vector3(side * 0.28, 0, 0), mat(Color(1.0, 0.95, 0.6, 1.0), 1.4)).scale = Vector3(1.0, 1.0, 0.7)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.omni_range = 3.0
	m.add_child(light)
	return m


static func _build_broom(at: Node3D, wood: Color, band: Color, bristles: Color) -> void:
	# A broom along +Z (the way a model faces): a handle, a band, and a bushy bundle of bristles at the back
	var handle := CylinderMesh.new()
	handle.top_radius = 0.035
	handle.bottom_radius = 0.045
	handle.height = 1.9
	mesh_on(at, handle, Vector3(0, 0, 0.25), mat(wood)).rotation.x = PI / 2.0
	var tip := SphereMesh.new()
	tip.radius = 0.06
	tip.height = 0.12
	mesh_on(at, tip, Vector3(0, 0, 1.2), mat(band, 0.6, 0.7))
	var ring_m := CylinderMesh.new()
	ring_m.top_radius = 0.07
	ring_m.bottom_radius = 0.07
	ring_m.height = 0.1
	mesh_on(at, ring_m, Vector3(0, 0, -0.62), mat(band, 0.3, 0.7)).rotation.x = PI / 2.0
	var bush := CylinderMesh.new()
	bush.top_radius = 0.07
	bush.bottom_radius = 0.26
	bush.height = 0.65
	mesh_on(at, bush, Vector3(0, 0, -0.98), mat(bristles, 0.25)).rotation.x = -PI / 2.0
	# (the bush's wide end at the back)


func _spin_bits(delta: float) -> void:
	if is_instance_valid(ball_node):
		var s := ball_node.get_node_or_null("Spin") as Node3D
		if s:
			s.rotate_y(delta * 3.0)
			s.rotation.x = 0.6


# Her legs astride the broom: after the animation, each thigh swings forward and a little out, and the shin hangs back
# down from the knee (a SkeletonModifier3D, like star_popper.gd's PopperArm, so it never fights the animation).
class Seat extends SkeletonModifier3D:
	func _process_modification() -> void:
		var skel := get_skeleton()
		if skel == null:
			return
		for side in ["L", "R"]:
			var thigh := skel.find_bone("thigh." + side)
			var shin := skel.find_bone("shin." + side)
			if thigh < 0 or shin < 0:
				continue
			var out := 0.22 if side == "L" else -0.22
			var tp := skel.get_bone_global_pose(thigh)
			tp.basis = Basis(Vector3.FORWARD, out) * Basis(Vector3.RIGHT, -1.25) * tp.basis
			skel.set_bone_global_pose(thigh, tp)
			var sp := skel.get_bone_global_pose(shin)
			sp.basis = Basis(Vector3.RIGHT, 1.05) * sp.basis
			skel.set_bone_global_pose(shin, sp)
