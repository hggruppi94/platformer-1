extends SceneTree

# Aiming the Star Popper from the board at the Skate Park at midday, from the game's own camera (scripts/star_popper.gd,
# scenes/player/skate.gd): holding Aim while rolling and looking off to the side at a Gloop, the shot, aiming on the
# flat rail, and aiming in the air. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_ride_aim.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.ride_aim_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://ride_aim_shots"
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
	var boom := player.get("spring_arm") as SpringArm3D
	(boom.get_node("Camera3D") as Camera3D).make_current()

	# --- 1: rolling, looking off to her left at a Gloop ---
	_put(c + Vector3(-7, 0.85, 3.0), skate.State.ROLL)
	player.velocity = Vector3(3.5, 0, 0)
	var g0 := gloops[0] as Node3D
	_place(g0, c + Vector3(0.0, 0, -5.0))
	Input.action_press("aim")
	await _physics(6)
	_look_at(boom, g0.global_position + Vector3(0, 0.6, 0))
	await _physics(14)
	_look_at(boom, g0.global_position + Vector3(0, 0.6, 0))
	await _physics(2)
	await _still("01_aiming_while_rolling")
	popper._cooldown = 0.0
	popper.shoot(false)
	await _physics(9)
	await _still("02_the_shot")
	await _physics(60)
	Input.action_release("aim")
	await _physics(30)

	# --- 3: aiming on the flat rail ---
	var rail := park.get_node("Flat Rail").find_children("*", "GrindRail", true, false)[0] as GrindRail
	_put(rail.point_at(rail.length() * 0.1) + Vector3(0, 1.4, 0), skate.State.AIR)
	player.velocity = Vector3(4, -1, 0)
	skate._grind_buffer = 0.2
	skate._try_grind()
	var g1 := gloops[1] as Node3D
	_place(g1, rail.point_at(rail.length() * 0.6) + Vector3(0, -0.5, 5.0))
	Input.action_press("aim")
	await _physics(4)
	_look_at(boom, g1.global_position + Vector3(0, 0.6, 0))
	await _physics(14)
	_look_at(boom, g1.global_position + Vector3(0, 0.6, 0))
	await _physics(2)
	await _still("03_aiming_on_a_rail")
	Input.action_release("aim")
	skate._leave_rail(Vector3.ZERO)
	skate.state = skate.State.AIR
	await _physics(90)

	# --- 4: aiming in the air ---
	_put(c + Vector3(-5, 3.5, 0), skate.State.AIR)
	player.velocity = Vector3(2.0, 4.5, 0)
	var g2 := gloops[2] as Node3D
	_place(g2, c + Vector3(3.0, 0, 4.0))
	Input.action_press("aim")
	await _physics(4)
	_look_at(boom, g2.global_position + Vector3(0, 0.6, 0))
	await _physics(14)
	_look_at(boom, g2.global_position + Vector3(0, 0.6, 0))
	await _physics(2)
	await _still("04_aiming_in_the_air")
	Input.action_release("aim")
	_finish()


func _look_at(boom: SpringArm3D, at: Vector3) -> void:
	# Turn the camera (as the mouse or right stick would) so the crosshair is on this spot
	var d := at - boom.global_position
	boom.rotation.y = atan2(-d.x, -d.z)
	boom.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), boom.min_pitch, boom.max_pitch)
	boom.set("_since_look", 0.0)


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
	Input.action_release("aim")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
