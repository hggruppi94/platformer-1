extends SceneTree

# Checks people really doing their jobs (scripts/work_job.gd, scripts/work_pose.gd, scripts/work_props.gd,
# res://routines/jobs.json; Hayden's day 1 playtest: "characters who are performing actions to actually be in the
# locations and performing those actions (librarian climbing a ladder and grabbing a book from a bookshelf)"):
#
# - the jobs file: every job a routine names is there, every pose, prop and held thing is one that exists;
# - in Stars Hollow and the Void: every workplace is found, its things are put out, every spot they stand on is on the
#   floor and clear, and every walk between spots goes round the furniture, not through it; nothing put out stands on
#   a path people walk or in a race's lanes;
# - at work: everyone goes round their steps, their arms and legs take the poses, they hold and carry things (the
#   librarian really climbs her ladder and comes down with a book), they stop and listen when talked to and carry on
#   after, and when the work's over they're down off the ladder with empty hands.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_work.gd
#
# Your own save is put aside first (user://save.work_backup.json) and put back at the end.

const WORK_JOB := preload("res://scripts/work_job.gd")
const WORK_POSE := preload("res://scripts/work_pose.gd")
const PROPS := preload("res://scripts/work_props.gd")
const SAVE := "user://save.json"
const BACKUP := "user://save.work_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const EARTH_FAR := Vector3(80, 1, 95)
const VOID_FAR := Vector3(150, 30, 150)
const BODY_R := 0.22                  # how wide someone is, for "is this spot clear"

