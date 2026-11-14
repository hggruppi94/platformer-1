extends SceneTree

# Screenshots of the castle school's new look (tools/build_school.gd, Hayden's 14 Nov 2026 picture and the Void School
# Sensory Plan): the palace front and its fountain, the courtyard garden, the palm grove, the hedge maze and the
# greenhouse, the east quad, the festival stage, the pool, the overlook walk, the music pods, the library from both
# floors and the foyer. The same spots are shot on an old build for "before" pictures. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_school_look.gd -- <output folder> [night]
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const SCHOOL := "res://scenes/school/school.tscn"

const VIEWS := [
	["01_palace_front", Vector3(0, 10, 74), Vector3(0, 7.5, 24)],
	["02_tiered_fountain", Vector3(9, 2.6, 45), Vector3(0, 3.0, 30)],
	["03_courtyard_garden", Vector3(-53, 2.6, 5.5), Vector3(-58, 1.2, -18)],
	["04_palm_hammocks", Vector3(-44.5, 3.0, 23.5), Vector3(-58, 1.6, 15)],
	["05_hedge_maze_and_greenhouse", Vector3(-60, 6.5, 57), Vector3(-22, 1.0, 40)],
	["06_east_quad", Vector3(35, 4.5, 25), Vector3(60, 2.0, 0)],
	["07_festival_stage", Vector3(55, 5.0, 28), Vector3(55, -0.5, 54)],
	["08_pool", Vector3(37, 4.5, -9), Vector3(54, -1.0, -22)],
	["09_overlook_walk", Vector3(-30, 2.6, -30), Vector3(30, 2.0, -37)],
	["10_music_pods", Vector3(19, 2.3, 12.5), Vector3(23, 1.6, 21.5)],
	["11_library_from_the_gallery", Vector3(-13, 8.2, 3), Vector3(3, 2.5, -10)],
	["12_library_floor", Vector3(-5, 2.0, -0.5), Vector3(10, 3.2, -5)],
	["13_foyer", Vector3(0, 2.6, 22.5), Vector3(0, 2.2, 10)],
	["14_from_above", Vector3(10, 55, 105), Vector3(5, 0, 5)],
	["15_skybridge", Vector3(9, 9.5, -6), Vector3(0, 6.2, -6)],
	["16_library_mezzanine", Vector3(2, 8.2, -3), Vector3(-7.2, 6.4, 2.6)],
	["17_nova_lab", Vector3(-12.5, 8.0, -10), Vector3(-21, 6.8, -15)],
	["18_gadget_wall", Vector3(-24, 7.8, 12.5), Vector3(-29.7, 7.5, 12.5)],
	["19_window_seats", Vector3(5.5, 13.8, -19), Vector3(-6, 12.4, -23.2)],
	["20_hidden_stair_top", Vector3(26.5, 14.5, -11), Vector3(28.55, 9, -14)],
	["21_hidden_stair_bottom", Vector3(28.5, 7.6, -7.5), Vector3(28.55, 9.5, -14)],
	["22_escalators_to_the_roof", Vector3(-31, 14.2, -2), Vector3(-36.5, 15.5, 10)],
	["23_roof_arrival", Vector3(-36, 20.0, 21.5), Vector3(-10, 18.5, 8)],
	["24_palm_terrace", Vector3(3.5, 21.5, -1), Vector3(18, 18.8, 14)],
	["25_terrace_loungers", Vector3(28, 20.2, 10), Vector3(14, 18.5, 20)],
	["26_roof_garden_gazebo", Vector3(-5, 21.5, 3), Vector3(-16, 19.5, 11)],
	["27_telescope", Vector3(-13.5, 20.2, 13.5), Vector3(-16, 19.6, 11)],
	["28_sky_pavilion", Vector3(2, 21.0, 0.5), Vector3(2, 19.5, -12)],
	["29_magic_craft_pods", Vector3(9, 20.2, -10), Vector3(0, 19.0, -17.5)],
	["30_roof_from_above", Vector3(10, 48, 62), Vector3(-2, 18, 0)],
]

var out_dir := "user://school_look_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred(args.size() > 1 and args[1] == "night")


func _run(night: bool) -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	clock.set_time(1, (21 * 60.0 + 30.0) if night else 13 * 60.0, true)
	game.next_spawn = "FromTown"
	change_scene_to_file(SCHOOL)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	player.global_position = Vector3(0, 1, 50)
	cam = Camera3D.new()
	cam.fov = 65
	cam.far = 1500
	current_scene.add_child(cam)
	cam.make_current()
	for v: Array in VIEWS:
		await _view(str(v[0]) + ("_night" if night else ""), v[1], v[2])
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
