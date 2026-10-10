extends SpringArm3D

@export var mouse_sensitivity: float = 0.005
@export var min_pitch: float = -1.2   # look-down limit (radians)
@export var max_pitch: float = 0.4    # look-up limit (radians)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Don't let the camera boom collide with the player's own body
	add_excluded_object(get_parent().get_rid())

func _unhandled_input(event: InputEvent) -> void:
	# Press Escape to release the mouse, click in the window to grab it again
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity   # look left/right
		rotation.x -= event.relative.y * mouse_sensitivity   # look up/down
		rotation.x = clamp(rotation.x, min_pitch, max_pitch)
