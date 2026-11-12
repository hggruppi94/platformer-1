extends SceneTree

# Screenshots of Dash's kinetic energy and Nina and Bruno's making power (scripts/kinetic.gd, scripts/make.gd): Bruno
# teaching it, the kinetic meter full, a kinetic burst popping Gloops, a made bridge out over the lake, and a step
# made in mid-air. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_powers.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.powers_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.powers_capture_backup.cfg"

var out_dir := "user://powers_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state["bike_boy"] = {"step": 6, "done": true, "since_day": 1}
	var dialogue := root.get_node("Dialogue")
	dialogue.set_flag("kinetic_taught")
	dialogue.set_flag("make_start")
	game.go("res://scenes/town/town.tscn", "", "")
	await _frames(20)
	await _bruno()
	dialogue.set_flag("make_taught")
	await _kinetic()
	await _bridge()
	await _step()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _ground(x: float, z: float) -> Vector3:
	return root.get_node("Remnants").ground_at(Vector2(x, z))


func _bruno() -> void:
	var s := current_scene as Node3D
	var p := _player()
	var bruno: Node3D = null
	var talk: Node3D = null
	for n in s.find_children("*", "", true, false):
		if n.get("character_id") == "bruno_alien":
			talk = n as Node3D
			bruno = n.get_parent() as Node3D
			break
	if bruno == null:
		print("NO BRUNO")
		return
	p.global_position = bruno.global_position + Vector3(0, 0.9, 2.2)
	await _physics(10)
	_cam_in(s)
	var d := root.get_node("Dialogue")
	var conv := JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/bruno_alien.json")) as Dictionary
	var lines: Array = []
	for c in conv.conversations:
		if c.get("set", "") == "make_taught":
			lines = c.lines.slice(2, 3)
	d.say(talk, "Bruno", lines)
	await create_timer(0.3).timeout
	d._finish_typing()
	_look(bruno.global_position + Vector3(-3.0, 2.2, 4.5), bruno.global_position + Vector3(0.3, 1.0, 0.8))
	await _frames(4)
	await _shot("01_bruno_and_nina_make_a_plank")
	d.end()
	await _frames(4)


func _kinetic() -> void:
	var s := current_scene as Node3D
	var p := _player()
	p.global_position = _ground(-18.0, 50.0) + Vector3(0, 1.0, 0)
	await _physics(20)
	var k := p.get_node("Kinetic")
	k.charge = 1.0
	k._changed_at = k._now()
	_look(p.global_position + Vector3(4.0, 2.4, 5.5), p.global_position + Vector3(0, 0.5, 0))
	await _frames(6)
	await _shot("02_kinetic_charge_full")
	var gloops: Array = []
	for e in get_nodes_in_group("enemies"):
		if e is CharacterBody3D and str(e.name).begins_with("Gloop") and not e.get("defeated") and gloops.size() < 3:
			gloops.append(e)
	for i in gloops.size():
		var a := i * TAU / 3.0 + 0.5
		(gloops[i] as Node3D).global_position = p.global_position + Vector3(sin(a) * 3.5, 0.3, cos(a) * 3.5)
	await _physics(4)
	root.get_node("Game").sp = root.get_node("Game").max_sp
	p._try_roll(Vector3(1, 0, 0))
	await create_timer(0.18).timeout
	_look(p.global_position + Vector3(6.0, 4.5, 7.0), p.global_position)
	await _shot("03_kinetic_burst_pops_gloops")
	await create_timer(1.0).timeout


func _bridge() -> void:
	# Out in front of the hero on open ground
	var p := _player()
	var m := p.get_node("Make")
	p.global_position = _ground(-18.0, 50.0) + Vector3(0, 1.0, 0)
	await _physics(20)
	p.visual.rotation.y = PI * 0.5
	m._turn = 0
	m.make()
	await create_timer(0.4).timeout
	var ahead: Vector3 = p.global_position + p.facing_dir() * 2.5
	_look(ahead + Vector3(1.0, 3.0, 6.5), ahead + Vector3(-0.8, -0.6, 0))
	await _shot("04_a_made_bridge")
	m.clear()


func _step() -> void:
	var p := _player()
	var m := p.get_node("Make")
	p.global_position = _ground(-18.0, 50.0) + Vector3(0, 1.0, 0)
	await _physics(20)
	m.cooldown = 0.0
	m._turn = 0
	p.velocity = Vector3(0, 7.0, 0)
	await _physics(20)                # (physics frames: software rendering here is slow, so seconds aren't jumps)
	m.make()
	await _physics(80)
	_look(p.global_position + Vector3(4.5, 0.8, 4.5), p.global_position + Vector3(0, -0.6, 0))
	await _shot("05_a_step_made_in_mid_air")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
