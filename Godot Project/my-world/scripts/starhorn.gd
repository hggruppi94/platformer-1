extends CharacterBody3D

# The Starhorn: the one big optional boss, asleep on the summit at the very end of the Skyreach Trail, the longest
# trail in the game (scripts/skyreach_trail.gd; the "feels bigger" plan's slice 4, Hayden: "Go ahead", 15 Nov 2026).
# A giant stag of mountain stone with antlers of glowing crystal full of stars. Nothing in the game mentions it until
# you're on the summit.
#
# Before this was written we read how open-source boss fights are put together (Hayden's rule: look first, then
# build), and took the two ideas that fit a kids' game:
#   - CodingQuests/godot-enemy-ai (MIT): one small state machine, IDLE -> TELEGRAPH -> ATTACK -> RECOVERY, with every
#     attack read from a mark on the ground first. That's our WARN -> ACT -> DAZED loop, with the shared boss tells
#     (scripts/boss_tell.gd), the same as the guardians (scripts/guardian.gd).
#   - euuuuuuan/cairnfall-public (Apache 2.0): bosses in PHASES picked by how much health is left, with a one-way
#     latch (a phase never goes back), a short beat between phases where the boss can't be hit and opens the new phase
#     with a big move, a "burst can't skip a phase" rule, and things in the arena you break to knock the boss down.
#     That's PHASES, _turn() and the Star Shards below.
#
# The fight, in three phases (HITS bubbles, stomps or rolls to calm it, at most MAX_PER_DAZE in a row):
#   1. Stomp (a ring: jump it) and charge (arrows: step aside). After each it's puffed out for a moment: pop it then.
#   2. It rears up and roars (a big ring), and its antlers shine a shield round it. Three Star Shards glow on pillars
#      round the summit: break them (a bubble, or jump into one) and it's knocked over for a long time. Falling stars
#      (a shadow: move off it) join in.
#   3. It roars again and gets quicker, and adds its big breath (arrows pointing in: jump free).
# Walk back down the trail and it settles back to sleep, all its puff back, no harm done. Kid-safe: a bump, never more.

const TELL := preload("res://scripts/boss_tell.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")

const TITLE := "The Starhorn"
const COLOUR := Color(0.55, 0.85, 1.0)
const HEIGHT := 7.0
const HITS := 18
const MAX_PER_DAZE := 3
const STAGGER_HITS := 4
# health left (1 is full) at which each phase ends, its moves, and how much quicker it is
const PHASES := [
	{"until": 2.0 / 3.0, "moves": ["jump", "dash"], "quick": 1.0, "daze": 3.0},
	{"until": 1.0 / 3.0, "moves": ["drop", "jump", "dash"], "quick": 1.15, "daze": 3.0, "shards": true},
	{"until": 0.0, "moves": ["pull", "dash", "drop", "jump"], "quick": 1.3, "daze": 2.4},
]
const WAKE := 16.0
const LEASH := 34.0
const ROAM := 14.0
const IDLE_TIME := 1.5
const TURN_TIME := 2.6                 # the beat between phases: it can't be hit, rears up and roars
const STAGGER_TIME := 6.0
const RING_REACH := 11.0
const ROAR_REACH := 16.0
const CHARGE_LEN := 22.0
const CHARGE_SPEED := 17.0
const DROP_R := 2.8
const PULL_REACH := 14.0
const PULL_TIME := 1.8
const PULL_SPEED := 3.8
const SHARD_R := 18.0                  # how far from the middle the shard pillars stand
const SHARD_TOUCH := 1.6
const ARENA_EDGE := 22.0                # a charge stops before the summit's edge (it floats, so walls don't stop it)

enum State { SLEEP, IDLE, WARN, ACT, DAZED, TURN, STAGGER, CALMED }

var home := Vector3.ZERO
var state := State.SLEEP
var phase := 0
var hits := 0
var defeated := false
var visual: Node3D
var player: CharacterBody3D
var shards: Array[Node3D] = []         # the three Star Shards (on the summit, not in the boss)
var shield_on := false
var _t := 0.0
var _state_t := 0.0
var _move_i := 0
var _move := ""
var _daze_hits := 0
var _dir := Vector3.FORWARD
var _targets: Array[Vector3] = []
var _bar: BossBar
var _hitbox: Area3D
var _told := 0.0
var _parts := {}
var _shield: MeshInstance3D


