extends SceneTree

# Screenshots of the town map: open by day with a quest on, in the Shift with the portal open, and the corner
# minimap while walking about. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_map.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://map_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	var map := root.get_node("TownMap")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	quests.load_data({"rex_campaign": {"step": 0, "since_day": 1}})
	dialogue.flags["asked_dash"] = true
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-60, 2, 58)
	player.get_node("Visual").rotation.y = PI * 0.75
	clock.set_time(1, 14 * 60.0, true)
	await create_timer(2.0).timeout
	map.toggle()
	await _shot("01_town_map_with_quest_stars")
	map.toggle()
	clock.set_time(2, 20.0, true)                          # the Shift
	await create_timer(1.5).timeout
	map.toggle()
	await _shot("02_town_map_in_the_shift_portal_open")
	map.toggle()
	clock.set_time(2, 9 * 60.0, true)
	var minimap_was: bool = settings.minimap
	settings.minimap = true
	player.global_position = Vector3(70, 2, 10)
	await create_timer(2.0).timeout
	await _shot("03_corner_minimap_in_the_homes")
	settings.minimap = minimap_was
	_finish()


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
