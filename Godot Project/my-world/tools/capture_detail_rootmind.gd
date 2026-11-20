extends SceneTree

# Pictures for the Rootmind's baked props: the giant stems and their leaves round the edge, the Leaf Climb, the Root
# Tunnel's arches and the giant flowers, shut and open (20 Nov 2026, tools/build_prop_rootmind.py,
# scripts/detail_props.gd dress_rootmind()). With --old-props it shoots the same spots with everything the pipeline
# adds turned off, so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_rootmind.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_rootmind_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_rootmind_capture_backup.cfg"
const WORLD := "res://scenes/portal_worlds/rootmind.tscn"

var out_dir := "user://detail_rootmind_shots"
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
		player.global_position = Vector3(0, 2, 38)              # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	# The stems and flowers stand where the builder's dice put them, so the shots look for them
	var stem := Vector3(40, 0, 0)
	var stem_h := 22.0
	for c in s.find_child("Giant Stems", true, false).get_children():
		if c is MeshInstance3D and c.mesh is CylinderMesh:
			stem = Vector3(c.position.x, 0, c.position.z)
			stem_h = (c.mesh as CylinderMesh).height
			break
	var inward := -stem.normalized()
	var flower := s.find_child("Giant Buds", true, false).get_child(0) as Node3D
	var fp := Vector3(flower.position.x, 0, flower.position.z)
	var fin := -fp.normalized()
	var views := []
	views.append(["01_edge_stems", stem + inward * 26.0 + Vector3(0, 5, 0), stem + Vector3(0, 10, 0)])
	views.append(["02_stem_close", stem + inward * 6.0 + Vector3(0, 2.5, 0), stem + Vector3(0, 4.5, 0)])
	views.append(["03_leaf_overhead", stem + inward * 9.0 + Vector3(0, 3, 0), stem * 0.86 + Vector3(0, stem_h - 1.0, 0)])
	views.append(["04_leaf_climb", Vector3(-24, 0, -6) + Vector3(13, 7, 11), Vector3(-24, 7, -6)])
	views.append(["05_step_leaves", Vector3(-24, 0, -6) + Vector3(6, 6, 6), Vector3(-24, 4, -6)])
	views.append(["06_root_tunnel", Vector3(0, 1.7, -11), Vector3(0, 1.6, -24)])
	views.append(["07_flower_bud", fp + fin * 9.0 + Vector3(0, 6, 0), fp + Vector3(0, 7.5, 0)])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	# The same flower open, as it is once the Rootmind is mended
	for f in s.find_child("Giant Buds", true, false).get_children():
		(f.get_node("Bud") as Node3D).visible = false
		(f.get_node("Open") as Node3D).visible = true
	views = []
	views.append(["08_flower_open", fp + fin * 9.0 + Vector3(0, 8, 0), fp + Vector3(0, 7.5, 0)])
	views.append(["09_clearing_wide", Vector3(-30, 24, 34), Vector3(5, 2, -6)])
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
