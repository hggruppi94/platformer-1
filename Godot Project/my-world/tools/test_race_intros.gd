extends SceneTree

# Checks the race intros (scripts/race_intro.gd, played by scripts/races.gd): starting a race plays the cutscene first,
# with its own camera, the track's name, and nobody moving; the camera flies the course above the ground and says
# hello to each rival by name and ride; when it ends (or Jump skips it) the player's camera is back and the countdown
# starts; every track has one, the Pumpkin Run on Earth and the Sky Rings (the mothership holds still for it, then the
# race is on); calling a race off mid-intro cleans up; and Settings > Assist > "Race intros" off goes straight to the
# countdown.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_race_intros.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_intros_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_intros_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var settings: Node
var races: Node


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
	settings = root.get_node("Settings")
	races = root.get_node("Races")
	settings.use_layout("classic")
	settings.tips = false
	settings.skate_assist = 1
	settings.race_intros = true
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	races.reset()
	for k in races.TRACKS:
		races.finished_once[k] = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)

	change_scene_to_file(TOWN)
	await _frames(6)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var player_cam := p.get_node("SpringArm3D/Camera3D") as Camera3D
	for id in ["lake_loop", "meadow_wiggle", "observatory_hill", "sky_rings"]:
		var tn: Node3D = races.track_node(id)
		for i in 60:
			if tn and tn.ready_to_race:
				break
			await physics_frame
	var intro: Node = races.intro

	# The Lake Loop: the whole intro, played out
	check(races.start("lake_loop"), "a race starts")
	check(races.state == races.State.INTRO and intro.playing(), "...with its intro first")
	check(root.get_viewport().get_camera_3d() == intro.cam, "...seen through the intro's own camera")
	check(intro._title.text == "LAKE LOOP", "...with the track's name up (%s)" % intro._title.text)
	check(p.input_locked, "nobody moves in the intro")
	var d0: float = races.rivals[0].d
	await _ground_ok("lake_loop", intro)
	check(races.rivals[0].d == d0, "...and the friends wait on the grid")
	await _watch_rivals(intro)
	await _physics(int((intro.length() - intro._t) * 60.0) + 10)
	check(not intro.playing() and races.state == races.State.COUNTDOWN, "when it ends, the countdown starts")
	check(root.get_viewport().get_camera_3d() == player_cam, "...back through the player's camera")
	check(current_scene.find_child("Race Intro Camera", true, false) == null or not is_instance_valid(intro.cam), "...and the intro's camera is gone")
	races._end(false)
	await _physics(3)

	# Skipping
	races.start("meadow_wiggle")
	await _physics(30)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(2)
	check(races.state == races.State.COUNTDOWN and root.get_viewport().get_camera_3d() == player_cam, "Jump skips straight to the countdown")
	races._end(false)
	await _physics(3)
	# Calling it off mid-intro
	races.start("observatory_hill")
	await _physics(20)
	races._end(false)
	await _physics(2)
	check(not intro.playing() and not p.input_locked and root.get_viewport().get_camera_3d() == player_cam,
		"a race called off mid-intro cleans up (camera back, free to move)")
	await _ground_ok_all(["meadow_wiggle", "observatory_hill"], intro)

	# Intros off
	settings.race_intros = false
	races.start("lake_loop")
	check(races.state == races.State.COUNTDOWN and not intro.playing(), "with Race intros off, straight to the countdown")
	races._end(false)
	settings.race_intros = true
	await _physics(3)

	# The Sky Rings: the mothership holds still for it, then the race is on
	var sky: Node3D = races.track_node("sky_rings")
	var ship: Node3D = get_first_node_in_group("mothership")
	ship.global_position = p.global_position + Vector3.UP * 20.0
	ship.board(p)
	for i in 240:
		if ship.is_piloted():
			break
		await physics_frame
	var s0: Vector3 = sky.point_at(0.0)
	var sf: Vector3 = sky.dir_at(0.0)
	ship.global_position = s0 - sf * 20.0
	await _physics(3)
	ship.global_position = s0 + sf * 2.0
	await _physics(3)
	check(races.state == races.State.INTRO and intro.playing(), "through the Sky Rings' start ring: its intro plays")
	check(ship.process_mode == Node.PROCESS_MODE_DISABLED, "...with the mothership holding still")
	var at: Vector3 = ship.global_position
	await _physics(60)
	check(ship.global_position.distance_to(at) < 0.1, "...really still (%.2f m)" % ship.global_position.distance_to(at))
	intro.skip()
	await _physics(2)
	check(races.state == races.State.RACING and ship.process_mode != Node.PROCESS_MODE_DISABLED, "then the sky race is on, the mothership flying again")
	await _physics(60)
	check(races.rivals[0].d > -12.0 + 3.0, "...and the saucers fly off (%.0f m)" % races.rivals[0].d)
	races._end(false)
	ship.beam_down()
	await _physics(30)

	# The Pumpkin Run on Earth
	game.riding = false
	clock.day = 1
	clock.set_earth_time(14 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	var et: Node3D = races.track_node("pumpkin_run")
	for i in 60:
		if et.ready_to_race:
			break
		await physics_frame
	check(races.start("pumpkin_run") and intro.playing() and intro._title.text == "PUMPKIN RUN", "the Pumpkin Run has its intro too")
	await _ground_ok("pumpkin_run", intro)
	await _watch_rivals(intro)
	intro.skip()
	races._end(false)
	_finish()


func _ground_ok(id: String, intro: Node) -> void:
	# Through the flyover, the camera stays above the ground (and never inside a building's walls at eye level)
	var t: Node3D = races.track_node(id)
	var low := 0
	var low_at := ""
	var start: float = intro.TITLE_TIME
	for k in 24:
		intro._t = start + intro.FLY_TIME * k / 24.0
		intro._place_camera()
		var c: Vector3 = intro.cam.global_position
		var g: Vector3 = t.ground_at(Vector2(c.x, c.z))
		if c.y - g.y < 3.0:
			low += 1
			low_at = "(%.0f, %.0f, %.0f) over %.1f" % [c.x, c.y, c.z, g.y]
	check(low == 0, "%s: the intro's camera flies above the ground all the way round (%d low %s)" % [id, low, low_at])
	intro._t = 0.5
	await physics_frame


func _ground_ok_all(ids: Array, intro: Node) -> void:
	for id in ids:
		races.start(id)
		await _ground_ok(id, intro)
		races._end(false)
		await physics_frame


func _watch_rivals(intro: Node) -> void:
	# Says hello to each rival, by name and ride
	var names: Array = []
	for k in races.rivals.size():
		intro._t = intro.TITLE_TIME + intro.FLY_TIME + intro.RIVAL_TIME * (k + 0.5)
		intro._place_camera()
		names.append(intro._caption.text.replace("\n", ", "))
	var all_named := true
	for k in races.rivals.size():
		if not names[k].begins_with(races.rivals[k].display_name()):
			all_named = false
	check(all_named and names.size() == 3, "...and says hello to each rival (%s)" % "; ".join(names))
	await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
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
