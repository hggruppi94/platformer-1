extends SceneTree

# Screenshots of the nightly request board (scripts/requests.gd): the board in the Market Square, a close-up of
# tonight's list, Tally and their clipboard, Tally reading the requests out, a turn-in with its confetti, the
# requests on the Tab menu's Quests sheet, the board at night, and a parcel waiting outside a building on Earth.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_request_board.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.request_board_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://request_board_shots"
var cam: Camera3D
var R: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	R = root.get_node("Requests")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	R.reset()
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	var hud = player.get_node("HUD")
	hud.visible = false
	R.nights = 2
	R.roll(4)
	R.nights = 3
	# Some progress to show: the first one done, the second partway
	R.list[0].progress = R.list[0].goal
	R.list[0].done = true
	if R.list[1].kind in ["gloops", "crocodillo", "watch", "park_score"]:
		R.list[1].progress = maxi(int(R.list[1].goal) / 2, 1) if R.list[1].kind != "crocodillo" else 0
	R.changed.emit()
	var board := town.get_node("Request Board") as Node3D
	var tally := town.get_node("Tally") as Node3D
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	var b := board.global_position
	var out := board.global_transform.basis.z                   # the way the board faces (toward the fountain)
	player.global_position = b + out * 4.0 + board.global_transform.basis.x * 1.2 + Vector3.UP
	for i in 30:
		await process_frame
	await _view("01_board_in_the_market_square", b + out * 11.0 + Vector3(4.0, 4.0, 0) + board.global_transform.basis.x * 3.0, b + Vector3(0, 1.8, 0))
	await _view("02_tonights_requests", b + out * 3.4 + Vector3(0, 2.0, 0), b + Vector3(0, 2.0, 0))
	# Tally, stopped for a close-up
	tally.set_physics_process(false)
	tally.global_position = b + out * 3.0 - board.global_transform.basis.x * 2.0
	tally.rotation.y = atan2(out.x, out.z) + 0.4
	(tally.find_child("AnimationPlayer", true, false) as AnimationPlayer).play("idle")
	var tp := tally.global_position
	var front := tp + Vector3(sin(tally.rotation.y), 0, cos(tally.rotation.y)) * 2.6 + Vector3(0.6, 1.0, 0)
	await _view("03_tally_and_the_clipboard", front, tp + Vector3(0, 0.6, 0))
	# Tally reading tonight's requests out
	hud.visible = true
	player.global_position = tp + Vector3(sin(tally.rotation.y), 0, cos(tally.rotation.y)) * 1.6 + Vector3.UP
	(player.get_node("Visual") as Node3D).rotation.y = tally.rotation.y + PI
	var dialogue := root.get_node("Dialogue")
	R.list[0].done = false                                      # (turned in in the next shot)
	dialogue.say(tally.get_node("Request Talk"), "Tally", R.lines(), "tally")
	for i in 3:
		dialogue._finish_typing()
		if i < 2:
			dialogue._next()
		await process_frame
	await _view("04_tally_reads_the_requests", player.global_position + Vector3(-2.0, 1.8, 3.2) - out * 0.5, tp + Vector3(0, 0.8, 0))
	dialogue.end()
	for i in 10:
		await process_frame
	# Turning one in: the sparkles and the confetti
	R.list[0].done = true
	R.list[0].paid = false
	player.global_position = b + out * 2.0 + Vector3.UP
	R.turn_in(board)
	for i in 6:
		await process_frame
	await _view("05_turned_in", b + out * 6.0 + Vector3(0, 2.5, 0) + board.global_transform.basis.x * 1.5, b + Vector3(0, 2.4, 0), 0)
	for i in 20:
		await process_frame
	# The Quests sheet
	root.get_node("PlayerMenu").open("quests")
	for i in 6:
		await process_frame
	await _view("06_quests_sheet", cam.global_position, b + Vector3(0, 2.0, 0))
	root.get_node("PlayerMenu").close()
	for i in 6:
		await process_frame
	hud.visible = false
	# At night
	clock.set_time(3, 22 * 60.0 + 30.0, true)
	for i in 40:
		await process_frame
	await _view("07_board_at_night", b + out * 7.0 + Vector3(0, 2.6, 0) + board.global_transform.basis.x * 2.0, b + Vector3(0, 2.0, 0))
	# On Earth: a parcel waiting outside its building
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var earth_req: Dictionary = R._make("deliver", "hard", rng)
	R.list = [earth_req]
	clock.on_earth = true
	clock.set_earth_time(10.0, true)
	change_scene_to_file(EARTH)
	for i in 10:
		await process_frame
	var earth := current_scene as Node3D
	earth.find_child("Player", true, false).get_node("HUD").visible = false
	earth.find_child("Player", true, false).global_position = Vector3(0, -50, 0)
	cam = Camera3D.new()
	cam.fov = 50
	earth.add_child(cam)
	cam.make_current()
	var parcel := earth.get_node_or_null("Parcel " + str(earth_req.item)) as Node3D
	if parcel:
		var shop := earth.get_node(str(earth_req.from)) as Node3D
		var face := shop.global_transform.basis.z
		await _view("08_earth_parcel_outside_the_" + str(earth_req.from).to_snake_case(),
			parcel.global_position + face * 6.0 + Vector3(2.0, 2.4, 0), parcel.global_position + Vector3(0, 1.0, 0) - face * 3.0)
	else:
		print("NO PARCEL ON EARTH")
	_finish()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
