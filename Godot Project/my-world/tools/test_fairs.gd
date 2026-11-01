extends SceneTree

# Checks the fairs of every season and Hallow's Eve (scripts/festival.gd, festival_green.gd, hallows_eve.gd). There's a
# fair on the green every Saturday, dressed for the season: the Frost Fair in winter (ice fishing, a sleigh ride, Gus's
# cocoa, a gingerbread house for the baking contest), the Spring Fair (hook a duck) and the Summer Fair, each with its
# own hours, and the stall-holders at their stalls whatever the season. The treats change with the season (shop items'
# "season"). Then Hallow's Eve on 28 Autumn: a glowing lantern and a knock spot at every house on Maple Lane from 5 PM,
# a treat and a sparkle from each door once, a bonus for all of them, the kids going door to door, and it all comes
# down at 9. The doors knocked save and load.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_fairs.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.fairs_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var F: Node
var game: Node
var clock: Node
var dialogue: Node
var town: Node3D


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
	F = root.get_node("Festival")
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	dialogue.reset()
	root.get_node("Quests").reset()
	F.reset()
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.reset()

	# --- The calendar of fairs ---
	var winter_sat: int = clock.day_of("winter", 6)
	var spring_sat: int = clock.day_of("spring", 6)
	var summer_sat: int = clock.day_of("summer", 6)
	check(F.is_festival_day(winter_sat) and F.fair_name(winter_sat) == "Frost Fair" and F.fair_name(spring_sat) == "Spring Fair"
		and F.fair_name(summer_sat) == "Summer Fair" and F.fair_name(2) == "Autumn Festival", "a fair every Saturday, one for each season")
	check(F.events_on(winter_sat).has("Frost Fair, 4-9 PM") and F.events_on(10).has("Hallow's Eve, trick-or-treat 5-9 PM"),
		"the Calendar page lists them (%s)" % [F.events_on(winter_sat)])

	# --- A winter Saturday: the Frost Fair ---
	clock.day = winter_sat
	clock.set_earth_time(15 * 60.0 + 30.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(4)
	town = current_scene as Node3D
	(town.find_child("Player", true, false) as Node3D).global_position = Vector3(0, 1, 16)
	check(F.is_festival_day() and not F.is_on(), "3:30 PM on a winter Saturday: not on yet")
	clock.set_earth_time(16 * 60.0 + 10.0, true)
	await _wait(0.7)
	var green := town.get_node_or_null("Autumn Festival") as Node3D
	check(F.is_on() and green != null, "the Frost Fair's up at 4:10 PM (an hour earlier than autumn's)")
	if green == null:
		_end()
		return
	check(_labels(green).has("FROST FAIR") and _labels(green).has("Ice fishing!") and _labels(green).has("SLEIGH RIDE")
		and _labels(green).has("Gus's Cocoa Cart"), "the banner, the ice-fishing barrel, the sleigh and the cocoa cart %s" % [_labels(green)])
	var shop := root.get_node("Shop")
	var cart: Array = shop.for_stall("Cider Cart").map(func(it: Dictionary) -> String: return str(it.id))
	var treats: Array = shop.for_stall("Festival Treats").map(func(it: Dictionary) -> String: return str(it.id))
	check("hot_cocoa" in cart and not "pink_lemonade" in cart and "gingerbread_kid" in treats and not "ice_lolly" in treats,
		"winter treats: cocoa and gingerbread, no lemonade or ice lollies %s %s" % [cart, treats])
	await _physics(10)
	var r: Node = dialogue.routine_of("hank")
	check(r and r.current_block().get("place", "") == "fest_apples_stall", "Hank minds the ice-fishing barrel")
	F.start_bobbing()
	await _frames(2)
	var bob: Node = F.bobbing()
	check(bob != null and str(bob._title.text).begins_with("Ice fishing!"), "the barrel game is ice fishing (%s)" % (bob._title.text if bob else "?"))
	if bob:
		bob.marker = bob.zone
		bob.bite()
		bob.go = bob.GOES
		bob._wait = 0.0
		bob._finish()
		check(str(bob._say.text).contains("1 fish"), "...and you catch a fish (%s)" % bob._say.text)
		bob.close()
	game.sparkles = 20
	shop.buy("contest_pie")
	var lines: Array = F.judge_pie()
	check(" ".join(lines).contains("gingerbread house") and F.ribbons[0] == 1, "Dottie judges a gingerbread house")
	clock.set_earth_time(21 * 60.0 + 5.0, true)
	await _wait(0.7)
	check(not F.is_on() and town.get_node_or_null("Autumn Festival") == null, "it's all packed away after 9 PM")

	# --- A spring Saturday: hook a duck ---
	clock.day = spring_sat
	clock.set_earth_time(18 * 60.0, true)
	await _wait(0.7)
	green = town.get_node_or_null("Autumn Festival") as Node3D
	check(green != null and _labels(green).has("SPRING FAIR") and _labels(green).has("Hook a duck!") and _labels(green).has("HAYRIDE"),
		"the Spring Fair: hook a duck and the hayride")
	clock.day = summer_sat                                     # straight on to a summer Saturday, the fair still up
	await _wait(0.7)
	await _frames(2)
	green = town.get_node_or_null("Autumn Festival") as Node3D
	check(green != null and _labels(green).has("SUMMER FAIR") and not _labels(green).has("SPRING FAIR"),
		"jumping to another season's Saturday dresses the fair again %s" % [_labels(green) if green else []])
	clock.day = spring_sat
	await _wait(0.7)
	cart = shop.for_stall("Cider Cart").map(func(it: Dictionary) -> String: return str(it.id))
	check("pink_lemonade" in cart and not "hot_cocoa" in cart, "...and pink lemonade at Gus's cart")

	# --- Hallow's Eve ---
	clock.day = 10                                             # Sunday 28 Autumn
	clock.set_earth_time(16 * 60.0, true)
	await _wait(0.7)
	check(clock.date_string() == "Sunday 28 Autumn" and F.is_hallows_eve() and not F.hallows_on()
		and town.get_node_or_null("Hallows Eve") == null, "Hallow's Eve afternoon: not started yet")
	clock.set_earth_time(17 * 60.0 + 30.0, true)
	await _wait(0.7)
	var lane := town.get_node_or_null("Hallows Eve") as Node3D
	var doors: Array = lane.find_children("Door *", "", false, false) if lane else []
	check(lane != null and doors.size() == F.HALLOWS_DOORS.size(), "5:30 PM: a lantern and a door to knock at every house (%d)" % doors.size())
	await _physics(10)
	var out := []
	for id in ["nina_earth", "bruno", "prue", "juniper", "theo", "ozzie"]:
		var kr: Node = dialogue.routine_of(id)
		if kr and kr.activity() == "trick_or_treat":
			out.append(id)
	check(out.size() == 6, "the kids are out trick-or-treating %s" % [out])
	dialogue.talks["bruno"] = 3
	check(" ".join(dialogue._pick("bruno").get("lines", [])).contains("meatball"), "Bruno's a spooky meatball")
	var before: int = game.sparkles
	lines = F.treat_lines("palmer_house")
	check(game.sparkles == before + F.TREAT_PRIZE and " ".join(lines).contains("Trick or treat"), "knocking: a treat and a sparkle")
	lines = F.treat_lines("palmer_house")
	check(game.sparkles == before + F.TREAT_PRIZE and " ".join(lines).contains("Back again"), "...once a door")
	for door in F.HALLOWS_DOORS:
		F.treat_lines(door)
	check(game.sparkles == before + F.TREAT_PRIZE * F.HALLOWS_DOORS.size() + F.TREAT_BONUS and F.doors_knocked() == F.HALLOWS_DOORS.size(),
		"every door on the lane: the bonus too (%d)" % (game.sparkles - before))
	var spot := lane.get_node("Door okafor_house")
	spot.call("use")
	await _frames(2)
	check(dialogue.is_active(), "Interact at a door starts the trick-or-treat")
	dialogue.end()
	check(root.get_node("Quests").log_text().contains("Hallow's Eve"), "the Quests sheet says it's Hallow's Eve")
	var saved: Dictionary = F.save_data()
	F.reset()
	F.load_data(saved)
	check(F.doors_knocked() == F.HALLOWS_DOORS.size(), "the doors knocked save and load")
	clock.set_earth_time(21 * 60.0 + 5.0, true)
	await _wait(0.7)
	check(town.get_node_or_null("Hallows Eve") == null, "after 9 PM the lanterns are gone")
	_end()


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label3D", true, false).map(func(l: Label3D) -> String: return l.text)


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(1 if failures > 0 else 0)
