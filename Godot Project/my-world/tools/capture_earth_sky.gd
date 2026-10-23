extends SceneTree

# Screenshots of the Earth town's sky (tools/build_earth.gd, scripts/earth_world.gd) through an Earth day: sunrise,
# midday with white clouds, sunset, and night with the stars and the moon. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_sky.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_sky_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	clock.set_time(1, 12.0, true)                         # the Shift, when the portal to Earth is open
	game.next_spawn = "Entrance"
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.0).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 70
	current_scene.add_child(cam)
	cam.make_current()
	# From the corner of the green, looking across the gazebo and up into the sky
	var at := Vector3(-16, 2.2, 16)
	for shot in [["01_sunrise", 6.6, Vector3(30, 8, -6)], ["02_midday_clouds", 12.5, Vector3(10, 12, -30)],
			["03_sunset", 18.6, Vector3(-30, 7, -8)]]:
		clock.earth_minutes = shot[1] * 60.0
		await _view(shot[0], at, at + shot[2])
	clock.earth_minutes = 22.0 * 60.0
	await _view("04_night_stars_and_moon", at, at)             # aimed once the moon has moved to its night spot
	var moon := current_scene.get_node("Sky/Moon") as Node3D
	await _view("04_night_stars_and_moon", at, at + (moon.global_position - at).normalized() * 10.0 + Vector3(0, -2.5, 0))
	_finish()


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
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
