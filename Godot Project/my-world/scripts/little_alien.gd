extends Node3D

# One of the little aliens (models/characters/little_alien_<colour>.glb, tools/build_little_aliens.py) pottering about
# on whatever it's standing on: the ground, a roof, or straight up a wall, because their sticky boots don't care
# which way is down. Spawned and moved about by scripts/little_aliens.gd.
#
# It walks along its surface by feeling ahead with rays (no physics body, so nothing can bump into it or stand on
# it): a step that runs into a wall climbs onto the wall, a step off the top of a wall rolls over onto the roof, and a
# step off an edge with nothing round it turns back. When the player comes close it either waves or scurries off.
# The model's +Z is its front; its "up" is the surface it's on.

const PROBE := 0.45                      # how far above and below its feet it feels for the surface
const LOOK := 0.32                       # how far ahead it looks for a wall to climb
const TURN := 6.0
const WALK_SPEED := 0.55
const RUN_SPEED := 1.9
const REACT_DISTANCE := 4.0
const SIZE := 1.2                        # a touch bigger than the models are built, so they read from across a square

enum State { IDLE, MOVE, WAVE }

var up := Vector3.UP                     # the surface's normal under its feet
var forward := Vector3.FORWARD           # the way it's walking, along the surface
var climbs := true                       # some like walls; some stay on the flat
var exclude: Array[RID] = []             # bodies it mustn't walk on (the player)
var _state := State.IDLE
var _timer := 1.0
var _speed := WALK_SPEED
var _cooldown := 0.0
var _turning := 0.0                      # left (-) or right (+), how hard it's wandering off its line
var _anim: AnimationPlayer
var _player: Node3D


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in ["idle", "walk", "run", "wave"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.speed_scale = randf_range(0.9, 1.15)        # so a crowd doesn't move in lockstep
	_timer = randf_range(0.2, 3.0)
	_play("idle")


# Puts it on a surface: at a point, standing out along that surface's normal, facing any way along it.
func place(at: Vector3, normal: Vector3, facing := Vector3.ZERO) -> void:
	up = normal.normalized()
	if facing == Vector3.ZERO:
		facing = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
	forward = _along(facing, up)
	global_position = at
	_orient(1.0)
	_start_idle()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not visible:
		return
	_cooldown -= delta
	var near := _cooldown <= 0.0 and _player != null \
			and global_position.distance_to(_player.global_position) < REACT_DISTANCE
	match _state:
		State.IDLE:
			_timer -= delta
			if near:
				_react()
			elif _timer <= 0.0:
				_start_move(randf() < 0.25)
		State.WAVE:
			_timer -= delta
			if _player:
				forward = forward.lerp(_along(_player.global_position - global_position, up), minf(1.0, 4.0 * delta)).normalized()
			if _timer <= 0.0:
				_start_idle()
		State.MOVE:
			_timer -= delta
			if near and _speed < RUN_SPEED:
				_react()
			elif _timer <= 0.0:
				_start_idle()
			else:
				_turning = clampf(_turning + randf_range(-3.0, 3.0) * delta, -1.0, 1.0)
				forward = forward.rotated(up.normalized(), _turning * delta * 1.2)
				_step(_speed * delta)
	_orient(delta)


# One step along the surface: climb what's ahead, follow the surface underneath, or roll over an edge.
func _step(dist: float) -> void:
	var space := get_world_3d().direct_space_state
	var here := global_position
	# A wall (or anything steep) right ahead: climb onto it, or turn back if it's not a climber
	var ahead := _ray(space, here + up * 0.12, here + up * 0.12 + forward * LOOK)
	if ahead and ahead.normal.dot(up) < 0.7:
		if climbs or ahead.normal.dot(Vector3.UP) > 0.5:
			var old_up := up
			up = (ahead.normal as Vector3).normalized()
			forward = _along(old_up, up)
			global_position = ahead.position
		else:
			_bounce()
		return
	var next := here + forward * dist
	var under := _ray(space, next + up * PROBE, next - up * PROBE)
	if under:
		if under.normal.dot(up) < 0.25:               # a sudden corner underfoot is a wall, handled from ahead
			_bounce()
			return
		up = up.lerp((under.normal as Vector3).normalized(), 0.5).normalized()
		forward = _along(forward, up)
		global_position = under.position
		return
	# Nothing underneath: over the top of a wall onto a roof, or round any outside corner
	var past := next - up * 0.25
	var round_edge := _ray(space, past, past - forward * 0.6)
	if round_edge and climbs:
		var old_up := up
		up = (round_edge.normal as Vector3).normalized()
		forward = _along(-old_up, up)
		global_position = round_edge.position
	else:
		_bounce()


func _bounce() -> void:
	forward = -forward
	_start_idle()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit and not LittleAliens.walkable(hit):
		return {}
	return hit


func _orient(delta: float) -> void:
	# Up is the surface, +Z is the way it's going; smoothed so corners look like a little hop round
	var f := _along(forward, up)
	var target := Basis(up.cross(f), up, f).orthonormalized()
	var q := global_transform.basis.get_rotation_quaternion().slerp(target.get_rotation_quaternion(),
			minf(1.0, TURN * delta))
	global_transform.basis = Basis(q).scaled(Vector3.ONE * SIZE)


static func _along(v: Vector3, n: Vector3) -> Vector3:
	# v flattened onto the surface with normal n (any sideways direction if v points straight off it)
	var t := v - n * v.dot(n)
	if t.length() < 0.001:
		t = n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.FORWARD)
	return t.normalized()


func _react() -> void:
	_cooldown = 7.0
	if randf() < 0.5:
		_state = State.WAVE
		_timer = 2.4
		_play("wave")
	else:
		# Off it scurries, away from the player
		forward = _along(global_position - _player.global_position, up)
		_start_move(true)
		_timer = randf_range(1.5, 3.0)


func _start_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(1.0, 4.5)
	_play("idle")


func _start_move(running: bool) -> void:
	_state = State.MOVE
	_speed = RUN_SPEED if running else WALK_SPEED
	_timer = randf_range(1.0, 2.5) if running else randf_range(2.5, 7.0)
	_turning = randf_range(-0.6, 0.6)
	_play("run" if running else "walk")


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim):
		_anim.play(anim, 0.2, 1.6 if anim == "walk" else 1.0)
