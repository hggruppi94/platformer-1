extends SceneTree

# Screenshots of the Tide Reef, Otto the octopus's portal world (scripts/tide_reef.gd): its portal by the lake's
# south-east shore, arriving with the tide stuck out, Otto in his bubble chair, his eight arms opening the Clam Vault, the Kelp
# Grotto's holes, his bubble steps up the Coral Spire, the bubble ride down, the Riptide Gloop asleep, Otto holding it
# still, and the reef with the tide back in. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_tide_reef.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.tide_reef_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tide_reef_capture_backup.cfg"

var out_dir := "user://tide_reef_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _portal()
	if OS.get_cmdline_user_args().size() < 2 or OS.get_cmdline_user_args()[1] != "portal":       # ("portal": only its shot)
		await _inside()
	_finish()


func _portal() -> void:
	game_go("res://scenes/town/town.tscn")
	await _frames(16)
	portals.quake("tide_reef", true)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var portal := s.get_node("Portals/Portal tide_reef") as Node3D
	p.global_position = portal.global_position + portal.global_basis.z * 7.0 + Vector3(0, 1, 0)
	await _frames(40)
	_cam_in(s)
	_look(portal.global_position + portal.global_basis.z * 10.0 + Vector3(0, 3.0, 3.5), portal.global_position + Vector3(0, 2.6, 0))
	await _frames(30)
	await _shot("01_portal_by_the_lake")


