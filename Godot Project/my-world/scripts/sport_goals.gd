extends SportGame

# Goal Kicks (scripts/sports.gd), on the Void's Soccer Field against Bonk the goalie: five kicks at the east goal from
# the spot. A glowing target slides back and forth across the goal; press Interact and the ball flies at it. Bonk
# waits a moment, then dives after it along the goal line (the way nicolasbize/soccer-course's goalie steers to the
# ball, clamped between its posts), so a kick near the middle is caught and one near a post goes in. Now and then
# Bonk guesses the wrong way. Each kick the target slides a little quicker.

const KICKS := 5
const SPOT := Vector3(6.6, 0.47, 0.0)          # the penalty spot (the goal line's at x 15.6: tools/build_town.gd)
const LINE := 15.6
const POSTS := 2.75                            # the target slides between these (the posts are at +-3)
const GOALIE_X := 15.0
const REACT := 0.22                            # Bonk's moment before diving
const DIVE := 2.6                              # how fast Bonk gets along the line
const REACH := 0.95                            # a ball this close to Bonk's middle is caught
const FLIGHT := 0.75

var kick := 0                                  # kicks taken
var goals := 0
var phase := "aim"                             # aim, fly, wait
var aim := 0.0                                 # where the target is across the goal
var guess_wrong := 0.25                        # how often Bonk dives the wrong way (tests set 0)
var rng := RandomNumberGenerator.new()
var b: Node3D
var target: MeshInstance3D
var last := ""                                 # "goal" or "saved"

var _aim_t := 0.0
var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _h := 0.0
var _dur := 1.0
var _shot_z := 0.0
var _keeper_z := 0.0
var _keeper_to := 0.0
var _wait := 0.0
var _base := Basis()


func setup() -> void:
	hold = true
	rng.randomize()
	if Game.riding:
		Game.riding = false                    # (kicks are on foot)
		Game.equipment_changed.emit()
	b = ball(Color(0.97, 0.97, 1.0), 0.22, Color(0.2, 0.15, 0.35))
	target = ring(Color(1.0, 0.85, 0.3), 0.45)
	target.rotation = Vector3(0, 0, PI / 2.0)  # standing up, facing down the field
	place_hero(SPOT + Vector3(-1.6, 0.2, 0), Vector3(LINE, 0, 0))
	send_host(to_global(Vector3(GOALIE_X, 0.25, 0)), to_global(SPOT))
	if is_instance_valid(host):
		_base = host.global_basis
	_reset_kick()


func go() -> void:
	sports.show_meter(false)
	sports.shout("%s: kick!" % Settings.prompt("interact"), Color(1.0, 0.85, 0.3), 0.8)


func _reset_kick() -> void:
	phase = "aim"
	_aim_t = rng.randf() * TAU
	b.position = SPOT
	_keeper_z = 0.0
	_move_keeper(0.0)
	target.visible = true


func tick(delta: float) -> void:
	super.tick(delta)
	match phase:
		"aim":
			_aim_t += delta * (1.7 + kick * 0.18)
			aim = sin(_aim_t) * POSTS
			target.position = Vector3(LINE + 0.05, 1.05, aim)
			_move_keeper(sin(time * 2.0) * 0.25)                # Bonk bobs about on the line
		"fly":
			_t += delta / _dur
			b.position = SportGame.arc(_from, _to, _h, _t)
			b.rotation.z -= delta * 14.0
			if _t * _dur > REACT:                               # then dives after it
				var step := DIVE * delta
				_keeper_z = move_toward(_keeper_z, _keeper_to, step)
			_move_keeper(clampf((_keeper_to - _keeper_z) * -0.5, -0.9, 0.9) if absf(_keeper_to - _keeper_z) > 0.05 else _lean_at())
			if _t >= 1.0:
				_arrive()
		"wait":
			_wait -= delta
			if last == "goal":
				_t += delta / 0.4
				b.position = SportGame.arc(_from, _to, 0.1, _t)
			else:
				_t += delta / 0.7
				b.position = SportGame.arc(_from, _to, 1.2, _t)
			if _wait <= 0.0:
				if kick >= KICKS:
					sports.over(goals, "FULL TIME!")
				else:
					_reset_kick()


func action() -> void:
	if phase == "aim":
		kick_at(aim)


func kick_at(z: float) -> void:
	# Kick the ball at a spot across the goal (z, from post to post)
	_shot_z = clampf(z, -POSTS, POSTS)
	_from = b.position
	_to = Vector3(LINE + 0.3, 0.75 + absf(_shot_z) * 0.12, _shot_z)
	_h = 0.7
	_dur = FLIGHT
	_t = 0.0
	phase = "fly"
	target.visible = false
	kick += 1
	_keeper_to = clampf(_shot_z, -POSTS + 0.4, POSTS - 0.4)
	if rng.randf() < guess_wrong:
		_keeper_to = -signf(_shot_z if absf(_shot_z) > 0.1 else 1.0) * 1.4   # dives the wrong way
	Juice.blip("thud", 0.9, -4.0)
	Juice.dust(self, to_global(SPOT), 0.4)


func _arrive() -> void:
	var saved := absf(_keeper_z - _shot_z) <= REACH
	last = "saved" if saved else "goal"
	_from = b.position
	_t = 0.0
	if saved:
		_to = Vector3(LINE - 4.5, 0.25, _shot_z * 0.4)                 # punched back out
		sports.shout("SAVED!", Color(1.0, 0.6, 0.6), 0.6)
		Juice.blip("boink", 1.0, -4.0)
	else:
		goals += 1
		_to = Vector3(LINE + 1.0, 0.3, _shot_z)                        # into the net
		sports.shout("GOAL!", Color(0.5, 1.0, 0.6), 0.8)
		Juice.blip("chime")
		Juice.burst(self, to_global(Vector3(LINE + 0.8, 1.2, _shot_z)), Color(0.5, 1.0, 0.6), 18, 0.09, 3.0, 0.7)
		Juice.shake(0.12)
	phase = "wait"
	_wait = 1.6


func _lean_at() -> float:
	return 0.0


func _move_keeper(lean: float) -> void:
	if not is_instance_valid(host):
		return
	host.global_position = to_global(Vector3(GOALIE_X, 0.25 + absf(lean) * 0.25, _keeper_z))
	var axis := (to_global(Vector3(-1, 0, 0)) - to_global(Vector3.ZERO)).normalized()
	host.global_basis = _base.rotated(axis, lean)


func status() -> Array:
	return ["Kick %d of %d" % [mini(kick + (1 if phase == "aim" else 0), KICKS), KICKS], "Goals %d" % goals]
