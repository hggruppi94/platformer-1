extends SceneTree

# Checks daily routines (scripts/routine.gd, res://routines/*.json). Run it twice: the first run checks everyone is
# where their schedule says through the day, walks between places, snaps into place after sleeping, and saves at
# 11 AM; the second starts up like the real game and checks they're where they should be after loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_routines.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_routines.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const PEOPLE := ["dash", "rex", "rook", "bramble", "pip", "green_man", "nina", "mr_palmer", "bruno_alien"]
const FAR_AWAY := Vector3(-140, 2, 100)            # the empty southwest corner, far from everyone's places

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var player: CharacterBody3D
var routines := {}
var paths: TownPaths


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	# Never hang: give up after a few minutes (your save stays safe in the backup until --check-load puts it back)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	paths = TownPaths.get_shared()
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	dialogue.reset()
	root.get_node("Quests").reset()          # start from no quests, whatever your own save has
	_check_files()

	change_scene_to_file(TOWN)
	await _frames(5)
	_find()
	check(routines.size() == PEOPLE.size(), "everyone has a routine: %s" % [routines.keys()])
	if routines.size() != PEOPLE.size():
		print("RESULT FAILED (routines missing). Now run with -- --check-load to put your save back")
		quit(1)
		return

	# Where everyone is through the day (with Nina far away, so nobody walks: they're just there)
	player.global_position = FAR_AWAY
	for t in ["07:00", "08:00", "11:00", "13:30", "19:30", "22:00", "00:20", "03:00"]:
		clock.set_time(1, clock.parse_time(t), true)
		await _settle()
		for id in PEOPLE:
			_check_where(id, t)

	# Walking: Nina by Rex at 9:59 AM. At 10 he skates off from the homes to the Town Hall in the market, right across
	# town along the paths, never under a roof.
	clock.set_time(2, 9 * 60 + 59.0, true)
	await _settle()
	var rex := _body("rex")
	player.global_position = rex.global_position + Vector3(4, 1, 0)
	Engine.time_scale = 4.0
	var under_roof := []
	var started := false
	for i in 3000:
		await physics_frame
		if routines.rex.is_travelling():
			started = true
			var roof := _roof_over(rex.global_position)
			if roof != "" and roof not in under_roof:
				under_roof.append(roof)
		elif started:
			break
	Engine.time_scale = 1.0
	check(started, "at 10 AM Rex sets off for the Town Hall (Nina's watching)")
	check(not routines.rex.is_travelling() and _flat_dist(rex.global_position, "town_hall") < 6.0,
		"...and gets there (%.1f m from it)" % _flat_dist(rex.global_position, "town_hall"))
	check(under_roof.is_empty(), "...without going through any building: %s" % [under_roof])

	# Nobody watching: at 12:30 Bramble is simply at her flower stall in the market, no walk
	player.global_position = FAR_AWAY
	clock.set_time(2, 12 * 60 + 29.6, true)
	await _settle()
	await create_timer(1.0).timeout
	check(not routines.bramble.is_travelling() and _flat_dist(_body("bramble").global_position, "flower_stall") < 6.0,
		"12:30 with Nina far away: Bramble is just there at her flower stall (%.1f m)" % _flat_dist(_body("bramble").global_position, "flower_stall"))

	# Dash's bike: under him while he rides about, parked next to him on his snack break
	clock.set_time(2, 9 * 60.0, true)
	await _settle()
	var dash := _body("dash")
	var bike := current_scene.find_child("Bike", true, false) as Node3D
	player.global_position = dash.global_position + Vector3(10, 1, 0)
	var riding_ok := false
	for i in 120:
		await physics_frame
		if not routines.dash._path.is_empty() and bike.global_position.distance_to(dash.global_position) < 0.05:
			riding_ok = true
			break
	check(riding_ok, "Dash rides his bike on his rounds")
	clock.set_time(2, 12 * 60 + 45.0, true)
	await _settle()
	var gap := bike.global_position.distance_to(dash.global_position)
	check(gap > 0.5 and gap < 2.5, "...and parks it next to him for his snack break (%.1f m)" % gap)

	# Rook tags along after Rex in the morning
	clock.set_time(2, 8 * 60.0, true)
	await _settle()
	player.global_position = _body("rook").global_position + Vector3(6, 1, 0)
	await create_timer(4.0).timeout
	var tag := _body("rook").global_position.distance_to(_body("rex").global_position)
	check(tag < 7.0, "Rook follows Rex around (%.1f m behind)" % tag)

	# The Green Man and the Shift: walks to the portal at midnight, stands facing it, walks back at 1
	clock.set_time(2, 23 * 60 + 59.7, true)
	await _settle()
	var green := _body("green_man")
	player.global_position = green.global_position + Vector3(5, 1, 3)
	Engine.time_scale = 4.0
	var walked := false
	for i in 1200:
		await physics_frame
		walked = walked or routines.green_man.is_travelling()
		if walked and not routines.green_man.is_travelling() and clock.in_shift():
			break
	await create_timer(2.0).timeout
	Engine.time_scale = 1.0
	check(walked and _flat_dist(green.global_position, "portal") < 1.5, "in the Shift the Green Man walks to the portal (%.1f m)" % _flat_dist(green.global_position, "portal"))
	var to_portal := Vector3(36, 0, 13) - green.global_position
	to_portal.y = 0
	var facing := green.global_transform.basis.z
	facing.y = 0
	check(rad_to_deg(facing.angle_to(to_portal)) < 20.0, "...and stands looking at it (%.0f degrees off)" % rad_to_deg(facing.angle_to(to_portal)))
	clock.set_time(3, 59.8, true)                  # just before 1 AM (the jump puts him at the portal)...
	await _settle()
	player.global_position = green.global_position + Vector3(4, 1, 3)
	var back := false
	for i in 300:
		await physics_frame
		if routines.green_man.is_travelling():
			back = true
			break
	check(back, "...and at 1 AM, after the Shift, he walks back")

	# Mr. Palmer at bedtime: from his evening stroll he walks to the Town Hall door and goes in, rather than standing
	# outside all night
	clock.set_time(3, 20 * 60 + 29.7, true)
	await _settle()
	var palmer := _body("mr_palmer")
	player.global_position = palmer.global_position + Vector3(5, 1, 0)
	Engine.time_scale = 4.0
	var strolled_home := false
	for i in 1500:
		await physics_frame
		strolled_home = strolled_home or routines.mr_palmer.is_travelling()
		if strolled_home and not routines.mr_palmer.is_travelling():
			break
	Engine.time_scale = 1.0
	check(strolled_home and not palmer.visible and _flat_dist(palmer.global_position, "town_hall") < 1.5,
		"at 8:30 PM Mr. Palmer walks home to the Town Hall and goes in (%.1f m from its door)" % _flat_dist(palmer.global_position, "town_hall"))

	# Asleep / away: not in town, nobody to talk to; sleeping on to the morning puts everyone in place
	clock.set_time(3, 22 * 60.0, true)
	await _settle()
	for id in ["dash", "rex", "bramble", "bruno_alien"]:
		check(not _body(id).visible and not routines[id].is_present() and not _talk(id).monitoring, "%s is home at 10 PM (gone from town)" % id)
	clock.call("sleep_until_morning")              # 7 AM: the clock jumps, everyone snaps
	await _settle()
	for id in PEOPLE:
		_check_where(id, "after sleeping, 07:00")

	# Dialogue that knows where they are and what they're doing
	for c in [["rex", "11:00", 2, "Citizens of Galaxity"], ["dash", "12:45", 2, "Snack break"],
			["rook", "13:30", 2, "Zzzz"], ["bramble", "13:30", 2, "flower"], ["bruno_alien", "10:00", 2, "leththon"]]:
		clock.set_time(4, clock.parse_time(c[1]), true)
		await _settle()
		dialogue.talks[c[0]] = c[2]
		var first := _first_line(c[0])
		check(first.contains(c[3]), "%s at %s (%s): \"%s\"" % [c[0], c[1], routines[c[0]].activity(), first])
	# Pip, on his way to the lamps at dusk: too excited to stop
	clock.set_time(4, 18 * 60 + 29.7, true)
	await _settle()
	player.global_position = _body("pip").global_position + Vector3(5, 1, 0)
	for i in 120:
		await physics_frame
		if routines.pip.is_travelling():
			break
	dialogue.talks["pip"] = 3
	check(routines.pip.is_travelling() and _first_line("pip").contains("Can't stop"), "Pip setting off at dusk: \"%s\"" % _first_line("pip"))

	# Save at 11 AM for the --check-load run
	clock.set_time(5, 11 * 60.0, true)
	await _settle()
	player.global_position = _ground("spawn") + Vector3(0, 1, 0)
	await _frames(3)
	game.save_game()
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	# Game (an autoload) has already loaded the save; the town starts up as on a real start-up
	change_scene_to_file(TOWN)
	await _frames(5)
	_find()
	await _settle()
	check(clock.day == 5 and clock.hour() == 11, "loaded clock: day %d, %s" % [clock.day, clock.time_string()])
	for id in PEOPLE:
		_check_where(id, "after loading, 11:00")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


