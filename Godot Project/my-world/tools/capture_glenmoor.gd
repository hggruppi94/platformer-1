extends SceneTree

# Screenshots of Glenmoor, Heather's portal world (scripts/glenmoor.gd): its portal in the meadow past the farm, the
# glen looping between day and night (day, dusk and night), the Sunfolk and Moonfolk camps cheering their own time,
# Heather and Isla, herding the Fluffkins into the Fold, the garden's moonflowers open at night, the hill race up Ben
# Bonnie, the Stormram asleep on the Standing Stones and then charging in its whirlwind, and a normal morning with the
# two sides at peace once it's mended. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_glenmoor.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.glenmoor_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.glenmoor_capture_backup.cfg"

var out_dir := "user://glenmoor_shots"
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
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("glenmoor", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal glenmoor") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(3.5, 3.0, 0), portal.global_position + Vector3(0, 2.6, 0))
	await _frames(30)
	await _shot("01_portal_in_the_meadow")


func _inside() -> void:
	portals.enter("glenmoor")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	_hold_time(s)
	await _frames(10)
	# Day and night looping: the same view by day, at dusk and at night
	for pair in [[0.05, "02_the_glen_by_day"], [0.27, "03_seconds_later_dusk"], [0.5, "04_and_then_night"]]:
		s.set_daylight(pair[0])
		_look(Vector3(-4.0, 9.0, 44.0), Vector3(0, 2.0, -10.0))
		await _frames(2)
		await _shot(pair[1])
	# The two camps, each cheering its own time
	var sun := (s.get_node("Sunfolk") as Node3D).global_position
	var moon := (s.get_node("Moonfolk") as Node3D).global_position
	var mid := (sun + moon) / 2.0
	s.set_daylight(0.05)
	s._cheer(true)
	_look(sun + (sun - mid).normalized() * -2.0 + Vector3(0, 3.0, 9.0), sun + Vector3(0, 1.2, 0))
	await create_timer(0.3).timeout
	await _shot("04b_the_sunfolk_cheer_the_day")
	s.set_daylight(0.5)
	s._cheer(false)
	_look(moon + Vector3(0, 3.0, 9.0), moon + Vector3(0, 1.2, 0))
	await create_timer(0.3).timeout
	await _shot("04c_the_moonfolk_cheer_the_night")
	s.set_daylight(0.05)
	# Heather, and Isla
	var hz := (s.get_node("Heather") as Node3D).global_position
	var hb := (s.get_node("Heather") as Node3D).global_basis.z
	p.global_position = hz + hb * 3.0 + Vector3(2.5, 0.9, 0)
	await create_timer(0.6).timeout
	s.set_daylight(0.1)
	_look(hz + hb * 3.4 + Vector3(-0.6, 1.5, 0), hz + Vector3(0, 1.0, 0))
	await _shot("05_heather_at_home")
	var isla := s.get_node("Isla Runner") as Node3D
	var iz := isla.global_position
	s.set_daylight(0.05)
	_look(iz + isla.global_basis.z * 3.4 + Vector3(0.8, 1.4, 0), iz + Vector3(0, 0.9, 0))
	await _shot("06_isla_her_best_friend")
	# Herding the Fluffkins into the Fold
	var fold := (s.get_node("Fold") as Node3D).global_position
	for i in 3:
		s.pen_fluff(i)
		var f: Node3D = s.fluffkin(i)
		var a := i * 2.1
		f.global_position = fold + Vector3(cos(a), 0, sin(a)) * 2.0
	var f4: Node3D = s.fluffkin(3)
	f4.global_position = fold + Vector3(8.5, 0, 1.0)
	p.global_position = fold + Vector3(12.0, 0.9, 1.5)
	await _frames(3)
	s.set_daylight(0.08)
	_look(fold + Vector3(14.0, 6.0, 10.0), fold + Vector3(3.0, 0.5, 0))
	await _shot("07_herding_fluffkins_into_the_fold")
	p.global_position = Vector3(0, 0.9, 30)
	# The garden: plants growing, blooming and wilting at different times
	var bed := (s.get_node("Bed3") as Node3D).global_position
	s.set_daylight(0.5)
	_look(bed + Vector3(-3.0, 3.0, 6.0), bed + Vector3(0, 0.4, 0))
	await _frames(2)
	await _shot("08_the_garden_at_night_moonflowers_open")
	s.set_daylight(0.05)
	# The hill race
	s.start_race()
	await create_timer(4.2).timeout
	var line := s.get_node("RaceLine") as Path3D
	var at := line.to_global(line.curve.sample_baked(line.curve.get_baked_length() * 0.35))
	p.global_position = at + Vector3(0.8, 1.0, 0.8)
	s._isla_d = line.curve.get_baked_length() * 0.33
	await _frames(3)
	s.set_daylight(0.12)
	var hill := (s.get_node("Hill") as Node3D).global_position
	_look(at + (at - hill).normalized() * 9.0 + Vector3(0, 4.0, 0), at + Vector3(0, 1.0, 0))
	await _shot("09_racing_isla_up_ben_bonnie")
	s.end_race(true)
	for i in 5:
		s.pen_fluff(i)
	await create_timer(0.2).timeout
	# The Stormram, asleep...
	var stones := (s.get_node("Stormram") as Node3D).global_position
	s.ring_bell(1, Vector3.ZERO)
	p.global_position = Vector3(0, 0.9, 30)
	await _frames(4)
	_look(stones + Vector3(3.0, 8.0, 12.0), stones + Vector3(0, 1.2, 0))
	await _shot("10_the_stormram_asleep_on_the_standing_stones")
	# ...and charging in its whirlwind
	var storm := s.stormram as CharacterBody3D
	p.global_position = stones + Vector3(0, 0.9, 13.0)
	storm.set("_cooldown", 0.0)
	var t := 0
	while t < 400 and not (storm.get_node("Visual/Whirlwind") as Node3D).visible:
		await physics_frame
		t += 1
	await create_timer(0.35).timeout
	var sp := storm.global_position
	_look(sp + Vector3(2.0, 9.0, 10.0), sp + Vector3(0, 1.0, 0))
	await _shot("11_the_stormram_charges_in_a_whirlwind")
	# Mended: spring, to stay
	p.global_position = Vector3(0, 0.9, 30)
	while not storm.get("defeated"):
		storm.call("_set_state", 4)
		storm.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await create_timer(1.2).timeout
	_look(stones + Vector3(3.0, 9.0, 13.0), stones + Vector3(0, 1.0, 0))
	await _shot("12_popped")
	await create_timer(3.5).timeout
	if root.get_node("Dialogue").is_active():
		root.get_node("Dialogue").end()
	await _frames(4)
	_look(Vector3(-4.0, 9.0, 44.0), Vector3(0, 2.0, -10.0))
	await _shot("13_a_normal_morning_in_glenmoor")
	var peace := (s.get_node("Peace Banner") as Node3D).global_position
	_look(peace + Vector3(0, 2.5, 8.0), peace + Vector3(0, 2.4, 0))
	await _shot("14_peace_one_banner_half_day_half_night")


func _hold_time(s: Node) -> void:
	# (the flux would move the sky on between setting it and the shot)
	s.set("_flux", 0.0)
	s.set("_flux_left", 9999.0)


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
