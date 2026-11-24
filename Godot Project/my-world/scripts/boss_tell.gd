extends Node3D

# A boss's warning before it attacks, so every fight can be learnt. Nothing is drawn on the ground or over the boss
# (Hayden, 21 Nov 2026: "We dont need visual cues like arrows or circles"): the boss's own body winds up, with a sound
# of its own, and the same wind-up always means the same thing, in every fight:
#
#   "jump"  it squashes down low and shivers: a shockwave's coming, jump it.
#   "dash"  it rears back, leaning away, and scrapes up dust: it's about to charge, step out of the way.
#   "drop"  it stretches up tall, and whatever it's dropping is already up there, glinting and falling where it'll
#           land: move away from under it.
#   "pull"  it puffs up, breathing in: it's about to suck you in, jump to break free.
#   "throw" it rears back and swells: something's about to fly at you, step aside (scripts/boss_moves.gd).
#   "beam"  it rears up looking at the sky, wings spread: light's about to come down, step out from under the threads
#           of light (the Seraph, scripts/starhorn.gd: the threads are its own, coming down from the clouds).
#   "blink" it shrinks and flickers: it's about to vanish and pop up somewhere else (scripts/boss_moves.gd).
#
# The tell only ever starts EARLIER than the attack; it never changes when the attack comes, so a fight's timing and
# its tests are just as before. Settings > Assist > Early boss warnings makes the wind-ups longer (lead()).
#
# The wind-up works on the boss's "Visual" node on top of whatever the boss's own script does with it: each frame it
# takes the Visual's scale, pitch and place as the boss left them, and adds its own squash, lean and shiver.
#
# No class_name (tools run with --script compile class_name scripts before the autoloads exist): preload it.
#
#   const TELL := preload("res://scripts/boss_tell.gd")
#   TELL.warn(self, "jump", reach, colour, secs, {"visual": visual})

const NORMAL := 0.9           # seconds of warning before an attack
const EARLY := 1.6            # with Early boss warnings on
const DROP_FROM := 16.0       # how high over its landing spot a dropped thing first shows
const HINTS := {
	"jump": "Squashing down? Jump!",
	"dash": "Leaning back? Step aside!",
	"drop": "Something falling? Move away!",
	"pull": "Puffing up? Jump free!",
	"throw": "Rearing back? Dodge what it throws!",
	"blink": "Flickering? It's about to vanish!",
	"beam": "Light coming down? Step out from under it!",
}
# What each wind-up does to the body at its fullest: squash (scale y), widen (scale x and z), lean back (radians)
const POSES := {
	"jump": {"squash": 0.72, "widen": 1.16, "lean": 0.0, "shiver": 0.05},
	"dash": {"squash": 0.92, "widen": 1.04, "lean": 0.28, "shiver": 0.02},
	"drop": {"squash": 1.14, "widen": 0.94, "lean": 0.12, "shiver": 0.0},
	"pull": {"squash": 1.18, "widen": 1.2, "lean": 0.0, "shiver": 0.015},
	"throw": {"squash": 1.08, "widen": 1.1, "lean": 0.22, "shiver": 0.03},
	"blink": {"squash": 0.8, "widen": 0.8, "lean": 0.0, "shiver": 0.08},
	"beam": {"squash": 1.1, "widen": 1.06, "lean": 0.3, "shiver": 0.02},
}
const SOUNDS := {"jump": 0.7, "dash": 1.0, "drop": 1.3, "pull": 0.85, "throw": 1.15, "blink": 1.6, "beam": 1.45}   # the wind-up sound's pitch for each

var kind := "jump"
var reach := 6.0
var colour := Color(1, 1, 1)
var secs := NORMAL
var follow: Node3D            # where the dropped thing falls to keeps under this (x and z) while the warning lasts
var ground_y := NAN           # where the ground is; NAN: follow's own height
var dir := Vector3.FORWARD    # "dash": which way
var visual: Node3D            # what winds up
var head := 3.0               # kept for callers that pass it (the old "!" height); unused now
var _t := 0.0
var _dust_t := 0.0
var _falling: Node3D          # "drop": the thing on its way down
var _base_scale := Vector3.ONE
var _base_pitch := 0.0
var _base_pos := Vector3.ZERO
var _left_scale := Vector3(NAN, NAN, NAN)  # what we left on the Visual last frame, to see whether the boss changed it
var _left_pitch := NAN
var _left_pos := Vector3(NAN, NAN, NAN)


static func lead() -> float:
	return EARLY if bool(Settings.get("boss_warn_early")) else NORMAL


static func warn(boss: Node3D, what: String, reach_m: float, col: Color, length := -1.0, opts := {}) -> Node3D:
	if boss == null or not boss.is_inside_tree():
		return null
	var t: Node3D = (load("res://scripts/boss_tell.gd") as GDScript).new()
	t.name = "BossTell"
	t.kind = what
	t.reach = reach_m
	t.colour = col
	t.secs = length if length > 0.0 else lead()
	t.follow = opts.get("follow", boss)
	t.ground_y = float(opts.get("ground_y", NAN))
	t.dir = opts.get("dir", -boss.global_basis.z)
	t.visual = opts.get("visual", boss.get_node_or_null("Visual"))
	t.head = float(opts.get("head", 3.0))
	var parent := boss.get_parent() if boss.get_parent() else boss
	parent.add_child(t)
	t.global_position = opts.get("at", t._ground_spot())
	if opts.has("at"):
		t.follow = null
	boss.set_meta("boss_tell", t)
	return t


