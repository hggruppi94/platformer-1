extends SceneTree

# Screenshots of Rhythm Springs, Melody's portal world (scripts/rhythm_springs.gd): its portal by the lake, arriving in
# the blazing stuck noon, Melody, the Heat meter, the Sizzle Steps flaring, Waterfall Mesa and the water slide, riding
# the slide, dancing with Melody, the Off-Beat asleep and then awake, and the golden evening once it's mended. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_rhythm_springs.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.rhythm_springs_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rhythm_springs_capture_backup.cfg"

var out_dir := "user://rhythm_springs_shots"
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
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("rhythm_springs", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal rhythm_springs") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(3.5, 3.0, 0), portal.global_position + Vector3(0, 2.6, 0))
	await _frames(30)
	await _shot("01_portal_by_the_lake")


func _inside() -> void:
	portals.enter("rhythm_springs")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	await _frames(10)
	_look(Vector3(-4.0, 6.0, 42.0), Vector3(0, 3.0, -10.0))
	await _shot("02_arriving_the_sun_stuck_at_noon")
	var mel := (s.get_node("Melody") as Node3D).global_position
	p.global_position = mel + Vector3(-1.5, 0.9, 2.2)
	await create_timer(0.8).timeout
	_look(mel + Vector3(-2.4, 1.6, 3.2), mel + Vector3(0, 1.0, 0))
	await _shot("03_melody_at_home")
	s.melody_lines()
	# The Heat meter, getting hot
	s.heat = 72.0
	p.global_position = Vector3(-6, 0.9, 16)
	await _frames(6)
	_look(Vector3(-2.0, 3.0, 24.0), Vector3(-10.0, 1.0, 4.0))
	await _shot("04_heat_meter_getting_hot")
	# The Sizzle Steps, flaring
	s.heat = 30.0
	var pit := (s.get_node("SizzlePit") as Node3D).global_position
	var start := (s.get_node("SizzleStart") as Node3D).global_position
	p.global_position = (s.get_node("Stone3") as Node3D).global_position + Vector3(0, 1.4, 0)
	await create_timer(1.3).timeout
	_look(start + Vector3(5.0, 4.5, 6.0), pit + Vector3(-2.0, 0.0, -2.0))
	await _shot("05_sizzle_steps_flaring")
	# Waterfall Mesa and the slide
	var mesa := (s.get_node("Shell2") as Node3D).global_position
	s.heat = 40.0
	p.global_position = Vector3(10, 0.9, 6)
	await _frames(6)
	_look(Vector3(2.0, 7.0, 10.0), mesa + Vector3(-6.0, -6.0, -2.0))
	await _shot("06_waterfall_mesa_and_the_slide")
	p.global_position = mesa + Vector3(0, 0.9, 0.3)
	await _frames(4)
	s.ride_slide()
	await create_timer(1.6).timeout
	var at := p.global_position
	_look(at + Vector3(-4.0, 3.0, 5.0), at)
	await _shot("07_whee_down_the_water_slide")
	while s.riding_slide:
		await physics_frame
	await create_timer(0.5).timeout
	# Dancing with Melody (the HUD shows the beat ring)
	var floor_at := (s.get_node("DanceFloor") as Node3D).global_position
	p.global_position = floor_at + Vector3(0, 0.9, 0)
	await _frames(6)
	s.start_dance()
	await create_timer(1.1).timeout
	s.dance_good = 5
	s._show_dance()
	_look(floor_at + Vector3(-6.0, 4.0, 7.0), floor_at + Vector3(0, 1.2, 0))
	await _shot("08_dancing_with_melody")
	s.end_dance(true)
	# The Off-Beat, asleep
	var ob := (s.get_node("OffBeat") as Node3D).global_position
	s.take_shell(0)
	_look(ob + Vector3(7.0, 5.0, 17.0), ob + Vector3(0, 3.5, 0))
	p.global_position = Vector3(0, 0.9, 20)
	await _frames(10)
	await _shot("09_the_off_beat_asleep")
	# ...and awake
	p.global_position = ob + Vector3(-3.0, 0.9, 10.0)
	var o := s.off_beat as Node3D
	var t := 0
	while t < 300 and not (o.awake and o.lit_drum >= 0 and _has_ring(s)):
		await physics_frame
		t += 1
	await create_timer(0.25).timeout
	_look(ob + Vector3(9.0, 6.0, 15.0), ob + Vector3(0, 2.5, 2.0))
	await _shot("10_the_off_beat_awake_heat_rings")
	# Back in time: the golden evening
	p.global_position = Vector3(0, 0.9, 20)
	while not o.defeated:
		o._shot_cd = 0.0
		o.shot_weight()
	await create_timer(1.2).timeout
	_look(ob + Vector3(5.0, 3.0, 12.0), ob + Vector3(0, 2.0, 0))
	await _shot("11_back_in_time")
	await create_timer(5.0).timeout
	_look(Vector3(-12.0, 6.0, 40.0), Vector3(10.0, 4.0, -20.0))
	await _shot("12_golden_evening_over_rhythm_springs")


func _has_ring(s: Node) -> bool:
	for c in s.get_children():
		if str(c.name).begins_with("ShockRing"):
			return true
	return false


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
