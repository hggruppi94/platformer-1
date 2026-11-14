extends SceneTree

# Checks the pull home to Stars Hollow after mending a portal world (Hayden, 14 Nov 2026: "After completing worlds in
# the void, the player should be sucked back to earth, where they must complete more quests (can be season-related or
# one-off) in order to unlock the ability to go back to the void"; scripts/home_calls.gd):
#   - mending a world owes Stars Hollow a visit; Dark Hollow, the Far Future and practice trips don't;
#   - the way home from it lands you by the old oak on Earth, out of its crack, which then snaps shut;
#   - while it's shut there's no way to the Void (the crack, the pause menu) and the oak's hint says home needs you;
#   - the one-off chapter (Mrs. Wren's wind chimes): her talk, three chimes to find, back to her, and the crack opens;
#   - a seasonal chapter (after the Frozen Moment): Stars Hollow turns to winter, Nina's First Snow, and only its end
#     opens the crack;
#   - the chapters save and load, and an old save owes nothing.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_home_calls.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.home_calls_test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const ISLE := "res://scenes/portal_worlds/shard_isle.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var portals: Node
var mind: Node
var calls: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	portals = root.get_node("Portals")
	mind = root.get_node("DivineMind")
	calls = portals.home_calls
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Settings").tips = false
	game.new_game()
	await _wait_for_scene(EARTH)
	game.needs_creator = false
	dialogue.set_flag("oak_woken")
	await create_timer(3.0).timeout
	var crack := current_scene.get("crack") as Node3D
	check(crack != null and float(crack.get_meta("open", 0.0)) > 0.9, "before: the crack by the old oak is open")
	check(not calls.sealed(), "...and nothing's shut")

	# --- Who owes a visit ---
	calls.on_mended("dark_hollow")
	calls.on_mended("far_future")
	check(calls.owed.is_empty(), "Dark Hollow and the Far Future don't pull you home")
	portals.practice = true
	calls.on_mended("shard_isle")
	check(calls.owed.is_empty(), "nor does a practice trip")
	portals.practice = false

	# --- Mend Shard Isle, and the way home pulls you all the way to Earth ---
	portals.quakes = ["shard_isle"]
	portals.enter("shard_isle")
	await _wait_for_scene(ISLE, 300)
	check(current_scene.scene_file_path == ISLE and portals.here == "shard_isle", "in Shard Isle")
	portals.clear("shard_isle")
	check("shard_isle" in calls.owed and calls.is_due("shard_isle"), "mending it owes Stars Hollow a visit")
	portals.go_home()
	await _wait_for_scene(EARTH, 300)
	check(current_scene.scene_file_path == EARTH, "the way home goes all the way to Stars Hollow, not the Void")
	check(calls.sealed() and calls.chapter == "shard_isle" and not "shard_isle" in calls.owed, "Shard Isle's chapter is on")
	check(clock.on_earth and not clock.in_shift(), "...and it's morning on Earth")
	check(quests.is_started("home_chimes") and quests.is_followed("home_chimes"), "Wren's Wind Chimes starts, and is followed")
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	var oak := current_scene.get_node("Portal Home/Old Oak") as Node3D
	check(player.global_position.distance_to(oak.global_position) < 12.0, "...landing by the old oak")
	crack = current_scene.get("crack") as Node3D
	await create_timer(calls.SHUT_AFTER + 4.0).timeout
	check(not calls.just_pulled, "a moment later the crack snaps shut")
	check(crack != null and float(crack.get_meta("open", 1.0)) < 0.05, "...and is gone from the green")
	var door := current_scene.find_child("PortalToGalaxity", true, false)
	check(str(door.get("closed_message")) != "", "walking onto it does nothing but a message")
	var menu := root.get_node("PauseMenu")
	check(menu.way_home().is_empty(), "the pause menu has no way to the Void")
	var hint: Array = mind.hint()
	check(not str(hint).contains("open"), "the oak's hint doesn't say the ground's open (%s)" % str(hint))
	quests.followed.clear()
	quests.chose_none = true
	check(mind.hint() == [mind.HINT_HOME], "...with nothing followed, it says Stars Hollow needs you")
	quests.chose_none = false

	# --- The chapter: Mrs. Wren's chimes ---
	var lines: Array = dialogue.pick_conversation("wren")
	check(str(lines).contains("wind chimes"), "Mrs. Wren asks for her wind chimes")
	dialogue.set_flag("chimes_asked")
	await _quests()
	check(quests.on_step("home_chimes", "find"), "...then the find step")
	var holder := current_scene.get_node_or_null("Home Calls")
	check(holder != null and holder.get_child_count() == calls.SPOTS.size(), "the chapters' things are in Stars Hollow")
	for f in ["chime_1", "chime_2", "chime_3"]:
		var spot := holder.get_node("Home Spot " + f)
		check(spot.is_open() and (spot.get_node("Before") as Node3D).visible, "%s waits to be picked up" % f)
		var y := (spot as Node3D).global_position.y
		check(absf(y - EarthLand.height((spot as Node3D).global_position.x, (spot as Node3D).global_position.z)) < 1.5,
			"...on the ground (%.1f)" % y)
		spot.use()
	await _quests()
	check(quests.on_step("home_chimes", "back"), "three found: back to Mrs. Wren")
	check(calls.sealed(), "...still shut till she has them")
	lines = dialogue.pick_conversation("wren")
	check(str(lines).contains("in tune"), "she's pleased")
	dialogue.set_flag("chimes_back")
	await _quests()
	await create_timer(1.0).timeout
	check(quests.is_done("home_chimes") and not calls.sealed() and "shard_isle" in calls.done, "done: the crack's open again")
	await create_timer(3.5).timeout
	check(float(crack.get_meta("open", 0.0)) > 0.9, "...wide open in front of the old oak")
	check(not menu.way_home().is_empty(), "...and the pause menu goes to the Void again")
	calls.on_mended("shard_isle")
	check(calls.owed.is_empty(), "a chapter only happens once")

	# --- A seasonal chapter: the Frozen Moment brings winter ---
	portals.cleared_worlds.append("frozen_moment")
	portals.open_seasons()
	calls.on_mended("frozen_moment")
	check(calls.is_due("frozen_moment"), "mending the Frozen Moment owes a visit too")
	calls.pull("frozen_moment")
	await _wait_for_scene(EARTH, 300)
	await create_timer(1.0).timeout
	check(clock.season() == "winter", "Stars Hollow turns to winter")
	check(quests.is_started("home_snow"), "Snow in Stars Hollow! starts")
	quests.state["first_night"] = {"step": 99, "done": true}       # (Nina's winter talk needs the First Night done)
	lines = dialogue.pick_conversation("nina_earth")
	check(str(lines).contains("SNOWING"), "Nina's got the First Snow for you")
	dialogue.set_flag("first_snow_start")
	await _quests()
	check(quests.is_done("home_snow") and quests.is_started("first_snow"), "...and it starts")
	check(quests.is_followed("first_snow"), "...followed")
	check(calls.sealed(), "the crack stays shut till it's done")
	for f in ["snow_carrot", "snow_scarf", "snow_built", "snow_sledded", "snow_cocoa"]:
		dialogue.set_flag(f)
		await _quests()
	await create_timer(1.0).timeout
	check(quests.is_done("first_snow") and not calls.sealed(), "the First Snow done: the crack's open again")

	# --- Saving ---
	calls.owed = ["lanternmoor"]
	calls.chapter = "glenmoor"
	var data: Dictionary = portals.save_data()
	portals.load_data({})
	check(calls.owed.is_empty() and calls.chapter == "" and calls.done.is_empty(), "an old save owes nothing")
	portals.load_data(data)
	check(calls.owed == ["lanternmoor"] and calls.chapter == "glenmoor" and "frozen_moment" in calls.done,
		"chapters save and load")
	calls.reset()

	# --- No spoilers, and short words ---
	for id in calls.CHAPTERS:
		var q: Dictionary = quests.quest(str(calls.CHAPTERS[id].quest))
		check(not q.is_empty(), "%s's chapter quest exists" % id)
		for step in q.get("steps", []):
			var t := str(step.text)
			check(t.split(" ").size() <= 6 and not t.to_lower().contains("chaos"), "'%s' is short and gives nothing away" % t)
	_finish()


func _quests() -> void:
	quests.check()
	await _frames(3)


func _wait_for_scene(path: String, frames := 150) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
