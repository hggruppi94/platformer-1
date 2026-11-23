extends SceneTree

# Pictures for the Star Arena's baked props: the low wall and its trim, the stands' steps and seats, the spotlight
# towers, the hatches, the way-in tunnel, Blip's podium and the Round Board (23 Nov 2026,
# tools/build_prop_star_arena.py, scripts/detail_props.gd dress_star_arena()). With --old-props it shoots the same
# spots with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_star_arena.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_star_arena_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_star_arena_capture_backup.cfg"
const WORLD := "res://scenes/bosses/arena.tscn"

var out_dir := "user://detail_star_arena_shots"
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
		player.global_position = Vector3(0, 0.5, 0)             # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var views := []
	views.append(["01_wide", Vector3(0, 14, -20), Vector3(0, 3, 22)])
	views.append(["02_stands", Vector3(-8, 2.5, -10), Vector3(-26, 3.5, -22)])
	views.append(["03_stands_close", Vector3(-17, 3, -14), Vector3(-23, 3, -19)])
	views.append(["04_wall", Vector3(8, 1.6, -14), Vector3(18, 0.8, -17)])
	views.append(["05_tower", Vector3(14, 6, -14), Vector3(26.5, 11, -26.5)])
	views.append(["06_tower_top", Vector3(20, 18, -20), Vector3(26.5, 16, -26.5)])
	views.append(["07_tunnel", Vector3(0, 2.5, 14), Vector3(0, 2.5, 30)])
	views.append(["08_tunnel_inside", Vector3(0, 1.8, 37), Vector3(0, 2.2, 26)])
	views.append(["09_board_blip", Vector3(0, 2.4, 14.5), Vector3(0, 1.6, 21)])
	views.append(["10_hatch", Vector3(3, 3, -8), Vector3(8.5, 0, -14.7)])
	views.append(["11_overhead", Vector3(40, 40, 40), Vector3(0, 0, 0)])
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
