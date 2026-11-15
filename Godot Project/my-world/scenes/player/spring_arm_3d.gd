extends SpringArm3D

@export var mouse_sensitivity: float = 0.005
@export var stick_speed: float = 2.6   # radians per second at full stick tilt
@export var min_pitch: float = -1.2   # look-down limit (radians)
@export var max_pitch: float = 0.4    # look-up limit (radians)

@onready var camera: Camera3D = $Camera3D
var fov_kick := 0.0                   # extra field of view for a moment (a roll adds some)
var aim := 0.0                        # 0..1: how far into the over-the-shoulder aiming view (scripts/star_popper.gd)
const AIM_LENGTH := 2.6               # the boom's length while aiming, in close behind the right shoulder
const AIM_SHIFT := Vector3(1.0, 0.3, 0.0)
const AIM_ZOOM := 14.0                # degrees of field of view taken off while aiming
# The boom's own length (from the scene) and how far it's lifted, for when she isn't aiming. Other things change
# these, not spring_length or position: this script sets those every frame, so a change made straight to them was
# lost the next frame (the mothership's pulled-back camera never pulled back).
var boom_length := 5.0
var lift := 0.0
var _origin := Vector3.ZERO           # ...and where it's fixed on her
var _since_look := 10.0               # seconds since the player last turned the camera themselves
# When something gets between her and the camera the boom snaps in at once (so the camera never goes through a wall),
# but it used to snap straight back out too the moment the way was clear, which jolts. Now it eases back out.
const EASE_OUT := 5.0                 # metres a second the boom grows back out after being pushed in
var _shown := 5.0                     # how long the boom is now, eased
var _easing := false                  # growing back out after a wall (anything else that changes the boom is at once)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Don't let the camera boom collide with the player's own body
	add_excluded_object(get_parent().get_rid())
	boom_length = spring_length
	_shown = spring_length
	_origin = position
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	camera.fov = Settings.fov


func _unhandled_input(event: InputEvent) -> void:
	# The character creator has the mouse while it's open: it keeps the cursor, and turns the hero, not the camera
	if Creator.is_open():
		return
	# The pause menu (Esc) frees the mouse; clicking back in the game window grabs it again
	# (not while a race's results buttons are up: they need the cursor)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused and not Races.choosing():
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
	camera.fov = Settings.fov + fov_kick - AIM_ZOOM * aim
	spring_length = lerpf(boom_length, AIM_LENGTH, aim)
	_ease_camera(delta)
	# The boom places its camera itself, so the shoulder shift moves the boom: to the camera's right, a bit up
	var turn := Basis(Vector3.UP, rotation.y)
	position = _origin + Vector3(0, lift, 0) + turn * AIM_SHIFT * aim


func _ease_camera(delta: float) -> void:
	# The boom puts the camera at its hit length every physics frame. This runs after that, before the frame's drawn:
	# in at once if the way's blocked, but back out only bit by bit. spring_length itself is left alone (the
	# mothership and aiming set the length they want through boom_length and aim).
	var hit := get_hit_length()
	if hit < _shown - 0.05:
		_shown = hit
		_easing = true
	if _easing:
		_shown = minf(move_toward(_shown, hit, EASE_OUT * delta), hit)
		_easing = _shown < spring_length - 0.01     # (still held in by the wall counts: keep easing till fully out)
		camera.position.z = _shown
	else:
		_shown = hit


func shown_length() -> float:
	return _shown


func follow(yaw: float, delta: float, rate := 2.5, quiet := 0.8) -> void:
	# Swing round behind something moving (Nina on her board, scenes/player/skate.gd; running on foot, player.gd,
	# slower), unless the player has turned the camera themselves in the last `quiet` seconds: then it's theirs for a
	# moment. While she aims it's the player's all the time.
	if _since_look > quiet and aim <= 0.0:
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _look(dx: float, dy: float) -> void:
	_since_look = 0.0
	rotation.y -= dx * (-1.0 if Settings.invert_x else 1.0)   # look left/right
	rotation.x -= dy * (-1.0 if Settings.invert_y else 1.0)   # look up/down
	rotation.x = clamp(rotation.x, min_pitch, max_pitch)
