extends SceneTree

# Screenshots of Earth through the portal: arriving by the old oak, the town green and gazebo, the main street,
# Mr. Palmer in person, the gazebo lit up, and evening falling. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_shots"
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
	var clock := root.get_node("Clock")
	var quests := root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	dialogue.reset()
	quests.reset()
	game._resume = {}
	game.pending_message = ""
	clock.set_time(1, 12.0, true)                         # 12:12 AM: the Shift
	clock.earth_minutes = 16 * 60.0 + 40.0
	game.next_spawn = "Entrance"
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	await _shot("01_arriving_on_earth_by_the_old_oak")
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(-6, 9, 26)
	cam.look_at(Vector3(0, 2, 0))
	await _shot("02_the_town_green_and_gazebo")
	cam.global_position = Vector3(-24, 3.5, -12)
	cam.look_at(Vector3(4, 2.5, -31))
	await _shot("03_main_street_diner_and_bookshop")

	var palmer := _talker("palmer_earth")
	var p := palmer.get_parent() as Node3D
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.global_position = p.global_position + p.global_basis.z * 1.7 + Vector3(0, 0.8, 0)
	player.get_node("Visual").rotation.y = p.global_rotation.y + PI
	await create_timer(0.5).timeout
	cam.global_position = p.global_position + p.global_basis.x * 3.5 + p.global_basis.z * 2.0 + Vector3(0, 1.6, 0)
	cam.look_at(p.global_position + p.global_basis.z * 0.8 + Vector3(0, 1.2, 0))
	dialogue.talk_to(palmer)
	await _advance_to("Shh!")
	await _shot("04_mr_palmer_in_person")
	while dialogue.is_active():
		dialogue._finish_typing()
		_press("interact")
		await _frames(3)

	# Evening, the gazebo lit after the lights quest
	quests.load_data({"earth_lights": {"step": 2, "since_day": 1, "done": true}})
	quests.changed.emit("earth_lights")
	clock.earth_minutes = 19 * 60.0 + 30.0
	clock.time_changed.emit()
	await create_timer(1.0).timeout
	cam.global_position = Vector3(7, 4.5, 14)
	cam.look_at(Vector3(0, 2.5, 0))
	await _shot("05_evening_the_gazebo_all_lit_up")
	cam.current = false
	player.global_position = Vector3(-4, 1, 16)
	player.get_node("Visual").rotation.y = PI
	await create_timer(1.0).timeout
	await _shot("06_earth_time_on_the_hud")
	root.get_node("PauseMenu").open()
	await _shot("07_pause_menu_go_back_through_the_portal")
	root.get_node("PauseMenu").close()
	_finish()


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _advance_to(text: String) -> void:
	await _frames(3)
	for i in 30:
		dialogue._finish_typing()
		if dialogue._text.text.contains(text) or not dialogue.is_active():
			return
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
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
