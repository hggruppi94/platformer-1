class_name Skate
extends Node

# Riding: Tony Hawk-style arcade skating for whoever is on the ride (Nina on her board, for now). The player
# (scenes/player/player.gd) hands its whole physics step over to this while Game.riding is on. How the ride feels
# (speeds, ollie height, spin speed, balance) comes from scripts/rides.gd, so other characters' rides can share it.
#
#   Rolling: push by steering the way you're going, carve by steering to the side, pull back to brake. Slopes and
#            ramps really pull on you, so you can pump a halfpipe.
#   Ollie:   hold Jump to crouch, let go to pop (a longer hold pops higher).
#   Air:     left and right spin. Land facing the way you're going (or straight backwards) to ride away; land
#            sideways and she bails. Going straight up off a steep ramp is a vert air: she turns round by herself
#            and comes back down onto the ramp.
#   Grind:   press (or hold) Grind near a rail or a ledge edge to lock on. Keep the balance needle in the middle with
#            left and right, Jump to pop off. Rails sloping down speed you up.
#   Bail:    a silly tumble (no damage), stars round her head, and she hops back on.
#   Tricks:  in the air, Flip + a direction flips the board, Grab + a direction (held) grabs it, Flip and Grab together
#            with a full special meter does her special. Grind + a direction picks the grind. On the ground, forward
#            then back quickly starts a manual (back then forward, a nose manual), balanced with forward and back.
#            Scoring and combos: scenes/player/skate_tricks.gd.

signal bailed
signal landed(clean: bool)

enum State { ROLL, AIR, GRIND, BAIL }

const FEET := 0.8                    # from the body's middle down to her feet (the collision capsule's half height)
const FLOOR_MIN_Y := 0.17            # ground up to 80 degrees steep counts as something to ride on
const SNAP := 0.35                   # how far she's pulled down onto a slope that drops away under her
const SIDE_RADIUS := 0.35            # the capsule's radius
const BAIL_LINES := ["Whoops!", "Oof!", "Wobbly!", "Banana peel!", "Bonk!", "Ta-da? No...", "Wipeout!"]

var p: Player
var ride: Dictionary = Rides.BOARD
var state := State.ROLL
var rng := RandomNumberGenerator.new()

var _yaw := 0.0                      # which way the board points (the model faces +Z, so atan2(x, z))
var _normal := Vector3.UP            # the ground under the board (UP in the air)
var _grounded := false               # touching something to ride on after the last move (see _move)
var _ground_n := Vector3.UP          # ...and which way it faces
var _charge := -1.0                  # ollie charge 0..1 while Jump is held; -1 when not crouching
var _coyote := 0.0                   # a moment after rolling off an edge when an ollie still works
var _air_time := 0.0
var _air_spin := 0.0                 # how far she has turned on purpose in this air (radians, signed)
var _vert := false                   # this air started straight up off a steep ramp
var _auto_turn := 0.0                # vert: the half turn still to do by herself before landing
var _grind_buffer := 0.0             # a Grind press is remembered this long
var _rail: GrindRail
var _rail_offset := 0.0
var _rail_dir := 1.0                 # +1 along the rail's curve, -1 against it
var _rail_speed := 0.0
var _rail_snap := 0.0                # eases her onto the rail over a moment instead of teleporting
var _snap_from := Vector3.ZERO
var _last_rail: GrindRail            # just came off this one: don't snap straight back on
var _last_rail_timer := 0.0
var balance := 0.0                   # -1..1 on a grind; off either end and she falls off
var _balance_vel := 0.0
var _grind_time := 0.0
var _bail_timer := 0.0
var _spark_timer := 0.0
var _lean := 0.0                     # visual lean into turns and on rails
var _crouch := 0.0                   # visual squash while charging an ollie
var _stars: Node3D                   # circling her head after a bail
var _board_tween: Tween              # the board flying off on its own in a bail
var _roll_sound: AudioStreamPlayer
var _grind_sound: AudioStreamPlayer
var hud                              # scripts/skate_hud.gd
var tricks := SkateTricks.new()
var _stick := Vector2.ZERO           # the stick (or WASD) this frame, not turned by the camera
var _manual := 0                     # rolling on two wheels: 1 a manual (on the tail), -1 a nose manual, 0 not
var _since_fwd_tap := 9.0            # seconds since forward, and back, were last pushed (for starting a manual)
var _since_back_tap := 9.0
var _grind_style := "fifty"
var _flip_press := 9.0               # seconds since Flip, and Grab, were pressed (together = the special)
var _grab_press := 9.0
var _was_fwd := false
var _was_back := false


