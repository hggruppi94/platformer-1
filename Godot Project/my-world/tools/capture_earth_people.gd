extends SceneTree

# Pictures of the people of the Earth town (scripts/townsfolk.gd, tools/build_earth.gd): everyone lined up on the
# green, close-ups in threes, the Blastoffs, and people about their day round town (morning, afternoon and evening).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_people.gd -- <output folder> [only]
#
# Pass a shot's name (or part of it) as "only" to take just that one. Your own save is put aside and put back.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_people_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_people_shots"
var only := ""
var cam: Camera3D
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	clock = root.get_node("Clock")
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.earth_minutes = 12 * 60.0
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	await create_timer(1.5).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	player.global_position = Vector3(60, 1, 60)
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()
	# About their day first, with their routines running
	await _about("10_main_street_morning", 9.5, Vector3(-2, 2.6, -36), Vector3(0, 1.4, -62))
	await _about("11_the_green_afternoon", 15.5, Vector3(14, 3.0, 22), Vector3(-2, 1.0, 4))
	await _about("12_the_diner_afternoon", 15.5, Vector3(-3, 2.4, -16), Vector3(-8, 1.2, -26))
	await _about("13_skate_yard_after_school", 16.0, Vector3(6, 3.2, -88), Vector3(16, 1.0, -93))
	await _about("14_the_green_evening", 19.5, Vector3(14, 3.0, 22), Vector3(-2, 1.0, 4))
	await _about("15_mr_palmer_at_the_oak", 23.9, Vector3(-2.5, 2.2, 21), Vector3(-6, 1.2, 13))
	await _about("16_inside_the_bakery", 10.0, Vector3(-5.2, 2.0, -45), Vector3(-12, 1.0, -46))
	await _about("17_inside_the_library", 10.0, Vector3(-10, 3.0, -83), Vector3(-20, 1.8, -85))
	await _about("18_nina_in_her_room", 20.5, Vector3(-45.5, 2.2, 74.0), Vector3(-45.5, 0.9, 77.5))
	# Then everyone stood still in a row, on the green at noon
	var folk: Array = current_scene.find_children("*", "Townsfolk", true, false)
	for f in folk:
		var r: Node = f.get_node_or_null("Routine")
		if r:
			r.process_mode = Node.PROCESS_MODE_DISABLED
		f.visible = true
	_set_hour(12.0)
	var lineup := ["Mr. Palmer", "Miss Ivy", "Gus", "Dottie Pennywhistle", "Barnaby Quill", "Miss Marigold", "Poppy Crumb",
		"Mr. Gumdrop", "Mrs. Wren", "Hank", "Kip", "Mr. Page", "Madame Celeste", "Theo", "Juniper", "Ozzie", "Nina", "Prue",
		"Bruno"]
	var people: Array[Node3D] = []
	for n in lineup:
		var p := current_scene.find_child(n.replace(".", ""), true, false) as Node3D
		if p:
			people.append(p)
	for i in people.size():
		people[i].global_position = Vector3(10.35 - i * 1.15, 0.03, -6.5)
		people[i].global_rotation = Vector3(0, PI, 0)
	await _shot_at("01_everyone", Vector3(0, 2.4, -21.5), Vector3(0, 0.9, -6.5), 75.0)
	var groups := [[0, 3], [3, 6], [6, 9], [9, 12], [12, 15], [16, 19]]
	for k in groups.size():
		var a: int = groups[k][0]
		var b: int = mini(groups[k][1], people.size())
		var mid := (people[a].global_position + people[b - 1].global_position) / 2.0
		await _shot_at("%02d_close_%s" % [k + 2, "_".join(lineup.slice(a, b)).to_lower().replace(" ", "_").replace(".", "")],
			mid + Vector3(0, 1.3, -4.0), mid + Vector3(0, 1.0, 0), 50.0)
	# The Blastoffs from the side and the back, to see Nina's bow and Bruno's board
	var mid2 := people[17].global_position
	await _shot_at("08_blastoffs_three_quarter", mid2 + Vector3(-2.6, 1.4, -2.6), mid2 + Vector3(0, 0.9, 0), 50.0)
	_finish()


func _about(file: String, hour: float, from: Vector3, look: Vector3) -> void:
	if only != "" and not file.contains(only):
		return
	_set_hour(hour)
	clock.jumped.emit()
	await create_timer(0.8).timeout
	await _shot_at(file, from, look, 70.0)


func _shot_at(file: String, from: Vector3, look: Vector3, fov: float) -> void:
	if only != "" and not file.contains(only):
		return
	cam.global_position = from
	cam.look_at(look)
	cam.fov = fov
	await create_timer(0.4).timeout
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _set_hour(hour: float) -> void:
	clock.earth_minutes = hour * 60.0
	clock.time_changed.emit()
	if current_scene.has_method("_light"):
		current_scene.call("_light")


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
