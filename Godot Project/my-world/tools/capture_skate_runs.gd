extends SceneTree

# Screenshots of the timed skate runs (scripts/skate_runs.gd): the Run Clock at the Hollow Skate Yard, the clock and
# score across the top in a run, "Land it!" after the buzzer, the results with medals, the Run Clock at Galaxity's
# Skate Park, and the runs on the Skate page. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skate_runs.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.skate_runs_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://skate_run_shots"
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
	var runs := root.get_node("SkateRuns")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Settings").tips = false
	runs.reset()
	clock.pulls_home = false
	clock.day = 1
	clock.set_earth_time(16 * 60.0, true)
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	var c: Node3D = runs.clocks.skate_yard
	var face: Vector3 = c.global_basis.z
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()
	hud.visible = false
	p.global_position = c.global_position + face * 14.0 + Vector3.UP
	await _view("01_run_clock_at_the_hollow_skate_yard", c.global_position + face * 5.5 + c.global_basis.x * 1.5 + Vector3.UP * 2.6,
		c.global_position + Vector3.UP * 2.6)
	# A run, through the game's camera
	p.global_position = c.global_position + face * 3.0 + Vector3.UP
	for i in 3:
		await physics_frame
	runs.start("skate_yard")
	p.get_node("SpringArm3D/Camera3D").make_current()
	hud.visible = true
	for i in 200:
		await physics_frame
	var tricks = p.get_node("Skate").tricks
	for t in ["Kickflip", "Indy", "50-50"]:
		tricks.add(t, 400)
	tricks.bank()
	runs.left = 74.0
	for i in 30:
		await physics_frame
	tricks.add("Melon", 500)
	tricks.add("Hollow Yard Gap", 500)
	for i in 6:
		await physics_frame
	await _shot("02_a_run_on_the_clock")
	runs.left = 0.02
	for i in 20:
		await physics_frame
	await _shot("03_times_up_land_it")
	tricks.add("Tre Flip", 600)
	tricks.add("Boardslide", 900)
	tricks.add("Manual", 400)
	tricks.bank()
	for i in 30:
		await physics_frame
	await _shot("04_results_and_medals")
	for i in int(runs.RESULTS_TIME * 60) + 10:
		await physics_frame
	game.riding = false
	game.equipment_changed.emit()
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()
	var gc: Node3D = runs.clocks.skate_park
	var gf: Vector3 = gc.global_basis.z
	await _view("05_run_clock_at_galaxitys_skate_park", gc.global_position + gf * 6.0 - gc.global_basis.x * 2.0 + Vector3.UP * 2.8,
		gc.global_position + Vector3.UP * 2.4)
	var p2 := current_scene.find_child("Player", true, false) as CharacterBody3D
	p2.get_node("SpringArm3D/Camera3D").make_current()
	root.get_node("PlayerMenu").open("skate")
	for i in 6:
		await process_frame
	for sc in root.get_node("PlayerMenu").find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 600
	for i in 4:
		await process_frame
	await _shot("06_runs_on_the_skate_page")
	root.get_node("PlayerMenu").close()
	_finish()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 2) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("SkateRuns").reset()
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