func setup(player: Player) -> void:
	p = player
	tricks.ride = ride
	_roll_sound = _loop_player("skate_roll")
	_grind_sound = _loop_player("skate_grind")
	hud = CanvasLayer.new()
	hud.name = "SkateHUD"
	hud.set_script(load("res://scripts/skate_hud.gd"))
	add_child(hud)
	hud.watch(tricks)
	hud.visible = false


func start() -> void:
	# Hopping on: rolling, facing the way she was facing
	state = State.ROLL
	_yaw = p.visual.rotation.y
	_charge = -1.0
	balance = 0.0
	_grounded = p.is_on_floor()
	_ground_n = p.get_floor_normal() if _grounded else Vector3.UP
	# On the board she moves as a free body and works out the ground herself (_move): Godot's walking rules would
	# flatten her speed on every slope and stop her riding up anything steeper than a gentle hill.
	p.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	p.wall_min_slide_angle = 0.0
	hud.visible = true


func stop() -> void:
	# Stepping off: back to walking rules, upright
	if state == State.BAIL:
		_end_bail()
	tricks.bank()
	_manual = 0
	state = State.ROLL
	_rail = null
	p.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	p.wall_min_slide_angle = deg_to_rad(15.0)
	p.visual.basis = Basis(Vector3.UP, p.visual.rotation.y)
	p.visual.position = Vector3.ZERO
	p.tumble.scale = Vector3.ONE
	_roll_sound.stop()
	_grind_sound.stop()
	hud.visible = false


func can_step_off() -> bool:
	return state == State.ROLL and _charge < 0.0


func rail_in_reach() -> bool:
	return _find_rail() != null


func is_bailing() -> bool:
	return state == State.BAIL


func balancing() -> bool:
	# On a rail or in a manual: the balance meter is up
	return state == State.GRIND or (state == State.ROLL and _manual != 0)


# -----------------------------------------------------------------------------
# The physics step (called by the player instead of its own while riding)
# -----------------------------------------------------------------------------
func physics(delta: float) -> void:
	var input := Vector2.ZERO if p.input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_stick = input
	var dir := _camera_dir(input)
	_grind_buffer = 0.25 if Input.is_action_just_pressed("skate_grind") and not p.input_locked else _grind_buffer - delta
	_flip_press = 0.0 if Input.is_action_just_pressed("skate_flip") and not p.input_locked else _flip_press + delta
	_grab_press = 0.0 if Input.is_action_just_pressed("skate_grab") and not p.input_locked else _grab_press + delta
	_last_rail_timer -= delta
	if p._stun_timer > 0.0 and state != State.BAIL:
		bail()                                        # an enemy knocked her off the board
	match state:
		State.ROLL:
			_roll(dir, delta)
		State.AIR:
			_air(input, dir, delta)
		State.GRIND:
			_grind(input, delta)
		State.BAIL:
			_bailing(delta)
	RenderingServer.global_shader_parameter_set("nina_pos", p.global_position)   # plants lean away from her
	if p._spin_timer > 0.0 or absf(p.tumble.rotation.x) > 0.001:
		p._update_spin(delta)                         # a bail's tumble, or the special's somersault
	_pose(delta)
	_sounds()
	hud.update_skate(self)


func _camera_dir(input: Vector2) -> Vector3:
	# Steering is relative to the camera, like walking. The camera swings round behind her as she rolls, so it soon
	# feels like steering the board itself.
	var b := p.spring_arm.global_transform.basis
	var forward := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	return (right * input.x - forward * input.y).normalized()


func _facing() -> Vector3:
	return Vector3(sin(_yaw), 0, cos(_yaw))


