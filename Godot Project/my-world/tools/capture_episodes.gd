extends SceneTree

# Screenshots of the quests from the show's first episodes (scripts/episodes.gd): Melanie at the Town Hall, the old
# slide's clues, Mr. Goldwhistle, the escaped spirit, the Cloud Water Slide; Leo, his kit and bunker; the DOGS WELCOME
# sign; the hero's turtle shell, the Wizard Lizard and the little turtles before and after; and on Earth the glowing
# Willow Pond, the other Nina and her tricks.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_episodes.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.episodes_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://episodes_shots"
var cam: Camera3D
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var episodes: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	episodes = root.get_node("Watches").get_node("Episodes")
	root.get_node("Settings").tips = false
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.outfits = {"hero": {}}
	clock.pulls_home = false
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")

	# --- We Need a Slide! ---
	await _to_town(10 * 60.0)
	await _guest_shot("01_melanie_waits_by_the_town_hall", "melanie", 4.0, Vector3(-1.5, 0, 0))
	_flags(["slide_start", "slide_asked", "slide_ask_bramble", "slide_ask_pip", "slide_ask_dash"])
	await _settle()
	_make_cam()
	await _view("02_clues_at_the_old_slide", Vector3(-99.0, 3.2, -111.5), Vector3(-99.5, 0.6, -121.0), 20)
	_flags(["slide_clue_sign", "slide_clue_goo"])
	await _settle()
	await _guest_shot("03_mr_goldwhistle_by_the_haunted_house", "goldwhistle", 3.6)
	_flags(["slide_rich_talked", "slide_spirit"])
	await _frames(4)
	var spirit := current_scene.find_child("Escaped Spirit", true, false) as Node3D
	if spirit:
		await _view("04_something_giggly_escapes", Vector3(-99.0, 2.0, -113.0), spirit.global_position + Vector3(1.0, 0.3, 1.0), 2)
	_flags(["slide_plan", "slide_yes"])
	await _settle()
	await _to_town(11 * 60.0)
	_make_cam()
	await _view("05_the_cloud_water_slide_unlocked", Vector3(-5.0, 14.0, 30.0), Vector3(-28.0, 14.0, 6.0), 30)

	# --- Emergency Prep ---
	await _guest_shot("06_leo", "leo", 3.2)
	_flags(["prep_start"])
	await _settle()
	await _view("07_a_water_jug_for_the_kit", Vector3(-69.0, 2.0, 41.0), Vector3(-72.0, 0.4, 44.5), 15)
	_flags(["prep_water", "prep_torch", "prep_blanket", "prep_snacks"])
	await _settle()
	await _view("08_leos_emergency_bunker", Vector3(18.0, 4.0, 46.0), Vector3(11.0, 1.2, 35.0), 20)
	_flags(["prep_stored", "prep_calm"])
	await _settle()

	# --- Doggie Bill of Rights ---
	_flags(["dogs_start", "dogs_right_zoomies", "dogs_written", "dogs_sign_dash", "dogs_sign_bramble", "dogs_sign_pip",
		"dogs_sign_nina", "dogs_sign_rook", "dogs_read"])
	await _settle()
	var sign := current_scene.find_child("Dogs Welcome", true, false) as Node3D
	if sign:
		await _view("09_dogs_welcome_by_the_fountain", sign.to_global(Vector3(0, 2.0, 4.5)), sign.to_global(Vector3(0, 1.2, 0)), 15)

	# --- Turtle Independence ---
	await _to_town(9 * 60.0)
	await _to_town(9 * 60.0)
	var player := _player()
	player.global_position = Vector3(-72.0, 1.0, 0.0)
	_face(player, Vector3(-72.0, 0.0, -20.0))
	await _frames(20)
	await _view("10_you_woke_up_with_a_turtle_shell", player.global_position + Vector3(2.0, 1.6, 3.2),
		player.global_position + Vector3(0, 0.8, 0), 15)
	await _guest_shot("11_the_wizard_lizard", "wizard_lizard", 3.4)
	_flags(["turtle_met_lizard", "turtle_cup", "turtle_bucket", "turtle_pot"])
	await _settle()
	var at := Vector3(-24.0, 0.0, 21.0)
	await _view("12_three_little_turtles_with_no_shells", at + Vector3(0.0, 1.8, -4.5), at + Vector3(0, 0.3, 0), 15)
	_flags(["turtle_given"])
	await _settle()
	await _view("13_they_chose_their_own_shells", at + Vector3(0.0, 1.8, -4.5), at + Vector3(0, 0.3, 0), 15)
	_flags(["turtle_done_talk"])
	await _settle()

	# --- Aftershock (Earth) ---
	clock.set_earth_time(19 * 60.0 + 30.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	await _settle()
	await _settle()
	_make_cam()
	await _view("14_willow_pond_glows_after_the_aftershock", Vector3(-52.0, 6.0, 16.0), Vector3(-75.0, 0.0, 2.0), 20)
	_flags(["aftershock_pond"])
	await _settle()
	await _guest_shot("15_the_other_nina", "other_nina", 2.6)
	_flags(["aftershock_met"])
	await _settle()
	await _view("16_her_trick_tangled_gazebo_lights", Vector3(6.0, 2.4, 10.0), Vector3(2.5, 0.6, 4.5), 15)
	await _view("17_her_trick_town_smell", Vector3(-15.0, 2.6, 3.0), Vector3(-23.5, 2.8, 0.0), 15)
	_finish()


func _flags(names: Array) -> void:
	for f in names:
		dialogue.set_flag(f)
		quests.check()


func _to_town(galaxity_minutes: float) -> void:
	if cam and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	clock.set_earth_time(0.25 * 60.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN)
	clock.set_time(clock.day, galaxity_minutes, true)
	await _settle()


func _guest_shot(file: String, id: String, dist: float, offset := Vector3.ZERO) -> void:
	var n: Node3D = episodes.guest(id)
	if n == null:
		print("NO GUEST ", id)
		return
	var player := _player()
	player.global_position = n.global_position + n.global_basis.z * 2.0 + Vector3(0, 1.0, 0)
	_face(player, n.global_position)
	await _frames(10)
	var front := n.global_basis.z.normalized()
	await _view(file, n.global_position + front * dist + n.global_basis.x * 1.2 + Vector3(0, 1.5, 0) + offset,
		n.global_position + Vector3(0, 1.0, 0), 15)


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _face(n: Node3D, at: Vector3) -> void:
	var d := at - n.global_position
	n.rotation.y = atan2(d.x, d.z)


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


func _settle() -> void:
	await create_timer(0.45).timeout
	await _frames(3)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
