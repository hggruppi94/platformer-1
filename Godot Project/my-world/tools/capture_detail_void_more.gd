extends SceneTree

# Pictures for more of the Void's baked props (18 Nov 2026, tools/build_prop_void_more.py, scripts/detail_props.gd):
# the Goblin Clockyard's grandfather clocks and cogs, Boulder Hollow, an ammo crate, and Dash's gadget stall and
# workbench, by day and at night. With --old-props it shoots the same spots with everything
# the pipeline adds turned off (no detailed props, no merging, no LODs), so the two sets make a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_void_more.gd -- <folder> [--old-props]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_void_more_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_void_more_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://detail_void_more_shots"
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
	# the clockyard: the ring of clocks, one close up, and at night (their faces glow)
	var yard := s.get_node("Goblin Clockyard") as Node3D
	var yp := yard.global_position
	views.append(["01_clockyard", yp + Vector3(9.0, 5.0, 11.0), yp + Vector3(0, 1.2, 0), 11.0])
	var c0 := yard.get_node("Clock 0") as Node3D
	var cf := c0.global_basis.z.normalized()
	views.append(["02_clock", c0.global_position + cf * 3.2 + Vector3(0, 2.0, 0) + c0.global_basis.x * 0.8,
		c0.global_position + c0.global_basis.y * 1.6, 11.0])
	views.append(["03_clock_face", c0.global_position + c0.global_basis.y * 2.3 + cf * 1.5,
		c0.global_position + c0.global_basis.y * 2.2, 11.0])
	views.append(["04_clockyard_night", yp + Vector3(9.0, 5.0, 11.0), yp + Vector3(0, 1.2, 0), 22.0])
	# a cog in the grass
	var cog := Vector3.ZERO
	for c in yard.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			cog = (c as MeshInstance3D).global_position
			break
	views.append(["05_cog", cog + Vector3(1.4, 1.2, 1.6), cog, 11.0])
	# Boulder Hollow
	var hollow := s.get_node("Boulder Hollow") as Node3D
	var hp := hollow.global_position
	views.append(["06_boulder_hollow", hp + Vector3(0, 9.0, 24.0), hp + Vector3(0, 1.0, 0), 11.0])
	var b0 := hollow.get_node("Boulder 0") as Node3D
	var out := (b0.global_position - hp).normalized()
	out.y = 0
	views.append(["07_boulder", b0.global_position + out.normalized() * 5.5 + Vector3(0, 1.8, 0) + Vector3(out.z, 0, -out.x) * 2.0,
		b0.global_position, 11.0])
	# an ammo crate
	var crate := s.get_node("Ammo Crate 1") as Node3D
	views.append(["08_ammo_crate", crate.global_position + Vector3(1.6, 1.3, 1.9), crate.global_position + Vector3(0, 0.5, 0),
		11.0])
	# Dash's stall and workbench, from the front
	var st := s.get_node("Gadget Stall") as Node3D
	var sf := st.global_basis.z.normalized()
	var sx := st.global_basis.x.normalized()
	views.append(["09_gadget_stall", st.global_position + sf * 6.0 + sx * 1.5 + Vector3(0, 2.2, 0),
		st.global_position + sx * 1.2 + Vector3(0, 1.4, 0), 11.0])
	views.append(["10_workbench", st.global_position + sf * 2.6 + sx * 4.2 + Vector3(0, 1.6, 0),
		st.global_position + sx * 4.5 + Vector3(0, 1.3, 0), 11.0])
	views.append(["11_gadget_stall_night", st.global_position + sf * 6.0 + sx * 1.5 + Vector3(0, 2.2, 0),
		st.global_position + sx * 1.2 + Vector3(0, 1.4, 0), 22.0])
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
