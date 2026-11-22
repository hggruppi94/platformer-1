extends SceneTree

# Pictures for Shard Isle's baked props: the floating islands' rock, the stepping stones, the crystal clusters' mounds,
# the Heart Stone, the Echo Crystals and every crystal (22 Nov 2026, tools/build_prop_shard_isle.py,
# scripts/detail_props.gd dress_shard_isle(), scripts/shard_isle.gd). With --old-props it shoots the same spots with
# everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_shard_isle.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_shard_isle_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_shard_isle_capture_backup.cfg"
const WORLD := "res://scenes/portal_worlds/shard_isle.tscn"

var out_dir := "user://detail_shard_isle_shots"
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
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	change_scene_to_file(WORLD)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	s.set_process(false)
	s.set_physics_process(false)
	var player := s.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(0, 0.5, 9)              # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	views.append(["01_island_side", Vector3(30, -6, 30), Vector3(0, -3, 0)])
	views.append(["02_island_under", Vector3(13, -14, 13), Vector3(0, -5, 0)])
	views.append(["03_stones", Vector3(12, 3.5, 5), Vector3(20, 0.5, -4)])
	views.append(["04_stone_close", Vector3(13.5, 1.6, -0.8), Vector3(15.5, 0, -3.6)])
	views.append(["05_heart_stone", Vector3(3.5, 2.4, 2.5), Vector3(0, 1, -3)])
	views.append(["06_echo", Vector3(22.5, 3.6, -3.5), Vector3(25, 2.8, -6)])
	views.append(["07_rim_crystals", Vector3(-4, 3.5, 3), Vector3(-11, 1.2, -6)])
	views.append(["08_islet_under", Vector3(-14, -6, 19), Vector3(-24, -2, 9)])
	views.append(["09_wide", Vector3(-48, 12, 48), Vector3(0, -2, 0)])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
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
