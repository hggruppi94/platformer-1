extends SceneTree

# Pictures for the portal worlds' dream skies (scripts/world_sky.gd, 22 Nov 2026): for each world a look out at its
# far scenery and a look up at its sky, plus Lanternmoor at dawn and Glenmoor at night. --no-haze leaves the haze off.
# A world id after the folder shoots only that world.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_world_skies.gd -- <folder> [<world>] [--no-haze]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.world_skies_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.world_skies_capture_backup.cfg"
const WORLDS := ["rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs", "dark_hollow",
	"far_future"]

var out_dir := "user://world_skies_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var portals := root.get_node("Portals")
	portals.home_calls.enabled = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	for id: String in WORLDS:
		if args.size() > 1 and not args[1].begins_with("--") and args[1] != id:
			continue
		change_scene_to_file(str(portals.world(id).scene))
		for i in 16:
			await process_frame
		await create_timer(3.0).timeout
		var s := current_scene
		var player := s.find_child("Player", true, false) as Node3D
		var eye := Vector3(0, 4, 0)
		var entrance := s.get_node_or_null("Entrance") as Node3D
		if entrance:
			eye = entrance.global_position + Vector3(0, 4, 0)
		if player:
			player.visible = false
		for c in root.find_children("*", "CanvasLayer", true, false):
			if c.name != "Dream Haze":
				(c as CanvasLayer).visible = false
		var sky := s.get_node("Dream Sky")
		var haze := sky.get_node_or_null("Dream Haze") as CanvasLayer
		if haze:
			haze.visible = not "--no-haze" in args
		cam = Camera3D.new()
		cam.fov = 60
		cam.far = 3000
		s.add_child(cam)
		cam.make_current()
		var g: Node3D = sky.far[0]
		var flat := Vector3(g.global_position.x, 0, g.global_position.z).normalized()
		cam.global_position = eye
		cam.look_at(eye + flat * 100.0 + Vector3(0, 28, 0))
		await _shot(id + "_1_out")
		var other := flat.rotated(Vector3.UP, 2.2)
		cam.global_position = eye
		cam.look_at(eye + other * 100.0 + Vector3(0, 70, 0))
		await _shot(id + "_2_up")
		if id == "lanternmoor":
			s.set_dawn(1.0)
			cam.look_at(eye + flat * 100.0 + Vector3(0, 28, 0))
			await _shot(id + "_3_dawn")
		if id == "glenmoor":
			s.set_process(false)
			s.set_daylight(0.5)
			cam.look_at(eye + other * 100.0 + Vector3(0, 50, 0))
			await _shot(id + "_3_night")
		cam.queue_free()
	_finish()


func _shot(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


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