func flag() -> String:
	return "starhorn_calmed"


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0                         # it keeps to the summit's height
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 2.0
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 2.4
	hcap.height = HEIGHT + 0.4
	hcs.shape = hcap
	hcs.position.y = HEIGHT * 0.5
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_look(visual)
	_bar = BossBar.make(self, TITLE, COLOUR, HEIGHT + 1.6, 2.6)
	_bar.visible = false
	_sleep_pose(true)


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func quick() -> float:
	return float(PHASES[phase].quick)


func phase_for(n: int) -> int:
	# Which phase this many hits puts it in (the one-way latch keeps it from going back)
	var left := 1.0 - float(n) / HITS
	for i in PHASES.size():
		if left > float(PHASES[i].until) + 0.0001:
			return i
	return PHASES.size() - 1


func phase_cap() -> int:
	# The most hits this phase can take: a big burst of bubbles never skips a phase (it stops at the next one's edge)
	return int(round((1.0 - float(PHASES[phase].until)) * HITS))


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	if player == null:
		return
	_t += delta
	_state_t -= delta
	_told = maxf(_told - delta, 0.0)
	var from_home := _flat(player.global_position - home)
	if state == State.SLEEP:
		if from_home < WAKE and not Dialogue.is_active():
			_wake()
		_animate(delta)
		return
	if from_home > LEASH:
		_calm_down()
		return
	_check_shards()
	var h := Vector3.ZERO
	match state:
		State.IDLE:
			var to := player.global_position - global_position
			to.y = 0
			if to.length() > 6.0:
				h = to.normalized() * 2.6 * quick() * Arsenal.slow(self)
			if _state_t <= 0.0:
				_start_move()
		State.WARN:
			if _move == "dash":
				_face(_dir, delta)
			if _state_t <= 0.0:
				_do_move()
		State.ACT:
			match _move:
				"dash":
					h = _dir * CHARGE_SPEED * quick()
					var next := global_position + h * delta - home
					if _flat(next) > ARENA_EDGE and _flat(next) > _flat(global_position - home):
						h = Vector3.ZERO
						_state_t = 0.0
				"pull":
					_pull_step(delta)
			if _state_t <= 0.0:
				_daze()
		State.DAZED, State.STAGGER:
			if _state_t <= 0.0 or (state == State.DAZED and _daze_hits >= MAX_PER_DAZE) \
					or (state == State.STAGGER and _daze_hits >= STAGGER_HITS):
				_get_up()
		State.TURN:
			if _state_t <= 0.0:
				_turn_done()
	var off := global_position - home
	off.y = 0
	if off.length() > ROAM and state != State.ACT:
		h += -off.normalized() * 4.0
	velocity.x = h.x if state == State.ACT else move_toward(velocity.x, h.x, 14.0 * delta)
	velocity.z = h.z if state == State.ACT else move_toward(velocity.z, h.z, 14.0 * delta)
	velocity.y = (home.y - global_position.y) * 6.0
	move_and_slide()
	if state == State.IDLE or state == State.DAZED:
		_face(player.global_position - global_position, delta)
	_animate(delta)
	_bar.fill = 1.0 - float(hits) / HITS
	if _hitbox.overlaps_body(player):
		_touch_player()


func _face(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-4.0 * delta))


func _wake() -> void:
	state = State.IDLE
	_state_t = IDLE_TIME
	_bar.visible = true
	_sleep_pose(false)
	Juice.blip("whoosh", 0.5, -3.0)
	Juice.shake(0.35)
	Juice.rumble(0.4, 0.3)
	Game.message("%s wakes! Walk back down to let it sleep." % TITLE)


func _calm_down() -> void:
	# You walked back down the trail: it settles back to sleep, all its puff back, no harm done
	state = State.SLEEP
	hits = 0
	phase = 0
	_bar.visible = false
	_bar.fill = 1.0
	velocity = Vector3.ZERO
	global_position = home
	_set_shield(false)
	_light_shards(false)
	for t in get_tree().get_nodes_in_group("boss_tells"):
		if is_instance_valid(t) and t.get("follow") == self:
			t.queue_free()
	_sleep_pose(true)
	Game.message("%s settles back to sleep." % TITLE)


