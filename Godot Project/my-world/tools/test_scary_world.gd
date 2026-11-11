extends SceneTree

# Checks the Scary World and the centipede's story in order (Hayden, 11 Nov 2026): the gate asks first (a clear yes or
# no, kept in the save), but a yes doesn't open it, only a whisper towards the school; once Dark Hollow is mended it
# opens. Inside: nothing can hurt more than a bump; the centipede asks to play her scary game (yes or no, kept), her
# boss game, and after it she's your friend for keeps (her gifts, then naming her); and every way home (the gate, the
# pause menu). Run it twice: the second run starts up like the real game and checks the save.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_scary_world.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_scary_world.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"

var failures := 0
var game: Node
var dialogue: Node
var quests: Node
var said: Array = []
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(220.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	dialogue.reset()
	quests.reset()
	var portals := root.get_node("Portals")
	portals.cleared_worlds.erase("dark_hollow")
	root.get_node("Clock").set_time(1, 15 * 60.0, true)
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	change_scene_to_file(TOWN)
	await _frames(6)

	# --- The gate asks; "No" (the first, highlighted answer) keeps her in town
	var gate := _talker("scary_gate")
	check(gate != null, "the Scary World gate has a question")
	var no := await _talk(gate, [0])
	check(_said(no, "Do you want to go in?"), "it asks: \"Do you want to go in?\"")
	check(_said(no, "Saying no is brave too"), "No: \"Saying no is brave too.\"")
	await _frames(6)
	check(current_scene.scene_file_path == TOWN, "...and she stays in town")
	check(dialogue.choice_log.size() == 1 and dialogue.choice_log[0].what == "scary_world_gate" and dialogue.choice_log[0].answer == "no"
		and int(dialogue.choice_log[0].day) == 1, "the answer is kept, with the day and time: %s" % [dialogue.choice_log])

	# --- Yes: kept, but the gate won't open yet; a whisper sends her to the school
	var yes := await _talk(_talker("scary_gate"), [1])
	await _frames(20)
	check(current_scene.scene_file_path == TOWN, "Yes doesn't open the gate yet (the story goes in order)")
	check(_said(yes, "won't open") and _said(yes, "behind the walls") and _said(yes, "school"), "...a whisper points to the school, behind the walls")
	check(dialogue.choice_log.size() == 2 and dialogue.choice_log[1].answer == "yes" and dialogue.flags.has("scary_world_said_yes"), "...and the yes is kept")
	var again := await _talk(_talker("scary_gate"))
	check(_said(again, "whisper") and not _said(again, "Do you want to go in?"), "after a yes it stays shut, with the whisper again")
	await _frames(6)
	check(current_scene.scene_file_path == TOWN, "...still in town")

	# --- Once Dark Hollow's mended (the centipede gulped her down and she mended it), the gate's open: her home
	portals.cleared_worlds.append("dark_hollow")
	var open := await _talk(_talker("scary_gate"), [1])
	check(_said(open, "Somebody lives here now"), "now the gate's open a crack: somebody lives here")
	await _wait_for_scene(SCARY)
	check(current_scene.scene_file_path == SCARY, "Yes takes her through the gate")
	check(dialogue.choice_log.size() == 3 and dialogue.choice_log[2].answer == "yes", "...and that answer's kept too")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var entrance := current_scene.find_child("Entrance", true, false) as Node3D
	check(player.global_position.distance_to(entrance.global_position) < 1.5, "she appears just inside")
	await _frames(3)
	check(messages.any(func(m: String) -> bool: return m.contains("Somebody's expecting you")), "a calm hello: somebody's expecting her")
	check(dialogue.flags.has("scary_world_visited"), "visit remembered")

	# --- Safe: no enemies, the centipede doesn't block or chase
	check(current_scene.find_children("*", "Node", true, false).filter(func(n: Node) -> bool:
		return n.is_in_group("enemies") or (n.get_script() != null and str(n.get_script().resource_path).contains("gloop"))).is_empty(),
		"no enemies in the Scary World (until her game)")
	var centipede := current_scene.find_child("Centipede", true, false) as Node3D
	check(centipede.visible, "she's home, curled round her hollow log")
	var solid_bits := centipede.find_children("*", "CollisionShape3D", true, false).filter(func(c: Node) -> bool: return not c.get_parent() is Area3D)
	check(solid_bits.is_empty(), "the centipede has no body to bump into")
	var edge := current_scene.find_child("Edge", true, false)
	check(edge != null and edge.get_child_count() >= 30, "an edge all the way round, so she can't get lost")
	check(current_scene.get_node_or_null("LogKnock") != null and current_scene.get_node("LogKnock").what() == "",
		"her log can't take you anywhere yet (not friends for keeps)")

	# --- Her scary game: she asks first. No is fine (and kept)...
	var ask := await _talk(_talker("centipede"), [1])
	check(_said(ask, "Everyone always runs away") and _said(ask, "SCARIEST") and _said(ask, "only a game"), "she asks: will you stay when she's at her scariest? (only a game)")
	check(_said(ask, "Saying no is brave too") and current_scene.get_node_or_null("Centipede Boss") == null, "No is fine: no game")
	check(dialogue.choice_log.back().what == "centipede_scary_game" and dialogue.choice_log.back().answer == "no", "...and kept")
	# ...yes starts it
	await _talk(_talker("centipede"), [0])
	await _frames(4)
	var boss := current_scene.get_node_or_null("Centipede Boss") as Node3D
	check(boss != null and not centipede.visible, "Yes: she rears up and the game's on")
	check(dialogue.choice_log.back().what == "centipede_scary_game" and dialogue.choice_log.back().answer == "yes", "...and the yes is kept")
	if boss == null:
		_finish_run()
		return
	var hp_before: int = game.hp if "hp" in game else 0
	var states := {}
	for f in 600:                                    # (up to 12 s)
		await create_timer(0.02).timeout
		states[boss.state] = true
		if states.has("dizzy"):
			break
	check(states.has("scuttle") and states.has("windup") and states.has("charge") and states.has("dizzy"),
		"she scuttles round, rears up, charges, and gets dizzy (%s)" % [states.keys()])
	boss.state = "scuttle"
	var t0: StaticBody3D = boss._targets[0]
	check(str(t0.shot(1, t0.global_position, Vector3.FORWARD)) == "bounce", "bubbles boing off her while she's zooming about")
	boss.state = "dizzy"
	check(str(t0.shot(1, t0.global_position, Vector3.FORWARD)) == "hit" and boss.hits == 1, "...but pop her when she's dizzy")
	while boss.hits < boss.HITS:
		boss.state = "dizzy"
		boss.hurt(1)
	check(boss.defeated and dialogue.flags.has("centipede_fought"), "%d bops and she flops over giggling: you stayed" % boss.HITS)
	if "hp" in game:
		check(int(game.hp) > 0, "never more than a bump (hp %d, was %d)" % [game.hp, hp_before])

	# --- Then friends for keeps: her thank-you and her gifts (straight after), then a name
	said.clear()
	await create_timer(2.4).timeout
	var gifts := await _talk(null, [0])
	check(_said(gifts, "You stayed") and _said(gifts, "climb") and _said(gifts, "knock"), "she's your friend for keeps, and shares her tricks")
	check(dialogue.flags.has("centipede_friend") and dialogue.flags.has("centipede_gifts"), "friends, and her gifts given")
	check(centipede.visible and current_scene.get_node_or_null("Centipede Boss") == null, "back curled round her log")
	check(current_scene.get_node("LogKnock").what() == "knock on the hollow log", "...and now her log can take you places")
	var naming := await _talk(_talker("centipede"), [0])
	check(dialogue.names.get("centipede", "") == "Wiggles" and _said(naming, "WIGGLES"), "she names her Wiggles")
	await _frames(2)
	var cent := _talker("centipede")
	cent.call("_show", true)
	check(cent._name_label.text == "Wiggles", "her name over her head: \"%s\"" % cent._name_label.text)
	var chat := await _talk(cent)
	check(chat.size() > 0 and chat[0][0] == "Wiggles", "and in the talk box: \"%s\"" % (chat[0][0] if chat.size() else ""))
	var bad := []
	for id in ["centipede", "scary_gate"]:
		var text := JSON.stringify(dialogue.load_character(id)).to_lower()
		for word in ["blood", "kill", "die ", "dead", "hate", "stupid", "eat you"]:
			if text.contains(word):
				bad.append("%s: %s" % [id, word])
	check(bad.is_empty(), "kid-safe words: %s" % [bad])

	# --- Ways home: the pause menu, any time
	var pause := root.get_node("PauseMenu")
	pause.open()
	await _frames(2)
	var buttons: Array = pause.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Go home to town")
	var home: Button = buttons[0] if buttons.size() > 0 else null
	check(home != null, "the pause menu has \"Go home to town\"")
	if home:
		home.pressed.emit()
	await _wait_for_scene(TOWN)
	var marker := current_scene.find_child("FromScaryWorld", true, false) as Node3D
	player = current_scene.find_child("Player", true, false) as Node3D
	check(current_scene.scene_file_path == TOWN and player.global_position.distance_to(marker.global_position) < 1.5,
		"...back in town, just outside the gate")
	check(not paused, "...and not paused")

	# ...and the gate: back in (it asks again), then out through the gate
	await _talk(_talker("scary_gate"), [1])
	await _wait_for_scene(SCARY)
	check(current_scene.scene_file_path == SCARY and dialogue.choice_log.size() == 6, "back in (6 answers kept)")
	var exit := current_scene.find_child("ExitToTown", true, false) as Area3D
	player = current_scene.find_child("Player", true, false) as Node3D
	player.global_position = exit.global_position
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN, "walking back through the gate goes home")
	_finish_run()


