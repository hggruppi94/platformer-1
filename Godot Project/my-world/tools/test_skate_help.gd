extends SceneTree

# Checks the help for skating and the controls: the forgiving landings (Settings.skate_assist: Relaxed, Normal, Pro in
# scenes/player/skate.gd), the Simple layout (one trick button, grinds by themselves, Grind on the flat is a manual),
# changing controller buttons and keys (scripts/settings.gd) with prompts that follow them and whichever device is in
# use, the how-to tips (scripts/tips.gd), and Coach Rook's skate lesson (scripts/skate_lesson.gd): each step done for
# real, saved, carried on later, paying sparkles once, and Rook coaching by the Lesson Pad in town.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate_help.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.test_backup.cfg"
const PARK := "res://scenes/skate/test_park.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var lesson: Node
var tips: Node
var dialogue: Node
var p: CharacterBody3D
var s: Node
var arm: Node3D
var bails := [0]
var slips := [0]


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	lesson = root.get_node("SkateLesson")
	tips = root.get_node("Tips")
	dialogue = root.get_node("Dialogue")
	settings.use_layout("classic")
	settings.tips = true
	settings.last_device = "keyboard"
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(PARK)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	arm = p.get_node("SpringArm3D")
	s.rng.seed = 7
	s.bailed.connect(func() -> void: bails[0] += 1)
	s.slipped.connect(func() -> void: slips[0] += 1)
	await _physics(10)
	check(game.riding and s.state == s.State.ROLL, "she's rolling in the Practice Park")

	await _assists()
	await _simple()
	_controls()
	await _tips()
	await _lesson()
	await _coach()
	_end()


# -----------------------------------------------------------------------------
# Forgiving landings
# -----------------------------------------------------------------------------
func _assists() -> void:
	check(settings.skate_assist == 1 or FileAccess.file_exists(SETTINGS_BACKUP), "skating starts on Normal (or the player's own pick)")
	check(settings.ASSIST_NAMES == ["Relaxed", "Normal", "Pro"], "there are three skating assists")
	# Landing crooked: how far off straight still rides away
	for c in [[2, 0.85, true], [1, 0.85, false], [1, 1.2, true], [0, 1.2, false]]:
		settings.skate_assist = c[0]
		var bailed := await _land_off(c[1])
		check(bailed == c[2], "%s: landing %d degrees off straight is %s" % [settings.ASSIST_NAMES[c[0]],
			roundi(rad_to_deg(c[1])), "a bail" if c[2] else "fine"])
	# Landing while the board's still flipping
	var t: SkateTricks = s.tricks
	for c in [[2, 0.1, true], [1, 0.55, false], [0, 0.05, false]]:
		settings.skate_assist = c[0]
		t.lose()
		await _big_air()
		t.start_flip("")
		t.flip.time = float(t.flip.duration) * float(c[1])
		p.global_position.y = 1.15
		p.velocity = Vector3(0, -4, -3)
		bails[0] = 0
		await _until_rolling()
		await _physics(2)
		var ok: bool = bails[0] == 0 and (t.combo.size() > 0 or t.score > 0)
		check(ok != c[2], "%s: landing with the flip %d%% round is %s" % [settings.ASSIST_NAMES[c[0]], roundi(c[1] * 100),
			"a bail" if c[2] else "fine, and the flip counts"])
		await _get_up()
	# The balance needle running off the end of a rail
	settings.skate_assist = 1
	var rail := current_scene.find_child("Flat Rail", true, false).get_node("Rail") as GrindRail
	var r0: Vector3 = rail.point_at(0.0)
	_place(r0 + Vector3(0.5, 1.4, 0.0), PI / 2)
	p.velocity = Vector3(2.5, -1, 0)
	s._pop()
	s._try_grind()
	t.lose()
	t.start_live("50-50", 50, 150.0)
	bails[0] = 0
	slips[0] = 0
	for i in 600:
		await physics_frame
		if s.state != s.State.GRIND:
			break
		s._rail_offset = 2.0
		s.balance = 0.995 if i > 20 else s.balance        # tipping right over
	check(slips[0] == 1 and bails[0] == 0 and s.state == s.State.AIR, "Normal: falling off the balance slips her off the rail, no bail")
	check(t.names().begins_with("50-50"), "...and the grind still counts in the combo (%s)" % t.names())
	await _until_rolling()
	await _physics(40)
	# A manual tipping over just ends it
	_place(Vector3(-30, 0.9, 40), PI)
	p.velocity = Vector3(0, 0, -6)
	await _physics(3)
	s._start_manual(1)
	slips[0] = 0
	s.balance = 0.999
	s._balance_vel = 4.0
	await _physics(4)
	check(slips[0] == 1 and s._manual == 0 and s.state == s.State.ROLL, "Normal: a manual tipping over lands on four wheels")
	# A bail keeps some of the combo, and the special meter
	for c in [[0, 100], [1, 50], [2, 0]]:
		settings.skate_assist = c[0]
		_place(Vector3(-30, 0.9, 40), PI)
		await _physics(3)
		t.lose()
		t.score = 0
		t.add("Kickflip", 100)
		t.special = 0.5
		s.bail()
		check(t.score == c[1] and t.combo.is_empty(), "%s: a bail still pays %d of a 100 point combo" % [settings.ASSIST_NAMES[c[0]], c[1]])
		check(is_equal_approx(t.special, 0.5) == (c[0] < 2), "...and %s the special meter" % ("keeps" if c[0] < 2 else "empties"))
		var get_up: float = s._bail_timer
		await _get_up()
		check(get_up < float(s.ride.bail_time) or c[0] == 2, "...and gets her up in %.1f s" % get_up)
	settings.skate_assist = 1