# -----------------------------------------------------------------------------
# Moves: each warned with the shared tells, and always the same shape for the same thing
# -----------------------------------------------------------------------------
func _start_move() -> void:
	var moves: Array = PHASES[phase].moves
	_move = str(moves[_move_i % moves.size()])
	_move_i += 1
	state = State.WARN
	var lead := TELL.lead()
	_state_t = lead
	var ground := home.y
	match _move:
		"jump":
			TELL.warn(self, "jump", RING_REACH, COLOUR, lead + 0.3, {"visual": visual, "ground_y": ground})
		"dash":
			_dir = player.global_position - global_position
			_dir.y = 0
			_dir = _dir.normalized() if _dir.length() > 0.1 else -visual.global_basis.z
			TELL.warn(self, "dash", CHARGE_LEN, COLOUR, lead, {"visual": visual, "dir": _dir, "follow": null,
				"at": Vector3(global_position.x, ground + 0.06, global_position.z)})
		"drop":
			# One falling star in phase 2, three in phase 3: one on you and two either side
			_targets.clear()
			var at := Vector3(player.global_position.x, ground, player.global_position.z)
			_targets.append(at)
			if phase >= 2:
				var side := (at - global_position).cross(Vector3.UP)
				side.y = 0
				side = side.normalized() * 4.5 if side.length() > 0.1 else Vector3.RIGHT * 4.5
				_targets.append(at + side)
				_targets.append(at - side)
			for t in _targets:
				TELL.warn(self, "drop", DROP_R, COLOUR, lead, {"visual": visual, "follow": null, "at": t + Vector3(0, 0.06, 0)})
		"pull":
			TELL.warn(self, "pull", PULL_REACH, COLOUR, lead, {"visual": visual, "ground_y": ground})


func _do_move() -> void:
	state = State.ACT
	match _move:
		"jump":
			_state_t = 0.4
			ShockRing.spawn(get_parent(), Vector3(global_position.x, home.y, global_position.z), RING_REACH, COLOUR, 2, 0.9, "star")
			Juice.shake(0.4)
			Juice.blip("thud", 0.55, -1.0)
			_squash(0.6)
		"dash":
			_state_t = CHARGE_LEN / (CHARGE_SPEED * quick())
			Juice.blip("whoosh", 0.6, -2.0)
		"drop":
			_state_t = 0.45
			for t in _targets:
				_star_fall(t)
		"pull":
			_state_t = PULL_TIME
			Juice.blip("whoosh", 0.35, -2.0)


func _star_fall(at: Vector3) -> void:
	# A star drops out of the sky where the shadow was, and bumps you if you're still on it
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	star.mesh = sm
	star.material_override = _mat(Color(0.75, 0.95, 1.0), 2.2)
	get_parent().add_child(star)
	star.global_position = at + Vector3(0, 14, 0)
	var tw := star.create_tween()
	tw.tween_property(star, "global_position", at + Vector3(0, 0.5, 0), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Fx.burst(get_parent(), at + Vector3(0, 0.4, 0), Color(0.75, 0.95, 1.0), 18, 0.08, 4.0, 0.0, 0.6)
		Juice.blip("thud", 1.1, -4.0)
		if is_instance_valid(player) and _flat(player.global_position - at) < DROP_R \
				and player.global_position.y < at.y + 2.0 and not player.call("is_invulnerable"):
			player.call("hurt", 2, at)
		star.queue_free())


func _pull_step(delta: float) -> void:
	# Its big breath drags you along the ground towards it. Jumping breaks free.
	if not player.is_on_floor():
		return
	var to := global_position - player.global_position
	to.y = 0
	var d := to.length()
	if d > PULL_REACH or d < 3.0:
		return
	player.global_position += to / d * PULL_SPEED * delta


func _daze() -> void:
	state = State.DAZED
	_state_t = float(PHASES[phase].daze)
	_daze_hits = 0
	velocity = Vector3.ZERO
	_squash(0.4)
	if shield_on:
		if _told <= 0.0:
			Game.message("Its antlers shield it! Break the Star Shards!")
			_told = 12.0
	elif hits == 0 and _told <= 0.0:
		Game.message("%s's puffed out! Pop it now!" % TITLE)
		_told = 20.0


func _get_up() -> void:
	var was_stagger := state == State.STAGGER
	state = State.IDLE
	_state_t = IDLE_TIME / quick()
	visual.rotation.z = 0.0
	if was_stagger and phase == 1:
		_light_shards(true)                    # (still in phase 2: the shards glow again)