func _inside() -> void:
	portals.enter("tide_reef")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	await _frames(10)
	_look(Vector3(-5.0, 7.0, 46.0), Vector3(0, 2.5, -10.0))
	await _shot("02_arriving_the_tide_stuck_out")
	_look(Vector3(14.0, 22.0, 34.0), Vector3(-4, 0.0, -8.0))
	await _shot("03_the_dry_reef_from_above")
	# Otto
	var otto: Vector3 = s.otto_at()
	p.global_position = otto + Vector3(-1.6, 0.9, 2.6)
	await create_timer(0.8).timeout
	_look(otto + Vector3(-1.4, 1.7, 3.6), otto + Vector3(0, 1.2, 0))
	await _shot("04_otto_in_his_bubble_chair")
	s.otto_lines()                                               # (met)
	# Following you
	p.global_position = Vector3(-6, 0.9, 18)
	await create_timer(2.5).timeout
	_look(p.global_position + Vector3(4.5, 2.6, 5.0), p.global_position + Vector3(1.0, 0.6, 0))
	await _shot("05_ottos_bubble_follows_you")
	# The Clam Vault
	var vault := (s.get_node("Vault") as Node3D).global_position
	var clam := (s.get_node("Clam Vault") as Node3D).global_position
	p.global_position = vault + Vector3(0, 0.9, 0)
	await _otto_here(s, vault)
	_look(vault + Vector3(5.0, 3.5, 7.0), clam + Vector3(0, 1.0, 0))
	await _shot("06_the_clam_vault_eight_latches")
	s.open_vault()
	await create_timer(0.7).timeout
	await _shot("07_eight_arms_eight_latches")
	await create_timer(2.6).timeout
	await _shot("08_the_vault_open_first_pearl")
	s.take_pearl(0)
	# The Kelp Grotto
	var hole := (s.get_node("Hole2") as Node3D).global_position
	p.global_position = hole + Vector3(-1.6, 0.9, 0.8)
	await _otto_here(s, hole)
	_look(hole + Vector3(-7.5, 2.8, 2.5), hole + Vector3(0, 1.2, 0))
	await _shot("09_kelp_grotto_which_hole")
	s.try_hole(s.right_hole)
	await create_timer(0.6).timeout
	await _shot("10_otto_reaches_in")
	# The Coral Spire and the bubble steps
	var pad := (s.get_node("BubblePad") as Node3D).global_position
	var spire := (s.get_node("Coral Spire") as Node3D).global_position
	p.global_position = pad + Vector3(0.8, 0.9, 0.8)
	await _otto_here(s, pad)
	s.blow_steps()
	await create_timer(2.6).timeout
	var top := (s.get_node("Pearl3") as Node3D).global_position
	_look(pad + Vector3(9.0, 4.0, 10.0), Vector3(top.x, 5.0, top.z))
	await _shot("11_bubble_steps_up_the_coral_spire")
	p.global_position = (s.get_node("Step5") as Node3D).global_position + Vector3(0, 1.3, 0)
	await create_timer(0.9).timeout
	var st := p.global_position
	_look(st + Vector3(5.0, 2.5, 4.0), st + Vector3(-1.0, 0.5, -1.0))
	await _shot("12_hopping_up_the_bubbles")
	p.global_position = top + Vector3(0.6, 0.9, 1.4)
	await _frames(6)
	_look(top + Vector3(3.5, 2.6, 5.5), top + Vector3(0, 0.8, 0))
	await _shot("13_the_pearl_on_top")
	s.take_pearl(2)
	s.ride_bubble()
	await create_timer(2.4).timeout
	var at := p.global_position
	_look(at + Vector3(4.0, 1.5, 5.0), at)
	await _shot("14_riding_a_bubble_down")
	while s.riding:
		await physics_frame
	await create_timer(0.5).timeout
	# The Riptide Gloop
	var basin := (s.get_node("RiptideGloop") as Node3D).global_position
	if not s.riptide_awake:
		p.global_position = basin + Vector3(20, 0.9, 22)
		await _frames(6)
		_look(basin + Vector3(6.0, 4.5, 15.0), basin + Vector3(0, 2.2, 0))
		await _shot("15_the_riptide_gloop_asleep")
	p.global_position = basin + Vector3(-4.0, 0.9, 13.0)
	var t := 0
	while t < 1500 and not bool(s.riptide.get("held")):
		await physics_frame
		t += 1
		if p.global_position.distance_to(s.riptide.global_position) < 7.0:
			p.global_position = basin + Vector3(-12.0, 0.9, 15.0)
	await create_timer(0.8).timeout
	var g: Vector3 = s.riptide.global_position
	var o: Vector3 = s.otto_at()
	_look((g + o) / 2.0 + (o - g).normalized().rotated(Vector3.UP, PI / 2.0) * 12.0 + Vector3(0, 4.5, 0), (g + o) / 2.0 + Vector3(0, 1.6, 0))
	await _shot("16_otto_holds_the_riptide_gloop")
	# Mended
	p.global_position = basin + Vector3(20, 0.9, 22)
	while not s.is_mended():
		await physics_frame
		if bool(s.riptide.get("held")) and not bool(s.riptide.get("defeated")):
			s.riptide.shot(1, s.riptide.global_position, Vector3.FORWARD)
	await create_timer(1.0).timeout
	_look(basin + Vector3(8.0, 5.0, 17.0), basin + Vector3(0, 2.0, 0))
	await _shot("17_the_tide_lets_go")
	await create_timer(6.5).timeout
	root.get_node("Dialogue").end()
	_look(Vector3(-5.0, 7.0, 46.0), Vector3(0, 2.5, -10.0))
	await _shot("18_the_tide_back_in")
	_look(Vector3(14.0, 22.0, 34.0), Vector3(-4, 0.0, -8.0))
	await _shot("19_the_reef_in_bloom_from_above")
	var pool := (s.get_node("Tide2") as Node3D).global_position
	p.global_position = pool + Vector3(1.0, 0.9, 0.5)
	await create_timer(3.0).timeout
	_look(pool + Vector3(-5.0, 2.4, 6.0), pool + Vector3(1.0, 0.8, 0))
	await _shot("20_paddling_with_otto")


func _otto_here(s: Node, at: Vector3) -> void:
	# Waits for Otto's bubble to float over, then a moment for him to settle
	var t := 0
	while not s.otto_near(at, 4.5) and t < 1200:
		await process_frame
		t += 1
	await create_timer(0.6).timeout


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
