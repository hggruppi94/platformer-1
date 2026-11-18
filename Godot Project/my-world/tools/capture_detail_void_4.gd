extends SceneTree

# Pictures for the Void's baked Tree House, Rex and Dash's lab, the Wishing Well and a Remnant vein (18 Nov 2026,
# tools/build_prop_void_4.py, scripts/detail_props.gd), by day and at night. With --old-props it shoots the same spots
# with everything the pipeline adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_void_4.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_void_4_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_void_4_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_void_4_shots"
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
	# the Tree House, from round about and up on its deck
	var th := s.get_node("Tree House") as Node3D
	var tp := th.global_position
	views.append(["01_tree_house", tp + Vector3(13, 6, 13), tp + Vector3(0, 6.5, 0), 11.0])
	views.append(["02_tree_house_side", tp + Vector3(-15, 8, 6), tp + Vector3(0, 7.5, 0), 11.0])
	views.append(["03_tree_house_deck", tp + Vector3(3.5, 9.2, 3.5), tp + Vector3(-1.2, 8.2, -1.2), 11.0])
	views.append(["04_tree_house_night", tp + Vector3(13, 6, 13), tp + Vector3(0, 6.5, 0), 22.0])
	# Rex and Dash's lab, from its open front
	var lab := s.get_node("Rex and Dash's Lab") as Node3D
	var lf := lab.global_basis.z.normalized()
	var lx := lab.global_basis.x.normalized()
	views.append(["05_lab", lab.global_position + lf * 11.0 + lx * 3.0 + Vector3(0, 3.5, 0),
		lab.global_position + Vector3(0, 1.8, 0), 11.0])
	views.append(["06_lab_inside", lab.global_position + lf * 3.5 + Vector3(0, 2.2, 0),
		lab.global_position - lf * 1.5 + Vector3(0, 1.4, 0), 11.0])
	views.append(["07_lab_night", lab.global_position + lf * 11.0 + lx * 3.0 + Vector3(0, 3.5, 0),
		lab.global_position + Vector3(0, 1.8, 0), 22.0])
	# the Wishing Well
	var well := s.find_child("The Wishing Well", true, false) as Node3D
	var wp := well.global_position
	views.append(["08_wishing_well", wp + Vector3(4.5, 3.0, 4.5), wp + Vector3(0, -0.5, 0), 11.0])
	views.append(["09_wishing_well_down", wp + Vector3(0.6, 4.0, 0.6), wp + Vector3(0, -3.0, 0), 11.0])
	# a Remnant vein, by day and night
	var vein := s.find_child("Vein lake_shore", true, false) as Node3D
	var vp := vein.global_position
	views.append(["10_vein", vp + Vector3(3.5, 2.0, 3.5), vp + Vector3(0, 0.8, 0), 11.0])
	views.append(["11_vein_night", vp + Vector3(3.5, 2.0, 3.5), vp + Vector3(0, 0.8, 0), 22.0])
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
