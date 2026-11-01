extends Node

# The final boss fight with the Agent of Chaos (Hayden, Nov 1, 2026: "Agent of Chaos is the game's final boss so he
# will need a lot of mechanics such as rewinding time / explosions / summoning minions"). Added under the giant
# (scripts/chaos_giant.gd) by the Bosses autoload (scripts/bosses.gd); while a fight is on it drives him instead of his
# patrol.
#
# Unlocking: the fight only starts once the player has popped the three bosses (the Gloop King, Grandfather Tock and
# the Boulderdillo). Before that, walking up to him just gets a hint. Once they're done, coming close starts it, and
# walking well away calls it off (he gets all his chaos back).
#
# His weak spot is the cracked backwards clock on his chest. It's shielded except when it GLOWS: then bubbles that hit
# near it count (a big bubble counts for three). His chaos meter has CHAOS_MAX points, in three phases:
#   1. Chaos Bursts:  glitchy bursts land round the player, each one marked on the ground a moment before (move off
#      the marks; jumping doesn't help), and a stomp sends a ring out (jump that). After each volley his clock glows.
#   2. Minions:       he opens glitch rifts and calls Time Goblins, Gloops and a Pebbledillo. His clock glows once
#      they're all popped (or after a while), and the bursts carry on in between.
#   3. Rewind:        he winds his clock backwards: if it isn't hit three times while it spins, time rewinds, the
#      player is pulled back to where they were a few seconds ago and he gets some chaos back. Breaking the rewind
#      leaves him dazed with his clock glowing for longer. Bursts and minions keep coming, faster.
# When his chaos runs out his clock shatters into glitch cubes, he shrinks away out of time, and the game remembers it
# (flag "beat_agent_of_chaos"). A rematch is always there next time he's about.
# Kid-safe throughout: bursts and rings bump like any enemy, nothing is hurt or broken but his clock, and he isn't
# destroyed, just sent back out of time.

signal phase_changed(phase: int)
signal won

const CHAOS_MAX := 30
const START_NEAR := 24.0                     # metres from him that starts the fight (once it's unlocked)
const GIVE_UP_FAR := 70.0                    # this far away and the fight's called off
const HEART_Y := 7.2                         # the chest clock, above his feet (the model is about 11 m tall)
const HEART_FORWARD := 1.5
const HEART_RADIUS := 1.7
const BOSS_FLAGS := ["popped_gloop_king", "popped_grandfather_tock", "popped_boulderdillo"]
const GOBLIN := preload("res://scenes/enemies/time_goblin.tscn")
const GLOOP := preload("res://scenes/enemies/gloop.tscn")
const CROC := preload("res://scenes/enemies/crocodillo.tscn")

enum Step { IDLE, BURSTS, OPEN, MINIONS, WIND, DAZED, GONE }

var giant: Node3D
var active := false
var chaos := CHAOS_MAX
var phase := 0
var step := Step.IDLE
var player: Player
var minions: Array[Node] = []
var rewinds_done := 0
var rewind_breaks := 0

var _t := 0.0
var _volleys := 0
var _cycles := 0                             # turns taken (a turn = bursts, then his clock opens, or minions, or a rewind)
var _hinted := false
var _trail: Array[Vector3] = []              # where the player has been, every 0.1 s (for the rewind)
var _trail_t := 0.0
var _wind_hits := 0
var _heart: StaticBody3D
var _glow: MeshInstance3D
var _glow_light: OmniLight3D
var _glow_mat: StandardMaterial3D
var _bar: BossBar
var _tint: ColorRect


func _ready() -> void:
	giant = get_parent() as Node3D
	_make_heart()
	_bar = BossBar.make(giant, str(giant.get("NAME")), Color(0.95, 0.35, 0.5), 9.6, 3.0)
	_bar.scale = Vector3.ONE * 2.2
	_bar.show_within = 0.0                     # hidden until a fight starts


static func unlocked() -> bool:
	for f in BOSS_FLAGS:
		if not Dialogue.flags.has(f):
			return false
	return true


static func bosses_left() -> Array[String]:
	var names := {"popped_gloop_king": "the Gloop King", "popped_grandfather_tock": "Grandfather Tock",
		"popped_boulderdillo": "the Boulderdillo"}
	var out: Array[String] = []
	for f in BOSS_FLAGS:
		if not Dialogue.flags.has(f):
			out.append(names[f])
	return out


func heart_position() -> Vector3:
	return giant.global_transform * Vector3(0, HEART_Y, HEART_FORWARD)


