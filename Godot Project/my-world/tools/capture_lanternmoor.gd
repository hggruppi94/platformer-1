extends SceneTree

# Screenshots of Lanternmoor, Pip's portal world (scripts/lanternmoor.gd): its portal in the Spooky Woods, arriving
# in the endless night, Pip, the Night Path's lanterns, the Tall Lantern Tree and Moon Rock, gliding on moth wings, the
# runaway lights, the Dawn Snatcher asleep and then awake, and the sunrise once it's mended. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_lanternmoor.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.lanternmoor_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lanternmoor_capture_backup.cfg"

var out_dir := "user://lanternmoor_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
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
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 18 * 60.0 + 40.0, true)                # dusk in the Void, for the portal in the woods
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("lanternmoor", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal lanternmoor") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)                                         # near enough for the preview window to wake
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(3.5, 3.0, 0), portal.global_position + Vector3(0, 2.6, 0))
	await _frames(30)
	await _shot("01_portal_in_the_spooky_woods")


func _inside() -> void:
	portals.enter("lanternmoor")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	await _frames(10)
	_look(Vector3(-3.0, 3.4, 37.0), Vector3(0, 4.0, -12.0))
	await _shot("02_arriving_the_sun_wont_rise")
	var pip := (s.get_node("Pip") as Node3D).global_position
	p.global_position = pip + Vector3(1.0, 0.9, 2.4)
	await create_timer(1.2).timeout                          # she turns to look at you
	_look(pip + Vector3(-1.8, 1.5, 2.8), pip + Vector3(0, 1.0, 0))
	await _shot("03_pip_at_home")
	s.pip_lines()                                            # meeting her: the moth wings
	for i in 3:
		s.light_lantern(i)
	var l3 := (s.get_node("Lantern3") as Node3D).global_position
	p.global_position = Vector3(0, 0.9, 27)
	await _frames(6)
	_look(l3 + Vector3(6.0, 3.0, 8.0), l3 + Vector3(-6.0, 1.2, -6.0))
	await _shot("04_lighting_the_night_path")
	var launch := (s.get_node("Launch") as Node3D).global_position
	var rock := (s.get_node("Beacon2") as Node3D).global_position
	_look(launch + Vector3(-6.0, 1.0, 12.0), (launch + rock) / 2.0 + Vector3(0, -1.5, 0))
	await _shot("05_tall_lantern_tree_and_moon_rock")
	# Off the top of the tree, gliding on Pip's wings
	var dir := Vector3(rock.x - launch.x, 0, rock.z - launch.z).normalized()
	p.global_position = launch + dir * 1.8 + Vector3(0, 0.6, 0)
	p.spring_arm.global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	await _frames(6)
	Input.action_press("move_forward")
	Input.action_press("jump")
	p.velocity = dir * 5.0 + Vector3(0, 6.0, 0)
	await create_timer(1.9).timeout
	var side := dir.cross(Vector3.UP)
	_look(p.global_position - dir * 3.2 + side * 2.4 + Vector3(0, 1.4, 0), p.global_position + dir * 3.0 + Vector3(0, 0.6, 0))
	await _shot("06_gliding_on_moth_wings")
	await create_timer(4.0).timeout
	Input.action_release("move_forward")
	Input.action_release("jump")
	s.light_beacon(1)
	var grove := (s.get_node("Beacon3") as Node3D).global_position
	p.global_position = grove + Vector3(0, 0.9, 14)
	await _frames(10)
	_look(grove + Vector3(2.0, 9.0, 15.0), grove + Vector3(0, 1.0, 0))
	await _shot("07_runaway_lights_in_the_grove")
	var hill := (s.get_node("Snatcher") as Node3D).global_position
	p.global_position = hill + Vector3(-3.0, 0.9, 14.0)
	await _frames(6)
	_look(hill + Vector3(6.0, 4.0, 11.0), hill + Vector3(0, 2.2, 0))
	await _shot("08_dawn_snatcher_asleep")
	for i in 5:
		s.light_lantern(i)
	for i in 3:
		s.catch_light(i)
	await create_timer(1.6).timeout
	p.global_position = Vector3(0, 0.9, 30)
	await _frames(6)
	_look(Vector3(8.0, 9.0, 34.0), Vector3(-6.0, 1.0, -14.0))
	await _shot("09_three_beacons_lit")
	p.global_position = hill + Vector3(-5.0, 0.9, 12.0)
	await create_timer(1.8).timeout
	var g := s._snatcher as Node3D
	_look(g.global_position + Vector3(6.0, 4.0, 10.0), g.global_position + Vector3(0, 2.4, 0))
	await _shot("10_dawn_snatcher_awake")
	p.global_position = Vector3(0, 0.9, 22)
	for i in 8:
		if is_instance_valid(g) and not g.defeated:
			g.shot(1, g.global_position, Vector3.FORWARD)
	await create_timer(2.6).timeout
	_look(Vector3(-6.0, 3.0, 4.0), Vector3(20.0, 14.0, -60.0))
	await _shot("11_the_dawn_floats_out")
	await create_timer(4.5).timeout
	_look(Vector3(-10.0, 4.0, 26.0), Vector3(14.0, 6.0, -40.0))
	await _shot("12_morning_over_lanternmoor")


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
	Input.action_release("move_forward")
	Input.action_release("jump")
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
