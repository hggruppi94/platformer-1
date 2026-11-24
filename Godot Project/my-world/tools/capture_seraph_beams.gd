extends SceneTree

# Frames of the Seraph's beams of light from the sky (24 Nov 2026, scripts/starhorn.gd _beam, the pixel-art light in
# scripts/sky_light_fx.gd): a row of beams pouring down across the summit one after another, each with its splash,
# as numbered frames (frame_000.png...) to make into a GIF, plus a few stills.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_seraph_beams.gd -- <folder>
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.seraph_beams_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.seraph_beams_capture_backup.cfg"
const WORLD := "res://scenes/bosses/skyreach_trail.tscn"

var out_dir := "user://seraph_beams_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Clock").set("pulls_home", false)
	if "--old-props" in OS.get_cmdline_user_args():
		root.get_node("WorldDetail").detail_props = false
	change_scene_to_file(WORLD)
	for i in 30:
		await process_frame
	await create_timer(2.0).timeout
	var s := current_scene as Node3D
	var top: Vector3 = s.call("summit")
	var p := s.find_child("Player", true, false) as Node3D
	p.global_position = top + Vector3(3.0, 1.0, 11.0)
	p.set("_invulnerable_timer", 999.0)          # (no fainting mid-pictures)
	await create_timer(3.0).timeout
	var boss := s.get_node("The Starhorn") as Node3D
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var here := top + Vector3(0, 1.0, 9.0)
	boss.global_position = top
	p.global_position = here
	# Its second phase: a row of beams from in front of it, on past where you stand
	boss.set_physics_process(false)
	# Awake but standing still: a sleeping Seraph's beams fade away instead of striking.
	boss.set("state", boss.get_script().State.IDLE)
	var lead0: float = (load("res://scripts/boss_tell.gd") as GDScript).lead()
	# The row is called down straight from its beam maker, so nothing else it might be doing gets in the way of the shot.
	for i in 5:
		var at := top + Vector3(1.0, 0, 1.0).normalized() * (4.0 + 2.8 * i)
		boss.call("_beam", at, lead0, 0.22 * i)
	_view(top + Vector3(-4.0, 5.0, 24.0), top + Vector3(7.0, 5.0, 6.0))
	# Saving a frame is slow without a real screen, so the game runs slowed right down while recording: each frame is
	# then only a twentieth of a second of fight, and the GIF plays smoothly at normal speed.
	Engine.time_scale = 0.25
	var t0 := Time.get_ticks_msec()
	var n := 0
	var game_s := 0.0
	var next_shot := 0.0
	while game_s < 4.2:
		await process_frame
		game_s += boss.get_process_delta_time()
		if game_s < next_shot:
			continue
		next_shot += 0.05
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("frame_%03d.png" % n))
		n += 1
	Engine.time_scale = 1.0
	print("FRAMES ", n, " in ", Time.get_ticks_msec() - t0, " ms")
	# A still of one beam striking close up
	boss.set("phase", 0)
	boss.set("state", boss.get_script().State.IDLE)
	boss.set("_move_i", 1)
	boss.call("_start_move")
	var lead: float = (load("res://scripts/boss_tell.gd") as GDScript).lead()
	_view(here + Vector3(7.0, 3.0, 7.0), here + Vector3(0, 3.0, 0))
	await _shot("still_thread")
	await create_timer(lead - 0.25).timeout
	await _shot("still_strike")
	_finish()


func _view(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _shot(file: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
