extends SceneTree

# Checks the quest system (scripts/quests.gd, quest_spot.gd, res://quests/*.json) by playing Rex's whole campaign in
# town, the way a player would: talking, waiting for the next day, hanging posters, the evening rally at the
# fountain, Mr. Palmer's window and the ending. Run it twice: the first run plays it and saves, the second starts up
# like the real game and checks it all came back.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_quests.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_quests.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const Q := "rex_campaign"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var settings: Node
var player: CharacterBody3D
var talkers := {}
var spots := {}
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	settings = root.get_node("Settings")
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
	game.items.clear()
	dialogue.reset()
	quests.reset()

	# The file, the key, the empty log
	var data: Dictionary = quests.quest(Q)
	check(data.get("name", "") == "Rex for Mayor!" and data.get("steps", []).size() == 6, "rex_campaign.json reads: %s, %d steps" % [data.get("name", "?"), data.get("steps", []).size()])
	var ids := []
	for s in data.get("steps", []):
		ids.append(s.get("id", ""))
	check(ids == ["ask", "report", "posters", "rally", "palmer", "finale"], "steps in order: %s" % [ids])
	check(settings.REBINDABLE.any(func(p: Array) -> bool: return p[0] == "quest_log") and settings.key_name("quest_log") == "Q",
		"quest log key is rebindable, on %s" % settings.key_name("quest_log"))
	check(quests.log_text().contains("No quests yet"), "empty quest log says so")

	change_scene_to_file(TOWN)
	await _frames(5)
	await _in_town()
	check(talkers.has("mr_palmer") and not talkers["mr_palmer"].get("turns"), "Mr. Palmer talks from his window (a voice, no model)")
	check(spots.size() == 4, "four poster spots in town: %s" % [spots.keys()])
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))

	# --- Day 1, morning: Rex asks Nina to run his campaign (she voted for him earlier)
	clock.set_time(1, 10 * 60 + 30.0, true)
	dialogue.talks["rex"] = 2
	dialogue.flags["voted_rex"] = true
	var start := await _talk("rex", [0])
	check(_said(start, "already gave me your vote"), "Rex remembers her vote: \"%s\"" % _first(start))
	check(quests.is_started(Q) and quests.on_step(Q, "ask"), "the campaign starts on 'ask'")
	check(quests.note_text().contains("New quest: Rex for Mayor!"), "a note pops up: \"%s\"" % quests.note_text().replace("\n", " / "))

	# The quest log: opens and pauses, lists the checklist, closes with the same key and with Pause
	_press("quest_log")
	await _frames(2)
	check(quests.is_log_open() and paused, "%s opens the quest log (game paused)" % settings.key_name("quest_log"))
	check(quests._log_text.text.contains("Ask Dash") and quests._log_text.text.contains("( )"), "the log lists who to ask")
	_press("quest_log")
	await _frames(2)
	check(not quests.is_log_open() and not paused, "...and closes again")
	_press("quest_log")
	await _frames(2)
	_press("pause")
	await _frames(2)
	check(not quests.is_log_open() and not paused and not root.get_node("PauseMenu").is_open(), "Pause closes the log (not opening the menu)")

	var nag := await _talk("rex")
	check(_said(nag, "How's the asking going"), "Rex while she's still asking: \"%s\"" % _first(nag))

	# --- Asking around: Dash at his snack break, Bramble at her stall, Rook, and Pip once the lamps come on
	clock.set_time(1, 12 * 60 + 45.0, true)
	for id in ["dash", "bramble", "rook", "pip"]:
		dialogue.talks[id] = 1                           # they've met (a first meeting plays its hello first)
	for id in ["dash", "bramble", "rook"]:
		var lines := await _talk(id)
		check(dialogue.flags.has("asked_" + id) and _said(lines, "mayor"), "asked %s: \"%s\"" % [id, _last(lines)])
	check(quests.on_step(Q, "ask") and quests.log_text().contains("(done)"), "three asked, still on 'ask', ticked off in the log")
	clock.set_time(1, 19 * 60.0, true)
	var pip := await _talk("pip")
	check(dialogue.flags.has("asked_pip") and _said(pip, "LAMPS"), "asked Pip at lamp time: \"%s\"" % _last(pip))
	check(quests.on_step(Q, "report") and quests.note_text().contains("Quest updated"), "all four asked: on to 'report'")

	# --- Telling Rex (the dog gag), then a day's wait for the posters
	clock.set_time(1, 20 * 60.0, true)
	var report := await _talk("rex")
	check(_said(report, "I'm REX! He's the dog!"), "the report has \"I'm REX! He's the dog!\"")
	check(quests.on_step(Q, "posters") and quests.is_waiting(Q), "on 'posters', waiting for tomorrow")
	check(quests.log_text().contains("Come back tomorrow"), "the log says to come back tomorrow")
	game.save_game()
	var mid = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var saved_q: Dictionary = mid.get("quests", {}).get(Q, {}) if mid is Dictionary else {}
	check(int(saved_q.get("step", -1)) == 2 and int(saved_q.get("since_day", 0)) == 1, "save.json keeps the step: %s" % [saved_q])
	await _stand_at_spot(1)
	check(dialogue._nearest != spots[1] and not spots[1]._prompt.visible, "no posters to hang yet on day 1")
	var paint := await _talk("rex")
	check(_said(paint, "Painting posters"), "Rex is painting: \"%s\"" % _first(paint))

	# --- Day 2: hang the four posters
	clock.set_time(2, 9 * 60.0, true)
	await create_timer(1.3).timeout                       # the quest notices the new day on its own
	check(not quests.is_waiting(Q), "day 2: the posters are ready")
	for k in [1, 2, 3, 4]:
		await _stand_at_spot(k)
		var spot: Area3D = spots[k]
		check(dialogue._nearest == spot and spot._prompt.visible and spot._prompt.text == "Press F to hang a poster",
			"poster spot %d offers: \"%s\"" % [k, spot._prompt.text])
		check(not spot.get_node("Done").visible, "...no poster there yet")
		_press("interact")
		await _frames(3)
		check(dialogue.flags.has("poster_%d" % k) and spot.get_node("Done").visible, "...hung poster %d" % k)
		check(dialogue._nearest != spot, "...and it doesn't offer again")
	check(quests.on_step(Q, "rally"), "all posters up: on to 'rally'")

	# --- The rally: Rex goes to the fountain in the evening (not before)
	clock.set_time(2, 14 * 60.0, true)
	var early := await _talk("rex")
	check(_said(early, "this evening"), "afternoon, Rex: \"%s\"" % _first(early))
	var rex_routine := _routine("rex")
	clock.set_time(2, 18 * 60.0, true)
	for i in 5:
		await physics_frame
	var rex_body := talkers["rex"].get_parent() as Node3D
	var fountain := Vector2(-72, 42)
	var rex_xz := Vector2(rex_body.global_position.x, rex_body.global_position.z)
	check(rex_routine.activity() == "rally" and rex_xz.distance_to(fountain) < 9.0,
		"6 PM: Rex is at the fountain for his rally (%.1f m away)" % rex_xz.distance_to(fountain))
	var rally := await _talk("rex", [1])
	check(_said(rally, "MORE BRAIN BREAKS"), "Nina picks his big finish: \"More brain breaks\"")
	check(quests.on_step(Q, "palmer") and quests.is_waiting(Q), "rally done: on to 'palmer', tomorrow")
	for i in 5:
		await physics_frame
	check(rex_routine.activity() != "rally", "Rex's rally is over (%s)" % rex_routine.activity())

	# --- Mr. Palmer: closed in the evening, says no on day 3
	var closed := await _talk("mr_palmer")
	check(_said(closed, "OFFICE HOURS") and closed[0][0] == "", "evening: his window's closed (narration)")
	clock.set_time(3, 10 * 60.0, true)
	quests.check()
	var palmer := await _talk("mr_palmer")
	check(_said(palmer, "the answer is no") and _said(palmer, "patient"), "day 3: Mr. Palmer says no, and to be patient")
	check(palmer.any(func(l: Array) -> bool: return l[0] == "Mr. Palmer"), "his lines are under his name")
	check(quests.on_step(Q, "finale"), "on to 'finale'")

	# --- The ending: listening, the sash, Future Mayor Rex
	var sash := player.find_child("Sash", true, false) as Node3D
	check(sash != null and not sash.visible, "no sash before the end")
	var finale := await _talk("rex")
	check(_said(finale, "about listening"), "Rex learns being mayor is about listening")
	check(quests.is_done(Q) and clock.day <= 3, "the campaign is done, on day %d" % clock.day)
	check(game.has_item("campaign_sash") and sash.visible, "Nina gets (and wears) the campaign sash")
	check(quests.note_text().contains("Quest complete"), "the note: \"%s\"" % quests.note_text().replace("\n", " / "))
	await _stand_by("rex", 1.5)
	check(talkers["rex"]._name_label.text == "Future Mayor Rex", "over his head: \"%s\"" % talkers["rex"]._name_label.text)
	var after := await _talk("rex")
	check(after.size() > 0 and after[0][0] == "Future Mayor Rex", "in the talk box too: \"%s\"" % (after[0][0] if after.size() else ""))
	check(quests.log_text().contains("done!"), "the log shows it done")
	check(quests.override_for("rex").is_empty(), "no more overrides once it's done")

	# Nothing in the quest is scary: every line of every quest conversation is checked for words that don't belong
	var bad := []
	for id in ["rex", "mr_palmer", "dash", "bramble", "pip", "rook"]:
		var text := JSON.stringify(dialogue.load_character(id)).to_lower()
		for word in ["blood", "kill", "die ", "dead", "hate", "stupid"]:
			if text.contains(word):
				bad.append("%s: %s" % [id, word])
	check(bad.is_empty(), "kid-safe words: %s" % [bad])

	game.save_game()
	var data2 = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var saved: Dictionary = data2.get("quests", {}) if data2 is Dictionary else {}
	check(saved.get(Q, {}).get("done", false) and "campaign_sash" in data2.get("items", []), "save.json has the finished quest and the sash")
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	# Game (an autoload) has already loaded the save, as on a real start-up
	check(quests.is_done(Q), "loaded: the campaign is done (%s)" % [quests.state])
	check(game.has_item("campaign_sash"), "loaded: Nina still has the sash")
	check(quests.display_name("rex", "Rex") == "Future Mayor Rex", "loaded: Rex is still Future Mayor Rex")
	check(dialogue.flags.has("poster_4") and dialogue.flags.has("campaign_done"), "loaded: the flags")
	quests.load_data({Q: {"step": 3, "since_day": 2}})
	check(quests.on_step(Q, "rally") and not quests.is_done(Q), "a save made mid-quest loads onto its step")
	quests.reset()
	check(not quests.is_started(Q), "a new game starts the quest over")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _first(lines: Array) -> String:
	return lines[0][1] if lines.size() else ""


