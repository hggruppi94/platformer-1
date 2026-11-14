extends Node3D

# The Royal Court floods with slime (Hayden, 14 Nov 2026: "Can we add a mechanic where the arena fills with slime?").
# Built by the Gloop Kingdom (scripts/gloop_kingdom.gd) inside the Royal Court, as a child placed at the court's middle.
#
# Once the King's fight is on, every so often the goo-falls round the court gush: a warning first ("Get up high!"),
# then the court fills with his goo, sits full for a few seconds and drains away. While she stands in it she's slowed
# right down and every couple of seconds the goo gives her a bump (knocking her towards the nearest Royal Lily Pad).
# The way out is up: the gold-rimmed Lily Pads round the court and the throne's dais stick up out of the goo, so jump
# onto one and wait it out (or keep popping him from there). Each flood the goo also burps up a Gloop from his court.
# Under half his goo (when he's cross) the floods come more often. Popping him drains it for good.
# Kid-safe like the rest of him: bumps only, and the pads are never more than a few strides away.

enum State { DRY, WARN, RISE, FULL, DRAIN }

const DEPTH := 0.6                     # how deep the goo gets (her feet are 0.8 below her middle; the pads' tops are 1.0 up)
const FIRST := 10.0                    # seconds into the fight before the first flood
const EVERY := 20.0                    # seconds between floods (from one draining to the next warning)...
const EVERY_CROSS := 14.0              # ...and when he's cross
const WARN_TIME := 2.5
const RISE_TIME := 2.0
const FULL_TIME := 6.0
const DRAIN_TIME := 2.0
const STING_EVERY := 2.0               # in the goo, a bump this often (the first one a second after it's up)
const STING := 1
const FEET := 0.8
const PAD_TOP := 1.0
const PAD_RADIUS := 1.7
# The Lily Pads (angle in degrees round the court, distance from its middle). None on the throne's side (+z, the dais is
# the high ground there) or right in the way in from the gate (-z).
const PADS := [Vector2(10, 11.5), Vector2(50, 12.0), Vector2(130, 12.0), Vector2(170, 11.5), Vector2(215, 12.0),
	Vector2(325, 12.0), Vector2(200, 5.5), Vector2(340, 5.5)]

var radius := 19.0
var king: Node3D
var state := State.DRY
var level := 0.0                       # the goo's height above the court floor
var floods := 0
var pads: Array[Node3D] = []
var speed_scale := 0.5                 # read by the player while she's in it (enter_zone, like scripts/water.gd)
var gravity_scale := 1.0
var fall_cap := 1000.0
var kind := "water"

var _t := FIRST
var _sting := 0.0
var _inside := false
var _goo: MeshInstance3D
var _player: CharacterBody3D
var _running := false
var _told := false


func build(court_radius: float, goo: Material, gold: Material) -> void:
	radius = court_radius
	for k in PADS.size():
		var spot: Vector2 = PADS[k]
		var a := deg_to_rad(spot.x)
		var pad := StaticBody3D.new()
		pad.name = "Royal Lily Pad %d" % (k + 1)
		pad.position = Vector3(cos(a), 0, sin(a)) * spot.y
		add_child(pad)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = PAD_RADIUS
		shape.height = PAD_TOP
		cs.shape = shape
		cs.position.y = PAD_TOP / 2.0
		pad.add_child(cs)
		var stem := CylinderMesh.new()
		stem.top_radius = PAD_RADIUS
		stem.bottom_radius = PAD_RADIUS * 0.85
		stem.height = PAD_TOP
		_part(pad, stem, Vector3(0, PAD_TOP / 2.0, 0), goo)
		var rim := TorusMesh.new()
		rim.inner_radius = PAD_RADIUS - 0.12
		rim.outer_radius = PAD_RADIUS + 0.05
		_part(pad, rim, Vector3(0, PAD_TOP, 0), gold)
		pads.append(pad)
	# The goo itself: a glossy disc across the whole court, hidden until a flood
	_goo = MeshInstance3D.new()
	_goo.name = "Flood Goo"
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.2
	disc.bottom_radius = radius - 0.2
	disc.height = 0.06
	disc.radial_segments = 64
	_goo.mesh = disc
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.82, 0.18, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.25
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = Color(0.35, 0.6, 0.1)
	m.emission_energy_multiplier = 0.5
	_goo.material_override = m
	_goo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_goo.visible = false
	add_child(_goo)


