extends SceneTree

# Screenshots of the sunken secrets (scripts/sunken_secrets.gd): the Void's Wishing Well by the Portal Plaza, diving
# down to the secrets on its bottom, one read out, the deep pool in each portal world, and Willow Pond's secrets.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_sunken_secrets.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.sunken_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.sunken_capture_backup.cfg"

var out_dir := "user://sunken_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var sunken: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1500.0, true, false, true).timeout.connect(_finish)
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
	portals = root.get_node("Portals")
	sunken = root.get_node("Watches/Sunken")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
		portals.note_found(w, "swim_taught")
	# The Void's Wishing Well, from outside
	await _go("res://scenes/town/town.tscn")
	var well := current_scene.find_child("The Wishing Well", true, false) as Node3D
	_cam_in(current_scene)
	_look(well.global_position + Vector3(-9, 6, 8), well.global_position + Vector3(0, 2, 0))
	await _frames(20)
	await _shot("01_the_wishing_well_by_the_portal_plaza")
	_look(well.global_position + Vector3(0, 9, 1.5), well.global_position)
	await _frames(10)
	await _shot("02_looking_down_into_it")
	# Diving down to the bottom (the player's own camera)
	cam.queue_free()
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var top: float = float(well.get_node("Water").get("water_y"))
	player.global_position = well.global_position + Vector3(-1.2, top - 0.5, 1.2)
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("dash")
	for i in 40:
		await physics_frame
	Input.action_release("dash")
	await _frames(40)
	await _shot("03_diving_down_to_the_secrets")
	var pick := current_scene.find_child("Secret piece_nameplate", true, false) as Node3D
	if pick:
		player.global_position = pick.global_position + Vector3(0, -0.4, 0.5)
		player.velocity = Vector3.ZERO
		for i in 30:
			await physics_frame
		var d := root.get_node("Dialogue")
		await _frames(10)
		d._finish_typing()
		await _frames(10)
		await _shot("04_a_piece_of_that_night_read_out")
		for i in 2:
			d._next()
			await _frames(6)
			d._finish_typing()
		await _frames(10)
		await _shot("05_its_echo")
		d.end()
	# Each portal world's pool
	var n := 6
	for key in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		var p: Dictionary = sunken.POOLS[key]
		await _go(p.scene)
		var pool := current_scene.find_child(str(p.name), true, false) as Node3D
		_cam_in(current_scene)
		_look(pool.global_position + Vector3(8, 6, 8), pool.global_position + Vector3(0, 2, 0))
		await _frames(30)
		await _shot("%02d_%s" % [n, str(p.name).to_lower().replace(" ", "_")])
		n += 1
	# Willow Pond's three, from under the water
	await _go("res://scenes/earth/earth.tscn")
	player = current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	player.global_position = Vector3(-84, EarthLand.WATER_Y - 0.5, 4)
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("dash")
	for i in 45:
		await physics_frame
	Input.action_release("dash")
	await _frames(40)
	await _shot("%02d_willow_ponds_secrets" % n)
	_finish()


func _go(path: String) -> void:
	change_scene_to_file(path)
	for i in 30:
		await process_frame
	await create_timer(1.0).timeout


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
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
