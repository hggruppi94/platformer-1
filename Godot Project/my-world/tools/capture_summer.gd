extends SceneTree

# Screenshots of summer in Stars Hollow: the green in the bright summer sun with sunflowers where the pumpkins were,
# the same spot in autumn to compare, the Sunflower Field, the beach at Willow Pond with Summer Splash's sandcastle,
# a cannonball off the dock, a thirsty flower job, and a summer evening with fireflies. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_summer.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.summer_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.summer_capture_backup.cfg"

var out_dir := "user://summer_shots"
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
	root.get_node("Dialogue").flags["splash_castle"] = true
	await _summer_town()
	_finish()


func _summer_town() -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of("autumn", 3, 1), 12 * 60.0, true)
	clock.earth_minutes = 12 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(Vector3(9, 4.5, 14), Vector3(0, 1.0, 0))
	await _shot("00_the_green_in_autumn_to_compare")
	clock.set_time(clock.day_of("summer", 3, 1), 12 * 60.0, true)
	clock.earth_minutes = 12 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	s = current_scene as Node3D
	p = s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(Vector3(9, 4.5, 14), Vector3(0, 1.0, 0))
	await _shot("01_the_green_in_summer")
	_look(Vector3(-8, 3.0, 22), Vector3(10, 14.0, -30))
	await _shot("02_the_bright_summer_sky")
	var patch := s.find_child("Pumpkin Patch", true, false) as Node3D
	_look(patch.global_position + Vector3(4, 4.5, 11), patch.global_position + Vector3(0, 1.0, 0))
	await _shot("03_the_sunflower_field")
	var ss := root.get_node("EarthTown/SummerSplash")
	var beach: Vector2 = ss.BEACH
	_look(Vector3(beach.x + 9.0, 3.5, beach.y - 6.0), Vector3(beach.x - 4.0, 0.0, beach.y + 3.0))
	await _shot("04_the_beach_at_willow_pond")
	p.global_position = ss.DOCK_END + Vector3(0, 1, 0)
	await _frames(6)
	ss.cannonball()
	await create_timer(ss.JUMP_TIME * 0.55).timeout
	_look(ss.DOCK_END + Vector3(-2.0, 2.2, 4.5), ss.DOCK_END + Vector3(-3.5, 2.0, 0))
	await _shot("05_cannonball")
	await create_timer(ss.JUMP_TIME * 0.45 + 0.05).timeout
	await _shot("06_ker_sploosh")
	await create_timer(1.0).timeout
	# A summer job: thirsty flowers round a house on Maple Lane
	var jobs := root.get_node("EarthJobs")
	for d in 60:
		jobs.roll(hash("summer_capture:%d" % d))
		var water: Array = jobs.list.filter(func(r: Dictionary) -> bool: return r.kind == "rake")
		if not water.is_empty():
			jobs.list.clear()
			jobs.list.append(water[0])
			break
	jobs._place_props()
	await _frames(4)
	var pots := s.get_tree().get_nodes_in_group("earth_job_props")
	if not pots.is_empty():
		# A thirsty one, and the one nearest it watered
		var first := pots[0] as Node3D
		pots.sort_custom(func(x: Node3D, y: Node3D) -> bool:
			return x.global_position.distance_to(first.global_position) < y.global_position.distance_to(first.global_position))
		if pots.size() > 1:
			pots[1].call("_on_body", p)
		var second := pots[1] as Node3D if pots.size() > 1 else first
		var mid := (first.global_position + second.global_position) / 2.0
		var to_house := (root.get_node("EarthJobs").list[0].house as String)
		var house := s.get_node_or_null(to_house) as Node3D
		var away := (mid - house.global_position) if house else Vector3(1, 0, 1)
		away.y = 0.0
		_look(mid + away.normalized() * 3.5 + Vector3(0, 1.8, 0), mid + Vector3(0, 0.3, 0))
		await _shot("07_watering_thirsty_flowers")
	clock.earth_minutes = 21.5 * 60.0
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.5).timeout
	_look(Vector3(4, 2.0, 22), Vector3(0, 2.0, 10))
	await _shot("08_a_summer_night_with_fireflies")


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
