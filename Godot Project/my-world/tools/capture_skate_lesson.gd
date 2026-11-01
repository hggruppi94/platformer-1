extends SceneTree

# Screenshots of the skating help: the Lesson Pad at the Skate Park, Bruno offering a lesson, Coach Bruno teaching with Rook (with
# keyboard and with controller prompts), a how-to tip, and the Controls and Assist settings.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skate_lesson.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://skate_lesson_shots"
var p: CharacterBody3D
var s: Node
var arm: SpringArm3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	var lesson := root.get_node("SkateLesson")
	var tips := root.get_node("Tips")
	var dialogue := root.get_node("Dialogue")
	settings.last_device = "keyboard"
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	for st in lesson.STEPS:
		dialogue.flags.erase("skate_lesson_" + st.id)
	change_scene_to_file(TOWN)
	await _frames(6)
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	arm = p.get_node("SpringArm3D") as SpringArm3D
	var pad := town.find_child("Lesson Pad", true, false) as Node3D
	game.message("")
	tips.clear()

	# 1. Walking up to the Lesson Pad (the Skaters' Corner is across the way)
	_place(pad.global_position + Vector3(0, 1.0, -0.3), 0.0)
	await _shot("01_lesson_pad", 30)

	# 2. The first time on a ride, Bruno offers a lesson
	game.riding = true
	game.equipment_changed.emit()
	tips.clear()
	_place(pad.global_position + Vector3(0, 1.0, -2.5), 0.0)
	lesson.offer(true)
	await _shot("02_bruno_offers", 10)

	# 3. Coach Bruno teaching, by the pad, with Rook helping
	lesson.answer(true)
	tips.clear()
	_place(pad.global_position + Vector3(-1.2, 1.0, -3.5), 0.4)
	await _shot("03_coach_bruno", 20)

	# 4. The same lesson on a controller: the prompts say its buttons
	for id in ["push", "ollie", "spin"]:
		lesson.complete(id)
		await _seconds(1.7)
	settings.last_device = "pad"
	await _shot("04_lesson_with_a_controller", 6)
	settings.last_device = "keyboard"
	lesson.stop()

	# 5. A how-to tip
	tips.replay()
	await _seconds(0.8)
	await _shot("05_how_to_tip", 4)
	tips.clear()

	# 6, 7. The Controls settings (layouts, keys and controller buttons) and the Assist settings (skating landings)
	var menu := root.get_node("PauseMenu")
	menu.open()
	menu._tab = 1
	menu._show_settings()
	await _frames(2)
	(menu.find_child("Controls", true, false) as ScrollContainer).scroll_vertical = 330   # down to the buttons
	await _shot("06_controls_settings", 6)
	menu._tab = 4
	menu._show_settings()
	await _shot("07_assist_settings", 6)
	menu.close()
	_finish()


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s.state = s.State.ROLL
	s._yaw = yaw
	p.get_node("Visual").basis = Basis(Vector3.UP, yaw)
	arm.rotation = Vector3(-0.3, yaw + PI, 0)


func _shot(file: String, frames: int) -> void:
	(p.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	await _frames(frames)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
