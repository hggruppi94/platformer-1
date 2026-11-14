extends SceneTree

# Screenshots of the cutscene for each crack that opens (scripts/crack_opening.gd; Hayden, 14 Nov 2026: "more obvious
# when a crack opens up, with a cutscene for each one"): every portal world's quake in the Void, four moments each
# (the shake where you are, the ground splitting with its pillar of light, the look down it, the world's name), then
# the crack by the old oak on Earth. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_crack_opening.gd -- <output folder> [world ids...]
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.crack_opening_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.crack_opening_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
# When in each cutscene to take its four pictures (seconds from the start)
const MOMENTS := [[1.6, "a_shake"], [4.6, "b_splits"], [8.2, "c_down_it"], [11.6, "d_name"]]

var out_dir := "user://crack_opening_shots"
var only: Array = []
var _had_save := false
var portals: Node
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		only.append(args[i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(2400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	game = root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	var dialogue := root.get_node("Dialogue")
	for f in ["fn_fell", "oak_woken", "fn_arrived", "fn_met_tally"]:
		dialogue.flags[f] = true
	change_scene_to_file(TOWN)
	await _wait_for(TOWN)
	await create_timer(2.0).timeout
	var n := 0
	for w in portals.WORLDS:
		var id := str(w.id)
		if not portals.has_portal(id) or not portals.is_built(id) or (not only.is_empty() and not id in only):
			continue
		n += 1
		await _quake(id, "%02d_%s" % [n, id])
	if only.is_empty() or "earth" in only:
		await _earth(clock)
	_finish()


func _quake(id: String, name: String) -> void:
	# Each from the Market Square, as if you were just stood about in town
	var p := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	if p:
		p.global_position = root.get_node("Remnants").ground_at(Vector2(-72, 50)) + Vector3(0, 0.5, 0)
	await create_timer(0.6).timeout
	portals.quake(id)
	var t := 0.0
	for m in MOMENTS:
		await create_timer(float(m[0]) - t).timeout
		t = float(m[0])
		await _shot("%s_%s" % [name, m[1]])
	while portals.opening_cut.playing():
		await process_frame
	await create_timer(9.0).timeout              # (till the voice in your mind has finished, so it's not in the next one)


func _earth(clock: Node) -> void:
	clock.set_earth_time(22 * 60.0, true)
	change_scene_to_file(EARTH)
	await _wait_for(EARTH)
	await create_timer(2.0).timeout
	clock.set_earth_time(0.1, true)
	while not portals.opening_cut.playing():
		await process_frame
	var t := 0.0
	for m in [[1.4, "a_midnight"], [4.6, "b_splits"], [7.6, "c_down_it"], [10.6, "d_name"]]:
		await create_timer(float(m[0]) - t).timeout
		t = float(m[0])
		await _shot("20_earth_oak_%s" % m[1])


func _shot(file: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("shot ", file)


func _wait_for(path: String) -> void:
	for i in 1200:
		if current_scene and current_scene.scene_file_path == path:
			break
		await process_frame
	await create_timer(1.0).timeout


func _finish() -> void:
	if _had_save and FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
