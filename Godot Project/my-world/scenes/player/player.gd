extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var speed: float = 5.0
@export var acceleration: float = 40.0   # how quickly you reach top speed on the ground
@export var friction: float = 50.0       # how quickly you stop on the ground
@export var air_control: float = 0.4     # fraction of ground accel/friction available mid-air
@export var turn_speed: float = 12.0     # how quickly the model turns to face movement

@export_group("Jump")
@export var jump_velocity: float = 6.0
@export var jump_cut: float = 0.5                # releasing jump early scales upward speed by this
@export var fall_gravity_multiplier: float = 1.6 # heavier on the way down = less floaty
@export var coyote_time: float = 0.12            # seconds you can still jump after leaving a ledge
@export var jump_buffer_time: float = 0.12       # seconds a jump press is remembered before landing
@export var double_jump_velocity: float = 5.5    # the second jump, in mid-air; free, once per time in the air
@export var flip_time: float = 0.42              # the front flip that goes with it

@export_group("Skateboard")                   # how the board rides is in scripts/rides.gd
@export var skate_stance: float = -PI / 2   # she rides side-on to the board
@export var skate_height: float = 0.115     # board deck height under her feet

@export_group("Roll")
@export var roll_speed: float = 12.0        # speed at the start of the roll; it eases down to a run by the end
@export var roll_end_speed: float = 4.5
@export var roll_time: float = 0.45         # seconds the roll lasts (about 3.7 m)
@export var roll_iframes: float = 0.38      # nothing can hurt her for this much of it, from the start
@export var roll_cost: float = 25.0         # SP (stamina) per roll
@export var roll_buffer: float = 0.15       # a roll pressed just before landing still happens

@export_group("Getting hurt")
@export var invulnerable_time: float = 1.2  # seconds of blinking after a hit, when nothing can hurt her
@export var knockback: float = 7.0          # how hard a hit pushes her away
@export var knockback_up: float = 4.0
@export var stun_time: float = 0.3          # seconds the knockback can't be steered out of

# Reference to the camera boom so movement follows where you're looking
@onready var spring_arm: SpringArm3D = $SpringArm3D
# The character model; rotated to face movement (the body itself stays unrotated so the camera doesn't spin)
@onready var visual: Node3D = $Visual
@onready var tumble: Node3D = $Visual/Tumble     # pivot at her middle: rolls and flips spin this
@onready var model: Node3D = $Visual/Tumble/Nina
@onready var board: Node3D = $Visual/Skateboard
var _sash: Node3D                                 # shown once she has the campaign sash
var _hat: Node3D                                  # the market hat she's wearing (scripts/cosmetics.gd)
var _stickers: Node3D                             # market stickers on the sash
# Animations exported from Blender with the character (idle, run, jump, fall, skate)
@onready var anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)

const MODEL_Y := -0.8                       # feet at the bottom of the collision capsule

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _invulnerable_timer := 0.0
var _stun_timer := 0.0
var _roll_timer := 0.0
var _roll_dir := Vector3.ZERO
var _roll_buffer_timer := 0.0
var _air_jump_used := false
var _spin_timer := 0.0                      # somersault (roll) or front flip (double jump) in progress
var _spin_time := 1.0
var _spin_squash := 0.0                     # how much she tucks into a ball mid-spin
var _spin_grounded := false                 # roll: keep the ball on the floor while it turns
var _was_on_floor := true
var _fall_speed := 0.0
var _step_timer := 0.0
var input_locked := false                   # talking to someone (scripts/dialogue.gd): no moving, jumping or rolling
var carried := false                        # riding something that moves her itself (scripts/zipline.gd): no physics
var skate: Skate                            # takes over her physics while she's on the board (scenes/player/skate.gd)
var _on_board := false

# Walk-through places she's inside (clouds, the bubble bath, hot springs, the lake: scripts/soft_zone.gd,
# scripts/water.gd). Each can slow her down (speed_scale), make her float (gravity_scale, fall_cap) and sets the
# sound of her steps (kind). What's under her feet otherwise picks the sound too (scripts/surfaces.gd).
var _zones: Array[Node] = []
var _floor_node: Node = null
const STEP_SOUNDS := {"grass": "step_grass", "wood": "step_wood", "stone": "step_stone", "water": "step_water",
	"cloud": "step_cloud", "crystal": "step_crystal", "mushroom": "step_cloud"}
