extends Node3D

# A copy of a friend who's walking with you, where their own town self isn't there to do it (portal worlds, the
# castle school, the rooms): made by scripts/party.gd. It walks a few steps behind along the way your feet went (the
# same idea as the centipede in Dark Hollow, scripts/centipede_walker.gd), keeps to the ground, waits where you've
# gone somewhere it can't (up a wall, the sky, deep water), and pops back beside you if it gets left a long way
# behind. Nothing solid, so it never gets in your way.

const TRAIL_EVERY := 0.4                         # metres between remembered footsteps
const TRAIL_MAX := 120
const LOST := 26.0                               # further than this and it catches up out of sight
const WALK := 1.6                                # m/s at the slowest
const TURN := 7.0

var source := ""                                 # a .glb, or "res://scripts/x.gd:method" for a model made in code
var gap := 3.0                                   # how far behind, along your path
var side := 0.0                                  # metres to one side (Nina and Bruno walk side by side)

var model: Node3D
var _anim: AnimationPlayer
var _trail: Array[Vector3] = []
var _player: Node3D
var _playing := ""
var _bob := 0.0


func _ready() -> void:
	model = _load(source)
	if model:
		add_child(model)
		_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player:
		var at := _ground(_player.global_position - _ahead() * gap + _right() * side)
		global_position = at if at != Vector3.INF else _player.global_position
		_trail.append(_player.global_position)


func _load(path: String) -> Node3D:
	if path.contains(".gd:"):
		var bits := path.rsplit(":", true, 1)
		var s := load(bits[0]) as GDScript
		return s.call(bits[1]) as Node3D if s else null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed else null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var feet := _player.global_position
	if _trail.is_empty() or feet.distance_to(_trail[_trail.size() - 1]) >= TRAIL_EVERY:
		_trail.append(feet)
		if _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)
	var flat_d := Vector2(feet.x - global_position.x, feet.z - global_position.z).length()
	if flat_d > LOST:
		var at := _ground(feet - _ahead() * gap + _right() * side)
		if at != Vector3.INF:
			global_position = at
		_play("idle")
		return
	var target := _target()
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := to.length()
	if d > 0.25 and flat_d > gap * 0.8:
		var speed := maxf(WALK, d * 2.2)
		var step := minf(speed * delta, d)
		var next := _ground(global_position + to.normalized() * step)
		if next != Vector3.INF and absf(next.y - global_position.y) < 1.6:
			global_position = next
		else:
			global_position += to.normalized() * step       # (over a gap the trail crossed: keep up anyway)
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, TURN * delta))
		_play("run" if speed > 4.0 else "walk")
	else:
		var look := Vector3(feet.x - global_position.x, 0, feet.z - global_position.z)
		if look.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, TURN * delta))
		_play("idle")
	if _anim == null and model:
		_bob += delta * 6.0                             # (a model with no animations bobs along)
		model.position.y = absf(sin(_bob)) * 0.08 if d > 0.25 else 0.0


func _target() -> Vector3:
	# The point `gap` metres back along your footsteps, nudged to the side
	var left := gap
	var at := _player.global_position
	for i in range(_trail.size() - 1, -1, -1):
		var seg := at.distance_to(_trail[i])
		if seg >= left:
			at = at.lerp(_trail[i], left / seg)
			left = 0.0
			break
		left -= seg
		at = _trail[i]
	return at + _right() * side


func _ahead() -> Vector3:
	# The way the player faces, flat (their Visual turns, not their body: scripts/frost_breath.gd forward())
	var v := _player.get_node_or_null("Visual") as Node3D
	var yaw := v.global_rotation.y if v else _player.global_rotation.y
	return Vector3(sin(yaw), 0, cos(yaw))


func _right() -> Vector3:
	var b := _ahead()
	return Vector3(-b.z, 0, b.x)


func _ground(p: Vector3) -> Vector3:
	# The ground under p, looking from a little above it; INF over nothing
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0), p - Vector3(0, 6.0, 0))
	if _player is CollisionObject3D:
		q.exclude = [(_player as CollisionObject3D).get_rid()]
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3.INF


func _play(want: String) -> void:
	if _anim == null:
		return
	var use := want
	if not _anim.has_animation(use):
		use = "walk" if want == "run" and _anim.has_animation("walk") else ("idle" if _anim.has_animation("idle") else "")
	if use == "" or use == _playing:
		return
	_playing = use
	_anim.get_animation(use).loop_mode = Animation.LOOP_LINEAR
	_anim.play(use, 0.2)
