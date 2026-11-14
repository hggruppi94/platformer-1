extends SceneTree

# Screenshots of the races' first prizes (scripts/races.gd FIRST_HATS, Schematics.LIST "reward"): the race gate's board
# with what each race's first win gives, the results of a first win with its blueprint and the Champion's Helmet, and
# the hero wearing each of the four new hats. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_prizes.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_prizes_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_prizes_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://race_prize_shots"
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
	settings.tips = false
	settings.race_intros = false
	settings.skate_assist = 0
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	races.reset()
	races.finished_once["lake_loop"] = true
	races.best["lake_loop"] = 95.0

	# The race gate's board
	change_scene_to_file(TOWN)
	await _frames(10)
	var gate: Node3D = races.hub_node("void")
	for i in 60:
		if gate and gate.ready_to_race:
			break
		await physics_frame
	races._refresh_boards()
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 45
	current_scene.add_child(cam)
	cam.make_current()
	var board: Node3D = gate.get_node("Race Board")
	var fwd: Vector3 = board.global_transform.basis.z
	await _view("01_the_race_board_says_what_winning_gives", board.global_position + fwd * 5.5 + Vector3.UP * 2.6, board.global_position + Vector3.UP * 2.2)
	await _view("01b_the_race_board_other_side", board.global_position - fwd * 5.5 + Vector3.UP * 2.6, board.global_position + Vector3.UP * 2.2)

	# A first win on the Lake Loop, the last of the four circuits
	for k in ["meadow_wiggle", "observatory_hill", "pumpkin_run"]:
		races.wins[k] = 1
		dialogue.set_flag("schematic_" + str(root.get_node("Schematics").for_race(k).id))
	game.riding = true
	races.enter_circuit("lake_loop")
	for i in 400:
		if races.racing() and current_scene and current_scene.scene_file_path == str(races.TRACKS.lake_loop.scene):
			break
		await physics_frame
	t = races.track_node("lake_loop")
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	for k in 400:
		if races.state == races.State.RACING:
			break
		await physics_frame
	races.lap = int(races.TRACKS.lake_loop.laps)
	races.next_cp = 0
	races.last_cp = t.cp_dist.size() - 1
	var last: float = t.cp_dist[t.cp_dist.size() - 1]
	p.global_position = t.point_at(lerpf(last, t.length, 0.6)) + Vector3.UP * 0.9
	p.velocity = t.dir_at(0.0) * 6.0
	await _ride(3.0)
	_release()
	await _frames(20)
	await _shot("02_first_win_prize_and_champion")
	races._close_choice()
	races._end(false)

	# The four hats, on the hero
	races.leave_circuit()
	for i in 300:
		if current_scene and current_scene.scene_file_path == TOWN:
			break
		await physics_frame
	await _frames(20)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	game.riding = false
	game.equipment_changed.emit()
	# The player's own spring arm takes the camera back every frame: stop it, and hide the minimap
	var arm := p.get_node("SpringArm3D")
	arm.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Settings").minimap = false
	# (Something takes a new camera back after a trip, so this moves the player's own one, its spring arm stopped)
	cam = arm.get_node("Camera3D") as Camera3D
	cam.fov = 30
	var n := 3
	for hat in ["aviator_cap", "lantern_hat", "rocket_helmet", "racing_helmet"]:
		game.hat = hat
		game.equipment_changed.emit()
		await _frames(6)
		var vis := p.get_node("Visual") as Node3D
		var front := vis.global_transform.basis.z         # (the hero's model faces +Z)
		var head := p.global_position + Vector3.UP * 0.55
		await _view("%02d_%s" % [n, hat], head + front * 2.4 + Vector3.UP * 0.35 + vis.global_transform.basis.x * 0.8, head)
		n += 1
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
