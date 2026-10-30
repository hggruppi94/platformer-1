extends SceneTree

# Close-ups of shooting the Star Popper from the board at the Skate Park at midday (scripts/star_popper.gd,
# PopperArm's ride pose): rolling with a shot straight ahead (side-on on her board, she twists round to it), on the flat rail, mid-kickflip, and charging a big
# bubble. Run it on an older checkout too to get "before" pictures of the same moments. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_ride_shoot.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.ride_shoot_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://ride_shoot_shots"
var cam: Camera3D
var player: CharacterBody3D
var skate: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	game.mp = game.max_mp
	settings.tips = false
	settings.last_device = "pad"
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	skate = player.get_node("Skate")
	(player.get_node("HUD") as CanvasLayer).visible = false
	(skate.get("hud") as CanvasLayer).visible = false
	var popper = player.get("popper")
	var park := town.get_node("Skate Park") as Node3D
	var c := park.global_position + Vector3(0, 0.25, 0)
	await _physics(3)
	var gloops: Array[Node] = park.find_children("Skate Gloop *", "", false, false)
	for g in gloops + town.find_children("Gloop *", "", true, false):
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	(skate.get("hud") as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 40
	town.add_child(cam)
	cam.make_current()

	# --- 1: rolling, a shot off to her left ---
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	player.velocity = Vector3(3, 0, 0)
	_place(gloops[0], c + Vector3(-1.5, 0, 7.5))
	await _physics(10)
	popper.shoot(false)
	await _physics(12)
	_frame(Vector3(4.0, 0.8, 1.2))
	await _still("01_rolling")
	await _physics(90)

	# --- 2: on the flat rail ---
	var rail := park.get_node("Flat Rail").find_children("*", "GrindRail", true, false)[0] as GrindRail
	_put(rail.point_at(rail.length() * 0.15) + Vector3(0, 1.4, 0), skate.State.AIR)
	player.velocity = Vector3(4, -1, 0)
	skate._grind_buffer = 0.2
	skate._try_grind()
	_place(gloops[1], rail.point_at(rail.length() * 0.9) + Vector3(0, -0.5, -4.0))
	await _physics(8)
	popper.shoot(false)
	await _physics(12)
	_frame(Vector3(1.0, 0.9, -4.0))
	await _still("02_grinding")
	skate._leave_rail(Vector3.ZERO)
	skate.state = skate.State.AIR
	await _physics(90)

	# --- 3: mid-kickflip ---
	_put(c + Vector3(-4, 3.2, -2.5), skate.State.AIR)
	player.velocity = Vector3(1.5, 4.0, 0)
	skate.tricks.start_flip("")
	_place(gloops[2], c + Vector3(2.0, 0, -6.0))
	await _physics(3)
	popper.shoot(false)
	await _physics(10)
	_frame(Vector3(3.5, 0.4, 1.2))
	await _still("03_mid_kickflip")
	await _physics(120)

	# --- 4: charging a big bubble ---
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	await _physics(10)
	Input.action_press("shoot")
	await _physics(75)
	_frame(Vector3(4.0, 0.7, 0.8))
	await _still("04_charging")
	Input.action_release("shoot")
	await _physics(4)
	_frame(Vector3(4.0, 0.7, 0.8))
	await _still("05_big_bubble_kick")
	_finish()


func _frame(offset: Vector3) -> void:
	# A close-up of her from this side
	cam.global_position = player.global_position + offset
	cam.look_at(player.global_position + Vector3(0, 0.1, 0))


func _put(at: Vector3, state: int) -> void:
	skate.tricks.lose()
	skate._manual = 0
	player.global_position = at
	player.velocity = Vector3.ZERO
	skate.state = state
	skate._yaw = PI / 2
	(player.get_node("Visual") as Node3D).rotation.y = PI / 2


func _place(enemy: Node, at: Vector3) -> void:
	var e := enemy as CharacterBody3D
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at + Vector3(0, -6, 0))
	q.exclude = [player.get_rid(), e.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	e.global_position = hit.position if not hit.is_empty() else at
	e.velocity = Vector3.ZERO


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _still(file: String) -> void:
	# Freeze everything for the picture, then carry on
	paused = true
	await _frames(3)
	await _shot(file)
	paused = false


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
