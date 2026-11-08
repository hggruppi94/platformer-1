extends SceneTree

# Checks the save slots (scripts/game.gd, scripts/title_screen.gd): slot 1 is save.json as it always was, a second
# slot keeps a whole other game (hero, items, sparkles) apart from the first, the title screen lists the three slots
# with who's in each, an empty slot starts a new game there, deleting a slot empties it, and tools like this one
# never move off slot 1 or write slots.cfg.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_save_slots.gd
#
# Your own saves are put aside and put back at the end (slots 2 and 3 too).

const SAVES := ["user://save.json", "user://save_slot2.json", "user://save_slot3.json"]
const TITLE := "res://scenes/title/title.tscn"

var failures := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	for s in SAVES:
		if FileAccess.file_exists(s) and not FileAccess.file_exists(s + ".slots_test_backup"):
			DirAccess.copy_absolute(s, s + ".slots_test_backup")
		DirAccess.remove_absolute(s)
	var had_cfg := FileAccess.file_exists("user://slots.cfg")
	game = root.get_node("Game")

	check(game.slot == 1 and game.save_path() == "user://save.json", "tools play in slot 1, which is save.json")
	check(game.slot_path(2) == "user://save_slot2.json" and game.slot_path(3) == "user://save_slot3.json",
		"slots 2 and 3 have files of their own")

	# Slot 1: Ana, with a skateboard and some sparkles
	game.hero = Hero.blank(true)
	game.hero["name"] = "Ana"
	game.needs_creator = false
	game.items.clear()
	game.items.append("skateboard")
	game.sparkles = 12
	game.level = 3
	game.save_game()
	check(FileAccess.file_exists("user://save.json"), "slot 1 saves to save.json")

	# Slot 2: empty, so a fresh start; Ben is made there
	game.use_slot(2)
	check(game.slot == 2 and game.items.is_empty() and game.sparkles == 0 and game.level == 1,
		"moving to an empty slot starts fresh (no items, sparkles or levels from slot 1)")
	game.hero = Hero.blank(false)
	game.hero["name"] = "Ben"
	game.needs_creator = false
	game.sparkles = 5
	game.save_game()
	check(FileAccess.file_exists("user://save_slot2.json"), "slot 2 saves to its own file")
	var one: Dictionary = game.slot_info(1)
	var two: Dictionary = game.slot_info(2)
	check(one.get("name") == "Ana" and int(one.get("level")) == 3 and bool(one.get("girl")), "slot 1's card: Ana, a girl, level 3")
	check(two.get("name") == "Ben" and not bool(two.get("girl")), "slot 2's card: Ben, a boy")
	check(game.slot_info(3).is_empty(), "slot 3 is empty")

	# Back to slot 1: Ana's game is just as it was
	game.use_slot(1)
	check(game.hero.name == "Ana" and game.has_item("skateboard") and game.sparkles == 12, "back in slot 1, Ana's game is as she left it")
	game.use_slot(2)
	check(game.hero.name == "Ben" and not game.has_item("skateboard") and game.sparkles == 5, "...and slot 2 is Ben's")
	game.use_slot(1)
	check(FileAccess.file_exists("user://slots.cfg") == had_cfg, "a tool run never writes slots.cfg")

	# The title screen lists the slots
	change_scene_to_file(TITLE)
	for i in 6:
		await process_frame
	var t := current_scene
	t.open_slots()
	await process_frame
	var b1 := t.slots_panel.find_child("Slot 1", true, false) as Button
	var b2 := t.slots_panel.find_child("Slot 2", true, false) as Button
	var b3 := t.slots_panel.find_child("Slot 3", true, false) as Button
	check(b1 != null and b2 != null and b3 != null, "the title screen's Save Slots shows three slots")
	check(b1 and "Ana" in b1.text and b2 and "Ben" in b2.text and b3 and "Empty" in b3.text, "...with who's in each, and Empty")
	check(t.slots_panel.find_child("Delete 2", true, false) != null and t.slots_panel.find_child("Delete 3", true, false) == null,
		"...and a Delete button only on a slot with a game in it")
	t._ask_delete(2)
	check(t.confirm_panel.visible and "Ben" in (t.confirm_panel.get_node("Box/Question") as Label).text, "Delete asks first")
	(t.confirm_panel.get_node("Box/Yes") as Button).pressed.emit()
	await process_frame
	check(game.slot_info(2).is_empty() and not FileAccess.file_exists("user://save_slot2.json"), "...and Yes empties the slot")
	check(t.slots_panel.visible and "Empty" in (t.slots_panel.find_child("Slot 2", true, false) as Button).text,
		"...and shows the slots again")
	check(game.slot == 1 and game.hero.name == "Ana", "deleting another slot leaves the game being played alone")
	t._close_slots()
	t._new_slot = 3
	t.play_opening()
	t.skip_opening()
	for i in 120:
		await process_frame
		if game.slot == 3:
			break
	check(game.slot == 3 and game.needs_creator, "a new game from an empty slot starts in that slot")
	game.slot = 1
	_finish()


func _finish() -> void:
	game.hold_saves = true           # (the new game above would otherwise save over the saves put back)
	game.slot = 1
	for s in SAVES:
		DirAccess.remove_absolute(s)
		if FileAccess.file_exists(s + ".slots_test_backup"):
			DirAccess.rename_absolute(s + ".slots_test_backup", s)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