func _last(lines: Array) -> String:
	return lines[-1][1] if lines.size() else ""


func _routine(id: String) -> Node:
	for r in get_nodes_in_group("routines"):
		if r.get("character_id") == id:
			return r
	return null


func _talk(id: String, picks: Array = []) -> Array:
	await _stand_by(id, 1.5)
	said.clear()
	await _frames(1)
	if dialogue._nearest == talkers[id]:
		_press("interact")
	else:
		dialogue.talk_to(talkers[id])
	await _frames(2)
	if not dialogue.is_active():
		check(false, "couldn't start talking to " + id)
		return []
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick].grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")
			await _frames(1)
			_press("interact")
		await _frames(2)
	await create_timer(0.25).timeout
	return said.duplicate()


func _stand_by(id: String, distance: float) -> void:
	for i in 3:
		await physics_frame
	await _in_town()
	var who := talkers[id].get_parent() as Node3D
	var side := _clear_side(id, who.global_position, distance)
	if side == Vector3.ZERO and who is CharacterBody3D:
		for k in 8:
			who.global_position += Vector3(3, 0.5, 0).rotated(Vector3.UP, k * TAU / 8.0)
			for i in 4:
				await physics_frame
			side = _clear_side(id, who.global_position, distance)
			if side != Vector3.ZERO:
				break
	if side == Vector3.ZERO:
		side = Vector3(1.7, 0, 0.6).normalized()
	player.global_position = who.global_position + side * distance + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	await _frames(2)