func _land_off(off: float) -> bool:
	# Flying north (yaw PI) and turned off straight by this much; true if she bails
	_place(Vector3(-30, 3.0, 30), PI)
	p.velocity = Vector3(0, 2, -7)
	s._pop()
	s._yaw = PI - off
	bails[0] = 0
	await _physics(80)
	var bailed: bool = bails[0] > 0
	await _get_up()
	return bailed


# -----------------------------------------------------------------------------
# The Simple layout
# -----------------------------------------------------------------------------
func _simple() -> void:
	settings.use_layout("simple")
	check(settings.control_style == "simple", "the Simple layout can be picked")
	var t: SkateTricks = s.tricks
	t.lose()
	await _big_air()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	await _physics(2)
	check(t.flipping() and t.flip.name == "Kickflip", "Simple: a tap of the trick button flips")
	await _until_rolling()
	await _physics(40)
	t.lose()
	await _big_air()
	Input.action_press("skate_flip")
	await _physics(20)
	check(not t.flipping() and not t.grab.is_empty() and t.grab.name == "Indy", "Simple: holding it grabs instead")
	Input.action_release("skate_flip")
	await _physics(2)
	check(t.grab.is_empty() and t.names().contains("Indy"), "...and letting go counts the grab")
	await _until_rolling()
	await _physics(40)
	# Grinds lock on by themselves, coming down near a rail
	var rail := current_scene.find_child("Flat Rail", true, false).get_node("Rail") as GrindRail
	var r0: Vector3 = rail.point_at(0.0)
	_place(r0 + Vector3(1.0, 1.6, 0.0), PI / 2)
	p.velocity = Vector3(6, -1, 0)
	s._pop()
	s._air_time = 0.3
	for i in 20:
		await physics_frame
		if s.state == s.State.GRIND:
			break
	check(s.state == s.State.GRIND, "Simple: coming down over a rail grinds by itself, no button")
	s._leave_rail(Vector3.ZERO)
	s.state = s.State.AIR
	await _until_rolling()
	await _physics(30)
	# Grind on the flat is a manual
	_place(Vector3(-30, 0.9, 40), PI)
	p.velocity = Vector3(0, 0, -6)
	await _physics(3)
	Input.action_press("skate_grind")
	await _physics(2)
	Input.action_release("skate_grind")
	check(s._manual == 1 and t.live.get("name", "") == "Manual", "Simple: Grind on the flat starts a manual")
	s._end_manual()
	await _physics(30)
	# The special with the one button
	t.lose()
	t.special = 1.0
	await _big_air()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	check(t.flipping() and t.flip.get("special", false), "Simple: with a full meter the trick button does the special")
	await _until_rolling()
	await _physics(40)
	settings.use_layout("classic")


