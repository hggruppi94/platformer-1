extends CharacterBody3D

# A townsperson who wanders around their spot (scenes/town/characters.tscn): moves between random places
# nearby, stops to look around, and reacts when Nina comes close. Models face +Z.
#
# Rook (Dash's twin, on all fours) uses the defaults: he trots and gallops, and barks at Nina (and now and then
# for no reason at all). Rex (Dash's twin, the talking husky on skates) skates about and stops to turn and look
# at her (no react action).

@export var wander_radius := 7.0
@export var walk_speed := 0.6
@export var run_speed := 2.2
@export_range(0.0, 1.0) var run_chance := 0.6       # how often he runs instead of walking to the next spot
@export var walk_anim := "walk"
@export var run_anim := "run"
@export var walk_anim_speed := 2.0                  # play speeds that keep hands and feet in step with the ground
@export var run_anim_speed := 1.8
@export var react_anim := "bark"                    # played when Nina comes close; "" = just stop and look at her
@export var react_sound := "bark"                   # audio/sfx/<name>.wav, played at react_sound_times; "" = silent
@export var react_sound_times: Array[float] = [0.07, 0.42]   # seconds into the react action (tools/build_rook.py)
@export var react_distance := 5.0
@export var react_cooldown := 6.0
@export_range(0.0, 1.0) var random_react_chance := 0.15   # chance to react for no reason when done resting

const GRAVITY := 20.0
const TURN_SPEED := 8.0
const LOOK_TIME := 2.5                              # how long he stops to look when there's no react action

enum State { IDLE, MOVE, REACT }

var _state := State.IDLE
var _timer := 1.0
var _target := Vector3.ZERO
var _speed := 0.0
var _home := Vector3.ZERO
var _react_t := 0.0
var _sounds := 0
var _cooldown := 0.0
var _stuck := 0.0
var _anim: AnimationPlayer
var _player: Node3D
var talking := false                                # set by his talk spot (scripts/talker.gd): stand still and listen
var held := false                                   # set by his daily routine (scripts/routine.gd) while it moves him


func _ready() -> void:
	_home = global_position
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in ["idle", walk_anim, run_anim]:
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
	if held:                                        # his routine is walking him somewhere, or he's away
		_cooldown = react_cooldown
		return
	if talking:                                     # the talk spot turns him to face her
		if _state != State.IDLE or (_anim and _anim.current_animation != "idle"):
			_start_idle()
		_timer = 1.0
		_cooldown = react_cooldown                  # no barking at her the moment she's done talking
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var flat := Vector3.ZERO

	match _state:
		State.IDLE:
			_timer -= delta
			if _player_close():
				_start_react()
			elif _timer <= 0.0:
				if react_anim != "" and randf() < random_react_chance:
					_start_react()
				else:
					_start_move()
		State.MOVE:
			var to := _target - global_position
			to.y = 0.0
			if _player_close():
				_start_react()
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
		State.REACT:
			if _player:
				_face(_player.global_position - global_position, delta)
			_react_t += delta
			if react_sound != "" and _sounds < react_sound_times.size() and _react_t >= react_sound_times[_sounds]:
				_sounds += 1
				Audio.play_at(react_sound, global_position + Vector3.UP * 0.5)
			if _react_t >= _react_length():
				_start_idle()

	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()


func _player_close() -> bool:
	return _cooldown <= 0.0 and _player != null \
			and global_position.distance_to(_player.global_position) < react_distance


func _start_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(1.5, 4.0)
	_stuck = 0.0
	_play("idle")


func _start_move() -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * wander_radius
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var running := randf() < run_chance
	_speed = run_speed if running else walk_speed
	_stuck = 0.0
	_state = State.MOVE
	_play(run_anim if running else walk_anim)


func _start_react() -> void:
	_state = State.REACT
	_react_t = 0.0
	_sounds = 0
	_cooldown = react_cooldown
	_play(react_anim if react_anim != "" else "idle")


func _react_length() -> float:
	if react_anim != "" and _anim and _anim.has_animation(react_anim):
		return _anim.get_animation(react_anim).length
	return LOOK_TIME


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, TURN_SPEED * delta))


func _play(anim: String) -> void:
	if _anim == null or not _anim.has_animation(anim):
		return
	var speed := 1.0
	if anim == run_anim:
		speed = run_anim_speed
	elif anim == walk_anim:
		speed = walk_anim_speed
	_anim.play(anim, 0.2, speed)
