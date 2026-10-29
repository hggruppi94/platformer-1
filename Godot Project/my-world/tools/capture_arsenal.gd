extends SceneTree

# Screenshots of the hero's gadgets (scripts/arsenal.gd) in the Market Square at midday: Dash's gadget stall and its
# shop window, the Fizz Flinger in her hand with the gadget readout, a fizz bomb on its way and its splash popping
# two Gloops, the Disco Ball with Gloops dancing under it, the gadget wheel, and an ammo bubble. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_arsenal.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.arsenal_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://arsenal_shots"
var cam: Camera3D
var player: CharacterBody3D
var arm: SpringArm3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	var arsenal := root.get_node("Arsenal")
	var shop := root.get_node("Shop")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	settings.tips = false
	settings.last_device = "keyboard"
	arsenal.reset()
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	arm = player.get_node("SpringArm3D") as SpringArm3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	var popper = player.get("popper")
	var enemies := town.find_children("Gloop *", "", true, false) + town.find_children("Crocodillo *", "", true, false)
	for e in enemies:
		(e as Node3D).set_physics_process(false)
		(e as Node3D).global_position += Vector3(0, -300, 0)
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)

	# --- 1: Dash's gadget stall ---
	var stall := town.get_node("Gadget Stall") as Node3D
	var front := stall.global_transform.basis.z
	player.global_position = _ground(stall.global_position + front * 2.0) + Vector3(0, 0.85, 0)
	(player.get_node("Visual") as Node3D).rotation.y = atan2(-front.x, -front.z)
	cam.global_position = stall.global_position + front * 6.5 + Vector3(0, 2.4, 0) + stall.global_transform.basis.x * 1.5
	cam.look_at(stall.global_position + Vector3(0, 1.6, 0))
	cam.make_current()
	await _physics(10)
	await _still("01_dashs_gadget_stall")

	# --- 2: its shop window ---
	game.sparkles = 40
	shop.open("Gadget")
	await _frames(4)
	await _shot("02_gadget_shop")
	shop.buy("fizz_flinger")
	shop.buy("disco_ball")
	arsenal.select("fizz")
	shop.close()
	await _frames(2)

	# --- 3: the Fizz Flinger in her hand, aiming at two Gloops ---
	var fountain := town.find_child("Market Square", true, false) as Node3D
	var ground := _ground(fountain.global_position + Vector3(0, 0, 14))
	player.global_position = ground + Vector3(0, 0.85, 0)
	var g0 := town.find_child("Gloop 0", true, false) as CharacterBody3D
	var g1 := town.find_child("Gloop 1", true, false) as CharacterBody3D
	g0.global_position = _ground(ground + Vector3(0.6, 0, 8))
	g1.global_position = _ground(ground + Vector3(-0.8, 0, 8.8))
	for g in [g0, g1]:
		(g.get_node("Visual") as Node3D).rotation.y = PI
		g.stomps_to_defeat = 1
	arm.get_node("Camera3D").make_current()
	Input.action_press("aim")
	for i in 3:
		_look_at(g0.global_position + Vector3(-0.3, 0.2, 0.4))
		await _physics(8)
	await _shot("03_fizz_flinger_aimed")

	# --- 4 and 5: the fizz bomb on its way, and the splash ---
	popper.shoot(false)
	Input.action_release("aim")
	await _physics(16)
	cam.global_position = player.global_position + Vector3(-6.0, 1.5, 4.0)
	cam.look_at(player.global_position + Vector3(0, 1.2, 4.5))
	cam.make_current()
	await _still("04_fizz_bomb_on_its_way")
	for i in 60:
		await physics_frame
		if town.find_child("FizzSplash", true, false) != null:
			break
	await _physics(3)
	cam.global_position = g0.global_position + Vector3(-4.5, 2.2, 3.5)
	cam.look_at(g0.global_position + Vector3(0, 0.8, 0))
	await _still("05_fizz_splash_pops_them")
	await _physics(90)

	# --- 6: the Disco Ball, and Gloops dancing under it ---
	arsenal.select("disco")
	var dancers := [town.find_child("Gloop 2", true, false), town.find_child("Gloop 3", true, false),
		town.find_child("Gloop 4", true, false)] as Array
	var spots := [Vector3(1.8, 0, 8), Vector3(-1.8, 0, 9), Vector3(0.2, 0, 10.5)]
	for k in dancers.size():
		var g := dancers[k] as CharacterBody3D
		g.global_position = _ground(ground + spots[k])
		g.set_physics_process(true)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	await _physics(2)
	popper._cooldown = 0.0
	popper.shoot(false)
	await _physics(75)
	cam.global_position = ground + Vector3(-5.0, 3.0, 4.5)
	cam.look_at(ground + Vector3(0, 1.4, 9))
	await _still("06_disco_ball_dance")
	await _physics(20)
	await _still("07_still_dancing")

	# --- 8: the gadget wheel ---
	arm.get_node("Camera3D").make_current()
	popper.find_child("GadgetWheel", true, false).open_wheel()
	popper.find_child("GadgetWheel", true, false).point(-PI / 2.0 + TAU / 3.0)
	await _frames(4)
	await _shot("08_gadget_wheel")
	popper.find_child("GadgetWheel", true, false).close(true)

	# --- 9: an ammo bubble left by a popped Gloop ---
	arsenal.ammo["fizz"] = 3
	arsenal.drop(player.global_position + Vector3(0.0, 0.2, 4.5), "fizz")
	cam.global_position = player.global_position + Vector3(-2.2, 1.0, 6.5)
	cam.look_at(player.global_position + Vector3(0, 0.3, 3.5))
	cam.make_current()
	await _physics(5)
	await _still("09_ammo_bubble")
	_finish()


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -40, 0))
	q.exclude = [player.get_rid()] if player else []
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _look_at(target: Vector3) -> void:
	var c := arm.get_node("Camera3D") as Camera3D
	var d := (target - c.global_position).normalized()
	arm.rotation = Vector3(asin(d.y), atan2(-d.x, -d.z), 0)


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
	Engine.time_scale = 1.0
	Input.action_release("aim")
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
