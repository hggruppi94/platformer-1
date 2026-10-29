extends SceneTree

# Screenshots of aiming and shooting with the Star Popper (scripts/star_popper.gd) in the market square at midday:
# aiming over the shoulder at a Gloop with the crosshair on it, a bubble on its way, the Gloop caught in a bubble and
# floating up, the pop, charging a big bubble, a bubble boinging off a rolling Crocodillo, and Aim and Shoot in
# Settings > Controls. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_shooting.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://shooting_shots"
var cam: Camera3D
var player: CharacterBody3D
var arm: SpringArm3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	settings.tips = false
	settings.last_device = "pad"
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
	var fountain := town.find_child("Market Square", true, false) as Node3D
	var ground := _ground(fountain.global_position + Vector3(0, 0, 14))
	player.global_position = ground + Vector3(0, 0.85, 0)
	var gloop := town.find_child("Gloop 0", true, false) as CharacterBody3D
	gloop.global_position = _ground(ground + Vector3(1.2, 0, 6.5))
	(gloop.get_node("Visual") as Node3D).rotation.y = PI * 0.9                     # facing her, roughly

	# --- 1: aiming over the shoulder, the crosshair on the Gloop ---
	Input.action_press("aim")
	for i in 3:
		_look_at(_centre(gloop))
		await _physics(8)
	await _shot("01_aiming_at_a_gloop")

	# --- 2: a bubble on its way, seen from the side ---
	popper.shoot(false)
	await _physics(9)
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.global_position = player.global_position + Vector3(-4.5, 0.8, 3.0)
	cam.look_at(player.global_position + Vector3(0.6, 0.3, 3.2))
	cam.make_current()
	await _still("02_bubble_on_its_way")

	# --- 3 and 4: caught in a bubble, floating up, and the pop ---
	await _physics(30)
	cam.global_position = gloop.global_position + Vector3(2.6, 1.4, 3.4)
	cam.look_at(gloop.global_position + Vector3(0, 1.2, 0))
	await _still("03_caught_in_a_bubble")
	for i in 70:
		await physics_frame
		if not (gloop.get_node("Visual") as Node3D).visible:
			break
	await _physics(9)
	await _still("04_pop")

	# --- 5: charging a big bubble ---
	arm.get_node("Camera3D").make_current()
	var g2 := town.find_child("Gloop 1", true, false) as CharacterBody3D
	g2.global_position = _ground(ground + Vector3(-1.5, 0, 7))
	g2.stomps_to_defeat = 4                      # the bubble from pressing Shoot, then the big one
	for i in 3:
		_look_at(_centre(g2))
		await _physics(6)
	Input.action_press("shoot")
	await _physics(80)
	await _shot("05_charging_a_big_bubble")
	Input.action_release("shoot")
	await _physics(10)
	await _shot("06_big_bubble")
	await _physics(30)
	Input.action_release("aim")

	# --- 7: boing off a rolling Crocodillo ---
	var croc := town.find_child("Crocodillo 0", true, false) as CharacterBody3D
	var CROC: GDScript = load("res://scripts/crocodillo.gd")
	croc.global_position = _ground(ground + Vector3(0, 0, 6))
	croc.state = CROC.State.ROLL
	(croc.get_node("Visual/Ball") as Node3D).visible = true
	(croc.get_node("Visual/Body") as Node3D).visible = false
	await _physics(20)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(13)
	cam.make_current()
	cam.global_position = player.global_position + Vector3(-4.0, 1.2, 2.0)
	cam.look_at(player.global_position + Vector3(0, 0.2, 3.5))
	await _still("07_boing_off_the_shell")

	# --- 8: Aim and Shoot in Settings > Controls ---
	var pause := root.get_node("PauseMenu")
	settings.last_device = "keyboard"
	pause.open()
	await process_frame
	for b in pause.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Settings"):
			(b as Button).pressed.emit()
			break
	await _frames(3)
	for t in pause.find_children("*", "TabContainer", true, false):
		var tabs := t as TabContainer
		for k in tabs.get_tab_count():
			if tabs.get_tab_title(k) == "Controls":
				tabs.current_tab = k
	await _frames(4)
	for l in pause.find_children("*", "Label", true, false):
		if (l as Label).text == "Aim" and (l as Label).is_visible_in_tree():
			for s in pause.find_children("*", "ScrollContainer", true, false):
				if (s as ScrollContainer).is_ancestor_of(l):
					(s as ScrollContainer).scroll_vertical = int(l.global_position.y - (s as Control).global_position.y) - 140 + (s as ScrollContainer).scroll_vertical
	await _shot("08_controls")
	_finish()


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -40, 0))
	q.exclude = [player.get_rid()] if player else []
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _centre(e: Node3D) -> Vector3:
	return e.global_position + Vector3(0, 0.45, 0)


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
	Input.action_release("aim")
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