var failures := 0
var clock: Node
var game: Node
var routines := {}


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	game._resume = {}
	game.pending_message = ""
	_check_file()

	# Stars Hollow
	game.next_spawn = "Entrance"
	clock.day = 1                                       # a Friday: a working day, no fair
	clock.calendar_offset = clock.CALENDAR_START
	clock.set_earth_time(10 * 60.0 + 15.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	_find()
	_player().global_position = EARTH_FAR
	await _settle()
	_check_places("earth")
	await _check_working(["librarian", "baker", "toymaker", "hall_keeper", "diner_cook", "waitress", "hardware",
		"truck_wash", "innkeeper", "bookseller", "antiques"], 100.0)
	clock.set_earth_time(7 * 60.0, true)
	await _settle()
	await _check_working(["grocer"], 40.0)
	clock.set_earth_time(10 * 60.0 + 15.0, true)
	await _settle()
	await _check_ladder()
	await _check_talk("marigold")
	await _check_home_time()

	# The Void
	clock.set_time(1, 8 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(8)
	_find()
	_player().global_position = VOID_FAR
	await _settle()
	_check_places("void")
	await _check_working(["garden_beds"], 50.0)
	_check_garden()
	clock.set_time(1, 13 * 60.0, true)
	await _settle()
	await _check_working(["flower_stall"], 30.0)
	clock.set_time(1, 19 * 60.0, true)
	await _settle()
	await _check_working(["lamplighter"], 60.0)
	await _check_patrol_pose()

	_put_save_back()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)


# -----------------------------------------------------------------------------
# The jobs file
# -----------------------------------------------------------------------------
func _check_file() -> void:
	var jobs: Dictionary = WORK_JOB.jobs()
	check(jobs.size() >= 15, "res://routines/jobs.json has the jobs (%d)" % jobs.size())
	var poses := WORK_POSE.names()
	var bad := []
	for id in jobs:
		var j: Dictionary = jobs[id]
		if not (j.has("frame") or j.has("at")):
			bad.append("%s: no frame" % id)
		if (j.get("steps", []) as Array).size() < 3:
			bad.append("%s: under 3 steps" % id)
		for p in j.get("props", []):
			if not str(p.get("kind", "")) in PROPS.kinds():
				bad.append("%s: prop %s" % [id, p.get("kind")])
		for s in j.get("steps", []):
			var pose := str(s.get("pose", ""))
			if pose != "" and not pose in poses:
				bad.append("%s: pose %s" % [id, pose])
			for k in ["hold", "take"]:
				if s.has(k) and PROPS.hand(str(s[k])).get_child_count() == 0:
					bad.append("%s: %s %s" % [id, k, s[k]])
			if not s.has("to"):
				bad.append("%s: a step with nowhere to stand" % id)
	check(bad.is_empty(), "...every frame, pose, prop and thing held is real: %s" % [bad])
	var missing := []
	var used := {}
	for f in DirAccess.get_files_at("res://routines"):
		if not f.ends_with(".json") or f in ["jobs.json", "places.json", "earth_places.json"]:
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://routines/" + f))
		if not data is Dictionary:
			continue
		for key in data:
			if data[key] is Array:
				for b in data[key]:
					if b is Dictionary and str(b.get("do", "")) == "work":
						used[str(b.get("job", ""))] = true
						if not jobs.has(str(b.get("job", ""))):
							missing.append("%s: %s" % [f, b.get("job", "")])
	check(missing.is_empty(), "every job a routine names is in the file: %s" % [missing])
	var unused := jobs.keys().filter(func(id: String) -> bool: return not used.has(id))
	check(unused.is_empty(), "...and every job in it has someone doing it: %s" % [unused])
	# Every pose gives something for both arms or neither, and moves with time where it should
	var p: Node = WORK_POSE.new()
	var empty := poses.filter(func(n: String) -> bool: return (p.targets(n, 0.4) as Dictionary).is_empty())
	check(empty.is_empty(), "every working pose has its targets: %s" % [empty])
	var still := ["stir", "knead", "sweep", "hammer", "saw", "wipe", "wash"].filter(func(n: String) -> bool:
		return p.targets(n, 0.2) == p.targets(n, 0.7))
	check(still.is_empty(), "...and the busy ones move (stirring goes round, a hammer goes up and down): %s" % [still])
	p.free()


# -----------------------------------------------------------------------------
# The workplaces
# -----------------------------------------------------------------------------
func _jobs_here(world: String) -> Array:
	var out := []
	var jobs: Dictionary = WORK_JOB.jobs()
	for id in jobs:
		if (str(jobs[id].get("world", "earth")) == "void") == (world == "void"):
			out.append(id)
	return out


func _check_places(world: String) -> void:
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(current_scene)
	var paths := TownPaths.get_shared(TownPaths.FILE if world == "void" else TownPaths.EARTH_FILE)
	var no_frame := []
	var no_props := []
	var off_floor := []
	var crowded := []
	var through := []
	var on_paths := []
	for id in _jobs_here(world):
		var j: Dictionary = WORK_JOB.jobs()[id]
		var frame: Node3D = WORK_JOB.frame_of(id, current_scene)
		if frame == null:
			no_frame.append(id)
			continue
		var props := frame.get_children().filter(func(n: Node) -> bool: return n.is_in_group("work_props") and n.get_meta("job", "") == id)
		if props.size() != (j.get("props", []) as Array).size():
			no_props.append("%s (%d of %d)" % [id, props.size(), (j.get("props", []) as Array).size()])
		var steps: Array = j.steps
		var points := []                                # where they stand, and every corner on the way, in order
		for i in steps.size():
			var s: Dictionary = steps[i]
			for v in s.get("via", []):
				points.append([frame.global_transform * WORK_JOB.local_point(v), "%s via" % id])
			var want := frame.global_transform * WORK_JOB.local_point(s.to)
			var at := TownPaths.ground_at(want, space, skip, 1.0)
			if absf(at.y - want.y) > 0.5:
				off_floor.append("%s step %d (%.2f, wanted %.2f)" % [id, i + 1, at.y, want.y])
			var who := _clear(space, skip, at)
			if who != "":
				crowded.append("%s step %d (%s)" % [id, i + 1, who])
			points.append([at, "%s step %d" % [id, i + 1]])
		for i in points.size():
			var a: Vector3 = points[i][0]
			var b: Vector3 = points[(i + 1) % points.size()][0]
			var who := _walk_blocked(space, skip, a, b)
			if who != "":
				through.append("%s -> %s (%s)" % [points[i][1], points[(i + 1) % points.size()][1], who])
		# The way in ends at the first step, and the way out starts from it (both walked once, not round and round)
		for way in ["in", "out"]:
			if not j.has(way):
				continue
			var line := []
			for v in j[way]:
				line.append(TownPaths.ground_at(frame.global_transform * WORK_JOB.local_point(v), space, skip, 1.0))
			var first: Vector3 = points[0][0] if steps[0].get("via", []).is_empty() else points[steps[0].via.size()][0]
			if way == "in":
				line.append(first)
			else:
				line.push_front(first)
			for i in line.size() - 1:
				var who := _walk_blocked(space, skip, line[i], line[i + 1])
				if who != "":
					through.append("%s way %s, corner %d (%s)" % [id, way, i, who])
		# Out of doors, nothing put out stands where people walk between places
		if not str(j.get("frame", "")) in ["Library", "Bakery", "Toy Shop", "Earth Town Hall"]:
			for pr in props:
				var p := (pr as Node3D).global_position
				for l in paths.links:
					var a := paths.points[str(l[0])] as Vector2
					var b := paths.points[str(l[1])] as Vector2
					var d := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b).distance_to(Vector2(p.x, p.z))
					if d < 0.6:
						on_paths.append("%s %s on %s-%s (%.2f m)" % [id, pr.name, l[0], l[1], d])
	check(no_frame.is_empty(), "%s: every workplace is found: %s" % [world, no_frame])
	check(no_props.is_empty(), "%s: ...its things are put out (once): %s" % [world, no_props])
	check(off_floor.is_empty(), "%s: every spot they stand on is on its floor: %s" % [world, off_floor])
	check(crowded.is_empty(), "%s: ...with room to stand (not in a shelf, a table or a wall): %s" % [world, crowded])
	check(through.is_empty(), "%s: every walk between spots goes round things, not through them: %s" % [world, through])
	check(on_paths.is_empty(), "%s: nothing put out stands on a path people walk: %s" % [world, on_paths])
	_check_races(world)


