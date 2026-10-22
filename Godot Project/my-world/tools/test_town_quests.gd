extends SceneTree

# Checks Pip's lamps and Bramble's window flowers (res://quests/pip_lamps.json, bramble_flowers.json): both start
# after Rex's campaign, Nina finds the glow shells and fills the window boxes, and the town changes for good: lit
# moon-lamps along the boardwalks, flowers in every window box. Run it twice: the second run starts up like the real
# game and checks the town is still changed.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_town_quests.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_town_quests.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const LAKE_Y := -0.3

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var player: CharacterBody3D
var talkers := {}
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
	check(quests.quest("pip_lamps").get("steps", []).size() == 2 and quests.quest("bramble_flowers").get("steps", []).size() == 2,
		"both quest files read")

	change_scene_to_file(TOWN)
	await _frames(5)
	await _in_town()
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	var shells := _nodes("Glow Shell *")
	var flower_spots := current_scene.find_children("Flower Spot", "Area3D", true, false)
	check(shells.size() == 5 and flower_spots.size() == 5, "5 glow shells and 5 window boxes to fill (%d, %d)" % [shells.size(), flower_spots.size()])
	for s in shells:
		check((s as Node3D).global_position.y > LAKE_Y, "%s is on dry ground (y %.2f)" % [s.name, (s as Node3D).global_position.y])
	await _frames(2)
	check(_count_visible("Lit Lantern *") == 0 and _count_visible("Unlit Lantern *") > 6, "boardwalk lanterns start unlit (%d)" % _nodes("Unlit Lantern *").size())
	check(shells.all(func(s: Node) -> bool: return not s.get_node("Before").visible), "no glow shells before the quest")
	check(_count_visible("Window Flowers") == 0 and flower_spots.all(func(s: Node) -> bool: return not s.get_node("Done").visible),
		"window boxes start empty")

	# Not before Rex's campaign is done
	clock.set_time(1, 19 * 60.0, true)
	dialogue.talks["pip"] = 2
	dialogue.talks["bramble"] = 2
	var early := await _talk("pip")
	check(not _said(early, "glow shells"), "Pip doesn't ask before Rex's campaign")
	quests.load_data({"rex_campaign": {"step": 6, "since_day": 1, "done": true}})

	# --- Pip: find the five glow shells, bring them back
	var ask := await _talk("pip", [0])
	check(_said(ask, "glow shells") and quests.on_step("pip_lamps", "find"), "Pip asks for glow shells; the quest starts")
	await _frames(2)
	check(shells.all(func(s: Node) -> bool: return s.get_node("Before").visible), "the glow shells appear round the lake")
	for s in shells:
		var ok := await _use_spot(s)
		check(ok and dialogue.flags.has(s.get("flag")) and not s.get_node("Before").visible, "picked up %s" % s.name)
	check(quests.on_step("pip_lamps", "bring"), "all five: on to 'bring'")
	var give := await _talk("pip")
	check(_said(give, "light up like little moons") and quests.is_done("pip_lamps"), "Pip lights the lanterns: quest done")
	await _frames(2)
	check(_count_visible("Lit Lantern *") == _nodes("Lit Lantern *").size() and _count_visible("Unlit Lantern *") == 0,
		"the boardwalk lanterns are lit (%d)" % _count_visible("Lit Lantern *"))
	await _stand_by("pip", 1.5)
	check(talkers["pip"]._name_label.text == "Lamplighter Pip", "Pip's name: \"%s\"" % talkers["pip"]._name_label.text)

	# --- Bramble: fill five window boxes, then the whole town blooms
	clock.set_time(2, 13 * 60.0, true)
	var flowers := await _talk("bramble", [0])
	check(_said(flowers, "window box") and quests.on_step("bramble_flowers", "deliver"), "Bramble asks Nina to fill the window boxes")
	for s in flower_spots:
		var ok := await _use_spot(s)
		check(ok and s.get_node("Done").visible, "filled the window box at %s" % s.get_parent().name)
	check(quests.on_step("bramble_flowers", "thanks") and _count_visible("Window Flowers") == 0, "all five filled; the rest wait for Bramble")
	var thanks := await _talk("bramble")
	check(_said(thanks, "did the rest of the town") and quests.is_done("bramble_flowers"), "Bramble's quest done")
	await _frames(2)
	check(_count_visible("Window Flowers") == _nodes("Window Flowers").size() and _nodes("Window Flowers").size() >= 6,
		"every other window box blooms too (%d)" % _count_visible("Window Flowers"))

	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var q: Dictionary = data.get("quests", {}) if data is Dictionary else {}
	check(q.get("pip_lamps", {}).get("done", false) and q.get("bramble_flowers", {}).get("done", false), "save.json has both quests done")
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	check(quests.is_done("pip_lamps") and quests.is_done("bramble_flowers"), "loaded: both quests done")
	game._resume = {}
	change_scene_to_file(TOWN)
	await _frames(6)
	check(_count_visible("Lit Lantern *") > 6 and _count_visible("Unlit Lantern *") == 0, "loaded: the boardwalk is still lit")
	check(_count_visible("Window Flowers") >= 6, "loaded: the window boxes are still blooming")
	var spots := current_scene.find_children("Flower Spot", "Area3D", true, false)
	check(spots.all(func(s: Node) -> bool: return s.get_node("Done").visible), "loaded: Nina's window boxes too")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _nodes(pattern: String) -> Array[Node]:
	return current_scene.find_children(pattern, "Node3D", true, false)


func _count_visible(pattern: String) -> int:
	return _nodes(pattern).filter(func(n: Node) -> bool: return (n as Node3D).visible).size()


func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _use_spot(spot: Area3D) -> bool:
	# Stand next to a quest spot (trying a few sides) and press Interact once it offers
	await _in_town()
	for k in 8:
		var side := Vector3(1.2, 0, 0).rotated(Vector3.UP, k * TAU / 8.0)
		player.global_position = spot.global_position + side + Vector3(0, 0.8, 0)
		player.velocity = Vector3.ZERO
		for i in 6:
			await physics_frame
		await _frames(2)
		if dialogue._nearest == spot:
			_press("interact")
			await _frames(3)
			return true
	print("NOTE  couldn't get the prompt at %s" % spot.get_path())
	return false


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
	var side := Vector3.ZERO
	var doors := current_scene.find_children("*", "Area3D", true, false).filter(
		func(a: Node) -> bool: return a.get_script() == load("res://scripts/door.gd"))
	for k in 24:
		var s := Vector3(1.7, 0, 0.6).normalized().rotated(Vector3.UP, k * TAU / 24.0)
		var spot := who.global_position + s * distance
		if doors.all(func(d: Node3D) -> bool: return d.global_position.distance_to(spot) > 4.5) and \
				talkers.values().all(func(t: Node3D) -> bool: return t == talkers[id] or t.global_position.distance_to(spot) > distance + 1.5):
			side = s
			break
	if side == Vector3.ZERO:
		side = Vector3(1.7, 0, 0.6).normalized()
	player.global_position = who.global_position + side * distance + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	await _frames(2)


func _in_town() -> void:
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE  left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t


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
