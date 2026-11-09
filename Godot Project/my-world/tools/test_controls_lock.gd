extends SceneTree

# Checks the holds on the player's controls (scenes/player/player.gd lock_input, Game.hold_controls): every system
# that stops her moving holds the controls under its own name, so a talk ending never hands them back while a
# countdown, a cutscene or the Swap-o-Tron still needs them.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_controls_lock.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


class Talker extends Node3D:
	# The least a talker needs for Dialogue.say()
	var display_name := "Tester"

	func begin_talk() -> void:
		pass

	func end_talk() -> void:
		pass


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
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame
	await _physics(3)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	if dialogue.is_active():
		dialogue.end()
		await create_timer(0.3).timeout
	player.input_locked = false

	# --- 1. Holds by name ---
	check(not player.input_locked and player.input_locks().is_empty(), "nobody's holding the controls to start with")
	var changes: Array = []
	player.input_lock_changed.connect(func(on: bool) -> void: changes.append(on))
	game.hold_controls(&"race", true)
	game.hold_controls(&"race", true)               # (countdowns take it every frame)
	check(player.input_locked and player.input_locks() == [&"race"], "a hold locks the controls, and says who's holding")
	game.hold_controls(&"lab", true)
	game.hold_controls(&"race", false)
	check(player.input_locked and player.input_locks() == [&"lab"], "letting go of one hold leaves the other")
	game.hold_controls(&"lab", false)
	game.hold_controls(&"lab", false)               # (letting go twice is harmless)
	check(not player.input_locked, "...and she moves again once both have let go")
	check(changes == [true, false], "the signal says locked once and free once: %s" % [changes])

	# --- 2. A talk ending doesn't undo someone else's hold (the old bug: the Swap-o-Tron, race and run countdowns) ---
	var talker := Talker.new()
	current_scene.add_child(talker)
	dialogue.say(talker, "Tester", ["Hello!"], "")
	check(dialogue.is_active() and &"dialogue" in player.input_locks(), "talking holds the controls")
	game.hold_controls(&"lab", true)                # a talk's "do" starts the machine
	dialogue.end()
	await create_timer(0.4).timeout                 # (the talk lets go 0.15 s after it closes)
	check(not dialogue.is_active() and player.input_locked and player.input_locks() == [&"lab"],
		"the talk ending leaves the machine's hold: %s" % [player.input_locks()])
	game.hold_controls(&"lab", false)
	check(not player.input_locked, "...and the machine finishing frees her")

	# --- 3. The old switch still works for tools ---
	player.input_locked = true
	check(player.input_locked and player.input_locks() == [&"legacy"], "input_locked = true still holds the controls")
	game.hold_controls(&"race", true)
	player.input_locked = false
	check(not player.input_locked and player.input_locks().is_empty(), "input_locked = false lets go for everyone")

	# --- 4. Walking really stops while held, and starts again ---
	game.hold_controls(&"test", true)
	Input.action_press("move_forward")
	var from := player.global_position
	await _physics(20)
	var moved_held := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	game.hold_controls(&"test", false)
	from = player.global_position
	await _physics(20)
	var moved_free := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	Input.action_release("move_forward")
	check(moved_held < 0.05 and moved_free > 0.3, "held: stands still (%.2f m); let go: walks (%.2f m)" % [moved_held, moved_free])
	_finish()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
