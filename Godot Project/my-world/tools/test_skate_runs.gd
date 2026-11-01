extends SceneTree

# Checks the timed skate runs (scripts/skate_runs.gd): a Run Clock stands at the Hollow Skate Yard on Earth and at
# Galaxity's Skate Park, clear of the skating, talking to it reads out the medals and starts a run, the countdown
# holds you still, combos and gaps landed in the run count (and ones before it don't), the clock runs down, a combo
# you're in at the buzzer still counts once you land it, the results pay each medal's sparkles once, best scores and
# medals are saved and load back, and stepping off your ride ends a run with no harm done.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate_runs.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.skate_runs_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.skate_runs_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var runs: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	runs = root.get_node("SkateRuns")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	runs.reset()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.day = 1
	clock.set_earth_time(14 * 60.0, true)

	change_scene_to_file(EARTH)
	await _frames(8)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var c: Node3D = runs.clocks.get("skate_yard")
	check(c != null and c.get_node_or_null("Run Talk") != null, "a Run Clock stands at the Hollow Skate Yard")
	check(not runs.clocks.has("skate_park"), "...and Galaxity's isn't put on Earth")
	if c == null:
		_finish()
		return
	# Clear of the skating: nothing of the yard's ramps within 2.5 m, and on the yard's floor
	var yard := current_scene.find_child("Hollow Skate Yard", true, false) as Node3D
	var close := INF
	for piece in ["Big Vert West", "Funbox", "Gap Kicker", "Flat Rail", "Yard Stairs"]:
		var n := yard.get_node_or_null(piece) as Node3D
		if n:
			close = minf(close, Vector2(n.global_position.x - c.global_position.x, n.global_position.z - c.global_position.z).length())
	check(close > 4.0, "...out of the way of the ramps (%.1f m from the nearest)" % close)
	var lines: Array = runs.lines("skate_yard")
	check(str(lines).contains("Bronze") and str(lines).contains("Gold"), "talking to it reads out the medals")
	check(lines.any(func(l) -> bool: return l is Dictionary and str(l.get("choice", "")).contains("skate_run_go_skate_yard")),
		"...and asks if you're ready")

	# A run
	p.global_position = c.global_position + Vector3(3, 0.9, 3)
	await _physics(4)
	var s: Node = p.get_node("Skate") if p.has_node("Skate") else null
	check(runs.start("skate_yard"), "saying go starts the run")
	check(game.riding and p.input_locked and runs.state == runs.State.COUNTDOWN, "...on your ride, held still for the countdown")
	s = p.get_node("Skate")
	var tricks = s.tricks
	tricks.add("Kickflip", 100)
	tricks.bank()
	check(runs.score == 0, "a combo landed in the countdown doesn't count")
	await _physics(int(runs.COUNTDOWN * 60) + 6)
	check(runs.state == runs.State.RUNNING and not p.input_locked, "GO: two minutes on the clock")
	check(runs.hud.place_label.text.begins_with("1:5") or runs.hud.place_label.text == "2:00", "...shown across the top (%s)" % runs.hud.place_label.text)
	tricks.add("Kickflip", 100)
	tricks.add("50-50", 400)
	tricks.bank()
	check(runs.score == 1000, "a combo counts: 500 x 2 = %d" % runs.score)
	var gz: Array = root.get_node("Gaps").zone("hollow_yard_gap")
	root.get_node("Gaps").check_landing(gz[0], gz[2], 0.9, false, false, false, null, null, s)
	tricks.bank()
	check(runs.gaps == 1 and runs.score == 1500, "a gap counts (%d gaps, %d)" % [runs.gaps, runs.score])
	var before: float = runs.left
	await _physics(60)
	check(before - runs.left > 0.9 and before - runs.left < 1.1, "the clock runs down (%.2f s in a second)" % (before - runs.left))

	# The buzzer goes mid-combo: it counts once landed
	runs.left = 0.02
	tricks.add("Melon", 600)
	await _physics(3)
	check(runs.state == runs.State.LAST_COMBO and runs.hud.place_label.text == "Land it!", "time's up mid-combo: land it! (%d, %s)" % [runs.state, runs.hud.place_label.text])
	tricks.bank()
	await _physics(2)
	check(runs.state == runs.State.RESULTS and runs.score == 2100, "...it counts once landed (%d)" % runs.score)
	check(runs.best.get("skate_yard", 0) == 2100, "the best score is kept")
	check(runs.hud.results.visible and runs.hud.results_label.text.contains("2,100"), "the results show the score")
	await _physics(int(runs.RESULTS_TIME * 60) + 10)
	check(not runs.running(), "then back to skating about")

	# Medals: a big run pays bronze and silver once
	var sparkles: int = game.sparkles
	runs.start("skate_yard")
	await _physics(int(runs.COUNTDOWN * 60) + 6)
	tricks.lose()
	for t in ["Kickflip", "Heelflip", "Impossible", "Shove-it", "Indy", "Melon"]:
		tricks.add(t, 600)
	tricks.bank()                                       # 3600 x 6 = 21,600
	runs.left = 0.01
	await _physics(3)
	var m: Array = runs.RUNS.skate_yard.medals
	check(runs.state == runs.State.RESULTS and int(runs.medals.get("skate_yard", 0)) == 2,
		"%d: bronze and silver (%d medals)" % [runs.score, int(runs.medals.get("skate_yard", 0))])
	check(game.sparkles - sparkles == int(m[0][2]) + int(m[1][2]), "...paying ✦ %d" % (game.sparkles - sparkles))
	await _physics(int(runs.RESULTS_TIME * 60) + 10)
	sparkles = game.sparkles
	runs.start("skate_yard")
	await _physics(int(runs.COUNTDOWN * 60) + 6)
	tricks.lose()
	for t in ["Kickflip", "Heelflip", "Impossible", "Shove-it", "Indy", "Melon"]:
		tricks.add(t, 600)
	tricks.bank()
	runs.left = 0.01
	await _physics(3)
	check(game.sparkles == sparkles, "the same medals again don't pay again")
	await _physics(int(runs.RESULTS_TIME * 60) + 10)

	# Stepping off ends it
	runs.start("skate_yard")
	await _physics(int(runs.COUNTDOWN * 60) + 6)
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	check(not runs.running() and runs.hud.place_label.text == "", "stepping off your ride ends the run")

	# Saved and loaded
	var data: Dictionary = runs.save_data()
	runs.reset()
	check(runs.best.is_empty(), "a new game has no best scores")
	runs.load_data(data)
	check(int(runs.best.skate_yard) == 21600 and int(runs.medals.skate_yard) == 2, "best scores and medals load back")
	check(str((c.get_node("Best") as Label3D).text).contains("21,600"), "the Run Clock shows your best")

	# Galaxity's
	change_scene_to_file(TOWN)
	await _frames(8)
	var gc: Node3D = runs.clocks.get("skate_park")
	check(gc != null, "a Run Clock stands at Galaxity's Skate Park")
	if gc:
		var park := current_scene.find_child("Skate Park", true, false) as Node3D
		var off := Vector2(gc.global_position.x - park.global_position.x, gc.global_position.z - park.global_position.z).length()
		check(off > 15.0 and off < 20.0, "...just outside the rings (%.1f m from the middle)" % off)
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	runs.reset()
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
