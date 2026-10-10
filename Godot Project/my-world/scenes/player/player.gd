extends CharacterBody3D

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

# Reference to the camera boom so movement follows where you're looking
@onready var spring_arm: SpringArm3D = $SpringArm3D
# The character model; rotated to face movement (the body itself stays unrotated so the camera doesn't spin)
@onready var visual: Node3D = $Visual
# Animations exported from Blender with the character (idle, run, jump, fall)
@onready var anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _ready() -> void:
	# Coming through a door: appear at the matching spawn marker in this scene
	if Game.next_spawn != "":
		var scene_root: Node = owner if owner else get_tree().current_scene   # current_scene isn't set yet during a scene change
		var marker := scene_root.find_child(Game.next_spawn, true, false) as Node3D
		if marker:
			global_transform = marker.global_transform
			spring_arm.rotation.y = 0.0
		Game.next_spawn = ""
	if anim:
		for loop_name in ["idle", "run", "fall"]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# Gravity
	if not on_floor:
		var gravity := get_gravity()
		if velocity.y < 0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta

	# Coyote time and jump buffering
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else _jump_buffer_timer - delta

	# Jump
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0
		_coyote_timer = 0

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

	# Accelerate toward the target speed instead of snapping to it
	var rate := acceleration if direction else friction
	if not on_floor:
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# Turn the model to face where we're moving (models face +Z after glTF export from Blender)
	if direction:
		var target_yaw := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	_update_animation(horizontal.length())


func _update_animation(horizontal_speed: float) -> void:
	if anim == null:
		return
	var target := "idle"
	if not is_on_floor():
		target = "jump" if velocity.y > 0.0 else "fall"
	elif horizontal_speed > 0.3:
		target = "run"
	# assigned_animation sticks after a one-shot (jump) finishes, so it holds its last pose instead of restarting
	if anim.assigned_animation != target:
		anim.play(target, 0.15)
	# Match the stride to how fast she's actually moving
	anim.speed_scale = clampf(horizontal_speed / speed, 0.6, 1.4) if target == "run" else 1.0
