extends SceneTree

# Screenshots of the final boss fight with the Agent of Chaos (scripts/chaos_fight.gd): the fight starting, his chest
# clock glowing, a volley of chaos burst marks, a burst popping, his minions coming out of glitch rifts, the spinning
# rewind clock, and the clock shattering. Also lets the fight run on its own for a while with bubbles fired at him, as
# a soak test (watch the log for errors). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_chaos_fight.gd -- <output folder> [posed]
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.chaos_fight_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://chaos_fight_shots"
var posed_only := false
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	posed_only = args.has("posed")              # skip the soak and the first shot
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Settings").no_damage = true
	for f in ["popped_gloop_king", "popped_grandfather_tock", "popped_boulderdillo"]:
		root.get_node("Dialogue").flags[f] = true
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 17 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as CharacterBody3D
	player.get_node("HUD").visible = false
	var giant := town.find_child("ChaosGiant", true, false) as Node3D
	var fight := giant.get_node("ChaosFight")
	var g := giant.global_position
	var front := giant.global_transform.basis.z.normalized()
	player.global_position = g + front * 16.0 + Vector3(0, 1.5, 0)
	for i in 30:
		await physics_frame
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	cam.make_current()
	# Soak: let the fight run itself for a while, a bubble at his clock every second
	var star: GDScript = load("res://scripts/star_bubble.gd")
	for s in (0 if posed_only else 25):
		for i in 60:
			await physics_frame
		if not fight.active:
			continue
		var from := player.global_position + Vector3(0, 0.6, 0)
		star.fire(town, from, fight.heart_position() - from, player)
		if s == 3:
			await _snap("01_the_final_fight", player.global_position + Vector3(4, 3, 9), fight.heart_position() - Vector3(0, 2, 0))
	print("SOAK phase %d chaos %d rewinds %d breaks %d" % [fight.phase, fight.chaos, fight.rewinds_done, fight.rewind_breaks])
	# Posed shots
	for m in fight.minions:
		if is_instance_valid(m):
			m.queue_free()
	fight.minions.clear()
	fight.set_physics_process(false)
	giant.set_physics_process(false)
	g = giant.global_position
	front = giant.global_transform.basis.z.normalized()
	player.global_position = g + front * 16.0 + Vector3(0, 1.5, 0)
	for i in 20:
		await physics_frame
	var side := giant.global_transform.basis.x.normalized()
	fight._open(30.0)
	await _snap("02_his_clock_glows", g + front * 14.0 + side * 5.0 + Vector3(0, 4, 0), fight.heart_position())
	fight.step = 0
	fight._glow.visible = false
	fight._glow_light.visible = false
	var burst_script: GDScript = load("res://scripts/chaos_burst.gd")
	var pp := player.global_position - Vector3(0, 0.8, 0)
	var marks := []
	for i in 5:
		var b := burst_script.new() as Node3D
		b.set("warn", 60.0)
		town.add_child(b)
		var a := TAU * i / 5.0
		b.global_position = pp + (Vector3(cos(a), 0, sin(a)) * 3.5 if i > 0 else Vector3.ZERO)
		marks.append(b)
	for i in 30:
		await physics_frame
	await _snap("03_chaos_burst_marks", pp + Vector3(6, 7, 9), pp)
	Engine.time_scale = 0.25
	for b in marks:
		b.call("_pop")
	for i in 3:
		await process_frame
	await _snap("04_chaos_bursts_pop", pp + Vector3(6, 5, 9), pp + Vector3(0, 0.5, 0), 1)
	Engine.time_scale = 1.0
	fight._summon()
	for m in fight.minions:
		m.set_physics_process(false)
	await _snap("05_minions_from_glitch_rifts", pp + Vector3(-5, 5, 12), pp + Vector3(0, 0.5, 0), 4)
	fight._wind()
	fight._t = 99.0
	await _snap("06_rewind_clock_spinning", g + front * 14.0 - side * 4.0 + Vector3(0, 5, 0), fight.heart_position(), 12)
	fight._rewind()
	await _snap("07_time_rewinds", player.global_position + Vector3(3, 2.5, 6), player.global_position, 2)
	fight._open(30.0)
	fight.chaos = 1
	giant.shot(1, fight.heart_position(), Vector3.FORWARD)
	await _snap("08_his_clock_shatters", g + front * 26.0 + Vector3(0, 6, 0), g + Vector3(0, 5, 0), 2)


func _snap(file: String, at: Vector3, look: Vector3, wait := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
