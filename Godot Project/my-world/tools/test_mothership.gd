extends SceneTree

# Checks flying the mothership (scripts/mothership.gd, scripts/mothership_pad.gd): standing on the Mothership Pad and
# pressing Interact calls it down, it beams Nina up into the cockpit, the move keys fly it the way the camera faces,
# Jump climbs, it can't leave the town or scrape the ground, a save made up there puts her back on the pad, and
# Interact beams her down to the ground underneath and sends the ship back to its loop.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_mothership.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

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
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var ship := town.get_node_or_null("Mothership") as Node3D
	var pad := town.find_child("PadCall", true, false) as Area3D
	check(ship != null and pad != null, "the town has the mothership and its pad")
	if ship == null or pad == null:
		_end()
		return
	var spot: Vector3 = pad.pad_spot()

	# --- Standing on the pad shows the prompt ---
	p.global_position = spot + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	check(p.is_on_floor() and absf(p.global_position.y - spot.y) < 1.5, "she can stand on the pad (%.2f m over it)" % (p.global_position.y - spot.y))
	var prompt := pad.get_node("Prompt") as Label3D
	check(prompt.visible and "call the mothership" in prompt.text, "...and it says to call the mothership")

	# --- Interact calls it down; it beams her up ---
	await _press("interact")
	check(ship.is_coming(), "Interact calls the mothership down")
	ship.global_position = spot + Vector3(30, 60, 0)          # it starts closer, so the test doesn't wait for the loop
	var boarded := false
	for i in 300:
		await _physics(3)
		if ship.state == ship.State.PILOTED:
			boarded = true
			break
	check(boarded, "...it comes over the pad and beams her up")
	var seat: Vector3 = ship.get_node("Hull/Cockpit").global_position
	check(p.carried and p.input_locked and p.global_position.distance_to(seat) < 1.5, "...into the cockpit")
	check(absf(ship.global_position.y - (spot.y + ship.hover_height)) < 5.0, "...from a hover over the pad")
	check((p.get_node("SpringArm3D") as SpringArm3D).spring_length > 30.0, "the camera pulls back to see the whole ship")

	# --- A save made up here puts her back on the pad ---
	game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var saved := Vector3(data.position[0], data.position[1], data.position[2])
	check(saved.distance_to(spot) < 2.0, "a save while flying puts her back on the pad, not in the sky")

	# --- Flying: forward goes the way the camera faces, Jump climbs ---
	var arm := p.get_node("SpringArm3D") as Node3D
	arm.rotation.y = 0.0                                       # camera looking north (-Z)
	var from := ship.global_position
	Input.action_press("move_forward")
	await create_timer(2.0).timeout
	Input.action_release("move_forward")
	var moved := ship.global_position - from
	check(moved.z < -15.0 and absf(moved.x) < 5.0, "forward flies the way the camera faces (%.0f m north)" % -moved.z)
	check(p.global_position.distance_to(ship.get_node("Hull/Cockpit").global_position + Vector3(0, 0.8, 0)) < 0.5,
		"...and she stays in the cockpit")
	from = ship.global_position
	Input.action_press("jump")
	await create_timer(1.0).timeout
	Input.action_release("jump")
	check(ship.global_position.y > from.y + 4.0, "Jump climbs (%.1f m)" % (ship.global_position.y - from.y))

	# --- It stays over the town and off the ground ---
	ship.global_position = Vector3(400, ship.global_position.y, 0)
	await _frames(2)
	check(ship.global_position.x <= ship.bounds.end.x + 0.1, "it can't fly off the edge of the town")
	ship.global_position = Vector3(spot.x, spot.y + 2.0, spot.z)
	await _frames(2)
	check(ship.global_position.y >= spot.y + ship.min_altitude - 1.0, "...or down into the ground")

	# --- No skateboard in the cockpit ---
	var had_board: bool = game.has_item("skateboard")
	if not had_board:
		game.items.append("skateboard")
	var riding: bool = game.riding
	await _press("toggle_skateboard")
	check(game.riding == riding, "the skateboard key does nothing while she's flying")
	if not had_board:
		game.items.erase("skateboard")

	# --- Interact beams her down and the ship flies off on its own ---
	ship.global_position = Vector3(spot.x + 10, spot.y + 40, spot.z + 10)
	await _frames(2)
	await _press("interact")
	var off := false
	for i in 300:
		await _physics(3)
		if not p.carried:
			off = true
			break
	check(off and ship.state == ship.State.CRUISING, "Interact beams her down and the ship cruises on")
	check(not p.input_locked and not p.has_meta("save_spot"), "...and she can walk again")
	await _physics(30)
	check(p.is_on_floor() and Vector2(p.global_position.x - ship.global_position.x, p.global_position.z - ship.global_position.z).length() < 6.0,
		"...on the ground right under where it was")
	await create_timer(1.6).timeout
	check((p.get_node("SpringArm3D") as SpringArm3D).spring_length < 8.0, "the camera is back close to her")
	_end()


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


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
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
