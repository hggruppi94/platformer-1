extends SceneTree

# Pictures of the Lily Pond in the Void's south meadow and the friends on its shore (scripts/pond_friends.gd), in the
# real town at midday. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_pond_friends.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.pond_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pond_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://pond_friends"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 12 * 60.0, true)
	change_scene_to_file(TOWN)
	for i in 90:
		await process_frame
	var pond := root.get_node("Watches/PondFriends").pond() as Node3D
	var s := current_scene as Node3D
	var player := s.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = pond.global_position + Vector3(0, 0.5, -14)
	for l in root.find_children("*", "CanvasLayer", true, false):
		if l is CanvasLayer:
			(l as CanvasLayer).visible = false
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.current = true
	var c := pond.global_position
	var shots := {
		"01_pond_wide": [c + Vector3(-3, 4.0, -14), c + Vector3(0, 0.6, 0)],
		"02_friends": [c + Vector3(0, 1.5, -9.5), c + Vector3(0, 0.9, -4.4)],
		"03_hermez_close": [c + Vector3(-2.0, 1.6, -7.2), c + Vector3(-2.6, 1.2, -4.3)],
		"04_rolo_close": [c + Vector3(2.2, 1.2, -7.0), c + Vector3(2.4, 0.75, -4.6)],
	}
	for name in shots:
		cam.global_position = shots[name][0]
		cam.look_at(shots[name][1])
		for i in 20:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var path: String = out_dir.path_join(name + ".png")
		img.save_png(path)
		print("SHOT ", path)
	_finish()


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
