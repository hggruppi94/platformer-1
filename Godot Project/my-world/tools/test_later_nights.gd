extends SceneTree

# Checks nights 3 to 7 (quests/night_3.json to night_7.json, scripts/nights.gd): each starts the next time you land
# in Galaxity after the night before is done, and never two on one visit; each says what's new when you land and has
# a friend to meet (Bramble, Dash and Rex wait by the portal, the Astronaut at the Mothership Pad, Mr. Palmer at his
# window), whose lines tick the first step; then a list of the night's schematics and its spotlight (a race, the
# Observatory, building a ride, flying the mothership, the castle school, the Scary World gate and the Agent of
# Chaos), each ticked by really doing it; and each pays out. After night 7 nothing's spotlighted, and a skipped night
# still lets the next one start.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_later_nights.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.later_nights_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const FRIENDS := {3: "bramble", 4: "dash", 5: "astronaut", 6: "rex", 7: "mr_palmer"}
const AT_PORTAL := ["bramble", "dash", "rex"]
const REWARDS := {3: 10, 4: 12, 5: 12, 6: 14, 7: 20}

var failures := 0
var N: Node
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var requests: Node
var S: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	N = root.get_node("Nights")
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	requests = root.get_node("Requests")
	S = root.get_node("Schematics")
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	dialogue.reset()
	quests.reset()
	root.get_node("Arsenal").reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	clock.pulls_home = false

	# The First Night and night 2, done (tools/test_first_night.gd and test_nights.gd walk those)
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	requests.nights = 2
	await _new_visit()
	check(quests.is_started("night_2"), "night 2 starts on the next visit")
	for i in 10:
		if quests.is_done("night_2"):
			break
		quests.skip("night_2")
	await _go(EARTH)
	await _go(TOWN)
	check(quests.is_done("night_2") and not dialogue.flags.has("night_3"),
		"with night 2 done, night 3 waits for the next visit (not the same one)")

	for n in range(3, 8):
		await _night(n)

	check(N.current().is_empty(), "after night 7 nothing's spotlighted")
	check(S.found_count() == S.LIST.size(), "...and every schematic's been found (%d of %d)" % [S.found_count(), S.LIST.size()])
	await _new_visit()
	check(not dialogue.flags.has("night_8"), "...and there's no night 8 to start")

	# --- A skipped night still lets the next one start ---
	dialogue.reset()
	quests.reset()
	for f in ["first_night_start"]:
		dialogue.set_flag(f)
	quests.check()
	for q in ["first_night", "night_2", "night_3"]:
		if q != "first_night":
			await _new_visit()
		for i in 30:
			if quests.is_done(q):
				break
			quests.skip(q)
	await _new_visit()
	check(quests.is_done("night_3") and quests.is_started("night_4"), "skipping a whole night, the next one starts on the next visit")

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _night(n: int) -> void:
	var q := "night_%d" % n
	requests.nights = n
	messages.clear()
	await _new_visit()
	check(dialogue.flags.has("night_%d" % n) and quests.is_started(q) and _step(q) == "hi",
		"night %d starts when you land, on meeting %s" % [n, FRIENDS[n]])
	await create_timer(3.4).timeout
	check(messages.any(func(m: String) -> bool: return m.contains("Night %d" % n)), "...and says what's new when you land")
	check(str(N.goals()[0][1][0]).contains("Night %d" % n), "...and the Goals page says it's night %d" % n)
	var friend := _talker(FRIENDS[n])
	check(friend != null, "%s is there to talk to" % FRIENDS[n])
	if FRIENDS[n] in AT_PORTAL:
		check(_going(friend, "portal"), "...waiting by the portal")
	if friend:
		await _talk_to(friend)
	check(dialogue.flags.has("n%d_hi" % n) and _step(q) == "explore", "talking to %s ticks it, then the night's list" % FRIENDS[n])
	var items: Array = quests.current_step(q).checklist.map(func(c: Array) -> String: return str(c[0]))
	var before: int = game.sparkles
	for flag in items:
		await _do(n, str(flag))
		check(dialogue.flags.has(flag), "night %d: %s" % [n, flag])
	await _frames(4)
	quests.check()
	await _frames(2)
	check(quests.is_done(q) and game.sparkles >= before + int(REWARDS[n]),
		"night %d is done, for %d sparkles (%d)" % [n, REWARDS[n], game.sparkles - before])
	await _go(EARTH)
	await _go(TOWN)
	check(not dialogue.flags.has("night_%d" % (n + 1)), "...and the next night waits for the next visit")


