extends SceneTree

# Screenshots of the circuits' secret shortcuts, road tunnels and moving obstacles (scripts/race_circuit.gd,
# race_track.gd): on every circuit the curtain hiding the shortcut's mouth, the inside of the shortcut, and the
# tunnel over the road; on the Lake Loop the sliding bumper and the pop-up wall, and the "SECRET SHORTCUT!" shout
# mid-race. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_tracks.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_tracks_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_tracks_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://race_track_shots"
var cam: Camera3D
var races: Node
var p: CharacterBody3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
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
	for k in races.TRACKS:
		if races.TRACKS[k].has("circuit"):
			races.finished_once[k] = true

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
		var c: Node3D = current_scene
		var t: Node3D = races.track_node(id)
		var sc: Dictionary = c.shortcuts[0]
		var path: Array = sc.path
		# The mouth: from the road a little before it, the curtain in the wall on the inside of the bend
		var d0: float = float(sc.d0)
		var from: Vector3 = t.point_at(d0 - 14.0) - t.side_at(d0 - 14.0) * float(sc.inner) * 2.0 + Vector3.UP * 2.2
		await _view("%02d_%s_shortcut_curtain" % [n, id], from, path[0] + Vector3.UP * 1.4)
		n += 1
		# Inside the shortcut
		var a: Vector3 = path[int(path.size() * 0.3)]
		var b: Vector3 = path[int(path.size() * 0.5)]
		await _view("%02d_%s_inside_the_shortcut" % [n, id], a + Vector3.UP * 1.7, b + Vector3.UP * 1.3)
		n += 1
		# The tunnel over the road, from the road before it
		var tn: Array = tr.tunnels[0]
		var tl: float = t.at(float(tn[0]))
		var th: float = t.at(float(tn[1]))
		await _view("%02d_%s_road_tunnel" % [n, id], t.point_at(tl - 24.0) + Vector3.UP * 4.5,
			t.point_at((tl + th) / 2.0) + Vector3.UP * 2.0)
		n += 1
		if id == "lake_loop":
			var slider: Node3D = null
			var popup: Node3D = null
			for o in t.obstacles:
				if str(o.get_meta("kind")) == "slider":
					slider = o
				elif str(o.get_meta("kind")) == "popup":
					popup = o
			var sd: float = float(slider.get_meta("d"))
			await _view("%02d_lake_loop_sliding_bumper" % n, t.point_at(sd - 12.0) + Vector3.UP * 3.2, t.point_at(sd) + Vector3.UP * 0.8, 2)
			n += 1
			var pd: float = float(popup.get_meta("d", t.at(12.2)))
			for i in 600:
				if t.pop_warning(popup):
					break
				await physics_frame
			await _view("%02d_lake_loop_popup_wall_warning" % n, t.point_at(pd - 11.0) + Vector3.UP * 3.0, t.point_at(pd) + Vector3.UP * 0.6, 2)
			n += 1
			for i in 600:
				if t.pop_up(popup) and (popup.get_node("Wall") as Node3D).position.y > -0.05:
					break
				await physics_frame
			await _view("%02d_lake_loop_popup_wall_up" % n, t.point_at(pd - 11.0) + Vector3.UP * 3.0, t.point_at(pd) + Vector3.UP * 0.6, 1)
			n += 1
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