const LAND_SOUNDS := {"water": "splash", "cloud": "fwump", "crystal": "step_crystal", "mushroom": "boing"}
const MUSHROOM_BOUNCE := 9.5                # landing on a big mushroom cap bounces her up this fast


func _ready() -> void:
	add_to_group("player")              # enemies find her through this group
	var scene_root: Node = owner if owner else get_tree().current_scene   # current_scene isn't set yet during a scene change
	# Coming through a door: appear at the matching spawn marker in this scene
	if Game.next_spawn != "":
		var marker := scene_root.find_child(Game.next_spawn, true, false) as Node3D
		if marker:
			# Stand on the marker facing the way it points (its -Z: into the room, or away from the building). Only
			# the model and the camera turn: the body stays unturned, like everywhere else (movement and the camera
			# rely on it). Copying the marker's whole transform used to turn the body and leave her facing backwards.
			global_position = marker.global_position
			rotation = Vector3.ZERO
			var yaw := marker.global_rotation.y
			visual.rotation.y = yaw + PI                    # models face +Z
			spring_arm.rotation.y = yaw                     # camera behind her, looking the same way
		Game.next_spawn = ""
	# Starting the game from a save: appear where she was
	var resume := Game.take_resume_point(scene_root.scene_file_path if scene_root else "")
	if not resume.is_empty():
		global_position = resume["position"]
		visual.rotation.y = resume["yaw"]
		spring_arm.rotation.y = resume["yaw"] + PI         # camera behind her
	if not Game.is_resuming():
		Game.save_game.call_deferred()                     # autosave on arriving anywhere
	if anim:
		for loop_name in ["idle", "run", "fall", "skate"]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	_add_sash()
	skate = Skate.new()
	skate.name = "Skate"
	add_child(skate)
	skate.setup(self)
	Game.equipment_changed.connect(_on_equipment_changed)
	_on_equipment_changed()


func _on_equipment_changed() -> void:
	board.visible = Game.riding
	if Game.riding and not _on_board:
		skate.start()
	elif not Game.riding and _on_board:
		skate.stop()
	_on_board = Game.riding
	if _sash:
		_sash.visible = Game.has_item("campaign_sash")     # Rex's thank-you for running his campaign
		if _stickers:
			_stickers.free()
		_stickers = Node3D.new()
		_stickers.name = "Stickers"
		_sash.add_child(_stickers)
		for id in Cosmetics.STICKER_ANGLES:
			if Game.has_item("shop:" + id):
				var st: Node3D = Cosmetics.sticker(id)
				st.transform = Cosmetics.sticker_place(id)
				_stickers.add_child(st)
	if _hat:
		_hat.free()
		_hat = null
	if Game.hat != "":
		_hat = Cosmetics.hat(Game.hat)
		if _hat:
			model.add_child(_hat)
	model.position.y = MODEL_Y + (skate_height if Game.riding else 0.0)
	model.rotation.y = skate_stance if Game.riding else 0.0


func _add_sash() -> void:
	# A "VOTE REX" sash from her shoulder across to her hip, round her middle (on the model, so it turns and rolls
	# with her)
	_sash = Node3D.new()
	_sash.name = "Sash"
	_sash.position = Vector3(0, 0.6, 0)
	model.add_child(_sash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.33
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.25, 0.3)
	m.roughness = 0.7
	ring.material_override = m
	ring.rotation = Vector3(0, 0, deg_to_rad(44))
	ring.scale = Vector3(1.0, 1.0, 0.85)
	_sash.add_child(ring)
	var star := MeshInstance3D.new()                       # a gold rosette on the front
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.03
	star.mesh = disc
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.25)
	gold.metallic = 0.6
	gold.roughness = 0.3
	star.material_override = gold
	star.position = Vector3(-0.07, 0.04, 0.27)
	star.rotation = Vector3(PI / 2, 0, 0)
	_sash.add_child(star)


func is_invulnerable() -> bool:
	# Nothing can hurt her: blinking after a hit, or the invulnerable frames of a roll
	return _invulnerable_timer > 0.0 or (_roll_timer > 0.0 and roll_time - _roll_timer < roll_iframes)


func is_recovering() -> bool:
	# Just the blinking after a hit (enemies leave her alone for it; a roll's iframes don't scare them off)
	return _invulnerable_timer > 0.0


func is_rolling() -> bool:
	return _roll_timer > 0.0