# -----------------------------------------------------------------------------
func _check_files() -> void:
	# Every schedule reads, names real places and people, and every place can be reached
	for id in PEOPLE:
		var res := load("res://routines/%s.json" % id) as JSON
		var ok: bool = res != null and res.data is Dictionary and not res.data.get("blocks", []).is_empty()
		var bad := []
		if ok:
			for b in res.data.blocks:
				var names: Array = [b.get("place", "")] + b.get("route", [])
				for n in names:
					if not paths.has(str(n)):
						bad.append("no place '%s'" % n)
					elif paths.route("ninas_house", str(n)).is_empty():
						bad.append("can't reach '%s'" % n)
				if b.get("do", "") == "follow" and not str(b.get("who", "")) in PEOPLE:
					bad.append("follows nobody: '%s'" % b.get("who", ""))
				if not str(b.get("do", "")) in ["idle", "wander", "nap", "patrol", "follow", "away"]:
					bad.append("unknown 'do': %s" % b.get("do", ""))
		check(ok and bad.is_empty(), "%s.json: %d blocks %s" % [id, res.data.blocks.size() if ok else 0, bad])


func _check_where(id: String, when: String) -> void:
	# Where this person should be right now, by their own schedule
	var r: Node = routines[id]
	var b: Dictionary = r.current_block()
	var body := _body(id)
	var doing := str(b.get("do", ""))
	if doing == "away":
		check(not body.visible and not r.is_present(), "%s %s: away (%s)" % [when, id, r.activity()])
		return
	var where := str(b.get("place", ""))
	var slack := float(b.get("radius", 0.0)) + 2.5
	var d := _flat_dist(body.global_position, where)
	if doing == "patrol":
		d = INF
		for n in b.route:
			d = minf(d, _flat_dist(body.global_position, str(n)))
		slack = 3.0
	elif doing == "follow":
		var leader := routines[str(b.who)] as Node
		if leader.is_present():
			d = body.global_position.distance_to(_body(str(b.who)).global_position)
			where = "with " + str(b.who)
			slack = 6.0
	var ground_ok := absf(body.global_position.y - TownPaths.ground_at(body.global_position, current_scene.get_world_3d().direct_space_state, TownPaths.skip_rids(current_scene), 1.0).y) < 0.6
	check(body.visible and d < slack and ground_ok, "%s %s: %s at %s (%.1f m)%s" % [when, id, r.activity(), where, d, "" if ground_ok else " NOT ON THE GROUND"])


func _first_line(id: String) -> String:
	var convo: Array = dialogue.pick_conversation(id)
	var steps: Array = dialogue._steps(convo)
	return str(steps[0].text) if steps.size() > 0 and steps[0].has("text") else ""


func _find() -> void:
	player = current_scene.find_child("Player", true, false)
	routines.clear()
	for r in get_nodes_in_group("routines"):
		routines[r.character_id] = r


func _body(id: String) -> Node3D:
	return routines[id].get_parent() as Node3D


func _talk(id: String) -> Area3D:
	return _body(id).get_node("Talk") as Area3D


func _ground(place: String) -> Vector3:
	return paths.position_of(place, current_scene.get_world_3d().direct_space_state, TownPaths.skip_rids(current_scene))


func _flat_dist(pos: Vector3, place: String) -> float:
	var p: Vector2 = paths.points.get(place, Vector2(INF, INF))
	return Vector2(pos.x, pos.z).distance_to(p)


func _roof_over(pos: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.UP * 30)
	q.exclude = TownPaths.skip_rids(current_scene)
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return str((hit.collider as Node).get_path()).get_slice("/", 4) if hit else ""


func _settle() -> void:
	for i in 4:
		await physics_frame
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
