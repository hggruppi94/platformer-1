extends SceneTree

# Pictures for the Void's baked race and skate landmarks (18 Nov 2026, tools/build_prop_void_gate.py,
# scripts/detail_props.gd): Tally's request board, the race gate's start arch, race board and Zippy's Tune-Up, and the
# Skate Park's Run Clock, by day and at night. With --old-props it shoots the same spots with everything
# the pipeline adds turned off (no detailed props, no merging, no LODs), so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_void_gate.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_void_gate_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_void_gate_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_void_gate_shots"
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
	change_scene_to_file(TOWN)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 120)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()
	var s := current_scene
	var views := []
	# Tally's request board, from the Market Square
	var rb := s.get_node("Request Board") as Node3D
	var rf := rb.global_basis.z.normalized()
	var rx := rb.global_basis.x.normalized()
	views.append(["01_request_board", rb.global_position + rf * 6.0 + rx * 1.6 + Vector3(0, 2.4, 0),
		rb.global_position + Vector3(0, 2.2, 0), 11.0])
	views.append(["02_request_board_close", rb.global_position + rf * 2.6 - rx * 1.4 + Vector3(0, 3.2, 0),
		rb.global_position + rx * 0.6 + Vector3(0, 3.0, 0), 11.0])
	views.append(["03_request_board_night", rb.global_position + rf * 6.0 + rx * 1.6 + Vector3(0, 2.4, 0),
		rb.global_position + Vector3(0, 2.2, 0), 22.0])
	# the race gate: the arch, a tower close up, the board and the Tune-Up
	var gate := s.get_node("Race Gate void") as Node3D
	var arch := gate.get_node("Start Arch") as Node3D
	var af := arch.global_basis.z.normalized()
	var ax := arch.global_basis.x.normalized()
	views.append(["04_start_arch", arch.global_position + af * 15.0 + Vector3(0, 3.5, 0),
		arch.global_position + Vector3(0, 4.0, 0), 11.0])
	views.append(["05_arch_tower", arch.global_position + af * 4.5 + ax * 9.0 + Vector3(0, 4.5, 0),
		arch.global_position + ax * 6.2 + Vector3(0, 4.8, 0), 11.0])
	var board := gate.get_node("Race Board") as Node3D
	var bf := board.global_basis.z.normalized()
	views.append(["06_race_board", board.global_position + bf * 5.0 + Vector3(0, 2.2, 0),
		board.global_position + Vector3(0, 2.1, 0), 11.0])
	var tune := gate.get_node("Tune-Up") as Node3D
	var tf := tune.global_basis.z.normalized()
	var tx := tune.global_basis.x.normalized()
	views.append(["07_tune_up", tune.global_position + tf * 4.2 + tx * 1.2 + Vector3(0, 2.0, 0),
		tune.global_position + Vector3(0, 1.4, 0), 11.0])
	views.append(["08_start_arch_night", arch.global_position + af * 15.0 + Vector3(0, 3.5, 0),
		arch.global_position + Vector3(0, 4.0, 0), 22.0])
	# the Skate Park's Run Clock
	var rc := s.find_child("Run Clock", true, false) as Node3D
	var cf := rc.global_basis.z.normalized()
	var cx := rc.global_basis.x.normalized()
	views.append(["09_run_clock", rc.global_position + cf * 4.5 + cx * 1.0 + Vector3(0, 2.6, 0),
		rc.global_position + Vector3(0, 2.6, 0), 11.0])
	views.append(["10_run_clock_close", rc.global_position + cf * 2.0 + Vector3(0, 3.2, 0),
		rc.global_position + Vector3(0, 3.1, 0), 11.0])
	views.append(["11_run_clock_night", rc.global_position + cf * 4.5 + cx * 1.0 + Vector3(0, 2.6, 0),
		rc.global_position + Vector3(0, 2.6, 0), 22.0])
	for v in views:
		clock.set_time(3, v[3] * 60.0, true)
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
