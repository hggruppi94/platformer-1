extends Node

# A daily routine: put one under a character (scenes/town/characters.tscn) and they follow the schedule in
# res://routines/<character_id>.json (see res://routines/README.md), driven by the Clock autoload.
#
# Each block of the day says where they go and what they do there: stand about, wander nearby, nap, walk or ride a
# loop of places, follow someone, or be away (asleep at home, inside): then they're not in town at all.
# When a block starts and Nina is near enough to see, they walk (or skate, or ride) there along the town's paths
# (scripts/town_paths.gd). If she's far off, or the time just jumped (sleeping, loading a save, arriving from inside),
# they simply are where they should be.
#
# Rex and Rook (scripts/wanderer.gd) keep their own wandering and barking for "wander" blocks; for everything else
# the routine holds them. While someone is talking to Nina, the routine waits.
#
# A quest step can move someone for an event while it's on (Rex's rally at the fountain: scripts/quests.gd,
# "override"): that block takes over from the schedule until the step's done or its time is over.

@export var character_id := ""
@export var bike_path: NodePath                    # Dash: the bike he rides, and parks next to him when he stops

const NEAR := 55.0                                  # metres: closer than this to Nina, people walk instead of popping
const ARRIVE := 0.35
const TURN_SPEED := 6.0
const LAKE_Y := -0.4                                # ground lower than this is the lake: don't wander into it
const BIKE_PARK := Vector3(1.1, 0.0, 0.5)           # where the bike stands next to Dash when he's off it

var blocks: Array = []                              # {at, place, do, radius, route, pause, who, face, label}
var speed := 1.4
var move_anim := "walk"
var follow_anim := "run"
var rides := false                                  # rides the bike whenever he's moving

var _body: Node3D
var _bike: Node3D
var _anim: AnimationPlayer
var _bike_anim: AnimationPlayer
var _talk: Area3D
var _paths: TownPaths
var _space: PhysicsDirectSpaceState3D
var _skip: Array[RID] = []
var _block := -1
var _override := {}                                 # a quest event's block, while it's on
var _ready_to_go := false
var _jumped := true                                 # snap on the first frame
var _path: Array[Vector3] = []                      # points still to walk through
var _travelling := false
var _present := true
var _wait := 0.0                                    # pausing (at a patrol stop, between wander spots)
var _route_i := 0
var _rest_yaw := NAN
var _playing := ""


func _ready() -> void:
	add_to_group("routines")
	_body = get_parent() as Node3D
	_anim = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_talk = _body.get_node_or_null("Talk") as Area3D
	if not bike_path.is_empty():
		_bike = get_node_or_null(bike_path) as Node3D
		if _bike:
			_bike_anim = _bike.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in _anim.get_animation_list():
			if a != "bark" and a != "growl":
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	if _bike_anim:
		for a in _bike_anim.get_animation_list():
			_bike_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_load()
	_paths = TownPaths.get_shared()
	Clock.jumped.connect(func() -> void: _jumped = true)


func _load() -> void:
	var path := "res://routines/%s.json" % character_id
	var res := load(path) as JSON if ResourceLoader.exists(path) else null
	if res == null or not res.data is Dictionary:
		push_warning("Routine: no schedule for '%s' (%s)" % [character_id, path])
		return
	var data: Dictionary = res.data
	speed = float(data.get("speed", speed))
	move_anim = str(data.get("move_anim", move_anim))
	follow_anim = str(data.get("follow_anim", follow_anim))
	rides = bool(data.get("rides", false))
	for b in data.get("blocks", []):
		var block: Dictionary = b.duplicate()
		block["at"] = Clock.parse_time(str(b.get("at", "00:00")))
		blocks.append(block)
	blocks.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.at < y.at)


# -----------------------------------------------------------------------------
# What they're up to (Dialogue asks, for lines like "Out for my ride!")
# -----------------------------------------------------------------------------
func current_block() -> Dictionary:
	if not _override.is_empty():
		return _override
	return blocks[_block] if _block >= 0 and _block < blocks.size() else {}


func place() -> String:
	return "" if _travelling else str(current_block().get("place", ""))


func activity() -> String:
	# The block's label if it has one ("riding", "campaigning"), else what it does ("wander", "away")
	var b := current_block()
	return str(b.get("label", b.get("do", "")))


func is_travelling() -> bool:
	return _travelling


func is_present() -> bool:
	return _present


static func block_index_at(list: Array, minutes: float) -> int:
	# The block that's on at this time of day: the last one that has started (yesterday's last one before the first)
	if list.is_empty():
		return -1
	var i := list.size() - 1
	for k in list.size():
		if list[k].at <= minutes:
			i = k
	return i


