extends SceneTree

# Screenshots of the real Secret Garden (scripts/secret_garden.gd) and its hidden way in (scripts/secret_garden_way.gd):
# the wren on the hill, the old ivy wall, the door open, then the garden: the Rose Walk, the whole garden from above, the
# fountain, the maze, the pond, the giant flowers, the Great Tree, and the garden awake. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_secret_garden.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.secret_garden_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.secret_garden_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://secret_garden_shots"
var cam: Camera3D


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
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var way := root.get_node("Farm/SecretGarden")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	for f in dialogue.flags.keys():
		if str(f).begins_with("sg_"):
			dialogue.flags.erase(f)

	# The wren up on the hill, then the old wall at the foot of the cliff
	change_scene_to_file(TOWN)
	await _frames(12)
	var wall := current_scene.get_node("Ivy Wall") as Node3D
	var wren := wall.get_node("Wren") as Node3D
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	p.global_position = wren.global_position + Vector3(7, 1, 6)
	_new_cam()
	await _view("01_the_wren_on_the_hill", wren.global_position + Vector3(1.2, 0.8, 1.6), wren.global_position + Vector3(0, 0.3, 0))
	var door: Vector2 = way.DOOR
	var base: Vector3 = root.get_node("Bosses").ground(current_scene, door.x, door.y - 3.0)
	for k in way.TRAIL.size() - 1:
		way.hop_on()
		await _frames(140)
	p.global_position = base + Vector3(3, 1, -6)
	await _view("02_the_old_ivy_wall", base + Vector3(2.5, 2.4, -9), base + Vector3(0, 2.0, 2.0))
	await _view("03_the_wren_pecking", wren.global_position + Vector3(1.5, 1.0, -1.5), wren.global_position + Vector3(0, 0.2, 0))
	var mound := wall.get_node("Key Mound")
	mound.find_child("Key Spot", true, false).act.call()
	var spot := wall.find_child("Wall Spot", true, false)
	spot.act.call()
	await _frames(120)
	await _view("04_the_door_open", base + Vector3(1.5, 2.0, -6.5), base + Vector3(0, 1.8, 2.0))

	# In
	spot.act.call()
	await _frames(14)
	var sg := current_scene as Node3D
	p = sg.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	_new_cam()
	await _view("05_the_rose_walk", Vector3(0.6, 2.0, 2.0), Vector3(0, 1.8, 30), 12)
	await _view("06_the_garden_from_above", Vector3(0, 70, -25), Vector3(0, 0, 70), 12)
	await _view("07_the_fountain_lawn", Vector3(10, 4.5, 34), Vector3(0, 2.0, 52))
	await _view("08_the_hedge_maze", Vector3(-24, 22, 36), Vector3(-42, 0, 52))
	await _view("09_the_lily_pond", Vector3(22, 4.0, 40), Vector3(40, 0.5, 56))
	await _view("10_the_giant_flowers", Vector3(10, 5, 92), Vector3(0, 4.5, 108))
	await _view("11_the_great_tree", Vector3(-30, 5, 104), Vector3(-44, 7, 118))
	for id in sg.seeds:
		sg.wake_seed(id)
	await _frames(220)
	await _view("12_the_garden_awake", Vector3(14, 9, 30), Vector3(0, 2.5, 60), 10)
	_finish()


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.make_current()
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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
