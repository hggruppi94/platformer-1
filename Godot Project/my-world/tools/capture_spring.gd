extends SceneTree

# Screenshots of spring in Stars Hollow and the quest "Duckling Day": the green in the soft spring sun, a lost duckling
# by the gazebo, the five ducklings following in a line, bringing them home to Mother Duck, the family swimming on
# Willow Pond, a puddle splash on the green, and a spring evening. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_spring.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.spring_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.spring_capture_backup.cfg"

var out_dir := "user://spring_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
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
	clock = root.get_node("Clock")
	clock.set("pulls_home", false)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	await _spring_town()
	_finish()


func _spring_town() -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of("spring", 3, 1), 10 * 60.0, true)
	clock.earth_minutes = 10 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(Vector3(9, 4.5, 14), Vector3(0, 1.0, 0))
	await _shot("01_the_green_on_a_spring_morning")
	var dd := root.get_node("EarthTown/DucklingDay")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	dialogue.set_flag("duckling_day_start")
	quests.check()
	await _frames(4)
	var d1: Vector3 = dd.lost_spot(0)
	_look(d1 + Vector3(1.6, 0.9, 1.6), d1 + Vector3(0, 0.15, 0))
	await _shot("02_a_lost_duckling_by_the_gazebo")
	# Pick them all up, then walk a little way so they line up behind
	for i in dd.DUCKLINGS:
		dd.pick_up(i)
	quests.check()
	p.global_position = dd.ground(Vector2(-30.0, 14.0)) + Vector3(0, 0.85, 0)
	await _frames(4)
	for k in 40:
		p.global_position += Vector3(-0.15, 0, 0.02)
		await _frames(1)
	var feet := p.global_position - Vector3(0, 0.85, 0)
	_look(feet + Vector3(-2.2, 1.4, 3.2), feet + Vector3(1.6, 0.3, 0))
	await _shot("03_five_ducklings_in_a_line")
	# Home to Mother Duck
	var m: Vector3 = dd.ground(dd.MOTHER_AT)
	for k in 60:
		var to := m + Vector3(5.0, 0, 0.6)
		var here := p.global_position - Vector3(0, 0.85, 0)
		if here.distance_to(to) < 0.2:
			break
		p.global_position += (to - here).limit_length(0.4)
		await _frames(1)
	_look(m + Vector3(3.0, 1.8, 4.5), m + Vector3(2.5, 0.2, 0))
	await _shot("04_mother_duck_waiting_on_the_bank")
	dd.bring_home()
	quests.check()
	await create_timer(6.0).timeout
	var mother := s.get_node("Duckling Day/Mother Duck") as Node3D
	var mp := mother.global_position
	_look(mp + Vector3(4.0, 2.0, 4.0), mp + Vector3(-1.0, 0, -1.0))
	await _shot("05_the_family_swims_round_willow_pond")
	# A puddle splash on the green
	var pud: Vector3 = dd.PUDDLES[1]
	var pg: Vector3 = dd.ground(Vector2(pud.x, pud.z))
	p.global_position = pg + Vector3(0, 2.2, 0)
	p.velocity = Vector3.ZERO
	_look(pg + Vector3(3.5, 1.8, 3.5), pg + Vector3(0, 0.5, 0))
	for k in 120:
		await physics_frame
		if k > 3 and p.is_on_floor():
			break
	await _frames(3)
	await _shot("06_splash_in_a_puddle")
	clock.earth_minutes = 19.0 * 60.0
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.5).timeout
	_look(Vector3(14, 6.0, 30), Vector3(0, 1.5, 4))
	await _shot("07_a_long_spring_evening")


func game_go(path: String) -> void:
	root.get_node("Game").go(path, "", "")


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
