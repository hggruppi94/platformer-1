extends "res://scripts/gloop_king.gd"

# Grumblefin, the Tide Reef's boss (plan item 19a world 5, scripts/tide_reef.gd). The file and node names still say
# "riptide_gloop" / "The Riptide Gloop" because saves and tests know them; nobody sees those. Since 15 Nov 2026
# (Hayden: "the portal worlds bosses each need new unique designs instead of being copy paste of old bosses") it isn't
# a sea-blue Gloop King any more: it's a giant grumpy pufferfish, crusted with barnacles, wearing a crown of pink
# coral, with a pouty mouth, little flapping fins and a fan tail. It swallowed the whole tide and has been snoozing in
# the Deep Basin ever since. It wakes once the three Tide Pearls are found.
#
# It's far too slippery to pop: bubbles slide off and stomps just bounce. That's where Otto comes in (the friend who
# thought he was no use): every few seconds he wraps his arms round it and HOLDS it still (hold(), called by the
# world), and only then do bubbles and stomps count. Between holds it belly-flops a wave to jump, calls in little
# Splash Gloops, and now and then it sucks the water in: a riptide that drags you towards it while you're on the
# ground (jump to break free). It puffs right up while it sucks, spines out, and goes flat and flustered while Otto
# holds it. Popping it lets the tide go: it tells the world, which mends (Portals.clear). Kid-safe: a normal bump,
# nothing more, and it doesn't count as popping the King. Its look is built here in code on the Gloop King scene's
# Body (strip() takes the goo off), so the fight's own squash and bob still move it.

const PARTS := preload("res://scripts/boss_parts.gd")
const SEA := Color(0.3, 0.75, 0.95)
const BOSS_NAME := "Grumblefin"
const PULL_EVERY := 7.5                        # seconds between riptides
const PULL_TIME := 2.2
const PULL_SPEED := 3.2                        # metres a second it drags you
const PULL_REACH := 16.0

var world: Node                               # the Tide Reef, told when it's popped
var held := false                             # Otto's got it: now it can be popped
var pulling := false
var _hold_t := 0.0
var _pull_cd := 6.0
var _pull_t := 0.0
var _slip_cd := 0.0
var _fish: Node3D
var _spines: Node3D
var _fins: Array[Node3D] = []
var _tail: Node3D
var _puff := 0.0                              # 0 its normal round self, 1 puffed right up


func _ready() -> void:
	title = BOSS_NAME
	ring_colour = SEA
	ring_style = "tide"
	throw_look = "bubble"                                    # it spits water bubbles
	throw_moves = ["fan", "shot"]
	super()
	_sea_puddle()
	var body := visual.get_node("Body") as Node3D
	PARTS.strip(visual)
	for d in _drops:                                         # no goo, so no drips
		(d.mesh as Node).queue_free()
	_drops.clear()
	_pufferfish(body)


func _sea_puddle() -> void:
	var puddle := get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.3, 0.7, 0.95, 0.5)
		puddle.material_override = pm


