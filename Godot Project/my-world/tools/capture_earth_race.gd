extends SceneTree

# Screenshots of the Pumpkin Run, the race round Stars Hollow on Earth (scripts/races.gd): the start arch on Maple
# Lane with Pepper and the race board, the grid in the countdown with Nina, Bruno and Ozzie, racing for real (a
# little steering bot rides it, seen through the game's own camera with the HUD) past the barn and through the gap on
# Main Street, the whole route from above, and the route on the Earth map. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_earth_race.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.earth_race_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://earth_race_shots"
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
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	races = root.get_node("Races")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	settings.tips = false
	settings.set("race_intros", false)
	clock.pulls_home = false
	clock.day = 1
	clock.set_earth_time(15 * 60.0, true)              # a sunny autumn afternoon
	races.reset()
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	var earth := current_scene as Node3D
	p = earth.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	t = races.track_node("pumpkin_run")
	for i in 60:
		if t.ready_to_race:
			break
		await physics_frame
	var game_cam := p.get_node("SpringArm3D/Camera3D") as Camera3D
	cam = Camera3D.new()
	cam.fov = 50
	earth.add_child(cam)
	cam.make_current()
	hud.visible = false

	# The start on Maple Lane: the arch, Pepper with her flag, the board
	var start: Vector3 = t.point_at(0.0)
	var f: Vector3 = t.dir_at(0.0)
	var right: Vector3 = t.side_at(0.0)
	p.global_position = start - f * 30.0 + Vector3.UP * 0.85
	var pepper := t.get_node("Pepper") as Node3D
	var board := t.get_node("Race Board") as Node3D
	await _view("01_pumpkin_run_start_on_maple_lane", start - f * 16.0 - right * 7.0 + Vector3.UP * 4.0, start + Vector3.UP * 2.5 + right * 2.0)
	await _view("02_pepper_and_the_race_board", pepper.global_position + f * 1.5 - right * 3.5 + Vector3.UP * 1.4,
		(pepper.global_position + board.global_position) / 2.0 + Vector3.UP * 1.1)
	await _view("03_board_close_up", board.global_position - right * 3.2 + Vector3.UP * 2.0, board.global_position + Vector3.UP * 1.9)

	# The grid, through the game's camera
	races.start("pumpkin_run")
	cam.make_current()
	var g: Vector3 = t.point_at(-6.0)
	await _view("04_nina_bruno_and_ozzie_on_the_grid", g + f * 9.0 + right * 3.0 + Vector3.UP * 1.8, g + Vector3.UP * 0.8)
	game_cam.make_current()
	hud.visible = true
	for i in 70:
		await physics_frame
	await _shot("05_countdown")
	for i in 130:
		await physics_frame
	for r in races.rivals:
		r.skill *= 1.12
	await _ride(5.0)
	await _shot("06_racing_down_maple_lane")
	await _ride_to(t.cp_dist[4])
	await _shot("07_past_the_barn")
	await _ride_to(t.cp_dist[9] - 6.0)
	await _shot("08_through_the_gap_on_main_street")
	await _ride_to(t.cp_dist[14])
	await _shot("09_down_by_the_green")
	_release()

	# The whole route from above, rings out
	cam.make_current()
	hud.visible = false
	await _view("10_the_route_from_above", Vector3(12, 55, 95), Vector3(10, 0, 5))
	game_cam.make_current()
	hud.visible = true
	root.get_node("PlayerMenu").open("map")
	for i in 8:
		await process_frame
	await _shot("11_the_route_on_the_earth_map")
	root.get_node("PlayerMenu").close()
	races._end(false)
	_finish()


func _ride_to(d: float) -> void:
	for k in 60 * 40:
		if fposmod(races.progress, t.length) >= d or races.state != races.State.RACING:
			return
		await _ride(1.0 / 60.0)


func _ride(seconds: float) -> void:
	# A little steering bot: aims at the racing line a few metres ahead, through the camera, like a player would
	var frames := maxi(int(seconds * 60.0), 1)
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
