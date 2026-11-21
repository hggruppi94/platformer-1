extends SceneTree

# Screenshots of the three new characters where they live: Granny Purl teaching Knitting Class at the castle school
# (scripts/knitting_class.gd), Sir Squiggle in the Rootmind (scripts/rootmind.gd) and the cyber gorillas firing their
# blasters in the fading Lumen City (scripts/cyber_gorilla.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_new_characters.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.new_characters_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.new_characters_capture_backup.cfg"
const SCHOOL := "res://scenes/school/school.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://new_characters_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var portals := root.get_node("Portals")
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	root.get_node("Clock").pulls_home = false
	root.get_node("Clock").set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor",
			"far_future"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.cleared_worlds.append(w)
	var home_calls = portals.get("home_calls")
	if home_calls:
		home_calls.set("enabled", false)

	# The castle school's Knitting Class, 2nd floor
	change_scene_to_file(SCHOOL)
	await _frames(24)
	_hide_hud()
	var floor_2 := current_scene.get_node("Floor 2") as Node3D
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = floor_2.to_global(Vector3(18.5, 1, 4.5))
	_new_cam()
	var g: Node3D = root.get_node("Watches/KnittingClass").granny()
	var gp := g.global_position
	await _view("01_knitting_class", floor_2.to_global(Vector3(18.5, 3.4, 2.6)), gp + Vector3(0, 0.6, 0))
	await _view("02_granny_purl", gp + Vector3(-0.9, 1.5, 2.6), gp + Vector3(0, 1.1, 0))
	await _view("03_granny_and_snag_close", gp + Vector3(0.5, 1.75, 1.3), gp + Vector3(0.1, 1.5, 0))
	await _view("04_class_sign", floor_2.to_global(Vector3(8.5, 2.6, -1.6)), floor_2.to_global(Vector3(11.75, 2.6, -1.6)))

	# Sir Squiggle in the Rootmind, before and after it's mended
	change_scene_to_file(TOWN)
	await _frames(12)
	portals.enter("rootmind")
	await _frames(30)
	_hide_hud()
	_new_cam()
	var w := current_scene.get_node("Sir Squiggle") as Node3D
	var wp := w.global_position
	await _view("05_sir_squiggle_in_the_rootmind", wp + Vector3(3.5, 2.2, 4.5), wp + Vector3(0, 0.6, 0))
	await _view("06_sir_squiggle_close", wp + Vector3(1.0, 1.1, 1.9), wp + Vector3(0, 0.8, 0))
	current_scene.call("worm_dance")
	await _frames(30)
	await _view("07_sir_squiggle_dancing", wp + Vector3(1.6, 1.3, 2.4), wp + Vector3(0, 0.7, 0))
	portals.go_home()
	await _frames(20)

	# The cyber gorillas in Lumen City while it fades
	portals.enter("far_future")
	await _frames(30)
	_hide_hud()
	_new_cam()
	var gs: Array = current_scene.call("gorillas")
	var gor := gs[0] as Node3D
	var here := gor.global_position
	p = current_scene.find_child("Player", true, false) as Node3D
	for k in range(1, gs.size()):
		(gs[k] as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await _view("08_cyber_gorilla_in_lumen_city", here + Vector3(5.0, 2.6, 6.5), here + Vector3(0, 1.3, 0))
	# She stands in front of him: he lifts his blaster and shows his arrows, then fires
	p.global_position = here + Vector3(0, 0.85, 9.0)
	gor.set("_shoot_cd", 0.0)
	for i in 90:
		await physics_frame
		p.global_position = Vector3(here.x, p.global_position.y, here.z + 9.0)
		if float(gor.get("aiming")) > 0.0:
			break
	for i in 20:
		await physics_frame
	await _view("09_he_takes_aim_arrows", here + Vector3(-5.5, 3.6, 7.5), here + Vector3(0, 0.8, 4.5), 2)
	for i in 300:
		await physics_frame
		p.global_position = Vector3(here.x, p.global_position.y, here.z + 9.0)
		if not get_nodes_in_group("gorilla_bolts").is_empty():
			break
	for i in 18:
		await physics_frame
	await _view("10_the_bolt_flies", here + Vector3(-4.5, 2.2, 5.0), here + Vector3(0, 1.4, 4.0), 1)
	await _view("11_cyber_gorilla_close", here + Vector3(1.6, 2.4, 3.2), here + Vector3(0, 1.6, 0), 4)
	_finish()


func _hide_hud() -> void:
	for n in current_scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 10) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
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
