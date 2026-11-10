extends SceneTree

# Screenshots of the Far Future, Dash and Rex's portal world (scripts/far_future.gd): its portal on the fault line
# behind their lab, Lumen City faded and flickering, Rex by the way in, Dash's lab and the Swap-o-Tron, the Skyway
# high over the streets, the fading folk on the plaza, the Tomorrow Clock with its cores, Captain Glitch on his dais and
# then fighting, and the city bright again once he's popped. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_far_future.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.far_future_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.far_future_capture_backup.cfg"

var out_dir := "user://far_future_shots"
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
	clock.set_time(3, 11 * 60.0, true)                       # late morning in the Void
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("far_future", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal far_future") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(3.5, 3.5, 0), portal.global_position + Vector3(0, 2.0, 0))
	await _frames(30)
	await _shot("01_portal_on_the_fault_line")


func _inside() -> void:
	portals.enter("far_future")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	await _frames(10)
	if root.get_node("Dialogue").is_active():
		root.get_node("Dialogue").end()
	_look(Vector3(6.0, 14.0, 60.0), Vector3(0, 4.0, -4.0))
	await create_timer(0.4).timeout
	await _shot("02_lumen_city_fading")
	var rex := s.get_node("Rex") as Node3D
	_look(rex.global_position + rex.global_basis.z * 3.6 + Vector3(0.8, 1.6, 0), rex.global_position + Vector3(0, 1.0, 0))
	await _shot("03_rex_by_the_way_in")
	# Dash's lab, from its open front
	var lab := (s.get_node("SwapOTron") as Node3D).global_position
	p.global_position = Vector3(0, 1.0, 40)
	_look(lab + Vector3(14.0, 5.0, 3.0), lab + Vector3(-1.0, 1.6, 0))
	await _shot("04_dashs_lab_power_off")
	for i in s.FUSES:
		s.fix_fuse(i)
	await create_timer(0.6).timeout
	_look(lab + Vector3(4.5, 2.6, 3.5), lab + Vector3(0, 1.4, 0))
	await _shot("05_the_swap_o_tron_humming")
	# The Skyway, high over the streets
	_look(Vector3(-62.0, 22.0, 30.0), Vector3(-20.0, 8.0, 10.0))
	await _shot("06_the_skyway")
	# The fading folk on the plaza, one pinned in time
	s.pin(0)
	var f2 := (s.get_node("Folk2") as Node3D).global_position
	_look(f2 + Vector3(-4.0, 3.0, 7.0), f2 + Vector3(0, 1.0, 0))
	await create_timer(0.3).timeout
	await _shot("07_folk_fading_on_the_plaza")
	# The Tomorrow Clock with its cores, and the glitchy statue on the dais
	for i in 3:
		s.bring_core(i)
	await create_timer(2.3).timeout
	var cap := (s.get_node("Captain") as Node3D).global_position
	_look(cap + Vector3(5.0, 4.5, 13.0), cap + Vector3(0, 3.0, -4.0))
	await _shot("08_three_cores_home_and_the_statue")
	# Captain Glitch wakes and fights
	p.global_position = cap + Vector3(0, 1.0, 10.0)
	await _frames(4)
	var c := s.get_node("Captain Glitch") as CharacterBody3D
	await create_timer(1.6).timeout
	c.set("_timer", 0.0)
	await create_timer(0.5).timeout
	if root.get_node("Dialogue").is_active():
		root.get_node("Dialogue").end()
	_look(c.global_position + Vector3(6.0, 3.0, 12.0), c.global_position + Vector3(0, -1.0, 0))
	await _shot("09_captain_glitch_chaos_bursts")
	c.set("_volleys", 99)
	c.call("_set_state", 2)
	var t := 0
	while t < 120 and not c.call("is_open"):
		await physics_frame
		t += 1
	await create_timer(0.25).timeout
	_look(c.global_position + Vector3(4.0, 3.0, 9.0), c.global_position + Vector3(0, 2.0, 0))
	await _shot("10_crashed_down_clock_glowing")
	# Popped: the city bright again
	p.global_position = Vector3(0, 1.0, 40)
	while not c.get("defeated"):
		c.call("_set_state", 3)
		c.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await create_timer(s.THANKS_AFTER + 0.6).timeout
	if root.get_node("Dialogue").is_active():
		root.get_node("Dialogue").end()
	_look(Vector3(6.0, 14.0, 60.0), Vector3(0, 4.0, -4.0))
	await _frames(4)
	await _shot("11_lumen_city_bright_again")
	_look(Vector3(40.0, 18.0, 30.0), Vector3(0, 6.0, -10.0))
	await _shot("12_fireworks_over_the_city")


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
