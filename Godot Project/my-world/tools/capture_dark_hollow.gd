extends SceneTree

# Screenshots of Dark Hollow, the centipede's world (scripts/dark_hollow.gd), and its secret way in
# (scripts/centipede_corner.gd): the centipede in her corner at the end of Behind the Walls in the castle school, the
# gulp, arriving in the hollow at midnight, the shadow ghosts in the Ghost Glade, the Big Hole, the Crooked Spire, the
# Hollow Run with Pip, the Hush asleep on its hill, the Hush in the dark and caught in a moon lamp's light, and the
# hollow mended. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_dark_hollow.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.dark_hollow_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dark_hollow_capture_backup.cfg"
const SCHOOL := "res://scenes/school/school.tscn"

var out_dir := "user://dark_hollow_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
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
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.set("race_intros", false)
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 13 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	await _corner()
	await _inside()
	_finish()


func _corner() -> void:
	game_go(SCHOOL)
	await _frames(16)
	var s := current_scene as Node3D
	var corner := s.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner") as Node3D
	if corner == null:
		print("NO CORNER")
		return
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = corner.to_global(corner.SPOT_AT + Vector3(2.2, 1.0, 0))
	p.velocity = Vector3.ZERO
	await _frames(40)
	_cam_in(s)
	_look(corner.to_global(Vector3(-20.5, 2.0, -22.3)), corner.to_global(corner.CORNER + Vector3(0, 0.9, 0)))
	await _frames(20)
	await _shot("01_her_corner_behind_the_walls")
	_look(corner.to_global(Vector3(-23.0, 1.7, -21.6)), corner.to_global(corner.CORNER + Vector3(0, 1.0, 0)))
	await _frames(10)
	await _shot("02_her_corner_close")
	corner.gulp()
	await create_timer(1.0).timeout
	await _shot("03_she_circles_round_you")
	await create_timer(0.9).timeout
	await _shot("04_gulp")
	await create_timer(1.3).timeout
	await _shot("05_the_slide_down")
	await create_timer(2.6).timeout                            # lands in Dark Hollow


func _inside() -> void:
	await _frames(20)
	var s := current_scene as Node3D
	if s == null or not s.has_method("wake_hush"):
		print("NOT IN DARK HOLLOW: ", s)
		return
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	await _frames(30)
	_cam_in(s)
	_look(Vector3(-4, 5, 62), Vector3(0, 1, 30))
	await _frames(20)
	await _shot("06_arriving_at_midnight")
	var c := s.get_node("Centipede") as Node3D
	_look(c.global_position + Vector3(4.5, 2.4, 3.5), c.global_position + Vector3(0, 1.0, 0))
	await _frames(10)
	await _shot("07_the_centipede_waits_by_the_way_in")
	# The Ghost Glade
	p.global_position = Vector3(-26, 1, 8)
	await _frames(40)
	var gh := s.ghost_node(0) as Node3D
	var gat := gh.global_position if gh else Vector3(-26, 0, -4)
	_look(gat + Vector3(3.5, 2.6, 5.0), gat + Vector3(0, 1.0, 0))
	await _frames(10)
	await _shot("08_shadow_ghosts_in_the_glade")
	# The Big Hole
	p.global_position = Vector3(0, 1, 12)
	await _frames(10)
	_look(Vector3(7, 7, 10), Vector3(0, -1, 0))
	await _frames(10)
	await _shot("09_the_big_hole")
	# The Crooked Spire
	_look(Vector3(8, 6, 4), Vector3(22, 10, -18))
	await _frames(10)
	await _shot("10_the_crooked_spire")
	p.global_position = Vector3(22, 15.5, -18)
	await _frames(20)
	_look(Vector3(25, 19, -12), Vector3(0, 0, 0))
	await _frames(10)
	await _shot("11_the_view_from_the_spire")
	# The Hollow Run and Pip
	var race := s.get_node_or_null("Race hollow_run") as Node3D
	if race:
		var pip := race.find_child("Pip", true, false) as Node3D
		var at := pip.global_position if pip else race.global_position
		_look(at + Vector3(-5, 3, 6), at + Vector3(0, 1.2, 0))
		await _frames(10)
		await _shot("12_pip_starts_the_hollow_run")
	# The Hush asleep
	p.global_position = Vector3(0, 1, -6)
	await _frames(10)
	_look(Vector3(8, 6, -12), Vector3(0, 2, -28))
	await _frames(10)
	await _shot("13_the_hush_asleep_on_its_hill")
	# Awake: in the dark, then caught in a lamp's light
	for i in 3:
		portals.note_found("dark_hollow", "piece_%d" % (i + 1))
	s.wake_hush()
	var h := s.hush() as Node3D
	h.process_mode = Node.PROCESS_MODE_DISABLED
	for i in s.LAMPS:
		s.snuff_lamp(i)
	h.global_position = Vector3(0, 0.6, -28)
	await _frames(30)
	_look(Vector3(5, 5, -14), h.global_position + Vector3(0, 3, 0))
	await _frames(10)
	await _shot("14_the_hush_in_the_dark")
	s.light_lamp(0)
	var lamp: Vector3 = s.lamp_pos(0)
	h.global_position = lamp + (Vector3(0, 0, -28) - lamp).normalized() * 4.0
	h.set("lit", true)                                       # (its own _look() eases it pale; it stays put meanwhile)
	for k in 40:
		h.call("_look", 0.05)
	await _frames(10)
	_look(lamp + Vector3(8, 5, 8), h.global_position + Vector3(0, 3, 0))
	await _frames(10)
	await _shot("15_caught_in_a_moon_lamps_light")
	# Mended
	h.process_mode = Node.PROCESS_MODE_INHERIT
	h.call("defeat")
	await create_timer(s.MEND_TIME + 1.0).timeout
	root.get_node("Dialogue").end()
	_look(Vector3(0, 8, 30), Vector3(0, 30, -120))
	await _frames(20)
	await _shot("16_mended_the_moon_clock_ticks_on")
	_look(Vector3(-6, 5, 2), Vector3(0, 1, -28))
	await _frames(10)
	await _shot("17_mended_hush_hill")


func game_go(path: String) -> void:
	change_scene_to_file(path)


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
