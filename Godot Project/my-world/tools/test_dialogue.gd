extends SceneTree

# Checks talking to people (scripts/dialogue.gd, talker.gd, res://dialogue/*.json). Run it twice: the first run talks
# to everyone in town and saves, the second starts up like the real game and checks the talks came back.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_dialogue.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_dialogue.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const PEOPLE := ["dash", "rex", "rook", "bramble", "pip", "green_man"]
const PERIODS := {"morning": 8 * 60.0, "day": 13 * 60.0, "evening": 19 * 60.0, "night": 22 * 60.0, "shift": 20.0}

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var player: CharacterBody3D
var talkers := {}
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	# Never hang: give up after a few minutes (your save stays safe in the backup until --check-load puts it back)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	dialogue.reset()
	_check_files()

	change_scene_to_file(TOWN)
	await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t
	check(talkers.size() == PEOPLE.size() and PEOPLE.all(func(p: String) -> bool: return talkers.has(p)),
		"everyone in town has a talk spot: %s" % [talkers.keys()])
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))

	# Names only show up close, and only the nearest person gets the prompt (12:45: Dash on his snack break)
	clock.set_time(1, 12 * 60 + 45.0, true)
	await _stand_by("dash", 8.0)
	check(not _name_shown("dash") and not _name_shown("green_man"), "names hidden while far away")
	await _stand_by("dash", 1.5)
	check(_name_shown("dash") and _prompt_shown("dash"), "close to Dash: name and '%s'" % talkers["dash"]._prompt.text)
	check(not _name_shown("green_man") and not _name_shown("bramble"), "...and nobody else's name")

	# First meetings, at 7 PM when everyone's out and about
	clock.set_time(1, PERIODS.evening, true)
	for id in PEOPLE:
		var lines := await _talk(id)
		var file := _expected_lines(id, 0, "evening")
		check(lines.size() == file.size() and lines.size() > 0 and lines[0][1] == _fill(file[0]),
			"%s, first time: %d lines, \"%s\"" % [id, lines.size(), lines[0][1] if lines.size() > 0 else ""])
		check(dialogue.talks.get(id, 0) == 1, "%s: talked to once" % id)
		if id == "dash":
			check(lines.any(func(l: Array) -> bool: return l[0] == "Nina"), "Nina has lines too")

	# Time of day: Pip at night is all about the lamps; in the Shift, the portal
	clock.set_time(1, PERIODS.night, true)
	var pip := await _talk("pip", [1])
	check(pip.any(func(l: Array) -> bool: return l[1].to_lower().contains("lamp")), "Pip at night: " + (pip[0][1] if pip.size() else ""))
	clock.set_time(2, PERIODS.shift, true)
	var rook_shift := await _talk("rook")
	check(rook_shift.size() > 0 and rook_shift[0][1].begins_with("Awoo"), "Rook in the Shift: " + (rook_shift[0][1] if rook_shift.size() else ""))
	var pip_shift := await _talk("pip")
	check(pip_shift.size() > 0 and pip_shift[0][1].contains("portal"), "Pip in the Shift: " + (pip_shift[0][1] if pip_shift.size() else ""))
	var green := await _talk("green_man")
	check(green.size() > 0 and green[0][1].contains("portal") and green[0][0] == "", "Green Man in the Shift (narration): " + (green[0][1] if green.size() else ""))

	# Choices: vote for Rex (sets a flag), take Bramble's pick-me-up (heals), play fetch with Rook. 11 AM: Rex is
	# campaigning at the Town Hall, Bramble gardening, Rook following Rex.
	clock.set_time(2, 11 * 60.0, true)
	dialogue.talks["rex"] = 1
	dialogue.talks["bramble"] = 1
	dialogue.talks["rook"] = 1
	var rex := await _talk("rex", [0])         # second talk: the vote question
	check(rex.any(func(l: Array) -> bool: return l[0] == "Nina" and l[1] == "You've got my vote!"), "Nina says her answer")
	check(dialogue.flags.has("voted_rex"), "voting for Rex sets the 'voted_rex' flag")
	check(rex.size() > 0 and rex[-1][1].contains("brain breaks"), "Rex: " + (rex[-1][1] if rex.size() else ""))
	game.hp = 1
	var bramble := await _talk("bramble", [0])
	check(game.hp == game.max_hp, "Bramble's pick-me-up fills HP (%d/%d)" % [game.hp, game.max_hp])
	check(bramble.size() > 0 and bramble[-1][1].contains("daisy"), "Bramble: " + (bramble[-1][1] if bramble.size() else ""))
	var rook := await _talk("rook", [1])       # second talk: fetch
	check(rook.any(func(l: Array) -> bool: return l[1].contains("wagging")), "Rook and the fetch answer")

	# While talking she can't walk off; the wanderer stays put and faces her
	await _stand_by("rex", 1.6)
	await _start_talking("rex")
	await _frames(3)
	var rex_node := talkers["rex"].get_parent() as Node3D
	var rex_at := rex_node.global_position
	check(dialogue.is_active() and player.input_locked, "talking locks Nina's moving and jumping")
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	check(rex_node.global_position.distance_to(rex_at) < 0.2 and rex_node.get("talking"), "Rex stands still while talking")
	await _finish()
	await create_timer(0.3).timeout
	check(not player.input_locked, "...and she can move again after")

	# Someone out gardening stops and turns to face her while they talk, then carries on
	await _stand_by("bramble", 1.6)
	var bramble_node := talkers["bramble"].get_parent() as Node3D
	await _start_talking("bramble")
	await create_timer(1.0).timeout
	var to_nina := player.global_position - bramble_node.global_position
	to_nina.y = 0.0
	var facing := bramble_node.global_transform.basis.z
	facing.y = 0.0
	check(rad_to_deg(facing.angle_to(to_nina)) < 15.0, "Bramble turns to face Nina (%.0f degrees off)" % rad_to_deg(facing.angle_to(to_nina)))
	var bramble_at := bramble_node.global_position
	await create_timer(1.0).timeout
	check(bramble_node.global_position.distance_to(bramble_at) < 0.05, "...and stops gardening while they talk")
	await _finish()
	check(not bramble_node.get("talking"), "...and carries on after")

	# Save: talk counts and flags
	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var saved: Dictionary = data.get("dialogue", {}) if data is Dictionary else {}
	check(saved.get("talks", {}).get("rex", 0) == 3 and "voted_rex" in saved.get("flags", []),
		"save.json has the talks and flags: %s" % [saved])
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_files() -> void:
	# Every file reads, and every one of them has something to say at every time of day, any number of visits in
	for id in PEOPLE:
		var data: Dictionary = dialogue.load_character(id)
		check(not data.is_empty() and data.get("name", "") != "", "%s.json reads (%s)" % [id, data.get("name", "?")])
		var bad := []
		for period in PERIODS:
			clock.set_time(1, PERIODS[period], true)
			for count in 8:
				dialogue.talks[id] = count
				var convo: Array = dialogue.pick_conversation(id)
				if convo.is_empty():
					bad.append("%s/%d: nothing" % [period, count])
				for step in dialogue._steps(convo):
					if step.has("choice") and not (step.choice.size() in [2, 3]):
						bad.append("%s/%d: a choice needs 2-3 answers" % [period, count])
		check(bad.is_empty(), "%s has lines for every time of day: %s" % [id, bad])
	dialogue.reset()


