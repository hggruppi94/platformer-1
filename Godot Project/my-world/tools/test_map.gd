extends SceneTree

# Checks the town map (scripts/map_screen.gd): opening and closing it (M, Pause), where Nina, people, homes, quest
# steps and the open portal show up, and the corner minimap.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_map.gd
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var map: Node
var settings: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	map = root.get_node("TownMap")
	settings = root.get_node("Settings")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.riding = false                             # on foot, whatever the save says (riding turns her by itself)
	dialogue.reset()
	quests.reset()
	var minimap_was: bool = settings.minimap

	check(map._texture != null and map._texture.get_width() >= 512, "the map picture loads (%dpx)" % (map._texture.get_width() if map._texture else 0))
	check(map.to_map(Vector3(map._center.x, 0, map._center.y)).is_equal_approx(Vector2(0.5, 0.5)), "the map's middle is the middle of the picture")
	check(settings.REBINDABLE.any(func(p: Array) -> bool: return p[0] == "map") and settings.key_name("map") == "M", "the map key is rebindable, on M")

	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var player := town.find_child("Player", true, false) as CharacterBody3D
	player.global_position = Vector3(-72, 2, 60)

	# Everything on the map is inside the picture
	var all_in := true
	for b in map.BUILDINGS:
		var n := town.get_node_or_null(b) as Node3D
		if n == null:
			check(false, "building on the map is in town: %s" % b)
			continue
		var m: Vector2 = map.to_map(n.global_position)
		all_in = all_in and m.x > 0.0 and m.x < 1.0 and m.y > 0.0 and m.y < 1.0
	check(all_in, "all %d labelled buildings are on the map" % map.BUILDINGS.size())
	var tm: Vector2 = map.to_map(town.get_node("Town Hall").global_position)
	var mk: Vector2 = map.to_map(town.get_node("Market Square").global_position)
	check(tm.y < mk.y and absf(tm.x - mk.x) < 0.02, "north is up: the Town Hall is above the Market Square")

	# Open and close with M; Pause closes it without opening the menu
	_press("map")
	await _frames(3)
	check(map.is_open() and paused, "M opens the map (game paused)")
	await _frames(2)
	_press("map")
	await _frames(3)
	check(not map.is_open() and not paused, "...and closes it")
	_press("map")
	await _frames(3)
	_press("pause")
	await _frames(3)
	check(not map.is_open() and not paused and not root.get_node("PauseMenu").is_open(), "Pause closes the map (not opening the menu)")

	# Nina's arrow faces where she faces
	player.get_node("Visual").rotation.y = PI / 2                # facing +x: east, right on the map
	await _frames(2)
	check(absf(sin(map.nina_facing()) - 1.0) < 0.01, "Nina's facing on the map: east is right")

	# People: out and about by day, at home at night
	clock.set_time(1, 13 * 60.0, true)
	await _physics(4)
	var by_day: Array = map.people()
	check(by_day.size() >= 6 and by_day.all(func(p: Dictionary) -> bool: return p.id == "pip" or not p.home), "1 PM: everyone's out (but Pip, asleep)")
	clock.set_time(1, 23 * 60.0, true)
	await _physics(4)
	var dash: Dictionary = map.people().filter(func(p: Dictionary) -> bool: return p.id == "dash")[0]
	check(dash.home, "11 PM: Dash shows at home")

	# Quest markers: the people still to ask, then the poster spots
	clock.set_time(1, 13 * 60.0, true)
	check(map.quest_markers().is_empty(), "no quest, no stars")
	quests.load_data({"rex_campaign": {"step": 0, "since_day": 1}})
	check(map.quest_markers().size() == 4, "asking around: 4 stars (%d)" % map.quest_markers().size())
	dialogue.flags["asked_dash"] = true
	check(map.quest_markers().size() == 3, "asked Dash: 3 stars")
	quests.load_data({"rex_campaign": {"step": 2, "since_day": 1}})
	check(map.quest_markers().is_empty(), "posters, waiting for tomorrow: no stars")
	clock.set_time(2, 10 * 60.0, true)
	check(map.quest_markers().size() == 4, "posters, next day: a star on each poster spot")
	quests.load_data({"rex_campaign": {"step": 4, "since_day": 1}})
	var palmer: Array = map.quest_markers()
	check(palmer.size() == 1 and (palmer[0].pos as Vector3).distance_to(town.get_node("Town Hall").global_position) < 14.0, "Mr. Palmer: a star at the Town Hall")

	# The portal: the player is only in Galaxity in the Shift, so it's open whatever Galaxity's time
	clock.set_time(3, 20.0, true)
	check(map.portal_open(), "in the Shift the map shows the portal open")
	clock.set_time(3, 14 * 60.0, true)
	check(map.portal_open(), "...all through Galaxity's day")

	# Drawing works (nothing breaks with all of the above on it)
	_press("map")
	await _frames(4)
	check(map.is_open(), "the map draws with markers on")
	_press("map")
	await _frames(2)

	# Minimap: only when switched on, only outdoors
	settings.minimap = false
	await _frames(2)
	check(not map._mini_layer.visible, "minimap off by default setting")
	settings.minimap = true
	await _frames(2)
	check(map._mini_layer.visible, "minimap on: shows in the corner")
	dialogue.talk_to(town.find_children("Talk", "Area3D", true, false)[0])
	await _frames(2)
	dialogue.end()
	await _frames(2)
	change_scene_to_file("res://scenes/interiors/ninas_house.tscn")
	await _frames(6)
	check(not map._mini_layer.visible, "...but not indoors")
	_press("map")
	await _frames(3)
	check(map.is_open() and not map.in_town(), "the map opens indoors too (says to step outside)")
	_press("map")
	await _frames(2)
	settings.minimap = minimap_was

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(failures)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
