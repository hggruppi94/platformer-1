extends SceneTree

# Screenshots of the races' tutorial (scripts/race_tutorial.gd) and the Lake Loop's clear start: the card by Zippy's
# race gate, the grid with nothing in front of it, then the first race's cards through the game's own camera (GO, the
# gold ring, a Star Box, using it). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_tutorial.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_tut_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_tut_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://race_tutorial_shots"
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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	races = root.get_node("Races")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var settings := root.get_node("Settings")
	settings.tips = true
	settings.race_intros = false
	settings.skate_assist = 0
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	races.reset()
	for f in dialogue.flags.keys():
		if str(f).begins_with("race_"):
			dialogue.flags.erase(f)

	# The card by the race gate, through the game's camera
	change_scene_to_file(TOWN)
	await _frames(10)
	var gate: Node3D = races.hub_node("void")
	for i in 60:
		if gate and gate.ready_to_race:
			break
		await physics_frame
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var zippy: Node3D = gate.get_node("Zippy")
	var f: Vector3 = gate.dir_at(20.0)
	p.global_position = zippy.global_position - f * 9.0 + Vector3.UP * 1.0
	var arm := p.get_node("SpringArm3D") as Node3D
	arm.rotation.y = atan2(-(zippy.global_position - p.global_position).x, -(zippy.global_position - p.global_position).z)
	await _frames(30)
	await _shot("01_the_card_by_the_race_gate")
	dialogue.set_flag("race_gate_seen")

	# The Lake Loop: the grid, clear in front
	game.riding = true
	races.enter_circuit("lake_loop")
	for i in 400:
		if races.racing() and current_scene and current_scene.scene_file_path == str(races.TRACKS.lake_loop.scene):
			break
		await physics_frame
	t = races.track_node("lake_loop")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	var game_cam := p.get_node("SpringArm3D/Camera3D") as Camera3D
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()
	var start: Vector3 = t.point_at(0.0)
	var fw: Vector3 = t.dir_at(0.0)
	await _view("02_the_lake_loop_grid_clear_ahead", start - fw * 34.0 + Vector3.UP * 7.0, start - fw * 8.0 + Vector3.UP * 1.0)
	game_cam.make_current()
	hud.visible = true
	await _frames(20)
	await _shot("03_countdown_ride_forward_at_go")
	for k in 400:
		if races.state == races.State.RACING:
			break
		await physics_frame
	await _ride(1.6)
	await _shot("04_ride_through_the_gold_ring")
	for k in 900:
		if races.tutorial.step_id() != "ring":
			break
		await _ride(0.05)
	await _ride(1.5)
	await _shot("05_ride_into_a_star_box")
	races.power = "zoom"
	races.hud.show_power("Zoom Star")
	await _ride(1.2)
	await _shot("06_press_aim_to_use_it")
	races.use_power()
	await _ride(1.4)
	await _shot("07_what_the_obstacles_do")
	_release()
	races._end(false)
	_finish()


func _ride(seconds: float) -> void:
	# A little steering bot: aims at the racing line a few metres ahead, through the camera, like a player would
	var frames := int(seconds * 60.0)
	for k in frames:
		await physics_frame
		if not is_instance_valid(p):
			return
		var here: float = races.progress
		var target: Vector3 = t.point_at(fposmod(here, t.length) + 8.0)
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
