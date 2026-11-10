extends SceneTree

# Screenshots of the Agent of Chaos's ending cutscene (scripts/chaos_ending.gd): his clock cracking and shattering, him
# sinking down to a figure of light, the sky's crack zipping shut, the friends coming through, the title, and the
# pocket watch he leaves. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_chaos_ending.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.chaos_ending_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const WORLDS := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor",
	"dark_hollow", "far_future"]
const SHOTS := [[1.6, "01_his_clock_cracks"], [3.6, "02_it_shatters"], [8.0, "03_he_sinks_down"],
	[11.2, "04_a_figure_of_light"], [15.3, "05_the_crack_in_the_sky"], [16.6, "05b_the_sky_mends"], [23.5, "06_the_friends_come"],
	[28.0, "07_the_friends_talk"], [32.0, "08_the_title"]]

var out_dir := "user://chaos_ending_shots"


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
	var game := root.get_node("Game")
	game.hold_saves = true
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Settings").no_damage = true
	var dialogue := root.get_node("Dialogue")
	dialogue.flags["swap_tried"] = true
	dialogue.flags.erase("beat_agent_of_chaos")
	dialogue.flags.erase("chaos_watch_found")
	root.get_node("Portals").cleared_worlds.assign(WORLDS)
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 16 * 60.0, true)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var giant := town.find_child("ChaosGiant", true, false) as Node3D
	var fight := giant.get_node("ChaosFight")
	fight.trials.off = true
	var front := giant.global_transform.basis.z.normalized()
	p.global_position = fight._ground(giant.global_position + front * 16.0) + Vector3(0, 0.6, 0)
	p.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	fight._open(3.0)
	giant.shot(40, fight.heart_position(), Vector3.FORWARD)
	var ending: Node = fight.ending
	for s in SHOTS:
		# (by the cutscene's own clock: a slow window would put real seconds out of step)
		while ending.playing() and float(ending.get("_t")) < float(s[0]):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(str(s[1]) + ".png"))
		print("SHOT ", s[1])
	while ending.playing():
		await process_frame
	var watch: Node3D = ending.watch
	if watch:
		var cam := Camera3D.new()
		town.add_child(cam)
		cam.global_position = watch.global_position + front * 2.2 + Vector3(0, 0.9, 0)
		cam.look_at(watch.global_position)
		cam.make_current()
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("09_the_pocket_watch.png"))
		print("SHOT 09_the_pocket_watch")
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
