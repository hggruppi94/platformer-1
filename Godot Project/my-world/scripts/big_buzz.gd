extends CharacterBody3D

# Big Buzz: the Fizzlers' boss, a great crackling storm-ball of static with one big eye and a crown of little lightning
# bolts (every enemy gets a bigger boss version: Hayden, Nov 1, 2026). He only lives in the Star Arena
# (scripts/arena_level.gd), one of its three bosses you meet nowhere else.
#
# He floats high, out of reach, drifting after you, and while he's up there bubbles just fizzle off his static. Every
# few seconds he dives down and slams the ground: a big ring of static rolls out (scripts/shock_ring.gd: jump it).
# Then he's FIZZLED OUT: he sits on the ground for a moment, dizzy, his static gone flat and his eye spinning. That's
# the time to pop him: bubbles and stomps count, up to MAX_PER_DAZE each time, then he blinks off somewhere else in a
# fizz and floats up again. At 3 and 6 hits he lets off three Fizzlers (scripts/fizzler.gd). Past half he's cross: he
# dives more often and his slam sends two rings. HITS hits and he bursts into a shower of sparks.
# Kid-safe: a bump, never more.
#
# Built in code: BIG_BUZZ.new(), with `centre` and `reach` set to the arena floor he keeps over.

const FIZZLER := preload("res://scripts/fizzler.gd")

const HITS := 15
const HELP_AT := [3, 9]
const MAX_PER_DAZE := 3
const SIZE := 3.0
const HIGH := 4.2                             # how high he floats (out of stomp reach)
const DRIFT := 2.6                            # m/s after you (you run at 5)
const UP_TIME := 4.4                          # seconds up before a dive (3.4 when he's cross)
const DIVE_TIME := 0.55
const DAZE_TIME := 3.6
const RING_REACH := 10.0
const SINK := 1.6                            # fizzled out, he squats this far down (so his top's in jumping reach)
const BAR_COLOUR := Color(0.45, 0.95, 1.0)

enum State { UP, DIVE, DAZED, RISE }

signal popped(who: Node3D)

var world: Node                               # the arena, told when he's popped
var centre := Vector3.ZERO                    # the floor he keeps over
var reach := 20.0
var state := State.UP
var hits := 0
var defeated := false
var cross := false
var visual: Node3D
var player: CharacterBody3D
var _t := 0.0
var _state_t := 0.0
var _daze_hits := 0
var _helped := 0
var _ground_y := 0.0
var _bar: BossBar
var _hitbox: Area3D
var _shell_mat: StandardMaterial3D
var _eye: Node3D
var _crown: Node3D
var _told_fizzle := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	Arsenal.supply_boss(self)                       # ammo crates round the fight (scripts/arsenal.gd)
	_ground_y = global_position.y
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0                         # he floats where he likes (he keeps over the floor himself)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.42 * SIZE
	cs.shape = sp
	cs.position.y = 1.0 * SIZE
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hsp := SphereShape3D.new()
	hsp.radius = 0.55 * SIZE
	hcs.shape = hsp
	hcs.position.y = 1.0 * SIZE
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = FIZZLER.model(SIZE)
	add_child(visual)
	_shell_mat = visual.get_meta("shell")
	_eye = visual.get_node("Eye")
	_crown_of_bolts()
	_bar = BossBar.make(self, "Big Buzz", BAR_COLOUR, 1.0 * SIZE * 2.0 + 0.9, 2.2)
	global_position.y = _ground_y + HIGH - 1.0
	_state_t = UP_TIME * 0.6


