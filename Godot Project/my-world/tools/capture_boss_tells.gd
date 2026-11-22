extends SceneTree

# Screenshots of the boss warnings (scripts/boss_tell.gd) and the guardians (scripts/guardian.gd): each guardian
# asleep by its hidden place, then each of its moves while the ground's warning about it, and the Gloop King's ring
# before his belly-flop. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_tells.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.tells_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tells_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://tell_shots"
var cam: Camera3D
var player: CharacterBody3D


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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var hidden := root.get_node("Hidden")
	var G: GDScript = load("res://scripts/guardian.gd")
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Portals").home_calls.enabled = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(16)
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	_new_cam()
	var n := 0
	for id in G.KINDS:
		hidden.find(id)
		await _frames(4)
		var g := current_scene.find_child("Guardian " + id, true, false) as CharacterBody3D
		if g == null:
			continue
		g.set_physics_process(false)
		var out: Vector3 = Vector3.ZERO - g.home
		out.y = 0
		out = out.normalized()
		var side := Vector3(-out.z, 0, out.x)
		n += 1
		player.global_position = g.home + out * 25.0 + Vector3(0, 1, 0)
		await _view("%02d_%s_asleep" % [n, id], g.home + out * 8.0 + side * 3.0 + Vector3(0, 3.0, 0), g.home + Vector3(0, 1.5, 0))
		g.set_physics_process(true)
		player.global_position = g.home + out * 7.0 + side * 1.5 + Vector3(0, 1, 0)
		await _physics(6)
		for mv in g.moves:
			game.hp = game.max_hp                       # (the camera stands in every attack: no fainting)
			player.set("_invulnerable_timer", 99.0)
			g.state = G.State.IDLE
			g._state_t = 99.0
			g._move_i = (g.moves as Array).find(mv)
			await _physics(2)
			g._start_move()
			await _wait(0.6)                            # (deep into the wind-up)
			g.set_physics_process(false)
			player.set_physics_process(false)
			n += 1
			for t in get_nodes_in_group("boss_tells"):
				t.set_process(false)                    # (hold the warning still: frames are slow here)
			var mid: Vector3 = (g.global_position + player.global_position) * 0.5
			var eye: Vector3 = player.global_position + out * 9.0 + side * 4.0 + Vector3(0, 7.0, 0)
			await _view("%02d_%s_%s_windup" % [n, id, mv], eye, mid)
			for t in get_nodes_in_group("boss_tells"):
				t.queue_free()
			player.set_physics_process(true)
			g.set_physics_process(true)
			await _wait(1.0)
		if is_instance_valid(g):
			g.queue_free()
		await _frames(2)
	# The Gloop King squashing down, before the flop
	root.get_node("Bosses").enter_kingdom()
	await _frames(14)
	await _physics(4)
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	_new_cam()
	var king := current_scene.get_node_or_null("The Gloop King") as CharacterBody3D
	if king:
		king.global_position = Vector3(0, 1.2, 88)
		player.global_position = king.global_position + Vector3(6.0, 0.5, 0.0)
		king.set("_flop_timer", 1.4)
		var clock_t := 0.0
		while clock_t < 4.0 and not root.get_node("Bosses").get_tree().get_nodes_in_group("boss_tells").size() > 0:
			await physics_frame
			clock_t += 1.0 / 60.0
			player.global_position = king.global_position + Vector3(6.0, 0.0, 0.0)
		await _wait(0.3)
		king.set_physics_process(false)
		player.set_physics_process(false)
		n += 1
		await _view("%02d_gloop_king_windup" % n, king.global_position + Vector3(14, 10, 12), king.global_position)
	_finish()


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 6) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