func _pufferfish(body: Node3D) -> void:
	_fish = PARTS.pivot(body, Vector3(0, 0.55, 0), "Pufferfish")
	var skin := PARTS.mat(Color(0.98, 0.7, 0.3), 0.55)                   # sunny orange
	var belly := PARTS.mat(Color(1.0, 0.93, 0.75), 0.6)
	var spot := PARTS.mat(Color(0.75, 0.38, 0.2), 0.6)
	var spine := PARTS.mat(Color(1.0, 0.86, 0.6), 0.5)
	var fin := PARTS.mat(Color(0.35, 0.8, 0.95), 0.4, 0.15, 0.85)
	var coral := PARTS.mat(Color(1.0, 0.48, 0.62), 0.6, 0.3)
	var shell := PARTS.mat(Color(0.93, 0.9, 0.84), 0.9)
	var dark := PARTS.mat(Color(0.06, 0.08, 0.14), 0.25)
	var white := PARTS.mat(Color(1, 1, 1), 0.2, 0.6)
	# Its skin and belly get baked scales once they're built (scripts/detail_props.gd)
	_dress_skins.call_deferred([[skin, "boss_scales"], [belly, "boss_scales"]])  # (called on itself, so nothing happens if it was freed first)
	PARTS.ball(_fish, 0.52, Vector3.ZERO, skin, Vector3(1.0, 0.95, 1.05), "Skin")
	PARTS.ball(_fish, 0.42, Vector3(0, -0.14, 0.12), belly, Vector3(1.0, 0.8, 1.0), "Belly")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 9:                                                 # dark spots on its back
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 0.4)).normalized()
		PARTS.face(PARTS.ball(_fish, 0.05, d * 0.5, spot, Vector3(1, 0.4, 1)), d)
	# Spines all over it (not its face or its belly), on their own node so they can stand up when it puffs
	_spines = PARTS.pivot(_fish, Vector3.ZERO, "Spines")
	for k in 46:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 1), rng.randf_range(-1, 1)).normalized()
		if d.z > 0.55 and d.y < 0.5:
			continue
		PARTS.spike(_spines, d * 0.46, d, 0.16, 0.035, spine)
	# Barnacles crusted on its back and sides
	for k in 8:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.7), rng.randf_range(-1, -0.1)).normalized()
		PARTS.face(PARTS.cyl(_fish, 0.03, 0.06, 0.06, d * 0.52, shell), d)
	# Its grumpy face: big eyes on the sides, heavy brows, a pouty little mouth
	for side in [-1.0, 1.0]:
		PARTS.ball(_fish, 0.13, Vector3(side * 0.3, 0.14, 0.36), white)
		PARTS.ball(_fish, 0.075, Vector3(side * 0.31, 0.13, 0.46), dark)
		PARTS.ball(_fish, 0.022, Vector3(side * 0.29, 0.17, 0.52), white)
		PARTS.box(_fish, Vector3(0.2, 0.05, 0.08), Vector3(side * 0.27, 0.3, 0.42), spot, Vector3(0, 0, side * -0.4))
		# Little side fins that flap
		var f := PARTS.pivot(_fish, Vector3(side * 0.47, -0.05, 0.1), "Fin %s" % ("L" if side < 0 else "R"))
		PARTS.ball(f, 0.16, Vector3(side * 0.1, 0, -0.04), fin, Vector3(0.9, 0.55, 0.15)).rotation.y = side * 1.2
		_fins.append(f)
	PARTS.ring(_fish, 0.05, 0.1, Vector3(0, -0.08, 0.53), PARTS.mat(Color(0.95, 0.45, 0.4), 0.4), Vector3(PI / 2, 0, 0),
		"Mouth")
	# A fan tail and a fin on top
	_tail = PARTS.pivot(_fish, Vector3(0, 0.02, -0.5), "Tail")
	for side in [-1.0, 1.0]:
		PARTS.ball(_tail, 0.2, Vector3(side * 0.1, 0.05, -0.14), fin, Vector3(0.45, 1.0, 0.12)).rotation = \
			Vector3(0.0, PI / 2, side * 0.5)
	PARTS.ball(_fish, 0.16, Vector3(0, 0.5, -0.12), fin, Vector3(0.12, 0.8, 1.0))
	# A crown of pink coral
	var crown := PARTS.pivot(_fish, Vector3(0, 0.46, 0.08), "Coral Crown")
	for k in 6:
		var a := TAU * k / 6.0
		var at := Vector3(cos(a) * 0.15, 0.0, sin(a) * 0.12)
		PARTS.spike(crown, at, Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.3), 0.24, 0.035, coral)
		PARTS.ball(crown, 0.035, at + Vector3(cos(a) * 0.09, 0.22, sin(a) * 0.07), coral)


func hold(seconds: float) -> void:
	# Otto's arms are round it: it can't move, flop or pull, and it can be popped
	if defeated:
		return
	held = true
	_hold_t = seconds
	pulling = false
	_flopping = false


func release() -> void:
	held = false
	_hold_t = 0.0


func _physics_process(delta: float) -> void:
	_slip_cd -= delta
	if held and not defeated:
		# Held still: it only wobbles on the spot (and can be touched, stomped and shot)
		_hold_t -= delta
		_find_player()
		_t += delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		_animate(delta, 0.0, false)
		var body := visual.get_node("Body") as Node3D
		if _squash <= 0.0:
			body.scale = Vector3(1.0 + 0.06 * sin(_t * 14.0), 1.0 - 0.05 * sin(_t * 14.0), 1.0 - 0.06 * sin(_t * 14.0))
		_bar.visible = true
		var cam := get_viewport().get_camera_3d()
		if cam:
			_bar.global_basis = cam.global_basis
		_bar_fill.scale.x = maxf(0.001, 1.0 - float(hits) / stomps_to_defeat)
		_bar_fill.position.x = -0.5 * (1.0 - _bar_fill.scale.x)
		if player and hitbox.overlaps_body(player):
			_touch_player()
		if _hold_t <= 0.0:
			release()
		_puff_look(delta)
		return
	super(delta)
	_puff_look(delta)
	if defeated or player == null:
		pulling = false
		return
	# The riptide: now and then, while it's after you, it drags you in along the ground
	if pulling:
		_pull_t -= delta
		pull_step(delta)
		if _pull_t <= 0.0:
			pulling = false
	elif _was_chasing and not _flopping:
		_pull_cd -= delta
		if _pull_cd <= TELL.lead() and _pull_cd > 0.0 and not TELL.showing(self):
			TELL.warn(self, "pull", minf(PULL_REACH, 9.0), Color(0.3, 0.75, 0.95), _pull_cd)  # arrows in: it's about to suck you in
		if _pull_cd <= 0.0:
			start_pull()


