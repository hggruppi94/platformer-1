extends SceneTree

# Checks the camera polish (overnight, 15 Nov 2026; scenes/player/spring_arm_3d.gd and player.gd):
#   - a wall behind her pushes the camera in at once, and when it's gone the camera eases back out (no snap)
#   - running forwards on a slant, the camera swings round behind her by itself, slowly
#   - not straight after the player turned it themselves, not running straight at the camera, and not with
#     Settings > Assist "Camera follows you" off (which is saved and on the Assist tab)
# Built on a test floor high over the Practice Park, so nothing else gets in the way.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_camera_polish.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.camera_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.camera_backup.cfg"
const PARK := "res://scenes/skate/test_park.tscn"
const UP := 200.0

var failures := 0
var settings: Node
var p: CharacterBody3D
var arm: SpringArm3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	settings = root.get_node("Settings")
	settings.tips = false
	settings.camera_follow = true
	root.get_node("Game")._resume = {}
	root.get_node("Game").riding = false               # on foot: the board has its own follow (skate.gd)
	change_scene_to_file(PARK)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	arm = p.spring_arm
	if root.get_node("Game").riding:
		root.get_node("Game").toggle_skateboard()      # on foot: the board has its own follow (skate.gd)
	_box("Test Floor", Vector3(0, UP - 0.5, 0), Vector3(120, 1, 120))
	p.global_position = Vector3(0, UP + 1.0, 0)
	p.velocity = Vector3.ZERO
	arm.rotation = Vector3(-0.35, 0.0, 0.0)
	await _physics(30)

	await _wall()
	await _follow()
	_setting()
	_finish()


func _wall() -> void:
	var full: float = arm.shown_length()
	check(full > 4.0, "the camera starts out on its full boom (%.1f m)" % full)
	# A wall right behind her, between her and the camera
	var wall := _box("Test Wall", p.global_position + arm.global_transform.basis.z * 2.0, Vector3(8, 8, 0.4))
	await _physics(4)
	await _frames(2)
	var hit: float = arm.get_hit_length()
	check(hit < 2.5, "a wall behind her pushes the camera in at once (%.1f m)" % hit)
	wall.queue_free()
	await _physics(3)
	await _frames(1)
	# (the boom puts the camera at its hit length each physics frame and the ease moves it after that, in _process,
	# so shown_length() is where it's drawn)
	check(arm.shown_length() < full - 0.8, "with the wall gone, it doesn't snap straight back out (%.1f m)" % arm.shown_length())
	await _wait(1.6)
	await _frames(1)
	check(arm.shown_length() > full - 0.1, "...it eases back out to the full boom (%.1f m)" % arm.shown_length())


func _follow() -> void:
	p.global_position = Vector3(0, UP + 1.0, 0)
	arm.rotation.y = 0.0
	arm._since_look = 10.0
	# Running straight ahead: nothing to swing round to
	Input.action_press("move_forward")
	await _wait(1.0)
	check(absf(wrapf(arm.rotation.y, -PI, PI)) < 0.05, "running straight ahead the camera stays put")
	# On a slant (forward and left): it swings round behind her, slowly
	Input.action_press("move_left")
	await _wait(0.3)
	var early := absf(wrapf(arm.rotation.y, -PI, PI))
	await _wait(1.5)
	var later := absf(wrapf(arm.rotation.y, -PI, PI))
	check(early < 0.3, "...gently at first (%.2f rad)" % early)
	check(later > early + 0.2, "running on a slant, it swings round behind her (%.2f rad)" % later)
	# Just after the player turned it themselves: it's theirs
	arm._look(0.0, 0.0)
	var mine: float = arm.rotation.y
	await _wait(1.0)
	check(absf(arm.rotation.y - mine) < 0.01, "just after the player turns it, it's left alone")
	Input.action_release("move_left")
	Input.action_release("move_forward")
	# Running towards the camera: no swinging (it would spin round)
	arm.rotation.y = 0.0
	arm._since_look = 10.0
	Input.action_press("move_back")
	Input.action_press("move_left")
	await _wait(1.2)
	check(absf(wrapf(arm.rotation.y, -PI, PI)) < 0.05, "running back towards the camera it doesn't swing round (%.2f)" % arm.rotation.y)
	Input.action_release("move_back")
	# Off in the settings: nothing
	settings.camera_follow = false
	arm.rotation.y = 0.0
	arm._since_look = 10.0
	Input.action_press("move_forward")
	await _wait(1.2)
	check(absf(wrapf(arm.rotation.y, -PI, PI)) < 0.01, "with Camera follows you off, it never swings by itself (%.2f)" % arm.rotation.y)
	Input.action_release("move_forward")
	Input.action_release("move_left")
	settings.camera_follow = true


func _setting() -> void:
	check("camera_follow" in settings._props(), "Camera follows you is saved with the settings")
	var src := FileAccess.get_file_as_string("res://scripts/pause_menu.gd")
	check(src.contains("\"Camera follows you\", \"camera_follow\""), "...and it's on the Assist tab")


func _box(name: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	b.add_child(shape)
	current_scene.add_child(b)
	b.global_position = at
	b.global_rotation = Vector3(0, arm.global_rotation.y, 0)
	return b


func _finish() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _wait(seconds: float) -> void:
	# Physics frames, not the wall clock, so a busy computer doesn't change the answer (60 a second)
	for i in int(seconds * 60.0):
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
