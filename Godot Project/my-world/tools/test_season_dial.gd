extends SceneTree

# Checks the Season Dial by the old oak (scripts/season_dial.gd, story flag 48):
# - Clock.dial_to(): the same date and weekday in the new season, the calendar only ever moves on, and a locked season
#   or the season it already is can't be picked,
# - no dial while Stars Hollow has only autumn, or while the oak's still asleep; with a second season open it's there,
#   on dry, open ground off every path, with a "turn the Season Dial" spot,
# - it offers every open season but this one (a locked one is frosted over, and says so),
# - turning it: the pointer spins round, the town comes back in the new season where the player stood, the notice
#   board's jobs are picked again for the new season, Nina has a line about it, and the Calendar sheet mentions it,
# - it's still there after a save and load.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_season_dial.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.dial_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dial_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var clock: Node
var quests: Node
var dialogue: Node
var jobs: Node
var dial: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	jobs = root.get_node("EarthJobs")
	dial = root.get_node("EarthTown/SeasonDial")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	_check_clock()
	await _check_when_shown()
	await _check_turning()
	await _check_saved()
	_finish()


func _to_autumn() -> void:
	clock.calendar_offset = clock.CALENDAR_START
	clock.on_earth = true
	clock.set_time(clock.day_of("autumn", 10, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0


# --- The calendar -------------------------------------------------------------------------------------------------
func _check_clock() -> void:
	clock.seasons_open = clock.SEASONS.duplicate()
	_to_autumn()
	var date: int = clock.season_day()
	var wd: String = clock.weekday()
	var off: int = clock.calendar_offset
	check(clock.dial_to("winter") and clock.season() == "winter", "dial_to(\"winter\") makes it winter")
	check(clock.season_day() == date and clock.weekday() == wd, "...on the same date and weekday (%s)" % clock.date_string())
	check(clock.calendar_offset > off, "...and the calendar moved on, not back")
	off = clock.calendar_offset
	var year: int = clock.year()
	check(clock.dial_to("autumn") and clock.season() == "autumn" and clock.calendar_offset > off,
		"winter round to autumn moves on too")
	check(clock.year() == year + 1, "...into the next year")
	check(not clock.dial_to("autumn"), "the season it already is can't be picked")
	clock.seasons_open = ["autumn", "winter"]
	check(not clock.dial_to("summer") and clock.season() == "autumn", "a locked season can't be picked")


# --- Where it is, and when ----------------------------------------------------------------------------------------
func _load_earth() -> void:
	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(2)


func _check_when_shown() -> void:
	clock.seasons_open = ["autumn"]
	_to_autumn()
	dialogue.flags.erase("season_dial_seen")
	await _load_earth()
	check(current_scene.get_node_or_null("Season Dial") == null, "no dial while Stars Hollow only has autumn")
	clock.seasons_open = ["autumn", "winter"]
	var oak := root.get_node("HummingOak")
	if oak.has_method("awake") and oak.awake():
		# The oak's asleep in the First Night's early steps: no dial then either
		quests.state[root.get_node("FirstNight").ID] = {"step": 1, "done": false, "since_day": 1}
		dialogue.flags.erase("oak_woken")
		var asleep: bool = not oak.awake()
		if asleep:
			await _load_earth()
			check(current_scene.get_node_or_null("Season Dial") == null, "no dial while the old oak's still asleep")
		quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
		dialogue.flags["oak_woken"] = true
	await _load_earth()
	var g := current_scene.get_node_or_null("Season Dial") as Node3D
	check(g != null, "with winter open too, the Season Dial stands by the old oak")
	if g == null:
		return
	check(dialogue.flags.has("season_dial_seen"), "...and the player's told about it the first time")
	var at := g.global_position
	check(not EarthLand.is_water(at.x, at.z) and absf(at.y - EarthLand.height(at.x, at.z)) < 0.05,
		"it stands on dry ground (%.1f, %.1f)" % [at.x, at.z])
	# Nothing else solid where it stands
	var space: PhysicsDirectSpaceState3D = (current_scene as Node3D).get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), at + Vector3(0, 1.0, 0))
	var others: Array = space.intersect_shape(q, 8).filter(func(h: Dictionary) -> bool:
		return not g.is_ancestor_of(h.collider as Node))
	check(others.is_empty(), "nothing else solid round it (%s)" % str(others.map(func(h): return str(h.collider.name))))
	# Off every path people walk
	var places = JSON.parse_string(FileAccess.get_file_as_string("res://routines/earth_places.json"))
	var pts := {}
	for k in places.points:
		var p: Array = places.points[k]
		pts[k] = Vector2(float(p[0]), float(p[p.size() - 1]))
	var near := 999.0
	for l in places.links:
		var a: Vector2 = pts[l[0]]
		var b: Vector2 = pts[l[1]]
		near = minf(near, Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), a, b).distance_to(Vector2(at.x, at.z)))
	check(near > 2.0, "it's off every path people walk (%.1f m from the nearest)" % near)
	var spot := g.get_node_or_null("Spot")
	check(spot != null and str(spot.call("what")) == "turn the Season Dial", "Interact there offers to turn the dial")
	check(g.get_node_or_null("Face/Quarter Winter") != null and g.get_node_or_null("Face/Quarter Spring") != null,
		"the face has a quarter for each season")
	var pointer := g.get_node("Face/Pointer") as Node3D
	check(is_equal_approx(pointer.rotation.y, dial.angle_of("autumn")), "the pointer rests on autumn")
	# What it offers
	var said: Array = dial.lines()
	var choice: Array = []
	var text := ""
	for l in said:
		if l is Dictionary and l.has("choice"):
			choice = l.choice
		elif l is String:
			text += l
	var picks := choice.map(func(c: Dictionary) -> String: return str(c.get("set", "")))
	check(picks.has("dial_winter") and not picks.has("dial_autumn") and not picks.has("dial_spring")
		and not picks.has("dial_summer"), "it offers winter, and not autumn (it's autumn) or the locked seasons")
	check("Spring and Summer quarters are frosted over" in text, "...and says the locked quarters are frosted over")