func hurt(amount: int, from: Vector3) -> void:
	# Called by enemies on touch. Knocks her away from the hit, then she blinks and can't be hurt for a moment.
	if is_invulnerable():
		return
	_invulnerable_timer = invulnerable_time
	_stun_timer = stun_time
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = -visual.global_transform.basis.z
	velocity = away.normalized() * knockback + Vector3.UP * knockback_up
	_roll_timer = 0.0
	Audio.play("hurt")
	Game.damage(amount)


func bounce(strength: float) -> void:
	# Pop upward after stomping an enemy; hold jump for a higher bounce
	velocity.y = strength * (1.3 if Input.is_action_pressed("jump") else 1.0)
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_air_jump_used = false              # a stomp gives the double jump back


func _physics_process(delta: float) -> void:
	if _hat and _hat.has_node("Propeller"):
		(_hat.get_node("Propeller") as Node3D).rotate_y(delta * 14.0)    # the propeller cap spins
	if carried:
		return
	var on_floor := is_on_floor()

	# Blink while invulnerable after a hit (or stay solid with Reduce flashing on)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		model.visible = Settings.reduce_flashing or _invulnerable_timer <= 0.0 or fmod(_invulnerable_timer, 0.16) > 0.08
	_stun_timer -= delta
	if Game.riding:
		skate.physics(delta)
		return
	if on_floor:
		_air_jump_used = false

	# Gravity
	if not on_floor:
		var gravity := get_gravity() * _zone_min("gravity_scale", 1.0)
		if velocity.y < 0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
		velocity.y = maxf(velocity.y, -_zone_min("fall_cap", 1000.0))       # floaty in clouds and the bath

	# Coyote time and jump buffering
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	var jump_pressed := Input.is_action_just_pressed("jump") and not input_locked
	_jump_buffer_timer = jump_buffer_time if jump_pressed else _jump_buffer_timer - delta

	# Jump. Jumping out of a roll is allowed and ends it.
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0
		_coyote_timer = 0
		_end_roll()
		Audio.play("jump", -3.0)
	# Double jump: a second, free jump in mid-air with a front flip; back again on landing or stomping
	elif jump_pressed and not on_floor and not _air_jump_used and _stun_timer <= 0.0:
		velocity.y = double_jump_velocity
		_air_jump_used = true
		_jump_buffer_timer = 0
		_end_roll()
		_spin(flip_time, 0.25, false)
		Audio.play("double_jump", -3.0, 0.05)

	# Let go of jump early for a shorter hop
	if Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y *= jump_cut

	# Read input
	var input_dir := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Build direction relative to the CAMERA's yaw instead of the player body
	var cam_basis := spring_arm.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	# Flatten to the horizontal plane so looking up/down doesn't slow you
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var direction := (right * input_dir.x - forward * input_dir.y).normalized()

	# Roll (the "dash" action): on the ground only; pressed in the air, it waits a moment for her to land
	_roll_buffer_timer = roll_buffer if Input.is_action_just_pressed("dash") and not input_locked else _roll_buffer_timer - delta
	if _roll_buffer_timer > 0.0 and on_floor:
		_try_roll(direction)

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if _roll_timer > 0.0:
		_roll_timer -= delta
		var f := 1.0 - maxf(_roll_timer, 0.0) / roll_time
		horizontal = _roll_dir * lerpf(roll_speed, roll_end_speed, f * f)   # fast start, eases into a run
	elif _stun_timer > 0.0:
		pass                                # knocked back: ride out the hit
	else:
		# Accelerate toward the target speed instead of snapping to it
		var rate := acceleration if direction else friction
		if not on_floor:
			rate *= air_control
		horizontal = horizontal.move_toward(direction * speed * _zone_min("speed_scale", 1.0), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_fall_speed = -velocity.y
	move_and_slide()
	_floor_node = null
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y > 0.6:
				_floor_node = c.get_collider() as Node
				break
	RenderingServer.global_shader_parameter_set("nina_pos", global_position)   # plants lean away from her
	_sounds(delta, horizontal.length())

	# Turn the model to face where you steer (models face +Z after glTF export from Blender)
	var face := _roll_dir if _roll_timer > 0.0 else direction
	if face:
		var target_yaw := atan2(face.x, face.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	_update_spin(delta)

	_update_animation(horizontal.length())


func _try_roll(direction: Vector3) -> void:
	# A quick forward somersault that costs stamina (SP). For most of it nothing can hurt her (iframes), so she can
	# roll straight through an attack; rolling into a Gloop pops it.
	if _roll_timer > 0.0 or _stun_timer > 0.0:
		return
	_roll_buffer_timer = 0.0
	if not Game.spend_sp(roll_cost):
		Game.message("Too tired to roll! Stamina refills in a moment.")
		Audio.play("ui_back", -6.0, 0.0)
		return
	_roll_dir = direction if direction else visual.global_transform.basis.z
	_roll_dir.y = 0.0
	_roll_dir = _roll_dir.normalized()
	_roll_timer = roll_time
	_spin(roll_time, 0.5, true)
	Audio.play("roll", -2.0, 0.08)
	if not Settings.reduce_motion:
		spring_arm.fov_kick = 5.0


func _end_roll() -> void:
	if _roll_timer > 0.0:
		_roll_timer = 0.0
		_spin_timer = 0.0                    # the spin eases back upright from wherever it was


func _spin(time: float, squash: float, grounded: bool) -> void:
	_spin_time = time
	_spin_timer = time
	_spin_squash = squash
	_spin_grounded = grounded


func _update_spin(delta: float) -> void:
	# One full turn forward around her middle, tucked into a ball halfway through. The visual is rotated to face her
	# heading, so turning about its X axis is always a forward somersault.
	if _spin_timer > 0.0:
		_spin_timer -= delta
		var f := clampf(1.0 - _spin_timer / _spin_time, 0.0, 1.0)
		var turn := f * f * (3.0 - 2.0 * f)                         # ease in and out
		tumble.rotation.x = TAU * turn if _spin_timer > 0.0 else 0.0
		var s := 1.0 - _spin_squash * sin(PI * f)
		tumble.scale = Vector3(1.0, s, 1.0)
		# On the ground, lower the pivot as she tucks so the ball rolls along the floor instead of floating
		tumble.position.y = -0.8 * (1.0 - s) if _spin_grounded else 0.0
	else:
		var k := 1.0 - exp(-18.0 * delta)
		tumble.rotation.x = lerp_angle(tumble.rotation.x, 0.0, k)
		tumble.scale = tumble.scale.lerp(Vector3.ONE, k)
		tumble.position.y = lerpf(tumble.position.y, 0.0, k)


func _sounds(delta: float, horizontal_speed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var ground := ground_kind()
		if ground == "mushroom" and _fall_speed > 2.0:
			velocity.y = MUSHROOM_BOUNCE              # boing: big mushroom caps are bouncy
			_air_jump_used = false
			Audio.play("boing", -2.0, 0.1)
		elif _fall_speed > 3.0:
			if ground == "cloud":
				velocity.y = minf(_fall_speed * 0.35, 4.0)   # a soft little bounce on a cloud
			Audio.play(LAND_SOUNDS.get(ground, "land"), linear_to_db(clampf(_fall_speed / 10.0, 0.3, 1.0)))
	_was_on_floor = on_floor
	# Footsteps while running on foot
	if on_floor and horizontal_speed > 0.8 and _roll_timer <= 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.33 * clampf(speed / horizontal_speed, 0.8, 1.6)
			Audio.play(STEP_SOUNDS.get(ground_kind(), "step"), -9.0, 0.15)
	else:
		_step_timer = 0.0


func enter_zone(zone: Node) -> void:
	if zone not in _zones:
		_zones.append(zone)


func exit_zone(zone: Node) -> void:
	_zones.erase(zone)


func in_zone(kind: String) -> bool:
	for z in _zones:
		if is_instance_valid(z) and z.get("kind") == kind:
			return true
	return false


func ground_kind() -> String:
	# Water and clouds she's in come first; otherwise whatever is under her feet
	for k in ["water", "bath", "spring", "cloud"]:
		if in_zone(k):
			return "cloud" if k == "cloud" else "water"
	return Surfaces.kind_of(_floor_node)


func _zone_min(prop: String, default: float) -> float:
	var v := default
	for z in _zones:
		if is_instance_valid(z):
			v = minf(v, float(z.get(prop)))
	return v


func _update_animation(horizontal_speed: float) -> void:
	if anim == null:
		return
	var target := "idle"
	if _spin_timer > 0.0:
		target = "fall"                     # arms and legs tucked in for the roll or flip
	elif not is_on_floor():
		target = "jump" if velocity.y > 0.0 else "fall"
	elif horizontal_speed > 0.3:
		target = "run"
	# assigned_animation sticks after a one-shot (jump) finishes, so it holds its last pose instead of restarting
	if anim.assigned_animation != target:
		anim.play(target, 0.15)
	# Match the stride to how fast she's actually moving
	anim.speed_scale = clampf(horizontal_speed / speed, 0.6, 1.4) if target == "run" else 1.0
