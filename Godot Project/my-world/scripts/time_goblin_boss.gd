extends "res://scripts/time_goblin.gd"

# Grandfather Tock, the Time Goblins' boss (Hayden, Nov 1, 2026: every enemy gets a bigger boss version with ramped-up
# aggression and mechanics). A big old goblin in a long coat and spectacles, wearing a grandfather clock as a hat, its
# pendulum swinging. He lives in the middle of the Goblin Clockyard (scripts/bosses.gd).
#
# What he does, on top of everything a Time Goblin does:
#   - Rewinds his own clock: when he blinks back in time he also UNDOES the last hit he took. So the trick is to make
#     him blink first, then pop him while he's dizzy (he can't blink again until his clock winds back up).
#   - Chimes: every few seconds while he's after you, his clock strikes three times, and each strike sends a ring
#     rolling out across the ground. Jump each ring.
#   - Calls goblins: at two-thirds and one-third he whistles up two Time Goblins (they don't come back once popped).
#   - Gets cross: under half, he's quicker, chimes more often and blinks sooner.
# Kid-safe: bumps only, popped in a bubble like the rest, and back later.

const NAME := "Grandfather Tock"
const HELPER := preload("res://scenes/enemies/time_goblin.tscn")
const MAX_HELPERS := 4

@export var chime_every := 7.0
@export var chime_reach := 9.0

var _chime_t := 4.0
var _chimes_left := 0
var _chime_gap := 0.0
var _calls_made := 0
var _helpers: Array[Node] = []
var _bar: BossBar
var _pendulum: Node3D
var _clock_hand: Node3D
var _cross := false
var _warned := false
var _base := []                                # chase speed, chime gap, blink cooldown, before he got cross


func _ready() -> void:
	super()
	add_to_group("bosses")
	_pendulum = get_node_or_null("Visual/Head/Clock/Pendulum") as Node3D
	_clock_hand = get_node_or_null("Visual/Head/Clock/Hand") as Node3D
	_bar = BossBar.make(self, NAME, Color(0.3, 0.95, 0.85), 2.0 * size + 0.5)
	_base = [chase_speed, chime_every, blink_cooldown]


func _physics_process(delta: float) -> void:
	super(delta)
	if defeated:
		return
	_bar.fill = 1.0 - float(hits) / stomps_to_defeat
	if _pendulum:
		_pendulum.rotation.z = sin(_t * (5.0 if _cross else 3.2)) * 0.45
	if _clock_hand:
		_clock_hand.rotation.z += delta * (8.0 if state == State.DIZZY else 1.5)
	if not _cross and hits * 2 >= stomps_to_defeat:
		_cross = true
		chase_speed *= 1.15
		chime_every *= 0.7
		blink_cooldown *= 0.75
		Game.message("Grandfather Tock is cross now! His clock ticks faster.")
	# The chimes: three strikes, each a ring to jump
	if _chimes_left > 0:
		_chime_gap -= delta
		if _chime_gap <= 0.0:
			_strike()
		return
	if state == State.CHASE and is_on_floor():
		_chime_t -= delta
		if _chime_t <= 0.0:
			_chime_t = chime_every * randf_range(0.85, 1.2)
			_chimes_left = 3
			_chime_gap = 0.5
			if not _warned:
				_warned = true
				Game.message("BONG! Grandfather Tock's clock is striking! Jump the rings!")


func _strike() -> void:
	_chimes_left -= 1
	_chime_gap = 0.75 if not _cross else 0.6
	Juice.blip("tick", 0.5, -2.0)
	Audio.play_at("stomp", global_position, 2.0, -0.3)
	_squash = 0.3
	velocity = Vector3.ZERO
	if player and global_position.distance_to(player.global_position) < 25.0:
		Juice.shake(0.25)
		Juice.rumble(0.3, 0.15, 0.3)
	ShockRing.spawn(get_parent(), global_position, chime_reach, Color(0.45, 1.0, 0.9), damage, 1.0)


func _blinked() -> void:
	# He rewinds his own clock too: the last hit is undone
	if hits > 0:
		hits -= 1
		Game.message("Grandfather Tock rewound his clock! Pop him while he's dizzy.")
	Fx.burst(get_parent(), global_position + Vector3(0, 1.6 * size, 0), Color(0.5, 1.0, 0.9), 18, 0.1, 3.0, 0.0, 0.7)


func _hurt_message(_stomped: bool) -> void:
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Juice.burst(get_parent(), global_position + Vector3(0, 1.2 * size, 0), Color(0.5, 1.0, 0.9), 10, 0.1, 3.0, 0.6)
	var left := stomps_to_defeat - hits
	if state != State.DIZZY:
		Game.message("Tock wobbles! %d more to pop him." % left if left > 1 else "One more and Tock pops!")
	var due := 0
	if hits * 3 >= stomps_to_defeat * 2:
		due = 2
	elif hits * 3 >= stomps_to_defeat:
		due = 1
	while _calls_made < due:
		_calls_made += 1
		_call_helpers(2)


func _stomped() -> void:
	# Stomping him doesn't make him blink straight away (the bubble trick does); it just counts as a hit
	hits += 1
	player.bounce(STOMP_BOUNCE)
	Audio.play_at("stomp", global_position, 0.0, 0.0)
	Juice.hitstop(0.04)
	if hits >= stomps_to_defeat:
		_defeat()
	else:
		_squash = 0.4
		_hurt_message(true)


func _snatch() -> void:
	# He doesn't run off with sparkles: he shoos you away
	_giggle()


func _call_helpers(count: int) -> void:
	_helpers.assign(_helpers.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	for i in count:
		if _helpers.size() >= MAX_HELPERS:
			return
		var g := HELPER.instantiate() as CharacterBody3D
		g.name = "Tock's Goblin %d" % randi_range(100, 999)
		g.set("respawns", false)
		g.set("xp_reward", 3)
		var a := randf() * TAU
		g.position = global_position + Vector3(cos(a), 0.4, sin(a)) * (1.2 * size)
		get_parent().add_child(g)
		_helpers.append(g)
	Game.message("Grandfather Tock whistles for his goblins!")
	Audio.play_at("gloop_giggle", global_position, 4.0, 0.3)


func helpers() -> Array[Node]:
	_helpers.assign(_helpers.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	return _helpers


func _defeated() -> void:
	Game.message("You popped Grandfather Tock! (He'll wind himself back up later.)")
	Dialogue.set_flag("popped_grandfather_tock")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	_calls_made = 0
	_chimes_left = 0
	_cross = false
	_warned = false
	chase_speed = _base[0]
	chime_every = _base[1]
	blink_cooldown = _base[2]
