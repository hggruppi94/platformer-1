extends SceneTree

# Screenshots of the schematics and the new rides (scripts/schematics.gd, Rides.HERO_RIDES): Dash's stall with the
# gadgets still locked, a schematic glowing on the promenade, the one in the sky, the hero on each new ride (the
# rockets boosting), Zippy's Tune-Up with the rides, the Skate page's ride picker and the Goals page. Opens a window
# (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_schematics.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.schematics_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://schematic_shots"
var game: Node
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1500.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	var S := root.get_node("Schematics")
	var shop := root.get_node("Shop")
	var clock := root.get_node("Clock")
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	root.get_node("Dialogue").reset()
	root.get_node("Arsenal").reset()
	game.needs_creator = false
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	game.riding = false
	game.sparkles = 60
	root.get_node("Requests").nights = 7
	clock.set_earth_time(0.3 * 60.0, true)
	clock.set_time(clock.day, 10 * 60.0, true)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN, 600)
	await create_timer(3.0).timeout
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D

	# --- Dash's stall, before any schematic ---
	shop.open("Gadget")
	await _shot("01_dash_stall_locked")
	shop.close()

	# --- A schematic on the promenade ---
	var fizz := current_scene.get_node_or_null("Schematic fizz") as Node3D
	if fizz:
		cam = Camera3D.new()
		current_scene.add_child(cam)
		cam.global_position = fizz.global_position + Vector3(-2.2, 1.3, 2.4)
		cam.look_at(fizz.global_position + Vector3(0, 0.7, 0))
		cam.current = true
		player.global_position = fizz.global_position + Vector3(3, 0.5, -3)
		await create_timer(1.0).timeout
		await _shot("02_schematic_on_the_promenade")
		cam.global_position = fizz.global_position + Vector3(9, 5, 11)
		cam.look_at(fizz.global_position + Vector3(0, 0.7, 0))
		await _shot("03_spotted_from_a_way_off")
	var sky := current_scene.get_node_or_null("Schematic rocket_board") as Node3D
	if sky and cam:
		cam.global_position = sky.global_position + Vector3(18, 4, 22)
		cam.look_at(sky.global_position + Vector3(0, 2.5, 0))
		await _shot("04_the_sky_schematic")
	if cam:
		cam.current = false
	player.global_position = fizz.global_position + Vector3(0, 0.5, 0) if fizz else player.global_position
	await create_timer(1.5).timeout
	await _shot("05_found_it")
	shop.open("Gadget")
	await _shot("06_dash_can_build_the_fizz_flinger")
	shop.close()

	# --- The rides ---
	for e in S.LIST:
		S.pick_up(str(e.id))
	await create_timer(0.5).timeout
	shop.open("Tune-Up")
	await _shot("07_zippys_tune_up_builds_rides")
	shop.close()
	for r in S.RIDE_PRICES:
		game.sparkles = 60
		shop.buy("ride_" + str(r))
	game.riding = true
	game.equipment_changed.emit()
	cam = Camera3D.new()
	current_scene.add_child(cam)
	var spot := Vector3(-4, 1.0, 24)
	var n := 8
	for r in S.rides_owned():
		S.use_ride(r)
		player.global_position = spot
		player.velocity = Vector3.ZERO
		await create_timer(0.5).timeout
		Engine.time_scale = 0.0                           # hold her still for the (slow) shot
		var flames: Node = player.board.find_child("Flames", true, false)
		if flames:                                        # rockets roaring, as if boosting
			for f in flames.get_children():
				if f is Node3D and not f is Light3D:
					(f as Node3D).scale = Vector3(1, 1, 1.8)
		var vis := player.get_node("Visual") as Node3D
		var at := player.global_position
		var side := vis.global_basis.x.normalized()
		cam.global_position = at + side * 2.4 + Vector3(0, 0.4, 0)
		cam.look_at(at + Vector3(0, -0.1, 0))
		cam.current = true
		await _shot("%02d_ride_%s" % [n, r], 4)
		Engine.time_scale = 1.0
		n += 1
	cam.current = false

	# --- Picking a ride, and the Goals page ---
	root.get_node("Dialogue").reset()                     # schematics not found yet, so Goals points to one
	var menu := root.get_node("PlayerMenu")
	menu.open("skate")
	await _shot("14_skate_page_ride_picker")
	menu.open("goals")
	await _shot("15_goals_page_next_schematic")
	menu.close()
	_finish()


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	quit(0)