# --- Rolling ------------------------------------------------------------------
func _roll(dir: Vector3, delta: float) -> void:
	if not _grounded:
		_leave_ground()
		_air(Vector2.ZERO, Vector3.ZERO, delta)
		return
	var n := _ground_n
	_normal = n
	var v := p.velocity
	v -= n * v.dot(n)                                  # roll along the ground, never into it
	var g := p.get_gravity()
	v += (g - n * g.dot(n)) * float(ride.slope) * delta   # slopes and ramps pull her down them
	var speed := v.length()
	var fwd := v / speed if speed > 0.3 else _plane(_facing(), n)
	tricks.update_ground(delta)
	_manual_input(speed, n, delta)
	if _manual != 0:
		if not _balance(-_stick.y, float(ride.manual_drift), float(ride.manual_control), delta):
			bail()
			return
		dir = _camera_dir(Vector2(_stick.x, 0.0))       # forward and back are for balancing now, not pushing
	if dir and _manual != 0:
		var side := _plane(dir, n)
		fwd = fwd.rotated(n, clampf(fwd.signed_angle_to(side, n), -float(ride.carve) * delta, float(ride.carve) * delta)).normalized()
		speed = move_toward(speed, 0.0, float(ride.coast) * delta)
	elif dir:
		var want := _plane(dir, n)
		var along := fwd.dot(want)
		if along < -0.5 and speed > 1.0:
			speed = move_toward(speed, 0.0, float(ride.brake) * delta)          # pulling back: brake
		else:
			# Carve toward where she's steering; standing still she can turn on the spot more quickly
			var rate := float(ride.carve) * (1.0 + 2.0 * (1.0 - clampf(speed / 3.0, 0.0, 1.0)))
			fwd = fwd.rotated(n, clampf(fwd.signed_angle_to(want, n), -rate * delta, rate * delta)).normalized()
			_lean = lerpf(_lean, clampf(fwd.signed_angle_to(want, n), -0.6, 0.6) * clampf(speed / 8.0, 0.0, 1.0), 0.15)
			if speed < float(ride.push_speed) and along > 0.0 and n.y > 0.9:
				speed = move_toward(speed, float(ride.push_speed), float(ride.push_accel) * maxf(along, 0.3) * delta)
	else:
		speed = move_toward(speed, 0.0, float(ride.coast) * delta)
		_lean = lerpf(_lean, 0.0, 0.1)
	v = fwd * minf(speed, float(ride.max_speed))
	if speed > 0.3:
		_yaw = atan2(fwd.x, fwd.z)
	if speed > 2.0:
		p.spring_arm.follow(atan2(-v.x, -v.z), delta)

	# Ollie: crouch while Jump is held, pop on letting go (out of a manual too, which keeps the combo going)
	if _ollie_input(delta):
		v += Vector3.UP * lerpf(float(ride.ollie_min), float(ride.ollie_max), _charge)
		_pop()
	elif _grind_buffer > 0.0 or Input.is_action_pressed("skate_grind"):
		if _try_grind():
			return
	_move(v, state == State.ROLL)
	if state == State.ROLL and not _grounded:
		_leave_ground()


func _move(v: Vector3, on_ground: bool) -> void:
	# Moves her, and works out whether she ended up on something to ride on. On the ground she's pressed lightly into
	# it, so she keeps touching it all the way up a ramp; where the ground drops away gently under her (the far side
	# of a bump, the start of a slope) she's pulled down onto it, but not where it ends (the top of a ramp).
	p.velocity = v - _ground_n * 0.8 if on_ground else v
	p.move_and_slide()
	var was := _grounded
	_grounded = false
	var best := -2.0
	for i in p.get_slide_collision_count():
		var n := p.get_slide_collision(i).get_normal()
		if n.y > FLOOR_MIN_Y and n.dot(_ground_n) > best:
			best = n.dot(_ground_n)
			_ground_n = n
			_grounded = true
	if not _grounded and was and on_ground and v.y <= 0.3:
		var hit := p.move_and_collide(-_ground_n * SNAP, true)
		if hit and hit.get_normal().y > FLOOR_MIN_Y:
			p.global_position += hit.get_travel()
			_ground_n = hit.get_normal()
			_grounded = true
	if not _grounded:
		p.velocity = v if on_ground else p.velocity     # not the press into the ground she just left
		_ground_n = Vector3.UP


