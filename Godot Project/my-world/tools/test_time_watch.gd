extends SceneTree

# Checks the hero's watch as the game's clock (scripts/time_watch.gd, scripts/watch_face.gd, scripts/hud.gd) and Rex
# and Dash's lab quest (scripts/lab.gd, quests/rex_lab.json):
# - no watch before the first crossing: the clock is just words; once they have one its face shows beside the words,
#   and Settings > Display > Clock picks watch and words, just the watch, or just words
# - the Shift Watch's hands show Earth's time even in Galaxity, the Time Keeper's the time where they are with the
#   other world on its little dial; checking the watch (T) holds it up with what it says
# - the lab is in the yard past Dash's house; Rex offers the quest, Dash tunes the watch, three time ripples turn up (and only
#   then), the watch points at the nearest and each is caught by walking into it; Rook comes for a ball; the lever
#   is a quest spot that runs the Swap-o-Tron; Rex's lines after it finish the quest with the Lab Goggles
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_time_watch.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.time_watch_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var settings: Node
var watches: Node
var lab: Node
var messages: Array = []
var TW: GDScript                # scripts/time_watch.gd, loaded once the autoloads are up (it uses them)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	settings = root.get_node("Settings")
	watches = root.get_node("Watches")
	lab = watches.get_node_or_null("Lab")
	TW = load("res://scripts/time_watch.gd")
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	settings.tips = false
	settings.clock_style = "both"
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.outfits = {"hero": {}}
	clock.pulls_home = false
	check(lab != null, "the lab lives under Watches, as \"Lab\"")

	# --- The watch as the clock ---
	await _go(EARTH)
	clock.set_earth_time(21 * 60.0, true)
	var hud := current_scene.find_child("HUD", true, false)
	check(hud != null and hud.get("watch_face") != null, "the HUD has a watch face")
	await _frames(2)
	check(not hud.watch_face.visible and hud.clock_label.visible, "no watch yet: the clock is just words")
	check(settings.key_name("check_watch") == "T" and settings.pad_name("check_watch") == "D-pad down",
		"Check your watch is on T and D-pad down (%s, %s)" % [settings.key_name("check_watch"), settings.pad_name("check_watch")])
	check(settings.REBINDABLE.any(func(p: Array) -> bool: return p[0] == "check_watch") and
		settings.PAD_REBINDABLE.any(func(p: Array) -> bool: return p[0] == "check_watch"), "...and it can be changed")
	hud.check_watch()
	check(not hud.glance.visible and messages.size() > 0 and str(messages.back()).contains("haven't got a watch"),
		"checking with no watch says so")

	game.items.append("shop:shift_watch")
	game.outfit["hands"] = "shift_watch"
	game.equipment_changed.emit()
	await _frames(2)
	check(hud.watch_face.visible and hud.clock_label.visible, "with the Shift Watch: its face beside the words")
	check(TW.style() == "shift" and is_equal_approx(TW.shown_minutes(), clock.earth_minutes),
		"the Shift Watch shows Earth's time")
	settings.set_value("clock_style", "watch")
	await _frames(1)
	check(hud.watch_face.visible and not hud.clock_label.visible, "\"Just the watch\" hides the words")
	settings.set_value("clock_style", "words")
	await _frames(1)
	check(not hud.watch_face.visible and hud.clock_label.visible, "\"Just words\" hides the watch")
	settings.set_value("clock_style", "both")
	await _frames(1)
	check(hud.clock_label.text.begins_with("Earth"), "the words are still the old clock: \"%s\"" % hud.clock_label.text.replace("\n", " / "))

	hud.check_watch()
	var said: String = hud.glance_label.text
	check(hud.glance.visible and said.contains("Shift Watch") and said.contains("Earth: ") and said.contains("midnight"),
		"checking it holds it up: \"%s\"" % said.replace("\n", " / "))
	check(said.contains("3 hours"), "...and says how long till the portal opens (9 PM: 3 hours)")
	hud.check_watch()
	check(not hud.glance.visible, "pressing again puts it away")

	# In Galaxity, in the Shift: the Shift Watch still shows Earth's (crawling) time
	clock.set_earth_time(0.25 * 60.0, true)
	await _go(TOWN)
	clock.set_time(clock.day, 13 * 60.0, true)
	hud = current_scene.find_child("HUD", true, false)
	check(not clock.on_earth and clock.in_shift(), "now in Galaxity, in the Shift")
	check(is_equal_approx(TW.shown_minutes(), clock.earth_minutes) and clock.earth_minutes < 60.0,
		"in Galaxity the Shift Watch still shows Earth's time (%s)" % clock.earth_time_string())
	hud.check_watch()
	said = hud.glance_label.text
	check(said.contains("Galaxity: day") and said.contains("left before the portal"), "it says how much of the Shift is left: \"%s\"" % said.replace("\n", " / "))
	hud.check_watch()

	# The Time Keeper keeps your own time, with the other world on its little dial
	game.items.append("shop:time_keeper_watch")
	game.outfit["hands"] = "time_keeper_watch"
	game.equipment_changed.emit()
	check(TW.style() == "keeper" and is_equal_approx(TW.shown_minutes(), clock.minutes) and
		is_equal_approx(TW.other_minutes(), clock.earth_minutes), "the Time Keeper shows Galaxity's time here, Earth's on its little dial")
	game.outfit["hands"] = "shift_watch"
	game.outfit["neck"] = "time_keeper_pendant"
	check(TW.style() == "shift", "wearing the Shift Watch, it's the Shift Watch's face")
	game.outfit.erase("hands")
	check(TW.style() == "keeper", "with just the pendant on, it's the Time Keeper")
	game.outfit.erase("neck")
	game.outfit["hands"] = "shift_watch"
	game.items.erase("shop:time_keeper_watch")

	# --- The lab ---
	var built := current_scene.get_node_or_null("Rex and Dash's Lab") as Node3D
	check(built != null, "the lab is in town")
	if built:
		var dash_home := Vector2(81, -9)
		var d := Vector2(built.global_position.x, built.global_position.z).distance_to(dash_home)
		check(d < 30.0, "...next to Dash's house (%.0f m from his door)" % d)
		check(absf(built.global_position.y) < 2.0, "...on the ground (y %.2f)" % built.global_position.y)
	var lever := current_scene.get_node_or_null("Lab Lever")
	check(lever != null and not lever.call("is_open"), "the lever's there, but does nothing before the quest")
	check(lab.nearest_ripple() == null and current_scene.find_child("Time Ripple *", true, false) == null,
		"no ripples before the quest")

	# Rex offers it once The First Night's done
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	var rex := _talker("rex")
	check(rex != null, "Rex is in town")
	await _talk_to(rex)          # (the first talk is his hello)
	await _talk_to(rex, [0])
	check(quests.is_started("rex_lab") and _step("rex_lab") == "see", "Rex asks for help, and the lab quest starts")
	await _frames(4)
	check(_going(rex, "lab"), "Rex waits at the lab")
	check(_going(_talker("dash"), "lab_bench"), "...and Dash at his workbench")

	game.items.erase("shop:shift_watch")
	game.outfit.erase("hands")
	await _talk_to(rex)
	check(dialogue.flags.has("lab_tuned") and TW.has_watch(), "seeing the lab, Dash tunes the watch (and one turns up if they had none)")
	check(_step("rex_lab") == "ripples", "on to the ripples")
	await _frames(4)
	var ripples := current_scene.find_children("Time Ripple *", "", true, false)
	check(ripples.size() == 3, "three time ripples are out (%d)" % ripples.size())
	var b = TW.ripple_bearing()
	check(b != null and float(b.y) > 1.0, "the watch points to the nearest")
	hud.check_watch()
	check(hud.glance_label.text.contains("time ripple"), "checking the watch says it's humming")
	hud.check_watch()
	for r in ripples:
		var n := r as Node3D
		var ground_y := _ground(n.global_position)
		check(n.global_position.y - ground_y < 2.0 and n.global_position.y - ground_y > 0.5,
			"%s floats just over the ground, where you can walk into it" % n.name)
	var player := _player()
	for r in ripples:
		player.global_position = (r as Node3D).global_position - Vector3(0, 0.9, 0)
		player.velocity = Vector3.ZERO
		await _frames(3)
	check(lab.caught_count() == 3, "walking into each catches it (%d of 3)" % lab.caught_count())
	await _frames(3)
	check(current_scene.find_child("Time Ripple *", true, false) == null and lab.nearest_ripple() == null,
		"caught ones are gone, and the pointer's off")
	check(_step("rex_lab") == "rook", "next: Rook")

	var rook := _talker("rook")
	await _talk_to(rook, [0])
	check(_step("rex_lab") == "rook", "asking Rook nicely doesn't work")
	await _talk_to(rook, [1])
	check(_step("rex_lab") == "try", "a ball does")
	await _frames(4)
	check(_going(rex, "lab_pod_rex") and _going(rook, "lab_pod_rook"), "Rex and Rook go to their pods")
	for id in ["rex", "rook"]:
		for r in get_nodes_in_group("routines"):
			if r.get("character_id") == id:
				r.call("snap")
				await _frames(2)
				var y: float = (r.get_parent() as Node3D).global_position.y
				check(y < 1.0, "%s stands on the lab's floor, not its roof (y %.2f)" % [id, y])
	check(lever.call("is_open"), "the lever's ready")
	dialogue.set_flag("lab_lever")
	check(lab.is_running(), "pulling it runs the Swap-o-Tron")
	for i in 60:                  # (by the clock, not frames: headless frames fly by)
		if not lab.is_running():
			break
		await create_timer(0.1).timeout
	check(not lab.is_running() and messages.any(func(m: String) -> bool: return m.contains("FZZZT")), "...which fizzes and puffs")
	check(_step("rex_lab") == "after", "then: talk to Rex")
	var sparkles: int = game.sparkles
	await _talk_to(rex)
	check(quests.is_done("rex_lab"), "Rex's lines finish the quest")
	check(game.has_item("shop:lab_goggles") and game.sparkles == sparkles + 15, "with the Lab Goggles and 15 sparkles")
	await _frames(4)
	check(not _going(rex, "lab_pod_rex"), "and everyone goes back to their day")

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _ground(p: Vector3) -> float:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, -0.2, 0), p + Vector3(0, -30, 0))
	var got := space.intersect_ray(q)
	return got.position.y if not got.is_empty() else -100.0


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
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _going(t: Node, place: String) -> bool:
	if t == null:
		return false
	for n in get_nodes_in_group("routines"):
		if n.get("character_id") == t.get("character_id"):
			return str(n.current_block().get("place", "")) == place
	return false


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
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
