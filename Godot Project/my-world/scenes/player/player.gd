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

# Reference to the camera boom so movement follows where you're looking
@onready var spring_arm: SpringArm3D = $SpringArm3D
# The character model; rotated to face movement (the body itself stays unrotated so the camera doesn't spin)
@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Nina
@onready var board: Node3D = $Visual/Skateboard
# Animations exported from Blender with the character (idle, run, jump, fall, skate)
@onready var anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)

const MODEL_Y := -0.8                       # feet at the bottom of the collision capsule

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

	# Jump (an ollie when riding: same jump, momentum kept)
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

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if Game.riding:
		horizontal = _skate(horizontal, direction, on_floor, delta)
	else:
		# Accelerate toward the target speed instead of snapping to it
		var rate := acceleration if direction else friction
		if not on_floor:
			rate *= air_control
		horizontal = horizontal.move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# Turn the model: on foot it faces where you steer; on the board it faces where the board is rolling
	# (models face +Z after glTF export from Blender)
	var face := direction
	if Game.riding:
		face = horizontal if horizontal.length() > 0.3 else Vector3.ZERO
	if face:
		var target_yaw := atan2(face.x, face.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	if Game.riding:
		_tilt_board(delta)

	_update_animation(horizontal.length())


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
	if not is_on_floor():
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
