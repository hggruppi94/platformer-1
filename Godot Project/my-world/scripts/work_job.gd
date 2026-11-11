extends RefCounted

# Someone really doing their job (Hayden, day 1 playtest: "I want characters who are performing actions to actually
# be in the locations and performing those actions (librarian climbing a ladder and grabbing a book from a
# bookshelf)"). A routine block with "do": "work" and "job": "<id>" (scripts/routine.gd) hands its person to one of
# these: they go round the job's steps in res://routines/jobs.json, over and over, for as long as the block lasts.
#
# A job has a frame (a building or thing in the scene by name, like the "Library", or a spot in the world: "at" and
# "yaw"), the props it needs there (made by scripts/work_props.gd, put in once when the scene loads, whether or not
# anyone is at work), and its steps. Each step, in the frame's own coordinates (+Z is the building's front):
#
#   {"to": [x, z] (or [x, y, z] for up a floor), "via": [[x, z], ...] (corners to walk round first),
#    "look": [x, z] (what to face), "pose": "reach_high" (scripts/work_pose.gd), "time": 4 (seconds),
#    "climb": 1.2 (up a ladder first, metres), "hold": "broom" (in hand for this step only),
#    "take": "book" (picked up at the end of the step and carried), "drop": true (put down at the end)}
#
# A job can also have "in" and "out": corners walked only on the way into the workplace and on the way out to
# wherever the routine goes next (round to the back of a stall, say), so the loop itself doesn't go round them.
#
# They walk straight from step to step inside the workplace (the steps are laid out round the furniture, and
# tools/test_work.gd checks every walk and every spot), not along the town's paths. While someone talks to them they
# put their arms down and listen, and pick up where they left off.

const WORK_POSE := preload("res://scripts/work_pose.gd")
const PROPS := preload("res://scripts/work_props.gd")
const FILE := "res://routines/jobs.json"
const WALK_SPEED := 0.75                 # of their routine's walking speed: pottering about, not off somewhere
const CLIMB_SPEED := 0.6                 # metres a second up or down a ladder
const TURN := 7.0

enum { WALK, TURN_TO, CLIMB_UP, DO, CLIMB_DOWN }

static var _jobs := {}
static var _loaded := false

var routine: Node
var body: Node3D
var id := ""
var job := {}
var steps: Array = []
var frame: Node3D
var step := 0
var state := WALK
var t := 0.0                             # seconds into the step's work
var up := 0.0                            # metres up a ladder
var held := ""                           # what they're carrying from step to step
var _held_node: Node3D
var _step_node: Node3D                   # what they hold for this step only
var _path: Array[Vector3] = []
var _floor_y := 0.0
var _pose: Node
var _space: PhysicsDirectSpaceState3D
var _skip: Array[RID] = []


# -----------------------------------------------------------------------------
# The jobs file, frames and props
# -----------------------------------------------------------------------------
static func jobs() -> Dictionary:
	if not _loaded:
		_loaded = true
		var res := load(FILE) as JSON if ResourceLoader.exists(FILE) else null
		if res and res.data is Dictionary:
			for k in res.data:
				if not str(k).begins_with("_"):
					_jobs[str(k)] = res.data[k]
	return _jobs


static func frame_of(job_id: String, scene: Node) -> Node3D:
	# The workplace's frame in this scene: a node by name, or a spot made for it ("at" and "yaw", on the ground)
	var j: Dictionary = jobs().get(job_id, {})
	if j.is_empty() or scene == null:
		return null
	if j.has("frame"):
		var name := str(j.frame)
		var n := scene.get_node_or_null(NodePath(name)) as Node3D
		if n == null:
			n = scene.find_child(name, true, false) as Node3D
		return n
	if j.has("at"):
		var own := scene.get_node_or_null("Work Frame " + job_id) as Node3D
		if own:
			return own
		own = Node3D.new()
		own.name = "Work Frame " + job_id
		scene.add_child(own)
		var at: Array = j.at
		var p := Vector3(float(at[0]), 0, float(at[1]))
		var space := (scene as Node3D).get_world_3d().direct_space_state if scene is Node3D else null
		if space:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 120.0, p + Vector3.DOWN * 60.0)
			q.exclude = TownPaths.skip_rids(scene)
			var hit := space.intersect_ray(q)
			if hit:
				p.y = hit.position.y
		own.global_position = p
		own.rotation.y = deg_to_rad(float(j.get("yaw", 0.0)))
		return own
	return null


