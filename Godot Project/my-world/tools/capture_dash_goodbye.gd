extends SceneTree

# Screenshots of the story's ending (scripts/far_future.gd slice three, scripts/dash_goodbye.gd): the Swap-o-Tron
# holding Rex and Rook in their own bodies, Dash telling everyone they're all going home, the homecoming at the Tomorrow
# Clock beat by beat, his letter on the workbench, Rex's banner, and the Old Oak in Lumen City. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_dash_goodbye.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.dash_goodbye_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dash_goodbye_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const ID := "far_future"
const WORLDS := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor",
	"dark_hollow", "far_future"]
# [the goodbye's own clock, name]
const SHOTS := [[2.8, "03_everyone_comes"], [5.5, "04_everyone_came"], [15.0, "05_bramble"],
	[21.5, "06_pip_see_you_later"], [28.5, "07_rex_says_sorry"], [31.5, "08_rook_forgives_him"],
	[38.5, "09_stars_hollow_just_later"], [41.5, "10_his_cap"], [47.8, "11_the_clock_strikes"],
	[50.2, "12_everyone_goes_home"], [53.5, "13_the_beam"], [57.5, "14_the_seam_in_the_sky"], [61.5, "15_see_you_later"]]

var out_dir := "user://dash_goodbye_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(2400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var portals := root.get_node("Portals")
	var dialogue := root.get_node("Dialogue")
	game._reset_state()
	game.hold_saves = true
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in WORLDS:
		portals.quakes.append(w)
		portals.cleared_worlds.append(w)
	for f in ["swap_try_start", "swap_tried", "beat_agent_of_chaos", "popped_gloop_king"]:
		dialogue.flags[f] = true
	for i in 3:
		portals.note_found(ID, "core_%d" % (i + 1))
	portals.note_found(ID, "thanked")
	change_scene_to_file(TOWN)
	await _frames(10)
	portals.enter(ID)
	await _frames(20)
	var s := current_scene
	var p := s.get_tree().get_first_node_in_group("player") as CharacterBody3D

	# The lever, for good
	var tron := s.get_node("SwapOTron") as Node3D
	p.global_position = tron.global_position + Vector3(1.5, 1.0, 5.5)
	await _frames(30)
	s.get_node("SwapOTron/Spot").use()
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.global_position = tron.global_position + Vector3(4.5, 3.2, 6.5)
	cam.look_at(tron.global_position + Vector3(0, 1.3, 0))
	cam.make_current()
	await create_timer(float(s.FOR_GOOD_HOLD) + 0.4).timeout
	await _shot("01_it_holds")
	await create_timer(float(s.SWAP_DONE) - float(s.FOR_GOOD_HOLD) + 0.2).timeout
	cam.global_position = tron.global_position + Vector3(6.5, 2.6, 4.0)
	cam.look_at((s.get_node("Dash") as Node3D).global_position + Vector3(0, 1.2, 0))
	for i in 6:                                   # on to "the Shift sends everyone back where they belong"
		dialogue.call("_next")
		await _frames(2)
	await create_timer(1.5).timeout
	await _shot("02_dash_tells_them")
	dialogue.end()
	await _frames(6)
	cam.queue_free()

	# The goodbye
	var dash := s.get_node("Dash") as Node3D
	p.global_position = dash.global_position + Vector3(0, 1.0, 5.0)
	await _frames(4)
	var g: Node = s.get("goodbye")
	for shot in SHOTS:
		while g.playing() and float(g.get("_t")) < float(shot[0]):
			await process_frame
		await _shot(str(shot[1]))
	while g.playing():
		await process_frame
	await _frames(10)

	# His letter
	var letter := s.get_node("Letter") as Node3D
	p.global_position = letter.global_position + Vector3(2.5, 1.0, 0.5)
	cam = Camera3D.new()
	s.add_child(cam)
	cam.global_position = letter.global_position + Vector3(2.6, 2.0, 1.6)
	cam.look_at(letter.global_position + Vector3(0, 1.1, 0))
	cam.make_current()
	await _frames(20)
	await _shot("16_his_letter")
	letter.get_node("Spot").use()
	await create_timer(1.6).timeout
	await _shot("17_reading_it")
	dialogue.end()
	await _frames(6)

	# Rex's banner by the clock, with the three of them home
	var banner := s.get_node("Mayor Banner") as Node3D
	cam.global_position = banner.global_position + banner.global_basis.z * 7.0 + Vector3(-2.0, 2.4, 0)
	cam.look_at(banner.global_position + Vector3(-1.5, 1.6, 0))
	await _frames(20)
	await _shot("18_rex_for_mayor")

	# The Old Oak in Lumen City
	var oak := s.get_node("Old Oak") as Node3D
	p.global_position = oak.global_position + Vector3(1.5, 1.0, 4.0)
	cam.global_position = oak.global_position + Vector3(6.0, 3.0, 11.0)
	cam.look_at(oak.global_position + Vector3(0, 4.0, 0))
	await _frames(20)
	await _shot("19_the_old_oak")
	oak.get_node("Spot").use()
	await create_timer(1.6).timeout
	await _shot("20_it_hums")
	dialogue.end()

	_finish()


func _finish() -> void:
	var game := root.get_node_or_null("Game")
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
