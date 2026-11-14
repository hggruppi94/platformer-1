extends SceneTree

# Screenshots of the things going on round the race circuits (scripts/race_life.gd): every set piece on every
# circuit caught going off, seen from the road just before it, and the crowd cheering in the stand with the blimp
# overhead. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_life.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_life_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_life_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://race_life_shots"
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


# How long after going off each one looks its best
const WAIT := {"leaper": 0.8, "geysers": 0.55, "saucers": 1.1, "crystals": 0.7, "bloom": 1.3, "moths": 1.2,
	"balloons": 2.2, "meteors": 1.0, "boulder": 1.4, "crows": 0.9, "hayburst": 0.6, "hot_air": 3.0, "fireworks": 1.6}


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
		var c: Node3D = current_scene
		var life: Node3D = c.get_node("Life")
		life.process_mode = Node.PROCESS_MODE_DISABLED      # (the shots fire them themselves)
		for s in life.sets:
			var d: float = float(s.get_meta("d"))
			var kind := str(s.get_meta("kind"))
			var from: Vector3 = c.line[c.index_at(fposmod(d - 30.0, c.total))] + Vector3.UP * 3.0
			var look: Vector3 = c.line[c.index_at(fposmod(d + 4.0, c.total))] + Vector3.UP * (9.0 if kind in ["saucers", "balloons", "hot_air", "fireworks", "meteors", "crows", "leaper"] else 2.5)
			cam.global_position = from
			cam.look_at(look)
			life.process_mode = Node.PROCESS_MODE_INHERIT
			life.fire(s)
			await create_timer(float(WAIT.get(kind, 1.0))).timeout
			life.process_mode = Node.PROCESS_MODE_DISABLED
			# Look at whatever's going on (the middle of everything shown in that set piece just now)
			var mid := Vector3.ZERO
			var count := 0
			for m in s.find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).is_visible_in_tree():
					mid += (m as Node3D).global_position
					count += 1
			if count > 0:
				cam.look_at(mid / count)
			await _shot("%02d_%s_%s" % [n, id, kind], 1)
			life.process_mode = Node.PROCESS_MODE_INHERIT
			await create_timer(4.0).timeout
			life.process_mode = Node.PROCESS_MODE_DISABLED
			n += 1
		# The crowd on its feet, and the blimp
		var stand := c.get_node("Stand") as Node3D
		life.cheering = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.global_position = stand.global_position + stand.global_basis.z * 14.0
		p.process_mode = Node.PROCESS_MODE_DISABLED
		life.process_mode = Node.PROCESS_MODE_INHERIT
		cam.global_position = stand.global_position + stand.global_basis.z * 26.0 + Vector3.UP * 7.0
		cam.look_at(stand.global_position + Vector3.UP * 6.0)
		await create_timer(0.7).timeout
		await _shot("%02d_%s_crowd_and_blimp" % [n, id], 1)
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
