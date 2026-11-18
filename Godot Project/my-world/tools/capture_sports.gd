extends SceneTree

# Pictures of the sports corner's games (scripts/sports.gd): the hosts by their courts, Hoop Shoot with its meter and a
# shot on its way, Goal Kicks with the target and Bonk diving, Tennis Rally with the ring and Volley over the net, the
# Rock Wall Race's way stars and bell, and a results card.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_sports.gd -- <folder>
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.sports_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.sports_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://sports_shots"
var cam: Camera3D
var sports: Node
var p: CharacterBody3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
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
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Portals").home_calls.enabled = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	sports = root.get_node("Sports")
	change_scene_to_file(TOWN)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()

	# The hosts, from the path
	var bb := sports.place_of("hoops") as Node3D
	p.global_position = bb.to_global(Vector3(-2.5, 0.6, 13.5))
	await _view(bb.to_global(Vector3(-1.5, 2.4, 16.5)), bb.to_global(Vector3(-4.5, 1.2, 10.4)), "01_coach_swish")
	var sf := sports.place_of("goals") as Node3D
	await _view(sf.to_global(Vector3(-2.0, 2.2, 16.0)), sf.to_global(Vector3(-4.5, 1.0, 11.9)), "02_bonk_by_the_field")

	# Hoop Shoot: the meter, and a shot on its way
	sports.start("hoops")
	await _skip_countdown()
	var hoops: Node3D = sports.game
	p.global_position = hoops.to_global(Vector3(5.5, 0.6, 2.0))
	await _frames(4)
	hoops.shoot(true)
	await _physics(30)
	await _view(hoops.to_global(Vector3(1.5, 3.2, 6.5)), hoops.to_global(Vector3(10.0, 2.8, 0.0)), "03_hoop_shoot")
	await _until(func() -> bool: return hoops.phase == "drop", 2.0)
	await _physics(4)
	await _view(hoops.to_global(Vector3(8.5, 3.4, 3.5)), hoops.to_global(Vector3(12.4, 2.8, 0.0)), "04_swish")
	await _until(func() -> bool: return hoops.phase == "held", 3.0)
	# On the ride, in the air
	game.riding = true
	game.equipment_changed.emit()
	await _physics(4)
	p.global_position = hoops.to_global(Vector3(7.0, 1.8, -1.5))
	var s = p.get("skate")
	if s:
		s.state = 1
	hoops.shoot(true)
	if s:
		s.state = 0
	await _physics(16)
	await _view(hoops.to_global(Vector3(3.0, 2.6, -6.0)), hoops.to_global(Vector3(10.0, 2.4, 0.0)), "05_air_shot_on_the_board")
	await _until(func() -> bool: return hoops.phase == "held", 3.0)
	game.riding = false
	game.equipment_changed.emit()
	hoops.left = 0.05
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 2.0)
	await _view(hoops.to_global(Vector3(1.5, 3.2, 6.5)), hoops.to_global(Vector3(10.0, 2.0, 0.0)), "06_results")
	sports._end()
	await _frames(4)

	# Goal Kicks: the target, then Bonk diving
	sports.start("goals")
	await _skip_countdown()
	var goals: Node3D = sports.game
	await _physics(20)
	await _view(goals.to_global(Vector3(2.0, 2.4, 1.5)), goals.to_global(Vector3(15.6, 1.0, 0.0)), "07_goal_kicks_aim")
	goals.guess_wrong = 0.0
	goals.kick_at(2.4)
	await _physics(36)
	await _view(goals.to_global(Vector3(9.0, 2.0, -5.0)), goals.to_global(Vector3(15.6, 1.0, 1.0)), "08_bonk_dives")
	await _until(func() -> bool: return goals.phase == "wait", 2.0)
	await _physics(10)
	await _view(goals.to_global(Vector3(10.0, 2.2, -4.0)), goals.to_global(Vector3(16.0, 0.8, 1.5)), "09_goal")
	sports._end()
	await _frames(4)

	# Tennis Rally: the ring and the ball coming over
	sports.start("tennis")
	await _skip_countdown()
	var tennis: Node3D = sports.game
	await _until(func() -> bool: return tennis.phase == "to_you", 4.0)
	p.global_position = tennis.to_global(tennis.landing + Vector3(1.5, 0.4, 0.5))
	await _physics(30)
	await _view(tennis.to_global(Vector3(14.0, 3.5, 3.0)), tennis.to_global(Vector3(0.0, 1.0, 0.0)), "10_tennis_ring")
	p.global_position = tennis.to_global(tennis.landing + Vector3(0, 0.4, 0))
	await _until(func() -> bool: return tennis.phase == "to_them", 3.0)
	await _physics(30)
	await _view(tennis.to_global(Vector3(10.0, 2.5, -7.0)), tennis.to_global(Vector3(-4.0, 1.2, 0.0)), "11_tennis_back_to_volley")
	sports._end()
	await _frames(4)

	# Rock Wall Race: the way stars and the bell
	sports.start("climb")
	await _skip_countdown()
	var climb: Node3D = sports.game
	await _physics(10)
	await _view(climb.to_global(Vector3(3.5, 4.0, 13.0)), climb.to_global(Vector3(0.0, 5.0, 0.0)), "12_rock_wall_race")
	p.global_position = climb.to_global(Vector3(-1.5, 9.4, 1.3))
	await _physics(10)
	await _view(climb.to_global(Vector3(4.0, 11.5, 6.0)), climb.to_global(Vector3(1.5, 10.0, 0.0)), "13_bell_on_top")
	sports._end()
	_finish()


func _skip_countdown() -> void:
	await _physics(int(sports.COUNTDOWN * 60) + 4)


func _view(at: Vector3, look: Vector3, file: String) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		await physics_frame


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
	quit(0)