func _crown_of_bolts() -> void:
	# A crown of zig-zag lightning bolts round the top of his head
	_crown = Node3D.new()
	_crown.name = "Crown"
	_crown.position.y = 1.0 * SIZE + 0.42 * SIZE
	visual.add_child(_crown)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.3)
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 6:
		var a := k * TAU / 6.0
		var bolt := Node3D.new()
		bolt.position = Vector3(cos(a), 0, sin(a)) * 0.6
		bolt.rotation.y = -a
		_crown.add_child(bolt)
		for j in 3:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.09, 0.32, 0.09)
			bar.mesh = bm
			bar.material_override = m
			bar.position = Vector3(0.07 * (1 if j % 2 == 0 else -1), 0.14 + j * 0.24, 0)
			bar.rotation.z = 0.55 * (1 if j % 2 == 0 else -1)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(bar)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	_state_t -= delta
	_told_fizzle = maxf(_told_fizzle - delta, 0.0)
	var want_y := _ground_y + HIGH - 1.0
	var h := Vector3.ZERO
	match state:
		State.UP:
			if player:
				var to := player.global_position - global_position
				to.y = 0
				if to.length() > 1.0:
					h = to.normalized() * DRIFT * (1.2 if cross else 1.0) * Arsenal.slow(self)
			if _state_t <= 0.0:
				state = State.DIVE
				_state_t = DIVE_TIME
				Juice.blip("whoosh", 0.6, -6.0)
		State.DIVE:
			want_y = _ground_y - SINK
			if _state_t <= 0.0 or global_position.y <= _ground_y - SINK + 0.15:
				_slam()
		State.DAZED:
			want_y = _ground_y - SINK
			if _state_t <= 0.0 or _daze_hits >= MAX_PER_DAZE:
				_blink_away()
		State.RISE:
			if _state_t <= 0.0:
				state = State.UP
				_state_t = (3.4 if cross else UP_TIME) * randf_range(0.85, 1.15)
	# Keep over the arena floor
	var off := global_position - centre
	off.y = 0
	if off.length() > reach:
		h += -off.normalized() * 3.0
	velocity.x = move_toward(velocity.x, h.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, h.z, 20.0 * delta)
	var bob := 0.0 if state == State.DAZED else sin(_t * 2.2) * 0.25 * (0.3 if Settings.reduce_motion else 1.0)
	var k := 9.0 if state == State.DIVE else 3.0
	velocity.y = (want_y + bob - global_position.y) * k
	move_and_slide()
	_look(delta)
	_bar.fill = 1.0 - float(hits) / HITS
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _look(delta: float) -> void:
	# Fizzing bright while he's up; flat and grey-ish while fizzled out, his eye spinning round
	var dazed := state == State.DAZED
	if player and not dazed:
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	var jitter := 0.0 if (Settings.reduce_motion or dazed) else 0.04
	visual.position = Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), 0)
	var bolts := visual.get_node("Bolts")
	var spin := _t * (1.5 if dazed else 5.0)
	var i := 0
	for b in bolts.get_children():
		var a := spin + i * TAU / bolts.get_child_count()
		(b as Node3D).position = Vector3(cos(a), sin(a * 1.7 + i) * 0.4, sin(a)) * 0.52 * SIZE
		(b as Node3D).visible = not dazed and (Settings.reduce_flashing or fmod(_t * 11.0 + i * 0.37, 1.0) > 0.25)
		i += 1
	if _shell_mat:
		var flick := 0.5 + 0.5 * sin(_t * 29.0) if not Settings.reduce_flashing else 0.5
		_shell_mat.emission_energy_multiplier = 0.25 if dazed else (1.2 + 0.8 * flick) * (1.4 if cross else 1.0)
		_shell_mat.albedo_color = Color(0.6, 0.6, 0.75, 0.25) if dazed \
			else Color(FIZZLER.STATIC.lerp(FIZZLER.GLITCH, 0.35 if cross else 0.0), 0.35)
	_crown.visible = not dazed
	_crown.rotation.y += delta * 1.5
	_eye.rotation.z = (_t * 8.0) if dazed else 0.0
	(visual.get_node("Pupil") as Node3D).position = Vector3(cos(_t * 8.0) * 0.08 * SIZE, 1.06 * SIZE + sin(_t * 8.0) * 0.06 * SIZE,
		0.44 * SIZE) if dazed else Vector3(0, 1.06 * SIZE, 0.44 * SIZE)


func _slam() -> void:
	# Down he comes: a ring of static (jump it), then he's fizzled out for a moment
	state = State.DAZED
	_state_t = DAZE_TIME
	_daze_hits = 0
	velocity = Vector3.ZERO
	var at := Vector3(global_position.x, _ground_y, global_position.z)
	ShockRing.spawn(get_parent(), at, RING_REACH, FIZZLER.STATIC, 2, 0.9)
	if cross:
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if not defeated and is_inside_tree():
				ShockRing.spawn(get_parent(), at, RING_REACH * 1.5, FIZZLER.GLITCH, 2, 1.0))
	Fx.burst(get_parent(), at + Vector3(0, 0.5, 0), FIZZLER.STATIC, 18, 0.07, 4.0, 0.5, 0.6)
	Juice.shake(0.4)
	Juice.rumble(0.4, 0.25, 0.5)
	Juice.blip("thud", 0.6, -2.0)
	if hits == 0 and _told_fizzle <= 0.0:
		Game.message("Big Buzz fizzled out! Pop him now, while he's dizzy!")
		_told_fizzle = 20.0


