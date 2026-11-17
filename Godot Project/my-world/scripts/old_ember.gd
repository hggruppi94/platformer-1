extends CharacterBody3D

# Old Ember: a giant, grumpy, sleepy salamander of cooled lava, curled up in the Magma Chamber under Rhythm Springs'
# volcano at the end of the secret Ember Tunnel (scripts/volcano_depths.gd; Hayden, 17 Nov 2026: "I'd love to have a
# secret volcano tunnel with an optional boss"). Optional: nothing in the game mentions it, and nothing needs it.
#
# Built the same way as the Starhorn (scripts/starhorn.gd), whose header credits the open-source boss fights we read
# first: one small WARN -> ACT -> DAZED loop with every attack read from a mark on the ground (scripts/boss_tell.gd),
# and PHASES with a one-way latch, a beat between phases it can't be hit in, a burst of bubbles never skipping a phase,
# and things in the arena you break to knock it down.
#
# The fight, in three phases (HITS bubbles, stomps or rolls to calm it, at most MAX_PER_DAZE in a row):
#   1. Tail slam (a ring: jump it) and belly slide (arrows: step aside). After each it's puffed out: pop it then.
#   2. It rears up and roars, and its crust glows red hot (a shield). Three Geyser Stones round the chamber glow: hit
#      them (a bubble, or jump into one) and each shoots spring water up; when all three have gone, the rain cools its
#      crust with a hiss of steam and it's knocked over for a long time. Lava blobs drip from the roof (a shadow: move
#      off it).
#   3. It roars again and gets quicker, and adds its big breath in (arrows pointing in: jump free).
# Go back up the tunnel and it settles back to sleep, all its puff back, no harm done. Kid-safe: a bump, never more.

