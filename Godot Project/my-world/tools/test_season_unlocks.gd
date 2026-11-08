extends SceneTree

# Checks the seasons unlocking one by one (plan item 20) and Flurry coming to the Void (the Frozen Moment's reward):
# a new game only has autumn, so when the calendar reaches winter it skips on to another autumn (whole seasons, so
# the weekdays don't move); nothing's on in a locked season; the Calendar sheet shows it frosted over with a hint;
# mending the Frozen Moment opens winter, so the next season really is winter, with Winter Lights on it; the seasons
# save and load, an old save keeps all four, and a mended world's season is always open after loading. Then Flurry:
# not in the Void before her world's mended, and afterwards on the Portal Plaza, on the ground, clear of its pillars
# and its portal, in her own little snowfall, with her own lines.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_season_unlocks.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.season_unlock_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.season_unlock_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var portals: Node
var clock: Node
var festival: Node


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
	portals = root.get_node("Portals")
	clock = root.get_node("Clock")
	festival = root.get_node("Festival")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	check(clock.seasons_open.size() == 4, "tests and old games have all four seasons")
	check(FileAccess.get_file_as_string("res://scripts/game.gd").contains("Clock.seasons_open = [\"autumn\"]"),
		"a new game starts with only autumn")
	clock.seasons_open = ["autumn"]
	clock.on_earth = true                     # (so the Void's day is Earth's: no Shift going on)
	_check_locked()
	await _check_frosted_page()
	_check_winter_opens()
	_check_saving()
	await _check_flurry()
	_finish()


func _check_locked() -> void:
	clock.set_time(1, 9 * 60.0, true)
	check(clock.date_string() == "Friday 19 Autumn" and clock.year() == 1, "day 1 is Friday 19 Autumn (%s)" % clock.date_string())
	clock.set_time(10, 9 * 60.0, true)
	check(clock.season() == "autumn" and clock.season_day() == 28, "day 10 is the last day of autumn")
	check(not clock.is_open(11) and festival.events_on(11).is_empty(), "the day after is in locked winter: nothing's on")
	var lights: int = clock.day_of("winter", 21)
	check(festival.big_day(lights) == "" and not festival.is_festival_day(clock.day_of("winter", 6)),
		"no Winter Lights and no Frost Fair while winter's locked")
	var wd: String = clock.weekday(11)
	clock.set_time(11, 9 * 60.0, true)
	check(clock.season() == "autumn" and clock.season_day() == 1 and clock.year() == 2,
		"when the calendar gets to winter it skips on to another autumn (%s, Year %d)" % [clock.date_string(), clock.year()])
	check(clock.weekday() == wd, "...on the same day of the week (%s)" % wd)
	check(festival.is_hallows_eve(10 + 28) and festival.is_festival_day(16), "autumn's Hallow's Eve and fairs come round again")


func _check_frosted_page() -> void:
	var menu := root.get_node("PlayerMenu")
	menu.open("calendar")
	await _frames(2)
	check(menu._body.find_child("Calendar grid", true, false) != null, "the Calendar shows this autumn")
	(menu._body.find_child("Cal next", true, false) as Button).pressed.emit()
	await _frames(2)
	var hint := menu._body.find_child("Frosted hint", true, false) as Label
	check(hint != null and menu._body.find_child("Calendar grid", true, false) == null, "next season's page is frosted over")
	check(hint != null and hint.text.begins_with("Winter hasn't come") and hint.text.contains("portal world"),
		"...with a hint about the portal world winter's waiting in (%s)" % (hint.text.replace("\n", " ") if hint else ""))
	portals.quakes.append("frozen_moment")
	menu._fill()
	await _frames(2)
	hint = menu._body.find_child("Frosted hint", true, false) as Label
	check(hint != null and hint.text.contains("The Frozen Moment"), "once its portal's open, the hint names it")
	menu.close()