# --- Turning it ---------------------------------------------------------------------------------------------------
func _check_turning() -> void:
	var g := current_scene.get_node_or_null("Season Dial") as Node3D
	if g == null:
		return
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	var stand := g.global_position + Vector3(0, 0, 2.0).rotated(Vector3.UP, g.rotation.y)
	player.global_position = stand + Vector3(0, 0.85, 0)   # (the player stands with her middle 0.8 m up)
	await _physics(20)
	var where := player.global_position
	jobs.roll(hash("dial_test"))
	jobs.rolled_visit = clock.earth_day()
	var before := str(jobs.list.map(func(r: Dictionary) -> String: return str(r.kind)))
	var day: int = clock.earth_day()
	# Talk to it and pick winter
	dial.ask()
	check(dialogue.is_active(), "Interact opens the dial's question")
	var answers: Array = []
	for k in 6:
		answers = dialogue.current_choices()
		if not answers.is_empty():
			break
		dialogue._next()
	check(answers.size() == 2, "...with winter and \"Leave it\" (%d answers)" % answers.size())
	if answers.is_empty():
		return
	(answers[0] as Button).pressed.emit()
	if dialogue.is_active():
		dialogue.end()
	await _frames(2)
	check(dial.turning, "the dial starts turning")
	var p := g.get_node("Face/Pointer") as Node3D
	await create_timer(0.8).timeout
	check(absf(p.rotation.y - dial.angle_of("autumn")) > 0.3, "the pointer spins round")
	var t := 0.0
	while dial.turns == 0 and t < 6.0:
		await process_frame
		t += 0.016
	await _frames(14)
	await _physics(3)
	check(clock.season() == "winter" and clock.earth_day() == day, "it's winter in Stars Hollow, on the same Earth day")
	check(current_scene.scene_file_path == EARTH and current_scene.get_node_or_null("Season Dial") != g,
		"Stars Hollow comes back fresh in winter")
	var dressed := current_scene.get_node_or_null("Seasons")
	check(dressed == null or str(dressed.get("season")) in ["winter", ""], "the town's dressed for winter")
	var p2 := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p2 != null and p2.global_position.distance_to(where) < 1.5, "the player's still standing by the dial (%s, was %s)" % [
		p2.global_position if p2 else Vector3.ZERO, where])
	var g2 := current_scene.get_node_or_null("Season Dial") as Node3D
	check(g2 != null and is_equal_approx((g2.get_node("Face/Pointer") as Node3D).rotation.y, dial.angle_of("winter")),
		"the new dial's pointer rests on winter")
	check(not dial.turning and not p2.get("input_locked"), "the controls are handed back")
	var after := str(jobs.list.map(func(r: Dictionary) -> String: return str(r.kind)))
	check(jobs.list.all(func(r: Dictionary) -> bool: return bool(r.get("winter", false))),
		"the notice board's jobs are picked again for winter (%s -> %s)" % [before, after])
	await create_timer(1.2).timeout
	check(not (dial.get("_wash") as ColorRect).visible, "the colour wash clears")
	# Nina knows about it, and so does the Calendar sheet
	quests.state["first_snow"] = {"step": 0, "done": true, "since_day": 1}     # (her winter quest comes first)
	var nina: Array = dialogue.pick_conversation("nina_earth")
	check(" ".join(nina.map(func(l) -> String: return str(l))).contains("stone dial"), "Nina talks about the dial (%s)" % str(nina).left(120))
	var menu := root.get_node("PlayerMenu")
	menu.call("open", "calendar") if menu.has_method("open") else null
	await _frames(3)
	check(root.find_child("Dial hint", true, false) != null, "the Calendar sheet says where the dial is")
	if menu.has_method("close"):
		menu.call("close")
	await _frames(2)


func _check_saved() -> void:
	game.save_game()
	clock.seasons_open = ["autumn"]
	clock.calendar_offset = clock.CALENDAR_START
	game.load_game()
	await _frames(14)
	await _physics(2)
	check(clock.season() == "winter" and clock.season_open("winter"), "after a save and load it's still winter")
	if current_scene.scene_file_path != EARTH:
		await _load_earth()
	check(current_scene.get_node_or_null("Season Dial") != null, "...and the dial's still there")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
