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

@export_group("Skateboard")
@export var skate_speed: float = 10.0       # top speed from pushing
@export var skate_max_speed: float = 16.0   # absolute cap (you can go faster than pushing downhill)
@export var skate_push: float = 6.0         # how quickly pushing builds speed
@export var skate_coast: float = 1.2        # rolling friction when you let go (low = long glide)
@export var skate_brake: float = 12.0       # slowing down when you pull back against your direction
@export var skate_carve: float = 2.2        # how quickly the board can turn toward where you steer
@export var skate_slope: float = 0.9        # how much hills speed you up / slow you down
@export var skate_air_control: float = 0.15
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


func _ready() -> void:
	add_to_group("player")              # enemies find her through this group
	var scene_root: Node = owner if owner else get_tree().current_scene   # current_scene isn't set yet during a scene change
	# Coming through a door: appear at the matching spawn marker in this scene
	if Game.next_spawn != "":
		var marker := scene_root.find_child(Game.next_spawn, true, false) as Node3D
		if marker:
			global_transform = marker.global_transform
			spring_arm.rotation.y = 0.0
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
	Game.equipment_changed.connect(_on_equipment_changed)
	_on_equipment_changed()


func _on_equipment_changed() -> void:
	board.visible = Game.riding
	model.position.y = MODEL_Y + (skate_height if Game.riding else 0.0)
	model.rotation.y = skate_stance if Game.riding else 0.0


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
	var on_floor := is_on_floor()

	# Blink while invulnerable after a hit (or stay solid with Reduce flashing on)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		model.visible = Settings.reduce_flashing or _invulnerable_timer <= 0.0 or fmod(_invulnerable_timer, 0.16) > 0.08
	_stun_timer -= delta
	if on_floor:
		_air_jump_used = false

	# Gravity
	if not on_floor:
		var gravity := get_gravity()
		if velocity.y < 0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta

	# Coyote time and jump buffering
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else _jump_buffer_timer - delta

	# Jump (an ollie when riding: same jump, momentum kept). Jumping out of a roll is allowed and ends it.
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0
		_coyote_timer = 0
		_end_roll()
		Audio.play("jump", -3.0)
	# Double jump: a second, free jump in mid-air with a front flip; back again on landing or stomping
	elif Input.is_action_just_pressed("jump") and not on_floor and not _air_jump_used and not Game.riding \
			and _stun_timer <= 0.0:
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
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

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
	_roll_buffer_timer = roll_buffer if Input.is_action_just_pressed("dash") else _roll_buffer_timer - delta
	if _roll_buffer_timer > 0.0 and on_floor:
		_try_roll(direction)

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if _roll_timer > 0.0:
		_roll_timer -= delta
		var f := 1.0 - maxf(_roll_timer, 0.0) / roll_time
		horizontal = _roll_dir * lerpf(roll_speed, roll_end_speed, f * f)   # fast start, eases into a run
	elif _stun_timer > 0.0:
		pass                                # knocked back: ride out the hit
	elif Game.riding:
		horizontal = _skate(horizontal, direction, on_floor, delta)
	else:
		# Accelerate toward the target speed instead of snapping to it
		var rate := acceleration if direction else friction
		if not on_floor:
			rate *= air_control
		horizontal = horizontal.move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_fall_speed = -velocity.y
	move_and_slide()
	_sounds(delta, horizontal.length())

	# Turn the model: on foot it faces where you steer; on the board it faces where the board is rolling
	# (models face +Z after glTF export from Blender)
	var face := direction
	if _roll_timer > 0.0:
		face = _roll_dir
	elif Game.riding:
		face = horizontal if horizontal.length() > 0.3 else Vector3.ZERO
	if face:
		var target_yaw := atan2(face.x, face.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	if Game.riding:
		_tilt_board(delta)
	_update_spin(delta)

	_update_animation(horizontal.length())


func _try_roll(direction: Vector3) -> void:
	# A quick forward somersault that costs stamina (SP). For most of it nothing can hurt her (iframes), so she can
	# roll straight through an attack; rolling into a Gloop pops it.
	if _roll_timer > 0.0 or _stun_timer > 0.0 or Game.riding:
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
	if on_floor and not _was_on_floor and _fall_speed > 3.0:
		Audio.play("land", linear_to_db(clampf(_fall_speed / 10.0, 0.3, 1.0)))
	_was_on_floor = on_floor
	# Footsteps while running on foot
	if on_floor and not Game.riding and horizontal_speed > 0.8 and _roll_timer <= 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.33 * clampf(speed / horizontal_speed, 0.8, 1.6)
			Audio.play("step", -10.0, 0.15)
	else:
		_step_timer = 0.0


func _skate(h: Vector3, direction: Vector3, on_floor: bool, delta: float) -> Vector3:
	# Momentum-based rolling: pushing builds speed slowly, letting go coasts, steering carves wide arcs,
	# pulling back brakes, and slopes speed you up or slow you down.
	if not on_floor:
		return h.move_toward(direction * h.length(), skate_air_control * skate_push * delta) if direction else h
	var n := get_floor_normal()
	var g := get_gravity()
	var downhill := g - n * g.dot(n)                         # gravity along the ground
	h += Vector3(downhill.x, 0, downhill.z) * skate_slope * delta
	var s := h.length()
	if direction:
		if s < 0.5:
			h = h.move_toward(direction * skate_speed, skate_push * delta)     # push off from a standstill
		else:
			var heading := h / s
			var along := heading.dot(direction)
			if along < -0.3:
				s = move_toward(s, 0.0, skate_brake * delta)
			else:
				heading = heading.slerp(direction, clampf(skate_carve * delta, 0.0, 1.0)).normalized()
				if s < skate_speed:
					s = move_toward(s, skate_speed, skate_push * maxf(along, 0.2) * delta)
			h = heading * s
	else:
		h = h.move_toward(Vector3.ZERO, skate_coast * delta)
	return h.limit_length(skate_max_speed)


func _tilt_board(delta: float) -> void:
	# Lean the board to match the ground under it
	var n := get_floor_normal() if is_on_floor() else Vector3.UP
	var local_n := (visual.global_transform.basis.inverse() * n).normalized()
	var target := Basis(Quaternion(Vector3.UP, local_n))
	board.basis = board.basis.slerp(target, 1.0 - exp(-10.0 * delta))


func _update_animation(horizontal_speed: float) -> void:
	if anim == null:
		return
	var target := "idle"
	if _spin_timer > 0.0:
		target = "fall"                     # arms and legs tucked in for the roll or flip
	elif not is_on_floor():
		target = "jump" if velocity.y > 0.0 else "fall"
	elif Game.riding:
		target = "skate"
	elif horizontal_speed > 0.3:
		target = "run"
	# assigned_animation sticks after a one-shot (jump) finishes, so it holds its last pose instead of restarting
	if anim.assigned_animation != target:
		anim.play(target, 0.15)
	# Match the stride to how fast she's actually moving
	anim.speed_scale = clampf(horizontal_speed / speed, 0.6, 1.4) if target == "run" else 1.0