func _manual_input(speed: float, n: Vector3, delta: float) -> void:
	# Forward then back quickly: a manual. Back then forward: a nose manual. Only rolling along on the flat.
	_since_fwd_tap += delta
	_since_back_tap += delta
	var fwd_now := _stick.y < -0.6
	var back_now := _stick.y > 0.6
	var fwd_new := fwd_now and not _was_fwd
	var back_new := back_now and not _was_back
	if _manual == 0 and speed > 1.5 and n.y > 0.9 and _charge < 0.0:
		if back_new and _since_fwd_tap < 0.35:
			_start_manual(1)
		elif fwd_new and _since_back_tap < 0.35:
			_start_manual(-1)
	if fwd_new:
		_since_fwd_tap = 0.0
	if back_new:
		_since_back_tap = 0.0
	_was_fwd = fwd_now
	_was_back = back_now


func _start_manual(kind: int) -> void:
	_manual = kind
	balance = rng.randf_range(-0.1, 0.1)
	_balance_vel = 0.0
	_grind_time = 0.0
	_since_fwd_tap = 9.0
	_since_back_tap = 9.0
	tricks.start_live(ride.tricks.manual if kind > 0 else ride.tricks.nose_manual, 50, 120.0)


func _end_manual() -> void:
	if _manual != 0:
		_manual = 0
		balance = 0.0
		tricks.end_live()


func _balance(push: float, drift: float, control: float, delta: float) -> bool:
	# The balance needle: it wanders, and wants to keep falling the way it leans, more and more the longer she
	# holds it. push (-1..1) shoves it back. False once it's gone off the end.
	_grind_time += delta
	var wobble := drift * (0.7 + _grind_time * 0.18)
	_balance_vel += (rng.randf_range(-1.0, 1.0) * 3.0 + balance * 2.2) * wobble * delta
	_balance_vel += push * control * delta
	_balance_vel *= exp(-1.5 * delta)
	balance += _balance_vel * delta
	tricks.update_live(delta)
	return absf(balance) < 1.0


func _ollie_input(delta: float) -> bool:
	# True on the frame she pops. Holding charges it.
	if p.input_locked:
		_charge = -1.0
		return false
	if Input.is_action_pressed("jump"):
		_charge = clampf(maxf(_charge, 0.0) + delta / float(ride.charge_time), 0.0, 1.0)
		return false
	return _charge >= 0.0


func _pop() -> void:
	_end_manual()
	tricks.keep_going()
	state = State.AIR
	_air_time = 0.0
	_air_spin = 0.0
	_vert = false
	_auto_turn = 0.0
	_coyote = 0.0
	_charge = -1.0
	_normal = Vector3.UP
	Audio.play("skate_pop", -2.0, 0.08)


func _leave_ground() -> void:
	# Rolled off an edge, or up and off a ramp. Off a steep ramp going up, it's a vert air: no flying off over the
	# top, she goes straight up and comes back down onto the same ramp, turning round on the way.
	_end_manual()
	tricks.keep_going()
	state = State.AIR
	_air_time = 0.0
	_air_spin = 0.0
	_auto_turn = 0.0
	_vert = false
	_coyote = 0.15
	var v := p.velocity
	var out := Vector3(_normal.x, 0, _normal.z)
	if _normal.y < 0.6 and v.y > 1.0 and out.length() > 0.1:
		out = out.normalized()
		v -= out * v.dot(out)                          # nothing carrying her over the lip
		v += out * 0.6                                 # a touch back toward the ramp, so she lands on it
		p.velocity = v
		_vert = true
		_auto_turn = PI
	_normal = Vector3.UP


