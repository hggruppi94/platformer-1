extends SceneTree

# Screenshots of flying the mothership at midday: Nina on the Mothership Pad, the tractor beam lifting her up, her in
# the cockpit under the glass dome, the view while flying over the town, and beaming back down.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_mothership.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://mothership_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var arm := p.get_node("SpringArm3D") as SpringArm3D
	var ship := town.get_node("Mothership") as Node3D
	var pad := town.find_child("PadCall", true, false) as Area3D
	var spot: Vector3 = pad.pad_spot()
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)

	# 1. Nina on the pad, from her own camera, with the prompt showing
	p.global_position = spot + Vector3(0, 0.9, 0)
	(p.get_node("Visual") as Node3D).rotation.y = PI * 0.8
	arm.rotation = Vector3(-0.25, PI * 0.8 + PI, 0)
	ship.global_position = spot + Vector3(-60, 80, -90)
	await _game_view("01_on_the_pad", 20)

	# 2. The ship hovering over the pad, beaming her up (held halfway)
	ship.set_process(false)
	ship.global_position = spot + Vector3(0, ship.hover_height, 0)
	ship.rotation.y = 0.6
	ship.summon(spot)
	ship.board(p)
	ship._beam_t = 0.45
	ship._beam(0.0)
	cam.make_current()
	await _view("02_tractor_beam", spot + Vector3(26, 6, 30), spot + Vector3(0, 12, 0))

	# 3. In the cockpit under the dome
	ship._beam_t = 1.0
	ship._beam(0.0)
	ship._seat()
	var seat: Vector3 = ship.get_node("Hull/Cockpit").global_position
	var fwd := Vector3(sin(ship.rotation.y), 0, cos(ship.rotation.y))
	await _view("03_in_the_cockpit", seat + fwd * 15.0 + Vector3(0, 6.0, 0), seat + Vector3(0, 1.0, 0))

	# 4. Flying over the town, from her camera pulled right back and lifted over the dome
	arm.spring_length = ship.camera_distance
	arm.position.y = 1.1 + ship.camera_lift
	ship.global_position = Vector3(20, 70, 60)
	ship.rotation.y = PI
	ship._seat()
	arm.rotation = Vector3(-0.35, 0.0, 0)
	p.get_node("HUD").visible = true
	game.message("You're flying the mothership! WASD to fly, Space to go up, Shift to go down, F to beam down.")
	await _game_view("04_flying_over_town", 10)

	# 5. High over the north of town, heading for the mountains
	ship.global_position = Vector3(100, 85, -120)
	ship.rotation.y = -1.94                                     # turned toward the far mountains
	ship._seat()
	arm.rotation = Vector3(-0.3, 1.2, 0)
	await _game_view("05_high_over_town", 10)

	# 6. Beaming back down by the lake
	ship.global_position = Vector3(-20, 40, 40)
	ship._seat()
	ship.beam_down()
	ship._beam_t = 0.6
	ship._beam(0.0)
	cam.make_current()
	var under := Vector3(-20, ship._beam_to.y, 40)
	await _view("06_beaming_down", under + Vector3(-30, 8, 28), under + Vector3(0, 14, 0))
	_finish()


func _game_view(file: String, frames: int) -> void:
	# What the player sees: Nina's own camera
	(cam.get_parent().find_child("Player", true, false).get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