const TELL := preload("res://scripts/boss_tell.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const KIT := preload("res://scripts/cave_kit.gd")

const TITLE := "Old Ember"
const COLOUR := Color(1.0, 0.55, 0.2)
const WATER := Color(0.45, 0.85, 1.0)
const HEIGHT := 4.4
const HITS := 15
const MAX_PER_DAZE := 3
const STAGGER_HITS := 4
# health left (1 is full) at which each phase ends, its moves, and how much quicker it is
const PHASES := [
	{"until": 2.0 / 3.0, "moves": ["jump", "dash"], "quick": 1.0, "daze": 3.0},
	{"until": 1.0 / 3.0, "moves": ["drop", "jump", "dash"], "quick": 1.15, "daze": 3.0, "stones": true},
	{"until": 0.0, "moves": ["pull", "dash", "drop", "jump"], "quick": 1.3, "daze": 2.4},
]
const WAKE := 8.0                       # come this close (well into the chamber) and it wakes
const LEASH := 13.0                     # go further than this (back up the tunnel) and it goes back to sleep
const ROAM := 5.0
const IDLE_TIME := 1.5
const TURN_TIME := 2.6
const STAGGER_TIME := 6.0
const RING_REACH := 7.5
const ROAR_REACH := 9.0
const CHARGE_LEN := 12.0
const CHARGE_SPEED := 13.0
const DROP_R := 2.3
const PULL_REACH := 9.0
const PULL_TIME := 1.8
const PULL_SPEED := 3.4
const STONE_TOUCH := 1.5
const ARENA_EDGE := 6.6                 # a slide stops before the lava ring

enum State { SLEEP, IDLE, WARN, ACT, DAZED, TURN, STAGGER, CALMED }

var home := Vector3.ZERO
var depths: Node3D                      # the volcano (scripts/volcano_depths.gd)
var state := State.SLEEP
var phase := 0
var hits := 0
var defeated := false
var visual: Node3D
var player: CharacterBody3D
var stones: Array[Node3D] = []          # the three Geyser Stones
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
var _crust: Array[StandardMaterial3D] = []


func flag() -> String:
	return "old_ember_calmed"


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0                         # it keeps to the chamber floor's height
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.7
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 2.2
	hcap.height = HEIGHT + 0.4
	hcs.shape = hcap
	hcs.position.y = HEIGHT * 0.5
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_look(visual)
	KIT.in_the_dark(visual)
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
	# The most hits this phase can take: a big burst of bubbles never skips a phase
	return int(round((1.0 - float(PHASES[phase].until)) * HITS))


func _physics_process(delta: float) -> void:
	_find_player()
	if player == null:
		return
	_t += delta
	if defeated:
		_animate(delta)
		return
	_state_t -= delta
	_told = maxf(_told - delta, 0.0)
	var from_home := _flat(player.global_position - home)
	if state == State.SLEEP:
		if from_home < WAKE and absf(player.global_position.y - home.y) < 5.0 and not Dialogue.is_active():
			_wake()
		_animate(delta)
		return
	if from_home > LEASH:
		_calm_down()
		return
	_check_stones()
	var h := Vector3.ZERO
	match state:
		State.IDLE:
			var to := player.global_position - global_position
			to.y = 0
			if to.length() > 4.5:
				h = to.normalized() * 2.2 * quick() * Arsenal.slow(self)
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
		h += -off.normalized() * 3.5
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
	Game.message("%s wakes up grumpy! Go back up the tunnel to let it sleep." % TITLE)


func _calm_down() -> void:
	# You went back up the tunnel: it settles back to sleep, all its puff back, no harm done
	state = State.SLEEP
	hits = 0
	phase = 0
	_bar.visible = false
	_bar.fill = 1.0
	velocity = Vector3.ZERO
	global_position = home
	_set_shield(false)
	_light_stones(false)
	_clear_tells()
	_sleep_pose(true)
	Game.message("%s curls back up and goes to sleep." % TITLE)


func _clear_tells() -> void:
	for t in get_tree().get_nodes_in_group("boss_tells"):
		if is_instance_valid(t) and t.get("follow") == self:
			t.queue_free()


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
			_dir = _dir.normalized() if _dir.length() > 0.1 else visual.global_basis.z
			TELL.warn(self, "dash", CHARGE_LEN, COLOUR, lead, {"visual": visual, "dir": _dir, "follow": null,
				"at": Vector3(global_position.x, ground + 0.06, global_position.z)})
		"drop":
			# One lava blob in phase 2, three in phase 3: one on you and two either side
			_targets.clear()
			var at := Vector3(player.global_position.x, ground, player.global_position.z)
			_targets.append(at)
			if phase >= 2:
				var side := (at - global_position).cross(Vector3.UP)
				side.y = 0
				side = side.normalized() * 3.6 if side.length() > 0.1 else Vector3.RIGHT * 3.6
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
			ShockRing.spawn(get_parent(), Vector3(global_position.x, home.y, global_position.z), RING_REACH, COLOUR, 2, 0.9)
			Juice.shake(0.4)
			Juice.blip("thud", 0.55, -1.0)
			_squash(0.6)
			var tail := _parts.get("tail") as Node3D
			if tail:
				var tw := create_tween()
				tw.tween_property(tail, "rotation:x", -0.6, 0.1)
				tw.tween_property(tail, "rotation:x", 0.0, 0.3)
		"dash":
			_state_t = CHARGE_LEN / (CHARGE_SPEED * quick())
			Juice.blip("whoosh", 0.6, -2.0)
		"drop":
			_state_t = 0.45
			for t in _targets:
				_lava_drop(t)
		"pull":
			_state_t = PULL_TIME
			Juice.blip("whoosh", 0.35, -2.0)


func _lava_drop(at: Vector3) -> void:
	# A blob of lava drips off the roof where the shadow was, and bumps you if you're still on it
	var blob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.3
	blob.mesh = sm
	blob.material_override = _mat(Color(1.0, 0.5, 0.12), 3.0)
	blob.layers = KIT.LAYER
	get_parent().add_child(blob)
	blob.global_position = at + Vector3(0, 9, 0)
	var tw := blob.create_tween()
	tw.tween_property(blob, "global_position", at + Vector3(0, 0.4, 0), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Fx.burst(get_parent(), at + Vector3(0, 0.3, 0), Color(1.0, 0.55, 0.2), 16, 0.08, 4.0, 0.0, 0.6)
		Juice.blip("thud", 1.1, -4.0)
		if is_instance_valid(player) and _flat(player.global_position - at) < DROP_R \
				and player.global_position.y < at.y + 2.0 and not player.call("is_invulnerable"):
			player.call("hurt", 2, at)
		blob.queue_free())


func _pull_step(delta: float) -> void:
	# Its big breath in drags you along the floor towards it. Jumping breaks free.
	if not player.is_on_floor():
		return
	var to := global_position - player.global_position
	to.y = 0
	var d := to.length()
	if d > PULL_REACH or d < 2.6:
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
			Game.message("Its crust is red hot! Hit the Geyser Stones!")
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
		_set_shield(true)                     # (still in phase 2: its crust heats up again, the stones glow again)
		_light_stones(true)


# -----------------------------------------------------------------------------
# Phases: a one-way latch, and a beat between them where it rears up, roars and starts the new phase
# -----------------------------------------------------------------------------
func _turn() -> void:
	phase = mini(phase + 1, PHASES.size() - 1)
	state = State.TURN
	_state_t = TURN_TIME
	velocity = Vector3.ZERO
	visual.rotation.z = 0.0
	_clear_tells()
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", -0.4, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.9)
	tw.tween_property(visual, "rotation:x", 0.0, 0.4)
	TELL.warn(self, "jump", ROAR_REACH, COLOUR, TURN_TIME - 0.2, {"visual": visual, "ground_y": home.y})
	Juice.blip("whoosh", 0.3, 0.0)
	Juice.shake(0.5)
	Juice.rumble(0.6, 0.5)
	Game.message("%s roars!" % TITLE if phase < 2 else "%s is getting cross!" % TITLE)


func _turn_done() -> void:
	ShockRing.spawn(get_parent(), Vector3(global_position.x, home.y, global_position.z), ROAR_REACH, COLOUR, 2, 1.1)
	Juice.shake(0.45)
	Juice.blip("thud", 0.45, 0.0)
	var hot := bool(PHASES[phase].get("stones", false))
	_set_shield(hot)
	_light_stones(hot)
	if shield_on:
		Game.message("Its crust's red hot! Hit the three Geyser Stones!")
	state = State.IDLE
	_state_t = IDLE_TIME


func _set_shield(on: bool) -> void:
	# Red hot: its crust glows bright and bubbles bounce off
	shield_on = on
	for m in _crust:
		m.emission_energy_multiplier = 3.2 if on else 0.7
	var heat := visual.get_node_or_null("Heat") as Node3D
	if heat:
		heat.visible = on


func _light_stones(on: bool) -> void:
	for s in stones:
		if is_instance_valid(s):
			s.set_meta("lit", on)
			var glow := s.get_node_or_null("Glow") as Node3D
			if glow:
				glow.visible = on


func stone_lit(s: Node3D) -> bool:
	return bool(s.get_meta("lit", false))


func hit_stone(s: Node3D) -> String:
	if not stone_lit(s) or state == State.SLEEP:
		return "bounce"
	s.set_meta("lit", false)
	var glow := s.get_node_or_null("Glow") as Node3D
	if glow:
		glow.visible = false
	_geyser(s)
	Juice.blip("pop", 1.2, -2.0)
	Juice.hitstop(0.04)
	var left := 0
	for o in stones:
		if is_instance_valid(o) and stone_lit(o):
			left += 1
	if left == 0:
		_stagger()
	else:
		Game.message("%d more!" % left)
	return "hit"


func _geyser(s: Node3D) -> void:
	# A jet of spring water shoots up out of the stone and splashes down
	var jet := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.4
	cm.height = 7.0
	jet.mesh = cm
	jet.material_override = _mat(Color(WATER.r, WATER.g, WATER.b, 0.6), 1.2)
	jet.layers = KIT.LAYER
	s.add_child(jet)
	jet.position.y = 1.4
	jet.scale = Vector3(1, 0.05, 1)
	var tw := jet.create_tween()
	tw.tween_property(jet, "scale", Vector3.ONE, 0.25)
	tw.parallel().tween_property(jet, "position:y", 4.9, 0.25)
	tw.tween_interval(0.6)
	tw.tween_property(jet, "scale", Vector3(0.2, 1, 0.2), 0.3)
	tw.tween_callback(jet.queue_free)
	Fx.burst(get_parent(), s.global_position + Vector3(0, 5.0, 0), WATER, 20, 0.1, 4.0, -3.0, 0.8)


func _check_stones() -> void:
	# Walking or jumping into a lit stone sets it off too, so it doesn't need a gadget
	for s in stones:
		if is_instance_valid(s) and stone_lit(s):
			if _flat(player.global_position - s.global_position) < STONE_TOUCH + 0.4 \
					and player.global_position.y < s.global_position.y + 3.0:
				hit_stone(s)


func _stagger() -> void:
	# All three geysers gone: the rain cools its crust with a hiss of steam, and it's knocked over for a good while
	_set_shield(false)
	_clear_tells()
	state = State.STAGGER
	_state_t = STAGGER_TIME
	_daze_hits = 0
	velocity = Vector3.ZERO
	create_tween().tween_property(visual, "rotation:z", 0.45, 0.4).set_trans(Tween.TRANS_BOUNCE)
	Fx.burst(get_parent(), global_position + Vector3(0, HEIGHT, 0), Color(1, 1, 1), 30, 0.14, 3.0, 2.0, 1.0)
	Juice.shake(0.5)
	Juice.blip("thud", 0.4, 0.0)
	Game.message("Psssssh! Its crust's cooled! Pop it now!")


# -----------------------------------------------------------------------------
# Getting hit
# -----------------------------------------------------------------------------
func _open() -> bool:
	return (state == State.DAZED and not shield_on) or state == State.STAGGER


func _touch_player() -> void:
	if _open():
		var feet := player.global_position.y - 0.8
		if player.velocity.y < 0.5 and feet > global_position.y + HEIGHT * 0.5:
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
			Game.message("Hit the Geyser Stones first!" if shield_on else "Boing! Wait till it's puffed out.")
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
	_light_stones(false)
	_clear_tells()
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
		if not Game.has_item("shop:ember_frills"):
			Game.items.append("shop:ember_frills")
			gifts.append("the Ember Frills")
		Game.message("%s is calm and happy!\n%s" % [TITLE, ", ".join(gifts)])
	else:
		Game.message("%s is calm and happy!" % TITLE)
	Juice.rumble(0.5, 0.4)
	Fx.burst(get_parent(), global_position + Vector3(0, HEIGHT * 0.6, 0), Color(1.0, 0.85, 0.5), 40, 0.12, 5.0, -1.0, 1.2)
	# It curls up for a happy nap, its glow gone soft, and a column of steam opens in the roof
	visual.rotation = Vector3.ZERO
	_sleep_pose(true)
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz:
		zz.text = "z z z  ♥"
	if depths:
		Game.message.call_deferred("Steam's rising out of the floor by the wall...")
	Game.save_game()


# -----------------------------------------------------------------------------
# The Geyser Stones: three squat stones with a spring under each, round the chamber (volcano_depths.gd calls this)
# -----------------------------------------------------------------------------
func make_stones(parent: Node3D, centre: Vector3, r: float) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + PI / 3.0
		var at := centre + Vector3(sin(a), 0, cos(a)) * r
		var s: StaticBody3D = SHOT_TARGET.new()
		s.name = "Geyser Stone %d" % (k + 1)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.8
		cyl.height = 1.2
		cs.shape = cyl
		cs.position.y = 0.6
		s.add_child(cs)
		parent.add_child(s)
		s.global_position = at
		s.set("on_shot", hit_stone.bind(s))
		var stone := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.7
		sm.bottom_radius = 0.9
		sm.height = 1.2
		sm.radial_segments = 7
		stone.mesh = sm
		stone.material_override = _mat(Color(0.3, 0.32, 0.36))
		stone.position.y = 0.6
		s.add_child(stone)
		var glow := Node3D.new()
		glow.name = "Glow"
		glow.visible = false
		s.add_child(glow)
		var pool := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.55
		pm.bottom_radius = 0.55
		pm.height = 0.06
		pool.mesh = pm
		pool.material_override = _mat(WATER, 2.4)
		pool.position.y = 1.23
		glow.add_child(pool)
		for i in 3:
			var b := MeshInstance3D.new()
			b.mesh = _ball(0.12 + 0.04 * i)
			b.material_override = _mat(Color(0.8, 0.95, 1.0), 2.0)
			b.position = Vector3(0.2 * (i - 1), 1.4 + 0.25 * i, 0.1)
			glow.add_child(b)
		var l := OmniLight3D.new()
		l.light_color = WATER
		l.light_energy = 1.4
		l.omni_range = 4.0
		l.position.y = 1.8
		glow.add_child(l)
		KIT.in_the_dark(s)
		s.set_meta("lit", false)
		stones.append(s)


# -----------------------------------------------------------------------------
# Its look, made from shapes: a long, low salamander of dark cooled lava, cracked all over with glowing magma, a warm
# orange belly, big sleepy eyes, frills of flame round its head like a giant axolotl, and a long thick tail
# -----------------------------------------------------------------------------
func _sleep_pose(on: bool) -> void:
	if visual == null:
		return
	var body := visual.get_node_or_null("Body") as Node3D
	if body:
		body.position.y = 0.9 if on else 1.5
	for leg in _parts.get("legs", []):
		(leg as Node3D).scale.y = 0.5 if on else 1.0
	var head := _parts.get("head") as Node3D
	if head:
		head.rotation.x = 0.35 if on else 0.0
	var tail := _parts.get("tail") as Node3D
	if tail:
		tail.rotation.y = 1.2 if on else 0.0
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
	var sleeping := state == State.SLEEP or state == State.CALMED
	var body := visual.get_node_or_null("Body") as Node3D
	if body:
		body.position.y = (0.9 if sleeping else 1.5) + sin(_t * (1.2 if sleeping else 2.0)) * 0.06 * calm
	var stride := (9.0 if state == State.ACT else 3.5) * calm
	var i := 0
	for leg in _parts.get("legs", []):
		var moving := state == State.IDLE or (state == State.ACT and _move == "dash")
		(leg as Node3D).rotation.x = sin(_t * stride + i * PI) * (0.4 if moving else 0.0)
		i += 1
	var tail := _parts.get("tail") as Node3D
	if tail and not sleeping:
		tail.rotation.y = sin(_t * 1.8) * 0.35 * calm
	for f in _parts.get("frills", []):
		(f as Node3D).scale.y = 1.0 + 0.15 * sin(_t * 5.0 + (f as Node3D).position.x * 3.0) * calm
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz and zz.visible:
		zz.position.y = 3.2 + fmod(_t * 0.4, 1.0) * 0.8


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
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
	var skin := _mat(Color(0.2, 0.16, 0.2))
	var belly := _mat(Color(1.0, 0.55, 0.25), 0.5)
	var crack := _mat(Color(1.0, 0.45, 0.1), 0.7)
	_crust.append(crack)
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 1.5
	v.add_child(body)
	# A long, low body, its belly glowing warm, its back cracked with magma
	_put(body, _ball(1.5), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 0.8, 2.0))
	_put(body, _ball(1.4), belly, Vector3(0, -0.35, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.85))
	for k in 9:
		var z := -2.2 + k * 0.55
		_put(body, BoxMesh.new(), crack, Vector3(sin(k * 1.9) * 0.6, 1.12 - absf(z) * 0.12, z),
			Vector3(0, k * 0.7, 0), Vector3(0.08, 0.06, 0.9))
	# Little rocky bumps down its spine
	for k in 6:
		_put(body, _cone(0.0, 0.28, 0.45), skin, Vector3(0, 1.25 - absf(-1.5 + k * 0.6) * 0.15, -1.5 + k * 0.6))
	# Four short splayed legs with fat round toes (pivots at the hips, so they swing)
	var legs: Array = []
	for at in [Vector3(-1.4, -0.3, 1.5), Vector3(1.4, -0.3, 1.5), Vector3(-1.4, -0.3, -1.5), Vector3(1.4, -0.3, -1.5)]:
		var hip := Node3D.new()
		hip.position = at
		body.add_child(hip)
		_put(hip, _cone(0.35, 0.42, 1.3), skin, Vector3(sign(at.x) * 0.25, -0.55, 0), Vector3(0, 0, sign(at.x) * 0.5))
		for t in 3:
			_put(hip, _ball(0.16), belly, Vector3(sign(at.x) * 0.55 + (t - 1) * 0.18, -1.15, 0.25))
		legs.append(hip)
	_parts["legs"] = legs
	# The tail: a long thick sweep behind, on a pivot so it can swish and slam
	var tail := Node3D.new()
	tail.position = Vector3(0, -0.1, -2.6)
	body.add_child(tail)
	_parts["tail"] = tail
	for k in 5:
		var r := 0.85 - k * 0.15
		_put(tail, _ball(r), skin, Vector3(0, -0.1 * k, -0.6 - k * 0.75), Vector3.ZERO, Vector3(1.0, 0.8, 1.3))
		_put(tail, BoxMesh.new(), crack, Vector3(0, r * 0.7 - 0.1 * k, -0.6 - k * 0.75), Vector3.ZERO, Vector3(0.07, 0.05, 0.6))
	# The head: wide and round, big sleepy eyes on top, a wide smile, frills of flame round it
	var head := Node3D.new()
	head.position = Vector3(0, 0.3, 2.8)
	body.add_child(head)
	_parts["head"] = head
	_put(head, _ball(1.15), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 0.8, 1.0))
	_put(head, _ball(1.0), belly, Vector3(0, -0.35, 0.15), Vector3.ZERO, Vector3(1.15, 0.45, 0.95))
	_put(head, BoxMesh.new(), _mat(Color(0.12, 0.06, 0.08)), Vector3(0, -0.15, 1.02), Vector3.ZERO, Vector3(1.2, 0.06, 0.05))
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		_put(head, _ball(0.36), skin, Vector3(side * 0.7, 0.6, 0.35))
		eyes.append(_put(head, _ball(0.26), _mat(Color(1.0, 0.85, 0.35), 2.4), Vector3(side * 0.72, 0.66, 0.55)))
		_put(head, _ball(0.11), _mat(Color(0.1, 0.05, 0.05)), Vector3(side * 0.74, 0.68, 0.79))
		_put(head, _ball(0.1), _mat(Color(0.12, 0.06, 0.08)), Vector3(side * 0.18, 0.05, 1.05))   # nostrils
	_parts["eyes"] = eyes
	var frills: Array = []
	for side in [-1.0, 1.0]:
		for k in 3:
			var f := Node3D.new()
			f.position = Vector3(side * 1.25, 0.25 + k * 0.32, -0.25 - k * 0.1)
			f.rotation = Vector3(0, 0, -side * (0.7 + k * 0.35))
			head.add_child(f)
			_put(f, _cone(0.0, 0.2, 1.0), _mat(Color(1.0, 0.4 + k * 0.15, 0.15), 2.8), Vector3(0, 0.5, 0))
			frills.append(f)
	_parts["frills"] = frills
	var l := OmniLight3D.new()
	l.light_color = COLOUR
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.position = Vector3(0, 2.0, 0)
	body.add_child(l)
	# The heat haze round it while its crust is red hot (phase 2): a see-through orange shell
	var heat := _put(v, _ball(3.4), _mat(Color(1.0, 0.45, 0.1, 0.16), 0.8), Vector3(0, 1.6, 0), Vector3.ZERO, Vector3(1.0, 0.65, 1.5))
	heat.name = "Heat"
	heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heat.visible = false
	var z := Label3D.new()
	z.name = "Zzz"
	z.text = "z z z"
	z.font_size = 96
	z.outline_size = 18
	z.modulate = Color(1.0, 0.85, 0.7)
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.position = Vector3(1.2, 3.2, 2.4)
	v.add_child(z)