static func showing(boss: Node) -> bool:
	if boss == null or not boss.has_meta("boss_tell"):
		return false
	var t: Variant = boss.get_meta("boss_tell")
	if not is_instance_valid(t):                  # (check before "is": a freed one can't be asked what it is)
		return false
	return t is Node and (t as Node).is_inside_tree()


func _ground_spot() -> Vector3:
	var at := follow.global_position if follow else global_position
	return Vector3(at.x, (at.y if is_nan(ground_y) else ground_y) + 0.06, at.z)


func _ready() -> void:
	add_to_group("boss_tells")
	if visual and not is_instance_valid(visual):
		visual = null
	if kind == "drop":
		_build_falling()
	Juice.blip("windup", float(SOUNDS.get(kind, 1.0)) * (1.0 if secs <= NORMAL + 0.05 else 0.85), -4.0)
	if kind == "pull":
		Juice.blip("whoosh", 0.55, -6.0)                           # a long breath in
	if HINTS.has(kind) and not Dialogue.flags.has("tell_seen_" + kind):
		Dialogue.flags["tell_seen_" + kind] = true                 # the first time each wind-up's seen, say what to do
		Game.message(HINTS[kind])


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / secs, 0.0, 1.0)
	if follow and is_instance_valid(follow):
		global_position = _ground_spot()
	_wind_up(k)
	if kind == "dash":
		_dust_t -= delta
		if _dust_t <= 0.0 and visual and is_instance_valid(visual):
			_dust_t = 0.3                                          # scraping a foot: dust kicked up behind it
			var at := visual.global_position - Vector3(dir.x, 0, dir.z).normalized() * 0.8
			Juice.dust(get_parent(), Vector3(at.x, _ground_spot().y, at.z), 0.5)
			Juice.blip("thud", 1.4, -12.0)
	if _falling:
		# Up high at first and slow, faster as it comes down: it lands as the attack does
		var e := k * k
		_falling.global_position = global_position + Vector3(0, lerpf(DROP_FROM, 0.4, e), 0)
		_falling.rotate_y(delta * 3.0)
	if _t >= secs:
		_end()


func _wind_up(k: float) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	# Take what the boss itself left on its Visual this frame as the base (it may squash, bob or turn it each frame)
	if not visual.scale.is_equal_approx(_left_scale):
		_base_scale = visual.scale
	if is_nan(_left_pitch) or not is_equal_approx(visual.rotation.x, _left_pitch):
		_base_pitch = visual.rotation.x
	if not visual.position.is_equal_approx(_left_pos):
		_base_pos = visual.position
	var pose: Dictionary = POSES.get(kind, POSES["jump"])
	# Eases in over the first two thirds and holds, so it reads as a wind-up, not a wobble
	var e := smoothstep(0.0, 0.66, k)
	var sq := lerpf(1.0, float(pose.squash), e)
	var wd := lerpf(1.0, float(pose.widen), e)
	if kind == "pull":
		var breath := 1.0 + 0.04 * sin(_t * 9.0) * e
		sq *= breath
		wd *= breath
	visual.scale = Vector3(_base_scale.x * wd, _base_scale.y * sq, _base_scale.z * wd)
	visual.rotation.x = _base_pitch + float(pose.lean) * e
	var shake := float(pose.shiver) * e * (0.3 if Settings.reduce_motion else 1.0)
	var size := maxf(absf(_base_scale.y), 0.2)
	visual.position = _base_pos + Vector3(sin(_t * 61.0), 0, cos(_t * 53.0)) * shake * size
	_left_scale = visual.scale
	_left_pitch = visual.rotation.x
	_left_pos = visual.position


func _build_falling() -> void:
	# What's about to land, already up there: a glinting lump in the boss's colour
	_falling = Node3D.new()
	_falling.name = "Falling"
	add_child(_falling)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := clampf(reach * 0.35, 0.4, 1.4)
	sm.radius = r
	sm.height = r * 2.0
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 1.2
	ball.material_override = m
	_falling.add_child(ball)
	_falling.global_position = global_position + Vector3(0, DROP_FROM, 0)


func _put_back() -> void:
	# Leave the Visual as the boss had it (only if nothing else has changed it since we last did)
	if visual == null or not is_instance_valid(visual):
		return
	if visual.scale.is_equal_approx(_left_scale):
		visual.scale = _base_scale
	if not is_nan(_left_pitch) and is_equal_approx(visual.rotation.x, _left_pitch):
		visual.rotation.x = _base_pitch
	if visual.position.is_equal_approx(_left_pos):
		visual.position = _base_pos
	_left_scale = Vector3(NAN, NAN, NAN)


func _end() -> void:
	set_process(false)
	_put_back()
	queue_free()


func _exit_tree() -> void:
	_put_back()
