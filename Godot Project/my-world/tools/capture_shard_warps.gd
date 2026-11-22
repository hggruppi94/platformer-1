extends SceneTree

# Pictures for Shard Isle's Warp Rings (scripts/shard_warps.gd, 22 Nov 2026): the Warp Circle on the main island,
# then the view from where you land on each of the six new islands, looking the way you face, and Prism Isle's chest.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_shard_warps.gd -- <folder>
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.shard_warps_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.shard_warps_capture_backup.cfg"
const WORLD := "res://scenes/portal_worlds/shard_isle.tscn"

var out_dir := "user://shard_warps_shots"
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
	var w := s.get_node("Warps")
	w.call("_refresh")
	var views := []
	views.append(["01_warp_circle", Vector3(-0.5, 2.6, -2.0), Vector3(-6.5, 1.0, -7.0)])
	var n := 2
	for id in ["skyhook", "underside", "prism", "overlook", "drift", "perch"]:
		var land: Vector3 = w.call("landing", id)
		var look: Vector3 = w.ISLANDS[id].get("look", Vector3(0, 0, -3))
		var flat := Vector3(look.x - land.x, 0, look.z - land.z).normalized()
		views.append(["%02d_from_%s" % [n, id], land - flat * 0.8 + Vector3(0, 1.2, 0), look])
		n += 1
	var prism: Vector3 = w.ISLANDS.prism.at
	views.append(["%02d_prism_chest" % n, prism + Vector3(5.5, 3.0, 5.5), prism + Vector3(1.5, 0.6, 1.5)])
	views.append(["%02d_wide" % (n + 1), Vector3(70, 30, 70), Vector3(-5, 0, -8)])
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
