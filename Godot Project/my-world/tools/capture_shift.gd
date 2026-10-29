extends SceneTree

# Screenshots of the Shift the story's way round: a new game at home on Earth, the house on the green, the portal by
# the old oak asleep in the evening and swirling open at midnight, arriving in Galaxity at its dawn, Galaxity's
# evening while Earth's clock has barely moved, being pulled home at 1 AM, and the bed at home. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_shift.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://shift_shots"
var clock: Node
var game: Node
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	game.new_game()
	game.hero["name"] = "Sofi"
	await _wait_for_scene(EARTH)
	await create_timer(1.5).timeout
	await _shot("01_a_new_game_starts_at_home_on_earth")

	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	var home := current_scene.find_child("My Home", true, false) as Node3D
	cam.global_position = home.global_position + Vector3(-7, 4, -14)
	cam.look_at(home.global_position + Vector3(0, 2.5, 0))
	await _shot("02_home_on_the_south_side_of_the_green")

	clock.set_earth_time(22 * 60.0, true)
	await create_timer(1.0).timeout
	var portal := current_scene.find_child("Portal Home", true, false) as Node3D
	# (the portal group's +Z faces the green: look at the ring from there)
	cam.global_position = portal.global_position + portal.global_basis.z * 7.0 + portal.global_basis.x * 2.0 + Vector3(0, 2.6, 0)
	cam.look_at(portal.global_position + Vector3(0, 1.8, 0))
	await _shot("03_10pm_the_portal_by_the_old_oak_is_asleep")
	clock.set_earth_time(23 * 60.0 + 59.8)
	await create_timer(4.0).timeout
	await _shot("04_midnight_the_shift_the_portal_opens_to_galaxity")
	cam.current = false
	await create_timer(0.3).timeout
	await _shot("05_the_hud_on_earth_in_the_shift")

	game.go(TOWN, "FromPortaltoEarth", "Galaxity")
	await _wait_for_scene(TOWN)
	await create_timer(2.0).timeout
	await _shot("06_through_the_portal_galaxity_at_dawn")
	clock.set_time(clock.day, 19 * 60.0, true)
	await create_timer(2.0).timeout
	await _shot("07_galaxity_evening_earth_is_only_at_1230am")
	clock.set_time(clock.day, 6 * 60.0 + 59.6, true)
	await _wait_for_scene(EARTH, 600)
	await create_timer(1.5).timeout
	await _shot("08_1am_the_portal_pulls_you_home_to_earth")

	# The bed at home, with its picker
	var bed := current_scene.find_child("My Home", true, false).find_child("SleepSpot", true, false) as Area3D
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.global_position = bed.global_position + Vector3(0.6, 0.5, -2.0)
	await create_timer(1.0).timeout
	clock.set_earth_time(19 * 60.0, true)
	bed.open_picker()
	await _shot("09_sleep_until_the_shift_in_your_own_bed")
	bed.close_picker()
	_finish()


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	for i in 8:
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
