extends SceneTree

# Checks the story's ending (scripts/far_future.gd slice three, scripts/dash_goodbye.gd, scripts/after_the_ending.gd,
# quests/loose_ends.json): nothing about it before the Agent of Chaos is beaten; then the quest Loose Ends starts and
# sends you to Dash's lab; the Swap-o-Tron's lever swaps Rex and Rook back for good (no snapping back this time), Rex
# says sorry to Rook, and Dash tells everyone the Shift will send them all home; all three go to the Tomorrow Clock;
# walking up to Dash plays the homecoming (controls held, its own camera, every beat in order, the cap given, the
# friends sent home, Dash, Rex and Rook still there, everything given back); his letter waits on his workbench and
# reading it finishes the quest; Rex's banner is up and the Old Oak hums; Dash takes the lost watches in Lumen City;
# back in the Void, Dash, Rex, Rook and Dash's bike are gone, and they're out of the Void's races and requests (but not
# the Skyway Run); skipping the homecoming gets to the same end; and it all saves and loads (rewritten Nov 12, 2026,
# when Hayden's lore changed: no sacrifice, everyone goes home).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_dash_goodbye.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.dash_goodbye_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dash_goodbye_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/far_future.tscn"
const ID := "far_future"
var AFTER: GDScript

var failures := 0
var game: Node
var portals: Node
var quests: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(500.0, true, false, true).timeout.connect(func() -> void:
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
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	AFTER = load("res://scripts/after_the_ending.gd")
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	_fresh()
	await _check_before()
	await _check_lab()
	await _check_goodbye(false)
	await _check_letter()
	await _check_hand_ins()
	await _check_void()
	_check_saving()
	# Again from the start of the goodbye, skipping it this time
	_fresh()
	for f in ["beat_agent_of_chaos", AFTER.START_FLAG, AFTER.REX_HOME, AFTER.TWIST_FLAG]:
		dialogue.flags[f] = true
	await _enter()
	await _check_goodbye(true)
	_finish()


func _fresh() -> void:
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor", ID]:
		portals.quakes.append(w)
		portals.cleared_worlds.append(w)
	for f in ["swap_try_start", "swap_tried", "popped_gloop_king", "popped_grandfather_tock", "popped_boulderdillo"]:
		dialogue.flags[f] = true
	for i in 3:
		portals.note_found(ID, "core_%d" % (i + 1))
	portals.note_found(ID, "thanked")


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _enter() -> void:
	if current_scene == null or current_scene.scene_file_path != TOWN:
		change_scene_to_file(TOWN)
		await _frames(10)
		await _physics(4)
	portals.enter(ID)
	await _frames(14)
	await _physics(4)


func _check_before() -> void:
	# Nothing about the ending until the Agent of Chaos is beaten
	await _enter()
	var s := current_scene
	check(s.scene_file_path == WORLD, "into the Far Future")
	check(not dialogue.flags.has(AFTER.START_FLAG) and not quests.state.has("loose_ends"), "no Loose Ends before he's beaten")
	check(not s.can_swap_for_good(), "...and the lever can't swap them for good yet")
	var said := " ".join(s.rex_lines() + s.dash_lines() + s.rook_lines()).to_lower()
	check(not "tomorrow clock" in said and not "goodbye" in said and not "stitch" in said, "nobody hints at Dash going")
	check(s.get_node_or_null("Letter") == null, "no letter on his bench")
	check(s.get_node_or_null("Mayor Banner") == null, "no banner for Rex")
	var oak := s.get_node_or_null("Old Oak") as Node3D
	check(oak != null and oak.global_position.distance_to(Vector3(s.OAK_AT.x, oak.global_position.y, s.OAK_AT.z)) < 0.1,
		"the Old Oak stands in Lumen City (Stars Hollow's oak, a long time later)")
	var oak_said := " ".join(s.oak_lines())
	check("Stars Hollow" in oak_said and not "same tree" in oak_said, "...touching it hums like the oak back home (a hint, not the answer)")
	check(absf(oak.global_position.y - s.ground_below(oak.global_position + Vector3(0, 1, 0)).y) < 0.3, "...on the city floor")
	dialogue.set_flag("beat_agent_of_chaos")
	AFTER.start_if_due()
	await _frames(3)
	check(quests.state.has("loose_ends") and quests.state["loose_ends"].step == 0, "beating him starts Loose Ends: to Dash's lab")
	var step: String = quests.current_step("loose_ends").get("text", "")
	check("lab" in step and not "tomorrow clock" in step.to_lower() and not "goodbye" in step.to_lower(), "...and the step only says where to go (%s)" % step)


func _check_lab() -> void:
	var s := current_scene
	var rex := s.get_node("Rex") as Node3D
	var rook := s.get_node("Rook") as Node3D
	var husky := rex.get_node("Model")
	var boy := rook.get_node("Model")
	check(s.can_swap_for_good() and not s.can_try_swap(), "the lever's ready to swap them for good")
	check("lever" in " ".join(s.rex_lines()).to_lower() and "lever" in " ".join(s.dash_lines()).to_lower(), "Rex and Dash say to pull the lever")
	var player := _player()
	player.global_position = (s.get_node("SwapOTron") as Node3D).global_position + Vector3(0, 1.0, 3.5)
	await _physics(4)
	s.get_node("SwapOTron/Spot").use()
	check(s.swapping and s.for_good and player.input_locks().has(&"swap_try"), "pulling it starts the swap (and holds your controls)")
	await create_timer(s.FOR_GOOD_HOLD + 0.3).timeout
	check(rex.get_node("Model") == boy and rook.get_node("Model") == husky, "ZAP: each in their own body, and it HOLDS")
	check(s.get_node_or_null("Knot Clock") == null, "...no cracked clock pulling them back")
	await create_timer(s.SWAP_DONE - s.FOR_GOOD_HOLD + 0.3).timeout
	check(dialogue.flags.has(AFTER.REX_HOME) and not s.swapping and not player.input_locks().has(&"swap_try"), "it's done, for good")
	check(rex.get_node("Model") == boy, "...and Rex is still the boy")
	check(dialogue.is_active(), "Dash tells everyone what happens next")
	var home := " ".join(s.home_lines())
	check("on purpose" in home and "sorry" in home.to_lower(), "...Rex says sorry to Rook: he swapped them on purpose")
	check("home" in home and "Tomorrow Clock" in home and "Stars Hollow" in home and not "stays in" in home,
		"...when the clock strikes, the Shift sends everyone home (and nobody stays behind)")
	check(quests.state["loose_ends"].step == 1, "the quest moves on: to the Tomorrow Clock")
	dialogue.end()
	await _frames(3)
	check(dialogue.flags.has(AFTER.TWIST_FLAG), "the twist's been told")
	check(s.dash_at_clock(), "Dash goes to the Tomorrow Clock")
	var c: Vector3 = s.CLOCK_AT
	check(rex.global_position.distance_to(c) < 12.0 and rook.global_position.distance_to(c) < 12.0, "...and Rex and Rook go with him")
	check(not s.can_swap_for_good() and not s.can_try_swap(), "the lever's done")


func _check_goodbye(skipping: bool) -> void:
	var s := current_scene
	var g := s.get("goodbye") as Node
	check(g != null and not g.playing(), "the goodbye waits")
	check(s.dash_at_clock(), "Dash waits on the clock's dais")
	var player := _player()
	var old_cam := root.get_viewport().get_camera_3d()
	var dash := s.get_node("Dash") as Node3D
	player.global_position = dash.global_position + Vector3(0, 1.0, s.GOODBYE_NEAR + 6.0)
	await _physics(6)
	check(not g.playing(), "...not till you walk up to him")
	player.global_position = dash.global_position + Vector3(0, 1.0, 5.0)
	await _frames(4)
	check(g.playing() and g.played, "walking up to him plays the goodbye")
	check(player.input_locks().has(&"dash_goodbye"), "...the controls are held")
	check(root.get_viewport().get_camera_3d() == g.cam, "...it has its own camera")
	check(not player.get_node("HUD").visible, "...and the HUD steps away")
	check(root.get_node("Soundscape").pick_track() == "chaos_ending", "...the gentle music plays")
	var left: float = portals.time_left
	await _frames(20)
	check(absf(portals.time_left - left) < 0.01, "the portal's timer stands still while it plays")
	check(g.friends.size() == 6, "six friends come through (%d)" % g.friends.size())
	var friends: Array = g.friends.duplicate()
	if skipping:
		await create_timer(1.5).timeout
		g.skip()
	else:
		var seen: Array[String] = [g.beat]
		var t := 0.0
		var capped := false
		var gone_home := false
		while g.playing() and t < 80.0:
			await process_frame
			t += root.get_process_delta_time()
			if seen.back() != g.beat:
				seen.append(g.beat)
				if g.beat == "strike":
					capped = game.has_item(AFTER.CAP)
				if g.beat == "beam":
					gone_home = friends.all(func(f) -> bool: return not is_instance_valid(f) or not (f as Node3D).visible)
		check(seen == ["gather", "talk", "strike", "home", "beam", "stitch", "title", "done"], "every beat in order: %s" % [seen])
		check(t > 58.0 and t < 72.0, "it lasts about a minute (%.1f s)" % t)
		check(capped, "he gives you his cap before the clock strikes")
		check(gone_home, "...then the Shift takes every friend home")
	check(not g.playing() and g.beat == "done", "it ends" + (" (skipped)" if skipping else ""))
	check(game.has_item(AFTER.CAP), "Dash's Cap is yours")
	check(dialogue.flags.has(AFTER.DASH_GOODBYE), "everyone's home")
	await _frames(3)
	check(s.get_node_or_null("Dash") != null and s.get_node_or_null("Rex") != null and s.get_node_or_null("Rook") != null,
		"...and Dash, Rex and Rook are still here: Lumen City is their home")
	check(s.dash_at_clock(), "...Dash by the clock")
	check(s.get_node_or_null("Mayor Banner") != null, "Rex's banner goes up: REX FOR MAYOR")
	check(not player.input_locks().has(&"dash_goodbye"), "the controls come back")
	check(root.get_viewport().get_camera_3d() == old_cam, "...the player's camera too")
	check(player.get_node("HUD").visible, "...and the HUD")
	check(s.get_node_or_null("Goodbye Scene") == null and s.get_node_or_null("Goodbye") != null,
		"everything the cutscene put in is tidied away")
	check(s.get_node_or_null("Letter/Spot") != null, "his letter waits on his workbench")
	check(quests.state["loose_ends"].step == 2, "the quest moves on: his letter")


func _check_letter() -> void:
	var s := current_scene
	var letter := s.get_node("Letter") as Node3D
	check(letter.global_position.distance_to(s.LAB_MIDDLE) < 9.0, "...in his lab")
	check(absf(letter.global_position.y - s.ground_below(letter.global_position + Vector3(0, 1, 0)).y) < 0.3, "...standing on the floor")
	var words := " ".join(s.letter_lines())
	check("LATER" in words and "Rex" in words and "cap" in words, "the letter: he's just later, look after Rex, keep the cap")
	var sparkles: int = game.sparkles
	letter.get_node("Spot").use()
	check(dialogue.is_active(), "reading it")
	dialogue.end()
	await _frames(3)
	check(quests.state["loose_ends"].get("done", false) and game.sparkles == sparkles + 20, "reading it finishes Loose Ends (+20 sparkles)")
	var mayor := false
	for i in 20:
		mayor = mayor or "mayor" in " ".join(s.rex_lines()).to_lower()
	check(mayor, "Rex talks about being mayor of Lumen City one day")
	check("same tree" in " ".join(s.oak_lines()), "...and now the Old Oak's hum makes sense")


func _check_hand_ins() -> void:
	# The lost watches come to Dash in Lumen City now
	var s := current_scene
	var w := root.get_node("Watches")
	var first: Dictionary = w.WATCHES[0]
	dialogue.set_flag("watch_found_" + str(first.id))
	check(w.to_give().size() == 1, "a lost watch to give")
	s.get_node("Dash/Spot").use()
	check(dialogue.is_active() and dialogue.flags.has("watch_given_" + str(first.id)), "talking to Dash in Lumen City hands it in")
	dialogue.end()
	await _frames(3)


func _check_void() -> void:
	portals.go_home()
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == TOWN, "home to the Void")
	await _frames(4)
	var dash_left := false
	var rex: Node3D
	var rook: Node3D
	for r in s.find_children("Routine", "", true, false):
		if not is_instance_valid(r):
			continue
		match str(r.get("character_id")):
			"dash":
				dash_left = true
			"rex":
				rex = r.get_parent()
			"rook":
				rook = r.get_parent()
	check(not dash_left and rex == null and rook == null, "Dash, Rex and Rook aren't in the Void any more: they live in Lumen City")
	var races := root.get_node("Races")
	check(races._gone_home("lake_loop") == ["dash", "rex", "rook"], "they're left out of the Void's races")
	check(races._gone_home("skyway_run").is_empty(), "...but they still race the Skyway Run at home")
	var req := root.get_node("Requests")
	var for_dash := 0
	for i in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var r: Dictionary = req._make("deliver", "easy", rng)
		if str(r.get("who", "")) in ["dash", "rex"]:
			for_dash += 1
	check(for_dash == 0, "no deliveries for Dash or Rex on the request board (60 tries)")


func _check_saving() -> void:
	game.save_game()
	var flags: Dictionary = dialogue.flags.duplicate()
	game.load_game()
	check(dialogue.flags.has(AFTER.DASH_GOODBYE) and dialogue.flags.has(AFTER.REX_HOME) and game.has_item(AFTER.CAP)
		and quests.is_done("loose_ends"), "the ending saves and loads")
	check(flags.size() == dialogue.flags.size(), "...with every flag")


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
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