func vulnerable() -> bool:
	return active and (step == Step.OPEN or step == Step.DAZED or step == Step.WIND)


# -----------------------------------------------------------------------------
# Called by the giant every physics frame; returns true while the fight is driving him
# -----------------------------------------------------------------------------
func drive(delta: float) -> bool:
	if step == Step.GONE:
		return true
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return active
	var d := _flat(player.global_position - giant.global_position)
	if not active:
		if d < START_NEAR:
			if unlocked():
				start()
				return true
			if not _hinted:
				_hinted = true
				var left := bosses_left()
				Game.message("The Agent of Chaos ignores you. Beat his champions first: %s." % ", ".join(left))
		elif d > START_NEAR * 2.0:
			_hinted = false
		return false
	if d > GIVE_UP_FAR:
		stop(false)
		return false
	_t -= delta
	_remember(delta)
	giant.call("_turn_toward", player.global_position - giant.global_position, delta)
	_animate_glow(delta)
	_bar.fill = float(chaos) / CHAOS_MAX
	match step:
		Step.BURSTS:
			if _t <= 0.0:
				_volley()
		Step.OPEN, Step.DAZED:
			if _t <= 0.0:
				_next()
		Step.MINIONS:
			_tidy_minions()
			if minions.is_empty() or _t <= 0.0:
				_open(4.0)
		Step.WIND:
			if _t <= 0.0:
				_rewind()
	return true


func start() -> void:
	active = true
	chaos = CHAOS_MAX
	_volleys = 0
	_cycles = 0
	_wind_hits = 0
	_trail.clear()
	giant.add_to_group("enemies")              # so the Star Popper's hip fire looks his way...
	giant.set("size", HEART_Y / 0.45)           # ...at his chest clock (it aims 0.45 x size up)
	giant.add_to_group("bosses")
	_bar.show_within = GIVE_UP_FAR
	Game.message("The Agent of Chaos turns to face you. Pop the glowing clock on his chest!")
	Juice.shake(0.5)
	Juice.rumble(0.5, 0.4, 0.6)
	giant.call("_play", "chaos", 1.0)
	_set_phase(1)
	step = Step.BURSTS
	_t = 2.5


func stop(won_it: bool) -> void:
	active = false
	step = Step.IDLE
	_bar.show_within = 0.0
	_glow.visible = false
	_glow_light.visible = false
	giant.remove_from_group("enemies")
	giant.remove_from_group("bosses")
	giant.set("size", 1.0)
	for m in minions:
		if is_instance_valid(m):
			m.queue_free()
	minions.clear()
	if not won_it:
		chaos = CHAOS_MAX
		phase = 0
		Game.message("The Agent of Chaos lets you go... for now.")
		giant.call("_brood", 2.0)


func _set_phase(p: int) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)
	match p:
		2:
			Game.message("The Agent of Chaos tears open glitch rifts! Pop his minions!")
		3:
			Game.message("His clock spins backwards! Hit it three times while it spins, or time rewinds!")


func _next() -> void:
	# What he does after his clock closes again
	_glow.visible = false
	_glow_light.visible = false
	_volleys = 0
	step = Step.BURSTS
	_t = 1.2 if phase < 3 else 0.8


# --- Chaos bursts --------------------------------------------------------------------------------------------------

func _volley() -> void:
	_volleys += 1
	giant.call("_play", "chaos", 1.4)
	var count := 3 + phase
	var spread := 5.0
	var at := player.global_position
	for i in count:
		var spot := at
		if i > 0:
			var a := TAU * float(i) / (count - 1) + randf() * 0.5
			spot = at + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, spread)
		_burst_at(spot, 1.3 if phase < 3 else 1.0)
	if _volleys % 2 == 0:
		ShockRing.spawn(giant.get_parent(), giant.global_position, 26.0, Color(0.9, 0.3, 0.55), 2, 2.2)
		Audio.play_at("stomp", giant.global_position, 6.0, -0.5)
		Juice.shake(0.4)
	var per := 2 if phase == 1 else 1
	if _volleys >= per:
		_cycles += 1
		_tidy_minions()
		if phase == 3 and _cycles % 2 == 1:
			_wind()                                     # every other turn in the last phase he tries to rewind
		elif phase >= 2 and minions.is_empty() and _cycles % (2 if phase == 2 else 3) == 0:
			_summon()
		else:
			_open(3.5 if phase < 3 else 3.0)
	else:
		step = Step.BURSTS
		_t = 2.2 if phase < 3 else 1.6


