extends SceneTree

# Pictures of the small new places' baked look (25 Nov 2026, scripts/detail_props.gd dress_place and the cave kit's
# rock): the Undergardens, the Museum Garden's exhibits, Old Ember's chamber, the Knitting Class and a virtue trial.
# Opens a window (not --headless). --old-props takes them with the detail pipeline off, to compare:
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_places_detail.gd -- <output folder> [--old-props]
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.places_detail_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.places_detail_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SPRINGS := "res://scenes/portal_worlds/rhythm_springs.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const TRIAL := "res://scenes/bosses/virtue_trial.tscn"

var out_dir := "user://places_detail_shots"
var cam: Camera3D
var player: CharacterBody3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not str(args[0]).begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	root.get_node("Settings").tips = false
	if "--old-props" in OS.get_cmdline_user_args():
		root.get_node("WorldDetail").set("detail_props", false)
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	var portals := root.get_node("Portals")
	portals.home_calls.enabled = false
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	# Every other world has had its quake too, so no crack cutscene plays over the pictures.
	for w in ["glenmoor", "tide_reef", "far_future"]:
		portals.quakes.append(w)
	# The Undergardens, lit by the player's glow (the camera sits near them)
	await _go(TOWN)
	player = get_first_node_in_group("player") as CharacterBody3D
	for s in [["01_undergardens_root_hall", Vector3(-80.0, 3.9, -48.0), Vector3(-75.0, 6.0, -46.0), Vector3(-83.0, 5.5, -52.0)],
			["02_undergardens_root_steps", Vector3(-96.0, 3.9, -44.2), Vector3(-95.0, 6.5, -42.0), Vector3(-97.5, 6.5, -47.5)],
			["03_undergardens_old_taproot", Vector3(-89.0, 3.9, -36.0), Vector3(-89.5, 6.0, -34.5), Vector3(-95.5, 5.0, -37.0)]]:
		_put(s[1])
		await _settle()
		_look(s[2], s[3])
		await _frames(40)
		await _shot(s[0])
	# The Museum Garden's exhibits, each from the walk
	var mg := current_scene.find_child("Museum Grounds", true, false) as Node3D
	if mg:
		var i := 4
		for e in mg.get_children():
			if not e is Node3D or not e.has_meta("exhibit") or i > 6:
				continue
			var at := (e as Node3D).global_position
			var front := (e as Node3D).global_basis.z.normalized()
			_put(at + front * 6.0 + Vector3(0, 1, 0))
			await _settle()
			_look(at + front * 5.0 + (e as Node3D).global_basis.x * 1.5 + Vector3(0, 2.4, 0), at + Vector3(0, 0.8, 0))
			await _frames(30)
			await _shot("%02d_museum_%s" % [i, str(e.get_meta("exhibit"))])
			i += 1
	# Old Ember's chamber
	await _go(SPRINGS)
	player = get_first_node_in_group("player") as CharacterBody3D
	var depths := current_scene.get_node_or_null("Volcano Depths")
	if depths:
		var c: Vector3 = depths.mark("chamber")
		_put(c + Vector3(3, 1, 3))
		await _settle()
		_look(c + Vector3(9, 4.5, 9), c)
		await _frames(40)
		await _shot("10_old_embers_chamber")
		var hall: Vector3 = depths.mark("hall")
		_put(hall + Vector3(0, 1, 0))
		await _settle()
		_look(hall + Vector3(2.5, 1.8, 2.5), hall + Vector3(-2, 0.5, -2))
		await _frames(40)
		await _shot("11_ember_hall")
	# The Knitting Class
	await _go(SCHOOL)
	var room := current_scene.get_node_or_null("Floor 2/Knitting Class") as Node3D
	if room:
		var kc := root.get_node("Watches/KnittingClass")
		var mid: Vector2 = (kc.ROOM_MIN + kc.ROOM_MAX) / 2
		var mid3 := room.to_global(Vector3(mid.x, 0, mid.y))
		_look(mid3 + Vector3(3.5, 2.6, 4.0), mid3 + Vector3(0, 0.6, 0))
		await _frames(40)
		await _shot("12_knitting_class")
		_look(mid3 + Vector3(1.4, 1.5, 1.8), mid3 + Vector3(-0.5, 0.6, -1.0))
		await _frames(20)
		await _shot("13_knitting_class_close")
	# A virtue trial
	root.get_node("Bosses").set_meta("virtue_trial", {"id": "humility", "stone": 0, "pos": Vector3.ZERO, "yaw": 0.0, "held": 0})
	await _go(TRIAL)
	_look(Vector3(6, 4, 12), Vector3(0, 0, 0))
	await _frames(40)
	await _shot("14_virtue_trial_landing")
	_look(Vector3(2.5, 1.6, 6), Vector3(-1, 0, 1))
	await _frames(20)
	await _shot("15_virtue_trial_marble_close")
	root.get_node("Bosses").remove_meta("virtue_trial")
	_finish()


func _put(at: Vector3) -> void:
	if player and is_instance_valid(player):
		player.global_position = at
		player.velocity = Vector3.ZERO


func _settle() -> void:
	for i in 10:
		await physics_frame
	await _frames(30)


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 40:
		await process_frame
	await create_timer(1.5).timeout
	cam = null


func _cam_in() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	if cam == null or not is_instance_valid(cam):
		_cam_in()
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	# The pictures are of the places, so the HUD is put out of the way.
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
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
