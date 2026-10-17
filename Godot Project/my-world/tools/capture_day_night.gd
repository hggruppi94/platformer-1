extends SceneTree

# Screenshots of day and night: the town at noon, dusk and midnight, the portal open in the Shift and closed after it,
# and waking up in Nina's House after sleeping. Opens a window (screenshots need rendering, so not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_day_night.gd -- <output folder>
#
# The folder defaults to user://day_night_shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"

var out_dir := "user://day_night_shots"
var clock: Node
var game: Node
var cam: Camera3D


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
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.pending_message = ""

	change_scene_to_file(TOWN)
	await _frames(5)
	var player := current_scene.find_child("Player", true, false) as Node3D
	var portal := current_scene.find_child("Portal to Earth", true, false) as Node3D
	cam = Camera3D.new()
	cam.fov = 70
	current_scene.add_child(cam)
	cam.make_current()

	# Overview from above the spawn, looking north over the lake to the castle
	var spawn := player.global_position
	_aim(spawn + Vector3(-6, 14, 16), spawn + Vector3(-10, 0, -60))
	await _shot(1, 12 * 60.0, "town_noon")
	await _shot(1, 18 * 60.0 + 45.0, "town_dusk")
	await _shot(2, 20.0, "town_midnight_shift")
	# The portal: open in the Shift, closed at 2 AM
	var front := portal.global_transform.basis.z
	_aim(portal.global_position + front * 13.0 + Vector3(0, 4, 0) + portal.global_transform.basis.x * 4.0,
		portal.global_position + Vector3(0, 3.2, 0))
	await _shot(2, 25.0, "portal_open_shift")
	await _shot(2, 2 * 60.0, "portal_closed_2am")

	# Sleep in Nina's bed at night and wake up in the morning
	change_scene_to_file(HOUSE)
	await _frames(5)
	player = current_scene.find_child("Player", true, false) as Node3D
	var bed := current_scene.find_child("SleepSpot", true, false) as Node3D
	player.global_position = bed.global_position + Vector3(0.6, 0.5, 2.0)
	clock.set_time(2, 22 * 60.0 + 30.0)
	await _frames(20)
	await _capture("house_bed_prompt")
	bed.call("sleep")
	await create_timer(1.6).timeout
	await _capture("sleeping_fade")
	await create_timer(3.2).timeout
	await _capture("house_after_sleep")
	# And outside, the morning after
	change_scene_to_file(TOWN)
	await _frames(5)
	cam = Camera3D.new()
	cam.fov = 70
	current_scene.add_child(cam)
	cam.make_current()
	_aim(spawn + Vector3(-6, 14, 16), spawn + Vector3(-10, 0, -60))
	await _frames(30)
	await _capture("town_morning_after_sleep")

	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()


func _aim(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)


func _shot(day: int, minutes: float, file: String) -> void:
	clock.set_time(day, minutes)
	await create_timer(3.0).timeout          # let the portal and the Shift glow ease in
	await _capture(file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file + ".png")
	root.get_texture().get_image().save_png(path)
	print("SHOT ", file, "  ", clock.call("time_string"), "  day ", clock.day)