func _part(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func start() -> void:
	# The fight's on: the first flood comes FIRST seconds from now
	_running = true
	_t = FIRST


func stop() -> void:
	# He's popped: whatever goo's in the court drains away, and no more floods
	_running = false
	if state != State.DRY:
		state = State.DRAIN
		_t = DRAIN_TIME * clampf(level / DEPTH, 0.0, 1.0)


func is_flooded() -> bool:
	return level > 0.15


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _running and king and (not is_instance_valid(king) or bool(king.get("defeated"))):
		stop()
	_step(delta)
	_goo.visible = level > 0.01
	_goo.position.y = level - 0.03
	_wade(delta)


func _step(delta: float) -> void:
	_t -= delta
	match state:
		State.DRY:
			if _running and _t <= 0.0:
				_warn()
		State.WARN:
			if _t <= 0.0:
				state = State.RISE
				_t = RISE_TIME
		State.RISE:
			level = DEPTH * clampf(1.0 - _t / RISE_TIME, 0.0, 1.0)
			if _t <= 0.0:
				state = State.FULL
				_t = FULL_TIME
				level = DEPTH
				_sting = 1.0
				if king and is_instance_valid(king) and king.has_method("_call_court"):
					king.call("_call_court", 1)             # the goo burps up one of his court
		State.FULL:
			if _t <= 0.0:
				state = State.DRAIN
				_t = DRAIN_TIME
		State.DRAIN:
			level = DEPTH * clampf(_t / DRAIN_TIME, 0.0, 1.0)
			if _t <= 0.0:
				level = 0.0
				state = State.DRY
				var cross := king != null and is_instance_valid(king) and bool(king.get("_cross"))
				_t = EVERY_CROSS if cross else EVERY


func _warn() -> void:
	state = State.WARN
	_t = WARN_TIME
	floods += 1
	Game.message("Goo flood! Jump on a Lily Pad!" if floods == 1 else "Goo flood! Get up high!")
	_told = false
	Audio.play_at("gloop_giggle", global_position, 4.0, -0.3)
	Juice.shake(0.25)
	Juice.rumble(0.3, 0.2, 0.4)
	for k in 10:
		var a := TAU * k / 10.0
		Fx.burst(get_parent(), global_position + Vector3(cos(a), 2.5, sin(a)) * Vector3(radius - 0.5, 1.0, radius - 0.5),
			Color(0.6, 0.9, 0.25), 6, 0.12, 3.0, -6.0, 0.8)


func _wade(delta: float) -> void:
	if _player == null:
		return
	var p := _player.global_position
	var flat := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var wet := is_flooded() and flat < radius and p.y - FEET < global_position.y + level
	if wet != _inside:
		_inside = wet
		if wet:
			_player.call("enter_zone", self)
			Audio.play_at("splash", p, -4.0)
		else:
			_player.call("exit_zone", self)
	if not wet or state != State.FULL:
		return
	_sting -= delta
	if _sting <= 0.0:
		_sting = STING_EVERY
		if _player.has_method("is_invulnerable") and not _player.call("is_invulnerable"):
			# The bump sends her towards the nearest pad (from the far side of her)
			var to := nearest_pad(p) - p
			to.y = 0.0
			_player.call("hurt", STING, p - to.normalized())
			if not _told:                              # (once a flood: the warning's already said where to go)
				_told = true
				Game.message("Sticky! Get on a pad!")


func nearest_pad(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var d := INF
	for pad in pads:
		var at := pad.global_position + Vector3(0, PAD_TOP, 0)
		var dd := Vector2(at.x - from.x, at.z - from.z).length()
		if dd < d:
			d = dd
			best = at
	return best


func _exit_tree() -> void:
	if _inside and _player and is_instance_valid(_player):
		_player.call("exit_zone", self)