func _check_races(world: String) -> void:
	# Nothing put out is in a race's lanes (the Pumpkin Run goes down Main Street)
	var races := root.get_node_or_null("Races")
	if races == null:
		return
	var in_lanes := []
	for track_id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[track_id]
		var line: Array = tr.get("line", [])
		var on_earth := str(tr.get("scene", "")).contains("earth")
		if line.is_empty() or on_earth != (world == "earth"):
			continue
		for pr in current_scene.get_tree().get_nodes_in_group("work_props"):
			var p := (pr as Node3D).global_position
			for i in line.size():
				var a: Vector2 = _v2(line[i])
				var b: Vector2 = _v2(line[(i + 1) % line.size()])
				if Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b).distance_to(Vector2(p.x, p.z)) < 3.0:
					in_lanes.append("%s in %s" % [pr.name, track_id])
					break
	check(in_lanes.is_empty(), "%s: nothing put out is in a race's lanes: %s" % [world, in_lanes])


func _v2(p) -> Vector2:
	if p is Vector2:
		return p
	if p is Vector3:
		return Vector2(p.x, p.z)
	return Vector2(float(p[0]), float(p[p.size() - 1]))


func _clear(space: PhysicsDirectSpaceState3D, skip: Array[RID], at: Vector3) -> String:
	# Nothing solid where their body would be (a little off the floor, so the floor itself doesn't count)
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_R
	shape.height = 1.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.85)
	q.exclude = skip
	for hit in space.intersect_shape(q, 4):
		var n := hit.collider as Node
		if not _ground(n):
			return str(n.get_path()).get_slice("/", 3) + "/" + n.name
	return ""