# --- In the air ---------------------------------------------------------------
func _air(input: Vector2, dir: Vector3, delta: float) -> void:
	_air_time += delta
	var v := p.velocity
	var g := p.get_gravity()
	v += g * delta * (1.0 if v.y > 0.0 else float(ride.fall_gravity))
	if dir and not _vert:
		var h := Vector3(v.x, 0, v.z)
		var hs := h.length()
		h = (h + dir * float(ride.air_drift) * delta).limit_length(maxf(hs, 2.0))
		v.x = h.x
		v.z = h.z
	# Spinning: left and right turn her (the board turns with her)
	if input.x != 0.0 and not p.input_locked:
		var turn := -input.x * float(ride.spin_speed) * delta
		_yaw += turn
		_air_spin += turn
	_air_tricks()
	tricks.update_air(delta)
	# Vert: turn round by herself, spread over the time she'll be up there
	if _auto_turn > 0.0:
		var hang := maxf(2.0 * maxf(v.y, 0.5) / g.length(), 0.25)
		var step := minf(_auto_turn, PI / hang * delta * 1.3)
		_yaw += step
		_auto_turn -= step
	# Rolled off an edge a moment ago: an ollie still works
	_coyote -= delta
	if _coyote > 0.0 and _ollie_input(delta):
		v.y = maxf(v.y, 0.0) + lerpf(float(ride.ollie_min), float(ride.ollie_max), _charge)
		_pop()
	elif _coyote <= 0.0:
		_charge = -1.0
	if (_grind_buffer > 0.0 or Input.is_action_pressed("skate_grind")) and _try_grind():
		return
	_move(v, false)
	if _grounded and _air_time > 0.05:
		_land()


func _air_tricks() -> void:
	if p.input_locked:
		return
	var dir := SkateTricks.direction_name(_stick)
	# Flip and Grab pressed together (near enough) with a full meter: the special
	var both := _flip_press < 0.15 and _grab_press < 0.15
	if both and tricks.special >= 1.0 and (not tricks.flipping() or float(tricks.flip.time) < 0.16):
		tricks.flip = {}
		tricks.grab = {}
		if tricks.start_special():
			_flip_press = 9.0
			_grab_press = 9.0
			p._spin(float(ride.tricks.special[3]), 0.3, false)
			Fx.burst(get_tree().current_scene, p.global_position, Color(1.0, 0.6, 0.95), 18, 0.07, 4.0, 0.0, 0.8)
			hud.shout(String(ride.tricks.special[0]) + "!", Color(1.0, 0.75, 0.98))
			Audio.play("level_up", -6.0, 0.0)
			return
	if _flip_press == 0.0:
		tricks.start_flip(dir)
	if Input.is_action_pressed("skate_grab"):
		if not tricks.flipping():
			tricks.start_grab(dir)
	else:
		tricks.release_grab()


func _land() -> void:
	var n := _ground_n
	_normal = n
	var v := p.velocity
	v -= n * v.dot(n)
	p.velocity = v
	var h := Vector3(v.x, 0, v.z)
	var facing := _facing()
	var clean := not tricks.flipping()               # still flipping the board: she lands on it wrong
	if h.length() > 1.0:
		var off := absf(facing.signed_angle_to(h.normalized(), Vector3.UP))
		var window := float(ride.land_window)
		if off > PI - window:
			_yaw += PI                                 # landed backwards: ride away fakie (turned round, for now)
		elif off > window:
			clean = false
	state = State.ROLL
	_vert = false
	_auto_turn = 0.0
	if clean:
		Audio.play("skate_land", linear_to_db(clampf(absf(v.y) / 8.0 + 0.4, 0.4, 1.0)), 0.08)
		tricks.land(roundi(absf(_air_spin) / PI))
		landed.emit(true)
	else:
		landed.emit(false)
		bail()


# --- Grinding -----------------------------------------------------------------
func _find_rail() -> GrindRail:
	var feet := p.global_position - Vector3.UP * FEET
	var best: GrindRail = null
	var best_d := INF
	var low := -1.0 if state == State.AIR else -0.25       # rail below her feet: falling onto it, or just a kerb
	var high := 0.6 if state == State.AIR else 1.3         # rail above her feet: hopping up onto it from the ground
	for node in get_tree().get_nodes_in_group("grind"):
		var r := node as GrindRail
		if r == null or (r == _last_rail and _last_rail_timer > 0.0):
			continue
		var o := r.closest_offset(feet)
		var d := r.point_at(o) - feet
		var side := Vector2(d.x, d.z).length()
		if side > float(ride.grind_reach) or d.y < low or d.y > high:
			continue
		if side < best_d:
			best_d = side
			best = r
	return best


