extends SceneTree

# Screenshots of the lost watches (scripts/watches.gd): all twenty in a little studio, a few where they're hidden in
# town and at school, the card when one's found, the Bag's Watches page, the map with found ones marked, and the
# hero wearing the Time Keeper with the Clockwork Star Popper. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_lost_watches.gd -- <output folder>
#
# Your own save is put aside (under its own name) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.watches_capture_backup.json"

var out_dir := "user://lost_watches_shots"
var cam: Camera3D
var _had_save := false


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
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	root.get_node("Settings").tips = false
	root.get_node("Dialogue").reset()
	await _lineup()
	await _in_world()
	await _menus()
	_finish()


func _lineup() -> void:
	# All twenty in five rows of four, turning a little, on a dark purple stage with soft coloured lights
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.05, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.65, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	env.environment = e
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-30, 25, 0)
	stage.add_child(key)
	var watches := root.get_node("Watches")
	var models: Array[Node3D] = []
	var all: Array = watches.WATCHES
	for k in all.size():
		var m: Node3D = watches.model(all[k].id)
		m.position = Vector3((k % 5 - 2) * 0.5, 0.75 - (k / 5) * 0.5, 0)
		stage.add_child(m)
		models.append(m)
		var label := Label3D.new()
		label.text = all[k].name
		label.font_size = 28
		label.pixel_size = 0.0012
		label.outline_size = 6
		label.modulate = Color(1.0, 0.9, 0.6)
		label.position = m.position + Vector3(0, -0.2, 0)
		stage.add_child(label)
	cam = Camera3D.new()
	cam.fov = 40
	stage.add_child(cam)
	cam.make_current()
	for i in 20:
		await process_frame
		for k in models.size():
			models[k].rotation.y = 0.35 * sin(i * 0.05 + k)
			watches.animate(models[k], i / 30.0)
	await _view("01_all_twenty", Vector3(0, 0.0, 3.4), Vector3(0, 0.0, 0))
	# A few close up
	for pair in [["many_hands", "02_close_many_hands"], ["orrery", "03_close_orrery"], ["cuckoo", "04_close_cuckoo"]]:
		var k: int = all.find(watches.watch(pair[0]))
		var at: Vector3 = models[k].position
		await _view(pair[1], at + Vector3(0.12, 0.08, 0.55), at)
	stage.queue_free()
	await process_frame


func _in_world() -> void:
	var watches := root.get_node("Watches")
	change_scene_to_file(watches.SCENES.town)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 11 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as CharacterBody3D
	player.get_node("HUD").visible = false
	player.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	# [watch, camera offset from it, where the hero stands (offset), file]
	var spots := [
		["water_clock", Vector3(3.5, 1.2, 5.0), Vector3(1.5, -1.9, 2.0), "05_on_the_fountain"],
		["cuckoo", Vector3(7.0, 2.5, 4.0), Vector3(1.5, -0.5, 0.5), "06_tree_house_deck"],
		["seashell", Vector3(2.5, 1.2, 3.5), Vector3(1.2, -0.7, 1.2), "07_out_on_the_lake"],
		["pocket", Vector3(4.0, 2.5, 6.0), Vector3(0, 30, 0), "08_town_hall_dome"],
		["orrery", Vector3(10.0, 5.0, 14.0), Vector3(0, 60, 0), "09_castle_spire"],
		["backwards", Vector3(-6.0, 3.0, 12.0), Vector3(-1.5, -0.1, 2.0), "10_chaos_field"],
		["robot", Vector3(3.0, 1.6, 6.0), Vector3(2.5, -0.5, 1.0), "11_castle_hill_rail"],
		["galaxy", Vector3(0, 6.0, 28.0), Vector3(0, -110, 0), "12_in_the_sky_over_the_castle"],
	]
	for s in spots:
		var w: Dictionary = watches.watch(s[0])
		player.global_position = w.pos + s[2]
		var at: Vector3 = w.pos + s[1]
		await _view(s[3], at, w.pos, 20)
	# Picking one up: the card
	var w0: Dictionary = watches.watch("egg_timer")
	player.set_physics_process(true)
	player.global_position = w0.pos + Vector3(0, 0.0, 0.4)
	for i in 20:
		await process_frame
	player.get_node("HUD").visible = true
	await _view("13_found_one_the_card", w0.pos + Vector3(2.5, 1.8, 5.0), w0.pos)
	player.get_node("HUD").visible = false
	# School: the window sill
	change_scene_to_file(watches.SCENES.school)
	for i in 10:
		await process_frame
	var school := current_scene as Node3D
	var sp := school.find_child("Player", true, false) as CharacterBody3D
	if sp:
		sp.get_node("HUD").visible = false
		sp.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 55
	school.add_child(cam)
	cam.make_current()
	var wb: Dictionary = watches.watch("beads")
	if sp:
		sp.global_position = wb.pos + Vector3(-2.0, -0.2, 2.5)
	await _view("14_school_window_sill", wb.pos + Vector3(2.0, 0.8, 4.5), wb.pos, 20)
	var wf: Dictionary = watches.watch("flower")
	await _view("15_school_greenhouse", wf.pos + Vector3(2.5, 1.0, 2.5), wf.pos, 20)