func _walk_blocked(space: PhysicsDirectSpaceState3D, skip: Array[RID], a: Vector3, b: Vector3) -> String:
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * BODY_R
	for h in [0.5, 1.2]:
		for off in [Vector3.ZERO, side, -side]:
			var q := PhysicsRayQueryParameters3D.create(a + off + Vector3.UP * h, b + off + Vector3.UP * h)
			q.exclude = skip
			var hit := space.intersect_ray(q)
			if hit and not _ground(hit.collider):
				var n := hit.collider as Node
				var what := str(n.get_path()).get_slice("/", 3) + "/" + (n.get_parent().name if n.name == "Solid" else n.name)
				return "%s at %s" % [what, Vector3(hit.position).snapped(Vector3.ONE * 0.1)]
	return ""


func _ground(n: Object) -> bool:
	var path := str((n as Node).get_path())
	return path.contains("/Land") or path.contains("Terrain") or path.contains("Ground") or path.contains("Plaza") \
		or path.contains("Market Square/StaticBody3D")


# -----------------------------------------------------------------------------
# At work
# -----------------------------------------------------------------------------
func _check_working(ids: Array, seconds: float) -> void:
	# Run the clock still (so nobody's block ends) at 4x for a while and watch everyone at work
	clock.running = false
	var watch := {}
	for r in current_scene.get_tree().get_nodes_in_group("routines"):
		var job = r.get("_job")
		if job and str(job.id) in ids:
			watch[str(job.id)] = {"r": r, "steps": {}, "poses": {}, "held": {}, "low": INF, "start": (r.get_parent() as Node3D).global_position}
	check(watch.size() == ids.size(), "at work: %s (of %s)" % [watch.keys(), ids])
	Engine.time_scale = 4.0
	var frames := int(seconds * 60.0 / 4.0)
	for i in frames:
		await physics_frame
		for id in watch:
			var w: Dictionary = watch[id]
			var job = w.r.get("_job")
			if job == null:
				continue
			w.steps[job.step] = true
			var pose: Node = job.get("_pose")
			if pose and str(pose.pose) != "":
				w.poses[str(pose.pose)] = true
			if str(job.held) != "":
				w.held[str(job.held)] = true
			var body := w.r.get_parent() as Node3D
			w.low = minf(w.low, body.global_position.y - job.frame.global_position.y)
	Engine.time_scale = 1.0
	clock.running = true
	for id in watch:
		var w: Dictionary = watch[id]
		var steps: Array = WORK_JOB.jobs()[id].steps
		var want := mini(steps.size(), 3)
		check(w.steps.size() >= want, "%s: goes round the steps (%d of %d in %d s)" % [id, w.steps.size(), steps.size(), seconds])
		var poses_wanted := {}
		for s in steps:
			if str(s.get("pose", "")) != "":
				poses_wanted[str(s.pose)] = true
		check(w.poses.size() >= mini(2, poses_wanted.size()), "%s: ...really working at them (poses %s)" % [id, w.poses.keys()])
		var carries := steps.any(func(s: Dictionary) -> bool: return s.has("take"))
		if carries:
			check(not w.held.is_empty(), "%s: ...carrying things about (%s)" % [id, w.held.keys()])
		check(w.low > -0.4, "%s: ...never through the floor (lowest %.2f m)" % [id, w.low])


func _check_ladder() -> void:
	# Miss Marigold: up the ladder, a book off the top shelf, down with it
	var r: Node = routines.get("marigold")
	var job = r.get("_job") if r else null
	check(job != null and str(job.id) == "librarian", "10:15: Miss Marigold's at work in the library")
	if job == null:
		return
	var body := r.get_parent() as Node3D
	var ladder: Array = job.frame.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Work Ladder"))
	check(ladder.size() == 1, "...where a ladder leans on the tall shelf")
	clock.running = false
	job.step = 2
	job._next()                                         # off to the ladder
	Engine.time_scale = 4.0
	var top := 0.0
	var book_up := false
	var down_with_book := false
	for i in 60 * 30:
		await physics_frame
		top = maxf(top, job.up)
		if job.up > 0.9 and job.state == WORK_JOB.DO and str(job._pose.pose) == "reach_high":
			book_up = true
		if top > 0.9 and job.up == 0.0 and job.held == "book":
			down_with_book = true
			break
	Engine.time_scale = 1.0
	clock.running = true
	check(top > 1.0, "...she climbs it (%.2f m up)" % top)
	check(book_up, "...and reaches up to the top shelf")
	check(down_with_book, "...and comes down with a book in her hand")
	var item := body.find_child("Work book", true, false)
	check(item != null and item is BoneAttachment3D and (item as BoneAttachment3D).bone_name == "hand.R",
		"...really in her hand (it moves with it)")
	if ladder.size() == 1:
		var foot := (ladder[0] as Node3D).global_position
		check(Vector2(body.global_position.x - foot.x, body.global_position.z - foot.z).length() < 0.8,
			"...at the foot of the ladder")