func _try_grind() -> bool:
	var r := _find_rail()
	if r == null:
		return false
	var feet := p.global_position - Vector3.UP * FEET
	_rail = r
	_rail_offset = r.closest_offset(feet)
	var t := r.tangent_at(_rail_offset)
	var v := p.velocity
	var along := v.dot(t)
	if absf(along) < 0.5:
		along = _facing().dot(t)                         # coming at it square on: go the way she's facing
	_rail_dir = 1.0 if along >= 0.0 else -1.0
	_rail_speed = maxf(Vector3(v.x, 0, v.z).length() * 0.85, float(ride.grind_min_speed))
	_rail_snap = 0.0
	_snap_from = p.global_position
	balance = rng.randf_range(-0.15, 0.15)
	_balance_vel = 0.0
	_grind_time = 0.0
	_grind_buffer = 0.0
	_charge = -1.0
	_end_manual()
	var g: Array = ride.tricks.grinds.get(SkateTricks.direction_name(_stick), ride.tricks.grinds[""])
	_grind_style = g[1]
	tricks.start_live(g[0], 50, 150.0)
	state = State.GRIND
	Audio.play("skate_land", -4.0, 0.1)
	return true


func _grind(input: Vector2, delta: float) -> void:
	var t := _rail.tangent_at(_rail_offset) * _rail_dir
	_rail_speed += p.get_gravity().dot(t) * 0.8 * delta     # down rails speed her up, up rails slow her
	_rail_speed = maxf(_rail_speed - float(ride.grind_friction) * delta, 2.0)
	_rail_offset += _rail_speed * _rail_dir * delta
	_yaw = atan2(t.x, t.z) + (PI / 2 if _grind_style == "slide" else 0.0)   # slides: the board across the rail
	p.velocity = t * _rail_speed
	var off_end := _rail_offset < 0.0 or _rail_offset > _rail.length()
	var target := _rail.point_at(_rail_offset) + Vector3.UP * (FEET + 0.04)
	_rail_snap = minf(_rail_snap + delta / 0.08, 1.0)
	p.global_position = _snap_from.lerp(target, _rail_snap) if _rail_snap < 1.0 else target
	p.spring_arm.follow(atan2(-t.x, -t.z), delta)

	# Balance: left and right keep the needle in the middle
	var ok := _balance(input.x, float(ride.balance_drift), float(ride.balance_control), delta)
	_lean = balance * 0.5
	if not ok:
		var side := p.visual.global_transform.basis.x * signf(balance)
		_leave_rail(t * _rail_speed * 0.5 + Vector3.UP * 1.5 + side * 2.0)
		bail()
		return
	# Jump pops her off (a tap is enough here), and the end of the rail sends her flying off it
	if Input.is_action_just_pressed("jump") and not p.input_locked:
		_leave_rail(t * _rail_speed + Vector3.UP * float(ride.ollie_min))
		_pop()
	elif off_end:
		_leave_rail(t * _rail_speed + Vector3.UP * 1.2)
		_pop()
	else:
		_spark_timer -= delta
		if _spark_timer <= 0.0 and _rail.kind == "rail":
			_spark_timer = 0.05
			Fx.burst(get_tree().current_scene, p.global_position - Vector3.UP * FEET, Color(1.0, 0.85, 0.4), 3, 0.03,
				3.0, -9.0, 0.35, 60.0)


func _leave_rail(v: Vector3) -> void:
	tricks.end_live()
	_last_rail = _rail
	_last_rail_timer = 0.35
	_rail = null
	p.velocity = v
	balance = 0.0