func _menus() -> void:
	# Back in town with some found and given, wearing the Time Keeper and holding the Clockwork Popper
	var watches := root.get_node("Watches")
	var dialogue := root.get_node("Dialogue")
	var game := root.get_node("Game")
	for w in watches.WATCHES.slice(0, 12):
		dialogue.set_flag("watch_found_" + str(w.id))
	for w in watches.WATCHES.slice(0, 9):
		dialogue.set_flag("watch_given_" + str(w.id))
	change_scene_to_file(watches.SCENES.town)
	for i in 10:
		await process_frame
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as CharacterBody3D
	player.global_position = Vector3(-60, 1.0, 62)
	for i in 10:
		await process_frame
	var menu := root.get_node("PlayerMenu")
	menu.open("bag")
	for i in 6:
		await process_frame
	var scroll := menu.find_child("Watches", true, false) as Control
	var sc := scroll.get_parent().get_parent() as ScrollContainer if scroll else null
	if sc:
		sc.scroll_vertical = int(scroll.position.y) - 10
	var grid := menu.find_child("Watch Grid", true, false)
	if grid:
		(grid.get_node("pocket") as Button).grab_focus()
	for i in 20:
		await process_frame
	await _shot("16_bag_watches_page")
	if grid:
		(grid.get_node("galaxy") as Button).grab_focus()
	for i in 10:
		await process_frame
	await _shot("17_bag_a_missing_one")
	menu.show_sheet("map")
	for i in 10:
		await process_frame
	await _shot("18_map_found_watches")
	menu.close()
	for i in 4:
		await process_frame
	# The rewards: hand the rest in, wear the Time Keeper (wrist), hold the popper out
	for w in watches.WATCHES:
		dialogue.set_flag("watch_found_" + str(w.id))
	watches.watches_hand_in()
	game.outfit["hands"] = "time_keeper_watch"
	game.outfit["neck"] = "time_keeper_pendant"
	game.equipment_changed.emit()
	player.get_node("HUD").visible = false
	player.set_physics_process(false)
	var popper := player.find_child("StarPopper", true, false)
	cam = Camera3D.new()
	cam.fov = 35
	town.add_child(cam)
	cam.make_current()
	var visual := player.get_node("Visual") as Node3D
	visual.rotation.y = 0.0
	if popper:
		popper.set("_raise", 99.0)
	var p := player.global_position
	await _view("19_wearing_the_time_keeper", p + Vector3(0.6, 0.4, 2.6), p + Vector3(0, 0.0, 0), 20)
	await _view("20_time_keeper_close_up", p + Vector3(0.25, 0.1, 1.2), p + Vector3(0.1, -0.1, 0), 10)


func _view(file: String, at: Vector3, look: Vector3, frames := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in frames:
		await process_frame
	await _shot(file)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	quit()
