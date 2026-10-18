extends SceneTree

# Screenshots of talking to people: a name and "Press F to talk" up close, and a few conversations (lines, Nina's
# replies, questions, a night and a Shift variant). Opens a window (screenshots need rendering, so not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_dialogue.gd -- <output folder>
#
# The folder defaults to user://dialogue_shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://dialogue_shots"
var clock: Node
var game: Node
var dialogue: Node
var player: Node3D
var cam: Camera3D
var talkers := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_run.call_deferred()


func _run() -> void:
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	change_scene_to_file(TOWN)
	await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.make_current()

	clock.set_time(1, 11 * 60.0, true)
	await _stand_by("dash")
	await _capture("01_name_and_prompt")
	await _conversation("dash", "day", 0, 0, "02_dash_first_meeting")
	await _conversation("rook", "day", 0, 3, "03_rook_and_nina")
	await _conversation("rex", "day", 1, -1, "04_rex_vote_question")
	await _conversation("bramble", "day", 1, -1, "05_bramble_pick_me_up")
	await _conversation("pip", "night", 3, 0, "06_pip_at_night")
	await _conversation("dash", "shift", 2, 2, "07_dash_in_the_shift")
	await _conversation("green_man", "shift", 2, 0, "08_green_man_in_the_shift")

	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()


func _conversation(id: String, period: String, talks: int, advance: int, file: String) -> void:
	# Talk to id at that time of day, as if it's visit number talks, go on `advance` lines (-1: up to the first
	# question), and take the picture
	var minutes := {"morning": 8 * 60.0, "day": 13 * 60.0, "evening": 19 * 60.0, "night": 22 * 60.0, "shift": 20.0}
	clock.set_time(2, minutes[period], true)
	await create_timer(2.5).timeout                  # let the sky and lamps catch up
	dialogue.talks[id] = talks
	await _stand_by(id)
	_press("interact")
	await _frames(3)
	var n := 0
	while dialogue.is_active() and not dialogue._choosing and (advance < 0 or n < advance):
		dialogue._finish_typing()
		_press("interact")
		await _frames(3)
		n += 1
	if dialogue._typing:
		dialogue._finish_typing()
	await create_timer(1.0).timeout                  # they turn to face her
	await _capture(file)
	while dialogue.is_active():                     # finish it off
		if dialogue._choosing:
			dialogue.current_choices()[0].pressed.emit()
		else:
			dialogue._finish_typing()
			_press("interact")
		await _frames(3)
	await create_timer(0.3).timeout


func _stand_by(id: String) -> void:
	# Nina a step from them, the camera off to the side looking at the two of them
	await _in_town()
	var who := talkers[id].get_parent() as Node3D
	var at := who.global_position
	var side := _clear_side(id, at, 1.7)
	if side == Vector3.ZERO and who is CharacterBody3D:
		# A wanderer (Rex, Rook) standing right next to someone else: walk him a few steps off first
		for k in 8:
			who.global_position += Vector3(3, 0.5, 0).rotated(Vector3.UP, k * TAU / 8.0)
			for i in 4:
				await physics_frame
			at = who.global_position
			side = _clear_side(id, at, 1.7)
			if side != Vector3.ZERO:
				break
	if side == Vector3.ZERO:
		side = Vector3(1.7, 0, 0.6).normalized()
	player.global_position = at + side * 1.7 + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	player.get_node("Visual").rotation.y = atan2(-side.x, -side.z)
	for i in 8:
		await physics_frame
	var mid := (at + player.global_position) / 2.0
	var across := side.cross(Vector3.UP).normalized()
	cam.global_position = mid + across * 4.2 + Vector3(0, 1.7, 0)
	cam.look_at(mid + Vector3(0, 0.6, 0))
	await _frames(3)


func _clear_side(id: String, at: Vector3, distance: float) -> Vector3:
	# A direction to stand in that keeps Nina out of door triggers (Rex wanders right past Nina's House door) and
	# makes this person clearly the nearest one to talk to (Rex and Bramble often stand side by side)
	var doors := current_scene.find_children("*", "Area3D", true, false).filter(
		func(a: Node) -> bool: return a.get_script() == load("res://scripts/door.gd"))
	var others := current_scene.find_children("Talk", "Area3D", true, false).filter(
		func(t: Node) -> bool: return t.get("character_id") != id)
	for k in 24:
		var side := Vector3(1.7, 0, 0.6).normalized().rotated(Vector3.UP, k * TAU / 24.0)
		var spot := at + side * distance
		if doors.all(func(d: Node3D) -> bool: return d.global_position.distance_to(spot) > 4.5) and 				others.all(func(t: Node3D) -> bool: return t.global_position.distance_to(spot) > distance + 1.5):
			return side
	return Vector3.ZERO


func _in_town() -> void:
	# Look everyone up again, in case something reloaded the town (or a door took her inside)
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		cam = Camera3D.new()
		cam.fov = 60
		current_scene.add_child(cam)
	cam.make_current()


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


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file, "  ", clock.call("time_string"))