func _burst_at(spot: Vector3, warn: float) -> void:
	var b := ChaosBurst.new()
	b.warn = warn
	giant.get_parent().add_child(b)
	b.global_position = _ground(spot)


# --- The open clock ------------------------------------------------------------------------------------------------

func _open(secs: float) -> void:
	step = Step.OPEN
	_t = secs
	_glow.visible = true
	_glow_light.visible = true
	giant.call("_play", "idle", 1.0)
	Juice.blip("chime", 0.6, -4.0)


func shot(power: int, point: Vector3, _dir: Vector3) -> String:
	if not active:
		return "miss"
	var on_heart := point.distance_to(heart_position()) < HEART_RADIUS + 0.8
	if not on_heart or not vulnerable():
		return "bounce"
	if step == Step.WIND:
		_wind_hits += 1
		Fx.burst(giant.get_parent(), point, Color(0.6, 1.0, 0.95), 10, 0.1, 3.0, 0.0, 0.5)
		Juice.blip("tick", 1.4, -3.0)
		if _wind_hits >= 3:
			_break_rewind()
		return "hit"
	chaos = maxi(chaos - power, 0)
	Juice.hitstop(0.05)
	Juice.shake(0.25)
	Fx.burst(giant.get_parent(), point, Color(1.0, 0.4, 0.6), 14, 0.12, 3.5, -1.0, 0.6)
	if chaos <= 0:
		_win()
		return "hit"
	if chaos <= CHAOS_MAX / 3:
		_set_phase(3)
	elif chaos <= CHAOS_MAX * 2 / 3:
		_set_phase(2)
	return "hit"


# --- Minions -------------------------------------------------------------------------------------------------------

func _summon() -> void:
	step = Step.MINIONS
	_t = 14.0
	giant.call("_play", "chaos", 1.0)
	Game.message("The Agent of Chaos calls his minions!")
	var kinds := [GOBLIN, GLOOP, GOBLIN] if phase == 2 else [GOBLIN, GOBLIN, GLOOP, CROC]
	var parent := giant.get_parent()
	var i := 0
	for k in kinds:
		var a := TAU * i / kinds.size() + randf() * 0.4
		var spot := _ground(player.global_position + Vector3(cos(a), 0, sin(a)) * 7.0)
		var m := (k as PackedScene).instantiate() as Node3D
		m.name = "Chaos Minion %d" % randi_range(100, 999)
		m.set("respawns", false)
		if k == CROC:
			m.set("size", 0.6)
			m.set("stomps_to_defeat", 1)
		m.position = spot + Vector3(0, 0.4, 0)
		parent.add_child(m)
		minions.append(m)
		_rift(spot)
		i += 1


func _tidy_minions() -> void:
	minions.assign(minions.filter(func(n: Node) -> bool: return is_instance_valid(n) and n.get("defeated") != true))


func _rift(at: Vector3) -> void:
	# A glitch rift: a flat spinning ring of purple and gold cubes where a minion steps out
	Fx.burst(giant.get_parent(), at + Vector3(0, 0.6, 0), Color(0.75, 0.3, 1.0), 16, 0.12, 2.5, 1.0, 0.7)
	Fx.burst(giant.get_parent(), at + Vector3(0, 0.6, 0), Color(1.0, 0.8, 0.3), 8, 0.08, 2.0, 1.0, 0.6)


# --- Rewinding time ------------------------------------------------------------------------------------------------

func _wind() -> void:
	step = Step.WIND
	_t = 4.0
	_wind_hits = 0
	_glow.visible = true
	_glow_light.visible = true
	giant.call("_play", "chaos", 0.6)
	Game.message("His clock is winding backwards! Hit it three times!")
	Juice.blip("rewind", 0.5, -2.0)


func _break_rewind() -> void:
	rewind_breaks += 1
	Game.message("You broke his rewind! He's dazed: pop his clock!")
	Juice.shake(0.4)
	step = Step.DAZED
	_t = 6.0
	giant.call("_play", "idle", 0.5)


func _rewind() -> void:
	# Time rewinds: the player is pulled back to where they were, and he gets some chaos back
	rewinds_done += 1
	var back := _trail[0] if not _trail.is_empty() else player.global_position
	player.global_position = back + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	chaos = mini(chaos + 3, CHAOS_MAX / 3)            # never undoes past the start of the last phase
	Juice.blip("rewind", 0.7, 0.0)
	Game.message("Time rewound! The Agent of Chaos got some chaos back.")
	_flash()
	_glow.visible = false
	_glow_light.visible = false
	step = Step.BURSTS
	_volleys = 0
	_t = 1.5


