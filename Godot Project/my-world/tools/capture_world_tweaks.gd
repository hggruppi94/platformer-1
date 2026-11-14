extends SceneTree

# Screenshots for the 14 Nov 2026 playtest tweaks: the Frozen Moment's fish in its hole in the ice and leaping, the
# snowmen's snowball fight going on, Pip's moth wings on the hero's back (folded walking, spread gliding, worn back in
# the Void), and the Gloop King's subjects jumping down and leaping at you. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_world_tweaks.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.tweaks_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tweaks_capture_backup.cfg"

var out_dir := "user://tweak_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind"]:
		portals.cleared_worlds.append(w)
	await _frozen()
	portals.cleared_worlds.append("frozen_moment")
	await _wings()
	await _kingdom()
	_finish()


func _player() -> CharacterBody3D:
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	return p


func _frozen() -> void:
	portals.enter("frozen_moment")
	await _frames(20)
	var s := current_scene as Node3D
	var p := _player()
	_cam_in(s)
	var m1 := (s.get_node("Moment1") as Node3D).global_position
	p.global_position = m1 + Vector3(-3.0, 0.9, 3.0)
	await _frames(6)
	_look(m1 + Vector3(-3.0, 2.6, 4.0), m1 + Vector3(0, 0.8, 0))
	await _shot("01_frozen_fish_over_its_hole")
	for k in 3:
		s.get_node("Moment1/Spot").use()
	for k in 3:
		s.get_node("Moment2/Spot").use()
	await create_timer(1.0).timeout
	# The fish, mid-leap (wait for one to start, then catch it at the top)
	_look(m1 + Vector3(-2.2, 1.6, 3.0), m1 + Vector3(0, 0.9, 0))
	var started := int(s.leaps)
	while int(s.leaps) == started:
		await process_frame
	await create_timer(0.42).timeout
	await _shot("02_fish_leaping_out_of_its_hole")
	_look(m1 + Vector3(0, 6.0, 2.0), m1)
	await _shot("03_the_hole_from_above")
	var m2 := (s.get_node("Moment2") as Node3D).global_position
	p.global_position = m2 + Vector3(3.2, 0.9, 2.5)            # (out of the picture)
	_look(m2 + Vector3(0.6, 1.3, 5.0), m2 + Vector3(0, 2.0, 0))
	for n in 2:
		var t0 := int(s.throws)
		while int(s.throws) == t0:
			await process_frame
		await create_timer(0.27).timeout
		await _shot("04_snowball_fight_%d" % (n + 1))


func _wings() -> void:
	portals.enter("lanternmoor")
	await _frames(20)
	var s := current_scene as Node3D
	var p := _player()
	_cam_in(s)
	s.pip_lines()                                            # meeting Pip: the moth wings, to keep
	await _frames(10)
	var pip := (s.get_node("Pip") as Node3D).global_position
	p.global_position = pip + Vector3(1.5, 0.9, 3.0)
	p.velocity = Vector3.ZERO
	await _frames(30)
	var vis := p.get_node("Visual") as Node3D
	var fwd := vis.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	var at := p.global_position
	_look(at - fwd * 2.6 + side * 1.4 + Vector3(0, 0.7, 0), at + Vector3(0, 0.1, 0))
	await _shot("05_moth_wings_on_your_back")
	_look(at + side * 2.6 + Vector3(0, 0.4, 0), at + Vector3(0, 0.1, 0))
	await _shot("06_moth_wings_from_the_side")
	# Gliding off the Tall Lantern Tree
	var launch := (s.get_node("Launch") as Node3D).global_position
	var rock := (s.get_node("Beacon2") as Node3D).global_position
	var dir := Vector3(rock.x - launch.x, 0, rock.z - launch.z).normalized()
	p.global_position = launch + dir * 1.8 + Vector3(0, 0.6, 0)
	p.spring_arm.global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	await _frames(6)
	Input.action_press("move_forward")
	Input.action_press("jump")
	p.velocity = dir * 5.0 + Vector3(0, 6.0, 0)
	await create_timer(1.9).timeout
	var sd := dir.cross(Vector3.UP)
	_look(p.global_position - dir * 3.0 + sd * 2.0 + Vector3(0, 1.2, 0), p.global_position + dir * 2.0 + Vector3(0, 0.3, 0))
	await _shot("07_gliding_wings_spread")
	await create_timer(3.0).timeout
	Input.action_release("move_forward")
	Input.action_release("jump")
	# Still on, back in the Void
	game.go("res://scenes/town/town.tscn", "", "")
	await _frames(20)
	var t := current_scene as Node3D
	p = _player()
	p.global_position = Vector3(0, 6.0, 30)
	await _frames(40)
	_cam_in(t)
	vis = p.get_node("Visual") as Node3D
	fwd = vis.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	at = p.global_position
	_look(at - fwd * 2.8 + fwd.cross(Vector3.UP) * 1.2 + Vector3(0, 0.9, 0), at + Vector3(0, 0.2, 0))
	await _shot("08_wearing_them_in_the_void")


func _kingdom() -> void:
	root.get_node("Bosses").enter_kingdom()
	await _frames(14)
	var kd := current_scene as Node3D
	var p := _player()
	p.global_position = Vector3(0, 1.0, 76)
	await _frames(30)
	_cam_in(kd)
	while (kd.call("jumpers") as Array).is_empty():
		await physics_frame
	await create_timer(0.35).timeout
	var first := (kd.call("jumpers") as Array)[0] as Node3D
	_look(first.global_position + Vector3(0, 1.5, 0) + (Vector3(0, 0, 88) - first.global_position).normalized() * 9.0,
		first.global_position + Vector3(0, -1.0, 0))
	await _shot("09_his_subjects_jump_in")
	var jumpers: Array = kd.call("jumpers")
	var king := kd.get_node("The Gloop King") as CharacterBody3D
	king.set_physics_process(false)
	if not jumpers.is_empty():
		var j := jumpers[0] as CharacterBody3D
		p.global_position = Vector3(0, 1.0, 82)
		j.global_position = p.global_position + Vector3(3.4, -0.2, 0)
		var shot := false
		for f in 200:
			await physics_frame
			if not is_instance_valid(j):
				break
			if bool(j.get("_leaping")) and not shot and j.velocity.y < 1.5:
				_look(p.global_position + Vector3(1.5, 1.6, 5.0), (p.global_position + j.global_position) / 2.0)
				await _shot("10_a_courtier_leaps_at_you")
				shot = true
	# A guard on the Bog Road crouching to leap
	var g := kd.get_node_or_null("Gloop Guard 1") as CharacterBody3D
	if g:
		p.global_position = g.global_position + Vector3(0, 0.3, -4.0)
		for f in 200:
			await physics_frame
			if float(g.get("_winding")) > 0.25:
				_look(g.global_position + Vector3(4.0, 2.0, -3.0), (p.global_position + g.global_position) / 2.0)
				await _shot("11_a_guard_crouches_to_leap")
				break


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


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
