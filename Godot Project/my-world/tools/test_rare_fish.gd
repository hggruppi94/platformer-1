extends SceneTree

# Checks the Aquarium's rare fish (scripts/rare_fish.gd, quests/aquarium.json): eight fish, one in each place with deep
# water, each swimming down deep under at least 2 m of water; floating on the top before Otto's taught you to dive
# isn't close enough to catch one; diving after it catches it (once), starts the quest if it hadn't started, and it
# goes off to the Aquarium; the Tide Reef's only turns up once its sea is in; Otto asks for them on the Portal Plaza;
# in the Aquarium each caught one swims in its own tank with its name; with all eight the quest is done, once.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_rare_fish.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.fish_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.fish_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var portals: Node
var dialogue: Node
var quests: Node
var fish: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(480.0, true, false, true).timeout.connect(func() -> void:
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
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fish = root.get_node("Watches/Fish")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	var fn := root.get_node("FirstNight")
	quests.state[fn.ID] = {"step": 0, "done": true, "since_day": 1}

	check(fish.FISH.size() == 8, "eight rare fish (%d)" % fish.FISH.size())
	var places := {}
	var names := {}
	for f in fish.FISH:
		places[f.place] = true
		names[f.name] = true
	check(places.size() == 8 and names.size() == 8, "...each in its own place, each with its own name")
	var q = JSON.parse_string(FileAccess.get_file_as_string("res://quests/aquarium.json"))
	check(q is Dictionary and (q.steps[0].done.flags as Array).size() == 8, "the Rare Fish quest wants all eight")

	for id in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(id)
		portals.note_found(id, "swim_taught")

	# Each one, down deep in its place
	for f in fish.FISH:
		change_scene_to_file(fish.scene_of(str(f.place)))
		await _frames(14)
		await _physics(10)
		var g: Node3D = null
		for k in 32:                              # (it swims in once the place's water is in: the reef floods first)
			await _seconds(0.25)
			g = current_scene.find_child("Rare Fish " + str(f.id), true, false) as Node3D
			if g:
				break
		var deep := false
		if g:
			var w: Node = fish.SWIM.water_at(self, g.global_position)
			deep = w != null and float(w.get("water_y")) - g.global_position.y > 1.0
			var bed: float = fish._ground(Vector3(g.global_position.x, 60.0, g.global_position.z))
			deep = deep and g.global_position.y > bed + 0.3
		var info := ""
		if g:
			var w2: Node = fish.SWIM.water_at(self, g.global_position)
			info = "at %s, water %s" % [g.global_position, (str(w2.get("water_y")) if w2 else "none")]
		check(g != null and deep, "%s swims down deep in %s (%s)" % [f.name, f.place, info])
		if f.place == "town":
			await _check_catching(g, f)

	# ...the Tide Reef's only once its sea's in
	portals.cleared_worlds.erase("tide_reef")
	change_scene_to_file(fish.scene_of("tide_reef"))
	await _frames(14)
	await _physics(10)
	await _seconds(1.6)
	check(current_scene.find_child("Rare Fish rainbow_puffer", true, false) == null, "...the Tide Reef's isn't there while its tide is stuck out")
	portals.cleared_worlds.append("tide_reef")

	# Otto asks on the Portal Plaza (a fresh start for the quest)
	dialogue.flags.erase("aquarium_start")
	quests.state.erase("aquarium")
	var lines: Array = portals.otto_fish_lines()
	check(lines == portals.OTTO_AQUARIUM and lines.size() <= 3, "Otto asks you to fill the Aquarium's tanks (%s)" % [lines])
	portals.note_found("tide_reef", "otto_in_hub")
	check(portals.otto_hub_lines() == portals.OTTO_AQUARIUM, "...the first thing he says once he's on the plaza")
	dialogue.set_flag("aquarium_start")
	await _frames(4)
	check(quests.state.has("aquarium") and not quests.is_done("aquarium"), "...and the quest's on")

	# The Aquarium: some caught
	for f in fish.FISH.slice(0, 3):
		dialogue.set_flag("fish_" + str(f.id))
	change_scene_to_file(fish.AQUARIUM)
	await _frames(14)
	await _seconds(1.6)
	var swimming := 0
	var unknown := 0
	for i in 8:
		var tank := current_scene.find_child("Tank %d" % (i + 1), true, false)
		if tank and tank.get_node_or_null("Rare Fish") != null:
			swimming += 1
		if tank and tank.get_node_or_null("Rare Fish Name") and (tank.get_node("Rare Fish Name") as Label3D).text == "?":
			unknown += 1
	check(swimming == 3 and unknown == 5, "in the Aquarium each caught fish swims in its own tank (%d), the rest say ? (%d)" % [swimming, unknown])
	check(not dialogue.flags.has("aquarium_full"), "...not done with three")
	# All eight
	for f in fish.FISH:
		dialogue.set_flag("fish_" + str(f.id))
	await _frames(4)
	change_scene_to_file(TOWN)
	await _frames(10)
	change_scene_to_file(fish.AQUARIUM)
	await _frames(14)
	await _seconds(2.0)
	check(dialogue.flags.has("aquarium_full") and quests.is_done("aquarium"), "with all eight, every tank's full and the quest's done")
	_finish()


func _check_catching(g: Node3D, f: Dictionary) -> void:
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var mid: Vector3 = g.get_meta("middle")
	var w: Node = fish.SWIM.water_at(self, mid)
	var top := float(w.get("water_y"))
	# Floating on top before you can dive: not close enough
	portals.cleared_worlds.erase("tide_reef")
	player.global_position = Vector3(mid.x, top - 0.5, mid.z)
	player.velocity = Vector3.ZERO
	await _seconds(2.5)
	check(player.call("is_swimming") and not fish.is_caught(f.id), "before you can dive, you float on top and can't catch it")
	portals.cleared_worlds.append("tide_reef")
	# Diving after it: it darts, but you get it
	var t := 0
	while not fish.is_caught(f.id) and t < 600 and is_instance_valid(g):
		player.global_position = player.global_position.lerp(g.global_position + Vector3(0, -0.8, 0), 0.15)
		player.velocity = Vector3.ZERO
		await physics_frame
		t += 1
	check(fish.is_caught(f.id), "dive after it and it's caught: %s" % f.name)
	check(dialogue.flags.has("aquarium_start"), "...which starts the quest too")
	check(fish.caught_count() == 1, "...counted once")
	await _seconds(2.0)
	check(current_scene.find_child("Rare Fish " + str(f.id), true, false) == null, "...and it's off to the Aquarium")
	player.global_position = Vector3(mid.x + 8.0, top + 3.0, mid.z + 8.0)


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


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
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
