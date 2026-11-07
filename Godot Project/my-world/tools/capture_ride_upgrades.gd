extends SceneTree

# Screenshots of the ride upgrades you get as you level up (scripts/ride_upgrades.gd, Rides.HERO_RIDES,
# scenes/player/skate.gd): Zippy's Tune-Up waiting for levels, the new Hover Bike, hover rides floating across the
# lake, the rocket rides flying high over town with the fuel bar, floating back down, the Skate page and the Goals
# page. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_ride_upgrades.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.ride_upgrades_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://ride_upgrade_shots"
var game: Node
var cam: Camera3D
var player: CharacterBody3D


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
	root.get_node("Settings").control_style = "classic"
	clock.pulls_home = false
	root.get_node("Dialogue").reset()
	root.get_node("Races").reset()
	game.needs_creator = false
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	game.riding = false
	game.sparkles = 200
	game.level = 1
	game.xp = 0
	root.get_node("Requests").nights = 7
	clock.set_earth_time(0.3 * 60.0, true)
	clock.set_time(clock.day, 11 * 60.0, true)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN, 600)
	await create_timer(3.0).timeout
	player = current_scene.find_child("Player", true, false) as CharacterBody3D

	# --- Zippy waits for levels ---
	for e in S.LIST:
		if str(e.kind) == "ride":
			S.pick_up(str(e.id))
	shop.buy("ride_bike")
	shop.open("Tune-Up")
	await _shot("01_tune_up_waits_for_levels")
	shop.close()
	game.add_xp(30)                                      # Lv 3: the Overboard and the Hover Bike open
	await create_timer(0.3).timeout
	await _shot("02_level_up_opens_a_ride")
	game.level = 9
	for r in ["overboard", "hover_bike", "rocket_board", "rocket_bike"]:
		shop.buy("ride_" + r)
	game.riding = true
	game.equipment_changed.emit()
	await create_timer(0.5).timeout

	# --- The Hover Bike, close up ---
	S.use_ride("hover_bike")
	cam = Camera3D.new()
	current_scene.add_child(cam)
	player.global_position = Vector3(-4, 1.0, 26)
	player.velocity = Vector3.ZERO
	await create_timer(0.8).timeout
	Engine.time_scale = 0.0
	var at := player.global_position
	var side := (player.get_node("Visual") as Node3D).global_basis.x.normalized()
	cam.global_position = at + side * 2.6 + Vector3(0, 0.5, 0.6)
	cam.look_at(at + Vector3(0, -0.2, 0))
	cam.current = true
	await _shot("03_hover_bike", 4)
	Engine.time_scale = 1.0
	cam.current = false

	# --- Hover rides across the lake ---
	await _ride_out("overboard", Vector3(12, 1.0, 12), 2.2)
	await _shot("04_overboard_across_the_lake")
	await _side_shot("05_overboard_on_the_water_side")
	Input.action_release("move_forward")
	await _ride_out("hover_bike", Vector3(20, 1.0, 10), 1.5)
	await _shot("06_hover_bike_across_the_lake")
	await _side_shot("07_hover_bike_on_the_water_side")
	Input.action_release("move_forward")

	# --- Rocket rides fly ---
	await _take_off("rocket_board", Vector3(10, 1.5, 44), 0.0, 1.0)
	await _shot("08_rocket_board_liftoff")
	await _physics(70)
	await _shot("09_rocket_board_flying_over_town")
	await _side_shot("10_rocket_board_flying_side")
	Input.action_release("jump")
	await _physics(70)
	await _shot("11_floating_back_down")
	Input.action_release("move_forward")
	await _land()
	await _take_off("rocket_bike", Vector3(30, 1.5, 40), -0.8, 2.2)
	await _shot("12_rocket_bike_high_over_town")
	await _side_shot("13_rocket_bike_flying_side")
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _land()

	# --- The Skate page and the Goals page ---
	var menu := root.get_node("PlayerMenu")
	menu.open("skate")
	await _shot("14_skate_page")
	menu.close()
	game.level = 1
	game.xp = 0
	game.items = game.items.filter(func(i: String) -> bool: return not i.begins_with("ride:") or i == "ride:bike")
	game.give_item("ride:saucer")
	S.use_ride("bike")
	menu.open("goals")
	await _shot("15_goals_page_next_level")
	menu.close()
	_finish()


func _ride_out(r: String, from: Vector3, seconds: float) -> void:
	# Onto the lake and pushing along it (north), with the game's own camera following
	root.get_node("Schematics").use_ride(r)
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.spring_arm.rotation.y = 0.0
	player.get("skate").set("_yaw", PI)
	await _physics(24)
	Input.action_press("move_forward")
	await _physics(int(seconds * 60))


func _take_off(r: String, from: Vector3, yaw: float, climb: float) -> void:
	root.get_node("Schematics").use_ride(r)
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.spring_arm.rotation.y = yaw
	player.get("skate").set("_yaw", yaw + PI)
	await _physics(30)
	Input.action_press("move_forward")
	await _physics(48)
	Input.action_press("jump")
	await _physics(7)
	Input.action_release("jump")
	await _physics(9)
	Input.action_press("jump")
	await _physics(int(climb * 60))


func _land() -> void:
	var skate: Node = player.get("skate")
	for i in 900:
		await physics_frame
		if int(skate.state) == int(skate.State.ROLL):
			break
	await create_timer(0.5).timeout


func _side_shot(file: String) -> void:
	# Frozen for a moment, seen from off to one side and a little behind, to show where she is
	Engine.time_scale = 0.0
	var at := player.global_position
	var vel := Vector3(player.velocity.x, 0, player.velocity.z)
	var fwd := vel.normalized() if vel.length() > 0.5 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	cam.global_position = at + side * 4.5 - fwd * 3.0 + Vector3(0, 1.2, 0)
	cam.look_at(at + fwd * 1.5 - Vector3(0, 0.6, 0))
	cam.current = true
	await _shot(file, 4)
	cam.current = false
	Engine.time_scale = 1.0


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	var sk = player.get("skate") if player else null
	print("SHOT ", file, (" fuel %.2f flying %s y %.1f" % [sk.fuel, sk.flying, player.global_position.y]) if sk else "")


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	for a in ["move_forward", "jump"]:
		Input.action_release(a)
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	quit(0)
