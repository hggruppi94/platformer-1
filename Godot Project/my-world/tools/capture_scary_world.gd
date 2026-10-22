extends SceneTree

# Screenshots of the Scary World: the gate's question in town, the misty wood, the eyes in the dark, the centipede
# (and its reveal), the way home, and the pause menu's "Go home to town". Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_scary_world.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"

var out_dir := "user://scary_shots"
var dialogue: Node
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(180.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	dialogue.reset()
	root.get_node("Quests").reset()
	game._resume = {}
	game.pending_message = ""
	root.get_node("Clock").set_time(1, 17 * 60.0, true)
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame

	# The gate asks
	var gate := _talker("scary_gate")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var g := gate.get_parent().get_parent() as Node3D
	player.global_position = gate.global_position + g.global_basis.z * 1.5 + Vector3(0, 0.8, 0)
	player.get_node("Visual").rotation.y = g.global_rotation.y + PI
	await create_timer(2.0).timeout
	dialogue.talk_to(gate)
	await _advance_to_choice()
	await _shot("01_the_gate_asks_do_you_want_to_go_in")
	dialogue.current_choices()[1].pressed.emit()
	while dialogue.is_active():
		dialogue._finish_typing()
		_press("interact")
		await _frames(3)
	for i in 90:
		await process_frame
		if current_scene and current_scene.scene_file_path == SCARY:
			break
	await create_timer(1.5).timeout
	await _shot("02_inside_the_scary_world")

	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(8, 6, 22)
	cam.look_at(Vector3(0, 1, -6))
	await _shot("03_the_misty_wood_and_the_hollow_log")
	cam.global_position = Vector3(0, 1.8, 12)
	cam.look_at(Vector3(-6, 1.8, 27))
	await _shot("04_eyes_in_the_dark_glow_bugs")

	# The centipede
	var cent := _talker("centipede")
	var c := cent.get_parent() as Node3D
	player = current_scene.find_child("Player", true, false) as Node3D
	player.global_position = c.global_position + Vector3(0.5, 0.8, 4.5)
	player.get_node("Visual").rotation.y = PI
	await create_timer(1.0).timeout
	cam.global_position = c.global_position + Vector3(4.5, 2.6, 6.5)
	cam.look_at(c.global_position + Vector3(0, 0.8, 1.0))
	await _shot("05_the_centipede_by_its_log")
	dialogue.talk_to(cent)
	await _advance_to_text("wanted a friend")
	await _shot("06_i_just_wanted_a_friend")
	await _end_talk([0, 0])
	await create_timer(0.6).timeout

	# The way home, and the pause menu
	cam.global_position = Vector3(3, 2.5, 18)
	cam.look_at(Vector3(0, 2.5, 28))
	await _shot("07_the_way_home")
	root.get_node("PauseMenu").open()
	await _shot("08_pause_menu_go_home_to_town")
	root.get_node("PauseMenu").close()
	root.get_node("TownMap").toggle()
	await _shot("09_map_inside_the_scary_world")
	root.get_node("TownMap").toggle()
	_finish()


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _advance_to_choice() -> void:
	await _frames(3)
	while dialogue.is_active() and not dialogue._choosing:
		dialogue._finish_typing()
		_press("interact")
		await _frames(3)


func _advance_to_text(text: String) -> void:
	await _frames(3)
	var picks := [1]
	for i in 40:
		dialogue._finish_typing()
		if dialogue._text.text.contains(text):
			return
		if dialogue._choosing:
			dialogue.current_choices()[picks.pop_front() if picks.size() else 0].pressed.emit()
		else:
			_press("interact")
		await _frames(3)


func _end_talk(picks: Array) -> void:
	while dialogue.is_active():
		if dialogue._choosing:
			dialogue.current_choices()[picks.pop_front() if picks.size() else 0].pressed.emit()
		else:
			dialogue._finish_typing()
			_press("interact")
		await _frames(3)


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


func _shot(file: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
