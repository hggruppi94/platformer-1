extends SceneTree

# Screenshots of the races (scripts/races.gd): the start arch with Zippy and the race board, the grid in the
# countdown, riding through a ring with the friends alongside, a boost pad, the Star Boxes, a goo puddle, the Bubble
# Shield, the whole Lake Loop from above, and the results. The racing shots are ridden for real by a little steering
# bot, seen through the game's own camera with the HUD. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_races.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.races_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://race_shots"
var cam: Camera3D
var races: Node
var t: Node3D
var p: CharacterBody3D


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
	races = root.get_node("Races")
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
	races.reset()
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	var town := current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	t = races.track_node("lake_loop")
	for i in 60:
		if t.ready_to_race:
			break
		await physics_frame
	var game_cam := p.get_node("SpringArm3D/Camera3D") as Camera3D
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	hud.visible = false

	# The start: the arch, Zippy with the flag, the board
	var start: Vector3 = t.point_at(0.0)
	var f: Vector3 = t.dir_at(0.0)
	var right: Vector3 = t.side_at(0.0)
	p.global_position = start - f * 30.0 + Vector3.UP * 0.85      # out of the way
	var zippy := t.get_node("Zippy") as Node3D
	var board := t.get_node("Race Board") as Node3D
	await _view("01_the_start_line", start - f * 16.0 - right * 7.0 + Vector3.UP * 4.0, start + Vector3.UP * 2.5 - right * 3.0)
	await _view("02_zippy_and_the_race_board", zippy.global_position + f * 1.0 - right * 4.5 + Vector3.UP * 1.6,
		(zippy.global_position + board.global_position) / 2.0 + Vector3.UP * 1.3)
	await _view("03_board_close_up", board.global_position - right * 3.2 + Vector3.UP * 2.0, board.global_position + Vector3.UP * 1.9)

	# The grid in the countdown, through the game's camera
	races.start("lake_loop")
	game_cam.make_current()
	hud.visible = true
	for i in 70:
		await physics_frame
	await _shot("04_on_the_grid_countdown")
	for i in 130:
		await physics_frame
	# Racing for real: a bot steers round, and the friends keep close
	for r in races.rivals:
		r.skill *= 1.12
	await _ride(5.5)
	await _shot("05_through_the_rings")
	await _ride(4.0)
	await _shot("06_alongside_friends")
	# A power-up in hand, then the Bubble Shield
	races.power = "zoom"
	races.hud.show_power("Zoom Star")
	await _ride(1.5)
	await _shot("07_holding_a_zoom_star")
	races.power = "shield"
	races.use_power()
	await _ride(1.5)
	await _shot("08_bubble_shield")
	_release()

	# Close-ups of what's on the track, from a camera of our own
	cam.make_current()
	hud.visible = false
	var pad := t.pads[0] as Node3D
	var pf: Vector3 = t.dir_at(float(pad.get_meta("d")))
	await _view("09_boost_pad", pad.global_position - pf * 5.0 + t.side_at(float(pad.get_meta("d"))) * 2.0 + Vector3.UP * 2.2, pad.global_position)
	var box := t.boxes[4] as Node3D
	var bf: Vector3 = t.dir_at(float(box.get_meta("d")))
	await _view("10_star_boxes", box.global_position - bf * 6.0 + Vector3.UP * 2.4, box.global_position + Vector3.UP * 1.0)
	var goo := t.goo[1] as Node3D
	var gf: Vector3 = t.dir_at(float(goo.get_meta("d")))
	await _view("11_goo_puddle", goo.global_position - gf * 5.5 + Vector3.UP * 2.6, goo.global_position)
	# The whole loop from above, rings out
	await _view("12_the_lake_loop_from_above", Vector3(0, 62, 62), Vector3(0, 0, -4))

	# Over the line: the results
	game_cam.make_current()
	hud.visible = true
	races.lap = races.TRACKS.lake_loop.laps
	races.last_cp = t.cp_dist.size() - 1
	races.next_cp = 0
	races.rivals[0].d = races.progress + 40.0
	races.rivals[0].finished = true
	races.rivals[0].finish_time = races.time - 1.4
	p.global_position = t.point_at(-2.0) + Vector3.UP * 0.85
	for i in 3:
		await physics_frame
	p.global_position = t.point_at(1.5) + Vector3.UP * 0.85
	p.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	await _shot("13_results")
	_finish()


func _ride(seconds: float) -> void:
	# A little steering bot: aims at the racing line a few metres ahead, through the camera, like a player would
	var frames := int(seconds * 60.0)
	for k in frames:
		await physics_frame
		var here: float = races.progress
		var target: Vector3 = t.point_at(fposmod(here, t.length) + 7.0)
		var want := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z).normalized()
		var b: Basis = p.get_node("SpringArm3D").global_transform.basis
		var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
		var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
		var ix := rgt.dot(want)
		var iy := -fwd.dot(want)
		_release()
		if ix > 0:
			Input.action_press("move_right", ix)
		else:
			Input.action_press("move_left", -ix)
		if iy > 0:
			Input.action_press("move_back", iy)
		else:
			Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
