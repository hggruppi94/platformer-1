extends SceneTree

# Screenshots of the speed coins on every circuit (scripts/race_track.gd _place_coins) and of the flow you get from a
# whole set (scripts/race_flow.gd): the same view on the Lake Loop out of the flow and in it. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_flow.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_flow_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_flow_capture_backup.cfg"

var out_dir := "user://race_flow_shots"
var cam: Camera3D
var races: Node
var p: CharacterBody3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	races = root.get_node("Races")
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	settings.tips = false
	settings.race_intros = false
	settings.minimap = false
	root.get_node("Clock").pulls_home = false
	races.reset()
	races.raced = 3

	var n := 1
	for id in ["lake_loop", "meadow_wiggle", "observatory_hill", "pumpkin_run"]:
		var tr: Dictionary = races.TRACKS[id]
		change_scene_to_file(str(tr.scene))
		await _frames(10)
		for i in 300:
			var tt: Node3D = races.track_node(id)
			if tt != null and tt.ready_to_race:
				break
			await physics_frame
		await _still()
		var t: Node3D = races.track_node(id)
		t.show_race(true)
		var life := current_scene.get_node_or_null("Life")
		if life:
			life.process_mode = Node.PROCESS_MODE_DISABLED
		# Each set from a racer's eye, a little way back down the road
		for k in t.coin_sets.size():
			var d: float = t.coin_sets[k][0].get_meta("d")
			var from: Vector3 = t.point_at(fposmod(d - 9.0, t.length))
			var look: Vector3 = t.point_at(fposmod(d + 8.0, t.length))
			await _view("%02d_%s_coins_%d" % [n, id, k + 1], from + Vector3.UP * 2.4, look + Vector3.UP * 0.8)
			n += 1

	# The flow: the same view on the Lake Loop out of it and in it (the player on the road, the camera behind)
	change_scene_to_file(str(races.TRACKS.lake_loop.scene))
	await _frames(10)
	for i in 300:
		var tt: Node3D = races.track_node("lake_loop")
		if tt != null and tt.ready_to_race:
			break
		await physics_frame
	await _still()
	var lake: Node3D = races.track_node("lake_loop")
	lake.show_race(true)
	var d0: float = lake.coin_sets[0][0].get_meta("d") + 10.0
	(p.get_node("Visual") as Node3D).visible = true
	p.global_position = lake.point_at(d0) + Vector3.UP * 0.9
	var f: Vector3 = lake.dir_at(d0)
	(p.get_node("Visual") as Node3D).rotation.y = atan2(f.x, f.z)
	var from2: Vector3 = lake.point_at(fposmod(d0 - 6.0, lake.length)) + Vector3.UP * 2.6
	var look2: Vector3 = lake.point_at(fposmod(d0 + 14.0, lake.length)) + Vector3.UP * 1.0
	await _view("%02d_flow_off" % n, from2, look2)
	n += 1
	var flow: CanvasLayer = races.flow
	flow.visible = true
	flow.start()
	await create_timer(1.6).timeout
	await _view("%02d_flow_on" % n, from2, look2)
	n += 1
	await create_timer(0.9).timeout
	await _view("%02d_flow_on_a_moment_later" % n, from2, look2)
	n += 1
	settings.reduce_motion = true
	settings.reduce_flashing = true
	await _view("%02d_flow_reduce_motion_and_flashing" % n, from2, look2)
	settings.reduce_motion = false
	settings.reduce_flashing = false
	flow.stop()
	_finish()


func _still() -> void:
	# Hide the player and the HUDs, and stop the spring arm so its camera stays where it's put
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	for l in root.find_children("*", "CanvasLayer", true, false):     # (every HUD, the race's and the minimap too)
		(l as CanvasLayer).visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	(p.get_node("Visual") as Node3D).visible = false
	var arm := p.get_node("SpringArm3D")
	cam = arm.get_node("Camera3D") as Camera3D
	cam.fov = 60
	cam.make_current()
	var hush := Node.new()                       # (the minimap stays up in a race, but waits for cutscenes)
	hush.add_to_group("cutscene_playing")
	current_scene.add_child(hush)
	await _frames(4)


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