# -----------------------------------------------------------------------------
# Every frame
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if blocks.is_empty():
		return
	if not _ready_to_go:
		_space = (_body as Node3D).get_world_3d().direct_space_state
		_skip = TownPaths.skip_rids(get_tree().current_scene if get_tree().current_scene else _body.owner)
		_ready_to_go = true
	_hold(_body.get("talking") or _travelling or not _present or not _self_wandering())
	if _body.get("talking"):
		_play("idle")
		return
	var i := block_index_at(blocks, Clock.minutes)
	var o := Quests.override_for(character_id)
	if i != _block or _jumped or o != _override:
		var was := _block
		_block = i
		_override = o
		if _jumped or was == -1 or not _near():
			snap()
		else:
			_go_to(current_block())
		_jumped = false
	if _travelling:
		_walk(delta)
	else:
		_do(delta)
	_hold(_body.get("talking") or _travelling or not _present or not _self_wandering())
	_update_bike()


func _self_wandering() -> bool:
	# Rex and Rook (scripts/wanderer.gd) do "wander" blocks themselves
	return current_block().get("do", "") == "wander" and "_home" in _body


func _near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var dest := _destination(current_block())
	return _body.global_position.distance_to(player.global_position) < NEAR \
		or dest.distance_to(player.global_position) < NEAR


func _destination(b: Dictionary) -> Vector3:
	var name := str(b.get("place", ""))
	if b.get("do", "") == "patrol" and not b.get("route", []).is_empty():
		name = str(b.route[0])
	elif b.get("do", "") == "follow":
		var t := _leader(b)
		if t:
			return t._body.global_position
	if not _paths.has(name):
		return _body.global_position
	return _paths.position_of(name, _space, _skip)


func snap() -> void:
	# Be wherever the current block says, straight away
	var b := current_block()
	_travelling = false
	_path.clear()
	_wait = 0.0
	_route_i = 0
	var pos := _destination(b)
	if b.get("do", "") == "follow":
		# Next to wherever the leader's own schedule puts them now (they may not have snapped there yet)
		var t := _leader(b)
		if t:
			var theirs: Dictionary = t.blocks[block_index_at(t.blocks, Clock.minutes)] if not t.blocks.is_empty() else {}
			if theirs.get("do", "") != "away" and _paths.has(str(theirs.get("place", ""))):
				pos = _paths.position_of(str(theirs.place), _space, _skip) + Vector3(1.8, 0, 1.8)
				pos = TownPaths.ground_at(pos, _space, _skip, 4.0)
			else:
				pos = _paths.position_of(str(b.get("place", "")), _space, _skip)
	_body.global_position = pos
	if _body is CharacterBody3D:
		(_body as CharacterBody3D).velocity = Vector3.ZERO
	_arrive()


func _go_to(b: Dictionary) -> void:
	# Walk to the block's place along the town's paths
	_wait = 0.0
	_route_i = 0
	if b.get("do", "") == "follow":
		_travelling = false
		_set_present(true)
		_arrive()
		return
	var dest_name := str(b.get("place", ""))
	if b.get("do", "") == "patrol" and not b.get("route", []).is_empty():
		dest_name = str(b.route[0])
	_set_present(true)
	_start_path(dest_name)


func _start_path(dest_name: String) -> void:
	_path.clear()
	var from := _paths.nearest(_body.global_position)
	for name in _paths.route(from, dest_name):
		_path.append(_paths.position_of(name, _space, _skip))
	# Already standing at the first point: skip it
	if _path.size() > 1 and _flat(_path[0] - _body.global_position).length() < 2.0:
		_path.remove_at(0)
	_travelling = not _path.is_empty()
	if not _travelling:
		_arrive()


func _walk(delta: float) -> void:
	if _path.is_empty():
		_travelling = false
		_arrive()
		return
	var target := _path[0]
	var to := _flat(target - _body.global_position)
	var step := speed * delta
	if to.length() <= maxf(step, ARRIVE):
		_body.global_position = Vector3(target.x, _body.global_position.y, target.z)
		_path.remove_at(0)
	else:
		_body.global_position += to.normalized() * step
		_face(to, delta)
	_body.global_position = TownPaths.ground_at(_body.global_position, _space, _skip)
	_play("ride" if rides else move_anim)


func _arrive() -> void:
	# Starting what the block says to do, at its place
	var b := current_block()
	_travelling = false
	var doing := str(b.get("do", "idle"))
	_set_present(doing != "away")
	_rest_yaw = NAN
	if b.has("face"):
		var f: Array = b.face
		var to := Vector3(float(f[0]), 0, float(f[1])) - _body.global_position
		_rest_yaw = atan2(to.x, to.z)
	if doing == "wander" and "_home" in _body:
		_body.set("_home", _body.global_position)                # Rex and Rook wander on their own
		_body.set("wander_radius", float(b.get("radius", 5.0)))


func _do(delta: float) -> void:
	var b := current_block()
	match str(b.get("do", "idle")):
		"away":
			_play("idle")
		"wander":
			if "_home" in _body:
				return                                    # wanderer.gd is doing it
			_wander(b, delta)
		"patrol":
			_patrol(b, delta)
		"follow":
			_follow(b, delta)
		"nap":
			_play("idle", 0.35)
			_face_rest(delta)
		_:
			_play("idle")
			_face_rest(delta)