# -----------------------------------------------------------------------------
# Phases: a one-way latch, and a beat between them where it rears up, roars and starts the new phase
# -----------------------------------------------------------------------------
func _turn() -> void:
	phase = mini(phase + 1, PHASES.size() - 1)
	state = State.TURN
	_state_t = TURN_TIME
	velocity = Vector3.ZERO
	visual.rotation.z = 0.0
	for t in get_tree().get_nodes_in_group("boss_tells"):
		if is_instance_valid(t) and t.get("follow") == self:
			t.queue_free()
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", -0.45, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.9)
	tw.tween_property(visual, "rotation:x", 0.0, 0.4)
	# Its roar opens the phase: a big ring, warned like every ring
	TELL.warn(self, "jump", ROAR_REACH, COLOUR, TURN_TIME - 0.2, {"visual": visual, "ground_y": home.y})
	Juice.blip("whoosh", 0.3, 0.0)
	Juice.shake(0.5)
	Juice.rumble(0.6, 0.5)
	Game.message("%s roars!" % TITLE if phase < 2 else "%s is getting cross!" % TITLE)


func _turn_done() -> void:
	ShockRing.spawn(get_parent(), Vector3(global_position.x, home.y, global_position.z), ROAR_REACH, COLOUR, 2, 1.1, "star")
	Juice.shake(0.45)
	Juice.blip("thud", 0.45, 0.0)
	_set_shield(bool(PHASES[phase].get("shards", false)))
	_light_shards(bool(PHASES[phase].get("shards", false)))
	if shield_on:
		Game.message("Break the three Star Shards!")
	state = State.IDLE
	_state_t = IDLE_TIME


func _set_shield(on: bool) -> void:
	shield_on = on
	if _shield:
		_shield.visible = on


func _light_shards(on: bool) -> void:
	for s in shards:
		if is_instance_valid(s):
			s.set_meta("lit", on)
			var gem := s.get_node_or_null("Gem") as Node3D
			if gem:
				gem.visible = on


func shard_lit(s: Node3D) -> bool:
	return bool(s.get_meta("lit", false))


func break_shard(s: Node3D) -> String:
	if not shard_lit(s) or state == State.SLEEP:
		return "bounce"
	s.set_meta("lit", false)
	var gem := s.get_node_or_null("Gem") as Node3D
	if gem:
		gem.visible = false
	Fx.burst(get_parent(), s.global_position + Vector3(0, 2.4, 0), COLOUR, 20, 0.1, 4.0, 0.0, 0.7)
	Juice.blip("pop", 1.2, -2.0)
	Juice.hitstop(0.04)
	var left := 0
	for o in shards:
		if is_instance_valid(o) and shard_lit(o):
			left += 1
	if left == 0:
		_stagger()
	else:
		Game.message("%d more!" % left)
	return "hit"


func _check_shards() -> void:
	# Walking or jumping into a lit shard breaks it too, so it doesn't need a gadget
	for s in shards:
		if is_instance_valid(s) and shard_lit(s):
			var gem := s.global_position + Vector3(0, 2.4, 0)
			if player.global_position.distance_to(gem) < SHARD_TOUCH + 0.6:
				break_shard(s)


func _stagger() -> void:
	# All three shards broken: its shield goes out and it's knocked over for a good long while
	_set_shield(false)
	for t in get_tree().get_nodes_in_group("boss_tells"):
		if is_instance_valid(t) and t.get("follow") == self:
			t.queue_free()
	state = State.STAGGER
	_state_t = STAGGER_TIME
	_daze_hits = 0
	velocity = Vector3.ZERO
	create_tween().tween_property(visual, "rotation:z", 0.5, 0.4).set_trans(Tween.TRANS_BOUNCE)
	Juice.shake(0.5)
	Juice.blip("thud", 0.4, 0.0)
	Game.message("It's knocked over! Pop it now!")


# -----------------------------------------------------------------------------
# Getting hit
# -----------------------------------------------------------------------------
func _open() -> bool:
	return (state == State.DAZED and not shield_on) or state == State.STAGGER