static func ensure_props(job_id: String, scene: Node) -> void:
	# Put the job's things in its workplace, once per scene (whoever works there sees to it)
	var f := frame_of(job_id, scene)
	if f == null or f.has_meta("work_props_" + job_id):
		return
	f.set_meta("work_props_" + job_id, true)
	var j: Dictionary = jobs().get(job_id, {})
	for p in j.get("props", []):
		var prop := PROPS.make(str(p.kind), p)
		prop.name = "%s %s" % [prop.name, job_id]
		var at: Array = p.get("at", [0, 0])
		prop.position = Vector3(float(at[0]), float(at[1]) if at.size() > 2 else 0.0, float(at[at.size() - 1]))
		prop.rotation.y = deg_to_rad(float(p.get("yaw", 0.0)))
		prop.add_to_group("work_props")
		prop.set_meta("job", job_id)
		f.add_child(prop)


static func local_point(a: Array) -> Vector3:
	# [x, z] or [x, y, z] in a frame
	if a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3(float(a[0]), 0.0, float(a[1]))


static func pose_of(who: Node3D) -> Node:
	# The working-pose modifier on their skeleton (made the first time it's wanted)
	var skel: Skeleton3D = null
	var model := who.get_node_or_null("Model")
	for s in (model if model else who).find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel == null:
		return null
	var p := skel.get_node_or_null("WorkPose")
	if p == null:
		p = WORK_POSE.new()
		p.name = "WorkPose"
		skel.add_child(p)
	return p


# -----------------------------------------------------------------------------
# Starting, stopping
# -----------------------------------------------------------------------------
func _init(r: Node, block: Dictionary) -> void:
	routine = r
	body = r.get("_body")
	id = str(block.get("job", ""))
	job = jobs().get(id, {})
	steps = job.get("steps", [])
	var scene := body.get_tree().current_scene if body.is_inside_tree() else null
	frame = frame_of(id, scene)
	if frame:
		ensure_props(id, scene)
	_space = body.get_world_3d().direct_space_state
	_skip = r.get("_skip")
	_pose = pose_of(body)


func ok() -> bool:
	return frame != null and not steps.is_empty()


func begin() -> void:
	# Arrived at the workplace: off to the first step
	step = 0
	_start_step(true)


func snap() -> void:
	# Already at work (nobody watching, a time jump): somewhere in the middle of a step, carrying what they'd carry
	step = randi() % steps.size()
	var carrying := _held_before(step)
	_set_held(carrying)
	for k in steps.size():
		var ks: Dictionary = steps[k]
		if ks.has("pick"):
			_show_prop_part(str(ks.pick), carrying == "")
	var s: Dictionary = steps[step]
	body.global_position = spot(step)
	_floor_y = body.global_position.y
	up = float(s.get("climb", 0.0))
	body.global_position.y += up
	_face_now(s)
	state = DO
	t = randf() * _time(s)
	_begin_doing(s)


func stop() -> void:
	# The block's over: down off the ladder, things put back, hands empty, arms down
	if up > 0.0:
		body.global_position.y = _floor_y
		up = 0.0
	if held != "" and frame:
		for s in steps:
			if s.has("pick"):
				_show_prop_part(str(s.pick), true)
	_set_held("")
	_clear_step_item()
	if _pose:
		_pose.set_pose("")


func listen() -> void:
	# Someone's talking to them: arms down (the routine stops them and turns them round)
	if _pose:
		_pose.set_pose("")


# -----------------------------------------------------------------------------
# Where things are
# -----------------------------------------------------------------------------
func world(local: Vector3) -> Vector3:
	return frame.global_transform * local