func _check_winter_opens() -> void:
	clock.set_time(38, 9 * 60.0, true)                   # 28 Autumn, Year 2
	check(clock.season_day() == 28 and not clock.season_open("winter"), "the end of the second autumn")
	portals.clear("frozen_moment")
	check(clock.season_open("winter"), "mending the Frozen Moment opens winter")
	check(clock.is_open(39) and festival.events_on(39).has("First day of Winter"), "the next season is winter now")
	check(festival.big_day(clock.day_of("winter", 21)) == "lights", "...with Winter Lights on it")
	clock.set_time(39, 9 * 60.0, true)
	check(clock.season() == "winter" and clock.season_day() == 1 and clock.year() == 2, "and winter really comes (%s)" % clock.date_string())
	check(not clock.is_open(39 + 28), "spring and summer still wait (in Glenmoor and Rhythm Springs)")


func _check_saving() -> void:
	game.save_game()
	clock.seasons_open = ["autumn"]
	game.load_game()
	check(clock.seasons_open == ["autumn", "winter"] or clock.seasons_open == ["winter", "autumn"]
		or (clock.season_open("winter") and clock.season_open("autumn") and clock.seasons_open.size() == 2),
		"the open seasons save and load (%s)" % str(clock.seasons_open))
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("seasons_open")
	_write(data)
	game.load_game()
	check(clock.seasons_open.size() == 4, "a save from before season unlocks keeps all four")
	data["seasons_open"] = ["autumn"]
	_write(data)
	game.load_game()
	check(clock.season_open("winter"), "a save with the Frozen Moment mended always has winter")
	data["portals"]["cleared"] = ["shard_isle"]
	data["seasons_open"] = ["autumn"]
	_write(data)
	game.load_game()
	check(clock.season() == "autumn" and not clock.season_open("winter"),
		"a save left in a locked season moves on to an open one (%s)" % clock.date_string())


func _check_flurry() -> void:
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	portals.quakes.append_array(["shard_isle", "rootmind", "frozen_moment"])
	portals.cleared_worlds.append_array(["shard_isle", "rootmind"])
	change_scene_to_file(TOWN)
	await _frames(10)
	check(current_scene.get_node_or_null("Portals/Flurry") == null, "Flurry isn't in the Void before her world's mended")
	portals.cleared_worlds.append("frozen_moment")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(3)
	var f := current_scene.get_node_or_null("Portals/Flurry") as Node3D
	check(f != null and f.get_node_or_null("Model") != null and f.get_node_or_null("Spot") != null,
		"once it's mended Flurry's in the Void, and you can talk to her")
	if f == null:
		return
	var plaza := current_scene.get_node("Portals/Portal Plaza") as Node3D
	var ground: Vector3 = root.get_node("Remnants").ground_at(Vector2(f.global_position.x, f.global_position.z))
	check(absf(f.global_position.y - ground.y) < 0.05, "...standing on the ground")
	var flat := Vector2(f.global_position.x - plaza.global_position.x, f.global_position.z - plaza.global_position.z)
	check(flat.length() > 3.0 and flat.length() < 4.6, "...on the Portal Plaza, beside its portal (%.1f m)" % flat.length())
	var near_pillar := 99.0
	for b in plaza.find_children("*", "StaticBody3D", true, false):
		var cs := (b as Node).get_child(0) as Node3D
		near_pillar = minf(near_pillar, Vector2(cs.global_position.x - f.global_position.x, cs.global_position.z - f.global_position.z).length())
	check(near_pillar > 1.4, "...clear of the plaza's crystal pillars (%.1f m)" % near_pillar)
	var flakes := f.get_node("Her Flurry") as MultiMeshInstance3D
	check(flakes.multimesh.instance_count > 20 and (flakes.get_meta("seeds") as Array).size() == flakes.multimesh.instance_count,
		"her own little snowfall falls round her")   # (headless MultiMeshes keep no instances: the shots show it moving)
	var first: Array = portals.flurry_hub_lines()
	check(first[0].contains("came through after you") and portals.has_found("frozen_moment", "flurry_in_hub"),
		"the first time, she says she followed you")
	var later: Array = portals.flurry_hub_lines()
	check(not later.is_empty() and not later[0].contains("came through"), "after that she chats")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var m := f.get_node("Model") as Node3D
	var r0 := m.rotation.y
	player.global_position = f.global_position + f.global_basis.x * 3.0 + Vector3(0, 0.5, 0)
	await _frames(30)
	check(absf(wrapf(m.rotation.y - r0, -PI, PI)) > 0.3, "she turns to look at you")


func _write(data) -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


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
