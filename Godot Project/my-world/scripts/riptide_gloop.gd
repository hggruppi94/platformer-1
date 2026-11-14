extends "res://scripts/gloop_king.gd"

# The Riptide Gloop, the Gloop King's seaside cousin and the Tide Reef's boss (plan item 19a world 5,
# scripts/tide_reef.gd). The same goo as the King, but sea-blue and foamy, with a crown of coral. It swallowed the whole
# tide and has been snoozing in the Deep Basin ever since, swollen with it. It wakes once the three Tide Pearls are
# found.
#
# It's far too slippery to pop: bubbles slide off and stomps just bounce. That's where Otto comes in (the friend who
# thought he was no use): every few seconds he wraps his arms round it and HOLDS it still (hold(), called by the
# world), and only then do bubbles and stomps count. Between holds it belly-flops a wave to jump, like the King, calls
# in little Splash Gloops, and now and then it sucks the water in: a riptide that drags you towards it while you're on
# the ground (jump to break free). Popping it lets the tide go: it tells the world, which mends (Portals.clear).
# Kid-safe like every Gloop: a normal bump, nothing more, and it doesn't count as popping the King.

const SEA := Color(0.3, 0.75, 0.95)
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


func _ready() -> void:
	title = "Riptide Gloop"
	ring_colour = SEA
	super()
	_sea(self)
	var crown := get_node_or_null("Visual/Body/Crown")
	if crown:
		_coral_crown(crown)


func _sea(n: Node) -> void:
	# Its goo, deep sea-blue swirled with white foam
	for m in _goo:
		m.set_shader_parameter("deep", Color(0.08, 0.25, 0.5))
		m.set_shader_parameter("green", Color(0.25, 0.7, 0.9))
		m.set_shader_parameter("gold", Color(0.9, 1.0, 1.0))
	var puddle := n.get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.3, 0.7, 0.95, 0.5)
		puddle.material_override = pm


func _coral_crown(crown: Node) -> void:
	# The King's gold crown and gem turned to pink coral
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(1.0, 0.5, 0.62)
	pink.roughness = 0.6
	pink.emission_enabled = true
	pink.emission = Color(1.0, 0.45, 0.6)
	pink.emission_energy_multiplier = 0.3
	for c in crown.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = pink
	if crown is MeshInstance3D:
		(crown as MeshInstance3D).material_override = pink


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
		return
	super(delta)
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
		if _pull_cd <= 0.0:
			start_pull()


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
	Game.message("The Riptide Gloop sloshes! %d more to pop it." % left if left > 1 else "One more and the Riptide Gloop pops!")


func _defeated() -> void:
	held = false
	pulling = false
	Game.message("Popped! The water rushes out...")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()