func _remember(delta: float) -> void:
	_trail_t -= delta
	if _trail_t > 0.0:
		return
	_trail_t = 0.1
	_trail.append(player.global_position)
	if _trail.size() > 35:                             # 3.5 s
		_trail.pop_front()


func _flash() -> void:
	if _tint == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_tint = ColorRect.new()
		_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_tint)
	_tint.color = Color(0.55, 0.2, 0.85, 0.15 if Settings.reduce_flashing else 0.45)
	_tint.create_tween().tween_property(_tint, "color:a", 0.0, 0.8)


# --- Winning -------------------------------------------------------------------------------------------------------

func _win() -> void:
	step = Step.GONE
	Game.message("His clock shatters! The Agent of Chaos is sent back out of time!")
	Dialogue.set_flag("beat_agent_of_chaos")
	Game.add_xp(200)
	Game.add_sparkles(20, "You beat the Agent of Chaos!")
	Juice.hitstop(0.12)
	Juice.shake(0.8)
	Juice.rumble(0.9, 0.6, 0.9)
	var parent := giant.get_parent()
	for i in 4:
		Fx.burst(parent, heart_position() + Vector3(randf_range(-2, 2), randf_range(-2, 3), randf_range(-2, 2)),
			[Color(0.75, 0.3, 1.0), Color(1.0, 0.8, 0.3), Color(0.4, 1.0, 0.9), Color(1.0, 0.4, 0.6)][i], 24, 0.2,
			5.0, -1.0, 1.2)
	stop(true)
	step = Step.GONE
	var model := giant.get_node_or_null("Model") as Node3D
	var body := giant.get_node_or_null("Body") as CollisionObject3D
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED
	_heart.process_mode = Node.PROCESS_MODE_DISABLED
	if model:
		var start := model.scale
		var tw := giant.create_tween()
		tw.tween_property(model, "scale", start * 1.08, 0.3)
		tw.tween_property(model, "scale", Vector3(start.x * 0.02, start.y * 1.4, start.z * 0.02), 1.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			giant.visible = false
			giant.remove_from_group("map_landmarks"))
	won.emit()


# --- Bits ----------------------------------------------------------------------------------------------------------

func _make_heart() -> void:
	# What bubbles hit on his chest: a sphere round the clock, and a glow shown while it can be popped
	_heart = StaticBody3D.new()
	_heart.name = "ChaosClock"
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = HEART_RADIUS
	cs.shape = ss
	_heart.add_child(cs)
	giant.add_child.call_deferred(_heart)
	_heart.position = Vector3(0, HEART_Y, HEART_FORWARD)
	_glow = MeshInstance3D.new()
	_glow.name = "ClockGlow"
	var sm := SphereMesh.new()
	sm.radius = HEART_RADIUS * 0.8
	sm.height = HEART_RADIUS * 1.6
	_glow.mesh = sm
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.35)
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	_heart.add_child(_glow)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(1.0, 0.8, 0.35)
	_glow_light.light_energy = 4.0
	_glow_light.omni_range = 8.0
	_glow_light.visible = false
	_heart.add_child(_glow_light)


func _animate_glow(delta: float) -> void:
	if not _glow.visible:
		return
	var spin := step == Step.WIND
	_glow.rotation.z += delta * (-9.0 if spin else 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / (90.0 if spin else 200.0))
	_glow_mat.albedo_color = (Color(0.5, 1.0, 0.95) if spin else Color(1.0, 0.85, 0.35))
	_glow_mat.albedo_color.a = 0.25 + 0.25 * pulse
	_glow.scale = Vector3.ONE * (1.0 + 0.12 * pulse)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _ground(at: Vector3) -> Vector3:
	# The ground under a spot: only the town's own static ground counts (not him, the player, minions or saucers)
	var space := giant.get_world_3d().direct_space_state
	var from := Vector3(at.x, at.y + 6.0, at.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0)
	var hit := space.intersect_ray(q)
	while hit and (not (hit.collider is StaticBody3D) or hit.collider is AnimatableBody3D or hit.collider == _heart):
		q.exclude = q.exclude + [(hit.collider as CollisionObject3D).get_rid()]
		hit = space.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, giant.global_position.y, at.z)
