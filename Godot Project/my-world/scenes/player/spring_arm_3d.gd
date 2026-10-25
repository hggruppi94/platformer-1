extends SpringArm3D

@export var mouse_sensitivity: float = 0.005
@export var stick_speed: float = 2.6   # radians per second at full stick tilt
@export var min_pitch: float = -1.2   # look-down limit (radians)
@export var max_pitch: float = 0.4    # look-up limit (radians)

@onready var camera: Camera3D = $Camera3D
var fov_kick := 0.0                   # extra field of view for a moment (a roll adds some)
var _since_look := 10.0               # seconds since the player last turned the camera themselves


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Don't let the camera boom collide with the player's own body
	add_excluded_object(get_parent().get_rid())
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	camera.fov = Settings.fov


func _unhandled_input(event: InputEvent) -> void:
	# The character creator has the mouse while it's open: it keeps the cursor, and turns the hero, not the camera
	if Creator.is_open():
		return
	# The pause menu (Esc) frees the mouse; clicking back in the game window grabs it again
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := mouse_sensitivity * Settings.mouse_sensitivity
		_look(event.relative.x * s, event.relative.y * s)


func _process(delta: float) -> void:
	# Controller right stick (in the character creator it turns the hero instead: scripts/creator.gd)
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO and not Creator.is_open():
		_look(stick.x * stick_speed * Settings.stick_sensitivity * delta, stick.y * stick_speed * Settings.stick_sensitivity * delta)
	_since_look += delta
	fov_kick = move_toward(fov_kick, 0.0, 30.0 * delta)
	camera.fov = Settings.fov + fov_kick


func follow(yaw: float, delta: float, rate := 2.5) -> void:
	# Swing round behind something moving (Nina on her board, scenes/player/skate.gd), unless the player has just
	# turned the camera themselves: then it's theirs for a moment.
	if _since_look > 0.8:
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _look(dx: float, dy: float) -> void:
	_since_look = 0.0
	rotation.y -= dx * (-1.0 if Settings.invert_x else 1.0)   # look left/right
	rotation.x -= dy * (-1.0 if Settings.invert_y else 1.0)   # look up/down
	rotation.x = clamp(rotation.x, min_pitch, max_pitch)
