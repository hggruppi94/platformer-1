extends "res://scripts/centipede_friend.gd"

# The centipede on the move, on the ground: the same body and face as at home (scripts/centipede_friend.gd), but her
# head goes wherever it's told (step()) and her body follows the head's own trail, segment after segment, like a real
# centipede. Used when she follows you round Dark Hollow (follow = the player, scripts/dark_hollow.gd) and in her boss
# game at home (scripts/centipede_boss.gd, which steers her itself).
#
# top_level, so everything here is placed in world space whatever it's parented to.

const SPACING := 0.42                     # metres between segments, at size 1
const CRUMB := 0.3                        # how far the player moves between the breadcrumbs she follows

var size := 1.0                           # how big she is (the boss game makes her bigger)
var trail: Array[Vector3] = []            # where her head has been, newest first
var head_at := Vector3.ZERO               # the ground under her head
var look_at_player := true
var upside_down := false                  # walking along a ceiling (her corner in the Sliver)

# Following (when follow is set)
var follow: Node3D
var gap := 3.2                            # how far behind you her head stays
var max_speed := 7.5
var _crumbs: Array[Vector3] = []          # your path on the ground, newest first


func _ready() -> void:
	top_level = true
	super._ready()
	global_transform = Transform3D.IDENTITY
	if trail.is_empty():
		place(Vector3.ZERO, 0.0)


func place(at: Vector3, yaw: float) -> void:
	# Lay her out straight, head at `at` facing `yaw`, tail behind
	trail.clear()
	head_at = at
	var back := -Vector3(sin(yaw), 0, cos(yaw))
	var n := int(segments * SPACING * size / 0.1) + 4
	for k in n:
		trail.append(at + back * (k * 0.1))
	_crumbs.clear()
	_lay(0.0)


func step(to: Vector3) -> void:
	# Her head moves to `to` (a point on the ground); the body follows along the trail
	head_at = to
	if trail.is_empty() or to.distance_to(trail[0]) >= 0.08:
		trail.push_front(to)
	var need := segments * SPACING * size + 1.0
	var total := 0.0
	for k in range(1, trail.size()):
		total += trail[k].distance_to(trail[k - 1])
		if total > need:
			trail.resize(k + 1)
			break


func yaw() -> float:
	if trail.size() < 2:
		return 0.0
	var d := trail[0] - trail[mini(4, trail.size() - 1)]
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0


func _point_back(dist: float) -> Array:
	# [position, direction (head-wards)] dist metres back along the trail from the head
	var left := dist
	for k in range(1, trail.size()):
		var a := trail[k - 1]
		var b := trail[k]
		var l := a.distance_to(b)
		if l >= left and l > 0.0001:
			return [a.lerp(b, left / l), (a - b) / l]
		left -= l
	var last := trail[trail.size() - 1]
	var d := (trail[trail.size() - 2] - last).normalized() if trail.size() > 1 else Vector3.FORWARD
	return [last - d * left, d]


func _process(delta: float) -> void:
	_t += delta
	if follow and is_instance_valid(follow):
		_follow(delta)
	_lay(delta)


func _lay(_delta: float) -> void:
	if trail.is_empty():
		return
	for k in _segs.size():
		var pd := _point_back((k + 0.6) * SPACING * size)
		var seg := _segs[k]
		seg.global_position = pd[0]
		var dir: Vector3 = pd[1]
		if Vector2(dir.x, dir.z).length() > 0.01:
			seg.rotation.y = atan2(dir.x, dir.z)
		seg.rotation.z = PI if upside_down else 0.0
		var s := size * (1.0 + 0.05 * sin(_t * 1.6 - k * 0.45))
		seg.scale = Vector3(s, s, s)
	if _head == null:
		return
	_head.scale = Vector3.ONE * size
	var up := -0.5 if upside_down else 1.0
	_head.global_position = head_at + Vector3(0, up * head_height * size + sin(_t * 1.3) * 0.05, 0)
	_head.rotation.z = PI if upside_down else 0.0
	var want := yaw()
	if look_at_player:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player and _player.global_position.distance_to(_head.global_position) < 6.0 * size:
			var to := _player.global_position - _head.global_position
			want = atan2(to.x, to.z)
	_head.rotation.y = lerp_angle(_head.rotation.y, want, minf(1.0, 6.0 * maxf(_delta, 0.016)))


# Following you --------------------------------------------------------------------------------------------------------
func _follow(delta: float) -> void:
	var body := follow as CharacterBody3D
	var feet := _ground(follow.global_position)
	if body == null or body.is_on_floor():
		if _crumbs.is_empty() or feet.distance_to(_crumbs[0]) > 8.0:
			_crumbs.clear()                             # you've been popped somewhere new: start a new path
			_crumbs.append(feet)
		elif feet.distance_to(_crumbs[0]) >= CRUMB:
			_crumbs.push_front(feet)
	if _crumbs.size() > 200:
		_crumbs.resize(200)
	if head_at.distance_to(follow.global_position) > 22.0:
		catch_up()
		return
	# Her goal: `gap` metres back along your path (or straight towards you, short of `gap`)
	var goal := head_at
	var along := 0.0
	var found := false
	for k in range(1, _crumbs.size()):
		along += _crumbs[k].distance_to(_crumbs[k - 1])
		if along >= gap:
			goal = _crumbs[k]
			found = true
			break
	if not found:
		var to := feet - head_at
		to.y = 0.0
		if to.length() > gap:
			goal = head_at + to.normalized() * (to.length() - gap)
	var move := goal - head_at
	if move.length() < 0.05:
		return
	var sp := max_speed * clampf(move.length() / 2.0, 0.3, 1.0)
	var next := head_at + move.normalized() * minf(move.length(), sp * delta)
	next.y = _ground(next).y
	step(next)


func catch_up() -> void:
	# Lost you (a hole spat you out somewhere, say): she scuttles up behind you in a puff of dust
	var at := follow.global_position
	var back := -follow.global_transform.basis.z
	var v := follow.get("visual") as Node3D
	if v:
		back = v.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var spot := _ground(at - back * gap)
	place(spot, atan2(back.x, back.z))
	_crumbs.clear()
	Fx.burst(get_parent(), spot + Vector3(0, 0.4, 0), Color(0.5, 0.4, 0.55), 10, 0.06, 2.0, -1.0, 0.5)


func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.5, 0), at + Vector3(0, -12, 0))
	q.collide_with_areas = false
	q.collision_mask = 1
	var skip: Array[RID] = []
	if follow is CollisionObject3D:
		skip.append((follow as CollisionObject3D).get_rid())
	var p := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if p:
		skip.append(p.get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(at.x, head_at.y, at.z)
