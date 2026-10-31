extends SceneTree

# Pictures of things to do in the Earth town (phase 3 of the Stars Hollow build-out): the notice board and its jobs
# (leaf piles, pumpkins to pick, a lost cat), the shops, the Autumn Festival on a Saturday evening (stalls, the pie
# table, apple bobbing, the hayride, the lanterns at nine), and the old oak's hints (its glow near midnight, the
# envelope on Mr. Palmer's porch). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_fun.gd -- <output folder> [only]
#
# Pass a shot's name (or part of it) as "only" to take just that one. Your own save is put aside and put back.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_fun_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_fun_shots"
var only := ""
var cam: Camera3D
var clock: Node
var jobs: Node
var player: CharacterBody3D
var hud: CanvasLayer


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	clock = root.get_node("Clock")
	jobs = root.get_node("EarthJobs")
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	root.get_node("Festival").reset()
	jobs.reset()
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	game.riding = false
	game.sparkles = 60
	root.get_node("Settings").tips = false                        # (no how-to pop-ups in the pictures)
	clock.day = 4                                                 # a Monday
	clock.minutes = 7 * 60.0
	clock.earth_minutes = 10 * 60.0
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	hud = player.get_node("HUD") as CanvasLayer
	hud.visible = false
	player.global_position = Vector3(60, 1, 60)
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()

	# --- The notice board and its jobs (Monday) ---
	_set_hour(10.0)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	jobs.list = [jobs._make("rake", "easy", r), jobs._make("cat", "medium", r), jobs._make("bakery", "hard", r)]
	jobs.list[0].merge({"house": "Maple House 2", "family": "Okafor", "piles": [0, 1, 2, 3, 4, 5, 6, 8, 9, 10]}, true)
	jobs.list[0].goal = 6
	jobs.list[1].merge({"who": "wren", "cat": "Duchess", "coat": "grey", "hideout": "playground", "where": "by the playground slide"}, true)
	jobs.rolled_visit = clock.earth_day()
	jobs.changed.emit()
	jobs._place_props()
	await create_timer(0.3).timeout
	await _shot("01_the_notice_board", Vector3(-3.7, 1.9, 10.2), Vector3(-3.7, 2.0, 6.6), 55.0)
	await _shot("02_the_board_by_the_gazebo", Vector3(-9, 3.2, 17), Vector3(-1.5, 1.6, 5), 60.0)
	await _shot("03_rake_the_okafor_yard", Vector3(-44, 4.0, 58.5), Vector3(-44, 0.4, 47.5), 60.0)
	var cat := current_scene.find_child("Job Cat *", true, false) as Node3D
	if cat:
		await _shot("04_a_lost_cat_by_the_slide", cat.global_position + Vector3(1.6, 0.9, 1.6), cat.global_position + Vector3(0, 0.3, 0), 45.0)
	_set_hour(18.6)
	await _shot("05_pumpkins_to_pick_at_dusk", Vector3(-119, 4.5, 41), Vector3(-119, 0.4, 31), 60.0)
	if cat:
		_set_hour(22.5)
		await _shot("06_glowing_eyes_at_night", cat.global_position + Vector3(1.4, 0.7, 1.4), cat.global_position + Vector3(0, 0.35, 0), 45.0)

	# --- The shops ---
	_set_hour(11.0)
	var bakery := current_scene.get_node("Bakery") as Node3D
	var counter := bakery.get_node("Shop Bakery") as Node3D
	await _shot("07_the_bakery_counter", bakery.global_transform * Vector3(0, 2.0, 3.5), counter.global_position + Vector3(0, 1.0, 0), 65.0)
	if only == "" or "08_shopping".contains(only):
		root.get_node("Shop").open("Bakery")
		await _shot("08_shopping_at_the_bakery", bakery.global_transform * Vector3(0, 2.0, 3.5), counter.global_position + Vector3(0, 1.0, 0), 65.0)
		root.get_node("Shop").close()
	game.outfit["head"] = "witch_hat"
	game.equipment_changed.emit()
	player.global_position = Vector3(6, 0.5, 14)
	await create_timer(0.6).timeout
	var visual := player.get_node("Visual") as Node3D
	var front := visual.global_basis.z.normalized()
	var at := player.global_position
	await _shot("09_a_witch_hat_from_the_toy_shop", at + front * 2.3 + Vector3(0, 1.5, 0), at + Vector3(0, 1.1, 0), 50.0)
	game.outfit["head"] = "pumpkin_hat"
	game.equipment_changed.emit()
	await create_timer(0.3).timeout
	await _shot("10_or_a_pumpkin_hat", at + front * 2.3 + Vector3(0, 1.5, 0), at + Vector3(0, 1.1, 0), 50.0)
	game.outfit.erase("head")
	game.equipment_changed.emit()
	player.global_position = Vector3(60, 1, 60)

	# --- The Autumn Festival (Saturday) ---
	jobs.list = []
	jobs._place_props()
	clock.day = 9                                                 # a Saturday
	_set_hour(18.0)
	clock.jumped.emit()
	await create_timer(1.5).timeout
	await _shot("11_the_autumn_festival", Vector3(14, 9, 24), Vector3(0, 0, 0), 65.0)
	await _shot("12_the_festival_from_the_banner", Vector3(1.2, 2.0, 17.5), Vector3(0, 1.4, 4), 70.0)
	await _shot("13_treats_and_the_pie_contest", Vector3(1.5, 1.9, -1.5), Vector3(0.5, 1.4, -9.5), 65.0)
	await _shot("14_apple_bobbing_and_hank", Vector3(3.5, 1.9, 1.0), Vector3(9.4, 0.8, -1.5), 60.0)
	await _shot("15_lanterns_and_cider", Vector3(-1.5, 1.9, -1.0), Vector3(-8.5, 1.4, -3.5), 65.0)
	if only == "" or "16_bob".contains(only):
		root.get_node("Festival").start_bobbing()
		await create_timer(0.6).timeout
		await _shot("16_bob_for_apples", Vector3(3.5, 1.9, 1.0), Vector3(9.4, 0.8, -1.5), 60.0)
		var bob: Node = root.get_node("Festival").bobbing()
		if bob:
			bob.close()
	var green := current_scene.get_node_or_null("Autumn Festival")
	if green:
		green._d = 0.0
		green._wait = 100.0
		await create_timer(0.2).timeout
		await _shot("17_the_hayride_waits_by_the_inn", Vector3(26, 2.6, 4), Vector3(21, 1.0, 12.5), 60.0)
		green.hop_on()
		green._wait = 0.0
		green._d = 30.0
		await create_timer(0.5).timeout
		var w: Node3D = green.wagon
		await _shot("18_on_the_hayride", w.global_transform * Vector3(-3.2, 2.4, -3.4), w.global_position + Vector3(0, 1.4, 0), 60.0)
		green.hop_off()
		player.global_position = Vector3(0, 0.3, 16)
	_set_hour(21.0)
	await create_timer(4.0).timeout
	await _shot("19_lanterns_at_nine", Vector3(1.2, 1.8, 17.5), Vector3(0, 7, 0), 75.0)
	await create_timer(6.0).timeout
	await _shot("20_lanterns_over_the_old_oak", Vector3(9, 2, 17), Vector3(-6, 14, 6), 70.0)

	# --- The old oak, near midnight ---
	clock.day = 10
	_set_hour(23.6)
	clock.jumped.emit()
	await create_timer(1.0).timeout
	await _shot("21_the_oak_glows_near_midnight", Vector3(-1, 2.4, 22), Vector3(-12, 3, 9), 60.0)
	_set_hour(21.5)
	var palmer := current_scene.get_node("Palmer House") as Node3D
	await _shot("22_an_envelope_on_mr_palmers_porch", palmer.global_transform * Vector3(3.9, 1.5, 6.0),
		palmer.global_transform * Vector3(3.1, 0.85, 4.4), 45.0)
	_finish()


func _shot(file: String, from: Vector3, look: Vector3, fov: float) -> void:
	if only != "" and not file.contains(only):
		return
	cam.global_position = from
	cam.look_at(look)
	cam.fov = fov
	await create_timer(0.4).timeout
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _set_hour(hour: float) -> void:
	clock.earth_minutes = hour * 60.0
	clock.time_changed.emit()
	if current_scene.has_method("_light"):
		current_scene.call("_light")


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
