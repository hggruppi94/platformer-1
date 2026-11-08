extends SceneTree

# Screenshots of Bramble's burrow (scripts/burrow.gd), the Rootmind's reward: Bramble teaching it once the Rootmind's
# mended, diving into the moss, the soil mound racing over the Void's grass, and sprouting back up with a hop. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_burrow.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.burrow_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.burrow_capture_backup.cfg"

var out_dir := "user://burrow_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	portals.cleared_worlds.append("shard_isle")
	await _rootmind()
	await _void()
	_finish()


func _rootmind() -> void:
	game_go("res://scenes/portal_worlds/rootmind.tscn")
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var b := (s.get_node("Bramble") as Node3D).global_position
	p.global_position = b + Vector3(-1.2, 0.5, 2.2)
	await _frames(10)
	s.mend()
	await create_timer(s.TEACH_AFTER + 1.2).timeout
	await _shot("01_bramble_teaches_the_burrow")
	var dialogue := root.get_node("Dialogue")
	if dialogue.is_active():
		dialogue.end()
	await _frames(30)
	p.get_node("HUD").visible = false
	_cam_in(s)
	p.global_position = Vector3(4, 0.9, 14)
	await _frames(10)
	p.burrow.try_start()
	await create_timer(0.12).timeout
	_look(p.global_position + Vector3(2.2, 1.6, 3.2), p.global_position + Vector3(0, -0.6, 0))
	await _shot("02_diving_into_the_moss")


func _void() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	var at: Vector3 = root.get_node("Remnants").ground_at(Vector2(-52, -10))
	p.global_position = at + Vector3(0, 0.9, 0)
	await _frames(10)
	p.burrow.try_start()
	Input.action_press("move_forward")
	for i in 50:
		await physics_frame
		_look(p.global_position + Vector3(-4.0, 2.4, 3.0), p.global_position + Vector3(0, -0.7, -1.0))
	await _shot("03_tunnelling_through_the_void")
	Input.action_release("move_forward")
	p.burrow.stop(p.burrow.HOP)
	var top := p.global_position
	for i in 16:
		await physics_frame
	_look(top + Vector3(-4.0, 1.6, 3.5), p.global_position)
	await _shot("04_sprouting_back_up")


func game_go(path: String) -> void:
	root.get_node("Game").go(path, "Entrance" if path.contains("portal_worlds") else "", "")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Input.action_release("move_forward")
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