func _wander(b: Dictionary, delta: float) -> void:
	# Little walks to random spots near the block's place, with a rest in between
	if _wait > 0.0:
		_wait -= delta
		_play("idle")
		return
	if _path.is_empty():
		var home := _paths.position_of(str(b.get("place", "")), _space, _skip)
		var r := float(b.get("radius", 5.0))
		var a := randf() * TAU
		var spot := home + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * r
		spot = TownPaths.ground_at(spot, _space, _skip, 3.0)
		if spot.y < LAKE_Y or _blocked(_body.global_position, spot):
			_wait = 0.5
			return
		_path = [spot]
	var target := _path[0]
	var to := _flat(target - _body.global_position)
	var step := speed * 0.6 * delta
	if to.length() <= maxf(step, ARRIVE):
		_path.clear()
		_wait = randf_range(2.0, 5.0)
		return
	_body.global_position += to.normalized() * step
	_body.global_position = TownPaths.ground_at(_body.global_position, _space, _skip)
	_face(to, delta)
	_play(move_anim, 0.7)


func _patrol(b: Dictionary, delta: float) -> void:
	# Go round the route's places in turn, stopping a moment at each
	var route: Array = b.get("route", [])
	if route.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		_play("idle")
		return
	if _path.is_empty():
		_route_i = (_route_i + 1) % route.size()
		var from := _paths.nearest(_body.global_position)
		for name in _paths.route(from, str(route[_route_i])):
			_path.append(_paths.position_of(name, _space, _skip))
		if _path.size() > 1 and _flat(_path[0] - _body.global_position).length() < 2.0:
			_path.remove_at(0)
		return
	var target := _path[0]
	var to := _flat(target - _body.global_position)
	var step := speed * delta
	if to.length() <= maxf(step, ARRIVE):
		_body.global_position = Vector3(target.x, _body.global_position.y, target.z)
		_path.remove_at(0)
		if _path.is_empty():
			_wait = float(b.get("pause", 3.0))
	else:
		_body.global_position += to.normalized() * step
		_face(to, delta)
	_body.global_position = TownPaths.ground_at(_body.global_position, _space, _skip)
	_play("ride" if rides else move_anim)


func _follow(b: Dictionary, delta: float) -> void:
	# Tag along a couple of steps behind someone (Rook after Rex or Dash). If they're away, wait at the block's place.
	var t := _leader(b)
	if t == null or not t.is_present():
		_play("idle")
		return
	var to := _flat(t._body.global_position - _body.global_position)
	var d := to.length()
	if d > 25.0:
		snap()                                        # lost him: catch up out of sight
		return
	if d > 3.0:
		var step := speed * (1.6 if d > 6.0 else 1.0) * delta
		var next := _body.global_position + to.normalized() * step
		next = TownPaths.ground_at(next, _space, _skip)
		if next.y > LAKE_Y:
			_body.global_position = next
		_face(to, delta)
		_play(follow_anim if d > 6.0 else move_anim)
	else:
		_face(to, delta)
		_play("idle")


func _leader(b: Dictionary) -> Node:
	var who := str(b.get("who", ""))
	for r in get_tree().get_nodes_in_group("routines"):
		if r.character_id == who:
			return r
	return null


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _set_present(on: bool) -> void:
	# Away (asleep at home, inside): gone from town. No body to bump into, nobody to talk to.
	if on == _present:
		return
	_present = on
	_body.visible = on
	for c in _body.find_children("*", "CollisionShape3D", true, false):
		if _talk == null or not _talk.is_ancestor_of(c):
			c.set_deferred("disabled", not on)
	if _talk:
		_talk.set_deferred("monitoring", on)
		if not on:
			Dialogue.exit_range(_talk)
			_talk.call("_show", false)
			_talk.call("set_prompt", false)


func _hold(on: bool) -> void:
	if "held" in _body:
		_body.set("held", on)


func _blocked(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.7, to + Vector3.UP * 0.7)
	q.exclude = _skip
	var hit := _space.intersect_ray(q)
	return not hit.is_empty() and not str((hit.collider as Node).get_path()).contains("Terrain")


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), minf(1.0, TURN_SPEED * delta))


func _face_rest(delta: float) -> void:
	if not is_nan(_rest_yaw):
		_body.rotation.y = lerp_angle(_body.rotation.y, _rest_yaw, minf(1.0, TURN_SPEED * delta))


func _play(anim: String, anim_speed := 1.0) -> void:
	if _anim == null:
		return
	if not _anim.has_animation(anim):
		anim = "idle"
	var key := "%s@%s" % [anim, anim_speed]
	if key != _playing:
		_playing = key
		_anim.play(anim, 0.2, anim_speed)


func _update_bike() -> void:
	# On the bike while riding; parked next to him otherwise (by the door when he's home)
	if _bike == null:
		return
	var riding: bool = rides and _present and (_travelling or (current_block().get("do", "") == "patrol" and _wait <= 0.0)) \
		and not _body.get("talking")
	if riding:
		_bike.global_transform = _body.global_transform
	else:
		var park := _body.global_transform * BIKE_PARK
		_bike.global_position = TownPaths.ground_at(park, _space, _skip, 2.0)
		_bike.global_rotation = _body.global_rotation + Vector3(0, 0.6, 0)
	if _bike_anim:
		var a := "ride" if riding else "idle"
		if _bike_anim.current_animation != a:
			_bike_anim.play(a)