func _check_talk(id: String) -> void:
	var r: Node = routines.get(id)
	var body := r.get_parent() as Node3D
	var job = r.get("_job")
	clock.running = false
	await _frames(30)
	body.set("talking", true)
	await _frames(20)
	var at := body.global_position
	await _frames(40)
	check(body.global_position.distance_to(at) < 0.02, "%s stops working to listen when talked to" % id)
	check(job._pose == null or str(job._pose.pose) == "", "...arms down")
	body.set("talking", false)
	var moved := false
	var posed := false
	for i in 60 * 12:
		await physics_frame
		if body.global_position.distance_to(at) > 0.05:
			moved = true
		if job._pose and str(job._pose.pose) != "":
			posed = true
		if moved and posed:
			break
	check(moved or posed, "...and gets back to it after")
	clock.running = true


func _check_home_time() -> void:
	# Half past seven: the library's shut and she's gone home, ladder and books left where they belong
	var r: Node = routines.get("marigold")
	var body := r.get_parent() as Node3D
	clock.set_earth_time(19 * 60.0 + 45.0, true)
	await _settle()
	check(r.get("_job") == null, "home time: Miss Marigold's job is over")
	check(body.find_child("Work book", true, false) == null, "...nothing left in her hand")
	var pose := body.find_child("WorkPose", true, false)
	check(pose == null or str(pose.pose) == "", "...arms down")


func _check_garden() -> void:
	# Bramble's beds are hers, beside your garden, not in it
	var farm := root.get_node_or_null("Farm")
	if farm == null:
		return
	var frame: Node3D = WORK_JOB.frame_of("garden_beds", current_scene)
	var half: Vector2 = farm.plot_half()
	var inside := []
	for pr in frame.get_children():
		if not pr.is_in_group("work_props"):
			continue
		var p := (pr as Node3D).global_position
		var d: Vector2 = Vector2(p.x, p.z) - farm.GARDEN
		var local: Vector2 = d.rotated(farm.GARDEN_YAW)
		if absf(local.x) < half.x + 1.5 and absf(local.y) < half.y + 1.5:
			inside.append(pr.name)
	check(inside.is_empty(), "Bramble's own beds stand clear of your garden: %s" % [inside])


func _check_patrol_pose() -> void:
	# A patrol's stop_pose (none use it now Pip's at the lamps, but it still works): set one on Pip's late patrol
	var r: Node = routines.get("pip")
	if r == null:
		return
	clock.set_time(1, 23 * 60.0, true)
	await _settle()
	var b: Dictionary = r.current_block()
	b["stop_pose"] = "reach_both"
	clock.running = false
	Engine.time_scale = 4.0
	var posed := false
	for i in 60 * 20:
		await physics_frame
		var p := (r.get_parent() as Node3D).find_child("WorkPose", true, false)
		if p and str(p.pose) == "reach_both":
			posed = true
			break
	Engine.time_scale = 1.0
	clock.running = true
	b.erase("stop_pose")
	check(posed, "a patrol's stop_pose: Pip reaches up at a stop on the boardwalk")


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _find() -> void:
	routines.clear()
	for r in current_scene.get_tree().get_nodes_in_group("routines"):
		routines[str(r.character_id)] = r


func _player() -> Node3D:
	return current_scene.find_child("Player", true, false) as Node3D


func _settle() -> void:
	for i in 4:
		await physics_frame
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