# --- Bailing ------------------------------------------------------------------
func bail() -> void:
	# A comedy wipeout: she tumbles, the board shoots off on its own, stars go round her head. No damage.
	if state == State.GRIND:
		_leave_rail(p.velocity)
	_manual = 0
	tricks.lose()
	state = State.BAIL
	_bail_timer = float(ride.bail_time)
	_charge = -1.0
	_auto_turn = 0.0
	p._spin(0.55, 0.4, _grounded)
	Audio.play("skate_bail", -1.0, 0.1)
	hud.shout(BAIL_LINES[rng.randi() % BAIL_LINES.size()], Color(1.0, 0.55, 0.6))
	var board := p.board
	var from := board.global_transform
	board.top_level = true
	board.global_transform = from
	var fly := _facing() * 2.5 + Vector3.UP * 0.6
	_board_tween = board.create_tween()
	_board_tween.set_parallel()
	_board_tween.tween_property(board, "global_position", from.origin + fly, 0.5).set_trans(Tween.TRANS_QUAD)
	_board_tween.tween_property(board, "rotation:z", board.rotation.z + TAU * 1.5, 0.5)
	_add_stars()
	bailed.emit()


func _bailing(delta: float) -> void:
	_bail_timer -= delta
	var v := p.velocity
	if _grounded:
		v -= _ground_n * v.dot(_ground_n)
		v = v.move_toward(Vector3.ZERO, 9.0 * delta)        # skidding to a stop on her bottom
		v += (p.get_gravity() - _ground_n * p.get_gravity().dot(_ground_n)) * delta
		_normal = _ground_n
	else:
		v += p.get_gravity() * delta
	_move(v, _grounded)
	if _stars:
		_stars.rotate_y(delta * 6.0)
	if _bail_timer <= 0.0 and _grounded:
		_end_bail()
		state = State.ROLL
		p.velocity = Vector3.ZERO


func _end_bail() -> void:
	# The board scoots back under her feet
	var board := p.board
	if _board_tween:
		_board_tween.kill()
		_board_tween = null
	board.top_level = false
	board.transform = Transform3D(Basis.IDENTITY, Vector3(0, -FEET, 0))
	if _stars:
		_stars.queue_free()
		_stars = null
	p.tumble.rotation.x = 0.0
	p.tumble.scale = Vector3.ONE
	p.tumble.position.y = 0.0
	p._spin_timer = 0.0


func _add_stars() -> void:
	if _stars:
		_stars.queue_free()
	_stars = Node3D.new()
	_stars.name = "BailStars"
	_stars.position = Vector3(0, 1.0, 0)
	p.add_child(_stars)
	for k in 3:
		var s := Label3D.new()
		s.text = "★"
		s.font_size = 64
		s.pixel_size = 0.006
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.modulate = Color(1.0, 0.9, 0.35)
		s.outline_size = 8
		s.position = Vector3(cos(k * TAU / 3) * 0.4, 0, sin(k * TAU / 3) * 0.4)
		_stars.add_child(s)


# -----------------------------------------------------------------------------
# How she looks: the whole body leans with the ground (up a quarter pipe she's nearly sideways), into turns and
# along the balance on a rail, and squashes down while charging an ollie.
# -----------------------------------------------------------------------------
func _pose(delta: float) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	var up := _normal if state == State.ROLL or state == State.BAIL else Vector3.UP
	var cur := p.visual.basis.orthonormalized()
	var cur_up := cur.y
	var new_up := cur_up.slerp(up, k).normalized() if cur_up.dot(up) < 0.9999 else up
	var tilt := Basis(Quaternion(Vector3.UP, new_up)) if new_up.dot(Vector3.UP) < 0.9999 else Basis.IDENTITY
	var yaw_now := _yaw_of(cur)
	var yaw := lerp_angle(yaw_now, _yaw, 1.0 - exp(-(30.0 if state == State.AIR else 16.0) * delta))
	if state == State.BAIL:
		yaw = yaw_now
	p.visual.basis = tilt * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -_lean * 0.6)
	# Her feet stay where the capsule touches a steep ramp (its side, not the bottom of its middle)
	p.visual.position = p.visual.position.lerp((new_up - Vector3.UP) * (FEET - SIDE_RADIUS), k)
	var grabbing := 0.3 if not tricks.grab.is_empty() else 0.0
	_crouch = lerpf(_crouch, maxf(0.25 * maxf(_charge, 0.0), grabbing) + (0.1 if state == State.GRIND else 0.0), k)
	if state != State.BAIL and p._spin_timer <= 0.0:
		p.tumble.scale = Vector3(1.0 + _crouch * 0.3, 1.0 - _crouch, 1.0 + _crouch * 0.3)
		p.tumble.position.y = -FEET * _crouch
	if state != State.BAIL:
		_board_pose()
	if p.anim:
		var target := "fall" if state == State.BAIL else "skate"
		if p.anim.assigned_animation != target:
			p.anim.play(target, 0.15)
		p.anim.speed_scale = 1.0