func spot(i: int) -> Vector3:
	# Where they stand for step i, on the floor there
	var s: Dictionary = steps[i]
	return _floor_at(world(local_point(s.get("to", [0, 0]))))


func _floor_at(p: Vector3) -> Vector3:
	return TownPaths.ground_at(p, _space, _skip, 1.0)


func _held_before(i: int) -> String:
	# What they'd be carrying when step i starts: the last thing taken before it and not put down
	var h := ""
	for k in i:
		var s: Dictionary = steps[k]
		if s.has("take"):
			h = str(s.take)
		if s.get("drop", false):
			h = ""
	return h


func _time(s: Dictionary) -> float:
	return float(s.get("time", 4.0))


# -----------------------------------------------------------------------------
# Every frame (the routine calls this while the block is on and they're not talking)
# -----------------------------------------------------------------------------
func tick(delta: float) -> void:
	if not ok():
		return
	var s: Dictionary = steps[step]
	match state:
		WALK:
			_walk(delta)
		TURN_TO:
			_set_pose(PROPS.hold_pose(held))
			routine.call("_play", "idle")
			if _turn(s, delta):
				if float(s.get("climb", 0.0)) > 0.0:
					state = CLIMB_UP
				else:
					state = DO
					t = 0.0
					_begin_doing(s)
		CLIMB_UP:
			_set_pose("climb")
			routine.call("_play", routine.get("move_anim"), 0.6)
			var top := float(s.get("climb", 0.0))
			up = minf(up + CLIMB_SPEED * delta, top)
			body.global_position.y = _floor_y + up
			if up >= top:
				state = DO
				t = 0.0
				_begin_doing(s)
		DO:
			_set_pose(str(s.get("pose", "")))
			routine.call("_play", str(s.get("anim", "idle")))
			t += delta
			if t >= _time(s):
				_end_doing(s)
				if up > 0.0:
					state = CLIMB_DOWN
				else:
					_next()
		CLIMB_DOWN:
			_set_pose("climb")
			routine.call("_play", routine.get("move_anim"), 0.6)
			up = maxf(up - CLIMB_SPEED * delta, 0.0)
			body.global_position.y = _floor_y + up
			if up <= 0.0:
				_next()


func way_out() -> Array[Vector3]:
	# The corners to walk round on the way out, in the world, before the town's paths take over
	var out: Array[Vector3] = []
	for v in job.get("out", []):
		out.append(_floor_at(world(local_point(v))))
	return out


func _next() -> void:
	step = (step + 1) % steps.size()
	_start_step(false)


func _start_step(first: bool) -> void:
	var s: Dictionary = steps[step]
	_path.clear()
	for v in s.get("via", []):
		_path.append(_floor_at(world(local_point(v))))
	_path.append(spot(step))
	if first:
		# From wherever the routine's path left them (a doorway, the middle of the room), round the way in
		var way_in: Array[Vector3] = []
		for v in job.get("in", []):
			way_in.append(_floor_at(world(local_point(v))))
		way_in.append_array(_path)
		_path = way_in
	state = WALK
	up = 0.0


func _walk(delta: float) -> void:
	_set_pose(PROPS.hold_pose(held))
	if _path.is_empty():
		state = TURN_TO
		_floor_y = body.global_position.y
		return
	var target := _path[0]
	var to := Vector3(target.x - body.global_position.x, 0, target.z - body.global_position.z)
	var step_len := float(routine.get("speed")) * WALK_SPEED * delta
	if to.length() <= maxf(step_len, 0.08):
		body.global_position = Vector3(target.x, body.global_position.y, target.z)
		_path.remove_at(0)
	else:
		body.global_position += to.normalized() * step_len
		body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), minf(1.0, TURN * delta))
	body.global_position = _floor_at(body.global_position)
	routine.call("_play", routine.get("move_anim"), 0.8)


func _look_yaw(s: Dictionary) -> float:
	if not s.has("look"):
		return NAN
	var at := world(local_point(s.look))
	var to := at - body.global_position
	return atan2(to.x, to.z)