func _touch_player() -> void:
	if _open():
		var feet := player.global_position.y - 0.8
		if player.velocity.y < 0.5 and feet > global_position.y + HEIGHT * 0.55:
			player.call("bounce", 10.0)
			hurt(1)
			return
		if player.call("is_rolling"):
			hurt(1)
		return
	if state == State.SLEEP or state == State.DAZED or state == State.TURN:
		return
	if not player.call("is_invulnerable"):
		player.call("hurt", 2, global_position)


func shot(power: int, point: Vector3, _dir_in: Vector3) -> String:
	if defeated or state == State.SLEEP:
		return "miss"
	if not _open():
		Fx.burst(get_parent(), point, COLOUR, 6, 0.05, 2.0, 0.0, 0.3)
		if _told <= 0.0:
			Game.message("Break the Star Shards first!" if shield_on else "Boing! Wait till it's puffed out.")
			_told = 8.0
		return "miss"
	var room := (STAGGER_HITS if state == State.STAGGER else MAX_PER_DAZE) - _daze_hits
	hurt(mini(power, room))
	return "hit"


func hurt(n: int) -> void:
	if defeated or n <= 0 or not _open():
		return
	n = mini(n, phase_cap() - hits)              # a burst never skips a phase
	if n <= 0:
		return
	hits += n
	_daze_hits += n
	Juice.hitstop(0.05)
	Fx.burst(get_parent(), global_position + Vector3(0, HEIGHT * 0.6, 0), COLOUR, 12, 0.08, 3.0, 0.5, 0.6)
	Juice.blip("pop", 0.6, -4.0)
	_squash(0.3)
	if hits >= HITS:
		_calmed()
	elif phase_for(hits) > phase:
		_turn()


func _calmed() -> void:
	defeated = true
	state = State.CALMED
	velocity = Vector3.ZERO
	_bar.fill = 0.0
	_bar.visible = false
	_set_shield(false)
	_light_shards(false)
	_hitbox.set_deferred("monitoring", false)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var first := not bool(Dialogue.flags.get(flag(), false))
	Dialogue.flags[flag()] = true
	if first:
		Game.add_sparkles(40, TITLE)
		Remnants.add(5, TITLE)
		var gifts := ["+40 sparkles", "+5 Remnants"]
		if not Game.has_item("shop:starhorn_antlers"):
			Game.items.append("shop:starhorn_antlers")
			gifts.append("the Starhorn Antlers")
		Game.message("%s is calm and happy!\n%s" % [TITLE, ", ".join(gifts)])
	else:
		Game.message("%s is calm and happy!" % TITLE)
	Juice.rumble(0.5, 0.4)
	Fx.burst(get_parent(), global_position + Vector3(0, HEIGHT * 0.6, 0), Color(0.8, 0.95, 1.0), 40, 0.12, 5.0, -1.0, 1.2)
	# It lies down for a nap, small and happy, and fades into starlight
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 0.4, 1.4).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "position:y", 8.0, 1.6)
	tw.parallel().tween_property(visual, "scale", Vector3.ONE * 0.05, 1.6)
	tw.tween_callback(func() -> void: visual.visible = false)
	Game.save_game()


# -----------------------------------------------------------------------------
# The Star Shards: three crystals on pillars round the summit, made by the trail (skyreach_trail.gd calls this)
# -----------------------------------------------------------------------------
func make_shards(parent: Node3D, centre: Vector3) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + PI / 2.0
		var at := centre + Vector3(sin(a), 0, cos(a)) * SHARD_R
		var s: StaticBody3D = SHOT_TARGET.new()
		s.name = "Star Shard %d" % (k + 1)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.7
		cyl.height = 1.6
		cs.shape = cyl
		cs.position.y = 0.8
		s.add_child(cs)
		var gs := CollisionShape3D.new()        # the gem on top, for bubbles to hit
		var ball := SphereShape3D.new()
		ball.radius = 0.8
		gs.shape = ball
		gs.position.y = 2.4
		s.add_child(gs)
		parent.add_child(s)
		s.global_position = at
		s.set("on_shot", break_shard.bind(s))
		var stone := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.55
		sm.bottom_radius = 0.8
		sm.height = 1.6
		stone.mesh = sm
		stone.material_override = _mat(Color(0.45, 0.42, 0.55))
		stone.position.y = 0.8
		s.add_child(stone)
		var gem := Node3D.new()
		gem.name = "Gem"
		gem.position.y = 2.4
		gem.visible = false
		s.add_child(gem)
		var crystal := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.9, 1.4, 0.9)
		crystal.mesh = pm
		crystal.material_override = _mat(COLOUR, 2.4)
		gem.add_child(crystal)
		var down := MeshInstance3D.new()
		down.mesh = pm
		down.material_override = crystal.material_override
		down.rotation.z = PI
		down.position.y = -0.9
		down.scale = Vector3(1, 0.5, 1)
		gem.add_child(down)
		var l := OmniLight3D.new()
		l.light_color = COLOUR
		l.light_energy = 1.4
		l.omni_range = 5.0
		gem.add_child(l)
		s.set_meta("lit", false)
		shards.append(s)


