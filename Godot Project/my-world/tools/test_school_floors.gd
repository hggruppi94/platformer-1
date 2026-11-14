extends SceneTree

# Checks the palace school's floors 2 and 3 (tools/build_school.gd, slice 2): the skybridge over the library holds
# her up, the Nova Lab, mezzanine, gadget wall and window seats are there, and the hidden spiral stair from floor 3's
# secret hallway down to Behind the Walls is solid all the way, with room to stand on it. Slice 3 (the roof) and
# slice 4 (the hidden lower level: the Logia chambers, the service tunnels, the maze's hatch, the stair on down to
# them and the pool's plant room) are checked too.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_school_floors.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SCHOOL := "res://scenes/school/school.tscn"
const FLOOR_H := 6.0
const LIBRARY_AT := Vector2(0, -6)          # build_school.gd
const STAIR := Vector2(28.55, -14)          # build_school.gd HIDDEN_STAIR
const STAIR_START := PI / 2                 # where the top step leaves floor 3
const STAIR_TURNS := 6.0                    # floor 3 all the way down to the lower level
const LOW_Y := -6.0                         # build_school.gd LOW_Y, the lower level's floor
const LOGIA := Rect2(-12, -14, 24, 16)      # build_school.gd LOGIA
const PLANT_ROOM := Rect2(40, -38, 20, 8)
const ROOF := 3 * FLOOR_H
const ROOF_HOLE := Rect2(-39, 5.5, 5.5, 12.5)  # build_school.gd ROOF_HOLE

