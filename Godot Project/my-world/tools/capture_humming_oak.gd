extends SceneTree

# Screenshots of the new first day on Earth, the Humming Oak (scripts/humming_oak.gd, res://quests/first_night.json):
# the sunny morning start, Theo and Mr. Page on the green's bench, the old oak by day (just a tree), Mr. Page's book,
# a glowing acorn, the acorns in the roots at dusk with the runes waking, the reveal at midnight, and the oak's door
# open. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_humming_oak.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.humming_oak_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://humming_oak_shots"
var cam: Camera3D
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var oak_mod: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	oak_mod = root.get_node("HummingOak")
	var creator := root.get_node("Creator")
	root.get_node("Settings").tips = false

	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	game.hero["name"] = "Sunny"
	creator.close()
	await _frames(10)
	await _physics(60)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var nina := _body("nina_earth")
	player.global_position = nina.global_position + Vector3(0, 0.5, 2.6)
	await _physics(4)
	await _view("01_a_sunny_morning_nina_knocks", nina.global_position + Vector3(3.5, 2.0, 4.5), nina.global_position + Vector3(0, 1.0, 0), 20)

	# Theo and Mr. Page on the bench
	var bench := current_scene.get_node("Green Bench") as Node3D
	var fwd := -bench.global_position.normalized()
	await _view("02_theo_and_mr_page_on_the_bench", bench.global_position + fwd * 3.2 + Vector3(0.6, 1.4, 0), bench.global_position + Vector3(0, 0.7, 0))
	await _view("03_the_bench_from_the_side", bench.global_position + Vector3(fwd.z, 0, -fwd.x) * 3.0 + fwd * 1.5 + Vector3(0, 1.3, 0), bench.global_position + Vector3(0, 0.6, 0))

	# The old oak by day
	var oak := current_scene.get_node("Portal Home/Old Oak") as Node3D
	var front := oak.global_transform * Vector3(0, 2.5, 11.0)
	await _view("04_the_old_oak_by_day", front, oak.global_transform * Vector3(0, 3.5, 0))
	await _view("05_the_old_oak_close", oak.global_transform * Vector3(1.5, 1.8, 5.0), oak.global_transform * Vector3(0, 1.6, 1.4))

	# The clues: skip ahead to them, and a glowing acorn
	dialogue.set_flag("fn_nina")
	dialogue.set_flag("fn_palmer")
	dialogue.set_flag("fn_folk")
	quests.check()
	dialogue.set_flag("fn_oak_listen")
	quests.check()
	await _frames(6)
	var acorn := current_scene.get_node_or_null("Glowing Acorn 2") as Node3D
	if acorn:
		await _view("06_a_glowing_acorn_in_the_pumpkin_patch", acorn.global_position + Vector3(2.0, 1.0, 2.0), acorn.global_position)
	var a1 := current_scene.get_node_or_null("Glowing Acorn 1") as Node3D
	if a1:
		await _view("07_a_glowing_acorn_by_mossy_falls", a1.global_position + Vector3(-3.0, 1.6, 3.0), a1.global_position)
	var a3 := current_scene.get_node_or_null("Glowing Acorn 3") as Node3D
	if a3:
		await _view("08_a_glowing_acorn_on_lookout_hill", a3.global_position + Vector3(2.5, 1.5, -2.5), a3.global_position)

	# Dusk: the acorns go in, and the runes wake
	for f in ["fn_book", "read_palmer_letter", "fn_acorn_1", "fn_acorn_2", "fn_acorn_3", "fn_acorns"]:
		dialogue.set_flag(f)
	quests.check()
	clock.earth_minutes = 19 * 60.0 + 30.0
	dialogue.set_flag("fn_acorns_placed")
	quests.check()
	await create_timer(1.5).timeout
	await _view("09_dusk_the_runes_wake", oak.global_transform * Vector3(2.5, 2.2, 7.0), oak.global_transform * Vector3(0, 2.6, 1.0))
	clock.earth_minutes = 22 * 60.0 + 30.0
	await create_timer(1.0).timeout
	await _view("10_late_evening_fireflies", oak.global_transform * Vector3(-3.0, 2.0, 8.0), oak.global_transform * Vector3(0, 2.5, 0))

	# Midnight: the reveal
	dialogue.set_flag("fn_midnight")
	quests.check()
	clock.set_earth_time(5.0, true)
	await _frames(6)
	player.global_position = oak.global_transform * Vector3(0, 1.0, 9.0)
	await _frames(4)
	if cam:
		cam.queue_free()
		cam = null
	for i in 160:
		await process_frame
		if oak_mod.revealing and oak_mod._reveal_t > 2.6:
			break
	await _shot("11_midnight_the_oak_wakes_up")
	for i in 400:
		await process_frame
		if oak_mod._reveal_t > 4.0:
			break
	await _shot("12_the_roots_lift")
	for i in 400:
		await process_frame
		if oak_mod._reveal_t > 7.2:
			break
	await _shot("13_a_door_in_the_old_oak")
	await create_timer(3.0).timeout
	await _view("14_the_door_open_for_the_shift", oak.global_transform * Vector3(0.8, 1.8, 5.5), oak.global_transform * Vector3(0, 1.5, 1.4))
	await _view("15_the_oak_at_midnight", oak.global_transform * Vector3(-4.0, 3.0, 12.0), oak.global_transform * Vector3(0, 3.0, 0))
	_finish()


func _body(id: String) -> Node3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t.get_parent() as Node3D
	return null


func _make_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		_make_cam()
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