func _stand_at_spot(k: int) -> void:
	# Next to a poster spot, on a side clear of the signpost's boards
	await _in_town()
	var spot: Area3D = spots[k]
	var best := Vector3(1.4, 0, 0)
	for a in 12:
		var side := Vector3(1.4, 0, 0).rotated(Vector3.UP, a * TAU / 12.0)
		var p := spot.global_position + side
		var others := talkers.values().filter(func(t: Node3D) -> bool: return t.global_position.distance_to(p) < 4.0)
		if others.is_empty():
			best = side
			break
	player.global_position = spot.global_position + best + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 8:
		await physics_frame
	await _frames(2)


func _clear_side(id: String, at: Vector3, distance: float) -> Vector3:
	var doors := current_scene.find_children("*", "Area3D", true, false).filter(
		func(a: Node) -> bool: return a.get_script() == load("res://scripts/door.gd"))
	var others := current_scene.find_children("Talk", "Area3D", true, false).filter(
		func(t: Node) -> bool: return t.get("character_id") != id)
	for k in 24:
		var side := Vector3(1.7, 0, 0.6).normalized().rotated(Vector3.UP, k * TAU / 24.0)
		var spot := at + side * distance
		if doors.all(func(d: Node3D) -> bool: return d.global_position.distance_to(spot) > 4.5) and \
				others.all(func(t: Node3D) -> bool: return t.global_position.distance_to(spot) > distance + 1.5):
			return side
	return Vector3.ZERO


func _in_town() -> void:
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE  left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t
	for s in current_scene.find_children("Poster Spot *", "Area3D", true, false):
		spots[int(str(s.name).get_slice(" ", 2))] = s


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