func _finish_run() -> void:
	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var d: Dictionary = data.get("dialogue", {}) if data is Dictionary else {}
	check(d.get("choices", []).size() == 6 and d.get("names", {}).get("centipede", "") == "Wiggles", "save.json keeps the answers and the name")
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	var answers: Array = dialogue.choice_log.map(func(c: Dictionary) -> String: return c.answer)
	check(answers == ["no", "yes", "yes", "no", "yes", "yes"], "loaded: the gate and game answers, in order: %s" % [answers])
	check(dialogue.names.get("centipede", "") == "Wiggles" and quests.display_name("centipede", "The Centipede") == "Wiggles", "loaded: Wiggles")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


# -----------------------------------------------------------------------------
func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _talk(t: Area3D, picks: Array = []) -> Array:
	# (t null: a talk that's already started, e.g. her thank-you straight after her game)
	if t:
		var player := current_scene.find_child("Player", true, false) as CharacterBody3D
		var body := t.get_parent() as Node3D
		player.global_position = body.global_position + Vector3(1.2, 0.8, 1.2)
		player.velocity = Vector3.ZERO
		for i in 6:
			await physics_frame
		said.clear()
		dialogue.talk_to(t)
	else:
		for i in 60:
			if dialogue.is_active():
				break
			await process_frame
	await _frames(2)
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


func _wait_for_scene(path: String) -> void:
	for i in 120:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


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