func _do(n: int, flag: String) -> void:
	# Really do each thing on a night's list, the way a player would
	var player := _player()
	if flag.begins_with("schematic_"):
		var id := flag.trim_prefix("schematic_")
		var e: Dictionary = S.entry(id)
		if e.has("sky"):
			var p := current_scene.get_node_or_null("Schematic " + id) as Node3D
			check(p != null and p.global_position.y > 30.0, "the %s's schematic floats high in the sky" % id)
			S.pick_up(id)                          # (flying the mothership through it: tools/test_schematics.gd)
			return
		if str(e.scene) == "school" and current_scene.scene_file_path != SCHOOL:
			await _go(SCHOOL)
			player = _player()
		var pick := current_scene.get_node_or_null("Schematic " + id) as Node3D
		check(pick != null, "the %s's schematic is out" % id)
		if pick and player:
			player.global_position = pick.global_position + Vector3(0, 0.5, 0)
			player.velocity = Vector3.ZERO
			await _frames(6)
		if current_scene.scene_file_path != TOWN:
			await _go(TOWN)
		return
	match flag:
		"n3_race":
			root.get_node("Races").finished.emit("lake_loop", 2)
		"n4_observatory":
			await _stand_by("Observatory", Vector3(0, 0, 12))
		"n4_ride":
			game.sparkles += 30
			root.get_node("Shop").buy("ride_bike")
			await _frames(40)
		"n5_fly":
			var ship := get_first_node_in_group("mothership")
			if ship and player:
				ship.call("board", player)                 # the tractor beam lifts her into the cockpit
				for i in 400:
					await process_frame
					if ship.call("is_piloted") and dialogue.flags.has("n5_fly"):
						break
				ship.call("beam_down")
				await create_timer(4.0).timeout
		"n6_school":
			await _go(SCHOOL)
			await _frames(40)
			await _go(TOWN)
		"n7_gate":
			await _stand_by("Scary World Gate", Vector3(0, 0, 6))
		"n7_giant":
			var giant := current_scene.find_child("ChaosGiant", true, false) as Node3D
			if giant and player:
				player.global_position = giant.global_position + Vector3(25, 1, 25)
				await _frames(40)


func _stand_by(node_name: String, off: Vector3) -> void:
	var n := current_scene.find_child(node_name, true, false) as Node3D
	var player := _player()
	if n and player:
		player.global_position = n.global_position + off + Vector3(0, 1, 0)
		player.velocity = Vector3.ZERO
		await _frames(40)


func _new_visit() -> void:
	# The next Shift: a new Galaxity day, landing in town from Earth
	clock.set_earth_time(0.3 * 60.0, true)
	clock.set_time(clock.day + 1, 9 * 60.0, true)
	await _go(EARTH)
	await _go(TOWN)


func _step(quest_id: String) -> String:
	return str(quests.current_step(quest_id).get("id", ""))


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 40:
		await process_frame
		if current_scene and current_scene.scene_file_path == scene:
			break
	await _frames(6)


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _going(t: Node, place: String) -> bool:
	var r := t.get_parent().find_child("Routine", true, false)
	if r == null:
		for n in get_nodes_in_group("routines"):
			if n.get("character_id") == t.get("character_id"):
				r = n
	return r != null and str(r.current_block().get("place", "")) == place


func _talk_to(t: Node3D, picks: Array = []) -> void:
	var player := _player()
	var body := t.get_parent() as Node3D
	player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
