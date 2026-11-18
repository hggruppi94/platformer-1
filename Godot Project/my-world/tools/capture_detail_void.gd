extends SceneTree

# Pictures for the Void's batch of baked props (18 Nov 2026, tools/build_prop_void.py, scripts/detail_props.gd
# dress_void): the glowing crystal clusters, the sailboats on the lake, the dome doors, the antique car and the
# picnic baskets in the South Meadow, by day and at night. With --old-props it shoots the same spots with everything
# the pipeline adds turned off (no detailed props, no merging, no LODs), so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_void.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_void_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_void_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_void_shots"
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
	# a crystal cluster: the one with the most shards, looked at from its south-east
	var best: Node3D = null
	for c in s.get_node("Crystals").get_children():
		if c is Node3D and not (c is MultiMeshInstance3D):
			if best == null or c.get_child_count() > best.get_child_count():
				best = c
	var cp := best.global_position
	views.append(["01_crystals", cp + Vector3(4.5, 2.6, 5.5), cp + Vector3(0, 1.6, 0), 11.0])
	views.append(["02_crystals_close", cp + Vector3(2.2, 1.8, 2.6), cp + Vector3(0, 1.4, 0), 11.0])
	views.append(["03_crystals_night", cp + Vector3(4.5, 2.6, 5.5), cp + Vector3(0, 1.6, 0), 22.0])
	# the sailboats: the first one up close, then the lake
	var boats := s.get_node("Sailboats")
	var b0 := (boats.get_child(0) as Node3D).global_position
	views.append(["04_sailboat", b0 + Vector3(3.5, 2.0, 4.0), b0 + Vector3(0, 1.2, 0), 11.0])
	views.append(["05_lake", Vector3(0, 9, 30), Vector3(0, 0, -8), 11.0])
	# a dome door: the Library's (or whichever comes first), from in front
	var door: MeshInstance3D = null
	for n in s.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(1.8, 2.6, 0.6)) \
				and mi.material_override and mi.material_override.resource_name == "Door":
			if door == null or String(mi.get_parent().name) == "Library":
				door = mi
	var front := door.global_basis.z.normalized()
	var dp := door.global_position
	views.append(["06_dome_door", dp + front * 5.0 + Vector3(0, 0.6, 0) + door.global_basis.x * 1.2, dp, 11.0])
	views.append(["07_dome_door_close", dp + front * 2.6 + Vector3(0, 0.2, 0), dp + Vector3(0, -0.1, 0), 11.0])
	# the car and the picnic
	var car := (s.get_node("Antique Car") as Node3D)
	var fwd := car.global_basis.z.normalized()
	var side := car.global_basis.x.normalized()
	views.append(["08_antique_car", car.global_position + fwd * 5.0 + side * 3.2 + Vector3(0, 2.4, 0),
		car.global_position + Vector3(0, 1.1, 0), 11.0])
	views.append(["09_antique_car_back", car.global_position - fwd * 5.0 - side * 3.0 + Vector3(0, 2.2, 0),
		car.global_position + Vector3(0, 1.1, 0), 15.0])
	var basket := Vector3.ZERO
	for c in s.get_node("South Meadow").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override \
				and (c as MeshInstance3D).material_override.resource_name == "Picnic Basket":
			basket = (c as MeshInstance3D).global_position
			break
	views.append(["10_picnic", basket + Vector3(1.3, 1.1, 1.5), basket, 11.0])
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