func _blink_away() -> void:
	# Fizz! He blinks off to somewhere else over the floor and floats back up
	Fx.burst(get_parent(), global_position + Vector3(0, SIZE, 0), FIZZLER.GLITCH, 14, 0.07, 3.0, 0.0, 0.5)
	var a := randf() * TAU
	var r := randf_range(0.3, 0.75) * reach
	var to := centre + Vector3(cos(a), 0, sin(a)) * r
	if player and _flat(to - player.global_position) < 6.0:
		to = centre - (player.global_position - centre).normalized() * r
		to.y = centre.y
	global_position = Vector3(to.x, global_position.y, to.z)
	Fx.burst(get_parent(), global_position + Vector3(0, SIZE, 0), FIZZLER.GLITCH, 14, 0.07, 3.0, 0.0, 0.5)
	Juice.blip("whoosh", 1.8, -6.0)
	state = State.RISE
	_state_t = 1.0


func _touch_player() -> void:
	if state == State.DAZED:
		var feet := player.global_position.y - 0.8
		if player.velocity.y < 0.5 and feet > global_position.y + 0.65 * SIZE + 0.6:
			player.call("bounce", 9.0)
			hurt(1)
			return
		if player.call("is_rolling"):
			hurt(1)
			return
		return                                                  # fizzled out: he can't bump you
	if not player.call("is_invulnerable"):
		player.call("hurt", 2, global_position)


func shot(power: int, _point: Vector3, _dir: Vector3) -> String:
	if defeated:
		return "miss"
	if state != State.DAZED:
		Fx.burst(get_parent(), _point, FIZZLER.STATIC, 6, 0.05, 2.0, 0.0, 0.3)
		if _told_fizzle <= 0.0:
			Game.message("The bubble fizzled off his static! Wait till he slams down and fizzles out.")
			_told_fizzle = 8.0
		return "miss"
	hurt(mini(power, MAX_PER_DAZE - _daze_hits))
	return "hit"


func hurt(n: int) -> void:
	if defeated or n <= 0:
		return
	hits += n
	_daze_hits += n
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Fx.burst(get_parent(), global_position + Vector3(0, SIZE, 0), Color(1.0, 0.95, 0.5), 10, 0.08, 3.0, 0.5, 0.5)
	Juice.blip("pop", 0.7, -4.0)
	if hits >= HITS:
		_burst()
		return
	var left := HITS - hits
	Game.message("Bzzt! Big Buzz crackles! %d more to pop him." % left if left > 1 else "One more and Big Buzz pops!")
	if not cross and hits * 2 >= HITS:
		cross = true
		Game.message("Big Buzz is cross! He's diving faster, and his slams send two rings!")
	while _helped < HELP_AT.size() and hits >= int(HELP_AT[_helped]):
		_helped += 1
		_let_off_fizzlers(3)


func _let_off_fizzlers(n: int) -> void:
	for k in n:
		var f := FIZZLER.new() as CharacterBody3D
		f.name = "Buzz Fizzler"
		f.set("respawns", false)
		f.set("sight_range", 30.0)
		f.set("leash_range", 60.0)
		var a := k * TAU / n + randf()
		var where := Vector3(global_position.x, _ground_y, global_position.z) + Vector3(cos(a), 0, sin(a)) * 3.0
		var parent := get_parent() as Node3D
		f.position = parent.to_local(where) if parent else where
		get_parent().add_child(f)
		Fx.burst(get_parent(), where + Vector3(0, 1, 0), FIZZLER.STATIC, 8, 0.05, 2.0, 0.0, 0.3)
	Game.message("Big Buzz lets off a crackle of Fizzlers!")


func _burst() -> void:
	defeated = true
	velocity = Vector3.ZERO
	_bar.visible = false
	_hitbox.set_deferred("monitoring", false)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var at := global_position + Vector3(0, SIZE, 0)
	Fx.burst(get_parent(), at, FIZZLER.STATIC, 30, 0.1, 5.0, 0.0, 1.0)
	Fx.burst(get_parent(), at, FIZZLER.GLITCH, 20, 0.08, 4.0, 0.0, 0.9)
	Fx.burst(get_parent(), at, Color(1.0, 0.9, 0.45), 16, 0.08, 3.5, -1.0, 0.8)
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	Juice.blip("sparkle", 1.0, -2.0)
	Game.add_xp(50)
	Game.message("You popped Big Buzz! Bzzzzzip... and the air goes all calm and quiet.")
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.8, 0.05, 1.8), 0.25)
	tw.tween_callback(func() -> void: visual.visible = false)
	popped.emit(self)
	if world and world.has_method("boss_popped"):
		world.call("boss_popped", self)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
