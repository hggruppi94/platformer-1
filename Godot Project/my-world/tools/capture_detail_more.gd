extends SceneTree

# Pictures for the second batch of baked props (16 Nov 2026, "give everything the baked in details"): Stars Hollow's
# pumpkin patch with its scarecrows, a Maple Lane porch with its jack-o'-lanterns and mailbox (by day and at dusk),
# and the Void's sign posts. With --old-props the same spots with the whole pipeline turned off, for a before and
# after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_more.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_more_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_more_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_more_shots"
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
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	# Stars Hollow, in autumn (a new game's season)
	clock.set_earth_time(11 * 60.0, true)
	await _load(EARTH)
	var patch := current_scene.find_child("Pumpkin Patch", true, false) as Node3D
	if patch:
		await _view("01_pumpkin_patch", patch, Vector3(-2, 2.6, 11), Vector3(0, 0.6, 0))
		await _view("02_pumpkin_close", patch, Vector3(-4.5, 1.3, 3.2), Vector3(-3.0, 0.9, 0.3))
	var house := current_scene.find_child("Maple House 1", true, false) as Node3D
	if house:
		await _view("03_porch", house, Vector3(3.5, 1.8, 12.0), Vector3(0, 1.0, 4.5))
		await _view("04_mailbox", house, Vector3(2.8, 1.5, 9.4), Vector3(1.5, 1.2, 7.7))
		clock.set_earth_time(19 * 60.0 + 30, true)
		await create_timer(0.5).timeout
		await _view("05_porch_dusk", house, Vector3(3.5, 1.8, 12.0), Vector3(0, 1.0, 4.5))
	# The Void
	clock.set_time(3, 11 * 60.0, true)
	await _load(TOWN)
	var i := 6
	for text in ["Market Square", "Welcome to the Void", "Skate Park"]:
		var s := _sign(text)
		if s:
			await _view("%02d_sign_%s" % [i, text.to_lower().replace(" ", "_")], s, Vector3(1.4, 2.2, 5.0),
				Vector3(0, 1.8, 0))
			i += 1
	_finish()


func _load(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position += Vector3(0, -200, 0)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()


func _sign(text: String) -> Node3D:
	for l in current_scene.find_children("*", "Label3D", true, false):
		if (l as Label3D).text == text and String(l.get_parent().name).begins_with("Sign"):
			return l.get_parent() as Node3D
	return null


func _view(file: String, at: Node3D, from: Vector3, look: Vector3) -> void:
	cam.global_position = at.global_transform * from
	cam.look_at(at.global_transform * look)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	for pair in [[BACKUP, SAVE], [SETTINGS_BACKUP, SETTINGS]]:
		if FileAccess.file_exists(pair[0]):
			DirAccess.copy_absolute(pair[0], pair[1])
			DirAccess.remove_absolute(pair[0])
		else:
			DirAccess.remove_absolute(pair[1])
	quit()
