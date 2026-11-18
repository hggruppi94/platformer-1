extends SportGame

# Tennis Rally (scripts/sports.gd), on the Void's Tennis Court with Volley: Volley hits the ball over the net and a
# glowing ring shows where it'll bounce on your side. Get to the ring: when the ball comes down by you, you swing and
# hit it back by yourself (no buttons, so the littlest players can rally). Volley always gets it back, a little
# quicker each time. Miss one and that ball's gone; three balls, and the score is how many you hit back in all.

const BALLS := 3
const MOST := 30                                 # hit this many and the game's won outright
const HIT_R := 1.7                               # the ball this close (sideways) and low enough: you hit it
const START_SPEED := 1.6                         # seconds for the ball to cross to you at first...
const FASTEST := 0.95                            # ...and at the quickest
const RIVAL_X := -9.0

var hits := 0
var balls := BALLS
var phase := "wait"                              # wait, to_you, after (bounced, coming up to you), to_them
var speed := START_SPEED
var rng := RandomNumberGenerator.new()
var b: Node3D
var marker: MeshInstance3D
var racket: Node3D
var landing := Vector3.ZERO                      # where the ball bounces on your side, in the court's space

var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _h := 0.0
var _dur := 1.0
var _wait := 0.0
var _rival_from := Vector3.ZERO
var _swing := 0.0


func setup() -> void:
	rng.randomize()
	if Game.riding:
		Game.riding = false                      # (on foot, racket in hand)
		Game.equipment_changed.emit()
	b = ball(Color(0.85, 1.0, 0.3), 0.11, Color(1, 1, 1))
	marker = ring(Color(0.5, 1.0, 1.0), 0.75)
	marker.visible = false
	racket = Node3D.new()
	racket.name = "Racket"
	add_child(racket)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.025
	handle.bottom_radius = 0.025
	handle.height = 0.3
	mesh_on(racket, handle, Vector3(0, 0.15, 0), mat(Color(0.35, 0.22, 0.4)))
	var head := TorusMesh.new()
	head.inner_radius = 0.15
	head.outer_radius = 0.19
	var hm := mesh_on(racket, head, Vector3(0, 0.48, 0), mat(Color(1.0, 0.45, 0.7), 0.3))
	hm.rotation.x = PI / 2.0
	var strings := CylinderMesh.new()
	strings.top_radius = 0.155
	strings.bottom_radius = 0.155
	strings.height = 0.01
	var sm := mesh_on(racket, strings, Vector3(0, 0.48, 0), mat(Color(1, 1, 1, 0.6)))
	sm.rotation.x = PI / 2.0
	place_hero(Vector3(8.0, 0.6, 0.0), Vector3(-8.0, 0, 0))
	send_host(to_global(Vector3(RIVAL_X, 0.25, 0)), to_global(Vector3(8, 0, 0)))
	b.global_position = _rival_hand()


func go() -> void:
	sports.show_meter(false)
	sports.shout("Stand in the ring!", Color(0.5, 1.0, 1.0), 0.8)
	_wait = 0.4


func _rival_hand() -> Vector3:
	return (host.global_position if is_instance_valid(host) else to_global(Vector3(RIVAL_X, 0, 0))) + Vector3(0.3, 1.2, 0)


func _serve() -> void:
	# Volley hits it over to a spot on your side; the ring shows where it'll bounce
	landing = Vector3(rng.randf_range(3.5, 9.5), 0.26, rng.randf_range(-4.0, 4.0))
	_start(_rival_hand(), to_global(landing), 2.4, speed, "to_you")
	marker.position = landing + Vector3(0, 0.01, 0)
	marker.visible = true
	Juice.blip("pop", 1.3, -6.0)


func tick(delta: float) -> void:
	super.tick(delta)
	_swing = maxf(0.0, _swing - delta * 4.0)
	_hold_racket()
	match phase:
		"wait":
			_wait -= delta
			if _wait <= 0.0:
				_serve()
		"to_you":
			var done := _fly(delta)
			if _t > 0.75 and _can_hit():
				hit()
			elif done:
				# Bounce, and on up past where you should be standing
				marker.visible = false
				Juice.blip("thud", 1.5, -10.0)
				var on := to_global(landing)
				var dir := (on - _from)
				dir.y = 0.0
				_start(on, on + dir.normalized() * 3.2 + Vector3(0, 0.2, 0), 1.1, 0.8, "after")
		"after":
			var done2 := _fly(delta)
			if _can_hit():
				hit()
			elif done2:
				_missed()
		"to_them":
			_fly(delta)
			if is_instance_valid(host):                      # Volley runs to where it'll land
				var spot := _to + (to_global(Vector3(-0.8, 0, 0)) - to_global(Vector3.ZERO))
				spot.y = _rival_from.y
				host.global_position = _rival_from.lerp(spot, minf(1.0, _t * 1.2))
				SportGame.face(host, p.global_position)
			if _t >= 1.0:
				Juice.blip("thud", 1.2, -12.0)
				_serve()


func _can_hit() -> bool:
	var d := Vector2(b.global_position.x - p.global_position.x, b.global_position.z - p.global_position.z).length()
	return d <= HIT_R and b.global_position.y - p.global_position.y < 2.6


func hit() -> void:
	# You swing and it goes back over the net to Volley
	hits += 1
	_swing = 1.0
	marker.visible = false
	sports.shout(str(hits), Color(0.5, 1.0, 0.6), 0.35)
	Juice.blip("pop", 0.9 + minf(hits, 12) * 0.04, -2.0)
	if hits >= MOST:
		phase = "done"
		sports.over(hits, "CHAMPION RALLY!")
		return
	speed = maxf(FASTEST, speed * 0.95)
	var back := Vector3(rng.randf_range(-10.0, -4.0), 0.26, rng.randf_range(-4.0, 4.0))
	if is_instance_valid(host):
		_rival_from = host.global_position
	_start(b.global_position, to_global(back), 2.2, speed * 0.9, "to_them")


func _missed() -> void:
	balls -= 1
	sports.shout("Missed!", Color(1.0, 0.6, 0.6), 0.6)
	Juice.blip("boink", 0.8, -6.0)
	if balls <= 0:
		phase = "done"
		sports.over(hits, "GAME!")
		return
	phase = "wait"
	_wait = 1.3
	speed = maxf(FASTEST, speed * 1.04)
	if is_instance_valid(host):
		b.global_position = _rival_hand()


func _hold_racket() -> void:
	# In her right hand, swung round as she hits
	var visual := p.get_node_or_null("Visual") as Node3D
	var basis := visual.global_basis if visual else Basis()
	var right := -basis.x.normalized()
	racket.global_position = p.global_position + right * 0.45 + Vector3(0, 0.65, 0)
	racket.global_basis = basis.rotated(basis.z.normalized(), -0.5 - _swing * 1.6)


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
	return _t >= 1.0


func status() -> Array:
	return ["Balls " + "●".repeat(maxi(balls, 0)) + "○".repeat(BALLS - maxi(balls, 0)), "Hits %d" % hits]