func _board_pose() -> void:
	# The board flips, spins and tilts for tricks, and lifts toward her hand for a grab
	var b := Basis.IDENTITY
	var lift := 0.0
	if tricks.flipping():
		var f := clampf(float(tricks.flip.time) / float(tricks.flip.duration), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		match String(tricks.flip.style):
			"kick":
				b = Basis(Vector3.BACK, TAU * f)
			"heel":
				b = Basis(Vector3.BACK, -TAU * f)
			"impossible":
				b = Basis(Vector3.RIGHT, TAU * f)
			"shove":
				b = Basis(Vector3.UP, PI * f)
			"twirl":
				b = Basis(Vector3.UP, TAU * 2.0 * f) * Basis(Vector3.BACK, TAU * f)
		lift = sin(PI * f) * 0.35
	elif not tricks.grab.is_empty():
		match String(tricks.grab.style):
			"indy":
				b = Basis(Vector3.BACK, 0.4)
			"melon":
				b = Basis(Vector3.BACK, -0.4)
			"nose":
				b = Basis(Vector3.RIGHT, -0.45)
			"tail":
				b = Basis(Vector3.RIGHT, 0.45)
		lift = 0.28
	elif state == State.GRIND:
		match _grind_style:
			"nose":
				b = Basis(Vector3.RIGHT, 0.22)
			"tail":
				b = Basis(Vector3.RIGHT, -0.22)
	elif _manual != 0:
		b = Basis(Vector3.RIGHT, -0.3 * _manual)
		lift = 0.08
	p.board.transform = Transform3D(b, Vector3(0, -FEET + lift, 0))


func _yaw_of(b: Basis) -> float:
	# The heading of a (possibly tilted) model basis: where its +Z points, flattened
	var z := b.z
	z.y = 0.0
	return atan2(z.x, z.z) if z.length() > 0.01 else _yaw


func _plane(d: Vector3, n: Vector3) -> Vector3:
	var out := d - n * d.dot(n)
	return out.normalized() if out.length() > 0.001 else _facing()


# -----------------------------------------------------------------------------
# Sounds: wheels rumbling with speed, the rail grinding
# -----------------------------------------------------------------------------
func _loop_player(name: String) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.bus = "SFX"
	var path := "res://audio/sfx/%s.wav" % name
	if ResourceLoader.exists(path):
		var s := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2           # 16-bit mono
		a.stream = s
	add_child(a)
	return a


func _sounds() -> void:
	var speed := p.velocity.length()
	var rolling := state == State.ROLL and speed > 0.8
	if rolling and not _roll_sound.playing and _roll_sound.stream:
		_roll_sound.play()
	elif not rolling and _roll_sound.playing:
		_roll_sound.stop()
	_roll_sound.volume_db = linear_to_db(clampf(speed / 14.0, 0.05, 0.6))
	_roll_sound.pitch_scale = clampf(0.7 + speed / 20.0, 0.7, 1.5)
	var grinding := state == State.GRIND
	if grinding and not _grind_sound.playing and _grind_sound.stream:
		_grind_sound.play()
	elif not grinding and _grind_sound.playing:
		_grind_sound.stop()
	_grind_sound.pitch_scale = clampf(0.8 + _rail_speed / 25.0, 0.8, 1.4)
	_grind_sound.volume_db = -4.0