# -----------------------------------------------------------------------------
# Changing the controls
# -----------------------------------------------------------------------------
func _controls() -> void:
	settings.use_layout("classic")
	check(_pad_buttons("jump") == [JOY_BUTTON_A] and _pad_buttons("dash").has(JOY_BUTTON_RIGHT_SHOULDER),
		"the Classic layout: A jumps, X or RB rolls")
	var clash: String = settings.rebind_pad("jump", JOY_BUTTON_B)
	check(_pad_buttons("jump") == [JOY_BUTTON_B], "a controller button can be changed (Jump on B)")
	check(clash != "" and _pad_buttons("interact") == [JOY_BUTTON_A] and _pad_buttons("skate_grab") == [JOY_BUTTON_A],
		"...and the actions that had B move to A")
	check(settings.rebind_pad("skate_grind", JOY_BUTTON_Y) == "" and _pad_buttons("toggle_skateboard") == [JOY_BUTTON_Y],
		"...but the skateboard and Grind can share Y, as they always have")
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	check(int(cf.get_value("pad", "jump", -1)) == JOY_BUTTON_B, "controller buttons are saved in the settings")
	settings.rebind("skate_flip", KEY_U)
	settings.last_device = "keyboard"
	check(settings.prompt("skate_flip") == "U" and settings.prompt("jump") == "Space", "keyboard prompts show the keys, changed ones too")
	check(settings.fill("{moves} to move") == "WASD to move", "...and the move keys")
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_X
	e.pressed = true
	settings._input(e)
	check(settings.last_device == "pad", "pressing a controller button switches the prompts to the controller")
	check(settings.prompt("jump") == "B" and settings.prompt("move_left") == "Left stick left", "...which show its buttons, changed ones too")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_W
	k.pressed = true
	settings._input(k)
	check(settings.last_device == "keyboard", "...and a key switches them back")
	settings.use_layout("classic")
	check(_pad_buttons("jump") == [JOY_BUTTON_A] and settings.prompt("skate_flip") == "J", "picking a layout puts the buttons and keys back")


