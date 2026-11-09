extends SceneTree

# Checks practice trips (scripts/portals.gd practice_trip(), the pause menu's "Visit a portal world"): off by default;
# with Settings > Assist > "Practice trips" on, the pause menu lists every built world; a trip goes straight in from
# Earth, with no quake or story needed, plays the world from the start, has no time limit, and saves
# nothing while there (even clearing the world); coming home (the world's portal, or the pause menu) loads the save
# from just before, back where the player was, with everything as it was; and leaving any other way does the same.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_practice_trips.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.practice_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.practice_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var portals: Node
var settings: Node
var pause: Node
var clock: Node


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
	portals = root.get_node("Portals")
	settings = root.get_node("Settings")
	pause = root.get_node("PauseMenu")
	clock = root.get_node("Clock")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hero["name"] = "Tester"
	game.hold_saves = false
	clock.set_time(3, 14 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(10)
	await _physics(4)
	check(current_scene.scene_file_path == EARTH, "starts on Earth")
	check(portals.quakes.is_empty() and portals.cleared_worlds.is_empty(), "a fresh game: no portals open, nothing mended")

	# --- the menu
	check(settings.practice_trips == false, "practice trips are off by default")
	pause.open()
	await _frames(2)
	check(not _menu_has("Visit a portal world"), "...so the pause menu doesn't offer them")
	pause.close()
	settings.practice_trips = true
	pause.open()
	await _frames(2)
	check(_menu_has("Visit a portal world"), "turned on, the pause menu offers \"Visit a portal world\"")
	pause._show_worlds()
	await _frames(2)
	var built := 0
	for w in portals.WORLDS:
		if portals.is_built(str(w.id)):
			built += 1
			check(_menu_has(str(w.name)), "the list has %s" % w.name)
		else:
			check(not _menu_has(str(w.name)), "...and not %s, which isn't built yet" % w.name)
	check(built >= 3, "every built world is on the list (%d)" % built)
	pause.close()
	await _frames(2)

	# --- a trip
	var player := get_first_node_in_group("player") as Node3D
	var was_at := player.global_position
	game.sparkles = 7
	game.save_game()
	var before := FileAccess.get_file_as_string(SAVE)
	check(not portals.is_open("frozen_moment"), "the Frozen Moment isn't open in this save")
	check(portals.practice_trip("frozen_moment"), "a practice trip to the Frozen Moment starts anyway")
	await _arrive("res://scenes/portal_worlds/frozen_moment.tscn")
	check(portals.here == "frozen_moment" and portals.practice, "...and the player is there, on a practice trip")
	check(portals.timer_text().contains("no time limit"), "the timer says there's no time limit")
	var t: float = portals.time_left
	await create_timer(2.0).timeout
	check(is_equal_approx(portals.time_left, t), "...and the time doesn't run down")
	check(game.hold_saves, "saving is held on a practice trip")
	game.sparkles = 999
	portals.note_found("frozen_moment", "test_thing")
	portals.clear("frozen_moment")
	game.save_game()
	check(FileAccess.get_file_as_string(SAVE) == before, "nothing done there reaches the save (even mending the world)")
	pause.open()
	await _frames(2)
	check(_menu_has("End practice trip"), "the pause menu has \"End practice trip\"")
	check(not _menu_has("Go home to Earth"), "...instead of the usual way home")
	pause.close()

	# --- home again, through the world's own portal
	portals.go_home()
	await _arrive(EARTH)
	await _physics(4)
	player = get_first_node_in_group("player") as Node3D
	check(not portals.practice and not game.hold_saves, "home again: the practice trip is over and saving is back on")
	check(game.sparkles == 7, "everything's as it was before the trip (%d sparkles)" % game.sparkles)
	check(not portals.is_cleared("frozen_moment") and not portals.is_open("frozen_moment")
		and not portals.has_found("frozen_moment", "test_thing"), "...the world isn't mended or open in the real game")
	check(player != null and player.global_position.distance_to(was_at) < 1.5, "...and the player's back where they were")
	check(portals.here == "" and portals.timer_text() == "", "no timer back home")

	# --- a world already mended plays from the start; and leaving some other way also ends the trip
	portals.quakes.append("shard_isle")
	portals.cleared_worlds.append("shard_isle")
	portals.found["shard_isle"] = ["echo1"]
	game.save_game()
	check(portals.practice_trip("shard_isle"), "a practice trip to Shard Isle (mended in this save)")
	await _arrive("res://scenes/portal_worlds/shard_isle.tscn")
	check(not portals.is_cleared("shard_isle") and not portals.has_found("shard_isle", "echo1"),
		"...plays it from the start")
	game.go(game.TOWN_SCENE, "FromPortaltoEarth", "Void")          # some other way out
	await _arrive(EARTH)
	check(not portals.practice and not game.hold_saves, "leaving another way also ends the practice trip")
	check(portals.is_cleared("shard_isle") and portals.has_found("shard_isle", "echo1"), "...and the real save's mended Shard Isle is back")
	_finish()


func _menu_has(text: String) -> bool:
	for c in pause.box.get_children():
		if c is Button and (c as Button).text.begins_with(text):
			return true
	return false


func _arrive(path: String) -> void:
	for i in 600:
		await process_frame
		if current_scene and current_scene.scene_file_path == path and get_first_node_in_group("player") != null:
			break
	await _frames(6)
	check(current_scene != null and current_scene.scene_file_path == path, "arrived in %s" % path.get_file())


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
