extends SceneTree

# Pictures of the cosmic dust (scripts/cosmic_dust.gd, 23 Nov 2026): the Void by day and at night, Dark Hollow,
# Lanternmoor and the Far Future, each from the player's own camera. With --no-dust it shoots the same views without
# it, for a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_cosmic_dust.gd -- <folder> [--no-dust]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.cosmic_dust_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.cosmic_dust_capture_backup.cfg"
const SHOTS := [
	["void_day", "res://scenes/town/town.tscn", 11 * 60],
	["void_night", "res://scenes/town/town.tscn", 23 * 60],
	["dark_hollow", "res://scenes/portal_worlds/dark_hollow.tscn", -1],
	["lanternmoor", "res://scenes/portal_worlds/lanternmoor.tscn", -1],
	["far_future", "res://scenes/portal_worlds/far_future.tscn", -1],
]

var out_dir := "user://cosmic_dust_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Portals").home_calls.enabled = false
	root.get_node("WorldDetail").cosmic = not ("--no-dust" in OS.get_cmdline_user_args())
	var clock := root.get_node("Clock")
	for shot: Array in SHOTS:
		if int(shot[2]) >= 0:
			clock.minutes = float(shot[2])
		change_scene_to_file(shot[1])
		for i in 16:
			await process_frame
		if int(shot[2]) >= 0:
			clock.minutes = float(shot[2])
			clock.running = false
		await create_timer(2.5).timeout
		for c in root.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = false
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(String(shot[0]) + ".png"))
		print("SHOT ", shot[0])
		clock.running = true
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0)