var failures := 0
var school: Node3D
var player
var space: PhysicsDirectSpaceState3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(SCHOOL)
	for i in 5:
		await process_frame
	await _physics(3)
	school = current_scene as Node3D
	player = school.find_child("Player", true, false)
	space = school.get_world_3d().direct_space_state
	check(player != null, "she's in the school")

	# --- What's new on floors 2 and 3 ---
	for path in ["Skybridge", "Floor 2/Nova Lab", "Floor 2/Nova Lab Kit", "Floor 2/Library Mezzanine",
			"Floor 2/Gadget Wall", "Floor 3/Window Seats", "Hidden Stair"]:
		check(school.has_node(path), "%s is there" % path)

	# --- The skybridge: a floor at floor 2's height right across the library's hole ---
	var gaps := []
	for z in range(-12, 1):
		for x: float in [-1.5, 0.0, 1.5]:
			var y := _ground(Vector3(x, FLOOR_H + 3, z))
			if absf(y - FLOOR_H) > 0.25:
				gaps.append(Vector2(x, z))
	check(gaps.is_empty(), "the skybridge holds her up all the way across: gaps at %s" % [gaps])
	check(_ground(Vector3(6, FLOOR_H + 3, -6)) < 1.0, "beside the bridge the library's still open below")

	# --- The hidden stair: solid all the way down, a gentle enough slope, and she can stand on it ---
	var bad := []
	var n := 216
	var r := 0.8
	for k in n + 1:
		var t := float(k) / n
		var a := STAIR_START + TAU * STAIR_TURNS * t
		var want := lerpf(2 * FLOOR_H, LOW_Y, t)
		var p := Vector3(STAIR.x + cos(a) * r, want + 0.6, STAIR.y + sin(a) * r)
		var y := _ground(p)
		if absf(y - want) > 0.2:
			bad.append("t%.2f got %.2f want %.2f" % [t, y, want])
	check(bad.is_empty(), "the stair is solid under every step: %s" % [bad])
	var slope := rad_to_deg(atan((2 * FLOOR_H - LOW_Y) / (TAU * STAIR_TURNS * r)))
	check(slope < 40.0, "the stair's slope where you walk is %.0f degrees" % slope)
	check(absf(_ground(Vector3(STAIR.x, 2 * FLOOR_H + 1, STAIR.y + 2.2)) - 2 * FLOOR_H) < 0.1,
		"floor 3's hallway is there by the top step")
	check(absf(_ground(Vector3(STAIR.x, FLOOR_H + 1, STAIR.y + 2.2)) - FLOOR_H) < 0.1,
		"floor 2's Behind the Walls is there by its landing")
	for t: float in [0.05, 0.15, 0.25, 0.4, 0.6, 0.8, 0.95]:
		var a := STAIR_START + TAU * STAIR_TURNS * t
		var want := lerpf(2 * FLOOR_H, LOW_Y, t)
		player.global_position = Vector3(STAIR.x + cos(a) * r, want + 1.0, STAIR.y + sin(a) * r)   # (her middle: her feet are 0.8 lower)
		player.velocity = Vector3.ZERO
		await _physics(40)
		var at: Vector3 = player.global_position
		check(at.y > want + 0.2 and Vector2(at.x, at.z).distance_to(STAIR) < 2.0,
			"stood on the stair %.0f%% of the way down, she stays on it (y %.2f, want about %.2f)" % [t * 100, at.y, want])

	# --- Up on the roof (slice 3): the escalators reach it, the opening's railed, and it's all solid ---
	for path in ["Floor 4/Sky Pavilion", "Floor 4/Sky Pavilion/Upper Commons", "Floor 4/Palm Terrace",
			"Floor 4/Roof Garden/Gazebo/Telescope", "Atrium/Escalator 3 Up", "Atrium/Escalator 3 Down"]:
		check(school.has_node(path), "%s is there" % path)
	check(absf(_ground(Vector3(-36, 2 * FLOOR_H + 2, 4)) - 2 * FLOOR_H) < 0.1, "a landing off floor 3's balcony for the escalators up")
	check(absf(_ground(Vector3(-37.5, ROOF + 3, ROOF_HOLE.end.y + 0.8)) - ROOF) < 0.15, "the up escalator's top reaches the roof")
	check(_ground(Vector3(-36.2, ROOF + 3, 9)) < ROOF - 1.0, "the roof's open over the escalators")
	check(_hits(Vector3(-36.2, ROOF + 0.6, ROOF_HOLE.position.y - 1), Vector3(-36.2, ROOF + 0.6, ROOF_HOLE.position.y + 1)),
		"a rail keeps her out of the opening from the north")
	check(_hits(Vector3(ROOF_HOLE.end.x + 1, ROOF + 0.6, 12), Vector3(ROOF_HOLE.end.x - 1, ROOF + 0.6, 12)),
		"a rail keeps her out of the opening from the east")
	var roof_holes := []
	for q: Vector2 in [Vector2(16, 10), Vector2(-16, 11), Vector2(2, -14), Vector2(-20, -10), Vector2(20, -18), Vector2(-2, 21)]:
		var y := _ground(Vector3(q.x, ROOF + 10, q.y))
		if y < ROOF - 0.1 or y > ROOF + 6:
			roof_holes.append(q)
	check(roof_holes.is_empty(), "the roof's solid underfoot everywhere tried: %s" % [roof_holes])
	check(_hits(Vector3(16, ROOF + 0.6, 22), Vector3(16, ROOF + 0.6, 26)), "the balustrade keeps her on the roof")

	# --- The hidden lower level (slice 4) ---
	for path in ["Lower Level/Logia Chambers", "Lower Level/Logia Chambers/Round Table", "Lower Level/Logia Chambers/Archive",
			"Lower Level/Service Tunnels/West Tunnel", "Lower Level/Service Tunnels/East Tunnel",
			"Lower Level/Service Tunnels/Stair Tunnel", "Lower Level/Pool Plant Room", "Lower Level/Maze Hatch"]:
		check(school.has_node(path), "%s is there" % path)
	# Floor 1 never sees the stair: it's walled in all round
	var open_sides := []
	for a: float in [0.0, PI / 2, PI, -PI / 2, PI / 4, -3 * PI / 4]:
		var from := Vector3(STAIR.x + cos(a) * 3.0, 1.0, STAIR.y + sin(a) * 3.0)
		if not _hits(from, Vector3(STAIR.x, 1.0, STAIR.y)):
			open_sides.append(a)
	check(open_sides.is_empty(), "on floor 1 the stair is walled in all round: open at %s" % [open_sides])
	var hatch := school.get_node("Lower Level/Maze Hatch") as Node3D
	var h2 := Vector2(hatch.position.x, hatch.position.z)
	var lz := LOGIA.get_center().y
	var walks := {"west": [Vector2(LOGIA.position.x, lz), Vector2(h2.x, lz), Vector2(h2.x, h2.y - 1.4)],
		"east": [Vector2(LOGIA.end.x, lz), Vector2(36, lz), Vector2(36, PLANT_ROOM.get_center().y), Vector2(PLANT_ROOM.position.x, PLANT_ROOM.get_center().y)],
		"stair": [Vector2(STAIR.x, lz), Vector2(STAIR.x, STAIR.y + 1.1)]}
	for wname in walks:
		var pts: Array = walks[wname]
		var no_floor := []
		var low_roof := []
		var blocked := []
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := int(a.distance_to(b))
			for k in steps + 1:
				var q := a.lerp(b, float(k) / maxi(steps, 1))
				if absf(_ground(Vector3(q.x, LOW_Y + 2.0, q.y)) - LOW_Y) > 0.1:
					no_floor.append(q)
				var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, LOW_Y + 1.0, q.y), Vector3(q.x, LOW_Y + 8.0, q.y)))
				if up.is_empty() or (up.position as Vector3).y < LOW_Y + 2.9:
					low_roof.append(q)
			if _hits(Vector3(a.x, LOW_Y + 1.2, a.y), Vector3(b.x, LOW_Y + 1.2, b.y)):
				blocked.append(i)
		check(no_floor.is_empty(), "the %s tunnel has a floor all the way: missing at %s" % [wname, no_floor])
		check(low_roof.is_empty(), "the %s tunnel has a roof, high enough, all the way: wrong at %s" % [wname, low_roof])
		check(blocked.is_empty(), "nothing in the way along the %s tunnel: blocked on legs %s" % [wname, blocked])
	var leaks := []
	for q: Vector3 in [Vector3(-20, lz, 0), Vector3(h2.x, 10, 1), Vector3(20, lz, 0), Vector3(36, -20, 1)]:
		var side := Vector2(1, 0) if q.z > 0.5 else Vector2(0, 1)       # across the tunnel
		for sgn: float in [-1.0, 1.0]:
			if not _hits(Vector3(q.x, LOW_Y + 1.2, q.y), Vector3(q.x + side.x * 2.0 * sgn, LOW_Y + 1.2, q.y + side.y * 2.0 * sgn)):
				leaks.append(Vector2(q.x, q.y))
	check(leaks.is_empty(), "the tunnels are walled in: open at %s" % [leaks])
	check(absf(_ground(Vector3(0, LOW_Y + 4, lz + 5)) - LOW_Y) < 0.1, "the Logia chambers' floor")
	check(absf(_ground(Vector3(PLANT_ROOM.get_center().x, LOW_Y + 2.5, PLANT_ROOM.end.y - 1.5)) - LOW_Y) < 0.1, "the plant room's floor")
	# The hatch: open from above, the lawn round it whole, and its spiral solid all the way down
	var across: float = hatch.get_meta("start") + PI
	check(_ground(Vector3(h2.x + cos(across) * 0.75, 3, h2.y + sin(across) * 0.75)) < -0.5, "the maze's hatch is open from above")
	check(absf(_ground(Vector3(h2.x + 2.6, 0.5, h2.y + 2.6))) < 0.1, "the lawn round the hatch is whole")
	var h_start: float = hatch.get_meta("start")
	var h_turns: float = hatch.get_meta("turns")
	var h_bad := []
	for k in range(1, 97):
		var t := k / 96.0
		var a := h_start + TAU * h_turns * t
		var want := lerpf(0.0, LOW_Y, t)
		var y := _ground(Vector3(h2.x + cos(a) * 0.75, want + 0.6, h2.y + sin(a) * 0.75))
		if absf(y - want) > 0.2:
			h_bad.append("t%.2f got %.2f want %.2f" % [t, y, want])
	check(h_bad.is_empty(), "the hatch's spiral is solid under every step: %s" % [h_bad])
	for t: float in [0.1, 0.5, 0.9]:
		var a := h_start + TAU * h_turns * t
		var want := lerpf(0.0, LOW_Y, t)
		player.global_position = Vector3(h2.x + cos(a) * 0.75, want + 1.0, h2.y + sin(a) * 0.75)
		player.velocity = Vector3.ZERO
		await _physics(40)
		var at: Vector3 = player.global_position
		check(at.y > want + 0.2 and Vector2(at.x, at.z).distance_to(h2) < 2.0,
			"stood on the hatch's spiral %.0f%% of the way down, she stays on it (y %.2f)" % [t * 100, at.y])
	check(not _hits(Vector3(h2.x, LOW_Y + 1.2, h2.y - 1.1), Vector3(h2.x, LOW_Y + 1.2, h2.y - 3.0)),
		"the hatch's shaft opens north into the west tunnel")
	check(not _hits(Vector3(STAIR.x, LOW_Y + 1.2, STAIR.y + 1.1), Vector3(STAIR.x, LOW_Y + 1.2, STAIR.y + 3.0)),
		"the stair's foot opens south into its tunnel")

	# --- The centipede's jumpscare every time she goes in through a Sliver (not on the way back out) ---
	var old_mp: int = game.mp_level
	game.mp_level = 9
	game.stats_changed.emit()
	await _physics(3)
	var slivers := school.find_children("Sliver*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.has_method("jumpscare"))
	check(slivers.size() == 2, "both Slivers are there")
	for sl in slivers:
		var behind: Vector3 = sl.behind_dir()
		var base: Vector3 = sl.global_position
		var before: int = sl.scares
		player.global_position = base - behind * 4.0 + Vector3(0, 0.9, 0)
		player.velocity = Vector3.ZERO
		await _physics(6)
		player.global_position = base - behind * 0.6 + Vector3(0, 0.9, 0)
		await _physics(6)
		check(sl.scares == before + 1 and sl.has_node("Jumpscare"), "going in at %s, the centipede jumps out" % [sl.get_path()])
		var head := sl.get_node_or_null("Jumpscare") as Node3D
		await _physics(20)
		if head:
			check(absf((head.global_position - base).dot(behind)) < 1.0, "it pops out right at the Sliver")
		await create_timer(1.5).timeout
		check(not sl.has_node("Jumpscare"), "then it's gone again")
		player.global_position = base + behind * 4.0 + Vector3(0, 0.9, 0)
		await _physics(6)
		player.global_position = base + behind * 0.6 + Vector3(0, 0.9, 0)
		await _physics(6)
		check(sl.scares == before + 1, "coming back out doesn't scare her again")
	game.mp_level = old_mp

	_finish()


func _hits(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	return not space.intersect_ray(q).is_empty()


func _ground(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -20, 0))
	if player:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return -99.0 if hit.is_empty() else (hit.position as Vector3).y


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