func _turn(s: Dictionary, delta: float) -> bool:
	var yaw := _look_yaw(s)
	if is_nan(yaw):
		return true
	body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(1.0, TURN * delta))
	return absf(wrapf(body.rotation.y - yaw, -PI, PI)) < 0.06


func _face_now(s: Dictionary) -> void:
	var yaw := _look_yaw(s)
	if not is_nan(yaw):
		body.rotation.y = yaw


func _begin_doing(s: Dictionary) -> void:
	if s.has("hold"):
		_clear_step_item()
		_step_node = _attach(str(s.hold))


func _end_doing(s: Dictionary) -> void:
	_clear_step_item()
	if s.get("drop", false):
		_set_held("")
	if s.has("take"):
		_set_held(str(s.take))
	# A thing taken from where it stands (Bramble's watering can off its rest) goes, and comes back when put down
	if s.has("pick"):
		_show_prop_part(str(s.pick), false)
	if s.has("put"):
		_show_prop_part(str(s.put), true)


func _show_prop_part(part: String, on: bool) -> void:
	for p in frame.get_children():
		if p.is_in_group("work_props") and p.get_meta("job", "") == id:
			var n := p.find_child(part, true, false) as Node3D
			if n:
				n.visible = on


func _set_pose(p: String) -> void:
	if _pose:
		_pose.set_pose(p)


# -----------------------------------------------------------------------------
# Things in their hands
# -----------------------------------------------------------------------------
func _set_held(kind: String) -> void:
	if kind == held and (_held_node != null or kind == ""):
		return
	held = kind
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	if kind != "":
		_held_node = _attach(kind)


func _clear_step_item() -> void:
	if _step_node:
		_step_node.queue_free()
		_step_node = null


func _attach(kind: String) -> Node3D:
	# One-handed things in the right hand (carried by its bone); two-handed ones in front of the chest, at the height
	# the carry pose holds the hands (carried by the chest bone, so they lean with it)
	var skel: Skeleton3D = _pose.get_skeleton() if _pose else null
	var item := PROPS.hand(kind)
	if skel == null:
		body.add_child(item)
		item.position = Vector3(0, 0.8, 0.35)
		return item
	var two := PROPS.two_handed(kind)
	var bone := skel.find_bone("chest" if two else "hand.R")
	if bone < 0:
		bone = 0
	var holder := BoneAttachment3D.new()
	holder.name = "Work " + kind
	holder.bone_name = skel.get_bone_name(bone)
	skel.add_child(holder)
	var rest := skel.get_bone_global_rest(bone)
	var place := Node3D.new()
	place.transform = rest.affine_inverse()
	holder.add_child(place)
	place.add_child(item)
	if two:
		var ua := skel.find_bone("upper_arm.L")
		var ub := skel.find_bone("upper_arm.R")
		var hand := skel.find_bone("hand.R")
		var shoulders := (skel.get_bone_global_rest(ua).origin + skel.get_bone_global_rest(ub).origin) / 2.0 if ua >= 0 and ub >= 0 else rest.origin
		var arm := skel.get_bone_global_rest(ub).origin.distance_to(skel.get_bone_global_rest(hand).origin) if ub >= 0 and hand >= 0 else 0.4
		var low := PROPS.hold_pose(kind) == "carry_low"
		item.position = shoulders + Vector3(0, (-0.55 if low else -0.35) * arm + 0.04, (0.5 if low else 0.55) * arm)
		item.scale = Vector3.ONE / skel.global_basis.get_scale()
	else:
		item.position = rest.origin + Vector3(0, -0.02, 0)
		item.scale = Vector3.ONE / skel.global_basis.get_scale()
	# The pie in its dish: pale dough going in, golden coming out
	var pie := item.find_child("Pie", true, false) as MeshInstance3D
	if pie and kind == "pie_tray" and _raw_pie():
		pie.material_override = PROPS.mat(PROPS.DOUGH)
	return holder


func _raw_pie() -> bool:
	# The pie they carry to the oven is raw; the one they take out is baked
	for k in range(step, steps.size()):
		var s: Dictionary = steps[k]
		if s.get("drop", false):
			return bool(s.get("into_oven", false))
	return false