func _expected_lines(id: String, count: int, period: String) -> Array:
	var keep: Dictionary = dialogue.talks.duplicate()
	clock.set_time(clock.day, PERIODS[period], true)
	dialogue.talks[id] = count
	var lines: Array = dialogue.pick_conversation(id)
	dialogue.talks = keep
	return lines


func _fill(line: String) -> String:
	return line.substr(6) if line.begins_with("Nina: ") else line


func _talk(id: String, picks: Array = []) -> Array:
	# Walk up, press Interact, read every line (skipping the typing), answer questions with picks, in order
	await _stand_by(id, 1.5)
	said.clear()
	await _start_talking(id)
	await _frames(2)
	if not dialogue.is_active():
		check(false, "couldn't start talking to " + id)
		return []
	await _finish(picks)
	return said.duplicate()


func _start_talking(id: String) -> void:
	# Interact, as a player would. If someone else happens to be nearer (Rook tags along right behind Rex and Dash),
	# talk to the one we came for directly.
	await _frames(1)
	if dialogue._nearest == talkers[id]:
		_press("interact")
	else:
		dialogue.talk_to(talkers[id])


func _finish(picks: Array = []) -> void:
	var guard := 200
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick].grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")                   # first press shows the whole line, the next one moves on
			await _frames(1)
			_press("interact")
		await _frames(2)


func _stand_by(id: String, distance: float) -> void:
	for i in 3:
		await physics_frame                       # let routines put everyone where the time says
	await _in_town()
	var who := talkers[id].get_parent() as Node3D
	var side := _clear_side(id, who.global_position, distance)
	if side == Vector3.ZERO and who is CharacterBody3D:
		# A wanderer (Rex, Rook) standing right next to someone else: walk him a few steps off first
		for k in 8:
			who.global_position += Vector3(3, 0.5, 0).rotated(Vector3.UP, k * TAU / 8.0)
			for i in 4:
				await physics_frame
			side = _clear_side(id, who.global_position, distance)
			if side != Vector3.ZERO:
				break
	if side == Vector3.ZERO:
		side = Vector3(1.7, 0, 0.6).normalized()
	var at := who.global_position + side * distance + Vector3(0, 0.6, 0)
	player.global_position = at
	player.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	await _frames(2)


func _clear_side(id: String, at: Vector3, distance: float) -> Vector3:
	# A direction to stand in that keeps Nina out of door triggers (Rex wanders right past Nina's House door) and
	# makes this person clearly the nearest one to talk to (Rex and Bramble often stand side by side)
	var doors := current_scene.find_children("*", "Area3D", true, false).filter(
		func(a: Node) -> bool: return a.get_script() == load("res://scripts/door.gd"))
	var others := current_scene.find_children("Talk", "Area3D", true, false).filter(
		func(t: Node) -> bool: return t.get("character_id") != id)
	for k in 24:
		var side := Vector3(1.7, 0, 0.6).normalized().rotated(Vector3.UP, k * TAU / 24.0)
		var spot := at + side * distance
		if doors.all(func(d: Node3D) -> bool: return d.global_position.distance_to(spot) > 4.5) and 				others.all(func(t: Node3D) -> bool: return t.global_position.distance_to(spot) > distance + 1.5):
			return side
	return Vector3.ZERO


func _in_town() -> void:
	# Look everyone up again, in case something reloaded the town (or a door took her inside)
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE  left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t


func _name_shown(id: String) -> bool:
	return talkers[id]._name_label.visible


func _prompt_shown(id: String) -> bool:
	return talkers[id]._prompt.visible


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


func _check_load() -> void:
	# Game (an autoload) has already loaded the save, as on a real start-up
	check(dialogue.talks.get("rex", 0) == 3 and dialogue.talks.get("dash", 0) == 1, "loaded talk counts: %s" % [dialogue.talks])
	check(dialogue.flags.has("voted_rex"), "loaded flags: %s" % [dialogue.flags.keys()])
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
