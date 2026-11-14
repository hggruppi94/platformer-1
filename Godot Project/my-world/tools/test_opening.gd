extends SceneTree

# The opening of a new game (scripts/opening.gd, scripts/move_tutorial.gd; Hayden's 12 Nov 2026 playtest: "There need
# to be more cutscenes in the beginning to guide the player, and way less popups. maybe a movement tutorial", and the
# blaster line on Shoot was a spoiler):
#   - making the hero plays the morning cutscene (forced here: headless runs skip cutscenes) and holds the controls
#     while it's on; skipping it hands them back; no "Welcome" or "Knock knock" pop-ups, no how-to tips
#   - the movement tutorial goes look, walk, jump, double jump, roll, sprint, door, ticked off by really doing each
#   - out of the door, Nina's cutscene; after her talk, Mr. Palmer and the green; every First Night step with a guide
#     has shots that end on the ground, and those steps don't put up a "Quest updated" banner
#   - Shoot with no gadget says nothing; a second tremor says nothing
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_opening.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.opening_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const Q := "first_night"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var fn: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fn = root.get_node("FirstNight")
	_run.call_deferred()


func _step() -> String:
	return str(quests.current_step(Q).get("id", ""))


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	var creator := root.get_node("Creator")
	var tips := root.get_node("Tips")
	var op: Node = fn.opening
	var tut: CanvasLayer = op.tutorial

	# --- A new game: the morning cutscene ---
	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	game.hero["name"] = "Sunny"
	op.force = true                                   # (play the cutscenes, headless as it is)
	creator.close()
	await _frames(4)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	check(quests.is_started(Q) and _step() == "morning", "making the hero starts The First Night")
	check(op.cut.playing() and dialogue.flags.has("opening_wake"), "...and the morning cutscene plays")
	check(op.cut.shots.size() == 4 and str(op.cut.shots[0].title) == "Stars Hollow", "...four shots, starting with Stars Hollow")
	check(str(op.cut.shots[3].get("sound", "")) == "door" and str(op.cut.shots[3].caption).contains("Knock knock"),
		"...ending inside, with a knock at the door")
	var all_words := " ".join(op.cut.shots.map(func(s: Dictionary) -> String: return str(s.title) + " " + str(s.caption)))
	check(not (all_words.to_lower().contains("portal") or all_words.contains("Void") or all_words.contains("midnight")),
		"...and gives nothing away (%s)" % all_words)
	check(player.input_locked, "the controls are held while it plays")
	check(not tut.running(), "the tutorial waits for the cutscene")
	await _press("jump")
	await _frames(4)
	check(op.cut.playing(), "a press straight away doesn't skip it (a jump out of the door)")
	await create_timer(1.4).timeout
	await _press("jump")
	await _frames(4)
	check(not op.cut.playing() and not player.input_locked, "Jump skips it, and the controls come back")
	check(tut.running() and tut.step_id() == "look", "the movement tutorial starts: look around")
	check(not messages.any(func(m: String) -> bool: return m.contains("Welcome") or m.contains("Knock") or m.contains("New jobs")),
		"no pop-up messages at the start (%s)" % str(messages))
	await _frames(5)
	check(tips.current() == "", "no how-to tip pops up (%s)" % tips.current())
	var panel := tut.get_node("Tutorial") as Control
	check(panel.visible and tut.get("_text").text.contains("mouse"), "a calm card says what to do (%s)" % tut.get("_text").text)

	# --- Doing each thing ---
	var arm := player.get("spring_arm") as Node3D
	for i in 30:
		arm.rotation.y += 0.06
		await physics_frame
	await _until(func() -> bool: return tut.step_id() == "walk", 120)
	check(tut.step_id() == "walk" and dialogue.flags.has("tut_look"), "turning the camera ticks off looking round")
	var home: Node3D = tut.home
	var mid := home.global_position + Vector3.UP * 0.6
	player.global_position = mid
	await _physics(4)
	var dir := home.global_basis.x.normalized()
	for i in 60:
		player.global_position = mid + dir * (sin(i * 0.15) * 3.0)
		await physics_frame
	await _until(func() -> bool: return tut.step_id() == "jump", 120)
	check(tut.step_id() == "jump", "walking a few metres ticks off walking (%s)" % tut.step_id())
	player.global_position = mid
	await _physics(10)
	await _press("jump")
	await _until(func() -> bool: return tut.step_id() == "double", 120)
	check(tut.step_id() == "double", "a jump ticks off jumping")
	await _physics(20)
	await _press("jump")
	await _physics(8)
	await _press("jump")
	await _until(func() -> bool: return tut.step_id() == "roll", 120)
	check(tut.step_id() == "roll", "a double jump in the air ticks it off (%s)" % tut.step_id())
	await _physics(60)
	await _press("dash")
	await _until(func() -> bool: return tut.step_id() == "sprint", 120)
	check(tut.step_id() == "sprint", "a roll ticks off rolling (%s)" % tut.step_id())
	await _physics(40)
	player.global_position = mid - home.global_basis.z * 2.5
	await _physics(4)
	Input.action_press("move_forward")
	Input.action_press("dash")
	var sprinted := false
	for i in 120:
		await physics_frame
		if tut.step_id() == "door":
			sprinted = true
			break
	Input.action_release("dash")
	Input.action_release("move_forward")
	check(sprinted, "holding the roll button on the move ticks off sprinting")
	check(tut.get("_text").text.contains("door"), "last: out of the front door")
	check(fn.opening.due().is_empty(), "Nina's cutscene waits till they're out")

	# --- Out of the door: Nina ---
	player.global_position = home.global_position + home.global_basis.z * 7.0 + Vector3.UP * 0.8
	await _until(func() -> bool: return not tut.running(), 60)
	check(not tut.running() and dialogue.flags.has("tut_done"), "out of the door, the tutorial's done")
	await _until(func() -> bool: return op.cut.playing(), 60)
	check(op.cut.playing() and dialogue.flags.has("guide_nina"), "Nina's cutscene plays")
	check(str(op.cut.shots[0].caption).contains("Nina") and str(op.cut.shots[0].caption).contains("say hi"),
		"...it says who she is and how to say hi")
	var nina := _talker("nina_earth")
	if nina:
		var look: Vector3 = op.cut.shots[0].look
		check(_flat(look - (nina.get_parent() as Node3D).global_position) < 1.0, "...looking at her")
	op.cut.stop()
	await _frames(2)

	# --- After Nina: the green ---
	await _talk("nina_earth")
	await _until(func() -> bool: return op.cut.playing(), 60)
	check(op.cut.playing() and dialogue.flags.has("guide_green"), "after Nina, a look at Mr. Palmer and the green")
	op.cut.stop()
	await _frames(2)

	# --- Every guide has shots, ending above the ground ---
	for id in op.GUIDES:
		var shots: Array = op.guide_shots(id)
		var ok := not shots.is_empty()
		for s in shots:
			ok = ok and (s.from as Vector3).y > (s.look as Vector3).y - 0.5 and (s.from as Vector3).distance_to(s.look) > 2.0
		check(ok, "the %s guide has its shots (%d)" % [id, shots.size()])

	# --- The board step: a quiet change, then its cutscene ---
	await _talk("palmer_earth")
	await _talk("theo")
	await _talk("lionel")
	await _frames(6)
	check(_step() == "board", "two hellos: on to the notice board")
	check(not quests.note_text().contains("Quest updated"), "no \"Quest updated\" banner for it (%s)" % quests.note_text())
	await _until(func() -> bool: return op.cut.playing(), 60)
	check(op.cut.playing() and str(op.cut.shots[0].title) == "The Notice Board", "a cutscene shows the notice board")
	var banner_hidden: bool = not (quests.get("_note") as Control).visible
	check(banner_hidden, "quest banners keep out of the way of a cutscene")
	op.cut.stop()

	# --- Fewer pop-ups ---
	messages.clear()
	var town := root.get_node("EarthTown")
	town.tremor()
	town.tremor()
	await _frames(2)
	check(messages.filter(func(m: String) -> bool: return m.contains("tremor")).size() <= 1, "a second tremor doesn't say so again")
	messages.clear()
	check(not root.get_node("Arsenal").armed(), "no gadget yet")
	await _press("shoot")
	await _frames(4)
	check(messages.is_empty(), "Shoot with no gadget says nothing about a blaster (%s)" % str(messages))

	op.force = false
	_put_save_back()
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(0 if failures == 0 else 1)


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


# -----------------------------------------------------------------------------
func _press(action: String) -> void:
	# As a real press (an event), so "just pressed" is seen by everything that frame
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await physics_frame
	await process_frame
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame


func _until(ok: Callable, frames: int) -> void:
	for i in frames:
		if ok.call():
			return
		await physics_frame


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _talk(id: String, picks: Array = []) -> void:
	var t := _talker(id)
	if t == null:
		print("      (no %s here)" % id)
		return
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
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
			buttons[pick if pick >= 0 else buttons.size() - 1].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
