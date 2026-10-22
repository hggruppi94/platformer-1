extends SceneTree

# Checks the Scary World: the gate asks first (a clear yes or no, and the answer is kept in the save), going in,
# that nothing in there can hurt her, making friends with the centipede (and naming it), and every way home (the
# gate, the pause menu). Run it twice: the second run starts up like the real game and checks the save.
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

	# --- Yes: through the gate
	var yes := await _talk(_talker("scary_gate"), [1])
	await _wait_for_scene(SCARY)
	check(current_scene.scene_file_path == SCARY, "Yes takes her through the gate")
	check(dialogue.choice_log.size() == 2 and dialogue.choice_log[1].answer == "yes", "...and that answer's kept too")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var entrance := current_scene.find_child("Entrance", true, false) as Node3D
	check(player.global_position.distance_to(entrance.global_position) < 1.5, "she appears just inside")
	await _frames(3)
	check(messages.any(func(m: String) -> bool: return m.contains("nothing here can hurt you")), "a calm hello: nothing here can hurt her, the gate goes home")
	check(dialogue.flags.has("scary_world_visited"), "visit remembered")

	# --- Safe: no enemies, the centipede doesn't block or chase
	check(current_scene.find_children("*", "Node", true, false).filter(func(n: Node) -> bool:
		return n.is_in_group("enemies") or (n.get_script() != null and str(n.get_script().resource_path).contains("gloop"))).is_empty(),
		"no enemies in the Scary World")
	var centipede := current_scene.find_child("Centipede", true, false) as Node3D
	var solid_bits := centipede.find_children("*", "CollisionShape3D", true, false).filter(func(c: Node) -> bool: return not c.get_parent() is Area3D)
	check(solid_bits.is_empty(), "the centipede has no body to bump into")
	var c_at := centipede.global_position
	for i in 60:
		await physics_frame
	check(centipede.global_position.distance_to(c_at) < 0.01, "...and it stays curled by its log")
	var edge := current_scene.find_child("Edge", true, false)
	check(edge != null and edge.get_child_count() >= 30, "an edge all the way round, so she can't get lost")

	# --- The centipede: scary-looking, lonely, a friend
	var cent := _talker("centipede")
	var first := await _talk(cent, [1, 0])
	check(_said(first, "Nobody ever visits") and _said(first, "wanted a friend"), "the centipede was lonely all along")
	check(dialogue.flags.has("centipede_friend"), "Nina's its friend now")
	var naming := await _talk(_talker("centipede"), [0])
	check(dialogue.names.get("centipede", "") == "Wiggles" and _said(naming, "WIGGLES"), "she names it Wiggles")
	await _frames(2)
	cent = _talker("centipede")
	cent.call("_show", true)
	check(cent._name_label.text == "Wiggles", "its name over its head: \"%s\"" % cent._name_label.text)
	var again := await _talk(cent)
	check(again.size() > 0 and again[0][0] == "Wiggles", "and in the talk box: \"%s\"" % (again[0][0] if again.size() else ""))
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
	var home: Button = pause.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Go home to town")[0] if pause.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == "Go home to town") else null
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
	var back_in := await _talk(_talker("scary_gate"), [1])
	check(_said(back_in, "go back in"), "the gate asks again next time: \"Do you want to go back in?\"")
	await _wait_for_scene(SCARY)
	check(current_scene.scene_file_path == SCARY and dialogue.choice_log.size() == 3, "back in (3 answers kept)")
	var exit := current_scene.find_child("ExitToTown", true, false) as Area3D
	player = current_scene.find_child("Player", true, false) as Node3D
	player.global_position = exit.global_position
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN, "walking back through the gate goes home")

	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var d: Dictionary = data.get("dialogue", {}) if data is Dictionary else {}
	check(d.get("choices", []).size() == 3 and d.get("names", {}).get("centipede", "") == "Wiggles", "save.json keeps the answers and the name")
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	var answers: Array = dialogue.choice_log.map(func(c: Dictionary) -> String: return c.answer)
	check(answers == ["no", "yes", "yes"], "loaded: the gate answers, in order: %s" % [answers])
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
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var body := t.get_parent() as Node3D
	player.global_position = body.global_position + Vector3(1.2, 0.8, 1.2)
	player.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	said.clear()
	dialogue.talk_to(t)
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