# -----------------------------------------------------------------------------
# Its look, made from shapes: a giant stag of lilac-grey mountain stone, mossy on its back, with glowing eyes, a
# starry mane and huge antlers of glowing crystal with little stars on the tips
# -----------------------------------------------------------------------------
func _sleep_pose(on: bool) -> void:
	if visual == null:
		return
	var body := visual.get_node_or_null("Body") as Node3D
	if body:
		body.position.y = 1.6 if on else 3.4
	for leg in _parts.get("legs", []):
		(leg as Node3D).scale.y = 0.45 if on else 1.0
	var neck := _parts.get("neck") as Node3D
	if neck:
		neck.rotation.x = 0.9 if on else 0.0
	for e in _parts.get("eyes", []):
		(e as Node3D).scale.y = 0.12 if on else 1.0
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz:
		zz.visible = on


func _squash(k: float) -> void:
	if visual == null:
		return
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.0 + 0.12 * k, 1.0 - 0.16 * k, 1.0 + 0.12 * k), 0.08)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(_delta: float) -> void:
	var calm := 0.3 if Settings.reduce_motion else 1.0
	var sleeping := state == State.SLEEP
	var body := visual.get_node_or_null("Body") as Node3D
	if body and not sleeping:
		body.position.y = 3.4 + sin(_t * 2.0) * 0.08 * calm
	var stride := (8.0 if state == State.ACT else 3.0) * calm
	var i := 0
	for leg in _parts.get("legs", []):
		var moving := state == State.IDLE or (state == State.ACT and _move == "dash")
		(leg as Node3D).rotation.x = sin(_t * stride + i * PI) * (0.35 if moving else 0.0)
		i += 1
	var mane := _parts.get("mane") as Node3D
	if mane:
		mane.rotation.y = _t * 0.3 * calm
	if _shield and _shield.visible:
		_shield.rotation.y = _t * 0.5
		var pulse := 1.0 + 0.03 * sin(_t * 4.0) * calm
		_shield.scale = Vector3(pulse, pulse, pulse)
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz and zz.visible:
		zz.position.y = 5.2 + fmod(_t * 0.4, 1.0) * 0.8


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _put(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


func _look(v: Node3D) -> void:
	var stone := _mat(Color(0.56, 0.52, 0.66))
	var dark := _mat(Color(0.4, 0.37, 0.5))
	var moss := _mat(Color(0.42, 0.62, 0.48))
	var glow := _mat(COLOUR, 2.0)
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 3.4
	v.add_child(body)
	# A big round barrel of a body, a mossy back with little crystals growing out of it
	_put(body, _ball(1.9), stone, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.95, 1.55))
	_put(body, _ball(1.75), moss, Vector3(0, 0.55, -0.1), Vector3.ZERO, Vector3(0.95, 0.5, 1.45))
	for k in 5:
		_put(body, _cone(0.0, 0.22, 0.7), glow, Vector3(sin(k * 2.3) * 0.7, 1.35, -1.6 + k * 0.7), Vector3(0.2 * sin(k), 0, 0.3 * cos(k)))
	_put(body, _ball(0.9), stone, Vector3(0, 0.1, -2.6), Vector3.ZERO, Vector3(0.7, 0.7, 0.6))     # its tail end
	_put(body, _ball(0.35), _mat(Color(0.95, 0.95, 1.0)), Vector3(0, 0.5, -3.05))                 # a fluffy white tail
	# Four sturdy legs with dark hooves (pivots at the hips, so they swing)
	var legs: Array = []
	for at in [Vector3(-1.0, -0.6, 1.6), Vector3(1.0, -0.6, 1.6), Vector3(-1.0, -0.6, -1.6), Vector3(1.0, -0.6, -1.6)]:
		var hip := Node3D.new()
		hip.position = at
		body.add_child(hip)
		_put(hip, _cone(0.42, 0.32, 2.4), stone, Vector3(0, -1.2, 0))
		_put(hip, _cone(0.4, 0.45, 0.4), dark, Vector3(0, -2.5, 0.05))
		legs.append(hip)
	_parts["legs"] = legs
	# The neck, head and antlers on a pivot at the shoulders, so it can bow its head when it sleeps
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.8, 2.2)
	body.add_child(neck)
	_parts["neck"] = neck
	_put(neck, _cone(0.6, 0.85, 2.2), stone, Vector3(0, 0.9, 0.4), Vector3(0.45, 0, 0))
	var mane := Node3D.new()
	mane.position = Vector3(0, 1.0, 0.1)
	neck.add_child(mane)
	_parts["mane"] = mane
	for k in 10:
		var a := TAU * k / 10.0
		_put(mane, _ball(0.09), _mat(Color(1.0, 0.95, 0.7), 2.5), Vector3(cos(a) * 0.95, sin(k * 1.7) * 0.4, sin(a) * 0.95))
	var head := Node3D.new()
	head.position = Vector3(0, 2.1, 1.1)
	neck.add_child(head)
	_put(head, _ball(0.8), stone, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.85, 1.1))
	_put(head, _ball(0.5), _mat(Color(0.75, 0.72, 0.85)), Vector3(0, -0.25, 0.75), Vector3.ZERO, Vector3(0.9, 0.75, 1.0))   # muzzle
	_put(head, _ball(0.16), _mat(Color(0.2, 0.15, 0.25)), Vector3(0, -0.12, 1.22))                                        # nose
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		eyes.append(_put(head, _ball(0.17), _mat(COLOUR, 3.0), Vector3(side * 0.45, 0.18, 0.55)))
		_put(head, _cone(0.05, 0.25, 0.6), stone, Vector3(side * 0.75, 0.35, -0.1), Vector3(0, 0, -side * 1.1))          # ears
	_parts["eyes"] = eyes
	# Its antlers: branches of glowing crystal, a little star on every tip
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		root.position = Vector3(side * 0.35, 0.65, -0.1)
		root.rotation = Vector3(-0.25, 0, -side * 0.45)
		head.add_child(root)
		_put(root, _cone(0.1, 0.18, 2.2), glow, Vector3(0, 1.1, 0))
		var tips := [Vector3(0, 2.3, 0)]
		for k in 3:
			var y := 0.6 + k * 0.55
			var br := Node3D.new()
			br.position = Vector3(0, y, 0)
			br.rotation = Vector3(0.5 * (1 if k % 2 == 0 else -1), 0, side * (0.9 - k * 0.2))
			root.add_child(br)
			_put(br, _cone(0.05, 0.1, 1.1 - k * 0.15), glow, Vector3(0, 0.5, 0))
			_put(br, _ball(0.14), _mat(Color(1.0, 0.95, 0.65), 3.0), Vector3(0, 1.08 - k * 0.15, 0))
		for t in tips:
			_put(root, _ball(0.16), _mat(Color(1.0, 0.95, 0.65), 3.0), t)
	var l := OmniLight3D.new()
	l.light_color = COLOUR
	l.light_energy = 1.2
	l.omni_range = 9.0
	l.position = Vector3(0, 3.0, 0)
	head.add_child(l)
	# The shield its antlers throw round it in phase 2: a big see-through bubble with stars in it
	_shield = _put(v, _ball(4.6), _mat(Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.18), 0.6), Vector3(0, 3.6, 0))
	_shield.name = "Shield"
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 14:
		var a := TAU * k / 14.0
		_put(_shield, _ball(0.08), _mat(Color(1, 1, 1), 2.5), Vector3(cos(a) * 0.95, sin(k * 1.3) * 0.6, sin(a) * 0.95))
	_shield.visible = false
	var z := Label3D.new()
	z.name = "Zzz"
	z.text = "z z z"
	z.font_size = 96
	z.outline_size = 18
	z.modulate = Color(0.95, 0.9, 1.0)
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.position = Vector3(1.5, 5.2, 2.0)
	v.add_child(z)
