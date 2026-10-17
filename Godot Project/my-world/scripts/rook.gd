extends CharacterBody3D

# Rook, Dash's twin, who gets about on all fours like a dog (scenes/town/characters.tscn).
# He trots and gallops around his spot in town, stops to pant and look around, and barks at Nina when she
# comes close (and now and then for no reason at all). His model faces +Z; actions: idle, walk, run, bark.

@export var wander_radius := 7.0
@export var walk_speed := 0.6
@export var run_speed := 2.2
@export var bark_distance := 5.0
@export var bark_cooldown := 6.0

const GRAVITY := 20.0
const TURN_SPEED := 8.0
# How fast each action plays, so his hands and feet keep up with how fast he is moving
const ANIM_SPEED := {"walk": 2.0, "run": 1.8}
const WOOF_TIMES := [0.07, 0.42]          # seconds into the bark action (tools/build_rook.py)

enum State { IDLE, MOVE, BARK }

var _state := State.IDLE
var _timer := 1.0
var _target := Vector3.ZERO
var _speed := 0.0
var _home := Vector3.ZERO
var _bark_t := 0.0
var _woofs := 0
var _cooldown := 0.0
var _stuck := 0.0
var _anim: AnimationPlayer
var _player: Node3D


func _ready() -> void:
	_home = global_position
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in ["idle", "walk", "run"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning("%s: no AnimationPlayer in its model" % name)
	_timer = randf_range(0.5, 2.5)
	_play("idle")


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_cooldown -= delta
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var flat := Vector3.ZERO

	match _state:
		State.IDLE:
			_timer -= delta
			if _wants_to_bark():
				_start_bark()
			elif _timer <= 0.0:
				if randf() < 0.15:
					_start_bark()
				else:
					_start_move()
		State.MOVE:
			var to := _target - global_position
			to.y = 0.0
			if _wants_to_bark():
				_start_bark()
			elif to.length() < 0.4:
				_start_idle()
			else:
				flat = to.normalized() * _speed
				_face(flat, delta)
				# Bumped into something (a wall, a fence, Nina): give up on that spot
				var moved := Vector2(get_real_velocity().x, get_real_velocity().z).length()
				_stuck = _stuck + delta if moved < _speed * 0.3 else 0.0
				if _stuck > 0.6:
					_start_idle()
		State.BARK:
			if _player:
				_face(_player.global_position - global_position, delta)
			_bark_t += delta
			if _woofs < WOOF_TIMES.size() and _bark_t >= WOOF_TIMES[_woofs]:
				_woofs += 1
				Audio.play_at("bark", global_position + Vector3.UP * 0.5)
			if _bark_t >= _bark_length():
				_start_idle()

	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()


func _wants_to_bark() -> bool:
	return _cooldown <= 0.0 and _player != null \
			and global_position.distance_to(_player.global_position) < bark_distance


func _start_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(1.5, 4.0)
	_stuck = 0.0
	_play("idle")


func _start_move() -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * wander_radius
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var gallop := randf() < 0.6
	_speed = run_speed if gallop else walk_speed
	_stuck = 0.0
	_state = State.MOVE
	_play("run" if gallop else "walk")


func _start_bark() -> void:
	_state = State.BARK
	_bark_t = 0.0
	_woofs = 0
	_cooldown = bark_cooldown
	_play("bark")


func _bark_length() -> float:
	return _anim.get_animation("bark").length if _anim and _anim.has_animation("bark") else 1.0


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, TURN_SPEED * delta))


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim):
		_anim.play(anim, 0.2, ANIM_SPEED.get(anim, 1.0))
