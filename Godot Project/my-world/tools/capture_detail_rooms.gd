extends SceneTree

# Pictures for the baked insides (24 Nov 2026, tools/build_prop_surfaces.py floorboards|floor_tiles|plaster,
# scripts/detail_props.gd inside_surface_of): a few of the Void's rooms and the palace school's floors and walls.
# With --old-props it shoots the same spots with everything the pipeline adds turned off, so the two sets make a
# before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_rooms.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_rooms_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_rooms_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_rooms_shots"
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

	# Each room is a dome round its middle: one wide view and one low look along the floor to the wall
	var rooms := ["cafe", "library", "aquarium", "my_house", "town_hall", "dashs_house"]
	var n := 1
	for room in rooms:
		await _open("res://scenes/interiors/%s.tscn" % room)
		var r := 8.0
		for mi in current_scene.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).material_override
			if m and (String(m.resource_name).begins_with("Floor ") or m.resource_name == "Decor floor") \
					and (mi as MeshInstance3D).mesh is CylinderMesh:
				r = ((mi as MeshInstance3D).mesh as CylinderMesh).top_radius - 1.0
		await _shoot([["%02d_%s" % [n, room], Vector3(r * 0.45, 2.4, r * 0.6), Vector3(-r * 0.1, 1.0, -r * 0.5)],
			["%02d_%s_close" % [n + 1, room], Vector3(r * 0.2, 1.0, r * 0.15), Vector3(-r * 0.35, 0.3, -r * 0.75)]])
		n += 2
	# The palace school: from its way in, on into the atrium
	await _open("res://scenes/school/school.tscn")
	var at := Vector3.ZERO
	var e := current_scene.find_child("Entrance", true, false) as Node3D
	if e:
		at = e.global_position
	var fwd := -e.global_basis.z if e else Vector3(0, 0, -1)
	fwd.y = 0
	fwd = fwd.normalized()
	await _shoot([["%02d_school_in" % n, at + Vector3(0, 1.8, 0), at + fwd * 10.0 + Vector3(0, 1.2, 0)],
		["%02d_school_floor" % (n + 1), at + fwd * 3.0 + Vector3(0, 1.1, 0), at + fwd * 7.0 + Vector3(1.5, 0.2, 0)]])
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
