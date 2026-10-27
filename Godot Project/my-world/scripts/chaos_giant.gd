extends Node3D

# The Agent of Chaos, the giant villain (model: tools/build_chaos_giant.py → models/characters/chaos_giant.glb), out at
# the far northeast edge of town behind the castle hill (scenes/town/characters.tscn). He stomps slowly back and forth
# between two spots, stops to brood, and now and then flings his arms up and lets the chaos out (his "chaos" action).
# When the player comes near he stops, turns to look at them and does it too. He's scenery: he never chases or hurts
# anyone, but he's solid, so nobody can walk through his legs. Models face +Z.

# Hayden may rename him "Agent of Time": this is the one place his name lives (the town map reads it from here).
const NAME := "Agent of Chaos"

@export var patrol_a := Vector3(128, 0, -232)       # the two ends of his walk, in the town's space
@export var patrol_b := Vector3(104, 0, -180)
@export var walk_anim_speed := 0.6                  # a slow, heavy stomp
@export var notice_distance := 28.0                 # how near the player comes before he stops to show off at them

# How far one loop of his walk carries him at play speed 1, before the model's x4 scale (two steps of the walk
# action's 0.77 m stride, tools/build_chaos_giant.py walk()), so his feet don't slide.
const STRIDE_PER_SECOND := 0.77
const TURN_SPEED := 0.8
const CHAOS_LOOPS := 2                              # times through the 2.5 s chaos action each outburst

enum State { WALK, BROOD, CHAOS }

var _state := State.BROOD
var _timer := 2.0
var _to_b := true
var _cooldown := 0.0
var _anim: AnimationPlayer
var _model: Node3D
var _body: CollisionObject3D
var _player: Node3D


func _ready() -> void:
	add_to_group("map_landmarks")
	_model = get_node_or_null("Model") as Node3D
	_body = get_node_or_null("Body") as CollisionObject3D
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("%s: no AnimationPlayer in its model" % name)
		return
	for a in ["idle", "walk", "chaos"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_snap_to_ground()
	_brood(randf_range(1.0, 3.0))


func map_name() -> String:
	return NAME


func _physics_process(delta: float) -> void:
	if _anim == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_cooldown -= delta
	_timer -= delta
	match _state:
		State.WALK:
			var target := patrol_b if _to_b else patrol_a
			var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
			if _player_near():
				_outburst(true)
			elif to.length() < 1.0:
				_to_b = not _to_b
				if randf() < 0.35:
					_outburst(false)
				else:
					_brood(randf_range(3.0, 6.0))
			else:
				_turn_toward(to, delta)
				var speed := STRIDE_PER_SECOND * _scale() * walk_anim_speed
				# He only goes forward once he's mostly facing the way he's going, so he turns on the spot at the ends.
				var facing := Vector3(sin(rotation.y), 0, cos(rotation.y))
				global_position += facing * speed * delta * clampf(facing.dot(to.normalized()), 0.0, 1.0)
				_snap_to_ground()
		State.BROOD:
			if _player_near():
				_outburst(true)
			elif _timer <= 0.0:
				_walk()
		State.CHAOS:
			if _player and _player_near(1.5):
				_turn_toward(_player.global_position - global_position, delta)
			if _timer <= 0.0:
				_brood(randf_range(1.5, 3.0))


func _scale() -> float:
	return _model.scale.y if _model else 1.0


func _player_near(slack := 1.0) -> bool:
	if _player == null or _cooldown > 0.0:
		return false
	return _player.global_position.distance_to(global_position) < notice_distance * slack


func _turn_toward(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)


func _walk() -> void:
	_state = State.WALK
	_play("walk", walk_anim_speed)


func _brood(time: float) -> void:
	_state = State.BROOD
	_timer = time
	_play("idle", 1.0)


func _outburst(at_player: bool) -> void:
	_state = State.CHAOS
	var anim := _anim.get_animation("chaos") if _anim.has_animation("chaos") else null
	_timer = (anim.length if anim else 2.5) * CHAOS_LOOPS
	# Once he's shown off at the player he leaves them be for a while, so standing near him isn't an endless roar.
	_cooldown = 25.0 if at_player else 0.0
	_play("chaos", 1.0)


func _play(anim: String, speed: float) -> void:
	if _anim.has_animation(anim):
		_anim.play(anim, 0.4, speed)


func _snap_to_ground() -> void:
	# The northeast field rolls a little; a ray from just above his feet finds the ground under him (starting low,
	# so it doesn't land on tree tops, and leaving out his own body and the player).
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0)
	var skip: Array[RID] = []
	if _body:
		skip.append(_body.get_rid())
	if _player is CollisionObject3D:
		skip.append((_player as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y