func _pad_buttons(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			out.append(ev.button_index)
	return out


# -----------------------------------------------------------------------------
# How-to tips
# -----------------------------------------------------------------------------
func _tips() -> void:
	tips.replay()
	tips.clear()
	for f in dialogue.flags.keys():
		if String(f).begins_with("tip_"):
			dialogue.flags.erase(f)
	tips.show_tip("move")
	await _frames(3)
	var panel := tips.get_node("Tip") as PanelContainer
	var text := (panel.find_children("*", "Label", true, false)[1] as Label).text
	check(tips.current() == "move" and panel.visible and dialogue.flags.has("tip_move"), "a tip shows, and is remembered")
	check(text.contains("WASD"), "...saying the player's own keys (%s)" % text)
	settings.last_device = "pad"
	await _frames(2)
	text = (panel.find_children("*", "Label", true, false)[1] as Label).text
	check(text.contains("left stick"), "...or the controller, when that's what they're using")
	settings.last_device = "keyboard"
	Input.action_press("move_forward")
	await _seconds(2.0)
	Input.action_release("move_forward")
	check(tips.current() != "move", "doing what it says puts it away")
	tips.clear()
	tips.show_tip("move")
	await _frames(3)
	check(tips.current() == "", "a tip that's been seen doesn't show again")
	settings.tips = false
	tips.show_tip("jump")
	await _frames(3)
	check(tips.current() == "", "with tips turned off, none show")
	tips.replay()
	await _seconds(0.8)
	check(settings.tips and tips.current() == "move", "How-to tips again turns them on and starts with the basics")
	tips.clear()


# -----------------------------------------------------------------------------
# The skate lesson
# -----------------------------------------------------------------------------
func _lesson() -> void:
	for st in lesson.STEPS:
		dialogue.flags.erase("skate_lesson_" + st.id)
	dialogue.flags.erase("skate_lesson_done")
	dialogue.flags.erase("skate_lesson_offered")
	_place(Vector3(-30, 0.9, 38), PI)
	await _physics(5)
	# The offer, the first time on a ride
	lesson.offer(true)
	check(lesson.is_offering() and p.input_locked, "Rook offers a skate lesson (and the hero waits for the answer)")
	lesson.answer(true)
	check(lesson.active and not lesson.is_offering() and not p.input_locked and lesson.step_id() == "push",
		"saying yes starts it, at the first step")
	lesson.offer()
	check(not lesson.is_offering(), "...and it's only offered once")
	# Push
	Input.action_press("move_forward")
	await _physics(120)
	Input.action_release("move_forward")
	check(dialogue.flags.has("skate_lesson_push"), "pushing along to speed does the first step")
	await _seconds(1.8)
	check(lesson.step_id() == "ollie", "...and the next one is the ollie")
	_place(Vector3(-30, 0.9, 38), 0.0)
	await _physics(5)
	Input.action_press("jump")
	await _physics(10)
	Input.action_release("jump")
	await _physics(3)
	check(dialogue.flags.has("skate_lesson_ollie"), "an ollie does the ollie step")
	await _until_rolling()
	await _seconds(1.8)
	# The lesson's words follow the controls
	settings.rebind("skate_flip", KEY_U)
	await _frames(2)
	var words := (lesson.get_node("Lesson").find_children("*", "Label", true, false)[2] as Label).text
	check(lesson.step_id() == "spin" and words.contains("hold A or D"), "the spin step says the move keys (%s)" % words)
	# Stopping halfway keeps what's done
	lesson.stop()
	check(not lesson.active, "the lesson can be stopped")
	lesson.start()
	check(lesson.active and lesson.step_id() == "spin", "...and starting again carries on from the spin")
	var t: SkateTricks = s.tricks
	t.add("180", 100)
	await _seconds(1.8)
	words = (lesson.get_node("Lesson").find_children("*", "Label", true, false)[2] as Label).text
	check(lesson.step_id() == "flip" and words.contains("press U"), "a 180 does the spin step; the flip step says the changed key (%s)" % words)
	settings.control_style = "simple"
	await _frames(2)
	words = (lesson.get_node("Lesson").find_children("*", "Label", true, false)[2] as Label).text
	check(words.contains("tap U"), "...and the Simple layout's own words (%s)" % words)
	settings.use_layout("classic")
	t.add("Grab-o", 100)
	await _frames(2)
	check(lesson.step_id() == "flip", "a trick that isn't the one being taught doesn't count")
	for c in [["Heelflip", "grab"], ["Melon", "grind"], ["Boardslide", "manual"], ["Nose Manual", "combo"]]:
		t.add(c[0], 100)
		await _seconds(1.8)
		check(lesson.step_id() == c[1], "%s does that step; next is %s" % [c[0], c[1]])
	var before: int = game.sparkles
	t.banked.emit(900, "Kickflip + Indy")
	await _frames(2)
	check(lesson.step_id() == "combo", "a combo of two isn't enough")
	t.banked.emit(1500, "Kickflip + Indy + 180")
	await _seconds(1.8)
	check(not lesson.active and lesson.is_done() and game.sparkles == before + lesson.REWARD,
		"a three-trick combo finishes the lesson, and pays %d sparkles" % lesson.REWARD)
	# Again, from the top, without paying twice
	lesson.start()
	check(lesson.active and lesson.step_id() == "push", "the lesson can be done again, from the start")
	for st in lesson.STEPS:
		lesson.complete(st.id)
		await _seconds(1.7)
	check(not lesson.active and game.sparkles == before + lesson.REWARD, "...without paying again")


func _coach() -> void:
	# In town, Rook coaches by the Lesson Pad at the Skate Park
	game.next_spawn = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	change_scene_to_file(TOWN)
	await _frames(8)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var pad := current_scene.find_child("Lesson Pad", true, false) as Node3D
	check(pad != null and pad.find_child("Lesson", true, false).get_script() != null, "the Skate Park has a Lesson Pad")
	var town_rook: Node3D = null
	for r in current_scene.find_children("Routine", "", true, false):
		if r.get("character_id") == "rook":
			town_rook = r.get_parent()
	lesson.start()
	await _frames(3)
	var coach := current_scene.find_child("Coach Rook", true, false) as Node3D
	check(lesson.active and game.riding and coach != null, "starting the lesson in town puts the hero on their ride, with Rook coaching")
	check(p.global_position.distance_to(pad.global_position) < 5.0, "...over at the Lesson Pad")
	check(coach != null and coach.global_position.distance_to(pad.global_position) < 4.0, "...where Rook stands")
	check(town_rook == null or not town_rook.visible, "...and there's only one Rook in town")
	lesson.stop()
	await _frames(2)
	check(not is_instance_valid(coach) and (town_rook == null or town_rook.visible), "stopping it sends Rook back to his day")
	lesson.start()
	game.go(PARK, "")
	await _frames(8)
	check(not lesson.active, "going somewhere else ends the lesson")


# -----------------------------------------------------------------------------
func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s._yaw = yaw
	if s.state == s.State.BAIL:
		s._end_bail()
	s.state = s.State.ROLL
	arm.rotation.y = yaw + PI


func _big_air() -> void:
	_place(Vector3(-30, 6.0, 38), PI)
	p.velocity = Vector3(0, 8, -6)
	s._pop()
	await _physics(2)


func _get_up() -> void:
	for i in 200:
		if s.state == s.State.ROLL:
			break
		await physics_frame
	await _physics(5)


func _until_rolling() -> void:
	for i in 300:
		if s.state == s.State.ROLL:
			return
		await physics_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout


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
	tips.clear()
	if lesson.active:
		lesson.stop()
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
