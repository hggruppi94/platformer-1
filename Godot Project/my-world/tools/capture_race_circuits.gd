extends SceneTree

# Screenshots of the race circuits (scripts/race_circuit.gd, scripts/races.gd): Zippy's race gate in the Void and
# Pepper's in Stars Hollow, then each circuit from above, the grid of eight in the countdown, its bumpers, sweepers,
# zappers and ramps up close, a few seconds ridden for real by a little steering bot through the game's own camera
# (with the HUD and the track map), a Bubble Seeker on its way, and the results with their two buttons. Opens a window
# (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_circuits.gd -- <output folder> [circuit ids]
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.circuits_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.circuits_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://circuit_shots"
var only: Array = []
var cam: Camera3D
var races: Node
var t: Node3D
var p: CharacterBody3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	only = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(3600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	races = root.get_node("Races")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.race_intros = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	races.reset()
	for k in races.TRACKS:
		races.finished_once[k] = true

	if only.is_empty():
		# The gates
		change_scene_to_file(TOWN)
		await _frames(10)
		await _gate_shots("void", "01_void_race_gate")
		clock.calendar_offset = clock.CALENDAR_START
		clock.day = 1
		clock.set_earth_time(14 * 60.0, true)
		change_scene_to_file(EARTH)
		await _frames(10)
		await _gate_shots("earth", "02_stars_hollow_race_gate")
	var n := 3
	for id in ["lake_loop", "meadow_wiggle", "observatory_hill", "pumpkin_run"]:
		if not only.is_empty() and not id in only:
			continue
		await _circuit(id, n)
		n += 1
	_finish()


func _gate_shots(hub: String, file: String) -> void:
	var gate: Node3D = races.hub_node(hub)
	for i in 60:
		if gate and gate.ready_to_race:
			break
		await physics_frame
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()
	var start: Vector3 = gate.point_at(20.0)
	var f: Vector3 = gate.dir_at(20.0)
	var right: Vector3 = gate.side_at(20.0)
	p.global_position = start - f * 30.0 + Vector3.UP * 0.85
	await _view(file, start - f * 13.0 - right * 6.0 + Vector3.UP * 4.0, start + Vector3.UP * 2.0)


func _circuit(id: String, n: int) -> void:
	var tr: Dictionary = races.TRACKS[id]
	var game := root.get_node("Game")
	game.riding = true
	change_scene_to_file(str(tr.scene))
	await _frames(6)
	for i in 300:
		if races.racing():
			break
		await physics_frame
	var circ := current_scene as Node3D
	t = races.track_node(id)
	p = circ.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	var game_cam := p.get_node("SpringArm3D/Camera3D") as Camera3D
	cam = Camera3D.new()
	cam.fov = 55
	circ.add_child(cam)
	var tag := "%02d_%s" % [n, id]
	# From above, the whole circuit
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for a in t.line:
		lo = lo.min(a)
		hi = hi.max(a)
	var mid := (lo + hi) / 2.0
	var span := maxf(hi.x - lo.x, hi.z - lo.z)
	cam.make_current()
	hud.visible = false
	await _view(tag + "a_from_above", mid + Vector3(0, span * 0.95, span * 0.55), mid, 12)
	# The grid in the countdown, from behind the pack
	var start: Vector3 = t.point_at(0.0)
	var f: Vector3 = t.dir_at(0.0)
	await _view(tag + "b_the_grid", start - f * 34.0 + Vector3.UP * 7.0, start - f * 8.0 + Vector3.UP * 1.0)
	# Each kind of obstacle up close
	var seen := {}
	for o in t.obstacles:
		var kind := str(o.get_meta("kind"))
		if seen.has(kind):
			continue
		seen[kind] = true
		var d: float = o.get_meta("d")
		var at: Vector3 = (o as Node3D).global_position
		await _view("%sc_%s" % [tag, kind], at - t.dir_at(d) * 9.0 + t.side_at(d) * 4.0 + Vector3.UP * 4.0, at + Vector3.UP * 0.8)
	# Riding it for real, through the game's camera
	for k in 400:
		if races.state == races.State.RACING:
			break
		await physics_frame
	game_cam.make_current()
	hud.visible = true
	await _ride(4.0)
	await _shot(tag + "d_racing")
	await _ride(5.0)
	await _shot(tag + "e_racing_on")
	# A friend behind throws a Bubble Seeker at you
	var r: Node = races.rivals[races.rivals.size() - 1]
	r.d = races.progress - 9.0
	await _ride(0.1)
	races.attacks._aim_wait = 0.0
	r.item = "seeker"
	r.item_wait = 0.0
	r.item_held = 0.0
	await _ride(0.4)
	await _shot(tag + "f_a_bubble_seeker_after_you")
	await _ride(2.0)
	_release()
	# Over the line: the results and their buttons
	for r2 in races.rivals:
		r2.d = minf(r2.d, races.progress - 30.0)
	races.lap = int(tr.laps)
	races.next_cp = 0
	races.last_cp = t.cp_dist.size() - 1
	var last: float = t.cp_dist[t.cp_dist.size() - 1]
	p.global_position = t.point_at(lerpf(last, t.length, 0.6)) + Vector3.UP * 0.9
	p.velocity = t.dir_at(0.0) * 6.0
	await _ride(3.0)
	_release()
	await _frames(20)
	await _shot(tag + "g_results")
	races._close_choice()
	races._end(false)


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
