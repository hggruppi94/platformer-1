extends Node

# Bramble's burrow, the player's own: the Rootmind's reward (scripts/rootmind.gd). Bramble teaches it once the
# Rootmind is mended, and not a moment before (Hayden: "it needs to be locked until completion of the world"), so
# until Portals.is_cleared("rootmind") pressing Burrow does nothing at all and the Controls list doesn't show it
# (Settings.action_shown()).
#
# Since the party system (plan item 26, scripts/party.gd) it has no button of its own: with Bramble walking with you,
# the Friend button (Z, RB) does it.
#
# On soft ground (the Void's grass, Stars Hollow's ground, the Rootmind's moss: soil()) press Burrow and the hero
# dives in with a puff of soil. Underground they're out of sight, nothing can hurt them, and a little mound with a
# sprig (the same one Bramble's own burrowing shows, scripts/burrower.gd) races along where they are, a bit faster
# than running. Press Friend again or Jump and they sprout back up with a springy hop (Jump's is the bigger one).
# Running onto anything that isn't soil (a path, a boardwalk, water) or off a ledge pops them up by themselves, and
# so does talking to someone, getting on a ride or a door.
#
# Made by the player (scenes/player/player.gd _ready), which hands its physics over to physics() while active.

const BURROWER := preload("res://scripts/burrower.gd")
const WORLD := "rootmind"                 # the world whose mending unlocks it
const SPEED := 1.45                       # times her running speed, underground
const ACCEL := 30.0
const HOP := 1.2                          # times her jump: sprouting up with Jump
const POP := 0.6                          # ...and just popping up (Burrow again, or the ground runs out)
const AIR_GRACE := 0.15                   # seconds off the ground before she's popped out (off a ledge, not a bump)
const TRAIL_EVERY := 0.22                 # seconds between little soil puffs behind the mound
const SOIL := Color(0.36, 0.24, 0.16)

var player: CharacterBody3D
var active := false
var floor_node: Node                      # what she's tunnelling through
var _mound: Node3D
var _air := 0.0
var _trail := 0.0
var _under_for := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p
	_mound = BURROWER.make_mound()
	_mound.visible = false
	player.add_child(_mound)
	_mound.position.y = -0.8                 # the capsule's foot: the hump sits on the ground


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


static func soil(node: Node) -> bool:
	# Soft ground she can dig into: the Void's terrain (Surfaces says "grass"), Stars Hollow's ground (EarthLand) and
	# anything a world puts in the "soil" group (the Rootmind's mossy floor). Not paving, wood, crystal or clouds.
	if node == null:
		return false
	if node.is_in_group("soil") or node is EarthLand:
		return true
	return Surfaces.kind_of(node) == "grass"


func can_start() -> bool:
	if active or not unlocked() or player == null:
		return false
	if Game.riding or player.carried or player.input_locked or not player.is_on_floor():
		return false
	if player.popper and player.popper.aiming:
		return false
	var kind: String = player.ground_kind()
	if kind == "water" or kind == "cloud":
		return false
	return soil(player._floor_node)


func try_start() -> bool:
	# Called by the player each frame when Burrow is pressed on foot
	if not can_start():
		return false
	start()
	return true


func start() -> void:
	active = true
	floor_node = player._floor_node
	_air = 0.0
	_trail = 0.0
	_under_for = 0.0
	player.visual.visible = false
	_mound.visible = true
	_mound.scale = Vector3.ONE * 0.2
	var tw := _mound.create_tween()
	tw.tween_property(_mound, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_puff(0.7)
	Juice.blip("thud", 0.8, -6.0)
	Juice.rumble(0.2, 0.1, 0.12)
	velocity_flat(0.6)


func stop(hop := POP) -> void:
	# Sprout back up, with a hop (0 for none: a door, a ride, a cutscene)
	if not active:
		return
	active = false
	_mound.visible = false
	player.visual.visible = true
	if hop > 0.0:
		player.velocity.y = player.jump_velocity * hop
		_puff(0.8)
		Juice.blip("pop", 0.9, -4.0)
		Juice.squash(player.visual, 0.25)
	Juice.rumble(0.15, 0.1, 0.1)


func velocity_flat(keep: float) -> void:
	player.velocity.x *= keep
	player.velocity.z *= keep


func physics(delta: float) -> void:
	# Her physics while she's under. The player calls this instead of its own walking.
	_under_for += delta
	if Game.riding or player.carried:
		stop(0.0)
		return
	if player.input_locked:                   # someone's talking to her: up she comes to listen
		stop(POP * 0.5)
		return
	if _under_for > 0.1:
		if Input.is_action_just_pressed("jump"):
			stop(HOP)
			return
		if Input.is_action_just_pressed("friend"):         # Bramble's move again: up you come (scripts/party.gd)
			stop(POP)
			return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis: Basis = player.spring_arm.global_transform.basis
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * input_dir.x - forward * input_dir.y).normalized()
	var horizontal := Vector2(player.velocity.x, player.velocity.z)
	var target: Vector2 = Vector2(dir.x, dir.z) * float(player.speed) * SPEED
	horizontal = horizontal.move_toward(target, ACCEL * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.y
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
	else:
		player.velocity.y = minf(player.velocity.y, 0.0)
	player.move_and_slide()
	# What's she in now? Off the soil, she's out.
	var ground: Node = null
	if player.is_on_floor():
		_air = 0.0
		for i in player.get_slide_collision_count():
			var c := player.get_slide_collision(i)
			if c.get_normal().y > 0.6:
				ground = c.get_collider() as Node
				break
		if ground:
			floor_node = ground
			player._floor_node = ground
	else:
		_air += delta
	if _air > AIR_GRACE:
		stop(0.0)                             # off a ledge: she just drops out and falls
		return
	if ground and not soil(ground):
		stop(POP)
		return
	var kind: String = player.ground_kind()
	if kind == "water" or kind == "cloud":
		stop(POP)
		return
	if dir != Vector3.ZERO:
		player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
	# The mound wiggles its sprig round and kicks up a little soil behind it as it goes
	var going := horizontal.length()
	_mound.rotation.y += delta * (2.0 + going)
	_mound.position.y = -0.8 + sin(_under_for * 14.0) * 0.03 * minf(going, 1.0)
	_trail -= delta
	if going > 1.0 and _trail <= 0.0:
		_trail = TRAIL_EVERY
		_puff(0.2)
	RenderingServer.global_shader_parameter_set("nina_pos", player.global_position)   # the grass still parts for her


func _puff(amount: float) -> void:
	if player.is_inside_tree() and player.get_parent():
		Juice.dust(player.get_parent(), player.global_position + Vector3(0, -0.8, 0), amount, SOIL)
