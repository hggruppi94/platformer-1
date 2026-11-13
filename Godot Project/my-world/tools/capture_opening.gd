extends SceneTree

# Screenshots of a new game's opening (scripts/opening.gd, scripts/move_tutorial.gd; tools/test_opening.gd checks
# them): the morning cutscene's four shots, the movement tutorial's card, Nina's cutscene out of the door, and the
# notice board's and the old oak's "where to go" shots. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_opening.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.opening_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://opening_shots"
var game: Node
var dialogue: Node
var quests: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	var creator := root.get_node("Creator")
	var fn := root.get_node("FirstNight")
	var op: Node = fn.opening
	game.new_game()
	await _frames(40)
	if not creator.is_open():
		creator.open(true)
	await _frames(10)
	game.hero["name"] = "Sunny"
	creator.close()
	await _frames(2)
	# The morning cutscene: a picture near the end of each shot
	var cut: CanvasLayer = op.cut
	for i in 4:
		var end := 0.0
		for k in i + 1:
			end += float(cut.shots[k].time)
		while cut.playing() and _elapsed(cut) < end - 0.5:
			await process_frame
		await _shot("%02d_morning_%d" % [i + 1, i + 1], 1)
	while cut.playing():
		await process_frame
	await _shot("05_movement_tutorial_card", 20)
	var tut: CanvasLayer = op.tutorial
	var player := current_scene.find_child("Player", true, false) as Node3D
	var arm := player.get("spring_arm") as Node3D
	for i in 30:
		arm.rotation.y += 0.06
		await physics_frame
	await _frames(60)
	await _shot("06_tutorial_next_step", 4)
	# Out of the door: Nina
	for s in ["walk", "jump", "double", "roll", "sprint"]:
		dialogue.set_flag("tut_" + s)
	var home: Node3D = tut.home
	player.global_position = home.global_position + home.global_basis.z * 7.0 + Vector3.UP * 0.8
	for i in 120:
		await process_frame
		if cut.playing():
			break
	await _mid_cut(cut, "07_nina_from_next_door")
	cut.stop()
	# The notice board and the old oak
	for f in ["fn_nina", "fn_palmer", "fn_folk"]:
		dialogue.set_flag(f)
	quests.check()
	await _frames(4)
	op.play_guide("board")
	await _mid_cut(cut, "08_where_to_go_the_notice_board")
	cut.stop()
	dialogue.set_flag("fn_board_look"); dialogue.set_flag("fn_board_follow"); dialogue.set_flag("fn_board_job")
	quests.check()
	await _frames(4)
	op.play_guide("evening")
	await _mid_cut(cut, "09_where_to_go_home_in_the_evening")
	cut.stop()
	_finish()


func _mid_cut(cut: CanvasLayer, file: String) -> void:
	# A picture near the end of a cutscene's first shot (frames are slow in a software-rendered window, so by time)
	while cut.playing() and _elapsed(cut) < float(cut.shots[0].time) - 0.6:
		await process_frame
	await _shot(file, 1)


func _elapsed(cut: CanvasLayer) -> float:
	var t := float(cut.get("_t"))
	for k in int(cut.get("_i")):
		t += float(cut.shots[k].time)
	return t


func _shot(file: String, settle := 8) -> void:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
