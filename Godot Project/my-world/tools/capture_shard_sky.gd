extends SceneTree

# Pictures for Shard Isle's dream sky (scripts/shard_sky.gd, 22 Nov 2026): the sky all round, the Dream Islands and
# their lightfalls, the monoliths, the sky jellies, the dream haze, and a Warp Ring's swirl part way through.
# --no-haze leaves the haze off (to compare).
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_shard_sky.gd -- <folder> [--no-haze]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.shard_sky_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.shard_sky_capture_backup.cfg"
const WORLD := "res://scenes/portal_worlds/shard_isle.tscn"

var out_dir := "user://shard_sky_shots"
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
	var sky := s.get_node("Dream Sky")
	var haze := sky.get_node_or_null("Dream Haze") as CanvasLayer
	if haze:
		haze.visible = not "--no-haze" in args
	var island: Node3D = sky.islands[0]
	var jelly: Node3D = sky.jellies[0]
	var views := []
	views.append(["01_over_the_island", Vector3(0, 6, 14), Vector3(0, 8, -40)])
	views.append(["02_planet", Vector3(0, 3, 0), Vector3(0, 3, 0) + Vector3(-0.55, 0.42, -0.72) * 100.0])
	views.append(["03_up", Vector3(0, 3, 0), Vector3(0.2, 100, -10)])
	views.append(["04_dream_island", island.global_position * 0.55 + Vector3(0, 10, 0), island.global_position])
	views.append(["05_down_below", Vector3(0, -6, 18), Vector3(0, -60, -40)])
	views.append(["06_jelly", jelly.global_position + Vector3(14, 3, 14), jelly.global_position])
	views.append(["07_wide", Vector3(70, 30, 70), Vector3(-5, 0, -8)])
	views.append(["08_moon", Vector3(0, 3, 0), Vector3(0, 3, 0) + Vector3(0.62, 0.55, 0.56) * 100.0])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	# A Warp Ring's swirl, a third of the way through
	cam.global_position = Vector3(-0.5, 2.6, -2.0)
	cam.look_at(Vector3(-6.5, 1.0, -7.0))
	sky.trip()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("09_warp_swirl.png"))
	print("SHOT 09_warp_swirl")
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
