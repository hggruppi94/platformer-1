extends SceneTree

# Screenshots of the Undergardens, the caves under the Secret Gardens hill (scripts/garden_caves.gd): the Rootwell
# tangled shut and then open, looking down it, each cave in Pip's glow, the Old Taproot asleep and awake, and
# Glowcaps glowing in the garden at night. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_garden_caves.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.garden_caves_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.garden_caves_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://garden_caves_shots"
var cam: Camera3D
var player: CharacterBody3D
var _had_save := false
var caves: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
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
	caves = root.get_node("Farm/Caves")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	var portals := root.get_node("Portals")
	var mouth := Vector3(caves.MOUTH.x, 12.0, caves.MOUTH.y)
	# Tangled shut
	await _go()
	_cam_in()
	_look(mouth + Vector3(7, 4.5, 6), mouth)
	await _frames(20)
	await _shot("01_the_rootwell_tangled_shut")
	# Open, once Pip's glow is yours
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _go()
	_cam_in()
	_look(mouth + Vector3(7, 4.5, 6), mouth)
	await _frames(20)
	await _shot("02_the_rootwell_open")
	_look(mouth + Vector3(9, 6, -12), mouth + Vector3(14, -1, 0))
	await _frames(10)
	await _shot("03_on_the_hill_by_the_greenhouse")
	# Inside, by the player's glow: the camera sits near them so the glow lights what it sees
	var shots := [
		["04_down_the_root_steps", Vector3(-96.0, 3.9, -44.2), Vector3(-95.0, 6.5, -42.0), Vector3(-97.5, 6.5, -47.5)],
		["05_the_root_hall", Vector3(-80.0, 3.9, -48.0), Vector3(-75.0, 6.0, -46.0), Vector3(-83.0, 5.5, -52.0)],
		["06_moth_dust_steps_to_a_spore", Vector3(-80.0, 3.9, -51.5), Vector3(-77.0, 5.5, -49.0), Vector3(-83.5, 6.5, -53.0)],
		["07_the_mushroom_grotto", Vector3(-63.5, 3.9, -47.5), Vector3(-66.0, 5.5, -49.5), Vector3(-59.0, 6.0, -42.5)],
		["08_the_crystal_pool", Vector3(-79.5, 3.9, -31.0), Vector3(-81.5, 6.0, -30.0), Vector3(-74.0, 3.0, -31.0)],
		["09_the_deep_crack_glow_bridge", Vector3(-84.0, 3.9, -36.0), Vector3(-81.5, 6.5, -34.5), Vector3(-90.0, 2.5, -36.0)],
		["10_the_old_taproot_asleep", Vector3(-89.0, 3.9, -36.0), Vector3(-89.5, 6.0, -34.5), Vector3(-95.5, 5.0, -37.0)],
	]
	player = get_first_node_in_group("player") as CharacterBody3D
	for s in shots:
		_put(s[1])
		await _settle()
		_look(s[2], s[3])
		await _frames(40)
		await _shot(s[0])
	_put(Vector3(-92.0, 3.9, -37.0))
	await _settle()
	_look(Vector3(-90.0, 5.2, -35.5), Vector3(-95.5, 5.0, -37.0))
	await _frames(40)
	await _shot("11_the_old_taproot_awake")
	# Glowcaps in the garden at night
	var farm := root.get_node("Farm")
	farm.beds[0] = {"tilled": true, "crop": "glowcap", "grown": 9999.0, "water_until": 1e9, "last": farm.now()}
	farm.beds[1] = {"tilled": true, "crop": "glowcap", "grown": 300.0, "water_until": 1e9, "last": farm.now()}
	farm.beds[2] = {"tilled": true, "crop": "glowcap", "grown": 9999.0, "water_until": 1e9, "last": farm.now()}
	clock.set_time(3, 22 * 60.0, true)
	await _go()
	_cam_in()
	var garden := Vector3(farm.GARDEN.x, 12.2, farm.GARDEN.y)
	_look(garden + Vector3(4.5, 2.5, 3.0), garden + Vector3(0, 0.3, 0))
	await _frames(40)
	await _shot("12_glowcaps_in_the_garden_at_night")
	_finish()


func _put(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


func _settle() -> void:
	for i in 10:
		await physics_frame
	await _frames(30)


func _go() -> void:
	change_scene_to_file(TOWN)
	for i in 40:
		await process_frame
	await create_timer(1.0).timeout


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
