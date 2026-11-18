extends SportGame

# Hoop Shoot (scripts/sports.gd), on the Void's Basketball Court with Coach Swish: one minute to score as many points
# as you can. You carry the ball over your head and can walk or ride anywhere on the court. A meter slides along the
# bottom of the screen; press Interact while the needle's in the green and the ball goes in (the nearer hoop: its
# green gets narrower the further out you are). 2 points, 3 from past the far line (THREE m from the hoop). On your
# ride (plan item 25's skateboard basketball): shooting in the air is x2, and mid-trick (a flip or a grab) x3. The
# ball always comes back to you by itself, so there's no chasing it.

const TIME := 60.0
const RIMS := [Vector3(12.45, 3.0, 0.0), Vector3(-12.45, 3.0, 0.0)]   # the rims' middles (tools/build_town.gd court())
const THREE := 7.0                         # this far from the hoop or further: 3 points
const REACH := 13.0                        # further than this and it's "Too far!"
const SWING := 0.75                        # the meter's needle goes up and back this many times a second
const CENTRE := 0.7                        # the middle of the green
const COURT := Vector2(15.5, 9.0)          # half the court's size with its edge (on it, you can shoot)

var score := 0
var left := TIME
var shots := 0
var made := 0
var meter := 0.0
var b: Node3D                              # the ball
var phase := "held"                        # held, shot, drop (through the net), bounce (off the rim), back (to you)
var last_points := 0
var last_mult := 1                         # 1 on your feet, 2 in the air on your ride, 3 mid-trick

var _t := 0.0
var _dur := 1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _h := 1.0
var _will := false
var _rim := Vector3.ZERO


func setup() -> void:
	b = ball(Color(1.0, 0.5, 0.18), 0.14, Color(0.25, 0.12, 0.08))
	place_hero(Vector3(5.0, 0.6, 2.5), RIMS[0])
	send_host(to_global(Vector3(0, 0.25, 8.2)), to_global(Vector3.ZERO))
	b.global_position = hand()


func go() -> void:
	sports.show_meter(true, "%s: shoot!" % Settings.prompt("interact"))


func hand() -> Vector3:
	return p.global_position + Vector3(0, 2.0 + sin(time * 6.0) * 0.06, 0)


func nearest_rim() -> Vector3:
	var a := to_global(RIMS[0])
	var c := to_global(RIMS[1])
	return a if _flat(a, p.global_position) <= _flat(c, p.global_position) else c


func half_zone(dist: float) -> float:
	# Half the green's width: wide up close, narrow far out
	return lerpf(0.17, 0.08, clampf((dist - 2.0) / 9.0, 0.0, 1.0))


func on_court() -> bool:
	var l := to_local(p.global_position)
	return absf(l.x) <= COURT.x and absf(l.z) <= COURT.y


func tick(delta: float) -> void:
	super.tick(delta)
	left = maxf(0.0, left - delta)
	meter = pingpong(time * SWING * 2.0, 1.0)
	var hw := half_zone(_flat(nearest_rim(), p.global_position))
	sports.set_meter(meter, CENTRE - hw, CENTRE + hw)
	match phase:
		"held":
			b.global_position = hand()
		"shot":
			if _fly(delta):
				if _will:
					_score()
					_start(b.global_position, _rim - Vector3(0, 2.75, 0), 0.0, 0.45, "drop")
				else:
					Juice.blip("clink", 0.9, -4.0)
					sports.shout("Clang!", Color(1.0, 0.6, 0.6), 0.4)
					var out := (b.global_position - _rim)
					out.y = 0.0
					out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
					_start(b.global_position, _rim + out * 2.2 - Vector3(0, 2.75, 0), 1.0, 0.6, "bounce")
		"drop", "bounce":
			if _fly(delta):
				Juice.blip("thud", 1.3, -10.0)
				_start(b.global_position, hand(), 1.6, 0.6, "back")
		"back":
			_to = hand()
			if _fly(delta):
				phase = "held"
	if left <= 0.0 and (phase == "held" or phase == "back"):
		sports.over(score, "TIME!")


func action() -> void:
	if phase != "held" or left <= 0.0:
		return
	if not on_court():
		sports.shout("Get on the court!", Color(1.0, 0.7, 0.5), 0.6)
		return
	var dist := _flat(nearest_rim(), p.global_position)
	if dist > REACH:
		sports.shout("Too far!", Color(1.0, 0.7, 0.5), 0.6)
		return
	shoot(absf(meter - CENTRE) <= half_zone(dist))


func shoot(good: bool) -> void:
	# Let the ball go at the nearer hoop: in if good, off the rim if not
	_rim = nearest_rim()
	var dist := _flat(_rim, p.global_position)
	var mult := 1
	var s = p.get("skate")
	if Game.riding and s != null and is_instance_valid(s) and int(s.state) == Skate.State.AIR:
		mult = 2
		var tr = s.tricks
		if tr != null and (tr.flipping() or not (tr.grab as Dictionary).is_empty()):
			mult = 3
	last_mult = mult
	last_points = (3 if dist >= THREE else 2) * mult
	_will = good
	shots += 1
	var to := _rim + Vector3(0, 0.12, 0)
	if not good:
		var side := (p.global_position - _rim)
		side.y = 0.0
		to = _rim + side.normalized() * 0.3 + Vector3(0, 0.05, 0)    # the near side of the rim
	_start(b.global_position, to, 1.6 + dist * 0.12, 0.8 + dist * 0.035, "shot")
	Juice.blip("whoosh", 1.4, -10.0)


func _score() -> void:
	made += 1
	score += last_points
	var words: String = ["SWISH!", "AIR SHOT!", "TRICK SHOT!"][last_mult - 1] + " +%d" % last_points
	sports.shout(words, Color(0.5, 1.0, 0.6), 0.6)
	Juice.blip("chime", 1.0 + minf(made, 8) * 0.05)
	Juice.burst(self, _rim, Color(1.0, 0.85, 0.3), 14, 0.08, 2.5, 0.6)


func _start(from: Vector3, to: Vector3, h: float, dur: float, next: String) -> void:
	_from = from
	_to = to
	_h = h
	_dur = dur
	_t = 0.0
	phase = next


func _fly(delta: float) -> bool:
	_t += delta / _dur
	b.global_position = SportGame.arc(_from, _to, _h, _t)
	b.rotation.x += delta * 9.0
	return _t >= 1.0


func status() -> Array:
	var s := ceili(left)
	return ["%d:%02d" % [s / 60, s % 60], "Score %d" % score]


static func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()
