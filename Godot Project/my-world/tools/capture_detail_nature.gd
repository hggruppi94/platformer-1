extends SceneTree

# Pictures for the baked trees and plants (19 Nov 2026, tools/build_prop_nature.py, scripts/detail_props.gd
# dress_nature): the Void's orb, spire and parasol trees, its giant leaves and mushrooms, and Stars Hollow's autumn
# trees. With --old-props it shoots the same spots with everything the pipeline adds turned off, so the two sets make
# a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_nature.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_nature_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_nature_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_nature_shots"
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

	await _open(TOWN)
	var trees := current_scene.get_node("Trees")
	var plants := current_scene.get_node("Foliage")
	var views := []
	var seen := {}
	# One of each kind of tree, a middling one, not one that wasn't grown
	for i in trees.positions.size():
		var k: int = trees.kinds[i]
		if seen.has(k) or i in trees.left_out or trees.sizes[i] < 1.4:
			continue
		seen[k] = true
		var p: Vector3 = trees.positions[i]
		var s: float = trees.sizes[i]
		var name: String = ["orb", "spire", "parasol"][k]
		views.append(["0%d_void_%s_tree" % [k + 1, name], p + Vector3(s * 3.2, s * 2.2 + 2.0, s * 3.2),
			p + Vector3(0, s * 1.4 + 1.5, 0)])
		views.append(["0%d_void_%s_close" % [k + 4, name], p + Vector3(s * 1.4, s * 1.6 + 2.5, s * 1.4),
			p + Vector3(0, s * 1.6 + 2.0, 0)])
	var leaf_done := false
	var mush_done := false
	for i in plants.positions.size():
		var p: Vector3 = plants.positions[i]
		var s: float = plants.sizes[i]
		if plants.kinds[i] == 0 and not leaf_done and s > 1.2:          # LEAVES
			leaf_done = true
			views.append(["07_giant_leaves", p + Vector3(s * 1.6, s * 1.4, s * 1.6), p + Vector3(0, s * 0.5, 0)])
		elif plants.kinds[i] == 2 and not mush_done and s > 2.4:        # MUSHROOM
			mush_done = true
			views.append(["08_mushroom", p + Vector3(s * 1.1, s * 1.0, s * 1.1), p + Vector3(0, s * 0.8, 0)])
			views.append(["09_mushroom_under", p + Vector3(s * 0.7, s * 0.45, s * 0.7), p + Vector3(0, s * 0.95, 0)])
	views.append(["10_void_woods", Vector3(-95, 9, -95), Vector3(-110, 3, -125)])
	await _shoot(views)

	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	await _open(EARTH)
	var trunks := current_scene.get_node("Autumn Trees/Tree Trunk")
	var xf: PackedFloat32Array = trunks.transforms
	views = []
	for n in [10, 40, 120]:
		var at := Vector3(xf[n * 12 + 9], xf[n * 12 + 10], xf[n * 12 + 11])
		var h := xf[n * 12 + 4]
		var dir := Vector3(1, 0, 0.6).normalized()
		views.append(["%d_earth_tree_%d" % [11 + views.size(), n], at + dir * 7.5 + Vector3(0, h * 0.3, 0),
			at + Vector3(0, h * 0.25, 0)])
	views.append(["14_earth_trunk_close", Vector3(xf[40 * 12 + 9], xf[40 * 12 + 10] - xf[40 * 12 + 4] * 0.5 + 1.2, xf[40 * 12 + 11]) + Vector3(1.6, 0, 1.0),
		Vector3(xf[40 * 12 + 9], xf[40 * 12 + 10] - xf[40 * 12 + 4] * 0.5 + 0.8, xf[40 * 12 + 11])])
	views.append(["15_earth_green", Vector3(0, 9, 34), Vector3(0, 3, 0)])
	await _shoot(views)
	_finish()


func _open(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 160)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()


func _shoot(views: Array) -> void:
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])


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
