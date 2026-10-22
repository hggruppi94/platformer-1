extends SceneTree

# Checks doors and other triggers (scripts/door.gd and friends) and which way Nina faces after going through a door.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_doors.gd
#
# 1. Only Nina goes through doors. Rex skating past Nina's House, or a Gloop bumping a door, used to take the whole
#    game into that building ("Nina keeps getting teleported into her house").
# 2. Coming in or out of a building, Nina faces into the room / away from the building, the camera is behind her,
#    and pushing forward walks her that way with her model facing where she's going (it used to be turned around).
#
# Your own save is put aside and put back at the end (it never needs a second run).

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"
const FAR_AWAY := Vector3(-140, 2, 100)

var failures := 0
var clock: Node
var game: Node
var changes := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.pending_message = ""
	scene_changed.connect(func() -> void: changes += 1)
	await _load(TOWN)

	# 1. Only Nina uses doors
	clock.set_time(1, 8 * 60.0, true)                  # Rex's morning skate, right by Nina's House
	await _physics(4)
	_player().global_position = FAR_AWAY
	var door := _door_of("Nina's House")
	var rex := current_scene.find_child("Rex", true, false) as Node3D
	var before := changes
	rex.global_position = door.global_position
	await _physics(10)
	check(changes == before and current_scene.scene_file_path == TOWN, "Rex skating into Nina's House door doesn't take the game inside")
	await _back_to_town()
	before = changes
	var gloop := current_scene.find_child("Enemies", true, false).get_child(0) as Node3D
	gloop.global_position = _door_of("Cafe").global_position
	await _physics(10)
	check(changes == before and current_scene.scene_file_path == TOWN, "a Gloop bumping the Cafe door doesn't either")
	await _back_to_town()
	before = changes
	# Two in-game hours of everyone going about their day, fast, with Nina far off: she stays put in town
	_player().global_position = FAR_AWAY
	clock.set_time(1, 7 * 60.0, true)
	Engine.time_scale = 8.0
	var start: float = clock.minutes
	while clock.minutes - start < 120.0 and changes == before:
		await physics_frame
	Engine.time_scale = 1.0
	check(changes == before and current_scene.scene_file_path == TOWN,
		"2 hours of routines (to %s) with Nina away: no trip into any building" % clock.time_string())
	check(_player().global_position.distance_to(FAR_AWAY) < 3.0, "...and Nina is still where she was")
	await _back_to_town()
	door = _door_of("Nina's House")

	# 2. Going in: Nina's House
	var house := current_scene.find_child("Nina's House", true, false) as Node3D
	var front := house.global_position + house.global_transform.basis.z * 7.5
	await _through(door, TOWN)
	check(current_scene.scene_file_path == HOUSE, "walking into Nina's House door goes inside")
	var room_center := Vector3.ZERO
	_check_facing("inside Nina's House", room_center - _player().global_position)
	await _walk_forward("inside", room_center - _player().global_position)

	# Coming out (at 11 PM, so Rex and Rook aren't skating about right in front of her door to bump into)
	clock.set_time(1, 23 * 60.0, true)
	var exit := current_scene.find_child("ExitToTown", true, false) as Area3D
	await _through(exit, HOUSE)
	check(current_scene.scene_file_path == TOWN, "the exit goes back out to town")
	house = current_scene.find_child("Nina's House", true, false) as Node3D
	var away := _player().global_position - house.global_position
	_check_facing("outside Nina's House", away)
	await _walk_forward("outside", away)
	var bumped := []
	for i in (_player() as CharacterBody3D).get_slide_collision_count():
		bumped.append(str(((_player() as CharacterBody3D).get_slide_collision(i).get_collider() as Node).name))
	if not bumped.is_empty():
		print("      (bumped into %s)" % [bumped])

	# The same for another building (a different door direction): the Cafe, facing south toward the lake
	await _through(_door_of("Cafe"), TOWN)
	_check_facing("inside the Cafe", -_player().global_position)
	await _through(current_scene.find_child("ExitToTown", true, false) as Area3D, "res://scenes/interiors/cafe.tscn")
	var cafe := current_scene.find_child("Cafe", true, false) as Node3D
	_check_facing("outside the Cafe", _player().global_position - cafe.global_position)
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _back_to_town() -> void:
	# After a failed check above, carry on from town so the rest still gets checked
	Engine.time_scale = 1.0
	if current_scene == null or current_scene.scene_file_path != TOWN:
		await _load(TOWN)
		_player().global_position = FAR_AWAY
		await _physics(3)


func _check_facing(where: String, want: Vector3) -> void:
	# The body itself stays unturned (movement and camera assume it); the model faces `want`; the camera looks the
	# same way from behind her
	var p := _player()
	var model_dir := _flat(p.get_node("Visual").global_transform.basis.z)
	var cam := p.get_viewport().get_camera_3d()
	var cam_dir := _flat(-cam.global_transform.basis.z)
	want = _flat(want)
	check(absf(wrapf(p.rotation.y, -PI, PI)) < 0.01, "%s: her body isn't turned (%.0f degrees)" % [where, rad_to_deg(p.rotation.y)])
	check(model_dir.angle_to(want) < deg_to_rad(30), "%s: she faces the right way (%.0f degrees off)" % [where, rad_to_deg(model_dir.angle_to(want))])
	check(cam_dir.angle_to(want) < deg_to_rad(30), "%s: the camera looks the same way (%.0f degrees off)" % [where, rad_to_deg(cam_dir.angle_to(want))])


func _walk_forward(where: String, want: Vector3) -> void:
	# Push forward for a moment: she should walk that way, facing where she's going
	var p := _player() as CharacterBody3D
	var from := p.global_position
	Input.action_press("move_forward")
	await _physics(25)
	var moved := _flat(p.global_position - from)
	var model_dir := _flat(p.get_node("Visual").global_transform.basis.z)
	Input.action_release("move_forward")
	await _physics(15)
	check(moved.length() > 0.5 and moved.angle_to(_flat(want)) < deg_to_rad(30),
		"%s: forward walks her that way (%.0f degrees off)" % [where, rad_to_deg(moved.angle_to(_flat(want)))])
	check(moved.length() > 0.5 and model_dir.angle_to(moved) < deg_to_rad(25),
		"%s: ...facing where she's going, not backwards (%.0f degrees off)" % [where, rad_to_deg(model_dir.angle_to(moved))])


func _through(door: Area3D, from_scene: String) -> void:
	# Put Nina in the doorway and wait for the next scene
	_player().global_position = door.global_position
	for i in 120:
		await physics_frame
		if current_scene and current_scene.scene_file_path != from_scene and current_scene.find_child("Player", true, false):
			break
	await _physics(6)
	await _frames(3)


func _door_of(building: String) -> Area3D:
	var b := current_scene.find_child(building, true, false)
	return b.find_child("Door", false, false) as Area3D


func _player() -> Node3D:
	return current_scene.find_child("Player", true, false) as Node3D


func _load(path: String) -> void:
	change_scene_to_file(path)
	await _frames(5)
	await _physics(3)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z).normalized()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame
