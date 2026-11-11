extends SceneTree

# Screenshots of the story's ending (scripts/far_future.gd slice three, scripts/dash_goodbye.gd): the Swap-o-Tron
# holding Rex and Rook in their own bodies, Dash telling everyone, the goodbye at the Tomorrow Clock beat by beat, his
# letter on the workbench, and Rex and Rook back in the Void in their own bodies. Opens a window (not --headless):
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
const SHOTS := [[2.8, "03_everyone_comes"], [5.0, "04_dash_says_goodbye"], [15.0, "05_bramble_asks"],
	[21.5, "06_pip_see_you_later"], [31.5, "07_rex"], [38.5, "08_his_cap"], [45.5, "09_up_to_the_clock"],
	[47.2, "10_one_last_wave"], [49.0, "11_into_the_light"], [51.0, "12_the_beam"], [54.5, "13_the_seam_in_the_sky"],
	[58.5, "14_see_you_later"]]

var out_dir := "user://dash_goodbye_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	for i in 5:                                   # on to "a crack has two ends"
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
	await _shot("15_his_letter")
	letter.get_node("Spot").use()
	await create_timer(1.6).timeout
	await _shot("16_reading_it")
	dialogue.end()

	# Back in the Void: Rex and Rook in their own bodies
	portals.go_home()
	await _frames(30)
	var town := current_scene
	var rex: Node3D
	var rook: Node3D
	for r in town.find_children("Routine", "", true, false):
		if str(r.get("character_id")) == "rex":
			rex = r.get_parent()
		elif str(r.get("character_id")) == "rook":
			rook = r.get_parent()
	if rex and rook:
		var mid := rex.global_position.lerp(rook.global_position, 0.5)
		rook.global_position = rex.global_position + rex.global_basis.x * 1.6
		rex.get_node("Routine").process_mode = Node.PROCESS_MODE_DISABLED
		rook.get_node("Routine").process_mode = Node.PROCESS_MODE_DISABLED
		mid = rex.global_position.lerp(rook.global_position, 0.5)
		var c2 := Camera3D.new()
		town.add_child(c2)
		var front := rex.global_basis.z.normalized()
		c2.global_position = mid + front * 4.5 + Vector3(0, 1.8, 0)
		c2.look_at(mid + Vector3(0, 1.0, 0))
		c2.make_current()
		await _frames(20)
		await _shot("17_rex_and_rook_in_the_void")
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