func _puff_look(delta: float) -> void:
	# It puffs right up (spines out) while it sucks the water in, and squashes flat and flustered while Otto holds it;
	# its fins never stop flapping and its tail sways
	if _fish == null:
		return
	var want := 1.0 if pulling else (-0.4 if held else 0.0)
	_puff = lerpf(_puff, want, 1.0 - exp(-6.0 * delta))
	var k := 1.0 + 0.3 * _puff
	_fish.scale = Vector3(k, k * (1.0 if _puff >= 0.0 else 1.0 + 0.3 * _puff), k)
	_spines.scale = Vector3.ONE * (1.0 + 0.6 * maxf(_puff, 0.0))
	for i in _fins.size():
		_fins[i].rotation.z = sin(_t * (14.0 if held else 6.0) + i * PI) * 0.5
	_tail.rotation.y = sin(_t * 4.0) * 0.4


func start_pull() -> void:
	_pull_cd = PULL_EVERY * randf_range(0.85, 1.2)
	_pull_t = PULL_TIME
	pulling = true
	Game.message(Settings.fill("RIPTIDE! It's sucking the water in. Jump ({jump}) to break free!"))
	Audio.play_at("splash", global_position, 0.0, -0.2)


func pull_step(delta: float) -> void:
	# Drags the player towards it, only while they're on the ground and not already close
	if player == null or not player.is_on_floor() or player.is_invulnerable():
		return
	var to := global_position - player.global_position
	to.y = 0.0
	var d := to.length()
	if d > PULL_REACH or d < 2.2 * size:
		return
	player.global_position += to / d * PULL_SPEED * delta
	if Engine.get_physics_frames() % 8 == 0:
		Fx.burst(get_parent(), player.global_position + Vector3(0, -0.6, 0), Color(0.7, 0.95, 1.0, 0.8), 3, 0.07, 1.5, -2.0, 0.4)


func _slip(what: String) -> void:
	# Not held: nothing sticks
	Fx.burst(get_parent(), global_position + Vector3(0, 1.4 * size, 0), Color(0.8, 0.97, 1.0), 8, 0.08, 3.0, -6.0, 0.5)
	Juice.blip("pop", 1.6, -8.0)
	if _slip_cd <= 0.0:
		_slip_cd = 3.0
		Game.message("%s slide off! Wait for Otto." % what)


func shot(power: int, point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	if not held:
		_slip("Bubbles")
		return "bounce"
	return super(power, point, dir)


func _stomped() -> void:
	if not held:
		_find_player()
		player.bounce(STOMP_BOUNCE)
		_slip("Stomps")
		return
	super()


func _touch_player() -> void:
	# Like any Gloop, but rolling or riding into it never pops it, and while Otto holds it, it can't bump you
	var feet := player.global_position.y - 0.8
	if player.velocity.y < 0.5 and feet > global_position.y + 0.5 * size:
		_stomped()
	elif not held and not player.is_invulnerable():
		player.hurt(damage, global_position)


func _call_court(count: int) -> void:
	var before := _court.size()
	super(count)
	for i in range(before, _court.size()):
		var g := _court[i] as Node
		if is_instance_valid(g):
			g.name = "Splash Gloop %d" % randi_range(100, 999)
			for m in g.get("_goo"):
				m.set_shader_parameter("deep", Color(0.15, 0.4, 0.65))
				m.set_shader_parameter("green", Color(0.45, 0.85, 0.95))
				m.set_shader_parameter("gold", Color(1, 1, 1))


func _hurt_message(stomped: bool) -> void:
	super(stomped)
	var left := stomps_to_defeat - hits
	Game.message("%s sputters! %d more to pop it." % [BOSS_NAME, left] if left > 1 else "One more and %s pops!" % BOSS_NAME)


func _defeated() -> void:
	held = false
	pulling = false
	Game.message("Popped! The water rushes out...")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()


func _dress_skins(parts: Array) -> void:
	(load("res://scripts/detail_props.gd") as GDScript).call("dress_surfaces", self, parts)
