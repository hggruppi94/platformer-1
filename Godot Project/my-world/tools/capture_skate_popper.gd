extends SceneTree

# Screenshots of the Star Popper on the board (scripts/star_popper.gd, scenes/player/skate.gd) at the Skate Park at
# midday: a shot from the hip while rolling, a Pop! mid-kickflip, popping a Gloop off a grind, the combo with its
# Pop!s, the goals board with the two new goals, a sleepy Gloop by a town rail, and Dash shooting from his BMX.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skate_popper.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.skate_popper_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://skate_popper_shots"
var cam: Camera3D
var player: CharacterBody3D
var skate: Node
var arm: SpringArm3D


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
	settings.tips = false
	settings.last_device = "pad"
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	skate = player.get_node("Skate")
	arm = player.get_node("SpringArm3D") as SpringArm3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	var popper = player.get("popper")
	var park := town.get_node("Skate Park") as Node3D
	var c := park.global_position + Vector3(0, 0.25, 0)
	await _physics(3)
	var gloops: Array[Node] = park.find_children("Skate Gloop *", "", false, false)
	var parked := []
	for g in gloops:
		(g as Node3D).set_physics_process(false)
		parked.append([g, (g as Node3D).global_position])
		(g as Node3D).global_position += Vector3(0, -300, 0)
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)

	# --- 1: rolling, a shot from the hip at a Gloop ahead ---
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	player.velocity = Vector3(4, 0, 0)
	var g0 := _place(gloops[0], c + Vector3(3, 0, 0.8))
	await _physics(20)
	arm.rotation = Vector3(-0.25, -PI / 2 + 0.25, 0)
	await _physics(10)
	popper.shoot(false)
	await _physics(7)
	cam.global_position = player.global_position + Vector3(-1.5, 1.3, 3.5)
	cam.look_at(player.global_position + Vector3(2.8, 0.2, -0.5))
	cam.make_current()
	await _still("01_shooting_while_rolling")
	await _physics(30)
	cam.global_position = g0.global_position + Vector3(-1.5, 1.2, 3.2)
	cam.look_at(g0.global_position + Vector3(0, 1.1, 0))
	await _still("02_popped_from_the_board")
	await _physics(60)
	skate.tricks.bank()

	# --- 3: mid-kickflip, popping one below ---
	_put(c + Vector3(-4, 3.2, -2.5), skate.State.AIR)
	player.velocity = Vector3(2.5, 3.5, 0)
	skate.tricks.start_flip("")
	_place(gloops[1], c + Vector3(1.5, 0, -2.0))
	await _physics(4)
	popper.shoot(false)
	await _physics(8)
	cam.global_position = player.global_position + Vector3(-0.5, 0.6, 4.5)
	cam.look_at(player.global_position + Vector3(1.8, -0.8, -0.5))
	await _still("03_pop_mid_kickflip")
	await _physics(80)
	skate.tricks.bank()

	# --- 4: on the flat rail, popping a Gloop beside it ---
	var rail := park.get_node("Flat Rail").find_children("*", "GrindRail", true, false)[0] as GrindRail
	_put(rail.point_at(rail.length() * 0.15) + Vector3(0, 1.4, 0), skate.State.AIR)
	player.velocity = Vector3(5, -1, 0)
	skate._grind_buffer = 0.2
	skate._try_grind()
	_place(gloops[2], rail.point_at(rail.length() * 0.95) + Vector3(0, -0.5, 1.8))
	await _physics(10)
	popper.shoot(false)
	await _physics(6)
	cam.global_position = player.global_position + Vector3(-2.0, 1.0, 4.0)
	cam.look_at(player.global_position + Vector3(2.5, -0.2, 0.8))
	await _still("04_pop_off_a_grind")
	await _physics(20)

	# --- 5: the combo with its Pop!s, from the game's own camera ---
	skate._leave_rail(Vector3.ZERO)
	skate.tricks.bank()
	_put(c + Vector3(-5, 4.0, 1.0), skate.State.AIR)
	player.velocity = Vector3(1.5, 5.5, 0)
	skate.tricks.start_flip("up")
	for k in 3:
		_place(gloops[3 + k], c + Vector3(3.5, 0, -1.5 + 1.8 * k))
	arm.rotation = Vector3(-0.35, -PI / 2 + 0.15, 0)
	arm.get_node("Camera3D").make_current()
	for k in 3:
		popper._cooldown = 0.0
		popper.shoot(false)
		await _physics(9)
	await _physics(6)
	await _still("05_combo_with_pops")
	await _physics(90)
	skate.tricks.bank()

	# --- 6: the goals board ---
	var board := park.get_node("GoalBoard") as Node3D
	cam.make_current()
	cam.global_position = board.global_position + board.global_transform.basis.z * 3.6 + Vector3(0, 2.3, 0)
	cam.look_at(board.global_position + Vector3(0, 2.3, 0))
	await _still("06_goals_board")

	# --- 7: a sleepy Gloop by a town rail ---
	for k in range(parked.size() - 1, -1, -1):              # the last ones: the earlier shots popped the first few
		var pair: Array = parked[k]
		var g := pair[0] as Node3D
		var d := Vector2(pair[1].x - c.x, pair[1].z - c.z).length()
		if d > park.RADIUS:
			g.global_position = pair[1]
			g.set_physics_process(true)
			await _physics(30)
			cam.global_position = g.global_position + Vector3(4.0, 2.2, 4.0)
			cam.look_at(g.global_position + Vector3(0, 0.4, 0))
			await _still("07_gloop_by_a_town_rail")
			break

	# --- 8: Dash on his BMX, popper up ---
	player.set_rider("dash")
	await _physics(5)
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	player.velocity = Vector3(4, 0, 0)
	_place(gloops[6], c + Vector3(3, 0, 0.8))
	await _physics(15)
	popper._cooldown = 0.0
	popper.shoot(false)
	await _physics(7)
	cam.global_position = player.global_position + Vector3(0.5, 1.2, 3.6)
	cam.look_at(player.global_position + Vector3(1.5, 0.3, -0.3))
	await _still("08_dash_on_his_bmx")
	player.set_rider("hero")
	_finish()


func _put(at: Vector3, state: int) -> void:
	skate.tricks.lose()
	skate._manual = 0
	player.global_position = at
	player.velocity = Vector3.ZERO
	skate.state = state
	skate._yaw = PI / 2
	(player.get_node("Visual") as Node3D).rotation.y = PI / 2


func _place(enemy: Node, at: Vector3) -> Node3D:
	var e := enemy as CharacterBody3D
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at + Vector3(0, -6, 0))
	q.exclude = [player.get_rid(), e.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	e.global_position = hit.position if not hit.is_empty() else at
	e.velocity = Vector3.ZERO
	(e.get_node("Visual") as Node3D).rotation.y = -PI / 2         # facing her, roughly
	return e


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
