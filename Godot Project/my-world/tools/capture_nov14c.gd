extends SceneTree

# Screenshots for the 14 Nov 2026 evening playtest fixes: Scarecrow Sam (the hayride's driver, reworked) at the wheel
# in autumn and bundled up on the Frost Fair's sleigh, the sleigh's runners, and Nina's big snowball on the green in
# The First Snow. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_nov14c.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://nov14c_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var quests := root.get_node("Quests")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for season in ["autumn", "winter"]:
		clock.on_earth = true
		clock.set_time(clock.day_of(season, 3, 1), 13 * 60.0, true)
		clock.earth_minutes = 13 * 60.0
		if season == "winter":
			root.get_node("Dialogue").flags["first_snow_start"] = true
			root.get_node("Dialogue").flags["snow_carrot"] = true
			root.get_node("Dialogue").flags["snow_scarf"] = true
			quests.state["first_snow"] = {"step": 1, "done": false, "since_day": 1}
		change_scene_to_file(EARTH)
		for i in 10:
			await process_frame
		await create_timer(1.0).timeout
		var scene := current_scene as Node3D
		var player := scene.find_child("Player", true, false) as Node3D
		player.get_node("HUD").visible = false
		var green := (load("res://scripts/festival_green.gd") as GDScript).new() as Node3D
		green.name = "Fair Preview"
		scene.add_child(green)
		await process_frame
		cam = Camera3D.new()
		cam.fov = 50
		scene.add_child(cam)
		cam.make_current()
		var tractor: Node3D = green.get("tractor")
		var wagon: Node3D = green.get("wagon")
		var sam := tractor.find_child("Scarecrow Sam", true, false) as Node3D
		var head := sam.global_position + Vector3(0, 0.8, 0)
		var fwd := tractor.global_transform.basis.z
		var side := tractor.global_transform.basis.x
		player.global_position = head + side * 8.0
		await _shot("%s_1_sam_front" % season, head + fwd * 1.6 + side * 0.4 + Vector3(0, 0.15, 0), head)
		await _shot("%s_2_sam_side" % season, head + side * 2.2 + fwd * 0.6, head + Vector3(0, -0.4, 0))
		await _shot("%s_3_ride" % season, tractor.global_position + side * 7.0 + fwd * 1.0 + Vector3(0, 2.5, 0),
			(tractor.global_position + wagon.global_position) / 2)
		if season == "winter":
			var ball := scene.get_node_or_null("First Snow/Snowman Spot") as Node3D
			if ball:
				player.global_position = ball.global_position + Vector3(0, 1, 5)
				await _shot("winter_4_big_snowball", ball.global_position + Vector3(2.5, 2.2, 6.0), ball.global_position + Vector3(0, 0.6, 0))
	_finish()


func _shot(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
